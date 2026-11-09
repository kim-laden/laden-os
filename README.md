# Laden OS

Unofficial live system **based on Arch Linux**. It is not Arch Linux.

Phase 1 is a BIOS and UEFI live desktop: KDE Plasma on Wayland, Plasma Login Manager, fish, fastfetch, btop, Firefox, and NetworkManager. The image boots from a squashfs with a RAM overlay, so a normal reboot is a fresh system. SSH is masked. Intel capture is off. Service keys are created on each boot.

The default wallpaper is `branding/laden-os-lets-do-it-v2-7680x4320.png` (SHA-256 `b0abe88efdeb874912380894bcadf11b04e1773d33b926b76704741031c08b7f`). It is AI-upscaled 8K artwork, not a native 8K capture. Plasma scales that one file to every display. The other v2 resolutions are optional manual choices. The older HP wallpaper is not installed.

## Development VM

Day-to-day changes go to a persistent VMware VM, not a new ISO. The commands and the safety limits are in `docs/DEVELOPMENT.md`.

```bash
scripts/dev-vm.sh create
scripts/dev-vm.sh start
scripts/dev-vm.sh sync --dry-run
scripts/dev-vm.sh sync
```

`scripts/release-iso.sh` is the separate release build. It does not run as part of `dev-vm.sh`.

## Build

The build uses archiso 92 as a normal user, through user namespaces. It does not install packages onto the host and it refuses block devices.

```bash
scripts/build-iso.sh 1
```

Output, when the build succeeds:

- `build/out/laden-os-0.1.0-live-x86_64.iso`
- `build/out/SHA256SUMS`
- `build/out/PACKAGES.txt`

`build/` is local work space and is not part of the source. Do not copy a workstation home directory, SSH configuration, or journal into it.

## Boot test

```bash
scripts/test-boot.sh both build/out/laden-os-0.1.0-live-x86_64.iso
```

The test uses QEMU and a file-backed ISO. It does not write a USB stick or a physical disk.

## Status

Read `docs/TEST-REPORT.md` before treating an ISO as bootable. A file on disk is not a passing boot test.

The lab package list is part of the 0.1.1 live image. Creator, gamer, and Calamares are not. The CockPit 1.1.0 checksum is in `third_party/cockpit/`. Read `docs/TEST-REPORT.md` and `docs/DEV-VM-TEST-RECORD.md` for what was actually booted. The image is not release-ready.
