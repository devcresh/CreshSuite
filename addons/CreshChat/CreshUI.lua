-- shared/CreshUI.lua  --  CreshSuite cross-addon UI service  --  Bridge v1
--
-- One physical copy of this file ships inside each suite addon's folder,
-- same convention as shared/Suite.lua and shared/Launcher.lua. Whichever of
-- CreshChat, CreshGames, or CreshCollect finishes loading first builds the
-- one shared _G.CreshSuiteUI table; every later load (the other two addons,
-- if present) is a no-op against the same table.
--
-- This file owns a small, consistent UI contract shared by all three
-- addons: palette resolution (via CreshChatAPI, never CreshChat's private
-- db table), semantic state colors, button/backdrop/tab/text primitives,
-- safe screen-fit scaling, minimal window chrome, owner-addon position
-- persistence, and theme-change notification. It intentionally does NOT
-- migrate any existing window this phase -- see addons/CreshCollect/
-- ProgressHub.lua for the one proof-of-contract conversion.
--
-- Compatible with WoW TBC Anniversary (Lua 5.1, no io/os/require).

local BRIDGE_VERSION = 1

-- ----------------------------------------------------------------------------
-- Idempotency guard (mirrors shared/Launcher.lua exactly)
-- ----------------------------------------------------------------------------
if _G.CreshSuiteUI then
    local existing = _G.CreshSuiteUI
    if type(existing.BRIDGE_VERSION) == "number" and existing.BRIDGE_VERSION == BRIDGE_VERSION then
        return -- already built by an earlier-loaded addon; expected for addons 2 and 3
    end
    -- Incompatible version already occupying _G.CreshSuiteUI. Keep the running copy.
    return
end

local UI = {}
_G.CreshSuiteUI = UI
UI.BRIDGE_VERSION = BRIDGE_VERSION

local floor, max, min = math.floor, math.max, math.min

-- ----------------------------------------------------------------------------
-- Standalone fallback palette -- the unified superset of every duplicated
-- FALLBACK table previously found in Games.lua, SoloGames.lua, BattlePass.lua,
-- ProgressHub.lua and ProgressOverview.lua. Values are unchanged from those
-- (they were already numerically identical across every copy).
-- ----------------------------------------------------------------------------
UI.FALLBACK = {
    panel       = { 0.022, 0.026, 0.034, 0.98 },
    panelSoft   = { 0.038, 0.044, 0.056, 0.98 },
    panelRaised = { 0.066, 0.074, 0.092, 1 },
    border      = { 0.105, 0.120, 0.145, 1 },
    accent      = { 0.130, 0.620, 0.950, 1 },
    incoming    = { 0.070, 0.080, 0.100, 0.98 },
    outgoing    = { 0.090, 0.430, 0.720, 0.98 },
    text        = { 0.93,  0.95,  0.98,  1 },
    muted       = { 0.56,  0.61,  0.69,  1 },
    green       = { 0.18,  0.78,  0.36,  1 },
    red         = { 0.92,  0.24,  0.25,  1 },
    gold        = { 0.95,  0.70,  0.20,  1 },
    quest       = { 1.00,  0.82,  0.26,  1 },
    blue        = { 0.13,  0.62,  0.95,  1 },
}

local BACKDROP = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    tile = false, edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
}

-- Semantic UI states shared by achievement/battle-pass/theme-style pickers.
UI.STATE = {
    LOCKED    = "LOCKED",
    AVAILABLE = "AVAILABLE",
    READY     = "READY",
    UNLOCKED  = "UNLOCKED",
    EQUIPPED  = "EQUIPPED",
    DISABLED  = "DISABLED",
}

-- ----------------------------------------------------------------------------
-- Palette
-- ----------------------------------------------------------------------------
-- Resolves the active theme colors via CreshChatAPI.GetActivePalette (a real
-- public API method, never CreshChat's private db table), merged over the
-- standalone FALLBACK so callers always get every key regardless of what
-- CreshChat's own palette happens to expose. Returns FALLBACK unchanged when
-- CreshChat is absent or the API method doesn't exist.

function UI:GetPalette()
    local api = _G.CreshChatAPI
    local active = (api and type(api.GetActivePalette) == "function") and api.GetActivePalette() or nil
    if type(active) ~= "table" then return self.FALLBACK end
    local merged = {}
    for key, value in pairs(self.FALLBACK) do merged[key] = value end
    for key, value in pairs(active) do merged[key] = value end
    return merged
end

-- Maps a semantic state to a { bg, border, text, alpha } color set. Unknown
-- states fall back to AVAILABLE so callers never get a nil result.
function UI:GetStateColor(state, palette)
    palette = palette or self:GetPalette()
    state = string.upper(tostring(state or "AVAILABLE"))
    if state == "LOCKED" then
        return { bg = palette.panelSoft, border = palette.border, text = palette.muted, alpha = 0.55 }
    elseif state == "DISABLED" then
        return { bg = palette.panelSoft, border = palette.border, text = palette.muted, alpha = 0.38 }
    elseif state == "READY" then
        return { bg = self:Darken(palette.accent, 0.22), border = palette.accent, text = palette.text, alpha = 1 }
    elseif state == "UNLOCKED" then
        return { bg = self:Darken(palette.green, 0.22), border = palette.green, text = palette.text, alpha = 1 }
    elseif state == "EQUIPPED" then
        return { bg = self:Darken(palette.gold, 0.18), border = palette.gold, text = palette.text, alpha = 1 }
    end
    -- AVAILABLE and anything unrecognized
    return { bg = palette.panelRaised, border = palette.border, text = palette.text, alpha = 1 }
end

-- ----------------------------------------------------------------------------
-- Color math
-- ----------------------------------------------------------------------------

function UI:Darken(color, amount)
    amount = tonumber(amount) or 0.18
    color = color or self.FALLBACK.panel
    return {
        max(0, (color[1] or 0) - amount),
        max(0, (color[2] or 0) - amount),
        max(0, (color[3] or 0) - amount),
        color[4] or 1,
    }
end

function UI:Brighten(color, amount)
    amount = tonumber(amount) or 0.10
    color = color or self.FALLBACK.panel
    return {
        min(1, (color[1] or 0) + amount),
        min(1, (color[2] or 0) + amount),
        min(1, (color[3] or 0) + amount),
        color[4] or 1,
    }
end

-- ----------------------------------------------------------------------------
-- Backdrop / text / buttons / tabs
-- ----------------------------------------------------------------------------

function UI:TemplateName()
    return _G.BackdropTemplateMixin and "BackdropTemplate" or nil
end

function UI:ApplyBackdrop(frame, bg, border)
    if not frame then return end
    if frame.SetBackdrop then frame:SetBackdrop(BACKDROP) end
    bg = bg or self.FALLBACK.panel
    border = border or self.FALLBACK.border
    if frame.SetBackdropColor then frame:SetBackdropColor(bg[1], bg[2], bg[3], bg[4] or 1) end
    if frame.SetBackdropBorderColor then frame:SetBackdropBorderColor(border[1], border[2], border[3], border[4] or 1) end
end

function UI:CreateText(parent, size, color, justify)
    local font = parent:CreateFontString(nil, "OVERLAY")
    font:SetFont(_G.STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", size or 11, "")
    color = color or self.FALLBACK.text
    font:SetTextColor(color[1], color[2], color[3], color[4] or 1)
    font:SetJustifyH(justify or "LEFT")
    font:SetJustifyV("MIDDLE")
    return font
end

function UI:CreateButton(parent, label, width, height, callback)
    local self_ = self
    local button = CreateFrame("Button", nil, parent, self:TemplateName())
    button:SetSize(width or 80, height or 24)
    local palette = self:GetPalette()
    self:ApplyBackdrop(button, palette.panelRaised, palette.border)
    button.label = self:CreateText(button, 9, palette.text, "CENTER")
    button.label:SetAllPoints()
    button.label:SetText(label or "")
    button.creshActive = false
    button.creshDisabled = false
    button:SetScript("OnClick", function(selfBtn, ...)
        if selfBtn.creshDisabled then return end
        if callback then callback(selfBtn, ...) end
    end)
    button:SetScript("OnEnter", function(selfBtn)
        if selfBtn.creshDisabled then return end
        local c = self_:GetPalette()
        self_:ApplyBackdrop(selfBtn, self_:Darken(c.accent, 0.22), c.accent)
    end)
    button:SetScript("OnLeave", function(selfBtn)
        local c = self_:GetPalette()
        local bg = selfBtn.creshActive and self_:Darken(c.accent, 0.22) or c.panelRaised
        local bd = selfBtn.creshActive and c.accent or c.border
        self_:ApplyBackdrop(selfBtn, bg, bd)
    end)
    return button
end

-- Drives a button's appearance from the shared semantic-state contract
-- instead of the ad hoc setButtonEnabled/setButtonAccent helpers each addon
-- used to define separately.
function UI:SetButtonState(button, state)
    if not button then return end
    local palette = self:GetPalette()
    local colors = self:GetStateColor(state, palette)
    button.creshState = state
    button.creshDisabled = (state == self.STATE.DISABLED or state == self.STATE.LOCKED)
    button.creshActive = (state == self.STATE.EQUIPPED or state == self.STATE.READY)
    self:ApplyBackdrop(button, colors.bg, colors.border)
    if button.label then
        button.label:SetTextColor(colors.text[1], colors.text[2], colors.text[3], colors.text[4] or 1)
    end
    if button.SetAlpha then button:SetAlpha(colors.alpha or 1) end
    if button.EnableMouse then button:EnableMouse(not button.creshDisabled) end
end

function UI:CreateTab(parent, label, width, height, callback)
    local tab = self:CreateButton(parent, label, width, height, callback)
    tab.creshIsTab = true
    return tab
end

function UI:SetTabActive(tab, active)
    if not tab then return end
    local c = self:GetPalette()
    local bg = active and self:Darken(c.accent, 0.22) or c.panelRaised
    local bd = active and c.accent or c.border
    self:ApplyBackdrop(tab, bg, bd)
    tab.creshActive = active and true or false
    if tab.label then
        local tc = active and c.accent or c.muted
        tab.label:SetTextColor(tc[1], tc[2], tc[3], 1)
    end
end

-- ----------------------------------------------------------------------------
-- Safe screen-fit scaling (ported from CreshChat/UI.lua's UI:GetSafeFrameScale
-- / UI:ApplySafeFrameScale, generalized to not depend on CC).
-- ----------------------------------------------------------------------------

function UI:GetSafeFrameScale(frame, requested, padding)
    requested = max(0.70, min(1.50, tonumber(requested) or 1))
    if not frame or not _G.UIParent then return requested end
    local width = tonumber(frame.GetWidth and frame:GetWidth()) or 0
    local height = tonumber(frame.GetHeight and frame:GetHeight()) or 0
    local screenWidth = tonumber(_G.UIParent.GetWidth and _G.UIParent:GetWidth()) or 0
    local screenHeight = tonumber(_G.UIParent.GetHeight and _G.UIParent:GetHeight()) or 0
    padding = tonumber(padding) or 18
    if width <= 0 or height <= 0 or screenWidth <= 0 or screenHeight <= 0 then return requested end
    local safetyFloor = 0.45
    local maxWidthScale = max(safetyFloor, (screenWidth - padding) / width)
    local maxHeightScale = max(safetyFloor, (screenHeight - padding) / height)
    return max(safetyFloor, min(requested, maxWidthScale, maxHeightScale))
end

function UI:ApplySafeFrameScale(frame, requested, padding)
    if not frame or not frame.SetScale then return tonumber(requested) or 1 end
    local safe = self:GetSafeFrameScale(frame, requested, padding)
    frame.creshBaseScale = safe
    frame:SetScale(safe)
    return safe
end

-- ----------------------------------------------------------------------------
-- Window focus / bring-to-front (ported from CreshChat/UI.lua's UI:FocusWindow
-- / UI:InstallWindowFocus, generalized to not depend on CC). A single shared
-- counter here -- rather than one counter per addon -- is what lets a window
-- opened in any one of the three addons correctly come to front above a
-- window from a different addon: CreshChat/UI.lua now delegates to this
-- implementation instead of keeping its own separate counter, so every
-- window in the suite that calls FocusWindow/InstallWindowFocus (whether via
-- _G.CreshSuiteUI directly, or via CC.UI in CreshChat) shares one z-order.
-- ----------------------------------------------------------------------------

local windowFocusCounter = 100

function UI:FocusWindow(frame)
    if not frame then return end
    if frame.creshAlwaysOnTop then
        if frame.SetFrameStrata then frame:SetFrameStrata("FULLSCREEN_DIALOG") end
        -- Leave enough frame-level headroom for child canvases, controls and
        -- backdrops. Pushing the parent to 9999 can flatten child ordering.
        if frame.SetFrameLevel then frame:SetFrameLevel(7000) end
        if frame.SetToplevel then frame:SetToplevel(true) end
        return
    end
    windowFocusCounter = windowFocusCounter + 1
    if windowFocusCounter > 9000 then windowFocusCounter = 100 end
    if frame.SetFrameStrata then frame:SetFrameStrata("HIGH") end
    if frame.SetFrameLevel then frame:SetFrameLevel(windowFocusCounter) end
end

-- Hooks a window so showing it or clicking it always brings it in front of
-- every other suite window, without each window builder having to remember
-- to call FocusWindow itself at both open-time and click-time.
function UI:InstallWindowFocus(frame)
    if not frame or frame.creshWindowFocusInstalled then return end
    frame.creshWindowFocusInstalled = true
    frame.creshFocusable = true
    if frame.HookScript then
        frame:HookScript("OnMouseDown", function() UI:FocusWindow(frame) end)
        frame:HookScript("OnShow", function() UI:FocusWindow(frame) end)
    end
end

-- ----------------------------------------------------------------------------
-- Minimal window chrome. Deliberately small: existing bespoke window
-- builders are not migrated this phase. Exists so the contract is testable
-- and available to new, low-risk windows going forward.
-- ----------------------------------------------------------------------------

function UI:CreateWindow(opts)
    opts = opts or {}
    local frame = CreateFrame("Frame", opts.name, opts.parent or _G.UIParent, self:TemplateName())
    frame:SetSize(opts.width or 300, opts.height or 200)
    local palette = self:GetPalette()
    self:ApplyBackdrop(frame, opts.bg or palette.panel, opts.border or palette.border)
    if frame.SetMovable then frame:SetMovable(opts.movable ~= false) end
    if frame.EnableMouse then frame:EnableMouse(true) end
    if frame.SetClampedToScreen then frame:SetClampedToScreen(true) end
    return frame
end

-- ----------------------------------------------------------------------------
-- Owner-addon position persistence. ownerDB is supplied by the caller (e.g.
-- _G.CreshCollectDB) so every addon persists into its OWN SavedVariables
-- table under a private "uiPositions" sub-table, instead of reaching into
-- another addon's db (the bug this replaces in ProgressHub.lua, which used
-- to save into CreshChat's CC.db.positions).
-- ----------------------------------------------------------------------------

function UI:SavePosition(ownerDB, key, frame)
    if type(ownerDB) ~= "table" or type(key) ~= "string" or key == "" or not frame then return false end
    if not frame.GetPoint then return false end
    ownerDB.uiPositions = type(ownerDB.uiPositions) == "table" and ownerDB.uiPositions or {}
    local point, _, relPoint, x, y = frame:GetPoint(1)
    ownerDB.uiPositions[key] = {
        point = point or "CENTER",
        relPoint = relPoint or point or "CENTER",
        x = floor(tonumber(x) or 0),
        y = floor(tonumber(y) or 0),
    }
    return true
end

-- Restores a previously saved position, falling back to `defaults` (same
-- shape: { point, relPoint, x, y }) when nothing has been saved yet.
function UI:RestorePosition(ownerDB, key, frame, defaults)
    if not frame or not frame.SetPoint or not frame.ClearAllPoints then return false end
    local saved = (type(ownerDB) == "table" and type(ownerDB.uiPositions) == "table")
        and ownerDB.uiPositions[key] or nil
    saved = saved or defaults
    if not saved then return false end
    local relativeTo = (frame.GetParent and frame:GetParent()) or _G.UIParent
    frame:ClearAllPoints()
    frame:SetPoint(saved.point or "CENTER", relativeTo, saved.relPoint or saved.point or "CENTER",
        tonumber(saved.x) or 0, tonumber(saved.y) or 0)
    return true
end

-- ----------------------------------------------------------------------------
-- Theme-change notification. Reuses the existing CreshSuite pub/sub bus
-- instead of inventing a second event system. Safe no-op when the Suite
-- bridge (or CreshChat, the only current publisher) is absent -- callers
-- keep using GetPalette()'s fallback in that case.
-- ----------------------------------------------------------------------------

function UI:OnThemeChanged(callback)
    if type(callback) ~= "function" then return false end
    local suite = _G.CreshSuite
    if not suite or type(suite.Subscribe) ~= "function" then return false end
    suite:Subscribe("SUITE_THEME_CHANGED", callback)
    return true
end
