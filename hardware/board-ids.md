# Board identification

## What the brief says, and what to confirm

| Identifier | Meaning | Confirm with |
|---|---|---|
| P3450 | 4GB developer kit carrier board (A02 kit), the "p3450" name in this project | `tr -d '\0' < /proc/device-tree/compatible`, plus the silkscreen photo |
| P3448-0000 | Nano module (4GB, A02) on that kit | module label under the heatsink bracket |
| P3449 | Carrier board family used for the B01 kit | only relevant if the labels say B01 |
| P3541 | 2GB developer kit; patches for it derive from p3450 in mainline | should not match this board |

Mainline ships `tegra210-p3450-0000.dtb` for this kit. Do not silently swap in a p3448/p3449 DTB: the
display, regulator and PCIe wiring differ per carrier.

## Checks

```sh
tr -d '\0' < /proc/device-tree/model; echo
tr '\0' '\n' < /proc/device-tree/compatible
cat /etc/nv_tegra_release            # vendor BSP only; absent on Arch
cat /proc/cmdline
```

Expected model string: `NVIDIA Jetson Nano Developer Kit`. Compatible strings: `nvidia,p3450-0000`
then `nvidia,tegra210`.

## Power and cooling before any benchmark

- 5 V, 4 A through the barrel jack (J25) for full performance; micro-USB power is limited and is for
  flashing/desk use only.
- Active cooling on the heatsink for any sustained GPU or CPU load. Thermals are part of the
  benchmark receipt, not an afterthought.
- Record the supply used and the thermal zone readings at idle and under load.

## Revision risk

The original kit shipped in A02 and B01 variants; modules differ (P3448-0000 vs P3448-0002). The
device-tree compatible string is the authority. If it does not match `nvidia,p3450-0000`, stop and
redo the DTB choice before any boot experiment.
