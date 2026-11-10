# laden-terminal

System default Laden OS LCP/CockPit terminal look.

- Fish: vendor functions + greeting (no unconditional fastfetch in laden-config).
- Fastfetch: `/etc/xdg/fastfetch/config.jsonc`
- CockPit theme: `/usr/share/laden/terminal/cockpit/laden-theme.lua`
- New users: `/etc/skel/.config/cockpit/{wezterm.lua,laden-theme.lua}`

Per-user override still works under `~/.config/`. No host `/home/...` paths.
