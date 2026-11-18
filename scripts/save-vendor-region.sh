#!/bin/bash
# Save the Tegra boot region (first 26880 sectors, ~13 MB) from a working card
# to a file, so an experimental card can be laid out exactly like it.
#
# The region contains the GPT and the bootloader partitions TBC, RP1, EBT, WB0,
# BPF, BPF-DTB, FX, TOS, DTB, LNX, EKS, BMP, RP4, with APP starting at LBA 28672.
#
# Usage: bash save-vendor-region.sh [--card /dev/disk4] [--out FILE]
set -euo pipefail

CARD=/dev/disk4
OUT="$HOME/nano-boot-region.img"
while (($#)); do
  case "$1" in
    --card) CARD=${2:-}; shift 2 ;;
    --out) OUT=${2:-}; shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 1 ;;
  esac
done

[[ -b $CARD ]] || { echo "$CARD is not a block device" >&2; exit 1; }
sudo -n /usr/sbin/diskutil info "$CARD" >/dev/null 2>&1 || { echo "sudo -n failed" >&2; exit 1; }

echo ">> reading the boot region from $CARD"
sudo -n /bin/dd if="$CARD" of="$OUT" bs=512 count=26880 2>/dev/null
actual=$(stat -f%z "$OUT")
[[ $actual -eq $((26880 * 512)) ]] || { echo "short read: $actual bytes" >&2; exit 1; }

# Sanity: the region must start with a protective MBR and contain the partitions.
python3 - "$OUT" <<'PY'
import struct, sys, uuid
d = open(sys.argv[1], "rb").read()
assert d[510:512] == b"\x55\xaa", "no MBR signature"
assert d[512:520] == b"EFI PART", "no GPT header"
hdr = d[512:604]
ent_lba = struct.unpack("<Q", hdr[72:80])[0]
num, esz = struct.unpack("<II", hdr[80:88])
names = {}
for i in range(num):
    e = d[ent_lba * 512 + i * esz: ent_lba * 512 + (i + 1) * esz]
    if e[0:16] == b"\x00" * 16:
        continue
    first, last = struct.unpack("<QQ", e[32:48])
    name = e[56:128].decode("utf-16-le", "ignore").rstrip("\x00")
    names[name] = (first, last)
print("partitions in region:", ", ".join(sorted(names)))
assert names.get("APP", (0,))[0] == 28672, "APP does not start at LBA 28672"
print("APP starts at LBA 28672: ok")
PY

echo "saved $(ls -lh "$OUT" | awk '{print $5}') to $OUT"
shasum -a 256 "$OUT"
echo
echo "Now swap cards, then run:"
echo "  bash $(dirname "$0")/build-sd-image-mac.sh --card /dev/disk4 --vendor-layout $OUT --write"
