local ADDON_NAME, CC = ...
if not CC then return end

-- Shared notification service owned by CreshChat.
-- Exposed globally via _G.CreshChat.Notifications so CreshGames and
-- CreshCollect can register without importing internal state.
-- No frames, queues, timers or callbacks are created here.
-- Card rendering arrives in Phase 3; stack management in Phase 4.

local Notifications = {}
CC.Notifications = Notifications
if CC.RegisterModule then CC:RegisterModule("Notifications", Notifications) end

local sources    = {}  -- [SOURCE_ADDON]          = { label, categories={} }
local categories = {}  -- [SOURCE_ADDON:CATEGORY]  = { sourceAddon, key, label, description, priority, soundEnabled }

-- ----------------------------------------------------------------
-- Registration
-- ----------------------------------------------------------------

function Notifications:RegisterSource(sourceAddon, label)
    sourceAddon = string.upper(tostring(sourceAddon or ""))
    if sourceAddon == "" then return false end
    if not sources[sourceAddon] then
        sources[sourceAddon] = { label = tostring(label or sourceAddon), categories = {} }
    end
    return true
end

-- options = { priority = "NORMAL", soundEnabled = true }
function Notifications:RegisterCategory(sourceAddon, categoryKey, label, description, options)
    sourceAddon = string.upper(tostring(sourceAddon or ""))
    categoryKey = string.upper(tostring(categoryKey or ""))
    if sourceAddon == "" or categoryKey == "" then return false end
    if not sources[sourceAddon] then self:RegisterSource(sourceAddon) end
    options = type(options) == "table" and options or {}
    local priority = string.upper(tostring(options.priority or "NORMAL"))
    if priority ~= "CRITICAL" and priority ~= "HIGH" and priority ~= "NORMAL" and priority ~= "LOW" then
        priority = "NORMAL"
    end
    local fullKey = sourceAddon .. ":" .. categoryKey
    categories[fullKey] = {
        sourceAddon  = sourceAddon,
        key          = categoryKey,
        label        = tostring(label or categoryKey),
        description  = tostring(description or ""),
        priority     = priority,
        soundEnabled = options.soundEnabled ~= false,
    }
    sources[sourceAddon].categories[categoryKey] = fullKey
    return true
end

-- ----------------------------------------------------------------
-- Enable queries
-- ----------------------------------------------------------------

function Notifications:IsSourceEnabled(sourceAddon)
    sourceAddon = string.upper(tostring(sourceAddon or ""))
    if not sources[sourceAddon] then return false end
    if CC.IsFeatureEnabled and not CC:IsFeatureEnabled("notifications") then return false end
    return true
end

function Notifications:IsCategoryEnabled(sourceAddon, categoryKey)
    sourceAddon = string.upper(tostring(sourceAddon or ""))
    categoryKey = string.upper(tostring(categoryKey or ""))
    if not self:IsSourceEnabled(sourceAddon) then return false end
    if sourceAddon == "CRESHCHAT" then
        -- Delegate to the existing per-category db flag; CC:IsNotificationEnabled
        -- guards against a nil db internally so this is safe before PLAYER_LOGIN.
        return not CC.IsNotificationEnabled or CC:IsNotificationEnabled(categoryKey)
    end
    -- Check per-source per-category toggle saved by the Notifications settings page.
    local srcs = CC.db and CC.db.notificationSources
    if srcs and srcs[sourceAddon] and srcs[sourceAddon][categoryKey] == false then
        return false
    end
    return categories[sourceAddon .. ":" .. categoryKey] ~= nil
end

-- ----------------------------------------------------------------
-- Settings query
-- ----------------------------------------------------------------

function Notifications:GetSettings()
    return {
        enabled    = not (CC.IsFeatureEnabled and not CC:IsFeatureEnabled("notifications")),
        sources    = sources,
        categories = categories,
    }
end

function Notifications:GetRegisteredSources()
    return sources
end

function Notifications:GetRegisteredCategories(sourceAddon)
    if sourceAddon then
        sourceAddon = string.upper(tostring(sourceAddon))
        local src = sources[sourceAddon]
        if not src then return {} end
        local result = {}
        for key, fullKey in pairs(src.categories) do
            result[key] = categories[fullKey]
        end
        return result
    end
    return categories
end

-- ----------------------------------------------------------------
-- Push / Dismiss  (stubs; full implementation in Phase 3 and 4)
-- ----------------------------------------------------------------

-- Normalized event fields:
--   sourceAddon, category, priority, title, detail,
--   icon, iconType, playerName, playerGUID, classFile, race, status,
--   accent, coalesceKey, destination, actions, duration, fallbackBehaviour
function Notifications:Push(event)
    if type(event) ~= "table" then return false end
    local src = string.upper(tostring(event.sourceAddon or "CRESHCHAT"))
    local cat = string.upper(tostring(event.category  or "SYSTEM"))
    return self:IsCategoryEnabled(src, cat)
end

function Notifications:Dismiss(id)
    -- Phase 3+ dismisses live cards by id.
    return false
end

-- ----------------------------------------------------------------
-- Built-in CreshChat category registration
-- Called immediately; Core.lua and FeatureManager.lua are already
-- loaded at this point (Notifications.lua follows them in the TOC).
-- ----------------------------------------------------------------

local function registerBuiltInCategories()
    Notifications:RegisterSource("CRESHCHAT", "CreshChat")
    Notifications:RegisterCategory("CRESHCHAT", "WHISPER",       "Whispers",          "Direct messages and Battle.net whispers.",                { priority = "HIGH" })
    Notifications:RegisterCategory("CRESHCHAT", "GUILD",         "Guild",             "Guild and Officer messages.",                             { priority = "NORMAL" })
    Notifications:RegisterCategory("CRESHCHAT", "PARTY_INVITE",  "Party Invitations", "Actionable incoming party invitations.",                  { priority = "CRITICAL" })
    Notifications:RegisterCategory("CRESHCHAT", "PARTY_MESSAGE", "Party Messages",    "Party, raid and instance-group messages.",                { priority = "HIGH" })
    Notifications:RegisterCategory("CRESHCHAT", "GENERAL",       "Public Mentions",   "Public-channel messages that mention your character.",    { priority = "NORMAL" })
    Notifications:RegisterCategory("CRESHCHAT", "FRIEND",        "Friends",           "Battle.net and character-friend online/offline notices.", { priority = "LOW" })
    Notifications:RegisterCategory("CRESHCHAT", "QUEST",         "Quest Dialogue",    "Quest dialogue captured by CreshChat.",                   { priority = "HIGH" })
    Notifications:RegisterCategory("CRESHCHAT", "SYSTEM",        "System",            "CreshChat status, group-state and system cards.",         { priority = "NORMAL" })
    Notifications:RegisterCategory("CRESHCHAT", "GAME",          "Games and Rewards", "Battle Pass, unlock and reward cards.",                   { priority = "LOW" })
    Notifications:RegisterCategory("CRESHCHAT", "VOICE",         "Voice Requests",    "Voice call connection notices.",                          { priority = "NORMAL" })
end

registerBuiltInCategories()
