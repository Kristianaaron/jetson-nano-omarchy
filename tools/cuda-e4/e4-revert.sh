#!/usr/bin/env bash
# Undo e4-probe.sh: unload nvgpu, give the GPU back to nouveau, restart the desktop.
set -uo pipefail
DEV=57000000.gpu
rmmod nvgpu 2>&1 || echo "rmmod failed (a reboot also restores everything)"
echo > /sys/bus/platform/devices/$DEV/driver_override
echo -n "" > /sys/module/firmware_class/parameters/path
echo "$DEV" > /sys/bus/platform/drivers/nouveau/bind 2>&1 && echo "nouveau rebound"
readlink /sys/bus/platform/devices/$DEV/driver
systemctl start sddm && echo "sddm started"
dmesg | tail -15
