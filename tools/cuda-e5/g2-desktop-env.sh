#!/usr/bin/env bash
# G2: run the Omarchy desktop on the nvgpu stack (Mesa Zink -> NVIDIA R36 Vulkan -> nvgpu) for
# one boot. Called by e4-autorun.sh in the CUDA boot mode, before the display manager starts.
# Everything it writes lives under /run and is gone at the next boot; the libraries are an
# unpacked copy in /opt/nvidia-l4t-r36-test until the R36 userspace is packaged.
set -eu
S=${E0_SRC:-/home/omarchy/cuda-e0/src}
O=/opt/nvidia-l4t-r36-test
# Rebuild the library copy every time into a new folder, verify every file against its source,
# flush it to disk, then swap it in: a crash during an earlier boot left truncated libraries.
SRCS="$S/libs/r36.4-l4t-core/usr/lib/aarch64-linux-gnu/nvidia $S/libs/r36.4-l4t-cuda/usr/lib/aarch64-linux-gnu/nvidia $S/g0/r36/usr/lib/aarch64-linux-gnu/nvidia $S/g0/r36/usr/lib/aarch64-linux-gnu/tegra-egl"
mkdir -p $O/share
rm -rf $O/lib.new && mkdir -p $O/lib.new
for d in $SRCS; do cp -a "$d/." $O/lib.new/; done
rm -f $O/lib.new/ld.so.conf $O/lib.new/nvidia.json $O/lib.new/nvidia_icd.json
for d in $SRCS; do
  for f in "$d"/*; do
    b=$(basename "$f"); case $b in ld.so.conf|nvidia.json|nvidia_icd.json) continue;; esac
    if [[ -L $f ]]; then [[ $(readlink "$f") == $(readlink "$O/lib.new/$b") ]]
    else cmp -s "$f" "$O/lib.new/$b"; fi || { echo "copy check failed: $b" >&2; exit 1; }
  done
done
chmod -R a+rX $O/lib.new
sync -f $O/lib.new
rm -rf $O/lib.old; [[ -d $O/lib ]] && mv $O/lib $O/lib.old
mv $O/lib.new $O/lib && rm -rf $O/lib.old
sync -f $O
# The Vulkan ICD is NVIDIA's EGL library: it exports the same ICD entry points, but libGLX_nvidia
# calls XOpenDisplay() while it loads, which deadlocks Xwayland (glamor on Zink loads the ICD inside
# the X server itself) and blocks every other client behind it.
printf '{"file_format_version":"1.0.0","ICD":{"library_path":"%s/lib/libEGL_nvidia.so.0","api_version":"1.3.251"}}\n' $O > $O/share/nvidia_icd.json
printf '{"file_format_version":"1.0.0","ICD":{"library_path":"%s/lib/libEGL_nvidia.so.0"}}\n' $O > $O/share/nvidia_egl.json
env="VK_DRIVER_FILES=$O/share/nvidia_icd.json
__EGL_VENDOR_LIBRARY_FILENAMES=/usr/share/glvnd/egl_vendor.d/50_mesa.json:$O/share/nvidia_egl.json
LD_LIBRARY_PATH=$O/lib
MESA_LOADER_DRIVER_OVERRIDE=zink
LIBGL_KOPPER_DISABLE=true"
# LIBGL_KOPPER_DISABLE: present through dma-buf (as the compositor does) instead of NVIDIA's Vulkan
# WSI, which deadlocks in pthread_cond_destroy inside libnvidia-eglcore on eglMakeCurrent.
mkdir -p /run/environment.d /run/systemd/system/sddm.service.d
printf '%s\n' "$env" > /run/environment.d/90-g2-nvgpu-desktop.conf
{ echo "[Service]"; printf '%s\n' "$env" | sed 's/^/Environment=/'; } > /run/systemd/system/sddm.service.d/zz-g2-nvgpu-desktop.conf
# Device nodes are root-only until udev rules are packaged.
chmod 0666 /dev/nvmap /dev/nvhost-* /dev/nvgpu/igpu0/*
systemctl daemon-reload
echo "G2 desktop environment set for this boot"
