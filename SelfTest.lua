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

-- /beastcodex modelscan: diagnostic for creatures that show no 3D model.
-- Pass 1 asks the client for every creature's model (which also warms its
-- cache); after a pause, pass 2 asks again and records what the client
-- reports for each. The result is saved for reading after a /reload.
function ns.RunModelScan()
  if ns.modelScanRunning then return end
  ns.modelScanRunning = true
  local list = ns.Creatures
  local model = CreateFrame("PlayerModel", nil, UIParent)
  model:SetSize(64, 64)
  model:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)
  model:SetAlpha(0.02) -- nearly invisible, but shown so the client loads it

  local result = {
    total = #list, missing = {}, sample = {}, at = date("%Y-%m-%d %H:%M:%S"),
    api = { GetModelFileID = model.GetModelFileID ~= nil, GetDisplayInfo = model.GetDisplayInfo ~= nil },
  }
  local function read()
    local okF, file = pcall(function() return model.GetModelFileID and model:GetModelFileID() end)
    local okD, display = pcall(function() return model.GetDisplayInfo and model:GetDisplayInfo() end)
    return okF and file or nil, okD and display or nil
  end
  local function say(text) print("|cff66cc66Beast Codex|r modelscan: " .. text) end

  local function pass2()
    local i, pending = 0, nil
    C_Timer.NewTicker(0.08, function(ticker)
      if pending then
        local file, display = read()
        local known = (file and file ~= 0) or (display and display ~= 0)
        if not known then result.missing[#result.missing + 1] = pending.id end
        if #result.sample < 12 then
          result.sample[#result.sample + 1] = { id = pending.id, file = file or false, display = display or false }
        end
        pending = nil
      end
      i = i + 1
      local c = list[i]
      if not c then
        ticker:Cancel()
        model:Hide()
        ns.db.modelscan = result
        ns.modelScanRunning = nil
        say(("done. %d of %d creatures reported no model. /reload to save the result."):format(#result.missing, result.total))
        return
      end
      pcall(function() model:ClearModel() model:SetCreature(c.id) end)
      pending = c
      if i % 100 == 0 then say(("checking %d of %d..."):format(i, #list)) end
    end)
  end

  say(("requesting %d models, this takes about two minutes..."):format(#list))
  local i = 0
  C_Timer.NewTicker(0.04, function(ticker)
    i = i + 1
    local c = list[i]
    if not c then
      ticker:Cancel()
      C_Timer.After(5, pass2)
      return
    end
    pcall(function() model:ClearModel() model:SetCreature(c.id) end)
  end)
end
