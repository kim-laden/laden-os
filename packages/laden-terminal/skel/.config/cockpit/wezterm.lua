-- SPDX-License-Identifier: MIT  (c) Laden AS - https://laden.no
-- Laden OS default CockPit / LCP WezTerm config for new users.
-- Applies the system LadenDark theme from /usr/share/laden/terminal/.
local wezterm = require "wezterm"
local c = wezterm.config_builder and wezterm.config_builder() or {}
pcall(function()
  c = dofile("/usr/share/laden/terminal/cockpit/laden-theme.lua")(c)
end)
return c
