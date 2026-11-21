#!/bin/bash
# lookbench.sh LABEL HL_EVAL: apply a Hyprland config live, run 40 workspace switches over ~8 s,
# report mean/max GPU load (nvgpu 'load', 0-1000), GPU clock, and Hyprland CPU seconds used.
export XDG_RUNTIME_DIR=/run/user/1000
sig=$(ls -t $XDG_RUNTIME_DIR/hypr | head -1)
H() { runuser -u omarchy -- env XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR HYPRLAND_INSTANCE_SIGNATURE=$sig hyprctl "$@"; }
G=$(ls -d /sys/devices/platform/*57000000.gpu* 2>/dev/null | head -1); [[ -f $G/load ]] || G=/sys/devices/platform/57000000.gpu
H eval "$2" >/dev/null 2>&1; sleep 1
pid=$(pgrep -x Hyprland | head -1); t0=$(awk '{print $14+$15}' /proc/$pid/stat)
( for i in $(seq 1 40); do H eval "hl.dispatch(hl.dsp.focus({ workspace = \"$(( i % 2 + 1 ))\" }))" >/dev/null; sleep 0.2; done ) &
n=0; sum=0; max=0; fmax=0
for i in $(seq 1 40); do l=$(cat $G/load); f=$(cat /sys/class/devfreq/57000000.gpu/cur_freq); sum=$((sum+l)); n=$((n+1)); (( l > max )) && max=$l; (( f > fmax )) && fmax=$f; sleep 0.2; done
wait
t1=$(awk '{print $14+$15}' /proc/$pid/stat)
H eval "hl.dispatch(hl.dsp.focus({ workspace = \"1\" }))" >/dev/null
echo "$1: gpu load mean $((sum/n/10))% max $((max/10))%  gpu clock max $((fmax/1000000)) MHz  Hyprland CPU $(( (t1-t0) ))/100 s over 8 s"
