local ADDON, ns = ...
local L = ns.L

ns.tests = {} -- { name, fn } pairs run by /beastcodex selftest

-- Filters as a new player has them: everything shown, nothing searched.
function ns.DefaultFilters()
  return { showUntameable = true, onlyLocated = false, search = "" }
end

local function defaults()
  return { minimap = {}, theme = ns.DEFAULT_THEME, filters = ns.DefaultFilters() }
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
  if type(db.names) == "table" then out.names = db.names end
  if db.modelPaused == true then out.modelPaused = true end
  if db.newsCollapsed == true then out.newsCollapsed = true end
  local pos = db.targetPos
  if type(pos) == "table" and type(pos[1]) == "number" and type(pos[2]) == "number" then
    out.targetPos = { pos[1], pos[2] }
  end
  if type(db.targetOpen) == "number" then out.targetOpen = db.targetOpen end

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
  if type(f.onlyLocated) == "boolean" then out.filters.onlyLocated = f.onlyLocated end
  if type(f.search) == "string" then out.filters.search = f.search end
  return out
end

-- Creature names in the data are English. The client knows each creature's
-- name in its own language and gives it for a creature link, fetching it
-- from the server the first time it is asked (so the first answer can be
-- empty). Names are cached per session; English is the fallback.
local localNames = {}

local function clientName(id)
  local link = ("unit:Creature-0-0-0-0-%d-0000000000"):format(id)
  if not (C_TooltipInfo and C_TooltipInfo.GetHyperlink) then return nil end
  local ok, data = pcall(C_TooltipInfo.GetHyperlink, link)
  local line = ok and type(data) == "table" and data.lines and data.lines[1]
  local text = line and line.leftText
  if type(text) == "string" and text ~= "" then return text end
  return nil
end

-- Names saved by an earlier session, usable only for the same client language
-- and build (a patch can rename creatures). Anything else starts empty.
function ns.NameCache(saved, locale, build)
  local names = {}
  if type(saved) == "table" and saved.locale == locale and saved.build == build
    and type(saved.names) == "table" then
    for id, name in pairs(saved.names) do
      if type(id) == "number" and type(name) == "string" and name ~= "" then names[id] = name end
    end
  end
  return names
end

-- The name already fetched for this creature, or nil. Never asks the client.
function ns.KnownLocalName(c)
  return localNames[c.id]
end

-- The creature's name in the client's language when available, else English.
function ns.LocalName(c)
  local name = localNames[c.id]
  if name then return name end
  name = clientName(c.id)
  if name then localNames[c.id] = name end
  return name or c.name
end

local function toggle()
  if ns.Window and ns.Window.Toggle then ns.Window:Toggle() end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, _, name)
  if name ~= ADDON then return end
  self:UnregisterEvent("ADDON_LOADED")

  local saved = BeastCodexDB
  BeastCodexDB = ns.SanitizeDB(saved, ns.Creatures)
  ns.db = BeastCodexDB
  -- Names fetched in earlier sessions come back at once; new ones are added
  -- to the same table, which is what gets saved.
  local locale, build = GetLocale(), select(2, GetBuildInfo())
  localNames = ns.NameCache(type(saved) == "table" and saved.nameCache, locale, build)
  ns.db.nameCache = { locale = locale, build = build, names = localNames }
  ns.ApplyTheme(ns.db.theme)

  local ldb = LibStub("LibDataBroker-1.1", true)
  local icon = LibStub("LibDBIcon-1.0", true)
  if ldb and icon then
    local obj = ldb:NewDataObject("BeastCodex", {
      type = "launcher",
      icon = "Interface\\AddOns\\BeastCodex\\Art\\Icon",
      OnClick = toggle,
      OnTooltipShow = function(tip)
        tip:AddLine(L.TITLE)
        tip:AddLine(L.MINIMAP_HINT, 1, 1, 1)
      end,
    })
    icon:Register("BeastCodex", obj, ns.db.minimap)
  end
  ns.Target:Restore()
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
    if not ns.Window:SetTheme(theme) then
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

table.insert(ns.tests, { "db: unknown theme falls back to the default, known theme survives", function()
  assert(ns.Themes[ns.DEFAULT_THEME], "default theme must exist")
  assert(ns.SanitizeDB({ theme = "nope" }, sample).theme == ns.DEFAULT_THEME)
  assert(ns.SanitizeDB({ theme = 5 }, sample).theme == ns.DEFAULT_THEME)
  assert(ns.SanitizeDB(nil, sample).theme == ns.DEFAULT_THEME)
  assert(ns.SanitizeDB({ filters = { onlyLocated = true } }, sample).filters.onlyLocated == true)
  assert(ns.SanitizeDB({ filters = { onlyLocated = "x" } }, sample).filters.onlyLocated == false)
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
    for _, key in ipairs({ "search", "searchClear", "close", "check", "check2", "resetButton", "themeButton", "credits", "list", "model", "name", "text",
                           "mapButton", "clearButton" }) do
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
      for piece, p in pairs(t.rowArt.faces) do
        assert(p[1] >= 0 and p[2] >= 0 and p[1] + p[3] <= t.rowArt.texW and p[2] + p[4] <= t.rowArt.texH,
          name .. " atlas piece out of bounds: " .. piece)
      end
      for _, key in ipairs({ "themeButton", "mapButton", "clearButton", "resetButton", "targetButton" }) do
        for _, field in ipairs({ "face", "offFace" }) do
          local piece = t[key][field]
          assert(piece == nil or t.rowArt.faces[piece], name .. "." .. key .. " names a missing atlas piece")
        end
      end
    end
  end
end })

table.insert(ns.tests, { "db: diagnostic results survive a reload", function()
  local db = ns.SanitizeDB({ modelscan = { total = 3 }, selftest = { passed = 1 }, junk = { 1 } }, sample)
  assert(db.modelscan.total == 3 and db.selftest.passed == 1 and db.junk == nil)
  assert(ns.SanitizeDB({ modelscan = "x" }, sample).modelscan == nil)
end })

table.insert(ns.tests, { "db: model pause and collapsed news survive a reload", function()
  local db = ns.SanitizeDB({ modelPaused = true, newsCollapsed = true }, sample)
  assert(db.modelPaused == true and db.newsCollapsed == true)
  db = ns.SanitizeDB({ modelPaused = "yes" }, sample)
  assert(db.modelPaused == nil and db.newsCollapsed == nil)
  assert(ns.SanitizeDB({ targetPos = { 120, 640 } }, sample).targetPos[2] == 640)
  assert(ns.SanitizeDB({ targetPos = { "a", 640 } }, sample).targetPos == nil)
  assert(ns.SanitizeDB({ targetOpen = 268231 }, sample).targetOpen == 268231)
  assert(ns.SanitizeDB({ targetOpen = "x" }, sample).targetOpen == nil)
end })

table.insert(ns.tests, { "names: client name when it answers, English otherwise, never an error", function()
  local old = C_TooltipInfo
  C_TooltipInfo = { GetHyperlink = function(link)
    if link == "unit:Creature-0-0-0-0-910001-0000000000" then return { lines = { { leftText = "Rosnador" } } } end
    if link == "unit:Creature-0-0-0-0-910002-0000000000" then return { lines = {} } end
    if link == "unit:Creature-0-0-0-0-910003-0000000000" then return { lines = { { leftText = "" } } } end
    error("boom")
  end }
  local a, b, c, d = { id = 910001, name = "Snarler" }, { id = 910002, name = "Pending" },
    { id = 910003, name = "Empty" }, { id = 910004, name = "Broken" }
  local got = { ns.LocalName(a), ns.LocalName(b), ns.LocalName(c), ns.LocalName(d) }
  local known = { ns.KnownLocalName(a), ns.KnownLocalName(b) }
  C_TooltipInfo = nil
  local without = ns.LocalName({ id = 910005, name = "NoApi" })
  C_TooltipInfo = old
  assert(got[1] == "Rosnador" and got[2] == "Pending" and got[3] == "Empty" and got[4] == "Broken")
  assert(known[1] == "Rosnador" and known[2] == nil and without == "NoApi")
end })

table.insert(ns.tests, { "names: saved names are reused only for the same language and build", function()
  local saved = { locale = "ptBR", build = "70959", names = { [5356] = "Rosnador", [30] = "", bad = "x", [7] = 12 } }
  local names = ns.NameCache(saved, "ptBR", "70959")
  assert(names[5356] == "Rosnador" and names[30] == nil and names.bad == nil and names[7] == nil)
  assert(next(ns.NameCache(saved, "deDE", "70959")) == nil)   -- other language
  assert(next(ns.NameCache(saved, "ptBR", "71000")) == nil)   -- other build
  assert(next(ns.NameCache(nil, "ptBR", "70959")) == nil)
  assert(next(ns.NameCache({ locale = "ptBR", build = "70959", names = "x" }, "ptBR", "70959")) == nil)
end })

table.insert(ns.tests, { "filters: defaults show everything and are a fresh table each time", function()
  local a, b = ns.DefaultFilters(), ns.DefaultFilters()
  assert(a ~= b and a.showUntameable == true and a.onlyLocated == false and a.search == "")
  assert(a.family == nil and a.zone == nil and a.bucket == nil)
end })

table.insert(ns.tests, { "locale: unknown key falls back to the key", function()
  assert(L.NO_SUCH_KEY == "NO_SUCH_KEY" and L.TITLE == "Beast Codex")
end })
