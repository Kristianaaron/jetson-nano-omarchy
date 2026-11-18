#!/bin/bash
set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
Usage: run-gbmclear-gdb.sh [--prefix DIR] [--out DIR] [--system]
USAGE
}

PREFIX=/opt/mesa-debug
OUT=/root/mesa-debug-results
SYSTEM=0

while (($#)); do
  case "$1" in
    --prefix)
      if (($# < 2)); then usage; exit 2; fi
      PREFIX=$2
      shift 2
      ;;
    --out)
      if (($# < 2)); then usage; exit 2; fi
      OUT=$2
      shift 2
      ;;
    --system)
      SYSTEM=1
      shift
      ;;
    *)
      usage
      exit 2
      ;;
  esac
done

mkdir -p "$OUT"
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
if ((SYSTEM)); then
  gcc -O0 -g "$SCRIPT_DIR/gbmclear.c" -o "$OUT/gbmclear" -lEGL -lGLESv2 -lgbm
else
  gcc -O0 -g "$SCRIPT_DIR/gbmclear.c" -o "$OUT/gbmclear" \
    -L"$PREFIX/lib" -Wl,-rpath,"$PREFIX/lib" -lEGL -lGLESv2 -lgbm
fi

unset MESA_LOADER_DRIVER_OVERRIDE LIBGL_ALWAYS_SOFTWARE || true
export EGL_LOG_LEVEL=debug
export MESA_DEBUG=1
if ((!SYSTEM)); then
  unset LD_LIBRARY_PATH LIBGL_DRIVERS_PATH GBM_BACKENDS_PATH __EGL_VENDOR_LIBRARY_DIRS || true
  [[ ! -d $PREFIX/lib ]] || export LD_LIBRARY_PATH="$PREFIX/lib"
  [[ ! -d $PREFIX/lib/dri ]] || export LIBGL_DRIVERS_PATH="$PREFIX/lib/dri"
  [[ ! -d $PREFIX/lib/gbm ]] || export GBM_BACKENDS_PATH="$PREFIX/lib/gbm"
  [[ ! -d $PREFIX/share/glvnd/egl_vendor.d ]] || export __EGL_VENDOR_LIBRARY_DIRS="$PREFIX/share/glvnd/egl_vendor.d"
fi

run_one() {
  local label=$1
  local dev=$2
  local logfile="$OUT/gdb-$label.log"
  timeout 120 gdb -batch -nx \
    -ex "set pagination off" \
    -ex run \
    -ex "bt full" \
    -ex "info registers" \
    -ex "thread apply all bt" \
    -ex "info sharedlibrary" \
    --args "$OUT/gbmclear" "$dev" >"$logfile" 2>&1 || true
}

run_one tegra /dev/dri/by-path/platform-50000000.host1x-card
run_one nouveau /dev/dri/by-path/platform-57000000.gpu-render

for label in tegra nouveau; do
  logfile="$OUT/gdb-$label.log"
  echo "[$label]"
  if pixel=$(grep -m1 'pixel:' "$logfile"); then
    echo "$pixel"
  else
    echo "NO PIXEL (crashed?)"
  fi
  awk '
    /^#0/ { found = 1 }
    found && count < 25 { print; count++ }
    END { if (!found) print "NO BACKTRACE" }
  ' "$logfile"
done
echo "RESULTS IN $OUT"
