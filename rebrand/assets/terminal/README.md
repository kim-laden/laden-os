# Laden OS terminal look (LCP / CockPit)

SPDX-License-Identifier: MIT (c) Laden AS. The Laden "L" mark inside
`fastfetch/config.jsonc` (`logo.source`) is Laden AS branding
(`LICENSES/LicenseRef-LadenAS-Branding.txt`).

Status: tried on ladenx first (per-user). Shipped by package `laden-terminal` (system default + /etc/skel for new users).

| File | Installed to (per user) | What it does |
|---|---|---|
| `fastfetch/config.jsonc` | `~/.config/fastfetch/config.jsonc` | Compact emerald "L" mark, grouped sections (system / hardware / displays / storage & power), short keys with Nerd Font icons, bars for memory/disk/battery. Info lines stay <= 53 columns. |
| `fish/functions/laden_greeting.fish` | `~/.config/fish/functions/` | Responsive greeting: logo beside info at >= 78 cols, logo on top at 56-77, info only at 40-55, one line below 40. Then one short Laden line. `set -gx LADEN_QUIET 1` turns it off. |
| `fish/functions/fish_greeting.fish` | `~/.config/fish/functions/` | Replaces "Welcome to fish" with `laden_greeting`. |
| `fish/functions/fish_prompt.fish` | `~/.config/fish/functions/` | Two-line emerald prompt: `lz`, path, git branch/state, exit status only when non-zero, duration when >= 2 s, ROOT badge, host only over SSH. WezTerm/CockPit only (or `set -gx LADEN_PROMPT 1`); other terminals keep their stock prompt. |
| `fish/conf.d/00-laden-config.fish` | `~/.config/fish/conf.d/` | Shadows `/etc/fish/conf.d/00-laden-config.fish` for this user: loads the same system config but stops its unconditional `fastfetch`, so the greeting prints it once, sized to the pane. |
| `cockpit/laden-theme.lua` | `~/.config/cockpit/laden-theme.lua` | LadenDark 16-colour palette (green = LadenDark #39DC9A), cursor, selection, padding. Hooked at the end of `~/.config/cockpit/wezterm.lua`. Colours skipped when CockPit `COLOR_SCHEME` is set. Default font 14.5 pt (12 pt + two Ctrl+= steps) unless cockpit.conf `FONT_SIZE` is set; `install-user.sh` moves `FONT_SIZE=11/12` to 14.5. The 96x54 start size (cells, sized for 12 pt) is scaled by 12/font so the window keeps about the same pixel size (79x45 at 14.5 pt -> side-by-side logo). |

Install / restore:

```sh
bash rebrand/assets/terminal/install-user.sh      # backs up to ~/.config/laden/backups/lcp-terminal-<ts>/
bash ~/.config/laden/backups/lcp-terminal-<ts>/restore.sh
```

Packaging later: ship the fish functions in `/usr/share/fish/vendor_functions.d/`
(user files still override them), drop the direct `fastfetch` call from
`packages/laden-desktop-settings/laden-config.fish`, and install the fastfetch
config as `/etc/xdg/fastfetch/config.jsonc` from laden-branding.
