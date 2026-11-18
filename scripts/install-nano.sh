#!/usr/bin/env bash
# Install Arch Linux ARM onto a spare SD card, run from the Nano itself while it
# still boots the Qengineering Ubuntu 20.04 image (or any aarch64 Linux).
#
# The old card is only read. The new card is cloned from it first, so NVIDIA's
# bootloader (cboot + U-Boot) in the raw sectors stays byte-identical, then the
# root partition is rebuilt with Arch and pointed at Arch's own mainline kernel
# and the upstream tegra210-p3450-0000 device tree.
#
# Two L4T layouts are handled:
#   single: one ext4 APP partition holding / and /boot  (the Qengineering image)
#   split : a FAT boot partition plus a separate root partition
#
# No custom kernel: ALARM's 7.3.4 package already carries every Tegra 210 driver
# the Nano needs, including r8169 for the Realtek PCIe Ethernet. See PLAN.md.
#
# Usage: sudo SRC=/dev/mmcblk0 DST=/dev/sda \
#          ALARM_TARBALL=/home/nano/ArchLinuxARM-aarch64-latest.tar.gz ./install-nano.sh --yes
set -euo pipefail

SRC="${SRC:-/dev/mmcblk0}"
DST="${DST:-}"
ALARM_TARBALL="${ALARM_TARBALL:-}"
SRCMNT="${SRCMNT:-/mnt/nano-old}"
NEWMNT="${NEWMNT:-/mnt/nano-sd}"
ASSUME_YES=0
[[ ${1:-} == "--yes" ]] && ASSUME_YES=1

die() { printf 'error: %s\n' "$*" >&2; exit 1; }
# Initial root password (required, never printed); checked before anything is written.
[[ -n ${ROOT_PASS:-} ]] || die "set ROOT_PASS (initial root password)"
say() { printf '\n>> %s\n' "$*"; }
cleanup() { umount "$SRCMNT" 2>/dev/null; umount "$NEWMNT" 2>/dev/null; }
trap cleanup EXIT

[[ $EUID -eq 0 ]] || die "run as root"
[[ -n $DST ]] || die "set DST to the spare card, e.g. DST=/dev/sda"
[[ -f $ALARM_TARBALL ]] || die "set ALARM_TARBALL to ArchLinuxARM-aarch64-latest.tar.gz"
[[ $DST != "$SRC" ]] || die "DST must not be the running card"
[[ -b $DST ]] || die "$DST is not a block device"
[[ $(cat "/sys/class/block/$(basename "$DST")/removable" 2>/dev/null || echo 0) == 1 ]] \
  || die "$DST does not look removable; refusing to write it"

src_bytes=$(blockdev --getsize64 "$SRC")
dst_bytes=$(blockdev --getsize64 "$DST")
(( dst_bytes >= src_bytes )) || die "target card ($dst_bytes B) is smaller than source ($src_bytes B)"
(( dst_bytes > 16 * 1024 * 1024 * 1024 )) || die "target card is smaller than 16 GB"

say "plan"
printf '  source card : %s (%s)\n' "$SRC" "$(numfmt --to=iec "$src_bytes")"
printf '  target card : %s (%s), WILL BE ERASED\n' "$DST" "$(numfmt --to=iec "$dst_bytes")"
printf '  rootfs      : %s\n' "$ALARM_TARBALL"
if (( ! ASSUME_YES )); then
  read -r -p 'type CLONE to continue: ' answer
  [[ $answer == CLONE ]] || die "aborted"
fi

say "cloning bootloader, boot files and root (the slow part)"
dd if="$SRC" of="$DST" bs=4M conv=fsync status=progress
sync
partx -u "$DST" 2>/dev/null || partprobe "$DST"

mapfile -t parts < <(lsblk -no NAME,PARTN,SIZE,FSTYPE "$DST" | awk 'NF>=3 && $2 ~ /^[0-9]+$/ {print "/dev/" $1, $3, $4}')
(( ${#parts[@]} > 0 )) || die "no partitions found on $DST"
printf '  found: %s\n' "$(printf '%s | ' "${parts[@]}")"

# Find the old extlinux.conf to learn the layout.
mkdir -p "$SRCMNT"
bootpart=""
for p in "${parts[@]}"; do
  dev=${p%% *}
  mount -o ro "$dev" "$SRCMNT" 2>/dev/null || continue
  if [[ -f $SRCMNT/boot/extlinux/extlinux.conf ]]; then
    bootpart=$dev; bootsub=/boot; break
  elif [[ -f $SRCMNT/extlinux/extlinux.conf ]]; then
    bootpart=$dev; bootsub=; break
  fi
  umount "$SRCMNT"
done
[[ -n $bootpart ]] || die "could not find extlinux.conf on the cloned card; layout unknown, stopping"
old_dtb=$(grep -m1 -E '^\s*FDT' "$SRCMNT$bootsub/extlinux/extlinux.conf" | awk '{print $2}' || true)
say "old boot layout: $bootpart with extlinux under '${bootsub:-/}' (dtb: ${old_dtb:-unknown})"

# Choose the new root: the largest partition that is not the boot partition, or the
# boot partition itself when there is only one.
rootdev="" ; rootsub="/"
for p in "${parts[@]}"; do
  dev=${p%% *}
  [[ $dev == "$bootpart" ]] && continue
  if (( $(blockdev --getsize64 "$dev") > 4000000000 )); then rootdev=$dev; break; fi
done
if [[ -z $rootdev ]]; then
  rootdev=$bootpart ; rootsub=$bootsub
  say "single-partition L4T layout: rebuilding $rootdev in place"
else
  say "split layout: rebuilding $rootdev as root, keeping $bootpart"
fi
umount "$SRCMNT"

say "resizing $rootdev to fill the card"
partnum=$(cat "/sys/class/block/$(basename "$rootdev")/partition")
start=$(sgdisk -i "$partnum" "$DST" | awk '/First sector/ {print $3}')
[[ -n $start ]] || die "could not read partition $partnum geometry"
sgdisk -d "$partnum" "$DST" >/dev/null
sgdisk -n "${partnum}:${start}:0" -t "${partnum}:8300" -c "${partnum}:ROOT" "$DST" >/dev/null
sgdisk -e "$DST" >/dev/null 2>&1 || true
partx -u "$DST"
root_uuid=$(blkid -s PARTUUID -o value "$rootdev")
[[ -n $root_uuid ]] || die "could not read the new PARTUUID"

say "creating the Arch filesystem and extracting the rootfs"
mkfs.ext4 -q -L ALARM -F "$rootdev"
mkdir -p "$NEWMNT"
mount "$rootdev" "$NEWMNT"
tar -xpf "$ALARM_TARBALL" -C "$NEWMNT" --numeric-owner

say "configuring the base system"
cat > "$NEWMNT/etc/fstab" <<EOF
PARTUUID=$root_uuid / ext4 rw,relatime,commit=120 0 1
EOF
printf 'nano\n' > "$NEWMNT/etc/hostname"
ln -sf "/usr/share/zoneinfo/${TIMEZONE:-UTC}" "$NEWMNT/etc/localtime"
printf 'en_GB.UTF-8 UTF-8\n' > "$NEWMNT/etc/locale.gen"
printf 'LANG=en_GB.UTF-8\n' > "$NEWMNT/etc/locale.conf"
# Initial root password from ROOT_PASS (required, never printed); change it after first boot.
printf 'root:%s\n' "$ROOT_PASS" | chpasswd --root "$NEWMNT"
# dhcpcd is in the ALARM tarball; the NIC is the Realtek PCIe device (r8169).
systemctl --root="$NEWMNT" enable dhcpcd 2>/dev/null || say "could not enable dhcpcd offline"

save_extlinux() {
  local dir=$1
  [[ -f $dir/extlinux.conf ]] && cp "$dir/extlinux.conf" "$dir/extlinux.conf.l4t-backup"
}

say "installing Arch's kernel, initramfs and Nano device tree"
if [[ -n $rootsub && $rootdev == "$bootpart" ]]; then
  # Kernel and boot entry live inside the new root itself.
  mkdir -p "$NEWMNT/boot/extlinux"
  install -m644 "$NEWMNT/boot/Image" "$NEWMNT/boot/Image.mainline" 2>/dev/null || true
  install -m644 "$NEWMNT/boot/initramfs-linux.img" "$NEWMNT/boot/initramfs-linux.img" 2>/dev/null || true
  install -m644 "$NEWMNT/boot/dtbs/nvidia/tegra210-p3450-0000.dtb" "$NEWMNT/boot/tegra210-p3450-0000.dtb"
  save_extlinux "$NEWMNT/boot/extlinux"
  cat > "$NEWMNT/boot/extlinux/extlinux.conf" <<EOF
DEFAULT arch-nano
MENU TITLE Jetson Nano boot
TIMEOUT 30

LABEL arch-nano
      MENU LABEL Arch Linux ARM (mainline 7.3.4)
      LINUX /boot/Image
      INITRD /boot/initramfs-linux.img
      FDT /boot/tegra210-p3450-0000.dtb
      APPEND root=PARTUUID=$root_uuid rw rootwait console=tty0 console=ttyTCU0,115200n8 loglevel=7
EOF
else
  say "writing the boot partition $bootpart"
  mount "$bootpart" "$SRCMNT"
  cp "$SRCMNT"/Image "$NEWMNT/boot/Image" 2>/dev/null || true
  install -m644 "$NEWMNT/boot/Image" "$SRCMNT/Image"
  install -m644 "$NEWMNT/boot/initramfs-linux.img" "$SRCMNT/initramfs-linux.img"
  install -m644 "$NEWMNT/boot/dtbs/nvidia/tegra210-p3450-0000.dtb" "$SRCMNT/tegra210-p3450-0000.dtb"
  save_extlinux "$SRCMNT/extlinux"
  cat > "$SRCMNT/extlinux/extlinux.conf" <<EOF
DEFAULT arch-nano
MENU TITLE Jetson Nano boot
TIMEOUT 30

LABEL arch-nano
      MENU LABEL Arch Linux ARM (mainline 7.3.4)
      LINUX /Image
      INITRD /initramfs-linux.img
      FDT /tegra210-p3450-0000.dtb
      APPEND root=PARTUUID=$root_uuid rw rootwait console=tty0 console=ttyTCU0,115200n8 loglevel=7
EOF
  sync
  umount "$SRCMNT"
fi

sync
umount "$NEWMNT"

say "done"
cat <<EOF
New card is ready: $DST

First boot, with HDMI and a keyboard on the Nano:
  1. log in as root / omarchy
  2. pacman-key --init && pacman-key --populate archlinuxarm
  3. pacman -Syu openssh && systemctl enable --now sshd
  4. passwd

The old extlinux.conf is kept beside the new one as extlinux.conf.l4t-backup.
EOF
