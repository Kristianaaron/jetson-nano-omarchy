# Native rebuild plan (2026-11-18)

Goal (owner, 2026-11-18): the OS runs light and snappy on the Nano with clocks set correctly,
natively, with no workarounds patched over fundamental issues. Kernel and driver optimised.

## Incident this morning (measured)

The board stopped booting after a cold power-on. Cause: ext4 block-bitmap corruption
(`ext4_mb_generate_buddy`, EFSCORRUPTED, first error 2026-11-17 23:50:11), five minutes after
the card was edited offline with `debugfs` from the Mac (`/tmp/restore-ddci2c.sh`, 23:45).
Every boot since then stopped in the initramfs fsck before mounting root. Fixed with
`e2fsck -f -y` on the Mac. Rule from now on: change the card only on the running system;
after any offline edit run `e2fsck -f` before booting.

The EMC 1600 MHz switch was disabled for the diagnosis and stays disabled until item 2 lands
(backups of the two files in results/emc-coldboot-backup/, blacklist in
/etc/modprobe.d/jetson-emc-diag.conf on the board).

## Workarounds on the board and their proper replacements

| Workaround (as found 2026-11-18) | Replacement | Item |
|---|---|---|
| /etc/environment and SDDM: LD_LIBRARY_PATH=/opt/mesa-tegra, __EGL_VENDOR_LIBRARY_DIRS, MESA_LOADER_DRIVER_OVERRIDE, LIBGL_ALWAYS_SOFTWARE | system `mesa` package with the tegra fixes (packaging/mesa-tegra) | 1 |
| AQ_FORCE_LINEAR_BLIT=1, Chromium GPU process crash, black/transparent tiles | root-cause in the tegra wrapper or nouveau, fix in the driver | 1b |
| pwm-tegra DKMS, tegra210-emc.ko in extra/ | own kernel package `linux-nano` (ALARM 7.2.11 + Tegra210 config) | 2 |
| static trained EMC table (one boot's values in emc-board.dtsi) | per-boot table read from the bootloader DT in RAM, validated, safe fallback | 2 |
| jetson-gpu-min-clock / jetson-emc-min-clock services | devfreq governors (GPU simple_ondemand tuned; EMC via actmon) | 3 |
| drm.edid_firmware=...aorus.bin, video=HDMI-A-1:...e, NvClkMode (no effect) | HDMI DDC and hot-plug fixed in the device tree | 4 |
| clk_ignore_unused pd_ignore_unused | remove (early-diagnosis leftovers; keep unused clocks and domains powered) | 5 |
| 3 altered omarchy files (shell.qml ...), owed and shell drop-ins | untouched packages; fixes carried as upstream-ready patches | 5 |
| jetson-nano-selfcheck.service | remove (one-off) | 5 |

## Progress (2026-11-18 13:40, measured)

- DONE Mesa system package `1:26.2.5-1.2` (packaging/mesa-tegra): three tegra wrapper fixes
  (surface unwrap, unimplemented hooks, clear scissor dropped). The scissor fix cured the
  Chromium black/white/transparent tiles and the Hyprland black trails. All Mesa env overrides,
  AQ_FORCE_LINEAR_BLIT, damage_tracking=1 and no_hardware_cursors removed. chrome://gpu:
  compositing, rasterization, canvas, WebGL hardware accelerated (video decode software: no
  mainline NVDEC driver for GM20B).
- DONE omarchy `4.5.0-3.1` (packaging/omarchy-nano): official package + agent collectors as
  cached modules behind launchers and low-priority refresh (tools/omarchy-pkg/agent-usage-perf.py,
  upstream form 0001-agent-usage-perf.patch, 23/23 collectors give identical output) + the
  shell background fix (0002). An earlier Panel.qml edit (no refresh on open) dropped: upstream
  behaviour restored. `pacman -Qkk omarchy`: 0 altered files. Pacman hook
  /etc/pacman.d/hooks/90-omarchy-pycache.hook compiles Omarchy's Python on install/upgrade.
- Login to settled desktop 56 s -> 22 s. New Chromium window ~1.0 s (412 ms launcher hand-off).
- INTERIM EMC 1600 MHz via /usr/local/bin/jetson-emc-raise (try-once marker) until item 2.
- The 2026-11-18 boot failure was ext4 damage from offline debugfs edits, not EMC.

## 1. Mesa system package (done)

`packaging/mesa-tegra/PKGBUILD`: same name, epoch and version as ALARM's mesa, pkgrel 1.1;
release tarball pinned by sha256 and verified by the release manager's GPG key;
`0001-tegra-fixes.patch` in prepare(); drivers tegra,nouveau,softpipe; x11+wayland with GLX
(parity with the stock package, which ships libGLX_mesa for Xwayland apps); glvnd; no LLVM.
Plain meson (arch-meson forces auto features this board cannot build). Configure verified
2026-11-18 11:50: 212 targets, GLX+EGL+GBM, glvnd enabled.
Install with pacman -U; rollback: the cached stock 1:26.2.5-1 package. Then remove every
Mesa variable from /etc/environment and 20-jetson-nano.conf, and delete /opt/mesa-*.

## 1b. Chromium tiles and the linear-blit override

Reproduce with AQ_FORCE_LINEAR_BLIT removed: Learn page, select text, hover the nav. Capture
the Chromium GPU process crash with the debug build (tools/mesa-debug), fix in the driver.

## 2. Kernel package linux-nano

ALARM linux-aarch64 7.2.11 recipe (the Omarchy snapshot version) with a config fragment:
CONFIG_PWM_TEGRA=y, CONFIG_TEGRA210_EMC=y, CONFIG_ARM_TEGRA_DEVFREQ=y, CONFIG_PM_DEVFREQ
governors. Trimmed with localmodconfig against the modules the running board uses so it
builds in hours, not a day.

EMC timings, per boot: the bootloader trains DRAM on every boot and leaves its kernel DT in
RAM at 0x83100000 (verified by the earlier read-only dump, /root/cboot-dt.bin). U-Boot loads
our DT at 0x83000000 (about 110 KB), so that blob survives. Design:
- our DT reserves the region (no-map) and points the EMC node at it;
- the driver validates it (FDT magic, size bound, a tegra21-emc node, every table
  `nvidia,trained = 1`, revision and ram code match) and only then parses the tables with
  the vendor-binding parser from /root/emc/emc-driver.patch;
- on any failure it logs why and stays at the bootloader rate (204 MHz). No static trained
  values anywhere.

## 3. Clock governors

GPU: devfreq simple_ondemand with tuned upthreshold/downdifferential (sysfs via a udev rule,
the standard place for device policy), no min-clock service. EMC: actmon-driven devfreq.

## 4. HDMI

Fix DDC pinmux/dpaux and the hot-plug GPIO in the B01 device tree so EDID is read; remove the
EDID firmware and video= forcing.

## 5. Cleanup

Drop leftovers listed above; Omarchy changes become patches in omarchy/ for the upstream PR.
