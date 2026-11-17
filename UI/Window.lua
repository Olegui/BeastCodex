local ADDON, ns = ...
local L = ns.L

local Window = {}
ns.Window = Window

-- Small widget helpers shared by the window and the detail panel. They are
-- plain frames (no Blizzard templates), so UI-skinning addons leave them
-- alone and a theme's art can show through.
local UI = {}
ns.UI = UI

function UI.Place(frame, parent, r)
  frame:ClearAllPoints()
  frame:SetPoint("TOPLEFT", parent, "TOPLEFT", r.x, -r.y)
  if r.w then frame:SetSize(r.w, r.h or 20) end
end

function UI.Text(parent, r, font, color, justify)
  local fs = parent:CreateFontString(nil, "ARTWORK", font or "GameFontHighlightSmall")
  fs:SetPoint("TOPLEFT", parent, "TOPLEFT", r.x, -r.y)
  if r.w then fs:SetWidth(r.w) end
  fs:SetJustifyH(justify or "LEFT")
  fs:SetJustifyV("TOP")
  if color then fs:SetTextColor(color[1], color[2], color[3]) end
  return fs
end

-- A clickable area. With `showLabel` it carries centered text; without it the
-- art underneath is the button face and `tooltip` names it on hover.
function UI.Button(parent, r, text, showLabel)
  local c = ns.Skin.colors
  local b = CreateFrame("Button", nil, parent)
  UI.Place(b, parent, r)
  if c.control and showLabel then
    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(c.control[1], c.control[2], c.control[3], c.control[4])
  end
  local hl = b:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetColorTexture(c.hover[1], c.hover[2], c.hover[3], c.hover[4])
  if showLabel then
    b.label = b:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    b.label:SetPoint("LEFT", 6, 0)
    b.label:SetPoint("RIGHT", -6, 0)
    b.label:SetWordWrap(false)
    local tc = r.textColor or c.text
    b.label:SetTextColor(tc[1], tc[2], tc[3])
    b.label:SetText(text)
  else
    b:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:SetText(self.tooltip or text)
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  end
  b.tooltip = text
  function b:SetActive(on)
    self:EnableMouse(on)
    self:SetAlpha((on or not showLabel) and 1 or 0.4)
  end
  return b
end

-- A filter button that opens a scrolling radio menu. `options()` returns
-- { {value, label}, ... }; every menu starts with "All" (value nil).
local function newFilter(parent, r, title, key, options, onChange)
  local c = ns.Skin.colors
  if r.label then
    UI.Text(parent, r.label, "GameFontNormalSmall", c.header):SetText(title)
  end
  local button = UI.Button(parent, r, L.ALL, true)

  local function refresh()
    local text = L.ALL
    for _, o in ipairs(options()) do
      if o[1] == ns.db.filters[key] then text = o[2] end
    end
    -- Without a separate label the button itself has to say which filter it is.
    button.label:SetText(r.label and text or (title .. ": " .. text))
  end

  button:SetScript("OnClick", function(self)
    if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
    MenuUtil.CreateContextMenu(self, function(_, root)
      if root.SetScrollMode then root:SetScrollMode(360) end
      local function add(value, text)
        root:CreateRadio(text,
          function() return ns.db.filters[key] == value end,
          function()
            ns.db.filters[key] = value
            refresh()
            onChange()
          end)
      end
      add(nil, L.ALL)
      for _, o in ipairs(options()) do add(o[1], o[2]) end
    end)
  end)

  refresh()
  return button
end

local function newCheck(parent, r, text, checked, onChange)
  local c = ns.Skin.colors
  local b = CreateFrame("Button", nil, parent)
  UI.Place(b, parent, r)
  local box = c.checkBox or c.control
  if box then
    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(box[1], box[2], box[3], box[4])
  end
  local mark = b:CreateTexture(nil, "ARTWORK")
  mark:SetPoint("CENTER")
  mark:SetSize(r.w * 1.5, r.h * 1.5)
  mark:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
  mark:SetShown(checked)
  if r.labelW then
    local label = b:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    label:SetPoint("LEFT", b, "RIGHT", 6, 0)
    label:SetWidth(r.labelW)
    label:SetJustifyH("LEFT")
    label:SetTextColor(c.text[1], c.text[2], c.text[3])
    label:SetText(text)
  else
    b:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:SetText(text)
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  end
  b:SetScript("OnClick", function()
    checked = not checked
    mark:SetShown(checked)
    onChange(checked)
  end)
  return b
end

local function familyOptions()
  local out = {}
  for _, f in ipairs(ns.Filter.Families()) do out[#out + 1] = { f, ns.Filter.FamilyName(f) } end
  table.sort(out, function(a, b) return a[2] < b[2] end)
  return out
end

local zoneOptionsCache
local function zoneOptions()
  if zoneOptionsCache then return zoneOptionsCache end
  local label = {}
  for _, c in ipairs(ns.Creatures) do
    if c.zone and not label[c.zone] then label[c.zone] = ns.ZoneLabel(c) end
  end
  local out = {}
  for zone, text in pairs(label) do out[#out + 1] = { zone, text } end
  table.sort(out, function(a, b) return a[2] < b[2] end)
  zoneOptionsCache = out
  return out
end

local function bucketOptions()
  local out = {}
  for i, b in ipairs(ns.Filter.Buckets()) do out[i] = { i, b[1] .. "-" .. b[2] } end
  return out
end

function Window:Refresh()
  if not self.frame then return end
  local rows, count = ns.Filter.Apply(ns.Creatures, ns.db.filters)
  ns.List:SetRows(rows)
  if self.count then self.count:SetText(L.COUNT_FMT:format(count, #ns.Creatures)) end
end

function Window:Create()
  local S = ns.Skin
  local c = S.colors
  local f = CreateFrame("Frame", "BeastCodexFrame", UIParent,
    S.backdrop and BackdropTemplateMixin and "BackdropTemplate" or nil)
  f:SetSize(S.W, S.H)
  f:SetPoint("CENTER")
  f:SetFrameStrata("HIGH")
  f:SetMovable(true)
  f:EnableMouse(true)
  f:SetClampedToScreen(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  tinsert(UISpecialFrames, "BeastCodexFrame") -- Esc closes it
  f:Hide()

  if S.texture then
    local art = f:CreateTexture(nil, "BACKGROUND")
    art:SetAllPoints()
    art:SetTexture(S.texture)
    art:SetTexCoord(0, S.imgW / S.texW, 0, S.imgH / S.texH)
  elseif S.backdrop and f.SetBackdrop then
    f:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8X8",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    f:SetBackdropColor(0.09, 0.07, 0.05, 0.96)
    f:SetBackdropBorderColor(0.6, 0.45, 0.25, 1)
  end

  if S.title then
    UI.Text(f, S.title, "GameFontNormalLarge", c.title):SetText(L.TITLE)
  end

  local close = UI.Button(f, S.close, CLOSE or "Close", S.close.text ~= nil)
  if close.label then close.label:SetText(S.close.text) end
  close:SetScript("OnClick", function() f:Hide() end)

  local search = CreateFrame("EditBox", nil, f)
  UI.Place(search, f, S.search)
  search:SetFontObject("GameFontHighlightSmall")
  search:SetTextColor(c.text[1], c.text[2], c.text[3])
  search:SetTextInsets(6, 6, 0, 0)
  search:SetAutoFocus(false)
  if c.control then
    local bg = search:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(c.control[1], c.control[2], c.control[3], c.control[4])
  end
  search:SetText(ns.db.filters.search or "")
  search:SetScript("OnEscapePressed", search.ClearFocus)
  search:SetScript("OnEnterPressed", search.ClearFocus)
  search:SetScript("OnTextChanged", function(self)
    ns.db.filters.search = self:GetText()
    Window:Refresh()
  end)
  if S.search.label then
    local label = f:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    label:SetPoint("RIGHT", search, "LEFT", -8, 0)
    label:SetTextColor(c.header[1], c.header[2], c.header[3])
    label:SetText(L.SEARCH)
  end

  local onChange = function() Window:Refresh() end
  local specs = {
    { L.FILTER_FAMILY, "family", familyOptions },
    { L.FILTER_ZONE, "zone", zoneOptions },
    { L.FILTER_LEVEL, "bucket", bucketOptions },
  }
  for i, spec in ipairs(specs) do
    newFilter(f, S.filters[i], spec[1], spec[2], spec[3], onChange)
  end

  newCheck(f, S.check, L.SHOW_UNTAMEABLE, ns.db.filters.showUntameable, function(on)
    ns.db.filters.showUntameable = on
    Window:Refresh()
  end)

  self.count = S.count and UI.Text(f, S.count, "GameFontDisableSmall", c.dim) or nil

  ns.List:Create(f, S.list)
  ns.Detail:Create(f)

  self.frame = f
end

function Window:Toggle()
  if not self.frame then self:Create() end
  if self.frame:IsShown() then
    self.frame:Hide()
  else
    self:Refresh()
    self.frame:Show()
  end
end
