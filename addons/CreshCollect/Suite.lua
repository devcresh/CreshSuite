-- shared/Suite.lua  --  CreshSuite inter-addon bridge  --  Bridge v1
--
-- One physical copy of this file ships inside each suite addon's folder.
-- The first addon to load builds _G.CreshSuite; all later loads are no-ops.
-- Canonical source: shared/Suite.lua
-- Compatible with WoW TBC Anniversary (Lua 5.1, no io/os/require).

local BRIDGE_VERSION = 1

-- --------------------------------------------------------------------------
-- Idempotency guard
-- --------------------------------------------------------------------------
if _G.CreshSuite then
    local cs = _G.CreshSuite
    if type(cs.BRIDGE_VERSION) == "number" then
        if cs.BRIDGE_VERSION == BRIDGE_VERSION then
            return   -- same version already running; expected for addons 2 and 3
        end
        -- Incompatible version already occupying _G.CreshSuite.
        -- Keep the running copy and record a warning into its log.
        if type(cs._warn) == "function" then
            cs:_warn("Bridge version mismatch: running=" .. cs.BRIDGE_VERSION
                .. "  loaded=" .. BRIDGE_VERSION .. "  Keeping running version.")
        end
        return
    end
end

-- --------------------------------------------------------------------------
-- First-load: construct the bridge
-- --------------------------------------------------------------------------
local Suite = {}
_G.CreshSuite        = Suite
Suite.BRIDGE_VERSION = BRIDGE_VERSION

-- Private state
local _products = {}   -- UPPER_NAME -> { name, version, api }
local _services = {}   -- name       -> fn
local _settings = {}   -- UPPER_NAME -> fn
local _subs     = {}   -- topic      -> { fn, ... }
local _log      = {}   -- list of { t, level, msg }, capped at LOG_MAX
local LOG_MAX   = 64

-- --------------------------------------------------------------------------
-- Internal helpers
-- --------------------------------------------------------------------------

local function pushLog(level, msg)
    if #_log >= LOG_MAX then table.remove(_log, 1) end
    _log[#_log + 1] = { t = GetTime and GetTime() or 0, level = level, msg = msg }
end

local function safeCall(fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then pushLog("ERROR", "callback error: " .. tostring(err)) end
    return ok
end

-- --------------------------------------------------------------------------
-- Logging (also called by the version-mismatch guard above)
-- --------------------------------------------------------------------------

function Suite:_warn(msg)  pushLog("WARN",  tostring(msg)) end
function Suite:_info(msg)  pushLog("INFO",  tostring(msg)) end
function Suite:_error(msg) pushLog("ERROR", tostring(msg)) end

function Suite:GetVersion() return BRIDGE_VERSION end

function Suite:GetLogs()
    local out = {}
    for i = 1, #_log do out[i] = _log[i] end
    return out
end

-- --------------------------------------------------------------------------
-- Product registry
-- --------------------------------------------------------------------------
-- Suite:RegisterProduct(name, version, api)
--   name    string  "CreshGames"  (stored upper-cased)
--   version string  "0.2.3"
--   api     table?  public interface; defaults to {}
--
-- Suite:GetProduct(name) -> { name, version, api } or nil

function Suite:RegisterProduct(name, version, api)
    if type(name)    ~= "string" or name    == "" then error("Suite:RegisterProduct: name must be a non-empty string",    2) end
    if type(version) ~= "string" or version == "" then error("Suite:RegisterProduct: version must be a non-empty string", 2) end
    local key = string.upper(name)
    if _products[key] then self:_warn("RegisterProduct: " .. key .. " re-registered, updating") end
    _products[key] = { name = key, version = version, api = api or {} }
    self:_info("RegisterProduct: " .. key .. " v" .. version)
    self:Publish("SUITE_PRODUCT_REGISTERED", key)
end

function Suite:GetProduct(name)
    if type(name) ~= "string" or name == "" then return nil end
    return _products[string.upper(name)]
end

-- Suite:IsProductLoaded(name) -> true/false
--   Centralized "is this addon actually installed and loaded" check. Reflects
--   RegisterProduct having run, which happens at the very top of each addon's
--   own first file (right after its own copy of Suite.lua), so this is a more
--   reliable presence signal than probing a specific bridged module table
--   (which depends on that addon's own bridging code having also run).
--   Use this instead of scattered `CC.Games ~= nil` / `CC.Achievements ~= nil`
--   style checks when the question is "is the addon here at all".

function Suite:IsProductLoaded(name)
    return self:GetProduct(name) ~= nil
end

-- --------------------------------------------------------------------------
-- Service registry
-- --------------------------------------------------------------------------
-- Suite:RegisterService(name, fn)  singleton named callable
-- Suite:GetService(name)           -> fn or nil

function Suite:RegisterService(name, fn)
    if type(name) ~= "string" or name == "" then error("Suite:RegisterService: name must be a non-empty string", 2) end
    if type(fn)   ~= "function"             then error("Suite:RegisterService: fn must be a function",            2) end
    _services[name] = fn
    self:_info("RegisterService: " .. name)
end

function Suite:GetService(name)
    if type(name) ~= "string" or name == "" then return nil end
    return _services[name]
end

-- --------------------------------------------------------------------------
-- Settings providers
-- --------------------------------------------------------------------------
-- Suite:RegisterSettingsProvider(addonName, spec)
--   spec is a function fn(builder) OR a table { pages = { {key,label,desc,build}, ... } }
--   CreshChat's Settings UI calls build(builder) per page to construct the panel.
--
-- Suite:GetSettingsProvider(addonName) -> spec or nil

function Suite:RegisterSettingsProvider(addonName, spec)
    if type(addonName) ~= "string" or addonName == "" then error("Suite:RegisterSettingsProvider: addonName must be a non-empty string", 2) end
    if type(spec) ~= "function" and type(spec) ~= "table" then error("Suite:RegisterSettingsProvider: spec must be a function or table", 2) end
    _settings[string.upper(addonName)] = spec
    self:_info("RegisterSettingsProvider: " .. addonName)
end

function Suite:GetSettingsProvider(addonName)
    if type(addonName) ~= "string" or addonName == "" then return nil end
    return _settings[string.upper(addonName)]
end

-- --------------------------------------------------------------------------
-- Pub / Sub
-- --------------------------------------------------------------------------

function Suite:Subscribe(topic, fn)
    if type(topic) ~= "string" or topic == "" then error("Suite:Subscribe: topic must be a non-empty string", 2) end
    if type(fn)    ~= "function"              then error("Suite:Subscribe: fn must be a function",             2) end
    if not _subs[topic] then _subs[topic] = {} end
    _subs[topic][#_subs[topic] + 1] = fn
end

function Suite:Publish(topic, ...)
    if type(topic) ~= "string" or topic == "" then return end
    local list = _subs[topic]
    if not list then return end
    -- snapshot: callbacks added during Publish fire next time, not this batch
    local snap = {}
    for i = 1, #list do snap[i] = list[i] end
    for i = 1, #snap  do safeCall(snap[i], ...) end
end

-- --------------------------------------------------------------------------
-- Targeted notification
-- --------------------------------------------------------------------------
-- Suite:Notify(targetAddon, event, ...)
--   Publishes to "NOTIFY:<TARGETADDON>:<EVENT>" so each addon can listen
--   for events addressed specifically to it.
--
-- Example:
--   Suite:Subscribe("NOTIFY:CRESHGAMES:READY", handler)
--   Suite:Notify("CreshGames", "READY")

function Suite:Notify(targetAddon, event, ...)
    if type(targetAddon) ~= "string" or type(event) ~= "string" then return end
    self:Publish("NOTIFY:" .. string.upper(targetAddon) .. ":" .. string.upper(event), ...)
end

-- --------------------------------------------------------------------------
-- Late-loading via ADDON_LOADED
-- --------------------------------------------------------------------------
-- Fires Suite:Publish("ADDON_LOADED", addonName) and
--       Suite:Notify(addonName, "LOADED")
-- whenever any addon finishes loading.  No polling or OnUpdate required.
--
-- Subscriber patterns:
--   Suite:Subscribe("ADDON_LOADED", function(name)
--       if name == "CreshGames" then ... end
--   end)
--
--   Suite:Subscribe("NOTIFY:CRESHGAMES:LOADED", handler)  -- per-addon form

local _bridgeFrame = CreateFrame("Frame", "CreshSuiteBridgeFrame")
_bridgeFrame:RegisterEvent("ADDON_LOADED")
_bridgeFrame:SetScript("OnEvent", function(_, _, addonName)
    Suite:Publish("ADDON_LOADED", addonName)
    Suite:Notify(addonName, "LOADED")
end)

Suite:_info("Bridge v" .. BRIDGE_VERSION .. " initialised")
