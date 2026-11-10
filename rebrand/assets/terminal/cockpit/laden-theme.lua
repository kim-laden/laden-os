-- SPDX-License-Identifier: MIT  (c) Laden AS - https://laden.no
-- LadenDark palette + spacing for the CockPit (LCP) WezTerm window.
-- Loaded at the end of ~/.config/cockpit/wezterm.lua:
--   pcall(function() dofile(wezterm.home_dir .. "/.config/cockpit/laden-theme.lua")(c) end)
-- Skipped when COCKPIT_SCHEME / COLOR_SCHEME picks another scheme. Font size is not touched.
return function(c)
  if (os.getenv("COCKPIT_SCHEME") or "") ~= "" then return c end
  local old = c.colors or {}
  c.colors = {
    foreground    = "#d7f6ea",   -- pearl
    background    = "#030805",
    cursor_bg     = "#5dffc0",
    cursor_fg     = "#030805",
    cursor_border = "#5dffc0",
    selection_fg  = "#f4fff9",
    selection_bg  = "#145c3a",
    scrollbar_thumb = "#0d2a1c",
    split         = old.split or "#39dc9a",
    compose_cursor = "#e6d36a",
    -- 16 ANSI colours: emerald green from LadenDark (57,220,154), the rest
    -- are distinct hues so output, paths, strings and errors stay readable.
    ansi = {
      "#0b1a14", -- black (lifted so it shows on the #030805 background)
      "#ff5c7a", -- red
      "#39dc9a", -- green  = LadenDark DecorationFocus
      "#e6d36a", -- yellow
      "#6ec8ff", -- blue
      "#c9a6ff", -- magenta
      "#3df0ff", -- cyan
      "#d7f6ea", -- white (pearl)
    },
    brights = {
      "#5a8f76", -- bright black (comments/hints, ~4.8:1 on background)
      "#ff8aa0",
      "#5dffc0", -- bright emerald
      "#f3e7a1",
      "#9bdcff",
      "#dcc6ff",
      "#8cfff0",
      "#ffffff",
    },
    tab_bar = old.tab_bar,
  }
  c.window_padding = { left = 16, right = 14, top = 12, bottom = 10 }
  c.line_height = 1.15
  c.cursor_thickness = 2
  return c
end
