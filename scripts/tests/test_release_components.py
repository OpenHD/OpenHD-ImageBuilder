"""Check newest-package selection within the requested feed and board."""
from pathlib import Path
import subprocess
import tempfile
import unittest
import sys
sys.dont_write_bytecode = True

ROOT = Path(__file__).resolve().parents[2]


class ComponentSelectionTests(unittest.TestCase):
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
        # Reproduce an old base image whose source pin differs from the newest
        # indexed package. It must not prevent installation.
        with tempfile.TemporaryDirectory() as fixture:
            Path(fixture, "component-commits").write_text("openhd=oldcommit\n")
            script = (ROOT / "additionalFiles/install-current-components.sh").read_text()
            script = script.replace("/opt/additionalFiles", fixture)
            self.check_board_packages(setup, script)

    def check_board_packages(self, setup, script):
        cases = [("radxa-debian-rock3a", False, "qopenhd-native-rk3566=2.0"),
                 ("radxa-debian-rock5a", False, "qopenhd-native-rk3588=2.0"),
                 ("radxa-debian-rock5b", False, "qopenhd-native-rk3588=2.0"),
                 ("radxa-debian-rock-cm3", False, "qopenhd-native-rk3566=2.0"),
                 ("raspbian", False, "qopenhd=2.0"),
                 ("radxa-debian-rock5a", True, None),
                 ("debian-X20", False, None)]
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

    def test_missing_channel_package_fails_before_install(self):
        setup = r"""
apt-cache() {
  printf '%s | 9.0 | https://dl.cloudsmith.io/public/openhd/release/deb/debian bullseye/main arm64 Packages\n' "$2"
}
dpkg() { echo arm64; }
apt-get() { echo UNEXPECTED_INSTALL; exit 77; }
export OPENHD_COMPONENT_CHANNEL=dev-release
"""
        with tempfile.TemporaryDirectory() as fixture:
            script = (ROOT / "additionalFiles/install-current-components.sh").read_text()
            script = script.replace("/opt/additionalFiles", fixture)
            result = subprocess.run(["bash"], input=setup + script, text=True, capture_output=True)
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn("No dev-release package indexed for openhd", result.stderr)
        self.assertNotIn("UNEXPECTED_INSTALL", result.stdout)


if __name__ == "__main__":
    unittest.main()
