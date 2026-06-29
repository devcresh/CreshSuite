local _, CC = ...
if not CC then return end

local Developer = {
    version = CC.version,
    expectedModules = {
        "Core", "ProgressRouter", "SoundLibrary", "Quest", "Friends", "ThemeLibrary",
        "CardDeckLibrary", "CardDecks", "UI", "ChessAssets", "DungeonAssets",
        "Tetris", "Games", "SoloGames", "BattlePass", "GameProgression", "GameAudio",
        "Voice", "Quality", "Settings", "Developer",
        "Achievements", "AchievementExpansion", "ClassAchievements", "DungeonAchievements",
        "DungeonContent", "DungeonDwellersPass",
    },
}
CC.Developer = Developer
if CC.RegisterModule then CC:RegisterModule("Developer", Developer) end

local function countTable(value)
    local total = 0
    if type(value) ~= "table" then return total end
    for _ in pairs(value) do total = total + 1 end
    return total
end

local function yesNo(value)
    return value and "OK" or "MISSING"
end

local function join(values, separator)
    local output = ""
    for index, value in ipairs(values) do
        if index > 1 then output = output .. (separator or ", ") end
        output = output .. tostring(value)
    end
    return output
end

function Developer:GetModuleStatus()
    local loaded, missing = {}, {}
    for _, name in ipairs(self.expectedModules) do
        if CC.modules and CC.modules[name] then loaded[#loaded + 1] = name
        else missing[#missing + 1] = name end
    end
    return loaded, missing
end

function Developer:GetDatabaseStatus()
    local required = {
        "ui", "notifications", "notificationPriorities", "sounds", "soundChoices", "soundVolumes", "colors", "positions",
        "sizes", "history", "soloGames", "arcadeRewards", "gameProgression",
        "gameAudio", "voice", "gameHistory", "gameLeaderboards", "characterProfiles",
    }
    local missing = {}
    for _, key in ipairs(required) do
        if not CC.db or type(CC.db[key]) ~= "table" then missing[#missing + 1] = key end
    end
    local schemaOK = CC.db and tonumber(CC.db.version) == tonumber(CC.schemaVersion)
    return schemaOK, missing
end

function Developer:GetAssetCounts()
    local sounds = _G.CreshChatSoundLibrary
    local decks = _G.CreshChatCardDecks
    local chess = _G.CreshChatChessTextures
    local dungeon = _G.CreshChatDungeonDwellersSets

    local deckCount, cardFaces = 0, 0
    if type(decks) == "table" then
        for _, deck in pairs(decks) do
            deckCount = deckCount + 1
            cardFaces = cardFaces + countTable(deck.cards)
        end
    end

    local dungeonSets, dungeonAssets = 0, 0
    if type(dungeon) == "table" then
        for _, set in pairs(dungeon) do
            dungeonSets = dungeonSets + 1
            dungeonAssets = dungeonAssets + countTable(set.assets)
        end
    end

    return {
        sounds = sounds and #(sounds.order or {}) or 0,
        cardDecks = deckCount,
        cardFaces = cardFaces,
        chessPieces = chess and countTable(chess.Notation) or 0,
        dungeonSets = dungeonSets,
        dungeonAssets = dungeonAssets,
        globalThemes = CC.UI and countTable(CC.UI.THEME_PRESETS) or 0,
        guildThemes = CC.UI and countTable(CC.UI.GUILD_THEME_PRESETS) or 0,
        tetrisThemes = CC.Tetris and CC.Tetris.GetThemeCount and CC.Tetris:GetThemeCount() or 0,
    }
end

function Developer:GetRuntimeReport()
    local loaded, missingModules = self:GetModuleStatus()
    local schemaOK, missingData = self:GetDatabaseStatus()
    local assets = self:GetAssetCounts()
    local profileCount = countTable(CC.db and CC.db.characterProfiles)
    local activeProfile = CC.GetCurrentCharacterProfileKey and CC:GetCurrentCharacterProfileKey() or "unknown"
    local lines = {
        "Developer report · build " .. tostring(CC.version) .. " · schema " .. tostring(CC.db and CC.db.version or "not loaded") .. "/" .. tostring(CC.schemaVersion),
        "Profiles: " .. tostring(profileCount) .. " character profile(s) · active " .. tostring(activeProfile),
        "Modules: " .. tostring(#loaded) .. "/" .. tostring(#self.expectedModules) .. " loaded" .. (#missingModules > 0 and (" · missing " .. join(missingModules)) or " · all expected modules present"),
        "Database: schema " .. yesNo(schemaOK) .. (#missingData > 0 and (" · missing tables " .. join(missingData)) or " · required root tables present"),
        "Assets: " .. tostring(assets.sounds) .. " sounds · " .. tostring(assets.cardDecks) .. " decks / " .. tostring(assets.cardFaces) .. " card faces · " .. tostring(assets.chessPieces) .. " chess pieces",
        "Assets: " .. tostring(assets.dungeonSets) .. " dungeon sets / " .. tostring(assets.dungeonAssets) .. " entries · " .. tostring(assets.globalThemes) .. " global themes · " .. tostring(assets.guildThemes) .. " Guild themes · " .. tostring(assets.tetrisThemes) .. " Tetris sets",
        "Documentation: Interface/AddOns/CreshChat/Docs/DEVELOPER_GUIDE.md",
    }
    local prog = _G.CreshChatDB and _G.CreshChatDB.accountProgression
    local migCount = prog and prog._v77MigrationCount
    if migCount and migCount > 0 then
        lines[#lines + 1] = "Migration v77: " .. tostring(migCount) .. " achievement key(s) renamed to stable ACH_WOW_*/ACH_DD_* IDs"
    end
    return lines
end

function Developer:PrintRuntimeReport()
    for _, line in ipairs(self:GetRuntimeReport()) do
        if CC.Print then CC:Print(line) end
    end
end

function Developer:PrintModules()
    local loaded, missing = self:GetModuleStatus()
    if CC.Print then
        CC:Print("Loaded modules (" .. tostring(#loaded) .. "): " .. join(loaded))
        if #missing > 0 then CC:Print("Missing modules: " .. join(missing)) end
    end
end

function Developer:PrintAssets()
    local a = self:GetAssetCounts()
    if not CC.Print then return end
    CC:Print("Asset library: " .. tostring(a.sounds) .. " sounds, " .. tostring(a.cardDecks) .. " card decks, " .. tostring(a.cardFaces) .. " card faces.")
    CC:Print("Asset library: " .. tostring(a.chessPieces) .. " chess textures, " .. tostring(a.dungeonSets) .. " Dungeon Dweller sets, " .. tostring(a.dungeonAssets) .. " Dungeon Dweller entries.")
    CC:Print("Theme library: " .. tostring(a.globalThemes) .. " global themes, " .. tostring(a.guildThemes) .. " Guild themes and " .. tostring(a.tetrisThemes) .. " Tetris piece sets.")
end

function Developer:HandleProgressCommand(arg)
    local R = CC.ProgressRouter
    if not R then
        if CC.Print then CC:Print("[ProgressRouter] module not loaded") end
        return
    end
    if arg == "test" then
        self:RunProgressRouterTests()
    elseif arg == "log" then
        local entries = R:GetDevLog()
        if not CC.Print then return end
        if #entries == 0 then
            CC:Print("[ProgressRouter] log empty (dev mode " .. (R:IsDevMode() and "ON" or "OFF") .. ")")
        else
            CC:Print("[ProgressRouter] rejection log (" .. #entries .. " entries, " .. R:GetDevLogCount() .. " total written):")
            for _, entry in ipairs(entries) do
                CC:Print("  [" .. tostring(entry.tag) .. "] " .. tostring(entry.message))
            end
        end
    elseif arg == "clear" then
        R:ClearDevLog()
        if CC.Print then CC:Print("[ProgressRouter] log cleared") end
    elseif arg == "on" then
        R:EnableDevMode(true)
        if CC.Print then CC:Print("[ProgressRouter] dev mode ON - rejected events will be logged") end
    elseif arg == "off" then
        R:EnableDevMode(false)
        if CC.Print then CC:Print("[ProgressRouter] dev mode OFF") end
    else
        if not CC.Print then return end
        CC:Print("/cc progress test   - run the 9 validation tests")
        CC:Print("/cc progress log    - print the rejection ring buffer")
        CC:Print("/cc progress clear  - clear the ring buffer")
        CC:Print("/cc progress on/off - enable or disable dev mode logging")
    end
end

function Developer:RunProgressRouterTests()
    local R = CC.ProgressRouter
    if not R then
        if CC.Print then CC:Print("[ProgressRouter] module not loaded - cannot test") end
        return
    end
    local wasDevMode = R:IsDevMode()
    R:EnableDevMode(true)
    R:ClearDevLog()

    local passed, failed = 0, 0
    local function check(label, result, expectOk, sim, expectSim)
        local pass = (result == expectOk) and (expectSim == nil or sim == expectSim)
        if pass then passed = passed + 1 else failed = failed + 1 end
        if CC.Print then
            CC:Print("[ProgressRouter] " .. (pass and "PASS" or "FAIL") .. " " .. label)
        end
    end

    -- 1. Valid Main Battle Pass event
    local e1 = R:BuildProgressEvent({
        sourceSystem = R.SYSTEMS.WOW_BATTLE_PASS, sourceGame = R.GAMES.WOW,
        progressNamespace = R.GAMES.WOW, objectiveType = R.OBJECTIVES.MOB_KILL, amount = 1,
    })
    local ok1, _, sim1 = R:RouteProgressEvent(e1)
    check("1: valid Main BP event", ok1, true, sim1, false)

    -- 2. Valid Dungeon Dwellers event
    local e2 = R:BuildProgressEvent({
        sourceSystem = R.SYSTEMS.DUNGEON_DWELLER_BATTLE_PASS, sourceGame = R.GAMES.DUNGEON_DWELLER,
        progressNamespace = R.GAMES.DUNGEON_DWELLER, objectiveType = R.OBJECTIVES.DD_ENEMY_KILL, amount = 2,
    })
    local ok2, _, sim2 = R:RouteProgressEvent(e2)
    check("2: valid DD event", ok2, true, sim2, false)

    -- 3. Valid WoW achievement event
    local e3 = R:BuildProgressEvent({
        sourceSystem = R.SYSTEMS.WOW_ACHIEVEMENTS, sourceGame = R.GAMES.WOW,
        progressNamespace = R.GAMES.WOW, objectiveType = R.OBJECTIVES.ACHIEVEMENT_UNLOCK,
        amount = 10, achievementId = "COMBAT_KILLS_10",
    })
    local ok3, _, sim3 = R:RouteProgressEvent(e3)
    check("3: valid WoW achievement event", ok3, true, sim3, false)

    -- 4. Invalid source system
    local e4 = R:BuildProgressEvent({
        sourceSystem = "FAKE_SYSTEM", sourceGame = R.GAMES.WOW,
        progressNamespace = R.GAMES.WOW, objectiveType = R.OBJECTIVES.MOB_KILL, amount = 1,
    })
    local ok4 = R:RouteProgressEvent(e4)
    check("4: invalid sourceSystem rejected", ok4, false)

    -- 5. Invalid destination namespace
    local e5 = R:BuildProgressEvent({
        sourceSystem = R.SYSTEMS.WOW_BATTLE_PASS, sourceGame = R.GAMES.WOW,
        progressNamespace = "FAKE_NAMESPACE", objectiveType = R.OBJECTIVES.MOB_KILL, amount = 1,
    })
    local ok5 = R:RouteProgressEvent(e5)
    check("5: invalid progressNamespace rejected", ok5, false)

    -- 6. Invalid amount (zero)
    local e6 = R:BuildProgressEvent({
        sourceSystem = R.SYSTEMS.WOW_BATTLE_PASS, sourceGame = R.GAMES.WOW,
        progressNamespace = R.GAMES.WOW, objectiveType = R.OBJECTIVES.MOB_KILL, amount = 0,
    })
    local ok6 = R:RouteProgressEvent(e6)
    check("6: zero amount rejected", ok6, false)

    -- 7. Prohibited cross-system route (DUNGEON_DWELLER -> WOW)
    local e7 = R:BuildProgressEvent({
        sourceSystem = R.SYSTEMS.DUNGEON_DWELLER_BATTLE_PASS, sourceGame = R.GAMES.DUNGEON_DWELLER,
        progressNamespace = R.GAMES.WOW, objectiveType = R.OBJECTIVES.DD_ENEMY_KILL, amount = 1,
    })
    local ok7 = R:RouteProgressEvent(e7)
    check("7: DD->WOW route prohibited", ok7, false)

    -- 8. Simulation flag: validates, returns isSimulation=true, does not apply
    local e8 = R:BuildProgressEvent({
        sourceSystem = R.SYSTEMS.WOW_BATTLE_PASS, sourceGame = R.GAMES.WOW,
        progressNamespace = R.GAMES.WOW, objectiveType = R.OBJECTIVES.MOB_KILL,
        amount = 1, isSimulation = true,
    })
    local ok8, _, sim8 = R:RouteProgressEvent(e8)
    check("8: simulation accepted, isSimulation=true returned", ok8, true, sim8, true)

    -- 9. Legacy caller through compatibility adapter
    local ok9, _, sim9 = R:ValidateLegacyPassXP(5, "Test quest reward")
    check("9: legacy adapter accepts valid XP", ok9, true, sim9, false)

    if CC.Print then
        CC:Print(string.format("[ProgressRouter] %d passed, %d failed. Ring buffer: %d entries written.",
            passed, failed, R:GetDevLogCount()))
    end
    R:EnableDevMode(wasDevMode)
end

local originalHandleSlashCommand = CC.HandleSlashCommand
function CC:HandleSlashCommand(input)
    local command = string.lower(string.match(tostring(input or ""), "^(%S*)") or "")
    if command == "dev" or command == "devreport" or command == "developer" then
        Developer:PrintRuntimeReport()
        return
    elseif command == "modules" then
        Developer:PrintModules()
        return
    elseif command == "assets" then
        Developer:PrintAssets()
        return
    elseif command == "progress" then
        local arg = string.lower(string.match(tostring(input or ""), "^%S+%s+(%S*)") or "")
        Developer:HandleProgressCommand(arg)
        return
    end
    return originalHandleSlashCommand(self, input)
end

local originalShowHelp = CC.ShowHelp
function CC:ShowHelp()
    originalShowHelp(self)
    self:Print("/cc devreport - show build, module, database and asset status")
    self:Print("/cc modules - list loaded CreshChat modules")
    self:Print("/cc assets - report registered themes and media libraries")
    self:Print("/cc progress [test|log|clear|on|off] - ProgressRouter diagnostics")
end
