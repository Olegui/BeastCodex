-- Throwaway probe: answers what the Forever client supports. /bcprobe, then /reload.
local NPC, MAP_A, MAP_B = 5356, 1444, 1429 -- Snarler, Feralas, Elwynn Forest

local function has(path)
  local v = _G
  for part in path:gmatch("[^.]+") do
    if type(v) ~= "table" then return false end
    v = v[part]
  end
  return v ~= nil
end

local function mapInfo(id)
  if not has("C_Map.GetMapInfo") then return "no C_Map.GetMapInfo" end
  local ok, info = pcall(C_Map.GetMapInfo, id)
  if not ok then return "error: " .. tostring(info) end
  if not info then return "nil" end
  return { name = info.name, mapType = info.mapType, parent = info.parentMapID }
end

local model, tip

SLASH_BCPROBE1 = "/bcprobe"
SlashCmdList.BCPROBE = function()
  local r = {}
  BeastCodexProbeDB = r

  r.build = { GetBuildInfo() }
  r.locale = GetLocale()
  r.project = WOW_PROJECT_ID

  r.api = {}
  for _, p in ipairs({
    "C_Map.GetMapInfo", "C_Map.GetBestMapForUnit", "C_Map.GetAreaInfo",
    "C_Map.GetMapChildrenInfo", "WorldMapFrame", "OpenWorldMap",
    "WorldMapFrame.SetMapID", "ToggleWorldMap", "C_TooltipInfo.GetHyperlink",
    "UIDropDownMenu_Initialize", "MenuUtil.CreateContextMenu",
    "FauxScrollFrame_Update", "CreateScrollBoxListLinearView",
    "BackdropTemplateMixin", "C_AddOns.GetAddOnMetadata", "UISpecialFrames",
  }) do
    r.api[p] = has(p)
  end

  r.mapA, r.mapB = mapInfo(MAP_A), mapInfo(MAP_B)

  -- 3D model by creature ID
  r.model = {}
  local ok, err = pcall(function()
    model = model or CreateFrame("PlayerModel", nil, UIParent)
    model:SetSize(200, 200)
    model:SetPoint("CENTER")
    r.model.hasSetCreature = model.SetCreature ~= nil
    r.model.hasSetDisplayInfo = model.SetDisplayInfo ~= nil
    model:ClearModel()
    model:SetCreature(NPC)
    model:Show()
  end)
  r.model.created = ok
  r.model.err = not ok and tostring(err) or nil

  -- World map pin through HereBeDragons-Pins
  r.pin = {}
  ok, err = pcall(function()
    local pins = LibStub("HereBeDragons-Pins-2.0")
    local icon = CreateFrame("Frame", nil, UIParent)
    icon:SetSize(16, 16)
    local t = icon:CreateTexture(nil, "OVERLAY")
    t:SetAllPoints()
    t:SetTexture("Interface\\Minimap\\ObjectIconsAtlas")
    t:SetColorTexture(1, 0, 0, 1)
    pins:RemoveAllWorldMapIcons("BeastCodexProbe")
    pins:AddWorldMapIconMap("BeastCodexProbe", icon, MAP_A, 0.5, 0.5, 3)
    r.pin.icon = icon
  end)
  r.pin.added = ok
  r.pin.err = not ok and tostring(err) or nil

  -- Localized creature name through a hidden tooltip
  r.name = {}
  ok, err = pcall(function()
    tip = tip or CreateFrame("GameTooltip", "BeastCodexProbeTip", nil, "GameTooltipTemplate")
    tip:SetOwner(WorldFrame, "ANCHOR_NONE")
    tip:SetHyperlink(("unit:Creature-0-0-0-0-%d"):format(NPC))
  end)
  r.name.linked = ok
  r.name.err = not ok and tostring(err) or nil

  -- Model and tooltip data load asynchronously: read them 3 seconds later.
  C_Timer.After(3, function()
    if model then
      local okId, id = pcall(function()
        return model.GetModelFileID and model:GetModelFileID() or (model.GetModel and model:GetModel())
      end)
      r.model.file = okId and id or ("error: " .. tostring(id))
    end
    local line = _G.BeastCodexProbeTipTextLeft1
    r.name.text = line and line:GetText() or nil
    if r.pin.icon then
      r.pin.shownOnMap = r.pin.icon:IsShown()
      r.pin.icon = nil -- frames cannot be saved
    end
    r.done = true
    print("|cff66cc66BeastCodexProbe:|r done. model=" .. tostring(r.model.file)
      .. " name=" .. tostring(r.name.text) .. " pin=" .. tostring(r.pin.added)
      .. ". Open the map on Feralas, take a look, then /reload.")
  end)
  print("|cff66cc66BeastCodexProbe:|r running, wait 3 seconds...")
end
