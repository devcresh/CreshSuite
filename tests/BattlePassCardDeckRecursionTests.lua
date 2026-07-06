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
loadProductionFile("addons/CreshGames/CreshGames.lua", "CreshGames", CG)
loadProductionFile("addons/CreshGames/CardDeckLibrary.lua", "CreshGames", CG)
loadProductionFile("addons/CreshGames/CardDecks.lua", "CreshGames", CG)

local COL = { version = "0.2.3" }
loadProductionFile("addons/CreshCollect/CreshCollectDatabase.lua", "CreshCollect", COL)
_G.CreshCollectDatabase.Init()
loadProductionFile("addons/CreshCollect/CreshCollect.lua", "CreshCollect", COL)
loadProductionFile("addons/CreshCollect/BattlePass.lua", "CreshCollect", COL)

-- BattlePass communicates through the guarded CreshGamesAPI registered by
-- CreshGames.lua; no private cross-addon table bridge is needed.

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
-- 1. The exact reported crash: a claimed tier matching a premium deck.
--    Phase 10 note: CreshCollect's Battle Pass no longer syncs ANY reward
--    into CreshGames (card decks/Tetris themes are CreshGames' own Battle
--    Pass's rewards now, see addons/CreshGames/GamesBattlePass.lua) -- so
--    Pass:Ensure() no longer calls into CardDecks at all, which removes this
--    half of the original cycle entirely rather than merely guarding it.
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

-- ============================================================
-- 2. Decoupling confirmed: a CreshCollect pass claim no longer reaches into
--    CreshGames' card decks at all (that link was intentionally removed).
-- ============================================================
section("CreshCollect's Battle Pass claim no longer backfills CreshGames card decks (intentional decoupling)")
ok((CreshGamesDB.cardDecks.unlocked or {})[firstDeckKey] ~= true, "the deck stays locked from CreshCollect's claim alone -- decks now come from CreshGames' own pass")

-- ============================================================
-- 3. Entering from the other side of the cycle still does not recurse.
--    CardDecks:Ensure() no longer queries CreshCollectAPI at all -- the
--    legacy battlePassTier backfill (and BackfillFromClaimed/
--    GetBattlePassReward) was removed as dead code once decks started
--    unlocking directly from CreshGames' own pass (GamesBattlePass.lua).
--    That closes off this half of the original cycle entirely too.
-- ============================================================
section("CardDecks:Ensure() called directly (the other half of the original cycle) does not recurse either")
freshState()
if firstDeckInfo then firstDeckInfo.battlePassTier = 5 end
CreshCollectDB.arcadeRewards.claimed["5"] = true
local okDecks, errDecks = pcall(function() return CG.CardDecks:Ensure() end)
ok(okDecks == true, "CardDecks:Ensure() returns without a stack overflow (err: " .. tostring(not okDecks and errDecks or "") .. ")")
ok((CreshGamesDB.cardDecks.unlocked or {})[firstDeckKey] ~= true, "CardDecks:Ensure() no longer backfills from CreshCollect's claimed tiers at all")

-- ============================================================
-- 3b. Pass:ClaimReward() (a fresh, user-triggered top-level call) no longer
--     calls into CreshGames at all -- confirms the decoupling holds from
--     this entry point too, not just Pass:Ensure().
-- ============================================================
section("Pass:ClaimReward() no longer reaches into CreshGames' card decks")
freshState()
if firstDeckInfo then firstDeckInfo.battlePassTier = 5 end
CreshCollectDB.arcadeRewards.passXP = COL.BattlePass:GetCumulativeXP(5) + 10
local okClaim, errClaim = pcall(function() return COL.BattlePass:ClaimReward(5) end)
ok(okClaim == true, "Pass:ClaimReward(5) returns without a stack overflow (err: " .. tostring(not okClaim and errClaim or "") .. ")")
ok((CreshGamesDB.cardDecks.unlocked or {})[firstDeckKey] ~= true, "ClaimReward no longer unlocks a CreshGames card deck -- that reward moved to CreshGames' own pass")

-- ============================================================
-- 4. Repeated calls remain safe (no guard needed any more: Ensure() no
--    longer calls anything that could re-enter it).
-- ============================================================
section("Repeated Ensure() calls remain safe")
freshState()
local okRepeat = true
for _ = 1, 5 do
    local runOk = pcall(function() COL.BattlePass:Ensure() end)
    okRepeat = okRepeat and runOk
end
ok(okRepeat, "5 consecutive top-level Ensure() calls all succeed without error")

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
