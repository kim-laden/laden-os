#!/usr/bin/env bash
# Laden OS step 1: enable the signed [laden] pacman repo and install the
# laden-* packages on this machine (Helios, Acer nvme1n1 only).
#
#   bash packages/install-laden-repo.sh --dry-run     # preview, changes nothing
#   sudo bash packages/install-laden-repo.sh          # apply
#
# Idempotent. Never removes packages (no -R / -Rns), never touches the
# Kingston drive, kernels, CachyOS repos/keyring, Steam, NVIDIA or gaming bits.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${HERE}/.." && pwd)"
SRC_REPO="${ROOT}/repo/x86_64"
DEST_REPO=/srv/laden-repo/x86_64
FPR=BE87AF39CC3C4610DEA910EC106B6FC0D1FF397F
PUBKEY="${HERE}/laden-keyring/laden.gpg"
PKGS=(laden-keyring laden-mirrorlist laden-branding laden-desktop-settings)
DATE="$(date +%Y%m%d-%H%M%S)"
BACKUP="/var/backups/laden-repo/${DATE}"
SNAP="/.laden-snapshots/pre-laden-repo-${DATE}"
PACCONF=/etc/pacman.conf
# Loose files from the rebrand kit that the packages replace with new paths
RETIRE=(
  /etc/pacman.d/hooks/50-laden-os-release.hook
  /usr/lib/laden-os/reapply-branding
  /usr/share/laden-os/os-identity/os-release
  /usr/share/laden-os/os-identity/lsb-release
  /usr/share/laden-os/fish/laden-colors.fish
)

DRY=0
for a in "$@"; do case $a in
  --dry-run|-n) DRY=1 ;;
  -h|--help) sed -n 2,12p "$0"; exit 0 ;;
  *) echo "unknown arg: $a" >&2; exit 2 ;;
esac; done
say() { printf '[laden-repo] %s\n' "$*"; }
run() { if [[ $DRY -eq 1 ]]; then printf 'DRY-RUN: %s\n' "$*"; else "$@"; fi; }
die() { say "ERROR: $*"; exit 1; }
[[ $DRY -eq 1 || $EUID -eq 0 ]] || die "run with sudo (or use --dry-run)"

# ---- 0. preflight -------------------------------------------------------
[[ -f ${SRC_REPO}/laden.db.tar.zst ]] || die "repo not built: run bash packages/build-repo.sh"
pkgfile() { ls -1t "${SRC_REPO}/$1"-[0-9]*-any.pkg.tar.zst | head -1; }
tmpk=$(mktemp -d); trap 'rm -rf "$tmpk"' EXIT
gpg --dearmor < "$PUBKEY" > "$tmpk/laden.gpg"
for f in "${SRC_REPO}/laden.db.tar.zst" $(for p in "${PKGS[@]}"; do pkgfile "$p"; done); do
  gpgv --keyring "$tmpk/laden.gpg" "$f.sig" "$f" >/dev/null 2>&1 || die "bad/missing signature: $f"
done
say "signatures OK (key $FPR)"
rootdisk=$(lsblk -no PKNAME "$(findmnt -no SOURCE / | sed 's/\[.*//')")
[[ $rootdisk != nvme0n1 ]] || die "/ is on nvme0n1 (Kingston) — refusing"
say "root disk: $rootdisk"

# Package file lists -> conflicts with loose (unowned) files from the rebrand kit
OVERWRITE=() ; LOOSE=()
while read -r p; do
  [[ -e $p || -L $p ]] || continue
  if owner=$(pacman -Qqo "$p" 2>/dev/null); then
    [[ $owner == laden-* ]] && continue
    die "$p is owned by package '$owner' — refusing to overwrite"
  fi
  LOOSE+=("$p"); OVERWRITE+=(--overwrite "$p")
done < <(for x in laden-branding laden-desktop-settings laden-keyring laden-mirrorlist; do
           bsdtar -tf "$(pkgfile $x)" | grep -v '^\.' | grep -v '/$' | sed 's#^#/#'; done)
say "${#LOOSE[@]} loose rebrand-kit files will be taken over by the packages (backed up first)"

# ---- 1. snapshot + backups ------------------------------------------------
if [[ $DRY -eq 1 ]]; then
  say "DRY-RUN: btrfs subvolume snapshot -r / ${SNAP}"
else
  mkdir -p /.laden-snapshots
  btrfs subvolume snapshot -r / "$SNAP" || die "snapshot failed"
  say "snapshot: $SNAP"
fi
run mkdir -p "$BACKUP"
backup() { [[ -e $1 || -L $1 ]] || return 0; run mkdir -p "$BACKUP$(dirname "$1")"; run cp -a "$1" "$BACKUP$1"; }
backup "$PACCONF"
for p in "${LOOSE[@]}" "${RETIRE[@]}"; do backup "$p"; done
[[ $DRY -eq 1 ]] || say "backups: $BACKUP"

# ---- 2. publish repo + trust key ------------------------------------------
run install -d -m0755 /srv/laden-repo "$DEST_REPO"
run rsync -a --delete --chown=root:root --chmod=D0755,F0644 "${SRC_REPO}/" "${DEST_REPO}/"
if pacman-key --list-keys "$FPR" >/dev/null 2>&1 && [[ $DRY -eq 0 ]]; then
  say "key already in pacman keyring"
else
  run pacman-key --add "$PUBKEY"
fi
run pacman-key --lsign-key "$FPR"

# ---- 3. keyring + mirrorlist (needed before [laden] can be enabled) -------
run pacman -U --needed --noconfirm \
  "${DEST_REPO}/$(basename "$(pkgfile laden-keyring)")" \
  "${DEST_REPO}/$(basename "$(pkgfile laden-mirrorlist)")"

# ---- 4. [laden] in pacman.conf, above the CachyOS repos -------------------
if grep -q '^\[laden\]' "$PACCONF"; then
  say "[laden] already in $PACCONF"
else
  say "adding [laden] above the first [cachyos*] section in $PACCONF"
  if [[ $DRY -eq 0 ]]; then
    python3 - "$PACCONF" <<'PY'
import re, sys
p = sys.argv[1]; t = open(p).read()
block = ("# Laden OS repository (added by packages/install-laden-repo.sh)\n"
         "[laden]\nSigLevel = Required DatabaseRequired\n"
         "Include = /etc/pacman.d/laden-mirrorlist\n\n")
m = re.search(r'^\[cachyos[^\]]*\]', t, re.M) or re.search(r'^\[core\]', t, re.M)
if not m: sys.exit("no [cachyos*] or [core] section found")
open(p, 'w').write(t[:m.start()] + block + t[m.start():])
PY
  else
    echo "DRY-RUN: insert before '$(grep -m1 -nE '^\[cachyos' "$PACCONF")':"
    printf '  [laden]\n  SigLevel = Required DatabaseRequired\n  Include = /etc/pacman.d/laden-mirrorlist\n'
  fi
fi

# ---- 5. sync + install -----------------------------------------------------
run pacman -Sy
# Plasma wallpaper images become symlinks to /usr/share/backgrounds/laden;
# remove the loose regular files (already backed up) so pacman can link them.
SYMLINKED=()
for s in 7680x4320 3840x2160 3440x1440 1920x1080; do
  f=/usr/share/wallpapers/LadenOS/contents/images/${s}.png
  if [[ -f $f && ! -L $f ]] && ! pacman -Qqo "$f" >/dev/null 2>&1; then SYMLINKED+=("$f"); fi
done
[[ ${#SYMLINKED[@]} -eq 0 ]] || run rm -f "${SYMLINKED[@]}"
if ! run pacman -S --needed --noconfirm "${OVERWRITE[@]}" "${PKGS[@]}"; then
  for f in "${SYMLINKED[@]}"; do cp -a "$BACKUP$f" "$f"; done
  die "pacman -S failed; restored wallpaper files. Nothing else was removed. Backups: $BACKUP"
fi
# Retire loose rebrand-kit files now superseded by package-owned paths
for p in "${RETIRE[@]}"; do
  [[ -e $p ]] || continue
  if pacman -Qqo "$p" >/dev/null 2>&1; then say "keep $p (owned by a package)"; continue; fi
  run rm -f "$p"
done
run rmdir --ignore-fail-on-non-empty /usr/lib/laden-os /usr/share/laden-os/os-identity 2>/dev/null || true

# ---- 6. verify -------------------------------------------------------------
if [[ $DRY -eq 0 ]]; then
  pacman -Q "${PKGS[@]}"
  pacman -Sl laden
  pacman -Qkk "${PKGS[@]}" 2>&1 | tail -4 || true
  grep -E '^(ID|LOGO)=' /etc/os-release
  say "done. Backups: $BACKUP   Snapshot: $SNAP"
  say "pacman.conf backup: $BACKUP$PACCONF"
else
  echo; say "dry-run finished — nothing changed. Apply with: sudo bash $0"
fi
