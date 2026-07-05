-- CreshCollect/CreshCollectDatabase.lua
-- Schema 2: adds arcadeRewards (Battle Pass), gameProgression (game levels +
-- exploration), and ddAchievements (Dungeon Dwellers achievement tracking).
-- The v1 migration (achievements + collection unlocks from CreshChatDB) is
-- preserved.  The v2 migration imports the Battle Pass and game progression
-- tables from CreshChatDB so no progress is lost on first upgrade.
--
-- The v3 migration is a safety net, not a new schema: CreshGamesDB ran its
-- own one-time import of the same legacy CreshChatDB data (see
-- CreshGames/CreshGamesDatabase.lua MigrateFromCreshChat) and CreshCollect is
-- now the sole authoritative owner of achievement/Battle Pass/collection
-- state going forward. If CreshGames and CreshCollect were installed at
-- different times, each addon's one-time import could have captured a
-- different point-in-time snapshot of CreshChatDB. v3 folds anything
-- CreshGamesDB has that CreshCollectDB is missing back in. CreshGamesDB
-- itself is never written to again after its own migration, so this is a
-- one-directional backfill, not an ongoing sync, and it is safe to leave
-- enabled indefinitely.
--
-- CreshCollect never reads CreshGamesDB directly (each addon's SavedVariables
-- are private — see Validate-Addons.ps1's cross-addon DB check); this reads
-- through CreshGames' guarded "GetLegacyProgressionSnapshot" Suite service.
--   Source:      CreshGamesDB.arcadeRewards.{claimed,unlockedThemes,themeUnlockSources}
--                CreshGamesDB.gameProgression.achievements.{unlocked,progress,stats}
--                (via CreshSuite:GetService("GetLegacyProgressionSnapshot"))
--   Destination: CreshCollectDB.arcadeRewards.{claimed,unlockedThemes,themeUnlockSources}
--                CreshCollectDB.achievements.{unlocked,progress,stats}
-- Union/max-only (via unionUnlocks / importProgressionValue below): a value
-- already present in CreshCollectDB is never removed, downgraded, or
-- replaced by an older CreshGamesDB value.

local SCHEMA = 2

-- ============================================================
-- Utilities (also exported for tests)
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

local function unionUnlocks(dest, src)
    if type(src) ~= "table" then return end
    for k, v in pairs(src) do
        if dest[k] == nil then dest[k] = v end
    end
end

-- ============================================================
-- Defaults
-- ============================================================

local DEFAULTS = {
    version = SCHEMA,

    -- Battle Pass: Cresh Coins, Pass XP, claimed level rewards, theme unlocks.
    arcadeRewards = {
        coins              = 0,
        lifetimeCoins      = 0,
        gameCoins          = 0,
        activityCoins      = 0,
        explorationCoins   = 0,
        spentCoins         = 0,
        passXP             = 0,
        claimed            = {},
        unlockedThemes     = {},
        themeUnlockSources = {},
        recent             = {},
        gamesRewarded      = 0,
        milestoneGoals     = {},
    },

    -- Game progression: per-game level records + WoW exploration counters.
    gameProgression = {
        games = {},
        exploration = {
            totalSteps           = 0,
            rewardedStepBlocks   = 0,
            distanceRemainder    = 0,
            visitedAreas         = {},
            visitedZones         = {},
            newAreas             = 0,
            newZones             = 0,
            dungeonClears        = 0,
            totalKills           = 0,
            coins                = 0,
            passXP               = 0,
        },
    },

    -- WoW achievements: unlock records, activity stats, profile tracking.
    achievements = {
        unlocked         = {},
        progress         = {},
        stats            = {},
        uniqueBosses     = {},
        professionRanks  = {},
        visitedZones     = {},
        totalCoins       = 0,
        totalPassXP      = 0,
    },

    -- Dungeon Dwellers achievements: tracked separately from the game state.
    ddAchievements = {
        unlocked  = {},
        activity  = {},
    },

    -- Collectible unlocks mirrored from CreshGames via Suite events.
    collections = {
        themes        = {},
        backgrounds   = {},
        cardDecks     = {},
        dungeonArmour = {},
        cosmetics     = {},
    },

    launcher   = { showAchievements = false, showProgress = false },
    _migration = {},
}

-- ============================================================
-- v1 Migration: achievements + collection unlocks from CreshChatDB
-- ============================================================

local function runV1Migration(dest)
    local m = dest._migration
    m.v1 = type(m.v1) == "table" and m.v1 or {}
    if m.v1.done then return 0 end

    local src = _G.CreshChatDB
    if type(src) ~= "table" then
        m.v1.done = true; m.v1.at = (time and time() or 0); m.v1.sourceDB = "none"
        return 0
    end

    local hasAccountProg = type(src.accountProgression) == "table"
    local srcProg = hasAccountProg and src.accountProgression or src
    local srcSchema = hasAccountProg
        and (tonumber(srcProg.migratedSchema) or tonumber(src.version) or 0)
        or   tonumber(src.version) or 0

    local imported = 0

    local srcAch = type(srcProg.gameProgression) == "table"
        and type(srcProg.gameProgression.achievements) == "table"
        and srcProg.gameProgression.achievements or nil
    if srcAch then
        dest.achievements.unlocked = importProgressionValue(dest.achievements.unlocked, srcAch.unlocked)
        if type(srcAch.progress) == "table" then
            dest.achievements.progress = importProgressionValue(dest.achievements.progress, srcAch.progress)
        end
        imported = imported + 1
    end

    local srcTetris = type(srcProg.soloGames) == "table"
        and type(srcProg.soloGames.tetris) == "table"
        and srcProg.soloGames.tetris or nil
    if srcTetris then
        unionUnlocks(dest.collections.themes,      srcTetris.unlockedThemes)
        unionUnlocks(dest.collections.backgrounds, srcTetris.unlockedBackgrounds)
        imported = imported + 1
    end

    local srcArcade = type(srcProg.arcadeRewards) == "table" and srcProg.arcadeRewards or nil
    if srcArcade then
        unionUnlocks(dest.collections.themes, srcArcade.unlockedThemes)
        imported = imported + 1
    end

    local srcDungeon = type(srcProg.soloGames) == "table"
        and type(srcProg.soloGames.dungeon) == "table"
        and srcProg.soloGames.dungeon or nil
    if srcDungeon then
        unionUnlocks(dest.collections.dungeonArmour, srcDungeon.unlockedArmour)
        imported = imported + 1
    end

    mergeDefaults(dest.achievements, DEFAULTS.achievements)
    mergeDefaults(dest.collections,  DEFAULTS.collections)

    m.v1.done                   = true
    m.v1.at                     = time and time() or 0
    m.v1.sourceDB               = "CreshChatDB"
    m.v1.sourceSchema           = srcSchema
    m.v1.usedAccountProgression = hasAccountProg
    m.v1.sectionsImported       = imported
    return imported
end

-- ============================================================
-- v2 Migration: Battle Pass + game progression from CreshChatDB
-- ============================================================

local function runV2Migration(dest)
    local m = dest._migration
    m.v2 = type(m.v2) == "table" and m.v2 or {}
    if m.v2.done then return 0 end

    local src = _G.CreshChatDB
    if type(src) ~= "table" then
        m.v2.done = true; m.v2.at = (time and time() or 0)
        return 0
    end

    local hasAccountProg = type(src.accountProgression) == "table"
    local srcProg = hasAccountProg and src.accountProgression or src
    local imported = 0

    -- Battle Pass: coins, pass XP, claimed rewards, theme unlocks.
    local srcArcade = type(srcProg.arcadeRewards) == "table" and srcProg.arcadeRewards or nil
    if srcArcade then
        local dst = dest.arcadeRewards
        local function importNum(key)
            local v = tonumber(srcArcade[key])
            if v and v > (tonumber(dst[key]) or 0) then dst[key] = math.floor(v) end
        end
        importNum("coins"); importNum("lifetimeCoins"); importNum("gameCoins")
        importNum("activityCoins"); importNum("explorationCoins"); importNum("spentCoins")
        importNum("passXP"); importNum("gamesRewarded")
        -- Claimed rewards: union (never remove).
        if type(srcArcade.claimed) == "table" then
            unionUnlocks(dst.claimed, srcArcade.claimed)
        end
        -- Theme unlocks: union.
        if type(srcArcade.unlockedThemes) == "table" then
            unionUnlocks(dst.unlockedThemes, srcArcade.unlockedThemes)
        end
        if type(srcArcade.themeUnlockSources) == "table" then
            for k, v in pairs(srcArcade.themeUnlockSources) do
                if dst.themeUnlockSources[k] == nil then dst.themeUnlockSources[k] = v end
            end
        end
        if type(srcArcade.milestoneGoals) == "table" then
            unionUnlocks(dst.milestoneGoals, srcArcade.milestoneGoals)
        end
        imported = imported + 1
    end

    -- Game progression: per-game level records.
    local srcGameProg = type(srcProg.gameProgression) == "table" and srcProg.gameProgression or nil
    if srcGameProg then
        -- Per-game level tables.
        if type(srcGameProg.games) == "table" then
            for game, rec in pairs(srcGameProg.games) do
                if type(rec) == "table" then
                    dest.gameProgression.games[game] = dest.gameProgression.games[game] or {}
                    local dst = dest.gameProgression.games[game]
                    local function importRec(key)
                        local v = tonumber(rec[key])
                        if v and v > (tonumber(dst[key]) or 0) then dst[key] = math.floor(v) end
                    end
                    importRec("level"); importRec("xp"); importRec("plays")
                    importRec("wins");  importRec("draws"); importRec("losses")
                    if tonumber(rec.lastPlayed) and (tonumber(rec.lastPlayed) or 0) > (tonumber(dst.lastPlayed) or 0) then
                        dst.lastPlayed = rec.lastPlayed
                    end
                end
            end
        end
        -- Exploration counters.
        local srcExp = type(srcGameProg.exploration) == "table" and srcGameProg.exploration or nil
        if srcExp then
            local dstExp = dest.gameProgression.exploration
            local function importExpNum(key)
                local v = tonumber(srcExp[key])
                if v and v > (tonumber(dstExp[key]) or 0) then dstExp[key] = math.floor(v) end
            end
            importExpNum("totalSteps"); importExpNum("rewardedStepBlocks")
            importExpNum("newAreas");   importExpNum("newZones")
            importExpNum("dungeonClears"); importExpNum("totalKills")
            importExpNum("coins");      importExpNum("passXP")
            if type(srcExp.distanceRemainder) == "number" then
                dstExp.distanceRemainder = math.max(dstExp.distanceRemainder, srcExp.distanceRemainder)
            end
            if type(srcExp.visitedAreas) == "table" then
                for k, v in pairs(srcExp.visitedAreas) do
                    if dstExp.visitedAreas[k] == nil then dstExp.visitedAreas[k] = deepCopy(v) end
                end
            end
            if type(srcExp.visitedZones) == "table" then
                for k, v in pairs(srcExp.visitedZones) do
                    if dstExp.visitedZones[k] == nil then dstExp.visitedZones[k] = deepCopy(v) end
                end
            end
        end
        -- Achievement stats that live inside gameProgression.achievements.
        local srcAch = type(srcGameProg.achievements) == "table" and srcGameProg.achievements or nil
        if srcAch then
            if type(srcAch.stats) == "table" then
                importProgressionValue(dest.achievements.stats, srcAch.stats)
            end
            if type(srcAch.uniqueBosses) == "table" then
                for k, v in pairs(srcAch.uniqueBosses) do
                    if dest.achievements.uniqueBosses[k] == nil then
                        dest.achievements.uniqueBosses[k] = deepCopy(v)
                    end
                end
            end
            if type(srcAch.professionRanks) == "table" then
                for k, v in pairs(srcAch.professionRanks) do
                    local dv = tonumber(dest.achievements.professionRanks[k]) or 0
                    local sv = tonumber(v) or 0
                    if sv > dv then dest.achievements.professionRanks[k] = sv end
                end
            end
            if type(srcAch.visitedZones) == "table" then
                for k, v in pairs(srcAch.visitedZones) do
                    if dest.achievements.visitedZones[k] == nil then
                        dest.achievements.visitedZones[k] = deepCopy(v)
                    end
                end
            end
            local function importAchNum(key)
                local v = tonumber(srcAch[key])
                if v and v > (tonumber(dest.achievements[key]) or 0) then
                    dest.achievements[key] = math.floor(v)
                end
            end
            importAchNum("totalCoins"); importAchNum("totalPassXP")
        end
        imported = imported + 1
    end

    -- DD achievements: migrate from CC.db.soloGames.dungeon.ddAchievements.
    local srcDD = type(srcProg.soloGames) == "table"
        and type(srcProg.soloGames.dungeon) == "table"
        and type(srcProg.soloGames.dungeon.ddAchievements) == "table"
        and srcProg.soloGames.dungeon.ddAchievements or nil
    if srcDD then
        if type(srcDD.unlocked) == "table" then
            for k, v in pairs(srcDD.unlocked) do
                if dest.ddAchievements.unlocked[k] == nil then
                    dest.ddAchievements.unlocked[k] = deepCopy(v)
                end
            end
        end
        if type(srcDD.activity) == "table" then
            importProgressionValue(dest.ddAchievements.activity, srcDD.activity)
        end
        imported = imported + 1
    end

    mergeDefaults(dest.arcadeRewards,    DEFAULTS.arcadeRewards)
    mergeDefaults(dest.gameProgression,  DEFAULTS.gameProgression)
    mergeDefaults(dest.achievements,     DEFAULTS.achievements)
    mergeDefaults(dest.ddAchievements,   DEFAULTS.ddAchievements)

    m.v2.done     = true
    m.v2.at       = time and time() or 0
    m.v2.imported = imported
    return imported
end

-- ============================================================
-- v3 Migration: safety-net import from CreshGamesDB
-- ============================================================
-- See the file-header comment above for the full rationale. CreshCollect
-- must never read CreshGamesDB directly (each addon's SavedVariables are
-- private to it — see Validate-Addons.ps1's cross-addon DB check), so this
-- goes through CreshGames' own guarded "GetLegacyProgressionSnapshot" Suite
-- service instead, which is nil-safe if CreshGames isn't installed.
--
-- Load order safety: CreshCollect and CreshGames declare no Dependencies, so
-- either may finish loading first. If CreshGames hasn't registered the
-- service yet when CreshCollect's own ADDON_LOADED fires, isFinalAttempt is
-- false and this returns without marking m.v3.done, so InitCollectDB's
-- PLAYER_LOGIN safety-net call (which always fires after every addon has
-- loaded) gets a second try with isFinalAttempt = true. Only that final
-- attempt is allowed to permanently record sourceDB = "none".
--
-- Idempotent: never re-runs once done, and even if it did, unionUnlocks /
-- importProgressionValue only ever add or raise values, never remove or
-- lower them, so re-running would be harmless.

local function runV3Migration(dest, isFinalAttempt)
    local m = dest._migration
    m.v3 = type(m.v3) == "table" and m.v3 or {}
    if m.v3.done then return 0 end

    local Suite = _G.CreshSuite
    local getSnapshot = Suite and Suite.GetService and Suite:GetService("GetLegacyProgressionSnapshot")
    local snapshot = getSnapshot and getSnapshot() or nil

    if type(snapshot) ~= "table" then
        if not isFinalAttempt then return 0 end
        m.v3.done = true; m.v3.at = (time and time() or 0); m.v3.sourceDB = "none"
        return 0
    end

    local imported = 0

    if type(snapshot.arcadeRewardsClaimed) == "table" then
        unionUnlocks(dest.arcadeRewards.claimed, snapshot.arcadeRewardsClaimed)
        imported = imported + 1
    end
    if type(snapshot.arcadeRewardsUnlockedThemes) == "table" then
        unionUnlocks(dest.arcadeRewards.unlockedThemes, snapshot.arcadeRewardsUnlockedThemes)
    end
    if type(snapshot.arcadeRewardsThemeSources) == "table" then
        for k, v in pairs(snapshot.arcadeRewardsThemeSources) do
            if dest.arcadeRewards.themeUnlockSources[k] == nil then dest.arcadeRewards.themeUnlockSources[k] = v end
        end
    end

    if type(snapshot.achievementsUnlocked) == "table" then
        unionUnlocks(dest.achievements.unlocked, snapshot.achievementsUnlocked)
        imported = imported + 1
    end
    if type(snapshot.achievementsProgress) == "table" then
        dest.achievements.progress = importProgressionValue(dest.achievements.progress, snapshot.achievementsProgress)
    end
    if type(snapshot.achievementsStats) == "table" then
        dest.achievements.stats = importProgressionValue(dest.achievements.stats, snapshot.achievementsStats)
    end

    m.v3.done     = true
    m.v3.at       = time and time() or 0
    m.v3.sourceDB = "CreshGames"
    m.v3.imported = imported
    return imported
end

-- ============================================================
-- Initialisation
-- ============================================================

local function InitCollectDB()
    CreshCollectDB = CreshCollectDB or {}
    if not CreshCollectDB.version then CreshCollectDB.version = SCHEMA end
    mergeDefaults(CreshCollectDB, DEFAULTS)
    CreshCollectDB._migration = type(CreshCollectDB._migration) == "table" and CreshCollectDB._migration or {}
    runV1Migration(CreshCollectDB)
    runV2Migration(CreshCollectDB)
    runV3Migration(CreshCollectDB, false)
    CreshCollectDB.version = SCHEMA
end

-- ============================================================
-- Public surface (used by tests and the diagnostic command)
-- ============================================================

_G.CreshCollectDatabase = {
    SCHEMA               = SCHEMA,
    Init                 = InitCollectDB,
    MigrateFromCreshChat = function(dest) return runV2Migration(dest or CreshCollectDB) end,
    GetMigrationStatus   = function()
        if type(CreshCollectDB) ~= "table" then return nil end
        local m = type(CreshCollectDB._migration) == "table" and CreshCollectDB._migration or {}
        return {
            v1 = type(m.v1) == "table" and m.v1 or {},
            v2 = type(m.v2) == "table" and m.v2 or {},
            v3 = type(m.v3) == "table" and m.v3 or {},
        }
    end,
}

-- ============================================================
-- WoW event wiring
-- ============================================================

local _dbFrame = CreateFrame("Frame", "CreshCollectDatabaseFrame")
_dbFrame:RegisterEvent("ADDON_LOADED")
_dbFrame:RegisterEvent("PLAYER_LOGIN")
_dbFrame:SetScript("OnEvent", function(_, event, addonName)
    if event == "ADDON_LOADED" then
        if addonName == "CreshCollect" then
            InitCollectDB()
        end
    elseif event == "PLAYER_LOGIN" then
        -- Final-attempt safety net: every addon has finished loading by now
        -- regardless of TOC/alphabetical load order, so if CreshGames is
        -- installed its Suite service is guaranteed to be registered here.
        if type(CreshCollectDB) == "table" then
            runV3Migration(CreshCollectDB, true)
        end
    end
end)
