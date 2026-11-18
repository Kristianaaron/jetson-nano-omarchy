#!/usr/bin/env python3
"""Unpack an initramfs that may be a concatenation of a plain cpio and a
compressed cpio, which is how Arch Linux ARM builds it: a small early cpio
(microcode) followed by a gzip-compressed main archive.

Usage: unpack-initramfs.py <initramfs> <output.cpio>
"""
import gzip
import lzma
import sys


def find(data, magic, start):
    return data.find(magic, start)


def main():
    if len(sys.argv) != 3:
        print(__doc__)
        return 2
    src, dst = sys.argv[1], sys.argv[2]
    data = open(src, "rb").read()

    offset = find(data, b"\x1f\x8b\x08", 512)  # gzip
    kind = "gzip"
    if offset < 0:
        offset = find(data, b"\x28\xb5\x2f\xfd", 512)  # zstd
        kind = "zstd"
    if offset < 0:
        offset = find(data, b"\xfd7zXZ", 512)  # xz
        kind = "xz"

    if offset < 0:
        # Nothing compressed: assume the whole file is a cpio.
        open(dst, "wb").write(data)
        print(f"no compressed segment found, copied {len(data)} bytes")
        return 0

    blob = data[offset:]
    try:
        if kind == "gzip":
            out = gzip.decompress(blob)
        elif kind == "xz":
            out = lzma.decompress(blob)
        else:
            import subprocess
            out = subprocess.run(["zstd", "-dc"], input=blob, check=True,
                                 capture_output=True).stdout
    except Exception as exc:  # truncated trailing garbage is common
        print(f"warning: {kind} decompress failed ({exc}); trying gzip fallback")
        out = gzip.decompress(blob)

    open(dst, "wb").write(out)
    print(f"extracted {kind} segment at offset {offset}: {len(out)} bytes of cpio")
    return 0


if __name__ == "__main__":
    sys.exit(main())
