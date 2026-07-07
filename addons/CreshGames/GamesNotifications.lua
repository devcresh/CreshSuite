local _, CG = ...
if not CG then return end

-- CreshGames' own registration against the suite-wide notification service
-- (shared/SuiteNotifications.lua, loaded earlier in this TOC -- guaranteed
-- present regardless of whether CreshChat is loaded). Replaces the old
-- registration block that used to live in CreshGames.lua's PLAYER_LOGIN
-- handler, gated on `if CC and CC.Notifications then ... end` -- meaning it
-- silently never ran at all without CreshChat. Category set is unchanged
-- from that block except for the addition of ACHIEVEMENT, which previously
-- had nowhere to go (GamesAchievements.lua/GamesDungeonAchievements.lua
-- unlocks were routed through the generic GAME/BATTLEPASS toast kinds).

local Notif = _G.CreshSuiteNotifications
if not Notif then return end

Notif:RegisterSource("CRESHGAMES", "CreshGames")
Notif:RegisterCategory("CRESHGAMES", "GAME_INVITE",       "Game Invitations",   "Incoming multiplayer game invitations.",         { priority = "CRITICAL" })
Notif:RegisterCategory("CRESHGAMES", "CHALLENGE",         "Challenges",         "Player challenges and counter-challenges.",      { priority = "HIGH" })
Notif:RegisterCategory("CRESHGAMES", "MULTIPLAYER_EVENT", "Multiplayer Events", "Multiplayer session and match events.",          { priority = "NORMAL" })
Notif:RegisterCategory("CRESHGAMES", "GAME_RESULT",       "Game Results",       "Multiplayer game completion results.",           { priority = "NORMAL" })
Notif:RegisterCategory("CRESHGAMES", "REWARD",            "Rewards",           "Cresh Coin and game reward notifications.",       { priority = "LOW" })
Notif:RegisterCategory("CRESHGAMES", "BATTLE_PASS",       "Battle Pass",       "Battle Pass level and reward unlock notices.",     { priority = "LOW" })
Notif:RegisterCategory("CRESHGAMES", "ACHIEVEMENT",       "Achievements",      "CreshGames and Dungeon Dweller achievement unlocks.", { priority = "NORMAL" })

-- ----------------------------------------------------------------
-- Producer helpers -- no CC.UI/CC.Notifications reference. Every one of
-- these builds a normalized event and pushes it directly; sound and card
-- rendering are entirely the suite service's concern from here.
-- ----------------------------------------------------------------

local function push(category, title, message, status, key, extra)
    local event = {
        sourceAddon = "CRESHGAMES",
        category    = category,
        status      = status or "GAME",
        title       = tostring(title or "CreshGames"),
        detail      = tostring(message or ""),
        coalesceKey = key,
    }
    if type(extra) == "table" then
        for k, v in pairs(extra) do event[k] = v end
    end
    return Notif:Push(event)
end

-- Generic reward/unlock toast (theme unlocks, dungeon crate pickups, solo
-- per-game level-ups). Mirrors the old UI:ShowGameToast(title, message,
-- status, key) signature so call sites only need their receiver changed.
function CG:ShowGameToast(title, message, status, key)
    return push("REWARD", title, message, status, key)
end

-- Tetris Mastery / Games (Arcade) Battle Pass level-ups and reward claims.
function CG:ShowBattlePassToast(title, message, status, key)
    return push("BATTLE_PASS", title or "Battle Pass", message or "New progress is ready.", status or "BATTLEPASS", key)
end

-- Delver Mastery (Dungeon Dwellers) pass level-ups and reward claims.
function CG:ShowDungeonPassToast(title, message, key)
    return push("BATTLE_PASS", title or "Delver Mastery", message or "New delver progress is ready.", "DUNGEONPASS", key)
end

-- CreshGames catalog / Dungeon Dweller achievement unlocks.
function CG:ShowAchievementToast(title, message, key)
    return push("ACHIEVEMENT", title, message, "ACHIEVEMENT", key)
end

-- Milestone dungeon boss defeats, multiplayer match results, and similar
-- solo/co-op outcomes. status defaults to "GAME" (e.g. dungeon milestones);
-- multiplayer results pass their own SUCCESS/ERROR/INFO outcome status.
function CG:ShowGameResultToast(title, message, key, status)
    return push("GAME_RESULT", title, message, status or "GAME", key)
end

-- Challenge sent/declined notices (not the actionable invite itself -- see
-- ShowGameInvite below for that).
function CG:ShowChallengeToast(title, message, key, status)
    return push("CHALLENGE", title, message, status or "GAME", key)
end

-- Actionable incoming multiplayer challenge/invite. destination=ACTIONABLE
-- so it uses the actionable lane (no queue cap) and the accept/decline
-- button pair, matching Games:ShowChallengePopup's existing shape.
function CG:ShowGameInvite(title, message, key, actions)
    return push("GAME_INVITE", title, message, "GAME", key, {
        priority    = "CRITICAL",
        destination = "ACTIONABLE",
        duration    = 30,
        actions     = actions,
    })
end
