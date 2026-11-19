#!/usr/bin/env bash
# G2: run the Omarchy desktop on the nvgpu stack (Mesa Zink -> NVIDIA R36 Vulkan -> nvgpu) for
# one boot. Called by e4-autorun.sh in the CUDA boot mode, before the display manager starts.
# Everything it writes lives under /run and is gone at the next boot; the libraries are an
# unpacked copy in /opt/nvidia-l4t-r36-test until the R36 userspace is packaged.
set -eu
S=${E0_SRC:-/home/omarchy/cuda-e0/src}
O=/opt/nvidia-l4t-r36-test
if [[ ! -e $O/lib/libGLX_nvidia.so.0 ]]; then
  mkdir -p $O/lib $O/share
  cp -a $S/libs/r36.4-l4t-core/usr/lib/aarch64-linux-gnu/nvidia/. $O/lib/
  cp -a $S/libs/r36.4-l4t-cuda/usr/lib/aarch64-linux-gnu/nvidia/. $O/lib/
  cp -a $S/g0/r36/usr/lib/aarch64-linux-gnu/nvidia/. $O/lib/
  cp -a $S/g0/r36/usr/lib/aarch64-linux-gnu/tegra-egl/. $O/lib/
  rm -f $O/lib/ld.so.conf $O/lib/nvidia.json $O/lib/nvidia_icd.json
  chmod -R a+rX $O
fi
printf '{"file_format_version":"1.0.0","ICD":{"library_path":"%s/lib/libGLX_nvidia.so.0","api_version":"1.3.251"}}\n' $O > $O/share/nvidia_icd.json
printf '{"file_format_version":"1.0.0","ICD":{"library_path":"%s/lib/libEGL_nvidia.so.0"}}\n' $O > $O/share/nvidia_egl.json
env="VK_DRIVER_FILES=$O/share/nvidia_icd.json
__EGL_VENDOR_LIBRARY_FILENAMES=/usr/share/glvnd/egl_vendor.d/50_mesa.json:$O/share/nvidia_egl.json
LD_LIBRARY_PATH=$O/lib
MESA_LOADER_DRIVER_OVERRIDE=zink"
mkdir -p /run/environment.d /run/systemd/system/sddm.service.d
printf '%s\n' "$env" > /run/environment.d/90-g2-nvgpu-desktop.conf
{ echo "[Service]"; printf '%s\n' "$env" | sed 's/^/Environment=/'; } > /run/systemd/system/sddm.service.d/zz-g2-nvgpu-desktop.conf
# Device nodes are root-only until udev rules are packaged.
chmod 0666 /dev/nvmap /dev/nvhost-* /dev/nvgpu/igpu0/*
systemctl daemon-reload
echo "G2 desktop environment set for this boot"
