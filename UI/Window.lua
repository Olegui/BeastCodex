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

-- Fills `frame` with an atlas piece cut in nine: corners keep their size
-- (`corner` atlas px, shown at half size like the rows), edges and middle
-- stretch, so rounded corners stay round at any size. False without the piece.
function UI.Slice(frame, layer, name, corner)
  local art = ns.Skin.rowArt
  local p = art and art.faces and art.faces[name]
  if not p then return false end
  corner = corner or 12
  local xs = { p[1], p[1] + corner, p[1] + p[3] - corner, p[1] + p[3] }
  local ys = { p[2], p[2] + corner, p[2] + p[4] - corner, p[2] + p[4] }
  local s = corner / 2
  -- Per column: where its left and right edges sit ({frame side, offset}); rows likewise.
  local cols = { { { "LEFT", 0 }, { "LEFT", s } }, { { "LEFT", s }, { "RIGHT", -s } }, { { "RIGHT", -s }, { "RIGHT", 0 } } }
  local rows = { { { "TOP", 0 }, { "TOP", -s } }, { { "TOP", -s }, { "BOTTOM", s } }, { { "BOTTOM", s }, { "BOTTOM", 0 } } }
  for r, row in ipairs(rows) do
    for c, col in ipairs(cols) do
      local t = frame:CreateTexture(nil, layer)
      t:SetTexture(art.texture)
      t:SetTexCoord(xs[c] / art.texW, xs[c + 1] / art.texW, ys[r] / art.texH, ys[r + 1] / art.texH)
      t:SetPoint("TOPLEFT", frame, row[1][1] .. col[1][1], col[1][2], row[1][2])
      t:SetPoint("BOTTOMRIGHT", frame, row[2][1] .. col[2][1], col[2][2], row[2][2])
    end
  end
  return true
end

-- A panel box behind `frame`: the theme's rounded card, else a flat dark fill
-- with a thin line around it.
-- `opaque` for a window over the game world rather than a card inside the codex.
function UI.Box(frame, opaque)
  if UI.Slice(frame, "BACKGROUND", opaque and "panel" or "card") then return end
  local c = ns.Skin.colors
  local bg = frame:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  local fill = opaque and (c.menu or { 0.07, 0.06, 0.05, 0.96 }) or { 0, 0, 0, 0.3 }
  bg:SetColorTexture(fill[1], fill[2], fill[3], fill[4])
  local line = c.menuBorder or { c.header[1], c.header[2], c.header[3], 0.5 }
  for _, edge in ipairs({ { "TOPLEFT", "TOPRIGHT", nil, 1 }, { "BOTTOMLEFT", "BOTTOMRIGHT", nil, 1 },
                          { "TOPLEFT", "BOTTOMLEFT", 1, nil }, { "TOPRIGHT", "BOTTOMRIGHT", 1, nil } }) do
    local t = frame:CreateTexture(nil, "BORDER")
    t:SetColorTexture(line[1], line[2], line[3], line[4] or 0.5)
    t:SetPoint(edge[1])
    t:SetPoint(edge[2])
    if edge[3] then t:SetWidth(edge[3]) else t:SetHeight(edge[4]) end
  end
end

-- Sets `text` in the first font of `fonts` (global font object names, largest
-- first) in which it fits the string's width; in the last one otherwise, where
-- the client cuts it short with "...". Returns whether it was cut. `width`
-- defaults to the string's own (set it for one sized by its anchors).
function UI.Fit(fs, text, fonts, width)
  width = width or fs:GetWidth()
  for i, name in ipairs(fonts) do
    if _G[name] then fs:SetFontObject(_G[name]) end
    fs:SetText(text)
    if fs:GetStringWidth() <= width then return false end
    if i == #fonts then return true end
  end
  return false
end

-- White glyphs from Art/Icons.tga (tools/make_icons.py), tinted per use.
local ICON_FILE = "Interface\\AddOns\\BeastCodex\\Art\\Icons"
local ICON_CELL = { rotLeft = 0, rotRight = 1, play = 2, pause = 3, alert = 4, chevUp = 5, chevDown = 6, close = 7 }

function UI.SetIcon(t, name)
  local i = ICON_CELL[name]
  t:SetTexture(ICON_FILE)
  t:SetTexCoord(i / 8, (i + 1) / 8, 0, 1)
end

-- A small round button showing one icon in the theme's accent, named by a
-- tooltip on hover. Themes with an atlas give it the round checkbox face.
function UI.IconButton(parent, size, icon, tooltip, color)
  local c = ns.Skin.colors
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(size, size)
  local face = UI.Atlas(b, "BACKGROUND", "box")
  if face then
    face:SetAllPoints()
  else
    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.45)
  end
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetPoint("CENTER")
  b.icon:SetSize(size * 0.62, size * 0.62)
  local tint = color or c.header
  b.icon:SetVertexColor(tint[1], tint[2], tint[3])
  UI.SetIcon(b.icon, icon)
  local hl = b:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetColorTexture(c.hover[1], c.hover[2], c.hover[3], c.hover[4])
  b.tooltip = tooltip
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText(self.tooltip)
    if self.tooltipText then GameTooltip:AddLine(self.tooltipText, 1, 1, 1, true) end
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return b
end

-- A frame built from one of the client's templates when the theme copies the
-- default interface (`blizzard`). Returns the frame and whether the template
-- was used; a client without that template gets a plain frame instead.
function UI.Make(kind, parent, template, name)
  if template and ns.Skin.blizzard then
    local ok, frame = pcall(CreateFrame, kind, name, parent, template)
    if ok and frame then return frame, true end
  end
  return CreateFrame(kind, name, parent), false
end

-- The client's own drop-down and menu (the ones the default interface uses),
-- or nil when the theme has its own look or the client lacks them.
-- `items()` returns { {value, label}, ... }.
function UI.NativeDropdown(parent, r, items, isSelected, onPick)
  if not ns.Skin.blizzard then return nil end
  local ok, dd = pcall(CreateFrame, "DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
  if not ok or not dd or not dd.SetupMenu then return nil end
  UI.Place(dd, parent, r)
  dd:SetupMenu(function(_, root)
    if root.SetScrollMode then root:SetScrollMode(400) end
    for _, item in ipairs(items()) do
      local value = item[1]
      root:CreateRadio(item[2], function() return isSelected(value) end, function() onPick(value) end)
    end
  end)
  return dd
end

-- A red glow on hover, for close buttons (as in EAD Skill Preview). The
-- client's round highlight is blue; without its color it takes the red.
function UI.RedGlow(b)
  -- Themes with an atlas: a disc filling the whole round button.
  local disc = UI.Atlas(b, "HIGHLIGHT", "disc")
  if disc then
    disc:SetAllPoints()
    disc:SetBlendMode("ADD")
    disc:SetVertexColor(1, 0.15, 0.08, 0.85)
    return
  end
  b:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
  local t = b:GetHighlightTexture()
  if t then
    t:SetDesaturated(true)
    t:SetVertexColor(1, 0.12, 0.08)
  end
end

-- An atlas piece over `b`, `pad` units past its edges, as one object with
-- Show/Hide/SetShown/SetBlend/SetColor. With `r.pill` it is three textures:
-- ends kept in proportion (`r.capR` atlas px for the right one, half the
-- piece's height otherwise), middle stretched. Nil without the piece.
function UI.Face(b, layer, name, pad, r)
  local art = ns.Skin.rowArt
  local p = art and art.faces and name and art.faces[name]
  if not p then return nil end
  local parts = {}
  local function tex(x0, x1)
    local t = b:CreateTexture(nil, layer)
    t:SetTexture(art.texture)
    t:SetTexCoord(x0 / art.texW, x1 / art.texW, p[2] / art.texH, (p[2] + p[4]) / art.texH)
    parts[#parts + 1] = t
    return t
  end
  if r.pill then
    local k = (r.h + 2 * pad) / p[4] -- window units per atlas px
    local capL, capR = p[4] / 2, r.capR or p[4] / 2
    local left, right = tex(p[1], p[1] + capL), tex(p[1] + p[3] - capR, p[1] + p[3])
    local mid = tex(p[1] + capL, p[1] + p[3] - capR)
    left:SetPoint("TOPLEFT", -pad, pad)
    left:SetPoint("BOTTOMLEFT", -pad, -pad)
    left:SetWidth(capL * k)
    right:SetPoint("TOPRIGHT", pad, pad)
    right:SetPoint("BOTTOMRIGHT", pad, -pad)
    right:SetWidth(capR * k)
    mid:SetPoint("TOPLEFT", left, "TOPRIGHT")
    mid:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT")
  else
    local t = tex(p[1], p[1] + p[3])
    t:SetPoint("TOPLEFT", -pad, pad)
    t:SetPoint("BOTTOMRIGHT", pad, -pad)
  end
  local face = {}
  function face:SetShown(on) for _, t in ipairs(parts) do t:SetShown(on) end end
  function face:Show() self:SetShown(true) end
  function face:Hide() self:SetShown(false) end
  function face:SetBlend(mode) for _, t in ipairs(parts) do t:SetBlendMode(mode) end end
  function face:SetColor(cr, cg, cb, ca) for _, t in ipairs(parts) do t:SetVertexColor(cr, cg, cb, ca) end end
  return face
end

-- A clickable area. With `showLabel` it carries centered text; without it the
-- art underneath is the button face and `tooltip` names it on hover.
-- `template` adds one of the client's templates (a secure action button, say).
function UI.Button(parent, r, text, showLabel, template)
  if showLabel and not r.face and ns.Skin.blizzard then
    local b, native = UI.Make("Button", parent, (template and template .. ", " or "") .. "UIPanelButtonTemplate")
    if native then
      -- The client's red button: its own textures, highlight and disabled look.
      UI.Place(b, parent, r)
      b:SetText(text)
      b.label, b.off, b.tooltip = b:GetFontString() or false, false, text
      function b:SetActive(on, offText)
        self:SetEnabled(on)
        self:SetText(on and text or offText or text)
      end
      return b
    end
    b:Hide()
  end
  local c = ns.Skin.colors
  local b = CreateFrame("Button", nil, parent, template)
  UI.Place(b, parent, r)
  local fill = showLabel and not r.face and c.control
  if fill then
    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(fill[1], fill[2], fill[3], fill[4])
  end
  -- `face` names the atlas piece that is the button's own look; `offFace` the
  -- piece laid over it while it is unavailable. `facePad`: window units the
  -- face reaches past the button (faces cut with their rim, or covering a
  -- painted control underneath); `pill` draws it in three parts so its round
  -- ends stay round at any width.
  local facePad = r.facePad or 0
  local face = UI.Face(b, "BACKGROUND", r.face, facePad, r)
  b.off = UI.Face(b, "BORDER", r.offFace, ns.Skin.rowArt and ns.Skin.rowArt.offPad or 0, r) or false
  if b.off then b.off:Hide() end
  -- Hover lights the button's own shape (its face, or the shape of the painted
  -- button under it), in the accent; nothing square spills past round corners.
  local shape = r.face or r.offFace
  local glow = shape and UI.Face(b, "HIGHLIGHT", shape, r.face and facePad or ns.Skin.rowArt.offPad or 0, r)
  if glow then
    glow:SetBlend("ADD")
    glow:SetColor(c.header[1], c.header[2], c.header[3], 0.45)
  elseif r.glow == "red" then
    UI.RedGlow(b)
  else
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(c.hover[1], c.hover[2], c.hover[3], c.hover[4])
  end
  if showLabel then
    b.label = b:CreateFontString(nil, "ARTWORK", r.font or "GameFontHighlightSmall")
    -- labelY nudges the text up (window units) on art whose visible face is
    -- not centered in its rect, like a button with a heavier bottom rim.
    b.label:SetPoint("LEFT", 6, r.labelY or 0)
    b.label:SetPoint("RIGHT", -(r.padRight or 6), r.labelY or 0)
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
  local native = UI.NativeDropdown(parent, r,
    function()
      local items = { { nil, L.ALL } }
      for _, o in ipairs(options()) do items[#items + 1] = o end
      return items
    end,
    function(value) return ns.db.filters[key] == value end,
    function(value)
      ns.db.filters[key] = value
      onChange()
    end)
  if native then return native end
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
  local b, native = UI.Make("CheckButton", parent, "UICheckButtonTemplate")
  if not native then
    b:Hide()
    b = CreateFrame("Button", nil, parent)
  end
  UI.Place(b, parent, r)
  local box = not native and UI.Atlas(b, "BACKGROUND", "box")
  local mark = not native and UI.Atlas(b, "ARTWORK", "tick")
  if native then
    -- The client's checkbox draws its own box and tick.
    b:SetChecked(checked)
    mark = { SetShown = function() end }
  elseif box and mark then
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
  -- One entry per name shown: sub-areas of the same map share the map's name,
  -- and the filter (Filter.Apply) matches all of them.
  local out, seen = {}, {}
  for _, c in ipairs(ns.Creatures) do
    local text = c.zone and ns.ZoneLabel(c)
    if text and not seen[text] then
      seen[text] = true
      out[#out + 1] = { c.zone, text }
    end
  end
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
  local f, native = UI.Make("Frame", UIParent, "ButtonFrameTemplate", frameName)
  if S.blizzard and not native then
    f:Hide()
    f = CreateFrame("Frame", frameName .. "b", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    frameName = frameName .. "b"
  end
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
  elseif native then
    -- The client's window: title bar, border and close button come with it.
    if ButtonFrameTemplate_HidePortrait then ButtonFrameTemplate_HidePortrait(f) end
    if ButtonFrameTemplate_HideButtonBar then ButtonFrameTemplate_HideButtonBar(f) end
    if f.Inset then f.Inset:Hide() end -- replaced by one panel per column below
    if f.SetTitle then f:SetTitle(L.TITLE) elseif f.TitleText then f.TitleText:SetText(L.TITLE) end
    if f.CloseButton then f.CloseButton:SetScript("OnClick", function() f:Hide() end) end
  elseif S.blizzard and f.SetBackdrop then
    -- Same look from older client textures, for a client without the template.
    f:SetBackdrop({
      bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
      edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
      tile = true, tileSize = 32, edgeSize = 32, insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    UI.Text(f, { x = 20, y = 18 }, "GameFontNormal", c.title):SetText(L.TITLE)
  end

  -- Children go on `p`. With sunken panels (insets) it is a layer above them,
  -- so that the window's own texts are not covered by the panels.
  local p = f
  if S.insets then
    for _, r in ipairs(S.insets) do
      local inset, nativeInset = UI.Make("Frame", f, "InsetFrameTemplate")
      UI.Place(inset, f, r)
      if not nativeInset then
        local bg = inset:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0, 0, 0, 0.35)
      end
    end
    p = CreateFrame("Frame", nil, f)
    p:SetAllPoints()
    p:SetFrameLevel(f:GetFrameLevel() + 10)
  end

  if S.title then
    UI.Text(p, S.title, "GameFontNormalLarge", c.title, S.title.center and "CENTER" or "LEFT"):SetText(L.TITLE)
  end

  if not (native and f.CloseButton) then
    local r = S.blizzard and { x = S.W - 34, y = 8, w = 24, h = 24, text = "X" } or S.close
    local close = UI.Button(p, r, CLOSE or "Close", r.text ~= nil)
    if close.label then close.label:SetText(r.text) end
    close:SetScript("OnClick", function() f:Hide() end)
  end

  -- The client's search box brings its own magnifier, placeholder and clear
  -- button; otherwise they are built here.
  local search, nativeSearch = UI.Make("EditBox", p, "SearchBoxTemplate")
  UI.Place(search, p, S.search)
  search:SetAutoFocus(false)
  local hint, clear
  if nativeSearch then
    if search.Instructions then search.Instructions:SetText(L.SEARCH_PLACEHOLDER) end
  else
    search:SetFontObject("GameFontHighlightSmall")
    local sc = S.search.textColor or c.text
    search:SetTextColor(sc[1], sc[2], sc[3])
    search:SetTextInsets(6, S.search.padRight or 6, 0, 0)
    if c.control then
      local bg = search:CreateTexture(nil, "BACKGROUND")
      bg:SetAllPoints()
      bg:SetColorTexture(c.control[1], c.control[2], c.control[3], c.control[4])
    end
    -- Placeholder: shown while the field is empty and not being typed in.
    hint = search:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    hint:SetPoint("LEFT", 6, 0)
    hint:SetPoint("RIGHT", -(S.search.padRight or 6), 0)
    hint:SetJustifyH("LEFT")
    hint:SetTextColor(c.dim[1], c.dim[2], c.dim[3])
    hint:SetText(L.SEARCH_PLACEHOLDER)
    UI.Flat(hint)

    -- With text in the field, an X over the magnifier clears it.
    local sr = S.blizzard and { x = S.search.x + S.search.w - 22, y = S.search.y, w = 22, h = S.search.h, text = "X" }
      or S.searchClear
    clear = UI.Button(p, sr, L.CLEAR_SEARCH, sr.text ~= nil)
    if clear.label then clear.label:SetText(sr.text) end
    local cover = UI.Atlas(clear, "BACKGROUND", sr.face)
    if cover then cover:SetAllPoints() end
    clear:SetFrameLevel(search:GetFrameLevel() + 2)
    clear:SetScript("OnClick", function()
      search:SetText("")
      search:ClearFocus()
    end)
  end

  local function paintSearch()
    if not hint then return end
    local empty = search:GetText() == ""
    hint:SetShown(empty and not search:HasFocus())
    clear:SetShown(not empty)
  end
  -- Hooked, not set: the client's search box has its own handlers for these.
  search:HookScript("OnEditFocusGained", paintSearch)
  search:HookScript("OnEditFocusLost", paintSearch)

  search:SetText(ns.db.filters.search or "")
  search:SetScript("OnEscapePressed", search.ClearFocus)
  search:SetScript("OnEnterPressed", search.ClearFocus)
  search:HookScript("OnTextChanged", function(self)
    paintSearch()
    ns.db.filters.search = self:GetText()
    Window:Refresh()
  end)
  paintSearch()
  if S.search.label then
    local label = p:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    label:SetPoint("RIGHT", search, "LEFT", -8, 0)
    label:SetTextColor(c.header[1], c.header[2], c.header[3])
    label:SetText(L.SEARCH)
  end

  if S.themeButton then
    local function themeItems()
      local items = {}
      for name, theme in pairs(ns.Themes) do items[#items + 1] = { name, theme.label or name } end
      table.sort(items, function(a, b) return a[2] < b[2] end)
      return items
    end
    local isCurrent = function(name) return name == ns.themeName end
    local pick = function(name) Window:SetTheme(name) end
    local dd = UI.NativeDropdown(p, S.themeButton, themeItems, isCurrent, pick)
    if dd then
      local label = p:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
      label:SetPoint("RIGHT", dd, "LEFT", -6, 0)
      label:SetText(L.THEME)
    else
      local current = ns.Themes[ns.themeName]
      local themeButton = UI.Button(p, S.themeButton, L.THEME .. ": " .. (current.label or ns.themeName), true)
      themeButton:SetScript("OnClick", function(self)
        UI.OpenMenu(self, themeItems(), isCurrent, pick)
      end)
    end
  end

  local onChange = function() Window:Refresh() end
  local specs = {
    { L.FILTER_FAMILY, "family", familyOptions },
    { L.FILTER_ZONE, "zone", zoneOptions },
    { L.FILTER_LEVEL, "bucket", bucketOptions },
  }
  for i, spec in ipairs(specs) do
    newFilter(p, S.filters[i], spec[1], spec[2], spec[3], onChange)
  end

  newCheck(p, S.check, L.SHOW_UNTAMEABLE, ns.db.filters.showUntameable, function(on)
    ns.db.filters.showUntameable = on
    Window:Refresh()
  end)
  newCheck(p, S.check2, L.ONLY_LOCATED, ns.db.filters.onlyLocated, function(on)
    ns.db.filters.onlyLocated = on
    Window:Refresh()
  end)

  -- Back to the defaults. The window is rebuilt from them, so every control
  -- (menus, checkboxes, search) shows the reset state at once.
  local reset = UI.Button(p, S.resetButton, L.RESET_FILTERS, true)
  reset:SetScript("OnClick", function()
    ns.db.filters = ns.DefaultFilters()
    Window:SetTheme(ns.themeName)
  end)

  self.count = S.count and UI.Text(p, S.count, "GameFontDisableSmall", c.dim) or nil

  -- Footer credits, as in EAD Skill Preview: author, then the site in the accent color.
  if S.credits then
    UI.Text(p, S.credits, "GameFontDisableSmall", c.dim, "CENTER")
      :SetText(L.CREDITS:format(AUTHOR) .. "  •  |cff" .. c.tag .. SITE .. "|r")
  end

  ns.List:Create(p, S.list)
  ns.Detail:Create(p)
  ns.News:Create(p, S.list)

  self.frame = f
end

-- Switches theme in place: the window is rebuilt from the new theme, keeping
-- its position, whether it was open, and the pinned creature.
function Window:SetTheme(name)
  if not ns.Themes[name] then return false end
  ns.db.theme = ns.ApplyTheme(name)
  ns.Target:Refresh()
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
