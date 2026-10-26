"""Add Windows-readable config and recording volumes to a fresh ORQA flash bundle.

The first four vendor partitions keep their exact indices, GUIDs and LBAs.
The old data extent is divided into data (128 MiB), config (128 MiB) and
recordings (remaining space). This changes a fresh-flash package, never a disk.
"""
import argparse
import json
import struct
import subprocess
import tempfile
import uuid
import zlib
from pathlib import Path
from orqa_rootfs_capacity import rootfs_capacity

MIB_SECTORS = 2048
BASIC_DATA = uuid.UUID('ebd0a0a2-b9e5-4433-87c0-68b6b72699c7').bytes_le

def layout(data: bytes):
    rootfs_capacity(data)  # validates both GPT checksums and rootfs bounds
    result = bytearray(data)
    lba, count, size = struct.unpack_from('<QII', result, 512+72)
    start = lba*512
    entries = bytearray(result[start:start+count*size])
    existing = []
    for i in range(count):
        entry = entries[i*size:(i+1)*size]
        if any(entry[:16]):
            existing.append((i, entry[56:128].decode('utf-16le').rstrip('\0')))
    if existing != [(0,'kernel'), (1,'recovery'), (2,'nvram'), (3,'rootfs'), (4,'data')]:
        raise ValueError('Expected the unmodified five-partition ORQA vendor layout')
    first, last = struct.unpack_from('<QQ', entries, 4*size+32)
    if first % MIB_SECTORS:
        raise ValueError('Vendor data partition must start on a MiB boundary')
    data_last = first+128*MIB_SECTORS-1
    config_first, config_last = data_last+1, data_last+128*MIB_SECTORS
    video_first = config_last+1
    if (last-video_first+1) < 256*MIB_SECTORS:
        raise ValueError('Insufficient space for ORQA recording volume')
    struct.pack_into('<QQ', entries, 4*size+32, first, data_last)
    partitions = [('data',first,data_last,'ext4'), ('config',config_first,config_last,'vfat'),
                  ('recordings',video_first,last,'vfat')]
    disk_guid = uuid.UUID(bytes_le=bytes(result[512+56:512+72]))
    for i, (name, lo, hi, _) in enumerate(partitions[1:], start=5):
        entry = bytearray(size)
        entry[:16] = BASIC_DATA
        entry[16:32] = uuid.uuid5(disk_guid, 'openhd-'+name).bytes_le
        struct.pack_into('<QQQ', entry, 32, lo, hi, 0)
        label = name.encode('utf-16le'); entry[56:56+len(label)] = label
        entries[i*size:(i+1)*size] = entry
    result[start:start+len(entries)] = entries
    struct.pack_into('<I',result,512+88,zlib.crc32(entries))
    header_size = struct.unpack_from('<I',result,512+12)[0]
    struct.pack_into('<I',result,512+16,0)
    struct.pack_into('<I',result,512+16,zlib.crc32(result[512:512+header_size]))
    rootfs_capacity(result)
    return bytes(result), partitions

def prepare(bundle: Path):
    gpt = bundle/'partition-table.img'
    modified, partitions = layout(gpt.read_bytes())
    script = bundle/'uuu.auto'
    text = script.read_text()
    anchor = 'FB[-t 30000]: flash -raw2sparse rootfs rootfs.img'
    if text.count(anchor) != 1:
        raise ValueError('Unexpected vendor UUU rootfs flash command')
    text = text.replace(anchor, anchor+'\n'+ '\n'.join(
        f'FB[-t 30000]: flash -raw2sparse {name} {name}.img' for name, *_ in partitions))
    with tempfile.TemporaryDirectory(prefix='orqa-config-') as temporary:
        seed = Path(temporary)
        (seed/'openhd').mkdir()
        (seed/'README.txt').write_text(
            'OpenHD NXP configuration\n\n'
            'Default role: Air. To select Ground create an empty openhd/ground.txt.\n'
            'To select Air create an empty openhd/air.txt. Mode markers are consumed on boot.\n'
            'settings.json at this volume root (or openhd/settings.json) uses the normal SysUtils schema.\n'
            'Keep only one role marker. Safely eject before removing storage.\n'
            'The separate recordings volume is mounted at /Video. FAT32 limits each file to 4 GiB.\n'
            'A recording partition alone does not enable recording in a video backend.\n', encoding='ascii')
        (seed/'openhd/ground.txt.example').write_text('Rename this file to ground.txt to select Ground.\n')
        (seed/'openhd/air.txt.example').write_text('Rename this file to air.txt to select Air.\n')
        for name, lo, hi, fs in partitions:
            image = bundle/(name+'.img')
            with image.open('wb') as output:
                output.truncate((hi-lo+1)*512)
            if fs == 'ext4':
                subprocess.run(['mkfs.ext4','-F','-L','data',str(image)],check=True)
            else:
                label = 'openhd' if name == 'config' else 'recordings'
                subprocess.run(['mkfs.vfat','-F','32','-n',label,str(image)],check=True)
                if name == 'config':
                    subprocess.run(['mcopy','-s','-i',str(image),str(seed/'README.txt'),str(seed/'openhd'),'::/'],check=True)
                else:
                    (seed/'external_video_part.txt').write_text('OpenHD recording partition\n')
                    subprocess.run(['mcopy','-i',str(image),str(seed/'external_video_part.txt'),'::/'],check=True)
    gpt.write_bytes(modified)
    script.write_text(text)
    (bundle/'openhd-storage.json').write_text(json.dumps(dict(schema_version=1, partitions=[
        dict(name=n, first_lba=lo, last_lba=hi, filesystem=fs) for n,lo,hi,fs in partitions]),indent=2)+'\n')

if __name__ == '__main__':
    p=argparse.ArgumentParser(description=__doc__); p.add_argument('bundle',type=Path)
    prepare(p.parse_args().bundle)
