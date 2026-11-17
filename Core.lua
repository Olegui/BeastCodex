local ADDON, ns = ...
local L = ns.L

ns.tests = {} -- { name, fn } pairs run by /beastcodex selftest

local function defaults()
  return { minimap = {}, filters = { showUntameable = true, search = "" } }
end

-- Returns a usable settings table from whatever was saved: a missing table,
-- an older shape, or a filter value that no longer exists in the data.
function ns.SanitizeDB(db, creatures)
  local out = defaults()
  if type(db) ~= "table" then return out end
  if type(db.minimap) == "table" then out.minimap = db.minimap end

  local f = type(db.filters) == "table" and db.filters or {}
  local families, zones = {}, {}
  for _, c in ipairs(creatures) do
    families[c.family] = true
    if c.zone then zones[c.zone] = true end
  end
  if type(f.family) == "string" and families[f.family] then out.filters.family = f.family end
  if type(f.zone) == "string" and zones[f.zone] then out.filters.zone = f.zone end
  if type(f.bucket) == "number" and f.bucket >= 1 and f.bucket <= math.ceil(ns.MaxLevel / 10) then
    out.filters.bucket = math.floor(f.bucket)
  end
  if type(f.showUntameable) == "boolean" then out.filters.showUntameable = f.showUntameable end
  if type(f.search) == "string" then out.filters.search = f.search end
  return out
end

local function toggle()
  if ns.Window and ns.Window.Toggle then ns.Window:Toggle() end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, _, name)
  if name ~= ADDON then return end
  self:UnregisterEvent("ADDON_LOADED")

  BeastCodexDB = ns.SanitizeDB(BeastCodexDB, ns.Creatures)
  ns.db = BeastCodexDB

  local ldb = LibStub("LibDataBroker-1.1", true)
  local icon = LibStub("LibDBIcon-1.0", true)
  if ldb and icon then
    local obj = ldb:NewDataObject("BeastCodex", {
      type = "launcher",
      icon = "Interface\\Icons\\Ability_Hunter_BeastTaming",
      OnClick = toggle,
      OnTooltipShow = function(tip)
        tip:AddLine(L.TITLE)
        tip:AddLine(L.MINIMAP_HINT, 1, 1, 1)
      end,
    })
    icon:Register("BeastCodex", obj, ns.db.minimap)
  end
end)

SLASH_BEASTCODEX1 = "/beastcodex"
SlashCmdList.BEASTCODEX = function(msg)
  if msg and msg:lower():match("^%s*selftest") then
    if ns.RunSelfTest then ns.RunSelfTest() end
  else
    toggle()
  end
end

-- Self-checks ---------------------------------------------------------------

local sample = { { family = "wolf", zone = "Feralas" } }

table.insert(ns.tests, { "db: missing table gets defaults", function()
  local db = ns.SanitizeDB(nil, sample)
  assert(db.filters.showUntameable == true and db.filters.search == "" and type(db.minimap) == "table")
end })

table.insert(ns.tests, { "db: stale or wrongly typed filters are dropped", function()
  local db = ns.SanitizeDB({ filters = { family = "dragon", zone = 5, bucket = "x", showUntameable = "no", search = {} } }, sample)
  assert(db.filters.family == nil and db.filters.zone == nil and db.filters.bucket == nil)
  assert(db.filters.showUntameable == true and db.filters.search == "")
end })

table.insert(ns.tests, { "db: valid filters survive", function()
  local db = ns.SanitizeDB({ minimap = { hide = true }, filters = { family = "wolf", zone = "Feralas", bucket = 2, showUntameable = false, search = "sn" } }, sample)
  assert(db.filters.family == "wolf" and db.filters.zone == "Feralas" and db.filters.bucket == 2)
  assert(db.filters.showUntameable == false and db.filters.search == "sn" and db.minimap.hide == true)
end })

table.insert(ns.tests, { "locale: unknown key falls back to the key", function()
  assert(L.NO_SUCH_KEY == "NO_SUCH_KEY" and L.TITLE == "Beast Codex")
end })
