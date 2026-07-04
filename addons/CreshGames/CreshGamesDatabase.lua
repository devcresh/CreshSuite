-- CreshGames/Database.lua
-- Declares CreshGamesDB, applies defaults, and runs the one-time v1 migration
-- that imports legacy data from CreshChatDB.
-- Must appear before CreshGames.lua in the TOC.

local SCHEMA = 1

-- ============================================================
-- Utilities (local copies; Core.lua equivalents are not accessible here)
-- ============================================================

local function deepCopy(v)
    if type(v) ~= "table" then return v end
    local out = {}
    for k, c in pairs(v) do out[k] = deepCopy(c) end
    return out
end

local function mergeDefaults(tgt, src)
    for k, v in pairs(src) do
        if tgt[k] == nil then
            tgt[k] = deepCopy(v)
        elseif type(v) == "table" and type(tgt[k]) == "table" then
            mergeDefaults(tgt[k], v)
        end
    end
end

-- Merges src into tgt following progression-safe rules:
--   numbers  -> math.max(tgt, src)
--   booleans -> tgt or src
--   strings  -> keep non-empty tgt; accept non-empty src only when tgt is empty
--   tables   -> recurse (union, no deletion)
local function importProgressionValue(tgt, src)
    if src == nil then return tgt end
    if tgt == nil then return deepCopy(src) end
    local tt, ts = type(tgt), type(src)
    if tt ~= ts then return tgt end
    if ts == "number"  then return math.max(tgt, src) end
    if ts == "boolean" then return tgt or src end
    if ts == "string"  then return (tgt == "" and src ~= "") and src or tgt end
    if ts == "table" then
        for k, v in pairs(src) do
            tgt[k] = importProgressionValue(tgt[k], v)
        end
    end
    return tgt
end

-- ============================================================
-- Defaults
-- ============================================================

local DEFAULTS = {
    version = SCHEMA,
    soloGames = {
        frogger     = { unlocked=1, bestLevel=0, highScore=0, games=0 },
        holdem      = { wins=0, losses=0, bestChips=100, games=0, bankroll=100 },
        blackjack   = { wins=0, losses=0, pushes=0, bestBank=100, games=0, bankroll=100 },
        chess       = { wins=0, losses=0, draws=0, games=0, level=3, bestLevel=0 },
        higherlower = { wins=0, losses=0, draws=0, games=0, bankroll=100, bestBank=100, bestStreak=0 },
        dungeon = {
            runs=0, bestLevel=0, bestRoom=0, kills=0, bosses=0, minions=0,
            highScore=0, bossCoins=0, class="", permanentDamage=0,
            armourPity=0, voidCratePity=0, armourShards=0,
            portraitTokens=0, fullBodyTokens=0, classStatsMigrated=false,
            enemyKillsByType={}, bossKillsByType={}, firstBossKills={},
            unlockedArmour={}, equippedArmour={}, crateInventory={},
            crateHistory={}, pendingCrates={}, classStats={},
            unlockedMinions={}, minionRecruitsByType={},
            unlockedMinionSkins={}, minionSkinRecruits={}, discoveredItems={},
            battlePass={ xp=0, claimed={}, buffs={}, activity={},
                visitedZones={}, achievements={}, recent={} },
        },
        tetris = {
            wins=0, losses=0, games=0, highScore=0, bestLines=0,
            totalLines=0, vsWins=0, vsLosses=0, endlessRuns=0,
            cpuLevel=3, cpuVersusMode="ENDLESS", multiplayerMode="ENDLESS",
            multiplayerDuration=10, soloDuration=10, mode="ENDLESS",
            revealLines=0, revealCompleted=0, revealThemeKey="", revealBackgroundKey="",
            passXP=0, passClaimed={},
            unlockedThemes={ CLASSIC_BLOCKS=true },
            themeUnlockSources={ CLASSIC_BLOCKS="DEFAULT" },
            selectedTheme="CLASSIC_BLOCKS",
            unlockedBackgrounds={}, backgroundUnlockSources={}, selectedBackground="",
        },
    },
    arcadeRewards = {
        coins=0, lifetimeCoins=0, gameCoins=0, activityCoins=0,
        explorationCoins=0, spentCoins=0, passXP=0,
        claimed={}, unlockedThemes={}, themeUnlockSources={},
        recent={}, gamesRewarded=0, milestoneGoals={},
    },
    gameProgression = {
        games       = {},
        exploration = {
            totalSteps=0, rewardedStepBlocks=0, distanceRemainder=0,
            visitedAreas={}, visitedZones={}, newAreas=0, newZones=0,
            dungeonClears=0, totalKills=0, coins=0, passXP=0,
        },
        achievements = {},
    },
    gameHistory      = {},
    gameLeaderboards = {},
    multiplayerStats = {},
    launcher         = { showButton = false },
    _migration       = {},
}

local IMPORT_FIELDS = {
    "soloGames", "arcadeRewards", "gameProgression",
    "gameHistory", "gameLeaderboards", "multiplayerStats",
}

-- ============================================================
-- Migration
-- ============================================================

-- Imports legacy CreshChatDB data into dest (idempotent — runs once per install).
-- Prefers CreshChatDB.accountProgression over root-level compatibility aliases.
-- Never re-runs after the first successful completion.
local function MigrateFromCreshChat(dest)
    dest._migration = type(dest._migration) == "table" and dest._migration or {}
    local m = dest._migration
    m.v1 = type(m.v1) == "table" and m.v1 or {}
    if m.v1.done then return 0 end

    local src = _G.CreshChatDB
    if type(src) ~= "table" then
        m.v1.done     = true
        m.v1.at       = time and time() or 0
        m.v1.sourceDB = "none"
        return 0
    end

    -- Prefer accountProgression; fall back to root for installs that
    -- pre-date schema 70 (accountProgression was introduced at schema 70).
    local hasAccountProg = type(src.accountProgression) == "table"
    local srcProg = hasAccountProg and src.accountProgression or src
    local srcSchema = hasAccountProg
        and (tonumber(srcProg.migratedSchema) or tonumber(src.version) or 0)
        or   tonumber(src.version) or 0

    local imported = 0
    for _, field in ipairs(IMPORT_FIELDS) do
        local srcField = srcProg[field]
        if type(srcField) == "table" then
            -- importProgressionValue applies max-values + union-collections rules
            -- in case dest already has partial data from a concurrent source.
            dest[field] = importProgressionValue(dest[field], srcField)
            mergeDefaults(dest[field], DEFAULTS[field] or {})
            imported = imported + 1
        end
    end

    m.v1.done                 = true
    m.v1.at                   = time and time() or 0
    m.v1.sourceDB             = "CreshChatDB"
    m.v1.sourceSchema         = srcSchema
    m.v1.usedAccountProgression = hasAccountProg
    m.v1.fieldsImported       = imported
    return imported
end

-- ============================================================
-- Initialisation
-- ============================================================

local function InitGamesDB()
    CreshGamesDB = CreshGamesDB or {}
    if not CreshGamesDB.version then CreshGamesDB.version = SCHEMA end
    -- Migration must see a table with no defaults pre-filled, otherwise fields
    -- like selectedTheme already hold a non-empty default string and look
    -- "already set" to importProgressionValue, so the legacy value is skipped.
    MigrateFromCreshChat(CreshGamesDB)
    mergeDefaults(CreshGamesDB, DEFAULTS)
end

-- ============================================================
-- Public surface (used by tests and the diagnostic command)
-- ============================================================

_G.CreshGamesDatabase = {
    SCHEMA              = SCHEMA,
    Init                = InitGamesDB,
    MigrateFromCreshChat = function(dest) return MigrateFromCreshChat(dest or CreshGamesDB) end,
    GetMigrationStatus  = function()
        if type(CreshGamesDB) ~= "table" then return nil end
        local m = type(CreshGamesDB._migration) == "table" and CreshGamesDB._migration or {}
        return type(m.v1) == "table" and m.v1 or {}
    end,
}

-- ============================================================
-- WoW event wiring
-- ============================================================

local _dbFrame = CreateFrame("Frame", "CreshGamesDatabaseFrame")
_dbFrame:RegisterEvent("ADDON_LOADED")
_dbFrame:SetScript("OnEvent", function(_, _, addonName)
    if addonName == "CreshGames" then
        InitGamesDB()
    end
end)
