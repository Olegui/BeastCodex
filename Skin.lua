local ADDON, ns = ...

-- A theme says where everything goes and what it looks like. The window code
-- (UI/*.lua) reads positions and colors from ns.Skin and nowhere else.
--
-- Rectangles are { x, y, w, h } in window units, measured from the window's
-- top-left corner, y growing downward.
ns.Themes = {}

-- Plain dark frame drawn with client textures. Needs no art file.
ns.Themes.classic = {
  W = 896, H = 560,
  backdrop = true,
  title = { x = 48, y = 28 },
  search = { x = 668, y = 26, w = 176, h = 22, label = true },
  close = { x = 852, y = 22, w = 24, h = 24, text = "X" },
  filters = {
    { x = 48, y = 88, w = 160, h = 24, label = { x = 48, y = 72 } },
    { x = 48, y = 138, w = 160, h = 24, label = { x = 48, y = 122 } },
    { x = 48, y = 188, w = 160, h = 24, label = { x = 48, y = 172 } },
  },
  check = { x = 48, y = 226, w = 16, h = 16, labelW = 136 },
  count = { x = 48, y = 496, w = 160 },
  list = { x = 220, y = 72, w = 386, h = 440 },
  rowH = 20,
  model = { x = 618, y = 72, w = 230, h = 170 },
  name = { x = 618, y = 250, w = 230 },
  text = { x = 618, y = 276, w = 230 },
  mapButton = { x = 618, y = 458, w = 230, h = 24, label = true },
  clearButton = { x = 618, y = 488, w = 230, h = 24, label = true },
  colors = {
    text = { 1, 1, 1 }, header = { 1, 0.82, 0 }, dim = { 0.5, 0.5, 0.5 },
    title = { 1, 0.82, 0 }, tag = "7fb2ff",
    hover = { 1, 1, 1, 0.12 }, selected = { 1, 0.82, 0, 0.18 },
    control = { 0.25, 0.18, 0.1, 0.9 }, -- fill behind buttons and fields; nil when the art has them
  },
}

-- Builds a theme from measurements taken on the source image, in its pixels.
-- `t.srcW` is the source image width the rectangles were measured on, `t.W`
-- the window width in game units; everything is scaled by W / srcW.
function ns.ArtTheme(t)
  local k = t.W / t.srcW
  local function scale(v)
    if type(v) ~= "table" then return v end
    local out = {}
    for key, val in pairs(v) do
      if type(val) == "number" and (key == "x" or key == "y" or key == "w" or key == "h" or key == "labelW") then
        out[key] = val * k
      else
        out[key] = scale(val)
      end
    end
    return out
  end
  local theme = {}
  for key, val in pairs(t) do
    theme[key] = (key == "colors" or key == "srcW" or key == "W") and val or scale(val)
  end
  theme.H = t.srcH * k
  theme.rowH = t.rowH -- row height is given in window units, not source pixels
  return theme
end

function ns.ApplyTheme(name)
  if not ns.Themes[name] then name = "classic" end
  ns.themeName = name
  ns.Skin = ns.Themes[name]
  return name
end

ns.ApplyTheme("classic")
