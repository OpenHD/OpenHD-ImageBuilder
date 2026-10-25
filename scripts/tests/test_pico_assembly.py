"""Check preservation boundaries and rejection of corrupt application overlays."""
import hashlib
import io
from pathlib import Path
import struct
import sys
import tarfile
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from assemble_pico_image import extract_applications, outside_digest, root_partition


class PicoAssemblyTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)

    def disk(self, last=31):
        data = bytearray(64 * 512)
        data[512:520] = b'EFI PART'
        struct.pack_into('<QII', data, 512 + 72, 2, 1, 128)
        data[1024:1040] = b'1' * 16
        struct.pack_into('<QQ', data, 1024 + 32, 16, last)
        name = 'rootfs'.encode('utf-16-le')
        data[1024 + 56:1024 + 56 + len(name)] = name
        path = self.root / 'disk.img'
        path.write_bytes(data)
        return path

    def test_partition_boundary_and_untouched_boot_data(self):
        disk = self.disk()
        offset, length = root_partition(disk)
        self.assertEqual((offset, length), (8192, 8192))
        expected = outside_digest(disk, offset, length)
        with disk.open('r+b') as stream:
            stream.seek(offset + 100)
            stream.write(b'applications')
        self.assertEqual(outside_digest(disk, offset, length), expected)
        with disk.open('r+b') as stream:
            stream.seek(offset - 1)
            stream.write(b'!')
        self.assertNotEqual(outside_digest(disk, offset, length), expected)

    def test_reject_partition_outside_disk(self):
        with self.assertRaisesRegex(ValueError, 'bounded'):
            root_partition(self.disk(100))

    def archive(self, name='usr/bin/openhd', content=b'new-app'):
        path = self.root / 'app.tar.gz'
        with tarfile.open(path, 'w:gz') as archive:
            entry = tarfile.TarInfo(name)
            entry.size = len(content)
            entry.mode = 0o755
            archive.addfile(entry, io.BytesIO(content))
        return path

    def test_overlay_checksum(self):
        dest = self.root / 'stage'
        dest.mkdir()
        manifest = {'files': {'usr/bin/openhd': hashlib.sha256(b'new-app').hexdigest()}}
        extract_applications(self.archive(), dest, manifest)
        self.assertEqual((dest / 'usr/bin/openhd').read_bytes(), b'new-app')
        with self.assertRaisesRegex(ValueError, 'checksum'):
            extract_applications(self.archive(content=b'tampered'), dest, manifest)

    def test_reject_application_path_escape(self):
        for name in ('../outside', '/outside', 'etc/shadow'):
            with self.subTest(name=name), self.assertRaises(ValueError):
                extract_applications(self.archive(name), self.root / 'stage', {'files': {}})


if __name__ == '__main__':
    unittest.main()
