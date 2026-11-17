local ADDON, ns = ...
local L = ns.L

-- Right-hand panel: 3D model and facts for the hovered or pinned creature.
local Detail = { pinned = nil }
ns.Detail = Detail

-- The text lines for a creature. Kept apart from the frames so it can be checked.
function Detail.Lines(c)
  local lines = {}
  local head = ns.Filter.FamilyName(c.family) .. ", " .. L.LEVEL_FMT:format(ns.LevelText(c))
  local cls = ns.ClsLabel(c.cls)
  if cls then head = head .. ", " .. cls end
  lines[#lines + 1] = head
  local zone = ns.ZoneLabel(c)
  if zone ~= "" then lines[#lines + 1] = zone end
  if not c.tame then
    lines[#lines + 1] = "|cffff5555" .. L.UNTAMEABLE .. "|r"
    if c.note then lines[#lines + 1] = c.note end
  end
  if c.abilities and #c.abilities > 0 then
    local names = {}
    for i, a in ipairs(c.abilities) do names[i] = a[1] .. " " .. a[2] end
    lines[#lines + 1] = L.TEACHES_FMT:format(table.concat(names, ", "))
  end
  if c.speed then lines[#lines + 1] = L.ATTACK_SPEED_FMT:format(c.speed) end
  local diet = ns.FamilyDiet[c.family]
  if diet then lines[#lines + 1] = L.DIET_FMT:format(diet) end
  return lines
end

local function hasModel(model)
  local ok, display = pcall(function() return model.GetDisplayInfo and model:GetDisplayInfo() end)
  return ok and display ~= nil and display ~= 0
end

-- The client fetches a creature's appearance the first time it is asked for,
-- so the first request can come back empty (measured with /beastcodex
-- modelscan: every creature has a model once asked twice). Ask again shortly
-- after if nothing showed.
local function showModel(model, c)
  local function request()
    pcall(function()
      model:ClearModel()
      model:SetCreature(c.id)
      model:SetFacing(0.5)
    end)
  end
  request()
  for _, delay in ipairs({ 0.4, 1.2 }) do
    C_Timer.After(delay, function()
      if Detail.shown == c and not hasModel(model) then request() end
    end)
  end
end

-- Asks the client for every creature's appearance once per session, a few per
-- frame, so models are ready by the time a row is hovered.
function ns.Preload()
  if ns.preloadStarted then return end
  ns.preloadStarted = true
  local warm = CreateFrame("PlayerModel", nil, UIParent)
  warm:SetSize(32, 32)
  warm:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)
  warm:SetAlpha(0.02) -- nearly invisible, but shown so the client really loads it
  local i = 0
  C_Timer.NewTicker(0.04, function(ticker)
    i = i + 1
    local c = ns.Creatures[i]
    if not c then
      ticker:Cancel()
      warm:Hide()
      return
    end
    pcall(function() warm:ClearModel() warm:SetCreature(c.id) end)
  end)
end

function Detail:Show(c)
  if not self.frame then return end
  if self.shown == c then return end
  self.shown = c
  if not c then
    pcall(self.model.ClearModel, self.model)
    self.name:SetText("")
    self.text:SetText(L.HOVER_HINT)
    self.mapButton:SetActive(false)
    return
  end
  showModel(self.model, c)
  self.name:SetText(c.name)
  local lines = Detail.Lines(c)
  local can = ns.Map.CanShow(c)
  self.text:SetText(table.concat(lines, "\n"))
  self.mapButton:SetActive(can, L.LOCATION_UNAVAILABLE)
end

function Detail:Preview(c)
  self:Show(c or self.pinned)
end

function Detail:Pin(c)
  self.pinned = c
  ns.List:SetSelected(c)
  self:Show(c)
end

function Detail:UpdateClearButton()
  if self.clearButton then self.clearButton:SetShown(ns.Map.HasPins()) end
end

-- Builds the panel from the theme's rectangles, as children of the window.
function Detail:Create(parent)
  local S = ns.Skin
  local c = S.colors
  local UI = ns.UI

  local model = CreateFrame("PlayerModel", nil, parent)
  UI.Place(model, parent, S.model)
  local angle = 0.5
  model:SetScript("OnUpdate", function(self, elapsed)
    angle = angle + elapsed * 0.6
    self:SetFacing(angle)
  end)
  self.model = model

  self.name = UI.Text(parent, S.name, "GameFontNormalLarge", c.title, S.name.center and "CENTER" or "LEFT")
  self.name:SetWordWrap(false)
  self.text = UI.Text(parent, S.text, "GameFontHighlightSmall", c.text)
  self.text:SetSpacing(3)

  self.mapButton = UI.Button(parent, S.mapButton, L.SHOW_ON_MAP, S.mapButton.label)
  self.mapButton:SetScript("OnClick", function()
    local creature = self.shown
    if creature then
      self:Pin(creature)
      ns.Map.Show(creature)
      self:UpdateClearButton()
    end
  end)

  self.clearButton = UI.Button(parent, S.clearButton, L.CLEAR_PINS, S.clearButton.label)
  self.clearButton:SetScript("OnClick", function()
    ns.Map.Clear()
    self:UpdateClearButton()
  end)

  self.frame = parent
  ns.List.onEnter = function(creature) self:Preview(creature) end
  ns.List.onLeave = function() self:Preview(nil) end
  ns.List.onClick = function(creature) self:Pin(creature) end

  self.pinned = nil
  self.shown = false -- force the first Show(nil) to paint the hint
  self:Show(nil)
  self:UpdateClearButton()
end

-- Self-checks ---------------------------------------------------------------

table.insert(ns.tests, { "detail: lines for a tameable rare with abilities", function()
  local old = ns.FamilyDiet
  ns.FamilyDiet = { wolf = "Meat" }
  local t = table.concat(Detail.Lines({ name = "Snarler", family = "wolf", min = 42, max = 42, cls = "rare",
    zone = "Feralas", tame = true, speed = 2.0, abilities = { { "Bite", 6 }, { "Furious Howl", 3 } } }), "\n")
  ns.FamilyDiet = old
  -- Built from L so the check also holds on translated clients.
  local want = table.concat({
    L.FAMILY_wolf .. ", " .. L.LEVEL_FMT:format("42") .. ", " .. L.RARE,
    "Feralas",
    L.TEACHES_FMT:format("Bite 6, Furious Howl 3"),
    L.ATTACK_SPEED_FMT:format(2.0),
    L.DIET_FMT:format("Meat"),
  }, "\n")
  assert(t == want, t)
end })

table.insert(ns.tests, { "detail: missing fields produce no lines and no error", function()
  local old = ns.FamilyDiet
  ns.FamilyDiet = {}
  local lines = Detail.Lines({ name = "X", family = "bat", tame = false, note = "Friendly to Alliance players." })
  ns.FamilyDiet = old
  assert(#lines == 3, #lines)
  assert(lines[1] == L.FAMILY_bat .. ", " .. L.LEVEL_FMT:format(L.LEVEL_UNKNOWN), lines[1])
  assert(lines[2]:find(L.UNTAMEABLE, 1, true) and lines[3]:find("Friendly", 1, true))
end })

table.insert(ns.tests, { "data: every creature formats without error", function()
  for _, c in ipairs(ns.Creatures) do
    local ok, err = pcall(function()
      assert(type(Detail.Lines(c)[1]) == "string" and type(ns.LevelText(c)) == "string")
      assert(c.cls == nil or ns.ClsLabel(c.cls) ~= nil, "unknown classification " .. tostring(c.cls))
      assert(ns.Looks[c.look or ""] ~= nil or c.look == nil, "unknown look")
    end)
    if not ok then error(("creature %s (%s): %s"):format(tostring(c.id), tostring(c.name), tostring(err)), 0) end
  end
end })
