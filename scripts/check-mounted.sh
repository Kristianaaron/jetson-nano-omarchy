#!/bin/bash
# Read-only: did anything mount this ext4 filesystem, and are there any writes?
set -u
DUMP=/opt/homebrew/opt/e2fsprogs/sbin/dumpe2fs
DBG=/opt/homebrew/opt/e2fsprogs/sbin/debugfs
CARD=${1:-/dev/disk4}

part=$(diskutil list "$CARD" | awk '/^ +[0-9]+:/ && $NF ~ /s[0-9]+$/ {print $NF}' | while read -r id; do
  size=$(diskutil info "/dev/$id" 2>/dev/null | awk -F'[()]' '/Disk Size/{print $2}' | awk '{print $1}')
  [[ -n ${size:-} ]] && echo "$size $id"
done | sort -rn | head -1 | awk '{print $2}')
[[ -n ${part:-} ]] || { echo "no partition"; exit 1; }
partdev="/dev/$part"
echo "partition: $partdev"
echo
echo "== superblock state =="
sudo -n "$DUMP" -h "$partdev" 2>/dev/null | grep -Ei "filesystem state|last mounted|mount count|last write|last check|volume name"
echo
echo "== /var/log =="
sudo -n "$DBG" -R "ls -l /var/log" "$partdev" 2>/dev/null | awk 'NF>4 {printf "  %s %s\n", $2, $NF}'
echo
echo "== /var/lib/systemd =="
sudo -n "$DBG" -R "ls -l /var/lib" "$partdev" 2>/dev/null | awk 'NF>4 {printf "  %s %s\n", $2, $NF}' | head -12
echo
echo "== /etc/machine-id =="
sudo -n "$DBG" -R "stat /etc/machine-id" "$partdev" 2>/dev/null | sed 's/^/  /'
