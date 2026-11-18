# ADR-002: why the first two cards produced a black screen, and what to test next

- Status: open, hypotheses ranked
- Date: 2026-11-16
- Context: two cards built from Arch Linux ARM + mainline 7.3.4 with the A02 p3450 DTB
  produced the same result: NVIDIA splash, then HDMI loses signal, LED on, no network
  lease, no SSH.

## Facts established on hardware and from sources

1. The bootloader lives in the board's 4 MB QSPI (`TNSPEC ...-jetson-nano-qspi-sd-...`,
   `TEGRA_OTA_BOOT_DEVICE /dev/mtdblock0`). The card carries no bootloader.
2. The vendor boot entry is `LINUX /boot/Image`, `INITRD /boot/initrd`, no `FDT` line,
   `root=/dev/mmcblk0p1`. So the vendor path boots a kernel from p1's `/boot` and gets its
   DTB from somewhere else, which is why the vendor card also ships
   `kernel_tegra210-p3448-0000-p3449-0000-b00.dtb` under `/boot/dtb`.
3. The vendor card has p1..p14. The small partitions are kernel/DTB copies. The first two
   experimental cards kept that layout and only reformatted p1.
4. The vendor stack exposes no `/dev/dri`, so nothing about the vendor stack can host
   Hyprland. That is independent of this failure.

## Hypotheses, most likely first

**H1. The stale kernel partitions won the boot.**
cboot/ U-Boot can boot a kernel partition directly, ahead of `extlinux.conf`. Cards 1 and 2
kept p2..p14 from the vendor image, so a vendor kernel could have been loaded with its root
now pointing at an Arch filesystem, producing a panic with no console. Test: rebuild with a
clean single-partition table (builder changed; not yet booted). If the symptom changes, H1 is
confirmed.

**H2. ext4 features unreadable by the 2016-era bootloader.**
`mke2fs 1.47` defaults (`metadata_csum`, `64bit`, `orphan_file`) postdate this U-Boot. Card 2
was built with the legacy feature set, but H1 was still in play, so this is unproven rather
than excluded. Both fixes are now in the builder.

**H3. The DTB does not match the B01 board.**
Ruled out as the primary cause: both cards used the p3450 tree, which includes
`nvidia,tegra210` and therefore matches. A B01 tree is now built anyway and shipped as the
default, with the vendor filename as an alias.

**H4. The kernel dies before userspace for an unrelated reason.**
Possible: bad initramfs, missing BPMP firmware at probe time, or a mainline regression on
T210. This is the hypothesis that needs a console to distinguish, and it is why a 3.3 V
USB-TTL adapter on the UART is now the recommended purchase.

## What would settle it

- Serial console on UART (`ttyS0`, 115200n8, 3.3 V only). One boot prints cboot/U-Boot
  output, whether extlinux was parsed, the kernel banner, and the first failing driver.
- Vendor-control card: boot the NVIDIA kernel and DTB dumped from the working card through
  our own filesystem and extlinux entry. Boots means our plumbing is fine and mainline is at
  fault; fails means cboot never read our card. Implemented as an optional
  `VENDOR_CARD=` path in the builder.

## Decision

Keep mainline. Fix the card layout (done), keep the legacy ext4 feature set (done), ship the
B01 tree and the vendor DTB alias (done), and do not attempt another blind change until one
of the two tests above produces output.
