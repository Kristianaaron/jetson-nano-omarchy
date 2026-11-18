#!/bin/bash
# Print the diagnostic file the initramfs writes, and the extlinux entry in use.
set -u
DBG=/opt/homebrew/opt/e2fsprogs/sbin/debugfs
CARD=${1:-/dev/disk4}
part=$(diskutil list "$CARD" | awk '/^ +[0-9]+:/ && $NF ~ /s[0-9]+$/ {print $NF}' | while read -r id; do
  size=$(diskutil info "/dev/$id" 2>/dev/null | awk -F'[()]' '/Disk Size/{print $2}' | awk '{print $1}')
  [[ -n ${size:-} ]] && echo "$size $id"
done | sort -rn | head -1 | awk '{print $2}')
[[ -n ${part:-} ]] || { echo "no partition"; exit 1; }
partdev="/dev/$part"
echo "partition: $partdev"
echo "== root listing (top level) =="
sudo -n "$DBG" -R "ls -l /" "$partdev" 2>/dev/null | awk 'NF>4 {printf "  %s %s\n", $2, $NF}' | head -25
echo
echo "== /nano-diag.txt =="
out=$(sudo -n "$DBG" -R "cat /nano-diag.txt" "$partdev" 2>/dev/null || true)
if [[ -n ${out// /} ]]; then
  printf '%s\n' "$out"
else
  echo "absent: the diagnostic initramfs did not run, or could not write"
fi
