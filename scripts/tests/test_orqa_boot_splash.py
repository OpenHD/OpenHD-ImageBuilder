"""Reject ORQA images with an incomplete or disabled early splash payload."""
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / 'validate_orqa_ui.py'
spec = importlib.util.spec_from_file_location('validate_orqa_ui', SCRIPT)
validator = importlib.util.module_from_spec(spec)
spec.loader.exec_module(validator)


class BootSplashPayloadTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.runtime = self.root / 'usr/local/share/qopenhd-nxp'
        files = ['QOpenHD', 'weston', 'run-qopenhd.sh', 'run-weston.sh',
                 'nxp-boot-splash', 'boot-logo.png',
                 "plugins/geoservices/libqtgeoservices_mapboxgl.so",
                "plugins/geoservices/libqtgeoservices_osm.so", "plugins/sqldrivers/libqsqlite.so",
                "qml/QtLocation/qmldir", "qml/QtPositioning/qmldir",
                "lib/libssl.so.1.1", "lib/libcrypto.so.1.1", "certs/ca-certificates.crt",
                 'libweston-9/drm-backend.so',
                 'libweston-9/gl-renderer.so', 'weston-modules/kiosk-shell.so']
        manifest = dict(backend='hantro-wayland-dmabuf', media_frameworks=[], files={})
        for name in files:
            path = self.runtime / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(name.encode())
            path.chmod(0o755)
            manifest['files'][name] = hashlib.sha256(path.read_bytes()).hexdigest()
        (self.runtime / 'manifest.json').write_text(json.dumps(manifest))
        units = self.root / 'usr/lib/systemd/system'
        units.mkdir(parents=True)
        for name in ['qopenhd.service', 'qopenhd-nxp-compositor.service', 'openhd-nxp-boot-splash.service']:
            (units / name).write_text('[Service]\n')
        self.enabled = units / 'sysinit.target.wants/openhd-nxp-boot-splash.service'
        self.enabled.parent.mkdir()
        self.enabled.symlink_to('../openhd-nxp-boot-splash.service')
        output = self.root / 'etc/qopenhd-nxp/weston.ini'
        output.parent.mkdir(parents=True)
        output.write_text('[core]\n')

    def test_complete_boot_payload_passes(self):
        validator.validate(self.root, False)

    def test_missing_map_runtime_fails(self):
        for name in ['plugins/geoservices/libqtgeoservices_mapboxgl.so',
                     'plugins/sqldrivers/libqsqlite.so', 'lib/libssl.so.1.1',
                     'certs/ca-certificates.crt']:
            with self.subTest(name=name):
                path = self.runtime / name
                original = path.read_bytes()
                path.unlink()
                with self.assertRaisesRegex(ValueError, 'Invalid ORQA runtime manifest path'):
                    validator.validate(self.root, False)
                path.write_bytes(original)

    def test_missing_logo_fails(self):
        (self.runtime / 'boot-logo.png').unlink()
        with self.assertRaisesRegex(ValueError, 'Invalid ORQA runtime manifest path'):
            validator.validate(self.root, False)

    def test_unmanifested_splash_helper_fails(self):
        path = self.runtime / 'manifest.json'
        manifest = json.loads(path.read_text())
        del manifest['files']['nxp-boot-splash']
        path.write_text(json.dumps(manifest))
        with self.assertRaisesRegex(ValueError, 'Unmanifested ORQA component: nxp-boot-splash'):
            validator.validate(self.root, False)

    def test_disabled_early_splash_fails(self):
        self.enabled.unlink()
        with self.assertRaisesRegex(ValueError, 'not enabled'):
            validator.validate(self.root, False)

    def test_missing_early_service_fails(self):
        (self.enabled.parent.parent / 'openhd-nxp-boot-splash.service').unlink()
        with self.assertRaisesRegex(ValueError, 'Missing ORQA UI unit'):
            validator.validate(self.root, False)

    def test_nonexecutable_helper_fails(self):
        (self.runtime / 'nxp-boot-splash').chmod(0o644)
        with self.assertRaisesRegex(ValueError, 'not executable'):
            validator.validate(self.root, False)


if __name__ == '__main__':
    unittest.main()
