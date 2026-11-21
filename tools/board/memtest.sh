#!/bin/bash
# memtest.sh: a memory hog in the user's app.slice vs. compositor responsiveness.
export XDG_RUNTIME_DIR=/run/user/1000
sig=$(ls -t $XDG_RUNTIME_DIR/hypr | head -1)
U() { runuser -u omarchy -- env XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR HYPRLAND_INSTANCE_SIGNATURE=$sig "$@"; }
hpid=$(pgrep -x Hyprland)
since=$(date "+%Y-%m-%d %H:%M:%S")
U systemctl --user reset-failed memhog >/dev/null 2>&1
U systemd-run --user --unit=memhog --slice=app.slice -p MemoryMax=3200M -p MemorySwapMax=3G \
  python3 -c '
import time
chunks = []
while True:
    b = bytearray(60 * 1024 * 1024)
    for i in range(0, len(b), 4096): b[i] = 1
    chunks.append(b)
    time.sleep(1)
' >/dev/null 2>&1
worst=0; n=0; slow=0
for i in $(seq 1 120); do
  t0=$(date +%s%N); U hyprctl monitors >/dev/null 2>&1; t1=$(date +%s%N)
  ms=$(( (t1 - t0) / 1000000 )); n=$((n+1)); (( ms > worst )) && worst=$ms; (( ms > 250 )) && slow=$((slow+1))
  if ! U systemctl --user is-active -q memhog; then break; fi
  sleep 0.5
done
U systemctl --user stop memhog >/dev/null 2>&1
echo "compositor replies: $n, worst ${worst} ms, slower than 250 ms: $slow"
echo "Hyprland same pid: $([[ $(pgrep -x Hyprland) == $hpid ]] && echo yes || echo NO)"
journalctl --since "$since" --no-pager 2>/dev/null | grep -E "systemd-oomd.*Killed|Out of memory: Killed|memhog.*(oom|Failed|Deactivated)" | cut -c1-200 | head -5
free -m | sed -n 2,3p
