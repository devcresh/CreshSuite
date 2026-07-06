-- Regression coverage for targeted walking progression and cross-addon reward
-- availability. Loads the real Progression.lua and BattlePass.lua files.

local progressionPath = assert(arg[1], "Progression.lua path required")
local battlePassPath = assert(arg[2], "BattlePass.lua path required")

local PASS, FAIL = 0, 0
local function ok(value, message)
    if value then PASS = PASS + 1; print("  PASS  " .. message)
    else FAIL = FAIL + 1; print("  FAIL  " .. message) end
end
local function eq(actual, expected, message)
    ok(actual == expected, message .. " (expected " .. tostring(expected) .. ", got " .. tostring(actual) .. ")")
end

local frames = {}
function CreateFrame()
    local frame = { scripts = {} }
    function frame:RegisterEvent() end
    function frame:SetScript(name, fn) self.scripts[name] = fn end
    frames[#frames + 1] = frame
    return frame
end
function GetTime() return 100 end
function GetServerTime() return 100 end
function time() return 100 end

local function loadProductionFile(path, ...)
    local file = assert(io.open(path, "rb"))
    local source = file:read("*a")
    file:close()
    if source:sub(1, 3) == "\239\187\191" then source = source:sub(4) end
    return assert(loadstring(source, "@" .. path))(...)
end

local mapX, mapY = 0.5, 0.5
_G.C_Map = {
    GetBestMapForUnit = function() return 1 end,
    GetPlayerMapPosition = function()
        return { GetXY = function() return mapX, mapY end }
    end,
}
_G.UnitOnTaxi = function() return false end

_G.CreshCollectDB = {
    arcadeRewards = {},
    gameProgression = { exploration = {} },
}

local COL = { version = "0.2.3", RegisterModule = function() end }
local targeted, full, milestoneChecks = 0, 0, 0
COL.Achievements = {
    ProcessTaxiState = function() end,
    EvaluateStat = function(_, stat) if stat == "STEPS" then targeted = targeted + 1 end end,
    EvaluateAll = function() full = full + 1 end,
}
COL.BattlePass = {
    CheckMilestoneGoals = function() milestoneChecks = milestoneChecks + 1 end,
}

loadProductionFile(progressionPath, "CreshCollect", COL)

print("\n[Movement hot path]")
COL.GameProgression:ProcessMovement() -- establishes the baseline sample
mapX = mapX + 0.0002                 -- fallback map scale: one yard
COL.GameProgression:ProcessMovement()
eq(targeted, 1, "movement evaluates only the STEPS achievement series")
eq(full, 0, "movement never invokes the full achievement-catalogue sweep")
eq(milestoneChecks, 1, "walking milestone check still runs after real movement")
ok(CreshCollectDB.gameProgression.exploration.totalSteps >= 1, "estimated step total still advances")

print("\n[Progressive walking milestones]")
loadProductionFile(battlePassPath, "CreshCollect", COL)
local PassModule = COL.BattlePass
local early = {}
for _, goal in ipairs(PassModule.milestoneDefinitions) do
    if goal.kind == "WALK" and goal.goal <= 10000 then early[#early + 1] = goal.goal end
end
eq(#early, 10, "there are ten early walking unlocks")
for index = 1, 10 do eq(early[index], index * 1000, "walking unlock " .. index .. " uses a 1,000-step progression") end

local refreshes = 0
PassModule.RefreshDrawer = function() refreshes = refreshes + 1 end
PassModule:CheckMilestoneGoals("WALK", 999)
eq(refreshes, 0, "no Battle Pass UI rebuild occurs when no milestone changes")
PassModule:CheckMilestoneGoals("WALK", 1000)
eq(refreshes, 1, "crossing 1,000 steps refreshes once")
PassModule:CheckMilestoneGoals("WALK", 1001)
eq(refreshes, 1, "ordinary movement after the unlock does not rebuild the UI")

print("\n[Cross-addon reward availability]")
_G.CreshSuite = {
    loaded = {},
    IsProductLoaded = function(self, name) return self.loaded[string.upper(tostring(name or ""))] == true end,
}
-- Card decks/Tetris themes are CreshGames' own Battle Pass rewards now (see
-- addons/CreshGames/BattlePass.lua); CreshCollect's pass only still gates on
-- CreshChat for its own chat-theme rewards (level 10 = WESTFALL).
local reward = PassModule:GetReward(10)
eq(reward.deckKey, nil, "level 10 no longer carries a CreshGames card-deck reward")
eq(reward.requiredAddonText, "CRESHCHAT", "the remaining (theme) reward names its own missing addon only")
local themeAvailable, themeMissing = PassModule:IsThemeAvailable("UBUNTU")
ok(not themeAvailable and themeMissing == "CreshChat", "chat theme is unavailable while CreshChat is disabled")
eq(PassModule:GetRequirementRoute().name, "World Progression", "Battle Pass always guides players toward world/exploration progress")

_G.CreshSuite.loaded.CRESHGAMES = true
_G.CreshSuite.loaded.CRESHCHAT = true
reward = PassModule:GetReward(10)
ok(reward.requiredAddonText == nil, "theme reward clears its unavailable marker once CreshChat is active")
themeAvailable, themeMissing = PassModule:IsThemeAvailable("UBUNTU")
ok(themeAvailable and themeMissing == nil, "chat theme becomes available when CreshChat is active")
eq(PassModule:GetRequirementRoute().name, "World Progression", "requirement route stays world-progression even once CreshGames is active -- mini-games no longer fund this pass")

print(("\n=== Results: %d passed, %d failed ==="):format(PASS, FAIL))
if FAIL > 0 then os.exit(1) end
