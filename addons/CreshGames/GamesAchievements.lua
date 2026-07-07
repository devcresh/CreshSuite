-- CreshGames/GamesAchievements.lua
-- Rework Phase 5: CreshGames' own achievement system. Moved here from
-- CreshCollect (the old "GAMES" category inside Achievements.lua, 23
-- entries) so CreshCollect can go back to reporting only World of Warcraft
-- achievements. Dungeon Dwellers' 93 achievements are merged in by
-- GamesDungeonAchievements.lua the same way CreshCollect's own
-- AchievementExpansion.lua/ClassAchievements.lua extend a shared catalog.
--
-- State lives in CreshGamesDB.achievements -- a brand-new table. Existing
-- players' completions from CreshCollect's old catalogs are imported once
-- per achievement via SyncLegacyCompletions() below (never re-granting
-- rewards), reached only through the guarded CreshSuite service
-- CreshCollect exposes -- this file never reads CreshCollectDB directly.
local _, CG = ...
if not CG then return end

local CC = setmetatable({}, { __index = function(_, k)
    local c = _G.CreshChat
    return c and c[k]
end })

local Achievements = {
    version = CG.version,
    catalog = {},
    byKey = {},
    categoryOrder = {
        "ARCADE", "MULTIPLAYER", "TETRIS", "FROGGER", "CHESS", "CARDGAMES", "PONG",
        "DUNGEON_DWELLERS", "COLLECTION",
    },
    categoryNames = {
        ARCADE = "Arcade",
        MULTIPLAYER = "Multiplayer",
        TETRIS = "Tetris",
        FROGGER = "Frogger",
        CHESS = "Chess",
        CARDGAMES = "Card Games",
        PONG = "Pong",
        DUNGEON_DWELLERS = "Dungeon Dwellers",
        COLLECTION = "Collection",
    },
}
CG.Achievements = Achievements
if CG.RegisterModule then CG:RegisterModule("Achievements", Achievements) end

local floor, max, min = math.floor, math.max, math.min
local upper = string.upper

local function now()
    if type(_G.GetServerTime) == "function" then return _G.GetServerTime() end
    if type(_G.time) == "function" then return _G.time() end
    if type(_G.GetTime) == "function" then return floor(_G.GetTime()) end
    return 0
end

local function formatNumber(value)
    local text = tostring(floor(max(0, tonumber(value) or 0)))
    local grouped = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    if grouped:sub(1, 1) == "," then grouped = grouped:sub(2) end
    return grouped
end

-- ── Catalog ───────────────────────────────────────────────────────────────────
-- Same reward formula as CreshCollect's Achievements.lua (unchanged, so the
-- 23 ported entries pay exactly what they always did).
local function rewardFor(index, weight)
    index = max(1, tonumber(index) or 1)
    weight = max(1, tonumber(weight) or 1)
    local coins = 4 + (index * 4 * weight)
    local xp = 4 + (index * 3 * weight)
    if index >= 6 then
        coins = coins + ((index - 5) * 8 * weight)
        xp = xp + ((index - 5) * 6 * weight)
    end
    return floor(coins), floor(xp)
end

-- coinsOverride/xpOverride let other files (GamesDungeonAchievements.lua)
-- merge entries into this catalog using their own reward formula instead of
-- rewardFor above -- mirrors how CreshCollect's AchievementExpansion.lua
-- supplies its own coins/xp per entry rather than reusing Achievements.lua's.
function Achievements:Add(category, stat, goal, title, description, index, weight, stableKey, coinsOverride, xpOverride)
    local coins, xp
    if coinsOverride ~= nil and xpOverride ~= nil then
        coins, xp = coinsOverride, xpOverride
    else
        coins, xp = rewardFor(index, weight)
    end
    local key = stableKey or upper(category .. "_" .. stat .. "_" .. tostring(goal))
    local achievement = {
        key = key,
        category = category,
        stat = stat,
        goal = goal,
        title = title,
        description = description,
        coins = coins,
        xp = xp,
        tier = index,
    }
    self.catalog[#self.catalog + 1] = achievement
    self.byKey[key] = achievement
end

local function addSeries(self, category, stat, goals, titles, description, weight, stableKeys)
    for index, goal in ipairs(goals) do
        local title = titles[index] or ((self.categoryNames[category] or category) .. " " .. tostring(index))
        self:Add(category, stat, goal, title, description(goal, index), index, weight, stableKeys and stableKeys[index])
    end
end

function Achievements:BuildCatalog()
    if #self.catalog > 0 then return end

    -- Ported from CreshCollect/Achievements.lua's "GAMES" category (Rework
    -- Phase 5). Keys are unchanged from their original names for migration
    -- continuity, even though "WOW" in the key string is a historical
    -- artifact of the shared key-prefix convention they were created under.
    addSeries(self, "ARCADE", "GAME_PLAYS",
        { 1, 10, 25, 50, 100, 250 },
        { "Game On", "Arcade Regular", "Twenty-Five Plays", "Game Night", "Arcade Veteran", "Cresh Games Loyalist" },
        function(goal) return "Complete or start " .. formatNumber(goal) .. " Cresh game sessions." end, 1,
        { "ACH_WOW_GAME_PLAYS_001", "ACH_WOW_GAME_PLAYS_002", "ACH_WOW_GAME_PLAYS_003",
          "ACH_WOW_GAME_PLAYS_004", "ACH_WOW_GAME_PLAYS_005", "ACH_WOW_GAME_PLAYS_006" })

    addSeries(self, "ARCADE", "GAME_WINS",
        { 1, 10, 25, 50, 100 },
        { "First Win", "Winning Habit", "Arcade Champion", "Fifty Victories", "Century Champion" },
        function(goal) return "Win " .. formatNumber(goal) .. " Cresh games." end, 2,
        { "ACH_WOW_GAME_WINS_001", "ACH_WOW_GAME_WINS_002", "ACH_WOW_GAME_WINS_003",
          "ACH_WOW_GAME_WINS_004", "ACH_WOW_GAME_WINS_005" })

    addSeries(self, "ARCADE", "GAME_LEVELS",
        { 5, 10, 25, 50, 100, 250 },
        { "Level Collector", "Double Digits", "Growing Arcade", "Fifty Combined Levels", "Century of Levels", "Account Arcade Master" },
        function(goal) return "Reach " .. formatNumber(goal) .. " combined levels across Cresh games." end, 1,
        { "ACH_WOW_GAME_LEVELS_001", "ACH_WOW_GAME_LEVELS_002", "ACH_WOW_GAME_LEVELS_003",
          "ACH_WOW_GAME_LEVELS_004", "ACH_WOW_GAME_LEVELS_005", "ACH_WOW_GAME_LEVELS_006" })

    addSeries(self, "COLLECTION", "UNLOCKS",
        { 1, 5, 10, 25, 50, 100 },
        { "First Unlock", "Collection Started", "Ten Treasures", "Unlock Hunter", "Collection Curator", "Vault Keeper" },
        function(goal) return "Own " .. formatNumber(goal) .. " decks, Tetris themes/backgrounds, dungeon armour or minions." end, 2,
        { "ACH_WOW_UNLOCKS_001", "ACH_WOW_UNLOCKS_002", "ACH_WOW_UNLOCKS_003",
          "ACH_WOW_UNLOCKS_004", "ACH_WOW_UNLOCKS_005", "ACH_WOW_UNLOCKS_006" })
end

-- ── Save ──────────────────────────────────────────────────────────────────────

local function achievementsRoot()
    if not _G.CreshGamesDB then return nil end
    _G.CreshGamesDB.achievements = type(_G.CreshGamesDB.achievements) == "table" and _G.CreshGamesDB.achievements or {}
    return _G.CreshGamesDB.achievements
end

function Achievements:Ensure()
    self:BuildCatalog()
    local save = achievementsRoot()
    if not save then return nil end
    save.unlocked = type(save.unlocked) == "table" and save.unlocked or {}
    save.totalCoins = floor(max(0, tonumber(save.totalCoins) or 0))
    save.totalXP = floor(max(0, tonumber(save.totalXP) or 0))
    return save
end

-- ── Stat readers ──────────────────────────────────────────────────────────────
-- Same-addon reads only -- never CreshCollectDB. Fixes a staleness bug that
-- existed in the old CreshCollect location: GAME_PLAYS/WINS/LEVELS used to
-- read CreshCollectDB.gameProgression.games, which stopped being written to
-- after the Phase 10 CreshGames/CreshCollect split -- those achievements
-- were frozen in place for anyone playing after that split. Reading
-- CreshGamesDB.gameLevels directly (the live per-game record) fixes this.
local GAME_KEYS = { "FROGGER", "DUNGEON", "CHESS", "HOLDEM", "BLACKJACK", "HIGHERLOWER", "TETRIS", "PONG" }

function Achievements:GetGameTotals()
    local plays, wins, levels = 0, 0, 0
    local games = CG.GameProgression and CG.GameProgression:Ensure() or {}
    for _, game in ipairs(GAME_KEYS) do
        local record = games[game] or {}
        plays = plays + floor(max(0, tonumber(record.plays) or tonumber(record.starts) or 0))
        wins = wins + floor(max(0, tonumber(record.wins) or 0))
        levels = levels + floor(max(1, tonumber(record.level) or 1))
    end
    return plays, wins, levels
end

local function countTrueOrTables(tbl)
    local count = 0
    for _, value in pairs(tbl or {}) do
        if value == true or type(value) == "table" then count = count + 1 end
    end
    return count
end

-- Counts only CreshGames-owned unlockables (decks, Tetris themes/
-- backgrounds, Dungeon armour/minions). The old CreshCollect version of this
-- achievement also counted CreshChat theme unlocks earned through
-- CreshCollect's own pass -- that source is CreshCollect-owned and dropped
-- here, since counting it would require reading CreshCollectDB directly.
function Achievements:GetUnlockCount()
    local total = 0
    if CG.CardDecks then
        local save = CG.CardDecks:Ensure()
        if save then total = total + countTrueOrTables(save.unlocked) end
    end
    if CG.Tetris then
        local save = CG.Tetris:Ensure()
        if save then
            total = total + countTrueOrTables(save.unlockedThemes)
            total = total + countTrueOrTables(save.unlockedBackgrounds)
        end
    end
    if CG.DungeonDwellersPass then
        local _, dungeon = CG.DungeonDwellersPass:Ensure()
        if dungeon then
            total = total + countTrueOrTables(dungeon.unlockedArmour)
            total = total + countTrueOrTables(dungeon.unlockedMinions)
        end
    end
    return total
end

function Achievements:GetStat(stat)
    if stat == "GAME_PLAYS" or stat == "GAME_WINS" or stat == "GAME_LEVELS" then
        local plays, wins, levels = self:GetGameTotals()
        if stat == "GAME_PLAYS" then return plays end
        if stat == "GAME_WINS" then return wins end
        return levels
    end
    if stat == "UNLOCKS" then return self:GetUnlockCount() end
    return 0
end

-- ── Unlock / evaluate ─────────────────────────────────────────────────────────

function Achievements:IsUnlocked(key)
    local save = self:Ensure()
    return save and save.unlocked[tostring(key)] ~= nil or false
end

function Achievements:Unlock(achievement, silent)
    local save = self:Ensure()
    if not save or not achievement or save.unlocked[achievement.key] then return false end
    save.unlocked[achievement.key] = {
        at = now(),
        value = self:GetStat(achievement.stat),
        sourceSystem = "CRESHGAMES_ACHIEVEMENTS",
        sourceId = achievement.key,
        targetGame = achievement.category,
    }
    save.totalCoins = save.totalCoins + achievement.coins
    save.totalXP = save.totalXP + achievement.xp

    if CG.BattlePass then
        if CG.BattlePass.AddCoins then CG.BattlePass:AddCoins(achievement.coins, "ACHIEVEMENT") end
        -- Same-addon now: call the Arcade Pass XP source directly instead of
        -- the Suite publish/subscribe round-trip GamesBattlePass.lua used
        -- while this catalog was still CreshCollect-owned (Rework Phase 3).
        if CG.BattlePass.AwardAchievementCompletion then CG.BattlePass:AwardAchievementCompletion(silent) end
    end

    if not silent then
        CG:ShowAchievementToast("Achievement: " .. achievement.title,
            "+" .. tostring(achievement.coins) .. " Cresh Coins · +" .. tostring(achievement.xp) .. " Arcade Pass XP",
            "GAMESACH:" .. achievement.key)
    end
    if not silent and CG.GameAudio and CG.GameAudio.PlayEffect then CG.GameAudio:PlayEffect("LEVEL") end
    return true
end

function Achievements:EvaluateAll(silent)
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
    if unlocked > 0 and CC.UI and CC.UI.RefreshConsoleEconomy then CC.UI:RefreshConsoleEconomy() end
    return unlocked
end

function Achievements:GetCounts(category)
    local save = self:Ensure()
    local unlocked, total = 0, 0
    for _, achievement in ipairs(self.catalog) do
        if not category or achievement.category == category then
            total = total + 1
            if save and save.unlocked[achievement.key] then unlocked = unlocked + 1 end
        end
    end
    return unlocked, total
end

-- ── Migration: import completions from CreshCollect's pre-move catalogs ──────
-- Reads only through the guarded CreshSuite service CreshCollect exposes
-- (GetLegacyGameAchievements) -- never CreshCollectDB directly. Safe to call
-- on every login: each key imports at most once (the `not save.unlocked[key]`
-- guard), so if CreshCollect becomes available later (or wasn't loaded at
-- an earlier login), the next sync safely unions in anything new without
-- ever re-granting a reward for an already-imported completion.
function Achievements:SyncLegacyCompletions()
    local save = self:Ensure()
    if not save then return 0 end
    local suite = _G.CreshSuite
    local getter = suite and suite.GetService and suite:GetService("GetLegacyGameAchievements")
    local snapshot = getter and getter()
    if type(snapshot) ~= "table" then return 0 end

    local imported = 0
    local function importFrom(sourceTable)
        if type(sourceTable) ~= "table" then return end
        for key, record in pairs(sourceTable) do
            if self.byKey[key] and not save.unlocked[key] then
                save.unlocked[key] = record
                imported = imported + 1
            end
        end
    end
    -- Two source tables: the 23 ex-GAMES keys (and any historically stray
    -- ACH_DD_* keys -- see CreshCollect/DungeonAchievements.lua's old
    -- MigrateFromWoW, whose job this subsumes) live in achievementsUnlocked;
    -- the 93 Dungeon Dwellers keys live in dungeonUnlocked. Filtering by
    -- self.byKey means only keys THIS catalog actually defines are imported.
    importFrom(snapshot.achievementsUnlocked)
    importFrom(snapshot.dungeonUnlocked)
    return imported
end

-- ── Event registration ────────────────────────────────────────────────────────

local eventFrame = CreateFrame("Frame")
local function safeRegister(event)
    if eventFrame and eventFrame.RegisterEvent then pcall(eventFrame.RegisterEvent, eventFrame, event) end
end
safeRegister("PLAYER_LOGIN")

eventFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        Achievements:Ensure()
        Achievements:SyncLegacyCompletions()
        Achievements:EvaluateAll(true)
    end
end)
