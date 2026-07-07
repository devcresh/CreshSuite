-- GamesUnlocksCatalogTests.lua
-- Lua 5.1 tests for Phase 5 (CreshGames Unlocks catalogue,
-- addons/CreshGames/GamesUnlocksCatalog.lua):
--   Catalog:BuildCatalog()   -- completeness: every source catalog's items
--                               appear exactly once, counts match
--   Catalog:MatchesFilter()  -- category/status/search combine correctly
--   State mapping            -- LOCKED/READY/UNLOCKED/EQUIPPED per category
--   Optional CreshCollect    -- CHAT_THEME category appears only when
--                               CreshCollect is loaded, no error either way
--   Catalog:BuildPanel/Refresh -- pooled UI smoke test (no crash, pool
--                               sized/shown correctly)
--
-- Loads the REAL production files (not reimplemented copies). Fixture
-- "already unlocked" state is set by writing directly into CreshGamesDB
-- (the SavedVariables shape), never by calling the unlock-granting
-- functions themselves (UnlockTheme/ClaimReward/etc.) -- those have their
-- own dedicated tests (ArcadePassTests.lua, MasteryConversionTests.lua) and
-- some go through notification helpers this file does not load.
--
-- Usage: lua GamesUnlocksCatalogTests.lua

-- ============================================================
-- Generic WoW widget mock (extends the one proven in
-- GamesHubRoutingTests.lua with EditBox/ScrollFrame methods, since
-- GamesUnlocksCatalog.lua's BuildPanel uses both).
-- ============================================================
local function mockWidget()
    local w = { _shown = true, _scripts = {}, _text = "", _alpha = 1, _w = 100, _h = 100, _scrollY = 0 }
    function w:SetPoint(point, _, relPoint, x, y)
        self._point = { point = point, relPoint = relPoint or point, x = x or 0, y = y or 0 }
    end
    function w:ClearAllPoints() self._point = nil end
    function w:SetAllPoints() end
    function w:GetPoint()
        local p = self._point or { point = "CENTER", relPoint = "CENTER", x = 0, y = 0 }
        return p.point, nil, p.relPoint, p.x, p.y
    end
    function w:SetSize(width, height) self._w, self._h = width, height end
    function w:SetWidth(width) self._w = width end
    function w:SetHeight(height) self._h = height end
    function w:GetWidth() return self._w end
    function w:GetHeight() return self._h end
    function w:SetFrameStrata() end
    function w:SetFrameLevel(level) self._level = level end
    function w:GetFrameLevel() return self._level or 1 end
    function w:SetClampedToScreen() end
    function w:SetMovable() end
    function w:EnableMouse() end
    function w:EnableKeyboard() end
    function w:EnableMouseWheel() end
    function w:SetPropagateKeyboardInput() end
    function w:RegisterForDrag() end
    function w:RegisterForClicks() end
    function w:RegisterEvent() end
    function w:UnregisterEvent() end
    function w:UnregisterAllEvents() end
    function w:SetScript(hook, fn) self._scripts[hook] = fn end
    function w:GetScript(hook) return self._scripts[hook] end
    function w:HookScript(hook, fn) self._scripts[hook] = fn end
    function w:Show() self._shown = true end
    function w:Hide() self._shown = false end
    function w:SetShown(v) self._shown = v and true or false end
    function w:IsShown() return self._shown == true end
    function w:IsVisible() return self._shown == true end
    function w:SetBackdrop() end
    function w:SetBackdropColor() end
    function w:SetBackdropBorderColor() end
    function w:StartMoving() end
    function w:StopMovingOrSizing() end
    function w:SetAlpha(a) self._alpha = a end
    function w:GetAlpha() return self._alpha end
    function w:SetScale(s) self._scale = s end
    function w:GetScale() return self._scale or 1 end
    function w:CreateTexture() return mockWidget() end
    function w:CreateFontString() return mockWidget() end
    function w:SetTexture() end
    function w:SetTexCoord() end
    function w:SetVertexColor() end
    function w:SetBlendMode() end
    function w:SetColorTexture() end
    function w:SetFont() end
    function w:SetFontObject() end
    function w:SetJustifyH() end
    function w:SetJustifyV() end
    function w:SetTextColor() end
    function w:SetText(t) self._text = t end
    function w:GetText() return self._text end
    function w:SetWordWrap() end
    function w:SetStatusBarTexture() end
    function w:SetMinMaxValues(lo, hi) self._min, self._max = lo, hi end
    function w:SetValue(v) self._value = v end
    function w:GetValue() return self._value or 0 end
    function w:SetStatusBarColor() end
    -- EditBox
    function w:SetAutoFocus() end
    function w:SetTextInsets() end
    function w:SetMaxLetters() end
    function w:ClearFocus() end
    -- ScrollFrame
    function w:SetScrollChild(child) self._scrollChild = child end
    function w:GetVerticalScroll() return self._scrollY end
    function w:SetVerticalScroll(v) self._scrollY = v end
    function w:GetVerticalScrollRange() return 5000 end
    return w
end

function CreateFrame(kind, name)
    local w = mockWidget()
    w._kind, w._name = kind, name
    return w
end
function time() return 0 end
function GetTime() return 0 end
_G.C_Timer = { After = function() end }
_G.hooksecurefunc = function() end
_G.UIParent = mockWidget()
_G.UIParent:SetSize(1920, 1080)
_G.GameTooltip = { SetOwner = function() end, SetText = function() end, AddLine = function() end, Show = function() end, Hide = function() end }
_G.GameFontHighlightSmall = {}
_G.GameFontNormalSmall = {}
_G.STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
_G.GetAddOnMetadata = function() return nil end

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

local function ok(cond, msg) if cond then pass(msg) else fail(msg) end end
local function eq(a, b, msg)
    if a == b then pass(msg)
    else fail(("%s  (expected %q, got %q)"):format(msg, tostring(b), tostring(a))) end
end

local function loadProductionFile(path, ...)
    local f = assert(io.open(path, "rb"))
    local src = f:read("*a")
    f:close()
    if src:sub(1, 3) == "\239\187\191" then src = src:sub(4) end
    local chunk = assert(loadstring(src, "@" .. path))
    return chunk(...)
end

-- ============================================================
-- Load the real production files, in real cross-addon load order.
-- ============================================================
_G.CreshChat = nil
_G.CreshCollectAPI = nil

loadProductionFile("shared/Suite.lua", "CreshGames", {})
loadProductionFile("shared/CreshUI.lua", "CreshGames", {})

_G.CreshGamesDB = nil
loadProductionFile("addons/CreshGames/CreshGamesDatabase.lua", "CreshGames", {})
_G.CreshGamesDatabase.Init()

local CG = { version = "0.2.3" }
loadProductionFile("addons/CreshGames/CreshGames.lua", "CreshGames", CG)
loadProductionFile("addons/CreshGames/CardDeckLibrary.lua", "CreshGames", CG)
loadProductionFile("addons/CreshGames/CardDecks.lua", "CreshGames", CG)
loadProductionFile("addons/CreshGames/DungeonCrawlerContent.lua", "CreshGames", CG)
loadProductionFile("addons/CreshGames/TetrisThemes.lua", "CreshGames", CG)
loadProductionFile("addons/CreshGames/GamesBattlePass.lua", "CreshGames", CG)
loadProductionFile("addons/CreshGames/SoloGames.lua", "CreshGames", CG)
loadProductionFile("addons/CreshGames/DungeonDwellersProgression.lua", "CreshGames", CG)
loadProductionFile("addons/CreshGames/GamesRewardRegistry.lua", "CreshGames", CG)
loadProductionFile("addons/CreshGames/GamesUnlocksCatalog.lua", "CreshGames", CG)

if not CG.UnlocksCatalog or not CG.RewardRegistry then
    print("FATAL: CG.UnlocksCatalog / CG.RewardRegistry not found after loading production files")
    os.exit(2)
end

local Catalog = CG.UnlocksCatalog

local function freshState()
    _G.CreshGamesDB = nil
    _G.CreshGamesDatabase.Init()
end

-- ============================================================
-- 1. Completeness: every source catalog's items appear exactly once
-- ============================================================
section("Completeness: counts match the real source catalogs")

freshState()
local entries = Catalog:BuildCatalog()
ok(#entries > 0, "catalogue is non-empty")

local seenKeys, duplicates = {}, 0
local countByCategory = {}
for _, entry in ipairs(entries) do
    if seenKeys[entry.key] then duplicates = duplicates + 1 end
    seenKeys[entry.key] = true
    countByCategory[entry.category] = (countByCategory[entry.category] or 0) + 1
end
eq(duplicates, 0, "no duplicate catalogue keys (every unlock appears once)")

local expectedDecks = 1
for _ in ipairs(CG.CardDecks.premiumOrder) do expectedDecks = expectedDecks + 1 end
eq(countByCategory.CARD_DECK, expectedDecks, "CARD_DECK count matches 1 default + premiumOrder")

eq(countByCategory.TETRIS_THEME, CG.Tetris:GetThemeCount(), "TETRIS_THEME count matches Tetris:GetThemeCount()")
eq(countByCategory.TETRIS_BACKGROUND, CG.Tetris:GetBackgroundThemeCount(), "TETRIS_BACKGROUND count matches Tetris:GetBackgroundThemeCount()")

local expectedArmour = 0
for _, classKey in ipairs(CG.DungeonCrawlerContent.classOrder) do
    expectedArmour = expectedArmour + #CG.DungeonCrawlerContent:GetArmourSets(classKey)
end
eq(countByCategory.DUNGEON_ARMOUR, expectedArmour, "DUNGEON_ARMOUR count matches the sum of every class's armour sets")

eq(countByCategory.DUNGEON_MINION, #CG.SoloGames:GetMinionSkinCatalog(), "DUNGEON_MINION count matches the deduped minion-skin catalog")
ok(countByCategory.DUNGEON_MINION > 0 and countByCategory.DUNGEON_MINION <= 26, "minion skin count is a sane deduped size (>0, <=26 raw variant slots)")

eq(countByCategory.DUNGEON_MILESTONE, 5, "DUNGEON_MILESTONE count matches the 5 fixed milestone levels (20/40/60/80/100)")

ok(countByCategory.CHAT_THEME == nil, "no CHAT_THEME entries when CreshCollect is not loaded")

-- ============================================================
-- 2. State mapping: LOCKED / READY / UNLOCKED / EQUIPPED
-- ============================================================
section("State mapping: card decks")

-- CardDecks:Ensure() assigns a random starter deck from premiumOrder (always
-- already-unlocked) -- pick a premium deck that is NOT that starter deck for
-- the LOCKED/READY/UNLOCKED/EQUIPPED fixtures below, so the test can't
-- flake depending on which deck the identity hash happens to pick.
freshState()
local starterDeck = CG.CardDecks:Ensure().starterDeck
local premiumDeckKey
for _, key in ipairs(CG.CardDecks.premiumOrder) do
    if key ~= starterDeck then premiumDeckKey = key break end
end
ok(premiumDeckKey ~= nil, "sanity: at least one premium deck other than the random starter deck exists")

entries = Catalog:BuildCatalog()
local function findEntry(key) for _, e in ipairs(entries) do if e.key == key then return e end end end

local deckEntry = findEntry("CARD_DECK:" .. premiumDeckKey)
ok(deckEntry ~= nil, "premium deck entry exists in the catalogue")
eq(deckEntry.state, "LOCKED", "an unowned premium deck starts LOCKED")

-- Find this deck's Arcade Pass required level via the registry itself, then
-- mark that pass level reached-but-unclaimed -- should become READY.
local requiredLevel
for _, reward in ipairs(CG.RewardRegistry.arcadeRewards) do
    if reward.type == "CARD_DECK" and reward.unlockKey == premiumDeckKey then requiredLevel = reward.requiredLevel end
end
if requiredLevel then
    CG.BattlePass:Ensure().xp = CG.BattlePass:GetCumulativeXP(requiredLevel)
    entries = Catalog:BuildCatalog()
    deckEntry = findEntry("CARD_DECK:" .. premiumDeckKey)
    eq(deckEntry.state, "READY", "reached-but-unclaimed Arcade Pass level makes the deck READY")
    CG.BattlePass:Ensure().xp = 0
else
    fail("could not find an Arcade Pass level for deck " .. tostring(premiumDeckKey) .. " to test READY state")
end

CreshGamesDB.cardDecks.unlocked[premiumDeckKey] = true
entries = Catalog:BuildCatalog()
deckEntry = findEntry("CARD_DECK:" .. premiumDeckKey)
eq(deckEntry.state, "UNLOCKED", "an owned-but-not-selected deck is UNLOCKED")

CreshGamesDB.cardDecks.selected.HOLDEM = premiumDeckKey
entries = Catalog:BuildCatalog()
deckEntry = findEntry("CARD_DECK:" .. premiumDeckKey)
eq(deckEntry.state, "EQUIPPED", "a deck selected for HOLDEM is EQUIPPED")

section("State mapping: Tetris themes")

freshState()
-- CLASSIC_BLOCKS is always DEFAULT/unlocked.
entries = Catalog:BuildCatalog()
local defaultTheme = findEntry("TETRIS_THEME:CLASSIC_BLOCKS")
ok(defaultTheme ~= nil, "the default Tetris theme is in the catalogue")
eq(defaultTheme.state, "EQUIPPED", "CLASSIC_BLOCKS starts both unlocked and selected (EQUIPPED)")

-- Find a GAME_LEVEL-sourced theme (no READY state possible -- automatic
-- unlock, no separate claim step) and confirm it starts LOCKED.
local gameLevelThemeKey
for _, key in ipairs(CG.Tetris.themeOrder) do
    if CG.Tetris.themes[key].source == "GAME_LEVEL" then gameLevelThemeKey = key break end
end
ok(gameLevelThemeKey ~= nil, "sanity: at least one GAME_LEVEL-sourced theme exists")
if gameLevelThemeKey then
    local themeEntry = findEntry("TETRIS_THEME:" .. gameLevelThemeKey)
    eq(themeEntry.state, "LOCKED", "an un-reached GAME_LEVEL theme is LOCKED")
    CreshGamesDB.soloGames.tetris.unlockedThemes[gameLevelThemeKey] = true
    entries = Catalog:BuildCatalog()
    themeEntry = findEntry("TETRIS_THEME:" .. gameLevelThemeKey)
    eq(themeEntry.state, "UNLOCKED", "unlocking it directly (as real game-level automation would) makes it UNLOCKED")
end

section("State mapping: dungeon armour")

freshState()
local armourClass = CG.DungeonCrawlerContent.classOrder[1]
local armourSet = CG.DungeonCrawlerContent:GetArmourSets(armourClass)[1]
entries = Catalog:BuildCatalog()
local armourEntry = findEntry("DUNGEON_ARMOUR:" .. armourSet.key)
eq(armourEntry.state, "LOCKED", "an un-owned armour set starts LOCKED")

CreshGamesDB.soloGames.dungeon.unlockedArmour[armourSet.key] = true
entries = Catalog:BuildCatalog()
armourEntry = findEntry("DUNGEON_ARMOUR:" .. armourSet.key)
eq(armourEntry.state, "UNLOCKED", "an owned-but-not-equipped armour set is UNLOCKED")

CreshGamesDB.soloGames.dungeon.equippedArmour[armourClass] = armourSet.key
entries = Catalog:BuildCatalog()
armourEntry = findEntry("DUNGEON_ARMOUR:" .. armourSet.key)
eq(armourEntry.state, "EQUIPPED", "an equipped armour set is EQUIPPED")

section("State mapping: dungeon milestone chests")

freshState()
entries = Catalog:BuildCatalog()
local milestone20 = findEntry("DUNGEON_MILESTONE:20")
eq(milestone20.state, "LOCKED", "an unreached milestone chest is LOCKED")

CreshGamesDB.soloGames.dungeon.bestRoom = 25
entries = Catalog:BuildCatalog()
milestone20 = findEntry("DUNGEON_MILESTONE:20")
eq(milestone20.state, "UNLOCKED", "reaching dungeon level 25 unlocks the level-20 milestone chest")
local milestone40 = findEntry("DUNGEON_MILESTONE:40")
eq(milestone40.state, "LOCKED", "the level-40 milestone chest stays LOCKED at dungeon level 25")

-- ============================================================
-- 3. Filter/search combination
-- ============================================================
section("Filter/search: category, status and search AND-combine")

freshState()
CreshGamesDB.soloGames.dungeon.unlockedArmour[armourSet.key] = true
Catalog.filterCategory, Catalog.filterStatus, Catalog.filterSearch = "ALL", "ALL", ""
Catalog:BuildCatalog()
local allCount = #Catalog:BuildFilteredList()
ok(allCount == #Catalog.entries, "ALL/ALL/'' shows every entry")

Catalog.filterCategory = "DUNGEON_ARMOUR"
local armourOnly = Catalog:BuildFilteredList()
ok(#armourOnly > 0 and #armourOnly < allCount, "category filter narrows the list")
for _, e in ipairs(armourOnly) do
    if e.category ~= "DUNGEON_ARMOUR" then fail("category filter leaked a non-matching entry: " .. tostring(e.key)) end
end
pass("category filter only returns DUNGEON_ARMOUR entries")

Catalog.filterStatus = "UNLOCKED"
local armourUnlocked = Catalog:BuildFilteredList()
ok(#armourUnlocked >= 1, "at least the fixture-unlocked armour set passes category+status combined")
for _, e in ipairs(armourUnlocked) do
    if e.category ~= "DUNGEON_ARMOUR" or (e.state ~= "UNLOCKED" and e.state ~= "EQUIPPED") then
        fail("category+status filter leaked a non-matching entry: " .. tostring(e.key))
    end
end
pass("category+status filters combine with AND semantics")

Catalog.filterCategory, Catalog.filterStatus = "ALL", "ALL"
Catalog.filterSearch = string.lower(armourSet.name or armourSet.key)
local searched = Catalog:BuildFilteredList()
ok(#searched >= 1, "search finds the fixture armour set by name")
Catalog.filterSearch = "zzz_no_such_item_zzz"
local noMatches = Catalog:BuildFilteredList()
eq(#noMatches, 0, "a nonsense search returns no entries")
Catalog.filterSearch = ""

-- ============================================================
-- 4. Optional CreshCollect integration
-- ============================================================
section("Optional CreshCollect: absent -> no CHAT_THEME category, no error")

ok(_G.CreshSuite:IsProductLoaded("CreshCollect") == false, "sanity: CreshCollect is not registered yet")
local categories = Catalog:GetCategoryOrder()
local hasChat = false
for _, key in ipairs(categories) do if key == "CHAT_THEME" then hasChat = true end end
ok(not hasChat, "CHAT_THEME is not offered as a filter category when CreshCollect is absent")

local okBuild, errBuild = pcall(function() return Catalog:BuildCatalog() end)
ok(okBuild, "BuildCatalog() does not error when CreshCollect is absent (err: " .. tostring(not okBuild and errBuild or "") .. ")")

section("Optional CreshCollect: present -> CHAT_THEME entries appear")

_G.CreshSuite:RegisterProduct("CreshCollect", "0.1.0", {})
_G.CreshCollectAPI = {
    GetChatThemeEntitlements = function()
        return { { key = "MIDNIGHT_AZURE", source = "CHRONICLE_LEVEL:40" } }
    end,
}
categories = Catalog:GetCategoryOrder()
hasChat = false
for _, key in ipairs(categories) do if key == "CHAT_THEME" then hasChat = true end end
ok(hasChat, "CHAT_THEME is offered as a filter category once CreshCollect is loaded")

entries = Catalog:BuildCatalog()
local chatEntry = findEntry("CHAT_THEME:MIDNIGHT_AZURE")
ok(chatEntry ~= nil, "the CreshCollect-sourced chat theme entry appears")
eq(chatEntry.state, "UNLOCKED", "an entitlement returned by CreshCollectAPI is shown UNLOCKED")
eq(chatEntry.ownerAddon, "CRESHCOLLECT", "the entry is correctly attributed to CreshCollect, not CreshGames")

_G.CreshCollectAPI = nil
_G.CreshSuite = nil
loadProductionFile("shared/Suite.lua", "CreshGames", {})

-- ============================================================
-- 5. BuildPanel/Refresh -- paginated card-grid smoke test
-- ============================================================
section("BuildPanel/Refresh: builds a card grid that fills the width, pages correctly")

freshState()
local parent = mockWidget()
parent:SetSize(746, 574) -- realistic panel size, so column math matches production
Catalog.panel = nil -- force a fresh build against the new mock parent
local okPanel, errPanel = pcall(function() Catalog:BuildPanel(parent) end)
ok(okPanel, "BuildPanel() does not error (err: " .. tostring(not okPanel and errPanel or "") .. ")")
eq(Catalog.gridColumns, 4, "4 cards fit across a 746px-wide panel (176px cards, 8px gaps)")
eq(#Catalog.cardPool, Catalog.gridColumns * 4, "the card pool is sized for exactly one page (columns x 4 rows)")

local okRefresh, errRefresh = pcall(function() Catalog:Refresh(true) end)
ok(okRefresh, "Refresh() does not error (err: " .. tostring(not okRefresh and errRefresh or "") .. ")")
eq(Catalog.currentPage, 1, "Refresh() resets to page 1")

local shownCards = 0
for _, card in ipairs(Catalog.cardPool) do if card:IsShown() then shownCards = shownCards + 1 end end
ok(shownCards == math.min(Catalog.pageSize, #Catalog.filteredList), "exactly min(pageSize, filteredCount) cards are shown")
ok(shownCards > 0, "sanity: at least one card is actually visible")

-- Cards should tile left-to-right, wrapping down row by row (not a single
-- tall column) -- confirm at least two distinct X positions are used.
local seenX = {}
for _, card in ipairs(Catalog.cardPool) do
    if card:IsShown() then
        local _, _, _, x = card:GetPoint()
        seenX[x] = true
    end
end
local distinctX = 0
for _ in pairs(seenX) do distinctX = distinctX + 1 end
ok(distinctX > 1, "cards use more than one horizontal position (fills the width instead of stacking in one column)")

section("Page navigation: GoToPage clamps and updates the page indicator")

local totalPages = math.max(1, math.ceil(#Catalog.filteredList / Catalog.pageSize))
Catalog:GoToPage(9999)
eq(Catalog.currentPage, totalPages, "GoToPage clamps above the last page to the last page")
Catalog:GoToPage(-5)
eq(Catalog.currentPage, 1, "GoToPage clamps below page 1 to page 1")
ok(Catalog.pageText:GetText():find("Page 1"), "the page indicator reflects the current page")

-- ============================================================
section("VIEW: shows an in-place preview instead of jumping straight to entry.action()")
-- ============================================================

ok(Catalog.previewBlocker ~= nil and Catalog.previewPopup ~= nil, "BuildPanel() built the preview popup")
ok(Catalog.previewBlocker:IsShown() == false, "preview starts hidden")

local lockedEntry, readyEntry, unlockedEntry
for _, entry in ipairs(Catalog.filteredList) do
    if entry.state == "LOCKED" and entry.action then lockedEntry = lockedEntry or entry end
    if entry.state == "READY" and entry.action then readyEntry = readyEntry or entry end
    if (entry.state == "UNLOCKED" or entry.state == "EQUIPPED") then unlockedEntry = unlockedEntry or entry end
end

ok(lockedEntry ~= nil, "sanity: a LOCKED entry with an action exists in this fixture")
Catalog:ShowPreview(lockedEntry)
ok(Catalog.previewBlocker:IsShown() and Catalog.previewPopup:IsShown(), "ShowPreview() shows the blocker and popup")
eq(Catalog.previewPopup.name:GetText(), lockedEntry.name, "preview shows the entry's name")
ok(Catalog.previewPopup.actionButton:IsShown(), "a LOCKED entry with an action still offers the secondary action button")
eq(Catalog.previewPopup.actionButton.label:GetText(), "TRACK PROGRESS", "the secondary button is labelled TRACK PROGRESS for a LOCKED entry")

Catalog:HidePreview()
ok(not Catalog.previewBlocker:IsShown() and not Catalog.previewPopup:IsShown(), "HidePreview() hides both the blocker and popup")

if readyEntry then
    Catalog:ShowPreview(readyEntry)
    eq(Catalog.previewPopup.actionButton.label:GetText(), "CLAIM", "the secondary button is labelled CLAIM for a READY entry")
    Catalog:HidePreview()
end

if unlockedEntry then
    Catalog:ShowPreview(unlockedEntry)
    ok(not unlockedEntry.action, "sanity: an UNLOCKED/EQUIPPED entry has no action")
    ok(not Catalog.previewPopup.actionButton:IsShown(), "an already-owned entry's preview has no secondary action button")
    Catalog:HidePreview()
end

-- Every populated card's VIEW button must always be visible, regardless of
-- state -- this used to be hidden entirely for UNLOCKED/EQUIPPED entries.
Catalog:Refresh(true)
local anyCardHidden = false
for _, card in ipairs(Catalog.cardPool) do
    if card.assignedEntry and not card.actionButton:IsShown() then anyCardHidden = true end
end
ok(not anyCardHidden, "every populated card's VIEW button is shown regardless of entry state")

-- ============================================================
-- Summary
-- ============================================================
print(("\n=== Results: %d passed, %d failed ==="):format(PASS, FAIL))
if FAIL > 0 then os.exit(1) end
