local ADDON, ns = ...

-- A theme says where everything goes and what it looks like. The window code
-- (UI/*.lua) reads positions and colors from ns.Skin and nowhere else.
--
-- Rectangles are { x, y, w, h } in window units, measured from the window's
-- top-left corner, y growing downward.
ns.Themes = {}

-- The game's own look: the window, panels, buttons, checkboxes, search box,
-- drop-downs and menus are the client's templates (`blizzard = true`), the
-- same ones the default interface uses. Needs no art file. Where the client
-- lacks a template, the control falls back to a plain one (see UI.Make).
ns.Themes.classic = {
  label = "Classic",
  blizzard = true,
  W = 900, H = 584,
  -- Sunken panels behind the three columns (InsetFrameTemplate).
  insets = {
    { x = 10, y = 60, w = 212, h = 488 },
    { x = 226, y = 60, w = 424, h = 488 },
    { x = 654, y = 60, w = 238, h = 488 },
  },
  search = { x = 676, y = 32, w = 206, h = 20 },
  searchClear = { x = 0, y = 0, w = 1, h = 1 }, -- the search box template has its own
  close = { x = 0, y = 0, w = 1, h = 1 },       -- the window template has its own
  filters = {
    { x = 20, y = 92, w = 192, h = 26, label = { x = 22, y = 74 } },
    { x = 20, y = 146, w = 192, h = 26, label = { x = 22, y = 128 } },
    { x = 20, y = 200, w = 192, h = 26, label = { x = 22, y = 182 } },
  },
  check = { x = 18, y = 238, w = 26, h = 26, labelW = 160 },
  check2 = { x = 18, y = 266, w = 26, h = 26, labelW = 160 },
  resetButton = { x = 22, y = 304, w = 188, h = 22 },
  themeButton = { x = 474, y = 29, w = 190, h = 26 },
  count = { x = 22, y = 522, w = 188 },
  credits = { x = 10, y = 558, w = 880 },
  -- Inside the middle inset (226..650): 26 units each side; the right one holds the scroll bar, 4 in.
  list = { x = 252, y = 68, w = 394, h = 472 },
  rowH = 20,
  model = { x = 662, y = 68, w = 222, h = 196 },
  name = { x = 664, y = 274, w = 218 },
  text = { x = 664, y = 300, w = 218, h = 150 }, -- ends above the target button
  targetButton = { x = 664, y = 458, w = 218, h = 22, label = true },
  mapButton = { x = 664, y = 486, w = 218, h = 22, label = true },
  clearButton = { x = 664, y = 514, w = 218, h = 22, label = true },
  colors = {
    text = { 1, 1, 1 }, header = { 1, 0.82, 0 }, dim = { 0.5, 0.5, 0.5 },
    title = { 1, 0.82, 0 }, tag = "7fb2ff",
    hover = { 1, 1, 1, 0.10 }, selected = { 1, 0.82, 0, 0.20 },
    -- Used only where a template is missing: fill behind fields and buttons.
    control = { 0.12, 0.12, 0.12, 0.95 },
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
      texW = 1024, texH = 512, slotH = 64, rowW = 800, rowH = 44, pillW = 96, pillH = 30,
      -- Controls the addon draws itself, as { x, y, w, h } in the atlas.
      offPad = 2.9, -- window units the grey face reaches beyond the button, to cover its rim
      faces = {
        off = { 128, 192, 338, 60 },     -- grey face over the map button, rim included
        outline = { 528, 192, 390, 60 }, -- "clear pins" button
        field = { 0, 256, 362, 56 },     -- drop-down field with its arrow, cut from the search field
        box = { 368, 256, 48, 48 },      -- checkbox, cut from the round close button
        tick = { 432, 256, 48, 48 },     -- its tick
        clearSearch = { 496, 256, 54, 42 }, -- the search field's magnifier spot with an X
        pillGrey = { 920, 192, 96, 30 },  -- tag for plain rares
        pillSpawn = { 560, 256, 96, 30 }, -- tag for spawned creatures
        red = { 672, 256, 338, 60 },     -- the main button in red, rim included (like `off`)
        card = { 0, 320, 48, 48 },       -- rounded box, drawn as nine slices (UI.Slice)
        cardHover = { 56, 320, 48, 48 }, -- its hovered look
        panel = { 112, 320, 48, 48 },    -- nearly opaque box for the target window
        disc = { 168, 320, 48, 48 },     -- white disc: the red glow of round close buttons
        cardFeatured = { 224, 320, 48, 48 }, -- news card: accent rim and glow, like a selected row
        pillGlow = { 280, 320, 96, 40 },  -- white pill: hover of pill-shaped buttons painted in the art
      },
    },
    label = look.label,
    credits = { x = 500, y = 1143, w = 1000 }, -- on the frame below the panels, clear of the corner decorations
    -- Same height and look as the search field it sits beside.
    themeButton = { x = 1030, y = 108, w = 368, h = 57, face = "field", pill = true, capR = 46, padRight = 24 },
    scroll = { width = 5, track = { 0, 0, 0, 0.25 }, thumb = { a[1], a[2], a[3], 0.75 } },
    search = { x = 1436, y = 119, w = 300, h = 38, padRight = 8 },
    -- Over the magnifier painted in the field: a piece of the field with an X instead.
    searchClear = { x = 1740, y = 116, w = 54, h = 42, face = "clearSearch" },
    close = { x = 1832, y = 111, w = 50, h = 50, glow = "red" },
    -- The painted fields have small corners; the field piece laid over them, a
    -- little larger (facePad) so it covers them, makes them pills like the
    -- search field. capR: atlas px of its right end, the arrow included.
    filters = {
      { x = 164, y = 266, w = 310, h = 53, padRight = 22, label = { x = 164, y = 234 }, face = "field", pill = true, capR = 46, facePad = 4 },
      { x = 164, y = 376, w = 310, h = 53, padRight = 22, label = { x = 164, y = 344 }, face = "field", pill = true, capR = 46, facePad = 4 },
      { x = 164, y = 487, w = 310, h = 53, padRight = 22, label = { x = 164, y = 455 }, face = "field", pill = true, capR = 46, facePad = 4 },
    },
    check = { x = 166, y = 578, w = 34, h = 34, labelW = 262 },
    check2 = { x = 166, y = 628, w = 34, h = 34, labelW = 262 },
    -- The main button's look, in red; its face reaches past the rect to cover the rim.
    resetButton = { x = 164, y = 690, w = 310, h = 50, face = "red", facePad = 2.9, labelY = 2, font = "GameFontNormal",
      textColor = { 1, 0.91, 0.84 } },
    count = look.count or { x = 166, y = 1084, w = 310 },
    -- The panel's stitching runs at x 545.5 and 1372.5. Rows keep 15 units (31 here)
    -- from it on both sides; on the right that holds the scroll bar, 4 units in.
    list = { x = 577, y = 226, w = 787, h = 892 },
    model = { x = 1458, y = 250, w = 380, h = 354 },
    name = { x = 1452, y = 640, w = 404 },
    text = { x = 1452, y = 704, w = 404, h = 168 }, -- ends above the target button
    -- Not in the art: opens the target window. Same look as "clear pins".
    targetButton = { x = 1447, y = 884, w = 404, h = 56, label = true, font = "GameFontNormal",
      textColor = a, face = "outline" },
    mapButton = { x = 1447, y = 960, w = 404, h = 62, label = true, font = "GameFontNormal",
      textColor = look.onAccent, dimColor = { 0.82, 0.80, 0.76 }, offFace = "off" },
    -- Not in the art: the addon draws it, and only while there are pins to clear.
    clearButton = { x = 1447, y = 1040, w = 404, h = 62, label = true, font = "GameFontNormal",
      textColor = a, face = "outline" },
    colors = {
      menu = look.menu, menuBorder = { a[1], a[2], a[3], 0.55 },
      text = look.text, header = a, dim = look.dim, title = a,
      tag = look.tagHex, tagText = look.tagText,
      hover = { 1, 1, 1, 0.07 }, selected = { a[1], a[2], a[3], 0.22 },
    },
  })
end

-- "Jungle" (internal name "selva", kept so saved settings still match): modern dark-green panels with amber accents and tropical leaves.
ns.Themes.selva = panels({
  art = "Selva", label = "Jungle", accent = { 0.96, 0.66, 0.25 },
  onAccent = { 0.13, 0.09, 0.02 },
  text = { 0.92, 0.90, 0.82 }, dim = { 0.45, 0.52, 0.48 },
  tagHex = "e8a33d", tagText = { 1, 0.90, 0.78 },
  menu = { 0.05, 0.09, 0.075, 0.98 },
})

-- "Hunter": the same panels as a hunter's lodge: dark wood, stitched leather,
-- brass lines, feathers, arrows and antlers around the edges.
ns.Themes.hunter = panels({
  art = "Hunter", label = "Hunter", accent = { 0.86, 0.69, 0.38 },
  count = { x = 166, y = 758, w = 310 }, -- the bottom-left corner is covered by a fang and oak leaves
  onAccent = { 0.16, 0.10, 0.03 },
  text = { 0.94, 0.88, 0.77 }, dim = { 0.74, 0.64, 0.54 },
  tagHex = "d9ad5c", tagText = { 1, 0.93, 0.80 },
  menu = { 0.13, 0.08, 0.05, 0.98 },
})

-- The target window's own art (art-src/HunterTarget.png, cut small by
-- tools/splice_target.py, then tools/make_skin.py --width 512). Rectangles as
-- { x, y, w, h } in the source's 2000-px-wide units after the cuts (`srcW` wide);
-- UI/Target.lua scales them to `W` units.
ns.Themes.hunter.targetArt = {
  texture = ART .. "HunterTarget", texW = 512, texH = 512, imgW = 512, imgH = 333,
  srcW = 1290, W = 194, -- same scale as before the cuts: 0.15 units per source unit
  close = { 1025, 125, 130, 130 },  -- the painted round X
  title = { 260, 262, 770 },        -- the leather's width, centered on the window
  info = { 260, 350, 770 },
  button = { 350, 435, 590, 135 },  -- the painted gold button
  textColor = { 0.16, 0.10, 0.03 }, -- dark label on the gold face
}

ns.DEFAULT_THEME = "hunter"

function ns.ApplyTheme(name)
  if not ns.Themes[name] then name = ns.DEFAULT_THEME end
  ns.themeName = name
  ns.Skin = ns.Themes[name]
  return name
end

ns.ApplyTheme(ns.DEFAULT_THEME)
