-- SPDX-License-Identifier: MIT  (c) Laden AS - https://laden.no
-- Laden OS defaults for The CockPit (standalone LCP). Applied as local.lua so
-- an upgrade of The CockPit never overwrites them. Existing user files are not
-- replaced by the package (this file is only copied from /etc/skel for new users).
-- Hardware and host identity stay live; nothing here is hardcoded to one machine.
return function(config, wezterm)
  local ok, themed = pcall(function()
    return dofile("/usr/share/laden/terminal/cockpit/laden-theme.lua")(config)
  end)
  if ok and type(themed) == "table" then
    for k, v in pairs(themed) do
      config[k] = v
    end
  end
end
