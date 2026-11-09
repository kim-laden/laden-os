#!/usr/bin/env bash
# Laden OS — per-user Plasma / fish rebrand (NO sudo).
# Usage: bash rebrand/apply-user-rebrand.sh [--dry-run]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

for arg in "$@"; do
  case "$arg" in
    --dry-run|-n) DRY_RUN=1 ;;
    -h|--help)
      echo "Usage: bash rebrand/apply-user-rebrand.sh [--dry-run]"
      exit 0
      ;;
    *) die "unknown arg: $arg" ;;
  esac
done

[[ "${EUID}" -ne 0 ]] || die "Do NOT run apply-user-rebrand.sh as root"

WP8K="/usr/share/backgrounds/laden/laden-os-lets-do-it-v2-7680x4320.png"
if [[ ! -f "${WP8K}" ]]; then
  WP8K="${BRANDING}/laden-os-lets-do-it-v2-7680x4320.png"
fi

log "=== User rebrand for ${USER} (dry_run=${DRY_RUN}) ==="

# Look and feel
if command -v plasma-apply-lookandfeel >/dev/null; then
  run plasma-apply-lookandfeel -a org.laden.os || log "WARN: plasma-apply-lookandfeel failed (is org.laden.os installed?)"
else
  log "WARN: plasma-apply-lookandfeel not found"
fi

# Wallpaper
if [[ -f "${WP8K}" ]]; then
  if command -v plasma-apply-wallpaperimage >/dev/null; then
    run plasma-apply-wallpaperimage "${WP8K}" || log "WARN: plasma-apply-wallpaperimage failed"
  else
    log "WARN: plasma-apply-wallpaperimage not found; set wallpaper manually to ${WP8K}"
  fi
else
  log "WARN: wallpaper not found at ${WP8K}"
fi

# Color scheme if tool exists
if command -v plasma-apply-colorscheme >/dev/null; then
  run plasma-apply-colorscheme LadenDark || true
fi

# Fish config: stop sourcing cachyos-config.fish; source Laden instead
FISH_CFG="${HOME}/.config/fish/config.fish"
mkdir -p "${HOME}/.config/fish"
if [[ -f "${FISH_CFG}" ]]; then
  if [[ "${DRY_RUN}" -eq 1 ]]; then
    echo "DRY-RUN: backup and rewrite ${FISH_CFG} to drop cachyos source"
  else
    cp -a "${FISH_CFG}" "${FISH_CFG}.bak-pre-laden-rebrand-${DATE_TAG}"
    # Remove cachyos source lines; ensure Laden source present
    python3 - <<PY
from pathlib import Path
p = Path("${FISH_CFG}")
lines = p.read_text().splitlines(True)
out = []
skip_block = False
for line in lines:
    if "cachyos-fish-config" in line or "cachyos-config.fish" in line:
        continue
    if line.strip().startswith("# --- Laden OS (managed"):
        skip_block = True
        continue
    if skip_block:
        if line.strip().startswith("# --- end Laden OS"):
            skip_block = False
        continue
    out.append(line)
snippet = Path("${ASSETS}/fish/user-config.fish.snippet").read_text()
if "laden-config.fish" not in "".join(out):
    if out and not out[-1].endswith("\n"):
        out.append("\n")
    out.append("\n" + snippet + "\n")
p.write_text("".join(out))
print("Updated", p)
PY
  fi
else
  if [[ "${DRY_RUN}" -eq 1 ]]; then
    echo "DRY-RUN: create ${FISH_CFG} with Laden snippet"
  else
    cat "${ASSETS}/fish/user-config.fish.snippet" > "${FISH_CFG}"
  fi
fi

# Local desktop overrides (user-level hide/rebrand)
mkdir -p "${HOME}/.local/share/applications"
if [[ "${DRY_RUN}" -eq 1 ]]; then
  echo "DRY-RUN: copy desktop overrides to ~/.local/share/applications"
else
  cp -a "${ASSETS}/desktop-overrides/." "${HOME}/.local/share/applications/"
  update-desktop-database "${HOME}/.local/share/applications" 2>/dev/null || true
fi

log "=== User rebrand done ==="
echo "Log out/in (or reboot) for splash/tray icon changes to fully apply."
echo "Wallpaper target: ${WP8K}"
