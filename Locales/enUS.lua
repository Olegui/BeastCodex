local ADDON, ns = ...

-- English is the fallback: other locale files only overwrite keys.
-- A missing key shows as its own name instead of nil.
ns.L = setmetatable({
  TITLE = "Beast Codex",
  MINIMAP_HINT = "Click to open the codex.",
  SELFTEST_FMT = "self-test: %d of %d passed.",

  FAMILY_bat = "Bat", FAMILY_bear = "Bear", FAMILY_birdofprey = "Bird of Prey",
  FAMILY_boar = "Boar", FAMILY_carrionbird = "Carrion Bird", FAMILY_cat = "Cat",
  FAMILY_corehound = "Core Hound", FAMILY_crab = "Crab", FAMILY_crocolisk = "Crocolisk",
  FAMILY_fox = "Fox", FAMILY_gorilla = "Gorilla", FAMILY_hyena = "Hyena",
  FAMILY_raptor = "Raptor", FAMILY_scorpid = "Scorpid", FAMILY_spider = "Spider",
  FAMILY_tallstrider = "Tallstrider", FAMILY_turtle = "Turtle",
  FAMILY_windserpent = "Wind Serpent", FAMILY_wolf = "Wolf",
}, { __index = function(_, key) return key end })
