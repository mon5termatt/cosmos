#!/bin/sh
# Soft-recover ACE by reauthorizing ONLY the Genesys hub in front of it.
# Never touch 1-1 (QinHeng) — WiFi and camera share that hub.
set -e

reauth_one() {
    hub=$1
    path="/sys/bus/usb/devices/$hub/authorized"
    if [ -f "$path" ]; then
        echo "reauth $hub"
        echo 0 > "$path" || true
        sleep 2
        echo 1 > "$path" || true
        sleep 5
    fi
}

reauth_one 1-1.4

for d in /sys/bus/usb/devices/*/idVendor; do
    [ -f "$d" ] || continue
    dir=$(dirname "$d")
    [ "$(cat "$dir/idVendor")" = "05e3" ] || continue
    [ "$(cat "$dir/idProduct")" = "0610" ] || continue
    base=$(basename "$dir")
    [ "$base" = "1-1.4" ] && continue
    case "$base" in
        1-1.*) reauth_one "$base" ;;
    esac
done

/user-resource/ace-addon/ace-usb-power.sh --once 2>/dev/null || true
echo "products:"
for f in /sys/bus/usb/devices/*/product; do
    [ -f "$f" ] || continue
    echo "  $(cat "$f") ($f)"
done
echo "ttys:"
ls /dev/ttyACM* 2>&1 || true
