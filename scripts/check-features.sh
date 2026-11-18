#!/bin/bash
# Print the ext4 feature flags of the card's largest partition.
set -u
DUMP=/opt/homebrew/opt/e2fsprogs/sbin/dumpe2fs
CARD=${1:-/dev/disk4}
part=$(diskutil list "$CARD" | awk '/^ +[0-9]+:/ && $NF ~ /s[0-9]+$/ {print $NF}' | while read -r id; do
  size=$(diskutil info "/dev/$id" 2>/dev/null | awk -F'[()]' '/Disk Size/{print $2}' | awk '{print $1}')
  [[ -n ${size:-} ]] && echo "$size $id"
done | sort -rn | head -1 | awk '{print $2}')
[[ -n ${part:-} ]] || { echo "no partition"; exit 1; }
sudo -n "$DUMP" -h "/dev/$part" 2>/dev/null | grep -Ei "filesystem features|block size|inode size|filesystem state|volume name"
features=$(sudo -n "$DUMP" -h "/dev/$part" 2>/dev/null | awk -F: '/Filesystem features/{print $2}')
echo
case "$features" in
  *metadata_csum*|*64bit*) echo "VERDICT: modern features present; this bootloader cannot read it" ;;
  *) echo "VERDICT: legacy-compatible feature set" ;;
esac
