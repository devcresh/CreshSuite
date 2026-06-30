local _, CC = ...

local root = "Interface\\AddOns\\CreshChat\\Media\\Sounds\\"

local entries = {
    { key = "CRESH_SOFT_BELL_01", name = "Cresh · Soft Bell 1", file = "soft_bell_01.ogg", group = "Soft Bells" },
    { key = "CRESH_SOFT_BELL_02", name = "Cresh · Soft Bell 2", file = "soft_bell_02.ogg", group = "Soft Bells" },
    { key = "CRESH_SOFT_BELL_03", name = "Cresh · Soft Bell 3", file = "soft_bell_03.ogg", group = "Soft Bells" },
    { key = "CRESH_SOFT_BELL_04", name = "Cresh · Soft Bell 4", file = "soft_bell_04.ogg", group = "Soft Bells" },

    { key = "CRESH_CRYSTAL_01", name = "Cresh · Crystal Ping 1", file = "crystal_ping_01.ogg", group = "Crystal Pings" },
    { key = "CRESH_CRYSTAL_02", name = "Cresh · Crystal Ping 2", file = "crystal_ping_02.ogg", group = "Crystal Pings" },
    { key = "CRESH_CRYSTAL_03", name = "Cresh · Crystal Ping 3", file = "crystal_ping_03.ogg", group = "Crystal Pings" },
    { key = "CRESH_CRYSTAL_04", name = "Cresh · Crystal Ping 4", file = "crystal_ping_04.ogg", group = "Crystal Pings" },

    { key = "CRESH_WOOD_TICK_01", name = "Cresh · Wooden Tick 1", file = "wood_tick_01.ogg", group = "Wooden Ticks" },
    { key = "CRESH_WOOD_TICK_02", name = "Cresh · Wooden Tick 2", file = "wood_tick_02.ogg", group = "Wooden Ticks" },
    { key = "CRESH_WOOD_TICK_03", name = "Cresh · Wooden Tick 3", file = "wood_tick_03.ogg", group = "Wooden Ticks" },
    { key = "CRESH_WOOD_TICK_04", name = "Cresh · Wooden Tick 4", file = "wood_tick_04.ogg", group = "Wooden Ticks" },

    { key = "CRESH_ARCANE_01", name = "Cresh · Arcane Pulse 1", file = "arcane_pulse_01.ogg", group = "Arcane Pulses" },
    { key = "CRESH_ARCANE_02", name = "Cresh · Arcane Pulse 2", file = "arcane_pulse_02.ogg", group = "Arcane Pulses" },
    { key = "CRESH_ARCANE_03", name = "Cresh · Arcane Pulse 3", file = "arcane_pulse_03.ogg", group = "Arcane Pulses" },
    { key = "CRESH_ARCANE_04", name = "Cresh · Arcane Pulse 4", file = "arcane_pulse_04.ogg", group = "Arcane Pulses" },

    { key = "CRESH_WHISPER_01", name = "Cresh · Whisper Tone 1", file = "whisper_tone_01.ogg", group = "Whisper Tones" },
    { key = "CRESH_WHISPER_02", name = "Cresh · Whisper Tone 2", file = "whisper_tone_02.ogg", group = "Whisper Tones" },
    { key = "CRESH_WHISPER_03", name = "Cresh · Whisper Tone 3", file = "whisper_tone_03.ogg", group = "Whisper Tones" },
    { key = "CRESH_WHISPER_04", name = "Cresh · Whisper Tone 4", file = "whisper_tone_04.ogg", group = "Whisper Tones" },

    { key = "CRESH_BUBBLE_01", name = "Cresh · Bubble Pop 1", file = "bubble_pop_01.ogg", group = "Bubble Pops" },
    { key = "CRESH_BUBBLE_02", name = "Cresh · Bubble Pop 2", file = "bubble_pop_02.ogg", group = "Bubble Pops" },
    { key = "CRESH_BUBBLE_03", name = "Cresh · Bubble Pop 3", file = "bubble_pop_03.ogg", group = "Bubble Pops" },
    { key = "CRESH_BUBBLE_04", name = "Cresh · Bubble Pop 4", file = "bubble_pop_04.ogg", group = "Bubble Pops" },
}

local library = {
    order = {},
    display = {},
    files = {},
    groups = {},
    entries = entries,
}

for _, entry in ipairs(entries) do
    library.order[#library.order + 1] = entry.key
    library.display[entry.key] = entry.name
    library.files[entry.key] = root .. entry.file
    library.groups[entry.key] = entry.group
end

_G.CreshChatSoundLibrary = library
if CC then
    CC.Assets = CC.Assets or {}
    CC.Assets.Sounds = library
    if CC.RegisterModule then CC:RegisterModule("SoundLibrary", { version = CC.version, library = library }) end
end
