#!/usr/bin/env python3
"""Insert Anycubic ACE / Centauri hub entries into usb_quirk_list."""
from __future__ import annotations

import pathlib
import sys

MARKER = "{ }  /* terminating entry must be last */"
NEEDLE = "0x28e9, 0x018a"
BLOCK = """\
	/* Centauri Carbon: Genesys hub carrying the Anycubic ACE Pro */
	{ USB_DEVICE(0x05e3, 0x0610), .driver_info = USB_QUIRK_NO_LPM |
			USB_QUIRK_HUB_SLOW_RESET },

	/* Anycubic ACE Pro (GDMicroelectronics GD32 CDC-ACM) */
	{ USB_DEVICE(0x28e9, 0x018a), .driver_info = USB_QUIRK_RESET_RESUME |
			USB_QUIRK_DELAY_INIT | USB_QUIRK_NO_LPM |
			USB_QUIRK_DELAY_CTRL_MSG },

"""


def main(path: pathlib.Path) -> int:
    text = path.read_text(encoding="utf-8", errors="replace")
    if NEEDLE in text:
        print(f"{path}: ACE quirk already present")
        return 0
    if MARKER not in text:
        print(f"{path}: terminating marker not found", file=sys.stderr)
        return 1
    path.write_text(text.replace(MARKER, BLOCK + MARKER, 1), encoding="utf-8")
    print(f"{path}: inserted ACE/Genesys USB quirks")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(pathlib.Path(sys.argv[1])))
