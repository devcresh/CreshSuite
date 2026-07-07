local _, COL = ...
if not COL then return end

local CC = setmetatable({}, { __index = function(_, k)
    local c = _G.CreshChat
    return c and c[k]
end })

local Achievements = {
    version = COL.version,
    catalog = {},
    byKey = {},
    categoryOrder = { "EXPLORATION", "COMBAT", "DUNGEONS", "PROFESSIONS" },
    categoryNames = {
        EXPLORATION = "Exploration",
        COMBAT = "Combat",
        DUNGEONS = "Dungeons & Bosses",
        PROFESSIONS = "Professions",
    },
    -- Which feature flags must be enabled for each achievement category to be active.
    -- A category with no entry here is always shown (no feature dependency).
    categoryRequiredFeatures = {
        COMBAT      = { "combatTracking" },
        EXPLORATION = { "worldProgression" },
        DUNGEONS    = { "worldProgression" },
        PROFESSIONS = { "worldProgression" },
    },
}
COL.Achievements = Achievements
if COL.RegisterModule then COL:RegisterModule("Achievements", Achievements) end

local floor, max, min, ceil = math.floor, math.max, math.min, math.ceil
local upper, lower = string.upper, string.lower
local format = string.format

local function isCategoryEnabled(category)
    local required = Achievements.categoryRequiredFeatures[category]
    if not required then return true end
    if not (CC.IsFeatureEnabled) then return true end
    for _, feature in ipairs(required) do
        if CC:IsFeatureEnabled(feature) then return true end
    end
    return false
end

-- Per-achievement addon requirement (e.g. a handful of COMMUNITY
-- achievements require CreshChat). Rework Phase 5 removed the category-level
-- version of this check (categoryRequiredAddon/categoryMissingAddon) along
-- with the GAMES category, which was its only user -- CreshCollect no
-- longer has any category whose entire content requires another addon.
local function achievementMissingAddon(achievement)
    if type(achievement) ~= "table" then return nil end
    local addonName = achievement.requiredAddon
    if not addonName then return nil end
    if _G.CreshSuite and _G.CreshSuite:IsProductLoaded(addonName) then return nil end
    return addonName
end
-- Test-only hook (see tests/AchievementsAvailabilityTests.lua) for the pure
-- logic above; production code should call it only from RefreshDrawerPanel.
Achievements._TESTONLY_IsCategoryEnabled = isCategoryEnabled
Achievements._TESTONLY_AchievementMissingAddon = achievementMissingAddon

function Achievements:GetMissingAddon(achievementOrKey)
    local achievement = type(achievementOrKey) == "table" and achievementOrKey or self.byKey[tostring(achievementOrKey or "")]
    return achievementMissingAddon(achievement)
end

function Achievements:IsAvailable(achievementOrKey)
    local achievement = type(achievementOrKey) == "table" and achievementOrKey or self.byKey[tostring(achievementOrKey or "")]
    if not achievement then return false, nil end
    local missingAddon = achievementMissingAddon(achievement)
    return missingAddon == nil and isCategoryEnabled(achievement.category), missingAddon
end

-- ============================================================
-- Phase 2: shared filter contract used by BOTH the standalone window
-- (RefreshWindow) and the drawer panel (RefreshDrawerPanel), plus the
-- pre-refresh height estimate (GetPanelHeight), so all three can never
-- drift apart from one another.
-- ============================================================

-- Same UnitClass("player") resolution ClassAchievements.lua already uses
-- internally (its own private currentClass()) -- kept as an independent
-- copy here since Achievements.lua has no load-order dependency on
-- ClassAchievements.lua and shouldn't gain one just for this.
function Achievements:GetPlayerClassToken()
    if type(_G.UnitClass) == "function" then
        local _, token = _G.UnitClass("player")
        return upper(tostring(token or ""))
    end
    return ""
end

-- Sorted, de-duplicated list of class tokens actually present in the
-- CLASSES category of the catalog. Returns {} before ClassAchievements.lua
-- has run BuildCatalog (or if it's absent entirely) -- never hardcodes a
-- class roster here.
function Achievements:GetClassTokens()
    local seen, tokens = {}, {}
    for _, achievement in ipairs(self.catalog) do
        if achievement.category == "CLASSES" and achievement.classToken and not seen[achievement.classToken] then
            seen[achievement.classToken] = true
            tokens[#tokens + 1] = achievement.classToken
        end
    end
    table.sort(tokens)
    return tokens
end

-- Pure rule: entering CLASSES from any other category resets the class
-- filter to "MY_CLASS"; staying within CLASSES (or changing to any other
-- category) preserves whatever was already selected.
function Achievements:ResolveClassFilterOnCategoryChange(previousCategory, newCategory, currentClassFilter)
    if newCategory == "CLASSES" and previousCategory ~= "CLASSES" then return "MY_CLASS" end
    return currentClassFilter or "MY_CLASS"
end

-- The single combined-filter predicate. `state` is a plain table:
--   { search = "", category = "ALL", classFilter = "MY_CLASS", status = "ALL", enabledOnly = false }
-- `save` is the achievements SavedVariables root (self:Ensure()'s result),
-- computed once by the caller and passed in rather than re-fetched per
-- achievement. `playerClassToken` is the caller's already-resolved
-- GetPlayerClassToken() value.
function Achievements:MatchesFilter(achievement, save, state, playerClassToken)
    if not achievement then return false end
    state = state or {}
    local category = state.category or "ALL"

    local categoryMatch = category == "ALL" or achievement.category == category
    if categoryMatch and category == "CLASSES" then
        local classFilter = state.classFilter or "MY_CLASS"
        if classFilter == "MY_CLASS" then
            categoryMatch = achievement.classToken == (playerClassToken or "")
        elseif classFilter ~= "ALL_CLASSES" then
            categoryMatch = achievement.classToken == classFilter
        end
    end
    if not categoryMatch then return false end

    local missingAddon = achievementMissingAddon(achievement)
    if state.enabledOnly and not (isCategoryEnabled(achievement.category) and not missingAddon) then
        return false
    end

    local complete = save and save.unlocked and save.unlocked[achievement.key] ~= nil
    local status = state.status or "ALL"
    if status == "UNLOCKED" and not complete then return false end
    if status == "LOCKED" and complete then return false end

    local filterText = lower(tostring(state.search or ""))
    if filterText ~= "" then
        local haystack = lower(table.concat({ achievement.title, achievement.description, self.categoryNames[achievement.category] or achievement.category }, " "))
        if not string.find(haystack, filterText, 1, true) then return false end
    end
    return true
end

-- Generic forward(+1)/backward(-1) cycle through a value list; shared by
-- the category/class/status controls in both BuildWindow and
-- BuildDrawerPanel so their click behaviour can't drift apart either.
local function cycleValue(list, current, direction)
    if #list == 0 then return current end
    local index = 1
    for i, value in ipairs(list) do
        if value == current then index = i; break end
    end
    index = ((index - 1 + direction) % #list) + 1
    return list[index]
end

local function categoryCycleOrder()
    local order = { "ALL" }
    for _, cat in ipairs(Achievements.categoryOrder) do order[#order + 1] = cat end
    return order
end

local function classCycleOrder()
    local order = { "MY_CLASS", "ALL_CLASSES" }
    for _, token in ipairs(Achievements:GetClassTokens()) do order[#order + 1] = token end
    return order
end

local function categoryLabel(key)
    if key == "ALL" then return "CATEGORY: ALL" end
    return "CATEGORY: " .. upper(Achievements.categoryNames[key] or key)
end

local function classDisplayName(token)
    token = tostring(token or "")
    if token == "" then return "?" end
    return token:sub(1, 1) .. token:sub(2):lower()
end

local function classLabel(playerClassToken, classFilter)
    if classFilter == "ALL_CLASSES" then return "CLASS: ALL CLASSES" end
    if classFilter == "MY_CLASS" or classFilter == nil then
        if playerClassToken and playerClassToken ~= "" then
            return "CLASS: MY CLASS (" .. classDisplayName(playerClassToken) .. ")"
        end
        return "CLASS: MY CLASS"
    end
    return "CLASS: " .. classDisplayName(classFilter)
end

local function statusLabel(status)
    if status == "UNLOCKED" then return "STATUS: UNLOCKED" end
    if status == "LOCKED" then return "STATUS: LOCKED" end
    return "STATUS: ALL"
end

-- Drawer-panel row height/step: title/detail/progress/reward each get their
-- own full-width line (bug fix -- the old design overlaid progress/reward in
-- a reserved top/bottom-right corner shared with title/detail, which could
-- run past the row's edge for longer strings). Shared by the row-creation
-- loop (BuildDrawerPanel), the row-positioning loop (RefreshDrawerPanel) and
-- the pre-refresh height estimate (GetPanelHeight) so they can't drift apart.
local DRAWER_ROW_HEIGHT = 64
local DRAWER_ROW_STEP   = 70

-- Pixel-exact height of the drawer panel's chrome (hero + search + the
-- three filter rows, one of which -- the class row -- only exists when
-- browsing Class Mastery) above where the achievement rows begin. Shared by
-- GetPanelHeight (pre-refresh estimate) and RefreshDrawerPanel (authoritative
-- final height) so they can't disagree about how tall the chrome is.
local function drawerBaseOffset(classShown)
    local offset = 72 + 7 + 30 + 6 + 24 -- hero + gap + search + gap + category row
    if classShown then offset = offset + 4 + 24 end -- class row
    offset = offset + 4 + 24 -- status row
    offset = offset + 4 + 24 -- enabled-modules toggle row
    offset = offset + 8 -- gap before the first achievement row
    return offset
end

local function now()
    if type(_G.GetServerTime) == "function" then return _G.GetServerTime() end
    if type(_G.time) == "function" then return _G.time() end
    if type(_G.GetTime) == "function" then return floor(_G.GetTime()) end
    return 0
end

local function formatNumber(value)
    local text = tostring(floor(max(0, tonumber(value) or 0)))
    local grouped = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    if grouped:sub(1, 1) == "," then grouped = grouped:sub(2) end
    return grouped
end

local function rewardFor(index, weight)
    index = max(1, tonumber(index) or 1)
    weight = max(1, tonumber(weight) or 1)
    local coins = 4 + (index * 4 * weight)
    local xp = 4 + (index * 3 * weight)
    if index >= 6 then
        coins = coins + ((index - 5) * 8 * weight)
        xp = xp + ((index - 5) * 6 * weight)
    end
    return floor(coins), floor(xp)
end

function Achievements:Add(category, stat, goal, title, description, index, weight, stableKey, scope)
    local coins, xp = rewardFor(index, weight)
    local legacyKey = upper(category .. "_" .. stat .. "_" .. tostring(goal))
    local key = stableKey or legacyKey
    local achievement = {
        key = key,
        legacyKey = (key ~= legacyKey) and legacyKey or nil,
        category = category,
        stat = stat,
        goal = goal,
        title = title,
        description = description,
        coins = coins,
        xp = xp,
        tier = index,
        scope = scope or "ACCOUNT_AGGREGATE",
    }
    self.catalog[#self.catalog + 1] = achievement
    self.byKey[key] = achievement
    if achievement.legacyKey then self.byKey[achievement.legacyKey] = achievement end
end

local function addSeries(self, category, stat, goals, titles, description, weight, stableKeys, scope)
    for index, goal in ipairs(goals) do
        local title = titles[index] or ((self.categoryNames[category] or category) .. " " .. tostring(index))
        self:Add(category, stat, goal, title, description(goal, index), index, weight, stableKeys and stableKeys[index], scope)
    end
end

-- Returns the current value of `stat` for the given scope.
-- CHARACTER: reads per-character combat table from CombatTracker (WOW_* stats)
--   or falls through to account class stats for CLASS| stats.
-- ACCOUNT_AGGREGATE (default): existing behaviour via GetStat().
function Achievements:GetStatForScope(stat, scope)
    if scope == "CHARACTER" then
        local s = tostring(stat or "")
        -- CLASS| stats are stored per-class (not per-character) — use account class tracking.
        if s:sub(1, 6) == "CLASS|" then return self:GetStat(stat) end
        -- WOW_* combat stats: read from per-character table if available.
        local ct = COL.CombatTracker
        if ct then
            local charStats = ct:GetCharStats()
            if charStats and tonumber(charStats[s]) then
                return floor(max(0, tonumber(charStats[s]) or 0))
            end
        end
        return 0
    end
    return self:GetStat(stat)
end

function Achievements:BuildCatalog()
    if #self.catalog > 0 then return end

    addSeries(self, "EXPLORATION", "STEPS",
        { 1000, 2000, 3000, 4000, 5000, 6000, 7000, 8000, 9000, 10000, 25000, 50000, 100000, 250000, 500000, 1000000 },
        { "First Thousand", "Road Tested", "Three Thousand Strong", "Four Thousand Footfalls", "Trail Seeker", "Six Thousand Strides", "Seven Thousand Steps", "Eight Thousand and Onward", "Nine Thousand Wanderings", "Ten Thousand Steps", "Azeroth Rambler", "Long-Haul Adventurer", "World Walker", "Continental Trekker", "Half-Million Hero", "One Million Steps" },
        function(goal) return "Travel " .. formatNumber(goal) .. " estimated steps on foot or mount." end, 1,
        { "ACH_WOW_STEPS_001", "ACH_WOW_STEPS_002", "ACH_WOW_STEPS_3000", "ACH_WOW_STEPS_4000", "ACH_WOW_STEPS_003",
          "ACH_WOW_STEPS_6000", "ACH_WOW_STEPS_7000", "ACH_WOW_STEPS_8000", "ACH_WOW_STEPS_9000", "ACH_WOW_STEPS_004",
          "ACH_WOW_STEPS_005", "ACH_WOW_STEPS_006", "ACH_WOW_STEPS_007", "ACH_WOW_STEPS_008", "ACH_WOW_STEPS_009", "ACH_WOW_STEPS_010" })

    addSeries(self, "EXPLORATION", "ZONES",
        { 1, 5, 10, 25, 50, 75, 100 },
        { "New Horizon", "Local Explorer", "Border Crosser", "Map Maker", "World Traveller", "Azeroth Cartographer", "Every Road Leads Somewhere" },
        function(goal) return "Discover " .. formatNumber(goal) .. " different zones." end, 1,
        { "ACH_WOW_ZONES_001", "ACH_WOW_ZONES_002", "ACH_WOW_ZONES_003", "ACH_WOW_ZONES_004",
          "ACH_WOW_ZONES_005", "ACH_WOW_ZONES_006", "ACH_WOW_ZONES_007" })

    addSeries(self, "EXPLORATION", "FLIGHTS",
        { 1, 5, 10, 25, 50, 100, 250 },
        { "First Flight", "Frequent Flier", "Wind Rider", "Flight Master Regular", "Aerial Commuter", "Sky Route Veteran", "Master of the Airways" },
        function(goal) return "Complete " .. formatNumber(goal) .. " flight-path journeys." end, 1,
        { "ACH_WOW_FLIGHTS_001", "ACH_WOW_FLIGHTS_002", "ACH_WOW_FLIGHTS_003", "ACH_WOW_FLIGHTS_004",
          "ACH_WOW_FLIGHTS_005", "ACH_WOW_FLIGHTS_006", "ACH_WOW_FLIGHTS_007" })

    addSeries(self, "COMBAT", "KILLS",
        { 10, 25, 50, 100, 250, 500, 1000, 2500, 5000, 10000 },
        { "First Hunt", "Threat Cleaner", "Field Fighter", "Centurion", "Mob Breaker", "Battle Hardened", "Azeroth Defender", "Relentless", "Enemy Reaper", "Ten Thousand Victories" },
        function(goal) return "Defeat " .. formatNumber(goal) .. " creatures." end, 1,
        { "ACH_WOW_KILLS_001", "ACH_WOW_KILLS_002", "ACH_WOW_KILLS_003", "ACH_WOW_KILLS_004", "ACH_WOW_KILLS_005",
          "ACH_WOW_KILLS_006", "ACH_WOW_KILLS_007", "ACH_WOW_KILLS_008", "ACH_WOW_KILLS_009", "ACH_WOW_KILLS_010" })

    addSeries(self, "COMBAT", "DEATHS",
        { 1, 5, 10, 25, 50, 100 },
        { "That Hurt", "Walk It Off", "Spirit Healer Regular", "Hard Lessons", "Too Stubborn to Stay Down", "Immortal in Spirit" },
        function(goal) return "Return from defeat " .. formatNumber(goal) .. " times." end, 1,
        { "ACH_WOW_DEATHS_001", "ACH_WOW_DEATHS_002", "ACH_WOW_DEATHS_003",
          "ACH_WOW_DEATHS_004", "ACH_WOW_DEATHS_005", "ACH_WOW_DEATHS_006" })

    -- Combat stats — tracked by CombatTracker.lua from COMBAT_LOG_EVENT_UNFILTERED.
    -- GetStat() fallback (save.stats[stat]) reads these without explicit handlers.
    addSeries(self, "COMBAT", "WOW_DAMAGE_DEALT",
        { 10000, 50000, 100000, 500000, 1000000, 5000000, 10000000 },
        { "First Blood", "Ten Thousand Damage", "One Hundred Thousand", "Half a Million", "One Million Damage", "Five Million Damage", "Ten Million Damage" },
        function(goal) return "Deal " .. formatNumber(goal) .. " total damage to enemies." end, 2,
        { "ACH_WOW_DAMAGE_DEALT_001", "ACH_WOW_DAMAGE_DEALT_002", "ACH_WOW_DAMAGE_DEALT_003",
          "ACH_WOW_DAMAGE_DEALT_004", "ACH_WOW_DAMAGE_DEALT_005", "ACH_WOW_DAMAGE_DEALT_006",
          "ACH_WOW_DAMAGE_DEALT_007" })

    addSeries(self, "COMBAT", "WOW_DAMAGE_TAKEN",
        { 5000, 25000, 100000, 500000, 1000000 },
        { "First Scar", "Tested in Battle", "Iron Will", "Unyielding Defender", "Indestructible" },
        function(goal) return "Survive taking " .. formatNumber(goal) .. " total damage." end, 1,
        { "ACH_WOW_DAMAGE_TAKEN_001", "ACH_WOW_DAMAGE_TAKEN_002", "ACH_WOW_DAMAGE_TAKEN_003",
          "ACH_WOW_DAMAGE_TAKEN_004", "ACH_WOW_DAMAGE_TAKEN_005" })

    addSeries(self, "COMBAT", "WOW_BEST_HIT",
        { 500, 1000, 2500, 5000, 10000 },
        { "Heavy Hitter", "Four-Digit Strike", "Master Strike", "Five Thousand Power", "Ten Thousand Fury" },
        function(goal) return "Land a single hit dealing " .. formatNumber(goal) .. " or more damage." end, 3,
        { "ACH_WOW_BEST_HIT_001", "ACH_WOW_BEST_HIT_002", "ACH_WOW_BEST_HIT_003",
          "ACH_WOW_BEST_HIT_004", "ACH_WOW_BEST_HIT_005" })

    addSeries(self, "COMBAT", "WOW_HEALING",
        { 5000, 25000, 100000, 500000, 1000000 },
        { "First Aid", "Field Medic", "Hundred Thousand Healed", "Dedicated Healer", "One Million Healed" },
        function(goal) return "Restore " .. formatNumber(goal) .. " total health to allies." end, 2,
        { "ACH_WOW_HEALING_001", "ACH_WOW_HEALING_002", "ACH_WOW_HEALING_003",
          "ACH_WOW_HEALING_004", "ACH_WOW_HEALING_005" })

    addSeries(self, "COMBAT", "WOW_BEST_HEAL",
        { 500, 1000, 2500, 5000, 10000 },
        { "Tender Touch", "Thousand Heal", "Powerful Mend", "Major Restoration", "Divine Intervention" },
        function(goal) return "Cast a single heal restoring " .. formatNumber(goal) .. " or more health." end, 3,
        { "ACH_WOW_BEST_HEAL_001", "ACH_WOW_BEST_HEAL_002", "ACH_WOW_BEST_HEAL_003",
          "ACH_WOW_BEST_HEAL_004", "ACH_WOW_BEST_HEAL_005" })

    addSeries(self, "COMBAT", "WOW_CRITS",
        { 10, 50, 100, 500, 1000, 5000 },
        { "Sharp Eye", "Fifty Crits", "Critical Century", "Crit Veteran", "Critical Master", "Critical Legend" },
        function(goal) return "Land " .. formatNumber(goal) .. " critical strikes." end, 2,
        { "ACH_WOW_CRITS_001", "ACH_WOW_CRITS_002", "ACH_WOW_CRITS_003",
          "ACH_WOW_CRITS_004", "ACH_WOW_CRITS_005", "ACH_WOW_CRITS_006" })

    addSeries(self, "COMBAT", "WOW_CRIT_HEALS",
        { 10, 50, 100, 500, 1000 },
        { "Inspired Mend", "Fifty Crit Heals", "Critical Restoration", "Critical Healer", "Legendary Healer" },
        function(goal) return "Land " .. formatNumber(goal) .. " critical heals." end, 2,
        { "ACH_WOW_CRIT_HEALS_001", "ACH_WOW_CRIT_HEALS_002", "ACH_WOW_CRIT_HEALS_003",
          "ACH_WOW_CRIT_HEALS_004", "ACH_WOW_CRIT_HEALS_005" })

    -- Real WoW dungeon progress is kept separate from the Dungeon Dwellers game.
    addSeries(self, "DUNGEONS", "EXP|WOW_DUNGEON_MOBS|",
        { 10, 25, 50, 100, 250, 500, 1000, 2500, 5000, 10000 },
        { "Dungeon Initiate", "Hallway Cleaner", "Pack Breaker", "Dungeon Centurion", "Elite Sweeper", "Delver Veteran", "Thousand Below", "Deep-Crawl Destroyer", "Dungeon Exterminator", "Ten Thousand in the Dark" },
        function(goal) return "Defeat " .. formatNumber(goal) .. " enemies inside real WoW five-player dungeons." end, 2,
        { "ACH_WOW_DUNGEON_MOBS_001", "ACH_WOW_DUNGEON_MOBS_002", "ACH_WOW_DUNGEON_MOBS_003", "ACH_WOW_DUNGEON_MOBS_004", "ACH_WOW_DUNGEON_MOBS_005",
          "ACH_WOW_DUNGEON_MOBS_006", "ACH_WOW_DUNGEON_MOBS_007", "ACH_WOW_DUNGEON_MOBS_008", "ACH_WOW_DUNGEON_MOBS_009", "ACH_WOW_DUNGEON_MOBS_010" })

    addSeries(self, "DUNGEONS", "EXP|WOW_DUNGEON_BOSSES|",
        { 1, 3, 5, 10, 25, 50, 100, 250, 500 },
        { "Boss Breaker", "Triple Threat", "Guardian Hunter", "Ten Bosses Down", "Dungeon Ruler Hunter", "Dungeon Nemesis", "Century of Bosses", "Legendary Slayer", "Five Hundred Crowns" },
        function(goal) return "Defeat " .. formatNumber(goal) .. " bosses inside real WoW five-player dungeons." end, 2,
        { "ACH_WOW_DUNGEON_BOSSES_001", "ACH_WOW_DUNGEON_BOSSES_002", "ACH_WOW_DUNGEON_BOSSES_003",
          "ACH_WOW_DUNGEON_BOSSES_004", "ACH_WOW_DUNGEON_BOSSES_005", "ACH_WOW_DUNGEON_BOSSES_006",
          "ACH_WOW_DUNGEON_BOSSES_007", "ACH_WOW_DUNGEON_BOSSES_008", "ACH_WOW_DUNGEON_BOSSES_009" })

    addSeries(self, "DUNGEONS", "EXP|UNIQUE_DUNGEON_FINAL_BOSSES|",
        { 1, 3, 5, 8, 10, 12, 15 },
        { "New Name on the List", "Boss Collector", "Five Final Foes", "Known Enemy", "Ten Final Tyrants", "Boss Encyclopaedia", "Every TBC Final Boss" },
        function(goal) return "Defeat " .. formatNumber(goal) .. " different TBC five-player final bosses." end, 2,
        { "ACH_WOW_UNIQUE_FINAL_BOSSES_001", "ACH_WOW_UNIQUE_FINAL_BOSSES_002", "ACH_WOW_UNIQUE_FINAL_BOSSES_003",
          "ACH_WOW_UNIQUE_FINAL_BOSSES_004", "ACH_WOW_UNIQUE_FINAL_BOSSES_005", "ACH_WOW_UNIQUE_FINAL_BOSSES_006",
          "ACH_WOW_UNIQUE_FINAL_BOSSES_007" })

    addSeries(self, "DUNGEONS", "EXP|WOW_DUNGEON_COMPLETES_TOTAL|",
        { 1, 5, 10, 25, 50, 100, 250 },
        { "Into the Instance", "Dungeon Tourist", "Ten Expeditions", "Reliable Delver", "Dungeon Regular", "Instance Veteran", "Endless Expedition" },
        function(goal) return "Complete " .. formatNumber(goal) .. " real WoW five-player dungeon runs." end, 2,
        { "ACH_WOW_DUNGEON_CLEARS_001", "ACH_WOW_DUNGEON_CLEARS_002", "ACH_WOW_DUNGEON_CLEARS_003",
          "ACH_WOW_DUNGEON_CLEARS_004", "ACH_WOW_DUNGEON_CLEARS_005", "ACH_WOW_DUNGEON_CLEARS_006",
          "ACH_WOW_DUNGEON_CLEARS_007" })

    addSeries(self, "PROFESSIONS", "PROFESSION_RANK",
        { 75, 150, 225, 300 },
        { "Apprentice Hands", "Journeyman Hands", "Expert Hands", "Master Artisan" },
        function(goal) return "Reach skill " .. formatNumber(goal) .. " in any profession." end, 2,
        { "ACH_WOW_PROF_RANK_001", "ACH_WOW_PROF_RANK_002", "ACH_WOW_PROF_RANK_003", "ACH_WOW_PROF_RANK_004" })

    addSeries(self, "PROFESSIONS", "PROFESSION_COUNT",
        { 1, 2, 4, 6 },
        { "Learn a Trade", "Working Pair", "Many Talents", "Renaissance Crafter" },
        function(goal) return "Learn or advance " .. formatNumber(goal) .. " different professions." end, 1,
        { "ACH_WOW_PROF_COUNT_001", "ACH_WOW_PROF_COUNT_002", "ACH_WOW_PROF_COUNT_003", "ACH_WOW_PROF_COUNT_004" })

    addSeries(self, "PROFESSIONS", "MASTER_PROFESSIONS",
        { 1, 2, 4, 6 },
        { "One Mastery", "Dual Mastery", "Master of Four", "Trade Grandmaster" },
        function(goal) return "Reach 300 skill in " .. formatNumber(goal) .. " professions." end, 2,
        { "ACH_WOW_PROF_MASTER_001", "ACH_WOW_PROF_MASTER_002", "ACH_WOW_PROF_MASTER_003", "ACH_WOW_PROF_MASTER_004" })
    -- Rework Phase 5: the GAMES category (GAME_PLAYS/GAME_WINS/GAME_LEVELS/
    -- UNLOCKS, 23 achievements) moved to CreshGames/GamesAchievements.lua.
    -- CreshCollect now reports only World of Warcraft achievements.
end

local function progressionRoot()
    if not CreshCollectDB then return nil end
    CreshCollectDB.achievements = type(CreshCollectDB.achievements) == "table" and CreshCollectDB.achievements or {}
    return CreshCollectDB.achievements
end

function Achievements:Ensure()
    self:BuildCatalog()
    local save = progressionRoot()
    if not save then return nil end
    save.unlocked = type(save.unlocked) == "table" and save.unlocked or {}
    save.stats = type(save.stats) == "table" and save.stats or {}
    save.uniqueBosses = type(save.uniqueBosses) == "table" and save.uniqueBosses or {}
    save.professionRanks = type(save.professionRanks) == "table" and save.professionRanks or {}
    save.visitedZones = type(save.visitedZones) == "table" and save.visitedZones or {}
    save.totalCoins = floor(max(0, tonumber(save.totalCoins) or 0))
    save.totalPassXP = floor(max(0, tonumber(save.totalPassXP) or 0))
    save.stats.deaths = floor(max(0, tonumber(save.stats.deaths) or 0))
    save.stats.flights = floor(max(0, tonumber(save.stats.flights) or 0))
    save.stats.dungeonMobs = floor(max(0, tonumber(save.stats.dungeonMobs) or 0))
    save.stats.bosses = floor(max(0, tonumber(save.stats.bosses) or 0))
    save.stats.dungeons = floor(max(0, tonumber(save.stats.dungeons) or 0))
    -- Combat stats tracked by CombatTracker.lua (COMBAT_LOG_EVENT_UNFILTERED).
    -- Keys match achievement stat names so GetStat()'s fallback reads them directly.
    local s = save.stats
    if not tonumber(s.WOW_DAMAGE_DEALT) then s.WOW_DAMAGE_DEALT = 0 end
    if not tonumber(s.WOW_DAMAGE_TAKEN) then s.WOW_DAMAGE_TAKEN = 0 end
    if not tonumber(s.WOW_BEST_HIT)     then s.WOW_BEST_HIT     = 0 end
    if not tonumber(s.WOW_HEALING)      then s.WOW_HEALING       = 0 end
    if not tonumber(s.WOW_BEST_HEAL)    then s.WOW_BEST_HEAL     = 0 end
    if not tonumber(s.WOW_CRITS)        then s.WOW_CRITS         = 0 end
    if not tonumber(s.WOW_CRIT_HEALS)   then s.WOW_CRIT_HEALS    = 0 end
    return save
end

local function countMap(tbl)
    local count = 0
    for _ in pairs(tbl or {}) do count = count + 1 end
    return count
end

function Achievements:GetStat(stat)
    local save = self:Ensure()
    if not save then return 0 end
    local exploration = CreshCollectDB.gameProgression and CreshCollectDB.gameProgression.exploration or {}
    if stat == "STEPS" then return floor(max(0, tonumber(exploration.totalSteps) or 0)) end
    if stat == "ZONES" then
        return max(floor(max(0, tonumber(exploration.newZones) or 0)), countMap(save.visitedZones), countMap(exploration.visitedZones))
    end
    if stat == "FLIGHTS" then return save.stats.flights or 0 end
    if stat == "KILLS" then return floor(max(0, tonumber(exploration.totalKills) or 0)) end
    if stat == "DEATHS" then return save.stats.deaths or 0 end
    -- Legacy mixed counters remain readable for old saves, but no current
    -- achievement uses them after the v73 dungeon/game split.
    if stat == "DUNGEON_MOBS" then return save.stats.dungeonMobs or 0 end
    if stat == "BOSSES" then return save.stats.bosses or 0 end
    if stat == "UNIQUE_BOSSES" then return countMap(save.uniqueBosses) end
    if stat == "DUNGEONS" then return max(save.stats.dungeons or 0, floor(max(0, tonumber(exploration.dungeonClears) or 0))) end
    if stat == "PROFESSION_RANK" then
        local best = 0
        for _, rank in pairs(save.professionRanks or {}) do best = max(best, tonumber(rank) or 0) end
        return floor(best)
    end
    if stat == "PROFESSION_COUNT" then
        local count = 0
        for _, rank in pairs(save.professionRanks or {}) do if (tonumber(rank) or 0) > 0 then count = count + 1 end end
        return count
    end
    if stat == "MASTER_PROFESSIONS" then
        local count = 0
        for _, rank in pairs(save.professionRanks or {}) do if (tonumber(rank) or 0) >= 300 then count = count + 1 end end
        return count
    end
    return floor(max(0, tonumber(save.stats[stat]) or 0))
end

function Achievements:GetCounts(category)
    local save = self:Ensure()
    local unlocked, total = 0, 0
    for _, achievement in ipairs(self.catalog) do
        if not category or achievement.category == category then
            total = total + 1
            if save and save.unlocked[achievement.key] then unlocked = unlocked + 1 end
        end
    end
    return unlocked, total
end

function Achievements:GetPoints()
    local save = self:Ensure()
    local points = 0
    for _, achievement in ipairs(self.catalog) do
        if save and save.unlocked[achievement.key] then points = points + (achievement.tier * 5) end
    end
    return points
end

function Achievements:IsUnlocked(key)
    local save = self:Ensure()
    return save and save.unlocked[tostring(key)] ~= nil or false
end

function Achievements:Unlock(achievement, silent)
    local save = self:Ensure()
    if not save or not achievement or save.unlocked[achievement.key] then return false end
    local R = COL.ProgressRouter
    local charKey, charClass
    if CC.currentProfile then
        charKey   = CC.currentProfile.key
        charClass = CC.currentProfile.class
    end
    save.unlocked[achievement.key] = {
        at           = now(),
        value        = self:GetStatForScope(achievement.stat, achievement.scope),
        -- F1: reward routing metadata
        sourceSystem = R and R.SYSTEMS.WOW_ACHIEVEMENTS or "WOW_ACHIEVEMENTS",
        sourceId     = achievement.key,
        targetGame   = R and R.GAMES.GLOBAL or "GLOBAL",
        -- Part 4: account-wide completion metadata
        scope        = achievement.scope or "ACCOUNT_AGGREGATE",
        completedBy  = charKey,
        completedByClass = charClass,
    }
    save.totalCoins = save.totalCoins + achievement.coins
    save.totalPassXP = save.totalPassXP + achievement.xp
    -- Rework Phase 3: notify listeners (e.g. CreshGames' Arcade Pass, for the
    -- still-CreshCollect-owned GAMES category) that an achievement unlocked.
    -- Fires regardless of `silent` -- that flag only defers CreshCollect's
    -- own coin/XP payout timing, not whether the achievement happened.
    local suite = _G.CreshSuite
    if suite and suite.Publish then
        suite:Publish("CRESHCOLLECT_ACHIEVEMENT_UNLOCKED", { source = "CRESHCOLLECT", key = achievement.key, category = achievement.category })
    end
    if silent and self.silentRewardBatch then
        self.silentRewardBatch.coins = self.silentRewardBatch.coins + achievement.coins
        self.silentRewardBatch.xp = self.silentRewardBatch.xp + achievement.xp
    elseif COL.BattlePass then
        if COL.BattlePass.AddCoins then COL.BattlePass:AddCoins(achievement.coins, "ACHIEVEMENT") end
        if COL.BattlePass.AddPassXP then COL.BattlePass:AddPassXP(achievement.xp, "ACHIEVEMENT", true) end
    end
    if not silent then
        COL:ShowAchievementToast(
            "Achievement unlocked: " .. achievement.title,
            "+" .. tostring(achievement.coins) .. " Cresh Coins · +" .. tostring(achievement.xp) .. " Chronicle XP",
            "ACHIEVEMENT:" .. achievement.key
        )
    end
    if not silent and CC.GameAudio and CC.GameAudio.PlayEffect then CC.GameAudio:PlayEffect("LEVEL") end
    return true
end

function Achievements:EvaluateAll(silent)
    local save = self:Ensure()
    if not save or self.evaluating then return 0 end
    self.evaluating = true
    if silent then self.silentRewardBatch = { coins = 0, xp = 0 } end
    local unlocked = 0
    local values = {}
    for _, achievement in ipairs(self.catalog) do
        local available = self:IsAvailable(achievement)
        local valueKey = tostring(achievement.scope or "ACCOUNT_AGGREGATE") .. "\031" .. tostring(achievement.stat)
        local value = values[valueKey]
        if value == nil and available then
            value = self:GetStatForScope(achievement.stat, achievement.scope)
            values[valueKey] = value
        end
        if available and not save.unlocked[achievement.key] and value >= achievement.goal then
            if self:Unlock(achievement, silent) then unlocked = unlocked + 1 end
        end
    end
    local batch = self.silentRewardBatch
    self.silentRewardBatch = nil
    self.evaluating = false
    if silent and batch and COL.BattlePass then
        if batch.coins > 0 and COL.BattlePass.AddCoins then COL.BattlePass:AddCoins(batch.coins, "ACHIEVEMENT") end
        if batch.xp > 0 and COL.BattlePass.AddPassXP then COL.BattlePass:AddPassXP(batch.xp, "ACHIEVEMENT", true) end
    end
    if unlocked > 0 and not silent then
        if CC.UI then
            if CC.UI.RefreshConsoleEconomy then CC.UI:RefreshConsoleEconomy() end
            if CC.UI.RefreshGameDrawer then CC.UI:RefreshGameDrawer(true) end
        end
        -- Same single centralized refresh point, extended to also cover the
        -- standalone achievements window (see BuildWindow/RefreshWindow
        -- below) and the Progress Overview's achievements card, rather than
        -- adding a second, parallel event hook.
        self:RefreshWindow()
        if COL.ProgressOverview and COL.ProgressOverview.RefreshWindow then COL.ProgressOverview:RefreshWindow() end
    end
    return unlocked
end

-- Evaluate only achievements driven by one changed stat.  Movement uses this
-- path so adding a handful of steps never scans and recomputes the full 500+
-- achievement catalogue.
function Achievements:EvaluateStat(stat, silent)
    stat = tostring(stat or "")
    if stat == "" then return 0 end
    local save = self:Ensure()
    if not save or self.evaluating then return 0 end
    self.evaluating = true
    if silent then self.silentRewardBatch = { coins = 0, xp = 0 } end
    local unlocked, values = 0, {}
    for _, achievement in ipairs(self.catalog) do
        if achievement.stat == stat and not save.unlocked[achievement.key] and self:IsAvailable(achievement) then
            local scope = tostring(achievement.scope or "ACCOUNT_AGGREGATE")
            local value = values[scope]
            if value == nil then
                value = self:GetStatForScope(stat, achievement.scope)
                values[scope] = value
            end
            if value >= achievement.goal and self:Unlock(achievement, silent) then unlocked = unlocked + 1 end
        end
    end
    local batch = self.silentRewardBatch
    self.silentRewardBatch = nil
    self.evaluating = false
    if silent and batch and COL.BattlePass then
        if batch.coins > 0 and COL.BattlePass.AddCoins then COL.BattlePass:AddCoins(batch.coins, "ACHIEVEMENT") end
        if batch.xp > 0 and COL.BattlePass.AddPassXP then COL.BattlePass:AddPassXP(batch.xp, "ACHIEVEMENT", true) end
    end
    if unlocked > 0 and not silent then
        self:RefreshWindow()
        if COL.ProgressOverview and COL.ProgressOverview.RefreshWindow then COL.ProgressOverview:RefreshWindow() end
    end
    return unlocked
end

function Achievements:RecordDeath()
    local save = self:Ensure(); if not save then return end
    save.stats.deaths = (save.stats.deaths or 0) + 1
    self:EvaluateAll(false)
end

function Achievements:RecordFlight()
    local save = self:Ensure(); if not save then return end
    save.stats.flights = (save.stats.flights or 0) + 1
    self:EvaluateAll(false)
end

function Achievements:RecordZone(mapID, zoneName)
    local save = self:Ensure(); if not save then return end
    local key = tostring(mapID or "") .. ":" .. lower(tostring(zoneName or "Unknown Zone"))
    if key == ":" or save.visitedZones[key] then return end
    save.visitedZones[key] = { name = tostring(zoneName or "Unknown Zone"), at = now() }
    self:EvaluateAll(false)
end

function Achievements:RecordDungeonEntry(name)
    local save = self:Ensure(); if not save then return end
    save.stats.dungeons = (save.stats.dungeons or 0) + 1
    save.lastDungeon = tostring(name or "Dungeon")
    self:EvaluateAll(false)
end

function Achievements:CaptureBossUnits()
    self.bossGUIDs = self.bossGUIDs or {}
    for index = 1, 8 do
        local unit = "boss" .. tostring(index)
        if type(_G.UnitGUID) == "function" then
            local guid = _G.UnitGUID(unit)
            if guid then
                local name = type(_G.UnitName) == "function" and _G.UnitName(unit) or ("Boss " .. index)
                self.bossGUIDs[guid] = tostring(name or ("Boss " .. index))
            end
        end
    end
end

function Achievements:RecordBoss(key, name)
    local save = self:Ensure(); if not save then return end
    local displayName = tostring(name or key or "")
    local normalizedName = lower(displayName):gsub("^%s+", ""):gsub("%s+$", "")
    if normalizedName == "" then return end
    local stamp = now()
    self.recentBosses = self.recentBosses or {}
    -- PARTY_KILL, ENCOUNTER_END and BOSS_KILL can all report the same kill.
    -- Deduplicate by the visible boss name so one kill cannot pay three times.
    if stamp - (self.recentBosses[normalizedName] or 0) < 8 then return end
    self.recentBosses[normalizedName] = stamp
    save.stats.bosses = (save.stats.bosses or 0) + 1
    local uniqueKey = "WOW:" .. normalizedName
    save.uniqueBosses[uniqueKey] = save.uniqueBosses[uniqueKey] or { name = displayName, first = stamp }
    if COL.GameProgression and COL.GameProgression.AwardExploration then
        COL.GameProgression:AwardExploration(5, 5, "Boss Defeated", displayName, true)
    end
    self:EvaluateAll(false)
end

function Achievements:RecordWorldKill(destGUID, destName)
    local inInstance, instanceType = false, nil
    if type(_G.IsInInstance) == "function" then inInstance, instanceType = _G.IsInInstance() end
    local isDungeon = inInstance and (instanceType == "party" or instanceType == "raid")
    if not isDungeon then return false end
    self:CaptureBossUnits()
    local isBoss = self.bossGUIDs and self.bossGUIDs[destGUID] ~= nil
    if isBoss then
        self:RecordBoss(destGUID, destName or self.bossGUIDs[destGUID])
    else
        local save = self:Ensure(); if not save then return false end
        save.stats.dungeonMobs = (save.stats.dungeonMobs or 0) + 1
        self:EvaluateAll(false)
    end
    return isBoss
end

function Achievements:ScanProfessions(silent)
    local save = self:Ensure(); if not save then return end
    local changed = false
    local function record(name, rank)
        name, rank = tostring(name or ""), floor(max(0, tonumber(rank) or 0))
        if name == "" or rank <= 0 then return end
        local old = tonumber(save.professionRanks[name]) or 0
        if rank > old then save.professionRanks[name] = rank; changed = true end
    end

    if type(_G.GetProfessions) == "function" and type(_G.GetProfessionInfo) == "function" then
        local professionIndexes = { _G.GetProfessions() }
        -- TBC leaves empty slots between primary and secondary professions, so
        -- iterate fixed positions rather than ipairs (which stops at the first nil).
        for slot = 1, 6 do
            local professionIndex = professionIndexes[slot]
            if professionIndex then
                local ok, name, _, rank = pcall(_G.GetProfessionInfo, professionIndex)
                if ok then record(name, rank) end
            end
        end
    elseif type(_G.GetNumSkillLines) == "function" and type(_G.GetSkillLineInfo) == "function" then
        local known = {
            ["Alchemy"] = true, ["Blacksmithing"] = true, ["Enchanting"] = true, ["Engineering"] = true,
            ["Herbalism"] = true, ["Jewelcrafting"] = true, ["Leatherworking"] = true, ["Mining"] = true,
            ["Skinning"] = true, ["Tailoring"] = true, ["Cooking"] = true, ["Fishing"] = true,
            ["First Aid"] = true,
        }
        for index = 1, _G.GetNumSkillLines() do
            local name, isHeader, _, rank = _G.GetSkillLineInfo(index)
            if not isHeader and known[tostring(name or "")] then record(name, rank) end
        end
    end
    if changed then self:EvaluateAll(silent == true) end
end

function Achievements:ProcessTaxiState()
    local onTaxi = type(_G.UnitOnTaxi) == "function" and _G.UnitOnTaxi("player") or false
    if self.wasOnTaxi and not onTaxi then self:RecordFlight() end
    self.wasOnTaxi = onTaxi and true or false
end

function Achievements:ProcessInstanceState(initial)
    local inInstance, instanceType = false, nil
    if type(_G.IsInInstance) == "function" then inInstance, instanceType = _G.IsInInstance() end
    local inDungeon = inInstance and (instanceType == "party" or instanceType == "raid")
    if inDungeon and not self.wasInDungeon and not initial then
        local name = type(_G.GetInstanceInfo) == "function" and _G.GetInstanceInfo() or "Dungeon"
        self:RecordDungeonEntry(name)
    end
    self.wasInDungeon = inDungeon and true or false
end

function Achievements:GetPanelHeight(filter, category, status, classFilter)
    local state = { search = filter, category = category, status = status, classFilter = classFilter, enabledOnly = false }
    local save = self:Ensure()
    local playerClassToken = self:GetPlayerClassToken()
    local count = 0
    for _, achievement in ipairs(self.catalog) do
        if self:MatchesFilter(achievement, save, state, playerClassToken) then count = count + 1 end
    end
    return drawerBaseOffset(category == "CLASSES") + (count * DRAWER_ROW_STEP)
end

function Achievements:BuildDrawerPanel(drawer, helpers)
    if drawer.achievementPanel then return drawer.achievementPanel end
    local createButton, createFont = helpers.createButton, helpers.createFont
    local applyBackdrop, darken, colors, templateName = helpers.applyBackdrop, helpers.darken, helpers.colors, helpers.templateName
    local panel = CreateFrame("Frame", nil, drawer.content)
    panel:SetPoint("TOPLEFT", drawer.content, "TOPLEFT", 0, 0)
    panel:SetPoint("TOPRIGHT", drawer.content, "TOPRIGHT", 0, 0)
    panel:SetHeight(self:GetPanelHeight())
    panel.searchText = ""
    panel.category = "ALL"
    panel.classFilter = "MY_CLASS"
    panel.status = "ALL"
    drawer.achievementPanel = panel

    panel.hero = CreateFrame("Frame", nil, panel, templateName())
    panel.hero:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
    panel.hero:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, 0)
    panel.hero:SetHeight(72)
    applyBackdrop(panel.hero, colors.panelSoft, colors.quest)
    panel.title = createFont(panel.hero, 14, colors.text, "LEFT")
    panel.title:SetPoint("TOPLEFT", panel.hero, "TOPLEFT", 10, -9)
    panel.title:SetText("ACCOUNT ACHIEVEMENTS")
    panel.summary = createFont(panel.hero, 9, colors.muted, "LEFT")
    panel.summary:SetPoint("TOPLEFT", panel.title, "BOTTOMLEFT", 0, -5)
    panel.summary:SetPoint("RIGHT", panel.hero, "RIGHT", -10, 0)

    panel.searchFrame = CreateFrame("Frame", nil, panel, templateName())
    panel.searchFrame:SetPoint("TOPLEFT", panel.hero, "BOTTOMLEFT", 0, -7)
    panel.searchFrame:SetPoint("TOPRIGHT", panel.hero, "BOTTOMRIGHT", 0, -7)
    panel.searchFrame:SetHeight(30)
    applyBackdrop(panel.searchFrame, colors.panelRaised, colors.border)
    panel.search = CreateFrame("EditBox", nil, panel.searchFrame, templateName())
    panel.search:SetPoint("TOPLEFT", panel.searchFrame, "TOPLEFT", 8, -4)
    panel.search:SetPoint("BOTTOMRIGHT", panel.searchFrame, "BOTTOMRIGHT", -8, 4)
    panel.search:SetAutoFocus(false)
    panel.search:SetFontObject(_G.GameFontNormalSmall or _G.GameFontHighlightSmall)
    panel.search:SetTextInsets(2, 2, 0, 0)
    panel.search:SetMaxLetters(40)
    panel.search:SetScript("OnEscapePressed", function(box) box:ClearFocus() end)
    panel.search:SetScript("OnEnterPressed", function(box) box:ClearFocus() end)
    panel.search:SetScript("OnTextChanged", function(box)
        panel.searchText = tostring(box:GetText() or "")
        Achievements:RefreshDrawerPanel(drawer, helpers, true)
    end)
    panel.searchHint = createFont(panel.searchFrame, 8, colors.muted, "LEFT")
    panel.searchHint:SetPoint("LEFT", panel.searchFrame, "LEFT", 10, 0)
    panel.searchHint:SetText("Search achievements or types...")
    panel.search:SetScript("OnEditFocusGained", function() panel.searchHint:Hide() end)
    panel.search:SetScript("OnEditFocusLost", function(box) panel.searchHint:SetShown((box:GetText() or "") == "") end)

    -- Phase 2: three fixed, always-full-width cycle controls replace the
    -- old per-category button wall (which overhung once there were more
    -- than 5 categories) -- left-click cycles forward, right-click cycles
    -- back, same convention as ProgressHub.lua's settings button.
    panel.enabledOnly = false

    panel.categoryRow = CreateFrame("Frame", nil, panel)
    panel.categoryRow:SetPoint("TOPLEFT", panel.searchFrame, "BOTTOMLEFT", 0, -6)
    panel.categoryRow:SetPoint("TOPRIGHT", panel.searchFrame, "BOTTOMRIGHT", 0, -6)
    panel.categoryRow:SetHeight(24)

    panel.classRow = CreateFrame("Frame", nil, panel)
    panel.classRow:SetPoint("TOPLEFT", panel.categoryRow, "BOTTOMLEFT", 0, -4)
    panel.classRow:SetPoint("TOPRIGHT", panel.categoryRow, "BOTTOMRIGHT", 0, -4)
    panel.classRow:SetHeight(24)

    panel.statusRow = CreateFrame("Frame", nil, panel)
    panel.statusRow:SetHeight(24)

    panel.toggleRow = CreateFrame("Frame", nil, panel)
    panel.toggleRow:SetHeight(24)

    -- Re-anchors statusRow/toggleRow around whichever of categoryRow/
    -- classRow is currently the last visible row, and shows/hides classRow
    -- itself -- called at build time and whenever the category changes.
    local function layoutFilterRows()
        local classShown = panel.category == "CLASSES"
        panel.classRow:SetShown(classShown)
        local statusAnchor = classShown and panel.classRow or panel.categoryRow
        panel.statusRow:ClearAllPoints()
        panel.statusRow:SetPoint("TOPLEFT", statusAnchor, "BOTTOMLEFT", 0, -4)
        panel.statusRow:SetPoint("TOPRIGHT", statusAnchor, "BOTTOMRIGHT", 0, -4)
        panel.toggleRow:ClearAllPoints()
        panel.toggleRow:SetPoint("TOPLEFT", panel.statusRow, "BOTTOMLEFT", 0, -4)
        panel.toggleRow:SetPoint("TOPRIGHT", panel.statusRow, "BOTTOMRIGHT", 0, -4)
    end

    panel.categoryButton = createButton(panel.categoryRow, categoryLabel(panel.category), 200, 24, function(_, mouseButton)
        local previousCategory = panel.category
        panel.category = cycleValue(categoryCycleOrder(), previousCategory, mouseButton == "RightButton" and -1 or 1)
        panel.classFilter = Achievements:ResolveClassFilterOnCategoryChange(previousCategory, panel.category, panel.classFilter)
        layoutFilterRows()
        Achievements:RefreshDrawerPanel(drawer, helpers, true)
    end)
    panel.categoryButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    panel.categoryButton:SetPoint("TOPLEFT", panel.categoryRow, "TOPLEFT", 0, 0)
    panel.categoryButton:SetPoint("BOTTOMRIGHT", panel.categoryRow, "BOTTOMRIGHT", 0, 0)

    panel.classButton = createButton(panel.classRow, classLabel(Achievements:GetPlayerClassToken(), panel.classFilter), 200, 24, function(_, mouseButton)
        panel.classFilter = cycleValue(classCycleOrder(), panel.classFilter, mouseButton == "RightButton" and -1 or 1)
        Achievements:RefreshDrawerPanel(drawer, helpers, true)
    end)
    panel.classButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    panel.classButton:SetPoint("TOPLEFT", panel.classRow, "TOPLEFT", 0, 0)
    panel.classButton:SetPoint("BOTTOMRIGHT", panel.classRow, "BOTTOMRIGHT", 0, 0)

    panel.statusButton = createButton(panel.statusRow, statusLabel(panel.status), 200, 24, function(_, mouseButton)
        panel.status = cycleValue({ "ALL", "UNLOCKED", "LOCKED" }, panel.status, mouseButton == "RightButton" and -1 or 1)
        Achievements:RefreshDrawerPanel(drawer, helpers, true)
    end)
    panel.statusButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    panel.statusButton:SetPoint("TOPLEFT", panel.statusRow, "TOPLEFT", 0, 0)
    panel.statusButton:SetPoint("BOTTOMRIGHT", panel.statusRow, "BOTTOMRIGHT", 0, 0)

    panel.enabledToggle = createButton(panel.toggleRow, "ENABLED MODULES ONLY", 150, 22, function()
        panel.enabledOnly = not panel.enabledOnly
        Achievements:RefreshDrawerPanel(drawer, helpers, true)
    end)
    panel.enabledToggle:SetPoint("RIGHT", panel.toggleRow, "RIGHT", 0, 0)
    panel.enabledToggle:SetScript("OnEnter", function(btn)
        GameTooltip:SetOwner(btn, "ANCHOR_BOTTOM")
        GameTooltip:SetText("Enabled Modules Only", 1, 1, 1)
        GameTooltip:AddLine("Show only achievements for modules you have turned on in Settings > Modules.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    panel.enabledToggle:SetScript("OnLeave", function() GameTooltip:Hide() end)

    layoutFilterRows()

    panel.empty = createFont(panel, 9, colors.muted, "CENTER")
    panel.empty:SetPoint("TOPLEFT", panel.toggleRow, "BOTTOMLEFT", 0, -24)
    panel.empty:SetPoint("TOPRIGHT", panel.toggleRow, "BOTTOMRIGHT", 0, -24)
    panel.empty:SetText("No achievements match your filter.")
    panel.empty:Hide()

    panel.rows = {}
    for index, achievement in ipairs(self.catalog) do
        local row = CreateFrame("Frame", nil, panel, templateName())
        row:SetPoint("TOPLEFT", panel.toggleRow, "BOTTOMLEFT", 0, -8)
        row:SetPoint("TOPRIGHT", panel.toggleRow, "BOTTOMRIGHT", 0, -8)
        row:SetHeight(DRAWER_ROW_HEIGHT)
        applyBackdrop(row, colors.panelSoft, colors.border)
        row.title = createFont(row, 10, colors.text, "LEFT")
        row.title:SetPoint("TOPLEFT", row, "TOPLEFT", 9, -7)
        row.title:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        row.detail = createFont(row, 8, colors.muted, "LEFT")
        row.detail:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -4)
        row.detail:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        row.progress = createFont(row, 8, colors.muted, "LEFT")
        row.progress:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 9, 7)
        row.reward = createFont(row, 8, colors.quest, "RIGHT")
        row.reward:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -8, 7)
        row.achievement = achievement
        panel.rows[index] = row
    end

    self:RefreshDrawerPanel(drawer, helpers, false)
    return panel
end

function Achievements:RefreshDrawerPanel(drawer, helpers, resetScroll)
    local panel = drawer and drawer.achievementPanel
    if not panel then return end
    local applyBackdrop, colors = helpers.applyBackdrop, helpers.colors
    self:EvaluateAll(true)
    local save = self:Ensure()
    if not save then return end
    local unlocked, total = self:GetCounts()
    local points = self:GetPoints()
    panel.summary:SetText(format("%d / %d unlocked · %s achievement points · rewards are account-wide", unlocked, total, formatNumber(points)))
    if panel.searchHint then panel.searchHint:SetShown((panel.search:GetText() or "") == "" and not panel.search:HasFocus()) end

    local playerClassToken = self:GetPlayerClassToken()
    if panel.categoryButton and panel.categoryButton.label then panel.categoryButton.label:SetText(categoryLabel(panel.category)) end
    if panel.classButton and panel.classButton.label then panel.classButton.label:SetText(classLabel(playerClassToken, panel.classFilter)) end
    if panel.statusButton and panel.statusButton.label then panel.statusButton.label:SetText(statusLabel(panel.status)) end
    if panel.enabledToggle then
        if helpers.setAccent then helpers.setAccent(panel.enabledToggle, panel.enabledOnly and helpers.colors.green or helpers.colors.border, panel.enabledOnly) end
        if panel.enabledToggle.label then
            panel.enabledToggle.label:SetTextColor(panel.enabledOnly and 0.4 or 0.72, panel.enabledOnly and 1 or 0.74, panel.enabledOnly and 0.4 or 0.80, 1)
        end
    end

    local state = {
        search = panel.searchText, category = panel.category, classFilter = panel.classFilter,
        status = panel.status, enabledOnly = panel.enabledOnly,
    }
    local y = 0
    for _, row in ipairs(panel.rows or {}) do
        local achievement = row.achievement
        if self:MatchesFilter(achievement, save, state, playerClassToken) then
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", panel.toggleRow, "BOTTOMLEFT", 0, -8 - y)
            row:SetPoint("TOPRIGHT", panel.toggleRow, "BOTTOMRIGHT", 0, -8 - y)
            y = y + DRAWER_ROW_STEP
            local value = self:GetStat(achievement.stat)
            local complete = save.unlocked[achievement.key] ~= nil
            local missingAddon = achievementMissingAddon(achievement)
            local disabled = missingAddon ~= nil or not isCategoryEnabled(achievement.category)
            local label = (complete and "✓ " or "") .. achievement.title .. "  ·  TIER " .. tostring(achievement.tier) .. "  ·  " .. (self.categoryNames[achievement.category] or achievement.category)
            if missingAddon then
                label = label .. "  ·  REQUIRES " .. upper(missingAddon)
            elseif disabled then
                label = label .. "  ·  MODULE OFF"
            end
            row.title:SetText(label)
            row.detail:SetText(achievement.description)
            row.progress:SetText(complete and "UNLOCKED" or (formatNumber(min(value, achievement.goal)) .. "/" .. formatNumber(achievement.goal)))
            row.reward:SetText("+" .. achievement.coins .. " coins · +" .. achievement.xp .. " XP")
            local rowState = complete and "UNLOCKED" or (disabled and "LOCKED" or "AVAILABLE")
            local sc = _G.CreshSuiteUI and _G.CreshSuiteUI:GetStateColor(rowState, colors)
            if sc then
                applyBackdrop(row, sc.bg, sc.border)
                row.title:SetTextColor(sc.text[1], sc.text[2], sc.text[3], 1)
                row:SetAlpha(sc.alpha or 1)
            else
                applyBackdrop(row, colors.panelSoft, colors.border) -- cheap insurance, not an expected path
            end
            row:Show()
        else
            row:Hide()
        end
    end
    if panel.empty then panel.empty:SetShown(y == 0) end
    local base = drawerBaseOffset(panel.category == "CLASSES")
    panel:SetHeight(base + y)
    if drawer.mode == "ACHIEVEMENTS" then
        drawer.content:SetHeight(max(240, base + y))
        if resetScroll and CC.UI and CC.UI.SetGameDrawerScroll then CC.UI:SetGameDrawerScroll(0) end
    end
    if drawer.achievementMode and drawer.achievementMode.label then
        drawer.achievementMode.label:SetText("ACH " .. tostring(unlocked) .. "/" .. tostring(total))
    end
end

local eventFrame = CreateFrame("Frame")
local function safeRegister(event)
    if eventFrame and eventFrame.RegisterEvent then pcall(eventFrame.RegisterEvent, eventFrame, event) end
end
safeRegister("PLAYER_LOGIN")
safeRegister("PLAYER_ENTERING_WORLD")
safeRegister("PLAYER_DEAD")
safeRegister("ZONE_CHANGED_NEW_AREA")
safeRegister("SKILL_LINES_CHANGED")
safeRegister("TRADE_SKILL_SHOW")
safeRegister("TRADE_SKILL_UPDATE")
safeRegister("ENCOUNTER_END")
safeRegister("BOSS_KILL")

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        -- Ensure() always runs: it initialises save.stats used by CombatTracker.
        Achievements:Ensure()
        if CC.IsFeatureEnabled and CC:IsFeatureEnabled("worldProgression") then
            Achievements:ScanProfessions(true)
            Achievements:EvaluateAll(true)
        end
        return
    end
    if CC.IsFeatureEnabled and not CC:IsFeatureEnabled("worldProgression") then return end
    if event == "PLAYER_ENTERING_WORLD" then
        Achievements:ProcessInstanceState(true)
        Achievements:CaptureBossUnits()
    elseif event == "PLAYER_DEAD" then
        Achievements:RecordDeath()
    elseif event == "ZONE_CHANGED_NEW_AREA" then
        Achievements:ProcessInstanceState(false)
        Achievements:CaptureBossUnits()
    elseif event == "SKILL_LINES_CHANGED" or event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_UPDATE" then
        Achievements:ScanProfessions()
    elseif event == "ENCOUNTER_END" then
        local encounterID, encounterName, _, _, success = ...
        if tonumber(success) == 1 then Achievements:RecordBoss("ENCOUNTER:" .. tostring(encounterID or encounterName), encounterName) end
    elseif event == "BOSS_KILL" then
        local encounterID, encounterName = ...
        Achievements:RecordBoss("BOSSKILL:" .. tostring(encounterID or encounterName), encounterName)
    end
end)

-- ============================================================
-- Standalone Achievements window (opened by /cc achievements and aliases)
-- ============================================================
-- Self-contained: uses its own local widget helpers (same convention as
-- ProgressHub.lua/BattlePass.lua's standalone window) instead of CreshChat's
-- UI.lua drawer helpers, so this has no dependency on the CreshChat game
-- drawer and never forces it open. Every value shown is read from the
-- functions already defined above (GetCounts, GetPoints, IsUnlocked,
-- GetStat, categoryMissingAddon, isCategoryEnabled) -- nothing here
-- recomputes an achievement's progress or unlock state independently.
-- Pooled rows: a fixed page's worth of frames recycled across pages via
-- Prev/Next (see UpdateWindowPage/GoToPage below), not one frame per
-- catalog entry.

-- WINDOW_W is the window's actual declared width; CONTENT_WIDTH derives the
-- scroll child / row width from it (matching the scroll frame's own -8
-- right inset below) instead of an unrelated hard-coded magic number.
local WINDOW_W, WINDOW_H = 480, 620
local CONTENT_WIDTH = WINDOW_W - 8
local WINDOW_ROW_HEIGHT = 58
local WINDOW_ROW_GAP    = 6
local WINDOW_PAGE_SIZE  = 6

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
    btn:SetScript("OnClick", function(selfBtn, ...)
        if selfBtn.creshDisabled then return end
        if callback then callback(selfBtn, ...) end
    end)
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

local function winSetAccent(button, active, colors)
    if not button then return end
    if active then
        winApplyBackdrop(button, winDarken(colors.quest, 0.32), colors.quest)
        if button.label then button.label:SetTextColor(1, 1, 1, 1) end
    else
        winApplyBackdrop(button, colors.panelRaised, colors.border)
        if button.label then button.label:SetTextColor(colors.muted[1], colors.muted[2], colors.muted[3], 1) end
    end
end

function Achievements:IsWindowOpen()
    return self.window and self.window:IsShown()
end

function Achievements:ToggleWindow()
    if not self:BuildWindow() then return end
    if self.window:IsShown() then self:CloseWindow() else self:OpenWindow() end
end

function Achievements:OpenWindow()
    if not self:BuildWindow() then return end
    self.window:Show()
    self:RefreshWindow()
    if CC.UI and CC.UI.FocusWindow then CC.UI:FocusWindow(self.window) end
    if CC.UI and CC.UI.RefreshLauncherButtonStates then CC.UI:RefreshLauncherButtonStates() end
end

function Achievements:CloseWindow()
    if self.window then self.window:Hide() end
    if CC.UI and CC.UI.RefreshLauncherButtonStates then CC.UI:RefreshLauncherButtonStates() end
end

function Achievements:BuildWindow()
    if self.window then return self.window end
    -- Guarantee self.catalog is populated before the row-creation loop below,
    -- regardless of whether Ensure() has already run elsewhere (it normally
    -- has, via the ADDON_LOADED handler, but this must not depend on that
    -- timing to avoid building a window with zero rows).
    self:BuildCatalog()
    local colors = winPalette()

    self.windowCategory = self.windowCategory or "ALL"
    self.windowClassFilter = self.windowClassFilter or "MY_CLASS"
    self.windowStatus = self.windowStatus or "ALL"
    self.windowEnabledOnly = self.windowEnabledOnly or false
    self.windowSearchText = self.windowSearchText or ""

    local frame = CreateFrame("Frame", "CreshCollectAchievementsFrame", UIParent, winTemplateName())
    frame:SetSize(WINDOW_W, WINDOW_H)
    local savedPos = CC.db and CC.db.positions and CC.db.positions.achievementsWindow
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
            CC.db.positions.achievementsWindow = { point = point, relPoint = relPoint, x = floor(x or 0), y = floor(y or 0) }
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
    titleLabel:SetText("ACHIEVEMENTS")
    self.windowSummary = winCreateText(header, 9, colors.muted, "RIGHT")
    self.windowSummary:SetPoint("RIGHT", header, "RIGHT", -32, 0)
    self.windowSummary:SetText("0 / 0 unlocked")
    local closeBtn = CreateFrame("Button", nil, header, winTemplateName())
    closeBtn:SetSize(22, 22)
    closeBtn:SetPoint("TOPRIGHT", header, "TOPRIGHT", -4, -6)
    winApplyBackdrop(closeBtn, colors.panelRaised, colors.border)
    local closeLbl = winCreateText(closeBtn, 9, colors.muted, "CENTER")
    closeLbl:SetAllPoints()
    closeLbl:SetText("X")
    closeBtn:SetScript("OnClick", function() Achievements:CloseWindow() end)

    -- Search box
    local searchFrame = CreateFrame("Frame", nil, frame, winTemplateName())
    searchFrame:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -1)
    searchFrame:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, -1)
    searchFrame:SetHeight(28)
    winApplyBackdrop(searchFrame, colors.panelRaised, colors.border)
    local search = CreateFrame("EditBox", nil, searchFrame, winTemplateName())
    search:SetPoint("TOPLEFT", searchFrame, "TOPLEFT", 8, -4)
    search:SetPoint("BOTTOMRIGHT", searchFrame, "BOTTOMRIGHT", -8, 4)
    search:SetAutoFocus(false)
    search:SetFontObject(_G.GameFontNormalSmall or _G.GameFontHighlightSmall)
    search:SetTextInsets(2, 2, 0, 0)
    search:SetMaxLetters(40)
    search:SetScript("OnEscapePressed", function(box) box:ClearFocus() end)
    search:SetScript("OnEnterPressed", function(box) box:ClearFocus() end)
    search:SetScript("OnTextChanged", function(box)
        Achievements.windowSearchText = tostring(box:GetText() or "")
        Achievements:RefreshWindow()
    end)
    self.windowSearch = search

    -- Phase 2: three fixed, always-full-width cycle controls replace the
    -- old one-button-per-category wall (which overhung this 480px window
    -- once there were more than ~5 categories) -- left-click cycles
    -- forward, right-click cycles back, same convention used in the drawer
    -- panel above and ProgressHub.lua's settings button.
    local categoryRow = CreateFrame("Frame", nil, frame, winTemplateName())
    categoryRow:SetPoint("TOPLEFT", searchFrame, "BOTTOMLEFT", 8, -6)
    categoryRow:SetPoint("TOPRIGHT", searchFrame, "BOTTOMRIGHT", -8, -6)
    categoryRow:SetHeight(24)

    local classRow = CreateFrame("Frame", nil, frame, winTemplateName())
    classRow:SetPoint("TOPLEFT", categoryRow, "BOTTOMLEFT", 0, -4)
    classRow:SetPoint("TOPRIGHT", categoryRow, "BOTTOMRIGHT", 0, -4)
    classRow:SetHeight(24)

    local statusRow = CreateFrame("Frame", nil, frame, winTemplateName())
    statusRow:SetHeight(24)

    local toggleRow = CreateFrame("Frame", nil, frame, winTemplateName())
    toggleRow:SetHeight(22)

    -- Re-anchors statusRow/toggleRow around whichever of categoryRow/
    -- classRow is currently the last visible row, and shows/hides classRow
    -- itself -- called at build time and whenever the category changes.
    local function layoutFilterRows()
        local classShown = Achievements.windowCategory == "CLASSES"
        classRow:SetShown(classShown)
        local statusAnchor = classShown and classRow or categoryRow
        statusRow:ClearAllPoints()
        statusRow:SetPoint("TOPLEFT", statusAnchor, "BOTTOMLEFT", 0, -4)
        statusRow:SetPoint("TOPRIGHT", statusAnchor, "BOTTOMRIGHT", 0, -4)
        toggleRow:ClearAllPoints()
        toggleRow:SetPoint("TOPLEFT", statusRow, "BOTTOMLEFT", 0, -4)
        toggleRow:SetPoint("TOPRIGHT", statusRow, "BOTTOMRIGHT", 0, -4)
    end

    self.windowCategoryButton = winCreateButton(categoryRow, categoryLabel(self.windowCategory or "ALL"), 200, 24, function(_, mouseButton)
        local previousCategory = Achievements.windowCategory
        Achievements.windowCategory = cycleValue(categoryCycleOrder(), previousCategory, mouseButton == "RightButton" and -1 or 1)
        Achievements.windowClassFilter = Achievements:ResolveClassFilterOnCategoryChange(previousCategory, Achievements.windowCategory, Achievements.windowClassFilter)
        layoutFilterRows()
        Achievements:RefreshWindow()
    end)
    self.windowCategoryButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    self.windowCategoryButton:SetPoint("TOPLEFT", categoryRow, "TOPLEFT", 0, 0)
    self.windowCategoryButton:SetPoint("BOTTOMRIGHT", categoryRow, "BOTTOMRIGHT", 0, 0)

    self.windowClassButton = winCreateButton(classRow, classLabel(self:GetPlayerClassToken(), self.windowClassFilter), 200, 24, function(_, mouseButton)
        Achievements.windowClassFilter = cycleValue(classCycleOrder(), Achievements.windowClassFilter, mouseButton == "RightButton" and -1 or 1)
        Achievements:RefreshWindow()
    end)
    self.windowClassButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    self.windowClassButton:SetPoint("TOPLEFT", classRow, "TOPLEFT", 0, 0)
    self.windowClassButton:SetPoint("BOTTOMRIGHT", classRow, "BOTTOMRIGHT", 0, 0)

    self.windowStatusButton = winCreateButton(statusRow, statusLabel(self.windowStatus or "ALL"), 200, 24, function(_, mouseButton)
        Achievements.windowStatus = cycleValue({ "ALL", "UNLOCKED", "LOCKED" }, Achievements.windowStatus, mouseButton == "RightButton" and -1 or 1)
        Achievements:RefreshWindow()
    end)
    self.windowStatusButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    self.windowStatusButton:SetPoint("TOPLEFT", statusRow, "TOPLEFT", 0, 0)
    self.windowStatusButton:SetPoint("BOTTOMRIGHT", statusRow, "BOTTOMRIGHT", 0, 0)

    -- Enabled-modules-only toggle
    self.windowEnabledToggle = winCreateButton(toggleRow, "ENABLED MODULES ONLY", 160, 20, function()
        Achievements.windowEnabledOnly = not Achievements.windowEnabledOnly
        Achievements:RefreshWindow()
    end)
    self.windowEnabledToggle:SetPoint("RIGHT", toggleRow, "RIGHT", 0, 0)

    layoutFilterRows()

    -- Page bar (Prev/Next) -- same convention as CreshGames' Unlocks
    -- catalogue -- replaces the old one-frame-per-catalog-entry scrolling
    -- list, which also let long reward/progress text run past the row's
    -- reserved right-hand corner.
    local pageBar = CreateFrame("Frame", nil, frame, winTemplateName())
    pageBar:SetPoint("TOPLEFT", toggleRow, "BOTTOMLEFT", 0, -8)
    pageBar:SetPoint("TOPRIGHT", toggleRow, "BOTTOMRIGHT", 0, -8)
    pageBar:SetHeight(22)
    self.windowPrevButton = winCreateButton(pageBar, "<", 40, 22, function()
        Achievements:GoToPage((Achievements.windowCurrentPage or 1) - 1)
    end)
    self.windowPrevButton:SetPoint("LEFT", pageBar, "LEFT", 0, 0)
    self.windowNextButton = winCreateButton(pageBar, ">", 40, 22, function()
        Achievements:GoToPage((Achievements.windowCurrentPage or 1) + 1)
    end)
    self.windowNextButton:SetPoint("RIGHT", pageBar, "RIGHT", 0, 0)
    self.windowPageText = winCreateText(pageBar, 9, colors.muted, "CENTER")
    self.windowPageText:SetPoint("LEFT", self.windowPrevButton, "RIGHT", 4, 0)
    self.windowPageText:SetPoint("RIGHT", self.windowNextButton, "LEFT", -4, 0)
    self.windowPageText:SetPoint("TOP", pageBar, "TOP", 0, 0)
    self.windowPageText:SetPoint("BOTTOM", pageBar, "BOTTOM", 0, 0)

    -- Pooled rows: a fixed page's worth of frames, recycled across pages.
    -- Title/detail/progress/reward each get their own full-width line so
    -- long text can never run past the row's edge (the old design overlaid
    -- progress/reward in a reserved top/bottom-right corner shared with
    -- title/detail, which could overflow for longer strings).
    local content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT", pageBar, "BOTTOMLEFT", 0, -8)
    content:SetPoint("TOPRIGHT", pageBar, "BOTTOMRIGHT", 0, -8)
    content:SetHeight(WINDOW_PAGE_SIZE * (WINDOW_ROW_HEIGHT + WINDOW_ROW_GAP))
    self.windowContent = content

    self.windowPool = {}
    for i = 1, WINDOW_PAGE_SIZE do
        local row = CreateFrame("Frame", nil, content, winTemplateName())
        local rowY = -(i - 1) * (WINDOW_ROW_HEIGHT + WINDOW_ROW_GAP)
        row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, rowY)
        row:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, rowY)
        row:SetHeight(WINDOW_ROW_HEIGHT)
        winApplyBackdrop(row, colors.panelSoft, colors.border)
        row.title = winCreateText(row, 10, colors.text, "LEFT")
        row.title:SetPoint("TOPLEFT", row, "TOPLEFT", 8, -6)
        row.title:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        row.detail = winCreateText(row, 8, colors.muted, "LEFT")
        row.detail:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -3)
        row.detail:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        row.progress = winCreateText(row, 8, colors.muted, "LEFT")
        row.progress:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 8, 6)
        row.reward = winCreateText(row, 8, colors.quest, "RIGHT")
        row.reward:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -8, 6)
        row.achievement = nil
        row:Hide()
        self.windowPool[i] = row
    end

    self.windowCurrentPage = 1
    return frame
end

function Achievements:RefreshWindow()
    if not self.window or not self.window:IsShown() then return end
    local colors = winPalette()
    self:EvaluateAll(true)
    local save = self:Ensure()
    if not save then return end
    local unlockedCount, total = self:GetCounts()
    self.windowSummary:SetText(unlockedCount .. " / " .. total .. " unlocked · " .. formatNumber(self:GetPoints()) .. " points")

    local playerClassToken = self:GetPlayerClassToken()
    if self.windowCategoryButton and self.windowCategoryButton.label then self.windowCategoryButton.label:SetText(categoryLabel(self.windowCategory)) end
    if self.windowClassButton and self.windowClassButton.label then self.windowClassButton.label:SetText(classLabel(playerClassToken, self.windowClassFilter)) end
    if self.windowStatusButton and self.windowStatusButton.label then self.windowStatusButton.label:SetText(statusLabel(self.windowStatus)) end
    winSetAccent(self.windowEnabledToggle, self.windowEnabledOnly, colors)

    local state = {
        search = self.windowSearchText, category = self.windowCategory, classFilter = self.windowClassFilter,
        status = self.windowStatus, enabledOnly = self.windowEnabledOnly,
    }
    local filtered = {}
    for _, achievement in ipairs(self.catalog) do
        if self:MatchesFilter(achievement, save, state, playerClassToken) then
            filtered[#filtered + 1] = achievement
        end
    end
    self.windowFilteredList = filtered
    self.windowCurrentPage = 1
    self:UpdateWindowPage()
end

-- Repopulates only the current page's pooled rows from self.windowFilteredList
-- (built by RefreshWindow). Kept separate from RefreshWindow so Prev/Next
-- (GoToPage) can flip pages without re-running EvaluateAll/MatchesFilter
-- over the whole catalog on every click.
function Achievements:UpdateWindowPage()
    local list = self.windowFilteredList
    local pool = self.windowPool
    if not list or not pool then return end
    local colors = winPalette()
    local save = self:Ensure()
    if not save then return end

    local totalPages = max(1, ceil(#list / WINDOW_PAGE_SIZE))
    self.windowCurrentPage = max(1, min(totalPages, self.windowCurrentPage or 1))
    local firstIdx = (self.windowCurrentPage - 1) * WINDOW_PAGE_SIZE

    for poolI = 1, WINDOW_PAGE_SIZE do
        local achievement = list[firstIdx + poolI]
        local row = pool[poolI]
        if achievement then
            row.achievement = achievement
            local value = self:GetStat(achievement.stat)
            local complete = save.unlocked[achievement.key] ~= nil
            local missingAddon = achievementMissingAddon(achievement)
            local disabled = missingAddon ~= nil or not isCategoryEnabled(achievement.category)
            local label = (complete and "✓ " or "") .. achievement.title .. "  ·  TIER " .. tostring(achievement.tier)
                .. "  ·  " .. (self.categoryNames[achievement.category] or achievement.category)
            if missingAddon then
                label = label .. "  ·  REQUIRES " .. upper(missingAddon)
            elseif disabled then
                label = label .. "  ·  MODULE OFF"
            end
            row.title:SetText(label)
            row.detail:SetText(achievement.description)
            row.progress:SetText(complete and "UNLOCKED" or (formatNumber(min(value, achievement.goal)) .. "/" .. formatNumber(achievement.goal)))
            row.reward:SetText("+" .. achievement.coins .. " coins · +" .. achievement.xp .. " XP")
            local rowState = complete and "UNLOCKED" or (disabled and "LOCKED" or "AVAILABLE")
            local sc = _G.CreshSuiteUI and _G.CreshSuiteUI:GetStateColor(rowState, colors)
            if sc then
                winApplyBackdrop(row, sc.bg, sc.border)
                row.title:SetTextColor(sc.text[1], sc.text[2], sc.text[3], 1)
                row:SetAlpha(sc.alpha or 1)
            else
                winApplyBackdrop(row, colors.panelSoft, colors.border) -- cheap insurance, not an expected path
            end
            row:Show()
        else
            row.achievement = nil
            row:Hide()
        end
    end

    if self.windowPageText then self.windowPageText:SetText("Page " .. self.windowCurrentPage .. " / " .. totalPages) end
    if self.windowPrevButton then
        local enabled = self.windowCurrentPage > 1
        self.windowPrevButton:SetAlpha(enabled and 1 or 0.4)
        self.windowPrevButton.creshDisabled = not enabled
    end
    if self.windowNextButton then
        local enabled = self.windowCurrentPage < totalPages
        self.windowNextButton:SetAlpha(enabled and 1 or 0.4)
        self.windowNextButton.creshDisabled = not enabled
    end
end

function Achievements:GoToPage(pageIndex)
    if not self.windowFilteredList then return end
    local totalPages = max(1, ceil(#self.windowFilteredList / WINDOW_PAGE_SIZE))
    self.windowCurrentPage = max(1, min(totalPages, floor(tonumber(pageIndex) or 1)))
    self:UpdateWindowPage()
end
