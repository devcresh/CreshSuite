local _, CC = ...
if not CC then return end

-- v0.3.25 theme library: 75 additional named presets combine with the 25
-- existing presets in UI.lua for exactly 100 selectable named themes.
local Library = { version = CC.version, presets = {}, display = {}, order = {}, category = {}, guildPresets = {}, guildDisplay = {}, guildOrder = {} }
CC.ThemeLibrary = Library
if CC.RegisterModule then CC:RegisterModule("ThemeLibrary", Library) end

local min = math.min
local function C(r, g, b, a) return { r / 255, g / 255, b / 255, a or 1 } end
local function mix(a, b, amount, alpha)
    amount = amount or 0.5
    return { a[1] + ((b[1] - a[1]) * amount), a[2] + ((b[2] - a[2]) * amount), a[3] + ((b[3] - a[3]) * amount), alpha or 1 }
end
local function brighten(a, amount)
    return { min(1, a[1] + amount), min(1, a[2] + amount), min(1, a[3] + amount), 1 }
end
local function add(key, name, bg, accent, secondary, border, category)
    Library.presets[key] = {
        panel = { bg[1] * 0.72, bg[2] * 0.72, bg[3] * 0.72, 0.990 },
        panelSoft = mix(bg, accent, 0.10, 0.990),
        panelRaised = mix(bg, accent, 0.19, 1.000),
        border = border, accent = accent,
        incoming = mix(bg, { 1, 1, 1, 1 }, 0.075, 1.000),
        outgoing = mix(bg, secondary or accent, 0.68, 1.000),
    }
    Library.display[key] = name
    Library.category[key] = category or "Theme"
    Library.order[#Library.order + 1] = key
end

add("FOR_THE_ALLIANCE", "For the Alliance", C(16,43,85,1), C(233,185,73,1), C(47,117,200,1), C(110,168,255,1), "Faction")
add("FOR_THE_HORDE", "For the Horde", C(58,13,13,1), C(213,51,42,1), C(123,31,24,1), C(240,128,60,1), "Faction")
add("UNDEAD_FORSAKEN", "Undead Forsaken", C(25,21,42,1), C(138,105,184,1), C(61,111,86,1), C(183,154,214,1), "Faction")
add("NIGHT_ELF_MOON", "Night Elf Moon", C(16,24,47,1), C(125,112,217,1), C(49,91,115,1), C(183,169,255,1), "Faction")
add("BLOOD_ELF_SUN", "Blood Elf Sun", C(53,17,26,1), C(230,167,51,1), C(140,36,59,1), C(247,216,106,1), "Faction")
add("DRAENEI_CRYSTAL", "Draenei Crystal", C(20,29,63,1), C(111,168,255,1), C(118,86,184,1), C(168,213,255,1), "Faction")
add("ORCISH_WARSONG", "Orcish Warsong", C(36,48,18,1), C(155,189,55,1), C(95,66,29,1), C(211,223,114,1), "Faction")
add("TAUREN_EARTH", "Tauren Earth", C(48,35,25,1), C(197,138,70,1), C(110,74,46,1), C(231,188,121,1), "Faction")
add("DWARVEN_FORGE", "Dwarven Forge", C(42,33,29,1), C(217,122,43,1), C(106,88,71,1), C(242,179,110,1), "Faction")
add("GNOMISH_GADGET", "Gnomish Gadget", C(28,46,55,1), C(85,201,216,1), C(192,107,170,1), C(167,238,242,1), "Faction")
add("HUMAN_LION", "Human Lion", C(23,40,68,1), C(225,194,90,1), C(54,95,157,1), C(255,240,160,1), "Faction")
add("TROLL_VOODOO", "Troll Voodoo", C(18,43,42,1), C(49,187,164,1), C(125,63,162,1), C(122,232,213,1), "Faction")
add("DARK_IRON", "Dark Iron", C(36,22,22,1), C(228,93,50,1), C(77,55,50,1), C(255,154,114,1), "Faction")
add("HIGH_ELF", "High Elf", C(19,37,56,1), C(110,197,214,1), C(185,163,85,1), C(189,236,242,1), "Faction")
add("GOBLIN_CARTEL", "Goblin Cartel", C(37,49,13,1), C(140,198,62,1), C(201,144,47,1), C(200,241,126,1), "Faction")
add("ELWYNN_FOREST", "Elwynn Forest", C(19,40,22,1), C(98,168,77,1), C(138,107,54,1), C(157,209,122,1), "Zone")
add("DUROTAR", "Durotar", C(58,32,22,1), C(212,106,53,1), C(125,50,30,1), C(241,160,103,1), "Zone")
add("TELDRASSIL", "Teldrassil", C(27,23,56,1), C(139,112,214,1), C(43,107,101,1), C(197,174,255,1), "Zone")
add("MULGORE", "Mulgore", C(24,51,26,1), C(114,185,91,1), C(167,132,60,1), C(183,224,138,1), "Zone")
add("WESTFALL", "Westfall", C(58,44,18,1), C(226,183,68,1), C(128,96,43,1), C(245,218,119,1), "Zone")
add("REDRIDGE", "Redridge Mountains", C(59,25,23,1), C(201,85,60,1), C(106,51,40,1), C(233,141,114,1), "Zone")
add("DUSKWOOD", "Duskwood", C(22,26,32,1), C(89,106,117,1), C(75,46,88,1), C(142,161,173,1), "Zone")
add("STRANGLETHORN", "Stranglethorn Vale", C(15,45,35,1), C(34,165,107,1), C(122,92,34,1), C(100,215,155,1), "Zone")
add("TANARIS", "Tanaris", C(59,48,27,1), C(216,183,99,1), C(167,119,52,1), C(244,217,139,1), "Zone")
add("UNGORO", "Un'Goro Crater", C(18,52,36,1), C(75,197,107,1), C(45,125,82,1), C(138,241,154,1), "Zone")
add("WINTERSPRING", "Winterspring", C(21,43,59,1), C(143,212,238,1), C(85,123,169,1), C(208,245,255,1), "Zone")
add("EASTERN_PLAGUELANDS", "Eastern Plaguelands", C(49,50,24,1), C(163,184,74,1), C(100,93,43,1), C(209,222,119,1), "Zone")
add("SILITHUS", "Silithus", C(54,42,22,1), C(201,154,69,1), C(110,81,48,1), C(232,195,114,1), "Zone")
add("ASHENVALE", "Ashenvale", C(20,38,31,1), C(79,158,113,1), C(91,76,136,1), C(139,208,160,1), "Zone")
add("THE_BARRENS", "The Barrens", C(53,42,22,1), C(196,161,74,1), C(154,100,49,1), C(228,198,120,1), "Zone")
add("HELLFIRE_PENINSULA", "Hellfire Peninsula", C(56,19,25,1), C(209,70,53,1), C(125,34,29,1), C(242,130,104,1), "Zone")
add("ZANGARMARSH", "Zangarmarsh", C(16,44,53,1), C(60,184,184,1), C(78,94,154,1), C(123,227,217,1), "Zone")
add("TEROKKAR_FOREST", "Terokkar Forest", C(27,37,48,1), C(113,137,167,1), C(82,107,73,1), C(166,185,208,1), "Zone")
add("NAGRAND", "Nagrand", C(21,55,46,1), C(87,189,130,1), C(90,131,198,1), C(148,225,169,1), "Zone")
add("BLADES_EDGE", "Blade's Edge Mountains", C(46,27,36,1), C(180,90,77,1), C(107,67,84,1), C(223,140,121,1), "Zone")
add("NETHERSTORM", "Netherstorm", C(37,22,58,1), C(160,96,232,1), C(59,121,199,1), C(207,155,255,1), "Zone")
add("SHADOWMOON_VALLEY", "Shadowmoon Valley", C(23,20,38,1), C(109,75,155,1), C(56,107,76,1), C(165,139,199,1), "Zone")
add("SHATTRATH", "Shattrath City", C(29,42,53,1), C(215,179,93,1), C(82,122,145,1), C(240,213,138,1), "Zone")
add("SILVERMOON", "Silvermoon City", C(59,16,23,1), C(217,170,62,1), C(165,35,56,1), C(244,211,108,1), "Zone")
add("EVERSONG_WOODS", "Eversong Woods", C(56,36,22,1), C(216,168,78,1), C(163,76,53,1), C(240,206,120,1), "Zone")
add("GHOSTLANDS", "Ghostlands", C(36,25,42,1), C(139,92,154,1), C(90,109,61,1), C(190,145,200,1), "Zone")
add("AZUREMYST", "Azuremyst Isle", C(20,39,66,1), C(87,159,224,1), C(117,92,184,1), C(146,200,244,1), "Zone")
add("BLOODMYST", "Bloodmyst Isle", C(53,22,37,1), C(184,77,114,1), C(94,79,152,1), C(226,133,164,1), "Zone")
add("STORMWIND", "Stormwind City", C(19,42,75,1), C(229,189,74,1), C(53,108,193,1), C(247,223,126,1), "Zone")
add("ORGRIMMAR", "Orgrimmar", C(53,17,15,1), C(201,55,47,1), C(115,80,59,1), C(241,120,99,1), "Zone")
add("UNDERCITY", "Undercity", C(26,22,38,1), C(123,90,165,1), C(58,108,84,1), C(176,140,203,1), "Zone")
add("IRONFORGE", "Ironforge", C(40,35,34,1), C(217,138,63,1), C(107,113,120,1), C(241,186,116,1), "Zone")
add("DARNASSUS", "Darnassus", C(23,27,53,1), C(127,116,201,1), C(61,125,103,1), C(182,169,238,1), "Zone")
add("THUNDER_BLUFF", "Thunder Bluff", C(48,36,25,1), C(194,140,75,1), C(90,123,73,1), C(225,189,123,1), "Zone")
add("EXODAR", "The Exodar", C(21,34,62,1), C(110,166,232,1), C(106,85,165,1), C(169,210,255,1), "Zone")
add("BLACK_TEMPLE", "Black Temple", C(21,18,30,1), C(122,74,156,1), C(50,77,60,1), C(168,123,194,1), "Raid")
add("KARAZHAN", "Karazhan", C(35,24,43,1), C(176,109,173,1), C(93,70,110,1), C(216,156,209,1), "Raid")
add("SUNWELL", "Sunwell Plateau", C(52,33,19,1), C(232,196,90,1), C(197,91,60,1), C(255,229,140,1), "Raid")
add("TEMPEST_KEEP", "Tempest Keep", C(33,19,59,1), C(158,90,224,1), C(57,121,201,1), C(208,153,255,1), "Raid")
add("SERPENTSHRINE", "Serpentshrine Cavern", C(16,43,50,1), C(54,166,164,1), C(71,96,162,1), C(112,217,213,1), "Raid")
add("PALADIN_GOLD", "Paladin Gold", C(48,39,18,1), C(243,200,74,1), C(168,120,39,1), C(255,229,134,1), "Class")
add("SHAMAN_STORM", "Shaman Storm", C(20,42,58,1), C(62,157,216,1), C(110,94,168,1), C(121,202,240,1), "Class")
add("DRUID_GROVE", "Druid Grove", C(23,48,29,1), C(105,174,77,1), C(139,106,49,1), C(168,216,121,1), "Class")
add("ROGUE_SHADOW", "Rogue Shadow", C(24,24,27,1), C(216,200,90,1), C(87,84,94,1), C(244,232,137,1), "Class")
add("MAGE_ARCANE", "Mage Arcane", C(24,35,58,1), C(79,170,229,1), C(126,90,196,1), C(135,212,244,1), "Class")
add("WARLOCK_FEL", "Warlock Fel", C(29,40,16,1), C(117,198,59,1), C(101,64,151,1), C(172,238,115,1), "Class")
add("WARRIOR_STEEL", "Warrior Steel", C(39,40,44,1), C(197,83,62,1), C(105,115,127,1), C(226,134,114,1), "Class")
add("PRIEST_HOLY", "Priest Holy", C(52,48,38,1), C(240,227,176,1), C(167,155,130,1), C(255,246,213,1), "Class")
add("HUNTER_WILD", "Hunter Wild", C(33,48,26,1), C(130,184,77,1), C(139,107,53,1), C(185,222,130,1), "Class")
add("ALCHEMY", "Alchemy", C(28,46,40,1), C(92,197,142,1), C(154,103,179,1), C(146,227,183,1), "Profession")
add("BLACKSMITH", "Blacksmith", C(43,34,29,1), C(217,120,54,1), C(109,107,104,1), C(240,165,109,1), "Profession")
add("ENCHANTING", "Enchanting", C(31,26,54,1), C(155,115,223,1), C(78,140,193,1), C(200,166,255,1), "Profession")
add("ENGINEERING", "Engineering", C(43,43,26,1), C(216,182,71,1), C(79,141,150,1), C(241,217,130,1), "Profession")
add("HERBALISM", "Herbalism", C(25,49,30,1), C(95,185,104,1), C(107,143,57,1), C(156,224,161,1), "Profession")
add("MINING", "Mining", C(41,41,45,1), C(167,169,174,1), C(164,108,53,1), C(214,216,219,1), "Profession")
add("FROSTMOURNE", "Frostmourne", C(17,31,46,1), C(133,216,245,1), C(77,111,155,1), C(198,242,255,1), "Special")
add("MOLTEN_CORE", "Molten Core", C(50,18,13,1), C(232,75,40,1), C(157,46,24,1), C(255,145,107,1), "Special")
add("AQ_SAND", "Ahn'Qiraj Sand", C(55,43,25,1), C(208,166,76,1), C(121,101,76,1), C(233,204,122,1), "Special")
add("DARK_PORTAL", "The Dark Portal", C(33,20,47,1), C(164,99,216,1), C(59,139,98,1), C(206,152,238,1), "Special")
add("OUTLAND_SKY", "Outland Sky", C(24,41,61,1), C(92,169,216,1), C(122,90,180,1), C(153,212,239,1), "Special")

local function addGuild(key, name, bg, accent, secondary, border)
    Library.guildPresets[key] = {
        panel = { bg[1] * 0.70, bg[2] * 0.70, bg[3] * 0.70, 0.995 },
        panelSoft = mix(bg, accent, 0.10, 0.995), panelRaised = mix(bg, accent, 0.20, 1),
        border = border, accent = accent, accentHover = brighten(accent, 0.12),
        incoming = mix(bg, {1,1,1,1}, 0.08, 1), outgoing = mix(bg, secondary, 0.68, 1),
        officer = brighten(accent, 0.18), muted = mix(accent, {1,1,1,1}, 0.48, 1),
    }
    Library.guildDisplay[key] = name
    Library.guildOrder[#Library.guildOrder + 1] = key
end
addGuild("FOR_ALLIANCE_GUILD", "For the Alliance", C(16,43,85,1), C(233,185,73,1), C(47,117,200,1), C(110,168,255,1))
addGuild("FOR_HORDE_GUILD", "For the Horde", C(58,13,13,1), C(213,51,42,1), C(123,31,24,1), C(240,128,60,1))
addGuild("FORSAKEN_GUILD", "Forsaken Covenant", C(25,21,42,1), C(138,105,184,1), C(61,111,86,1), C(183,154,214,1))
addGuild("STORMWIND_GUILD", "Stormwind Guard", C(19,42,75,1), C(229,189,74,1), C(53,108,193,1), C(247,223,126,1))
addGuild("ORGRIMMAR_GUILD", "Orgrimmar Warband", C(53,17,15,1), C(201,55,47,1), C(115,80,59,1), C(241,120,99,1))
addGuild("SILVERMOON_GUILD", "Silvermoon Court", C(59,16,23,1), C(217,170,62,1), C(165,35,56,1), C(244,211,108,1))
addGuild("UNDERCITY_GUILD", "Undercity Circle", C(26,22,38,1), C(123,90,165,1), C(58,108,84,1), C(176,140,203,1))
addGuild("IRONFORGE_GUILD", "Ironforge Clan", C(40,35,34,1), C(217,138,63,1), C(107,113,120,1), C(241,186,116,1))
addGuild("DARNASSUS_GUILD", "Darnassus Sentinels", C(23,27,53,1), C(127,116,201,1), C(61,125,103,1), C(182,169,238,1))
addGuild("THUNDER_BLUFF_GUILD", "Thunder Bluff Tribe", C(48,36,25,1), C(194,140,75,1), C(90,123,73,1), C(225,189,123,1))

Library.namedThemeCount = 100
