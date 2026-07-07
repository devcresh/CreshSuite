local _, CG = ...
if not CG then return end

local floor = math.floor
local function pct(v) return floor(v * 100 + 0.5) .. "%" end

local function cgDB()  return _G.CreshGamesDB end

local function gaDB()
    local db = cgDB()
    if not db then return { musicEnabled = true, musicVolume = 0.35, effectsEnabled = true, effectsVolume = 0.55 } end
    db.gameAudio = type(db.gameAudio) == "table" and db.gameAudio or {}
    local s = db.gameAudio
    if s.musicEnabled   == nil then s.musicEnabled   = true  end
    if s.effectsEnabled == nil then s.effectsEnabled = true  end
    if s.musicVolume    == nil then s.musicVolume    = 0.35  end
    if s.effectsVolume  == nil then s.effectsVolume  = 0.55  end
    return s
end

-- Phase 6: opens the relevant hub tab instead of duplicating its numbers
-- here. CG.SoloGames loads before this file (see CreshGames.toc), so it's
-- always available by the time a button is actually clicked.
local function openHubTab(tab)
    if CG.SoloGames and CG.SoloGames.SelectHubTab then CG.SoloGames:SelectHubTab(tab) end
end

local Suite = _G.CreshSuite
if not Suite then return end

Suite:RegisterSettingsProvider("CreshGames", {
    pages = {
        {
            key      = "GENERAL",
            label    = "General",
            desc     = "Launcher and general CreshGames preferences.",
            keywords = "launcher quick button",
            build = function(b)
                b:Section("Launcher")
                b:HalfToggle("Games quick button",
                    function()
                        local db = cgDB(); return db and db.launcher and db.launcher.showButton == true
                    end,
                    function(v)
                        local db = cgDB()
                        if db then db.launcher = db.launcher or {}; db.launcher.showButton = v and true or false end
                    end)
                b:Note("Shows the Games button next to C in Expanded launcher mode. Configure launcher mode in CreshChat Settings \226\134\146 General \226\134\146 Launcher.")
            end,
        },
        {
            key      = "GAMEPLAY",
            label    = "Gameplay",
            desc     = "Music, sound effects, Tetris defaults and shortcuts to the Solo, Multiplayer and Unlocks hubs.",
            keywords = "audio music sound effects volume tetris cpu difficulty solo multiplayer unlocks dungeon controls",
            build = function(b)
                b:Section("Background music")
                b:HalfToggle("Enable background music",
                    function() return gaDB().musicEnabled ~= false end,
                    function(v)
                        gaDB().musicEnabled = v
                        if CG.GameAudio then
                            if v then CG.GameAudio:RestartMusic() else CG.GameAudio:StopMusic() end
                        end
                    end)
                b:Slider("Music volume", 0, 1, 0.05,
                    function() return gaDB().musicVolume or 0.35 end,
                    function(v) gaDB().musicVolume = v; if CG.GameAudio then CG.GameAudio:RestartMusic() end end,
                    pct)
                b:Section("Sound effects")
                b:HalfToggle("Enable sound effects",
                    function() return gaDB().effectsEnabled ~= false end,
                    function(v) gaDB().effectsEnabled = v end)
                b:Slider("Effects volume", 0, 1, 0.05,
                    function() return gaDB().effectsVolume or 0.55 end,
                    function(v)
                        gaDB().effectsVolume = v
                        if CG.GameAudio then CG.GameAudio:PlayEffect("CLICK") end
                    end,
                    pct)
                b:Note("Controls mini-game music loops and gameplay sounds. CreshChat notification-card sounds are configured separately in CreshChat Settings \226\134\146 Notifications.")

                -- Phase 6 bug fix: the value list here used to be
                -- ENDLESS/TIMED/CLASSIC, but the game itself only ever
                -- reads/writes ENDLESS or ATTACK (SoloGames.lua) -- TIMED
                -- and CLASSIC were dead selections that didn't match
                -- anything the game checked.
                local VERSUS_VALUES  = { "ENDLESS", "ATTACK" }
                local VERSUS_DISPLAY = { ENDLESS = "Endless", ATTACK = "Endless Attack" }
                local LEVEL_VALUES   = { "1","2","3","4","5","6","7","8","9","10" }
                local LEVEL_DISPLAY  = {
                    ["1"]="1 \226\128\148 Beginner",  ["2"]="2", ["3"]="3 \226\128\148 Normal",
                    ["4"]="4", ["5"]="5 \226\128\148 Hard", ["6"]="6",
                    ["7"]="7", ["8"]="8", ["9"]="9", ["10"]="10 \226\128\148 Expert",
                }
                local function tet()
                    local db = cgDB()
                    return db and db.soloGames and db.soloGames.tetris
                end
                b:Section("Tetris defaults")
                b:Dropdown("CPU AI difficulty",
                    function() local t = tet() or {}; return tostring(t.cpuLevel or 3) end,
                    function(v)
                        local t = tet(); if t then t.cpuLevel = tonumber(v) or 3 end
                    end,
                    LEVEL_VALUES, LEVEL_DISPLAY)
                b:Dropdown("Versus CPU mode",
                    function() local t = tet() or {}; return t.cpuVersusMode or "ENDLESS" end,
                    function(v) local t = tet(); if t then t.cpuVersusMode = v end end,
                    VERSUS_VALUES, VERSUS_DISPLAY)

                b:Section("Solo, Multiplayer and Unlocks")
                b:Note("Game records, leaderboards, dungeon progress and cosmetic unlocks live in the CreshGames hub itself, not here.")
                b:Buttons({
                    { "OPEN SOLO GAMES", function() openHubTab("SOLO") end, 150 },
                    { "OPEN MULTIPLAYER", function() openHubTab("MULTIPLAYER") end, 150 },
                    { "OPEN UNLOCKS", function() openHubTab("UNLOCKS") end, 130 },
                })
            end,
        },
        {
            key      = "NOTIFICATIONS",
            label    = "Notifications",
            desc     = "CreshGames notification card categories. Requires CreshChat.",
            keywords = "notifications cards sound alerts",
            build = function(b)
                local CC = _G.CreshChat
                b:Section("CreshGames notification cards")
                if not CC or not CC.Notifications then
                    b:Note("CreshChat is not loaded. Load CreshChat alongside CreshGames to configure notification card display.")
                    return
                end
                local cats     = CC.Notifications:GetRegisteredCategories("CRESHGAMES")
                local catOrder = {}
                for catKey in pairs(cats) do catOrder[#catOrder + 1] = catKey end
                table.sort(catOrder)
                if #catOrder == 0 then
                    b:Note("No CreshGames notification categories are registered yet. Log in with CreshGames loaded to register them.")
                    return
                end
                for _, catKey in ipairs(catOrder) do
                    local info = cats[catKey]
                    local cCat = catKey
                    b:HalfToggle(info.label,
                        function()
                            local s = CC.db and CC.db.notificationSources and CC.db.notificationSources.CRESHGAMES
                            return not s or s[cCat] ~= false
                        end,
                        function(v)
                            CC.db.notificationSources = CC.db.notificationSources or {}
                            CC.db.notificationSources.CRESHGAMES = CC.db.notificationSources.CRESHGAMES or {}
                            CC.db.notificationSources.CRESHGAMES[cCat] = v and true or false
                        end)
                end
                b:Note("These control which CreshGames event types show as notification cards in CreshChat. Master card visibility is set in CreshChat Settings \226\134\146 Notifications.")
            end,
        },
        {
            key      = "ADVANCED",
            label    = "Advanced",
            desc     = "Permanently reset CreshGames data. Cannot be undone.",
            keywords = "reset advanced delete stats",
            build = function(b)
                b:Section("Reset game data")
                b:Note("WARNING: The button below permanently deletes CreshGames data. CreshChat settings, chat history and CreshCollect data are not affected.")
                b:Buttons({
                    { "RESET GAME STATS", function()
                        b:ConfirmAction(
                            "Permanently delete all CreshGames solo/multiplayer stats, leaderboards and game progression, then reload the UI?\n\nThis cannot be undone. Cresh Coins and Battle Pass XP live in CreshCollect and are not affected.",
                            function()
                                local db = _G.CreshGamesDB
                                if db then
                                    db.soloGames        = nil
                                    db.arcadeRewards    = nil
                                    db.gameHistory      = nil
                                    db.gameLeaderboards = nil
                                    db.multiplayerStats = nil
                                    db.gameProgression  = nil
                                    if _G.ReloadUI then _G.ReloadUI() end
                                end
                            end)
                    end, 160 },
                })
                b:Note("Resets all solo game stats, leaderboards, multiplayer records and game progression. A UI reload follows to reinitialise the database.")
                b:Buttons({
                    { "RESET LAUNCHER PREFS", function()
                        local db = _G.CreshGamesDB
                        if db then db.launcher = { showButton = false } end
                    end, 180 },
                })
                b:Note("Resets only the Games launcher button preference back to hidden.")
            end,
        },
    },
})
