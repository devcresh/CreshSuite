-- AchievementsAvailabilityTests.lua
-- Lua 5.1 tests for the GAMES-category addon-availability logic in
-- addons/CreshCollect/Achievements.lua: isCategoryEnabled and
-- categoryMissingAddon (exposed as _TESTONLY_ hooks), which decide whether
-- the GAMES achievement category is shown as available, "MODULE OFF", or
-- "REQUIRES CRESHGAMES" in the achievements drawer panel.
--
-- Loads the REAL production Achievements.lua (not a reimplemented copy).
-- Only enough of the WoW API is stubbed for the file's top-level chunk to
-- execute; this test never builds the drawer panel itself, only exercises
-- the pure category-availability logic.
--
-- Usage: lua AchievementsAvailabilityTests.lua [Achievements.lua]

-- ============================================================
-- Minimal WoW API stubs
-- ============================================================

function CreateFrame()
    return { SetScript = function() end, RegisterEvent = function() end }
end
function time() return 0 end
function GetTime() return 0 end
_G.GetServerTime = function() return 0 end

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

-- ============================================================
-- Load the real production file
-- ============================================================

local achievementsPath = (arg and arg[1]) or "addons/CreshCollect/Achievements.lua"

-- Some production files carry a leading UTF-8 BOM (unlike Core.lua/UI.lua,
-- which don't); WoW's client loader tolerates it but Lua 5.1's loadfile()
-- does not, so strip it before loading if present.
local function loadProductionFile(path, ...)
    local f = assert(io.open(path, "rb"))
    local src = f:read("*a")
    f:close()
    if src:sub(1, 3) == "\239\187\191" then src = src:sub(4) end
    local chunk = assert(loadstring(src, "@" .. path))
    return chunk(...)
end

local COL = { version = "0.2.3" }
loadProductionFile(achievementsPath, "CreshCollect", COL)

local Achievements = COL.Achievements
if not Achievements or not Achievements._TESTONLY_CategoryMissingAddon or not Achievements._TESTONLY_IsCategoryEnabled then
    print("FATAL: CreshCollect.Achievements / _TESTONLY_ hooks not found after loading Achievements.lua")
    os.exit(2)
end

local categoryMissingAddon = Achievements._TESTONLY_CategoryMissingAddon
local isCategoryEnabled = Achievements._TESTONLY_IsCategoryEnabled

-- ============================================================
-- 1. categoryMissingAddon
-- ============================================================
section("categoryMissingAddon")

_G.CreshSuite = nil
ok(categoryMissingAddon("GAMES") == "CreshGames", "GAMES category reports missing CreshGames when CreshSuite doesn't even exist")
ok(categoryMissingAddon("COMBAT") == nil, "COMBAT category has no addon requirement")
ok(categoryMissingAddon("EXPLORATION") == nil, "EXPLORATION category has no addon requirement")
ok(categoryMissingAddon("DUNGEONS") == nil, "DUNGEONS category has no addon requirement")
ok(categoryMissingAddon("PROFESSIONS") == nil, "PROFESSIONS category has no addon requirement")

_G.CreshSuite = {
    _loaded = {},
    IsProductLoaded = function(self, name) return self._loaded[string.upper(tostring(name or ""))] == true end,
}
ok(categoryMissingAddon("GAMES") == "CreshGames", "GAMES still reported missing when CreshSuite exists but CreshGames isn't registered")
_G.CreshSuite._loaded.CRESHGAMES = true
ok(categoryMissingAddon("GAMES") == nil, "GAMES reports no missing addon once CreshGames is registered")

-- ============================================================
-- 2. isCategoryEnabled (feature-flag path, unaffected by addon presence)
-- ============================================================
section("isCategoryEnabled (feature-flag semantics unchanged)")

-- No CC.IsFeatureEnabled available at all -> always enabled (matches
-- production's "if not (CC.IsFeatureEnabled) then return true end").
ok(isCategoryEnabled("GAMES") == true, "GAMES enabled by feature-flag check when no feature system is present")
ok(isCategoryEnabled("COMBAT") == true, "COMBAT enabled by feature-flag check when no feature system is present")

-- ============================================================
-- 3. Combined semantics a caller (RefreshDrawerPanel) relies on:
--    disabled = categoryMissingAddon(cat) ~= nil or not isCategoryEnabled(cat)
-- ============================================================
section("Combined disabled-state semantics")

_G.CreshSuite = nil
do
    local missing = categoryMissingAddon("GAMES")
    local enabled = isCategoryEnabled("GAMES")
    local disabled = missing ~= nil or not enabled
    ok(disabled == true, "GAMES category is disabled overall when CreshGames is absent")
    ok(missing == "CreshGames", "...specifically because of a missing addon, not a feature toggle")
end

_G.CreshSuite = {
    _loaded = { CRESHGAMES = true },
    IsProductLoaded = function(self, name) return self._loaded[string.upper(tostring(name or ""))] == true end,
}
do
    local missing = categoryMissingAddon("GAMES")
    local enabled = isCategoryEnabled("GAMES")
    local disabled = missing ~= nil or not enabled
    ok(disabled == false, "GAMES category is enabled once CreshGames is loaded (feature flags default enabled)")
end

-- ============================================================
-- Summary
-- ============================================================
print(("\n=== Results: %d passed, %d failed ==="):format(PASS, FAIL))
if FAIL > 0 then os.exit(1) end
