#!/bin/bash
# Build a small first-stage initramfs for the Jetson Nano on mainline.
#
# Arch Linux ARM's shipped initramfs is unusable on this board: it was built
# with autodetect on Arch's build host, so it carries no i2c-tegra. The SD
# card's I/O rail comes from the MAX77620 PMIC behind Tegra I2C, so without
# that module the root card never appears. It is also 14.7 MiB, which overruns
# the 14 MiB gap L4T U-Boot is believed to leave between ramdisk_addr_r and
# kernel_addr_r. This image is about 2 MiB.
#
# Each outcome is visible without a serial console:
#   board reboots every ~20 s       -> kernel panic (cmdline carries panic=10)
#   answers ping, never reboots     -> init ran, SD never appeared
#   kernel log on LOG_HOST:6666/udp -> init ran (needs Ethernet and LOG_HOST)
#   Arch boots, /nano-diag.txt set  -> handed off to systemd
#
# Usage: bash make-diag-initramfs.sh [output.img]
set -euo pipefail

TARBALL="${TARBALL:-$HOME/.cache/archlinuxarm/ArchLinuxARM-aarch64-latest.tar.gz}"
OUT="${1:-$PWD/diag-initramfs.img}"
WORK=$(mktemp -d /tmp/nano-diag.XXXXXX)
trap 'rm -rf "$WORK"' EXIT

[[ -f $TARBALL ]] || { echo "missing $TARBALL" >&2; exit 1; }

kver=$(tar -tzf "$TARBALL" | sed -n 's#^\./usr/lib/modules/\([^/]*\)/kernel/$#\1#p' | head -1)
[[ -n $kver ]] || { echo "no kernel module tree in $TARBALL" >&2; exit 1; }
moddir="./usr/lib/modules/$kver/kernel"
MODULES=(
  drivers/i2c/busses/i2c-tegra.ko
  drivers/net/ethernet/realtek/r8169.ko
  drivers/net/netconsole.ko
)
FIRMWARE=(rtl_nic/rtl8168h-1.fw rtl_nic/rtl8168h-2.fw)
# The Mac that listens for the kernel log over UDP (netconsole, port 6666).
# LOG_MAC is the listener's own MAC; Wi-Fi routers may not pass broadcast frames.
LOG_HOST="${LOG_HOST:-}"
LOG_MAC="${LOG_MAC:-}"
# The Nano's own address for netconsole (required with LOG_HOST).
NANO_IP="${NANO_IP:-}"
if [ -n "$LOG_HOST" ] && [ -z "$NANO_IP" ]; then echo "error: LOG_HOST needs NANO_IP" >&2; exit 1; fi
# Arch's busybox has no mount, umount, insmod, switch_root or tr; Arch ships
# those from util-linux and kmod. Every command /init runs must be in INIT_CMDS.
BINS=(busybox kmod switch_root mount umount)
INIT_CMDS=(sh mount umount mknod ls wc uname dmesg sleep cat ip sync grep reboot switch_root insmod)
OBJDUMP="${OBJDUMP:-/usr/bin/objdump}"

echo ">> extracting ${BINS[*]}, libraries and ${#MODULES[@]} modules for $kver"
mkdir -p "$WORK/src"
tar -xzf "$TARBALL" -C "$WORK/src" ./boot/initramfs-linux.img "${MODULES[@]/#/$moddir/}" \
  "${FIRMWARE[@]/#/./usr/lib/firmware/}"
python3 -I "$(dirname "$0")/unpack-initramfs.py" "$WORK/src/boot/initramfs-linux.img" "$WORK/main.cpio" >/dev/null
mkdir -p "$WORK/arch"
bsdtar -xf "$WORK/main.cpio" -C "$WORK/arch"

R="$WORK/root"
mkdir -p "$R"/{usr/bin,usr/lib/modules,dev,proc,sys,run,new_root}
ln -s usr/bin "$R/bin"
ln -s usr/bin "$R/sbin"
ln -s usr/lib "$R/lib"
for b in "${BINS[@]}"; do cp -L "$WORK/arch/usr/bin/$b" "$R/usr/bin/$b"; done
ln -s kmod "$R/usr/bin/insmod"
# Same applet links as Arch's initramfs; busybox --install needs /proc at boot.
for l in "$WORK/arch/usr/bin"/*; do
  [[ -L $l && $(readlink "$l") == busybox && ! -e $R/usr/bin/${l##*/} ]] && ln -s busybox "$R/usr/bin/${l##*/}"
done
needed() { "$OBJDUMP" -p "$1" | awk '/NEEDED/{print $2}'; }
queue=$(for b in "${BINS[@]}"; do needed "$R/usr/bin/$b"; done)
while [[ -n $queue ]]; do
  next=""
  for l in $queue; do
    [[ -f $R/usr/lib/$l ]] && continue
    [[ -e $WORK/arch/usr/lib/$l ]] || { echo "library $l is not in Arch's initramfs" >&2; exit 1; }
    cp -L "$WORK/arch/usr/lib/$l" "$R/usr/lib/$l"
    next+=" $(needed "$R/usr/lib/$l")"
  done
  queue=$next
done
for m in "${MODULES[@]}"; do cp "$WORK/src/$moddir/$m" "$R/usr/lib/modules/"; done
for f in "${FIRMWARE[@]}"; do
  mkdir -p "$R/usr/lib/firmware/$(dirname "$f")"
  cp "$WORK/src/usr/lib/firmware/$f" "$R/usr/lib/firmware/$f"
done
mkdir -p "$R/etc"
printf 'LOG_HOST=%s\nLOG_MAC=%s\nNANO_IP=%s\n' "$LOG_HOST" "$LOG_MAC" "$NANO_IP" > "$R/etc/nano-log.conf"

cat > "$R/init" <<'INIT'
#!/usr/bin/busybox sh
# Never exit: PID 1 exiting is a kernel panic, which would hide where we got to.
export PATH=/usr/bin
mount -t proc proc /proc
mount -t sysfs sysfs /sys
# On 2026-11-17 /dev came up empty under 7.1.6 (no init messages in the log, no
# /dev/mmcblk1p1 although the card was detected), so never depend on devtmpfs.
mount -t devtmpfs devtmpfs /dev 2>/dev/null; devtmpfs_rc=$?
[ -c /dev/kmsg ] || mknod /dev/kmsg c 1 11
[ -c /dev/console ] || mknod /dev/console c 5 1
[ -c /dev/null ] || mknod /dev/null c 1 3
[ -c /dev/console ] && exec </dev/console >/dev/console 2>&1
log() { echo "nano-init: $*" > /dev/kmsg; }
blocknodes() {
  for s in /sys/class/block/*; do
    n=/dev/${s##*/}
    [ -b "$n" ] || [ ! -e "$s/dev" ] || { d=$(cat "$s/dev"); mknod "$n" b "${d%:*}" "${d#*:}"; }
  done
}
forever() { log "$*"; while true; do sleep 3600; done; }
. /etc/nano-log.conf

log "started, kernel $(uname -r), devtmpfs mount rc=$devtmpfs_rc, /dev has $(ls /dev | wc -l) entries"
echo on > /proc/sys/kernel/printk_devkmsg
dmesg -n 8
# Network first so the log leaves the board before anything risky runs. Display
# drivers are left to the real system, where tegra-drm loads cleanly. The ~20 s
# panic loop of 2026-11-17 was an unguarded console redirect before /dev existed.
for m in i2c-tegra r8169; do
  insmod "/usr/lib/modules/$m.ko" && log "loaded $m" || log "FAILED to load $m"
done

if [ -n "$LOG_HOST" ]; then
  i=0
  while [ $i -lt 15 ] && [ ! -e /sys/class/net/eth0 ]; do sleep 1; i=$((i + 1)); done
  ip link set eth0 up
  ip addr add "$NANO_IP/24" dev eth0
  i=0
  while [ $i -lt 15 ] && [ "$(cat /sys/class/net/eth0/carrier 2>/dev/null)" != 1 ]; do sleep 1; i=$((i + 1)); done
  if insmod /usr/lib/modules/netconsole.ko "netconsole=6665@$NANO_IP/eth0,6666@$LOG_HOST/$LOG_MAC"; then
    log "netconsole to $LOG_HOST up, replaying the boot log"
    dmesg > /run/boot.log
    while IFS= read -r line; do echo "replay: $line" > /dev/kmsg; done < /run/boot.log
  else
    log "netconsole FAILED"
  fi
fi

root=""
i=0
while [ $i -lt 30 ] && [ -z "$root" ]; do
  blocknodes
  for dev in /dev/mmcblk*p1; do
    [ -b "$dev" ] || continue
    mount -t ext4 -o rw "$dev" /new_root 2>/dev/null || { log "mount $dev failed"; continue; }
    if [ -f /new_root/etc/os-release ] || [ -L /new_root/etc/os-release ]; then root=$dev; break; fi
    umount /new_root
  done
  [ -z "$root" ] && sleep 1
  i=$((i + 1))
done

if [ -z "$root" ]; then
  log "no root card after 30 s; block devices:"
  cat /proc/partitions > /dev/kmsg
  forever "init ran but the SD card never appeared"
fi

log "root is $root"
{
  echo "=== nano diagnostics ==="
  echo "uptime: $(cat /proc/uptime)"
  echo "root: $root"
  echo "cmdline: $(cat /proc/cmdline)"
  echo "model: $(cat /proc/device-tree/model)"
  echo "compatible: $(cat /proc/device-tree/compatible)"
  grep MemTotal /proc/meminfo
  echo; echo "=== block devices ==="; cat /proc/partitions
  echo; echo "=== drm ==="; ls -l /dev/dri 2>&1; ls /sys/class/drm 2>&1
  echo; echo "=== dmesg ==="; dmesg
} > /new_root/nano-diag.txt 2>&1
sync

mount --move /dev /new_root/dev
mount --move /proc /new_root/proc
mount --move /sys /new_root/sys
[ -x /new_root/usr/lib/systemd/systemd ] && exec switch_root /new_root /usr/lib/systemd/systemd
forever "switch_root not possible"
INIT
chmod 755 "$R/init"
for c in "${INIT_CMDS[@]}"; do
  [[ -e $R/usr/bin/$c ]] || { echo "init needs '$c' but the image has no /usr/bin/$c" >&2; exit 1; }
done

echo ">> packing"
( cd "$R" && bsdtar -cf - --format=newc --uid 0 --gid 0 . ) | gzip -9 > "$OUT"
size=$(wc -c < "$OUT" | tr -d ' ')
(( size < 12 * 1024 * 1024 )) || { echo "initramfs is $size bytes; keep it under 12 MiB" >&2; exit 1; }
echo ">> done: $OUT ($size bytes)"
