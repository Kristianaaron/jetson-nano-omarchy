#!/usr/bin/env python3
"""Write a minimal GPT with one Linux partition, no EFI partition.

macOS's diskutil always inserts a 200 MB EFI System Partition first on GPT, so
the data lands on p2. The Jetson bootloader looks at the first partition, so the
root filesystem must be p1. This writes the table itself.

Usage:
  make-gpt.py <device> <size_bytes> [start_lba] [label]
  make-gpt.py --prefix /tmp/gpt --size <bytes> [start_lba] [label]

The first form writes the table straight to a device (needs write permission).
The second writes two files, <prefix>.head (LBA 0..33) and <prefix>.tail (the
last 33 sectors), so a caller that is not root can feed them to dd.

Only the table is written: protective MBR (LBA 0), primary header (LBA 1),
entry array (LBA 2..33), backup entries and header at the end of the device.
The caller formats the partition afterwards.
"""
import os
import struct
import sys
import uuid
import zlib

LINUX_FS = "0FC63DAF-8483-4772-8E79-3D69D8477DE4"
FAT32 = "EBD0A0A2-B9E5-4433-87C0-68B6B72699C7"
SECTOR = 512
ENTRIES = 128
ENTRY_SIZE = 128


def guid_bytes(text):
    return uuid.UUID(text).bytes_le


def entry(type_guid, unique_guid, first, last, name):
    e = bytearray(ENTRY_SIZE)
    e[0:16] = guid_bytes(type_guid)
    e[16:32] = guid_bytes(unique_guid)
    e[32:40] = struct.pack("<Q", first)
    e[40:48] = struct.pack("<Q", last)
    e[48:56] = struct.pack("<Q", 0)
    enc = name.encode("utf-16-le")[:72]
    e[56:56 + len(enc)] = enc
    return bytes(e)


def header(current, backup, first_usable, last_usable, disk_guid, entries_lba, entries_crc):
    h = bytearray(92)
    h[0:8] = b"EFI PART"
    h[8:12] = struct.pack("<I", 0x00010000)
    h[12:16] = struct.pack("<I", 92)
    h[16:20] = b"\x00\x00\x00\x00"  # crc placeholder
    h[20:24] = struct.pack("<I", 0)
    h[24:32] = struct.pack("<Q", current)
    h[32:40] = struct.pack("<Q", backup)
    h[40:48] = struct.pack("<Q", first_usable)
    h[48:56] = struct.pack("<Q", last_usable)
    h[56:72] = guid_bytes(disk_guid)
    h[72:80] = struct.pack("<Q", entries_lba)
    h[80:84] = struct.pack("<I", ENTRIES)
    h[84:88] = struct.pack("<I", ENTRY_SIZE)
    h[88:92] = struct.pack("<I", entries_crc)
    crc = zlib.crc32(bytes(h)) & 0xFFFFFFFF
    h[16:20] = struct.pack("<I", crc)
    return bytes(h)


def main():
    args = sys.argv[1:]
    prefix = None
    if args and args[0] == "--prefix":
        prefix = args[1]
        args = args[2:]
        if len(args) < 2 or args[0] != "--size":
            print(__doc__)
            return 2
        size = int(args[1])
        rest = args[2:]
    else:
        if len(args) < 2:
            print(__doc__)
            return 2
        size = int(args[1])
        rest = args[2:]
    start = int(rest[0]) if len(rest) > 0 else 2048
    label = rest[1] if len(rest) > 1 else "ALARM"
    fat_mb = int(os.environ.get("FAT_MB", "0"))

    total = size // SECTOR
    last = total - 1
    first_usable = 34
    last_usable = last - 33
    if start < first_usable or start >= last_usable:
        print(f"bad start lba {start}", file=sys.stderr)
        return 2

    disk_guid = str(uuid.uuid4()).upper()
    part_guid = str(uuid.uuid4()).upper()

    entries = bytearray(ENTRIES * ENTRY_SIZE)
    if fat_mb:
        fat_last = start + (fat_mb * 1024 * 1024 // SECTOR) - 1
        linux_start = fat_last + 1
        entries[0:ENTRY_SIZE] = entry(FAT32, str(uuid.uuid4()).upper(), start, fat_last, "BOOT")
        entries[ENTRY_SIZE:2 * ENTRY_SIZE] = entry(
            LINUX_FS, part_guid, linux_start, last_usable, label)
        print(f"  p1 FAT32 lba {start}..{fat_last}, p2 Linux lba {linux_start}..{last_usable}")
    else:
        entries[0:ENTRY_SIZE] = entry(LINUX_FS, part_guid, start, last_usable, label)
    entries = bytes(entries)
    entries_crc = zlib.crc32(entries) & 0xFFFFFFFF

    mbr = bytearray(SECTOR)
    mbr[446 + 4] = 0xEE
    mbr[446 + 8:446 + 12] = struct.pack("<I", 1)
    mbr[446 + 12:446 + 16] = struct.pack("<I", min(total - 1, 0xFFFFFFFF))
    mbr[510:512] = b"\x55\xAA"

    primary = header(1, last, first_usable, last_usable, disk_guid, 2, entries_crc)
    backup_entries_lba = last - 32
    backup = header(last, 1, first_usable, last_usable, disk_guid, backup_entries_lba, entries_crc)

    if prefix:
        with open(prefix + ".head", "wb") as f:
            f.write(bytes(mbr))
            f.write(primary.ljust(SECTOR, b"\x00"))
            f.write(entries)
        with open(prefix + ".tail", "wb") as f:
            f.write(entries)
            f.write(backup)
        print(f"wrote {prefix}.head and {prefix}.tail: p1 lba {start}..{last_usable}")
        return 0

    dev = sys.argv[1]
    with open(dev, "r+b", buffering=0) as f:
        f.seek(0)
        f.write(bytes(mbr))
        # LBA 1 holds the header padded to a full sector; the entry array starts
        # at LBA 2 exactly, not immediately after the 92-byte header.
        f.write(primary.ljust(SECTOR, b"\x00"))
        f.write(entries)
        f.seek(backup_entries_lba * SECTOR)
        f.write(entries)
        f.seek(last * SECTOR)
        f.write(backup)
        f.flush()
        os.fsync(f.fileno())

    print(f"wrote GPT to {dev}: p1 lba {start}..{last_usable}, label {label}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
