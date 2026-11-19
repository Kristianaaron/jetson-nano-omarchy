#!/usr/bin/env bash
# E2: build NVIDIA's R36 nvgpu (OE4T/linux-nvgpu patches-rel-36) out of tree against the running
# mainline kernel, the way JetPack 6 builds it (conftest from linux-nv-oot, then nvgpu as an OOT
# module). Build only: nothing is loaded. Run on the Nano.
# Usage: build-nvgpu.sh [SRC_DIR (default ~/cuda)] [extra make args...]
set -uo pipefail
SRC=${1:-$HOME/cuda}; shift || true
# KVER selects the target kernel (default: the running one); conftest output is per kernel.
KVER=${KVER:-$(uname -r)}
KDIR=/usr/lib/modules/$KVER/build
NVGPU=$SRC/linux-nvgpu
OOT=$SRC/linux-nv-oot
CONF=$SRC/build/$KVER/conftest
LOG=$SRC/build/$KVER/logs
mkdir -p "$CONF/nvidia" "$LOG"
JOBS=${JOBS:-3}

# 1. conftest: probes the kernel API and writes nvidia/conftest.h and friends.
if [[ ! -s $CONF/nvidia/conftest/headers.h ]]; then
  cp -a "$OOT/scripts/conftest/." "$CONF/nvidia/"
  nice -n 19 make -j"$JOBS" ARCH=arm64 -C "$KDIR" src="$CONF/nvidia" obj="$CONF/nvidia" \
    NV_KERNEL_SOURCES="$KDIR" NV_KERNEL_OUTPUT="$KDIR" -f "$CONF/nvidia/Makefile" \
    > "$LOG/conftest.log" 2>&1
  echo "conftest exit=$?"
fi

# 2. nvgpu with NVIDIA's own default feature set (the only combination NVIDIA builds; dGPU and
#    GV11B code is compiled but finds no such device on the Nano). Only change: no host1x-next or
#    nvmap-next from nv-oot, which would fight the mainline host1x that tegra-drm uses; no VPR
#    (mainline has no video protected region); no nv-oot mc-utils (it only loads on Tegra234);
#    fuses read with tegra_fuse_readl() instead of NVMEM cells (mainline registers the GPU
#    gcplex-config-fuse cell only for Tegra194; same offsets, see mainline fuse-tegra30.c).
#    -k so one pass collects every error.
nice -n 19 make -k -j"$JOBS" ARCH=arm64 -C "$KDIR" M="$NVGPU/drivers/gpu/nvgpu" \
  CONFIG_TEGRA_OOT_MODULE=m srctree.nvidia="$OOT" srctree.nvconftest="$CONF" \
  CONFIG_TEGRA_HOST1X_NEXT= CONFIG_TEGRA_NVMAP_NEXT= \
  CONFIG_NVGPU_VPR= CONFIG_NVGPU_TEGRA_MC_UTILS= CONFIG_NVGPU_NVMEM_FUSE=n \
  "$@" modules > "$LOG/nvgpu.log" 2>&1
rc=$?
echo "nvgpu exit=$rc"
grep -cE "error:" "$LOG/nvgpu.log" | sed 's/^/errors: /'
grep -oE "^[^ :]+\.[ch]:[0-9]+:[0-9]+: error: .*" "$LOG/nvgpu.log" \
  | sed -E 's/:[0-9]+:[0-9]+: error:/: error:/' | sort | uniq -c | sort -rn > "$LOG/nvgpu-errors.txt"
ls -l "$NVGPU"/drivers/gpu/nvgpu/*.ko 2>/dev/null
echo E2-BUILD-DONE
