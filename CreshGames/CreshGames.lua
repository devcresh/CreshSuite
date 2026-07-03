-- CreshGames registers its notification source with the CreshChat
-- shared service. CreshChat is guaranteed loaded first (see Dependencies).
-- This stub establishes the source and category registry so the Settings
-- panel (Phase 8) can display CreshGames controls before event migration
-- (Phase 6) moves the actual producers here.

local CC = _G.CreshChat
if not CC or not CC.Notifications then return end

CC.Notifications:RegisterSource("CRESHGAMES", "CreshGames")
CC.Notifications:RegisterCategory("CRESHGAMES", "GAME_INVITE",      "Game Invitations",  "Incoming multiplayer game invitations.",       { priority = "CRITICAL" })
CC.Notifications:RegisterCategory("CRESHGAMES", "CHALLENGE",        "Challenges",        "Player challenges and counter-challenges.",    { priority = "HIGH" })
CC.Notifications:RegisterCategory("CRESHGAMES", "MULTIPLAYER_EVENT","Multiplayer Events","Multiplayer session and match events.",        { priority = "NORMAL" })
CC.Notifications:RegisterCategory("CRESHGAMES", "GAME_RESULT",      "Game Results",      "Multiplayer game completion results.",         { priority = "NORMAL" })
CC.Notifications:RegisterCategory("CRESHGAMES", "REWARD",           "Rewards",           "Cresh Coin and game reward notifications.",   { priority = "LOW" })
CC.Notifications:RegisterCategory("CRESHGAMES", "BATTLE_PASS",      "Battle Pass",       "Battle Pass level and reward unlock notices.", { priority = "LOW" })
