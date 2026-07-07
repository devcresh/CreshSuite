-- SettingsShellTests.lua
-- Tests the addon-presence detection logic used by the Settings product tab shell,
-- plus (Phase 6) the settings-search matching predicate and lazy-page-build
-- flag logic, mirrored inline for the same reason as detectAddonStatus below.
-- The detection function is inlined here because Settings.lua requires the WoW
-- addon environment (local _, CC = ...) and cannot be loaded standalone. The
-- semantic-version comparison it depends on is NOT reimplemented here though:
-- it dofiles the real addons/CreshChat/VersionCompare.lua so a regression in
-- production version comparison shows up as a test failure instead of being
-- masked by a second, independently-maintained copy.
--
-- The new-page-structure check at the end DOES load the real production
-- GamesSettings.lua/CollectSettings.lua: registering a settings provider spec
-- only stores page tables (the build(builder) closures are never invoked at
-- registration time), so this needs only a minimal _G.CreshSuite stub, no
-- WoW widget/frame mocking at all.
-- Run: lua tests/SettingsShellTests.lua [path-to-VersionCompare.lua]

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
-- Shared production helper (real file, not a re-implementation)
-- ============================================================

local versionComparePath = (arg and arg[1]) or "addons/CreshChat/VersionCompare.lua"
dofile(versionComparePath)
local VC = _G.CreshChatVersionCompare

-- ============================================================
-- Detection function (mirrors Settings.lua detectAddonStatus exactly,
-- including delegating version comparison to VC instead of tonumber())
-- ============================================================

local function detectAddonStatus(addonName, minVer)
    if IsAddOnLoaded and IsAddOnLoaded(addonName) then
        if minVer and _G.CreshSuite then
            local p = _G.CreshSuite.GetProduct and _G.CreshSuite:GetProduct(addonName)
            local verStr = p and p.version
            if verStr and not VC.IsUnset(verStr) then
                local cmp = VC.Compare(verStr, minVer)
                if cmp and cmp < 0 then return "incompatible", tostring(verStr) end
            end
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

-- minVer "0.2.0" here doubles as coverage for "0.2.3 satisfies a 0.2.0 requirement".
eq(detectAddonStatus("CreshChat"),    "loaded", "CreshChat = loaded")
eq(detectAddonStatus("CreshGames", "0.2.0"),   "loaded", "CreshGames = loaded")
eq(detectAddonStatus("CreshCollect", "0.2.0"), "loaded", "CreshCollect = loaded")

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

local s6, d6 = detectAddonStatus("CreshGames", "0.2.0")
eq(s6, "incompatible", "CreshGames = incompatible (0.1.5 < 0.2.0 required)")
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

eq(detectAddonStatus("CreshGames", "0.2.0"), "loaded",
    "CreshGames = loaded (no Suite, version check skipped)")

-- Suite present but product not registered -> still loaded
mockSuite({})
eq(detectAddonStatus("CreshGames", "0.2.0"), "loaded",
    "CreshGames = loaded (product absent from Suite, version = 0)")

-- Suite present, version = 0 (unset) -> still loaded (0 < minVer but skipped when ver==0)
mockSuite({ CreshGames = { version = "0" } })
eq(detectAddonStatus("CreshGames", "0.2.0"), "loaded",
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
-- 12. Phase 6: settings search matching (mirrors Settings:Search's
--     provider-branch predicate: case-insensitive substring over
--     label + desc + keywords -- pure logic, no widgets involved)
-- ============================================================
section("Search: label/desc/keywords matching")

local function searchPages(pages, query)
    query = string.lower(tostring(query or ""))
    if query == "" then return {} end
    local matches = {}
    for _, page in ipairs(pages) do
        local haystack = string.lower((page.label or "") .. " " .. (page.desc or "") .. " " .. (page.keywords or ""))
        if string.find(haystack, query, 1, true) then matches[#matches + 1] = page.key end
    end
    return matches
end

local samplePages = {
    { key = "GENERAL", label = "General", desc = "Launcher preferences.", keywords = "launcher quick button" },
    { key = "GAMEPLAY", label = "Gameplay", desc = "Music and Tetris defaults.", keywords = "audio sound tetris cpu solo multiplayer unlocks" },
    { key = "ADVANCED", label = "Advanced", desc = "Reset data.", keywords = "reset delete stats" },
}

local function keyIn(matches, key)
    for _, k in ipairs(matches) do if k == key then return true end end
    return false
end

ok(keyIn(searchPages(samplePages, "tetris"), "GAMEPLAY"), "keyword match finds the right page")
ok(keyIn(searchPages(samplePages, "GENERAL"), "GENERAL"), "label match is case-insensitive")
ok(keyIn(searchPages(samplePages, "reset"), "ADVANCED"), "desc/keyword match finds Advanced")
eq(#searchPages(samplePages, "zzz_no_match"), 0, "no match returns an empty list")
eq(#searchPages(samplePages, ""), 0, "empty query returns an empty list (no results flyout)")

-- ============================================================
-- 13. Phase 6: lazy page-build flag (mirrors Settings:EnsurePageBuilt /
--     EnsureProductPageBuilt: build a page's content at most once, on
--     first visit, not eagerly for every page)
-- ============================================================
section("Lazy build: a page's builder runs at most once, only when visited")

local function ensureBuilt(builtFlags, key, builders, callLog)
    if builtFlags[key] then return end
    builtFlags[key] = true
    if builders[key] then builders[key](); callLog[#callLog + 1] = key end
end

local built, calls = {}, {}
local builders = {
    GENERAL = function() end,
    GAMEPLAY = function() end,
    ADVANCED = function() end,
}
eq(#calls, 0, "sanity: nothing built before any page is visited")
ensureBuilt(built, "GENERAL", builders, calls)
eq(#calls, 1, "visiting GENERAL builds it exactly once")
ensureBuilt(built, "GENERAL", builders, calls)
eq(#calls, 1, "revisiting GENERAL does not rebuild it")
ensureBuilt(built, "GAMEPLAY", builders, calls)
eq(#calls, 2, "visiting a second page builds only that page")
ok(not built.ADVANCED, "a never-visited page is never built")

-- ============================================================
-- 14. Phase 6: CreshGames/CreshCollect provider page structure matches the
--     new consolidated page lists. Loads the REAL production files -- no
--     frame/widget mocking needed since RegisterSettingsProvider only
--     stores page tables (build closures are never invoked here).
-- ============================================================
section("Provider page structure: CreshGames (9 -> 4) and CreshCollect (8 -> 5)")

local function loadProductionFile(path, ...)
    local f = assert(io.open(path, "rb"))
    local src = f:read("*a")
    f:close()
    if src:sub(1, 3) == "\239\187\191" then src = src:sub(4) end
    local chunk = assert(loadstring(src, "@" .. path))
    return chunk(...)
end

local function pageKeys(spec)
    local keys = {}
    for _, page in ipairs(spec.pages) do keys[#keys + 1] = page.key end
    return keys
end

local function sameKeys(actual, expected, label)
    eq(#actual, #expected, label .. ": page count matches")
    for i, key in ipairs(expected) do
        eq(actual[i], key, label .. ": page " .. i .. " key matches")
    end
end

local registeredSpecs = {}
_G.CreshSuite = {
    RegisterSettingsProvider = function(_, addonName, spec) registeredSpecs[addonName] = spec end,
}
_G.CreshChat = nil

local gamesPath = "addons/CreshGames/GamesSettings.lua"
local okGames, errGames = pcall(loadProductionFile, gamesPath, "CreshGames", {})
ok(okGames, "GamesSettings.lua loads without error (err: " .. tostring(not okGames and errGames or "") .. ")")
if okGames then
    local gamesSpec = registeredSpecs.CreshGames
    ok(gamesSpec ~= nil, "CreshGames registered a settings provider spec")
    if gamesSpec then
        sameKeys(pageKeys(gamesSpec), { "GENERAL", "GAMEPLAY", "NOTIFICATIONS", "ADVANCED" }, "CreshGames")
        for _, page in ipairs(gamesSpec.pages) do
            ok(type(page.label) == "string" and page.label ~= "", "CreshGames page " .. tostring(page.key) .. " has a label")
            ok(type(page.desc) == "string" and page.desc ~= "", "CreshGames page " .. tostring(page.key) .. " has a description")
            ok(type(page.build) == "function", "CreshGames page " .. tostring(page.key) .. " has a build function")
        end
    end
end

local collectPath = "addons/CreshCollect/CollectSettings.lua"
local okCollect, errCollect = pcall(loadProductionFile, collectPath, "CreshCollect", {})
ok(okCollect, "CollectSettings.lua loads without error (err: " .. tostring(not okCollect and errCollect or "") .. ")")
if okCollect then
    local collectSpec = registeredSpecs.CreshCollect
    ok(collectSpec ~= nil, "CreshCollect registered a settings provider spec")
    if collectSpec then
        sameKeys(pageKeys(collectSpec), { "TRACKING", "ACHIEVEMENTS", "CHRONICLE", "NOTIFICATIONS", "ADVANCED" }, "CreshCollect")
        for _, page in ipairs(collectSpec.pages) do
            ok(type(page.label) == "string" and page.label ~= "", "CreshCollect page " .. tostring(page.key) .. " has a label")
            ok(type(page.desc) == "string" and page.desc ~= "", "CreshCollect page " .. tostring(page.key) .. " has a description")
            ok(type(page.build) == "function", "CreshCollect page " .. tostring(page.key) .. " has a build function")
        end
    end
end

-- ============================================================
-- Summary
-- ============================================================
print(("\n=== Results: %d passed, %d failed ==="):format(PASS, FAIL))
if FAIL > 0 then os.exit(1) end
