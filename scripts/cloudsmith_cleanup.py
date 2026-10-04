#!/usr/bin/env python3
"""Clean unused Cloudsmith packages, retaining only the newest version in x21."""

from __future__ import annotations

import argparse
import calendar
import json
import os
import re
import sys
import time
from datetime import datetime, timezone
from urllib.error import HTTPError
from urllib.parse import quote, urlencode
from urllib.request import Request, urlopen


API_URL = "https://api.cloudsmith.io/v1"


def month_ago(now: datetime) -> datetime:
    year, month = (now.year - 1, 12) if now.month == 1 else (now.year, now.month - 1)
    day = min(now.day, calendar.monthrange(year, month)[1])
    return now.replace(year=year, month=month, day=day)


def upload_time(package: dict) -> datetime | None:
    uploaded = package.get("uploaded_at")
    if not isinstance(uploaded, str):
        return None
    try:
        timestamp = datetime.fromisoformat(uploaded.replace("Z", "+00:00"))
    except ValueError:
        return None
    return timestamp if timestamp.tzinfo is not None else None


def eligible(package: dict, cutoff: datetime) -> bool:
    # Missing or malformed metadata must never qualify a package for deletion.
    if type(package.get("downloads")) is not int or package["downloads"] != 0:
        return False
    timestamp = upload_time(package)
    return timestamp is not None and timestamp < cutoff


def package_family(package: dict) -> str | None:
    if not all(isinstance(package.get(key), str) and package[key] for key in ("format", "name")):
        return None
    # Keep platform variants separate; versions and dated filenames are not identities.
    identity = [package.get(key) for key in
                ("format", "name", "package_type", "arch", "architecture", "distro", "distro_version")]
    # Early X21 uploads used the entire dated filename as their package name.
    if package["format"] == "raw" and package["name"] == package.get("filename"):
        legacy = re.fullmatch(
            r"(firmware|OpenHD-X21B-full)-\d{4}(?:-\d{2}){5}\.(zip|ohd)",
            package["name"], re.IGNORECASE,
        )
        if legacy:
            name, extension = (part.lower() for part in legacy.groups())
            if (name, extension) in (("firmware", "zip"), ("openhd-x21b-full", "ohd")):
                identity[1] = name
    architectures = package.get("architectures")
    if isinstance(architectures, list):
        architectures = sorted(architectures, key=lambda value: json.dumps(value, sort_keys=True))
    return json.dumps([*identity, architectures], sort_keys=True)


def upload_rank(package: dict) -> tuple[datetime, str] | None:
    timestamp = upload_time(package)
    identifier = package.get("slug_perm")
    if timestamp is None or not isinstance(identifier, str) or not identifier:
        return None
    # Permanent IDs break timestamp ties consistently, leaving exactly one upload.
    return timestamp, identifier


def superseded(packages: list[dict]) -> dict[str, tuple[dict, dict]]:
    families: dict[str, list[dict]] = {}
    for package in packages:
        family = package_family(package)
        if family is not None:
            families.setdefault(family, []).append(package)
    candidates = {}
    for family in families.values():
        if any(upload_rank(package) is None for package in family):
            continue
        newest = max(family, key=upload_rank)
        # A failed or unfinished upload must not displace a usable older version.
        if newest.get("is_downloadable") is not True:
            continue
        for package in family:
            if package["slug_perm"] != newest["slug_perm"]:
                candidates[package["slug_perm"]] = (package, newest)
    return candidates


def still_superseded(current: dict, keeper: dict, original: dict) -> bool:
    current_rank = upload_rank(current)
    keeper_rank = upload_rank(keeper)
    return (
        keeper.get("is_downloadable") is True
        and package_family(current) is not None
        and package_family(current) == package_family(keeper) == package_family(original)
        and current_rank is not None and keeper_rank is not None
        and current_rank < keeper_rank
    )


class Cloudsmith:
    def __init__(self, api_key: str):
        self.api_key = api_key

    def request(self, path: str, method: str = "GET") -> tuple[object, object]:
        request = Request(
            API_URL + path,
            method=method,
            headers={
                "X-Api-Key": self.api_key,
                "Accept": "application/json",
                "User-Agent": "OpenHD-ImageBuilder-cleanup",
            },
        )
        for attempt in range(5):
            try:
                with urlopen(request, timeout=60) as response:
                    data = None if response.status == 204 else json.load(response)
                    return data, response.headers
            except HTTPError as exc:
                if exc.code == 404 and method == "DELETE":
                    return None, exc.headers
                if exc.code not in (429, 500, 502, 503, 504) or attempt == 4:
                    # Do not print response bodies, which may contain sensitive data.
                    raise RuntimeError(f"{method} {path}: HTTP {exc.code}") from None
                try:
                    delay = float(exc.headers.get("Retry-After", 2 ** attempt))
                except ValueError:
                    delay = 2 ** attempt
                print(f"HTTP {exc.code}; retrying in {min(60, max(1, delay))}s", flush=True)
                time.sleep(min(60, max(1, delay)))
        raise RuntimeError("Cloudsmith retry limit reached")

    def list_all(self, path: str) -> list[dict]:
        items = []
        page = 1
        while True:
            data, headers = self.request(path + "?" + urlencode({"page": page, "page_size": 100}))
            if not isinstance(data, list) or any(not isinstance(item, dict) for item in data):
                raise RuntimeError(f"Unexpected list response for {path}")
            items.extend(data)
            total = headers.get("X-Pagination-Pagetotal")
            if not data or (total is not None and page >= int(total)):
                return items
            page += 1


def cleanup(client: Cloudsmith, owner: str, cutoff: datetime, dry_run: bool) -> int:
    namespace = quote(owner, safe="")
    repos = client.list_all(f"/repos/{namespace}/")
    if not repos:
        raise RuntimeError(f"No repositories visible for {owner}; check API key permissions")
    # Process X21 retention first, preserving the API order for other repositories.
    repos.sort(key=lambda repo: repo.get("slug") != "x21")
    failures = 0
    matched = 0
    deleted = 0
    for repo in repos:
        slug = repo.get("slug")
        if not isinstance(slug, str) or not slug:
            raise RuntimeError("Repository response is missing its slug")
        path = f"/packages/{namespace}/{quote(slug, safe='')}/"
        print(f"Scanning {owner}/{slug}", flush=True)
        try:
            # Finish pagination before deleting, so deletions cannot shift page offsets.
            packages = client.list_all(path)
            latest_only = slug == "x21"
            candidates = superseded(packages) if latest_only else {
                p["slug_perm"]: (p, None) for p in packages if eligible(p, cutoff)
            }
            matched += len(candidates)
            print(f"  {len(packages)} packages; {len(candidates)} candidates", flush=True)
            for identifier, (package, keeper) in candidates.items():
                package_path = path + quote(identifier, safe="") + "/"
                ref = f"{owner}/{slug}/{identifier}"
                try:
                    if dry_run:
                        print(f"  Would delete {ref} ({package.get('filename', '')})", flush=True)
                        continue
                    current, _ = client.request(package_path)
                    if not isinstance(current, dict):
                        raise RuntimeError(f"Unexpected package response for {ref}")
                    if latest_only:
                        keeper_path = path + quote(keeper["slug_perm"], safe="") + "/"
                        live_keeper, _ = client.request(keeper_path)
                        qualifies = isinstance(live_keeper, dict) and still_superseded(
                            current, live_keeper, package,
                        )
                    else:
                        qualifies = eligible(current, cutoff)
                    if not qualifies:
                        print(f"  Keeping {ref}: metadata changed", flush=True)
                        continue
                    client.request(package_path, method="DELETE")
                    deleted += 1
                    print(f"  Deleted {ref}", flush=True)
                except Exception as exc:
                    failures += 1
                    print(f"  Failed {ref}: {exc}", file=sys.stderr, flush=True)
        except Exception as exc:
            failures += 1
            print(f"Failed to scan {owner}/{slug}: {exc}", file=sys.stderr, flush=True)
    print(
        f"Finished: repositories={len(repos)}, candidates={matched}, "
        f"deleted={deleted}, failures={failures}, dry_run={dry_run}", flush=True,
    )
    return 1 if failures else 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--owner", default=os.environ.get("CLOUDSMITH_OWNER", "openhd"))
    parser.add_argument("--delete", action="store_true", help="Delete matches (default: dry run)")
    args = parser.parse_args()
    api_key = os.environ.get("CLOUDSMITH_API_KEY", "").strip()
    if not api_key or not args.owner.strip():
        parser.error("CLOUDSMITH_API_KEY and a non-empty owner are required")
    cutoff = month_ago(datetime.now(timezone.utc))
    print(f"Policy: downloads == 0 and uploaded_at < {cutoff.isoformat()}", flush=True)
    print("x21 override: keep the newest upload of each package; remove superseded uploads", flush=True)
    try:
        return cleanup(Cloudsmith(api_key), args.owner.strip(), cutoff, not args.delete)
    except Exception as exc:
        print(f"Cleanup failed: {exc}", file=sys.stderr, flush=True)
        return 1


if __name__ == "__main__":
    sys.exit(main())
