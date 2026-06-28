local _, CC = ...
if not CC then return end

local Developer = {
    version = CC.version,
    expectedModules = {
        "Core", "SoundLibrary", "Quest", "Friends", "ThemeLibrary",
        "CardDeckLibrary", "CardDecks", "UI", "ChessAssets", "DungeonAssets",
        "Tetris", "Games", "SoloGames", "BattlePass", "GameProgression", "GameAudio",
        "Voice", "Quality", "Settings", "Developer",
        "Achievements", "AchievementExpansion", "ClassAchievements",
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
    end
    return originalHandleSlashCommand(self, input)
end

local originalShowHelp = CC.ShowHelp
function CC:ShowHelp()
    originalShowHelp(self)
    self:Print("/cc devreport - show build, module, database and asset status")
    self:Print("/cc modules - list loaded CreshChat modules")
    self:Print("/cc assets - report registered themes and media libraries")
end
