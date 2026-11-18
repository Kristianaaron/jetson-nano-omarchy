# Omarchy on Jetson Nano 4GB (p3450): port plan

Status: route verified against upstream sources. Blocked on the board being powered on.

## Verdict

Possible, and the kernel side is smaller than it looks. The work is boot plumbing plus an
Omarchy hardware profile, not driver authoring.

What is settled:

- **NVIDIA's stack is a dead end for Hyprland.** Jetson Nano 4GB stopped at JetPack 4.6 / L4T
  r32.7.4: kernel 4.9, X11-only proprietary driver, no GBM/Wayland. Hyprland needs a modern
  Mesa/wlroots stack.
- **Mainline already supports this board.** `tegra210-p3450-0000.dts` is upstream and enables
  both display paths: `sor@54580000` with `hdmi-supply` (HDMI) and `sor@54540000` + DPAUX
  (DisplayPort over USB-C). 2025 patches added the sibling 2GB kit on top of p3450, so the
  display side is maintained.
- **Arch Linux ARM's stock kernel needs no rebuild for first boot.** Its 7.3.4 config has
  `ARCH_TEGRA_210_SOC=y`, `DRM_TEGRA=m`, `TEGRA_HOST1X=m`, `DRM_NOUVEAU=m`, `SDHCI_TEGRA=y`,
  `USB_XHCI_TEGRA=y`, `PHY_TEGRA_XUSB=y`, `SND_SOC_TEGRA*=m`, `DRM_FBDEV_EMULATION=y`, and it ships
  `tegra210-p3450-0000.dtb`. Vermagic is `7.3.4-2-aarch64-ARCH SMP preempt mod_unload aarch64`.
- **Ethernet is a Realtek PCIe NIC, not the Tegra EQOS MAC.** The p3450 device tree aliases
  `ethernet` to `/pcie@1003000/pci@2,0/ethernet@0,0`, and `r8169.ko` ships in the ALARM kernel
  package. So wired networking comes up on the stock kernel with no module work. (The earlier
  `CONFIG_DWMAC_TEGRA` finding was a red herring: that driver only matches Tegra234 MGBE, and
  mainline's Tegra210 tree has no EQOS node.)
- **Omarchy 4.x installs on aarch64, but only knows four SoCs.** It ships
  `install/omarchy-aarch64-{apple,gb10,n1x,qualcomm}.packages`, detection helpers
  `bin/omarchy-hw-aarch64-*`, and platform hooks in `install/hardware/`. There is no Tegra profile,
  the official ISO is x86_64-only, and `install/omarchy-x86_64-only.packages` has no ARM builds.

## Route

1. Arch Linux ARM generic aarch64 rootfs, stock ALARM kernel, mainline p3450 DTB.
2. Keep NVIDIA's own boot chain (cboot + U-Boot in the FAT boot partition, `extlinux.conf`), not
   Omarchy's Limine/UKI stack.
3. Install Omarchy's desktop layer on top, with a new `tegra210` profile.
4. Tune hard for 4 GB: zram, llvmpipe or tegra DRM, 1080p.

| Layer | Choice | Why |
|---|---|---|
| Bootloader | cboot + U-Boot from the stock L4T SD image, `extlinux.conf` | No tegraflash on a Mac, no recovery-mode flashing, reversible |
| Kernel | stock ALARM `linux-aarch64` 7.3.4 + its `tegra210-p3450-0000.dtb` | Everything needed is already built in; custom kernel only if a DTS fix turns out to be necessary |
| Rootfs | Arch Linux ARM generic aarch64 | The base Omarchy's ARM path expects |
| Desktop | Omarchy 4.x source + `install/omarchy-aarch64-tegra210.packages` + `install/hardware/tegra210.sh` | Upstream-shaped, so it can be contributed back |
| Swap | zram, 2-3 GB | 4 GB unified memory, no expansion possible |

## Milestones and gates

**M0 - Inventory** (blocked: board offline, Tailscale last seen 169 days ago)
- Run `scripts/probe-nano.sh` on the board over SSH.
- Gate: report shows SD size, partition layout, L4T version, `/boot/extlinux/extlinux.conf`,
  HDMI/DP connector state, RAM.

**M1 - Arch Linux ARM boots**
- Clone the stock card onto a spare one, rebuild the root partition with ALARM, point
  `extlinux.conf` at ALARM's `Image` + `tegra210-p3450-0000.dtb`.
- Gate: boots to a console on HDMI, `uname -r` is `7.3.4-2-aarch64-ARCH`, `cat
  /sys/class/drm/card0-HDMI-A-1/status` is `connected`.

**M2 - Network and graphics**
- DHCP on the Realtek NIC, SSH over the LAN, then `glxinfo -B` and a bare `Hyprland`.
- Gate: SSH reachable; `hyprctl monitors` shows 1920x1080, recording whether it is the tegra DRM
  driver or llvmpipe.

**M3 - Omarchy**
- Omarchy source, `omarchy-aarch64-tegra210.packages`, hardware hook, ARM install path, and the boot
  step made a no-op so Omarchy updates never touch `extlinux.conf`.
- Gate: desktop, bar and lock screen up for 30 minutes without OOM, one terminal and one browser tab.

**M4 - 4 GB tuning and upstreaming**
- zram sizing, `vm.swappiness`, 1080p only, drop Chromium-class defaults that thrash, document the
  profile, open an upstream PR for `tegra210`.

## Known risks

1. **cboot may not hand over to a mainline DTB cleanly.** The boot chain stays byte-identical from
   the stock card; the old `extlinux.conf` is kept as a second entry.
2. **No GPU acceleration, or awkward acceleration.** Tegra X1 has no mainline reclocking; nouveau
   may fail to bring up EGL. Fallback is llvmpipe at 1080p on 4x A57: slow but usable.
3. **4 GB RAM.** Omarchy's default app set assumes more; the tegra profile has to trim it.
4. **Omarchy update fighting our boot loader.** Its installer and updater own Limine + UKIs; the boot
   step must become a no-op on this machine.
5. **SD card longevity.** Root on SD, zram instead of swap, logs to RAM where sensible.

## Decisions taken

- New SD card; the existing Ubuntu card is only read, never wiped.
- Stock ALARM kernel first; no custom kernel until a DTS fix proves necessary.
- Keep our own boot chain, install Omarchy's desktop layer rather than its boot layer.

## Open questions (for the owner)

- Is the board available to power on with Ethernet and HDMI?
- Spare microSD (16 GB+) and reader, and a USB keyboard for the first Arch boot?

## Port work, not install work

The board is B01 (`nvidia,p3449-0000-b00+p3448-0000-b00`) on L4T R32.6.1. Nothing
upstream declares support for it today, so "installing Omarchy" is really four
pieces of missing platform support. Each is a separate deliverable.

### P1. Kernel and device tree

- Mainline ships `tegra210-p3450-0000.dts` (A02) and `tegra210-p3541-0000.dts`
  (2GB kit). There is **no B01 dev kit tree**, so a B01 DTS has to exist before a
  clean boot claim is possible. `images/mainline-kernel/make-b01-dts.sh` derives it
  from p3450 the way p3541 was derived.
- The ALARM 7.3.4 kernel already carries every driver the board needs, including
  `r8169` for its Realtek PCIe Ethernet and `PCI_TEGRA` for the host bridge.
- These are the only two facts that decide whether a boot is a board-support gap
  or a configuration mistake.

Status: generator written, unbuilt. Needs a kernel build host (the Nano itself can
cross the dtbs natively) and one boot test.

### P2. Userspace

- Arch Linux ARM generic aarch64 is the base Omarchy's ARM path expects. The
  vendor Ubuntu cannot host Hyprland: no `/dev/dri`, X11-only driver, kernel 4.9.
- The Nano's card is a single ext4 partition with `/boot/extlinux` inside it, so
  the image is: GPT, one ext4 root, Arch, kernel, B01 DTB, `extlinux.conf`.

Status: layout known from the live board; image not built.

### P3. Omarchy platform layer

Present and tested in this repo, none of it upstream yet:

- `omarchy/platform-detection/omarchy-hw-aarch64-tegra210` - accepts both Nano
  kits, rejects p3541, GB10, N1x and other Tegra210 boards. Seven fixture cases
  pass with no hardware: `bash omarchy/platform-detection/test-detection.sh`.
- `omarchy/packages/omarchy-aarch64-tegra210.packages` - deliberately short;
  no proprietary NVIDIA userspace on the desktop path.
- `omarchy/installer-hooks/tegra210.sh` - boot ownership set to `extlinux` so an
  Omarchy update can never rewrite the entry, zram sized for 4 GB, renderer
  recorded rather than assumed.

Status: code written and tested offline. Untested inside a real Omarchy install.

### P4. Graphics decision

Unresolved and unresolvable without the board: `drm_tegra` + nouveau vs llvmpipe.
The vendor stack cannot be used, since it exposes no `/dev/dri` at all. The gate is
`hyprctl monitors` reporting a hardware renderer, not a desktop appearing.

### Test vehicle

The card is a test vehicle, not the project. It is the only way to check P1 and P4,
and it must be built so the working card is never written. When the first image
boots, the honest claim is "Arch Linux ARM boots on mainline with a B01 DTB", and
only after Omarchy's platform layer installs is it a port of Omarchy.
