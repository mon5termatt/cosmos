#!/bin/sh
# Patch live U-Boot env so the next reboot gets ACE USB quirks without an
# image rebuild. Run as root on the printer.
set -eu

[ "$(id -u)" -eq 0 ] || { echo "Run as root." >&2; exit 1; }
command -v fw_setenv >/dev/null || { echo "fw_setenv not found" >&2; exit 1; }

# Keep existing console/root; append USB harden args.
# Quirks: ACE bgkno, Genesys hub ko, QinHeng hub k.
NEW='setenv bootargs console=ttyS0,115200 earlycon=uart8250,mmio32,0x02500000 root=${mmc_root} rootwait consoleblank=0 usbcore.autosuspend=-1 usbcore.quirks=28e9:018a:bgkno,05e3:0610:ko,1a86:8091:k'

# CC2 uses ttyS2 — detect from current env if present.
cur=$(fw_printenv -n setargs_mainline 2>/dev/null || true)
case "$cur" in
    *ttyS2*)
        NEW='setenv bootargs console=ttyS2,115200 root=${mmc_root} rootwait usbcore.autosuspend=-1 usbcore.quirks=28e9:018a:bgkno,05e3:0610:ko,1a86:8091:k'
        ;;
esac

echo "Current setargs_mainline:"
fw_printenv setargs_mainline || true
echo
echo "Writing:"
echo "$NEW"
fw_setenv setargs_mainline "$NEW"
echo
echo "Updated setargs_mainline:"
fw_printenv setargs_mainline
echo
echo "Also applying live usbcore params (best-effort until reboot):"
echo -1 > /sys/module/usbcore/parameters/autosuspend 2>/dev/null || true
echo '28e9:018a:bgkno,05e3:0610:ko,1a86:8091:k' > /sys/module/usbcore/parameters/quirks 2>/dev/null || true
echo "autosuspend=$(cat /sys/module/usbcore/parameters/autosuspend 2>/dev/null)"
echo "quirks=$(cat /sys/module/usbcore/parameters/quirks 2>/dev/null)"
echo
echo "Power-cycle the ACE if it is wedged, then reboot the printer to boot with the new args."
