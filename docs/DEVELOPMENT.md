# Laden OS development

Use the persistent VM for day-to-day changes. Build an ISO only when you mean to cut a release. Neither path installs packages on the host, writes a USB stick, or attaches a physical disk.

## Development VM

VMware Workstation, UEFI, NAT (`vmnet8`), 8 GiB RAM, 4 vCPU, a 24 GiB sparse disk. The NIC is `e1000e` on a PCIe root port. USB, bridged networking, shared folders, and the host home directory are off. Firmware variables, the disk, the dev SSH key, and logs stay in `build/dev-vm/`. That directory is gitignored. SSH reaches the guest `dev` account on the NAT address only. Nothing is published on the host's public interfaces.

```bash
scripts/dev-vm.sh create
scripts/dev-vm.sh start
scripts/dev-vm.sh status
scripts/dev-vm.sh stop
scripts/dev-vm.sh snapshot NAME
scripts/dev-vm.sh restore NAME
```

`create` refuses to replace an existing disk. Snapshot and restore refuse to run while the VM is powered on. `stop` asks the guest to shut down and does not force the power off. A snapshot writes a sparse delta disk beside the base image, still under `build/dev-vm/`. Do not delete those `laden-os-dev-00000N.vmdk` files by hand while the snapshot exists.

The disk is a writable installed system built from `build/out/laden-os-0.1.1-live-x86_64.iso` plus the current profile. It is not the live ISO attached to an empty data disk. The graphical seat still autologins as `live`, which matches the live image under test. A separate `dev` account is the only SSH login. Its key and `sudo` rule are created by `create` and are not in `profile/`.

## One source of truth

`profile/laden-os/` and `branding/` feed both the VM and `scripts/release-iso.sh`.

```bash
scripts/dev-vm.sh sync --dry-run
scripts/dev-vm.sh sync
```

Sync copies the profile overlay and the v2 wallpapers. It does not copy the archiso initramfs hook or the live SSH masks (`profile/laden-os/dev-vm-sync-exclude.txt`). It does not copy the host user's ownership onto guest files. It deletes guest files only inside the directories listed in `profile/laden-os/dev-vm-sync-owned.txt`, and it refuses that delete when the source directory is empty. The log is `build/dev-vm/logs/sync-*.log`. A dry run prints the rsync itemize list and does not change the guest.

Package names in `packages.x86_64` and `packages.d/lab.txt` are installed in the guest when they are missing. Sync does not remove extra packages and it does not upgrade the world. Creator, gamer, and Calamares lists are not applied.

A reboot is required after a kernel, initramfs, module, or systemd system-unit change. Wallpaper, menu, and application configuration do not need a reboot or a new ISO. The wallpaper helper runs once per home, after Plasma is up, and then leaves that user's later choice alone. Skel applies the default to a new user.

These changes need a reboot of the guest, or a new ISO if you also want them on the live image:

- kernel, microcode, or `/boot`
- `/usr/lib/modules`
- systemd system units
- `mkinitcpio` configuration

## Release

```bash
scripts/release-iso.sh
```

That command uses a fresh work directory, refuses to overwrite `build/out/laden-os-<version>-x86_64.iso`, checks the embedded wallpaper and that `/home/laden` and the dev key did not leak, runs `scripts/scan-image.sh`, writes checksums and the package list, and boot-tests BIOS and UEFI with `scripts/test-boot.sh`. It does not publish. The current lab image fails the secret scan, so a release of this package set stops there until that scan is clean. Bump `iso_version` in `profile/laden-os/profiledef.sh` before building another ISO of the same name.

A VM boot does not prove physical GPU, gaming, Wi-Fi, or USB hardware. Those stay untested until they are exercised on that hardware.
