# SPDX-License-Identifier: MIT  (c) Laden AS - https://laden.no
# Laden OS prompt (LCP / CockPit / WezTerm). Two lines, emerald accents:
#   ╭─ lz  󰝰 ~/Projects/LadenOS  󰘬 main ●  ✘ 1  󱦟 3.2s
#   ╰─❯
# Exit status only when non-zero, duration only when >= 2 s, ROOT badge for root,
# host shown only over SSH. Other terminals (e.g. Alacritty) keep their stock prompt.
function fish_prompt
    set -l last_status $status
    set -l last_pipestatus $pipestatus

    if not set -q WEZTERM_PANE; and not set -q LADEN_PROMPT
        if functions -q __cachyos_prompt
            __cachyos_prompt
            return
        end
        set_color cyan; echo -n (prompt_pwd); set_color normal; echo -n ' > '
        return
    end

    set -l frame '#2a7a58'
    set -l emerald '#39dc9a'
    set -l bright '#5dffc0'
    set -l path '#9bdcff'
    set -l dim '#6d9a86'
    set -l warn '#e6d36a'
    set -l bad '#ff5c7a'

    # One blank line between commands, but not above the very first prompt.
    if set -q __laden_prompt_drawn
        echo
    end
    set -g __laden_prompt_drawn 1

    # Line 1
    set_color $frame; echo -n '╭─ '
    if fish_is_root_user
        set_color --bold --background $bad 030805; echo -n ' ROOT '
        set_color normal; echo -n ' '
    end
    set_color --bold $bright; echo -n 'lz'
    set_color normal
    if set -q SSH_CONNECTION
        set_color $dim; echo -n '@'
        set_color $warn; echo -n (prompt_hostname)
    end

    set -l cwd (prompt_pwd --dir-length 0 2>/dev/null)
    set -l max (math "max(16, $COLUMNS - 40)")
    if test (string length -- $cwd) -gt $max
        set cwd (prompt_pwd --dir-length 1 --full-length-dirs 2)
    end
    set_color $emerald; echo -n '  󰝰 '
    set_color $path; echo -n $cwd

    if command -sq git
        set -g __fish_git_prompt_showdirtystate 1
        set -g __fish_git_prompt_showuntrackedfiles 1
        set -g __fish_git_prompt_char_dirtystate '●'
        set -g __fish_git_prompt_char_stagedstate '+'
        set -g __fish_git_prompt_char_untrackedfiles '?'
        set -g __fish_git_prompt_char_stateseparator ' '
        set -g __fish_git_prompt_color_branch $emerald
        set -g __fish_git_prompt_color_dirtystate $warn
        set -g __fish_git_prompt_color_stagedstate $bright
        set -g __fish_git_prompt_color_untrackedfiles $dim
        set -l git (fish_git_prompt '%s')
        if test -n "$git"
            set_color $emerald; echo -n '  󰘬 '
            echo -n $git
        end
    end

    if test $last_status -ne 0
        set -l shown $last_status
        if test (count $last_pipestatus) -gt 1
            set shown (string join '|' $last_pipestatus)
        end
        set_color --bold $bad; echo -n "  ✘ $shown"
        set_color normal
    end

    if test -n "$CMD_DURATION"; and test $CMD_DURATION -ge 2000
        set -l secs (math --scale=1 "$CMD_DURATION / 1000")
        set -l txt "$secs"s
        if test $CMD_DURATION -ge 60000
            set txt (math --scale=0 "floor($CMD_DURATION / 60000)")m(math --scale=0 "floor($CMD_DURATION / 1000) % 60")s
        end
        set_color $warn; echo -n "  󱦟 $txt"
    end
    echo

    # Line 2
    set_color $frame; echo -n '╰─'
    if fish_is_root_user
        set_color --bold $bad; echo -n '# '
    else
        set_color --bold $bright; echo -n '❯ '
    end
    set_color normal
end
