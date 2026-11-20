#!/usr/bin/env bash
# g2-xstress.sh N: run the cross-process render/import/check (g2-xproc.c) N times at 1280x720 and
# count the runs with wrong pixels. Needs the desktop environment file from g2-desktop-env.sh.
# Run as root (pidfd_getfd on the exporter).
cd "$(dirname "$0")"
E=$(grep -v "^$" /run/environment.d/90-g2-nvgpu-desktop.conf | grep -v ZINK_DEBUG | tr "\n" " ")
[[ -x xproc_1280 ]] || gcc -O2 -DW=1280 -DH=720 -o xproc_1280 g2-xproc.c $(pkg-config --cflags --libs egl glesv2 gbm libdrm)
N=${1:-20}; bad=0
for i in $(seq 1 $N); do
  env $E CLIENT=1 ./xproc_1280 > /tmp/xs.out 2>&1 & cp=$!
  for t in $(seq 1 40); do grep -q "CLIENT pid" /tmp/xs.out && break; sleep 0.5; done
  L=$(grep "CLIENT pid" /tmp/xs.out); set -- $L
  r=$(env $E FROM_PID=$3 FROM_FD=$5 FROM_MOD=$7 FROM_STRIDE=$9 timeout 60 ./xproc_1280 2>&1 | grep -oE "[0-9]+ of [0-9]+ pixels wrong")
  kill $cp 2>/dev/null; wait $cp 2>/dev/null
  echo "run $i: ${r:-no result}"; [[ ${r%% *} == 0 ]] || bad=$((bad+1))
done
echo "runs with wrong pixels: $bad of $N"
