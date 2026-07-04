-- SettingsShellTests.lua
-- Tests the addon-presence detection logic used by the Settings product tab shell.
-- The detection function is inlined here because Settings.lua requires the WoW
-- addon environment (local _, CC = ...) and cannot be loaded standalone.
-- Run: lua tests/SettingsShellTests.lua

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
-- Detection function (mirrors Settings.lua detectAddonStatus exactly)
-- ============================================================

local function detectAddonStatus(addonName, minVer)
    if IsAddOnLoaded and IsAddOnLoaded(addonName) then
        if minVer and _G.CreshSuite then
            local p = _G.CreshSuite.GetProduct and _G.CreshSuite:GetProduct(addonName)
            local ver = p and tonumber(p.version) or 0
            if ver > 0 and ver < minVer then return "incompatible", tostring(p.version) end
        end
        return "loaded"
    end
    if GetAddOnInfo then
        local name, _, _, loadable, reason = GetAddOnInfo(addonName)
        if name == nil then return "missing" end
        if reason == "DISABLED" then return "disabled" end
        if reason == "MISSING"  then return "missing"  end
        if not loadable and reason then return "incompatible", reason end
        if not loadable then return "disabled" end
    end
    return "missing"
end

-- ============================================================
-- Mock helpers
-- ============================================================

local function resetGlobals()
    IsAddOnLoaded = nil
    GetAddOnInfo  = nil
    _G.CreshSuite = nil
end

local function mockLoaded(...)
    local loaded = {}
    for _, name in ipairs({...}) do loaded[name] = true end
    IsAddOnLoaded = function(name) return loaded[name] == true end
end

-- info[name] = { name, title, notes, loadable, reason }
local function mockInfo(tbl)
    GetAddOnInfo = function(name)
        local row = tbl[name]
        if not row then return nil, nil, nil, nil, nil end
        return row[1], row[2], row[3], row[4], row[5]
    end
end

local function mockSuite(products, providers)
    local suite = { _providers = providers or {} }
    function suite:GetProduct(name) return products[name] end
    function suite:GetSettingsProvider(name) return self._providers[name] end
    _G.CreshSuite = suite
end

-- ============================================================
-- 1. All three addons loaded
-- ============================================================
section("All three loaded")

resetGlobals()
mockLoaded("CreshChat", "CreshGames", "CreshCollect")
mockSuite({ CreshGames = { version = "0.2.3" }, CreshCollect = { version = "0.2.3" } })

eq(detectAddonStatus("CreshChat"),    "loaded", "CreshChat = loaded")
eq(detectAddonStatus("CreshGames"),   "loaded", "CreshGames = loaded")
eq(detectAddonStatus("CreshCollect"), "loaded", "CreshCollect = loaded")

-- ============================================================
-- 2. Only CreshChat loaded; others not installed
-- ============================================================
section("Only CreshChat loaded (others missing via MISSING reason)")

resetGlobals()
mockLoaded("CreshChat")
mockInfo({
    CreshGames   = { "CreshGames",   nil, nil, false, "MISSING" },
    CreshCollect = { "CreshCollect", nil, nil, false, "MISSING" },
})

eq(detectAddonStatus("CreshChat"),    "loaded",  "CreshChat = loaded")
eq(detectAddonStatus("CreshGames"),   "missing", "CreshGames = missing")
eq(detectAddonStatus("CreshCollect"), "missing", "CreshCollect = missing")

-- ============================================================
-- 3. CreshGames disabled, CreshCollect missing
-- ============================================================
section("CreshGames disabled, CreshCollect missing")

resetGlobals()
mockLoaded("CreshChat")
mockInfo({
    CreshGames   = { "CreshGames",   "CreshGames", "", false, "DISABLED" },
    CreshCollect = { "CreshCollect", nil, nil, false, "MISSING" },
})

eq(detectAddonStatus("CreshGames"),   "disabled", "CreshGames = disabled")
eq(detectAddonStatus("CreshCollect"), "missing",  "CreshCollect = missing")

-- ============================================================
-- 4. CreshGames missing (nil name), CreshCollect disabled
-- ============================================================
section("CreshGames missing (nil from GetAddOnInfo), CreshCollect disabled")

resetGlobals()
mockLoaded("CreshChat")
mockInfo({
    -- CreshGames not in table at all -> returns all nils
    CreshCollect = { "CreshCollect", "CreshCollect", "", false, "DISABLED" },
})

eq(detectAddonStatus("CreshGames"),   "missing",  "CreshGames = missing (nil name)")
eq(detectAddonStatus("CreshCollect"), "disabled", "CreshCollect = disabled")

-- ============================================================
-- 5. Both missing and no GetAddOnInfo API
-- ============================================================
section("GetAddOnInfo unavailable (fallback)")

resetGlobals()
mockLoaded("CreshChat")
-- GetAddOnInfo is nil

eq(detectAddonStatus("CreshGames"),   "missing", "CreshGames = missing (no API)")
eq(detectAddonStatus("CreshCollect"), "missing", "CreshCollect = missing (no API)")

-- ============================================================
-- 6. CreshGames loaded but incompatible version (via Suite product)
-- ============================================================
section("CreshGames incompatible version (Suite product version check)")

resetGlobals()
mockLoaded("CreshChat", "CreshGames")
mockSuite({ CreshGames = { version = "0.1.5" } })

local s6, d6 = detectAddonStatus("CreshGames", 0.2)
eq(s6, "incompatible", "CreshGames = incompatible (0.1.5 < 0.2 required)")
ok(d6 ~= nil,          "detail returned")
ok(tostring(d6):find("0.1") ~= nil, "detail contains old version string")

-- Without a minVer requirement, same addon is just "loaded"
eq(detectAddonStatus("CreshGames"), "loaded", "CreshGames = loaded when no minVer")

-- ============================================================
-- 7. Interface version mismatch (GetAddOnInfo reason = INTERFACE_VERSION)
-- ============================================================
section("INTERFACE_VERSION mismatch")

resetGlobals()
mockLoaded("CreshChat")
mockInfo({
    CreshGames = { "CreshGames", "CreshGames", "", false, "INTERFACE_VERSION" },
})

local s7, d7 = detectAddonStatus("CreshGames")
eq(s7, "incompatible",       "CreshGames = incompatible (INTERFACE_VERSION)")
eq(d7, "INTERFACE_VERSION",  "detail = INTERFACE_VERSION")

-- ============================================================
-- 8. Loaded but no Suite registration (minVer ignored safely)
-- ============================================================
section("CreshGames loaded, no CreshSuite global")

resetGlobals()
mockLoaded("CreshChat", "CreshGames")
-- _G.CreshSuite is nil

eq(detectAddonStatus("CreshGames", 0.2), "loaded",
    "CreshGames = loaded (no Suite, version check skipped)")

-- Suite present but product not registered -> still loaded
mockSuite({})
eq(detectAddonStatus("CreshGames", 0.2), "loaded",
    "CreshGames = loaded (product absent from Suite, version = 0)")

-- Suite present, version = 0 (unset) -> still loaded (0 < minVer but skipped when ver==0)
mockSuite({ CreshGames = { version = "0" } })
eq(detectAddonStatus("CreshGames", 0.2), "loaded",
    "CreshGames = loaded (version=0 treated as unset, not incompatible)")

-- ============================================================
-- 9. loadable=false with nil reason (edge case: installed, reason unknown)
-- ============================================================
section("loadable=false, nil reason")

resetGlobals()
mockLoaded("CreshChat")
mockInfo({
    CreshGames = { "CreshGames", "CreshGames", "", false, nil },
})

eq(detectAddonStatus("CreshGames"), "disabled",
    "CreshGames = disabled (loadable=false, reason=nil)")

-- ============================================================
-- 10. All three present, only CreshChat loaded (both others disabled)
-- ============================================================
section("All installed, only CreshChat loaded")

resetGlobals()
mockLoaded("CreshChat")
mockInfo({
    CreshGames   = { "CreshGames",   "CreshGames",   "", false, "DISABLED" },
    CreshCollect = { "CreshCollect", "CreshCollect", "", false, "DISABLED" },
})

eq(detectAddonStatus("CreshChat"),    "loaded",   "CreshChat = loaded")
eq(detectAddonStatus("CreshGames"),   "disabled", "CreshGames = disabled")
eq(detectAddonStatus("CreshCollect"), "disabled", "CreshCollect = disabled")

-- ============================================================
-- 11. Provider registration detection
-- ============================================================
section("Provider registration (Suite:GetSettingsProvider)")

resetGlobals()
mockLoaded("CreshChat", "CreshGames", "CreshCollect")
mockSuite(
    { CreshGames = { version = "0.2.3" }, CreshCollect = { version = "0.2.3" } },
    { CreshGames = function() end }   -- CreshGames has a provider; CreshCollect does not
)

local suite = _G.CreshSuite
ok(suite:GetSettingsProvider("CreshGames")   ~= nil, "CreshGames provider registered")
ok(suite:GetSettingsProvider("CreshCollect") == nil, "CreshCollect provider absent (placeholder only)")

-- ============================================================
-- Summary
-- ============================================================
print(("\n=== Results: %d passed, %d failed ==="):format(PASS, FAIL))
if FAIL > 0 then os.exit(1) end
