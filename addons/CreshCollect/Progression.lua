local _, COL = ...
if not COL then return end

local CC = setmetatable({}, { __index = function(_, k)
    local c = _G.CreshChat
    return c and c[k]
end })

local Progression = {
    version = COL.version,
    stepYards = 0.75,
    pollInterval = 1.0,
}
COL.GameProgression = Progression
if COL.RegisterModule then COL:RegisterModule("GameProgression", Progression) end

local floor, max, sqrt = math.floor, math.max, math.sqrt
local lower = string.lower

local function now()
    if type(_G.GetServerTime) == "function" then return _G.GetServerTime() end
    if type(_G.time) == "function" then return _G.time() end
    if type(_G.GetTime) == "function" then return floor(_G.GetTime()) end
    return 0
end

local function mapIDForPlayer()
    if _G.C_Map and _G.C_Map.GetBestMapForUnit then
        local ok, mapID = pcall(_G.C_Map.GetBestMapForUnit, "player")
        if ok then return tonumber(mapID) end
    end
end

local function mapPosition(mapID)
    mapID = tonumber(mapID)
    if not mapID or not _G.C_Map or not _G.C_Map.GetPlayerMapPosition then return nil end
    local ok, point = pcall(_G.C_Map.GetPlayerMapPosition, mapID, "player")
    if not ok or not point then return nil end
    local x, y
    if point.GetXY then x, y = point:GetXY() else x, y = point.x, point.y end
    if not x or not y or (x == 0 and y == 0) then return nil end
    return x, y
end

local function currentAreaName()
    local subzone = type(_G.GetSubZoneText) == "function" and _G.GetSubZoneText() or ""
    local zone = type(_G.GetRealZoneText) == "function" and _G.GetRealZoneText() or (type(_G.GetZoneText) == "function" and _G.GetZoneText() or "")
    if subzone and subzone ~= "" then return subzone, zone end
    if zone and zone ~= "" then return zone, zone end
    return "Unknown Area", "Unknown Zone"
end

local function worldDistance(mapID, x1, y1, x2, y2)
    if _G.C_Map and _G.C_Map.GetWorldPosFromMapPos and _G.CreateVector2D then
        local ok1, continent1, world1 = pcall(_G.C_Map.GetWorldPosFromMapPos, mapID, _G.CreateVector2D(x1, y1))
        local ok2, continent2, world2 = pcall(_G.C_Map.GetWorldPosFromMapPos, mapID, _G.CreateVector2D(x2, y2))
        if ok1 and ok2 and world1 and world2 and continent1 == continent2 then
            local wx1, wy1, wx2, wy2
            if world1.GetXY then wx1, wy1 = world1:GetXY() else wx1, wy1 = world1.x, world1.y end
            if world2.GetXY then wx2, wy2 = world2:GetXY() else wx2, wy2 = world2.x, world2.y end
            if wx1 and wy1 and wx2 and wy2 then
                local dx, dy = wx2 - wx1, wy2 - wy1
                return sqrt(dx * dx + dy * dy)
            end
        end
    end
    local dx, dy = (x2 - x1) * 5000, (y2 - y1) * 3333
    return sqrt(dx * dx + dy * dy)
end

function Progression:Ensure()
    if not CreshCollectDB then return nil end
    CreshCollectDB.gameProgression = type(CreshCollectDB.gameProgression) == "table" and CreshCollectDB.gameProgression or {}
    local root = CreshCollectDB.gameProgression
    root.games = type(root.games) == "table" and root.games or {}
    root.exploration = type(root.exploration) == "table" and root.exploration or {}
    local exploration = root.exploration
    exploration.totalSteps = floor(max(0, tonumber(exploration.totalSteps) or 0))
    exploration.rewardedStepBlocks = floor(max(0, tonumber(exploration.rewardedStepBlocks) or 0))
    exploration.distanceRemainder = max(0, tonumber(exploration.distanceRemainder) or 0)
    exploration.visitedAreas = type(exploration.visitedAreas) == "table" and exploration.visitedAreas or {}
    exploration.visitedZones = type(exploration.visitedZones) == "table" and exploration.visitedZones or {}
    exploration.newAreas = floor(max(0, tonumber(exploration.newAreas) or 0))
    exploration.newZones = floor(max(0, tonumber(exploration.newZones) or 0))
    exploration.dungeonClears = floor(max(0, tonumber(exploration.dungeonClears) or 0))
    exploration.totalKills = floor(max(0, tonumber(exploration.totalKills) or 0))
    exploration.coins = floor(max(0, tonumber(exploration.coins) or 0))
    exploration.passXP = floor(max(0, tonumber(exploration.passXP) or 0))
    return root
end

-- Per-game level/XP tracking (Frogger, Chess, ...) moved to CreshGames/
-- GameProgression.lua (Phase 10) so game progress bars work without
-- CreshCollect installed. root.games above is kept populated only as the
-- one-time migration source CreshGames' Ensure() reads from.

function Progression:AwardExploration(coins, passXP, title, detail, showToast)
    coins = floor(max(0, tonumber(coins) or 0))
    passXP = floor(max(0, tonumber(passXP) or 0))
    local root = self:Ensure()
    if not root then return end
    local exploration = root.exploration
    if COL.BattlePass then
        if coins > 0 and COL.BattlePass.AddCoins then COL.BattlePass:AddCoins(coins, "EXPLORATION") end
        if passXP > 0 and COL.BattlePass.AddPassXP then COL.BattlePass:AddPassXP(passXP, "EXPLORATION", not showToast) end
    end
    exploration.coins = exploration.coins + coins
    exploration.passXP = exploration.passXP + passXP
    if showToast then
        COL:ShowGameToast(title or "Explorer Reward",
            tostring(detail or "") .. " · +" .. coins .. " Cresh Coins · +" .. passXP .. " Chronicle XP", "SUCCESS", "EXPLORATION:" .. tostring(title or detail or time()))
    end
    if CC.UI and CC.UI.gameDrawer and CC.UI.RefreshGameDrawer then CC.UI:RefreshGameDrawer(true) end
end

function Progression:ProcessMovement()
    local root = self:Ensure()
    if not root then return end
    local exploration = root.exploration
    if COL.Achievements and COL.Achievements.ProcessTaxiState then COL.Achievements:ProcessTaxiState() end
    if type(_G.UnitOnTaxi) == "function" and _G.UnitOnTaxi("player") then
        self.lastMapID, self.lastX, self.lastY = nil, nil, nil
        return
    end
    local mapID = mapIDForPlayer()
    local x, y = mapPosition(mapID)
    if not mapID or not x or not y then return end
    if self.lastMapID == mapID and self.lastX and self.lastY then
        local distance = worldDistance(mapID, self.lastX, self.lastY, x, y)
        if distance and distance >= 0.8 and distance <= 50 then
            if COL.Achievements and COL.Achievements.RecordTravelDistance then
                local flying = type(_G.IsFlying) == "function" and _G.IsFlying() or false
                COL.Achievements:RecordTravelDistance(distance, flying)
            end
            local accumulated = exploration.distanceRemainder + distance
            local steps = floor(accumulated / self.stepYards)
            exploration.distanceRemainder = accumulated - (steps * self.stepYards)
            if steps > 0 then
                exploration.totalSteps = exploration.totalSteps + steps
                local blocks = floor(exploration.totalSteps / 1000)
                local newBlocks = blocks - exploration.rewardedStepBlocks
                if newBlocks > 0 then
                    exploration.rewardedStepBlocks = blocks
                    self:AwardExploration(newBlocks * 2, newBlocks * 2, "Explorer Steps", tostring(newBlocks * 1000) .. " steps travelled", true)
                end
                if COL.Achievements then
                    if COL.Achievements.EvaluateStat then COL.Achievements:EvaluateStat("STEPS", false)
                    elseif COL.Achievements.EvaluateAll then COL.Achievements:EvaluateAll(false) end
                end
            end
        end
    end
    self.lastMapID, self.lastX, self.lastY = mapID, x, y
end

function Progression:CheckArea(initial)
    local root = self:Ensure()
    if not root then return end
    local exploration = root.exploration
    local mapID = mapIDForPlayer()
    if not mapID then return end
    local area, zone = currentAreaName()
    local key = tostring(mapID) .. ":" .. lower(tostring(area))
    if COL.Achievements and COL.Achievements.RecordArea then
        COL.Achievements:RecordArea(zone ~= "" and zone or area, area)
    end
    if exploration.visitedAreas[key] then return end
    exploration.visitedAreas[key] = { area = area, zone = zone, first = now() }
    exploration.newAreas = exploration.newAreas + 1
    local zoneKey = tostring(mapID) .. ":" .. lower(tostring(zone ~= "" and zone or area))
    if not exploration.visitedZones[zoneKey] then
        exploration.visitedZones[zoneKey] = { zone = zone ~= "" and zone or area, first = now() }
        exploration.newZones = exploration.newZones + 1
        self:AwardExploration(8, 5, "New Zone Discovered", zone ~= "" and zone or area, not initial)
        if COL.Achievements and COL.Achievements.RecordZone then COL.Achievements:RecordZone(mapID, zone ~= "" and zone or area) end
    else
        self:AwardExploration(3, 2, "New Area Discovered", area, not initial)
    end
end

function Progression:AwardDungeonClear(dungeonName)
    local root = self:Ensure()
    if not root then return end
    root.exploration.dungeonClears = root.exploration.dungeonClears + 1
    self:AwardExploration(20, 15, "Dungeon Cleared", tostring(dungeonName or "Dungeon"), true)
    if COL.Achievements and COL.Achievements.RecordDungeonEntry then COL.Achievements:RecordDungeonEntry(dungeonName) end
end

function Progression:GetExplorationSummary()
    local root = self:Ensure()
    if not root then return 0, 0, 0, 0 end
    local e = root.exploration
    return e.totalSteps or 0, e.newAreas or 0, e.dungeonClears or 0, e.totalKills or 0
end

function Progression:RecordKill(destGUID, destName)
    local root = self:Ensure(); if not root then return end
    local key = tostring(destGUID or "")
    -- Only count creature/vehicle GUIDs so player PvP deaths never advance mob goals.
    if key ~= "" and not (string.find(key, "^Creature%-") or string.find(key, "^Vehicle%-")) then return end
    self.killCache = self.killCache or {}
    local stamp = now()
    if key ~= "" and stamp - (self.killCache[key] or 0) < 2 then return end
    if key ~= "" then self.killCache[key] = stamp end
    self.killCacheSize = (self.killCacheSize or 0) + 1
    if self.killCacheSize > 250 then self.killCache = {}; self.killCacheSize = 0 end
    root.exploration.totalKills = (root.exploration.totalKills or 0) + 1
    if COL.Achievements and COL.Achievements.RecordWorldKill then COL.Achievements:RecordWorldKill(destGUID, destName) end
    if COL.BattlePass and COL.BattlePass.AddPassXP then COL.BattlePass:AddPassXP(1, "WoW mob defeated", true) end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
events:RegisterEvent("ZONE_CHANGED")
events:RegisterEvent("ZONE_CHANGED_INDOORS")
events:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
events:SetScript("OnEvent", function(_, event)
    if CC.IsFeatureEnabled and not CC:IsFeatureEnabled("worldProgression") then return end
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        if type(_G.CombatLogGetCurrentEventInfo) == "function" then
            local _, subevent, _, sourceGUID, _, sourceFlags, _, destGUID, destName = _G.CombatLogGetCurrentEventInfo()
            if subevent == "PARTY_KILL" then Progression:RecordKill(destGUID, destName) end
        end
        return
    elseif event == "PLAYER_ENTERING_WORLD" then
        Progression:Ensure()
        Progression.lastMapID, Progression.lastX, Progression.lastY = nil, nil, nil
        if _G.C_Timer and _G.C_Timer.After then
            _G.C_Timer.After(1.5, function() Progression:CheckArea(true) end)
        else
            Progression:CheckArea(true)
        end
    else
        if _G.C_Timer and _G.C_Timer.After then
            _G.C_Timer.After(0.6, function() Progression:CheckArea(false) end)
        else
            Progression:CheckArea(false)
        end
    end
end)

events:SetScript("OnUpdate", function(_, elapsed)
    if CC.IsFeatureEnabled and not CC:IsFeatureEnabled("worldProgression") then return end
    Progression.elapsed = (Progression.elapsed or 0) + (elapsed or 0)
    if Progression.elapsed < Progression.pollInterval then return end
    Progression.elapsed = 0
    Progression:ProcessMovement()
end)
