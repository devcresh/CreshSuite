local _, CC = ...
if not CC then
    return
end

local UI = { version = CC.version }
UI.friendsDirectoryTab = "GAME"
CC.UI = UI
if CC.RegisterModule then CC:RegisterModule("UI", UI) end

local floor = math.floor
local max = math.max
local min = math.min
local tinsert = table.insert
local tremove = table.remove
local sort = table.sort
local sin = math.sin
local pi = math.pi

local BUILD_VERSION = tostring(CC.version or "0.0.0")
local BUILD_LABEL = "v" .. (string.match(BUILD_VERSION, "^(%d+%.%d+%.%d+)") or BUILD_VERSION)

local COLORS = {
    panel = { 0.055, 0.067, 0.090, 0.98 },
    panelSoft = { 0.080, 0.094, 0.122, 0.98 },
    panelRaised = { 0.105, 0.120, 0.155, 1 },
    border = { 0.18, 0.21, 0.28, 1 },
    blue = { 0.110, 0.430, 0.950, 1 },
    blueHover = { 0.170, 0.500, 1.000, 1 },
    incoming = { 0.145, 0.165, 0.210, 1 },
    text = { 0.92, 0.94, 0.98, 1 },
    muted = { 0.57, 0.62, 0.70, 1 },
    green = { 0.22, 0.78, 0.45, 1 },
    red = { 0.95, 0.28, 0.31, 1 },
    combatOut = { 0.98, 0.78, 0.30, 1 },
    combatIn = { 1.00, 0.38, 0.38, 1 },
    combatHeal = { 0.32, 0.92, 0.50, 1 },
    combatUtility = { 0.55, 0.72, 1.00, 1 },
    quest = { 0.95, 0.76, 0.22, 1 },
}
UI.COLORS = COLORS

local CONSOLE_TAB_DEFINITIONS = {
    { key = "FRIENDS", label = "FRIENDS", title = "Friends", subtitle = "Battle.net and character friends only" },
    { key = "WHISPER", label = "WHISPERS", title = "Whispers", subtitle = "Private conversations" },
    { key = "GUILD", label = "GUILD", title = "Guild Chat", subtitle = "Guild and officer messages" },
    { key = "GENERAL", label = "GENERAL", title = "General Chat", subtitle = "All public, party, raid and local channels" },
    { key = "QUEST", label = "QUESTS", title = "Quests", subtitle = "Quest-giver conversations by zone" },
    { key = "COMBAT", label = "COMBAT", title = "Combat Log", subtitle = "Live personal combat activity" },
    { key = "TRADE", label = "TRADE", title = "Trade Chat", subtitle = "Trade channel messages" },
    { key = "PARTY", label = "PARTY", title = "Party Chat", subtitle = "Party and party-leader messages" },
    { key = "RAID", label = "RAID", title = "Raid Chat", subtitle = "Raid and raid-leader messages" },
    { key = "INSTANCE", label = "INSTANCE", title = "Instance Chat", subtitle = "Instance-group messages" },
    { key = "LFG", label = "LFG", title = "Looking For Group", subtitle = "LookingForGroup channel messages" },
    { key = "SAY", label = "SAY", title = "Say Chat", subtitle = "Nearby /say messages" },
    { key = "YELL", label = "YELL", title = "Yell Chat", subtitle = "Nearby /yell messages" },
    { key = "EMOTE", label = "EMOTE", title = "Emotes", subtitle = "Nearby emote messages" },
    { key = "LOCALDEFENSE", label = "LOCAL", title = "Local Defense", subtitle = "LocalDefense channel messages" },
}
UI.CONSOLE_TAB_DEFINITIONS = CONSOLE_TAB_DEFINITIONS

local CONSOLE_TAB_LOOKUP = {}
for index, definition in ipairs(CONSOLE_TAB_DEFINITIONS) do
    definition.order = index
    CONSOLE_TAB_LOOKUP[definition.key] = definition
end
UI.CONSOLE_TAB_LOOKUP = CONSOLE_TAB_LOOKUP

local GENERAL_FEED_MODES = {
    GENERAL = true, TRADE = true, PARTY = true, RAID = true, RAID_WARNING = true,
    INSTANCE = true, BATTLEGROUND = true, LFG = true, SAY = true, YELL = true,
    EMOTE = true, LOCALDEFENSE = true,
}
UI.GENERAL_FEED_MODES = GENERAL_FEED_MODES

-- Guild is deliberately independent from the selected global theme. This keeps
-- every Guild surface recognisably green even when Messenger, Discord, Bronze,
-- High Contrast or a custom colour preset is active.
local GUILD_THEME = {
    panel = { 0.018, 0.075, 0.038, 0.985 },
    panelSoft = { 0.026, 0.115, 0.055, 0.985 },
    panelRaised = { 0.040, 0.180, 0.082, 1.000 },
    border = { 0.090, 0.390, 0.185, 1.000 },
    accent = { 0.180, 0.780, 0.365, 1.000 },
    accentHover = { 0.260, 0.900, 0.455, 1.000 },
    incoming = { 0.032, 0.145, 0.068, 1.000 },
    outgoing = { 0.055, 0.315, 0.135, 1.000 },
    officer = { 0.390, 0.920, 0.555, 1.000 },
    muted = { 0.585, 0.790, 0.650, 1.000 },
}
UI.GUILD_THEME = GUILD_THEME

-- All normal CreshChat windows share one click-to-front layer. Notification cards
-- remain on TOOLTIP/FULLSCREEN_DIALOG, while Settings uses an explicit always-on-top layer.
UI.windowFocusCounter = 100
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
    self.windowFocusCounter = (self.windowFocusCounter or 100) + 1
    if self.windowFocusCounter > 9000 then self.windowFocusCounter = 100 end
    if frame.SetFrameStrata then frame:SetFrameStrata("HIGH") end
    if frame.SetFrameLevel then frame:SetFrameLevel(self.windowFocusCounter) end
end

function UI:InstallWindowFocus(frame)
    if not frame or frame.creshWindowFocusInstalled then return end
    frame.creshWindowFocusInstalled = true
    frame.creshFocusable = true
    if frame.HookScript then
        frame:HookScript("OnMouseDown", function() UI:FocusWindow(frame) end)
        frame:HookScript("OnShow", function() UI:FocusWindow(frame) end)
    end
end

function UI:GetSafeFrameScale(frame, requested, padding)
    requested = max(0.70, min(1.50, tonumber(requested) or 1))
    if not frame or not UIParent then return requested end
    local width = tonumber(frame.GetWidth and frame:GetWidth()) or 0
    local height = tonumber(frame.GetHeight and frame:GetHeight()) or 0
    local screenWidth = tonumber(UIParent.GetWidth and UIParent:GetWidth()) or 0
    local screenHeight = tonumber(UIParent.GetHeight and UIParent:GetHeight()) or 0
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

local function copyColor(target, source)
    if type(target) ~= "table" or type(source) ~= "table" then return end
    target[1] = tonumber(source[1]) or target[1]
    target[2] = tonumber(source[2]) or target[2]
    target[3] = tonumber(source[3]) or target[3]
    target[4] = tonumber(source[4]) or target[4] or 1
end

local THEME_PRESETS = {
    CRESH_MINIMAL = {
        panel = { 0.022, 0.026, 0.034, 0.96 }, panelSoft = { 0.038, 0.044, 0.056, 0.96 },
        panelRaised = { 0.066, 0.074, 0.092, 0.98 }, border = { 0.105, 0.120, 0.145, 0.95 },
        accent = { 0.130, 0.620, 0.950, 1.00 }, incoming = { 0.070, 0.080, 0.100, 0.98 },
        outgoing = { 0.090, 0.430, 0.720, 0.98 },
    },
    ELVUI_CHARCOAL = {
        panel = { 0.025, 0.025, 0.025, 0.98 }, panelSoft = { 0.055, 0.055, 0.055, 0.98 },
        panelRaised = { 0.090, 0.090, 0.090, 1.00 }, border = { 0.160, 0.160, 0.160, 1.00 },
        accent = { 0.180, 0.700, 0.850, 1.00 }, incoming = { 0.085, 0.085, 0.085, 1.00 },
        outgoing = { 0.120, 0.480, 0.560, 1.00 },
    },
    WIM_CLASSIC = {
        panel = { 0.055, 0.045, 0.070, 0.98 }, panelSoft = { 0.090, 0.075, 0.110, 0.98 },
        panelRaised = { 0.130, 0.105, 0.155, 1.00 }, border = { 0.250, 0.190, 0.300, 1.00 },
        accent = { 0.700, 0.420, 0.950, 1.00 }, incoming = { 0.115, 0.090, 0.135, 1.00 },
        outgoing = { 0.480, 0.260, 0.720, 1.00 },
    },
    PRAT_GLASS = {
        panel = { 0.015, 0.020, 0.025, 0.82 }, panelSoft = { 0.030, 0.040, 0.050, 0.78 },
        panelRaised = { 0.055, 0.070, 0.082, 0.88 }, border = { 0.100, 0.210, 0.240, 0.90 },
        accent = { 0.130, 0.820, 0.900, 1.00 }, incoming = { 0.035, 0.050, 0.060, 0.90 },
        outgoing = { 0.060, 0.440, 0.500, 0.92 },
    },
    GINGI_NEON = {
        panel = { 0.015, 0.017, 0.022, 0.99 }, panelSoft = { 0.032, 0.035, 0.045, 0.99 },
        panelRaised = { 0.055, 0.060, 0.078, 1.00 }, border = { 0.110, 0.125, 0.165, 1.00 },
        accent = { 0.090, 0.900, 0.720, 1.00 }, incoming = { 0.045, 0.052, 0.066, 1.00 },
        outgoing = { 0.060, 0.520, 0.410, 1.00 },
    },
    NORD_FROST = {
        panel = { 0.105, 0.125, 0.160, 0.98 }, panelSoft = { 0.135, 0.160, 0.200, 0.98 },
        panelRaised = { 0.180, 0.210, 0.255, 1.00 }, border = { 0.285, 0.335, 0.405, 1.00 },
        accent = { 0.535, 0.750, 0.815, 1.00 }, incoming = { 0.155, 0.185, 0.230, 1.00 },
        outgoing = { 0.365, 0.545, 0.675, 1.00 },
    },
    CLASSIC_BRONZE = {
        panel = { 0.055, 0.040, 0.025, 0.98 }, panelSoft = { 0.090, 0.065, 0.035, 0.98 },
        panelRaised = { 0.135, 0.095, 0.050, 1.00 }, border = { 0.330, 0.235, 0.105, 1.00 },
        accent = { 0.950, 0.650, 0.180, 1.00 }, incoming = { 0.115, 0.080, 0.045, 1.00 },
        outgoing = { 0.560, 0.330, 0.090, 1.00 },
    },
    WOW_CLASSIC = {
        panel = { 0.205, 0.135, 0.060, 0.985 }, panelSoft = { 0.275, 0.180, 0.075, 0.985 },
        panelRaised = { 0.355, 0.235, 0.100, 1.000 }, border = { 0.820, 0.610, 0.225, 1.000 },
        accent = { 1.000, 0.790, 0.260, 1.000 }, incoming = { 0.245, 0.155, 0.065, 0.985 },
        outgoing = { 0.090, 0.285, 0.535, 0.985 },
    },
    TUKUI_OBSIDIAN = {
        panel = { 0.012, 0.014, 0.017, 0.990 }, panelSoft = { 0.026, 0.030, 0.034, 0.990 },
        panelRaised = { 0.048, 0.054, 0.060, 1.000 }, border = { 0.095, 0.115, 0.120, 1.000 },
        accent = { 0.160, 0.760, 0.720, 1.000 }, incoming = { 0.038, 0.043, 0.048, 1.000 },
        outgoing = { 0.055, 0.390, 0.365, 1.000 },
    },
    LS_GLASS = {
        panel = { 0.008, 0.012, 0.018, 0.700 }, panelSoft = { 0.018, 0.025, 0.035, 0.650 },
        panelRaised = { 0.040, 0.052, 0.068, 0.790 }, border = { 0.180, 0.230, 0.290, 0.760 },
        accent = { 0.500, 0.810, 1.000, 1.000 }, incoming = { 0.030, 0.040, 0.055, 0.760 },
        outgoing = { 0.080, 0.330, 0.500, 0.820 },
    },
    CHATTYNATOR_SLATE = {
        panel = { 0.055, 0.065, 0.080, 0.985 }, panelSoft = { 0.078, 0.092, 0.112, 0.985 },
        panelRaised = { 0.110, 0.128, 0.155, 1.000 }, border = { 0.185, 0.215, 0.260, 1.000 },
        accent = { 0.360, 0.680, 0.960, 1.000 }, incoming = { 0.095, 0.110, 0.135, 1.000 },
        outgoing = { 0.185, 0.460, 0.760, 1.000 },
    },
    SPARTAN_STEEL = {
        panel = { 0.035, 0.050, 0.075, 0.990 }, panelSoft = { 0.055, 0.080, 0.115, 0.990 },
        panelRaised = { 0.085, 0.115, 0.155, 1.000 }, border = { 0.390, 0.440, 0.500, 1.000 },
        accent = { 0.930, 0.620, 0.190, 1.000 }, incoming = { 0.070, 0.095, 0.130, 1.000 },
        outgoing = { 0.150, 0.350, 0.580, 1.000 },
    },
    NDUI_AZURE = {
        panel = { 0.018, 0.028, 0.040, 0.990 }, panelSoft = { 0.030, 0.050, 0.070, 0.990 },
        panelRaised = { 0.050, 0.080, 0.105, 1.000 }, border = { 0.080, 0.205, 0.290, 1.000 },
        accent = { 0.050, 0.650, 0.960, 1.000 }, incoming = { 0.040, 0.065, 0.090, 1.000 },
        outgoing = { 0.030, 0.350, 0.610, 1.000 },
    },
    BENIK_TEAL = {
        panel = { 0.025, 0.035, 0.055, 0.990 }, panelSoft = { 0.040, 0.060, 0.085, 0.990 },
        panelRaised = { 0.065, 0.090, 0.120, 1.000 }, border = { 0.130, 0.260, 0.315, 1.000 },
        accent = { 0.090, 0.790, 0.820, 1.000 }, incoming = { 0.055, 0.075, 0.100, 1.000 },
        outgoing = { 0.050, 0.430, 0.480, 1.000 },
    },
    ZLR = {
        -- Arena-tech palette: blackened steel, cold gunmetal, oxidised red-orange and electric blue.
        panel = { 0.012, 0.016, 0.020, 0.995 }, panelSoft = { 0.050, 0.060, 0.070, 0.992 },
        panelRaised = { 0.095, 0.105, 0.115, 1.000 }, border = { 0.315, 0.345, 0.365, 1.000 },
        accent = { 0.940, 0.205, 0.035, 1.000 }, incoming = { 0.030, 0.082, 0.112, 1.000 },
        outgoing = { 0.405, 0.060, 0.028, 1.000 },
    },
    ICQ = {
        panel = { 0.030, 0.045, 0.035, 0.990 }, panelSoft = { 0.055, 0.080, 0.060, 0.990 },
        panelRaised = { 0.085, 0.125, 0.090, 1.000 }, border = { 0.220, 0.390, 0.225, 1.000 },
        accent = { 0.310, 0.850, 0.230, 1.000 }, incoming = { 0.070, 0.105, 0.075, 1.000 },
        outgoing = { 0.160, 0.500, 0.130, 1.000 },
    },
    MSN_MESSENGER = {
        panel = { 0.025, 0.060, 0.115, 0.990 }, panelSoft = { 0.045, 0.095, 0.165, 0.990 },
        panelRaised = { 0.075, 0.140, 0.225, 1.000 }, border = { 0.285, 0.590, 0.900, 1.000 },
        accent = { 0.090, 0.650, 1.000, 1.000 }, incoming = { 0.060, 0.115, 0.190, 1.000 },
        outgoing = { 0.055, 0.385, 0.720, 1.000 },
    },
    WINDOWS_31 = {
        panel = { 0.000, 0.000, 0.500, 0.995 }, panelSoft = { 0.060, 0.060, 0.250, 0.995 },
        panelRaised = { 0.360, 0.360, 0.390, 1.000 }, border = { 0.760, 0.760, 0.800, 1.000 },
        accent = { 0.000, 0.760, 0.760, 1.000 }, incoming = { 0.120, 0.120, 0.300, 1.000 },
        outgoing = { 0.000, 0.440, 0.520, 1.000 },
    },
    WINDOWS_95 = {
        panel = { 0.015, 0.190, 0.190, 0.995 }, panelSoft = { 0.055, 0.115, 0.125, 0.995 },
        panelRaised = { 0.300, 0.315, 0.335, 1.000 }, border = { 0.720, 0.730, 0.750, 1.000 },
        accent = { 0.000, 0.500, 0.760, 1.000 }, incoming = { 0.075, 0.135, 0.145, 1.000 },
        outgoing = { 0.000, 0.340, 0.520, 1.000 },
    },
    UBUNTU = {
        panel = { 0.105, 0.028, 0.090, 0.995 }, panelSoft = { 0.165, 0.050, 0.125, 0.995 },
        panelRaised = { 0.235, 0.075, 0.165, 1.000 }, border = { 0.500, 0.170, 0.285, 1.000 },
        accent = { 0.925, 0.315, 0.080, 1.000 }, incoming = { 0.190, 0.060, 0.145, 1.000 },
        outgoing = { 0.640, 0.175, 0.055, 1.000 },
    },
    HIGH_CONTRAST = {
        panel = { 0.000, 0.000, 0.000, 1.00 }, panelSoft = { 0.035, 0.035, 0.035, 1.00 },
        panelRaised = { 0.075, 0.075, 0.075, 1.00 }, border = { 0.500, 0.500, 0.500, 1.00 },
        accent = { 1.000, 0.800, 0.000, 1.00 }, incoming = { 0.090, 0.090, 0.090, 1.00 },
        outgoing = { 0.120, 0.390, 0.800, 1.00 },
    },
    MESSENGER = {
        panel = { 0.035, 0.043, 0.060, 0.98 }, panelSoft = { 0.060, 0.071, 0.094, 0.98 },
        panelRaised = { 0.095, 0.108, 0.140, 1.00 }, border = { 0.150, 0.175, 0.230, 1.00 },
        accent = { 0.000, 0.520, 1.000, 1.00 }, incoming = { 0.120, 0.137, 0.175, 1.00 },
        outgoing = { 0.000, 0.480, 0.950, 1.00 },
    },
    SNAPCHAT = {
        panel = { 0.045, 0.047, 0.052, 0.98 }, panelSoft = { 0.075, 0.078, 0.086, 0.98 },
        panelRaised = { 0.115, 0.118, 0.128, 1.00 }, border = { 0.220, 0.225, 0.240, 1.00 },
        accent = { 1.000, 0.865, 0.000, 1.00 }, incoming = { 0.120, 0.124, 0.135, 1.00 },
        outgoing = { 0.860, 0.110, 0.260, 1.00 },
    },
    DISCORD = {
        panel = { 0.040, 0.043, 0.052, 0.99 }, panelSoft = { 0.068, 0.073, 0.088, 0.99 },
        panelRaised = { 0.105, 0.112, 0.137, 1.00 }, border = { 0.150, 0.160, 0.190, 1.00 },
        accent = { 0.345, 0.396, 0.949, 1.00 }, incoming = { 0.095, 0.102, 0.125, 1.00 },
        outgoing = { 0.345, 0.396, 0.949, 1.00 },
    },
    MIDNIGHT = {
        panel = { 0.015, 0.020, 0.030, 0.99 }, panelSoft = { 0.035, 0.045, 0.062, 0.99 },
        panelRaised = { 0.060, 0.075, 0.100, 1.00 }, border = { 0.090, 0.130, 0.180, 1.00 },
        accent = { 0.100, 0.720, 0.850, 1.00 }, incoming = { 0.050, 0.065, 0.088, 1.00 },
        outgoing = { 0.075, 0.500, 0.680, 1.00 },
    },
}

-- Merge the extended v0.3.25 library after the original presets so legacy keys
-- retain their exact appearance while the full list reaches 100 named themes.
if CC.ThemeLibrary and CC.ThemeLibrary.presets then
    for key, preset in pairs(CC.ThemeLibrary.presets) do THEME_PRESETS[key] = preset end
end

local THEME_CHROME = {
    WOW_CLASSIC = {
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    },
    ZLR = {
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 10,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    },
    WINDOWS_31 = {
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    },
    WINDOWS_95 = {
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 10,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    },
}
UI.THEME_PRESETS = THEME_PRESETS
UI.THEME_CHROME = THEME_CHROME

function UI:GetThemeChrome()
    local preset = CC.db and CC.db.ui and string.upper(tostring(CC.db.ui.themePreset or "")) or ""
    return THEME_CHROME[preset]
end


function UI:IsZLRTheme()
    local preset = CC.db and CC.db.ui and string.upper(tostring(CC.db.ui.themePreset or "")) or ""
    return preset == "ZLR"
end

function UI:GetLauncherBaseText()
    return self:IsZLRTheme() and "q3a" or "C"
end

function UI:ApplyLauncherTextStyle(fontString, mainLogo)
    if not fontString or not fontString.SetFont then return end
    local size = self:IsZLRTheme() and (mainLogo and 9 or 10) or (mainLogo and 14 or 17)
    fontString:SetFont(_G.STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", size, "")
end

local function isGuildColorReference(color)
    if type(color) ~= "table" then return false end
    for _, guildColor in pairs(GUILD_THEME) do
        if color == guildColor then return true end
    end
    return false
end

local function overwriteColor(target, source)
    if type(target) ~= "table" or type(source) ~= "table" then return end
    for index = 1, 4 do target[index] = source[index] or target[index] end
end

local GUILD_THEME_PRESETS = {
    VERDANT = {
        panel = { 0.018, 0.075, 0.038, 0.985 }, panelSoft = { 0.026, 0.115, 0.055, 0.985 },
        panelRaised = { 0.040, 0.180, 0.082, 1.000 }, border = { 0.090, 0.390, 0.185, 1.000 },
        accent = { 0.180, 0.780, 0.365, 1.000 }, accentHover = { 0.260, 0.900, 0.455, 1.000 },
        incoming = { 0.032, 0.145, 0.068, 1.000 }, outgoing = { 0.055, 0.315, 0.135, 1.000 },
        officer = { 0.390, 0.920, 0.555, 1.000 }, muted = { 0.585, 0.790, 0.650, 1.000 },
    },
    ALLIANCE = {
        panel = { 0.018, 0.045, 0.095, 0.990 }, panelSoft = { 0.026, 0.075, 0.145, 0.990 },
        panelRaised = { 0.040, 0.115, 0.220, 1.000 }, border = { 0.530, 0.430, 0.130, 1.000 },
        accent = { 0.130, 0.520, 0.960, 1.000 }, accentHover = { 0.250, 0.670, 1.000, 1.000 },
        incoming = { 0.030, 0.095, 0.185, 1.000 }, outgoing = { 0.055, 0.270, 0.620, 1.000 },
        officer = { 0.910, 0.735, 0.250, 1.000 }, muted = { 0.570, 0.715, 0.880, 1.000 },
    },
    HORDE = {
        panel = { 0.080, 0.018, 0.018, 0.990 }, panelSoft = { 0.125, 0.026, 0.025, 0.990 },
        panelRaised = { 0.200, 0.040, 0.035, 1.000 }, border = { 0.430, 0.115, 0.080, 1.000 },
        accent = { 0.850, 0.145, 0.105, 1.000 }, accentHover = { 1.000, 0.265, 0.180, 1.000 },
        incoming = { 0.155, 0.032, 0.030, 1.000 }, outgoing = { 0.430, 0.060, 0.045, 1.000 },
        officer = { 0.965, 0.510, 0.180, 1.000 }, muted = { 0.850, 0.570, 0.520, 1.000 },
    },
    EMERALD = {
        panel = { 0.012, 0.060, 0.040, 0.990 }, panelSoft = { 0.020, 0.100, 0.065, 0.990 },
        panelRaised = { 0.030, 0.155, 0.095, 1.000 }, border = { 0.070, 0.390, 0.220, 1.000 },
        accent = { 0.100, 0.880, 0.440, 1.000 }, accentHover = { 0.210, 1.000, 0.560, 1.000 },
        incoming = { 0.020, 0.125, 0.075, 1.000 }, outgoing = { 0.035, 0.390, 0.185, 1.000 },
        officer = { 0.330, 1.000, 0.640, 1.000 }, muted = { 0.520, 0.825, 0.650, 1.000 },
    },
    JADE_NIGHT = {
        panel = { 0.010, 0.035, 0.035, 0.995 }, panelSoft = { 0.015, 0.065, 0.060, 0.995 },
        panelRaised = { 0.020, 0.105, 0.095, 1.000 }, border = { 0.055, 0.285, 0.250, 1.000 },
        accent = { 0.080, 0.720, 0.590, 1.000 }, accentHover = { 0.150, 0.870, 0.710, 1.000 },
        incoming = { 0.018, 0.090, 0.080, 1.000 }, outgoing = { 0.025, 0.285, 0.235, 1.000 },
        officer = { 0.250, 0.920, 0.770, 1.000 }, muted = { 0.440, 0.720, 0.670, 1.000 },
    },
    MOSS_STONE = {
        panel = { 0.060, 0.070, 0.045, 0.990 }, panelSoft = { 0.090, 0.105, 0.065, 0.990 },
        panelRaised = { 0.125, 0.145, 0.085, 1.000 }, border = { 0.310, 0.360, 0.190, 1.000 },
        accent = { 0.530, 0.710, 0.260, 1.000 }, accentHover = { 0.650, 0.830, 0.350, 1.000 },
        incoming = { 0.105, 0.120, 0.070, 1.000 }, outgoing = { 0.275, 0.380, 0.120, 1.000 },
        officer = { 0.750, 0.880, 0.430, 1.000 }, muted = { 0.680, 0.735, 0.525, 1.000 },
    },
    SAGE_PARCHMENT = {
        panel = { 0.170, 0.175, 0.120, 0.985 }, panelSoft = { 0.220, 0.225, 0.150, 0.985 },
        panelRaised = { 0.285, 0.285, 0.185, 1.000 }, border = { 0.390, 0.420, 0.220, 1.000 },
        accent = { 0.470, 0.680, 0.290, 1.000 }, accentHover = { 0.590, 0.800, 0.390, 1.000 },
        incoming = { 0.235, 0.240, 0.155, 1.000 }, outgoing = { 0.330, 0.450, 0.185, 1.000 },
        officer = { 0.720, 0.825, 0.470, 1.000 }, muted = { 0.760, 0.780, 0.610, 1.000 },
    },
    FEL_GREEN = {
        panel = { 0.020, 0.035, 0.010, 0.995 }, panelSoft = { 0.035, 0.065, 0.015, 0.995 },
        panelRaised = { 0.060, 0.110, 0.020, 1.000 }, border = { 0.230, 0.460, 0.060, 1.000 },
        accent = { 0.470, 0.950, 0.080, 1.000 }, accentHover = { 0.620, 1.000, 0.170, 1.000 },
        incoming = { 0.045, 0.090, 0.018, 1.000 }, outgoing = { 0.205, 0.470, 0.035, 1.000 },
        officer = { 0.710, 1.000, 0.310, 1.000 }, muted = { 0.600, 0.760, 0.420, 1.000 },
    },
    ALLIANCE_ARCANE = {
        panel = { 0.015, 0.030, 0.085, 0.995 }, panelSoft = { 0.022, 0.052, 0.130, 0.995 },
        panelRaised = { 0.035, 0.085, 0.195, 1.000 }, border = { 0.370, 0.500, 0.760, 1.000 },
        accent = { 0.190, 0.660, 1.000, 1.000 }, accentHover = { 0.320, 0.780, 1.000, 1.000 },
        incoming = { 0.025, 0.070, 0.165, 1.000 }, outgoing = { 0.060, 0.310, 0.690, 1.000 },
        officer = { 0.960, 0.790, 0.270, 1.000 }, muted = { 0.560, 0.700, 0.900, 1.000 },
    },
    HORDE_IRON = {
        panel = { 0.055, 0.020, 0.018, 0.995 }, panelSoft = { 0.090, 0.030, 0.025, 0.995 },
        panelRaised = { 0.135, 0.045, 0.035, 1.000 }, border = { 0.350, 0.300, 0.280, 1.000 },
        accent = { 0.850, 0.180, 0.110, 1.000 }, accentHover = { 1.000, 0.300, 0.180, 1.000 },
        incoming = { 0.110, 0.035, 0.030, 1.000 }, outgoing = { 0.390, 0.065, 0.045, 1.000 },
        officer = { 1.000, 0.500, 0.180, 1.000 }, muted = { 0.800, 0.585, 0.540, 1.000 },
    },
    DEEP_FOREST = {
        panel = { 0.010, 0.050, 0.052, 0.990 }, panelSoft = { 0.015, 0.085, 0.082, 0.990 },
        panelRaised = { 0.025, 0.135, 0.125, 1.000 }, border = { 0.060, 0.330, 0.280, 1.000 },
        accent = { 0.085, 0.720, 0.560, 1.000 }, accentHover = { 0.150, 0.880, 0.690, 1.000 },
        incoming = { 0.020, 0.115, 0.105, 1.000 }, outgoing = { 0.035, 0.300, 0.245, 1.000 },
        officer = { 0.240, 0.900, 0.720, 1.000 }, muted = { 0.480, 0.760, 0.700, 1.000 },
    },
}
if CC.ThemeLibrary and CC.ThemeLibrary.guildPresets then
    for key, preset in pairs(CC.ThemeLibrary.guildPresets) do GUILD_THEME_PRESETS[key] = preset end
end
UI.GUILD_THEME_PRESETS = GUILD_THEME_PRESETS
UI.GUILD_THEME_DISPLAY = {
    AUTO = "Auto faction", VERDANT = "Verdant guild", EMERALD = "Emerald hall",
    JADE_NIGHT = "Jade night", MOSS_STONE = "Moss and stone", SAGE_PARCHMENT = "Sage parchment",
    FEL_GREEN = "Fel green", DEEP_FOREST = "Deep forest", ALLIANCE = "Alliance royal",
    ALLIANCE_ARCANE = "Alliance arcane", HORDE = "Horde crimson", HORDE_IRON = "Horde iron",
    CUSTOM = "Custom guild colours",
}
if CC.ThemeLibrary and CC.ThemeLibrary.guildDisplay then
    for key, label in pairs(CC.ThemeLibrary.guildDisplay) do UI.GUILD_THEME_DISPLAY[key] = label end
end

-- Extended Guild palettes that mirror a premium global theme use the same
-- ownership requirement. Base Guild presets remain free.
UI.GUILD_THEME_UNLOCK_KEYS = {
    FOR_ALLIANCE_GUILD = "FOR_THE_ALLIANCE",
    FOR_HORDE_GUILD = "FOR_THE_HORDE",
    FORSAKEN_GUILD = "UNDEAD_FORSAKEN",
    STORMWIND_GUILD = "STORMWIND",
    ORGRIMMAR_GUILD = "ORGRIMMAR",
    SILVERMOON_GUILD = "SILVERMOON",
}

function UI:GetGuildThemeUnlockKey(name)
    name = string.upper(tostring(name or "AUTO"))
    return self.GUILD_THEME_UNLOCK_KEYS and self.GUILD_THEME_UNLOCK_KEYS[name] or nil
end

function UI:IsGuildThemeUnlocked(name)
    local unlockKey = self:GetGuildThemeUnlockKey(name)
    if not unlockKey then return true end
    if not CC.BattlePass or not CC.BattlePass.IsThemeUnlocked then return true end
    return CC.BattlePass:IsThemeUnlocked(unlockKey)
end

function UI:IsThemePresetUnlocked(name)
    name = string.upper(tostring(name or "CRESH_MINIMAL"))
    if name == "CUSTOM" then return true end
    if not CC.BattlePass or not CC.BattlePass.IsThemeUnlocked then return true end
    return CC.BattlePass:IsThemeUnlocked(name)
end

function UI:ResolveGuildThemePreset(name)
    name = string.upper(tostring(name or "AUTO"))
    if name == "AUTO" then
        local faction = type(UnitFactionGroup) == "function" and UnitFactionGroup("player") or nil
        if faction == "Alliance" then return "ALLIANCE" end
        if faction == "Horde" then return "HORDE" end
        return "VERDANT"
    end
    if name == "CUSTOM" then return "CUSTOM" end
    if GUILD_THEME_PRESETS[name] then return name end
    return "VERDANT"
end

function UI:SyncGuildTheme()
    if not CC.db or not CC.db.ui or not CC.db.colors then return end
    CC.db.colors.guild = CC.db.colors.guild or {}
    local selected = string.upper(tostring(CC.db.ui.guildThemePreset or "AUTO"))
    if not self:IsGuildThemeUnlocked(selected) then
        selected = "AUTO"
        CC.db.ui.guildThemePreset = selected
    end
    local resolved = self:ResolveGuildThemePreset(selected)
    local source = resolved == "CUSTOM" and CC.db.colors.guild or GUILD_THEME_PRESETS[resolved]
    source = source or GUILD_THEME_PRESETS.VERDANT
    for key, value in pairs(source) do
        GUILD_THEME[key] = GUILD_THEME[key] or {}
        overwriteColor(GUILD_THEME[key], value)
    end
end

function UI:ApplyGuildThemePreset(name)
    if not CC.db or not CC.db.ui or not CC.db.colors then return false end
    name = string.upper(tostring(name or "AUTO"))
    if not self:IsGuildThemeUnlocked(name) then
        local unlockKey = self:GetGuildThemeUnlockKey(name)
        local info = unlockKey and CC.BattlePass and CC.BattlePass.GetThemeInfo and CC.BattlePass:GetThemeInfo(unlockKey) or nil
        if CC.Print then CC:Print((info and info.name or unlockKey or name) .. " is locked. Unlock it before using the matching Guild theme.") end
        if unlockKey and CC.BattlePass and CC.BattlePass.OpenThemeUnlock then
            CC.BattlePass:OpenThemeUnlock(unlockKey)
        elseif self.OpenGameDrawer then
            self:OpenGameDrawer("THEMES")
        end
        return false
    end
    CC.db.ui.guildThemePreset = name
    local resolved = self:ResolveGuildThemePreset(name)
    if resolved ~= "CUSTOM" then
        CC.db.colors.guild = CC.db.colors.guild or {}
        for key, value in pairs(GUILD_THEME_PRESETS[resolved] or GUILD_THEME_PRESETS.VERDANT) do
            CC.db.colors.guild[key] = CC.db.colors.guild[key] or {}
            overwriteColor(CC.db.colors.guild[key], value)
        end
    end
    self:SyncGuildTheme()
    self:ApplyVisualSettings()
    return true
end

local THEME_PREVIEW_COLOR_KEYS = { "panel", "panelSoft", "panelRaised", "border", "accent", "incoming", "outgoing" }

local function snapshotThemePreviewColors()
    local snapshot = {}
    for _, key in ipairs(THEME_PREVIEW_COLOR_KEYS) do
        local source = CC.db and CC.db.colors and CC.db.colors[key]
        if type(source) == "table" then
            snapshot[key] = { source[1], source[2], source[3], source[4] }
        end
    end
    return snapshot
end

local function restoreThemePreviewColors(snapshot)
    if type(snapshot) ~= "table" or not CC.db or not CC.db.colors then return end
    for _, key in ipairs(THEME_PREVIEW_COLOR_KEYS) do
        local source = snapshot[key]
        if type(source) == "table" then
            CC.db.colors[key] = CC.db.colors[key] or {}
            overwriteColor(CC.db.colors[key], source)
        end
    end
end

function UI:GetThemePreviewName()
    return self.themePreview and self.themePreview.name or nil
end

function UI:IsThemePreviewActive()
    return self.themePreview ~= nil
end

function UI:PreviewThemePreset(name)
    if not CC.db or not CC.db.ui or not CC.db.colors then return false end
    name = string.upper(tostring(name or "CRESH_MINIMAL"))
    if name == "CUSTOM" then
        if CC.Print then CC:Print("Custom colours are already shown live. Select a named theme to preview it.") end
        return false
    end
    local preset = THEME_PRESETS[name]
    if not preset then return false end

    if not self.themePreview then
        self.themePreview = {
            savedPreset = CC.db.ui.themePreset or "CRESH_MINIMAL",
            savedColors = snapshotThemePreviewColors(),
        }
    end
    self.themePreview.name = name
    for key, value in pairs(preset) do
        CC.db.colors[key] = CC.db.colors[key] or {}
        overwriteColor(CC.db.colors[key], value)
    end
    CC.db.ui.themePreset = name
    self:ApplyVisualSettings()
    return true
end

function UI:CancelThemePreview(silent)
    local preview = self.themePreview
    if not preview or not CC.db or not CC.db.ui or not CC.db.colors then return false end
    CC.db.ui.themePreset = preview.savedPreset or "CRESH_MINIMAL"
    restoreThemePreviewColors(preview.savedColors)
    self.themePreview = nil
    self:ApplyVisualSettings()
    if not silent and CC.Print then CC:Print("Theme preview reverted.") end
    return true
end

function UI:CommitThemePreview()
    local preview = self.themePreview
    if not preview then return false end
    local name = preview.name
    self:CancelThemePreview(true)
    return self:ApplyThemePreset(name)
end

function UI:ApplyThemePreset(name)
    if not CC.db or not CC.db.ui or not CC.db.colors then return false end
    name = string.upper(tostring(name or "CRESH_MINIMAL"))
    if self.themePreview then self:CancelThemePreview(true) end
    if not self:IsThemePresetUnlocked(name) then
        local info = CC.BattlePass.GetThemeInfo and CC.BattlePass:GetThemeInfo(name)
        if info and info.source == "PASS" and info.level then
            if CC.Print then CC:Print((info.name or name) .. " unlocks at Battle Pass Level " .. tostring(info.level) .. ".") end
            if CC.BattlePass.SelectRequirement then CC.BattlePass:SelectRequirement(info.level)
            elseif self.OpenGameDrawer then self:OpenGameDrawer("BATTLEPASS") end
        else
            if CC.Print then CC:Print((info and info.name or name) .. " is locked. Open Games > Unlock Themes.") end
            if self.OpenGameDrawer then self:OpenGameDrawer("THEMES") end
        end
        return false
    end
    local preset = THEME_PRESETS[name]
    if not preset then return end
    for key, value in pairs(preset) do
        CC.db.colors[key] = CC.db.colors[key] or {}
        overwriteColor(CC.db.colors[key], value)
    end
    CC.db.ui.themePreset = name
    self:ApplyVisualSettings()
    return true
end

function UI:ValidateThemeOwnership()
    if not CC.db or not CC.db.ui or not CC.db.colors then return end

    -- An active preview is intentionally temporary and may display a locked
    -- palette. It must never alter ownership or become the saved selection.
    if not self.themePreview then
        local selected = string.upper(tostring(CC.db.ui.themePreset or "CRESH_MINIMAL"))
        if not self:IsThemePresetUnlocked(selected) then
            local fallback = "CRESH_MINIMAL"
            local preset = THEME_PRESETS[fallback]
            CC.db.ui.themePreset = fallback
            if preset then
                for key, value in pairs(preset) do
                    CC.db.colors[key] = CC.db.colors[key] or {}
                    overwriteColor(CC.db.colors[key], value)
                end
            end
            if not self.creshLockedThemeWarningShown and CC.Print then
                self.creshLockedThemeWarningShown = true
                CC:Print("A locked theme could not be equipped. Cresh Minimal has been restored.")
            end
        end
    end

    local guildSelected = string.upper(tostring(CC.db.ui.guildThemePreset or "AUTO"))
    if not self:IsGuildThemeUnlocked(guildSelected) then
        CC.db.ui.guildThemePreset = "AUTO"
    end
end

function UI:SyncThemeColors()
    if not CC.db or not CC.db.colors then return end
    local c = CC.db.colors
    copyColor(COLORS.panel, c.panel)
    copyColor(COLORS.panelSoft, c.panelSoft)
    copyColor(COLORS.panelRaised, c.panelRaised)
    copyColor(COLORS.border, c.border)
    copyColor(COLORS.blue, c.accent)
    copyColor(COLORS.blueHover, c.accent)
    COLORS.blueHover[1] = min(1, COLORS.blueHover[1] + 0.06)
    COLORS.blueHover[2] = min(1, COLORS.blueHover[2] + 0.06)
    COLORS.blueHover[3] = min(1, COLORS.blueHover[3] + 0.06)
    copyColor(COLORS.incoming, c.incoming)
end

local function getOutgoingColor()
    return (CC.db and CC.db.colors and CC.db.colors.outgoing) or COLORS.blue
end

local function getChannelColor(message)
    local key = CC.ChannelColorKey and CC:ChannelColorKey(message) or "CHANNEL"
    local channels = CC.db and CC.db.colors and CC.db.colors.channels
    return (channels and channels[key]) or COLORS.blue
end

local function templateName()
    if _G.BackdropTemplateMixin then
        return "BackdropTemplate"
    end
    return nil
end

local function applyBackdrop(frame, background, border, edgeSize)
    border = border or COLORS.border
    edgeSize = edgeSize or 1

    if frame.SetBackdrop then
        local chrome = frame.creshClassicChrome and not isGuildColorReference(background) and UI:GetThemeChrome() or nil
        if chrome then
            frame:SetBackdrop({
                bgFile = chrome.bgFile,
                edgeFile = chrome.edgeFile,
                tile = true,
                tileSize = 32,
                edgeSize = chrome.edgeSize or 12,
                insets = chrome.insets or { left = 3, right = 3, top = 3, bottom = 3 },
            })
        else
            frame:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                edgeSize = edgeSize,
                insets = { left = edgeSize, right = edgeSize, top = edgeSize, bottom = edgeSize },
            })
        end
        frame:SetBackdropColor(background[1], background[2], background[3], background[4])
        frame:SetBackdropBorderColor(border[1], border[2], border[3], border[4])
    else
        if not frame.creshBackground then
            frame.creshBackground = frame:CreateTexture(nil, "BACKGROUND")
            frame.creshBackground:SetAllPoints()
        end
        frame.creshBackground:SetColorTexture(background[1], background[2], background[3], background[4])
    end
end

local function createFont(parent, size, color, justify)
    local text = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetFont(STANDARD_TEXT_FONT, size or 12, "")
    color = color or COLORS.text
    text:SetTextColor(color[1], color[2], color[3], color[4])
    text:SetJustifyH(justify or "LEFT")
    text:SetJustifyV("MIDDLE")
    return text
end

local function paintBackdrop(frame, color)
    if not frame or type(color) ~= "table" then return end
    local alpha = color[4] or 1
    if frame.SetBackdropColor then
        frame:SetBackdropColor(color[1] or 0, color[2] or 0, color[3] or 0, alpha)
    elseif frame.creshBackground then
        frame.creshBackground:SetColorTexture(color[1] or 0, color[2] or 0, color[3] or 0, alpha)
    end
end

local function brightenColor(color, amount)
    amount = tonumber(amount) or 0.08
    return {
        min(1, (color and color[1] or 0) + amount),
        min(1, (color and color[2] or 0) + amount),
        min(1, (color and color[3] or 0) + amount),
        color and color[4] or 1,
    }
end

local function darkenColor(color, factor)
    factor = max(0, min(1, tonumber(factor) or 0.42))
    return {
        (color and color[1] or 0) * factor,
        (color and color[2] or 0) * factor,
        (color and color[3] or 0) * factor,
        color and color[4] or 1,
    }
end

local function createButton(parent, text, width, height, callback)
    local button = CreateFrame("Button", nil, parent, templateName())
    button:SetSize(width or 60, height or 26)
    applyBackdrop(button, COLORS.panelRaised, COLORS.border)
    button.creshNormalColor = COLORS.panelRaised
    button.creshActiveColor = COLORS.blue
    button.creshHoverColor = COLORS.blueHover
    button.creshSelected = false

    button.label = createFont(button, 11, COLORS.text, "CENTER")
    button.label:SetAllPoints()
    button.label:SetText(text or "")

    button:SetScript("OnEnter", function(self)
        paintBackdrop(self, self.creshHoverColor or COLORS.blueHover)
    end)
    button:SetScript("OnLeave", function(self)
        local color = self.creshSelected and (self.creshActiveColor or COLORS.blue) or (self.creshNormalColor or COLORS.panelRaised)
        paintBackdrop(self, color)
    end)
    button:SetScript("OnClick", callback)
    return button
end


local function createGuildCrest(parent, size)
    local crest = CreateFrame("Frame", nil, parent)
    crest:SetSize(size or 30, size or 30)
    crest.generic = crest:CreateTexture(nil, "ARTWORK")
    crest.generic:SetAllPoints()
    crest.generic:SetTexture("Interface\\Icons\\INV_Shirt_GuildTabard_01")
    crest.background = crest:CreateTexture(nil, "BACKGROUND")
    crest.background:SetAllPoints()
    crest.emblem = crest:CreateTexture(nil, "ARTWORK")
    crest.emblem:SetAllPoints()
    crest.border = crest:CreateTexture(nil, "OVERLAY")
    crest.border:SetAllPoints()
    crest.background:Hide(); crest.emblem:Hide(); crest.border:Hide()
    return crest
end

function UI:RefreshGuildCrest(crest)
    if not crest then return end
    crest.generic:Show()
    crest.background:Hide(); crest.emblem:Hide(); crest.border:Hide()
    if type(_G.SetSmallGuildTabardTextures) == "function" then
        local ok = pcall(_G.SetSmallGuildTabardTextures, "player", crest.emblem, crest.background, crest.border)
        if ok then
            crest.background:Show(); crest.emblem:Show(); crest.border:Show(); crest.generic:Hide()
        end
    end
end

function UI:GetGuildDisplayName()
    if type(_G.GetGuildInfo) == "function" then
        local ok, name = pcall(_G.GetGuildInfo, "player")
        if ok and name and name ~= "" then return name end
    end
    return "Guild"
end

local function setBackground(frame, color)
    paintBackdrop(frame, color)
end

local function truncate(text, limit)
    text = tostring(text or "")
    limit = limit or 60
    if string.len(text) <= limit then
        return text
    end
    return string.sub(text, 1, limit - 3) .. "..."
end



local CLASS_ICON_TEXTURE = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES"
local RACE_ICON_TEXTURE = "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Races"
local PORTRAIT_MASK = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"

local function setSprite(texture, file, coords)
    texture:SetTexture(file)
    if coords then
        texture:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
    else
        texture:SetTexCoord(0, 1, 0, 1)
    end
end

local function getClassCoords(classFile)
    if not classFile then return nil end
    return _G.CLASS_ICON_TCOORDS and _G.CLASS_ICON_TCOORDS[string.upper(classFile)] or nil
end

local function getRaceCoords(raceFile, sex)
    if not raceFile or not _G.RACE_ICON_TCOORDS then return nil end
    local race = string.upper(tostring(raceFile))
    local gender = tonumber(sex) == 3 and "FEMALE" or "MALE"
    return _G.RACE_ICON_TCOORDS[race .. "_" .. gender]
        or _G.RACE_ICON_TCOORDS[race .. gender]
        or _G.RACE_ICON_TCOORDS[race]
end

local function unitMatches(unit, name, guid)
    if not unit or not UnitExists or not UnitExists(unit) then return false end
    if guid and UnitGUID and UnitGUID(unit) == guid then return true end
    if name and UnitName then
        local unitName, unitRealm = UnitName(unit)
        local full = unitName
        if unitName and unitRealm and unitRealm ~= "" then full = unitName .. "-" .. unitRealm end
        if unitName and (CC:WhisperNamesEquivalent(unitName, name) or (full and CC:WhisperNamesEquivalent(full, name))) then
            return true
        end
    end
    return false
end

function UI:FindUnitForPlayer(name, guid)
    local fixed = { "player", "target", "focus", "mouseover", "pet" }
    for _, unit in ipairs(fixed) do
        if unitMatches(unit, name, guid) then return unit end
    end
    for index = 1, 4 do
        local unit = "party" .. index
        if unitMatches(unit, name, guid) then return unit end
    end
    for index = 1, 40 do
        local unit = "raid" .. index
        if unitMatches(unit, name, guid) then return unit end
    end
    return nil
end

local function createCircularPortrait(parent, size)
    local portrait = CreateFrame("Frame", nil, parent)
    portrait:SetSize(size or 30, size or 30)
    portrait.initial = createFont(portrait, max(10, floor((size or 30) * 0.42)), COLORS.text, "CENTER")
    portrait.initial:SetAllPoints()

    portrait.ring = portrait:CreateTexture(nil, "BACKGROUND")
    portrait.ring:SetAllPoints()
    portrait.ring:SetTexture(PORTRAIT_MASK)
    portrait.ring:SetVertexColor(COLORS.blue[1], COLORS.blue[2], COLORS.blue[3], 1)

    portrait.texture = portrait:CreateTexture(nil, "ARTWORK")
    portrait.texture:SetPoint("TOPLEFT", portrait, "TOPLEFT", 2, -2)
    portrait.texture:SetPoint("BOTTOMRIGHT", portrait, "BOTTOMRIGHT", -2, 2)
    if portrait.texture.AddMaskTexture and portrait.CreateMaskTexture then
        portrait.mask = portrait:CreateMaskTexture()
        portrait.mask:SetTexture(PORTRAIT_MASK)
        portrait.mask:SetAllPoints(portrait.texture)
        portrait.texture:AddMaskTexture(portrait.mask)
    end

    if CreateFrame then
        local ok, model = pcall(CreateFrame, "PlayerModel", nil, portrait)
        if ok and model then
            portrait.model = model
            model:SetPoint("TOPLEFT", portrait, "TOPLEFT", 2, -2)
            model:SetPoint("BOTTOMRIGHT", portrait, "BOTTOMRIGHT", -2, 2)
            model:Hide()
        end
    end

    portrait.badge = portrait:CreateTexture(nil, "OVERLAY")
    portrait.badge:SetSize(max(10, floor((size or 30) * 0.38)), max(10, floor((size or 30) * 0.38)))
    portrait.badge:SetPoint("BOTTOMRIGHT", portrait, "BOTTOMRIGHT", 1, -1)
    portrait.badge:Hide()
    portrait.badgeText = createFont(portrait, max(7, floor((size or 30) * 0.24)), COLORS.text, "CENTER")
    portrait.badgeText:SetSize(max(10, floor((size or 30) * 0.38)), max(10, floor((size or 30) * 0.38)))
    portrait.badgeText:SetPoint("CENTER", portrait.badge, "CENTER", 0, 0)
    portrait.badgeText:Hide()
    return portrait
end
UI.CreateCircularPortrait = createCircularPortrait

function UI:UpdatePlayerPortrait(portrait, name, guid, message)
    if not portrait then return end
    local options = CC.db and CC.db.ui or {}
    if options.showPortraits == false then
        portrait:Hide()
        return
    end
    portrait:Show()
    local info = message or CC:GetCachedPlayerInfo(name, guid) or {}
    if message and (not message.classFile or not message.raceFile) then
        local cached = CC:GetCachedPlayerInfo(name, guid) or {}
        info = {
            classFile = message.classFile or cached.classFile,
            raceFile = message.raceFile or cached.raceFile,
            sex = message.sex or cached.sex,
        }
    end
    local classFile = info.classFile
    local raceFile = info.raceFile
    local sex = info.sex
    local classColors = _G.CUSTOM_CLASS_COLORS or _G.RAID_CLASS_COLORS
    local classColor = classColors and classFile and classColors[string.upper(classFile)]
    if classColor then
        portrait.ring:SetVertexColor(classColor.r or 1, classColor.g or 1, classColor.b or 1, 1)
    end
    local style = string.upper(tostring(options.portraitStyle or "CLASS"))
    local unit = nil
    if style == "2D" or style == "3D" then
        unit = self:FindUnitForPlayer(name, guid)
    end

    local portraitSize = portrait:GetWidth() or 30
    local badgeSize = max(10, floor(portraitSize * 0.38))
    portrait.badge:SetSize(badgeSize, badgeSize)
    portrait.badgeText:SetSize(badgeSize, badgeSize)
    portrait.initial:SetFont(STANDARD_TEXT_FONT, max(10, floor(portraitSize * 0.42)), "")
    portrait.badgeText:SetFont(STANDARD_TEXT_FONT, max(7, floor(portraitSize * 0.24)), "")
    portrait.texture:Hide()
    if portrait.model then portrait.model:Hide() end
    portrait.initial:Hide()
    portrait.badge:Hide()
    portrait.badgeText:Hide()
    if not classColor then portrait.ring:SetVertexColor(COLORS.blue[1], COLORS.blue[2], COLORS.blue[3], 1) end

    local shown = false
    if style == "3D" and unit and portrait.model and portrait.model.SetUnit then
        portrait.model:Show()
        pcall(portrait.model.SetUnit, portrait.model, unit)
        if portrait.model.SetPortraitZoom then pcall(portrait.model.SetPortraitZoom, portrait.model, 1) end
        shown = true
    elseif style == "2D" and unit and type(SetPortraitTexture) == "function" then
        portrait.texture:Show()
        portrait.texture:SetTexCoord(0, 1, 0, 1)
        pcall(SetPortraitTexture, portrait.texture, unit)
        shown = true
    end

    if not shown and style ~= "CLASS" then
        local raceCoords = getRaceCoords(raceFile, sex)
        if raceCoords then
            portrait.texture:Show()
            setSprite(portrait.texture, RACE_ICON_TEXTURE, raceCoords)
            shown = true
        end
    end
    if not shown then
        local classCoords = getClassCoords(classFile)
        if classCoords then
            portrait.texture:Show()
            setSprite(portrait.texture, CLASS_ICON_TEXTURE, classCoords)
            shown = true
        end
    end
    if not shown then
        portrait.initial:SetText(string.upper(string.sub(CC:ShortName(name or "?"), 1, 1)))
        portrait.initial:Show()
    end

    local badgeCoords
    local badgeTexture
    if style == "CLASS" then
        badgeCoords = getRaceCoords(raceFile, sex)
        badgeTexture = RACE_ICON_TEXTURE
    else
        badgeCoords = getClassCoords(classFile)
        badgeTexture = CLASS_ICON_TEXTURE
    end
    if badgeCoords then
        portrait.badge:Show()
        setSprite(portrait.badge, badgeTexture, badgeCoords)
    elseif style == "CLASS" and raceFile then
        portrait.badgeText:SetText(string.upper(string.sub(tostring(raceFile), 1, 1)))
        portrait.badgeText:Show()
    end
end

local function savePosition(frame, key)
    if not CC.db or not CC.db.positions then
        return
    end
    local point, _, relativePoint, x, y = frame:GetPoint(1)
    CC.db.positions[key] = {
        point = point or "CENTER",
        relativePoint = relativePoint or point or "CENTER",
        x = floor((x or 0) + 0.5),
        y = floor((y or 0) + 0.5),
    }
end

local function applyPosition(frame, key)
    local saved = CC.db and CC.db.positions and CC.db.positions[key]
    if not saved then
        return
    end
    frame:ClearAllPoints()
    frame:SetPoint(saved.point or "CENTER", UIParent, saved.relativePoint or saved.point or "CENTER", saved.x or 0, saved.y or 0)
end

local function saveSize(frame, key)
    if not frame or not CC.db then return end
    CC.db.sizes = CC.db.sizes or {}
    CC.db.sizes[key] = {
        width = floor((frame:GetWidth() or 1) + 0.5),
        height = floor((frame:GetHeight() or 1) + 0.5),
    }
end

local function applySize(frame, key, defaultWidth, defaultHeight)
    if not frame then return end
    local saved = CC.db and CC.db.sizes and CC.db.sizes[key]
    local width = saved and tonumber(saved.width) or defaultWidth
    local height = saved and tonumber(saved.height) or defaultHeight
    frame:SetSize(width or defaultWidth or 320, height or defaultHeight or 260)
end

local function configureResizeBounds(frame, minWidth, minHeight, maxWidth, maxHeight)
    if not frame then return end
    if frame.SetResizable then frame:SetResizable(true) end
    if frame.SetResizeBounds then
        frame:SetResizeBounds(minWidth, minHeight, maxWidth, maxHeight)
    else
        if frame.SetMinResize then frame:SetMinResize(minWidth, minHeight) end
        if frame.SetMaxResize then frame:SetMaxResize(maxWidth, maxHeight) end
    end
end

local function installShiftResize(frame, dragSurface, key, minWidth, minHeight, maxWidth, maxHeight, refreshCallback)
    if not frame or not dragSurface then return end
    configureResizeBounds(frame, minWidth, minHeight, maxWidth, maxHeight)
    dragSurface:EnableMouse(true)
    dragSurface:RegisterForDrag("LeftButton")
    dragSurface:SetScript("OnDragStart", function()
        local allowResize = not CC.db or not CC.db.ui or CC.db.ui.shiftResize ~= false
        if allowResize and IsShiftKeyDown and IsShiftKeyDown() and frame.StartSizing then
            frame.creshSizing = true
            frame:StartSizing("BOTTOMRIGHT")
        elseif frame.StartMoving then
            frame.creshSizing = false
            frame:StartMoving()
        end
    end)
    dragSurface:SetScript("OnDragStop", function()
        if frame.StopMovingOrSizing then frame:StopMovingOrSizing() end
        savePosition(frame, key)
        saveSize(frame, key)
        if refreshCallback then refreshCallback(frame) end
        if UI and UI.ResolveWindowOverlaps then UI:ResolveWindowOverlaps(frame) end
    end)

    if not frame.resizeHint then
        frame.resizeHint = createFont(frame, 8, COLORS.muted, "RIGHT")
        frame.resizeHint:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -5, 4)
        frame.resizeHint:SetText("///")
    end
end


local function installSharedWidthGrips(frame)
    if not frame or frame.creshSharedWidthGrips then return end
    frame.creshSharedWidthGrips = {}
    if frame.SetResizable then frame:SetResizable(true) end

    local function makeGrip(side)
        local grip = CreateFrame("Button", nil, frame)
        grip:SetSize(15, 15)
        grip:SetPoint(side == "LEFT" and "BOTTOMLEFT" or "BOTTOMRIGHT", frame,
            side == "LEFT" and "BOTTOMLEFT" or "BOTTOMRIGHT", side == "LEFT" and 1 or -1, 1)
        grip:RegisterForDrag("LeftButton")
        grip.texture = grip:CreateTexture(nil, "OVERLAY")
        grip.texture:SetAllPoints()
        grip.texture:SetColorTexture(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3], 0.13)
        grip:SetScript("OnEnter", function(selfGrip)
            selfGrip.texture:SetColorTexture(COLORS.blue[1], COLORS.blue[2], COLORS.blue[3], 0.45)
            GameTooltip:SetOwner(selfGrip, "ANCHOR_CURSOR")
            GameTooltip:SetText("Drag to resize all chat widths", 1, 1, 1)
            GameTooltip:Show()
        end)
        grip:SetScript("OnLeave", function(selfGrip)
            selfGrip.texture:SetColorTexture(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3], 0.13)
            GameTooltip:Hide()
        end)
        grip:SetScript("OnDragStart", function()
            if frame.StartSizing then frame:StartSizing(side) end
        end)
        grip:SetScript("OnDragStop", function()
            if frame.StopMovingOrSizing then frame:StopMovingOrSizing() end
            if UI and UI.SetSharedDockWidth then UI:SetSharedDockWidth(frame:GetWidth(), frame) end
        end)
        frame.creshSharedWidthGrips[side] = grip
    end

    makeGrip("LEFT")
    makeGrip("RIGHT")
end


local function installPopoutWidthGrips(frame)
    if not frame or frame.creshPopoutWidthGrips then return end
    frame.creshPopoutWidthGrips = {}
    if frame.SetResizable then frame:SetResizable(true) end

    local function makeGrip(side)
        local grip = CreateFrame("Button", nil, frame)
        grip:SetSize(14, 14)
        grip:SetPoint(side == "LEFT" and "BOTTOMLEFT" or "BOTTOMRIGHT", frame,
            side == "LEFT" and "BOTTOMLEFT" or "BOTTOMRIGHT", side == "LEFT" and 1 or -1, 1)
        grip:RegisterForDrag("LeftButton")
        grip.texture = grip:CreateTexture(nil, "OVERLAY")
        grip.texture:SetAllPoints()
        grip.texture:SetColorTexture(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3], 0.10)
        grip:SetScript("OnEnter", function(selfGrip)
            selfGrip.texture:SetColorTexture(COLORS.blue[1], COLORS.blue[2], COLORS.blue[3], 0.38)
            GameTooltip:SetOwner(selfGrip, "ANCHOR_CURSOR")
            GameTooltip:SetText("Drag to resize compact pop-outs", 1, 1, 1)
            GameTooltip:Show()
        end)
        grip:SetScript("OnLeave", function(selfGrip)
            selfGrip.texture:SetColorTexture(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3], 0.10)
            GameTooltip:Hide()
        end)
        grip:SetScript("OnDragStart", function()
            if frame.StartSizing then frame:StartSizing(side) end
        end)
        grip:SetScript("OnDragStop", function()
            if frame.StopMovingOrSizing then frame:StopMovingOrSizing() end
            if UI and UI.SetPopoutWidth then UI:SetPopoutWidth(frame:GetWidth(), frame) end
        end)
        frame.creshPopoutWidthGrips[side] = grip
    end

    makeGrip("LEFT")
    makeGrip("RIGHT")
end

local function createBadge(parent, width)
    local badge = CreateFrame("Frame", nil, parent, templateName())
    badge:SetSize(width or 20, 18)
    applyBackdrop(badge, COLORS.red, COLORS.red)
    badge.text = createFont(badge, 10, COLORS.text, "CENTER")
    badge.text:SetAllPoints()
    badge:Hide()
    return badge
end

local function setBadge(badge, count)
    -- v0.3.25 removes red numeric counters. Unread state is shown with a subtle
    -- theme-aware border and portrait-ring pulse instead.
    if badge then badge:Hide() end
end

function UI:SetUnreadPulse(frame, portrait, active, color)
    if not frame then return end
    color = color or COLORS.blue
    if not frame.creshUnreadEdges then
        frame.creshUnreadEdges = {}
        local top = frame:CreateTexture(nil, "OVERLAY")
        top:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 1, -2); top:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", -1, -2); top:SetHeight(2)
        local bottom = frame:CreateTexture(nil, "OVERLAY")
        bottom:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 1, 2); bottom:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", -1, 2); bottom:SetHeight(2)
        local left = frame:CreateTexture(nil, "OVERLAY")
        left:SetPoint("TOPRIGHT", frame, "TOPLEFT", 2, -1); left:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", 2, 1); left:SetWidth(2)
        local right = frame:CreateTexture(nil, "OVERLAY")
        right:SetPoint("TOPLEFT", frame, "TOPRIGHT", -2, -1); right:SetPoint("BOTTOMLEFT", frame, "BOTTOMRIGHT", -2, 1); right:SetWidth(2)
        frame.creshUnreadEdges = { top, bottom, left, right }
        for _, edge in ipairs(frame.creshUnreadEdges) do if edge.SetBlendMode then edge:SetBlendMode("ADD") end; edge:Hide() end
    end
    if portrait and not portrait.creshUnreadRing then
        portrait.creshUnreadRing = portrait:CreateTexture(nil, "OVERLAY")
        portrait.creshUnreadRing:SetAllPoints()
        portrait.creshUnreadRing:SetTexture(PORTRAIT_MASK)
        if portrait.creshUnreadRing.SetBlendMode then portrait.creshUnreadRing:SetBlendMode("ADD") end
        portrait.creshUnreadRing:Hide()
    end
    frame.creshUnreadActive = active and true or false
    frame.creshUnreadPortrait = portrait
    frame.creshUnreadColor = color
    if not frame.creshUnreadActive then
        for _, edge in ipairs(frame.creshUnreadEdges or {}) do edge:Hide() end
        if portrait and portrait.creshUnreadRing then portrait.creshUnreadRing:Hide() end
        frame:SetScript("OnUpdate", nil)
        return
    end
    frame.creshUnreadElapsed = frame.creshUnreadElapsed or 0
    frame:SetScript("OnUpdate", function(selfFrame, elapsed)
        selfFrame.creshUnreadElapsed = (selfFrame.creshUnreadElapsed or 0) + (elapsed or 0)
        local wave = 0.5 + (0.5 * sin(selfFrame.creshUnreadElapsed * 3.2))
        local c = selfFrame.creshUnreadColor or COLORS.blue
        local alpha = 0.18 + (0.48 * wave)
        for _, edge in ipairs(selfFrame.creshUnreadEdges or {}) do
            edge:SetColorTexture(c[1] or 1, c[2] or 1, c[3] or 1, alpha)
            edge:Show()
        end
        local p = selfFrame.creshUnreadPortrait
        if p and p.creshUnreadRing then
            p.creshUnreadRing:SetVertexColor(c[1] or 1, c[2] or 1, c[3] or 1, 0.12 + (0.34 * wave))
            p.creshUnreadRing:Show()
        end
    end)
end

function UI:CreateMessageView(parent)
    local view = {}
    view.rows = {}

    view.scroll = CreateFrame("ScrollFrame", nil, parent)
    view.scroll:EnableMouseWheel(true)
    view.child = CreateFrame("Frame", nil, view.scroll)
    view.child:SetSize(1, 1)
    view.scroll:SetScrollChild(view.child)

    view.empty = createFont(view.scroll, 12, COLORS.muted, "CENTER")
    view.empty:SetPoint("CENTER", view.scroll, "CENTER", 0, 0)
    view.empty:SetText("No messages yet")

    view.scroll:SetScript("OnMouseWheel", function(scroll, delta)
        local range = max(0, (view.child:GetHeight() or 0) - (scroll:GetHeight() or 0))
        local current = scroll:GetVerticalScroll() or 0
        local nextValue = min(range, max(0, current - (delta * 42)))
        scroll:SetVerticalScroll(nextValue)
    end)

    function view:Refresh(messages, channel)
        messages = messages or {}
        local count = #messages
        self.empty:SetShown(count == 0)

        for _, row in ipairs(self.rows) do row:Hide() end

        local scrollWidth = self.scroll:GetWidth()
        if not scrollWidth or scrollWidth < 100 then scrollWidth = self.fallbackWidth or 260 end

        local options = CC.db.ui or {}
        local iconSize = max(22, min(44, tonumber(options.iconSize) or 30))
        local messageScale = max(0.8, min(1.35, tonumber(options.messageScale) or 1))
        local showPortraits = options.showPortraits ~= false
        local startIndex = max(1, count - 59)
        local y = -8
        local visibleIndex = 0

        for index = startIndex, count do
            visibleIndex = visibleIndex + 1
            local message = messages[index]
            local row = self.rows[visibleIndex]
            if not row then
                row = CreateFrame("Button", nil, self.child, templateName())
                row:RegisterForClicks("RightButtonUp")
                applyBackdrop(row, COLORS.incoming, COLORS.incoming)

                row.accentLine = row:CreateTexture(nil, "OVERLAY")
                row.accentLine:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -1)
                row.accentLine:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 1)
                row.accentLine:SetWidth(3)
                row.accentLine:Hide()

                row.avatar = createCircularPortrait(row, 30)
                row.meta = createFont(row, 9, COLORS.muted, "LEFT")
                row.body = createFont(row, 12, COLORS.text, "LEFT")
                row.body:SetJustifyV("TOP")
                if row.body.SetWordWrap then row.body:SetWordWrap(true) end

                row:SetScript("OnClick", function(selfRow, mouseButton)
                    if mouseButton == "RightButton" and selfRow.creshMessage then
                        local rowMessage = selfRow.creshMessage
                        if rowMessage.channel ~= "QUEST" and rowMessage.incoming and rowMessage.sender and not CC:IsSelf(rowMessage.sender) then
                            UI:BeginWhisper(rowMessage.sender)
                        end
                    end
                end)
                row:SetScript("OnEnter", function(selfRow)
                    local rowMessage = selfRow.creshMessage
                    if rowMessage and rowMessage.channel ~= "QUEST" and rowMessage.incoming and rowMessage.sender and not CC:IsSelf(rowMessage.sender) then
                        GameTooltip:SetOwner(selfRow, "ANCHOR_CURSOR")
                        GameTooltip:SetText("Right-click to whisper " .. CC:ShortName(rowMessage.sender), 1, 1, 1)
                        GameTooltip:Show()
                    end
                end)
                row:SetScript("OnLeave", function() GameTooltip:Hide() end)
                self.rows[visibleIndex] = row
            end

            row.creshMessage = message
            local incoming = message.incoming and true or false
            local previousMessage = index > startIndex and messages[index - 1] or nil
            local grouped = false
            if options.groupedMessages ~= false and previousMessage then
                local sameDirection = (previousMessage.incoming and true or false) == incoming
                local sameSender = tostring(previousMessage.sender or "") == tostring(message.sender or "")
                local sameSource = tostring(previousMessage.channelLabel or previousMessage.channel or "") == tostring(message.channelLabel or message.channel or "")
                local closeInTime = math.abs((message.timestamp or 0) - (previousMessage.timestamp or 0)) <= 120
                grouped = sameDirection and sameSender and sameSource and closeInTime
            end
            local bubbleWidth = max(170, floor(scrollWidth * 0.74))
            row:SetWidth(bubbleWidth)
            row:ClearAllPoints()
            if incoming then
                row:SetPoint("TOPLEFT", self.child, "TOPLEFT", 8, y)
                setBackground(row, channel == "GUILD" and GUILD_THEME.incoming or COLORS.incoming)
            else
                row:SetPoint("TOPRIGHT", self.child, "TOPRIGHT", -8, y)
                setBackground(row, channel == "GUILD" and GUILD_THEME.outgoing or getOutgoingColor())
            end

            row.accentLine:SetShown(channel == "GENERAL" or channel == "GUILD" or channel == "QUEST")
            if channel == "GENERAL" then
                local channelColor = getChannelColor(message)
                row.accentLine:SetColorTexture(channelColor[1], channelColor[2], channelColor[3], channelColor[4] or 1)
            elseif channel == "GUILD" then
                local line = message.channel == "OFFICER" and GUILD_THEME.officer or GUILD_THEME.accent
                row.accentLine:SetColorTexture(line[1], line[2], line[3], 1)
            elseif channel == "QUEST" then
                row.accentLine:SetColorTexture(COLORS.quest[1], COLORS.quest[2], COLORS.quest[3], 1)
            end

            row.avatar:SetSize(iconSize, iconSize)
            row.avatar.ring:SetAllPoints()
            row.avatar:ClearAllPoints()
            row.meta:ClearAllPoints()
            row.body:ClearAllPoints()
            row.meta:SetShown(not grouped)
            if grouped then
                row.avatar:Hide()
                row.body:SetPoint("TOPLEFT", row, "TOPLEFT", channel == "GENERAL" and 10 or 9, -8)
                row.body:SetPoint("TOPRIGHT", row, "TOPRIGHT", -10, -8)
            elseif showPortraits then
                if incoming then
                    row.avatar:SetPoint("TOPLEFT", row, "TOPLEFT", channel == "GENERAL" and 8 or 6, -6)
                    row.meta:SetPoint("TOPLEFT", row.avatar, "TOPRIGHT", 7, 1)
                    row.meta:SetPoint("TOPRIGHT", row, "TOPRIGHT", -9, -6)
                else
                    row.avatar:SetPoint("TOPRIGHT", row, "TOPRIGHT", -6, -6)
                    row.meta:SetPoint("TOPLEFT", row, "TOPLEFT", channel == "GENERAL" and 9 or 8, -6)
                    row.meta:SetPoint("TOPRIGHT", row.avatar, "TOPLEFT", -7, 1)
                end
                UI:UpdatePlayerPortrait(row.avatar, message.sender, message.guid, message)
                row.body:SetPoint("TOPLEFT", row.meta, "BOTTOMLEFT", 0, -3)
                row.body:SetPoint("TOPRIGHT", row.meta, "BOTTOMRIGHT", 0, -3)
            else
                row.avatar:Hide()
                row.meta:SetPoint("TOPLEFT", row, "TOPLEFT", channel == "GENERAL" and 9 or 8, -6)
                row.meta:SetPoint("TOPRIGHT", row, "TOPRIGHT", -9, -6)
                row.body:SetPoint("TOPLEFT", row.meta, "BOTTOMLEFT", 0, -3)
                row.body:SetPoint("TOPRIGHT", row.meta, "BOTTOMRIGHT", 0, -3)
            end
            row.meta:SetFont(STANDARD_TEXT_FONT, max(8, floor(9 * messageScale)), "")
            row.body:SetFont(STANDARD_TEXT_FONT, max(10, floor(12 * messageScale)), "")
            if row.meta.SetTextColor then
                local metaColor = channel == "GUILD" and (message.channel == "OFFICER" and GUILD_THEME.officer or GUILD_THEME.muted) or COLORS.muted
                row.meta:SetTextColor(metaColor[1], metaColor[2], metaColor[3], 1)
            end

            local sender = incoming and CC:ShortName(message.sender) or "You"
            if not incoming and message.failed then sender = "You · failed"
            elseif not incoming and message.pending then sender = "You · sending" end
            if channel == "GUILD" and message.channel == "OFFICER" then
                sender = "Officer - " .. sender
            elseif channel == "GENERAL" and message.channelLabel then
                sender = "[" .. tostring(message.channelLabel) .. "] " .. sender
            elseif channel == "QUEST" then
                sender = incoming and CC:ShortName(message.npcName or message.sender) or "You"
                if message.questTitle and message.questTitle ~= "" then
                    sender = sender .. " · " .. truncate(message.questTitle, 30)
                end
            end
            row.meta:SetText(sender .. "  " .. date("%H:%M", message.timestamp or time()))
            row.body:SetText(message.text or "")

            local bodyHeight = row.body:GetStringHeight() or 14
            local contentHeight = grouped and (bodyHeight + 16) or (bodyHeight + 30)
            if showPortraits and not grouped then contentHeight = max(contentHeight, iconSize + 12) end
            local rowHeight = max(grouped and 30 or 42, contentHeight)
            row:SetHeight(rowHeight)
            row:Show()
            y = y - rowHeight - (grouped and 3 or 8)
        end

        local totalHeight = max(1, -y + 2)
        self.child:SetWidth(scrollWidth)
        self.child:SetHeight(totalHeight)
        self.scroll:UpdateScrollChildRect()
        self.scroll:SetVerticalScroll(max(0, totalHeight - (self.scroll:GetHeight() or 0)))
    end

    return view
end


function UI:CreateCompactPopoutView(parent)
    local view = {}
    view.rows = {}
    view.offset = 0

    view.scroll = CreateFrame("Frame", nil, parent)
    view.scroll:EnableMouse(true)
    view.scroll:EnableMouseWheel(true)
    view.empty = createFont(view.scroll, 11, COLORS.muted, "CENTER")
    view.empty:SetPoint("CENTER", view.scroll, "CENTER", 0, 0)
    view.empty:SetText("No messages yet")

    local function refreshFromCache()
        if view.lastMessages then view:Refresh(view.lastMessages, view.lastChannel) end
    end

    view.scroll:SetScript("OnMouseWheel", function(_, delta)
        local messages = view.lastMessages or {}
        local rowCount = max(1, floor(tonumber((CC.db.ui or {}).popoutRows) or 6))
        local maxOffset = max(0, #messages - rowCount)
        if delta > 0 then view.offset = min(maxOffset, (view.offset or 0) + 1)
        else view.offset = max(0, (view.offset or 0) - 1) end
        refreshFromCache()
    end)

    function view:Refresh(messages, channel)
        messages = messages or {}
        self.lastMessages = messages
        self.lastChannel = channel
        local options = CC.db.ui or {}
        local rowCount = max(4, min(8, floor(tonumber(options.popoutRows) or 6)))
        local rowHeight = max(36, min(68, floor(tonumber(options.popoutRowHeight) or 44)))
        local maxOffset = max(0, #messages - rowCount)
        self.offset = min(maxOffset, max(0, self.offset or 0))
        local lastIndex = max(0, #messages - self.offset)
        local firstIndex = max(1, lastIndex - rowCount + 1)
        self.empty:SetShown(#messages == 0)

        for index = 1, rowCount do
            local row = self.rows[index]
            if not row then
                row = CreateFrame("Button", nil, self.scroll, templateName())
                row.accent = row:CreateTexture(nil, "OVERLAY")
                row.accent:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -1)
                row.accent:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 1)
                row.accent:SetWidth(3)
                row.time = createFont(row, 8, COLORS.muted, "LEFT")
                row.time:SetPoint("TOPLEFT", row, "TOPLEFT", 8, -5)
                row.time:SetWidth(40)
                row.name = createFont(row, 9, COLORS.text, "LEFT")
                row.name:SetPoint("TOPLEFT", row.time, "TOPRIGHT", 3, 0)
                row.name:SetPoint("RIGHT", row, "RIGHT", -8, 0)
                row.body = createFont(row, 10, COLORS.text, "LEFT")
                row.body:SetPoint("TOPLEFT", row, "TOPLEFT", 8, -18)
                row.body:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -8, 4)
                row.body:SetJustifyV("TOP")
                if row.body.SetWordWrap then row.body:SetWordWrap(true) end
                if row.body.SetNonSpaceWrap then row.body:SetNonSpaceWrap(true) end
                row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
                row:SetScript("OnClick", function(selfRow, mouseButton)
                    local message = selfRow.creshMessage
                    if mouseButton == "RightButton" and message and message.channel ~= "QUEST" and message.sender and not CC:IsSelf(message.sender) then
                        UI:BeginWhisper(message.sender)
                    elseif UI.SetActivePopout then
                        UI:SetActivePopout(parent)
                    end
                end)
                self.rows[index] = row
            end
            row:SetHeight(rowHeight)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", self.scroll, "TOPLEFT", 0, -((index - 1) * rowHeight))
            row:SetPoint("TOPRIGHT", self.scroll, "TOPRIGHT", 0, -((index - 1) * rowHeight))
            if row.body.SetHeight then row.body:SetHeight(max(12, rowHeight - 22)) end
            if row.body.SetMaxLines then row.body:SetMaxLines(max(1, floor((rowHeight - 20) / 11))) end

            local messageIndex = firstIndex + index - 1
            local message = messageIndex <= lastIndex and messages[messageIndex] or nil
            if message then
                row.creshMessage = message
                local incoming = message.incoming and true or false
                local sender = incoming and CC:ShortName(message.sender) or "You"
                if not incoming and message.failed then sender = "You · failed"
                elseif not incoming and message.pending then sender = "You · sending" end
                if channel == "GENERAL" and message.channelLabel then
                    sender = "[" .. tostring(message.channelLabel) .. "] " .. sender
                elseif channel == "GUILD" and message.channel == "OFFICER" then
                    sender = "[Officer] " .. sender
                elseif channel == "QUEST" then
                    sender = incoming and CC:ShortName(message.npcName or message.sender) or "You"
                    if message.questTitle and message.questTitle ~= "" then
                        sender = sender .. " · " .. truncate(message.questTitle, 22)
                    end
                end
                row.time:SetText(date("%H:%M", message.timestamp or time()))
                row.name:SetText(truncate(sender, 28))
                row.body:SetText(tostring(message.text or ""))

                local accent = getChannelColor(message)
                local background
                local border
                if channel == "GUILD" then
                    accent = message.channel == "OFFICER" and GUILD_THEME.officer or GUILD_THEME.accent
                    background = incoming and GUILD_THEME.incoming or GUILD_THEME.outgoing
                    border = GUILD_THEME.border
                    if row.name.SetTextColor then
                        local nameColor = message.channel == "OFFICER" and GUILD_THEME.officer or GUILD_THEME.muted
                        row.name:SetTextColor(nameColor[1], nameColor[2], nameColor[3], 1)
                    end
                    if row.time.SetTextColor then row.time:SetTextColor(GUILD_THEME.muted[1], GUILD_THEME.muted[2], GUILD_THEME.muted[3], 1) end
                else
                    if channel == "WHISPER" then accent = (CC.db.colors.channels or {}).WHISPER or COLORS.blue
                    elseif channel == "QUEST" then accent = COLORS.quest end
                    background = incoming and COLORS.incoming or getOutgoingColor()
                    border = COLORS.border
                    if row.name.SetTextColor then row.name:SetTextColor(COLORS.text[1], COLORS.text[2], COLORS.text[3], 1) end
                    if row.time.SetTextColor then row.time:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3], 1) end
                end
                applyBackdrop(row, background, border)
                row.accent:SetColorTexture(accent[1] or 1, accent[2] or 1, accent[3] or 1, accent[4] or 1)
                row:Show()
            else
                row.creshMessage = nil
                row:Hide()
            end
        end
        for index = rowCount + 1, #self.rows do self.rows[index]:Hide() end
        self.scroll:SetHeight(rowCount * rowHeight)
    end

    return view
end

function UI:CreateCombatView(parent)
    local view = {}
    view.rows = {}

    view.scroll = CreateFrame("ScrollFrame", nil, parent)
    view.scroll:EnableMouseWheel(true)
    view.child = CreateFrame("Frame", nil, view.scroll)
    view.child:SetSize(1, 1)
    view.scroll:SetScrollChild(view.child)

    view.empty = createFont(view.scroll, 12, COLORS.muted, "CENTER")
    view.empty:SetPoint("CENTER", view.scroll, "CENTER", 0, 0)
    view.empty:SetText("Combat activity will appear here")

    view.scroll:SetScript("OnMouseWheel", function(scroll, delta)
        local range = max(0, (view.child:GetHeight() or 0) - (scroll:GetHeight() or 0))
        local current = scroll:GetVerticalScroll() or 0
        scroll:SetVerticalScroll(min(range, max(0, current - (delta * 38))))
    end)

    local categoryColors = {
        damageOut = COLORS.combatOut,
        damageIn = COLORS.combatIn,
        heal = COLORS.combatHeal,
        aura = COLORS.combatUtility,
        utility = COLORS.combatUtility,
        kill = COLORS.combatOut,
        death = COLORS.combatIn,
        miss = COLORS.muted,
        event = COLORS.text,
    }

    function view:Refresh(messages)
        messages = messages or {}
        local count = #messages
        self.empty:SetShown(count == 0)

        for _, row in ipairs(self.rows) do
            row:Hide()
        end

        local width = self.scroll:GetWidth()
        if not width or width < 100 then
            width = self.fallbackWidth or 320
        end

        local startIndex = max(1, count - 99)
        local y = -4
        local visibleIndex = 0
        for index = startIndex, count do
            visibleIndex = visibleIndex + 1
            local message = messages[index]
            local row = self.rows[visibleIndex]
            if not row then
                row = CreateFrame("Frame", nil, self.child)
                row.time = createFont(row, 10, COLORS.muted, "LEFT")
                row.time:SetPoint("TOPLEFT", row, "TOPLEFT", 4, -4)
                row.time:SetWidth(42)

                row.dot = createFont(row, 12, COLORS.text, "CENTER")
                row.dot:SetPoint("TOPLEFT", row.time, "TOPRIGHT", 1, -1)
                row.dot:SetWidth(12)
                row.dot:SetText("•")

                row.body = createFont(row, 11, COLORS.text, "LEFT")
                row.body:SetPoint("TOPLEFT", row.dot, "TOPRIGHT", 3, 0)
                row.body:SetPoint("TOPRIGHT", row, "TOPRIGHT", -6, -4)
                row.body:SetJustifyV("TOP")
                if row.body.SetWordWrap then
                    row.body:SetWordWrap(true)
                end
                self.rows[visibleIndex] = row
            end

            row:SetWidth(width)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", self.child, "TOPLEFT", 0, y)
            row.time:SetText(date("%H:%M", message.timestamp or time()))
            row.body:SetText(message.text or "")
            local color = categoryColors[message.category] or COLORS.text
            row.dot:SetTextColor(color[1], color[2], color[3], color[4])
            row.body:SetTextColor(color[1], color[2], color[3], color[4])
            local bodyHeight = row.body:GetStringHeight() or 13
            local rowHeight = max(22, bodyHeight + 8)
            row:SetHeight(rowHeight)
            row:Show()
            y = y - rowHeight
        end

        local totalHeight = max(1, -y + 4)
        self.child:SetWidth(width)
        self.child:SetHeight(totalHeight)
        self.scroll:UpdateScrollChildRect()
        local range = max(0, totalHeight - (self.scroll:GetHeight() or 0))
        self.scroll:SetVerticalScroll(range)
    end

    return view
end

-- The C-dock composer is intentionally the only EditBox created by CreshChat.

function UI:GetWhisperPortraitMessage(target)
    target = CC:ResolveWhisperConversation(target)
    local messages = target and CC.db.history.whispers[target] or nil
    if messages then
        for index = #messages, 1, -1 do
            local message = messages[index]
            if message.incoming or (message.sender and CC:WhisperNamesEquivalent(message.sender, target)) then
                return message
            end
        end
    end
    local cached = CC:GetCachedPlayerInfo(target, nil) or {}
    return {
        sender = target,
        guid = cached.guid,
        classFile = cached.classFile,
        raceFile = cached.raceFile,
        sex = cached.sex,
        incoming = true,
    }
end

function UI:GetSortedConversations()
    local items = {}
    for target, updated in pairs(CC.db.conversations or {}) do
        if CC.db.history.whispers[target] then
            tinsert(items, { target = target, updated = updated or 0 })
        end
    end
    sort(items, function(a, b)
        return a.updated > b.updated
    end)
    return items
end

function UI:GetSortedQuestConversations()
    local items = {}
    if CC.EnsureQuestStorage then CC:EnsureQuestStorage() end
    for target, meta in pairs(CC.db.questConversations or {}) do
        if meta.hidden ~= true and CC.db.history.quests and CC.db.history.quests[target] then
            tinsert(items, {
                target = target,
                updated = tonumber(meta.updated) or 0,
                npcName = meta.npcName or "Quest Giver",
                zone = meta.zone or "Unknown Zone",
            })
        end
    end
    sort(items, function(a, b)
        return a.updated > b.updated
    end)
    return items
end

function UI:GetSortedFriends()
    if not (CC.Friends and CC.Friends.GetRoster) then return {} end
    local roster = CC.Friends:GetRoster()
    local isBattleNet = self.friendsDirectoryTab == "BNET"
    local wanted = isBattleNet and "BATTLENET" or "PLAYER"
    local showOnline, showOffline
    if isBattleNet then
        showOnline = CC.db.ui.showBattleNetFriendsOnline ~= false
        showOffline = CC.db.ui.showBattleNetFriendsOffline ~= false
    else
        showOnline = CC.db.ui.showGameFriendsOnline ~= false
        showOffline = CC.db.ui.showGameFriendsOffline ~= false
    end
    local filtered = {}
    for _, item in ipairs(roster or {}) do
        if item.kind == wanted and ((item.online and showOnline) or (not item.online and showOffline)) then
            filtered[#filtered + 1] = item
        end
    end
    return filtered
end

function UI:SetFriendsDirectoryTab(tab)
    tab = tab == "BNET" and "BNET" or "GAME"
    if self.friendsDirectoryTab == tab then return end
    self.friendsDirectoryTab = tab
    self:UpdateFriendsDirectoryTabs()
    self:RefreshFriendsHeader()
    self:RefreshConversationList()
end

function UI:EnsureFriendsDirectoryTabs()
    if self.friendsDirectoryTabs or not (self.main and self.main.body) then return end
    local holder = CreateFrame("Frame", nil, self.main.body)
    holder:SetHeight(28)
    holder.game = createButton(holder, "GAME FRIENDS", 116, 24, function() UI:SetFriendsDirectoryTab("GAME") end)
    holder.game:SetPoint("LEFT", holder, "LEFT", 0, 0)
    holder.game.label:SetFont(STANDARD_TEXT_FONT, 9, "")
    holder.bnet = createButton(holder, "BATTLE.NET", 104, 24, function() UI:SetFriendsDirectoryTab("BNET") end)
    holder.bnet:SetPoint("LEFT", holder.game, "RIGHT", 6, 0)
    holder.bnet.label:SetFont(STANDARD_TEXT_FONT, 9, "")
    self.friendsDirectoryTabs = holder
    self:UpdateFriendsDirectoryTabs()
end

function UI:UpdateFriendsDirectoryTabs()
    local holder = self.friendsDirectoryTabs
    if not holder then return end
    local accent = (CC.db and CC.db.colors and CC.db.colors.accent) or COLORS.blue
    local hover = brightenColor(accent, 0.10)
    local normal = darkenColor(accent, 0.42)
    self:SetTabButtonStyle(holder.game, self.friendsDirectoryTab ~= "BNET", accent, hover, normal)
    self:SetTabButtonStyle(holder.bnet, self.friendsDirectoryTab == "BNET", accent, hover, normal)
    for _, button in ipairs({ holder.game, holder.bnet }) do
        if button.SetBackdropBorderColor then
            local selected = (button == holder.bnet and self.friendsDirectoryTab == "BNET") or (button == holder.game and self.friendsDirectoryTab ~= "BNET")
            local border = selected and accent or COLORS.border
            button:SetBackdropBorderColor(border[1], border[2], border[3], selected and 1 or 0.85)
        end
    end
end

function UI:GetSortedGuildRoster()
    if not (CC.Friends and CC.Friends.GetGuildRoster) then return {} end
    local showOnline = CC.db.ui.showGuildMembersOnline ~= false
    local showOffline = CC.db.ui.showGuildMembersOffline ~= false
    local filtered = {}
    for _, item in ipairs(CC.Friends:GetGuildRoster() or {}) do
        if (item.online and showOnline) or (not item.online and showOffline) then
            filtered[#filtered + 1] = item
        end
    end
    return filtered
end

function UI:GetSortedLocalRoster()
    if CC.Friends and CC.Friends.GetLocalRoster then return CC.Friends:GetLocalRoster() end
    return {}
end

function UI:GetSortedPartyRoster()
    if CC.Friends and CC.Friends.GetPartyRoster then return CC.Friends:GetPartyRoster() end
    return {}
end

function UI:GetSortedRaidRoster()
    if CC.Friends and CC.Friends.GetRaidRoster then return CC.Friends:GetRaidRoster() end
    return {}
end

function UI:GetSortedInstanceRoster()
    if CC.Friends and CC.Friends.GetInstanceRoster then return CC.Friends:GetInstanceRoster() end
    return {}
end

function UI:OpenDirectoryEntry(item)
    if not item or item.selfPlayer then return false end
    if item.kind == "QUEST" then return self:OpenFriendEntry(item) end
    if item.kind == "BATTLENET" or item.kind == "PLAYER" or item.kind == "PREVIOUS_WHISPER" then
        return self:OpenFriendEntry(item)
    end
    local target = item.target or item.fullName or item.name
    if not target or target == "" then return false end
    target = CC:EnsureWhisperConversation(target)
    if target then self.currentTarget = target; self:SetMode("WHISPER", target); return true end
    return false
end

function UI:OpenBattleNetFriendMessage(item)
    if not item or item.kind ~= "BATTLENET" then return false end
    self:OpenFriendEntry(item)
    return true
end

function UI:OpenBattleNetCharacterWhisper(item)
    if not item or item.kind ~= "BATTLENET" then return false end
    local target = item.gameTarget or item.activeCharacter or item.activeAltTarget
    if not target or target == "" then
        CC:Print("That Battle.net friend is not currently playing TBC Anniversary.")
        return false
    end
    target = CC:EnsureWhisperConversation(target)
    if not target then return false end
    self.currentTarget = target
    self:SetMode("WHISPER", target)
    return true
end

function UI:CallDirectoryEntry(item)
    if not item or item.selfPlayer then return false end
    local target = item.gameTarget or item.activeCharacter or item.activeAltTarget or item.fullName or item.target or item.name
    if item.kind == "BATTLENET" and (not target or target == item.target) then
        CC:Print("That Battle.net friend is not currently playing TBC Anniversary.")
        return false
    end
    if CC.Voice and CC.Voice.RequestCall then return CC.Voice:RequestCall(target) end
    CC:Print("Voice calls are unavailable on this client.")
    return false
end

function UI:AddDirectoryFriend(item)
    if not item or item.selfPlayer then return false end
    local target = item.addTarget or item.gameTarget or item.activeCharacter or item.fullName or item.target or item.name
    if not target or target == "" then return false end
    if CC.Friends and CC.Friends.AddFriend then return CC.Friends:AddFriend(target) end
    return CC:AddChatFriend(target)
end

function UI:InviteDirectoryEntry(item)
    if not item or item.selfPlayer then return false end
    local target = item.gameTarget or item.activeCharacter or item.activeAltTarget or item.fullName or item.target or item.name
    if item.kind == "BATTLENET" and (not target or target == item.target) then
        CC:Print("That Battle.net friend is not currently playing TBC Anniversary.")
        return false
    end
    if CC.Friends and CC.Friends.InvitePlayer then return CC.Friends:InvitePlayer(target) end
    return false
end

function UI:InviteWhisperTarget(target)
    target = CC:ResolveWhisperConversation(target or self.currentTarget)
    if not target then CC:Print("Open a whisper before inviting a player."); return false end
    local inviteTarget = CC.GetWhisperRoute and CC:GetWhisperRoute(target) or target
    if CC.IsBattleNetConversation and CC:IsBattleNetConversation(target) then
        local record = CC.GetBattleNetCharacterRecord and CC:GetBattleNetCharacterRecord(target) or nil
        inviteTarget = record and record.activeTarget or nil
        if not inviteTarget or inviteTarget == "" then
            CC:Print("That Battle.net friend is not currently playing TBC Anniversary.")
            return false
        end
    end
    if CC.Friends and CC.Friends.InvitePlayer then return CC.Friends:InvitePlayer(inviteTarget) end
    return false
end

function UI:RefreshFriendsHeader(roster)
    if not self.main or self.mode ~= "FRIENDS" then return end
    roster = roster or self:GetSortedFriends()
    local online, offline = 0, 0
    for _, item in ipairs(roster) do
        if item.online then online = online + 1 else offline = offline + 1 end
    end
    if self.friendsDirectoryTab == "BNET" then
        self.main.title:SetText("Battle.net Friends")
        if self.main.subtitle then self.main.subtitle:SetText(string.format("TBC Anniversary only · %d online / %d offline · ADD saves the active character as a game friend", online, offline)) end
    else
        self.main.title:SetText("Game Friends")
        if self.main.subtitle then self.main.subtitle:SetText(string.format("Blizzard character friends · %d online / %d offline", online, offline)) end
    end
    self:UpdateFriendsDirectoryTabs()
end

function UI:OpenFriendEntry(item)
    if not item then return end
    if item.kind == "QUEST" then
        local meta = CC:GetQuestConversationMeta(item.target)
        if meta then meta.hidden = false end
        self.currentQuestTarget = item.target
        self:SetMode("QUEST", item.target)
        return
    end

    local target
    if item.kind == "BATTLENET" then
        if item.target and CC.IsBattleNetConversation and CC:IsBattleNetConversation(item.target) then
            target = CC:EnsureWhisperConversation(item.target)
        elseif CC.EnsureBattleNetConversation then
            target = CC:EnsureBattleNetConversation(item.bnetAccountID, item.name)
        end
    else
        target = CC:EnsureWhisperConversation(item.target or item.name)
    end
    if target then
        self.currentTarget = target
        self:SetMode("WHISPER", target)
    end
end

function UI:InviteFriendEntry(item)
    if not item or item.kind == "QUEST" then return false end
    if item.kind == "BATTLENET" and not item.gameTarget then
        CC:Print("That Battle.net friend is not currently playing TBC Anniversary.")
        return false
    end
    if CC.Friends and CC.Friends.InvitePlayer then
        return CC.Friends:InvitePlayer(item.gameTarget or item.activeAltTarget or item.target or item.name)
    end
    CC:Print("Party invitation is not available on this client.")
    return false
end

function UI:ConfirmRemoveFriend(item)
    if not item or item.kind == "QUEST" then return false end
    local target = item.target or item.name
    local displayName = item.name or (CC.GetWhisperDisplayName and CC:GetWhisperDisplayName(target)) or target
    if not target or target == "" then return false end

    local function removeEntry(entry)
        if CC.Friends and CC.Friends.RemoveEntry then return CC.Friends:RemoveEntry(entry) end
        if CC.Friends and CC.Friends.RemovePlayer then return CC.Friends:RemovePlayer(entry.target or entry.name) end
        return false
    end

    if _G.StaticPopupDialogs and type(_G.StaticPopup_Show) == "function" then
        if not _G.StaticPopupDialogs.CRESHCHAT_REMOVE_FRIEND then
            _G.StaticPopupDialogs.CRESHCHAT_REMOVE_FRIEND = {
                text = "Remove %s from your friends list?",
                button1 = _G.YES or "Yes",
                button2 = _G.NO or "No",
                OnAccept = function(dialog, data)
                    local entry = data or (dialog and dialog.data)
                    if entry then removeEntry(entry) end
                end,
                timeout = 0,
                whileDead = true,
                hideOnEscape = true,
                preferredIndex = 3,
            }
        end
        local popup = _G.StaticPopup_Show("CRESHCHAT_REMOVE_FRIEND", displayName, nil, item)
        if popup then popup.data = item; return true end
    end
    return removeEntry(item)
end

function UI:PromptAddFriend()
    if not (_G.StaticPopupDialogs and type(_G.StaticPopup_Show) == "function") then
        CC:Print("Open a whisper and use the + button to add that player.")
        return false
    end
    if not _G.StaticPopupDialogs.CRESHCHAT_ADD_FRIEND then
        _G.StaticPopupDialogs.CRESHCHAT_ADD_FRIEND = {
            text = "Add a character name or BattleTag",
            button1 = _G.ADD_FRIEND or "Add Friend",
            button2 = _G.CANCEL or "Cancel",
            hasEditBox = true,
            maxLetters = 64,
            OnShow = function(dialog)
                if dialog.editBox then dialog.editBox:SetText(""); dialog.editBox:SetFocus() end
            end,
            OnAccept = function(dialog)
                local value = dialog.editBox and dialog.editBox:GetText() or ""
                if CC.Friends and CC.Friends.AddFriend then CC.Friends:AddFriend(value) end
            end,
            EditBoxOnEnterPressed = function(editBox)
                local dialog = editBox:GetParent()
                if CC.Friends and CC.Friends.AddFriend then CC.Friends:AddFriend(editBox:GetText()) end
                dialog:Hide()
            end,
            EditBoxOnEscapePressed = function(editBox) editBox:GetParent():Hide() end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
    end
    return _G.StaticPopup_Show("CRESHCHAT_ADD_FRIEND") ~= nil
end

function UI:RefreshConversationList()
    if not self.conversationList then
        return
    end
    for _, button in ipairs(self.conversationButtons) do
        button:Hide()
    end
    self.conversationSectionHeaders = self.conversationSectionHeaders or {}
    for _, header in ipairs(self.conversationSectionHeaders) do
        header:Hide()
    end

    local questMode = self.mode == "QUEST"
    local friendsMode = self.mode == "FRIENDS"
    local guildRosterMode = self.mode == "GUILD"
    local partyRosterMode = self.mode == "PARTY"
    local raidRosterMode = self.mode == "RAID"
    local instanceRosterMode = self.mode == "INSTANCE"
    local localRosterMode = self:IsGeneralFeedMode(self.mode) and not partyRosterMode and not raidRosterMode and not instanceRosterMode
    local groupRosterMode = partyRosterMode or raidRosterMode or instanceRosterMode
    local directoryMode = friendsMode or guildRosterMode or groupRosterMode or localRosterMode
    local conversations
    if friendsMode then conversations = self:GetSortedFriends()
    elseif guildRosterMode then conversations = self:GetSortedGuildRoster()
    elseif partyRosterMode then conversations = self:GetSortedPartyRoster()
    elseif raidRosterMode then conversations = self:GetSortedRaidRoster()
    elseif instanceRosterMode then conversations = self:GetSortedInstanceRoster()
    elseif localRosterMode then conversations = self:GetSortedLocalRoster()
    elseif questMode then conversations = self:GetSortedQuestConversations()
    else conversations = self:GetSortedConversations() end

    if friendsMode then self:RefreshFriendsHeader(conversations) end

    self.conversationEmptyText = self.conversationEmptyText or createFont(self.conversationList.child, 11, COLORS.muted, "CENTER")
    self.conversationEmptyText:Hide()
    if directoryMode and #conversations == 0 then
        self.conversationEmptyText:ClearAllPoints()
        self.conversationEmptyText:SetPoint("TOPLEFT", self.conversationList.child, "TOPLEFT", 18, -24)
        self.conversationEmptyText:SetPoint("RIGHT", self.conversationList.child, "RIGHT", -18, 0)
        if friendsMode then
            if self.friendsDirectoryTab == "BNET" then
                if CC.db.ui.showBattleNetFriendsOnline == false and CC.db.ui.showBattleNetFriendsOffline == false then
                    self.conversationEmptyText:SetText("Battle.net friend rows are hidden in Settings > Console > Roster visibility.")
                else
                    self.conversationEmptyText:SetText("No TBC Anniversary Battle.net friends were returned yet. CreshChat is refreshing both Battle.net API routes.")
                end
            else
                if CC.db.ui.showGameFriendsOnline == false and CC.db.ui.showGameFriendsOffline == false then
                    self.conversationEmptyText:SetText("Game friend rows are hidden in Settings > Console > Roster visibility.")
                else
                    self.conversationEmptyText:SetText("No in-game character friends were returned yet. Add a character here or from the Battle.net tab.")
                end
            end
        elseif guildRosterMode then
            if CC.db.ui.showGuildMembersOnline == false and CC.db.ui.showGuildMembersOffline == false then
                self.conversationEmptyText:SetText("Guild member rows are hidden in Settings > Console > Roster visibility.")
            else
                self.conversationEmptyText:SetText("No guild members were returned yet. CreshChat is refreshing the guild roster.")
            end
        elseif partyRosterMode then self.conversationEmptyText:SetText("You are not currently in a party. Only current party members appear here.")
        elseif raidRosterMode then self.conversationEmptyText:SetText("You are not currently in a raid. Only current raid members appear here.")
        elseif instanceRosterMode then self.conversationEmptyText:SetText("No current instance-group members were returned.")
        else self.conversationEmptyText:SetText("The local player list is refreshing for this area.") end
        self.conversationEmptyText:Show()
    end

    local activeTarget = questMode and self.currentQuestTarget or self.currentTarget
    local unreadTable = questMode and self.unreadQuestByTarget or self.unreadByTarget
    local y = 0
    local rowIndex = 0
    local headerIndex = 0
    local lastSection

    for _, item in ipairs(conversations) do
        if directoryMode and item.section ~= lastSection then
            headerIndex = headerIndex + 1
            local header = self.conversationSectionHeaders[headerIndex]
            if not header then
                header = createFont(self.conversationList.child, 9, COLORS.muted, "LEFT")
                self.conversationSectionHeaders[headerIndex] = header
            end
            header:ClearAllPoints()
            header:SetPoint("TOPLEFT", self.conversationList.child, "TOPLEFT", 8, -y - 5)
            header:SetPoint("RIGHT", self.conversationList.child, "RIGHT", -8, 0)
            header:SetText(item.section or "FRIENDS")
            if item.section == "PREVIOUS WHISPERS" then
                header:SetTextColor(COLORS.blue[1], COLORS.blue[2], COLORS.blue[3], 1)
            elseif item.online then
                header:SetTextColor(COLORS.green[1], COLORS.green[2], COLORS.green[3], 1)
            else
                header:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3], 1)
            end
            header:Show()
            y = y + 22
            lastSection = item.section
        end

        rowIndex = rowIndex + 1
        local button = self.conversationButtons[rowIndex]
        if not button then
            button = CreateFrame("Button", nil, self.conversationList.child, templateName())
            button:SetHeight(46)
            button:EnableMouse(true)
            if button.RegisterForClicks then button:RegisterForClicks("LeftButtonUp") end
            applyBackdrop(button, COLORS.panelSoft, COLORS.panelSoft)

            button.avatar = createCircularPortrait(button, 28)
            button.avatar:SetPoint("LEFT", button, "LEFT", 6, 0)

            button.nameText = createFont(button, 10, COLORS.text, "LEFT")
            if button.nameText.SetWordWrap then button.nameText:SetWordWrap(false) end

            button.preview = createFont(button, 8, COLORS.muted, "LEFT")
            if button.preview.SetWordWrap then button.preview:SetWordWrap(false) end
            button.preview:Hide()

            button.close = createButton(button, "X", 18, 18, function(selfClose)
                if not selfClose.target then return end
                if selfClose.kind == "QUEST" then
                    UI:CloseQuestConversation(selfClose.target)
                else
                    UI:CloseWhisper(selfClose.target)
                end
            end)
            button.close:SetPoint("TOPRIGHT", button, "TOPRIGHT", -3, -3)
            button.close.label:SetFont(STANDARD_TEXT_FONT, 9, "")

            button.removeFriend = createButton(button, "X", 20, 18, function(selfAction)
                UI:ConfirmRemoveFriend(selfAction:GetParent().friendEntry)
            end)
            button.removeFriend:SetPoint("RIGHT", button, "RIGHT", -4, 0)
            button.removeFriend.label:SetFont(STANDARD_TEXT_FONT, 9, "")
            button.removeFriend.creshNormalColor = darkenColor(COLORS.red, 0.32)
            button.removeFriend.creshHoverColor = brightenColor(COLORS.red, 0.08)
            paintBackdrop(button.removeFriend, button.removeFriend.creshNormalColor)
            if button.removeFriend.SetBackdropBorderColor then button.removeFriend:SetBackdropBorderColor(COLORS.red[1], COLORS.red[2], COLORS.red[3], 1) end
            button.removeFriend:HookScript("OnEnter", function(selfAction)
                if GameTooltip then
                    GameTooltip:SetOwner(selfAction, "ANCHOR_RIGHT")
                    local entry = selfAction:GetParent().friendEntry or {}
                    GameTooltip:SetText(entry.kind == "BATTLENET" and "Remove Battle.net friend" or "Remove friend")
                    GameTooltip:AddLine(entry.kind == "BATTLENET" and "Removes this account from your Battle.net friends list." or "Removes this player from your WoW friends list.", 0.75, 0.78, 0.84, true)
                    GameTooltip:Show()
                end
            end)
            button.removeFriend:HookScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
            button.removeFriend:Hide()

            button.addRosterFriend = createButton(button, "ADD", 32, 20, function(selfAction)
                UI:AddDirectoryFriend(selfAction:GetParent().directoryEntry)
            end)
            button.addRosterFriend.label:SetFont(STANDARD_TEXT_FONT, 8, "")
            button.addRosterFriend.creshNormalColor = darkenColor(COLORS.blue, 0.34)
            button.addRosterFriend.creshHoverColor = brightenColor(COLORS.blue, 0.10)
            paintBackdrop(button.addRosterFriend, button.addRosterFriend.creshNormalColor)
            if button.addRosterFriend.SetBackdropBorderColor then button.addRosterFriend:SetBackdropBorderColor(COLORS.blue[1], COLORS.blue[2], COLORS.blue[3], 1) end
            button.addRosterFriend:HookScript("OnEnter", function(selfAction)
                if GameTooltip then
                    GameTooltip:SetOwner(selfAction, "ANCHOR_RIGHT")
                    local entry = selfAction:GetParent().directoryEntry or {}
                    GameTooltip:SetText(entry.kind == "BATTLENET" and "Add active character" or "Add to friends")
                    GameTooltip:AddLine(entry.kind == "BATTLENET" and "Adds the TBC Anniversary character currently being played to your in-game friends list." or "Adds this character to your WoW friends list.", 0.75, 0.78, 0.84, true)
                    GameTooltip:Show()
                end
            end)
            button.addRosterFriend:HookScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
            button.addRosterFriend:Hide()

            button.messageFriend = createButton(button, "B.NET", 38, 20, function(selfAction)
                UI:OpenBattleNetFriendMessage(selfAction:GetParent().friendEntry)
            end)
            button.messageFriend.label:SetFont(STANDARD_TEXT_FONT, 7, "")
            button.messageFriend.creshNormalColor = darkenColor(COLORS.blue, 0.34)
            button.messageFriend.creshHoverColor = brightenColor(COLORS.blue, 0.10)
            paintBackdrop(button.messageFriend, button.messageFriend.creshNormalColor)
            if button.messageFriend.SetBackdropBorderColor then button.messageFriend:SetBackdropBorderColor(COLORS.blue[1], COLORS.blue[2], COLORS.blue[3], 1) end
            button.messageFriend:HookScript("OnEnter", function(selfAction)
                if GameTooltip then
                    GameTooltip:SetOwner(selfAction, "ANCHOR_RIGHT")
                    GameTooltip:SetText("Battle.net message")
                    GameTooltip:AddLine("Opens the account-level Battle.net conversation.", 0.75, 0.78, 0.84, true)
                    GameTooltip:Show()
                end
            end)
            button.messageFriend:HookScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
            button.messageFriend:Hide()

            button.whisperFriend = createButton(button, "/W", 28, 20, function(selfAction)
                UI:OpenBattleNetCharacterWhisper(selfAction:GetParent().friendEntry)
            end)
            button.whisperFriend.label:SetFont(STANDARD_TEXT_FONT, 8, "")
            local whisperActionColor = (CC.db and CC.db.colors and CC.db.colors.channels and CC.db.colors.channels.WHISPER) or COLORS.blue
            button.whisperFriend.creshNormalColor = darkenColor(whisperActionColor, 0.34)
            button.whisperFriend.creshHoverColor = brightenColor(whisperActionColor, 0.10)
            paintBackdrop(button.whisperFriend, button.whisperFriend.creshNormalColor)
            if button.whisperFriend.SetBackdropBorderColor then button.whisperFriend:SetBackdropBorderColor(whisperActionColor[1], whisperActionColor[2], whisperActionColor[3], 1) end
            button.whisperFriend:HookScript("OnEnter", function(selfAction)
                if GameTooltip then
                    GameTooltip:SetOwner(selfAction, "ANCHOR_RIGHT")
                    GameTooltip:SetText("Whisper active character")
                    GameTooltip:AddLine("Opens a direct /whisper to the TBC Anniversary character currently online.", 0.75, 0.78, 0.84, true)
                    GameTooltip:Show()
                end
            end)
            button.whisperFriend:HookScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
            button.whisperFriend:Hide()

            button.inviteFriend = createButton(button, "PARTY", 42, 20, function(selfAction)
                UI:InviteDirectoryEntry(selfAction:GetParent().directoryEntry or selfAction:GetParent().friendEntry)
            end)
            button.inviteFriend:SetPoint("RIGHT", button.removeFriend, "LEFT", -4, 0)
            button.inviteFriend.label:SetFont(STANDARD_TEXT_FONT, 7, "")
            button.inviteFriend.creshNormalColor = darkenColor(COLORS.green, 0.34)
            button.inviteFriend.creshHoverColor = brightenColor(COLORS.green, 0.10)
            paintBackdrop(button.inviteFriend, button.inviteFriend.creshNormalColor)
            if button.inviteFriend.SetBackdropBorderColor then button.inviteFriend:SetBackdropBorderColor(COLORS.green[1], COLORS.green[2], COLORS.green[3], 1) end
            button.inviteFriend:HookScript("OnEnter", function(selfAction)
                if GameTooltip then
                    GameTooltip:SetOwner(selfAction, "ANCHOR_RIGHT")
                    GameTooltip:SetText("Invite to party")
                    GameTooltip:AddLine("Sends this character a party invitation.", 0.75, 0.78, 0.84, true)
                    GameTooltip:Show()
                end
            end)
            button.inviteFriend:HookScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
            button.inviteFriend:Hide()

            button.gameFriend = createButton(button, "GAME", 40, 18, function(selfAction)
                local entry = selfAction:GetParent().friendEntry
                if entry and CC.Games and CC.Games.OpenHub then CC.Games:OpenHub(entry.gameTarget or entry.activeAltTarget or entry.target or entry.name) end
            end)
            button.gameFriend:SetPoint("RIGHT", button.inviteFriend, "LEFT", -4, 0)
            button.gameFriend.label:SetFont(STANDARD_TEXT_FONT, 8, "")
            button.gameFriend:HookScript("OnEnter", function(selfAction)
                if GameTooltip then
                    GameTooltip:SetOwner(selfAction, "ANCHOR_RIGHT")
                    GameTooltip:SetText("Challenge to a game")
                    GameTooltip:AddLine("Opens Chess, Tetris, Hold'em and Pong challenges.", 0.75, 0.78, 0.84, true)
                    GameTooltip:Show()
                end
            end)
            button.gameFriend:HookScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
            button.gameFriend:Hide()

            button.voiceFriend = createButton(button, "", 22, 18, function(selfAction)
                UI:CallDirectoryEntry(selfAction:GetParent().friendEntry or selfAction:GetParent().directoryEntry)
            end)
            button.voiceFriend:SetPoint("RIGHT", button.gameFriend, "LEFT", -4, 0)
            if button.voiceFriend.SetFrameLevel and button.GetFrameLevel then button.voiceFriend:SetFrameLevel(button:GetFrameLevel() + 8) end
            if button.voiceFriend.RegisterForClicks then button.voiceFriend:RegisterForClicks("LeftButtonUp") end
            button.voiceFriend.icon = button.voiceFriend:CreateTexture(nil, "ARTWORK")
            button.voiceFriend.icon:SetSize(13, 13)
            button.voiceFriend.icon:SetPoint("CENTER")
            button.voiceFriend.icon:SetTexture("Interface\\AddOns\\CreshChat\\Media\\Voice\\Microphone.tga")
            button.voiceFriend:HookScript("OnEnter", function(selfAction)
                if not GameTooltip then return end
                local entry = selfAction:GetParent().friendEntry or {}
                local target = entry.gameTarget or entry.activeAltTarget or entry.target or entry.name or "player"
                local ready = CC.Voice and CC.Voice:IsPeerReady(target)
                GameTooltip:SetOwner(selfAction, "ANCHOR_RIGHT")
                GameTooltip:SetText("Start voice call")
                GameTooltip:AddLine(ready and "CreshChat detected" or "Waiting to detect CreshChat", ready and 0.25 or 0.65, ready and 0.9 or 0.68, ready and 0.45 or 0.75)
                GameTooltip:AddLine("Both players need CreshChat. Audio uses Blizzard voice chat.", 0.75, 0.78, 0.84, true)
                GameTooltip:Show()
            end)
            button.voiceFriend:HookScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
            button.voiceFriend:Hide()

            button.badge = createBadge(button, 18)
            button.badge:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -3, 3)

            button.statusDot = button:CreateTexture(nil, "OVERLAY")
            button.statusDot:SetTexture("Interface\\Buttons\\WHITE8X8")
            button.statusDot:SetSize(7, 7)
            button.statusDot:SetPoint("RIGHT", button, "RIGHT", -8, 0)
            button.statusDot:Hide()

            button.altIndicator = createButton(button, "ALT", 28, 18, function(selfAction)
                local entry = selfAction:GetParent().friendEntry or {}
                local target = entry.activeAltTarget or entry.altName
                if target and target ~= "" then UI:SetMode("WHISPER", CC:EnsureWhisperConversation(target)) end
            end)
            button.altIndicator.label:SetFont(STANDARD_TEXT_FONT, 7, "")
            button.altIndicator:Hide()
            button.altIndicator:HookScript("OnEnter", function(selfAction)
                if not GameTooltip then return end
                local entry = selfAction:GetParent().friendEntry or {}
                local altName = entry.altName or entry.activeAltTarget or "Unknown"
                GameTooltip:SetOwner(selfAction, "ANCHOR_RIGHT")
                GameTooltip:SetText("Logged in on an alt")
                GameTooltip:AddLine(CC:ShortName(altName), COLORS.blue[1], COLORS.blue[2], COLORS.blue[3])
                GameTooltip:AddLine("Click to open the alt's direct whisper. The right-side tabs switch between account, main and alt chats.", 0.75, 0.78, 0.84, true)
                GameTooltip:Show()
            end)
            button.altIndicator:HookScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

            button:SetScript("OnEnter", function(selfButton)
                local selected = selfButton.kind == "QUEST" and UI.currentQuestTarget or UI.currentTarget
                if selfButton.directoryEntry or selfButton.target ~= selected then
                    setBackground(selfButton, COLORS.panelRaised)
                end
                if selfButton.directoryEntry and GameTooltip then
                    GameTooltip:SetOwner(selfButton, "ANCHOR_RIGHT")
                    GameTooltip:SetText(selfButton.displayName or "Friend")
                    local entry = selfButton.directoryEntry or selfButton.friendEntry or {}
                    if selfButton.kind == "FRIEND_QUEST" then
                        GameTooltip:AddLine("Quest giver · " .. tostring(entry.zone or "Current zone"), COLORS.quest[1], COLORS.quest[2], COLORS.quest[3])
                        GameTooltip:AddLine("Click to open saved quest chat", 0.75, 0.78, 0.84)
                    else
                        local statusText = entry.online and "Online" or "Offline"
                        if entry.kind == "BATTLENET" then statusText = "Battle.net TBC Anniversary · " .. statusText end
                        GameTooltip:AddLine(statusText, entry.online and COLORS.green[1] or COLORS.muted[1], entry.online and COLORS.green[2] or COLORS.muted[2], entry.online and COLORS.green[3] or COLORS.muted[3])
                        local details = {}
                        if tonumber(entry.level) then table.insert(details, "Level " .. tostring(entry.level)) end
                        if entry.className and entry.className ~= "" then table.insert(details, tostring(entry.className)) end
                        if entry.area and entry.area ~= "" then table.insert(details, tostring(entry.area)) end
                        if #details > 0 then GameTooltip:AddLine(table.concat(details, " · "), 0.75, 0.78, 0.84) end
                        if entry.kind == "BATTLENET" and entry.richPresence and entry.richPresence ~= "" then
                            GameTooltip:AddLine(tostring(entry.richPresence), 0.60, 0.68, 0.78, true)
                        end
                        if entry.activeCharacter and entry.activeCharacter ~= "" then
                            GameTooltip:AddLine("Playing as: " .. CC:ShortName(entry.activeCharacter), COLORS.blue[1], COLORS.blue[2], COLORS.blue[3])
                        end
                        if entry.altLoggedIn and entry.altName then
                            GameTooltip:AddLine("Known alternate character", 0.68, 0.76, 0.92)
                        end
                        GameTooltip:AddLine(entry.kind == "BATTLENET" and "Click to open Battle.net message · use /W, PARTY or microphone for the active character" or "Click to open whisper chat", 0.75, 0.78, 0.84, true)
                    end
                    GameTooltip:Show()
                end
            end)
            button:SetScript("OnLeave", function(selfButton)
                local selected = selfButton.kind == "QUEST" and UI.currentQuestTarget or UI.currentTarget
                if selfButton.directoryEntry or selfButton.target ~= selected then
                    setBackground(selfButton, COLORS.panelSoft)
                end
                if GameTooltip then GameTooltip:Hide() end
            end)
            button:SetScript("OnClick", function(selfButton)
                if selfButton.directoryEntry then
                    UI:OpenDirectoryEntry(selfButton.directoryEntry)
                else
                    UI:SetMode(selfButton.kind == "QUEST" and "QUEST" or "WHISPER", selfButton.target)
                end
            end)

            self.conversationButtons[rowIndex] = button
        end

        button.friendEntry = friendsMode and item or nil
        button.directoryEntry = directoryMode and item or nil
        button.kind = friendsMode and (item.kind == "QUEST" and "FRIEND_QUEST" or "FRIEND_PLAYER") or ((guildRosterMode or groupRosterMode or localRosterMode) and "DIRECTORY_PLAYER" or (questMode and "QUEST" or "WHISPER"))
        button.target = item.target
        button.displayName = item.name or item.npcName or item.target
        button.close.kind = questMode and "QUEST" or "WHISPER"
        button.close.target = item.target
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", self.conversationList.child, "TOPLEFT", 0, -y)
        button:SetPoint("TOPRIGHT", self.conversationList.child, "TOPRIGHT", 0, -y)

        button.nameText:ClearAllPoints()
        button.nameText:SetPoint("LEFT", button.avatar, "RIGHT", 7, 0)

        button.badge:ClearAllPoints()
        button.statusDot:ClearAllPoints()
        button.removeFriend:Hide()
        if button.addRosterFriend then button.addRosterFriend:Hide() end
        if button.messageFriend then button.messageFriend:Hide() end
        if button.whisperFriend then button.whisperFriend:Hide() end
        button.inviteFriend:Hide()
        if button.gameFriend then button.gameFriend:Hide() end
        if button.voiceFriend then button.voiceFriend:Hide() end
        if button.altIndicator then button.altIndicator:Hide() end
        button.preview:SetText("")
        button.preview:Hide()

        local messages
        local displayName
        local portraitMessage
        local rowUnread = 0
        if directoryMode then
            displayName = item.name or "Player"
            if item.kind == "QUEST" then
                messages = (CC.db.history.quests or {})[item.target] or {}
                portraitMessage = messages[#messages] or { sender = displayName, incoming = true, channel = "QUEST" }
                button.statusDot:SetVertexColor(COLORS.quest[1], COLORS.quest[2], COLORS.quest[3], 1)
                rowUnread = self.unreadQuestByTarget[item.target] or 0
                setBadge(button.badge, rowUnread)
            else
                portraitMessage = { sender = displayName, guid = item.guid, classFile = item.classFile, incoming = true }
                if item.online then button.statusDot:SetVertexColor(COLORS.green[1], COLORS.green[2], COLORS.green[3], 1)
                else button.statusDot:SetVertexColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3], 0.75) end
                local resolved = CC:ResolveWhisperConversation(item.target)
                rowUnread = self.unreadByTarget[resolved or item.target] or 0
                setBadge(button.badge, rowUnread)
            end
            button.close:Hide()
            button.statusDot:Show()
            button.badge:SetPoint("BOTTOMRIGHT", button.avatar, "BOTTOMRIGHT", 4, -2)
            local rightAnchor = button
            local isSavedFriend = friendsMode and (item.kind == "PLAYER" or item.kind == "BATTLENET")
            local canAdd = not item.selfPlayer and item.kind ~= "QUEST" and item.addTarget and item.addTarget ~= ""
            if isSavedFriend then
                button.removeFriend:Show(); button.removeFriend:ClearAllPoints(); button.removeFriend:SetPoint("RIGHT", button, "RIGHT", -4, 0); rightAnchor = button.removeFriend
            end
            -- A Battle.net friendship and a WoW character friendship are separate.
            -- In the Battle.net tab, ADD saves the currently active TBC character
            -- to Blizzard's ordinary in-game friend list without removing B.net.
            if canAdd and button.addRosterFriend then
                button.addRosterFriend:Show(); button.addRosterFriend:ClearAllPoints()
                if rightAnchor == button then button.addRosterFriend:SetPoint("RIGHT", button, "RIGHT", -4, 0)
                else button.addRosterFriend:SetPoint("RIGHT", rightAnchor, "LEFT", -4, 0) end
                rightAnchor = button.addRosterFriend
            end
            local actionTarget = item.gameTarget or item.activeCharacter or item.activeAltTarget or item.fullName or item.target or item.name
            local inviteStatusAllowed = item.kind == "PREVIOUS_WHISPER" or item.online == true
            local alreadyGrouped = item.kind == "PARTY_MEMBER" or item.kind == "RAID_MEMBER"
            local canInvite = not item.selfPlayer and not alreadyGrouped and inviteStatusAllowed and actionTarget and actionTarget ~= "" and not (item.kind == "BATTLENET" and not item.gameTarget and not item.activeCharacter)
            if canInvite then
                button.inviteFriend:ClearAllPoints()
                if rightAnchor == button then button.inviteFriend:SetPoint("RIGHT", button, "RIGHT", -4, 0)
                else button.inviteFriend:SetPoint("RIGHT", rightAnchor, "LEFT", -4, 0) end
                button.inviteFriend:Show(); rightAnchor = button.inviteFriend
            end
            if isSavedFriend and item.online then
                if item.kind == "BATTLENET" then
                    if button.messageFriend then button.messageFriend:ClearAllPoints(); button.messageFriend:SetPoint("RIGHT", rightAnchor, "LEFT", -4, 0); button.messageFriend:Show(); rightAnchor = button.messageFriend end
                    if item.gameTarget and button.whisperFriend then button.whisperFriend:ClearAllPoints(); button.whisperFriend:SetPoint("RIGHT", rightAnchor, "LEFT", -4, 0); button.whisperFriend:Show(); rightAnchor = button.whisperFriend end
                    if button.voiceFriend and item.gameTarget then button.voiceFriend:ClearAllPoints(); button.voiceFriend:SetPoint("RIGHT", rightAnchor, "LEFT", -4, 0); button.voiceFriend:Show(); rightAnchor = button.voiceFriend end
                else
                    if button.gameFriend then button.gameFriend:ClearAllPoints(); button.gameFriend:SetPoint("RIGHT", rightAnchor, "LEFT", -4, 0); button.gameFriend:Show(); rightAnchor = button.gameFriend end
                    if button.voiceFriend then button.voiceFriend:ClearAllPoints(); button.voiceFriend:SetPoint("RIGHT", rightAnchor, "LEFT", -4, 0); button.voiceFriend:Show(); rightAnchor = button.voiceFriend end
                end
            end
            if item.altLoggedIn and item.altName and button.altIndicator then
                button.altIndicator:ClearAllPoints(); button.altIndicator:SetPoint("RIGHT", rightAnchor, "LEFT", -4, 0); button.altIndicator:Show(); rightAnchor = button.altIndicator
            end
            button.statusDot:SetPoint("RIGHT", rightAnchor == button and button or rightAnchor, rightAnchor == button and "RIGHT" or "LEFT", rightAnchor == button and -8 or -7, 0)
            button.nameText:SetPoint("RIGHT", button.statusDot, "LEFT", -7, 5)
            button.preview:ClearAllPoints(); button.preview:SetPoint("TOPLEFT", button.nameText, "BOTTOMLEFT", 0, 1); button.preview:SetPoint("RIGHT", button.statusDot, "LEFT", -7, 0)
            local details = {}
            local className = tostring(item.className or "")
            if className == "" and item.classFile then
                className = tostring((_G.LOCALIZED_CLASS_NAMES_MALE or {})[item.classFile] or (_G.LOCALIZED_CLASS_NAMES_FEMALE or {})[item.classFile] or item.classFile)
            end
            local identity = {}
            if tonumber(item.level) then table.insert(identity, "Level " .. tostring(math.floor(tonumber(item.level)))) end
            if className ~= "" then table.insert(identity, className) end
            local identityText = table.concat(identity, " ")

            if item.kind == "BATTLENET" and item.activeCharacter and item.activeCharacter ~= "" then
                table.insert(details, CC:ShortName(item.activeCharacter))
                if identityText ~= "" then table.insert(details, identityText) end
            elseif item.kind == "BATTLENET" then
                if identityText ~= "" then table.insert(details, identityText) end
                table.insert(details, item.online and "TBC Anniversary" or "Offline")
            else
                if identityText ~= "" then table.insert(details, identityText) end
                if item.kind == "GUILD_MEMBER" then
                    table.insert(details, item.rankName or "Guild member")
                    if item.area and item.area ~= "" then table.insert(details, item.area) end
                elseif item.kind == "PARTY_MEMBER" then
                    table.insert(details, item.leader and "Party leader" or (item.role or "Party member"))
                elseif item.kind == "RAID_MEMBER" then
                    table.insert(details, item.leader and "Raid leader" or (item.assistant and "Raid assistant" or (item.role or "Raid member")))
                    if item.subgroup then table.insert(details, "Group " .. tostring(item.subgroup)) end
                elseif item.kind == "LOCAL_PLAYER" then
                    if item.guild and item.guild ~= "" then table.insert(details, "<" .. item.guild .. ">")
                    elseif item.area and item.area ~= "" then table.insert(details, item.area) end
                elseif item.kind == "PLAYER" and item.area and item.area ~= "" then
                    table.insert(details, item.area)
                end
            end
            local secondary = table.concat(details, " · ")
            button.preview:SetText(secondary)
            if secondary ~= "" then
                button.preview:SetTextColor(item.online and COLORS.blue[1] or COLORS.muted[1], item.online and COLORS.blue[2] or COLORS.muted[2], item.online and COLORS.blue[3] or COLORS.muted[3], 1)
                button.preview:Show()
            else button.preview:Hide() end
        elseif questMode then
            messages = (CC.db.history.quests or {})[item.target] or {}
            displayName = item.npcName or "Quest Giver"
            portraitMessage = messages[#messages] or { sender = displayName, incoming = true, channel = "QUEST" }
            button.close:Show()
            button.statusDot:Hide()
            button.badge:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -3, 3)
            button.nameText:SetPoint("RIGHT", button, "RIGHT", -26, 0)
            rowUnread = unreadTable[item.target] or 0
            setBadge(button.badge, rowUnread)
        else
            messages = CC.db.history.whispers[item.target] or {}
            displayName = CC.GetWhisperDisplayName and CC:GetWhisperDisplayName(item.target) or CC:ShortName(item.target)
            portraitMessage = UI:GetWhisperPortraitMessage(item.target)
            button.close:Show()
            button.statusDot:Hide()
            button.badge:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -3, 3)
            button.nameText:SetPoint("RIGHT", button, "RIGHT", -26, 0)
            rowUnread = unreadTable[item.target] or 0
            setBadge(button.badge, rowUnread)
        end

        button.nameText:SetText(displayName)
        UI:UpdatePlayerPortrait(button.avatar, displayName, portraitMessage.guid, portraitMessage)
        local pulseColor = (questMode or (friendsMode and item.kind == "QUEST")) and COLORS.quest or COLORS.blue
        UI:SetUnreadPulse(button, button.avatar, (tonumber(rowUnread) or 0) > 0, pulseColor)
        setBackground(button, (not friendsMode and item.target == activeTarget) and COLORS.panelRaised or COLORS.panelSoft)
        button:Show()
        y = y + 47
    end

    local listWidth = max(128, (self.conversationList.scroll:GetWidth() or 132) - 4)
    self.conversationList.child:SetWidth(listWidth)
    self.conversationList.child:SetHeight(max(self.conversationList.scroll:GetHeight(), y))
end

function UI:AddWhisperFriend(target)
    target = CC:ResolveWhisperConversation(target or self.currentTarget)
    if not target then
        CC:Print("Open a whisper before adding a friend.")
        return false
    end
    if CC.IsBattleNetConversation and CC:IsBattleNetConversation(target) then
        CC:Print("This conversation is already linked to a Battle.net friend.")
        return false
    end
    return CC:AddChatFriend(target)
end

function UI:CloseWhisper(target)
    target = CC:ResolveWhisperConversation(target or self.currentTarget)
    if not target or target == "" then
        return
    end

    -- Closing removes the conversation from the visible list, not its saved history.
    CC.db.conversations[target] = nil
    self.unreadByTarget[target] = nil

    local popoutID = "WHISPER:" .. tostring(target)
    local popout = self.popouts and self.popouts[popoutID]
    if popout then
        popout:Hide()
    end

    if self.currentTarget == target then
        self.currentTarget = nil
        local sorted = self:GetSortedConversations()
        self.currentTarget = sorted[1] and sorted[1].target or nil
    end

    if CC.state.lastWhisperTarget == target then
        CC.state.lastWhisperTarget = self.currentTarget
    end

    CC.state.unreadWhispers = 0
    for _, count in pairs(self.unreadByTarget) do
        CC.state.unreadWhispers = CC.state.unreadWhispers + (count or 0)
    end

    if self.mode == "WHISPER" then
        self:SetMode("WHISPER", self.currentTarget)
        return
    end
    self:RefreshAll()
end

function UI:CloseQuestConversation(target)
    if not target or target == "" then return end
    if CC.EnsureQuestStorage then CC:EnsureQuestStorage() end

    -- Closing hides the quest-giver conversation from the Quests inbox while retaining
    -- its metadata for the current-zone Friends directory and its saved dialogue.
    local meta = CC.db.questConversations[target]
    if meta then meta.hidden = true end
    self.unreadQuestByTarget[target] = nil

    local id = "QUEST:" .. tostring(target)
    local popout = self.popouts and self.popouts[id]
    if popout then popout:Hide() end

    if self.currentQuestTarget == target then
        self.currentQuestTarget = nil
        local sorted = self:GetSortedQuestConversations()
        self.currentQuestTarget = sorted[1] and sorted[1].target or nil
    end

    CC.state.unreadQuests = 0
    for _, count in pairs(self.unreadQuestByTarget) do
        CC.state.unreadQuests = CC.state.unreadQuests + (count or 0)
    end

    if self.mode == "QUEST" then
        self:SetMode("QUEST", self.currentQuestTarget)
        return
    end
    self:RefreshAll()
end

function UI:RefreshSettingsPanel()
    if not self.settingsPanel then return end
    self.settingsRows.hide.label:SetText("Blizzard chat window: " .. (CC.db.hideBlizzard and "DISABLED" or "ENABLED"))
    local enabled = CC.db.ui and CC.db.ui.notificationCardsEnabled ~= false
    self.settingsRows.notifications.label:SetText("Notifications: " .. (enabled and "ON" or "OFF") .. "  |  OPEN SETTINGS")
    self.settingsRows.bubble.label:SetText("Floating button: " .. (CC.db.bubbleVisible and "ON" or "OFF"))
end

function UI:BuildSettingsPanel(parent)
    local panel = CreateFrame("Frame", nil, parent, templateName())
    panel:SetSize(225, 146)
    panel:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -8, -42)
    panel:SetFrameStrata("TOOLTIP")
    applyBackdrop(panel, COLORS.panel, COLORS.border)
    panel:Hide()
    self.settingsPanel = panel
    self.settingsRows = {}

    local heading = createFont(panel, 12, COLORS.text, "LEFT")
    heading:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -10)
    heading:SetText("QUICK SETTINGS  |  /cc settings")

    local function addRow(key, text, y, callback)
        local row = createButton(panel, text, 201, 27, callback)
        row:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, y)
        row.label:SetJustifyH("LEFT")
        row.label:ClearAllPoints()
        row.label:SetPoint("LEFT", row, "LEFT", 9, 0)
        row.label:SetPoint("RIGHT", row, "RIGHT", -9, 0)
        self.settingsRows[key] = row
        return row
    end

    addRow("hide", "", -34, function()
        CC:SetBlizzardChatHidden(not CC.db.hideBlizzard)
    end)
    addRow("notifications", "", -64, function()
        if UI.OpenSettings then UI:OpenSettings() end
        if UI.FullSettings and UI.FullSettings.frame and UI.FullSettings.frame:IsShown() and UI.FullSettings.SetPage then
            UI.FullSettings:SetPage("ALERTS")
        end
    end)
    addRow("bubble", "", -94, function()
        CC.db.bubbleVisible = not CC.db.bubbleVisible
        UI:SetBubbleGroupShown(CC.db.bubbleVisible)
        UI:RefreshSettingsPanel()
    end)

    self:RefreshSettingsPanel()
end

function UI:GetConsoleTabs()
    if not CC.db then return {} end
    CC.db.ui = CC.db.ui or {}
    CC.db.ui.consoleTabs = CC.db.ui.consoleTabs or {}
    return CC.db.ui.consoleTabs
end

function UI:IsConsoleTabEnabled(mode)
    mode = string.upper(tostring(mode or ""))
    if not CONSOLE_TAB_LOOKUP[mode] then return false end
    -- Party chat is always exposed while grouped, even when the optional Party
    -- tab was disabled outside a group. Messages still remain in General too.
    if mode == "PARTY" and CC.IsPlayerInParty and CC:IsPlayerInParty() then return true end
    local tabs = self:GetConsoleTabs()
    if tabs[mode] == nil then
        return mode == "FRIENDS" or mode == "WHISPER" or mode == "GUILD" or mode == "GENERAL" or mode == "QUEST" or mode == "COMBAT"
    end
    return tabs[mode] ~= false
end

function UI:IsGeneralFeedMode(mode)
    return GENERAL_FEED_MODES[tostring(mode or "")] == true
end

function UI:GetFirstVisibleConsoleMode()
    for _, definition in ipairs(CONSOLE_TAB_DEFINITIONS) do
        if self:IsConsoleTabEnabled(definition.key) then return definition.key end
    end
    local tabs = self:GetConsoleTabs()
    tabs.FRIENDS = true
    return "FRIENDS"
end

function UI:GetMainBodyTopOffset()
    return tonumber(self.mainBodyTopOffset) or 92
end

function UI:LayoutMainTabs()
    if not self.main or not self.main.tabs then return end
    local tabs = self.main.tabs
    local buttons = {}
    for _, definition in ipairs(CONSOLE_TAB_DEFINITIONS) do
        local button = self.main.consoleTabButtons and self.main.consoleTabButtons[definition.key]
        if button then
            local shown = self:IsConsoleTabEnabled(definition.key)
            button:SetShown(shown)
            if shown then buttons[#buttons + 1] = button end
        end
    end
    if #buttons == 0 then
        self:GetConsoleTabs().FRIENDS = true
        local fallback = self.main.consoleTabButtons and self.main.consoleTabButtons.FRIENDS
        if fallback then fallback:Show(); buttons[1] = fallback end
    end

    local available = tonumber(tabs:GetWidth()) or 0
    if available <= 0 then available = max(1, (tonumber(self.main:GetWidth()) or 470) - 20) end
    available = floor(available)
    local gap, rowHeight = 4, 30
    local rows, current, currentWidth = {}, {}, 0
    for _, button in ipairs(buttons) do
        local label = button.creshTabLabel or "TAB"
        local preferred = max(52, min(86, 24 + string.len(label) * 6))
        if #current > 0 and currentWidth + gap + preferred > available then
            rows[#rows + 1] = current
            current, currentWidth = {}, 0
        end
        current[#current + 1] = { button = button, preferred = preferred }
        currentWidth = currentWidth + (#current > 1 and gap or 0) + preferred
    end
    if #current > 0 then rows[#rows + 1] = current end

    for rowIndex, row in ipairs(rows) do
        local usable = available - gap * (#row - 1)
        local totalPreferred = 0
        for _, item in ipairs(row) do totalPreferred = totalPreferred + item.preferred end
        local previous
        for index, item in ipairs(row) do
            local button = item.button
            button:ClearAllPoints()
            local width = floor(usable * item.preferred / max(1, totalPreferred))
            if index == #row then
                local used = 0
                for prior = 1, index - 1 do used = used + (row[prior].button:GetWidth() or 0) end
                width = max(34, usable - used)
            end
            button:SetWidth(max(34, width))
            if button.label then button.label:SetFont(STANDARD_TEXT_FONT, width < 54 and 8 or (width < 68 and 9 or 10), "") end
            if previous then button:SetPoint("LEFT", previous, "RIGHT", gap, 0)
            else button:SetPoint("TOPLEFT", tabs, "TOPLEFT", 0, -((rowIndex - 1) * rowHeight)) end
            previous = button
        end
    end

    local rowCount = max(1, #rows)
    tabs:SetHeight(rowCount * rowHeight)
    self.mainBodyTopOffset = 62 + rowCount * rowHeight
    if self.main.body then
        self.main.body:ClearAllPoints()
        self.main.body:SetPoint("TOPLEFT", self.main, "TOPLEFT", 10, -self.mainBodyTopOffset)
        self.main.body:SetPoint("BOTTOMRIGHT", self.main, "BOTTOMRIGHT", -10, 10)
    end
end

function UI:RefreshConsoleTabs()
    self:LayoutMainTabs()
    if self.main and not self:IsConsoleTabEnabled(self.mode) then
        self:SetMode(self:GetFirstVisibleConsoleMode())
    else
        self:UpdateTabAppearance()
        self:RefreshAll()
    end
end


local function setDrawerButtonEnabled(button, enabled)
    if not button then return end
    button.creshDisabled = not enabled
    button:SetAlpha(enabled and 1 or 0.38)
    if enabled then button:Enable() else button:Disable() end
end

-- Returns self.main when chat is enabled, or self.gamesAnchor in Games Only mode.
-- Used by game-drawer functions so they work without the main chat frame.
function UI:GetGameParent()
    return self.main or self.gamesAnchor
end

-- Creates an invisible anchor frame positioned where the main frame would be.
-- Used as the parent / positioning reference for the game drawer in Games Only mode.
function UI:BuildGamesAnchor()
    if self.gamesAnchor then return self.gamesAnchor end
    local anchor = CreateFrame("Frame", "CreshChatGamesAnchor", UIParent)
    applySize(anchor, "main", 470, 520)
    anchor:SetFrameStrata("HIGH")
    anchor:SetClampedToScreen(true)
    local hasSaved = CC.db and CC.db.positions and CC.db.positions["main"]
    if hasSaved then
        applyPosition(anchor, "main")
    else
        anchor:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -16, 300)
    end
    anchor:Show()
    self.gamesAnchor = anchor
    return anchor
end

function UI:GetGameDrawerSide()
    local drawer = self.gameDrawer
    local anchor = self:GetGameParent()
    if not drawer or not anchor or not UIParent then return "RIGHT" end
    local screenWidth = tonumber(UIParent.GetWidth and UIParent:GetWidth()) or 0
    local anchorLeft = tonumber(anchor.GetLeft and anchor:GetLeft()) or 0
    local anchorRight = tonumber(anchor.GetRight and anchor:GetRight()) or 0
    local rightSpace = max(0, screenWidth - anchorRight)
    local leftSpace = max(0, anchorLeft)
    local visualWidth = (tonumber(drawer.GetWidth and drawer:GetWidth()) or 350) * (tonumber(anchor.GetScale and anchor:GetScale()) or 1)
    if rightSpace >= visualWidth + 8 then return "RIGHT" end
    if leftSpace >= visualWidth + 8 then return "LEFT" end
    return rightSpace >= leftSpace and "RIGHT" or "LEFT"
end

function UI:PositionGameDrawer(offset, side)
    local drawer = self.gameDrawer
    local anchor = self:GetGameParent()
    if not drawer or not anchor then return end
    side = side or drawer.creshSide or self:GetGameDrawerSide()
    drawer.creshSide = side
    local width = drawer:GetWidth() or 350
    if offset == nil then
        if side == "LEFT" then offset = drawer.creshOpen and -6 or (width - 4)
        else offset = drawer.creshOpen and 6 or (-width + 4) end
    end
    offset = tonumber(offset) or 0
    drawer:ClearAllPoints()
    if side == "LEFT" then
        drawer:SetPoint("TOPRIGHT", anchor, "TOPLEFT", offset, 0)
        drawer:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMLEFT", offset, 0)
    else
        drawer:SetPoint("TOPLEFT", anchor, "TOPRIGHT", offset, 0)
        drawer:SetPoint("BOTTOMLEFT", anchor, "BOTTOMRIGHT", offset, 0)
    end
end

function UI:BuildGameDrawer(parent)
    if self.gameDrawer then return self.gameDrawer end
    parent = parent or self.main
    if not parent then return nil end
    local drawer = CreateFrame("Frame", "CreshChatGameDrawer", parent, templateName())
    drawer:SetWidth(350)
    drawer:SetFrameStrata("HIGH")
    drawer:SetClampedToScreen(true)
    if drawer.SetFrameLevel and parent.GetFrameLevel then drawer:SetFrameLevel((parent:GetFrameLevel() or 1) + 12) end
    applyBackdrop(drawer, COLORS.panel, COLORS.border)
    drawer.creshOpen = false
    drawer.mode = "SOLO"
    drawer:Hide()
    self.gameDrawer = drawer
    drawer.creshSide = self:GetGameDrawerSide()
    self:PositionGameDrawer(nil, drawer.creshSide)

    drawer.header = CreateFrame("Frame", nil, drawer, templateName())
    drawer.header:SetPoint("TOPLEFT", drawer, "TOPLEFT", 1, -1)
    drawer.header:SetPoint("TOPRIGHT", drawer, "TOPRIGHT", -1, -1)
    drawer.header:SetHeight(50)
    applyBackdrop(drawer.header, COLORS.panelRaised, COLORS.border)
    drawer.title = createFont(drawer.header, 15, COLORS.text, "LEFT")
    drawer.title:SetPoint("TOPLEFT", drawer.header, "TOPLEFT", 12, -9)
    drawer.title:SetText("CRESH GAMES")
    drawer.subtitle = createFont(drawer.header, 9, COLORS.muted, "LEFT")
    drawer.subtitle:SetPoint("TOPLEFT", drawer.title, "BOTTOMLEFT", 0, -3)
    drawer.subtitle:SetText("Solo arcade and addon multiplayer")
    drawer.close = createButton(drawer.header, "X", 26, 24, function() UI:CloseGameDrawer() end)
    drawer.close:SetPoint("RIGHT", drawer.header, "RIGHT", -7, 0)
    drawer.history = createButton(drawer.header, "H", 26, 24, function()
        if CC.SoloGames and CC.SoloGames.OpenHistory then CC.SoloGames:OpenHistory() end
    end)
    drawer.history:SetPoint("RIGHT", drawer.close, "LEFT", -5, 0)
    drawer.leaderboard = createButton(drawer.header, "LB", 30, 24, function()
        if CC.SoloGames and CC.SoloGames.OpenLeaderboard then CC.SoloGames:OpenLeaderboard() end
    end)
    drawer.leaderboard:SetPoint("RIGHT", drawer.history, "LEFT", -5, 0)

    drawer.modeBar = CreateFrame("Frame", nil, drawer, templateName())
    drawer.modeBar:SetPoint("TOPLEFT", drawer.header, "BOTTOMLEFT", 8, -8)
    drawer.modeBar:SetPoint("TOPRIGHT", drawer.header, "BOTTOMRIGHT", -8, -8)
    drawer.modeBar:SetHeight(60)
    drawer.soloMode = createButton(drawer.modeBar, "SOLO", 52, 28, function() UI:SetGameDrawerMode("SOLO") end)
    drawer.soloMode:SetPoint("TOPLEFT", drawer.modeBar, "TOPLEFT", 0, 0)
    drawer.multiMode = createButton(drawer.modeBar, "MULTI", 68, 28, function() UI:SetGameDrawerMode("MULTIPLAYER") end)
    drawer.multiMode:SetPoint("LEFT", drawer.soloMode, "RIGHT", 4, 0)
    drawer.passMode = createButton(drawer.modeBar, "BATTLE PASS", 84, 28, function() UI:SetGameDrawerMode("BATTLEPASS") end)
    drawer.passMode:SetPoint("LEFT", drawer.multiMode, "RIGHT", 4, 0)
    drawer.achievementMode = createButton(drawer.modeBar, "ACH 0/0", 106, 28, function() UI:SetGameDrawerMode("ACHIEVEMENTS") end)
    drawer.achievementMode:SetPoint("LEFT", drawer.passMode, "RIGHT", 4, 0)
    drawer.themesMode = createButton(drawer.modeBar, "UNLOCK THEMES", 326, 26, function() UI:SetGameDrawerMode("THEMES") end)
    drawer.themesMode:SetPoint("TOPLEFT", drawer.modeBar, "TOPLEFT", 0, -32)

    drawer.statusBox = CreateFrame("Frame", nil, drawer, templateName())
    drawer.statusBox:SetPoint("TOPLEFT", drawer.modeBar, "BOTTOMLEFT", 0, -7)
    drawer.statusBox:SetPoint("TOPRIGHT", drawer.modeBar, "BOTTOMRIGHT", 0, -7)
    drawer.statusBox:SetHeight(48)
    applyBackdrop(drawer.statusBox, COLORS.panelSoft, COLORS.border)
    drawer.status = createFont(drawer.statusBox, 9, COLORS.muted, "LEFT")
    drawer.status:SetPoint("TOPLEFT", drawer.statusBox, "TOPLEFT", 9, -6)
    drawer.status:SetPoint("BOTTOMRIGHT", drawer.statusBox, "BOTTOMRIGHT", -78, 6)
    drawer.status:SetWordWrap(true)
    drawer.status:SetText("Choose Solo, Multiplayer, Battle Pass or unlockable themes.")
    drawer.scan = createButton(drawer.statusBox, "SCAN", 60, 26, function()
        if CC.Games and CC.Games.ScanPeers then CC.Games:ScanPeers() end
        UI:RefreshGameDrawer()
    end)
    drawer.scan:SetPoint("RIGHT", drawer.statusBox, "RIGHT", -7, 0)
    drawer.scan:Hide()

    drawer.scroll = CreateFrame("ScrollFrame", nil, drawer)
    drawer.scroll:SetPoint("TOPLEFT", drawer.statusBox, "BOTTOMLEFT", 0, -7)
    drawer.scroll:SetPoint("BOTTOMRIGHT", drawer, "BOTTOMRIGHT", -8, 8)
    drawer.scroll:EnableMouseWheel(true)
    drawer.content = CreateFrame("Frame", nil, drawer.scroll)
    drawer.content:SetWidth(326)
    drawer.content:SetHeight(680)
    drawer.scroll:SetScrollChild(drawer.content)
    drawer.scroll:SetScript("OnMouseWheel", function(selfScroll, delta)
        local current = selfScroll:GetVerticalScroll() or 0
        local maximum = selfScroll:GetVerticalScrollRange() or 0
        selfScroll:SetVerticalScroll(max(0, min(maximum, current - delta * 42)))
    end)

    drawer.soloPanel = CreateFrame("Frame", nil, drawer.content)
    drawer.soloPanel:SetPoint("TOPLEFT", drawer.content, "TOPLEFT", 0, 0)
    drawer.soloPanel:SetPoint("TOPRIGHT", drawer.content, "TOPRIGHT", 0, 0)
    drawer.soloPanel:SetHeight(720)
    drawer.soloCards = {}
    local soloCatalog = CC.SoloGames and CC.SoloGames.GetCatalog and CC.SoloGames:GetCatalog() or {}
    for index, info in ipairs(soloCatalog) do
        local card = CreateFrame("Frame", nil, drawer.soloPanel, templateName())
        card:SetPoint("TOPLEFT", drawer.soloPanel, "TOPLEFT", 0, -((index - 1) * 96))
        card:SetPoint("TOPRIGHT", drawer.soloPanel, "TOPRIGHT", 0, -((index - 1) * 96))
        card:SetHeight(88)
        applyBackdrop(card, COLORS.panelSoft, COLORS.border)
        card.art = CreateFrame("Frame", nil, card, templateName())
        card.art:SetSize(60, 60)
        card.art:SetPoint("LEFT", card, "LEFT", 10, 0)
        applyBackdrop(card.art, darkenColor(info.accent or COLORS.blue, 0.25), info.accent or COLORS.blue)
        card.artTexture = card.art:CreateTexture(nil, "ARTWORK")
        card.artTexture:SetPoint("TOPLEFT", card.art, "TOPLEFT", 1, -1)
        card.artTexture:SetPoint("BOTTOMRIGHT", card.art, "BOTTOMRIGHT", -1, 1)
        card.artText = createFont(card.art, 13, info.accent or COLORS.blue, "CENTER")
        card.artText:SetAllPoints()
        if info.icon then
            card.artTexture:SetTexture(info.icon)
            card.artTexture:Show()
            card.artText:Hide()
        else
            card.artText:SetText(info.art or info.key)
            card.artText:Show()
        end
        card.title = createFont(card, 12, COLORS.text, "LEFT")
        card.title:SetPoint("TOPLEFT", card.art, "TOPRIGHT", 10, -5)
        card.title:SetPoint("RIGHT", card, "RIGHT", -78, 0)
        card.title:SetText(info.shortTitle or info.title)
        card.details = createFont(card, 9, COLORS.muted, "LEFT")
        card.details:SetPoint("TOPLEFT", card.title, "BOTTOMLEFT", 0, -5)
        card.details:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -78, 17)
        card.details:SetWordWrap(true)
        card.levelBar = CreateFrame("StatusBar", nil, card)
        card.levelBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
        card.levelBar:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 78, 7)
        card.levelBar:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -78, 7)
        card.levelBar:SetHeight(7)
        card.levelBar:SetMinMaxValues(0, 1)
        card.levelBar:SetValue(0)
        card.levelBar:SetStatusBarColor((info.accent or COLORS.blue)[1], (info.accent or COLORS.blue)[2], (info.accent or COLORS.blue)[3], 0.95)
        card.levelText = createFont(card.levelBar, 7, COLORS.text, "CENTER")
        card.levelText:SetAllPoints()
        card.play = createButton(card, "PLAY", 58, 28, function()
            if CC.SoloGames and CC.SoloGames.StartGame then CC.SoloGames:StartGame(info.key) end
        end)
        card.play:SetPoint("RIGHT", card, "RIGHT", -9, 0)
        card.info = info
        drawer.soloCards[info.key] = card
    end

    drawer.multiPanel = CreateFrame("Frame", nil, drawer.content)
    drawer.multiPanel:SetPoint("TOPLEFT", drawer.content, "TOPLEFT", 0, 0)
    drawer.multiPanel:SetPoint("TOPRIGHT", drawer.content, "TOPRIGHT", 0, 0)
    drawer.multiPanel:SetHeight(760)
    drawer.targetButton = createButton(drawer.multiPanel, "TARGET: NONE", 326, 32, function(_, mouseButton)
        if CC.Games and CC.Games.CycleTarget then CC.Games:CycleTarget(mouseButton == "RightButton" and -1 or 1) end
        UI:RefreshGameDrawer()
    end)
    drawer.targetButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    drawer.targetButton:SetPoint("TOPLEFT", drawer.multiPanel, "TOPLEFT", 0, 0)
    drawer.targetHint = createFont(drawer.multiPanel, 9, COLORS.muted, "LEFT")
    drawer.targetHint:SetPoint("TOPLEFT", drawer.targetButton, "BOTTOMLEFT", 2, -6)
    drawer.targetHint:SetPoint("TOPRIGHT", drawer.targetButton, "BOTTOMRIGHT", -2, -6)
    drawer.targetHint:SetText("Left/right click cycles players. SCAN checks addon compatibility.")

    drawer.multiCards = {}
    local multiCatalog = CC.Games and CC.Games.GetCatalog and CC.Games:GetCatalog() or {}
    for index, info in ipairs(multiCatalog) do
        local card = CreateFrame("Frame", nil, drawer.multiPanel, templateName())
        card:SetPoint("TOPLEFT", drawer.multiPanel, "TOPLEFT", 0, -62 - ((index - 1) * 66))
        card:SetPoint("TOPRIGHT", drawer.multiPanel, "TOPRIGHT", 0, -62 - ((index - 1) * 66))
        card:SetHeight(58)
        applyBackdrop(card, COLORS.panelSoft, COLORS.border)
        card.art = CreateFrame("Frame", nil, card, templateName())
        card.art:SetSize(52, 52)
        card.art:SetPoint("LEFT", card, "LEFT", 8, 0)
        applyBackdrop(card.art, darkenColor(COLORS.blue, 0.25), COLORS.blue)
        card.artTexture = card.art:CreateTexture(nil, "ARTWORK")
        card.artTexture:SetPoint("TOPLEFT", card.art, "TOPLEFT", 1, -1)
        card.artTexture:SetPoint("BOTTOMRIGHT", card.art, "BOTTOMRIGHT", -1, 1)
        card.artText = createFont(card.art, 11, COLORS.blue, "CENTER")
        card.artText:SetAllPoints()
        if info.icon then
            card.artTexture:SetTexture(info.icon)
            card.artTexture:Show()
            card.artText:Hide()
        else
            card.artText:SetText(info.art or info.key)
            card.artText:Show()
        end
        card.title = createFont(card, 11, COLORS.text, "LEFT")
        card.title:SetPoint("TOPLEFT", card, "TOPLEFT", 66, -9)
        card.title:SetPoint("RIGHT", card, "RIGHT", -88, 0)
        card.title:SetText(info.title)
        card.details = createFont(card, 8, COLORS.muted, "LEFT")
        card.details:SetPoint("TOPLEFT", card.title, "BOTTOMLEFT", 0, -4)
        card.details:SetPoint("RIGHT", card, "RIGHT", -88, 0)
        card.details:SetText(info.description or "Addon multiplayer")
        card.levelBar = CreateFrame("StatusBar", nil, card)
        card.levelBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
        card.levelBar:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 66, 4)
        card.levelBar:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -88, 4)
        card.levelBar:SetHeight(4)
        card.levelBar:SetMinMaxValues(0, 1)
        card.levelBar:SetValue(0)
        card.levelBar:SetStatusBarColor(COLORS.blue[1], COLORS.blue[2], COLORS.blue[3], 0.95)
        card.levelText = createFont(card.levelBar, 7, COLORS.text, "CENTER")
        card.levelText:SetAllPoints()
        card.challenge = createButton(card, "PLAY", 70, 27, function()
            if CC.Games and CC.Games.Challenge then CC.Games:Challenge(CC.Games.targetName, info.key) end
            UI:RefreshGameDrawer()
        end)
        card.challenge:SetPoint("RIGHT", card, "RIGHT", -8, 0)
        card.info = info
        drawer.multiCards[info.key] = card
    end

    drawer.playersTitle = createFont(drawer.multiPanel, 11, COLORS.text, "LEFT")
    drawer.playersTitle:SetPoint("TOPLEFT", drawer.multiPanel, "TOPLEFT", 2, -334)
    drawer.playersTitle:SetText("DISCOVERED PLAYERS")
    drawer.playersHint = createFont(drawer.multiPanel, 8, COLORS.muted, "RIGHT")
    drawer.playersHint:SetPoint("TOPRIGHT", drawer.multiPanel, "TOPRIGHT", -2, -334)
    drawer.playersHint:SetText("Friends · whispers · party · raid · guild")
    drawer.playerRows = {}
    for index = 1, 9 do
        local row = createButton(drawer.multiPanel, "", 326, 30, function(selfRow)
            if selfRow.playerName and CC.Games and CC.Games.SetTarget then
                CC.Games:SetTarget(selfRow.playerName)
                UI:RefreshGameDrawer()
            end
        end)
        row:SetPoint("TOPLEFT", drawer.multiPanel, "TOPLEFT", 0, -354 - ((index - 1) * 34))
        row.label:SetJustifyH("LEFT")
        row.label:ClearAllPoints()
        row.label:SetPoint("LEFT", row, "LEFT", 9, 0)
        row.label:SetPoint("RIGHT", row, "RIGHT", -9, 0)
        drawer.playerRows[index] = row
    end

    if CC.BattlePass and CC.BattlePass.BuildDrawerPanels then
        CC.BattlePass:BuildDrawerPanels(drawer, {
            createButton = createButton,
            createFont = createFont,
            applyBackdrop = applyBackdrop,
            darken = darkenColor,
            setAccent = function(button, color, selected) UI:SetTabButtonStyle(button, selected == true, color, color, darkenColor(color, 0.45)) end,
            colors = COLORS,
            templateName = templateName,
        })
    end
    if CC.Achievements and CC.Achievements.BuildDrawerPanel then
        CC.Achievements:BuildDrawerPanel(drawer, {
            createButton = createButton,
            createFont = createFont,
            applyBackdrop = applyBackdrop,
            darken = darkenColor,
            setAccent = function(button, color, selected) UI:SetTabButtonStyle(button, selected == true, color, color, darkenColor(color, 0.45)) end,
            colors = COLORS,
            templateName = templateName,
        })
    end

    drawer:SetScript("OnShow", function() UI:RefreshGameDrawer() end)
    self:SetGameDrawerMode("SOLO")
    return drawer
end

function UI:SetGameDrawerStatus(text, color)
    local drawer = self.gameDrawer
    if not drawer then return end
    drawer.lastStatus = tostring(text or "")
    color = color or COLORS.muted
    drawer.status:SetText(drawer.lastStatus)
    drawer.status:SetTextColor(color[1], color[2], color[3], 1)
end

function UI:SetGameDrawerMode(mode, preserveScroll)
    local drawer = self:BuildGameDrawer(self:GetGameParent())
    if not drawer then return end
    mode = string.upper(tostring(mode or "SOLO"))
    if mode ~= "MULTIPLAYER" and mode ~= "BATTLEPASS" and mode ~= "ACHIEVEMENTS" and mode ~= "THEMES" then mode = "SOLO" end
    local previousMode = drawer.mode
    local savedScroll = preserveScroll and previousMode == mode and drawer.scroll and (drawer.scroll:GetVerticalScroll() or 0) or 0
    drawer.mode = mode
    local subtitles = {
        SOLO = "Solo arcade and saved progression",
        MULTIPLAYER = "Addon-to-addon challenges and player scans",
        BATTLEPASS = "100 levels of account-wide rewards and unlocks",
        ACHIEVEMENTS = "408 account-wide TBC, dungeon, profession, PvP and game goals",
        THEMES = "Spend account-wide Cresh Coins on premium themes",
    }
    drawer.subtitle:SetText(subtitles[mode] or "Cresh games")
    drawer.soloPanel:SetShown(mode == "SOLO")
    drawer.multiPanel:SetShown(mode == "MULTIPLAYER")
    if drawer.passPanel then drawer.passPanel:SetShown(mode == "BATTLEPASS") end
    if drawer.achievementPanel then drawer.achievementPanel:SetShown(mode == "ACHIEVEMENTS") end
    if drawer.themesPanel then drawer.themesPanel:SetShown(mode == "THEMES") end
    drawer.scan:SetShown(mode == "MULTIPLAYER")
    drawer.status:ClearAllPoints()
    drawer.status:SetPoint("TOPLEFT", drawer.statusBox, "TOPLEFT", 9, -6)
    if mode == "MULTIPLAYER" then
        drawer.status:SetPoint("BOTTOMRIGHT", drawer.statusBox, "BOTTOMRIGHT", -78, 6)
    else
        drawer.status:SetPoint("BOTTOMRIGHT", drawer.statusBox, "BOTTOMRIGHT", -9, 6)
    end
    self:SetTabButtonStyle(drawer.soloMode, mode == "SOLO", COLORS.blue, COLORS.blueHover, COLORS.panelRaised)
    self:SetTabButtonStyle(drawer.multiMode, mode == "MULTIPLAYER", COLORS.blue, COLORS.blueHover, COLORS.panelRaised)
    self:SetTabButtonStyle(drawer.passMode, mode == "BATTLEPASS", COLORS.quest, COLORS.quest, COLORS.panelRaised)
    self:SetTabButtonStyle(drawer.achievementMode, mode == "ACHIEVEMENTS", COLORS.quest, COLORS.quest, COLORS.panelRaised)
    self:SetTabButtonStyle(drawer.themesMode, mode == "THEMES", COLORS.green, COLORS.green, COLORS.panelRaised)
    local passHeight = (CC.BattlePass and CC.BattlePass.GetPassPanelHeight and CC.BattlePass:GetPassPanelHeight()) or 5910
    local achievementHeight = (CC.Achievements and CC.Achievements.GetPanelHeight and CC.Achievements:GetPanelHeight(drawer.achievementPanel and drawer.achievementPanel.searchText, drawer.achievementPanel and drawer.achievementPanel.category, drawer.achievementPanel and drawer.achievementPanel.status)) or 640
    local themeHeight = (CC.BattlePass and CC.BattlePass.GetThemePanelHeight and CC.BattlePass:GetThemePanelHeight()) or 640
    local heights = { SOLO = 720, MULTIPLAYER = 760, BATTLEPASS = passHeight, ACHIEVEMENTS = math.max(240, achievementHeight), THEMES = math.max(240, themeHeight) }
    drawer.content:SetHeight(heights[mode] or 620)
    if preserveScroll and previousMode == mode then
        self:SetGameDrawerScroll(savedScroll)
    else
        drawer.scroll:SetVerticalScroll(0)
    end
    self:RefreshGameDrawer()
    self:RefreshLauncherButtonStates()
end

function UI:SetGameDrawerScroll(value)
    local drawer = self.gameDrawer
    if not drawer or not drawer.scroll then return end
    local maximum = drawer.scroll:GetVerticalScrollRange() or 0
    if maximum <= 0 and drawer.content then
        maximum = max(0, (drawer.content:GetHeight() or 0) - (drawer.scroll:GetHeight() or 0))
    end
    drawer.scroll:SetVerticalScroll(max(0, min(maximum, tonumber(value) or 0)))
end

function UI:ScrollGameDrawerToTheme(theme)
    local drawer = self.gameDrawer
    if not drawer or drawer.mode ~= "THEMES" or not drawer.themeRows then return false end
    theme = string.upper(tostring(theme or ""))
    local row = drawer.themeRows[theme]
    if not row then return false end
    if not row.IsShown or not row:IsShown() then return false end
    local index = row.visibleThemeIndex or row.themeIndex or 1
    local rowTop = 122 + ((index - 1) * 98)
    local viewport = drawer.scroll and drawer.scroll:GetHeight() or 420
    local target = rowTop - max(14, (viewport - 90) / 2)
    self:SetGameDrawerScroll(target)
    return true
end

function UI:RefreshGameDrawer(silent)
    local drawer = self.gameDrawer
    if not drawer then return end
    local save = CC.SoloGames and CC.SoloGames.GetSave and CC.SoloGames:GetSave() or nil
    if save and drawer.soloCards then
        local stats = {
            FROGGER = string.format("Endless level %d · Best %d · Score %d", save.frogger.unlocked or 1, save.frogger.bestLevel or 0, save.frogger.highScore or 0),
            DUNGEON = string.format("Best room %d · %d bosses · %d minions", save.dungeon.bestRoom or save.dungeon.bestLevel or 0, save.dungeon.bosses or 0, save.dungeon.minions or 0),
            CHESS = string.format("Level %d · %d wins · %d draws", save.chess.level or 3, save.chess.wins or 0, save.chess.draws or 0),
            HOLDEM = string.format("Bankroll %s · %d wins", tostring(save.holdem.bankroll or 100), save.holdem.wins or 0),
            BLACKJACK = string.format("Bank %s · %d wins", tostring(save.blackjack.bankroll or 100), save.blackjack.wins or 0),
            HIGHERLOWER = string.format("Bank %s · Best streak %d", tostring(save.higherlower.bankroll or 100), save.higherlower.bestStreak or 0),
            TETRIS = string.format("High score %d · Best %d lines", save.tetris and save.tetris.highScore or 0, save.tetris and save.tetris.bestLines or 0),
        }
        for key, card in pairs(drawer.soloCards) do
            card.details:SetText(stats[key] or (card.info and card.info.desc) or "Single-player game")
            if CC.GameProgression then CC.GameProgression:UpdateBar(card.levelBar, card.levelText, key) end
        end
    end

    if CC.BattlePass and CC.BattlePass.RefreshDrawerPanel and drawer.passPanel then
        CC.BattlePass:RefreshDrawerPanel(drawer, {
            colors = COLORS,
            applyBackdrop = applyBackdrop,
            darken = darkenColor,
            setAccent = function(button, color, selected) UI:SetTabButtonStyle(button, selected == true, color, color, darkenColor(color, 0.45)) end,
        })
    end
    if CC.Achievements and CC.Achievements.RefreshDrawerPanel and drawer.achievementPanel then
        CC.Achievements:RefreshDrawerPanel(drawer, {
            colors = COLORS,
            applyBackdrop = applyBackdrop,
            darken = darkenColor,
            setAccent = function(button, color, selected) UI:SetTabButtonStyle(button, selected == true, color, color, darkenColor(color, 0.45)) end,
        }, false)
    end
    local games = CC.Games
    if games then
        local targets = games:GetTargets() or {}
        local selected
        for _, item in ipairs(targets) do
            if games.targetName and CC.WhisperNamesEquivalent and CC:WhisperNamesEquivalent(item.name, games.targetName) then selected = item; break end
            if games.targetName and string.lower(item.name) == string.lower(games.targetName) then selected = item; break end
        end
        if not selected and #targets > 0 then
            games.targetIndex = max(1, min(#targets, games.targetIndex or 1))
            selected = targets[games.targetIndex]
            games.targetName = selected.name
        end
        if selected then
            drawer.targetButton.label:SetText("TARGET: " .. string.upper(CC.ShortName and CC:ShortName(selected.name) or selected.name) .. (selected.addon and "  [CRESHCHAT]" or "  [?]"))
            setDrawerButtonEnabled(drawer.targetButton, true)
        else
            drawer.targetButton.label:SetText("NO PLAYERS FOUND")
            setDrawerButtonEnabled(drawer.targetButton, false)
        end
        local canChallenge = selected ~= nil and not games.active and not games.pendingOutgoing
        for key, card in pairs(drawer.multiCards or {}) do
            setDrawerButtonEnabled(card.challenge, canChallenge)
            if CC.GameProgression then CC.GameProgression:UpdateBar(card.levelBar, card.levelText, key) end
        end
        for index, row in ipairs(drawer.playerRows or {}) do
            local item = targets[index]
            if item then
                row.playerName = item.name
                local dot = item.addon and "●" or (item.online and "○" or "·")
                local source = tostring(item.source or "PLAYER")
                row.label:SetText(string.format("%s  %s   |cff7f8796%s|r%s", dot, CC.ShortName and CC:ShortName(item.name) or item.name, source, item.addon and "   |cff36d867ADDON READY|r" or ""))
                row:SetShown(true)
                row.creshSelected = selected and selected.name == item.name
                setBackground(row, row.creshSelected and darkenColor(COLORS.blue, 0.42) or COLORS.panelRaised)
            else
                row.playerName = nil
                row:Hide()
            end
        end
        if drawer.mode == "MULTIPLAYER" and not silent then
            if games.active then
                self:SetGameDrawerStatus("Active " .. games:GetGameName(games.active.game) .. " match with " .. (CC.ShortName and CC:ShortName(games.active.opponent) or games.active.opponent) .. ".", COLORS.green)
            elseif games.pendingOutgoing then
                self:SetGameDrawerStatus("Challenge sent. Waiting for " .. (CC.ShortName and CC:ShortName(games.pendingOutgoing.target) or games.pendingOutgoing.target) .. ".", COLORS.quest)
            elseif selected then
                self:SetGameDrawerStatus(selected.addon and "Addon detected. Choose a multiplayer game." or "Player found. Press SCAN to confirm they have CreshChat.", selected.addon and COLORS.green or COLORS.muted)
            else
                self:SetGameDrawerStatus("No players found. Friends, whisper contacts, party, raid and online guild players are scanned.", COLORS.muted)
            end
        elseif drawer.mode == "SOLO" and not silent then
            self:SetGameDrawerStatus("Choose a solo game. Completed games earn Pass Points and Cresh Coins.", COLORS.muted)
        elseif drawer.mode == "BATTLEPASS" and not silent then
            local level, current, required = 1, 0, 50
            if CC.BattlePass and CC.BattlePass.GetProgress then level, current, required = CC.BattlePass:GetProgress() end
            self:SetGameDrawerStatus(string.format("Battle Pass Level %d · %d / %d points toward the next unlock.", level or 1, current or 0, required or 50), COLORS.quest)
        elseif drawer.mode == "ACHIEVEMENTS" and not silent then
            local unlocked, total = 0, 0
            if CC.Achievements and CC.Achievements.GetCounts then unlocked, total = CC.Achievements:GetCounts() end
            self:SetGameDrawerStatus(string.format("%d of %d achievements unlocked. Higher tiers award more Battle Pass XP and Cresh Coins.", unlocked or 0, total or 0), COLORS.quest)
        elseif drawer.mode == "THEMES" and not silent then
            local wallet = CC.BattlePass and CC.BattlePass.GetWalletText and CC.BattlePass:GetWalletText() or "0"
            self:SetGameDrawerStatus(wallet .. " account-wide Cresh Coins available. Unlock a theme once, then equip it any time.", COLORS.green)
        end

    elseif drawer.mode == "BATTLEPASS" and not silent then
        local level, current, required = 1, 0, 50
        if CC.BattlePass and CC.BattlePass.GetProgress then level, current, required = CC.BattlePass:GetProgress() end
        self:SetGameDrawerStatus(string.format("Battle Pass Level %d · %d / %d points toward the next unlock.", level or 1, current or 0, required or 50), COLORS.quest)
    elseif drawer.mode == "ACHIEVEMENTS" and not silent then
        local unlocked, total = 0, 0
        if CC.Achievements and CC.Achievements.GetCounts then unlocked, total = CC.Achievements:GetCounts() end
        self:SetGameDrawerStatus(string.format("%d of %d achievements unlocked. Higher tiers award more Battle Pass XP and Cresh Coins.", unlocked or 0, total or 0), COLORS.quest)
    elseif drawer.mode == "THEMES" and not silent then
        local wallet = CC.BattlePass and CC.BattlePass.GetWalletText and CC.BattlePass:GetWalletText() or "0"
        self:SetGameDrawerStatus(wallet .. " account-wide Cresh Coins available. Unlock a theme once, then equip it any time.", COLORS.green)
    end
end

function UI:AnimateGameDrawer(open, immediate)
    local drawer = self:BuildGameDrawer(self:GetGameParent())
    if not drawer then return end
    if drawer.creshSlide then drawer:SetScript("OnUpdate", nil); drawer.creshSlide = nil end
    local width = drawer:GetWidth() or 350
    local side = open and self:GetGameDrawerSide() or (drawer.creshSide or self:GetGameDrawerSide())
    drawer.creshSide = side
    local closedX = side == "LEFT" and (width - 4) or (-width + 4)
    local openX = side == "LEFT" and -6 or 6
    if immediate then
        drawer.creshOpen = open == true
        self:UpdateTabAppearance()
        self:RefreshLauncherButtonStates()
        if open then drawer:Show(); self:PositionGameDrawer(openX, side) else self:PositionGameDrawer(closedX, side); drawer:Hide() end
        return
    end
    local from = drawer.creshOpen and openX or closedX
    local to = open and openX or closedX
    if open then drawer:Show() end
    drawer.creshOpen = open == true
    self:UpdateTabAppearance()
    self:RefreshLauncherButtonStates()
    local duration = max(0.12, min(0.26, self:GetAnimationDuration() * 1.05))
    local elapsedTotal = 0
    drawer.creshSlide = true
    drawer:SetScript("OnUpdate", function(selfDrawer, elapsed)
        elapsedTotal = elapsedTotal + (elapsed or 0)
        local progress = min(1, elapsedTotal / duration)
        local eased = 1 - ((1 - progress) * (1 - progress) * (1 - progress))
        local x = from + ((to - from) * eased)
        UI:PositionGameDrawer(x, side)
        selfDrawer:SetAlpha(open and (0.72 + 0.28 * eased) or (1 - 0.28 * eased))
        if progress >= 1 then
            selfDrawer:SetScript("OnUpdate", nil)
            selfDrawer.creshSlide = nil
            selfDrawer:SetAlpha(1)
            UI:PositionGameDrawer(to, side)
            if not open then selfDrawer:Hide() end
        end
    end)
end

function UI:OpenGameDrawer(mode, target)
    local gameParent = self:GetGameParent()
    if not gameParent then return end
    if target and CC.Games and CC.Games.SetTarget then CC.Games:SetTarget(target) end
    if self.main and not self.main:IsShown() then
        local openMode = self.mode
        if openMode == "GAMES" or not openMode then openMode = "FRIENDS" end
        self:OpenChannel(openMode, self.currentTarget)
    end
    self:BuildGameDrawer(gameParent)
    local resolvedMode = string.upper(tostring(mode or "SOLO"))
    self:SetGameDrawerMode(resolvedMode)
    self:RefreshGameDrawer()
    self:AnimateGameDrawer(true)
    if resolvedMode == "MULTIPLAYER" and CC.Games and CC.Games.ScanPeers then
        CC.Games:ScanPeers()
    end
end

function UI:CloseGameDrawer(immediate)
    if not self.gameDrawer then return end
    self:AnimateGameDrawer(false, immediate == true)
end

function UI:ToggleGameDrawer(mode, target)
    local drawer = self:BuildGameDrawer(self:GetGameParent())
    if drawer and drawer.creshOpen and drawer:IsShown() then
        self:CloseGameDrawer()
    else
        self:OpenGameDrawer(mode or (drawer and drawer.mode) or "SOLO", target)
    end
end

function UI:ModeSupportsRosterCollapse(mode)
    mode = string.upper(tostring(mode or self.mode or ""))
    if mode == "FRIENDS" or mode == "COMBAT" then return false end
    return mode == "WHISPER" or mode == "QUEST" or mode == "GUILD"
        or mode == "PARTY" or mode == "RAID" or mode == "INSTANCE"
        or self:IsGeneralFeedMode(mode)
end

function UI:IsRosterCollapsed(mode)
    return self:ModeSupportsRosterCollapse(mode) and (CC.db.ui or {}).rosterCollapsed == true
end

function UI:SetRosterCollapsed(collapsed)
    CC.db.ui = CC.db.ui or {}
    CC.db.ui.rosterCollapsed = collapsed and true or false
    if self.main and self.main:IsShown() then self:SetMode(self.mode, self.mode == "QUEST" and self.currentQuestTarget or self.currentTarget) end
end

function UI:ApplyRosterCollapseState()
    if not self.main or not self.conversationList or not self.mainView then return end
    local supported = self:ModeSupportsRosterCollapse(self.mode)
    local collapsed = supported and self:IsRosterCollapsed(self.mode)
    local toggle = self.main.rosterToggle
    if toggle then
        toggle:SetShown(supported)
        toggle.label:SetText(collapsed and ">" or "<")
        toggle:ClearAllPoints()
        if collapsed then toggle:SetPoint("LEFT", self.main.body, "LEFT", -1, 0)
        else toggle:SetPoint("CENTER", self.conversationList.container, "RIGHT", 0, 0) end
        toggle.creshCollapsed = collapsed
    end
    if not supported then return end
    if collapsed then
        self.conversationList.container:Hide()
        self.mainView.scroll:ClearAllPoints()
        self.mainView.scroll:SetPoint("TOPLEFT", self.main.body, "TOPLEFT", 0, 0)
        self.mainView.scroll:SetPoint("BOTTOMRIGHT", self.main.body, "BOTTOMRIGHT", 0, 0)
        self.mainView.fallbackWidth = 440
    else
        self.conversationList.container:Show()
        self.mainView.scroll:ClearAllPoints()
        self.mainView.scroll:SetPoint("TOPLEFT", self.conversationList.container, "TOPRIGHT", 8, 0)
        self.mainView.scroll:SetPoint("BOTTOMRIGHT", self.main.body, "BOTTOMRIGHT", 0, 0)
        self.mainView.fallbackWidth = 310
    end
end

function UI:RefreshWhisperContactSwitcher()
    if not self.mainView or not self.main or not self.main.body then return end
    local switcher = self.contactSwitcher
    local tabs = {}
    if self.mode == "WHISPER" and self.currentTarget and CC.GetWhisperContactTabs then tabs = CC:GetWhisperContactTabs(self.currentTarget) or {} end
    local show = switcher and #tabs >= 2

    self.mainView.scroll:ClearAllPoints()
    if self:IsRosterCollapsed(self.mode) then
        self.mainView.scroll:SetPoint("TOPLEFT", self.main.body, "TOPLEFT", 0, 0)
    else
        self.mainView.scroll:SetPoint("TOPLEFT", self.conversationList.container, "TOPRIGHT", 8, 0)
    end
    if show then self.mainView.scroll:SetPoint("BOTTOMRIGHT", switcher, "BOTTOMLEFT", -6, 0)
    else self.mainView.scroll:SetPoint("BOTTOMRIGHT", self.main.body, "BOTTOMRIGHT", 0, 0) end
    if not switcher then return end
    switcher:SetShown(show)
    for _, button in ipairs(switcher.buttons or {}) do button:Hide() end
    if not show then return end

    switcher:SetHeight(12 + (#tabs * 30))
    for index, tab in ipairs(tabs) do
        local button = switcher.buttons[index]
        if not button then
            button = createButton(switcher, "", 58, 24, function(selfButton)
                if selfButton.creshTarget then UI:SetMode("WHISPER", selfButton.creshTarget) end
            end)
            button:HookScript("OnEnter", function(selfButton)
                if not GameTooltip then return end
                GameTooltip:SetOwner(selfButton, "ANCHOR_LEFT")
                GameTooltip:SetText(selfButton.creshTitle or "Chat route")
                if selfButton.creshDescription then GameTooltip:AddLine(selfButton.creshDescription, 0.75, 0.78, 0.84, true) end
                GameTooltip:Show()
            end)
            button:HookScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
            switcher.buttons[index] = button
        end
        button.creshTarget = tab.target
        button.creshTitle = tab.label .. " CHAT"
        button.creshDescription = tab.description
        button.label:SetText(tab.label)
        button:ClearAllPoints()
        button:SetPoint("TOP", switcher, "TOP", 0, -7 - ((index - 1) * 30))
        self:SetTabButtonStyle(button, tab.active == true, COLORS.blue, COLORS.blueHover, COLORS.panelRaised)
        button:Show()
    end
end

function UI:LayoutMainHeader()
    local frame = self.main
    if not frame or not frame.header then return end

    -- The header uses two compact rows. Global navigation remains on the top row,
    -- while context actions (whisper, invite, call, pop-out) use the bottom row.
    -- This prevents a narrow console from forcing the title underneath buttons.
    local GAP, RIGHT_PAD = 5, 6
    local function anchorLeft(control, rightOf, gap, y)
        if not control then return rightOf end
        control:ClearAllPoints()
        control:SetPoint("RIGHT", rightOf, "LEFT", -(gap or GAP), y or 0)
        return control
    end
    local function controlWidth(control)
        if not control or not control.IsShown or not control:IsShown() then return 0 end
        return (control.GetWidth and control:GetWidth()) or 0
    end
    local function rowWidth(controls)
        local total, count = 0, 0
        for _, control in ipairs(controls) do
            local width = controlWidth(control)
            if width > 0 then
                total = total + width
                count = count + 1
            end
        end
        if count > 1 then total = total + ((count - 1) * GAP) end
        return total
    end

    local globalControls = { frame.close, frame.settings, frame.bpLevelBox, frame.gamesMenu }
    local contextControls = { frame.popout, frame.closeChat, frame.addFriend, frame.partyInvite, frame.voiceCall }

    frame.close:ClearAllPoints()
    frame.close:SetPoint("RIGHT", frame.header, "RIGHT", -RIGHT_PAD, 12)
    local globalCursor = anchorLeft(frame.settings, frame.close, GAP, 0)
    globalCursor = anchorLeft(frame.bpLevelBox, globalCursor, GAP, 0)
    globalCursor = anchorLeft(frame.gamesMenu, globalCursor, GAP, 0)

    local contextCursor = frame.header
    local previous = nil
    for _, control in ipairs(contextControls) do
        if control and control:IsShown() then
            control:ClearAllPoints()
            if not previous then
                control:SetPoint("RIGHT", frame.header, "RIGHT", -RIGHT_PAD, -12)
            else
                control:SetPoint("RIGHT", previous, "LEFT", -GAP, 0)
            end
            previous = control
            contextCursor = control
        end
    end

    -- Constrain the title against whichever row reaches furthest left.
    local globalWidth = rowWidth(globalControls)
    local contextWidth = rowWidth(contextControls)
    local titleBoundary = (contextWidth > globalWidth and contextCursor) or globalCursor

    frame.title:ClearAllPoints()
    frame.title:SetPoint("TOPLEFT", frame.logo, "TOPRIGHT", 8, -1)
    frame.title:SetPoint("TOPRIGHT", titleBoundary, "TOPLEFT", -8, -1)
    frame.title:SetWordWrap(false)
    frame.subtitle:ClearAllPoints()
    frame.subtitle:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -2)
    frame.subtitle:SetPoint("TOPRIGHT", titleBoundary, "TOPLEFT", -8, -2)
    frame.subtitle:SetWordWrap(false)

    if frame.buildBadge then
        frame.buildBadge:ClearAllPoints()
        frame.buildBadge:SetPoint("BOTTOMLEFT", frame.header, "BOTTOMLEFT", 220, 4)
        local available = (frame:GetWidth() or 0) - math.max(globalWidth, contextWidth) - 300
        frame.buildBadge:SetShown((CC.db.ui or {}).showBuildBadge == true and available >= 80)
    end
end

function UI:BuildMainFrame()
    local frame = CreateFrame("Frame", "CreshChatMainFrame", UIParent, templateName())
    applySize(frame, "main", 470, 520)
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:SetScale((CC.db.ui and CC.db.ui.scale) or CC.db.panelScale or 1)
    frame.creshClassicChrome = true
    applyBackdrop(frame, COLORS.panel, COLORS.border)
    frame:Hide()
    self.main = frame
    self:InstallWindowFocus(frame)

    -- Register the console as an Escape-closeable WoW special frame. The OnHide
    -- hook also closes the connected composer and Games/Battle Pass drawer so
    -- Escape always dismisses the complete console rather than leaving fragments.
    _G.UISpecialFrames = _G.UISpecialFrames or {}
    local registeredForEscape = false
    for _, frameName in ipairs(_G.UISpecialFrames) do
        if frameName == "CreshChatMainFrame" then registeredForEscape = true break end
    end
    if not registeredForEscape then tinsert(_G.UISpecialFrames, "CreshChatMainFrame") end
    frame:HookScript("OnHide", function()
        if UI.CloseGameDrawer then UI:CloseGameDrawer(true) end
        if UI.quickInput and UI.quickInput:IsShown() then
            if UI.quickInput.edit then UI.quickInput.edit:ClearFocus() end
            UI.quickInput:Hide()
        end
    end)

    frame.header = CreateFrame("Frame", nil, frame)
    frame.header:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    frame.header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
    frame.header:SetHeight(50)
    installShiftResize(frame, frame.header, "main", 410, 380, 760, 820, function()
        UI:SetSharedDockWidth(frame:GetWidth(), frame)
        UI:LayoutMainHeader()
        UI:LayoutMainTabs()
        UI:PositionGameDrawer()
        UI:RefreshAll()
    end)
    installSharedWidthGrips(frame)

    frame.logo = CreateFrame("Frame", nil, frame.header, templateName())
    frame.logo:SetSize(32, 32)
    frame.logo:SetPoint("LEFT", frame.header, "LEFT", 9, 0)
    applyBackdrop(frame.logo, COLORS.blue, COLORS.blue)
    frame.logoText = createFont(frame.logo, 14, COLORS.text, "CENTER")
    frame.logoText:SetAllPoints()
    frame.logoText:SetText(self:GetLauncherBaseText())
    frame.whisperPortrait = createCircularPortrait(frame.header, 32)
    frame.whisperPortrait:SetPoint("CENTER", frame.logo, "CENTER", 0, 0)
    frame.whisperPortrait:Hide()
    frame.guildCrest = createGuildCrest(frame.header, 32)
    frame.guildCrest:SetPoint("CENTER", frame.logo, "CENTER", 0, 0)
    frame.guildCrest:Hide()

    frame.title = createFont(frame.header, 13, COLORS.text, "LEFT")
    frame.title:SetPoint("TOPLEFT", frame.logo, "TOPRIGHT", 8, -1)
    frame.title:SetText("CRESHCHAT")
    frame.subtitle = createFont(frame.header, 9, COLORS.muted, "LEFT")
    frame.subtitle:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -2)
    frame.subtitle:SetText("Messenger overlay for TBC Anniversary")

    frame.topAccentBack = frame:CreateTexture(nil, "BACKGROUND")
    frame.topAccentBack:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    frame.topAccentBack:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
    frame.topAccentBack:SetHeight(4)
    frame.topAccentBack:SetColorTexture(COLORS.border[1], COLORS.border[2], COLORS.border[3], 0.65)
    frame.topAccent = CreateFrame("StatusBar", nil, frame)
    frame.topAccent:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    frame.topAccent:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
    frame.topAccent:SetHeight(4)
    frame.topAccent:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    frame.topAccent:SetMinMaxValues(0, 1)
    frame.topAccent:SetValue(0)
    frame.topAccent:SetStatusBarColor(COLORS.blue[1], COLORS.blue[2], COLORS.blue[3], 1)

    frame.buildBadge = CreateFrame("Frame", nil, frame.header, templateName())
    frame.buildBadge:SetSize(78, 22)
    frame.buildBadge:SetPoint("TOPLEFT", frame.header, "TOPLEFT", 220, -9)
    applyBackdrop(frame.buildBadge, COLORS.panelRaised, COLORS.border)
    frame.buildText = createFont(frame.buildBadge, 9, COLORS.blue, "CENTER")
    frame.buildText:SetAllPoints()
    frame.buildText:SetText(BUILD_LABEL)
    frame.buildBadge:SetShown((CC.db.ui or {}).showBuildBadge == true)

    frame.close = createButton(frame.header, "X", 24, 24, function()
        UI:CloseGameDrawer(true)
        frame:Hide()
    end)
    frame.close:SetPoint("RIGHT", frame.header, "RIGHT", -6, 0)

    frame.settings = createButton(frame.header, "...", 26, 24, function()
        if UI.OpenSettings then UI:OpenSettings() end
    end)
    frame.settings:SetPoint("RIGHT", frame.close, "LEFT", -5, 0)

    -- Keep Battle Pass progress with the rest of the header controls instead of
    -- floating below them.  The compact two-line button remains readable at the
    -- minimum console width and opens the Battle Pass drawer directly.
    frame.bpLevelBox = createButton(frame.header, "", 62, 24, function()
        local drawer = UI.gameDrawer
        if drawer and drawer.creshOpen and drawer:IsShown() and drawer.mode == "BATTLEPASS" then
            UI:CloseGameDrawer()
        else
            UI:OpenGameDrawer("BATTLEPASS", UI.mode == "WHISPER" and UI.currentTarget or nil)
        end
    end)
    frame.bpLevelBox:SetPoint("RIGHT", frame.settings, "LEFT", -5, 0)
    frame.bpLevelText = frame.bpLevelBox.label
    frame.bpLevelText:ClearAllPoints()
    frame.bpLevelText:SetPoint("TOPLEFT", frame.bpLevelBox, "TOPLEFT", 3, -1)
    frame.bpLevelText:SetPoint("TOPRIGHT", frame.bpLevelBox, "TOPRIGHT", -3, -1)
    frame.bpLevelText:SetHeight(12)
    frame.bpLevelText:SetFont(STANDARD_TEXT_FONT, 9, "")
    frame.coinText = createFont(frame.bpLevelBox, 7, COLORS.muted, "CENTER")
    frame.coinText:SetPoint("BOTTOMLEFT", frame.bpLevelBox, "BOTTOMLEFT", 3, 1)
    frame.coinText:SetPoint("BOTTOMRIGHT", frame.bpLevelBox, "BOTTOMRIGHT", -3, 1)
    frame.coinText:SetHeight(9)
    frame.bpLevelBox:HookScript("OnEnter", function(selfBox)
        if not GameTooltip or not CC.BattlePass then return end
        local level, current, required = CC.BattlePass:GetProgress()
        GameTooltip:SetOwner(selfBox, "ANCHOR_BOTTOMRIGHT")
        GameTooltip:SetText("Battle Pass Level " .. tostring(level or 1))
        GameTooltip:AddLine(tostring(current or 0) .. " / " .. tostring(required or 1) .. " XP", 0.75, 0.78, 0.84)
        GameTooltip:AddLine("Cresh Coins: " .. tostring(CC.BattlePass:GetWalletText()), 1, 0.82, 0.28)
        GameTooltip:AddLine("Click to open the Battle Pass.", 0.55, 0.72, 1)
        GameTooltip:Show()
    end)
    frame.bpLevelBox:HookScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

    frame.gamesMenu = createButton(frame.header, "GAMES", 48, 24, function()
        UI:ToggleGameDrawer("SOLO", UI.mode == "WHISPER" and UI.currentTarget or nil)
    end)
    frame.gamesMenu:SetPoint("RIGHT", frame.bpLevelBox, "LEFT", -5, 0)

    frame.popout = createButton(frame.header, "POP", 34, 24, function()
        UI:CreatePopout(UI.mode, UI.mode == "QUEST" and UI.currentQuestTarget or UI.currentTarget)
    end)
    frame.popout:SetPoint("RIGHT", frame.gamesMenu, "LEFT", -5, 0)

    frame.closeChat = createButton(frame.header, "X", 24, 24, function()
        UI:CloseWhisper(UI.currentTarget)
    end)
    frame.closeChat:SetPoint("RIGHT", frame.popout, "LEFT", -5, 0)
    frame.closeChat:Hide()

    frame.addFriend = createButton(frame.header, "ADD", 38, 24, function()
        if UI.mode == "FRIENDS" then UI:PromptAddFriend() else UI:AddWhisperFriend(UI.currentTarget) end
    end)
    frame.addFriend:SetPoint("RIGHT", frame.closeChat, "LEFT", -5, 0)
    frame.addFriend:HookScript("OnEnter", function(selfButton)
        if not GameTooltip then return end
        GameTooltip:SetOwner(selfButton, "ANCHOR_RIGHT")
        GameTooltip:SetText(UI.mode == "FRIENDS" and "Add friend" or "Add to friends")
        GameTooltip:AddLine(UI.mode == "FRIENDS" and "Add a character name or BattleTag." or "Adds this whisper contact to your WoW friends list.", 0.75, 0.78, 0.84, true)
        GameTooltip:Show()
    end)
    frame.addFriend:HookScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    frame.addFriend:Hide()

    frame.partyInvite = createButton(frame.header, "PARTY", 46, 24, function()
        UI:InviteWhisperTarget(UI.currentTarget)
    end)
    frame.partyInvite:SetPoint("RIGHT", frame.addFriend, "LEFT", -5, 0)
    frame.partyInvite.label:SetFont(STANDARD_TEXT_FONT, 8, "")
    frame.partyInvite:HookScript("OnEnter", function(selfButton)
        if not GameTooltip then return end
        GameTooltip:SetOwner(selfButton, "ANCHOR_RIGHT")
        GameTooltip:SetText("Invite to party")
        GameTooltip:AddLine("Invites the character in this whisper. Battle.net chats use the character currently logged into WoW.", 0.75, 0.78, 0.84, true)
        GameTooltip:Show()
    end)
    frame.partyInvite:HookScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    frame.partyInvite:Hide()

    frame.voiceCall = createButton(frame.header, "", 24, 24, function()
        if CC.Voice and CC.Voice.RequestCall then CC.Voice:RequestCall(UI.currentTarget) end
    end)
    frame.voiceCall:SetPoint("RIGHT", frame.partyInvite, "LEFT", -5, 0)
    frame.voiceCall.icon = frame.voiceCall:CreateTexture(nil, "ARTWORK")
    frame.voiceCall.icon:SetSize(15, 15)
    frame.voiceCall.icon:SetPoint("CENTER")
    frame.voiceCall.icon:SetTexture("Interface\\AddOns\\CreshChat\\Media\\Voice\\Microphone.tga")
    frame.voiceCall:HookScript("OnEnter", function(selfButton)
        if not GameTooltip then return end
        local target = UI.currentTarget
        local active = CC.Voice and CC.Voice.active and target and CC.WhisperNamesEquivalent and CC:WhisperNamesEquivalent(CC.Voice.active.target, target)
        local ready = CC.Voice and target and CC.Voice:IsPeerReady(target)
        GameTooltip:SetOwner(selfButton, "ANCHOR_RIGHT")
        GameTooltip:SetText(active and "End voice call" or "Start voice call")
        if not active then
            GameTooltip:AddLine(ready and "CreshChat detected for this player" or "The other player must have CreshChat", ready and 0.25 or 0.75, ready and 0.9 or 0.72, ready and 0.45 or 0.78, true)
        end
        GameTooltip:AddLine("Voice audio is handled by Blizzard voice chat.", 0.75, 0.78, 0.84, true)
        GameTooltip:Show()
    end)
    frame.voiceCall:HookScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    frame.voiceCall:Hide()

    frame.subtitle:SetPoint("BOTTOMRIGHT", frame.addFriend, "BOTTOMLEFT", -8, 3)
    if frame.title.SetWordWrap then
        frame.title:SetWordWrap(false)
    end

    frame.tabs = CreateFrame("Frame", nil, frame)
    frame.tabs:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -58)
    frame.tabs:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -58)
    frame.tabs:SetHeight(30)
    frame.tabs:EnableMouse(true)
    if frame.tabs.SetFrameLevel and frame.GetFrameLevel then frame.tabs:SetFrameLevel(frame:GetFrameLevel() + 20) end

    frame.consoleTabButtons = {}
    local function addConsoleTab(key, field, callback)
        local definition = CONSOLE_TAB_LOOKUP[key]
        local tab = createButton(frame.tabs, definition.label, 68, 26, callback or function() UI:SetMode(key) end)
        tab:EnableMouse(true)
        if tab.RegisterForClicks then tab:RegisterForClicks("LeftButtonUp") end
        if tab.SetFrameLevel and frame.tabs.GetFrameLevel then tab:SetFrameLevel(frame.tabs:GetFrameLevel() + 12) end
        tab.creshTabKey = key
        tab.creshTabLabel = definition.label
        frame[field] = tab
        frame.consoleTabButtons[key] = tab
        return tab
    end

    addConsoleTab("FRIENDS", "friendsTab", function() UI:SetMode("FRIENDS") end)
    addConsoleTab("WHISPER", "whisperTab", function() UI:SetMode("WHISPER", UI.currentTarget) end)
    frame.whisperBadge = createBadge(frame.whisperTab, 18)
    frame.whisperBadge:SetPoint("TOPRIGHT", frame.whisperTab, "TOPRIGHT", -2, -2)

    addConsoleTab("GUILD", "guildTab", function() UI:SetMode("GUILD") end)
    frame.guildBadge = createBadge(frame.guildTab, 18)
    frame.guildBadge:SetPoint("TOPRIGHT", frame.guildTab, "TOPRIGHT", -2, -2)

    addConsoleTab("GENERAL", "generalTab", function() UI:SetMode("GENERAL") end)
    frame.generalBadge = createBadge(frame.generalTab, 18)
    frame.generalBadge:SetPoint("TOPRIGHT", frame.generalTab, "TOPRIGHT", -2, -2)

    addConsoleTab("QUEST", "questTab", function() UI:SetMode("QUEST", UI.currentQuestTarget) end)
    frame.questBadge = createBadge(frame.questTab, 18)
    frame.questBadge:SetPoint("TOPRIGHT", frame.questTab, "TOPRIGHT", -2, -2)

    addConsoleTab("COMBAT", "combatTab", function() UI:SetMode("COMBAT") end)
    addConsoleTab("TRADE", "tradeTab")
    addConsoleTab("PARTY", "partyTab")
    addConsoleTab("RAID", "raidTab")
    addConsoleTab("INSTANCE", "instanceTab")
    addConsoleTab("LFG", "lfgTab")
    addConsoleTab("SAY", "sayTab")
    addConsoleTab("YELL", "yellTab")
    addConsoleTab("EMOTE", "emoteTab")
    addConsoleTab("LOCALDEFENSE", "localDefenseTab")

    self:LayoutMainTabs()

    self:LayoutMainHeader()
    frame.body = CreateFrame("Frame", nil, frame)
    frame.body:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -self:GetMainBodyTopOffset())
    frame.body:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 10)
    frame.guildWash = frame.body:CreateTexture(nil, "BACKGROUND")
    frame.guildWash:SetAllPoints()
    frame.guildWash:SetColorTexture(0.05, 0.34, 0.14, 0.12)
    frame.guildWash:Hide()

    self:BuildGameDrawer(frame)

    self.conversationList = {}
    self.conversationList.container = CreateFrame("Frame", nil, frame.body, templateName())
    self.conversationList.container:SetPoint("TOPLEFT", frame.body, "TOPLEFT", 0, 0)
    self.conversationList.container:SetPoint("BOTTOMLEFT", frame.body, "BOTTOMLEFT", 0, 0)
    self.conversationList.container:SetWidth(132)
    applyBackdrop(self.conversationList.container, COLORS.panelSoft, COLORS.panelSoft)

    frame.rosterToggle = createButton(frame.body, "<", 18, 44, function(selfButton)
        UI:SetRosterCollapsed(not selfButton.creshCollapsed)
    end)
    frame.rosterToggle:SetFrameLevel(frame.body:GetFrameLevel() + 20)
    frame.rosterToggle:HookScript("OnEnter", function(selfButton)
        if not GameTooltip then return end
        GameTooltip:SetOwner(selfButton, "ANCHOR_RIGHT")
        GameTooltip:SetText(selfButton.creshCollapsed and "Show player list" or "Hide player list")
        GameTooltip:AddLine(selfButton.creshCollapsed and "Restore the roster and conversation list." or "Give chat the full console width.", 0.75, 0.78, 0.84, true)
        GameTooltip:Show()
    end)
    frame.rosterToggle:HookScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    frame.rosterToggle:Hide()

    self.conversationList.scroll = CreateFrame("ScrollFrame", nil, self.conversationList.container)
    self.conversationList.scroll:SetPoint("TOPLEFT", self.conversationList.container, "TOPLEFT", 2, -2)
    self.conversationList.scroll:SetPoint("BOTTOMRIGHT", self.conversationList.container, "BOTTOMRIGHT", -2, 2)
    self.conversationList.scroll:EnableMouseWheel(true)
    self.conversationList.child = CreateFrame("Frame", nil, self.conversationList.scroll)
    self.conversationList.child:SetWidth(128)
    self.conversationList.child:SetHeight(1)
    self.conversationList.scroll:SetScrollChild(self.conversationList.child)
    self.conversationList.scroll:SetScript("OnMouseWheel", function(scroll, delta)
        local range = max(0, self.conversationList.child:GetHeight() - scroll:GetHeight())
        local current = scroll:GetVerticalScroll()
        scroll:SetVerticalScroll(min(range, max(0, current - delta * 45)))
    end)
    self.conversationButtons = {}

    self.mainView = self:CreateMessageView(frame.body)
    self.mainView.scroll:SetPoint("TOPLEFT", self.conversationList.container, "TOPRIGHT", 8, 0)
    self.mainView.scroll:SetPoint("BOTTOMRIGHT", frame.body, "BOTTOMRIGHT", 0, 0)
    self.mainView.fallbackWidth = 310

    self.contactSwitcher = CreateFrame("Frame", nil, frame.body, templateName())
    self.contactSwitcher:SetWidth(68)
    self.contactSwitcher:SetPoint("RIGHT", frame.body, "RIGHT", 0, 0)
    applyBackdrop(self.contactSwitcher, COLORS.panelSoft, COLORS.border)
    self.contactSwitcher.buttons = {}
    self.contactSwitcher:Hide()

    self.mainCombatView = self:CreateCombatView(frame.body)
    self.mainCombatView.scroll:SetPoint("TOPLEFT", frame.body, "TOPLEFT", 0, 0)
    self.mainCombatView.scroll:SetPoint("BOTTOMRIGHT", frame.body, "BOTTOMRIGHT", 0, 0)
    self.mainCombatView.fallbackWidth = 440
    self.mainCombatView.scroll:Hide()

    -- v0.2.5: the main overlay is read-only; messages and native slash commands use the single C-dock composer.
    self.mainInput = nil

    frame:SetScript("OnShow", function()
        UI.settingsPanel:Hide()
        UI:MarkCurrentRead()
        UI:RefreshAll()
        UI:ResolveWindowOverlaps(frame)
    end)

    self:BuildSettingsPanel(frame)
    applyPosition(frame, "main")
end

function UI:IsLauncherCombatHidden()
    local options = CC.db and CC.db.ui or {}
    if options.launcherHideInCombat ~= true then return false end
    if type(InCombatLockdown) == "function" and InCombatLockdown() then return true end
    if type(UnitAffectingCombat) == "function" and UnitAffectingCombat("player") then return true end
    return false
end

function UI:SetBubbleGroupShown(shown)
    shown = shown and true or false
    local options = CC.db.ui or {}
    local effectiveShown = shown and not self:IsLauncherCombatHidden()
    if self.bubble then self.bubble:SetShown(effectiveShown) end
    local expanded = options.launcherMode == "EXPANDED"
    if self.whisperBubble then self.whisperBubble:SetShown(effectiveShown and expanded and options.showWhisperButton ~= false) end
    if self.generalBubble then self.generalBubble:SetShown(effectiveShown and expanded and options.showGeneralButton ~= false) end
    if self.combatBubble then self.combatBubble:SetShown(effectiveShown and expanded and options.showCombatButton ~= false) end
    -- Module buttons are always visible when chat is disabled (they become the
    -- primary launcher); otherwise they follow EXPANDED mode + their own toggle.
    local chatOn     = CC.IsFeatureEnabled and CC:IsFeatureEnabled("chat")
    local gamesOn    = CC.IsFeatureEnabled and CC:IsFeatureEnabled("games")
    local achieveOn  = CC.IsFeatureEnabled and CC:IsFeatureEnabled("gameProgression")
    local progressOn = CC.ProgressHub and CC.ProgressHub:HasAnyEnabled()
    local showGames    = effectiveShown and gamesOn    and (not chatOn or (expanded and options.showGamesButton        == true))
    local showAchieve  = effectiveShown and achieveOn  and (not chatOn or (expanded and options.showAchievementsButton == true))
    local showProgress = effectiveShown and progressOn and (not chatOn or (expanded and options.showProgressButton     == true))
    if self.gamesButton    then self.gamesButton:SetShown(showGames    == true) end
    if self.achieveButton  then self.achieveButton:SetShown(showAchieve  == true) end
    if self.progressButton then self.progressButton:SetShown(showProgress == true) end
    if not shown and self.quickInput then self.quickInput:Hide() end
    if not shown and self.combatPanel then self.combatPanel:Hide() end
    self:PositionQuickButtons()
    if effectiveShown and self.RefreshLauncherVisibility then self:RefreshLauncherVisibility(true) end
end

function UI:PositionQuickButtons()
    if not self.bubble then return end
    local center = self.bubble:GetCenter()
    local screenWidth = UIParent:GetWidth() or 1
    local onRight = center and center > (screenWidth / 2)
    local ordered = {}
    local options = CC.db.ui or {}
    local expanded = options.launcherMode == "EXPANDED"
    if expanded and self.whisperBubble and options.showWhisperButton ~= false then tinsert(ordered, self.whisperBubble) end
    if expanded and self.generalBubble and options.showGeneralButton ~= false then tinsert(ordered, self.generalBubble) end
    if expanded and self.combatBubble and options.showCombatButton ~= false then tinsert(ordered, self.combatBubble) end

    local chatOn     = CC.IsFeatureEnabled and CC:IsFeatureEnabled("chat")
    local gamesOn    = CC.IsFeatureEnabled and CC:IsFeatureEnabled("games")
    local achieveOn  = CC.IsFeatureEnabled and CC:IsFeatureEnabled("gameProgression")
    local progressOn = CC.ProgressHub and CC.ProgressHub:HasAnyEnabled()
    local showGames    = gamesOn    and (not chatOn or (expanded and options.showGamesButton        == true))
    local showAchieve  = achieveOn  and (not chatOn or (expanded and options.showAchievementsButton == true))
    local showProgress = progressOn and (not chatOn or (expanded and options.showProgressButton     == true))
    if self.gamesButton    and showGames    then tinsert(ordered, self.gamesButton)    end
    if self.achieveButton  and showAchieve  then tinsert(ordered, self.achieveButton)  end
    if self.progressButton and showProgress then tinsert(ordered, self.progressButton) end

    local previous = self.bubble
    for _, button in ipairs(ordered) do
        button:ClearAllPoints()
        if onRight then
            button:SetPoint("RIGHT", previous, "LEFT", -6, 0)
        else
            button:SetPoint("LEFT", previous, "RIGHT", 6, 0)
        end
        previous = button
    end
    self:PositionQuickInput()
end

function UI:PositionCombatPanel()
    if not self.combatPanel or not self.bubble then return end
    local centerX, centerY = self.bubble:GetCenter()
    local screenWidth = UIParent:GetWidth() or 1
    local screenHeight = UIParent:GetHeight() or 1
    local onRight = centerX and centerX > (screenWidth / 2)
    local placeAbove = not centerY or centerY < (screenHeight * 0.58)
    self.combatPanel:ClearAllPoints()
    if placeAbove then
        if onRight then self.combatPanel:SetPoint("BOTTOMRIGHT", self.bubble, "TOPRIGHT", 0, 12)
        else self.combatPanel:SetPoint("BOTTOMLEFT", self.bubble, "TOPLEFT", 0, 12) end
    else
        if onRight then self.combatPanel:SetPoint("TOPRIGHT", self.bubble, "BOTTOMRIGHT", 0, -12)
        else self.combatPanel:SetPoint("TOPLEFT", self.bubble, "BOTTOMLEFT", 0, -12) end
    end
end

function UI:GetLatestWhisperTarget()
    if self.currentTarget and CC.db.history.whispers[self.currentTarget] then
        return self.currentTarget
    end
    if CC.state.lastWhisperTarget and CC.db.history.whispers[CC.state.lastWhisperTarget] then
        return CC.state.lastWhisperTarget
    end
    local sorted = self:GetSortedConversations()
    return sorted[1] and sorted[1].target or nil
end

function UI:SetQuickDestination(channel, target)
    channel = tostring(channel or "GENERAL")
    if channel == "COMBAT" then
        channel = "GENERAL"
    end
    if channel == "WHISPER" then
        target = target or self:GetLatestWhisperTarget()
        if not target then
            channel = "GENERAL"
        end
    elseif channel ~= "GUILD" and channel ~= "OFFICER" and not self:IsGeneralFeedMode(channel) then
        channel = "GENERAL"
    end

    self.quickChannel = channel
    self.quickTarget = channel == "WHISPER" and target or nil
    if CC.db then
        CC.db.quickChannel = channel
    end
    self:RefreshQuickInputLabel()
end

function UI:GetQuickDestination()
    local channel = self.quickChannel or (CC.db and CC.db.quickChannel) or "GENERAL"
    local target = self.quickTarget
    if channel == "WHISPER" then
        target = target or self:GetLatestWhisperTarget()
        if not target then
            channel = "GENERAL"
        end
    end
    return channel, target
end

function UI:RefreshQuickInputLabel()
    if not self.quickInput or not self.quickInput.channel then
        return
    end
    local channel, target = self:GetQuickDestination()
    local label
    if channel == "WHISPER" then
        label = "TO " .. string.upper(truncate(CC.GetWhisperDisplayName and CC:GetWhisperDisplayName(target) or CC:ShortName(target), 12))
    elseif channel == "OFFICER" then
        label = "OFFICER"
    else
        local compactLabels = { LOCALDEFENSE = "LOCAL", INSTANCE = "INSTANCE", GENERAL = "GENERAL" }
        label = compactLabels[channel] or channel
    end
    self.quickInput.channel.label:SetText(label)
    if self.quickInput.portrait then
        local showPortrait = (CC.db.ui or {}).composerShowPortrait ~= false
        if channel == "WHISPER" and target and showPortrait then
            local portraitMessage = self:GetWhisperPortraitMessage(target)
            self:UpdatePlayerPortrait(self.quickInput.portrait, target, portraitMessage.guid, portraitMessage)
            self.quickInput.portrait:Show()
            if self.quickInput.channelIcon then self.quickInput.channelIcon:Hide() end
        else
            self.quickInput.portrait:Hide()
            if self.quickInput.guildCrest then self.quickInput.guildCrest:Hide() end
            if channel == "GUILD" and self.quickInput.guildCrest and (CC.db.ui or {}).guildTheme ~= false then
                self:RefreshGuildCrest(self.quickInput.guildCrest)
                self.quickInput.guildCrest:Show()
                if self.quickInput.channelIcon then self.quickInput.channelIcon:Hide() end
            elseif self.quickInput.channelIcon then
                local iconText = self:IsZLRTheme() and "q3a" or (channel == "OFFICER" and "O" or (channel == "WHISPER" and "W" or "#"))
                self.quickInput.channelIcon:SetText(iconText)
                self.quickInput.channelIcon:Show()
            end
        end
    end
    local guildMode = channel == "GUILD" and (CC.db.ui or {}).guildTheme ~= false
    local accent = guildMode and GUILD_THEME.accent or COLORS.blue
    applyBackdrop(self.quickInput, guildMode and GUILD_THEME.panel or COLORS.panel, guildMode and GUILD_THEME.border or COLORS.border)
    if self.quickInput.edit then
        applyBackdrop(self.quickInput.edit, guildMode and GUILD_THEME.panelRaised or COLORS.panelRaised,
            guildMode and GUILD_THEME.border or COLORS.panelRaised)
    end
    if self.quickInput.accent then self.quickInput.accent:SetColorTexture(accent[1], accent[2], accent[3], 1) end
    if self.quickInput.channel then setBackground(self.quickInput.channel, guildMode and GUILD_THEME.accent or COLORS.panelRaised) end
    if self.quickInput.send then setBackground(self.quickInput.send, guildMode and GUILD_THEME.accent or COLORS.blue) end
    if self.quickInput.placeholder and self.quickInput.placeholder.SetTextColor then
        local placeholderColor = guildMode and GUILD_THEME.muted or COLORS.muted
        self.quickInput.placeholder:SetTextColor(placeholderColor[1], placeholderColor[2], placeholderColor[3], 1)
        self.quickInput.placeholder:SetText(self:IsZLRTheme() and "/say or /console" or "Message or /command...")
    end
end

function UI:CycleQuickDestination()
    local routes = {}
    for _, definition in ipairs(CONSOLE_TAB_DEFINITIONS) do
        local key = definition.key
        if self:IsConsoleTabEnabled(key) and self:IsGeneralFeedMode(key) then tinsert(routes, { channel = key }) end
    end
    if #routes == 0 then routes[1] = { channel = "GENERAL" } end
    if (not IsInGuild or IsInGuild()) and self:IsConsoleTabEnabled("GUILD") then
        tinsert(routes, { channel = "GUILD" })
    end
    local target = self:GetLatestWhisperTarget()
    if target and self:IsConsoleTabEnabled("WHISPER") then
        tinsert(routes, { channel = "WHISPER", target = target })
    end

    local currentChannel, currentTarget = self:GetQuickDestination()
    local currentIndex = 1
    for index, route in ipairs(routes) do
        if route.channel == currentChannel and (route.channel ~= "WHISPER" or route.target == currentTarget) then
            currentIndex = index
            break
        end
    end
    local nextRoute = routes[(currentIndex % #routes) + 1]
    self:SetQuickDestination(nextRoute.channel, nextRoute.target)
    if self.quickInput and self.quickInput.edit then
        self.quickInput.edit:SetFocus()
    end
end


function UI:GetDockButtonWidth()
    local options = CC.db and CC.db.ui or {}
    return max(38, min(64, floor((tonumber(options.dockButtonWidth) or 46) + 0.5)))
end

function UI:GetComposerScale()
    local scale = self.quickInput and self.quickInput.GetScale and self.quickInput:GetScale()
    if not scale or scale <= 0 then scale = tonumber((CC.db.ui or {}).composerScale) or 1 end
    return max(0.70, min(1.50, scale))
end

function UI:GetMainScale()
    local scale = self.main and self.main.GetScale and self.main:GetScale()
    if not scale or scale <= 0 then scale = tonumber((CC.db.ui or {}).scale) or 1 end
    return max(0.70, min(1.50, scale))
end

function UI:GetBubbleScale()
    local scale = self.bubble and self.bubble.GetScale and self.bubble:GetScale()
    if not scale or scale <= 0 then scale = 1 end
    return scale
end

function UI:GetDockHeight()
    local composerScale = self:GetComposerScale()
    local stored = CC.db and CC.db.sizes and CC.db.sizes.composer
    local rawHeight = self.quickInput and self.quickInput:GetHeight() or (stored and stored.height) or 46
    local visualHeight = (tonumber(rawHeight) or 46) * composerScale
    return max(42, min(64, floor(visualHeight + 0.5)))
end

-- sharedDockWidth is the final on-screen width, not the unscaled width of one
-- child frame. This is the source of truth used by C, the command bar and main.
function UI:GetComposerBodyWidth(totalVisualWidth)
    local total = max(320, min(720, tonumber(totalVisualWidth) or 470))
    local cVisual = self:GetDockButtonWidth() * self:GetBubbleScale()
    local composerScale = self:GetComposerScale()
    return max(180, (total - cVisual) / composerScale)
end

function UI:GetConnectedDockVisualWidth()
    return max(320, min(720, tonumber((CC.db.ui or {}).sharedDockWidth) or 470))
end

function UI:ApplyConnectedDockDimensions()
    if not CC.db then return end
    local totalVisual = self:GetConnectedDockVisualWidth()
    local mainScale = self:GetMainScale()
    local composerScale = self:GetComposerScale()
    local bubbleScale = self:GetBubbleScale()
    local cVisual = self:GetDockButtonWidth() * bubbleScale
    local visualHeight = self:GetDockHeight()

    if self.main then self.main:SetWidth(totalVisual / mainScale) end
    if self.bubble then
        self.bubble:SetSize(self:GetDockButtonWidth(), visualHeight / bubbleScale)
    end
    if self.quickInput then
        self.quickInput:SetSize(max(180, (totalVisual - cVisual) / composerScale), visualHeight / composerScale)
    end
    if self.whisperDockAlert then
        self.whisperDockAlert:SetHeight(visualHeight)
        self:PositionWhisperDockAlert()
    end
end

function UI:SetSharedDockWidth(width, sourceFrame)
    if not CC.db then return end
    local requestedVisual = tonumber(width) or 470
    if sourceFrame and sourceFrame == self.quickInput then
        requestedVisual = (requestedVisual * self:GetComposerScale())
            + (self:GetDockButtonWidth() * self:GetBubbleScale())
    elseif sourceFrame and sourceFrame == self.main then
        requestedVisual = requestedVisual * self:GetMainScale()
    elseif sourceFrame and sourceFrame == self.bubble then
        requestedVisual = (self.quickInput and self.quickInput:GetWidth() or 0) * self:GetComposerScale()
            + requestedVisual * self:GetBubbleScale()
    end

    local totalVisual = max(320, min(720, floor(requestedVisual + 0.5)))
    CC.db.ui = CC.db.ui or {}
    CC.db.sizes = CC.db.sizes or {}
    CC.db.ui.sharedDockWidth = totalVisual
    CC.db.ui.composerWidth = totalVisual

    self:ApplyConnectedDockDimensions()

    CC.db.sizes.main = CC.db.sizes.main or {}
    CC.db.sizes.composer = CC.db.sizes.composer or {}
    CC.db.sizes.main.width = self.main and self.main:GetWidth() or (totalVisual / self:GetMainScale())
    CC.db.sizes.composer.width = self.quickInput and self.quickInput:GetWidth() or self:GetComposerBodyWidth(totalVisual)
    if self.main then CC.db.sizes.main.height = floor((self.main:GetHeight() or 520) + 0.5) end
    if self.quickInput then CC.db.sizes.composer.height = floor((self.quickInput:GetHeight() or 46) + 0.5) end

    self:PositionQuickInput(true)
    if self.PositionMainFromComposer and self.main and self.main:IsShown() then self:PositionMainFromComposer() end
    if self.RefreshAll then self:RefreshAll() end
    if self.ResolveWindowOverlaps then self:ResolveWindowOverlaps(sourceFrame) end
end

function UI:SetPopoutWidth(width, sourceFrame)
    if not CC.db then return end
    width = max(300, min(620, floor((tonumber(width) or 400) + 0.5)))
    CC.db.ui = CC.db.ui or {}
    CC.db.sizes = CC.db.sizes or {}
    CC.db.ui.popoutWidth = width
    CC.db.sizes.popout = CC.db.sizes.popout or {}
    CC.db.sizes.popout.width = width
    for _, popout in pairs(self.popouts or {}) do
        popout:SetWidth(width)
        if self.ApplyPopoutLayout then self:ApplyPopoutLayout(popout) end
    end
    if self.RefreshPopouts then self:RefreshPopouts() end
    if self.ResolveWindowOverlaps then self:ResolveWindowOverlaps(sourceFrame) end
end

function UI:GetActivePopout()
    if self.activePopout and self.activePopout.IsShown and self.activePopout:IsShown() and self.activePopout.commandBar then
        return self.activePopout
    end
    local newest, newestOrder
    for _, popout in pairs(self.popouts or {}) do
        if popout:IsShown() and popout.commandBar then
            local order = tonumber(popout.creshLastActive) or tonumber(popout.creshOrder) or 0
            if not newest or order > newestOrder then newest, newestOrder = popout, order end
        end
    end
    self.activePopout = newest
    return newest
end

function UI:WakePopout(popout)
    if not popout then return end
    popout.creshFadeToken = (popout.creshFadeToken or 0) + 1
    popout:SetAlpha(1)
end

function UI:SchedulePopoutFade(popout)
    if not popout or not popout:IsShown() then return end
    local options = CC.db.ui or {}
    if options.popoutFade ~= true then popout:SetAlpha(1); return end
    popout.creshFadeToken = (popout.creshFadeToken or 0) + 1
    local token = popout.creshFadeToken
    local delay = max(1, min(15, tonumber(options.popoutFadeDelay) or 4))
    local fadedAlpha = max(0.08, min(0.95, tonumber(options.popoutFadeAlpha) or 0.22))
    local function fadeNow()
        if not popout:IsShown() or token ~= popout.creshFadeToken then return end
        local focused = popout.commandBar and popout.commandBar.edit and popout.commandBar.edit.HasFocus and popout.commandBar.edit:HasFocus()
        local hovered = MouseIsOver and MouseIsOver(popout)
        if focused or hovered then return end
        popout:SetAlpha(fadedAlpha)
    end
    if C_Timer and C_Timer.After then C_Timer.After(delay, fadeNow) end
end

function UI:SetActivePopout(popout)
    if not popout or not popout:IsShown() then return end
    self.popoutActivityCounter = (self.popoutActivityCounter or 0) + 1
    popout.creshLastActive = self.popoutActivityCounter
    self.activePopout = popout
    self:WakePopout(popout)
    self:FocusWindow(popout)
    -- Detached windows are deliberately independent. Clicking one never changes
    -- the connected C composer destination or makes Enter attach to the pop-out.
end

function UI:FocusPopoutCommand(popout, initialText)
    if not popout or not popout.commandBar or not popout.commandBar.edit then return false end
    self:SetActivePopout(popout)
    local edit = popout.commandBar.edit
    initialText = tostring(initialText or "")
    if initialText ~= "" then edit:SetText(initialText) end
    edit:SetFocus()
    edit:SetCursorPosition(string.len(edit:GetText() or ""))
    return true
end

function UI:GetPopoutStyle()
    local style = string.upper(tostring((CC.db.ui or {}).popoutStyle or "NORMAL"))
    return style == "COMPACT" and "COMPACT" or "NORMAL"
end

function UI:ApplyPopoutStyle(popout)
    if not popout or popout.channel == "COMBAT" then return end
    local style = self:GetPopoutStyle()
    if popout.compactView and popout.compactView.scroll then popout.compactView.scroll:SetShown(style == "COMPACT") end
    if popout.normalView and popout.normalView.scroll then popout.normalView.scroll:SetShown(style == "NORMAL") end
    popout.messageView = style == "COMPACT" and popout.compactView or popout.normalView
    popout.creshPopoutStyle = style
    self:ApplyPopoutLayout(popout)
end

function UI:RefreshPopoutStyles()
    for _, popout in pairs(self.popouts or {}) do
        if popout.channel ~= "COMBAT" then self:ApplyPopoutStyle(popout) end
    end
    self:RefreshPopouts()
end

function UI:ApplyPopoutLayout(popout)
    if not popout then return end
    local options = CC.db.ui or {}
    local rows = max(4, min(8, floor(tonumber(options.popoutRows) or 6)))
    local compactRowHeight = max(36, min(68, floor(tonumber(options.popoutRowHeight) or 44)))
    local style = popout.channel == "COMBAT" and "COMPACT" or self:GetPopoutStyle()
    local viewportHeight = style == "NORMAL" and (rows * 52) or (rows * compactRowHeight)
    local showCommand = options.popoutShowCommand ~= false and popout.channel ~= "COMBAT" and popout.channel ~= "QUEST"
    local headerHeight = 28
    local commandHeight = showCommand and 36 or 0
    local totalHeight = headerHeight + viewportHeight + commandHeight + 7
    popout:SetHeight(totalHeight)
    if popout.header then popout.header:SetHeight(headerHeight) end
    if popout.messageView and popout.messageView.scroll then
        popout.messageView.scroll:ClearAllPoints()
        popout.messageView.scroll:SetPoint("TOPLEFT", popout, "TOPLEFT", 4, -(headerHeight + 2))
        popout.messageView.scroll:SetPoint("TOPRIGHT", popout, "TOPRIGHT", -4, -(headerHeight + 2))
        popout.messageView.scroll:SetHeight(viewportHeight)
        if popout.messageView.fallbackWidth ~= nil then popout.messageView.fallbackWidth = max(220, (popout:GetWidth() or 400) - 8) end
    end
    if popout.commandBar then
        popout.commandBar:SetShown(showCommand)
        popout.commandBar:SetHeight(32)
        popout.commandBar:ClearAllPoints()
        popout.commandBar:SetPoint("BOTTOMLEFT", popout, "BOTTOMLEFT", 4, 4)
        popout.commandBar:SetPoint("BOTTOMRIGHT", popout, "BOTTOMRIGHT", -4, 4)
    end
end

function UI:PositionQuickInput(force)
    if not self.quickInput then return end
    local options = CC.db.ui or {}
    local attached = options.composerAttached ~= false or options.launcherMode == "SINGLE"
    if attached and self.bubble then
        local x = self.bubble:GetCenter()
        local screenWidth = UIParent:GetWidth() or 1
        local onRight = x and x > (screenWidth / 2)
        self.quickInput:ClearAllPoints()
        if onRight then
            self.quickInput:SetPoint("RIGHT", self.bubble, "LEFT", 0, 0)
        else
            self.quickInput:SetPoint("LEFT", self.bubble, "RIGHT", 0, 0)
        end
        self.quickInput.creshAttachedSide = onRight and "RIGHT" or "LEFT"
        if self.quickInput.accent then
            self.quickInput.accent:ClearAllPoints()
            if onRight then
                self.quickInput.accent:SetPoint("TOPLEFT", self.quickInput, "TOPLEFT", 1, -1)
                self.quickInput.accent:SetPoint("BOTTOMLEFT", self.quickInput, "BOTTOMLEFT", 1, 1)
            else
                self.quickInput.accent:SetPoint("TOPRIGHT", self.quickInput, "TOPRIGHT", -1, -1)
                self.quickInput.accent:SetPoint("BOTTOMRIGHT", self.quickInput, "BOTTOMRIGHT", -1, 1)
            end
        end
        self.quickInput.creshPositionApplied = true
    elseif force or not self.quickInput.creshPositionApplied then
        applyPosition(self.quickInput, "composer")
        self.quickInput.creshPositionApplied = true
        self.quickInput.creshAttachedSide = nil
    end
end

function UI:GetNativeCommandEditBox()
    if _G.ChatFrame1EditBox then return _G.ChatFrame1EditBox end
    if _G.DEFAULT_CHAT_FRAME and _G.DEFAULT_CHAT_FRAME.editBox then return _G.DEFAULT_CHAT_FRAME.editBox end
    local count = tonumber(_G.NUM_CHAT_WINDOWS) or 10
    for index = 1, count do
        local box = _G["ChatFrame" .. index .. "EditBox"]
        if box then return box end
    end
    return nil
end

function UI:RunSlashCommandFallback(text)
    local command, arguments = string.match(text or "", "^/(%S+)%s*(.-)%s*$")
    command = command and string.lower(command) or nil
    if not command or not _G.SlashCmdList then return false end
    for key, callback in pairs(_G.SlashCmdList) do
        if type(callback) == "function" then
            for index = 1, 20 do
                local alias = _G["SLASH_" .. key .. index]
                if not alias then break end
                alias = string.lower(string.gsub(alias, "^/", ""))
                if alias == command then
                    local ok, err = pcall(callback, arguments or "", self.quickInput and self.quickInput.edit)
                    if not ok then CC:Print("Command error: " .. tostring(err)) end
                    return ok
                end
            end
        end
    end
    return false
end

local CHAT_SLASH_ROUTES = {
    g = "GUILD", guild = "GUILD",
    o = "OFFICER", officer = "OFFICER", osay = "OFFICER",
    p = "PARTY", party = "PARTY",
    raid = "RAID", ra = "RAID", rsay = "RAID",
    rw = "RAID_WARNING", raidwarning = "RAID_WARNING",
    i = "INSTANCE", instance = "INSTANCE", bg = "BATTLEGROUND", battleground = "BATTLEGROUND",
    s = "SAY", say = "SAY",
    y = "YELL", yell = "YELL", sh = "YELL", shout = "YELL",
    e = "EMOTE", em = "EMOTE", me = "EMOTE", emote = "EMOTE",
}

function UI:HandleChatSlashCommand(text)
    local command, arguments = string.match(tostring(text or ""), "^/(%S+)%s*(.-)%s*$")
    command = command and string.lower(command) or nil
    if not command then return false, false end

    if command == "w" or command == "whisper" or command == "tell" or command == "t" or command == "send" then
        local target, message = string.match(arguments or "", "^(%S+)%s*(.-)%s*$")
        if not target or target == "" then
            CC:Print("Use /w PlayerName message")
            return true, false
        end
        target = CC:EnsureWhisperConversation(target)
        if not target then return true, false end
        self.currentTarget = target
        self:SetQuickDestination("WHISPER", target)
        if message == "" then
            self:SetMode("WHISPER", target)
            self:OpenQuickInput("", true)
            return true, true
        end
        return true, CC:SendMessage("WHISPER", target, message)
    end

    if command == "r" or command == "reply" then
        local target = CC.state.lastWhisperTarget or self.currentTarget or self:GetLatestWhisperTarget()
        if not target then
            CC:Print("There is no recent whisper to reply to.")
            return true, false
        end
        if tostring(arguments or "") == "" then
            self:BeginWhisper(target)
            return true, true
        end
        self:SetQuickDestination("WHISPER", target)
        return true, CC:SendMessage("WHISPER", target, arguments)
    end

    local channel = CHAT_SLASH_ROUTES[command]
    if channel then
        if tostring(arguments or "") == "" then
            self:SetQuickDestination(channel)
            CC:Print("Chat destination set to " .. channel .. ".")
            return true, true
        end
        self:SetQuickDestination(channel)
        return true, CC:SendMessage(channel, nil, arguments)
    end

    local channelNumber = tonumber(command)
    if channelNumber and channelNumber >= 1 and channelNumber <= 99 then
        if tostring(arguments or "") == "" then
            CC:Print("Use /" .. tostring(channelNumber) .. " message")
            return true, false
        end
        return true, CC:SendMessage("CHANNEL", channelNumber, arguments)
    end

    return false, false
end

function UI:ExecuteNativeSlashCommand(text)
    text = tostring(text or "")
    if string.sub(text, 1, 1) ~= "/" then return false end
    CC:AddCommandHistory(text)
    local handled, result = self:HandleChatSlashCommand(text)
    if handled then return result and true or false end

    local editBox = self:GetNativeCommandEditBox()
    local usedNative = false
    local ok, err = false, nil
    self.executingNativeCommand = true
    self.redirectingEditBox = true

    if editBox and editBox.SetText then
        if editBox.SetAttribute and editBox.GetAttribute and not editBox:GetAttribute("chatType") then editBox:SetAttribute("chatType", "SAY") end
        editBox:SetText(text)
        if editBox.SetCursorPosition then editBox:SetCursorPosition(string.len(text)) end
        if type(_G.ChatEdit_SendText) == "function" then
            usedNative = true
            ok, err = pcall(_G.ChatEdit_SendText, editBox, 1)
        elseif type(_G.ChatEdit_ParseText) == "function" then
            usedNative = true
            ok, err = pcall(_G.ChatEdit_ParseText, editBox, 1)
        end
    end

    if not usedNative then ok = self:RunSlashCommandFallback(text) end

    if editBox then
        if editBox.SetText then editBox:SetText("") end
        if editBox.ClearFocus then editBox:ClearFocus() end
        if editBox.Hide then editBox:Hide() end
    end
    self.redirectingEditBox = false
    self.executingNativeCommand = false
    if CC.HideBlizzardEditBoxes then CC:HideBlizzardEditBoxes() end

    if not ok then
        if usedNative and err then CC:Print("WoW could not run that command: " .. tostring(err))
        else CC:Print("WoW did not recognise that slash command.") end
    end
    return ok and true or false
end

function UI:SendQuickText(rawText)
    local text = tostring(rawText or "")
    text = string.gsub(text, "^%s+", "")
    text = string.gsub(text, "%s+$", "")
    if text == "" then return true end

    -- Every slash-prefixed entry is delegated to Blizzard's native command box.
    -- Commands are never inserted into CreshChat message history.
    if string.sub(text, 1, 1) == "/" then
        if CC.db and CC.db.ui and CC.db.ui.nativeSlashCommands == false then
            CC:Print("Native WoW slash commands are disabled in Settings > Features.")
            return false
        end
        return self:ExecuteNativeSlashCommand(text)
    end

    local channel, target = self:GetQuickDestination()
    return CC:SendMessage(channel, target, text)
end

function UI:CloseQuickInput(clearText)
    if not self.quickInput then
        return
    end
    if clearText and self.quickInput.edit then
        self.quickInput.edit:SetText("")
    end
    if self.quickInput.edit then
        self.quickInput.edit:ClearFocus()
    end
    self.quickInput:Hide()
end

function UI:ShowComposerFromLauncher()
    local bar = self.quickInput
    if not bar then return end
    self:PositionQuickInput(true)
    self:ShowAnimated(bar, (CC.db.ui or {}).composerAnimation or "SLIDE_DOCK", self.bubble)
end

function UI:OpenQuickInput(initialText, forceDock)
    if not self.quickInput then return end
    local options = CC.db.ui or {}
    if self.main and self.main:IsShown() and self.mode ~= "COMBAT" and self.mode ~= "QUEST" and self.mode ~= "FRIENDS" then
        self:SetQuickDestination(self.mode, self.currentTarget)
    elseif not self.quickChannel then
        self:SetQuickDestination((CC.db and CC.db.quickChannel) or "GENERAL")
    end
    self:PositionQuickInput(false)
    self:RefreshQuickInputLabel()
    self:ShowComposerFromLauncher()
    local edit = self.quickInput.edit
    initialText = tostring(initialText or "")
    if initialText ~= "" then edit:SetText(initialText) end
    edit:SetFocus()
    edit:SetCursorPosition(string.len(edit:GetText() or ""))
    self:ResolveWindowOverlaps(self.quickInput)
end

function UI:BuildQuickInput()
    local bar = CreateFrame("Frame", "CreshChatQuickInput", UIParent, templateName())
    applySize(bar, "composer", 424, 46)
    bar:SetFrameStrata("HIGH")
    bar:SetClampedToScreen(true)
    bar:SetMovable(true)
    bar:EnableMouse(true)
    bar.creshClassicChrome = true
    applyBackdrop(bar, COLORS.panel, COLORS.border)
    bar:Hide()
    self.quickInput = bar
    self:InstallWindowFocus(bar)

    bar.accent = bar:CreateTexture(nil, "ARTWORK")
    bar.accent:SetPoint("TOPLEFT", bar, "TOPLEFT", 1, -1)
    bar.accent:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 1, 1)
    bar.accent:SetWidth(3)
    bar.accent:SetColorTexture(COLORS.blue[1], COLORS.blue[2], COLORS.blue[3], 1)

    bar.drag = CreateFrame("Button", nil, bar)
    bar.drag:SetPoint("TOPLEFT", bar, "TOPLEFT", 4, -4)
    bar.drag:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 4, 4)
    bar.drag:SetWidth(12)
    bar.drag:RegisterForDrag("LeftButton")
    bar.dragText = createFont(bar.drag, 9, COLORS.muted, "CENTER")
    bar.dragText:SetAllPoints()
    bar.dragText:SetText("::")
    bar.drag:SetScript("OnDragStart", function()
        local options = CC.db.ui or {}
        if options.shiftResize ~= false and IsShiftKeyDown and IsShiftKeyDown() and bar.StartSizing then
            bar.creshSizing = true
            bar:StartSizing(bar.creshAttachedSide == "RIGHT" and "LEFT" or "RIGHT")
            return
        end
        if options.composerLocked or options.composerAttached ~= false or options.launcherMode == "SINGLE" then return end
        bar.creshSizing = false
        bar:StartMoving()
    end)
    bar.drag:SetScript("OnDragStop", function()
        bar:StopMovingOrSizing()
        savePosition(bar, "composer")
        saveSize(bar, "composer")
        UI:SetSharedDockWidth(bar:GetWidth(), bar)
        bar.creshPositionApplied = true
        UI:PositionQuickInput(true)
    end)

    bar.portrait = createCircularPortrait(bar, 28)
    bar.portrait:SetPoint("LEFT", bar.drag, "RIGHT", 4, 0)
    bar.channelIcon = createFont(bar, 13, COLORS.text, "CENTER")
    bar.channelIcon:SetSize(28, 28)
    bar.channelIcon:SetPoint("CENTER", bar.portrait, "CENTER", 0, 0)
    bar.guildCrest = createGuildCrest(bar, 28)
    bar.guildCrest:SetPoint("CENTER", bar.portrait, "CENTER", 0, 0)
    bar.guildCrest:Hide()

    bar.channel = createButton(bar, "GENERAL", 68, 30, function() UI:CycleQuickDestination() end)
    bar.channel:SetPoint("LEFT", bar.portrait, "RIGHT", 5, 0)
    bar.channel.label:SetFont(STANDARD_TEXT_FONT, 9, "")

    bar.edit = CreateFrame("EditBox", "CreshChatQuickEditBox", bar, templateName())
    bar.edit:SetAutoFocus(false)
    bar.edit:SetFont(STANDARD_TEXT_FONT, 12, "")
    bar.edit:SetTextColor(COLORS.text[1], COLORS.text[2], COLORS.text[3], 1)
    bar.edit:SetTextInsets(10, 8, 0, 0)
    bar.edit:SetMaxLetters(255)
    applyBackdrop(bar.edit, COLORS.panelRaised, COLORS.panelRaised)
    bar.edit:SetPoint("TOPLEFT", bar.channel, "TOPRIGHT", 6, 0)
    bar.edit:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -30, 8)

    bar.placeholder = createFont(bar.edit, 10, COLORS.muted, "LEFT")
    bar.placeholder:SetPoint("LEFT", bar.edit, "LEFT", 10, 0)
    bar.placeholder:SetText(self:IsZLRTheme() and "/say or /console" or "Message or /command...")

    bar.send = createButton(bar, ">", 28, 30, function()
        local sent = UI:SendQuickText(bar.edit:GetText())
        if sent then
            bar.edit:SetText("")
            if (CC.db.ui or {}).composerCloseAfterSend ~= false then UI:CloseQuickInput(true) else bar.edit:SetFocus() end
        end
    end)
    bar.send:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
    bar.send.label:SetFont(STANDARD_TEXT_FONT, 13, "")
    setBackground(bar.send, COLORS.blue)
    bar.send:SetShown((CC.db.ui or {}).composerShowSend ~= false)
    bar.edit:ClearAllPoints()
    bar.edit:SetPoint("TOPLEFT", bar.channel, "TOPRIGHT", 6, 0)
    bar.edit:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", (CC.db.ui or {}).composerShowSend == false and -6 or -36, 8)

    bar.edit:SetScript("OnTextChanged", function(selfEdit)
        local text = selfEdit:GetText() or ""
        bar.placeholder:SetShown(text == "")
        local isCommand = string.sub(text, 1, 1) == "/"
        if bar.channel and bar.channel.label then
            if isCommand then bar.channel.label:SetText("COMMAND") else UI:RefreshQuickInputLabel() end
        end
        -- Commands stay in the compact composer and never reveal or enter chat history.
        if text ~= "" and not isCommand and (CC.db.ui or {}).openMainOnType ~= false and not UI.main:IsShown() then
            UI:RevealMainFromComposer("TYPE")
        end
    end)
    bar.edit:SetScript("OnEnterPressed", function(selfEdit)
        local sent = UI:SendQuickText(selfEdit:GetText())
        if sent then
            selfEdit:SetText("")
            if (CC.db.ui or {}).composerCloseAfterSend ~= false then UI:CloseQuickInput(true) else selfEdit:SetFocus() end
        else selfEdit:SetFocus() end
    end)
    bar.edit:SetScript("OnEscapePressed", function() UI:CloseDockChat() end)
    bar.edit:SetScript("OnTabPressed", function(selfEdit)
        if string.sub(selfEdit:GetText() or "", 1, 1) ~= "/" then UI:CycleQuickDestination() end
    end)
    if bar.edit.SetAltArrowKeyMode then bar.edit:SetAltArrowKeyMode(false) end
    bar.edit:SetScript("OnArrowPressed", function(selfEdit, key)
        local currentText = selfEdit:GetText() or ""
        if currentText ~= "" and string.sub(currentText, 1, 1) ~= "/" and not bar.commandHistoryIndex then return end
        local history = CC:GetCommandHistory()
        if #history == 0 then return end
        if key == "UP" then
            bar.commandHistoryIndex = bar.commandHistoryIndex or (#history + 1)
            bar.commandHistoryIndex = max(1, bar.commandHistoryIndex - 1)
            selfEdit:SetText(history[bar.commandHistoryIndex] or "")
        elseif key == "DOWN" and bar.commandHistoryIndex then
            bar.commandHistoryIndex = min(#history + 1, bar.commandHistoryIndex + 1)
            selfEdit:SetText(bar.commandHistoryIndex <= #history and history[bar.commandHistoryIndex] or "")
        end
        selfEdit:SetCursorPosition(string.len(selfEdit:GetText() or ""))
    end)
    bar:SetScript("OnShow", function()
        bar.commandHistoryIndex = nil
        UI:PositionQuickInput(false)
        UI:RefreshQuickInputLabel()
    end)

    configureResizeBounds(bar, 180, 28, 680, 92)
    installSharedWidthGrips(bar)
    self:SetQuickDestination((CC.db and CC.db.quickChannel) or "GENERAL")
    self:PositionQuickInput(true)
end

function UI:BeginWhisper(target, initialText)
    target = CC:EnsureWhisperConversation(target)
    if not target then
        return
    end

    CC.state.whisperRedirects = (CC.state.whisperRedirects or 0) + 1
    self.currentTarget = target
    self:SetQuickDestination("WHISPER", target)
    self:SetMode("WHISPER", target)
    self:OpenQuickInput(initialText or "", true)
    self:RevealMainFromComposer("WHISPER")
    if self.quickInput and self.quickInput.edit then
        self.quickInput.edit:SetFocus()
    end
    if CC.HideBlizzardEditBoxes then
        CC:HideBlizzardEditBoxes()
    end
end

local function cleanCommandOutput(text)
    text = tostring(text or "")
    text = string.gsub(text, "|c%x%x%x%x%x%x%x%x", "")
    text = string.gsub(text, "|r", "")
    text = string.gsub(text, "|H.-|h(.-)|h", "%1")
    text = string.gsub(text, "|T.-|t", "")
    return text
end

function UI:GetBlizzardEditRoute(editBox)
    if not editBox or not editBox.GetAttribute then
        return nil, nil
    end
    local chatType = editBox:GetAttribute("chatType")
    local target = editBox:GetAttribute("tellTarget") or editBox:GetAttribute("channelTarget")
    return chatType, target
end

function UI:RedirectBlizzardEditBox(editBox)
    if self.executingNativeCommand then return end
    if not CC.db or not (CC.ShouldHideBlizzardChat and CC:ShouldHideBlizzardChat()) or not self.initialized then
        return
    end
    local chatType, target = self:GetBlizzardEditRoute(editBox)
    local initialText = editBox and editBox.GetText and editBox:GetText() or ""

    if chatType == "WHISPER" and target and target ~= "" then
        self:BeginWhisper(target, initialText)
        return
    end

    if chatType == "GUILD" or chatType == "OFFICER" then
        self:SetQuickDestination(chatType)
    elseif chatType == "CHANNEL" then
        self:SetQuickDestination("GENERAL")
    end
    self:OpenQuickInput(initialText)
    if CC.HideBlizzardEditBoxes then
        CC:HideBlizzardEditBoxes()
    end
end

function UI:GetUnitWhisperTarget(unit, fallbackName)
    local target = ""
    if unit and UnitExists and UnitExists(unit) then
        if type(GetUnitName) == "function" then
            local ok, fullName = pcall(GetUnitName, unit, true)
            if ok and fullName and fullName ~= "" then target = fullName end
        end
        if target == "" and type(UnitFullName) == "function" then
            local ok, name, realm = pcall(UnitFullName, unit)
            if ok and name and name ~= "" then
                target = name
                if realm and realm ~= "" then target = name .. "-" .. string.gsub(realm, "%s+", "") end
            end
        end
        if target == "" and type(UnitName) == "function" then
            local ok, name, realm = pcall(UnitName, unit)
            if ok and name and name ~= "" then
                target = name
                if realm and realm ~= "" then target = name .. "-" .. string.gsub(realm, "%s+", "") end
            end
        end
    end
    if target == "" then target = tostring(fallbackName or "") end
    target = CC:CleanPlayerName(target)
    if target ~= "" and not CC:IsSelf(target) then return target end
    return nil
end

function UI:CacheUnitPopupWhisperTarget(dropdownMenu, unit, name)
    local target = self:GetUnitWhisperTarget(unit or (dropdownMenu and dropdownMenu.unit), name or (dropdownMenu and dropdownMenu.name))
    if target then
        self.lastUnitPopupWhisperTarget = target
        self.lastUnitPopupWhisperAt = GetTime and GetTime() or 0
        if dropdownMenu then dropdownMenu.creshWhisperTarget = target end
    end
    return target
end

function UI:ResolveUnitPopupWhisperTarget(button)
    local menus = {
        button and button.owner,
        button and button.dropdownFrame,
        _G.UIDROPDOWNMENU_INIT_MENU,
        _G.UIDROPDOWNMENU_OPEN_MENU,
    }
    for _, menu in ipairs(menus) do
        if menu then
            local target = menu.creshWhisperTarget or self:GetUnitWhisperTarget(menu.unit, menu.name)
            if target then return target end
        end
    end
    if button then
        local target = self:GetUnitWhisperTarget(button.unit, button.name or button.arg2)
        if target then return target end
    end
    local age = (GetTime and GetTime() or 0) - (tonumber(self.lastUnitPopupWhisperAt) or 0)
    if self.lastUnitPopupWhisperTarget and age < 20 then return self.lastUnitPopupWhisperTarget end
    return nil
end

function UI:InstallBlizzardChatRedirects()
    if not hooksecurefunc then return false end

    if not self.sendTellRedirectHooked and type(ChatFrame_SendTell) == "function" then
        local ok = pcall(hooksecurefunc, "ChatFrame_SendTell", function(target)
            if CC.ShouldHideBlizzardChat and CC:ShouldHideBlizzardChat() and target and target ~= "" and UI.initialized then
                UI:BeginWhisper(target)
            end
        end)
        self.sendTellRedirectHooked = ok and true or false
    end

    if not self.replyTellRedirectHooked and type(ChatFrame_ReplyTell) == "function" then
        local ok = pcall(hooksecurefunc, "ChatFrame_ReplyTell", function()
            if CC.ShouldHideBlizzardChat and CC:ShouldHideBlizzardChat() and UI.initialized then
                local target = CC.state.lastWhisperTarget
                if target then UI:BeginWhisper(target) end
            end
        end)
        self.replyTellRedirectHooked = ok and true or false
    end

    if not self.activateChatRedirectHooked and type(ChatEdit_ActivateChat) == "function" then
        local ok = pcall(hooksecurefunc, "ChatEdit_ActivateChat", function(editBox)
            if not UI.executingNativeCommand and CC.ShouldHideBlizzardChat and CC:ShouldHideBlizzardChat() and UI.initialized then
                UI:RedirectBlizzardEditBox(editBox)
            end
        end)
        self.activateChatRedirectHooked = ok and true or false
    end

    if not self.unitPopupShowHooked and type(UnitPopup_ShowMenu) == "function" then
        local ok = pcall(hooksecurefunc, "UnitPopup_ShowMenu", function(dropdownMenu, _, unit, name)
            if UI.initialized then UI:CacheUnitPopupWhisperTarget(dropdownMenu, unit, name) end
        end)
        self.unitPopupShowHooked = ok and true or false
    end

    if not self.dropdownTargetHooked and type(ToggleDropDownMenu) == "function" then
        local ok = pcall(hooksecurefunc, "ToggleDropDownMenu", function(_, _, dropdownMenu)
            if UI.initialized and dropdownMenu then UI:CacheUnitPopupWhisperTarget(dropdownMenu, dropdownMenu.unit, dropdownMenu.name) end
        end)
        self.dropdownTargetHooked = ok and true or false
    end

    if not self.unitPopupClickHooked and type(UnitPopup_OnClick) == "function" then
        local ok = pcall(hooksecurefunc, "UnitPopup_OnClick", function(button)
            if not (CC.ShouldHideBlizzardChat and CC:ShouldHideBlizzardChat() and UI.initialized) then return end
            local value = string.upper(tostring(button and (button.value or button.arg1) or ""))
            if value == "WHISPER" or value == "WHISPER_TARGET" or value == "PLAYER_WHISPER" then
                local target = UI:ResolveUnitPopupWhisperTarget(button)
                if target then
                    UI:BeginWhisper(target)
                    if CC.HideBlizzardEditBoxes then CC:HideBlizzardEditBoxes() end
                end
            end
        end)
        self.unitPopupClickHooked = ok and true or false
    end

    -- Addon and Blizzard commands commonly write synchronously to DEFAULT_CHAT_FRAME.
    -- While a native command is executing, mirror that output into a themed CreshChat card.
    if not self.commandOutputHooked and _G.DEFAULT_CHAT_FRAME and type(_G.DEFAULT_CHAT_FRAME.AddMessage) == "function" then
        local ok = pcall(hooksecurefunc, _G.DEFAULT_CHAT_FRAME, "AddMessage", function(_, text)
            if UI.executingNativeCommand and CC.db and CC.db.ui and CC.db.ui.showSystemCards ~= false then
                local clean = cleanCommandOutput(text)
                if clean ~= "" and UI.ShowSystemToast then UI:ShowSystemToast("Command output", clean, "INFO") end
            end
        end)
        self.commandOutputHooked = ok and true or false
    end

    self.blizzardChatRedirectsInstalled = self.sendTellRedirectHooked or self.unitPopupClickHooked or self.activateChatRedirectHooked or false
    return self.blizzardChatRedirectsInstalled
end

function UI:InstallEditBoxWatchers()
    if self.editBoxWatchersInstalled then return end
    self.editBoxWatchersInstalled = true
    for index = 1, 10 do
        local editBox = _G["ChatFrame" .. index .. "EditBox"]
        if editBox and editBox.HookScript then
            editBox:HookScript("OnShow", function(box)
                if UI.executingNativeCommand or UI.redirectingEditBox or not (CC.ShouldHideBlizzardChat and CC:ShouldHideBlizzardChat() and UI.initialized) then return end
                UI.redirectingEditBox = true
                UI:RedirectBlizzardEditBox(box)
                if box.Hide then box:Hide() end
                UI.redirectingEditBox = false
            end)
        end
    end
end

function UI:InstallEnterChatHook()
    if self.enterChatHooked then
        self:InstallEditBoxWatchers()
        return
    end
    if hooksecurefunc and ChatFrame_OpenChat then
        hooksecurefunc("ChatFrame_OpenChat", function(initialText)
            if CC.ShouldHideBlizzardChat and CC:ShouldHideBlizzardChat() and UI.initialized then
                UI:OpenQuickInput(initialText)
                if CC.HideBlizzardEditBoxes then CC:HideBlizzardEditBoxes() end
            end
        end)
        self.enterChatHooked = true
    end
    if hooksecurefunc and type(ChatEdit_OnShow) == "function" then
        hooksecurefunc("ChatEdit_OnShow", function(editBox)
            if not UI.executingNativeCommand and CC.ShouldHideBlizzardChat and CC:ShouldHideBlizzardChat() and UI.initialized and editBox then
                UI:RedirectBlizzardEditBox(editBox)
            end
        end)
        self.enterChatHooked = true
    end
    self:InstallEditBoxWatchers()
end


function UI:BuildWhisperDockAlert()
    if self.whisperDockAlert then return end
    local chip = CreateFrame("Button", "CreshChatWhisperDockAlert", UIParent, templateName())
    chip:SetSize(max(150, min(280, tonumber((CC.db.ui or {}).dockWhisperWidth) or 190)), self:GetDockHeight())
    chip:SetFrameStrata("TOOLTIP")
    chip:SetClampedToScreen(true)
    chip:EnableMouse(true)
    applyBackdrop(chip, COLORS.panel, COLORS.border)
    chip.accent = chip:CreateTexture(nil, "ARTWORK")
    chip.accent:SetPoint("TOPLEFT", chip, "TOPLEFT", 1, -1)
    chip.accent:SetPoint("BOTTOMLEFT", chip, "BOTTOMLEFT", 1, 1)
    chip.accent:SetWidth(3)
    local whisperColor = (CC.db.colors and CC.db.colors.channels and CC.db.colors.channels.WHISPER) or COLORS.blue
    chip.accent:SetColorTexture(whisperColor[1], whisperColor[2], whisperColor[3], 1)
    chip.portrait = createCircularPortrait(chip, 30)
    chip.portrait:SetPoint("LEFT", chip, "LEFT", 8, 0)
    chip.name = createFont(chip, 11, COLORS.text, "LEFT")
    chip.name:SetPoint("TOPLEFT", chip.portrait, "TOPRIGHT", 8, -2)
    chip.name:SetPoint("RIGHT", chip, "RIGHT", -8, 0)
    chip.preview = createFont(chip, 9, COLORS.muted, "LEFT")
    chip.preview:SetPoint("TOPLEFT", chip.name, "BOTTOMLEFT", 0, -1)
    chip.preview:SetPoint("RIGHT", chip, "RIGHT", -8, 0)
    chip.preview:SetHeight(13)
    chip:SetScript("OnClick", function(selfChip)
        local target = selfChip.target
        UI:DismissWhisperDockAlert(true)
        if target then
            target = CC:EnsureWhisperConversation(target)
            UI.currentTarget = target
            UI:SetQuickDestination("WHISPER", target)
            UI:SetMode("WHISPER", target)
            UI:OpenQuickInput("", true)
            UI:RevealMainFromComposer("WHISPER_ALERT")
            if UI.quickInput and UI.quickInput.edit then UI.quickInput.edit:SetFocus() end
        end
    end)
    chip:SetScript("OnEnter", function(selfChip) selfChip.hovered = true; selfChip:SetAlpha(1) end)
    chip:SetScript("OnLeave", function(selfChip) selfChip.hovered = false; selfChip.expiresAt = GetTime() + 1.25 end)
    chip:Hide()
    self.whisperDockAlert = chip
end

function UI:GetWhisperDockAlertTargetPosition()
    local chip, bubble = self.whisperDockAlert, self.bubble
    if not chip or not bubble then return 18, 92 end
    local width = max(150, min(280, tonumber((CC.db.ui or {}).dockWhisperWidth) or 190))
    local height = self:GetDockHeight()
    chip:SetSize(width, height)
    local screenWidth, screenHeight = UIParent:GetWidth() or 1920, UIParent:GetHeight() or 1080
    local bubbleCenter = bubble:GetCenter()
    local preferLeft = bubbleCenter and bubbleCenter > screenWidth / 2
    local leftEdge, rightEdge = bubble:GetLeft() or 18, bubble:GetRight() or 64
    if self.quickInput and self.quickInput:IsShown() then
        leftEdge = min(leftEdge, self.quickInput:GetLeft() or leftEdge)
        rightEdge = max(rightEdge, self.quickInput:GetRight() or rightEdge)
    end
    local leftSpace, rightSpace = leftEdge - 10, screenWidth - rightEdge - 10
    if preferLeft and leftSpace < width and rightSpace >= width then preferLeft = false end
    if not preferLeft and rightSpace < width and leftSpace >= width then preferLeft = true end
    local x
    local y = (bubble:GetBottom() or 92) + ((bubble:GetHeight() or height) - height) / 2
    if leftSpace < width and rightSpace < width then
        x = max(4, min(screenWidth - width - 4, leftEdge))
        y = min(screenHeight - height - 4, (bubble:GetTop() or y) + 8)
    else
        x = preferLeft and (leftEdge - width - 6) or (rightEdge + 6)
    end
    x = max(4, min(screenWidth - width - 4, x))
    y = max(4, min(screenHeight - height - 4, y))
    return x, y
end

function UI:PositionWhisperDockAlert()
    local chip = self.whisperDockAlert
    if not chip or not chip:IsShown() then return end
    local x, y = self:GetWhisperDockAlertTargetPosition()
    chip.targetX, chip.targetY = x, y
end

function UI:ShowWhisperDockAlert(target, message)
    if (CC.db.ui or {}).showDockWhisperAlert == false then return end
    self:BuildWhisperDockAlert()
    local chip = self.whisperDockAlert
    target = CC:ResolveWhisperConversation(target or (message and message.sender))
    if not target then return end
    chip.target = target
    chip.name:SetText(CC.GetWhisperDisplayName and CC:GetWhisperDisplayName(target) or CC:ShortName(target))
    chip.preview:SetText(truncate(message and message.text or "New whisper", 42))
    self:UpdatePlayerPortrait(chip.portrait, target, message and message.guid, message)
    local whisperColor = (CC.db.colors and CC.db.colors.channels and CC.db.colors.channels.WHISPER) or COLORS.blue
    chip.accent:SetColorTexture(whisperColor[1], whisperColor[2], whisperColor[3], 1)
    local targetX, targetY = self:GetWhisperDockAlertTargetPosition()
    local sourceX = (self.bubble and self.bubble:GetLeft()) or targetX
    local sourceY = (self.bubble and self.bubble:GetBottom()) or targetY
    chip.targetX, chip.targetY = targetX, targetY
    chip.currentX, chip.currentY = sourceX, sourceY
    chip.expiresAt = GetTime() + max(3, min(15, tonumber((CC.db.ui or {}).dockWhisperDuration) or 6))
    chip.hovered, chip.dismissing = false, false
    chip:SetAlpha(0)
    chip:ClearAllPoints(); chip:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", sourceX, sourceY)
    chip:Show()
    chip:SetScript("OnUpdate", function(selfChip, elapsed)
        elapsed = min(0.05, elapsed or 0)
        if selfChip.dismissing then
            selfChip.currentX = (selfChip.currentX or selfChip.targetX) + (((self.bubble and self.bubble:GetLeft()) or selfChip.targetX) - (selfChip.currentX or selfChip.targetX)) * min(1, elapsed * 16)
            selfChip:SetAlpha(max(0, selfChip:GetAlpha() - elapsed * 6))
            selfChip:ClearAllPoints(); selfChip:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", selfChip.currentX, selfChip.currentY or selfChip.targetY)
            if selfChip:GetAlpha() <= 0.03 then UI:DismissWhisperDockAlert(true) end
            return
        end
        UI:PositionWhisperDockAlert()
        selfChip.currentX = (selfChip.currentX or selfChip.targetX) + ((selfChip.targetX - (selfChip.currentX or selfChip.targetX)) * min(1, elapsed * 15))
        selfChip.currentY = (selfChip.currentY or selfChip.targetY) + ((selfChip.targetY - (selfChip.currentY or selfChip.targetY)) * min(1, elapsed * 15))
        selfChip:SetAlpha(min(1, selfChip:GetAlpha() + elapsed * 7))
        selfChip:ClearAllPoints(); selfChip:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", selfChip.currentX, selfChip.currentY)
        if not selfChip.hovered and GetTime() >= (selfChip.expiresAt or 0) then selfChip.dismissing = true end
    end)
end

function UI:DismissWhisperDockAlert(immediate)
    local chip = self.whisperDockAlert
    if not chip then return end
    if immediate then chip:SetScript("OnUpdate", nil); chip:Hide(); chip.target = nil; chip.dismissing = false
    else chip.dismissing = true end
end

-- Returns the destination the C button should act on, given launcherDefault and
-- which features are actually enabled. Knows about: CHAT, GAMES, ACHIEVEMENTS,
-- PROGRESS, SETTINGS.
function UI:GetLauncherEffectiveDest()
    local options = CC.db and CC.db.ui or {}
    local dest = options.launcherDefault or "LAST"
    if dest == "LAST" then dest = options.lastLauncherDest end
    local chatOn     = CC.IsFeatureEnabled and CC:IsFeatureEnabled("chat")
    local gamesOn    = CC.IsFeatureEnabled and CC:IsFeatureEnabled("games")
    local achieveOn  = CC.IsFeatureEnabled and CC:IsFeatureEnabled("gameProgression")
    local progressOn = CC.ProgressHub and CC.ProgressHub:HasAnyEnabled()
    if dest == "CHAT"         and not chatOn     then dest = nil end
    if dest == "GAMES"        and not gamesOn    then dest = nil end
    if dest == "ACHIEVEMENTS" and not achieveOn  then dest = nil end
    if dest == "PROGRESS"     and not progressOn then dest = nil end
    if not dest then
        if chatOn     then dest = "CHAT"
        elseif gamesOn    then dest = "GAMES"
        elseif achieveOn  then dest = "ACHIEVEMENTS"
        elseif progressOn then dest = "PROGRESS"
        else                   dest = "SETTINGS" end
    end
    return dest
end

-- Smart toggle for a given destination. When the drawer is already open in a
-- different mode, switches modes instead of closing and re-opening.
function UI:LauncherToggleMode(dest)
    dest = string.upper(tostring(dest or "CHAT"))
    local options = CC.db and CC.db.ui or {}
    if dest == "CHAT" then
        self:ToggleMain()
        options.lastLauncherDest = "CHAT"
    elseif dest == "GAMES" then
        local drawer = self.gameDrawer
        local drawerOpen = drawer and drawer.creshOpen and drawer:IsShown()
        local isGamesMode = drawerOpen and drawer.mode ~= "ACHIEVEMENTS" and drawer.mode ~= "THEMES"
        if isGamesMode then
            self:CloseGameDrawer()
        elseif drawerOpen then
            local lastMode = options.lastGameMode or "SOLO"
            if lastMode == "ACHIEVEMENTS" or lastMode == "THEMES" then lastMode = "SOLO" end
            self:SetGameDrawerMode(lastMode)
        else
            self:OpenGameDrawer(options.lastGameMode or "SOLO")
        end
        local newMode = self.gameDrawer and self.gameDrawer.mode or "SOLO"
        if newMode ~= "ACHIEVEMENTS" and newMode ~= "THEMES" then
            options.lastGameMode = newMode
        end
        options.lastLauncherDest = "GAMES"
    elseif dest == "ACHIEVEMENTS" then
        local drawer = self.gameDrawer
        local drawerOpen = drawer and drawer.creshOpen and drawer:IsShown()
        if drawerOpen and drawer.mode == "ACHIEVEMENTS" then
            self:CloseGameDrawer()
        elseif drawerOpen then
            self:SetGameDrawerMode("ACHIEVEMENTS")
        else
            self:OpenGameDrawer("ACHIEVEMENTS")
        end
        options.lastLauncherDest = "ACHIEVEMENTS"
    elseif dest == "PROGRESS" then
        if CC.ProgressHub then
            CC.ProgressHub:Toggle()
        end
        options.lastLauncherDest = "PROGRESS"
    elseif dest == "SETTINGS" then
        self:OpenSettings()
    end
    self:RefreshLauncherButtonStates()
end

-- Left-click action for the C bubble: delegates to the appropriate destination.
function UI:LauncherDefaultAction()
    self:LauncherToggleMode(self:GetLauncherEffectiveDest())
end

-- Update active-state highlight on satellite launcher buttons.
function UI:RefreshLauncherButtonStates()
    local drawer = self.gameDrawer
    local drawerOpen   = drawer and drawer.creshOpen and drawer:IsShown()
    local drawerMode   = drawer and drawer.mode or "SOLO"
    local gamesActive  = drawerOpen and drawerMode ~= "ACHIEVEMENTS" and drawerMode ~= "THEMES"
    local achieveActive= drawerOpen and drawerMode == "ACHIEVEMENTS"
    local progressActive = CC.ProgressHub and CC.ProgressHub:IsOpen()
    if self.gamesButton then
        applyBackdrop(self.gamesButton, gamesActive and COLORS.blue or COLORS.panelRaised, COLORS.border)
    end
    if self.achieveButton then
        applyBackdrop(self.achieveButton, achieveActive and COLORS.quest or COLORS.panelRaised, COLORS.border)
    end
    if self.progressButton then
        applyBackdrop(self.progressButton, progressActive and COLORS.green or COLORS.panelRaised, COLORS.border)
    end
end

function UI:BuildBubble()
    local function makeQuickButton(name, label, tooltipTitle, tooltipText, callback)
        local button = CreateFrame("Button", name, UIParent, templateName())
        button:SetSize(36, 36)
        button:SetFrameStrata("HIGH")
        button:SetClampedToScreen(true)
        applyBackdrop(button, COLORS.panelRaised, COLORS.border)
        local iconSize = #label >= 3 and 10 or (#label == 2 and 12 or 15)
        button.icon = createFont(button, iconSize, COLORS.text, "CENTER")
        button.icon:SetAllPoints()
        button.icon:SetText(label)
        button.badge = createBadge(button, 20)
        button.badge:SetPoint("TOPRIGHT", button, "TOPRIGHT", 6, 6)
        button:SetScript("OnClick", callback)
        button:SetScript("OnEnter", function(selfButton)
            setBackground(selfButton, COLORS.blueHover)
            GameTooltip:SetOwner(selfButton, "ANCHOR_LEFT")
            GameTooltip:AddLine(tooltipTitle, 1, 1, 1)
            GameTooltip:AddLine(tooltipText, 0.75, 0.8, 0.9)
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function(selfButton)
            setBackground(selfButton, COLORS.panelRaised)
            GameTooltip:Hide()
        end)
        return button
    end

    local bubble = CreateFrame("Button", "CreshChatBubble", UIParent, templateName())
    bubble:SetSize(UI:GetDockButtonWidth(), UI:GetDockHeight())
    bubble:SetFrameStrata("HIGH")
    bubble:SetClampedToScreen(true)
    bubble:SetMovable(true)
    bubble:RegisterForDrag("RightButton")
    applyBackdrop(bubble, COLORS.blue, COLORS.blue)
    self.bubble = bubble
    self:BuildWhisperDockAlert()

    bubble.icon = createFont(bubble, 17, COLORS.text, "CENTER")
    bubble.icon:SetAllPoints()
    bubble.icon:SetText(self:GetLauncherBaseText())
    bubble.badge = createBadge(bubble, 20)
    bubble.badge:SetPoint("TOPRIGHT", bubble, "TOPRIGHT", 6, 6)

    -- Four lightweight edge textures create a clean notification outline without
    -- changing the launcher's backdrop or its saved dimensions.
    bubble.notificationOutline = {}
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
    bubble.notificationOutline[1] = top
    bubble.notificationOutline[2] = bottom
    bubble.notificationOutline[3] = left
    bubble.notificationOutline[4] = right
    for _, edge in ipairs(bubble.notificationOutline) do edge:Hide() end

    -- A second, wider ADD-blended outline creates a soft glow outside the block.
    bubble.notificationGlow = {}
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
    bubble.notificationGlow[1] = glowTop
    bubble.notificationGlow[2] = glowBottom
    bubble.notificationGlow[3] = glowLeft
    bubble.notificationGlow[4] = glowRight
    for _, edge in ipairs(bubble.notificationGlow) do
        if edge.SetBlendMode then edge:SetBlendMode("ADD") end
        edge:Hide()
    end
    bubble:SetScript("OnClick", function()
        UI:MarkLauncherActive()
        if IsShiftKeyDown and IsShiftKeyDown() then
            UI:OpenSettings()
            return
        end
        UI:LauncherDefaultAction()
    end)
    bubble:SetScript("OnDragStart", function(selfBubble)
        UI:MarkLauncherActive()
        selfBubble:StartMoving()
    end)
    bubble:SetScript("OnDragStop", function(selfBubble)
        selfBubble:StopMovingOrSizing()
        savePosition(selfBubble, "bubble")
        UI:PositionQuickButtons()
        UI:PositionCombatPanel()
        UI:PositionQuickInput()
        UI:PositionWhisperDockAlert()
        UI:RepositionToasts()
        UI:MarkLauncherActive()
    end)
    bubble:SetScript("OnEnter", function(selfBubble)
        UI.launcherHovered = true
        UI:MarkLauncherActive()
        local chatOn = CC.IsFeatureEnabled and CC:IsFeatureEnabled("chat")
        local gamesOn = CC.IsFeatureEnabled and CC:IsFeatureEnabled("games")
        local achieveOn = CC.IsFeatureEnabled and CC:IsFeatureEnabled("gameProgression")
        GameTooltip:SetOwner(selfBubble, "ANCHOR_LEFT")
        GameTooltip:AddLine("CreshChat", 1, 1, 1)
        if chatOn then
            GameTooltip:AddLine("Left-click: open chat + typing bar", 0.75, 0.8, 0.9)
            GameTooltip:AddLine("Right-drag: move C and its composer", 0.75, 0.8, 0.9)
        elseif gamesOn then
            GameTooltip:AddLine("Left-click: open the games hub", 0.75, 0.8, 0.9)
            GameTooltip:AddLine("Right-drag: move this launcher", 0.75, 0.8, 0.9)
        elseif achieveOn then
            GameTooltip:AddLine("Left-click: open Achievements", 0.75, 0.8, 0.9)
            GameTooltip:AddLine("Right-drag: move this launcher", 0.75, 0.8, 0.9)
        end
        GameTooltip:AddLine("Shift+click: open Settings", 0.75, 0.8, 0.9)
        if chatOn then
            GameTooltip:AddLine("Enter: open the bar; typing reveals chat", 0.75, 0.8, 0.9)
            GameTooltip:AddLine("W / G / Q / P: latest unread notification type", 0.55, 0.75, 1.0)
        end
        GameTooltip:Show()
    end)
    bubble:SetScript("OnLeave", function()
        UI.launcherHovered = false
        UI:MarkLauncherActive()
        GameTooltip:Hide()
    end)

    self.whisperBubble = makeQuickButton("CreshChatWhisperButton", "W", "Whispers", "Open your whisper conversations", function()
        UI:OpenChannel("WHISPER", UI:GetLatestWhisperTarget())
    end)
    self.whisperBubble.icon:Hide()
    self.whisperBubble.chatIcon = self.whisperBubble:CreateTexture(nil, "ARTWORK")
    self.whisperBubble.chatIcon:SetSize(24, 24)
    self.whisperBubble.chatIcon:SetPoint("CENTER", self.whisperBubble, "CENTER", 0, 0)
    self.whisperBubble.chatIcon:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-Chat-Up")
    self.generalBubble = makeQuickButton("CreshChatGeneralButton", "G", "General Chat", "Open the General chat feed", function()
        UI:OpenChannel("GENERAL")
    end)
    self.combatBubble = makeQuickButton("CreshChatCombatButton", "CL", "Combat Log", "Open the compact combat panel", function()
        UI:ToggleCombatPanel()
    end)

    self.gamesButton = makeQuickButton("CreshChatGamesButton", "Gm", "Games Hub", "Toggle the CreshChat games hub", function()
        UI:LauncherToggleMode("GAMES")
    end)
    self.gamesButton:SetScript("OnLeave", function()
        UI:RefreshLauncherButtonStates()
        GameTooltip:Hide()
    end)

    self.achieveButton = makeQuickButton("CreshChatAchievementsButton", "Ach", "Achievements", "Toggle the Achievements panel", function()
        UI:LauncherToggleMode("ACHIEVEMENTS")
    end)
    self.achieveButton:SetScript("OnLeave", function()
        UI:RefreshLauncherButtonStates()
        GameTooltip:Hide()
    end)

    self.progressButton = makeQuickButton("CreshChatProgressButton", "Prg", "Progress Hub", "Toggle the Progress Hub (World · Quests · Combat)", function()
        UI:LauncherToggleMode("PROGRESS")
    end)
    self.progressButton:SetScript("OnLeave", function()
        UI:RefreshLauncherButtonStates()
        GameTooltip:Hide()
    end)

    applyPosition(bubble, "bubble")
    self:PositionQuickButtons()
    self:SetBubbleGroupShown(CC.db.bubbleVisible)
    self:RefreshLauncherNotification()
    self:RefreshLauncherButtonStates()
    self:MarkLauncherActive()
end

local function launcherTime()
    if type(GetTime) == "function" then return GetTime() end
    if type(time) == "function" then return time() end
    return 0
end

function UI:GetLauncherNotificationStyle(kind)
    kind = string.upper(tostring(kind or ""))
    local channels = CC.db and CC.db.colors and CC.db.colors.channels or {}
    if kind == "WHISPER" then return "W", COLORS.blue end
    if kind == "GUILD" or kind == "OFFICER" then return "G", GUILD_THEME.accent end
    if kind == "QUEST" then return "Q", COLORS.quest end
    if kind == "PARTY_INVITE" then return "I", channels.PARTY or COLORS.green end
    if kind == "PARTY_MESSAGE" then return "P", channels.PARTY or COLORS.blue end
    if kind == "GENERAL" then return "M", COLORS.blue end
    if kind == "SYSTEM" then return "S", COLORS.muted end
    if kind == "FRIEND" then return "F", COLORS.green end
    if kind == "GAME" then return "X", COLORS.blue end
    return self:GetLauncherBaseText(), COLORS.blue
end

function UI:SetLauncherOutline(color, alpha, shown)
    local bubble = self.bubble
    if not bubble or not bubble.notificationOutline then return end
    color = color or COLORS.blue
    alpha = tonumber(alpha) or 1
    for _, edge in ipairs(bubble.notificationOutline) do
        edge:SetColorTexture(color[1] or 1, color[2] or 1, color[3] or 1, alpha)
        edge:SetShown(shown ~= false)
    end
    for _, edge in ipairs(bubble.notificationGlow or {}) do
        edge:SetColorTexture(color[1] or 1, color[2] or 1, color[3] or 1, alpha * 0.42)
        edge:SetShown(shown ~= false)
    end
end

function UI:IsLauncherNoticeActive(kind, notice, now)
    notice = notice or {}
    now = tonumber(now) or launcherTime()
    if notice.expiresAt and now < notice.expiresAt then return true end
    kind = string.upper(tostring(kind or ""))
    if kind == "WHISPER" then return (tonumber(CC.state.unreadWhispers) or 0) > 0 end
    if kind == "GUILD" or kind == "OFFICER" then return (tonumber(CC.state.unreadGuild) or 0) > 0 end
    if kind == "QUEST" then return (tonumber(CC.state.unreadQuests) or 0) > 0 end
    if kind == "PARTY_MESSAGE" or kind == "GENERAL" then return (tonumber(CC.state.unreadGeneral) or 0) > 0 end
    if kind == "PARTY_INVITE" then return CC.state.partyInvitePending == true end
    return false
end

function UI:IsLauncherInUse(now)
    now = tonumber(now) or launcherTime()
    if self.launcherHovered then return true end
    if self.launcherCurrentNotice then return true end
    if self.main and self.main:IsShown() then return true end
    if self.quickInput and self.quickInput:IsShown() then return true end
    if self.combatPanel and self.combatPanel:IsShown() then return true end
    return now < (tonumber(self.launcherActiveUntil) or 0)
end

function UI:GetLauncherTargetAlpha(now)
    local options = CC.db and CC.db.ui or {}
    if options.launcherIdleFade ~= true or self:IsLauncherInUse(now) then return 1 end
    return max(0.05, min(0.75, tonumber(options.launcherIdleAlpha) or 0.18))
end

function UI:ApplyLauncherGroupAlpha(alpha)
    alpha = max(0, min(1, tonumber(alpha) or 1))
    if self.bubble then self.bubble:SetAlpha(alpha) end
    if self.whisperBubble then self.whisperBubble:SetAlpha(alpha) end
    if self.generalBubble then self.generalBubble:SetAlpha(alpha) end
    if self.combatBubble then self.combatBubble:SetAlpha(alpha) end
end

function UI:EnsureLauncherAnimation()
    local bubble = self.bubble
    if not bubble then return end
    bubble:SetScript("OnUpdate", function(selfBubble, elapsed)
        UI:UpdateLauncherAnimation(selfBubble, elapsed)
    end)
end

function UI:RefreshLauncherVisibility(immediate)
    local bubble = self.bubble
    if not bubble then return end
    local target = self:GetLauncherTargetAlpha(launcherTime())
    bubble.creshTargetAlpha = target
    if immediate then self:ApplyLauncherGroupAlpha(target) end
    local options = CC.db and CC.db.ui or {}
    local needsPulse = self.launcherCurrentNotice and options.launcherNotificationPulse ~= false
    if options.launcherIdleFade == true or needsPulse then
        self:EnsureLauncherAnimation()
    elseif not self.launcherCurrentNotice then
        bubble:SetScript("OnUpdate", nil)
    end
end

function UI:MarkLauncherActive(seconds)
    local options = CC.db and CC.db.ui or {}
    local delay = tonumber(seconds) or tonumber(options.launcherIdleDelay) or 5
    self.launcherActiveUntil = launcherTime() + max(0.5, delay)
    self:RefreshLauncherVisibility(true)
end

function UI:UpdateLauncherAnimation(selfBubble, elapsed)
    if not selfBubble then return end
    local now = launcherTime()
    local active = self.launcherCurrentNotice
    local activeKind = active and active.kind
    if activeKind and not self:IsLauncherNoticeActive(activeKind, active, now) then
        self:RefreshLauncherNotification()
        return
    end

    local options = CC.db and CC.db.ui or {}
    if activeKind then
        local _, activeColor = self:GetLauncherNotificationStyle(activeKind)
        if options.launcherNotificationPulse ~= false then
            selfBubble.creshNotificationElapsed = (selfBubble.creshNotificationElapsed or 0) + (elapsed or 0)
            local wave = 0.5 + (0.5 * sin(selfBubble.creshNotificationElapsed * 4.6))
            local outlineAlpha = 0.28 + (0.72 * wave)
            self:SetLauncherOutline(activeColor, outlineAlpha, true)
            selfBubble.icon:SetAlpha(0.84 + (0.16 * wave))
        else
            self:SetLauncherOutline(activeColor, 0.92, true)
            selfBubble.icon:SetAlpha(1)
        end
    else
        selfBubble.icon:SetAlpha(1)
    end

    local target = self:GetLauncherTargetAlpha(now)
    selfBubble.creshTargetAlpha = target
    local current = selfBubble:GetAlpha() or 1
    local speed = 6.5
    local nextAlpha = current + ((target - current) * min(1, (elapsed or 0) * speed))
    if math.abs(nextAlpha - target) < 0.01 then nextAlpha = target end
    self:ApplyLauncherGroupAlpha(nextAlpha)

    if options.launcherIdleFade ~= true and not (activeKind and options.launcherNotificationPulse ~= false) then
        selfBubble:SetScript("OnUpdate", nil)
    end
end

function UI:NotifyLauncher(kind, target, transientSeconds, force)
    if not self.bubble then return end
    if not force and CC.IsNotificationEnabled and not CC:IsNotificationEnabled(kind) then return end
    kind = string.upper(tostring(kind or "SYSTEM"))
    local now = launcherTime()
    self.launcherNotices = self.launcherNotices or {}
    local notice = self.launcherNotices[kind] or {}
    notice.kind = kind
    notice.target = target
    notice.force = force and true or false
    notice.timestamp = now
    if tonumber(transientSeconds) and tonumber(transientSeconds) > 0 then
        notice.expiresAt = now + tonumber(transientSeconds)
    else
        notice.expiresAt = nil
    end
    self.launcherNotices[kind] = notice
    self:MarkLauncherActive()
    self:RefreshLauncherNotification()
    if notice.expiresAt and C_Timer and C_Timer.After then
        local stamp = notice.timestamp
        C_Timer.After(tonumber(transientSeconds) + 0.05, function()
            local current = UI.launcherNotices and UI.launcherNotices[kind]
            if current and current.timestamp == stamp then UI:RefreshLauncherNotification() end
        end)
    end
end

function UI:PreviewLauncherNotification(kind)
    self:NotifyLauncher(kind, nil, 3.2, true)
end

function UI:RefreshLauncherNotification()
    local bubble = self.bubble
    if not bubble or not bubble.icon then return end
    local now = launcherTime()
    self.launcherNotices = self.launcherNotices or {}
    local selectedKind, selectedNotice, selectedRank
    for kind, notice in pairs(self.launcherNotices) do
        local previewExpired = notice.force == true and notice.expiresAt and now >= notice.expiresAt
        local allowed = notice.force == true or not CC.IsNotificationEnabled or CC:IsNotificationEnabled(kind)
        if not previewExpired and allowed and self:IsLauncherNoticeActive(kind, notice, now) then
            local rank = CC.GetNotificationPriorityRank and CC:GetNotificationPriorityRank(kind) or 2
            if not selectedNotice or rank > (selectedRank or 0) or (rank == selectedRank and (tonumber(notice.timestamp) or 0) > (tonumber(selectedNotice.timestamp) or 0)) then
                selectedKind, selectedNotice, selectedRank = kind, notice, rank
            end
        else
            self.launcherNotices[kind] = nil
        end
    end

    if not selectedKind then
        self.launcherCurrentNotice = nil
        bubble.icon:SetText(self:GetLauncherBaseText())
        self:ApplyLauncherTextStyle(bubble.icon, false)
        bubble.icon:SetAlpha(1)
        applyBackdrop(bubble, COLORS.blue, COLORS.blue)
        self:SetLauncherOutline(COLORS.blue, 0, false)
        bubble.creshNotificationElapsed = nil
        self:RefreshLauncherVisibility(false)
        return
    end

    local letter, color = self:GetLauncherNotificationStyle(selectedKind)
    self.launcherCurrentNotice = selectedNotice
    bubble.icon:SetText(letter)
    if bubble.icon.SetFont then bubble.icon:SetFont(_G.STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 17, "") end
    bubble.icon:SetAlpha(1)
    local fill = darkenColor(color, 0.34)
    local border = darkenColor(color, 0.68)
    applyBackdrop(bubble, fill, border)
    self:SetLauncherOutline(color, 0.92, true)
    bubble.creshNotificationElapsed = 0
    self:RefreshLauncherVisibility(true)
end

function UI:BuildCombatPanel()
    local panel = CreateFrame("Frame", "CreshChatCombatPanel", UIParent, templateName())
    applySize(panel, "combat", 330, 250)
    panel:SetFrameStrata("HIGH")
    panel:SetClampedToScreen(true)
    panel.creshClassicChrome = true
    applyBackdrop(panel, COLORS.panel, COLORS.border)
    panel:Hide()
    self.combatPanel = panel
    self:InstallWindowFocus(panel)

    panel.header = CreateFrame("Frame", nil, panel)
    panel.header:SetPoint("TOPLEFT", panel, "TOPLEFT", 1, -1)
    panel.header:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -1, -1)
    panel.header:SetHeight(34)
    panel:SetMovable(true)
    installShiftResize(panel, panel.header, "combat", 280, 190, 620, 650, function()
        UI:RefreshCombatPanel()
    end)

    panel.title = createFont(panel.header, 12, COLORS.text, "LEFT")
    panel.title:SetPoint("LEFT", panel.header, "LEFT", 11, 0)
    panel.title:SetText("COMBAT LOG")

    panel.clear = createButton(panel.header, "CLEAR", 48, 26, function()
        CC.db.history.combat = {}
        UI:RefreshAll()
    end)
    panel.clear:SetPoint("RIGHT", panel.header, "RIGHT", -38, 0)

    panel.close = createButton(panel.header, "X", 26, 26, function()
        panel:Hide()
    end)
    panel.close:SetPoint("RIGHT", panel.header, "RIGHT", -6, 0)

    panel.view = self:CreateCombatView(panel)
    panel.view.scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -42)
    panel.view.scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -8, 8)
    panel.view.fallbackWidth = 350

    panel:SetScript("OnShow", function()
        UI:PositionCombatPanel()
        UI:RefreshCombatPanel()
    end)
    self:PositionCombatPanel()
end

function UI:ToggleCombatPanel()
    if not self.combatPanel then
        return
    end
    if self.combatPanel:IsShown() then
        self.combatPanel:Hide()
    else
        self:PositionCombatPanel()
        self:ShowAnimated(self.combatPanel)
    end
end

function UI:RefreshCombatPanel()
    if self.combatPanel and self.combatPanel:IsShown() then
        self.combatPanel.view:Refresh(CC.db.history.combat)
    end
end

function UI:RefreshCombatDisplays()
    if self.main and self.main:IsShown() and self.mode == "COMBAT" then
        self.mainCombatView:Refresh(CC.db.history.combat)
    end
    self:RefreshCombatPanel()
    local popout = self.popouts and self.popouts.COMBAT
    if popout and popout:IsShown() then
        popout.messageView:Refresh(CC.db.history.combat)
    end
end

function UI:QueueCombatRefresh()
    if self.combatRefreshQueued then
        return
    end
    self.combatRefreshQueued = true

    local function refresh()
        UI.combatRefreshQueued = false
        UI:RefreshCombatDisplays()
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(0.08, refresh)
    else
        refresh()
    end
end

function UI:SetTabButtonStyle(button, selected, activeColor, hoverColor, normalColor)
    if not button then return end
    button.creshSelected = selected == true
    button.creshActiveColor = activeColor or COLORS.blue
    button.creshHoverColor = hoverColor or brightenColor(activeColor or COLORS.blue, 0.08)
    button.creshNormalColor = normalColor or COLORS.panelRaised
    setBackground(button, button.creshSelected and button.creshActiveColor or button.creshNormalColor)
end

function UI:GetConsoleModeAccent(mode)
    if mode == "FRIENDS" then
        local accent = (CC.db and CC.db.colors and CC.db.colors.accent) or COLORS.blue
        return accent, brightenColor(accent, 0.10), COLORS.panelRaised
    end
    if mode == "GUILD" then return GUILD_THEME.accent, GUILD_THEME.accentHover, GUILD_THEME.panelRaised end
    if mode == "QUEST" then return COLORS.quest, brightenColor(COLORS.quest, 0.09), COLORS.panelRaised end
    if mode == "COMBAT" then return COLORS.combatOut, brightenColor(COLORS.combatOut, 0.08), COLORS.panelRaised end
    local channelColor = CC.db and CC.db.colors and CC.db.colors.channels and CC.db.colors.channels[mode]
    local accent = channelColor or COLORS.blue
    return accent, brightenColor(accent, 0.08), COLORS.panelRaised
end

function UI:UpdateTabAppearance()
    if not self.main then return end
    self:SetTabButtonStyle(self.main.gamesMenu, self.gameDrawer and self.gameDrawer.creshOpen and self.gameDrawer.mode ~= "BATTLEPASS", COLORS.blue, COLORS.blueHover, COLORS.panelRaised)
    if self.main.addFriend then
        self:SetTabButtonStyle(self.main.addFriend, false, COLORS.blue, brightenColor(COLORS.blue, 0.12), darkenColor(COLORS.blue, 0.34))
        if self.main.addFriend.SetBackdropBorderColor then self.main.addFriend:SetBackdropBorderColor(COLORS.blue[1], COLORS.blue[2], COLORS.blue[3], 1) end
    end
    if self.main.partyInvite then
        self:SetTabButtonStyle(self.main.partyInvite, false, COLORS.green, brightenColor(COLORS.green, 0.12), darkenColor(COLORS.green, 0.34))
        if self.main.partyInvite.SetBackdropBorderColor then self.main.partyInvite:SetBackdropBorderColor(COLORS.green[1], COLORS.green[2], COLORS.green[3], 1) end
    end
    if self.main.bpLevelBox then
        local accent = (CC.db and CC.db.colors and CC.db.colors.accent) or COLORS.blue
        local passOpen = self.gameDrawer and self.gameDrawer.creshOpen and self.gameDrawer.mode == "BATTLEPASS"
        self:SetTabButtonStyle(self.main.bpLevelBox, passOpen, darkenColor(accent, 0.55), brightenColor(accent, 0.10), darkenColor(accent, 0.28))
        if self.main.bpLevelBox.SetBackdropBorderColor then
            self.main.bpLevelBox:SetBackdropBorderColor(accent[1], accent[2], accent[3], accent[4] or 1)
        end
    end
    for _, definition in ipairs(CONSOLE_TAB_DEFINITIONS) do
        local button = self.main.consoleTabButtons and self.main.consoleTabButtons[definition.key]
        if button then
            local active, hover, normal = self:GetConsoleModeAccent(definition.key)
            local selected = self.mode == definition.key
            self:SetTabButtonStyle(button, selected, active, hover, normal)
            if button.SetBackdropBorderColor then
                local border = selected and active or COLORS.border
                button:SetBackdropBorderColor(border[1], border[2], border[3], selected and 1 or 0.85)
            end
            if button.label and button.label.SetTextColor then
                local textColor = selected and COLORS.text or COLORS.muted
                button.label:SetTextColor(textColor[1], textColor[2], textColor[3], 1)
            end
        end
    end
end

function UI:AnimateModeSwitch(previousMode, nextMode)
    if not self.main or not self.main.body or not self.main:IsShown() then return end
    local body = self.main.body
    if body.creshModeTransition then
        body:SetScript("OnUpdate", nil)
        body.creshModeTransition = nil
    end

    local order = {}; for _, definition in ipairs(CONSOLE_TAB_DEFINITIONS) do order[definition.key] = definition.order end
    local previousRank = order[previousMode or ""] or 1
    local nextRank = order[nextMode or ""] or previousRank
    local direction = nextRank >= previousRank and 1 or -1
    local startOffset = 9 * direction
    local duration = max(0.10, min(0.18, self:GetAnimationDuration() * 0.72))
    local elapsedTotal = 0

    body:SetAlpha(0.74)
    body:ClearAllPoints()
    body:SetPoint("TOPLEFT", self.main, "TOPLEFT", 10 + startOffset, -self:GetMainBodyTopOffset())
    body:SetPoint("BOTTOMRIGHT", self.main, "BOTTOMRIGHT", -10 + startOffset, 10)
    body.creshModeTransition = true
    body:SetScript("OnUpdate", function(selfBody, elapsed)
        elapsedTotal = elapsedTotal + elapsed
        local progress = min(1, elapsedTotal / duration)
        local eased = 1 - ((1 - progress) * (1 - progress) * (1 - progress))
        local offset = startOffset * (1 - eased)
        selfBody:SetAlpha(0.74 + (0.26 * eased))
        selfBody:ClearAllPoints()
        selfBody:SetPoint("TOPLEFT", UI.main, "TOPLEFT", 10 + offset, -UI:GetMainBodyTopOffset())
        selfBody:SetPoint("BOTTOMRIGHT", UI.main, "BOTTOMRIGHT", -10 + offset, 10)
        if progress >= 1 then
            selfBody:SetScript("OnUpdate", nil)
            selfBody.creshModeTransition = nil
            selfBody:SetAlpha(1)
            selfBody:ClearAllPoints()
            selfBody:SetPoint("TOPLEFT", UI.main, "TOPLEFT", 10, -UI:GetMainBodyTopOffset())
            selfBody:SetPoint("BOTTOMRIGHT", UI.main, "BOTTOMRIGHT", -10, 10)
        end
    end)
end

function UI:SetMode(mode, target)
    local previousMode = self.mode
    if mode == "GAMES" then
        self:OpenGameDrawer("MULTIPLAYER", target)
        return
    end
    if not CONSOLE_TAB_LOOKUP[mode] then mode = "WHISPER" end
    self.mode = mode
    if self.friendsDirectoryTabs then self.friendsDirectoryTabs:Hide() end

    if self.main.body.creshModeTransition then
        self.main.body:SetScript("OnUpdate", nil)
        self.main.body.creshModeTransition = nil
    end
    self.main.body:SetAlpha(1)
    self.main.body:ClearAllPoints()
    self.main.body:SetPoint("TOPLEFT", self.main, "TOPLEFT", 10, -self:GetMainBodyTopOffset())
    self.main.body:SetPoint("BOTTOMRIGHT", self.main, "BOTTOMRIGHT", -10, 10)
    if mode == "COMBAT" then
        self.mainView.scroll:Hide()
        self.mainCombatView.scroll:Show()
        self.conversationList.container:Hide()
        self.main.title:SetText("Combat Log")
        if self.main.subtitle then self.main.subtitle:SetText("Live personal combat activity") end
    else
        self.mainCombatView.scroll:Hide()
        self.mainView.scroll:Show()

        if mode == "WHISPER" then
            self.conversationList.container:ClearAllPoints()
            self.conversationList.container:SetPoint("TOPLEFT", self.main.body, "TOPLEFT", 0, 0)
            self.conversationList.container:SetPoint("BOTTOMLEFT", self.main.body, "BOTTOMLEFT", 0, 0)
            self.conversationList.container:SetWidth(132)
            if target and CC.db.history.whispers[target] then
                self.currentTarget = target
            elseif not self.currentTarget or not CC.db.history.whispers[self.currentTarget] then
                local sorted = self:GetSortedConversations()
                self.currentTarget = sorted[1] and sorted[1].target or nil
            end
            self.conversationList.container:Show()
            self.mainView.scroll:ClearAllPoints()
            self.mainView.scroll:SetPoint("TOPLEFT", self.conversationList.container, "TOPRIGHT", 8, 0)
            self.mainView.scroll:SetPoint("BOTTOMRIGHT", self.main.body, "BOTTOMRIGHT", 0, 0)
            self.main.title:SetText(self.currentTarget and (CC.GetWhisperDisplayName and CC:GetWhisperDisplayName(self.currentTarget) or CC:ShortName(self.currentTarget)) or "Whispers")
            if self.main.subtitle then self.main.subtitle:SetText(self.currentTarget and "Private conversation" or "Choose a conversation") end
        elseif mode == "QUEST" then
            self.conversationList.container:ClearAllPoints()
            self.conversationList.container:SetPoint("TOPLEFT", self.main.body, "TOPLEFT", 0, 0)
            self.conversationList.container:SetPoint("BOTTOMLEFT", self.main.body, "BOTTOMLEFT", 0, 0)
            self.conversationList.container:SetWidth(132)
            if CC.EnsureQuestStorage then CC:EnsureQuestStorage() end
            if target and CC.db.history.quests[target] then
                self.currentQuestTarget = target
            elseif not self.currentQuestTarget or not CC.db.history.quests[self.currentQuestTarget] then
                local sorted = self:GetSortedQuestConversations()
                self.currentQuestTarget = sorted[1] and sorted[1].target or nil
            end
            self.conversationList.container:Show()
            self.mainView.scroll:ClearAllPoints()
            self.mainView.scroll:SetPoint("TOPLEFT", self.conversationList.container, "TOPRIGHT", 8, 0)
            self.mainView.scroll:SetPoint("BOTTOMRIGHT", self.main.body, "BOTTOMRIGHT", 0, 0)
            local meta = self.currentQuestTarget and CC:GetQuestConversationMeta(self.currentQuestTarget) or nil
            self.main.title:SetText(meta and meta.npcName or "Quests")
            if self.main.subtitle then self.main.subtitle:SetText(meta and meta.zone or "Quest-giver conversations by zone") end
        elseif mode == "FRIENDS" then
            if CC.Friends then
                if CC.Friends.RequestRoster then CC.Friends:RequestRoster() end
                if CC.Friends.SyncAllRosters then CC.Friends:SyncAllRosters() end
            end
            self:EnsureFriendsDirectoryTabs()
            self.friendsDirectoryTabs:ClearAllPoints()
            self.friendsDirectoryTabs:SetPoint("TOPLEFT", self.main.body, "TOPLEFT", 0, 0)
            self.friendsDirectoryTabs:SetPoint("TOPRIGHT", self.main.body, "TOPRIGHT", 0, 0)
            self.friendsDirectoryTabs:Show()
            self:UpdateFriendsDirectoryTabs()
            self.conversationList.container:ClearAllPoints()
            self.conversationList.container:SetPoint("TOPLEFT", self.friendsDirectoryTabs, "BOTTOMLEFT", 0, -6)
            self.conversationList.container:SetPoint("BOTTOMRIGHT", self.main.body, "BOTTOMRIGHT", 0, 0)
            self.conversationList.container:Show()
            self.mainView.scroll:Hide()
            self.mainCombatView.scroll:Hide()
            self:RefreshFriendsHeader()
            if C_Timer and C_Timer.After then
                C_Timer.After(0.20, function()
                    if UI.mode == "FRIENDS" and UI.main and UI.main:IsShown() then
                        if CC.Friends and CC.Friends.SyncAllRosters then CC.Friends:SyncAllRosters() end
                        UI:RefreshConversationList()
                    end
                end)
            end
        elseif mode == "GUILD" then
            if CC.Friends and CC.Friends.RequestGuildRoster then CC.Friends:RequestGuildRoster() end
            self.conversationList.container:ClearAllPoints()
            self.conversationList.container:SetPoint("TOPLEFT", self.main.body, "TOPLEFT", 0, 0)
            self.conversationList.container:SetPoint("BOTTOMLEFT", self.main.body, "BOTTOMLEFT", 0, 0)
            self.conversationList.container:SetWidth(220)
            self.conversationList.container:Show()
            self.mainView.scroll:ClearAllPoints()
            self.mainView.scroll:SetPoint("TOPLEFT", self.conversationList.container, "TOPRIGHT", 8, 0)
            self.mainView.scroll:SetPoint("BOTTOMRIGHT", self.main.body, "BOTTOMRIGHT", 0, 0)
            local guildName = self:GetGuildDisplayName()
            self.main.title:SetText(guildName ~= "Guild" and ("Guild · " .. guildName) or "Guild Chat")
            if self.main.subtitle then self.main.subtitle:SetText("Guild and officer messages · online/offline roster") end
        elseif mode == "PARTY" or mode == "RAID" or mode == "INSTANCE" then
            self.conversationList.container:ClearAllPoints()
            self.conversationList.container:SetPoint("TOPLEFT", self.main.body, "TOPLEFT", 0, 0)
            self.conversationList.container:SetPoint("BOTTOMLEFT", self.main.body, "BOTTOMLEFT", 0, 0)
            self.conversationList.container:SetWidth(220)
            self.conversationList.container:Show()
            self.mainView.scroll:ClearAllPoints()
            self.mainView.scroll:SetPoint("TOPLEFT", self.conversationList.container, "TOPRIGHT", 8, 0)
            self.mainView.scroll:SetPoint("BOTTOMRIGHT", self.main.body, "BOTTOMRIGHT", 0, 0)
            local definition = CONSOLE_TAB_LOOKUP[mode]
            self.main.title:SetText(definition and definition.title or "Group Chat")
            if self.main.subtitle then
                if mode == "PARTY" then
                    self.main.subtitle:SetText("Party messages · current party members only · online/offline")
                elseif mode == "RAID" then
                    self.main.subtitle:SetText("Raid messages · current raid members only · online/offline")
                else
                    self.main.subtitle:SetText("Instance messages · current group members · online/offline")
                end
            end
        elseif self:IsGeneralFeedMode(mode) then
            if CC.Friends and CC.Friends.RequestLocalRoster then CC.Friends:RequestLocalRoster(false) end
            self.conversationList.container:ClearAllPoints()
            self.conversationList.container:SetPoint("TOPLEFT", self.main.body, "TOPLEFT", 0, 0)
            self.conversationList.container:SetPoint("BOTTOMLEFT", self.main.body, "BOTTOMLEFT", 0, 0)
            self.conversationList.container:SetWidth(220)
            self.conversationList.container:Show()
            self.mainView.scroll:ClearAllPoints()
            self.mainView.scroll:SetPoint("TOPLEFT", self.conversationList.container, "TOPRIGHT", 8, 0)
            self.mainView.scroll:SetPoint("BOTTOMRIGHT", self.main.body, "BOTTOMRIGHT", 0, 0)
            local definition = CONSOLE_TAB_LOOKUP[mode] or CONSOLE_TAB_LOOKUP.GENERAL
            self.main.title:SetText(definition.title)
            if self.main.subtitle then self.main.subtitle:SetText(definition.subtitle .. " · current-area roster") end
        end
    end

    self:ApplyRosterCollapseState()

    local showWhisperPortrait = mode == "WHISPER" and self.currentTarget ~= nil and CC.db.ui.showPortraits ~= false
    local guildMode = mode == "GUILD" and (CC.db.ui or {}).guildTheme ~= false
    local questMode = mode == "QUEST"
    local friendsMode = mode == "FRIENDS"
    local guildColor = GUILD_THEME.accent
    if self.main then
        applyBackdrop(self.main, guildMode and GUILD_THEME.panel or COLORS.panel, guildMode and GUILD_THEME.border or COLORS.border)
        if self.main.body and self.main.guildWash then
            self.main.guildWash:SetColorTexture(GUILD_THEME.panelRaised[1], GUILD_THEME.panelRaised[2], GUILD_THEME.panelRaised[3], 0.34)
        end
        if self.main.title and self.main.title.SetTextColor then
            local titleColor = guildMode and GUILD_THEME.accentHover or (questMode and COLORS.quest or (friendsMode and COLORS.blue or COLORS.text))
            self.main.title:SetTextColor(titleColor[1], titleColor[2], titleColor[3], 1)
        end
        if self.main.subtitle and self.main.subtitle.SetTextColor then
            local subtitleColor = guildMode and GUILD_THEME.muted or COLORS.muted
            self.main.subtitle:SetTextColor(subtitleColor[1], subtitleColor[2], subtitleColor[3], 1)
        end
    end
    if self.main and self.main.whisperPortrait then
        self.main.whisperPortrait:Hide()
        if self.main.guildCrest then self.main.guildCrest:Hide() end
        self.main.logoText:Hide()
        if showWhisperPortrait then
            local portraitMessage = UI:GetWhisperPortraitMessage(self.currentTarget)
            UI:UpdatePlayerPortrait(self.main.whisperPortrait, self.currentTarget, portraitMessage.guid, portraitMessage)
            self.main.whisperPortrait:Show()
            if self.main.logo.SetBackdropColor then self.main.logo:SetBackdropColor(0, 0, 0, 0) end
            if self.main.logo.SetBackdropBorderColor then self.main.logo:SetBackdropBorderColor(0, 0, 0, 0) end
        elseif guildMode and self.main.guildCrest then
            self:RefreshGuildCrest(self.main.guildCrest)
            self.main.guildCrest:Show()
            applyBackdrop(self.main.logo, { 0.025, 0.16, 0.065, 0.98 }, guildColor)
        else
            self.main.logoText:Show()
            local logoColor = questMode and COLORS.quest or COLORS.blue
            applyBackdrop(self.main.logo, logoColor, logoColor)
        end
        if self.main.guildWash then self.main.guildWash:SetShown(guildMode) end
        if self.main.topAccent then
            local accent = guildMode and guildColor or (questMode and COLORS.quest or COLORS.blue)
            self.main.topAccent:SetStatusBarColor(accent[1], accent[2], accent[3], 1)
        end
        if self.main.buildText then
            local accent = guildMode and guildColor or (questMode and COLORS.quest or COLORS.blue)
            self.main.buildText:SetTextColor(accent[1], accent[2], accent[3], 1)
        end
    end

    local hasWhisperTarget = mode == "WHISPER" and self.currentTarget ~= nil
    if self.main.closeChat then self.main.closeChat:SetShown(hasWhisperTarget) end
    if self.main.addFriend then self.main.addFriend:SetShown(hasWhisperTarget or mode == "FRIENDS") end
    if self.main.partyInvite then self.main.partyInvite:SetShown(hasWhisperTarget) end
    if self.main.voiceCall then self.main.voiceCall:SetShown(hasWhisperTarget) end
    self:RefreshWhisperContactSwitcher()
    if self.main.popout then self.main.popout:SetShown(mode ~= "FRIENDS") end
    self:LayoutMainHeader()

    if mode ~= "COMBAT" and mode ~= "QUEST" and mode ~= "FRIENDS" then
        self:SetQuickDestination(mode, self.currentTarget)
    end

    self:MarkCurrentRead()
    self:UpdateTabAppearance()
    self:RefreshAll()
    self:AnimateModeSwitch(previousMode, mode)
end

function UI:MarkCurrentRead()
    if not self.main or not self.main:IsShown() then
        return
    end
    if self.mode == "WHISPER" then
        if self.currentTarget then self.unreadByTarget[self.currentTarget] = 0 end
        CC.state.unreadWhispers = 0
        for _, count in pairs(self.unreadByTarget) do
            CC.state.unreadWhispers = CC.state.unreadWhispers + (count or 0)
        end
    elseif self.mode == "QUEST" then
        if self.currentQuestTarget then self.unreadQuestByTarget[self.currentQuestTarget] = 0 end
        CC.state.unreadQuests = 0
        for _, count in pairs(self.unreadQuestByTarget) do
            CC.state.unreadQuests = CC.state.unreadQuests + (count or 0)
        end
    elseif self.mode == "GUILD" then
        CC.state.unreadGuild = 0
    elseif self:IsGeneralFeedMode(self.mode) then
        CC.state.unreadGeneral = 0
    end
    self:RefreshBadges()
    self:RefreshLauncherNotification()
end

function UI:RefreshBadges()
    if not self.main or not self.bubble then
        return
    end
    local questUnread = tonumber(CC.state.unreadQuests) or 0
    setBadge(self.main.whisperBadge, CC.state.unreadWhispers)
    setBadge(self.main.guildBadge, CC.state.unreadGuild)
    setBadge(self.main.generalBadge, CC.state.unreadGeneral)
    setBadge(self.main.questBadge, questUnread)
    if self.whisperBubble and self.whisperBubble.badge then setBadge(self.whisperBubble.badge, CC.state.unreadWhispers) end
    if self.generalBubble and self.generalBubble.badge then setBadge(self.generalBubble.badge, CC.state.unreadGeneral) end
    setBadge(self.bubble.badge, CC.state.unreadWhispers + CC.state.unreadGuild + CC.state.unreadGeneral + questUnread)
    self:SetUnreadPulse(self.main.whisperTab, nil, (tonumber(CC.state.unreadWhispers) or 0) > 0, COLORS.blue)
    self:SetUnreadPulse(self.main.generalTab, nil, (tonumber(CC.state.unreadGeneral) or 0) > 0, COLORS.blue)
    self:SetUnreadPulse(self.main.guildTab, nil, (tonumber(CC.state.unreadGuild) or 0) > 0, GUILD_THEME.accent)
    self:SetUnreadPulse(self.main.questTab, nil, questUnread > 0, COLORS.quest)
    self:RefreshLauncherNotification()
end

function UI:GetGeneralMessagesForMode(mode)
    mode = tostring(mode or "GENERAL")
    local history = CC.db and CC.db.history and CC.db.history.general or {}
    if mode == "GENERAL" then return history end
    if not self:IsGeneralFeedMode(mode) then return {} end
    local filtered = {}
    for _, message in ipairs(history) do
        if CC:ChannelColorKey(message) == mode then filtered[#filtered + 1] = message end
    end
    return filtered
end

function UI:RefreshMainMessages()
    if not self.mainView or not self.mainCombatView then
        return
    end
    if self.mode == "COMBAT" then
        self.mainCombatView:Refresh(CC.db.history.combat)
    elseif self.mode == "GUILD" then
        self.mainView:Refresh(CC.db.history.guild, "GUILD")
    elseif self:IsGeneralFeedMode(self.mode) then
        self.mainView:Refresh(self:GetGeneralMessagesForMode(self.mode), "GENERAL")
    elseif self.mode == "QUEST" then
        local messages = self.currentQuestTarget and (CC.db.history.quests or {})[self.currentQuestTarget] or {}
        self.mainView:Refresh(messages, "QUEST")
    elseif self.mode == "FRIENDS" then
        self.mainView:Refresh({}, "WHISPER")
    else
        local messages = self.currentTarget and CC.db.history.whispers[self.currentTarget] or {}
        self.mainView:Refresh(messages, "WHISPER")
    end
end

function UI:RefreshWhisperChrome()
    if self.main and self.main.whisperPortrait then
        local showPortrait = self.mode == "WHISPER" and self.currentTarget and CC.db.ui.showPortraits ~= false
        local guildMode = self.mode == "GUILD" and (CC.db.ui or {}).guildTheme ~= false
        local questMode = self.mode == "QUEST"
        local friendsMode = self.mode == "FRIENDS"
        if self.main.voiceCall and self.main.voiceCall.icon then
            local active=CC.Voice and CC.Voice.active and self.currentTarget and CC.WhisperNamesEquivalent and CC:WhisperNamesEquivalent(CC.Voice.active.target,self.currentTarget)
            local ready=CC.Voice and self.currentTarget and CC.Voice:IsPeerReady(self.currentTarget)
            local c=active and COLORS.green or (ready and COLORS.blue or COLORS.muted)
            self.main.voiceCall.icon:SetVertexColor(c[1],c[2],c[3],active and 1 or (ready and 0.95 or 0.55))
        end
        self.main.whisperPortrait:Hide()
        if self.main.guildCrest then self.main.guildCrest:Hide() end
        self.main.logoText:Hide()
        if showPortrait then
            local message = self:GetWhisperPortraitMessage(self.currentTarget)
            self:UpdatePlayerPortrait(self.main.whisperPortrait, self.currentTarget, message.guid, message)
            self.main.whisperPortrait:Show()
            if self.main.logo.SetBackdropColor then self.main.logo:SetBackdropColor(0, 0, 0, 0) end
            if self.main.logo.SetBackdropBorderColor then self.main.logo:SetBackdropBorderColor(0, 0, 0, 0) end
        elseif guildMode and self.main.guildCrest then
            self:RefreshGuildCrest(self.main.guildCrest)
            self.main.guildCrest:Show()
            applyBackdrop(self.main.logo, GUILD_THEME.panelRaised, GUILD_THEME.border)
        else
            self.main.logoText:Show()
            local logoColor = questMode and COLORS.quest or COLORS.blue
            applyBackdrop(self.main.logo, logoColor, logoColor)
        end
    end
    for _, popout in pairs(self.popouts or {}) do
        if popout.channel == "GUILD" and popout.guildCrest then self:RefreshGuildCrest(popout.guildCrest) end
        if popout.channel == "WHISPER" and popout.portrait then
            local message = self:GetWhisperPortraitMessage(popout.target)
            self:UpdatePlayerPortrait(popout.portrait, popout.target, message.guid, message)
        end
    end
end

function UI:RefreshPopouts()
    self:RefreshWhisperChrome()
    for _, popout in pairs(self.popouts) do
        if popout:IsShown() then
            if popout.channel ~= "COMBAT" then self:ApplyPopoutStyle(popout) end
            if popout.channel == "COMBAT" then
                popout.messageView:Refresh(CC.db.history.combat)
            elseif popout.channel == "GUILD" then
                popout.messageView:Refresh(CC.db.history.guild, "GUILD")
            elseif self:IsGeneralFeedMode(popout.channel) then
                popout.messageView:Refresh(self:GetGeneralMessagesForMode(popout.channel), "GENERAL")
            elseif popout.channel == "QUEST" then
                popout.messageView:Refresh((CC.db.history.quests or {})[popout.target] or {}, "QUEST")
            else
                popout.messageView:Refresh(CC.db.history.whispers[popout.target] or {}, "WHISPER")
            end
        end
    end
end

function UI:RefreshConsoleEconomy()
    if not self.main or not CC.BattlePass then return end
    local level,current,required = CC.BattlePass:GetProgress()
    local wallet = CC.BattlePass:GetWalletText()
    if self.main.topAccent then self.main.topAccent:SetMinMaxValues(0,math.max(1,required or 1)); self.main.topAccent:SetValue(current or 0) end
    if self.main.bpLevelText then self.main.bpLevelText:SetText("BP "..tostring(level or 1)) end
    if self.main.coinText then self.main.coinText:SetText(tostring(wallet or "0").." COINS") end
    local accent=(CC.db and CC.db.colors and CC.db.colors.accent) or COLORS.blue
    if self.main.topAccent then self.main.topAccent:SetStatusBarColor(accent[1],accent[2],accent[3],1) end
    if self.main.bpLevelText and self.main.bpLevelText.SetTextColor then
        self.main.bpLevelText:SetTextColor(COLORS.text[1], COLORS.text[2], COLORS.text[3], 1)
    end
    if self.main.coinText and self.main.coinText.SetTextColor then
        self.main.coinText:SetTextColor(accent[1], accent[2], accent[3], 1)
    end
    self:UpdateTabAppearance()
end

function UI:RefreshAll()
    if not self.initialized then return end
    local function refresh(methodName)
        local method = self[methodName]
        if type(method) ~= "function" then return end
        local ok, err = pcall(method, self)
        if not ok then
            CC.state.lastUIRefreshError = tostring(err or "Unknown UI refresh error")
            CC.state.lastUIRefreshMethod = methodName
            CC.state.lastUIRefreshErrorAt = time and time() or 0
        end
    end
    -- Message history is refreshed first and independently. A slow or malformed
    -- Guild/Friends roster can no longer prevent Guild chat text from rendering.
    refresh("RefreshMainMessages")
    refresh("RefreshConversationList")
    refresh("RefreshWhisperContactSwitcher")
    refresh("ApplyRosterCollapseState")
    refresh("RefreshBadges")
    refresh("RefreshPopouts")
    refresh("RefreshCombatPanel")
    refresh("RefreshSettingsPanel")
    refresh("RefreshConsoleEconomy")
end

function UI:GetAnimationDuration()
    return max(0.08, min(0.55, tonumber((CC.db.ui or {}).animationDuration) or 0.20))
end

function UI:NormaliseAnimationStyle(style)
    style = string.upper(tostring(style or "SLIDE_LEFT"))
    if style == "SLIDE" then return "SLIDE_LEFT" end
    if style == "DOCK" then return "SLIDE_DOCK" end
    return style
end

local function animationSourceOffset(frame, sourceFrame, finalX, finalY)
    if not sourceFrame or not sourceFrame.GetCenter or not frame.GetCenter then return 0, 0 end
    local sx, sy = sourceFrame:GetCenter()
    local fx, fy = frame:GetCenter()
    if not sx or not sy or not fx or not fy then return 0, 0 end
    local dx, dy = sx - fx, sy - fy
    local distance = math.sqrt((dx * dx) + (dy * dy))
    if distance > 280 and distance > 0 then
        local scale = 280 / distance
        dx, dy = dx * scale, dy * scale
    end
    return dx, dy
end

function UI:ShowAnimated(frame, requestedStyle, sourceFrame)
    if not frame then return end
    local style = self:NormaliseAnimationStyle(requestedStyle or (CC.db.ui and CC.db.ui.windowAnimation) or "SLIDE_LEFT")
    if frame.creshAnimation then
        frame:SetScript("OnUpdate", nil)
        frame.creshAnimation = nil
    end

    local baseScale = frame.creshBaseScale or frame:GetScale() or 1
    frame.creshBaseScale = baseScale
    frame:SetAlpha(1)
    frame:SetScale(baseScale)

    if style == "NONE" then
        frame:Show()
        return
    end

    local point, relativeTo, relativePoint, x, y = frame:GetPoint(1)
    point = point or "CENTER"
    relativeTo = relativeTo or UIParent
    relativePoint = relativePoint or point
    x, y = x or 0, y or 0
    local duration = self:GetAnimationDuration()
    local elapsedTotal = 0
    local startX, startY = x, y
    local startScale = baseScale
    local startAlpha = 0
    local arcX, arcY = 0, 0
    local overshoot = false

    if style == "FADE" then
        -- Alpha only.
    elseif style == "POP" then
        startScale = baseScale * 0.84
    elseif style == "ZOOM" then
        startScale = baseScale * 0.62
    elseif style == "BOUNCE" then
        startScale = baseScale * 0.72
        overshoot = true
    elseif style == "SLIDE_RIGHT" then
        startX = x + 110
    elseif style == "SLIDE_UP" then
        startY = y - 105
    elseif style == "SLIDE_DOWN" then
        startY = y + 105
    elseif style == "FAN_UP" then
        local dx, dy = animationSourceOffset(frame, sourceFrame, x, y)
        startX, startY = x + dx, y + dy - 38
        startScale = baseScale * 0.70
        arcX, arcY = 34, 16
    elseif style == "FAN_DOWN" then
        local dx, dy = animationSourceOffset(frame, sourceFrame, x, y)
        startX, startY = x + dx, y + dy + 38
        startScale = baseScale * 0.70
        arcX, arcY = -34, -16
    elseif style == "SWOOP" then
        local dx, dy = animationSourceOffset(frame, sourceFrame, x, y)
        startX, startY = x + dx - 60, y + dy - 45
        startScale = baseScale * 0.72
        arcX, arcY = 48, 24
    elseif style == "SLIDE_DOCK" then
        local dx, dy = animationSourceOffset(frame, sourceFrame, x, y)
        if dx == 0 and dy == 0 then
            dx = frame.creshAttachedSide == "RIGHT" and 60 or -60
        end
        startX, startY = x + dx, y + dy
        startScale = baseScale * 0.78
    else -- SLIDE_LEFT and unknown legacy values.
        startX = x - 110
    end

    frame.creshAnimation = true
    frame:ClearAllPoints()
    frame:SetPoint(point, relativeTo, relativePoint, startX, startY)
    frame:SetAlpha(startAlpha)
    frame:SetScale(startScale)
    frame:Show()
    frame:SetScript("OnUpdate", function(selfFrame, elapsed)
        elapsedTotal = elapsedTotal + (elapsed or 0)
        local progress = min(1, elapsedTotal / duration)
        local eased = 1 - ((1 - progress) * (1 - progress))
        local arc = sin(progress * pi)
        local px = startX + ((x - startX) * eased) + (arcX * arc)
        local py = startY + ((y - startY) * eased) + (arcY * arc)
        local scaleProgress = eased
        local currentScale
        if overshoot then
            if progress < 0.72 then
                currentScale = startScale + ((baseScale * 1.07 - startScale) * (progress / 0.72))
            else
                currentScale = baseScale * 1.07 + ((baseScale - baseScale * 1.07) * ((progress - 0.72) / 0.28))
            end
        else
            currentScale = startScale + ((baseScale - startScale) * scaleProgress)
        end
        selfFrame:ClearAllPoints()
        selfFrame:SetPoint(point, relativeTo, relativePoint, px, py)
        selfFrame:SetAlpha(progress)
        selfFrame:SetScale(currentScale)
        if progress >= 1 then
            selfFrame:ClearAllPoints()
            selfFrame:SetPoint(point, relativeTo, relativePoint, x, y)
            selfFrame:SetAlpha(1)
            selfFrame:SetScale(baseScale)
            selfFrame:SetScript("OnUpdate", nil)
            selfFrame.creshAnimation = nil
        end
    end)
end

function UI:HideAnimated(frame, requestedStyle, sourceFrame, finished)
    if not frame or not frame:IsShown() then
        if finished then finished() end
        return
    end
    local style = self:NormaliseAnimationStyle(requestedStyle or "FADE")
    if style == "NONE" then
        frame:Hide()
        if finished then finished() end
        return
    end
    if frame.creshAnimation then frame:SetScript("OnUpdate", nil) end
    local baseScale = frame.creshBaseScale or frame:GetScale() or 1
    local point, relativeTo, relativePoint, x, y = frame:GetPoint(1)
    point, relativeTo, relativePoint = point or "CENTER", relativeTo or UIParent, relativePoint or point or "CENTER"
    x, y = x or 0, y or 0
    local duration = self:GetAnimationDuration() * 0.75
    local elapsedTotal = 0
    local dx, dy = animationSourceOffset(frame, sourceFrame, x, y)
    if style == "SLIDE_LEFT" then dx, dy = -90, 0
    elseif style == "SLIDE_RIGHT" then dx, dy = 90, 0
    elseif style == "SLIDE_UP" then dx, dy = 0, 90
    elseif style == "SLIDE_DOWN" then dx, dy = 0, -90
    elseif style == "FADE" then dx, dy = 0, 0 end
    frame.creshAnimation = true
    frame:SetScript("OnUpdate", function(selfFrame, elapsed)
        elapsedTotal = elapsedTotal + (elapsed or 0)
        local progress = min(1, elapsedTotal / duration)
        local eased = progress * progress
        selfFrame:ClearAllPoints()
        selfFrame:SetPoint(point, relativeTo, relativePoint, x + dx * eased, y + dy * eased)
        selfFrame:SetAlpha(1 - progress)
        if style == "POP" or style == "ZOOM" or style == "BOUNCE" or style == "SLIDE_DOCK" or style == "FAN_UP" or style == "FAN_DOWN" or style == "SWOOP" then
            selfFrame:SetScale(baseScale * (1 - (0.22 * progress)))
        end
        if progress >= 1 then
            selfFrame:Hide()
            selfFrame:ClearAllPoints()
            selfFrame:SetPoint(point, relativeTo, relativePoint, x, y)
            selfFrame:SetAlpha(1)
            selfFrame:SetScale(baseScale)
            selfFrame:SetScript("OnUpdate", nil)
            selfFrame.creshAnimation = nil
            if finished then finished() end
        end
    end)
end

function UI:ApplyVisualSettings()
    self:ValidateThemeOwnership()
    self:SyncThemeColors()
    self:SyncGuildTheme()
    if CC.Games and CC.Games.ApplyTheme then CC.Games:ApplyTheme() end
    if CC.SoloGames and CC.SoloGames.ApplyTheme then CC.SoloGames:ApplyTheme() end
    local options = CC.db.ui or {}
    local scale = max(0.70, min(1.50, tonumber(options.scale) or 1))
    CC.db.panelScale = scale
    if self.main then
        self:ApplySafeFrameScale(self.main, scale, 18)
        local guildMain = self.mode == "GUILD" and options.guildTheme ~= false
        local questMain = self.mode == "QUEST"
        local friendsMain = self.mode == "FRIENDS"
        local modeAccent = select(1, self:GetConsoleModeAccent(self.mode)) or COLORS.blue
        local mainLogoColor = guildMain and GUILD_THEME.panelRaised or (questMain and COLORS.quest or modeAccent)
        local mainLogoBorder = guildMain and GUILD_THEME.border or (questMain and COLORS.quest or modeAccent)
        applyBackdrop(self.main, guildMain and GUILD_THEME.panel or COLORS.panel, guildMain and GUILD_THEME.border or COLORS.border)
        applyBackdrop(self.main.logo, mainLogoColor, mainLogoBorder)
        if self.main.guildWash then self.main.guildWash:SetShown(guildMain) end
        if self.main.topAccent then
            local topColor = guildMain and GUILD_THEME.accent or (questMain and COLORS.quest or COLORS.blue)
            self.main.topAccent:SetStatusBarColor(topColor[1], topColor[2], topColor[3], 1)
        end
        if self.main.buildBadge then self:LayoutMainHeader() end
        if self.main.logoText then self.main.logoText:SetText(self:GetLauncherBaseText()); self:ApplyLauncherTextStyle(self.main.logoText, true) end
        if self.main.subtitle then
            if questMain then
                local meta = self.currentQuestTarget and CC:GetQuestConversationMeta(self.currentQuestTarget) or nil
                self.main.subtitle:SetText(meta and meta.zone or "Quest-giver conversations by zone")
            elseif friendsMain then
                self:RefreshFriendsHeader()
            elseif guildMain then
                self.main.subtitle:SetText("Guild and officer messages")
            elseif self:IsGeneralFeedMode(self.mode) then
                local definition = CONSOLE_TAB_LOOKUP[self.mode] or CONSOLE_TAB_LOOKUP.GENERAL
                self.main.subtitle:SetText(definition.subtitle)
            elseif self.mode == "COMBAT" then
                self.main.subtitle:SetText(CONSOLE_TAB_LOOKUP.COMBAT.subtitle)
            else
                self.main.subtitle:SetText(self:IsZLRTheme() and "Arena relay // TBC Anniversary" or "Messenger overlay for TBC Anniversary")
            end
        end
        self:LayoutMainTabs()
        self:UpdateTabAppearance()
        self:UpdateFriendsDirectoryTabs()
    end
    if self.gameDrawer then
        local drawer = self.gameDrawer
        applyBackdrop(drawer, COLORS.panel, COLORS.border)
        if drawer.header then applyBackdrop(drawer.header, COLORS.panelRaised, COLORS.border) end
        if drawer.statusBox then applyBackdrop(drawer.statusBox, COLORS.panelSoft, COLORS.border) end
        if drawer.close then self:SetTabButtonStyle(drawer.close, false, COLORS.red, brightenColor(COLORS.red, 0.08), COLORS.panelRaised) end
        if drawer.history then self:SetTabButtonStyle(drawer.history, false, COLORS.quest, brightenColor(COLORS.quest, 0.08), COLORS.panelRaised) end
        if drawer.leaderboard then self:SetTabButtonStyle(drawer.leaderboard, false, COLORS.blue, COLORS.blueHover, COLORS.panelRaised) end
        if drawer.scan then self:SetTabButtonStyle(drawer.scan, false, COLORS.blue, COLORS.blueHover, COLORS.panelRaised) end
        for _, card in pairs(drawer.soloCards or {}) do
            local accent = card.info and card.info.accent or COLORS.blue
            applyBackdrop(card, COLORS.panelSoft, COLORS.border)
            if card.art then applyBackdrop(card.art, darkenColor(accent, 0.25), accent) end
            if card.play then self:SetTabButtonStyle(card.play, false, accent, brightenColor(accent, 0.08), COLORS.panelRaised) end
        end
        for _, card in pairs(drawer.multiCards or {}) do
            applyBackdrop(card, COLORS.panelSoft, COLORS.border)
            if card.challenge then self:SetTabButtonStyle(card.challenge, false, COLORS.blue, COLORS.blueHover, COLORS.panelRaised) end
        end
        self:SetGameDrawerMode(drawer.mode or "SOLO", true)
        self:PositionGameDrawer(nil, self:GetGameDrawerSide())
    end
    if self.combatPanel then
        self:ApplySafeFrameScale(self.combatPanel, scale, 18)
        applyBackdrop(self.combatPanel, COLORS.panel, COLORS.border)
    end
    if self.bubble then
        applyBackdrop(self.bubble, COLORS.blue, COLORS.blue)
        if self.bubble.icon and not self.launcherCurrentNotice then
            self.bubble.icon:SetText(self:GetLauncherBaseText())
            self:ApplyLauncherTextStyle(self.bubble.icon, false)
        end
        self:RefreshLauncherNotification()
    end
    if self.whisperBubble then applyBackdrop(self.whisperBubble, COLORS.panelRaised, COLORS.border) end
    if self.generalBubble then applyBackdrop(self.generalBubble, COLORS.panelRaised, COLORS.border) end
    if self.combatBubble then applyBackdrop(self.combatBubble, COLORS.panelRaised, COLORS.border) end
    for _, popout in pairs(self.popouts or {}) do
        local guildPopout = popout.channel == "GUILD" and (CC.db.ui or {}).guildTheme ~= false
        applyBackdrop(popout, guildPopout and GUILD_THEME.panel or COLORS.panel, guildPopout and GUILD_THEME.border or COLORS.border)
        local channelAccent = guildPopout and GUILD_THEME.accent
            or (popout.channel == "QUEST" and COLORS.quest)
            or ((CC.db.colors and CC.db.colors.channels and CC.db.colors.channels[popout.channel]) or COLORS.blue)
        if popout.accent then popout.accent:SetColorTexture(channelAccent[1], channelAccent[2], channelAccent[3], 1) end
        if popout.header and popout.header.background then
            if guildPopout then popout.header.background:SetColorTexture(GUILD_THEME.panelRaised[1], GUILD_THEME.panelRaised[2], GUILD_THEME.panelRaised[3], 1)
            else popout.header.background:SetColorTexture(COLORS.panelRaised[1], COLORS.panelRaised[2], COLORS.panelRaised[3], COLORS.panelRaised[4] or 1) end
        end
        if popout.header and popout.header.divider then
            popout.header.divider:SetColorTexture(COLORS.border[1], COLORS.border[2], COLORS.border[3], 0.70)
        end
        if popout.commandBar then
            applyBackdrop(popout.commandBar, guildPopout and GUILD_THEME.panelSoft or COLORS.panel, guildPopout and GUILD_THEME.border or COLORS.border)
            if popout.commandBar.edit then
                applyBackdrop(popout.commandBar.edit, guildPopout and GUILD_THEME.panelRaised or COLORS.panelRaised,
                    guildPopout and GUILD_THEME.border or COLORS.panelRaised)
            end
            if popout.commandBar.label and popout.commandBar.label.SetTextColor then
                local labelColor = guildPopout and GUILD_THEME.muted or COLORS.muted
                popout.commandBar.label:SetTextColor(labelColor[1], labelColor[2], labelColor[3], 1)
            end
        end
        self:ApplyPopoutLayout(popout)
        self:SchedulePopoutFade(popout)
    end

    local sharedWidth = max(320, min(720, tonumber(options.sharedDockWidth) or tonumber(options.composerWidth) or 470))
    local popoutWidth = max(300, min(620, tonumber(options.popoutWidth) or 400))
    options.sharedDockWidth = sharedWidth
    options.composerWidth = sharedWidth
    options.popoutWidth = popoutWidth
    for _, popout in pairs(self.popouts or {}) do
        popout:SetWidth(popoutWidth)
        self:ApplySafeFrameScale(popout, scale, 18)
    end

    if self.quickInput then
        local composerScale = max(0.70, min(1.50, tonumber(options.composerScale) or 1))
        self.quickInput.creshBaseScale = composerScale
        self.quickInput:SetScale(composerScale)
        applyBackdrop(self.quickInput, COLORS.panel, COLORS.border)
        if self.quickInput.edit then applyBackdrop(self.quickInput.edit, COLORS.panelRaised, COLORS.panelRaised) end
        if self.quickInput.accent then self.quickInput.accent:SetColorTexture(COLORS.blue[1], COLORS.blue[2], COLORS.blue[3], 1) end
        if self.quickInput.dragText then self.quickInput.dragText:SetText("::") end
        if self.quickInput.send then self.quickInput.send:SetShown(options.composerShowSend ~= false) end
        if self.quickInput.edit then
            self.quickInput.edit:ClearAllPoints()
            self.quickInput.edit:SetPoint("TOPLEFT", self.quickInput.channel, "TOPRIGHT", 6, 0)
            self.quickInput.edit:SetPoint("BOTTOMRIGHT", self.quickInput, "BOTTOMRIGHT", options.composerShowSend == false and -6 or -36, 8)
        end
        self.quickInput.creshPositionApplied = false
        self:ApplyConnectedDockDimensions()
        self:PositionQuickInput(true)
        self:RefreshQuickInputLabel()
    end
    for _, toast in ipairs(self.toasts or {}) do
        self:ApplyCardSettings(toast)
        applyBackdrop(toast, toast.notificationPromoted and COLORS.panel or COLORS.panelSoft, COLORS.border)
    end
    for _, toast in ipairs(self.secondaryToasts or {}) do
        self:ApplyCardSettings(toast)
        applyBackdrop(toast, COLORS.panel, COLORS.border)
    end

    if CC.SoloGames and CC.SoloGames.window then self:ApplySafeFrameScale(CC.SoloGames.window, scale, 22) end
    if CC.Games then
        if CC.Games.gameWindow then self:ApplySafeFrameScale(CC.Games.gameWindow, scale, 22) end
        if CC.Games.challengePopup then self:ApplySafeFrameScale(CC.Games.challengePopup, scale, 22) end
    end
    if self.FullSettings and self.FullSettings.frame then
        self:ApplySafeFrameScale(self.FullSettings.frame, scale, 22)
        if self.FullSettings.KeepOnTop then self.FullSettings:KeepOnTop() end
    end

    self:SetBubbleGroupShown(CC.db.bubbleVisible)
    self:PositionQuickButtons()
    self:PositionCombatPanel()
    self:RefreshWhisperChrome()
    self:RefreshAll()
    if self.fullSettings and self.fullSettings.Refresh then self.fullSettings:Refresh() end
end

local function frameRect(frame)
    if not frame or not frame.IsShown or not frame:IsShown() then return nil end
    local left, right, bottom, top = frame:GetLeft(), frame:GetRight(), frame:GetBottom(), frame:GetTop()
    if not left or not right or not bottom or not top then return nil end
    return left, right, bottom, top
end

local function framesOverlap(first, second, padding)
    local l1, r1, b1, t1 = frameRect(first)
    local l2, r2, b2, t2 = frameRect(second)
    if not l1 or not l2 then return false end
    padding = padding or 6
    return not (r1 + padding <= l2 or r2 + padding <= l1 or t1 + padding <= b2 or t2 + padding <= b1)
end

function UI:PositionMainNearLauncher()
    if not self.main or not self.bubble or not CC.db.ui or CC.db.ui.autoArrange == false then return end
    local x, y = self.bubble:GetCenter()
    local screenWidth = UIParent:GetWidth() or 1
    local screenHeight = UIParent:GetHeight() or 1
    local onRight = x and x > screenWidth / 2
    local placeAbove = not y or y < screenHeight * 0.62
    self.main:ClearAllPoints()
    if placeAbove then
        if onRight then self.main:SetPoint("BOTTOMRIGHT", self.bubble, "TOPRIGHT", 0, 12)
        else self.main:SetPoint("BOTTOMLEFT", self.bubble, "TOPLEFT", 0, 12) end
    else
        if onRight then self.main:SetPoint("TOPRIGHT", self.bubble, "BOTTOMRIGHT", 0, -12)
        else self.main:SetPoint("TOPLEFT", self.bubble, "BOTTOMLEFT", 0, -12) end
    end
    savePosition(self.main, "main")
end

function UI:PositionMainFromComposer()
    if not self.main or not self.quickInput or not CC.db.ui then
        self:PositionMainNearLauncher()
        return
    end
    local bar = self.quickInput
    local centerX, centerY = bar:GetCenter()
    local screenWidth = UIParent:GetWidth() or 1
    local screenHeight = UIParent:GetHeight() or 1
    local onRight = centerX and centerX > screenWidth / 2
    local barTop = bar:GetTop() or centerY or 0
    local barBottom = bar:GetBottom() or centerY or 0
    local mainHeight = (self.main:GetHeight() or 520) * (self.main:GetScale() or 1)
    local roomAbove = screenHeight - barTop
    local roomBelow = barBottom
    local placeAbove = roomAbove >= mainHeight + 12 or roomAbove >= roomBelow

    self.main:ClearAllPoints()
    -- Anchor to the outside edge of the complete C + command-bar dock. The
    -- composer is a separate frame, so anchoring only to it previously left C
    -- hanging outside the main window width.
    local outerAnchor = self.bubble or bar
    local composerOnLeft = bar.creshAttachedSide == "RIGHT"
    if placeAbove then
        if composerOnLeft then self.main:SetPoint("BOTTOMRIGHT", outerAnchor, "TOPRIGHT", 0, 9)
        else self.main:SetPoint("BOTTOMLEFT", outerAnchor, "TOPLEFT", 0, 9) end
    else
        if composerOnLeft then self.main:SetPoint("TOPRIGHT", outerAnchor, "BOTTOMRIGHT", 0, -9)
        else self.main:SetPoint("TOPLEFT", outerAnchor, "BOTTOMLEFT", 0, -9) end
    end
    self.main.creshDockedToComposer = true
end

function UI:SyncMainToComposerDestination()
    local channel, target = self:GetQuickDestination()
    if channel == "WHISPER" then
        self:SetMode("WHISPER", target)
    elseif channel == "GUILD" or channel == "OFFICER" then
        self:SetMode("GUILD")
    elseif self:IsGeneralFeedMode(channel) then
        self:SetMode(self:IsConsoleTabEnabled(channel) and channel or "GENERAL")
    else
        self:SetMode("GENERAL")
    end
end

function UI:RevealMainFromComposer(reason)
    if not self.main or not self.quickInput then return end
    self:SyncMainToComposerDestination()
    self:PositionMainFromComposer()
    if not self.main:IsShown() then
        self:ShowAnimated(self.main, (CC.db.ui or {}).dockAnimation or "SLIDE_DOCK", self.quickInput)
    end
    self:MarkCurrentRead()
    self:ResolveWindowOverlaps(self.main)
end

function UI:OpenDockChat()
    if not self.main then return end
    local options = CC.db.ui or {}
    if options.launcherOpensComposer == false then
        self:PositionMainNearLauncher()
        self:ShowAnimated(self.main, options.windowAnimation, self.bubble)
        self:MarkCurrentRead()
        return
    end
    if not self.quickInput then return end
    self:OpenQuickInput("", true)
    self:RevealMainFromComposer("LAUNCHER")
    if self.quickInput.edit then self.quickInput.edit:SetFocus() end
end

function UI:CloseDockChat()
    local ui = CC.db.ui or {}
    if self.main and self.main:IsShown() then
        self:HideAnimated(self.main, ui.dockAnimation or "SLIDE_DOCK", self.quickInput)
    end
    if self.quickInput and self.quickInput:IsShown() then
        if self.quickInput.edit then self.quickInput.edit:ClearFocus() end
        self:HideAnimated(self.quickInput, ui.composerAnimation or "SLIDE_DOCK", self.bubble)
    end
end

function UI:ArrangePopouts()
    -- Pop-outs are positioned once when first created. Saved/manual positions are
    -- never re-tiled, snapped to the dock, or changed by chat/settings refreshes.
    local pending = {}
    for id, popout in pairs(self.popouts or {}) do
        if popout:IsShown() and not popout.creshUserPositioned and not popout.creshInitialPlaced then
            tinsert(pending, { id = tostring(id), frame = popout, order = popout.creshOrder or 0 })
        end
    end
    sort(pending, function(left, right)
        if left.order == right.order then return left.id < right.id end
        return left.order < right.order
    end)
    if #pending == 0 then return end

    local screenWidth = UIParent:GetWidth() or 1920
    local screenHeight = UIParent:GetHeight() or 1080
    for index, item in ipairs(pending) do
        local popout = item.frame
        local width = popout:GetWidth() or 400
        local height = popout:GetHeight() or 300
        local column = floor((index - 1) / 2)
        local row = (index - 1) % 2
        local x = max(8, min(screenWidth - width - 8, 70 + column * (width + 12)))
        local y = max(height + 8, min(screenHeight - 8, screenHeight - 90 - row * (height + 12)))
        popout:ClearAllPoints()
        popout:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
        popout.creshInitialPlaced = true
        savePosition(popout, "popout_" .. item.id)
    end
end

function UI:ResolveWindowOverlaps(changedFrame)
    -- Only connected dock surfaces auto-align. Detached pop-outs are intentionally
    -- excluded so they stay exactly where the player leaves them.
    if self.main and self.main:IsShown() and self.quickInput and self.quickInput:IsShown() and framesOverlap(self.main, self.quickInput, 6) then
        self:PositionMainFromComposer()
    end
    if self.combatPanel and self.combatPanel:IsShown() and self.quickInput and self.quickInput:IsShown() and framesOverlap(self.combatPanel, self.quickInput, 6) then
        self:PositionCombatPanel()
    end
    self:PositionWhisperDockAlert()
    self:RepositionToasts()
end

function UI:ToggleMain()
    if not self.main or not self.quickInput then return end
    -- C always controls the connected composer/main dock, even when a pop-out is active.
    local bothShown = self.main:IsShown() and self.quickInput:IsShown()
    if bothShown then
        self:CloseDockChat()
    else
        self:OpenDockChat()
    end
end

function UI:OpenChannel(channel, target)
    if string.upper(tostring(channel or "")) == "GAMES" then
        self:OpenGameDrawer("MULTIPLAYER", target)
        return
    end
    self:SetMode(channel, target)
    if self.quickInput and self.quickInput:IsShown() then
        self:PositionMainFromComposer()
        self:ShowAnimated(self.main, (CC.db.ui or {}).dockAnimation or "SLIDE_DOCK", self.quickInput)
    else
        self:PositionMainNearLauncher()
        self:ShowAnimated(self.main, (CC.db.ui or {}).windowAnimation, self.bubble)
    end
    self:MarkCurrentRead()
    self:ResolveWindowOverlaps(self.main)
end

function UI:GetPopupScale()
    local options = CC.db.ui or {}
    return max(0.65, min(1.50, tonumber(options.notificationScale) or tonumber(options.cardScale) or 0.95))
end

function UI:GetCardDimensions(lane, promoted, kind)
    local options = CC.db.ui or {}
    local width = max(230, min(440, tonumber(options.cardWidth) or 300))
    local height = max(56, min(104, tonumber(options.cardHeight) or 68))
    local scale = self:GetPopupScale()
    lane = string.upper(tostring(lane or "SLIDE"))
    promoted = promoted == true
    kind = string.upper(tostring(kind or ""))

    if lane == "NORMAL" or promoted or kind == "PARTY" then
        return width, height, scale
    end

    local widthRatio = max(0.72, min(0.96, tonumber(options.secondaryCardWidthRatio) or 0.88))
    local heightRatio = max(0.62, min(0.92, tonumber(options.secondaryCardHeightRatio) or 0.80))
    return max(205, floor(width * widthRatio + 0.5)), max(44, floor(height * heightRatio + 0.5)), scale
end

function UI:GetToastDimensions(toast)
    if not toast then return self:GetCardDimensions("NORMAL", true) end
    local role = string.upper(tostring(toast.notificationRole or (toast.cardLane == "SECONDARY" and "NORMAL" or "SLIDE")))
    return self:GetCardDimensions(role, toast.notificationPromoted == true, toast.kind)
end

function UI:GetCardDuration(lane)
    local options = CC.db.ui or {}
    lane = string.upper(tostring(lane or "SLIDE"))
    if lane == "NORMAL" or lane == "SECONDARY" then
        return max(2, min(20, tonumber(options.secondaryCardDuration) or 6))
    end
    return max(3, min(30, tonumber(options.priorityCardDuration) or tonumber(CC.db.alertDuration) or 10))
end

function UI:GetNotificationRole(kind, fallbackRole)
    local priority = CC.GetNotificationPriority and CC:GetNotificationPriority(kind) or "NORMAL"
    if priority == "CRITICAL" or priority == "HIGH" then return "NORMAL" end
    return "SLIDE"
end

function UI:GetNotificationDuration(kind, role)
    local base = self:GetCardDuration(role)
    local priority = CC.GetNotificationPriority and CC:GetNotificationPriority(kind) or "NORMAL"
    if priority == "CRITICAL" then return max(base, min(30, base * 1.60)) end
    if priority == "HIGH" then return max(base, min(30, base * 1.25)) end
    if priority == "LOW" then return max(2, base * 0.65) end
    return base
end

function UI:RemoveToastFromActiveLists(toast)
    if not toast then return end
    for _, list in ipairs({ self.toasts or {}, self.secondaryToasts or {} }) do
        for index = #list, 1, -1 do if list[index] == toast then tremove(list, index) end end
    end
end

function UI:AddToastToRole(toast, role)
    role = string.upper(tostring(role or "SLIDE"))
    self:RemoveToastFromActiveLists(toast)
    if role == "NORMAL" then
        self.secondaryToasts = self.secondaryToasts or {}
        while #self.secondaryToasts >= self:GetCardLimit("NORMAL") do self:DismissToast(self.secondaryToasts[1], true) end
        toast.cardLane = "SECONDARY"
        toast.notificationRole = "NORMAL"
        tinsert(self.secondaryToasts, toast)
    else
        self:MakeRoomForSlideToast()
        self.toasts = self.toasts or {}
        toast.cardLane = "PRIORITY"
        toast.notificationRole = "SLIDE"
        tinsert(self.toasts, toast)
    end
    toast.notificationPriority = CC.GetNotificationPriority and CC:GetNotificationPriority(toast.kind) or "NORMAL"
    toast.notificationCreatedAt = launcherTime and launcherTime() or (GetTime and GetTime() or 0)
end

function UI:GetMessageNotificationKind(channel, message)
    channel = string.upper(tostring(channel or "SYSTEM"))
    if channel ~= "GENERAL" then return channel end
    local chatType = string.upper(tostring(message and message.chatType or ""))
    if chatType == "CHAT_MSG_PARTY" or chatType == "CHAT_MSG_PARTY_LEADER" or chatType == "CHAT_MSG_RAID" or chatType == "CHAT_MSG_RAID_LEADER" or chatType == "CHAT_MSG_RAID_WARNING" or chatType == "CHAT_MSG_INSTANCE_CHAT" or chatType == "CHAT_MSG_INSTANCE_CHAT_LEADER" then
        return "PARTY_MESSAGE"
    end
    return "GENERAL"
end

function UI:GetCardLimit(lane)
    local options = CC.db.ui or {}
    lane = string.upper(tostring(lane or "SLIDE"))
    if lane == "NORMAL" or lane == "SECONDARY" then
        return max(1, min(8, floor(tonumber(options.secondaryCardMaxVisible) or 4)))
    end
    return max(1, min(10, floor(tonumber(options.cardMaxVisible) or 6)))
end

function UI:GetCardLists(lane)
    if string.upper(tostring(lane or "PRIORITY")) == "SECONDARY" then
        self.secondaryToasts = self.secondaryToasts or {}
        self.secondaryToastPool = self.secondaryToastPool or {}
        return self.secondaryToasts, self.secondaryToastPool
    end
    self.toasts = self.toasts or {}
    self.toastPool = self.toastPool or {}
    return self.toasts, self.toastPool
end

function UI:GetEffectiveCardStackDirection()
    return string.upper(tostring((CC.db.ui or {}).cardStack or "UP")) == "DOWN" and "DOWN" or "UP"
end

function UI:GetNotificationSlideDirection()
    local direction = string.upper(tostring((CC.db.ui or {}).notificationSlideDirection or "BOTTOM"))
    if direction ~= "TOP" and direction ~= "BOTTOM" and direction ~= "LEFT" and direction ~= "RIGHT" then direction = "BOTTOM" end
    return direction
end

function UI:GetNotificationHubAnchor()
    local options = CC.db.ui or {}
    local location = string.upper(tostring(options.cardLocation or "DOCK"))
    local horizontal = string.upper(tostring(options.cardHorizontal or "LEFT"))
    local vertical = string.upper(tostring(options.cardVertical or "BOTTOM"))
    local width, height, scale = self:GetCardDimensions("NORMAL", true)
    local visualWidth, visualHeight = width * scale, height * scale
    local screenWidth = UIParent:GetWidth() or 1920
    local screenHeight = UIParent:GetHeight() or 1080
    local x, y

    if location == "TOPLEFT" then location, horizontal, vertical = "SCREEN", "LEFT", "TOP"
    elseif location == "TOPRIGHT" then location, horizontal, vertical = "SCREEN", "RIGHT", "TOP"
    elseif location == "BOTTOMLEFT" then location, horizontal, vertical = "SCREEN", "LEFT", "BOTTOM"
    elseif location == "BOTTOMRIGHT" then location, horizontal, vertical = "SCREEN", "RIGHT", "BOTTOM" end

    if location == "CUSTOM" then
        local saved = CC.db.positions and CC.db.positions.alerts
        x = saved and tonumber(saved.x) or 0
        y = saved and tonumber(saved.y) or 148
    elseif location == "MAIN" and self.main and self.main:IsShown() and self.main.GetLeft then
        x = self.main:GetLeft() or 0
        y = (self.main:GetTop() or visualHeight) + 10
    elseif location == "SCREEN" then
        if horizontal == "CENTER" or horizontal == "MIDDLE" then x = (screenWidth - visualWidth) / 2
        elseif horizontal == "RIGHT" then x = screenWidth - visualWidth
        else x = 0 end
        if vertical == "TOP" then y = screenHeight - visualHeight
        elseif vertical == "MIDDLE" then y = (screenHeight - visualHeight) / 2
        else y = 0 end
    else
        local anchor = self.quickInput and self.quickInput:IsShown() and self.quickInput or self.bubble
        if anchor and anchor.GetLeft then
            x = anchor:GetLeft() or 0
            y = (anchor:GetTop() or visualHeight) + 10
            if self.main and self.main:IsShown() and framesOverlap(self.main, anchor, 0) then
                y = max(y, (self.main:GetTop() or y) + 10)
            end
        else
            x, y = 0, 148
        end
    end

    return x or 0, y or 0
end

function UI:GetCardStackMetrics()
    local width, height, scale = self:GetCardDimensions("NORMAL", true)
    local spacing = max(0, min(24, tonumber((CC.db.ui or {}).cardSpacing) or 6))
    local normalCount, slideCount = 0, 0
    for _, toast in ipairs(self.secondaryToasts or {}) do if not toast.slidingOut then normalCount = normalCount + 1 end end
    for _, toast in ipairs(self.toasts or {}) do if not toast.slidingOut then slideCount = slideCount + 1 end end
    local mainCount = normalCount > 0 and normalCount or min(1, slideCount)
    local totalHeight = mainCount > 0 and ((height * scale) + ((mainCount - 1) * ((height * scale) + spacing))) or 0
    return width * scale, totalHeight, height * scale, totalHeight, 0, 0, (height * scale) + spacing, (height * scale) + spacing, slideCount, normalCount
end

function UI:GetCardAnchor()
    return self:GetNotificationHubAnchor()
end

function UI:GetCardLaneX(stackLeft)
    return stackLeft
end

function UI:AvoidCardOverlaps(baseX, baseY)
    return baseX, baseY
end

function UI:ApplyCardSettings(toast)
    if not toast then return end
    local role = string.upper(tostring(toast.notificationRole or (toast.cardLane == "SECONDARY" and "NORMAL" or "SLIDE")))
    local width, height, scale = self:GetToastDimensions(toast)
    local compact = role == "SLIDE" and toast.notificationPromoted ~= true and toast.kind ~= "PARTY"
    local portraitSize = compact and 26 or 34
    local titleSize = compact and 10 or 12
    local bodySize = compact and 9 or 11
    local timeSize = compact and 8 or 9
    local lineHeight = max(2, min(6, floor(tonumber((CC.db.ui or {}).notificationLineHeight) or 3)))

    toast:SetSize(width, height)
    toast.creshBaseScale = scale
    if not toast:IsShown() or not toast:GetScript("OnUpdate") or toast.dragging then toast:SetScale(scale) end
    toast:SetFrameStrata((role == "NORMAL" or toast.notificationPromoted) and "TOOLTIP" or "FULLSCREEN_DIALOG")

    if toast.accent then
        toast.accent:ClearAllPoints()
        toast.accent:SetPoint("TOPLEFT", toast, "TOPLEFT", 1, -1)
        toast.accent:SetPoint("TOPRIGHT", toast, "TOPRIGHT", -1, -1)
        toast.accent:SetHeight(lineHeight)
    end
    if toast.playerPortrait then
        toast.playerPortrait:SetSize(portraitSize, portraitSize)
        toast.playerPortrait:ClearAllPoints()
        toast.playerPortrait:SetPoint("LEFT", toast, "LEFT", compact and 8 or 10, -1)
    end
    if toast.title then
        toast.title:SetFont(STANDARD_TEXT_FONT, titleSize, "")
        toast.title:ClearAllPoints()
        toast.title:SetPoint("TOPLEFT", toast.playerPortrait, "TOPRIGHT", compact and 7 or 9, compact and 2 or 4)
        toast.title:SetPoint("RIGHT", toast, "RIGHT", compact and -38 or -50, 0)
    end
    if toast.timeText then
        toast.timeText:SetFont(STANDARD_TEXT_FONT, timeSize, "")
        toast.timeText:ClearAllPoints()
        toast.timeText:SetPoint("TOPRIGHT", toast, "TOPRIGHT", -8, -(lineHeight + 5))
        toast.timeText:SetWidth(compact and 32 or 42)
    end
    if toast.preview then
        toast.preview:SetFont(STANDARD_TEXT_FONT, bodySize, "")
        local rightInset = toast.kind == "PARTY" and -132 or (toast.kind == "WHISPER" and -62 or -9)
        if compact and toast.kind ~= "WHISPER" then rightInset = -8 end
        toast.preview:ClearAllPoints()
        toast.preview:SetPoint("TOPLEFT", toast.title, "BOTTOMLEFT", 0, compact and 0 or -2)
        toast.preview:SetPoint("RIGHT", toast, "RIGHT", rightInset, 0)
        toast.preview:SetHeight(max(12, height - (compact and 24 or 42)))
    end
    if toast.reply then
        toast.reply:SetSize(50, 18)
        toast.reply:ClearAllPoints(); toast.reply:SetPoint("BOTTOMRIGHT", toast, "BOTTOMRIGHT", -7, 6)
        toast.reply:SetShown(toast.kind == "WHISPER")
    end
    if toast.accept then
        toast.accept:SetSize(58, 18)
        toast.accept:ClearAllPoints(); toast.accept:SetPoint("BOTTOMRIGHT", toast, "BOTTOMRIGHT", -68, 6)
        toast.accept:SetShown(toast.kind == "PARTY")
    end
    if toast.decline then
        toast.decline:SetSize(58, 18)
        toast.decline:ClearAllPoints(); toast.decline:SetPoint("BOTTOMRIGHT", toast, "BOTTOMRIGHT", -7, 6)
        toast.decline:SetShown(toast.kind == "PARTY")
    end
end

function UI:SetToastPosition(toast)
    if not toast then return end
    toast:ClearAllPoints()
    toast:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", toast.currentX or -380, toast.currentY or 150)
end

local function activeToastList(source)
    local output = {}
    for _, toast in ipairs(source or {}) do
        if toast and not toast.slidingOut then output[#output + 1] = toast end
    end
    table.sort(output, function(a, b)
        local rankA = CC.GetNotificationPriorityRank and CC:GetNotificationPriorityRank(a.kind) or 2
        local rankB = CC.GetNotificationPriorityRank and CC:GetNotificationPriorityRank(b.kind) or 2
        if rankA ~= rankB then return rankA < rankB end
        return (tonumber(a.notificationCreatedAt) or 0) < (tonumber(b.notificationCreatedAt) or 0)
    end)
    return output
end

function UI:RepositionToasts()
    self.toasts = self.toasts or {}
    self.secondaryToasts = self.secondaryToasts or {}

    local normal = activeToastList(self.secondaryToasts)
    local slides = activeToastList(self.toasts)
    local promoted = (#normal == 0 and #slides > 0) and slides[#slides] or nil
    local baseX, baseY = self:GetNotificationHubAnchor()
    local spacing = max(0, min(24, tonumber((CC.db.ui or {}).cardSpacing) or 6))
    local normalDirection = self:GetEffectiveCardStackDirection()
    local slideDirection = self:GetNotificationSlideDirection()
    local layout = {}

    local function add(toast, x, y, role, isPromoted)
        toast.notificationRole = role
        toast.notificationPromoted = isPromoted == true
        setBackground(toast, (role == "NORMAL" or toast.notificationPromoted) and COLORS.panel or COLORS.panelSoft)
        self:ApplyCardSettings(toast)
        local width, height, scale = self:GetToastDimensions(toast)
        layout[#layout + 1] = { toast = toast, x = x, y = y, width = width * scale, height = height * scale }
    end

    if #normal > 0 then
        local newest = #normal
        for index = newest, 1, -1 do
            local toast = normal[index]
            local distance = newest - index
            local _, height, scale = self:GetCardDimensions("NORMAL", true, toast.kind)
            local step = (height * scale) + spacing
            local y = baseY + ((normalDirection == "DOWN" and -1 or 1) * distance * step)
            add(toast, baseX, y, "NORMAL", false)
        end
    elseif promoted then
        add(promoted, baseX, baseY, "SLIDE", true)
    end

    local minX, minY, maxX, maxY
    for _, item in ipairs(layout) do
        minX = minX and min(minX, item.x) or item.x
        minY = minY and min(minY, item.y) or item.y
        maxX = maxX and max(maxX, item.x + item.width) or (item.x + item.width)
        maxY = maxY and max(maxY, item.y + item.height) or (item.y + item.height)
    end

    if not minX then
        local width, height, scale = self:GetCardDimensions("NORMAL", true)
        minX, minY, maxX, maxY = baseX, baseY, baseX + width * scale, baseY + height * scale
    end

    local slideIndex = 0
    for index = #slides, 1, -1 do
        local toast = slides[index]
        if toast ~= promoted then
            slideIndex = slideIndex + 1
            toast.notificationRole = "SLIDE"
            toast.notificationPromoted = false
            setBackground(toast, COLORS.panelSoft)
            self:ApplyCardSettings(toast)
            local width, height, scale = self:GetToastDimensions(toast)
            local visualWidth, visualHeight = width * scale, height * scale
            local x, y
            if slideDirection == "TOP" then
                x = baseX + max(0, ((maxX - minX) - visualWidth) / 2)
                y = maxY + spacing
                maxY = y + visualHeight
                minX, maxX = min(minX, x), max(maxX, x + visualWidth)
            elseif slideDirection == "LEFT" then
                x = minX - visualWidth - spacing
                y = baseY + max(0, ((maxY - minY) - visualHeight) / 2)
                minX = x
                minY, maxY = min(minY, y), max(maxY, y + visualHeight)
            elseif slideDirection == "RIGHT" then
                x = maxX + spacing
                y = baseY + max(0, ((maxY - minY) - visualHeight) / 2)
                maxX = x + visualWidth
                minY, maxY = min(minY, y), max(maxY, y + visualHeight)
            else
                x = baseX + max(0, ((maxX - minX) - visualWidth) / 2)
                y = minY - visualHeight - spacing
                minY = y
                minX, maxX = min(minX, x), max(maxX, x + visualWidth)
            end
            layout[#layout + 1] = { toast = toast, x = x, y = y, width = visualWidth, height = visualHeight }
        end
    end

    local screenWidth, screenHeight = UIParent:GetWidth() or 1920, UIParent:GetHeight() or 1080
    local shiftX, shiftY = 0, 0
    if minX < 0 then shiftX = -minX elseif maxX > screenWidth then shiftX = screenWidth - maxX end
    if minY < 0 then shiftY = -minY elseif maxY > screenHeight then shiftY = screenHeight - maxY end

    self.notificationBaseX = baseX + shiftX
    self.notificationBaseY = baseY + shiftY
    self.notificationPromotedToast = promoted

    for _, item in ipairs(layout) do
        local toast = item.toast
        toast.targetX = item.x + shiftX
        toast.targetY = item.y + shiftY
        if toast.currentX == nil then toast.currentX = toast.targetX end
        if toast.currentY == nil then toast.currentY = toast.targetY end
        if not toast.dragging then self:SetToastPosition(toast) end
    end
end

function UI:SaveCardStackFromDrag(toast)
    if not toast or not toast.GetLeft or not toast.GetBottom then return end
    local left, bottom = toast:GetLeft(), toast:GetBottom()
    if not left or not bottom then return end
    local targetX = tonumber(toast.targetX) or left
    local targetY = tonumber(toast.targetY) or bottom
    local baseX = tonumber(self.notificationBaseX) or targetX
    local baseY = tonumber(self.notificationBaseY) or targetY
    CC.db.positions = CC.db.positions or {}
    CC.db.positions.alerts = {
        point = "BOTTOMLEFT", relativePoint = "BOTTOMLEFT",
        x = baseX + (left - targetX), y = baseY + (bottom - targetY),
    }
    CC.db.ui.cardLocation = "CUSTOM"
end

function UI:RecycleToast(toast)
    if not toast then return end
    local list, pool = self:GetCardLists(toast.cardLane)
    for index, candidate in ipairs(list) do
        if candidate == toast then tremove(list, index) break end
    end
    toast:Hide()
    toast:SetScript("OnUpdate", nil)
    toast.slidingOut = false
    toast.hovered = false
    toast.dragging = false
    toast.kind = nil
    toast.target = nil
    toast.inviter = nil
    toast.secondaryKey = nil
    toast.isTestInvite = nil
    toast.partyAction = nil
    if toast.accept and toast.accept.label then toast.accept.label:SetText("ACCEPT") end
    if toast.decline and toast.decline.label then toast.decline.label:SetText("DECLINE") end
    if toast.accept and toast.accept.Enable then toast.accept:Enable() end
    if toast.decline and toast.decline.Enable then toast.decline:Enable() end
    toast.notificationRole = nil
    toast.notificationPromoted = nil
    toast.notificationPriority = nil
    toast.notificationCreatedAt = nil
    toast.messageCount = nil
    tinsert(pool, toast)
    self:RepositionToasts()
end

function UI:DismissToast(toast, immediate)
    if not toast or not toast:IsShown() then return end
    if immediate then self:RecycleToast(toast) return end
    toast.slidingOut = true
    toast.hovered = false
    toast:SetAlpha(1)
end

function UI:PauseToast(toast)
    if not toast then return end
    toast.hovered = true
    toast.pausedRemaining = max(0.5, (toast.expiresAt or GetTime()) - GetTime())
    toast:SetAlpha(1)
end

function UI:ResumeToast(toast)
    if not toast then return end
    toast.hovered = false
    local role = string.upper(tostring(toast.notificationRole or "SLIDE"))
    toast.expiresAt = GetTime() + max(0.5, tonumber(toast.pausedRemaining) or self:GetNotificationDuration(toast.kind, role))
    toast.pausedRemaining = nil
end

function UI:AcquireToast(lane)
    lane = string.upper(tostring(lane or "PRIORITY"))
    local _, pool = self:GetCardLists(lane)
    local toast = tremove(pool)
    if toast then
        toast.cardLane = lane
        toast.notificationRole = lane == "SECONDARY" and "NORMAL" or "SLIDE"
        toast.notificationPromoted = false
        self:ApplyCardSettings(toast)
        return toast
    end

    toast = CreateFrame("Button", nil, UIParent, templateName())
    toast.cardLane = lane
    toast.notificationRole = lane == "SECONDARY" and "NORMAL" or "SLIDE"
    toast.notificationPromoted = false
    toast:SetClampedToScreen(false)
    toast:SetMovable(true)
    toast:EnableMouse(true)
    toast:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    toast:RegisterForDrag("RightButton")
    applyBackdrop(toast, COLORS.panel, COLORS.border)

    toast.accent = toast:CreateTexture(nil, "ARTWORK")
    toast.accent:SetPoint("TOPLEFT", toast, "TOPLEFT", 1, -1)
    toast.accent:SetPoint("TOPRIGHT", toast, "TOPRIGHT", -1, -1)
    toast.accent:SetHeight(3)
    toast.accent:SetColorTexture(COLORS.blue[1], COLORS.blue[2], COLORS.blue[3], 1)

    toast.playerPortrait = createCircularPortrait(toast, 34)
    toast.playerPortrait:SetPoint("LEFT", toast, "LEFT", 9, 0)
    toast.channelTag = toast.playerPortrait

    toast.title = createFont(toast, 12, COLORS.text, "LEFT")
    toast.timeText = createFont(toast, 9, COLORS.muted, "RIGHT")
    toast.preview = createFont(toast, 11, COLORS.muted, "LEFT")
    toast.preview:SetJustifyV("TOP")
    if toast.preview.SetWordWrap then toast.preview:SetWordWrap(true) end

    toast.reply = createButton(toast, "REPLY", 50, 18, function(selfButton)
        local owner = selfButton:GetParent()
        if owner.target then UI:BeginWhisper(owner.target) end
        UI:DismissToast(owner)
    end)

    toast.accept = createButton(toast, "ACCEPT", 58, 18, function(selfButton)
        local owner = selfButton:GetParent()
        if owner.partyAction then return end
        local inviter = owner.inviter
        local testInvite = owner.isTestInvite
        if testInvite then
            UI:DismissToast(owner, true)
            UI:ShowSystemToast("Party invite accepted", "Test invitation from " .. CC:ShortName(inviter or "Unknown"), "SUCCESS")
            return
        end

        owner.partyAction = "ACCEPTING"
        if owner.accept and owner.accept.Disable then owner.accept:Disable() end
        if owner.decline and owner.decline.Disable then owner.decline:Disable() end
        if owner.accept and owner.accept.label then owner.accept.label:SetText("JOINING") end
        if owner.preview then owner.preview:SetText("joining party...") end
        CC.state.pendingPartyInviter = inviter
        CC.state.partyInvitePending = true
        local ok, err
        if CC.AcceptPendingPartyInvite then ok, err = CC:AcceptPendingPartyInvite()
        else ok, err = false, "The party accept helper is unavailable." end
        if ok then
            UI:ShowSystemToast("Accepting party invite", "Joining " .. CC:ShortName(inviter or "the inviter") .. "'s party", "SUCCESS")
        else
            owner.partyAction = nil
            if owner.accept and owner.accept.Enable then owner.accept:Enable() end
            if owner.decline and owner.decline.Enable then owner.decline:Enable() end
            if owner.accept and owner.accept.label then owner.accept.label:SetText("ACCEPT") end
            if owner.preview then owner.preview:SetText("invite could not be accepted") end
            UI:ShowSystemToast("Party invite failed", tostring(err or "The client did not accept the invitation."), "ERROR")
        end
    end)

    toast.decline = createButton(toast, "DECLINE", 58, 18, function(selfButton)
        local owner = selfButton:GetParent()
        if owner.partyAction then return end
        local inviter = owner.inviter
        local testInvite = owner.isTestInvite
        if testInvite then
            UI:DismissToast(owner, true)
            UI:ShowSystemToast("Party invite declined", "Test invitation from " .. CC:ShortName(inviter or "Unknown"), "INFO")
            return
        end

        owner.partyAction = "DECLINING"
        if owner.accept and owner.accept.Disable then owner.accept:Disable() end
        if owner.decline and owner.decline.Disable then owner.decline:Disable() end
        if owner.decline and owner.decline.label then owner.decline.label:SetText("DECLINING") end
        local ok, err
        if CC.DeclinePendingPartyInvite then ok, err = CC:DeclinePendingPartyInvite()
        else ok, err = false, "The party decline helper is unavailable." end
        if ok then
            UI:DismissToast(owner, true)
            CC:FinalizeBlizzardPartyInvitePopups()
            CC.state.partyInvitePending = false
            CC.state.pendingPartyInviter = nil
            CC.state.partyInviteAction = nil
            CC.state.partyInviteAcceptedAt = nil
            UI:ShowSystemToast("Party invite declined", "Invitation from " .. CC:ShortName(inviter or "Unknown"), "INFO")
            if UI.RefreshLauncherNotification then UI:RefreshLauncherNotification() end
        else
            owner.partyAction = nil
            if owner.accept and owner.accept.Enable then owner.accept:Enable() end
            if owner.decline and owner.decline.Enable then owner.decline:Enable() end
            if owner.decline and owner.decline.label then owner.decline.label:SetText("DECLINE") end
            UI:ShowSystemToast("Party decline failed", tostring(err or "The client did not decline the invitation."), "ERROR")
        end
    end)

    local function holdToast(button)
        if not button or not button.HookScript then return end
        button:HookScript("OnEnter", function(selfButton) UI:PauseToast(selfButton:GetParent()) end)
        button:HookScript("OnLeave", function(selfButton) UI:ResumeToast(selfButton:GetParent()) end)
    end
    holdToast(toast.reply); holdToast(toast.accept); holdToast(toast.decline)

    toast:SetScript("OnDragStart", function(selfToast, buttonName)
        if buttonName ~= "RightButton" or (CC.db.ui or {}).cardLocked == true then return end
        selfToast.dragging = true
        UI:PauseToast(selfToast)
        selfToast:SetScript("OnUpdate", nil)
        selfToast:StartMoving()
    end)
    toast:SetScript("OnDragStop", function(selfToast)
        if not selfToast.dragging then return end
        selfToast:StopMovingOrSizing()
        UI:SaveCardStackFromDrag(selfToast)
        selfToast.dragging = false
        UI:ResumeToast(selfToast)
        selfToast.currentX, selfToast.currentY = selfToast:GetLeft(), selfToast:GetBottom()
        UI:RepositionToasts()
        UI:StartToast(selfToast, true)
        if UI.fullSettings and UI.fullSettings.Refresh then UI.fullSettings:Refresh() end
    end)
    toast:SetScript("OnEnter", function(selfToast)
        UI:PauseToast(selfToast)
        setBackground(selfToast, COLORS.panelRaised)
        GameTooltip:SetOwner(selfToast, "ANCHOR_RIGHT")
        GameTooltip:AddLine((selfToast.notificationRole == "NORMAL" or selfToast.notificationPromoted) and "CreshChat main notification" or "CreshChat slide-out notification", 0.25, 0.7, 1)
        GameTooltip:AddLine("Right-drag to move the full notification hub", 0.75, 0.8, 0.9)
        GameTooltip:Show()
    end)
    toast:SetScript("OnLeave", function(selfToast)
        UI:ResumeToast(selfToast)
        setBackground(selfToast, (selfToast.notificationRole == "NORMAL" or selfToast.notificationPromoted) and COLORS.panel or COLORS.panelSoft)
        GameTooltip:Hide()
    end)
    toast:SetScript("OnClick", function(selfToast, buttonName)
        if buttonName == "RightButton" then return end
        if selfToast.kind == "WHISPER" and selfToast.target then
            UI:BeginWhisper(selfToast.target); UI:DismissToast(selfToast)
        elseif selfToast.kind == "GUILD" then
            UI:OpenChannel("GUILD"); UI:DismissToast(selfToast)
        elseif selfToast.kind == "BATTLEPASS" then
            UI:OpenGameDrawer("BATTLEPASS"); UI:DismissToast(selfToast)
        elseif selfToast.kind == "DUNGEONPASS" then
            if CC.SoloGames and CC.SoloGames.OpenDungeonDwellers then CC.SoloGames:OpenDungeonDwellers("PASS") end
            UI:DismissToast(selfToast)
        elseif selfToast.kind ~= "PARTY" then
            UI:DismissToast(selfToast)
        end
    end)
    self:ApplyCardSettings(toast)
    return toast
end

function UI:StartToast(toast, resumeOnly)
    if not toast then return end
    local _, _, baseScale = self:GetToastDimensions(toast)
    toast.slidingOut = false
    toast.popProgress = resumeOnly and 1 or 0
    local targetX = toast.targetX or 18
    local targetY = toast.targetY or 150
    local hubX = self.notificationBaseX or targetX
    local hubY = self.notificationBaseY or targetY
    local isSlide = toast.notificationRole == "SLIDE" and toast.notificationPromoted ~= true
    local style = self:NormaliseAnimationStyle((CC.db.ui or {}).toastAnimation or "FAN_UP")

    if not resumeOnly then
        local startX, startY, startScale = targetX, targetY, baseScale
        if style == "NONE" then
            toast.currentX, toast.currentY = targetX, targetY
            toast:SetScale(baseScale); toast:SetAlpha(1)
        elseif style == "FADE" then
            toast.currentX, toast.currentY = targetX, targetY
            toast:SetScale(baseScale); toast:SetAlpha(0)
        elseif style == "POP" then
            toast.currentX, toast.currentY = targetX, targetY
            toast:SetScale(baseScale * 0.78); toast:SetAlpha(0)
        elseif style == "ZOOM" then
            toast.currentX, toast.currentY = targetX, targetY
            toast:SetScale(baseScale * 0.55); toast:SetAlpha(0)
        elseif style == "SLIDE_LEFT" then startX = targetX - 90; toast.currentX, toast.currentY = startX, targetY; toast:SetScale(baseScale * 0.96); toast:SetAlpha(0)
        elseif style == "SLIDE_RIGHT" then startX = targetX + 90; toast.currentX, toast.currentY = startX, targetY; toast:SetScale(baseScale * 0.96); toast:SetAlpha(0)
        elseif style == "SLIDE_UP" then startY = targetY - 70; toast.currentX, toast.currentY = targetX, startY; toast:SetScale(baseScale * 0.96); toast:SetAlpha(0)
        elseif style == "SLIDE_DOWN" then startY = targetY + 70; toast.currentX, toast.currentY = targetX, startY; toast:SetScale(baseScale * 0.96); toast:SetAlpha(0)
        elseif style == "FAN_DOWN" then
            toast.currentX, toast.currentY = hubX + (isSlide and 18 or 0), hubY + (isSlide and 34 or 18)
            toast:SetScale(baseScale * 0.90); toast:SetAlpha(0)
        elseif style == "SWOOP" then
            toast.currentX, toast.currentY = hubX - 70, hubY - 42
            toast:SetScale(baseScale * 0.72); toast:SetAlpha(0)
        elseif style == "BOUNCE" then
            toast.currentX, toast.currentY = targetX, targetY - 26
            toast:SetScale(baseScale * 0.88); toast:SetAlpha(0)
        else
            toast.currentX, toast.currentY = hubX + (isSlide and -18 or 0), hubY - (isSlide and 34 or 18)
            toast:SetScale(baseScale * 0.90); toast:SetAlpha(0)
        end
    else
        toast.currentX = toast.currentX or targetX
        toast.currentY = toast.currentY or targetY
        toast:SetAlpha(1)
    end
    self:SetToastPosition(toast)

    local elapsedTotal = resumeOnly and self:GetAnimationDuration() or (style == "NONE" and self:GetAnimationDuration() or 0)
    toast:SetScript("OnUpdate", function(selfToast, elapsed)
        if selfToast.dragging then return end
        elapsed = min(0.05, elapsed or 0)
        local desiredX = selfToast.targetX or targetX
        local desiredY = selfToast.targetY or targetY
        local desiredScale = selfToast.creshBaseScale or baseScale

        if selfToast.slidingOut then
            local direction = UI:GetNotificationSlideDirection()
            if direction == "LEFT" then selfToast.currentX = (selfToast.currentX or desiredX) - (720 * elapsed)
            elseif direction == "RIGHT" then selfToast.currentX = (selfToast.currentX or desiredX) + (720 * elapsed)
            elseif direction == "TOP" then selfToast.currentY = (selfToast.currentY or desiredY) + (520 * elapsed)
            else selfToast.currentY = (selfToast.currentY or desiredY) - (520 * elapsed) end
            selfToast:SetAlpha(max(0, selfToast:GetAlpha() - elapsed * 5.2))
            selfToast:SetScale(max(desiredScale * 0.90, selfToast:GetScale() - (elapsed * 0.25)))
            UI:SetToastPosition(selfToast)
            if selfToast:GetAlpha() <= 0.03 then UI:RecycleToast(selfToast) end
            return
        end

        elapsedTotal = elapsedTotal + elapsed
        local duration = UI:GetAnimationDuration()
        local progress = min(1, elapsedTotal / duration)
        local eased = 1 - ((1 - progress) * (1 - progress))
        local response = min(1, elapsed * 15)
        selfToast.currentX = (selfToast.currentX or desiredX) + ((desiredX - (selfToast.currentX or desiredX)) * response)
        selfToast.currentY = (selfToast.currentY or desiredY) + ((desiredY - (selfToast.currentY or desiredY)) * response)
        if style == "BOUNCE" and progress < 1 then
            selfToast.currentY = selfToast.currentY + (sin(progress * 3.14159 * 2.5) * (1 - progress) * 5)
        end
        local scaleNow = selfToast:GetScale() or desiredScale
        selfToast:SetScale(scaleNow + ((desiredScale - scaleNow) * response))
        selfToast:SetAlpha(max(selfToast:GetAlpha(), eased))
        UI:SetToastPosition(selfToast)

        if not selfToast.hovered then
            if selfToast.kind == "PARTY" and not selfToast.isTestInvite and CC.state.partyInvitePending then
                selfToast.expiresAt = GetTime() + 30
                selfToast:SetAlpha(1)
                return
            end
            local remaining = (selfToast.expiresAt or 0) - GetTime()
            if remaining <= 0 then UI:DismissToast(selfToast)
            elseif remaining < 0.55 then selfToast:SetAlpha(max(0.35, remaining / 0.55))
            elseif progress >= 1 then selfToast:SetAlpha(1) end
        end
    end)
end

function UI:FindToast(kind, target)
    for _, list in ipairs({ self.toasts or {}, self.secondaryToasts or {} }) do
        for _, toast in ipairs(list) do
            if toast:IsShown() and not toast.slidingOut and toast.kind == kind then
                if kind ~= "WHISPER" or CC:ResolveWhisperConversation(toast.target) == CC:ResolveWhisperConversation(target) then return toast end
            end
        end
    end
end

function UI:FindSecondaryToast(key)
    for _, list in ipairs({ self.secondaryToasts or {}, self.toasts or {} }) do
        for _, toast in ipairs(list) do
            if toast:IsShown() and not toast.slidingOut and toast.secondaryKey == key then return toast end
        end
    end
end

local function notificationAccent(status)
    status = string.upper(tostring(status or "INFO"))
    if status == "SUCCESS" or status == "ONLINE" then return { 0.28, 0.85, 0.48, 1 }, status == "ONLINE" and "+" or "+" end
    if status == "OFFLINE" then return { 0.42, 0.46, 0.54, 1 }, "-" end
    if status == "WARNING" then return { 1.00, 0.68, 0.20, 1 }, "!" end
    if status == "ERROR" then return { 1.00, 0.32, 0.30, 1 }, "!" end
    if status == "BATTLEPASS" then return COLORS.quest or { 0.95, 0.76, 0.22, 1 }, "BP" end
    if status == "DUNGEONPASS" then return COLORS.green or { 0.30, 0.88, 0.52, 1 }, "DD" end
    return COLORS.blue, "i"
end

function UI:ConfigureToastIdentity(toast, title, message, status, playerName)
    local accent, symbol = notificationAccent(status)
    setBackground(toast, toast.notificationRole == "NORMAL" and COLORS.panel or COLORS.panelSoft)
    toast.title:SetText(tostring(title or "Notification"))
    toast.preview:SetText(truncate(tostring(message or ""), toast.notificationRole == "NORMAL" and 100 or 82))
    toast.timeText:SetText(date("%H:%M", time()))
    if toast.accent then toast.accent:SetColorTexture(accent[1], accent[2], accent[3], accent[4] or 1) end
    if playerName and playerName ~= "" then
        UI:UpdatePlayerPortrait(toast.playerPortrait, playerName, nil, nil)
    else
        toast.playerPortrait:Show()
        toast.playerPortrait.texture:Hide()
        if toast.playerPortrait.model then toast.playerPortrait.model:Hide() end
        toast.playerPortrait.badge:Hide(); toast.playerPortrait.badgeText:Hide()
        toast.playerPortrait.initial:SetText(symbol); toast.playerPortrait.initial:Show()
        toast.playerPortrait.ring:SetVertexColor(accent[1], accent[2], accent[3], 1)
    end
end

function UI:MakeRoomForSlideToast()
    self.toasts = self.toasts or {}
    local limit = self:GetCardLimit("SLIDE")
    while #self.toasts >= limit do
        local removable
        for _, candidate in ipairs(self.toasts) do
            local protectedInvite = candidate.kind == "PARTY" and not candidate.isTestInvite and CC.state.partyInvitePending
            if not protectedInvite then removable = candidate break end
        end
        if not removable then return false end
        self:DismissToast(removable, true)
    end
    return true
end

function UI:ShowToast(channel, target, message)
    local notificationKind = self:GetMessageNotificationKind(channel, message)
    if CC.IsNotificationEnabled and not CC:IsNotificationEnabled(notificationKind) then return end
    local role = self:GetNotificationRole(notificationKind, "SLIDE")
    local coalesce = (CC.db.ui or {}).cardCoalesce ~= false
    local toast = (coalesce and channel == "WHISPER") and self:FindToast("WHISPER", target) or nil
    if not toast then
        toast = self:AcquireToast(role == "NORMAL" and "SECONDARY" or "PRIORITY")
        toast.messageCount = 0
    end
    toast.kind = notificationKind
    self:AddToastToRole(toast, role)
    toast.notificationPromoted = false
    toast.channel, toast.target = channel, target
    toast.hovered, toast.isTestInvite, toast.slidingOut = false, nil, false
    toast.messageCount = (toast.messageCount or 0) + 1
    toast.reply:Hide(); toast.accept:Hide(); toast.decline:Hide()
    local colorKey = channel == "GENERAL" and (notificationKind == "PARTY_MESSAGE" and "PARTY" or "GENERAL") or channel
    local cardAccent = (CC.db.colors and CC.db.colors.channels and CC.db.colors.channels[colorKey]) or COLORS.blue
    if toast.accent then toast.accent:SetColorTexture(cardAccent[1], cardAccent[2], cardAccent[3], cardAccent[4] or 1) end
    local timestamp = message and message.timestamp or time()
    toast.timeText:SetText(date("%H:%M", timestamp))
    local sender = message and message.sender or "Unknown"
    local preview = truncate(message and message.text or "", role == "NORMAL" and 100 or 82)
    if channel == "WHISPER" then
        local suffix = toast.messageCount > 1 and (" - " .. toast.messageCount) or ""
        toast.title:SetText((CC.GetWhisperDisplayName and CC:GetWhisperDisplayName(target) or CC:ShortName(target)) .. suffix)
        toast.preview:SetText(preview)
        UI:UpdatePlayerPortrait(toast.playerPortrait, target, message and message.guid, message)
        toast.reply:Show()
    elseif channel == "GUILD" then
        toast.title:SetText("Guild - " .. CC:ShortName(sender))
        toast.preview:SetText(preview)
        UI:UpdatePlayerPortrait(toast.playerPortrait, sender, message and message.guid, message)
    elseif channel == "QUEST" then
        toast.title:SetText("Quest - " .. CC:ShortName(sender))
        toast.preview:SetText(preview)
        UI:UpdatePlayerPortrait(toast.playerPortrait, sender, message and message.guid, message)
    elseif notificationKind == "PARTY_MESSAGE" then
        toast.title:SetText("Group - " .. CC:ShortName(sender))
        toast.preview:SetText(preview)
        UI:UpdatePlayerPortrait(toast.playerPortrait, sender, message and message.guid, message)
    else
        toast.title:SetText("Mention - " .. CC:ShortName(sender))
        toast.preview:SetText(preview)
        UI:UpdatePlayerPortrait(toast.playerPortrait, sender, message and message.guid, message)
    end
    toast.expiresAt = GetTime() + self:GetNotificationDuration(notificationKind, role)
    self:RepositionToasts()
    if not toast:IsShown() then self:StartToast(toast); toast:Show() else self:StartToast(toast, true) end
end

function UI:ShowSecondaryToast(title, message, status, key, playerName, kind)
    kind = string.upper(tostring(kind or "SYSTEM"))
    if CC.IsNotificationEnabled and not CC:IsNotificationEnabled(kind) then return end
    key = tostring(key or (tostring(title) .. ":" .. tostring(message)))
    local role = self:GetNotificationRole(kind, "NORMAL")
    local toast = self:FindSecondaryToast(key)
    if not toast then toast = self:AcquireToast(role == "NORMAL" and "SECONDARY" or "PRIORITY") end
    toast.kind = kind
    self:AddToastToRole(toast, role)
    toast.notificationPromoted = false
    toast.channel, toast.target, toast.inviter = kind, nil, nil
    toast.secondaryKey = key
    toast.hovered, toast.isTestInvite, toast.slidingOut = false, nil, false
    toast.reply:Hide(); toast.accept:Hide(); toast.decline:Hide()
    self:ConfigureToastIdentity(toast, title, message, status, playerName)
    toast.expiresAt = GetTime() + self:GetNotificationDuration(kind, role)
    self:RepositionToasts()
    if not toast:IsShown() then self:StartToast(toast); toast:Show() else self:StartToast(toast, true) end
end

function UI:ShowSlideToast(title, message, status, key, playerName, kind, target)
    kind = string.upper(tostring(kind or "SYSTEM"))
    if CC.IsNotificationEnabled and not CC:IsNotificationEnabled(kind) then return end
    key = tostring(key or (tostring(kind) .. ":" .. tostring(title) .. ":" .. tostring(message)))
    local role = self:GetNotificationRole(kind, "SLIDE")
    local toast = self:FindSecondaryToast(key)
    if not toast then toast = self:AcquireToast(role == "NORMAL" and "SECONDARY" or "PRIORITY") end
    toast.kind = kind
    self:AddToastToRole(toast, role)
    toast.notificationPromoted = false
    toast.channel = kind
    toast.target = target
    toast.secondaryKey = key
    toast.hovered, toast.isTestInvite, toast.slidingOut = false, nil, false
    toast.reply:Hide(); toast.accept:Hide(); toast.decline:Hide()
    self:ConfigureToastIdentity(toast, title, message, status, playerName)
    toast.expiresAt = GetTime() + self:GetNotificationDuration(kind, role)
    self:RepositionToasts()
    if not toast:IsShown() then self:StartToast(toast); toast:Show() else self:StartToast(toast, true) end
end

function UI:ShowSystemToast(title, message, status)
    if CC.PlayAlertSound then CC:PlayAlertSound("SYSTEM") end
    if CC.IsNotificationEnabled and not CC:IsNotificationEnabled("SYSTEM") then return end
    self:ShowSecondaryToast(title, message, status, "SYSTEM:" .. tostring(title) .. ":" .. tostring(message), nil, "SYSTEM")
end

function UI:ShowPresenceToast(name, online)
    name = CC:CleanPlayerName(name or "Friend")
    local now = GetTime()
    self.presenceDedupe = self.presenceDedupe or {}
    local dedupeKey = string.lower(name) .. ":" .. tostring(online and true or false)
    if self.presenceDedupe[dedupeKey] and now - self.presenceDedupe[dedupeKey] < 2.5 then return end
    self.presenceDedupe[dedupeKey] = now
    if CC.PlayAlertSound then CC:PlayAlertSound("FRIEND") end
    if CC.IsNotificationEnabled and not CC:IsNotificationEnabled("FRIEND") then return end
    self:ShowSlideToast(online and "Friend online" or "Friend offline", CC:ShortName(name), online and "ONLINE" or "OFFLINE", "PRESENCE:" .. dedupeKey, name, "FRIEND", name)
end

function UI:ShowBattlePassToast(title, message, status, key)
    if CC.PlayAlertSound then CC:PlayAlertSound("GAME") end
    if CC.IsNotificationEnabled and not CC:IsNotificationEnabled("GAME") then return end
    self:ShowSlideToast(title or "Battle Pass", message or "New progress is ready.", status or "BATTLEPASS", key or ("BATTLEPASS:" .. tostring(title) .. ":" .. tostring(message)), nil, "BATTLEPASS", nil)
end

function UI:ShowDungeonPassToast(title, message, key)
    if CC.PlayAlertSound then CC:PlayAlertSound("GAME") end
    if CC.IsNotificationEnabled and not CC:IsNotificationEnabled("GAME") then return end
    self:ShowSlideToast(title or "Dungeon Dwellers Pass", message or "New delver progress is ready.", "DUNGEONPASS", key or ("DUNGEONPASS:" .. tostring(title) .. ":" .. tostring(message)), nil, "DUNGEONPASS", nil)
end

function UI:ShowGameToast(title, message, status, key)
    if CC.PlayAlertSound then CC:PlayAlertSound("GAME") end
    if CC.IsNotificationEnabled and not CC:IsNotificationEnabled("GAME") then return end
    self:ShowSlideToast(title or "Game notification", message or "New game progress is ready.", status or "GAME", key or ("GAME:" .. tostring(title) .. ":" .. tostring(message)), nil, "GAME", nil)
end

function UI:ShowPartyInvite(inviter, isTest)
    if not isTest and CC.IsNotificationEnabled and not CC:IsNotificationEnabled("PARTY_INVITE") then return end
    local role = self:GetNotificationRole("PARTY_INVITE", "NORMAL")
    local toast = self:AcquireToast(role == "NORMAL" and "SECONDARY" or "PRIORITY")
    local shortName = CC:ShortName(inviter or "Unknown")
    toast.kind = "PARTY"
    self:AddToastToRole(toast, role)
    toast.notificationPromoted = false
    toast.channel, toast.inviter, toast.target = "PARTY", inviter, nil
    toast.notificationPriority = CC.GetNotificationPriority and CC:GetNotificationPriority("PARTY_INVITE") or "CRITICAL"
    toast.hovered, toast.isTestInvite, toast.slidingOut = false, isTest and true or false, false
    toast.partyAction = nil
    if toast.accept and toast.accept.label then toast.accept.label:SetText("ACCEPT") end
    if toast.decline and toast.decline.label then toast.decline.label:SetText("DECLINE") end
    if toast.accept and toast.accept.Enable then toast.accept:Enable() end
    if toast.decline and toast.decline.Enable then toast.decline:Enable() end
    local partyAccent = (CC.db.colors and CC.db.colors.channels and CC.db.colors.channels.PARTY) or COLORS.blue
    if toast.accent then toast.accent:SetColorTexture(partyAccent[1], partyAccent[2], partyAccent[3], partyAccent[4] or 1) end
    setBackground(toast, role == "NORMAL" and COLORS.panel or COLORS.panelSoft)
    UI:UpdatePlayerPortrait(toast.playerPortrait, inviter, nil, nil)
    toast.title:SetText(shortName)
    toast.timeText:SetText(date("%H:%M", time()))
    toast.preview:SetText("invited you to join a party")
    toast.reply:Hide(); toast.accept:Show(); toast.decline:Show()
    toast.expiresAt = GetTime() + (isTest and self:GetNotificationDuration("PARTY_INVITE", role) or 30)
    self:RepositionToasts(); self:StartToast(toast); toast:Show()
end

function UI:CancelPartyInviteToasts()
    for _, list in ipairs({ self.toasts or {}, self.secondaryToasts or {} }) do
        for index = #list, 1, -1 do
            local toast = list[index]
            if toast.kind == "PARTY" and not toast.isTestInvite then self:DismissToast(toast) end
        end
    end
end

function UI:CreatePopout(channel, target)
    if channel ~= "GUILD" and not self:IsGeneralFeedMode(channel) and channel ~= "COMBAT" and channel ~= "QUEST" then channel = "WHISPER" end
    if channel == "WHISPER" then target = CC:EnsureWhisperConversation(target) end
    if channel == "WHISPER" and (not target or target == "") then
        CC:Print("Open a whisper conversation before popping it out.")
        return
    end
    if channel == "QUEST" and (not target or target == "" or not (CC.db.history.quests or {})[target]) then
        CC:Print("Open a quest-giver conversation before popping it out.")
        return
    end

    local id
    if channel == "WHISPER" then id = "WHISPER:" .. target
    elseif channel == "QUEST" then id = "QUEST:" .. target
    else id = channel end
    local existing = self.popouts[id]
    if existing then
        if existing:IsShown() then
            existing:Hide()
        else
            self:ShowAnimated(existing)
            self:SetActivePopout(existing)
            self:RefreshPopouts()
            self:SchedulePopoutFade(existing)
        end
        return
    end

    local popout = CreateFrame("Frame", nil, UIParent, templateName())
    local popoutWidth = max(300, min(620, tonumber((CC.db.ui or {}).popoutWidth) or 400))
    popout:SetSize(popoutWidth, 238)
    popout:SetFrameStrata("HIGH")
    popout:SetClampedToScreen(true)
    popout:SetMovable(true)
    popout:EnableMouse(true)
    popout.creshClassicChrome = true
    popout.channel = channel
    popout.target = target
    self:InstallWindowFocus(popout)
    applyBackdrop(popout, COLORS.panel, COLORS.border)
    popout.accent = popout:CreateTexture(nil, "ARTWORK")
    popout.accent:SetPoint("TOPLEFT", popout, "TOPLEFT", 1, -1)
    popout.accent:SetPoint("BOTTOMLEFT", popout, "BOTTOMLEFT", 1, 1)
    popout.accent:SetWidth(3)
    popout.accent:SetColorTexture(COLORS.blue[1], COLORS.blue[2], COLORS.blue[3], 1)
    popout:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    self.popoutCount = (self.popoutCount or 0) + 1
    popout.creshOrder = self.popoutCount

    popout.header = CreateFrame("Frame", nil, popout)
    popout.header:SetPoint("TOPLEFT", popout, "TOPLEFT", 1, -1)
    popout.header:SetPoint("TOPRIGHT", popout, "TOPRIGHT", -1, -1)
    popout.header:SetHeight(28)
    popout.header.background = popout.header:CreateTexture(nil, "BACKGROUND")
    popout.header.background:SetAllPoints()
    popout.header.background:SetColorTexture(COLORS.panelRaised[1], COLORS.panelRaised[2], COLORS.panelRaised[3], COLORS.panelRaised[4] or 1)
    popout.header.divider = popout.header:CreateTexture(nil, "BORDER")
    popout.header.divider:SetPoint("BOTTOMLEFT", popout.header, "BOTTOMLEFT", 3, 0)
    popout.header.divider:SetPoint("BOTTOMRIGHT", popout.header, "BOTTOMRIGHT", -3, 0)
    popout.header.divider:SetHeight(1)
    popout.header.divider:SetColorTexture(COLORS.border[1], COLORS.border[2], COLORS.border[3], 0.70)
    popout.header:EnableMouse(true)
    popout.header:RegisterForDrag("LeftButton")
    popout.header:SetScript("OnDragStart", function()
        UI:SetActivePopout(popout)
        popout.creshUserPositioned = true
        popout:StartMoving()
    end)
    popout.header:SetScript("OnDragStop", function()
        popout:StopMovingOrSizing()
        popout.creshUserPositioned = true
        savePosition(popout, "popout_" .. id)
        UI:SchedulePopoutFade(popout)
    end)

    popout.title = createFont(popout.header, 11, COLORS.text, "LEFT")
    popout.title:SetPoint("LEFT", popout.header, "LEFT", 9, 0)
    if channel == "WHISPER" then
        popout.portrait = createCircularPortrait(popout.header, 20)
        popout.portrait:SetPoint("LEFT", popout.header, "LEFT", 7, 0)
        local portraitMessage = UI:GetWhisperPortraitMessage(target)
        UI:UpdatePlayerPortrait(popout.portrait, target, portraitMessage.guid, portraitMessage)
        popout.title:ClearAllPoints()
        popout.title:SetPoint("LEFT", popout.portrait, "RIGHT", 6, 0)
    end
    if channel == "GUILD" and (CC.db.ui or {}).guildTheme ~= false then
        popout.guildCrest = createGuildCrest(popout.header, 20)
        popout.guildCrest:SetPoint("LEFT", popout.header, "LEFT", 7, 0)
        self:RefreshGuildCrest(popout.guildCrest)
        popout.title:ClearAllPoints(); popout.title:SetPoint("LEFT", popout.guildCrest, "RIGHT", 6, 0)
        local guildColor = GUILD_THEME.accent
        popout.accent:SetColorTexture(guildColor[1], guildColor[2], guildColor[3], 1)
        applyBackdrop(popout, GUILD_THEME.panel, GUILD_THEME.border)
        popout.header.background:SetColorTexture(GUILD_THEME.panelRaised[1], GUILD_THEME.panelRaised[2], GUILD_THEME.panelRaised[3], 1)
    end
    local questMeta = channel == "QUEST" and CC:GetQuestConversationMeta(target) or nil
    local titles = { GUILD = self:GetGuildDisplayName(), COMBAT = "Combat", QUEST = questMeta and questMeta.npcName or "Quests" }
    local feedDefinition = CONSOLE_TAB_LOOKUP[channel]
    popout.title:SetText(titles[channel] or (feedDefinition and feedDefinition.title) or (CC.GetWhisperDisplayName and CC:GetWhisperDisplayName(target) or CC:ShortName(target)))
    if self:IsGeneralFeedMode(channel) then
        local accent = (CC.db.colors and CC.db.colors.channels and CC.db.colors.channels[channel]) or COLORS.blue
        popout.accent:SetColorTexture(accent[1], accent[2], accent[3], 1)
    end
    if channel == "QUEST" then
        popout.accent:SetColorTexture(COLORS.quest[1], COLORS.quest[2], COLORS.quest[3], 1)
    end

    popout.close = createButton(popout.header, "X", 22, 20, function()
        if popout.channel == "WHISPER" then UI:CloseWhisper(popout.target) else popout:Hide() end
    end)
    popout.close:SetPoint("RIGHT", popout.header, "RIGHT", -4, 0)
    if channel == "WHISPER" then
        popout.addFriend = createButton(popout.header, "+", 22, 20, function() UI:AddWhisperFriend(popout.target) end)
        popout.addFriend:SetPoint("RIGHT", popout.close, "LEFT", -3, 0)
        popout.gameChallenge = createButton(popout.header, "GAME", 38, 20, function()
            if CC.Games and CC.Games.OpenHub then CC.Games:OpenHub(popout.target) end
        end)
        popout.gameChallenge:SetPoint("RIGHT", popout.addFriend, "LEFT", -3, 0)
        if CC.IsBattleNetConversation and CC:IsBattleNetConversation(target) then
            popout.addFriend:Hide()
            popout.gameChallenge:Hide()
            popout.title:SetPoint("RIGHT", popout.close, "LEFT", -6, 0)
        else
            popout.title:SetPoint("RIGHT", popout.gameChallenge, "LEFT", -6, 0)
        end
    else
        popout.title:SetPoint("RIGHT", popout.close, "LEFT", -6, 0)
    end

    if channel == "COMBAT" then
        popout.messageView = self:CreateCombatView(popout)
        popout.messageView.scroll:SetPoint("TOPLEFT", popout, "TOPLEFT", 6, -34)
        popout.messageView.scroll:SetPoint("BOTTOMRIGHT", popout, "BOTTOMRIGHT", -6, 6)
        popout.messageView.fallbackWidth = popoutWidth - 8
    else
        popout.compactView = self:CreateCompactPopoutView(popout)
        popout.normalView = self:CreateMessageView(popout)
        popout.normalView.fallbackWidth = popoutWidth - 8
        popout.messageView = self:GetPopoutStyle() == "COMPACT" and popout.compactView or popout.normalView
        popout.compactView.scroll:SetShown(self:GetPopoutStyle() == "COMPACT")
        popout.normalView.scroll:SetShown(self:GetPopoutStyle() == "NORMAL")

        popout.commandBar = CreateFrame("Frame", nil, popout, templateName())
        popout.commandBar:SetPoint("BOTTOMLEFT", popout, "BOTTOMLEFT", 4, 4)
        popout.commandBar:SetPoint("BOTTOMRIGHT", popout, "BOTTOMRIGHT", -4, 4)
        popout.commandBar:SetHeight(32)
        applyBackdrop(popout.commandBar, COLORS.panel, COLORS.border)
        popout.commandBar.label = createFont(popout.commandBar, 9, COLORS.muted, "LEFT")
        popout.commandBar.label:SetPoint("LEFT", popout.commandBar, "LEFT", 8, 0)
        popout.commandBar.label:SetWidth(72)
        popout.commandBar.label:SetText(channel == "WHISPER" and ("TO " .. string.upper(truncate(CC.GetWhisperDisplayName and CC:GetWhisperDisplayName(target) or CC:ShortName(target), 12))) or channel)
        popout.commandBar.edit = CreateFrame("EditBox", nil, popout.commandBar, templateName())
        popout.commandBar.edit:SetAutoFocus(false)
        popout.commandBar.edit:SetFont(STANDARD_TEXT_FONT, 11, "")
        popout.commandBar.edit:SetTextColor(COLORS.text[1], COLORS.text[2], COLORS.text[3], 1)
        popout.commandBar.edit:SetTextInsets(8, 8, 0, 0)
        popout.commandBar.edit:SetMaxLetters(255)
        popout.commandBar.edit:SetPoint("TOPLEFT", popout.commandBar.label, "TOPRIGHT", 4, -3)
        popout.commandBar.edit:SetPoint("BOTTOMRIGHT", popout.commandBar, "BOTTOMRIGHT", -4, 3)
        applyBackdrop(popout.commandBar.edit, COLORS.panelRaised, COLORS.panelRaised)
        popout.commandBar.placeholder = createFont(popout.commandBar.edit, 10, COLORS.muted, "LEFT")
        popout.commandBar.placeholder:SetPoint("LEFT", popout.commandBar.edit, "LEFT", 8, 0)
        popout.commandBar.placeholder:SetText("Message or /command...")
        if channel == "GUILD" and (CC.db.ui or {}).guildTheme ~= false then
            applyBackdrop(popout.commandBar, GUILD_THEME.panelSoft, GUILD_THEME.border)
            applyBackdrop(popout.commandBar.edit, GUILD_THEME.panelRaised, GUILD_THEME.border)
            if popout.commandBar.label.SetTextColor then popout.commandBar.label:SetTextColor(GUILD_THEME.muted[1], GUILD_THEME.muted[2], GUILD_THEME.muted[3], 1) end
            if popout.commandBar.placeholder.SetTextColor then popout.commandBar.placeholder:SetTextColor(GUILD_THEME.muted[1], GUILD_THEME.muted[2], GUILD_THEME.muted[3], 1) end
        end
        popout.commandBar.edit:SetScript("OnTextChanged", function(edit)
            popout.commandBar.placeholder:SetShown((edit:GetText() or "") == "")
            UI:SetActivePopout(popout)
        end)
        popout.commandBar.edit:SetScript("OnEditFocusGained", function() UI:SetActivePopout(popout) end)
        popout.commandBar.edit:SetScript("OnEditFocusLost", function() UI:SchedulePopoutFade(popout) end)
        popout.commandBar.edit:SetScript("OnEnterPressed", function(edit)
            local text = edit:GetText() or ""
            UI:SetActivePopout(popout)
            local sent
            if string.sub(text, 1, 1) == "/" then sent = UI:ExecuteNativeSlashCommand(text)
            else sent = CC:SendMessage(popout.channel, popout.target, text) end
            if sent then edit:SetText("") end
            edit:SetFocus()
        end)
        popout.commandBar.edit:SetScript("OnEscapePressed", function(edit) edit:ClearFocus(); UI:SchedulePopoutFade(popout) end)
        if popout.commandBar.edit.SetAltArrowKeyMode then popout.commandBar.edit:SetAltArrowKeyMode(false) end
        popout.commandBar.edit:SetScript("OnArrowPressed", function(edit, key)
            local text = edit:GetText() or ""
            if text ~= "" and string.sub(text, 1, 1) ~= "/" and not popout.commandHistoryIndex then return end
            local history = CC:GetCommandHistory()
            if #history == 0 then return end
            if key == "UP" then
                popout.commandHistoryIndex = popout.commandHistoryIndex or (#history + 1)
                popout.commandHistoryIndex = max(1, popout.commandHistoryIndex - 1)
                edit:SetText(history[popout.commandHistoryIndex] or "")
            elseif key == "DOWN" and popout.commandHistoryIndex then
                popout.commandHistoryIndex = min(#history + 1, popout.commandHistoryIndex + 1)
                edit:SetText(popout.commandHistoryIndex <= #history and history[popout.commandHistoryIndex] or "")
            end
            edit:SetCursorPosition(string.len(edit:GetText() or ""))
        end)
    end

    installPopoutWidthGrips(popout)
    local savedPopoutPosition = CC.db and CC.db.positions and CC.db.positions["popout_" .. id]
    applyPosition(popout, "popout_" .. id)
    if savedPopoutPosition then
        popout.creshUserPositioned = true
        popout.creshInitialPlaced = true
    end
    if channel ~= "COMBAT" then self:ApplyPopoutStyle(popout) else self:ApplyPopoutLayout(popout) end

    popout:SetScript("OnMouseDown", function() UI:SetActivePopout(popout) end)
    popout:SetScript("OnEnter", function() UI:SetActivePopout(popout) end)
    popout:SetScript("OnLeave", function() UI:SchedulePopoutFade(popout) end)
    popout:SetScript("OnShow", function()
        UI:SetActivePopout(popout)
        if channel == "GUILD" then CC.state.unreadGuild = 0
        elseif UI:IsGeneralFeedMode(channel) then CC.state.unreadGeneral = 0
        elseif channel == "QUEST" then
            UI.unreadQuestByTarget[target] = 0
            CC.state.unreadQuests = 0
            for _, count in pairs(UI.unreadQuestByTarget) do CC.state.unreadQuests = CC.state.unreadQuests + (count or 0) end
        elseif channel == "WHISPER" then
            UI.unreadByTarget[target] = 0
            CC.state.unreadWhispers = 0
            for _, count in pairs(UI.unreadByTarget) do CC.state.unreadWhispers = CC.state.unreadWhispers + (count or 0) end
        end
        UI:RefreshAll(); UI:SchedulePopoutFade(popout)
    end)
    popout:SetScript("OnHide", function()
        if UI.activePopout == popout then UI.activePopout = nil; UI:GetActivePopout() end
    end)

    self.popouts[id] = popout
    self:RefreshPopouts()
    self:ArrangePopouts()
    self:ShowAnimated(popout)
    self:SetActivePopout(popout)
    self:SchedulePopoutFade(popout)
end

function UI:ShouldCountGeneralBadge(message)
    if not message or not message.incoming then return false end
    local chatType = tostring(message.chatType or "")
    if chatType == "CHAT_MSG_PARTY" or chatType == "CHAT_MSG_PARTY_LEADER" then return true end
    return CC.MessageMentionsPlayer and CC:MessageMentionsPlayer(message.text) or false
end

function UI:IsChannelVisible(channel, target, message)
    if channel == "WHISPER" then target = CC:ResolveWhisperConversation(target) end
    if self.main and self.main:IsShown() then
        if channel == "WHISPER" and self.mode == "WHISPER" then
            if self.currentTarget == target then return true end
        elseif channel == "QUEST" and self.mode == "QUEST" then
            if self.currentQuestTarget == target then return true end
        elseif channel == "GENERAL" and self:IsGeneralFeedMode(self.mode) then
            if self.mode == "GENERAL" or (message and CC:ChannelColorKey(message) == self.mode) then return true end
        elseif channel == self.mode then
            return true
        end
    end

    if channel == "COMBAT" and self.combatPanel and self.combatPanel:IsShown() then return true end

    local id
    if channel == "WHISPER" then id = "WHISPER:" .. tostring(target)
    elseif channel == "QUEST" then id = "QUEST:" .. tostring(target)
    else id = channel end
    local popout = self.popouts[id]
    if popout and popout:IsShown() then return true end
    if channel == "GENERAL" and message then
        local filtered = self.popouts[CC:ChannelColorKey(message)]
        if filtered and filtered:IsShown() then return true end
    end
    return false
end

function UI:RefreshVisibleLiveMessage(channel, target, message)
    if not message then return end
    if channel == "WHISPER" then target = CC:ResolveWhisperConversation(target or message.target or message.sender) end

    if self.main and self.main:IsShown() then
        if channel == "WHISPER" and self.mode == "WHISPER" and self.currentTarget == target then
            self.mainView:Refresh((CC.db.history.whispers or {})[target] or {}, "WHISPER")
        elseif channel == "QUEST" and self.mode == "QUEST" and self.currentQuestTarget == target then
            self.mainView:Refresh((CC.db.history.quests or {})[target] or {}, "QUEST")
        elseif channel == "GUILD" and self.mode == "GUILD" then
            self.mainView:Refresh(CC.db.history.guild or {}, "GUILD")
        elseif channel == "GENERAL" and self:IsGeneralFeedMode(self.mode) then
            if self.mode == "GENERAL" or CC:ChannelColorKey(message) == self.mode then
                self.mainView:Refresh(self:GetGeneralMessagesForMode(self.mode), "GENERAL")
            end
        end
    end

    local id
    if channel == "WHISPER" then id = "WHISPER:" .. tostring(target)
    elseif channel == "QUEST" then id = "QUEST:" .. tostring(target)
    else id = channel end
    local popout = self.popouts and self.popouts[id]
    if popout and popout:IsShown() and popout.messageView then
        if channel == "WHISPER" then popout.messageView:Refresh((CC.db.history.whispers or {})[target] or {}, "WHISPER")
        elseif channel == "QUEST" then popout.messageView:Refresh((CC.db.history.quests or {})[target] or {}, "QUEST")
        elseif channel == "GUILD" then popout.messageView:Refresh(CC.db.history.guild or {}, "GUILD")
        elseif channel == "GENERAL" then popout.messageView:Refresh(self:GetGeneralMessagesForMode(popout.channel), "GENERAL") end
    end
    if channel == "GENERAL" and message then
        local filteredID = CC:ChannelColorKey(message)
        local filtered = self.popouts and self.popouts[filteredID]
        if filtered and filtered:IsShown() and filtered.messageView then
            filtered.messageView:Refresh(self:GetGeneralMessagesForMode(filteredID), "GENERAL")
        end
    end
end

function UI:OnNewMessage(channel, target, message, shouldAlert)
    if not message then return end

    if channel == "WHISPER" then
        target = CC:ResolveWhisperConversation(target or message.target or message.sender)
        message.target = target
    elseif channel == "QUEST" then
        target = target or message.target
        message.target = target
        if self.mode == "QUEST" and self.main and self.main:IsShown() then
            self.currentQuestTarget = target
        elseif not self.currentQuestTarget then
            self.currentQuestTarget = target
        end
    end

    if channel == "COMBAT" then
        self:QueueCombatRefresh()
        return
    end

    -- Refresh the currently visible chat surface immediately. The broader queued
    -- refresh below still updates badges, rosters and chrome, but a slow roster API
    -- can no longer delay live chat text in Guild, Party, Raid, Instance or channels.
    self:RefreshVisibleLiveMessage(channel, target, message)

    local incoming = message.incoming and true or false
    local visible = self:IsChannelVisible(channel, target, message)
    if incoming and not visible then
        if channel == "WHISPER" then
            self.unreadByTarget[target] = (self.unreadByTarget[target] or 0) + 1
            CC.state.unreadWhispers = CC.state.unreadWhispers + 1
        elseif channel == "QUEST" then
            self.unreadQuestByTarget[target] = (self.unreadQuestByTarget[target] or 0) + 1
            CC.state.unreadQuests = (CC.state.unreadQuests or 0) + 1
        elseif channel == "GUILD" then
            CC.state.unreadGuild = CC.state.unreadGuild + 1
        elseif channel == "GENERAL" and self:ShouldCountGeneralBadge(message) then
            CC.state.unreadGeneral = CC.state.unreadGeneral + 1
        end
    end

    if incoming and not visible then
        if channel == "WHISPER" then
            self:NotifyLauncher("WHISPER", target)
        elseif channel == "QUEST" then
            self:NotifyLauncher("QUEST", target)
        elseif channel == "GUILD" then
            self:NotifyLauncher("GUILD")
        elseif channel == "GENERAL" and self:ShouldCountGeneralBadge(message) then
            local chatType = tostring(message.chatType or "")
            if chatType == "CHAT_MSG_PARTY" or chatType == "CHAT_MSG_PARTY_LEADER" then
                self:NotifyLauncher("PARTY_MESSAGE")
            else
                self:NotifyLauncher("GENERAL")
            end
        end
    end

    if incoming and channel == "WHISPER" and not visible and (not CC.IsNotificationEnabled or CC:IsNotificationEnabled("WHISPER")) and (CC.db.ui or {}).showDockWhisperAlert ~= false then
        self:ShowWhisperDockAlert(target, message)
    end
    if incoming and shouldAlert then self:ShowToast(channel, target, message) end

    local flags = { badges = true }
    if channel == "WHISPER" or channel == "QUEST" then
        flags.conversations = true
        if channel == "WHISPER" and self.mode == "WHISPER" and self.currentTarget == target then flags.chrome = true end
    end
    if self.main and self.main:IsShown() and (self.mode == channel or (channel == "GENERAL" and self:IsGeneralFeedMode(self.mode))) then
        if channel == "WHISPER" then
            if self.currentTarget == target then flags.main = true end
        elseif channel == "QUEST" then
            if self.currentQuestTarget == target then flags.main = true end
        elseif channel == "GENERAL" then
            if self.mode == "GENERAL" or CC:ChannelColorKey(message) == self.mode then flags.main = true end
        else
            flags.main = true
        end
    end
    local id
    if channel == "WHISPER" then id = "WHISPER:" .. tostring(target)
    elseif channel == "QUEST" then id = "QUEST:" .. tostring(target)
    else id = channel end
    if id and self.popouts and self.popouts[id] and self.popouts[id]:IsShown() then flags.popout = id end
    if channel == "GENERAL" then
        local filteredID = CC:ChannelColorKey(message)
        if self.popouts and self.popouts[filteredID] and self.popouts[filteredID]:IsShown() then
            flags.popouts = flags.popouts or {}
            flags.popouts[filteredID] = true
        end
    end
    if self.RequestRefresh then self:RequestRefresh(flags) else self:RefreshAll() end
end

function UI:ApplySavedPositions()
    if self.main then
        applySize(self.main, "main", 470, 520)
        applyPosition(self.main, "main")
    end
    if self.bubble then
        applyPosition(self.bubble, "bubble")
    end
    self:PositionQuickButtons()
    self:PositionCombatPanel()
    if self.quickInput then self.quickInput.creshPositionApplied = false end
    self:SetSharedDockWidth((CC.db.ui or {}).sharedDockWidth or 470)
    self:SetPopoutWidth((CC.db.ui or {}).popoutWidth or 400)
    self:PositionQuickInput(true)
    self:RepositionToasts()
end

function UI:Initialize()
    if self.initialized then
        return
    end

    self.mode = "WHISPER"
    self.currentTarget = nil
    self.currentQuestTarget = nil
    self.unreadByTarget = {}
    self.unreadQuestByTarget = {}
    self.toasts = {}
    self.toastPool = {}
    self.secondaryToasts = {}
    self.secondaryToastPool = {}
    self.presenceDedupe = {}
    self.popouts = {}
    self.popoutCount = 0
    self.popoutActivityCounter = 0
    self.activePopout = nil

    self:SyncThemeColors()
    self:SyncGuildTheme()
    local chatEnabled     = CC.IsFeatureEnabled and CC:IsFeatureEnabled("chat")
    local gamesEnabled    = CC.IsFeatureEnabled and CC:IsFeatureEnabled("games")
    local achieveEnabled  = CC.IsFeatureEnabled and CC:IsFeatureEnabled("gameProgression")
    local progressEnabled = CC.ProgressHub and CC.ProgressHub:HasAnyEnabled()
    if chatEnabled then
        self:BuildMainFrame()
        self:BuildQuickInput()
        self:BuildCombatPanel()
    else
        self:BuildGamesAnchor()
    end
    -- The C launcher is built whenever any major destination is enabled, even
    -- with chat disabled, so Games/Achievements/Progress-only players still have a launcher.
    if chatEnabled or gamesEnabled or achieveEnabled or progressEnabled then
        self:BuildBubble()
    end
    self.initialized = true
    if chatEnabled then
        self:InstallEnterChatHook()
        self:InstallBlizzardChatRedirects()
        if C_Timer and C_Timer.After then
            C_Timer.After(1.0, function() if UI.initialized then UI:InstallBlizzardChatRedirects() end end)
            C_Timer.After(3.0, function() if UI.initialized then UI:InstallBlizzardChatRedirects() end end)
        end
        self:SetMode("WHISPER")
        self.main:Hide()
    end
    self:RefreshAll()
end
