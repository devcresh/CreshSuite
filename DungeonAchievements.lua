local _, CC = ...
if not CC then return end

local DungeonAchievements = {
    version  = CC.version,
    catalog  = {},
    byKey    = {},
}
CC.DungeonAchievements = DungeonAchievements
if CC.RegisterModule then CC:RegisterModule("DungeonAchievements", DungeonAchievements) end

local floor, max, min = math.floor, math.max, math.min
local format = string.format

local function now()
    if type(_G.GetServerTime) == "function" then return _G.GetServerTime() end
    if type(_G.time)          == "function" then return _G.time() end
    if type(_G.GetTime)       == "function" then return floor(_G.GetTime()) end
    return 0
end

local function formatNumber(value)
    local text    = tostring(floor(max(0, tonumber(value) or 0)))
    local grouped = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    if grouped:sub(1, 1) == "," then grouped = grouped:sub(2) end
    return grouped
end

local function countMap(tbl)
    local n = 0
    for _ in pairs(tbl or {}) do n = n + 1 end
    return n
end

-- Reward scaling for DD achievements. XP here goes to the DD Pass, not the Main Battle Pass.
local function ddRewardFor(tier, weight)
    tier   = max(1, tonumber(tier)   or 1)
    weight = max(1, tonumber(weight) or 1)
    return floor(8 + tier * 6 * weight), floor(20 + tier * 15 * weight)
end

-- ── Save helpers ─────────────────────────────────────────────────────────────

local function ddSave()
    if not CC.db then return nil end
    CC.db.soloGames        = type(CC.db.soloGames)        == "table" and CC.db.soloGames        or {}
    CC.db.soloGames.dungeon = type(CC.db.soloGames.dungeon) == "table" and CC.db.soloGames.dungeon or {}
    return CC.db.soloGames.dungeon
end

function DungeonAchievements:Ensure()
    self:BuildCatalog()
    local dungeon = ddSave()
    if not dungeon then return nil end
    dungeon.ddAchievements = type(dungeon.ddAchievements) == "table" and dungeon.ddAchievements or {}
    local save = dungeon.ddAchievements
    save.unlocked = type(save.unlocked) == "table" and save.unlocked or {}
    save.activity = type(save.activity) == "table" and save.activity or {}
    local act = save.activity
    act.damageDealt   = floor(max(0, tonumber(act.damageDealt)   or 0))
    act.damageTaken   = floor(max(0, tonumber(act.damageTaken)   or 0))
    act.crits         = floor(max(0, tonumber(act.crits)         or 0))
    act.cratesOpened  = floor(max(0, tonumber(act.cratesOpened)  or 0))
    act.bestStreak    = floor(max(0, tonumber(act.bestStreak)    or 0))
    act.currentStreak = floor(max(0, tonumber(act.currentStreak) or 0))
    return save
end

-- ── Catalog ───────────────────────────────────────────────────────────────────

function DungeonAchievements:Add(key, stat, goal, title, description, tier, coins, xp)
    local entry = {
        key         = key,
        stat        = stat,
        goal        = goal,
        title       = title,
        description = description,
        tier        = tier,
        coins       = coins,
        xp          = xp,
    }
    self.catalog[#self.catalog + 1] = entry
    self.byKey[key] = entry
end

local function addSeries(self, stat, goals, keys, titles, descriptions, weight)
    for i, goal in ipairs(goals) do
        local coins, xp = ddRewardFor(i, weight)
        self:Add(keys[i], stat, goal, titles[i], descriptions[i], i, coins, xp)
    end
end

function DungeonAchievements:BuildCatalog()
    if #self.catalog > 0 then return end

    -- KILLS — enemy kills inside Dungeon Dwellers
    addSeries(self, "DD_KILLS",
        { 10, 25, 50, 100, 250, 500, 1000, 2500, 5000, 10000 },
        { "ACH_DD_KILLS_001", "ACH_DD_KILLS_002", "ACH_DD_KILLS_003", "ACH_DD_KILLS_004", "ACH_DD_KILLS_005",
          "ACH_DD_KILLS_006", "ACH_DD_KILLS_007", "ACH_DD_KILLS_008", "ACH_DD_KILLS_009", "ACH_DD_KILLS_010" },
        { "Dungeon Initiate", "Dungeon Scout", "Dweller Slayer", "Centurion of the Deep",
          "Pack Breaker", "Battle-Hardened Dweller", "Thousand Fallen", "Relentless Delver",
          "Enemy of the Deep", "Ten Thousand Dwellers" },
        { "Defeat " .. formatNumber(10)    .. " enemies in Dungeon Dwellers.",
          "Defeat " .. formatNumber(25)    .. " enemies in Dungeon Dwellers.",
          "Defeat " .. formatNumber(50)    .. " enemies in Dungeon Dwellers.",
          "Defeat " .. formatNumber(100)   .. " enemies in Dungeon Dwellers.",
          "Defeat " .. formatNumber(250)   .. " enemies in Dungeon Dwellers.",
          "Defeat " .. formatNumber(500)   .. " enemies in Dungeon Dwellers.",
          "Defeat " .. formatNumber(1000)  .. " enemies in Dungeon Dwellers.",
          "Defeat " .. formatNumber(2500)  .. " enemies in Dungeon Dwellers.",
          "Defeat " .. formatNumber(5000)  .. " enemies in Dungeon Dwellers.",
          "Defeat " .. formatNumber(10000) .. " enemies in Dungeon Dwellers." }, 1)

    -- BOSSES — boss victories inside Dungeon Dwellers
    addSeries(self, "DD_BOSSES",
        { 1, 3, 5, 10, 25, 50, 100, 250, 500 },
        { "ACH_DD_BOSSES_001", "ACH_DD_BOSSES_002", "ACH_DD_BOSSES_003",
          "ACH_DD_BOSSES_004", "ACH_DD_BOSSES_005", "ACH_DD_BOSSES_006",
          "ACH_DD_BOSSES_007", "ACH_DD_BOSSES_008", "ACH_DD_BOSSES_009" },
        { "First Guardian Slain", "Triple Threat", "Five Tyrants", "Ten Crowns",
          "Dweller Nemesis", "Half-Century of Tyrants", "Century of Crowns",
          "Legendary Dweller Slayer", "Five Hundred Crowns" },
        { "Defeat 1 boss in Dungeon Dwellers.",
          "Defeat 3 bosses in Dungeon Dwellers.",
          "Defeat 5 bosses in Dungeon Dwellers.",
          "Defeat 10 bosses in Dungeon Dwellers.",
          "Defeat " .. formatNumber(25)  .. " bosses in Dungeon Dwellers.",
          "Defeat " .. formatNumber(50)  .. " bosses in Dungeon Dwellers.",
          "Defeat " .. formatNumber(100) .. " bosses in Dungeon Dwellers.",
          "Defeat " .. formatNumber(250) .. " bosses in Dungeon Dwellers.",
          "Defeat " .. formatNumber(500) .. " bosses in Dungeon Dwellers." }, 2)

    -- UNIQUE BOSSES — distinct boss types encountered
    addSeries(self, "DD_UNIQUE_BOSSES",
        { 1, 5, 10, 25, 50, 75, 100 },
        { "ACH_DD_UNIQUE_BOSSES_001", "ACH_DD_UNIQUE_BOSSES_002", "ACH_DD_UNIQUE_BOSSES_003",
          "ACH_DD_UNIQUE_BOSSES_004", "ACH_DD_UNIQUE_BOSSES_005", "ACH_DD_UNIQUE_BOSSES_006",
          "ACH_DD_UNIQUE_BOSSES_007" },
        { "First Name on the List", "Boss Collector", "Ten Tyrant Types",
          "Dweller Bestiary", "Half the Roster", "Near Complete", "Dungeon Master" },
        { "Defeat 1 different boss type in Dungeon Dwellers.",
          "Defeat 5 different boss types in Dungeon Dwellers.",
          "Defeat 10 different boss types in Dungeon Dwellers.",
          "Defeat " .. formatNumber(25)  .. " different boss types in Dungeon Dwellers.",
          "Defeat " .. formatNumber(50)  .. " different boss types in Dungeon Dwellers.",
          "Defeat " .. formatNumber(75)  .. " different boss types in Dungeon Dwellers.",
          "Defeat " .. formatNumber(100) .. " different boss types in Dungeon Dwellers." }, 2)

    -- RUNS — expeditions started or completed
    addSeries(self, "DD_RUNS",
        { 1, 5, 10, 25, 50, 100, 250 },
        { "ACH_DD_RUNS_001", "ACH_DD_RUNS_002", "ACH_DD_RUNS_003", "ACH_DD_RUNS_004",
          "ACH_DD_RUNS_005", "ACH_DD_RUNS_006", "ACH_DD_RUNS_007" },
        { "First Expedition", "Dungeon Regular", "Ten Expeditions",
          "Reliable Dweller", "Dungeon Veteran", "Hundred Expeditions", "Endless Dweller" },
        { "Begin 1 Dungeon Dwellers expedition.",
          "Begin 5 Dungeon Dwellers expeditions.",
          "Begin 10 Dungeon Dwellers expeditions.",
          "Begin " .. formatNumber(25)  .. " Dungeon Dwellers expeditions.",
          "Begin " .. formatNumber(50)  .. " Dungeon Dwellers expeditions.",
          "Begin " .. formatNumber(100) .. " Dungeon Dwellers expeditions.",
          "Begin " .. formatNumber(250) .. " Dungeon Dwellers expeditions." }, 1)

    -- DEPTH — deepest room reached in a single run (survival / level progression)
    addSeries(self, "DD_BEST_ROOM",
        { 3, 5, 8, 10, 15, 20, 25, 30 },
        { "ACH_DD_DEPTH_001", "ACH_DD_DEPTH_002", "ACH_DD_DEPTH_003", "ACH_DD_DEPTH_004",
          "ACH_DD_DEPTH_005", "ACH_DD_DEPTH_006", "ACH_DD_DEPTH_007", "ACH_DD_DEPTH_008" },
        { "Going Deeper", "Halfway Down", "Eight Rooms Deep", "Tenth Room",
          "Halfway to the Core", "Dungeon Diver", "Deep Dweller", "Bottom of the Dungeon" },
        { "Reach room 3 or deeper in a single Dungeon Dwellers run.",
          "Reach room 5 or deeper in a single Dungeon Dwellers run.",
          "Reach room 8 or deeper in a single Dungeon Dwellers run.",
          "Reach room 10 or deeper in a single Dungeon Dwellers run.",
          "Reach room 15 or deeper in a single Dungeon Dwellers run.",
          "Reach room 20 or deeper in a single Dungeon Dwellers run.",
          "Reach room 25 or deeper in a single Dungeon Dwellers run.",
          "Reach room 30 or deeper in a single Dungeon Dwellers run." }, 2)

    -- SCORE — high score challenge milestones
    addSeries(self, "DD_HIGH_SCORE",
        { 100, 500, 1000, 5000, 10000, 25000 },
        { "ACH_DD_SCORE_001", "ACH_DD_SCORE_002", "ACH_DD_SCORE_003",
          "ACH_DD_SCORE_004", "ACH_DD_SCORE_005", "ACH_DD_SCORE_006" },
        { "First Points", "Five Hundred Strong", "Four Digits",
          "Five Thousand Score", "Ten Thousand Score", "Elite Scorer" },
        { "Achieve a Dungeon Dwellers high score of 100.",
          "Achieve a Dungeon Dwellers high score of " .. formatNumber(500)   .. ".",
          "Achieve a Dungeon Dwellers high score of " .. formatNumber(1000)  .. ".",
          "Achieve a Dungeon Dwellers high score of " .. formatNumber(5000)  .. ".",
          "Achieve a Dungeon Dwellers high score of " .. formatNumber(10000) .. ".",
          "Achieve a Dungeon Dwellers high score of " .. formatNumber(25000) .. "." }, 2)

    -- PASS LEVEL — Dungeon Dwellers Pass rank progression
    addSeries(self, "DD_PASS_LEVEL",
        { 5, 10, 25, 50, 75, 100 },
        { "ACH_DD_PASS_001", "ACH_DD_PASS_002", "ACH_DD_PASS_003",
          "ACH_DD_PASS_004", "ACH_DD_PASS_005", "ACH_DD_PASS_006" },
        { "Delver Rising", "Level Ten Delver", "Veteran Delver",
          "Elite Delver", "Master Delver", "Max Rank Delver" },
        { "Reach Dungeon Dwellers Pass level 5.",
          "Reach Dungeon Dwellers Pass level 10.",
          "Reach Dungeon Dwellers Pass level 25.",
          "Reach Dungeon Dwellers Pass level 50.",
          "Reach Dungeon Dwellers Pass level 75.",
          "Reach Dungeon Dwellers Pass level 100." }, 2)

    -- ARMOUR — class or armour set unlocks
    addSeries(self, "DD_ARMOUR",
        { 1, 3, 5, 8, 12 },
        { "ACH_DD_ARMOUR_001", "ACH_DD_ARMOUR_002", "ACH_DD_ARMOUR_003",
          "ACH_DD_ARMOUR_004", "ACH_DD_ARMOUR_005" },
        { "Armoured Up", "Well Equipped", "War Gear", "Knight's Armoury", "Full Arsenal" },
        { "Unlock 1 armour set in Dungeon Dwellers.",
          "Unlock 3 armour sets in Dungeon Dwellers.",
          "Unlock 5 armour sets in Dungeon Dwellers.",
          "Unlock 8 armour sets in Dungeon Dwellers.",
          "Unlock 12 armour sets in Dungeon Dwellers." }, 2)

    -- MINION — minion recruitment (class/companion progression)
    addSeries(self, "DD_MINION",
        { 1, 3, 5, 10, 20 },
        { "ACH_DD_MINION_001", "ACH_DD_MINION_002", "ACH_DD_MINION_003",
          "ACH_DD_MINION_004", "ACH_DD_MINION_005" },
        { "First Recruit", "Band of Three", "Warband", "Full Roster", "Minion Army" },
        { "Recruit 1 different minion in Dungeon Dwellers.",
          "Recruit 3 different minions in Dungeon Dwellers.",
          "Recruit 5 different minions in Dungeon Dwellers.",
          "Recruit 10 different minions in Dungeon Dwellers.",
          "Recruit 20 different minions in Dungeon Dwellers." }, 2)

    -- ITEM — items discovered across expeditions (chest and reward activity)
    addSeries(self, "DD_ITEM",
        { 5, 10, 25, 50, 100 },
        { "ACH_DD_ITEM_001", "ACH_DD_ITEM_002", "ACH_DD_ITEM_003",
          "ACH_DD_ITEM_004", "ACH_DD_ITEM_005" },
        { "Item Finder", "Dungeon Appraiser", "Catalogue Started",
          "Seasoned Collector", "Dungeon Antiquarian" },
        { "Discover 5 unique items across Dungeon Dwellers expeditions.",
          "Discover 10 unique items across Dungeon Dwellers expeditions.",
          "Discover " .. formatNumber(25)  .. " unique items across Dungeon Dwellers expeditions.",
          "Discover " .. formatNumber(50)  .. " unique items across Dungeon Dwellers expeditions.",
          "Discover " .. formatNumber(100) .. " unique items across Dungeon Dwellers expeditions." }, 1)

    -- CRATE — reward crates opened (chest activity)
    addSeries(self, "DD_CRATE",
        { 1, 5, 10, 25, 50 },
        { "ACH_DD_CRATE_001", "ACH_DD_CRATE_002", "ACH_DD_CRATE_003",
          "ACH_DD_CRATE_004", "ACH_DD_CRATE_005" },
        { "Treasure Seeker", "Crate Opener", "Dungeon Looter", "Chest Hunter", "Vault Raider" },
        { "Open 1 reward crate in Dungeon Dwellers.",
          "Open 5 reward crates in Dungeon Dwellers.",
          "Open 10 reward crates in Dungeon Dwellers.",
          "Open " .. formatNumber(25) .. " reward crates in Dungeon Dwellers.",
          "Open " .. formatNumber(50) .. " reward crates in Dungeon Dwellers." }, 1)

    -- DAMAGE DEALT — total damage dealt (tracked from Pass 6 onward; 0 until then)
    addSeries(self, "DD_DAMAGE_DEALT",
        { 500, 2500, 10000, 50000, 100000 },
        { "ACH_DD_DAMAGE_001", "ACH_DD_DAMAGE_002", "ACH_DD_DAMAGE_003",
          "ACH_DD_DAMAGE_004", "ACH_DD_DAMAGE_005" },
        { "First Bloodshed", "Damage Apprentice", "Damage Dealer",
          "Wrecking Machine", "Engine of Destruction" },
        { "Deal " .. formatNumber(500)    .. " total damage in Dungeon Dwellers.",
          "Deal " .. formatNumber(2500)   .. " total damage in Dungeon Dwellers.",
          "Deal " .. formatNumber(10000)  .. " total damage in Dungeon Dwellers.",
          "Deal " .. formatNumber(50000)  .. " total damage in Dungeon Dwellers.",
          "Deal " .. formatNumber(100000) .. " total damage in Dungeon Dwellers." }, 2)

    -- DAMAGE TAKEN — total damage received (tracked from Pass 6 onward)
    addSeries(self, "DD_DAMAGE_TAKEN",
        { 100, 500, 2500, 10000, 50000 },
        { "ACH_DD_TAKEN_001", "ACH_DD_TAKEN_002", "ACH_DD_TAKEN_003",
          "ACH_DD_TAKEN_004", "ACH_DD_TAKEN_005" },
        { "First Scratch", "Punching Bag", "Iron Will", "Tough Enough", "Unbreakable" },
        { "Receive " .. formatNumber(100)   .. " total damage in Dungeon Dwellers.",
          "Receive " .. formatNumber(500)   .. " total damage in Dungeon Dwellers.",
          "Receive " .. formatNumber(2500)  .. " total damage in Dungeon Dwellers.",
          "Receive " .. formatNumber(10000) .. " total damage in Dungeon Dwellers.",
          "Receive " .. formatNumber(50000) .. " total damage in Dungeon Dwellers." }, 1)

    -- CRITS — critical strikes landed (tracked from Pass 6 onward)
    addSeries(self, "DD_CRITS",
        { 10, 50, 100, 500, 1000 },
        { "ACH_DD_CRIT_001", "ACH_DD_CRIT_002", "ACH_DD_CRIT_003",
          "ACH_DD_CRIT_004", "ACH_DD_CRIT_005" },
        { "Sharp Strike", "Crit Apprentice", "Critical Thinker", "Critical Mastery", "Dice of Fate" },
        { "Land 10 critical strikes in Dungeon Dwellers.",
          "Land " .. formatNumber(50)   .. " critical strikes in Dungeon Dwellers.",
          "Land " .. formatNumber(100)  .. " critical strikes in Dungeon Dwellers.",
          "Land " .. formatNumber(500)  .. " critical strikes in Dungeon Dwellers.",
          "Land " .. formatNumber(1000) .. " critical strikes in Dungeon Dwellers." }, 2)

    -- STREAK — consecutive-run win streak (tracked from Pass 6 onward)
    addSeries(self, "DD_STREAK",
        { 2, 3, 5, 10, 20 },
        { "ACH_DD_STREAK_001", "ACH_DD_STREAK_002", "ACH_DD_STREAK_003",
          "ACH_DD_STREAK_004", "ACH_DD_STREAK_005" },
        { "On a Roll", "Hat Trick", "High-Five Streak", "Ten in a Row", "Unstoppable Dweller" },
        { "Win 2 Dungeon Dwellers expeditions in a row.",
          "Win 3 Dungeon Dwellers expeditions in a row.",
          "Win 5 Dungeon Dwellers expeditions in a row.",
          "Win 10 Dungeon Dwellers expeditions in a row.",
          "Win 20 Dungeon Dwellers expeditions in a row." }, 2)
end

-- ── Stat reader ───────────────────────────────────────────────────────────────
-- All reads are isolated to DD saves. No WoW-world stat keys cross into this function.

function DungeonAchievements:GetStat(stat)
    local save = self:Ensure()
    if not save then return 0 end
    local dungeon = ddSave() or {}
    local bp = type(dungeon.battlePass) == "table" and dungeon.battlePass or {}

    if stat == "DD_KILLS"        then return floor(max(0, tonumber(dungeon.kills)   or 0)) end
    if stat == "DD_BOSSES"       then return floor(max(0, tonumber(dungeon.bosses)  or 0)) end
    if stat == "DD_UNIQUE_BOSSES" then return countMap(dungeon.bossKillsByType) end
    if stat == "DD_RUNS"         then return floor(max(0, tonumber(dungeon.runs)    or 0)) end
    if stat == "DD_BEST_ROOM"    then
        return floor(max(0, tonumber(dungeon.bestRoom) or tonumber(dungeon.bestLevel) or 0))
    end
    if stat == "DD_HIGH_SCORE"   then return floor(max(0, tonumber(dungeon.highScore) or 0)) end
    if stat == "DD_PASS_LEVEL"   then
        local xp = floor(max(0, tonumber(bp.xp) or 0))
        if CC.DungeonDwellersPass and CC.DungeonDwellersPass.GetLevelFromXP then
            return CC.DungeonDwellersPass:GetLevelFromXP(xp)
        end
        return 1
    end
    if stat == "DD_ARMOUR"       then return countMap(dungeon.unlockedArmour) end
    if stat == "DD_MINION"       then return countMap(dungeon.unlockedMinions) end
    if stat == "DD_ITEM"         then return countMap(dungeon.discoveredItems) end
    -- Stats that require future combat tracking; evaluate to 0 until Pass 6 wires them.
    if stat == "DD_CRATE"        then return floor(max(0, tonumber(save.activity.cratesOpened) or 0)) end
    if stat == "DD_DAMAGE_DEALT" then return floor(max(0, tonumber(save.activity.damageDealt)  or 0)) end
    if stat == "DD_DAMAGE_TAKEN" then return floor(max(0, tonumber(save.activity.damageTaken)  or 0)) end
    if stat == "DD_CRITS"        then return floor(max(0, tonumber(save.activity.crits)        or 0)) end
    if stat == "DD_STREAK"       then return floor(max(0, tonumber(save.activity.bestStreak)   or 0)) end
    return 0
end

-- ── Unlock ────────────────────────────────────────────────────────────────────
-- Coins go to the shared Cresh Coin pool (BattlePass:AddCoins).
-- XP goes to the Dungeon Dwellers Pass only — never to the Main Battle Pass.

function DungeonAchievements:Unlock(achievement, silent)
    local save = self:Ensure()
    if not save or not achievement or save.unlocked[achievement.key] then return false end

    save.unlocked[achievement.key] = {
        at           = now(),
        value        = self:GetStat(achievement.stat),
        sourceSystem = "DUNGEON_DWELLER_ACHIEVEMENTS",
        sourceId     = achievement.key,
        targetGame   = "DUNGEON_DWELLER",
    }

    if CC.BattlePass and CC.BattlePass.AddCoins then
        CC.BattlePass:AddCoins(achievement.coins, "DD_ACHIEVEMENT")
    end
    if CC.DungeonDwellersPass and CC.DungeonDwellersPass.AddXP then
        CC.DungeonDwellersPass:AddXP(achievement.xp, "DD Achievement: " .. achievement.title, nil, silent)
    end

    if not silent then
        local toastTitle = "Dungeon Achievement: " .. achievement.title
        local toastBody  = "+" .. tostring(achievement.coins) .. " Cresh Coins  ·  +" .. tostring(achievement.xp) .. " Delver XP"
        local toastKey   = "DD_ACH:" .. achievement.key
        if CC.UI and CC.UI.ShowDungeonPassToast then
            CC.UI:ShowDungeonPassToast(toastTitle, toastBody, toastKey)
        elseif CC.UI and CC.UI.ShowBattlePassToast then
            CC.UI:ShowBattlePassToast(toastTitle, toastBody, "DUNGEONPASS", toastKey)
        end
        if CC.GameAudio and CC.GameAudio.PlayEffect then CC.GameAudio:PlayEffect("LEVEL") end
    end
    return true
end

-- ── Evaluation ────────────────────────────────────────────────────────────────

function DungeonAchievements:EvaluateAll(silent)
    local save = self:Ensure()
    if not save or self.evaluating then return 0 end
    self.evaluating = true
    local unlocked = 0
    for _, achievement in ipairs(self.catalog) do
        if not save.unlocked[achievement.key] and self:GetStat(achievement.stat) >= achievement.goal then
            if self:Unlock(achievement, silent) then unlocked = unlocked + 1 end
        end
    end
    self.evaluating = false
    if unlocked > 0 and CC.UI then
        if CC.UI.RefreshConsoleEconomy then CC.UI:RefreshConsoleEconomy() end
    end
    return unlocked
end

-- ── Migration from WoW achievement table ─────────────────────────────────────
-- Pass 4 renamed the old GAMES/DD_* auto-generated keys to ACH_DD_KILLS_* etc.
-- Those records landed in gameProgression.achievements.unlocked (the WoW table).
-- This function moves them once into dungeon.ddAchievements.unlocked so that
-- the WoW and DD catalogs are fully separated. No coins or XP are re-awarded.

local MIGRATE_FROM_WOW = {
    "ACH_DD_KILLS_001","ACH_DD_KILLS_002","ACH_DD_KILLS_003","ACH_DD_KILLS_004","ACH_DD_KILLS_005",
    "ACH_DD_KILLS_006","ACH_DD_KILLS_007","ACH_DD_KILLS_008","ACH_DD_KILLS_009","ACH_DD_KILLS_010",
    "ACH_DD_BOSSES_001","ACH_DD_BOSSES_002","ACH_DD_BOSSES_003",
    "ACH_DD_BOSSES_004","ACH_DD_BOSSES_005","ACH_DD_BOSSES_006",
    "ACH_DD_BOSSES_007","ACH_DD_BOSSES_008","ACH_DD_BOSSES_009",
    "ACH_DD_UNIQUE_BOSSES_001","ACH_DD_UNIQUE_BOSSES_002","ACH_DD_UNIQUE_BOSSES_003",
    "ACH_DD_UNIQUE_BOSSES_004","ACH_DD_UNIQUE_BOSSES_005","ACH_DD_UNIQUE_BOSSES_006",
    "ACH_DD_UNIQUE_BOSSES_007",
    "ACH_DD_RUNS_001","ACH_DD_RUNS_002","ACH_DD_RUNS_003","ACH_DD_RUNS_004",
    "ACH_DD_RUNS_005","ACH_DD_RUNS_006","ACH_DD_RUNS_007",
}

function DungeonAchievements:MigrateFromWoW()
    local save = self:Ensure()
    if not save or save.migratedFromWoW then return 0 end

    local wowAch = CC.db
        and type(CC.db.gameProgression) == "table"
        and type(CC.db.gameProgression.achievements) == "table"
        and CC.db.gameProgression.achievements
        or nil
    local wowUnlocked = wowAch and type(wowAch.unlocked) == "table" and wowAch.unlocked or nil

    local moved = 0
    if wowUnlocked then
        for _, key in ipairs(MIGRATE_FROM_WOW) do
            local wowRecord = wowUnlocked[key]
            if wowRecord then
                local ddRecord = save.unlocked[key]
                if not ddRecord then
                    save.unlocked[key] = wowRecord
                else
                    -- Both present: keep earliest unlock time and highest stat value.
                    if type(wowRecord) == "table" and type(ddRecord) == "table" then
                        local wAt = tonumber(wowRecord.at) or 0
                        local dAt = tonumber(ddRecord.at)  or 0
                        if wAt > 0 and (dAt == 0 or wAt < dAt) then ddRecord.at = wAt end
                        local wVal = tonumber(wowRecord.value) or 0
                        local dVal = tonumber(ddRecord.value)  or 0
                        if wVal > dVal then ddRecord.value = wVal end
                    end
                end
                wowUnlocked[key] = nil
                moved = moved + 1
            end
        end
    end

    save.migratedFromWoW = true
    return moved
end

-- ── Helpers ───────────────────────────────────────────────────────────────────

function DungeonAchievements:GetCounts()
    local save = self:Ensure()
    local unlocked = 0
    for _, achievement in ipairs(self.catalog) do
        if save and save.unlocked[achievement.key] then unlocked = unlocked + 1 end
    end
    return unlocked, #self.catalog
end

function DungeonAchievements:IsUnlocked(key)
    local save = self:Ensure()
    return save and save.unlocked[tostring(key)] ~= nil or false
end

-- ── Recording API (stubs wired by DungeonContent in a future pass) ────────────
-- DungeonContent.lua should call these at the appropriate game events.
-- Each method updates the relevant activity counter and triggers EvaluateAll.

function DungeonAchievements:RecordKill()
    self:EvaluateAll(false)
end

function DungeonAchievements:RecordBoss()
    self:EvaluateAll(false)
end

function DungeonAchievements:RecordRunComplete()
    self:EvaluateAll(false)
end

function DungeonAchievements:RecordDamageDealt(amount)
    local save = self:Ensure()
    if not save then return end
    save.activity.damageDealt = (save.activity.damageDealt or 0) + floor(max(0, tonumber(amount) or 0))
end

function DungeonAchievements:RecordDamageTaken(amount)
    local save = self:Ensure()
    if not save then return end
    save.activity.damageTaken = (save.activity.damageTaken or 0) + floor(max(0, tonumber(amount) or 0))
end

function DungeonAchievements:RecordCrit()
    local save = self:Ensure()
    if not save then return end
    save.activity.crits = (save.activity.crits or 0) + 1
end

function DungeonAchievements:RecordCrateOpen()
    local save = self:Ensure()
    if not save then return end
    save.activity.cratesOpened = (save.activity.cratesOpened or 0) + 1
    self:EvaluateAll(false)
end

function DungeonAchievements:RecordStreakUpdate(streak)
    local save = self:Ensure()
    if not save then return end
    streak = floor(max(0, tonumber(streak) or 0))
    save.activity.currentStreak = streak
    save.activity.bestStreak    = max(save.activity.bestStreak or 0, streak)
    self:EvaluateAll(false)
end

-- ── Event registration ────────────────────────────────────────────────────────

local eventFrame = CreateFrame("Frame")
local function safeRegister(event)
    if eventFrame and eventFrame.RegisterEvent then pcall(eventFrame.RegisterEvent, eventFrame, event) end
end
safeRegister("PLAYER_LOGIN")

eventFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        DungeonAchievements:Ensure()
        if CC:IsFeatureEnabled("gameProgression") then
            DungeonAchievements:MigrateFromWoW()
            DungeonAchievements:EvaluateAll(true)
        end
    end
end)
