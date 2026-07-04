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
if Suite then
    Suite:RegisterProduct("CreshGames", CG.version, {})

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
end

-- -----------------------------------------------------------------------
-- Bridge: populate CreshChat's namespace with CreshGames modules so that
-- existing CC.SoloGames / CC.Games / etc. references in BattlePass.lua,
-- Progression.lua, Settings.lua, and DungeonAchievements.lua keep working
-- without any changes to those files.
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
