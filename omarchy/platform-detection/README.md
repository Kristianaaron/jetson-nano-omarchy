# Omarchy platform integration for Tegra210 (design, not yet written upstream)

Status: design only. Nothing here is submitted; it records the shape the contribution should take so
the implementation stays upstream-shaped rather than a private fork.

## Detection

Omarchy 4.x already has the primitive: `bin/omarchy-hw-match-device-tree`. The Nano profile must:

- match `nvidia,tegra210` in `/proc/device-tree/compatible`;
- require the board-level compatible `nvidia,p3450-0000`, so a different Tegra210 board does not
  inherit the Nano's quirks;
- be mutually exclusive with `omarchy-hw-aarch64-gb10` and `omarchy-hw-aarch64-n1x`, which match
  different NVIDIA SoCs;
- fail closed: unknown Tegra210 board → no profile, generic aarch64 behaviour.

Suggested helper: `bin/omarchy-hw-aarch64-tegra210`, in the style of the four existing
`omarchy-hw-aarch64-*` scripts.

## Packages

`install/omarchy-aarch64-tegra210.packages` should be near-empty by design. The generic
`install/omarchy-aarch64.packages` already covers zram and PipeWire; board-specific entries belong
here only if they are genuinely board-specific (for example a display or thermal helper). Do not add
x86-only applications, and do not add NVIDIA proprietary userspace: that stack belongs to the
inference path, not to the desktop image.

## Hardware hook

`install/hardware/tegra210.sh`, guarded by the detection above, and limited to facts the generic
installer gets wrong on this board:

1. Boot: the board boots cboot/U-Boot + `extlinux.conf`; the update path must never run Limine or UKI
   commands on it.
2. Memory: 4 GB shared with the GPU, so cap the desktop's appetite and enable zram sized for the
   model-free case.
3. Rendering: record whether the session is accelerated or software-rendered, and refuse to claim
   acceleration when Mesa reports `llvmpipe`.
4. Power/thermal: no `nvpmodel` on mainline; do not call it.

## Lifecycle

`docs/lifecycle-dispatch.md` and `omarchy-lifecycle-dispatch` are the supported extension points.
The Nano needs a `setup-boot` implementation that is a no-op, so an Omarchy update cannot make the
card unbootable. That is the single most important safety property of this port.

## Tests without hardware

- Detection: fixture device-tree compatible strings (p3450, p3541, GB10, empty) must select or reject
  the profile correctly.
- Package selection: a dry-run resolver must show no x86_64-only package for this profile.
- Lifecycle: a fake `OMARCHY_PATH` tree must prove `setup-boot` performs no writes.
