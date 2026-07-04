-- DatabaseMigrationTests.lua
-- Lua 5.1 unit tests for CreshGames/Database.lua and CreshCollect/Database.lua.
-- Uses anonymised fixture data only (no real player SavedVariables).
-- Usage: lua DatabaseMigrationTests.lua <path-to-Games-DB> <path-to-Collect-DB>

-- ============================================================
-- WoW API stubs
-- ============================================================

local _frames = {}

function CreateFrame(_, name)
    local f = { _name=name, _events={}, _scripts={} }
    function f:RegisterEvent(e) self._events[e] = true end
    function f:SetScript(hook, fn) self._scripts[hook] = fn end
    function f:Fire(event, ...)
        local fn = self._scripts["OnEvent"]
        if fn then fn(self, event, ...) end
    end
    _frames[name or #_frames + 1] = f
    return f
end

local _fakeTime = 1000000
function time() return _fakeTime end

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

local function ok(cond, msg)  if cond then pass(msg) else fail(msg) end end
local function eq(a, b, msg)
    if a == b then pass(msg)
    else fail(("%s  (expected %q, got %q)"):format(msg, tostring(b), tostring(a))) end
end

-- ============================================================
-- Helpers to reset state between tests
-- ============================================================

local gamesDBPath   = (arg and arg[1]) or "addons/CreshGames/CreshGamesDatabase.lua"
local collectDBPath = (arg and arg[2]) or "addons/CreshCollect/CreshCollectDatabase.lua"

local function resetState()
    _G.CreshGamesDB     = nil
    _G.CreshCollectDB   = nil
    _G.CreshChatDB      = nil
    _G.CreshGamesDatabase  = nil
    _G.CreshCollectDatabase = nil
    _frames = {}
end

local function loadGamesDB()
    dofile(gamesDBPath)
    return _frames["CreshGamesDatabaseFrame"]
end

local function loadCollectDB()
    dofile(collectDBPath)
    return _frames["CreshCollectDatabaseFrame"]
end

local function fireAddonLoaded(frame, addonName)
    if frame then frame:Fire("ADDON_LOADED", addonName) end
end

-- ============================================================
-- Anonymised fixtures
-- ============================================================

-- Fixture: fresh CreshChatDB (no game data) — simulates a new install
local FIXTURE_FRESH = {
    version = 9,
    -- no soloGames, arcadeRewards, gameProgression, etc.
}

-- Fixture: legacy CreshChatDB (root-level progression, no accountProgression)
-- All player names and values are fictional.
local FIXTURE_LEGACY = {
    version = 50,
    soloGames = {
        frogger  = { unlocked=1, bestLevel=7, highScore=3200, games=44 },
        chess    = { wins=12, losses=8, draws=2, games=22, level=5, bestLevel=5 },
        tetris   = {
            wins=5, losses=3, games=8, highScore=18000, bestLines=42, totalLines=200,
            unlockedThemes={ CLASSIC_BLOCKS=true, DARK_MAGIC=true },
            themeUnlockSources={ CLASSIC_BLOCKS="DEFAULT", DARK_MAGIC="REWARD" },
            selectedTheme="DARK_MAGIC",
            unlockedBackgrounds={}, backgroundUnlockSources={}, selectedBackground="",
        },
        dungeon  = {
            runs=15, bestLevel=8, kills=320, bosses=22,
            unlockedArmour={ IRON_PLATE=true, VOID_MANTLE=true },
            equippedArmour={}, class="WARRIOR", highScore=4400,
        },
    },
    arcadeRewards = {
        coins=280, lifetimeCoins=1150, gameCoins=900, activityCoins=250,
        spentCoins=870, passXP=420,
        unlockedThemes={ NEON_ARCADE=true },
    },
    gameProgression = {
        games = {},
        exploration = { totalSteps=18000, rewardedStepBlocks=17, newZones=5 },
        achievements = {
            unlocked = {
                ACH_WOW_STEPS_001 = { at=940000, value=1000, sourceId="ACH_WOW_STEPS_001" },
                ACH_DD_KILLS_001   = { at=950000, value=25,   sourceId="ACH_DD_KILLS_001" },
            },
        },
    },
}

-- Fixture: modern CreshChatDB with accountProgression (schema 70+)
-- accountProgression has higher values than root — must be preferred.
local FIXTURE_MODERN = {
    version = 79,
    -- Root-level aliases still present for backward compatibility.
    soloGames = {
        chess = { wins=3, losses=2, draws=0, games=5, level=3, bestLevel=3 },
    },
    arcadeRewards = { coins=50, lifetimeCoins=200 },
    -- accountProgression is authoritative.
    accountProgression = {
        migratedSchema = 78,
        soloGames = {
            frogger  = { unlocked=1, bestLevel=12, highScore=9900, games=88 },
            chess    = { wins=20, losses=10, draws=3, games=33, level=7, bestLevel=7 },
            tetris   = {
                wins=10, losses=4, games=14, highScore=55000, bestLines=120, totalLines=680,
                unlockedThemes={
                    CLASSIC_BLOCKS=true, DARK_MAGIC=true, ARCANE_FLOW=true,
                },
                themeUnlockSources={
                    CLASSIC_BLOCKS="DEFAULT", DARK_MAGIC="REWARD", ARCANE_FLOW="PURCHASE",
                },
                selectedTheme="ARCANE_FLOW",
                unlockedBackgrounds={ STARFIELD=true },
                backgroundUnlockSources={ STARFIELD="REWARD" },
                selectedBackground="STARFIELD",
            },
            dungeon  = {
                runs=40, bestLevel=16, kills=2100, bosses=95,
                unlockedArmour={ IRON_PLATE=true, VOID_MANTLE=true, SHADOW_WRAP=true },
                equippedArmour={ chest="SHADOW_WRAP" }, class="ROGUE", highScore=22000,
            },
        },
        arcadeRewards = {
            coins=730, lifetimeCoins=3600, gameCoins=2800, activityCoins=800,
            spentCoins=2870, passXP=1450,
            unlockedThemes={ NEON_ARCADE=true, CRYSTAL_SKY=true },
            themeUnlockSources={ NEON_ARCADE="REWARD", CRYSTAL_SKY="PURCHASE" },
        },
        gameProgression = {
            games = { DUNGEON_DWELLER = { plays=40, wins=40 } },
            exploration = { totalSteps=62000, rewardedStepBlocks=60, newZones=18 },
            achievements = {
                unlocked = {
                    ACH_WOW_STEPS_001 = { at=900000, value=1000, sourceId="ACH_WOW_STEPS_001" },
                    ACH_WOW_STEPS_002 = { at=910000, value=2000, sourceId="ACH_WOW_STEPS_002" },
                    ACH_DD_KILLS_001  = { at=920000, value=50,   sourceId="ACH_DD_KILLS_001"  },
                    ACH_DD_KILLS_002  = { at=930000, value=100,  sourceId="ACH_DD_KILLS_002"  },
                },
                progress = {
                    ACH_WOW_STEPS_003 = { value=3700, lastAt=980000 },
                },
            },
        },
        gameHistory      = { { game="CHESS", result="WIN", at=970000 } },
        gameLeaderboards = {},
        multiplayerStats = {},
    },
}

-- ============================================================
-- 1. CreshGamesDB - Fresh install (no CreshChatDB)
-- ============================================================
section("GamesDB: fresh install (no CreshChatDB)")

resetState()
local gFrame = loadGamesDB()
fireAddonLoaded(gFrame, "CreshGames")

ok(type(CreshGamesDB) == "table",          "CreshGamesDB exists after fresh init")
eq(CreshGamesDB.version, 1,               "version = 1")
ok(type(CreshGamesDB.soloGames) == "table","soloGames table present")
ok(type(CreshGamesDB.arcadeRewards) == "table", "arcadeRewards table present")
ok(type(CreshGamesDB.gameProgression) == "table", "gameProgression table present")
eq(CreshGamesDB.soloGames.frogger.bestLevel, 0, "frogger.bestLevel defaults to 0")
eq(CreshGamesDB.arcadeRewards.coins, 0,   "arcadeRewards.coins defaults to 0")

local m1 = CreshGamesDB._migration.v1
ok(m1 ~= nil and m1.done,                 "v1 migration marked done")
eq(m1.sourceDB, "none",                   "sourceDB = none (no CreshChatDB)")
eq(m1.at, 1000000,                        "at timestamp recorded")

-- ============================================================
-- 2. CreshGamesDB - Legacy CreshChatDB (no accountProgression)
-- ============================================================
section("GamesDB: legacy CreshChatDB (no accountProgression)")

resetState()
_G.CreshChatDB = FIXTURE_LEGACY
local gFrame2 = loadGamesDB()
fireAddonLoaded(gFrame2, "CreshGames")

ok(CreshGamesDB._migration.v1.done, "v1 migration done")
eq(CreshGamesDB._migration.v1.sourceDB, "CreshChatDB", "sourceDB = CreshChatDB")
eq(CreshGamesDB._migration.v1.usedAccountProgression, false, "fell back to root (no accountProgression)")
eq(CreshGamesDB.soloGames.frogger.bestLevel, 7,   "frogger.bestLevel = 7 (from legacy root)")
eq(CreshGamesDB.soloGames.frogger.highScore, 3200, "frogger.highScore = 3200")
eq(CreshGamesDB.soloGames.chess.wins, 12,          "chess.wins = 12")
eq(CreshGamesDB.arcadeRewards.coins, 280,          "arcadeRewards.coins = 280")
eq(CreshGamesDB.arcadeRewards.lifetimeCoins, 1150, "arcadeRewards.lifetimeCoins = 1150")
ok(CreshGamesDB.soloGames.tetris.unlockedThemes.DARK_MAGIC == true,
    "tetris DARK_MAGIC theme carried over")
eq(CreshGamesDB.soloGames.tetris.selectedTheme, "DARK_MAGIC",
    "selectedTheme=DARK_MAGIC preserved from legacy source")
ok(CreshGamesDB.soloGames.dungeon.unlockedArmour.IRON_PLATE == true,
    "dungeon IRON_PLATE armour carried over")
eq(CreshGamesDB.gameProgression.exploration.totalSteps, 18000,
    "exploration.totalSteps = 18000")

-- ============================================================
-- 3. CreshGamesDB - Modern CreshChatDB (with accountProgression)
-- ============================================================
section("GamesDB: modern CreshChatDB (accountProgression takes priority)")

resetState()
_G.CreshChatDB = FIXTURE_MODERN
local gFrame3 = loadGamesDB()
fireAddonLoaded(gFrame3, "CreshGames")

ok(CreshGamesDB._migration.v1.done, "v1 migration done")
eq(CreshGamesDB._migration.v1.usedAccountProgression, true,
    "accountProgression was preferred")
eq(CreshGamesDB._migration.v1.sourceSchema, 78,
    "sourceSchema = 78 (from accountProgression.migratedSchema)")

-- accountProgression values must win over root-level aliases
eq(CreshGamesDB.soloGames.chess.wins, 20,
    "chess.wins = 20 (accountProgression), NOT 3 (root)")
eq(CreshGamesDB.soloGames.frogger.bestLevel, 12,
    "frogger.bestLevel = 12 (from accountProgression)")
eq(CreshGamesDB.arcadeRewards.coins, 730,
    "arcadeRewards.coins = 730 (accountProgression), NOT 50 (root)")
eq(CreshGamesDB.arcadeRewards.lifetimeCoins, 3600,
    "arcadeRewards.lifetimeCoins = 3600")
ok(CreshGamesDB.soloGames.tetris.unlockedThemes.ARCANE_FLOW == true,
    "ARCANE_FLOW theme present")
ok(CreshGamesDB.soloGames.tetris.unlockedBackgrounds.STARFIELD == true,
    "STARFIELD background carried over")
eq(CreshGamesDB.soloGames.tetris.selectedTheme, "ARCANE_FLOW",
    "selectedTheme = ARCANE_FLOW (valid non-default selection preserved)")
eq(CreshGamesDB.soloGames.dungeon.class, "ROGUE",
    "dungeon class = ROGUE preserved")
eq(CreshGamesDB.gameProgression.exploration.totalSteps, 62000,
    "exploration.totalSteps = 62000")

-- ============================================================
-- 4. CreshGamesDB - Idempotency
-- ============================================================
section("GamesDB: idempotency")

resetState()
_G.CreshChatDB = FIXTURE_MODERN
local gFrame4 = loadGamesDB()
fireAddonLoaded(gFrame4, "CreshGames")

local coinsAfterFirst = CreshGamesDB.arcadeRewards.coins
CreshGamesDB.arcadeRewards.coins = 9999  -- simulate player earning coins
CreshGamesDB._migration.v1.done = true    -- already done

-- Reload the module (simulate second login)
_G.CreshGamesDatabase = nil
_frames = {}
local gFrame4b = loadGamesDB()
fireAddonLoaded(gFrame4b, "CreshGames")

eq(CreshGamesDB.arcadeRewards.coins, 9999,
    "coins not overwritten on second load (idempotent)")
ok(CreshGamesDB._migration.v1.done, "v1.done still true after second load")

-- ============================================================
-- 5. CreshGamesDB - Max values for numeric records
-- ============================================================
section("GamesDB: importProgressionValue max rule")

resetState()
-- Pre-populate CreshGamesDB with higher values than the import source.
_G.CreshGamesDB = { version=1, soloGames={ chess={ wins=50, losses=2 } }, _migration={} }
_G.CreshChatDB  = FIXTURE_MODERN
_G.CreshGamesDatabase = nil
_frames = {}
local gFrame5 = loadGamesDB()
-- Fire the event to run migration; it should not have run yet (fresh _migration)
fireAddonLoaded(gFrame5, "CreshGames")

ok(CreshGamesDB.soloGames.chess.wins >= 50,
    "chess.wins stays at max (existing 50 >= import 20)")
eq(CreshGamesDB.soloGames.chess.wins, 50,
    "chess.wins = 50 (existing value is higher, preserved)")

-- ============================================================
-- 6. CreshCollectDB - Fresh install
-- ============================================================
section("CollectDB: fresh install (no CreshChatDB)")

resetState()
local cFrame = loadCollectDB()
fireAddonLoaded(cFrame, "CreshCollect")

ok(type(CreshCollectDB) == "table",               "CreshCollectDB exists")
eq(CreshCollectDB.version, 2,                     "version = 2 (schema 2)")
ok(type(CreshCollectDB.achievements) == "table",  "achievements table present")
ok(type(CreshCollectDB.collections) == "table",   "collections table present")
ok(type(CreshCollectDB.arcadeRewards) == "table", "arcadeRewards table present")
ok(type(CreshCollectDB.gameProgression) == "table","gameProgression table present")
ok(type(CreshCollectDB.ddAchievements) == "table","ddAchievements table present")
ok(type(CreshCollectDB.achievements.unlocked) == "table", "achievements.unlocked table")
ok(type(CreshCollectDB.collections.themes) == "table",    "collections.themes table")

local cm1 = CreshCollectDB._migration.v1
ok(cm1.done,             "v1 migration marked done")
eq(cm1.sourceDB, "none", "sourceDB = none (no CreshChatDB)")
local cm2 = CreshCollectDB._migration.v2
ok(cm2.done,             "v2 migration marked done (no source)")

-- ============================================================
-- 7. CreshCollectDB - Legacy CreshChatDB import
-- ============================================================
section("CollectDB: legacy CreshChatDB import")

resetState()
_G.CreshChatDB = FIXTURE_LEGACY
local cFrame2 = loadCollectDB()
fireAddonLoaded(cFrame2, "CreshCollect")

ok(CreshCollectDB._migration.v1.done, "v1 done")
eq(CreshCollectDB._migration.v1.usedAccountProgression, false,
    "fell back to root (no accountProgression)")

local unlocked = CreshCollectDB.achievements.unlocked
ok(type(unlocked) == "table", "achievements.unlocked is a table")
ok(unlocked.ACH_WOW_STEPS_001 ~= nil, "ACH_WOW_STEPS_001 carried over")
eq(unlocked.ACH_WOW_STEPS_001.at, 940000, "unlock timestamp correct")
ok(unlocked.ACH_DD_KILLS_001 ~= nil, "ACH_DD_KILLS_001 carried over")

-- Themes: union of tetris + arcade
ok(CreshCollectDB.collections.themes.CLASSIC_BLOCKS == true, "CLASSIC_BLOCKS in themes")
ok(CreshCollectDB.collections.themes.DARK_MAGIC == true,     "DARK_MAGIC in themes")
ok(CreshCollectDB.collections.themes.NEON_ARCADE == true,    "NEON_ARCADE in themes (from arcadeRewards)")

-- Armour
ok(CreshCollectDB.collections.dungeonArmour.IRON_PLATE == true,  "IRON_PLATE armour")
ok(CreshCollectDB.collections.dungeonArmour.VOID_MANTLE == true, "VOID_MANTLE armour")

-- Backgrounds
-- FIXTURE_LEGACY has no unlockedBackgrounds in tetris
ok(type(CreshCollectDB.collections.backgrounds) == "table", "backgrounds table exists")

-- v2 migration: arcadeRewards and gameProgression from legacy root
eq(CreshCollectDB.arcadeRewards.coins, 280,
    "arcadeRewards.coins = 280 (v2 from legacy root)")
eq(CreshCollectDB.arcadeRewards.passXP, 420,
    "arcadeRewards.passXP = 420 (v2 import)")
eq(CreshCollectDB.gameProgression.exploration.totalSteps, 18000,
    "gameProgression.exploration.totalSteps = 18000 (v2 import)")

-- ============================================================
-- 8. CreshCollectDB - Modern (accountProgression preferred)
-- ============================================================
section("CollectDB: modern CreshChatDB (accountProgression)")

resetState()
_G.CreshChatDB = FIXTURE_MODERN
local cFrame3 = loadCollectDB()
fireAddonLoaded(cFrame3, "CreshCollect")

ok(CreshCollectDB._migration.v1.done, "v1 done")
eq(CreshCollectDB._migration.v1.usedAccountProgression, true,
    "accountProgression was used")
eq(CreshCollectDB._migration.v1.sourceSchema, 78, "sourceSchema = 78")

local ul2 = CreshCollectDB.achievements.unlocked
ok(ul2.ACH_WOW_STEPS_001 ~= nil, "ACH_WOW_STEPS_001 present")
ok(ul2.ACH_WOW_STEPS_002 ~= nil, "ACH_WOW_STEPS_002 present")
ok(ul2.ACH_DD_KILLS_002  ~= nil, "ACH_DD_KILLS_002 present")

local pr2 = CreshCollectDB.achievements.progress
ok(type(pr2) == "table" and pr2.ACH_WOW_STEPS_003 ~= nil,
    "achievement progress ACH_WOW_STEPS_003 imported")
eq(pr2.ACH_WOW_STEPS_003.value, 3700, "progress value = 3700")

-- Themes: union of tetris + arcade (all three theme sources)
ok(CreshCollectDB.collections.themes.CLASSIC_BLOCKS == true, "CLASSIC_BLOCKS in themes")
ok(CreshCollectDB.collections.themes.DARK_MAGIC == true,     "DARK_MAGIC in themes")
ok(CreshCollectDB.collections.themes.ARCANE_FLOW == true,    "ARCANE_FLOW in themes (tetris)")
ok(CreshCollectDB.collections.themes.NEON_ARCADE == true,    "NEON_ARCADE in themes (arcade)")
ok(CreshCollectDB.collections.themes.CRYSTAL_SKY == true,    "CRYSTAL_SKY in themes (arcade)")

-- Backgrounds
ok(CreshCollectDB.collections.backgrounds.STARFIELD == true, "STARFIELD background")

-- Armour
ok(CreshCollectDB.collections.dungeonArmour.SHADOW_WRAP == true, "SHADOW_WRAP armour")

-- v2 migration: arcadeRewards and gameProgression from accountProgression
eq(CreshCollectDB.arcadeRewards.coins, 730,
    "arcadeRewards.coins = 730 (v2 from accountProgression)")
eq(CreshCollectDB.arcadeRewards.passXP, 1450,
    "arcadeRewards.passXP = 1450 (v2 import)")
ok(CreshCollectDB.arcadeRewards.unlockedThemes.NEON_ARCADE == true,
    "arcadeRewards unlockedThemes.NEON_ARCADE (v2 import)")
eq(CreshCollectDB.gameProgression.exploration.totalSteps, 62000,
    "gameProgression.exploration.totalSteps = 62000 (v2 import)")
eq(CreshCollectDB.gameProgression.exploration.newZones, 18,
    "gameProgression.exploration.newZones = 18 (v2 import)")
local cm2_8 = CreshCollectDB._migration.v2
ok(cm2_8 ~= nil and cm2_8.done, "v2 migration done")

-- ============================================================
-- 9. CreshCollectDB - Union of collections (no deletions)
-- ============================================================
section("CollectDB: union collections (no deletion)")

resetState()
-- Pre-populate with an extra theme the source does not know about.
_G.CreshCollectDB = {
    version=1,
    achievements={ unlocked={}, progress={} },
    collections={ themes={ LEGACY_THEME=true }, backgrounds={}, dungeonArmour={}, cosmetics={} },
    _migration={},
}
_G.CreshChatDB = FIXTURE_MODERN
_G.CreshCollectDatabase = nil
_frames = {}
local cFrame4 = loadCollectDB()
fireAddonLoaded(cFrame4, "CreshCollect")

ok(CreshCollectDB.collections.themes.LEGACY_THEME == true,  "LEGACY_THEME not deleted")
ok(CreshCollectDB.collections.themes.ARCANE_FLOW  == true,  "ARCANE_FLOW added from import")

-- ============================================================
-- 10. CreshCollectDB - Idempotency
-- ============================================================
section("CollectDB: idempotency")

resetState()
_G.CreshChatDB = FIXTURE_MODERN
local cFrame5 = loadCollectDB()
fireAddonLoaded(cFrame5, "CreshCollect")

local countBefore = 0
for _ in pairs(CreshCollectDB.achievements.unlocked) do countBefore = countBefore + 1 end
CreshCollectDB.achievements.unlocked.FAKE_NEW = { at=999999, value=1 }

-- Reload
_G.CreshCollectDatabase = nil
_frames = {}
local cFrame5b = loadCollectDB()
fireAddonLoaded(cFrame5b, "CreshCollect")

ok(CreshCollectDB.achievements.unlocked.FAKE_NEW ~= nil,
    "manually added unlock not removed on second load")
ok(CreshCollectDB._migration.v1.done, "v1.done still true after second load")

-- ============================================================
-- Summary
-- ============================================================
print(("\n=== Results: %d passed, %d failed ==="):format(PASS, FAIL))
if FAIL > 0 then os.exit(1) end
