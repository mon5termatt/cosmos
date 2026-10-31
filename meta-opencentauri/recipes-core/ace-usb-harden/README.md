# ace-usb-harden

OS-side mitigation for Anycubic ACE Pro USB flaps on Centauri Carbon
(`28e9:018a` behind QinHeng + Genesys hubs).

## What it installs

- `98-ace-usb.rules` — force `power/control=on` / no autosuspend on ACE + hubs
- `usbcore-ace.conf` — `autosuspend=-1`, quirk `28e9:018a:bk` (RESET_RESUME + NO_LPM)
- `ace-usb-power` — reinforcer that walks USB parents by path name every 30s
- `ace-usb-recover` — rate-limited hub `authorized` toggle after ≥20s gone + `-71`
  (Genesys `1-1.4` only — never the QinHeng `1-1` hub; WiFi lives there)

U-Boot bootargs (in `elegoo-centauri-carbon{1,2}.env`) also pass:

```
usbcore.autosuspend=-1 usbcore.quirks=28e9:018a:bk
```

## Live install (no image rebuild)

From a build host with SSH to the printer:

```sh
scp -r meta-opencentauri/recipes-core/ace-usb-harden/files \
  root@PRINTER:/tmp/ace-usb-harden
ssh root@PRINTER sh /tmp/ace-usb-harden/deploy-live.sh
```

Live deploy puts daemons under `/user-resource/ace-addon/` because `/usr` is
read-only on a running image. Image builds still install to `/usr/sbin`.

Quirks are best after a reboot with the new U-Boot env; sysfs write is best-effort.

## Primary install path (no image rebuild)

Ship and run from [cosmoace_afc](https://github.com/shawn-makes-stuff/cosmoace_afc)
`tools/ace-usb-harden/install.sh` on the printer. That is the supported
day-to-day path.

## OS patch (kernel + bootargs)

Branch `ace-usb-harden` patches Cosmos itself:

1. **U-Boot** `setargs_mainline` — `usbcore.autosuspend=-1` and
   `usbcore.quirks=28e9:018a:bgkno,05e3:0610:ko,1a86:8091:k`
2. **Kernel** `inject-ace-usb-quirks.py` (from `linux-mainline_%.bbappend`)
   inserts the same ACE + Genesys quirks into `drivers/usb/core/quirks.c`
   at configure time so a rebuilt `zImage` carries them without cmdline.

Live printers (no image rebuild yet):

```sh
sh tools/ace-usb-harden/patch-bootargs.sh   # fw_setenv + live sysfs
# power-cycle ACE if wedged, then reboot the printer
```

Optional package `ace-usb-harden` (udev + stay-awake daemons) is still
installable via the cosmoace_afc installer; it is **not** in
`CORE_IMAGE_EXTRA_INSTALL` by default.

## Validation (2026-10-31 live soak)

10-minute port soak on CC1 after live deploy: **0 flaps**, `link_online`
the whole window, 8/8 exclusive-lock probes blocked while AFC held the tty.
