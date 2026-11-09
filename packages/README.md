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
`/usr/share/icons/cachyos.svg` (cachyos-settings) are **not** claimed. Laden
content lives under `/usr/share/laden` and is overlaid by `laden-apply-branding`,
run from the package install script and pacman hooks
(`/usr/share/libalpm/hooks/5x-laden-*.hook`) whenever those packages are
upgraded. (The cachy-update tray overlay and the `/usr/local/share/applications`
menu overrides were dropped in laden-desktop-settings 2026.11.09-2: the real
forks below replace them.) The first
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

## linux-laden (step 2)

`linux-laden` / `linux-laden-headers` are the signed CachyOS `linux-cachyos` /
`linux-cachyos-headers` binaries (cachyos-v3, same build, same performance)
repackaged under the Laden name. Nothing is recompiled; `prepare()` checks the
CachyOS signatures against `/usr/share/pacman/keyrings/cachyos.gpg`. Only
`/usr/lib/modules/<kver>/pkgbase` (→ `linux-laden`) and the `/usr/src` symlink
change; every other file is byte-identical (checked against the upstream MTREE).

**Why a replacement, not side-by-side:** the kernel release (`uname -r` =
`7.3.3-1-cachyos`) is compiled into vmlinuz and every module's vermagic, so a
repackage must use the same `/usr/lib/modules/7.3.3-1-cachyos` directory as
linux-cachyos. Two packages can't own it, and a different directory would need a
rebuild with a new localversion (~30 GB, hours). A "thin" branding package can't
work either: limine-mkinitcpio-hook names the boot entry after the package that
owns `modules.builtin`. So linux-laden `conflicts=linux-cachyos` and
`provides=linux-cachyos=<ver>` (keeps ntsync-autoload etc. satisfied).
`linux-cachyos-lts` stays installed, untouched, as the fallback kernel.
`uname -r` keeps saying `-cachyos` until a real rebuild.

**Updates:** linux-cachyos is no longer installed, so `pacman -Syu` won't pull
new CachyOS kernels. When CachyOS ships one:

    bash packages/linux-laden/update-from-cachyos.sh
    sudo bash packages/publish-local-repo.sh && sudo pacman -Syu

**Install:** `sudo bash packages/install-linux-laden.sh` (`--dry-run` first).
It snapshots, backs up limine.conf, the old ESP kernel dir and the original
CachyOS packages to `/var/backups/laden-kernel/<date>/`, swaps the packages
(`--ask 4` answers yes only to the conflict removal), rebuilds DKMS and the
initramfs through the normal hooks, puts linux-laden first in `/+Laden OS`, and
sets `default_entry: Laden OS/linux-laden`. It also checks that the Kingston
sections didn't change.

**Limine config gotcha:** on UEFI, Limine reads `<EFI app dir>/limine.conf`
before `/limine.conf`. A hand-made `/boot/EFI/limine/limine.conf` was hiding the
`/boot/limine.conf` that limine-entry-tool manages, so kernel updates and the
rebrand labels never reached the real boot menu. The script moves it aside to
`limine.conf.pre-linux-laden`.

**Rollback** (from the LTS entry or a running system):

    B=/var/backups/laden-kernel/<date>
    sudo pacman -U --ask 4 $B/pkgs/linux-cachyos-7.3.3-1-x86_64_v3.pkg.tar.zst \
                           $B/pkgs/linux-cachyos-headers-7.3.3-1-x86_64_v3.pkg.tar.zst
    # quick boot-menu-only rollback: the old ESP files are still in /boot/<machine-id>/linux-cachyos
    sudo mv /boot/EFI/limine/limine.conf.pre-linux-laden /boot/EFI/limine/limine.conf

## Laden forks of the CachyOS tools (step 3)

| Laden package | Based on (upstream, license) | Replaces |
|---|---|---|
| `laden-update` 4.4.7 | [cachy-update](https://github.com/CachyOS/cachy-update) main `22c569d` ← [Arch-Update](https://github.com/Antiz96/arch-update) by Robin Candau, GPL-3.0-or-later | `cachy-update` |
| `laden-scheduler` 1.16.0 | [scx-manager](https://github.com/CachyOS/scx-manager) v1.16.0, GPL-3.0-or-later | `scx-manager` |
| `laden-kernel-manager` 1.19.0 | [kernel-manager](https://github.com/CachyOS/kernel-manager) v1.19.0, GPL-3.0-or-later | `cachyos-kernel-manager` |

Each PKGBUILD clones upstream at a pinned commit and applies
`laden-branding.patch` (generated with `git format-patch` from a `laden`
branch). Only names, icons, desktop entries, window titles, notification text,
the polkit action (`org.laden.KernelManager…`, helper path
`/usr/lib/laden-kernel-manager/`) and Qt app ids change. Kept on purpose:
`/usr/bin/arch-update` (+ `laden-update` alias), `arch-update.{service,timer}`
user units, `~/.config/arch-update`, the `Arch-Update` gettext domain,
`libscxctl-ui` + its cmake config (the kernel manager links it), a
`scx-manager` symlink, and the functional linux-cachyos package names / "CachyOS
config" kernel options. Each package `provides`/`conflicts`/`replaces` exactly the
package it supersedes.

Build: `BUILDDIR=/tmp/laden-makepkg GPGKEY=<fpr> makepkg -C --sign --nocheck` in each dir
(scdoc is a makedep of laden-update; bats only for check), then `repo-add --sign`
and `sudo bash packages/publish-local-repo.sh`.

Install: `bash packages/install-laden-forks.sh [--dry-run]` — snapshot
`/.laden-snapshots/pre-laden-forks-<date>`, originals saved to
`/var/backups/laden-forks/<date>/pkgs`, `pacman -U --ask 4` (removes only the three
named packages), then per-user migration: old `~/.local/share/applications`
overrides moved to `~/.local/share/laden-backups/forks-<date>/`,
`~/.local/state/arch-update/tray_icon` renamed to the `laden-update…` icon, tray restarted.

Undo: `sudo pacman -U --ask 4 /var/backups/laden-forks/<date>/pkgs/*.pkg.tar.zst`
(reinstalls cachy-update, cachyos-kernel-manager, scx-manager and
laden-desktop-settings -1, removing the forks), then copy the files from
`~/.local/share/laden-backups/forks-<date>/` back.

## Meta-packages (step 4) and ISO editions

`packages/metas/gen-metas.py` generates `laden-{desktop,gaming,creator,streaming,pentest,full}`
(arch any, group `laden-meta`). Hard `depends` are small essentials that resolve from
the configured repos; large or hardware-specific items (Proton/Wine builds, NVIDIA/AMD
userspace, Blender, DaVinci Resolve, Metasploit, Burp, SecLists, Ghidra…) are
`optdepends` only, so installing a meta never pulls in GBs. On ladenx all six
were installed with 0 bytes added (all depends were already present).

| ISO edition (step 5) | metas in the package list | extra repos needed |
|---|---|---|
| Laden OS Desktop | `laden-desktop` (+ `linux-laden`, `limine`, `chwd` from its optdepends) | laden, cachyos* |
| Laden OS Gaming | `laden-desktop laden-gaming` + `proton-cachyos-slr`, `wine-cachyos-opt`; GPU stack chosen by chwd at install | + multilib |
| Laden OS Creator | `laden-desktop laden-creator laden-streaming` (+ gimp, krita, inkscape, audacity from optdepends) | — |
| Laden OS Pentest | `laden-desktop laden-pentest` (+ metasploit, burpsuite, zaproxy, seclists from optdepends) | + blackarch |
| Laden OS Full (dev/test) | `laden-full` | multilib, blackarch |

AUR-only (not in any repo, so never in depends): bottles (use Flatpak),
chatterino2, game-devices-udev, gpu-screen-recorder-gtk, obs-pipewire-audio-capture,
olive, openshot, streamlink-twitch-gui-bin. obs-websocket is built into OBS
(obs-studio-browser provides it).

Undo: `sudo pacman -R laden-full laden-desktop laden-gaming laden-creator laden-streaming laden-pentest`
(plain `-R`, no `-s`: the apps stay installed; anything that was a dependency only
because of a meta would show up in `pacman -Qdt` and is left for manual review).
