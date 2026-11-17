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
    if c.note then lines[#lines + 1] = "|cffaaaaaa" .. c.note .. "|r" end
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

local function showModel(model, c)
  -- A creature the client has not cached may fail to load: the panel still shows its text.
  pcall(function()
    model:ClearModel()
    model:SetCreature(c.id)
    model:SetFacing(0.5)
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
    self.mapButton:Hide()
    self.unknown:Hide()
    return
  end
  showModel(self.model, c)
  self.name:SetText(c.name)
  self.text:SetText(table.concat(Detail.Lines(c), "\n"))
  local can = ns.Map and ns.Map.CanShow and ns.Map.CanShow(c)
  self.mapButton:SetShown(can and true or false)
  self.unknown:SetShown(not can)
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
  if self.clearButton then
    self.clearButton:SetShown(ns.Map and ns.Map.HasPins and ns.Map.HasPins() or false)
  end
end

function Detail:Create(parent, x, y, width, height)
  local f = CreateFrame("Frame", nil, parent)
  f:SetPoint("TOPLEFT", x, y)
  f:SetSize(width, height)

  local model = CreateFrame("PlayerModel", nil, f)
  model:SetPoint("TOPLEFT")
  model:SetSize(width, 170)
  local angle = 0.5
  model:SetScript("OnUpdate", function(self, elapsed)
    angle = angle + elapsed * 0.6
    self:SetFacing(angle)
  end)
  self.model = model

  self.name = f:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  self.name:SetPoint("TOPLEFT", model, "BOTTOMLEFT", 0, -8)
  self.name:SetWidth(width)
  self.name:SetJustifyH("LEFT")

  self.text = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  self.text:SetPoint("TOPLEFT", self.name, "BOTTOMLEFT", 0, -6)
  self.text:SetWidth(width)
  self.text:SetJustifyH("LEFT")
  self.text:SetJustifyV("TOP")
  self.text:SetSpacing(3)

  local mapButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  mapButton:SetSize(width, 24)
  mapButton:SetPoint("BOTTOMLEFT", 0, 28)
  mapButton:SetText(L.SHOW_ON_MAP)
  mapButton:SetScript("OnClick", function()
    local c = self.shown
    if c and ns.Map and ns.Map.Show then
      self:Pin(c)
      ns.Map.Show(c)
      self:UpdateClearButton()
    end
  end)
  self.mapButton = mapButton

  self.unknown = f:CreateFontString(nil, "ARTWORK", "GameFontDisable")
  self.unknown:SetPoint("BOTTOMLEFT", 0, 34)
  self.unknown:SetWidth(width)
  self.unknown:SetJustifyH("LEFT")
  self.unknown:SetText(L.LOCATION_UNKNOWN)

  local clear = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  clear:SetSize(width, 22)
  clear:SetPoint("BOTTOMLEFT", 0, 0)
  clear:SetText(L.CLEAR_PINS)
  clear:SetScript("OnClick", function()
    if ns.Map and ns.Map.Clear then ns.Map.Clear() end
    self:UpdateClearButton()
  end)
  self.clearButton = clear

  self.frame = f
  ns.List.onEnter = function(c) self:Preview(c) end
  ns.List.onLeave = function() self:Preview(nil) end
  ns.List.onClick = function(c) self:Pin(c) end

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
