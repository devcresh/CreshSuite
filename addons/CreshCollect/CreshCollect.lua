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

-- ----------------------------------------------------------------------------
-- Public API — CreshCollect is the authoritative owner of achievement
-- definitions/completion state, Battle Pass definitions/level/XP/reward state,
-- and collection definitions/unlock state. This table is the only supported
-- way for another addon to query that data; COL.Achievements / COL.BattlePass /
-- COL.* internal module tables are not a public contract and may change shape.
--
-- Every function resolves the underlying module lazily (at call time, not at
-- registration time) and returns a safe default if that module, CreshCollectDB,
-- or CreshCollect itself is not yet loaded — so callers never need to guard
-- anything beyond checking that _G.CreshCollectAPI exists.
--
-- Exposed via two equivalent, guarded access paths:
--   _G.CreshCollectAPI                                (direct global)
--   CreshSuite:GetProduct("CreshCollect").api          (Suite product registry)
-- ----------------------------------------------------------------------------
local API = {}

function API.IsLoaded()
    return true
end

function API.GetVersion()
    return COL.version
end

-- Achievements ----------------------------------------------------------------
function API.IsAchievementUnlocked(key)
    if not COL.Achievements then return false end
    return COL.Achievements:IsUnlocked(key)
end

-- Returns unlocked, total. (0, 0) when achievements aren't loaded yet.
function API.GetAchievementCounts(category)
    if not COL.Achievements then return 0, 0 end
    return COL.Achievements:GetCounts(category)
end

-- Returns available, missingAddon. Completed achievements remain queryable
-- even when their owning addon is currently disabled.
function API.GetAchievementAvailability(key)
    if not COL.Achievements or not COL.Achievements.IsAvailable then return false, nil end
    return COL.Achievements:IsAvailable(key)
end

-- Battle Pass -------------------------------------------------------------
-- Returns level, currentXP, requiredXP, ratio. (1, 0, 50, 0) when not loaded.
function API.GetBattlePassProgress()
    if not COL.BattlePass then return 1, 0, 50, 0 end
    return COL.BattlePass:GetProgress()
end

function API.IsBattlePassRewardClaimed(level)
    if not COL.BattlePass then return false end
    return COL.BattlePass:IsRewardClaimed(level)
end

function API.GetBattlePassReward(level)
    if not COL.BattlePass then return nil end
    return COL.BattlePass:GetReward(level)
end

function API.GetThemeAvailability(key)
    if not COL.BattlePass or not COL.BattlePass.IsThemeAvailable then return false, nil end
    return COL.BattlePass:IsThemeAvailable(key)
end

-- ------------------------------------------------------------------------
-- Rework Phase 1: forward-looking "Chronicle" naming and world/chat-theme
-- entitlement queries for the Progression and Unlockables Rework. These wrap
-- the same modules as the functions above (no data has moved) so existing
-- callers are unaffected; new code should prefer these names going forward.
-- ------------------------------------------------------------------------

-- Same backing data as GetBattlePassProgress today; Phase 6 will repoint
-- this at the dedicated Azeroth Chronicle track once it exists.
function API.GetChronicleProgress()
    return API.GetBattlePassProgress()
end

-- Every remaining category in COL.Achievements is a World achievement
-- category now that Rework Phase 5 moved GAMES (and the separate Dungeon
-- Dwellers catalog) out to CreshGames, so this is just GetCounts() -- kept
-- as its own named function since callers rely on this exact name.
function API.GetWorldAchievementCounts()
    if not COL.Achievements then return 0, 0 end
    return COL.Achievements:GetCounts()
end

-- Returns an array of { key, source } for every CreshChat theme currently
-- entitled through CreshCollect's Battle Pass. This is the authoritative
-- entitlement list Phase 7's CreshChat union-only cache will sync from.
function API.GetChatThemeEntitlements()
    if not COL.BattlePass or not COL.BattlePass.Ensure then return {} end
    local save = COL.BattlePass:Ensure()
    if not save or type(save.unlockedThemes) ~= "table" then return {} end
    local result = {}
    for key, unlocked in pairs(save.unlockedThemes) do
        if unlocked then
            result[#result + 1] = { key = key, source = save.themeUnlockSources and save.themeUnlockSources[key] or nil }
        end
    end
    return result
end

function API.GetChatThemeUnlockSource(key)
    if not COL.BattlePass or not COL.BattlePass.Ensure then return nil end
    local save = COL.BattlePass:Ensure()
    if not save or type(save.themeUnlockSources) ~= "table" then return nil end
    return save.themeUnlockSources[tostring(key or "")]
end

-- Collections -------------------------------------------------------------
-- bucket is one of: themes, backgrounds, cardDecks, dungeonArmour, cosmetics.
function API.IsCollectionUnlocked(bucket, key)
    if type(bucket) ~= "string" or key == nil then return false end
    if type(CreshCollectDB) ~= "table" then return false end
    local col = CreshCollectDB.collections
    if type(col) ~= "table" or type(col[bucket]) ~= "table" then return false end
    return col[bucket][key] == true
end

_G.CreshCollectAPI = API

-- Suite registration
do
    local Suite = _G.CreshSuite
    if Suite then
        Suite:RegisterProduct("CreshCollect", COL.version, API)

        -- Formal "open this feature" contract for CreshChat's commands and
        -- launcher buttons, so they can ask "is CreshCollect able to do this?"
        -- via the Suite instead of reaching into CC.ProgressHub / CC.Achievements /
        -- CC.BattlePass directly. ProgressHub, Achievements and Battle Pass
        -- each own their own standalone window (see ProgressHub.lua,
        -- Achievements.lua, BattlePass.lua) -- none of these route through
        -- CreshChat's shared game drawer, so opening them never opens an
        -- unrelated CreshChat window.
        --
        -- "OpenProgressHub" (the service backing /cc progress, /cc hub and
        -- /cc tracking) now opens the dedicated ProgressOverview window
        -- (Phase 7) instead of the older, generic ProgressHub -- that older
        -- window (World/Quest/Combat tracking) is untouched and still
        -- reachable via a nav button inside ProgressOverview itself, so
        -- nothing becomes unreachable.
        Suite:RegisterService("OpenProgressHub", function()
            if COL.ProgressOverview and COL.ProgressOverview.ToggleWindow then COL.ProgressOverview:ToggleWindow() end
        end)
        Suite:RegisterService("OpenAchievements", function()
            if COL.Achievements and COL.Achievements.ToggleWindow then COL.Achievements:ToggleWindow() end
        end)
        Suite:RegisterService("OpenBattlePass", function()
            if COL.BattlePass and COL.BattlePass.ToggleWindow then COL.BattlePass:ToggleWindow() end
        end)
        -- Forward-looking alias ("Azeroth Chronicle" is this window's Rework name).
        Suite:RegisterService("OpenChronicle", function()
            if COL.BattlePass and COL.BattlePass.ToggleWindow then COL.BattlePass:ToggleWindow() end
        end)

        -- Read-only legacy snapshot for CreshGames' one-time migration of
        -- per-game levels (Phase 10 split): lets GameProgression.lua pick up
        -- existing players' pre-split levels without ever reaching directly
        -- into CreshCollectDB (mirrors CreshGames' own
        -- GetLegacyProgressionSnapshot service for the reverse direction).
        Suite:RegisterService("GetLegacyGameLevels", function()
            if not _G.CreshCollectDB then return nil end
            local root = _G.CreshCollectDB.gameProgression
            return root and root.games or nil
        end)

        -- Read-only legacy snapshot for CreshGames' one-time-per-key
        -- migration of achievement completions (Rework Phase 5: the 23
        -- ex-GAMES achievements and the 93 Dungeon Dwellers achievements
        -- both moved to CreshGames). Returns the raw unlocked tables from
        -- both of CreshCollect's old locations; CreshGames filters by its
        -- own catalog's keys, so this never needs to know which specific
        -- keys used to belong to which category. Also subsumes the old
        -- DungeonAchievements:MigrateFromWoW special case (stray ACH_DD_*
        -- keys that leaked into the WoW achievements table pre-split) --
        -- both live in achievementsUnlocked here, both filtered the same way.
        Suite:RegisterService("GetLegacyGameAchievements", function()
            if not _G.CreshCollectDB then return nil end
            local achRoot = _G.CreshCollectDB.achievements
            local ddRoot = _G.CreshCollectDB.ddAchievements
            return {
                achievementsUnlocked = achRoot and type(achRoot.unlocked) == "table" and achRoot.unlocked or nil,
                dungeonUnlocked      = ddRoot and type(ddRoot.unlocked) == "table" and ddRoot.unlocked or nil,
            }
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
            -- key must be a real, non-empty string: a collection item name,
            -- not a number/boolean/table. Without this, a malformed publish
            -- (e.g. a stray numeric or table key) would insert a bogus entry
            -- into an otherwise all-string-keyed SavedVariables table instead
            -- of being rejected as an unknown/invalid unlock.
            if type(key) ~= "string" or key == "" then return end
            if type(uType) ~= "string" then return end
            local info = UNLOCK_TYPES[uType]
            if not info then return end
            if type(col[info.bucket]) ~= "table" then return end
            local isNewUnlock = col[info.bucket][key] == nil
            col[info.bucket][key] = col[info.bucket][key] or true

            -- Same single centralized refresh point extended for the
            -- Progress Overview's Collections card, rather than adding a
            -- second, parallel event hook.
            if COL.ProgressOverview and COL.ProgressOverview.RefreshWindow then COL.ProgressOverview:RefreshWindow() end

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
    -- GameProgression is not bridged here any more: per-game level tracking
    -- moved to CreshGames/GameProgression.lua (Phase 10), which bridges its
    -- own CC.GameProgression. This module keeps only world-exploration
    -- tracking (COL.GameProgression itself), which nothing outside
    -- CreshCollect needs to reach.
    -- DungeonAchievements is not bridged here any more either (Rework Phase
    -- 5): it moved to CreshGames/GamesDungeonAchievements.lua, merged into
    -- CG.Achievements, which bridges as CC.GamesAchievements instead --
    -- CC.Achievements stays this addon's own (now World-only) catalog.
    local keys = {
        "BattlePass", "ProgressRouter",
        "Achievements", "AchievementExpansion", "ClassAchievements",
        "ProgressHub", "ProgressOverview", "CombatTracker",
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
        -- Ensure the shared launcher exists even when CreshChat is absent --
        -- idempotent, a no-op if another addon already built it.
        if _G.CreshSuiteLauncherAPI and _G.CreshSuiteLauncherAPI.EnsureBuilt then
            _G.CreshSuiteLauncherAPI:EnsureBuilt()
        end
    end
end)
