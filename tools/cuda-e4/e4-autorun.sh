#!/usr/bin/env bash
# E4 test at boot: runs only while /root/e4-autorun.enabled exists. Streams the kernel log to the
# Mac with netconsole, loads nvgpu, triggers the first power-on. Nothing is installed.
set -u
[[ -f /root/e4-autorun.enabled ]] || exit 0
. /root/e4-autorun.enabled   # MODULE=..., LOG_MASK=..., NETCON=...
E4=/home/omarchy/cuda/e4; D=57000000.gpu
modprobe netconsole netconsole="$NETCON"
echo 8 > /proc/sys/kernel/printk
echo "<6>nvgpu-e4: autorun start module=$MODULE log_mask=$LOG_MASK" > /dev/kmsg
if readlink /sys/bus/platform/devices/$D/driver >/dev/null; then
  echo "<3>nvgpu-e4: autorun abort: $D already has a driver" > /dev/kmsg; exit 1
fi
echo -n "$E4/fw" > /sys/module/firmware_class/parameters/path
echo gk20a > /sys/bus/platform/devices/$D/driver_override
insmod "$E4/$MODULE" log_mask="$LOG_MASK"
echo "<6>nvgpu-e4: autorun insmod exit=$? driver=$(readlink /sys/bus/platform/devices/$D/driver)" > /dev/kmsg
sleep 3
echo "<6>nvgpu-e4: autorun opening ctrl" > /dev/kmsg
python3 -c "import os; fd=os.open('/dev/nvhost-ctrl-gpu', os.O_RDWR); os.close(fd)" \
  && echo "<6>nvgpu-e4: autorun POWER-ON OK" > /dev/kmsg \
  || echo "<3>nvgpu-e4: autorun power-on failed" > /dev/kmsg
ls /dev/nvgpu/igpu0 > /dev/kmsg 2>&1
echo "<6>nvgpu-e4: autorun end" > /dev/kmsg
