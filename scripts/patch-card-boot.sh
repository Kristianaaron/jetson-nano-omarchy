#!/bin/bash
# Put files into an experimental card's root filesystem in place, then read each
# back and compare. Refuses the L4T working card.
#
# Usage: bash patch-card-boot.sh --card /dev/disk4 [--initrd FILE] [--extlinux FILE]
#                                [--put LOCAL:/card/path ...]
set -euo pipefail

SUDO="sudo -n"
DBG="${DBG:-/opt/homebrew/opt/e2fsprogs/sbin/debugfs}"
CARD=""
PUTS=()
while (($#)); do
  case "$1" in
    --card) CARD=${2:-}; shift 2 ;;
    --initrd) PUTS+=("${2:-}:/boot/initrd"); shift 2 ;;
    --extlinux) PUTS+=("${2:-}:/boot/extlinux/extlinux.conf"); shift 2 ;;
    --put) PUTS+=("${2:-}"); shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 1 ;;
  esac
done
die() { echo "error: $*" >&2; exit 1; }
[[ -b $CARD ]] || die "--card /dev/diskN is required"
(( ${#PUTS[@]} )) || die "nothing to patch"
for p in "${PUTS[@]}"; do [[ -f ${p%%:*} && ${p#*:} == /* ]] || die "bad --put $p"; done
part="/dev/$(basename "$CARD")s1"
label=$($SUDO /opt/homebrew/opt/e2fsprogs/sbin/dumpe2fs -h "$part" 2>/dev/null | awk -F': *' '/volume name/{print $2}')
[[ $label == ALARM ]] || die "$part is labelled '$label', not ALARM"
if $SUDO "$DBG" -R "stat /etc/nv_tegra_release" "$part" 2>/dev/null | grep -q '^Inode:'; then
  die "$part holds an L4T system; refusing to write the working card"
fi

cmds=$(mktemp /tmp/nano-patch.XXXXXX)
trap 'rm -f "$cmds"' EXIT
add() { # local-file card-dir name
  printf 'cd %s\nrm %s\nwrite %s %s\nsif %s uid 0\nsif %s gid 0\nsif %s mode 0100644\n' \
    "$2" "$3" "$1" "$3" "$3" "$3" "$3" >> "$cmds"
}
for p in "${PUTS[@]}"; do dst=${p#*:}; add "${p%%:*}" "$(dirname "$dst")" "$(basename "$dst")"; done
$SUDO "$DBG" -w -f "$cmds" "$part" >/dev/null 2>&1 || die "debugfs write failed"

check() { # local-file card-path
  want=$(shasum -a 256 < "$1" | cut -d' ' -f1)
  got=$($SUDO "$DBG" -R "cat $2" "$part" 2>/dev/null | shasum -a 256 | cut -d' ' -f1)
  [[ $want == "$got" ]] || die "$2 read back differs from $1"
  echo "ok $2 $want"
}
for p in "${PUTS[@]}"; do check "${p%%:*}" "${p#*:}"; done
