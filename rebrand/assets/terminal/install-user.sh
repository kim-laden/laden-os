#!/usr/bin/env bash
# SPDX-License-Identifier: MIT  (c) Laden AS - https://laden.no
# Install the Laden OS LCP/CockPit terminal look for the CURRENT user only.
# Backs up every file it replaces or adds to ~/.config/laden/backups/lcp-terminal-<ts>/
# and writes restore.sh there. Nothing is deleted; restore moves new files into the backup.
set -euo pipefail
src="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cfg="${XDG_CONFIG_HOME:-$HOME/.config}"
ts="$(date +%Y%m%d-%H%M%S)"
bk="$cfg/laden/backups/lcp-terminal-$ts"
mkdir -p "$bk/orig" "$bk/added-by-install"

# src-relative-path  ->  target under $cfg
map=(
  "fastfetch/config.jsonc|fastfetch/config.jsonc"
  "fish/functions/fish_prompt.fish|fish/functions/fish_prompt.fish"
  "fish/functions/fish_greeting.fish|fish/functions/fish_greeting.fish"
  "fish/functions/laden_greeting.fish|fish/functions/laden_greeting.fish"
  "fish/conf.d/00-laden-config.fish|fish/conf.d/00-laden-config.fish"
  "cockpit/laden-theme.lua|cockpit/laden-theme.lua"
)
restore="$bk/restore.sh"
{
  echo '#!/usr/bin/env bash'
  echo "# Restore the terminal setup from before $ts (moves added files into $bk/added-by-install)."
  echo 'set -u'
} > "$restore"

for m in "${map[@]}"; do
  rel="${m%%|*}"; dst="$cfg/${m##*|}"
  mkdir -p "$(dirname "$dst")"
  if [ -e "$dst" ]; then
    mkdir -p "$bk/orig/$(dirname "${m##*|}")"
    cp -a "$dst" "$bk/orig/${m##*|}"
    echo "cp -a '$bk/orig/${m##*|}' '$dst'" >> "$restore"
  else
    echo "mkdir -p '$bk/added-by-install/$(dirname "${m##*|}")' && mv -f '$dst' '$bk/added-by-install/${m##*|}'" >> "$restore"
  fi
  install -m0644 "$src/$rel" "$dst"
  echo "installed $dst"
done

# Hook laden-theme.lua into the CockPit WezTerm config (once), just before `return c`.
cw="$cfg/cockpit/wezterm.lua"
if [ -f "$cw" ] && ! grep -q 'laden-theme.lua' "$cw"; then
  mkdir -p "$bk/orig/cockpit"
  cp -a "$cw" "$bk/orig/cockpit/wezterm.lua"
  echo "cp -a '$bk/orig/cockpit/wezterm.lua' '$cw'" >> "$restore"
  python3 - "$cw" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
hook = ('-- Laden OS terminal look (rebrand/assets/terminal); remove this line to opt out.\n'
        'pcall(function() c = dofile(wezterm.home_dir .. "/.config/cockpit/laden-theme.lua")(c) end)\n')
i = s.rstrip().rfind("return c")
if i < 0:
    s = s.rstrip() + "\n" + hook
else:
    s = s[:i] + hook + s[i:]
open(p, "w", encoding="utf-8").write(s)
PY
  echo "hooked laden-theme.lua into $cw"
fi
chmod +x "$restore"
echo
echo "Backup : $bk"
echo "Restore: bash '$restore'"
