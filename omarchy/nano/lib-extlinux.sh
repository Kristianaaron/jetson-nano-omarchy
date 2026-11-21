#!/bin/bash

edit_extlinux() {
  local file="$1"
  local token
  # panic=10 with hung_task_panic and softlockup_panic: a driver deadlock or a stuck CPU reboots the
  # board instead of hanging it; reserve_mem + ramoops keep the panic log across that reboot
  # (systemd-pstore files it under /var/lib/systemd/pstore).
  local tokens=(loglevel=7 panic=10 hung_task_panic=1 softlockup_panic=1
    reserve_mem=1M:4096:oops ramoops.mem_name=oops ramoops.record_size=0x40000
    clk_ignore_unused pd_ignore_unused video=HDMI-A-1:1280x720@60e)

  sed -E \
    -e 's/^[[:space:]]*INITRD .*/      INITRD \/boot\/initramfs-linux.img/' \
    -e '/^[[:space:]]*APPEND[[:space:]]/ s/(^|[[:space:]])root=\/dev\/mmcblk0p1([[:space:]]|$)/\1root=LABEL=ALARM\2/' \
    -e '/^[[:space:]]*APPEND[[:space:]]/ s/([[:space:]])quiet([[:space:]])/\1/g' \
    -e '/^[[:space:]]*APPEND[[:space:]]/ s/[[:space:]]quiet$//' \
    -e '/^[[:space:]]*APPEND[[:space:]]/ s/video=HDMI-A-1:[^[:space:]]*/video=HDMI-A-1:1280x720@60e/g' \
    -i.bak "$file"
  rm -f "$file.bak"

  for token in "${tokens[@]}"; do
    if ! grep -Eq "(^|[[:space:]])${token}([[:space:]]|$)" <(sed -n '/^[[:space:]]*APPEND[[:space:]]/p' "$file"); then
      sed -E \
        -e "/^[[:space:]]*APPEND[[:space:]]/ s|$| ${token}|" \
        -i.bak "$file"
      rm -f "$file.bak"
    fi
  done
}
