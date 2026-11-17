local ADDON, ns = ...
local L = ns.L

-- Virtual list: a fixed set of row frames is reused over any number of rows.
local List = { rows = {}, frames = {}, offset = 0 }
ns.List = List

-- Filled by UI/Detail.lua; called only when set.
List.onEnter, List.onLeave, List.onClick = nil, nil, nil

local zoneCache = {}

-- The game's own (localized) map name when the map is known, else the English zone.
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
  return c.zone or ""
end

function ns.LevelText(c)
  if not c.min then return L.LEVEL_UNKNOWN end
  return c.min == c.max and tostring(c.min) or (c.min .. "-" .. c.max)
end

local function paint(row, data)
  row.data = data
  if not data then row:Hide() return end
  row:Show()
  local c = data.creature
  row.icon:Hide()
  row.selected:Hide()
  if not c then
    row:EnableMouse(false)
    row.name:SetText(data.header)
    row.name:SetTextColor(1, 0.82, 0)
    row.name:SetPoint("LEFT", 4, 0)
    row.level:SetText("")
    row.zone:SetText("")
    return
  end
  row:EnableMouse(true)
  local cls = ns.ClsLabel(c.cls)
  local tag = cls and (" |cff7fb2ff" .. cls .. "|r") or ""
  row.name:SetText(c.name .. tag)
  row.name:SetPoint("LEFT", 22, 0)
  row.level:SetText(ns.LevelText(c))
  row.zone:SetText(ns.ZoneLabel(c))
  local r, g, b = 1, 1, 1
  if not c.tame then
    r, g, b = 0.5, 0.5, 0.5
    row.icon:Show()
  end
  row.name:SetTextColor(r, g, b)
  row.level:SetTextColor(r, g, b)
  row.zone:SetTextColor(r, g, b)
  if List.selectedId == c.id then row.selected:Show() end
end

function List:Update()
  local maxOffset = math.max(0, #self.rows - #self.frames)
  self.offset = math.min(math.max(0, self.offset), maxOffset)
  for i, row in ipairs(self.frames) do
    paint(row, self.rows[i + self.offset])
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

local function newRow(parent, width, height)
  local row = CreateFrame("Button", nil, parent)
  row:SetSize(width, height)

  local hl = row:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetColorTexture(1, 1, 1, 0.12)

  row.selected = row:CreateTexture(nil, "BACKGROUND")
  row.selected:SetAllPoints()
  row.selected:SetColorTexture(1, 0.82, 0, 0.18)

  row.icon = row:CreateTexture(nil, "ARTWORK")
  row.icon:SetSize(14, 14)
  row.icon:SetPoint("LEFT", 4, 0)
  row.icon:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")

  row.zone = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  row.zone:SetPoint("RIGHT", -4, 0)
  row.zone:SetWidth(130)
  row.zone:SetJustifyH("LEFT")
  row.zone:SetWordWrap(false)

  row.level = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  row.level:SetPoint("RIGHT", row.zone, "LEFT", -6, 0)
  row.level:SetWidth(44)
  row.level:SetJustifyH("LEFT")

  row.name = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  row.name:SetPoint("LEFT", 22, 0)
  row.name:SetPoint("RIGHT", row.level, "LEFT", -6, 0)
  row.name:SetJustifyH("LEFT")
  row.name:SetWordWrap(false)

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

-- Builds the list inside `parent`, anchored at its top-left corner offset.
function List:Create(parent, x, y, width, height)
  local rowH = ns.Skin.rowH
  local holder = CreateFrame("Frame", nil, parent)
  holder:SetPoint("TOPLEFT", x, y)
  holder:SetSize(width, height)
  holder:EnableMouseWheel(true)
  holder:SetScript("OnMouseWheel", function(_, delta)
    self.offset = self.offset - delta * 3
    self:Update()
  end)

  local barW = 16
  for i = 1, math.floor(height / rowH) do
    local row = newRow(holder, width - barW - 4, rowH)
    row:SetPoint("TOPLEFT", 0, -(i - 1) * rowH)
    self.frames[i] = row
  end

  self.empty = holder:CreateFontString(nil, "ARTWORK", "GameFontDisable")
  self.empty:SetPoint("CENTER")
  self.empty:SetText(L.NO_RESULTS)

  local bar = CreateFrame("Slider", nil, holder)
  bar:SetOrientation("VERTICAL")
  bar:SetPoint("TOPRIGHT", 0, 0)
  bar:SetPoint("BOTTOMRIGHT", 0, 0)
  bar:SetWidth(barW)
  bar:SetValueStep(1)
  if bar.SetObeyStepOnDrag then bar:SetObeyStepOnDrag(true) end
  local track = bar:CreateTexture(nil, "BACKGROUND")
  track:SetAllPoints()
  track:SetColorTexture(0, 0, 0, 0.3)
  bar:SetThumbTexture("Interface\\Buttons\\UI-ScrollBar-Knob")
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
end
