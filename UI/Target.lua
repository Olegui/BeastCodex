local ADDON, ns = ...
local L = ns.L

-- A small window of its own, apart from the codex: it stays open while you
-- travel, and its button targets the beast once it is in range. Targeting is
-- protected, so the button is a secure action button running /targetexact;
-- its macro can only be set out of combat.
local Target = {}
ns.Target = Target

function Target.Macro(name)
  return "/targetexact " .. name
end

-- Where everything goes, in window units. A theme with its own art for this
-- window (`targetArt`, measured on the source image) gets that art and the
-- button painted on it; others get a plain box.
function Target.Layout(S)
  local a = S.targetArt
  if not a then
    local W, H = 240, 92
    return { W = W, H = H, title = { x = 32, y = 11, w = W - 64 }, info = { x = 12, y = 30, w = W - 24 },
      close = { x = W - 28, y = 8, w = 20, h = 20 }, button = { x = 12, y = H - 38, w = W - 24, h = 26 } }
  end
  local k = a.W / a.srcW
  local function r(t) return { x = t[1] * k, y = t[2] * k, w = t[3] * k, h = t[4] and t[4] * k } end
  return { W = a.W, H = a.imgH * a.W / a.imgW, art = a, title = r(a.title), info = r(a.info),
    close = r(a.close), button = r(a.button) }
end

local function build()
  local S = ns.Skin
  local c = S.colors
  local lay = Target.Layout(S)
  local f = CreateFrame("Frame", nil, UIParent)
  f:SetSize(lay.W, lay.H)
  -- Where it was last left; the first time, beside the codex.
  local codex, pos = ns.Window.frame, ns.db.targetPos
  if pos then
    f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", pos[1], pos[2])
  elseif codex and codex:IsShown() then
    -- Placed on the screen, not anchored to the codex: it stays put when the codex moves or closes.
    f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", codex:GetRight() + 8, codex:GetTop())
  else
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
  end
  f:SetFrameStrata("DIALOG") -- above the codex (HIGH), never hidden behind it
  f:SetToplevel(true)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:SetClampedToScreen(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    ns.db.targetPos = { self:GetLeft(), self:GetTop() }
  end)

  local art = lay.art
  if art then
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(art.texture)
    bg:SetTexCoord(0, art.imgW / art.texW, 0, art.imgH / art.texH)
  else
    ns.UI.Box(f, true)
  end

  f.title = ns.UI.Text(f, lay.title, "GameFontNormal", c.header, "CENTER")
  f.title:SetWordWrap(false)
  f.info = ns.UI.Text(f, lay.info, "GameFontHighlightSmall", c.text, "CENTER")
  f.info:SetWordWrap(false)
  -- A name or zone too long even in the smallest font is cut short; hovering shows it whole.
  f:SetScript("OnEnter", function(self)
    if not self.cut then return end
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText(self.fullTitle)
    GameTooltip:AddLine(self.fullInfo, 1, 1, 1, true)
    GameTooltip:Show()
  end)
  f:SetScript("OnLeave", function() GameTooltip:Hide() end)

  -- On the art the X is painted: the button is only its click area.
  local close
  if art then
    close = CreateFrame("Button", nil, f)
    ns.UI.Place(close, f, lay.close)
    close:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:SetText(CLOSE or "Close")
      GameTooltip:Show()
    end)
    close:SetScript("OnLeave", function() GameTooltip:Hide() end)
    ns.UI.RedGlow(close)
  else
    close = ns.UI.IconButton(f, lay.close.w, "close", CLOSE or "Close")
    ns.UI.Place(close, f, lay.close)
    ns.UI.RedGlow(close)
  end
  close:SetScript("OnClick", function()
    -- The window holds a secure button: it cannot be hidden in combat.
    if InCombatLockdown() then print("|cffd9ad5cBeast Codex|r: " .. L.TARGET_COMBAT) return end
    f:Hide()
    ns.db.targetOpen = nil
  end)

  -- On the art the button face is painted: only the label goes over it.
  local r = {}
  if art then
    r = { label = true, font = "GameFontNormalSmall", textColor = art.textColor }
  else
    for key, v in pairs(S.targetButton) do r[key] = v end
  end
  r.x, r.y, r.w, r.h = lay.button.x, lay.button.y, lay.button.w, lay.button.h
  f.button = ns.UI.Button(f, r, L.TARGET, true, "SecureActionButtonTemplate")
  if f.button.label then -- a long translation shrinks rather than spills over the button's rim
    ns.UI.Fit(f.button.label, L.TARGET, { r.font or "GameFontNormal", "GameFontNormalSmall", "GameFontNormalSmall2" },
      r.w - 12)
  end
  f.button:SetAttribute("type", "macro")
  f.button:RegisterForClicks("AnyUp", "AnyDown") -- fires whichever the client's key-down setting says
  f.theme = ns.themeName
  f:Hide()
  return f
end

-- Opens the window for creature `c`, or says why it cannot (in combat).
function Target:Open(c)
  if InCombatLockdown() then
    print("|cffd9ad5cBeast Codex|r: " .. L.TARGET_COMBAT)
    return false
  end
  if self.frame and self.frame.theme ~= ns.themeName then
    self.frame:Hide() -- built for another theme: build it again in the current one
    self.frame = nil
  end
  self.frame = self.frame or build()
  self.creature = c
  ns.db.targetOpen = c.id -- reopened after a reload
  local name = ns.LocalName(c)
  local f = self.frame
  local zone = ns.ZoneLabel(c)
  f.fullTitle, f.fullInfo = name, L.LEVEL_FMT:format(ns.LevelText(c)) .. (zone ~= "" and " • " .. zone or "")
  local big = f.title:GetWidth() > 150 and "GameFontNormalLarge" or "GameFontNormal"
  local cutTitle = ns.UI.Fit(f.title, f.fullTitle, { big, "GameFontNormal", "GameFontNormalSmall" })
  local cutInfo = ns.UI.Fit(f.info, f.fullInfo, { "GameFontHighlightSmall", "GameFontHighlightExtraSmall", "SystemFont_Tiny" })
  f.cut = cutTitle or cutInfo
  self.frame.button:SetAttribute("macrotext", Target.Macro(name))
  self.frame:Show()
  return true
end

-- After a theme change: an open window is built again in the new theme.
function Target:Refresh()
  if self.frame and self.frame:IsShown() and self.creature then self:Open(self.creature) end
end

-- At load: reopens the window left open before the reload, once out of combat
-- (its secure button cannot be made during combat).
function Target:Restore()
  local id = ns.db.targetOpen
  local c = id and ns.News.Creature(id)
  if not c then
    ns.db.targetOpen = nil
    return
  end
  if not InCombatLockdown() then
    self:Open(c)
    return
  end
  local wait = CreateFrame("Frame")
  wait:RegisterEvent("PLAYER_REGEN_ENABLED")
  wait:SetScript("OnEvent", function(w)
    w:UnregisterAllEvents()
    if ns.db.targetOpen == id then self:Open(c) end
  end)
end

-- Self-checks ---------------------------------------------------------------

table.insert(ns.tests, { "target: the macro names the beast exactly", function()
  assert(Target.Macro("Ta'shkal") == "/targetexact Ta'shkal")
end })

table.insert(ns.tests, { "target: long text shrinks first, is cut only past the smallest font", function()
  -- A string whose width is 8 per character in font "A", 6 in "B".
  local per = { A = 8, B = 6 }
  local function fs()
    local o = { font = "A", text = "" }
    function o:SetFontObject(f) for k, v in pairs(_G) do if v == f then self.font = k end end end
    function o:SetText(t) self.text = t end
    function o:GetStringWidth() return #self.text * per[self.font] end
    function o:GetWidth() return 60 end
    return o
  end
  _G.A, _G.B = {}, {}
  local a, b, c = fs(), fs(), fs()
  local cutA, cutB, cutC = ns.UI.Fit(a, "1234567", { "A", "B" }), ns.UI.Fit(b, "123456789", { "A", "B" }),
    ns.UI.Fit(c, "1234567890123", { "A", "B" })
  _G.A, _G.B = nil, nil
  assert(not cutA and a.font == "A", "fits in the large font")
  assert(not cutB and b.font == "B", "fits once smaller")
  assert(cutC and c.font == "B", "too long even small: cut, smallest font")
end })

table.insert(ns.tests, { "target: every theme lays the window out inside itself", function()
  for name, theme in pairs(ns.Themes) do
    local lay = Target.Layout(theme)
    for _, key in ipairs({ "title", "info", "close", "button" }) do
      local r = lay[key]
      if r then
        assert(r.x >= 0 and r.y >= 0 and r.x + (r.w or 0) <= lay.W and r.y + (r.h or 0) <= lay.H,
          name .. " target window: " .. key .. " outside the window")
      end
    end
  end
end })
