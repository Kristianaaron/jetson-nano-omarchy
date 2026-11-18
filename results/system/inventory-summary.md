# Inventory result, first real capture

Device: `baseline-20260530T141349Z.txt`, collected 2026-05-30T14:13Z over SSH through a USB
jump host. Read-only; nothing was installed or changed.

## Headline facts

| Fact | Value |
|---|---|
| Model string | `NVIDIA Jetson Nano Developer Kit` |
| Compatible | `nvidia,p3449-0000-b00+p3448-0000-b00 nvidia,jetson-nano nvidia,tegra210` |
| Board revision | **B01** carrier (P3449-0000-B00), not the A02 P3450 the brief assumed |
| OS | Ubuntu 20.04.6 LTS (Qengineering image) |
| L4T | R32.6.1, `nvidia-l4t-core` 32.6.1-20210726122000 |
| Kernel | `4.9.253-tegra` |
| Power mode | MAXN, fan control not configured |
| Thermals at idle | CPU 37 C, GPU 37 C, PMIC 50 C |
| Root device | `/dev/mmcblk0p1`, ext4, single partition |
| Boot entry | `/boot/extlinux/extlinux.conf`, `LINUX /boot/Image`, `INITRD /boot/initrd`, single `primary` label |
| Display nodes | `/dev/nvhost-*` present, **no `/dev/dri`** (vendor nvhost stack, no DRM/KMS) |
| Ethernet | eth0 link up (carrier 1, r8168), but NetworkManager state `disconnected`, no IPv4 |
| USB gadget | `l4tbr0` <lan-ip>, rndis0/usb0 up, reachable from the USB host |
| Tailscale | installed, `tailscaled` active, logged out, no DNS resolution |
| CUDA | not in the report's cuda section (nvcc not on PATH for this shell) |

## What this changes

1. **The board is B01, not P3450.** Mainline ships `tegra210-p3450-0000.dts` (A02) and
   `tegra210-p3541-0000.dts` (2GB kit) and no B01 devkit DTS, so the first boot experiment runs the
   p3450 DTB on B01 hardware. Functionally close (same SoC wiring for display, USB, SD, PCIe), but it
   is a compatibility mismatch worth its own upstream DTS patch derived from p3450, the way p3541 was.
2. **Single-partition layout confirmed.** `root=/dev/mmcblk0p1` and `/boot` inside it. The installer's
   `single` branch is the one that will run.
3. **No DRM/KMS on the vendor stack.** `/dev/dri` is absent, which independently confirms that
   Hyprland cannot run on this software stack. It does not affect mainline, which has `DRM_TEGRA`.
4. **Networking is a NetworkManager profile problem, not a cable problem.** eth0 has carrier and the
   r8168 driver bound; NM simply has no connection activated for it.

## Not collected

- `nvcc --version` / `nvidia-smi` output (needs the CUDA environment in that shell).
- `tegrastats` trace (script ran it; file stays on the device).
- Card model and capacity in the visible tail of the report (present in the file's storage section).

## Second capture, after networking came up

- Reachable over a VPN (address and user redacted).
  Earlier the board also held DHCP `<lan-ip>/22` on eth0, so the router port was fine and only the
  NetworkManager profile had been inactive.
- Card: `/dev/mmcblk0p1` 119 G total, 26 G used, 89 G free. The disk carries the L4T partition set
  (`p1`..`p14`), so the bootloader area and the GPT layout are the vendor's.
- zram swaps: `zram0`..`zram3`, about 495 M each, 1.9 G total, 140 M in use at idle.
- Memory at idle: 3.9 GiB total, 1.6 GiB used, 2.4 GiB available, 1.0 GiB buff/cache.
- CUDA: `/usr/local/cuda-10.2`, `V10.2.300`, `cuda_10.2_r440.TC440_70.29663091`. Not on `PATH` by
  default in a plain SSH shell.
- `tegrastats`: CPU idles at 102 MHz and bursts to 1479 MHz, `EMC_FREQ 0%`, `GR3D_FREQ 0%` at idle;
  CPU 40.5 C, GPU 41 C, PMIC 50 C.
- No external disk is attached, so the 1 TB SATA drive from the brief is not connected right now.
