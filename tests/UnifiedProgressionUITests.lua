-- UnifiedProgressionUITests.lua
-- Rework Phase 9 regression coverage for CreshGamesAPI's Unified
-- Progression UI additions/fixes (addons/CreshGames/CreshGames.lua):
--   1. IsGameAchievementUnlocked delegates to CG.Achievements directly
--      (fixes a Phase 5 regression: it used to route through
--      CreshCollectAPI.IsAchievementUnlocked, which only ever checks
--      CreshCollect's own World-achievement catalog and would always
--      return false for a CreshGames achievement key).
--   2. GetGameAchievementCounts wraps CG.Achievements:GetCounts.
--   3. GetGameMasteryProgress dispatches to the right Mastery track
--      (Tetris vs Dungeon Dweller) with a safe fallback for anything else.
--   4. OpenGameMastery routes to a real per-track destination instead of
--      always falling back to the generic hub (a Phase 1-era dead end).
--
-- Loads the REAL CreshGames.lua (not a reimplemented copy) with CG.*
-- modules as lightweight recording mocks, since the modules themselves
-- (SoloGames' WoW frame construction, Achievements' catalog) are already
-- covered by their own dedicated test files -- this file tests only the
-- API layer's dispatch logic, which is what changed.
--
-- Usage: lua UnifiedProgressionUITests.lua

function CreateFrame() return { SetScript = function() end, RegisterEvent = function() end } end
function time() return 0 end
function GetTime() return 0 end
_G.C_Timer = { After = function() end }

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
local API = _G.CreshGamesAPI

-- ============================================================
-- 1. IsGameAchievementUnlocked delegates to CG.Achievements, not
--    CreshCollectAPI (the Phase 5 regression).
-- ============================================================
section("IsGameAchievementUnlocked delegates to CG.Achievements directly")

_G.CreshCollectAPI = {
    IsAchievementUnlocked = function() return false end, -- would always be false post Phase-5-move
}
CG.Achievements = { IsUnlocked = function(_, key) return key == "ACH_WOW_GAME_PLAYS_001" end }
ok(API.IsGameAchievementUnlocked("ACH_WOW_GAME_PLAYS_001") == true,
    "a real CreshGames achievement key resolves true via CG.Achievements, ignoring CreshCollectAPI's stale false")
ok(API.IsGameAchievementUnlocked("NOT_A_KEY") == false, "an unknown key resolves false")

CG.Achievements = nil
ok(API.IsGameAchievementUnlocked("ANY_KEY") == false, "resolves false (not an error) when CG.Achievements isn't loaded")

-- ============================================================
-- 2. GetGameAchievementCounts wraps CG.Achievements:GetCounts.
-- ============================================================
section("GetGameAchievementCounts")

CG.Achievements = { GetCounts = function(_, category) if category == "DUNGEON_DWELLERS" then return 40, 93 end return 23, 116 end }
local unlocked, total = API.GetGameAchievementCounts()
eq(unlocked, 23, "GetGameAchievementCounts() with no category returns the overall unlocked count")
eq(total, 116, "GetGameAchievementCounts() with no category returns the overall total")
local dUnlocked, dTotal = API.GetGameAchievementCounts("DUNGEON_DWELLERS")
eq(dUnlocked, 40, "GetGameAchievementCounts('DUNGEON_DWELLERS') passes the category through")
eq(dTotal, 93, "GetGameAchievementCounts('DUNGEON_DWELLERS') passes the category through")

CG.Achievements = nil
local u2, t2 = API.GetGameAchievementCounts()
eq(u2, 0, "GetGameAchievementCounts() returns 0 (not an error) when CG.Achievements isn't loaded")
eq(t2, 0, "GetGameAchievementCounts() returns 0 (not an error) when CG.Achievements isn't loaded")

-- ============================================================
-- 3. GetGameMasteryProgress dispatches to the right track.
-- ============================================================
section("GetGameMasteryProgress dispatches correctly")

CG.Tetris = { GetMasteryProgress = function() return 7, 5, 50, 0.1 end }
CG.DungeonDwellersPass = { GetProgress = function() return 3, 2, 40, 0.05 end }

local tLevel = API.GetGameMasteryProgress("TETRIS")
eq(tLevel, 7, "GetGameMasteryProgress('TETRIS') reads CG.Tetris:GetMasteryProgress()")
local dLevel = API.GetGameMasteryProgress("DUNGEON")
eq(dLevel, 3, "GetGameMasteryProgress('DUNGEON') reads CG.DungeonDwellersPass:GetProgress()")
local dLevel2 = API.GetGameMasteryProgress("delver")
eq(dLevel2, 3, "GetGameMasteryProgress accepts 'DELVER' as an alias for the same track, case-insensitively")
local unknownLevel = API.GetGameMasteryProgress("PONG")
eq(unknownLevel, 1, "an unrecognised game falls back to (1, 0, 1, 0) instead of erroring")

CG.Tetris, CG.DungeonDwellersPass = nil, nil
local fallbackLevel = API.GetGameMasteryProgress("TETRIS")
eq(fallbackLevel, 1, "falls back safely when the underlying module isn't loaded at all")

-- ============================================================
-- 4. OpenGameMastery routes to a real per-track destination.
-- ============================================================
section("OpenGameMastery is no longer a blanket dead end")

local calls = {}
CG.SoloGames = {
    OpenTetrisMastery  = function() calls[#calls + 1] = "TETRIS_MASTERY"; return true end,
    OpenDungeonDwellers = function(_, mode) calls[#calls + 1] = "DUNGEON:" .. tostring(mode); return true end,
    OpenHub            = function() calls[#calls + 1] = "HUB"; return true end,
}

API.OpenGameMastery("TETRIS")
eq(calls[#calls], "TETRIS_MASTERY", "OpenGameMastery('TETRIS') opens Tetris' own Mastery tab, not the generic hub")

API.OpenGameMastery("DUNGEON")
eq(calls[#calls], "DUNGEON:PASS", "OpenGameMastery('DUNGEON') opens Dungeon Dweller's own Mastery panel with mode=PASS")

API.OpenGameMastery("delver")
eq(calls[#calls], "DUNGEON:PASS", "OpenGameMastery accepts 'DELVER' as an alias for the Dungeon Dweller track")

API.OpenGameMastery("PONG")
eq(calls[#calls], "HUB", "an unrecognised game still falls back to the generic hub (never a dead end)")

API.OpenGameMastery()
eq(calls[#calls], "HUB", "no game argument at all falls back to the generic hub")

-- ============================================================
-- Summary
-- ============================================================
print(("\n=== Results: %d passed, %d failed ==="):format(PASS, FAIL))
if FAIL > 0 then os.exit(1) end
