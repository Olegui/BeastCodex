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

-- The art themes share one layout, "three panels": filters on the left, the
-- list in the middle, the creature on the right. Measured on the art scaled
-- to 2000 px wide. The title, the three filter fields, the search field, the
-- close button and both buttons are part of the art; the addon only puts text
-- and click areas over them. A theme of this family differs only in `look`:
-- its art files and its colors.
local ART = "Interface\\AddOns\\BeastCodex\\Art\\"

local function panels(look)
  local a = look.accent
  return ns.ArtTheme({
    srcW = 2000, srcH = 1244, W = 960, rowH = 25,
    texture = ART .. look.art,
    texW = 1024, texH = 1024, imgW = 1024, imgH = 637,
    -- Rounded row boxes, hover, selection glow and tag pill; numbers match tools/make_rows.py.
    rowGap = 3,
    rowArt = {
      texture = ART .. look.art .. "Rows",
      texW = 1024, texH = 256, slotH = 64, rowW = 800, rowH = 44, pillW = 96, pillH = 30,
    },
    scroll = { width = 5, track = { 0, 0, 0, 0.25 }, thumb = { a[1], a[2], a[3], 0.75 } },
    search = { x = 1436, y = 119, w = 300, h = 38 },
    close = { x = 1832, y = 111, w = 50, h = 50 },
    filters = {
      { x = 164, y = 266, w = 310, h = 53, padRight = 22, label = { x = 164, y = 234 } },
      { x = 164, y = 376, w = 310, h = 53, padRight = 22, label = { x = 164, y = 344 } },
      { x = 164, y = 487, w = 310, h = 53, padRight = 22, label = { x = 164, y = 455 } },
    },
    check = { x = 166, y = 580, w = 30, h = 30, labelW = 250 },
    count = look.count or { x = 166, y = 1084, w = 310 },
    list = { x = 552, y = 226, w = 820, h = 892 },
    model = { x = 1458, y = 250, w = 380, h = 354 },
    name = { x = 1452, y = 640, w = 404 },
    text = { x = 1452, y = 704, w = 404 },
    mapButton = { x = 1447, y = 960, w = 404, h = 62, label = true, font = "GameFontNormal",
      textColor = look.onAccent, dimColor = look.onAccentDim },
    clearButton = { x = 1447, y = 1040, w = 404, h = 62, label = true, font = "GameFontNormal",
      textColor = a },
    colors = {
      menu = look.menu, menuBorder = { a[1], a[2], a[3], 0.55 },
      text = look.text, header = a, dim = look.dim, title = a,
      tag = look.tagHex, tagText = look.tagText,
      hover = { 1, 1, 1, 0.07 }, selected = { a[1], a[2], a[3], 0.22 },
      checkBox = look.well, -- the art has no checkbox, so draw its box
    },
  })
end

-- "Selva": modern dark-green panels with amber accents and tropical leaves.
ns.Themes.selva = panels({
  art = "Selva", accent = { 0.96, 0.66, 0.25 },
  onAccent = { 0.13, 0.09, 0.02 }, onAccentDim = { 0.52, 0.36, 0.14 },
  text = { 0.92, 0.90, 0.82 }, dim = { 0.45, 0.52, 0.48 },
  tagHex = "e8a33d", tagText = { 1, 0.90, 0.78 },
  menu = { 0.05, 0.09, 0.075, 0.98 }, well = { 0.04, 0.07, 0.06, 1 },
})

-- "Hunter": the same panels as a hunter's lodge: dark wood, stitched leather,
-- brass lines, feathers, arrows and antlers around the edges.
ns.Themes.hunter = panels({
  art = "Hunter", accent = { 0.86, 0.69, 0.38 },
  count = { x = 166, y = 640, w = 310 }, -- the bottom-left corner is covered by a fang and oak leaves
  onAccent = { 0.16, 0.10, 0.03 }, onAccentDim = { 0.44, 0.33, 0.16 },
  text = { 0.94, 0.88, 0.77 }, dim = { 0.74, 0.64, 0.54 },
  tagHex = "d9ad5c", tagText = { 1, 0.93, 0.80 },
  menu = { 0.13, 0.08, 0.05, 0.98 }, well = { 0.09, 0.05, 0.03, 1 },
})

function ns.ApplyTheme(name)
  if not ns.Themes[name] then name = "classic" end
  ns.themeName = name
  ns.Skin = ns.Themes[name]
  return name
end

ns.ApplyTheme("classic")
