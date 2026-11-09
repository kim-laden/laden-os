# Laden OS user guide

This describes the phase-1 live image. Read `docs/TEST-REPORT.md` for what has been booted. The current image includes The CockPit 1.1.0. A BIOS screenshot shows its terminal open. SSH targets are not configured, and Intel capture is off. The earlier image without CockPit passed BIOS and UEFI, including a fresh overlay after reset, and a BIOS session stayed unlocked for 330 seconds.

## What you get

Laden OS 0.1.0-live is a live desktop **based on Arch Linux**. It is not Arch Linux. The account is `live`. The password is locked. The local seat logs in by itself. The screen locker is off, because a locked password cannot clear it. That autologin and the lock setting are only for this live image. An installed system must not keep `/etc/plasmalogin.conf`, `/etc/sudoers.d/10-laden-live`, `/etc/xdg/kscreenlockerrc`, `/etc/xdg/powerdevilrc`, or the live polkit rule.

A reboot throws away the RAM overlay. Files you create, including `~/PROOF` and the service key under `/var/lib/laden-os`, do not survive. Persistence is not implemented.

## Desktop

Plasma on Wayland. The panel is on the top edge and the theme is Breeze Dark. Chromium is the default browser. Firefox stays installed. Dolphin, System Settings, fish, fastfetch, and btop are installed. The terminal is `lcp` (The CockPit). Alt+T opens it. Alt+Q shows or hides it. The shell greeting is `Laden OS — Let's do it!`. LCP opens as one 960×1024 pane. Commands, builtins, options, paths, quoted text, pipes, and errors use different colors. That size and those colors are in the profile for the next image. The 0.1.3 ISO does not include them.

The wallpaper is the AI-upscaled 8K file `/usr/share/backgrounds/laden/laden-os-lets-do-it-v2-7680x4320.png` (SHA-256 `b0abe88efdeb874912380894bcadf11b04e1773d33b926b76704741031c08b7f`). It is not a native 8K capture. Plasma scales that file to each display (`preserveAspectCrop`). The v2 1080p, 1440p ultrawide, and 4K files are in the same directory for a manual change. Nothing picks them automatically. A helper applies the default once, after Plasma is up, and then leaves a later choice alone.

`laden-layout` prints the primary output and the largest enabled output from kscreen. It does not rename connectors and it does not change the wallpaper.

## Network and remote access

NetworkManager is enabled. SSH is not installed, and `sshd.service` is masked. VNC and RDP are not enabled. There is no default password and no SSH key in the image.

## Packages

The live pacman configuration uses only `https://geo.mirror.pkgbuild.com`. Package signatures are required. Database signatures are optional because the official mirrors were not publishing `.db.sig` on 2026-11-08.

Refresh and upgrade together:

```bash
sudo pacman -Syu
```

Do not combine `-Sy` with a later partial `-S` of some other package. That is a partial upgrade.

The lab set is installed. `laden-lab` prints the command names. The signed BlackArch repository is enabled. Responder, the seclists wordlist dump, and the BloodHound desktop app are not installed. Creator applications and game libraries are not in this image. Intel capture is off.

Alt+T opens The CockPit. Alt+Q hides it if it is open, and opens it otherwise. Chromium's homepage is https://laden.no. The third panel icon, after the menu and the pager, is LCP.

Installing onto a disk is a separate step from this live image. Read `docs/INSTALL.md`. The 0.1.1 ISO does not contain the installer. The 0.1.2 ISO does, and that USB boots, but on it the Install menu did not open a window, Autopsy did not start, and Alt+T did not bind. 0.1.3 is the rebuild for those three, and it docks the top panel so the bar does not float and flicker. The Calamares window has not been click-tested. `laden-install` still refuses the Acer drive (Hynix serial `SME8N00091140886D`), this workstation's Kingston system disk, and the disk the system is running from. Calamares is not an Arch package. `scripts/build-calamares.sh` builds the pinned 3.4.2 source inside Laden OS. The virtual-disk result is in `docs/INSTALL-TEST-RECORD.md`.

## Hardware

Documented minimum RAM is 4 GiB. 8 GiB is the sensible amount. The QEMU test, when it is run, uses 6 GiB and no network card. NVIDIA drivers are not installed. Secure Boot is not supported; the image is unsigned.

## Build and test

```bash
scripts/build-iso.sh 1
scripts/test-boot.sh both build/out/laden-os-0.1.0-live-x86_64.iso
```

The test harness talks to a virtio port. It does not log in with a password. Do not write the ISO to a USB stick from these instructions until the BIOS and UEFI rows in the test report say Pass.
