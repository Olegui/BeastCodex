local ADDON, ns = ...

-- English is the fallback: other locale files only overwrite keys.
-- A missing key shows as its own name instead of nil.
ns.L = setmetatable({
  TITLE = "Beast Codex",
  MINIMAP_HINT = "Click to open the codex.",
  SELFTEST_FMT = "self-test: %d of %d passed.",
}, { __index = function(_, key) return key end })
