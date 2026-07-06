-- GamesAchievementsTests.lua
-- Rework Phase 5 regression coverage for moving CreshGames' 23 achievements
-- and Dungeon Dwellers' 93 achievements out of CreshCollect:
--   1. CreshCollect reports only World achievement counts (no GAMES category).
--   2. CreshGames reports all 116 addon-game achievements (23 + 93).
--   3. Migration preserves completions and their original timestamps.
--   4. Migration never grants rewards twice (coins/XP untouched by import).
--   5. Both addons work independently of each other.
--
-- Loads the REAL production files, in real cross-addon load order.
-- Usage: lua GamesAchievementsTests.lua

function CreateFrame() return { SetScript = function() end, RegisterEvent = function() end } end
function time() return 0 end
function GetTime() return 0 end
_G.GetServerTime = function() return 0 end
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
-- 1. CreshGames alone (no CreshCollect at all) -- exit criterion "both
--    addons work independently."
-- ============================================================
section("CreshGames achievements work fully without CreshCollect")

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
loadProductionFile("addons/CreshGames/GamesAchievements.lua", "CreshGames", CG)
loadProductionFile("addons/CreshGames/GamesDungeonAchievements.lua", "CreshGames", CG)

local function freshGamesState()
    _G.CreshGamesDB = { cardDecks = {}, battlePass = {} }
    _G.CreshCollectDB = nil
end

freshGamesState()
ok(_G.CreshCollect == nil, "sanity: CreshCollect is genuinely not loaded in this process")
local okEnsure, gaSave = pcall(function() return CG.Achievements:Ensure() end)
ok(okEnsure and gaSave ~= nil, "Achievements:Ensure() does not error and returns a save table without CreshCollect")
local okEval = pcall(function() return CG.Achievements:EvaluateAll(true) end)
ok(okEval, "EvaluateAll() does not error without CreshCollect (SyncLegacyCompletions finds no service and no-ops)")

-- ============================================================
-- 2. CreshGames reports all 116 addon-game achievements (23 + 93).
-- ============================================================
section("CreshGames catalog has exactly 116 achievements across the ported categories")
eq(#CG.Achievements.catalog, 116, "catalog has 23 (ex-GAMES) + 93 (Dungeon Dwellers) = 116 entries")
local _, arcadeTotal = CG.Achievements:GetCounts("ARCADE")
local _, collectionTotal = CG.Achievements:GetCounts("COLLECTION")
local _, dungeonTotal = CG.Achievements:GetCounts("DUNGEON_DWELLERS")
eq(arcadeTotal, 17, "ARCADE category has 17 entries (GAME_PLAYS 6 + GAME_WINS 5 + GAME_LEVELS 6)")
eq(collectionTotal, 6, "COLLECTION category has 6 entries (UNLOCKS series)")
eq(dungeonTotal, 93, "DUNGEON_DWELLERS category has all 93 ported entries")
local _, grandTotal = CG.Achievements:GetCounts()
eq(grandTotal, 116, "GetCounts() with no category filter still totals 116")

-- ============================================================
-- 3 & 4. Migration preserves completions/timestamps and never re-grants
--    rewards. Load CreshCollect too now, in real cross-addon order, to
--    exercise the actual Suite service round-trip.
-- ============================================================
section("Migration imports legacy completions once, preserving timestamps, without re-granting rewards")

local COL = { version = "0.2.3" }
loadProductionFile("addons/CreshCollect/CreshCollectDatabase.lua", "CreshCollect", COL)
_G.CreshCollectDatabase.Init()
loadProductionFile("addons/CreshCollect/CreshCollect.lua", "CreshCollect", COL)
loadProductionFile("addons/CreshCollect/Achievements.lua", "CreshCollect", COL)

-- Plant legacy completions directly into CreshCollectDB, as if a player had
-- earned these under the old CreshCollect-owned catalogs before the move.
freshGamesState()
_G.CreshCollectDatabase.Init()
COL.Achievements:Ensure()
local legacyTimestamp = 123456
CreshCollectDB.achievements.unlocked["ACH_WOW_GAME_PLAYS_001"] = { at = legacyTimestamp, value = 1 }
CreshCollectDB.ddAchievements = { unlocked = { ["ACH_DD_KILLS_001"] = { at = legacyTimestamp + 1, value = 10 } } }

CG.Achievements:Ensure()
local coinsBefore = CG.BattlePass:Ensure().coins
local imported = CG.Achievements:SyncLegacyCompletions()
ok(imported >= 2, "SyncLegacyCompletions imports both planted legacy completions")
local gaSave2 = CG.Achievements:Ensure()
ok(gaSave2.unlocked["ACH_WOW_GAME_PLAYS_001"] ~= nil, "the ex-GAMES completion is now present in CreshGames' own save")
ok(gaSave2.unlocked["ACH_DD_KILLS_001"] ~= nil, "the Dungeon Dweller completion is now present in CreshGames' own save")
eq(gaSave2.unlocked["ACH_WOW_GAME_PLAYS_001"].at, legacyTimestamp, "the original completion timestamp is preserved exactly")
eq(gaSave2.unlocked["ACH_DD_KILLS_001"].at, legacyTimestamp + 1, "the original Dungeon Dweller completion timestamp is preserved exactly")
eq(CG.BattlePass:Ensure().coins, coinsBefore, "importing legacy completions pays no coins -- rewards are never re-granted during migration")

-- Re-running the sync must not disturb already-imported records (idempotent
-- per key) -- exit criterion "if legacy data becomes available later,
-- migration must safely union it once."
local secondImportSnapshot = gaSave2.unlocked["ACH_WOW_GAME_PLAYS_001"]
CG.Achievements:SyncLegacyCompletions()
eq(gaSave2.unlocked["ACH_WOW_GAME_PLAYS_001"], secondImportSnapshot, "re-running SyncLegacyCompletions leaves an already-imported record untouched")

-- A brand new legacy completion appearing later (e.g. CreshCollect was
-- absent at an earlier login) is still picked up on the next sync.
CreshCollectDB.achievements.unlocked["ACH_WOW_GAME_WINS_001"] = { at = legacyTimestamp + 2, value = 1 }
CG.Achievements:SyncLegacyCompletions()
ok(gaSave2.unlocked["ACH_WOW_GAME_WINS_001"] ~= nil, "a legacy completion that appears later is unioned in on the next sync")

-- ============================================================
-- 5. CreshCollect reports only World achievement counts.
-- ============================================================
section("CreshCollect reports only World achievement counts")
local hasGames = false
for _, category in ipairs(COL.Achievements.categoryOrder or {}) do
    if category == "GAMES" then hasGames = true end
end
ok(not hasGames, "COL.Achievements.categoryOrder has no GAMES category")
local _, colTotal = COL.Achievements:GetCounts()
-- Achievements.lua alone (this fixture doesn't load AchievementExpansion.lua/
-- ClassAchievements.lua) had 152 entries before Rework Phase 5 (Phase 0
-- baseline audit); removing the 23 GAMES entries leaves 129.
eq(colTotal, 129, "CreshCollect's own catalog lost exactly the 23 GAMES entries (152 -> 129)")
local _, worldTotal = _G.CreshCollectAPI.GetWorldAchievementCounts()
eq(worldTotal, colTotal, "CreshCollectAPI.GetWorldAchievementCounts matches GetCounts() exactly now that GAMES is gone")

-- ============================================================
-- Summary
-- ============================================================
print(("\n=== Results: %d passed, %d failed ==="):format(PASS, FAIL))
if FAIL > 0 then os.exit(1) end
