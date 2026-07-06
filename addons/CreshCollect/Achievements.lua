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

local floor, max, min = math.floor, math.max, math.min
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
    if not silent and CC.UI and CC.UI.ShowBattlePassToast then
        CC.UI:ShowBattlePassToast(
            "Achievement unlocked: " .. achievement.title,
            "+" .. tostring(achievement.coins) .. " Cresh Coins · +" .. tostring(achievement.xp) .. " Chronicle XP",
            "BATTLEPASS",
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

function Achievements:GetPanelHeight(filter, category)
    local count = 0
    filter = lower(tostring(filter or ""))
    for _, achievement in ipairs(self.catalog) do
        local categoryMatch = not category or category == "ALL" or achievement.category == category
        local haystack = lower(table.concat({ achievement.title, achievement.description, self.categoryNames[achievement.category] or achievement.category }, " "))
        if categoryMatch and (filter == "" or string.find(haystack, filter, 1, true)) then count = count + 1 end
    end
    return 208 + (count * 62)
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

    panel.filters = CreateFrame("Frame", nil, panel)
    panel.filters:SetPoint("TOPLEFT", panel.searchFrame, "BOTTOMLEFT", 0, -6)
    panel.filters:SetPoint("TOPRIGHT", panel.searchFrame, "BOTTOMRIGHT", 0, -6)
    panel.filters:SetHeight(28)
    panel.filterButtons = {}
    panel.enabledOnly = false
    local filters = {
        { "ALL", "ALL", 42 }, { "EXPLORATION", "EXPLORE", 58 }, { "COMBAT", "COMBAT", 52 },
        { "DUNGEONS", "DUNGEON", 58 }, { "PROFESSIONS", "PROF", 46 },
    }
    local previous
    for _, item in ipairs(filters) do
        local key, label, width = item[1], item[2], item[3]
        local button = createButton(panel.filters, label, width, 24, function()
            panel.category = key
            Achievements:RefreshDrawerPanel(drawer, helpers, true)
        end)
        if previous then button:SetPoint("LEFT", previous, "RIGHT", 3, 0) else button:SetPoint("LEFT", panel.filters, "LEFT", 0, 0) end
        panel.filterButtons[key] = button
        previous = button
    end

    panel.toggleRow = CreateFrame("Frame", nil, panel)
    panel.toggleRow:SetPoint("TOPLEFT", panel.filters, "BOTTOMLEFT", 0, -4)
    panel.toggleRow:SetPoint("TOPRIGHT", panel.filters, "BOTTOMRIGHT", 0, -4)
    panel.toggleRow:SetHeight(24)
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
        row:SetHeight(56)
        applyBackdrop(row, colors.panelSoft, colors.border)
        row.title = createFont(row, 10, colors.text, "LEFT")
        row.title:SetPoint("TOPLEFT", row, "TOPLEFT", 9, -7)
        row.title:SetPoint("RIGHT", row, "RIGHT", -78, 0)
        row.detail = createFont(row, 8, colors.muted, "LEFT")
        row.detail:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -4)
        row.detail:SetPoint("RIGHT", row, "RIGHT", -78, 0)
        row.progress = createFont(row, 8, colors.muted, "RIGHT")
        row.progress:SetPoint("TOPRIGHT", row, "TOPRIGHT", -8, -7)
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
    local applyBackdrop, darken, colors = helpers.applyBackdrop, helpers.darken, helpers.colors
    self:EvaluateAll(true)
    local save = self:Ensure()
    local unlocked, total = self:GetCounts()
    local points = self:GetPoints()
    panel.summary:SetText(format("%d / %d unlocked · %s achievement points · rewards are account-wide", unlocked, total, formatNumber(points)))
    if panel.searchHint then panel.searchHint:SetShown((panel.search:GetText() or "") == "" and not panel.search:HasFocus()) end

    for key, button in pairs(panel.filterButtons or {}) do
        local active = panel.category == key
        if helpers.setAccent then helpers.setAccent(button, active and helpers.colors.quest or helpers.colors.border, active) end
        if button.label then button.label:SetTextColor(active and 1 or 0.72, active and 0.82 or 0.74, active and 0.28 or 0.80, 1) end
    end
    if panel.enabledToggle then
        if helpers.setAccent then helpers.setAccent(panel.enabledToggle, panel.enabledOnly and helpers.colors.green or helpers.colors.border, panel.enabledOnly) end
        if panel.enabledToggle.label then
            panel.enabledToggle.label:SetTextColor(panel.enabledOnly and 0.4 or 0.72, panel.enabledOnly and 1 or 0.74, panel.enabledOnly and 0.4 or 0.80, 1)
        end
    end

    local filter = lower(tostring(panel.searchText or ""))
    local y = 0
    for _, row in ipairs(panel.rows or {}) do
        local achievement = row.achievement
        local missingAddon = achievementMissingAddon(achievement)
        local categoryMatch = panel.category == "ALL" or panel.category == achievement.category
        local enabledMatch = not panel.enabledOnly or (isCategoryEnabled(achievement.category) and not missingAddon)
        local haystack = lower(table.concat({ achievement.title, achievement.description, self.categoryNames[achievement.category] or achievement.category }, " "))
        local searchMatch = filter == "" or string.find(haystack, filter, 1, true)
        if categoryMatch and enabledMatch and searchMatch then
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", panel.toggleRow, "BOTTOMLEFT", 0, -8 - y)
            row:SetPoint("TOPRIGHT", panel.toggleRow, "BOTTOMRIGHT", 0, -8 - y)
            y = y + 62
            local value = self:GetStat(achievement.stat)
            local complete = save.unlocked[achievement.key] ~= nil
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
            applyBackdrop(row, complete and darken(colors.green, 0.58) or colors.panelSoft, complete and colors.green or colors.border)
            if disabled and not complete then
                row.title:SetTextColor(colors.muted[1], colors.muted[2], colors.muted[3], 1)
            else
                row.title:SetTextColor(complete and colors.green[1] or colors.text[1], complete and colors.green[2] or colors.text[2], complete and colors.green[3] or colors.text[3], 1)
            end
            row:SetAlpha(disabled and not complete and 0.55 or 1)
            row:Show()
        else
            row:Hide()
        end
    end
    if panel.empty then panel.empty:SetShown(y == 0) end
    panel:SetHeight(208 + y)
    if drawer.mode == "ACHIEVEMENTS" then
        drawer.content:SetHeight(max(240, 208 + y))
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
-- One row per catalog entry, built once (matching the existing drawer
-- panel's own approach above) -- not rebuilt on every open.

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

    local frame = CreateFrame("Frame", "CreshCollectAchievementsFrame", UIParent, winTemplateName())
    frame:SetSize(480, 620)
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
            if CC.UI and CC.UI.FocusWindow then CC.UI:FocusWindow(selfFrame) end
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
    if CC.UI and CC.UI.InstallWindowFocus then CC.UI:InstallWindowFocus(frame) end

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

    -- Category filter row (ALL + each category)
    local filterBar = CreateFrame("Frame", nil, frame, winTemplateName())
    filterBar:SetPoint("TOPLEFT", searchFrame, "BOTTOMLEFT", 8, -6)
    filterBar:SetPoint("TOPRIGHT", searchFrame, "BOTTOMRIGHT", -8, -6)
    filterBar:SetHeight(24)
    self.windowFilterButtons = {}
    local previousFilter
    local filterDefs = { { "ALL", "ALL", 42 } }
    for _, cat in ipairs(self.categoryOrder) do
        filterDefs[#filterDefs + 1] = { cat, (self.categoryNames[cat] or cat):upper():sub(1, 8), 64 }
    end
    for _, filterDef in ipairs(filterDefs) do
        local key, label, width = filterDef[1], filterDef[2], filterDef[3]
        local btn = winCreateButton(filterBar, label, width, 22, function()
            Achievements.windowCategory = key
            Achievements:RefreshWindow()
        end)
        if previousFilter then btn:SetPoint("LEFT", previousFilter, "RIGHT", 3, 0)
        else btn:SetPoint("LEFT", filterBar, "LEFT", 0, 0) end
        self.windowFilterButtons[key] = btn
        previousFilter = btn
    end

    -- Enabled-modules-only toggle
    local toggleRow = CreateFrame("Frame", nil, frame, winTemplateName())
    toggleRow:SetPoint("TOPLEFT", filterBar, "BOTTOMLEFT", 0, -4)
    toggleRow:SetPoint("TOPRIGHT", filterBar, "BOTTOMRIGHT", 0, -4)
    toggleRow:SetHeight(22)
    self.windowEnabledToggle = winCreateButton(toggleRow, "ENABLED MODULES ONLY", 160, 20, function()
        Achievements.windowEnabledOnly = not Achievements.windowEnabledOnly
        Achievements:RefreshWindow()
    end)
    self.windowEnabledToggle:SetPoint("RIGHT", toggleRow, "RIGHT", 0, 0)

    -- Scroll + one row per catalog entry (matches the existing drawer
    -- panel's own approach -- built once here, never rebuilt on open).
    local scroll = CreateFrame("ScrollFrame", nil, frame)
    scroll:SetPoint("TOPLEFT", toggleRow, "BOTTOMLEFT", 0, -8)
    scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 8)
    scroll:EnableMouseWheel(true)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetWidth(450)
    content:SetHeight(620)
    scroll:SetScrollChild(content)
    scroll:SetScript("OnMouseWheel", function(selfScroll, delta)
        local current = selfScroll:GetVerticalScroll() or 0
        local maximum = selfScroll:GetVerticalScrollRange() or 0
        selfScroll:SetVerticalScroll(max(0, min(maximum, current - delta * 42)))
    end)
    self.windowContent = content

    self.windowRows = {}
    for index, achievement in ipairs(self.catalog) do
        local row = CreateFrame("Frame", nil, content, winTemplateName())
        row:SetWidth(450)
        row:SetHeight(52)
        winApplyBackdrop(row, colors.panelSoft, colors.border)
        row.title = winCreateText(row, 10, colors.text, "LEFT")
        row.title:SetPoint("TOPLEFT", row, "TOPLEFT", 8, -6)
        row.title:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        row.detail = winCreateText(row, 8, colors.muted, "LEFT")
        row.detail:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -3)
        row.detail:SetPoint("RIGHT", row, "RIGHT", -78, 0)
        row.progress = winCreateText(row, 8, colors.muted, "RIGHT")
        row.progress:SetPoint("TOPRIGHT", row, "TOPRIGHT", -7, -6)
        row.reward = winCreateText(row, 8, colors.quest, "RIGHT")
        row.reward:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -7, 6)
        row.achievement = achievement
        self.windowRows[index] = row
    end

    self.windowCategory = self.windowCategory or "ALL"
    self.windowEnabledOnly = self.windowEnabledOnly or false
    self.windowSearchText = self.windowSearchText or ""
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

    for key, btn in pairs(self.windowFilterButtons or {}) do
        winSetAccent(btn, self.windowCategory == key, colors)
    end
    winSetAccent(self.windowEnabledToggle, self.windowEnabledOnly, colors)

    local filter = lower(tostring(self.windowSearchText or ""))
    local y = 0
    for _, row in ipairs(self.windowRows or {}) do
        local achievement = row.achievement
        local missingAddon = achievementMissingAddon(achievement)
        local categoryMatch = self.windowCategory == "ALL" or self.windowCategory == achievement.category
        local enabledMatch = not self.windowEnabledOnly or (isCategoryEnabled(achievement.category) and not missingAddon)
        local haystack = lower(table.concat({ achievement.title, achievement.description, self.categoryNames[achievement.category] or achievement.category }, " "))
        local searchMatch = filter == "" or string.find(haystack, filter, 1, true)
        if categoryMatch and enabledMatch and searchMatch then
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", self.windowContent, "TOPLEFT", 0, -y)
            row:SetPoint("TOPRIGHT", self.windowContent, "TOPRIGHT", 0, -y)
            y = y + 58
            local value = self:GetStat(achievement.stat)
            local complete = save.unlocked[achievement.key] ~= nil
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
            winApplyBackdrop(row, complete and winDarken(colors.green, 0.58) or colors.panelSoft, complete and colors.green or colors.border)
            if disabled and not complete then
                row.title:SetTextColor(colors.muted[1], colors.muted[2], colors.muted[3], 1)
            else
                row.title:SetTextColor(complete and colors.green[1] or colors.text[1], complete and colors.green[2] or colors.text[2], complete and colors.green[3] or colors.text[3], 1)
            end
            row:SetAlpha(disabled and not complete and 0.55 or 1)
            row:Show()
        else
            row:Hide()
        end
    end
    self.windowContent:SetHeight(max(1, y))
end
