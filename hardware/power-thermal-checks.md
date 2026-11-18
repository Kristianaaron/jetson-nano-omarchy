# Power and thermal checks

## Power

- Barrel jack J25: 5 V, 4 A recommended for full clocks. Micro-USB 5 V/2 A limits the board and is
  not a benchmark configuration.
- Verify the supply under load, not only at idle: `tegrastats` reports board power where available.
- On the vendor BSP, `nvpmodel -q` names the power mode; record it with every benchmark. Mainline has
  no nvpmodel equivalent, so CPU/GPU clock behaviour there must be measured, not assumed.

## Cooling

- Active cooling (fan on the heatsink) for anything sustained: compositor sessions, kernel builds,
  inference runs.
- Record thermal zones at idle, at steady state, and the peak, with the ambient temperature.

## What to capture before and after each experiment

```sh
timeout 6s tegrastats --interval 1000
for z in /sys/class/thermal/thermal_zone*; do
  [ -e "$z/temp" ] && echo "$(cat $z/type) $(cat $z/temp)"
done
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq
```

## Failure modes to watch

- Brown-out reboots under load usually mean the supply, not the kernel. Check before chasing software.
- Thermal throttling shows as falling clocks with rising temperatures; a slow run during throttling is
  not a performance result.
- On a 4 GB board, memory pressure can look like a hang: check `dmesg` for the OOM killer before
  blaming the compositor.
