# SPDX-License-Identifier: MIT  (c) Laden AS - https://laden.no
# Per-user shadow of /etc/fish/conf.d/00-laden-config.fish (same file name, so fish
# runs this one instead). It loads the same system Laden config but stops it from
# printing fastfetch itself; fish_greeting -> laden_greeting prints it, sized to the pane.
if test -f /usr/share/laden/fish/laden-config.fish
    if status is-interactive
        function fastfetch --description 'muted while the system Laden config loads'
        end
        source /usr/share/laden/fish/laden-config.fish
        functions --erase fastfetch
    else
        source /usr/share/laden/fish/laden-config.fish
    end
end
