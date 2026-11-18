#!/usr/bin/env python3
"""Remove identifying details from board logs before they are committed.

Drops firewall log lines (they carry the MAC and IP of every device on the LAN) and masks private
IPv4 addresses, tailnet addresses, MAC addresses and USB serial numbers. Rewrites files in place.
Usage: sanitize-log.py FILE [FILE ...]
"""
import re
import sys

PRIVATE_V4 = re.compile(
    r"\b(?:10\.\d{1,3}|172\.(?:1[6-9]|2\d|3[01])|192\.168|100\.(?:6[4-9]|[7-9]\d|1[01]\d|12[0-7]))"
    r"\.\d{1,3}\.\d{1,3}\b"
)
MAC = re.compile(r"\b(?:[0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}\b")
USB_SERIAL = re.compile(r"(SerialNumber: ).+")
DROP = ("UFW BLOCK", "UFW AUDIT", "UFW ALLOW")


def clean(text: str) -> str:
    out = []
    for line in text.splitlines(keepends=True):
        if any(d in line for d in DROP):
            continue
        line = PRIVATE_V4.sub("<lan-ip>", line)
        line = MAC.sub("<mac>", line)
        line = USB_SERIAL.sub(r"\1<serial>", line)
        out.append(line)
    return "".join(out)


def main() -> int:
    for path in sys.argv[1:]:
        with open(path, encoding="utf-8", errors="surrogateescape") as f:
            text = f.read()
        new = clean(text)
        if new != text:
            with open(path, "w", encoding="utf-8", errors="surrogateescape") as f:
                f.write(new)
            print(f"sanitized {path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
