-- CollectionUnlockTests.lua
-- Lua 5.1 tests for the CRESHGAMES_COLLECTION_UNLOCK Suite event (Phase 9):
--   /run CreshSuite:Publish("CRESHGAMES_COLLECTION_UNLOCK", {key="ZONE_ELWYNN",type="TETRIS_BACKGROUND"})
--
-- Covers the subscriber registered in addons/CreshCollect/CreshCollect.lua:
--   - valid payloads unlock the matching collection bucket entry and persist
--     in CreshCollectDB (the authoritative SavedVariable)
--   - repeated publishes are idempotent (no duplicate notifications, value
--     never regresses)
--   - malformed payloads (nil, non-table, missing fields, wrong field types,
--     unknown type, empty/non-string key) are rejected without touching
--     CreshCollectDB.collections at all
--   - a simulated /reload (re-running the DB init/merge-defaults pass)
--     preserves the unlock
--   - an open Progress Overview window is refreshed exactly once per valid
--     publish
--
-- Loads the REAL production Suite.lua, CreshCollectDatabase.lua and
-- CreshCollect.lua (not reimplemented copies), consistent with every other
-- suite in tests/.
--
-- Usage: lua CollectionUnlockTests.lua [Suite.lua] [CreshCollectDatabase.lua] [CreshCollect.lua]

function CreateFrame()
    return { SetScript = function() end, RegisterEvent = function() end, RegisterForDrag = function() end, IsShown = function() return false end }
end
function time() return 0 end
function GetTime() return 0 end
_G.C_Timer = { After = function() end }
_G.hooksecurefunc = function() end
_G.UIParent = { GetWidth = function() return 1920 end, GetHeight = function() return 1080 end }
_G.GetAddOnMetadata = function() return nil end

local PASS, FAIL = 0, 0
local _section = ""

local function section(name)
    _section = name
    print(("\n[%s]"):format(name))
end

local function pass(msg)
    PASS = PASS + 1
    print(("  PASS  %s"):format(msg))
end

local function fail(msg)
    FAIL = FAIL + 1
    print(("  FAIL  %s  [in: %s]"):format(msg, _section))
end

local function ok(cond, msg) if cond then pass(msg) else fail(msg) end end
local function eq(a, b, msg)
    if a == b then pass(msg)
    else fail(("%s  (expected %q, got %q)"):format(msg, tostring(b), tostring(a))) end
end

-- ============================================================
-- Load the real production files, in real TOC order
-- ============================================================

local suitePath   = (arg and arg[1]) or "shared/Suite.lua"
local dbPath      = (arg and arg[2]) or "addons/CreshCollect/CreshCollectDatabase.lua"
local collectPath = (arg and arg[3]) or "addons/CreshCollect/CreshCollect.lua"

local function loadProductionFile(path, ...)
    local chunk = assert(loadfile(path))
    return chunk(...)
end

local COL = { version = "0.2.3" }
loadProductionFile(suitePath, "CreshCollect", COL)
loadProductionFile(dbPath, "CreshCollect", COL)

if not _G.CreshCollectDatabase or not _G.CreshCollectDatabase.Init then
    print("FATAL: CreshCollectDatabase.Init not found")
    os.exit(2)
end

-- ADDON_LOADED("CreshCollect") equivalent: real load order loads
-- SavedVariables first, then runs this once all of CreshCollect's files
-- have executed.
_G.CreshCollectDatabase.Init()

loadProductionFile(collectPath, "CreshCollect", COL)

if not _G.CreshSuite or not _G.CreshCollectAPI then
    print("FATAL: CreshSuite / CreshCollectAPI not found after loading production files")
    os.exit(2)
end

local Suite = _G.CreshSuite

local function publish(payload)
    local ok_, err = pcall(function() Suite:Publish("CRESHGAMES_COLLECTION_UNLOCK", payload) end)
    return ok_, err
end

local function freshDB()
    _G.CreshCollectDB = nil
    _G.CreshCollectDatabase.Init()
end

-- ============================================================
-- 1. Valid payload: the exact command from the bug report
-- ============================================================
section("Valid payload: /run CreshSuite:Publish(\"CRESHGAMES_COLLECTION_UNLOCK\", {key=\"ZONE_ELWYNN\",type=\"TETRIS_BACKGROUND\"})")
freshDB()
local ok1, err1 = publish({ key = "ZONE_ELWYNN", type = "TETRIS_BACKGROUND" })
ok(ok1 == true, "Publish does not error (err: " .. tostring(err1) .. ")")
eq(CreshCollectDB.collections.backgrounds.ZONE_ELWYNN, true, "ZONE_ELWYNN recorded as unlocked in CreshCollectDB")
ok(_G.CreshCollectAPI.IsCollectionUnlocked("backgrounds", "ZONE_ELWYNN") == true, "public API reports the unlock too")

-- ============================================================
-- 2. Duplicate publish: idempotency
-- ============================================================
section("Duplicate payload: republishing the same event is idempotent")
freshDB()
local pushCount = 0
_G.CreshChat = { Notifications = { Push = function() pushCount = pushCount + 1 end } }
publish({ key = "ZONE_ELWYNN", type = "TETRIS_BACKGROUND" })
eq(pushCount, 1, "first publish pushes exactly one notification (new unlock)")
publish({ key = "ZONE_ELWYNN", type = "TETRIS_BACKGROUND" })
eq(pushCount, 1, "second (duplicate) publish does NOT push a second notification")
publish({ key = "ZONE_ELWYNN", type = "TETRIS_BACKGROUND" })
eq(pushCount, 1, "third publish still idempotent")
eq(CreshCollectDB.collections.backgrounds.ZONE_ELWYNN, true, "value is still exactly true, not corrupted by repeats")
_G.CreshChat = nil

-- ============================================================
-- 3. Malformed payloads: must not error and must not touch collections
-- ============================================================
section("Malformed payloads: rejected without error and without state change")

local function bucketsAreEmpty(label)
    local c = CreshCollectDB.collections
    for _, bucket in ipairs({ "themes", "backgrounds", "cardDecks", "dungeonArmour", "cosmetics" }) do
        for k in pairs(c[bucket]) do
            fail(("%s left a stray entry in collections.%s = %q"):format(label, bucket, tostring(k)))
            return
        end
    end
    pass(label .. ": collections untouched")
end

freshDB()
local malformed = {
    { "nil payload",              nil },
    { "string payload",           "not a table" },
    { "number payload",           42 },
    { "empty table payload",      {} },
    { "missing key",              { type = "TETRIS_BACKGROUND" } },
    { "missing type",             { key = "ZONE_ELWYNN" } },
    { "unknown type",             { key = "ZONE_ELWYNN", type = "BOGUS_TYPE" } },
    { "numeric key",              { key = 12345, type = "TETRIS_BACKGROUND" } },
    { "boolean key",              { key = true, type = "TETRIS_BACKGROUND" } },
    { "table key",                { key = {}, type = "TETRIS_BACKGROUND" } },
    { "empty string key",         { key = "", type = "TETRIS_BACKGROUND" } },
    { "numeric type",             { key = "ZONE_ELWYNN", type = 7 } },
    { "boolean type",             { key = "ZONE_ELWYNN", type = true } },
}
for _, case in ipairs(malformed) do
    local label, payload = case[1], case[2]
    local okCall, errCall = publish(payload)
    ok(okCall == true, label .. ": Publish does not raise an error (err: " .. tostring(errCall) .. ")")
end
bucketsAreEmpty("after all malformed payloads above")

-- ============================================================
-- 4. Unknown keys with a KNOWN type: still recorded (an unrecognized asset
--    name is not itself invalid input -- only structurally wrong payloads
--    are rejected), but only as a clean, single, correctly-typed entry.
-- ============================================================
section("Unknown-but-well-formed key with a known type: stored as one clean string entry, nothing else touched")
freshDB()
publish({ key = "SOME_FUTURE_ZONE_NOT_YET_CATALOGUED", type = "TETRIS_BACKGROUND" })
eq(CreshCollectDB.collections.backgrounds.SOME_FUTURE_ZONE_NOT_YET_CATALOGUED, true, "well-formed key is recorded even if not yet a known catalog entry")
local count = 0
for _ in pairs(CreshCollectDB.collections.backgrounds) do count = count + 1 end
eq(count, 1, "exactly one entry created, no stray numeric/boolean/table keys alongside it")

-- ============================================================
-- 5. All four published unlock types route to the correct bucket
-- ============================================================
section("All four canonical unlock types route to their correct bucket")
freshDB()
publish({ key = "DARK_MAGIC",  type = "TETRIS_THEME" })
publish({ key = "ZONE_ELWYNN", type = "TETRIS_BACKGROUND" })
publish({ key = "TEST_DECK",   type = "CARD_DECK" })
publish({ key = "IRON_PLATE",  type = "DUNGEON_PASS" })
eq(CreshCollectDB.collections.themes.DARK_MAGIC, true, "TETRIS_THEME -> collections.themes")
eq(CreshCollectDB.collections.backgrounds.ZONE_ELWYNN, true, "TETRIS_BACKGROUND -> collections.backgrounds")
eq(CreshCollectDB.collections.cardDecks.TEST_DECK, true, "CARD_DECK -> collections.cardDecks")
eq(CreshCollectDB.collections.dungeonArmour.IRON_PLATE, true, "DUNGEON_PASS -> collections.dungeonArmour")

-- ============================================================
-- 6. Persistence after /reload (re-running DB init over the existing table,
--    exactly what happens on a real reload: SavedVariables are loaded back
--    in, then InitCollectDB()/mergeDefaults runs over them again)
-- ============================================================
section("Persists after /reload")
freshDB()
publish({ key = "ZONE_ELWYNN", type = "TETRIS_BACKGROUND" })
ok(CreshCollectDB.collections.backgrounds.ZONE_ELWYNN == true, "sanity: unlock present before reload")
_G.CreshCollectDatabase.Init()  -- simulate /reload re-running Init() over the same saved table
eq(CreshCollectDB.collections.backgrounds.ZONE_ELWYNN, true, "unlock still present after simulated /reload")
_G.CreshCollectDatabase.Init()  -- a second reload for good measure
eq(CreshCollectDB.collections.backgrounds.ZONE_ELWYNN, true, "unlock still present after a second simulated /reload")

-- ============================================================
-- 7. CreshCollect remains safe without CreshGames: publishing this event
--    with no game state / no CreshGames installed still works (nothing in
--    the subscriber depends on CG.* or CreshGamesDB).
-- ============================================================
section("CreshCollect is safe without CreshGames (this test harness never loads CreshGames at all)")
freshDB()
ok(_G.CreshGamesDB == nil, "sanity: CreshGamesDB was never loaded in this test")
local okNoGames = publish({ key = "ZONE_ELWYNN", type = "TETRIS_BACKGROUND" })
ok(okNoGames == true, "unlock still applies cleanly with CreshGames entirely absent")
eq(CreshCollectDB.collections.backgrounds.ZONE_ELWYNN, true, "unlock recorded with CreshGames absent")

-- ============================================================
-- 8. CreshGames remains safe without CreshCollect: publishing to a topic
--    with zero subscribers must not error (Suite-level guarantee this event
--    depends on -- see also SuiteBridgeTests.lua).
-- ============================================================
section("CreshGames is safe without CreshCollect (publishing with no subscriber registered)")
do
    local bareSuite = {}
    -- Re-load a second, independent Suite instance is not possible (global
    -- singleton), so instead verify the documented guarantee directly against
    -- a topic no one has subscribed to on the real Suite.
    local okBare, errBare = pcall(function() Suite:Publish("CRESHGAMES_COLLECTION_UNLOCK_NEVER_SUBSCRIBED", { key = "X", type = "TETRIS_THEME" }) end)
    ok(okBare == true, "Publish on a topic with no subscribers does not error (err: " .. tostring(errBare) .. ")")
end

-- ============================================================
-- 9. Window refresh: an open Progress Overview refreshes on a successful
--    unlock, and is not touched by rejected/malformed payloads.
-- ============================================================
section("Open Progress Overview window refreshes after a successful unlock")
freshDB()
local refreshCount = 0
COL.ProgressOverview = { RefreshWindow = function() refreshCount = refreshCount + 1 end }
publish({ key = "ZONE_ELWYNN", type = "TETRIS_BACKGROUND" })
eq(refreshCount, 1, "RefreshWindow called exactly once after a valid unlock")
publish({ key = "ZONE_ELWYNN", type = "TETRIS_BACKGROUND" })
eq(refreshCount, 2, "RefreshWindow called again on a duplicate publish (idempotent re-render, not an error)")
publish({ key = "BOGUS", type = "NOT_A_TYPE" })
eq(refreshCount, 2, "RefreshWindow NOT called for a rejected/malformed payload")
publish(nil)
eq(refreshCount, 2, "RefreshWindow NOT called for a nil payload")
COL.ProgressOverview = nil

-- ============================================================
-- Summary
-- ============================================================
print(("\n=== Results: %d passed, %d failed ==="):format(PASS, FAIL))
if FAIL > 0 then os.exit(1) end
