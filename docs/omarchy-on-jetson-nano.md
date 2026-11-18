# Omarchy on the Jetson Nano (Tegra210): engineering record

Status as of 2026-11-17. Every claim is labelled **measured** (seen on the board, with the
command or log named) or **inferred** (reasoned, not yet confirmed). This document is the
evidence base for upstream changes; it is not itself a PR.

## 1. Result

Omarchy 4.5.0 runs natively on an original Jetson Nano 4 GB developer kit (B01 carrier):
mainline Linux, Arch Linux ARM userland, Omarchy's own packages, Hyprland, Quickshell shell,
SDDM login. No NVIDIA L4T kernel, no vendor userspace.

| Area | State | Evidence |
|---|---|---|
| Boot (L4T U-Boot from QSPI, extlinux) | works | measured: boots in ~16 s to SSH |
| Kernel | mainline 7.2.11 (Omarchy snapshot) | measured: `uname -r` |
| Storage (SD, ext4) | works, appears as `mmcblk1` | measured: netconsole log |
| Ethernet (RTL8111, r8169) | works, 1 Gbit/s | measured: dmesg "Link is Up - 1Gbps/Full" |
| USB (keyboard, mouse) | works, needs firmware in initramfs | measured: Logitech PRO X detected |
| HDMI output | works, mode forced | measured: 720p, 1080p-class and 2560x1440@60 (312.25 MHz) scan out |
| HDMI hot-plug and EDID | broken | measured: HPD gpio-225 high, EDID 0 bytes, DDC bus silent at 0x50 |
| GPU (GM20B, nouveau) | renders correctly | measured: GBM/EGL clear + readback on nouveau render node = expected pixel |
| GPU through Mesa `tegra` driver | works after the two patches | measured: 1280x720 texture upload/sample/readback on the display device, `GL_MAX_TEXTURE_SIZE` 16384 |
| Desktop rendering | GPU, patched Mesa in `/opt/mesa-tegra` | measured: wallpaper on `omarchy-background`/`owe-background`, `hyprctl layers` |
| Memory clock (EMC) | stuck at 204 MHz of 1600 | measured: debugfs `clk/emc/clk_rate` |
| CPU clock | 1555 MHz, governor performance | measured |
| Fan | works, trip lowered to 38 C | measured: cooling state 1/3 at 44 C |
| Audio, Bluetooth, camera, Wi-Fi | not tested | |
| CUDA | not available on mainline | by design, see ADR-001 |

## 2. Versions

| Component | Version |
|---|---|
| Board | NVIDIA Jetson Nano Developer Kit, P3449-0000-B00 carrier, P3448-0000 module |
| Firmware | L4T R32.6.1 bootloader in QSPI (cboot + U-Boot), unchanged |
| Kernel | `linux-aarch64` 7.2.11-1 (Omarchy stable snapshot of Arch Linux ARM) |
| Mesa | 26.2.5 (snapshot) |
| Omarchy | `omarchy` and `omarchy-settings` 4.5.0-3 from `pkgs.omarchy.org/stable/aarch64` |
| Hyprland / Aquamarine | 0.56.2 / 0.15.1 (snapshot) |
| Device tree | our B01 tree: mainline `tegra210-p3450-0000` with B01 model/compatible |

## 3. Boot chain

The firmware lives in QSPI; the SD card holds only partitions and the root filesystem. U-Boot
reads `/boot/extlinux/extlinux.conf` from partition 1.

Findings, in the order they mattered:

1. **The initramfs must stay under 14 MiB** (inferred from load addresses, consistent with every
   observation). L4T U-Boot loads the ramdisk at `0x83200000` and the kernel at `0x84000000`, so a
   larger initramfs is overwritten by the kernel. Arch's default image was 14.7 MiB; Omarchy's
   generic aarch64 hooks (plymouth, kms, encrypt, btrfs-overlayfs) would make it larger still. The
   working image is 12.4 MB (`HOOKS=(base systemd autodetect modconf block filesystems fsck)`,
   zstd -19). A pacman hook (`jetson-nano-boot-check`) refuses silently-unbootable updates.
2. **`i2c-tegra` must be in the initramfs** (measured). The SD card's I/O rail and the PCIe rails
   come from the MAX77620 PMIC behind Tegra I2C; Arch builds `i2c-tegra` as a module.
3. **Root is `mmcblk1` on mainline** (measured), not `mmcblk0` as on L4T; use `root=LABEL=`.
4. **USB needs `nvidia/tegra210/xusb.bin` in the initramfs** (measured). `xhci-tegra` is built in,
   probes before root is mounted, fails with -2 and never retries.
5. Diagnostic channel without a serial cable: a small initramfs that loads `r8169` and
   `netconsole` and streams the kernel log over UDP (`scripts/make-diag-initramfs.sh`).

## 4. Kernel configuration gaps (Arch Linux ARM `linux-aarch64`)

| Option | State | Effect | Workaround now |
|---|---|---|---|
| `CONFIG_PWM_TEGRA` | not set | `vdd-gpu` pwm-regulator never probes, nouveau never binds the GPU, fan never binds | upstream `pwm-tegra.c` built as a DKMS module |
| `CONFIG_TEGRA210_EMC` | not set | memory stays at the boot rate, 204 MHz of 1600 | none yet |
| `CONFIG_ARM_TEGRA_DEVFREQ` | not set | no memory frequency scaling | none yet |

These belong in Arch Linux ARM's kernel config, not in Omarchy.

## 5. Display

- **Hot-plug and DDC do not work on mainline with this tree** (measured): HPD reads "not
  connected", EDID is empty, `i2cdetect` on the DDC bus (`7000c700.i2c`) finds nothing. The video
  path itself works. The mainline tree routes the DDC pads through `dpaux1` pin control; the
  vendor tree configures them differently (inferred cause, not yet fixed).
- Workaround: `video=HDMI-A-1:<mode>e` on the kernel command line forces the port on, and the
  Hyprland monitor line sets the mode explicitly.
- 2560x1440@60 scans out (measured, 312.25 MHz CVT timing).
- Current choice is **1280x720 output, upscaled by the monitor**, because memory is still at
  204 MHz and the GPU at its lowest clock (sections 6 and 9). This is the monitor's scaler, not
  a reconstruction upscaler.

## 6. GPU and Mesa

- nouveau binds GM20B once `pwm-tegra` is present (measured: "NVIDIA GM20B (12b000a1)").
- **Direct nouveau rendering works** (measured): `tools/mesa-debug/gbmclear.c` on
  `/dev/dri/by-path/platform-57000000.gpu-render` reports renderer `NV12B` and reads back the
  expected pixel `0 255 0 255`.
- **Mesa's `tegra` gallium driver used to crash** (measured 2026-11-17 morning): the same
  program on the display device (`platform-50000000.host1x-card`) loaded renderer `tegra` and
  segfaulted in `libgallium` on the first render. Xorg and Hyprland crashed at the same place.
  Fixed by `tools/mesa-debug/patches/0001-tegra-fixes.patch` (unwrapped resources and surfaces
  in `tegra_context.c`; only hooks the GPU driver implements are forwarded). The optimised
  build is in `/opt/mesa-tegra`; see docs/HANDOFF.md "START HERE".
- Textured rendering now measures correctly through the patched driver (2026-11-17 15:58):
  GLES2 on the display device reports `tegra`, `GL_MAX_TEXTURE_SIZE` 16384, and a 1280x720
  RGBA upload, sample and readback returns the expected pixel.
- GPU clock: nouveau exposes performance states 76 to about 998 MHz; it sits at the lowest. Only
  relevant once rendering uses the GPU.

## 6a. Wallpaper, owe and the shell background (measured 2026-11-17 16:33)

Quickshell's `omarchy.background` service draws still wallpapers; owe draws video and takes the
still over during the startup handoff. Both run on the GPU with the patched Mesa.

After the desktop moved to the patched Mesa, the wallpaper came up black. `hyprctl layers`
showed no `omarchy-background` layer. Two faults:

1. `owed` (owe 0.2.14) runs `omarchy-shell shell setPluginEnabled omarchy.background false`
   when its renderer takes the still. On the observed boots the matching re-enable did not take
   effect: owed logged `shell background enabled` while the service stayed unloaded, and the
   shell reads only the literal `"true"` as enabled (owe's binary also carries
   `"enabled"`/`"disabled"`). With no plugin there was no background layer. The disable
   persisted in `~/.config/omarchy/shell.json` as `"disabledPlugins": ["omarchy.background"]`.
   Fixed with a local edit to `shell.qml`: accept `"enabled"` and never unload
   `omarchy.background`.
2. owe's own upload failed: `GL_MAX_TEXTURE_SIZE` returned 0 in its context
   (`Image exceeds the texture size limit: 1280x720, limit 0`), because owe-render links the
   patched Mesa `libEGL` while its GL entry points come from the system glvnd `libGL`, which
   cannot see that context (`glGetString` returned NULL). Fixed with
   `MESA_GL_VERSION_OVERRIDE=3.1` in an `owed.service` drop-in, which makes owe take the GLES
   fallback that pairs with the patched EGL: journal now shows
   `OpenGL vendor=NVIDIA renderer=tegra version=OpenGL ES 3.2 Mesa 26.2.5` and
   `still loaded ... (1280x720)`.

Verified on a cold boot: plugin enabled, both background layers visible, wallpaper on screen,
idle CPU 0 to 1 jiffy/s. Each change runs only for owe / the shell, not the whole session.
The shell edit is overwritten by an `omarchy` package update; details and rollback are in
docs/HANDOFF.md, section "Wallpaper on the GPU path".

## 7. Software rendering fallback (superseded 2026-11-17 15:35, kept for reference)

Until the Mesa fix landed, every compositor and client used llvmpipe. The desktop now runs the
patched Mesa in `/opt/mesa-tegra`; the software configs remain at `/root/environment.swrast` and
`/root/20-jetson-nano.conf.swrast`. When it was in place, the fallback used:

- `/etc/sddm.conf.d/20-jetson-nano.conf`: greeter compositor and greeter UI get
  `MESA_LOADER_DRIVER_OVERRIDE=kms_swrast`, `LIBGL_ALWAYS_SOFTWARE=1` and
  `AQ_DRM_DEVICES=/dev/dri/by-path/platform-50000000.host1x-card`.
- `/etc/environment`: the same three variables for user sessions.
- `AQ_DRM_DEVICES` uses the by-path name because `card0`/`card1` swap between boots.

This is not acceleration and must never be reported as such.

## 7a. Native glvnd Mesa (2026-11-17 evening, measured)

The patched Mesa used to be loaded by pointing `LD_LIBRARY_PATH` at `/opt/mesa-tegra/lib`, so its
own glvnd-less `libEGL` shadowed the system one. Desktop-GL clients that go through the system
glvnd `libGL` could not see that context (owe reported `GL_MAX_TEXTURE_SIZE` 0), which forced the
GLES override and the shell background patch.

It is now built with `-Dglvnd=enabled` and installed as a glvnd EGL vendor:
- `/opt/mesa-tegra/lib/libEGL_mesa.so.0` plus
  `/opt/mesa-tegra/share/glvnd/egl_vendor.d/50_mesa.json`.
- The session sets `__EGL_VENDOR_LIBRARY_DIRS=/opt/mesa-tegra/share/glvnd/egl_vendor.d`, keeps
  `LD_LIBRARY_PATH=/opt/mesa-tegra/lib` for the patched libgbm/libgallium, and keeps
  `MESA_LOADER_DRIVER_OVERRIDE=tegra`.
- The old glvnd-less `libEGL.so*` and `libGLESv2.so*` were moved to
  `/opt/mesa-tegra/lib/pre-glvnd-shadow/` so they cannot shadow the system dispatch.

Verified: Hyprland reports `Renderer: tegra`, `OpenGL ES 3.2 Mesa 26.2.5`; owe reports
`OpenGL vendor=NVIDIA renderer=tegra version=4.3 (Core Profile) Mesa 26.2.5` with the still
loaded; Quickshell loads the patched libgallium. The `owed` GLES drop-in is removed. Menu and
window latency are unchanged (about 0.7 to 1.2 s and 0.9 s), so this was a correctness change,
not a speed one.

Rollback: the previous environment is at `/root/chain/environment.pre-glvnd` and
`/root/chain/sddm-20.pre-glvnd`; the pre-glvnd prefix is at `/root/mesa-tegra-before-glvnd`.

## 8. Omarchy integration

What was run, in order, and where it deviates from a stock Omarchy install:

1. `omarchy-refresh-pacman stable`, `omarchy-update-keyring`: Omarchy's aarch64 repos and pinned
   Arch Linux ARM mirror. The snapshot downgrades several packages, including the kernel
   (7.3.4 to 7.2.11) and OpenSSL (4.1 to 3.6).
2. **OpenSSL file conflict** (measured): a newer system has `openssl` 4 plus `openssl-3`, which owns
   `libcrypto.so.3`/`libssl.so.3`; the snapshot's `openssl` 3 ships the same files. Resolved with
   `--overwrite` for those two files and `pacman -Rdd --dbonly openssl-3`.
3. `pacman -S omarchy omarchy-settings`, then `omarchy-reinstall-pkgs` as the user.
4. `omarchy-apply-system` stages run in the same order, **minus `install/config/snapper.sh`**,
   which needs a btrfs root (this card is ext4). The runner stops at the first failing step, so
   the stage cannot run unmodified on ext4.
5. **mkinitcpio ordering** (measured risk): `omarchy-settings` installs
   `/etc/mkinitcpio.conf.d/00-omarchy-hooks.conf`. Our board config is named
   `zz-jetson-nano.conf` so it loads last and keeps the initramfs small.
6. `omarchy-reinstall-configs` calls `omarchy-refresh-limine`, which fails on a system without
   Limine and aborts the rest; its other steps were run individually.
7. **SDDM remembered user** (measured): Omarchy's theme logs in as `userModel.lastUser`. On a system
   that never had a login, `/var/lib/sddm/state.conf` is missing and the login is attempted with an
   empty user name ("User not known to the underlying authentication module"). The ISO path sets
   this up through `omarchy-provision-owner`; an install onto an existing system does not.
8. **Startup cover polling** (measured, performance): `services/BackgroundIntro.qml` runs
   `owe render-status` every 16 ms while the startup cover is up. With a still wallpaper the
   status is never "video", so the cover waits for the 10 s fallback; on a slow CPU the poll keeps
   Hyprland at 190 to 270% CPU (0% with the shell paused). It settles once the cover lifts.
9. Monitor without EDID: Omarchy's `monitors.lua` default (`mode = "preferred"`, `scale = "auto"`)
   picks 1024x768 at scale 2. A per-connector line fixes it.

## 9. Performance (measured)

| Situation | Hyprland CPU | Shell CPU |
|---|---|---|
| 2560x1440, effects on, startup cover up | 190-274% | 48-61% |
| Shell paused (control) | 0% | 0% |
| 1280x720, blur/shadows/animations off, settled | 0% | 0% |

Measured 2026-11-17 16:40 to 16:55, after the wallpaper fix:

- **Rendering path:** Aquamarine logs `Renderer: tegra` and `Using: OpenGL ES 3.2 Mesa 26.2.5`;
  Hyprland and Quickshell both load `/opt/mesa-tegra/lib/libgallium`, and Quickshell runs a
  `QSGRenderThread`. The desktop composites on the GPU, not llvmpipe.
- **GPU clock:** pstate `01` (76 MHz) when idle. The governor steps to `0d` (998 MHz) after about
  2 s of load, so the first window open after an idle period pays 76 MHz frame times.
- **720p fill:** one full-screen textured quad through the tegra driver takes 5.6 ms at 998 MHz
  (179 fps). The same frame at 76 MHz is about 70 ms, which is the first-interaction cost.
- **Window open:** `foot` maps in about 500 ms with 250 to 300 ms of Hyprland CPU. Idle CPU is 0.
- **Memory:** EMC is fixed at 204 MHz of 1600 (no `CONFIG_TEGRA210_EMC`).
- **Stability limit:** sustained 998 MHz load with EMC at 204 MHz times the nouveau channel out
  (`nv50cal_space: -110`, "kernel rejected pushbuf"). Temperatures stayed at 35 C, so this is a
  memory/clock limit, not thermal. Fix the EMC clock before pinning or raising the GPU clock.
- **Cursor and damage tracking:** the hardware cursor plane produced movement artifacts, so
  `cursor:no_hardware_cursors = 1` in `~/.config/hypr/looknfeel.lua` draws the cursor in the
  composited frame instead. With full per-region damage tracking, a lag spike with a window
  open then left black rectangles trailing the pointer, so the same file now also sets
  `debug = { damage_tracking = 1 }` (monitor-level: any change redraws the whole output).
  Idle CPU stays 0; a window open costs 47 jiffies of compositor CPU instead of 26.
- **Menu and overlay opens (measured with `QSG_RENDER_TIMING=1` on the shell):** the shell's Qt
  renderer time is 0 to 1 ms per frame, but `eglSwapBuffers` blocks for 29 to 220 ms and the
  menu takes about 0.7 to 1.2 s to appear. The cause is presentation, not QML: Omarchy's
  `OverlayWindow` maps a fresh full-screen surface on each open and paints a full-screen dim
  scrim, and the compositor presents each full-screen frame at the 76 MHz idle clock. A
  full-screen composite is about 5.6 ms at 998 MHz and about 70 ms at 76 MHz. Warming the GPU
  with window opens first does not help, because the governor drops back to 76 MHz before the
  menu opens. Skipping the redundant `Hyprland.refreshMonitors()` on open changed nothing and
  was reverted. `QSG_RENDER_TIMING` was set on the shell through
  `omarchy-launch-shell` for the measurement and removed afterwards.
- **GPU devfreq minimum (2026-11-17):** `/sys/class/devfreq/57000000.gpu` exposes the
  `simple_ondemand` governor with 76.8 to 998.4 MHz. `jetson-gpu-min-clock.service` holds a
  537.6 MHz minimum. At 537.6 MHz idle the GPU sits at 43 C with no errors and the governor
  still ramps to 998 MHz under load. The minimum did not reduce window or menu latency (window
  map about 600 ms, menu 0.6 to 1.2 s) because the governor ramps during the event; the
  remaining cost is userspace (overlay surface map, QML) and app startup.
- **EMC blocked:** the mainline `tegra210-emc` driver requires a bootloader-provided timing
  table in reserved memory (`of_reserved_mem_device_init_by_name(..., "nominal")`). The vendor
  bootloader does not publish one in that format and the vendor DTB has the timings in the
  vendor DT binding, so enabling `CONFIG_TEGRA210_EMC` alone fails to probe. Source for
  7.2.11 is in `/root/kbuild/linux-7.2.11` if this is picked up.
- **Implication:** the GPU clock minimum is in place, but the menu and window-open latency is
  dominated by userspace: the full-screen overlay surface is remapped on every menu open and
  monitor-level damage redraws full frames. The EMC port remains the kernel-side item for
  memory-bound work.

Remaining limits, largest first: memory at 204 MHz (the prerequisite for a faster GPU clock),
the GPU idle clock and its slow ramp, then app startup. The Mesa `tegra` driver crash is fixed
(section 6); the desktop renders on the GPU.

## 10. Reproducing

- Card: `scripts/build-sd-image-mac.sh` (vendor boot region, Arch rootfs, owners restored with
  `scripts/ownership-commands.py`, diagnostic initramfs).
- Then `omarchy/nano/provision-nano.sh` on the board: staged and re-runnable, uses the captured
  config files in `omarchy/nano/files/`. **Status: written by a coding agent, under review, not yet run on
  a fresh card.**

## 11. Upstream candidates

Split by project. "Ready" means evidence exists and the change is small; nothing has been sent.

### Omarchy (github.com/omacom/omarchy)

| Change | Ready? |
|---|---|
| `bin/omarchy-hw-aarch64-tegra210` detection (already in this repo with fixture tests) | yes, needs rebase on 4.5 |
| `install/hardware/tegra210.sh`, wired into `install/hardware/all.sh` | needs rework against 4.5 layout |
| `00-omarchy-hooks.conf`: a Tegra210 case (or platform-owned) that keeps the initramfs small | yes, evidence in section 3 |
| `install/config/snapper.sh`: skip cleanly on non-btrfs roots | yes |
| `omarchy-reinstall-configs`: skip Limine refresh when the platform does not use Limine | yes |
| Existing-system install: write SDDM `state.conf` with the install user | yes |
| `BackgroundIntro.qml`: back off the 16 ms `owe render-status` poll, or lift the cover for a ready still | yes, generic, helps every slow device |
| SDDM/session software-GL policy for Tegra210 | only until the Mesa fix; prefer not to upstream a workaround |

Before opening anything: read Omarchy's `AGENTS.md`/`CLAUDE.md` and contribution rules, one
concern per commit, an install receipt from a fresh card, and the feature matrix in section 1.

### Elsewhere

| Project | Change |
|---|---|
| Arch Linux ARM | enable `CONFIG_PWM_TEGRA`, `CONFIG_TEGRA210_EMC`, `CONFIG_ARM_TEGRA_DEVFREQ` |
| Mesa | `tegra` gallium driver crash on Tegra210 (report with backtrace; patch if found) |
| Linux device tree | B01 HDMI hot-plug and DDC; EMC timing table for the Nano |
| Omarchy owe / shell | see the polling item above |

## 12. Open items

1. Mesa `tegra` crash: backtrace, fix, then remove the software fallback and measure GPU rendering.
2. Memory clock: kernel with `TEGRA210_EMC` plus the 1600 MHz timing table from the vendor tree.
3. HDMI hot-plug and EDID on mainline.
4. Fresh-card run of `provision-nano.sh` as the reproducibility test.
5. Change the default account passwords (owner action).
6. Audio, Bluetooth, Wi-Fi, camera: untested.

## Credits

Mainline Tegra210 support in Linux, nouveau and Mesa is the work of their upstream
maintainers; `pwm-tegra.c` is NVIDIA's (GPL-2.0-or-later) and is built unmodified. Omarchy is by
Basecamp and its contributors. This port adds board configuration and fixes, not drivers.
