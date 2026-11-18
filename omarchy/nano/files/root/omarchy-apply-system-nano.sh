#!/bin/bash
# omarchy-apply-system for the Jetson Nano: identical stages and order, minus
# config/snapper.sh, which needs a btrfs root (this card is ext4).
set -uo pipefail
export OMARCHY_INSTALL_USER=omarchy OMARCHY_FIRST_INSTALL=1 OMARCHY_UPGRADE=0
export OMARCHY_PATH=/usr/share/omarchy OMARCHY_INSTALL=/usr/share/omarchy/install
export OMARCHY_INSTALL_LOG_FILE=/var/log/omarchy-install.log PATH=/usr/share/omarchy/bin:$PATH
source "$OMARCHY_INSTALL/helpers/logging.sh"
start_install_log
grep -v "config/snapper.sh" "$OMARCHY_INSTALL/config/all.sh" > /tmp/omarchy-config-all.sh
source /tmp/omarchy-config-all.sh; echo "STAGE config rc=$?"
omarchy-apply-hardware --install-user omarchy; echo "STAGE hardware rc=$?"
run_logged "$OMARCHY_INSTALL/hardware/tegra210.sh"; echo "STAGE tegra210 rc=$?"
source "$OMARCHY_INSTALL/login/all.sh"; echo "STAGE login rc=$?"
source "$OMARCHY_INSTALL/post-install/all.sh"; echo "STAGE post-install rc=$?"
stop_install_log
