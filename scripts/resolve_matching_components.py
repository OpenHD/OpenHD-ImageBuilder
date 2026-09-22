#!/usr/bin/env python3
"""Select the newest compatible OpenHD and SysUtils raw component pair."""

from __future__ import annotations

import argparse
import json
import sys
import urllib.parse
import urllib.request


API_URL = "https://api.cloudsmith.io/v1/packages/openhd/dev-release/"


def fetch_json(url: str) -> object:
    request = urllib.request.Request(url, headers={"User-Agent": "OpenHD-ImageBuilder-CI"})
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.load(response)


def package_list(prefix: str) -> list[dict[str, object]]:
    query = urllib.parse.quote(f"format:raw AND name:^{prefix}")
    packages = fetch_json(f"{API_URL}?page_size=100&query={query}")
    if not isinstance(packages, list):
        raise RuntimeError("Cloudsmith returned an unexpected package response")
    return packages


def manifests(prefix: str, platform: str) -> list[tuple[dict[str, object], str, str]]:
    packages = package_list(prefix)
    filenames = {str(package["filename"]) for package in packages}
    candidates: list[tuple[dict[str, object], str, str]] = []

    for package in packages:
        filename = str(package["filename"])
        if not filename.startswith(prefix) or not filename.endswith(".tar.gz.manifest.json"):
            continue
        if "-latest.tar.gz.manifest.json" in filename:
            continue

        archive = filename.removesuffix(".manifest.json")
        checksum = f"{archive}.sha256"
        if archive not in filenames or checksum not in filenames:
            continue

        manifest = fetch_json(str(package["cdn_url"]))
        if not isinstance(manifest, dict) or manifest.get("platform") != platform:
            continue
        candidates.append((manifest, archive, str(package.get("uploaded_at", ""))))

    return candidates


def select_pair(
    openhd_candidates: list[tuple[dict[str, object], str, str]],
    sysutils_candidates: list[tuple[dict[str, object], str, str]],
) -> tuple[str, str, str, str]:
    matches: list[tuple[str, str, str, str, str]] = []
    for openhd, openhd_archive, openhd_uploaded in openhd_candidates:
        for sysutils, sysutils_archive, sysutils_uploaded in sysutils_candidates:
            sdk_sha = str(openhd.get("sdk_sha256", ""))
            buildroot_commit = str(openhd.get("sdk_buildroot_commit", ""))
            if not sdk_sha or sdk_sha == "unknown":
                continue
            if sdk_sha != str(sysutils.get("sdk_sha256", "")):
                continue
            if buildroot_commit != str(sysutils.get("sdk_buildroot_commit", "")):
                continue
            matches.append(
                (
                    min(openhd_uploaded, sysutils_uploaded),
                    openhd_archive,
                    sysutils_archive,
                    sdk_sha,
                    buildroot_commit,
                )
            )

    if not matches:
        raise RuntimeError("no OpenHD/SysUtils pair shares an SDK checksum and Buildroot commit")

    _, openhd_archive, sysutils_archive, sdk_sha, buildroot_commit = max(matches)
    return openhd_archive, sysutils_archive, sdk_sha, buildroot_commit


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--platform", required=True)
    parser.add_argument("--openhd-prefix", required=True)
    parser.add_argument("--sysutils-prefix", required=True)
    args = parser.parse_args()

    pair = select_pair(
        manifests(args.openhd_prefix, args.platform),
        manifests(args.sysutils_prefix, args.platform),
    )
    openhd_archive, sysutils_archive, sdk_sha, buildroot_commit = pair
    print(f"OPENHD_COMPONENT_NAME={openhd_archive}")
    print(f"SYSUTILS_COMPONENT_NAME={sysutils_archive}")
    print(f"COMPONENT_SDK_SHA256={sdk_sha}")
    print(f"COMPONENT_BUILDROOT_COMMIT={buildroot_commit}")
    print(
        f"Selected {openhd_archive} and {sysutils_archive} "
        f"from SDK {sdk_sha}",
        file=sys.stderr,
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"component resolution failed: {exc}", file=sys.stderr)
        raise SystemExit(1)
