#!/bin/bash
# Read and describe the GPT of a card without touching it.
# Usage: bash read-gpt.sh /dev/disk4
set -u
CARD=${1:-/dev/disk4}
TMP=$(mktemp /tmp/gpthead.XXXXXX)
trap 'rm -f "$TMP"' EXIT

sudo -n /bin/dd if="$CARD" of="$TMP" bs=512 count=2048 2>/dev/null || {
  echo "could not read $CARD"; exit 1; }

python3 - "$TMP" <<'PY'
import struct, sys, uuid
d = open(sys.argv[1], "rb").read()
print("MBR boot signature:", d[510:512].hex())
print("MBR partition type:", hex(d[446 + 4]))
sig = d[512:520]
print("GPT signature:", sig)
if sig != b"EFI PART":
    print("no GPT found; searching for one")
    idx = d.find(b"EFI PART")
    print("EFI PART at", idx)
    sys.exit(0)
hdr = d[512:512 + 92]
cur, back, fu, lu = struct.unpack("<QQQQ", hdr[24:56])
ent_lba = struct.unpack("<Q", hdr[72:80])[0]
num, esz = struct.unpack("<II", hdr[80:88])
print(f"current={cur} backup={back} first_usable={fu} last_usable={lu}")
print(f"entries_lba={ent_lba} count={num} entry_size={esz}")
base = ent_lba * 512
for i in range(num):
    e = d[base + i * esz: base + (i + 1) * esz]
    if e[0:16] == b"\x00" * 16:
        continue
    t = str(uuid.UUID(bytes_le=e[0:16])).upper()
    first, last = struct.unpack("<QQ", e[32:48])
    name = e[56:128].decode("utf-16-le", "ignore").rstrip("\x00")
    print(f"p{i+1}: type={t} first={first} last={last} size_mb={(last-first+1)*512/1048576:.2f} name={name!r}")
PY
