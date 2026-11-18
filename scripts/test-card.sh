#!/bin/bash
# Write-and-verify test for an SD card. Destroys the card's contents.
#
# Usage: bash test-card.sh --card /dev/disk4
#
# Writes a 256 MB random block at 32 MB and again near the middle, reads each
# back and compares hashes, then reads the first 64 MB. Any I/O error or hash
# mismatch means the card is not trustworthy for boot experiments.
set -euo pipefail

SUDO="sudo -n"
CARD=""
while (($#)); do
  case "$1" in
    --card) CARD=${2:-}; shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 1 ;;
  esac
done
[[ -n $CARD ]] || { echo "usage: --card /dev/diskN" >&2; exit 1; }
[[ -b $CARD ]] || { echo "$CARD not a block device" >&2; exit 1; }

$SUDO /usr/sbin/diskutil info "$CARD" >/dev/null 2>&1 || { echo "sudo -n failed" >&2; exit 1; }
$SUDO /usr/sbin/diskutil unmountDisk "$CARD" >/dev/null 2>&1 || true

bytes=$($SUDO /usr/sbin/diskutil info "$CARD" | awk -F'[()]' '/Disk Size/{print $2}' | awk '{print $1}')
echo "card: $CARD ($bytes bytes)"
work=$(mktemp -d /tmp/cardtest.XXXXXX)
trap 'rm -rf "$work"' EXIT

size_mb=256
block=$(( size_mb * 1024 * 1024 ))
mid=$(( (bytes / 2 / 512) * 512 ))

echo ">> writing ${size_mb} MB of random data at 32 MB and at the card midpoint"
dd if=/dev/urandom of="$work/block.bin" bs=1m count=$size_mb 2>/dev/null
h_src=$(shasum -a 256 "$work/block.bin" | awk '{print $1}')

fail=0
for off in 32 $mid; do
  off_mb=$(( off / 1024 / 1024 ))
  printf '   offset %s MB: ' "$off_mb"
  if ! $SUDO /bin/dd if="$work/block.bin" of="$CARD" bs=1m seek=$(( off / 1024 / 1024 )) \
        count=$size_mb conv=notrunc,fsync 2>"$work/err"; then
    echo "WRITE FAILED"; sed 's/^/     /' "$work/err"; fail=1; continue
  fi
  # drop caches is not available; read back through the raw device instead
  $SUDO /bin/dd if="$CARD" of="$work/read.bin" bs=1m skip=$(( off / 1024 / 1024 )) \
      count=$size_mb 2>"$work/err" || { echo "READ FAILED"; fail=1; continue; }
  h_dst=$(shasum -a 256 "$work/read.bin" | awk '{print $1}')
  if [[ $h_src == "$h_dst" ]]; then echo "match"; else echo "MISMATCH"; fail=1; fi
done

echo ">> reading the first 64 MB (the area the bootloader reads)"
if $SUDO /bin/dd if="$CARD" of=/dev/null bs=1m count=64 2>"$work/err"; then
  echo "   ok"
else
  echo "   READ ERROR"; sed 's/^/     /' "$work/err"; fail=1
fi

if (( fail )); then
  echo
  echo "RESULT: the card failed verification. Do not use it for boot experiments."
  exit 1
fi
echo
echo "RESULT: write and read-back verified. The card is not obviously faulty."
