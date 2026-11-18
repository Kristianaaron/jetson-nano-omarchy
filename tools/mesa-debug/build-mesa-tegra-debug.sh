#!/bin/bash
set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
Usage: build-mesa-tegra-debug.sh [--version V] [--prefix DIR] [--jobs N] [--workdir DIR]
USAGE
}

PREFIX=/opt/mesa-debug
JOBS=4
WORKDIR=/var/cache/mesa-debug
VERSION=
VERSION_SET=0

while (($#)); do
  case "$1" in
    --version)
      if (($# < 2)); then usage; exit 2; fi
      VERSION=$2
      VERSION_SET=1
      shift 2
      ;;
    --prefix)
      if (($# < 2)); then usage; exit 2; fi
      PREFIX=$2
      shift 2
      ;;
    --jobs)
      if (($# < 2)); then usage; exit 2; fi
      JOBS=$2
      shift 2
      ;;
    --workdir)
      if (($# < 2)); then usage; exit 2; fi
      WORKDIR=$2
      shift 2
      ;;
    *)
      usage
      exit 2
      ;;
  esac
done

if [[ $(id -u) -ne 0 ]]; then
  echo "run as root" >&2
  exit 1
fi
if [[ $(uname -m) != aarch64 ]]; then
  echo "this script requires aarch64" >&2
  exit 1
fi

LOG=/var/log/mesa-debug-build.log
exec > >(tee -a "$LOG") 2>&1

if ((VERSION_SET == 0)); then
  PACKAGE_VERSION=$(pacman -Q mesa | awk '{print $2}')
  PACKAGE_VERSION=${PACKAGE_VERSION#*:}
  VERSION=${PACKAGE_VERSION%-*}
fi
if [[ -z $VERSION ]]; then
  echo "could not determine Mesa version" >&2
  exit 1
fi

TARBALL="$WORKDIR/mesa-$VERSION.tar.xz"
URL="https://archive.mesa3d.org/mesa-$VERSION.tar.xz"
mkdir -p "$WORKDIR/src"

echo "Installing build dependencies"
pacman -S --needed --noconfirm \
  meson ninja python-mako python-packaging python-yaml python-pycparser glslang libdrm wayland \
  wayland-protocols libxshmfence elfutils zstd expat bison flex gdb gcc pkgconf

if [[ ! -f $TARBALL ]]; then
  curl -fL --retry 3 -o "$TARBALL.part" "$URL"
  mv "$TARBALL.part" "$TARBALL"
fi
# Mesa publishes detached GPG signatures, not checksum files.
curl -fL --retry 3 -o "$TARBALL.sig" "$URL.sig"
export GNUPGHOME="$WORKDIR/gnupg"
mkdir -p "$GNUPGHOME"
chmod 700 "$GNUPGHOME"
if ! gpg --batch --keyserver hkps://keyserver.ubuntu.com --auto-key-retrieve \
    --verify "$TARBALL.sig" "$TARBALL"; then
  rm -f "$TARBALL"
  echo "signature verification failed" >&2
  exit 1
fi

SRC="$WORKDIR/src/mesa-$VERSION"
if [[ ! -d $SRC ]]; then
  tar -xf "$TARBALL" -C "$WORKDIR/src"
fi
BUILD="$SRC/build-tegra-debug"
if [[ -f $SRC/meson.options ]]; then
  OPTS="$SRC/meson.options"
elif [[ -f $SRC/meson_options.txt ]]; then
  OPTS="$SRC/meson_options.txt"
else
  echo "could not find Meson options file" >&2
  exit 1
fi

required=(gallium-drivers gbm egl gles2)
specs=(
  "b_ndebug|false"
  "gallium-drivers|tegra,nouveau"
  "vulkan-drivers|"
  "platforms|wayland"
  "gbm|enabled"
  "egl|enabled"
  "gles1|disabled"
  "gles2|enabled"
  "glx|disabled"
  "glvnd|disabled"
  "llvm|disabled"
  "video-codecs|"
  "tools|"
  "build-tests|false"
)
opts=("--prefix=$PREFIX" --libdir=lib --buildtype=debug)
for spec in "${specs[@]}"; do
  name=${spec%%|*}
  value=${spec#*|}
  if grep -A1 -E '^option\(' "$OPTS" | grep -q "'$name'"; then
    opts+=("-D$name=$value")
  else
    is_required=0
    for required_name in "${required[@]}"; do
      if [[ $name == "$required_name" ]]; then
        is_required=1
        break
      fi
    done
    if ((is_required)); then
      echo "required Meson option is absent: $name" >&2
      exit 1
    fi
    echo "skip absent option: $name"
  fi
done

if [[ -f $BUILD/build.ninja ]]; then
  meson setup --reconfigure "$BUILD" "$SRC" "${opts[@]}"
else
  meson setup "$BUILD" "$SRC" "${opts[@]}"
fi
ninja -C "$BUILD" -j "$JOBS"
ninja -C "$BUILD" install

for library in libEGL.so.1 libgbm.so.1 libGLESv2.so.2; do
  if [[ ! -e $PREFIX/lib/$library ]]; then
    echo "missing installed library: $PREFIX/lib/$library" >&2
    exit 1
  fi
done
if [[ ! -e $PREFIX/lib/dri/tegra_dri.so ]] && ! compgen -G "$PREFIX/lib/libgallium*.so" >/dev/null; then
  echo "missing installed tegra or gallium driver library" >&2
  exit 1
fi
echo "MESA-DEBUG-BUILD-OK $VERSION $PREFIX"
