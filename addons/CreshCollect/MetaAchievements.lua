-- CreshCollect/MetaAchievements.lua
-- Rework Phase 6: adds the "Meta Achievements" category the plan's World
-- categories list calls for (Questing, Exploration, Combat, Dungeons,
-- Raids, Professions, Reputation, PvP, Classes, Community, Meta
-- Achievements). Merges into the shared COL.Achievements catalog the same
-- way AchievementExpansion.lua/ClassAchievements.lua do -- must load after
-- both (see CreshCollect.toc).
--
-- A single series rewarding overall completionism: total World
-- achievements unlocked, account-wide. Deliberately excludes META entries
-- from their own stat so completing a Meta achievement can never count
-- toward completing more Meta achievements.
local _, COL = ...
if not COL then return end
if not COL.Achievements then return end
local A = COL.Achievements

local floor, max = math.floor, math.max

local META_SERIES = {
    { key = "META_001", goal = 25,  title = "Achievement Hunter",       description = "Complete 25 World of Warcraft achievements.",  tier = 1, coins = 30,  xp = 20 },
    { key = "META_002", goal = 50,  title = "Dedicated Adventurer",     description = "Complete 50 World of Warcraft achievements.",  tier = 2, coins = 60,  xp = 40 },
    { key = "META_003", goal = 100, title = "Century Achiever",        description = "Complete 100 World of Warcraft achievements.", tier = 3, coins = 120, xp = 80 },
    { key = "META_004", goal = 200, title = "Azeroth Completionist",   description = "Complete 200 World of Warcraft achievements.", tier = 4, coins = 250, xp = 160 },
    { key = "META_005", goal = 300, title = "Legendary Achiever",      description = "Complete 300 World of Warcraft achievements.", tier = 5, coins = 400, xp = 260 },
    { key = "META_006", goal = 400, title = "Master of Azeroth",       description = "Complete 400 World of Warcraft achievements.", tier = 6, coins = 600, xp = 380 },
    { key = "META_007", goal = 500, title = "Grand Chronicle Legend",  description = "Complete 500 World of Warcraft achievements.", tier = 7, coins = 900, xp = 550 },
}

local oldBuildCatalog = A.BuildCatalog
function A:BuildCatalog()
    oldBuildCatalog(self)
    if self.metaAchievementsBuilt then return end
    self.metaAchievementsBuilt = true
    self.categoryNames.META = "Meta Achievements"
    local found = false
    for _, key in ipairs(self.categoryOrder or {}) do if key == "META" then found = true break end end
    if not found then table.insert(self.categoryOrder, "META") end
    for _, item in ipairs(META_SERIES) do
        local achievement = {
            key = item.key,
            category = "META",
            stat = "META_TOTAL_COMPLETED",
            goal = item.goal,
            title = item.title,
            description = item.description,
            coins = item.coins,
            xp = item.xp,
            tier = item.tier,
            meta = true,
        }
        self.catalog[#self.catalog + 1] = achievement
        self.byKey[achievement.key] = achievement
    end
end

-- Counts every unlocked achievement EXCEPT other Meta achievements, so this
-- stat can never be satisfied by completing more of itself.
local oldGetStat = A.GetStat
function A:GetStat(stat)
    if stat ~= "META_TOTAL_COMPLETED" then return oldGetStat(self, stat) end
    local save = self:Ensure()
    if not save then return 0 end
    local count = 0
    for _, achievement in ipairs(self.catalog) do
        if achievement.category ~= "META" and save.unlocked[achievement.key] then
            count = count + 1
        end
    end
    return floor(max(0, count))
end
