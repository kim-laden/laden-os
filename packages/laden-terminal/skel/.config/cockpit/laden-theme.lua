-- SPDX-License-Identifier: MIT  (c) Laden AS - https://laden.no
-- LadenDark palette + spacing for the CockPit (LCP) WezTerm window.
-- Loaded at the end of ~/.config/cockpit/wezterm.lua:
--   pcall(function() dofile(wezterm.home_dir .. "/.config/cockpit/laden-theme.lua")(c) end)
-- Colours are skipped when COCKPIT_SCHEME / COLOR_SCHEME picks another scheme.
-- Font: CockPit's FONT_SIZE (cockpit.conf -> COCKPIT_FONT_SIZE) wins; without it the
-- default is 14.5 pt (= 12 pt + two Ctrl+= steps, 12 x 1.1 x 1.1, rounded to 0.5).
return function(c)
  if not tonumber(os.getenv("COCKPIT_FONT_SIZE") or "") then c.font_size = 14.5 end
  -- initial_cols/rows (96x54) were sized for 12 pt; scale them so a bigger font
  -- keeps about the same window size in pixels instead of growing off-screen.
  local k = 12 / (c.font_size or 12)
  if k < 1 then
    c.initial_cols = math.floor((c.initial_cols or 96) * k + 0.5)
    c.initial_rows = math.floor((c.initial_rows or 54) * k + 0.5)
  end
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
