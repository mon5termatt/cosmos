#!/bin/sh
# Rate-limited hub reauth when the ACE port wedges with -71.
# Toggles the Genesys hub (typically 1-1.4) authorized 0→1 at most once/min.

SYSFS_USB="${ACE_SYSFS_USB:-/sys/bus/usb/devices}"
EVENT_LOG="${ACE_USB_EVENT_LOG:-/user-resource/ace-addon/usb-events.log}"
INTERVAL="${ACE_USB_RECOVER_INTERVAL:-5}"
GONE_S="${ACE_USB_RECOVER_GONE_S:-20}"
COOLDOWN_S="${ACE_USB_RECOVER_COOLDOWN_S:-60}"
STATE_DIR="${ACE_USB_RECOVER_STATE:-/var/run}"
LAST_REAUTH="${STATE_DIR}/ace-usb-reauth.ts"
GONE_SINCE="${STATE_DIR}/ace-usb-gone.ts"
# Never reauth 1-1 (QinHeng): WiFi/camera share that hub and dropping it
# kills SSH. Only the Genesys hub that carries the ACE (typically 1-1.4).
HUB_CANDIDATES="1-1.4"

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

recent_minus71() {
    dmesg | tail -n 80 | grep -qE '1-1\.4.*-71|error -71'
}

find_hub() {
    for h in $HUB_CANDIDATES; do
        if [ -f "${SYSFS_USB}/${h}/authorized" ]; then
            echo "${SYSFS_USB}/${h}"
            return 0
        fi
    done
    # Fall back to Genesys hub only if it is under 1-1.* (not a random port).
    for d in "$SYSFS_USB"/1-1.*/; do
        [ -f "${d}idVendor" ] || continue
        [ "$(cat "${d}idVendor" 2>/dev/null)" = "05e3" ] || continue
        [ "$(cat "${d}idProduct" 2>/dev/null)" = "0610" ] || continue
        echo "${d%/}"
        return 0
    done
    return 1
}

reauth_hub() {
    hub=$1
    [ -f "${hub}/authorized" ] || return 1
    now=$(date +%s)
    if [ -f "$LAST_REAUTH" ]; then
        last=$(cat "$LAST_REAUTH" 2>/dev/null || echo 0)
        age=$((now - last))
        if [ "$age" -lt "$COOLDOWN_S" ]; then
            return 0
        fi
    fi
    log_usb_event "ACE_HUB_REAUTH hub=$(basename "$hub") reason=gone_with_-71"
    echo 0 > "${hub}/authorized" 2>/dev/null || true
    sleep 2
    echo 1 > "${hub}/authorized" 2>/dev/null || true
    echo "$now" > "$LAST_REAUTH"
}

LOCKFILE="${ACE_USB_RECOVER_LOCK:-/var/run/ace-usb-recover.lock}"
PIDFILE="${ACE_USB_RECOVER_PID:-/var/run/ace-usb-recover.pid}"
exec 9>"$LOCKFILE"
flock -n 9 || exit 0
echo $$ > "$PIDFILE"

if [ "$1" = "--once" ]; then
    if ! ace_present && recent_minus71; then
        hub=$(find_hub) && reauth_hub "$hub"
    fi
    exit 0
fi

log_usb_event "recover_start pid=$$"

while :; do
    if ace_present; then
        rm -f "$GONE_SINCE"
    else
        now=$(date +%s)
        if [ ! -f "$GONE_SINCE" ]; then
            echo "$now" > "$GONE_SINCE"
        else
            since=$(cat "$GONE_SINCE" 2>/dev/null || echo "$now")
            gone=$((now - since))
            if [ "$gone" -ge "$GONE_S" ] && recent_minus71; then
                hub=$(find_hub) || hub=""
                if [ -n "$hub" ]; then
                    reauth_hub "$hub"
                    echo "$(date +%s)" > "$GONE_SINCE"
                fi
            fi
        fi
    fi
    sleep "$INTERVAL"
done
