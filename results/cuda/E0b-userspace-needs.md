# E0b userspace needs

## `nvidia-l4t-core/usr/lib/aarch64-linux-gnu/tegra/libnvos.so`

- Package: `nvidia-l4t-core 32.7.6-20241104234540`
- Highest GLIBC symbol version seen by `readelf -V`: `2.17`
- NEEDED: `libpthread.so.0`, `libdl.so.2`, `librt.so.1`, `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - `/proc/self/cmdline`

## `nvidia-l4t-core/usr/lib/aarch64-linux-gnu/tegra/libnvrm.so`

- Package: `nvidia-l4t-core 32.7.6-20241104234540`
- Highest GLIBC symbol version seen by `readelf -V`: `2.17`
- NEEDED: `libnvos.so`, `libpthread.so.0`, `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - `/dev/ion`
  - `/dev/nvhost-ctrl`
  - `/dev/nvhost-ctrl-gpu`
  - `/dev/nvmap`
  - `/sys/devices/soc0/revision`
  - `/sys/devices/soc0/soc_id`
  - `/sys/module/fuse/parameters/tegra_chip_id`
  - `/sys/module/fuse/parameters/tegra_chip_rev`
  - `/sys/module/fuse/parameters/tegra_cpu`
  - `/sys/module/fuse/parameters/tegra_platform`
  - `/sys/module/tegra_fuse/parameters/tegra_chip_id`
  - `/sys/module/tegra_fuse/parameters/tegra_chip_rev`
  - `/sys/module/tegra_fuse/parameters/tegra_cpu`
  - `/sys/module/tegra_fuse/parameters/tegra_platform`

## `nvidia-l4t-core/usr/lib/aarch64-linux-gnu/tegra/libnvrm_gpu.so`

- Package: `nvidia-l4t-core 32.7.6-20241104234540`
- Highest GLIBC symbol version seen by `readelf -V`: `2.17`
- NEEDED: `libnvrm.so`, `libnvos.so`, `libpthread.so.0`, `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - `/dev/l3cache`
  - `/dev/nvgpu-pci`
  - `/dev/nvhost`
  - `/sys/devices/soc0/soc_id`
  - `/sys/module/fuse/parameters/tegra_chip_id`
  - `/sys/module/tegra_fuse/parameters/tegra_chip_id`

## `nvidia-l4t-cuda/usr/lib/aarch64-linux-gnu/tegra/libcuda.so.1.1`

- Package: `nvidia-l4t-cuda 32.7.6-20241104234540`
- Highest GLIBC symbol version seen by `readelf -V`: `2.17`
- NEEDED: `libm.so.6`, `libc.so.6`, `ld-linux-aarch64.so.1`, `libdl.so.2`, `librt.so.1`, `libpthread.so.0`, `libnvrm_gpu.so`, `libnvrm.so`, `libnvrm_graphics.so`, `libnvidia-fatbinaryloader.so.440.18`
- Paths:

  - `/dev/null`
  - `/dev/nvgpu-pci/card-%s-dbg`
  - `/dev/nvhost-dbg-gpu`
  - `/dev/nvidia%d`
  - `/dev/nvidia-modeset`
  - `/dev/nvidia-nvlink`
  - `/dev/nvidia-nvswitch%d`
  - `/dev/nvidia-nvswitchctl`
  - `/dev/nvidia-uvm`
  - `/dev/nvidia-uvm-tools`
  - `/dev/nvidia-vgpu%d`
  - `/dev/nvidiactl`
  - `/dev/nvidiactl%d`
  - `/dev/urandom`
  - `/proc/%ld/exe`
  - `/proc/%lld/ns/%s`
  - `/proc/devices`
  - `/proc/driver/nvidia-nvlink/permissions`
  - `/proc/driver/nvidia-nvswitch/permissions`
  - `/proc/driver/nvidia/%d/params`
  - `/proc/driver/nvidia/params`
  - `/proc/modules`
  - `/proc/self/exe`
  - `/proc/self/maps`
  - `/proc/self/status`
  - `/proc/sys/kernel/modprobe`
  - `/proc/sys/vm/mmap_min_addr`
  - `/sys/bus/pci/devices`
  - `/sys/bus/pci/devices/%04x:%02x:%02x.%1u/rescan`
  - `/sys/bus/pci/rescan`
  - `/sys/devices/system/memory/block_size_bytes`
  - `/sys/devices/system/node`
  - `/sys/devices/system/node/%s/cpumap`
  - `/sys/devices/system/node/node%d/meminfo`
  - `/sys/kernel/debug/clock/emc/possible_rates`
  - `/sys/kernel/debug/clock/emc/rate`
  - `/sys/kernel/debug/clock/gbus/rate`

## `r35.6-l4t-core/usr/lib/aarch64-linux-gnu/tegra/libnvos.so`

- Package: `r35.6-l4t-core 35.6.5-20260701022834`
- Highest GLIBC symbol version seen by `readelf -V`: `2.17`
- NEEDED: `libpthread.so.0`, `libdl.so.2`, `librt.so.1`, `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - `/proc/self/cmdline`

## `r35.6-l4t-core/usr/lib/aarch64-linux-gnu/tegra/libnvrm_gpu.so`

- Package: `r35.6-l4t-core 35.6.5-20260701022834`
- Highest GLIBC symbol version seen by `readelf -V`: `2.17`
- NEEDED: `libnvrm_mem.so`, `libnvos.so`, `libnvsocsys.so`, `libnvrm_sync.so`, `libstdc++.so.6`, `libpthread.so.0`, `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - `/dev/l3cache`
  - `/dev/nvgpu`

## `r35.6-l4t-core/usr/lib/aarch64-linux-gnu/tegra/libnvrm_mem.so`

- Package: `r35.6-l4t-core 35.6.5-20260701022834`
- Highest GLIBC symbol version seen by `readelf -V`: `2.17`
- NEEDED: `libnvos.so`, `libnvsciipc.so`, `libnvsocsys.so`, `libpthread.so.0`, `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - `/dev/nvmap`

## `r35.6-l4t-cuda/usr/lib/aarch64-linux-gnu/tegra/libcuda.so.1.1`

- Package: `r35.6-l4t-cuda 35.6.5-20260701022834`
- Highest GLIBC symbol version seen by `readelf -V`: `2.17`
- NEEDED: `libc.so.6`, `libnvrm_gpu.so`, `libnvrm_mem.so`, `libm.so.6`, `libdl.so.2`, `librt.so.1`, `libpthread.so.0`, `libnvrm_sync.so`, `libnvrm_host1x.so`
- Paths:

  - `/dev/null`
  - `/dev/nvidia%d`
  - `/dev/nvidia-caps`
  - `/dev/nvidia-caps/nvidia-cap%d`
  - `/dev/nvidia-modeset`
  - `/dev/nvidia-nvlink`
  - `/dev/nvidia-nvswitch%d`
  - `/dev/nvidia-nvswitchctl`
  - `/dev/nvidia-uvm`
  - `/dev/nvidia-uvm-tools`
  - `/dev/nvidia-vgpu%d`
  - `/dev/nvidiactl`
  - `/dev/nvidiactl%d`
  - `/proc/%d/exe`
  - `/proc/%ld/exe`
  - `/proc/cpuinfo`
  - `/proc/devices`
  - `/proc/driver/nvidia-nvlink/capabilities/fabric-mgmt`
  - `/proc/driver/nvidia-nvlink/permissions`
  - `/proc/driver/nvidia-nvswitch/permissions`
  - `/proc/driver/nvidia/%d/params`
  - `/proc/driver/nvidia/capabilities/fabric-imex-mgmt`
  - `/proc/driver/nvidia/capabilities/gpu%u/mig/gi%u/access`
  - `/proc/driver/nvidia/capabilities/gpu%u/mig/gi%u/ci%u/access`
  - `/proc/driver/nvidia/capabilities/mig/config`
  - `/proc/driver/nvidia/capabilities/mig/monitor`
  - `/proc/driver/nvidia/params`
  - `/proc/modules`
  - `/proc/self/comm`
  - `/proc/self/exe`
  - `/proc/self/maps`
  - `/proc/self/status`
  - `/proc/sys/kernel/modprobe`
  - `/proc/sys/vm/mmap_min_addr`
  - `/sys/bus/pci/devices`
  - `/sys/bus/pci/devices/%04x:%02x:%02x.%1u/rescan`
  - `/sys/bus/pci/rescan`
  - `/sys/devices/soc0/family`
  - `/sys/devices/system/memory/block_size_bytes`
  - `/sys/devices/system/node`
  - `/sys/devices/system/node/%s/cpumap`
  - `/sys/devices/system/node/node%d/meminfo`
  - `/sys/kernel/debug/clock/emc/possible_rates`
  - `/sys/kernel/debug/clock/emc/rate`
  - `/sys/kernel/debug/clock/gbus/rate`

## `r36.4-l4t-core/usr/lib/aarch64-linux-gnu/nvidia/libnvos.so`

- Package: `r36.4-l4t-core 36.4.7-20250918154033`
- Highest GLIBC symbol version seen by `readelf -V`: `2.34`
- NEEDED: `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - `/proc/self/cmdline`

## `r36.4-l4t-core/usr/lib/aarch64-linux-gnu/nvidia/libnvrm_gpu.so`

- Package: `r36.4-l4t-core 36.4.7-20250918154033`
- Highest GLIBC symbol version seen by `readelf -V`: `2.34`
- NEEDED: `libnvrm_mem.so`, `libnvos.so`, `libnvsocsys.so`, `libnvtegrahv.so`, `libnvrm_sync.so`, `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - `/dev/l3cache`
  - `/dev/nvgpu`

## `r36.4-l4t-core/usr/lib/aarch64-linux-gnu/nvidia/libnvrm_mem.so`

- Package: `r36.4-l4t-core 36.4.7-20250918154033`
- Highest GLIBC symbol version seen by `readelf -V`: `2.17`
- NEEDED: `libnvos.so`, `libnvsciipc.so`, `libnvsocsys.so`, `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - `/dev/nvmap`

## `r36.4-l4t-cuda/usr/lib/aarch64-linux-gnu/nvidia/libcuda.so.1.1`

- Package: `r36.4-l4t-cuda 36.4.7-20250918154033`
- Highest GLIBC symbol version seen by `readelf -V`: `2.17`
- NEEDED: `libm.so.6`, `libc.so.6`, `ld-linux-aarch64.so.1`, `libdl.so.2`, `librt.so.1`, `libpthread.so.0`, `libnvrm_gpu.so`, `libnvrm_mem.so`
- Paths:

  - `/dev/`
  - `/dev/char/%d:%d`
  - `/dev/null`
  - `/dev/nvidia%d`
  - `/dev/nvidia-caps`
  - `/dev/nvidia-caps-imex-channels`
  - `/dev/nvidia-caps-imex-channels/channel%d`
  - `/dev/nvidia-caps/nvidia-cap%d`
  - `/dev/nvidia-modeset`
  - `/dev/nvidia-nvlink`
  - `/dev/nvidia-nvswitch%d`
  - `/dev/nvidia-nvswitchctl`
  - `/dev/nvidia-uvm`
  - `/dev/nvidia-uvm-tools`
  - `/dev/nvidia-vgpu%d`
  - `/dev/nvidia-vgpuctl`
  - `/dev/nvidiactl`
  - `/proc/%d/exe`
  - `/proc/%d/fd/%d`
  - `/proc/%d/task`
  - `/proc/%d/task/%s/comm`
  - `/proc/%ld/exe`
  - `/proc/cpuinfo`
  - `/proc/devices`
  - `/proc/driver/nvidia-nvlink/capabilities/fabric-mgmt`
  - `/proc/driver/nvidia-nvlink/permissions`
  - `/proc/driver/nvidia-nvswitch/permissions`
  - `/proc/driver/nvidia/capabilities/fabric-imex-mgmt`
  - `/proc/driver/nvidia/capabilities/gpu%u/mig/gi%u/access`
  - `/proc/driver/nvidia/capabilities/gpu%u/mig/gi%u/ci%u/access`
  - `/proc/driver/nvidia/capabilities/mig/config`
  - `/proc/driver/nvidia/capabilities/mig/monitor`
  - `/proc/driver/nvidia/gpus/%04x:%02x:%02x.%1u/numa_status`
  - `/proc/driver/nvidia/params`
  - `/proc/modules`
  - `/proc/self/cmdline`
  - `/proc/self/comm`
  - `/proc/self/exe`
  - `/proc/self/maps`
  - `/proc/self/status`
  - `/proc/self/task/%d/comm`
  - `/proc/sys/kernel/modprobe`
  - `/proc/sys/vm/mmap_min_addr`
  - `/sys/bus/pci/devices`
  - `/sys/bus/pci/devices/%04x:%02x:%02x.%1u/rescan`
  - `/sys/bus/pci/rescan`
  - `/sys/devices/soc0/family`
  - `/sys/devices/system/memory/auto_online_blocks`
  - `/sys/devices/system/memory/block_size_bytes`
  - `/sys/devices/system/node`
  - `/sys/devices/system/node/%s/cpumap`
  - `/sys/devices/system/node/node%d/meminfo`
  - `/sys/devices/system/node/node%ld/meminfo`
  - `/sys/kernel/debug/clock/emc/possible_rates`
  - `/sys/kernel/debug/clock/emc/rate`
  - `/sys/kernel/debug/clock/gbus/rate`
  - `/sys/module/%s/initstate`

## `nvidia-l4t-core/usr/lib/aarch64-linux-gnu/tegra/libdrm.so.2`

- Package: `nvidia-l4t-core 32.7.6-20241104234540`
- Highest GLIBC symbol version seen by `readelf -V`: `2.17`
- NEEDED: `libnvrm.so`, `libnvll.so`, `libnvos.so`, `libpthread.so.0`, `libdl.so.2`, `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - none found

## `nvidia-l4t-core/usr/lib/aarch64-linux-gnu/tegra/libnvcolorutil.so`

- Package: `nvidia-l4t-core 32.7.6-20241104234540`
- Highest GLIBC symbol version seen by `readelf -V`: `2.17`
- NEEDED: `libnvos.so`, `libm.so.6`, `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - none found

## `nvidia-l4t-core/usr/lib/aarch64-linux-gnu/tegra/libnvdc.so`

- Package: `nvidia-l4t-core 32.7.6-20241104234540`
- Highest GLIBC symbol version seen by `readelf -V`: `2.17`
- NEEDED: `libnvimp.so`, `libnvrm.so`, `libpthread.so.0`, `libm.so.6`, `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - `/dev/fb%d`
  - `/dev/tegra_dc_%d`
  - `/dev/tegra_dc_ctrl`
  - `/sys/class/graphics/fb%d/device/crc_checksum_latched`

## `nvidia-l4t-core/usr/lib/aarch64-linux-gnu/tegra/libnvddk_2d_v2.so`

- Package: `nvidia-l4t-core 32.7.6-20241104234540`
- Highest GLIBC symbol version seen by `readelf -V`: `2.17`
- NEEDED: `libnvrm_graphics.so`, `libnvrm.so`, `libnvos.so`, `libnvddk_vic.so`, `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - none found

## `nvidia-l4t-core/usr/lib/aarch64-linux-gnu/tegra/libnvddk_vic.so`

- Package: `nvidia-l4t-core 32.7.6-20241104234540`
- Highest GLIBC symbol version seen by `readelf -V`: `2.17`
- NEEDED: `libnvrm.so`, `libnvrm_graphics.so`, `libnvos.so`, `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - none found

## `nvidia-l4t-core/usr/lib/aarch64-linux-gnu/tegra/libnvdla_compiler.so`

- Package: `nvidia-l4t-core 32.7.6-20241104234540`
- Highest GLIBC symbol version seen by `readelf -V`: `2.17`
- NEEDED: `libnvos.so`, `libstdc++.so.6`, `libm.so.6`, `libc.so.6`, `ld-linux-aarch64.so.1`, `libgcc_s.so.1`
- Paths:

  - none found

## `nvidia-l4t-core/usr/lib/aarch64-linux-gnu/tegra/libnvdla_runtime.so`

- Package: `nvidia-l4t-core 32.7.6-20241104234540`
- Highest GLIBC symbol version seen by `readelf -V`: `2.17`
- NEEDED: `libnvrm.so`, `libnvrm_graphics.so`, `libnvos.so`, `libstdc++.so.6`, `libpthread.so.0`, `libm.so.6`, `libc.so.6`, `ld-linux-aarch64.so.1`, `libgcc_s.so.1`
- Paths:

  - `/dev/nvhost-ctrl-nvdla0`
  - `/dev/nvhost-ctrl-nvdla1`

## `nvidia-l4t-core/usr/lib/aarch64-linux-gnu/tegra/libnvfnet.so`

- Package: `nvidia-l4t-core 32.7.6-20241104234540`
- Highest GLIBC symbol version seen by `readelf -V`: `2.17`
- NEEDED: `libEGL.so.1`, `libnvrm.so`, `libnvrm_graphics.so`, `libexpat.so.1`, `libstdc++.so.6`, `libm.so.6`, `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - none found

## `nvidia-l4t-core/usr/lib/aarch64-linux-gnu/tegra/libnvfnetstoredefog.so`

- Package: `nvidia-l4t-core 32.7.6-20241104234540`
- Highest GLIBC symbol version seen by `readelf -V`: `2.17`
- NEEDED: `libnvfnet.so`, `libstdc++.so.6`, `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - none found

## `nvidia-l4t-core/usr/lib/aarch64-linux-gnu/tegra/libnvfnetstorehdfx.so`

- Package: `nvidia-l4t-core 32.7.6-20241104234540`
- Highest GLIBC symbol version seen by `readelf -V`: `2.17`
- NEEDED: `libnvfnet.so`, `libstdc++.so.6`, `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - none found

## `nvidia-l4t-core/usr/lib/aarch64-linux-gnu/tegra/libnvgbm.so`

- Package: `nvidia-l4t-core 32.7.6-20241104234540`
- Highest GLIBC symbol version seen by `readelf -V`: `2.17`
- NEEDED: `libdrm.so.2`, `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - none found

## `nvidia-l4t-core/usr/lib/aarch64-linux-gnu/tegra/libnvgov_boot.so`

- Package: `nvidia-l4t-core 32.7.6-20241104234540`
- Highest GLIBC symbol version seen by `readelf -V`: `2.17`
- NEEDED: `libnvphsd.so`, `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - none found

## `nvidia-l4t-core/usr/lib/aarch64-linux-gnu/tegra/libnvgov_camera.so`

- Package: `nvidia-l4t-core 32.7.6-20241104234540`
- Highest GLIBC symbol version seen by `readelf -V`: `2.17`
- NEEDED: `libnvphsd.so`, `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - none found

## `nvidia-l4t-core/usr/lib/aarch64-linux-gnu/tegra/libnvgov_force.so`

- Package: `nvidia-l4t-core 32.7.6-20241104234540`
- Highest GLIBC symbol version seen by `readelf -V`: `2.17`
- NEEDED: `libnvphsd.so`, `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - none found

## `nvidia-l4t-core/usr/lib/aarch64-linux-gnu/tegra/libnvgov_generic.so`

- Package: `nvidia-l4t-core 32.7.6-20241104234540`
- Highest GLIBC symbol version seen by `readelf -V`: `2.17`
- NEEDED: `libnvphsd.so`, `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - none found

## `nvidia-l4t-core/usr/lib/aarch64-linux-gnu/tegra/libnvgov_gpucompute.so`

- Package: `nvidia-l4t-core 32.7.6-20241104234540`
- Highest GLIBC symbol version seen by `readelf -V`: `2.17`
- NEEDED: `libnvphsd.so`, `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - none found

## `nvidia-l4t-core/usr/lib/aarch64-linux-gnu/tegra/libnvgov_graphics.so`

- Package: `nvidia-l4t-core 32.7.6-20241104234540`
- Highest GLIBC symbol version seen by `readelf -V`: `2.17`
- NEEDED: `libnvphsd.so`, `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - none found

## `nvidia-l4t-core/usr/lib/aarch64-linux-gnu/tegra/libnvgov_il.so`

- Package: `nvidia-l4t-core 32.7.6-20241104234540`
- Highest GLIBC symbol version seen by `readelf -V`: `2.17`
- NEEDED: `libnvphsd.so`, `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - none found

## `nvidia-l4t-core/usr/lib/aarch64-linux-gnu/tegra/libnvgov_spincircle.so`

- Package: `nvidia-l4t-core 32.7.6-20241104234540`
- Highest GLIBC symbol version seen by `readelf -V`: `2.17`
- NEEDED: `libnvphsd.so`, `libc.so.6`
- Paths:

  - none found

## `nvidia-l4t-core/usr/lib/aarch64-linux-gnu/tegra/libnvgov_tbc.so`

- Package: `nvidia-l4t-core 32.7.6-20241104234540`
- Highest GLIBC symbol version seen by `readelf -V`: `2.17`
- NEEDED: `libnvphsd.so`, `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - none found

## `nvidia-l4t-core/usr/lib/aarch64-linux-gnu/tegra/libnvgov_ui.so`

- Package: `nvidia-l4t-core 32.7.6-20241104234540`
- Highest GLIBC symbol version seen by `readelf -V`: `2.17`
- NEEDED: `libnvphsd.so`, `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - none found

## `nvidia-l4t-core/usr/lib/aarch64-linux-gnu/tegra/libnvidia-tls.so.32.7.6`

- Package: `nvidia-l4t-core 32.7.6-20241104234540`
- Highest GLIBC symbol version seen by `readelf -V`: `2.17`
- NEEDED: `libc.so.6`
- Paths:

  - none found

## `nvidia-l4t-core/usr/lib/aarch64-linux-gnu/tegra/libnvimp.so`

- Package: `nvidia-l4t-core 32.7.6-20241104234540`
- Highest GLIBC symbol version seen by `readelf -V`: `2.17`
- NEEDED: `libnvrm.so`, `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - none found

## `nvidia-l4t-core/usr/lib/aarch64-linux-gnu/tegra/libnvll.so`

- Package: `nvidia-l4t-core 32.7.6-20241104234540`
- Highest GLIBC symbol version seen by `readelf -V`: `2.17`
- NEEDED: `libnvrm.so`, `libnvrm_graphics.so`, `libnvdc.so`, `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - none found

## `nvidia-l4t-core/usr/lib/aarch64-linux-gnu/tegra/libnvphs.so`

- Package: `nvidia-l4t-core 32.7.6-20241104234540`
- Highest GLIBC symbol version seen by `readelf -V`: `2.17`
- NEEDED: `libnvos.so`, `libpthread.so.0`, `librt.so.1`, `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - `/proc/self/cmdline`

## `nvidia-l4t-core/usr/lib/aarch64-linux-gnu/tegra/libnvphsd.so`

- Package: `nvidia-l4t-core 32.7.6-20241104234540`
- Highest GLIBC symbol version seen by `readelf -V`: `2.17`
- NEEDED: `libnvos.so`, `libpthread.so.0`, `libdl.so.2`, `librt.so.1`, `libm.so.6`, `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - `/dev/stune/cgroup.procs`
  - `/dev/stune/nvphsd/cgroup.procs`
  - `/dev/stune/nvphsd/schedtune.boost`
  - `/proc/%d/comm`
  - `/proc/%d/largest_task`
  - `/proc/%d/task`

## `nvidia-l4t-core/usr/lib/aarch64-linux-gnu/tegra/libnvrm_graphics.so`

- Package: `nvidia-l4t-core 32.7.6-20241104234540`
- Highest GLIBC symbol version seen by `readelf -V`: `2.17`
- NEEDED: `libnvrm.so`, `libnvos.so`, `libpthread.so.0`, `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - `/dev/dri`
  - `/dev/dri/%.22s`
  - `/dev/nvhost-ctrl`
  - `/dev/nvhost-display`
  - `/dev/nvhost-dsi`
  - `/dev/nvhost-gpu`
  - `/dev/nvhost-isp`
  - `/dev/nvhost-isp.1`
  - `/dev/nvhost-msenc`
  - `/dev/nvhost-nvdec`
  - `/dev/nvhost-nvdec1`
  - `/dev/nvhost-nvenc1`
  - `/dev/nvhost-nvjpg`
  - `/dev/nvhost-tsec`
  - `/dev/nvhost-tsecb`
  - `/dev/nvhost-vi`
  - `/dev/nvhost-vi.1`
  - `/dev/nvhost-vic`
  - `/sys/devices/platform/host1x/capabilities/alloc_chs_per_submits`
  - `/sys/devices/platform/host1x/capabilities/gather_filter_enabled`
  - `/sys/devices/platform/host1x/capabilities/num_mlocks`
  - `/sys/devices/platform/host1x/capabilities/num_pts`

## `nvidia-l4t-core/usr/lib/aarch64-linux-gnu/tegra/libsensors.hal-client.nvs.so`

- Package: `nvidia-l4t-core 32.7.6-20241104234540`
- Highest GLIBC symbol version seen by `readelf -V`: `2.17`
- NEEDED: `libnvos.so`, `libpthread.so.0`, `libstdc++.so.6`, `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - none found

## `nvidia-l4t-core/usr/lib/aarch64-linux-gnu/tegra/libsensors.l4t.no_fusion.nvs.so`

- Package: `nvidia-l4t-core 32.7.6-20241104234540`
- Highest GLIBC symbol version seen by `readelf -V`: `none found`
- NEEDED: `libsensors_hal.nvs.so`, `libstdc++.so.6`
- Paths:

  - none found

## `nvidia-l4t-core/usr/lib/aarch64-linux-gnu/tegra/libsensors_hal.nvs.so`

- Package: `nvidia-l4t-core 32.7.6-20241104234540`
- Highest GLIBC symbol version seen by `readelf -V`: `2.17`
- NEEDED: `libnvos.so`, `libpthread.so.0`, `libstdc++.so.6`, `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - `/dev/iio:device%d`
  - `/dev/input/event%u`
  - `/dev/nvs:device%d`
  - `/sys/bus/iio/devices`
  - `/sys/bus/iio/devices/iio:device%d`
  - `/sys/bus/nvs/devices`
  - `/sys/bus/nvs/devices/nvs:device%d`
  - `/sys/class/input`
  - `/sys/class/input/input%d`
  - `/sys/class/input/input%d/attr`

## `r35.6-l4t-core/usr/lib/aarch64-linux-gnu/tegra/libdrm.so.2`

- Package: `r35.6-l4t-core 35.6.5-20260701022834`
- Highest GLIBC symbol version seen by `readelf -V`: `2.17`
- NEEDED: `libnvll.so`, `libpthread.so.0`, `libdl.so.2`, `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - none found

## `r35.6-l4t-core/usr/lib/aarch64-linux-gnu/tegra/libjetsonpower.so`

- Package: `r35.6-l4t-core 35.6.5-20260701022834`
- Highest GLIBC symbol version seen by `readelf -V`: `2.17`
- NEEDED: `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - `/dev/%s %dMB %dMB *`
  - `/proc/device-tree/compatible`
  - `/proc/device-tree/model`
  - `/proc/meminfo`
  - `/proc/stat`
  - `/sys/bus/i2c/drivers`
  - `/sys/class/thermal`
  - `/sys/devices/system/cpu/cpu%d/cpufreq/scaling_cur_freq`
  - `/sys/devices/system/cpu/cpu%d/cpufreq/scaling_max_freq`
  - `/sys/devices/system/cpu/cpu%d/cpufreq/scaling_min_freq`
  - `/sys/devices/system/cpu/cpu%d/online`
  - `/sys/devices/system/cpu/present`

## `r35.6-l4t-core/usr/lib/aarch64-linux-gnu/tegra/libnvcolorutil.so`

- Package: `r35.6-l4t-core 35.6.5-20260701022834`
- Highest GLIBC symbol version seen by `readelf -V`: `2.29`
- NEEDED: `libnvos.so`, `libm.so.6`, `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - none found

## `r35.6-l4t-core/usr/lib/aarch64-linux-gnu/tegra/libnvdc.so`

- Package: `r35.6-l4t-core 35.6.5-20260701022834`
- Highest GLIBC symbol version seen by `readelf -V`: `2.17`
- NEEDED: `libnvimp.so`, `libnvrm_chip.so`, `libnvrm_mem.so`, `libnvrm_surface.so`, `libnvrm_sync.so`, `libpthread.so.0`, `libm.so.6`, `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - `/dev/fb%d`
  - `/dev/tegra_dc_%d`
  - `/dev/tegra_dc_ctrl`
  - `/sys/class/graphics/fb%d/device/crc_checksum_latched`

## `r35.6-l4t-core/usr/lib/aarch64-linux-gnu/tegra/libnvddk_2d_v2.so`

- Package: `r35.6-l4t-core 35.6.5-20260701022834`
- Highest GLIBC symbol version seen by `readelf -V`: `2.17`
- NEEDED: `libnvrm_host1x.so`, `libnvrm_mem.so`, `libnvrm_stream.so`, `libnvrm_surface.so`, `libnvos.so`, `libnvddk_vic.so`, `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - none found

## `r35.6-l4t-core/usr/lib/aarch64-linux-gnu/tegra/libnvddk_vic.so`

- Package: `r35.6-l4t-core 35.6.5-20260701022834`
- Highest GLIBC symbol version seen by `readelf -V`: `2.17`
- NEEDED: `libnvrm_chip.so`, `libnvrm_host1x.so`, `libnvrm_mem.so`, `libnvrm_stream.so`, `libnvrm_sync.so`, `libnvos.so`, `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - none found

## `r35.6-l4t-core/usr/lib/aarch64-linux-gnu/tegra/libnvdla_compiler.so`

- Package: `r35.6-l4t-core 35.6.5-20260701022834`
- Highest GLIBC symbol version seen by `readelf -V`: `2.29`
- NEEDED: `libnvos.so`, `libstdc++.so.6`, `libm.so.6`, `libc.so.6`, `ld-linux-aarch64.so.1`, `libgcc_s.so.1`
- Paths:

  - none found

## `r35.6-l4t-core/usr/lib/aarch64-linux-gnu/tegra/libnvdla_runtime.so`

- Package: `r35.6-l4t-core 35.6.5-20260701022834`
- Highest GLIBC symbol version seen by `readelf -V`: `2.27`
- NEEDED: `libnvrm_host1x.so`, `libnvrm_mem.so`, `libnvsocsys.so`, `libnvos.so`, `libstdc++.so.6`, `libpthread.so.0`, `libm.so.6`, `libc.so.6`, `ld-linux-aarch64.so.1`, `libgcc_s.so.1`
- Paths:

  - `/dev/nvhost-ctrl-nvdla0`
  - `/dev/nvhost-ctrl-nvdla1`

## `r35.6-l4t-core/usr/lib/aarch64-linux-gnu/tegra/libnvfnet.so`

- Package: `r35.6-l4t-core 35.6.5-20260701022834`
- Highest GLIBC symbol version seen by `readelf -V`: `2.29`
- NEEDED: `libEGL.so.1`, `libnvrm_sync.so`, `libnvrm_host1x.so`, `libexpat.so.1`, `libstdc++.so.6`, `libm.so.6`, `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - none found

## `r35.6-l4t-core/usr/lib/aarch64-linux-gnu/tegra/libnvfnetstoredefog.so`

- Package: `r35.6-l4t-core 35.6.5-20260701022834`
- Highest GLIBC symbol version seen by `readelf -V`: `2.17`
- NEEDED: `libnvfnet.so`, `libstdc++.so.6`, `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - none found

## `r35.6-l4t-core/usr/lib/aarch64-linux-gnu/tegra/libnvfnetstorehdfx.so`

- Package: `r35.6-l4t-core 35.6.5-20260701022834`
- Highest GLIBC symbol version seen by `readelf -V`: `2.17`
- NEEDED: `libnvfnet.so`, `libstdc++.so.6`, `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - none found

## `r35.6-l4t-core/usr/lib/aarch64-linux-gnu/tegra/libnvgov_boot.so`

- Package: `r35.6-l4t-core 35.6.5-20260701022834`
- Highest GLIBC symbol version seen by `readelf -V`: `2.17`
- NEEDED: `libnvphsd.so`, `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - none found

## `r35.6-l4t-core/usr/lib/aarch64-linux-gnu/tegra/libnvgov_camera.so`

- Package: `r35.6-l4t-core 35.6.5-20260701022834`
- Highest GLIBC symbol version seen by `readelf -V`: `2.17`
- NEEDED: `libnvphsd.so`, `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - none found

## `r35.6-l4t-core/usr/lib/aarch64-linux-gnu/tegra/libnvgov_force.so`

- Package: `r35.6-l4t-core 35.6.5-20260701022834`
- Highest GLIBC symbol version seen by `readelf -V`: `2.17`
- NEEDED: `libnvphsd.so`, `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - none found

## `r35.6-l4t-core/usr/lib/aarch64-linux-gnu/tegra/libnvgov_generic.so`

- Package: `r35.6-l4t-core 35.6.5-20260701022834`
- Highest GLIBC symbol version seen by `readelf -V`: `2.17`
- NEEDED: `libnvphsd.so`, `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - none found

## `r35.6-l4t-core/usr/lib/aarch64-linux-gnu/tegra/libnvgov_gpucompute.so`

- Package: `r35.6-l4t-core 35.6.5-20260701022834`
- Highest GLIBC symbol version seen by `readelf -V`: `2.17`
- NEEDED: `libnvphsd.so`, `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - none found

## `r35.6-l4t-core/usr/lib/aarch64-linux-gnu/tegra/libnvgov_graphics.so`

- Package: `r35.6-l4t-core 35.6.5-20260701022834`
- Highest GLIBC symbol version seen by `readelf -V`: `2.17`
- NEEDED: `libnvphsd.so`, `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - none found

## `r35.6-l4t-core/usr/lib/aarch64-linux-gnu/tegra/libnvgov_il.so`

- Package: `r35.6-l4t-core 35.6.5-20260701022834`
- Highest GLIBC symbol version seen by `readelf -V`: `2.17`
- NEEDED: `libnvphsd.so`, `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - none found

## `r35.6-l4t-core/usr/lib/aarch64-linux-gnu/tegra/libnvgov_spincircle.so`

- Package: `r35.6-l4t-core 35.6.5-20260701022834`
- Highest GLIBC symbol version seen by `readelf -V`: `2.17`
- NEEDED: `libnvphsd.so`, `libc.so.6`
- Paths:

  - none found

## `r35.6-l4t-core/usr/lib/aarch64-linux-gnu/tegra/libnvgov_tbc.so`

- Package: `r35.6-l4t-core 35.6.5-20260701022834`
- Highest GLIBC symbol version seen by `readelf -V`: `2.17`
- NEEDED: `libnvphsd.so`, `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - none found

## `r35.6-l4t-core/usr/lib/aarch64-linux-gnu/tegra/libnvgov_ui.so`

- Package: `r35.6-l4t-core 35.6.5-20260701022834`
- Highest GLIBC symbol version seen by `readelf -V`: `2.17`
- NEEDED: `libnvphsd.so`, `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - none found

## `r35.6-l4t-core/usr/lib/aarch64-linux-gnu/tegra/libnvidia-tls.so.35.6.5`

- Package: `r35.6-l4t-core 35.6.5-20260701022834`
- Highest GLIBC symbol version seen by `readelf -V`: `2.17`
- NEEDED: `libc.so.6`
- Paths:

  - none found

## `r35.6-l4t-core/usr/lib/aarch64-linux-gnu/tegra/libnvimp.so`

- Package: `r35.6-l4t-core 35.6.5-20260701022834`
- Highest GLIBC symbol version seen by `readelf -V`: `2.17`
- NEEDED: `libnvrm_chip.so`, `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - none found

## `r35.6-l4t-core/usr/lib/aarch64-linux-gnu/tegra/libnvisp_utils.so`

- Package: `r35.6-l4t-core 35.6.5-20260701022834`
- Highest GLIBC symbol version seen by `readelf -V`: `2.17`
- NEEDED: `libnvos.so`, `libstdc++.so.6`, `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - none found

## `r35.6-l4t-core/usr/lib/aarch64-linux-gnu/tegra/libnvll.so`

- Package: `r35.6-l4t-core 35.6.5-20260701022834`
- Highest GLIBC symbol version seen by `readelf -V`: `2.17`
- NEEDED: `libnvrm_chip.so`, `libnvrm_mem.so`, `libnvrm_host1x.so`, `libnvrm_surface.so`, `libnvdc.so`, `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - none found

## `r35.6-l4t-core/usr/lib/aarch64-linux-gnu/tegra/libnvphs.so`

- Package: `r35.6-l4t-core 35.6.5-20260701022834`
- Highest GLIBC symbol version seen by `readelf -V`: `2.17`
- NEEDED: `libnvos.so`, `libpthread.so.0`, `librt.so.1`, `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - `/proc/self/cmdline`

## `r35.6-l4t-core/usr/lib/aarch64-linux-gnu/tegra/libnvphsd.so`

- Package: `r35.6-l4t-core 35.6.5-20260701022834`
- Highest GLIBC symbol version seen by `readelf -V`: `2.29`
- NEEDED: `libnvos.so`, `libpthread.so.0`, `libdl.so.2`, `librt.so.1`, `libm.so.6`, `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - `/dev/stune/cgroup.procs`
  - `/dev/stune/nvphsd/cgroup.procs`
  - `/dev/stune/nvphsd/schedtune.boost`
  - `/proc/%d/comm`
  - `/proc/%d/largest_task`
  - `/proc/%d/task`

## `r35.6-l4t-core/usr/lib/aarch64-linux-gnu/tegra/libnvpva.so`

- Package: `r35.6-l4t-core 35.6.5-20260701022834`
- Highest GLIBC symbol version seen by `readelf -V`: `2.17`
- NEEDED: `libnvos.so`, `libnvrm_mem.so`, `libnvrm_surface.so`, `libdl.so.2`, `libpthread.so.0`, `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - `/dev/nvhost-ctrl-pva`

## `r35.6-l4t-core/usr/lib/aarch64-linux-gnu/tegra/libnvpva_algorithms.so`

- Package: `r35.6-l4t-core 35.6.5-20260701022834`
- Highest GLIBC symbol version seen by `readelf -V`: `2.27`
- NEEDED: `libnvos.so`, `libnvrm_mem.so`, `libnvrm_surface.so`, `libnvpva.so`, `libnvsocsys.so`, `libm.so.6`, `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - none found

## `r35.6-l4t-core/usr/lib/aarch64-linux-gnu/tegra/libnvpvaumd.so`

- Package: `r35.6-l4t-core 35.6.5-20260701022834`
- Highest GLIBC symbol version seen by `readelf -V`: `2.17`
- NEEDED: `libnvrm_mem.so`, `libnvsocsys.so`, `libnvos.so`, `libpthread.so.0`, `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - `/dev/nvhost-ctrl-pva0`
  - `/dev/nvhost-ctrl-pva1`

## `r35.6-l4t-core/usr/lib/aarch64-linux-gnu/tegra/libnvrm_chip.so`

- Package: `r35.6-l4t-core 35.6.5-20260701022834`
- Highest GLIBC symbol version seen by `readelf -V`: `2.17`
- NEEDED: `libnvos.so`, `libpthread.so.0`, `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - `/sys/devices/soc0/major`
  - `/sys/devices/soc0/minor`
  - `/sys/devices/soc0/platform`
  - `/sys/devices/soc0/revision`
  - `/sys/devices/soc0/soc_id`
  - `/sys/module/fuse/parameters/tegra_chip_id`
  - `/sys/module/fuse/parameters/tegra_chip_rev`
  - `/sys/module/fuse/parameters/tegra_cpu`
  - `/sys/module/fuse/parameters/tegra_platform`
  - `/sys/module/tegra_fuse/parameters/tegra_chip_id`
  - `/sys/module/tegra_fuse/parameters/tegra_chip_rev`
  - `/sys/module/tegra_fuse/parameters/tegra_cpu`
  - `/sys/module/tegra_fuse/parameters/tegra_platform`

## `r35.6-l4t-core/usr/lib/aarch64-linux-gnu/tegra/libnvrm_host1x.so`

- Package: `r35.6-l4t-core 35.6.5-20260701022834`
- Highest GLIBC symbol version seen by `readelf -V`: `2.25`
- NEEDED: `libnvrm_chip.so`, `libnvrm_mem.so`, `libnvos.so`, `libpthread.so.0`, `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - `/dev/dri`
  - `/dev/dri/%s`
  - `/dev/dri/by-path/platform-13e00000.host1x-card`
  - `/dev/host1x-fence`
  - `/dev/nvhost-ctrl`
  - `/dev/nvhost-display`
  - `/dev/nvhost-dsi`
  - `/dev/nvhost-gpu`
  - `/dev/nvhost-isp`
  - `/dev/nvhost-isp.1`
  - `/dev/nvhost-msenc`
  - `/dev/nvhost-nvdec`
  - `/dev/nvhost-nvdec1`
  - `/dev/nvhost-nvenc1`
  - `/dev/nvhost-nvjpg`
  - `/dev/nvhost-nvjpg1`
  - `/dev/nvhost-ofa`
  - `/dev/nvhost-tsec`
  - `/dev/nvhost-tsecb`
  - `/dev/nvhost-vi`
  - `/dev/nvhost-vi.1`
  - `/dev/nvhost-vic`

## `r35.6-l4t-core/usr/lib/aarch64-linux-gnu/tegra/libnvrm_stream.so`

- Package: `r35.6-l4t-core 35.6.5-20260701022834`
- Highest GLIBC symbol version seen by `readelf -V`: `2.17`
- NEEDED: `libnvrm_mem.so`, `libnvrm_host1x.so`, `libnvos.so`, `libnvrm_sync.so`, `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - none found

## `r35.6-l4t-core/usr/lib/aarch64-linux-gnu/tegra/libnvrm_surface.so`

- Package: `r35.6-l4t-core 35.6.5-20260701022834`
- Highest GLIBC symbol version seen by `readelf -V`: `2.17`
- NEEDED: `libnvrm_mem.so`, `libnvos.so`, `libnvrm_chip.so`, `libnvrm_sync.so`, `libpthread.so.0`, `libdl.so.2`, `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - `/dev/nvgpu/igpu0/ctrl`

## `r35.6-l4t-core/usr/lib/aarch64-linux-gnu/tegra/libnvrm_sync.so`

- Package: `r35.6-l4t-core 35.6.5-20260701022834`
- Highest GLIBC symbol version seen by `readelf -V`: `2.17`
- NEEDED: `libnvos.so`, `libnvrm_chip.so`, `libnvrm_host1x.so`, `libpthread.so.0`, `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - none found

## `r35.6-l4t-core/usr/lib/aarch64-linux-gnu/tegra/libnvsciipc.so`

- Package: `r35.6-l4t-core 35.6.5-20260701022834`
- Highest GLIBC symbol version seen by `readelf -V`: `2.17`
- NEEDED: `libpthread.so.0`, `librt.so.1`, `libdl.so.2`, `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - `/dev/ivc`
  - `/dev/nvsciipc`
  - `/proc/%d`
  - `/proc/%d/task/%d`
  - `/proc/device-tree/soc_id`

## `r35.6-l4t-core/usr/lib/aarch64-linux-gnu/tegra/libnvsocsys.so`

- Package: `r35.6-l4t-core 35.6.5-20260701022834`
- Highest GLIBC symbol version seen by `readelf -V`: `2.17`
- NEEDED: `libnvos.so`, `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - `/sys/bus/nvmem/devices/fuse/nvmem`
  - `/sys/devices/soc0/major`
  - `/sys/devices/soc0/minor`
  - `/sys/devices/soc0/platform`
  - `/sys/devices/soc0/production`
  - `/sys/devices/soc0/revision`
  - `/sys/devices/soc0/soc_id`
  - `/sys/module/fuse/parameters/tegra_chip_id`
  - `/sys/module/fuse/parameters/tegra_chip_rev`
  - `/sys/module/fuse/parameters/tegra_cpu`
  - `/sys/module/fuse/parameters/tegra_platform`
  - `/sys/module/fuse/parameters/tegra_prod_mode`
  - `/sys/module/tegra_fuse/parameters/tegra_chip_id`
  - `/sys/module/tegra_fuse/parameters/tegra_chip_rev`
  - `/sys/module/tegra_fuse/parameters/tegra_cpu`
  - `/sys/module/tegra_fuse/parameters/tegra_platform`
  - `/sys/module/tegra_fuse/parameters/tegra_prod_mode`

## `r35.6-l4t-core/usr/lib/aarch64-linux-gnu/tegra/libnvvic.so`

- Package: `r35.6-l4t-core 35.6.5-20260701022834`
- Highest GLIBC symbol version seen by `readelf -V`: `2.17`
- NEEDED: `libnvrm_mem.so`, `libnvrm_host1x.so`, `libnvrm_stream.so`, `libnvsocsys.so`, `libnvos.so`, `libnvcolorutil.so`, `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - none found

## `r35.6-l4t-core/usr/lib/aarch64-linux-gnu/tegra/libsensors.hal-client.nvs.so`

- Package: `r35.6-l4t-core 35.6.5-20260701022834`
- Highest GLIBC symbol version seen by `readelf -V`: `2.17`
- NEEDED: `libnvos.so`, `libpthread.so.0`, `libstdc++.so.6`, `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - none found

## `r35.6-l4t-core/usr/lib/aarch64-linux-gnu/tegra/libsensors.l4t.no_fusion.nvs.so`

- Package: `r35.6-l4t-core 35.6.5-20260701022834`
- Highest GLIBC symbol version seen by `readelf -V`: `none found`
- NEEDED: `libsensors_hal.nvs.so`, `libstdc++.so.6`
- Paths:

  - none found

## `r35.6-l4t-core/usr/lib/aarch64-linux-gnu/tegra/libsensors_hal.nvs.so`

- Package: `r35.6-l4t-core 35.6.5-20260701022834`
- Highest GLIBC symbol version seen by `readelf -V`: `2.17`
- NEEDED: `libnvos.so`, `libpthread.so.0`, `libstdc++.so.6`, `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - `/dev/iio:device%d`
  - `/dev/input/event%u`
  - `/dev/nvs:device%d`
  - `/sys/bus/iio/devices`
  - `/sys/bus/iio/devices/iio:device%d`
  - `/sys/bus/nvs/devices`
  - `/sys/bus/nvs/devices/nvs:device%d`
  - `/sys/class/input`
  - `/sys/class/input/input%d`
  - `/sys/class/input/input%d/attr`

## `r35.6-l4t-cuda/usr/lib/aarch64-linux-gnu/tegra/libnvcucompat.so`

- Package: `r35.6-l4t-cuda 35.6.5-20260701022834`
- Highest GLIBC symbol version seen by `readelf -V`: `2.17`
- NEEDED: `libc.so.6`, `libdl.so.2`, `libnvrm_gpu.so`, `libnvrm_sync.so`, `libnvrm_mem.so`, `libnvrm_host1x.so`
- Paths:

  - none found

## `r36.4-l4t-core/usr/lib/aarch64-linux-gnu/nvidia/libjetsonpower.so`

- Package: `r36.4-l4t-core 36.4.7-20250918154033`
- Highest GLIBC symbol version seen by `readelf -V`: `2.17`
- NEEDED: `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - `/dev/%s %dMB %dMB *`
  - `/proc/device-tree/compatible`
  - `/proc/device-tree/model`
  - `/proc/meminfo`
  - `/proc/stat`
  - `/sys/bus/i2c/drivers`
  - `/sys/class/hwmon`
  - `/sys/class/thermal`
  - `/sys/devices/system/cpu/cpu%d/cpufreq/scaling_cur_freq`
  - `/sys/devices/system/cpu/cpu%d/cpufreq/scaling_max_freq`
  - `/sys/devices/system/cpu/cpu%d/cpufreq/scaling_min_freq`
  - `/sys/devices/system/cpu/cpu%d/online`
  - `/sys/devices/system/cpu/present`

## `r36.4-l4t-core/usr/lib/aarch64-linux-gnu/nvidia/libnvcolorutil.so`

- Package: `r36.4-l4t-core 36.4.7-20250918154033`
- Highest GLIBC symbol version seen by `readelf -V`: `2.29`
- NEEDED: `libnvos.so`, `libm.so.6`, `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - none found

## `r36.4-l4t-core/usr/lib/aarch64-linux-gnu/nvidia/libnvdc.so`

- Package: `r36.4-l4t-core 36.4.7-20250918154033`
- Highest GLIBC symbol version seen by `readelf -V`: `2.34`
- NEEDED: `libnvimp.so`, `libnvrm_chip.so`, `libnvrm_mem.so`, `libnvrm_surface.so`, `libnvrm_sync.so`, `libm.so.6`, `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - `/dev/fb%d`
  - `/dev/tegra_dc_%d`
  - `/dev/tegra_dc_ctrl`
  - `/sys/class/graphics/fb%d/device/crc_checksum_latched`

## `r36.4-l4t-core/usr/lib/aarch64-linux-gnu/nvidia/libnvddk_2d_v2.so`

- Package: `r36.4-l4t-core 36.4.7-20250918154033`
- Highest GLIBC symbol version seen by `readelf -V`: `2.17`
- NEEDED: `libnvrm_host1x.so`, `libnvrm_mem.so`, `libnvrm_stream.so`, `libnvrm_surface.so`, `libnvos.so`, `libnvddk_vic.so`, `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - none found

## `r36.4-l4t-core/usr/lib/aarch64-linux-gnu/nvidia/libnvddk_vic.so`

- Package: `r36.4-l4t-core 36.4.7-20250918154033`
- Highest GLIBC symbol version seen by `readelf -V`: `2.17`
- NEEDED: `libnvrm_chip.so`, `libnvrm_host1x.so`, `libnvrm_mem.so`, `libnvrm_stream.so`, `libnvrm_sync.so`, `libnvos.so`, `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - none found

## `r36.4-l4t-core/usr/lib/aarch64-linux-gnu/nvidia/libnvdla_runtime.so`

- Package: `r36.4-l4t-core 36.4.7-20250918154033`
- Highest GLIBC symbol version seen by `readelf -V`: `2.32`
- NEEDED: `libnvrm_host1x.so`, `libnvrm_mem.so`, `libnvsocsys.so`, `libnvos.so`, `libstdc++.so.6`, `libm.so.6`, `libc.so.6`, `ld-linux-aarch64.so.1`, `libgcc_s.so.1`
- Paths:

  - `/dev/nvhost-ctrl-nvdla0`
  - `/dev/nvhost-ctrl-nvdla1`

## `r36.4-l4t-core/usr/lib/aarch64-linux-gnu/nvidia/libnvfnet.so`

- Package: `r36.4-l4t-core 36.4.7-20250918154033`
- Highest GLIBC symbol version seen by `readelf -V`: `2.29`
- NEEDED: `libEGL.so.1`, `libnvrm_sync.so`, `libnvrm_host1x.so`, `libexpat.so.1`, `libstdc++.so.6`, `libm.so.6`, `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - none found

## `r36.4-l4t-core/usr/lib/aarch64-linux-gnu/nvidia/libnvfnetstoredefog.so`

- Package: `r36.4-l4t-core 36.4.7-20250918154033`
- Highest GLIBC symbol version seen by `readelf -V`: `2.17`
- NEEDED: `libnvfnet.so`, `libstdc++.so.6`, `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - none found

## `r36.4-l4t-core/usr/lib/aarch64-linux-gnu/nvidia/libnvfnetstorehdfx.so`

- Package: `r36.4-l4t-core 36.4.7-20250918154033`
- Highest GLIBC symbol version seen by `readelf -V`: `2.17`
- NEEDED: `libnvfnet.so`, `libstdc++.so.6`, `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - none found

## `r36.4-l4t-core/usr/lib/aarch64-linux-gnu/nvidia/libnvgov_boot.so`

- Package: `r36.4-l4t-core 36.4.7-20250918154033`
- Highest GLIBC symbol version seen by `readelf -V`: `2.17`
- NEEDED: `libnvphsd.so`, `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - none found

## `r36.4-l4t-core/usr/lib/aarch64-linux-gnu/nvidia/libnvgov_camera.so`

- Package: `r36.4-l4t-core 36.4.7-20250918154033`
- Highest GLIBC symbol version seen by `readelf -V`: `2.17`
- NEEDED: `libnvphsd.so`, `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - none found

## `r36.4-l4t-core/usr/lib/aarch64-linux-gnu/nvidia/libnvgov_force.so`

- Package: `r36.4-l4t-core 36.4.7-20250918154033`
- Highest GLIBC symbol version seen by `readelf -V`: `2.17`
- NEEDED: `libnvphsd.so`, `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - none found

## `r36.4-l4t-core/usr/lib/aarch64-linux-gnu/nvidia/libnvgov_generic.so`

- Package: `r36.4-l4t-core 36.4.7-20250918154033`
- Highest GLIBC symbol version seen by `readelf -V`: `2.17`
- NEEDED: `libnvphsd.so`, `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - none found

## `r36.4-l4t-core/usr/lib/aarch64-linux-gnu/nvidia/libnvgov_gpucompute.so`

- Package: `r36.4-l4t-core 36.4.7-20250918154033`
- Highest GLIBC symbol version seen by `readelf -V`: `2.17`
- NEEDED: `libnvphsd.so`, `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - none found

## `r36.4-l4t-core/usr/lib/aarch64-linux-gnu/nvidia/libnvgov_graphics.so`

- Package: `r36.4-l4t-core 36.4.7-20250918154033`
- Highest GLIBC symbol version seen by `readelf -V`: `2.17`
- NEEDED: `libnvphsd.so`, `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - none found

## `r36.4-l4t-core/usr/lib/aarch64-linux-gnu/nvidia/libnvgov_il.so`

- Package: `r36.4-l4t-core 36.4.7-20250918154033`
- Highest GLIBC symbol version seen by `readelf -V`: `2.17`
- NEEDED: `libnvphsd.so`, `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - none found

## `r36.4-l4t-core/usr/lib/aarch64-linux-gnu/nvidia/libnvgov_spincircle.so`

- Package: `r36.4-l4t-core 36.4.7-20250918154033`
- Highest GLIBC symbol version seen by `readelf -V`: `2.17`
- NEEDED: `libnvphsd.so`, `libc.so.6`
- Paths:

  - none found

## `r36.4-l4t-core/usr/lib/aarch64-linux-gnu/nvidia/libnvgov_tbc.so`

- Package: `r36.4-l4t-core 36.4.7-20250918154033`
- Highest GLIBC symbol version seen by `readelf -V`: `2.33`
- NEEDED: `libnvphsd.so`, `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - none found

## `r36.4-l4t-core/usr/lib/aarch64-linux-gnu/nvidia/libnvgov_ui.so`

- Package: `r36.4-l4t-core 36.4.7-20250918154033`
- Highest GLIBC symbol version seen by `readelf -V`: `2.17`
- NEEDED: `libnvphsd.so`, `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - none found

## `r36.4-l4t-core/usr/lib/aarch64-linux-gnu/nvidia/libnvidia-rmapi-tegra.so.540.4.0`

- Package: `r36.4-l4t-core 36.4.7-20250918154033`
- Highest GLIBC symbol version seen by `readelf -V`: `2.17`
- NEEDED: `libpthread.so.0`, `libc.so.6`, `libnvrm_gpu.so`, `libnvrm_chip.so`, `libnvrm_host1x.so`, `libnvrm_mem.so`, `libnvrm_surface.so`, `libnvrm_sync.so`, `libnvos.so`
- Paths:

  - `/dev/mem`
  - `/dev/mods`
  - `/proc/cpuinfo`
  - `/sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq`
  - `/sys/devices/system/cpu/possible`

## `r36.4-l4t-core/usr/lib/aarch64-linux-gnu/nvidia/libnvidia-tls.so.540.4.0`

- Package: `r36.4-l4t-core 36.4.7-20250918154033`
- Highest GLIBC symbol version seen by `readelf -V`: `2.17`
- NEEDED: `libc.so.6`
- Paths:

  - none found

## `r36.4-l4t-core/usr/lib/aarch64-linux-gnu/nvidia/libnvimp.so`

- Package: `r36.4-l4t-core 36.4.7-20250918154033`
- Highest GLIBC symbol version seen by `readelf -V`: `2.17`
- NEEDED: `libnvrm_chip.so`, `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - none found

## `r36.4-l4t-core/usr/lib/aarch64-linux-gnu/nvidia/libnvisp_utils.so`

- Package: `r36.4-l4t-core 36.4.7-20250918154033`
- Highest GLIBC symbol version seen by `readelf -V`: `2.33`
- NEEDED: `libnvos.so`, `libstdc++.so.6`, `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - none found

## `r36.4-l4t-core/usr/lib/aarch64-linux-gnu/nvidia/libnvphs.so`

- Package: `r36.4-l4t-core 36.4.7-20250918154033`
- Highest GLIBC symbol version seen by `readelf -V`: `2.34`
- NEEDED: `libnvos.so`, `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - `/proc/self/cmdline`

## `r36.4-l4t-core/usr/lib/aarch64-linux-gnu/nvidia/libnvphsd.so`

- Package: `r36.4-l4t-core 36.4.7-20250918154033`
- Highest GLIBC symbol version seen by `readelf -V`: `2.34`
- NEEDED: `libnvos.so`, `libm.so.6`, `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - `/dev/stune/cgroup.procs`
  - `/dev/stune/nvphsd/cgroup.procs`
  - `/dev/stune/nvphsd/schedtune.boost`
  - `/proc/%d/comm`
  - `/proc/%d/largest_task`
  - `/proc/%d/task`

## `r36.4-l4t-core/usr/lib/aarch64-linux-gnu/nvidia/libnvpva.so`

- Package: `r36.4-l4t-core 36.4.7-20250918154033`
- Highest GLIBC symbol version seen by `readelf -V`: `2.34`
- NEEDED: `libnvos.so`, `libnvrm_mem.so`, `libnvrm_surface.so`, `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - `/dev/nvhost-ctrl-pva`

## `r36.4-l4t-core/usr/lib/aarch64-linux-gnu/nvidia/libnvpva_algorithms.so`

- Package: `r36.4-l4t-core 36.4.7-20250918154033`
- Highest GLIBC symbol version seen by `readelf -V`: `2.27`
- NEEDED: `libnvos.so`, `libnvrm_mem.so`, `libnvrm_surface.so`, `libnvpva.so`, `libnvsocsys.so`, `libm.so.6`, `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - none found

## `r36.4-l4t-core/usr/lib/aarch64-linux-gnu/nvidia/libnvpvaumd.so`

- Package: `r36.4-l4t-core 36.4.7-20250918154033`
- Highest GLIBC symbol version seen by `readelf -V`: `2.34`
- NEEDED: `libnvrm_mem.so`, `libnvsocsys.so`, `libnvos.so`, `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - `/dev/nvhost-ctrl-pva0`
  - `/dev/nvhost-ctrl-pva1`

## `r36.4-l4t-core/usr/lib/aarch64-linux-gnu/nvidia/libnvrm_chip.so`

- Package: `r36.4-l4t-core 36.4.7-20250918154033`
- Highest GLIBC symbol version seen by `readelf -V`: `2.17`
- NEEDED: `libnvos.so`, `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - `/sys/devices/soc0/major`
  - `/sys/devices/soc0/minor`
  - `/sys/devices/soc0/platform`
  - `/sys/devices/soc0/revision`
  - `/sys/devices/soc0/soc_id`
  - `/sys/module/fuse/parameters/tegra_chip_id`
  - `/sys/module/fuse/parameters/tegra_chip_rev`
  - `/sys/module/fuse/parameters/tegra_cpu`
  - `/sys/module/fuse/parameters/tegra_platform`
  - `/sys/module/tegra_fuse/parameters/tegra_chip_id`
  - `/sys/module/tegra_fuse/parameters/tegra_chip_rev`
  - `/sys/module/tegra_fuse/parameters/tegra_cpu`
  - `/sys/module/tegra_fuse/parameters/tegra_platform`

## `r36.4-l4t-core/usr/lib/aarch64-linux-gnu/nvidia/libnvrm_host1x.so`

- Package: `r36.4-l4t-core 36.4.7-20250918154033`
- Highest GLIBC symbol version seen by `readelf -V`: `2.25`
- NEEDED: `libnvrm_chip.so`, `libnvrm_mem.so`, `libnvos.so`, `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - `/dev/dri`
  - `/dev/dri/%s`
  - `/dev/host1x-fence`
  - `/dev/nvhost-ctrl`
  - `/dev/nvhost-display`
  - `/dev/nvhost-dsi`
  - `/dev/nvhost-gpu`
  - `/dev/nvhost-isp`
  - `/dev/nvhost-isp.1`
  - `/dev/nvhost-msenc`
  - `/dev/nvhost-nvdec`
  - `/dev/nvhost-nvdec1`
  - `/dev/nvhost-nvenc1`
  - `/dev/nvhost-nvjpg`
  - `/dev/nvhost-nvjpg1`
  - `/dev/nvhost-ofa`
  - `/dev/nvhost-tsec`
  - `/dev/nvhost-tsecb`
  - `/dev/nvhost-vi`
  - `/dev/nvhost-vi.1`
  - `/dev/nvhost-vic`

## `r36.4-l4t-core/usr/lib/aarch64-linux-gnu/nvidia/libnvrm_stream.so`

- Package: `r36.4-l4t-core 36.4.7-20250918154033`
- Highest GLIBC symbol version seen by `readelf -V`: `2.17`
- NEEDED: `libnvrm_mem.so`, `libnvrm_host1x.so`, `libnvos.so`, `libnvrm_sync.so`, `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - none found

## `r36.4-l4t-core/usr/lib/aarch64-linux-gnu/nvidia/libnvrm_surface.so`

- Package: `r36.4-l4t-core 36.4.7-20250918154033`
- Highest GLIBC symbol version seen by `readelf -V`: `2.34`
- NEEDED: `libnvrm_mem.so`, `libnvos.so`, `libnvrm_chip.so`, `libnvrm_sync.so`, `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - `/dev/nvgpu/igpu0/ctrl`

## `r36.4-l4t-core/usr/lib/aarch64-linux-gnu/nvidia/libnvrm_sync.so`

- Package: `r36.4-l4t-core 36.4.7-20250918154033`
- Highest GLIBC symbol version seen by `readelf -V`: `2.34`
- NEEDED: `libnvos.so`, `libnvrm_chip.so`, `libnvrm_host1x.so`, `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - none found

## `r36.4-l4t-core/usr/lib/aarch64-linux-gnu/nvidia/libnvsciipc.so`

- Package: `r36.4-l4t-core 36.4.7-20250918154033`
- Highest GLIBC symbol version seen by `readelf -V`: `2.34`
- NEEDED: `libnvos.so`, `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - `/dev/ivc`
  - `/dev/nvsciipc`
  - `/proc/%d`
  - `/proc/%d/task/%d`
  - `/proc/device-tree/soc_id`
  - `/sys/class/tegra_hv`

## `r36.4-l4t-core/usr/lib/aarch64-linux-gnu/nvidia/libnvsocsys.so`

- Package: `r36.4-l4t-core 36.4.7-20250918154033`
- Highest GLIBC symbol version seen by `readelf -V`: `2.17`
- NEEDED: `libnvos.so`, `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - `/sys/bus/nvmem/devices/fuse/nvmem`
  - `/sys/devices/soc0/major`
  - `/sys/devices/soc0/minor`
  - `/sys/devices/soc0/platform`
  - `/sys/devices/soc0/production`
  - `/sys/devices/soc0/revision`
  - `/sys/devices/soc0/soc_id`
  - `/sys/module/fuse/parameters/tegra_chip_id`
  - `/sys/module/fuse/parameters/tegra_chip_rev`
  - `/sys/module/fuse/parameters/tegra_cpu`
  - `/sys/module/fuse/parameters/tegra_platform`
  - `/sys/module/fuse/parameters/tegra_prod_mode`
  - `/sys/module/tegra_fuse/parameters/tegra_chip_id`
  - `/sys/module/tegra_fuse/parameters/tegra_chip_rev`
  - `/sys/module/tegra_fuse/parameters/tegra_cpu`
  - `/sys/module/tegra_fuse/parameters/tegra_platform`
  - `/sys/module/tegra_fuse/parameters/tegra_prod_mode`

## `r36.4-l4t-core/usr/lib/aarch64-linux-gnu/nvidia/libnvtegrahv.so`

- Package: `r36.4-l4t-core 36.4.7-20250918154033`
- Highest GLIBC symbol version seen by `readelf -V`: `2.17`
- NEEDED: `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - `/dev/tegra_hv_vcpu_yield_vm%u`
  - `/sys/class/tegra_hv/vmid`

## `r36.4-l4t-core/usr/lib/aarch64-linux-gnu/nvidia/libnvvic.so`

- Package: `r36.4-l4t-core 36.4.7-20250918154033`
- Highest GLIBC symbol version seen by `readelf -V`: `2.17`
- NEEDED: `libnvrm_mem.so`, `libnvrm_host1x.so`, `libnvrm_stream.so`, `libnvsocsys.so`, `libnvos.so`, `libnvcolorutil.so`, `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - none found

## `r36.4-l4t-core/usr/lib/aarch64-linux-gnu/nvidia/libsensors.hal-client.nvs.so`

- Package: `r36.4-l4t-core 36.4.7-20250918154033`
- Highest GLIBC symbol version seen by `readelf -V`: `2.34`
- NEEDED: `libnvos.so`, `libstdc++.so.6`, `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - none found

## `r36.4-l4t-core/usr/lib/aarch64-linux-gnu/nvidia/libsensors.l4t.no_fusion.nvs.so`

- Package: `r36.4-l4t-core 36.4.7-20250918154033`
- Highest GLIBC symbol version seen by `readelf -V`: `none found`
- NEEDED: `libsensors_hal.nvs.so`, `libstdc++.so.6`
- Paths:

  - none found

## `r36.4-l4t-core/usr/lib/aarch64-linux-gnu/nvidia/libsensors_hal.nvs.so`

- Package: `r36.4-l4t-core 36.4.7-20250918154033`
- Highest GLIBC symbol version seen by `readelf -V`: `2.34`
- NEEDED: `libnvos.so`, `libstdc++.so.6`, `libc.so.6`, `ld-linux-aarch64.so.1`
- Paths:

  - `/dev/iio:device%d`
  - `/dev/input/event%u`
  - `/dev/nvs:device%d`
  - `/sys/bus/iio/devices`
  - `/sys/bus/iio/devices/iio:device%d`
  - `/sys/bus/nvs/devices`
  - `/sys/bus/nvs/devices/nvs:device%d`
  - `/sys/class/input`
  - `/sys/class/input/input%d`
  - `/sys/class/input/input%d/attr`

## `r36.4-l4t-cuda/usr/lib/aarch64-linux-gnu/nvidia/libnvcucompat.so`

- Package: `r36.4-l4t-cuda 36.4.7-20250918154033`
- Highest GLIBC symbol version seen by `readelf -V`: `2.17`
- NEEDED: `libc.so.6`, `ld-linux-aarch64.so.1`, `libdl.so.2`, `libnvrm_gpu.so`, `libnvrm_sync.so`, `libnvrm_mem.so`, `libnvrm_host1x.so`
- Paths:

  - none found

## `r36.4-l4t-cuda/usr/lib/aarch64-linux-gnu/nvidia/libnvcudla.so`

- Package: `r36.4-l4t-cuda 36.4.7-20250918154033`
- Highest GLIBC symbol version seen by `readelf -V`: `2.17`
- NEEDED: `libc.so.6`, `libdl.so.2`, `libcuda.so`, `libstdc++.so.6`, `libnvdla_runtime.so`
- Paths:

  - none found

## Combined unique paths

- `/dev/`
- `/dev/%s %dMB %dMB *`
- `/dev/char/%d:%d`
- `/dev/dri`
- `/dev/dri/%.22s`
- `/dev/dri/%s`
- `/dev/dri/by-path/platform-13e00000.host1x-card`
- `/dev/fb%d`
- `/dev/host1x-fence`
- `/dev/iio:device%d`
- `/dev/input/event%u`
- `/dev/ion`
- `/dev/ivc`
- `/dev/l3cache`
- `/dev/mem`
- `/dev/mods`
- `/dev/null`
- `/dev/nvgpu`
- `/dev/nvgpu-pci`
- `/dev/nvgpu-pci/card-%s-dbg`
- `/dev/nvgpu/igpu0/ctrl`
- `/dev/nvhost`
- `/dev/nvhost-ctrl`
- `/dev/nvhost-ctrl-gpu`
- `/dev/nvhost-ctrl-nvdla0`
- `/dev/nvhost-ctrl-nvdla1`
- `/dev/nvhost-ctrl-pva`
- `/dev/nvhost-ctrl-pva0`
- `/dev/nvhost-ctrl-pva1`
- `/dev/nvhost-dbg-gpu`
- `/dev/nvhost-display`
- `/dev/nvhost-dsi`
- `/dev/nvhost-gpu`
- `/dev/nvhost-isp`
- `/dev/nvhost-isp.1`
- `/dev/nvhost-msenc`
- `/dev/nvhost-nvdec`
- `/dev/nvhost-nvdec1`
- `/dev/nvhost-nvenc1`
- `/dev/nvhost-nvjpg`
- `/dev/nvhost-nvjpg1`
- `/dev/nvhost-ofa`
- `/dev/nvhost-tsec`
- `/dev/nvhost-tsecb`
- `/dev/nvhost-vi`
- `/dev/nvhost-vi.1`
- `/dev/nvhost-vic`
- `/dev/nvidia%d`
- `/dev/nvidia-caps`
- `/dev/nvidia-caps-imex-channels`
- `/dev/nvidia-caps-imex-channels/channel%d`
- `/dev/nvidia-caps/nvidia-cap%d`
- `/dev/nvidia-modeset`
- `/dev/nvidia-nvlink`
- `/dev/nvidia-nvswitch%d`
- `/dev/nvidia-nvswitchctl`
- `/dev/nvidia-uvm`
- `/dev/nvidia-uvm-tools`
- `/dev/nvidia-vgpu%d`
- `/dev/nvidia-vgpuctl`
- `/dev/nvidiactl`
- `/dev/nvidiactl%d`
- `/dev/nvmap`
- `/dev/nvs:device%d`
- `/dev/nvsciipc`
- `/dev/stune/cgroup.procs`
- `/dev/stune/nvphsd/cgroup.procs`
- `/dev/stune/nvphsd/schedtune.boost`
- `/dev/tegra_dc_%d`
- `/dev/tegra_dc_ctrl`
- `/dev/tegra_hv_vcpu_yield_vm%u`
- `/dev/urandom`
- `/proc/%d`
- `/proc/%d/comm`
- `/proc/%d/exe`
- `/proc/%d/fd/%d`
- `/proc/%d/largest_task`
- `/proc/%d/task`
- `/proc/%d/task/%d`
- `/proc/%d/task/%s/comm`
- `/proc/%ld/exe`
- `/proc/%lld/ns/%s`
- `/proc/cpuinfo`
- `/proc/device-tree/compatible`
- `/proc/device-tree/model`
- `/proc/device-tree/soc_id`
- `/proc/devices`
- `/proc/driver/nvidia-nvlink/capabilities/fabric-mgmt`
- `/proc/driver/nvidia-nvlink/permissions`
- `/proc/driver/nvidia-nvswitch/permissions`
- `/proc/driver/nvidia/%d/params`
- `/proc/driver/nvidia/capabilities/fabric-imex-mgmt`
- `/proc/driver/nvidia/capabilities/gpu%u/mig/gi%u/access`
- `/proc/driver/nvidia/capabilities/gpu%u/mig/gi%u/ci%u/access`
- `/proc/driver/nvidia/capabilities/mig/config`
- `/proc/driver/nvidia/capabilities/mig/monitor`
- `/proc/driver/nvidia/gpus/%04x:%02x:%02x.%1u/numa_status`
- `/proc/driver/nvidia/params`
- `/proc/meminfo`
- `/proc/modules`
- `/proc/self/cmdline`
- `/proc/self/comm`
- `/proc/self/exe`
- `/proc/self/maps`
- `/proc/self/status`
- `/proc/self/task/%d/comm`
- `/proc/stat`
- `/proc/sys/kernel/modprobe`
- `/proc/sys/vm/mmap_min_addr`
- `/sys/bus/i2c/drivers`
- `/sys/bus/iio/devices`
- `/sys/bus/iio/devices/iio:device%d`
- `/sys/bus/nvmem/devices/fuse/nvmem`
- `/sys/bus/nvs/devices`
- `/sys/bus/nvs/devices/nvs:device%d`
- `/sys/bus/pci/devices`
- `/sys/bus/pci/devices/%04x:%02x:%02x.%1u/rescan`
- `/sys/bus/pci/rescan`
- `/sys/class/graphics/fb%d/device/crc_checksum_latched`
- `/sys/class/hwmon`
- `/sys/class/input`
- `/sys/class/input/input%d`
- `/sys/class/input/input%d/attr`
- `/sys/class/tegra_hv`
- `/sys/class/tegra_hv/vmid`
- `/sys/class/thermal`
- `/sys/devices/platform/host1x/capabilities/alloc_chs_per_submits`
- `/sys/devices/platform/host1x/capabilities/gather_filter_enabled`
- `/sys/devices/platform/host1x/capabilities/num_mlocks`
- `/sys/devices/platform/host1x/capabilities/num_pts`
- `/sys/devices/soc0/family`
- `/sys/devices/soc0/major`
- `/sys/devices/soc0/minor`
- `/sys/devices/soc0/platform`
- `/sys/devices/soc0/production`
- `/sys/devices/soc0/revision`
- `/sys/devices/soc0/soc_id`
- `/sys/devices/system/cpu/cpu%d/cpufreq/scaling_cur_freq`
- `/sys/devices/system/cpu/cpu%d/cpufreq/scaling_max_freq`
- `/sys/devices/system/cpu/cpu%d/cpufreq/scaling_min_freq`
- `/sys/devices/system/cpu/cpu%d/online`
- `/sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq`
- `/sys/devices/system/cpu/possible`
- `/sys/devices/system/cpu/present`
- `/sys/devices/system/memory/auto_online_blocks`
- `/sys/devices/system/memory/block_size_bytes`
- `/sys/devices/system/node`
- `/sys/devices/system/node/%s/cpumap`
- `/sys/devices/system/node/node%d/meminfo`
- `/sys/devices/system/node/node%ld/meminfo`
- `/sys/kernel/debug/clock/emc/possible_rates`
- `/sys/kernel/debug/clock/emc/rate`
- `/sys/kernel/debug/clock/gbus/rate`
- `/sys/module/%s/initstate`
- `/sys/module/fuse/parameters/tegra_chip_id`
- `/sys/module/fuse/parameters/tegra_chip_rev`
- `/sys/module/fuse/parameters/tegra_cpu`
- `/sys/module/fuse/parameters/tegra_platform`
- `/sys/module/fuse/parameters/tegra_prod_mode`
- `/sys/module/tegra_fuse/parameters/tegra_chip_id`
- `/sys/module/tegra_fuse/parameters/tegra_chip_rev`
- `/sys/module/tegra_fuse/parameters/tegra_cpu`
- `/sys/module/tegra_fuse/parameters/tegra_platform`
- `/sys/module/tegra_fuse/parameters/tegra_prod_mode`
