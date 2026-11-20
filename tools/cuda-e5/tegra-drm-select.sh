#!/bin/sh
# G2 test only: load a patched tegra-drm in the CUDA boot mode, the stock one otherwise.
# Installed as a modprobe "install" rule (g2-tegra-drm.conf), so it runs whenever tegra_drm is
# requested; the patched module lives outside the module tree and is used by nothing else.
PATCHED=/opt/g2-test/tegra-drm.ko
if grep -qw 'nano.mode=cuda' /proc/cmdline && [ -f "$PATCHED" ]; then
  /usr/bin/modprobe -q host1x
  /usr/bin/modprobe -q drm_client_lib
  exec /usr/bin/insmod "$PATCHED" "$@"
fi
exec /usr/bin/modprobe --ignore-install tegra_drm "$@"
