"""Exercise real password hashing and Pico recording storage decisions."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from pico_image_setup import install_ssh_login, install_recordings


class ImageSetupTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)

    def test_ssh_password_and_existing_accounts(self):
        etc = self.root / 'etc'
        (etc / 'ssh').mkdir(parents=True)
        (etc / 'passwd').write_text('root:x:0:0:root:/root:/bin/sh\nother:x:1000:1000::/home/other:/bin/sh\n')
        (etc / 'group').write_text('root:x:0:\nother:x:1000:\n')
        (etc / 'shadow').write_text('root:keep:1:0:99999:7:::\n')
        (etc / 'ssh/sshd_config').write_text('PasswordAuthentication no\nAllowUsers root\nMatch User root\n  PasswordAuthentication no\n')
        install_ssh_login(self.root)
        install_ssh_login(self.root)
        passwd = (etc / 'passwd').read_text()
        self.assertEqual(sum(line.startswith('openhd:') for line in passwd.splitlines()), 1)
        self.assertIn('openhd:x:1001:1001:OpenHD:/home/openhd:/bin/sh', passwd)
        shadow = (etc / 'shadow').read_text()
        self.assertIn('root:keep:', shadow)
        hashed = next(s.split(':')[1] for s in shadow.splitlines() if s.startswith('openhd:'))
        salt = hashed.split('$')[2]
        expected = subprocess.check_output(['openssl', 'passwd', '-6', '-salt', salt, '-stdin'], input='openhd\n', text=True).strip()
        self.assertEqual(hashed, expected)
        self.assertEqual((self.root / 'home/openhd').stat().st_uid, 1001)
        self.assertTrue((etc / 'ssh/sshd_config').read_text().startswith('PasswordAuthentication yes\n'))
        self.assertIn('AllowUsers root openhd', (etc / 'ssh/sshd_config').read_text())

    def startup(self, devices='', mount_result=0, already_mounted=False,
                legacy_mounted=False, mounts='ubi0:rootfs / ubifs rw 0 0\n'):
        install_recordings(self.root)
        script = self.root / 'etc/init.d/S97openhd-recordings'
        text = script.read_text()
        for path in ('/proc/mounts', '/Config', '/usr/local/share/openhd', '/Video', '/sys/bus/platform/drivers/dwmmc_rockchip'):
            text = text.replace(path, str(self.root) + path)
        script.write_text(text)
        mounts_file = self.root / 'proc/mounts'
        mounts_file.parent.mkdir(exist_ok=True)
        mounts_file.write_text(mounts.replace('/Config', str(self.root) + '/Config').replace('/Video', str(self.root) + '/Video'))
        tools = self.root / 'bin'; tools.mkdir(exist_ok=True)
        for name, body in {
            'blkid': 'cat ' + str(self.root / 'devices'),
            'mountpoint': f'case "$2" in {self.root}/Video) exit {0 if already_mounted else 1} ;; {self.root}/Videos) exit {0 if legacy_mounted else 1} ;; *) exit 1 ;; esac',
            'mount': 'echo "$@" >> ' + str(self.root / 'mount-calls') + '; exit ' + str(mount_result),
        }.items():
            path = tools / name; path.write_text('#!/bin/sh\n' + body + '\n'); path.chmod(0o755)
        (self.root / 'devices').write_text(devices)
        return subprocess.run(['/bin/sh', str(script), 'start'], env=dict(os.environ, PATH=str(tools) + ':' + os.environ['PATH']), capture_output=True, text=True)

    def settings(self, mode):
        path = self.root / 'usr/local/share/openhd/video/LUCKFOX_MIS5001_0.json'
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(dict(air_recording=mode, qp_min=8)))
        return path

    def test_first_mount_enables_recording_once_and_preserves_user_choice(self):
        settings = self.settings(0)
        card = '/dev/mmcblk1p1: LABEL="RECORDINGS" UUID="1234"\n'
        self.assertEqual(self.startup(card).returncode, 0)
        self.assertEqual(json.loads(settings.read_text()), dict(air_recording=1, qp_min=8))
        self.settings(0)
        self.assertEqual(self.startup(card).returncode, 0)
        self.assertEqual(json.loads(settings.read_text())['air_recording'], 0)

    def test_missing_card_suspends_and_restores_mode(self):
        settings = self.settings(2)
        (self.root / 'Config').mkdir(parents=True)
        (self.root / 'Config/.sd-recording-initialized').touch()
        self.assertEqual(self.startup().returncode, 0)
        self.assertEqual(json.loads(settings.read_text())['air_recording'], 0)
        self.assertFalse((self.root / 'mount-calls').exists())
        self.assertEqual(self.startup('/dev/mmcblk1p1: LABEL="RECORDINGS"\n').returncode, 0)
        self.assertEqual(json.loads(settings.read_text())['air_recording'], 2)

    def test_failed_mount_and_ambiguous_cards_do_not_enable_recording(self):
        settings = self.settings(0)
        card = '/dev/mmcblk1p1: LABEL="RECORDINGS"\n'
        self.assertNotEqual(self.startup(card, mount_result=1).returncode, 0)
        self.assertEqual(json.loads(settings.read_text())['air_recording'], 0)
        self.assertFalse((self.root / 'Config/.sd-recording-initialized').exists())
        self.assertEqual(self.startup(card + '/dev/mmcblk2p1: LABEL="RECORDINGS"\n').returncode, 0)
        self.assertEqual(json.loads(settings.read_text())['air_recording'], 0)

    def test_sd_and_emmc_roots_mount_dedicated_recording_partition(self):
        for root_device in ('/dev/mmcblk1p4', '/dev/mmcblk0p4'):
            with self.subTest(root_device=root_device):
                self.settings(0)
                result = self.startup('/dev/mmcblk1p7: LABEL="RECORDINGS"\n',
                                      mounts=f'{root_device} / ext4 rw 0 0\n')
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn('-o noatime /dev/mmcblk1p7', (self.root / 'mount-calls').read_text())
                self.assertTrue((self.root / 'Video/external_video_part.txt').exists())

    def test_legacy_videos_mount_is_reused_without_reformatting(self):
        self.settings(0)
        mounts = '/dev/mmcblk0p4 / ext4 rw 0 0\n/dev/mmcblk0p7 /Videos vfat rw 0 0\n'
        result = self.startup(legacy_mounted=True, mounts=mounts)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(f'--bind {self.root}/Videos {self.root}/Video', (self.root / 'mount-calls').read_text())

    def test_existing_video_mount_is_used_without_mounting_again(self):
        self.settings(0)
        mounts = '/dev/mmcblk1p4 / ext4 rw 0 0\n/dev/mmcblk1p7 /Video vfat rw 0 0\n'
        result = self.startup(already_mounted=True, mounts=mounts)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse((self.root / 'mount-calls').exists())

    def test_root_config_and_tmpfs_are_never_used_as_recording_storage(self):
        for storage, mounts in (
            ('/dev/mmcblk1p4', '/dev/mmcblk1p4 / ext4 rw 0 0\n'),
            ('/dev/mmcblk1p5', '/dev/mmcblk1p4 / ext4 rw 0 0\n/dev/mmcblk1p5 /Config ext4 rw 0 0\n'),
            ('tmpfs', '/dev/mmcblk1p4 / ext4 rw 0 0\n'),
        ):
            with self.subTest(storage=storage):
                settings = self.settings(1)
                result = self.startup(already_mounted=True, mounts=mounts + f'{storage} /Video ext4 rw 0 0\n')
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(json.loads(settings.read_text())['air_recording'], 0)
                self.assertFalse((self.root / 'mount-calls').exists())


if __name__ == '__main__':
    unittest.main()
