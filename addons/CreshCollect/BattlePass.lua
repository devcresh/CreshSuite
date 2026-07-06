local _, COL = ...
if not COL then return end

local CC = setmetatable({}, { __index = function(_, k)
    local c = _G.CreshChat
    return c and c[k]
end })

local Pass = {
    version = COL.version,
    maxLevel = 200,
}
COL.BattlePass = Pass
if COL.RegisterModule then COL:RegisterModule("BattlePass", Pass) end

local floor, min, max = math.floor, math.min, math.max
local upper = string.upper
local format = string.format

Pass.themeOrder = { "UBUNTU", "WINDOWS_95", "MSN_MESSENGER", "WOW_CLASSIC", "ZLR" }

local function isProductLoaded(name)
    return (_G.CreshSuite and _G.CreshSuite.IsProductLoaded and _G.CreshSuite:IsProductLoaded(name)) == true
end

-- Card decks and Tetris themes are CreshGames' own Battle Pass rewards now
-- (addons/CreshGames/BattlePass.lua) -- this pass stays exploration/
-- achievement/quest driven and no longer grants game content. The nine
-- levels that used to carry a deck/theme reward keep an equivalent bonus
-- coin payout instead, so no reward slot goes empty for existing players.
Pass.bonusRewardLevels = {
    [10] = 150, [15] = 150, [25] = 200, [35] = 200, [40] = 250,
    [55] = 300, [75] = 350, [95] = 400, [100] = 500,
}

Pass.levelNames = {
    "Arcade Initiate", "First Hop", "Lucky Draw", "Dungeon Scout", "Bronze Cache",
    "Opening Move", "River Reader", "Twenty-One", "Minion Recruit", "Silver Cache",
    "Traffic Dodger", "Pair Maker", "Room Delver", "Board Tactician", "Challenger Cache",
    "Line Breaker", "Paddle Keeper", "Dice Fighter", "Streak Seeker", "Gold Cache",
    "Frogger Veteran", "Card Shark", "Dungeon Captain", "Chess Strategist", "Heroic Cache",
    "Tetris Racer", "Pong Contender", "Blackjack Ace", "Boss Hunter", "Platinum Cache",
    "Endless Hopper", "Table Veteran", "Minion Master", "Chess Expert", "Champion Cache",
    "High Roller", "Dungeon Survivor", "Perfect Read", "Multiplayer Rival", "Mythic Cache",
    "Arcade Elite", "Board Master", "River King", "Endless Dweller", "Legend Cache",
    "Grandmaster Trial", "Casino Champion", "Game Night Hero", "Cresh Challenger", "Grand Arcade Vault",
    "Azeroth Rambler", "Faction Standard", "Forest Pathfinder", "Desert Runner", "Explorer Cache",
    "City Defender", "Crypt Delver", "Arena Reader", "Portal Walker", "Veteran Cache",
    "Outland Scout", "Marsh Navigator", "Nagrand Rider", "Shadowmoon Seeker", "Expedition Cache",
    "Sunwell Spark", "Tempest Tactician", "Serpent Challenger", "Black Temple Raider", "Epic Cache",
    "Alliance Vanguard", "Horde Vanguard", "Forsaken Survivor", "Moonlit Sentinel", "Faction Cache",
    "Draenei Crystal", "Blood Elf Dawn", "Tauren Spirit", "Dwarven Forge", "Masterwork Cache",
    "Arcane Gambler", "Fel Challenger", "Storm Caller", "Grove Keeper", "Exalted Cache",
    "Endless Champion", "Dungeon Warlord", "Chess Virtuoso", "Card Table Legend", "Conqueror Cache",
    "Hundred-Room Hero", "Perfect Crossing", "Grand Rival", "Theme Collector", "Ascendant Cache",
    "Azeroth Icon", "Outland Icon", "Social Arcade Legend", "Cresh Immortal", "Grand Theme Vault",
    -- Levels 101-200
    "Legendary Initiate", "Second Horizon", "Grander Fortune", "Realm Walker", "Imperial Cache",
    "Dawn Herald", "Starfall Seeker", "Crystal Warden", "Vault Delver", "Sovereign Cache",
    "Flame Warder", "Storm Victor", "Iron Sentinel", "Rift Scout", "Twilight Cache",
    "Void Wanderer", "Ember Tactician", "Tide Caller", "Sky Marshal", "Celestial Cache",
    "Rune Keeper", "Pact Forger", "Shadow Dancer", "Oath Bearer", "Eternity Cache",
    "World Wanderer", "Shard Hunter", "Pinnacle Walker", "Crucible Lord", "Dominion Cache",
    "Primal Champion", "Ancient Caller", "Lore Master", "Power Forger", "Valor Cache",
    "Sacred Keeper", "Gate Warden", "Horizon Runner", "Relic Finder", "Conquest Cache",
    "Titan's Disciple", "Boundless Wanderer", "Throne Seeker", "Beacon Holder", "Primordial Cache",
    "Storm's Edge", "Void Champion", "Abyss Walker", "Crown Seeker", "Grand Conqueror's Vault",
    "Arcane Sovereign", "Battle Forged", "Realm Master", "Undying Seeker", "Eternal Cache",
    "Last Bastion", "Crucible Veteran", "Starlit Rival", "Ironclad Sage", "Timeless Cache",
    "Light's Ascendant", "Sunlit Keeper", "Radiant Warden", "Dawnbringer", "Unbowed Cache",
    "Arcane Vanguard", "Fel Warden", "Storm Sentinel", "Grove Champion", "Radiant Cache",
    "Azeroth Paragon", "Relentless Paragon", "Realm Forger", "Cresh Transcendent", "Ancient Cache",
    "Bastion Breaker", "Immortal Delver", "Final Rival", "Lore Champion", "Undying Cache",
    "Arena Paragon", "Void Walker", "Eternal Dawn", "Kingdom's Edge", "Titan Cache",
    "Forge Mastery", "Pinnacle Seeker", "Immortal Rival", "Grand Arcanist", "Transcendent Cache",
    "Azeroth Eternal", "Boundless Champion", "Cresh Paragon", "Immortal Seeker", "Infinite Cache",
    "Last Legend", "Timeless Champion", "Cresh Ascendant", "Immortal of Azeroth", "Grand Eternal Champion",
}

-- Mini-games no longer feed this pass (Phase 10 split moved that funding to
-- CreshGames' own Battle Pass) -- so this pass' one and only requirement
-- route is world/exploration progress, regardless of whether CreshGames is
-- installed.
Pass.worldRequirementRoute = {
    name = "World Progression", action = "KEEP EXPLORING",
    hint = "Complete achievements, explore Azeroth, and defeat enemies to earn Pass Points.",
}

Pass.premiumThemes = {
    UBUNTU = {
        name = "Ubuntu",
        price = 100,
        note = "Warm aubergine panels with vivid orange accents.",
        swatches = { {0.105,0.028,0.090,1}, {0.925,0.315,0.080,1}, {0.640,0.175,0.055,1} },
        source = "SHOP", requiredAddon = "CreshChat",
    },
    WINDOWS_95 = {
        name = "Windows 95",
        price = 200,
        note = "Teal desktop surfaces with classic grey controls.",
        swatches = { {0.015,0.190,0.190,1}, {0.720,0.730,0.750,1}, {0.000,0.500,0.760,1} },
        source = "SHOP", requiredAddon = "CreshChat",
    },
    MSN_MESSENGER = {
        name = "MSN Messenger",
        price = 300,
        note = "Bright blue messenger styling inspired by early chat clients.",
        swatches = { {0.025,0.060,0.115,1}, {0.090,0.650,1.000,1}, {0.055,0.385,0.720,1} },
        source = "SHOP", requiredAddon = "CreshChat",
    },
    WOW_CLASSIC = {
        name = "WoW Classic",
        price = 400,
        note = "Bronze, parchment and gold surfaces for a classic Azeroth feel.",
        swatches = { {0.205,0.135,0.060,1}, {1.000,0.790,0.260,1}, {0.090,0.285,0.535,1} },
        source = "SHOP", requiredAddon = "CreshChat",
    },
    ZLR = {
        name = "ZLR Arena",
        price = 500,
        note = "Blackened arena-tech panels, Q3A launcher text and red-orange glow.",
        swatches = { {0.012,0.016,0.020,1}, {0.940,0.205,0.035,1}, {0.405,0.060,0.028,1} },
        source = "SHOP", requiredAddon = "CreshChat",
    },
}

local function paletteInfo(key, name, price, note, source, level, achievementKey)
    local apiInfo = _G.CreshChatAPI and _G.CreshChatAPI.GetThemeInfo and _G.CreshChatAPI.GetThemeInfo(key) or nil
    local preset = apiInfo or (CC.UI and CC.UI.THEME_PRESETS and CC.UI.THEME_PRESETS[key])
    local fallback = { {0.10,0.11,0.14,1}, {0.38,0.44,0.54,1}, {0.20,0.24,0.30,1} }
    Pass.premiumThemes[key] = {
        name = (apiInfo and apiInfo.name) or name, price = price, note = note,
        swatches = preset and { preset.panel, preset.accent, preset.outgoing } or fallback,
        source = source or "SHOP", level = level, requiredAddon = "CreshChat",
        achievementKey = achievementKey,
    }
end

-- Ten shop themes purchasable with Cresh Coins.
-- The ten Outland and endgame zone themes are reserved as Battle Pass rewards (levels 110-200).
local SHOP_THEMES = {
    {"FOR_THE_ALLIANCE", "For the Alliance", 150, "Royal blue, lion gold and bright Alliance trim."},
    {"FOR_THE_HORDE", "For the Horde", 150, "Crimson iron, war-banner red and ember highlights."},
    {"UNDEAD_FORSAKEN", "Undead Forsaken", 225, "Undercity violet, plague green and shadowed stone."},
    {"ELWYNN_FOREST", "Elwynn Forest", 250, "Warm woodland greens, trail brown and sunlit leaves."},
    {"DUROTAR", "Durotar", 275, "Dry red earth, canyon orange and Horde frontier iron."},
    {"STRANGLETHORN", "Stranglethorn Vale", 325, "Deep jungle green with treasure-gold accents."},
    {"TANARIS", "Tanaris", 350, "Sandstone panels, desert gold and weathered brass."},
    {"WINTERSPRING", "Winterspring", 400, "Frost blue, snow white and cold mountain shadows."},
    {"STORMWIND", "Stormwind City", 850, "Alliance blue, royal gold and bright city stone."},
    {"ORGRIMMAR", "Orgrimmar", 850, "Horde crimson, iron brown and fortress firelight."},
}
for _, row in ipairs(SHOP_THEMES) do
    paletteInfo(row[1], row[2], row[3], row[4], "SHOP")
    Pass.themeOrder[#Pass.themeOrder + 1] = row[1]
end

-- Twenty zone themes earned from the extended Battle Pass (levels 10-200, every 10 levels).
-- Levels 1-100: classic Azeroth and early Outland zones (exclusive to the pass).
-- Levels 110-200: Outland and endgame zones, moved from the shop to the pass.
--   Players who previously purchased these themes from the shop retain ownership.
Pass.passThemeRewards = {
    [10]  = "WESTFALL",         [20]  = "DUSKWOOD",           [30]  = "THE_BARRENS",
    [40]  = "ASHENVALE",        [50]  = "UNGORO",             [60]  = "EASTERN_PLAGUELANDS",
    [70]  = "TEROKKAR_FOREST",  [80]  = "BLADES_EDGE",        [90]  = "TEMPEST_KEEP",
    [100] = "SERPENTSHRINE",
    -- Extended pass rewards: levels 110-200
    [110] = "HELLFIRE_PENINSULA",  [120] = "ZANGARMARSH",      [130] = "NAGRAND",
    [140] = "NETHERSTORM",         [150] = "SHADOWMOON_VALLEY",[160] = "SHATTRATH",
    [170] = "SILVERMOON",          [180] = "BLACK_TEMPLE",     [190] = "SUNWELL",
    [200] = "DARK_PORTAL",
}
local PASS_THEME_NAMES = {
    WESTFALL="Westfall", DUSKWOOD="Duskwood", THE_BARRENS="The Barrens", ASHENVALE="Ashenvale",
    UNGORO="Un'Goro Crater", EASTERN_PLAGUELANDS="Eastern Plaguelands", TEROKKAR_FOREST="Terokkar Forest",
    BLADES_EDGE="Blade's Edge Mountains", TEMPEST_KEEP="Tempest Keep", SERPENTSHRINE="Serpentshrine Cavern",
    HELLFIRE_PENINSULA="Hellfire Peninsula", ZANGARMARSH="Zangarmarsh", NAGRAND="Nagrand",
    NETHERSTORM="Netherstorm", SHADOWMOON_VALLEY="Shadowmoon Valley", SHATTRATH="Shattrath City",
    SILVERMOON="Silvermoon City", BLACK_TEMPLE="Black Temple", SUNWELL="Sunwell Plateau", DARK_PORTAL="The Dark Portal",
}
for level = 10, 200, 10 do
    local key = Pass.passThemeRewards[level]
    local name = PASS_THEME_NAMES[key] or key
    paletteInfo(key, name, 0, "Exclusive Azeroth Chronicle theme unlocked at Level " .. level .. ".", "PASS", level)
    Pass.themeOrder[#Pass.themeOrder + 1] = key
end

-- Rework Phase 7: the forty-five remaining named CreshChat themes (Class,
-- Profession, Raid, Faction, Zone and Special categories in
-- CreshChat/Themes.lua) that were not already claimed by the shop or the
-- Chronicle pass above. Each one now has an explicit, stable source: a real
-- World of Warcraft achievement. Ownership is granted the moment the backing
-- achievement unlocks (see the achievementThemeRewards loop in Ensure()
-- below) -- the same "grant from source of truth" pattern passThemeRewards
-- already uses for claimed pass levels.
--
-- Faction/race and Zone/capital-city themes have no achievement content of
-- their own in this codebase (ClassAchievements.lua only covers classes, and
-- AchievementExpansion.lua's REPUTATION/EXPLORATION series are not
-- race-or-city specific), so those two buckets are assigned systematically
-- (in theme-list order, against the matching category's real achievement
-- keys) rather than by forced lore-matching that the source data can't
-- support. Every other bucket (Class capstones, Profession masters, the one
-- remaining Raid theme, and Special) maps to a thematically exact
-- achievement.
Pass.achievementThemeRewards = {
    -- Class capstones (ACH_CLASS_<TOKEN>_010, the "Legendary" tier of each
    -- class's own 15-tier series in ClassAchievements.lua).
    DRUID_GROVE   = "ACH_CLASS_DRUID_010",   HUNTER_WILD  = "ACH_CLASS_HUNTER_010",
    MAGE_ARCANE   = "ACH_CLASS_MAGE_010",    PALADIN_GOLD = "ACH_CLASS_PALADIN_010",
    PRIEST_HOLY   = "ACH_CLASS_PRIEST_010",  ROGUE_SHADOW = "ACH_CLASS_ROGUE_010",
    SHAMAN_STORM  = "ACH_CLASS_SHAMAN_010",  WARLOCK_FEL  = "ACH_CLASS_WARLOCK_010",
    WARRIOR_STEEL = "ACH_CLASS_WARRIOR_010",
    -- Professions (the Master tier of each profession's pair in
    -- AchievementExpansion.lua's PROFESSIONS series).
    ALCHEMY = "EXP_232", BLACKSMITH = "EXP_234", ENCHANTING = "EXP_236",
    ENGINEERING = "EXP_238", HERBALISM = "EXP_240", MINING = "EXP_246",
    -- Raid: the one raid theme not already claimed by the Chronicle pass.
    KARAZHAN = "EXP_177",
    -- Faction/race (systematic assignment against REPUTATION's ten Exalted
    -- tiers, plus two Honored tiers to cover the two extra race themes).
    NIGHT_ELF_MOON = "EXP_267", BLOOD_ELF_SUN = "EXP_269", DRAENEI_CRYSTAL = "EXP_271",
    ORCISH_WARSONG = "EXP_273", TAUREN_EARTH = "EXP_275",  DWARVEN_FORGE = "EXP_277",
    GNOMISH_GADGET = "EXP_279", HUMAN_LION = "EXP_281",    TROLL_VOODOO = "EXP_283",
    DARK_IRON = "EXP_285",      HIGH_ELF = "EXP_266",      GOBLIN_CARTEL = "EXP_268",
    -- Zone/capital city (systematic assignment against EXPLORATION's ZONES
    -- and STEPS series in Achievements.lua).
    TELDRASSIL = "ACH_WOW_ZONES_001",  MULGORE = "ACH_WOW_ZONES_002",     REDRIDGE = "ACH_WOW_ZONES_003",
    SILITHUS = "ACH_WOW_ZONES_004",    EVERSONG_WOODS = "ACH_WOW_ZONES_005", GHOSTLANDS = "ACH_WOW_ZONES_006",
    AZUREMYST = "ACH_WOW_ZONES_007",   BLOODMYST = "ACH_WOW_STEPS_001",  UNDERCITY = "ACH_WOW_STEPS_002",
    IRONFORGE = "ACH_WOW_STEPS_3000",  DARNASSUS = "ACH_WOW_STEPS_4000", THUNDER_BLUFF = "ACH_WOW_STEPS_003",
    EXODAR = "ACH_WOW_STEPS_6000",
    -- Special: each paired with a thematically fitting Legendary/Epic
    -- achievement (the game's ultimate legendary weapon with the game's most
    -- prestigious Meta achievement; raid- and flight-flavoured themes with
    -- raid-boss and flying-distance achievements).
    FROSTMOURNE = "META_007", MOLTEN_CORE = "EXP_210", AQ_SAND = "EXP_183", OUTLAND_SKY = "EXP_081",
}
for themeKey, achievementKey in pairs(Pass.achievementThemeRewards) do
    paletteInfo(themeKey, themeKey, 0, "Unlocked by completing a World of Warcraft achievement.", "ACHIEVEMENT", nil, achievementKey)
    Pass.themeOrder[#Pass.themeOrder + 1] = themeKey
end

function Pass:RefreshThemeMetadata()
    local chatAPI = _G.CreshChatAPI
    if not chatAPI or not chatAPI.GetThemeInfo then return false end
    local changed = false
    for _, key in ipairs(self.themeOrder or {}) do
        local info = self.premiumThemes[key]
        local chatInfo = chatAPI.GetThemeInfo(key)
        if info and chatInfo then
            info.name = chatInfo.name or info.name
            info.swatches = { chatInfo.panel, chatInfo.accent, chatInfo.outgoing }
            changed = true
        end
    end
    return changed
end

local function now()
    if type(_G.time) == "function" then return _G.time() end
    if type(_G.GetTime) == "function" then return floor(_G.GetTime()) end
    return 0
end

local function clamp(value, low, high)
    value = tonumber(value) or low
    return max(low, min(high, value))
end

local function formatNumber(value)
    local text = tostring(floor(max(0, tonumber(value) or 0)))
    local grouped = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    if grouped:sub(1, 1) == "," then grouped = grouped:sub(2) end
    return grouped
end

function Pass:Ensure()
    if not CreshCollectDB then return nil end
    CreshCollectDB.arcadeRewards = type(CreshCollectDB.arcadeRewards) == "table" and CreshCollectDB.arcadeRewards or {}
    local save = CreshCollectDB.arcadeRewards
    save.coins = floor(max(0, tonumber(save.coins) or 0))
    save.lifetimeCoins = floor(max(save.coins, tonumber(save.lifetimeCoins) or save.coins))
    save.gameCoins = floor(max(0, tonumber(save.gameCoins) or 0))
    save.activityCoins = floor(max(0, tonumber(save.activityCoins) or 0))
    save.explorationCoins = floor(max(0, tonumber(save.explorationCoins) or 0))
    save.spentCoins = floor(max(0, tonumber(save.spentCoins) or 0))
    save.passXP = floor(max(0, tonumber(save.passXP) or 0))
    save.claimed = type(save.claimed) == "table" and save.claimed or {}
    save.unlockedThemes = type(save.unlockedThemes) == "table" and save.unlockedThemes or {}
    save.themeUnlockSources = type(save.themeUnlockSources) == "table" and save.themeUnlockSources or {}
    save.recent = type(save.recent) == "table" and save.recent or {}
    save.gamesRewarded = floor(max(0, tonumber(save.gamesRewarded) or 0))
    save.milestoneGoals = type(save.milestoneGoals) == "table" and save.milestoneGoals or {}
    -- Rework Phase 6: Renown -- a non-destructive, endless rank track that
    -- starts once level 200 (GetMaxXP()) is fully reached, so continued
    -- World activity keeps paying off after the Chronicle's fixed levels
    -- run out. renownClaimed is the only new save field; Renown rank itself
    -- is a pure function of the passXP overflow past GetMaxXP(), so nothing
    -- else needs migrating.
    save.renownClaimed = type(save.renownClaimed) == "table" and save.renownClaimed or {}

    -- Ownership must only come from a purchase or a claimed Battle Pass reward.
    -- Theme preview temporarily changes ui.themePreset, so inferring ownership from
    -- the selected preset would allow a locked preview to become permanently owned.
    for level, themeKey in pairs(self.passThemeRewards or {}) do
        if save.claimed[tostring(level)] then
            save.unlockedThemes[themeKey] = true
            save.themeUnlockSources[themeKey] = save.themeUnlockSources[themeKey] or ("PASS:" .. tostring(level))
        end
    end
    -- Rework Phase 7: the forty-five achievement-gated themes above. Granted
    -- the moment the backing World achievement is unlocked -- same
    -- normalize-from-source-of-truth pattern as the loop above.
    if COL.Achievements and COL.Achievements.IsUnlocked then
        for themeKey, achievementKey in pairs(self.achievementThemeRewards or {}) do
            if COL.Achievements:IsUnlocked(achievementKey) then
                save.unlockedThemes[themeKey] = true
                save.themeUnlockSources[themeKey] = save.themeUnlockSources[themeKey] or ("ACHIEVEMENT:" .. achievementKey)
            end
        end
    end
    -- No CreshGames sync here any more: this pass no longer grants any
    -- game-owned reward (see bonusRewardLevels above), so there is nothing
    -- to keep in sync with CreshGames' card deck/Tetris theme state.
    return save
end

-- Rework Phase 6: the WALK/KILL milestone table that used to live here was
-- removed -- it duplicated the EXPLORATION "STEPS" and COMBAT "KILLS"
-- achievement series in Achievements.lua (both tracked the exact same
-- exploration.totalSteps/totalKills counters and paid coins+XP
-- independently). "Keep one canonical progression series per statistic":
-- the achievement series is now the sole source for both, and still funds
-- Chronicle XP the same way it always did, via Achievements:Unlock. Existing
-- players' already-claimed milestoneGoals stay in the save (Ensure() below
-- still normalizes the field) so nothing is lost, it just no longer grants
-- anything new.

-- Returns the next un-unlocked tier of `stat`'s canonical achievement series
-- (nil if every tier is already unlocked), plus the raw current stat value.
-- Used by the drawer's goal panel below in place of the removed milestone
-- table, so the UI has exactly one source of truth for step/kill progress.
function Pass:GetNextAchievementTier(stat)
    local Ach = COL.Achievements
    if not Ach then return nil, 0 end
    local save = Ach:Ensure()
    if not save then return nil, 0 end
    local value = Ach:GetStat(stat)
    for _, achievement in ipairs(Ach.catalog) do
        if achievement.stat == stat and not save.unlocked[achievement.key] then
            return achievement, value
        end
    end
    return nil, value
end

function Pass:GetPassPanelHeight() return 446 + ((self.maxLevel or 100) * 55) end

function Pass:IsPremiumTheme(theme)
    return self.premiumThemes[upper(tostring(theme or ""))] ~= nil
end

function Pass:GetThemeMissingAddon(theme)
    local info = self.premiumThemes[upper(tostring(theme or ""))]
    local addonName = info and info.requiredAddon or nil
    if addonName and not isProductLoaded(addonName) then return addonName end
    return nil
end

function Pass:IsThemeAvailable(theme)
    local info = self.premiumThemes[upper(tostring(theme or ""))]
    if not info then return false, nil end
    local missingAddon = self:GetThemeMissingAddon(theme)
    return missingAddon == nil, missingAddon
end

function Pass:IsThemeUnlocked(theme)
    theme = upper(tostring(theme or ""))
    if not self.premiumThemes[theme] then return true end
    local save = self:Ensure()
    return save and save.unlockedThemes[theme] == true or false
end

function Pass:GetLockedThemeCount()
    local count = 0
    for _, theme in ipairs(self.themeOrder or {}) do
        if not self:IsThemeUnlocked(theme) then count = count + 1 end
    end
    return count
end

function Pass:GetThemePanelHeight()
    return max(240, 140 + (self:GetLockedThemeCount() * 98))
end

function Pass:GetThemeInfo(theme)
    return self.premiumThemes[upper(tostring(theme or ""))]
end

function Pass:GetNextLevelCost(level)
    level = floor(clamp(level, 1, self.maxLevel))
    return 50 + ((level - 1) * 5)
end

function Pass:GetCumulativeXP(level)
    level = floor(clamp(level, 1, self.maxLevel))
    local completed = level - 1
    return completed * 50 + (5 * completed * (completed - 1)) / 2
end

function Pass:GetLevelFromXP(xp)
    xp = floor(max(0, tonumber(xp) or 0))
    -- Closed-form solution to 5k²+95k = 2·xp (k = level−1).
    -- At every level boundary the discriminant (10n+85)² is a perfect square,
    -- so the formula is exact at thresholds. The ±1 neighbour loop corrects
    -- any floating-point drift between boundaries.
    local k = floor((-95 + math.sqrt(9025 + 40 * xp)) / 10)
    local level = max(1, min(self.maxLevel, 1 + k))
    while level < self.maxLevel and xp >= self:GetCumulativeXP(level + 1) do level = level + 1 end
    while level > 1               and xp <  self:GetCumulativeXP(level)     do level = level - 1 end
    return level
end

function Pass:GetMaxXP()
    return self:GetCumulativeXP(self.maxLevel)
end

-- ---------------------------------------------------------------------------
-- Rework Phase 6: Renown. Once level 200 (GetMaxXP()) is fully reached,
-- every further AddPassXP call keeps accumulating into the same save.passXP
-- field (it already had no ceiling -- only the *displayed level* clamped at
-- maxLevel). Renown rank is a pure derived view of that overflow, so no new
-- XP-tracking field is needed; only a rank-claimed table (added in Ensure()
-- above). Renown rewards are flat, repeatable Cresh Coins only -- never a
-- theme, deck, or anything from the fixed level 1-200 reward catalog, so
-- Renown can never duplicate a fixed Chronicle reward.
-- ---------------------------------------------------------------------------
Pass.renownXPPerRank = 250
Pass.renownCoinsPerRank = 50

-- Returns rank, currentXP, neededXP, ratio -- same shape as GetProgress().
function Pass:GetRenownRank()
    local save = self:Ensure()
    if not save then return 0, 0, self.renownXPPerRank, 0 end
    local overflow = max(0, save.passXP - self:GetMaxXP())
    local rank = floor(overflow / self.renownXPPerRank)
    local current = overflow - (rank * self.renownXPPerRank)
    return rank, current, self.renownXPPerRank, clamp(current / max(1, self.renownXPPerRank), 0, 1)
end

function Pass:IsRenownRewardClaimed(rank)
    local save = self:Ensure()
    return save and save.renownClaimed[tostring(rank)] == true or false
end

function Pass:ClaimRenownReward(rank, silent)
    local save = self:Ensure()
    if not save then return false end
    rank = floor(max(1, tonumber(rank) or 1))
    local currentRank = self:GetRenownRank()
    if rank > currentRank then return false end
    local key = tostring(rank)
    if save.renownClaimed[key] then return false end
    save.renownClaimed[key] = true
    self:AddCoins(self.renownCoinsPerRank, "RENOWN")
    if not silent then
        self:RefreshDrawer()
        if CC.UI and CC.UI.ShowBattlePassToast then
            CC.UI:ShowBattlePassToast("Renown Rank " .. rank, "+" .. self.renownCoinsPerRank .. " Cresh Coins", "BATTLEPASS", "RENOWN:CLAIM:" .. rank)
        end
    end
    return true
end

function Pass:ClaimAllRenownAvailable()
    local claimed, coins = 0, 0
    local currentRank = self:GetRenownRank()
    for rank = 1, currentRank do
        if not self:IsRenownRewardClaimed(rank) then
            if self:ClaimRenownReward(rank, true) then
                claimed = claimed + 1
                coins = coins + self.renownCoinsPerRank
            end
        end
    end
    if claimed > 0 then self:RefreshDrawer() end
    return claimed, coins
end

function Pass:GetProgress()
    local save = self:Ensure()
    if not save then return 1, 0, 50, 0 end
    local level = self:GetLevelFromXP(save.passXP)
    local base = self:GetCumulativeXP(level)
    if level >= self.maxLevel then return level, 1, 1, 1 end
    local required = self:GetNextLevelCost(level)
    local current = max(0, save.passXP - base)
    return level, current, required, clamp(current / max(1, required), 0, 1)
end

function Pass:GetReward(level)
    level = floor(clamp(level, 1, self.maxLevel))
    local coins
    if level == self.maxLevel then
        coins = 1000  -- capstone: completing all 200 levels
    elseif level % 10 == 0 then
        coins = 100 + level * 2
    elseif level % 5 == 0 then
        coins = 45 + level
    else
        coins = 15 + floor((level - 1) / 5) * 5
    end
    -- Former game-reward levels keep an equivalent bonus coin payout instead
    -- of a card deck/Tetris theme -- see the comment on bonusRewardLevels.
    coins = coins + (self.bonusRewardLevels and self.bonusRewardLevels[level] or 0)
    local themeKey = self.passThemeRewards and self.passThemeRewards[level]
    local themeInfo = themeKey and self.premiumThemes[themeKey] or nil
    local themeMissingAddon
    if themeKey then local _; _, themeMissingAddon = self:IsThemeAvailable(themeKey) end
    return {
        level = level, coins = coins,
        title = self.levelNames[level] or ("Azeroth Chronicle Level " .. level),
        themeKey = themeKey,
        themeName = themeInfo and themeInfo.name or nil,
        themeRequiredAddon = themeMissingAddon,
        requiredAddonText = themeMissingAddon and upper(themeMissingAddon) or nil,
        -- F1: reward routing metadata
        sourceSystem = "WOW_BATTLE_PASS",
        sourceId     = "BATTLEPASS_LEVEL_" .. level,
        targetGame   = "GLOBAL",
    }
end

function Pass:GetRequirementRoute()
    return self.worldRequirementRoute
end

function Pass:GetRequirement(level)
    level = floor(clamp(level, 1, self.maxLevel))
    local save = self:Ensure()
    local reward = self:GetReward(level)
    local target = self:GetCumulativeXP(level)
    local current = save and save.passXP or 0
    local needed = max(0, target - current)
    local reached = current >= target
    local route = self:GetRequirementRoute()
    local detail
    if reached then
        local extras = ""
        if reward.themeName then extras = extras .. " and the " .. reward.themeName .. " theme" end
        if reward.deckName then extras = extras .. " and the " .. reward.deckName .. " card deck" end
        if reward.tetrisThemeName then extras = extras .. " and the " .. reward.tetrisThemeName .. " Tetris set" end
        detail = "Requirement complete. Unlock " .. reward.title .. " to collect " .. reward.coins .. " Cresh Coins" .. extras .. "."
    else
        detail = formatNumber(needed) .. " more Pass Points required. " .. route.hint
    end
    return {
        level = level,
        reward = reward,
        target = target,
        current = current,
        needed = needed,
        reached = reached,
        route = route,
        detail = detail,
    }
end

function Pass:SelectRequirement(level)
    level = floor(clamp(level, 1, self.maxLevel))
    self.selectedLevel = level
    if CC.UI and CC.UI.OpenGameDrawer then
        if not CC.UI.gameDrawer or not CC.UI.gameDrawer.creshOpen then CC.UI:OpenGameDrawer("BATTLEPASS")
        else CC.UI:SetGameDrawerMode("BATTLEPASS") end
        CC.UI:RefreshGameDrawer(true)
        local drawer = CC.UI.gameDrawer
        if drawer then self:ScrollToPassLevel(drawer, level) end
        local requirement = self:GetRequirement(level)
        if CC.UI.SetGameDrawerStatus then
            CC.UI:SetGameDrawerStatus(requirement.reached and ("Level " .. level .. " requirement complete - unlock the reward.")
                or ("Level " .. level .. " needs " .. formatNumber(requirement.needed) .. " more Pass Points."),
                requirement.reached and ((CC.UI.COLORS and CC.UI.COLORS.green) or nil) or ((CC.UI.COLORS and CC.UI.COLORS.quest) or nil))
        end
    end
end

function Pass:StartRequirement(level)
    local requirement = self:GetRequirement(level)
    if requirement.reached then return self:ClaimReward(level) end
    local route = requirement.route
    if route.mode == "MULTIPLAYER" then
        if CC.UI and CC.UI.SetGameDrawerMode then CC.UI:SetGameDrawerMode("MULTIPLAYER") end
        if CC.Games and CC.Games.ScanPeers then CC.Games:ScanPeers() end
        return true
    end
    if route.game and CC.SoloGames and CC.SoloGames.StartGame then
        return CC.SoloGames:StartGame(route.game)
    end
    return false
end

function Pass:HandleRewardClick(level)
    if self:IsLevelReached(level) and not self:IsRewardClaimed(level) then return self:ClaimReward(level) end
    self:SelectRequirement(level)
    return true
end

function Pass:IsLevelReached(level)
    local save = self:Ensure()
    if not save then return false end
    return save.passXP >= self:GetCumulativeXP(level)
end

function Pass:IsRewardClaimed(level)
    local save = self:Ensure()
    return save and save.claimed[tostring(level)] == true or false
end

function Pass:AddCoins(amount, source, isSimulation)
    if isSimulation == true then return 0 end
    local save = self:Ensure()
    amount = floor(max(0, tonumber(amount) or 0))
    if not save or amount <= 0 then return 0 end
    save.coins = save.coins + amount
    save.lifetimeCoins = save.lifetimeCoins + amount
    if source == "GAME" then save.gameCoins = save.gameCoins + amount
    elseif source == "ACTIVITY" then save.activityCoins = save.activityCoins + amount
    elseif source == "EXPLORATION" or source == "GOAL" then save.explorationCoins = save.explorationCoins + amount end
    if CC.UI and CC.UI.RefreshConsoleEconomy then CC.UI:RefreshConsoleEconomy() end
    return amount
end

function Pass:AddPassXP(amount, source, silent, isSimulation)
    if isSimulation == true then return 0 end
    local save = self:Ensure()
    amount = floor(max(0, tonumber(amount) or 0))
    if not save or amount <= 0 then return 0 end
    local previousLevel = self:GetLevelFromXP(save.passXP)
    local previousRenownRank = self:GetRenownRank()
    save.passXP = save.passXP + amount
    local newLevel = self:GetLevelFromXP(save.passXP)
    local newRenownRank = self:GetRenownRank()
    save.recent = { text = tostring(source or "Activity") .. " reward", xp = amount, level = newLevel, at = now() }
    if CC.UI and CC.UI.RefreshConsoleEconomy then CC.UI:RefreshConsoleEconomy() end
    if not silent then
        self:RefreshDrawer()
        if newLevel > previousLevel and CC.UI and CC.UI.ShowBattlePassToast then
            local reward = self:GetReward(newLevel)
            local detail = "+" .. amount .. " Pass Points - reward ready"
            if reward.themeName then detail = detail .. " - " .. reward.themeName .. " theme" end
            if reward.deckName then detail = detail .. " - " .. reward.deckName .. " deck" end
            if reward.tetrisThemeName then detail = detail .. " - " .. reward.tetrisThemeName .. " Tetris set" end
            CC.UI:ShowBattlePassToast("Azeroth Chronicle Level " .. newLevel, detail, "BATTLEPASS", "BP:LEVEL:" .. tostring(newLevel))
        elseif newRenownRank > previousRenownRank and CC.UI and CC.UI.ShowBattlePassToast then
            CC.UI:ShowBattlePassToast("Renown Rank " .. newRenownRank, "+" .. self.renownCoinsPerRank .. " Cresh Coins - reward ready", "BATTLEPASS", "RENOWN:" .. tostring(newRenownRank))
        end
    end
    return amount, previousLevel, newLevel
end

function Pass:ClaimReward(level, silent)
    local save = self:Ensure()
    level = floor(clamp(level, 1, self.maxLevel))
    if not save then return false end
    if not self:IsLevelReached(level) then
        local needed = max(0, self:GetCumulativeXP(level) - save.passXP)
        if not silent and CC.Print then CC:Print("Azeroth Chronicle Level " .. level .. " needs " .. formatNumber(needed) .. " more points.") end
        return false
    end
    local key = tostring(level)
    if save.claimed[key] then return false end
    local reward = self:GetReward(level)
    save.claimed[key] = true
    self:AddCoins(reward.coins, "PASS")
    if reward.themeKey then
        save.unlockedThemes[reward.themeKey] = true
        save.themeUnlockSources[reward.themeKey] = "PASS:" .. tostring(level)
        local suite = _G.CreshSuite
        if suite and suite.Publish then
            suite:Publish("CRESHCOLLECT_CHAT_THEME_UNLOCKED", { source = "CRESHCOLLECT", themeKey = reward.themeKey, unlockSource = "PASS:" .. tostring(level) })
        end
    end
    save.recent = { text = "Level " .. level .. " unlocked", coins = reward.coins, theme = reward.themeKey, at = now() }
    if not silent and CC.Print then
        local extra = ""
        if reward.themeName then extra = extra .. " + " .. reward.themeName .. " theme" end
        CC:Print("Azeroth Chronicle Level " .. level .. " unlocked: +" .. reward.coins .. " Cresh Coins" .. extra .. ".")
    end
    if not silent then
        self:RefreshDrawer()
        if CC.SoloGames and CC.SoloGames.RefreshTetrisPanels then CC.SoloGames:RefreshTetrisPanels(true) end
        if CC.UI and CC.UI.ShowBattlePassToast then
            local detail = "+" .. tostring(reward.coins or 0) .. " Cresh Coins"
            if reward.themeName then detail = detail .. " - " .. reward.themeName .. " theme unlocked" end
            if reward.deckName then detail = detail .. " - " .. reward.deckName .. " deck unlocked" end
            if reward.tetrisThemeName then detail = detail .. " - " .. reward.tetrisThemeName .. " Tetris set unlocked" end
            CC.UI:ShowBattlePassToast("Azeroth Chronicle reward unlocked", "Level " .. level .. " - " .. detail, "BATTLEPASS", "BP:CLAIM:" .. tostring(level))
        end
    end
    return true
end

function Pass:ClaimAllAvailable()
    local claimed, total = 0, 0
    for level = 1, self.maxLevel do
        if self:IsLevelReached(level) and not self:IsRewardClaimed(level) then
            local reward = self:GetReward(level)
            if self:ClaimReward(level, true) then
                claimed = claimed + 1
                total = total + reward.coins
            end
        end
    end
    if CC.Print then
        if claimed == 0 then CC:Print("No Azeroth Chronicle rewards are ready to unlock.")
        else CC:Print(claimed .. " Azeroth Chronicle rewards unlocked: +" .. formatNumber(total) .. " Cresh Coins.") end
    end
    self:RefreshDrawer()
    if claimed > 0 then
        if CC.SoloGames and CC.SoloGames.RefreshTetrisPanels then CC.SoloGames:RefreshTetrisPanels(true) end
        if CC.UI and CC.UI.ShowBattlePassToast then
            CC.UI:ShowBattlePassToast("Azeroth Chronicle rewards unlocked", tostring(claimed) .. " rewards - +" .. formatNumber(total) .. " Cresh Coins", "BATTLEPASS", "BP:CLAIMALL:" .. tostring(now()))
        end
    end
    return claimed, total
end

-- Returns claimed, total -- how many of the maxLevel reward levels have
-- actually been claimed. Pure/read-only (no side effects), so the Progress
-- Overview window can show "rewards unlocked" without recomputing claim
-- state itself.
function Pass:GetClaimedRewardCount()
    local claimed = 0
    for level = 1, self.maxLevel do
        if self:IsRewardClaimed(level) then claimed = claimed + 1 end
    end
    return claimed, self.maxLevel
end

-- Rework Phase 6 removed Pass:AwardForGame here -- it was already DORMANT
-- (no callers, explicitly deprecated in favor of GameProgression's own
-- CreshGames-side route) and awarded CreshGames-specific game results
-- (DUNGEON/FROGGER score bonuses, multiplayer doubling) into this pass,
-- which the rework's ownership rules ("remove only CreshGames-specific
-- content"; "do not fund CreshGames XP or rewards" in reverse) forbid.

function Pass:BuyTheme(theme)
    theme = upper(tostring(theme or ""))
    local info = self.premiumThemes[theme]
    local save = self:Ensure()
    if not info or not save then return false end
    local available, missingAddon = self:IsThemeAvailable(theme)
    if not available then
        if CC.Print then CC:Print(info.name .. " requires " .. tostring(missingAddon) .. " to be enabled before it can be unlocked or equipped.") end
        return false
    end
    if save.unlockedThemes[theme] then
        if CC.UI and CC.UI.ApplyThemePreset then CC.UI:ApplyThemePreset(theme) end
        self:RefreshDrawer()
        return true
    end
    if info.source == "PASS" and info.level then
        self.selectedTheme = theme
        self:SelectRequirement(info.level)
        return false
    end
    if info.source == "ACHIEVEMENT" then
        local achievement = COL.Achievements and COL.Achievements.byKey and COL.Achievements.byKey[info.achievementKey]
        if CC.Print then
            CC:Print((info.name or theme) .. " unlocks by completing the achievement: "
                .. tostring(achievement and achievement.title or info.achievementKey) .. ".")
        end
        return false
    end
    if save.coins < info.price then
        local needed = info.price - save.coins
        if CC.Print then CC:Print(info.name .. " needs " .. formatNumber(needed) .. " more Cresh Coins.") end
        return false
    end
    save.coins = save.coins - info.price
    save.spentCoins = save.spentCoins + info.price
    save.unlockedThemes[theme] = true
    save.themeUnlockSources[theme] = "SHOP"
    save.recent = { text = info.name .. " unlocked", coins = -info.price, at = now() }
    if CC.UI and CC.UI.ApplyThemePreset then CC.UI:ApplyThemePreset(theme) end
    if CC.Print then CC:Print(info.name .. " unlocked and equipped for " .. formatNumber(info.price) .. " Cresh Coins.") end
    if CC.UI and CC.UI.ShowBattlePassToast then
        CC.UI:ShowBattlePassToast("Theme unlocked", info.name .. " is now equipped", "BATTLEPASS", "BP:THEME:" .. tostring(theme))
    end
    self:RefreshDrawer()
    return true
end

function Pass:GetWalletText()
    local save = self:Ensure()
    return save and formatNumber(save.coins) or "0"
end

function Pass:GetLifetimeText()
    local save = self:Ensure()
    return save and formatNumber(save.lifetimeCoins) or "0"
end

function Pass:RefreshDrawer()
    if CC.UI and CC.UI.RefreshConsoleEconomy then CC.UI:RefreshConsoleEconomy() end
    if CC.UI and CC.UI.RefreshGameDrawer then CC.UI:RefreshGameDrawer(true) end
    -- Single centralized refresh point for every Battle Pass display surface
    -- (the CreshChat drawer panel above, the standalone window, and the
    -- Progress Overview's Battle Pass card) -- extended here rather than
    -- adding a second, parallel event hook.
    self:RefreshWindow()
    if COL.ProgressOverview and COL.ProgressOverview.RefreshWindow then COL.ProgressOverview:RefreshWindow() end
end

function Pass:OpenThemeUnlock(theme)
    theme = upper(tostring(theme or ""))
    if not self.premiumThemes[theme] then return false end
    self.selectedTheme = theme
    if CC.UI and CC.UI.OpenGameDrawer then
        CC.UI:OpenGameDrawer("THEMES")
        if CC.UI.ScrollGameDrawerToTheme then
            CC.UI:ScrollGameDrawerToTheme(theme)
            if _G.C_Timer and type(_G.C_Timer.After) == "function" then
                _G.C_Timer.After(0, function()
                    if CC.UI and CC.UI.ScrollGameDrawerToTheme then CC.UI:ScrollGameDrawerToTheme(theme) end
                end)
            end
        end
    end
    self:RefreshDrawer()
    return true
end

function Pass:ToggleThemePreview(theme)
    theme = upper(tostring(theme or ""))
    if not self.premiumThemes[theme] or not self:IsThemeAvailable(theme) or not CC.UI then return false end
    self.selectedTheme = theme
    local drawer = CC.UI.gameDrawer
    local savedScroll = drawer and drawer.scroll and drawer.scroll:GetVerticalScroll() or nil
    local previewName = CC.UI.GetThemePreviewName and CC.UI:GetThemePreviewName() or nil
    local previewing = CC.UI.IsThemePreviewActive and CC.UI:IsThemePreviewActive() and previewName == theme
    local changed = false
    if previewing then
        if CC.UI.CancelThemePreview then changed = CC.UI:CancelThemePreview(false) end
    else
        if CC.UI.PreviewThemePreset then changed = CC.UI:PreviewThemePreset(theme) end
    end
    self:RefreshDrawer()
    if savedScroll and CC.UI.SetGameDrawerScroll then
        CC.UI:SetGameDrawerScroll(savedScroll)
        if _G.C_Timer and type(_G.C_Timer.After) == "function" then
            _G.C_Timer.After(0, function()
                if CC.UI and CC.UI.SetGameDrawerScroll then CC.UI:SetGameDrawerScroll(savedScroll) end
            end)
        end
    end
    return changed
end

local function setButtonEnabled(button, enabled)
    if not button then return end
    button.creshDisabled = not enabled
    button:SetAlpha(enabled and 1 or 0.42)
    if enabled then button:Enable() else button:Disable() end
end

-- ── Virtual row pool ───────────────────────────────────────────────────────────
local ROWS_TOP   = 396   -- pixels from passPanel top to first row
local ROW_HEIGHT = 55    -- pixels per row slot (49px row + 6px gap)
local POOL_SIZE  = 14    -- recycled frames: covers viewport at all supported scales

-- Builds drawer.passLevelList — the ordered array of level numbers that pass
-- the active filter. Returns the list.
function Pass:BuildPassLevelList(drawer)
    local filter = drawer.passFilter or "ALL"
    local list = {}
    for level = 1, self.maxLevel do
        local reached = self:IsLevelReached(level)
        local claimed = self:IsRewardClaimed(level)
        local visible = filter == "ALL"
            or (filter == "READY"   and reached and not claimed)
            or (filter == "CLAIMED" and claimed)
            or (filter == "LOCKED"  and not reached)
        if visible then list[#list + 1] = level end
    end
    drawer.passLevelList = list
    return list
end

-- Writes fresh data into one recycled pool frame for the given level.
function Pass:PopulatePassRow(row, level, save, api)
    local colors       = api.colors
    local applyBackdrop = api.applyBackdrop
    local darken       = api.darken
    local setAccent    = api.setAccent

    local reward    = self:GetReward(level)
    local reached   = self:IsLevelReached(level)
    local claimed   = self:IsRewardClaimed(level)
    local selected  = (level == self.selectedLevel)
    local milestone = level % 5 == 0

    applyBackdrop(row.badge,
        milestone and darken(colors.blue, 0.32) or colors.panelRaised,
        milestone and colors.blue or colors.border)
    row.badgeText:SetText(tostring(level))
    local textColor = milestone and colors.text or colors.muted
    row.badgeText:SetTextColor(textColor[1], textColor[2], textColor[3], 1)

    row.title:SetText(reward.title .. "  ·  +" .. reward.coins .. " coins"
        .. (reward.themeName       and ("  ·  THEME: "  .. reward.themeName)       or "")
        .. (reward.deckName        and ("  ·  DECK: "   .. reward.deckName)         or "")
        .. (reward.tetrisThemeName and ("  ·  TETRIS: " .. reward.tetrisThemeName)  or "")
        .. (reward.requiredAddonText and ("  ·  REQUIRES " .. reward.requiredAddonText) or ""))

    local borderColor = selected and (colors.quest or colors.blue) or colors.border
    if claimed then
        row.detail:SetText(reward.requiredAddonText and "Claimed · pending cosmetics activate when their addons are enabled"
            or (selected and "Unlocked · selected" or "Unlocked"))
        row.button.label:SetText("OWNED")
        setButtonEnabled(row.button, false)
        applyBackdrop(row, darken(colors.green, 0.72),
            selected and (colors.quest or colors.blue) or colors.green)
    elseif reached then
        row.detail:SetText(reward.requiredAddonText and "Ready to claim · unavailable cosmetics will be banked safely"
            or (selected and "Ready to unlock · selected" or "Ready to unlock"))
        row.button.label:SetText("UNLOCK NOW")
        setButtonEnabled(row.button, true)
        if setAccent then setAccent(row.button, colors.green) end
        applyBackdrop(row, darken(colors.green, 0.82),
            selected and (colors.quest or colors.blue) or colors.green)
    else
        local need = max(0, self:GetCumulativeXP(level) - save.passXP)
        row.detail:SetText(formatNumber(need) .. " points required"
            .. (reward.requiredAddonText and (" · cosmetics require " .. reward.requiredAddonText) or "")
            .. (selected and " · selected" or ""))
        row.button.label:SetText("VIEW GOAL")
        setButtonEnabled(row.button, true)
        if setAccent then setAccent(row.button, colors.quest or colors.blue) end
        local base = milestone and darken(colors.blue, 0.62) or colors.panelSoft
        local edge = selected and (colors.quest or colors.blue)
            or (milestone and colors.blue or borderColor)
        applyBackdrop(row, base, edge)
    end
    local titleColor = reward.requiredAddonText and colors.muted or colors.text
    row.title:SetTextColor(titleColor[1], titleColor[2], titleColor[3], 1)
end

-- Positions and (conditionally) repopulates pool frames to cover the viewport.
-- forceRepopulate=true re-applies content even when the frame's assigned level
-- has not changed — needed after filter/theme/selection changes.
function Pass:UpdatePassPool(drawer, forceRepopulate)
    local list = drawer.passLevelList
    local pool = drawer.passPool
    local api  = drawer.passApi
    if not list or not pool or not api then return end

    local save = self:Ensure()
    if not save then return end

    local scrollY  = drawer.scroll and (drawer.scroll:GetVerticalScroll() or 0) or 0
    local firstIdx = max(0, floor((scrollY - ROWS_TOP) / ROW_HEIGHT) - 1)
    firstIdx = min(firstIdx, max(0, #list - POOL_SIZE))

    for poolI = 1, POOL_SIZE do
        local listIdx = firstIdx + poolI - 1
        local level   = list[listIdx + 1]
        local frame   = pool[poolI]
        if level then
            local absY = -(ROWS_TOP + listIdx * ROW_HEIGHT)
            frame:ClearAllPoints()
            frame:SetPoint("TOPLEFT",  drawer.passPanel, "TOPLEFT",  0, absY)
            frame:SetPoint("TOPRIGHT", drawer.passPanel, "TOPRIGHT", 0, absY)
            if forceRepopulate or frame.assignedLevel ~= level then
                frame.assignedLevel = level
                self:PopulatePassRow(frame, level, save, api)
            end
            frame:Show()
        else
            frame.assignedLevel = nil
            frame:Hide()
        end
    end
end

-- Scrolls the drawer so the row for the given level is centered in the viewport.
function Pass:ScrollToPassLevel(drawer, level)
    if not drawer or not drawer.passLevelList or not drawer.scroll then return end
    local targetIdx = nil
    for i, l in ipairs(drawer.passLevelList) do
        if l == level then targetIdx = i - 1; break end
    end
    if not targetIdx then return end
    local viewportH = drawer.scroll:GetHeight() or 400
    local rowY      = ROWS_TOP + targetIdx * ROW_HEIGHT
    local scrollTo  = max(0, rowY - floor(viewportH / 2) + floor(ROW_HEIGHT / 2))
    if CC.UI and CC.UI.SetGameDrawerScroll then
        CC.UI:SetGameDrawerScroll(scrollTo)
    else
        drawer.scroll:SetVerticalScroll(scrollTo)
    end
end

function Pass:BuildDrawerPanels(drawer, api)
    if not drawer or not api then return end
    self:RefreshThemeMetadata()
    if drawer.passPanel then return end
    local createButton = api.createButton
    local createFont = api.createFont
    local applyBackdrop = api.applyBackdrop
    local darken = api.darken
    local colors = api.colors
    local templateName = api.templateName

    drawer.passPanel = CreateFrame("Frame", nil, drawer.content)
    drawer.passPanel:SetPoint("TOPLEFT", drawer.content, "TOPLEFT", 0, 0)
    drawer.passPanel:SetPoint("TOPRIGHT", drawer.content, "TOPRIGHT", 0, 0)
    drawer.passPanel:SetHeight(self:GetPassPanelHeight())
    drawer.passPanel:Hide()

    local hero = CreateFrame("Frame", nil, drawer.passPanel, templateName())
    hero:SetPoint("TOPLEFT", drawer.passPanel, "TOPLEFT", 0, 0)
    hero:SetPoint("TOPRIGHT", drawer.passPanel, "TOPRIGHT", 0, 0)
    hero:SetHeight(126)
    applyBackdrop(hero, darken(colors.blue, 0.42), colors.blue)
    drawer.passHero = hero

    hero.title = createFont(hero, 16, colors.text, "LEFT")
    hero.title:SetPoint("TOPLEFT", hero, "TOPLEFT", 12, -10)
    hero.title:SetText("AZEROTH CHRONICLE")
    hero.subtitle = createFont(hero, 9, colors.muted, "LEFT")
    hero.subtitle:SetPoint("TOPLEFT", hero.title, "BOTTOMLEFT", 0, -4)
    hero.subtitle:SetText(tostring(self.maxLevel) .. " levels · explore Azeroth and earn achievements to gain Pass Points, coins and themes.")

    hero.level = createFont(hero, 24, colors.text, "LEFT")
    hero.level:SetPoint("TOPLEFT", hero, "TOPLEFT", 12, -49)
    hero.level:SetText("LEVEL 1")
    hero.wallet = createFont(hero, 10, colors.gold or colors.quest, "RIGHT")
    hero.wallet:SetPoint("TOPRIGHT", hero, "TOPRIGHT", -12, -53)
    hero.wallet:SetText("0 COINS")

    hero.progressBack = CreateFrame("Frame", nil, hero, templateName())
    hero.progressBack:SetPoint("BOTTOMLEFT", hero, "BOTTOMLEFT", 12, 16)
    hero.progressBack:SetPoint("BOTTOMRIGHT", hero, "BOTTOMRIGHT", -12, 16)
    hero.progressBack:SetHeight(20)
    applyBackdrop(hero.progressBack, colors.panel, colors.border)
    hero.progress = CreateFrame("StatusBar", nil, hero.progressBack)
    hero.progress:SetPoint("TOPLEFT", hero.progressBack, "TOPLEFT", 2, -2)
    hero.progress:SetPoint("BOTTOMRIGHT", hero.progressBack, "BOTTOMRIGHT", -2, 2)
    hero.progress:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    hero.progress:SetStatusBarColor(colors.blue[1], colors.blue[2], colors.blue[3], 0.95)
    hero.progress:SetMinMaxValues(0, 1)
    hero.progress:SetValue(0)
    hero.progressText = createFont(hero.progressBack, 9, colors.text, "CENTER")
    hero.progressText:SetAllPoints()

    drawer.passRequirement = CreateFrame("Frame", nil, drawer.passPanel, templateName())
    drawer.passRequirement:SetPoint("TOPLEFT", drawer.passPanel, "TOPLEFT", 0, -136)
    drawer.passRequirement:SetPoint("TOPRIGHT", drawer.passPanel, "TOPRIGHT", 0, -136)
    drawer.passRequirement:SetHeight(76)
    applyBackdrop(drawer.passRequirement, colors.panelSoft, colors.quest or colors.blue)
    drawer.passRequirement.title = createFont(drawer.passRequirement, 11, colors.text, "LEFT")
    drawer.passRequirement.title:SetPoint("TOPLEFT", drawer.passRequirement, "TOPLEFT", 10, -9)
    drawer.passRequirement.title:SetPoint("RIGHT", drawer.passRequirement, "RIGHT", -116, 0)
    drawer.passRequirement.detail = createFont(drawer.passRequirement, 8, colors.muted, "LEFT")
    drawer.passRequirement.detail:SetPoint("TOPLEFT", drawer.passRequirement.title, "BOTTOMLEFT", 0, -5)
    drawer.passRequirement.detail:SetPoint("BOTTOMRIGHT", drawer.passRequirement, "BOTTOMRIGHT", -116, 8)
    drawer.passRequirement.detail:SetWordWrap(true)
    drawer.passRequirement.action = createButton(drawer.passRequirement, "PLAY", 98, 29, function()
        Pass:StartRequirement(drawer.passRequirementLevel or 1)
    end)
    drawer.passRequirement.action:SetPoint("RIGHT", drawer.passRequirement, "RIGHT", -8, 0)

    drawer.goalBox = CreateFrame("Frame", nil, drawer.passPanel, templateName())
    drawer.goalBox:SetPoint("TOPLEFT", drawer.passPanel, "TOPLEFT", 0, -222)
    drawer.goalBox:SetPoint("TOPRIGHT", drawer.passPanel, "TOPRIGHT", 0, -222)
    drawer.goalBox:SetHeight(92)
    applyBackdrop(drawer.goalBox, colors.panelSoft, colors.border)
    drawer.goalBox.title = createFont(drawer.goalBox, 10, colors.text, "LEFT")
    drawer.goalBox.title:SetPoint("TOPLEFT", drawer.goalBox, "TOPLEFT", 9, -7)
    drawer.goalBox.title:SetText("EXPLORATION GOALS")
    drawer.goalBox.walk = createFont(drawer.goalBox, 8, colors.muted, "LEFT")
    drawer.goalBox.walk:SetPoint("TOPLEFT", drawer.goalBox, "TOPLEFT", 9, -27)
    drawer.goalBox.walk:SetPoint("RIGHT", drawer.goalBox, "RIGHT", -9, 0)
    drawer.goalBox.walkBar = CreateFrame("StatusBar", nil, drawer.goalBox)
    drawer.goalBox.walkBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    drawer.goalBox.walkBar:SetPoint("TOPLEFT", drawer.goalBox, "TOPLEFT", 9, -42)
    drawer.goalBox.walkBar:SetPoint("TOPRIGHT", drawer.goalBox, "TOPRIGHT", -9, -42)
    drawer.goalBox.walkBar:SetHeight(5)
    drawer.goalBox.kill = createFont(drawer.goalBox, 8, colors.muted, "LEFT")
    drawer.goalBox.kill:SetPoint("TOPLEFT", drawer.goalBox, "TOPLEFT", 9, -55)
    drawer.goalBox.kill:SetPoint("RIGHT", drawer.goalBox, "RIGHT", -9, 0)
    drawer.goalBox.killBar = CreateFrame("StatusBar", nil, drawer.goalBox)
    drawer.goalBox.killBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    drawer.goalBox.killBar:SetPoint("TOPLEFT", drawer.goalBox, "TOPLEFT", 9, -70)
    drawer.goalBox.killBar:SetPoint("TOPRIGHT", drawer.goalBox, "TOPRIGHT", -9, -70)
    drawer.goalBox.killBar:SetHeight(5)

    drawer.passFilter = drawer.passFilter or "ALL"
    drawer.passFilterBar = CreateFrame("Frame", nil, drawer.passPanel)
    drawer.passFilterBar:SetPoint("TOPLEFT", drawer.passPanel, "TOPLEFT", 0, -324)
    drawer.passFilterBar:SetPoint("TOPRIGHT", drawer.passPanel, "TOPRIGHT", 0, -324)
    drawer.passFilterBar:SetHeight(28)
    drawer.passFilterButtons = {}
    local passFilters = {
        { "ALL", "ALL", 54 }, { "READY", "READY", 64 },
        { "CLAIMED", "CLAIMED", 76 }, { "LOCKED", "LOCKED", 68 },
    }
    local previousFilter
    for _, filter in ipairs(passFilters) do
        local key, label, width = filter[1], filter[2], filter[3]
        local filterButton = createButton(drawer.passFilterBar, label, width, 24, function()
            drawer.passFilter = key
            Pass:RefreshDrawer()
            if CC.UI and CC.UI.SetGameDrawerScroll then CC.UI:SetGameDrawerScroll(0) end
        end)
        if previousFilter then filterButton:SetPoint("LEFT", previousFilter, "RIGHT", 4, 0)
        else filterButton:SetPoint("LEFT", drawer.passFilterBar, "LEFT", 0, 0) end
        drawer.passFilterButtons[key] = filterButton
        previousFilter = filterButton
    end

    drawer.passClaimAll = createButton(drawer.passPanel, "UNLOCK ALL READY", 138, 27, function() Pass:ClaimAllAvailable() end)
    drawer.passClaimAll:SetPoint("TOPRIGHT", drawer.passPanel, "TOPRIGHT", 0, -358)
    drawer.passSummary = createFont(drawer.passPanel, 9, colors.muted, "LEFT")
    drawer.passSummary:SetPoint("TOPLEFT", drawer.passPanel, "TOPLEFT", 2, -364)
    drawer.passSummary:SetPoint("RIGHT", drawer.passClaimAll, "LEFT", -8, 0)

    -- Create a small recycled pool (POOL_SIZE frames) instead of 200 static rows.
    drawer.passPool = {}
    drawer.passApi  = api
    for i = 1, POOL_SIZE do
        local row = CreateFrame("Button", nil, drawer.passPanel, templateName())
        row:SetHeight(49)
        row.assignedLevel = nil
        row.badge = CreateFrame("Frame", nil, row, templateName())
        row.badge:SetSize(38, 34)
        row.badge:SetPoint("LEFT", row, "LEFT", 7, 0)
        row.badgeText = createFont(row.badge, 11, colors.muted, "CENTER")
        row.badgeText:SetAllPoints()
        row.title = createFont(row, 10, colors.text, "LEFT")
        row.title:SetPoint("TOPLEFT", row, "TOPLEFT", 53, -8)
        row.title:SetPoint("RIGHT", row, "RIGHT", -98, 0)
        row.detail = createFont(row, 8, colors.muted, "LEFT")
        row.detail:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -3)
        row.detail:SetPoint("RIGHT", row, "RIGHT", -98, 0)
        row.button = createButton(row, "LOCKED", 82, 26, function()
            if row.assignedLevel then Pass:HandleRewardClick(row.assignedLevel) end
        end)
        row.button:SetPoint("RIGHT", row, "RIGHT", -7, 0)
        row:SetScript("OnClick", function()
            if row.assignedLevel then Pass:SelectRequirement(row.assignedLevel) end
        end)
        row:SetScript("OnEnter", function(selfRow)
            if selfRow.SetBackdropBorderColor then
                local accent = colors.quest or colors.blue
                selfRow:SetBackdropBorderColor(accent[1], accent[2], accent[3], 1)
            end
        end)
        row:SetScript("OnLeave", function() Pass:RefreshDrawer() end)
        row:Hide()
        drawer.passPool[i] = row
    end
    -- Reposition pool frames when the scroll position changes.
    drawer.scroll:SetScript("OnVerticalScroll", function()
        if drawer.mode == "BATTLEPASS" then Pass:UpdatePassPool(drawer, false) end
    end)

    drawer.themesPanel = CreateFrame("Frame", nil, drawer.content)
    drawer.themesPanel:SetPoint("TOPLEFT", drawer.content, "TOPLEFT", 0, 0)
    drawer.themesPanel:SetPoint("TOPRIGHT", drawer.content, "TOPRIGHT", 0, 0)
    drawer.themesPanel:SetHeight(self:GetThemePanelHeight())
    drawer.themesPanel:Hide()

    local themeHero = CreateFrame("Frame", nil, drawer.themesPanel, templateName())
    themeHero:SetPoint("TOPLEFT", drawer.themesPanel, "TOPLEFT", 0, 0)
    themeHero:SetPoint("TOPRIGHT", drawer.themesPanel, "TOPRIGHT", 0, 0)
    themeHero:SetHeight(112)
    applyBackdrop(themeHero, darken(colors.quest or colors.blue, 0.48), colors.quest or colors.blue)
    drawer.themeHero = themeHero
    themeHero.title = createFont(themeHero, 16, colors.text, "LEFT")
    themeHero.title:SetPoint("TOPLEFT", themeHero, "TOPLEFT", 12, -10)
    themeHero.title:SetText("UNLOCK THEMES")
    themeHero.subtitle = createFont(themeHero, 9, colors.muted, "LEFT")
    themeHero.subtitle:SetPoint("TOPLEFT", themeHero.title, "BOTTOMLEFT", 0, -4)
    themeHero.subtitle:SetText("Only themes you still need to unlock are shown. Use PREVIEW to test a palette before spending Cresh Coins or claiming its reward.")
    themeHero.wallet = createFont(themeHero, 18, colors.text, "LEFT")
    themeHero.wallet:SetPoint("BOTTOMLEFT", themeHero, "BOTTOMLEFT", 12, 13)
    themeHero.earned = createFont(themeHero, 9, colors.muted, "RIGHT")
    themeHero.earned:SetPoint("BOTTOMRIGHT", themeHero, "BOTTOMRIGHT", -12, 17)

    drawer.themeEmpty = createFont(drawer.themesPanel, 13, colors.muted, "CENTER")
    drawer.themeEmpty:SetPoint("TOPLEFT", drawer.themesPanel, "TOPLEFT", 24, -170)
    drawer.themeEmpty:SetPoint("TOPRIGHT", drawer.themesPanel, "TOPRIGHT", -24, -170)
    drawer.themeEmpty:SetHeight(70)
    drawer.themeEmpty:SetWordWrap(true)
    drawer.themeEmpty:SetText("ALL THEMES UNLOCKED\nChoose and apply your owned themes from Settings > Themes.")
    drawer.themeEmpty:Hide()

    drawer.themeRows = {}
    for index, theme in ipairs(self.themeOrder) do
        local themeKey = theme
        local info = self.premiumThemes[themeKey]
        local row = CreateFrame("Frame", nil, drawer.themesPanel, templateName())
        row:SetPoint("TOPLEFT", drawer.themesPanel, "TOPLEFT", 0, -122 - ((index - 1) * 98))
        row:SetPoint("TOPRIGHT", drawer.themesPanel, "TOPRIGHT", 0, -122 - ((index - 1) * 98))
        row:SetHeight(90)
        applyBackdrop(row, colors.panelSoft, colors.border)
        row.theme = themeKey
        row.themeIndex = index
        row.swatches = {}
        for swatchIndex = 1, 3 do
            local swatch = CreateFrame("Frame", nil, row, templateName())
            swatch:SetSize(22, 54)
            swatch:SetPoint("LEFT", row, "LEFT", 8 + ((swatchIndex - 1) * 18), 0)
            local value = info.swatches[swatchIndex]
            applyBackdrop(swatch, value, swatchIndex == 2 and value or colors.border)
            row.swatches[swatchIndex] = swatch
        end
        row.title = createFont(row, 11, colors.text, "LEFT")
        row.title:SetPoint("TOPLEFT", row, "TOPLEFT", 72, -10)
        row.title:SetText(info.name)
        row.note = createFont(row, 8, colors.muted, "LEFT")
        row.note:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -4)
        row.note:SetPoint("RIGHT", row, "RIGHT", -176, 0)
        row.note:SetHeight(32)
        row.note:SetWordWrap(true)
        row.note:SetText(info.note)
        row.price = createFont(row, 10, colors.gold or colors.quest, "LEFT")
        row.price:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 72, 10)
        row.preview = createButton(row, "PREVIEW", 82, 28, function() Pass:ToggleThemePreview(themeKey) end)
        row.preview:SetPoint("RIGHT", row, "RIGHT", -96, 0)
        row.button = createButton(row, "UNLOCK", 82, 28, function()
            Pass.selectedTheme = themeKey
            Pass:BuyTheme(themeKey)
        end)
        row.button:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        drawer.themeRows[themeKey] = row
    end
end

function Pass:RefreshDrawerPanel(drawer, api)
    local save = self:Ensure()
    if not drawer or not save or not drawer.passPanel then return end
    local colors = api.colors
    local applyBackdrop = api.applyBackdrop
    local darken = api.darken
    local setAccent = api.setAccent

    applyBackdrop(drawer.passHero, darken(colors.blue, 0.42), colors.blue)
    applyBackdrop(drawer.themeHero, darken(colors.quest or colors.blue, 0.48), colors.quest or colors.blue)
    if drawer.passHero.progress and drawer.passHero.progress.SetStatusBarColor then
        drawer.passHero.progress:SetStatusBarColor(colors.blue[1], colors.blue[2], colors.blue[3], 0.95)
    end

    local level, current, required, ratio = self:GetProgress()
    drawer.passHero.level:SetText("LEVEL " .. level .. " / " .. self.maxLevel)
    drawer.passHero.wallet:SetText(self:GetWalletText() .. " CRESH COINS")
    -- Rework Phase 6: this pass no longer grants card decks/Tetris themes at
    -- all (that split to CreshGames' own Arcade Pass back in Phase 10), so
    -- the subtitle no longer needs a CreshGames-presence branch.
    if drawer.passHero.subtitle then
        drawer.passHero.subtitle:SetText(tostring(self.maxLevel) .. " levels · explore Azeroth and earn achievements to gain Pass Points, coins and themes.")
    end
    drawer.passHero.progress:SetMinMaxValues(0, max(1, required))
    drawer.passHero.progress:SetValue(level >= self.maxLevel and required or current)
    drawer.passHero.progressText:SetText(level >= self.maxLevel and "AZEROTH CHRONICLE COMPLETE" or (formatNumber(current) .. " / " .. formatNumber(required) .. " POINTS TO LEVEL " .. (level + 1)))
    if drawer.goalBox then
        local worldOn = CC.IsFeatureEnabled and CC:IsFeatureEnabled("worldProgression")
        if worldOn == false then
            drawer.goalBox.title:SetText("EXPLORATION GOALS (MODULE OFF)")
            drawer.goalBox.walk:SetText("World Progression is disabled in Settings > Modules. Walking goals are paused.")
            drawer.goalBox.kill:SetText("Kill goals are paused until World Progression is re-enabled.")
            drawer.goalBox.walkBar:SetMinMaxValues(0,1); drawer.goalBox.walkBar:SetValue(0)
            drawer.goalBox.killBar:SetMinMaxValues(0,1); drawer.goalBox.killBar:SetValue(0)
        else
            drawer.goalBox.title:SetText("EXPLORATION GOALS")
            local walk,walkValue=self:GetNextAchievementTier("STEPS")
            local kill,killValue=self:GetNextAchievementTier("KILLS")
            if walk then
                drawer.goalBox.walk:SetText(walk.title .. " · " .. formatNumber(walkValue) .. "/" .. formatNumber(walk.goal) .. " steps · +" .. walk.coins .. " coins / +" .. walk.xp .. " XP")
                drawer.goalBox.walkBar:SetMinMaxValues(0,walk.goal); drawer.goalBox.walkBar:SetValue(math.min(walk.goal,walkValue))
            else drawer.goalBox.walk:SetText("All walking goals completed"); drawer.goalBox.walkBar:SetMinMaxValues(0,1); drawer.goalBox.walkBar:SetValue(1) end
            if kill then
                drawer.goalBox.kill:SetText(kill.title .. " · " .. formatNumber(killValue) .. "/" .. formatNumber(kill.goal) .. " kills · +" .. kill.coins .. " coins / +" .. kill.xp .. " XP")
                drawer.goalBox.killBar:SetMinMaxValues(0,kill.goal); drawer.goalBox.killBar:SetValue(math.min(kill.goal,killValue))
            else drawer.goalBox.kill:SetText("All kill goals completed"); drawer.goalBox.killBar:SetMinMaxValues(0,1); drawer.goalBox.killBar:SetValue(1) end
        end
        drawer.goalBox.walkBar:SetStatusBarColor(colors.blue[1],colors.blue[2],colors.blue[3],0.95)
        drawer.goalBox.killBar:SetStatusBarColor(colors.quest[1],colors.quest[2],colors.quest[3],0.95)
    end

    if not self.selectedLevel then
        self.selectedLevel = min(self.maxLevel, max(1, level + (self:IsRewardClaimed(level) and 1 or 0)))
    end
    local selectedRequirement = self:GetRequirement(self.selectedLevel)
    drawer.passRequirementLevel = selectedRequirement.level
    local route = selectedRequirement.route
    -- Rework Phase 6: the requirement route is always worldRequirementRoute
    -- now (no CreshGames-mode routes exist since Phase 3), so this gate must
    -- check the world-progression feature flag, not "games"/"multiplayerGames"
    -- -- checking the latter let a player with World Progression enabled but
    -- Games disabled see an incorrect "MODULE OFF" state on a requirement
    -- that has nothing to do with CreshGames.
    local worldOn = CC.IsFeatureEnabled and CC:IsFeatureEnabled("worldProgression")
    if not selectedRequirement.reached and worldOn == false then
        drawer.passRequirement.title:SetText("LEVEL " .. selectedRequirement.level .. " REQUIREMENT · MODULE OFF")
        drawer.passRequirement.detail:SetText("World Progression is disabled in Settings > Modules, so this requirement can't progress. Re-enable World Progression to continue the Azeroth Chronicle.")
        drawer.passRequirement.action.label:SetText("MODULE OFF")
        setButtonEnabled(drawer.passRequirement.action, false)
        applyBackdrop(drawer.passRequirement, darken(colors.muted, 0.78), colors.muted)
        if setAccent then setAccent(drawer.passRequirement.action, colors.muted) end
    else
        drawer.passRequirement.title:SetText("LEVEL " .. selectedRequirement.level .. " REQUIREMENT · " .. selectedRequirement.reward.title)
        drawer.passRequirement.detail:SetText(selectedRequirement.detail)
        drawer.passRequirement.action.label:SetText(selectedRequirement.reached and (self:IsRewardClaimed(selectedRequirement.level) and "VIEW COMPLETE" or "UNLOCK NOW") or route.action)
        setButtonEnabled(drawer.passRequirement.action, not (selectedRequirement.reached and self:IsRewardClaimed(selectedRequirement.level)))
        applyBackdrop(drawer.passRequirement, darken(selectedRequirement.reached and colors.green or (colors.quest or colors.blue), 0.78), selectedRequirement.reached and colors.green or (colors.quest or colors.blue))
        if setAccent then setAccent(drawer.passRequirement.action, selectedRequirement.reached and colors.green or (colors.quest or colors.blue)) end
    end

    local ready = 0
    for rewardLevel = 1, self.maxLevel do
        if self:IsLevelReached(rewardLevel) and not self:IsRewardClaimed(rewardLevel) then ready = ready + 1 end
    end
    drawer.passSummary:SetText(format("%s lifetime · %s games · %s exploration/goals · %d ready", formatNumber(save.lifetimeCoins), formatNumber(save.gameCoins), formatNumber(save.explorationCoins), ready))
    setButtonEnabled(drawer.passClaimAll, ready > 0)
    if setAccent then setAccent(drawer.passClaimAll, ready > 0 and (colors.quest or colors.blue) or colors.muted) end
    for key, filterButton in pairs(drawer.passFilterButtons or {}) do
        local active = (drawer.passFilter or "ALL") == key
        if setAccent then setAccent(filterButton, active and (colors.quest or colors.blue) or colors.border, active) end
    end

    drawer.passApi = api
    self:BuildPassLevelList(drawer)
    local filteredPassHeight = max(446, 446 + (#drawer.passLevelList * ROW_HEIGHT))
    drawer.passPanel:SetHeight(filteredPassHeight)
    if drawer.mode == "BATTLEPASS" and drawer.content then drawer.content:SetHeight(filteredPassHeight) end
    self:UpdatePassPool(drawer, true)

    drawer.themeHero.wallet:SetText(self:GetWalletText() .. " COINS AVAILABLE")
    drawer.themeHero.earned:SetText("LIFETIME " .. self:GetLifetimeText() .. "  ·  GAMES " .. formatNumber(save.gameCoins) .. "  ·  EXPLORE/GOALS " .. formatNumber(save.explorationCoins))
    local previewName = CC.UI and CC.UI.GetThemePreviewName and CC.UI:GetThemePreviewName() or nil
    local previewActive = CC.UI and CC.UI.IsThemePreviewActive and CC.UI:IsThemePreviewActive() or false
    local currentTheme = CC.db.ui and upper(tostring(CC.db.ui.themePreset or "")) or ""
    if previewActive and CC.UI and CC.UI.themePreview and CC.UI.themePreview.savedPreset then
        currentTheme = upper(tostring(CC.UI.themePreview.savedPreset or currentTheme))
    end

    local savedThemeScroll = drawer.mode == "THEMES" and drawer.scroll and (drawer.scroll:GetVerticalScroll() or 0) or nil
    local visibleIndex = 0
    for _, theme in ipairs(self.themeOrder or {}) do
        local row = drawer.themeRows and drawer.themeRows[theme]
        local info = self.premiumThemes[theme]
        local unlocked = self:IsThemeUnlocked(theme)
        if row then
            if unlocked then
                row:Hide()
                row.visibleThemeIndex = nil
            else
                visibleIndex = visibleIndex + 1
                row.visibleThemeIndex = visibleIndex
                row.themeIndex = visibleIndex
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", drawer.themesPanel, "TOPLEFT", 0, -122 - ((visibleIndex - 1) * 98))
                row:SetPoint("TOPRIGHT", drawer.themesPanel, "TOPRIGHT", 0, -122 - ((visibleIndex - 1) * 98))
                row:Show()

                local previewing = previewActive and previewName == theme
                local selected = self.selectedTheme == theme
                local available, missingAddon = self:IsThemeAvailable(theme)
                local achievementInfo = info.source == "ACHIEVEMENT" and COL.Achievements and COL.Achievements.byKey
                    and COL.Achievements.byKey[info.achievementKey] or nil
                if previewing then
                    if info.source == "PASS" and info.level then
                        row.price:SetText("PREVIEW ACTIVE · CHRONICLE LEVEL " .. tostring(info.level))
                    elseif info.source == "ACHIEVEMENT" then
                        row.price:SetText("PREVIEW ACTIVE · ACHIEVEMENT: " .. upper(tostring(achievementInfo and achievementInfo.title or info.achievementKey)))
                    else
                        row.price:SetText("PREVIEW ACTIVE · " .. formatNumber(info.price) .. " CRESH COINS")
                    end
                elseif info.source == "PASS" and info.level then
                    row.price:SetText("CHRONICLE LEVEL " .. tostring(info.level))
                elseif info.source == "ACHIEVEMENT" then
                    row.price:SetText("ACHIEVEMENT: " .. upper(tostring(achievementInfo and achievementInfo.title or info.achievementKey)))
                else
                    row.price:SetText(formatNumber(info.price) .. " CRESH COINS")
                end
                if not available then
                    row.price:SetText("REQUIRES " .. upper(tostring(missingAddon or "ADDON")))
                    row.title:SetTextColor(colors.muted[1], colors.muted[2], colors.muted[3], 1)
                    row:SetAlpha(0.55)
                    if row.preview then row.preview.label:SetText("UNAVAILABLE"); setButtonEnabled(row.preview, false) end
                    row.button.label:SetText("ADDON OFF")
                    setButtonEnabled(row.button, false)
                    applyBackdrop(row, colors.panelSoft, colors.muted)
                elseif row.preview then
                    row.title:SetTextColor(colors.text[1], colors.text[2], colors.text[3], 1)
                    row:SetAlpha(1)
                    row.preview.label:SetText(previewing and "REVERT" or "PREVIEW")
                    setButtonEnabled(row.preview, true)
                    if setAccent then setAccent(row.preview, previewing and colors.green or (colors.quest or colors.blue)) end
                end
                if available and info.source == "PASS" and info.level then
                    local reached = self:IsLevelReached(info.level)
                    row.button.label:SetText(reached and "VIEW REWARD" or "VIEW LEVEL")
                    setButtonEnabled(row.button, true)
                    if setAccent then setAccent(row.button, reached and colors.green or (colors.quest or colors.blue)) end
                    applyBackdrop(row, colors.panelSoft, (previewing or selected) and (colors.quest or colors.blue) or colors.border)
                elseif available and info.source == "ACHIEVEMENT" then
                    row.button.label:SetText("LOCKED")
                    setButtonEnabled(row.button, false)
                    if setAccent then setAccent(row.button, colors.muted) end
                    applyBackdrop(row, colors.panelSoft, (previewing or selected) and (colors.quest or colors.blue) or colors.border)
                elseif available then
                    local canBuy = save.coins >= info.price
                    row.button.label:SetText(canBuy and "UNLOCK NOW" or ("NEED " .. formatNumber(info.price - save.coins)))
                    setButtonEnabled(row.button, canBuy)
                    if setAccent then setAccent(row.button, canBuy and (colors.quest or colors.blue) or colors.muted) end
                    applyBackdrop(row, colors.panelSoft, (previewing or selected) and (colors.quest or colors.blue) or colors.border)
                end
            end
        end
    end

    if drawer.themeEmpty then drawer.themeEmpty:SetShown(visibleIndex == 0) end
    local themeHeight = max(240, 140 + (visibleIndex * 98))
    drawer.themesPanel:SetHeight(themeHeight)
    drawer.visibleLockedThemeCount = visibleIndex
    if drawer.mode == "THEMES" and drawer.content then
        drawer.content:SetHeight(max(240, themeHeight))
    end
    if self.selectedTheme and self:IsThemeUnlocked(self.selectedTheme) then
        self.selectedTheme = nil
    end
    if savedThemeScroll ~= nil and CC.UI and CC.UI.SetGameDrawerScroll then
        CC.UI:SetGameDrawerScroll(savedThemeScroll)
        if _G.C_Timer and type(_G.C_Timer.After) == "function" then
            _G.C_Timer.After(0, function()
                if CC.UI and CC.UI.SetGameDrawerScroll then CC.UI:SetGameDrawerScroll(savedThemeScroll) end
            end)
        end
    end
end

Pass.formatNumber = formatNumber

-- ============================================================
-- Standalone Battle Pass window (opened by /cc battlepass and its aliases)
-- ============================================================
-- Self-contained: uses its own local widget helpers (same convention as
-- ProgressHub.lua) instead of CreshChat's UI.lua drawer helpers, so this
-- window has no dependency on the CreshChat game drawer and never forces it
-- open. Every number/state shown below is read from the functions already
-- defined above (GetProgress, GetReward, IsLevelReached, IsRewardClaimed,
-- GetRequirement, ClaimReward, ClaimAllAvailable, BuildPassLevelList,
-- PopulatePassRow) -- nothing here recomputes a level, reward or claim
-- state independently. Rows are pooled (POOL_SIZE, reused from the drawer's
-- own constant above) rather than one frame per level, since building 200
-- static rows would be wasteful and this window is built once, not rebuilt
-- on every open.

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
    gold        = { 0.95,  0.70,  0.20,  1 },
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
        gold        = WFALLBACK.gold,
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

local function winSetAccent(button, color)
    if not button then return end
    winApplyBackdrop(button, winDarken(color, 0.55), color)
    if button.label then button.label:SetTextColor(1, 1, 1, 1) end
end

function Pass:IsWindowOpen()
    return self.window and self.window:IsShown()
end

function Pass:ToggleWindow()
    if not self:BuildWindow() then return end
    if self.window:IsShown() then self:CloseWindow() else self:OpenWindow() end
end

function Pass:OpenWindow()
    if not self:BuildWindow() then return end
    self.window:Show()
    self:RefreshWindow()
    if CC.UI and CC.UI.FocusWindow then CC.UI:FocusWindow(self.window) end
    if CC.UI and CC.UI.RefreshLauncherButtonStates then CC.UI:RefreshLauncherButtonStates() end
end

function Pass:CloseWindow()
    if self.window then self.window:Hide() end
    if CC.UI and CC.UI.RefreshLauncherButtonStates then CC.UI:RefreshLauncherButtonStates() end
end

function Pass:SelectWindowLevel(level)
    self.windowSelectedLevel = floor(clamp(level, 1, self.maxLevel))
    self:RefreshWindow()
end

function Pass:BuildWindow()
    if self.window then return self.window end
    local colors = winPalette()

    local frame = CreateFrame("Frame", "CreshCollectBattlePassFrame", UIParent, winTemplateName())
    frame:SetSize(460, 600)
    local savedPos = CC.db and CC.db.positions and CC.db.positions.battlePassWindow
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
            CC.db.positions.battlePassWindow = { point = point, relPoint = relPoint, x = floor(x or 0), y = floor(y or 0) }
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
    titleLabel:SetText("AZEROTH CHRONICLE")
    local closeBtn = CreateFrame("Button", nil, header, winTemplateName())
    closeBtn:SetSize(22, 22)
    closeBtn:SetPoint("TOPRIGHT", header, "TOPRIGHT", -4, -6)
    winApplyBackdrop(closeBtn, colors.panelRaised, colors.border)
    local closeLbl = winCreateText(closeBtn, 9, colors.muted, "CENTER")
    closeLbl:SetAllPoints()
    closeLbl:SetText("X")
    closeBtn:SetScript("OnClick", function() Pass:CloseWindow() end)

    -- Hero: level, wallet, progress bar, CreshGames notice
    local hero = CreateFrame("Frame", nil, frame, winTemplateName())
    hero:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -1)
    hero:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, -1)
    hero:SetHeight(78)
    winApplyBackdrop(hero, winDarken(colors.blue, 0.42), colors.blue)
    self.windowHero = hero
    hero.level = winCreateText(hero, 20, colors.text, "LEFT")
    hero.level:SetPoint("TOPLEFT", hero, "TOPLEFT", 12, -8)
    hero.level:SetText("LEVEL 1 / " .. self.maxLevel)
    hero.wallet = winCreateText(hero, 10, colors.gold, "RIGHT")
    hero.wallet:SetPoint("TOPRIGHT", hero, "TOPRIGHT", -12, -12)
    hero.wallet:SetText("0 COINS")
    hero.progressBack = CreateFrame("Frame", nil, hero, winTemplateName())
    hero.progressBack:SetPoint("BOTTOMLEFT", hero, "BOTTOMLEFT", 12, 26)
    hero.progressBack:SetPoint("BOTTOMRIGHT", hero, "BOTTOMRIGHT", -12, 26)
    hero.progressBack:SetHeight(18)
    winApplyBackdrop(hero.progressBack, colors.panel, colors.border)
    hero.progress = CreateFrame("StatusBar", nil, hero.progressBack)
    hero.progress:SetPoint("TOPLEFT", hero.progressBack, "TOPLEFT", 2, -2)
    hero.progress:SetPoint("BOTTOMRIGHT", hero.progressBack, "BOTTOMRIGHT", -2, 2)
    hero.progress:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    hero.progress:SetStatusBarColor(colors.blue[1], colors.blue[2], colors.blue[3], 0.95)
    hero.progress:SetMinMaxValues(0, 1)
    hero.progress:SetValue(0)
    hero.progressText = winCreateText(hero.progressBack, 9, colors.text, "CENTER")
    hero.progressText:SetAllPoints()
    hero.notice = winCreateText(hero, 8, colors.muted, "LEFT")
    hero.notice:SetPoint("BOTTOMLEFT", hero, "BOTTOMLEFT", 12, 8)
    hero.notice:SetPoint("BOTTOMRIGHT", hero, "BOTTOMRIGHT", -12, 8)
    hero.notice:SetWordWrap(true)

    -- Requirement / selected-level detail box
    local req = CreateFrame("Frame", nil, frame, winTemplateName())
    req:SetPoint("TOPLEFT", hero, "BOTTOMLEFT", 0, -1)
    req:SetPoint("TOPRIGHT", hero, "BOTTOMRIGHT", 0, -1)
    req:SetHeight(70)
    winApplyBackdrop(req, colors.panelSoft, colors.quest)
    self.windowRequirement = req
    req.title = winCreateText(req, 11, colors.text, "LEFT")
    req.title:SetPoint("TOPLEFT", req, "TOPLEFT", 10, -9)
    req.title:SetPoint("RIGHT", req, "RIGHT", -108, 0)
    req.detail = winCreateText(req, 8, colors.muted, "LEFT")
    req.detail:SetPoint("TOPLEFT", req.title, "BOTTOMLEFT", 0, -5)
    req.detail:SetPoint("BOTTOMRIGHT", req, "BOTTOMRIGHT", -108, 8)
    req.detail:SetWordWrap(true)
    req.action = winCreateButton(req, "VIEW", 92, 29, function()
        local level = Pass.windowSelectedLevel or 1
        if Pass:IsLevelReached(level) and not Pass:IsRewardClaimed(level) then
            Pass:ClaimReward(level)
        end
    end)
    req.action:SetPoint("RIGHT", req, "RIGHT", -8, 0)

    -- Filter bar + claim-all
    local filterBar = CreateFrame("Frame", nil, frame, winTemplateName())
    filterBar:SetPoint("TOPLEFT", req, "BOTTOMLEFT", 8, -8)
    filterBar:SetPoint("TOPRIGHT", req, "BOTTOMRIGHT", -8, -8)
    filterBar:SetHeight(26)
    self.windowFilterButtons = {}
    local filters = { { "ALL", "ALL", 54 }, { "READY", "READY", 64 }, { "CLAIMED", "CLAIMED", 76 }, { "LOCKED", "LOCKED", 68 } }
    local previousFilter
    for _, filterDef in ipairs(filters) do
        local key, label, width = filterDef[1], filterDef[2], filterDef[3]
        local btn = winCreateButton(filterBar, label, width, 24, function()
            Pass.windowFilter = key
            Pass:RefreshWindow()
        end)
        if previousFilter then btn:SetPoint("LEFT", previousFilter, "RIGHT", 4, 0)
        else btn:SetPoint("LEFT", filterBar, "LEFT", 0, 0) end
        self.windowFilterButtons[key] = btn
        previousFilter = btn
    end
    local claimAll = winCreateButton(filterBar, "CLAIM ALL READY", 132, 24, function() Pass:ClaimAllAvailable() end)
    claimAll:SetPoint("RIGHT", filterBar, "RIGHT", 0, 0)
    self.windowClaimAll = claimAll

    -- Scroll + pooled rows (POOL_SIZE / ROW_HEIGHT reused from the drawer's
    -- own virtualization constants above -- same row size, same pool count).
    local scroll = CreateFrame("ScrollFrame", nil, frame)
    scroll:SetPoint("TOPLEFT", filterBar, "BOTTOMLEFT", 0, -8)
    scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 8)
    scroll:EnableMouseWheel(true)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetWidth(430)
    content:SetHeight(600)
    scroll:SetScrollChild(content)
    scroll:SetScript("OnMouseWheel", function(selfScroll, delta)
        local current = selfScroll:GetVerticalScroll() or 0
        local maximum = selfScroll:GetVerticalScrollRange() or 0
        selfScroll:SetVerticalScroll(max(0, min(maximum, current - delta * 42)))
    end)
    scroll:SetScript("OnVerticalScroll", function() Pass:UpdateWindowPool(false) end)
    self.windowScroll = scroll
    self.windowContent = content

    self.windowPool = {}
    local windowApi = { colors = colors, applyBackdrop = winApplyBackdrop, darken = winDarken, setAccent = winSetAccent }
    self.windowApi = windowApi
    for i = 1, POOL_SIZE do
        local row = CreateFrame("Button", nil, content, winTemplateName())
        row:SetWidth(430)
        row:SetHeight(49)
        row.assignedLevel = nil
        row.badge = CreateFrame("Frame", nil, row, winTemplateName())
        row.badge:SetSize(38, 34)
        row.badge:SetPoint("LEFT", row, "LEFT", 7, 0)
        row.badgeText = winCreateText(row.badge, 11, colors.muted, "CENTER")
        row.badgeText:SetAllPoints()
        row.title = winCreateText(row, 10, colors.text, "LEFT")
        row.title:SetPoint("TOPLEFT", row, "TOPLEFT", 53, -8)
        row.title:SetPoint("RIGHT", row, "RIGHT", -98, 0)
        row.detail = winCreateText(row, 8, colors.muted, "LEFT")
        row.detail:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -3)
        row.detail:SetPoint("RIGHT", row, "RIGHT", -98, 0)
        row.button = winCreateButton(row, "LOCKED", 82, 26, function()
            if not row.assignedLevel then return end
            if Pass:IsLevelReached(row.assignedLevel) and not Pass:IsRewardClaimed(row.assignedLevel) then
                Pass:ClaimReward(row.assignedLevel)
            else
                Pass:SelectWindowLevel(row.assignedLevel)
            end
        end)
        row.button:SetPoint("RIGHT", row, "RIGHT", -7, 0)
        row:SetScript("OnClick", function()
            if row.assignedLevel then Pass:SelectWindowLevel(row.assignedLevel) end
        end)
        row:Hide()
        self.windowPool[i] = row
    end

    self.windowFilter = self.windowFilter or "ALL"
    return frame
end

function Pass:UpdateWindowPool(forceRepopulate)
    local list = self.windowLevelList
    local pool = self.windowPool
    local api = self.windowApi
    if not list or not pool or not api then return end
    local save = self:Ensure()
    if not save then return end
    local scrollY = self.windowScroll and (self.windowScroll:GetVerticalScroll() or 0) or 0
    local firstIdx = max(0, floor(scrollY / ROW_HEIGHT))
    firstIdx = min(firstIdx, max(0, #list - POOL_SIZE))
    for poolI = 1, POOL_SIZE do
        local listIdx = firstIdx + poolI - 1
        local level = list[listIdx + 1]
        local rowFrame = pool[poolI]
        if level then
            local absY = -(listIdx * ROW_HEIGHT)
            rowFrame:ClearAllPoints()
            rowFrame:SetPoint("TOPLEFT", self.windowContent, "TOPLEFT", 0, absY)
            rowFrame:SetPoint("TOPRIGHT", self.windowContent, "TOPRIGHT", 0, absY)
            if forceRepopulate or rowFrame.assignedLevel ~= level then
                rowFrame.assignedLevel = level
                self:PopulatePassRow(rowFrame, level, save, api)
            end
            rowFrame:Show()
        else
            rowFrame.assignedLevel = nil
            rowFrame:Hide()
        end
    end
end

function Pass:RefreshWindow()
    if not self.window or not self.window:IsShown() then return end
    local save = self:Ensure()
    if not save then return end
    local colors = winPalette()

    local level, current, required = self:GetProgress()
    self.windowHero.level:SetText("LEVEL " .. level .. " / " .. self.maxLevel)
    self.windowHero.wallet:SetText(self:GetWalletText() .. " CRESH COINS")
    self.windowHero.progress:SetMinMaxValues(0, max(1, required))
    self.windowHero.progress:SetValue(level >= self.maxLevel and required or current)
    self.windowHero.progressText:SetText(level >= self.maxLevel and "AZEROTH CHRONICLE COMPLETE"
        or (formatNumber(current) .. " / " .. formatNumber(required) .. " POINTS TO LEVEL " .. (level + 1)))
    -- Rework Phase 6: this pass only grants chat themes now (card decks/
    -- Tetris themes moved to CreshGames' own Arcade Pass back in Phase 10),
    -- so only a missing CreshChat is ever relevant here.
    local missing = {}
    if not isProductLoaded("CreshChat") then missing[#missing + 1] = "chat themes require CreshChat" end
    self.windowHero.notice:SetText(#missing > 0 and (table.concat(missing, " · ") .. ". Claims are banked until those addons are enabled.") or "")

    if not self.windowSelectedLevel then
        self.windowSelectedLevel = min(self.maxLevel, max(1, level + (self:IsRewardClaimed(level) and 1 or 0)))
    end
    local requirement = self:GetRequirement(self.windowSelectedLevel)
    self.windowRequirement.title:SetText("LEVEL " .. requirement.level .. " REQUIREMENT · " .. requirement.reward.title)
    self.windowRequirement.detail:SetText(requirement.detail)
    local alreadyClaimed = self:IsRewardClaimed(requirement.level)
    self.windowRequirement.action.label:SetText(requirement.reached and (alreadyClaimed and "CLAIMED" or "UNLOCK NOW") or "IN PROGRESS")
    setButtonEnabled(self.windowRequirement.action, requirement.reached and not alreadyClaimed)
    winApplyBackdrop(self.windowRequirement, winDarken(requirement.reached and colors.green or colors.quest, 0.78),
        requirement.reached and colors.green or colors.quest)

    local ready = 0
    for rewardLevel = 1, self.maxLevel do
        if self:IsLevelReached(rewardLevel) and not self:IsRewardClaimed(rewardLevel) then ready = ready + 1 end
    end
    setButtonEnabled(self.windowClaimAll, ready > 0)
    for key, btn in pairs(self.windowFilterButtons or {}) do
        winSetAccent(btn, (self.windowFilter or "ALL") == key and colors.quest or colors.panelRaised)
    end

    self.windowLevelList = self:BuildPassLevelList({ passFilter = self.windowFilter or "ALL" })
    self.windowContent:SetHeight(max(1, #self.windowLevelList * ROW_HEIGHT))
    self:UpdateWindowPool(true)
end
