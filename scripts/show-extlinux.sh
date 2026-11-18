#!/bin/bash
# Print the extlinux.conf on the card (read-only).
set -u
DBG=/opt/homebrew/opt/e2fsprogs/sbin/debugfs
CARD=${1:-/dev/disk4}
part=$(diskutil list "$CARD" | awk '/^ +[0-9]+:/ && $NF ~ /s[0-9]+$/ {print $NF}' | while read -r id; do
  size=$(diskutil info "/dev/$id" 2>/dev/null | awk -F'[()]' '/Disk Size/{print $2}' | awk '{print $1}')
  [[ -n ${size:-} ]] && echo "$size $id"
done | sort -rn | head -1 | awk '{print $2}')
[[ -n ${part:-} ]] || { echo "no partition"; exit 1; }
sudo -n "$DBG" -R "cat /boot/extlinux/extlinux.conf" "/dev/$part" 2>/dev/null
