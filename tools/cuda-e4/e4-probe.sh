#!/usr/bin/env bash
# E4 first probe: hand the GM20B from nouveau to nvgpu and record what nvgpu does.
# Run as root on the Nano. Revert with e4-revert.sh (or reboot).
set -uo pipefail
E4=${E4:-/home/omarchy/cuda/e4}
DEV=57000000.gpu
step() { printf '\n== %s\n' "$*"; }

if readlink /sys/bus/platform/devices/$DEV/driver >/dev/null; then
step "1. close the graphical session (it holds nouveau's render nodes)"
systemctl stop sddm
loginctl terminate-user omarchy 2>/dev/null || true
for i in $(seq 1 20); do
  holders=$(fuser /dev/dri/renderD* 2>/dev/null | wc -w)
  [[ $holders -eq 0 ]] && break; sleep 1
done
fuser -v /dev/dri/renderD* 2>&1 | grep -v "^ *USER" || echo "render nodes free"

step "2. unbind nouveau"
echo "$DEV" > /sys/bus/platform/drivers/nouveau/unbind && echo unbound
readlink /sys/bus/platform/devices/$DEV/driver || echo "no driver bound"
else
step "1-2. no driver holds $DEV (nouveau not loaded): nothing to unbind"
fi

step "3. firmware search path and driver override"
echo -n "$E4/fw" > /sys/module/firmware_class/parameters/path
cat /sys/module/firmware_class/parameters/path; echo
echo gk20a > /sys/bus/platform/devices/$DEV/driver_override

step "4. load nvgpu"
dmesg -C
insmod "$E4/nvgpu.ko"; echo "insmod exit=$?"
sleep 3
readlink /sys/bus/platform/devices/$DEV/driver || echo "no driver bound"
dmesg

step "5. device nodes"
ls -l /dev/nvhost-*gpu* /dev/nvgpu/igpu0/ 2>&1 | head -30

step "6. first power-on: open the control node"
dmesg -C
timeout 20 python3 -c "import os; fd=os.open('/dev/nvhost-ctrl-gpu', os.O_RDWR); print('opened ctrl fd', fd); os.close(fd)"
echo "open exit=$?"
sleep 2
dmesg
echo E4-PROBE-DONE
