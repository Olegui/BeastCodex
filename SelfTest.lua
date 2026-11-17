local ADDON, ns = ...

-- /beastcodex selftest: runs every registered check and saves the failures,
-- so the result can be read from SavedVariables after a /reload.
function ns.RunSelfTest()
  local failures, passed = {}, 0
  for _, t in ipairs(ns.tests) do
    local ok, err = pcall(t[2])
    if ok then passed = passed + 1 else failures[#failures + 1] = t[1] .. ": " .. tostring(err) end
  end
  if ns.db then
    ns.db.selftest = { passed = passed, total = #ns.tests, failures = failures, at = date("%Y-%m-%d %H:%M:%S") }
  end
  print("|cff66cc66Beast Codex|r " .. ns.L.SELFTEST_FMT:format(passed, #ns.tests))
  for _, f in ipairs(failures) do print("  |cffff5555" .. f .. "|r") end
end
