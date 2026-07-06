-- LauncherRoutingTests.lua
-- Lua 5.1 tests for the shared launcher's destination-registry routing in
-- shared/Launcher.lua (Phase 9 -- ownership moved out of CreshChat/UI.lua):
--   Launcher:GetEffectiveDest()        -- which destination C defaults to
--   Launcher:ToggleMode(dest)          -- per-destination dispatch through
--                                          the internal LAUNCHER_DESTINATIONS registry
--   Launcher:PrimaryClick()            -- single click on C: opens directly
--                                          when <=1 destination is AVAILABLE,
--                                          otherwise toggles the satellite reveal
--   Launcher:SatelliteClick(dest)      -- a revealed satellite button: performs
--                                          its action then collapses the reveal
--   Launcher:SetShown/PositionButtons  -- all five satellites show or hide
--                                          together as one row; per-icon
--                                          availability only affects colour/click,
--                                          never row membership
--   Launcher:RefreshButtonStates()     -- greys unavailable icons, restores
--                                          full colour for available ones
--
-- Loads the REAL production shared/Launcher.lua, with _G.CreshChat and
-- _G.CreshSuite mocked out (the same nil-safe public-API boundary the real
-- addons use), and a fresh _G.CreshSuiteLauncherAPI/_G.CreshChatDB each run.
--
-- Usage: lua LauncherRoutingTests.lua [Launcher.lua]

-- A generic, capable mock covering every WoW frame/texture/fontstring method
-- shared/Launcher.lua's EnsureBuilt/makeSatelliteButton calls, so those real
-- code paths can run end-to-end against a fake screen instead of only
-- exercising the pure dispatch functions.
local function mockRegion()
    local r = { shown = false, alpha = 1, mouseEnabled = true, vertexColor = { 1, 1, 1, 1 } }
    function r:SetPoint() end
    function r:ClearAllPoints() end
    function r:SetAllPoints() end
    function r:SetHeight() end
    function r:SetWidth() end
    function r:SetSize() end
    function r:Show() self.shown = true end
    function r:Hide() self.shown = false end
    function r:SetShown(v) self.shown = v and true or false end
    function r:IsShown() return self.shown == true end
    function r:SetAlpha(v) self.alpha = v end
    function r:GetAlpha() return self.alpha end
    function r:SetTexture() end
    function r:SetVertexColor(a, b, c, d) self.vertexColor = { a, b, c, d }; self.r, self.g, self.b_, self.a_ = a, b, c, d end
    function r:SetBlendMode() end
    function r:SetColorTexture() end
    function r:SetFont() end
    function r:SetJustifyH() end
    function r:SetJustifyV() end
    function r:SetTextColor() end
    function r:SetText() end
    function r:GetText() return "" end
    return r
end

local function mockFrame()
    local f = mockRegion()
    f.iconTexture = nil
    function f:SetFrameStrata() end
    function f:SetClampedToScreen() end
    function f:SetMovable() end
    function f:RegisterForDrag() end
    function f:RegisterEvent() end
    function f:SetScript(kind, fn) self["_script_" .. kind] = fn end
    function f:GetScript(kind) return self["_script_" .. kind] end
    function f:EnableMouse(v) self.mouseEnabled = v and true or false end
    function f:StartMoving() end
    function f:StopMovingOrSizing() end
    function f:GetPoint() return "BOTTOMRIGHT", nil, "BOTTOMRIGHT", -40, 40 end
    function f:GetCenter() return 960, 200 end
    function f:GetLeft() return 900 end
    function f:GetRight() return 946 end
    function f:GetTop() return 240 end
    function f:GetBottom() return 194 end
    function f:SetBackdrop() end
    function f:SetBackdropColor() end
    function f:SetBackdropBorderColor() end
    function f:CreateTexture() return mockRegion() end
    function f:CreateFontString() return mockRegion() end
    return f
end

function CreateFrame()
    return mockFrame()
end
function time() return 0 end
function GetTime() return 0 end
_G.C_Timer = { After = function() end }
_G.hooksecurefunc = function() end
_G.UIParent = { GetWidth = function() return 1920 end, GetHeight = function() return 1080 end }
_G.GetAddOnMetadata = function() return nil end
_G.GameTooltip = {
    SetOwner = function() end, AddLine = function() end, Show = function() end, Hide = function() end,
}
_G.IsShiftKeyDown = function() return false end
_G.STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"

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

-- ============================================================
-- Load the real production file fresh for every run (the file itself is an
-- idempotency-guarded singleton, so re-running the chunk with a clean
-- _G.CreshSuiteLauncherAPI each time simulates "this is the first addon to load").
-- ============================================================
local launcherPath = (arg and arg[1]) or "shared/Launcher.lua"

local function freshLauncher()
    _G.CreshSuiteLauncherAPI = nil
    _G.CreshChatDB = { ui = {} }
    _G.CreshGamesDB = nil
    _G.CreshCollectDB = nil
    local chunk = assert(loadfile(launcherPath))
    chunk()
    return _G.CreshSuiteLauncherAPI
end

local printed = {}
local toggleMainCalls, openSettingsCalls = 0, 0
local gamesCalls, achieveCalls, progressCalls, questCalls = 0, 0, 0, 0

local function resetCallCounts()
    toggleMainCalls, openSettingsCalls = 0, 0
    gamesCalls, achieveCalls, progressCalls, questCalls = 0, 0, 0, 0
    printed = {}
end

-- Registers mock _G.CreshChat and _G.CreshSuite whose availability exactly
-- matches the flags passed in -- the same guarded public-API boundary the
-- real registry entries in shared/Launcher.lua go through.
local function setAddons(chatOn, gamesOn, achieveOn, progressOn, questOn)
    _G.CreshChat = {
        IsFeatureEnabled = function() return chatOn end,
        Print = function(_, msg) table.insert(printed, msg) end,
        UI = {
            ToggleMain = function() toggleMainCalls = toggleMainCalls + 1 end,
            OpenSettings = function() openSettingsCalls = openSettingsCalls + 1 end,
        },
    }
    local services = {}
    if gamesOn then services.OpenSoloGames = function() gamesCalls = gamesCalls + 1 end end
    if achieveOn then services.OpenAchievements = function() achieveCalls = achieveCalls + 1 end end
    if progressOn then services.OpenProgressHub = function() progressCalls = progressCalls + 1 end end
    if questOn then services.OpenCreshQuest = function() questCalls = questCalls + 1 end end
    _G.CreshSuite = { GetService = function(_, name) return services[name] end }
end

local Launcher

-- ============================================================
-- 1. GetEffectiveDest
-- ============================================================
section("GetEffectiveDest: fallback order when nothing configured/remembered")

Launcher = freshLauncher()
setAddons(true, true, true, true, false)
eq(Launcher:GetEffectiveDest(), "CHAT", "chat preferred first when everything is installed")

setAddons(false, true, true, true, false)
eq(Launcher:GetEffectiveDest(), "GAMES", "falls back to games when chat is off")

setAddons(false, false, true, true, false)
eq(Launcher:GetEffectiveDest(), "ACHIEVEMENTS", "falls back to achievements when chat+games are off")

setAddons(false, false, false, true, false)
eq(Launcher:GetEffectiveDest(), "PROGRESS", "falls back to progress when only CreshCollect's progress is on")

setAddons(false, false, false, false, false)
eq(Launcher:GetEffectiveDest(), "SETTINGS", "falls back to settings when nothing at all is available")

setAddons(false, false, false, false, true)
eq(Launcher:GetEffectiveDest(), "CRESHQUEST", "falls back to CreshQuest when it is the only available destination")

section("GetEffectiveDest: explicit configured default")
Launcher = freshLauncher()
_G.CreshChatDB.launcher = {}
_G.CreshChatDB.launcher.launcherDefault = "GAMES"
setAddons(true, true, true, true, false)
eq(Launcher:GetEffectiveDest(), "GAMES", "configured default (GAMES) honoured when available")

_G.CreshChatDB.launcher.launcherDefault = "GAMES"
setAddons(true, false, true, true, false)
eq(Launcher:GetEffectiveDest(), "CHAT", "configured default (GAMES) falls back when GAMES unavailable")

-- ============================================================
-- 2. ToggleMode dispatch
-- ============================================================
section("ToggleMode: CHAT dispatches to CreshChat's own ToggleMain")
Launcher = freshLauncher(); resetCallCounts()
setAddons(true, false, false, false, false)
Launcher:ToggleMode("CHAT")
eq(toggleMainCalls, 1, "ToggleMain invoked exactly once")
eq(_G.CreshChatDB.launcher.lastLauncherDest, "CHAT", "lastLauncherDest recorded")

section("ToggleMode: ACHIEVEMENTS routes through the Suite service, and only that service")
Launcher = freshLauncher(); resetCallCounts()
setAddons(false, false, true, false, false)
Launcher:ToggleMode("ACHIEVEMENTS")
eq(achieveCalls, 1, "OpenAchievements service invoked exactly once")
eq(toggleMainCalls, 0, "CreshChat's own ToggleMain is never called as a fallback")
eq(_G.CreshChatDB.launcher.lastLauncherDest, "ACHIEVEMENTS", "lastLauncherDest recorded")

section("ToggleMode: ACHIEVEMENTS with no CreshSuite/service prints 'Requires CreshCollect'")
Launcher = freshLauncher(); resetCallCounts()
setAddons(true, false, false, false, false)
Launcher:ToggleMode("ACHIEVEMENTS")
eq(printed[#printed], "Requires CreshCollect", "exact message printed")
eq(achieveCalls, 0, "the service is never invoked when unavailable")
eq(toggleMainCalls, 0, "no CreshChat fallback window opened")

section("ToggleMode: PROGRESS routes through the Suite service")
Launcher = freshLauncher(); resetCallCounts()
setAddons(false, false, false, true, false)
Launcher:ToggleMode("PROGRESS")
eq(progressCalls, 1, "OpenProgressHub service invoked exactly once")
eq(toggleMainCalls, 0, "no CreshChat fallback window opened")

section("ToggleMode: GAMES with no service prints 'Requires CreshGames' and opens nothing")
Launcher = freshLauncher(); resetCallCounts()
setAddons(true, false, false, false, false)
Launcher:ToggleMode("GAMES")
eq(printed[#printed], "Requires CreshGames", "message printed")
eq(gamesCalls, 0, "the service is never invoked when unavailable")
eq(toggleMainCalls, 0, "no CreshChat fallback window opened")

section("ToggleMode: GAMES with service present calls only that service")
Launcher = freshLauncher(); resetCallCounts()
setAddons(false, true, false, false, false)
Launcher:ToggleMode("GAMES")
eq(gamesCalls, 1, "OpenSoloGames service invoked exactly once")
eq(toggleMainCalls, 0, "no CreshChat fallback window opened")

section("ToggleMode: CRESHQUEST absent prints 'Requires CreshQuest' and opens nothing")
Launcher = freshLauncher(); resetCallCounts()
setAddons(true, false, false, false, false)
Launcher:ToggleMode("CRESHQUEST")
eq(printed[#printed], "Requires CreshQuest", "message printed")
eq(questCalls, 0, "the service is never invoked when unavailable")

section("ToggleMode: CRESHQUEST routes through its Suite service once registered")
Launcher = freshLauncher(); resetCallCounts()
setAddons(false, false, false, false, true)
Launcher:ToggleMode("CRESHQUEST")
eq(questCalls, 1, "OpenCreshQuest service invoked exactly once")
eq(toggleMainCalls, 0, "no CreshChat fallback window opened")

section("ToggleMode: nil public API (CreshSuite table exists but has no GetService)")
Launcher = freshLauncher(); resetCallCounts()
setAddons(true, false, false, false, false)
_G.CreshSuite = {}
local ok1, err1 = pcall(function() Launcher:ToggleMode("GAMES") end)
ok(ok1, "malformed Suite (no GetService method) does not error (err: " .. tostring(err1) .. ")")
eq(printed[#printed], "Requires CreshGames", "still reports the destination as unavailable")

section("ToggleMode: CreshSuite entirely absent")
Launcher = freshLauncher(); resetCallCounts()
_G.CreshChat = { IsFeatureEnabled = function() return true end, Print = function(_, msg) table.insert(printed, msg) end, UI = {} }
_G.CreshSuite = nil
local okNil, errNil = pcall(function() Launcher:ToggleMode("PROGRESS") end)
ok(okNil, "entirely absent CreshSuite does not error (err: " .. tostring(errNil) .. ")")
eq(printed[#printed], "Requires CreshCollect", "still reports the destination as unavailable")

section("ToggleMode: GetService present but returns a non-function for the expected method")
-- Suite:RegisterService (shared/Suite.lua) type-checks and errors on
-- registration if fn isn't a function, so this shape can't come from real
-- registration -- only from a malformed test double. Documents that calling
-- through surfaces a clear Lua error rather than silently no-oping.
Launcher = freshLauncher(); resetCallCounts()
_G.CreshChat = { IsFeatureEnabled = function() return true end, Print = function(_, msg) table.insert(printed, msg) end, UI = {} }
_G.CreshSuite = { GetService = function(_, name) if name == "OpenSoloGames" then return "not a function" end end }
local ok2, err2 = pcall(function() Launcher:ToggleMode("GAMES") end)
ok(not ok2, "calling a non-function 'service' surfaces as a Lua error (err: " .. tostring(err2) .. ")")

-- ============================================================
-- 3. PrimaryClick: direct-open vs. expand-to-reveal
-- ============================================================
section("PrimaryClick: single available destination opens directly, no reveal")
Launcher = freshLauncher(); resetCallCounts()
setAddons(true, false, false, false, false)
Launcher:PrimaryClick()
eq(toggleMainCalls, 1, "chat-only install: clicking C opens CreshChat directly")
ok(Launcher.expanded ~= true, "no satellites revealed when only one destination exists")

Launcher = freshLauncher(); resetCallCounts()
setAddons(false, true, false, false, false)
Launcher:PrimaryClick()
eq(gamesCalls, 1, "games-only install: clicking C opens the games hub directly")
ok(Launcher.expanded ~= true, "no satellites revealed when only one destination exists")

Launcher = freshLauncher(); resetCallCounts()
setAddons(false, false, false, true, false)
Launcher:PrimaryClick()
eq(progressCalls, 1, "collect-only install: clicking C opens the progression interface directly")
ok(Launcher.expanded ~= true, "no satellites revealed when only one destination exists")

section("PrimaryClick: CreshQuest alone counts as exactly one destination too")
Launcher = freshLauncher(); resetCallCounts()
setAddons(false, false, false, false, true)
Launcher:PrimaryClick()
eq(questCalls, 1, "CreshQuest-only availability: clicking C opens CreshQuest directly")
ok(Launcher.expanded ~= true, "no satellites revealed when only one destination exists")

section("PrimaryClick: CreshQuest absent never inflates the destination count")
Launcher = freshLauncher(); resetCallCounts()
setAddons(true, false, false, false, false)
Launcher:PrimaryClick()
eq(toggleMainCalls, 1, "chat-only install still opens directly even though CreshQuest icon is visible")
ok(Launcher.expanded ~= true, "CreshQuest being unavailable does not force a reveal step")

section("PrimaryClick: 2+ available destinations reveal satellites first, then open on second click")
Launcher = freshLauncher(); resetCallCounts()
setAddons(true, true, false, false, false)
Launcher:PrimaryClick()
ok(Launcher.expanded == true, "first click reveals the satellites")
eq(toggleMainCalls, 0, "first click does not itself open a destination")

Launcher:PrimaryClick()
ok(Launcher.expanded == false, "second click collapses the satellites again")
eq(toggleMainCalls, 1, "second click opens the default destination (chat) exactly once")

section("PrimaryClick: all four real addons installed -- deterministic, every destination reachable")
Launcher = freshLauncher(); resetCallCounts()
setAddons(true, true, true, true, false)
Launcher:PrimaryClick()
ok(Launcher.expanded == true, "click reveals satellites when all addons are installed")
Launcher:SatelliteClick("ACHIEVEMENTS")
eq(achieveCalls, 1, "achievements satellite reaches CreshCollect's achievements window")
ok(Launcher.expanded == false, "expansion collapses after a satellite is used")

Launcher:PrimaryClick()
Launcher:SatelliteClick("PROGRESS")
eq(progressCalls, 1, "progress satellite reaches CreshCollect's progression interface")

Launcher:PrimaryClick()
Launcher:SatelliteClick("GAMES")
eq(gamesCalls, 1, "games satellite reaches CreshGames through the normal guard")

section("PrimaryClick: an unavailable satellite click still collapses the row (no duplicate window, no stuck-open reveal)")
Launcher = freshLauncher(); resetCallCounts()
setAddons(true, true, false, false, false)
Launcher:PrimaryClick()
ok(Launcher.expanded == true, "reveal happens with 2 available destinations")
Launcher:SatelliteClick("ACHIEVEMENTS")
eq(printed[#printed], "Requires CreshCollect", "unavailable satellite still reports its requirement")
eq(toggleMainCalls, 0, "clicking an unavailable satellite never opens the CreshChat fallback window")
ok(Launcher.expanded == false, "the row still collapses even though the destination was unavailable")

-- ============================================================
-- 4. Satellite visibility (SetShown / PositionButtons)
-- All five icons are one row: row membership depends only on
-- reveal/EXPANDED state, never on per-destination availability.
-- ============================================================
local function keys()
    return { "chatButton", "gamesButton", "achieveButton", "progressButton", "questButton" }
end

local function shownMap()
    local out = {}
    for _, key in ipairs(keys()) do
        local button = Launcher.buttons[key]
        out[key] = button and button:IsShown()
    end
    return out
end

section("Satellite visibility: single addon installed -> no satellites, even though the bubble shows")
Launcher = freshLauncher()
setAddons(true, false, false, false, false)
Launcher:EnsureBuilt()
Launcher:SetShown(true)
local shown = shownMap()
ok(Launcher.bubble:IsShown(), "main C bubble is shown")
eq(shown.chatButton, false, "chat satellite hidden (chat has nothing else to expand to)")
eq(shown.gamesButton, false, "games satellite hidden (row not revealed)")
eq(shown.achieveButton, false, "achievements satellite hidden (row not revealed)")
eq(shown.progressButton, false, "progress satellite hidden (row not revealed)")
eq(shown.questButton, false, "CreshQuest satellite hidden (row not revealed)")

section("Satellite visibility: two addons installed, not yet expanded -> satellites stay hidden (minimal)")
Launcher = freshLauncher()
setAddons(true, true, false, false, false)
Launcher:EnsureBuilt()
Launcher.expanded = false
Launcher:SetShown(true)
shown = shownMap()
eq(shown.gamesButton, false, "games satellite stays tucked away until C is clicked")
eq(shown.chatButton, false, "chat satellite stays tucked away until C is clicked")

section("Satellite visibility: revealed -> ALL five icons appear together, including unavailable ones")
Launcher = freshLauncher()
setAddons(true, true, false, false, false)
Launcher:EnsureBuilt()
Launcher.expanded = true
Launcher:SetShown(true)
shown = shownMap()
eq(shown.chatButton, true, "chat satellite appears once revealed")
eq(shown.gamesButton, true, "games satellite appears once revealed")
eq(shown.achieveButton, true, "achievements satellite appears too, even though CreshCollect is absent")
eq(shown.progressButton, true, "progress satellite appears too, even though CreshCollect is absent")
eq(shown.questButton, true, "CreshQuest satellite appears too, even though it is never installed")

section("Satellite visibility: all four real addons installed, expanded -> every destination shown")
Launcher = freshLauncher()
setAddons(true, true, true, true, false)
Launcher:EnsureBuilt()
Launcher.expanded = true
Launcher:SetShown(true)
shown = shownMap()
eq(shown.chatButton, true, "chat satellite present")
eq(shown.gamesButton, true, "games satellite present")
eq(shown.achieveButton, true, "achievements satellite present")
eq(shown.progressButton, true, "progress satellite present")
eq(shown.questButton, true, "CreshQuest satellite present (always visible)")

section("Satellite visibility: CreshChat absent (games+collect only) -- no chat satellite, others become primary-visible")
Launcher = freshLauncher()
setAddons(false, true, true, true, false)
Launcher:EnsureBuilt()
Launcher.expanded = false
Launcher:SetShown(true)
shown = shownMap()
eq(shown.chatButton, false, "no chat satellite when CreshChat's chat feature is off")
eq(shown.gamesButton, true, "games button becomes primary-visible when chat is off (module IS the launcher)")
eq(shown.achieveButton, true, "achievements button becomes primary-visible when chat is off")
eq(shown.progressButton, true, "progress button becomes primary-visible when chat is off")
eq(shown.questButton, true, "CreshQuest button becomes primary-visible when chat is off too")

-- ============================================================
-- 5. Missing-addon disabled visuals (RefreshButtonStates)
-- ============================================================
section("RefreshButtonStates: unavailable destinations are greyed, available ones are full colour")
Launcher = freshLauncher()
setAddons(true, false, true, false, false)
Launcher:EnsureBuilt()
Launcher:RefreshButtonStates()
eq(Launcher.buttons.gamesButton.iconTexture.r, 0.4, "GAMES (unavailable) icon is desaturated")
eq(Launcher.buttons.achieveButton.iconTexture.r, 1, "ACHIEVEMENTS (available) icon is full colour")
eq(Launcher.buttons.questButton.iconTexture.r, 0.4, "CRESHQUEST (never installed) icon is desaturated")

Launcher = freshLauncher()
setAddons(false, true, false, false, true)
Launcher:EnsureBuilt()
Launcher:RefreshButtonStates()
eq(Launcher.buttons.gamesButton.iconTexture.r, 1, "GAMES becomes full colour once its service is registered")
eq(Launcher.buttons.questButton.iconTexture.r, 1, "CRESHQUEST becomes full colour once its service is registered")

-- ============================================================
-- 6. Public registration boundary (new in Phase 9)
-- ============================================================
section("RegisterDestination: adds a new destination and can replace an existing one by key")
Launcher = freshLauncher()
local customCalls = 0
local addedOk = Launcher:RegisterDestination({
    key = "CUSTOM", buttonKey = "customButton", frameName = "TestCustomButton",
    label = "Cs", tooltipTitle = "Custom", tooltipText = "Custom destination",
    texture = "Interface\\Icons\\INV_Misc_QuestionMark", requirementText = "Requires Custom",
    IsAvailable = function() return true end,
    Open = function() customCalls = customCalls + 1; return true end,
})
ok(addedOk, "a well-formed new destination is accepted")
ok(Launcher:GetDestination("CUSTOM") ~= nil, "the new destination is retrievable by key")
Launcher:ToggleMode("CUSTOM")
eq(customCalls, 1, "the newly registered destination's Open() is actually called")

local replaced = Launcher:RegisterDestination({
    key = "CUSTOM", buttonKey = "customButton", frameName = "TestCustomButton",
    label = "Cs", tooltipTitle = "Custom v2", tooltipText = "Replaced",
    texture = "Interface\\Icons\\INV_Misc_QuestionMark",
    IsAvailable = function() return true end, Open = function() return true end,
})
ok(replaced, "re-registering the same key replaces it in place")
eq(Launcher:GetDestination("CUSTOM").tooltipTitle, "Custom v2", "the replacement definition is the one now stored")

section("RegisterDestination: malformed input is rejected, not silently accepted")
Launcher = freshLauncher()
eq(Launcher:RegisterDestination(nil), false, "nil is rejected")
eq(Launcher:RegisterDestination({}), false, "a table with no key is rejected")
eq(Launcher:RegisterDestination("CUSTOM"), false, "a non-table is rejected")

-- ============================================================
-- Summary
-- ============================================================
print(("\n=== Results: %d passed, %d failed ==="):format(PASS, FAIL))
if FAIL > 0 then os.exit(1) end
