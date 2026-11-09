# Laden OS packages and the `[laden]` repo

Step 1 of making Laden OS fully in-house: Laden branding and settings ship as
signed pacman packages instead of loose files.

| Package | Contents |
|---|---|
| `laden-branding` | os-release/lsb-release content (`/usr/share/laden/os-identity`, applied to `/etc/os-release`, `/usr/lib/os-release`, `/etc/lsb-release` by `/usr/lib/laden/laden-apply-branding`), `laden-os` icons (hicolor + pixmaps), Limine splash (`/usr/share/laden/limine-splash.png` → `/boot`), Plymouth theme `laden`, wallpapers v1 + v2 (`/usr/share/backgrounds/laden`, Plasma package `/usr/share/wallpapers/LadenOS`, v2 8K default), fastfetch Laden logo + `/etc/xdg/fastfetch/config.jsonc`, pacman hooks |
| `laden-desktop-settings` | `org.laden.os` look-and-feel, `LadenDark.colors`, `/etc/xdg/kdeglobals` + `ksplashrc`, fish config (`/usr/share/laden/fish`, `/etc/fish/conf.d`), Laden Update tray icons and overlay, menu overrides in `/usr/local/share/applications` |
| `laden-keyring` | Repo signing **public** key (`laden.gpg`, `laden-trusted`, `laden-revoked`), populated via `pacman-key --populate laden` |
| `laden-mirrorlist` | `/etc/pacman.d/laden-mirrorlist` (local `file:///srv/laden-repo/$arch`; `https://laden.no/repo/$arch` commented out until it is live) |

Assets are taken from `rebrand/assets/` and `branding/` at build time, so there
is one copy of every image in git.

## Files owned by other packages

`/usr/lib/os-release` (filesystem), `/etc/lsb-release` (lsb-release),
`/usr/share/icons/cachyos.svg` (cachyos-settings), cachy-update's
`/etc/xdg/autostart/arch-update-tray.desktop` and `cachy-update*.svg` icons are
**not** claimed. Laden content lives under `/usr/share/laden` and is overlaid by
`laden-apply-branding` / `laden-apply-tray-branding`, run from the package
install scripts and pacman hooks (`/usr/share/libalpm/hooks/5x-laden-*.hook`,
`60-laden-tray-branding.hook`) whenever those packages are upgraded. The first
original of each overlaid file is kept in `/var/lib/laden/orig/`.

The Limine splash is only copied to `/boot` when `/boot` is on the same disk as
`/` (so a Kingston ESP mounted at `/boot` is never written).

## Signing key

`Laden OS Repo <admin@laden.no>`, ed25519, expires 2031-11-08,
fingerprint `BE87AF39CC3C4610DEA910EC106B6FC0D1FF397F`.
The secret key lives only in `~/.gnupg` on ladenx (no passphrase, dedicated
to repo signing). Only the public key is in git and in `laden-keyring`.
Back it up offline; a revocation certificate is in
`~/.gnupg/openpgp-revocs.d/`.

## Build (as user, no sudo)

    bash packages/build-repo.sh

Builds all four packages (build dirs in `/tmp/laden-makepkg`, removed after),
signs them, runs `repo-add --sign --verify` into `repo/x86_64/` (gitignored)
and checks every signature.

## Install / update on this machine

    bash packages/install-laden-repo.sh --dry-run
    sudo bash packages/install-laden-repo.sh

Takes a read-only btrfs snapshot (`/.laden-snapshots/pre-laden-repo-<date>`),
backs up `pacman.conf` and every loose file it takes over to
`/var/backups/laden-repo/<date>/`, publishes the repo to `/srv/laden-repo/x86_64`
(pacman's sandboxed `alpm` download user cannot read `/home/laden`), adds and
locally signs the key, installs keyring + mirrorlist, adds `[laden]` above the
CachyOS repos, `pacman -Sy`, then installs the packages with `--overwrite`
limited to the exact loose rebrand-kit paths. It never removes packages.

After a rebuild later on: `bash packages/build-repo.sh && sudo bash packages/publish-local-repo.sh && sudo pacman -Syu`.

## Undo

    sudo cp -a /var/backups/laden-repo/<date>/etc/pacman.conf /etc/pacman.conf
    sudo pacman -R laden-desktop-settings laden-branding laden-mirrorlist laden-keyring   # named packages only, never -Rns
    sudo cp -a /var/backups/laden-repo/<date>/. /     # restore the loose files

or boot/restore the snapshot.
