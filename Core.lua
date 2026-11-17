local ADDON, ns = ...
local L = ns.L

ns.tests = {} -- { name, fn } pairs run by /beastcodex selftest

local function defaults()
  return { minimap = {}, theme = "classic", filters = { showUntameable = true, search = "" } }
end

-- Returns a usable settings table from whatever was saved: a missing table,
-- an older shape, or a filter value that no longer exists in the data.
function ns.SanitizeDB(db, creatures)
  local out = defaults()
  if type(db) ~= "table" then return out end
  if type(db.minimap) == "table" then out.minimap = db.minimap end
  if type(db.theme) == "string" and ns.Themes[db.theme] then out.theme = db.theme end
  -- Diagnostic results are kept so they survive any number of reloads until read.
  if type(db.selftest) == "table" then out.selftest = db.selftest end
  if type(db.modelscan) == "table" then out.modelscan = db.modelscan end

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
  ns.ApplyTheme(ns.db.theme)

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
  msg = (msg or ""):lower()
  local theme = msg:match("^%s*theme%s*(%S*)")
  if msg:match("^%s*selftest") then
    if ns.RunSelfTest then ns.RunSelfTest() end
  elseif msg:match("^%s*modelscan") then
    if ns.RunModelScan then ns.RunModelScan() end
  elseif theme then
    -- The window is built once per session, so a theme change reloads the UI.
    if ns.Themes[theme] then
      ns.db.theme = theme
      ReloadUI()
    else
      local names = {}
      for name in pairs(ns.Themes) do names[#names + 1] = name end
      table.sort(names)
      print("|cff66cc66Beast Codex|r " .. L.THEME_LIST_FMT:format(ns.themeName, table.concat(names, ", ")))
    end
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

table.insert(ns.tests, { "db: unknown theme falls back to classic, known theme survives", function()
  assert(ns.SanitizeDB({ theme = "nope" }, sample).theme == "classic")
  assert(ns.SanitizeDB({ theme = 5 }, sample).theme == "classic")
  assert(ns.SanitizeDB({ theme = "classic" }, sample).theme == "classic")
  for name in pairs(ns.Themes) do assert(ns.SanitizeDB({ theme = name }, sample).theme == name) end
end })

table.insert(ns.tests, { "theme: art measurements scale from source pixels to window units", function()
  local t = ns.ArtTheme({ srcW = 2000, srcH = 1000, W = 1000, rowH = 20, colors = { text = { 1, 1, 1 } },
    list = { x = 100, y = 50, w = 200, h = 20 },
    filters = { { x = 10, y = 20, w = 30, h = 40, label = { x = 2, y = 4 } } },
    check = { x = 8, y = 8, w = 16, h = 16, labelW = 100 } })
  assert(t.W == 1000 and t.H == 500 and t.rowH == 20)
  assert(t.list.x == 50 and t.list.y == 25 and t.list.w == 100 and t.list.h == 10)
  assert(t.filters[1].h == 20 and t.filters[1].label.x == 1 and t.filters[1].label.y == 2)
  assert(t.check.labelW == 50 and t.colors.text[1] == 1)
end })

table.insert(ns.tests, { "theme: every theme defines every rectangle the window needs", function()
  for name, t in pairs(ns.Themes) do
    for _, key in ipairs({ "search", "close", "check", "list", "model", "name", "text", "mapButton", "clearButton" }) do
      assert(type(t[key]) == "table" and t[key].x and t[key].y, name .. " lacks " .. key)
    end
    assert(#t.filters == 3, name .. " needs 3 filters")
    assert(t.W and t.H and t.rowH and t.list.h >= t.rowH, name .. " size")
    for _, key in ipairs({ "text", "header", "dim", "title", "hover", "selected" }) do
      assert(type(t.colors[key]) == "table", name .. " lacks color " .. key)
    end
    assert(type(t.colors.tag) == "string" and #t.colors.tag == 6, name .. " tag color")
    if t.texture then
      assert(t.imgW and t.imgH and t.texW and t.texH, name .. " texture size")
      -- A path with single backslashes loses them silently and the art never loads.
      assert(t.texture:find("^Interface\\AddOns\\BeastCodex\\Art\\%w+$"), name .. " texture path: " .. t.texture)
    end
    if t.rowArt then
      assert(t.rowArt.texture:find("^Interface\\AddOns\\BeastCodex\\Art\\%w+$"), name .. " row art path")
    end
  end
end })

table.insert(ns.tests, { "db: diagnostic results survive a reload", function()
  local db = ns.SanitizeDB({ modelscan = { total = 3 }, selftest = { passed = 1 }, junk = { 1 } }, sample)
  assert(db.modelscan.total == 3 and db.selftest.passed == 1 and db.junk == nil)
  assert(ns.SanitizeDB({ modelscan = "x" }, sample).modelscan == nil)
end })

table.insert(ns.tests, { "locale: unknown key falls back to the key", function()
  assert(L.NO_SUCH_KEY == "NO_SUCH_KEY" and L.TITLE == "Beast Codex")
end })
