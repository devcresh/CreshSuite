-- GameLevelMigrationTests.lua
-- Rework Phase 8 regression coverage for GameProgression.lua's legacy
-- per-game-level import (CreshCollectDB.gameProgression.games ->
-- CreshGamesDB.gameLevels):
--   1. An opportunistic Ensure() call before CreshCollect's
--      GetLegacyGameLevels service is registered does NOT permanently give
--      up -- gameLevels works immediately (empty), but migratedLegacyLevels
--      stays unset so a later call can still succeed.
--   2. Once the service becomes available, import succeeds and unions with
--      (never overwrites) any real gameplay already recorded in the gap.
--   3. PLAYER_LOGIN's final attempt permanently records "nothing to
--      import" only when the service is genuinely unavailable, and never
--      touches already-imported or already-played data.
--   4. Repeated Ensure()/PLAYER_LOGIN calls after migration completes are
--      idempotent (no duplicate work, no data change).
--
-- Loads the REAL production files, in real cross-addon load order.
-- Usage: lua GameLevelMigrationTests.lua

-- Capturing CreateFrame stub: real tests below fire PLAYER_LOGIN through it.
local _frames = {}
function CreateFrame()
    local frame = {
        events = {},
        RegisterEvent = function(self, event) self.events[event] = true end,
        SetScript = function(self, script, fn) if script == "OnEvent" then self.onEvent = fn end end,
    }
    _frames[#_frames + 1] = frame
    return frame
end
local function fireEvent(eventName, ...)
    for _, frame in ipairs(_frames) do
        if frame.events[eventName] and frame.onEvent then frame.onEvent(frame, eventName, ...) end
    end
end

function time() return 0 end
function GetTime() return 0 end
_G.GetServerTime = function() return 0 end
_G.C_Timer = { After = function() end }
_G.hooksecurefunc = function() end

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

loadProductionFile("shared/Suite.lua", "CreshGames", {})
local CG = { version = "0.2.3" }
loadProductionFile("addons/CreshGames/CreshGames.lua", "CreshGames", CG)
loadProductionFile("addons/CreshGames/GameProgression.lua", "CreshGames", CG)

-- ============================================================
-- 1. Opportunistic Ensure() before the legacy service exists: works
--    immediately, but does not permanently give up.
-- ============================================================
section("Ensure() before CreshCollect's service is registered")
_G.CreshGamesDB = {}
_G.CreshCollectDB = nil
_G.CreshSuite = nil -- simulate CreshCollect (and its Suite service) not loaded yet

local games = CG.GameProgression:Ensure()
ok(type(games) == "table", "Ensure() returns a usable table immediately, even with no Suite at all")
ok(_G.CreshGamesDB.migratedLegacyLevels ~= true, "an unsuccessful opportunistic attempt does NOT permanently mark migration done")

-- ============================================================
-- 2. The service becomes available later (e.g. CreshCollect finishes
--    loading): the next Ensure() call succeeds and unions real gameplay
--    recorded in the gap.
-- ============================================================
section("A later Ensure() call succeeds once the legacy service exists")

-- Real gameplay happened between step 1 and now: a Frogger record already
-- exists in CreshGamesDB.gameLevels, created by ordinary play (not import).
games.FROGGER = { level = 3, xp = 40, plays = 5 }

loadProductionFile("shared/Suite.lua", "CreshCollect", {})
_G.CreshCollectDB = {
    gameProgression = {
        games = {
            FROGGER = { level = 1, xp = 999 }, -- would be WRONG to let this clobber real level 3 play
            CHESS   = { level = 7, xp = 12, plays = 20 },
        },
    },
}
_G.CreshSuite:RegisterService("GetLegacyGameLevels", function()
    return _G.CreshCollectDB.gameProgression.games
end)

games = CG.GameProgression:Ensure()
eq(_G.CreshGamesDB.migratedLegacyLevels, true, "migration is now marked done once a real snapshot was imported")
eq(games.FROGGER.level, 3, "real gameplay recorded before the import is NEVER overwritten by the legacy snapshot")
ok(games.CHESS ~= nil and games.CHESS.level == 7, "a game with no prior real gameplay is imported from the legacy snapshot")

-- ============================================================
-- 3. Idempotency: further Ensure() calls and a PLAYER_LOGIN firing after
--    migration is done change nothing.
-- ============================================================
section("Idempotency after migration completes")
local frogBefore, chessBefore = games.FROGGER.level, games.CHESS.level
fireEvent("PLAYER_LOGIN")
games = CG.GameProgression:Ensure()
eq(games.FROGGER.level, frogBefore, "FROGGER is unchanged by a PLAYER_LOGIN fired after migration already completed")
eq(games.CHESS.level, chessBefore, "CHESS is unchanged by a PLAYER_LOGIN fired after migration already completed")

-- ============================================================
-- 4. Final attempt with no legacy source at all (CreshCollect genuinely
--    absent): PLAYER_LOGIN permanently records "nothing to import" without
--    touching any existing data, and this is safe to fire repeatedly.
-- ============================================================
section("Final PLAYER_LOGIN attempt with no CreshCollect installed")
_G.CreshGamesDB = { gameLevels = { PONG = { level = 2 } } }
_G.CreshSuite = nil

local midGames = CG.GameProgression:Ensure()
ok(_G.CreshGamesDB.migratedLegacyLevels ~= true, "still not permanently marked before PLAYER_LOGIN fires")
fireEvent("PLAYER_LOGIN")
eq(_G.CreshGamesDB.migratedLegacyLevels, true, "PLAYER_LOGIN's final attempt permanently marks migration done with no source available")
eq(midGames.PONG.level, 2, "existing real gameplay is untouched by the final no-source attempt")
fireEvent("PLAYER_LOGIN")
eq(midGames.PONG.level, 2, "firing PLAYER_LOGIN again after the final attempt is a harmless no-op")

-- ============================================================
-- Summary
-- ============================================================
print(("\n=== Results: %d passed, %d failed ==="):format(PASS, FAIL))
if FAIL > 0 then os.exit(1) end
