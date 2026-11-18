#!/bin/bash
# Omarchy hardware hook: NVIDIA Jetson Nano (Tegra210).
#
# Runs inside the target system from omarchy-apply-hardware, guarded by
# omarchy-hw-aarch64-tegra210. This is the only place the Nano's differences from
# generic aarch64 belong. Everything here must be idempotent.

set -euo pipefail

omarchy-hw-aarch64-tegra210 || return 0

echo "Detected NVIDIA Jetson Nano (Tegra210), applying platform configuration..."

# 1. Boot ownership.
#
# The board boots NVIDIA cboot/U-Boot with /boot/extlinux/extlinux.conf. Omarchy's
# generic arm64 lifecycle assumes Limine and a UKI, neither of which exists here.
# Mark the boot step as not-managed so an Omarchy update can never rewrite or
# remove the boot entry that makes the card bootable.
mkdir -p /etc/omarchy
cat > /etc/omarchy/boot.conf <<'CONF'
# Tegra210: boot files are owned by the image, not by Omarchy.
# omarchy-lifecycle-dispatch setup-boot is a no-op on this platform.
OMARCHY_BOOT_MANAGED=0
OMARCHY_BOOT_LOADER=extlinux
OMARCHY_BOOT_FDT=tegra210-p3450-0000.dtb
CONF

# 2. Memory.
#
# 4 GB shared with the GPU. zram-generator is in the aarch64 package list; give it
# a size that leaves room for a compositor and a terminal without thrashing.
mkdir -p /etc/systemd/zram-generator.conf.d
cat > /etc/systemd/zram-generator.conf.d/omarchy-tegra210.conf <<'CONF'
# Tegra210: 4 GB unified memory, no expansion, SD-card root.
[zram0]
zram-size = min(ram / 2, 3072)
compression-algorithm = zstd
CONF

# Keep the kernel from over-eagerly swapping the model-free desktop to zram.
cat > /etc/sysctl.d/99-omarchy-tegra210.conf <<'CONF'
vm.swappiness = 100
vm.watermark_boost_factor = 0
vm.watermark_scale_factor = 125
CONF

# 3. Graphics honesty.
#
# Tegra X1 has no mainline GPU reclocking. Whether the session is accelerated is a
# measurement, not an assumption: record the renderer so nothing downstream claims
# GPU acceleration that Mesa does not provide.
if command -v eglinfo >/dev/null 2>&1; then
  renderer=$(eglinfo -B 2>/dev/null | awk -F': ' '/OpenGL renderer/ {print $2; exit}' || true)
  printf 'OMARCHY_RENDERER=%s\n' "${renderer:-unknown}" >> /etc/omarchy/boot.conf
fi

# 4. Power and thermals.
#
# mainline has no nvpmodel; do not call it. Record thermals only.
if command -v sensors >/dev/null 2>&1; then
  sensors >/dev/null 2>&1 || true
fi

echo "Tegra210 platform configuration applied."
