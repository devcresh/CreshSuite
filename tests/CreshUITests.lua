-- CreshUITests.lua
-- Lua 5.1 static/mock tests for shared/CreshUI.lua
-- Usage: lua CreshUITests.lua <path-to-CreshUI.lua> [path-to-Suite.lua]

-- ============================================================
-- WoW API stubs
-- ============================================================
local function newMockFrame(kind, name, parent)
    local f = { _kind = kind, _name = name, _parent = parent, _scripts = {}, _width = 0, _height = 0, _scale = 1 }
    function f:SetSize(w, h) self._width = w; self._height = h end
    function f:GetWidth() return self._width end
    function f:GetHeight() return self._height end
    function f:SetScale(s) self._scale = s end
    function f:GetScale() return self._scale end
    function f:SetBackdrop(bd) self._backdrop = bd end
    function f:SetBackdropColor(r, g, b, a) self._backdropColor = { r, g, b, a } end
    function f:SetBackdropBorderColor(r, g, b, a) self._backdropBorderColor = { r, g, b, a } end
    function f:SetScript(name, fn) self._scripts[name] = fn end
    function f:GetScript(name) return self._scripts[name] end
    function f:HookScript(name, fn)
        self._hooks = self._hooks or {}
        self._hooks[name] = self._hooks[name] or {}
        table.insert(self._hooks[name], fn)
    end
    function f:FireHooks(name, ...)
        for _, fn in ipairs((self._hooks or {})[name] or {}) do fn(self, ...) end
    end
    function f:SetFrameStrata(s) self._strata = s end
    function f:GetFrameStrata() return self._strata end
    function f:SetFrameLevel(l) self._level = l end
    function f:GetFrameLevel() return self._level end
    function f:SetToplevel(v) self._toplevel = v end
    function f:RegisterEvent(event) self._events = self._events or {}; self._events[event] = true end
    function f:SetPoint(point, relativeTo, relativePoint, x, y)
        self._point = { point = point, relativeTo = relativeTo, relativePoint = relativePoint, x = x, y = y }
    end
    function f:ClearAllPoints() self._point = nil end
    function f:GetPoint()
        if not self._point then return nil end
        return self._point.point, self._point.relativeTo, self._point.relativePoint, self._point.x, self._point.y
    end
    function f:GetParent() return self._parent end
    function f:SetMovable(v) self._movable = v end
    function f:EnableMouse(v) self._mouseEnabled = v end
    function f:SetClampedToScreen(v) self._clamped = v end
    function f:SetAlpha(a) self._alpha = a end
    function f:GetAlpha() return self._alpha end
    function f:SetAllPoints() self._allPoints = true end
    function f:CreateFontString(name)
        local fs = newMockFrame("FontString", name)
        function fs:SetFont(path, size, flags) self._font = { path, size, flags } end
        function fs:SetTextColor(r, g, b, a) self._textColor = { r, g, b, a } end
        function fs:SetJustifyH(j) self._justifyH = j end
        function fs:SetJustifyV(j) self._justifyV = j end
        function fs:SetText(t) self._text = t end
        function fs:GetText() return self._text end
        return fs
    end
    return f
end

function CreateFrame(kind, name, parent, template)
    return newMockFrame(kind, name, parent)
end

_G.UIParent = newMockFrame("Frame", "UIParent")
_G.UIParent:SetSize(1024, 768)
_G.STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
_G.BackdropTemplateMixin = nil -- classic-era default; TemplateName() should return nil

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

local function ok(cond, msg)
    if cond then pass(msg) else fail(msg) end
end

local function eq(a, b, msg)
    if a == b then
        pass(msg)
    else
        fail(("%s  (expected %q, got %q)"):format(msg, tostring(b), tostring(a)))
    end
end

-- ============================================================
-- Load CreshUI.lua
-- ============================================================
local uiPath = (arg and arg[1]) or "shared/CreshUI.lua"
local suitePath = (arg and arg[2]) or "shared/Suite.lua"

dofile(uiPath)
local UI = _G.CreshSuiteUI

-- ============================================================
-- 1. Standalone load + idempotency
-- ============================================================
section("Standalone load + idempotency")

ok(UI ~= nil, "CreshSuiteUI global is set")
eq(type(UI.GetPalette), "function", "GetPalette present")
eq(type(UI.GetStateColor), "function", "GetStateColor present")
eq(type(UI.ApplyBackdrop), "function", "ApplyBackdrop present")
eq(type(UI.CreateButton), "function", "CreateButton present")
eq(type(UI.CreateTab), "function", "CreateTab present")
eq(type(UI.GetSafeFrameScale), "function", "GetSafeFrameScale present")
eq(type(UI.SavePosition), "function", "SavePosition present")
eq(type(UI.RestorePosition), "function", "RestorePosition present")
eq(type(UI.OnThemeChanged), "function", "OnThemeChanged present")

local uiRef = _G.CreshSuiteUI
dofile(uiPath)
ok(_G.CreshSuiteUI == uiRef, "re-loading CreshUI.lua is idempotent (same table)")

-- ============================================================
-- 2. Palette resolution
-- ============================================================
section("Palette resolution")

_G.CreshChatAPI = nil
local fb = UI:GetPalette()
ok(fb ~= nil, "GetPalette returns a table with no CreshChatAPI present")
eq(fb.accent[1], UI.FALLBACK.accent[1], "fallback accent matches UI.FALLBACK when CreshChatAPI absent")
eq(fb.text[1], UI.FALLBACK.text[1], "fallback text matches UI.FALLBACK when CreshChatAPI absent")

_G.CreshChatAPI = {
    GetActivePalette = function()
        return { accent = { 1, 0, 0, 1 }, panel = { 0.5, 0.5, 0.5, 1 } }
    end,
}
local active = UI:GetPalette()
eq(active.accent[1], 1, "GetPalette returns CreshChatAPI's accent when present")
eq(active.panel[1], 0.5, "GetPalette returns CreshChatAPI's panel when present")
eq(active.text[1], UI.FALLBACK.text[1], "GetPalette merges missing keys (text) from FALLBACK")
eq(active.muted[1], UI.FALLBACK.muted[1], "GetPalette merges missing keys (muted) from FALLBACK")

_G.CreshChatAPI = nil

-- ============================================================
-- 3. Semantic states
-- ============================================================
section("Semantic states")

local states = { "LOCKED", "AVAILABLE", "READY", "UNLOCKED", "EQUIPPED", "DISABLED" }
for _, state in ipairs(states) do
    eq(UI.STATE[state], state, ("UI.STATE.%s is defined"):format(state))
    local color = UI:GetStateColor(state)
    ok(color ~= nil, ("GetStateColor(%s) returns a color set"):format(state))
    ok(color.bg ~= nil and color.border ~= nil and color.text ~= nil, ("GetStateColor(%s) has bg/border/text"):format(state))
    ok(type(color.alpha) == "number", ("GetStateColor(%s) has a numeric alpha"):format(state))
end

local unknown = UI:GetStateColor("NOT_A_REAL_STATE")
ok(unknown ~= nil, "GetStateColor falls back safely for an unrecognized state")

-- ============================================================
-- 4. Button / tab / backdrop plumbing
-- ============================================================
section("Button / tab / backdrop plumbing")

local parent = newMockFrame("Frame", "Parent")
local clicked = false
local btn = UI:CreateButton(parent, "TEST", 80, 24, function() clicked = true end)
ok(btn ~= nil, "CreateButton returns a frame")
ok(btn.label ~= nil, "CreateButton attaches a label")
eq(btn.label._text, "TEST", "button label text is set")
btn._scripts["OnClick"](btn)
ok(clicked, "button OnClick callback fires")

UI:SetButtonState(btn, UI.STATE.DISABLED)
ok(btn.creshDisabled, "SetButtonState(DISABLED) marks the button disabled")
UI:SetButtonState(btn, UI.STATE.EQUIPPED)
ok(not btn.creshDisabled, "SetButtonState(EQUIPPED) re-enables the button")
ok(btn.creshActive, "SetButtonState(EQUIPPED) marks the button active")

local tab = UI:CreateTab(parent, "TAB", 70, 22, function() end)
UI:SetTabActive(tab, true)
ok(tab.creshActive == true, "SetTabActive(true) marks the tab active")
UI:SetTabActive(tab, false)
ok(tab.creshActive == false, "SetTabActive(false) clears the active flag")

-- ============================================================
-- 5. Safe screen-fit scaling
-- ============================================================
section("Safe screen-fit scaling")

local smallFrame = newMockFrame("Frame", "Small")
smallFrame:SetSize(300, 200)
eq(UI:GetSafeFrameScale(smallFrame, 1, 18), 1, "a frame well within screen bounds keeps the requested scale")

local hugeFrame = newMockFrame("Frame", "Huge")
hugeFrame:SetSize(4000, 4000)
local safeScale = UI:GetSafeFrameScale(hugeFrame, 1, 18)
ok(safeScale < 1, "an oversized frame is clamped below the requested scale")

local appliedScale = UI:ApplySafeFrameScale(hugeFrame, 1, 18)
eq(hugeFrame._scale, appliedScale, "ApplySafeFrameScale actually calls SetScale with the safe value")

-- ============================================================
-- 6. Owner-addon position persistence
-- ============================================================
section("Owner-addon position persistence")

local ownerDB = {}
local posFrame = newMockFrame("Frame", "PosFrame", _G.UIParent)
posFrame:SetPoint("CENTER", _G.UIParent, "CENTER", 40, -20)

ok(UI:SavePosition(ownerDB, "testWindow", posFrame), "SavePosition succeeds against a fresh ownerDB")
ok(type(ownerDB.uiPositions) == "table", "SavePosition creates ownerDB.uiPositions")
eq(ownerDB.uiPositions.testWindow.x, 40, "SavePosition records x offset")
eq(ownerDB.uiPositions.testWindow.y, -20, "SavePosition records y offset")

local restoreFrame = newMockFrame("Frame", "RestoreFrame", _G.UIParent)
ok(UI:RestorePosition(ownerDB, "testWindow", restoreFrame), "RestorePosition succeeds when a position was saved")
eq(restoreFrame._point.x, 40, "RestorePosition applies the saved x offset")
eq(restoreFrame._point.y, -20, "RestorePosition applies the saved y offset")

-- Migration path: no saved position yet, defaults supplied by the caller
-- (mirrors ProgressHub.lua reading its old CC.db.positions.progressHub value).
local emptyDB = {}
local defaults = { point = "TOPLEFT", relPoint = "TOPLEFT", x = 5, y = -5 }
local migratedFrame = newMockFrame("Frame", "MigratedFrame", _G.UIParent)
ok(UI:RestorePosition(emptyDB, "testWindow", migratedFrame, defaults), "RestorePosition falls back to supplied defaults")
eq(migratedFrame._point.point, "TOPLEFT", "RestorePosition used the default point when nothing was saved")
eq(migratedFrame._point.x, 5, "RestorePosition used the default x when nothing was saved")

local noopFrame = newMockFrame("Frame", "NoopFrame", _G.UIParent)
ok(not UI:RestorePosition(emptyDB, "missingKey", noopFrame), "RestorePosition returns false with nothing saved and no defaults")

-- ============================================================
-- 7. Theme-change notification
-- ============================================================
section("Theme-change notification")

_G.CreshSuite = nil
ok(UI:OnThemeChanged(function() end) == false, "OnThemeChanged is a safe no-op with no Suite bridge present")

dofile(suitePath)
local Suite = _G.CreshSuite
ok(Suite ~= nil, "Suite bridge loaded for theme-change test")

local themeChanged = false
ok(UI:OnThemeChanged(function() themeChanged = true end), "OnThemeChanged subscribes when the Suite bridge is present")
Suite:Publish("SUITE_THEME_CHANGED")
ok(themeChanged, "SUITE_THEME_CHANGED publish fires the OnThemeChanged callback")

-- ============================================================
-- 8. Window focus / bring-to-front
-- ============================================================
section("Window focus / bring-to-front")

eq(type(UI.FocusWindow), "function", "FocusWindow present")
eq(type(UI.InstallWindowFocus), "function", "InstallWindowFocus present")

local winA = newMockFrame("Frame", "WinA", _G.UIParent)
local winB = newMockFrame("Frame", "WinB", _G.UIParent)
UI:FocusWindow(winA)
UI:FocusWindow(winB)
eq(winA:GetFrameStrata(), "HIGH", "FocusWindow sets HIGH strata on a normal window")
ok(winB:GetFrameLevel() > winA:GetFrameLevel(), "the window focused more recently gets a higher frame level")
UI:FocusWindow(winA)
ok(winA:GetFrameLevel() > winB:GetFrameLevel(), "re-focusing an older window raises it above the other again")

local alwaysOnTop = newMockFrame("Frame", "AlwaysOnTop", _G.UIParent)
alwaysOnTop.creshAlwaysOnTop = true
UI:FocusWindow(alwaysOnTop)
eq(alwaysOnTop:GetFrameStrata(), "FULLSCREEN_DIALOG", "an always-on-top window is pinned to FULLSCREEN_DIALOG strata")
eq(alwaysOnTop:GetFrameLevel(), 7000, "an always-on-top window is pinned to a fixed high frame level")

local installed = newMockFrame("Frame", "Installed", _G.UIParent)
UI:InstallWindowFocus(installed)
ok(installed.creshWindowFocusInstalled, "InstallWindowFocus marks the frame as installed")
installed:FireHooks("OnMouseDown")
eq(installed:GetFrameStrata(), "HIGH", "the installed OnMouseDown hook calls FocusWindow")
local levelAfterClick = installed:GetFrameLevel()
UI:FocusWindow(winA) -- advance the shared counter so OnShow's raise is independently observable
installed:FireHooks("OnShow")
ok(installed:GetFrameLevel() > levelAfterClick, "the installed OnShow hook also calls FocusWindow, raising it again")

UI:InstallWindowFocus(installed)
local hookCountAfterSecondInstall = #(installed._hooks.OnMouseDown or {})
eq(hookCountAfterSecondInstall, 1, "InstallWindowFocus is idempotent -- a second call does not add duplicate hooks")

-- ============================================================
-- Summary
-- ============================================================
print(("\n=== Results: %d passed, %d failed ==="):format(PASS, FAIL))
if FAIL > 0 then os.exit(1) end
