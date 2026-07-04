local addonName, COL = ...

-- Defer CreshChat access to call time (CreshChat may load before or after us)
local CC = setmetatable({}, { __index = function(_, k)
    local c = _G.CreshChat
    return c and c[k]
end })

-- Module registry
COL.version  = "0.2.3"
COL._modules = {}
function COL:RegisterModule(name, obj)
    self._modules[name] = obj
end

-- Suite registration
do
    local Suite = _G.CreshSuite
    if Suite then
        Suite:RegisterProduct("CreshCollect", COL.version, {})

        -- Formal "open this feature" contract for CreshChat's commands and
        -- launcher buttons, so they can ask "is CreshCollect able to do this?"
        -- via the Suite instead of reaching into CC.ProgressHub / CC.Achievements /
        -- CC.BattlePass directly. Progress Hub owns its own frame, so it opens
        -- directly; Achievements and Battle Pass are panels of CreshChat's own
        -- game drawer, so those services call back into CreshChat's UI through
        -- the same CC proxy this file already uses.
        Suite:RegisterService("OpenProgressHub", function()
            if COL.ProgressHub and COL.ProgressHub.Toggle then COL.ProgressHub:Toggle() end
        end)
        Suite:RegisterService("OpenAchievements", function()
            if CC.UI and CC.UI.LauncherToggleMode then CC.UI:LauncherToggleMode("ACHIEVEMENTS") end
        end)
        Suite:RegisterService("OpenBattlePass", function()
            if CC.UI and CC.UI.OpenGameDrawer then CC.UI:OpenGameDrawer("BATTLEPASS") end
        end)

        -- Mirror cosmetic unlocks from CreshGames into CreshCollectDB.collections.
        -- Idempotent: existing keys are never overwritten.
        local UNLOCK_TYPES = {
            TETRIS_THEME      = { bucket = "themes",        label = "Theme" },
            TETRIS_BACKGROUND = { bucket = "backgrounds",   label = "Background" },
            CARD_DECK         = { bucket = "cardDecks",     label = "Card Deck" },
            DUNGEON_PASS      = { bucket = "dungeonArmour", label = "Dungeon Armour" },
        }
        Suite:Subscribe("CRESHGAMES_COLLECTION_UNLOCK", function(payload)
            if type(payload) ~= "table" then return end
            if not CreshCollectDB then return end
            local col = CreshCollectDB.collections
            if type(col) ~= "table" then return end
            local key, uType = payload.key, payload.type
            if not key then return end
            local info = UNLOCK_TYPES[uType]
            if not info then return end
            local isNewUnlock = col[info.bucket][key] == nil
            col[info.bucket][key] = col[info.bucket][key] or true

            -- Feedback below is best-effort: the unlock above already
            -- persisted silently and correctly even if CreshChat is absent.
            local cc = _G.CreshChat
            if not cc then return end

            local settingsModule = cc.GetModule and cc:GetModule("Settings")
            if settingsModule and settingsModule.frame and settingsModule.frame:IsShown()
                and settingsModule.activeProductKey == "COL" then
                settingsModule:RefreshProductPage("COL", "COLLECTIONS")
            end

            if isNewUnlock and cc.Notifications then
                cc.Notifications:Push({
                    sourceAddon = "CRESHCOLLECT",
                    category    = "COLLECTION_UNLOCK",
                    priority    = "NORMAL",
                    title       = "Collection Unlocked",
                    detail      = info.label .. " unlocked: " .. tostring(key),
                    coalesceKey = "COLLECTION_UNLOCK:" .. tostring(key),
                })
            end
        end)
    end
end

-- Bridge CreshCollect modules into CreshChat's namespace so that
-- CC.BattlePass / CC.Achievements etc. references in CreshGames keep working.
-- Safe to call multiple times; only sets keys that are already loaded.
local function bridgeToCreshChat()
    local cc = _G.CreshChat
    if not cc then return end
    local keys = {
        "BattlePass", "GameProgression", "ProgressRouter",
        "Achievements", "AchievementExpansion", "ClassAchievements",
        "DungeonAchievements", "ProgressHub", "CombatTracker",
    }
    for _, k in ipairs(keys) do
        if COL[k] then cc[k] = COL[k] end
    end
end

-- Register CreshCollect as a notification producer in CC.Notifications.
-- Called after CreshChat is confirmed loaded; RegisterSource is idempotent.
local _notifDone = false
local function registerNotifications()
    if _notifDone then return end
    local notif = CC.Notifications
    if not notif then return end
    notif:RegisterSource("CRESHCOLLECT", "CreshCollect")
    notif:RegisterCategory("CRESHCOLLECT", "ACHIEVEMENT",          "Achievement Earned",   "Achievement completion notifications.",            { priority = "NORMAL" })
    notif:RegisterCategory("CRESHCOLLECT", "ACHIEVEMENT_PROGRESS", "Achievement Progress", "Incremental achievement progress updates.",        { priority = "LOW"    })
    notif:RegisterCategory("CRESHCOLLECT", "COLLECTION_UNLOCK",    "Collection Unlocks",   "New collectible or cosmetic unlock notices.",      { priority = "NORMAL" })
    notif:RegisterCategory("CRESHCOLLECT", "COSMETIC_REWARD",      "Cosmetic Rewards",     "Cosmetic item reward notifications.",              { priority = "LOW"    })
    notif:RegisterCategory("CRESHCOLLECT", "MILESTONE",            "Milestones",           "Collection or progression milestone completions.", { priority = "LOW"    })
    _notifDone = true
end

local _frame = CreateFrame("Frame", "CreshCollectFrame")
_frame:RegisterEvent("ADDON_LOADED")
_frame:RegisterEvent("PLAYER_LOGIN")

_frame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        -- Bridge after all our TOC files finish loading, and again if CreshChat
        -- loads after us (no fixed load order without a Dependencies directive).
        if arg1 == addonName or arg1 == "CreshChat" then
            bridgeToCreshChat()
            registerNotifications()
        end
    elseif event == "PLAYER_LOGIN" then
        -- Safety net: ensure bridge and notifications are wired before gameplay.
        bridgeToCreshChat()
        registerNotifications()
    end
end)
