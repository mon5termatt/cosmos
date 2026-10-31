#!/bin/sh
# Live-install ace-usb-harden onto a running Cosmos printer (no image rebuild).
# Run on the printer after scp of this files/ directory, or via:
#   scp -r files/* root@PRINTER:/tmp/ace-usb-harden/ && ssh root@PRINTER sh /tmp/ace-usb-harden/deploy-live.sh
set -e
SRC="${1:-$(cd "$(dirname "$0")" && pwd)}"

mkdir -p /etc/udev/rules.d /etc/modprobe.d /etc/init.d /user-resource/ace-addon

# /usr is read-only on a running Cosmos image; live scripts live in /user-resource.
# Image builds still install to ${sbindir} via the recipe.
cp "$SRC/98-ace-usb.rules" /etc/udev/rules.d/98-ace-usb.rules
cp "$SRC/usbcore-ace.conf" /etc/modprobe.d/usbcore-ace.conf
cp "$SRC/ace-usb-power.sh" /user-resource/ace-addon/ace-usb-power.sh
cp "$SRC/ace-usb-recover.sh" /user-resource/ace-addon/ace-usb-recover.sh
cp "$SRC/ace-usb-power.init" /etc/init.d/ace-usb-power
cp "$SRC/ace-usb-recover.init" /etc/init.d/ace-usb-recover
chmod 0644 /etc/udev/rules.d/98-ace-usb.rules /etc/modprobe.d/usbcore-ace.conf
chmod 0755 /user-resource/ace-addon/ace-usb-power.sh \
    /user-resource/ace-addon/ace-usb-recover.sh \
    /etc/init.d/ace-usb-power /etc/init.d/ace-usb-recover

# Strip CRLF if copied from Windows
sed -i 's/\r$//' /user-resource/ace-addon/ace-usb-power.sh \
    /user-resource/ace-addon/ace-usb-recover.sh \
    /etc/init.d/ace-usb-power /etc/init.d/ace-usb-recover \
    /etc/udev/rules.d/98-ace-usb.rules /etc/modprobe.d/usbcore-ace.conf

update-rc.d ace-usb-power defaults 22 78 2>/dev/null || true
update-rc.d ace-usb-recover defaults 23 77 2>/dev/null || true

# Apply usbcore params live where possible (quirks fully need reboot/bootargs).
if [ -w /sys/module/usbcore/parameters/autosuspend ]; then
    echo -1 > /sys/module/usbcore/parameters/autosuspend || true
fi
if [ -w /sys/module/usbcore/parameters/quirks ]; then
    echo "28e9:018a:bk" > /sys/module/usbcore/parameters/quirks || true
fi

udevadm control --reload 2>/dev/null || true
udevadm trigger --subsystem-match=usb 2>/dev/null || true

/etc/init.d/ace-usb-power restart
/etc/init.d/ace-usb-recover restart

# Clear a wedged ACE hub port once after install.
# Never touch 1-1 — WiFi/camera share that QinHeng hub.
if [ -f /sys/bus/usb/devices/1-1.4/authorized ]; then
    echo 0 > /sys/bus/usb/devices/1-1.4/authorized || true
    sleep 2
    echo 1 > /sys/bus/usb/devices/1-1.4/authorized || true
fi


/user-resource/ace-addon/ace-usb-power.sh --once || true

echo "ace-usb-harden live install done"
echo "autosuspend=$(cat /sys/module/usbcore/parameters/autosuspend 2>/dev/null)"
echo "quirks=$(cat /sys/module/usbcore/parameters/quirks 2>/dev/null)"
