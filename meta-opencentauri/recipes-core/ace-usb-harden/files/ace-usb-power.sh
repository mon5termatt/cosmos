#!/bin/sh
# Force power/control=on up the ACE USB parent chain.
# Walk by USB path name (1-1.4.3 -> 1-1.4 -> 1-1 -> usbN); never `cd ..`
# from /sys/bus/usb/devices (that lands in the bus dir).

SYSFS_USB="${ACE_SYSFS_USB:-/sys/bus/usb/devices}"
INTERVAL="${ACE_USB_POWER_INTERVAL:-30}"

usb_parent_of() {
    base=$(basename "$1")
    case "$base" in
        usb[0-9]*)
            echo ""
            ;;
        *-*.*)
            echo "${base%.*}"
            ;;
        *-[0-9]*)
            if [ -f "$1/busnum" ]; then
                echo "usb$(cat "$1/busnum")"
            else
                echo ""
            fi
            ;;
        *)
            echo ""
            ;;
    esac
}

stay_awake_path() {
    d=$1
    n=0
    while [ -n "$d" ] && [ -e "${d}/power/control" ] && [ "$n" -lt 8 ]; do
        echo on > "${d}/power/control" 2>/dev/null || true
        echo -1 > "${d}/power/autosuspend" 2>/dev/null || true
        echo -1 > "${d}/power/autosuspend_delay_ms" 2>/dev/null || true
        base=$(basename "$d")
        case "$base" in
            usb[0-9]*) break ;;
        esac
        parent=$(usb_parent_of "$d")
        [ -n "$parent" ] || break
        if [ -d "${SYSFS_USB}/${parent}" ]; then
            d="${SYSFS_USB}/${parent}"
        else
            break
        fi
        n=$((n + 1))
    done
}

pin_known() {
    for id in "28e9:018a" "1a86:8091" "05e3:0610"; do
        vid=${id%:*}
        pid=${id#*:}
        for d in "$SYSFS_USB"/*/; do
            [ -f "${d}idVendor" ] || continue
            [ "$(cat "${d}idVendor" 2>/dev/null)" = "$vid" ] || continue
            [ "$(cat "${d}idProduct" 2>/dev/null)" = "$pid" ] || continue
            stay_awake_path "${d%/}"
        done
    done
}

LOCKFILE="${ACE_USB_POWER_LOCK:-/var/run/ace-usb-power.lock}"
PIDFILE="${ACE_USB_POWER_PID:-/var/run/ace-usb-power.pid}"
exec 9>"$LOCKFILE"
flock -n 9 || exit 0
echo $$ > "$PIDFILE"

if [ "$1" = "--once" ]; then
    pin_known
    exit 0
fi

while :; do
    pin_known
    sleep "$INTERVAL"
done
