-- ThemeAchievementTests.lua
-- Rework Phase 7 regression coverage for CreshChat theme sourcing:
--   1. Every one of the 45 achievement-gated themes maps to a real,
--      distinct achievement key, with no collision against the themes
--      already claimed by the shop or the Chronicle pass.
--   2. CreshCollect's BattlePass grants ownership the moment the backing
--      achievement unlocks, and refuses to sell an achievement-gated theme
--      for coins even at price 0.
--   3. CollectRewardRegistry's chatThemeAchievementRewards registry is
--      populated (no longer an empty Phase-7 placeholder) and agrees with
--      BattlePass's own data.
--   4. CreshChat's public ChatAPI.IsThemeAvailable/SyncThemeEntitlements
--      correctly distinguish the twenty always-free UI.lua presets from
--      every gated theme, using only the local entitlement cache.
--   5. The four capital-city guild themes that had no unlock-key mapping
--      (and were silently always-unlocked) now have one.
--
-- Loads the REAL production files, in real cross-addon load order.
-- Usage: lua ThemeAchievementTests.lua

function CreateFrame() return { SetScript = function() end, RegisterEvent = function() end, RegisterForDrag = function() end } end
function time() return 0 end
function GetTime() return 0 end
_G.GetServerTime = function() return 0 end
_G.C_Timer = { After = function() end }
_G.hooksecurefunc = function() end
_G.UIParent = { GetWidth = function() return 1920 end, GetHeight = function() return 1080 end }
_G.GetAddOnMetadata = function() return nil end
_G.SlashCmdList = {}

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

local function loadProductionFile(path, ...)
    local f = assert(io.open(path, "rb"))
    local src = f:read("*a")
    f:close()
    if src:sub(1, 3) == "\239\187\191" then src = src:sub(4) end
    local chunk = assert(loadstring(src, "@" .. path))
    return chunk(...)
end

local function readFile(path)
    local f = assert(io.open(path, "rb"))
    local src = f:read("*a")
    f:close()
    return src
end

-- ============================================================
-- Load the full CreshCollect achievement + BattlePass + registry chain.
-- ============================================================
loadProductionFile("shared/Suite.lua", "CreshCollect", {})
local COL = { version = "0.2.3" }
loadProductionFile("addons/CreshCollect/CreshCollectDatabase.lua", "CreshCollect", COL)
_G.CreshCollectDatabase.Init()
loadProductionFile("addons/CreshCollect/CreshCollect.lua", "CreshCollect", COL)
loadProductionFile("addons/CreshCollect/BattlePass.lua", "CreshCollect", COL)
loadProductionFile("addons/CreshCollect/CollectRewardRegistry.lua", "CreshCollect", COL)
loadProductionFile("addons/CreshCollect/Achievements.lua", "CreshCollect", COL)
loadProductionFile("addons/CreshCollect/AchievementExpansion.lua", "CreshCollect", COL)
loadProductionFile("addons/CreshCollect/ClassAchievements.lua", "CreshCollect", COL)
loadProductionFile("addons/CreshCollect/MetaAchievements.lua", "CreshCollect", COL)
COL.Achievements:BuildCatalog()

local function freshState()
    _G.CreshCollectDB = nil
    _G.CreshCollectDatabase.Init()
end

-- ============================================================
-- 1. All 45 achievement-gated themes are real, distinct and non-colliding.
-- ============================================================
section("Forty-five achievement-gated themes: distinct, real, non-colliding")

local rewardCount = 0
for _ in pairs(COL.BattlePass.achievementThemeRewards) do rewardCount = rewardCount + 1 end
eq(rewardCount, 45, "achievementThemeRewards has exactly 45 entries")

local seenAchievements, duplicateAchievement = {}, false
for themeKey, achievementKey in pairs(COL.BattlePass.achievementThemeRewards) do
    if seenAchievements[achievementKey] then duplicateAchievement = achievementKey end
    seenAchievements[achievementKey] = themeKey
end
ok(not duplicateAchievement, "no achievement key is reused across two different themes")

local missingAchievement = nil
for themeKey, achievementKey in pairs(COL.BattlePass.achievementThemeRewards) do
    if not COL.Achievements.byKey[achievementKey] then missingAchievement = themeKey .. " -> " .. achievementKey end
end
ok(not missingAchievement, "every referenced achievement key exists in the real catalog (" .. tostring(missingAchievement) .. ")")

local claimedByShopOrPass, collision = {}, nil
for _, row in ipairs({ "FOR_THE_ALLIANCE", "FOR_THE_HORDE", "UNDEAD_FORSAKEN", "ELWYNN_FOREST", "DUROTAR",
                       "STRANGLETHORN", "TANARIS", "WINTERSPRING", "STORMWIND", "ORGRIMMAR" }) do
    claimedByShopOrPass[row] = true
end
for _, themeKey in pairs(COL.BattlePass.passThemeRewards) do claimedByShopOrPass[themeKey] = true end
for themeKey in pairs(COL.BattlePass.achievementThemeRewards) do
    if claimedByShopOrPass[themeKey] then collision = themeKey end
end
ok(not collision, "no achievement-gated theme was already claimed by the shop or the Chronicle pass (" .. tostring(collision) .. ")")

local premiumThemeCount = 0
for _ in pairs(COL.BattlePass.premiumThemes) do premiumThemeCount = premiumThemeCount + 1 end
eq(premiumThemeCount, 80, "premiumThemes totals 80 (5 static + 10 shop + 20 pass + 45 achievement)")

-- ============================================================
-- 2. Ensure() grants ownership from the achievement catalog; BuyTheme
--    refuses to sell an achievement-gated theme.
-- ============================================================
section("Ensure() grants achievement-gated themes; BuyTheme refuses to sell them")
freshState()
local passSave = COL.BattlePass:Ensure()
ok(not passSave.unlockedThemes.KARAZHAN, "KARAZHAN starts locked")

local karazhanAchievement = COL.Achievements.byKey["EXP_177"]
local achSave = COL.Achievements:Ensure()
achSave.unlocked[karazhanAchievement.key] = { at = 1, value = karazhanAchievement.goal }
passSave = COL.BattlePass:Ensure()
ok(passSave.unlockedThemes.KARAZHAN == true, "KARAZHAN unlocks once EXP_177 is unlocked")
eq(passSave.themeUnlockSources.KARAZHAN, "ACHIEVEMENT:EXP_177", "source is recorded as ACHIEVEMENT:EXP_177")

freshState()
passSave = COL.BattlePass:Ensure()
passSave.coins = 999999
local bought = COL.BattlePass:BuyTheme("KARAZHAN")
ok(not bought, "BuyTheme refuses an achievement-gated theme even with plenty of coins")
ok(not passSave.unlockedThemes.KARAZHAN, "KARAZHAN remains locked after the refused purchase")
eq(passSave.coins, 999999, "no coins were spent on the refused purchase")

-- ============================================================
-- 3. CollectRewardRegistry.chatThemeAchievementRewards is populated and
--    agrees with BattlePass.
-- ============================================================
section("CollectRewardRegistry.chatThemeAchievementRewards is populated")
eq(#COL.RewardRegistry.chatThemeAchievementRewards, 45, "registry has exactly 45 chat-theme achievement rewards")
local registryMissing = nil
for _, entry in ipairs(COL.RewardRegistry.chatThemeAchievementRewards) do
    local expected = COL.BattlePass.achievementThemeRewards[entry.unlockKey]
    if entry.requiredAchievement ~= expected then registryMissing = entry.unlockKey end
end
ok(not registryMissing, "every registry entry's requiredAchievement matches BattlePass's achievementThemeRewards (" .. tostring(registryMissing) .. ")")

-- ============================================================
-- 4. CreshChat's public API: free UI.lua presets vs. entitlement-gated themes.
-- ============================================================
section("ChatAPI.IsThemeAvailable / SyncThemeEntitlements")
local CCTable = {}
loadProductionFile("addons/CreshChat/Core.lua", "CreshChat", CCTable)
loadProductionFile("addons/CreshChat/Themes.lua", "CreshChat", CCTable)
loadProductionFile("addons/CreshChat/UI.lua", "CreshChat", CCTable)
local ChatAPI = _G.CreshChatAPI
_G.CreshChatDB = { themeEntitlements = {} }

ok(ChatAPI.IsThemeAvailable("CRESH_MINIMAL") == true, "a free UI.lua preset is available even with an empty entitlement cache")
ok(ChatAPI.IsThemeAvailable("MIDNIGHT") == true, "every one of the twenty free presets is available (spot check: MIDNIGHT)")
ok(ChatAPI.IsThemeAvailable("UBUNTU") == false, "a SHOP-gated UI.lua preset (not one of the twenty free ones) requires an entitlement")
ok(ChatAPI.IsThemeAvailable("KARAZHAN") == false, "an achievement-gated theme is unavailable with an empty entitlement cache")
ok(ChatAPI.IsThemeAvailable("BOGUS_THEME_KEY") == false, "an undefined theme key is never available")

ChatAPI.SyncThemeEntitlements({ "KARAZHAN" })
ok(ChatAPI.IsThemeAvailable("KARAZHAN") == true, "KARAZHAN becomes available once synced into the entitlement cache")
ok(ChatAPI.IsThemeAvailable("DRUID_GROVE") == false, "a different gated theme that was never synced stays unavailable")

local addedAgain = ChatAPI.SyncThemeEntitlements({ "KARAZHAN" })
eq(addedAgain, 0, "re-syncing an already-cached entitlement adds nothing new (idempotent)")

-- ============================================================
-- 5. The four previously-unmapped guild themes now have an unlock key.
-- ============================================================
section("Guild theme unlock-key gap is fixed")
local uiSource = readFile("addons/CreshChat/UI.lua")
for _, guildKey in ipairs({ "UNDERCITY_GUILD", "IRONFORGE_GUILD", "DARNASSUS_GUILD", "THUNDER_BLUFF_GUILD" }) do
    ok(uiSource:find(guildKey .. ' = "', 1, true) ~= nil, guildKey .. " has an entry in GUILD_THEME_UNLOCK_KEYS")
end

-- ============================================================
-- Summary
-- ============================================================
print(("\n=== Results: %d passed, %d failed ==="):format(PASS, FAIL))
if FAIL > 0 then os.exit(1) end
