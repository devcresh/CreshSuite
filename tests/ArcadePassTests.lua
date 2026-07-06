-- ArcadePassTests.lua
-- Rework Phase 3 regression coverage for the expanded 100-level Arcade
-- Battle Pass: direct XP sources (game start, game result, achievement
-- completion, Mastery level-up), anti-farm/duplicate-submission guards,
-- claim-all idempotency, and level-calculation boundary tests.
--
-- Loads the REAL production files, in real cross-addon load order.
-- Usage: lua ArcadePassTests.lua

local _mockNow = 1000
function CreateFrame() return { SetScript = function() end, RegisterEvent = function() end } end
function time() return _mockNow end
function GetTime() return _mockNow end
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

local function loadProductionFile(path, ...)
    local f = assert(io.open(path, "rb"))
    local src = f:read("*a")
    f:close()
    if src:sub(1, 3) == "\239\187\191" then src = src:sub(4) end
    local chunk = assert(loadstring(src, "@" .. path))
    return chunk(...)
end

-- ============================================================
-- Load CreshGames alone first (no CreshCollect, no CreshChat at all) to
-- prove the pass works fully standalone -- exit criterion "Pass works
-- without CreshCollect or CreshChat."
-- ============================================================
loadProductionFile("shared/Suite.lua", "CreshGames", {})

local CG = { version = "0.2.3" }
loadProductionFile("addons/CreshGames/CreshGames.lua", "CreshGames", CG)
loadProductionFile("addons/CreshGames/CardDeckLibrary.lua", "CreshGames", CG)
loadProductionFile("addons/CreshGames/CardDecks.lua", "CreshGames", CG)
loadProductionFile("addons/CreshGames/DungeonCrawlerContent.lua", "CreshGames", CG)
loadProductionFile("addons/CreshGames/TetrisThemes.lua", "CreshGames", CG)
loadProductionFile("addons/CreshGames/GamesBattlePass.lua", "CreshGames", CG)
loadProductionFile("addons/CreshGames/GameProgression.lua", "CreshGames", CG)
loadProductionFile("addons/CreshGames/DungeonDwellersProgression.lua", "CreshGames", CG)

local function freshState()
    _G.CreshGamesDB = { cardDecks = {}, battlePass = {} }
end

-- ============================================================
-- 1. Pass works fully without CreshCollect or CreshChat installed.
-- ============================================================
section("Arcade Pass functions without CreshCollect or CreshChat loaded")
freshState()
ok(_G.CreshCollect == nil, "sanity: CreshCollect is genuinely not loaded in this process")
ok(_G.CreshChat == nil, "sanity: CreshChat is genuinely not loaded in this process")
local okStart = pcall(function() CG.BattlePass:AwardGameStart("FROGGER", "SOLO", true) end)
ok(okStart, "AwardGameStart does not error without CreshChat/CreshCollect")
local okResult = pcall(function() CG.BattlePass:AwardGameResult({ game = "FROGGER", mode = "SOLO", result = "RUN", score = 100 }, true) end)
ok(okResult, "AwardGameResult does not error without CreshChat/CreshCollect")
local okClaim = pcall(function() CG.BattlePass:ClaimAllAvailable() end)
ok(okClaim, "ClaimAllAvailable does not error without CreshChat/CreshCollect")

-- ============================================================
-- 2. Anti-farm: rapid repeat "game start" within the cooldown window pays
--    no further XP; after the cooldown elapses, it pays again.
-- ============================================================
section("Game-start XP is anti-farmed by a per-game cooldown")
freshState()
_mockNow = 1000
local firstAmount = CG.BattlePass:AwardGameStart("CHESS", "SOLO", true)
ok(firstAmount > 0, "first start of a session grants XP")
local secondAmount = CG.BattlePass:AwardGameStart("CHESS", "SOLO", true)
eq(secondAmount, 0, "an immediate repeat start for the same game grants no XP")
_mockNow = 1000 + CG.BattlePass.balance.xpGameStartCooldownSeconds + 1
local thirdAmount = CG.BattlePass:AwardGameStart("CHESS", "SOLO", true)
ok(thirdAmount > 0, "a start after the cooldown window elapses grants XP again")
_mockNow = 1000

-- ============================================================
-- 3. Duplicate result submission: the exact same completed-game entry
--    cannot pay XP twice.
-- ============================================================
section("Duplicate game-result submission is rejected")
freshState()
local entry = { game = "HOLDEM", mode = "SOLO", result = "WIN", score = 0, timestamp = 5000 }
local firstXP = CG.BattlePass:AwardGameResult(entry, true)
ok(firstXP > 0, "first submission of a result grants XP")
local secondXP = CG.BattlePass:AwardGameResult(entry, true)
eq(secondXP, 0, "resubmitting the identical result grants no further XP")
local differentEntry = { game = "HOLDEM", mode = "SOLO", result = "WIN", score = 0, timestamp = 5001 }
local thirdXP = CG.BattlePass:AwardGameResult(differentEntry, true)
ok(thirdXP > 0, "a genuinely different result (different timestamp) still grants XP")

-- ============================================================
-- 4. Score milestones and the multiplayer multiplier.
-- ============================================================
section("Score milestones and multiplayer completion increase XP")
freshState()
local lowScore = CG.BattlePass:AwardGameResult({ game = "FROGGER", mode = "SOLO", result = "RUN", score = 0, timestamp = 1 }, true)
freshState()
local highScore = CG.BattlePass:AwardGameResult({ game = "FROGGER", mode = "SOLO", result = "RUN", score = 5000, timestamp = 1 }, true)
ok(highScore > lowScore, "a high-score RUN result grants more XP than a zero-score RUN result")

freshState()
local soloWin = CG.BattlePass:AwardGameResult({ game = "PONG", mode = "SOLO", result = "WIN", score = 0, timestamp = 1 }, true)
freshState()
local multiWin = CG.BattlePass:AwardGameResult({ game = "PONG", mode = "MULTIPLAYER", result = "WIN", score = 0, timestamp = 1 }, true)
eq(multiWin, soloWin * CG.BattlePass.balance.xpMultiplayerMultiplier, "a multiplayer win grants exactly xpMultiplayerMultiplier times a solo win")

-- ============================================================
-- 5. Mastery level-ups (Tetris Pass, Dungeon Dwellers Pass) pay Arcade Pass
--    XP directly, same addon, no Suite hop.
-- ============================================================
section("Tetris Pass and Dungeon Dwellers Pass level-ups fund the Arcade Pass")
freshState()
local beforeTetris = CG.BattlePass:Ensure().xp
CG.Tetris:Ensure()
CreshGamesDB.soloGames.tetris.passXP = 0
CG.Tetris:AddPassXP(CG.Tetris:GetPassNextCost(1) + 1, "TEST")
local afterTetris = CG.BattlePass:Ensure().xp
eq(afterTetris - beforeTetris, CG.BattlePass.balance.xpMasteryLevelUp, "a Tetris Pass level-up grants exactly xpMasteryLevelUp Arcade Pass XP")

local beforeDungeon = CG.BattlePass:Ensure().xp
CG.DungeonDwellersPass:Ensure()
CG.DungeonDwellersPass:AddXP(CG.DungeonDwellersPass:GetNextLevelCost(1) + 1, "TEST", "mobKills", true)
local afterDungeon = CG.BattlePass:Ensure().xp
eq(afterDungeon - beforeDungeon, CG.BattlePass.balance.xpMasteryLevelUp, "a Dungeon Dwellers Pass level-up grants exactly xpMasteryLevelUp Arcade Pass XP")

-- ============================================================
-- 6. Achievement-completion hook. Rework Phase 3 originally reached this via
--    a Suite subscription to CreshCollect's unlock notification (GAMES
--    achievements were CreshCollect-owned then); Phase 5 moved that catalog
--    into CreshGames and retired the subscription -- GamesAchievements.lua's
--    Unlock() now calls this directly, same addon. This test exercises the
--    Arcade Pass side of that contract directly, independent of the caller.
-- ============================================================
section("Achievement completion funds the Arcade Pass")
freshState()
local beforeAch = CG.BattlePass:Ensure().xp
CG.BattlePass:AwardAchievementCompletion(true)
local afterAch = CG.BattlePass:Ensure().xp
eq(afterAch - beforeAch, CG.BattlePass.balance.xpAchievementUnlock, "AwardAchievementCompletion grants exactly xpAchievementUnlock Arcade Pass XP")

-- ============================================================
-- 7. Capstone: reaching and claiming level 100 sets save.arcadeChampion.
-- ============================================================
section("Reaching and claiming level 100 sets the Arcade Champion flag")
freshState()
local save100 = CG.BattlePass:Ensure()
save100.xp = CG.BattlePass:GetCumulativeXP(100)
eq(save100.arcadeChampion, false, "arcadeChampion starts false")
CG.BattlePass:ClaimReward(100, true)
eq(save100.arcadeChampion, true, "arcadeChampion becomes true after claiming level 100")

-- ============================================================
-- 8. Claim-all idempotency.
-- ============================================================
section("ClaimAllAvailable is idempotent")
freshState()
CG.BattlePass:Ensure().xp = CG.BattlePass:GetCumulativeXP(30)
local claimed1, coins1 = CG.BattlePass:ClaimAllAvailable()
ok(claimed1 > 0, "first ClaimAllAvailable call claims at least one level")
local coinsAfterFirst = CG.BattlePass:Ensure().coins
local claimed2, coins2 = CG.BattlePass:ClaimAllAvailable()
eq(claimed2, 0, "second consecutive ClaimAllAvailable call claims nothing new")
eq(coins2, 0, "second consecutive ClaimAllAvailable call awards no additional coins")
eq(CG.BattlePass:Ensure().coins, coinsAfterFirst, "total coins are unchanged by the idempotent second call")

-- ============================================================
-- 9. Level-calculation boundary tests.
-- ============================================================
section("Level calculation boundary tests")
eq(CG.BattlePass:GetLevelFromXP(0), 1, "0 XP is level 1")
eq(CG.BattlePass:GetCumulativeXP(1), 0, "level 1 requires 0 cumulative XP")
eq(CG.BattlePass:GetLevelFromXP(CG.BattlePass:GetCumulativeXP(100)), 100, "XP exactly at level 100's threshold resolves to level 100")
eq(CG.BattlePass:GetLevelFromXP(CG.BattlePass:GetCumulativeXP(100) - 1), 99, "one XP short of level 100's threshold resolves to level 99")
eq(CG.BattlePass:GetLevelFromXP(999999999), 100, "far more XP than the pass could ever need still clamps to level 100 (max)")
eq(CG.BattlePass:GetLevelFromXP(-50), 1, "negative XP clamps to level 1")
local monotonic = true
for level = 1, 99 do
    if CG.BattlePass:GetCumulativeXP(level + 1) <= CG.BattlePass:GetCumulativeXP(level) then monotonic = false end
end
ok(monotonic, "cumulative XP strictly increases across every one of the 100 levels")

-- ============================================================
-- Summary
-- ============================================================
print(("\n=== Results: %d passed, %d failed ==="):format(PASS, FAIL))
if FAIL > 0 then os.exit(1) end
