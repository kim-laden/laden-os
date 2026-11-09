# Laden OS installed-system rebrand kit

Turns the Helios CachyOS-clone install into a through-and-through **Laden OS** desktop
without touching the Kingston rollback drive (`nvme0n1`).

## What Laden should run

```bash
cd ~/Projects/LadenOS

# 1) Preview (no root required for most of the plan)
bash rebrand/apply-installed-rebrand.sh --dry-run

# 2) Apply system branding (needs sudo once)
sudo bash rebrand/apply-installed-rebrand.sh

# 3) Apply your user session (Plasma + fish) — NO sudo
bash rebrand/apply-user-rebrand.sh

# 4) Reboot to see Limine splash + Plymouth
systemctl reboot
```

Rollback:

```bash
sudo bash rebrand/rollback-installed-rebrand.sh --latest
# or a specific backup:
sudo bash rebrand/rollback-installed-rebrand.sh /var/backups/laden-rebrand/<date>
```

## Steps the sudo script performs

0. **Safety** — snapper snapshot `pre-rebrand-<date>` on config `root`; file backups under
   `/var/backups/laden-rebrand/<date>/`; log `/var/log/laden-rebrand.log`. Aborts on error.
1. **Identity** — `/etc/os-release` + `/usr/lib/os-release` + `/etc/lsb-release` → Laden OS,
   `ID=ladenos`, `ID_LIKE=arch`, URLs `https://laden.no`, `LOGO=laden-os`. Installs icons.
   Pacman hook reapplies branding after `filesystem` / `lsb-release` upgrades.
2. **Boot** — replaces `/boot/limine-splash.png`; soft-renames Laden menu labels only
   (kernel paths unchanged); installs Plymouth theme `laden`; rebuilds initramfs via
   `limine-mkinitcpio`. Removes Cachy plymouth packages.
3. **Tray** — keeps `cachy-update` (it already provides `arch-update` and conflicts with
   the plain package). Overrides autostart + icons with Laden branding.
4. **Desktop** — installs `org.laden.os`, `LadenDark`, v1+v2 wallpapers, `/etc/xdg` defaults,
   Laden fish config, menu overrides. Removes cosmetic Cachy packages and sets `IgnorePkg`.

## Never removed (functional)

Kernels `linux-cachyos*`, `cachyos-keyring`, mirrorlists/repos, `cachyos-settings` /
hooks / ananicy / snapper-support / rate-mirrors, gaming meta, proton/wine builds,
`python-cachy`, and `cachy-update` (rebranded in place).

## Kingston

Boot menu entries for CachyOS on Kingston are left intact. This kit never mounts or
writes that drive.
