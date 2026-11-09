# Package decisions (read-only checks on Helios, 2026-11-09)

## ID / LOGO
- Airootfs `apply-os-release` already uses `ID=ladenos` (installed clone had `ID=laden`).
- Kit standardizes on **`ID=ladenos`**, `ID_LIKE=arch`, **`LOGO=laden-os`** (matches icon file names).

## Tray approach
- `cachy-update` **Conflicts With** `arch-update` and already provides `/usr/bin/arch-update`.
- Removing it to install plain `arch-update` is unnecessary risk.
- **Keep `cachy-update`**, override `/etc/xdg/autostart/arch-update-tray.desktop` + icon files with Laden branding.

## Cosmetic removals (all `Required By: None`)
Verified with `pacman -Qi` / `pactree -r` before baking into the script:
- cachyos-hello, cachyos-wallpapers
- cachyos-emerald-kde-theme-git, cachyos-nord-kde-theme-git, cachyos-iridescent-kde
- cachyos-packageinstaller, cachyos-benchmarker, cachyos-micro-settings
- cachyos-kde-settings (only reverse-dep of cachyos-alacritty-config)
- cachyos-alacritty-config (remove after kde-settings)
- cachyos-plymouth-bootanimation, cachyos-plymouth-theme
- cachyos-fish-config, cachyos-zsh-config (Laden fish installed first)

## Never remove
linux-cachyos*, cachyos-keyring, mirrorlists, repos, cachyos-settings/hooks/ananicy/snapper-support/rate-mirrors,
gaming meta + proton/wine builds, python-cachy, cachy-update.
