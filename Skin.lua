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

-- "Selva": modern dark-green panels with amber accents and tropical leaves.
-- Measured on the concept image scaled to 2000 px wide. The title, the three
-- filter fields, the search field, the close button and both buttons are
-- part of the art; the addon only puts text and click areas over them.
ns.Themes.selva = ns.ArtTheme({
  srcW = 2000, srcH = 1244, W = 960, rowH = 25,
  texture = "Interface\\AddOns\\BeastCodex\\Art\\Selva",
  texW = 1024, texH = 1024, imgW = 1024, imgH = 637,
  -- Rounded row boxes, hover, selection glow and tag pill; numbers match tools/make_rows.py.
  rowGap = 3,
  rowArt = {
    texture = "Interface\\AddOns\\BeastCodex\\Art\\SelvaRows",
    texW = 1024, texH = 256, slotH = 64, rowW = 800, rowH = 44, pillW = 96, pillH = 30,
  },
  scroll = { width = 5, track = { 0, 0, 0, 0.25 }, thumb = { 0.96, 0.66, 0.25, 0.75 } },
  search = { x = 1436, y = 119, w = 300, h = 38 },
  close = { x = 1832, y = 111, w = 50, h = 50 },
  filters = {
    { x = 164, y = 266, w = 310, h = 53, padRight = 22, label = { x = 164, y = 234 } },
    { x = 164, y = 376, w = 310, h = 53, padRight = 22, label = { x = 164, y = 344 } },
    { x = 164, y = 487, w = 310, h = 53, padRight = 22, label = { x = 164, y = 455 } },
  },
  check = { x = 166, y = 580, w = 30, h = 30, labelW = 250 },
  count = { x = 166, y = 1084, w = 310 },
  list = { x = 552, y = 226, w = 820, h = 892 },
  model = { x = 1458, y = 250, w = 380, h = 354 },
  name = { x = 1452, y = 640, w = 404 },
  text = { x = 1452, y = 704, w = 404 },
  mapButton = { x = 1447, y = 960, w = 404, h = 62, label = true, font = "GameFontNormal",
    textColor = { 0.13, 0.09, 0.02 }, dimColor = { 0.52, 0.36, 0.14 } },
  clearButton = { x = 1447, y = 1040, w = 404, h = 62, label = true, font = "GameFontNormal",
    textColor = { 0.96, 0.66, 0.25 } },
  colors = {
    menu = { 0.05, 0.09, 0.075, 0.98 }, menuBorder = { 0.96, 0.66, 0.25, 0.55 },
    text = { 0.92, 0.90, 0.82 }, header = { 0.96, 0.66, 0.25 }, dim = { 0.45, 0.52, 0.48 },
    title = { 0.96, 0.66, 0.25 }, tag = "e8a33d", tagText = { 1, 0.90, 0.78 },
    hover = { 1, 1, 1, 0.07 }, selected = { 0.96, 0.66, 0.25, 0.22 },
    checkBox = { 0.04, 0.07, 0.06, 1 }, -- the art has no checkbox, so draw its box
  },
})

function ns.ApplyTheme(name)
  if not ns.Themes[name] then name = "classic" end
  ns.themeName = name
  ns.Skin = ns.Themes[name]
  return name
end

ns.ApplyTheme("classic")
