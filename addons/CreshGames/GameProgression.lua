-- CreshGames/GameProgression.lua
-- Per-game level/XP tracking (Frogger Level X, Chess Level X, ...) for
-- CreshGames' own mini-games. Moved here from CreshCollect/Progression.lua
-- (which kept only WoW-world exploration tracking) so game level bars work
-- fully without CreshCollect installed. Level-ups pay into CreshGames' own
-- Battle Pass (GamesBattlePass.lua) directly -- no cross-addon hop needed,
-- same addon now.
--
-- State lives in CreshGamesDB.gameLevels. Existing players' levels are
-- migrated once from CreshCollectDB.gameProgression.games on first use, so
-- nobody's current game level is lost by this split.
local _, CG = ...
if not CG then return end

local CC = setmetatable({}, { __index = function(_, k)
    local c = _G.CreshChat
    return c and c[k]
end })
local COL = setmetatable({}, { __index = function(_, k)
    local c = _G.CreshCollect
    return c and c[k]
end })

local Progression = {
    version = CG.version,
}
CG.GameProgression = Progression
if CG.RegisterModule then CG:RegisterModule("GameProgression", Progression) end

local floor, min, max = math.floor, math.min, math.max
local upper = string.upper

local GAME_NAMES = {
    FROGGER = "Frogger",
    DUNGEON = "Dungeon Dweller",
    CHESS = "Chess",
    HOLDEM = "Texas Hold'em",
    BLACKJACK = "Blackjack",
    HIGHERLOWER = "Higher or Lower",
    TETRIS = "Tetris",
    PONG = "Pong",
}

local function now()
    if type(_G.GetServerTime) == "function" then return _G.GetServerTime() end
    if type(_G.time) == "function" then return _G.time() end
    if type(_G.GetTime) == "function" then return floor(_G.GetTime()) end
    return 0
end

-- CreshGames must work fully without CreshChat: only defer to CreshChat's
-- own "gameProgression" feature toggle when CreshChat is actually loaded.
local function progressionFeatureEnabled()
    local cc = _G.CreshChat
    if not (cc and cc.IsFeatureEnabled) then return true end
    return cc:IsFeatureEnabled("gameProgression") ~= false
end

-- Rework Phase 8: one-time, self-healing migration from CreshCollect's
-- pre-split per-game level data, so existing players don't lose their
-- levels. Read via the Suite service, never CreshCollectDB directly.
--
-- This used to commit to gameLevels = {} the very first time Ensure() ran,
-- even if CreshCollect's GetLegacyGameLevels service wasn't registered yet
-- (e.g. an unusual inter-addon load order) -- since that empty table is
-- truthy, the "not yet migrated" check could never be true again, silently
-- and permanently losing the import for that player. gameLevels is now
-- populated immediately so every other method keeps working, while a
-- separate migratedLegacyLevels flag (not "is the table non-nil") gates the
-- one-shot import, and only a confirmed PLAYER_LOGIN attempt -- guaranteed
-- to run after every addon has finished loading, mirroring
-- CreshCollectDatabase.lua's v3 "isFinalAttempt" migration -- is allowed to
-- permanently record "nothing to import". Union, not overwrite: any level
-- already recorded by real gameplay before the import lands is preserved.
local function importLegacyGameLevels(isFinalAttempt)
    if not _G.CreshGamesDB then return end
    _G.CreshGamesDB.gameLevels = type(_G.CreshGamesDB.gameLevels) == "table" and _G.CreshGamesDB.gameLevels or {}
    if _G.CreshGamesDB.migratedLegacyLevels then return end

    local suite = _G.CreshSuite
    local getter = suite and suite.GetService and suite:GetService("GetLegacyGameLevels")
    local legacy = getter and getter()
    if type(legacy) == "table" then
        for game, record in pairs(legacy) do
            if _G.CreshGamesDB.gameLevels[game] == nil then
                _G.CreshGamesDB.gameLevels[game] = record
            end
        end
        _G.CreshGamesDB.migratedLegacyLevels = true
    elseif isFinalAttempt then
        _G.CreshGamesDB.migratedLegacyLevels = true
    end
end

function Progression:Ensure()
    if not _G.CreshGamesDB then return nil end
    importLegacyGameLevels(false)
    return _G.CreshGamesDB.gameLevels
end

function Progression:XPNeeded(level)
    level = floor(max(1, tonumber(level) or 1))
    return 80 + ((level - 1) * 20)
end

function Progression:GetGameRecord(game)
    local games = self:Ensure()
    if not games then return nil end
    game = upper(tostring(game or "GAME"))
    games[game] = type(games[game]) == "table" and games[game] or {}
    local record = games[game]
    record.level = floor(max(1, tonumber(record.level) or 1))
    record.xp = floor(max(0, tonumber(record.xp) or 0))
    record.plays = floor(max(0, tonumber(record.plays) or 0))
    record.wins = floor(max(0, tonumber(record.wins) or 0))
    record.draws = floor(max(0, tonumber(record.draws) or 0))
    record.losses = floor(max(0, tonumber(record.losses) or 0))
    record.starts = floor(max(0, tonumber(record.starts) or 0))
    record.lastPlayed = tonumber(record.lastPlayed) or 0
    local needed = self:XPNeeded(record.level)
    while record.xp >= needed do
        record.xp = record.xp - needed
        record.level = record.level + 1
        needed = self:XPNeeded(record.level)
    end
    return record
end

function Progression:GetProgress(game)
    local record = self:GetGameRecord(game)
    if not record then return 1, 0, 80, 0 end
    local needed = self:XPNeeded(record.level)
    return record.level, record.xp, needed, min(1, record.xp / max(1, needed)), record
end

function Progression:UpdateBar(bar, label, game)
    if not game or game == "" then
        if bar then bar:SetMinMaxValues(0, 1); bar:SetValue(0) end
        if label then label:SetText("") end
        return
    end
    local level, current, needed = self:GetProgress(game)
    if bar then
        bar:SetMinMaxValues(0, max(1, needed))
        bar:SetValue(current)
        if bar.Show then bar:Show() end
    end
    if label then label:SetText("LV " .. level .. "  " .. current .. "/" .. needed) end
end

function Progression:RefreshUI()
    if CG.SoloGames and CG.SoloGames.hub and CG.SoloGames.RefreshHub then CG.SoloGames:RefreshHub() end
    if CC.UI and CC.UI.gameDrawer and CC.UI.RefreshGameDrawer then CC.UI:RefreshGameDrawer(true) end
    if CG.SoloGames and CG.SoloGames.window then
        self:UpdateBar(CG.SoloGames.window.levelProgress, CG.SoloGames.window.levelText, CG.SoloGames.activeGame)
    end
    if CG.Games and CG.Games.gameWindow then
        self:UpdateBar(CG.Games.gameWindow.levelProgress, CG.Games.gameWindow.levelText, CG.Games.active and CG.Games.active.game)
    end
end

-- Pays a level-up into CreshGames' own Battle Pass directly -- same addon,
-- no cross-addon API hop needed.
function Progression:AwardGameLevel(game, level)
    local coins, passXP = 10, 10
    if CG.BattlePass then
        if CG.BattlePass.AddCoins then CG.BattlePass:AddCoins(coins, "GAME") end
        if CG.BattlePass.AddXP then CG.BattlePass:AddXP(passXP, "GAME LEVEL") end
    end
    if CC.UI and CC.UI.ShowGameToast then
        CC.UI:ShowGameToast((GAME_NAMES[game] or game) .. " Level " .. level,
            "+" .. coins .. " Cresh Coins · +" .. passXP .. " Games Battle Pass XP", "SUCCESS", "GAMELEVEL:" .. tostring(game) .. ":" .. tostring(level))
    end
    if CG.GameAudio and CG.GameAudio.PlayEffect then CG.GameAudio:PlayEffect("LEVEL") end
    if CC.UI and CC.UI.RefreshConsoleEconomy then CC.UI:RefreshConsoleEconomy() end
    return coins, passXP
end

function Progression:AddGameXP(game, amount)
    game = upper(tostring(game or "GAME"))
    amount = floor(max(0, tonumber(amount) or 0))
    local record = self:GetGameRecord(game)
    if not record or amount <= 0 then return 0, 0 end
    local levels = 0
    record.xp = record.xp + amount
    local needed = self:XPNeeded(record.level)
    while record.xp >= needed do
        record.xp = record.xp - needed
        record.level = record.level + 1
        levels = levels + 1
        self:AwardGameLevel(game, record.level)
        needed = self:XPNeeded(record.level)
    end
    if game == "TETRIS" and levels > 0 and CG.Tetris and CG.Tetris.SyncUnlocks then CG.Tetris:SyncUnlocks(true) end
    self:RefreshUI()
    return amount, levels
end

function Progression:OnGameStarted(game, mode)
    if not progressionFeatureEnabled() then return 0 end
    game = upper(tostring(game or "GAME"))
    mode = upper(tostring(mode or "SOLO"))
    -- Rework Phase 3: Arcade Pass XP pays in directly here, independent of
    -- the per-game Mastery XP below -- a Mastery level-up is never a
    -- precondition for funding the Arcade Pass on a game start.
    if CG.BattlePass and CG.BattlePass.AwardGameStart then CG.BattlePass:AwardGameStart(game, mode, true) end
    local gain = (mode == "MULTIPLAYER" or mode == "MULTI") and 10 or 5
    local record = self:GetGameRecord(game)
    if record then record.starts = floor(max(0, tonumber(record.starts) or 0)) + 1 end
    self:AddGameXP(game, gain)
    if COL.Achievements and COL.Achievements.EvaluateAll then COL.Achievements:EvaluateAll(false) end
    if CG.GameAudio and CG.GameAudio.PlayEffect then CG.GameAudio:PlayEffect("CLICK") end
    return gain
end

function Progression:OnGameCompleted(entry)
    if not progressionFeatureEnabled() then return 0 end
    if type(entry) ~= "table" then return 0 end
    local game = upper(tostring(entry.game or "GAME"))
    local mode = upper(tostring(entry.mode or "SOLO"))
    local result = upper(tostring(entry.result or "RUN"))
    local score = floor(max(0, tonumber(entry.score) or 0))
    local record = self:GetGameRecord(game)
    if not record then return 0 end

    -- Rework Phase 3: Arcade Pass XP pays in directly from the completed
    -- result -- covers "completed game", "win/loss/draw", "score
    -- milestones" and "multiplayer completion" in one call, independent of
    -- the per-game Mastery XP below (no Mastery level-up required first).
    if CG.BattlePass and CG.BattlePass.AwardGameResult then CG.BattlePass:AwardGameResult(entry, false) end

    local gain = 10
    if result == "WIN" then gain = 30; record.wins = record.wins + 1
    elseif result == "DRAW" then gain = 20; record.draws = record.draws + 1
    elseif result == "LOSS" then gain = 15; record.losses = record.losses + 1
    elseif result == "RUN" then gain = 15 + min(20, floor(score / 250)) end
    if mode == "MULTIPLAYER" or mode == "MULTI" then gain = gain * 2 end

    record.plays = record.plays + 1
    record.lastPlayed = now()
    self:AddGameXP(game, gain)
    if COL.Achievements and COL.Achievements.EvaluateAll then COL.Achievements:EvaluateAll(false) end
    if CG.GameAudio and CG.GameAudio.PlayEffect then
        if result == "WIN" then CG.GameAudio:PlayEffect("WIN") elseif result == "LOSS" then CG.GameAudio:PlayEffect("LOSS") else CG.GameAudio:PlayEffect("CLICK") end
    end
    return gain
end

-- Final-attempt safety net: PLAYER_LOGIN always fires after every addon has
-- finished loading, so if CreshCollect is installed its GetLegacyGameLevels
-- service is guaranteed to be registered by now. Only this call is allowed
-- to permanently record "nothing to import" (see importLegacyGameLevels
-- above); ordinary Ensure() calls before this point may retry harmlessly.
local eventFrame = CreateFrame("Frame")
local function safeRegister(event)
    if eventFrame and eventFrame.RegisterEvent then pcall(eventFrame.RegisterEvent, eventFrame, event) end
end
safeRegister("PLAYER_LOGIN")

eventFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        importLegacyGameLevels(true)
    end
end)
