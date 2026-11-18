# ADR-001: kernel and GPU strategy

- Status: accepted for Phase 1/2, to be revisited at gate P4
- Date: 2026-11-16
- Context: Jetson Nano 4GB (P3450, Tegra210, GM20B SM 5.3), 4 GB shared LPDDR4

## Problem

Two goals conflict at the kernel level:

1. A native Omarchy desktop needs Hyprland, which needs a modern Mesa/EGL and DRM/KMS stack.
2. Local CUDA inference needs NVIDIA's userspace, which on this board exists only for L4T R32 with
   kernel 4.9 and an X11-only display driver.

## Options

**A. Mainline kernel + Arch Linux ARM (desktop-first).**
Mainline has the board: `tegra210-p3450-0000.dts` enables both display paths, and Arch Linux ARM's
7.3.4 kernel already carries `ARCH_TEGRA_210_SOC`, `DRM_TEGRA`, `HOST1X`, `NOUVEAU`,
`SDHCI_TEGRA`, `XHCI_TEGRA`, `SND_SOC_TEGRA*`, plus `r8169` and the Tegra PCIe host. A desktop is
reachable in principle; CUDA is not, because the vendor driver cannot bind a 7.x mainline kernel and
its userspace expects the BSP ABI.
Cost: boot-chain work and unknown graphics quality.

**B. L4T R32.7.6 + Ubuntu (inference-first, current state).**
The board already runs a community Ubuntu 20.04 image on L4T R32 with CUDA 10.2, which is the only
path where CUDA is known to work on this silicon. Hyprland cannot run: no modern Mesa/EGL, no
GBM/Wayland from the vendor driver, kernel 4.9.
Cost: no native Omarchy; security exposure of an EOL stack.

**C. Hybrid: Arch userspace on the vendor kernel.**
Keep L4T 4.9 and put an Arch ARM rootfs on top to get newer userland. Attractive on paper, but the
vendor driver is built against L4T's glibc and X11 stack, and Hyprland still needs DRM/EGL features
that L4T 4.9 does not provide. Expected to fail the desktop gate and to risk a half-broken CUDA
install. Should only be attempted after A and B each pass their gates.

## Decision

- Phase 1/2: **option A** on a spare card, leaving the working card untouched. Desktop first.
- Inference work continues on **option B**, on the untouched known-good card, independently.
- **Option C stays closed** until A proves a compositor and B proves CUDA, and only then with a
  written compatibility test for glibc, ELF dependencies, EGL and module ABI.

Restating the constraint the brief already sets: software rendering is a diagnostic fallback, not an
accelerated desktop, and a loaded model is not a CUDA run.

## Consequences

- Two clearly named deliverables, never a merged claim: "Omarchy desktop (mainline)" and "CUDA
  inference (L4T)".
- If A ends at llvmpipe, the acceptable outcome is headless Omarchy tooling or an Omarchy-styled
  lightweight desktop, labelled as such.
- A DTS or DRM fix discovered on the way is a standalone upstreamable patch, not part of a
  board-support mega-commit.

## Revisit triggers

- Gate P4: Hyprland accelerated and stable → continue native integration.
- Gate P4: llvmpipe only → document limits, ship headless/tools profile.
- Gate P5: CUDA correct on BSP → attempt C with the ABI contract from P5 recorded.
- Any proposal to flash QSPI or change the known-good card firmware: stop, new ADR.
