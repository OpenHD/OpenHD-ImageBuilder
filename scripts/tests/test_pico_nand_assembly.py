from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from assemble_pico_nand_image import verify_runtime, install_config_mount


class NandRuntimeTest(unittest.TestCase):
    def root(self, directory):
        root = Path(directory)
        header = b'\x7fELF\x01\x01' + bytes(12) + b'\x28\x00'
        for name in ('usr/bin/openhd', 'usr/bin/openhd_sys_utils', 'usr/lib/librockit.so', 'usr/lib/librkaiq.so'):
            path = root / name; path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(header + b'Devourer identified packet-address=mb-valid')
        for name in ('usr/local/share/OpenHD/SysUtils/wifi_cards.json', 'lib/modprobe.d/openhd-devourer-eu.conf', 'usr/sbin/usb_modeswitch', 'usr/sbin/openhd-usb-power-recover'):
            path = root / name; path.parent.mkdir(parents=True, exist_ok=True); path.write_bytes(b'fixture')
        return root

    def test_reusable_seed_gets_current_config_mount_startup(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / 'root'; sdk = Path(directory) / 'sdk'
            name = 'etc/init.d/S25openhd-nand'
            old = root / name; old.parent.mkdir(parents=True); old.write_text('old symlink startup')
            source = sdk / 'project/cfg/BoardConfig_IPC/overlay/overlay-openhd-pico-nand' / name
            source.parent.mkdir(parents=True)
            source.write_text('#!/bin/sh\nmount --bind /userdata/Config /Config\n')
            install_config_mount(root, sdk)
            self.assertEqual(old.read_bytes(), source.read_bytes())
            source.write_text('old symlink startup')
            with self.assertRaisesRegex(ValueError, 'real persistent'):
                install_config_mount(root, sdk)

    def test_rejects_gstreamer_and_missing_transitive_runtime(self):
        for library in ('libgstreamer-1.0.so.0', 'libmissing.so.1'):
            with self.subTest(library=library), tempfile.TemporaryDirectory() as directory:
                root = self.root(directory)
                with patch('assemble_pico_nand_image.subprocess.check_output', return_value=f'(NEEDED) Shared library: [{library}]'):
                    with self.assertRaises(ValueError):
                        verify_runtime(root)

    def test_native_devourer_runtime_is_required(self):
        with tempfile.TemporaryDirectory() as directory:
            root = self.root(directory)
            with patch('assemble_pico_nand_image.subprocess.check_output', return_value=''):
                self.assertEqual(verify_runtime(root), 2)
                (root / 'usr/bin/openhd').write_bytes((root / 'usr/bin/openhd').read_bytes().replace(b'Devourer identified', b'no radio backend  '))
                with self.assertRaisesRegex(ValueError, 'Devourer'):
                    verify_runtime(root)
