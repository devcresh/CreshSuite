-- BattlePassCardDeckRecursionTests.lua
-- Lua 5.1 regression test for a live-reported crash: calling
-- CreshCollect/BattlePass.lua's Pass:Ensure() recursed infinitely and
-- overflowed the stack whenever at least one claimed Battle Pass tier
-- matched a premium card deck's tier, via this cycle:
--
--   Pass:Ensure() [BattlePass.lua:205]
--     -> CardDecks:BackfillFromClaimed() [CardDecks.lua:128]
--       -> CardDecks:Ensure() [CardDecks.lua:61]
--         -> CreshCollectAPI.IsBattlePassRewardClaimed() [CreshCollect.lua]
--           -> Pass:IsRewardClaimed() [BattlePass.lua:437]
--             -> Pass:Ensure() again [BattlePass.lua:438]  -- back to the top
--
-- This crashed CreshChat's entire UI:Initialize() (called from
-- PLAYER_LOGIN), which is why the whole suite appeared completely dead in
-- game with no C bubble and no working slash commands, even though every
-- file loaded and every TOC/deploy check passed.
--
-- Fixed with a re-entrancy guard (Pass._ensuring) around the
-- BackfillFromClaimed call in Pass:Ensure().
--
-- Also covers a second, unrelated bug found in the same crash log:
-- DungeonCrawlerContent.lua wrote to a nonexistent global `CC` instead of
-- `CG` ("attempt to index global 'CC' (a nil value)").
--
-- Loads the REAL production files (not reimplemented copies).
--
-- Usage: lua BattlePassCardDeckRecursionTests.lua

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

local function ok(cond, msg) if cond then pass(msg) else fail(msg) end end
local function eq(a, b, msg)
    if a == b then pass(msg)
    else fail(("%s  (expected %q, got %q)"):format(msg, tostring(b), tostring(a))) end
end

-- loadfile() chokes on the UTF-8 BOM several production files carry, and
-- Lua 5.1's load() is reader-function-based, not string-based -- read raw
-- bytes, strip the BOM if present, and loadstring() explicitly.
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

loadProductionFile("shared/Suite.lua", "CreshCollect", {})

local CG = { version = "0.2.3" }
loadProductionFile("addons/CreshGames/CardDeckLibrary.lua", "CreshGames", CG)
loadProductionFile("addons/CreshGames/CardDecks.lua", "CreshGames", CG)

local COL = { version = "0.2.3" }
loadProductionFile("addons/CreshCollect/CreshCollectDatabase.lua", "CreshCollect", COL)
_G.CreshCollectDatabase.Init()
loadProductionFile("addons/CreshCollect/CreshCollect.lua", "CreshCollect", COL)
loadProductionFile("addons/CreshCollect/BattlePass.lua", "CreshCollect", COL)

-- BattlePass.lua reads CC.CardDecks through the deferred _G.CreshChat proxy,
-- exactly like the real bridge would populate it.
_G.CreshChat = { CardDecks = CG.CardDecks }

if not COL.BattlePass or not CG.CardDecks then
    print("FATAL: BattlePass / CardDecks not found after loading production files")
    os.exit(2)
end

local function freshState()
    _G.CreshCollectDB = nil
    _G.CreshCollectDatabase.Init()
    _G.CreshGamesDB = { cardDecks = {} }
end

-- ============================================================
-- 1. The exact reported crash: a claimed tier matching a premium deck
-- ============================================================
section("Pass:Ensure() does not recurse when a claimed Battle Pass tier matches a premium deck")
freshState()

-- Force a known premium deck onto a known tier so this test doesn't depend
-- on the current catalog's specific tier assignments.
local firstDeckKey = CG.CardDecks.premiumOrder[1]
local firstDeckInfo = (_G.CreshGamesCardDecks or {})[firstDeckKey]
ok(firstDeckInfo ~= nil, "sanity: first premium deck resolves to a real catalog entry")
if firstDeckInfo then firstDeckInfo.battlePassTier = 5 end
CreshCollectDB.arcadeRewards.claimed["5"] = true

local okEnsure, resultOrErr = pcall(function() return COL.BattlePass:Ensure() end)
ok(okEnsure == true, "Pass:Ensure() returns without a stack overflow (err: " .. tostring(not okEnsure and resultOrErr or "") .. ")")
ok(COL.BattlePass._ensuring == false, "re-entrancy guard resets to false after the call completes")

-- ============================================================
-- 2. The backfill side effect still actually happens (no silent regression)
-- ============================================================
section("The CardDecks backfill/publish side effect still runs (fix must not just delete the feature)")
ok(CreshGamesDB.cardDecks.unlocked[firstDeckKey] == true, "the deck matching the claimed tier is unlocked in CreshGamesDB")

-- ============================================================
-- 3. Entering from the other side of the cycle also does not recurse
-- ============================================================
section("CardDecks:Ensure() called directly (the other half of the original cycle) does not recurse either")
freshState()
if firstDeckInfo then firstDeckInfo.battlePassTier = 5 end
CreshCollectDB.arcadeRewards.claimed["5"] = true
local okDecks, errDecks = pcall(function() return CG.CardDecks:Ensure() end)
ok(okDecks == true, "CardDecks:Ensure() returns without a stack overflow (err: " .. tostring(not okDecks and errDecks or "") .. ")")

-- ============================================================
-- 3b. A THIRD entry point into the same cycle: Pass:ClaimReward() (a fresh,
--     user-triggered top-level call, not nested inside Pass:Ensure() the
--     way BackfillFromClaimed is) calls CardDecks:UnlockDeck(), which walks
--     right back into CardDecks:Ensure() -> CreshCollectAPI ->
--     Pass:IsRewardClaimed() -> Pass:Ensure() again. This is a genuinely
--     different call shape than sections 1 and 3 above (the recursion is
--     entered fresh from OUTSIDE Pass:Ensure(), not from inside it), found
--     during the Phase 10 audit -- confirms the guard on Pass:Ensure()
--     itself stops re-entry regardless of which function triggers it.
-- ============================================================
section("Pass:ClaimReward() -> CardDecks:UnlockDeck() re-entering the cycle from a fresh (non-Ensure) entry point")
freshState()
if firstDeckInfo then firstDeckInfo.battlePassTier = 5 end
CreshCollectDB.arcadeRewards.passXP = COL.BattlePass:GetCumulativeXP(5) + 10
local okClaim, errClaim = pcall(function() return COL.BattlePass:ClaimReward(5) end)
ok(okClaim == true, "Pass:ClaimReward(5) returns without a stack overflow (err: " .. tostring(not okClaim and errClaim or "") .. ")")
ok(COL.BattlePass._ensuring == false, "guard resets to false after ClaimReward's nested Ensure() calls settle")
ok(CreshGamesDB.cardDecks.unlocked[firstDeckKey] == true, "the deck reward from ClaimReward is still unlocked correctly")

-- ============================================================
-- 4. Repeated calls never leave the guard stuck true
-- ============================================================
section("Repeated Ensure() calls never leave the re-entrancy guard stuck")
freshState()
for i = 1, 5 do
    COL.BattlePass:Ensure()
end
eq(COL.BattlePass._ensuring, false, "guard is false after 5 consecutive top-level Ensure() calls")

-- ============================================================
-- 5. No claimed tiers at all (the common case): still no recursion, no crash
-- ============================================================
section("No claimed tiers: Pass:Ensure() and CardDecks:Ensure() both still safe")
freshState()
local okA = pcall(function() return COL.BattlePass:Ensure() end)
local okB = pcall(function() return CG.CardDecks:Ensure() end)
ok(okA == true, "Pass:Ensure() safe with nothing claimed")
ok(okB == true, "CardDecks:Ensure() safe with nothing claimed")

-- ============================================================
-- 6. The second bug from the same crash log: DungeonCrawlerContent.lua's
--    stray `CC` global reference.
-- ============================================================
section("DungeonCrawlerContent.lua no longer indexes the nonexistent global CC")
local CG2 = { version = "0.2.3" }
local okContent, errContent = pcall(function()
    loadProductionFile("addons/CreshGames/DungeonCrawlerContent.lua", "CreshGames", CG2)
end)
ok(okContent == true, "loading the file does not error (err: " .. tostring(not okContent and errContent or "") .. ")")
ok(CG2.DungeonCrawlerContent ~= nil, "CG.DungeonCrawlerContent is set (was being written to the wrong global 'CC')")

-- ============================================================
-- Summary
-- ============================================================
print(("\n=== Results: %d passed, %d failed ==="):format(PASS, FAIL))
if FAIL > 0 then os.exit(1) end
