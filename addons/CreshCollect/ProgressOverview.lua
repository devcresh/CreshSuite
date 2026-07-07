local _, COL = ...
if not COL then return end

local CC = setmetatable({}, { __index = function(_, k)
    local c = _G.CreshChat
    return c and c[k]
end })

-- ProgressOverview: the dedicated visual progress dashboard opened by
-- /cc progress (and its aliases /cc hub, /cc tracking). Distinct from both
-- ProgressHub (the older, generic World/Quest/Combat tracking window, left
-- untouched and still reachable from this window's own nav row) and the
-- detailed BattlePass/Achievements standalone windows (Phase 6) -- this is
-- a single-screen summary of the Azeroth Chronicle, Achievements and Collections
-- progress, with quick links into the detailed windows for each.

local Overview = {}
COL.ProgressOverview = Overview
if COL.RegisterModule then COL:RegisterModule("ProgressOverview", Overview) end

local floor, max, min = math.floor, math.max, math.min

local function formatNumber(value)
    local text = tostring(floor(max(0, tonumber(value) or 0)))
    local grouped = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    if grouped:sub(1, 1) == "," then grouped = grouped:sub(2) end
    return grouped
end

-- Renders "a / b" for a known total, or just "a" when the total can't be
-- determined (e.g. a collection bucket whose total lives in CreshGames and
-- CreshGames isn't loaded) -- never divides or fabricates a total.
local function ratioText(count, total)
    count = floor(max(0, tonumber(count) or 0))
    if total == nil then return formatNumber(count) end
    total = floor(max(0, tonumber(total) or 0))
    return formatNumber(count) .. " / " .. formatNumber(total)
end

-- Safe ratio in [0, 1]. Returns 0 for a zero/unknown total instead of
-- dividing by zero, and never exceeds 1 even if data is momentarily
-- inconsistent (e.g. a stat recount mid-transaction).
local function safeRatio(count, total)
    count = tonumber(count) or 0
    total = tonumber(total) or 0
    if total <= 0 then return 0 end
    return min(1, max(0, count / total))
end

-- ============================================================
-- Pure calculation layer -- validated independently of rendering below
-- (see tests/ProgressOverviewTests.lua). GetSummary() never touches a
-- frame; it only reads CreshCollectDB and the bridged calculation
-- functions already defined in BattlePass.lua / Achievements.lua, plus
-- CreshGames' own bridged Tetris/CardDecks totals when available.
-- ============================================================

function Overview:GetSummary()
    local suite = _G.CreshSuite
    local collectLoaded = (suite and suite:IsProductLoaded("CreshCollect")) == true
    local gamesLoaded    = (suite and suite:IsProductLoaded("CreshGames")) == true

    local summary = {
        collectLoaded = collectLoaded,
        gamesLoaded   = gamesLoaded,
        battlePass    = { hasData = false },
        achievements  = { hasData = false, categories = {} },
        collections   = { hasData = false, buckets = {}, totalUnlocked = 0, totalKnown = nil },
    }

    if COL.BattlePass then
        local Pass = COL.BattlePass
        local level, current, required, ratio = Pass:GetProgress()
        local claimed, totalLevels = Pass:GetClaimedRewardCount()
        summary.battlePass = {
            hasData      = true,
            level        = level,
            maxLevel     = Pass.maxLevel,
            current      = current,
            required     = required,
            ratio        = safeRatio(current, required),
            claimed      = claimed,
            totalLevels  = totalLevels,
            claimedRatio = safeRatio(claimed, totalLevels),
        }
    end

    if COL.Achievements then
        local Ach = COL.Achievements
        local unlocked, total = Ach:GetCounts()
        summary.achievements.hasData = true
        summary.achievements.unlocked = unlocked
        summary.achievements.total = total
        summary.achievements.ratio = safeRatio(unlocked, total)
        for _, category in ipairs(Ach.categoryOrder or {}) do
            local catUnlocked, catTotal = Ach:GetCounts(category)
            local missingAddon = Ach._TESTONLY_CategoryMissingAddon and Ach._TESTONLY_CategoryMissingAddon(category) or nil
            summary.achievements.categories[#summary.achievements.categories + 1] = {
                key = category,
                label = Ach.categoryNames and Ach.categoryNames[category] or category,
                unlocked = catUnlocked,
                total = catTotal,
                ratio = safeRatio(catUnlocked, catTotal),
                missingAddon = missingAddon,
            }
        end
    end

    if type(CreshCollectDB) == "table" and type(CreshCollectDB.collections) == "table" then
        local col = CreshCollectDB.collections
        summary.collections.hasData = true
        local function countKeys(t)
            local n = 0
            for _ in pairs(t or {}) do n = n + 1 end
            return n
        end
        local themesUnlocked      = countKeys(col.themes)
        local backgroundsUnlocked = countKeys(col.backgrounds)
        local decksUnlocked       = countKeys(col.cardDecks)
        local armourUnlocked      = countKeys(col.dungeonArmour)
        local cosmeticsUnlocked   = countKeys(col.cosmetics)

        -- Totals for these three buckets live in CreshGames' own definitions
        -- (Tetris theme/background counts, the premium card deck list) --
        -- only known when CreshGames is bridged in. dungeonArmour/cosmetics
        -- have no equivalent "how many exist" accessor anywhere in the
        -- codebase today, so they're shown unlocked-only (handled cleanly by
        -- ratioText/safeRatio's nil-total path), per "per-category
        -- completion where supported by existing data".
        local themesTotal, backgroundsTotal, decksTotal
        if gamesLoaded then
            if CC.Tetris and CC.Tetris.GetThemeCount then themesTotal = CC.Tetris:GetThemeCount() end
            if CC.Tetris and CC.Tetris.GetBackgroundThemeCount then backgroundsTotal = CC.Tetris:GetBackgroundThemeCount() end
            if CC.CardDecks and CC.CardDecks.premiumOrder then decksTotal = #CC.CardDecks.premiumOrder end
        end

        local buckets = {
            { key = "themes",        label = "Tetris Themes",     unlocked = themesUnlocked,      total = themesTotal },
            { key = "backgrounds",   label = "Tetris Backgrounds", unlocked = backgroundsUnlocked, total = backgroundsTotal },
            { key = "cardDecks",     label = "Card Decks",        unlocked = decksUnlocked,        total = decksTotal },
            { key = "dungeonArmour", label = "Dungeon Armour",    unlocked = armourUnlocked,       total = nil },
            { key = "cosmetics",     label = "Cosmetics",         unlocked = cosmeticsUnlocked,    total = nil },
        }
        for _, bucket in ipairs(buckets) do
            bucket.ratio = bucket.total and safeRatio(bucket.unlocked, bucket.total) or nil
            summary.collections.buckets[#summary.collections.buckets + 1] = bucket
        end

        summary.collections.totalUnlocked = themesUnlocked + backgroundsUnlocked + decksUnlocked + armourUnlocked + cosmeticsUnlocked
        if themesTotal and backgroundsTotal and decksTotal then
            summary.collections.totalKnown = themesTotal + backgroundsTotal + decksTotal
        end
    end

    -- Rework Phase 9 (Unified Progression UI): CreshGames' own Arcade Pass,
    -- Tetris/Delver Mastery and 116 achievements had no visibility anywhere
    -- outside CreshGames' own windows (its achievements in particular had
    -- none at all -- only ever surfaced as unlock toasts). Read exclusively
    -- through CreshGamesAPI, never CG.* directly, so this stays a correct
    -- cross-addon read even if CreshGames' internals change shape later.
    summary.creshGames = { hasData = false }
    if gamesLoaded and _G.CreshGamesAPI then
        local api = _G.CreshGamesAPI
        local arcadeLevel, arcadeCurrent, arcadeRequired = api.GetArcadePassProgress()
        local tetrisLevel, tetrisCurrent, tetrisRequired = api.GetGameMasteryProgress("TETRIS")
        local delverLevel, delverCurrent, delverRequired = api.GetGameMasteryProgress("DUNGEON")
        local gamesUnlocked, gamesTotal = api.GetGameAchievementCounts()
        summary.creshGames = {
            hasData = true,
            arcadePass    = { level = arcadeLevel, ratio = safeRatio(arcadeCurrent, arcadeRequired) },
            tetrisMastery = { level = tetrisLevel,  ratio = safeRatio(tetrisCurrent, tetrisRequired) },
            delverMastery = { level = delverLevel,  ratio = safeRatio(delverCurrent, delverRequired) },
            achievements  = { unlocked = gamesUnlocked, total = gamesTotal, ratio = safeRatio(gamesUnlocked, gamesTotal) },
        }
    end

    return summary
end

Overview.ratioText = ratioText
Overview.safeRatio = safeRatio
Overview.formatNumber = formatNumber

-- ============================================================
-- Standalone window (rendering layer -- consumes GetSummary() above;
-- contains no progression calculations of its own)
-- ============================================================
-- Same local-widget-helper convention as ProgressHub.lua / the Phase 6
-- standalone windows, for visual consistency across every CreshCollect
-- window. No dependency on CreshChat's UI.lua drawer helpers.

local WBACKDROP = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    tile = false, edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
}
local WFALLBACK = {
    panel       = { 0.022, 0.026, 0.034, 0.98 },
    panelSoft   = { 0.038, 0.044, 0.056, 0.98 },
    panelRaised = { 0.066, 0.074, 0.092, 1 },
    border      = { 0.105, 0.120, 0.145, 1 },
    text        = { 0.93,  0.95,  0.98,  1 },
    muted       = { 0.56,  0.61,  0.69,  1 },
    green       = { 0.18,  0.78,  0.36,  1 },
    quest       = { 1.00,  0.82,  0.26,  1 },
    blue        = { 0.13,  0.62,  0.95,  1 },
}

local function winPalette()
    local c = CC.db and CC.db.colors or {}
    return {
        panel       = c.panel       or WFALLBACK.panel,
        panelSoft   = c.panelSoft   or WFALLBACK.panelSoft,
        panelRaised = c.panelRaised or WFALLBACK.panelRaised,
        border      = c.border      or WFALLBACK.border,
        text        = WFALLBACK.text,
        muted       = WFALLBACK.muted,
        green       = WFALLBACK.green,
        quest       = c.quest       or WFALLBACK.quest,
        blue        = c.blue        or WFALLBACK.blue,
    }
end

local function winTemplateName()
    return _G.BackdropTemplateMixin and "BackdropTemplate" or nil
end

local function winApplyBackdrop(frame, bg, border)
    if not frame then return end
    if frame.SetBackdrop then frame:SetBackdrop(WBACKDROP) end
    bg = bg or WFALLBACK.panel
    border = border or WFALLBACK.border
    if frame.SetBackdropColor then frame:SetBackdropColor(bg[1], bg[2], bg[3], bg[4] or 1) end
    if frame.SetBackdropBorderColor then frame:SetBackdropBorderColor(border[1], border[2], border[3], border[4] or 1) end
end

local function winCreateText(parent, size, color, justify)
    local f = parent:CreateFontString(nil, "OVERLAY")
    f:SetFont(_G.STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", size or 11, "")
    color = color or WFALLBACK.text
    f:SetTextColor(color[1], color[2], color[3], color[4] or 1)
    f:SetJustifyH(justify or "LEFT")
    f:SetJustifyV("MIDDLE")
    return f
end

local function winDarken(color, amount)
    amount = tonumber(amount) or 0.18
    return {
        max(0, (color[1] or 0) - amount),
        max(0, (color[2] or 0) - amount),
        max(0, (color[3] or 0) - amount),
        color[4] or 1,
    }
end

local function winCreateButton(parent, label, width, height, callback)
    local btn = CreateFrame("Button", nil, parent, winTemplateName())
    btn:SetSize(width or 80, height or 24)
    local colors = winPalette()
    winApplyBackdrop(btn, colors.panelRaised, colors.border)
    btn.label = winCreateText(btn, 9, colors.text, "CENTER")
    btn.label:SetAllPoints()
    btn.label:SetText(label or "")
    btn:SetScript("OnClick", function(selfBtn, ...) if callback then callback(selfBtn, ...) end end)
    btn:SetScript("OnEnter", function(selfBtn)
        local c = winPalette()
        winApplyBackdrop(selfBtn, winDarken(c.quest or c.blue, 0.22), c.quest or c.blue)
    end)
    btn:SetScript("OnLeave", function(selfBtn)
        local c = winPalette()
        winApplyBackdrop(selfBtn, c.panelRaised, c.border)
    end)
    return btn
end

local function winSetBarValue(bar, ratio, color)
    if not bar then return end
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(ratio or 0)
    if color then bar:SetStatusBarColor(color[1], color[2], color[3], 0.95) end
end

local function winMakeBar(parent)
    local back = CreateFrame("Frame", nil, parent, winTemplateName())
    back:SetHeight(14)
    local colors = winPalette()
    winApplyBackdrop(back, colors.panel, colors.border)
    local bar = CreateFrame("StatusBar", nil, back)
    bar:SetPoint("TOPLEFT", back, "TOPLEFT", 1, -1)
    bar:SetPoint("BOTTOMRIGHT", back, "BOTTOMRIGHT", -1, 1)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    winSetBarValue(bar, 0, colors.blue)
    back.bar = bar
    return back
end

function Overview:IsWindowOpen()
    return self.window and self.window:IsShown()
end

function Overview:ToggleWindow()
    if not self:BuildWindow() then return end
    if self.window:IsShown() then self:CloseWindow() else self:OpenWindow() end
end

function Overview:OpenWindow()
    if not self:BuildWindow() then return end
    self.window:Show()
    self:RefreshWindow()
    if CC.UI and CC.UI.FocusWindow then CC.UI:FocusWindow(self.window) end
    if CC.UI and CC.UI.RefreshLauncherButtonStates then CC.UI:RefreshLauncherButtonStates() end
end

function Overview:CloseWindow()
    if self.window then self.window:Hide() end
    if CC.UI and CC.UI.RefreshLauncherButtonStates then CC.UI:RefreshLauncherButtonStates() end
end

-- Builds one "card" section (title + body area) and returns it so
-- RefreshWindow can populate the pieces it created.
local function buildCard(parent, title, yOffset, height)
    local card = CreateFrame("Frame", nil, parent, winTemplateName())
    card:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, yOffset)
    card:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, yOffset)
    card:SetHeight(height)
    local colors = winPalette()
    winApplyBackdrop(card, colors.panelSoft, colors.border)
    card.title = winCreateText(card, 11, colors.text, "LEFT")
    card.title:SetPoint("TOPLEFT", card, "TOPLEFT", 8, -8)
    card.title:SetText(title)
    return card
end

function Overview:BuildWindow()
    if self.window then return self.window end
    local colors = winPalette()

    local frame = CreateFrame("Frame", "CreshCollectProgressOverviewFrame", UIParent, winTemplateName())
    frame:SetSize(420, 720)
    local savedPos = CC.db and CC.db.positions and CC.db.positions.progressOverviewWindow
    if savedPos then
        frame:SetPoint(savedPos.point or "CENTER", UIParent, savedPos.relPoint or "CENTER",
            tonumber(savedPos.x) or 0, tonumber(savedPos.y) or 0)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    winApplyBackdrop(frame, colors.panel, colors.border)
    frame:Hide()
    self.window = frame

    frame:SetScript("OnMouseDown", function(selfFrame, btn)
        if btn == "LeftButton" then
            local uiSvc = _G.CreshSuiteUI or CC.UI
            if uiSvc and uiSvc.FocusWindow then uiSvc:FocusWindow(selfFrame) end
            selfFrame:StartMoving()
        end
    end)
    frame:SetScript("OnMouseUp", function(selfFrame)
        selfFrame:StopMovingOrSizing()
        if CC.db then
            CC.db.positions = CC.db.positions or {}
            local point, _, relPoint, x, y = selfFrame:GetPoint()
            CC.db.positions.progressOverviewWindow = { point = point, relPoint = relPoint, x = floor(x or 0), y = floor(y or 0) }
        end
    end)
    frame:SetScript("OnHide", function()
        if CC.UI and CC.UI.RefreshLauncherButtonStates then CC.UI:RefreshLauncherButtonStates() end
    end)
    -- Prefer the shared, addon-agnostic bridge so this window shares one
    -- z-order with every other suite window even when CreshChat is absent.
    local uiSvc = _G.CreshSuiteUI or CC.UI
    if uiSvc and uiSvc.InstallWindowFocus then uiSvc:InstallWindowFocus(frame) end

    -- Header
    local header = CreateFrame("Frame", nil, frame, winTemplateName())
    header:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    header:SetHeight(34)
    winApplyBackdrop(header, winDarken(colors.quest, 0.32), colors.quest)
    local titleLabel = winCreateText(header, 11, colors.text, "LEFT")
    titleLabel:SetPoint("TOPLEFT", header, "TOPLEFT", 10, -10)
    titleLabel:SetText("PROGRESS OVERVIEW")
    local closeBtn = CreateFrame("Button", nil, header, winTemplateName())
    closeBtn:SetSize(22, 22)
    closeBtn:SetPoint("TOPRIGHT", header, "TOPRIGHT", -4, -6)
    winApplyBackdrop(closeBtn, colors.panelRaised, colors.border)
    local closeLbl = winCreateText(closeBtn, 9, colors.muted, "CENTER")
    closeLbl:SetAllPoints()
    closeLbl:SetText("X")
    closeBtn:SetScript("OnClick", function() Overview:CloseWindow() end)

    -- Nav row: keep the older World/Quest/Combat tracking window reachable.
    local navBtn = winCreateButton(header, "WORLD / QUESTS / COMBAT", 150, 22, function()
        if COL.ProgressHub and COL.ProgressHub.Toggle then COL.ProgressHub:Toggle() end
    end)
    navBtn:SetPoint("RIGHT", closeBtn, "LEFT", -6, 0)

    local scroll = CreateFrame("ScrollFrame", nil, frame)
    scroll:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -8)
    scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 8)
    scroll:EnableMouseWheel(true)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetWidth(392)
    content:SetHeight(704)
    scroll:SetScrollChild(content)
    scroll:SetScript("OnMouseWheel", function(selfScroll, delta)
        local current = selfScroll:GetVerticalScroll() or 0
        local maximum = selfScroll:GetVerticalScrollRange() or 0
        selfScroll:SetVerticalScroll(max(0, min(maximum, current - delta * 42)))
    end)
    self.content = content

    -- Azeroth Chronicle card
    local bpCard = buildCard(content, "AZEROTH CHRONICLE", 0, 118)
    bpCard.levelText = winCreateText(bpCard, 14, colors.text, "LEFT")
    bpCard.levelText:SetPoint("TOPLEFT", bpCard.title, "BOTTOMLEFT", 0, -6)
    bpCard.progressLabel = winCreateText(bpCard, 8, colors.muted, "LEFT")
    bpCard.progressLabel:SetPoint("TOPLEFT", bpCard.levelText, "BOTTOMLEFT", 0, -8)
    bpCard.progressBar = winMakeBar(bpCard)
    bpCard.progressBar:SetPoint("TOPLEFT", bpCard.progressLabel, "BOTTOMLEFT", 0, -3)
    bpCard.progressBar:SetPoint("RIGHT", bpCard, "RIGHT", -8, 0)
    bpCard.rewardsLabel = winCreateText(bpCard, 8, colors.muted, "LEFT")
    bpCard.rewardsLabel:SetPoint("TOPLEFT", bpCard.progressBar, "BOTTOMLEFT", 0, -8)
    bpCard.rewardsBar = winMakeBar(bpCard)
    bpCard.rewardsBar:SetPoint("TOPLEFT", bpCard.rewardsLabel, "BOTTOMLEFT", 0, -3)
    bpCard.rewardsBar:SetPoint("RIGHT", bpCard, "RIGHT", -8, 0)
    bpCard.viewBtn = winCreateButton(bpCard, "VIEW CHRONICLE →", 130, 22, function()
        if COL.BattlePass and COL.BattlePass.ToggleWindow then COL.BattlePass:ToggleWindow() end
    end)
    bpCard.viewBtn:SetPoint("TOPRIGHT", bpCard, "TOPRIGHT", -8, -8)
    self.bpCard = bpCard

    -- Achievements card
    local achCard = buildCard(content, "ACHIEVEMENTS", -126, 210)
    achCard.summaryLabel = winCreateText(achCard, 8, colors.muted, "LEFT")
    achCard.summaryLabel:SetPoint("TOPLEFT", achCard.title, "BOTTOMLEFT", 0, -6)
    achCard.summaryBar = winMakeBar(achCard)
    achCard.summaryBar:SetPoint("TOPLEFT", achCard.summaryLabel, "BOTTOMLEFT", 0, -3)
    achCard.summaryBar:SetPoint("RIGHT", achCard, "RIGHT", -8, 0)
    achCard.categoryRows = {}
    for i = 1, 5 do
        local row = CreateFrame("Frame", nil, achCard)
        row:SetPoint("TOPLEFT", achCard.summaryBar, "BOTTOMLEFT", 0, -8 - ((i - 1) * 22))
        row:SetPoint("RIGHT", achCard, "RIGHT", -8, 0)
        row:SetHeight(18)
        row.label = winCreateText(row, 8, colors.muted, "LEFT")
        row.label:SetPoint("LEFT", row, "LEFT", 0, 0)
        row.label:SetWidth(140)
        row.value = winCreateText(row, 8, colors.text, "RIGHT")
        row.value:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        achCard.categoryRows[i] = row
    end
    achCard.viewBtn = winCreateButton(achCard, "VIEW ACHIEVEMENTS →", 140, 22, function()
        if COL.Achievements and COL.Achievements.ToggleWindow then COL.Achievements:ToggleWindow() end
    end)
    achCard.viewBtn:SetPoint("TOPRIGHT", achCard, "TOPRIGHT", -8, -8)
    self.achCard = achCard

    -- Collections card
    local colCard = buildCard(content, "COLLECTIONS", -344, 190)
    colCard.notice = winCreateText(colCard, 8, colors.muted, "LEFT")
    colCard.notice:SetPoint("TOPLEFT", colCard.title, "BOTTOMLEFT", 0, -6)
    colCard.notice:SetPoint("RIGHT", colCard, "RIGHT", -8, 0)
    colCard.notice:SetWordWrap(true)
    colCard.bucketRows = {}
    for i = 1, 5 do
        local row = CreateFrame("Frame", nil, colCard)
        row:SetPoint("TOPLEFT", colCard.title, "BOTTOMLEFT", 0, -22 - ((i - 1) * 22))
        row:SetPoint("RIGHT", colCard, "RIGHT", -8, 0)
        row:SetHeight(18)
        row.label = winCreateText(row, 8, colors.muted, "LEFT")
        row.label:SetPoint("LEFT", row, "LEFT", 0, 0)
        row.label:SetWidth(140)
        row.value = winCreateText(row, 8, colors.text, "RIGHT")
        row.value:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        colCard.bucketRows[i] = row
    end
    self.colCard = colCard

    -- CreshGames card (Rework Phase 9): Arcade Pass + Tetris/Delver Mastery
    -- levels + achievement count, read via CreshGamesAPI only.
    local gamesCard = buildCard(content, "ARCADE & MASTERY (CreshGames)", -542, 150)
    gamesCard.notice = winCreateText(gamesCard, 8, colors.muted, "LEFT")
    gamesCard.notice:SetPoint("TOPLEFT", gamesCard.title, "BOTTOMLEFT", 0, -6)
    gamesCard.notice:SetPoint("RIGHT", gamesCard, "RIGHT", -8, 0)
    gamesCard.notice:SetWordWrap(true)
    gamesCard.rows = {}
    for i = 1, 4 do
        local row = CreateFrame("Frame", nil, gamesCard)
        row:SetPoint("TOPLEFT", gamesCard.title, "BOTTOMLEFT", 0, -22 - ((i - 1) * 22))
        row:SetPoint("RIGHT", gamesCard, "RIGHT", -8, 0)
        row:SetHeight(18)
        row.label = winCreateText(row, 8, colors.muted, "LEFT")
        row.label:SetPoint("LEFT", row, "LEFT", 0, 0)
        row.label:SetWidth(140)
        row.value = winCreateText(row, 8, colors.text, "RIGHT")
        row.value:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        gamesCard.rows[i] = row
    end
    gamesCard.viewBtn = winCreateButton(gamesCard, "OPEN ARCADE PASS →", 140, 22, function()
        local suite = _G.CreshSuite
        local svc = suite and suite.GetService and suite:GetService("OpenArcadePass")
        if svc then svc() end
    end)
    gamesCard.viewBtn:SetPoint("TOPRIGHT", gamesCard, "TOPRIGHT", -8, -8)
    self.gamesCard = gamesCard

    return frame
end

-- Applies a uniform "unavailable" treatment (dimmed, muted title) to a card
-- when its underlying data genuinely can't be computed right now.
local function setCardAvailable(card, available)
    card:SetAlpha(available and 1 or 0.5)
end

local function colCardNotice(self, text)
    if self.colCard and self.colCard.notice then self.colCard.notice:SetText(text or "") end
end

function Overview:RefreshWindow()
    if not self.window or not self.window:IsShown() then return end
    local colors = winPalette()
    local summary = self:GetSummary()

    -- Battle Pass card
    local bp = summary.battlePass
    setCardAvailable(self.bpCard, bp.hasData)
    if bp.hasData then
        self.bpCard.levelText:SetText("LEVEL " .. bp.level .. " / " .. bp.maxLevel)
        self.bpCard.progressLabel:SetText("Progress to next level: " .. ratioText(bp.current, bp.required))
        winSetBarValue(self.bpCard.progressBar.bar, bp.ratio, colors.blue)
        self.bpCard.rewardsLabel:SetText("Rewards unlocked: " .. ratioText(bp.claimed, bp.totalLevels))
        winSetBarValue(self.bpCard.rewardsBar.bar, bp.claimedRatio, colors.green)
    else
        self.bpCard.levelText:SetText("Unavailable")
        self.bpCard.progressLabel:SetText("")
        self.bpCard.rewardsLabel:SetText("")
    end

    -- Achievements card
    local ach = summary.achievements
    setCardAvailable(self.achCard, ach.hasData)
    if ach.hasData then
        self.achCard.summaryLabel:SetText("Completed: " .. ratioText(ach.unlocked, ach.total))
        winSetBarValue(self.achCard.summaryBar.bar, ach.ratio, colors.quest)
        for i, row in ipairs(self.achCard.categoryRows) do
            local cat = ach.categories[i]
            if cat then
                row.label:SetText(cat.label)
                if cat.missingAddon then
                    row.value:SetText("REQUIRES " .. string.upper(cat.missingAddon))
                    row.value:SetTextColor(colors.muted[1], colors.muted[2], colors.muted[3], 1)
                else
                    row.value:SetText(ratioText(cat.unlocked, cat.total))
                    row.value:SetTextColor(colors.text[1], colors.text[2], colors.text[3], 1)
                end
                row:Show()
            else
                row:Hide()
            end
        end
    else
        self.achCard.summaryLabel:SetText("")
        for _, row in ipairs(self.achCard.categoryRows) do row:Hide() end
    end

    -- Collections card
    local col = summary.collections
    setCardAvailable(self.colCard, col.hasData)
    if col.hasData then
        if summary.gamesLoaded then
            colCardNotice(self, "")
        else
            colCardNotice(self, "Totals for Tetris themes/backgrounds and card decks require CreshGames. Unlocked counts are always shown.")
        end
        for i, row in ipairs(self.colCard.bucketRows) do
            local bucket = col.buckets[i]
            if bucket then
                row.label:SetText(bucket.label)
                row.value:SetText(ratioText(bucket.unlocked, bucket.total))
                row:Show()
            else
                row:Hide()
            end
        end
    else
        colCardNotice(self, "")
        for _, row in ipairs(self.colCard.bucketRows) do row:Hide() end
    end

    -- CreshGames card
    local cg = summary.creshGames
    setCardAvailable(self.gamesCard, cg.hasData)
    if cg.hasData then
        self.gamesCard.notice:SetText("")
        local rows = self.gamesCard.rows
        rows[1].label:SetText("Arcade Pass")
        rows[1].value:SetText("Level " .. tostring(cg.arcadePass.level))
        rows[2].label:SetText("Tetris Mastery")
        rows[2].value:SetText("Level " .. tostring(cg.tetrisMastery.level))
        rows[3].label:SetText("Delver Mastery")
        rows[3].value:SetText("Level " .. tostring(cg.delverMastery.level))
        rows[4].label:SetText("Achievements")
        rows[4].value:SetText(ratioText(cg.achievements.unlocked, cg.achievements.total))
        for _, row in ipairs(rows) do row:Show() end
    else
        self.gamesCard.notice:SetText("Requires CreshGames.")
        for _, row in ipairs(self.gamesCard.rows) do row:Hide() end
    end
end
