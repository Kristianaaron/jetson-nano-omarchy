#!/bin/bash
# Install the Omarchy desktop layer on Arch Linux ARM, Jetson Nano (Tegra210).
#
# Runs on the Nano after mainline Arch boots. It installs Omarchy's packages and
# its source tree at a pinned release, wires the platform profile, and starts the
# session. It does not touch the boot loader: on this board the boot entry is
# owned by the image (see /etc/omarchy/boot.conf and ADR-001).
#
# Status: written against Omarchy v4.5.0, not yet executed on hardware. Every
# step logs to /var/log/omarchy-nano-install.log, and the script is idempotent so
# a partial run can be repeated.
#
# Usage: sudo bash install-omarchy-nano.sh
set -euo pipefail

OMARCHY_REF="${OMARCHY_REF:-v4.5.0}"
OMARCHY_TAG_SHA="${OMARCHY_TAG_SHA:-97e664bd971fa5a8691d89440d3738143499c438}"
SRC=/usr/share/omarchy
LOG=/var/log/omarchy-nano-install.log
REPO_DIR="$(cd "$(dirname "$0")/../.." && pwd)"

die() { echo "error: $*" >&2; exit 1; }
say() { printf '\n>> %s\n' "$*" | tee -a "$LOG"; }

[[ $EUID -eq 0 ]] || die "run as root"
[[ -f /etc/pacman.conf ]] || die "this must run on Arch Linux ARM"
exec > >(tee -a "$LOG") 2>&1

say "1/8 pacman keys and refresh"
pacman-key --init 2>/dev/null || true
pacman-key --populate archlinuxarm 2>/dev/null || true
pacman -Syu --noconfirm

say "2/8 installing Omarchy packages for aarch64"
# Base + generic aarch64 + the Nano's own additions, then the desktop stack.
mapfile -t pkgs < <(cat \
  "$REPO_DIR/omarchy/packages/omarchy-aarch64-tegra210.packages" 2>/dev/null \
  | grep -vE '^\s*#|^\s*$')
pacman -S --noconfirm --needed \
  hyprland quickshell waybar hyprlock hypridle hyprpaper hyprsunset \
  xdg-desktop-portal-hyprland uwsm sddm \
  foot alacritty wl-clipboard grim slurp swappy brightnessctl playerctl \
  pipewire wireplumber pipewire-pulse \
  qt6-wayland qt6-svg qt6-declarative \
  zram-generator sudo git base-devel \
  "${pkgs[@]}"

say "3/8 fetching Omarchy $OMARCHY_REF"
if [[ -d $SRC/.git ]]; then
  git -C "$SRC" fetch --depth 1 origin "refs/tags/$OMARCHY_REF:refs/tags/$OMARCHY_REF" || true
  git -C "$SRC" checkout -f "$OMARCHY_REF"
else
  git clone --depth 1 --branch "$OMARCHY_REF" https://github.com/omacom/omarchy "$SRC"
fi
got=$(git -C "$SRC" rev-parse "$OMARCHY_REF^{commit}")
say "    $OMARCHY_REF -> $got (tag object $OMARCHY_TAG_SHA)"

say "4/8 installing the platform profile"
install -Dm755 "$REPO_DIR/omarchy/platform-detection/omarchy-hw-aarch64-tegra210" \
  /usr/local/bin/omarchy-hw-aarch64-tegra210
install -Dm755 "$REPO_DIR/omarchy/installer-hooks/tegra210.sh" \
  "$SRC/install/hardware/tegra210.sh"

say "5/8 wiring the Omarchy commands"
# The tree hardcodes /usr/bin/omarchy-*, so the commands belong there.
for f in "$SRC"/bin/*; do
  [[ -f $f ]] || continue
  ln -sf "$f" "/usr/bin/$(basename "$f")"
done
ln -sf "$SRC/bin/omarchy" /usr/bin/omarchy

say "6/8 applying configurations and the hardware hook"
# omarchy-reinstall-configs is Omarchy's own config copier; it needs the user it
# is provisioning. Fall back to the raw tree if the helper is absent.
OMARCHY_PATH="$SRC" PATH="$SRC/bin:/usr/local/bin:$PATH" \
  bash "$SRC/install/hardware/tegra210.sh" || true
if [[ -x $SRC/bin/omarchy-reinstall-configs ]]; then
  OMARCHY_PATH="$SRC" bash "$SRC/bin/omarchy-reinstall-configs" || true
fi

say "7/8 enabling services"
systemctl enable zram-generator 2>/dev/null || true
systemctl enable sddm 2>/dev/null || true

say "8/8 done"
cat <<EOF
Omarchy $OMARCHY_REF installed from source at $SRC.

Boot entry ownership: /etc/omarchy/boot.conf (OMARCHY_BOOT_MANAGED=0).
Next: reboot and check for the Hyprland session. If the session starts with a
black screen, check the renderer with:
  eglinfo -B | grep -i renderer
That string decides whether this is accelerated or llvmpipe.
EOF
