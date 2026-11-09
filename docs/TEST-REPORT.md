# Test report

Date: 2026-11-08. This is not a release. No GPG signature. Secure Boot is unsigned.

## Lab image — current file

File: `build/out/laden-os-0.1.0-live-x86_64.iso`

SHA-256 `22732d306e9d6096020e1a9399cb0c6af22f6e088a861f77e84fbbc3e33d44ad`

Size: 6402670592 bytes. Built 2026-11-08 20:04. The previous desktop image is kept as `build/out/laden-os-0.1.0-live-x86_64.iso.02e096f0`.

The package list is the desktop plus `packages.d/lab.txt`: the Kali tools people run, then the BlackArch forensic tools. 1068 packages resolved. Installed size reported by pacman: 12053.14 MiB. Responder, seclists, the BloodHound desktop app, and `blackarch-officials` are not in the image.

Default kernel `7.2.14-arch1-1`:

| Check | Result |
|---|---|
| BIOS 256 MiB | Initramfs unpacked. Serial reached `laden-os login` and `plasma=up` (`mem_available_kb=37532`). The framebuffer was a black screen. A usable desktop is not claimed at 256 MiB. |
| BIOS 512 MiB | Same. `plasma=up` with `mem_available_kb=227796`. The picture was a cursor on black. |
| BIOS 6144 MiB harness | `PASS`. First fingerprint `6395f293…`, after reset `416f3046…`, `proof=absent`, `ssh=masked`, no port 22. Screenshot `build/test-results/bios-20261108-201147/desktop.png` shows the top dark panel and the “Let's do it!” wallpaper. |
| UEFI 6144 MiB harness | `PASS`. First fingerprint `988bb5db…`, after reset `e0091352…`, `proof=absent`, `ssh=masked`, no port 22. Screenshot `build/test-results/uefi-20261108-201325/desktop.png`. |
| Alt+T | On a separate BIOS boot at 6144 MiB, `sendkey alt-t` opened LCP at `live@laden-os`. Alt+Q was not pressed on its own. |

`linux-lts` was not booted on this file. Real VMware was not driven. Chromium was not opened.

`scripts/scan-image.sh` exited 1. Wallpaper hashes matched, `machine-id` stayed `uninitialized`, and there was no `/home/laden` hit. The scanner reported 126 private-key and aws-key hits inside upstream lab packages (Nuclei templates, Exploit-DB, Metasploit fixtures and docs, Python test certificates, and three binaries). Those paths are not on the GnuTLS allowlist. The image is not release-ready.

## LTS image — default kernel and LTS entry both reached Plasma

File: `build/out/laden-os-0.1.0-live-x86_64.iso`

SHA-256 `02e096f05c9141ac9efeeed35b3b8e3eadfbb7807976439ad147aac6875307a5`

Size: 2226241536 bytes. Default menu entry is `linux`. `linux-lts` 6.18.60-1 is the second entry. Both initramfs images were built with the `archiso` hook.

`scripts/test-boot.sh bios` and `scripts/test-boot.sh uefi` both printed `PASS` and `status=0` on the default entry. Logs: `build/logs/boot-bios-02e096f0.log`, `build/logs/boot-uefi-02e096f0.log`.

| Check | BIOS | UEFI |
|---|---|---|
| First `plasma=up` | `uptime_s=6.34`, `kernel=7.2.14-arch1-1` | `uptime_s=5.39`, `kernel=7.2.14-arch1-1` |
| `~/PROOF` | present at `uptime_s=11.29` | present at `uptime_s=11.43` |
| After reset | `proof=absent`, `uptime_s=5.38`, fingerprint `1fd6bfa6…` | `proof=absent`, `uptime_s=5.33`, fingerprint `79d63a62…` |
| SSH | `masked`, no port 22 | `masked`, no port 22 |

The second menu entry was then selected on both firmwares. It reached Plasma on `kernel=6.18.60-1-lts`.

| Check | BIOS LTS | UEFI LTS |
|---|---|---|
| `plasma=up` | `uptime_s=5.68` | `uptime_s=5.74` |
| Kernel | `6.18.60-1-lts` | `6.18.60-1-lts` |
| SSH | `masked`, no port 22 | `masked`, no port 22 |
| PipeWire | `up` | `up` |
| Screenshot | `build/test-results/bios-lts-20261108/desktop.png` | `build/test-results/uefi-lts-20261108/desktop.png` |

Both screenshots are the “Let's do it!” desktop. The LTS boots did not repeat the `~/PROOF` reset. That check was done on the default kernel of this same file.

`scripts/scan-image.sh` on this file exited 0. Log `build/logs/scan-02e096f0.log`. The only PEM findings are the reviewed GnuTLS 3.8.13-3 test blocks in `usr/bin/gnutls-cli` and `usr/lib/libgnutls.so.30.42.0`. Wallpaper hashes match.

## CockPit image — BIOS and UEFI passed, window not opened

File: `build/out/laden-os-0.1.0-live-x86_64.iso`

SHA-256 `3a9eb94089088a2a41861fab886fc29e83786692236ce227359b76d594fc53d4`

Size: 1907900416 bytes.

`scripts/test-boot.sh bios` and `scripts/test-boot.sh uefi` both printed `PASS` and `status=0`. Logs: `build/logs/boot-bios-3a9eb940.log`, `build/logs/boot-uefi-3a9eb940.log`.

| Check | BIOS | UEFI |
|---|---|---|
| First `plasma=up` | `uptime_s=5.88`, `pipewire=up`, `mem_available_kb=5485276` | `uptime_s=6.05`, `pipewire=up`, `mem_available_kb=5432100` |
| `~/PROOF` | present at `uptime_s=10.84` | present at `uptime_s=10.98` |
| After reset | `proof=absent`, `uptime_s=5.21`, `pipewire=up` | `proof=absent`, `uptime_s=5.33`, `pipewire=up` |
| Fingerprints | `b796590a…` then `4309c7e0…` | `659ce253…` then `2a22b288…` |
| SSH | `masked`, no port 22 | `masked`, no port 22 |

Screenshots `build/test-results/bios-20261108-184654/desktop.png` and `build/test-results/uefi-20261108-184654/desktop.png` are the “Let's do it!” desktop. The greeter is not shown.

The squashfs contains CockPit 1.1.0 at `/usr/share/the-cockpit`, `/usr/bin/cockpit`, and `/usr/bin/wezterm`. `connections.lua` has no active SSH entry. Intel capture was not started. The tarball is not in the image.

A separate BIOS guest opened the program from the launcher. `build/test-results/bios-cockpit-open-20261108/cockpit.png` shows a terminal on the live desktop with the fish prompt `live@laden-os` and the greeting `Laden OS — Let's do it!`. The helper then sent ACPI poweroff. The guest did not exit within 30 seconds, so the helper stopped QEMU. No guest was left running. SSH connections, the hardware view, and Intel capture were not used. UEFI was not used for this window check.

`scripts/scan-image.sh` on this file exited 0. Log `build/logs/scan-3a9eb940.log`. The only PEM findings are the reviewed GnuTLS 3.8.13-3 test blocks in `usr/bin/gnutls-cli` and `usr/lib/libgnutls.so.30.42.0`. Wallpaper hashes match. The structural checks in that script passed, including `machine-id` `uninitialized`, no service private key, and `sshd.service` linked to `/dev/null`.

## Build 4 — BIOS and UEFI freshness passed

File: `build/out/laden-os-0.1.0-live-x86_64.iso`

SHA-256 `afd71eb1c0e43ae71de460658df54590918135e718d40bbe040f60a8b7692d23`

Size: 1863024640 bytes. Built 18:32.

Commands:

```bash
scripts/build-iso.sh 1
scripts/test-boot.sh bios build/out/laden-os-0.1.0-live-x86_64.iso
scripts/test-boot.sh uefi build/out/laden-os-0.1.0-live-x86_64.iso
```

Both harnesses printed `PASS` and `status=0`. Logs: `build/logs/boot-bios-afd71eb1.log`, `build/logs/boot-uefi-afd71eb1.log`. QEMU used KVM, 6144 MiB, no NIC, and the ISO file only.

| Check | BIOS | UEFI |
|---|---|---|
| First `plasma=up` | `uptime_s=6.23`, `mem_available_kb=5484996` | `uptime_s=5.84`, `mem_available_kb=5314828` |
| `~/PROOF` before reset | `proof=present` at `uptime_s=8.17` | `proof=present` at `uptime_s=8.79` |
| After `system_reset` | `proof=absent`, `uptime_s=5.26`, `mem_available_kb=5220796` | `proof=absent`, `uptime_s=5.38`, `mem_available_kb=5124444` |
| Fingerprint | `360df997…` then `4ed8f14d…` | `d2189ddd…` then `4a1ef303…` |
| SSH | `ssh=masked` | `ssh=masked` |
| Listeners | 53 and 5355 only | 53 and 5355 only |
| Display manager | `dm=active` | `dm=active` |

The four fingerprints differ. The proof fingerprint matched the first boot, and the reset fingerprint did not.

Screenshots:

- BIOS first frame, `build/test-results/bios-20261108-183418/desktop.png`, is the Plasma splash (“Plasma 30th Anniversary Edition”). `plasmashell` was already running. The next frame, `screen.png`, is the desktop.
- UEFI `desktop.png` and `screen.png` in `build/test-results/uefi-20261108-183418/` are the desktop.
- Both desktop frames show the “Let's do it!” wallpaper, the Plasma panel, and Firefox. No greeter and no lock screen.

`mem_available_kb` is MemAvailable from `/proc/meminfo` at the status line, with 6144 MiB assigned to the guest. It is not a long idle sample.

## Still open on this file

| Check | Result |
|---|---|
| Secret scan of `afd71eb1…` | Pass, with reviewed upstream test keys | `scripts/scan-image.sh` exited 0. Log `build/logs/scan-afd71eb1.log`. The only PEM findings are GnuTLS 3.8.13-3 test blocks in `usr/bin/gnutls-cli` and `usr/lib/libgnutls.so.30.42.0`. Wallpaper hashes match. The script also requires `machine-id` `uninitialized`, no service private key, no HP wallpaper, no `CacheDir`, `sshd.service` linked to `/dev/null`, and no `/home/laden` under `etc` or `usr/lib/laden-os`. |
| Screen stays unlocked for more than five minutes | Pass on BIOS | `LADEN_IDLE_SECONDS=330 scripts/test-boot.sh bios` exited 0. `build/test-results/bios-20261108-183714/idle.png` is the desktop at 5:43 PM. The earlier frame in that run is 5:37 PM. No password prompt. UEFI was not left idle. |
| PipeWire process | Not measured |
| CockPit, linux-lts, lab tools, Calamares | Not in this image |

## Build 3 — desktop, then lock, freshness not finished

SHA-256 `50d5569cd90fe01ca800f24507246772f0da93e376e86a6590f69f4fad59f66f`, kept as `build/out/laden-os-0.1.0-live-x86_64.iso.50d5569c`.

BIOS `plasma=up` at 6.25 s and UEFI at 5.55 s. Screenshots `build/test-results/*-20261108-181834/desktop.png` show the desktop. `create-proof` was not read. Both harnesses exited 1 with `timed out waiting for boot status`. About five minutes after the desktop appeared, kscreenlocker asked for a password. The live password is locked, so the screen could not be cleared.

Secret scan of this file, `scripts/scan-image.sh` on the preserved ISO, exited 0. The only PEM findings were the reviewed GnuTLS 3.8.13-3 test blocks in `usr/bin/gnutls-cli` and `usr/lib/libgnutls.so.30.42.0`. Wallpaper hashes matched. The log is `build/logs/scan-50d5569c-r2.log`.

## Build 2 — failed in the initramfs

SHA-256 `54b213070d06ffed36f4aff24972ea46d9de0bdc6d83175c5ccf38817aef92d0`. The file was replaced. BIOS and UEFI dropped to an emergency shell because the initramfs had no `archiso` hook. Screenshots are in `build/test-results/*-20261108-180824/`.

A file named `laden-os-*.iso` is not evidence that the system boots. The boot claim above is only for SHA-256 `afd71eb1c0e43ae71de460658df54590918135e718d40bbe040f60a8b7692d23`.
