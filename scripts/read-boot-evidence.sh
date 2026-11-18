#!/bin/bash
# Read boot evidence off the experimental card after a boot attempt, with no
# serial console and no working network. Read-only.
#
# Usage: bash read-boot-evidence.sh --card /dev/disk4
set -euo pipefail

SUDO="sudo -n"
DBG="${DBG:-/opt/homebrew/opt/e2fsprogs/sbin/debugfs}"
CARD=""

while (($#)); do
  case "$1" in
    --card) CARD=${2:-}; shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 1 ;;
  esac
done

[[ -n $CARD ]] || { echo "usage: --card /dev/diskN" >&2; exit 1; }
[[ -b $CARD ]] || { echo "$CARD is not a block device" >&2; exit 1; }

$SUDO /usr/sbin/diskutil info "$CARD" >/dev/null 2>&1 || { echo "sudo -n failed for diskutil" >&2; exit 1; }

part=$($SUDO /usr/sbin/diskutil list "$CARD" | awk '/^ +[0-9]+:/ && $NF ~ /s[0-9]+$/ {print $NF}' | while read -r id; do
  size=$($SUDO /usr/sbin/diskutil info "/dev/$id" 2>/dev/null | awk -F'[()]' '/Disk Size/{print $2}' | awk '{print $1}')
  [[ -n ${size:-} ]] && echo "$size $id"
done | sort -rn | head -1 | awk '{print $2}')
[[ -n ${part:-} ]] || { echo "no data partition on $CARD" >&2; exit 1; }
partdev="/dev/$part"

cat_of() {
  $SUDO "$DBG" -R "cat $1" "$partdev" 2>/dev/null || true
}

echo "== card =="
echo "  $partdev"
echo
echo "== /boot =="
$SUDO "$DBG" -R "ls -l /boot" "$partdev" 2>/dev/null | awk 'NF>4 {printf "  %s %s\n", $2, $NF}'
echo
echo "== boot stamp =="
stamp=$(cat_of /boot/boot-stamp)
if [[ -n ${stamp// /} ]]; then
  echo "  REACHED USERSPACE: $stamp"
else
  echo "  absent: the kernel never reached the boot-stamp service"
fi
echo
echo "== machine-id =="
mid=$(cat_of /etc/machine-id)
if [[ -n ${mid// /} ]]; then echo "  written: $mid"; else echo "  empty: systemd did not complete first boot"; fi
echo
echo "== journal =="
$SUDO "$DBG" -R "ls -l /var/log/journal" "$partdev" 2>/dev/null | awk 'NF>4 {printf "  %s %s\n", $2, $NF}' || echo "  no journal directory"
echo
echo "== fstab =="
cat_of /etc/fstab | sed 's/^/  /'
echo
echo "Interpretation:"
echo "  stamp present            -> kernel and systemd ran; the failure is display or network"
echo "  machine-id non-empty     -> systemd started at least once"
echo "  all empty                -> the kernel died before userspace; serial or netconsole next"
