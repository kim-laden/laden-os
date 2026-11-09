# Laden OS 0.2.0 — release notes (DRAFT, not published)

**Let's do it!** Laden OS 0.2.0 is the first Laden OS release with a graphical installer.
Laden OS is based on CachyOS and Arch Linux.

## What's in it

- **Desktop live ISO** (`laden-os-0.2.0-desktop-x86_64.iso`, about 2.7 GB): KDE Plasma (Wayland)
  with the Laden look: LadenDark colours, the v2 "Let's do it!" wallpaper (v1 is still in
  `/usr/share/backgrounds/laden`), and the new Laden menu with its panel layout, favourites and categories.
- **Laden OS installer** (Calamares, Laden branding and slideshow):
  - Pick an edition: Desktop, Gaming, Creator, Streaming, Pentest or Full.
    Desktop installs offline from the ISO. The others are downloaded during the install.
  - Partitioning: btrfs by default (subvolumes `@`, `@home`, `@cache`, `@log`), ext4 also available.
  - Bootloader: Limine (default, the same as on our own machines) or systemd-boot (UEFI only).
  - Hardware detection: chwd picks the graphics drivers when the machine is online, for example the NVIDIA driver.
  - First boot: SSH host keys are made on the installed machine. The installer creates the machine ID
    and the pacman keyring on the target, never at build time.
- **Laden tools**: Laden Update (tray updater), Laden Kernel Manager, Laden Scheduler and the
  `linux-laden` kernel 7.3.3.
- **[laden] package repository**: signed packages and meta-packages for every edition,
  for example `sudo pacman -S laden-gaming`.

## Requirements

- A 64-bit CPU with x86-64-v3 support (AVX2), for example Intel Haswell, AMD Zen or newer.
  The installer checks this and stops with a clear message if the CPU is older.
- 4 GB RAM and 30 GB of disk space or more.
- BIOS or UEFI. Secure Boot must be off.

## Known issues

- No full install to disk has been tested end to end yet. The live session and the installer start are tested.
- Limine on BIOS with a GPT disk is untested.
- The [laden] repository is still shipped inside the image (`/srv/laden-repo`). Updates to Laden
  packages need the public repository at laden.no, which isn't online yet.
- No Secure Boot support.
- No NVIDIA driver in the live session (it uses nouveau). The installer adds the NVIDIA driver through chwd when the machine is online.
- No Plymouth boot splash yet.
- `uname -r` still shows the upstream kernel version string (`7.3.3-1-cachyos`).

## Checksums

See `laden-os-0.2.0-desktop-x86_64.iso.sha256`.
