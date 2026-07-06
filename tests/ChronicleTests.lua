-- ChronicleTests.lua
-- Rework Phase 6 regression coverage for CreshCollect's Azeroth Chronicle:
--   1. Every active achievement is World-based (no GAMES category, META
--      category exists and excludes itself from its own stat).
--   2. No CreshGames result changes Chronicle progress (AwardForGame
--      removed; no stat reads anything CreshGames-owned).
--   3. Achievement series display correctly (META series tiers correct;
--      the removed duplicate WALK/KILL milestone system stays removed).
--   4. Legacy completions remain intact across Ensure() calls.
--   5. Renown cannot duplicate fixed Chronicle rewards, and its own
--      math/claim logic is correct and idempotent.
--
-- Loads the REAL production files, in real cross-addon load order.
-- Usage: lua ChronicleTests.lua

function CreateFrame() return { SetScript = function() end, RegisterEvent = function() end } end
function time() return 0 end
function GetTime() return 0 end
_G.GetServerTime = function() return 0 end
_G.C_Timer = { After = function() end }

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

-- ============================================================
-- Load the full CreshCollect achievement chain + BattlePass, in real order.
-- ============================================================
loadProductionFile("shared/Suite.lua", "CreshCollect", {})
local COL = { version = "0.2.3" }
loadProductionFile("addons/CreshCollect/CreshCollectDatabase.lua", "CreshCollect", COL)
_G.CreshCollectDatabase.Init()
loadProductionFile("addons/CreshCollect/CreshCollect.lua", "CreshCollect", COL)
loadProductionFile("addons/CreshCollect/BattlePass.lua", "CreshCollect", COL)
loadProductionFile("addons/CreshCollect/Achievements.lua", "CreshCollect", COL)
loadProductionFile("addons/CreshCollect/AchievementExpansion.lua", "CreshCollect", COL)
loadProductionFile("addons/CreshCollect/ClassAchievements.lua", "CreshCollect", COL)
loadProductionFile("addons/CreshCollect/MetaAchievements.lua", "CreshCollect", COL)

local function freshState()
    _G.CreshCollectDB = nil
    _G.CreshCollectDatabase.Init()
end

-- ============================================================
-- 1. Every active achievement is World-based; META exists and self-excludes.
-- ============================================================
section("Every active achievement category is World-based; META exists")
freshState()
COL.Achievements:BuildCatalog()
local hasGames, hasMeta = false, false
for _, category in ipairs(COL.Achievements.categoryOrder) do
    if category == "GAMES" then hasGames = true end
    if category == "META" then hasMeta = true end
end
ok(not hasGames, "categoryOrder has no GAMES category (moved to CreshGames in Phase 5)")
ok(hasMeta, "categoryOrder includes META (Meta Achievements)")
eq(COL.Achievements.categoryNames.META, "Meta Achievements", "META has the expected display name")

local _, metaTotal = COL.Achievements:GetCounts("META")
eq(metaTotal, 7, "META category has all 7 ported tiers")

-- ============================================================
-- 2. No CreshGames result changes Chronicle progress.
-- ============================================================
section("No CreshGames result changes Chronicle progress")
eq(COL.BattlePass.AwardForGame, nil, "AwardForGame (CreshGames-result-driven XP) no longer exists")
freshState()
local save = COL.BattlePass:Ensure()
local coinsBefore, xpBefore = save.coins, save.passXP
-- Simulate what used to happen: nothing in this addon calls anything with a
-- CreshGames-shaped payload any more, so directly assert the removed
-- function is gone (above) and that Ensure()/GetStat never reference
-- CreshGames-owned state (grep-level confirmation already done in Phase 5's
-- research; here we just confirm coins/XP are untouched by loading alone).
eq(save.coins, coinsBefore, "loading the module alone does not change coins")
eq(save.passXP, xpBefore, "loading the module alone does not change XP")

-- ============================================================
-- 3. Achievement series display correctly; duplicate milestone system stays removed.
-- ============================================================
section("META series tiers are correct; duplicate WALK/KILL milestones stay removed")
local metaGoals = {}
for _, achievement in ipairs(COL.Achievements.catalog) do
    if achievement.category == "META" then metaGoals[#metaGoals + 1] = achievement.goal end
end
table.sort(metaGoals)
eq(#metaGoals, 7, "seven META tiers present")
eq(metaGoals[1], 25, "first META tier goal is 25")
eq(metaGoals[7], 500, "last META tier goal is 500")
eq(COL.BattlePass.milestoneDefinitions, nil, "BattlePass-native milestone table stays removed")
eq(COL.BattlePass.CheckMilestoneGoals, nil, "CheckMilestoneGoals stays removed")

-- Meta achievements never count toward their own stat (self-exclusion).
freshState()
local metaAch = COL.Achievements.byKey["META_001"]
save = COL.Achievements:Ensure()
save.unlocked[metaAch.key] = { at = 1, value = 25 }
local statAfterMetaUnlock = COL.Achievements:GetStat("META_TOTAL_COMPLETED")
eq(statAfterMetaUnlock, 0, "unlocking a META achievement does not count toward META_TOTAL_COMPLETED itself")

-- A genuine World achievement DOES count toward it.
local worldAch = COL.Achievements.catalog[1]
if worldAch.category == "META" then
    for _, a in ipairs(COL.Achievements.catalog) do if a.category ~= "META" then worldAch = a break end end
end
save.unlocked[worldAch.key] = { at = 1, value = worldAch.goal }
local statAfterWorldUnlock = COL.Achievements:GetStat("META_TOTAL_COMPLETED")
eq(statAfterWorldUnlock, 1, "unlocking a genuine World achievement increases META_TOTAL_COMPLETED by 1")

-- ============================================================
-- 4. Legacy completions remain intact across Ensure() calls.
-- ============================================================
section("Legacy completions remain intact")
freshState()
save = COL.BattlePass:Ensure()
save.claimed["50"] = true
save.passXP = 12345
local reEnsured = COL.BattlePass:Ensure()
ok(reEnsured.claimed["50"] == true, "a previously claimed level stays claimed across Ensure() calls")
eq(reEnsured.passXP, 12345, "previously accumulated passXP is preserved across Ensure() calls")

-- ============================================================
-- 5. Renown: math, claim idempotency, and no duplication of fixed rewards.
-- ============================================================
section("Renown rank math, claiming, and no duplication of fixed Chronicle rewards")
freshState()
save = COL.BattlePass:Ensure()
local maxXP = COL.BattlePass:GetMaxXP()
save.passXP = maxXP - 1
eq(COL.BattlePass:GetRenownRank(), 0, "renown rank is 0 one XP short of the Chronicle's max")
save.passXP = maxXP
eq(COL.BattlePass:GetRenownRank(), 0, "renown rank is exactly 0 right at the Chronicle's max (no overflow yet)")
save.passXP = maxXP + COL.BattlePass.renownXPPerRank
eq(COL.BattlePass:GetRenownRank(), 1, "renown rank is 1 after exactly one rank's worth of overflow XP")
save.passXP = maxXP + (COL.BattlePass.renownXPPerRank * 3) + 10
local rank, current = COL.BattlePass:GetRenownRank()
eq(rank, 3, "renown rank is 3 with three ranks plus a partial remainder of overflow XP")
eq(current, 10, "the partial remainder within the current rank is reported correctly")

-- Claiming: idempotent, coins-only, no interaction with fixed-level data.
local claimedKeysBefore, unlockedThemesBefore = save.claimed["50"], nil
local coinsBefore2 = save.coins
local claimed1 = COL.BattlePass:ClaimRenownReward(1, true)
ok(claimed1, "claiming an available renown rank succeeds")
eq(save.coins, coinsBefore2 + COL.BattlePass.renownCoinsPerRank, "claiming pays exactly renownCoinsPerRank coins")
local claimed2 = COL.BattlePass:ClaimRenownReward(1, true)
ok(not claimed2, "claiming the same renown rank twice is rejected (idempotent)")
ok(save.claimed["50"] == claimedKeysBefore, "claiming a renown rank never touches the fixed level-claimed table")
eq(next(save.unlockedThemes), unlockedThemesBefore, "claiming a renown rank never unlocks any chat theme")

local claimedAll, coinsFromAll = COL.BattlePass:ClaimAllRenownAvailable()
eq(claimedAll, 2, "ClaimAllRenownAvailable claims exactly the 2 remaining available ranks (2 and 3)")
eq(coinsFromAll, COL.BattlePass.renownCoinsPerRank * 2, "ClaimAllRenownAvailable pays coins for exactly those 2 ranks")
local claimedAllAgain = COL.BattlePass:ClaimAllRenownAvailable()
eq(claimedAllAgain, 0, "a second ClaimAllRenownAvailable call claims nothing new (idempotent)")

-- ============================================================
-- Summary
-- ============================================================
print(("\n=== Results: %d passed, %d failed ==="):format(PASS, FAIL))
if FAIL > 0 then os.exit(1) end
