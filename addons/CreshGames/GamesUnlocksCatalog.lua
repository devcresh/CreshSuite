-- CreshGames/GamesUnlocksCatalog.lua
-- Phase 5: normalized, read-only catalogue of every obtainable CreshGames
-- item -- card decks, Tetris themes/backgrounds, dungeon armour sets,
-- dungeon minion skins and dungeon milestone chests -- plus, optionally,
-- CreshCollect's unlocked CreshChat theme entitlements when that addon is
-- loaded. Renders into SoloGames.lua's existing frame.unlocksPanel, the
-- same "host builds the panel frame, a sibling module owns its content"
-- pattern already used for Games:BuildHub(frame.multiPanel).
--
-- Every entry is read from a catalog/module CreshGames already owns
-- (CG.RewardRegistry, CG.CardDecks, CG.Tetris, CG.DungeonCrawlerContent,
-- CG.SoloGames, CG.BattlePass) or, for the one cross-addon category,
-- through CreshCollectAPI's existing public getter -- never another
-- addon's private tables or SavedVariables. Must load after
-- GamesRewardRegistry.lua and SoloGames.lua (see CreshGames.toc).
local _, CG = ...
if not CG then return end

local UI = _G.CreshSuiteUI

local Catalog = { version = CG.version }
CG.UnlocksCatalog = Catalog
if CG.RegisterModule then CG:RegisterModule("UnlocksCatalog", Catalog) end

local floor, max, min = math.floor, math.max, math.min
local upper, lower = string.upper, string.lower
local format = string.format

local function palette() return (UI and UI:GetPalette()) or {} end
local function templateName() return UI and UI:TemplateName() or nil end
local function applyBackdrop(frame, bg, border) if UI then UI:ApplyBackdrop(frame, bg, border) end end
local function createText(parent, size, color, justify)
    if UI then return UI:CreateText(parent, size, color, justify) end
    return parent:CreateFontString(nil, "OVERLAY")
end
local function createButton(parent, label, w, h, cb)
    if UI then return UI:CreateButton(parent, label, w, h, cb) end
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(w or 80, h or 24)
    b:SetScript("OnClick", cb)
    return b
end

local function openArcadePass()
    local api = _G.CreshGamesAPI
    if api and api.OpenArcadePass then api.OpenArcadePass() end
end

local function openMastery(game)
    local api = _G.CreshGamesAPI
    if api and api.OpenGameMastery then api.OpenGameMastery(game) end
end

-- ============================================================================
-- Categories / status / filter state
-- ============================================================================

local CATEGORY_ORDER = {
    "ALL", "CARD_DECK", "TETRIS_THEME", "TETRIS_BACKGROUND",
    "DUNGEON_ARMOUR", "DUNGEON_MINION", "DUNGEON_MILESTONE",
}
local CATEGORY_NAMES = {
    ALL = "ALL", CARD_DECK = "CARD DECKS", TETRIS_THEME = "TETRIS THEMES",
    TETRIS_BACKGROUND = "TETRIS BACKGROUNDS", DUNGEON_ARMOUR = "DUNGEON ARMOUR",
    DUNGEON_MINION = "MINION SKINS", DUNGEON_MILESTONE = "MILESTONE CHESTS",
    CHAT_THEME = "CHAT THEMES",
}
local STATUS_ORDER = { "ALL", "UNLOCKED", "LOCKED", "READY" }

local function chatThemesAvailable()
    local suite = _G.CreshSuite
    return suite ~= nil and type(suite.IsProductLoaded) == "function" and suite:IsProductLoaded("CreshCollect") == true
end

-- Category cycle list, including CHAT_THEME only when CreshCollect is
-- actually loaded (task 8: nothing to show, so nothing offered -- no
-- placeholder row needed for a category that simply doesn't apply).
function Catalog:GetCategoryOrder()
    if not chatThemesAvailable() then return CATEGORY_ORDER end
    local list = {}
    for _, key in ipairs(CATEGORY_ORDER) do list[#list + 1] = key end
    list[#list + 1] = "CHAT_THEME"
    return list
end

local function cycleValue(list, current, direction)
    if #list == 0 then return current end
    local index = 1
    for i, value in ipairs(list) do
        if value == current then index = i break end
    end
    index = index + (direction or 1)
    if index > #list then index = 1 end
    if index < 1 then index = #list end
    return list[index]
end

-- ============================================================================
-- Catalogue assembly -- one function per category, each reading only from
-- an existing catalog/module this addon already owns.
-- ============================================================================

-- True when a pass-driven `requiredLevel` has been reached but its reward
-- not yet claimed -- the moment of claiming is also the moment the item
-- itself is granted (GamesBattlePass.lua:ClaimReward / TetrisThemes.lua:
-- ClaimPassReward both grant-then-mark-claimed together), so this is the
-- only "claimable but not yet owned" signal the catalogue needs.
local function isPassReady(sourceSystem, requiredLevel)
    if not requiredLevel then return false end
    if sourceSystem == "ARCADE_PASS" then
        local Pass = CG.BattlePass
        return Pass ~= nil and Pass:IsLevelReached(requiredLevel) and not Pass:IsRewardClaimed(requiredLevel)
    elseif sourceSystem == "TETRIS_MASTERY_PASS" then
        local Tetris = CG.Tetris
        return Tetris ~= nil and Tetris:IsPassLevelReached(requiredLevel) and not Tetris:IsPassRewardClaimed(requiredLevel)
    end
    return false
end

local function addCardDeckEntries(list)
    local Decks, Registry = CG.CardDecks, CG.RewardRegistry
    if not Decks or not Registry then return end
    local levelByKey = {}
    for _, reward in ipairs(Registry.arcadeRewards or {}) do
        if reward.type == "CARD_DECK" then levelByKey[reward.unlockKey] = reward.requiredLevel end
    end
    for _, reg in ipairs(Registry.cardDeckCatalog or {}) do
        local key = reg.unlockKey
        local unlocked = Decks:IsUnlocked(key)
        local equipped = false
        if unlocked then
            for _, gameKey in ipairs(Decks.gameKeys or {}) do
                if Decks:GetSelected(gameKey) == key then equipped = true break end
            end
        end
        local requiredLevel = levelByKey[key]
        local state
        if unlocked then state = equipped and "EQUIPPED" or "UNLOCKED"
        elseif isPassReady("ARCADE_PASS", requiredLevel) then state = "READY"
        else state = "LOCKED" end
        local requirementText
        if reg.sourceSystem == "DEFAULT" then requirementText = "Included with every account"
        elseif requiredLevel then requirementText = "Arcade Pass level " .. tostring(requiredLevel)
        else requirementText = "Random starter deck, or an Arcade Pass reward" end
        list[#list + 1] = {
            key = "CARD_DECK:" .. key, name = reg.displayName or key, category = "CARD_DECK",
            ownerAddon = "CRESHGAMES", icon = reg.assetPath, state = state,
            source = requiredLevel and "Arcade Pass" or (reg.sourceSystem == "DEFAULT" and "Included" or "Starter Deck"),
            requirementText = requirementText, progress = nil,
            action = (state == "LOCKED" or state == "READY") and openArcadePass or nil,
        }
    end
end

local function addTetrisEntries(list)
    local Tetris, Registry = CG.Tetris, CG.RewardRegistry
    if not Tetris or not Registry then return end
    local selectedTheme = Tetris:GetSelectedTheme()
    local selectedBackground = Tetris:GetSelectedBackground()
    for _, reg in ipairs(Registry.tetrisMasteryRewards or {}) do
        local key = reg.unlockKey
        local isTheme = reg.type == "TETRIS_THEME"
        local unlocked = isTheme and Tetris:IsThemeUnlocked(key) or Tetris:IsBackgroundUnlocked(key)
        local equipped = unlocked and ((isTheme and selectedTheme and selectedTheme.key == key)
            or (not isTheme and selectedBackground and selectedBackground.key == key))
        local state
        if unlocked then state = equipped and "EQUIPPED" or "UNLOCKED"
        elseif isPassReady(reg.sourceSystem, reg.requiredLevel) then state = "READY"
        else state = "LOCKED" end
        local requirementText = isTheme and Tetris:GetThemeRequirementText(key) or Tetris:GetBackgroundRequirementText(key)
        local icon, swatch
        if reg.assetPath then icon = reg.assetPath
        elseif isTheme then
            local theme = Tetris:GetTheme(key)
            swatch = theme and theme.colors and (theme.colors.T or theme.colors.I)
        end
        list[#list + 1] = {
            key = reg.type .. ":" .. key, name = reg.displayName or key,
            category = reg.type, ownerAddon = "CRESHGAMES", icon = icon, swatch = swatch,
            state = state, source = reg.sourceSystem, requirementText = requirementText, progress = nil,
            action = (state == "LOCKED" or state == "READY") and function() openMastery("TETRIS") end or nil,
        }
    end
end

local function addDungeonArmourEntries(list)
    local Content = CG.DungeonCrawlerContent
    if not Content then return end
    local db = _G.CreshGamesDB
    local equippedByClass = db and db.soloGames and db.soloGames.dungeon and db.soloGames.dungeon.equippedArmour or {}
    for _, classKey in ipairs(Content.classOrder or {}) do
        for _, set in ipairs(Content:GetArmourSets(classKey)) do
            local unlocked = Content:IsArmourUnlocked(classKey, set.key)
            local equipped = unlocked and equippedByClass[classKey] == set.key
            local state = unlocked and (equipped and "EQUIPPED" or "UNLOCKED") or "LOCKED"
            list[#list + 1] = {
                key = "DUNGEON_ARMOUR:" .. set.key, name = set.name or set.key, category = "DUNGEON_ARMOUR",
                ownerAddon = "CRESHGAMES", icon = set.icon, state = state,
                source = set.className and (set.className .. " armour") or "Dungeon Dweller armour",
                requirementText = "Dungeon Dweller level " .. tostring(set.unlockLevel or 0)
                    .. (set.className and (" (" .. set.className .. ")") or ""),
                progress = nil,
                action = (state == "LOCKED") and function() openMastery("DUNGEON") end or nil,
            }
        end
    end
end

local function addDungeonMinionEntries(list)
    local Solo = CG.SoloGames
    if not Solo or not Solo.GetMinionSkinCatalog then return end
    for _, skin in ipairs(Solo:GetMinionSkinCatalog()) do
        local unlocked = Solo:IsMinionSkinUnlocked(skin.key)
        list[#list + 1] = {
            key = "DUNGEON_MINION:" .. skin.key, name = skin.key:gsub("_", " "), category = "DUNGEON_MINION",
            ownerAddon = "CRESHGAMES", icon = skin.texture, state = unlocked and "UNLOCKED" or "LOCKED",
            source = skin.kind .. " minion", requirementText = "Random reward from recruiting minions in Dungeon Dweller runs",
            progress = nil, action = nil,
        }
    end
end

local function addDungeonMilestoneEntries(list)
    local Content = CG.DungeonCrawlerContent
    if not Content then return end
    local db = _G.CreshGamesDB
    local dungeon = db and db.soloGames and db.soloGames.dungeon
    local best = max(tonumber(dungeon and dungeon.bestRoom) or 0, tonumber(dungeon and dungeon.bestLevel) or 0)
    for _, level in ipairs(Content.milestoneChestOrder or {}) do
        local chest = Content:GetMilestoneChest(level)
        if chest then
            local reached = best >= level
            list[#list + 1] = {
                key = "DUNGEON_MILESTONE:" .. level, name = chest.name or ("Level " .. level .. " Milestone Chest"),
                category = "DUNGEON_MILESTONE", ownerAddon = "CRESHGAMES", icon = chest.icon,
                state = reached and "UNLOCKED" or "LOCKED", source = "Dungeon Dweller milestone",
                requirementText = "Reach dungeon level " .. tostring(level), progress = nil,
                action = (not reached) and function() openMastery("DUNGEON") end or nil,
            }
        end
    end
end

local function addChatThemeEntries(list)
    if not chatThemesAvailable() then return end
    local api = _G.CreshCollectAPI
    if not api or not api.GetChatThemeEntitlements then return end
    for _, entitlement in ipairs(api.GetChatThemeEntitlements() or {}) do
        list[#list + 1] = {
            key = "CHAT_THEME:" .. tostring(entitlement.key), name = tostring(entitlement.key):gsub("_", " "),
            category = "CHAT_THEME", ownerAddon = "CRESHCOLLECT", icon = nil, state = "UNLOCKED",
            source = tostring(entitlement.source or "CreshCollect"), requirementText = "Unlocked via CreshCollect",
            progress = nil, action = nil,
        }
    end
end

-- Rebuilds self.entries from scratch. Cheap: a few hundred table
-- constructions and existing-getter calls, no frames created here.
function Catalog:BuildCatalog()
    local list = {}
    addCardDeckEntries(list)
    addTetrisEntries(list)
    addDungeonArmourEntries(list)
    addDungeonMinionEntries(list)
    addDungeonMilestoneEntries(list)
    addChatThemeEntries(list)
    self.entries = list
    return list
end

-- ============================================================================
-- Filtering (mirrors CreshCollect/Achievements.lua's MatchesFilter: AND-
-- combine category, status and a case-insensitive search substring)
-- ============================================================================

function Catalog:MatchesFilter(entry)
    local category = self.filterCategory or "ALL"
    if category ~= "ALL" and entry.category ~= category then return false end

    local status = self.filterStatus or "ALL"
    if status == "UNLOCKED" and not (entry.state == "UNLOCKED" or entry.state == "EQUIPPED") then return false end
    if status == "LOCKED" and entry.state ~= "LOCKED" then return false end
    if status == "READY" and entry.state ~= "READY" then return false end

    local search = lower(tostring(self.filterSearch or ""))
    if search ~= "" then
        local haystack = lower((entry.name or "") .. " " .. (entry.source or "") .. " " .. (CATEGORY_NAMES[entry.category] or ""))
        if not string.find(haystack, search, 1, true) then return false end
    end
    return true
end

function Catalog:BuildFilteredList()
    local list = {}
    for _, entry in ipairs(self.entries or {}) do
        if self:MatchesFilter(entry) then list[#list + 1] = entry end
    end
    self.filteredList = list
    return list
end

-- ============================================================================
-- UI: compact progress hero + search/filter row + a paginated card GRID
-- (fills the available width, wraps downward row by row, Prev/Next pages --
-- matches the existing dropdown-menu convention in CreshChat/Settings.lua
-- rather than a scrollbar).
-- ============================================================================

local CARD_WIDTH  = 176
local CARD_HEIGHT = 96
local CARD_GAP    = 8
local GRID_ROWS    = 4

local function heroTile(parent, label)
    local colors = palette()
    local box = CreateFrame("Frame", nil, parent, templateName())
    applyBackdrop(box, colors.panelSoft, colors.border)
    box.value = createText(box, 13, colors.text, "CENTER")
    box.value:SetPoint("TOPLEFT", box, "TOPLEFT", 4, -6)
    box.value:SetPoint("TOPRIGHT", box, "TOPRIGHT", -4, -6)
    box.label = createText(box, 8, colors.muted, "CENTER")
    box.label:SetPoint("TOPLEFT", box.value, "BOTTOMLEFT", 0, -2)
    box.label:SetPoint("TOPRIGHT", box.value, "BOTTOMRIGHT", 0, -2)
    box.label:SetText(label)
    return box
end

function Catalog:BuildPanel(parent)
    if self.panel then return self.panel end
    local colors = palette()
    self.panel = parent
    self.filterCategory = "ALL"
    self.filterStatus = "ALL"
    self.filterSearch = ""

    -- Compact progress hero: Arcade Pass / Tetris Mastery / Delver Mastery.
    local hero = CreateFrame("Frame", nil, parent, templateName())
    hero:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, -8)
    hero:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -8, -8)
    hero:SetHeight(50)
    self.heroTiles = {}
    local tileDefs = { { key = "ARCADE", label = "ARCADE PASS" }, { key = "TETRIS", label = "TETRIS MASTERY" }, { key = "DUNGEON", label = "DELVER MASTERY" } }
    local prevTile
    for _, def in ipairs(tileDefs) do
        local tile = heroTile(hero, def.label)
        tile:SetPoint("TOP", hero, "TOP", 0, 0)
        tile:SetPoint("BOTTOM", hero, "BOTTOM", 0, 0)
        if prevTile then
            tile:SetPoint("LEFT", prevTile, "RIGHT", 6, 0)
        else
            tile:SetPoint("LEFT", hero, "LEFT", 0, 0)
        end
        self.heroTiles[def.key] = tile
        prevTile = tile
    end
    -- Even 3-way split: anchor the last tile's right edge to hero's right.
    prevTile:SetPoint("RIGHT", hero, "RIGHT", 0, 0)

    -- Search box.
    local searchFrame = CreateFrame("Frame", nil, parent, templateName())
    searchFrame:SetPoint("TOPLEFT", hero, "BOTTOMLEFT", 0, -6)
    searchFrame:SetPoint("TOPRIGHT", hero, "BOTTOMRIGHT", 0, -6)
    searchFrame:SetHeight(24)
    applyBackdrop(searchFrame, colors.panelRaised, colors.border)
    local search = CreateFrame("EditBox", nil, searchFrame, templateName())
    search:SetPoint("TOPLEFT", searchFrame, "TOPLEFT", 6, -3)
    search:SetPoint("BOTTOMRIGHT", searchFrame, "BOTTOMRIGHT", -6, 3)
    search:SetAutoFocus(false)
    search:SetFontObject(_G.GameFontHighlightSmall or _G.GameFontNormalSmall)
    search:SetTextInsets(2, 2, 0, 0)
    search:SetMaxLetters(40)
    search:SetScript("OnEscapePressed", function(box) box:ClearFocus() end)
    search:SetScript("OnEnterPressed", function(box) box:ClearFocus() end)
    search:SetScript("OnTextChanged", function(box)
        Catalog.filterSearch = tostring(box:GetText() or "")
        Catalog:Refresh(true)
    end)
    self.searchHint = createText(searchFrame, 8, colors.muted, "LEFT")
    self.searchHint:SetPoint("LEFT", searchFrame, "LEFT", 8, 0)
    self.searchHint:SetText("Search unlocks...")
    search:SetScript("OnEditFocusGained", function() self.searchHint:Hide() end)
    search:SetScript("OnEditFocusLost", function(box) self.searchHint:SetShown((box:GetText() or "") == "") end)
    self.searchBox = search

    -- Category / status cycle buttons (Phase 2 precedent: cycle controls,
    -- not a button wall).
    local filterRow = CreateFrame("Frame", nil, parent, templateName())
    filterRow:SetPoint("TOPLEFT", searchFrame, "BOTTOMLEFT", 0, -6)
    filterRow:SetPoint("TOPRIGHT", searchFrame, "BOTTOMRIGHT", 0, -6)
    filterRow:SetHeight(24)

    self.categoryButton = createButton(filterRow, CATEGORY_NAMES.ALL, 300, 24, function(_, mouseButton)
        local order = self:GetCategoryOrder()
        self.filterCategory = cycleValue(order, self.filterCategory, mouseButton == "RightButton" and -1 or 1)
        self.categoryButton.label:SetText(CATEGORY_NAMES[self.filterCategory] or self.filterCategory)
        self:Refresh(true)
    end)
    self.categoryButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    self.categoryButton:SetPoint("TOPLEFT", filterRow, "TOPLEFT", 0, 0)
    self.categoryButton:SetPoint("BOTTOMLEFT", filterRow, "BOTTOMLEFT", 0, 0)

    self.statusButton = createButton(filterRow, STATUS_ORDER[1], 160, 24, function(_, mouseButton)
        self.filterStatus = cycleValue(STATUS_ORDER, self.filterStatus, mouseButton == "RightButton" and -1 or 1)
        self.statusButton.label:SetText(self.filterStatus)
        self:Refresh(true)
    end)
    self.statusButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    self.statusButton:SetPoint("LEFT", self.categoryButton, "RIGHT", 6, 0)
    self.statusButton:SetPoint("TOP", filterRow, "TOP", 0, 0)
    self.statusButton:SetPoint("BOTTOM", filterRow, "BOTTOM", 0, 0)

    self.countText = createText(filterRow, 9, colors.muted, "RIGHT")
    self.countText:SetPoint("RIGHT", filterRow, "RIGHT", 0, 0)
    self.countText:SetPoint("TOP", filterRow, "TOP", 0, 0)
    self.countText:SetPoint("BOTTOM", filterRow, "BOTTOM", 0, 0)

    -- Page navigation -- Prev/Next + "Page X / Y", the same convention
    -- CreshChat/Settings.lua's dropdown menus already use instead of a
    -- scrollbar.
    local pageBar = CreateFrame("Frame", nil, parent, templateName())
    pageBar:SetPoint("TOPLEFT", filterRow, "BOTTOMLEFT", 0, -6)
    pageBar:SetPoint("TOPRIGHT", filterRow, "BOTTOMRIGHT", 0, -6)
    pageBar:SetHeight(22)
    self.previousPageButton = createButton(pageBar, "<", 40, 22, function() self:GoToPage((self.currentPage or 1) - 1) end)
    self.previousPageButton:SetPoint("LEFT", pageBar, "LEFT", 0, 0)
    self.nextPageButton = createButton(pageBar, ">", 40, 22, function() self:GoToPage((self.currentPage or 1) + 1) end)
    self.nextPageButton:SetPoint("RIGHT", pageBar, "RIGHT", 0, 0)
    self.pageText = createText(pageBar, 9, colors.muted, "CENTER")
    self.pageText:SetPoint("LEFT", self.previousPageButton, "RIGHT", 4, 0)
    self.pageText:SetPoint("RIGHT", self.nextPageButton, "LEFT", -4, 0)
    self.pageText:SetPoint("TOP", pageBar, "TOP", 0, 0)
    self.pageText:SetPoint("BOTTOM", pageBar, "BOTTOM", 0, 0)

    -- Card grid: fills the available width, wraps downward row by row.
    -- Column count is derived from the panel's actual width so the grid
    -- always fills it rather than leaving a narrow single column.
    local availableWidth = max(CARD_WIDTH, (parent:GetWidth() or 746) - 16)
    self.gridColumns = max(1, floor((availableWidth + CARD_GAP) / (CARD_WIDTH + CARD_GAP)))
    self.pageSize = self.gridColumns * GRID_ROWS
    self.currentPage = 1

    local grid = CreateFrame("Frame", nil, parent)
    grid:SetPoint("TOPLEFT", pageBar, "BOTTOMLEFT", 0, -6)
    grid:SetPoint("TOPRIGHT", pageBar, "BOTTOMRIGHT", 0, -6)
    grid:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    self.grid = grid

    self.cardPool = {}
    for i = 1, self.pageSize do
        local card = CreateFrame("Button", nil, grid, templateName())
        card:SetSize(CARD_WIDTH, CARD_HEIGHT)
        applyBackdrop(card, colors.panel, colors.border)
        card.icon = card:CreateTexture(nil, "ARTWORK")
        card.icon:SetPoint("TOPLEFT", card, "TOPLEFT", 6, -6)
        card.icon:SetSize(28, 28)
        card.statePill = CreateFrame("Frame", nil, card, templateName())
        card.statePill:SetSize(70, 16)
        card.statePill:SetPoint("TOPRIGHT", card, "TOPRIGHT", -6, -6)
        card.stateText = createText(card.statePill, 8, colors.text, "CENTER")
        card.stateText:SetAllPoints()
        card.name = createText(card, 10, colors.text, "LEFT")
        card.name:SetPoint("TOPLEFT", card.icon, "TOPRIGHT", 6, 0)
        card.name:SetPoint("RIGHT", card.statePill, "LEFT", -4, 0)
        card.detail = createText(card, 8, colors.muted, "LEFT")
        card.detail:SetPoint("TOPLEFT", card, "TOPLEFT", 6, -40)
        card.detail:SetPoint("RIGHT", card, "RIGHT", -6, 0)
        card.detail:SetHeight(28)
        card.detail:SetWordWrap(true)
        card.actionButton = createButton(card, "VIEW", 70, 20, function() if card.assignedEntry then Catalog:ShowPreview(card.assignedEntry) end end)
        card.actionButton:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -6, 6)
        card:Hide()
        self.cardPool[i] = card
    end

    self:BuildPreviewPopup(parent, colors)

    return self.panel
end

-- Preview popup: shows one entry in place (icon/swatch, name, category,
-- state, requirement/source text) without leaving the Unlocks tab. VIEW
-- used to jump straight into entry.action() (e.g. opening the whole Tetris
-- game just to look at a locked background) -- now it always shows this
-- popup first, and the popup itself offers entry.action() as a separate,
-- clearly-labelled secondary step for entries that actually have a
-- Pass/Mastery destination to navigate to.
function Catalog:BuildPreviewPopup(parent, colors)
    if self.previewBlocker then return end
    local blocker = CreateFrame("Frame", nil, parent, templateName())
    blocker:SetAllPoints()
    blocker:SetFrameLevel((parent:GetFrameLevel() or 1) + 50)
    blocker:EnableMouse(true)
    applyBackdrop(blocker, { 0.004, 0.006, 0.010, 0.82 }, { 0, 0, 0, 0 })
    blocker:Hide()
    blocker:SetScript("OnMouseDown", function() Catalog:HidePreview() end)
    self.previewBlocker = blocker

    local popup = CreateFrame("Frame", nil, blocker, templateName())
    popup:SetSize(300, 232)
    popup:SetPoint("CENTER", blocker, "CENTER", 0, 0)
    popup:SetFrameLevel((blocker:GetFrameLevel() or 1) + 1)
    popup:EnableMouse(true)
    applyBackdrop(popup, colors.panel, colors.accent or colors.border)
    self.previewPopup = popup

    popup.icon = popup:CreateTexture(nil, "ARTWORK")
    popup.icon:SetSize(96, 96)
    popup.icon:SetPoint("TOP", popup, "TOP", 0, -16)

    popup.statePill = CreateFrame("Frame", nil, popup, templateName())
    popup.statePill:SetSize(80, 18)
    popup.statePill:SetPoint("TOP", popup.icon, "BOTTOM", 0, -8)
    popup.stateText = createText(popup.statePill, 9, colors.text, "CENTER")
    popup.stateText:SetAllPoints()

    popup.name = createText(popup, 13, colors.text, "CENTER")
    popup.name:SetPoint("TOP", popup.statePill, "BOTTOM", 0, -8)
    popup.name:SetPoint("LEFT", popup, "LEFT", 12, 0)
    popup.name:SetPoint("RIGHT", popup, "RIGHT", -12, 0)

    popup.category = createText(popup, 9, colors.muted, "CENTER")
    popup.category:SetPoint("TOP", popup.name, "BOTTOM", 0, -4)
    popup.category:SetPoint("LEFT", popup, "LEFT", 12, 0)
    popup.category:SetPoint("RIGHT", popup, "RIGHT", -12, 0)

    popup.detail = createText(popup, 9, colors.muted, "CENTER")
    popup.detail:SetPoint("TOP", popup.category, "BOTTOM", 0, -8)
    popup.detail:SetPoint("LEFT", popup, "LEFT", 14, 0)
    popup.detail:SetPoint("RIGHT", popup, "RIGHT", -14, 0)
    popup.detail:SetHeight(48)
    popup.detail:SetWordWrap(true)
    popup.detail:SetJustifyV("TOP")

    popup.actionButton = createButton(popup, "", 210, 26, function()
        local entry = popup.assignedEntry
        Catalog:HidePreview()
        if entry and entry.action then entry.action() end
    end)
    popup.actionButton:SetPoint("BOTTOM", popup, "BOTTOM", 0, 14)

    popup.close = createButton(popup, "X", 22, 22, function() Catalog:HidePreview() end)
    popup.close:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -4, -4)
end

function Catalog:ShowPreview(entry)
    if not entry or not self.previewPopup then return end
    local colors = palette()
    local popup = self.previewPopup
    popup.assignedEntry = entry
    if entry.icon then
        popup.icon:SetTexture(entry.icon)
        popup.icon:SetTexCoord(0, 1, 0, 1)
        popup.icon:Show()
    elseif entry.swatch then
        popup.icon:SetColorTexture(entry.swatch[1], entry.swatch[2], entry.swatch[3], entry.swatch[4] or 1)
        popup.icon:Show()
    else
        popup.icon:Hide()
    end
    local stateColors = UI and UI:GetStateColor(entry.state, colors) or { bg = colors.panelRaised, border = colors.border, text = colors.text }
    applyBackdrop(popup.statePill, stateColors.bg, stateColors.border)
    popup.stateText:SetText(entry.state)
    popup.stateText:SetTextColor(stateColors.text[1], stateColors.text[2], stateColors.text[3], 1)
    popup.name:SetText(entry.name)
    popup.category:SetText(CATEGORY_NAMES[entry.category] or entry.category or "")
    popup.detail:SetText(entry.requirementText or entry.source or "")
    if entry.action then
        popup.actionButton:Show()
        popup.actionButton.label:SetText(entry.state == "READY" and "CLAIM" or "TRACK PROGRESS")
    else
        popup.actionButton:Hide()
    end
    self.previewBlocker:Show()
    popup:Show()
end

function Catalog:HidePreview()
    if self.previewBlocker then self.previewBlocker:Hide() end
    if self.previewPopup then self.previewPopup:Hide() end
end

-- Applies fresh data + state colors to one pooled card for `entry`.
function Catalog:PopulateCard(card, entry)
    local colors = palette()
    card.assignedEntry = entry
    card.name:SetText(entry.name)
    card.detail:SetText(entry.requirementText or entry.source or "")
    if entry.icon then
        card.icon:SetTexture(entry.icon)
        card.icon:Show()
    elseif entry.swatch then
        card.icon:SetColorTexture(entry.swatch[1], entry.swatch[2], entry.swatch[3], entry.swatch[4] or 1)
        card.icon:Show()
    else
        card.icon:Hide()
    end
    local stateColors = UI and UI:GetStateColor(entry.state, colors) or { bg = colors.panelRaised, border = colors.border, text = colors.text }
    applyBackdrop(card.statePill, stateColors.bg, stateColors.border)
    card.stateText:SetText(entry.state)
    card.stateText:SetTextColor(stateColors.text[1], stateColors.text[2], stateColors.text[3], 1)
    applyBackdrop(card, colors.panel, colors.border)
    -- VIEW always shows the in-place preview popup now (see ShowPreview),
    -- regardless of state -- previously this button was hidden entirely for
    -- UNLOCKED/EQUIPPED entries and, for LOCKED/READY, jumped straight to
    -- entry.action() (e.g. opening the whole Tetris game to see a
    -- background) instead of showing what the item actually looks like.
    card.actionButton:Show()
    card.actionButton.label:SetText("VIEW")
end

-- Moves to a specific page (clamped) and repopulates the grid.
function Catalog:GoToPage(pageIndex)
    local list = self.filteredList or {}
    local pageSize = self.pageSize or 1
    local totalPages = max(1, math.ceil(#list / pageSize))
    self.currentPage = max(1, min(totalPages, floor(tonumber(pageIndex) or 1)))
    self:UpdatePage(true)
end

-- Positions and populates one page's worth of pooled cards into the grid
-- (fills the width, wraps downward row by row) -- same virtualization idea
-- as CreshCollect/BattlePass.lua's pooled rows, just a 2D grid with
-- Prev/Next paging instead of a scrollbar, matching the dropdown-menu
-- convention already used elsewhere in Settings.lua.
function Catalog:UpdatePage(forceRepopulate)
    local list, pool = self.filteredList, self.cardPool
    if not list or not pool then return end
    local pageSize = self.pageSize or #pool
    local totalPages = max(1, math.ceil(#list / pageSize))
    self.currentPage = max(1, min(totalPages, self.currentPage or 1))
    local firstIdx = (self.currentPage - 1) * pageSize

    local columns = self.gridColumns or 1
    for poolI = 1, #pool do
        local listIdx = firstIdx + poolI - 1
        local entry = list[listIdx + 1]
        local card = pool[poolI]
        if entry then
            local col = (poolI - 1) % columns
            local row = floor((poolI - 1) / columns)
            card:ClearAllPoints()
            card:SetPoint("TOPLEFT", self.grid, "TOPLEFT", col * (CARD_WIDTH + CARD_GAP), -(row * (CARD_HEIGHT + CARD_GAP)))
            if forceRepopulate or card.assignedKey ~= entry.key then
                card.assignedKey = entry.key
                self:PopulateCard(card, entry)
            end
            card:Show()
        else
            card:Hide()
            card.assignedKey = nil
        end
    end

    if self.pageText then self.pageText:SetText("Page " .. self.currentPage .. " / " .. totalPages) end
    if self.previousPageButton then
        local enabled = self.currentPage > 1
        self.previousPageButton:SetAlpha(enabled and 1 or 0.4)
        self.previousPageButton.creshDisabled = not enabled
    end
    if self.nextPageButton then
        local enabled = self.currentPage < totalPages
        self.nextPageButton:SetAlpha(enabled and 1 or 0.4)
        self.nextPageButton.creshDisabled = not enabled
    end
end

-- ============================================================================
-- Refresh: rebuild the catalogue + filtered list, update the hero stats and
-- reposition/repopulate the pool. Called whenever the UNLOCKS tab is shown
-- (Solo:SelectHubTab) so the catalogue is always current; the pool itself
-- means only the visible rows are ever rebuilt, not the whole list.
-- ============================================================================

function Catalog:Refresh(forceRepopulate)
    if not self.panel then return end
    self:BuildCatalog()
    self:BuildFilteredList()
    self.currentPage = 1

    if self.heroTiles then
        if CG.BattlePass and self.heroTiles.ARCADE then
            local level, curXP, reqXP = CG.BattlePass:GetProgress()
            self.heroTiles.ARCADE.value:SetText("Lv " .. tostring(level or 1))
            self.heroTiles.ARCADE.label:SetText("ARCADE PASS · " .. tostring(curXP or 0) .. "/" .. tostring(reqXP or 50))
        end
        if CG.Tetris and self.heroTiles.TETRIS then
            local level = CG.Tetris:GetMasteryProgress()
            self.heroTiles.TETRIS.value:SetText("Lv " .. tostring(level or 1))
            self.heroTiles.TETRIS.label:SetText("TETRIS MASTERY")
        end
        if CG.DungeonDwellersPass and self.heroTiles.DUNGEON then
            local level = CG.DungeonDwellersPass:GetProgress()
            self.heroTiles.DUNGEON.value:SetText("Lv " .. tostring(level or 1))
            self.heroTiles.DUNGEON.label:SetText("DELVER MASTERY")
        end
    end

    if self.countText then
        local unlocked = 0
        for _, entry in ipairs(self.entries or {}) do
            if entry.state == "UNLOCKED" or entry.state == "EQUIPPED" then unlocked = unlocked + 1 end
        end
        self.countText:SetText(tostring(#(self.filteredList or {})) .. " shown · " .. unlocked .. "/" .. #(self.entries or {}) .. " unlocked")
    end

    self:UpdatePage(forceRepopulate ~= false)
end

-- Re-skins the already-built panel when the suite theme changes (called
-- from Solo:ApplyTheme(), same convention as Games:ApplyTheme()). Only
-- re-colors -- data/layout are untouched, and pooled cards are repopulated
-- so their state-pill colors (which also come from the palette) stay
-- correct.
function Catalog:ApplyTheme()
    if not self.panel then return end
    local colors = palette()
    applyBackdrop(self.panel, colors.panelSoft, colors.panelSoft)
    for _, tile in pairs(self.heroTiles or {}) do applyBackdrop(tile, colors.panelSoft, colors.border) end
    for _, card in ipairs(self.cardPool or {}) do
        applyBackdrop(card, colors.panel, colors.border)
        if card.assignedEntry then self:PopulateCard(card, card.assignedEntry) end
    end
end
