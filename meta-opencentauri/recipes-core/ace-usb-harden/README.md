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

## Optional Cosmos image / bootargs

This recipe stays in the Yocto tree for optional image inclusion. It is
**not** added to `CORE_IMAGE_EXTRA_INSTALL` by default.

U-Boot env files for carbon-1/2 on branch `ace-usb-harden` append:

```
usbcore.autosuspend=-1 usbcore.quirks=28e9:018a:bk
```

To bake into a custom image: `IMAGE_INSTALL:append = " ace-usb-harden"` (or
add to `cosmos-image-base.bb`), bitbake, flash. Bootargs need the new U-Boot
env written; until then live deploy sets sysfs `autosuspend`/`quirks`
best-effort.

## Validation (2026-10-31 live soak)

10-minute port soak on CC1 after live deploy: **0 flaps**, `link_online`
the whole window, 8/8 exclusive-lock probes blocked while AFC held the tty.
