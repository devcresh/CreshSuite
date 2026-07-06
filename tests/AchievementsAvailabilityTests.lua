-- AchievementsAvailabilityTests.lua
-- Lua 5.1 tests for addons/CreshCollect/Achievements.lua's per-achievement
-- addon-availability logic (_TESTONLY_AchievementMissingAddon) and its
-- feature-flag category logic (_TESTONLY_IsCategoryEnabled).
--
-- Rework Phase 5 removed the GAMES achievement category (and the
-- category-level categoryRequiredAddon/categoryMissingAddon mechanism that
-- existed only to gate it on CreshGames) -- this file used to test exactly
-- that. What remains and is still genuinely live: the generic per-item
-- `achievement.requiredAddon` override (used by a handful of COMMUNITY
-- achievements that require CreshChat), and the feature-flag category gate.
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
if not Achievements or not Achievements._TESTONLY_IsCategoryEnabled or not Achievements._TESTONLY_AchievementMissingAddon then
    print("FATAL: CreshCollect.Achievements / _TESTONLY_ hooks not found after loading Achievements.lua")
    os.exit(2)
end

local isCategoryEnabled = Achievements._TESTONLY_IsCategoryEnabled
local achievementMissingAddon = Achievements._TESTONLY_AchievementMissingAddon

-- ============================================================
-- 1. GAMES no longer exists as a category at all (Rework Phase 5)
-- ============================================================
section("GAMES category removed from CreshCollect entirely")

local hasGames = false
for _, category in ipairs(Achievements.categoryOrder or {}) do
    if category == "GAMES" then hasGames = true end
end
ok(not hasGames, "categoryOrder no longer contains GAMES")
ok(Achievements.categoryNames.GAMES == nil, "categoryNames no longer has a GAMES entry")
ok(Achievements.categoryRequiredFeatures.GAMES == nil, "categoryRequiredFeatures no longer has a GAMES entry")

-- ============================================================
-- 2. Per-achievement addon requirements (still live -- e.g. CreshChat-only
--    COMMUNITY achievements)
-- ============================================================
section("per-achievement addon requirements")

_G.CreshSuite = {
    _loaded = {},
    IsProductLoaded = function(self, name) return self._loaded[string.upper(tostring(name or ""))] == true end,
}
ok(achievementMissingAddon({ category = "COMMUNITY", requiredAddon = "CreshChat" }) == "CreshChat",
    "an individual CreshChat achievement reports CreshChat missing")
_G.CreshSuite._loaded.CRESHCHAT = true
ok(achievementMissingAddon({ category = "COMMUNITY", requiredAddon = "CreshChat" }) == nil,
    "the individual achievement becomes available when CreshChat is registered")
ok(achievementMissingAddon({ category = "EXPLORATION" }) == nil,
    "an achievement with no requiredAddon field never reports anything missing")
ok(achievementMissingAddon(nil) == nil, "a nil achievement reports nothing missing (defensive)")

-- ============================================================
-- 3. isCategoryEnabled (feature-flag path; unrelated to addon presence)
-- ============================================================
section("isCategoryEnabled (feature-flag semantics)")

-- No CC.IsFeatureEnabled available at all -> always enabled (matches
-- production's "if not (CC.IsFeatureEnabled) then return true end").
ok(isCategoryEnabled("COMBAT") == true, "COMBAT enabled by feature-flag check when no feature system is present")
ok(isCategoryEnabled("EXPLORATION") == true, "EXPLORATION enabled by feature-flag check when no feature system is present")

-- ============================================================
-- Summary
-- ============================================================
print(("\n=== Results: %d passed, %d failed ==="):format(PASS, FAIL))
if FAIL > 0 then os.exit(1) end
