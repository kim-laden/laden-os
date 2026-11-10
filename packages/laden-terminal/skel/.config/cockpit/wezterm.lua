-- SPDX-License-Identifier: MIT  (c) Laden AS - https://laden.no
-- Laden OS default WezTerm / LCP config for new users.
-- Applies the system LadenDark theme (opacity, emerald border, fonts, palette).
-- A user can replace this file; package updates will not overwrite an existing copy.
local wezterm = require "wezterm"
local c = wezterm.config_builder and wezterm.config_builder() or {}
pcall(function()
  c = dofile("/usr/share/laden/terminal/cockpit/laden-theme.lua")(c)
end)
return c
