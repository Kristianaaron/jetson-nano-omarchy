#!/usr/bin/env bash
# Read-only inventory of a Jetson Nano 4GB (P3450). Nothing here writes to the
# system, the boot partition or the SD card. Secrets are redacted before output.
#
# Usage: bash hardware/inventory.sh [outdir]
# Default outdir: $HOME/nano-inventory
set -u

OUT="${1:-$HOME/nano-inventory}"
mkdir -p "$OUT"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
REPORT="$OUT/baseline-$STAMP.txt"

have() { command -v "$1" >/dev/null 2>&1; }
section() { printf '\n===== %s =====\n' "$1"; }
rd() { tr -d '\0' 2>/dev/null || true; }

# Redaction: MAC addresses, IP addresses, SSIDs. Hostnames are replaced by a
# fixed string. Run before anything leaves the device.
redact() {
  sed -E \
    -e 's/([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}/aa:bb:cc:dd:ee:ff/g' \
    -e 's/\b([0-9]{1,3}\.){3}[0-9]{1,3}\b/<ipv4-redacted>/g' \
    -e 's/(ssid=)[^ ]*/\1<ssid-redacted>/g' \
    -e "s/$(hostname -s 2>/dev/null || echo __none__)/<hostname-redacted>/g"
}

{
  section "identity"
  printf 'utc: %s\n' "$(date -u -Is)"
  printf 'model: %s\n' "$(rd < /proc/device-tree/model 2>/dev/null || echo unknown)"
  printf 'compatible: %s\n' "$(tr '\0' ' ' < /proc/device-tree/compatible 2>/dev/null || echo unknown)"

  section "os"
  cat /etc/os-release 2>/dev/null
  printf 'uname: %s\n' "$(uname -srm)"
  printf 'l4t: %s\n' "$(cat /etc/nv_tegra_release 2>/dev/null || echo 'not present')"

  section "nvidia packages"
  dpkg-query -W 'nvidia-l4t-*' 2>/dev/null || echo 'dpkg not available'

  section "kernel"
  printf 'release: %s\n' "$(uname -r)"
  printf 'cmdline: %s\n' "$(cat /proc/cmdline)"
  printf 'loaded modules (tegra/gpu/net):\n'
  lsmod 2>/dev/null | grep -Ei 'tegra|nvgpu|nvhost|nouveau|r8169|host1x' || true

  section "memory"
  free -h 2>/dev/null
  grep -E 'MemTotal|MemAvailable|SwapTotal' /proc/meminfo 2>/dev/null
  cat /proc/swaps 2>/dev/null
  ls /sys/block 2>/dev/null | grep -i zram || true

  section "cpu"
  nproc
  for f in scaling_governor scaling_cur_freq cpuinfo_max_freq; do
    printf '%s: %s\n' "$f" "$(cat "/sys/devices/system/cpu/cpu0/cpufreq/$f" 2>/dev/null || echo n/a)"
  done

  section "storage"
  lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,PARTUUID,UUID,MOUNTPOINTS 2>/dev/null || lsblk
  findmnt / 2>/dev/null
  df -hT 2>/dev/null | grep -Ev 'tmpfs|devtmpfs'

  section "boot"
  printf 'extlinux present: %s\n' "$(test -f /boot/extlinux/extlinux.conf && echo yes || echo no)"
  cat /boot/extlinux/extlinux.conf 2>/dev/null
  ls -la /boot 2>/dev/null | head -20
  find /boot -maxdepth 3 -name '*.dtb' 2>/dev/null | head -20

  section "gpu and display"
  ls -l /dev/dri /dev/nvhost* 2>/dev/null || echo 'no drm/nvhost nodes'
  for c in /sys/class/drm/card*/status; do
    [ -e "$c" ] || continue
    printf '%s: %s\n' "$c" "$(cat "$c")"
  done
  have nvpmodel && nvpmodel -q 2>/dev/null

  section "thermal"
  for z in /sys/class/thermal/thermal_zone*; do
    [ -e "$z/temp" ] || continue
    printf '%s %s: %s\n' "$(basename "$z")" "$(cat "$z/type" 2>/dev/null)" "$(cat "$z/temp")"
  done

  section "network"
  ip -brief address 2>/dev/null
  ip route 2>/dev/null | head -5

  section "usb"
  lsusb 2>/dev/null || true

  section "cuda"
  have nvcc && nvcc --version
  have nvidia-smi && nvidia-smi 2>/dev/null | head -15 || true
} 2>&1 | redact | tee "$REPORT"

if have tegrastats; then
  timeout 6s tegrastats --interval 1000 > "$OUT/tegrastats-$STAMP.txt" 2>&1 || true
fi

printf '\nreport: %s\n' "$REPORT"
