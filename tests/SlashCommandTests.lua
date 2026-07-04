-- SlashCommandTests.lua
-- Regression test for the /cc slash-command dispatch chain.
--
-- Core.lua defines CC:HandleSlashCommand as an if/elseif chain, then
-- Developer.lua monkey-patches it (saves the original, wraps it, falls
-- through via `return originalHandleSlashCommand(self, input)` for any
-- command it does not recognise). This test dofiles both REAL production
-- files (not a reimplemented copy) so a future regression in the actual
-- dispatch chain shows up here, and proves:
--   * /cc notifytest reaches CC:RunTest (the notification preview), not the
--     developer test suite
--   * /cc test on/run/off reach the developer test suite, not RunTest
--   * /cc progress and /cc hub reach the real Progress Hub, not the
--     developer ProgressRouter diagnostics
--   * /cc devprogress reaches the developer ProgressRouter diagnostics
--   * stacking a further slash-command wrapper on top (the same pattern
--     Developer.lua itself uses) does not re-break any of the above
--
-- Usage: lua tests/SlashCommandTests.lua [Core.lua] [Developer.lua]

-- ============================================================
-- Minimal WoW API stubs (just enough for Core.lua / Developer.lua to
-- dofile and register without erroring; none of these are exercised by
-- the assertions below).
-- ============================================================

function CreateFrame()
    return { SetScript = function() end, RegisterEvent = function() end, RegisterForDrag = function() end }
end
function time() return 0 end
function GetTime() return 0 end
_G.C_Timer = { After = function() end }
_G.hooksecurefunc = function() end
_G.SlashCmdList = {}
_G.UIParent = { GetWidth = function() return 1920 end, GetHeight = function() return 1080 end }
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

-- ============================================================
-- Load the real production files
-- ============================================================

local corePath      = (arg and arg[1]) or "addons/CreshChat/Core.lua"
local developerPath = (arg and arg[2]) or "addons/CreshChat/Developer.lua"

-- WoW invokes every file in a TOC with (addonName, addonTable), the same
-- addonTable shared across all of that addon's files. dofile() supplies no
-- varargs at all, which would make Developer.lua's `local _, CC = ...` see a
-- nil CC and bail out immediately (Developer.lua:1-2) -- so load + call each
-- chunk explicitly with the vararg pair, exactly like the real loader does.
local function loadProductionFile(path, ...)
    local chunk = assert(loadfile(path))
    return chunk(...)
end

loadProductionFile(corePath, "CreshChat", nil)
loadProductionFile(developerPath, "CreshChat", _G.CreshChat)

local CC = _G.CreshChat
if not CC or not CC.HandleSlashCommand or not CC.Developer then
    print("FATAL: CreshChat.HandleSlashCommand / CreshChat.Developer not found after loading production files")
    os.exit(2)
end

-- ============================================================
-- Spy helpers
-- ============================================================

local calls

local function resetSpies()
    calls = { runTest = 0, handleTest = nil, handleProgress = nil, progressHubToggle = 0, extra = 0 }
    CC.RunTest = function() calls.runTest = calls.runTest + 1 end
    CC.Developer.HandleTestCommand = function(_, a) calls.handleTest = a end
    CC.Developer.HandleProgressCommand = function(_, a) calls.handleProgress = a end
    -- /cc progress and /cc hub resolve the real Progress Hub through the
    -- CreshSuite service registry (Core.lua:GetService("OpenProgressHub")),
    -- not a direct CC.ProgressHub field access.
    _G.CreshSuite = {
        GetService = function(_, name)
            if name == "OpenProgressHub" then
                return function() calls.progressHubToggle = calls.progressHubToggle + 1 end
            end
            return nil
        end,
    }
end

-- ============================================================
-- 1. /cc notifytest reaches CC:RunTest, not the developer test suite
-- ============================================================
section("/cc notifytest -> CC:RunTest")

resetSpies()
CC:HandleSlashCommand("notifytest")
ok(calls.runTest == 1, "RunTest invoked once")
ok(calls.handleTest == nil, "Developer:HandleTestCommand NOT invoked")

-- ============================================================
-- 2. /cc test on|run|off reach the developer test suite, not RunTest
-- ============================================================
section("/cc test on|run|off -> Developer:HandleTestCommand")

resetSpies()
CC:HandleSlashCommand("test on")
ok(calls.handleTest == "on", "HandleTestCommand invoked with arg 'on'")
ok(calls.runTest == 0, "RunTest NOT invoked")

resetSpies()
CC:HandleSlashCommand("test run")
ok(calls.handleTest == "run", "HandleTestCommand invoked with arg 'run'")
ok(calls.runTest == 0, "RunTest NOT invoked")

resetSpies()
CC:HandleSlashCommand("test off")
ok(calls.handleTest == "off", "HandleTestCommand invoked with arg 'off'")
ok(calls.runTest == 0, "RunTest NOT invoked")

-- ============================================================
-- 3. /cc progress and /cc hub reach the real Progress Hub
-- ============================================================
section("/cc progress and /cc hub -> ProgressHub:Toggle")

resetSpies()
CC:HandleSlashCommand("progress")
ok(calls.progressHubToggle == 1, "ProgressHub:Toggle invoked for /cc progress")
ok(calls.handleProgress == nil, "Developer:HandleProgressCommand NOT invoked")

resetSpies()
CC:HandleSlashCommand("hub")
ok(calls.progressHubToggle == 1, "ProgressHub:Toggle invoked for /cc hub")
ok(calls.handleProgress == nil, "Developer:HandleProgressCommand NOT invoked")

-- ============================================================
-- 4. /cc devprogress reaches the developer ProgressRouter diagnostics
-- ============================================================
section("/cc devprogress -> Developer:HandleProgressCommand")

resetSpies()
CC:HandleSlashCommand("devprogress")
ok(calls.handleProgress == "", "HandleProgressCommand invoked (empty arg)")
ok(calls.progressHubToggle == 0, "ProgressHub:Toggle NOT invoked")

resetSpies()
CC:HandleSlashCommand("devprogress test")
ok(calls.handleProgress == "test", "HandleProgressCommand invoked with arg 'test'")
ok(calls.progressHubToggle == 0, "ProgressHub:Toggle NOT invoked")

-- ============================================================
-- 5. A later-loaded wrapper (same monkey-patch shape Developer.lua uses)
--    for an unrelated command must not re-shadow the routing above.
-- ============================================================
section("Stacking a further wrapper does not re-shadow existing routing")

local previousHandler = CC.HandleSlashCommand
function CC:HandleSlashCommand(input)
    local command = string.lower(string.match(tostring(input or ""), "^(%S*)") or "")
    if command == "extra" then
        calls.extra = calls.extra + 1
        return
    end
    return previousHandler(self, input)
end

resetSpies()
CC:HandleSlashCommand("extra")
ok(calls.extra == 1, "new wrapper's own command still works")

resetSpies()
CC:HandleSlashCommand("notifytest")
ok(calls.runTest == 1, "notifytest still reaches RunTest after stacking a new wrapper")

resetSpies()
CC:HandleSlashCommand("test run")
ok(calls.handleTest == "run", "test run still reaches the dev suite after stacking a new wrapper")

resetSpies()
CC:HandleSlashCommand("progress")
ok(calls.progressHubToggle == 1, "progress still reaches ProgressHub after stacking a new wrapper")

resetSpies()
CC:HandleSlashCommand("devprogress")
ok(calls.handleProgress == "", "devprogress still reaches dev diagnostics after stacking a new wrapper")

-- ============================================================
-- Summary
-- ============================================================
print(("\n=== Results: %d passed, %d failed ==="):format(PASS, FAIL))
if FAIL > 0 then os.exit(1) end
