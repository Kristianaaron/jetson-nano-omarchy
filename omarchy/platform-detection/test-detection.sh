#!/bin/bash
# Tests for omarchy/platform-detection/omarchy-hw-aarch64-tegra210.
# No hardware required: each case writes a fixture compatible string and expects
# the detector to accept or reject it.
#
# Usage: bash omarchy/platform-detection/test-detection.sh

set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
detect="$here/omarchy-hw-aarch64-tegra210"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fails=0

run_case() {
  local name=$1 expected=$2 compatible=$3 model=${4:-}
  # Bash variables cannot hold NUL bytes, so the fixtures carry \0 escapes and
  # are expanded with printf %b.
  printf '%b' "$compatible" > "$tmp/compat"
  printf '%b' "$model" > "$tmp/model"
  if OMARCHY_DT_COMPATIBLE="$tmp/compat" OMARCHY_DT_MODEL="$tmp/model" bash "$detect"; then
    got=accept
  else
    got=reject
  fi
  if [[ $got == "$expected" ]]; then
    printf 'PASS %-38s %s\n' "$name" "$got"
  else
    printf 'FAIL %-38s expected %s got %s\n' "$name" "$expected" "$got"
    fails=$((fails + 1))
  fi
}

run_case "A02 p3450 kit" accept \
  "nvidia,p3450-0000\\0nvidia,tegra210\\0" "NVIDIA Jetson Nano Developer Kit"

run_case "B01 p3449 kit (this board)" accept \
  "nvidia,p3449-0000-b00+p3448-0000-b00\\0nvidia,jetson-nano\\0nvidia,tegra210\\0" "NVIDIA Jetson Nano Developer Kit"

run_case "2GB p3541 kit" reject \
  "nvidia,p3541-0000\\0nvidia,tegra210\\0" "NVIDIA Jetson Nano 2GB Developer Kit"

run_case "GB10 (DGX Spark)" reject \
  "nvidia,gb10\\0nvidia,tegra234\\0" "NVIDIA DGX Spark"

run_case "N1x laptop" reject \
  "nvidia,n1x\\0" "NVIDIA N1x"

run_case "unrelated Tegra210 board" reject \
  "nvidia,p2371-2180\\0nvidia,tegra210\\0" "NVIDIA Jetson TX1"

run_case "missing compatible file" reject "" ""

printf '\n%s case(s) failed\n' "$fails"
[[ $fails -eq 0 ]]
