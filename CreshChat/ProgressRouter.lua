local _, CC = ...
if not CC then return end

local Router = { version = CC.version }
CC.ProgressRouter = Router
if CC.RegisterModule then CC:RegisterModule("ProgressRouter", Router) end

local floor, max = math.floor, math.max

-- ============================================================
-- C1-C5, E4, F1: constants, validators, and routing whitelist
-- ============================================================

-- Source systems — identifies which pass or achievement module emitted the event.
Router.SYSTEMS = {
    WOW_BATTLE_PASS              = "WOW_BATTLE_PASS",
    WOW_ACHIEVEMENTS             = "WOW_ACHIEVEMENTS",
    DUNGEON_DWELLER_BATTLE_PASS  = "DUNGEON_DWELLER_BATTLE_PASS",
    DUNGEON_DWELLER_ACHIEVEMENTS = "DUNGEON_DWELLER_ACHIEVEMENTS",
    DUNGEON_CRAWLER_BATTLE_PASS  = "DUNGEON_CRAWLER_BATTLE_PASS",
}

-- Game namespaces / origins (used in sourceGame and progressNamespace fields).
Router.GAMES = {
    WOW             = "WOW",
    DUNGEON_DWELLER = "DUNGEON_DWELLER",
    DUNGEON_CRAWLER = "DUNGEON_CRAWLER",
    GLOBAL          = "GLOBAL",
}

-- Activity types (objectiveType field).
Router.OBJECTIVES = {
    MOB_KILL           = "MOB_KILL",
    ELITE_KILL         = "ELITE_KILL",
    BOSS_KILL          = "BOSS_KILL",
    RAID_BOSS_KILL     = "RAID_BOSS_KILL",
    QUEST_COMPLETE     = "QUEST_COMPLETE",
    ZONE_DISCOVER      = "ZONE_DISCOVER",
    DUNGEON_COMPLETE   = "DUNGEON_COMPLETE",
    EXPLORATION        = "EXPLORATION",
    GAME_PLAY          = "GAME_PLAY",
    GAME_WIN           = "GAME_WIN",
    PROFESSION_CRAFT   = "PROFESSION_CRAFT",
    ACHIEVEMENT_UNLOCK = "ACHIEVEMENT_UNLOCK",
    CLASS_ACTION       = "CLASS_ACTION",
    PVP_KILL           = "PVP_KILL",
    DD_ENEMY_KILL      = "DD_ENEMY_KILL",
    DD_BOSS_KILL       = "DD_BOSS_KILL",
    DD_ZONE_DISCOVER   = "DD_ZONE_DISCOVER",
    MILESTONE          = "MILESTONE",
}

-- Named statistic keys (F1).
Router.PROGRESS_KEYS = {
    WOW_MOB_KILLS         = "WOW_MOB_KILLS",
    WOW_BOSS_KILLS        = "WOW_BOSS_KILLS",
    WOW_QUESTS_TOTAL      = "WOW_QUESTS_TOTAL",
    WOW_ZONES_VISITED     = "WOW_ZONES_VISITED",
    WOW_DUNGEON_KILLS     = "WOW_DUNGEON_KILLS",
    WOW_DUNGEON_COMPLETES = "WOW_DUNGEON_COMPLETES",
    WOW_STEPS             = "WOW_STEPS",
    WOW_TOTAL_KILLS       = "WOW_TOTAL_KILLS",
    DD_ENEMY_KILLS        = "DD_ENEMY_KILLS",
    DD_BOSS_KILLS         = "DD_BOSS_KILLS",
    DD_ZONE_DISCOVERS     = "DD_ZONE_DISCOVERS",
    MAIN_PASS_XP          = "MAIN_PASS_XP",
    MAIN_PASS_COINS       = "MAIN_PASS_COINS",
    DD_PASS_XP            = "DD_PASS_XP",
    DD_PASS_COINS         = "DD_PASS_COINS",
}

-- Reward type tags (F1, used in GetReward metadata).
Router.REWARD_TYPES = {
    CRESH_COINS         = "CRESH_COINS",
    BATTLE_PASS_XP      = "BATTLE_PASS_XP",
    THEME_UNLOCK        = "THEME_UNLOCK",
    DUNGEON_BUFF        = "DUNGEON_BUFF",
    ACHIEVEMENT_UNLOCK  = "ACHIEVEMENT_UNLOCK",
    CARD_DECK_UNLOCK    = "CARD_DECK_UNLOCK",
    TETRIS_THEME_UNLOCK = "TETRIS_THEME_UNLOCK",
}

-- Coin category strings matched by BattlePass:AddCoins (F1).
Router.COIN_CATEGORIES = {
    GAME         = "GAME",
    ACTIVITY     = "ACTIVITY",
    EXPLORATION  = "EXPLORATION",
    ACHIEVEMENT  = "ACHIEVEMENT",
    PASS         = "PASS",
    DUNGEON_PASS = "DUNGEON_PASS",
    GOAL         = "GOAL",
}

-- E4: achievement key prefixes by namespace.
Router.WOW_ACHIEVEMENT_PREFIX = "ACH_WOW_"
Router.DD_ACHIEVEMENT_PREFIX  = "ACH_DD_"
Router.DC_ACHIEVEMENT_PREFIX  = "ACH_DC_"

-- ============================================================
-- ROUTING WHITELIST (C3)
-- Permitted sourceGame -> progressNamespace pairs.
-- Any pair absent from this table is FORBIDDEN.
-- ============================================================
local ALLOWED_ROUTES = {
    WOW = {
        WOW             = true,  -- WoW events fund the main Battle Pass
        DUNGEON_DWELLER = true,  -- WoW zone discoveries may also fund DD Pass
    },
    DUNGEON_DWELLER = {
        DUNGEON_DWELLER = true,  -- DD game events fund the DD Pass only
    },
    DUNGEON_CRAWLER = {
        DUNGEON_CRAWLER = true,
    },
    GLOBAL = {
        WOW             = true,
        DUNGEON_DWELLER = true,
        DUNGEON_CRAWLER = true,
    },
}

-- Fast-lookup sets built from the constant tables above.
local VALID_SYSTEMS    = {}
local VALID_GAMES      = {}
local VALID_OBJECTIVES = {}
for _, v in pairs(Router.SYSTEMS)    do VALID_SYSTEMS[v]    = true end
for _, v in pairs(Router.GAMES)      do VALID_GAMES[v]      = true end
for _, v in pairs(Router.OBJECTIVES) do VALID_OBJECTIVES[v] = true end

-- ============================================================
-- DEVELOPER DIAGNOSTICS (ring buffer, dev-mode gated)
-- Disabled during normal play; activated via /cc progress on.
-- ============================================================
local DEV_CAPACITY = 20
local devLog      = {}
local devLogNext  = 1   -- slot where the next write will land
local devCount    = 0   -- total writes ever (not capped to capacity)
local devMode     = false

local function getTime()
    if type(_G.GetTime) == "function" then return _G.GetTime() end
    return 0
end

function Router:EnableDevMode(enabled)
    devMode = enabled == true
end

function Router:IsDevMode()
    return devMode
end

local function devAppend(tag, message)
    if not devMode then return end
    devLog[devLogNext] = { tag = tag, message = message, time = getTime() }
    devLogNext = (devLogNext % DEV_CAPACITY) + 1
    devCount   = devCount + 1
end

function Router:LogRejection(event, reason)
    if not devMode then return end
    local src  = tostring(event and event.sourceSystem      or "?")
    local game = tostring(event and event.sourceGame        or "?")
    local ns   = tostring(event and event.progressNamespace or "?")
    local obj  = tostring(event and event.objectiveType     or "?")
    local amt  = tostring(event and event.amount            or "?")
    devAppend("REJECT", string.format("[%s/%s->%s][%s][amt=%s] %s",
        src, game, ns, obj, amt, tostring(reason or "unknown")))
end

-- Returns all buffered entries in chronological order (oldest first).
function Router:GetDevLog()
    local result   = {}
    local stored   = math.min(devCount, DEV_CAPACITY)
    -- When buffer is full the oldest slot is devLogNext (next to be overwritten).
    -- When not full the oldest slot is 1.
    local startIdx = (devCount >= DEV_CAPACITY) and devLogNext or 1
    for i = 0, stored - 1 do
        local idx   = ((startIdx - 1 + i) % DEV_CAPACITY) + 1
        local entry = devLog[idx]
        if entry then result[#result + 1] = entry end
    end
    return result
end

function Router:GetDevLogCount()
    return devCount
end

function Router:ClearDevLog()
    devLog     = {}
    devLogNext = 1
    devCount   = 0
end

-- ============================================================
-- PROGRESS EVENT FACTORY
-- ============================================================

-- Returns a normalised event table with safe defaults.
-- Required fields: sourceSystem, sourceGame, progressNamespace,
--                  objectiveType, amount.
function Router:BuildProgressEvent(fields)
    if type(fields) ~= "table" then return nil end
    return {
        sourceSystem      = tostring(fields.sourceSystem      or ""),
        sourceGame        = tostring(fields.sourceGame        or ""),
        progressNamespace = tostring(fields.progressNamespace or ""),
        objectiveType     = tostring(fields.objectiveType     or ""),
        progressKey       = fields.progressKey      and tostring(fields.progressKey)      or nil,
        amount            = floor(max(0, tonumber(fields.amount) or 0)),
        isSimulation      = fields.isSimulation     == true,
        achievementId     = fields.achievementId    and tostring(fields.achievementId)    or nil,
        deduplicationKey  = fields.deduplicationKey and tostring(fields.deduplicationKey) or nil,
        description       = fields.description      and tostring(fields.description)      or nil,
    }
end

-- ============================================================
-- C2: ValidateProgressEvent
-- Returns: ok (bool), errorMessage (string|nil)
-- ============================================================
function Router:ValidateProgressEvent(event)
    if type(event) ~= "table" then
        return false, "event is not a table"
    end
    if event.sourceSystem == "" or not VALID_SYSTEMS[event.sourceSystem] then
        return false, "unknown sourceSystem: " .. tostring(event.sourceSystem)
    end
    if event.sourceGame == "" or not VALID_GAMES[event.sourceGame] then
        return false, "unknown sourceGame: " .. tostring(event.sourceGame)
    end
    if event.progressNamespace == "" or not VALID_GAMES[event.progressNamespace] then
        return false, "unknown progressNamespace: " .. tostring(event.progressNamespace)
    end
    if event.objectiveType == "" then
        return false, "missing objectiveType"
    end
    if not VALID_OBJECTIVES[event.objectiveType] then
        return false, "unknown objectiveType: " .. tostring(event.objectiveType)
    end
    if not event.amount or event.amount <= 0 then
        return false, "amount must be positive, got: " .. tostring(event.amount)
    end
    if not self:IsProgressEventAllowed(event) then
        return false, "prohibited route: " .. tostring(event.sourceGame) .. "->" .. tostring(event.progressNamespace)
    end
    return true
end

-- ============================================================
-- C3: IsProgressEventAllowed
-- ============================================================
function Router:IsProgressEventAllowed(event)
    if type(event) ~= "table" then return false end
    local gameRoutes = ALLOWED_ROUTES[event.sourceGame]
    return gameRoutes ~= nil and gameRoutes[event.progressNamespace] == true
end

-- ============================================================
-- C4: GetProgressNamespace
-- ============================================================
function Router:GetProgressNamespace(event)
    if type(event) ~= "table" then return nil end
    if VALID_GAMES[event.progressNamespace] then return event.progressNamespace end
    if VALID_GAMES[event.sourceGame]        then return event.sourceGame end
    return nil
end

-- ============================================================
-- C1: RouteProgressEvent — canonical validated entry point
-- Returns: ok (bool), errorMessage (string|nil), isSimulation (bool)
-- When the third return is true the event passed validation but
-- MUST NOT be applied to live SavedVariables data.
-- ============================================================
function Router:RouteProgressEvent(event)
    local ok, err = self:ValidateProgressEvent(event)
    if not ok then
        self:LogRejection(event, err)
        return false, err, false
    end
    if event.isSimulation then
        devAppend("SIM_OK", string.format("[%s/%s->%s][%s][amt=%d] simulation accepted",
            tostring(event.sourceSystem),
            tostring(event.sourceGame),
            tostring(event.progressNamespace),
            tostring(event.objectiveType),
            event.amount))
        return true, nil, true
    end
    return true, nil, false
end

-- ============================================================
-- COMPATIBILITY ADAPTERS
-- Wrap legacy (amount, description) call patterns into validated events.
-- Return the same three-value tuple as RouteProgressEvent.
-- ============================================================

function Router:ValidateLegacyPassXP(amount, description)
    local event = self:BuildProgressEvent({
        sourceSystem      = Router.SYSTEMS.WOW_BATTLE_PASS,
        sourceGame        = Router.GAMES.WOW,
        progressNamespace = Router.GAMES.WOW,
        objectiveType     = Router.OBJECTIVES.EXPLORATION,
        progressKey       = Router.PROGRESS_KEYS.MAIN_PASS_XP,
        amount            = amount,
        description       = description,
    })
    return self:RouteProgressEvent(event)
end

function Router:ValidateLegacyDDPassXP(amount, description)
    local event = self:BuildProgressEvent({
        sourceSystem      = Router.SYSTEMS.DUNGEON_DWELLER_BATTLE_PASS,
        sourceGame        = Router.GAMES.DUNGEON_DWELLER,
        progressNamespace = Router.GAMES.DUNGEON_DWELLER,
        objectiveType     = Router.OBJECTIVES.DD_ENEMY_KILL,
        progressKey       = Router.PROGRESS_KEYS.DD_PASS_XP,
        amount            = amount,
        description       = description,
    })
    return self:RouteProgressEvent(event)
end

function Router:ValidateLegacyAchievementUnlock(achievementKey, amount)
    local event = self:BuildProgressEvent({
        sourceSystem      = Router.SYSTEMS.WOW_ACHIEVEMENTS,
        sourceGame        = Router.GAMES.WOW,
        progressNamespace = Router.GAMES.WOW,
        objectiveType     = Router.OBJECTIVES.ACHIEVEMENT_UNLOCK,
        progressKey       = Router.PROGRESS_KEYS.MAIN_PASS_XP,
        achievementId     = achievementKey,
        amount            = amount,
        description       = "Achievement unlock: " .. tostring(achievementKey or ""),
    })
    return self:RouteProgressEvent(event)
end
