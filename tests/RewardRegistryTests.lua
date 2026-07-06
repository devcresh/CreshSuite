-- RewardRegistryTests.lua
-- Rework Phase 2 regression coverage for the new data-driven reward
-- registries (GamesRewardRegistry.lua, CollectRewardRegistry.lua) and the
-- three fixes made while building them:
--   1. The starter-deck-voucher fix (CardDecks:GrantDeckOrVoucher) -- a
--      randomly assigned starter deck must never make an Arcade Pass deck
--      reward silently do nothing.
--   2. The Dungeon Dwellers buff-schedule data table produces byte-identical
--      output to the if/elseif branching it replaced, for every level 1-100.
--   3. Dungeon/Tetris pass coin rewards and in-dungeon coin pickups now pay
--      into CG.BattlePass, never CC.BattlePass (CreshCollect's pass).
--
-- Loads the REAL production files, in real cross-addon load order.
-- Usage: lua RewardRegistryTests.lua

function CreateFrame() return { SetScript = function() end, RegisterEvent = function() end } end
function time() return 0 end
function GetTime() return 0 end
_G.C_Timer = { After = function() end }
_G.hooksecurefunc = function() end
_G.UnitGUID = function() return "Player-0-00000001" end
_G.UnitName = function() return "TestChar" end
_G.GetRealmName = function() return "TestRealm" end

local PASS, FAIL = 0, 0
local _section = ""
local function section(name) _section = name; print(("\n[%s]"):format(name)) end
local function pass(msg) PASS = PASS + 1; print(("  PASS  %s"):format(msg)) end
local function fail(msg) FAIL = FAIL + 1; print(("  FAIL  %s  [in: %s]"):format(msg, _section)) end
local function ok(cond, msg) if cond then pass(msg) else fail(msg) end end
local function eq(a, b, msg)
    if a == b then pass(msg)
    else fail(("%s  (expected %q, got %q)"):format(msg, tostring(b), tostring(a))) end
end

-- loadfile() chokes on the UTF-8 BOM some production files carry.
local function loadProductionFile(path, ...)
    local f = assert(io.open(path, "rb"))
    local src = f:read("*a")
    f:close()
    if src:sub(1, 3) == "\239\187\191" then src = src:sub(4) end
    local chunk = assert(loadstring(src, "@" .. path))
    return chunk(...)
end

-- ============================================================
-- Load the real production files, in real cross-addon load order
-- ============================================================
loadProductionFile("shared/Suite.lua", "CreshGames", {})

local CG = { version = "0.2.3" }
loadProductionFile("addons/CreshGames/CreshGames.lua", "CreshGames", CG)
loadProductionFile("addons/CreshGames/CardDeckLibrary.lua", "CreshGames", CG)
loadProductionFile("addons/CreshGames/CardDecks.lua", "CreshGames", CG)
loadProductionFile("addons/CreshGames/DungeonCrawlerContent.lua", "CreshGames", CG)
loadProductionFile("addons/CreshGames/TetrisThemes.lua", "CreshGames", CG)
loadProductionFile("addons/CreshGames/GamesBattlePass.lua", "CreshGames", CG)
loadProductionFile("addons/CreshGames/DungeonDwellersProgression.lua", "CreshGames", CG)
loadProductionFile("addons/CreshGames/GamesRewardRegistry.lua", "CreshGames", CG)

local COL = { version = "0.2.3" }
loadProductionFile("addons/CreshCollect/CreshCollectDatabase.lua", "CreshCollect", COL)
_G.CreshCollectDatabase.Init()
loadProductionFile("addons/CreshCollect/CreshCollect.lua", "CreshCollect", COL)
loadProductionFile("addons/CreshCollect/BattlePass.lua", "CreshCollect", COL)
loadProductionFile("addons/CreshCollect/CollectRewardRegistry.lua", "CreshCollect", COL)

if not CG.RewardRegistry or not COL.RewardRegistry then
    print("FATAL: RewardRegistry not found after loading production files")
    os.exit(2)
end

local function freshState()
    _G.CreshGamesDB = { cardDecks = {}, battlePass = {} }
    _G.CreshCollectDB = nil
    _G.CreshCollectDatabase.Init()
end

-- ============================================================
-- 1. Uniqueness: every registry's ids and unlockKeys are unique within it.
-- ============================================================
section("Every registry entry has a unique id and unlockKey")
local function checkUniqueness(list, label)
    local ids, keys = {}, {}
    local dupIds, dupKeys = 0, 0
    for _, entry in ipairs(list) do
        if ids[entry.id] then dupIds = dupIds + 1 end
        ids[entry.id] = true
        if entry.unlockKey then
            if keys[entry.unlockKey] then dupKeys = dupKeys + 1 end
            keys[entry.unlockKey] = true
        end
    end
    eq(dupIds, 0, label .. ": no duplicate ids (" .. #list .. " entries)")
    eq(dupKeys, 0, label .. ": no duplicate unlockKeys")
end
checkUniqueness(CG.RewardRegistry.arcadeRewards, "arcadeRewards")
checkUniqueness(CG.RewardRegistry.tetrisMasteryRewards, "tetrisMasteryRewards")
checkUniqueness(CG.RewardRegistry.dungeonMasteryRewards, "dungeonMasteryRewards")
checkUniqueness(CG.RewardRegistry.cardDeckCatalog, "cardDeckCatalog")
checkUniqueness(COL.RewardRegistry.chronicleRewards, "chronicleRewards")
checkUniqueness(COL.RewardRegistry.chatThemeAchievementRewards, "chatThemeAchievementRewards")
checkUniqueness(COL.RewardRegistry.shopThemeRewards, "shopThemeRewards")

-- ============================================================
-- 2. Registry counts match the Phase 0 baseline (sanity that generation
--    covered every entry in the source tables, not a subset).
-- ============================================================
section("Registry counts match known catalog sizes")
-- 9 pass levels grant a reward; levels 28 and 38 each grant BOTH a deck and a
-- Tetris theme, so the registry (one row per unlockKey) has 9 + 2 = 11 rows:
-- 6 CARD_DECK rows (one per premium deck) + 5 TETRIS_THEME rows.
eq(#CG.RewardRegistry.arcadeRewards, 11, "arcadeRewards has one row per unlockKey (6 decks + 5 tetris themes)")
eq(#CG.RewardRegistry.tetrisMasteryRewards, 100, "tetrisMasteryRewards covers all 50 themes + 50 backgrounds")
eq(#CG.RewardRegistry.cardDeckCatalog, 7, "cardDeckCatalog covers all 7 decks (1 default + 6 premium)")
eq(#COL.RewardRegistry.shopThemeRewards, 15, "shopThemeRewards covers all 15 shop-sourced themes (5 original + 10 zone/faction)")
eq(#COL.RewardRegistry.chronicleRewards, 29, "chronicleRewards covers 9 bonus-coin milestones + 20 chat zone themes")
eq(#COL.RewardRegistry.chatThemeAchievementRewards, 45, "chatThemeAchievementRewards covers all 45 Phase 7 achievement-gated themes")

-- ============================================================
-- 3. Rule: no placeholder Dungeon armour is exposed as a live reward.
-- ============================================================
section("Placeholder Dungeon armour (Druid/Shaman) is flagged, not silently live")
local placeholderCount, liveCount = 0, 0
for _, entry in ipairs(CG.RewardRegistry.dungeonMasteryRewards) do
    if entry.type == "DUNGEON_ARMOUR" then
        if entry.placeholder then placeholderCount = placeholderCount + 1 else liveCount = liveCount + 1 end
    end
end
eq(placeholderCount, 10, "exactly the 10 Druid/Shaman tiers are flagged placeholder")
eq(liveCount, 40, "exactly the 40 live-art tiers are not flagged placeholder")

-- ============================================================
-- 4. Starter-deck-voucher fix: whichever deck the RNG assigns as the
--    player's starter, claiming every Arcade Pass deck-reward level must
--    still end with the player owning all 6 premium decks.
-- ============================================================
section("Claiming every Arcade Pass deck reward always yields all 6 premium decks, regardless of starter")
for _, starterDeck in ipairs(CG.CardDecks.premiumOrder) do
    freshState()
    CG.CardDecks:Ensure()
    CreshGamesDB.cardDecks.starterDeck = starterDeck
    CreshGamesDB.cardDecks.unlocked = { Classic_8Bit = true, [starterDeck] = true }
    CreshGamesDB.cardDecks.unlockSources = { Classic_8Bit = "DEFAULT", [starterDeck] = "RANDOM_STARTER" }

    for level = 1, CG.BattlePass.maxLevel do
        local reward = CG.BattlePass.gameRewardCatalog[level]
        if reward and reward.deckKey then
            CG.BattlePass:Ensure().xp = CG.BattlePass:GetCumulativeXP(level)
            CG.BattlePass:ClaimReward(level, true)
        end
    end

    local allOwned = true
    for _, deckKey in ipairs(CG.CardDecks.premiumOrder) do
        if not CreshGamesDB.cardDecks.unlocked[deckKey] then allOwned = false end
    end
    ok(allOwned, "starter=" .. starterDeck .. ": all 6 premium decks owned after claiming every deck-reward level")
end

-- ============================================================
-- 5. Dungeon buff-schedule refactor: byte-identical output to the original
--    if/elseif branching, replicated here as a fixed oracle, for every level.
-- ============================================================
section("Dungeon buff schedule (data table) matches the original branching for every level 1-100")
local function oldGetBuffs(level)
    local buffs = {}
    local function add(key, value) buffs[#buffs + 1] = key .. ":" .. value end
    local cycle = level % 20
    if cycle == 5 then add("maxHP", 1) end
    if cycle == 10 then add("minionPower", 1) end
    if cycle == 15 then add("regenRoom", 1) end
    if cycle == 0 then add("attack", 1) end
    if level == 25 or level == 50 or level == 75 or level == 100 then add("bossDamage", 1) end
    if level == 40 or level == 80 then add("extraDieChance", 5) end
    if level == 50 or level == 100 then add("coinBonus", 5) end
    if level == 60 or level == 100 then add("regenTurn", 1) end
    table.sort(buffs)
    return table.concat(buffs, ",")
end
local mismatches = 0
for level = 1, 100 do
    local reward = CG.DungeonDwellersPass:GetReward(level)
    local newBuffs = {}
    for _, buff in ipairs(reward.buffs) do newBuffs[#newBuffs + 1] = buff.key .. ":" .. buff.value end
    table.sort(newBuffs)
    if table.concat(newBuffs, ",") ~= oldGetBuffs(level) then mismatches = mismatches + 1 end
end
eq(mismatches, 0, "all 100 levels produce identical buffs under the new data-driven schedule")

-- ============================================================
-- 6. Ownership-boundary fixes: CreshGames-originated coins land in
--    CG.BattlePass, never CC.BattlePass (a stand-in for CreshCollect's pass).
-- ============================================================
section("Tetris Pass, Dungeon Pass and in-dungeon coin rewards pay into CG.BattlePass, not CC.BattlePass")
freshState()
_G.CreshChat = { BattlePass = { AddCoins = function() error("must not be called: CC.BattlePass is CreshCollect's pass") end } }

CG.Tetris:Ensure()
CreshGamesDB.soloGames.tetris.passXP = CG.Tetris:GetPassCumulativeXP(10)
local okTetris = pcall(function() CG.Tetris:ClaimPassReward(10, true) end)
ok(okTetris, "Tetris:ClaimPassReward(10) does not touch CC.BattlePass")

CG.DungeonDwellersPass:Ensure()
local ddSave = CG.DungeonDwellersPass:Ensure()
ddSave.xp = CG.DungeonDwellersPass:GetCumulativeXP(5)
local okDungeon = pcall(function() CG.DungeonDwellersPass:ClaimReward(5, true) end)
ok(okDungeon, "DungeonDwellersPass:ClaimReward(5) does not touch CC.BattlePass")

local gamesCoinsBefore = CG.BattlePass:Ensure().coins
ok(gamesCoinsBefore > 0, "CG.BattlePass actually received the coins from both claims above")

_G.CreshChat = nil

-- ============================================================
-- Summary
-- ============================================================
print(("\n=== Results: %d passed, %d failed ==="):format(PASS, FAIL))
if FAIL > 0 then os.exit(1) end
