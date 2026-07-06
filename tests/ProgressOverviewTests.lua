-- ProgressOverviewTests.lua
-- Lua 5.1 tests for the Progress Overview (addons/CreshCollect/ProgressOverview.lua),
-- added in Phase 7. Split into two independent concerns, per the phase spec
-- ("validate calculations independently from rendering"):
--   1. Overview:GetSummary() -- pure data, no frames touched at all.
--   2. BuildWindow/OpenWindow/RefreshWindow -- rendering, using a mock frame.
--
-- Loads the REAL production files (BattlePass.lua, Achievements.lua,
-- ProgressOverview.lua) via the loadfile + explicit-vararg technique
-- established by SlashCommandTests.lua / ProgressionWindowTests.lua.
--
-- Usage: lua ProgressOverviewTests.lua [BattlePass.lua] [Achievements.lua] [ProgressOverview.lua]

-- ============================================================
-- Generic mock WoW frame (same as ProgressionWindowTests.lua)
-- ============================================================

local function mockFrame()
    local obj = { _shown = false, _text = "", _scripts = {}, _scroll = 0, _alpha = 1 }
    local mt = {}
    mt.__index = function(t, k)
        local fn
        if k == "CreateFontString" or k == "CreateTexture" then
            fn = function() return mockFrame() end
        elseif k == "GetVerticalScroll" then
            fn = function(self) return self._scroll end
        elseif k == "GetVerticalScrollRange" or k == "GetWidth" or k == "GetHeight" then
            fn = function() return 100 end
        elseif k == "IsShown" then
            fn = function(self) return self._shown == true end
        elseif k == "Show" then
            fn = function(self) self._shown = true end
        elseif k == "Hide" then
            fn = function(self) self._shown = false end
        elseif k == "SetText" then
            fn = function(self, text) self._text = tostring(text or "") end
        elseif k == "GetText" then
            fn = function(self) return self._text end
        elseif k == "SetAlpha" then
            fn = function(self, a) self._alpha = a end
        elseif k == "GetPoint" then
            fn = function() return "CENTER", nil, "CENTER", 0, 0 end
        elseif k == "SetScript" then
            fn = function(self, hook, handler) self._scripts[hook] = handler end
        elseif k == "GetScript" then
            fn = function(self, hook) return self._scripts[hook] end
        else
            fn = function(self, ...) return self end
        end
        rawset(t, k, fn)
        return fn
    end
    return setmetatable(obj, mt)
end

function CreateFrame(frameType, name)
    local f = mockFrame()
    if name then _G[name] = f end
    return f
end
function time() return 0 end
function GetTime() return 0 end
_G.C_Timer = { After = function() end }
_G.UIParent = mockFrame()
_G.GameTooltip = mockFrame()
_G.GameFontNormalSmall = {}
_G.GameFontHighlightSmall = {}
_G.STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"

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

-- ============================================================
-- Load the real production files
-- ============================================================

local battlePassPath      = (arg and arg[1]) or "addons/CreshCollect/BattlePass.lua"
local achievementsPath    = (arg and arg[2]) or "addons/CreshCollect/Achievements.lua"
local progressOverviewPath = (arg and arg[3]) or "addons/CreshCollect/ProgressOverview.lua"

local function loadProductionFile(path, ...)
    local f = assert(io.open(path, "rb"))
    local src = f:read("*a")
    f:close()
    if src:sub(1, 3) == "\239\187\191" then src = src:sub(4) end
    local chunk = assert(loadstring(src, "@" .. path))
    return chunk(...)
end

local function freshCreshCollectDB()
    return {
        achievements  = { unlocked = {}, progress = {}, stats = {}, uniqueBosses = {}, professionRanks = {}, visitedZones = {}, totalCoins = 0, totalPassXP = 0 },
        arcadeRewards = { coins = 0, lifetimeCoins = 0, gameCoins = 0, activityCoins = 0, explorationCoins = 0, spentCoins = 0, passXP = 0, claimed = {}, unlockedThemes = {}, themeUnlockSources = {}, recent = {}, gamesRewarded = 0, milestoneGoals = {} },
        collections   = { themes = {}, backgrounds = {}, cardDecks = {}, dungeonArmour = {}, cosmetics = {} },
    }
end

local COL = { version = "0.2.3" }
_G.CreshCollectDB = freshCreshCollectDB()
loadProductionFile(battlePassPath, "CreshCollect", COL)
loadProductionFile(achievementsPath, "CreshCollect", COL)
loadProductionFile(progressOverviewPath, "CreshCollect", COL)

local Pass, Achievements, Overview = COL.BattlePass, COL.Achievements, COL.ProgressOverview
if not Overview or not Overview.GetSummary or not Overview.BuildWindow or not Overview.RefreshWindow then
    print("FATAL: CreshCollect.ProgressOverview / GetSummary / BuildWindow / RefreshWindow not found")
    os.exit(2)
end

-- ============================================================
-- 1. Pure calculation: no progress (fresh save)
-- ============================================================
section("GetSummary: no progress (fresh save, CreshGames absent)")

_G.CreshSuite = nil
_G.CreshChat = nil
local s1 = Overview:GetSummary()

ok(s1.battlePass.hasData, "battlePass section has data (BattlePass module is present)")
eq(s1.battlePass.level, 1, "fresh save starts at level 1")
eq(s1.battlePass.claimed, 0, "fresh save has 0 claimed rewards")
eq(s1.battlePass.ratio, Overview.safeRatio(0, s1.battlePass.required), "battle pass progress ratio computed via safeRatio, not raw division")

ok(s1.achievements.hasData, "achievements section has data")
eq(s1.achievements.unlocked, 0, "fresh save has 0 unlocked achievements")
ok(s1.achievements.total > 0, "achievement catalog has a non-zero total (sanity check)")
eq(s1.achievements.ratio, 0, "0 unlocked / positive total = ratio 0, no error")

ok(s1.collections.hasData, "collections section has data")
eq(s1.collections.totalUnlocked, 0, "fresh save has 0 unlocked collection items")
eq(s1.collections.totalKnown, nil, "totalKnown is nil (unknowable) when CreshGames is absent")
ok(s1.gamesLoaded == false, "gamesLoaded correctly false with no CreshSuite/CreshChat at all")

ok(s1.creshGames.hasData == false, "creshGames section has no data when CreshGames is absent (Rework Phase 9)")

for _, bucket in ipairs(s1.collections.buckets) do
    ok(bucket.total == nil or bucket.key == "dungeonArmour" or bucket.key == "cosmetics" or bucket.total == nil,
        "bucket '" .. bucket.key .. "' has no total without CreshGames (avoids a fabricated number)")
    eq(Overview.ratioText(bucket.unlocked, bucket.total), bucket.total and (tostring(bucket.unlocked) .. " / " .. tostring(bucket.total)) or tostring(bucket.unlocked),
        "ratioText for '" .. bucket.key .. "' renders without a total when total is nil")
end

-- ============================================================
-- 2. Pure calculation: zero-total safety (division-by-zero guard)
-- ============================================================
section("safeRatio / ratioText: zero and unknown totals never error")

eq(Overview.safeRatio(0, 0), 0, "safeRatio(0, 0) = 0, not NaN or an error")
eq(Overview.safeRatio(5, 0), 0, "safeRatio(5, 0) = 0 (defensive: total can't actually be < count, but must not divide by zero)")
eq(Overview.safeRatio(5, 10), 0.5, "safeRatio(5, 10) = 0.5 for a normal case")
eq(Overview.ratioText(0, 0), "0 / 0", "ratioText(0, 0) renders '0 / 0' cleanly")
eq(Overview.ratioText(3, nil), "3", "ratioText with a nil total renders just the count")

-- ============================================================
-- 3. Pure calculation: partial progress
-- ============================================================
section("GetSummary: partial progress")

CreshCollectDB.arcadeRewards.passXP = Pass:GetCumulativeXP(10) + 5
CreshCollectDB.arcadeRewards.claimed["3"] = true
CreshCollectDB.arcadeRewards.claimed["7"] = true
local someKey
for _, a in ipairs(Achievements.catalog) do someKey = a.key break end
CreshCollectDB.achievements.unlocked[someKey] = { at = 1, value = 1 }
CreshCollectDB.collections.themes.ZONE_ELWYNN_FOREST = true
CreshCollectDB.collections.cardDecks.Alliance_Vanguard = true

local s3 = Overview:GetSummary()
eq(s3.battlePass.level, 10, "battle pass level reflects the fixture's passXP")
eq(s3.battlePass.claimed, 2, "2 claimed rewards reflected")
eq(s3.achievements.unlocked, 1, "1 unlocked achievement reflected")
eq(s3.collections.totalUnlocked, 2, "2 unlocked collection items (1 theme + 1 deck) reflected")
ok(s3.battlePass.ratio > 0 and s3.battlePass.ratio <= 1, "battle pass ratio is within (0, 1]")
ok(s3.achievements.ratio > 0 and s3.achievements.ratio < 1, "achievements ratio is within (0, 1) for a partial state")

-- ============================================================
-- 4. Pure calculation: full progress (maxed level, all rewards claimed,
--    every achievement unlocked)
-- ============================================================
section("GetSummary: full progress")

CreshCollectDB.arcadeRewards.passXP = Pass:GetCumulativeXP(Pass.maxLevel)
for level = 1, Pass.maxLevel do CreshCollectDB.arcadeRewards.claimed[tostring(level)] = true end
for _, a in ipairs(Achievements.catalog) do CreshCollectDB.achievements.unlocked[a.key] = { at = 1, value = a.goal } end

local s4 = Overview:GetSummary()
eq(s4.battlePass.level, Pass.maxLevel, "battle pass reaches max level")
eq(s4.battlePass.claimed, Pass.maxLevel, "every reward level is claimed")
eq(s4.battlePass.claimedRatio, 1, "claimedRatio is exactly 1 at full completion")
eq(s4.achievements.unlocked, s4.achievements.total, "every achievement is unlocked")
eq(s4.achievements.ratio, 1, "achievements ratio is exactly 1 at full completion")

-- ============================================================
-- 5. Pure calculation: missing-addon states
-- ============================================================
section("GetSummary: CreshGames present -> collection/category totals become known")

_G.CreshSuite = {
    _loaded = { CRESHGAMES = true },
    IsProductLoaded = function(self, name) return self._loaded[string.upper(tostring(name or ""))] == true end,
}
_G.CreshChat = {
    Tetris = {
        GetThemeCount = function() return 50 end,
        GetBackgroundThemeCount = function() return 50 end,
    },
    CardDecks = { premiumOrder = { "A", "B", "C", "D", "E", "F" } },
}
-- Rework Phase 9: the creshGames section reads exclusively through
-- CreshGamesAPI (never CC.* directly), unlike the pre-existing collections
-- totals above.
_G.CreshGamesAPI = {
    GetArcadePassProgress   = function() return 42, 10, 100, 0.1 end,
    GetGameMasteryProgress  = function(game)
        if game == "TETRIS" then return 7, 5, 50, 0.1 end
        if game == "DUNGEON" then return 3, 2, 40, 0.05 end
        return 1, 0, 1, 0
    end,
    GetGameAchievementCounts = function() return 12, 116 end,
}
local s5 = Overview:GetSummary()
ok(s5.gamesLoaded, "gamesLoaded is true once CreshSuite reports CreshGames registered")

ok(s5.creshGames.hasData, "creshGames section has data once CreshGames + CreshGamesAPI are present")
eq(s5.creshGames.arcadePass.level, 42, "arcadePass level comes from CreshGamesAPI.GetArcadePassProgress()")
eq(s5.creshGames.tetrisMastery.level, 7, "tetrisMastery level comes from CreshGamesAPI.GetGameMasteryProgress('TETRIS')")
eq(s5.creshGames.delverMastery.level, 3, "delverMastery level comes from CreshGamesAPI.GetGameMasteryProgress('DUNGEON')")
eq(s5.creshGames.achievements.unlocked, 12, "creshGames achievements unlocked comes from CreshGamesAPI.GetGameAchievementCounts()")
eq(s5.creshGames.achievements.total, 116, "creshGames achievements total comes from CreshGamesAPI.GetGameAchievementCounts()")
eq(s5.creshGames.achievements.ratio, Overview.safeRatio(12, 116), "creshGames achievements ratio computed via safeRatio")
local themesBucket, decksBucket
for _, b in ipairs(s5.collections.buckets) do
    if b.key == "themes" then themesBucket = b end
    if b.key == "cardDecks" then decksBucket = b end
end
eq(themesBucket.total, 50, "themes total now comes from CC.Tetris:GetThemeCount()")
eq(decksBucket.total, 6, "cardDecks total now comes from #CC.CardDecks.premiumOrder")
eq(s5.collections.totalKnown, 50 + 50 + 6, "totalKnown sums the three buckets with known totals")

-- Rework Phase 5: GAMES achievements (and Dungeon Dwellers') moved to
-- CreshGames entirely, so COL.Achievements.categoryOrder no longer has a
-- GAMES entry at all -- CreshCollect's achievement breakdown is World-only
-- now, regardless of whether CreshGames is loaded.
local gamesCat
for _, cat in ipairs(s5.achievements.categories) do
    if cat.key == "GAMES" then gamesCat = cat end
end
ok(gamesCat == nil, "GAMES category is absent from CreshCollect's achievements breakdown even when CreshGames is loaded")

-- Rendering check while CreshGamesAPI is still mocked, before the reset
-- below -- confirms the CreshGames card actually reflects "available".
local okBuild5, errBuild5 = pcall(function() Overview:BuildWindow() end)
ok(okBuild5, "BuildWindow() does not error while CreshGames is loaded (err: " .. tostring(errBuild5) .. ")")
Overview:OpenWindow()
ok(Overview.gamesCard._alpha == 1, "CreshGames card is fully opaque once CreshGamesAPI data is available")
ok(Overview.gamesCard.rows[1].value._text:find("42") ~= nil, "Arcade Pass row shows the mocked level 42")
ok(Overview.gamesCard.rows[2].value._text:find("7") ~= nil, "Tetris Mastery row shows the mocked level 7")
ok(Overview.gamesCard.rows[3].value._text:find("3") ~= nil, "Delver Mastery row shows the mocked level 3")
ok(Overview.gamesCard.rows[4].value._text:find("12") ~= nil, "Achievements row shows the mocked unlocked count 12")

_G.CreshSuite = nil
_G.CreshChat = nil
_G.CreshGamesAPI = nil
local s6 = Overview:GetSummary()
local gamesCat2
for _, cat in ipairs(s6.achievements.categories) do
    if cat.key == "GAMES" then gamesCat2 = cat end
end
ok(gamesCat2 == nil, "GAMES category stays absent when CreshGames is unloaded too -- CreshCollect never had it")
ok(s6.creshGames.hasData == false, "creshGames section has no data once CreshGames is unloaded again")

-- ============================================================
-- 6. Rendering: window build/open/refresh, using the calculations above
-- ============================================================
section("Window: build/open/refresh without error, across all the states above")

local okBuild, errBuild = pcall(function() Overview:BuildWindow() end)
ok(okBuild, "BuildWindow() does not error (err: " .. tostring(errBuild) .. ")")
local okOpen, errOpen = pcall(function() Overview:OpenWindow() end)
ok(okOpen, "OpenWindow() does not error (err: " .. tostring(errOpen) .. ")")
ok(Overview:IsWindowOpen(), "window reports open")

ok(Overview.bpCard._alpha == 1, "Battle Pass card is fully opaque when its data is available")
ok(Overview.achCard._alpha == 1, "Achievements card is fully opaque when its data is available")
ok(Overview.colCard._alpha == 1, "Collections card is fully opaque when its data is available")
ok(Overview.bpCard.levelText._text:find(tostring(Pass.maxLevel)) ~= nil, "Battle Pass card shows the maxed level text")
ok(Overview.gamesCard._alpha == 0.5, "CreshGames card is dimmed once CreshGames is unloaded again (Rework Phase 9)")

Overview:CloseWindow()
ok(not Overview:IsWindowOpen(), "window reports closed after CloseWindow()")

-- ============================================================
-- Summary
-- ============================================================
print(("\n=== Results: %d passed, %d failed ==="):format(PASS, FAIL))
if FAIL > 0 then os.exit(1) end
