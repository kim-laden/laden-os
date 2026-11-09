# Compatibility shim: older ~/.config/fish/config.fish snippets source this path.
# Real config: /usr/share/laden/fish/laden-config.fish (loads only once per shell).
if test -f /usr/share/laden/fish/laden-config.fish
    source /usr/share/laden/fish/laden-config.fish
end
