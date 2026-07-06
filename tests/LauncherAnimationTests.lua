-- LauncherAnimationTests.lua
-- Lua 5.1 tests for the shared launcher's open/close animation controller in
-- shared/Launcher.lua (Phase 9 -- ownership moved out of CreshChat/UI.lua;
-- math/policy unchanged from Phase 5):
--   Launcher:AnimateReveal(opening)   -- starts/redirects the one shared
--                                         animation for the five satellites
--   Launcher:TickAnimation(elapsed)  -- advances progress, applies
--                                         alpha/position, finishes on completion
--   Launcher:FinishAnimation(opening) -- snaps to the exact resting state
--                                         and tears down the OnUpdate driver
--
-- Loads the REAL production shared/Launcher.lua. Its own CreateFrame mock
-- actually captures the OnUpdate hook installed on the animation driver
-- frame, so this file can assert it gets cleared.
--
-- Usage: lua LauncherAnimationTests.lua [Launcher.lua]

local capturedScripts = {}

function CreateFrame()
    local f = { shown = true }
    function f:SetScript(kind, fn) capturedScripts[self] = capturedScripts[self] or {}; capturedScripts[self][kind] = fn end
    function f:GetScript(kind) return capturedScripts[self] and capturedScripts[self][kind] end
    function f:RegisterEvent() end
    function f:RegisterForDrag() end
    return f
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

local function freshLoad()
    _G.CreshSuiteLauncherAPI = nil
    _G.CreshChatDB = { ui = {}, bubbleVisible = true }
    _G.CreshGamesDB = nil
    _G.CreshCollectDB = nil
    local chunk = assert(loadfile(launcherPath))
    chunk()
    return _G.CreshSuiteLauncherAPI
end

local Launcher = freshLoad()
if not Launcher or not Launcher.AnimateReveal or not Launcher.TickAnimation or not Launcher.FinishAnimation then
    print("FATAL: CreshSuiteLauncherAPI / animation functions not found after loading Launcher.lua")
    os.exit(2)
end

-- ============================================================
-- Mock frames: bubble + five satellite buttons.
-- ============================================================
local function mockSatellite()
    local b = {
        shown = false, alpha = 0, mouseEnabled = true, x = nil, y = nil,
        point = nil, relativePoint = nil, relativeTo = nil,
    }
    function b:SetShown(v) self.shown = v and true or false end
    function b:Show() self.shown = true end
    function b:Hide() self.shown = false end
    function b:IsShown() return self.shown == true end
    function b:SetAlpha(v) self.alpha = v end
    function b:GetAlpha() return self.alpha end
    function b:EnableMouse(v) self.mouseEnabled = v and true or false end
    function b:ClearAllPoints() self.point, self.relativeTo, self.relativePoint, self.x, self.y = nil, nil, nil, nil, nil end
    function b:SetPoint(point, relativeTo, relativePoint, x, y)
        self.point, self.relativeTo, self.relativePoint, self.x, self.y = point, relativeTo, relativePoint, x, y
    end
    function b:SetBackdrop() end
    function b:SetBackdropColor() end
    function b:SetBackdropBorderColor() end
    function b:GetLeft() return 900 end
    function b:GetRight() return 936 end
    function b:GetTop() return 550 end
    function b:GetBottom() return 514 end
    return b
end

local function mockBubble()
    local b = mockSatellite()
    function b:GetCenter() return 918, 532 end
    -- Bubble sits comfortably centre-screen: plenty of room in every
    -- direction so orientation/direction choice never confounds these tests.
    return b
end

local function freshLauncher()
    Launcher = freshLoad()
    _G.CreshChat = { IsFeatureEnabled = function() return true end, UI = {} }
    Launcher.bubble = mockBubble()
    Launcher.buttons = {
        chatButton = mockSatellite(),
        gamesButton = mockSatellite(),
        achieveButton = mockSatellite(),
        progressButton = mockSatellite(),
        questButton = mockSatellite(),
    }
    Launcher.visible = true
    Launcher.expanded = nil
    Launcher.anim = nil
    Launcher.animDriver = nil
    return Launcher
end

local SATELLITE_KEYS = { "chatButton", "gamesButton", "achieveButton", "progressButton", "questButton" }
local function allSatellites()
    local list = {}
    for _, key in ipairs(SATELLITE_KEYS) do table.insert(list, Launcher.buttons[key]) end
    return list
end

-- ============================================================
-- 1. Opening
-- ============================================================
section("AnimateReveal(true): starts from the flush-against-C origin")
Launcher = freshLauncher()
Launcher:AnimateReveal(true)
for _, button in ipairs(allSatellites()) do
    eq(button.shown, true, "button is shown immediately (alpha ramps, visibility doesn't wait)")
    eq(button.x, 0, "button starts at offset 0 (flush against C)")
    eq(button.mouseEnabled, false, "button starts non-interactive")
end
ok(Launcher.anim.active, "animation is active")
eq(Launcher.anim.target, 1, "target is 1 (opening)")

section("Opening: partial tick increases alpha but stays below the interactive threshold early on")
Launcher = freshLauncher()
Launcher:AnimateReveal(true)
Launcher:TickAnimation(0.02) -- small step: t = 0.02/0.20 = 0.10
local anyEnabledTooEarly = false
for _, button in ipairs(allSatellites()) do
    if button.alpha <= 0 then fail("alpha should have advanced off 0 after a tick") end
    if button.mouseEnabled then anyEnabledTooEarly = true end
end
ok(not anyEnabledTooEarly, "still non-interactive well before the 0.6 threshold")

section("Opening: becomes interactive once eased progress crosses the threshold")
Launcher = freshLauncher()
Launcher:AnimateReveal(true)
Launcher:TickAnimation(0.16) -- t = 0.8 -> easeOutCubic(0.8) = 1-0.2^3 = 0.992 (> 0.6)
for _, button in ipairs(allSatellites()) do
    ok(button.mouseEnabled, "button became interactive once sufficiently visible")
end

section("Opening completion: exact final position and alpha, driver removed")
Launcher = freshLauncher()
Launcher:AnimateReveal(true)
Launcher:TickAnimation(1.0) -- overshoots duration; clamps to done
for index, button in ipairs(allSatellites()) do
    eq(button.alpha, 1, "final alpha is exactly 1 for satellite #" .. index)
    ok(button.shown, "final Shown state is true for satellite #" .. index)
    ok(button.mouseEnabled, "final interaction state is enabled for satellite #" .. index)
    local expectedExtent = index * (36 + 6) - 36
    eq(button.x, expectedExtent, "final x offset matches PositionButtons' own formula for satellite #" .. index)
end
ok(not Launcher.anim.active, "animation marks itself inactive on completion")
local driverScript = Launcher.animDriver and Launcher.animDriver:GetScript("OnUpdate")
eq(driverScript, nil, "OnUpdate is cleared immediately after completion")

-- ============================================================
-- 2. Closing
-- ============================================================
section("Closing completion: exact final alpha (0), hidden, non-interactive, driver removed")
Launcher = freshLauncher()
Launcher:AnimateReveal(true)
Launcher:TickAnimation(1.0)
Launcher.expanded = false
Launcher:AnimateReveal(false)
eq(Launcher.anim.target, 0, "target is 0 (closing)")
for _, button in ipairs(allSatellites()) do
    eq(button.mouseEnabled, false, "navigation disabled immediately when closing starts")
end
Launcher:TickAnimation(1.0)
for index, button in ipairs(allSatellites()) do
    eq(button.alpha, 0, "final alpha is exactly 0 for satellite #" .. index)
    eq(button.shown, false, "satellite #" .. index .. " is hidden on close completion")
    eq(button.mouseEnabled, false, "satellite #" .. index .. " stays non-interactive once closed")
end
ok(not Launcher.anim.active, "animation marks itself inactive on completion")
eq(Launcher.animDriver:GetScript("OnUpdate"), nil, "OnUpdate is cleared immediately after close completes too")

section("Hidden button interaction: a fully closed button never reports itself clickable")
for _, button in ipairs(allSatellites()) do
    ok(button.shown == false and button.mouseEnabled == false, "closed satellite is both hidden and mouse-disabled")
end

-- ============================================================
-- 3. Rapid-click handling: reversal, not duplication or a stuck OnUpdate
-- ============================================================
section("Rapid clicks: a second 'open' while already opening does not duplicate the animation")
Launcher = freshLauncher()
Launcher:AnimateReveal(true)
Launcher:TickAnimation(0.05)
local tAfterFirstTick = Launcher.anim.t
Launcher:AnimateReveal(true) -- same target again -- must be a no-op on progress
eq(Launcher.anim.t, tAfterFirstTick, "re-clicking the same direction does not reset or duplicate progress")
ok(Launcher.anim.active, "still exactly one active animation")

section("Rapid clicks: closing mid-open reverses smoothly from the current progress (documented policy)")
Launcher = freshLauncher()
Launcher:AnimateReveal(true)
Launcher:TickAnimation(0.08) -- partway open
local progressBeforeReversal = Launcher.anim.t
local alphaBeforeReversal = Launcher.buttons.chatButton.alpha
Launcher:AnimateReveal(false) -- reverse without finishing
eq(Launcher.anim.t, progressBeforeReversal, "reversal preserves the exact progress value, no snap")
eq(Launcher.buttons.chatButton.alpha, alphaBeforeReversal, "reversal does not touch alpha/position before the next tick")
eq(Launcher.anim.target, 0, "target flips to closing")
Launcher:TickAnimation(0.02)
ok(Launcher.buttons.chatButton.alpha < alphaBeforeReversal, "alpha now decreases from where it was, continuing smoothly toward closed")

section("Rapid clicks: never leaves an invalid alpha value even under repeated reversal")
Launcher = freshLauncher()
Launcher:AnimateReveal(true)
for _ = 1, 20 do
    Launcher:TickAnimation(0.013)
    Launcher:AnimateReveal(Launcher.anim.target == 0)
    for _, button in ipairs(allSatellites()) do
        if button.alpha < 0 or button.alpha > 1 then
            fail(("alpha out of range: %s"):format(tostring(button.alpha)))
        end
    end
end
pass("20 rapid alternating reversals never produced an out-of-range alpha")

section("Rapid clicks: button order is never reversed across repeated runs")
Launcher = freshLauncher()
Launcher:AnimateReveal(true)
Launcher:TickAnimation(1.0)
local firstOrder = {}
for i = 1, Launcher.anim.count do firstOrder[i] = Launcher.anim.items[i].button end
Launcher.expanded = false
Launcher:AnimateReveal(false)
Launcher:TickAnimation(1.0)
Launcher.expanded = true
Launcher:AnimateReveal(true)
local sameOrder = true
for i = 1, Launcher.anim.count do
    if Launcher.anim.items[i].button ~= firstOrder[i] then sameOrder = false end
end
ok(sameOrder, "the animated item list is rebuilt in the same registry order every run")

section("No nil callbacks: ticking with no active animation is a harmless no-op")
Launcher = freshLauncher()
local okCall, err = pcall(function() Launcher:TickAnimation(0.1) end)
ok(okCall, "ticking with nothing active does not error (err: " .. tostring(err) .. ")")

-- ============================================================
-- 4. Orientation change / launcher movement while open
-- ============================================================
section("Orientation change while fully open: re-layout does not error and keeps satellites at their (now-recomputed) rest position")
Launcher = freshLauncher()
Launcher:AnimateReveal(true)
Launcher:TickAnimation(1.0)
local okOrientation, errOrientation = pcall(function() Launcher:SetOrientation("VERTICAL") end)
ok(okOrientation, "changing orientation after the open animation finished does not error (err: " .. tostring(errOrientation) .. ")")
for _, button in ipairs(allSatellites()) do
    eq(button.alpha, 1, "satellites remain fully visible after an orientation change once open")
end

section("Launcher movement while open: PositionButtons (the drag-stop handler) does not error and keeps satellites visible")
Launcher = freshLauncher()
Launcher:AnimateReveal(true)
Launcher:TickAnimation(1.0)
local okMove, errMove = pcall(function() Launcher:PositionButtons() end)
ok(okMove, "repositioning after a drag does not error while the row is open (err: " .. tostring(errMove) .. ")")
for _, button in ipairs(allSatellites()) do
    eq(button.alpha, 1, "satellites remain fully visible after a reposition once open")
end

-- ============================================================
-- Summary
-- ============================================================
print(("\n=== Results: %d passed, %d failed ==="):format(PASS, FAIL))
if FAIL > 0 then os.exit(1) end
