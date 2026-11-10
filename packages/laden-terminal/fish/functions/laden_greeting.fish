# SPDX-License-Identifier: MIT  (c) Laden AS - https://laden.no
# Laden OS terminal greeting: fastfetch sized to the pane, plus one short Laden line.
#   >= 78 columns : logo beside the info (default ~/.config/fastfetch/config.jsonc)
#   56-77 columns : logo on top
#   40-55 columns : info only
#   <  40 columns : the Laden line only
# Opt out for one shell with:  set -gx LADEN_QUIET 1
function laden_greeting --description 'Laden OS greeting: responsive fastfetch + one line'
    set -q LADEN_QUIET; and return
    set -l cols $COLUMNS
    test -n "$cols"; or set cols (tput cols 2>/dev/null); or set cols 80

    if type -q fastfetch; and test $cols -ge 40
        if test $cols -ge 78
            fastfetch
        else if test $cols -ge 56
            fastfetch --logo-position top
        else
            fastfetch --logo none
        end
    end

    set -l lines \
        'Ready when you are.' \
        'Build something good today.' \
        'Small steps, shipped often.' \
        'Your machine, your rules.' \
        'Break it in a lab, fix it for real.' \
        'Stay curious. Stay legal.' \
        'Make it, then make it better.'
    set -l line $lines[(random 1 (count $lines))]
    echo
    set_color '#145c3a'; echo -n '  ▌ '
    set_color --bold '#5dffc0'; echo -n 'laden'
    set_color normal; set_color '#6d9a86'; echo -n '  ·  '
    set_color '#d7f6ea'; echo $line
    set_color normal
end
