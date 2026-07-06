-- ProgressionWindowTests.lua
-- Lua 5.1 tests for the standalone Battle Pass and Achievements windows
-- (addons/CreshCollect/BattlePass.lua, addons/CreshCollect/Achievements.lua)
-- added in Phase 6: BuildWindow/ToggleWindow/OpenWindow/CloseWindow/
-- RefreshWindow must not error, must show real progression data, and must
-- never touch a CreshChat game-drawer object (proving they can't force an
-- unrelated CreshChat window open).
--
-- Loads the REAL production files (not reimplementations) via the same
-- loadfile + explicit-vararg technique established by SlashCommandTests.lua,
-- with a generic mock frame object standing in for the WoW widget API.
--
-- Usage: lua ProgressionWindowTests.lua [BattlePass.lua] [Achievements.lua]

-- ============================================================
-- Generic mock WoW frame: any unrecognised method is a safe no-op that
-- returns self (chainable); a handful of methods that production code
-- treats as real state (Show/Hide/IsShown, Set/GetText, scroll position)
-- are backed by real per-instance storage so assertions can observe them.
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
_G.C_Timer = { After = function() end }
_G.UIParent = mockFrame()
_G.GameTooltip = mockFrame()
_G.GameFontNormalSmall = {}
_G.GameFontHighlightSmall = {}
_G.STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"

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
-- Load the real production files
-- ============================================================

local battlePassPath   = (arg and arg[1]) or "addons/CreshCollect/BattlePass.lua"
local achievementsPath = (arg and arg[2]) or "addons/CreshCollect/Achievements.lua"

-- Some production files carry a leading UTF-8 BOM; strip it before loading
-- since Lua 5.1's loadstring() (unlike WoW's own client loader) chokes on it.
local function loadProductionFile(path, ...)
    local f = assert(io.open(path, "rb"))
    local src = f:read("*a")
    f:close()
    if src:sub(1, 3) == "\239\187\191" then src = src:sub(4) end
    local chunk = assert(loadstring(src, "@" .. path))
    return chunk(...)
end

-- CC is deliberately left with NO .UI field at all -- production code must
-- treat CreshChat's UI as fully optional. This is the whole point of the
-- test: if any window-building code accidentally *required* CC.UI, or
-- called into CC.UI.OpenGameDrawer / OpenChannel (the "unrelated CreshChat
-- window" it must never open), it would error here since neither exists.
local COL = { version = "0.2.3" }
_G.CreshCollectDB = {
    achievements  = { unlocked = {}, progress = {}, stats = {}, uniqueBosses = {}, professionRanks = {}, visitedZones = {}, totalCoins = 0, totalPassXP = 0 },
    arcadeRewards = { coins = 0, lifetimeCoins = 0, gameCoins = 0, activityCoins = 0, explorationCoins = 0, spentCoins = 0, passXP = 0, claimed = {}, unlockedThemes = {}, themeUnlockSources = {}, recent = {}, gamesRewarded = 0, milestoneGoals = {} },
}
loadProductionFile(battlePassPath, "CreshCollect", COL)
loadProductionFile(achievementsPath, "CreshCollect", COL)

local Pass = COL.BattlePass
local Achievements = COL.Achievements
if not Pass or not Pass.BuildWindow or not Pass.ToggleWindow or not Pass.RefreshWindow then
    print("FATAL: CreshCollect.BattlePass / BuildWindow / ToggleWindow / RefreshWindow not found")
    os.exit(2)
end
if not Achievements or not Achievements.BuildWindow or not Achievements.ToggleWindow or not Achievements.RefreshWindow then
    print("FATAL: CreshCollect.Achievements / BuildWindow / ToggleWindow / RefreshWindow not found")
    os.exit(2)
end

-- ============================================================
-- 1. Battle Pass standalone window
-- ============================================================
section("BattlePass window: build/open/close without CC.UI present")

local okBuild, errBuild = pcall(function() Pass:BuildWindow() end)
ok(okBuild, "BuildWindow() does not error with no CC.UI at all (err: " .. tostring(errBuild) .. ")")
ok(Pass.window ~= nil, "window frame was created")
ok(Pass:IsWindowOpen() == false, "window starts closed")

local okOpen, errOpen = pcall(function() Pass:OpenWindow() end)
ok(okOpen, "OpenWindow() does not error (err: " .. tostring(errOpen) .. ")")
ok(Pass:IsWindowOpen() == true, "window is open after OpenWindow()")

section("BattlePass window: shows real progression data (level 1, fresh save)")
eq(Pass.windowHero.level._text, "LEVEL 1 / " .. Pass.maxLevel, "hero shows LEVEL 1 for a fresh save")
ok(Pass.windowHero.wallet._text:find("0 CRESH COINS") ~= nil, "wallet shows 0 coins for a fresh save")
ok(#Pass.windowLevelList > 0, "windowLevelList is populated (BuildPassLevelList was called)")

section("BattlePass window: claiming updates the same data GetProgress/IsRewardClaimed report")
CreshCollectDB.arcadeRewards.passXP = Pass:GetCumulativeXP(5)
ok(Pass:IsLevelReached(5) == true, "level 5 requirement now met (sanity check on the fixture)")
local claimed = Pass:ClaimReward(5, true)
ok(claimed == true, "ClaimReward(5) succeeds once the level is reached")
ok(Pass:IsRewardClaimed(5) == true, "IsRewardClaimed(5) reflects the claim")
Pass:RefreshWindow()
ok(Pass.windowRequirement ~= nil, "requirement detail box exists after refresh")

section("BattlePass window: close")
Pass:CloseWindow()
ok(Pass:IsWindowOpen() == false, "window reports closed after CloseWindow()")

-- ============================================================
-- 2. Achievements standalone window
-- ============================================================
section("Achievements window: build/open/close without CC.UI present")

local okABuild, errABuild = pcall(function() Achievements:BuildWindow() end)
ok(okABuild, "BuildWindow() does not error with no CC.UI at all (err: " .. tostring(errABuild) .. ")")
ok(Achievements.window ~= nil, "window frame was created")
ok(#Achievements.catalog > 0, "catalog was populated by BuildWindow's own BuildCatalog() call")
eq(#Achievements.windowRows, #Achievements.catalog, "one row was built per catalog entry")

local okAOpen, errAOpen = pcall(function() Achievements:OpenWindow() end)
ok(okAOpen, "OpenWindow() does not error (err: " .. tostring(errAOpen) .. ")")
ok(Achievements:IsWindowOpen() == true, "window is open after OpenWindow()")

-- Rework Phase 5: GAMES achievements moved to CreshGames entirely, so no
-- catalog entry anywhere in CreshCollect's Achievements.lua has
-- category == "GAMES" any more -- regardless of CreshGames presence.
section("Achievements window: GAMES category no longer exists in CreshCollect")
_G.CreshSuite = nil
Achievements.windowCategory = "GAMES"
Achievements:RefreshWindow()
local gamesRows = 0
for _, row in ipairs(Achievements.windowRows) do
    if row.achievement.category == "GAMES" then gamesRows = gamesRows + 1 end
end
eq(gamesRows, 0, "no catalog entry has category GAMES when CreshGames is absent")

_G.CreshSuite = {
    _loaded = { CRESHGAMES = true },
    IsProductLoaded = function(self, name) return self._loaded[string.upper(tostring(name or ""))] == true end,
}
Achievements:RefreshWindow()
gamesRows = 0
for _, row in ipairs(Achievements.windowRows) do
    if row.achievement.category == "GAMES" then gamesRows = gamesRows + 1 end
end
eq(gamesRows, 0, "no catalog entry has category GAMES even once CreshGames is loaded")

section("Achievements window: close")
Achievements:CloseWindow()
ok(Achievements:IsWindowOpen() == false, "window reports closed after CloseWindow()")

-- ============================================================
-- Summary
-- ============================================================
print(("\n=== Results: %d passed, %d failed ==="):format(PASS, FAIL))
if FAIL > 0 then os.exit(1) end
