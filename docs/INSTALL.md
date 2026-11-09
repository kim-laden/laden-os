# Install Laden OS

Laden OS installs as a normal writable system. The live ISO is the package source. It is not copied onto the disk with `dd`. The target is partitioned, the squashfs is unpacked, and the install then builds its own fstab, initramfs, and bootloader.

This does not touch the workstation's disks. `scripts/install-disk.sh` refuses `/dev`, block devices, and `build/dev-vm/laden-os-dev.raw`. A device install refuses to run unless it is the live image, and it still refuses the disk the system is running from plus every disk in `protected-disks.txt`.

## What the installer does

GPT layout:

| Partition | Size | Filesystem | Mount |
| --- | --- | --- | --- |
| ESP | 512 MiB | FAT32, label `LADENESP` | `/boot` |
| swap | 2 GiB | swap | swap |
| root | the rest | ext4 | `/` |

`/etc/fstab` uses those UUIDs. `mkinitcpio` builds an initramfs without the archiso hook. systemd-boot is installed on that disk's own ESP, including `EFI/BOOT/BOOTX64.EFI`. The kernel command line is `root=UUID=… rw rootfstype=ext4`.

At install time the target gets a new `/etc/machine-id` and a new ED25519 service key. These are not copied from the live image or from the machine running the installer. The live account, live autologin, live sudo rule, live polkit rule, live screen-lock overrides, and the build-only pacman hooks are removed. The live sentence in `/etc/motd` is rewritten so the installed system does not say the session is discarded on reboot. `sshd` stays masked. SSH host keys and authorized keys are removed. No password is stored in the profile.

The account password is chosen during install. Calamares asks for it. The virtual-disk test reads it from `build/install-vm/password`, which is mode 600 and is not part of the image. The account is in the `wheel` group. `sudo` asks for that password. It is not `NOPASSWD`.

The default wallpaper is `/usr/share/backgrounds/laden/laden-os-lets-do-it-v2-7680x4320.png` (SHA-256 `b0abe88efdeb874912380894bcadf11b04e1773d33b926b76704741031c08b7f`). Any leftover v1 path is rewritten to that file. Plasma scales it with `preserveAspectCrop`. CockPit Intel capture stays off. The shipped connections file has no active SSH entry.

The desktop files come from the current profile: top panel, Breeze Dark, the LCP launcher, and the lab tools that are already in the 0.1.1 squashfs. Creator and gamer applications are not added. Nothing is copied from the ladenx account.

## Virtual disk

```bash
scripts/install-disk.sh
scripts/test-installed-boot.sh
```

The first command builds `build/install-vm/laden-os-install.raw` from `build/out/laden-os-0.1.1-live-x86_64.iso` plus the current profile. The second boots that file in QEMU with UEFI and no ISO attached. Both refuse a host device path.

`scripts/install-disk.sh --replace` builds the image again.

## Live USB, later

Boot a Laden OS USB that contains this installer. The 0.1.1 ISO does not. The 0.1.2 ISO does and boots; on that stick the menu did not open the window. 0.1.3 keeps the Wayland display when the installer starts. From that USB:

```bash
sudo laden-install
```

Calamares runs `install-finalize prepare` before it creates the account and `install-finalize finish` before it installs systemd-boot. The protected-disk list is still applied, and the disk the USB is running from is not offered.

A direct device install exists for that same live session:

```bash
sudo /usr/lib/laden-os/install-system --device /dev/disk/by-id/… --user NAME --password-file /root/password --erase
```

The password file must be mode 600. `--erase` is required. This command has not been executed. Do not run it on the Acer drive until the gates below are done.

## Before an Acer install

The Acer disk (Hynix serial `SME8N00091140886D`, model `HFS001TEJ9X125N`) and this workstation's Kingston disk are still named in `protected-disks.txt`. A USB boot on the Acer would refuse that drive until that Acer rule is removed on purpose. The Kingston rule and the running-disk rule should stay.

Also still required:

- 0.1.3 is the ISO with the installer display fix. Do not overwrite `laden-os-0.1.1-live-x86_64.iso` or `laden-os-0.1.2-live-x86_64.iso`. The Calamares window is still not a click-through test.
- Boot that ISO in a VM with a second, empty virtual disk and run the installer from inside the live session. The test in this tree installs from the host into an image file. It is the same populate, fstab, initramfs, and bootloader steps. It is not a click-through of the Calamares window.
- Scan that ISO before anyone writes a USB.
- The image is unsigned. Secure Boot stays off.

The result of the virtual-disk boot is in `docs/INSTALL-TEST-RECORD.md`.
