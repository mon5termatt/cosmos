SUMMARY = "ACE Pro USB autosuspend / -71 hardening"
DESCRIPTION = "udev rules, usbcore quirks, hub stay-awake, and rate-limited \
hub reauth for Anycubic ACE Pro (28e9:018a) on Centauri Carbon."
LICENSE = "GPL-3.0-only"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/GPL-3.0-only;md5=c79ff39f19dfec6d293b95dea7b07891"

SRC_URI = "\
    file://98-ace-usb.rules \
    file://usbcore-ace.conf \
    file://ace-usb-power.sh \
    file://ace-usb-recover.sh \
    file://ace-usb-power.init \
    file://ace-usb-recover.init \
"

S = "${UNPACKDIR}"

inherit update-rc.d

# Two initscripts: update-rc.d class installs the primary; second is linked in do_install.
INITSCRIPT_NAME = "ace-usb-power"
INITSCRIPT_PARAMS = "defaults 22 78"

RDEPENDS:${PN} = "udev"

do_install() {
    install -d ${D}${sysconfdir}/udev/rules.d
    install -m 0644 ${S}/98-ace-usb.rules \
        ${D}${sysconfdir}/udev/rules.d/98-ace-usb.rules

    install -d ${D}${sysconfdir}/modprobe.d
    install -m 0644 ${S}/usbcore-ace.conf \
        ${D}${sysconfdir}/modprobe.d/usbcore-ace.conf

    install -d ${D}${sbindir}
    install -m 0755 ${S}/ace-usb-power.sh ${D}${sbindir}/ace-usb-power.sh
    install -m 0755 ${S}/ace-usb-recover.sh ${D}${sbindir}/ace-usb-recover.sh

    install -d ${D}${sysconfdir}/init.d
    install -m 0755 ${S}/ace-usb-power.init ${D}${sysconfdir}/init.d/ace-usb-power
    install -m 0755 ${S}/ace-usb-recover.init ${D}${sysconfdir}/init.d/ace-usb-recover
}

# Ensure recover also gets rc links (update-rc.d only handles INITSCRIPT_NAME).
pkg_postinst:${PN}() {
    if [ -n "$D" ]; then
        OPT="-r $D"
    else
        OPT="-s"
    fi
    update-rc.d $OPT ace-usb-recover defaults 23 77
}

pkg_prerm:${PN}() {
    if [ -z "$D" ]; then
        update-rc.d -f ace-usb-recover remove
    fi
}

FILES:${PN} = "\
    ${sysconfdir}/udev/rules.d/98-ace-usb.rules \
    ${sysconfdir}/modprobe.d/usbcore-ace.conf \
    ${sbindir}/ace-usb-power.sh \
    ${sbindir}/ace-usb-recover.sh \
    ${sysconfdir}/init.d/ace-usb-power \
    ${sysconfdir}/init.d/ace-usb-recover \
"
