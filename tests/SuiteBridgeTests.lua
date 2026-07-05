-- SuiteBridgeTests.lua
-- Lua 5.1 static/mock tests for shared/Suite.lua
-- Usage: lua SuiteBridgeTests.lua <path-to-Suite.lua>

-- ============================================================
-- WoW API stubs
-- ============================================================
local _bridgeFrame = nil

function CreateFrame(_, _name)
    local f = { _events = {}, _scripts = {} }
    function f:RegisterEvent(event)  self._events[event] = true end
    function f:SetScript(hook, fn)   self._scripts[hook] = fn   end
    function f:Fire(event, ...)
        local fn = self._scripts["OnEvent"]
        if fn then fn(self, event, ...) end
    end
    _bridgeFrame = f
    return f
end

function GetTime() return 0 end

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

local function ok(cond, msg)
    if cond then pass(msg) else fail(msg) end
end

local function eq(a, b, msg)
    if a == b then
        pass(msg)
    else
        fail(("%s  (expected %q, got %q)"):format(msg, tostring(b), tostring(a)))
    end
end

-- ============================================================
-- Load Suite.lua
-- ============================================================
local suitePath = (arg and arg[1]) or "shared/Suite.lua"
dofile(suitePath)
local Suite = _G.CreshSuite

-- ============================================================
-- 1. Registration
-- ============================================================
section("Registration")

ok(Suite ~= nil,                              "CreshSuite global is set")
eq(type(Suite.RegisterProduct),  "function",  "RegisterProduct present")
eq(type(Suite.GetProduct),       "function",  "GetProduct present")
eq(type(Suite.RegisterService),  "function",  "RegisterService present")
eq(type(Suite.GetService),       "function",  "GetService present")
eq(type(Suite.RegisterSettingsProvider), "function", "RegisterSettingsProvider present")
eq(type(Suite.GetSettingsProvider),      "function", "GetSettingsProvider present")
eq(type(Suite.Subscribe),        "function",  "Subscribe present")
eq(type(Suite.Publish),          "function",  "Publish present")
eq(type(Suite.Notify),           "function",  "Notify present")

Suite:RegisterProduct("TestAddon", "1.0", { ping = function() return "pong" end })
local prod = Suite:GetProduct("TestAddon")
ok(prod ~= nil,                  "GetProduct returns registered entry")
eq(prod.name,    "TESTADDON",    "product name is upper-cased")
eq(prod.version, "1.0",          "product version stored")
eq(type(prod.api.ping), "function", "product api stored")

ok(Suite:GetProduct("MISSING") == nil, "GetProduct nil for unknown key")
ok(Suite:GetProduct("")        == nil, "GetProduct nil for empty key")

eq(type(Suite.IsProductLoaded), "function", "IsProductLoaded present")
ok(Suite:IsProductLoaded("TestAddon") == true,  "IsProductLoaded true for a registered product")
ok(Suite:IsProductLoaded("testaddon") == true,  "IsProductLoaded is case-insensitive, like GetProduct")
ok(Suite:IsProductLoaded("MISSING")   == false, "IsProductLoaded false for an unregistered product")
ok(Suite:IsProductLoaded("")          == false, "IsProductLoaded false for an empty name")

Suite:RegisterService("greet", function(name) return "hi " .. name end)
local svc = Suite:GetService("greet")
eq(type(svc), "function",  "GetService returns function")
eq(svc("world"), "hi world", "service is callable")
ok(Suite:GetService("MISSING") == nil, "GetService nil for unknown key")

local provCalled = false
Suite:RegisterSettingsProvider("MyAddon", function() provCalled = true end)
local prov = Suite:GetSettingsProvider("MyAddon")
eq(type(prov), "function",  "GetSettingsProvider returns function")
prov()
ok(provCalled,               "settings provider is callable")
ok(Suite:GetSettingsProvider("MISSING") == nil, "GetSettingsProvider nil for unknown")

-- ============================================================
-- 2. Pub/Sub
-- ============================================================
section("Pub/Sub")

local received = {}
Suite:Subscribe("T_BASIC", function(a, b)
    received[#received + 1] = { a = a, b = b }
end)
Suite:Publish("T_BASIC", "hello", 42)
eq(#received, 1,        "subscriber called once")
eq(received[1].a, "hello", "first arg received")
eq(received[1].b, 42,      "second arg received")

local called = {}
Suite:Subscribe("T_MULTI", function() called[#called + 1] = "first" end)
Suite:Subscribe("T_MULTI", function() called[#called + 1] = "second" end)
Suite:Publish("T_MULTI")
eq(#called, 2,        "multiple subscribers all fired")
eq(called[1], "first",  "first subscriber fires first")
eq(called[2], "second", "second subscriber fires second")

Suite:Publish("T_NOSUBS")
pass("Publish on topic with no subscribers does not error")

-- Snapshot: sub registered during Publish does not fire in the same batch
local snapCount = 0
Suite:Subscribe("T_SNAP", function()
    snapCount = snapCount + 1
    if snapCount == 1 then
        Suite:Subscribe("T_SNAP", function() snapCount = snapCount + 100 end)
    end
end)
Suite:Publish("T_SNAP")
eq(snapCount, 1, "sub registered inside Publish does not fire in same batch")

-- Notify
local notifFired = false
Suite:Subscribe("NOTIFY:MYADDON:PING", function() notifFired = true end)
Suite:Notify("MyAddon", "PING")
ok(notifFired, "Notify routes to NOTIFY:<ADDON>:<EVENT>")

-- ============================================================
-- 3. Late addon loading via ADDON_LOADED
-- ============================================================
section("Late loading via ADDON_LOADED")

ok(_bridgeFrame ~= nil,                         "bridge frame was created")
ok(_bridgeFrame._events["ADDON_LOADED"] == true, "bridge frame registered ADDON_LOADED")

local lateNames = {}
Suite:Subscribe("ADDON_LOADED", function(n) lateNames[#lateNames + 1] = n end)
_bridgeFrame:Fire("ADDON_LOADED", "CreshGames")
eq(#lateNames, 1,            "ADDON_LOADED fires Publish")
eq(lateNames[1], "CreshGames", "addon name forwarded correctly")

local notifyLoaded = false
Suite:Subscribe("NOTIFY:CRESHGAMES:LOADED", function() notifyLoaded = true end)
_bridgeFrame:Fire("ADDON_LOADED", "CreshGames")
ok(notifyLoaded, "ADDON_LOADED also fires Notify(<addon>, LOADED)")

-- ============================================================
-- 4. Callback isolation
-- ============================================================
section("Callback isolation")

local isoLog = {}
Suite:Subscribe("T_ISO", function() error("intentional error") end)
Suite:Subscribe("T_ISO", function() isoLog[#isoLog + 1] = "ran" end)
Suite:Publish("T_ISO")
eq(#isoLog, 1, "second callback runs despite first throwing")

local logs = Suite:GetLogs()
local errFound = false
for _, e in ipairs(logs) do
    if e.level == "ERROR" and e.msg:find("callback error") then
        errFound = true; break
    end
end
ok(errFound, "callback error is recorded in Suite log")

-- ============================================================
-- 5. Idempotency and version mismatch
-- ============================================================
section("Idempotency and version mismatch")

local suiteRef = _G.CreshSuite
dofile(suitePath)
ok(_G.CreshSuite == suiteRef, "re-loading Suite.lua same version is idempotent (same table)")

-- Version mismatch: install a fake higher-version Suite, dofile should warn + keep it
local logsBefore = #Suite:GetLogs()
local fakeSuite = { BRIDGE_VERSION = 99, _warn = Suite._warn }
_G.CreshSuite = fakeSuite
dofile(suitePath)
_G.CreshSuite = suiteRef   -- restore

local warnFound = false
local logsAfter = Suite:GetLogs()
for i = logsBefore + 1, #logsAfter do
    if logsAfter[i].level == "WARN" and logsAfter[i].msg:find("mismatch") then
        warnFound = true; break
    end
end
ok(warnFound, "version mismatch emits WARN via _warn")
ok(_G.CreshSuite == suiteRef, "running suite preserved after version mismatch dofile")

-- ============================================================
-- Summary
-- ============================================================
print(("\n=== Results: %d passed, %d failed ==="):format(PASS, FAIL))
if FAIL > 0 then os.exit(1) end
