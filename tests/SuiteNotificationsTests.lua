-- SuiteNotificationsTests.lua
-- Lua 5.1 tests for shared/SuiteNotifications.lua: standalone loading (no
-- CreshChat/CC.UI present), load-order/idempotency, coalescing, passive-lane
-- queueing, actionable cards, and enablement fallback (RegisterEnabledQuery
-- override vs. the generic per-category table vs. own-storage toggles).
--
-- Usage: lua SuiteNotificationsTests.lua <path-to-SuiteNotifications.lua>

-- ============================================================
-- WoW API stubs
-- ============================================================
local function mockFrame()
    local obj = { _shown = false, _text = "", _scripts = {}, _events = {} }
    local mt = {}
    mt.__index = function(t, k)
        local fn
        if k == "CreateFontString" or k == "CreateTexture" then
            fn = function() return mockFrame() end
        elseif k == "GetWidth" or k == "GetHeight" then
            fn = function() return 100 end
        elseif k == "IsShown" then
            fn = function(self) return self._shown == true end
        elseif k == "Show" then
            fn = function(self) self._shown = true end
        elseif k == "Hide" then
            fn = function(self) self._shown = false end
        elseif k == "SetText" then
            fn = function(self, text) self._text = tostring(text or "") end
        elseif k == "GetText" then
            fn = function(self) return self._text end
        elseif k == "GetPoint" then
            fn = function() return "BOTTOMLEFT", nil, "BOTTOMLEFT", 0, 0 end
        elseif k == "SetScript" then
            fn = function(self, hook, handler) self._scripts[hook] = handler end
        elseif k == "GetScript" then
            fn = function(self, hook) return self._scripts[hook] end
        elseif k == "RegisterEvent" then
            fn = function(self, event) self._events[event] = true end
        elseif k == "UnregisterEvent" then
            fn = function(self, event) self._events[event] = nil end
        else
            fn = function(self, ...) return self end
        end
        rawset(t, k, fn)
        return fn
    end
    return setmetatable(obj, mt)
end

function CreateFrame(frameType, name)
    local f = mockFrame()
    if name then _G[name] = f end
    return f
end

local playSoundCalls = 0
function GetTime() return 1000 end
function time() return 1000 end
function date() return "12:00" end
_G.C_Timer = { After = function() end }
_G.UIParent = mockFrame()
_G.GameTooltip = mockFrame()
_G.STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
_G.PlaySound = function() playSoundCalls = playSoundCalls + 1 end
_G.SOUNDKIT = { IG_QUEST_LIST_COMPLETE = 888 }

-- ============================================================
-- Test runner
-- ============================================================
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

-- ============================================================
-- Load shared/SuiteNotifications.lua
-- ============================================================
local suitePath = (arg and arg[1]) or "shared/SuiteNotifications.lua"
dofile(suitePath)
local Notif = _G.CreshSuiteNotifications

-- ============================================================
-- 1. Standalone (no CreshChat / CC.UI at all)
-- ============================================================
section("Standalone loading (no CreshChat present)")

ok(Notif ~= nil, "CreshSuiteNotifications global is set")
ok(_G.CreshChat == nil, "sanity: no CreshChat global exists in this test")
eq(type(Notif.RegisterSource), "function", "RegisterSource present")
eq(type(Notif.RegisterCategory), "function", "RegisterCategory present")
eq(type(Notif.RegisterEnabledQuery), "function", "RegisterEnabledQuery present")
eq(type(Notif.Push), "function", "Push present")
eq(type(Notif.ShowCard), "function", "ShowCard present")

Notif:RegisterSource("CRESHGAMES", "CreshGames")
Notif:RegisterCategory("CRESHGAMES", "GAME_INVITE", "Game Invites", "desc", { priority = "CRITICAL" })
Notif:RegisterCategory("CRESHGAMES", "REWARD", "Rewards", "desc", { priority = "LOW" })

ok(Notif:IsSourceEnabled("CRESHGAMES"), "a registered source is enabled with no CreshChat present")
ok(Notif:IsCategoryEnabled("CRESHGAMES", "REWARD"), "a registered category is enabled with no CreshChat present")

local pushed = Notif:Push({ sourceAddon = "CRESHGAMES", category = "REWARD", title = "Test Reward", detail = "hi", coalesceKey = "T1" })
ok(pushed == true, "Push succeeds for a registered CRESHGAMES-only category with CreshChat absent")
eq(#Notif._activePassiveCards, 1, "the push produced exactly one active passive card")

-- ============================================================
-- 2. Load-order / idempotency
-- ============================================================
section("Load-order and idempotency")

local ref = _G.CreshSuiteNotifications
dofile(suitePath)
ok(_G.CreshSuiteNotifications == ref, "re-loading SuiteNotifications.lua is idempotent (same table)")

Notif:RegisterSource("CRESHCOLLECT", "CreshCollect")
Notif:RegisterCategory("CRESHCOLLECT", "ACHIEVEMENT", "Achievement Earned", "desc", { priority = "NORMAL" })

local gamesCats = Notif:GetRegisteredCategories("CRESHGAMES")
local collectCats = Notif:GetRegisteredCategories("CRESHCOLLECT")
ok(gamesCats.REWARD ~= nil and gamesCats.ACHIEVEMENT == nil, "CRESHGAMES categories don't leak CRESHCOLLECT's ACHIEVEMENT")
ok(collectCats.ACHIEVEMENT ~= nil and collectCats.REWARD == nil, "CRESHCOLLECT categories don't leak CRESHGAMES' REWARD")

-- Registering a CreshChat-like source later doesn't disturb the others.
Notif:RegisterSource("CRESHCHAT", "CreshChat")
Notif:RegisterCategory("CRESHCHAT", "WHISPER", "Whispers", "desc", { priority = "HIGH" })
ok(Notif:IsCategoryEnabled("CRESHGAMES", "REWARD"), "CRESHGAMES still enabled after CRESHCHAT registers later")
ok(Notif:IsCategoryEnabled("CRESHCOLLECT", "ACHIEVEMENT"), "CRESHCOLLECT still enabled after CRESHCHAT registers later")

-- ============================================================
-- 3. Coalescing
-- ============================================================
section("Coalescing")

local beforeCount = #Notif._activePassiveCards
Notif:Push({ sourceAddon = "CRESHGAMES", category = "REWARD", title = "Coalesce A", detail = "1", coalesceKey = "COALESCE_KEY" })
local afterFirst = #Notif._activePassiveCards
Notif:Push({ sourceAddon = "CRESHGAMES", category = "REWARD", title = "Coalesce B", detail = "2", coalesceKey = "COALESCE_KEY" })
local afterSecond = #Notif._activePassiveCards
eq(afterFirst, beforeCount + 1, "first push with a new coalesceKey adds one card")
eq(afterSecond, afterFirst, "second push with the same coalesceKey reuses the existing card (no new card)")

local coalescedCard
for _, c in ipairs(Notif._activePassiveCards) do
    if c._coalesceKey == "COALESCE_KEY" then coalescedCard = c end
end
ok(coalescedCard ~= nil, "the coalesced card is findable by its key")
eq(coalescedCard.title._text, "Coalesce B", "the coalesced card's content was updated to the second push's title")

-- ============================================================
-- 4. Passive-lane queueing
-- ============================================================
section("Passive-lane queueing")

-- Drain to a clean slate so the max-visible math below is predictable.
for _, c in ipairs({unpack(Notif._activePassiveCards)}) do Notif:RecycleCard(c) end
for i = #Notif._cardQueue, 1, -1 do table.remove(Notif._cardQueue, i) end

-- Default getMaxVisible() with no CreshChat present is 3 (hard-coded local
-- fallback in shared/SuiteNotifications.lua's getMaxVisible()).
for i = 1, 3 do
    Notif:Push({ sourceAddon = "CRESHGAMES", category = "REWARD", title = "Queue " .. i, detail = "", coalesceKey = "QUEUE_" .. i })
end
eq(#Notif._activePassiveCards, 3, "three distinct pushes fill the default max-visible passive lane")
eq(#Notif._cardQueue, 0, "queue is still empty while under the cap")

Notif:Push({ sourceAddon = "CRESHGAMES", category = "REWARD", title = "Queue 4", detail = "", coalesceKey = "QUEUE_4" })
eq(#Notif._activePassiveCards, 3, "a 4th distinct push does not exceed the passive-lane cap")
eq(#Notif._cardQueue, 1, "the 4th push queues instead of being dropped")

local firstActive = Notif._activePassiveCards[1]
Notif:RecycleCard(firstActive)
eq(#Notif._cardQueue, 0, "recycling a card promotes the queued event")
eq(#Notif._activePassiveCards, 3, "the passive lane is refilled back up to 3 after promotion")

local promoted = false
for _, c in ipairs(Notif._activePassiveCards) do
    if c._coalesceKey == "QUEUE_4" then promoted = true end
end
ok(promoted, "the specific queued event (QUEUE_4) is the one that got promoted")

-- ============================================================
-- 5. Actionable cards
-- ============================================================
section("Actionable cards")

-- Fill the passive lane back to its cap so we can prove actionable cards
-- bypass it entirely (no queue cap on the actionable lane).
for _, c in ipairs({unpack(Notif._activePassiveCards)}) do Notif:RecycleCard(c) end
for i = #Notif._cardQueue, 1, -1 do table.remove(Notif._cardQueue, i) end
for i = 1, 3 do
    Notif:Push({ sourceAddon = "CRESHGAMES", category = "REWARD", title = "Fill " .. i, detail = "", coalesceKey = "FILL_" .. i })
end
eq(#Notif._activePassiveCards, 3, "passive lane is at capacity going into the actionable test")

local acceptedCard, declinedCalled = nil, false
local actionPushed = Notif:Push({
    sourceAddon = "CRESHGAMES", category = "GAME_INVITE", title = "Invite", detail = "join?",
    destination = "ACTIONABLE", coalesceKey = "ACTION_1",
    actions = {
        accept = function(card) acceptedCard = card end,
        decline = function() declinedCalled = true end,
    },
})
ok(actionPushed == true, "an actionable push succeeds even while the passive lane is full")
eq(#Notif._activeActionCards, 1, "the actionable card lands in the actionable lane, not the passive one")
eq(#Notif._activePassiveCards, 3, "the passive lane is untouched by the actionable push")

local actionCard = Notif._activeActionCards[1]
ok(actionCard._onAccept ~= nil, "the actionable card's accept callback is wired")
actionCard._onAccept(actionCard)
eq(acceptedCard, actionCard, "invoking the wired accept callback calls through with the card")
actionCard._onDecline(actionCard)
ok(declinedCalled, "invoking the wired decline callback fires")

-- ============================================================
-- 6. Fallback / enablement
-- ============================================================
section("Enablement: RegisterEnabledQuery override vs. generic table vs. own-storage")

Notif:RegisterSource("CRESHTEST", "CreshTest")
Notif:RegisterCategory("CRESHTEST", "ALPHA", "Alpha", "desc")

ok(Notif:IsCategoryEnabled("CRESHTEST", "ALPHA"), "no override registered: falls back to the generic categories table (registered => enabled)")

Notif:RegisterEnabledQuery("CRESHTEST", function(categoryKey)
    if categoryKey == "ALPHA" then return false end
    return true
end)
ok(not Notif:IsCategoryEnabled("CRESHTEST", "ALPHA"), "a RegisterEnabledQuery override returning false suppresses the category")

Notif:RegisterCategory("CRESHTEST", "BETA", "Beta", "desc")
ok(Notif:IsCategoryEnabled("CRESHTEST", "BETA"), "the same override returning true (default) leaves other categories enabled")

-- Own-storage cardsEnabled toggle: only consulted when no query is
-- registered for the source (CRESHGAMES has none in this test file).
_G.CreshGamesDB = { }
Notif:SetCardsEnabled(false)
ok(not Notif:IsCategoryEnabled("CRESHGAMES", "REWARD"), "own-storage cardsEnabled=false suppresses a source with no registered query")
Notif:SetCardsEnabled(true)
ok(Notif:IsCategoryEnabled("CRESHGAMES", "REWARD"), "re-enabling own-storage cardsEnabled restores it")

-- ============================================================
-- 7. Sound vs. card-visibility independence
-- ============================================================
section("Sound and card visibility are independently configurable")

playSoundCalls = 0
Notif:SetSoundEnabled(false)
Notif:PlayNotificationSound("CRESHGAMES", {})
eq(playSoundCalls, 0, "soundEnabled=false suppresses the fallback PlaySound with no CreshChat present")

Notif:SetSoundEnabled(true)
Notif:PlayNotificationSound("CRESHGAMES", {})
eq(playSoundCalls, 1, "soundEnabled=true allows the fallback PlaySound with no CreshChat present")

-- Cards stay independently controllable via cardsEnabled regardless of sound.
Notif:SetCardsEnabled(false)
Notif:PlayNotificationSound("CRESHGAMES", {})
eq(playSoundCalls, 2, "sound still plays even while cardsEnabled is false (independent toggles)")
Notif:SetCardsEnabled(true)

-- ============================================================
-- 8. Profiling instrumentation
-- ============================================================
section("Profiling instrumentation (off by default, cold/warm reported separately)")

ok(Notif:IsProfilingEnabled() == false, "profiling is disabled by default")
ok(tostring(Notif:GetProfileReport()):find("No notification profiling") ~= nil, "no samples recorded while disabled")

local profileTick = 0
_G.debugprofilestop = function() profileTick = profileTick + 1; return profileTick end
Notif:SetProfilingEnabled(true)
Notif:ResetProfile()

for _, c in ipairs({unpack(Notif._activePassiveCards)}) do Notif:RecycleCard(c) end
Notif:Push({ sourceAddon = "CRESHGAMES", category = "REWARD", title = "Profiled", detail = "", coalesceKey = "PROFILE_1" })

local report = Notif:GetProfileReport()
ok(report:find("cold") ~= nil or report:find("warm") ~= nil, "GetProfileReport contains at least one cold/warm stage after a push")

Notif:SetProfilingEnabled(false)
ok(Notif:IsProfilingEnabled() == false, "profiling can be turned back off")

-- ============================================================
-- Summary
-- ============================================================
print(("\n=== Results: %d passed, %d failed ==="):format(PASS, FAIL))
if FAIL > 0 then os.exit(1) end
