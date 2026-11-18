#!/usr/bin/env bash
# E2: build nvmap (OE4T/linux-nv-oot patches-rel-36, drivers/video/tegra/nvmap) out of tree against
# the running kernel. Build only: nothing is loaded. Run on the Nano after build-nvgpu.sh has
# produced conftest output, or let this script generate its own.
# Usage: build-nvmap.sh [SRC_DIR (default ~/cuda)]
#
# CONFIG_ARCH_HAS_PMEM_API=y only gets past nvmap's config check. On a kernel without
# CONFIG_ARM64_PMEM, arch_invalidate_pmem() is an empty stub, so nvmap's CPU cache invalidation does
# nothing. The module may be loaded for probe tests, but must not run CUDA work until the kernel
# (linux-nano) has CONFIG_ARM64_PMEM=y.
# NVMAP_CONFIG_SCIIPC=n: NvSciIpc buffer sharing needs nv-oot's nvsciipc module; not needed for CUDA.
set -uo pipefail
SRC=${1:-$HOME/cuda}
KDIR=/usr/lib/modules/$(uname -r)/build
OOT=$SRC/linux-nv-oot
CONF=$SRC/build/conftest
LOG=$SRC/build/logs
N=$OOT/drivers/video/tegra/nvmap
JOBS=${JOBS:-3}
mkdir -p "$CONF/nvidia" "$LOG"
if [[ ! -s $CONF/nvidia/conftest/headers.h ]]; then
  cp -a "$OOT/scripts/conftest/." "$CONF/nvidia/"
  nice -n 19 make -j"$JOBS" ARCH=arm64 -C "$KDIR" src="$CONF/nvidia" obj="$CONF/nvidia" \
    NV_KERNEL_SOURCES="$KDIR" NV_KERNEL_OUTPUT="$KDIR" -f "$CONF/nvidia/Makefile" \
    > "$LOG/conftest.log" 2>&1
  echo "conftest exit=$?"
fi
grep -q '^CONFIG_ARM64_PMEM=y' "$KDIR/.config" || echo "NOTE: kernel lacks CONFIG_ARM64_PMEM; nvmap cache invalidation is a no-op on this kernel"
make -s -C "$KDIR" M="$N" clean >/dev/null 2>&1
nice -n 19 make -k -j"$JOBS" ARCH=arm64 -C "$KDIR" M="$N" \
  CONFIG_TEGRA_OOT_MODULE=m CONFIG_ARCH_HAS_PMEM_API=y NVMAP_CONFIG_SCIIPC=n \
  srctree.nvidia-oot="$OOT" srctree.nvconftest="$CONF" KCFLAGS="-I$CONF -I$OOT/include" \
  modules > "$LOG/nvmap.log" 2>&1
echo "nvmap exit=$?"
grep -cE "error:" "$LOG/nvmap.log" | sed 's/^/errors: /'
grep -E "ERROR: modpost|WARNING: modpost" "$LOG/nvmap.log"
ls -l "$N"/*.ko 2>/dev/null
echo NVMAP-BUILD-DONE
