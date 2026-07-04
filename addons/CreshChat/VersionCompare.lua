-- CreshChat/VersionCompare.lua
-- Lua 5.1-compatible major.minor.patch comparison for dotted version strings
-- (e.g. "0.2.3"). tonumber() cannot parse a string with more than one decimal
-- point, so callers must not tonumber() a dotted version directly.
-- Standalone module (no addon vararg dependency) so it can be dofile'd
-- directly by both the addon and the standalone test harness.

local function Parse(v)
    if type(v) ~= "string" then return nil end
    local major, minor, patch = v:match("^(%d+)%.?(%d*)%.?(%d*)")
    if not major then return nil end
    return tonumber(major) or 0, tonumber(minor) or 0, tonumber(patch) or 0
end

-- Returns -1, 0 or 1 (a<b, a==b, a>b); nil if either side fails to parse.
local function Compare(a, b)
    local aMajor, aMinor, aPatch = Parse(a)
    local bMajor, bMinor, bPatch = Parse(b)
    if not aMajor or not bMajor then return nil end
    if aMajor ~= bMajor then return aMajor < bMajor and -1 or 1 end
    if aMinor ~= bMinor then return aMinor < bMinor and -1 or 1 end
    if aPatch ~= bPatch then return aPatch < bPatch and -1 or 1 end
    return 0
end

-- "0" / "0.0" / "0.0.0" / unparseable strings mean not-yet-populated data,
-- not a genuinely ancient release, so callers can skip enforcement.
local function IsUnset(v)
    local major, minor, patch = Parse(v)
    if not major then return true end
    return major == 0 and minor == 0 and patch == 0
end

_G.CreshChatVersionCompare = {
    Parse   = Parse,
    Compare = Compare,
    IsUnset = IsUnset,
}
