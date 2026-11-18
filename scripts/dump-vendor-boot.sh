#!/bin/bash
# Dump the vendor kernel, initrd and device tree from a Jetson Nano card,
# read-only, so they can be booted from an experimental card as a control.
#
# Usage: bash dump-vendor-boot.sh --card /dev/disk4 [--out vendor-boot]
set -euo pipefail

DBG="${DBG:-/opt/homebrew/opt/e2fsprogs/sbin/debugfs}"
CARD=""
OUT="vendor-boot"

while (($#)); do
  case "$1" in
    --card) CARD=${2:-}; shift 2 ;;
    --out) OUT=${2:-}; shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 1 ;;
  esac
done
[[ -n $CARD ]] || { echo "usage: --card /dev/diskN" >&2; exit 1; }
[[ -b $CARD ]] || { echo "$CARD is not a block device" >&2; exit 1; }

sudo -n /usr/sbin/diskutil info "$CARD" >/dev/null 2>&1 || { echo "sudo -n failed" >&2; exit 1; }

part=$(diskutil list "$CARD" | awk '/^ +[0-9]+:/ && $NF ~ /s[0-9]+$/ {print $NF}' | while read -r id; do
  size=$(diskutil info "/dev/$id" 2>/dev/null | awk -F'[()]' '/Disk Size/{print $2}' | awk '{print $1}')
  [[ -n ${size:-} ]] && echo "$size $id"
done | sort -rn | head -1 | awk '{print $2}')
[[ -n ${part:-} ]] || { echo "no partition" >&2; exit 1; }
partdev="/dev/$part"

mkdir -p "$OUT"

echo "== /boot on $partdev =="
sudo -n "$DBG" -R "ls -l /boot" "$partdev" 2>/dev/null | awk 'NF>4 {printf "  %s %s\n", $2, $NF}'
echo "== /boot/dtb =="
sudo -n "$DBG" -R "ls -l /boot/dtb" "$partdev" 2>/dev/null | awk 'NF>4 {printf "  %s %s\n", $2, $NF}' | head -20

extract() {
  local src=$1 dst=$2
  if sudo -n "$DBG" -R "dump $src $dst" "$partdev" >/dev/null 2>&1 && [[ -s $dst ]]; then
    printf '  saved %-45s %s bytes\n' "$dst" "$(wc -c < "$dst" | tr -d ' ')"
  else
    printf '  MISSING %s\n' "$src"
  fi
}

echo "== extracting =="
extract /boot/Image "$OUT/vendor-Image"
extract /boot/initrd "$OUT/vendor-initrd.img"

dtb=$(sudo -n "$DBG" -R "ls -l /boot/dtb" "$partdev" 2>/dev/null | awk '/\.dtb$/ {print $NF}' | head -1)
if [[ -n ${dtb:-} ]]; then
  extract "/boot/dtb/$dtb" "$OUT/vendor.dtb"
else
  echo "  no DTB under /boot/dtb"
fi

echo
echo "Now rebuild with VENDOR_FILES=$PWD/$OUT to add a vendor-control boot entry."
