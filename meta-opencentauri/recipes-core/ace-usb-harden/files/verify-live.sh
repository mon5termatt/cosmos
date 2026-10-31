#!/bin/sh
echo "=== services ==="
/etc/init.d/ace-usb-power status || true
/etc/init.d/ace-usb-recover status || true
/etc/init.d/ace-keepalive status || true
/etc/init.d/klipper status || true

echo "=== usbcore ==="
echo "autosuspend=$(cat /sys/module/usbcore/parameters/autosuspend 2>/dev/null)"
echo "quirks=$(cat /sys/module/usbcore/parameters/quirks 2>/dev/null)"

echo "=== power tree ==="
for d in /sys/bus/usb/devices/*/idVendor; do
    [ -f "$d" ] || continue
    dir=$(dirname "$d")
    vid=$(cat "$dir/idVendor" 2>/dev/null)
    pid=$(cat "$dir/idProduct" 2>/dev/null)
    case "$vid:$pid" in
        28e9:018a|1a86:8091|05e3:0610)
            echo "$dir $(cat "$dir/product" 2>/dev/null) control=$(cat "$dir/power/control" 2>/dev/null) autosuspend=$(cat "$dir/power/autosuspend" 2>/dev/null)"
            ;;
    esac
done

echo "=== ports ==="
ls -la /dev/ttyACM* /dev/serial/by-id/ 2>&1 || true

echo "=== afc ==="
wget -qO- 'http://127.0.0.1/printer/objects/query?AFC_ACE%20ACE_1' | tr ',' '\n' | grep -E 'connected|link_online|status_age' || true
echo "holding=$(cat /var/run/afc-ace-holding 2>/dev/null || true)"

echo "=== recent usb events ==="
tail -n 10 /user-resource/ace-addon/usb-events.log 2>/dev/null || true
