# Rollback and recovery

The first rule: **the known-good 128 GB microSD is never written.** Every experiment uses a second
card. The only writes this repository performs are to a card the operator names explicitly.

## Non-negotiables

- No `flash.sh` guessing. If QSPI or firmware modification is ever needed, that is a separate ADR
  with a verified recovery image and explicit owner approval.
- No experiment proceeds without a serial console path and a captured "before" log.
- `scripts/install-nano.sh` refuses a non-removable target and refuses to write the running card.

## Image the known-good card

On a Linux host with a card reader, with the Nano powered off and the card removed:

```sh
lsblk                                        # identify the card, e.g. /dev/sdb
sudo dd if=/dev/sdb of=nano-known-good.img bs=4M status=progress conv=fsync
sha256sum nano-known-good.img | tee nano-known-good.img.sha256
```

Store the image away from the card. A 128 GB card makes a 128 GB image; compress it
(`xz -T0 -9`) if space is tight, and keep the checksum with it.

## Restore test (required before any experiment)

```sh
sudo dd if=nano-known-good.img of=/dev/sdc bs=4M status=progress conv=fsync
```

Boot the restored card in the Nano, confirm the desktop/login and SSH, then keep that card as the
**reference**. Only a card that has been restored once is trusted.

## Serial recovery

- 3.3 V TTL adapter, 115200n8, GND shared. Never 5 V.
- Jetson Nano 40-pin header: pin 8 TX, pin 10 RX, pin 6 GND. Confirm against the board pinout first.
- Boot log to `results/system/serial-before.log` before touching anything.

If the board does not boot:

1. Try the vendor label in U-Boot's extlinux menu.
2. Try the known-good card.
3. Try serial console with the experimental card to see how far the kernel gets.
4. Only then consider rewriting the boot partition, and only from the verified image.

## Card inventory discipline

Label every card physically: `GOOD-128`, `ARCH-EXP-1`, `ARCH-EXP-2`. Record in
`results/system/cards.md`: label, capacity, image hash, date written, what it contains, last known
state. An unlabelled card is an unknown card and does not go in the board.

## Failure log

Every failed boot records: card label, `extlinux.conf` used, serial log, last kernel message,
and the exact rollback taken. That is the artifact that makes the next attempt cheaper.
