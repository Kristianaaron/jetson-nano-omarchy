#!/usr/bin/env bash
# G1: NVIDIA's R36 Vulkan driver on nvgpu (CUDA boot mode: nvmap and nvgpu loaded, GPU on).
# Uses only the unpacked L4T R36.4 packages: the Vulkan ICD (libGLX_nvidia) needs NVIDIA's own EGL
# vendor registered with glvnd, or it finds no NVIDIA EGL and refuses to create an instance.
set -u
S=${E0_SRC:-/home/omarchy/cuda-e0/src}
G=$S/g0/r36/usr/lib/aarch64-linux-gnu
T=$(mktemp -d)
printf '{"file_format_version":"1.0.0","ICD":{"library_path":"%s/nvidia/libGLX_nvidia.so.0","api_version":"1.3.251"}}\n' "$G" > "$T/icd.json"
printf '{"file_format_version":"1.0.0","ICD":{"library_path":"%s/tegra-egl/libEGL_nvidia.so.0"}}\n' "$G" > "$T/egl.json"
export VK_DRIVER_FILES=$T/icd.json __EGL_VENDOR_LIBRARY_FILENAMES=$T/egl.json
export LD_LIBRARY_PATH="$S/libs/r36.4-l4t-cuda/usr/lib/aarch64-linux-gnu/nvidia:$S/libs/r36.4-l4t-core/usr/lib/aarch64-linux-gnu/nvidia:$G/nvidia:$G/tegra-egl"
echo "G1 vulkaninfo --summary"
timeout 120 vulkaninfo --summary 2>&1 | head -60
echo "G1 vulkaninfo exit=${PIPESTATUS[0]}"
rm -rf "$T"
