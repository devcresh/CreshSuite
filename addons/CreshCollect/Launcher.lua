-- shared/Launcher.lua  --  CreshSuite launcher singleton  --  Bridge v1
--
-- One physical copy of this file ships inside each suite addon's folder,
-- same convention as shared/Suite.lua. Whichever of CreshChat, CreshGames,
-- or CreshCollect finishes loading first builds the one shared "C" launcher
-- bubble and its five destination satellites; every later load (the other
-- two addons, if present) is a no-op against the same table.
--
-- This file owns launcher CREATION, POSITIONING, ORIENTATION, and the
-- open/close ANIMATION -- the mechanics of "there is one C button and five
-- icons around it". It does NOT own destination ROUTING semantics (the five
-- entries below are ported unchanged from CreshChat's former registry) or
-- BUTTON VISUALS (the backdrop-behind-artwork look is carried over as-is);
-- both are explicitly deferred to a later phase.
--
-- Compatible with WoW TBC Anniversary (Lua 5.1, no io/os/require).

local BRIDGE_VERSION = 1

-- ----------------------------------------------------------------------------
-- Idempotency guard (mirrors shared/Suite.lua exactly)
-- ----------------------------------------------------------------------------
if _G.CreshSuiteLauncherAPI then
    local existing = _G.CreshSuiteLauncherAPI
    if type(existing.BRIDGE_VERSION) == "number" and existing.BRIDGE_VERSION == BRIDGE_VERSION then
        return -- already built by an earlier-loaded addon; expected for addons 2 and 3
    end
end

local Launcher = _G.CreshSuiteLauncherAPI or {}
_G.CreshSuiteLauncherAPI = Launcher
Launcher.BRIDGE_VERSION = BRIDGE_VERSION

local max = math.max
local min = math.min
local floor = math.floor
local tinsert = table.insert

-- ----------------------------------------------------------------------------
-- Persistent storage: reuse whichever suite addon's SavedVariables table
-- exists, in a fixed priority order, under its own "launcher" sub-table so
-- it can never collide with that addon's own settings. Looked up fresh every
-- call (never cached) -- by the time anything here actually reads/writes
-- (EnsureBuilt runs from each addon's own PLAYER_LOGIN handler), every
-- enabled addon's SavedVariables global is already populated regardless of
-- which addon happened to load first.
-- ----------------------------------------------------------------------------
local function getLauncherDB()
    local db = _G.CreshChatDB or _G.CreshGamesDB or _G.CreshCollectDB
    if not db then return nil end
    if type(db.launcher) ~= "table" then
        db.launcher = {}
        -- One-time, self-healing migration from CreshChat's pre-Phase-9
        -- launcher settings, so existing CreshChat users don't lose their
        -- saved position/orientation the first time this ships.
        local legacy = _G.CreshChatDB
        if legacy and legacy.ui and legacy.ui.launcherOrientation then
            db.launcher.orientation = legacy.ui.launcherOrientation
        end
        if legacy and legacy.positions and legacy.positions.bubble then
            db.launcher.position = legacy.positions.bubble
        end
    end
    return db.launcher
end

-- ----------------------------------------------------------------------------
-- Nil-safe lookup for a Suite service (identical contract to the helper this
-- replaces in CreshChat/UI.lua).
-- ----------------------------------------------------------------------------
local function getSuiteService(name)
    local suite = _G.CreshSuite
    if suite and type(suite.GetService) == "function" then
        return suite:GetService(name)
    end
    return nil
end

-- Nil-safe optional integration point: CreshChat, when present, gets to know
-- about launcher clicks/drags for its own notification/fade bookkeeping.
-- Absent CreshChat, this is simply a no-op.
local function markSuiteActive()
    local cc = _G.CreshChat
    if cc and cc.UI and cc.UI.MarkLauncherActive then cc.UI:MarkLauncherActive() end
end

-- ----------------------------------------------------------------------------
-- Destination registry -- ported unchanged from CreshChat/UI.lua's
-- LAUNCHER_DESTINATIONS. Same five keys, same IsAvailable/Open contracts,
-- same texture paths. Only relocated, not redesigned (routing/visual changes
-- are out of scope for this phase).
-- ----------------------------------------------------------------------------
local LAUNCHER_DESTINATIONS = {
    {
        key = "CHAT", buttonKey = "chatButton", frameName = "CreshSuiteLauncherChatButton", sortOrder = 1,
        label = "Cht", tooltipTitle = "CreshChat", tooltipText = "Open the CreshChat window",
        texture = "Interface\\AddOns\\CreshChat\\Media\\Icons\\CreshChat_Button_Transparent.tga",
        requirementText = "Requires CreshChat",
        IsAvailable = function()
            local cc = _G.CreshChat
            return cc and cc.IsFeatureEnabled and cc:IsFeatureEnabled("chat") == true
        end,
        Open = function()
            local cc = _G.CreshChat
            if cc and cc.UI and cc.UI.ToggleMain then
                cc.UI:ToggleMain()
                return true
            end
            return false
        end,
    },
    {
        key = "GAMES", buttonKey = "gamesButton", frameName = "CreshSuiteLauncherGamesButton", sortOrder = 2,
        label = "Gm", tooltipTitle = "Games Hub", tooltipText = "Open the CreshGames Solo Arcade",
        texture = "Interface\\AddOns\\CreshChat\\Media\\Icons\\Games_Button_Transparent.tga",
        requirementText = "Requires CreshGames",
        -- Routes to the Solo Games window specifically, not the multiplayer
        -- hub (OpenGames) -- that one only ever opens CreshChat's internal
        -- multiplayer drawer and requires CreshChat to be loaded at all.
        IsAvailable = function() return getSuiteService("OpenSoloGames") ~= nil end,
        Open = function()
            local svc = getSuiteService("OpenSoloGames")
            if not svc then return false end
            svc()
            return true
        end,
    },
    {
        key = "ACHIEVEMENTS", buttonKey = "achieveButton", frameName = "CreshSuiteLauncherAchievementsButton", sortOrder = 3,
        label = "Ach", tooltipTitle = "Achievements", tooltipText = "Open the Achievements window",
        texture = "Interface\\AddOns\\CreshChat\\Media\\Icons\\Achievements_Button_Transparent.tga",
        requirementText = "Requires CreshCollect",
        IsAvailable = function() return getSuiteService("OpenAchievements") ~= nil end,
        Open = function()
            local svc = getSuiteService("OpenAchievements")
            if not svc then return false end
            svc()
            return true
        end,
    },
    {
        key = "PROGRESS", buttonKey = "progressButton", frameName = "CreshSuiteLauncherProgressButton", sortOrder = 4,
        label = "Prg", tooltipTitle = "Progress Hub", tooltipText = "Open the Progress Hub overview",
        texture = "Interface\\AddOns\\CreshChat\\Media\\Icons\\ProgressHub_Button_Transparent.tga",
        requirementText = "Requires CreshCollect",
        IsAvailable = function() return getSuiteService("OpenProgressHub") ~= nil end,
        Open = function()
            local svc = getSuiteService("OpenProgressHub")
            if not svc then return false end
            svc()
            return true
        end,
    },
    {
        key = "CRESHQUEST", buttonKey = "questButton", frameName = "CreshSuiteLauncherQuestButton", sortOrder = 5,
        label = "Qst", tooltipTitle = "CreshQuest", tooltipText = "Open CreshQuest",
        texture = "Interface\\AddOns\\CreshChat\\Media\\Icons\\CreshQuest_Button_Transparent.tga",
        requirementText = "Requires CreshQuest",
        IsAvailable = function() return getSuiteService("OpenCreshQuest") ~= nil end,
        Open = function()
            local svc = getSuiteService("OpenCreshQuest")
            if not svc then return false end
            svc()
            return true
        end,
    },
}
Launcher._destinations = LAUNCHER_DESTINATIONS

-- Public registration boundary for a future phase: any addon can add (or
-- replace, by key) a destination. Not used by the five built-ins above yet
-- -- they stay hardcoded here until destination ownership itself moves --
-- but the entry point exists now so Phase 10+ has somewhere to call.
function Launcher:RegisterDestination(def)
    if type(def) ~= "table" or type(def.key) ~= "string" or def.key == "" then return false end
    def.key = string.upper(def.key)
    for index, existing in ipairs(LAUNCHER_DESTINATIONS) do
        if existing.key == def.key then
            LAUNCHER_DESTINATIONS[index] = def
            return true
        end
    end
    def.sortOrder = tonumber(def.sortOrder) or (#LAUNCHER_DESTINATIONS + 1)
    tinsert(LAUNCHER_DESTINATIONS, def)
    return true
end

function Launcher:GetDestination(key)
    key = string.upper(tostring(key or ""))
    for _, destination in ipairs(LAUNCHER_DESTINATIONS) do
        if destination.key == key then return destination end
    end
    return nil
end

function Launcher:CountAvailableDestinations()
    local count = 0
    for _, destination in ipairs(LAUNCHER_DESTINATIONS) do
        if destination.IsAvailable() then count = count + 1 end
    end
    return count
end

function Launcher:GetEffectiveDest()
    local db = getLauncherDB() or {}
    local dest = db.launcherDefault or "LAST"
    if dest == "LAST" then dest = db.lastLauncherDest end
    if dest then
        local destination = self:GetDestination(dest)
        if not destination or not destination.IsAvailable() then dest = nil end
    end
    if not dest then
        for _, destination in ipairs(LAUNCHER_DESTINATIONS) do
            if destination.IsAvailable() then dest = destination.key; break end
        end
        dest = dest or "SETTINGS"
    end
    return dest
end

-- Every destination click funnels through here: check availability, call
-- only that destination's own guarded Open(), and return immediately.
function Launcher:ToggleMode(dest)
    dest = string.upper(tostring(dest or "CHAT"))
    if dest == "SETTINGS" then
        local cc = _G.CreshChat
        if cc and cc.UI and cc.UI.OpenSettings then cc.UI:OpenSettings() end
        self:RefreshButtonStates()
        return
    end
    local destination = self:GetDestination(dest)
    if not destination then return end
    local db = getLauncherDB()
    if not destination.IsAvailable() then
        if _G.CreshChat and _G.CreshChat.Print then
            _G.CreshChat:Print(destination.requirementText or (destination.tooltipTitle .. " is not installed or loaded."))
        end
        self:RefreshButtonStates()
        return
    end
    if destination.Open() and db then
        db.lastLauncherDest = destination.key
    end
    self:RefreshButtonStates()
end

function Launcher:DefaultAction()
    self:ToggleMode(self:GetEffectiveDest())
end

-- ----------------------------------------------------------------------------
-- Orientation: HORIZONTAL (default) or VERTICAL. Validated and self-corrected
-- on every read, same idempotent validate-on-read contract as Phase 4.
-- ----------------------------------------------------------------------------
local VALID_ORIENTATIONS = { HORIZONTAL = true, VERTICAL = true }
local SATELLITE_BUTTON_SIZE = 36
local SATELLITE_GAP = 6

function Launcher:GetOrientation()
    local db = getLauncherDB()
    if not db then return "HORIZONTAL" end
    local saved = db.orientation
    if type(saved) == "string" then
        saved = string.upper(saved)
        if VALID_ORIENTATIONS[saved] then
            db.orientation = saved
            return saved
        end
    end
    db.orientation = "HORIZONTAL"
    return "HORIZONTAL"
end

function Launcher:SetOrientation(orientation)
    orientation = string.upper(tostring(orientation or "HORIZONTAL"))
    if not VALID_ORIENTATIONS[orientation] then orientation = "HORIZONTAL" end
    local db = getLauncherDB()
    if db then db.orientation = orientation end
    self:PositionButtons()
end

-- Pure geometry (unchanged from Phase 4): given the bubble's screen-space
-- edges, screen size, orientation, and required pixel extent, choose the
-- expansion direction. No frames touched -- independently testable.
function Launcher:CalculateExpansionDirection(bubbleLeft, bubbleRight, bubbleTop, bubbleBottom, screenWidth, screenHeight, orientation, requiredExtent)
    screenWidth = tonumber(screenWidth) or 1
    screenHeight = tonumber(screenHeight) or 1
    requiredExtent = max(0, tonumber(requiredExtent) or 0)
    orientation = VALID_ORIENTATIONS[orientation] and orientation or "HORIZONTAL"

    if orientation == "VERTICAL" then
        local roomBelow = tonumber(bubbleBottom) or 0
        local roomAbove = screenHeight - (tonumber(bubbleTop) or screenHeight)
        if roomBelow >= requiredExtent then return "DOWN" end
        if roomAbove >= requiredExtent then return "UP" end
        return roomBelow >= roomAbove and "DOWN" or "UP"
    end

    local roomRight = screenWidth - (tonumber(bubbleRight) or 0)
    local roomLeft = tonumber(bubbleLeft) or 0
    if roomRight >= requiredExtent then return "RIGHT" end
    if roomLeft >= requiredExtent then return "LEFT" end
    return roomRight >= roomLeft and "RIGHT" or "LEFT"
end

-- Pure geometry (unchanged from Phase 5): the Nth satellite's anchor,
-- relative to the bubble, scalable by progress for the animation.
function Launcher:GetAnchorOffset(direction, index)
    local extent = index * (SATELLITE_BUTTON_SIZE + SATELLITE_GAP) - SATELLITE_BUTTON_SIZE
    if direction == "RIGHT" then return "LEFT", "RIGHT", extent, 0
    elseif direction == "LEFT" then return "RIGHT", "LEFT", -extent, 0
    elseif direction == "DOWN" then return "TOP", "BOTTOM", 0, -extent
    else return "BOTTOM", "TOP", 0, extent end -- UP
end

function Launcher:GetLayoutDirection(count)
    local orientation = self:GetOrientation()
    local screenWidth = _G.UIParent:GetWidth() or 1
    local screenHeight = _G.UIParent:GetHeight() or 1
    local requiredExtent = count * (SATELLITE_BUTTON_SIZE + SATELLITE_GAP)
    local bubble = self.bubble
    return self:CalculateExpansionDirection(
        bubble and bubble.GetLeft and bubble:GetLeft(),
        bubble and bubble.GetRight and bubble:GetRight(),
        bubble and bubble.GetTop and bubble:GetTop(),
        bubble and bubble.GetBottom and bubble:GetBottom(),
        screenWidth, screenHeight, orientation, requiredExtent)
end

function Launcher:GetOrderedVisibleButtons()
    local ordered = {}
    for _, destination in ipairs(LAUNCHER_DESTINATIONS) do
        local button = self.buttons and self.buttons[destination.buttonKey]
        if button and button:IsShown() then tinsert(ordered, button) end
    end
    return ordered
end

function Launcher:PositionButtons()
    if not self.bubble then return end
    local ordered = self:GetOrderedVisibleButtons()
    if #ordered > 0 then
        local direction = self:GetLayoutDirection(#ordered)
        for index, button in ipairs(ordered) do
            local point, relativePoint, x, y = self:GetAnchorOffset(direction, index)
            button:ClearAllPoints()
            button:SetPoint(point, self.bubble, relativePoint, x, y)
            button:SetAlpha(1)
        end
    end
    -- CreshChat's composer anchors above the tallest currently-visible point
    -- of this launcher; nothing here knows what a "composer" is, so just
    -- nudge CreshChat (if present) to recompute its own position whenever
    -- our layout changes.
    local cc = _G.CreshChat
    if cc and cc.UI and cc.UI.PositionQuickInput then cc.UI:PositionQuickInput() end
end

-- Screen resolution and UI scale changes both invalidate the edge-fit
-- decision baked into the current satellite layout -- recompute once
-- whenever either fires, rather than every frame.
local layoutWatcher = CreateFrame("Frame")
layoutWatcher:RegisterEvent("UI_SCALE_CHANGED")
layoutWatcher:RegisterEvent("DISPLAY_SIZE_CHANGED")
layoutWatcher:SetScript("OnEvent", function()
    if Launcher.bubble then Launcher:PositionButtons() end
end)

function Launcher:GetTopFrame()
    local topFrame, topValue = self.bubble, self.bubble and self.bubble:GetTop()
    for _, destination in ipairs(LAUNCHER_DESTINATIONS) do
        local satellite = self.buttons and self.buttons[destination.buttonKey]
        if satellite and satellite:IsShown() and satellite.GetTop then
            local satelliteTop = satellite:GetTop()
            if satelliteTop and (not topValue or satelliteTop > topValue) then
                topFrame, topValue = satellite, satelliteTop
            end
        end
    end
    return topFrame
end

function Launcher:GetBubble() return self.bubble end
function Launcher:GetButton(key) return self.buttons and self.buttons[key] end

-- ----------------------------------------------------------------------------
-- Visibility / expand-collapse state (instant path; see the animation
-- controller below for the click-driven animated path).
-- ----------------------------------------------------------------------------
function Launcher:IsRowVisible(revealed, chatOn)
    if chatOn == nil then
        local cc = _G.CreshChat
        chatOn = cc and cc.IsFeatureEnabled and cc:IsFeatureEnabled("chat")
    end
    if not chatOn then return true end
    return revealed == true
end

function Launcher:SetShown(shown)
    shown = shown and true or false
    if self.bubble then self.bubble:SetShown(shown) end
    local cc = _G.CreshChat
    local chatOn = cc and cc.IsFeatureEnabled and cc:IsFeatureEnabled("chat")
    local revealed = self.expanded == true
    local rowVisible = shown and self:IsRowVisible(revealed, chatOn)
    for _, destination in ipairs(LAUNCHER_DESTINATIONS) do
        local button = self.buttons and self.buttons[destination.buttonKey]
        if button then
            local destinationVisible = rowVisible and (destination.key ~= "CHAT" or chatOn)
            button:SetShown(destinationVisible == true)
        end
    end
    self:PositionButtons()
    self:RefreshButtonStates()
end

function Launcher:RefreshButtonStates()
    for _, destination in ipairs(LAUNCHER_DESTINATIONS) do
        local button = self.buttons and self.buttons[destination.buttonKey]
        if button then
            local available = destination.IsAvailable()
            if button.iconTexture then
                if available then
                    button.iconTexture:SetVertexColor(1, 1, 1, 1)
                else
                    button.iconTexture:SetVertexColor(0.4, 0.4, 0.4, 0.6)
                end
            end
        end
    end
    -- CreshChat, when present, additionally highlights whichever destination
    -- is currently the active/open one -- optional decoration, not core.
    local cc = _G.CreshChat
    if cc and cc.UI and cc.UI.RefreshLauncherActiveHighlight then
        cc.UI:RefreshLauncherActiveHighlight()
    end
end

-- ----------------------------------------------------------------------------
-- Open/close animation (unchanged from Phase 5).
-- ----------------------------------------------------------------------------
local ANIM_DURATION = 0.20
local ANIM_INTERACTIVE_THRESHOLD = 0.6
local function easeOutCubic(t) return 1 - ((1 - t) * (1 - t) * (1 - t)) end
local function easeInCubic(t) return t * t * t end

function Launcher:GetAnimationTargets()
    local cc = _G.CreshChat
    local chatOn = cc and cc.IsFeatureEnabled and cc:IsFeatureEnabled("chat")
    if not chatOn then return {} end
    local targets = {}
    for _, destination in ipairs(LAUNCHER_DESTINATIONS) do
        local button = self.buttons and self.buttons[destination.buttonKey]
        if button then tinsert(targets, button) end
    end
    return targets
end

function Launcher:StopAnimDriver()
    if self.animDriver then self.animDriver:SetScript("OnUpdate", nil) end
end

function Launcher:FinishAnimation(opening)
    local anim = self.anim
    if anim then
        anim.active = false
        for i = 1, anim.count do
            local item = anim.items[i]
            local button = item.button
            if opening then
                button:SetAlpha(1)
                button:EnableMouse(true)
            else
                button:SetAlpha(0)
                button:Hide()
                button:EnableMouse(false)
            end
        end
    end
    self:StopAnimDriver()
    self:PositionButtons()
    self:RefreshButtonStates()
end

function Launcher:TickAnimation(elapsed)
    local anim = self.anim
    if not anim or not anim.active then
        self:StopAnimDriver()
        return
    end
    local dt = (tonumber(elapsed) or 0) / ANIM_DURATION
    if dt <= 0 then return end
    local opening = anim.target == 1
    if opening then anim.t = min(1, anim.t + dt) else anim.t = max(0, anim.t - dt) end
    local eased = max(0, min(1, opening and easeOutCubic(anim.t) or easeInCubic(anim.t)))
    for i = 1, anim.count do
        local item = anim.items[i]
        local button = item.button
        button:SetAlpha(eased)
        button:SetPoint(item.point, self.bubble, item.relativePoint, item.finalX * eased, item.finalY * eased)
        if opening and eased >= ANIM_INTERACTIVE_THRESHOLD then button:EnableMouse(true) end
    end
    local done = (opening and anim.t >= 1) or (not opening and anim.t <= 0)
    if done then self:FinishAnimation(opening) end
end

function Launcher:AnimateReveal(opening)
    local targets = self:GetAnimationTargets()
    if #targets == 0 or not self.bubble then
        self:SetShown(true)
        return
    end

    local anim = self.anim
    if not anim then
        anim = { items = {}, active = false, t = 0, target = 0, count = 0 }
        self.anim = anim
    end

    if not anim.active then
        if not opening then
            local anyShown = false
            for _, button in ipairs(targets) do
                if button:IsShown() then anyShown = true; break end
            end
            if not anyShown then
                self:SetShown(true)
                return
            end
        end
        anim.t = opening and 0 or 1
    end
    anim.target = opening and 1 or 0

    local wasActive = anim.active
    local direction = self:GetLayoutDirection(#targets)
    local items = anim.items
    for index, button in ipairs(targets) do
        local point, relativePoint, finalX, finalY = self:GetAnchorOffset(direction, index)
        local item = items[index]
        if not item then item = {}; items[index] = item end
        item.button, item.point, item.relativePoint, item.finalX, item.finalY = button, point, relativePoint, finalX, finalY
        if not wasActive then
            button:ClearAllPoints()
            button:SetPoint(point, self.bubble, relativePoint, 0, 0)
            button:Show()
            button:EnableMouse(false)
        end
    end
    for i = #targets + 1, #items do items[i] = nil end
    anim.count = #targets
    anim.active = true

    if not self.animDriver then self.animDriver = CreateFrame("Frame") end
    self.animDriver:SetScript("OnUpdate", function(_, elapsed) Launcher:TickAnimation(elapsed) end)
end

function Launcher:RefreshExpansion()
    if not self.visible then
        self:SetShown(false)
        return
    end
    self:AnimateReveal(self.expanded == true)
end

-- Left-click handler for the C bubble: with <=1 available destination,
-- opens it directly; with 2+, toggles the animated reveal (maximize) /
-- collapse (minimize) of the satellite row.
function Launcher:PrimaryClick()
    local destCount = self:CountAvailableDestinations()
    if destCount <= 1 then
        self.expanded = false
        self:RefreshExpansion()
        self:DefaultAction()
        return
    end
    local wasExpanded = self.expanded == true
    self.expanded = not wasExpanded
    self:RefreshExpansion()
    if wasExpanded then self:DefaultAction() end
end

function Launcher:SatelliteClick(dest)
    self.expanded = false
    self:ToggleMode(dest)
    self:RefreshExpansion()
end

-- ----------------------------------------------------------------------------
-- Bubble + satellite creation. Idempotent: safe to call from every suite
-- addon's own init; only the first call actually builds anything.
-- ----------------------------------------------------------------------------
local function applyBasicBackdrop(frame, r, g, b, a)
    if frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        frame:SetBackdropColor(r, g, b, a)
        frame:SetBackdropBorderColor(0.18, 0.21, 0.28, 1)
    else
        if not frame.creshBackground then
            frame.creshBackground = frame:CreateTexture(nil, "BACKGROUND")
            frame.creshBackground:SetAllPoints()
        end
        frame.creshBackground:SetColorTexture(r, g, b, a)
    end
end

local function templateName()
    if _G.BackdropTemplateMixin then return "BackdropTemplate" end
    return nil
end

local function makeSatelliteButton(destination)
    local button = CreateFrame("Button", destination.frameName, UIParent, templateName())
    button:SetSize(SATELLITE_BUTTON_SIZE, SATELLITE_BUTTON_SIZE)
    button:SetFrameStrata("HIGH")
    button:SetClampedToScreen(true)
    -- No backdrop: the artwork is the whole button, it already has its own
    -- circular border baked in -- a filled panel behind it just shows as an
    -- unwanted box around the icon.
    button.iconTexture = button:CreateTexture(nil, "ARTWORK")
    button.iconTexture:SetPoint("CENTER", button, "CENTER", 0, 0)
    button.iconTexture:SetSize(26, 26)
    button.iconTexture:SetTexture(destination.texture)
    button:SetScript("OnClick", function() Launcher:SatelliteClick(destination.key) end)
    button:SetScript("OnEnter", function(selfButton)
        -- Hover feedback without a background box: a small pop on the icon itself.
        selfButton.iconTexture:SetSize(29, 29)
        _G.GameTooltip:SetOwner(selfButton, "ANCHOR_LEFT")
        _G.GameTooltip:AddLine(destination.tooltipTitle, 1, 1, 1)
        _G.GameTooltip:AddLine(destination.tooltipText, 0.75, 0.8, 0.9)
        if not destination.IsAvailable() and destination.requirementText then
            _G.GameTooltip:AddLine(destination.requirementText, 1, 0.4, 0.4)
        end
        _G.GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function(selfButton)
        selfButton.iconTexture:SetSize(26, 26)
        Launcher:RefreshButtonStates()
        _G.GameTooltip:Hide()
    end)
    return button
end

local function getLauncherTitle()
    if _G.CreshChat then return "CreshChat" end
    if _G.CreshGames then return "CreshGames" end
    if _G.CreshCollect then return "CreshCollect" end
    return "CreshSuite"
end

function Launcher:EnsureBuilt()
    if self.bubble then return end
    local ok, err = pcall(function() self:_EnsureBuiltUnsafe() end)
    if not ok then
        self.bubble = nil -- let a later call retry instead of getting stuck half-built
        print("|cffff4040CreshSuite Launcher failed to build:|r " .. tostring(err))
    end
end

function Launcher:_EnsureBuiltUnsafe()
    local bubble = CreateFrame("Button", "CreshSuiteLauncherBubble", UIParent, templateName())
    bubble:SetSize(46, 46)
    bubble:SetFrameStrata("HIGH")
    bubble:SetClampedToScreen(true)
    bubble:SetMovable(true)
    bubble:RegisterForDrag("RightButton")
    applyBasicBackdrop(bubble, 0.110, 0.430, 0.950, 1)
    self.bubble = bubble

    bubble.icon = bubble:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bubble.icon:SetFont(STANDARD_TEXT_FONT, 17, "")
    bubble.icon:SetAllPoints()
    bubble.icon:SetJustifyH("CENTER")
    bubble.icon:SetJustifyV("MIDDLE")
    bubble.icon:SetTextColor(0.92, 0.94, 0.98, 1)
    bubble.icon:SetText("C")

    -- Notification outline/glow textures (ported from CreshChat/UI.lua's
    -- former BuildBubble): created hidden here so CreshChat's own
    -- notification system can decorate this shared bubble when present,
    -- without this module needing to know anything about notifications.
    local top = bubble:CreateTexture(nil, "OVERLAY")
    top:SetPoint("TOPLEFT", bubble, "TOPLEFT", 0, 0)
    top:SetPoint("TOPRIGHT", bubble, "TOPRIGHT", 0, 0)
    top:SetHeight(3)
    local bottom = bubble:CreateTexture(nil, "OVERLAY")
    bottom:SetPoint("BOTTOMLEFT", bubble, "BOTTOMLEFT", 0, 0)
    bottom:SetPoint("BOTTOMRIGHT", bubble, "BOTTOMRIGHT", 0, 0)
    bottom:SetHeight(3)
    local left = bubble:CreateTexture(nil, "OVERLAY")
    left:SetPoint("TOPLEFT", bubble, "TOPLEFT", 0, -3)
    left:SetPoint("BOTTOMLEFT", bubble, "BOTTOMLEFT", 0, 3)
    left:SetWidth(3)
    local right = bubble:CreateTexture(nil, "OVERLAY")
    right:SetPoint("TOPRIGHT", bubble, "TOPRIGHT", 0, -3)
    right:SetPoint("BOTTOMRIGHT", bubble, "BOTTOMRIGHT", 0, 3)
    right:SetWidth(3)
    bubble.notificationOutline = { top, bottom, left, right }
    for _, edge in ipairs(bubble.notificationOutline) do edge:Hide() end

    local glowTop = bubble:CreateTexture(nil, "OVERLAY")
    glowTop:SetPoint("BOTTOMLEFT", bubble, "TOPLEFT", -4, -2)
    glowTop:SetPoint("BOTTOMRIGHT", bubble, "TOPRIGHT", 4, -2)
    glowTop:SetHeight(8)
    local glowBottom = bubble:CreateTexture(nil, "OVERLAY")
    glowBottom:SetPoint("TOPLEFT", bubble, "BOTTOMLEFT", -4, 2)
    glowBottom:SetPoint("TOPRIGHT", bubble, "BOTTOMRIGHT", 4, 2)
    glowBottom:SetHeight(8)
    local glowLeft = bubble:CreateTexture(nil, "OVERLAY")
    glowLeft:SetPoint("TOPRIGHT", bubble, "TOPLEFT", 2, 4)
    glowLeft:SetPoint("BOTTOMRIGHT", bubble, "BOTTOMLEFT", 2, -4)
    glowLeft:SetWidth(8)
    local glowRight = bubble:CreateTexture(nil, "OVERLAY")
    glowRight:SetPoint("TOPLEFT", bubble, "TOPRIGHT", -2, 4)
    glowRight:SetPoint("BOTTOMLEFT", bubble, "BOTTOMRIGHT", -2, -4)
    glowRight:SetWidth(8)
    bubble.notificationGlow = { glowTop, glowBottom, glowLeft, glowRight }
    for _, edge in ipairs(bubble.notificationGlow) do
        if edge.SetBlendMode then edge:SetBlendMode("ADD") end
        edge:Hide()
    end

    bubble:SetScript("OnClick", function()
        markSuiteActive()
        if _G.IsShiftKeyDown and _G.IsShiftKeyDown() then
            local cc = _G.CreshChat
            if cc and cc.UI and cc.UI.OpenSettings then cc.UI:OpenSettings() end
            return
        end
        Launcher:PrimaryClick()
    end)
    bubble:SetScript("OnDragStart", function(selfBubble)
        markSuiteActive()
        selfBubble:StartMoving()
    end)
    bubble:SetScript("OnDragStop", function(selfBubble)
        selfBubble:StopMovingOrSizing()
        local point, _, relativePoint, x, y = selfBubble:GetPoint(1)
        local db = getLauncherDB()
        if db then
            db.position = {
                point = point or "CENTER",
                relativePoint = relativePoint or point or "CENTER",
                x = floor((x or 0) + 0.5),
                y = floor((y or 0) + 0.5),
            }
        end
        Launcher:PositionButtons()
        -- CreshChat-specific extras (composer, combat panel, whisper alert,
        -- toasts) reposition themselves off this same bubble when present.
        local cc = _G.CreshChat
        if cc and cc.UI then
            if cc.UI.PositionCombatPanel then cc.UI:PositionCombatPanel() end
            if cc.UI.PositionQuickInput then cc.UI:PositionQuickInput() end
            if cc.UI.PositionWhisperDockAlert then cc.UI:PositionWhisperDockAlert() end
            if cc.UI.RepositionToasts then cc.UI:RepositionToasts() end
        end
        markSuiteActive()
    end)
    bubble:SetScript("OnEnter", function(selfBubble)
        markSuiteActive()
        local destCount = Launcher:CountAvailableDestinations()
        _G.GameTooltip:SetOwner(selfBubble, "ANCHOR_LEFT")
        _G.GameTooltip:AddLine(getLauncherTitle(), 1, 1, 1)
        if destCount >= 2 then
            if Launcher.expanded then
                _G.GameTooltip:AddLine("Left-click: open default destination", 0.75, 0.8, 0.9)
            else
                _G.GameTooltip:AddLine("Left-click: show quick-access buttons", 0.75, 0.8, 0.9)
            end
        else
            local onlyDestination = Launcher:GetDestination(Launcher:GetEffectiveDest())
            if onlyDestination then
                _G.GameTooltip:AddLine("Left-click: " .. onlyDestination.tooltipText, 0.75, 0.8, 0.9)
            end
        end
        _G.GameTooltip:AddLine("Right-drag: move this launcher", 0.75, 0.8, 0.9)
        _G.GameTooltip:AddLine("Shift+click: open Settings", 0.75, 0.8, 0.9)
        _G.GameTooltip:Show()
    end)
    bubble:SetScript("OnLeave", function()
        markSuiteActive()
        _G.GameTooltip:Hide()
    end)

    self.buttons = {}
    for _, destination in ipairs(LAUNCHER_DESTINATIONS) do
        self.buttons[destination.buttonKey] = makeSatelliteButton(destination)
    end

    -- Apply saved position. With no saved position yet (first-ever build for
    -- this SavedVariables set -- notably whenever CreshChat, and therefore
    -- its legacy position to migrate from, is absent) always default to the
    -- bottom-left corner.
    local db = getLauncherDB()
    local saved = db and db.position
    bubble:ClearAllPoints()
    if saved then
        bubble:SetPoint(saved.point or "CENTER", UIParent, saved.relativePoint or saved.point or "CENTER", saved.x or 0, saved.y or 0)
    else
        bubble:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 40, 40)
    end

    self.visible = true
    self:PositionButtons()
    self:SetShown(true)
end

-- ----------------------------------------------------------------------------
-- Temporary diagnostic slash command (Phase 9 bugfix aid): prints every
-- piece of state relevant to "why doesn't the bubble show" in one shot, so
-- it doesn't have to be typed out freehand in chat. Safe to leave in --
-- harmless if never used. Remove once the launcher-visibility issue is
-- confirmed fixed.
-- ----------------------------------------------------------------------------
_G.SLASH_CRESHLAUNCHERDEBUG1 = "/creshlauncherdebug"
_G.SlashCmdList = _G.SlashCmdList or {}
_G.SlashCmdList["CRESHLAUNCHERDEBUG"] = function()
    local function say(msg) (DEFAULT_CHAT_FRAME or _G.ChatFrame1):AddMessage("|cff40ffb0[CreshLauncherDebug]|r " .. tostring(msg)) end
    say("CreshSuiteLauncherAPI = " .. tostring(_G.CreshSuiteLauncherAPI))
    if not _G.CreshSuiteLauncherAPI then return end
    local api = _G.CreshSuiteLauncherAPI
    say("bubble = " .. tostring(api.bubble))
    if not api.bubble then return end
    local b = api.bubble
    local okShown, shown = pcall(function() return b:IsShown() end)
    local okVisible, visible = pcall(function() return b:IsVisible() end)
    local okAlpha, alpha = pcall(function() return b:GetAlpha() end)
    local okScale, scale = pcall(function() return b:GetScale() end)
    local okStrata, strata = pcall(function() return b:GetFrameStrata() end)
    local okW, w = pcall(function() return b:GetWidth() end)
    local okH, h = pcall(function() return b:GetHeight() end)
    local okLeft, left = pcall(function() return b:GetLeft() end)
    local okTop, top = pcall(function() return b:GetTop() end)
    local okPoint, p1, p2, p3, p4, p5 = pcall(function() return b:GetPoint(1) end)
    say(("IsShown=%s  IsVisible=%s  Alpha=%s  Scale=%s  Strata=%s")
        :format(tostring(okShown and shown), tostring(okVisible and visible), tostring(okAlpha and alpha),
            tostring(okScale and scale), tostring(okStrata and strata)))
    say(("Width=%s  Height=%s  Left=%s  Top=%s")
        :format(tostring(okW and w), tostring(okH and h), tostring(okLeft and left), tostring(okTop and top)))
    if okPoint then
        say(("Point: %s, relativeTo=%s, relativePoint=%s, x=%s, y=%s"):format(tostring(p1), tostring(p2), tostring(p3), tostring(p4), tostring(p5)))
    else
        say("GetPoint(1) failed: " .. tostring(p1))
    end
    say(("UIParent size: %s x %s"):format(tostring(UIParent:GetWidth()), tostring(UIParent:GetHeight())))
    local buttonCount = 0
    for _ in pairs(api.buttons or {}) do buttonCount = buttonCount + 1 end
    say("buttons table entries = " .. tostring(buttonCount))
end
