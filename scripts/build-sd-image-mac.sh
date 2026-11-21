#!/bin/bash
# Build an Arch Linux ARM SD card for the Jetson Nano (Tegra210, B01) on macOS.
#
# Runs as a normal user. Only the steps that genuinely need privilege (raw device
# writes, mke2fs, diskutil, debugfs, chown) are escalated, each explicitly, via
# `sudo -n`, so it never prompts once /etc/sudoers.d/jetson-builder is in place.
#
# Design:
# - Bootloader lives in QSPI, so the card needs no cboot/U-Boot, only an ext4
#   root with /boot and extlinux.conf.
# - The card is wiped to a single partition so stale vendor kernel partitions
#   cannot be booted ahead of extlinux.
# - ext4 uses the pre-2016 feature set the board's bootloader understands.
# - Rootfs is staged on a case-sensitive HFS+ image (APFS is case-insensitive and
#   would merge P/ and p/ terminfo entries).
#
# Usage (no sudo prefix):
#   bash build-sd-image-mac.sh --card /dev/disk4 --write
set -euo pipefail

SUDO="sudo -n"
BOOT_FAT=0
DIAG=0
VENDOR_LAYOUT=""
VENDOR_FILES="${VENDOR_FILES:-}"
CARD=""
WRITE=0
# Initial password for root and USER_NAME: required, never printed. Change it after first boot.
ROOT_PASS="${ROOT_PASS:-}"
USER_NAME="${USER_NAME:-omarchy}"
HOSTNAME_NEW="${HOSTNAME_NEW:-nano-arch}"
TARBALL="${TARBALL:-$HOME/.cache/archlinuxarm/ArchLinuxARM-aarch64-latest.tar.gz}"
STAGE_IMG="${STAGE_IMG:-/tmp/archstage-$$.sparseimage}"
STAGE_SIZE="${STAGE_SIZE:-12g}"
E2FS="${E2FS:-/opt/homebrew/opt/e2fsprogs/sbin/mke2fs}"
DBG="${DBG:-/opt/homebrew/opt/e2fsprogs/sbin/debugfs}"
DUMPE2FS="${DUMPE2FS:-/opt/homebrew/opt/e2fsprogs/sbin/dumpe2fs}"

die() { echo "error: $*" >&2; exit 1; }
say() { printf '\n>> %s\n' "$*"; }

while (($#)); do
  case "$1" in
    --card) CARD=${2:-}; shift 2 ;;
    --write) WRITE=1; shift ;;
    --boot-fat) BOOT_FAT=1; shift ;;
    --diag) DIAG=1; shift ;;
    --vendor-layout) VENDOR_LAYOUT=${2:-}; shift 2 ;;
    --vendor-files) VENDOR_FILES=${2:-}; shift 2 ;;
    *) die "unknown argument: $1" ;;
  esac
done

[[ $(uname -s) == Darwin ]] || die "this script is for macOS"
[[ -n $CARD ]] || die "--card /dev/diskN is required"
[[ -x $E2FS ]] || die "missing $E2FS, run: brew install e2fsprogs"
[[ -b $CARD ]] || die "$CARD is not a block device"
[[ $CARD != /dev/disk0 ]] || die "refusing internal disk0"
# Probe with a command the sudoers rule actually permits; `true` is not listed.
$SUDO /usr/sbin/diskutil info "$CARD" >/dev/null 2>&1 \
  || die "sudo -n failed for diskutil; check /etc/sudoers.d/jetson-builder"

card_bytes=$($SUDO /usr/sbin/diskutil info "$CARD" | awk -F'[()]' '/Disk Size/{print $2}' | awk '{print $1}')
[[ -n ${card_bytes:-} ]] || die "could not read the card size"
(( card_bytes > 16000000000 )) || die "card looks too small (${card_bytes} bytes)"
# The known-good card is never written. L4T marks its rootfs with nv_tegra_release.
if $SUDO "$DBG" -R "stat /etc/nv_tegra_release" "/dev/$(basename "$CARD")s1" 2>/dev/null | grep -q '^Inode:'; then
  die "$CARD holds an L4T system (/etc/nv_tegra_release); refusing to write the working card"
fi

say "plan"
printf '  card       : %s (%s bytes)\n' "$CARD" "$card_bytes"
printf '  rootfs     : %s\n' "$TARBALL"
[[ -n $ROOT_PASS ]] || die "set ROOT_PASS (initial password for root and $USER_NAME)"
printf '  accounts   : root and %s (password from ROOT_PASS, not shown)\n' "$USER_NAME"
(( WRITE )) || printf '  DRY RUN: pass --write to actually format\n'

if [[ -n $VENDOR_LAYOUT ]]; then
  say "copying the vendor boot region from $VENDOR_LAYOUT"
  # The working card's layout: p1 APP starts at LBA 28672, and p2..p14 are the
  # Tegra bootloader stages (TBC, RP1, EBT, WB0, BPF, DTB, LNX, EKS, BMP...).
  # cboot uses them, so an experimental card must carry the same region.
  # Source may be the working card or a saved region file.
  from_file=0
  if [[ -f $VENDOR_LAYOUT ]]; then
    from_file=1
    vbytes=$(stat -f%z "$VENDOR_LAYOUT")
    (( vbytes >= 26880 * 512 )) || die "$VENDOR_LAYOUT is shorter than the boot region"
  else
    [[ -b $VENDOR_LAYOUT ]] || die "$VENDOR_LAYOUT is neither a block device nor a file"
    vbytes=$($SUDO /usr/sbin/diskutil info "$VENDOR_LAYOUT" | awk -F'[()]' '/Disk Size/{print $2}' | awk '{print $1}')
  fi
  (( from_file )) || (( vbytes >= card_bytes )) \
    || die "vendor card is smaller than the target ($vbytes < $card_bytes)"
  $SUDO /usr/sbin/diskutil unmountDisk "$CARD" >/dev/null 2>&1 || true
  $SUDO /bin/dd if="$VENDOR_LAYOUT" of="$CARD" bs=512 count=26880 conv=fsync 2>/dev/null \
    || die "could not copy the vendor boot region"
  partdev="/dev/$(basename "$CARD")s1"
  ROOTDEV="mmcblk0p1"
  for _ in $(seq 1 20); do
    [[ -b $partdev ]] && break
    $SUDO /usr/sbin/diskutil list "$CARD" >/dev/null 2>&1 || true
    sleep 1
  done
  [[ -b $partdev ]] || die "APP partition $partdev did not appear"
  printf '  APP partition: %s (vendor table, starts at LBA 28672)\n' "$partdev"
else
  say "writing a single-partition GPT (no EFI partition)"
  $SUDO /usr/sbin/diskutil unmountDisk "$CARD" >/dev/null 2>&1 || true
  sectors=$(( card_bytes / 512 ))
  last_lba=$(( sectors - 1 ))
  gptdir="/tmp/nano-gpt-$$"
  if (( BOOT_FAT )); then
    FAT_MB=512 python3 "$(dirname "$0")/make-gpt.py" --prefix "$gptdir" --size "$card_bytes" 2048 ALARM \
      || die "could not build the partition table"
  else
    python3 "$(dirname "$0")/make-gpt.py" --prefix "$gptdir" --size "$card_bytes" 2048 ALARM \
      || die "could not build the partition table"
  fi
  $SUDO /bin/dd if="$gptdir.head" of="$CARD" bs=512 conv=fsync 2>/dev/null \
    || die "could not write the primary GPT"
  $SUDO /bin/dd if="$gptdir.tail" of="$CARD" bs=512 seek=$(( last_lba - 32 )) \
    conv=notrunc,fsync 2>/dev/null || die "could not write the backup GPT"
  rm -f "$gptdir.head" "$gptdir.tail"
  if (( BOOT_FAT )); then
    fatdev="/dev/$(basename "$CARD")s1"
    partdev="/dev/$(basename "$CARD")s2"
    ROOTDEV="mmcblk0p2"
  else
    fatdev=""
    partdev="/dev/$(basename "$CARD")s1"
    ROOTDEV="mmcblk0p1"
  fi
  for _ in $(seq 1 20); do
    [[ -b $partdev ]] && break
    $SUDO /usr/sbin/diskutil list "$CARD" >/dev/null 2>&1 || true
    sleep 1
  done
  [[ -b $partdev ]] || die "partition $partdev did not appear; check diskutil list"
  printf '  root partition: %s, root=%s\n' "$partdev" "$ROOTDEV"
  if (( BOOT_FAT )); then
    [[ -b $fatdev ]] || die "$fatdev did not appear"
    $SUDO /usr/sbin/diskutil eraseVolume MS-DOS BOOT "$fatdev" >/dev/null \
      || die "could not format the FAT boot partition"
    printf '  boot partition: %s (FAT32)\n' "$fatdev"
  fi
fi

say "fetching Arch Linux ARM"
mkdir -p "$(dirname "$TARBALL")"
[[ -f $TARBALL ]] || curl -fL --retry 3 -o "$TARBALL" https://archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz
ls -lh "$TARBALL"

say "creating a case-sensitive staging volume"
rm -f "$STAGE_IMG"
hdiutil create -quiet -size "$STAGE_SIZE" -fs "Case-sensitive HFS+" -volname "ArchStage$$" \
  -type SPARSE "$STAGE_IMG" || die "could not create the staging image"
hdiutil attach -nobrowse "$STAGE_IMG" >/dev/null || die "could not mount $STAGE_IMG"
STAGING=$(hdiutil info | awk -v img="$STAGE_IMG" '
  /^image-path/{want=($3==img)}
  want && /^\/dev\// && $NF ~ /^\//{print $NF; exit} ')
[[ -n ${STAGING:-} && -d $STAGING ]] || die "could not determine the staging mountpoint"
detach_stage() { hdiutil detach -quiet "$STAGING" 2>/dev/null || true; }
trap detach_stage EXIT
touch "$STAGING/.CaseTest"
[[ -e $STAGING/.casetest ]] && die "$STAGING is case-insensitive"
rm -f "$STAGING/.CaseTest"
printf '  staging at: %s\n' "$STAGING"

say "unpacking rootfs"
tar -xpf "$TARBALL" -C "$STAGING" --no-same-owner
[[ -f $STAGING/boot/Image ]] || die "no /boot/Image in the tarball"
[[ -f $STAGING/boot/initramfs-linux.img ]] || die "no initramfs in the tarball"
install -m644 "$STAGING/boot/dtbs/nvidia/tegra210-p3450-0000.dtb" "$STAGING/boot/tegra210-p3450-0000.dtb"

repo=$(cd "$(dirname "$0")/.." && pwd)
b01="$repo/images/mainline-kernel/b01/tegra210-p3448-0002-p3449-0000-b00.dtb"
if [[ -f $b01 ]]; then
  install -m644 "$b01" "$STAGING/boot/tegra210-p3448-0002-p3449-0000-b00.dtb"
  default_dtb=tegra210-p3448-0002-p3449-0000-b00.dtb
else
  echo "warning: B01 DTB missing, defaulting to p3450" >&2
  default_dtb=tegra210-p3450-0000.dtb
fi
# cboot may ignore the FDT line and use its own fdtfile path instead.
mkdir -p "$STAGING/boot/dtb"
install -m644 "$STAGING/boot/tegra210-p3448-0002-p3449-0000-b00.dtb" \
  "$STAGING/boot/kernel_tegra210-p3448-0000-p3449-0000-b00.dtb"
install -m644 "$STAGING/boot/$default_dtb" \
  "$STAGING/boot/dtb/kernel_${default_dtb#tegra210-}"

if (( DIAG )); then
  say "building the diagnostic initramfs"
  bash "$repo/scripts/make-diag-initramfs.sh" "$STAGING/boot/diag-initramfs.img" >/dev/null \
    || die "could not build the diagnostic initramfs"
  cp "$STAGING/boot/diag-initramfs.img" "$STAGING/boot/initrd"
  printf '  diag initramfs: %s bytes\n' "$(wc -c < "$STAGING/boot/diag-initramfs.img" | tr -d ' ')"
fi

say "writing boot entry, fstab and identity"


mkdir -p "$STAGING/boot/extlinux"
cat > "$STAGING/boot/extlinux/extlinux.conf" <<EOF
DEFAULT arch-b01-noinitrd
MENU TITLE Jetson Nano boot
TIMEOUT 30

LABEL arch-b01-noinitrd
      MENU LABEL Arch Linux ARM (B01 DTB, no initramfs)
      LINUX /boot/Image
      FDT /boot/$default_dtb
      APPEND root=/dev/$ROOTDEV rw rootwait console=tty0 fbcon=map:0 loglevel=8

LABEL arch-b01
      MENU LABEL Arch Linux ARM (mainline, B01 DTB, with initramfs)
      LINUX /boot/Image
      INITRD /boot/initramfs-linux.img
      FDT /boot/$default_dtb
      APPEND root=/dev/$ROOTDEV rw rootwait console=tty0 console=ttyS0,115200n8 loglevel=7

LABEL arch-p3450
      MENU LABEL Arch Linux ARM (A02 p3450 DTB)
      LINUX /boot/Image
      INITRD /boot/initramfs-linux.img
      FDT /boot/tegra210-p3450-0000.dtb
      APPEND root=/dev/$ROOTDEV rw rootwait console=tty0 loglevel=7
EOF

if (( DIAG )); then
  # Byte-for-byte the vendor entry shape: same label name, same INITRD path,
  # same ${cbootargs} placeholder, same extras. cboot may key on "primary".
  cat > "$STAGING/boot/extlinux/extlinux.conf" <<EOF
TIMEOUT 30
DEFAULT primary

MENU TITLE L4T boot options

LABEL primary
      MENU LABEL primary kernel
      LINUX /boot/Image
      INITRD /boot/initrd
      FDT /boot/$default_dtb
      APPEND \${cbootargs} root=/dev/$ROOTDEV rw rootwait rootfstype=ext4 console=ttyS0,115200n8 console=tty0 fbcon=map:0 net.ifnames=0 pcie_aspm=off loglevel=7 panic=10 clk_ignore_unused pd_ignore_unused
EOF
fi

if [[ -n $VENDOR_FILES ]]; then
  say "adding vendor control boot entry from $VENDOR_FILES"
  for f in vendor-Image vendor-initrd.img vendor.dtb; do
    [[ -f "$VENDOR_FILES/$f" ]] || die "missing $VENDOR_FILES/$f (run scripts/dump-vendor-boot.sh)"
    install -m644 "$VENDOR_FILES/$f" "$STAGING/boot/$f"
  done
  cat >> "$STAGING/boot/extlinux/extlinux.conf" <<'EOF'

LABEL vendor-control
      MENU LABEL Vendor kernel + DTB (boot plumbing control)
      LINUX /boot/vendor-Image
      INITRD /boot/vendor-initrd.img
      FDT /boot/vendor.dtb
      APPEND root=/dev/mmcblk0p1 rw rootwait console=tty0
EOF
fi

cat > "$STAGING/etc/fstab" <<EOF
LABEL=ALARM  /  ext4  rw,relatime  0 1
EOF
printf '%s\n' "$HOSTNAME_NEW" > "$STAGING/etc/hostname"
ln -sf "/usr/share/zoneinfo/${TIMEZONE:-UTC}" "$STAGING/etc/localtime"
printf 'en_GB.UTF-8 UTF-8\n' > "$STAGING/etc/locale.gen"
printf 'LANG=en_GB.UTF-8\n' > "$STAGING/etc/locale.conf"

hash=$(openssl passwd -6 "$ROOT_PASS")
python3 - "$STAGING/etc/shadow" "$hash" <<'PY'
import sys
path, h = sys.argv[1], sys.argv[2]
out = []
for line in open(path):
    f = line.rstrip("\n").split(":")
    if f[0] == "root":
        f[1] = h
        line = ":".join(f) + "\n"
    out.append(line)
open(path, "w").writelines(out)
PY

hash_user=$(openssl passwd -6 "$ROOT_PASS")
printf '%s:x:1000:1000::/home/%s:/bin/bash\n' "$USER_NAME" "$USER_NAME" >> "$STAGING/etc/passwd"
printf '%s:%s:19000:0:99999:7:::\n' "$USER_NAME" "$hash_user" >> "$STAGING/etc/shadow"
printf '%s:x:1000:\n' "$USER_NAME" >> "$STAGING/etc/group"
printf '%s:!::\n' "$USER_NAME" >> "$STAGING/etc/gshadow"
mkdir -p "$STAGING/home/$USER_NAME"
cp -a "$STAGING/etc/skel/." "$STAGING/home/$USER_NAME/" 2>/dev/null || true
python3 - "$STAGING/etc/group" "$USER_NAME" <<'PY'
import sys
path, user = sys.argv[1], sys.argv[2]
out = []
for line in open(path):
    f = line.rstrip("\n").split(":")
    if f[0] == "wheel":
        members = [m for m in (f[3].split(",") if len(f) > 3 and f[3] else []) if m]
        if user not in members:
            members.append(user)
        f[3] = ",".join(members)
        line = ":".join(f) + "\n"
    out.append(line)
open(path, "w").writelines(out)
PY
mkdir -p "$STAGING/etc/sudoers.d"
printf '%s ALL=(ALL) ALL\n' "$USER_NAME" > "$STAGING/etc/sudoers.d/10-$USER_NAME"
chmod 440 "$STAGING/etc/sudoers.d/10-$USER_NAME"

say "network and observability"
mkdir -p "$STAGING/etc/systemd/network"
# DHCP, plus a fixed address when NANO_ADDRESS (CIDR) and NANO_GATEWAY are set.
{
  printf '[Match]\nName=e*\n\n[Network]\nDHCP=yes\n'
  if [[ -n ${NANO_ADDRESS:-} ]]; then
    printf 'Address=%s\nGateway=%s\n' "$NANO_ADDRESS" "${NANO_GATEWAY:?NANO_ADDRESS needs NANO_GATEWAY}"
  fi
  printf 'DNS=1.1.1.1\n'
} > "$STAGING/etc/systemd/network/20-wired.network"
mkdir -p "$STAGING/etc/systemd/system/multi-user.target.wants"
ln -sf /usr/lib/systemd/system/dhcpcd.service \
  "$STAGING/etc/systemd/system/multi-user.target.wants/dhcpcd.service"
cat > "$STAGING/etc/systemd/system/boot-stamp.service" <<'EOF'
[Unit]
Description=Record that userspace was reached (Jetson Nano bring-up)
After=local-fs.target
Before=multi-user.target

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'printf "%s %s\n" "$(date -Is)" "$(uname -r)" > /boot/boot-stamp'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
ln -sf /etc/systemd/system/boot-stamp.service \
  "$STAGING/etc/systemd/system/multi-user.target.wants/boot-stamp.service"
mkdir -p "$STAGING/var/log/journal"

if (( ! WRITE )); then
  say "dry run complete; card not written"
  exit 0
fi

say "computing owners and modes from the Arch tarball"
# hdiutil ignores ownership, so staging reads as the Mac user and mke2fs -d
# would write every inode as 501:20 with setuid bits lost.
owncmds="/tmp/nano-owners-$$.cmds"
python3 -I "$(dirname "$0")/ownership-commands.py" "$TARBALL" "$STAGING" "$USER_NAME" > "$owncmds" \
  || die "could not compute ownership"

say "creating the ext4 filesystem on $partdev"
$SUDO /usr/sbin/diskutil unmount "$partdev" >/dev/null 2>&1 || true
$SUDO "$E2FS" -t ext4 -F -L ALARM -m 1 -O ^metadata_csum,^metadata_csum_seed,^64bit,^orphan_file,^casefold,^encrypt,^quota -d "$STAGING" "$partdev"
say "applying owners and modes ($(grep -c . "$owncmds") inode edits)"
$SUDO "$DBG" -w -f "$owncmds" "$partdev" >/dev/null 2>&1 || die "debugfs could not apply ownership"
rm -f "$owncmds"
su_stat=$($SUDO "$DBG" -R "stat /usr/bin/su" "$partdev" 2>/dev/null | head -4 | tr '\n' ' ')
[[ $su_stat =~ Mode:\ +04755\ .*User:\ +0\ +Group:\ +0\  ]] || die "ownership check failed on /usr/bin/su: $su_stat"

if (( BOOT_FAT )); then
  say "copying kernel, DTB and extlinux onto the FAT boot partition"
  bootmnt=/Volumes/BOOT
  $SUDO /usr/sbin/diskutil mount "$fatdev" >/dev/null 2>&1 || true
  [[ -d $bootmnt ]] || die "FAT partition did not mount at $bootmnt"
  mkdir -p "$bootmnt/boot/extlinux" "$bootmnt/extlinux"
  cp "$STAGING/boot/Image" "$bootmnt/Image"
  cp "$STAGING/boot/Image" "$bootmnt/boot/Image"
  cp "$STAGING/boot/initramfs-linux.img" "$bootmnt/initramfs-linux.img" 2>/dev/null || true
  cp "$STAGING/boot/initramfs-linux.img" "$bootmnt/boot/initramfs-linux.img" 2>/dev/null || true
  cp "$STAGING/boot/"*.dtb "$bootmnt/" 2>/dev/null || true
  cp "$STAGING/boot/"*.dtb "$bootmnt/boot/" 2>/dev/null || true
  cp "$STAGING/boot/extlinux/extlinux.conf" "$bootmnt/boot/extlinux/extlinux.conf"
  if (( DIAG )); then
    cp "$STAGING/boot/diag-initramfs.img" "$bootmnt/diag-initramfs.img"
    cp "$STAGING/boot/diag-initramfs.img" "$bootmnt/boot/diag-initramfs.img"
  fi
  cp "$STAGING/boot/extlinux/extlinux.conf" "$bootmnt/extlinux/extlinux.conf"
  sync
fi

say "verifying the written card"
echo "  superblock:"
$SUDO "$DUMPE2FS" -h "$partdev" 2>/dev/null | grep -E "volume name|Filesystem features|Block count|Inode count" | sed 's/^/    /'
echo "  /boot:"
$SUDO "$DBG" -R "ls -l /boot" "$partdev" 2>/dev/null | awk 'NF>4 {printf "    %s %s\n", $2, $NF}'
echo "  extlinux.conf:"
$SUDO "$DBG" -R "cat /boot/extlinux/extlinux.conf" "$partdev" 2>/dev/null | sed 's/^/    /'
echo "  users:"
$SUDO "$DBG" -R "cat /etc/passwd" "$partdev" 2>/dev/null | grep -E "^(root|$USER_NAME):" | sed 's/^/    /'

say "done"
cat <<EOF
Card ready: $partdev

Next: diskutil eject $CARD, put it in the Nano, power on.
After the boot attempt, put the card back in the Mac and run:
  bash $repo/scripts/read-boot-evidence.sh --card $CARD
That prints /boot/boot-stamp and the tail of the journal, which say whether the
kernel reached userspace.
EOF
