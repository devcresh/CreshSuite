-- LauncherRoutingTests.lua
-- Lua 5.1 tests for the "C" launcher's addon-aware routing in
-- addons/CreshChat/UI.lua (Phase 8):
--   UI:GetLauncherEffectiveDest()   -- which destination C defaults to
--   UI:LauncherToggleMode(dest)     -- per-destination dispatch, including
--                                      the ACHIEVEMENTS fix (now routes
--                                      through the Suite "OpenAchievements"
--                                      service instead of the retired
--                                      drawer path)
--   UI:LauncherPrimaryClick()       -- single click on C: opens directly
--                                      when <=1 destination is installed,
--                                      otherwise toggles the satellite reveal
--   UI:LauncherSatelliteClick(dest) -- a revealed satellite button: performs
--                                      its action then collapses the reveal
--   UI:SetBubbleGroupShown/PositionQuickButtons -- which satellite buttons
--                                      (chat/games/achievements/progress)
--                                      are shown for a given addon combination
--
-- Loads the REAL production UI.lua. Frame-building methods (BuildBubble,
-- BuildGameDrawer, ToggleMain, OpenSettings, OpenGameDrawer, ...) are not
-- exercised here -- consistent with GameDrawerAvailabilityTests.lua, this
-- file only drives the pure routing/dispatch logic and stubs the handful
-- of heavy widget-touching methods those functions call through to.
--
-- Usage: lua LauncherRoutingTests.lua [UI.lua]

function CreateFrame()
    return { SetScript = function() end, RegisterEvent = function() end, RegisterForDrag = function() end }
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
-- Load the real production file
-- ============================================================

local uiPath = (arg and arg[1]) or "addons/CreshChat/UI.lua"

local function loadProductionFile(path, ...)
    local chunk = assert(loadfile(path))
    return chunk(...)
end

local CC = { version = "0.2.3", db = { ui = {} } }
loadProductionFile(uiPath, "CreshChat", CC)

local UI = CC.UI
if not UI or not UI.GetLauncherEffectiveDest or not UI.LauncherToggleMode
    or not UI.LauncherPrimaryClick or not UI.LauncherSatelliteClick then
    print("FATAL: CreshChat.UI / launcher routing functions not found after loading UI.lua")
    os.exit(2)
end

-- Isolate routing/dispatch from the (unrelated) alpha/fade animation system
-- and from the real, widget-heavy per-destination openers -- exactly the
-- same tactic GameDrawerAvailabilityTests.lua uses for BuildGameDrawer.
UI.RefreshLauncherVisibility = function() end

local printed = {}
CC.Print = function(_, msg) table.insert(printed, msg) end

local toggleMainCalls, openSettingsCalls = 0, 0
local openGameDrawerCalls, closeGameDrawerCalls, setGameDrawerModeCalls = 0, 0, 0
UI.ToggleMain = function() toggleMainCalls = toggleMainCalls + 1 end
UI.OpenSettings = function() openSettingsCalls = openSettingsCalls + 1 end
UI.OpenGameDrawer = function(_, mode) openGameDrawerCalls = openGameDrawerCalls + 1 end
UI.CloseGameDrawer = function() closeGameDrawerCalls = closeGameDrawerCalls + 1 end
UI.SetGameDrawerMode = function(_, mode) setGameDrawerModeCalls = setGameDrawerModeCalls + 1 end

local function resetCallCounts()
    toggleMainCalls, openSettingsCalls = 0, 0
    openGameDrawerCalls, closeGameDrawerCalls, setGameDrawerModeCalls = 0, 0, 0
    printed = {}
end

local function setAddons(chatOn, gamesOn, achieveOn, progressOn)
    CC.IsFeatureEnabled = chatOn and function() return true end or nil
    CC.Games = gamesOn and {} or nil
    CC.Achievements = achieveOn and { IsWindowOpen = function() return false end } or nil
    CC.ProgressHub = progressOn and { HasAnyEnabled = function() return true end } or nil
    CC.ProgressOverview = nil
end

local function freshOptions()
    CC.db.ui = {}
    UI.gameDrawer = nil
    UI.launcherExpanded = nil
    _G.CreshSuite = nil
end

-- ============================================================
-- 1. GetLauncherEffectiveDest
-- ============================================================
section("GetLauncherEffectiveDest: fallback order when nothing configured/remembered")

freshOptions()
setAddons(true, true, true, true)
eq(UI:GetLauncherEffectiveDest(), "CHAT", "chat preferred first when everything is installed")

setAddons(false, true, true, true)
eq(UI:GetLauncherEffectiveDest(), "GAMES", "falls back to games when chat is off")

setAddons(false, false, true, true)
eq(UI:GetLauncherEffectiveDest(), "ACHIEVEMENTS", "falls back to achievements when chat+games are off")

setAddons(false, false, false, true)
eq(UI:GetLauncherEffectiveDest(), "PROGRESS", "falls back to progress when only CreshCollect's progress is on")

setAddons(false, false, false, false)
eq(UI:GetLauncherEffectiveDest(), "SETTINGS", "falls back to settings when nothing at all is available")

section("GetLauncherEffectiveDest: explicit configured default")
CC.db.ui.launcherDefault = "GAMES"
setAddons(true, true, true, true)
eq(UI:GetLauncherEffectiveDest(), "GAMES", "configured default (GAMES) honoured when available")

CC.db.ui.launcherDefault = "GAMES"
setAddons(true, false, true, true)
eq(UI:GetLauncherEffectiveDest(), "CHAT", "configured default (GAMES) falls back when GAMES unavailable")
CC.db.ui.launcherDefault = nil

-- ============================================================
-- 2. LauncherToggleMode dispatch
-- ============================================================
section("LauncherToggleMode: CHAT dispatches to ToggleMain")
freshOptions(); resetCallCounts()
UI:LauncherToggleMode("CHAT")
eq(toggleMainCalls, 1, "ToggleMain invoked exactly once")
eq(CC.db.ui.lastLauncherDest, "CHAT", "lastLauncherDest recorded")

section("LauncherToggleMode: ACHIEVEMENTS routes through the Suite service (Phase 6/8 fix)")
freshOptions(); resetCallCounts()
local achieveCalls = 0
_G.CreshSuite = { GetService = function(_, name) if name == "OpenAchievements" then return function() achieveCalls = achieveCalls + 1 end end end }
UI:LauncherToggleMode("ACHIEVEMENTS")
eq(achieveCalls, 1, "OpenAchievements service invoked exactly once")
eq(openGameDrawerCalls, 0, "the old drawer is NOT opened for ACHIEVEMENTS anymore")
eq(setGameDrawerModeCalls, 0, "the old drawer mode is NOT changed for ACHIEVEMENTS anymore")
eq(closeGameDrawerCalls, 0, "the old drawer is NOT closed for ACHIEVEMENTS anymore")
eq(CC.db.ui.lastLauncherDest, "ACHIEVEMENTS", "lastLauncherDest recorded")

section("LauncherToggleMode: ACHIEVEMENTS with no CreshSuite/service prints 'Requires CreshCollect.'")
freshOptions(); resetCallCounts()
_G.CreshSuite = nil
UI:LauncherToggleMode("ACHIEVEMENTS")
eq(printed[#printed], "Requires CreshCollect.", "exact message printed")
eq(openGameDrawerCalls, 0, "no drawer touched when the service is absent")

section("LauncherToggleMode: PROGRESS routes through the Suite service")
freshOptions(); resetCallCounts()
local progressCalls = 0
_G.CreshSuite = { GetService = function(_, name) if name == "OpenProgressHub" then return function() progressCalls = progressCalls + 1 end end end }
UI:LauncherToggleMode("PROGRESS")
eq(progressCalls, 1, "OpenProgressHub service invoked exactly once")

section("LauncherToggleMode: GAMES with no service prints message and touches no drawer")
freshOptions(); resetCallCounts()
_G.CreshSuite = nil
UI:LauncherToggleMode("GAMES")
eq(printed[#printed], "CreshGames is not installed or loaded.", "message printed")
eq(openGameDrawerCalls, 0, "drawer not opened when the service is absent")

section("LauncherToggleMode: GAMES with service present opens the drawer")
freshOptions(); resetCallCounts()
_G.CreshSuite = { GetService = function(_, name) if name == "OpenGames" then return function() end end end }
UI:LauncherToggleMode("GAMES")
eq(openGameDrawerCalls, 1, "OpenGameDrawer invoked once when no drawer was open yet")

-- ============================================================
-- 3. LauncherPrimaryClick: direct-open vs. expand-to-reveal
-- ============================================================
section("LauncherPrimaryClick: single installed addon opens directly, no reveal")
freshOptions(); resetCallCounts()
setAddons(true, false, false, false)
UI:LauncherPrimaryClick()
eq(toggleMainCalls, 1, "chat-only install: clicking C opens CreshChat directly")
ok(UI.launcherExpanded ~= true, "no satellites revealed when only one destination exists")

freshOptions(); resetCallCounts()
setAddons(false, true, false, false)
_G.CreshSuite = { GetService = function(_, name) if name == "OpenGames" then return function() end end end }
UI:LauncherPrimaryClick()
eq(openGameDrawerCalls, 1, "games-only install: clicking C opens the games hub directly")
ok(UI.launcherExpanded ~= true, "no satellites revealed when only one destination exists")

freshOptions(); resetCallCounts()
setAddons(false, false, false, true)
_G.CreshSuite = { GetService = function(_, name) if name == "OpenProgressHub" then return function() progressCalls = progressCalls + 1 end end end }
progressCalls = 0
UI:LauncherPrimaryClick()
eq(progressCalls, 1, "collect-only install: clicking C opens the progression interface directly")
ok(UI.launcherExpanded ~= true, "no satellites revealed when only one destination exists")

section("LauncherPrimaryClick: 2+ installed destinations reveal satellites first, then open on second click")
freshOptions(); resetCallCounts()
setAddons(true, true, false, false)
_G.CreshSuite = nil
UI:LauncherPrimaryClick()
ok(UI.launcherExpanded == true, "first click reveals the satellites")
eq(toggleMainCalls, 0, "first click does not itself open a destination")

UI:LauncherPrimaryClick()
ok(UI.launcherExpanded == false, "second click collapses the satellites again")
eq(toggleMainCalls, 1, "second click opens the default destination (chat) exactly once")

section("LauncherPrimaryClick: all three addons installed -- deterministic, every destination reachable")
freshOptions(); resetCallCounts()
setAddons(true, true, true, true)
_G.CreshSuite = { GetService = function(_, name)
    if name == "OpenAchievements" then return function() achieveCalls = achieveCalls + 1 end end
    if name == "OpenProgressHub" then return function() progressCalls = progressCalls + 1 end end
end }
achieveCalls, progressCalls = 0, 0
UI:LauncherPrimaryClick()
ok(UI.launcherExpanded == true, "click reveals satellites when all three addons are installed")
UI:LauncherSatelliteClick("ACHIEVEMENTS")
eq(achieveCalls, 1, "achievements satellite reaches CreshCollect's achievements window")
ok(UI.launcherExpanded == false, "expansion collapses after a satellite is used")

UI:LauncherPrimaryClick()
UI:LauncherSatelliteClick("PROGRESS")
eq(progressCalls, 1, "progress satellite reaches CreshCollect's progression interface")

UI:LauncherPrimaryClick()
UI:LauncherSatelliteClick("GAMES")
-- GAMES has no service registered above -> falls through to the "not installed" print,
-- proving the satellite dispatches through the same guarded path as a direct click.
eq(printed[#printed], "CreshGames is not installed or loaded.", "games satellite dispatches through the normal GAMES guard")

-- ============================================================
-- 4. Satellite visibility (SetBubbleGroupShown / PositionQuickButtons)
-- ============================================================
local function mockButton()
    local b = { shown = nil }
    function b:SetShown(v) self.shown = v end
    function b:ClearAllPoints() end
    function b:SetPoint() end
    return b
end

local function mockBubble()
    local b = mockButton()
    function b:GetCenter() return 500 end
    return b
end

local function freshBubbleGroup()
    UI.bubble = mockBubble()
    UI.chatButton = mockButton()
    UI.gamesButton = mockButton()
    UI.achieveButton = mockButton()
    UI.progressButton = mockButton()
    UI.whisperBubble, UI.generalBubble, UI.combatBubble = nil, nil, nil
    UI.quickInput, UI.combatPanel = nil, nil
end

section("Satellite visibility: single addon installed -> no satellites, even though the bubble shows")
freshOptions()
setAddons(true, false, false, false)
freshBubbleGroup()
UI:SetBubbleGroupShown(true)
eq(UI.bubble.shown, true, "main C bubble is shown")
eq(UI.chatButton.shown, false, "chat satellite hidden (chat has nothing else to expand to)")
eq(UI.gamesButton.shown, false, "games satellite hidden (games not installed)")
eq(UI.achieveButton.shown, false, "achievements satellite hidden (collect not installed)")
eq(UI.progressButton.shown, false, "progress satellite hidden (collect not installed)")

section("Satellite visibility: two addons installed, not yet expanded -> satellites stay hidden (minimal)")
freshOptions()
setAddons(true, true, false, false)
freshBubbleGroup()
UI.launcherExpanded = false
UI:SetBubbleGroupShown(true)
eq(UI.gamesButton.shown, false, "games satellite stays tucked away until C is clicked")
eq(UI.chatButton.shown, false, "chat satellite stays tucked away until C is clicked")

section("Satellite visibility: two addons installed, expanded -> exactly the installed ones appear")
freshOptions()
setAddons(true, true, false, false)
freshBubbleGroup()
UI.launcherExpanded = true
UI:SetBubbleGroupShown(true)
eq(UI.chatButton.shown, true, "chat satellite appears once revealed")
eq(UI.gamesButton.shown, true, "games satellite appears once revealed")
eq(UI.achieveButton.shown, false, "achievements satellite absent (CreshCollect not installed)")
eq(UI.progressButton.shown, false, "progress satellite absent (CreshCollect not installed)")

section("Satellite visibility: all three addons installed, expanded -> every destination gets a button")
freshOptions()
setAddons(true, true, true, true)
freshBubbleGroup()
UI.launcherExpanded = true
UI:SetBubbleGroupShown(true)
eq(UI.chatButton.shown, true, "chat satellite present")
eq(UI.gamesButton.shown, true, "games satellite present")
eq(UI.achieveButton.shown, true, "achievements satellite present")
eq(UI.progressButton.shown, true, "progress satellite present")

section("Satellite visibility: CreshChat absent (games+collect only) -- no chat satellite ever, others always on")
freshOptions()
setAddons(false, true, true, true)
freshBubbleGroup()
UI.launcherExpanded = false
UI:SetBubbleGroupShown(true)
eq(UI.chatButton.shown, false, "no chat satellite when CreshChat's chat feature is off")
eq(UI.gamesButton.shown, true, "games button becomes primary-visible when chat is off (module IS the launcher)")
eq(UI.achieveButton.shown, true, "achievements button becomes primary-visible when chat is off")
eq(UI.progressButton.shown, true, "progress button becomes primary-visible when chat is off")

-- ============================================================
-- Summary
-- ============================================================
print(("\n=== Results: %d passed, %d failed ==="):format(PASS, FAIL))
if FAIL > 0 then os.exit(1) end
