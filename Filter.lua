local ADDON, ns = ...
local L = ns.L

-- Pure list logic: no frames here, so it can be checked by /beastcodex selftest.
local Filter = {}
ns.Filter = Filter

-- { {1,10}, {11,20}, ... } up to the highest level in the data.
function Filter.Buckets()
  local out = {}
  for lo = 1, ns.MaxLevel, 10 do out[#out + 1] = { lo, lo + 9 } end
  return out
end

local function sortedKeys(set)
  local out = {}
  for k in pairs(set) do out[#out + 1] = k end
  table.sort(out)
  return out
end

function Filter.Families()
  local set = {}
  for _, c in ipairs(ns.Creatures) do set[c.family] = true end
  return sortedKeys(set)
end

function Filter.Zones()
  local set = {}
  for _, c in ipairs(ns.Creatures) do if c.zone then set[c.zone] = true end end
  return sortedKeys(set)
end

local CLS_KEY = {
  rare = "RARE", elite = "ELITE", rareelite = "RAREELITE",
  spawned = "SPAWNED", spawnedelite = "SPAWNEDELITE",
}

-- Translated label for a creature's classification, or nil when it has none
-- (or one this version does not know: better no tag than an error).
function ns.ClsLabel(cls)
  local key = cls and CLS_KEY[cls]
  return key and L[key] or nil
end

-- An appearance's name in the client's language (Locales/LookNames.lua), else English.
function Filter.LookName(look)
  return ns.LookNames and ns.LookNames[look.name] or look.name
end

function Filter.FamilyName(family)
  return L["FAMILY_" .. family]
end

local function matches(c, f, lo, hi, search, canShow, nameOf, zoneLabel)
  if f.family and c.family ~= f.family then return false end
  if zoneLabel and ns.ZoneLabel(c) ~= zoneLabel then return false end
  if f.showUntameable == false and not c.tame then return false end
  if f.onlyLocated and not canShow(c) then return false end
  -- A level range matches a bucket when the two overlap. Unknown level matches no bucket.
  if lo and not (c.min and c.max and c.min <= hi and c.max >= lo) then return false end
  if search and not c.name:lower():find(search, 1, true) then
    local localName = nameOf and nameOf(c)
    if not (localName and localName:lower():find(search, 1, true)) then return false end
  end
  return true
end

-- Returns rows for the list: { header = "text" } or { creature = c }.
-- `creatures` must already be sorted by family and look (the generated data is).
-- A header is only emitted when a creature follows it.
-- `canShow(c)` says whether a creature can be put on the map; it defaults to
-- the map module's answer and exists so the rule can be checked on its own.
-- `nameOf(c)` gives the creature's name in the client's language, or nil; the
-- search then matches either that or the English name.
function Filter.Apply(creatures, f, looks, canShow, nameOf)
  looks = looks or ns.Looks
  canShow = canShow or ns.Map.CanShow
  local lo, hi
  if f.bucket then lo, hi = (f.bucket - 1) * 10 + 1, f.bucket * 10 end
  local search = f.search and f.search ~= "" and f.search:lower() or nil

  -- Sub-areas of one map (Deathknell, Venomweb Vale...) are shown under the
  -- map's name, so the zone filter compares that name, not the sub-area.
  local zoneLabel = f.zone
  for _, c in ipairs(creatures) do
    if f.zone and c.zone == f.zone then zoneLabel = ns.ZoneLabel(c) break end
  end

  local rows, count, lastGroup = {}, 0, nil
  for _, c in ipairs(creatures) do
    if matches(c, f, lo, hi, search, canShow, nameOf, zoneLabel) then
      local group = c.family .. "/" .. (c.look or "")
      if group ~= lastGroup then
        local look = c.look and looks[c.look]
        rows[#rows + 1] = { header = look and Filter.LookName(look) or Filter.FamilyName(c.family) }
        lastGroup = group
      end
      rows[#rows + 1] = { creature = c }
      count = count + 1
    end
  end
  return rows, count
end

-- Self-checks ---------------------------------------------------------------

local LOOKS = { black = { name = "Charcoal Black Wolf", family = "wolf" } }
local SAMPLE = {
  { id = 1, name = "Forest Spider", family = "spider", min = 5, max = 6, tame = true, zone = "Elwynn Forest" },
  { id = 2, name = "Snarler", family = "wolf", look = "black", min = 42, max = 42, tame = true, zone = "Feralas" },
  { id = 3, name = "Vilebranch Raiding Wolf", family = "wolf", look = "black", min = 50, max = 51, tame = true, zone = "The Hinterlands" },
  { id = 4, name = "Vilebranch Wolf Pup", family = "wolf", look = "black", min = 46, max = 47, tame = true, zone = "The Hinterlands" },
  { id = 5, name = "Shadow (Pet)", family = "wolf", look = "black", min = 30, max = 30, tame = false, zone = "Darnassus" },
  { id = 6, name = "Mystery", family = "wolf", tame = true },
}

local function ids(rows)
  local out = {}
  for _, r in ipairs(rows) do if r.creature then out[#out + 1] = r.creature.id end end
  return table.concat(out, ",")
end

local function headers(rows)
  local out = {}
  for _, r in ipairs(rows) do if r.header then out[#out + 1] = r.header end end
  return table.concat(out, "|")
end

local function apply(f) return Filter.Apply(SAMPLE, f, LOOKS) end

local function test(name, fn) table.insert(ns.tests, { "filter: " .. name, fn }) end

test("no filters returns everything with headers", function()
  local rows, count = apply({ showUntameable = true, search = "" })
  assert(count == 6 and ids(rows) == "1,2,3,4,5,6", ids(rows))
  assert(headers(rows) == L.FAMILY_spider .. "|" .. Filter.LookName(LOOKS.black) .. "|" .. L.FAMILY_wolf, headers(rows))
end)

test("level buckets match by overlap", function()
  assert(ids(apply({ bucket = 5 })) == "2,3,4", ids(apply({ bucket = 5 })))   -- 41-50
  assert(ids(apply({ bucket = 6 })) == "3")                                      -- 51-60
  assert(ids(apply({ bucket = 4 })) == "")                                       -- 31-40
  assert(ids(apply({ bucket = 1 })) == "1")
end)

test("unknown level matches no bucket but shows without one", function()
  assert(not ids(apply({ bucket = 3 })):find("6"))
  assert(ids(apply({})):find("6"))
end)

test("hiding untameable removes them", function()
  assert(ids(apply({ showUntameable = false })) == "1,2,3,4,6")
end)

test("a header with no visible creature is not emitted", function()
  local rows = apply({ family = "spider" })
  assert(headers(rows) == L.FAMILY_spider and ids(rows) == "1")
  rows = apply({ zone = "Darnassus", showUntameable = false })
  assert(#rows == 0)
end)

test("sub-areas of one map count as the same zone", function()
  local list = {
    { id = 1, name = "A", family = "bat", tame = true, zone = "Deathknell", map = 1420 },
    { id = 2, name = "B", family = "bat", tame = true, zone = "Tirisfal Glades", map = 1420 },
    { id = 3, name = "C", family = "bat", tame = true, zone = "Feralas", map = 1444 },
  }
  local always = function() return true end
  assert(ids(Filter.Apply(list, { zone = "Deathknell" }, {}, always)) == "1,2")
  assert(ids(Filter.Apply(list, { zone = "Feralas" }, {}, always)) == "3")
end)

test("family and zone combine", function()
  assert(ids(apply({ family = "wolf", zone = "The Hinterlands" })) == "3,4")
  assert(ids(apply({ family = "spider", zone = "Feralas" })) == "")
end)

test("search is case-insensitive, substring, and treats pattern characters literally", function()
  assert(ids(apply({ search = "wolf pup" })) == "4")
  assert(ids(apply({ search = "(" })) == "5")
  assert(ids(apply({ search = "%" })) == "")
  assert(ids(apply({ search = "VILE" })) == "3,4")
end)

test("classification labels: known ones translate, unknown ones give no label", function()
  assert(ns.ClsLabel("rare") == L.RARE and ns.ClsLabel("rareelite") == L.RAREELITE)
  assert(ns.ClsLabel("spawned") == L.SPAWNED and ns.ClsLabel("spawnedelite") == L.SPAWNEDELITE)
  assert(ns.ClsLabel("bogus") == nil and ns.ClsLabel(nil) == nil)
end)

test("only-located keeps creatures that can be shown on the map", function()
  local even = function(c) return c.id % 2 == 0 end
  assert(ids(Filter.Apply(SAMPLE, { onlyLocated = true }, LOOKS, even)) == "2,4,6")
  assert(ids(Filter.Apply(SAMPLE, { onlyLocated = false }, LOOKS, even)) == "1,2,3,4,5,6")
  assert(ids(Filter.Apply(SAMPLE, { onlyLocated = true, family = "spider" }, LOOKS, even)) == "")
end)

test("search also matches the name in the client's language", function()
  local pt = { [2] = "Rosnador", [4] = "Filhote de Lobo Ramovil" }
  local nameOf = function(c) return pt[c.id] end
  local function found(text) return ids(Filter.Apply(SAMPLE, { search = text }, LOOKS, nil, nameOf)) end
  assert(found("rosna") == "2")
  assert(found("snarl") == "2")           -- English still works
  assert(found("filhote") == "4")
  assert(found("lobo") == "4")            -- only the one whose known name has it
  assert(ids(Filter.Apply(SAMPLE, { search = "rosna" }, LOOKS)) == "")  -- without names: English only
end)

test("look names: translated when the language has one, English otherwise", function()
  local old = ns.LookNames
  ns.LookNames = { ["Charcoal Black Wolf"] = "Lobo Preto Carvão" }
  local a, b = Filter.LookName({ name = "Charcoal Black Wolf" }), Filter.LookName({ name = "Tan Wolf" })
  ns.LookNames = nil
  local c = Filter.LookName({ name = "Tan Wolf" })
  ns.LookNames = old
  assert(a == "Lobo Preto Carvão" and b == "Tan Wolf" and c == "Tan Wolf")
end)

test("buckets cover the data's level range", function()
  local b = Filter.Buckets()
  assert(b[1][1] == 1 and b[1][2] == 10 and b[#b][2] >= ns.MaxLevel)
end)
