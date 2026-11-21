# Attempts that did not ship

## HDMI hot-plug and EDID through MOD_SLEEP* (PA6), 2026-11-20

Measured: on the P3449-B01 carrier, GPIO PA6 (MOD_SLEEP*) switches VDD_3V3_HDMI, which enables
the HDMI 5 V load switch and the DDC level shifter. Mainline describes PA6 only as the enable of
VDD_HUB_3V3, which has no consumer since commit 2428787f1615 ("phy: tegra: xusb: Remove usb3
supply"), so the fixed regulator driver drives PA6 low at probe. Driving PA6 high by register
made HPD read connected and the EDID read over DDC (`00 ff ff ff ff ff ff 00`, AORUS FO27Q2).

Not shipped: with `hdmi-power-pa6.dtsi` (PA6 as the shared, boot-on enable of VDD_HDMI_5V0 and
VDD_HUB_3V3) in both boot device trees and the forced mode removed, the board stopped booting
after the NVIDIA splash on every power cycle, with no journal entry (the kernel stopped before
the root filesystem). The same session had also frozen once, silently, about 20 minutes after
PA6 was set high by register. Restoring the previous device trees and command line booted.
The cause was not isolated (no serial console at the time).

Files: `hdmi-power-pa6.dtsi` (fragment), `0103-arm64-tegra-p3450-power-HDMI-from-MOD_SLEEP.patch`
(the same change for mainline's tegra210-p3450-0000.dts). Next step if picked up again: test
one change at a time with a serial console attached (regulator-always-on on VDD_HUB_3V3 alone,
without the shared enable or boot-on).

Shipped instead: the monitor's EDID from /usr/lib/firmware/edid with the forced connector, at
the monitor's native mode (2560x1440) and scale 1.
