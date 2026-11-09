-- Laden OS CockPit size and palette.
-- One pane, the size of a half desktop under the top bar (960 x 1024).
-- Return a function so the window can be sized when it opens.
return function(config, wezterm)
  config.initial_cols = 96
  config.initial_rows = 54
  if config.colors then
    config.colors.foreground = '#d7f6ea'
    config.colors.cursor_bg = '#00ff9d'
    config.colors.cursor_fg = '#030805'
    config.colors.cursor_border = '#00ff9d'
    config.colors.selection_fg = '#f4fff9'
    config.colors.selection_bg = '#145c3a'
    config.colors.ansi = {
      '#06140e', '#ff5c7a', '#00ff9d', '#e6d36a',
      '#6ec8ff', '#c9a6ff', '#3df0ff', '#d7f6ea',
    }
    config.colors.brights = {
      '#3d6a54', '#ff8aa0', '#5dffc0', '#f3e7a1',
      '#9bdcff', '#dcc6ff', '#8cfff0', '#ffffff',
    }
  end
  if not _G.LADEN_LCP_SIZED then
    _G.LADEN_LCP_SIZED = true
    wezterm.on('gui-startup', function(cmd)
      local _, _, window = wezterm.mux.spawn_window(cmd or {})
      local gui = window:gui_window()
      pcall(function() gui:restore() end)
      pcall(function() gui:set_inner_size(960, 1024) end)
    end)
  end
end
