#!/usr/bin/env bash
# E4/E5 test at boot: runs only while /root/e4-autorun.enabled exists and the kernel command
# line has nano.mode=cuda. Streams the kernel log to the
# listener with netconsole, loads nvmap (optional) and nvgpu, triggers the first power-on, then runs
# an optional CUDA test. Nothing is installed.
#
# /root/e4-autorun.enabled is sourced and sets:
#   MODULE=nvgpu.ko            nvgpu module, relative to DIR (default /home/omarchy/cuda/e4)
#   DIR=/home/omarchy/cuda/e5  optional, where MODULE and NVMAP live
#   NVMAP=nvmap.ko             optional, loaded before nvgpu (CUDA allocates through /dev/nvmap)
#   LOG_MASK=0x3               optional, only for debug builds that have the log_mask parameter
#   NETCON=...                 netconsole target, see Documentation/networking/netconsole.rst
#   SMOKE="cmd args"           optional, run after a successful power-on; output goes to
#                              /root/e5-smoke.log and its last line to the kernel log
#   GPU_IOMMU=DMA              optional, put the GPU behind a translating SMMU domain
#   DESKTOP_ENV=/path/script   optional, run after power-on to set the desktop up on nvgpu
#                              (the unit runs before display-manager.service)
set -u
[[ -f /root/e4-autorun.enabled ]] || exit 0
# Only in the CUDA boot mode (boot entry nano-cuda: nouveau blacklisted, nano.mode=cuda).
grep -qw 'nano.mode=cuda' /proc/cmdline || exit 0
DIR=/home/omarchy/cuda/e4; NVMAP=; LOG_MASK=; SMOKE=; DESKTOP_ENV=; GPU_IOMMU=
. /root/e4-autorun.enabled
FW=/home/omarchy/cuda/e4/fw; D=57000000.gpu
kmsg() { echo "<$1>nvgpu-e4: $2" > /dev/kmsg; }
modprobe netconsole netconsole="$NETCON"
echo 8 > /proc/sys/kernel/printk
kmsg 6 "autorun start kernel=$(uname -r) dir=$DIR module=$MODULE nvmap=${NVMAP:-none} log_mask=${LOG_MASK:-none}"
if readlink /sys/bus/platform/devices/$D/driver >/dev/null; then
  kmsg 3 "autorun abort: $D already has a driver"; exit 1
fi
if [[ -n $NVMAP ]]; then
  insmod "$DIR/$NVMAP"
  kmsg 6 "autorun nvmap insmod exit=$? node=$(ls /dev/nvmap 2>&1)"
fi
if [[ -n $GPU_IOMMU ]]; then
  # GPU_IOMMU=DMA: translate GPU accesses through the SMMU instead of the default identity
  # (passthrough) domain; only possible while no driver is bound to the GPU.
  g=/sys/bus/platform/devices/$D/iommu_group
  echo "$GPU_IOMMU" > $g/type
  kmsg 6 "autorun gpu iommu group $(basename "$(readlink $g)") type=$(cat $g/type)"
fi
echo -n "$FW" > /sys/module/firmware_class/parameters/path
echo gk20a > /sys/bus/platform/devices/$D/driver_override
insmod "$DIR/$MODULE" ${LOG_MASK:+log_mask="$LOG_MASK"}
kmsg 6 "autorun insmod exit=$? driver=$(readlink /sys/bus/platform/devices/$D/driver)"
sleep 3
kmsg 6 "autorun opening ctrl"
if python3 -c "import os; fd=os.open('/dev/nvhost-ctrl-gpu', os.O_RDWR); os.close(fd)"; then
  kmsg 6 "autorun POWER-ON OK"
  if [[ -n $SMOKE ]]; then
    kmsg 6 "autorun smoke start: $SMOKE"
    timeout 300 bash -c "$SMOKE" > /root/e5-smoke.log 2>&1
    rc=$?
    while IFS= read -r line; do kmsg 6 "smoke: $line"; done < /root/e5-smoke.log
    kmsg 6 "autorun smoke exit=$rc"
  fi
  if [[ -n $DESKTOP_ENV ]]; then
    "$DESKTOP_ENV" > /root/g2-desktop-env.log 2>&1
    kmsg 6 "autorun desktop env exit=$? ($DESKTOP_ENV)"
  fi
else
  kmsg 3 "autorun power-on failed"
fi
ls /dev/nvgpu/igpu0 > /dev/kmsg 2>&1
kmsg 6 "autorun end"
