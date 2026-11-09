#!/usr/bin/env bash
# Laden OS — apply installed-system rebrand (Helios / Acer NVMe only).
# Usage:
#   sudo bash rebrand/apply-installed-rebrand.sh [--dry-run]
# Never touches Kingston nvme0n1. Never removes kernels/keyring/repos/gaming stack.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

for arg in "$@"; do
  case "$arg" in
    --dry-run|-n) DRY_RUN=1 ;;
    -h|--help)
      cat <<H
Usage: sudo bash rebrand/apply-installed-rebrand.sh [--dry-run]

Applies Laden OS branding on the installed Helios system (Acer nvme1n1).
Creates a snapper snapshot + file backups, then rebrands identity, boot
visuals, tray, desktop defaults, and removes cosmetic CachyOS packages.
H
      exit 0
      ;;
    *) die "unknown arg: $arg" ;;
  esac
done

require_root

# Refuse if someone tries to operate on Kingston by UUID in env (paranoia)
if [[ "${LADEN_ALLOW_KINGSTON:-}" == "1" ]]; then
  die "LADEN_ALLOW_KINGSTON is set — refusing (this kit never touches Kingston)"
fi

log "=== Laden OS installed rebrand start (dry_run=${DRY_RUN}) ==="
log "REBRAND_DIR=${REBRAND_DIR}"
log "BACKUP_ROOT=${BACKUP_ROOT}"

# ---------------------------------------------------------------------------
# 0. Safety: snapper snapshot + backup dir
# ---------------------------------------------------------------------------
safety_snapshot() {
  log "Creating pre-rebrand snapper snapshot (config root)"
  if [[ "${DRY_RUN}" -eq 1 ]]; then
    echo "DRY-RUN: snapper -c root create --description \"pre-rebrand-${DATE_TAG}\" --cleanup-algorithm number"
    echo "DRY-RUN: mkdir -p ${BACKUP_ROOT} ${LOG_FILE%/*}"
    return 0
  fi
  mkdir -p "${BACKUP_ROOT}"
  mkdir -p "$(dirname "${LOG_FILE}")"
  touch "${LOG_FILE}"
  # Record metadata
  {
    echo "date=${DATE_TAG}"
    echo "hostname=$(hostname)"
    echo "root_uuid=$(findmnt -no UUID / || true)"
    echo "boot_uuid=$(findmnt -no UUID /boot || true)"
    echo "cmdline=$(cat /proc/cmdline)"
    echo "NOTE: Kingston nvme0n1 must remain untouched"
  } > "${BACKUP_ROOT}/META.txt"
  # The cloned system has no /.snapshots subvolume, so snapper can fail.
  # Fall back to a plain read-only btrfs snapshot of / (the @ subvolume).
  if command -v snapper >/dev/null && [[ -d /.snapshots ]] \
     && snapper -c root create --description "pre-rebrand-${DATE_TAG}" --cleanup-algorithm number; then
    snapper -c root list | tee -a "${LOG_FILE}" | tail -5 || true
  else
    log "snapper unavailable or failed; using btrfs read-only snapshot instead"
    mkdir -p /.laden-snapshots
    btrfs subvolume snapshot -r / "/.laden-snapshots/pre-rebrand-${DATE_TAG}" \
      || die "btrfs snapshot failed"
    log "Snapshot: /.laden-snapshots/pre-rebrand-${DATE_TAG}"
  fi
}

# ---------------------------------------------------------------------------
# 1. Identity
# ---------------------------------------------------------------------------
apply_identity() {
  log "=== 1. Identity ==="
  install_file "${ASSETS}/os-identity/os-release" /etc/os-release 0644
  # Keep /usr/lib/os-release in sync (filesystem package may restore later; hook reapplies)
  backup_file /usr/lib/os-release
  if [[ "${DRY_RUN}" -eq 1 ]]; then
    echo "DRY-RUN: write matching /usr/lib/os-release"
  else
    install -m 0644 "${ASSETS}/os-identity/os-release" /usr/lib/os-release
  fi
  install_file "${ASSETS}/os-identity/lsb-release" /etc/lsb-release 0644

  # Icons: hicolor + pixmaps; also provide legacy 'cachyos' name pointing at Laden
  # so anything still looking for LOGO=cachyos shows Laden instead.
  local size dest
  for size in 16 22 24 32 48 64 128 256 512; do
    local src="${ASSETS}/icons/hicolor/${size}x${size}/apps/laden-os.png"
    [[ -f "${src}" ]] || continue
    dest="/usr/share/icons/hicolor/${size}x${size}/apps/laden-os.png"
    install_file "${src}" "${dest}" 0644
  done
  install_file "${ASSETS}/icons/laden-os.svg" /usr/share/icons/hicolor/scalable/apps/laden-os.svg 0644
  install_file "${ASSETS}/icons/laden-os.png" /usr/share/pixmaps/laden-os.png 0644
  install_file "${ASSETS}/icons/laden-os.svg" /usr/share/pixmaps/laden-os.svg 0644
  # Replace user-facing cachyos logo name with Laden artwork (do not delete if owned by pkg — overwrite + backup)
  backup_file /usr/share/icons/cachyos.svg
  if [[ "${DRY_RUN}" -eq 1 ]]; then
    echo "DRY-RUN: replace /usr/share/icons/cachyos.svg with laden-os.svg"
  else
    install -m 0644 "${ASSETS}/icons/laden-os.svg" /usr/share/icons/cachyos.svg
  fi

  # Install reapply helper + pacman hooks
  if [[ "${DRY_RUN}" -eq 1 ]]; then
    echo "DRY-RUN: install /usr/lib/laden-os/reapply-branding + pacman hooks"
  else
    mkdir -p /usr/lib/laden-os
    install -m 0755 "${REBRAND_DIR}/lib/reapply-branding" /usr/lib/laden-os/reapply-branding
    install -m 0644 "${ASSETS}/hooks/50-laden-os-release.hook" /etc/pacman.d/hooks/50-laden-os-release.hook
    install -m 0644 "${ASSETS}/hooks/zz-laden-ignore-cosmetic-notice.hook" /etc/pacman.d/hooks/zz-laden-ignore-cosmetic-notice.hook
    mkdir -p /usr/share/laden-os/os-identity
    install -m 0644 "${ASSETS}/os-identity/os-release" /usr/share/laden-os/os-identity/os-release
    install -m 0644 "${ASSETS}/os-identity/lsb-release" /usr/share/laden-os/os-identity/lsb-release
  fi

  # gtk-update-icon-cache if present
  if command -v gtk-update-icon-cache >/dev/null; then
    run gtk-update-icon-cache -f /usr/share/icons/hicolor || true
  fi
}

# ---------------------------------------------------------------------------
# 2. Boot visuals
# ---------------------------------------------------------------------------
apply_boot() {
  log "=== 2. Boot visuals ==="

  # Detect Limine enroll
  local enroll=0
  if grep -Eqs '^\s*ENABLE_ENROLL_LIMINE_CONFIG\s*=\s*yes' /etc/default/limine 2>/dev/null; then
    enroll=1
  fi
  log "Limine enroll enabled: ${enroll}"

  # Limine splash
  if [[ -f /boot/limine-splash.png ]] || [[ -d /boot ]]; then
    backup_file /boot/limine-splash.png
    if [[ "${DRY_RUN}" -eq 1 ]]; then
      echo "DRY-RUN: install limine-splash.png -> /boot/limine-splash.png"
    else
      install -m 0644 "${ASSETS}/limine/limine-splash.png" /boot/limine-splash.png
      # ESP often wants executable bit on vfat; mode may be ignored
      log "installed /boot/limine-splash.png"
    fi
  fi

  # Soft-rename Laden kernel display labels in limine.conf ONLY if enroll is off
  # and the Laden OS section is present. Kernel paths stay intact.
  # /boot is root-only on this install; treat as present when ESP is mounted.
  local limine_conf_ok=0
  if [[ "${enroll}" -eq 0 ]]; then
    if [[ -r /boot/limine.conf ]] || findmnt -n /boot >/dev/null 2>&1; then
      limine_conf_ok=1
    fi
  fi
  if [[ "${limine_conf_ok}" -eq 1 ]]; then
    backup_file /boot/limine.conf
    if [[ "${DRY_RUN}" -eq 1 ]]; then
      echo "DRY-RUN: rewrite display labels under /+Laden OS (linux-cachyos -> Laden kernel)"
    else
      python3 - <<'PY'
from pathlib import Path
p = Path("/boot/limine.conf")
text = p.read_text()
lines = text.splitlines(True)
out = []
in_laden = False
for line in lines:
    stripped = line.lstrip()
    # top-level entries start with /+
    if stripped.startswith("/+"):
        in_laden = stripped.startswith("/+Laden OS")
    if in_laden:
        if stripped.startswith("//linux-cachyos-lts"):
            line = line.replace("//linux-cachyos-lts", "//Laden kernel LTS", 1)
        elif stripped.startswith("//linux-cachyos"):
            line = line.replace("//linux-cachyos", "//Laden kernel", 1)
    # Leave Kingston /+CachyOS* entries untouched
    out.append(line)
p.write_text("".join(out))
print("limine.conf display labels updated under Laden OS section only")
PY
    fi
  else
    log "Skipping limine.conf label edits (enroll=${enroll} or missing conf)"
  fi

  # Optional: set TARGET_OS_NAME for entry tool / snapper sync
  backup_file /etc/default/limine
  if [[ "${DRY_RUN}" -eq 1 ]]; then
    echo "DRY-RUN: ensure TARGET_OS_NAME=Laden OS note in /etc/default/limine (comment)"
  else
    if ! grep -q 'Laden OS rebrand' /etc/default/limine 2>/dev/null; then
      cat >> /etc/default/limine <<'E'
# Laden OS rebrand: display branding is in /boot/limine.conf (interface_branding).
# Kernel package names remain linux-cachyos*; do not rename packages.
#TARGET_OS_NAME="Laden OS"
E
    fi
  fi

  # Plymouth theme
  if [[ "${DRY_RUN}" -eq 1 ]]; then
    echo "DRY-RUN: install plymouth theme laden -> /usr/share/plymouth/themes/laden"
    echo "DRY-RUN: plymouth-set-default-theme laden"
    echo "DRY-RUN: limine-mkinitcpio or mkinitcpio -P"
  else
    mkdir -p /usr/share/plymouth/themes/laden
    rsync -a "${ASSETS}/plymouth/laden/" /usr/share/plymouth/themes/laden/
    backup_file /etc/plymouth/plymouthd.conf
    plymouth-set-default-theme laden
    # Prefer limine-mkinitcpio when present (keeps Limine entries in sync)
    if command -v limine-mkinitcpio >/dev/null; then
      limine-mkinitcpio
    elif command -v mkinitcpio >/dev/null; then
      mkinitcpio -P
    else
      die "neither limine-mkinitcpio nor mkinitcpio found"
    fi
  fi
}

# ---------------------------------------------------------------------------
# 3. Tray (keep cachy-update binary; override branding)
# ---------------------------------------------------------------------------
apply_tray() {
  log "=== 3. Tray branding (keep cachy-update / arch-update functionality) ==="
  # Rationale: cachy-update Conflicts with arch-update and already provides
  # /usr/bin/arch-update. Swapping packages would disrupt updates. We override
  # autostart + icons with Laden branding instead.
  install_file "${ASSETS}/desktop-overrides/arch-update-tray.desktop" \
    /etc/xdg/autostart/arch-update-tray.desktop 0644
  # Higher-precedence application override
  if [[ "${DRY_RUN}" -eq 1 ]]; then
    echo "DRY-RUN: mkdir -p /usr/local/share/applications"
  else
    mkdir -p /usr/local/share/applications
  fi
  install_file "${ASSETS}/desktop-overrides/arch-update-tray.desktop" \
    /usr/local/share/applications/arch-update-tray.desktop 0644
  install_file "${ASSETS}/desktop-overrides/arch-update.desktop" \
    /usr/local/share/applications/arch-update.desktop 0644

  # Install Laden tray icons and also overwrite the cachy-update icon names
  # that the binary may still request by hard-coded name.
  install_file "${ASSETS}/icons/tray/laden-update.svg" \
    /usr/share/icons/hicolor/scalable/apps/laden-update.svg 0644
  if [[ "${DRY_RUN}" -eq 1 ]]; then
    echo "DRY-RUN: overlay cachy-update*.svg icons with Laden artwork"
  else
    local icon
    for icon in \
      cachy-update-blue.svg \
      cachy-update-dark.svg \
      cachy-update-light.svg \
      cachy-update_updates-available-blue.svg \
      cachy-update_updates-available-blue-cb.svg \
      cachy-update_updates-available-dark.svg \
      cachy-update_updates-available-dark-cb.svg \
      cachy-update_updates-available-light.svg \
      cachy-update_updates-available-light-cb.svg
    do
      local path="/usr/share/icons/hicolor/scalable/apps/${icon}"
      if [[ -e "${path}" ]]; then
        backup_file "${path}"
        install -m 0644 "${ASSETS}/icons/tray/laden-update.svg" "${path}"
      fi
    done
    gtk-update-icon-cache -f /usr/share/icons/hicolor || true
  fi
}

# ---------------------------------------------------------------------------
# 4. Desktop defaults + wallpapers + look-and-feel
# ---------------------------------------------------------------------------
apply_desktop() {
  log "=== 4. Desktop defaults ==="

  # Look-and-feel
  if [[ "${DRY_RUN}" -eq 1 ]]; then
    echo "DRY-RUN: install org.laden.os look-and-feel + LadenDark.colors"
  else
    mkdir -p /usr/share/plasma/look-and-feel/org.laden.os
    rsync -a "${ASSETS}/look-and-feel/org.laden.os/" /usr/share/plasma/look-and-feel/org.laden.os/
    install -m 0644 "${ASSETS}/LadenDark.colors" /usr/share/color-schemes/LadenDark.colors
  fi

  # Wallpapers: backgrounds/laden (all v2 + keep v1) and Plasma wallpaper package
  if [[ "${DRY_RUN}" -eq 1 ]]; then
    echo "DRY-RUN: install wallpapers from branding/ into /usr/share/backgrounds/laden and /usr/share/wallpapers/LadenOS"
  else
    mkdir -p /usr/share/backgrounds/laden
    mkdir -p /usr/share/wallpapers/LadenOS/contents/images
    # v2 (default) + v1 (keep alongside, never overwrite v1 if already custom — copy once)
    local f
    for f in \
      laden-os-lets-do-it-v2-7680x4320.png \
      laden-os-lets-do-it-v2-3840x2160.png \
      laden-os-lets-do-it-v2-3440x1440.png \
      laden-os-lets-do-it-v2-1920x1080.png \
      laden-os-lets-do-it-v2-1920x1080-sharp.png \
      laden-os-lets-do-it-7680x4320.png \
      laden-os-lets-do-it-3840x2160.png \
      laden-os-lets-do-it-3440x1440.png \
      laden-os-lets-do-it-1920x1080.png
    do
      [[ -f "${BRANDING}/${f}" ]] || continue
      install -m 0644 "${BRANDING}/${f}" "/usr/share/backgrounds/laden/${f}"
    done
    # Plasma images by resolution name
    [[ -f "${BRANDING}/laden-os-lets-do-it-v2-7680x4320.png" ]] && \
      install -m 0644 "${BRANDING}/laden-os-lets-do-it-v2-7680x4320.png" \
        /usr/share/wallpapers/LadenOS/contents/images/7680x4320.png
    [[ -f "${BRANDING}/laden-os-lets-do-it-v2-3840x2160.png" ]] && \
      install -m 0644 "${BRANDING}/laden-os-lets-do-it-v2-3840x2160.png" \
        /usr/share/wallpapers/LadenOS/contents/images/3840x2160.png
    [[ -f "${BRANDING}/laden-os-lets-do-it-v2-1920x1080.png" ]] && \
      install -m 0644 "${BRANDING}/laden-os-lets-do-it-v2-1920x1080.png" \
        /usr/share/wallpapers/LadenOS/contents/images/1920x1080.png
    [[ -f "${BRANDING}/laden-os-lets-do-it-v2-3440x1440.png" ]] && \
      install -m 0644 "${BRANDING}/laden-os-lets-do-it-v2-3440x1440.png" \
        /usr/share/wallpapers/LadenOS/contents/images/3440x1440.png
    install -m 0644 "${ASSETS}/wallpapers/LadenOS/metadata.json" \
      /usr/share/wallpapers/LadenOS/metadata.json
    # checksums for verification
    [[ -f "${BRANDING}/SHA256SUMS-wallpapers-v2.txt" ]] && \
      install -m 0644 "${BRANDING}/SHA256SUMS-wallpapers-v2.txt" \
        /usr/share/backgrounds/laden/SHA256SUMS-wallpapers-v2.txt
  fi

  # /etc/xdg defaults for new users
  install_file "${ASSETS}/xdg/kdeglobals" /etc/xdg/kdeglobals 0644
  install_file "${ASSETS}/xdg/ksplashrc" /etc/xdg/ksplashrc 0644

  # Fish system config
  if [[ "${DRY_RUN}" -eq 1 ]]; then
    echo "DRY-RUN: install /usr/share/laden-os/fish/* and /etc/fish/conf.d/laden-*.fish"
  else
    mkdir -p /usr/share/laden-os/fish /etc/fish/conf.d
    install -m 0644 "${ASSETS}/fish/laden-config.fish" /usr/share/laden-os/fish/laden-config.fish
    install -m 0644 "${ASSETS}/fish/laden-colors.fish" /usr/share/laden-os/fish/laden-colors.fish
    install -m 0644 "${ASSETS}/fish/laden-colors.fish" /etc/fish/conf.d/laden-colors.fish
    install -m 0644 "${ASSETS}/fish/laden-os.fish" /etc/fish/conf.d/laden-os.fish
    # Drop-in that sources Laden config for all users (after removing cachyos-fish-config)
    cat > /etc/fish/conf.d/00-laden-config.fish <<'F'
# Laden OS system fish bootstrap
if test -f /usr/share/laden-os/fish/laden-config.fish
    source /usr/share/laden-os/fish/laden-config.fish
end
F
    chmod 0644 /etc/fish/conf.d/00-laden-config.fish
  fi

  # Menu entry overrides (Kernel Manager / SCX / hide hello+pi)
  if [[ "${DRY_RUN}" -eq 1 ]]; then
    echo "DRY-RUN: install /usr/local/share/applications overrides for Kernel Manager, SCX, hello, pi"
  else
    mkdir -p /usr/local/share/applications
    install -m 0644 "${ASSETS}/desktop-overrides/org.cachyos.KernelManager.desktop" \
      /usr/local/share/applications/org.cachyos.KernelManager.desktop
    install -m 0644 "${ASSETS}/desktop-overrides/org.cachyos.scx-manager.desktop" \
      /usr/local/share/applications/org.cachyos.scx-manager.desktop
    install -m 0644 "${ASSETS}/desktop-overrides/cachyos-hello.desktop" \
      /usr/local/share/applications/cachyos-hello.desktop
    install -m 0644 "${ASSETS}/desktop-overrides/cachyos-pi.desktop" \
      /usr/local/share/applications/cachyos-pi.desktop
    update-desktop-database /usr/local/share/applications 2>/dev/null || true
  fi
}

# ---------------------------------------------------------------------------
# 5. Remove cosmetic packages + IgnorePkg
# ---------------------------------------------------------------------------
remove_cosmetics() {
  log "=== 5. Remove cosmetic CachyOS packages ==="
  local to_remove=()
  local p
  for p in "${COSMETIC_REMOVE[@]}"; do
    assert_not_protected "$p"
    if pkg_installed "$p"; then
      to_remove+=("$p")
    else
      log "skip (not installed): $p"
    fi
  done
  if [[ "${#to_remove[@]}" -eq 0 ]]; then
    log "No cosmetic packages to remove"
  else
    log "Will remove: ${to_remove[*]}"
    if [[ "${DRY_RUN}" -eq 1 ]]; then
      echo "DRY-RUN: pacman -Rns --noconfirm ${to_remove[*]}"
    else
      pacman -Rns --noconfirm "${to_remove[@]}"
    fi
  fi

  # IgnorePkg so metas don't silently pull cosmetics back
  backup_file /etc/pacman.conf
  if [[ "${DRY_RUN}" -eq 1 ]]; then
    echo "DRY-RUN: set IgnorePkg for cosmetic packages in /etc/pacman.conf"
  else
    python3 - <<'PY'
from pathlib import Path
conf = Path("/etc/pacman.conf")
text = conf.read_text()
pkgs = " ".join([
  "cachyos-hello", "cachyos-wallpapers",
  "cachyos-emerald-kde-theme-git", "cachyos-nord-kde-theme-git", "cachyos-iridescent-kde",
  "cachyos-packageinstaller", "cachyos-benchmarker", "cachyos-micro-settings",
  "cachyos-kde-settings", "cachyos-alacritty-config",
  "cachyos-plymouth-bootanimation", "cachyos-plymouth-theme",
  "cachyos-fish-config", "cachyos-zsh-config",
])
line = f"IgnorePkg = {pkgs}\n"
import re
if re.search(r'^IgnorePkg\s*=', text, re.M):
    text = re.sub(r'^#?\s*IgnorePkg\s*=.*$', line.strip(), text, count=1, flags=re.M)
else:
    # insert after HoldPkg
    if "HoldPkg" in text:
        text = re.sub(r'^(HoldPkg\s*=.*)$', r'\1\n' + line.strip(), text, count=1, flags=re.M)
    else:
        text = line + text
conf.write_text(text)
print("IgnorePkg updated")
PY
  fi
}

# ---------------------------------------------------------------------------
main() {
  safety_snapshot
  apply_identity
  apply_boot
  apply_tray
  apply_desktop
  remove_cosmetics
  log "=== Rebrand complete ==="
  if [[ "${DRY_RUN}" -eq 1 ]]; then
    echo
    echo "Dry-run finished. Apply for real with:"
    echo "  sudo bash ${REBRAND_DIR}/apply-installed-rebrand.sh"
    echo "Then as your user:"
    echo "  bash ${REBRAND_DIR}/apply-user-rebrand.sh"
  else
    echo
    echo "System rebrand applied. Backups: ${BACKUP_ROOT}"
    echo "Log: ${LOG_FILE}"
    echo "Now run as your user (no sudo):"
    echo "  bash ${REBRAND_DIR}/apply-user-rebrand.sh"
    echo "Then reboot to see Limine splash + Plymouth."
  fi
}

main
