# Upstream plan

Three separate tracks, three separate success states. Do not merge them into one claim.

## 1. Omarchy (github.com/omacom/omarchy, branch `quattro`; candidate list in omarchy-on-jetson-nano.md section 11)

Shape of a narrow, reviewable contribution:

- `install/omarchy-aarch64-tegra210.packages` - only genuinely board-specific packages. The generic
  aarch64 list already brings zram and PipeWire bits; a Nano profile should add almost nothing.
- `bin/omarchy-hw-aarch64-tegra210` - detection, in the same style as the existing
  `omarchy-hw-aarch64-*` helpers. Match on device tree, using the existing
  `bin/omarchy-hw-match-device-tree`, against `nvidia,tegra210` plus the P3450 compatible. Must be
  mutually exclusive with `omarchy-hw-aarch64-gb10` and `-n1x`.
- `install/hardware/tegra210.sh` - guarded by that detection; sets what Omarchy's assumptions get
  wrong here: no Limine/UKI management, no x86 app set, memory limits for 4 GB, software-rendering
  fallback policy.
- Boot lifecycle: `docs/lifecycle-dispatch.md` + `omarchy-lifecycle-dispatch` are the documented
  extension points. The Nano boots cboot/U-Boot with `extlinux.conf`, so the update path must be a
  no-op for boot files rather than rewriting them.
- A feature matrix in the PR: display, network, audio, camera, Bluetooth, AI runtimes, each marked
  works / limited / unsupported.

PR discipline: one commit per concern, a tested install receipt, and no "complete board support"
claim without the hardware tests.

## 2. Linux / Mesa / U-Boot

Only if the board needs it, and one patch per subsystem:

- `arch/arm64/boot/dts/nvidia/tegra210-*`: display, PCIe/Ethernet or thermal corrections discovered
  on hardware, with the exact failure they fix.
- `drivers/gpu/drm/tegra`, `drivers/gpu/drm/nouveau`: only with a reproducible failure that is not a
  configuration mistake, plus regression evidence on other Tegra boards.
- U-Boot: only if the stock chain cannot load a mainline `Image` + DTB; otherwise do not touch it.

## 3. TensorFold (github.com/ashhart/TensorFold)

- A `cuda-legacy-sm53` backend behind compile-time and runtime capability gates.
- CUDA 10.2 as the toolchain baseline; no CUDA 13 PTX sent to SM 5.3.
- Correctness first: per-operator test vectors with tolerances, then model-level logits.
- Qualification is per (model, format, quant, GPU) and recorded as such.
- Coordinate with the maintainers' backend abstraction before writing kernels.

## Issue tracking

Three tracks, three states: OS boot/graphics, GPU inference, joint integration. "Boots and renders
with llvmpipe" and "CUDA runs" are both valuable and neither implies the other.

## Install path on the Nano (as run on 2026-11-17)

Superseded: the draft `omarchy/installer-hooks/install-omarchy-nano.sh` cloned the Omarchy tree
and installed packages directly. On hardware that left out Omarchy's system files (SDDM Wayland
greeter, session file, `/etc/skel` configs), which come from the `omarchy-settings` package.

The working path uses Omarchy's own packages and repositories:

- `omarchy-refresh-pacman stable` and `omarchy-update-keyring` (Omarchy's aarch64 repo plus its
  pinned Arch Linux ARM mirror), then `pacman -S omarchy omarchy-settings` (4.5.0-3) and
  `omarchy-reinstall-pkgs`.
- `omarchy-apply-system` stages minus `install/config/snapper.sh` (ext4 root).
- Board configuration that Omarchy does not provide: `omarchy/nano/files/`.
- Reproduction script: `omarchy/nano/provision-nano.sh` (under review, not yet run on a fresh card).

Full record, findings and the per-project upstream candidates: [omarchy-on-jetson-nano.md](omarchy-on-jetson-nano.md).
