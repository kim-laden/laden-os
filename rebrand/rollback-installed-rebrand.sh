#!/usr/bin/env bash
# Restore files from a laden-rebrand backup directory.
# Usage:
#   sudo bash rebrand/rollback-installed-rebrand.sh /var/backups/laden-rebrand/<date>
#   sudo bash rebrand/rollback-installed-rebrand.sh --latest
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

[[ "${EUID}" -eq 0 ]] || die "Run as root"

TARGET="${1:-}"
if [[ "${TARGET}" == "--latest" ]] || [[ -z "${TARGET}" ]]; then
  TARGET="$(ls -1d /var/backups/laden-rebrand/* 2>/dev/null | sort | tail -1 || true)"
fi
[[ -n "${TARGET}" && -d "${TARGET}" ]] || die "Usage: sudo bash rebrand/rollback-installed-rebrand.sh /var/backups/laden-rebrand/<date>|--latest"

log "Rolling back from ${TARGET}"

# Restore every backed-up file preserving relative path
while IFS= read -r -d '' f; do
  rel="${f#"${TARGET}"}"
  [[ "${rel}" == "/META.txt" ]] && continue
  dest="${rel}"
  log "restore ${dest}"
  mkdir -p "$(dirname "${dest}")"
  cp -a "${f}" "${dest}"
done < <(find "${TARGET}" -type f -print0)

# Prefer restoring plymouth theme from backup of plymouthd.conf; also try setting previous theme
if [[ -f /etc/plymouth/plymouthd.conf ]]; then
  prev="$(awk -F= '/^Theme=/{print $2}' /etc/plymouth/plymouthd.conf || true)"
  if [[ -n "${prev}" ]]; then
    plymouth-set-default-theme "${prev}" || true
  fi
fi

if command -v limine-mkinitcpio >/dev/null; then
  limine-mkinitcpio || true
elif command -v mkinitcpio >/dev/null; then
  mkinitcpio -P || true
fi

log "Rollback file restore complete. Reinstall removed packages manually if needed, e.g.:"
echo "  sudo pacman -S cachyos-hello cachyos-wallpapers cachyos-plymouth-bootanimation ..."
echo "Consider: snapper -c root list   # and snapper undochange / rollback if required"
