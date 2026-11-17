local ADDON, ns = ...

-- World map pins for one creature at a time, through HereBeDragons-Pins.
local Map = {}
ns.Map = Map

local pool, used, current = {}, 0, nil

-- Whether the client knows this uiMapID. Asking the world map to show an
-- unknown ID breaks the map for the rest of the session, so check first.
function Map.IsValidMap(id)
  if not (C_Map and C_Map.GetMapInfo) then return false end
  local ok, info = pcall(C_Map.GetMapInfo, id)
  return ok and info ~= nil
end

-- True when there is somewhere to put pins: a map the client knows and at least one x,y pair.
function Map.CanShow(c)
  return c ~= nil and c.map ~= nil and type(c.coords) == "table" and #c.coords >= 2
    and Map.IsValidMap(c.map)
end

function Map.HasPins()
  return used > 0
end

local function pinsLib()
  return LibStub and LibStub("HereBeDragons-Pins-2.0", true)
end

local function acquire()
  used = used + 1
  local pin = pool[used]
  if not pin then
    pin = CreateFrame("Frame", nil, UIParent)
    pin:SetSize(14, 14)
    local t = pin:CreateTexture(nil, "OVERLAY")
    t:SetAllPoints()
    t:SetTexture("Interface\\COMMON\\Indicator-Yellow")
    pin:SetScript("OnEnter", function(self)
      if not current then return end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText(ns.LocalName(current))
      GameTooltip:Show()
    end)
    pin:SetScript("OnLeave", function() GameTooltip:Hide() end)
    pool[used] = pin
  end
  return pin
end

function Map.Clear()
  local lib = pinsLib()
  if lib then lib:RemoveAllWorldMapIcons(ADDON) end
  for i = 1, used do pool[i]:Hide() end
  used, current = 0, nil
end

-- Puts a pin on every spawn point and opens the world map there.
-- Returns false when the creature has no usable location.
function Map.Show(c)
  if not Map.CanShow(c) then return false end
  local lib = pinsLib()
  if not lib then return false end
  Map.Clear()
  current = c
  for i = 1, #c.coords - 1, 2 do
    lib:AddWorldMapIconMap(ADDON, acquire(), c.map, c.coords[i] / 100, c.coords[i + 1] / 100, 3)
  end
  if WorldMapFrame then
    if not WorldMapFrame:IsShown() and ToggleWorldMap then ToggleWorldMap() end
    if WorldMapFrame.SetMapID then WorldMapFrame:SetMapID(c.map) end
  end
  return true
end

-- Self-checks ---------------------------------------------------------------

table.insert(ns.tests, { "map: CanShow needs a map and at least one coordinate pair", function()
  assert(Map.CanShow({ map = nil, coords = { 1, 2 } }) == false)
  assert(Map.CanShow({ map = 1444, coords = {} }) == false)
  assert(Map.CanShow({ map = 1444, coords = { 1 } }) == false)
  assert(Map.CanShow({ map = 1444 }) == false)
  assert(Map.CanShow(nil) == false)
  assert(Map.CanShow({ map = 1444, coords = { 1, 2 } }) == true)
end })

table.insert(ns.tests, { "map: a map ID the client does not know cannot be shown", function()
  local old = Map.IsValidMap
  Map.IsValidMap = function(id) return id ~= 16593 end
  local bad = Map.CanShow({ map = 16593, coords = { 1, 2 } })
  local shown = Map.Show({ map = 16593, coords = { 1, 2 } })
  local good = Map.CanShow({ map = 1444, coords = { 1, 2 } })
  Map.IsValidMap = old
  assert(bad == false and shown == false and good == true)
end })

table.insert(ns.tests, { "map: Show refuses a creature without a location", function()
  assert(Map.Show({ map = nil, coords = {} }) == false)
end })
