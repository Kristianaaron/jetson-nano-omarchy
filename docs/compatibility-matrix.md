# Compatibility matrix: Jetson Nano 4GB (P3450) × Omarchy ARM64

Status vocabulary: **verified** (checked in a source tree, package or kernel package I inspected),
**assumed** (plausible, not checked), **blocked** (contradicted by evidence), **unknown** (needs the
physical board).

Board: P3448-0000 module on a P3450 carrier (dev kit A02), 4 GB LPDDR4, GM20B Maxwell SM 5.3,
128 GB microSD, 1 TB USB SATA. No hardware access yet, so every runtime claim is `unknown`.

## Platform and firmware

| Component | Status | Evidence |
|---|---|---|
| Vendor stack: JetPack 4.6.6 / L4T R32.7.6, kernel 4.9, CUDA 10.2 | verified | GPU userspace is coupled to the NVIDIA downstream kernel; final JetPack 4 line. https://developer.nvidia.com/jetpack-sdk-466 |
| Mainline Tegra210 board support (`tegra210-p3450-0000.dts`) | verified | Enables `sor@54540000` + DPAUX (DP over USB-C) and `sor@54580000` with `hdmi-supply` (HDMI); the 2025 p3541 series derives from it. `arch/arm64/boot/dts/nvidia/tegra210-p3450-0000.dts` in Linux 7.3.4 |
| Mainline U-Boot board port | unknown | Not exercised; plan reuses NVIDIA's cboot + U-Boot from the card instead |
| Boot order on a stock card | unknown | Needs `docs/boot-chain.md` procedure run on the device |
| QSPI/bootloader location | unknown | P3450 boots from microSD; must be confirmed, not assumed |

## Kernel

| Component | Status | Evidence |
|---|---|---|
| Arch Linux ARM `linux-aarch64` 7.3.4-2 | verified | Ships `boot/Image`, `boot/initramfs-linux.img`, `boot/dtbs/nvidia/tegra210-p3450-0000.dtb`; vermagic `7.3.4-2-aarch64-ARCH SMP preempt mod_unload aarch64` |
| Tegra210 SoC + DRM + host1x + nouveau | verified in config | `ARCH_TEGRA_210_SOC=y`, `DRM_TEGRA=m`, `TEGRA_HOST1X=m`, `DRM_NOUVEAU=m`, `DRM_FBDEV_EMULATION=y`, `DRM_TEGRA_STAGING=y` |
| Storage (SD), USB, XUSB PHYs | verified in config | `MMC_SDHCI_TEGRA=y`, `TEGRA_IOMMU_SMMU=y`, `USB_XHCI_TEGRA=y`, `PHY_TEGRA_XUSB=y` |
| Ethernet | verified in config, runtime unknown | Board tree aliases `ethernet` to `/pcie@1003000/pci@2,0/ethernet@0,0`, a Realtek PCIe NIC; `r8169.ko` and `PCI_TEGRA=y` are in the package. No Tegra EQOS node exists in `tegra210.dtsi` |
| Tegra210 audio | verified in config | `SND_SOC_TEGRA=m`, `SND_SOC_TEGRA210_*=m` (HDMI audio path unproven) |
| CPU frequency / thermals | assumed | `CPUFREQ_DT=y`, `TEGRA_BPMP_THERMAL=m`; OPP table limits unknown until measured |
| Custom DT patch requirement | unknown | Only likely if HDMI or DP misbehaves on mainline |

## Graphics

| Component | Status | Evidence |
|---|---|---|
| HDMI / DP connectors on mainline DRM | unknown | DT nodes are enabled; needs `modetest`/`drm_info` on hardware |
| GPU acceleration (nouveau GM20B) | unknown | Driver is built, but Tegra X1 has no mainline reclocking; EGL/GBM unproven |
| Mesa software rendering (llvmpipe) | assumed available | Mesa for aarch64 is in ALARM; performance on 4x A57 at 1080p unmeasured |
| Hyprland on the result | unknown | Depends on EGL from the two rows above; not to be claimed before `hyprctl monitors` |
| CUDA on a mainline kernel | blocked | Vendor driver is X11-only and BSP-coupled; CUDA 10.2 needs L4T 4.9 |

## Omarchy

| Component | Status | Evidence |
|---|---|---|
| ARM64 install path | verified | `install/omarchy-aarch64*.packages`, `bin/omarchy-hw-aarch64*`, hooks in `install/hardware/`; branch `quattro`, `version` = `4.0.0.alpha` |
| Platform profiles present | verified | apple, gb10, n1x, qualcomm only |
| Tegra/Nano profile | missing (to implement) | Nothing matches `nvidia,tegra210` |
| Device-tree matching helper | verified | `bin/omarchy-hw-match-device-tree` exists, which is the right hook for this board |
| x86_64-only packages | verified | `install/omarchy-x86_64-only.packages`; the ISO is x86_64 only |
| Boot stack (Limine + UKI) | blocked here | Board boots cboot/U-Boot with `extlinux.conf`; `docs/lifecycle-dispatch.md` hook needed so updates never rewrite boot |
| 4 GB memory budget | unknown | No measurement; zram and a trimmed app set planned |

## Inference

| Component | Status | Evidence |
|---|---|---|
| MiniCPM5-1B 4-bit weights fit | assumed | ~540 MB raw at 4 bpw; must be measured with KV cache on 4 GB |
| TensorFold release binaries on SM 5.3 | blocked | Archives require glibc 2.28+ and NVIDIA driver R580+/CUDA 13.0; fatbins are sm_80/86/120/121 only. https://github.com/ashhart/TensorFold/blob/main/RUNBOOK.md |
| TensorFold legacy backend | missing (to build) | Needs CUDA 10.2-compatible kernels and SM 5.3 SASS/PTX review |
| Local CUDA proof on vendor BSP | unknown | No hardware access yet |
| Omarchy + CUDA in one boot | blocked until proven | The two stacks need different kernels; this is path C in ADR-001 |

## Sources to re-verify at implementation time

- Omarchy branch and commit (`quattro` today), `install/omarchy-aarch64.packages`, `AGENTS.md`,
  `docs/lifecycle-dispatch.md`: https://github.com/omacom/omarchy
- Arch Linux ARM kernel package: `aarch64/core/linux-aarch64-7.3.4-2-aarch64.pkg.tar.xz` on
  `mirror.archlinuxarm.org`
- Linux Tegra210 board data: `arch/arm64/boot/dts/nvidia/` in the kernel tree being used
- TensorFold RUNBOOK and release assets: https://github.com/ashhart/TensorFold

## Arch Linux ARM package availability (checked 2026-11-16 against the mirror index)

The whole Omarchy desktop stack exists for aarch64, which removes the biggest
open question from Phase 3:

| Package | aarch64 version |
|---|---|
| hyprland | 0.57.2-1 |
| quickshell | 0.3.2-1 |
| waybar | 0.16.0-1 |
| hyprlock, hypridle, hyprpaper, hyprsunset | 0.9.7, 0.1.8, 0.8.5, 0.4.0 |
| xdg-desktop-portal-hyprland | 1.5.0-1 |
| uwsm | 0.27.2-1 (any) |
| mesa, mesa-utils, libdrm, vulkan-tools | 26.2.7, 9.0.0, 2.4.134, 1.4.363 |
| qt6-wayland, qt6-svg, qt6-declarative | 6.12.0 |
| pipewire, wireplumber, pipewire-pulse | 1.6.11, 0.5.19, 1.6.11 |
| foot, alacritty, sddm, greetd | 1.28.0, 0.17.0, 0.21.0, 0.10.3 |

`drm_info` is the only tool I had listed that does not exist for aarch64; the graphics
gate uses `modetest` and `mesa-utils` instead.

Still not established: whether Hyprland runs at all on this GPU. The packages existing
says nothing about EGL, DRM or compositor stability on Tegra X1.
