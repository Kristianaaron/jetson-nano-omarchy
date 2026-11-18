#!/usr/bin/env bash
# Collect logs for a report and redact secrets. Read-only.
# Usage: bash scripts/collect-logs.sh [outdir]
set -u

OUT="${1:-$HOME/nano-inventory/logs-$(date -u +%Y%m%dT%H%M%SZ)}"
mkdir -p "$OUT"

redact() {
  sed -E \
    -e 's/([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}/aa:bb:cc:dd:ee:ff/g' \
    -e 's/\b([0-9]{1,3}\.){3}[0-9]{1,3}\b/<ipv4-redacted>/g' \
    -e 's/(ssid=)[^ ]*/\1<ssid-redacted>/g' \
    -e 's/(password|passwd|secret|token|key)=[^ ]*/\1=<redacted>/gI'
}

collect() {
  local name=$1
  shift
  {
    echo "# cmd: $*"
    "$@" 2>&1
  } | redact > "$OUT/$name.txt"
}

collect uname              uname -a
collect os-release         cat /etc/os-release
collect l4t                cat /etc/nv_tegra_release
collect cmdline            cat /proc/cmdline
collect lspci              lspci -nnk
collect lsusb              lsusb
collect lsblk              lsblk -o NAME,SIZE,FSTYPE,LABEL,PARTUUID,UUID,MOUNTPOINTS
collect extlinux           cat /boot/extlinux/extlinux.conf
collect drm                sh -c 'for c in /sys/class/drm/card*/status; do echo "$c $(cat $c)"; done'
collect modules            lsmod
collect thermal            sh -c 'for z in /sys/class/thermal/thermal_zone*; do echo "$(cat $z/type) $(cat $z/temp)"; done'
collect pkglist            sh -c 'dpkg-query -W 2>/dev/null || pacman -Q 2>/dev/null'

if command -v dmesg >/dev/null 2>&1; then
  dmesg 2>/dev/null | redact > "$OUT/dmesg.txt" || echo "dmesg not readable" > "$OUT/dmesg.txt"
fi
if command -v journalctl >/dev/null 2>&1; then
  journalctl -b --no-pager 2>/dev/null | redact > "$OUT/journal-boot.txt" || true
fi

printf 'collected into %s\n' "$OUT"
