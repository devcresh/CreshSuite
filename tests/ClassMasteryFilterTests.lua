-- ClassMasteryFilterTests.lua
-- Lua 5.1 tests for Phase 2's Class Mastery filtering: player-class
-- resolution, the shared Achievements:MatchesFilter predicate combining
-- category/class/status/search/enabledOnly, and standalone-window/drawer
-- parity for the same filter state.
--
-- Loads the REAL production files (Achievements.lua + ClassAchievements.lua,
-- not reimplementations), same BOM-safe loadProductionFile technique as
-- tests/AchievementsAvailabilityTests.lua, plus the generic mock-frame
-- technique from tests/ProgressionWindowTests.lua for the window/drawer
-- parity section.
--
-- Usage: lua ClassMasteryFilterTests.lua [Achievements.lua] [ClassAchievements.lua]

-- ============================================================
-- Generic mock WoW frame (same contract as ProgressionWindowTests.lua)
-- ============================================================
local function mockFrame()
    local obj = { _shown = false, _text = "", _scripts = {}, _scroll = 0 }
    local mt = {}
    mt.__index = function(t, k)
        local fn
        if k == "CreateFontString" or k == "CreateTexture" then
            fn = function() return mockFrame() end
        elseif k == "GetVerticalScroll" then
            fn = function(self) return self._scroll end
        elseif k == "GetVerticalScrollRange" or k == "GetWidth" or k == "GetHeight" then
            fn = function() return 100 end
        elseif k == "IsShown" then
            fn = function(self) return self._shown == true end
        elseif k == "Show" then
            fn = function(self) self._shown = true end
        elseif k == "Hide" then
            fn = function(self) self._shown = false end
        elseif k == "SetText" then
            fn = function(self, text) self._text = tostring(text or "") end
        elseif k == "GetText" then
            fn = function(self) return self._text end
        elseif k == "GetPoint" then
            fn = function() return "CENTER", nil, "CENTER", 0, 0 end
        elseif k == "SetScript" then
            fn = function(self, hook, handler) self._scripts[hook] = handler end
        elseif k == "GetScript" then
            fn = function(self, hook) return self._scripts[hook] end
        else
            fn = function(self, ...) return self end
        end
        rawset(t, k, fn)
        return fn
    end
    return setmetatable(obj, mt)
end

function CreateFrame(frameType, name)
    local f = mockFrame()
    if name then _G[name] = f end
    return f
end
function time() return 0 end
function GetTime() return 0 end
_G.GetServerTime = function() return 0 end
_G.C_Timer = { After = function() end }
_G.UIParent = mockFrame()
_G.GameTooltip = mockFrame()
_G.GameFontNormalSmall = {}
_G.GameFontHighlightSmall = {}
_G.STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"

-- Minimal drawer-side widget factory: createButton stores the callback
-- directly (so tests can simulate clicks without real WoW input plumbing)
-- instead of wiring a real OnClick script.
local function stubCreateButton(parent, label, width, height, callback)
    local btn = mockFrame()
    btn.label = mockFrame()
    btn.label:SetText(label)
    btn._callback = callback
    return btn
end
local function stubHelpers()
    return {
        createButton = stubCreateButton,
        createFont = function() return mockFrame() end,
        applyBackdrop = function() end,
        darken = function(c) return c end,
        setAccent = function() end,
        colors = {
            panel = {0.02,0.02,0.03,1}, panelSoft = {0.03,0.04,0.05,1}, panelRaised = {0.06,0.07,0.09,1},
            border = {0.1,0.1,0.1,1}, accent = {0.1,0.6,0.9,1}, text = {0.9,0.9,0.9,1}, muted = {0.5,0.5,0.5,1},
            green = {0.2,0.8,0.3,1}, quest = {1,0.8,0.2,1}, blue = {0.1,0.6,0.9,1},
        },
        templateName = function() return nil end,
    }
end

-- ============================================================
-- Test runner
-- ============================================================
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

-- ============================================================
-- Load the real production files
-- ============================================================
local achievementsPath      = (arg and arg[1]) or "addons/CreshCollect/Achievements.lua"
local classAchievementsPath = (arg and arg[2]) or "addons/CreshCollect/ClassAchievements.lua"

local function loadProductionFile(path, ...)
    local f = assert(io.open(path, "rb"))
    local src = f:read("*a")
    f:close()
    if src:sub(1, 3) == "\239\187\191" then src = src:sub(4) end
    local chunk = assert(loadstring(src, "@" .. path))
    return chunk(...)
end

local COL = { version = "0.2.3" }
_G.CreshCollectDB = { achievements = { unlocked = {}, stats = {}, uniqueBosses = {}, professionRanks = {}, visitedZones = {} } }
loadProductionFile(achievementsPath, "CreshCollect", COL)
loadProductionFile(classAchievementsPath, "CreshCollect", COL)

local Achievements = COL.Achievements
if not Achievements or not Achievements.MatchesFilter or not Achievements.GetPlayerClassToken or not Achievements.GetClassTokens then
    print("FATAL: CreshCollect.Achievements / MatchesFilter / GetPlayerClassToken / GetClassTokens not found")
    os.exit(2)
end
Achievements:BuildCatalog()

local EXPECTED_CLASSES = { "DRUID", "HUNTER", "MAGE", "PALADIN", "PRIEST", "ROGUE", "SHAMAN", "WARLOCK", "WARRIOR" }

-- ============================================================
-- 1. Player class resolution
-- ============================================================
section("GetPlayerClassToken")

_G.UnitClass = nil
eq(Achievements:GetPlayerClassToken(), "", "returns empty string when UnitClass is unavailable")

_G.UnitClass = function(unit) if unit == "player" then return "Druid", "DRUID" end end
eq(Achievements:GetPlayerClassToken(), "DRUID", "resolves and upper-cases the player's class token")

_G.UnitClass = function(unit) if unit == "player" then return "Warrior", "WARRIOR" end end
eq(Achievements:GetPlayerClassToken(), "WARRIOR", "re-resolves when the underlying UnitClass value changes")

-- ============================================================
-- 2. Class roster
-- ============================================================
section("GetClassTokens")

local tokens = Achievements:GetClassTokens()
eq(#tokens, #EXPECTED_CLASSES, "returns all 9 class tokens present in the catalog")
local sorted = true
for i = 2, #tokens do if tokens[i] < tokens[i - 1] then sorted = false end end
ok(sorted, "class tokens are sorted")
local tokenSet = {}
for _, t in ipairs(tokens) do tokenSet[t] = true end
for _, expected in ipairs(EXPECTED_CLASSES) do
    ok(tokenSet[expected], "class roster includes " .. expected)
end

-- ============================================================
-- 3. ResolveClassFilterOnCategoryChange
-- ============================================================
section("ResolveClassFilterOnCategoryChange")

eq(Achievements:ResolveClassFilterOnCategoryChange("ALL", "CLASSES", "WARRIOR"), "MY_CLASS",
    "entering CLASSES from another category resets to MY_CLASS")
eq(Achievements:ResolveClassFilterOnCategoryChange("CLASSES", "CLASSES", "WARRIOR"), "WARRIOR",
    "staying within CLASSES preserves the current class filter")
eq(Achievements:ResolveClassFilterOnCategoryChange("CLASSES", "ALL", "WARRIOR"), "WARRIOR",
    "leaving CLASSES preserves the current class filter (irrelevant until re-entered)")
eq(Achievements:ResolveClassFilterOnCategoryChange("ALL", "CLASSES", nil), "MY_CLASS",
    "defaults to MY_CLASS when no class filter was ever set")

-- ============================================================
-- 4. MatchesFilter combined filtering
-- ============================================================
section("MatchesFilter: category + class")

local save = Achievements:Ensure()
ok(save ~= nil, "Ensure() returns a save root")

local function countMatches(state, playerClassToken)
    local count = 0
    for _, achievement in ipairs(Achievements.catalog) do
        if Achievements:MatchesFilter(achievement, save, state, playerClassToken) then count = count + 1 end
    end
    return count
end

eq(countMatches({ category = "CLASSES", classFilter = "MY_CLASS" }, "DRUID"), 15,
    "MY_CLASS shows only the 15 achievements matching the resolved player class")
eq(countMatches({ category = "CLASSES", classFilter = "ALL_CLASSES" }, "DRUID"), 15 * 9,
    "ALL_CLASSES restores the full Class Mastery catalogue (9 classes x 15)")
eq(countMatches({ category = "CLASSES", classFilter = "WARRIOR" }, "DRUID"), 15,
    "a specific class token isolates that class regardless of the player's own class")

local mageCount = 0
for _, achievement in ipairs(Achievements.catalog) do
    if Achievements:MatchesFilter(achievement, save, { category = "CLASSES", classFilter = "MAGE" }, "DRUID") then
        mageCount = mageCount + 1
        ok(achievement.classToken == "MAGE", "MAGE filter only returns MAGE achievements (got " .. tostring(achievement.classToken) .. ")")
    end
end
eq(mageCount, 15, "MAGE class filter returns exactly 15 achievements")

eq(countMatches({ category = "ALL" }, "DRUID"), #Achievements.catalog,
    "category ALL ignores classFilter entirely and returns the whole catalog")

section("MatchesFilter: search + class + category together")

eq(countMatches({ category = "CLASSES", classFilter = "DRUID", search = "rebirth" }, "DRUID"), 2,
    "search combines with category+classFilter (2 Druid Rebirth achievements)")
eq(countMatches({ category = "CLASSES", classFilter = "WARRIOR", search = "rebirth" }, "DRUID"), 0,
    "search + a different class filter correctly returns nothing")

section("MatchesFilter: completion status")

-- Pick two real Druid achievement keys to mark unlocked.
local druidKeys = {}
for _, achievement in ipairs(Achievements.catalog) do
    if achievement.classToken == "DRUID" then druidKeys[#druidKeys + 1] = achievement.key end
end
save.unlocked[druidKeys[1]] = { at = 1 }
save.unlocked[druidKeys[2]] = { at = 1 }

eq(countMatches({ category = "CLASSES", classFilter = "DRUID", status = "UNLOCKED" }, "DRUID"), 2,
    "status=UNLOCKED shows only the completed Druid achievements")
eq(countMatches({ category = "CLASSES", classFilter = "DRUID", status = "LOCKED" }, "DRUID"), 13,
    "status=LOCKED shows the remaining incomplete Druid achievements")
eq(countMatches({ category = "CLASSES", classFilter = "DRUID", status = "ALL" }, "DRUID"), 15,
    "status=ALL (default) shows every Druid achievement regardless of completion")

save.unlocked[druidKeys[1]] = nil
save.unlocked[druidKeys[2]] = nil

section("MatchesFilter: enabledOnly")

_G.CreshChat = { IsFeatureEnabled = function() return false end }
eq(countMatches({ category = "COMBAT", enabledOnly = true }, "DRUID"), 0,
    "enabledOnly excludes a feature-gated category whose feature is off")
eq(countMatches({ category = "COMBAT", enabledOnly = false }, "DRUID"), countMatches({ category = "COMBAT" }, "DRUID"),
    "enabledOnly=false is equivalent to omitting it")
eq(countMatches({ category = "CLASSES", classFilter = "DRUID", enabledOnly = true }, "DRUID"), 15,
    "enabledOnly does not affect CLASSES (no required feature)")
_G.CreshChat = nil

-- ============================================================
-- 5. Standalone window / drawer panel parity
-- ============================================================
section("Standalone window and drawer panel show the same rows for the same filter state")

_G.UnitClass = function(unit) if unit == "player" then return "Warrior", "WARRIOR" end end

local okBuild, errBuild = pcall(function() Achievements:BuildWindow() end)
ok(okBuild, "BuildWindow() does not error (err: " .. tostring(errBuild) .. ")")
Achievements:OpenWindow()
ok(Achievements:IsWindowOpen(), "window is open for the parity check")

-- Plain table, not mockFrame(): production code does
-- `if drawer.achievementPanel then return ... end` (a memoization guard)
-- before that field is ever set, and mockFrame()'s __index permanently
-- caches a truthy no-op function the first time any unset key is *read* --
-- which would make that guard true forever and skip building the panel.
local drawer = {}
drawer.content = mockFrame()
drawer.mode = "ACHIEVEMENTS"
local helpers = stubHelpers()
local okDrawerBuild, errDrawerBuild = pcall(function() Achievements:BuildDrawerPanel(drawer, helpers) end)
ok(okDrawerBuild, "BuildDrawerPanel() does not error (err: " .. tostring(errDrawerBuild) .. ")")

local sharedState = { category = "CLASSES", classFilter = "WARRIOR", search = "", status = "ALL", enabledOnly = false }
Achievements.windowCategory, Achievements.windowClassFilter = sharedState.category, sharedState.classFilter
Achievements.windowSearchText, Achievements.windowStatus, Achievements.windowEnabledOnly =
    sharedState.search, sharedState.status, sharedState.enabledOnly
Achievements:RefreshWindow()

local panel = drawer.achievementPanel
panel.category, panel.classFilter = sharedState.category, sharedState.classFilter
panel.searchText, panel.status, panel.enabledOnly = sharedState.search, sharedState.status, sharedState.enabledOnly
Achievements:RefreshDrawerPanel(drawer, helpers, false)

-- Bug-fix round: the standalone window is now a paginated pool (see
-- Achievements.lua's WINDOW_PAGE_SIZE) and only ever shows one page's worth
-- of rows at a time, unlike the drawer panel which still renders every
-- matching row unpaginated. windowFilteredList (the full filtered set built
-- by RefreshWindow, independent of the current page) is the correct
-- equivalent to compare against the drawer's fully-visible row set.
local windowVisible, drawerVisible, drawerCount = {}, {}, 0
for _, achievement in ipairs(Achievements.windowFilteredList) do
    windowVisible[achievement.key] = true
end
for _, row in ipairs(panel.rows) do
    if row:IsShown() then drawerVisible[row.achievement.key] = true; drawerCount = drawerCount + 1 end
end
local windowCount = 0
for _ in pairs(windowVisible) do windowCount = windowCount + 1 end

eq(windowCount, 15, "standalone window's filtered set has exactly 15 entries for CLASSES/WARRIOR")
eq(drawerCount, 15, "drawer panel shows exactly 15 rows for CLASSES/WARRIOR")
local mismatch = false
for key in pairs(windowVisible) do if not drawerVisible[key] then mismatch = true end end
for key in pairs(drawerVisible) do if not windowVisible[key] then mismatch = true end end
ok(not mismatch, "standalone window and drawer panel match on the identical set of achievement keys")

-- Paging through every page of the standalone window must surface exactly
-- those same 15 keys, once each -- proving pagination neither drops nor
-- duplicates entries from the filtered set.
local pagedKeys, totalPages = {}, math.ceil(#Achievements.windowFilteredList / 6)
for pageIndex = 1, totalPages do
    Achievements:GoToPage(pageIndex)
    for _, row in ipairs(Achievements.windowPool) do
        if row:IsShown() and row.achievement then
            pagedKeys[row.achievement.key] = (pagedKeys[row.achievement.key] or 0) + 1
        end
    end
end
local pagedCount, duplicated = 0, false
for _, count in pairs(pagedKeys) do
    pagedCount = pagedCount + 1
    if count > 1 then duplicated = true end
end
eq(pagedCount, 15, "paging through every page surfaces all 15 CLASSES/WARRIOR achievements")
ok(not duplicated, "no achievement appears on more than one page")

-- ============================================================
-- Summary
-- ============================================================
print(("\n=== Results: %d passed, %d failed ==="):format(PASS, FAIL))
if FAIL > 0 then os.exit(1) end
