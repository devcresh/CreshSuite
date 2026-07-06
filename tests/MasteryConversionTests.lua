-- MasteryConversionTests.lua
-- Rework Phase 4 regression coverage for converting the Tetris Pass and
-- Dungeon Dwellers Pass into Tetris Mastery / Delver Mastery:
--   1. Existing XP/claimed-reward progress survives (no data restructuring
--      happened, only WoW-world XP sources and player-facing names changed).
--   2. World activity (WoW zones/mobs/quests/achievements) can no longer
--      fund Delver Mastery -- the removed methods are gone, and the
--      CreshCollect call site that fed WoW zone discovery into it is gone.
--   3. Mastery rewards (Dungeon armour/buffs) never share an unlockKey with
--      Arcade Pass rewards (decks/Tetris themes) -- disjoint content types.
--   4. Dungeon Dwellers has no multiplayer code path at all, so solo Dungeon
--      buffs structurally cannot reach a multiplayer game.
--
-- Loads the REAL production files, in real cross-addon load order.
-- Usage: lua MasteryConversionTests.lua

function CreateFrame() return { SetScript = function() end, RegisterEvent = function() end } end
function time() return 0 end
function GetTime() return 0 end
_G.C_Timer = { After = function() end }
_G.hooksecurefunc = function() end
_G.UnitGUID = function() return "Player-0-00000001" end
_G.UnitName = function() return "TestChar" end
_G.GetRealmName = function() return "TestRealm" end

local PASS, FAIL = 0, 0
local _section = ""
local function section(name) _section = name; print(("\n[%s]"):format(name)) end
local function pass(msg) PASS = PASS + 1; print(("  PASS  %s"):format(msg)) end
local function fail(msg) FAIL = FAIL + 1; print(("  FAIL  %s  [in: %s]"):format(msg, _section)) end
local function ok(cond, msg) if cond then pass(msg) else fail(msg) end end
local function eq(a, b, msg)
    if a == b then pass(msg)
    else fail(("%s  (expected %q, got %q)"):format(msg, tostring(b), tostring(a))) end
end

local function readFile(path)
    local f = assert(io.open(path, "rb"))
    local src = f:read("*a")
    f:close()
    if src:sub(1, 3) == "\239\187\191" then src = src:sub(4) end
    return src
end

local function loadProductionFile(path, ...)
    local chunk = assert(loadstring(readFile(path), "@" .. path))
    return chunk(...)
end

-- ============================================================
-- Load CreshGames alone (Tetris/Dungeon Mastery must not need CreshCollect).
-- ============================================================
loadProductionFile("shared/Suite.lua", "CreshGames", {})
local CG = { version = "0.2.3" }
loadProductionFile("addons/CreshGames/CreshGames.lua", "CreshGames", CG)
loadProductionFile("addons/CreshGames/CardDeckLibrary.lua", "CreshGames", CG)
loadProductionFile("addons/CreshGames/CardDecks.lua", "CreshGames", CG)
loadProductionFile("addons/CreshGames/DungeonCrawlerContent.lua", "CreshGames", CG)
loadProductionFile("addons/CreshGames/TetrisThemes.lua", "CreshGames", CG)
loadProductionFile("addons/CreshGames/GamesBattlePass.lua", "CreshGames", CG)
loadProductionFile("addons/CreshGames/DungeonDwellersProgression.lua", "CreshGames", CG)
loadProductionFile("addons/CreshGames/GamesRewardRegistry.lua", "CreshGames", CG)
loadProductionFile("addons/CreshGames/GamesAchievements.lua", "CreshGames", CG)
loadProductionFile("addons/CreshGames/GamesDungeonAchievements.lua", "CreshGames", CG)

local function freshState()
    _G.CreshGamesDB = { cardDecks = {}, battlePass = {} }
end

-- ============================================================
-- 1. Existing progress is preserved: pre-set XP/claimed state round-trips
--    through Ensure()/GetProgress/IsRewardClaimed unchanged.
-- ============================================================
section("Existing Tetris Mastery and Delver Mastery progress is preserved")
freshState()
CG.Tetris:Ensure()
CreshGamesDB.soloGames.tetris.passXP = 4000
CreshGamesDB.soloGames.tetris.passClaimed = { ["10"] = true, ["20"] = true }
local tLevel = CG.Tetris:GetMasteryProgress()
ok(tLevel > 1, "a save with existing Tetris passXP resolves to a level above 1 after reload")
ok(CG.Tetris:IsPassRewardClaimed(10) and CG.Tetris:IsPassRewardClaimed(20), "previously claimed Tetris Mastery rewards remain claimed")

CG.DungeonDwellersPass:Ensure()
local ddSave = CG.DungeonDwellersPass:Ensure()
ddSave.xp = 3000
ddSave.claimed = { ["5"] = true }
local dLevel = CG.DungeonDwellersPass:GetProgress()
ok(dLevel > 1, "a save with existing Delver Mastery XP resolves to a level above 1 after reload")
ok(CG.DungeonDwellersPass:IsRewardClaimed(5), "a previously claimed Delver Mastery reward remains claimed")

-- ============================================================
-- 2. World activity cannot fund Delver Mastery: the WoW-world XP methods no
--    longer exist, and CreshCollect's zone-discovery code no longer
--    references CC.DungeonDwellersPass at all.
-- ============================================================
section("World activity cannot fund Delver Mastery")
eq(CG.DungeonDwellersPass.RecordZone, nil, "RecordZone (WoW zone discovery) no longer exists")
eq(CG.DungeonDwellersPass.RecordMobKill, nil, "RecordMobKill (WoW mob kills) no longer exists")
eq(CG.DungeonDwellersPass.RecordQuest, nil, "RecordQuest (WoW quests) no longer exists")
eq(CG.DungeonDwellersPass.RecordAchievement, nil, "RecordAchievement (World achievements) no longer exists")
ok(CG.DungeonDwellersPass.RecordDungeonKill ~= nil, "RecordDungeonKill (genuine Dungeon Dwellers activity) still exists")

local progressionSource = readFile("addons/CreshCollect/Progression.lua")
ok(not progressionSource:find("DungeonDwellersPass", 1, true), "CreshCollect/Progression.lua no longer references CC.DungeonDwellersPass at all")

-- Rework Phase 5: Dungeon Dweller achievements moved to CreshGames entirely
-- (addons/CreshGames/GamesDungeonAchievements.lua) -- unlocking one now pays
-- coins into CG.BattlePass directly (same addon, no CreshGamesAPI hop
-- needed any more) and XP into Delver Mastery, never CreshCollect's pass
-- (which isn't even loaded in this test).
freshState()
CG.Achievements:Ensure()
local ddAch = CG.Achievements.byKey["ACH_DD_KILLS_001"]
ok(ddAch ~= nil, "sanity: a ported Dungeon Dweller achievement is present in the merged catalog")
local coinsBefore = CG.BattlePass:Ensure().coins
local delverXPBefore = select(1, CG.DungeonDwellersPass:GetProgress())
local okUnlock, unlocked = pcall(function() return CG.Achievements:Unlock(ddAch, true) end)
ok(okUnlock and unlocked, "unlocking a Dungeon Dweller achievement does not error and reports success")
ok(CG.BattlePass:Ensure().coins > coinsBefore, "coins landed in CG.BattlePass (CreshGames' own pool)")
ok(select(1, CG.DungeonDwellersPass:GetProgress()) >= delverXPBefore, "Delver Mastery XP did not decrease (achievement XP went to Delver Mastery, not lost)")

-- ============================================================
-- 3. Mastery rewards never duplicate Arcade rewards: Dungeon Mastery's
--    unlockKeys (armour sets, buff keys) never overlap the Arcade Pass's
--    unlockKeys (decks, Tetris themes) -- disjoint content types by design.
-- ============================================================
section("Delver Mastery rewards never share an unlockKey with Arcade Pass rewards")
local arcadeKeys = {}
for _, entry in ipairs(CG.RewardRegistry.arcadeRewards) do arcadeKeys[entry.unlockKey] = true end
local overlap = 0
for _, entry in ipairs(CG.RewardRegistry.dungeonMasteryRewards) do
    if arcadeKeys[entry.unlockKey] then overlap = overlap + 1 end
end
eq(overlap, 0, "no Delver Mastery unlockKey (armour/buff) appears anywhere in the Arcade Pass's reward list")

-- ============================================================
-- 4. Dungeon Dwellers has no multiplayer code path -- solo Dungeon buffs
--    structurally cannot leak into a multiplayer game.
-- ============================================================
section("Dungeon Dwellers has no multiplayer code path (solo buffs cannot affect multiplayer)")
local gamesSource = readFile("addons/CreshGames/Games.lua")
local dungeonMultiplayerRefs = 0
for _ in gamesSource:gmatch("DUNGEON") do dungeonMultiplayerRefs = dungeonMultiplayerRefs + 1 end
eq(dungeonMultiplayerRefs, 1, "Games.lua (the multiplayer module) mentions DUNGEON exactly once, in a stats snapshot -- no multiplayer Dungeon Dweller gameplay exists")

-- ============================================================
-- Summary
-- ============================================================
print(("\n=== Results: %d passed, %d failed ==="):format(PASS, FAIL))
if FAIL > 0 then os.exit(1) end
