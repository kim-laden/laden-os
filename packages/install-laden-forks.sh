#!/usr/bin/env bash
# Laden OS step 3: swap the CachyOS tools for their Laden forks.
#   cachy-update           -> laden-update          (tray updater)
#   cachyos-kernel-manager -> laden-kernel-manager
#   scx-manager            -> laden-scheduler
#   laden-desktop-settings -1 -> -2 (drops the old menu overrides / tray overlay)
# Only the three named packages are removed (pacman conflict prompt answered
# via --ask 4); nothing cascades.  Run as the desktop user (uses sudo -n):
#   bash packages/install-laden-forks.sh [--dry-run]
set -euo pipefail
DRY=0; [[ "${1:-}" == --dry-run ]] && DRY=1
REPO=/srv/laden-repo/x86_64
D=$(date +%Y%m%d-%H%M%S)
BK=/var/backups/laden-forks/$D
UBK=$HOME/.local/share/laden-backups/forks-$D
PKGS=(laden-scheduler-1.16.0-1-x86_64 laden-kernel-manager-1.19.0-1-x86_64
      laden-update-4.4.7-1-x86_64 laden-desktop-settings-2026.11.09-2-any)
run() { echo "+ $*"; [[ $DRY -eq 1 ]] || "$@"; }

# --- preflight
[[ $EUID -ne 0 ]] || { echo "run as the desktop user, not root" >&2; exit 1; }
sudo -n true || { echo "sudo needs a password; re-run with --dry-run and do it by hand" >&2; exit 1; }
files=()
for p in "${PKGS[@]}"; do
  f=$REPO/$p.pkg.tar.zst
  [[ -f $f && -f $f.sig ]] || { echo "missing $f(.sig) — publish first" >&2; exit 1; }
  gpgv --keyring /etc/pacman.d/gnupg/pubring.gpg "$f.sig" "$f" 2>/dev/null \
    || sudo -n pacman-key --verify "$f.sig" >/dev/null 2>&1 \
    || { echo "bad signature: $f" >&2; exit 1; }
  files+=("$f")
done
for p in cachy-update cachyos-kernel-manager scx-manager; do
  if pacman -Qq "$p" >/dev/null 2>&1; then
    rb=$(pacman -Qi "$p" | sed -n 's/^Required By *: //p')
    echo "$p installed; required by: $rb"
  fi
done

# --- snapshot + backups
run sudo -n btrfs subvolume snapshot -r / "/.laden-snapshots/pre-laden-forks-$D"
run sudo -n install -d -m0755 "$BK/pkgs"
# originals for rollback (pacman -U $BK/pkgs/*)
run sudo -n pacman -Sw --noconfirm cachy-update cachyos-kernel-manager scx-manager
for p in cachy-update cachyos-kernel-manager scx-manager; do
  v=$(pacman -Q "$p" 2>/dev/null | cut -d' ' -f2) || continue
  run sudo -n sh -c "cp -a /var/cache/pacman/pkg/$p-$v-*.pkg.tar.zst* '$BK/pkgs/'"
done
run sudo -n cp -a /srv/laden-repo/x86_64/laden-desktop-settings-2026.11.09-1-any.pkg.tar.zst{,.sig} "$BK/pkgs/" 2>/dev/null || true
[[ -e /etc/xdg/autostart/arch-update-tray.desktop ]] && run sudo -n cp -a /etc/xdg/autostart/arch-update-tray.desktop "$BK/"
run install -d "$UBK"
for f in arch-update.desktop arch-update-tray.desktop org.cachyos.KernelManager.desktop \
         org.cachyos.scx-manager.desktop cachyos-hello.desktop cachyos-pi.desktop; do
  [[ -e $HOME/.local/share/applications/$f ]] && run cp -a "$HOME/.local/share/applications/$f" "$UBK/"
done
[[ -e $HOME/.local/state/arch-update/tray_icon ]] && run cp -a "$HOME/.local/state/arch-update/tray_icon" "$UBK/"

# --- install (removes only the conflicting named packages)
run sudo -n pacman -U --noconfirm --ask 4 "${files[@]}"

# --- user migration
# old per-user overrides (they shadowed the CachyOS entries; the packages are Laden-named now)
for f in arch-update.desktop arch-update-tray.desktop org.cachyos.KernelManager.desktop \
         org.cachyos.scx-manager.desktop cachyos-hello.desktop cachyos-pi.desktop; do
  [[ -e $HOME/.local/share/applications/$f ]] && run rm -f "$HOME/.local/share/applications/$f"
done
st=$HOME/.local/state/arch-update/tray_icon
[[ -f $st ]] && run sed -i 's/^cachy-update/laden-update/' "$st"
run update-desktop-database -q "$HOME/.local/share/applications" || true
command -v kbuildsycoca6 >/dev/null && run kbuildsycoca6 --noincremental >/dev/null 2>&1 || true
run systemctl --user daemon-reload
# restart the tray so it picks up the new icons/text (relogin also does this)
if pgrep -u "$USER" -f /usr/lib/arch-update/arch-update-tray >/dev/null; then
  run pkill -u "$USER" -f /usr/lib/arch-update/arch-update-tray
  export DBUS_SESSION_BUS_ADDRESS=${DBUS_SESSION_BUS_ADDRESS:-unix:path=/run/user/$(id -u)/bus}
  [[ $DRY -eq 1 ]] || setsid -f arch-update --tray >/dev/null 2>&1 < /dev/null
fi
echo "done. snapshot: /.laden-snapshots/pre-laden-forks-$D  backups: $BK  $UBK"
