local _, CG = ...
if not CG then return end

CG.version = "0.2.3"

-- Shared player state; populated on PLAYER_LOGIN.
CG.state = {
    playerName   = nil,
    playerRealm  = nil,
    playerFull   = nil,
}

-- Module registry (readable by other modules via CG._modules).
CG._modules = {}
function CG:RegisterModule(name, mod)
    CG._modules[name] = mod
end

-- True when name matches the local player (wire-protocol helper).
function CG:IsSelf(name)
    if not name then return false end
    local pname = self.state.playerName
    if not pname then
        pname = type(_G.UnitName) == "function" and _G.UnitName("player") or nil
    end
    return pname ~= nil and name == pname
end

-- -----------------------------------------------------------------------
-- Suite registration
-- -----------------------------------------------------------------------
local Suite = _G.CreshSuite
local API = _G.CreshGamesAPI or {}

function API.IsLoaded() return true end
function API.GetVersion() return CG.version end

-- Public entry point for CreshGames' own Battle Pass (addons/CreshGames/
-- BattlePass.lua): in-game level-up events pay coins/XP into it through
-- here, rather than any other addon reaching into CG.BattlePass directly.
function API.AddBattlePassCoins(amount, source)
    if CG.BattlePass and CG.BattlePass.AddCoins then return CG.BattlePass:AddCoins(amount, source) end
    return 0
end

function API.AddBattlePassXP(amount, source, silent)
    if CG.BattlePass and CG.BattlePass.AddXP then return CG.BattlePass:AddXP(amount, source, silent) end
    return 0
end

-- ------------------------------------------------------------------------
-- Rework Phase 1: forward-looking "Arcade Pass" / "Mastery" naming for the
-- Progression and Unlockables Rework. These wrap the exact same modules as
-- the functions above (no data has moved) so existing callers are
-- unaffected; new code should prefer these names going forward.
-- ------------------------------------------------------------------------

-- Returns level, currentXP, requiredXP, ratio. (1, 0, 50, 0) when not loaded.
function API.GetArcadePassProgress()
    if not CG.BattlePass or not CG.BattlePass.GetProgress then return 1, 0, 50, 0 end
    return CG.BattlePass:GetProgress()
end

function API.AddArcadeXP(amount, source, silent)
    return API.AddBattlePassXP(amount, source, silent)
end

-- Rework Phase 5 moved CreshGames' own achievements (arcade + Dungeon
-- Dwellers, 116 total) out of CreshCollect and into CG.Achievements -- this
-- used to delegate to CreshCollectAPI.IsAchievementUnlocked, which since
-- that move only ever checks CreshCollect's own World-achievement catalog
-- and would always return false for a CreshGames achievement key. Same
-- addon now, so no cross-addon hop is needed at all.
function API.IsGameAchievementUnlocked(key)
    if not CG.Achievements or not CG.Achievements.IsUnlocked then return false end
    return CG.Achievements:IsUnlocked(key)
end

-- bucket is one of: CARD_DECK, TETRIS_THEME.
function API.IsGameCollectibleOwned(bucket, key)
    bucket = tostring(bucket or "")
    if bucket == "CARD_DECK" then
        return CG.CardDecks and CG.CardDecks.IsUnlocked and CG.CardDecks:IsUnlocked(key) or false
    elseif bucket == "TETRIS_THEME" then
        return CG.Tetris and CG.Tetris.IsThemeUnlocked and CG.Tetris:IsThemeUnlocked(key) or false
    end
    return false
end

function API.OpenArcadePass()
    if CG.BattlePass and CG.BattlePass.ToggleWindow then CG.BattlePass:ToggleWindow(); return true end
    return false
end

-- Rework Phase 9: routes to the requested track's own Mastery tab/panel
-- (Tetris' "TETRIS MASTERY" tab, Dungeon Dweller's "PASS" panel). An
-- unrecognised or omitted game falls back to the solo games hub so this
-- call is never a dead end.
function API.OpenGameMastery(game)
    game = string.upper(tostring(game or ""))
    if game == "TETRIS" then
        if CG.SoloGames and CG.SoloGames.OpenTetrisMastery then return CG.SoloGames:OpenTetrisMastery() end
    elseif game == "DUNGEON" or game == "DELVER" or game == "DUNGEONDWELLER" or game == "DUNGEONDWELLERS" then
        if CG.SoloGames and CG.SoloGames.OpenDungeonDwellers then return CG.SoloGames:OpenDungeonDwellers("PASS") end
    end
    if CG.SoloGames and CG.SoloGames.OpenHub then CG.SoloGames:OpenHub(); return true end
    return false
end

-- Rework Phase 9: data getters for the Unified Progression UI (CreshCollect's
-- ProgressOverview surfaces these via this API, never by reaching into
-- CG.* directly).
function API.GetGameAchievementCounts(category)
    if not CG.Achievements or not CG.Achievements.GetCounts then return 0, 0 end
    return CG.Achievements:GetCounts(category)
end

-- Returns level, currentXP, requiredXP, ratio for the named Mastery track
-- ("TETRIS" or "DUNGEON"/"DELVER"/"DUNGEONDWELLER"/"DUNGEONDWELLERS").
-- (1, 0, 1, 0) for an unrecognised game or when CreshGames isn't loaded.
function API.GetGameMasteryProgress(game)
    game = string.upper(tostring(game or ""))
    if game == "TETRIS" then
        if CG.Tetris and CG.Tetris.GetMasteryProgress then return CG.Tetris:GetMasteryProgress() end
    elseif game == "DUNGEON" or game == "DELVER" or game == "DUNGEONDWELLER" or game == "DUNGEONDWELLERS" then
        if CG.DungeonDwellersPass and CG.DungeonDwellersPass.GetProgress then return CG.DungeonDwellersPass:GetProgress() end
    end
    return 1, 0, 1, 0
end

_G.CreshGamesAPI = API
if Suite then
    Suite:RegisterProduct("CreshGames", CG.version, API)
    Suite:RegisterService("OpenGamesBattlePass", function()
        if CG.BattlePass and CG.BattlePass.ToggleWindow then CG.BattlePass:ToggleWindow() end
    end)
    -- Forward-looking alias ("Arcade Pass" is this window's Rework name).
    Suite:RegisterService("OpenArcadePass", function() API.OpenArcadePass() end)
    Suite:RegisterService("OpenGameMastery", function(game) API.OpenGameMastery(game) end)

    -- Formal "open this feature" contract for CreshChat's commands and launcher
    -- buttons, so they can ask "is CreshGames able to do this?" via the Suite
    -- instead of reaching into CC.Games / CC.SoloGames directly. Lazily checks
    -- CG.Games / CG.SoloGames at call time, so registration order versus the
    -- rest of CreshGames' own TOC load order does not matter.
    Suite:RegisterService("OpenGames", function(target)
        if CG.Games and CG.Games.OpenHub then CG.Games:OpenHub(target) end
    end)
    Suite:RegisterService("OpenSoloGames", function()
        if CG.SoloGames and CG.SoloGames.OpenHub then CG.SoloGames:OpenHub() end
    end)
    Suite:RegisterService("OpenLeaderboard", function()
        if CG.SoloGames and CG.SoloGames.OpenLeaderboard then CG.SoloGames:OpenLeaderboard() end
    end)
    Suite:RegisterService("OpenGameHistory", function()
        if CG.SoloGames and CG.SoloGames.OpenHistory then CG.SoloGames:OpenHistory() end
    end)

    -- Read-only snapshot of CreshGamesDB's frozen, one-time-migrated legacy
    -- progression data (arcadeRewards.claimed and gameProgression.achievements
    -- are never written to again after CreshGames' own one-time import from
    -- CreshChatDB). Exists solely so CreshCollect's safety-net migration can
    -- read it without ever touching CreshGamesDB directly — CreshCollect and
    -- CreshGames must never reach into each other's SavedVariables tables.
    Suite:RegisterService("GetLegacyProgressionSnapshot", function()
        if not CreshGamesDB then return nil end
        local arcade = CreshGamesDB.arcadeRewards
        local achievements = CreshGamesDB.gameProgression and CreshGamesDB.gameProgression.achievements
        return {
            arcadeRewardsClaimed        = arcade and arcade.claimed,
            arcadeRewardsUnlockedThemes = arcade and arcade.unlockedThemes,
            arcadeRewardsThemeSources   = arcade and arcade.themeUnlockSources,
            achievementsUnlocked        = achievements and achievements.unlocked,
            achievementsProgress        = achievements and achievements.progress,
            achievementsStats           = achievements and achievements.stats,
        }
    end)
end

-- -----------------------------------------------------------------------
-- Bridge: populate CreshChat's namespace with CreshGames modules so that
-- existing CC.SoloGames / CC.Games / etc. references in BattlePass.lua,
-- Progression.lua and Settings.lua keep working without any changes to
-- those files.
-- -----------------------------------------------------------------------
local function bridgeToCreshChat()
    local CC = _G.CreshChat
    if not CC then return end
    CC.GameAudio           = CG.GameAudio
    CC.CardDecks           = CG.CardDecks
    CC.Tetris              = CG.Tetris
    CC.Games               = CG.Games
    CC.SoloGames           = CG.SoloGames
    CC.DungeonDwellersPass = CG.DungeonDwellersPass
    -- Per-game level/XP tracking moved here from CreshCollect (Phase 10) so
    -- it works without CreshCollect installed; still bridged onto CC.* so
    -- existing CC.GameProgression references elsewhere keep working.
    -- NOTE: CC.BattlePass is deliberately NOT bridged to CG.BattlePass here
    -- -- CreshCollect's own bridge (CreshCollect.lua) owns that key for its
    -- 200-level pass UI (drawer panels, themes, wallet display in CreshChat/
    -- UI.lua, Settings.lua, Developer.lua). CreshGames' own Battle Pass is
    -- reached as CG.BattlePass (same-addon) or via CreshGamesAPI, never
    -- through the shared CC.BattlePass key.
    CC.GameProgression     = CG.GameProgression
    -- Rework Phase 5: CG.Achievements (the moved GAMES + Dungeon Dwellers
    -- catalogs) bridges under a distinct key, never "CC.Achievements" --
    -- that key is CreshCollect's own bridge, for its own (now World-only)
    -- catalog, and the same collision risk documented above for BattlePass
    -- applies here too.
    CC.GamesAchievements   = CG.Achievements
end

-- -----------------------------------------------------------------------
-- Event handling
-- -----------------------------------------------------------------------
local _eventFrame = CreateFrame("Frame")
_eventFrame:RegisterEvent("ADDON_LOADED")
_eventFrame:RegisterEvent("PLAYER_LOGIN")
_eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local loaded = ...
        -- Bridge runs when either CreshGames or CreshChat finishes loading,
        -- whichever comes second, guaranteeing both namespaces exist.
        if loaded == "CreshGames" or loaded == "CreshChat" then
            bridgeToCreshChat()
        end

    elseif event == "PLAYER_LOGIN" then
        CG.state.playerName  = type(_G.UnitName)     == "function" and _G.UnitName("player")  or nil
        CG.state.playerRealm = type(_G.GetRealmName) == "function" and _G.GetRealmName()       or nil
        if CG.state.playerName and CG.state.playerRealm then
            CG.state.playerFull = CG.state.playerName .. "-" .. CG.state.playerRealm
        end

        -- Final bridge pass (covers load-order edge cases).
        bridgeToCreshChat()

        -- Ensure the shared launcher exists even when CreshChat is absent --
        -- idempotent, a no-op if another addon already built it.
        if _G.CreshSuiteLauncherAPI and _G.CreshSuiteLauncherAPI.EnsureBuilt then
            _G.CreshSuiteLauncherAPI:EnsureBuilt()
        end

        local CC = _G.CreshChat
        if CC and CC.Notifications then
            CC.Notifications:RegisterSource("CRESHGAMES", "CreshGames")
            CC.Notifications:RegisterCategory("CRESHGAMES", "GAME_INVITE",       "Game Invitations",   "Incoming multiplayer game invitations.",        { priority = "CRITICAL" })
            CC.Notifications:RegisterCategory("CRESHGAMES", "CHALLENGE",         "Challenges",         "Player challenges and counter-challenges.",     { priority = "HIGH" })
            CC.Notifications:RegisterCategory("CRESHGAMES", "MULTIPLAYER_EVENT", "Multiplayer Events", "Multiplayer session and match events.",         { priority = "NORMAL" })
            CC.Notifications:RegisterCategory("CRESHGAMES", "GAME_RESULT",       "Game Results",       "Multiplayer game completion results.",          { priority = "NORMAL" })
            CC.Notifications:RegisterCategory("CRESHGAMES", "REWARD",            "Rewards",            "Cresh Coin and game reward notifications.",    { priority = "LOW" })
            CC.Notifications:RegisterCategory("CRESHGAMES", "BATTLE_PASS",       "Battle Pass",        "Battle Pass level and reward unlock notices.", { priority = "LOW" })
        end
    end
end)
