local _, CG = ...
if not CG then return end
-- CC is a nil-safe proxy for optional CreshChat integration when CreshChat is not loaded.
local CC = setmetatable({}, { __index = function(_, k) local c = _G.CreshChat; return c and c[k] end })

local Pass = {
    version = CG.version,
    maxLevel = 100,
}
CG.DungeonDwellersPass = Pass
if CG.RegisterModule then CG:RegisterModule("DungeonDwellersPass", Pass) end

local floor, max, min = math.floor, math.max, math.min
local upper = string.upper
local format = string.format

local function now()
    if type(_G.time) == "function" then return _G.time() end
    if type(_G.GetTime) == "function" then return floor(_G.GetTime()) end
    return 0
end

local function clamp(value, low, high)
    value = tonumber(value) or low
    return max(low, min(high, value))
end

local function showDungeonPassToast(title, message, key)
    CG:ShowDungeonPassToast(title, message, key)
end

local function dungeonSave()
    if not CreshGamesDB then return nil end
    CreshGamesDB.soloGames = type(CreshGamesDB.soloGames) == "table" and CreshGamesDB.soloGames or {}
    CreshGamesDB.soloGames.dungeon = type(CreshGamesDB.soloGames.dungeon) == "table" and CreshGamesDB.soloGames.dungeon or {}
    return CreshGamesDB.soloGames.dungeon
end

function Pass:Ensure()
    local dungeon = dungeonSave()
    if not dungeon then return nil end

    dungeon.classStats = type(dungeon.classStats) == "table" and dungeon.classStats or {}
    if not dungeon.classStatsMigrated and next(dungeon.classStats) == nil and (tonumber(dungeon.runs) or 0) > 0 then
        local classKey = upper(tostring(dungeon.class or "PALADIN"))
        if classKey == "" then classKey = "PALADIN" end
        dungeon.classStats[classKey] = {
            runs = floor(max(0, tonumber(dungeon.runs) or 0)),
            maxRoom = floor(max(0, tonumber(dungeon.bestRoom) or tonumber(dungeon.bestLevel) or 0)),
            kills = floor(max(0, tonumber(dungeon.kills) or 0)),
            bosses = floor(max(0, tonumber(dungeon.bosses) or 0)),
            highScore = floor(max(0, tonumber(dungeon.highScore) or 0)),
            deaths = 0,
        }
    end
    dungeon.classStatsMigrated = true
    dungeon.unlockedMinions = type(dungeon.unlockedMinions) == "table" and dungeon.unlockedMinions or {}
    dungeon.minionRecruitsByType = type(dungeon.minionRecruitsByType) == "table" and dungeon.minionRecruitsByType or {}
    dungeon.unlockedMinionSkins = type(dungeon.unlockedMinionSkins) == "table" and dungeon.unlockedMinionSkins or {}
    dungeon.minionSkinRecruits = type(dungeon.minionSkinRecruits) == "table" and dungeon.minionSkinRecruits or {}
    dungeon.discoveredItems = type(dungeon.discoveredItems) == "table" and dungeon.discoveredItems or {}
    dungeon.battlePass = type(dungeon.battlePass) == "table" and dungeon.battlePass or {}

    local save = dungeon.battlePass
    save.xp = floor(max(0, tonumber(save.xp) or 0))
    save.claimed = type(save.claimed) == "table" and save.claimed or {}
    save.buffs = type(save.buffs) == "table" and save.buffs or {}
    save.activity = type(save.activity) == "table" and save.activity or {}
    save.visitedZones = type(save.visitedZones) == "table" and save.visitedZones or {}
    save.achievements = type(save.achievements) == "table" and save.achievements or {}
    save.recent = type(save.recent) == "table" and save.recent or {}

    local activity = save.activity
    activity.mobKills = floor(max(0, tonumber(activity.mobKills) or 0))
    activity.dungeonKills = floor(max(0, tonumber(activity.dungeonKills) or 0))
    activity.quests = floor(max(0, tonumber(activity.quests) or 0))
    activity.zones = floor(max(0, tonumber(activity.zones) or 0))
    activity.achievements = floor(max(0, tonumber(activity.achievements) or 0))

    local buffKeys = { "maxHP", "attack", "minionPower", "regenRoom", "regenTurn", "bossDamage", "extraDieChance", "coinBonus" }
    for _, key in ipairs(buffKeys) do save.buffs[key] = floor(max(0, tonumber(save.buffs[key]) or 0)) end
    return save, dungeon
end

function Pass:GetNextLevelCost(level)
    level = floor(clamp(level, 1, self.maxLevel))
    return 40 + ((level - 1) * 4)
end

function Pass:GetCumulativeXP(level)
    level = floor(clamp(level, 1, self.maxLevel))
    local completed = level - 1
    return completed * 40 + (4 * completed * (completed - 1)) / 2
end

function Pass:GetLevelFromXP(xp)
    xp = floor(max(0, tonumber(xp) or 0))
    local level = 1
    while level < self.maxLevel and xp >= self:GetCumulativeXP(level + 1) do level = level + 1 end
    return level
end

function Pass:GetProgress()
    local save = self:Ensure()
    if not save then return 1, 0, 40, 0 end
    local level = self:GetLevelFromXP(save.xp)
    if level >= self.maxLevel then return level, 1, 1, 1 end
    local base = self:GetCumulativeXP(level)
    local needed = self:GetNextLevelCost(level)
    local current = max(0, save.xp - base)
    return level, current, needed, clamp(current / max(1, needed), 0, 1)
end

local function addBuff(reward, key, value, label)
    reward.buffs[#reward.buffs + 1] = { key = key, value = value, label = label }
end

-- Data-driven replacement for the level%20/level== branching this used to be
-- (Rework Phase 2: "replace hard-coded reward branching with stable
-- catalogs"). Each rule has its own stable id, independent of any specific
-- level number, so the schedule can be retuned without renaming anything a
-- save file or another system might reference. A rule fires on every level
-- matching cycleOf20 (level % 20 == cycleOf20) or, for milestone rules, any
-- level listed in `levels`.
Pass.buffScheduleCatalog = {
    { id = "MAXHP_EVERY20",       key = "maxHP",         value = 1, label = "+1 starting Max HP",                    cycleOf20 = 5 },
    { id = "MINIONPOWER_EVERY20", key = "minionPower",   value = 1, label = "+1 recruited minion power",             cycleOf20 = 10 },
    { id = "REGENROOM_EVERY20",   key = "regenRoom",     value = 1, label = "+1 HP after each cleared room",         cycleOf20 = 15 },
    { id = "ATTACK_EVERY20",      key = "attack",        value = 1, label = "+1 starting Attack",                    cycleOf20 = 0 },
    { id = "BOSSDAMAGE_MILESTONE",key = "bossDamage",     value = 1, label = "+1 damage against bosses",              levels = { 25, 50, 75, 100 } },
    { id = "EXTRADIE_MILESTONE",  key = "extraDieChance", value = 5, label = "+5% chance to roll a bonus die",        levels = { 40, 80 } },
    { id = "COINBONUS_MILESTONE", key = "coinBonus",      value = 5, label = "+5% Dungeon coin rewards",              levels = { 50, 100 } },
    { id = "REGENTURN_MILESTONE", key = "regenTurn",      value = 1, label = "+1 HP regeneration after enemy turns",  levels = { 60, 100 } },
}

local function buffRuleMatchesLevel(rule, level, cycle)
    if rule.cycleOf20 ~= nil then return cycle == rule.cycleOf20 end
    if rule.levels then
        for _, lvl in ipairs(rule.levels) do
            if lvl == level then return true end
        end
    end
    return false
end

function Pass:GetReward(level)
    level = floor(clamp(level, 1, self.maxLevel))
    local reward = {
        level = level,
        coins = level == 100 and 500 or (10 + floor((level - 1) / 5) * 5),
        buffs = {},
        title = "Delver Rank " .. tostring(level),
        -- F1: reward routing metadata
        sourceSystem = "DUNGEON_DWELLER_BATTLE_PASS",
        sourceId     = "DDPASS_LEVEL_" .. level,
        targetGame   = "DUNGEON_DWELLER",
    }

    local cycle = level % 20
    for _, rule in ipairs(self.buffScheduleCatalog) do
        if buffRuleMatchesLevel(rule, level, cycle) then
            addBuff(reward, rule.key, rule.value, rule.label)
        end
    end

    if #reward.buffs > 0 then reward.title = "Delver Boon " .. tostring(level) end
    return reward
end

function Pass:GetRewardText(level)
    local reward = self:GetReward(level)
    local parts = { "+" .. tostring(reward.coins) .. " Cresh Coins" }
    for _, buff in ipairs(reward.buffs) do parts[#parts + 1] = buff.label end
    return table.concat(parts, " · ")
end

function Pass:IsLevelReached(level)
    local save = self:Ensure()
    return save and save.xp >= self:GetCumulativeXP(level) or false
end

function Pass:IsRewardClaimed(level)
    local save = self:Ensure()
    return save and save.claimed[tostring(level)] == true or false
end

function Pass:GetBuffs()
    local save = self:Ensure()
    return save and save.buffs or {}
end

function Pass:RefreshUI()
    if CG.SoloGames and CG.SoloGames.views and CG.SoloGames.views.DUNGEON then
        local view = CG.SoloGames.views.DUNGEON
        if view.RefreshDwellersPanel then view:RefreshDwellersPanel() end
        if view.Refresh then view:Refresh() end
    end
    if CC.UI and CC.UI.RefreshConsoleEconomy then CC.UI:RefreshConsoleEconomy() end
end

function Pass:AddXP(amount, source, activityKey, silent, isSimulation)
    if isSimulation == true then return 0 end
    local save = self:Ensure()
    amount = floor(max(0, tonumber(amount) or 0))
    if not save or amount <= 0 then return 0 end

    local previousLevel = self:GetLevelFromXP(save.xp)
    save.xp = save.xp + amount
    local newLevel = self:GetLevelFromXP(save.xp)
    if activityKey and save.activity[activityKey] ~= nil then
        save.activity[activityKey] = save.activity[activityKey] + 1
    end
    save.recent = { source = tostring(source or "Activity"), xp = amount, level = newLevel, at = now() }

    if newLevel > previousLevel then
        -- Rework Phase 3: "per-game Mastery milestones" Arcade Pass XP
        -- source -- same addon, no Suite hop needed. Silent: the Delver
        -- Mastery level-up toast below already covers user feedback.
        if CG.BattlePass and CG.BattlePass.AwardMasteryLevelUp then CG.BattlePass:AwardMasteryLevelUp(true) end
        if not silent then
            showDungeonPassToast(
                "Delver Mastery Level " .. tostring(newLevel),
                "+" .. tostring(amount) .. " XP · " .. self:GetRewardText(newLevel) .. " ready",
                "DDPASS:LEVEL:" .. tostring(newLevel)
            )
        end
    end

    self:RefreshUI()
    return amount, previousLevel, newLevel
end

-- Rework Phase 4 (Delver Mastery): RecordMobKill, RecordQuest, RecordZone and
-- RecordAchievement were removed here -- they paid Mastery XP for WoW-world
-- mob kills, quests, zone discovery and World achievements, which the rules
-- for this conversion explicitly forbid ("Dungeon Mastery receives XP only
-- from Dungeon Dwellers activity... remove XP from WoW quests, WoW zones,
-- WoW mobs and World achievements"). Three of the four were already DORMANT
-- (no live callers); RecordZone was live, called from CreshCollect/
-- Progression.lua's CheckArea on every new WoW zone discovered -- that call
-- site was removed in the same change. RecordDungeonKill below is unaffected
-- -- killing an enemy inside a Dungeon Dweller run is Dungeon Dwellers
-- activity, not WoW-world activity, and remains this Mastery's own XP source.
function Pass:RecordDungeonKill(isBoss)
    return self:AddXP(isBoss and 5 or 2, isBoss and "Dungeon boss defeated" or "Dungeon enemy defeated", "dungeonKills", false)
end

function Pass:ClaimReward(level, silent)
    local save = self:Ensure()
    level = floor(clamp(level, 1, self.maxLevel))
    if not save or not self:IsLevelReached(level) then return false end
    local key = tostring(level)
    if save.claimed[key] then return false end

    local reward = self:GetReward(level)
    save.claimed[key] = true
    local Suite = _G.CreshSuite
    if Suite and Suite.Publish then
        Suite:Publish("CRESHGAMES_COLLECTION_UNLOCK", { source = "CRESHGAMES", type = "DUNGEON_PASS", key = key })
    end
    -- Dungeon Dwellers coin rewards are CreshGames' own reward currency --
    -- pay them into CG.BattlePass, never CreshCollect's pass (ownership
    -- boundary fix; this previously reached CC.BattlePass, which resolves to
    -- CreshCollect's pass now that the two are decoupled).
    if CG.BattlePass and CG.BattlePass.AddCoins then CG.BattlePass:AddCoins(reward.coins, "DUNGEON_PASS") end
    for _, buff in ipairs(reward.buffs) do
        local value = tonumber(buff.value) or 0
        save.buffs[buff.key] = floor(max(0, tonumber(save.buffs[buff.key]) or 0)) + value
        local view = CG.SoloGames and CG.SoloGames.views and CG.SoloGames.views.DUNGEON
        if view and view.frame and view.frame.IsShown and view.frame:IsShown() and not view.dead then
            if buff.key == "maxHP" then
                view.maxHP = (view.maxHP or 1) + value
                view.hp = min(view.maxHP, (view.hp or 0) + value)
            elseif buff.key == "attack" then
                view.attack = (view.attack or 1) + value
            elseif buff.key == "minionPower" then
                for _, minion in ipairs(view.minions or {}) do minion.power = (minion.power or 1) + value end
                if view.minionOffer then view.minionOffer.power = (view.minionOffer.power or 1) + value end
            end
        end
    end
    save.recent = { source = "Level " .. tostring(level) .. " reward claimed", coins = reward.coins, level = level, at = now() }

    if not silent then
        showDungeonPassToast(
            "Delver Mastery reward claimed",
            "Level " .. tostring(level) .. " · " .. self:GetRewardText(level),
            "DDPASS:CLAIM:" .. tostring(level)
        )
    end
    self:RefreshUI()
    return true
end

function Pass:ClaimAllAvailable()
    local claimed, coins = 0, 0
    for level = 1, self.maxLevel do
        if self:IsLevelReached(level) and not self:IsRewardClaimed(level) then
            local reward = self:GetReward(level)
            if self:ClaimReward(level, true) then
                claimed = claimed + 1
                coins = coins + reward.coins
            end
        end
    end
    if claimed > 0 then
        showDungeonPassToast(
            "Delver Mastery rewards claimed",
            tostring(claimed) .. " rewards · +" .. tostring(coins) .. " Cresh Coins",
            "DDPASS:CLAIMALL:" .. tostring(now())
        )
    end
    self:RefreshUI()
    return claimed, coins
end

function Pass:GetActivitySummary()
    local save = self:Ensure()
    local a = save and save.activity or {}
    return {
        mobKills = a.mobKills or 0,
        dungeonKills = a.dungeonKills or 0,
        quests = a.quests or 0,
        zones = a.zones or 0,
        achievements = a.achievements or 0,
    }
end

local eventFrame = CreateFrame("Frame")
local function safeRegister(event)
    if eventFrame and eventFrame.RegisterEvent then pcall(eventFrame.RegisterEvent, eventFrame, event) end
end
safeRegister("PLAYER_LOGIN")

eventFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        Pass:Ensure()
    end
end)
