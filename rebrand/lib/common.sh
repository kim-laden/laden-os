# shellcheck shell=bash
# Shared helpers for Laden OS rebrand scripts. Sourced, not executed.

REBRAND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "${REBRAND_DIR}/.." && pwd)"
ASSETS="${REBRAND_DIR}/assets"
BRANDING="${REPO_ROOT}/branding"

DRY_RUN=0
DATE_TAG="$(date +%Y%m%d-%H%M%S)"
BACKUP_ROOT="/var/backups/laden-rebrand/${DATE_TAG}"
LOG_FILE="/var/log/laden-rebrand.log"

# Packages we NEVER remove
PROTECTED_PKGS=(
  linux-cachyos linux-cachyos-headers linux-cachyos-lts linux-cachyos-lts-headers
  cachyos-keyring cachyos-mirrorlist cachyos-v3-mirrorlist cachyos-v4-mirrorlist
  cachyos-settings cachyos-hooks cachyos-ananicy-rules cachyos-snapper-support
  cachyos-rate-mirrors
  cachyos-gaming-meta cachyos-gaming-applications
  proton-cachyos-native proton-cachyos-slr wine-cachyos-opt
  python-cachy
  cachy-update
)

# Cosmetic packages safe to remove (verified Required By: None as of 2026-11-09)
# Order: dependents first where relevant (kde-settings before alacritty-config)
COSMETIC_REMOVE=(
  cachyos-hello
  cachyos-wallpapers
  cachyos-emerald-kde-theme-git
  cachyos-nord-kde-theme-git
  cachyos-iridescent-kde
  cachyos-packageinstaller
  cachyos-benchmarker
  cachyos-micro-settings
  cachyos-kde-settings
  cachyos-alacritty-config
  cachyos-plymouth-bootanimation
  cachyos-plymouth-theme
  cachyos-fish-config
  cachyos-zsh-config
)

IGNORE_PKG_LIST=(
  cachyos-hello
  cachyos-wallpapers
  cachyos-emerald-kde-theme-git
  cachyos-nord-kde-theme-git
  cachyos-iridescent-kde
  cachyos-packageinstaller
  cachyos-benchmarker
  cachyos-micro-settings
  cachyos-kde-settings
  cachyos-alacritty-config
  cachyos-plymouth-bootanimation
  cachyos-plymouth-theme
  cachyos-fish-config
  cachyos-zsh-config
)

log() {
  local msg="[$(date '+%Y-%m-%d %H:%M:%S %z')] $*"
  if [[ "${DRY_RUN}" -eq 1 ]]; then
    echo "DRY-RUN: $*"
  else
    echo "$msg"
    if [[ -w "$(dirname "${LOG_FILE}")" ]] || [[ -w "${LOG_FILE}" ]]; then
      echo "$msg" >> "${LOG_FILE}" 2>/dev/null || true
    fi
  fi
}

die() { log "ERROR: $*"; exit 1; }

require_root() {
  if [[ "${DRY_RUN}" -eq 1 ]]; then
    return 0
  fi
  [[ "${EUID}" -eq 0 ]] || die "Run as root: sudo bash rebrand/apply-installed-rebrand.sh"
}

run() {
  if [[ "${DRY_RUN}" -eq 1 ]]; then
    echo "DRY-RUN exec: $*"
    return 0
  fi
  log "exec: $*"
  "$@"
}

backup_file() {
  local src="$1"
  [[ -e "${src}" ]] || return 0
  local dest="${BACKUP_ROOT}${src}"
  if [[ "${DRY_RUN}" -eq 1 ]]; then
    echo "DRY-RUN backup: ${src} -> ${dest}"
    return 0
  fi
  mkdir -p "$(dirname "${dest}")"
  cp -a "${src}" "${dest}"
  log "backed up ${src}"
}

install_file() {
  local src="$1" dest="$2" mode="${3:-0644}"
  [[ -f "${src}" ]] || die "missing asset: ${src}"
  backup_file "${dest}"
  if [[ "${DRY_RUN}" -eq 1 ]]; then
    echo "DRY-RUN install: ${src} -> ${dest} (mode ${mode})"
    return 0
  fi
  mkdir -p "$(dirname "${dest}")"
  install -m "${mode}" "${src}" "${dest}"
  log "installed ${dest}"
}

install_tree() {
  local src="$1" dest="$2"
  [[ -d "${src}" ]] || die "missing dir: ${src}"
  if [[ "${DRY_RUN}" -eq 1 ]]; then
    echo "DRY-RUN rsync: ${src}/ -> ${dest}/"
    return 0
  fi
  mkdir -p "${dest}"
  rsync -a "${src}/" "${dest}/"
  log "synced ${src} -> ${dest}"
}

pkg_installed() {
  pacman -Q "$1" &>/dev/null
}

assert_not_protected() {
  local p="$1"
  local x
  for x in "${PROTECTED_PKGS[@]}"; do
    if [[ "$p" == "$x" ]]; then
      die "refusing to remove protected package: $p"
    fi
  done
  return 0
}
