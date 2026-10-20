"""Check package freshness, board selection, and fail-closed release gating."""
import importlib.util
from pathlib import Path
import subprocess
import unittest
import sys
sys.dont_write_bytecode = True
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("gate", ROOT / "scripts/wait_for_release_components.py")
gate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gate)


class ReleaseGateTests(unittest.TestCase):
    def test_failed_publication_blocks_images(self):
        source = {"repo": "OpenHD/QOpenHD", "ref": "dev-release", "commit": "new"}
        runs = [{"id": 1, "head_sha": "old", "status": "completed", "conclusion": "success", "html_url": "old"},
                {"id": 2, "head_sha": "new", "status": "completed", "conclusion": "failure", "html_url": "failed"}]
        with patch.object(gate, "api", return_value={"workflow_runs": runs}):
            with self.assertRaisesRegex(RuntimeError, "Required package build failed"):
                gate.check(source, "rock.yml")

    def test_pending_build_waits(self):
        source = {"repo": "OpenHD/QOpenHD", "ref": "dev-release", "commit": "new"}
        runs = [{"id": 2, "head_sha": "new", "status": "in_progress", "conclusion": None, "html_url": "pending"}]
        with patch.object(gate, "api", return_value={"workflow_runs": runs}):
            self.assertFalse(gate.check(source, "rock.yml"))

    def test_board_packages_select_newest_development_version(self):
        # Shell functions replace APT/dpkg; stop before any filesystem writes.
        setup = r"""
apt-cache() {
  printf '%s | 9.0 | https://dl.cloudsmith.io/public/openhd/release/deb/debian bullseye/main arm64 Packages\n' "$2"
  printf '%s | 1.0 | https://dl.cloudsmith.io/public/openhd/dev-release/deb/debian bullseye/main arm64 Packages\n' "$2"
  printf '%s | 2.0 | https://dl.cloudsmith.io/public/openhd/dev-release/deb/debian bullseye/main arm64 Packages\n' "$2"
}
dpkg() { [[ "$2" == 2.0 && "$4" == 1.0 ]]; }
apt-mark() { :; }
apt-get() { printf 'INSTALL %s\n' "$*"; exit 77; }
export OPENHD_COMPONENT_CHANNEL=dev-release
"""
        script = (ROOT / "additionalFiles/install-current-components.sh").read_text()
        cases = [("radxa-debian-rock3a", False, "qopenhd-rk3566=2.0"),
                 ("radxa-debian-rock5a", False, "qopenhd-rk3588=2.0"),
                 ("raspbian", False, "qopenhd=2.0"),
                 ("radxa-debian-rock5a", True, None)]
        for board, lite, expected in cases:
            with self.subTest(board=board, lite=lite):
                env = f"export OS={board} OPENHD_LITE_IMAGE={str(lite).lower()}\n"
                result = subprocess.run(["bash"], input=setup + env + script, text=True, capture_output=True)
                self.assertEqual(result.returncode, 77, result.stderr)
                self.assertIn("openhd=2.0", result.stdout)
                self.assertIn("open-hd-web-ui=2.0", result.stdout)
                self.assertNotIn("=9.0", result.stdout)
                if expected:
                    self.assertIn(expected, result.stdout)
                else:
                    self.assertNotIn("qopenhd", result.stdout)


if __name__ == "__main__":
    unittest.main()
