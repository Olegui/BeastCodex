local ADDON, ns = ...

-- English is the fallback: other locale files only overwrite keys.
-- A missing key shows as its own name instead of nil.
ns.L = setmetatable({
  TITLE = "Beast Codex",
  MINIMAP_HINT = "Click to open the codex.",
  THEME_LIST_FMT = "theme: %s. Available: %s. Use /beastcodex theme <name>.",
  SELFTEST_FMT = "self-test: %d of %d passed.",

  FILTER_FAMILY = "Family", FILTER_ZONE = "Zone", FILTER_LEVEL = "Level",
  ALL = "All", SEARCH = "Search",
  SHOW_UNTAMEABLE = "Show untameable",
  COUNT_FMT = "%d of %d beasts",
  NO_RESULTS = "No beasts match these filters.",
  RARE = "Rare", ELITE = "Elite", RAREELITE = "Rare Elite",
  SPAWNED = "Spawned", SPAWNEDELITE = "Spawned Elite",
  UNTAMEABLE = "Cannot be tamed",
  HOVER_HINT = "Hover a beast to preview it. Click to pin it.",
  LEVEL_FMT = "Level %s",
  LEVEL_UNKNOWN = "??",
  TEACHES_FMT = "Teaches: %s",
  ATTACK_SPEED_FMT = "Attack speed: %.1f",
  DIET_FMT = "Diet: %s",
  SHOW_ON_MAP = "Show on map",
  CLEAR_PINS = "Clear pins",
  LOCATION_UNKNOWN = "Location unknown",

  FAMILY_bat = "Bat", FAMILY_bear = "Bear", FAMILY_birdofprey = "Bird of Prey",
  FAMILY_boar = "Boar", FAMILY_carrionbird = "Carrion Bird", FAMILY_cat = "Cat",
  FAMILY_corehound = "Core Hound", FAMILY_crab = "Crab", FAMILY_crocolisk = "Crocolisk",
  FAMILY_fox = "Fox", FAMILY_gorilla = "Gorilla", FAMILY_hyena = "Hyena",
  FAMILY_raptor = "Raptor", FAMILY_scorpid = "Scorpid", FAMILY_spider = "Spider",
  FAMILY_tallstrider = "Tallstrider", FAMILY_turtle = "Turtle",
  FAMILY_windserpent = "Wind Serpent", FAMILY_wolf = "Wolf",
}, { __index = function(_, key) return key end })
