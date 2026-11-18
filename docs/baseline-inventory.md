# Baseline inventory

Collected by `hardware/inventory.sh`. Output goes to `$HOME/nano-inventory/baseline-<utc>.txt` and is
redacted (MACs, IPs, SSIDs, hostname). Copy only the redacted report into `results/system/`.

## Why each field matters

| Field | Feeds |
|---|---|
| `model`, `compatible` | confirms P3450/P3448-0000 and selects the DTB |
| `nv_tegra_release`, `nvidia-l4t-*` | pins the vendor BSP for the inference path |
| `uname -r`, `/proc/cmdline` | baseline kernel and firmware cmdline |
| `lsblk`, `findmnt /`, PARTUUIDs | proves the card layout and that `/boot` is where it seems |
| `/boot/extlinux/extlinux.conf` | the actual boot contract; the file the experiment must preserve |
| `/sys/class/drm/*/status` | whether a display is attached and sensed |
| `free`, `/proc/swaps`, zram | the 4 GB budget, before Omarchy exists |
| `thermal_zone*` | cooling headroom baseline |
| `nvcc --version`, `nvidia-smi` | the CUDA 10.2 reference for the inference track |
| `tegrastats` 6 s capture | idle clocks, power, memory, GPU utilisation |

## Not collected yet

No device access at the time of writing. `results/baseline-inventory.md` stays empty until a real
capture exists; an invented baseline is worse than none.

## Handling

- The raw report stays on the device or the owner's machine.
- Only the redacted copy is committed, and only with the board model and dates visible.
- Package lists and `dmesg` excerpts go in `results/system/` with the same redaction.
