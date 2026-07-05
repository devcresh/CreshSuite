-- GameDrawerAvailabilityTests.lua
-- Lua 5.1 tests for the game-drawer addon-availability logic in
-- addons/CreshChat/UI.lua: UI:IsCreshGamesLoaded, UI:IsCreshCollectLoaded,
-- and the pure UI._TESTONLY_ResolveGameDrawerMode gating function that
-- UI:OpenGameDrawer delegates to.
--
-- Loads the REAL production UI.lua (not a reimplemented copy) so a future
-- regression in the actual gating logic shows up here. Only enough of the
-- WoW widget API is stubbed to let the file's top-level chunk execute
-- (defines functions/tables only, does not build any frames) -- this test
-- never calls UI:BuildGameDrawer/UI:Initialize, so it does not need the
-- full widget method surface those functions touch.
--
-- Usage: lua GameDrawerAvailabilityTests.lua [UI.lua]

-- ============================================================
-- Minimal WoW API stubs (just enough for UI.lua's top-level chunk to
-- execute without error; none of these are exercised by the assertions
-- below since we never call a frame-building method).
-- ============================================================

function CreateFrame()
    return { SetScript = function() end, RegisterEvent = function() end, RegisterForDrag = function() end }
end
function time() return 0 end
function GetTime() return 0 end
_G.C_Timer = { After = function() end }
_G.hooksecurefunc = function() end
_G.UIParent = { GetWidth = function() return 1920 end, GetHeight = function() return 1080 end }
_G.GetAddOnMetadata = function() return nil end

-- ============================================================
-- Test runner
-- ============================================================

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
-- Load the real production file
-- ============================================================

local uiPath = (arg and arg[1]) or "addons/CreshChat/UI.lua"

-- WoW invokes every file in a TOC with (addonName, addonTable). dofile()
-- supplies no varargs, which would make UI.lua's `local _, CC = ...` see a
-- nil CC and bail out immediately (UI.lua:1-4) -- so load + call the chunk
-- explicitly with the vararg pair, exactly like the real loader does.
local function loadProductionFile(path, ...)
    local chunk = assert(loadfile(path))
    return chunk(...)
end

local CC = { version = "0.2.3" }
loadProductionFile(uiPath, "CreshChat", CC)

local UI = CC.UI
if not UI or not UI._TESTONLY_ResolveGameDrawerMode or not UI.IsCreshGamesLoaded or not UI.IsCreshCollectLoaded then
    print("FATAL: CreshChat.UI / UI._TESTONLY_ResolveGameDrawerMode / UI.IsCreshGamesLoaded / UI.IsCreshCollectLoaded not found after loading UI.lua")
    os.exit(2)
end

-- ============================================================
-- 1. UI:IsCreshGamesLoaded / UI:IsCreshCollectLoaded
-- ============================================================
section("IsCreshGamesLoaded / IsCreshCollectLoaded")

_G.CreshSuite = nil
ok(UI:IsCreshGamesLoaded() == false, "false when CreshSuite itself does not exist")
ok(UI:IsCreshCollectLoaded() == false, "false when CreshSuite itself does not exist (Collect)")

_G.CreshSuite = {
    _loaded = {},
    IsProductLoaded = function(self, name) return self._loaded[string.upper(tostring(name or ""))] == true end,
}
ok(UI:IsCreshGamesLoaded() == false, "false when CreshSuite exists but CreshGames is not registered")
_G.CreshSuite._loaded.CRESHGAMES = true
ok(UI:IsCreshGamesLoaded() == true, "true once CreshGames is registered")
ok(UI:IsCreshCollectLoaded() == false, "CreshCollect independently still false")
_G.CreshSuite._loaded.CRESHCOLLECT = true
ok(UI:IsCreshCollectLoaded() == true, "true once CreshCollect is registered")

-- ============================================================
-- 2. Pure gating logic — UI._TESTONLY_ResolveGameDrawerMode
--    (mode, gamesLoaded, collectLoaded) -> resolvedMode, allowed
-- ============================================================
local Resolve = UI._TESTONLY_ResolveGameDrawerMode

section("Mode normalization")
eq((Resolve(nil, true, true)),        "SOLO",         "nil mode normalizes to SOLO")
eq((Resolve("bogus", true, true)),    "SOLO",         "unrecognized mode normalizes to SOLO")
eq((Resolve("solo", true, true)),     "SOLO",         "lowercase 'solo' normalizes/uppercases to SOLO")
eq((Resolve("multiplayer", true, true)), "MULTIPLAYER", "lowercase 'multiplayer' uppercases correctly")

section("All three addons present (CreshChat + CreshGames + CreshCollect)")
for _, mode in ipairs({ "SOLO", "MULTIPLAYER", "BATTLEPASS", "ACHIEVEMENTS", "THEMES" }) do
    local resolved, allowed = Resolve(mode, true, true)
    ok(allowed == true, mode .. " allowed when both CreshGames and CreshCollect are loaded")
end

section("CreshCollect alone (no CreshGames) -- the reported bug")
do
    local resolved, allowed = Resolve("ACHIEVEMENTS", false, true)
    ok(allowed == true, "ACHIEVEMENTS allowed with only CreshCollect loaded (was wrongly blocked before this fix)")
end
do
    local resolved, allowed = Resolve("BATTLEPASS", false, true)
    ok(allowed == true, "BATTLEPASS allowed with only CreshCollect loaded")
end
do
    local resolved, allowed = Resolve("THEMES", false, true)
    ok(allowed == true, "THEMES allowed with only CreshCollect loaded")
end
do
    local resolved, allowed = Resolve("SOLO", false, true)
    ok(allowed == false, "SOLO still refused with only CreshCollect loaded (needs CreshGames)")
end
do
    local resolved, allowed = Resolve("MULTIPLAYER", false, true)
    ok(allowed == false, "MULTIPLAYER still refused with only CreshCollect loaded (needs CreshGames)")
end

section("CreshGames alone (no CreshCollect)")
do
    local resolved, allowed = Resolve("SOLO", true, false)
    ok(allowed == true, "SOLO allowed with only CreshGames loaded")
end
do
    local resolved, allowed = Resolve("MULTIPLAYER", true, false)
    ok(allowed == true, "MULTIPLAYER allowed with only CreshGames loaded")
end
do
    local resolved, allowed = Resolve("BATTLEPASS", true, false)
    ok(allowed == false, "BATTLEPASS refused with only CreshGames loaded (needs CreshCollect)")
end
do
    local resolved, allowed = Resolve("ACHIEVEMENTS", true, false)
    ok(allowed == false, "ACHIEVEMENTS refused with only CreshGames loaded (needs CreshCollect)")
end
do
    local resolved, allowed = Resolve("THEMES", true, false)
    ok(allowed == false, "THEMES refused with only CreshGames loaded (needs CreshCollect)")
end

section("Neither CreshGames nor CreshCollect loaded (CreshChat alone)")
for _, mode in ipairs({ "SOLO", "MULTIPLAYER", "BATTLEPASS", "ACHIEVEMENTS", "THEMES" }) do
    local resolved, allowed = Resolve(mode, false, false)
    ok(allowed == false, mode .. " refused when neither companion addon is loaded")
end

-- ============================================================
-- Summary
-- ============================================================
print(("\n=== Results: %d passed, %d failed ==="):format(PASS, FAIL))
if FAIL > 0 then os.exit(1) end
