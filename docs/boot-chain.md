# Boot chain: Jetson Nano 4GB (P3450)

Nothing in this document has been confirmed on the board yet. Every "unknown" is a check for
Phase 0 (see `hardware/inventory.sh`). Do not act on the assumptions below until the checks pass.

## What is known from sources

- Tegra210 boot ROM loads a bootloader from the microSD card; this dev kit has no eMMC.
- The L4T SD image places the bootloader in raw sectors at the start of the card, then a GPT with the
  root filesystem.
- `cboot` hands off to U-Boot, and U-Boot reads `extlinux.conf` from the root filesystem's `/boot`
  (ext4, so U-Boot's ext4 driver is what parses it).
- Two plausible layouts on the Qengineering Ubuntu 20.04 card: a single ext4 APP partition with
  `/boot` inside it, or a FAT boot partition plus a separate root. `scripts/install-nano.sh` detects
  which one it is before touching anything.

## What must be measured (Phase 0)

| Question | Check |
|---|---|
| Board and module revision | `tr -d '\0' < /proc/device-tree/model`, `compatible`, photos of labels |
| Which card and partition holds `/` | `findmnt /`, `lsblk -o NAME,SIZE,FSTYPE,PARTUUID,MOUNTPOINTS` |
| Where `extlinux.conf` lives | `test -f /boot/extlinux/extlinux.conf` and `lsblk` of that partition |
| Which kernel and DTB boot today | `uname -r`, `cat /boot/extlinux/extlinux.conf`, `grep -i fdt` |
| Kernel command line from firmware | `cat /proc/cmdline` |
| Whether cboot or U-Boot is in the chain | U-Boot banner on serial during boot; `dmesg | head` |
| Bootloader location | card raw sectors vs QSPI: inspect the card image's first sectors on a host |
| Serial console wiring | 3.3 V TTL on UART, 115200n8, log captured before and after any change |

## Serial console

- Use a **3.3 V** TTL adapter only. Never feed 5 V into the UART header.
- B01 carrier: the boot console is on header J50, pin 4 = TXD, pin 3 = RXD, pin 7 = GND (A02
  carriers use J44). The 40-pin header's pins 8/10 are `ttyTHS1` and carry no boot output.
- Capture with `picocom -b 115200 /dev/ttyUSB0` or `screen /dev/ttyUSB0 115200`; save the log to
  `results/system/serial-before.log` before any boot change.
- The console is the recovery path of last resort. No boot experiment proceeds without it.

## Backup and restore

1. Power off cleanly, remove the card, image it on a Linux host:
   `dd if=/dev/sdX of=nano-known-good-$(date +%F).img bs=4M status=progress conv=fsync`
2. Record `sha256sum` of the image in `results/system/`.
3. Restore test onto a **different** card: `dd` back, boot it, confirm the login screen and SSH.
4. Only then start experiments on a third card, or on the second card once it is proven.

Nothing in this repository writes to the working card. The installer clones it read-only from the
running system and writes only to a card the operator names explicitly.

## Boot entry contract for experiments

The experimental card keeps NVIDIA's bootloader byte-identical and adds one `extlinux.conf` entry:

```
LABEL arch-nano
      LINUX /Image
      INITRD /initramfs-linux.img
      FDT /tegra210-p3450-0000.dtb
      APPEND root=PARTUUID=<root-uuid> rw rootwait console=tty0 console=ttyS0,115200n8
```

The old entry is preserved beside it as `extlinux.conf.l4t-backup` so U-Boot can still boot the
vendor kernel from the same card.

## Rollback

- Selecting the old label in U-Boot's menu returns to the vendor system.
- If U-Boot's menu is unreachable, swap back the known-good card. That card is never modified, so
  rollback does not depend on software.

## Confirmed on this board (2026-11-16)

- `TNSPEC 3448-400-0000-F.0-1-0-jetson-nano-qspi-sd-mmcblk0p1`
- `COMPATIBLE_SPEC 3448-300-0000--1--jetson-nano-devkit-`
- `TEGRA_OTA_BOOT_DEVICE /dev/mtdblock0`, `TEGRA_OTA_GPT_DEVICE /dev/mtdblock0`
- `/proc/mtd`: a single 4 MB `spi32766.0` device
- Vendor device tree in use: `kernel_tegra210-p3448-0000-p3449-0000-b00.dtb`
- Vendor `extlinux.conf` has no `FDT` line and passes `${cbootargs}`

Consequence: the card does not need cboot or U-Boot. It needs an ext4 root with
`/boot/extlinux/extlinux.conf`, and because the vendor DTB lookup path is not what the
extlinux `FDT` line says, the card ships the B01 tree under both the upstream name and the
vendor `kernel_*.dtb` name.

## Vendor card layout

`p1` is the 127.8 GB ext4 APP partition holding `/boot`; `p2`..`p14` are small vendor
partitions. On an experimental card those small partitions are a hazard: cboot/U-Boot can
boot them directly and bypass `extlinux.conf`. `scripts/build-sd-image-mac.sh` therefore
wipes to a single partition.
