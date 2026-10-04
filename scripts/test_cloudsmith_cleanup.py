"""Exercise retention boundaries and deletion behavior without Cloudsmith writes."""

import contextlib
import io
import unittest
from datetime import datetime, timezone
from unittest.mock import patch

from cloudsmith_cleanup import Cloudsmith, cleanup, eligible, month_ago, superseded


def package(identifier="old", downloads=0, uploaded="2026-09-03T12:00:00Z"):
    return {"slug_perm": identifier, "downloads": downloads, "uploaded_at": uploaded}


class FakeCloudsmith:
    def __init__(self):
        self.deleted = []
        self.scanned = []

    def list_all(self, path):
        self.scanned.append(path)
        if path.startswith("/repos/"):
            return [{"slug": "release"}, {"slug": "base"}]
        return [package(), package("downloaded", 1), package("recent", 0, "2026-10-01T00:00:00Z")]

    def request(self, path, method="GET"):
        if method == "DELETE":
            self.deleted.append(path)
            return None, {}
        return package(), {}


class FakeX21(FakeCloudsmith):
    def __init__(self):
        super().__init__()
        self.packages = [
            dict(package("older", 20, "2026-10-01T00:00:00Z"), name="firmware", format="raw",
                 is_downloadable=True),
            dict(package("newest", 0, "2026-10-03T00:00:00Z"), name="firmware", format="raw",
                 is_downloadable=True),
        ]

    def list_all(self, path):
        return [{"slug": "x21"}] if path.startswith("/repos/") else self.packages

    def request(self, path, method="GET"):
        if method == "DELETE":
            self.deleted.append(path)
            return None, {}
        identifier = path.rstrip("/").split("/")[-1]
        return next(p for p in self.packages if p["slug_perm"] == identifier), {}


class CleanupTests(unittest.TestCase):
    cutoff = datetime(2026, 9, 4, 12, tzinfo=timezone.utc)

    def run_cleanup(self, client, dry_run=False):
        with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
            return cleanup(client, "openhd", self.cutoff, dry_run)

    def test_calendar_month_and_year_boundaries(self):
        for now, expected in [("2026-03-31", "2026-02-28"), ("2024-03-31", "2024-02-29"),
                              ("2026-01-31", "2025-12-31")]:
            timestamp = datetime.fromisoformat(now).replace(hour=12, tzinfo=timezone.utc)
            self.assertEqual(month_ago(timestamp).isoformat(), expected + "T12:00:00+00:00")

    def test_only_zero_downloads_strictly_older(self):
        self.assertTrue(eligible(package(), self.cutoff))
        for count in (1, -1, None, "0", False, 0.0):
            self.assertFalse(eligible(package(downloads=count), self.cutoff))
        for uploaded in (None, "invalid", "2026-09-01", "2026-09-04T12:00:00Z",
                         "2026-09-04T14:00:00+02:00", "2026-10-01T00:00:00Z"):
            self.assertFalse(eligible(package(uploaded=uploaded), self.cutoff))
        self.assertFalse(eligible({}, self.cutoff))

    def test_all_repositories_and_only_matching_packages(self):
        client = FakeCloudsmith()
        self.assertEqual(self.run_cleanup(client), 0)
        self.assertEqual(client.deleted, ["/packages/openhd/release/old/", "/packages/openhd/base/old/"])

    def test_x21_runs_before_other_repositories(self):
        client = FakeCloudsmith()
        original_list = client.list_all

        def repositories_with_x21_last(path):
            if path.startswith("/repos/"):
                return [{"slug": "release"}, {"slug": "base"}, {"slug": "x21"}]
            return original_list(path)

        with patch.object(client, "list_all", side_effect=repositories_with_x21_last):
            self.assertEqual(self.run_cleanup(client, True), 0)
        self.assertEqual(client.scanned, ["/packages/openhd/x21/", "/packages/openhd/release/",
                                        "/packages/openhd/base/"])

    def test_dry_run_never_writes(self):
        client = FakeCloudsmith()
        self.assertEqual(self.run_cleanup(client, True), 0)
        self.assertEqual(client.deleted, [])

    def test_recheck_keeps_packages_with_new_downloads(self):
        client = FakeCloudsmith()
        with patch.object(client, "request", return_value=(package(downloads=1), {})):
            self.assertEqual(self.run_cleanup(client), 0)
        self.assertEqual(client.deleted, [])

    def test_failures_make_job_fail(self):
        client = FakeCloudsmith()
        with patch.object(client, "request", side_effect=RuntimeError("HTTP 403")):
            self.assertEqual(self.run_cleanup(client), 1)

    def test_pagination_collects_every_page(self):
        client = Cloudsmith("test")
        pages = [([package("first")], {"X-Pagination-Pagetotal": "2"}),
                 ([package("second")], {"X-Pagination-Pagetotal": "2"})]
        with patch.object(client, "request", side_effect=pages) as request:
            self.assertEqual([p["slug_perm"] for p in client.list_all("/packages/openhd/base/")],
                             ["first", "second"])
        self.assertEqual(request.call_count, 2)
        self.assertIn("page=2", request.call_args.args[0])

    def test_pagination_without_headers_waits_for_empty_page(self):
        client = Cloudsmith("test")
        with patch.object(client, "request", side_effect=[([package()], {}), ([], {})]) as request:
            self.assertEqual(len(client.list_all("/repos/openhd/")), 1)
            self.assertEqual(request.call_count, 2)

    def test_x21_removes_recent_downloaded_older_upload(self):
        client = FakeX21()
        self.assertEqual(self.run_cleanup(client), 0)
        self.assertEqual(client.deleted, ["/packages/openhd/x21/older/"])

    def test_x21_always_preserves_newest_even_old_and_unused(self):
        client = FakeX21()
        client.packages = [dict(client.packages[1], uploaded_at="2026-01-01T00:00:00Z")]
        self.assertEqual(self.run_cleanup(client), 0)
        self.assertEqual(client.deleted, [])

    def test_x21_dry_run_never_writes(self):
        client = FakeX21()
        self.assertEqual(self.run_cleanup(client, True), 0)
        self.assertEqual(client.deleted, [])

    def test_x21_keeps_distinct_names_formats_and_platforms(self):
        client = FakeX21()
        original = client.packages[0]
        for changes in ({"name": "openhd-x21b-full"}, {"format": "deb"},
                        {"architectures": ["arm64"]}, {"distro": "ubuntu"},
                        {"distro_version": "noble"}):
            client.packages[0] = dict(original, **changes)
            self.assertEqual(superseded(client.packages), {})

    def test_x21_retains_group_with_invalid_metadata_or_unavailable_newest(self):
        client = FakeX21()
        for changes in ({"uploaded_at": None}, {"slug_perm": None}, {"is_downloadable": False}):
            packages = [client.packages[0], dict(client.packages[1], **changes)]
            self.assertEqual(superseded(packages), {})

    def test_x21_groups_known_legacy_dated_names(self):
        client = FakeX21()
        legacy_name = "firmware-2026-09-11-14-42-17.zip"
        client.packages[0].update(name=legacy_name, filename=legacy_name)
        self.assertEqual(set(superseded(client.packages)), {"older"})
        client.packages[1]["name"] = "openhd-x21b-full"
        legacy_name = "OpenHD-X21B-full-2026-09-11-14-42-17.ohd"
        client.packages[0].update(name=legacy_name, filename=legacy_name)
        self.assertEqual(set(superseded(client.packages)), {"older"})

    def test_x21_does_not_merge_unrelated_dated_package_names(self):
        client = FakeX21()
        for name in ("firmware-2026-09-11-14-42-17.ohd", "other-2026-09-11-14-42-17.zip"):
            client.packages[0].update(name=name, filename=name)
            self.assertEqual(superseded(client.packages), {})

    def test_x21_breaks_timestamp_ties_consistently(self):
        client = FakeX21()
        client.packages[0]["uploaded_at"] = client.packages[1]["uploaded_at"]
        self.assertEqual(set(superseded(client.packages)), {"newest"})
        self.assertEqual(set(superseded(list(reversed(client.packages)))), {"newest"})

    def test_x21_rechecks_replacement_before_deletion(self):
        client = FakeX21()
        original_request = client.request

        def changed_replacement(path, method="GET"):
            data, headers = original_request(path, method)
            if path.endswith("/newest/"):
                data = dict(data, is_downloadable=False)
            return data, headers

        with patch.object(client, "request", side_effect=changed_replacement):
            self.assertEqual(self.run_cleanup(client), 0)
        self.assertEqual(client.deleted, [])

    def test_x21_missing_replacement_fails_without_deleting(self):
        client = FakeX21()
        original_request = client.request

        def missing_replacement(path, method="GET"):
            if path.endswith("/newest/"):
                raise RuntimeError("HTTP 404")
            return original_request(path, method)

        with patch.object(client, "request", side_effect=missing_replacement):
            self.assertEqual(self.run_cleanup(client), 1)
        self.assertEqual(client.deleted, [])


if __name__ == "__main__":
    unittest.main()
