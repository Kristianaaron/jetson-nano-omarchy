# Graphics and Wayland on Tegra210

Two separate questions, often confused:

- **Compositor acceleration**: can Hyprland get an EGL context and a DRM plane from the GPU?
- **CUDA**: can NVIDIA's compute userspace run a kernel?

On this board the answers come from different stacks, and a working desktop does not imply CUDA.

## What mainline provides (verified in sources, not yet on hardware)

- `tegra210-p3450-0000.dts` enables `sor@54540000` with DPAUX (DisplayPort over USB-C) and
  `sor@54580000` with `hdmi-supply` (HDMI).
- Arch Linux ARM's kernel has `DRM_TEGRA=m`, `TEGRA_HOST1X=m`, `DRM_NOUVEAU=m`,
  `DRM_FBDEV_EMULATION=y`, `DRM_TEGRA_STAGING=y`.
- `tegra-drm` is a KMS driver: it gives connectors and modes. Whether it gives a usable GL path is a
  different matter. Mesa's `tegra` gallium driver targets the Tegra DRM/VIC path, not the GM20B 3D
  engine in the same way nouveau does.

## Three rendering candidates, in test order

1. **Nouveau on GM20B**: `drm/nouveau` binds, `nouveau` KMS gives a framebuffer, and Mesa's
   `nouveau` Gallium driver would provide EGL. Risk: Tegra X1 has no mainline reclocking, so clocks
   may stay low; secure-boot/PMU firmware handling on Tegra differs from discrete cards.
2. **tegra-drm plus Mesa tegra**: correct display, GPU 3D path unproven for this use.
3. **llvmpipe**: always available, CPU-only. Acceptable only as a diagnostic or explicitly labelled
   fallback. It is not acceleration and must never be reported as such.

## Test sequence (each recorded under `results/graphics/`)

| Step | Command | Pass criterion |
|---|---|---|
| G0 | `dmesg \| grep -Ei 'tegra-drm\|nouveau\|host1x'` | drivers probe without timeouts |
| G1 | `modetest -c` or `drm_info` | HDMI connector, modes listed |
| G2 | `eglinfo -B` / `glxinfo -B` | renderer string recorded verbatim |
| G3 | `weston --backend=drm` or a bare `Hyprland` | compositor starts, output present |
| G4 | `hyprctl monitors` | 1920x1080, named output, refresh rate |
| G5 | 10-minute interactive session | input, cursor, terminal, no hang |
| G6 | idle and active RSS | numbers for the 4 GB budget |

Record the renderer per run. `llvmpipe` means G4 may pass while G2 is software; that combination is
"desktop with software rendering", not an accelerated Omarchy desktop.

## Decision points

- If G2 reports a hardware renderer and G4 holds for 10 minutes: proceed with native Omarchy
  integration and tune limits.
- If only llvmpipe works: ship headless Omarchy tooling or an Omarchy-styled lightweight desktop, and
  say so in the README and every benchmark.
- If nouveau binds but EGL fails: capture `dmesg`, `drm_info` and the Mesa error, and treat it as an
  upstreamable bug rather than a board workaround.

## Not attempted here

Vendor L4T GL/EGL on the experimental card. The R32 userspace is coupled to the 4.9 kernel and its
X11 stack; mixing it with Arch ARM and Hyprland is path C in ADR-001 and is out of scope until both
independent paths pass.
