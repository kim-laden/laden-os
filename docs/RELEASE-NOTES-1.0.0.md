# Laden OS 1.0.0 — release notes (RC, not published)

**Let's do it.** Laden OS 1.0.0 is the first release-candidate of Laden OS as a
complete desktop you can install: gaming, creating, streaming and Red Team on
one system. Laden OS is **based on Arch Linux**. Upstream tooling credits
(including CachyOS) are listed in `NOTICE` and `CREDITS`.

## Editions

| Edition | How you get it | What it is |
|---------|----------------|------------|
| **Standard** | Live/installer ISO | KDE Plasma, Laden kernel, menu, art, Intel + AMD + NVIDIA graphics stacks, Laden Apps picker (Steam and friends over the network) |
| **Red Team** | Live USB ISO (separate profile) | Standard plus the pentest bundle, Tailscale and RustDesk tunnel helpers. Keys and passwords are created on the machine at first use — never baked into the image |
| **Full** | Network install from the `[laden]` repo | Every meta-package at once (`laden-full`) during Calamares when online |

Calamares still lets you pick Desktop/Standard, Gaming, Creator, Streaming,
Red Team/Pentest or Full on the Edition page. Standard installs offline from
the ISO; the others download from the repos when the network is up.

## What's new since 0.2.0

- **linux-laden 1:7.3.3-1** with `uname -r` = `7.3.3-1-laden` (no `cachy` in the running release string).
- **Laden OS Art v5** as the default wallpaper/lock/login art (deep tunnel, hidden gear and CLI eggs for people who zoom in).
- **Laden Apps** (`laden-apps`): one-click / checklist installer for Steam, Lutris, Heroic, OBS, Discord and Flatpak.
- **Laden Tunnels** (`laden-tunnels`): easy Tailscale login and RustDesk password generation on first use.
- Installer fixes for BIOS Limine layout, dark Calamares theme, and Limine menu default entry.
- BIOS installer: replace limine-entry-tool with limine-mkinitcpio-hook without a pacman conflict, write /etc/default/limine so the hook targets the **Laden OS** menu, and install limine-bios.sys plus `limine bios-install` on a FAT32 /boot (Limine cannot read btrfs).
- License prep: Laden original work under MIT © Laden AS; GPL forks stay GPL; branding reserved.

## Requirements

- 64-bit CPU with x86-64-v3 (AVX2), for example Intel Haswell, AMD Zen or newer.
- 4 GB RAM and 30 GB disk or more (more for Gaming/Full).
- BIOS or UEFI. Secure Boot must be off.

## Known blockers before a *public* v1

- The `[laden]` mirrorlist still points at `file:///srv/laden-repo` for local builds.
  A public **HTTPS** mirror (planned `https://laden.no/repo/$arch`) must exist before shipping.
- No Secure Boot / MOK support (by design for now).
- RustDesk may need a manual install if it is not in the configured repos at build time.
- This RC is tested in QEMU; real-hardware sign-off is still on Laden.

## Checksums

See `laden-os-1.0.0-standard-x86_64.iso.sha256` next to the ISO after the release build and scan.
