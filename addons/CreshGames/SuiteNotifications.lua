-- shared/SuiteNotifications.lua  --  CreshSuite notification service  --  Bridge v1
--
-- One physical copy of this file ships inside each suite addon's folder,
-- same convention as shared/Suite.lua, shared/Launcher.lua and
-- shared/CreshUI.lua. Whichever of CreshChat, CreshGames, or CreshCollect
-- finishes loading first builds the one shared _G.CreshSuiteNotifications
-- table (registration contract AND card renderer); every later load (the
-- other two addons, if present) is a no-op against the same table.
--
-- Registration/enablement queries never hardcode an addon name: any source
-- can plug in its own richer enablement check via RegisterEnabledQuery.
-- The card renderer (buildCard/populateCard/ShowCard/RepositionCards/
-- animation) reads CreshChat's existing settings (CC.db.ui.*, sound
-- settings, launcher-relative anchor) when CreshChat is loaded, preserving
-- them exactly, and falls back to a small addon-agnostic own-storage table
-- (mirroring shared/Launcher.lua's getLauncherDB reuse-whichever-db trick)
-- otherwise.
--
-- Compatible with WoW TBC Anniversary (Lua 5.1, no io/os/require).

local BRIDGE_VERSION = 1

-- ----------------------------------------------------------------------------
-- Idempotency guard (mirrors shared/Launcher.lua exactly)
-- ----------------------------------------------------------------------------
if _G.CreshSuiteNotifications then
    local existing = _G.CreshSuiteNotifications
    if type(existing.BRIDGE_VERSION) == "number" and existing.BRIDGE_VERSION == BRIDGE_VERSION then
        return -- already built by an earlier-loaded addon; expected for addons 2 and 3
    end
    return -- incompatible version already occupying the global; keep the running copy
end

local Notif = {}
_G.CreshSuiteNotifications = Notif
Notif.BRIDGE_VERSION = BRIDGE_VERSION

local floor, max, min = math.floor, math.max, math.min
local upper = string.upper

-- ----------------------------------------------------------------------------
-- Registration
-- ----------------------------------------------------------------------------

local sources        = {}  -- [SOURCE_ADDON]           = { label, categories = {} }
local categories     = {}  -- [SOURCE_ADDON:CATEGORY]  = { sourceAddon, key, label, description, priority, soundEnabled }
local enabledQueries = {}  -- [SOURCE_ADDON] = fn(categoryKey) -> boolean

function Notif:RegisterSource(sourceAddon, label)
    sourceAddon = upper(tostring(sourceAddon or ""))
    if sourceAddon == "" then return false end
    if not sources[sourceAddon] then
        sources[sourceAddon] = { label = tostring(label or sourceAddon), categories = {} }
    end
    return true
end

-- options = { priority = "NORMAL", soundEnabled = true }
function Notif:RegisterCategory(sourceAddon, categoryKey, label, description, options)
    sourceAddon = upper(tostring(sourceAddon or ""))
    categoryKey = upper(tostring(categoryKey or ""))
    if sourceAddon == "" or categoryKey == "" then return false end
    if not sources[sourceAddon] then self:RegisterSource(sourceAddon) end
    options = type(options) == "table" and options or {}
    local priority = upper(tostring(options.priority or "NORMAL"))
    if priority ~= "CRITICAL" and priority ~= "HIGH" and priority ~= "NORMAL" and priority ~= "LOW" then
        priority = "NORMAL"
    end
    local fullKey = sourceAddon .. ":" .. categoryKey
    categories[fullKey] = {
        sourceAddon  = sourceAddon,
        key          = categoryKey,
        label        = tostring(label or categoryKey),
        description  = tostring(description or ""),
        priority     = priority,
        soundEnabled = options.soundEnabled ~= false,
    }
    sources[sourceAddon].categories[categoryKey] = fullKey
    return true
end

-- Lets a source plug in its own richer per-category enablement check instead
-- of the generic notificationSources table lookup below. fn receives the
-- upper-cased category key and returns false to suppress, anything else to
-- allow (nil/true/etc). Wrapped in pcall by IsCategoryEnabled so a throwing
-- query can never break notifications for every other source.
function Notif:RegisterEnabledQuery(sourceAddon, fn)
    sourceAddon = upper(tostring(sourceAddon or ""))
    if sourceAddon == "" or type(fn) ~= "function" then return false end
    enabledQueries[sourceAddon] = fn
    return true
end

function Notif:GetRegisteredSources()
    return sources
end

function Notif:GetRegisteredCategories(sourceAddon)
    if sourceAddon then
        sourceAddon = upper(tostring(sourceAddon))
        local src = sources[sourceAddon]
        if not src then return {} end
        local result = {}
        for key, fullKey in pairs(src.categories) do
            result[key] = categories[fullKey]
        end
        return result
    end
    return categories
end

-- ----------------------------------------------------------------------------
-- Own-storage: reuse whichever suite addon's SavedVariables table exists, in
-- a fixed priority order, under its own sub-table -- identical convention to
-- shared/Launcher.lua's getLauncherDB(). Used only when no richer
-- CreshChat-hosted setting is available, so sound and card visibility stay
-- independently configurable even with CreshChat absent.
-- ----------------------------------------------------------------------------

local function getOwnDB()
    local db = _G.CreshChatDB or _G.CreshGamesDB or _G.CreshCollectDB
    if not db then return nil end
    if type(db.suiteNotifications) ~= "table" then
        db.suiteNotifications = { cardsEnabled = true, soundEnabled = true }
    end
    return db.suiteNotifications
end

function Notif:SetCardsEnabled(enabled)
    local own = getOwnDB()
    if own then own.cardsEnabled = enabled and true or false end
end

function Notif:SetSoundEnabled(enabled)
    local own = getOwnDB()
    if own then own.soundEnabled = enabled and true or false end
end

-- ----------------------------------------------------------------------------
-- Enable queries
-- ----------------------------------------------------------------------------

function Notif:IsSourceEnabled(sourceAddon)
    sourceAddon = upper(tostring(sourceAddon or ""))
    if not sources[sourceAddon] then return false end
    local cc = _G.CreshChat
    if cc and cc.IsFeatureEnabled and not cc:IsFeatureEnabled("notifications") then return false end
    return true
end

function Notif:IsCategoryEnabled(sourceAddon, categoryKey)
    sourceAddon = upper(tostring(sourceAddon or ""))
    categoryKey = upper(tostring(categoryKey or ""))
    if not self:IsSourceEnabled(sourceAddon) then return false end

    local query = enabledQueries[sourceAddon]
    if query then
        local ok, result = pcall(query, categoryKey)
        if ok and result == false then return false end
    end

    -- Per-category table shared across all sources -- lives in CreshChat's own
    -- db (the only settings UI surface that writes it today, for any source),
    -- so this lookup is a no-op until CreshChat's settings pages exist.
    local cc = _G.CreshChat
    local srcs = cc and cc.db and cc.db.notificationSources
    if srcs and srcs[sourceAddon] and srcs[sourceAddon][categoryKey] == false then
        return false
    end

    if not query then
        -- No CreshChat-hosted enabled-query for this source: fall back to the
        -- addon-agnostic own-storage toggle so cards can still be turned off
        -- without CreshChat's settings UI.
        local own = getOwnDB()
        if own and own.cardsEnabled == false then return false end
    end

    return categories[sourceAddon .. ":" .. categoryKey] ~= nil
end

function Notif:GetSettings()
    return {
        enabled    = self:IsSourceEnabled("CRESHCHAT") or true,
        sources    = sources,
        categories = categories,
    }
end

-- ----------------------------------------------------------------------------
-- Sound
-- CreshChat-sourced events are skipped here: CreshChat's own producers (chat
-- events, UI.lua's ShowGameToast/ShowBattlePassToast/ShowDungeonPassToast,
-- etc.) already call CC:PlayAlertSound themselves before Push ever runs --
-- playing it again here would double the sound. For every other source this
-- preserves the exact current behavior (every CreshGames/CreshCollect toast
-- already always played the "GAME" sound kind, regardless of which specific
-- game/pass/achievement fired).
-- ----------------------------------------------------------------------------

function Notif:PlayNotificationSound(sourceAddon, event)
    sourceAddon = upper(tostring(sourceAddon or ""))
    if sourceAddon == "CRESHCHAT" then return end
    local cc = _G.CreshChat
    if cc and cc.PlayAlertSound then
        cc:PlayAlertSound("GAME")
        return
    end
    local own = getOwnDB()
    if own and own.soundEnabled == false then return end
    if type(_G.PlaySound) == "function" then
        local kit = _G.SOUNDKIT and _G.SOUNDKIT.IG_QUEST_LIST_COMPLETE
        pcall(_G.PlaySound, kit or 888)
    end
end

-- ----------------------------------------------------------------------------
-- Profiling instrumentation (task 2) -- disabled by default, never
-- persisted, mirrors Developer.lua's testMode pattern (in-memory upvalue).
-- Cold path = AcquireCard had to buildCard(); warm path = pool hit or an
-- existing coalesce match. Reported separately per GetProfileReport().
-- ----------------------------------------------------------------------------

local profilingEnabled = false
local profile = { cold = {}, warm = {} }

local function recordStage(bucket, stage, elapsedMs)
    local b = profile[bucket]
    local s = b[stage]
    if not s then s = { count = 0, total = 0, max = 0 }; b[stage] = s end
    s.count = s.count + 1
    s.total = s.total + elapsedMs
    if elapsedMs > s.max then s.max = elapsedMs end
end

local function now()
    if profilingEnabled and type(_G.debugprofilestop) == "function" then return _G.debugprofilestop() end
    return nil
end

local function finish(bucket, stage, startedAt)
    if not startedAt then return end
    recordStage(bucket, stage, _G.debugprofilestop() - startedAt)
end

function Notif:SetProfilingEnabled(enabled)
    profilingEnabled = enabled and true or false
end

function Notif:IsProfilingEnabled()
    return profilingEnabled
end

function Notif:ResetProfile()
    profile.cold, profile.warm = {}, {}
end

function Notif:GetProfileReport()
    local lines = {}
    for _, bucket in ipairs({ "cold", "warm" }) do
        local stages = {}
        for stage in pairs(profile[bucket]) do stages[#stages + 1] = stage end
        table.sort(stages)
        for _, stage in ipairs(stages) do
            local s = profile[bucket][stage]
            lines[#lines + 1] = string.format("%s/%s: n=%d avg=%.2fms max=%.2fms",
                bucket, stage, s.count, s.total / s.count, s.max)
        end
    end
    if #lines == 0 then return "No notification profiling samples recorded yet." end
    return table.concat(lines, "\n")
end

-- ----------------------------------------------------------------------------
-- Semantic accent colours  { r, g, b, a }
-- (ported unchanged from NotificationCard.lua -- fixed constants, never
-- depended on CC.db.colors, so already addon-agnostic)
-- ----------------------------------------------------------------------------

local ACCENT = {
    ONLINE      = { 0.28, 0.85, 0.48, 1 },
    OFFLINE     = { 0.48, 0.52, 0.60, 1 },
    SUCCESS     = { 0.28, 0.85, 0.48, 1 },
    WHISPER     = { 0.25, 0.82, 0.90, 1 },
    PARTY       = { 0.28, 0.55, 1.00, 1 },
    GUILD       = { 0.38, 0.88, 0.55, 1 },
    GAME        = { 0.68, 0.32, 1.00, 1 },
    ACHIEVEMENT = { 0.95, 0.76, 0.22, 1 },
    REWARD      = { 1.00, 0.72, 0.15, 1 },
    BATTLEPASS  = { 0.95, 0.76, 0.22, 1 },
    DUNGEONPASS = { 0.38, 0.88, 0.55, 1 },
    WARNING     = { 1.00, 0.68, 0.20, 1 },
    ERROR       = { 1.00, 0.32, 0.30, 1 },
    INFO        = { 0.44, 0.64, 0.94, 1 },
}
local ACCENT_DEFAULT = { 0.44, 0.64, 0.94, 1 }

local CATEGORY_ACCENT = {
    WHISPER = ACCENT.WHISPER, BN_WHISPER = ACCENT.WHISPER,
    GUILD   = ACCENT.GUILD,   OFFICER    = ACCENT.GUILD,
    PARTY_INVITE = ACCENT.PARTY, PARTY_MESSAGE = ACCENT.PARTY,
    FRIEND  = ACCENT.ONLINE,  PRESENCE   = ACCENT.ONLINE,
    GAME    = ACCENT.GAME,    BATTLE_PASS = ACCENT.BATTLEPASS,
    GAME_INVITE = ACCENT.GAME, GAME_RESULT = ACCENT.GAME,
    CHALLENGE   = ACCENT.GAME, MULTIPLAYER_EVENT = ACCENT.GAME,
    REWARD      = ACCENT.REWARD, ACHIEVEMENT = ACCENT.ACHIEVEMENT,
    ACHIEVEMENT_PROGRESS = ACCENT.ACHIEVEMENT,
    COLLECTION_UNLOCK = ACCENT.REWARD, COSMETIC_REWARD = ACCENT.REWARD,
    MILESTONE = ACCENT.REWARD, EXPLORATION = ACCENT.REWARD, THEME = ACCENT.REWARD,
}

local function resolveAccent(status, category)
    return ACCENT[upper(tostring(status or ""))]
        or CATEGORY_ACCENT[upper(tostring(category or ""))]
        or ACCENT_DEFAULT
end

-- ----------------------------------------------------------------------------
-- Layout and animation constants (unchanged from NotificationCard.lua)
-- ----------------------------------------------------------------------------

local CARD_W       = 300
local CARD_H       = 72
local ICON_SIZE    = 40
local BADGE_SIZE   = 18
local ACCENT_H     = 3
local BTN_W, BTN_H = 58, 18
local STACK_GAP    = 6
local ANIM_DUR     = 0.20
local ANIM_OFFSET  = 44
local DUR_NORMAL   = 8
local DUR_HIGH     = 14

-- ----------------------------------------------------------------------------
-- Runtime config helpers -- read CreshChat's existing settings when present
-- (preserves every setting exactly), safe defaults otherwise. Deliberately
-- mirrors NotificationCard.lua's exact field names/fallbacks -- including
-- notifMaxVisible's pre-existing disconnect from the "Max visible" slider
-- (which actually writes cardMaxVisible) -- so behavior doesn't shift for
-- existing CreshChat users as a side effect of this move.
-- ----------------------------------------------------------------------------

local function ccDB()
    local cc = _G.CreshChat
    return cc and cc.db
end

local function getDir()
    local db = ccDB()
    if not db or not db.ui then return "UP" end
    local d = upper(tostring(db.ui.notifStackDirection or db.ui.cardStack or "UP"))
    if d ~= "UP" and d ~= "DOWN" and d ~= "LEFT" and d ~= "RIGHT" then return "UP" end
    return d
end

local function getMaxVisible()
    local db = ccDB()
    if not db or not db.ui then return 3 end
    return max(1, min(10, floor(tonumber(db.ui.notifMaxVisible) or 3)))
end

local function getScale()
    local db = ccDB()
    if not db or not db.ui then return 0.95 end
    return max(0.65, min(1.50, tonumber(db.ui.notificationScale) or 0.95))
end

local function getBase()
    local x, y = 18, 148
    local cc = _G.CreshChat
    if cc and cc.UI and cc.UI.GetNotificationHubAnchor then
        x, y = cc.UI:GetNotificationHubAnchor()
    end
    return x, y
end

-- ----------------------------------------------------------------------------
-- Frame helpers (unchanged from NotificationCard.lua)
-- ----------------------------------------------------------------------------

local FONT        = _G.STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
local BD_TEMPLATE = _G.BackdropTemplateMixin and "BackdropTemplate" or nil
local CARD_BD = {
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
}
local BTN_BD = {
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 8, edgeSize = 8,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
}

local function applyBackdrop(f, bd, r, g, b, a, er, eg, eb, ea)
    if f.SetBackdrop then
        f:SetBackdrop(bd)
        f:SetBackdropColor(r, g, b, a)
        f:SetBackdropBorderColor(er, eg, eb, ea)
    end
end

local function makeFont(parent, size, r, g, b, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(FONT, size, "")
    fs:SetTextColor(r, g, b, 1)
    fs:SetJustifyH(justify or "LEFT")
    return fs
end

local function makeButton(parent, labelText, w, h, onClick)
    local btn = CreateFrame("Button", nil, parent, BD_TEMPLATE)
    btn:SetSize(w, h)
    applyBackdrop(btn, BTN_BD, 0.12, 0.14, 0.18, 0.90, 0.26, 0.30, 0.38, 0.70)
    btn.label = makeFont(btn, 9, 0.85, 0.88, 0.92, "CENTER")
    btn.label:SetAllPoints(btn)
    btn.label:SetText(labelText)
    btn:SetScript("OnClick", onClick)
    btn:SetScript("OnEnter", function(self)
        if self.SetBackdropBorderColor then self:SetBackdropBorderColor(0.50, 0.62, 0.90, 1) end
    end)
    btn:SetScript("OnLeave", function(self)
        if self.SetBackdropBorderColor then self:SetBackdropBorderColor(0.26, 0.30, 0.38, 0.70) end
    end)
    return btn
end

-- ----------------------------------------------------------------------------
-- Card construction (unchanged from NotificationCard.lua)
-- ----------------------------------------------------------------------------

local function buildCard()
    local card = CreateFrame("Button", nil, UIParent, BD_TEMPLATE)
    card:SetSize(CARD_W, CARD_H)
    card:SetScale(0.95)
    card:SetClampedToScreen(false)
    card:EnableMouse(true)
    card:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    card:SetFrameStrata("FULLSCREEN_DIALOG")
    card:Hide()
    applyBackdrop(card, CARD_BD, 0.08, 0.09, 0.11, 0.92, 0.18, 0.20, 0.25, 0.80)

    card.iconBg = card:CreateTexture(nil, "BACKGROUND")
    card.iconBg:SetSize(ICON_SIZE, ICON_SIZE)
    card.iconBg:SetPoint("LEFT", card, "LEFT", 10, 0)
    card.iconBg:SetColorTexture(0.12, 0.14, 0.18, 1)

    card.icon = card:CreateTexture(nil, "ARTWORK")
    card.icon:SetSize(ICON_SIZE - 4, ICON_SIZE - 4)
    card.icon:SetPoint("CENTER", card.iconBg, "CENTER", 0, 0)
    card.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    card.icon:Hide()

    card.badge = card:CreateTexture(nil, "OVERLAY")
    card.badge:SetSize(BADGE_SIZE, BADGE_SIZE)
    card.badge:SetPoint("BOTTOMRIGHT", card.iconBg, "BOTTOMRIGHT", 3, -3)
    card.badge:Hide()

    card.iconInitial = makeFont(card, 15, 0.72, 0.76, 0.85, "CENTER")
    card.iconInitial:SetPoint("CENTER", card.iconBg, "CENTER", 0, 0)

    card.title = makeFont(card, 11, 0.92, 0.93, 0.95, "LEFT")
    card.title:SetPoint("TOPLEFT", card.iconBg, "TOPRIGHT",  9, -2)
    card.title:SetPoint("RIGHT",   card,        "RIGHT",   -46,  0)
    if card.title.SetMaxLines then card.title:SetMaxLines(1) end

    card.timeText = makeFont(card, 9, 0.48, 0.52, 0.58, "RIGHT")
    card.timeText:SetPoint("TOPRIGHT", card, "TOPRIGHT", -8, -7)
    card.timeText:SetWidth(40)

    card.detail = makeFont(card, 10, 0.60, 0.63, 0.68, "LEFT")
    card.detail:SetPoint("TOPLEFT", card.title,  "BOTTOMLEFT", 0, -3)
    card.detail:SetPoint("RIGHT",   card,        "RIGHT",     -8,  0)
    if card.detail.SetMaxLines then card.detail:SetMaxLines(2) end
    if card.detail.SetWordWrap  then card.detail:SetWordWrap(true) end

    card.accentBar = card:CreateTexture(nil, "ARTWORK")
    card.accentBar:SetPoint("BOTTOMLEFT",  card, "BOTTOMLEFT",   1, 1)
    card.accentBar:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -1, 1)
    card.accentBar:SetHeight(ACCENT_H)
    card.accentBar:SetColorTexture(ACCENT_DEFAULT[1], ACCENT_DEFAULT[2], ACCENT_DEFAULT[3], 1)

    card.btnAccept = makeButton(card, "ACCEPT",  BTN_W, BTN_H, function(self)
        local o = self:GetParent(); if o._onAccept  then o._onAccept(o)  end end)
    card.btnAccept:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -8, 8)
    card.btnAccept:Hide()

    card.btnDecline = makeButton(card, "DECLINE", BTN_W, BTN_H, function(self)
        local o = self:GetParent(); if o._onDecline then o._onDecline(o) end end)
    card.btnDecline:SetPoint("RIGHT", card.btnAccept, "LEFT", -5, 0)
    card.btnDecline:Hide()

    card.btnReply = makeButton(card, "REPLY", 50, BTN_H, function(self)
        local o = self:GetParent(); if o._onReply   then o._onReply(o)   end end)
    card.btnReply:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -8, 8)
    card.btnReply:Hide()

    card:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            Notif:DismissCard(self)
        elseif button == "LeftButton" and self._onPrimary then
            self._onPrimary(self)
        end
    end)
    card:SetScript("OnEnter", function(self)
        self._hovered = true
        self._pausedRemaining = max(0.5, (self._expiresAt or GetTime()) - GetTime())
        self:SetAlpha(1)
        if self._tooltipTitle and self._tooltipTitle ~= "" then
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
            GameTooltip:SetText(self._tooltipTitle, 1, 1, 1, 1, true)
            if self._tooltipBody and self._tooltipBody ~= "" then
                GameTooltip:AddLine(self._tooltipBody, 0.72, 0.76, 0.82, true)
            end
            GameTooltip:Show()
        end
    end)
    card:SetScript("OnLeave", function(self)
        self._hovered   = false
        self._expiresAt = GetTime() + max(0.5, self._pausedRemaining or DUR_NORMAL)
        self._pausedRemaining = nil
        GameTooltip:Hide()
    end)

    return card
end

-- ----------------------------------------------------------------------------
-- Card pool state
-- ----------------------------------------------------------------------------

local cardPool           = {}
local activePassiveCards = {}   -- passive / standard lane (max MaxVisible)
local activeActionCards  = {}   -- actionable lane (no slot cap)
local cardQueue          = {}   -- pending passive events (FIFO)

Notif._cardPool           = cardPool
Notif._activePassiveCards = activePassiveCards
Notif._activeActionCards  = activeActionCards
Notif._cardQueue          = cardQueue

-- ----------------------------------------------------------------------------
-- AcquireCard -- distinguishes cold (buildCard() required) from warm (pool
-- hit) for profiling; also feeds task 7's prewarm below.
-- ----------------------------------------------------------------------------

local lastAcquireWasCold = false

function Notif:AcquireCard()
    local card = table.remove(cardPool)
    if card then
        lastAcquireWasCold = false
        return card
    end
    local startedAt = now()
    card = buildCard()
    finish("cold", "acquire_build", startedAt)
    lastAcquireWasCold = true
    return card
end

-- ----------------------------------------------------------------------------
-- RecycleCard  (immediate — called after exit animation completes)
-- ----------------------------------------------------------------------------

function Notif:RecycleCard(card)
    if not card then return end
    card:Hide()
    card:SetScript("OnUpdate", nil)

    for i = #activePassiveCards, 1, -1 do
        if activePassiveCards[i] == card then table.remove(activePassiveCards, i); break end
    end
    for i = #activeActionCards, 1, -1 do
        if activeActionCards[i] == card then table.remove(activeActionCards, i); break end
    end

    card._entering        = false
    card._exiting         = false
    card._enterElapsed    = nil
    card._exitElapsed     = nil
    card._currentX        = nil
    card._currentY        = nil
    card._targetX         = nil
    card._targetY         = nil
    card._entryDir        = nil
    card._cardScale       = nil
    card._lastPointX      = nil
    card._lastPointY      = nil
    card._lastScale       = nil
    card._lastAlpha       = nil
    card._hovered         = false
    card._expiresAt       = nil
    card._pausedRemaining = nil
    card._onAccept        = nil
    card._onDecline       = nil
    card._onReply         = nil
    card._onPrimary       = nil
    card._coalesceKey     = nil
    card._tooltipTitle    = nil
    card._tooltipBody     = nil
    card._sourceAddon     = nil
    card._category        = nil
    card._id              = nil
    card.title:SetText("")
    card.detail:SetText("")
    card.timeText:SetText("")
    card.iconInitial:SetText("")
    card.icon:SetTexture(nil)
    card.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    card.icon:SetDesaturated(false)
    card.icon:Hide()
    card.badge:SetTexture(nil)
    card.badge:Hide()
    card.accentBar:SetColorTexture(ACCENT_DEFAULT[1], ACCENT_DEFAULT[2], ACCENT_DEFAULT[3], 1)
    card.iconBg:SetColorTexture(0.12, 0.14, 0.18, 1)
    card.btnAccept:Hide()
    card.btnDecline:Hide()
    card.btnReply:Hide()
    if card.btnAccept.label  then card.btnAccept.label:SetText("ACCEPT")   end
    if card.btnDecline.label then card.btnDecline.label:SetText("DECLINE") end
    card:SetAlpha(1)
    card:SetScale(0.95)

    table.insert(cardPool, card)

    if #cardQueue > 0 and #activePassiveCards < getMaxVisible() then
        local nextEvent = table.remove(cardQueue, 1)
        self:ShowCard(nextEvent)
    else
        self:RepositionCards()
    end
end

-- ----------------------------------------------------------------------------
-- DismissCard  (starts exit animation; RecycleCard follows)
-- ----------------------------------------------------------------------------

function Notif:DismissCard(card)
    if not card or card._exiting then return end
    card._exiting     = true
    card._exitElapsed = 0
end

function Notif:Dismiss(id)
    if not id then return false end
    for _, c in ipairs(activePassiveCards) do
        if c._id == id then self:DismissCard(c); return true end
    end
    for _, c in ipairs(activeActionCards) do
        if c._id == id then self:DismissCard(c); return true end
    end
    return false
end

-- ----------------------------------------------------------------------------
-- Point/scale/alpha helpers that skip redundant calls (task 7) -- a card
-- whose target hasn't actually changed since last frame doesn't re-issue
-- SetPoint/SetScale/SetAlpha.
-- ----------------------------------------------------------------------------

local function setCardPoint(card, x, y)
    if card._lastPointX == x and card._lastPointY == y then return end
    card._lastPointX, card._lastPointY = x, y
    card:ClearAllPoints()
    card:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y)
end

local function setCardScale(card, scale)
    if card._lastScale == scale then return end
    card._lastScale = scale
    card:SetScale(scale)
end

local function setCardAlpha(card, alpha)
    if card._lastAlpha == alpha then return end
    card._lastAlpha = alpha
    card:SetAlpha(alpha)
end

-- ----------------------------------------------------------------------------
-- Per-card OnUpdate: entry → reflow → expiry → exit → recycle
-- Left as one OnUpdate per active card, per task 7: converting this to a
-- single shared ticker frame is a real optimization but is deferred until
-- the profiling instrumentation above shows it's actually a hotspot.
-- ----------------------------------------------------------------------------

local function startCardAnimation(card)
    local dir   = card._entryDir  or "UP"
    local scale = card._cardScale or 0.95

    card:SetScript("OnUpdate", function(self, dt)
        dt = min(dt or 0, 0.05)
        local nowT = GetTime and GetTime() or 0

        if self._exiting then
            self._exitElapsed = (self._exitElapsed or 0) + dt
            local t = min(1, self._exitElapsed / ANIM_DUR)
            setCardAlpha(self, 1 - t)
            setCardScale(self, scale * max(0.80, 1 - 0.20 * t))
            if t >= 1 then Notif:RecycleCard(self) end
            return
        end

        if self._entering then
            self._enterElapsed = (self._enterElapsed or 0) + dt
            local t      = min(1, self._enterElapsed / ANIM_DUR)
            local eased  = 1 - (1 - t) * (1 - t)
            local remain = 1 - eased
            local tx = self._targetX or 0
            local ty = self._targetY or 0
            local cx, cy = tx, ty
            if dir == "UP"    then cy = ty - ANIM_OFFSET * remain
            elseif dir == "DOWN"  then cy = ty + ANIM_OFFSET * remain
            elseif dir == "LEFT"  then cx = tx + ANIM_OFFSET * remain
            else                       cx = tx - ANIM_OFFSET * remain end
            self._currentX = cx
            self._currentY = cy
            setCardPoint(self, cx, cy)
            setCardAlpha(self, eased)
            setCardScale(self, scale * (0.88 + 0.12 * eased))
            if t >= 1 then
                self._entering = false
                self._currentX = tx
                self._currentY = ty
                setCardAlpha(self, 1)
                setCardScale(self, scale)
            end
            return
        end

        local tx = self._targetX or self._currentX or 0
        local ty = self._targetY or self._currentY or 0
        local cx = self._currentX or tx
        local cy = self._currentY or ty
        local dx, dy = tx - cx, ty - cy
        if dx * dx + dy * dy > 0.25 then
            local r = min(1, dt * 14)
            cx = cx + dx * r
            cy = cy + dy * r
            self._currentX = cx
            self._currentY = cy
            setCardPoint(self, cx, cy)
        end

        if not self._hovered then
            local remaining = (self._expiresAt or nowT) - nowT
            if remaining <= 0 then
                Notif:DismissCard(self)
            elseif remaining < 0.5 then
                setCardAlpha(self, max(0, remaining / 0.5))
            else
                setCardAlpha(self, 1)
            end
        end
    end)
end

-- ----------------------------------------------------------------------------
-- RepositionCards: compute _targetX/Y for all active cards
-- ----------------------------------------------------------------------------

function Notif:RepositionCards()
    local dir    = getDir()
    local scale  = getScale()
    local baseX, baseY = getBase()
    local w = CARD_W * scale
    local h = CARD_H * scale
    local gap = STACK_GAP

    for i, card in ipairs(activePassiveCards) do
        local tx, ty = baseX, baseY
        if     dir == "UP"   then ty = baseY + (i - 1) * (h + gap)
        elseif dir == "DOWN" then ty = baseY - (i - 1) * (h + gap)
        elseif dir == "LEFT" then tx = baseX - (i - 1) * (w + gap)
        else                      tx = baseX + (i - 1) * (w + gap) end
        card._targetX = tx
        card._targetY = ty
        if not card._currentX then card._currentX = tx; card._currentY = ty end
    end

    if #activeActionCards > 0 then
        local screenW = UIParent:GetWidth()  or 1920
        local screenH = UIParent:GetHeight() or 1080
        local laneX, laneY

        if dir == "UP" or dir == "DOWN" then
            local rightSpace = screenW - (baseX + w)
            laneX = (rightSpace >= baseX) and (baseX + w + gap) or (baseX - w - gap)
            laneY = baseY
            for i, card in ipairs(activeActionCards) do
                local ty = laneY
                if dir == "UP"   then ty = laneY + (i - 1) * (h + gap)
                else                  ty = laneY - (i - 1) * (h + gap) end
                card._targetX = laneX
                card._targetY = ty
                if not card._currentX then card._currentX = laneX; card._currentY = ty end
            end
        else
            local aboveSpace = screenH - (baseY + h)
            laneY = (aboveSpace >= baseY) and (baseY + h + gap) or (baseY - h - gap)
            laneX = baseX
            for i, card in ipairs(activeActionCards) do
                local tx = laneX
                if dir == "LEFT" then tx = laneX - (i - 1) * (w + gap)
                else                  tx = laneX + (i - 1) * (w + gap) end
                card._targetX = tx
                card._targetY = laneY
                if not card._currentX then card._currentX = tx; card._currentY = laneY end
            end
        end
    end

    local allCards = {}
    for _, c in ipairs(activePassiveCards) do allCards[#allCards + 1] = c end
    for _, c in ipairs(activeActionCards)  do allCards[#allCards + 1] = c end

    if #allCards > 0 then
        local screenW = UIParent:GetWidth()  or 1920
        local screenH = UIParent:GetHeight() or 1080
        local c0 = allCards[1]
        local minX, minY = c0._targetX, c0._targetY
        local maxX, maxY = minX + w, minY + h
        for i = 2, #allCards do
            local c = allCards[i]
            if c._targetX < minX then minX = c._targetX end
            if c._targetY < minY then minY = c._targetY end
            if c._targetX + w > maxX then maxX = c._targetX + w end
            if c._targetY + h > maxY then maxY = c._targetY + h end
        end
        local sx = 0
        local sy = 0
        if     minX < 4              then sx =  4 - minX
        elseif maxX > screenW - 4   then sx = (screenW - 4) - maxX end
        if     minY < 4              then sy =  4 - minY
        elseif maxY > screenH - 4   then sy = (screenH - 4) - maxY end
        if sx ~= 0 or sy ~= 0 then
            for _, c in ipairs(allCards) do
                c._targetX = c._targetX + sx
                c._targetY = c._targetY + sy
            end
        end
    end
end

-- ----------------------------------------------------------------------------
-- Populate a card's visual content from a normalized event
-- ----------------------------------------------------------------------------

local function populateCard(card, event, accent, scale)
    local status = upper(tostring(event.status or "INFO"))

    card.iconBg:SetColorTexture(accent[1] * 0.20, accent[2] * 0.20, accent[3] * 0.20, 1)

    local hasTexture = false
    if event.icon and event.icon ~= "" then
        card.icon:SetTexture(event.icon)
        card.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        card.icon:SetDesaturated(status == "OFFLINE")
        card.icon:Show()
        card.iconInitial:SetText("")
        hasTexture = true
    end
    if not hasTexture then
        card.icon:SetTexture(nil)
        card.icon:Hide()
        card.iconInitial:SetText(upper(string.sub(tostring(event.title or "?"), 1, 1)))
    end

    if event.badge and event.badge ~= "" then
        card.badge:SetTexture(event.badge)
        card.badge:Show()
    else
        card.badge:SetTexture(nil)
        card.badge:Hide()
    end

    card.title:SetText(tostring(event.title  or ""))
    card.detail:SetText(tostring(event.detail or ""))
    card.timeText:SetText(date("%H:%M", time()))
    card.accentBar:SetColorTexture(accent[1], accent[2], accent[3], 1)

    card._tooltipTitle = tostring(event.title  or "")
    card._tooltipBody  = tostring(event.detail or "")

    local actions = type(event.actions) == "table" and event.actions or {}
    card._onAccept  = actions.accept
    card._onDecline = actions.decline
    card._onReply   = actions.reply
    card._onPrimary = actions.primary

    if actions.accept then
        if card.btnAccept.label then card.btnAccept.label:SetText(actions.acceptLabel  or "ACCEPT")  end
        card.btnAccept:Show()
    else
        card.btnAccept:Hide()
    end
    if actions.decline and actions.accept then
        if card.btnDecline.label then card.btnDecline.label:SetText(actions.declineLabel or "DECLINE") end
        card.btnDecline:Show()
    else
        card.btnDecline:Hide()
    end
    if actions.reply and not actions.accept then
        card.btnReply:Show()
    else
        card.btnReply:Hide()
    end

    card:SetScale(scale)
    card._lastScale = scale
    card._cardScale = scale
end

-- ----------------------------------------------------------------------------
-- ShowCard: show a card from a normalized event
-- force = true  bypasses IsCategoryEnabled (preview / test only)
-- ----------------------------------------------------------------------------

function Notif:ShowCard(event, force)
    if type(event) ~= "table" then return nil end

    local src = upper(tostring(event.sourceAddon or "CRESHCHAT"))
    local cat = upper(tostring(event.category    or "SYSTEM"))
    if not force and not self:IsCategoryEnabled(src, cat) then return nil end

    local isActionable = event.destination == "ACTIONABLE"
        or (event.destination == nil and (cat == "PARTY_INVITE" or cat == "GAME_INVITE"))

    if not isActionable then
        local maxV = getMaxVisible()
        local hasCoalesce = false
        if event.coalesceKey then
            for _, c in ipairs(activePassiveCards) do
                if c._coalesceKey == event.coalesceKey and c:IsShown() then
                    hasCoalesce = true
                    break
                end
            end
        end
        if not hasCoalesce and #activePassiveCards >= maxV then
            table.insert(cardQueue, event)
            return nil
        end
    end

    local accent   = (type(event.accent) == "table" and #event.accent >= 3)
                     and event.accent or resolveAccent(event.status, cat)
    local priority = upper(tostring(event.priority or "NORMAL"))
    local duration = tonumber(event.duration)
                     or ((priority == "CRITICAL" or priority == "HIGH") and DUR_HIGH or DUR_NORMAL)
    local scale     = getScale()
    local dir       = getDir()

    local card
    local activeList = isActionable and activeActionCards or activePassiveCards
    if event.coalesceKey then
        for _, c in ipairs(activeList) do
            if c._coalesceKey == event.coalesceKey and c:IsShown() then
                card = c
                break
            end
        end
    end
    local isNew = (card == nil)
    local bucket = "warm"
    if isNew then
        card = self:AcquireCard()
        bucket = lastAcquireWasCold and "cold" or "warm"
    end

    card._id          = event.id or (cat .. ":" .. tostring(GetTime and GetTime() or 0))
    card._sourceAddon = src
    card._category    = cat
    card._coalesceKey = event.coalesceKey

    local t0 = now()
    populateCard(card, event, accent, scale)
    finish(bucket, "populate", t0)

    card._expiresAt = (GetTime and GetTime() or 0) + duration

    if isNew then
        table.insert(activeList, card)
        card._entryDir = dir
        card._entering = true
        card._enterElapsed = 0
        card._exiting  = false
    end

    local t1 = now()
    self:RepositionCards()
    finish(bucket, "layout", t1)

    setCardAlpha(card, isNew and 0 or 1)
    card:Show()
    if isNew then startCardAnimation(card) end
    return card
end

-- ----------------------------------------------------------------------------
-- Push  -- the real, non-stub implementation. Sound is attempted
-- unconditionally (its own gating is independent of card enablement, see
-- PlayNotificationSound); the card is gated by the full IsCategoryEnabled
-- chain.
-- ----------------------------------------------------------------------------

function Notif:Push(event)
    if type(event) ~= "table" then return false end
    local src = upper(tostring(event.sourceAddon or "CRESHCHAT"))
    local cat = upper(tostring(event.category    or "SYSTEM"))

    local tSound = now()
    pcall(self.PlayNotificationSound, self, src, event)
    finish(lastAcquireWasCold and "cold" or "warm", "sound", tSound)

    if not self:IsCategoryEnabled(src, cat) then return false end

    -- Card rendering is never allowed to propagate an error back to the
    -- producer that called Push -- an actionable invitation (or any other
    -- notification) must fall back safely (the producer's own existing
    -- fallback, e.g. Games:ShowChallengePopup's own popup frame) rather than
    -- break whatever gameplay code triggered it.
    local tPush = now()
    local ok, card = pcall(self.ShowCard, self, event)
    finish(lastAcquireWasCold and "cold" or "warm", "push_total", tPush)
    if not ok then return false end
    return card ~= nil
end

-- ----------------------------------------------------------------------------
-- Preview  (manual testing hook -- callable from any addon's own slash
-- command). force=true so all three sources show even when only one addon
-- is actually loaded/registered.
-- ----------------------------------------------------------------------------

local PREVIEW_EVENTS = {
    { title="Alyndra",       detail="hey, are you on?",            status="WHISPER",     category="WHISPER",       sourceAddon="CRESHCHAT" },
    { title="Korreth",       detail="has come online.",             status="ONLINE",      category="FRIEND",        sourceAddon="CRESHCHAT" },
    { title="Guild",         detail="Durnan: portal is up!",       status="GUILD",       category="GUILD",         sourceAddon="CRESHCHAT" },
    { title="Party invite",  detail="Solenne invited you to join.", status="PARTY",       category="PARTY_INVITE",  sourceAddon="CRESHCHAT", destination="ACTIONABLE" },
    { title="Battle Pass",   detail="Level 12 · +50 Cresh Coins",  status="BATTLEPASS",  category="GAME",          sourceAddon="CRESHCHAT" },
    { title="System",        detail="You joined Solenne's party.",  status="SUCCESS",     category="SYSTEM",        sourceAddon="CRESHCHAT" },
    { title="Game invite",   detail="Durnan challenged you.",       status="GAME",        category="GAME_INVITE",   sourceAddon="CRESHGAMES", destination="ACTIONABLE" },
    { title="Achievement",   detail="Explorer: visit 50 zones.",   status="ACHIEVEMENT", category="ACHIEVEMENT",   sourceAddon="CRESHCOLLECT" },
}

function Notif:Preview()
    for _, evt in ipairs(PREVIEW_EVENTS) do
        self:ShowCard(evt, true)
    end
end

-- ----------------------------------------------------------------------------
-- Cold-start reduction (task 7): stagger 2 pool-priming acquisitions shortly
-- after PLAYER_LOGIN so a buildCard() has already happened well before any
-- real event arrives, instead of paying that cost on the first live push.
-- One frame total across all three addons (idempotent build above).
-- ----------------------------------------------------------------------------

local function prewarmOnce()
    local card = Notif:AcquireCard()
    table.insert(cardPool, card)
end

local prewarmFrame = CreateFrame("Frame")
prewarmFrame:RegisterEvent("PLAYER_LOGIN")
prewarmFrame:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    if _G.C_Timer and _G.C_Timer.After then
        _G.C_Timer.After(0.5, prewarmOnce)
        _G.C_Timer.After(1.2, prewarmOnce)
    else
        prewarmOnce()
    end
end)
