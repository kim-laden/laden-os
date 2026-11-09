# laden-menu

The Laden OS application menu.

- `menu-spec.py` is the single source: categories, rules, hidden duplicates, Red Team tools, favourites.
- `gen.py` builds (at makepkg time) `laden.menu` (XDG merge file in `/etc/xdg/menus/applications-merged/`),
  `.directory` files, Laden category icons (dark tile, emerald frame), Red Team terminal launchers
  (`laden-rt-*.desktop`, shown only when the tool is installed, via `TryExec`), and the Plasma JS.
- The merge file hides Plasma's stock top-level folders (`<Deleted/>`) and puts the Laden ones in place:
  Laden, Gaming, Create, Stream, Media, Red Team, Internet, Office, Develop, System, Utilities,
  Learn & Science, Help, More. Nothing in other packages is edited; removing the package restores the stock menu.
- Launchers: Kickoff as the "Laden menu" (Laden L icon, favourites grid, category rail, 980x700, Meta),
  and Application Dashboard as "Laden Dashboard" (fullscreen, Meta+Shift+Space).
  Existing users: `laden-menu-apply` (backs up first; `laden-menu-apply --rollback` undoes it).
  New users: look-and-feel layout -> layout template `org.laden.desktop.defaultPanel`.
- Red Team launchers open WezTerm (fallback Konsole/kitty/xterm) with the tool's help and then a shell
  (`laden-rt-run`). "Red Team Shell" lists every installed tool.
