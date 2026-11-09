# Install test record

Date: 2026-11-09. Host install into an empty virtual disk, then QEMU UEFI with no ISO attached. No physical disk was written. The running development VM was left running. The 0.1.1 ISO file was not overwritten.

Image: `build/install-vm/laden-os-install.raw` (28 GiB sparse raw file).
Install log: `build/install-vm/logs/install.log` (finished 2026-11-09T10:10:27+01:00).
Boot evidence: `build/install-vm/boot-20261109-102943/`.
Earlier boots of the same image: `boot-20261109-101334` (harness raced the shell), `boot-20261109-101931` (same race), `boot-20261109-102233` (desktop reached; key check ran as the user and was denied).

The account password is only in `build/install-vm/password` (mode 600). It is not in this record and it is not in the image except as a password hash. This test image has a serial getty because `scripts/install-disk.sh` passed `--serial-getty`. A Calamares install does not.

## How it was built

`scripts/install-disk.sh` unpacked `build/out/laden-os-0.1.1-live-x86_64.iso` (squashfs, not `dd` of the ISO), overlaid the current profile, and ran `install-finalize`. The target file was partitioned GPT:

| Partition | Size | Filesystem | Mount |
| --- | --- | --- | --- |
| ESP, name `laden-esp`, label `LADENESP` | 512 MiB | FAT32 | `/boot` |
| swap, name `laden-swap` | 2 GiB | swap | swap |
| root, name `laden-root` | the rest | ext4 | `/` |

`parted` on the file reports that layout. The ext4 superblock UUID is `5d873a0b-eead-46f7-beff-9facb532d8ad`. The swap header is `SWAPSPACE2` with UUID `dd970b8f-ba1b-4087-9f0d-bdcdc3c60a53`. `mkswap` warned that the swap image was sparse. The booted guest still activated `/dev/vda2`.

`/etc/fstab` in the guest uses those UUIDs. The root is ext4, mounted `rw,relatime`. systemd-boot on that ESP booted the guest under OVMF. `EFI=yes`.

## What the guest showed

Serial login as `laden` (uid 1000) with the install password, then the same password typed into the graphical login, reached Plasma.

`boot-20261109-102943/greeter.png` is the login clock (default blue/orange background, not the v2 artwork), before any graphical key was sent.
`desktop.png` from the previous successful login (`boot-20261109-102233`) and the desktop behind the terminal in `boot-20261109-102943/cockpit-manual.png` show the v2 artwork filling the screen: circuit-board "LADEN", the slogan "Let's do it!", and a dark panel on the top edge.
`cockpit-manual.png` shows a terminal window on that desktop. The window text is `Laden OS — Let's do it!` and the prompt is `laden@laden ~>`.

Guest facts from that boot:

| Check | Result |
| --- | --- |
| User | `laden`, uid 1000 |
| machine-id | `27b1a719031448c4affea69d802ea1f9` |
| Host machine-id | different 32-hex value |
| Service key | directory mode 700, key mode 600, fingerprint mode 644 |
| Unprivileged read of the key and fingerprint | denied |
| `openssl pkey` as root via `sudo` | yes |
| Fingerprint | `dfdbab80a01d59c30a73f3ad33a46d176377e15b01206e71c9d7f72d3e32fd42` (same value `install-finalize` wrote at install time) |
| Wallpaper file SHA-256 | `b0abe88efdeb874912380894bcadf11b04e1773d33b926b76704741031c08b7f` |
| Plasma config image | `laden-os-lets-do-it-v2-7680x4320.png` |
| Wallpaper helper marker | present |
| Intel capture in `product.conf` | `off` |
| CockPit connections | file present, no active `{` entry |
| CockPit version / `lcp` | 1.1.0, `/usr/bin/lcp` |
| Live autologin, live sudo, live polkit, live user | absent |
| Dev sudo and dev ssh config | absent |
| `sshd.service` | symlink to `/dev/null` |
| SSH host keys | 0 |
| `sudo -n` | password required |
| `NOPASSWD` in the installer sudo rule | no |
| Initramfs contains archiso | no |
| Swap | `/dev/vda2` |
| Hostname | `laden` |
| plasmashell after graphical login | up |

The harness exited 1 on this boot because `KEY_ROOT=yes` was glued to a terminal-integration sequence and the checker missed it. The serial log contains `KEY_ROOT=yes` and the fingerprint above. The checker now strips those sequences. That change was not given another boot.

## Matrix

| Item | Result | Evidence |
| --- | --- | --- |
| Empty virtual disk only; no host disk, no Acer, no Kingston | Pass | Installer refuses `/dev` and the dev VM raw file. `parted` was pointed at the raw file. `vmrun` still lists only `build/dev-vm/laden-os-dev.vmx`. |
| GPT, own ESP, root, swap, UEFI | Pass | `parted` print; guest `EFI=yes`; boot with no ISO. |
| Real writable system, not a copy of the ISO | Pass | ext4 `rw`; fstab by UUID; install log shows unsquash, `mkinitcpio`, and `mkfs.ext4 -d`. |
| Fresh machine-id and service key | Pass | Values above. They differ from the host machine-id. The user cannot read the private key. |
| Live autologin, live sudo, live user, dev access removed | Pass | Guest checks above. |
| New user, password set at install | Pass | Serial login and graphical login both accepted that password. `sudo -n` fails. |
| v2 wallpaper, scaled | Pass | Hash, Plasma image path, marker, and the desktop screenshots. The login clock does not use v2. |
| CockPit launches, capture off | Pass, with a limit | `lcp` started in the Plasma session and the window is in `cockpit-manual.png`. `product.conf` is `off` and the connections file has no entry. The capture switch was not clicked. |
| Alt+T starts CockPit | Not shown | The user shortcut file contains `Alt+T`. QEMU `sendkey alt-t` did not start a process (`COCKPIT_PROC=down`). |
| Plasma top panel and dark desktop | Pass | Screenshots. Applet ids were not read back from the running session. |
| Installed motd does not say the session is discarded | Fail on the booted image | Serial motd still says `The live session is discarded on reboot.` `install-finalize` now rewrites that sentence. The unit test covers the rewrite. This image was built before that change, so the rewrite has no VM boot. |
| Calamares window on an empty second disk | Untested | The 0.1.1 ISO does not contain Calamares or `install-finalize`. |
| `install-system --device` | Untested | Implemented. Not executed. It refuses to run unless it is a Laden OS live session. |
| Physical Acer install | Not done | Out of scope. No host disk was written. |
| Secret scan, signatures, Secure Boot | Not done | Publication stays blocked. |

`python3 -m unittest discover -s tests -q` passed: 18 tests, including the motd rewrite inside the existing finalize test.

## Before an Acer USB install

Do this from a boot of a new installer USB, not from this workstation.

1. Build a new ISO that contains `install-finalize`, `install-system`, and the Calamares binary. Do not overwrite `build/out/laden-os-0.1.1-live-x86_64.iso`.
2. Scan that image for secrets before writing a USB.
3. Boot that ISO in a VM with a second, empty virtual disk and run the installer from inside the live session. The test above used the same populate, fstab, initramfs, and bootloader steps from the host. It was not a click-through of Calamares, and `--device` was not run.
4. `protected-disks.txt` still names the Acer disk (Hynix serial `SME8N00091140886D`, model `HFS001TEJ9X125N`, label `Acer`) and the Kingston system disk. A USB boot on the Acer would refuse that drive until the Acer identity rule is removed on purpose. Keep the Kingston rule and the running-disk rule.
5. The image is unsigned. Secure Boot stays off. Do not publish.
6. On that USB session, confirm Alt+T opens CockPit. This virtual test did not.
