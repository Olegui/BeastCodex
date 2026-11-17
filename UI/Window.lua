local ADDON, ns = ...
local L = ns.L

local Window = {}
ns.Window = Window

local GAP = 12

-- A button that opens a scrolling radio menu. `options()` returns { {value, label}, ... };
-- the first entry of every menu is "All" (value nil).
local function newMenuButton(parent, title, key, options, onChange)
  local label = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  label:SetText(title)

  local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  button:SetSize(ns.Skin.filterW, 22)
  button:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -3)

  local function refresh()
    local text = L.ALL
    for _, o in ipairs(options()) do
      if o[1] == ns.db.filters[key] then text = o[2] end
    end
    button:SetText(text)
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
  return label, button
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
  self.count:SetText(L.COUNT_FMT:format(count, #ns.Creatures))
end

function Window:Create()
  local S = ns.Skin
  local f = CreateFrame("Frame", "BeastCodexFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
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

  -- Provisional frame until Art/Frame.tga exists.
  if S.texture then
    local art = f:CreateTexture(nil, "BACKGROUND")
    art:SetAllPoints()
    art:SetTexture(S.texture)
    art:SetTexCoord(0, S.W / 1024, 0, S.H / 1024)
  elseif f.SetBackdrop then
    f:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8X8",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    f:SetBackdropColor(0.09, 0.07, 0.05, 0.96)
    f:SetBackdropBorderColor(0.6, 0.45, 0.25, 1)
  end

  local title = f:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", S.inset.l, -(S.inset.t - 44))
  title:SetText(L.TITLE)

  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -(S.inset.r - 30), -(S.inset.t - 54))

  local search = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
  search:SetSize(180, 20)
  search:SetPoint("TOPRIGHT", -(S.inset.r + 24), -(S.inset.t - 42))
  search:SetAutoFocus(false)
  search:SetText(ns.db.filters.search or "")
  search:SetScript("OnEscapePressed", search.ClearFocus)
  search:SetScript("OnEnterPressed", search.ClearFocus)
  search:SetScript("OnTextChanged", function(self)
    ns.db.filters.search = self:GetText()
    Window:Refresh()
  end)
  local searchLabel = f:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  searchLabel:SetPoint("RIGHT", search, "LEFT", -10, 0)
  searchLabel:SetText(L.SEARCH)

  -- Left column: filters
  local onChange = function() Window:Refresh() end
  local x, y = S.inset.l, -S.inset.t
  local specs = {
    { L.FILTER_FAMILY, "family", familyOptions },
    { L.FILTER_ZONE, "zone", zoneOptions },
    { L.FILTER_LEVEL, "bucket", bucketOptions },
  }
  for _, spec in ipairs(specs) do
    local label = newMenuButton(f, spec[1], spec[2], spec[3], onChange)
    label:SetPoint("TOPLEFT", x, y)
    y = y - 50
  end

  local check = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
  check:SetSize(24, 24)
  check:SetPoint("TOPLEFT", x - 4, y)
  check:SetChecked(ns.db.filters.showUntameable)
  check:SetScript("OnClick", function(self)
    ns.db.filters.showUntameable = self:GetChecked() and true or false
    Window:Refresh()
  end)
  local checkText = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  checkText:SetPoint("LEFT", check, "RIGHT", 2, 0)
  checkText:SetWidth(S.filterW - 26)
  checkText:SetJustifyH("LEFT")
  checkText:SetText(L.SHOW_UNTAMEABLE)

  self.count = f:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  self.count:SetPoint("BOTTOMLEFT", S.inset.l, S.inset.b)
  self.count:SetWidth(S.filterW)
  self.count:SetJustifyH("LEFT")

  -- Centre column: the list. Right column belongs to UI/Detail.lua.
  local contentH = S.H - S.inset.t - S.inset.b
  local listX = S.inset.l + S.filterW + GAP
  local listW = S.W - S.inset.l - S.inset.r - S.filterW - S.detailW - 2 * GAP
  ns.List:Create(f, listX, -S.inset.t, listW, contentH)
  if ns.Detail and ns.Detail.Create then
    ns.Detail:Create(f, listX + listW + GAP, -S.inset.t, S.detailW, contentH)
  end

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
