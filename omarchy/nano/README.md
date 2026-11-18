# Provision a Jetson Nano

Run `bash omarchy/nano/provision-nano.sh` as root over SSH after booting the Arch Linux ARM card once with the diagnostic initramfs. The script reads its target files from `omarchy/nano/files/`. It does not reboot the Nano.

The nine stages set up accounts and sudo, update Arch and install build tools, protect the boot configuration, install the PWM DKMS module, configure the fan, install Omarchy packages, apply Omarchy system settings, configure wired networking, and set the user's desktop files.

Each completed stage writes `/var/lib/jetson-nano/stage-N.done`. A later run skips marked stages. Use `--from N` to clear markers from stage N onward and resume there. Use `--only N` to run one stage.
