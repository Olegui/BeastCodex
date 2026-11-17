local ADDON, ns = ...
local L = ns.L

local Window = {}
ns.Window = Window

local AUTHOR, SITE = "Oleg", "assantech.com.br"

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

-- Dark text on a light page: the client fonts' dark drop shadow reads as blur
-- there, so themes with `noShadow` drop it.
function UI.Flat(fontString)
  if ns.Skin.noShadow then fontString:SetShadowOffset(0, 0) end
  return fontString
end

function UI.Text(parent, r, font, color, justify)
  local fs = parent:CreateFontString(nil, "ARTWORK", font or "GameFontHighlightSmall")
  fs:SetPoint("TOPLEFT", parent, "TOPLEFT", r.x, -r.y)
  if r.w then fs:SetWidth(r.w) end
  fs:SetJustifyH(justify or "LEFT")
  fs:SetJustifyV("TOP")
  if color then fs:SetTextColor(color[1], color[2], color[3]) end
  return UI.Flat(fs)
end

-- A texture showing one named piece of the theme's atlas (tools/make_rows.py),
-- or nil when the theme has no atlas or no such piece. Themed controls use
-- these so that what the addon draws matches what the art paints.
function UI.Atlas(parent, layer, name)
  local art = ns.Skin.rowArt
  local piece = art and art.faces and name and art.faces[name]
  if not piece then return nil end
  local t = parent:CreateTexture(nil, layer)
  t:SetTexture(art.texture)
  t:SetTexCoord(piece[1] / art.texW, (piece[1] + piece[3]) / art.texW,
    piece[2] / art.texH, (piece[2] + piece[4]) / art.texH)
  return t
end

-- A clickable area. With `showLabel` it carries centered text; without it the
-- art underneath is the button face and `tooltip` names it on hover.
function UI.Button(parent, r, text, showLabel)
  local c = ns.Skin.colors
  local b = CreateFrame("Button", nil, parent)
  UI.Place(b, parent, r)
  local fill = showLabel and not r.face and c.control
  if fill then
    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(fill[1], fill[2], fill[3], fill[4])
  end
  -- `face` names the atlas piece that is the button's own look; `offFace` the
  -- piece laid over it while it is unavailable.
  local face = UI.Atlas(b, "BACKGROUND", r.face)
  if face then face:SetAllPoints() end
  b.off = UI.Atlas(b, "BORDER", r.offFace) or false
  if b.off then
    local pad = ns.Skin.rowArt.offPad or 0
    b.off:SetPoint("TOPLEFT", -pad, pad)
    b.off:SetPoint("BOTTOMRIGHT", pad, -pad)
    b.off:Hide()
  end
  local hl = b:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetColorTexture(c.hover[1], c.hover[2], c.hover[3], c.hover[4])
  if showLabel then
    b.label = b:CreateFontString(nil, "ARTWORK", r.font or "GameFontHighlightSmall")
    b.label:SetPoint("LEFT", 6, 0)
    b.label:SetPoint("RIGHT", -(r.padRight or 6), 0)
    b.label:SetWordWrap(false)
    -- The client fonts carry a dark drop shadow; under dark text on a light
    -- button it reads as blur, so such labels go without it.
    if r.textColor or ns.Skin.noShadow then b.label:SetShadowOffset(0, 0) end
    local tc = r.textColor or c.text
    b.label:SetTextColor(tc[1], tc[2], tc[3])
    b.label:SetText(text)
  else
    b.label = false -- the art is the face; hovering names the button
    b:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:SetText(self.tooltip or text)
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  end
  b.tooltip = text
  -- An inactive button keeps full opacity (fading text looks smeared) and
  -- changes to a muted color instead.
  -- `offText` replaces the label while inactive (e.g. why it is unavailable).
  function b:SetActive(on, offText)
    self:EnableMouse(on)
    if self.off then self.off:SetShown(not on) end
    if self.label then
      local tc = on and (r.textColor or c.text) or (r.dimColor or c.dim)
      self.label:SetTextColor(tc[1], tc[2], tc[3])
      self.label:SetText(on and text or offText or text)
    end
  end
  return b
end

-- The addon's own drop-down: a themed popup under `owner` listing `items`
-- ({ {value, label}, ... }), scrolled with the mouse wheel. One popup exists
-- per window; opening it again for the same owner closes it.
local MENU_ROW, MENU_MAX = 20, 12

local function buildMenu(parent)
  local c = ns.Skin.colors
  local bgc = c.menu or { 0.07, 0.06, 0.05, 0.98 }
  local line = c.menuBorder or { c.header[1], c.header[2], c.header[3], 0.6 }

  -- Invisible full-screen button behind the popup: a click anywhere else closes it.
  local catcher = CreateFrame("Button", nil, UIParent)
  catcher:SetAllPoints(UIParent)
  catcher:SetFrameStrata("DIALOG")
  catcher:Hide()

  local m = CreateFrame("Frame", nil, parent)
  m:SetFrameStrata("DIALOG")
  m:SetFrameLevel(catcher:GetFrameLevel() + 10)
  m:SetClampedToScreen(true)
  m:EnableMouse(true)
  m:Hide()
  m.catcher = catcher
  catcher:SetScript("OnClick", function() m:Hide() end)
  m:SetScript("OnHide", function() catcher:Hide() end)
  parent:HookScript("OnHide", function() m:Hide() end)

  local bg = m:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(bgc[1], bgc[2], bgc[3], bgc[4])
  for _, edge in ipairs({ { "TOPLEFT", "TOPRIGHT", nil, 1 }, { "BOTTOMLEFT", "BOTTOMRIGHT", nil, 1 },
                          { "TOPLEFT", "BOTTOMLEFT", 1, nil }, { "TOPRIGHT", "BOTTOMRIGHT", 1, nil } }) do
    local t = m:CreateTexture(nil, "BORDER")
    t:SetColorTexture(line[1], line[2], line[3], line[4])
    t:SetPoint(edge[1])
    t:SetPoint(edge[2])
    if edge[3] then t:SetWidth(edge[3]) else t:SetHeight(edge[4]) end
  end

  m.rows = {}
  for i = 1, MENU_MAX do
    local row = CreateFrame("Button", nil, m)
    row:SetHeight(MENU_ROW)
    row:SetPoint("TOPLEFT", 1, -(i - 1) * MENU_ROW - 3)
    row:SetPoint("TOPRIGHT", -7, -(i - 1) * MENU_ROW - 3)
    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(c.selected[1], c.selected[2], c.selected[3], c.selected[4])
    row.text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.text:SetPoint("LEFT", 10, 0)
    row.text:SetPoint("RIGHT", -4, 0)
    row.text:SetJustifyH("LEFT")
    row.text:SetWordWrap(false)
    UI.Flat(row.text)
    row:SetScript("OnClick", function(self)
      m:Hide()
      m.onPick(self.value)
    end)
    m.rows[i] = row
  end

  m.thumb = m:CreateTexture(nil, "ARTWORK")
  m.thumb:SetColorTexture(c.header[1], c.header[2], c.header[3], 0.75)
  m.thumb:SetWidth(3)

  function m:Paint()
    local shown = math.min(#self.items, MENU_MAX)
    local maxOffset = #self.items - shown
    self.offset = math.min(math.max(0, self.offset), maxOffset)
    for i, row in ipairs(self.rows) do
      local item = self.items[i + self.offset]
      if item and i <= shown then
        row.value = item[1]
        row.text:SetText(item[2])
        local col = self.isSelected(item[1]) and c.header or c.text
        row.text:SetTextColor(col[1], col[2], col[3])
        row:Show()
      else
        row:Hide()
      end
    end
    local inner = shown * MENU_ROW
    self.thumb:SetShown(maxOffset > 0)
    if maxOffset > 0 then
      local h = math.max(12, inner * shown / #self.items)
      self.thumb:SetHeight(h)
      self.thumb:ClearAllPoints()
      self.thumb:SetPoint("TOPRIGHT", -2, -3 - (inner - h) * self.offset / maxOffset)
    end
  end

  m:EnableMouseWheel(true)
  m:SetScript("OnMouseWheel", function(self, delta)
    self.offset = self.offset - delta * 2
    self:Paint()
  end)
  return m
end

local menus = setmetatable({}, { __mode = "k" }) -- window frame -> its popup

function UI.OpenMenu(owner, items, isSelected, onPick)
  local parent = owner:GetParent()
  local m = menus[parent]
  if not m then
    m = buildMenu(parent)
    menus[parent] = m
  end
  if m:IsShown() and m.owner == owner then
    m:Hide()
    return
  end
  m.owner, m.items, m.isSelected, m.onPick, m.offset = owner, items, isSelected, onPick, 0
  for i, item in ipairs(items) do -- open scrolled to the current choice
    if isSelected(item[1]) then m.offset = i - math.ceil(MENU_MAX / 2) end
  end
  m:ClearAllPoints()
  m:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, -2)
  m:SetSize(math.max(owner:GetWidth(), 150), math.min(#items, MENU_MAX) * MENU_ROW + 6)
  m:Paint()
  m.catcher:Show()
  m:Show()
end

-- A filter button that opens the drop-down. `options()` returns
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
    local items = { { nil, L.ALL } }
    for _, o in ipairs(options()) do items[#items + 1] = o end
    UI.OpenMenu(self, items,
      function(value) return ns.db.filters[key] == value end,
      function(value)
        ns.db.filters[key] = value
        refresh()
        onChange()
      end)
  end)

  refresh()
  return button
end

local function newCheck(parent, r, text, checked, onChange)
  local c = ns.Skin.colors
  local b = CreateFrame("Button", nil, parent)
  UI.Place(b, parent, r)
  local box = UI.Atlas(b, "BACKGROUND", "box")
  local mark = UI.Atlas(b, "ARTWORK", "tick")
  if box and mark then
    box:SetAllPoints()
    mark:SetAllPoints()
  else
    -- No themed pieces: a flat box and the client's tick.
    if c.control then
      local bg = b:CreateTexture(nil, "BACKGROUND")
      bg:SetAllPoints()
      bg:SetColorTexture(c.control[1], c.control[2], c.control[3], c.control[4])
    end
    mark = b:CreateTexture(nil, "ARTWORK")
    mark:SetPoint("CENTER")
    mark:SetSize(r.w * 1.5, r.h * 1.5)
    mark:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
  end
  mark:SetShown(checked)
  if r.labelW then
    local label = b:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    label:SetPoint("LEFT", b, "RIGHT", 6, 0)
    label:SetWidth(r.labelW)
    label:SetJustifyH("LEFT")
    -- Up to two lines: long translations wrap instead of being cut short.
    label:SetWordWrap(true)
    if label.SetMaxLines then label:SetMaxLines(2) end
    label:SetTextColor(c.text[1], c.text[2], c.text[3])
    label:SetText(text)
    UI.Flat(label)
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
  local rows, count = ns.Filter.Apply(ns.Creatures, ns.db.filters, nil, nil, ns.KnownLocalName)
  ns.List:SetRows(rows)
  if self.count then self.count:SetText(L.COUNT_FMT:format(count, #ns.Creatures)) end
end

function Window:Create()
  local S = ns.Skin
  local c = S.colors
  -- The window is rebuilt when the theme changes, so each build gets its own name.
  Window.serial = (Window.serial or 0) + 1
  local frameName = "BeastCodexFrame" .. Window.serial
  local f = CreateFrame("Frame", frameName, UIParent,
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
  for i = #UISpecialFrames, 1, -1 do -- Esc closes the current build only
    if tostring(UISpecialFrames[i]):find("^BeastCodexFrame") then table.remove(UISpecialFrames, i) end
  end
  tinsert(UISpecialFrames, frameName)
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
    UI.Text(f, S.title, "GameFontNormalLarge", c.title, S.title.center and "CENTER" or "LEFT"):SetText(L.TITLE)
  end

  local close = UI.Button(f, S.close, CLOSE or "Close", S.close.text ~= nil)
  if close.label then close.label:SetText(S.close.text) end
  close:SetScript("OnClick", function() f:Hide() end)

  local search = CreateFrame("EditBox", nil, f)
  UI.Place(search, f, S.search)
  search:SetFontObject("GameFontHighlightSmall")
  local sc = S.search.textColor or c.text
  search:SetTextColor(sc[1], sc[2], sc[3])
  search:SetTextInsets(6, S.search.padRight or 6, 0, 0)
  search:SetAutoFocus(false)
  if c.control then
    local bg = search:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(c.control[1], c.control[2], c.control[3], c.control[4])
  end
  -- Placeholder: shown while the field is empty and not being typed in.
  local hint = search:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  hint:SetPoint("LEFT", 6, 0)
  hint:SetPoint("RIGHT", -(S.search.padRight or 6), 0)
  hint:SetJustifyH("LEFT")
  hint:SetTextColor(c.dim[1], c.dim[2], c.dim[3])
  hint:SetText(L.SEARCH_PLACEHOLDER)
  UI.Flat(hint)

  -- With text in the field, an X over the magnifier clears it.
  local clear = UI.Button(f, S.searchClear, L.CLEAR_SEARCH, S.searchClear.text ~= nil)
  if clear.label then clear.label:SetText(S.searchClear.text) end
  local cover = UI.Atlas(clear, "BACKGROUND", S.searchClear.face)
  if cover then cover:SetAllPoints() end
  clear:SetFrameLevel(search:GetFrameLevel() + 2)
  clear:SetScript("OnClick", function()
    search:SetText("")
    search:ClearFocus()
  end)

  local function paintSearch()
    local empty = search:GetText() == ""
    hint:SetShown(empty and not search:HasFocus())
    clear:SetShown(not empty)
  end
  search:SetScript("OnEditFocusGained", paintSearch)
  search:SetScript("OnEditFocusLost", paintSearch)

  search:SetText(ns.db.filters.search or "")
  search:SetScript("OnEscapePressed", search.ClearFocus)
  search:SetScript("OnEnterPressed", search.ClearFocus)
  search:SetScript("OnTextChanged", function(self)
    paintSearch()
    ns.db.filters.search = self:GetText()
    Window:Refresh()
  end)
  paintSearch()
  if S.search.label then
    local label = f:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    label:SetPoint("RIGHT", search, "LEFT", -8, 0)
    label:SetTextColor(c.header[1], c.header[2], c.header[3])
    label:SetText(L.SEARCH)
  end

  if S.themeButton then
    local current = ns.Themes[ns.themeName]
    local themeButton = UI.Button(f, S.themeButton, L.THEME .. ": " .. (current.label or ns.themeName), true)
    themeButton:SetScript("OnClick", function(self)
      local items = {}
      for name, theme in pairs(ns.Themes) do items[#items + 1] = { name, theme.label or name } end
      table.sort(items, function(a, b) return a[2] < b[2] end)
      UI.OpenMenu(self, items,
        function(name) return name == ns.themeName end,
        function(name) Window:SetTheme(name) end)
    end)
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
  newCheck(f, S.check2, L.ONLY_LOCATED, ns.db.filters.onlyLocated, function(on)
    ns.db.filters.onlyLocated = on
    Window:Refresh()
  end)

  self.count = S.count and UI.Text(f, S.count, "GameFontDisableSmall", c.dim) or nil

  -- Footer credits, as in EAD Skill Preview: author, then the site in the accent color.
  if S.credits then
    UI.Text(f, S.credits, "GameFontDisableSmall", c.dim, "CENTER")
      :SetText(L.CREDITS:format(AUTHOR) .. "  •  |cff" .. c.tag .. SITE .. "|r")
  end

  ns.List:Create(f, S.list)
  ns.Detail:Create(f)

  self.frame = f
end

-- Switches theme in place: the window is rebuilt from the new theme, keeping
-- its position, whether it was open, and the pinned creature.
function Window:SetTheme(name)
  if not ns.Themes[name] then return false end
  ns.db.theme = ns.ApplyTheme(name)
  local old = self.frame
  if not old then return true end
  local shown = old:IsShown()
  local point, _, relPoint, x, y = old:GetPoint(1)
  local pinned = ns.Detail.pinned
  old:Hide()
  self.frame = nil
  self:Create()
  if point then
    self.frame:ClearAllPoints()
    self.frame:SetPoint(point, UIParent, relPoint, x, y)
  end
  if shown then
    self:Refresh()
    self.frame:Show()
    if pinned then ns.Detail:Pin(pinned) end
  end
  return true
end

function Window:Toggle()
  if not self.frame then self:Create() end
  if self.frame:IsShown() then
    self.frame:Hide()
  else
    self:Refresh()
    self.frame:Show()
    ns.Preload()
  end
end
