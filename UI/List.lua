local ADDON, ns = ...
local L = ns.L

-- Virtual list: a fixed set of row frames is reused over any number of rows.
local List = { rows = {}, frames = {}, offset = 0 }
ns.List = List

-- Filled by UI/Detail.lua; called only when set.
List.onEnter, List.onLeave, List.onClick = nil, nil, nil

local zoneCache = {}

-- The game's own (localized) name: of the map when it is known, else of the
-- area (dungeons, raids and zones without a world map). English as a last resort.
function ns.ZoneLabel(c)
  if c.map then
    local name = zoneCache[c.map]
    if name == nil then
      local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(c.map)
      name = info and info.name or false
      zoneCache[c.map] = name
    end
    if name then return name end
  end
  if c.area then
    local key = -c.area -- same cache as maps; negative keeps the two ID spaces apart
    local name = zoneCache[key]
    if name == nil then
      name = C_Map and C_Map.GetAreaInfo and C_Map.GetAreaInfo(c.area) or false
      if name == "" then name = false end
      zoneCache[key] = name
    end
    if name then return name end
  end
  return c.zone or ""
end

function ns.LevelText(c)
  if not c.min then return L.LEVEL_UNKNOWN end
  return c.min == c.max and tostring(c.min) or (c.min .. "-" .. c.max)
end

-- Width left for the name once the tag has taken what it needs: the name is
-- what gets cut short, never the tag.
function List.NameWidth(available, nameWidth, tagWidth, gap)
  if tagWidth <= 0 then return math.min(nameWidth, available) end
  return math.max(0, math.min(nameWidth, available - tagWidth - gap))
end

local TAG_GAP, PILL_PAD = 6, 5
local TAG_PIECE = { grey = "pillGrey", spawn = "pillSpawn" }                    -- atlas pieces
local TAG_TEXT = { grey = { 0.84, 0.84, 0.84 }, spawn = { 0.88, 0.80, 1.00 } }  -- text on them

local function paint(row, data)
  row.data = data
  if not data then row:Hide() return end
  row:Show()
  local c = data.creature
  local col = ns.Skin.colors
  row.icon:Hide()
  row.selected:Hide()
  row.tag:SetText("")
  if row.pill then row.pill:Hide() end
  for _, p in pairs(row.pills) do p:Hide() end
  if not c then
    row:EnableMouse(false)
    if row.bg then row.bg:Hide() end
    row.name:SetWidth(row.headerW)
    row.name:SetText(data.header)
    row.name:SetTextColor(col.header[1], col.header[2], col.header[3])
    row.name:SetPoint("LEFT", 4, 0)
    row.level:SetText("")
    row.zone:SetText("")
    return
  end
  row:EnableMouse(true)
  if row.bg then
    row.bg:Show()
    row.bg:SetAlpha(c.tame and 1 or 0.45)
  end
  row.name:SetPoint("LEFT", row.indent, 0)
  row.name:SetWidth(0) -- natural width, so it can be measured
  row.name:SetText(ns.LocalName(c))
  local cls = ns.ClsLabel(c.cls)
  local tagW = 0
  if cls then
    row.tag:SetText(cls)
    -- Each kind of tag has its own colors; elite uses the theme's accent.
    local style = List.TagStyle(c.cls)
    local tc = style and TAG_TEXT[style] or row.tagColor
    row.tag:SetTextColor(tc[1], tc[2], tc[3])
    tagW = row.tag:GetStringWidth() + (row.pill and 2 * PILL_PAD or 0)
    local pill = style and row.pills[style] or row.pill
    if pill then
      pill:SetWidth(tagW)
      pill:Show()
      -- The text sits on the pill actually shown: a hidden pill that was
      -- never sized has no position, and text anchored to it is not drawn.
      row.tag:ClearAllPoints()
      row.tag:SetPoint("LEFT", pill, "LEFT", PILL_PAD, 0)
    end
  end
  row.name:SetWidth(List.NameWidth(row.nameMax, row.name:GetStringWidth(), tagW, TAG_GAP))
  row.level:SetText(ns.LevelText(c))
  row.zone:SetText(ns.ZoneLabel(c))
  local r, g, b = col.text[1], col.text[2], col.text[3]
  if not c.tame then
    r, g, b = col.dim[1], col.dim[2], col.dim[3]
    row.icon:Show()
  end
  row.name:SetTextColor(r, g, b)
  row.level:SetTextColor(r, g, b)
  row.zone:SetTextColor(r, g, b)
  if List.selectedId == c.id then row.selected:Show() end
end

function List:Update()
  local visible = self.visible or #self.frames
  local maxOffset = math.max(0, #self.rows - visible)
  self.offset = math.min(math.max(0, self.offset), maxOffset)
  for i, row in ipairs(self.frames) do
    paint(row, i <= visible and self.rows[i + self.offset] or nil)
  end
  self.empty:SetShown(#self.rows == 0)
  self.bar:SetMinMaxValues(0, maxOffset)
  self.bar:SetValue(self.offset)
  self.bar:SetShown(maxOffset > 0)
end

function List:SetRows(rows)
  self.rows = rows
  self.offset = 0
  self:Update()
end

function List:SetSelected(c)
  self.selectedId = c and c.id or nil
  self:Update()
end

-- A texture showing one slot of the theme's row atlas (see tools/make_rows.py).
local function slot(parent, layer, art, index, w, h)
  local t = parent:CreateTexture(nil, layer)
  t:SetTexture(art.texture)
  local top = index * art.slotH
  t:SetTexCoord(0, w / art.texW, top / art.texH, (top + h) / art.texH)
  return t
end

local function newRow(parent, width, height)
  local S = ns.Skin
  local col, art = S.colors, S.rowArt
  local row = CreateFrame("Button", nil, parent)
  row:SetSize(width, height)
  row.bg, row.pill, row.pills = false, false, {} -- only themes with row art have them

  local hl
  if art then
    row.bg = slot(row, "BACKGROUND", art, 0, art.rowW, art.rowH)
    row.bg:SetAllPoints()
    hl = slot(row, "HIGHLIGHT", art, 1, art.rowW, art.rowH)
    row.selected = slot(row, "BORDER", art, 2, art.rowW, art.rowH)
  else
    hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetColorTexture(col.hover[1], col.hover[2], col.hover[3], col.hover[4])
    row.selected = row:CreateTexture(nil, "BACKGROUND")
    row.selected:SetColorTexture(col.selected[1], col.selected[2], col.selected[3], col.selected[4])
  end
  hl:SetAllPoints()
  row.selected:SetAllPoints()

  row.icon = row:CreateTexture(nil, "ARTWORK")
  row.icon:SetSize(14, 14)
  row.icon:SetPoint("LEFT", 4, 0)
  row.icon:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")

  -- Column split; a theme with a narrow list gives the name more room.
  local cols = S.cols or {}
  local zoneW, levelW = math.floor(width * (cols.zone or 0.36)), cols.level or 44
  row.indent = cols.indent or 22
  row.zone = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  row.zone:SetPoint("RIGHT", -6, 0)
  row.zone:SetWidth(zoneW)
  row.zone:SetJustifyH("LEFT")
  row.zone:SetWordWrap(false)

  row.level = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  row.level:SetPoint("RIGHT", row.zone, "LEFT", -6, 0)
  row.level:SetWidth(levelW)
  row.level:SetJustifyH("LEFT")

  -- Name and tag share what is left of the row; see List.NameWidth.
  row.nameMax = width - row.indent - zoneW - levelW - 18
  row.headerW = width - 8 -- a header has the whole row to itself
  row.name = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  row.name:SetPoint("LEFT", row.indent, 0)
  row.name:SetJustifyH("LEFT")
  row.name:SetWordWrap(false)

  row.tag = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  local tag = col.tagText or { tonumber(col.tag:sub(1, 2), 16) / 255, tonumber(col.tag:sub(3, 4), 16) / 255,
    tonumber(col.tag:sub(5, 6), 16) / 255 }
  row.tag:SetTextColor(tag[1], tag[2], tag[3])
  row.tagColor = tag
  if art then
    row.pill = slot(row, "ARTWORK", art, 3, art.pillW, art.pillH)
    row.pill:SetHeight(height - 6)
    row.pill:SetPoint("LEFT", row.name, "RIGHT", TAG_GAP, 0)
    for style, piece in pairs(TAG_PIECE) do
      local p = ns.UI.Atlas(row, "ARTWORK", piece)
      if p then
        p:SetHeight(height - 6)
        p:SetPoint("LEFT", row.name, "RIGHT", TAG_GAP, 0)
        row.pills[style] = p
      end
    end
    row.tag:SetPoint("LEFT", row.pill, "LEFT", PILL_PAD, 0)
  else
    row.tag:SetPoint("LEFT", row.name, "RIGHT", TAG_GAP, 0)
  end

  for _, fs in ipairs({ row.zone, row.level, row.name, row.tag }) do ns.UI.Flat(fs) end

  row:SetScript("OnEnter", function(self)
    if self.data and self.data.creature and List.onEnter then List.onEnter(self.data.creature) end
  end)
  row:SetScript("OnLeave", function()
    if List.onLeave then List.onLeave() end
  end)
  row:SetScript("OnClick", function(self)
    if self.data and self.data.creature and List.onClick then List.onClick(self.data.creature) end
  end)
  return row
end

-- Builds the list inside `parent`, in the theme rectangle `r`.
function List:Create(parent, r)
  local S = ns.Skin
  local rowH, gap = S.rowH, S.rowGap or 0
  local width, height = r.w, r.h
  self.frames, self.rows, self.offset = {}, {}, 0
  local holder = CreateFrame("Frame", nil, parent) -- placed by SetTop
  holder:EnableMouseWheel(true)
  holder:SetScript("OnMouseWheel", function(_, delta)
    self.offset = self.offset - delta * 3
    self:Update()
  end)

  local scroll = S.scroll
  local barW = scroll and scroll.width or 16
  for i = 1, math.floor(height / rowH) do
    local row = newRow(holder, width - barW - 6, rowH - gap)
    row:SetPoint("TOPLEFT", 0, -(i - 1) * rowH)
    self.frames[i] = row
  end

  self.empty = holder:CreateFontString(nil, "ARTWORK", "GameFontDisable")
  self.empty:SetPoint("CENTER")
  self.empty:SetText(L.NO_RESULTS)
  local dim = S.colors.dim
  self.empty:SetTextColor(dim[1], dim[2], dim[3])
  ns.UI.Flat(self.empty)

  -- The client's scroll bar (arrows, track and knob) when the theme copies the
  -- default interface; its arrows sit outside the slider, hence the insets.
  local bar, native = ns.UI.Make("Slider", holder, "UIPanelScrollBarTemplate")
  local inset = native and 16 or 0
  bar:SetOrientation("VERTICAL")
  bar:SetPoint("TOPRIGHT", 0, -inset)
  bar:SetPoint("BOTTOMRIGHT", 0, inset)
  bar:SetWidth(barW)
  bar:SetValueStep(1)
  bar.scrollStep = 3 -- rows per arrow click
  if bar.SetObeyStepOnDrag then bar:SetObeyStepOnDrag(true) end
  local track = bar:CreateTexture(nil, "BACKGROUND")
  track:SetAllPoints()
  if native then
    track:SetColorTexture(0, 0, 0, 0.25)
  elseif scroll then
    -- Slim flat bar in the theme's colors instead of the client's knob.
    track:SetColorTexture(scroll.track[1], scroll.track[2], scroll.track[3], scroll.track[4])
    local thumb = bar:CreateTexture(nil, "ARTWORK")
    thumb:SetColorTexture(scroll.thumb[1], scroll.thumb[2], scroll.thumb[3], scroll.thumb[4])
    thumb:SetSize(barW, 36)
    bar:SetThumbTexture(thumb)
  else
    track:SetColorTexture(0, 0, 0, 0.3)
    bar:SetThumbTexture("Interface\\Buttons\\UI-ScrollBar-Knob")
  end
  bar:SetMinMaxValues(0, 0)
  bar:SetValue(0)
  bar:SetScript("OnValueChanged", function(_, value)
    value = math.floor(value + 0.5)
    if value ~= self.offset then
      self.offset = value
      self:Update()
    end
  end)
  self.bar = bar
  self.holder = holder
  self.area, self.parent = r, parent
  self:SetTop(0)
end

-- Starts the list `top` units below its theme rectangle (the news cards sit
-- above it); rows that no longer fit are left out.
function List:SetTop(top)
  local r = self.area
  self.holder:ClearAllPoints()
  self.holder:SetPoint("TOPLEFT", self.parent, "TOPLEFT", r.x, -(r.y + top))
  self.holder:SetSize(r.w, r.h - top)
  self.visible = math.min(#self.frames, math.floor((r.h - top) / ns.Skin.rowH))
  self:Update()
end

-- Tag look per classification: plain rares grey, spawned creatures purple,
-- everything else (elite, rare elite) the theme's accent.
local STYLE = { rare = "grey", spawned = "spawn", spawnedelite = "spawn" }
function List.TagStyle(cls)
  return cls and STYLE[cls] or nil
end

-- Self-checks ---------------------------------------------------------------

table.insert(ns.tests, { "list: tag look per classification", function()
  assert(List.TagStyle("rare") == "grey")
  assert(List.TagStyle("spawned") == "spawn" and List.TagStyle("spawnedelite") == "spawn")
  assert(List.TagStyle("elite") == nil and List.TagStyle("rareelite") == nil and List.TagStyle(nil) == nil)
end })

table.insert(ns.tests, { "list: the tag is never cut, the name gives way", function()
  assert(List.NameWidth(200, 120, 0, 6) == 120)   -- short name, no tag
  assert(List.NameWidth(200, 320, 0, 6) == 200)   -- long name, no tag: fills the row
  assert(List.NameWidth(200, 120, 40, 6) == 120)  -- both fit
  assert(List.NameWidth(200, 180, 40, 6) == 154)  -- name shortened to leave room for the tag
  assert(List.NameWidth(30, 180, 40, 6) == 0)     -- absurdly narrow row: no negative width
end })

table.insert(ns.tests, { "list: a zone without a map takes the game's area name", function()
  local old = C_Map
  C_Map = { GetAreaInfo = function(id) return id == 990209 and "Bastilha" or nil end }
  local named = ns.ZoneLabel({ zone = "Shadowfang Keep (Dungeon)", area = 990209 })
  local unknown = ns.ZoneLabel({ zone = "Nowhere (Dungeon)", area = 990210 })
  C_Map = old
  assert(named == "Bastilha" and unknown == "Nowhere (Dungeon)", named .. " / " .. unknown)
end })
