#!/usr/bin/env bash
# E5: run cuda_smoke against the unpacked L4T R36.4 userspace and NVRTC 12.6 from the E0 fetch.
# Needs nvmap and nvgpu loaded and the GPU powered (see tools/cuda-e4/e4-autorun.sh). Run as root
# (the nvgpu device nodes are root-only until udev rules are packaged).
set -u
S=${E0_SRC:-/home/omarchy/cuda-e0/src}
# libnvidia-ptxjitcompiler (driver PTX JIT) ships in nvidia-l4t-3d-core, unpacked by the G0 desk check.
export LD_LIBRARY_PATH="$S/libs/r36.4-l4t-cuda/usr/lib/aarch64-linux-gnu/nvidia:$S/libs/r36.4-l4t-core/usr/lib/aarch64-linux-gnu/nvidia:$S/g0/r36/usr/lib/aarch64-linux-gnu/nvidia:$S/cuda12/cuda_nvrtc/cuda_nvrtc-linux-sbsa-12.6.85-archive/lib"
echo "kernel $(uname -r); nvmap $(ls /dev/nvmap 2>&1); gpu driver $(basename "$(readlink /sys/bus/platform/devices/57000000.gpu/driver)")"
exec "${SMOKE_BIN:-/home/omarchy/cuda/cuda_smoke}"
