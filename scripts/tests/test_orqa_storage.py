import importlib.util
import struct
import sys
import unittest
import uuid
import zlib
from pathlib import Path

sys.path.insert(0,str(Path(__file__).parents[1]))
from prepare_orqa_storage import layout, BASIC_DATA
from test_orqa_capacity import table

def vendor_table():
    data=table()
    entries=memoryview(data)[1024:]
    names=['kernel','recovery','nvram','rootfs','data']
    bounds=[(16384,147455),(147456,409599),(409600,540671),(540672,4734975),(4734976,7634910)]
    entries[:]=bytes(len(entries))
    for i,(name,(first,last)) in enumerate(zip(names,bounds)):
        entry=entries[i*128:(i+1)*128]
        entry[:16]=uuid.UUID('0fc63daf-8483-4772-8e79-3d69d8477de4').bytes_le
        entry[16:32]=uuid.uuid5(uuid.NAMESPACE_DNS,name).bytes_le
        struct.pack_into('<QQ',entry,32,first,last)
        label=name.encode('utf-16le');entry[56:56+len(label)]=label
    struct.pack_into('<QQ',data,512+40,34,7634910)
    struct.pack_into('<I',data,512+88,zlib.crc32(entries))
    struct.pack_into('<I',data,512+16,0)
    struct.pack_into('<I',data,512+16,zlib.crc32(data[512:512+92]))
    return data

class StorageTests(unittest.TestCase):
    def test_preserve_vendor_boot_layout_and_bounds(self):
        original=vendor_table();modified,parts=layout(original)
        self.assertEqual(original[1024:1024+4*128],modified[1024:1024+4*128])
        self.assertEqual([p[0] for p in parts],['data','config','recordings'])
        self.assertEqual(parts[0][1],4734976)
        self.assertEqual(parts[-1][2],7634910)
        for left,right in zip(parts,parts[1:]):self.assertEqual(left[2]+1,right[1])
        self.assertEqual(modified[1024+5*128:1024+5*128+16],BASIC_DATA)
    def test_reject_repartitioning_prepared_bundle(self):
        modified,_=layout(vendor_table())
        with self.assertRaises(ValueError):layout(modified)
    def test_reject_corrupt_vendor_table(self):
        data=vendor_table();data[1500]^=1
        with self.assertRaises(ValueError):layout(data)

if __name__=='__main__': unittest.main()
