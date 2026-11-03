from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from assemble_pico_nand_image import verify_runtime


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
