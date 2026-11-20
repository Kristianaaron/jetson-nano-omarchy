# jetson-nano-omarchy

[Omarchy](https://omarchy.org) running natively on the original NVIDIA Jetson Nano 4 GB (Tegra210,
GM20B Maxwell GPU, compute capability 5.3), on a mainline Linux kernel and Arch Linux ARM, with
NVIDIA's own GPU driver ported to that kernel so CUDA 12 can run next to the desktop.

This is a research project. Every result in `docs/` and `results/` is labelled **measured** (seen on
the board, with the log named) or **inferred**. Nothing here is supported by NVIDIA or Omarchy.

## Status (2026-11-20)

| Area | State |
|---|---|
| Omarchy 4.5 desktop (Hyprland, SDDM) on mainline 7.2.11 | works on **one driver stack**: Mesa Zink on NVIDIA's R36 Vulkan driver over nvgpu, hardware cursor, clean logout ([docs/cuda-feasibility.md §18, §20](docs/cuda-feasibility.md)) |
| NVIDIA nvgpu + nvmap (L4T R36) on mainline 7.2.11 | packaged (`nvgpu-nano`), load at boot; DVFS 76.8 to 921.6 MHz with voltage scaling ([§19](docs/cuda-feasibility.md)) |
| CUDA 12 on GM20B | **works next to the desktop**: CUDA 12.6 driver API, sm_53 cubin and PTX JIT, 188 GFLOP/s FP32 at 921.6 MHz, all results correct |
| Vulkan 1.3 | works (NVIDIA R36 driver); `vulkaninfo` itself aborts in NVIDIA's display path |
| Kernel package `linux-nano` | ALARM `linux-aarch64` 7.2.11 + Tegra210 config + tegra-drm block-linear modifiers; 7.2.11-2 booting ([packaging/linux-nano](packaging/linux-nano)) |
| EMC (memory) at 1600 MHz | works with the trained-table patch; raised at boot by `jetson-nano-board` |
| nouveau desktop (fallback boot entry) | works through a patched Mesa `tegra` driver ([packaging/mesa-tegra](packaging/mesa-tegra)) |
| CUDA toolkit package | open: NVRTC and the compiler still come from the unpacked CUDA 12.6 archive |
| HDMI hot-plug / EDID | broken (mode is forced) |

Read [docs/omarchy-on-jetson-nano.md](docs/omarchy-on-jetson-nano.md) for the desktop port and
[docs/cuda-feasibility.md](docs/cuda-feasibility.md) for the CUDA work, in that order.

## Layout

| Path | Contents |
|---|---|
| `docs/` | engineering record, plans, decisions (ADRs), boot chain and recovery |
| `packaging/` | Arch packages: `linux-nano` kernel, `nvgpu-nano`, `nvidia-l4t-r36`, `nvidia-l4t-gm20b-firmware`, `jetson-nano-board`, `hyprland-nano`, `aquamarine-nano`, `mesa-tegra`, `omarchy-nano` |
| `omarchy/` | provisioning, platform detection and config files for the Nano |
| `tools/cuda-e*/` | CUDA experiments: E0 desk checks, E2 nvgpu/nvmap builds, E4 power-on, E5 smoke test |
| `scripts/` | SD-card build, boot evidence and diagnostics helpers |
| `results/` | logs and measurements (sanitised with `tools/sanitize-log.py`) |
| `tests/` | smoke and regression test plans |

The NVIDIA driver ports live in forks of OE4T's mirrors, branch `mainline-7.2`:
[Kristianaaron/linux-nvgpu](https://github.com/Kristianaaron/linux-nvgpu) and
[Kristianaaron/linux-nv-oot](https://github.com/Kristianaaron/linux-nv-oot).

## Safety

The scripts never write the QSPI bootloader. `scripts/build-sd-image-mac.sh` refuses to overwrite a
card that holds an L4T system and requires `ROOT_PASS` for the initial password (change it after the
first boot). See [docs/rollback-recovery.md](docs/rollback-recovery.md) before touching a card.

## Credits

This builds on other people's work:

| Who | What | Source | Licence |
|---|---|---|---|
| NVIDIA | nvgpu and nvidia-oot drivers, L4T firmware and userspace | [nv-tegra.nvidia.com](https://nv-tegra.nvidia.com) | GPL-2.0 (drivers); NVIDIA licence (firmware, userspace, not redistributed here) |
| OE4T (OpenEmbedded for Tegra) | maintained mirrors and patches of NVIDIA's R36 drivers | [OE4T/linux-nvgpu](https://github.com/OE4T/linux-nvgpu), [OE4T/linux-nv-oot](https://github.com/OE4T/linux-nv-oot) | GPL-2.0 |
| Arch Linux ARM (Kevin Mihelich, graysky) | `linux-aarch64` PKGBUILD, config and patches that `linux-nano` derives from | [archlinuxarm/PKGBUILDs](https://github.com/archlinuxarm/PKGBUILDs) | GPL-2.0 (kernel) |
| Omarchy (DHH and contributors) | the desktop this port runs | [basecamp/omarchy](https://github.com/basecamp/omarchy) | MIT |
| Omarchy packagers | `hyprland` and `aquamarine` package recipes and patches that `hyprland-nano` and `aquamarine-nano` extend | [omacom/omarchy-pkgs](https://github.com/omacom/omarchy-pkgs) | per package |
| hyprwm (Vaxry and contributors) | Hyprland and aquamarine | [hyprwm/Hyprland](https://github.com/hyprwm/Hyprland), [hyprwm/aquamarine](https://github.com/hyprwm/aquamarine) | BSD-3-Clause |
| Mesa, nouveau and Linux Tegra maintainers | GM20B graphics, Tegra210 support, EMC driver (Joseph Lo, Thierry Reding) | [mesa](https://gitlab.freedesktop.org/mesa/mesa), [kernel.org](https://kernel.org) | MIT / GPL-2.0 |

Not affiliated with or endorsed by NVIDIA, Omarchy, Basecamp or Arch Linux ARM.

## Licence

Scripts, tools and documentation: MIT ([LICENSE](LICENSE)). Patches keep the licence of the code
they modify (kernel and drivers GPL-2.0, Mesa and Omarchy MIT). No NVIDIA binaries are included;
the scripts download them from NVIDIA's repositories and check their published SHA-256.
