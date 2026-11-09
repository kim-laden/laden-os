#!/usr/bin/env bash
# Laden OS step 2: switch the main kernel package linux-cachyos -> linux-laden
# (identical CachyOS binaries, Laden name) and do two safe cleanups.
#
#   bash packages/install-linux-laden.sh --dry-run
#   sudo bash packages/install-linux-laden.sh [--no-cleanup]
#
# Keeps linux-cachyos-lts (+headers) untouched as the fallback kernel.
# Never touches the Kingston drive/ESP or the "CachyOS (Kingston)" /
# "CachyOS Kingston (direct)" boot entries. Never uses -Rns / cascading removal.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${HERE}/.." && pwd)"
SRC_REPO="${ROOT}/repo/x86_64"; DEST_REPO=/srv/laden-repo/x86_64
FPR=BE87AF39CC3C4610DEA910EC106B6FC0D1FF397F
KVER=7.3.3-1-cachyos; PKGVER=7.3.3-1
DATE="$(date +%Y%m%d-%H%M%S)"
BACKUP="/var/backups/laden-kernel/${DATE}"
SNAP="/.laden-snapshots/pre-linux-laden-${DATE}"
MID="$(cat /etc/machine-id)"
DRY=0; CLEANUP=1
for a in "$@"; do case $a in
  --dry-run|-n) DRY=1 ;; --no-cleanup) CLEANUP=0 ;;
  -h|--help) sed -n 2,11p "$0"; exit 0 ;; *) echo "unknown arg $a" >&2; exit 2 ;;
esac; done
say() { printf '[linux-laden] %s\n' "$*"; }
run() { if [[ $DRY -eq 1 ]]; then printf 'DRY-RUN: %s\n' "$*"; else "$@"; fi; }
die() { say "ERROR: $*"; exit 1; }
[[ $DRY -eq 1 || $EUID -eq 0 ]] || die "run with sudo (or --dry-run)"
SUDO=""; [[ $EUID -eq 0 ]] || SUDO="sudo -n"

# ---- preflight ------------------------------------------------------------
rootdisk=$(lsblk -no PKNAME "$(findmnt -no SOURCE / | sed 's/\[.*//')")
bootdisk=$(lsblk -no PKNAME "$(findmnt -no SOURCE /boot)")
[[ $rootdisk == nvme1n1 && $bootdisk == nvme1n1 ]] || die "/ ($rootdisk) and /boot ($bootdisk) must both be nvme1n1"
K="${SRC_REPO}/linux-laden-${PKGVER}-x86_64.pkg.tar.zst"
H="${SRC_REPO}/linux-laden-headers-${PKGVER}-x86_64.pkg.tar.zst"
tmpk=$(mktemp -d); trap 'rm -rf "$tmpk"' EXIT
gpg --dearmor < "${HERE}/laden-keyring/laden.gpg" > "$tmpk/k.gpg"
for f in "$K" "$H" "${SRC_REPO}/laden.db.tar.zst"; do
  gpgv --keyring "$tmpk/k.gpg" "$f.sig" "$f" >/dev/null 2>&1 || die "bad signature: $f"
done
pacman-key --list-keys "$FPR" >/dev/null 2>&1 || [[ $DRY -eq 1 ]] || die "Laden key not in pacman keyring (run install-laden-repo.sh first)"
grep -q '^\[laden\]' /etc/pacman.conf || die "[laden] repo not enabled"
pacman -Q linux-cachyos-lts linux-cachyos-lts-headers >/dev/null || die "linux-cachyos-lts fallback missing — refusing"
dkms status -k 6.18.60-2-cachyos-lts 2>/dev/null | grep '^nvidia/.*installed' >/dev/null || die "nvidia not built for the LTS fallback — refusing"
$SUDO test -f "/boot/${MID}/linux-cachyos-lts/vmlinuz" -a -f "/boot/${MID}/linux-cachyos-lts/initramfs" || die "LTS boot files missing"
$SUDO grep -q 'kernel-id=linux-cachyos-lts' /boot/limine.conf || die "LTS Limine entry missing"
if pacman -Q linux-laden >/dev/null 2>&1; then
  say "linux-laden already installed: $(pacman -Q linux-laden linux-laden-headers | tr '\n' ' ')"; ALREADY=1
else
  [[ "$(pacman -Q linux-cachyos | awk '{print $2}')" == "$PKGVER" ]] || die "installed linux-cachyos is not $PKGVER — rebuild linux-laden for it first"
  ALREADY=0
fi
say "preflight OK (LTS fallback present, nvidia built for LTS, signatures OK)"

kingston_sections() { python3 - "$1" <<'PY'
import sys,re
t=open(sys.argv[1]).read()
parts=re.split(r'(?m)^(?=/\+)', t)
print("".join(p for p in parts if p.startswith('/+CachyOS')))
PY
}

# ---- snapshot + backups -------------------------------------------------------
if [[ $DRY -eq 1 ]]; then say "DRY-RUN: btrfs subvolume snapshot -r / $SNAP"
else mkdir -p /.laden-snapshots; btrfs subvolume snapshot -r / "$SNAP" || die "snapshot failed"; fi
run mkdir -p "$BACKUP/boot" "$BACKUP/pkgs"
run cp -a /boot/limine.conf /etc/default/limine "$BACKUP/boot/" 
[[ -d /boot/${MID}/linux-cachyos ]] && run cp -a "/boot/${MID}/linux-cachyos" "$BACKUP/boot/"
# original CachyOS packages, for a one-command rollback
for f in /tmp/laden-kpkg/linux-cachyos-{,headers-}7.3.3-1-x86_64_v3.pkg.tar.zst; do
  [[ -f $f ]] && run cp -a "$f" "${f%.zst}.zst.sig" "$BACKUP/pkgs/" 2>/dev/null || true
done
[[ $DRY -eq 1 ]] || kingston_sections /boot/limine.conf > "$BACKUP/kingston-sections.before"

# ---- publish repo + install ---------------------------------------------------
run install -d -m0755 /srv/laden-repo "$DEST_REPO"
run rsync -a --delete --chown=root:root --chmod=D0755,F0644 "${SRC_REPO}/" "${DEST_REPO}/"
run pacman -Sy
if [[ $ALREADY -eq 0 ]]; then
  # --ask 4 = answer "yes" only to "remove conflicting package?" (linux-cachyos[-headers])
  run pacman -S --noconfirm --ask 4 laden/linux-laden laden/linux-laden-headers
fi

# ---- Limine: linux-laden first in the "Laden OS" section ------------------------
if [[ $DRY -eq 0 ]]; then
  python3 - /boot/limine.conf <<'PY'
import re, sys
p = sys.argv[1]; t = open(p).read()
parts = re.split(r'(?m)^(?=/\+)', t)
for i, s in enumerate(parts):
    if not s.startswith('/+Laden OS'): continue
    blocks = re.split(r'(?m)^(?=  //)', s)
    head, ents = blocks[0], blocks[1:]
    laden = [b for b in ents if 'kernel-id=linux-laden ' in b or b.startswith('  //linux-laden\n')]
    rest = [b for b in ents if b not in laden]
    if laden and ents and ents[0] not in laden:
        for b in rest + laden:
            if not b.endswith('\n\n'): pass
        new = head + "".join(laden).rstrip('\n') + '\n\n' + "".join(rest).rstrip('\n') + '\n\n'
        parts[i] = new
        open(p, 'w').write("".join(parts)); print("moved linux-laden to the top of Laden OS")
    else:
        print("linux-laden already first (or missing)")
PY
  kingston_sections /boot/limine.conf > "$BACKUP/kingston-sections.after"
  if cmp -s "$BACKUP/kingston-sections.before" "$BACKUP/kingston-sections.after"; then
    say "Kingston boot entries unchanged"
  else
    die "Kingston entries changed! Compare $BACKUP/kingston-sections.{before,after}; original: $BACKUP/boot/limine.conf"
  fi
  sed -i 's/^# Kernel package names remain linux-cachyos\*; do not rename packages\./# Main kernel package is linux-laden (repackaged CachyOS kernel); LTS stays linux-cachyos-lts./' /etc/default/limine
else
  say "DRY-RUN: move //linux-laden to the top of /+Laden OS in /boot/limine.conf; verify Kingston sections unchanged"
fi

# ---- cleanups -----------------------------------------------------------------
if [[ $CLEANUP -eq 1 ]]; then
  if pacman -Q linux-headers >/dev/null 2>&1; then
    if [[ "$(pactree -rlu linux-headers | grep -vx linux-headers | wc -l)" -eq 0 ]] && ! pacman -Q linux >/dev/null 2>&1; then
      say "removing orphaned linux-headers $(pacman -Q linux-headers | awk '{print $2}') (no 'linux' kernel, no reverse deps)"
      run pacman -R --noconfirm linux-headers
    else say "keeping linux-headers (has reverse deps or linux is installed)"; fi
  fi
  if pacman -Q lib32-opencl-nvidia-580xx >/dev/null 2>&1; then
    say "swapping lib32-opencl-nvidia-580xx -> lib32-opencl-nvidia (matches nvidia-utils $(pacman -Q nvidia-utils | awk '{print $2}'))"
    run pacman -S --noconfirm --ask 4 lib32-opencl-nvidia
  fi
fi

# ---- verify --------------------------------------------------------------------
if [[ $DRY -eq 0 ]]; then
  echo; pacman -Q linux-laden linux-laden-headers linux-cachyos-lts linux-cachyos-lts-headers lib32-opencl-nvidia 2>&1 || true
  pacman -Q linux-cachyos linux-cachyos-headers linux-headers lib32-opencl-nvidia-580xx 2>&1 | sed 's/^/  /' || true
  cat "/usr/lib/modules/${KVER}/pkgbase"
  dkms status
  for m in nvidia nvidia_drm nvidia_modeset nvidia_uvm hid_xpadneo; do
    printf '%-16s %s\n' "$m" "$(modinfo -k "$KVER" -F filename "$m" 2>/dev/null || echo MISSING)"
  done
  ls -la "/boot/${MID}/linux-laden/" "/boot/${MID}/linux-cachyos-lts/"
  lsinitcpio "/boot/${MID}/linux-laden/initramfs" | grep -E 'nvidia' | head -5 || true
  limine-entry-tool --tree 4 --no-hooks
  grep -nE '^(default_entry|timeout)' /boot/limine.conf
  say "done. Snapshot: $SNAP  Backups: $BACKUP"
else
  say "dry-run finished — nothing changed"
fi
