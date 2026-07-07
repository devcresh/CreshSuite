local ADDON_NAME, CC = ...
if not CC then return end

-- CreshChat's own registration against the suite-wide notification service
-- (shared/SuiteNotifications.lua, loaded earlier in this TOC). The
-- registration contract and card renderer both now live on
-- _G.CreshSuiteNotifications so CreshGames/CreshCollect can push and render
-- notifications with CreshChat absent -- see shared/SuiteNotifications.lua
-- for the full contract. CC.Notifications is kept as a plain alias so every
-- existing reference (Settings.lua, GamesSettings.lua, CollectSettings.lua,
-- NotificationsAdapter.lua) keeps working unchanged.

local Notifications = _G.CreshSuiteNotifications
if not Notifications then return end

CC.Notifications = Notifications
if CC.RegisterModule then CC:RegisterModule("Notifications", Notifications) end

-- ----------------------------------------------------------------
-- Built-in CreshChat category registration
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

-- Preserves the exact pre-existing special case (CRESHCHAT categories used
-- to delegate straight to CC:IsNotificationEnabled) via the shared service's
-- generic per-source override hook instead of a hardcoded addon name.
Notifications:RegisterEnabledQuery("CRESHCHAT", function(categoryKey)
    if not CC.IsNotificationEnabled then return true end
    return CC:IsNotificationEnabled(categoryKey)
end)
