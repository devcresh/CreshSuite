-- CreshGames/GamesRewardRegistry.lua
-- Rework Phase 2: data-driven reward catalogs, built from the existing
-- source-of-truth tables (CardDeckLibrary, TetrisThemes, DungeonCrawlerContent,
-- GamesBattlePass, DungeonDwellersProgression) rather than duplicating their
-- data by hand -- the registry and the granting code can never disagree,
-- because the registry is generated from the same tables the granting code
-- reads. Must load after all of those files (see CreshGames.toc).
--
-- Every entry has a stable `id` that does not depend solely on a level
-- number, so retuning a pass's pacing later never renames an entry. `id`s
-- are namespaced "CRESHGAMES:<TYPE>:<unlockKey-or-rule-id>".
local _, CG = ...
if not CG then return end

local CC = setmetatable({}, { __index = function(_, k)
    local c = _G.CreshChat
    return c and c[k]
end })

local Registry = { version = CG.version }
CG.RewardRegistry = Registry
if CG.RegisterModule then CG:RegisterModule("RewardRegistry", Registry) end

Registry.arcadeRewards = {}
Registry.tetrisMasteryRewards = {}
Registry.dungeonMasteryRewards = {}
Registry.cardDeckCatalog = {}

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

-- ---------------------------------------------------------------------
-- 1. Arcade rewards (CreshGames' own 50-level Battle Pass, GamesBattlePass.lua)
-- ---------------------------------------------------------------------
if CG.BattlePass and CG.BattlePass.gameRewardCatalog then
    for level, reward in pairs(CG.BattlePass.gameRewardCatalog) do
        if reward.deckKey then
            addEntry(Registry.arcadeRewards, {
                id = "CRESHGAMES:CARD_DECK:" .. reward.deckKey,
                addon = "CRESHGAMES",
                type = "CARD_DECK",
                unlockKey = reward.deckKey,
                displayName = reward.deckName,
                sourceSystem = "ARCADE_PASS",
                requiredLevel = level,
                requiredAchievement = nil,
                requiredAddon = nil,
                assetPath = nil,
                migrationAlias = "ARCADE_PASS_LEVEL:" .. level,
                placeholder = false,
            })
        end
        if reward.tetrisThemeKey then
            addEntry(Registry.arcadeRewards, {
                id = "CRESHGAMES:TETRIS_THEME:" .. reward.tetrisThemeKey,
                addon = "CRESHGAMES",
                type = "TETRIS_THEME",
                unlockKey = reward.tetrisThemeKey,
                displayName = reward.tetrisThemeName,
                sourceSystem = "ARCADE_PASS",
                requiredLevel = level,
                requiredAchievement = nil,
                requiredAddon = nil,
                assetPath = nil,
                migrationAlias = "ARCADE_PASS_LEVEL:" .. level,
                placeholder = false,
            })
        end
    end
end

-- ---------------------------------------------------------------------
-- 2. Tetris Mastery rewards (Tetris' own theme/background library, TetrisThemes.lua)
--    Includes every theme regardless of current unlock trigger (in-game
--    level, the dedicated Tetris Mastery track, or the Arcade Pass) -- all three
--    triggers are CreshGames' own now (Rework Phase 3 removed the last
--    cross-addon trigger, a legacy CreshCollect sync), so every theme is
--    listed here exactly once with no `requiredAddon`.
-- ---------------------------------------------------------------------
local SOURCE_SYSTEM_BY_THEME_SOURCE = {
    DEFAULT = "DEFAULT",
    GAME_LEVEL = "TETRIS_GAME_LEVEL",
    TETRIS_PASS = "TETRIS_MASTERY_PASS",
    ARCADE_PASS = "ARCADE_PASS",
}
if CG.Tetris and CG.Tetris.themes then
    for _, key in ipairs(CG.Tetris.themeOrder or {}) do
        local theme = CG.Tetris.themes[key]
        if theme then
            addEntry(Registry.tetrisMasteryRewards, {
                id = "CRESHGAMES:TETRIS_THEME:" .. key,
                addon = "CRESHGAMES",
                type = "TETRIS_THEME",
                unlockKey = key,
                displayName = theme.name,
                sourceSystem = SOURCE_SYSTEM_BY_THEME_SOURCE[theme.source] or theme.source,
                requiredLevel = theme.requirement,
                requiredAchievement = nil,
                requiredAddon = nil,
                assetPath = nil,
                migrationAlias = tostring(theme.source) .. ":" .. tostring(theme.requirement),
                placeholder = false,
            })
        end
    end
    for _, key in ipairs(CG.Tetris.backgroundOrder or {}) do
        local bg = CG.Tetris.backgrounds[key]
        if bg then
            addEntry(Registry.tetrisMasteryRewards, {
                id = "CRESHGAMES:TETRIS_BACKGROUND:" .. key,
                addon = "CRESHGAMES",
                type = "TETRIS_BACKGROUND",
                unlockKey = key,
                displayName = bg.name,
                sourceSystem = "BACKGROUND_REVEAL",
                requiredLevel = bg.requirement,
                requiredAchievement = nil,
                requiredAddon = nil,
                assetPath = bg.texture,
                migrationAlias = "BACKGROUND_REVEAL:" .. key,
                placeholder = false,
            })
        end
    end
end

-- ---------------------------------------------------------------------
-- 3. Delver Mastery rewards: armour sets (DungeonCrawlerContent.lua) and the
--    Delver Mastery's own buff-schedule rules (DungeonDwellersProgression.lua)
-- ---------------------------------------------------------------------
local content = CG.DungeonCrawlerContent
if content and content.armourSets then
    for _, sets in pairs(content.armourSets) do
        for _, set in ipairs(sets) do
            addEntry(Registry.dungeonMasteryRewards, {
                id = "CRESHGAMES:DUNGEON_ARMOUR:" .. set.key,
                addon = "CRESHGAMES",
                type = "DUNGEON_ARMOUR",
                unlockKey = set.key,
                displayName = set.name,
                sourceSystem = "DUNGEON_MASTERY_CLASS_ARMOUR",
                requiredLevel = set.unlockLevel,
                requiredAchievement = nil,
                requiredAddon = nil,
                assetPath = set.icon,
                migrationAlias = "ARMOUR_TIER:" .. tostring(set.classKey) .. ":" .. tostring(set.tier),
                -- Rule: never include placeholder Dungeon armour in a
                -- global pass reward. Druid/Shaman tiers are data-complete
                -- but art-incomplete (artStatus == "PLACEHOLDER") and must
                -- stay flagged until real art replaces them.
                placeholder = set.artStatus == "PLACEHOLDER",
            })
        end
    end
end
if CG.DungeonDwellersPass and CG.DungeonDwellersPass.buffScheduleCatalog then
    for _, rule in ipairs(CG.DungeonDwellersPass.buffScheduleCatalog) do
        addEntry(Registry.dungeonMasteryRewards, {
            id = "CRESHGAMES:DUNGEON_BUFF:" .. rule.id,
            addon = "CRESHGAMES",
            type = "DUNGEON_BUFF",
            unlockKey = rule.key,
            displayName = rule.label,
            sourceSystem = "DUNGEON_DWELLER_BATTLE_PASS",
            requiredLevel = rule.levels and rule.levels[1] or nil,
            requiredAchievement = nil,
            requiredAddon = nil,
            assetPath = nil,
            migrationAlias = rule.cycleOf20 and ("CYCLE20:" .. rule.cycleOf20) or ("LEVELS:" .. table.concat(rule.levels or {}, ",")),
            placeholder = false,
        })
    end
end

-- ---------------------------------------------------------------------
-- 4. Card deck catalog (identity/metadata for every deck; ownership grants
--    themselves are recorded once, in arcadeRewards above -- this table
--    never duplicates a grant, it only describes the decks that exist)
-- ---------------------------------------------------------------------
local deckLibrary = _G.CreshGamesCardDecks or {}
if CG.CardDecks then
    local orderedKeys = { CG.CardDecks.defaultDeck }
    for _, key in ipairs(CG.CardDecks.premiumOrder or {}) do orderedKeys[#orderedKeys + 1] = key end
    for _, key in ipairs(orderedKeys) do
        local info = deckLibrary[key]
        if info then
            addEntry(Registry.cardDeckCatalog, {
                id = "CRESHGAMES:CARD_DECK_CATALOG:" .. key,
                addon = "CRESHGAMES",
                type = "CARD_DECK",
                unlockKey = key,
                displayName = info.displayName,
                sourceSystem = info.unlockedByDefault and "DEFAULT" or "ARCADE_PASS_OR_RANDOM_STARTER",
                requiredLevel = nil,
                requiredAchievement = nil,
                requiredAddon = nil,
                assetPath = info.icon,
                migrationAlias = "DECK:" .. key,
                placeholder = false,
            })
        end
    end
end
