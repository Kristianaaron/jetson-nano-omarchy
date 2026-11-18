#!/bin/bash
# Generate a mainline device tree for the Jetson Nano B01 kit from the existing
# p3450 (A02) tree.
#
# Why this exists: mainline ships tegra210-p3450-0000.dts (A02 dev kit) and
# tegra210-p3541-0000.dts (2GB kit), but no B01 dev kit tree, and the board
# reports:
#   nvidia,p3449-0000-b00+p3448-0000-b00 nvidia,jetson-nano nvidia,tegra210
#
# The B01 differences that matter to board bring-up are the second CSI connector
# (J49), the removed button header (J40) and the moved power-select jumper (J48).
# None of them touch the subsystems this port needs: display, PCIe/Ethernet, USB,
# SD and audio. So the B01 tree is derived from p3450 with the model and
# compatible strings corrected, which is also the shape the p3541 series took.
#
# Usage: bash make-b01-dts.sh /path/to/linux-source
set -euo pipefail

KDIR=${1:?usage: make-b01-dts.sh <linux-source-dir>}
dtsdir="$KDIR/arch/arm64/boot/dts/nvidia"
src="$dtsdir/tegra210-p3450-0000.dts"
dst="$dtsdir/tegra210-p3448-0002-p3449-0000-b00.dts"

[[ -f $src ]] || { echo "missing $src" >&2; exit 1; }
[[ -f $dst ]] && { echo "$dst already exists, not overwriting" >&2; exit 1; }

sed -E \
  -e 's/model = "NVIDIA Jetson Nano Developer Kit"/model = "NVIDIA Jetson Nano Developer Kit B01"/' \
  -e 's/compatible = "nvidia,p3450-0000", "nvidia,tegra210"/compatible = "nvidia,p3449-0000-b00+p3448-0000-b00", "nvidia,jetson-nano", "nvidia,tegra210"/' \
  "$src" > "$dst"

if ! grep -q 'tegra210-p3448-0002-p3449-0000-b00.dtb' "$dtsdir/Makefile"; then
  printf 'dtb-$(CONFIG_ARCH_TEGRA_210_SOC) += tegra210-p3448-0002-p3449-0000-b00.dtb\n' \
    >> "$dtsdir/Makefile"
fi

echo "wrote $dst"
echo "added to $dtsdir/Makefile"
echo
echo "Build with:"
echo "  make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- dtbs"
echo "  # result: arch/arm64/boot/dts/nvidia/tegra210-p3448-0002-p3449-0000-b00.dtb"
echo
echo "Note: this is a first-boot hypothesis, not verified silicon. If the B01 boot"
echo "fails while the p3450 tree boots, diff the two against NVIDIA's R32.6.1 B01"
echo "device tree before changing anything else."
