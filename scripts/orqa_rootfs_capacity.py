"""Read the rootfs partition size from the ORQA primary GPT flash payload."""
import struct
import sys
import zlib
from pathlib import Path

def rootfs_capacity(data: bytes) -> int:
    header = bytearray(data[512:1024])
    if len(header) != 512 or header[:8] != b"EFI PART":
        raise ValueError("ORQA partition table has no primary GPT header")
    size, checksum = struct.unpack_from("<II", header, 12)
    if not 92 <= size <= 512:
        raise ValueError("Invalid GPT header size")
    struct.pack_into("<I", header, 16, 0)
    if zlib.crc32(header[:size]) != checksum:
        raise ValueError("Invalid GPT header checksum")
    lba, count, entry_size, entries_crc = struct.unpack_from("<QIII", header, 72)
    if entry_size < 128 or count > 4096:
        raise ValueError("Invalid GPT entries")
    entries = data[lba * 512:lba * 512 + count * entry_size]
    if len(entries) != count * entry_size or zlib.crc32(entries) != entries_crc:
        raise ValueError("Invalid GPT entries checksum")
    first_usable, last_usable = struct.unpack_from("<QQ", header, 40)
    matches = []
    for offset in range(0, len(entries), entry_size):
        entry = entries[offset:offset + entry_size]
        if not any(entry[:16]):
            continue
        name = entry[56:128].decode("utf-16le").rstrip("\0")
        if name == "rootfs":
            first, last = struct.unpack_from("<QQ", entry, 32)
            if not first_usable <= first <= last <= last_usable:
                raise ValueError("rootfs partition is outside the GPT usable range")
            matches.append((last - first + 1) * 512)
    if len(matches) != 1 or not 64 * 1024**2 <= matches[0] <= 64 * 1024**3:
        raise ValueError("Expected exactly one bounded ORQA rootfs partition")
    return matches[0]

if __name__ == "__main__":
    print(rootfs_capacity(Path(sys.argv[1]).read_bytes()))
