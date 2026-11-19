#!/usr/bin/env bash
# Build the device tree for the linux-nano boot entry: the board's live device tree (with its
# EMC timing tables and display changes) plus the nvmap node in b01/nvmap-carveouts.dtsi.
# Writes a separate file, so the stock boot entry keeps its own device tree.
# Usage (on the Nano, as root): make-nano-dtb.sh [IN_DTB] [OUT_DTB]
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
in=${1:-/boot/tegra210-p3448-0002-p3449-0000-b00.dtb}
out=${2:-/boot/tegra210-p3448-0002-p3449-0000-b00-nano.dtb}
command -v dtc >/dev/null || { echo "needs dtc (pacman -S dtc)" >&2; exit 1; }
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
dtc -q -I dtb -O dts -o "$tmp/live.dts" "$in"
cat "$tmp/live.dts" "$here/b01/nvmap-carveouts.dtsi" > "$tmp/nano.dts"
dtc -q -I dts -O dtb -o "$tmp/nano.dtb" "$tmp/nano.dts"
# The result must hold the new node and be otherwise identical to the input.
dtc -q -I dtb -O dts "$tmp/nano.dtb" | grep -q 'compatible = "nvidia,carveouts"'
extra=$(diff <(dtc -q -I dtb -O dts "$in") <(dtc -q -I dtb -O dts "$tmp/nano.dtb") | grep '^[<>]' \
  | grep -v -E '^>[[:space:]]*(tegra-carveouts \{|compatible = "nvidia,carveouts";|status = "okay";|\};)?$' || true)
[[ -z $extra ]] || { printf 'unexpected differences:\n%s\n' "$extra" >&2; exit 1; }
install -m 644 "$tmp/nano.dtb" "$out"
echo "wrote $out"
