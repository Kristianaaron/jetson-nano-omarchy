#!/usr/bin/env bash
# G1: run vk_probe (Vulkan compute on NVIDIA R36 over nvgpu) against the unpacked R36 userspace.
S=${E0_SRC:-/home/omarchy/cuda-e0/src}
G=$S/g0/r36/usr/lib/aarch64-linux-gnu
T=$(mktemp -d)
printf '{"file_format_version":"1.0.0","ICD":{"library_path":"%s/nvidia/libGLX_nvidia.so.0","api_version":"1.3.251"}}\n' "$G" > "$T/icd.json"
printf '{"file_format_version":"1.0.0","ICD":{"library_path":"%s/tegra-egl/libEGL_nvidia.so.0"}}\n' "$G" > "$T/egl.json"
export VK_DRIVER_FILES=$T/icd.json __EGL_VENDOR_LIBRARY_FILENAMES=$T/egl.json
export LD_LIBRARY_PATH="$S/libs/r36.4-l4t-cuda/usr/lib/aarch64-linux-gnu/nvidia:$S/libs/r36.4-l4t-core/usr/lib/aarch64-linux-gnu/nvidia:$G/nvidia:$G/tegra-egl"
timeout 120 /home/omarchy/cuda/vk_probe 2>&1 | grep -vE "^ok |nvdc|tegra_dc_ctrl"
rm -rf "$T"
