local ADDON, ns = ...
local L = ns.L

-- Right-hand panel: 3D model and facts for the hovered or pinned creature.
local Detail = { pinned = nil }
ns.Detail = Detail

-- An ability's name as the client shows it, from one of its spells; English
-- when the client has no name for it.
function ns.AbilityName(name)
  local id = ns.AbilitySpell and ns.AbilitySpell[name]
  if not id then return name end
  local ok, text = pcall(function()
    if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
    return GetSpellInfo and (GetSpellInfo(id))
  end)
  return ok and type(text) == "string" and text ~= "" and text or name
end

-- A family's diet in the player's language. The data spells it in English,
-- separated by " - " or ",".
function ns.DietText(diet)
  local parts = {}
  for item in diet:gmatch("[^,%-]+") do
    item = item:match("^%s*(.-)%s*$")
    if item ~= "" then parts[#parts + 1] = L["DIET_" .. item:upper():gsub(" ", "_")] end
  end
  return table.concat(parts, ", ")
end

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
    for i, a in ipairs(c.abilities) do names[i] = ns.AbilityName(a[1]) .. " " .. a[2] end
    lines[#lines + 1] = L.TEACHES_FMT:format(table.concat(names, ", "))
  end
  if c.speed then lines[#lines + 1] = L.ATTACK_SPEED_FMT:format(c.speed) end
  local diet = ns.FamilyDiet[c.family]
  if diet then lines[#lines + 1] = L.DIET_FMT:format(ns.DietText(diet)) end
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
      -- Names were requested above; a moment later the client has them. Collect
      -- them, note how many came back (readable after a /reload), repaint.
      C_Timer.After(3, function()
        local known, sample = 0, {}
        for _, creature in ipairs(ns.Creatures) do
          local name = ns.LocalName(creature)
          if ns.KnownLocalName(creature) then
            known = known + 1
            if #sample < 5 and name ~= creature.name then sample[#sample + 1] = creature.name .. " = " .. name end
          end
        end
        ns.db.names = { known = known, total = #ns.Creatures, sample = sample, locale = GetLocale() }
        ns.Window:Refresh()
      end)
      return
    end
    pcall(function() warm:ClearModel() warm:SetCreature(c.id) end)
    ns.LocalName(c)
  end)
end

function Detail:Show(c)
  if not self.frame then return end
  if self.shown == c then return end
  self.shown = c
  self.rumor:SetShown(c and c.rumor or false)
  if not c then
    pcall(self.model.ClearModel, self.model)
    self.name:SetText("")
    self.text:SetText(L.HOVER_HINT)
    self.mapButton:SetActive(false, L.SELECT_BEAST) -- nothing to show on the map yet
    self.targetButton:SetActive(false)
    return
  end
  showModel(self.model, c)
  self.name:SetText(ns.LocalName(c))
  local lines = Detail.Lines(c)
  local can = ns.Map.CanShow(c)
  self.text:SetText(table.concat(lines, "\n"))
  self.mapButton:SetActive(can, L.LOCATION_UNAVAILABLE)
  self.targetButton:SetActive(true)
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
  -- Turns on its own unless paused; a held arrow button turns it by hand instead.
  local angle, turning = 0.5, 0
  model:SetScript("OnUpdate", function(self, elapsed)
    if turning ~= 0 then
      angle = angle + turning * elapsed * 2.5
    elseif not ns.db.modelPaused then
      angle = angle + elapsed * 0.6
    end
    self:SetFacing(angle)
  end)
  self.model = model

  -- Controls over the bottom of the model: turn left, play/pause, turn right.
  local size = math.floor(S.model.h * 0.13 + 0.5)
  local play = UI.IconButton(model, size, "pause", L.PAUSE)
  play:SetPoint("BOTTOM", 0, 6)
  local function paintPlay()
    local paused = ns.db.modelPaused
    UI.SetIcon(play.icon, paused and "play" or "pause")
    play.tooltip = paused and L.PLAY or L.PAUSE
  end
  play:SetScript("OnClick", function(b)
    ns.db.modelPaused = not ns.db.modelPaused
    paintPlay()
    if GameTooltip:IsOwned(b) then b:GetScript("OnEnter")(b) end
  end)
  paintPlay()
  for dir, spec in pairs({ [-1] = { "rotLeft", L.ROTATE_LEFT, "RIGHT", "LEFT" }, [1] = { "rotRight", L.ROTATE_RIGHT, "LEFT", "RIGHT" } }) do
    local b = UI.IconButton(model, size, spec[1], spec[2])
    b:SetPoint(spec[3], play, spec[4], dir * 8, 0)
    b:SetScript("OnMouseDown", function() turning = dir end)
    b:SetScript("OnMouseUp", function() turning = 0 end)
    b:SetScript("OnHide", function() turning = 0 end)
  end

  -- Top right of the model, only for a creature no data source confirms yet.
  self.rumor = UI.IconButton(model, size, "alert", L.RUMOR, { 1, 0.78, 0.25 })
  self.rumor:SetPoint("TOPRIGHT", -6, -6)
  self.rumor.tooltipText = L.RUMOR_TEXT
  self.rumor:Hide()

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

  self.targetButton = UI.Button(parent, S.targetButton, L.TARGET_WINDOW, S.targetButton.label)
  self.targetButton:SetScript("OnClick", function()
    if self.shown then ns.Target:Open(self.shown) end
  end)
  if S.text.h then self.text:SetHeight(S.text.h) end -- long notes stop above the target button

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
    L.DIET_FMT:format(L.DIET_MEAT),
  }, "\n")
  assert(t == want, t)
end })

table.insert(ns.tests, { "detail: diets and abilities in the player's language", function()
  assert(ns.DietText("Fruit - Fungus") == L.DIET_FRUIT .. ", " .. L.DIET_FUNGUS)
  assert(ns.DietText("Meat, Fish") == L.DIET_MEAT .. ", " .. L.DIET_FISH)
  assert(ns.DietText("Fish - Raw Fish") == L.DIET_FISH .. ", " .. L.DIET_RAW_FISH)
  local oldSpell, oldApi = ns.AbilitySpell, C_Spell
  ns.AbilitySpell = { Bite = 17253, Broken = 1 }
  C_Spell = { GetSpellName = function(id)
    if id == 17253 then return "Mordida" end
    error("unknown spell")
  end }
  local bite, broken, unknown = ns.AbilityName("Bite"), ns.AbilityName("Broken"), ns.AbilityName("Pinch")
  ns.AbilitySpell, C_Spell = oldSpell, oldApi
  assert(bite == "Mordida" and broken == "Broken" and unknown == "Pinch")
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
