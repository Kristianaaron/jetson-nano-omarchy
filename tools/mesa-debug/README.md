# Mesa tegra debug harness

This builds a debug Mesa with the tegra and nouveau gallium drivers, then runs a small GBM/EGL render test under gdb on the Jetson Nano.

Run these commands as root, in order:

1. `bash tools/mesa-debug/build-mesa-tegra-debug.sh`
2. `bash tools/mesa-debug/run-gbmclear-gdb.sh`

The build installs to `/opt/mesa-debug`; logs and render results go to `/var/log/mesa-debug-build.log` and `/root/mesa-debug-results`. The build uses a private prefix and never replaces the system Mesa.
