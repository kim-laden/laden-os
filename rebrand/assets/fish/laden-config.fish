# Laden OS fish config — replaces cachyos-fish-config sourcing
# Installed to /usr/share/laden-os/fish/laden-config.fish

# Colors
if test -f /usr/share/laden-os/fish/laden-colors.fish
    source /usr/share/laden-os/fish/laden-colors.fish
else if test -f /etc/fish/conf.d/laden-colors.fish
    source /etc/fish/conf.d/laden-colors.fish
end

# Sensible defaults
set -gx EDITOR micro
set -gx VISUAL $EDITOR
set -gx BROWSER chromium
set -gx TERMINAL lcp

# Aliases (Laden-branded; keep useful tools from the old Cachy fish config)
if type -q eza
    alias ls 'eza -1 --icons=auto'
    alias ll 'eza -l --icons=auto --git'
    alias la 'eza -la --icons=auto --git'
    alias lt 'eza --tree --level=2 --icons=auto'
end
if type -q bat
    alias cat 'bat --paging=never'
end
alias update 'sudo pacman -Syu'
alias mirror 'sudo cachyos-rate-mirrors'

# Fastfetch on interactive login shells (optional, quiet on failure)
if status is-interactive; and type -q fastfetch
    if test -f /usr/share/laden-os/fastfetch/config.jsonc
        fastfetch --config /usr/share/laden-os/fastfetch/config.jsonc
    end
end
