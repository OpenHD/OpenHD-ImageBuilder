import importlib.util
import struct
import unittest
import zlib
from pathlib import Path

spec = importlib.util.spec_from_file_location('capacity', Path(__file__).parents[1] / 'orqa_rootfs_capacity.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

def table(first=1024, last=1049599):
    data = bytearray(17408)
    entries = memoryview(data)[1024:]
    entries[:16] = bytes([1]) * 16
    struct.pack_into('<QQ', entries, 32, first, last)
    entries[56:68] = 'rootfs'.encode('utf-16le')
    header = memoryview(data)[512:1024]
    header[:8] = b'EFI PART'
    struct.pack_into('<I', header, 12, 92)
    struct.pack_into('<QQ', header, 40, 34, 2000000)
    struct.pack_into('<QIII', header, 72, 2, 128, 128, zlib.crc32(entries))
    struct.pack_into('<I', header, 16, zlib.crc32(header[:92]))
    return data

class CapacityTests(unittest.TestCase):
    def test_partition_capacity(self):
        self.assertEqual(module.rootfs_capacity(table()), 512 * 1024**2)
    def test_bad_header(self):
        data = table(); data[530] ^= 1
        with self.assertRaises(ValueError): module.rootfs_capacity(data)
    def test_bad_entries(self):
        data = table(); data[1100] ^= 1
        with self.assertRaises(ValueError): module.rootfs_capacity(data)
    def test_partition_outside_disk(self):
        with self.assertRaises(ValueError): module.rootfs_capacity(table(last=2000001))

if __name__ == '__main__': unittest.main()
