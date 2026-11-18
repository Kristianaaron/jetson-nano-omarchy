# Boot smoke tests

Run in order on the experimental card. Each step records its output under `results/system/`.
A step fails loudly; do not skip ahead.

## S0 - serial console alive

- Connect a 3.3 V TTL adapter, open 115200n8, power on.
- Pass: boot messages appear and reach a login prompt.
- Evidence: `results/system/serial-s0.log`.

## S1 - firmware to kernel handoff recorded

- Grep the serial log for the U-Boot banner, the `Loading Linux`/`Loading FDT` lines, and the kernel
  `Booting Linux on physical CPU`.
- Pass: U-Boot loads the named `Image` and `tegra210-p3450-0000.dtb`, not the vendor pair.
- Evidence: `results/system/boot-chain-s1.log` plus the `extlinux.conf` used.

## S2 - kernel version

- `uname -r` must be the Arch Linux ARM mainline release recorded in the compatibility matrix.
- Pass: exact match, and `dmesg | grep -i tegra` shows DRM/PCIe/SDHCI probes without timeouts.

## S3 - root filesystem

- `findmnt /` shows the expected PARTUUID, mounted read-write.
- Pass: `touch /root/write-test` succeeds; `pacman -Sy` refreshes.
- Evidence: `results/system/rootfs-s3.txt`.

## S4 - network

- `ip -brief address` shows the Realtek NIC with a DHCP lease.
- Pass: `ping -c3 1.1.1.1` and `curl -fsSI https://archlinuxarm.org | head -1`.
- If it fails: `lspci -k` should show whether the PCIe endpoint enumerated and `r8169` bound. That
  distinguishes "no link" from "no driver".

## S5 - display

- `for c in /sys/class/drm/card*/status; do echo "$c $(cat $c)"; done`
- Pass: HDMI shows `connected` with a mode; `modetest -c` or `drm_info` lists it.
- Evidence: `results/graphics/display-s5.txt`.

## S6 - SSH and recovery

- `systemctl status sshd`, log in from the Mac with a key.
- Pass: key-only login works, password auth disabled.
- Then power-cycle and confirm the working card still boots untouched.

## S7 - rollback drill

- Reboot, choose the vendor `l4t` label in U-Boot, confirm the old system boots.
- Pass: both labels boot from the same card; the vendor entry is unchanged.
