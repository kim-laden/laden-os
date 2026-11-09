# Architecture

Laden OS 0.1.0-live is an archiso profile. The supported build entry point is `scripts/build-iso.sh`.

```
branding/                 wallpaper sources and checksums
profile/laden-os/         archiso profile
  packages.x86_64         phase-1 package names
  packages.d/             later groups, not installed yet
  pacman.conf             build-time official Arch repos
  airootfs/               live-system files copied in before pacstrap
scripts/build-iso.sh      rootless mkarchiso, asset checks, host-identity check
scripts/test-boot.sh      QEMU BIOS and UEFI tests against a file ISO
scripts/scan-secrets.py   publication scanner
third_party/cockpit/      pinned checksums only
build/                    gitignored work, cache, ISO, and logs
```

## Boot and filesystem

- BIOS: syslinux/isolinux from the `syslinux` package inside the image.
- UEFI: systemd-boot. The EFI binary comes from the image's systemd, not from the host bootloader.
- Root: squashfs, zstd level 15, mounted read-only by mkinitcpio-archiso.
- Writes: overlay on tmpfs, `cow_spacesize=2G`. Reboot drops the overlay.
- Label: `LADEN_OS`. Install directory on the ISO: `laden`.
- Kernel command line puts `console=tty0` last so the screen stays the primary console. `ttyS0` is an extra console for tests.

## Accounts and services

- `live` (uid 1000) is created in a build hook, shell fish, password locked with `passwd -l`.
- root is locked.
- Plasma Login Manager autologins `live` on the local seat (`Relogin=true`). Logout returns to that session. There is no password to type at the greeter if autologin fails; that is a known live-image tradeoff and the boot test has to show whether autologin actually works.
- sudo and polkit admin rights apply only to that local active user.
- SSH units are masked. OpenSSH is not installed.
- NetworkManager is enabled. `NetworkManager-wait-online.service` is masked so an offline boot does not sit on the network wait.
- Pacman keyring is a tmpfs created at boot by `pacman-init.service`. It is populated from `archlinux-keyring` in the image, not from the build host.
- Journald storage is volatile.
- udisks automount is disabled in the shipped KDE config.
- `laden-os-identity.service` generates an Ed25519 key under `/var/lib/laden-os` on each fresh boot. The private key is not part of the squashfs.
- `laden-os-status.service` writes a one-line report to the serial console.
- `laden-os-control.service` accepts `status` and `create-proof` on a virtio port when that port exists. It does not run a shell. Real hardware has no such port.

## Desktop

Plasma Desktop, Plasma Login Manager, Konsole, Dolphin, System Settings, Firefox, PipeWire, and the Mesa Intel/AMD Vulkan drivers. NVIDIA is documented and not installed in phase 1, because the open kernel module is a DKMS build and is untested here.

The wallpaper helper runs once per home directory and then leaves the user's choice alone. It always requests `/usr/share/backgrounds/laden/laden-os-lets-do-it-v2-7680x4320.png` and does not record success until Plasma has applied it.

`laden-layout` reads kscreen JSON and reports the priority-1 output and the largest enabled output. It contains no connector names.

## What is intentionally absent

Creator applications, Steam, Calamares, installed-disk persistence on the live ISO, and Secure Boot signing. The 0.1.1 image does include the lab list, linux-lts, and CockPit 1.1.0. Package-group files and the Calamares README stub remain the extension points. A persistent development VM is separate from the live ISO and is described in `docs/DEVELOPMENT.md`.
