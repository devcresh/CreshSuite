-- CreshCollect/CollectRewardRegistry.lua
-- Rework Phase 2: data-driven reward catalogs, built from the existing
-- source-of-truth tables in BattlePass.lua rather than duplicating their data
-- by hand -- the registry and the granting code can never disagree, because
-- the registry is generated from the same tables the granting code reads.
-- Must load after BattlePass.lua (see CreshCollect.toc).
--
-- Every entry has a stable `id` that does not depend solely on a level
-- number. Chat-theme entries use the theme's own key (already stable and
-- non-numeric); the bonus-coin milestones have no other natural identity, so
-- they borrow that level's Battle Pass title as a slug -- renumbering the
-- pass later would not silently orphan the id.
local _, COL = ...
if not COL then return end

local CC = setmetatable({}, { __index = function(_, k)
    local c = _G.CreshChat
    return c and c[k]
end })

local Registry = { version = COL.version }
COL.RewardRegistry = Registry
if COL.RegisterModule then COL:RegisterModule("RewardRegistry", Registry) end

Registry.chronicleRewards = {}
Registry.chatThemeAchievementRewards = {}
Registry.shopThemeRewards = {}

-- Appends `entry` to `list`, refusing (and logging, not crashing) a
-- duplicate id or unlockKey -- catalog corruption fails loud in dev/tests
-- but never takes the addon down for a live player.
local function addEntry(list, entry)
    if type(entry.id) ~= "string" or entry.id == "" then
        if CC.Print then CC:Print("|cffff4040RewardRegistry:|r reward entry missing an id, skipped.") end
        return false
    end
    for _, existing in ipairs(list) do
        if existing.id == entry.id then
            if CC.Print then CC:Print("|cffff4040RewardRegistry:|r duplicate reward id '" .. entry.id .. "', skipped.") end
            return false
        end
        if entry.unlockKey and existing.unlockKey == entry.unlockKey then
            if CC.Print then CC:Print("|cffff4040RewardRegistry:|r duplicate unlockKey '" .. tostring(entry.unlockKey) .. "' (id '" .. entry.id .. "'), skipped.") end
            return false
        end
    end
    list[#list + 1] = entry
    return true
end

local function slugify(text)
    text = string.upper(tostring(text or ""))
    text = text:gsub("[^%w]+", "_")
    text = text:gsub("^_+", ""):gsub("_+$", "")
    return text
end

-- ---------------------------------------------------------------------
-- 5. Chronicle rewards (CreshCollect's own 200-level Battle Pass, BattlePass.lua):
--    bonus-coin milestones and the 20 chat zone themes it grants directly.
-- ---------------------------------------------------------------------
if COL.BattlePass then
    for level, coins in pairs(COL.BattlePass.bonusRewardLevels or {}) do
        local slug = slugify(COL.BattlePass.levelNames and COL.BattlePass.levelNames[level] or ("LEVEL_" .. level))
        addEntry(Registry.chronicleRewards, {
            id = "CRESHCOLLECT:CHRONICLE_BONUS:" .. slug,
            addon = "CRESHCOLLECT",
            type = "BONUS_COINS",
            unlockKey = slug,
            displayName = COL.BattlePass.levelNames and COL.BattlePass.levelNames[level],
            sourceSystem = "CHRONICLE_PASS",
            requiredLevel = level,
            requiredAchievement = nil,
            requiredAddon = nil,
            assetPath = nil,
            migrationAlias = "CHRONICLE_PASS_LEVEL:" .. level,
            placeholder = false,
            coins = coins,
        })
    end
    for level, themeKey in pairs(COL.BattlePass.passThemeRewards or {}) do
        local info = COL.BattlePass.premiumThemes and COL.BattlePass.premiumThemes[themeKey]
        addEntry(Registry.chronicleRewards, {
            id = "CRESHCOLLECT:CHRONICLE_THEME:" .. themeKey,
            addon = "CRESHCOLLECT",
            type = "CHAT_THEME",
            unlockKey = themeKey,
            displayName = info and info.name or themeKey,
            sourceSystem = "CHRONICLE_PASS",
            requiredLevel = level,
            requiredAchievement = nil,
            requiredAddon = "CreshChat",
            assetPath = nil,
            migrationAlias = "CHRONICLE_PASS_LEVEL:" .. level,
            placeholder = false,
        })
    end
end

-- ---------------------------------------------------------------------
-- 6. Chat-theme achievement rewards: every premiumThemes entry sourced from a
--    World of Warcraft achievement (Rework Phase 7).
-- 7. Cresh Coin shop themes: every premiumThemes entry sourced from the shop
--    (not the pass).
-- ---------------------------------------------------------------------
if COL.BattlePass and COL.BattlePass.premiumThemes then
    for themeKey, info in pairs(COL.BattlePass.premiumThemes) do
        if info.source == "ACHIEVEMENT" then
            addEntry(Registry.chatThemeAchievementRewards, {
                id = "CRESHCOLLECT:ACHIEVEMENT_THEME:" .. themeKey,
                addon = "CRESHCOLLECT",
                type = "CHAT_THEME",
                unlockKey = themeKey,
                displayName = info.name,
                sourceSystem = "ACHIEVEMENT",
                requiredLevel = nil,
                requiredAchievement = info.achievementKey,
                requiredAddon = "CreshChat",
                assetPath = nil,
                migrationAlias = "ACHIEVEMENT_THEME:" .. themeKey,
                placeholder = false,
            })
        elseif info.source == "SHOP" then
            addEntry(Registry.shopThemeRewards, {
                id = "CRESHCOLLECT:SHOP_THEME:" .. themeKey,
                addon = "CRESHCOLLECT",
                type = "CHAT_THEME",
                unlockKey = themeKey,
                displayName = info.name,
                sourceSystem = "SHOP",
                requiredLevel = nil,
                requiredAchievement = nil,
                requiredAddon = "CreshChat",
                assetPath = nil,
                migrationAlias = "SHOP_THEME:" .. themeKey,
                placeholder = false,
                price = info.price,
            })
        end
    end
end
