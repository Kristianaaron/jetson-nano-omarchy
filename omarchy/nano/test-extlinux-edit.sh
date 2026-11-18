#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib-extlinux.sh"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

cat > "$TMP_DIR/a.conf" <<'EOF'
LABEL primary
      LINUX /boot/Image
      INITRD /boot/initrd
      FDT /boot/tegra210-p3448-0002-p3449-0000-b00.dtb
      APPEND ${cbootargs} quiet root=/dev/mmcblk0p1 rw rootwait video=HDMI-A-1:e
EOF

cat > "$TMP_DIR/expected.conf" <<'EOF'
LABEL primary
      LINUX /boot/Image
      INITRD /boot/initramfs-linux.img
      FDT /boot/tegra210-p3448-0002-p3449-0000-b00.dtb
      APPEND ${cbootargs} root=LABEL=ALARM rw rootwait video=HDMI-A-1:1280x720@60e loglevel=7 panic=10 clk_ignore_unused pd_ignore_unused
EOF

cat > "$TMP_DIR/b.conf" <<'EOF'
LABEL primary
      LINUX /boot/Image
      INITRD /boot/initramfs-linux.img
      FDT /boot/tegra210-p3448-0002-p3449-0000-b00.dtb
      APPEND ${cbootargs} root=LABEL=ALARM rw rootwait video=HDMI-A-1:1280x720@60e loglevel=7 panic=10 clk_ignore_unused pd_ignore_unused
EOF

edit_extlinux "$TMP_DIR/a.conf"
if diff -u "$TMP_DIR/expected.conf" "$TMP_DIR/a.conf"; then
  printf 'PASS fixture A\n'
else
  printf 'FAIL fixture A\n' >&2
  exit 1
fi

edit_extlinux "$TMP_DIR/b.conf"
if diff -u "$TMP_DIR/expected.conf" "$TMP_DIR/b.conf"; then
  printf 'PASS fixture B\n'
else
  printf 'FAIL fixture B\n' >&2
  exit 1
fi
