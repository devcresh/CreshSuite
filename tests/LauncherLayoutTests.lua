-- LauncherLayoutTests.lua
-- Lua 5.1 tests for the shared launcher's orientation + expansion-direction
-- geometry in shared/Launcher.lua (Phase 9 -- ownership moved out of
-- CreshChat/UI.lua; math and contract unchanged from Phase 4):
--   Launcher:GetOrientation() / Launcher:SetOrientation(v) -- persisted,
--     validated storage with an idempotent, self-correcting fallback
--   Launcher:CalculateExpansionDirection(...) -- pure geometry: given the
--     bubble's screen edges, screen size, orientation and required pixel
--     extent, decide which direction the satellite chain expands
--
-- Loads the REAL production shared/Launcher.lua with _G.CreshChatDB mocked
-- as the persistence target.
--
-- Usage: lua LauncherLayoutTests.lua [Launcher.lua]

function CreateFrame()
    return {
        SetScript = function() end,
        RegisterEvent = function() end,
        RegisterForDrag = function() end,
    }
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
-- Load the real production file fresh each run
-- ============================================================
local launcherPath = (arg and arg[1]) or "shared/Launcher.lua"

local function freshLauncher()
    _G.CreshSuiteLauncherAPI = nil
    _G.CreshChatDB = { ui = {} }
    _G.CreshGamesDB = nil
    _G.CreshCollectDB = nil
    local chunk = assert(loadfile(launcherPath))
    chunk()
    return _G.CreshSuiteLauncherAPI
end

-- Simulates a /reload: the addon's SavedVariables table survives, only the
-- in-memory singleton is torn down and rebuilt from it.
local function reloadLauncher()
    _G.CreshSuiteLauncherAPI = nil
    local chunk = assert(loadfile(launcherPath))
    chunk()
    return _G.CreshSuiteLauncherAPI
end

local Launcher = freshLauncher()
if not Launcher or not Launcher.GetOrientation or not Launcher.SetOrientation
    or not Launcher.CalculateExpansionDirection then
    print("FATAL: CreshSuiteLauncherAPI / layout functions not found after loading Launcher.lua")
    os.exit(2)
end

-- ============================================================
-- 1. Orientation storage: default, persistence, validation
-- ============================================================
section("GetOrientation: default when nothing saved")
Launcher = freshLauncher()
eq(Launcher:GetOrientation(), "HORIZONTAL", "defaults to HORIZONTAL with no saved value")

section("GetOrientation: persists a valid saved value")
Launcher = freshLauncher()
Launcher:SetOrientation("VERTICAL")
Launcher = reloadLauncher() -- reload to prove it round-trips through storage, not just in-memory state
eq(Launcher:GetOrientation(), "VERTICAL", "VERTICAL is honoured when already valid")
eq(_G.CreshChatDB.launcher.orientation, "VERTICAL", "saved value is untouched when already valid")

section("GetOrientation: case-insensitive")
Launcher = freshLauncher()
_G.CreshChatDB.launcher = { orientation = "vertical" }
eq(Launcher:GetOrientation(), "VERTICAL", "lowercase saved value is normalised")

section("GetOrientation: invalid saved values fall back to HORIZONTAL and self-correct")
for _, bad in ipairs({ "DIAGONAL", "", "123", true, 42, {} }) do
    Launcher = freshLauncher()
    _G.CreshChatDB.launcher = { orientation = bad }
    eq(Launcher:GetOrientation(), "HORIZONTAL", "invalid value (" .. tostring(bad) .. ") falls back to HORIZONTAL")
    eq(_G.CreshChatDB.launcher.orientation, "HORIZONTAL", "the bad value is corrected in place, not just masked on read")
end

section("GetOrientation: idempotent -- repeated reads/reloads never change an already-valid value")
Launcher = freshLauncher()
_G.CreshChatDB.launcher = { orientation = "VERTICAL" }
Launcher:GetOrientation()
Launcher:GetOrientation()
local thirdRead = Launcher:GetOrientation()
eq(thirdRead, "VERTICAL", "three consecutive reads all agree")
eq(_G.CreshChatDB.launcher.orientation, "VERTICAL", "no drift after repeated validation passes")

section("SetOrientation: writes a valid value and rejects invalid input")
Launcher = freshLauncher()
Launcher:SetOrientation("VERTICAL")
eq(_G.CreshChatDB.launcher.orientation, "VERTICAL", "VERTICAL accepted")
Launcher:SetOrientation("HORIZONTAL")
eq(_G.CreshChatDB.launcher.orientation, "HORIZONTAL", "HORIZONTAL accepted")
Launcher:SetOrientation("NONSENSE")
eq(_G.CreshChatDB.launcher.orientation, "HORIZONTAL", "invalid input safely falls back to HORIZONTAL instead of storing garbage")

section("SetOrientation: does not touch the launcher's saved position")
Launcher = freshLauncher()
_G.CreshChatDB.launcher = { position = { point = "BOTTOMRIGHT", relativePoint = "BOTTOMRIGHT", x = -40, y = 40 } }
local before = _G.CreshChatDB.launcher.position
Launcher:SetOrientation("VERTICAL")
eq(_G.CreshChatDB.launcher.position, before, "position table reference is unchanged by an orientation change")
eq(_G.CreshChatDB.launcher.position.x, -40, "position values are unchanged by an orientation change")

section("Legacy migration: pre-Phase-9 CreshChatDB.ui.launcherOrientation/positions.bubble are imported once")
_G.CreshSuiteLauncherAPI = nil
_G.CreshChatDB = {
    ui = { launcherOrientation = "VERTICAL" },
    positions = { bubble = { point = "TOPLEFT", relativePoint = "TOPLEFT", x = 12, y = -12 } },
}
_G.CreshGamesDB, _G.CreshCollectDB = nil, nil
local chunk = assert(loadfile(launcherPath))
chunk()
Launcher = _G.CreshSuiteLauncherAPI
eq(Launcher:GetOrientation(), "VERTICAL", "legacy CreshChatDB.ui.launcherOrientation is picked up on first use")
eq(_G.CreshChatDB.launcher.position.x, 12, "legacy CreshChatDB.positions.bubble is picked up on first use")

-- ============================================================
-- 2. CalculateExpansionDirection: pure geometry (unchanged from Phase 4)
-- ============================================================
local SCREEN_W, SCREEN_H = 1920, 1080
local EXTENT = 5 * (36 + 6) -- 5 satellites at the real button size/gap

section("HORIZONTAL: centre of screen prefers RIGHT (plenty of room both ways)")
eq(Launcher:CalculateExpansionDirection(940, 980, 520, 560, SCREEN_W, SCREEN_H, "HORIZONTAL", EXTENT),
    "RIGHT", "centre-screen bubble expands right by default")

section("HORIZONTAL: left edge -- RIGHT still fits, so RIGHT is chosen")
eq(Launcher:CalculateExpansionDirection(0, 40, 520, 560, SCREEN_W, SCREEN_H, "HORIZONTAL", EXTENT),
    "RIGHT", "bubble flush against the left edge expands right (nowhere else to go)")

section("HORIZONTAL: right edge -- RIGHT would leave the screen, reverses to LEFT")
eq(Launcher:CalculateExpansionDirection(SCREEN_W - 40, SCREEN_W, 520, 560, SCREEN_W, SCREEN_H, "HORIZONTAL", EXTENT),
    "LEFT", "bubble flush against the right edge reverses to expand left")

section("HORIZONTAL: top edge -- orientation is horizontal, so vertical position doesn't affect direction")
eq(Launcher:CalculateExpansionDirection(940, 980, 0, 40, SCREEN_W, SCREEN_H, "HORIZONTAL", EXTENT),
    "RIGHT", "top-edge bubble still expands right (plenty of horizontal room)")

section("HORIZONTAL: bottom edge -- same, vertical position is irrelevant on this axis")
eq(Launcher:CalculateExpansionDirection(940, 980, SCREEN_H - 40, SCREEN_H, SCREEN_W, SCREEN_H, "HORIZONTAL", EXTENT),
    "RIGHT", "bottom-edge bubble still expands right")

section("HORIZONTAL: every corner")
eq(Launcher:CalculateExpansionDirection(0, 40, SCREEN_H - 40, SCREEN_H, SCREEN_W, SCREEN_H, "HORIZONTAL", EXTENT),
    "RIGHT", "top-left corner expands right")
eq(Launcher:CalculateExpansionDirection(SCREEN_W - 40, SCREEN_W, SCREEN_H - 40, SCREEN_H, SCREEN_W, SCREEN_H, "HORIZONTAL", EXTENT),
    "LEFT", "top-right corner reverses to left")
eq(Launcher:CalculateExpansionDirection(0, 40, 0, 40, SCREEN_W, SCREEN_H, "HORIZONTAL", EXTENT),
    "RIGHT", "bottom-left corner expands right")
eq(Launcher:CalculateExpansionDirection(SCREEN_W - 40, SCREEN_W, 0, 40, SCREEN_W, SCREEN_H, "HORIZONTAL", EXTENT),
    "LEFT", "bottom-right corner reverses to left")

section("VERTICAL: centre of screen prefers DOWN (plenty of room both ways)")
eq(Launcher:CalculateExpansionDirection(940, 980, 560, 520, SCREEN_W, SCREEN_H, "VERTICAL", EXTENT),
    "DOWN", "centre-screen bubble expands down by default")

section("VERTICAL: top edge -- DOWN still fits")
eq(Launcher:CalculateExpansionDirection(940, 980, SCREEN_H, SCREEN_H - 40, SCREEN_W, SCREEN_H, "VERTICAL", EXTENT),
    "DOWN", "bubble flush against the top edge expands down")

section("VERTICAL: bottom edge -- DOWN would leave the screen, reverses to UP")
eq(Launcher:CalculateExpansionDirection(940, 980, 40, 0, SCREEN_W, SCREEN_H, "VERTICAL", EXTENT),
    "UP", "bubble flush against the bottom edge reverses to expand up")

section("VERTICAL: left/right edges are irrelevant to the vertical axis")
eq(Launcher:CalculateExpansionDirection(0, 40, 560, 520, SCREEN_W, SCREEN_H, "VERTICAL", EXTENT),
    "DOWN", "left-edge bubble still expands down")
eq(Launcher:CalculateExpansionDirection(SCREEN_W - 40, SCREEN_W, 560, 520, SCREEN_W, SCREEN_H, "VERTICAL", EXTENT),
    "DOWN", "right-edge bubble still expands down")

section("VERTICAL: every corner")
eq(Launcher:CalculateExpansionDirection(0, 40, SCREEN_H, SCREEN_H - 40, SCREEN_W, SCREEN_H, "VERTICAL", EXTENT),
    "DOWN", "top-left corner expands down")
eq(Launcher:CalculateExpansionDirection(SCREEN_W - 40, SCREEN_W, SCREEN_H, SCREEN_H - 40, SCREEN_W, SCREEN_H, "VERTICAL", EXTENT),
    "DOWN", "top-right corner expands down")
eq(Launcher:CalculateExpansionDirection(0, 40, 40, 0, SCREEN_W, SCREEN_H, "VERTICAL", EXTENT),
    "UP", "bottom-left corner reverses to up")
eq(Launcher:CalculateExpansionDirection(SCREEN_W - 40, SCREEN_W, 40, 0, SCREEN_W, SCREEN_H, "VERTICAL", EXTENT),
    "UP", "bottom-right corner reverses to up")

section("Neither direction fully fits -- picks whichever side has more room instead of erroring")
eq(Launcher:CalculateExpansionDirection(100, 140, 80, 120, 200, 200, "HORIZONTAL", 500),
    "LEFT", "horizontal: neither side fits, the side with more room wins")
eq(Launcher:CalculateExpansionDirection(80, 120, 100, 140, 200, 200, "VERTICAL", 500),
    "DOWN", "vertical: neither side fits, the side with more room (below, 140 > 100) wins")

section("Different UI scales: GetLeft/Right/Top/Bottom already reflect effective scale, so the same pixel math applies")
eq(Launcher:CalculateExpansionDirection(1400, 1430, 400, 430, SCREEN_W, SCREEN_H, "HORIZONTAL", 100),
    "RIGHT", "small scaled bubble with small extent still fits and expands right")
eq(Launcher:CalculateExpansionDirection(1890, 1919, 400, 430, SCREEN_W, SCREEN_H, "HORIZONTAL", 100),
    "LEFT", "small scaled bubble pinned to the right edge still reverses correctly")

section("Invalid orientation argument passed directly to the geometry function safely defaults to HORIZONTAL behaviour")
eq(Launcher:CalculateExpansionDirection(940, 980, 520, 560, SCREEN_W, SCREEN_H, "DIAGONAL", EXTENT),
    "RIGHT", "an invalid orientation string is treated as HORIZONTAL rather than erroring")
eq(Launcher:CalculateExpansionDirection(940, 980, 520, 560, SCREEN_W, SCREEN_H, nil, EXTENT),
    "RIGHT", "a nil orientation is treated as HORIZONTAL rather than erroring")

-- ============================================================
-- Summary
-- ============================================================
print(("\n=== Results: %d passed, %d failed ==="):format(PASS, FAIL))
if FAIL > 0 then os.exit(1) end
