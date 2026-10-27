"""Exercise full/Lite boundaries, image boot arguments and GPU/DDK selection."""
import importlib.util
from pathlib import Path
import subprocess
import tempfile
import unittest
import yaml
import sys
sys.dont_write_bytecode = True

ROOT = Path(__file__).resolve().parents[2]


def module(name):
    spec = importlib.util.spec_from_file_location(name.replace('-', '_'), ROOT / 'additionalFiles' / (name + '.py'))
    loaded = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(loaded)
    return loaded


class NativeImages(unittest.TestCase):
    def test_lite_and_other_platforms_never_touch_runtime(self):
        script = ROOT / 'additionalFiles/configure-rockchip-native.sh'
        for board, lite in [('radxa-debian-rock5a', True), ('radxa-debian-rock3a', True), ('raspbian', False), ('ubuntu-x86', False)]:
            with self.subTest(board=board, lite=lite), tempfile.TemporaryDirectory() as fixture:
                env = dict(__import__('os').environ, OS=board, OPENHD_LITE_IMAGE=str(lite).lower(), OPENHD_IMAGE_ROOT=fixture)
                subprocess.run(['bash', str(script)], env=env, check=True)
                self.assertEqual(list(Path(fixture).iterdir()), [])

    def test_full_image_rejects_legacy_package_before_boot_changes(self):
        with tempfile.TemporaryDirectory() as fixture:
            env = dict(__import__('os').environ, OS='radxa-debian-rock3a', OPENHD_LITE_IMAGE='false', OPENHD_IMAGE_ROOT=fixture)
            result = subprocess.run(['bash', str(ROOT / 'additionalFiles/configure-rockchip-native.sh')], env=env, capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertFalse((Path(fixture) / 'etc').exists())

    def test_full_image_installs_complete_runtime_and_is_idempotent(self):
        with tempfile.TemporaryDirectory() as fixture:
            root = Path(fixture)
            base = root / 'usr/local/share/qopenhd-rockchip'
            base.mkdir(parents=True)
            # ImageBuilder CI checks out this repository alone. Model the package
            # contract here; QOpenHD CI verifies the actual packaged templates.
            deployment = base / 'deployment'
            deployment.mkdir()
            for name, target in [('qopenhd.service', 'multi-user.target'),
                                 ('qopenhd-rockchip-compositor.service', 'multi-user.target'),
                                 ('openhd-rockchip-boot-splash.service', 'sysinit.target')]:
                (deployment / name).write_text(
                    '[Unit]\nDescription=Native package fixture\n[Service]\nExecStart=/bin/true\n'
                    f'[Install]\nWantedBy={target}\n')
            (deployment / 'weston.ini').write_text('[shell]\nbackground-color=0xff000000\n')
            (deployment / 'openhd-video-native.conf').write_text(
                '[Unit]\nConditionPathExists=!/etc/qopenhd-rockchip/native-video-enabled\n')
            for name in ['QOpenHD', 'openhd-boot-splash', 'boot-logo.png', 'mali/egl-platform-compat.so']:
                path = base / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(b'packaged runtime fixture')
            (base / 'native-video.version').write_text('1\n')
            binary = root / 'usr/local/bin/openhd_sys_utils'
            binary.parent.mkdir(parents=True)
            binary.write_bytes(b'rockchip_native')
            status = root / 'var/lib/dpkg/status'
            status.parent.mkdir(parents=True)
            status.write_text('Package: libegl-mesa0\nStatus: install ok installed\n')
            boot = root / 'boot/extlinux/extlinux.conf'
            boot.parent.mkdir(parents=True)
            boot.write_text('APPEND root=UUID=test console=tty1\n')
            target = root / 'usr/lib/systemd/system/multi-user.target'
            target.parent.mkdir(parents=True)
            target.write_text('[Unit]\nDescription=Multi-user test fixture\n')
            for unit in ['openhd.service', 'openhd-sys-utils.service']:
                (target.parent / unit).write_text('[Unit]\nDescription=OpenHD fixture\n[Service]\nExecStart=/bin/true\n[Install]\nWantedBy=multi-user.target\n')
            env = dict(__import__('os').environ, OS='radxa-debian-rock3a', OPENHD_LITE_IMAGE='false', OPENHD_IMAGE_ROOT=fixture)
            command = ['bash', str(ROOT / 'additionalFiles/configure-rockchip-native.sh')]
            result = subprocess.run(command, env=env, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertTrue((root / 'etc/qopenhd-rockchip/native-video-enabled').is_file())
            early = root / 'etc/systemd/system/sysinit.target.wants/openhd-rockchip-boot-splash.service'
            self.assertTrue(early.is_symlink())
            self.assertFalse((root / 'etc/systemd/system/multi-user.target.wants/qopenhd.service').exists())
            first = boot.read_text()
            result = subprocess.run(command, env=env, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(boot.read_text(), first)

    def test_silent_boot_preserves_root_device_tree_and_serial(self):
        quiet = module('rockchip-silent-boot')
        with tempfile.TemporaryDirectory() as fixture:
            root = Path(fixture)
            ext = root / 'boot/extlinux/extlinux.conf'
            ext.parent.mkdir(parents=True)
            original = 'LABEL primary\n LINUX /Image\n INITRD /initrd.img\n FDT /dtb/rockchip/rk3568-rock-3a.dtb\n APPEND root=UUID=abc rw console=ttyFIQ0,1500000 console=tty1 loglevel=7 rootwait\n'
            ext.write_text(original)
            kernel = root / 'etc/kernel/cmdline'
            kernel.parent.mkdir(parents=True)
            kernel.write_text('root=UUID=abc console=tty1\n')
            quiet.configure(root)
            first = ext.read_text()
            self.assertIn('root=UUID=abc rw console=ttyFIQ0,1500000 rootwait', first)
            for line in original.splitlines()[:4]:
                self.assertIn(line, first)
            self.assertNotIn('console=tty1', first)
            self.assertIn('loglevel=0', first)
            self.assertIn('systemd.show_status=false', first)
            quiet.configure(root)
            self.assertEqual(ext.read_text(), first)
            self.assertEqual(kernel.read_text().count('console=tty3'), 1)

    def test_matching_mali_driver_never_crosses_gpu_or_ddk(self):
        mali = module('rockchip-mali-runtime')
        for name, expected in [('libmali-bifrost-g52-g2p0-x11-gbm', 'bifrost-g52-g2p0'),
                               ('libmali-bifrost-g52-g13p0-x11-wayland-gbm', 'bifrost-g52-g13p0'),
                               ('libmali-valhall-g610-g6p0-x11-gbm', 'valhall-g610-g6p0')]:
            status = f'Package: {name}\nStatus: install ok installed\nVersion: 1.9\n'
            self.assertEqual(mali.select_driver(status), expected)
            self.assertIsNone(mali.select_driver(status.replace('install ok installed', 'deinstall ok config-files')))
        with self.assertRaises(ValueError):
            mali.select_driver('Package: libmali-valhall-g610-g99p0-x11-gbm\nStatus: install ok installed\n')
        self.assertIsNone(mali.select_driver('Package: libegl-mesa0\nStatus: install ok installed\n'))

    def test_lite_build_targets_are_removed(self):
        workflow = yaml.safe_load((ROOT / '.github/workflows/update-image.yml').read_text())
        self.assertFalse(any('lite' in name for name in workflow['jobs']))
        self.assertEqual(list((ROOT / 'images').glob('*-lite*')), [])
        for job in workflow['jobs'].values():
            targets = job.get('strategy', {}).get('matrix', {}).get('target', [])
            self.assertFalse(any('lite' in target for target in targets))
        # PyYAML's YAML 1.1 loader treats the unquoted GitHub "on" key as True.
        trigger = workflow.get('on', workflow.get(True))
        self.assertNotIn('lite', trigger['workflow_dispatch']['inputs']['target']['options'])
        targets = workflow['jobs']['full-images']['strategy']['matrix']['target']
        self.assertTrue({'rock5a', 'rock5b', 'radxa-rock3a', 'radxa-zero3w'}.issubset(targets))


if __name__ == '__main__':
    unittest.main()
