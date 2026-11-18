#!/bin/bash

edit_extlinux() {
  local file="$1"
  local token
  local tokens=(loglevel=7 panic=10 clk_ignore_unused pd_ignore_unused video=HDMI-A-1:1280x720@60e)

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
