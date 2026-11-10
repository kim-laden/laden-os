# SPDX-License-Identifier: MIT  (c) Laden AS - https://laden.no
# Prefer Laden OS LCP fish functions over other vendor prompts for interactive shells.
if status is-interactive
    set -l laden_fn /usr/share/laden/fish/functions
    if test -d $laden_fn
        set -g fish_function_path $laden_fn $fish_function_path
    end
end
