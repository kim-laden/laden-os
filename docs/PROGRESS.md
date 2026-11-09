# Progress log

Times are local (CEST, UTC+1) on 2026-11-08. Commands were run from `/home/laden/Projects/LadenOS`. Build 3 reached a Plasma desktop. The freshness test did not finish.

## Implemented in the source tree

- Archiso profile `profile/laden-os/` for a phase-1 live desktop.
- Rootless build script `scripts/build-iso.sh` (phase 1 only).
- QEMU harness `scripts/test-boot.sh` (not yet run against an ISO).
- Secret scanner `scripts/scan-secrets.py` and unit tests. The profile scan passed. An extracted-image scan has not been run, because there is no image yet.
- Docs: requirements audit, architecture, implementation plan, acceptance checklist.

## Not implemented

CockPit, linux-lts, creator, gamer, and lab package groups, Calamares settings, persistence, Secure Boot signing, and a release signature.

## Build 1 — failed

Command:

```bash
scripts/build-iso.sh 1
```

Exit 1 after about 2 seconds of mkarchiso. Unit tests passed (7). Wallpaper checksums matched.

Pacman could not sync:

```text
error: failed retrieving file 'core.db.sig' from geo.mirror.pkgbuild.com : The requested URL returned error: 404
error: failed retrieving file 'extra.db.sig' from geo.mirror.pkgbuild.com : The requested URL returned error: 404
error: failed retrieving file 'multilib.db.sig' from geo.mirror.pkgbuild.com : The requested URL returned error: 404
==> ERROR: Failed to install packages to new root
```

mkarchiso then printed `Packages installed successfully` and died on `cp` of a missing `/boot`. Cause: `pacstrap -N` has no `set -e`. The inner unshare exits 1, and the outer pacstrap still returns 0. The build script now treats that pacstrap line as failure.

Checked the same day, without downloading a database signature body:

| URL | HTTP |
|---|---|
| `https://geo.mirror.pkgbuild.com/core/os/x86_64/core.db` | 200 |
| `https://geo.mirror.pkgbuild.com/core/os/x86_64/core.db.sig` | 404 |
| `https://geo.mirror.pkgbuild.com/extra/os/x86_64/extra.db.sig` | 404 |
| `https://geo.mirror.pkgbuild.com/multilib/os/x86_64/multilib.db.sig` | 404 |
| `https://mirror.pkgbuild.com/core/os/x86_64/core.db.sig` | 404 |
| `https://berlin.mirror.pkgbuild.com/core/os/x86_64/core.db.sig` | 404 |

Fix: `SigLevel = Required DatabaseOptional` in the build config and the live config. Package signatures stay required. This matches archiso 92. `DatabaseRequired` cannot sync against these mirrors.

## Package resolution — passed, before build 2

```bash
unshare --map-auto --map-root-user pacman --config profile/laden-os/pacman.conf \
  --dbpath build/pacman-db -Sy --noconfirm --disable-sandbox
```

Sync exit 0. Databases: `core.db`, `extra.db`, `multilib.db`.

```bash
unshare --map-auto --map-root-user pacman --config profile/laden-os/pacman.conf \
  --dbpath build/pacman-db -Sp --print-format '%n' --disable-sandbox -- \
  $(grep -E '^[^#[:space:]]' profile/laden-os/packages.x86_64)
```

Resolve exit 0. 61 explicit names, 661 packages including dependencies. No explicit name was missing. The dependency set picked `iptables`, `noto-fonts-emoji`, and `qt6-multimedia-ffmpeg` when pacman prompted during build 2. Those three names were added to `packages.x86_64` after build 2 had already copied the profile, so this ISO's explicit list is the copy without those three lines. The installed set still contains them.

A plain `pacman -Sy` without a user namespace fails with `you cannot perform this operation unless you are root`. The preflight uses `unshare` and `--dbpath build/pacman-db`. It does not write the host databases.

## Build 2 — ISO file produced, not yet boot-proven

Command, started 17:59, finished 18:03, exit 0:

```bash
scripts/build-iso.sh 1
```

Produced:

- `build/out/laden-os-0.1.0-live-x86_64.iso`
- size 1.9G (984384 sectors, 1923 MiB)
- SHA-256 `54b213070d06ffed36f4aff24972ea46d9de0bdc6d83175c5ccf38817aef92d0`
- `build/out/PACKAGES.txt` has 661 packages
- squashfs 1614.29 MiB, zstd, 41.61% of the uncompressed tree

`xorriso -report_el_torito` reports an isohybrid MBR and an El Torito EFI image. Volume id is `LADEN_OS`. `file` reports a bootable ISO 9660 image.

Host identity files were unchanged. No mounts were left under `build/work`. The live account in the work root is `live` uid 1000, shell `/usr/bin/fish`. `root` and `live` shadow fields are `!*` and `!`. `/etc/machine-id` is `uninitialized`. `os-release` says Laden OS 0.1.0-live (based on Arch Linux). `sshd.service` points at `/dev/null`.

mksquashfs printed the host name `laden` for uid 1000 because this workstation's account is also uid 1000. The squashfs stores the number. Inside the image that number is the `live` user. There is no `laden` account in `passwd`.

Initramfs warned that `/etc/vconsole.conf` is missing and that three POSIX ACL xattrs were not stored. Neither stopped the build.

## Image scan and boot tests — running

Started 18:08, against that ISO file only:

```bash
scripts/scan-image.sh build/out/laden-os-0.1.0-live-x86_64.iso
scripts/test-boot.sh bios build/out/laden-os-0.1.0-live-x86_64.iso
scripts/test-boot.sh uefi build/out/laden-os-0.1.0-live-x86_64.iso
```

BIOS and UEFI both reached the kernel and then failed in the initramfs. UEFI waited for `/dev/gpt-auto-root` and dropped to emergency mode. BIOS reported `Failed to start Switch Root` and did the same. The root account is locked, so sulogin could not open a shell. Screenshots are in the `build/test-results/*-20261108-180824/` directories. The guests were stopped after the screenshots.

Cause: the initramfs was built with the distribution's systemd hooks. It did not include the `archiso` hook, so `archisobasedir=` and `archisosearchuuid=` on the boot line were ignored. `profile/laden-os/airootfs/etc/mkinitcpio.conf.d/archiso.conf` now sets the archiso hook list. PXE hooks are not included. `/etc/vconsole.conf` sets `KEYMAP=us`, which removes the initramfs warning from build 2.

The secret scan's first 21 hits were header strings in manuals, MIME magic, and libraries. The scanner now requires a PEM block with a body. The rescan found PEM blocks only inside GnuTLS 3.8.13-3 (`gnutls-cli` and `libgnutls.so.30.42.0`). Those are upstream self-test keys. They are listed in `scripts/scan-allowlist.txt`. No host home path and no Laden service private key were in the squashfs.

The secret scanner was adjusted after this build started. Findings under a scan root that merely lives inside a directory named `build` are no longer skipped, nested `build` directories still are, and a bare `ghp_` string is not treated as a token. `python3 -m unittest discover -s tests -v` then reported 9 tests OK. The image scan started with the boot tests.

Boot-test risk, not yet observed: `laden-os-control.service` reads the virtio port once. If that read returns end-of-file before the test connects, `create-proof` will not be handled. The harness also accepts SSH state `not-installed`; this image masks `sshd.service` and does not install OpenSSH, so a passing line may say `not-installed` rather than `masked`.

Host constraints held: no sudo, no write to a block device, no package install into the host OS.

## Build 3 — Plasma reached, freshness not tested

Command finished 18:18, exit 0:

```bash
scripts/build-iso.sh 1
```

The initramfs log shows the drop-in `archiso.conf` and the hooks `archiso` and `archiso_loop_mnt`. There is no systemd hook. Both boot entries contain `archisobasedir=laden archisosearchuuid=2026-11-08-17-17-04-00 cow_spacesize=2G`.

Produced `build/out/laden-os-0.1.0-live-x86_64.iso`, 1863024640 bytes, SHA-256 `50d5569cd90fe01ca800f24507246772f0da93e376e86a6590f69f4fad59f66f`. This replaced the build 2 file. Host identity was unchanged.

BIOS and UEFI guests, started 18:18:

```bash
scripts/test-boot.sh bios build/out/laden-os-0.1.0-live-x86_64.iso
scripts/test-boot.sh uefi build/out/laden-os-0.1.0-live-x86_64.iso
```

First serial status:

| Firmware | uptime_s | plasma | proof | ssh | mem_available_kb | fingerprint |
|---|---|---|---|---|---|---|
| BIOS | 6.25 | up | absent | masked | 5436720 | `5112a422431635b7f8530544f5e3a17c7ebb7ab45ff8e9bd41666808d7b54363` |
| UEFI | 5.55 | up | absent | masked | 5417892 | `28be29b1e17e41e917f7d1c02a96576622b4f7ca9005e53ff8b63568413dbfa9` |

Listeners were `127.0.0.54:53`, `127.0.0.53%lo:53`, `0.0.0.0:5355`, and `[::]:5355`. No port 22. Screenshots `build/test-results/bios-20261108-181834/desktop.png` and `build/test-results/uefi-20261108-181834/desktop.png` show the Plasma desktop, the “Let's do it!” wallpaper, Firefox, and the panel. The greeter was not on that screen.

The harness sent `create-proof`. Those 13 bytes stayed in the host socket. The guest never printed `proof=present`. `control-port` read the virtio port once and exited when QEMU returned end-of-file before the client connected. It now reopens the port.

About five minutes after the desktop appeared, kscreenlocker locked both sessions. The live password is locked, so the lock screen could not be cleared. BIOS showed the password field for “Laden OS live user”. Both harnesses then exited 1 with `timed out waiting for boot status` and stopped QEMU. BIOS log `build/logs/boot-bios.log`. UEFI log `build/logs/boot-uefi.log`. Freshness was not tested. The image is not release-ready. The file is kept as `build/out/laden-os-0.1.0-live-x86_64.iso.50d5569c`.

Cause of the lock: kscreenlocker 6.8.2 defaults to `Autolock=true` and `Timeout=5` minutes. The live account has no password. `/etc/xdg/kscreenlockerrc` now turns autolock off, and PowerDevil is set not to lock before turning the display off. `logind` idle action is `ignore`.

## Build 4 — freshness passed on BIOS and UEFI

Command finished 18:32, exit 0. SHA-256 `afd71eb1c0e43ae71de460658df54590918135e718d40bbe040f60a8b7692d23`. Size 1863024640 bytes. The squashfs contains the control-port reopen loop and `Autolock=false`.

```bash
scripts/test-boot.sh bios build/out/laden-os-0.1.0-live-x86_64.iso
scripts/test-boot.sh uefi build/out/laden-os-0.1.0-live-x86_64.iso
```

Both printed `PASS` and `firmware=… status=0`. After reset, `proof=absent` and the fingerprint changed on each firmware. SSH stayed `masked`. No port 22. Details are in `docs/TEST-REPORT.md`.

The BIOS screenshot taken at the first `plasma=up` is still the Plasma splash. The screenshot taken after `proof=present` is the desktop. UEFI showed the desktop on the first screenshot.

The secret scan of build 3 (`50d5569c`) exited 0. Findings were only the two reviewed GnuTLS test files.

`scripts/scan-image.sh` on the build 4 ISO also exited 0. Log `build/logs/scan-afd71eb1.log`. Same two GnuTLS files, wallpaper hashes match, and the structural checks passed.

The CockPit 1.1.0 tarball in `build/cache` matches SHA-256 `72349d6983827d6a50acbdb5850b46aaa30213e9ecc8bb89f1e57c1d00943eb1`. `install.sh` was read and not executed on the host. It installs per user, leaves Intel capture off, and ships a commented-out SSH example. The next image build is prepared to run it inside the root with `--prefix /usr --no-bundled`, using Arch `wezterm`. That build has not started. The idle guest still has the current ISO open.

## Idle check — BIOS passed

```bash
LADEN_IDLE_SECONDS=330 scripts/test-boot.sh bios build/out/laden-os-0.1.0-live-x86_64.iso
```

Exit 0. After reset, `proof=absent` and the fingerprint changed again. `build/test-results/bios-20261108-183714/idle.png` is the desktop, clock 5:43 PM. The frame from the start of that wait is 5:37 PM. kscreenlocker did not take over. UEFI was not left idle.

## CockPit image built, not boot-tested

`scripts/build-iso.sh 1` exited 0. SHA-256 `3a9eb94089088a2a41861fab886fc29e83786692236ce227359b76d594fc53d4`. Size 1907900416 bytes. The build log contains `CockPit 1.1.0 installed. Intel capture is not started.` The squashfs has `/usr/bin/cockpit`, `/usr/bin/wezterm`, and `/usr/share/the-cockpit/VERSION` equal to `1.1.0`. `home/live/.config/the-cockpit/connections.lua` has no active SSH entry. The tarball is not in the squashfs. Host identity comparison did not fail (the script exits 3 on a mismatch, and the build exited 0).

This file has not been booted. The previous pass belongs to `afd71eb1…`, preserved as `build/out/laden-os-0.1.0-live-x86_64.iso.afd71eb1`.

## CockPit image booted

Both `scripts/test-boot.sh` runs printed `PASS`. BIOS first Plasma at 5.88 s, UEFI at 6.05 s. After reset, `proof=absent` and the fingerprint changed on each firmware. `pipewire=up` on every status line. `ssh=masked`. Screenshots are the desktop. Details are in `docs/TEST-REPORT.md`.

`scripts/scan-image.sh` on `3a9eb940…` exited 0. The only PEM findings are the two reviewed GnuTLS files. Log `build/logs/scan-3a9eb940.log`.

A BIOS guest launched `/usr/bin/cockpit`. `build/test-results/bios-cockpit-open-20261108/cockpit.png` shows the fish prompt `live@laden-os` and the greeting `Laden OS — Let's do it!`. SSH, the hardware view, and Intel capture were not used.

## LTS image — both kernels booted

SHA-256 `02e096f05c9141ac9efeeed35b3b8e3eadfbb7807976439ad147aac6875307a5`. Size 2226241536 bytes.

Default entry: BIOS and UEFI harnesses printed `PASS`. `kernel=7.2.14-arch1-1`. After reset, `proof=absent` and the fingerprint changed.

LTS entry, selected from the menu: BIOS `plasma=up` at 5.68 s and UEFI at 5.74 s, both `kernel=6.18.60-1-lts`, `ssh=masked`, `pipewire=up`. Screenshots are the desktop. The proof reset was not repeated on the LTS kernel.

`scripts/scan-image.sh` exited 0. Only the two reviewed GnuTLS files. Log `build/logs/scan-02e096f0.log`.

## Lab image — Kali daily set and BlackArch forensics

`scripts/build-iso.sh 1` exited 0 at 20:04. SHA-256 `22732d306e9d6096020e1a9399cb0c6af22f6e088a861f77e84fbbc3e33d44ad`. Size 6402670592 bytes. The 18:54 desktop image is `build/out/laden-os-0.1.0-live-x86_64.iso.02e096f0`.

`packages.d/lab.txt` is the explicit set. Pacman resolved 1068 packages and reported 12053.14 MiB installed. The closure does not contain `mingw-w64-gcc`, `seclists`, `neo4j-community`, or `jdk17-openjdk`.

BIOS and UEFI harnesses at 6144 MiB printed `PASS` on the default kernel. A separate BIOS boot opened LCP with Alt+T. BIOS at 256 MiB and 512 MiB unpacked the initramfs and reached userspace. The picture at those sizes was not a drawn desktop. `linux-lts` was not booted on this file.

`scripts/scan-image.sh` exited 1. The new hits are upstream tool material, not workstation paths. Details are in `docs/TEST-REPORT.md`.

## Remaining

1. Creator, gamer, and Calamares are not in the image.
2. The lab image secret scan did not pass. No GPG signature. Secure Boot is unsigned. Not release-ready.
3. `linux-lts` on this file, Alt+Q on its own, Chromium, and a real VMware boot were not tested.
