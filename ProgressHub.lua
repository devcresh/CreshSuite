local _, CC = ...
if not CC then return end

-- ProgressHub: compact floating window for background-tracking modules.
-- Provides World Progression, Quest Capture and Combat Tracking summaries
-- when those features are enabled, plus permanent Settings access.

local Hub = {}
CC.ProgressHub = Hub
if CC.RegisterModule then CC:RegisterModule("ProgressHub", Hub) end

local floor, max, min = math.floor, math.max, math.min

local function formatNumber(value)
    local text = tostring(floor(max(0, tonumber(value) or 0)))
    local grouped = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    if grouped:sub(1, 1) == "," then grouped = grouped:sub(2) end
    return grouped
end

local BACKDROP = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    tile = false, edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
}
local FALLBACK = {
    panel      = { 0.022, 0.026, 0.034, 0.98 },
    panelSoft  = { 0.038, 0.044, 0.056, 0.98 },
    panelRaised= { 0.066, 0.074, 0.092, 1 },
    border     = { 0.105, 0.120, 0.145, 1 },
    accent     = { 0.130, 0.620, 0.950, 1 },
    text       = { 0.93,  0.95,  0.98,  1 },
    muted      = { 0.56,  0.61,  0.69,  1 },
    green      = { 0.18,  0.78,  0.36,  1 },
    red        = { 0.92,  0.24,  0.25,  1 },
    gold       = { 0.95,  0.70,  0.20,  1 },
    quest      = { 1.00,  0.82,  0.26,  1 },
    blue       = { 0.13,  0.62,  0.95,  1 },
}

local function palette()
    local c = CC.db and CC.db.colors or {}
    return {
        panel      = c.panel      or FALLBACK.panel,
        panelSoft  = c.panelSoft  or FALLBACK.panelSoft,
        panelRaised= c.panelRaised or FALLBACK.panelRaised,
        border     = c.border     or FALLBACK.border,
        accent     = c.accent     or FALLBACK.accent,
        text       = FALLBACK.text,
        muted      = FALLBACK.muted,
        green      = FALLBACK.green,
        red        = FALLBACK.red,
        gold       = FALLBACK.gold,
        quest      = c.quest      or FALLBACK.quest,
        blue       = c.blue       or FALLBACK.blue,
    }
end

local function templateName()
    return _G.BackdropTemplateMixin and "BackdropTemplate" or nil
end

local function applyBackdrop(frame, bg, border)
    if not frame then return end
    if frame.SetBackdrop then frame:SetBackdrop(BACKDROP) end
    bg     = bg     or FALLBACK.panel
    border = border or FALLBACK.border
    if frame.SetBackdropColor       then frame:SetBackdropColor(bg[1],     bg[2],     bg[3],     bg[4] or 1) end
    if frame.SetBackdropBorderColor then frame:SetBackdropBorderColor(border[1], border[2], border[3], border[4] or 1) end
end

local function createText(parent, size, color, justify)
    local f = parent:CreateFontString(nil, "OVERLAY")
    f:SetFont(_G.STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", size or 11, "")
    color = color or FALLBACK.text
    f:SetTextColor(color[1], color[2], color[3], color[4] or 1)
    f:SetJustifyH(justify or "LEFT")
    f:SetJustifyV("MIDDLE")
    return f
end

local function darken(color, amount)
    amount = tonumber(amount) or 0.18
    return {
        max(0, (color[1] or 0) - amount),
        max(0, (color[2] or 0) - amount),
        max(0, (color[3] or 0) - amount),
        color[4] or 1,
    }
end

local function createButton(parent, label, width, height, callback)
    local btn = CreateFrame("Button", nil, parent, templateName())
    btn:SetSize(width or 80, height or 24)
    local colors = palette()
    applyBackdrop(btn, colors.panelRaised, colors.border)
    btn.label = createText(btn, 9, colors.text, "CENTER")
    btn.label:SetAllPoints()
    btn.label:SetText(label or "")
    btn:SetScript("OnClick", function(self, ...)
        if callback then callback(self, ...) end
    end)
    btn:SetScript("OnEnter", function(self)
        local c = palette()
        applyBackdrop(self, darken(c.accent, 0.22), c.accent)
    end)
    btn:SetScript("OnLeave", function(self)
        if self.creshActive then return end
        local c = palette()
        applyBackdrop(self, c.panelRaised, c.border)
    end)
    return btn
end

local function setTabActive(btn, active)
    if not btn then return end
    local c = palette()
    local bg = active and darken(c.accent, 0.22) or c.panelRaised
    local bd = active and c.accent              or c.border
    applyBackdrop(btn, bg, bd)
    btn.creshActive = active
    if btn.label then
        local tc = active and c.accent or c.muted
        btn.label:SetTextColor(tc[1], tc[2], tc[3], 1)
    end
end

-- ── Public API ────────────────────────────────────────────────────────────────

function Hub:HasAnyEnabled()
    return CC:IsFeatureEnabled("worldProgression")
        or CC:IsFeatureEnabled("questCapture")
        or CC:IsFeatureEnabled("combatTracking")
end

function Hub:GetDefaultTab()
    local db  = CC.db and CC.db.ui or {}
    local last = db.lastProgressTab
    if last == "WORLD"  and CC:IsFeatureEnabled("worldProgression") then return "WORLD"    end
    if last == "QUESTS" and CC:IsFeatureEnabled("questCapture")     then return "QUESTS"   end
    if last == "COMBAT" and CC:IsFeatureEnabled("combatTracking")   then return "COMBAT"   end
    if CC:IsFeatureEnabled("worldProgression") then return "WORLD"  end
    if CC:IsFeatureEnabled("questCapture")     then return "QUESTS" end
    if CC:IsFeatureEnabled("combatTracking")   then return "COMBAT" end
    return "OVERVIEW"
end

function Hub:IsOpen()
    return self.frame and self.frame:IsShown()
end

function Hub:Toggle(tab)
    if not self:Build() then return end
    if self.frame:IsShown() and (not tab or self.currentTab == tab) then
        self:Close()
    else
        self:Open(tab)
    end
end

function Hub:Open(tab)
    if not self:Build() then return end
    local UI = CC.UI
    self:SetTab(tab or self:GetDefaultTab())
    if UI and UI.ApplySafeFrameScale then
        UI:ApplySafeFrameScale(self.frame, (CC.db and CC.db.ui and CC.db.ui.scale) or 1, 22)
    end
    if not self.frame:IsShown() then
        if UI and UI.ShowAnimated then
            UI:ShowAnimated(self.frame, "POP")
        else
            self.frame:Show()
        end
    end
    self:Refresh()
    if UI and UI.FocusWindow then UI:FocusWindow(self.frame) end
    if UI and UI.RefreshLauncherButtonStates then UI:RefreshLauncherButtonStates() end
end

function Hub:Close()
    if self.frame then self.frame:Hide() end
    local UI = CC.UI
    if UI and UI.RefreshLauncherButtonStates then UI:RefreshLauncherButtonStates() end
end

function Hub:SetTab(tab)
    self.currentTab = tab or "OVERVIEW"
    local db = CC.db and CC.db.ui
    if db then db.lastProgressTab = self.currentTab end
    for key, panel in pairs(self.panels or {}) do
        if panel then panel:SetShown(key == self.currentTab) end
    end
    for key, btn in pairs(self.tabButtons or {}) do
        setTabActive(btn, key == self.currentTab)
    end
end

-- ── Data accessors ────────────────────────────────────────────────────────────

local function getWorldData()
    local d = { steps = 0, zones = 0, areas = 0, dungeons = 0, kills = 0 }
    if CC.db and CC.db.gameProgression and CC.db.gameProgression.exploration then
        local e = CC.db.gameProgression.exploration
        d.steps    = floor(max(0, tonumber(e.totalSteps)    or 0))
        d.zones    = floor(max(0, tonumber(e.newZones)      or 0))
        d.areas    = floor(max(0, tonumber(e.newAreas)      or 0))
        d.dungeons = floor(max(0, tonumber(e.dungeonClears) or 0))
        d.kills    = floor(max(0, tonumber(e.totalKills)    or 0))
    end
    return d
end

local function getQuestData()
    local d = { total = 0, outland = 0, daily = 0, captured = 0 }
    if CC.db and CC.db.gameProgression and CC.db.gameProgression.achievements
       and CC.db.gameProgression.achievements.expansion then
        local stats = CC.db.gameProgression.achievements.expansion.stats or {}
        d.total   = floor(max(0, tonumber(stats.QUESTS_TOTAL)   or 0))
        d.outland = floor(max(0, tonumber(stats.QUESTS_OUTLAND) or 0))
        d.daily   = floor(max(0, tonumber(stats.DAILY_QUESTS)   or 0))
    end
    if CC.db and CC.db.history and CC.db.history.quests then
        local count = 0
        for _ in pairs(CC.db.history.quests) do count = count + 1 end
        d.captured = count
    end
    return d
end

local function getCombatData()
    local d = {
        kills = 0, deaths = 0,
        damage = 0, taken = 0, bestHit = 0,
        healing = 0, bestHeal = 0,
        crits = 0, critHeals = 0, interrupts = 0,
    }
    local stats
    if CC.CombatTracker and CC.CombatTracker.GetStats then
        stats = CC.CombatTracker:GetStats()
    end
    if not stats and CC.db and CC.db.gameProgression and CC.db.gameProgression.achievements then
        stats = CC.db.gameProgression.achievements.stats
    end
    if stats then
        d.damage    = floor(max(0, tonumber(stats.WOW_DAMAGE_DEALT) or 0))
        d.taken     = floor(max(0, tonumber(stats.WOW_DAMAGE_TAKEN) or 0))
        d.bestHit   = floor(max(0, tonumber(stats.WOW_BEST_HIT)     or 0))
        d.healing   = floor(max(0, tonumber(stats.WOW_HEALING)      or 0))
        d.bestHeal  = floor(max(0, tonumber(stats.WOW_BEST_HEAL)    or 0))
        d.crits     = floor(max(0, tonumber(stats.WOW_CRITS)        or 0))
        d.critHeals = floor(max(0, tonumber(stats.WOW_CRIT_HEALS)   or 0))
    end
    if CC.db and CC.db.gameProgression and CC.db.gameProgression.exploration then
        d.kills = floor(max(0, tonumber(CC.db.gameProgression.exploration.totalKills) or 0))
    end
    if CC.Achievements and CC.Achievements.GetStat then
        d.deaths = CC.Achievements:GetStat("DEATHS") or 0
    end
    if CC.db and CC.db.gameProgression and CC.db.gameProgression.achievements
       and CC.db.gameProgression.achievements.expansion then
        local expStats = CC.db.gameProgression.achievements.expansion.stats or {}
        d.interrupts = floor(max(0, tonumber(expStats.INTERRUPTS) or 0))
    end
    return d
end

-- ── Window builder ────────────────────────────────────────────────────────────

local WINDOW_W = 360
local WINDOW_H = 470

function Hub:Build()
    if self.frame then return self.frame end
    local UI = CC.UI
    if not UI then return nil end

    local colors     = palette()
    local savedPos   = CC.db and CC.db.positions and CC.db.positions.progressHub or nil

    local frame = CreateFrame("Frame", "CreshChatProgressHubFrame", UIParent, templateName())
    frame:SetSize(WINDOW_W, WINDOW_H)
    if savedPos then
        frame:SetPoint(savedPos.point or "CENTER", UIParent, savedPos.relPoint or "CENTER",
                       tonumber(savedPos.x) or 60, tonumber(savedPos.y) or 0)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 80, 0)
    end
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    applyBackdrop(frame, colors.panel, colors.border)
    frame:Hide()
    self.frame = frame

    frame:SetScript("OnMouseDown", function(self2, btn)
        if btn == "LeftButton" then
            if UI.FocusWindow then UI:FocusWindow(self2) end
            self2:StartMoving()
        end
    end)
    frame:SetScript("OnMouseUp", function(self2)
        self2:StopMovingOrSizing()
        if CC.db then
            CC.db.positions = CC.db.positions or {}
            local point, _, relPoint, x, y = self2:GetPoint()
            CC.db.positions.progressHub = {
                point = point, relPoint = relPoint,
                x = floor(x or 0), y = floor(y or 0),
            }
        end
    end)
    frame:SetScript("OnHide", function()
        if UI.RefreshLauncherButtonStates then UI:RefreshLauncherButtonStates() end
    end)

    if UI.InstallWindowFocus then UI:InstallWindowFocus(frame) end

    -- ── Header ────────────────────────────────────────────────────────────────
    local header = CreateFrame("Frame", nil, frame, templateName())
    header:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    header:SetHeight(34)
    applyBackdrop(header, darken(colors.accent, 0.32), colors.accent)

    local titleLabel = createText(header, 11, colors.text, "LEFT")
    titleLabel:SetPoint("TOPLEFT", header, "TOPLEFT", 10, -10)
    titleLabel:SetText("PROGRESS")

    -- Close button
    local closeBtn = CreateFrame("Button", nil, header, templateName())
    closeBtn:SetSize(22, 22)
    closeBtn:SetPoint("TOPRIGHT", header, "TOPRIGHT", -4, -6)
    applyBackdrop(closeBtn, colors.panelRaised, colors.border)
    local closeLbl = createText(closeBtn, 9, colors.muted, "CENTER")
    closeLbl:SetAllPoints()
    closeLbl:SetText("X")
    closeBtn:SetScript("OnClick", function() Hub:Close() end)

    -- Settings button (right of header, left of close)
    local settingsBtn = CreateFrame("Button", nil, header, templateName())
    settingsBtn:SetSize(36, 22)
    settingsBtn:SetPoint("RIGHT", closeBtn, "LEFT", -3, 0)
    applyBackdrop(settingsBtn, colors.panelRaised, colors.border)
    local settingsLbl = createText(settingsBtn, 8, colors.muted, "CENTER")
    settingsLbl:SetAllPoints()
    settingsLbl:SetText("SET")
    settingsBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    settingsBtn:SetScript("OnClick", function(_, mouseButton)
        if UI.OpenSettings then UI:OpenSettings() end
        if mouseButton == "RightButton" then
            if CC.Settings and CC.Settings.SetPage then CC.Settings:SetPage("MODULES") end
        end
    end)
    settingsBtn:SetScript("OnEnter", function(self2)
        GameTooltip:SetOwner(self2, "ANCHOR_LEFT")
        GameTooltip:AddLine("CreshChat Settings", 1, 1, 1)
        GameTooltip:AddLine("Right-click: open Modules", 0.75, 0.8, 0.9)
        GameTooltip:Show()
    end)
    settingsBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- ── Tab bar ───────────────────────────────────────────────────────────────
    local tabBar = CreateFrame("Frame", nil, frame, templateName())
    tabBar:SetPoint("TOPLEFT",  header, "BOTTOMLEFT",  0, -1)
    tabBar:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, -1)
    tabBar:SetHeight(26)
    applyBackdrop(tabBar, colors.panelRaised, colors.border)
    self.tabBar = tabBar

    self.tabButtons = {}
    self.panels     = {}

    local TAB_DEFS = {
        { key = "OVERVIEW", label = "OVERVIEW", feature = nil },
        { key = "WORLD",    label = "WORLD",    feature = "worldProgression" },
        { key = "QUESTS",   label = "QUESTS",   feature = "questCapture"    },
        { key = "COMBAT",   label = "COMBAT",   feature = "combatTracking"  },
    }
    local prevBtn
    for _, tabDef in ipairs(TAB_DEFS) do
        local shown = not tabDef.feature or CC:IsFeatureEnabled(tabDef.feature)
        local btn = CreateFrame("Button", nil, tabBar, templateName())
        btn:SetSize(70, 22)
        if prevBtn then btn:SetPoint("LEFT", prevBtn, "RIGHT", 2, 0)
        else             btn:SetPoint("LEFT", tabBar, "LEFT",  4, 0) end
        applyBackdrop(btn, colors.panelRaised, colors.border)
        btn.label = createText(btn, 8, colors.muted, "CENTER")
        btn.label:SetAllPoints()
        btn.label:SetText(tabDef.label)
        local capturedKey = tabDef.key
        btn:SetScript("OnClick", function()
            Hub:SetTab(capturedKey)
            Hub:Refresh()
        end)
        btn:SetShown(shown)
        self.tabButtons[tabDef.key] = btn
        if shown then prevBtn = btn end
    end

    -- ── Content ───────────────────────────────────────────────────────────────
    local content = CreateFrame("Frame", nil, frame, templateName())
    content:SetPoint("TOPLEFT",     tabBar, "BOTTOMLEFT",  0, -1)
    content:SetPoint("BOTTOMRIGHT", frame,  "BOTTOMRIGHT", 0,  0)
    applyBackdrop(content, colors.panelSoft, colors.panelSoft)
    self.content = content

    self.panels.OVERVIEW = self:BuildOverviewPanel(content, colors)
    self.panels.WORLD    = self:BuildWorldPanel(content, colors)
    self.panels.QUESTS   = self:BuildQuestsPanel(content, colors)
    self.panels.COMBAT   = self:BuildCombatPanel(content, colors)

    self.currentTab = self:GetDefaultTab()
    self:SetTab(self.currentTab)
    return frame
end

-- ── Overview panel ────────────────────────────────────────────────────────────

function Hub:BuildOverviewPanel(parent, colors)
    local panel = CreateFrame("Frame", nil, parent, templateName())
    panel:SetAllPoints()
    applyBackdrop(panel, colors.panelSoft, colors.panelSoft)
    panel:Hide()

    local modules = {
        { key = "worldProgression", label = "World Progression",
          desc = "Zone discovery · exploration · dungeons · professions",
          tab  = "WORLD" },
        { key = "questCapture",     label = "Quest Capture",
          desc = "NPC dialogue · quest completions · zone tracking",
          tab  = "QUESTS" },
        { key = "combatTracking",   label = "Combat Tracking",
          desc = "Damage dealt · healing · crits · kills",
          tab  = "COMBAT" },
    }

    panel.cards = {}
    local y = -8
    for _, mod in ipairs(modules) do
        local enabled = CC:IsFeatureEnabled(mod.key)
        local card = CreateFrame("Frame", nil, panel, templateName())
        card:SetPoint("TOPLEFT",  panel, "TOPLEFT",  8, y)
        card:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, y)
        card:SetHeight(74)
        applyBackdrop(card, enabled and colors.panel or darken(colors.panelSoft, 0.01), colors.border)
        y = y - 80

        local dot = createText(card, 9, enabled and colors.green or colors.muted, "LEFT")
        dot:SetPoint("TOPLEFT", card, "TOPLEFT", 8, -10)
        dot:SetText(enabled and "ON" or "OFF")

        local nameLabel = createText(card, 10, enabled and colors.text or colors.muted, "LEFT")
        nameLabel:SetPoint("LEFT", dot, "RIGHT", 5, 0)
        nameLabel:SetWidth(170)
        nameLabel:SetText(mod.label)

        local descLabel = createText(card, 8, colors.muted, "LEFT")
        descLabel:SetPoint("TOPLEFT", dot, "BOTTOMLEFT", 0, -6)
        descLabel:SetPoint("RIGHT", card, "RIGHT", -80, 0)
        descLabel:SetWordWrap(true)
        descLabel:SetText(mod.desc)

        local viewBtn = CreateFrame("Button", nil, card, templateName())
        viewBtn:SetSize(62, 20)
        viewBtn:SetPoint("TOPRIGHT", card, "TOPRIGHT", -8, -8)
        applyBackdrop(viewBtn, colors.panelRaised, colors.border)
        local viewLbl = createText(viewBtn, 8, enabled and colors.text or colors.muted, "CENTER")
        viewLbl:SetAllPoints()
        viewLbl:SetText(enabled and "VIEW" or "DISABLED")
        local capturedTab = mod.tab
        local capturedEnabled = enabled
        viewBtn:SetScript("OnClick", function()
            if capturedEnabled then
                Hub:SetTab(capturedTab)
                Hub:Refresh()
            else
                if CC.UI and CC.UI.OpenSettings then CC.UI:OpenSettings() end
                if CC.Settings and CC.Settings.SetPage then CC.Settings:SetPage("MODULES") end
            end
        end)

        local setBtn = CreateFrame("Button", nil, card, templateName())
        setBtn:SetSize(62, 20)
        setBtn:SetPoint("TOPRIGHT", card, "TOPRIGHT", -8, -32)
        applyBackdrop(setBtn, colors.panel, colors.border)
        local setLbl = createText(setBtn, 8, colors.muted, "CENTER")
        setLbl:SetAllPoints()
        setLbl:SetText("MODULES")
        setBtn:SetScript("OnClick", function()
            if CC.UI and CC.UI.OpenSettings then CC.UI:OpenSettings() end
            if CC.Settings and CC.Settings.SetPage then CC.Settings:SetPage("MODULES") end
        end)

        panel.cards[mod.key] = card
    end

    local statusLabel = createText(panel, 8, colors.muted, "CENTER")
    statusLabel:SetPoint("BOTTOMLEFT",  panel, "BOTTOMLEFT",  8, 8)
    statusLabel:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -8, 8)
    statusLabel:SetWordWrap(true)
    panel.statusLabel = statusLabel

    return panel
end

-- ── World panel ───────────────────────────────────────────────────────────────

local WORLD_STATS = {
    { key = "steps",    label = "Total steps travelled" },
    { key = "zones",    label = "Zones discovered" },
    { key = "areas",    label = "Sub-areas discovered" },
    { key = "dungeons", label = "Dungeon runs recorded" },
    { key = "kills",    label = "World kills" },
}

function Hub:BuildWorldPanel(parent, colors)
    local panel = CreateFrame("Frame", nil, parent, templateName())
    panel:SetAllPoints()
    applyBackdrop(panel, colors.panelSoft, colors.panelSoft)
    panel:Hide()

    local hdr = createText(panel, 10, colors.text, "LEFT")
    hdr:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -9)
    hdr:SetText("WORLD PROGRESSION")

    panel.rows = {}
    for i, stat in ipairs(WORLD_STATS) do
        local row = CreateFrame("Frame", nil, panel, templateName())
        row:SetPoint("TOPLEFT",  panel, "TOPLEFT",  8, -26 - (i - 1) * 26)
        row:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, -26 - (i - 1) * 26)
        row:SetHeight(24)
        if i % 2 == 0 then applyBackdrop(row, colors.panel, colors.panel) end
        row.label = createText(row, 9, colors.muted, "LEFT")
        row.label:SetPoint("LEFT", row, "LEFT", 6, 0)
        row.label:SetWidth(200)
        row.label:SetText(stat.label)
        row.value = createText(row, 9, colors.text, "RIGHT")
        row.value:SetPoint("RIGHT", row, "RIGHT", -6, 0)
        row.value:SetText("—")
        panel.rows[stat.key] = row
    end

    panel.notice = createText(panel, 9, colors.muted, "CENTER")
    panel.notice:SetPoint("CENTER", panel, "CENTER", 0, 20)
    panel.notice:SetPoint("LEFT",   panel, "LEFT",  12, 0)
    panel.notice:SetPoint("RIGHT",  panel, "RIGHT", -12, 0)
    panel.notice:SetWordWrap(true)
    panel.notice:SetJustifyV("MIDDLE")
    panel.notice:SetText(
        "World Progression is disabled.\n\n" ..
        "Enable it in Modules to track zone discovery,\n" ..
        "dungeon clears, profession progress and more."
    )
    panel.notice:Hide()

    return panel
end

-- ── Quests panel ──────────────────────────────────────────────────────────────

local QUEST_STATS = {
    { key = "total",    label = "Unique quests completed" },
    { key = "outland",  label = "Outland quests completed" },
    { key = "daily",    label = "Daily quests completed" },
    { key = "captured", label = "Quest dialogues captured" },
}

function Hub:BuildQuestsPanel(parent, colors)
    local panel = CreateFrame("Frame", nil, parent, templateName())
    panel:SetAllPoints()
    applyBackdrop(panel, colors.panelSoft, colors.panelSoft)
    panel:Hide()

    local hdr = createText(panel, 10, colors.text, "LEFT")
    hdr:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -9)
    hdr:SetText("QUEST CAPTURE")

    panel.rows = {}
    for i, stat in ipairs(QUEST_STATS) do
        local row = CreateFrame("Frame", nil, panel, templateName())
        row:SetPoint("TOPLEFT",  panel, "TOPLEFT",  8, -26 - (i - 1) * 26)
        row:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, -26 - (i - 1) * 26)
        row:SetHeight(24)
        if i % 2 == 0 then applyBackdrop(row, colors.panel, colors.panel) end
        row.label = createText(row, 9, colors.muted, "LEFT")
        row.label:SetPoint("LEFT", row, "LEFT", 6, 0)
        row.label:SetWidth(200)
        row.label:SetText(stat.label)
        row.value = createText(row, 9, colors.text, "RIGHT")
        row.value:SetPoint("RIGHT", row, "RIGHT", -6, 0)
        row.value:SetText("—")
        panel.rows[stat.key] = row
    end

    panel.notice = createText(panel, 9, colors.muted, "CENTER")
    panel.notice:SetPoint("CENTER", panel, "CENTER", 0, 20)
    panel.notice:SetPoint("LEFT",   panel, "LEFT",  12, 0)
    panel.notice:SetPoint("RIGHT",  panel, "RIGHT", -12, 0)
    panel.notice:SetWordWrap(true)
    panel.notice:SetJustifyV("MIDDLE")
    panel.notice:SetText(
        "Quest Capture is disabled.\n\n" ..
        "Enable it in Modules to record NPC dialogue,\n" ..
        "quest completions and zone quest counts."
    )
    panel.notice:Hide()

    return panel
end

-- ── Combat panel ──────────────────────────────────────────────────────────────

local COMBAT_STATS = {
    { key = "kills",     label = "World kills" },
    { key = "deaths",    label = "Deaths" },
    { key = "damage",    label = "Total damage dealt" },
    { key = "taken",     label = "Total damage taken" },
    { key = "healing",   label = "Total healing done" },
    { key = "crits",     label = "Critical strikes" },
    { key = "critHeals", label = "Critical heals" },
    { key = "bestHit",   label = "Best single hit" },
    { key = "bestHeal",  label = "Best single heal" },
    { key = "interrupts",label = "Interrupts" },
}

function Hub:BuildCombatPanel(parent, colors)
    local panel = CreateFrame("Frame", nil, parent, templateName())
    panel:SetAllPoints()
    applyBackdrop(panel, colors.panelSoft, colors.panelSoft)
    panel:Hide()

    local hdr = createText(panel, 10, colors.text, "LEFT")
    hdr:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -9)
    hdr:SetText("COMBAT TRACKING  \xB7  Account-wide")

    panel.rows = {}
    for i, stat in ipairs(COMBAT_STATS) do
        local row = CreateFrame("Frame", nil, panel, templateName())
        row:SetPoint("TOPLEFT",  panel, "TOPLEFT",  8, -26 - (i - 1) * 22)
        row:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, -26 - (i - 1) * 22)
        row:SetHeight(20)
        if i % 2 == 0 then applyBackdrop(row, colors.panel, colors.panel) end
        row.label = createText(row, 8, colors.muted, "LEFT")
        row.label:SetPoint("LEFT", row, "LEFT", 6, 0)
        row.label:SetWidth(190)
        row.label:SetText(stat.label)
        row.value = createText(row, 8, colors.text, "RIGHT")
        row.value:SetPoint("RIGHT", row, "RIGHT", -6, 0)
        row.value:SetText("—")
        panel.rows[stat.key] = row
    end

    panel.notice = createText(panel, 9, colors.muted, "CENTER")
    panel.notice:SetPoint("CENTER", panel, "CENTER", 0, 20)
    panel.notice:SetPoint("LEFT",   panel, "LEFT",  12, 0)
    panel.notice:SetPoint("RIGHT",  panel, "RIGHT", -12, 0)
    panel.notice:SetWordWrap(true)
    panel.notice:SetJustifyV("MIDDLE")
    panel.notice:SetText(
        "Combat Tracking is disabled.\n\n" ..
        "Enable it in Modules to record damage,\n" ..
        "healing, critical strikes and kill statistics."
    )
    panel.notice:Hide()

    return panel
end

-- ── Refresh (populate live data) ──────────────────────────────────────────────

function Hub:Refresh()
    if not self.frame or not self.frame:IsShown() then return end

    -- Keep tab visibility in sync with current feature state.
    local FEATURE_FOR_TAB = {
        WORLD  = "worldProgression",
        QUESTS = "questCapture",
        COMBAT = "combatTracking",
    }
    for tabKey, featureKey in pairs(FEATURE_FOR_TAB) do
        if self.tabButtons[tabKey] then
            self.tabButtons[tabKey]:SetShown(CC:IsFeatureEnabled(featureKey))
        end
    end

    -- If current tab is now feature-gated off, fall back to OVERVIEW.
    if self.currentTab ~= "OVERVIEW" then
        local feat = FEATURE_FOR_TAB[self.currentTab]
        if feat and not CC:IsFeatureEnabled(feat) then
            self:SetTab("OVERVIEW")
        end
    end

    if self.currentTab == "OVERVIEW" then
        self:RefreshOverview()
    elseif self.currentTab == "WORLD" then
        self:RefreshWorld()
    elseif self.currentTab == "QUESTS" then
        self:RefreshQuests()
    elseif self.currentTab == "COMBAT" then
        self:RefreshCombat()
    end
end

function Hub:RefreshOverview()
    local panel = self.panels.OVERVIEW
    if not panel then return end
    local anyEnabled = self:HasAnyEnabled()
    if panel.statusLabel then
        if anyEnabled then
            panel.statusLabel:SetText("Select a tab above to view detailed statistics.")
        else
            panel.statusLabel:SetText(
                "No background tracking modules are enabled.\n" ..
                "Open Settings \xE2\x86\x92 Modules to enable World Progression, Quest Capture or Combat Tracking."
            )
        end
    end
end

function Hub:RefreshWorld()
    local panel = self.panels.WORLD
    if not panel then return end
    local on = CC:IsFeatureEnabled("worldProgression")
    panel.notice:SetShown(not on)
    for _, row in pairs(panel.rows or {}) do row:SetShown(on) end
    if not on then return end
    local d = getWorldData()
    if panel.rows.steps    then panel.rows.steps.value:SetText(formatNumber(d.steps))    end
    if panel.rows.zones    then panel.rows.zones.value:SetText(formatNumber(d.zones))    end
    if panel.rows.areas    then panel.rows.areas.value:SetText(formatNumber(d.areas))    end
    if panel.rows.dungeons then panel.rows.dungeons.value:SetText(formatNumber(d.dungeons)) end
    if panel.rows.kills    then panel.rows.kills.value:SetText(formatNumber(d.kills))    end
end

function Hub:RefreshQuests()
    local panel = self.panels.QUESTS
    if not panel then return end
    local on = CC:IsFeatureEnabled("questCapture")
    panel.notice:SetShown(not on)
    for _, row in pairs(panel.rows or {}) do row:SetShown(on) end
    if not on then return end
    local d = getQuestData()
    if panel.rows.total    then panel.rows.total.value:SetText(formatNumber(d.total))    end
    if panel.rows.outland  then panel.rows.outland.value:SetText(formatNumber(d.outland)) end
    if panel.rows.daily    then panel.rows.daily.value:SetText(formatNumber(d.daily))    end
    if panel.rows.captured then panel.rows.captured.value:SetText(formatNumber(d.captured)) end
end

function Hub:RefreshCombat()
    local panel = self.panels.COMBAT
    if not panel then return end
    local on = CC:IsFeatureEnabled("combatTracking")
    panel.notice:SetShown(not on)
    for _, row in pairs(panel.rows or {}) do row:SetShown(on) end
    if not on then return end
    local d = getCombatData()
    if panel.rows.kills     then panel.rows.kills.value:SetText(formatNumber(d.kills))      end
    if panel.rows.deaths    then panel.rows.deaths.value:SetText(formatNumber(d.deaths))    end
    if panel.rows.damage    then panel.rows.damage.value:SetText(formatNumber(d.damage))    end
    if panel.rows.taken     then panel.rows.taken.value:SetText(formatNumber(d.taken))      end
    if panel.rows.healing   then panel.rows.healing.value:SetText(formatNumber(d.healing))  end
    if panel.rows.crits     then panel.rows.crits.value:SetText(formatNumber(d.crits))      end
    if panel.rows.critHeals then panel.rows.critHeals.value:SetText(formatNumber(d.critHeals)) end
    if panel.rows.bestHit   then panel.rows.bestHit.value:SetText(formatNumber(d.bestHit))  end
    if panel.rows.bestHeal  then panel.rows.bestHeal.value:SetText(formatNumber(d.bestHeal)) end
    if panel.rows.interrupts then panel.rows.interrupts.value:SetText(formatNumber(d.interrupts)) end
end
