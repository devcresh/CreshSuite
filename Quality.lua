local ADDON_NAME, CC = ...
if not CC or not CC.UI then return end

local UI = CC.UI
local max, min, floor = math.max, math.min, math.floor

local Quality = {
    build = CC.version,
    refresh = {
        full = 0,
        targeted = 0,
        flushes = 0,
        coalesced = 0,
        popouts = 0,
        visualApplies = 0,
    },
    pending = nil,
    visualApplyQueued = false,
}
CC.Quality = Quality
if CC.RegisterModule then CC:RegisterModule("Quality", Quality) end

local function clamp(value, low, high, fallback)
    value = tonumber(value)
    if not value then value = fallback end
    return max(low, min(high, value))
end

local function countTable(tbl)
    local count = 0
    for _ in pairs(tbl or {}) do count = count + 1 end
    return count
end

local function popoutID(channel, target)
    if channel == "WHISPER" then
        target = CC:ResolveWhisperConversation(target)
        return target and ("WHISPER:" .. tostring(target)) or nil
    elseif channel == "QUEST" then
        return target and ("QUEST:" .. tostring(target)) or nil
    end
    return channel
end

function Quality:SanitizeDatabase()
    if not CC.db then return false end
    if CC.EnsureChatStorage then CC:EnsureChatStorage() end
    local db = CC.db
    db.ui = db.ui or {}
    db.ui.consoleTabs = db.ui.consoleTabs or {}
    local defaultTabs = { FRIENDS=true, WHISPER=true, GUILD=true, GENERAL=true, QUEST=true, COMBAT=true, TRADE=false, PARTY=false, RAID=false, INSTANCE=false, LFG=false, SAY=false, YELL=false, EMOTE=false, LOCALDEFENSE=false }
    for key, value in pairs(defaultTabs) do if db.ui.consoleTabs[key] == nil then db.ui.consoleTabs[key] = value end end
    db.notifications = db.notifications or {}
    db.notificationPriorities = db.notificationPriorities or {}
    local defaultNotifications = { whisper=true, guild=true, quest=true, partyMessage=true, partyInvite=true, mentions=true, friends=true, system=true, game=true }
    for key, value in pairs(defaultNotifications) do if db.notifications[key] == nil then db.notifications[key] = value end end
    local defaultPriorities = { whisper="HIGH", guild="NORMAL", quest="HIGH", partyMessage="HIGH", partyInvite="CRITICAL", mentions="NORMAL", friends="LOW", system="NORMAL", game="LOW" }
    for key, value in pairs(defaultPriorities) do
        local priority = string.upper(tostring(db.notificationPriorities[key] or value))
        if priority ~= "CRITICAL" and priority ~= "HIGH" and priority ~= "NORMAL" and priority ~= "LOW" then priority = value end
        db.notificationPriorities[key] = priority
    end
    if db.ui.notificationCardsEnabled == nil then db.ui.notificationCardsEnabled = true end
    db.sounds = db.sounds or {}
    if db.sounds.partyInvite == nil then db.sounds.partyInvite = db.sounds.party ~= false end
    if db.sounds.partyMessage == nil then db.sounds.partyMessage = true end
    db.soundChoices = db.soundChoices or {}
    db.soundVolumes = db.soundVolumes or { whisper=0.65,guild=0.55,partyInvite=0.65,partyMessage=0.50,quest=0.55,mentions=0.50,friends=0.45,game=0.55,system=0.45 }
    for _, key in ipairs({"whisper","guild","partyInvite","partyMessage","quest","mentions","friends","game","system"}) do db.soundVolumes[key]=math.max(0,math.min(1,tonumber(db.soundVolumes[key]) or 0.5)) end
    db.gameAudio = db.gameAudio or { musicEnabled=true,musicVolume=0.35,effectsEnabled=true,effectsVolume=0.55 }
    db.gameAudio.musicVolume=math.max(0,math.min(1,tonumber(db.gameAudio.musicVolume) or 0.35))
    db.gameAudio.effectsVolume=math.max(0,math.min(1,tonumber(db.gameAudio.effectsVolume) or 0.55))
    db.voice=db.voice or {enabled=true}
    local allSoundChoices = {
        OFF=true, DING=true, CHIME=true, WHISPER=true, SOFT=true, SCROLL=true,
        MESSAGE=true, QUEST=true, READY=true, WARNING=true, OPEN=true, COIN=true,
    }
    local customSoundLibrary = _G.CreshChatSoundLibrary
    if customSoundLibrary and type(customSoundLibrary.order) == "table" then
        for _, soundKey in ipairs(customSoundLibrary.order) do
            allSoundChoices[string.upper(tostring(soundKey))] = true
        end
    end
    local validSounds = {
        whisper = allSoundChoices,
        guild = allSoundChoices,
        partyInvite = allSoundChoices,
        partyMessage = allSoundChoices,
        quest = allSoundChoices,
        mentions = allSoundChoices,
        friends = allSoundChoices,
        game = allSoundChoices,
        system = allSoundChoices,
    }
    local soundFallback = { whisper="WHISPER", guild="CHIME", partyInvite="READY", partyMessage="MESSAGE", quest="QUEST", mentions="MESSAGE", friends="SOFT", game="COIN", system="OFF" }
    for key, allowed in pairs(validSounds) do
        local value = string.upper(tostring(db.soundChoices[key] or soundFallback[key]))
        if not allowed[value] then value = soundFallback[key] end
        db.soundChoices[key] = value
    end
    db.sounds.whisper = db.soundChoices.whisper ~= "OFF"
    db.sounds.guild = db.soundChoices.guild ~= "OFF"
    db.sounds.partyInvite = db.soundChoices.partyInvite ~= "OFF"
    db.sounds.party = db.sounds.partyInvite
    db.sounds.partyMessage = db.soundChoices.partyMessage ~= "OFF"
    db.sounds.quest = db.soundChoices.quest ~= "OFF"
    db.sounds.mentions = db.soundChoices.mentions ~= "OFF"
    db.sounds.friends = db.soundChoices.friends ~= "OFF"
    db.sounds.game = db.soundChoices.game ~= "OFF"
    db.sounds.system = db.soundChoices.system ~= "OFF"
    db.history = db.history or { whispers = {}, guild = {}, general = {}, combat = {} }
    db.history.whispers = db.history.whispers or {}
    db.history.guild = db.history.guild or {}
    db.history.general = db.history.general or {}
    db.history.combat = db.history.combat or {}
    db.history.quests = db.history.quests or {}
    db.questConversations = db.questConversations or {}
    db.commandHistory = db.commandHistory or {}
    db.playerCache = db.playerCache or {}
    db.soloGames = db.soloGames or {}
    db.soloGames.frogger = db.soloGames.frogger or { unlocked = 1, bestLevel = 0, highScore = 0, games = 0 }
    local frogger = db.soloGames.frogger
    frogger.unlocked = max(1, floor(tonumber(frogger.unlocked) or 1))
    frogger.bestLevel = max(0, floor(tonumber(frogger.bestLevel) or 0))
    frogger.highScore = max(0, floor(tonumber(frogger.highScore) or 0))
    frogger.games = max(0, floor(tonumber(frogger.games) or 0))
    db.soloGames.dungeon = db.soloGames.dungeon or { runs = 0, bestLevel = 0, bestRoom = 0, kills = 0, bosses = 0, minions = 0, highScore = 0, bossCoins = 0, class = "", enemyKillsByType = {}, unlockedArmour = {}, equippedArmour = {} }
    local dungeon = db.soloGames.dungeon
    dungeon.runs = max(0, floor(tonumber(dungeon.runs) or 0))
    dungeon.bestLevel = max(0, floor(tonumber(dungeon.bestLevel) or tonumber(dungeon.bestRoom) or 0))
    dungeon.bestRoom = max(dungeon.bestLevel, floor(tonumber(dungeon.bestRoom) or 0))
    dungeon.kills = max(0, floor(tonumber(dungeon.kills) or 0))
    dungeon.bosses = max(0, floor(tonumber(dungeon.bosses) or 0))
    dungeon.minions = max(0, floor(tonumber(dungeon.minions) or 0))
    dungeon.highScore = max(0, floor(tonumber(dungeon.highScore) or 0))
    dungeon.bossCoins = max(0, floor(tonumber(dungeon.bossCoins) or 0))
    dungeon.class = string.upper(tostring(dungeon.class or ""))
    dungeon.enemyKillsByType = type(dungeon.enemyKillsByType) == "table" and dungeon.enemyKillsByType or {}
    dungeon.unlockedArmour = type(dungeon.unlockedArmour) == "table" and dungeon.unlockedArmour or {}
    dungeon.equippedArmour = type(dungeon.equippedArmour) == "table" and dungeon.equippedArmour or {}
    for enemyKey, count in pairs(dungeon.enemyKillsByType) do
        local normalized = string.upper(tostring(enemyKey or ""))
        local safeCount = max(0, floor(tonumber(count) or 0))
        if normalized == "" then dungeon.enemyKillsByType[enemyKey] = nil
        elseif normalized ~= enemyKey then dungeon.enemyKillsByType[normalized] = safeCount; dungeon.enemyKillsByType[enemyKey] = nil
        else dungeon.enemyKillsByType[enemyKey] = safeCount end
    end
    db.soloGames.chess = db.soloGames.chess or { wins = 0, losses = 0, draws = 0, games = 0, level = 3, bestLevel = 0 }
    local chess = db.soloGames.chess
    chess.wins = max(0, floor(tonumber(chess.wins) or 0))
    chess.losses = max(0, floor(tonumber(chess.losses) or 0))
    chess.draws = max(0, floor(tonumber(chess.draws) or 0))
    chess.games = max(chess.wins + chess.losses + chess.draws, floor(tonumber(chess.games) or 0))
    chess.level = max(1, min(5, floor(tonumber(chess.level) or 3)))
    chess.bestLevel = max(0, min(5, floor(tonumber(chess.bestLevel) or 0)))
    db.soloGames.tetris = db.soloGames.tetris or { wins = 0, losses = 0, games = 0, highScore = 0, bestLines = 0 }
    local tetris = db.soloGames.tetris
    tetris.wins = max(0, floor(tonumber(tetris.wins) or 0))
    tetris.losses = max(0, floor(tonumber(tetris.losses) or 0))
    tetris.games = max(tetris.wins + tetris.losses, floor(tonumber(tetris.games) or 0))
    tetris.highScore = max(0, floor(tonumber(tetris.highScore) or 0))
    tetris.bestLines = max(0, floor(tonumber(tetris.bestLines) or 0))
    tetris.totalLines = max(tetris.bestLines, floor(tonumber(tetris.totalLines) or 0))
    tetris.vsWins = max(0, floor(tonumber(tetris.vsWins) or 0))
    tetris.vsLosses = max(0, floor(tonumber(tetris.vsLosses) or 0))
    tetris.endlessRuns = max(0, floor(tonumber(tetris.endlessRuns) or 0))
    tetris.cpuLevel = max(1, min(5, floor(tonumber(tetris.cpuLevel) or 3)))
    tetris.cpuVersusMode = string.upper(tostring(tetris.cpuVersusMode or "ENDLESS"))
    if tetris.cpuVersusMode ~= "ATTACK" then tetris.cpuVersusMode = "ENDLESS" end
    tetris.multiplayerMode = string.upper(tostring(tetris.multiplayerMode or "ENDLESS"))
    if tetris.multiplayerMode ~= "ATTACK" then tetris.multiplayerMode = "ENDLESS" end
    local duration = max(5, min(60, floor(tonumber(tetris.multiplayerDuration) or 10)))
    local allowedDuration = { [5]=true, [10]=true, [15]=true, [30]=true, [45]=true, [60]=true }
    if not allowedDuration[duration] then duration = 10 end
    tetris.multiplayerDuration = duration
    local soloDuration = max(5, min(60, floor(tonumber(tetris.soloDuration) or 10)))
    if not allowedDuration[soloDuration] then soloDuration = 10 end
    tetris.soloDuration = soloDuration
    tetris.mode = string.upper(tostring(tetris.mode or "ENDLESS"))
    if tetris.mode ~= "CPU" then tetris.mode = "ENDLESS" end
    tetris.revealLines = max(0, floor(tonumber(tetris.revealLines) or 0))
    tetris.revealCompleted = max(0, floor(tonumber(tetris.revealCompleted) or 0))
    tetris.revealBackgroundKey = string.upper(tostring(tetris.revealBackgroundKey or tetris.revealThemeKey or ""))
    tetris.revealThemeKey = tetris.revealBackgroundKey
    tetris.unlockedBackgrounds = type(tetris.unlockedBackgrounds) == "table" and tetris.unlockedBackgrounds or {}
    tetris.backgroundUnlockSources = type(tetris.backgroundUnlockSources) == "table" and tetris.backgroundUnlockSources or {}
    tetris.selectedBackground = string.upper(tostring(tetris.selectedBackground or ""))
    tetris.passXP = max(0, floor(tonumber(tetris.passXP) or 0))
    tetris.passClaimed = type(tetris.passClaimed) == "table" and tetris.passClaimed or {}
    tetris.unlockedThemes = type(tetris.unlockedThemes) == "table" and tetris.unlockedThemes or {}
    tetris.themeUnlockSources = type(tetris.themeUnlockSources) == "table" and tetris.themeUnlockSources or {}
    tetris.unlockedThemes.CLASSIC_BLOCKS = true
    tetris.themeUnlockSources.CLASSIC_BLOCKS = tetris.themeUnlockSources.CLASSIC_BLOCKS or "DEFAULT"
    tetris.selectedTheme = string.upper(tostring(tetris.selectedTheme or "CLASSIC_BLOCKS"))
    db.soloGames.higherlower = db.soloGames.higherlower or { wins = 0, losses = 0, draws = 0, games = 0, bankroll = 100, bestBank = 100, bestStreak = 0 }
    local higher = db.soloGames.higherlower
    higher.wins = max(0, floor(tonumber(higher.wins) or 0))
    higher.losses = max(0, floor(tonumber(higher.losses) or 0))
    higher.draws = max(0, floor(tonumber(higher.draws) or 0))
    higher.games = max(higher.wins + higher.losses + higher.draws, floor(tonumber(higher.games) or 0))
    higher.bankroll = max(0, floor(tonumber(higher.bankroll) or tonumber(higher.bestBank) or 100))
    higher.bestBank = max(higher.bankroll, floor(tonumber(higher.bestBank) or 100))
    higher.bestStreak = max(0, floor(tonumber(higher.bestStreak) or 0))
    db.arcadeRewards = type(db.arcadeRewards) == "table" and db.arcadeRewards or {}
    local rewards = db.arcadeRewards
    rewards.coins = max(0, floor(tonumber(rewards.coins) or 0))
    rewards.lifetimeCoins = max(rewards.coins, floor(tonumber(rewards.lifetimeCoins) or rewards.coins))
    rewards.gameCoins = max(0, floor(tonumber(rewards.gameCoins) or 0))
    rewards.activityCoins = max(0, floor(tonumber(rewards.activityCoins) or 0))
    rewards.explorationCoins = max(0, floor(tonumber(rewards.explorationCoins) or 0))
    rewards.spentCoins = max(0, floor(tonumber(rewards.spentCoins) or 0))
    rewards.passXP = max(0, floor(tonumber(rewards.passXP) or 0))
    rewards.gamesRewarded = max(0, floor(tonumber(rewards.gamesRewarded) or 0))
    rewards.claimed = type(rewards.claimed) == "table" and rewards.claimed or {}
    rewards.unlockedThemes = type(rewards.unlockedThemes) == "table" and rewards.unlockedThemes or {}
    rewards.themeUnlockSources = type(rewards.themeUnlockSources) == "table" and rewards.themeUnlockSources or {}
    rewards.recent = type(rewards.recent) == "table" and rewards.recent or {}

    db.gameProgression = type(db.gameProgression) == "table" and db.gameProgression or {}
    db.gameProgression.games = type(db.gameProgression.games) == "table" and db.gameProgression.games or {}
    local validProgressionGames = { FROGGER=true, DUNGEON=true, CHESS=true, HOLDEM=true, BLACKJACK=true, HIGHERLOWER=true, TETRIS=true, PONG=true }
    for storedKey, record in pairs(db.gameProgression.games) do
        local gameKey = string.upper(tostring(storedKey or ""))
        if not validProgressionGames[gameKey] or type(record) ~= "table" then
            db.gameProgression.games[storedKey] = nil
        else
            if storedKey ~= gameKey then
                db.gameProgression.games[gameKey] = record
                db.gameProgression.games[storedKey] = nil
            end
            record.level = max(1, floor(tonumber(record.level) or 1))
            record.xp = max(0, floor(tonumber(record.xp) or 0))
            record.plays = max(0, floor(tonumber(record.plays) or 0))
            record.wins = max(0, floor(tonumber(record.wins) or 0))
            record.draws = max(0, floor(tonumber(record.draws) or 0))
            record.losses = max(0, floor(tonumber(record.losses) or 0))
            record.lastPlayed = max(0, tonumber(record.lastPlayed) or 0)
        end
    end
    db.gameProgression.exploration = type(db.gameProgression.exploration) == "table" and db.gameProgression.exploration or {}
    local exploration = db.gameProgression.exploration
    exploration.totalSteps = max(0, floor(tonumber(exploration.totalSteps) or 0))
    exploration.rewardedStepBlocks = max(0, floor(tonumber(exploration.rewardedStepBlocks) or 0))
    exploration.rewardedStepBlocks = min(exploration.rewardedStepBlocks, floor(exploration.totalSteps / 1000))
    exploration.distanceRemainder = max(0, tonumber(exploration.distanceRemainder) or 0)
    exploration.visitedAreas = type(exploration.visitedAreas) == "table" and exploration.visitedAreas or {}
    exploration.visitedZones = type(exploration.visitedZones) == "table" and exploration.visitedZones or {}
    exploration.newAreas = max(0, floor(tonumber(exploration.newAreas) or 0))
    exploration.newZones = max(0, floor(tonumber(exploration.newZones) or 0))
    exploration.dungeonClears = max(0, floor(tonumber(exploration.dungeonClears) or 0))
    exploration.totalKills = max(0, floor(tonumber(exploration.totalKills) or 0))
    exploration.coins = max(0, floor(tonumber(exploration.coins) or 0))
    exploration.passXP = max(0, floor(tonumber(exploration.passXP) or 0))
    db.gameProgression.achievements = type(db.gameProgression.achievements) == "table" and db.gameProgression.achievements or {}
    local achievements = db.gameProgression.achievements
    achievements.unlocked = type(achievements.unlocked) == "table" and achievements.unlocked or {}
    achievements.stats = type(achievements.stats) == "table" and achievements.stats or {}
    achievements.uniqueBosses = type(achievements.uniqueBosses) == "table" and achievements.uniqueBosses or {}
    achievements.professionRanks = type(achievements.professionRanks) == "table" and achievements.professionRanks or {}
    achievements.visitedZones = type(achievements.visitedZones) == "table" and achievements.visitedZones or {}
    achievements.totalCoins = max(0, floor(tonumber(achievements.totalCoins) or 0))
    achievements.totalPassXP = max(0, floor(tonumber(achievements.totalPassXP) or 0))
    for _, statKey in ipairs({"deaths", "flights", "dungeonMobs", "bosses", "dungeons"}) do
        achievements.stats[statKey] = max(0, floor(tonumber(achievements.stats[statKey]) or 0))
    end

    db.gameHistory = type(db.gameHistory) == "table" and db.gameHistory or {}
    while #db.gameHistory > 60 do table.remove(db.gameHistory) end
    db.gameLeaderboards = type(db.gameLeaderboards) == "table" and db.gameLeaderboards or {}
    db.multiplayerStats = type(db.multiplayerStats) == "table" and db.multiplayerStats or {}
    local ui = db.ui
    ui.scale = clamp(ui.scale, 0.70, 1.50, 0.95)
    ui.messageScale = clamp(ui.messageScale, 0.80, 1.35, 1)
    ui.iconSize = clamp(ui.iconSize, 22, 44, 26)
    ui.composerScale = clamp(ui.composerScale, 0.70, 1.50, 1)
    ui.sharedDockWidth = clamp(ui.sharedDockWidth, 320, 720, 470)
    ui.dockButtonWidth = clamp(ui.dockButtonWidth, 38, 64, 46)
    if ui.dockButtonWidth > ui.sharedDockWidth - 180 then
        ui.dockButtonWidth = min(64, max(38, ui.sharedDockWidth - 180))
    end
    ui.popoutWidth = clamp(ui.popoutWidth, 300, 620, 400)
    ui.popoutRows = floor(clamp(ui.popoutRows, 4, 10, 6) + 0.5)
    ui.popoutRowHeight = floor(clamp(ui.popoutRowHeight, 36, 68, 44) + 0.5)
    ui.popoutFadeDelay = clamp(ui.popoutFadeDelay, 1, 15, 4)
    ui.popoutFadeAlpha = clamp(ui.popoutFadeAlpha, 0.10, 0.70, 0.22)
    ui.rosterCollapsed = ui.rosterCollapsed == true
    ui.cardWidth = clamp(ui.cardWidth, 230, 440, 300)
    ui.cardHeight = clamp(ui.cardHeight, 56, 104, 68)
    ui.notificationScale = clamp(ui.notificationScale or ui.cardScale, 0.65, 1.50, 0.95)
    ui.cardScale = ui.notificationScale
    ui.notificationLineHeight = floor(clamp(ui.notificationLineHeight, 2, 6, 3) + 0.5)
    ui.secondaryCardWidthRatio = clamp(ui.secondaryCardWidthRatio, 0.72, 0.96, 0.88)
    ui.secondaryCardHeightRatio = clamp(ui.secondaryCardHeightRatio, 0.62, 0.92, 0.80)
    ui.cardSpacing = clamp(ui.cardSpacing, 0, 16, 6)
    ui.cardMaxVisible = floor(clamp(ui.cardMaxVisible, 1, 10, 6) + 0.5)
    ui.secondaryCardMaxVisible = floor(clamp(ui.secondaryCardMaxVisible, 1, 8, 4) + 0.5)
    ui.priorityCardDuration = clamp(ui.priorityCardDuration, 3, 30, 10)
    ui.secondaryCardDuration = clamp(ui.secondaryCardDuration, 2, 20, 6)
    ui.notificationSlideDirection = string.upper(tostring(ui.notificationSlideDirection or "BOTTOM"))
    if ui.notificationSlideDirection ~= "TOP" and ui.notificationSlideDirection ~= "BOTTOM" and ui.notificationSlideDirection ~= "LEFT" and ui.notificationSlideDirection ~= "RIGHT" then ui.notificationSlideDirection = "BOTTOM" end
    ui.animationDuration = clamp(ui.animationDuration, 0.08, 0.55, 0.20)
    ui.overheadBubbleDuration = clamp(ui.overheadBubbleDuration, 2, 15, 5)
    ui.overheadBubbleWidth = clamp(ui.overheadBubbleWidth, 120, 300, 180)
    ui.overheadBubbleScale = clamp(ui.overheadBubbleScale, 0.65, 1.35, 0.90)
    ui.dockWhisperWidth = clamp(ui.dockWhisperWidth, 140, 280, 190)
    ui.dockWhisperDuration = clamp(ui.dockWhisperDuration, 3, 15, 6)
    ui.overheadBubbles = false
    ui.popoutPrimary = false
    ui.autoArrange = false

    ui.popoutStyle = string.upper(tostring(ui.popoutStyle or "NORMAL"))
    if ui.popoutStyle ~= "NORMAL" and ui.popoutStyle ~= "COMPACT" then ui.popoutStyle = "NORMAL" end
    ui.portraitStyle = string.upper(tostring(ui.portraitStyle or "CLASS"))
    if ui.portraitStyle ~= "CLASS" and ui.portraitStyle ~= "2D" and ui.portraitStyle ~= "3D" then ui.portraitStyle = "CLASS" end
    ui.launcherMode = string.upper(tostring(ui.launcherMode or "SINGLE"))
    if ui.launcherMode ~= "SINGLE" and ui.launcherMode ~= "EXPANDED" then ui.launcherMode = "SINGLE" end
    if ui.launcherNotificationPulse == nil then ui.launcherNotificationPulse = true end
    if ui.launcherIdleFade == nil then ui.launcherIdleFade = false end
    if ui.launcherHideInCombat == nil then ui.launcherHideInCombat = false end
    ui.launcherIdleDelay = clamp(ui.launcherIdleDelay, 1, 30, 5)
    ui.launcherIdleAlpha = clamp(ui.launcherIdleAlpha, 0.05, 0.75, 0.18)

    db.historyLimit = floor(clamp(db.historyLimit, 40, 500, 120) + 0.5)
    db.combatHistoryLimit = floor(clamp(db.combatHistoryLimit, 80, 600, 220) + 0.5)
    CC:TrimHistory(db.history.guild)
    CC:TrimHistory(db.history.general)
    CC:TrimHistory(db.history.combat, db.combatHistoryLimit)
    for _, messages in pairs(db.history.whispers) do CC:TrimHistory(messages) end
    for _, messages in pairs(db.history.quests) do CC:TrimHistory(messages) end
    while #db.commandHistory > 50 do table.remove(db.commandHistory, 1) end

    -- Player metadata is useful for portraits, but an unlimited cache can grow for years.
    local cacheCount = countTable(db.playerCache)
    if cacheCount > 500 then
        local entries = {}
        for key, value in pairs(db.playerCache) do
            entries[#entries + 1] = { key = key, seen = type(value) == "table" and tonumber(value.lastSeen) or 0 }
        end
        table.sort(entries, function(a, b) return a.seen > b.seen end)
        for index = 401, #entries do db.playerCache[entries[index].key] = nil end
    end

    return true
end

function Quality:ApplyProfile(name)
    if not CC.db then return end
    name = string.upper(tostring(name or "BALANCED"))
    local ui = CC.db.ui
    if name == "MINIMAL" then
        ui.launcherMode = "SINGLE"
        ui.portraitStyle = "CLASS"
        ui.showPortraits = true
        ui.groupedMessages = true
        ui.popoutStyle = "COMPACT"
        ui.popoutRows = 6
        ui.windowAnimation = "FADE"
        ui.composerAnimation = "SLIDE_DOCK"
        ui.dockAnimation = "SLIDE_DOCK"
        ui.overheadBubbles = false
        CC.db.combatEnabled = false
    elseif name == "MESSENGER" then
        ui.launcherMode = "SINGLE"
        ui.portraitStyle = "2D"
        ui.showPortraits = true
        ui.groupedMessages = true
        ui.popoutStyle = "NORMAL"
        ui.windowAnimation = "POP"
        ui.composerAnimation = "SLIDE_DOCK"
        ui.dockAnimation = "SLIDE_DOCK"
        ui.overheadBubbles = false
        CC.db.combatEnabled = true
    elseif name == "POPOUT" then
        ui.popoutPrimary = false
        ui.popoutShowCommand = true
        ui.popoutFade = true
        ui.popoutStyle = "NORMAL"
        ui.autoArrange = false
        ui.launcherMode = "SINGLE"
    elseif name == "PERFORMANCE" then
        ui.portraitStyle = "CLASS"
        ui.showPortraits = true
        ui.windowAnimation = "NONE"
        ui.composerAnimation = "NONE"
        ui.dockAnimation = "NONE"
        ui.toastAnimation = "FADE"
        ui.overheadBubbles = false
        ui.cardCoalesce = true
        ui.groupedMessages = true
        CC.db.combatEnabled = false
    else
        name = "BALANCED"
        ui.launcherMode = "SINGLE"
        ui.portraitStyle = "CLASS"
        ui.showPortraits = true
        ui.groupedMessages = true
        ui.popoutStyle = "NORMAL"
        ui.windowAnimation = "SLIDE_LEFT"
        ui.composerAnimation = "SLIDE_DOCK"
        ui.dockAnimation = "SLIDE_DOCK"
        ui.toastAnimation = "FAN_UP"
        ui.overheadBubbles = false
        ui.autoArrange = false
        CC.db.combatEnabled = true
    end
    ui.qualityProfile = name
    self:SanitizeDatabase()
    if UI.ApplyVisualSettings then UI:ApplyVisualSettings() end
    if UI.RefreshPopoutStyles then UI:RefreshPopoutStyles() end
    if UI.FullSettings and UI.FullSettings.Refresh then UI.FullSettings:Refresh() end
    CC:Print("Quality profile applied: " .. name .. ".")
end

function UI:RefreshPopoutFor(channel, target)
    local id = popoutID(channel, target)
    local popout = id and self.popouts and self.popouts[id]
    if not popout or not popout:IsShown() then return end

    if popout.channel == "COMBAT" then
        popout.messageView:Refresh(CC.db.history.combat)
    elseif popout.channel == "GUILD" then
        popout.messageView:Refresh(CC.db.history.guild, "GUILD")
    elseif self:IsGeneralFeedMode(popout.channel) then
        popout.messageView:Refresh(self:GetGeneralMessagesForMode(popout.channel), "GENERAL")
    elseif popout.channel == "QUEST" then
        popout.messageView:Refresh((CC.db.history.quests or {})[popout.target] or {}, "QUEST")
    else
        local resolved = CC:ResolveWhisperConversation(popout.target)
        popout.target = resolved or popout.target
        popout.messageView:Refresh(CC.db.history.whispers[popout.target] or {}, "WHISPER")
        if popout.portrait and self.GetWhisperPortraitMessage then
            local portraitMessage = self:GetWhisperPortraitMessage(popout.target)
            self:UpdatePlayerPortrait(popout.portrait, popout.target, portraitMessage.guid, portraitMessage)
        end
    end
    Quality.refresh.popouts = Quality.refresh.popouts + 1
end

function UI:RequestRefresh(flags)
    flags = flags or {}
    if not Quality.pending then
        Quality.pending = { popouts = {} }
    else
        Quality.refresh.coalesced = Quality.refresh.coalesced + 1
    end
    local pending = Quality.pending
    for key, value in pairs(flags) do
        if key == "popout" and value then
            pending.popouts[value] = true
        elseif key == "popouts" and type(value) == "table" then
            for id in pairs(value) do pending.popouts[id] = true end
        elseif value then
            pending[key] = true
        end
    end
    Quality.refresh.targeted = Quality.refresh.targeted + 1
    if Quality.refreshQueued then return end
    Quality.refreshQueued = true
    local function flush()
        Quality.refreshQueued = false
        UI:FlushRequestedRefresh()
    end
    if C_Timer and C_Timer.After then C_Timer.After(0, flush) else flush() end
end

function UI:FlushRequestedRefresh()
    local pending = Quality.pending
    Quality.pending = nil
    if not pending or not self.initialized then return end
    Quality.refresh.flushes = Quality.refresh.flushes + 1

    if pending.conversations and self.RefreshConversationList then self:RefreshConversationList() end
    if pending.main and self.RefreshMainMessages then self:RefreshMainMessages() end
    if pending.badges and self.RefreshBadges then self:RefreshBadges() end
    if pending.chrome and self.RefreshWhisperChrome then self:RefreshWhisperChrome() end
    for id in pairs(pending.popouts or {}) do
        local popout = self.popouts and self.popouts[id]
        if popout then self:RefreshPopoutFor(popout.channel, popout.target) end
    end
    if pending.combat and self.RefreshCombatPanel then self:RefreshCombatPanel() end
    if pending.layout and self.ResolveWindowOverlaps then self:ResolveWindowOverlaps() end
end

local originalRefreshAll = UI.RefreshAll
UI.OriginalRefreshAll = originalRefreshAll
function UI:RefreshAll(...)
    Quality.refresh.full = Quality.refresh.full + 1
    return originalRefreshAll(self, ...)
end

function UI:RequestVisualApply()
    if Quality.visualApplyQueued then
        Quality.refresh.coalesced = Quality.refresh.coalesced + 1
        return
    end
    Quality.visualApplyQueued = true
    local function applyVisuals()
        Quality.visualApplyQueued = false
        Quality.refresh.visualApplies = Quality.refresh.visualApplies + 1
        if UI.ApplyVisualSettings then UI:ApplyVisualSettings() end
    end
    if C_Timer and C_Timer.After then C_Timer.After(0.04, applyVisuals) else applyVisuals() end
end

-- Message events now update only the surfaces that can actually have changed.
function UI:OnNewMessage(channel, target, message, shouldAlert)
    if not message then return end
    if channel == "WHISPER" then
        target = CC:ResolveWhisperConversation(target or message.target or message.sender)
        message.target = target
    elseif channel == "QUEST" then
        target = target or message.target
        message.target = target
        if self.mode == "QUEST" and self.main and self.main:IsShown() then
            self.currentQuestTarget = target
        elseif not self.currentQuestTarget then
            self.currentQuestTarget = target
        end
    end
    if channel == "COMBAT" then
        self:QueueCombatRefresh()
        return
    end

    local incoming = message.incoming and true or false
    local visible = self:IsChannelVisible(channel, target, message)
    if incoming and not visible then
        if channel == "WHISPER" then
            self.unreadByTarget[target] = (self.unreadByTarget[target] or 0) + 1
            CC.state.unreadWhispers = CC.state.unreadWhispers + 1
        elseif channel == "QUEST" then
            self.unreadQuestByTarget[target] = (self.unreadQuestByTarget[target] or 0) + 1
            CC.state.unreadQuests = (CC.state.unreadQuests or 0) + 1
        elseif channel == "GUILD" then
            CC.state.unreadGuild = CC.state.unreadGuild + 1
        elseif channel == "GENERAL" and self:ShouldCountGeneralBadge(message) then
            CC.state.unreadGeneral = CC.state.unreadGeneral + 1
        end
    end

    if incoming and not visible then
        if channel == "WHISPER" then
            self:NotifyLauncher("WHISPER", target)
        elseif channel == "QUEST" then
            self:NotifyLauncher("QUEST", target)
        elseif channel == "GUILD" then
            self:NotifyLauncher("GUILD")
        elseif channel == "GENERAL" and self:ShouldCountGeneralBadge(message) then
            local chatType = tostring(message.chatType or "")
            if chatType == "CHAT_MSG_PARTY" or chatType == "CHAT_MSG_PARTY_LEADER" then
                self:NotifyLauncher("PARTY_MESSAGE")
            else
                self:NotifyLauncher("GENERAL")
            end
        end
    end

    if incoming and channel == "WHISPER" and not visible and (not CC.IsNotificationEnabled or CC:IsNotificationEnabled("WHISPER")) and (CC.db.ui or {}).showDockWhisperAlert ~= false then
        self:ShowWhisperDockAlert(target, message)
    end
    local configuredCardAlert = shouldAlert and true or false
    if incoming and channel == "GENERAL" then
        local notificationKind = self.GetMessageNotificationKind and self:GetMessageNotificationKind(channel, message) or "GENERAL"
        if notificationKind == "PARTY_MESSAGE" then configuredCardAlert = true
        elseif self.ShouldCountGeneralBadge and self:ShouldCountGeneralBadge(message) then configuredCardAlert = true end
        if configuredCardAlert and notificationKind == "GENERAL" and CC.PlayAlertSound then CC:PlayAlertSound("GENERAL") end
    end
    if incoming and configuredCardAlert then self:ShowToast(channel, target, message) end

    local flags = { badges = true }
    if channel == "WHISPER" or channel == "QUEST" then
        flags.conversations = true
        if channel == "WHISPER" and self.mode == "WHISPER" and self.currentTarget == target then flags.chrome = true end
    end
    if self.main and self.main:IsShown() and (self.mode == channel or (channel == "GENERAL" and self:IsGeneralFeedMode(self.mode))) then
        if channel == "WHISPER" then
            if self.currentTarget == target then flags.main = true end
        elseif channel == "QUEST" then
            if self.currentQuestTarget == target then flags.main = true end
        elseif channel == "GENERAL" then
            if self.mode == "GENERAL" or CC:ChannelColorKey(message) == self.mode then flags.main = true end
        else
            flags.main = true
        end
    end
    local id = popoutID(channel, target)
    if id and self.popouts and self.popouts[id] and self.popouts[id]:IsShown() then flags.popout = id end
    if channel == "GENERAL" then
        local filteredID = CC:ChannelColorKey(message)
        if self.popouts and self.popouts[filteredID] and self.popouts[filteredID]:IsShown() then
            flags.popouts = flags.popouts or {}
            flags.popouts[filteredID] = true
        end
    end
    self:RequestRefresh(flags)
end

function Quality:GetHealthLines()
    local state = CC.state or {}
    local refresh = self.refresh
    local sourceCounts = state.chatSourceCounts or {}
    local profile = CC.db and CC.db.ui and CC.db.ui.qualityProfile or "BALANCED"
    local shared = CC.EnsureAccountWhisperStorage and CC:EnsureAccountWhisperStorage() or {}
    local captureStatus = state.chatCaptureReady == true and "READY" or (state.chatCaptureReady == false and "FALLBACK" or "CHECKING")
    return {
        "Build " .. tostring(CC.version) .. " · schema " .. tostring(CC.db and CC.db.version or "?") .. " · profile " .. tostring(profile),
        "Chat: " .. tostring(state.liveChatCount or 0) .. " accepted · direct " .. tostring(sourceCounts.DIRECT or 0) .. " · filter " .. tostring(sourceCounts.FILTER or 0) .. " · handler " .. tostring(sourceCounts.MESSAGE_HANDLER or 0) .. " · errors " .. tostring(state.chatErrors or 0),
        "Chat capture: " .. captureStatus .. " · events " .. tostring(state.registeredCoreEvents or state.registeredChatEvents or 0) .. " · filters " .. tostring(state.registeredChatFilters or 0),
        "Social: " .. tostring(countTable(shared.accountFriends)) .. " character friends · " .. tostring(countTable(shared.battleNetFriends)) .. " cached Battle.net identities · " .. tostring(countTable(shared.whispers)) .. " direct conversations",
        "Refresh: " .. tostring(refresh.targeted) .. " targeted · " .. tostring(refresh.flushes) .. " flushes · " .. tostring(refresh.full) .. " full · " .. tostring(refresh.coalesced) .. " coalesced",
        "Windows: " .. tostring(countTable(UI.popouts)) .. " pop-outs · cache " .. tostring(countTable(CC.db and CC.db.playerCache)) .. " player records",
    }
end

function Quality:PrintHealth()
    for _, line in ipairs(self:GetHealthLines()) do CC:Print(line) end
end

local originalHandleSlashCommand = CC.HandleSlashCommand
function CC:HandleSlashCommand(input)
    local command, rest = string.match(tostring(input or ""), "^(%S*)%s*(.-)$")
    command = string.lower(command or "")
    if command == "health" or command == "diagnostics" then
        Quality:PrintHealth()
        return
    elseif command == "chatcheck" or command == "chatrepair" then
        CC.state.chatConsecutiveErrors = 0
        if CC.EnsureChatStorage then CC:EnsureChatStorage() end
        if CC.EnsureChatEventRegistration then CC:EnsureChatEventRegistration() end
        if CC.RegisterChatFilters then CC:RegisterChatFilters() end
        if CC.Friends and CC.Friends.SyncAllRosters then CC.Friends:SyncAllRosters() end
        if CC.ApplyBlizzardChatVisibility then CC:ApplyBlizzardChatVisibility() end
        Quality:PrintHealth()
        if CC.state.lastChatError then CC:Print("Last chat error: " .. tostring(CC.state.lastChatErrorEvent or "unknown") .. " · " .. tostring(CC.state.lastChatError)) end
        if CC.state.lastChatUIError then CC:Print("Last chat UI error: " .. tostring(CC.state.lastChatUIError)) end
        if CC.state.chatFilterUnavailable then
            CC:Print("System message filter: INACTIVE (ChatFrame_AddMessageEventFilter not available on this client)")
            CC:Print("suppressOfflineWhisperErrors cannot hide offline whisper errors in Blizzard chat")
        else
            CC:Print("System message filter: " .. (CC.state.systemMessageFilterRegistered and "active" or "not registered"))
        end
        CC:Print("Chat events, filters, storage and account friends were refreshed.")
        return
    elseif command == "optimise" or command == "optimize" then
        Quality:SanitizeDatabase()
        Quality:PrintHealth()
        CC:Print("Saved data validated and history/cache limits enforced.")
        return
    elseif command == "profile" then
        Quality:ApplyProfile(rest ~= "" and rest or "BALANCED")
        return
    end
    return originalHandleSlashCommand(self, input)
end

local originalShowHelp = CC.ShowHelp
function CC:ShowHelp()
    originalShowHelp(self)
    self:Print("/cc health - show event, refresh and cache diagnostics")
    self:Print("/cc chatcheck - repair chat capture and refresh account friends")
    self:Print("/cc optimise - validate saved settings and enforce safe limits")
    self:Print("/cc profile balanced|minimal|messenger|popout|performance")
end

local qualityFrame = CreateFrame("Frame")
qualityFrame:RegisterEvent("PLAYER_LOGIN")
qualityFrame:SetScript("OnEvent", function()
    Quality:SanitizeDatabase()
end)
