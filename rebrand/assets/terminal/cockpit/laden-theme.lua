-- SPDX-License-Identifier: MIT  (c) Laden AS - https://laden.no
-- LadenDark palette + spacing for the CockPit (LCP) WezTerm window.
-- Loaded from /usr/share/laden/terminal/cockpit/laden-theme.lua (system default)
-- or ~/.config/cockpit/laden-theme.lua (per-user copy).
-- Colours are skipped when COCKPIT_SCHEME / COLOR_SCHEME picks another scheme.
-- Font: CockPit's FONT_SIZE (cockpit.conf -> COCKPIT_FONT_SIZE) wins; without it the
-- default is 14.5 pt (= 12 pt + two Ctrl+= steps, 12 x 1.1 x 1.1, rounded to 0.5).
-- The rocket/circuit backdrop is the default Laden OS wallpaper showing through
-- window_background_opacity; it is not a terminal background image, and it is
-- detected live per machine (the wallpaper ships in laden-branding).
return function(c)
  local wezterm = require "wezterm"
  if not tonumber(os.getenv("COCKPIT_FONT_SIZE") or "") then c.font_size = 14.5 end
  -- initial_cols/rows (96x54) were sized for 12 pt; scale them so a bigger font
  -- keeps about the same window size in pixels instead of growing off-screen.
  local k = 12 / (c.font_size or 12)
  if k < 1 then
    c.initial_cols = math.floor((c.initial_cols or 96) * k + 0.5)
    c.initial_rows = math.floor((c.initial_rows or 54) * k + 0.5)
  end

  -- JetBrains Mono ships on Laden OS; Nerd Font fallbacks draw the fetch icons.
  -- WezTerm also has built-in Symbols Nerd Font glyphs when a Nerd Font is missing.
  pcall(function()
    c.font = wezterm.font_with_fallback({
      { family = "JetBrains Mono", weight = "Medium" },
      "MesloLGS Nerd Font",
      "MesloLGM Nerd Font",
      "Symbols Nerd Font Mono",
      "Symbols Nerd Font",
      "monospace",
    })
  end)
  c.harfbuzz_features = c.harfbuzz_features or { "calt=1", "clig=1", "liga=1" }
  c.line_height = 1.15
  c.cursor_thickness = 2
  c.window_padding = { left = 16, right = 14, top = 12, bottom = 10 }
  -- 0.86 lets the Laden OS (rocket/circuit) wallpaper show through, as in the
  -- default LCP look. Not hardcoded to any host.
  c.window_background_opacity = 0.86
  c.window_background_gradient = nil
  c.window_decorations = "RESIZE"
  if c.enable_tab_bar == nil then c.enable_tab_bar = false end
  c.window_frame = {
    border_left_width = 2,
    border_right_width = 2,
    border_top_height = 2,
    border_bottom_height = 2,
    border_left_color = "#145c3a",
    border_right_color = "#145c3a",
    border_top_color = "#145c3a",
    border_bottom_color = "#145c3a",
  }
  if not c.default_prog then
    c.default_prog = { "/usr/bin/fish", "-l" }
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
  return c
end
