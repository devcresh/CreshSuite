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

local Suite = _G.CreshSuite
if not Suite then return end

Suite:RegisterSettingsProvider("CreshGames", {
    pages = {
        {
            key   = "GENERAL",
            label = "General",
            desc  = "Launcher and general CreshGames preferences.",
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
            key   = "AUDIO",
            label = "Game Audio",
            desc  = "Background music and sound effects for mini-games.",
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
            end,
        },
        {
            key   = "SOLO",
            label = "Solo Games",
            desc  = "Solo game statistics and records.",
            build = function(b)
                local db = cgDB()
                local sg = db and db.soloGames
                b:Section("Solo game records")
                if sg then
                    if sg.frogger then
                        b:Note("Frogger \xc2\xb7 Best level: " .. tostring(sg.frogger.bestLevel or 0) .. "  \xc2\xb7  High score: " .. tostring(sg.frogger.highScore or 0) .. "  \xc2\xb7  Games played: " .. tostring(sg.frogger.games or 0))
                    end
                    if sg.holdem then
                        b:Note("Hold\xe2\x80\x99em \xc2\xb7 Wins: " .. tostring(sg.holdem.wins or 0) .. "  \xc2\xb7  Losses: " .. tostring(sg.holdem.losses or 0) .. "  \xc2\xb7  Best chip count: " .. tostring(sg.holdem.bestChips or 100))
                    end
                    if sg.blackjack then
                        b:Note("Blackjack \xc2\xb7 Wins: " .. tostring(sg.blackjack.wins or 0) .. "  \xc2\xb7  Losses: " .. tostring(sg.blackjack.losses or 0) .. "  \xc2\xb7  Best bank: " .. tostring(sg.blackjack.bestBank or 100))
                    end
                    if sg.chess then
                        b:Note("Chess \xc2\xb7 Wins: " .. tostring(sg.chess.wins or 0) .. "  \xc2\xb7  Losses: " .. tostring(sg.chess.losses or 0) .. "  \xc2\xb7  AI level: " .. tostring(sg.chess.level or 3))
                    end
                    if sg.higherlower then
                        b:Note("Higher-Lower \xc2\xb7 Best streak: " .. tostring(sg.higherlower.bestStreak or 0) .. "  \xc2\xb7  Best bank: " .. tostring(sg.higherlower.bestBank or 100))
                    end
                else
                    b:Note("No solo game data yet. Play a game from the C launcher to see records here.")
                end
                b:Note("All solo game records are stored in CreshGamesDB. Records update as you play; reopen settings to see the latest values.")
            end,
        },
        {
            key   = "MULTIPLAYER",
            label = "Multiplayer",
            desc  = "Multiplayer game statistics and session settings.",
            build = function(b)
                local db  = cgDB()
                local mp  = db and db.multiplayerStats
                b:Section("Multiplayer stats")
                if type(mp) == "table" and next(mp) then
                    b:Note("Multiplayer statistics are recorded here as games complete.")
                else
                    b:Note("No multiplayer data yet. Challenge another player from the Games drawer to begin tracking stats.")
                end
                b:Section("Notifications")
                b:Note("Game invitations, challenges and multiplayer session events generate CreshChat notification cards. Configure which categories appear in the Notifications page.")
            end,
        },
        {
            key   = "TETRIS",
            label = "Tetris",
            desc  = "Tetris game preferences and statistics.",
            build = function(b)
                local VERSUS_VALUES  = { "ENDLESS", "TIMED", "CLASSIC" }
                local VERSUS_DISPLAY = { ENDLESS = "Endless", TIMED = "Timed", CLASSIC = "Classic" }
                local LEVEL_VALUES   = { "1","2","3","4","5","6","7","8","9","10" }
                local LEVEL_DISPLAY  = {
                    ["1"]="1 \xe2\x80\x94 Beginner",  ["2"]="2", ["3"]="3 \xe2\x80\x94 Normal",
                    ["4"]="4", ["5"]="5 \xe2\x80\x94 Hard", ["6"]="6",
                    ["7"]="7", ["8"]="8", ["9"]="9", ["10"]="10 \xe2\x80\x94 Expert",
                }
                local function tet()
                    local db = cgDB()
                    return db and db.soloGames and db.soloGames.tetris
                end
                b:Section("Defaults")
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
                b:Section("Tetris records")
                local t = tet()
                if t then
                    b:Note("High score: " .. tostring(t.highScore or 0) .. "  \xc2\xb7  Best lines: " .. tostring(t.bestLines or 0) .. "  \xc2\xb7  Games: " .. tostring(t.games or 0))
                    b:Note("VS wins: " .. tostring(t.vsWins or 0) .. "  \xc2\xb7  VS losses: " .. tostring(t.vsLosses or 0) .. "  \xc2\xb7  Endless runs: " .. tostring(t.endlessRuns or 0))
                    if t.selectedTheme and t.selectedTheme ~= "" then
                        b:Note("Active theme: " .. tostring(t.selectedTheme))
                    end
                else
                    b:Note("No Tetris data yet. Play a game to initialise records.")
                end
            end,
        },
        {
            key   = "DUNGEON",
            label = "Dungeon",
            desc  = "Dungeon Dwellers statistics and pass rewards.",
            build = function(b)
                local function dd()
                    local db = cgDB(); return db and db.soloGames and db.soloGames.dungeon
                end
                b:Section("Dungeon Dwellers stats")
                local d = dd()
                if d then
                    b:Note("Runs: " .. tostring(d.runs or 0) .. "  \xc2\xb7  Best level: " .. tostring(d.bestLevel or 0) .. "  \xc2\xb7  High score: " .. tostring(d.highScore or 0))
                    b:Note("Kills: " .. tostring(d.kills or 0) .. "  \xc2\xb7  Boss kills: " .. tostring(d.bosses or 0) .. "  \xc2\xb7  Minion kills: " .. tostring(d.minions or 0))
                    local shards = d.armourShards or 0
                    local tokens = d.portraitTokens or 0
                    if shards > 0 or tokens > 0 then
                        b:Note("Armour shards: " .. tostring(shards) .. "  \xc2\xb7  Portrait tokens: " .. tostring(tokens))
                    end
                else
                    b:Note("No dungeon data yet. Start a run from the Games drawer to initialise records.")
                end
                b:Section("Battle Pass progress")
                local bp = d and d.battlePass
                if bp then
                    b:Note("Pass XP: " .. tostring(bp.xp or 0))
                else
                    b:Note("No Battle Pass data attached to dungeon runs yet.")
                end
            end,
        },
        {
            key   = "CONTROLS",
            label = "Controls",
            desc  = "Game interface and control reference.",
            build = function(b)
                b:Section("Game controls")
                b:Note("CreshGames uses point-and-click and keyboard controls displayed on each game\xe2\x80\x99s own interface. No custom keybindings are configured here.")
                b:Section("Keyboard shortcuts")
                b:Note("Tetris: Arrow keys or WASD to move, Space to hard-drop, Escape to pause.")
                b:Note("Chess: Click to select, click to move. Escape cancels selection.")
                b:Note("Card games: Click cards and action buttons. Escape closes the game.")
                b:Note("Dungeon Dwellers: Mouse clicks for all actions. Keyboard not required.")
            end,
        },
        {
            key   = "NOTIFICATIONS",
            label = "Notifications",
            desc  = "CreshGames notification card categories. Requires CreshChat.",
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
            key   = "RESET",
            label = "Reset",
            desc  = "Permanently reset CreshGames data. Cannot be undone.",
            build = function(b)
                b:Section("Reset game data")
                b:Note("WARNING: The buttons below permanently delete CreshGames data. CreshChat settings, chat history and CreshCollect data are not affected.")
                b:Buttons({
                    { "RESET GAME STATS", function()
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
                    end, 160 },
                })
                b:Note("Resets all solo game stats, leaderboards, multiplayer records and game progression. A UI reload follows to reinitialise the database. Cresh Coins and Battle Pass XP are stored in CreshCollect and are not affected here.")
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
