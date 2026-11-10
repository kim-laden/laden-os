# laden-terminal

System default Laden OS LCP/CockPit terminal look.

- Fish: vendor functions + greeting (no unconditional fastfetch in laden-config).
- Fastfetch: `/etc/xdg/fastfetch/config.jsonc` (used when the user has no `~/.config/fastfetch`).
- CockPit / WezTerm theme: `/usr/share/laden/terminal/cockpit/laden-theme.lua`
  (opacity 0.86 so the Laden OS wallpaper shows through, emerald border, JetBrains Mono + Nerd Font).
- Launcher: `/usr/bin/lcp` (uses The CockPit when installed, otherwise WezTerm + the Laden theme).
- New users (`/etc/skel` only; existing homes are never overwritten):
  - `.config/wezterm/wezterm.lua`
  - `.config/cockpit/{wezterm.lua,laden-theme.lua}`
  - `.config/the-cockpit/local.lua`

Per-user override still works under `~/.config/`. No host `/home/...` paths. Values in the
fetch greeting (hostname, CPU, GPU, memory, displays) are detected live.

`lcp` is the Plasma default terminal (`TerminalApplication=lcp`, set by laden-desktop-settings)
and takes the usual terminal options: `lcp -e CMD`, `lcp --workdir DIR`. Meta+Enter and
Ctrl+Alt+T open it (`X-KDE-Shortcuts` in `lcp.desktop`).
