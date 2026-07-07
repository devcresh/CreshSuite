local _, CC = ...
if not CC or not CC.UI then return end
local UI = CC.UI

local max, min, floor = math.max, math.min, math.floor
local function templateName()
    return _G.BackdropTemplateMixin and "BackdropTemplate" or nil
end

local function backdrop(frame, r, g, b, a, br, bg, bb, ba)
    if frame.SetBackdrop then
        local chrome = frame.creshClassicChrome and UI.GetThemeChrome and UI:GetThemeChrome() or nil
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
                edgeSize = 1,
                insets = { left = 1, right = 1, top = 1, bottom = 1 },
            })
        end
        frame:SetBackdropColor(r or 0.06, g or 0.07, b or 0.09, a or 0.98)
        frame:SetBackdropBorderColor(br or 0.2, bg or 0.22, bb or 0.28, ba or 1)
    end
end

local function font(parent, size, justify)
    local f = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f:SetFont(STANDARD_TEXT_FONT, size or 11, "")
    f:SetTextColor(0.92, 0.94, 0.98, 1)
    f:SetJustifyH(justify or "LEFT")
    f:SetJustifyV("MIDDLE")
    return f
end

local function raiseFrame(frame, relativeTo, levelOffset)
    if not frame or not relativeTo then return end
    if frame.SetFrameStrata and relativeTo.GetFrameStrata then
        frame:SetFrameStrata(relativeTo:GetFrameStrata())
    end
    if frame.SetFrameLevel and relativeTo.GetFrameLevel then
        local target = (relativeTo:GetFrameLevel() or 0) + (levelOffset or 1)
        frame:SetFrameLevel(max(1, min(9000, target)))
    end
end

local function button(parent, text, width, height, callback)
    local b = CreateFrame("Button", nil, parent, templateName())
    b:SetSize(width or 100, height or 26)
    backdrop(b, 0.095, 0.108, 0.138, 1, 0.16, 0.19, 0.25, 1)
    b.text = font(b, 10, "CENTER")
    b.text:SetAllPoints()
    b.text:SetText(text or "")
    b:SetScript("OnClick", function(...)
        if UI.FullSettings and UI.FullSettings.frame and UI.FocusWindow then UI:FocusWindow(UI.FullSettings.frame) end
        if callback then callback(...) end
    end)
    b:SetScript("OnEnter", function(self)
        local c = CC.db and CC.db.colors and CC.db.colors.accent or { 0.11, 0.43, 0.95, 1 }
        if self.SetBackdropColor then self:SetBackdropColor(c[1] * 0.55, c[2] * 0.55, c[3] * 0.55, 1) end
    end)
    b:SetScript("OnLeave", function(self)
        if self.creshActive then return end
        if self.SetBackdropColor then self:SetBackdropColor(0.095, 0.108, 0.138, 1) end
    end)
    return b
end

local function ensureTables()
    CC.db.ui = CC.db.ui or {}
    CC.db.ui.consoleTabs = CC.db.ui.consoleTabs or {}
    CC.db.notifications = CC.db.notifications or {}
    CC.db.notificationPriorities = CC.db.notificationPriorities or {}
    CC.db.notificationSources = CC.db.notificationSources or {}
    CC.db.sounds = CC.db.sounds or { master = true, whisper = true, guild = true, party = true, partyInvite = true, partyMessage = true, quest = true, mentions = true, friends = true, game = true, system = false }
    CC.db.soundChoices = CC.db.soundChoices or {}
    CC.db.soundVolumes = CC.db.soundVolumes or {}
    CC.db.colors = CC.db.colors or {}
    CC.db.colors.channels = CC.db.colors.channels or {}
    CC.db.colors.guild = CC.db.colors.guild or {}
    CC.db.positions = CC.db.positions or {}
    CC.db.sizes = CC.db.sizes or {}
end

local function apply()
    ensureTables()
    CC.db.sound = CC.db.sounds.master ~= false
    -- Slider drags can fire many times per frame. The quality layer coalesces
    -- those visual rebuilds so settings remain smooth while values update live.
    if UI.RequestVisualApply then UI:RequestVisualApply()
    elseif UI.ApplyVisualSettings then UI:ApplyVisualSettings() end
end

local function openColorPicker(color, changed)
    local previous = { color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1 }
    local function update()
        local r, g, b = ColorPickerFrame:GetColorRGB()
        color[1], color[2], color[3] = r, g, b
        changed()
    end
    local function cancel(values)
        local v = values or previous
        color[1], color[2], color[3], color[4] = v[1], v[2], v[3], v[4]
        changed()
    end
    if ColorPickerFrame.SetupColorPickerAndShow then
        ColorPickerFrame:SetupColorPickerAndShow({
            r = previous[1], g = previous[2], b = previous[3], hasOpacity = false,
            swatchFunc = update, cancelFunc = function() cancel(previous) end,
        })
    else
        ColorPickerFrame.hasOpacity = false
        ColorPickerFrame.previousValues = previous
        ColorPickerFrame.func = update
        ColorPickerFrame.opacityFunc = update
        ColorPickerFrame.cancelFunc = cancel
        ColorPickerFrame:SetColorRGB(previous[1], previous[2], previous[3])
        ColorPickerFrame:Hide(); ColorPickerFrame:Show()
    end
end

local THEME_DISPLAY = {
    CRESH_MINIMAL = "Cresh Minimal", ELVUI_CHARCOAL = "ElvUI Charcoal", TUKUI_OBSIDIAN = "Tukui Obsidian",
    WIM_CLASSIC = "WIM Messenger", PRAT_GLASS = "Prat Glass", LS_GLASS = "LS Glass",
    CHATTYNATOR_SLATE = "Chattynator Slate", SPARTAN_STEEL = "Spartan Steel", NDUI_AZURE = "NDui Azure",
    BENIK_TEAL = "Benik Teal", GINGI_NEON = "Gingi Neon", NORD_FROST = "Nord Frost",
    WOW_CLASSIC = "WoW Classic", ZLR = "ZLR Arena", CLASSIC_BRONZE = "Classic Bronze", HIGH_CONTRAST = "High Contrast",
    MESSENGER = "Messenger Blue", SNAPCHAT = "Snapchat Contrast", DISCORD = "Discord Dark",
    ICQ = "ICQ", MSN_MESSENGER = "MSN Messenger", WINDOWS_31 = "Windows 3.1",
    WINDOWS_95 = "Windows 95", UBUNTU = "Ubuntu",
    MIDNIGHT = "Midnight", CUSTOM = "Custom colours",
}
local THEME_VALUES = {
    "CRESH_MINIMAL", "WOW_CLASSIC", "ZLR", "ELVUI_CHARCOAL", "TUKUI_OBSIDIAN", "WIM_CLASSIC",
    "PRAT_GLASS", "LS_GLASS", "CHATTYNATOR_SLATE", "SPARTAN_STEEL", "NDUI_AZURE",
    "BENIK_TEAL", "GINGI_NEON", "NORD_FROST", "CLASSIC_BRONZE", "HIGH_CONTRAST",
    "MESSENGER", "SNAPCHAT", "DISCORD", "ICQ", "MSN_MESSENGER", "WINDOWS_31",
    "WINDOWS_95", "UBUNTU", "MIDNIGHT", "CUSTOM",
}
local GUILD_THEME_VALUES = {
    "AUTO", "VERDANT", "EMERALD", "JADE_NIGHT", "MOSS_STONE", "SAGE_PARCHMENT",
    "FEL_GREEN", "DEEP_FOREST", "ALLIANCE", "ALLIANCE_ARCANE", "HORDE", "HORDE_IRON", "CUSTOM",
}
local GUILD_THEME_DISPLAY = UI.GUILD_THEME_DISPLAY or {}
if CC.ThemeLibrary then
    local rebuilt, seen = {}, {}
    for _, key in ipairs(THEME_VALUES) do if key ~= "CUSTOM" and not seen[key] then rebuilt[#rebuilt + 1] = key; seen[key] = true end end
    for _, key in ipairs(CC.ThemeLibrary.order or {}) do
        if not seen[key] then rebuilt[#rebuilt + 1] = key; seen[key] = true end
        THEME_DISPLAY[key] = (CC.ThemeLibrary.display or {})[key] or key
    end
    rebuilt[#rebuilt + 1] = "CUSTOM"
    THEME_VALUES = rebuilt

    local guildRebuilt, guildSeen = {}, {}
    for _, key in ipairs(GUILD_THEME_VALUES) do if key ~= "CUSTOM" and not guildSeen[key] then guildRebuilt[#guildRebuilt + 1] = key; guildSeen[key] = true end end
    for _, key in ipairs(CC.ThemeLibrary.guildOrder or {}) do
        if not guildSeen[key] then guildRebuilt[#guildRebuilt + 1] = key; guildSeen[key] = true end
        GUILD_THEME_DISPLAY[key] = (CC.ThemeLibrary.guildDisplay or {})[key] or key
    end
    guildRebuilt[#guildRebuilt + 1] = "CUSTOM"
    GUILD_THEME_VALUES = guildRebuilt
end
local ANIM_DISPLAY = {
    SLIDE_DOCK = "Slide from dock", SLIDE_LEFT = "Slide from left", SLIDE_RIGHT = "Slide from right",
    SLIDE_UP = "Slide upward", SLIDE_DOWN = "Slide downward", POP = "Pop", FAN_UP = "Fan upward",
    FAN_DOWN = "Fan downward", SWOOP = "Swoop", FADE = "Fade", ZOOM = "Zoom", BOUNCE = "Bounce", NONE = "None",
}
local ANIM_VALUES = { "SLIDE_DOCK", "SLIDE_LEFT", "SLIDE_RIGHT", "SLIDE_UP", "SLIDE_DOWN", "POP", "FAN_UP", "FAN_DOWN", "SWOOP", "FADE", "ZOOM", "BOUNCE", "NONE" }
local PROFILE_VALUES = { "BALANCED", "MINIMAL", "MESSENGER", "POPOUT", "PERFORMANCE" }
local PROFILE_DISPLAY = { BALANCED="Balanced", MINIMAL="Minimal", MESSENGER="Messenger", POPOUT="Pop-out focus", PERFORMANCE="Performance" }
local SOUND_DISPLAY = {
    OFF="Off", DING="Clear ding", CHIME="Bright chime", WHISPER="Whisper message",
    SOFT="Soft tick", MESSAGE="Message scroll", QUEST="Quest chime", READY="Ready check",
    WARNING="Warning pulse", OPEN="Window open", COIN="Coin bell",
}
local ALL_SOUND_VALUES = { "OFF", "DING", "CHIME", "WHISPER", "SOFT", "MESSAGE", "QUEST", "READY", "WARNING", "OPEN", "COIN" }
local CUSTOM_SOUND_LIBRARY = _G.CreshChatSoundLibrary
if CUSTOM_SOUND_LIBRARY then
    for _, key in ipairs(CUSTOM_SOUND_LIBRARY.order or {}) do
        ALL_SOUND_VALUES[#ALL_SOUND_VALUES + 1] = key
        SOUND_DISPLAY[key] = (CUSTOM_SOUND_LIBRARY.display or {})[key] or key
    end
end
local SOUND_VALUES = {
    whisper = ALL_SOUND_VALUES,
    guild = ALL_SOUND_VALUES,
    partyInvite = ALL_SOUND_VALUES,
    partyMessage = ALL_SOUND_VALUES,
    quest = ALL_SOUND_VALUES,
    mentions = ALL_SOUND_VALUES,
    friends = ALL_SOUND_VALUES,
    game = ALL_SOUND_VALUES,
    system = ALL_SOUND_VALUES,
}
local NOTIFICATION_PRIORITY_VALUES = { "CRITICAL", "HIGH", "NORMAL", "LOW" }
local NOTIFICATION_PRIORITY_DISPLAY = {
    CRITICAL = "Critical - full-size and longest",
    HIGH = "High - full-size",
    NORMAL = "Normal - slide-out",
    LOW = "Low - compact and shorter",
}
local NOTIFICATION_ANIMATION_VALUES = { "FAN_UP", "FAN_DOWN", "SLIDE_LEFT", "SLIDE_RIGHT", "SLIDE_UP", "SLIDE_DOWN", "POP", "SWOOP", "FADE", "ZOOM", "BOUNCE", "NONE" }
local function previewNotification(channel)
    if CC.PlayAlertSound then CC:PlayAlertSound(channel, true) end
    if UI.PreviewLauncherNotification then UI:PreviewLauncherNotification(channel) end
end

local function chooseSound(key, channel, value)
    if CC.SetSoundChoice then CC:SetSoundChoice(key, value) end
    if value ~= "OFF" then previewNotification(channel) end
end

local Settings = { version = CC.version }
local SETTINGS_FRAME_LEVEL = 7000

-- Phase 6: standardised row heights shared by every Create*/Builder method
-- below (previously a different hardcoded literal per method).
local ROW_HEIGHT = 33
local DROPDOWN_ROW_HEIGHT = 37
local SLIDER_ROW_HEIGHT = 54
local BUTTON_ROW_HEIGHT = 34
local SECTION_ROW_HEIGHT = 27

-- ============================================================
-- Phase 5 - Product tab shell
-- ============================================================

local SUITE_RELEASES_URL = "https://github.com/devcresh/CreshSuite/releases"

local PRODUCTS = {
    { key = "CC",   label = "CreshChat",    addonName = "CreshChat",  owned = true },
    { key = "CG",   label = "CreshGames",   addonName = "CreshGames",   minVer = CC.version },
    { key = "CCOL", label = "CreshCollect", addonName = "CreshCollect", minVer = CC.version },
}

local function detectAddonStatus(addonName, minVer)
    if IsAddOnLoaded and IsAddOnLoaded(addonName) then
        if minVer and _G.CreshSuite then
            local p = _G.CreshSuite.GetProduct and _G.CreshSuite:GetProduct(addonName)
            local verStr = p and p.version
            local VC = _G.CreshChatVersionCompare
            if verStr and VC and not VC.IsUnset(verStr) then
                local cmp = VC.Compare(verStr, minVer)
                if cmp and cmp < 0 then return "incompatible", tostring(verStr) end
            end
        end
        return "loaded"
    end
    if GetAddOnInfo then
        local name, _, _, loadable, reason = GetAddOnInfo(addonName)
        if name == nil then return "missing" end
        if reason == "DISABLED" then return "disabled" end
        if reason == "MISSING"  then return "missing"  end
        if not loadable and reason then return "incompatible", reason end
        if not loadable then return "disabled" end
    end
    return "missing"
end
local SETTINGS_DROPDOWN_LEVEL = 500
UI.FullSettings = Settings
if CC.RegisterModule then CC:RegisterModule("Settings", Settings) end
UI.fullSettings = Settings

-- Phase 6: one native two-step confirmation dialog (WoW's own StaticPopup
-- idiom) reused for every destructive reset button across all three
-- addons' settings pages -- CreshGames'/CreshCollect's build(builder)
-- callbacks reach it via Builder:ConfirmAction, which just delegates here.
_G.StaticPopupDialogs = _G.StaticPopupDialogs or {}
_G.StaticPopupDialogs["CRESHSUITE_SETTINGS_CONFIRM"] = {
    text = "%s",
    button1 = _G.YES or "Yes",
    button2 = _G.NO or "No",
    OnAccept = function(_, data) if data and data.onConfirm then data.onConfirm() end end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

function Settings:ConfirmAction(message, onConfirm)
    if _G.StaticPopup_Show then
        _G.StaticPopup_Show("CRESHSUITE_SETTINGS_CONFIRM", message, nil, { onConfirm = onConfirm })
    elseif onConfirm then
        onConfirm()
    end
end

function Settings:RegisterLayout(control, kind, column)
    control.creshLayoutKind   = kind or "full"
    control.creshLayoutColumn = column or 1
    control.creshProductKey   = self.currentProductKey
    if control.HookScript then
        control:HookScript("OnMouseDown", function()
            if Settings.frame and UI.FocusWindow then UI:FocusWindow(Settings.frame) end
        end)
    end
    self.layoutControls[#self.layoutControls + 1] = control
end

function Settings:CreateToggle(parent, label, getter, setter, x, y, width, kind, column)
    local row = CreateFrame("Button", nil, parent, templateName())
    row:SetSize(width, 27)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    backdrop(row, 0.075, 0.086, 0.112, 0.97, 0.13, 0.15, 0.20, 1)
    row.label = font(row, 10, "LEFT")
    row.label:SetPoint("LEFT", row, "LEFT", 8, 0)
    row.label:SetPoint("RIGHT", row, "RIGHT", -52, 0)
    row.label:SetText(label)
    row.value = font(row, 9, "RIGHT")
    row.value:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    row:SetScript("OnClick", function()
        setter(not getter()); apply(); Settings:Refresh()
    end)
    row.Refresh = function(self)
        local on = getter() and true or false
        self.value:SetText(on and "ON" or "OFF")
        self.value:SetTextColor(on and 0.35 or 0.95, on and 0.90 or 0.35, on and 0.55 or 0.35, 1)
    end
    self.refreshables[#self.refreshables + 1] = row
    self:RegisterLayout(row, kind, column)
    return row
end

-- Small unlabelled ON/OFF square used by the Notifications table's
-- per-category rows -- unlike CreateToggle, it isn't a top-level layout
-- control (no RegisterLayout call): its parent row manages its position and
-- size directly, the same way Builder:Buttons manages its button group.
function Settings:CreateCompactToggle(parent, getter, setter, size)
    local box = CreateFrame("Button", nil, parent, templateName())
    box:SetSize(size or 22, size or 22)
    box.Refresh = function(self)
        local on = getter() and true or false
        local c = CC.db and CC.db.colors and CC.db.colors.accent or { 0.11, 0.43, 0.95, 1 }
        if on then backdrop(self, c[1] * 0.55, c[2] * 0.55, c[3] * 0.55, 1, c[1], c[2], c[3], 1)
        else backdrop(self, 0.075, 0.086, 0.112, 0.97, 0.13, 0.15, 0.20, 1) end
    end
    box:SetScript("OnClick", function()
        setter(not getter()); apply(); Settings:Refresh()
    end)
    self.refreshables[#self.refreshables + 1] = box
    return box
end

function Settings:CloseDropdown(except)
    local open = self.openDropdown
    if open and open ~= except and open.menu then open.menu:Hide() end
    if not except then self.openDropdown = nil end
end

function Settings:CreateDropdown(parent, label, getter, setter, values, display, x, y, width, options)
    options = options or {}
    self.dropdownCounter = (self.dropdownCounter or 0) + 1
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(width, 31)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    -- Compact mode (used by the Notifications table's per-category rows):
    -- no reserved label -- the row's own name label already identifies the
    -- category once -- and the button stretches to fill the whole slot
    -- instead of the usual 44%-of-row-width split.
    if not options.compact then
        row.label = font(row, 10, "LEFT")
        row.label:SetPoint("LEFT", row, "LEFT", 0, 0)
        row.label:SetPoint("RIGHT", row, "RIGHT", -228, 0)
        row.label:SetText(label)
    end

    row.button = button(row, "", options.compact and width or 218, 27, function()
        if row.menu:IsShown() then
            row.menu:Hide(); Settings.openDropdown = nil
        else
            Settings:CloseDropdown(row)
            Settings.openDropdown = row
            if UI.FullSettings and UI.FullSettings.frame and UI.FocusWindow then UI:FocusWindow(UI.FullSettings.frame) end
            row:LayoutMenu(true)
            row.menu:Show()
        end
    end)
    if options.compact then
        row.button:SetPoint("LEFT", row, "LEFT", 0, 0)
        row.button:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    else
        row.button:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    end
    row.button.text:ClearAllPoints()
    row.button.text:SetPoint("LEFT", row.button, "LEFT", 9, 0)
    row.button.text:SetPoint("RIGHT", row.button, "RIGHT", -26, 0)
    row.button.text:SetJustifyH("LEFT")
    row.button.arrow = font(row.button, 10, "CENTER")
    row.button.arrow:SetPoint("RIGHT", row.button, "RIGHT", -8, 0)
    row.button.arrow:SetText("v")
    row.button.arrow:SetTextColor(0.56, 0.72, 0.96, 1)

    local menuName = "CreshChatSettingsDropdown" .. self.dropdownCounter
    local menu = CreateFrame("Frame", menuName, UIParent, templateName())
    menu:SetFrameStrata("TOOLTIP")
    menu:SetFrameLevel(SETTINGS_DROPDOWN_LEVEL)
    menu:SetClampedToScreen(true)
    backdrop(menu, 0.045, 0.052, 0.070, 1, 0.20, 0.25, 0.34, 1)
    menu:Hide()
    row.menu = menu
    row.items = {}
    row.menuPage = 1
    row.menuPages = 1
    row.menuCapacity = #values

    for index, value in ipairs(values) do
        local item = CreateFrame("Button", nil, menu, templateName())
        item:SetHeight(24)
        backdrop(item, 0.065, 0.074, 0.096, 1, 0.11, 0.13, 0.17, 0)
        item.check = font(item, 10, "CENTER")
        item.check:SetPoint("LEFT", item, "LEFT", 7, 0)
        item.check:SetWidth(14)
        item.text = font(item, 10, "LEFT")
        item.text:SetPoint("LEFT", item, "LEFT", 25, 0)
        item.text:SetPoint("RIGHT", item, "RIGHT", -7, 0)
        item.value = value
        item.creshHovered = false
        item.RefreshAppearance = function(selfItem)
            local selected = selfItem.creshSelected == true
            local locked = options.isLocked and options.isLocked(value) == true or false
            selfItem.creshLocked = locked
            local name = display[value] or tostring(value)
            selfItem.text:SetText(locked and (name .. "  [LOCKED]") or name)
            if locked then
                if selfItem.creshHovered then
                    backdrop(selfItem, 0.050, 0.054, 0.064, 1, 0.16, 0.17, 0.20, 1)
                else
                    backdrop(selfItem, 0.024, 0.027, 0.034, 1, 0.075, 0.082, 0.096, 1)
                end
                selfItem.text:SetTextColor(0.38, 0.40, 0.45, 1)
                selfItem.check:SetTextColor(0.34, 0.36, 0.40, 1)
            else
                local c = CC.db and CC.db.colors and CC.db.colors.accent or { 0.11, 0.43, 0.95, 1 }
                if selfItem.creshHovered then
                    backdrop(selfItem, c[1] * 0.35, c[2] * 0.35, c[3] * 0.35, 1, c[1] * 0.60, c[2] * 0.60, c[3] * 0.60, 0.9)
                else
                    backdrop(selfItem, 0.065, 0.074, 0.096, 1, 0.11, 0.13, 0.17, 0)
                end
                selfItem.text:SetTextColor(selected and 0.45 or 0.92, selected and 0.80 or 0.94, selected and 1.00 or 0.98, 1)
                selfItem.check:SetTextColor(0.56, 0.78, 1.00, 1)
            end
        end
        item:SetScript("OnEnter", function(selfItem)
            selfItem.creshHovered = true
            selfItem:RefreshAppearance()
        end)
        item:SetScript("OnLeave", function(selfItem)
            selfItem.creshHovered = false
            selfItem:RefreshAppearance()
        end)
        item:SetScript("OnClick", function()
            local locked = options.isLocked and options.isLocked(value) == true or false
            menu:Hide(); Settings.openDropdown = nil
            if options.onSelect then
                options.onSelect(value, locked, row)
            else
                setter(value)
                apply()
            end
            if options.refreshAfter ~= false then Settings:Refresh() end
        end)
        row.items[index] = { frame = item, value = value }
    end

    row.pageText = font(menu, 9, "CENTER")
    row.pageText:SetTextColor(0.62, 0.70, 0.82, 1)
    row.previousPage = button(menu, "<", 30, 23, function()
        if row.menuPage > 1 then row.menuPage = row.menuPage - 1; row:LayoutMenu(false) end
    end)
    row.nextPage = button(menu, ">", 30, 23, function()
        if row.menuPage < row.menuPages then row.menuPage = row.menuPage + 1; row:LayoutMenu(false) end
    end)

    local function settingsMenuScale()
        local settingsFrame = Settings.frame
        local frameScale = settingsFrame and settingsFrame.GetEffectiveScale and settingsFrame:GetEffectiveScale()
            or (settingsFrame and settingsFrame.GetScale and settingsFrame:GetScale()) or 1
        local parentScale = UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()
            or (UIParent and UIParent.GetScale and UIParent:GetScale()) or 1
        if not parentScale or parentScale <= 0 then parentScale = 1 end
        return max(0.45, frameScale / parentScale)
    end

    function row:LayoutMenu(focusCurrent)
        local scale = settingsMenuScale()
        menu:SetScale(scale)

        local screenWidth = UIParent and UIParent.GetWidth and UIParent:GetWidth() or 1920
        local screenHeight = UIParent and UIParent.GetHeight and UIParent:GetHeight() or 1080
        local availableWidth = max(210, (screenWidth / scale) - 24)
        local availableHeight = max(180, (screenHeight / scale) - 24)
        local preferredItemWidth = #values > 40 and 154 or 218
        local itemWidth = min(preferredItemWidth, max(132, availableWidth - 6))
        local maximumColumns = max(1, min(6, floor((availableWidth - 6) / itemWidth)))
        local footerHeight = 30
        local maximumRows = max(5, floor((availableHeight - footerHeight - 8) / 25))
        local preferredColumns = #values > 60 and 4 or (#values > 12 and 2 or 1)
        local requiredColumns = math.ceil(#values / maximumRows)
        local columns = max(1, min(maximumColumns, max(preferredColumns, requiredColumns)))
        local capacity = max(1, columns * maximumRows)
        local pages = max(1, math.ceil(#values / capacity))

        self.menuCapacity = capacity
        self.menuPages = pages
        if focusCurrent then
            local current = getter()
            for index, item in ipairs(self.items) do
                if item.value == current then self.menuPage = math.ceil(index / capacity); break end
            end
        end
        self.menuPage = max(1, min(pages, self.menuPage or 1))

        local firstIndex = ((self.menuPage - 1) * capacity) + 1
        local itemCount = min(capacity, max(0, #values - firstIndex + 1))
        local rows = max(1, min(maximumRows, math.ceil(itemCount / columns)))
        local visibleColumns = max(1, math.ceil(itemCount / rows))
        local menuWidth = max(itemWidth, itemWidth * visibleColumns)
        local menuHeight = rows * 25 + 6 + (pages > 1 and footerHeight or 0)
        menu:SetSize(menuWidth, menuHeight)

        for index, item in ipairs(self.items) do
            local localIndex = index - firstIndex + 1
            if localIndex >= 1 and localIndex <= itemCount then
                local column = floor((localIndex - 1) / rows)
                local rowIndex = (localIndex - 1) % rows
                item.frame:ClearAllPoints()
                item.frame:SetPoint("TOPLEFT", menu, "TOPLEFT", 3 + column * itemWidth, -3 - rowIndex * 25)
                item.frame:SetWidth(itemWidth - 6)
                item.frame:Show()
            else
                item.frame:Hide()
            end
        end

        if pages > 1 then
            self.previousPage:ClearAllPoints()
            self.previousPage:SetPoint("BOTTOMLEFT", menu, "BOTTOMLEFT", 4, 3)
            self.nextPage:ClearAllPoints()
            self.nextPage:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", -4, 3)
            self.pageText:ClearAllPoints()
            self.pageText:SetPoint("LEFT", self.previousPage, "RIGHT", 5, 0)
            self.pageText:SetPoint("RIGHT", self.nextPage, "LEFT", -5, 0)
            self.pageText:SetText("Page " .. tostring(self.menuPage) .. " / " .. tostring(pages))
            if self.menuPage > 1 then self.previousPage:Enable() else self.previousPage:Disable() end
            if self.menuPage < pages then self.nextPage:Enable() else self.nextPage:Disable() end
            self.previousPage:SetAlpha(self.menuPage > 1 and 1 or 0.38)
            self.nextPage:SetAlpha(self.menuPage < pages and 1 or 0.38)
            self.previousPage:Show(); self.nextPage:Show(); self.pageText:Show()
        else
            self.previousPage:Hide(); self.nextPage:Hide(); self.pageText:Hide()
        end

        menu:ClearAllPoints()
        local buttonBottom = self.button.GetBottom and self.button:GetBottom() or 0
        local buttonTop = self.button.GetTop and self.button:GetTop() or 0
        local menuHeightOnParent = menuHeight * scale
        local roomBelow = buttonBottom
        local roomAbove = screenHeight - buttonTop
        if roomBelow >= menuHeightOnParent + 8 or roomBelow >= roomAbove then
            menu:SetPoint("TOPRIGHT", self.button, "BOTTOMRIGHT", 0, -2)
        else
            menu:SetPoint("BOTTOMRIGHT", self.button, "TOPRIGHT", 0, 2)
        end
    end

    menu:EnableMouseWheel(true)
    menu:SetScript("OnMouseWheel", function(_, delta)
        if row.menuPages <= 1 then return end
        if delta < 0 and row.menuPage < row.menuPages then row.menuPage = row.menuPage + 1; row:LayoutMenu(false)
        elseif delta > 0 and row.menuPage > 1 then row.menuPage = row.menuPage - 1; row:LayoutMenu(false) end
    end)
    menu:SetScript("OnShow", function() row:LayoutMenu(false) end)
    menu:SetScript("OnHide", function()
        if Settings.openDropdown == row then Settings.openDropdown = nil end
    end)
    row.Relayout = function(self)
        if options.compact then
            -- Button already stretches to fill the row via its own LEFT+RIGHT
            -- anchors; only the open menu (if any) needs repositioning.
            if self.menu:IsShown() then self:LayoutMenu(false) end
            return
        end
        local buttonWidth = min(218, max(145, floor((self:GetWidth() or width) * 0.44)))
        self.button:SetWidth(buttonWidth)
        self.label:ClearAllPoints()
        self.label:SetPoint("LEFT", self, "LEFT", 0, 0)
        self.label:SetPoint("RIGHT", self, "RIGHT", -(buttonWidth + 10), 0)
        if self.menu:IsShown() then self:LayoutMenu(false) end
    end
    row.Refresh = function(self)
        local current = getter()
        self.button.text:SetText(display[current] or tostring(current))
        for _, item in ipairs(self.items) do
            local selected = item.value == current
            item.frame.creshSelected = selected
            item.frame.check:SetText(selected and "*" or "")
            if item.frame.RefreshAppearance then item.frame:RefreshAppearance() end
        end
    end
    self.refreshables[#self.refreshables + 1] = row
    if not options.skipLayout then self:RegisterLayout(row, "full", 1) end
    return row
end

-- Backwards-compatible internal name. All cycle controls now render as dropdowns.
function Settings:CreateCycle(parent, label, getter, setter, values, display, x, y, width, options)
    return self:CreateDropdown(parent, label, getter, setter, values, display, x, y, width, options)
end

function Settings:CreateSlider(parent, label, minValue, maxValue, step, getter, setter, x, y, width, format)
    self.sliderCounter = (self.sliderCounter or 0) + 1
    local row = CreateFrame("Frame", nil, parent, templateName())
    row:SetSize(width, 48)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    backdrop(row, 0.070, 0.081, 0.105, 0.98, 0.14, 0.17, 0.23, 1)

    row.label = font(row, 10, "LEFT")
    row.label:SetPoint("TOPLEFT", row, "TOPLEFT", 9, -6)
    row.label:SetPoint("RIGHT", row, "RIGHT", -92, 0)
    row.label:SetText(label)
    row.value = font(row, 10, "RIGHT")
    row.value:SetPoint("TOPRIGHT", row, "TOPRIGHT", -9, -6)
    row.value:SetWidth(82)

    row.track = CreateFrame("Frame", nil, row, templateName())
    row.track:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 10, 8)
    row.track:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -10, 8)
    row.track:SetHeight(10)
    backdrop(row.track, 0.025, 0.030, 0.040, 1, 0.12, 0.15, 0.20, 1)

    row.fill = row.track:CreateTexture(nil, "ARTWORK")
    row.fill:SetPoint("TOPLEFT", row.track, "TOPLEFT", 2, -2)
    row.fill:SetPoint("BOTTOMLEFT", row.track, "BOTTOMLEFT", 2, 2)
    row.fill:SetWidth(1)

    row.slider = CreateFrame("Slider", nil, row)
    row.slider:SetOrientation("HORIZONTAL")
    row.slider:SetPoint("LEFT", row.track, "LEFT", 5, 0)
    row.slider:SetPoint("RIGHT", row.track, "RIGHT", -5, 0)
    row.slider:SetHeight(18)
    row.slider:SetMinMaxValues(minValue, maxValue)
    row.slider:SetValueStep(step)
    row.slider:EnableMouse(true)
    if row.slider.SetObeyStepOnDrag then row.slider:SetObeyStepOnDrag(true) end
    row.slider:SetThumbTexture("Interface\\Buttons\\WHITE8X8")
    local thumb = row.slider:GetThumbTexture()
    if thumb then thumb:SetSize(11, 18) end

    local function updateVisual(value)
        local ratio = (tonumber(value) or minValue) - minValue
        ratio = ratio / max(0.0001, maxValue - minValue)
        ratio = max(0, min(1, ratio))
        local c = CC.db and CC.db.colors and CC.db.colors.accent or { 0.11, 0.43, 0.95, 1 }
        row.fill:SetColorTexture(c[1], c[2], c[3], 0.92)
        if thumb and thumb.SetColorTexture then thumb:SetColorTexture(min(1, c[1] + 0.18), min(1, c[2] + 0.18), min(1, c[3] + 0.18), 1) end
        local trackWidth = max(1, (row.track:GetWidth() or (row:GetWidth() - 20)) - 4)
        row.fill:SetWidth(max(1, floor(trackWidth * ratio + 0.5)))
    end

    row.slider:SetScript("OnValueChanged", function(_, value)
        value = floor((value / step) + 0.5) * step
        row.value:SetText(format and format(value) or tostring(value))
        updateVisual(value)
        if row.creshRefreshing then return end
        setter(value)
        apply()
    end)
    row.slider:SetScript("OnEnter", function()
        local c = CC.db and CC.db.colors and CC.db.colors.accent or { 0.11, 0.43, 0.95, 1 }
        if row.SetBackdropBorderColor then row:SetBackdropBorderColor(c[1], c[2], c[3], 1) end
    end)
    row.slider:SetScript("OnLeave", function()
        if row.SetBackdropBorderColor then row:SetBackdropBorderColor(0.14, 0.17, 0.23, 1) end
    end)
    row:SetScript("OnSizeChanged", function() updateVisual(row.slider:GetValue()) end)
    row.Refresh = function(self)
        local value = tonumber(getter()) or minValue
        self.creshRefreshing = true
        self.slider:SetValue(value)
        self.creshRefreshing = false
        self.value:SetText(format and format(value) or tostring(value))
        updateVisual(value)
    end
    self.refreshables[#self.refreshables + 1] = row
    self:RegisterLayout(row, "full", 1)
    return row
end

function Settings:CreateColorRow(parent, label, colorGetter, x, y, width, kind, column, customKind)
    local row = CreateFrame("Button", nil, parent, templateName())
    row:SetSize(width, 27)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    backdrop(row, 0.075, 0.086, 0.112, 0.97, 0.13, 0.15, 0.20, 1)
    row.label = font(row, 10, "LEFT")
    row.label:SetPoint("LEFT", row, "LEFT", 8, 0)
    row.label:SetPoint("RIGHT", row, "RIGHT", -48, 0)
    row.label:SetText(label)
    row.swatch = row:CreateTexture(nil, "ARTWORK")
    row.swatch:SetSize(34, 15)
    row.swatch:SetPoint("RIGHT", row, "RIGHT", -7, 0)
    row:SetScript("OnClick", function()
        local color = colorGetter()
        openColorPicker(color, function()
            if customKind == "GUILD" then CC.db.ui.guildThemePreset = "CUSTOM"
            else CC.db.ui.themePreset = "CUSTOM" end
            apply(); Settings:Refresh()
        end)
    end)
    row.Refresh = function(self)
        local c = colorGetter()
        self.swatch:SetColorTexture(c[1] or 1, c[2] or 1, c[3] or 1, 1)
    end
    self.refreshables[#self.refreshables + 1] = row
    self:RegisterLayout(row, kind or "half", column or 1)
    return row
end

local Builder = {}
Builder.__index = Builder

function Settings:NewBuilder(page, title, description)
    local b = setmetatable({ settings = self, page = page, parent = page.canvas, y = -12, nextColumn = 1 }, Builder)
    local heading = font(b.parent, 16, "LEFT")
    heading:SetPoint("TOPLEFT", b.parent, "TOPLEFT", 12, b.y)
    heading:SetText(title)
    b.y = b.y - 25
    if description and description ~= "" then
        local note = font(b.parent, 9, "LEFT")
        note:SetPoint("TOPLEFT", b.parent, "TOPLEFT", 12, b.y)
        note:SetPoint("RIGHT", b.parent, "RIGHT", -12, 0)
        note:SetTextColor(0.58, 0.64, 0.73, 1)
        note:SetJustifyV("TOP")
        note:SetWordWrap(true)
        note:SetText(description)
        local h = max(26, note:GetStringHeight() + 4)
        note:SetHeight(h)
        b.y = b.y - h - 4
    end
    return b
end

function Builder:Flush()
    if self.nextColumn == 2 then
        self.nextColumn = 1
        self.y = self.y - ROW_HEIGHT
    end
end

function Builder:Section(title)
    self:Flush()
    local line = self.parent:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(0.18, 0.21, 0.28, 0.65)
    line:SetPoint("TOPLEFT", self.parent, "TOPLEFT", 12, self.y - 11)
    line:SetPoint("TOPRIGHT", self.parent, "TOPRIGHT", -12, self.y - 11)
    line:SetHeight(1)
    local text = font(self.parent, 10, "LEFT")
    text:SetPoint("TOPLEFT", self.parent, "TOPLEFT", 12, self.y)
    text:SetTextColor(0.48, 0.72, 1.00, 1)
    text:SetText(string.upper(title))
    self.y = self.y - SECTION_ROW_HEIGHT
end

function Builder:HalfToggle(label, getter, setter)
    local col = self.nextColumn
    local row = self.settings:CreateToggle(self.parent, label, getter, setter, 12, self.y, 250, "half", col)
    self.nextColumn = col == 1 and 2 or 1
    if self.nextColumn == 1 then self.y = self.y - ROW_HEIGHT end
    return row
end

function Builder:HalfColor(label, getter, customKind)
    local col = self.nextColumn
    local row = self.settings:CreateColorRow(self.parent, label, getter, 12, self.y, 250, "half", col, customKind)
    self.nextColumn = col == 1 and 2 or 1
    if self.nextColumn == 1 then self.y = self.y - ROW_HEIGHT end
    return row
end

function Builder:Dropdown(label, getter, setter, values, display, options)
    self:Flush()
    local row = self.settings:CreateDropdown(self.parent, label, getter, setter, values, display, 12, self.y, 520, options)
    self.y = self.y - DROPDOWN_ROW_HEIGHT
    return row
end

function Builder:Cycle(label, getter, setter, values, display, options)
    return self:Dropdown(label, getter, setter, values, display, options)
end

function Builder:Slider(label, minValue, maxValue, step, getter, setter, format)
    self:Flush()
    local row = self.settings:CreateSlider(self.parent, label, minValue, maxValue, step, getter, setter, 12, self.y, 520, format)
    self.y = self.y - SLIDER_ROW_HEIGHT
    return row
end

function Builder:Note(text)
    self:Flush()
    local note = font(self.parent, 9, "LEFT")
    note:SetPoint("TOPLEFT", self.parent, "TOPLEFT", 12, self.y)
    note:SetPoint("RIGHT", self.parent, "RIGHT", -12, 0)
    note:SetTextColor(0.58, 0.64, 0.73, 1)
    note:SetJustifyV("TOP")
    note:SetWordWrap(true)
    note:SetText(text)
    local h = max(24, note:GetStringHeight() + 4)
    note:SetHeight(h)
    self.y = self.y - h - 5
    return note
end

function Builder:Buttons(items)
    self:Flush()
    local group = CreateFrame("Frame", nil, self.parent)
    group:SetPoint("TOPLEFT", self.parent, "TOPLEFT", 12, self.y)
    group:SetSize(520, 27)
    group.buttons = {}
    group.preferred = {}
    for index, item in ipairs(items) do
        local preferred = item[3] or 140
        local control = button(group, item[1], preferred, 27, item[2])
        group.buttons[index] = control
        group.preferred[index] = preferred
    end
    group.Relayout = function(selfGroup)
        local count = #selfGroup.buttons
        if count == 0 then return end
        local gap = 7
        local width = max(120, selfGroup:GetWidth() or 520)
        local available = max(80 * count, width - gap * (count - 1))
        local preferredTotal = 0
        for _, preferred in ipairs(selfGroup.preferred) do preferredTotal = preferredTotal + preferred end
        local previous
        local used = 0
        for index, control in ipairs(selfGroup.buttons) do
            local buttonWidth
            if preferredTotal + gap * (count - 1) <= width then
                buttonWidth = selfGroup.preferred[index]
            elseif index == count then
                buttonWidth = max(72, available - used)
            else
                buttonWidth = max(72, floor(available * selfGroup.preferred[index] / max(1, preferredTotal)))
            end
            control:SetWidth(buttonWidth)
            control:ClearAllPoints()
            if previous then control:SetPoint("LEFT", previous, "RIGHT", gap, 0)
            else control:SetPoint("LEFT", selfGroup, "LEFT", 0, 0) end
            previous = control
            used = used + buttonWidth
        end
    end
    self.settings:RegisterLayout(group, "full", 1)
    group:Relayout()
    self.y = self.y - BUTTON_ROW_HEIGHT
    return group
end

local NOTIFICATION_TABLE_ROW_HEIGHT = 28
local NOTIFICATION_TABLE_ROW_GAP    = 4
local NOTIFICATION_TABLE_TOGGLE_W   = 26

-- Compact "show / name / sound / priority" table for the Notifications
-- page's per-category rows -- replaces a tall Section+HalfToggle+Dropdown+
-- Dropdown+Slider+Note stack repeated once per category with one scannable
-- row per category. rows is an array of
-- { title, getEnabled, setEnabled, soundGetter, soundSetter, soundValues,
--   priorityGetter, prioritySetter }.
function Builder:NotificationTable(rows)
    self:Flush()
    local S = self.settings

    local header = CreateFrame("Frame", nil, self.parent)
    header:SetPoint("TOPLEFT", self.parent, "TOPLEFT", 12, self.y)
    header:SetSize(520, 16)
    local headerShow = font(header, 8, "LEFT")
    headerShow:SetText("SHOW")
    headerShow:SetTextColor(0.56, 0.61, 0.69, 1)
    local headerName = font(header, 8, "LEFT")
    headerName:SetText("NOTIFICATION")
    headerName:SetTextColor(0.56, 0.61, 0.69, 1)
    local headerSound = font(header, 8, "LEFT")
    headerSound:SetText("SOUND")
    headerSound:SetTextColor(0.56, 0.61, 0.69, 1)
    local headerPriority = font(header, 8, "LEFT")
    headerPriority:SetText("PRIORITY")
    headerPriority:SetTextColor(0.56, 0.61, 0.69, 1)
    self.y = self.y - 16 - 4

    local rowCount = #rows
    local group = CreateFrame("Frame", nil, self.parent)
    group:SetPoint("TOPLEFT", self.parent, "TOPLEFT", 12, self.y)
    group:SetSize(520, rowCount * NOTIFICATION_TABLE_ROW_HEIGHT + max(0, rowCount - 1) * NOTIFICATION_TABLE_ROW_GAP)
    group.rows = {}

    for _, entry in ipairs(rows) do
        local row = CreateFrame("Frame", nil, group)
        row:SetHeight(NOTIFICATION_TABLE_ROW_HEIGHT)
        backdrop(row, 0.070, 0.081, 0.105, 0.9, 0.13, 0.15, 0.20, 1)

        row.toggle = S:CreateCompactToggle(row, entry.getEnabled, entry.setEnabled, 20)
        row.toggle:SetPoint("LEFT", row, "LEFT", 4, 0)

        row.name = font(row, 10, "LEFT")
        row.name:SetText(entry.title)

        row.sound = S:CreateDropdown(row, "", entry.soundGetter, entry.soundSetter, entry.soundValues, SOUND_DISPLAY,
            0, 0, 120, { compact = true, skipLayout = true })
        row.priority = S:CreateDropdown(row, "", entry.priorityGetter, entry.prioritySetter,
            NOTIFICATION_PRIORITY_VALUES, NOTIFICATION_PRIORITY_DISPLAY, 0, 0, 110, { compact = true, skipLayout = true })

        row.Relayout = function(selfRow)
            local width = max(360, selfRow:GetWidth() or 520)
            local gap = 6
            local remaining = width - NOTIFICATION_TABLE_TOGGLE_W - gap * 3
            local soundW = max(90, floor(remaining * 0.34))
            local priorityW = max(90, floor(remaining * 0.32))
            local nameW = max(70, remaining - soundW - priorityW)

            selfRow.name:ClearAllPoints()
            selfRow.name:SetPoint("LEFT", selfRow, "LEFT", NOTIFICATION_TABLE_TOGGLE_W + gap, 0)
            selfRow.name:SetWidth(nameW)

            selfRow.sound:ClearAllPoints()
            selfRow.sound:SetPoint("LEFT", selfRow.name, "RIGHT", gap, 0)
            selfRow.sound:SetSize(soundW, 24)
            selfRow.sound:Relayout()

            selfRow.priority:ClearAllPoints()
            selfRow.priority:SetPoint("LEFT", selfRow.sound, "RIGHT", gap, 0)
            selfRow.priority:SetSize(priorityW, 24)
            selfRow.priority:Relayout()
        end

        group.rows[#group.rows + 1] = row
    end

    header.Relayout = function(selfHeader)
        local width = max(360, selfHeader:GetWidth() or 520)
        local gap = 6
        local remaining = width - NOTIFICATION_TABLE_TOGGLE_W - gap * 3
        local soundW = max(90, floor(remaining * 0.34))
        local priorityW = max(90, floor(remaining * 0.32))
        local nameW = max(70, remaining - soundW - priorityW)

        headerShow:ClearAllPoints()
        headerShow:SetPoint("LEFT", selfHeader, "LEFT", 4, 0)
        headerName:ClearAllPoints()
        headerName:SetPoint("LEFT", selfHeader, "LEFT", NOTIFICATION_TABLE_TOGGLE_W + gap, 0)
        headerSound:ClearAllPoints()
        headerSound:SetPoint("LEFT", headerName, "LEFT", nameW + gap, 0)
        headerPriority:ClearAllPoints()
        headerPriority:SetPoint("LEFT", headerSound, "LEFT", soundW + gap, 0)
    end

    group.Relayout = function(selfGroup)
        local previous
        for _, row in ipairs(selfGroup.rows) do
            row:ClearAllPoints()
            row:SetWidth(selfGroup:GetWidth() or 520)
            if previous then row:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -NOTIFICATION_TABLE_ROW_GAP)
            else row:SetPoint("TOPLEFT", selfGroup, "TOPLEFT", 0, 0) end
            if row.Relayout then row:Relayout() end
            previous = row
        end
    end

    S:RegisterLayout(header, "full", 1)
    S:RegisterLayout(group, "full", 1)
    header:Relayout()
    group:Relayout()
    self.y = self.y - group:GetHeight() - 8
    return group
end

-- Phase 6: a clickable header that shows/hides a body of uncommon controls.
-- Starts collapsed. The body is built immediately (not lazily) so its full
-- expanded height can be reserved in the page's layout up front -- toggling
-- is then a pure show/hide with no reflow of controls placed after it.
-- Intended for a small number of rarely-used controls (e.g. diagnostic
-- buttons), not as a general pagination mechanism.
function Builder:CollapsibleSection(title, buildFn)
    self:Flush()
    local header = CreateFrame("Button", nil, self.parent, templateName())
    header:SetPoint("TOPLEFT", self.parent, "TOPLEFT", 12, self.y)
    header:SetPoint("TOPRIGHT", self.parent, "TOPRIGHT", -12, self.y)
    header:SetHeight(SECTION_ROW_HEIGHT)
    local label = font(header, 10, "LEFT")
    label:SetAllPoints()
    header.expanded = false
    local function updateHeaderText()
        label:SetTextColor(0.48, 0.72, 1.00, 1)
        label:SetText((header.expanded and "[-] " or "[+] ") .. string.upper(title))
    end
    updateHeaderText()
    self.y = self.y - SECTION_ROW_HEIGHT

    local body = CreateFrame("Frame", nil, self.parent)
    body:SetPoint("TOPLEFT", self.parent, "TOPLEFT", 0, self.y)
    body:SetPoint("TOPRIGHT", self.parent, "TOPRIGHT", 0, self.y)
    local bodyBuilder = setmetatable({ settings = self.settings, page = self.page, parent = body, y = -4, nextColumn = 1 }, Builder)
    buildFn(bodyBuilder)
    bodyBuilder:Flush()
    local bodyHeight = max(1, -bodyBuilder.y)
    body:SetHeight(bodyHeight)
    body:Hide()
    header:SetScript("OnClick", function()
        header.expanded = not header.expanded
        updateHeaderText()
        body:SetShown(header.expanded)
    end)
    self.y = self.y - bodyHeight - 4
    return header
end

-- Delegates to Settings:ConfirmAction so page-content build(builder)
-- callbacks (CreshChat's own and every product provider's) never need to
-- reach past the Builder for a confirmation dialog.
function Builder:ConfirmAction(message, onConfirm)
    return self.settings:ConfirmAction(message, onConfirm)
end

function Builder:Finish()
    self:Flush()
    self.parent:SetHeight(max(420, -self.y + 18))
end

local function pct(value) return floor(value * 100 + 0.5) .. "%" end
local function px(value) return floor(value + 0.5) .. " px" end
local function sec(value) return string.format("%.1f sec", value) end

function Settings:BuildGeneral(page)
    local b = self:NewBuilder(page, "General", "Core behaviour, launcher controls, portraits, message density and character profiles.")
    b:Section("Quick setup profile")
    b:Dropdown("Profile", function() return CC.db.ui.qualityProfile or "BALANCED" end,
        function(v) if CC.Quality then CC.Quality:ApplyProfile(v) else CC.db.ui.qualityProfile = v end end,
        PROFILE_VALUES, PROFILE_DISPLAY)
    b:Note("Profiles change related options together without deleting messages, colours or saved window positions. You can still fine-tune every setting below.")
    b:Section("Core")
    b:HalfToggle("Disable Blizzard chat visually", function() return CC.db.hideBlizzard end, function(v) CC.db.hideBlizzard = v; CC:ApplyBlizzardChatVisibility() end)
    b:HalfToggle("Show floating C launcher", function() return CC.db.bubbleVisible end, function(v) CC.db.bubbleVisible = v end)
    b:HalfToggle("Enable Combat Log capture", function() return CC.db.combatEnabled end, function(v) CC.db.combatEnabled = v end)
    b:HalfToggle("Enable CreshChat voice calls", function() return not CC.db.voice or CC.db.voice.enabled ~= false end, function(v) CC.db.voice=CC.db.voice or {}; CC.db.voice.enabled=v; if not v and CC.Voice then CC.Voice:EndCall(true) end end)
    b:Note("Voice call requests use addon-to-addon handshakes and Blizzard voice services. Both players need CreshChat; client/account voice availability is still controlled by WoW.")
    b:HalfToggle("Automatic window arrangement", function() return CC.db.ui.autoArrange ~= false end, function(v) CC.db.ui.autoArrange = v end)
    b:HalfToggle("Shift-drag window resizing", function() return CC.db.ui.shiftResize ~= false end, function(v) CC.db.ui.shiftResize = v end)
    b:HalfToggle("Compact navigation", function() return CC.db.ui.compactNavigation ~= false end, function(v) CC.db.ui.compactNavigation = v end)

    b:Section("Launcher")
    b:Dropdown("Default launcher action", function() return CC.db.ui.launcherDefault or "LAST" end, function(v) CC.db.ui.launcherDefault = v end,
        { "LAST", "CHAT", "GAMES", "ACHIEVEMENTS", "PROGRESS", "CRESHQUEST", "SETTINGS" },
        { LAST = "Last used", CHAT = "Chat", GAMES = "Games", ACHIEVEMENTS = "Achievements", PROGRESS = "Progress Hub", CRESHQUEST = "CreshQuest", SETTINGS = "Settings" })
    b:Note("Left-click on C opens this destination. If it's disabled in Modules, CreshChat falls back to the first enabled destination automatically. Shift+click always opens Settings.")
    b:Dropdown("Launcher buttons", function() return CC.db.ui.launcherMode or "SINGLE" end, function(v) CC.db.ui.launcherMode = v end,
        { "SINGLE", "EXPANDED" }, { SINGLE = "C only", EXPANDED = "C + quick buttons" })
    b:Dropdown("Launcher orientation", function() return CC.UI:GetLauncherOrientation() end, function(v) CC.UI:SetLauncherOrientation(v) end,
        { "HORIZONTAL", "VERTICAL" }, { HORIZONTAL = "Horizontal", VERTICAL = "Vertical" })
    b:HalfToggle("Whisper quick button", function() return CC.db.ui.showWhisperButton == true end, function(v) CC.db.ui.showWhisperButton = v end)
    b:HalfToggle("General quick button", function() return CC.db.ui.showGeneralButton == true end, function(v) CC.db.ui.showGeneralButton = v end)
    b:HalfToggle("Combat quick button", function() return CC.db.ui.showCombatButton == true end, function(v) CC.db.ui.showCombatButton = v end)
    b:HalfToggle("Group consecutive messages", function() return CC.db.ui.groupedMessages ~= false end, function(v) CC.db.ui.groupedMessages = v end)

    -- Phase 6 bug fix: this used to gate on `CC.ProgressHub`, a field that is
    -- never assigned anywhere in CreshChat -- the button silently never
    -- rendered. CreshCollect's Progress Hub is reached through the Suite
    -- service every other entry point already uses (Core.lua/Launcher.lua).
    local progressHubService = _G.CreshSuite and _G.CreshSuite:GetService("OpenProgressHub")
    if progressHubService then
        b:Section("Progress Hub")
        b:Note("Exploration, quest and combat stats collected by CreshCollect live in their own window, not here.")
        b:Buttons({
            { "OPEN PROGRESS HUB", function() progressHubService() end, 160 },
        })
    end

    b:Section("Portraits and scale")
    b:HalfToggle("Show player portraits", function() return CC.db.ui.showPortraits ~= false end, function(v) CC.db.ui.showPortraits = v end)
    b:Dropdown("Portrait style", function() return CC.db.ui.portraitStyle or "CLASS" end, function(v) CC.db.ui.portraitStyle = v end,
        { "CLASS", "2D", "3D" }, { CLASS = "Class + race", ["2D"] = "2D portrait", ["3D"] = "3D model" })
    b:Slider("Overall UI size", 0.70, 1.50, 0.05, function() return CC.db.ui.scale or 1 end, function(v) CC.db.ui.scale = v end, pct)
    b:Note("This scales the console, Games drawer, Settings, pop-outs and solo/multiplayer game windows. Oversized windows are automatically limited to the visible screen so controls cannot hang off an edge.")
    b:Slider("Message text scale", 0.80, 1.35, 0.05, function() return CC.db.ui.messageScale or 1 end, function(v) CC.db.ui.messageScale = v end, pct)
    b:Slider("Player icon size", 22, 44, 2, function() return CC.db.ui.iconSize or 26 end, function(v) CC.db.ui.iconSize = v end, px)

    -- Merged in from the old standalone "Profiles" page: which character's
    -- interface configuration is active, and copying it to/from an alt.
    local currentKey = CC.GetCurrentCharacterProfileKey and CC:GetCurrentCharacterProfileKey() or "Current character"
    local currentName = CC.GetCharacterProfileDisplay and CC:GetCharacterProfileDisplay(currentKey) or currentKey
    local values, display = {}, {}
    if CC.GetCharacterProfileOptions then values, display = CC:GetCharacterProfileOptions(true) end

    b:Section("Character profiles")
    b:Note("Active profile: " .. tostring(currentName) .. ". Game XP, Battle Pass progress, Cresh Coins, unlocks and achievements are account-wide -- only interface appearance and placement is per-character.")
    if #values > 0 then
        if not self.profileCopySelection or not display[self.profileCopySelection] then self.profileCopySelection = values[1] end
        b:Dropdown("Source character", function() return Settings.profileCopySelection or values[1] end,
            function(v) Settings.profileCopySelection = v end, values, display)
        b:Buttons({
            { "COPY UI + LAYOUT", function()
                local source = Settings.profileCopySelection
                local sourceLabel = tostring(display[source] or source)
                b:ConfirmAction(
                    "Replace this character's theme, colours, scale, console, launcher, window sizes/positions, cards, sounds and channel colours with " .. sourceLabel .. "'s?\n\nThis cannot be undone (account-wide progression is never affected).",
                    function()
                        if source and CC.CopyUIFromCharacterProfile and CC:CopyUIFromCharacterProfile(source) then
                            local saved = CC.db.sizes and CC.db.sizes.settings
                            if Settings.frame and saved then
                                Settings.frame:SetSize(tonumber(saved.width) or Settings.frame:GetWidth(), tonumber(saved.height) or Settings.frame:GetHeight())
                            end
                            Settings:Relayout()
                            Settings:Refresh()
                            if CC.Print then CC:Print("Copied interface and window placement from " .. sourceLabel .. ".") end
                        elseif CC.Print then
                            CC:Print("That character profile could not be copied.")
                        end
                    end)
            end, 180 },
        })
    else
        b:Note("No other character profiles are available yet. Log into an alt once to create its profile, then return here to copy an interface setup.")
    end
    b:Note("Direct whispers and Battle.net conversations are shared across your characters. Guild, General, Combat and quest conversations remain session-only and clear on login or reload.")

    b:Finish()
end

function Settings:BuildWindows(page)
    local b = self:NewBuilder(page, "Windows", "C Dock and Composer geometry/motion, other window/pop-out behaviour, and console roster visibility.")
    b:Section("Dock and composer dimensions")
    b:Slider("Total C + command width", 320, 720, 10, function() return CC.db.ui.sharedDockWidth or 470 end,
        function(v) if UI.SetSharedDockWidth then UI:SetSharedDockWidth(v) else CC.db.ui.sharedDockWidth = v end end, px)
    b:Slider("C button width", 38, 64, 2, function() return CC.db.ui.dockButtonWidth or 46 end,
        function(v) CC.db.ui.dockButtonWidth = v; if UI.ApplyConnectedDockDimensions then UI:ApplyConnectedDockDimensions() end end, px)
    b:Slider("Composer scale", 0.70, 1.50, 0.05, function() return CC.db.ui.composerScale or 1 end, function(v) CC.db.ui.composerScale = v end, pct)
    b:Dropdown("Default composer destination", function() return CC.db.quickChannel or "GENERAL" end,
        function(v) CC.db.quickChannel = v; if UI.SetQuickDestination then UI:SetQuickDestination(v) end end,
        { "GENERAL", "GUILD", "PARTY", "RAID", "INSTANCE", "SAY" },
        { GENERAL = "General", GUILD = "Guild", PARTY = "Party", RAID = "Raid", INSTANCE = "Instance", SAY = "Say" })

    b:Section("Dock and composer behaviour")
    b:HalfToggle("Typing opens main history", function() return CC.db.ui.openMainOnType ~= false end, function(v) CC.db.ui.openMainOnType = v end)
    b:HalfToggle("C opens composer + main", function() return CC.db.ui.launcherOpensComposer ~= false end, function(v) CC.db.ui.launcherOpensComposer = v end)
    b:HalfToggle("Composer attached to C", function() return CC.db.ui.composerAttached ~= false end, function(v) CC.db.ui.composerAttached = v end)
    b:HalfToggle("Lock composer movement", function() return CC.db.ui.composerLocked == true end, function(v) CC.db.ui.composerLocked = v end)
    b:HalfToggle("Show composer portrait", function() return CC.db.ui.composerShowPortrait ~= false end, function(v) CC.db.ui.composerShowPortrait = v end)
    b:HalfToggle("Show SEND button", function() return CC.db.ui.composerShowSend == true end, function(v) CC.db.ui.composerShowSend = v end)
    b:HalfToggle("Close composer after send", function() return CC.db.ui.composerCloseAfterSend ~= false end, function(v) CC.db.ui.composerCloseAfterSend = v end)

    b:Section("Motion")
    b:Dropdown("Composer reveal", function() return CC.db.ui.composerAnimation or "SLIDE_DOCK" end, function(v) CC.db.ui.composerAnimation = v end, ANIM_VALUES, ANIM_DISPLAY)
    b:Dropdown("Main history reveal", function() return CC.db.ui.dockAnimation or "SLIDE_DOCK" end, function(v) CC.db.ui.dockAnimation = v end, ANIM_VALUES, ANIM_DISPLAY)
    b:Dropdown("Other window animation", function() return CC.db.ui.windowAnimation or "SLIDE_LEFT" end, function(v) CC.db.ui.windowAnimation = v end, ANIM_VALUES, ANIM_DISPLAY)
    -- Phase 6: this single slider used to exist twice (here and again on the
    -- old Notifications/Alerts page) writing the exact same SavedVariables
    -- key under two different labels. One control now; Notifications carries
    -- a cross-reference note instead, mirroring how Guild already documents
    -- its Notifications-page overlap.
    b:Slider("Animation duration (dock, composer and notification cards)", 0.08, 0.55, 0.01,
        function() return CC.db.ui.animationDuration or 0.20 end, function(v) CC.db.ui.animationDuration = v end, sec)
    b:Note("Detached pop-outs are independent: they never snap to the C dock, steal Enter, or move again after you place them.")
    b:Buttons({
        { "RESET DOCK", function()
            CC.db.positions.composer = { point = "BOTTOMLEFT", relativePoint = "BOTTOMLEFT", x = 72, y = 92 }
            if UI.quickInput then UI.quickInput.creshPositionApplied = false; UI:PositionQuickInput(true) end
        end, 128 },
        { "TEST DOCK", function() if UI.CloseDockChat then UI:CloseDockChat() end; if UI.OpenDockChat then UI:OpenDockChat() end end, 120 },
    })

    b:Section("Pop-out style")
    b:Dropdown("Message style", function() return CC.db.ui.popoutStyle or "NORMAL" end,
        function(v) CC.db.ui.popoutStyle = v; if UI.RefreshPopoutStyles then UI:RefreshPopoutStyles() end end,
        { "NORMAL", "COMPACT" }, { NORMAL = "Normal messenger bubbles", COMPACT = "Compact wrapped table" })
    b:Slider("Pop-out width", 300, 620, 10, function() return CC.db.ui.popoutWidth or 400 end,
        function(v) if UI.SetPopoutWidth then UI:SetPopoutWidth(v) else CC.db.ui.popoutWidth = v end end, px)
    b:Slider("Visible message rows", 4, 10, 1, function() return CC.db.ui.popoutRows or 6 end, function(v) CC.db.ui.popoutRows = v end, function(v) return floor(v + 0.5) .. " rows" end)
    b:Slider("Compact row height", 36, 68, 1, function() return CC.db.ui.popoutRowHeight or 44 end,
        function(v) CC.db.ui.popoutRowHeight = v; if UI.RefreshPopoutStyles then UI:RefreshPopoutStyles() end end, px)
    b:HalfToggle("Show native command field", function() return CC.db.ui.popoutShowCommand ~= false end, function(v) CC.db.ui.popoutShowCommand = v end)
    b:HalfToggle("Fade inactive pop-outs", function() return CC.db.ui.popoutFade == true end, function(v) CC.db.ui.popoutFade = v end)
    b:Slider("Pop-out fade delay", 1, 15, 1, function() return CC.db.ui.popoutFadeDelay or 4 end, function(v) CC.db.ui.popoutFadeDelay = v end, sec)
    b:Slider("Faded opacity", 0.10, 0.70, 0.05, function() return CC.db.ui.popoutFadeAlpha or 0.22 end, function(v) CC.db.ui.popoutFadeAlpha = v end, pct)
    b:Note("Normal uses the same wrapped messenger bubbles as the main chat. Compact keeps the table layout but uses incoming/outgoing bubble colours and wraps long text. C always opens or closes the connected dock, even with pop-outs open.")

    local function setRosterVisibility(key, value)
        CC.db.ui[key] = value and true or false
        if UI.RefreshConversationList then UI:RefreshConversationList() end
    end
    b:Section("Console roster cards")
    b:HalfToggle("Start with roster collapsed", function() return CC.db.ui.rosterCollapsed == true end,
        function(v) if UI.SetRosterCollapsed then UI:SetRosterCollapsed(v) else CC.db.ui.rosterCollapsed = v and true or false end end)
    b:HalfToggle("Game Friends: online", function() return CC.db.ui.showGameFriendsOnline ~= false end, function(v) setRosterVisibility("showGameFriendsOnline", v) end)
    b:HalfToggle("Game Friends: offline", function() return CC.db.ui.showGameFriendsOffline ~= false end, function(v) setRosterVisibility("showGameFriendsOffline", v) end)
    b:HalfToggle("Battle.net: online", function() return CC.db.ui.showBattleNetFriendsOnline ~= false end, function(v) setRosterVisibility("showBattleNetFriendsOnline", v) end)
    b:HalfToggle("Battle.net: offline", function() return CC.db.ui.showBattleNetFriendsOffline ~= false end, function(v) setRosterVisibility("showBattleNetFriendsOffline", v) end)
    b:HalfToggle("Guild members: online", function() return CC.db.ui.showGuildMembersOnline ~= false end, function(v) setRosterVisibility("showGuildMembersOnline", v) end)
    b:HalfToggle("Guild members: offline", function() return CC.db.ui.showGuildMembersOffline ~= false end, function(v) setRosterVisibility("showGuildMembersOffline", v) end)
    b:Note("These switches control the name cards shown beside chat. Friends use only Blizzard's actual Game Friends and Battle.net lists; Guild members remain separate.")
    b:Finish()
end

function Settings:BuildAlerts(page)
    local b = self:NewBuilder(page, "Notifications", "Control every CreshChat card popup from one place: visibility, priority, animation, placement, sound and volume.")

    b:Section("Master controls")
    b:HalfToggle("Enable all card popups", function() return CC.db.ui.notificationCardsEnabled ~= false end,
        function(v)
            CC.db.ui.notificationCardsEnabled = v and true or false
            if not v then
                while UI.toasts and #UI.toasts > 0 do if UI.DismissToast then UI:DismissToast(UI.toasts[#UI.toasts], true) else break end end
                while UI.secondaryToasts and #UI.secondaryToasts > 0 do if UI.DismissToast then UI:DismissToast(UI.secondaryToasts[#UI.secondaryToasts], true) else break end end
            end
            if UI.RefreshLauncherNotification then UI:RefreshLauncherNotification() end
        end)
    b:HalfToggle("All notification sounds", function() return CC.db.sounds.master ~= false end, function(v) CC.db.sounds.master = v end)
    b:HalfToggle("Animated C notification outline", function() return CC.db.ui.launcherNotificationPulse ~= false end,
        function(v) CC.db.ui.launcherNotificationPulse = v; if UI.RefreshLauncherNotification then UI:RefreshLauncherNotification() end end)
    b:HalfToggle("Use CreshChat party invite only", function() return CC.db.ui.replacePartyInvitePopup == true end,
        function(v)
            CC.db.ui.replacePartyInvitePopup = v
            if v and CC.state.partyInvitePending and CC.SuppressBlizzardPartyInvitePopups then CC:SuppressBlizzardPartyInvitePopups()
            elseif not v and CC.RestoreBlizzardPartyInvitePopups then CC:RestoreBlizzardPartyInvitePopups() end
        end)
    b:Note("Card visibility and notification sounds are independent. Disabling cards hides their popup and launcher glow, while each category's Sound control still decides whether audio plays. Party invitations fall back to Blizzard's normal invitation window when their card type is disabled.")

    b:Section("Animation and placement")
    b:Dropdown("Overall card animation", function() return CC.db.ui.toastAnimation or "FAN_UP" end,
        function(v) CC.db.ui.toastAnimation = v end, NOTIFICATION_ANIMATION_VALUES, ANIM_DISPLAY)
    b:Note("Animation speed is shared with the C dock and composer -- adjust it from Windows.")
    b:Dropdown("Card anchor", function() return CC.db.ui.cardLocation or "DOCK" end, function(v) CC.db.ui.cardLocation = v; if UI.RepositionToasts then UI:RepositionToasts() end end,
        { "DOCK", "MAIN", "SCREEN", "CUSTOM" }, { DOCK = "Attached to C", MAIN = "Above main chat", SCREEN = "Screen grid", CUSTOM = "Custom right-drag" })
    b:Dropdown("Horizontal position", function() return CC.db.ui.cardHorizontal or "LEFT" end, function(v) CC.db.ui.cardHorizontal = v; CC.db.ui.cardLocation = "SCREEN"; if UI.RepositionToasts then UI:RepositionToasts() end end,
        { "LEFT", "CENTER", "RIGHT" }, { LEFT = "Left", CENTER = "Middle", RIGHT = "Right" })
    b:Dropdown("Vertical position", function() return CC.db.ui.cardVertical or "BOTTOM" end, function(v) CC.db.ui.cardVertical = v; CC.db.ui.cardLocation = "SCREEN"; if UI.RepositionToasts then UI:RepositionToasts() end end,
        { "TOP", "MIDDLE", "BOTTOM" }, { TOP = "Top", MIDDLE = "Middle", BOTTOM = "Bottom" })
    b:Dropdown("Main-card stack", function() return CC.db.ui.cardStack or "UP" end, function(v) CC.db.ui.cardStack = v; if UI.RepositionToasts then UI:RepositionToasts() end end,
        { "UP", "DOWN" }, { UP = "Stack upward", DOWN = "Stack downward" })
    b:Dropdown("Slide-out direction", function() return CC.db.ui.notificationSlideDirection or "BOTTOM" end, function(v) CC.db.ui.notificationSlideDirection = v; if UI.RepositionToasts then UI:RepositionToasts() end end,
        { "TOP", "BOTTOM", "LEFT", "RIGHT" }, { TOP = "Above the main card", BOTTOM = "Below the main card", LEFT = "Left of the main card", RIGHT = "Right of the main card" })

    b:Section("Card size and timing")
    b:Slider("Normal slide-out time", 3, 30, 1, function() return CC.db.ui.priorityCardDuration or 10 end, function(v) CC.db.ui.priorityCardDuration = v; CC.db.alertDuration = v end, sec)
    b:Slider("Full-size main-card time", 2, 20, 1, function() return CC.db.ui.secondaryCardDuration or 6 end, function(v) CC.db.ui.secondaryCardDuration = v end, sec)
    b:Slider("Card width", 230, 440, 10, function() return CC.db.ui.cardWidth or 300 end, function(v) CC.db.ui.cardWidth = v; if UI.RepositionToasts then UI:RepositionToasts() end end, px)
    b:Slider("Card height", 56, 104, 2, function() return CC.db.ui.cardHeight or 68 end, function(v) CC.db.ui.cardHeight = v; if UI.RepositionToasts then UI:RepositionToasts() end end, px)
    b:Slider("Overall card scale", 0.65, 1.50, 0.05, function() return CC.db.ui.notificationScale or CC.db.ui.cardScale or 0.95 end, function(v) CC.db.ui.notificationScale = v; CC.db.ui.cardScale = v; if UI.RepositionToasts then UI:RepositionToasts() end end, pct)
    b:Slider("Stack spacing", 0, 16, 1, function() return CC.db.ui.cardSpacing or 6 end, function(v) CC.db.ui.cardSpacing = v; if UI.RepositionToasts then UI:RepositionToasts() end end, px)
    b:Slider("Maximum slide-outs", 1, 10, 1, function() return CC.db.ui.cardMaxVisible or 6 end, function(v) CC.db.ui.cardMaxVisible = v end, function(v) return floor(v + 0.5) end)
    b:Slider("Maximum main cards", 1, 8, 1, function() return CC.db.ui.secondaryCardMaxVisible or 4 end, function(v) CC.db.ui.secondaryCardMaxVisible = v end, function(v) return floor(v + 0.5) end)
    b:Slider("Card accent thickness", 2, 6, 1, function() return CC.db.ui.notificationLineHeight or 3 end,
        function(v) CC.db.ui.notificationLineHeight = v; if UI.RepositionToasts then UI:RepositionToasts() end end, px)
    b:Slider("Compact card width", 0.72, 0.96, 0.02, function() return CC.db.ui.secondaryCardWidthRatio or 0.88 end,
        function(v) CC.db.ui.secondaryCardWidthRatio = v; if UI.RepositionToasts then UI:RepositionToasts() end end, pct)
    b:Slider("Compact card height", 0.62, 0.92, 0.02, function() return CC.db.ui.secondaryCardHeightRatio or 0.80 end,
        function(v) CC.db.ui.secondaryCardHeightRatio = v; if UI.RepositionToasts then UI:RepositionToasts() end end, pct)
    b:Slider("Dock whisper preview width", 140, 280, 10, function() return CC.db.ui.dockWhisperWidth or 190 end,
        function(v) CC.db.ui.dockWhisperWidth = v; if UI.PositionWhisperDockAlert then UI:PositionWhisperDockAlert() end end, px)
    b:Slider("Dock whisper preview time", 3, 15, 1, function() return CC.db.ui.dockWhisperDuration or 6 end,
        function(v) CC.db.ui.dockWhisperDuration = v end, sec)
    b:HalfToggle("Lock card position", function() return CC.db.ui.cardLocked == true end, function(v) CC.db.ui.cardLocked = v end)
    b:HalfToggle("Merge repeat whispers", function() return CC.db.ui.cardCoalesce ~= false end, function(v) CC.db.ui.cardCoalesce = v end)
    b:HalfToggle("Whisper preview chip from C", function() return CC.db.ui.showDockWhisperAlert ~= false end, function(v) CC.db.ui.showDockWhisperAlert = v; if not v and UI.DismissWhisperDockAlert then UI:DismissWhisperDockAlert(true) end end)

    local sections = {
        { "Whispers", "whisper", "WHISPER", "CRESH_CRYSTAL_01" },
        { "Guild", "guild", "GUILD", "CRESH_SOFT_BELL_02" },
        { "Party invitations", "partyInvite", "PARTY_INVITE", "CRESH_ARCANE_02" },
        { "Party messages", "partyMessage", "PARTY_MESSAGE", "CRESH_WOOD_TICK_02" },
        { "Public mentions", "mentions", "GENERAL", "CRESH_WOOD_TICK_02" },
        { "Friends", "friends", "FRIEND", "CRESH_SOFT_BELL_01" },
        { "Quest dialogue", "quest", "QUEST", "CRESH_SOFT_BELL_04" },
        { "System", "system", "SYSTEM", "OFF" },
        { "Games and rewards", "game", "GAME", "COIN" },
    }
    CC.db.notificationPriorities = CC.db.notificationPriorities or {}
    CC.db.soundChoices = CC.db.soundChoices or {}
    CC.db.soundVolumes = CC.db.soundVolumes or {}

    -- Bug-fix round: replaces the old tall Section+HalfToggle+Dropdown+
    -- Dropdown+Slider+Note stack repeated once per category with one
    -- compact show/name/sound/priority row per category.
    b:Section("Notification categories")
    local tableRows = {}
    for _, item in ipairs(sections) do
        local title, key, kind, fallbackSound = item[1], item[2], item[3], item[4]
        tableRows[#tableRows + 1] = {
            title = title,
            getEnabled = function() return CC.db.notifications[key] ~= false end,
            setEnabled = function(v)
                CC.db.notifications[key] = v and true or false
                if key == "system" then CC.db.ui.showSystemCards = v and true or false end
                if not v and UI.DismissToast and CC.GetNotificationKey then
                    for _, list in ipairs({ UI.toasts or {}, UI.secondaryToasts or {} }) do
                        for index = #list, 1, -1 do
                            local toast = list[index]
                            if CC:GetNotificationKey(toast.kind or toast.channel) == key then UI:DismissToast(toast, true) end
                        end
                    end
                end
                if UI.RefreshLauncherNotification then UI:RefreshLauncherNotification() end
            end,
            soundGetter = function() return CC.db.soundChoices[key] or fallbackSound end,
            soundSetter = function(v) chooseSound(key, kind, v) end,
            soundValues = SOUND_VALUES[key] or ALL_SOUND_VALUES,
            priorityGetter = function() return CC.GetNotificationPriority and CC:GetNotificationPriority(kind) or (CC.db.notificationPriorities[key] or "NORMAL") end,
            prioritySetter = function(v)
                if CC.SetNotificationPriority then CC:SetNotificationPriority(kind, v) else CC.db.notificationPriorities[key] = v end
                if UI.RepositionToasts then UI:RepositionToasts() end
            end,
        }
    end
    b:NotificationTable(tableRows)
    b:Note("Per-category sound volume was simplified out of this table -- set a category's Sound to OFF to mute it entirely. Existing per-category volumes are unchanged and still apply to whichever sound plays.")

    b:Section("Category-specific options")
    b:Dropdown("Guild card trigger", function() return CC.db.guildAlerts or "all" end, function(v) CC.db.guildAlerts = v end,
        { "all", "mentions", "off" }, { all = "All Guild messages", mentions = "Mentions only", off = "Never" })
    b:Note("Controls which Guild/Officer messages raise a Guild notification card.")
    b:HalfToggle("Hide unavailable-player whisper line", function() return CC.db.ui.suppressOfflineWhisperErrors ~= false end,
        function(v) CC.db.ui.suppressOfflineWhisperErrors = v and true or false; if CC.RegisterChatFilters then CC:RegisterChatFilters() end end)
    b:Note("Hides only Blizzard's \226\128\152No player named \226\128\166 is currently online/playing\226\128\153 line (System notifications). The attempted CreshChat whisper remains visible and is marked failed instead.")

    b:Section("C launcher visibility")
    b:HalfToggle("Fade C button when idle", function() return CC.db.ui.launcherIdleFade == true end,
        function(v) CC.db.ui.launcherIdleFade = v; if UI.MarkLauncherActive then UI:MarkLauncherActive() end end)
    b:HalfToggle("Hide C button during combat", function() return CC.db.ui.launcherHideInCombat == true end,
        function(v) CC.db.ui.launcherHideInCombat = v; if UI.SetBubbleGroupShown then UI:SetBubbleGroupShown(CC.db.bubbleVisible) end end)
    b:Slider("Idle fade delay", 1, 30, 1, function() return CC.db.ui.launcherIdleDelay or 5 end,
        function(v) CC.db.ui.launcherIdleDelay = v; if UI.MarkLauncherActive then UI:MarkLauncherActive() end end, sec)
    b:Slider("Idle opacity", 0.05, 0.75, 0.05, function() return CC.db.ui.launcherIdleAlpha or 0.18 end,
        function(v) CC.db.ui.launcherIdleAlpha = v; if UI.RefreshLauncherVisibility then UI:RefreshLauncherVisibility(true) end end, pct)

    b:Section("Preview")
    b:Buttons({
        { "WHISPER", function() previewNotification("WHISPER"); if UI.ShowSlideToast then UI:ShowSlideToast("Whisper preview", "A direct-message card using your current settings.", "WHISPER", "PREVIEW:WHISPER", nil, "WHISPER", "Preview") end end, 104 },
        { "GUILD", function() previewNotification("GUILD"); if UI.ShowSlideToast then UI:ShowSlideToast("Guild preview", "A Guild notification card using your current settings.", "GUILD", "PREVIEW:GUILD", nil, "GUILD", nil) end end, 96 },
        { "PARTY", function() previewNotification("PARTY_MESSAGE"); if UI.ShowSlideToast then UI:ShowSlideToast("Party preview", "A party-message notification card.", "PARTY", "PREVIEW:PARTY", nil, "PARTY_MESSAGE", nil) end end, 96 },
    })
    b:Buttons({
        { "FRIEND", function() if UI.ShowPresenceToast then UI:ShowPresenceToast("Preview Friend", true) end end, 104 },
        { "REWARD", function() if UI.ShowBattlePassToast then UI:ShowBattlePassToast("Reward preview", "A Battle Pass or game reward card.", "BATTLEPASS", "PREVIEW:GAME") end end, 96 },
        { "SYSTEM", function() if UI.ShowSystemToast then UI:ShowSystemToast("System preview", "A system notification using your current settings.", "INFO") end end, 96 },
    })
    b:Note("Priority controls presentation: Critical and High use the full-size main-card lane; Normal and Low use compact slide-outs. Low-priority cards also expire sooner.")
    b:Finish()
end


local CONSOLE_TAB_LABELS = {
    FRIENDS="Friends", WHISPER="Whispers", GUILD="Guild", GENERAL="General feed", QUEST="Quest chats", COMBAT="Combat log",
    TRADE="Trade", PARTY="Party", RAID="Raid", INSTANCE="Instance", LFG="Looking For Group",
    SAY="Say", YELL="Yell", EMOTE="Emotes", LOCALDEFENSE="Local Defense",
}

local function setConsoleTab(key, value)
    CC.db.ui.consoleTabs = CC.db.ui.consoleTabs or {}
    CC.db.ui.consoleTabs[key] = value and true or false
    local any = false
    for _, definition in ipairs(UI.CONSOLE_TAB_DEFINITIONS or {}) do
        if CC.db.ui.consoleTabs[definition.key] == true then any = true; break end
    end
    if not any then CC.db.ui.consoleTabs.FRIENDS = true end
    if UI.RefreshConsoleTabs then UI:RefreshConsoleTabs() end
end

local function guildColor(key)
    CC.db.colors.guild = CC.db.colors.guild or {}
    CC.db.colors.guild[key] = CC.db.colors.guild[key] or { 0.18, 0.78, 0.36, 1 }
    return CC.db.colors.guild[key]
end

local CHANNELS = {
    { "GENERAL", "General" }, { "TRADE", "Trade" }, { "LOCALDEFENSE", "LocalDefense" },
    { "LFG", "LookingForGroup" }, { "SAY", "Say" }, { "YELL", "Yell" },
    { "PARTY", "Party" }, { "RAID", "Raid" }, { "INSTANCE", "Instance" },
    { "GUILD", "Guild accent" }, { "OFFICER", "Officer" }, { "EMOTE", "Emote" },
    { "WHISPER", "Whisper" }, { "CHANNEL", "Custom channels" },
}

function Settings:BuildChat(page)
    local b = self:NewBuilder(page, "Chat", "Which chat tabs appear in the console, plus Guild and General-feed colour theming. Card popups, priorities, animations and sounds are controlled from Notifications.")
    b:Section("Core console tabs")
    local core = { "FRIENDS", "WHISPER", "GUILD", "GENERAL", "QUEST", "COMBAT" }
    for _, key in ipairs(core) do
        local tabKey = key
        b:HalfToggle(CONSOLE_TAB_LABELS[tabKey], function() return CC.db.ui.consoleTabs[tabKey] ~= false end, function(v) setConsoleTab(tabKey, v) end)
    end

    b:Section("Optional channel tabs")
    local optional = { "TRADE", "PARTY", "RAID", "INSTANCE", "LFG", "SAY", "YELL", "EMOTE", "LOCALDEFENSE" }
    for _, key in ipairs(optional) do
        local tabKey = key
        b:HalfToggle(CONSOLE_TAB_LABELS[tabKey], function() return CC.db.ui.consoleTabs[tabKey] == true end, function(v) setConsoleTab(tabKey, v) end)
    end
    b:Note("Optional channel tabs filter the existing General history rather than duplicating messages. When selected, the shared composer sends directly to that channel. Tabs wrap onto additional rows so they stay inside the console width.")

    b:Buttons({
        { "CORE ONLY", function()
            local enabled = { FRIENDS=true, WHISPER=true, GUILD=true, GENERAL=true, QUEST=true, COMBAT=true }
            for _, definition in ipairs(UI.CONSOLE_TAB_DEFINITIONS or {}) do CC.db.ui.consoleTabs[definition.key] = enabled[definition.key] == true end
            if UI.RefreshConsoleTabs then UI:RefreshConsoleTabs() end
        end, 112 },
        { "CHAT FOCUS", function()
            local enabled = { FRIENDS=true, WHISPER=true, GUILD=true, GENERAL=true, TRADE=true, PARTY=true, RAID=true, INSTANCE=true, LFG=true }
            for _, definition in ipairs(UI.CONSOLE_TAB_DEFINITIONS or {}) do CC.db.ui.consoleTabs[definition.key] = enabled[definition.key] == true end
            if UI.RefreshConsoleTabs then UI:RefreshConsoleTabs() end
        end, 112 },
    })

    b:Section("Guild identity")
    b:HalfToggle("Use dedicated Guild theme", function() return CC.db.ui.guildTheme ~= false end, function(v) CC.db.ui.guildTheme = v end)
    b:Dropdown("Guild theme", function() return CC.db.ui.guildThemePreset or "AUTO" end,
        function() end,
        GUILD_THEME_VALUES, GUILD_THEME_DISPLAY, {
            isLocked = function(theme)
                return UI.IsGuildThemeUnlocked and not UI:IsGuildThemeUnlocked(theme) or false
            end,
            onSelect = function(theme, locked)
                if locked then
                    local unlockKey = UI.GetGuildThemeUnlockKey and UI:GetGuildThemeUnlockKey(theme) or nil
                    Settings:CloseDropdown()
                    if Settings.frame then Settings.frame:Hide() end
                    if unlockKey and CC.BattlePass and CC.BattlePass.OpenThemeUnlock then
                        CC.BattlePass:OpenThemeUnlock(unlockKey)
                    elseif UI.OpenGameDrawer then
                        UI:OpenGameDrawer("THEMES")
                    end
                    return
                end
                if UI.ApplyGuildThemePreset then UI:ApplyGuildThemePreset(theme)
                else CC.db.ui.guildThemePreset = theme end
            end,
        })
    b:Note("The Guild header and pop-outs use your tabard crest when the client exposes it. Guild card triggers, priority, sound and volume are controlled from Notifications. Premium matching Guild palettes are darkened and marked [LOCKED] until their Global Theme is unlocked.")

    b:Section("Custom Guild colours")
    b:HalfColor("Guild accent", function() return guildColor("accent") end, "GUILD")
    b:HalfColor("Guild border", function() return guildColor("border") end, "GUILD")
    b:HalfColor("Guild background", function() return guildColor("panel") end, "GUILD")
    b:HalfColor("Raised Guild boxes", function() return guildColor("panelRaised") end, "GUILD")
    b:HalfColor("Incoming Guild rows", function() return guildColor("incoming") end, "GUILD")
    b:HalfColor("Your Guild rows", function() return guildColor("outgoing") end, "GUILD")
    b:HalfColor("Officer accent", function() return guildColor("officer") end, "GUILD")
    b:HalfColor("Muted Guild text", function() return guildColor("muted") end, "GUILD")

    b:Section("General feed channel colours")
    for _, item in ipairs(CHANNELS) do
        b:HalfColor(item[2], function()
            CC.db.colors.channels[item[1]] = CC.db.colors.channels[item[1]] or { 0.5, 0.6, 0.8, 1 }
            return CC.db.colors.channels[item[1]]
        end)
    end
    b:Finish()
end

function Settings:BuildThemes(page)
    local b = self:NewBuilder(page, "Appearance", "Choose an unlocked theme to apply it immediately. Locked Battle Pass and Cresh Coin themes remain visible so you can jump directly to their unlock requirement.")
    b:Section("Theme selection")
    b:Dropdown("Active theme", function()
            return CC.db.ui.themePreset or "CRESH_MINIMAL"
        end,
        function() end,
        THEME_VALUES, THEME_DISPLAY, {
            isLocked = function(theme)
                if theme == "CUSTOM" then return false end
                return CC.BattlePass and CC.BattlePass.IsThemeUnlocked and not CC.BattlePass:IsThemeUnlocked(theme) or false
            end,
            onSelect = function(theme, locked)
                if locked then
                    Settings:CloseDropdown()
                    if Settings.frame then Settings.frame:Hide() end
                    if CC.BattlePass and CC.BattlePass.OpenThemeUnlock then
                        CC.BattlePass:OpenThemeUnlock(theme)
                    elseif UI.OpenGameDrawer then
                        UI:OpenGameDrawer("THEMES")
                    end
                    return
                end
                if UI.CancelThemePreview and UI.IsThemePreviewActive and UI:IsThemePreviewActive() then
                    UI:CancelThemePreview(true)
                end
                if theme == "CUSTOM" then
                    CC.db.ui.themePreset = "CUSTOM"
                    if UI.ApplyVisualSettings then UI:ApplyVisualSettings() end
                elseif UI.ApplyThemePreset then
                    UI:ApplyThemePreset(theme)
                end
            end,
        })
    b:Note("Unlocked themes apply as soon as you select them. Locked themes use a darker grey row marked [LOCKED]; selecting one closes Settings and opens Games > Unlock Themes at that exact theme.")
    b:Section("Surface colours")
    b:HalfColor("Accent / buttons", function() return CC.db.colors.accent end)
    b:HalfColor("Panel background", function() return CC.db.colors.panel end)
    b:HalfColor("Secondary panels", function() return CC.db.colors.panelSoft end)
    b:HalfColor("Raised surfaces", function() return CC.db.colors.panelRaised end)
    b:HalfColor("Borders", function() return CC.db.colors.border end)
    b:HalfColor("Incoming messages", function() return CC.db.colors.incoming end)
    b:HalfColor("Your messages", function() return CC.db.colors.outgoing end)
    b:Finish()
end

function Settings:BuildAdvanced(page)
    local b = self:NewBuilder(page, "Advanced", "Feature modules, native slash-command routing, diagnostic tools and safe UI resets.")

    b:Section("Feature module presets")
    b:Buttons({
        { "Full CreshChat", function() CC:ApplyFeaturePreset("full");    Settings:Refresh() end, 120 },
        { "Chat Only",      function() CC:ApplyFeaturePreset("chat");    Settings:Refresh() end, 120 },
        { "Minimal",        function() CC:ApplyFeaturePreset("minimal"); Settings:Refresh() end, 120 },
    })
    b:Note("Presets switch groups of modules at once. After choosing a preset, type /reload in chat to activate. Message history and progression data are never deleted by changing modules.")

    b:Section("Individual modules")
    for _, key in ipairs(CC.featureOrder or {}) do
        local displayName = (CC.featureDisplayNames and CC.featureDisplayNames[key]) or key
        b:HalfToggle(
            displayName,
            function() return CC:IsFeatureEnabled(key) end,
            function(v) CC:SetFeatureEnabled(key, v) end
        )
    end
    b:Note("Dependency cascades apply automatically: disabling Chat also disables Voice. Type /reload after any individual change.")

    b:Section("Blizzard command compatibility")
    b:HalfToggle("Native WoW slash commands", function() return CC.db.ui.nativeSlashCommands ~= false end, function(v) CC.db.ui.nativeSlashCommands = v end)
    b:HalfToggle("Remember command history", function() return CC.db.ui.commandHistory ~= false end, function(v) CC.db.ui.commandHistory = v end)
    b:HalfToggle("Single shared composer", function() return CC.db.ui.singleComposer ~= false end, function(v) CC.db.ui.singleComposer = v end)
    b:Note("Slash-prefixed text is passed to Blizzard's native parser, supporting /reload, /sit, emotes, targeting, macros, channels and commands registered by other addons.")

    b:Section("History limits")
    b:Slider("Chat history per feed", 40, 500, 10, function() return CC.db.historyLimit or 120 end,
        function(v) CC.db.historyLimit = v; if CC.Quality and CC.Quality.SanitizeDatabase then CC.Quality:SanitizeDatabase() end end,
        function(v) return floor(v + 0.5) .. " messages" end)
    b:Slider("Combat history limit", 80, 600, 20, function() return CC.db.combatHistoryLimit or 220 end,
        function(v) CC.db.combatHistoryLimit = v; if CC.Quality and CC.Quality.SanitizeDatabase then CC.Quality:SanitizeDatabase() end end,
        function(v) return floor(v + 0.5) .. " events" end)
    b:HalfToggle("Show build badge in console", function() return CC.db.ui.showBuildBadge == true end,
        function(v) CC.db.ui.showBuildBadge = v and true or false; if UI.LayoutMainHeader then UI:LayoutMainHeader() end end)
    b:Note("The build badge automatically hides when the console is too narrow to display it without covering chat controls.")

    -- Phase 6: rarely-used dev/diagnostic tools tucked behind one collapsible
    -- section instead of four separate button rows always on screen. Every
    -- one of these remains reachable, just not visible by default.
    b:CollapsibleSection("Diagnostics", function(db)
        db:Buttons({
            { "REFRESH SOCIAL", function()
                if _G.C_FriendList and type(_G.C_FriendList.ShowFriends) == "function" then pcall(_G.C_FriendList.ShowFriends) end
                if type(_G.ShowFriends) == "function" then pcall(_G.ShowFriends) end
                if type(_G.GuildRoster) == "function" then pcall(_G.GuildRoster) end
                if CC.Friends and CC.Friends.Refresh then pcall(CC.Friends.Refresh, CC.Friends, true) end
                if UI.RefreshConversationList then UI:RefreshConversationList() end
            end, 138 },
            { "HEALTH", function() CC:HandleSlashCommand("health") end, 100 },
        })
        db:Buttons({
            { "OPTIMISE", function() CC:HandleSlashCommand("optimise") end, 108 },
            { "STATUS", function() CC:HandleSlashCommand("status") end, 96 },
        })
        db:Buttons({
            { "TEST ALL", function() CC:HandleSlashCommand("test") end, 100 },
            { "VERSION", function() CC:HandleSlashCommand("version") end, 100 },
            { "DEV REPORT", function() CC:HandleSlashCommand("devreport") end, 118 },
        })
        db:Buttons({
            { "ASSETS", function() CC:HandleSlashCommand("assets") end, 100 },
        })
        db:Note("Health reports live event sources and refresh activity. Dev Report verifies module loading, SavedVariables structure and registered asset libraries. Optimise validates saved values and enforces safe history/cache limits. Test All injects sample messages/cards into your live history to preview notification styling.")
    end)

    b:Section("Reset")
    b:Buttons({
        { "RESET UI", function()
            b:ConfirmAction(
                "Reset CreshChat's appearance, colours, scale and saved window positions to defaults?\n\nMessage history is kept. This cannot be undone.",
                function() if CC.ResetUISettings then CC:ResetUISettings(); Settings:Refresh() end end)
        end, 120 },
    })
    b:Note("Reset UI restores CreshChat layout and appearance defaults but keeps message history. Completely deleting SavedVariables is the only full database reset.")
    b:Finish()
end

function Settings:CreatePage(name)
    local scroll = CreateFrame("ScrollFrame", nil, self.content, "UIPanelScrollFrameTemplate")
    raiseFrame(scroll, self.content, 6)
    scroll:SetAllPoints()
    if scroll.SetAlpha then scroll:SetAlpha(1) end
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(selfScroll, delta)
        local current = selfScroll:GetVerticalScroll() or 0
        local maximum = selfScroll:GetVerticalScrollRange() or 0
        selfScroll:SetVerticalScroll(max(0, min(maximum, current - delta * 42)))
    end)
    local canvas = CreateFrame("Frame", nil, scroll)
    raiseFrame(canvas, scroll, 1)
    canvas:SetSize(self.pageWidth, 520)
    if canvas.SetAlpha then canvas:SetAlpha(1) end
    scroll:SetScrollChild(canvas)
    scroll.canvas = canvas
    if scroll.ScrollBar then
        raiseFrame(scroll.ScrollBar, scroll, 3)
        if scroll.ScrollBarScrollUpButton then raiseFrame(scroll.ScrollBarScrollUpButton, scroll.ScrollBar, 1) end
        if scroll.ScrollBarScrollDownButton then raiseFrame(scroll.ScrollBarScrollDownButton, scroll.ScrollBar, 1) end
    end
    scroll:Hide()
    self.pages[name] = scroll
    return scroll
end

-- Phase 6: build a CreshChat page's actual controls the first time it's
-- shown, not eagerly for all pages at Settings:Build() time.
function Settings:EnsurePageBuilt(name)
    if self.pagesBuilt[name] then return end
    local builder = self.pageBuilders and self.pageBuilders[name]
    local page = self.pages[name]
    if not builder or not page then return end
    self.pagesBuilt[name] = true
    builder(page)
    -- Newly-built controls need one Relayout (splits half-width pairs into
    -- their two columns -- otherwise they sit stacked on top of each other
    -- at the same position) and one Refresh (populates dropdown menu item
    -- text, toggle ON/OFF labels, slider values and colour swatches, all of
    -- which are set by each control's own .Refresh(), not at construction
    -- time). The old eager Build() only needed to do this once, at the end,
    -- for everything; now it must happen once per page, right after it's
    -- actually built.
    self:Relayout()
    self:Refresh()
end

function Settings:SetPage(name)
    self:CloseDropdown()
    self:EnsurePageBuilt(name)
    self.activePage = name
    for pageName, page in pairs(self.pages) do
        page:SetShown(pageName == name)
        if pageName == name then
            if page.SetAlpha then page:SetAlpha(1) end
            if page.canvas and page.canvas.SetAlpha then page.canvas:SetAlpha(1) end
        end
    end
    self:RestorePageVisibility()
    local accent = CC.db and CC.db.colors and CC.db.colors.accent or { 0.11, 0.43, 0.95, 1 }
    for pageName, tab in pairs(self.tabs) do
        tab.creshActive = pageName == name
        if tab.SetBackdropColor then
            if tab.creshActive then tab:SetBackdropColor(accent[1] * 0.65, accent[2] * 0.65, accent[3] * 0.65, 1)
            else tab:SetBackdropColor(0.075, 0.086, 0.112, 1) end
        end
        if tab.text then tab.text:SetTextColor(tab.creshActive and 1 or 0.72, tab.creshActive and 1 or 0.77, tab.creshActive and 1 or 0.84, 1) end
    end
end

function Settings:Relayout()
    if not self.frame or not self.content then return end
    local sidebarWidth = self.sidebarWidth or 132
    local frameWidth, frameHeight = self.frame:GetWidth(), self.frame:GetHeight()
    local contentWidth = max(360, frameWidth - sidebarWidth - 30)
    local productBarOffset = self.productBar and (self.productBar:GetHeight() + 4) or 0
    local searchBarOffset = self.searchBar and (self.searchBar:GetHeight() + 4) or 0
    local contentHeight = max(300, frameHeight - 88 - productBarOffset - searchBarOffset)
    if self.compactLabel then self.compactLabel:SetShown(frameWidth >= 650) end
    self.sidebar:SetSize(sidebarWidth, contentHeight)
    self.content:SetSize(contentWidth, contentHeight)
    self.pageWidth = max(340, contentWidth - 24)
    local fullWidth = max(320, self.pageWidth - 24)
    local halfWidth = max(150, (fullWidth - 8) / 2)
    for _, page in pairs(self.pages or {}) do
        page:SetSize(contentWidth, contentHeight)
        page.canvas:SetWidth(self.pageWidth)
    end
    -- Product panel pages use a slightly wider content area (no CC sidebar offset).
    local pSidebarWidth = 130
    local pContentWidth = max(360, frameWidth - 16 - pSidebarWidth - 8)
    local pPageWidth    = max(340, pContentWidth - 24)
    local pFullWidth    = max(320, pPageWidth - 24)
    local pHalfWidth    = max(150, (pFullWidth - 8) / 2)
    for _, ps in pairs(self.productPanels or {}) do
        for _, page in pairs(ps.pages) do
            page:SetSize(pContentWidth, contentHeight)
            page.canvas:SetWidth(pPageWidth)
        end
    end
    for _, control in ipairs(self.layoutControls or {}) do
        if control.creshProductKey then
            if control.creshLayoutKind == "half" then
                control:SetWidth(pHalfWidth)
                local x = 12 + ((control.creshLayoutColumn or 1) - 1) * (pHalfWidth + 8)
                local point, relativeTo, relativePoint, _, y = control:GetPoint(1)
                control:ClearAllPoints(); control:SetPoint(point or "TOPLEFT", relativeTo or control:GetParent(), relativePoint or "TOPLEFT", x, y or 0)
            else
                control:SetWidth(pFullWidth)
            end
        else
            if control.creshLayoutKind == "half" then
                control:SetWidth(halfWidth)
                local x = 12 + ((control.creshLayoutColumn or 1) - 1) * (halfWidth + 8)
                local point, relativeTo, relativePoint, _, y = control:GetPoint(1)
                control:ClearAllPoints(); control:SetPoint(point or "TOPLEFT", relativeTo or control:GetParent(), relativePoint or "TOPLEFT", x, y or 0)
            else
                control:SetWidth(fullWidth)
            end
        end
        if control.Relayout then control:Relayout() end
    end
end

local function restoreFontAlpha(frame, depth)
    if not frame or (depth or 0) > 8 then return end
    if frame.GetRegions then
        local regions = { frame:GetRegions() }
        for _, region in ipairs(regions) do
            if region and region.GetObjectType and region:GetObjectType() == "FontString" and region.SetAlpha then
                region:SetAlpha(1)
            end
        end
    end
    if frame.GetChildren then
        local children = { frame:GetChildren() }
        for _, child in ipairs(children) do restoreFontAlpha(child, (depth or 0) + 1) end
    end
end

function Settings:RestorePageVisibility()
    if self.content and self.content.SetAlpha then self.content:SetAlpha(1) end
    if self.sidebar and self.sidebar.SetAlpha then self.sidebar:SetAlpha(1) end
    for _, page in pairs(self.pages or {}) do
        if page.SetAlpha then page:SetAlpha(1) end
        if page.canvas and page.canvas.SetAlpha then page.canvas:SetAlpha(1) end
        restoreFontAlpha(page, 0)
    end
    for _, ps in pairs(self.productPanels or {}) do
        for _, page in pairs(ps.pages) do
            if page.SetAlpha then page:SetAlpha(1) end
            if page.canvas and page.canvas.SetAlpha then page.canvas:SetAlpha(1) end
            restoreFontAlpha(page, 0)
        end
    end
end

function Settings:KeepOnTop()
    local frame = self.frame
    if not frame then return end
    frame.creshAlwaysOnTop = true
    if frame.SetFrameStrata then frame:SetFrameStrata("FULLSCREEN_DIALOG") end
    if frame.SetFrameLevel then frame:SetFrameLevel(SETTINGS_FRAME_LEVEL) end
    if frame.SetToplevel then frame:SetToplevel(true) end
    if frame.SetAlpha then frame:SetAlpha(1) end

    -- Keep every Settings layer below the client frame-level ceiling. Using
    -- 9999 caused child panels to collide at the ceiling and the content
    -- backdrop could render above its own text on TBC Anniversary clients.
    if self.sidebar then raiseFrame(self.sidebar, frame, 2) end
    if self.content then raiseFrame(self.content, frame, 2) end
    if self.header then raiseFrame(self.header, frame, 8) end
    for _, page in pairs(self.pages or {}) do
        raiseFrame(page, self.content or frame, 6)
        if page.canvas then raiseFrame(page.canvas, page, 2) end
        if page.ScrollBar then raiseFrame(page.ScrollBar, page, 4) end
    end
    for _, ps in pairs(self.productPanels or {}) do
        raiseFrame(ps.panel, frame, 2)
        raiseFrame(ps.sidebar, ps.panel, 2)
        raiseFrame(ps.content, ps.panel, 2)
        for _, page in pairs(ps.pages) do
            raiseFrame(page, ps.content, 6)
            if page.canvas then raiseFrame(page.canvas, page, 2) end
            if page.ScrollBar then raiseFrame(page.ScrollBar, page, 4) end
        end
    end
    self:RestorePageVisibility()
end

function Settings:Refresh()
    ensureTables()
    self:KeepOnTop()
    if UI.SyncGuildTheme then UI:SyncGuildTheme() end
    for _, control in ipairs(self.refreshables or {}) do if control.Refresh then control:Refresh() end end
    if self.frame then
        local c = CC.db.colors
        backdrop(self.frame, c.panel[1], c.panel[2], c.panel[3], 0.99, c.border[1], c.border[2], c.border[3], 1)
        backdrop(self.content, c.panelSoft[1], c.panelSoft[2], c.panelSoft[3], 1, c.border[1], c.border[2], c.border[3], 1)
        backdrop(self.sidebar, c.panel[1], c.panel[2], c.panel[3], 0.98, c.border[1], c.border[2], c.border[3], 1)
        self:RestorePageVisibility()
        if self.status then
            local profile = CC.db.ui and CC.db.ui.qualityProfile or "BALANCED"
            self.status:SetText("Build " .. tostring(CC.version or "") .. "  ·  schema " .. tostring(CC.db.version or "?") .. "  ·  profile " .. tostring(profile))
        end
        self:SetPage(self.activePage or "GENERAL")
        self:RefreshProductTabs()
    end
end

-- Build settings panels for any suite addon that has registered a page-spec
-- table via Suite:RegisterSettingsProvider. GamesSettings.lua / CollectSettings.lua
-- register on ADDON_LOADED, which can happen before OR after the player first
-- opens Settings (no fixed load order between addons without a Dependencies
-- directive) -- so this must be safe to call repeatedly, not just once at
-- Settings:Build() time. BuildProductSettingsPanel is itself idempotent
-- (Settings.lua's productPanels[key] guard), so re-scanning costs nothing once
-- a provider is already built.
function Settings:DiscoverProviders()
    if not self.frame then return end
    local _suite = _G.CreshSuite
    for _, _p in ipairs(PRODUCTS) do
        if not _p.owned then
            local _spec = _suite and _suite.GetSettingsProvider and _suite:GetSettingsProvider(_p.addonName)
            if type(_spec) == "table" and type(_spec.pages) == "table" then
                self:BuildProductSettingsPanel(_p.key, _spec)
            end
        end
    end
end

function Settings:Build()
    if self.frame then return end
    ensureTables()
    self.refreshables, self.layoutControls, self.pages, self.tabs = {}, {}, {}, {}
    self.sidebarWidth = 132

    local screenWidth = UIParent.GetWidth and UIParent:GetWidth() or 1920
    local screenHeight = UIParent.GetHeight and UIParent:GetHeight() or 1080
    local savedSize = CC.db.sizes and CC.db.sizes.settings or nil
    local requestedWidth = savedSize and tonumber(savedSize.width) or 740
    local requestedHeight = savedSize and tonumber(savedSize.height) or 600
    local maximumWidth = max(420, screenWidth - 28)
    local maximumHeight = max(350, screenHeight - 28)
    local minimumWidth = min(560, maximumWidth)
    local minimumHeight = min(420, maximumHeight)
    local frameWidth = max(minimumWidth, min(requestedWidth, min(900, maximumWidth)))
    local frameHeight = max(minimumHeight, min(requestedHeight, min(760, maximumHeight)))
    CC.db.sizes.settings = { width = frameWidth, height = frameHeight }

    local frame = CreateFrame("Frame", "CreshChatSettingsFrame", UIParent, templateName())
    frame:SetSize(frameWidth, frameHeight)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame.creshAlwaysOnTop = true
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetFrameLevel(SETTINGS_FRAME_LEVEL)
    if frame.SetToplevel then frame:SetToplevel(true) end
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame.creshClassicChrome = true
    if frame.SetResizable then frame:SetResizable(true) end
    if frame.SetResizeBounds then
        frame:SetResizeBounds(minimumWidth, minimumHeight, max(minimumWidth, min(900, screenWidth - 10)), max(minimumHeight, min(760, screenHeight - 10)))
    end
    backdrop(frame, 0.055, 0.067, 0.09, 0.99, 0.18, 0.21, 0.28, 1)
    frame:Hide()
    frame:SetScript("OnHide", function()
        Settings:CloseDropdown()
        if UI.CancelThemePreview and UI.IsThemePreviewActive and UI:IsThemePreviewActive() then UI:CancelThemePreview(true) end
        Settings.themePreviewSelection = CC.db and CC.db.ui and CC.db.ui.themePreset or "CRESH_MINIMAL"
    end)
    frame:SetScript("OnShow", function()
        Settings:Relayout()
        Settings:KeepOnTop()
    end)
    self.frame = frame
    if UI.InstallWindowFocus then UI:InstallWindowFocus(frame) end

    local header = CreateFrame("Frame", nil, frame)
    self.header = header
    raiseFrame(header, frame, 8)
    header:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
    header:SetHeight(40)
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function()
        if UI.FocusWindow then UI:FocusWindow(frame) end
        if CC.db.ui.shiftResize ~= false and IsShiftKeyDown and IsShiftKeyDown() and frame.StartSizing then frame:StartSizing("BOTTOMRIGHT")
        else frame:StartMoving() end
    end)
    header:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing(); Settings:Relayout()
        CC.db.sizes.settings = { width = frame:GetWidth(), height = frame:GetHeight() }
    end)

    local title = font(header, 15, "LEFT")
    title:SetPoint("LEFT", header, "LEFT", 13, 0)
    title:SetText("CreshChat Settings")
    local compact = font(header, 9, "LEFT")
    compact:SetPoint("LEFT", title, "RIGHT", 9, 0)
    compact:SetTextColor(0.52, 0.65, 0.82, 1)
    compact:SetText("COMPACT CONTROL CENTRE")
    self.compactLabel = compact
    local close = button(header, "X", 28, 27, function() frame:Hide() end)
    close:SetPoint("RIGHT", header, "RIGHT", -7, 0)

    self:BuildProductBar()
    self:BuildSearchBar()

    local sidebar = CreateFrame("Frame", nil, frame, templateName())
    raiseFrame(sidebar, frame, 2)
    sidebar:SetPoint("TOPLEFT", self.searchBar, "BOTTOMLEFT", 0, -4)
    sidebar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 8, 27)
    backdrop(sidebar, 0.045, 0.055, 0.075, 0.98, 0.13, 0.16, 0.21, 1)
    self.sidebar = sidebar

    local content = CreateFrame("Frame", nil, frame, templateName())
    raiseFrame(content, frame, 2)
    content:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 8, 0)
    content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 27)
    backdrop(content, 0.078, 0.090, 0.118, 1, 0.13, 0.16, 0.21, 1)
    self.content = content
    self.pageWidth = max(340, frameWidth - self.sidebarWidth - 54)

    -- Phase 6: 11 pages consolidated to 6. `keywords` feeds Settings:Search
    -- so it can find a page even before it has ever been built.
    local categories = {
        { "GENERAL", "General", "profile launcher portrait scale voice combat log arrange resize progress hub character copy" },
        { "CHAT", "Chat", "guild channel console tabs colours rails theme" },
        { "WINDOWS", "Windows", "dock composer popout window animation roster friends" },
        { "ALERTS", "Notifications", "notifications cards sound priority toast alert popup" },
        { "THEMES", "Appearance", "appearance theme colour accent panel border" },
        { "ADVANCED", "Advanced", "modules feature diagnostics health reset optimise version test" },
    }
    self.categoryOrder = categories
    self.pageBuilders = {
        GENERAL  = function(p) self:BuildGeneral(p) end,
        CHAT     = function(p) self:BuildChat(p) end,
        WINDOWS  = function(p) self:BuildWindows(p) end,
        ALERTS   = function(p) self:BuildAlerts(p) end,
        THEMES   = function(p) self:BuildThemes(p) end,
        ADVANCED = function(p) self:BuildAdvanced(p) end,
    }
    self.pagesBuilt = {}
    local previous
    local categoryHeight = #categories > 9 and 27 or 29
    local categoryGap = #categories > 9 and 3 or 5
    for index, item in ipairs(categories) do
        local tab = button(sidebar, item[2], self.sidebarWidth - 12, categoryHeight, function() Settings:SetPage(item[1]) end)
        if previous then tab:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -categoryGap)
        else tab:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 6, -7) end
        previous = tab
        self.tabs[item[1]] = tab
        self:CreatePage(item[1])
    end

    self:BuildProductPane()

    self:DiscoverProviders()

    self:SelectProduct("CC")

    local status = font(frame, 9, "LEFT")
    status:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 11, 7)
    status:SetPoint("RIGHT", frame, "RIGHT", -10, 0)
    status:SetTextColor(0.50, 0.58, 0.68, 1)
    self.status = status

    frame:SetScript("OnSizeChanged", function()
        Settings:Relayout()
    end)
    self:Relayout()
    self:SetPage("GENERAL")
    self:Refresh()
end

function UI:OpenSettings()
    Settings:Build()
    Settings:DiscoverProviders()
    if not (UI.IsThemePreviewActive and UI:IsThemePreviewActive()) then
        Settings.themePreviewSelection = CC.db and CC.db.ui and CC.db.ui.themePreset or "CRESH_MINIMAL"
    end
    Settings:Refresh()
    if Settings.frame:IsShown() then Settings.frame:Hide()
    else
        Settings:Relayout()
        if UI.ApplySafeFrameScale then UI:ApplySafeFrameScale(Settings.frame, (CC.db.ui and CC.db.ui.scale) or 1, 22) end
        if UI.ShowAnimated then UI:ShowAnimated(Settings.frame, "POP") else Settings.frame:Show() end
        Settings:KeepOnTop()
        if UI.FocusWindow then UI:FocusWindow(Settings.frame) end
    end
end

-- ============================================================
-- Phase 5 - Product tab methods
-- ============================================================

function Settings:BuildProductBar()
    local frame = self.frame
    local bar = CreateFrame("Frame", nil, frame, templateName())
    bar:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -44)
    bar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -44)
    bar:SetHeight(30)
    backdrop(bar, 0.040, 0.048, 0.065, 0.88, 0.12, 0.15, 0.20, 1)
    raiseFrame(bar, frame, 3)
    self.productBar  = bar
    self.productTabs = {}
    local previous
    for _, p in ipairs(PRODUCTS) do
        local tab = button(bar, p.label, 110, 22, function() Settings:SelectProduct(p.key) end)
        if previous then
            tab:SetPoint("TOPLEFT", previous, "TOPRIGHT", 4, 0)
        else
            tab:SetPoint("TOPLEFT", bar, "TOPLEFT", 6, -4)
        end
        self.productTabs[p.key] = tab
        previous = tab
    end
end

-- Phase 6: one search box, shared across every product tab. It always
-- searches whichever product is currently active (CC's own 6 pages, or the
-- active provider's own page list) -- see Settings:Search.
function Settings:BuildSearchBar()
    local frame = self.frame
    local bar = CreateFrame("Frame", nil, frame, templateName())
    bar:SetPoint("TOPLEFT", self.productBar, "BOTTOMLEFT", 0, -4)
    bar:SetPoint("TOPRIGHT", self.productBar, "BOTTOMRIGHT", 0, -4)
    bar:SetHeight(26)
    backdrop(bar, 0.045, 0.052, 0.070, 0.95, 0.13, 0.15, 0.20, 1)
    raiseFrame(bar, frame, 3)
    self.searchBar = bar

    local box = CreateFrame("EditBox", nil, bar, templateName())
    box:SetPoint("TOPLEFT", bar, "TOPLEFT", 8, -3)
    box:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -8, 3)
    box:SetAutoFocus(false)
    box:SetFontObject(_G.GameFontHighlightSmall or _G.GameFontNormalSmall)
    box:SetTextInsets(4, 4, 0, 0)
    box:SetMaxLetters(40)
    box:SetScript("OnEscapePressed", function(selfBox) selfBox:SetText(""); selfBox:ClearFocus() end)
    box:SetScript("OnEnterPressed", function(selfBox) selfBox:ClearFocus() end)
    box:SetScript("OnTextChanged", function(selfBox) Settings:UpdateSearchResults(selfBox:GetText() or "") end)
    self.searchBox = box

    local hint = font(bar, 9, "LEFT")
    hint:SetPoint("LEFT", box, "LEFT", 2, 0)
    hint:SetTextColor(0.52, 0.58, 0.68, 1)
    hint:SetText("Search settings...")
    box:SetScript("OnEditFocusGained", function() hint:Hide() end)
    box:SetScript("OnEditFocusLost", function(selfBox) hint:SetShown((selfBox:GetText() or "") == "") end)
    self.searchHint = hint

    local results = CreateFrame("Frame", nil, frame, templateName())
    results:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, -2)
    results:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT", 0, -2)
    backdrop(results, 0.03, 0.035, 0.048, 0.99, 0.16, 0.20, 0.27, 1)
    raiseFrame(results, frame, 30)
    results:Hide()
    self.searchResults = results
    self.searchResultButtons = {}
end

-- Matches the ACTIVE product's page list only (label + desc + keywords, and
-- any already-built controls' labels via self.refreshables for CC's own
-- pages) -- practical granularity is "jump to the page containing that
-- control," since a control on an unbuilt page has nothing to scroll to or
-- highlight yet anyway.
function Settings:Search(query)
    query = string.lower(tostring(query or ""))
    if query == "" then return {} end
    local results = {}
    if self.activeProductKey == "CC" or not self.activeProductKey then
        for _, item in ipairs(self.categoryOrder or {}) do
            local key, label, keywords = item[1], item[2], item[3] or ""
            local haystack = string.lower(label .. " " .. keywords)
            if string.find(haystack, query, 1, true) then
                results[#results + 1] = { key = key, label = label }
            end
        end
    else
        local ps = self.productPanels and self.productPanels[self.activeProductKey]
        if ps then
            for _, pKey in ipairs(ps.pageOrder or {}) do
                local spec = ps.pageSpecs[pKey]
                if spec then
                    local haystack = string.lower((spec.label or "") .. " " .. (spec.desc or "") .. " " .. (spec.keywords or ""))
                    if string.find(haystack, query, 1, true) then
                        results[#results + 1] = { key = pKey, label = spec.label }
                    end
                end
            end
        end
    end
    return results
end

function Settings:UpdateSearchResults(query)
    query = tostring(query or "")
    local results = self.searchResults
    if not results then return end
    if query == "" then results:Hide(); return end
    local matches = self:Search(query)
    for _, btn in ipairs(self.searchResultButtons) do btn:Hide() end
    if #matches == 0 then results:Hide(); return end
    local barWidth = (self.searchBar and self.searchBar:GetWidth() or 200) - 4
    local previous
    for index, match in ipairs(matches) do
        if index > 8 then break end
        local btn = self.searchResultButtons[index]
        if not btn then
            btn = button(results, "", barWidth, 22, nil)
            btn.text:ClearAllPoints()
            btn.text:SetJustifyH("LEFT")
            btn.text:SetPoint("LEFT", btn, "LEFT", 8, 0)
            btn.text:SetPoint("RIGHT", btn, "RIGHT", -8, 0)
            self.searchResultButtons[index] = btn
        end
        btn:SetWidth(barWidth)
        btn.text:SetText(match.label)
        btn:SetScript("OnClick", function()
            if Settings.activeProductKey == "CC" or not Settings.activeProductKey then
                Settings:SetPage(match.key)
            else
                Settings:SetProductPage(Settings.activeProductKey, match.key)
            end
            Settings.searchBox:SetText("")
            Settings.searchBox:ClearFocus()
            Settings:UpdateSearchResults("")
        end)
        if previous then btn:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -2)
        else btn:SetPoint("TOPLEFT", results, "TOPLEFT", 2, -2) end
        btn:Show()
        previous = btn
    end
    results:SetHeight(min(#matches, 8) * 24 + 4)
    results:Show()
end

function Settings:BuildProductPane()
    local frame = self.frame
    local pane = CreateFrame("Frame", nil, frame, templateName())
    pane:SetPoint("TOPLEFT", self.searchBar, "BOTTOMLEFT", 0, -4)
    pane:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 27)
    backdrop(pane, 0.055, 0.067, 0.090, 0.99, 0.13, 0.16, 0.21, 1)
    raiseFrame(pane, frame, 2)
    pane:Hide()
    self.productPane = pane

    local titleLabel = font(pane, 22, "LEFT")
    titleLabel:SetPoint("TOPLEFT", pane, "TOPLEFT", 28, -28)
    pane.productTitle = titleLabel

    local statusLabel = font(pane, 11, "LEFT")
    statusLabel:SetPoint("TOPLEFT", titleLabel, "BOTTOMLEFT", 0, -8)
    pane.statusLabel = statusLabel

    local descLabel = font(pane, 11, "LEFT")
    descLabel:SetPoint("TOPLEFT", statusLabel, "BOTTOMLEFT", 0, -16)
    descLabel:SetPoint("RIGHT", pane, "RIGHT", -28, 0)
    if descLabel.SetWordWrap then descLabel:SetWordWrap(true) end
    if descLabel.SetJustifyV then descLabel:SetJustifyV("TOP") end
    descLabel:SetTextColor(0.78, 0.82, 0.90, 1)
    pane.descriptionLabel = descLabel

    local urlFrame = CreateFrame("Frame", nil, pane)
    urlFrame:SetSize(440, 54)
    urlFrame:SetPoint("TOPLEFT", descLabel, "BOTTOMLEFT", 0, -16)
    urlFrame:Hide()
    pane.urlFrame = urlFrame

    local urlHint = font(urlFrame, 9, "LEFT")
    urlHint:SetPoint("TOPLEFT", urlFrame, "TOPLEFT", 0, 0)
    urlHint:SetText("Click to select, then Ctrl+A, Ctrl+C to copy:")
    urlHint:SetTextColor(0.52, 0.65, 0.82, 1)

    local urlBox = CreateFrame("EditBox", "CreshSettingsURLBox", urlFrame, "InputBoxTemplate")
    urlBox:SetAutoFocus(false)
    urlBox:SetWidth(400)
    urlBox:SetHeight(22)
    urlBox:SetPoint("TOPLEFT", urlHint, "BOTTOMLEFT", 0, -4)
    urlBox:SetText(SUITE_RELEASES_URL)
    urlBox:SetCursorPosition(0)
    urlBox:SetScript("OnEditFocusGained", function(self)
        if self.HighlightText then self:HighlightText() end
    end)
    urlBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    urlBox:SetScript("OnEnterPressed",  function(self) self:ClearFocus() end)
    pane.urlBox = urlBox
end

function Settings:RefreshProductTabs()
    if not self.productTabs then return end
    local key = self.activeProductKey or "CC"
    local accent = CC.db and CC.db.colors and CC.db.colors.accent or { 0.11, 0.43, 0.95, 1 }
    for _, p in ipairs(PRODUCTS) do
        local tab = self.productTabs[p.key]
        if tab then
            local active = p.key == key
            tab.creshActive = active
            if tab.SetBackdropColor then
                if active then
                    tab:SetBackdropColor(accent[1] * 0.55, accent[2] * 0.55, accent[3] * 0.55, 1)
                else
                    tab:SetBackdropColor(0.095, 0.108, 0.138, 1)
                end
            end
            if tab.text then
                tab.text:SetTextColor(active and 1 or 0.72, active and 1 or 0.77, active and 1 or 0.84, 1)
            end
        end
    end
end

function Settings:ShowProductStatus(key)
    local pane = self.productPane
    if not pane then return end
    local product
    for _, p in ipairs(PRODUCTS) do if p.key == key then product = p; break end end
    if not product then return end

    local status, detail = detectAddonStatus(product.addonName, product.minVer)
    pane.productTitle:SetText(product.label)

    if status == "loaded" then
        pane.statusLabel:SetText("Loaded")
        pane.statusLabel:SetTextColor(0.40, 0.90, 0.50, 1)
        local suite = _G.CreshSuite
        local hasProv = suite and suite.GetSettingsProvider
            and suite:GetSettingsProvider(product.addonName) ~= nil
        if hasProv then
            pane.descriptionLabel:SetText(product.label .. " is loaded. Settings will appear here once integrated.")
        else
            pane.descriptionLabel:SetText(product.label .. " is loaded. Full settings are coming in a future update.")
        end
        pane.urlFrame:Hide()

    elseif status == "disabled" then
        pane.statusLabel:SetText("Installed but not active")
        pane.statusLabel:SetTextColor(0.95, 0.78, 0.20, 1)
        pane.descriptionLabel:SetText(
            product.label .. " is installed but currently disabled.\n\n" ..
            "To enable it, return to the character selection screen and open the AddOns menu.")
        pane.urlFrame:Hide()

    elseif status == "missing" then
        pane.statusLabel:SetText("Not installed")
        pane.statusLabel:SetTextColor(0.85, 0.35, 0.35, 1)
        pane.descriptionLabel:SetText(
            product.label .. " is not installed. Download it from the CreshSuite releases " ..
            "page and place it in your Interface\\AddOns folder.")
        if pane.urlBox then pane.urlBox:SetText(SUITE_RELEASES_URL) end
        pane.urlFrame:Show()

    elseif status == "incompatible" then
        local verStr = detail and ("version " .. detail) or "an older version"
        pane.statusLabel:SetText("Incompatible version")
        pane.statusLabel:SetTextColor(0.85, 0.35, 0.35, 1)
        pane.descriptionLabel:SetText(
            product.label .. " is installed (" .. verStr .. ") but is not compatible with " ..
            "this version of CreshChat. Update " .. product.label .. " from the releases page.")
        if pane.urlBox then pane.urlBox:SetText(SUITE_RELEASES_URL) end
        pane.urlFrame:Show()
    end
end

-- Phase 6: build one product page's actual controls the first time it's
-- shown, not eagerly for every registered page when the provider is first
-- discovered.
function Settings:EnsureProductPageBuilt(productKey, pageKey)
    local ps = self.productPanels and self.productPanels[productKey]
    if not ps or ps.builtPages[pageKey] then return end
    local scroll = ps.pages[pageKey]
    local pageSpec = ps.pageSpecs[pageKey]
    if not scroll or not pageSpec then return end
    ps.builtPages[pageKey] = true
    if type(pageSpec.build) ~= "function" then return end
    self.currentProductKey = productKey
    local b = self:NewBuilder(scroll, pageSpec.label, pageSpec.desc or "")
    local ok, err = pcall(pageSpec.build, b)
    b:Finish()
    self.currentProductKey = nil
    if not ok then
        local errNote = font(scroll.canvas, 9, "LEFT")
        errNote:SetPoint("TOPLEFT", scroll.canvas, "TOPLEFT", 12, -12)
        errNote:SetTextColor(0.85, 0.35, 0.35, 1)
        errNote:SetText("Settings error: " .. tostring(err))
    end
    -- Same reason as EnsurePageBuilt: half-width pairs need one Relayout to
    -- split into columns, and dropdown/toggle/slider controls need one
    -- Refresh to populate their initial displayed text/state.
    self:Relayout()
    self:Refresh()
end

-- Switch the visible page within a product panel.
function Settings:SetProductPage(productKey, pageKey)
    local ps = self.productPanels and self.productPanels[productKey]
    if not ps then return end
    self:EnsureProductPageBuilt(productKey, pageKey)
    ps.activePage = pageKey
    local accent = CC.db and CC.db.colors and CC.db.colors.accent or { 0.11, 0.43, 0.95, 1 }
    for pKey, page in pairs(ps.pages) do
        page:SetShown(pKey == pageKey)
    end
    for pKey, tab in pairs(ps.tabs) do
        local active = pKey == pageKey
        tab.creshActive = active
        if tab.SetBackdropColor then
            if active then tab:SetBackdropColor(accent[1] * 0.65, accent[2] * 0.65, accent[3] * 0.65, 1)
            else tab:SetBackdropColor(0.075, 0.086, 0.112, 1) end
        end
        if tab.text then tab.text:SetTextColor(active and 1 or 0.72, active and 1 or 0.77, active and 1 or 0.84, 1) end
    end
end

-- Build a sidebar+content panel for a suite addon that has registered a page-spec table.
-- Spec format: { pages = { { key, label, desc, build(builder) }, ... } }
function Settings:BuildProductSettingsPanel(productKey, spec)
    if not spec or type(spec.pages) ~= "table" or #spec.pages == 0 then return end
    self.productPanels = self.productPanels or {}
    if self.productPanels[productKey] then return end

    local frame        = self.frame
    local pSidebarWidth = 130

    local panel = CreateFrame("Frame", nil, frame, templateName())
    panel:SetPoint("TOPLEFT",     self.searchBar, "BOTTOMLEFT", 0,  -4)
    panel:SetPoint("BOTTOMRIGHT", frame,          "BOTTOMRIGHT", -8, 27)
    backdrop(panel, 0.055, 0.067, 0.090, 0.99, 0.13, 0.16, 0.21, 1)
    raiseFrame(panel, frame, 2)
    panel:Hide()

    local pSidebar = CreateFrame("Frame", nil, panel, templateName())
    pSidebar:SetPoint("TOPLEFT",    panel, "TOPLEFT",    0, 0)
    pSidebar:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 0, 0)
    pSidebar:SetWidth(pSidebarWidth)
    backdrop(pSidebar, 0.045, 0.055, 0.075, 0.98, 0.13, 0.16, 0.21, 1)
    raiseFrame(pSidebar, panel, 2)

    local pContent = CreateFrame("Frame", nil, panel, templateName())
    pContent:SetPoint("TOPLEFT",     pSidebar, "TOPRIGHT",    8, 0)
    pContent:SetPoint("BOTTOMRIGHT", panel,    "BOTTOMRIGHT", 0, 0)
    backdrop(pContent, 0.078, 0.090, 0.118, 1, 0.13, 0.16, 0.21, 1)
    raiseFrame(pContent, panel, 2)

    local ps = {
        panel      = panel,
        sidebar    = pSidebar,
        content    = pContent,
        pages      = {},
        pageSpecs  = {},
        tabs       = {},
        pageOrder  = {},
        builtPages = {},
        activePage = nil,
    }

    local numPages  = #spec.pages
    local tabHeight = numPages > 9 and 27 or 29
    local tabGap    = numPages > 9 and 3  or 5
    local prevTab
    for _, pageSpec in ipairs(spec.pages) do
        local pKey = pageSpec.key
        ps.pageOrder[#ps.pageOrder + 1] = pKey

        local pKeyCapture = pKey
        local tab = button(pSidebar, pageSpec.label, pSidebarWidth - 12, tabHeight, function()
            Settings:SetProductPage(productKey, pKeyCapture)
        end)
        if prevTab then tab:SetPoint("TOPLEFT", prevTab,   "BOTTOMLEFT", 0, -tabGap)
        else            tab:SetPoint("TOPLEFT", pSidebar,  "TOPLEFT",    6, -7) end
        prevTab = tab
        ps.tabs[pKey] = tab

        local scroll = CreateFrame("ScrollFrame", nil, pContent, "UIPanelScrollFrameTemplate")
        raiseFrame(scroll, pContent, 6)
        scroll:SetAllPoints()
        scroll:EnableMouseWheel(true)
        scroll:SetScript("OnMouseWheel", function(selfScroll, delta)
            local current = selfScroll:GetVerticalScroll() or 0
            local maximum = selfScroll:GetVerticalScrollRange() or 0
            selfScroll:SetVerticalScroll(max(0, min(maximum, current - delta * 42)))
        end)
        local canvas = CreateFrame("Frame", nil, scroll)
        raiseFrame(canvas, scroll, 1)
        canvas:SetSize(self.pageWidth or 400, 520)
        scroll:SetScrollChild(canvas)
        scroll.canvas = canvas
        if scroll.ScrollBar then
            raiseFrame(scroll.ScrollBar, scroll, 3)
            if scroll.ScrollBarScrollUpButton   then raiseFrame(scroll.ScrollBarScrollUpButton,   scroll.ScrollBar, 1) end
            if scroll.ScrollBarScrollDownButton then raiseFrame(scroll.ScrollBarScrollDownButton, scroll.ScrollBar, 1) end
        end
        scroll:Hide()
        ps.pages[pKey] = scroll
        ps.pageSpecs[pKey] = pageSpec
        -- Phase 6: content is built lazily, on first Settings:SetProductPage
        -- for this key (see EnsureProductPageBuilt) -- not here.
    end

    self.productPanels[productKey] = ps
end

-- Re-run a single already-built product page's build(builder) closure against
-- a fresh canvas, so live data (e.g. collection counts) reflects the latest
-- SavedVariables without rebuilding the whole product panel or requiring the
-- page to be closed and reopened.
function Settings:RefreshProductPage(productKey, pageKey)
    local ps = self.productPanels and self.productPanels[productKey]
    if not ps then return end
    local scroll = ps.pages and ps.pages[pageKey]
    local pageSpec = ps.pageSpecs and ps.pageSpecs[pageKey]
    if not scroll or not pageSpec or type(pageSpec.build) ~= "function" then return end
    if ps.builtPages then ps.builtPages[pageKey] = true end

    local canvas = CreateFrame("Frame", nil, scroll)
    raiseFrame(canvas, scroll, 1)
    canvas:SetSize(self.pageWidth or 400, 520)
    scroll:SetScrollChild(canvas)
    scroll.canvas = canvas

    self.currentProductKey = productKey
    local b = self:NewBuilder(scroll, pageSpec.label, pageSpec.desc or "")
    local ok, err = pcall(pageSpec.build, b)
    b:Finish()
    self.currentProductKey = nil
    if not ok then
        local errNote = font(canvas, 9, "LEFT")
        errNote:SetPoint("TOPLEFT", canvas, "TOPLEFT", 12, -12)
        errNote:SetTextColor(0.85, 0.35, 0.35, 1)
        errNote:SetText("Settings error: " .. tostring(err))
    end
    self:Relayout()
    self:Refresh()
end

function Settings:SelectProduct(key)
    self.activeProductKey = key
    if key == "CC" then
        if self.sidebar     then self.sidebar:Show() end
        if self.content     then self.content:Show() end
        if self.productPane then self.productPane:Hide() end
        for _, ps in pairs(self.productPanels or {}) do ps.panel:Hide() end
        self:SetPage(self.activePage or "GENERAL")
    else
        if self.sidebar then self.sidebar:Hide() end
        if self.content then self.content:Hide() end
        -- A provider may have registered after Build() ran (no fixed load order
        -- between suite addons); pick it up now instead of showing the
        -- Overview/status fallback forever.
        self:DiscoverProviders()
        local ps = self.productPanels and self.productPanels[key]
        if ps then
            if self.productPane then self.productPane:Hide() end
            for pKey, p in pairs(self.productPanels) do p.panel:SetShown(pKey == key) end
            local activePage = ps.activePage or (ps.pageOrder and ps.pageOrder[1])
            if activePage then self:SetProductPage(key, activePage) end
        else
            for _, p in pairs(self.productPanels or {}) do p.panel:Hide() end
            if self.productPane then self.productPane:Show() end
            self:ShowProductStatus(key)
        end
    end
    self:RefreshProductTabs()
end
