#!/usr/bin/env python3
"""Gate image assembly on successful package workflows for the release sources."""
import json
from pathlib import Path
import subprocess
import time


def api(path):
    return json.loads(subprocess.check_output(["gh", "api", path], text=True))


def check(source, workflow):
    path = (f"repos/{source['repo']}/actions/workflows/{workflow}/runs"
            f"?branch={source['ref']}&head_sha={source['commit']}&per_page=100")
    runs = api(path)["workflow_runs"]
    runs = [run for run in runs if run["head_sha"] == source["commit"]]
    if not runs:
        raise RuntimeError(f"No {source['repo']}/{workflow} build for {source['commit']}")
    run = max(runs, key=lambda run: run["id"])
    print(f"{source['repo']}/{workflow}: {run['status']} {run['conclusion']} {run['html_url']}", flush=True)
    if run["status"] != "completed":
        return False
    if run["conclusion"] != "success":
        raise RuntimeError(f"Required package build failed: {run['html_url']}")
    return True


def main():
    release = json.loads(Path("release-components.json").read_text())
    deadline = time.monotonic() + 90 * 60
    pending = [(source, workflow) for source in release["sources"] for workflow in source["workflows"]]
    while pending:
        pending = [(source, workflow) for source, workflow in pending if not check(source, workflow)]
        if pending:
            if time.monotonic() >= deadline:
                raise RuntimeError("Timed out waiting for release component packages")
            time.sleep(30)
    print(f"All component builds succeeded for {release['release']}", flush=True)


if __name__ == "__main__":
    main()
