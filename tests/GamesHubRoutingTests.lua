-- GamesHubRoutingTests.lua
-- Lua 5.1 tests for Phase 4 (unified CreshGames hub shell):
--   Solo:BuildWindow()    -- SOLO/MULTIPLAYER/UNLOCKS tab bar + sibling panels
--   Solo:SelectHubTab()   -- tab switch, persistence, cross-module wiring
--   Solo:RefreshUnlocksPanel() / OpenUnlockRow()
--   Games:SetHubVisible() / Games:OpenHub()  -- multiplayer hub reparented
--     into the shell instead of CC.UI.main.body / CreshChat's drawer
--   Solo:OpenHub()        -- restores the last active top-level tab
--   The OnUpdate/OnKeyDown/OnKeyUp visibility guard that stops a solo game
--     from ticking in the background while another top-level tab is shown
--
-- Loads the REAL production files (not reimplemented copies), with
-- _G.CreshChat left entirely nil throughout -- the whole point of Phase 4
-- is that this shell (and the multiplayer hub inside it) works without
-- CreshChat installed at all.
--
-- Usage: lua GamesHubRoutingTests.lua

-- ============================================================
-- Generic WoW widget mock -- one factory covers Frame/Button/StatusBar/
-- Texture/FontString, since SoloGames.lua/Games.lua/CreshUI.lua only touch
-- the common subset of the widget API (no animation groups, models or
-- cooldowns anywhere in these files).
-- ============================================================
local function mockWidget()
    local w = { _shown = true, _scripts = {}, _text = "", _alpha = 1, _w = 100, _h = 100 }
    function w:SetPoint(point, _, relPoint, x, y)
        self._point = { point = point, relPoint = relPoint or point, x = x or 0, y = y or 0 }
    end
    function w:ClearAllPoints() self._point = nil end
    function w:SetAllPoints() end
    function w:GetPoint()
        local p = self._point or { point = "CENTER", relPoint = "CENTER", x = 0, y = 0 }
        return p.point, nil, p.relPoint, p.x, p.y
    end
    function w:SetSize(width, height) self._w, self._h = width, height end
    function w:SetWidth(width) self._w = width end
    function w:SetHeight(height) self._h = height end
    function w:GetWidth() return self._w end
    function w:GetHeight() return self._h end
    function w:SetFrameStrata() end
    function w:SetFrameLevel(level) self._level = level end
    function w:GetFrameLevel() return self._level or 1 end
    function w:SetClampedToScreen() end
    function w:SetMovable() end
    function w:EnableMouse() end
    function w:EnableKeyboard() end
    function w:EnableMouseWheel() end
    function w:SetPropagateKeyboardInput() end
    function w:RegisterForDrag() end
    function w:RegisterForClicks() end
    function w:RegisterEvent() end
    function w:UnregisterEvent() end
    function w:UnregisterAllEvents() end
    function w:SetScript(hook, fn) self._scripts[hook] = fn end
    function w:GetScript(hook) return self._scripts[hook] end
    function w:HookScript(hook, fn) self._scripts[hook] = fn end
    function w:Show() self._shown = true end
    function w:Hide() self._shown = false end
    function w:SetShown(v) self._shown = v and true or false end
    function w:IsShown() return self._shown == true end
    function w:IsVisible() return self._shown == true end
    function w:SetBackdrop() end
    function w:SetBackdropColor() end
    function w:SetBackdropBorderColor() end
    function w:StartMoving() end
    function w:StopMovingOrSizing() end
    function w:SetAlpha(a) self._alpha = a end
    function w:GetAlpha() return self._alpha end
    function w:SetScale(s) self._scale = s end
    function w:GetScale() return self._scale or 1 end
    function w:CreateTexture() return mockWidget() end
    function w:CreateFontString() return mockWidget() end
    function w:SetTexture() end
    function w:SetTexCoord() end
    function w:SetVertexColor() end
    function w:SetBlendMode() end
    function w:SetColorTexture() end
    function w:SetFont() end
    function w:SetJustifyH() end
    function w:SetJustifyV() end
    function w:SetTextColor() end
    function w:SetText(t) self._text = t end
    function w:GetText() return self._text end
    function w:SetWordWrap() end
    function w:SetStatusBarTexture() end
    function w:SetMinMaxValues(lo, hi) self._min, self._max = lo, hi end
    function w:SetValue(v) self._value = v end
    function w:GetValue() return self._value or 0 end
    function w:SetStatusBarColor() end
    return w
end

function CreateFrame(kind, name)
    local w = mockWidget()
    w._kind, w._name = kind, name
    return w
end
function time() return 0 end
function GetTime() return 0 end
_G.C_Timer = { After = function() end }
_G.hooksecurefunc = function() end
_G.UIParent = mockWidget()
_G.UIParent:SetSize(1920, 1080)
_G.GameTooltip = { SetOwner = function() end, SetText = function() end, AddLine = function() end, Show = function() end, Hide = function() end }
_G.STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
_G.GetAddOnMetadata = function() return nil end

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

local function ok(cond, msg) if cond then pass(msg) else fail(msg) end end
local function eq(a, b, msg)
    if a == b then pass(msg)
    else fail(("%s  (expected %q, got %q)"):format(msg, tostring(b), tostring(a))) end
end

-- loadfile() chokes on a UTF-8 BOM; read raw bytes, strip it, loadstring().
local function loadProductionFile(path, ...)
    local f = assert(io.open(path, "rb"))
    local src = f:read("*a")
    f:close()
    if src:sub(1, 3) == "\239\187\191" then src = src:sub(4) end
    local chunk = assert(loadstring(src, "@" .. path))
    return chunk(...)
end

-- ============================================================
-- Load the real production files, in real cross-addon load order.
-- _G.CreshChat is never set -- this whole suite exercises the
-- "works without CreshChat" contract.
-- ============================================================
_G.CreshChat = nil

loadProductionFile("shared/Suite.lua", "CreshChat", {})
loadProductionFile("shared/CreshUI.lua", "CreshGames", {})

_G.CreshGamesDB = nil
loadProductionFile("addons/CreshGames/CreshGamesDatabase.lua", "CreshGames", {})
_G.CreshGamesDatabase.Init()

local CG = { version = "0.2.3" }
loadProductionFile("addons/CreshGames/CreshGames.lua", "CreshGames", CG)
loadProductionFile("addons/CreshGames/Games.lua", "CreshGames", CG)
loadProductionFile("addons/CreshGames/SoloGames.lua", "CreshGames", CG)

if not CG.SoloGames or not CG.Games then
    print("FATAL: CG.SoloGames / CG.Games not found after loading production files")
    os.exit(2)
end

local Solo, Games = CG.SoloGames, CG.Games

-- ============================================================
-- 1. BuildWindow: the shell's tab bar and sibling panels exist
-- ============================================================
section("BuildWindow builds the SOLO/MULTIPLAYER/UNLOCKS tab shell")

local frame = Solo:BuildWindow()
ok(frame ~= nil, "BuildWindow() returns a frame")
ok(frame.hubTabButtons and frame.hubTabButtons.SOLO and frame.hubTabButtons.MULTIPLAYER and frame.hubTabButtons.UNLOCKS,
    "all three hub tab buttons exist")
ok(frame.content ~= nil, "frame.content (SOLO panel) exists")
ok(frame.multiPanel ~= nil, "frame.multiPanel (MULTIPLAYER panel) exists")
ok(frame.unlocksPanel ~= nil, "frame.unlocksPanel exists")
eq(frame.content:IsShown(), true, "frame.content starts shown (default SOLO state)")
eq(frame.multiPanel:IsShown(), false, "frame.multiPanel starts hidden")
eq(frame.unlocksPanel:IsShown(), false, "frame.unlocksPanel starts hidden")
eq(CreshGamesDB.gamesHub.activeTab, "SOLO", "gamesHub.activeTab still SOLO before any tab switch")

-- ============================================================
-- 2. SelectHubTab("MULTIPLAYER"): reparents Games' hub into the shell
--    without any CC.UI/CreshChat dependency at all.
-- ============================================================
section("SelectHubTab(MULTIPLAYER) shows the multiplayer hub inside the shell")

Solo:SelectHubTab("MULTIPLAYER")
eq(frame.content:IsShown(), false, "SOLO panel hidden")
eq(frame.statusBar:IsShown(), false, "SOLO status bar hidden")
eq(frame.multiPanel:IsShown(), true, "MULTIPLAYER panel shown")
eq(frame.unlocksPanel:IsShown(), false, "UNLOCKS panel stays hidden")
eq(CreshGamesDB.gamesHub.activeTab, "MULTIPLAYER", "gamesHub.activeTab persisted as MULTIPLAYER")
ok(Games.hub ~= nil, "Games:BuildHub() ran and built the hub")
eq(Games.hub:IsShown(), true, "Games.hub is shown once MULTIPLAYER is selected")
eq(frame.hubTabButtons.MULTIPLAYER.creshActive, true, "MULTIPLAYER tab button marked active")
eq(frame.hubTabButtons.SOLO.creshActive, false, "SOLO tab button no longer marked active")

-- ============================================================
-- 3. SelectHubTab("UNLOCKS"): hides the multiplayer hub and shows the
--    unlocks panel. This test file does not load GamesRewardRegistry.lua/
--    GamesUnlocksCatalog.lua (Phase 5), so CG.UnlocksCatalog is nil here --
--    SelectHubTab's nil-guarded call to it is exactly what's under test;
--    the catalogue's own content is covered end-to-end, with the real
--    module loaded, by GamesUnlocksCatalogTests.lua.
-- ============================================================
section("SelectHubTab(UNLOCKS) hides MULTIPLAYER and shows the unlocks panel")

ok(CG.UnlocksCatalog == nil, "sanity: this test environment does not load Phase 5's catalogue module")
local okUnlocks, errUnlocks = pcall(function() Solo:SelectHubTab("UNLOCKS") end)
ok(okUnlocks, "SelectHubTab(UNLOCKS) does not error when CG.UnlocksCatalog is absent (err: " .. tostring(not okUnlocks and errUnlocks or "") .. ")")
eq(frame.multiPanel:IsShown(), false, "MULTIPLAYER panel hidden again")
eq(Games.hub:IsShown(), false, "Games.hub explicitly hidden (Games:SetHubVisible(false))")
eq(frame.unlocksPanel:IsShown(), true, "UNLOCKS panel shown")
eq(CreshGamesDB.gamesHub.activeTab, "UNLOCKS", "gamesHub.activeTab persisted as UNLOCKS")

-- ============================================================
-- 4. SelectHubTab("SOLO") returns cleanly.
-- ============================================================
section("SelectHubTab(SOLO) returns to the solo catalog")

Solo:SelectHubTab("SOLO")
eq(frame.content:IsShown(), true, "SOLO panel shown again")
eq(frame.unlocksPanel:IsShown(), false, "UNLOCKS panel hidden")
eq(Games.hub:IsShown(), false, "Games.hub stays hidden while on SOLO")
eq(CreshGamesDB.gamesHub.activeTab, "SOLO", "gamesHub.activeTab back to SOLO")

-- ============================================================
-- 5. Games:OpenHub(target) -- the "OpenGames" Suite service's real target --
--    forces the MULTIPLAYER tab and sets the challenge target, all without
--    CC.UI/CreshChat's own drawer.
-- ============================================================
section("Games:OpenHub(target) routes to the MULTIPLAYER tab and sets the target")

-- Games:RefreshHub() (pre-existing, unrelated to Phase 4) always re-syncs
-- targetName against Games:GetTargets(), clearing it back to nil if the
-- requested name isn't a real, ping-able entry -- so a made-up name needs a
-- source GetTargets() actually reads from. This is the one section in the
-- file that needs a CreshChat whisper-conversation stub for that reason;
-- every other section in this suite runs with _G.CreshChat left nil.
_G.CreshChat = { db = { conversations = { Testperson = true, AnotherPerson = true } } }

Games:OpenHub("Testperson")
eq(CreshGamesDB.gamesHub.activeTab, "MULTIPLAYER", "OpenHub forced the MULTIPLAYER tab")
eq(Games.targetName, "Testperson", "the challenge target was applied")

-- Suite-registered "OpenGames" service reaches the same place end-to-end.
Solo:SelectHubTab("SOLO")
local openGames = _G.CreshSuite:GetService("OpenGames")
ok(openGames ~= nil, "OpenGames service is registered")
openGames("AnotherPerson")
eq(CreshGamesDB.gamesHub.activeTab, "MULTIPLAYER", "OpenGames service opens the MULTIPLAYER tab")
eq(Games.targetName, "AnotherPerson", "OpenGames service forwards the target")

_G.CreshChat = nil

-- ============================================================
-- 6. Solo:OpenHub() -- the "OpenSoloGames" Suite service's real target --
--    restores whichever tab was last active instead of always forcing SOLO.
-- ============================================================
section("Solo:OpenHub() restores the last active top-level tab")

CreshGamesDB.gamesHub.activeTab = "MULTIPLAYER"
Solo:OpenHub()
eq(frame.multiPanel:IsShown(), true, "OpenHub restored the MULTIPLAYER tab (not forced back to SOLO)")

CreshGamesDB.gamesHub.activeTab = "SOLO"
Solo.activeGame = "FROGGER"  -- simulate a stale in-progress game before reopening
Solo:OpenHub()
eq(frame.content:IsShown(), true, "OpenHub shows the SOLO panel when SOLO was last active")
ok(Solo.activeGame == nil, "OpenHub restoring SOLO resets to the catalog grid (matches pre-Phase-4 behaviour)")

local openSolo = _G.CreshSuite:GetService("OpenSoloGames")
ok(openSolo ~= nil, "OpenSoloGames service is registered")
CreshGamesDB.gamesHub.activeTab = "UNLOCKS"
openSolo()
eq(frame.unlocksPanel:IsShown(), true, "OpenSoloGames service restores UNLOCKS when that was last active")

-- ============================================================
-- 7. Background-tab safety guard: OnUpdate/OnKeyDown/OnKeyUp must not reach
--    the active solo view while the SOLO tab isn't the one on screen.
-- ============================================================
section("A solo game does not keep ticking (or eating input) once another tab is selected")

Solo:SelectHubTab("SOLO")
local updateCalls, keyDownCalls, keyUpCalls = 0, 0, 0
Solo.views.FROGGER = {
    OnUpdate  = function() updateCalls = updateCalls + 1 end,
    OnKeyDown = function() keyDownCalls = keyDownCalls + 1 end,
    OnKeyUp   = function() keyUpCalls = keyUpCalls + 1 end,
}
Solo.activeGame = "FROGGER"

Solo:SelectHubTab("MULTIPLAYER")
frame:GetScript("OnUpdate")(frame, 0.016)
frame:GetScript("OnKeyDown")(frame, "W")
frame:GetScript("OnKeyUp")(frame, "W")
eq(updateCalls, 0, "OnUpdate does not reach the background solo view while MULTIPLAYER is shown")
eq(keyDownCalls, 0, "OnKeyDown does not reach the background solo view while MULTIPLAYER is shown")
eq(keyUpCalls, 0, "OnKeyUp does not reach the background solo view while MULTIPLAYER is shown")

Solo:SelectHubTab("SOLO")
frame:GetScript("OnUpdate")(frame, 0.016)
frame:GetScript("OnKeyDown")(frame, "W")
frame:GetScript("OnKeyUp")(frame, "W")
eq(updateCalls, 1, "OnUpdate reaches the active solo view once SOLO is visible again")
eq(keyDownCalls, 1, "OnKeyDown reaches the active solo view once SOLO is visible again")
eq(keyUpCalls, 1, "OnKeyUp reaches the active solo view once SOLO is visible again")

Solo.activeGame = nil
Solo.views.FROGGER = nil

-- ============================================================
-- 8. StartGame always lands on the SOLO tab, even if MULTIPLAYER/UNLOCKS
--    was showing when it was called (e.g. via CreshGamesAPI.OpenGameMastery
--    while the shell was already open on a different tab).
-- ============================================================
section("StartGame forces the SOLO tab regardless of which tab was previously active")

Solo:SelectHubTab("MULTIPLAYER")
local okStart, errStart = pcall(function() return Solo:StartGame("FROGGER") end)
ok(okStart, "StartGame('FROGGER') does not error (err: " .. tostring(not okStart and errStart or "") .. ")")
eq(frame.content:IsShown(), true, "starting a solo game switches back to the SOLO panel")
eq(CreshGamesDB.gamesHub.activeTab, "SOLO", "gamesHub.activeTab updated to SOLO")
eq(Solo.activeGame, "FROGGER", "FROGGER is now the active solo game")

-- ============================================================
-- Summary
-- ============================================================
print(("\n=== Results: %d passed, %d failed ==="):format(PASS, FAIL))
if FAIL > 0 then os.exit(1) end
