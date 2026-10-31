#!/bin/sh
# ACE USB wedge watcher.
#
# A hard -71 wedge (ACE or Genesys hub can't enumerate / "can't set config")
# cannot be cleared by toggling hub `authorized`. Only power-cycling the ACE
# (its own PSU / wall plug) brings it back. This daemon does NOT hammer
# reauth — that just logs Protocol errors and can make the hub worse.
#
# It watches for the ACE disappearing with -71 noise and logs once that a
# power cycle is required. When the ACE returns, the latch clears.
#
# Soft flaps (ACE firmware watchdog re-enum, no -71) are left alone; AFC's
# own reconnect + grace handles those.

SYSFS_USB="${ACE_SYSFS_USB:-/sys/bus/usb/devices}"
EVENT_LOG="${ACE_USB_EVENT_LOG:-/user-resource/ace-addon/usb-events.log}"
INTERVAL="${ACE_USB_RECOVER_INTERVAL:-5}"
GONE_S="${ACE_USB_RECOVER_GONE_S:-20}"
STATE_DIR="${ACE_USB_RECOVER_STATE:-/var/run}"
GONE_SINCE="${STATE_DIR}/ace-usb-gone.ts"
WEDGE_LATCH="${STATE_DIR}/ace-usb-wedge.latch"

log_usb_event() {
    mkdir -p "$(dirname "$EVENT_LOG")" 2>/dev/null || true
    ts=$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "?")
    up=$(cut -d. -f1 /proc/uptime 2>/dev/null || echo "?")
    echo "$ts up=${up}s $*" >> "$EVENT_LOG" 2>/dev/null || true
}

ace_present() {
    for d in "$SYSFS_USB"/*/; do
        [ -f "${d}idVendor" ] || continue
        [ "$(cat "${d}idVendor" 2>/dev/null)" = "28e9" ] || continue
        [ "$(cat "${d}idProduct" 2>/dev/null)" = "018a" ] && return 0
    done
    for d in "$SYSFS_USB"/*/; do
        [ -f "${d}product" ] || continue
        read -r p < "${d}product" 2>/dev/null || continue
        case "$p" in
            *ACE*) return 0 ;;
        esac
    done
    return 1
}

# Hard wedge signatures in recent dmesg (hub/ACE protocol death, not a clean re-enum).
hard_wedge() {
    dmesg | tail -n 100 | grep -qE \
        '1-1\.4.*error -71|can.t read configurations, error -71|can.t set config.*-71|unable to enumerate USB device|hub_ext_port_status failed'
}

LOCKFILE="${ACE_USB_RECOVER_LOCK:-/var/run/ace-usb-recover.lock}"
PIDFILE="${ACE_USB_RECOVER_PID:-/var/run/ace-usb-recover.pid}"
exec 9>"$LOCKFILE"
flock -n 9 || exit 0
echo $$ > "$PIDFILE"

if [ "$1" = "--once" ]; then
    if ace_present; then
        rm -f "$WEDGE_LATCH" "$GONE_SINCE"
        echo "ACE present"
        exit 0
    fi
    if hard_wedge; then
        echo "ACE hard -71 wedge: power-cycle the ACE (hub reauth will not clear this)"
        exit 2
    fi
    echo "ACE absent (no hard-wedge signature yet)"
    exit 1
fi

log_usb_event "recover_start pid=$$ mode=watch_only"

while :; do
    if ace_present; then
        if [ -f "$WEDGE_LATCH" ]; then
            log_usb_event "ACE_BACK after power-cycle or re-enum"
        fi
        rm -f "$GONE_SINCE" "$WEDGE_LATCH"
    else
        now=$(date +%s)
        if [ ! -f "$GONE_SINCE" ]; then
            echo "$now" > "$GONE_SINCE"
        else
            since=$(cat "$GONE_SINCE" 2>/dev/null || echo "$now")
            gone=$((now - since))
            if [ "$gone" -ge "$GONE_S" ] && hard_wedge && [ ! -f "$WEDGE_LATCH" ]; then
                echo "$now" > "$WEDGE_LATCH"
                log_usb_event "ACE_HARD_WEDGE gone=${gone}s — power-cycle the ACE (its wall power). Hub authorized toggle cannot clear -71."
                echo "ACE USB hard wedge (-71): power-cycle the ACE unit" \
                    >/tmp/ace-usb-wedge.msg 2>/dev/null || true
            fi
        fi
    fi
    sleep "$INTERVAL"
done
