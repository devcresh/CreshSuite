local _, CC = ...
if not CC then
    return
end

local Friends = { version = CC.version }
CC.Friends = Friends
if CC.RegisterModule then CC:RegisterModule("Friends", Friends) end

local lower = string.lower
local sort = table.sort
local tinsert = table.insert
local unpack = _G.unpack or table.unpack

local function safeCall(func, ...)
    if type(func) ~= "function" then return nil end
    local values = { pcall(func, ...) }
    if not values[1] then return nil end
    table.remove(values, 1)
    return unpack(values)
end

local function actionSucceeded(func, ...)
    if type(func) ~= "function" then return false end
    local ok, result = pcall(func, ...)
    return ok and result ~= false
end

local function tryActions(actions, ...)
    for _, func in pairs(actions or {}) do
        if actionSucceeded(func, ...) then return true end
    end
    return false
end

local function trim(value)
    local text = tostring(value or "")
    text = string.gsub(text, "^%s+", "")
    text = string.gsub(text, "%s+$", "")
    return text
end

local function normalise(value)
    return lower(trim(value))
end

local function samePlayerName(a, b)
    a = CC.CleanPlayerName and CC:CleanPlayerName(a) or trim(a)
    b = CC.CleanPlayerName and CC:CleanPlayerName(b) or trim(b)
    if a == "" or b == "" then return false end
    if lower(a) == lower(b) then return true end
    local shortA = CC.ShortName and CC:ShortName(a) or string.match(a, "^[^-]+") or a
    local shortB = CC.ShortName and CC:ShortName(b) or string.match(b, "^[^-]+") or b
    return lower(shortA) == lower(shortB)
end

local function apiFlag(value)
    return value == true or value == 1
end

local function classFileFromName(className)
    className = trim(className)
    if className == "" then return nil end
    local wanted = lower(className)
    for classFile, localized in pairs(_G.LOCALIZED_CLASS_NAMES_MALE or {}) do
        if lower(tostring(localized or "")) == wanted then return classFile end
    end
    for classFile, localized in pairs(_G.LOCALIZED_CLASS_NAMES_FEMALE or {}) do
        if lower(tostring(localized or "")) == wanted then return classFile end
    end
    local compact = string.upper(string.gsub(className, "%s+", ""))
    if _G.CLASS_ICON_TCOORDS and _G.CLASS_ICON_TCOORDS[compact] then return compact end
    return nil
end

local function readModernFriend(index)
    if not (_G.C_FriendList and type(_G.C_FriendList.GetFriendInfoByIndex) == "function") then
        return nil
    end
    local a, b, c, d, e, f, g, h = safeCall(_G.C_FriendList.GetFriendInfoByIndex, index)
    if type(a) == "table" then
        return {
            name = a.name,
            level = a.level,
            className = a.className or a.class,
            classFile = a.classFilename or a.classFile,
            area = a.area,
            connected = apiFlag(a.connected) or apiFlag(a.isOnline),
            status = a.status or (apiFlag(a.dnd) and "DND" or (apiFlag(a.afk) and "AFK" or nil)),
            note = a.notes or a.note,
            guid = a.guid,
        }
    end
    if a ~= nil then
        return {
            name = a,
            level = b,
            className = c,
            area = d,
            connected = apiFlag(e),
            status = f,
            note = g,
            guid = h,
        }
    end
    return nil
end

local function readLegacyFriend(index)
    if type(_G.GetFriendInfo) ~= "function" then return nil end
    local name, level, className, area, connected, status, note, guid = safeCall(_G.GetFriendInfo, index)
    if not name then return nil end
    return {
        name = name,
        level = level,
        className = className,
        area = area,
        connected = apiFlag(connected),
        status = status,
        note = note,
        guid = guid,
    }
end

local function readModernBattleNetFriend(index)
    if not (_G.C_BattleNet and type(_G.C_BattleNet.GetFriendAccountInfo) == "function") then return nil end
    local info = safeCall(_G.C_BattleNet.GetFriendAccountInfo, index)
    if type(info) ~= "table" then return nil end
    return info
end

local function readLegacyBattleNetFriend(index)
    if type(_G.BNGetFriendInfo) ~= "function" then return nil end
    local values = { pcall(_G.BNGetFriendInfo, index) }
    if not values[1] then return nil end
    table.remove(values, 1)
    if values[1] == nil then return nil end
    -- Legacy BNGetFriendInfo returns an isBattleTagPresence flag before
    -- the active game-account fields. Keep the indices aligned with the
    -- TBC-era API so offline state, toon name and client are not shifted.
    return {
        bnetAccountID = tonumber(values[1]),
        accountName = values[2],
        battleTag = values[3],
        isBattleTagPresence = apiFlag(values[4]),
        gameAccountInfo = {
            characterName = values[5],
            gameAccountID = values[6],
            clientProgram = values[7],
            isOnline = apiFlag(values[8]),
        },
        isOnline = apiFlag(values[8]),
        lastOnlineTime = values[9],
        isAFK = apiFlag(values[10]),
        isDND = apiFlag(values[11]),
        customMessage = values[12],
        note = values[13],
    }
end

local function readPlayerFriend(index)
    local modern = readModernFriend(index)
    if modern and trim(modern.name) ~= "" then return modern end
    return readLegacyFriend(index)
end

local function readBattleNetFriend(index)
    local modern = readModernBattleNetFriend(index)
    if type(modern) == "table" then
        local id = tonumber(modern.bnetAccountID or modern.presenceID)
        if id or trim(modern.accountName) ~= "" or trim(modern.battleTag) ~= "" then return modern end
    end
    return readLegacyBattleNetFriend(index)
end

local function battleNetFriendCount()
    local legacy, modern = 0, 0
    if type(_G.BNGetNumFriends) == "function" then legacy = tonumber((safeCall(_G.BNGetNumFriends))) or 0 end
    if _G.C_BattleNet and type(_G.C_BattleNet.GetFriendNum) == "function" then
        modern = tonumber((safeCall(_G.C_BattleNet.GetFriendNum))) or 0
    end
    return math.max(legacy, modern)
end

local function playerFriendCount()
    local legacy, modern = 0, 0
    if type(_G.GetNumFriends) == "function" then legacy = tonumber((safeCall(_G.GetNumFriends))) or 0 end
    if _G.C_FriendList and type(_G.C_FriendList.GetNumFriends) == "function" then
        modern = tonumber((safeCall(_G.C_FriendList.GetNumFriends))) or 0
    end
    return math.max(legacy, modern)
end

local function battleNetDisplayName(info)
    if type(info) ~= "table" then return "Battle.net Friend" end
    local accountName = trim(info.accountName)
    local battleTag = trim(info.battleTag)
    local game = type(info.gameAccountInfo) == "table" and info.gameAccountInfo or {}
    local characterName = trim(game.characterName or game.name)
    if accountName ~= "" then return accountName end
    if battleTag ~= "" then return battleTag end
    if characterName ~= "" then return characterName end
    return "Battle.net Friend"
end

local function burningCrusadeProjectID()
    -- Anniversary clients report their own active project through WOW_PROJECT_ID.
    -- Prefer that live value over the historical constant because Blizzard has
    -- used different project identifiers across Classic branches and patches.
    return tonumber(_G.WOW_PROJECT_ID) or tonumber(_G.WOW_PROJECT_BURNING_CRUSADE_CLASSIC) or 5
end

local function isWoWClient(client)
    client = lower(trim(client))
    return client == "wow"
end

local function gameProjectID(game)
    if type(game) ~= "table" then return nil end
    return tonumber(game.wowProjectID or game.wowProjectId or game.projectID or game.projectId)
end

local function isTBCClientBuild()
    local active = tonumber(_G.WOW_PROJECT_ID)
    local historical = tonumber(_G.WOW_PROJECT_BURNING_CRUSADE_CLASSIC)
    if active and historical and active == historical then return true end
    local interfaceVersion = 0
    if type(_G.GetBuildInfo) == "function" then
        local _, _, _, reportedInterface = safeCall(_G.GetBuildInfo)
        interfaceVersion = tonumber(reportedInterface) or 0
    end
    return interfaceVersion >= 20000 and interfaceVersion < 30000
end

local function isTBCGameAccount(game, allowLegacyFallback)
    if type(game) ~= "table" or not isWoWClient(game.clientProgram) then return false end
    local projectID = gameProjectID(game)
    if projectID then return projectID == burningCrusadeProjectID() end

    -- TBC Anniversary's legacy Battle.net game-account tuple often omits a
    -- project ID even while the friend is online. When this addon is itself
    -- running on a 2.x/TBC client, a WoW game account from that legacy route is
    -- the best available same-client signal. Modern records with a project ID
    -- remain strictly filtered, so Retail and other Classic projects stay out.
    return allowLegacyFallback == true and isTBCClientBuild()
end

local function readLegacyBattleNetGameAccount(friendIndex, accountIndex)
    if type(_G.BNGetFriendGameAccountInfo) ~= "function" then return nil end
    local values = { pcall(_G.BNGetFriendGameAccountInfo, friendIndex, accountIndex) }
    if not values[1] then return nil end
    table.remove(values, 1)
    if values[1] == nil then return nil end
    -- TBC/Classic legacy tuple:
    -- hasFocus, characterName, client, realmName, realmID, faction, race,
    -- class, guild, zoneName, level, gameText, broadcastText, broadcastTime,
    -- canSoR, gameAccountID, ...optional modern tail fields.
    local hasFocus = apiFlag(values[1])
    local characterName = values[2]
    local client = values[3]
    return {
        hasFocus = hasFocus,
        characterName = characterName,
        gameAccountName = characterName,
        clientProgram = client,
        realmName = values[4],
        realmID = values[5],
        factionName = values[6],
        raceName = values[7],
        className = values[8],
        guildName = values[9],
        areaName = values[10],
        characterLevel = values[11],
        richPresence = values[12] or values[13],
        canSoR = apiFlag(values[15]),
        gameAccountID = values[16],
        regionID = values[17],
        isGameAFK = apiFlag(values[18]),
        isGameBusy = apiFlag(values[19]),
        playerGuid = values[20],
        wowProjectID = tonumber(values[21]),
        isOnline = trim(client) ~= "" and trim(characterName) ~= "",
        legacyTuple = true,
    }
end

local function legacyBattleNetGameAccountCount(friendIndex)
    if type(_G.BNGetNumFriendGameAccounts) ~= "function" then return nil end
    return tonumber((safeCall(_G.BNGetNumFriendGameAccounts, friendIndex)))
end

local function getTBCGameAccount(friendIndex, accountInfo)
    local candidates, seen = {}, {}
    local function addCandidate(game, legacy)
        if type(game) ~= "table" then return end
        local key = tostring(game.gameAccountID or game.gameAccountId or game.gameAccountName or game.characterName or #candidates + 1)
        key = key .. ":" .. tostring(gameProjectID(game) or "") .. ":" .. tostring(game.clientProgram or "")
        local existing = seen[key]
        if existing then
            -- Merge modern account focus data with the richer TBC legacy tuple.
            -- This preserves project/online state while filling character level,
            -- class, zone and realm that one API family may omit.
            for field, value in pairs(game) do
                if existing[field] == nil or existing[field] == "" then existing[field] = value end
            end
            if legacy then existing.legacyTuple = true end
            return
        end
        if legacy then game.legacyTuple = true end
        seen[key] = game
        candidates[#candidates + 1] = game
    end

    addCandidate(type(accountInfo) == "table" and accountInfo.gameAccountInfo or nil, false)
    local battleNet = _G.C_BattleNet
    local modernCount
    if battleNet and type(battleNet.GetFriendNumGameAccounts) == "function" then
        modernCount = tonumber((safeCall(battleNet.GetFriendNumGameAccounts, friendIndex)))
    end
    local legacyCount = legacyBattleNetGameAccountCount(friendIndex)
    local count = math.max(tonumber(modernCount) or 0, tonumber(legacyCount) or 0)

    if count > 0 then
        for accountIndex = 1, math.min(count, 20) do
            if battleNet and type(battleNet.GetFriendGameAccountInfo) == "function" then
                addCandidate(safeCall(battleNet.GetFriendGameAccountInfo, friendIndex, accountIndex), false)
            end
            addCandidate(readLegacyBattleNetGameAccount(friendIndex, accountIndex), true)
        end
    else
        -- Some Classic branches expose one or both getters without a count API.
        -- Probe a small bounded range and combine both routes instead of trusting
        -- whichever API family happened to return first.
        for accountIndex = 1, 10 do
            local modernGame = battleNet and type(battleNet.GetFriendGameAccountInfo) == "function"
                and safeCall(battleNet.GetFriendGameAccountInfo, friendIndex, accountIndex) or nil
            local legacyGame = readLegacyBattleNetGameAccount(friendIndex, accountIndex)
            if type(modernGame) ~= "table" and type(legacyGame) ~= "table" then
                if accountIndex > 1 then break end
            else
                addCandidate(modernGame, false)
                addCandidate(legacyGame, true)
            end
        end
    end

    local accountOnline = type(accountInfo) == "table" and apiFlag(accountInfo.isOnline)
    local offlineMatch, explicitIdentity = nil, {}
    local function identity(game)
        local id = game.gameAccountID or game.gameAccountId
        if id ~= nil then return "id:" .. tostring(id) end
        return normalise(tostring(game.characterName or game.gameAccountName or "") .. "-" .. tostring(game.realmName or ""))
    end

    -- Prefer explicit project IDs first. A projectless modern record is often a
    -- duplicate of a richer legacy record; it must not bypass an explicit Retail
    -- or other-Classic project ID for the same game account.
    for _, game in ipairs(candidates) do
        if gameProjectID(game) then
            explicitIdentity[identity(game)] = true
            if isTBCGameAccount(game, false) then
                local online = apiFlag(game.isOnline) or (accountOnline and isWoWClient(game.clientProgram))
                if online then return game, true end
                offlineMatch = offlineMatch or game
            end
        end
    end
    if offlineMatch then return offlineMatch, false end

    for _, game in ipairs(candidates) do
        if not gameProjectID(game) and not explicitIdentity[identity(game)] and isTBCGameAccount(game, true) then
            local online = apiFlag(game.isOnline) or (accountOnline and isWoWClient(game.clientProgram))
            if online then return game, true end
            offlineMatch = offlineMatch or game
        end
    end
    return offlineMatch, false
end

function Friends:SyncPlayerFriends()
    if not CC.db then return {} end
    local total = playerFriendCount()

    local liveByKey = {}
    for index = 1, total do
        local info = readPlayerFriend(index)
        local name = info and CC:CleanPlayerName(info.name) or ""
        local key = normalise(name)
        if name ~= "" and key ~= "" then
            info.name = name
            info.classFile = info.classFile or classFileFromName(info.className)
            local remembered, savedKey
            if CC.RememberAccountFriend then
                remembered, savedKey = CC:RememberAccountFriend(name, {
                    source = "BLIZZARD_ROSTER", lastSeen = time and time() or 0,
                    profileKey = CC.GetCurrentCharacterProfileKey and CC:GetCurrentCharacterProfileKey() or nil,
                    level = info.level, className = info.className, classFile = info.classFile,
                    area = info.area, note = info.note, guid = info.guid,
                })
            end
            -- The live Blizzard roster always wins. Cache/removal bookkeeping must
            -- never hide a player who is still an actual in-game friend.
            liveByKey[savedKey or key] = info
        end
    end
    self.lastPlayerFriendSync = time and time() or 0
    self.lastPlayerFriendCount = total
    return liveByKey
end

function Friends:GetPlayerFriends()
    -- Use Blizzard's current character-friend roster as the sole source of truth.
    -- Account cache entries can contain manually remembered whisper contacts from
    -- earlier builds, so they are never promoted into the Friends tab here.
    local liveByKey = self:SyncPlayerFriends()
    local output = {}
    for _, info in pairs(liveByKey) do
        local name = CC:CleanPlayerName(info.name)
        if name ~= "" then
            info.name = name
            info.classFile = info.classFile or classFileFromName(info.className)
            info.kind = "PLAYER"
            info.target = name
            info.accountSaved = true
            info.online = info.connected == true

            local linked = CC.GetLinkedBattleNetConversation and CC:GetLinkedBattleNetConversation(name) or nil
            local bnetRecord = linked and CC.GetBattleNetCharacterRecord and CC:GetBattleNetCharacterRecord(linked) or nil
            local activeTarget = bnetRecord and CC:CleanPlayerName(bnetRecord.activeTarget) or ""
            if linked and activeTarget ~= "" then
                info.linkedBattleNetTarget = linked
                info.activeAltTarget = activeTarget
                info.onlineViaBattleNet = not info.online and true or nil
                if string.lower(CC:ShortName(activeTarget)) ~= string.lower(CC:ShortName(name)) then
                    info.altLoggedIn = true
                    info.altName = activeTarget
                end
                if CC.SetBattleNetPrimaryCharacter then CC:SetBattleNetPrimaryCharacter(linked, name, false) end
            end
            info.section = info.online and "GAME FRIENDS ONLINE" or "GAME FRIENDS OFFLINE"
            info.sectionRank = info.online and 2 or 4
            tinsert(output, info)
        end
    end

    sort(output, function(a, b)
        if a.sectionRank ~= b.sectionRank then return a.sectionRank < b.sectionRank end
        return lower(CC:ShortName(a.name)) < lower(CC:ShortName(b.name))
    end)
    if #output > 0 or playerFriendCount() > 0 then self.playerRoster = output
    elseif type(self.playerRoster) == "table" then return self.playerRoster end
    return output
end

local function buildPlayerFriendLookup(liveByKey)
    local lookup = {}
    for key, info in pairs(liveByKey or {}) do
        lookup[key] = true
        local name = info and CC:CleanPlayerName(info.name) or ""
        if name ~= "" then
            lookup[normalise(name)] = true
            lookup[normalise(CC:ShortName(name))] = true
        end
    end
    return lookup
end

function Friends:GetBattleNetFriends()
    local output = {}
    local seen = {}
    local totalFriends = battleNetFriendCount()
    if totalFriends <= 0 and type(self.battleNetRoster) == "table" and #self.battleNetRoster > 0 then
        -- Battle.net can report zero briefly during login/reconnect. Keep the
        -- last roster from this session instead of making the Friends tab empty.
        return self.battleNetRoster
    end
    local projectID = burningCrusadeProjectID()
    local shared = CC.EnsureAccountWhisperStorage and CC:EnsureAccountWhisperStorage() or { battleNetFriends = {} }
    shared.battleNetFriends = type(shared.battleNetFriends) == "table" and shared.battleNetFriends or {}
    local playerFriendLookup = buildPlayerFriendLookup(self:SyncPlayerFriends())

    for index = 1, totalFriends do
        local info = readBattleNetFriend(index)
        if info then
            local accountID = tonumber(info.bnetAccountID or info.presenceID)
            local displayName = battleNetDisplayName(info)
            -- Register every live account route so existing Battle.net conversations
            -- keep working, but only expose verified TBC Anniversary accounts below.
            local target = CC.RegisterBattleNetAccount and CC:RegisterBattleNetAccount(accountID, info, displayName) or nil
            local game, tbcOnline = getTBCGameAccount(index, info)
            local cached = target and shared.battleNetFriends[target] or nil
            local knownTBC = type(game) == "table"
                or (type(cached) == "table" and (cached.tbcAnniversary == true or tonumber(cached.wowProjectID) == projectID))

            if knownTBC then
                game = type(game) == "table" and game or {}
                local dedupeKey = target or (accountID and ("id:" .. tostring(accountID))) or normalise(displayName)
                if dedupeKey ~= "" and not seen[dedupeKey] then
                    seen[dedupeKey] = true
                    if target then seen[target] = true end
                    local client = trim(game.clientProgram or "WoW")
                    local online = tbcOnline == true
                    local characterName = CC:CleanPlayerName(game.characterName or game.name or "")
                    local realmName = trim(game.realmName or game.realmDisplayName)
                    local gameTarget = online and characterName or ""
                    if gameTarget ~= "" and realmName ~= "" and not string.find(gameTarget, "-", 1, true) then
                        gameTarget = gameTarget .. "-" .. string.gsub(realmName, "%s+", "")
                    end
                    local gameFriendKey = normalise(gameTarget)
                    local shortGameFriendKey = normalise(CC:ShortName(gameTarget))
                    local isGameFriend = gameTarget ~= "" and (playerFriendLookup[gameFriendKey] == true or playerFriendLookup[shortGameFriendKey] == true)
                    local characterRecord
                    if CC.UpdateBattleNetCharacterPresence then
                        characterRecord = CC:UpdateBattleNetCharacterPresence(target, gameTarget, displayName, online)
                    end
                    local primaryCharacter = characterRecord and CC:CleanPlayerName(characterRecord.primaryTarget) or (cached and CC:CleanPlayerName(cached.primaryCharacter) or "")
                    local isKnownAlt = online and gameTarget ~= "" and primaryCharacter ~= "" and string.lower(CC:ShortName(primaryCharacter)) ~= string.lower(CC:ShortName(gameTarget))
                    local item = {
                        kind = "BATTLENET",
                        target = target,
                        name = displayName,
                        battleTag = info.battleTag,
                        bnetAccountID = accountID,
                        online = online,
                        inWoW = online,
                        inTBCAnniversary = true,
                        wowProjectID = projectID,
                        clientProgram = client,
                        gameAccountName = gameTarget ~= "" and gameTarget or nil,
                        gameTarget = gameTarget ~= "" and gameTarget or nil,
                        linkedBattleNetTarget = target,
                        activeCharacter = online and gameTarget or nil,
                        altLoggedIn = isKnownAlt,
                        altName = isKnownAlt and gameTarget or nil,
                        primaryCharacter = primaryCharacter ~= "" and primaryCharacter or nil,
                        isGameFriend = isGameFriend,
                        addTarget = online and not isGameFriend and gameTarget ~= "" and gameTarget or nil,
                        level = tonumber(game.characterLevel or game.level) or (cached and cached.level),
                        className = game.className or game.class or (cached and cached.className),
                        classFile = game.classFilename or game.classFile or classFileFromName(game.className or game.class) or (cached and cached.classFile),
                        area = game.areaName or game.richPresence or (cached and cached.area),
                        richPresence = game.richPresence,
                        status = apiFlag(info.isDND) and "DND" or (apiFlag(info.isAFK) and "AFK" or nil),
                        note = info.note,
                        section = online and "BATTLE.NET ONLINE" or "BATTLE.NET OFFLINE",
                        sectionRank = online and 1 or 3,
                    }
                    tinsert(output, item)
                    if target then
                        shared.battleNetFriends[target] = {
                            target = target, name = displayName, battleTag = info.battleTag,
                            lastBnetAccountID = accountID, lastSeen = time and time() or 0,
                            wowProjectID = projectID, tbcAnniversary = true,
                            primaryCharacter = primaryCharacter ~= "" and primaryCharacter or nil,
                            lastCharacter = gameTarget ~= "" and gameTarget or (cached and cached.lastCharacter),
                            className = item.className, classFile = item.classFile, level = item.level, area = item.area,
                        }
                    end
                end
            end
        end
    end

    -- Do not append cache-only Battle.net records. Cached project/class data may
    -- enrich an account that is still present in Blizzard's live friend roster,
    -- but a removed or stale account must never remain visible as an offline friend.

    sort(output, function(a, b)
        if a.sectionRank ~= b.sectionRank then return a.sectionRank < b.sectionRank end
        return lower(tostring(a.name or "")) < lower(tostring(b.name or ""))
    end)
    self.lastBattleNetSync = time and time() or 0
    self.battleNetRoster = output
    return output
end

function Friends:GetCurrentZoneQuestGivers()
    local output = {}
    if not CC.db then return output end
    if CC.EnsureQuestStorage then CC:EnsureQuestStorage() end

    local currentZone = CC.GetQuestZoneName and CC:GetQuestZoneName() or "Unknown Zone"
    local wantedZone = normalise(currentZone)
    for key, meta in pairs(CC.db.questConversations or {}) do
        local messages = CC.db.history and CC.db.history.quests and CC.db.history.quests[key]
        local zone = trim(meta.zone)
        if messages and #messages > 0 and normalise(zone) == wantedZone then
            tinsert(output, {
                kind = "QUEST",
                target = key,
                name = trim(meta.npcName) ~= "" and trim(meta.npcName) or "Quest Giver",
                zone = zone ~= "" and zone or currentZone,
                online = true,
                section = "QUEST GIVERS",
                sectionRank = 3,
                updated = tonumber(meta.updated) or 0,
                hidden = meta.hidden == true,
            })
        end
    end

    sort(output, function(a, b)
        if a.updated ~= b.updated then return a.updated > b.updated end
        return lower(a.name) < lower(b.name)
    end)
    return output
end

function Friends:GetPreviousWhispers(friendRoster)
    local output, friendTargets = {}, {}
    for _, item in ipairs(friendRoster or {}) do
        local target = item.target or item.gameTarget or item.activeAltTarget or item.name
        if target and target ~= "" then
            friendTargets[normalise(target)] = true
            friendTargets[normalise(CC:ShortName(target))] = true
        end
        if item.gameTarget and item.gameTarget ~= "" then
            friendTargets[normalise(item.gameTarget)] = true
            friendTargets[normalise(CC:ShortName(item.gameTarget))] = true
        end
        if item.activeCharacter and item.activeCharacter ~= "" then
            friendTargets[normalise(item.activeCharacter)] = true
            friendTargets[normalise(CC:ShortName(item.activeCharacter))] = true
        end
    end

    for target, messages in pairs((CC.db and CC.db.history and CC.db.history.whispers) or {}) do
        local resolved = CC.ResolveWhisperConversation and CC:ResolveWhisperConversation(target) or target
        local displayName = CC.GetWhisperDisplayName and CC:GetWhisperDisplayName(resolved) or CC:ShortName(resolved)
        local route = CC.GetWhisperRoute and CC:GetWhisperRoute(resolved) or resolved
        local isFriend = friendTargets[normalise(resolved)] or friendTargets[normalise(route)]
            or friendTargets[normalise(displayName)] or friendTargets[normalise(CC:ShortName(route))]
        if not isFriend and type(messages) == "table" and #messages > 0 then
            local last = messages[#messages] or {}
            local isBattleNet = CC.IsBattleNetConversation and CC:IsBattleNetConversation(resolved)
            local record = isBattleNet and CC.GetBattleNetCharacterRecord and CC:GetBattleNetCharacterRecord(resolved) or nil
            local activeTarget = record and CC:CleanPlayerName(record.activeTarget) or ""
            local shared = isBattleNet and CC.EnsureAccountWhisperStorage and CC:EnsureAccountWhisperStorage() or nil
            local cachedBNet = shared and shared.battleNetFriends and shared.battleNetFriends[resolved] or nil
            tinsert(output, {
                kind = "PREVIOUS_WHISPER",
                target = resolved,
                name = displayName,
                online = activeTarget ~= "",
                activeCharacter = activeTarget ~= "" and activeTarget or nil,
                gameTarget = activeTarget ~= "" and activeTarget or (not isBattleNet and route or nil),
                isBattleNetPrevious = isBattleNet and true or nil,
                battleTag = cachedBNet and cachedBNet.battleTag or nil,
                addTarget = cachedBNet and cachedBNet.battleTag or nil,
                classFile = last.classFile,
                guid = last.guid,
                section = "PREVIOUS WHISPERS",
                sectionRank = 5,
                updated = tonumber((CC.db.conversations or {})[resolved]) or tonumber(last.timestamp) or 0,
            })
        end
    end
    sort(output, function(a, b)
        if (a.updated or 0) ~= (b.updated or 0) then return (a.updated or 0) > (b.updated or 0) end
        return lower(tostring(a.name or "")) < lower(tostring(b.name or ""))
    end)
    return output
end

function Friends:GetRoster()
    -- The Friends tab is deliberately limited to Blizzard's real friend rosters.
    -- Guild members, nearby players and previous-whisper-only contacts belong in
    -- their own tabs and must never be promoted into Friends merely because they
    -- have been seen or messaged before.
    local roster = {}
    local okBattleNet, battleNet = pcall(self.GetBattleNetFriends, self)
    if okBattleNet and type(battleNet) == "table" then
        for _, item in ipairs(battleNet) do
            if item.kind == "BATTLENET" then tinsert(roster, item) end
        end
    end
    local okPlayers, players = pcall(self.GetPlayerFriends, self)
    if okPlayers and type(players) == "table" then
        for _, item in ipairs(players) do
            if item.kind == "PLAYER" then tinsert(roster, item) end
        end
    end
    sort(roster, function(a, b)
        if (tonumber(a.sectionRank) or 99) ~= (tonumber(b.sectionRank) or 99) then
            return (tonumber(a.sectionRank) or 99) < (tonumber(b.sectionRank) or 99)
        end
        return lower(tostring(a.name or "")) < lower(tostring(b.name or ""))
    end)
    return roster
end

function Friends:RequestGuildRoster(force)
    if type(_G.IsInGuild) == "function" and not _G.IsInGuild() then return false end
    local now = time and time() or 0
    if not force and self.lastGuildRequest and now - self.lastGuildRequest < 10 then return false end
    self.lastGuildRequest = now
    if _G.C_GuildInfo and type(_G.C_GuildInfo.GuildRoster) == "function" then
        pcall(_G.C_GuildInfo.GuildRoster)
        return true
    end
    if type(_G.GuildRoster) == "function" then
        pcall(_G.GuildRoster)
        return true
    end
    return false
end

function Friends:GetGuildRoster()
    local output = {}
    self:RequestGuildRoster()
    if type(_G.GetNumGuildMembers) ~= "function" or type(_G.GetGuildRosterInfo) ~= "function" then return output end
    local total = tonumber((safeCall(_G.GetNumGuildMembers))) or 0
    if total <= 0 and type(_G.IsInGuild) == "function" and _G.IsInGuild() then
        self:RequestGuildRoster(true)
        if type(self.guildRoster) == "table" and #self.guildRoster > 0 then return self.guildRoster end
    end
    for index = 1, math.min(total, 1000) do
        local name, rankName, rankIndex, level, className, zone, note, officerNote, online, status, classFile, _, _, mobile, _, _, guid = safeCall(_G.GetGuildRosterInfo, index)
        name = CC:CleanPlayerName(name)
        if name ~= "" then
            online = apiFlag(online) or apiFlag(mobile)
            tinsert(output, {
                kind = "GUILD_MEMBER", target = name, name = CC:ShortName(name), fullName = name,
                online = online, mobile = apiFlag(mobile), level = tonumber(level),
                className = className, classFile = classFile or classFileFromName(className),
                area = zone, note = note, officerNote = officerNote, rankName = rankName,
                rankIndex = rankIndex, status = status, guid = guid,
                section = online and "ONLINE" or "OFFLINE", sectionRank = online and 1 or 2,
            })
        end
    end
    sort(output, function(a, b)
        if a.sectionRank ~= b.sectionRank then return a.sectionRank < b.sectionRank end
        if tonumber(a.rankIndex) ~= tonumber(b.rankIndex) then return (tonumber(a.rankIndex) or 99) < (tonumber(b.rankIndex) or 99) end
        return lower(tostring(a.name or "")) < lower(tostring(b.name or ""))
    end)
    self.guildRoster = output
    return output
end

local function fullUnitName(unit)
    if type(_G.GetUnitName) == "function" then
        local value = safeCall(_G.GetUnitName, unit, true)
        if trim(value) ~= "" then return CC:CleanPlayerName(value) end
    end
    if type(_G.UnitFullName) == "function" then
        local name, realm = safeCall(_G.UnitFullName, unit)
        name, realm = trim(name), trim(realm)
        if name ~= "" then
            if realm ~= "" and not string.find(name, "-", 1, true) then
                name = name .. "-" .. string.gsub(realm, "%s+", "")
            end
            return CC:CleanPlayerName(name)
        end
    end
    if type(_G.UnitName) == "function" then
        return CC:CleanPlayerName(safeCall(_G.UnitName, unit))
    end
    return ""
end

local function unitRosterItem(unit, kind)
    if type(_G.UnitExists) == "function" and not safeCall(_G.UnitExists, unit) then return nil end
    local name = fullUnitName(unit)
    if name == "" then return nil end
    local className, classFile
    if type(_G.UnitClass) == "function" then className, classFile = safeCall(_G.UnitClass, unit) end
    local connected = true
    if type(_G.UnitIsConnected) == "function" then connected = safeCall(_G.UnitIsConnected, unit) ~= false end
    local leader = type(_G.UnitIsGroupLeader) == "function" and apiFlag(safeCall(_G.UnitIsGroupLeader, unit)) or false
    local assistant = type(_G.UnitIsGroupAssistant) == "function" and apiFlag(safeCall(_G.UnitIsGroupAssistant, unit)) or false
    local role = type(_G.UnitGroupRolesAssigned) == "function" and trim(safeCall(_G.UnitGroupRolesAssigned, unit)) or ""
    local subgroup
    if kind == "RAID_MEMBER" and type(_G.GetRaidRosterInfo) == "function" then
        local raidIndex = tonumber(string.match(unit, "^raid(%d+)$"))
        if raidIndex then
            local _, _, group = safeCall(_G.GetRaidRosterInfo, raidIndex)
            subgroup = tonumber(group)
        end
    end
    return {
        kind = kind,
        target = name,
        name = CC:ShortName(name),
        fullName = name,
        online = connected,
        className = className,
        classFile = classFile or classFileFromName(className),
        level = type(_G.UnitLevel) == "function" and tonumber(safeCall(_G.UnitLevel, unit)) or nil,
        guid = type(_G.UnitGUID) == "function" and safeCall(_G.UnitGUID, unit) or nil,
        leader = leader,
        assistant = assistant,
        role = role ~= "NONE" and role or nil,
        subgroup = subgroup,
        selfPlayer = unit == "player",
        unit = unit,
        section = connected and "ONLINE" or "OFFLINE",
        sectionRank = connected and 1 or 2,
    }
end

local function sortGroupRoster(output)
    sort(output, function(a, b)
        if a.sectionRank ~= b.sectionRank then return a.sectionRank < b.sectionRank end
        if a.selfPlayer ~= b.selfPlayer then return a.selfPlayer == true end
        if a.leader ~= b.leader then return a.leader == true end
        if (tonumber(a.subgroup) or 99) ~= (tonumber(b.subgroup) or 99) then
            return (tonumber(a.subgroup) or 99) < (tonumber(b.subgroup) or 99)
        end
        return lower(tostring(a.name or "")) < lower(tostring(b.name or ""))
    end)
    return output
end

function Friends:GetPartyRoster()
    local output = {}
    -- The Party tab must never fall back to nearby /who results or raid members.
    -- While in a raid it deliberately remains empty because raid members belong
    -- in the Raid tab, not the Party tab.
    if type(_G.IsInRaid) == "function" and safeCall(_G.IsInRaid) then return output end
    local count = 0
    if type(_G.GetNumSubgroupMembers) == "function" then
        count = tonumber(safeCall(_G.GetNumSubgroupMembers)) or 0
    elseif type(_G.GetNumPartyMembers) == "function" then
        count = tonumber(safeCall(_G.GetNumPartyMembers)) or 0
    end
    if count <= 0 then return output end

    local player = unitRosterItem("player", "PARTY_MEMBER")
    if player then tinsert(output, player) end
    for index = 1, math.min(count, 4) do
        local item = unitRosterItem("party" .. index, "PARTY_MEMBER")
        if item then tinsert(output, item) end
    end
    return sortGroupRoster(output)
end

function Friends:GetRaidRoster()
    local output = {}
    local inRaid = type(_G.IsInRaid) == "function" and safeCall(_G.IsInRaid)
    if not inRaid then return output end
    local count = 0
    if type(_G.GetNumGroupMembers) == "function" then
        count = tonumber(safeCall(_G.GetNumGroupMembers)) or 0
    elseif type(_G.GetNumRaidMembers) == "function" then
        count = tonumber(safeCall(_G.GetNumRaidMembers)) or 0
    end
    for index = 1, math.min(count, 40) do
        local item = unitRosterItem("raid" .. index, "RAID_MEMBER")
        if item then tinsert(output, item) end
    end
    return sortGroupRoster(output)
end

function Friends:GetInstanceRoster()
    if type(_G.IsInRaid) == "function" and safeCall(_G.IsInRaid) then
        return self:GetRaidRoster()
    end
    return self:GetPartyRoster()
end

local function currentZoneName()
    local zone = type(_G.GetRealZoneText) == "function" and safeCall(_G.GetRealZoneText) or nil
    if not zone or trim(zone) == "" then zone = type(_G.GetZoneText) == "function" and safeCall(_G.GetZoneText) or nil end
    return trim(zone) ~= "" and trim(zone) or "Current Area"
end

function Friends:RequestLocalRoster(force)
    local now = time and time() or 0
    local zone = currentZoneName()
    if not force and self.lastWhoRequest and now - self.lastWhoRequest < 30 and self.pendingWhoZone == zone then return false end
    self.lastWhoRequest, self.pendingWhoZone = now, zone
    -- Route /who results to CreshChat only. Setting this true causes Blizzard's
    -- Friends/Who panel to open when General is selected.
    if _G.C_FriendList and type(_G.C_FriendList.SetWhoToUi) == "function" then pcall(_G.C_FriendList.SetWhoToUi, false) end
    if type(_G.SetWhoToUI) == "function" then pcall(_G.SetWhoToUI, 0) end
    local query = 'z-"' .. string.gsub(zone, '"', '') .. '"'
    if _G.C_FriendList and type(_G.C_FriendList.SendWho) == "function" then
        local ok = pcall(_G.C_FriendList.SendWho, query)
        if ok then return true end
    end
    if type(_G.SendWho) == "function" then return pcall(_G.SendWho, query) end
    return false
end

local function whoResultCount()
    local legacy, modern = 0, 0
    if type(_G.GetNumWhoResults) == "function" then legacy = tonumber((safeCall(_G.GetNumWhoResults))) or 0 end
    if _G.C_FriendList and type(_G.C_FriendList.GetNumWhoResults) == "function" then modern = tonumber((safeCall(_G.C_FriendList.GetNumWhoResults))) or 0 end
    return math.max(legacy, modern)
end

local function readWhoInfo(index)
    if _G.C_FriendList and type(_G.C_FriendList.GetWhoInfo) == "function" then
        local info = safeCall(_G.C_FriendList.GetWhoInfo, index)
        if type(info) == "table" then
            return { name = info.fullName or info.name, guild = info.fullGuildName or info.guild, level = info.level, race = info.raceStr or info.race, className = info.classStr or info.className, area = info.area, classFile = info.filename or info.classFileName, sex = info.gender }
        end
    end
    if type(_G.GetWhoInfo) == "function" then
        local name, guild, level, race, className, area, classFile, sex = safeCall(_G.GetWhoInfo, index)
        if name then return { name = name, guild = guild, level = level, race = race, className = className, area = area, classFile = classFile, sex = sex } end
    end
    return nil
end

function Friends:CaptureLocalRoster()
    local zone = self.pendingWhoZone or currentZoneName()
    self.localRosterCache = self.localRosterCache or {}
    local previous = self.localRosterCache[zone] or {}
    if not next(previous) and self.localRosterZone == zone then
        for _, old in ipairs(self.localRoster or {}) do
            local key = normalise(old.target or old.name)
            if key ~= "" then previous[key] = old end
        end
    end
    local byKey, output = {}, {}
    for index = 1, whoResultCount() do
        local info = readWhoInfo(index)
        local name = info and CC:CleanPlayerName(info.name) or ""
        if name ~= "" then
            local key = normalise(name)
            local item = {
                kind = "LOCAL_PLAYER", target = name, name = CC:ShortName(name), fullName = name,
                online = true, level = tonumber(info.level), className = info.className,
                classFile = info.classFile or classFileFromName(info.className), area = info.area or zone,
                guild = info.guild, sex = info.sex, section = "ONLINE IN " .. string.upper(zone), sectionRank = 1,
            }
            byKey[key] = item
            tinsert(output, item)
        end
    end
    local playerName = type(_G.UnitName) == "function" and _G.UnitName("player") or nil
    if playerName and not byKey[normalise(playerName)] then
        local className, classFile
        if type(_G.UnitClass) == "function" then className, classFile = _G.UnitClass("player") end
        local item = { kind = "LOCAL_PLAYER", target = playerName, name = CC:ShortName(playerName), fullName = playerName, online = true, level = type(_G.UnitLevel) == "function" and _G.UnitLevel("player") or nil, className = className, classFile = classFile, area = zone, section = "ONLINE IN " .. string.upper(zone), sectionRank = 1, selfPlayer = true }
        byKey[normalise(playerName)] = item; tinsert(output, item)
    end
    for key, old in pairs(previous) do
        if not byKey[key] and type(old) == "table" then
            local copy = {}
            for k, v in pairs(old) do copy[k] = v end
            copy.online = false; copy.section = "OFFLINE / LEFT AREA"; copy.sectionRank = 2
            tinsert(output, copy)
        end
    end
    local cache = {}
    for _, item in ipairs(output) do cache[normalise(item.target or item.name)] = item end
    self.localRosterCache[zone] = cache
    self.localRoster = output
    self.localRosterZone = zone
    sort(output, function(a, b)
        if a.sectionRank ~= b.sectionRank then return a.sectionRank < b.sectionRank end
        return lower(tostring(a.name or "")) < lower(tostring(b.name or ""))
    end)
    return output
end

function Friends:GetLocalRoster()
    local zone = currentZoneName()
    if self.localRosterZone ~= zone then self.localRoster = {}; self:RequestLocalRoster(true) end
    local output = self.localRoster or {}
    if #output == 0 then
        -- Seed the previous/local section from recent public chat while the /who result is pending.
        local seen = {}
        for index = #(((CC.db or {}).history or {}).general or {}), 1, -1 do
            local message = CC.db.history.general[index]
            local sender = message and CC:CleanPlayerName(message.sender) or ""
            local key = normalise(sender)
            if sender ~= "" and sender ~= "System" and not seen[key] and #output < 30 then
                seen[key] = true
                tinsert(output, { kind = "LOCAL_PLAYER", target = sender, name = CC:ShortName(sender), online = false, classFile = message.classFile, guid = message.guid, area = zone, section = "OFFLINE / LEFT AREA", sectionRank = 2, recent = true })
            end
        end
        self.localRoster = output
    end
    return output
end

function Friends:SyncAllRosters()
    if not CC.db then return end
    self:SyncPlayerFriends()
    self:GetBattleNetFriends()
end

function Friends:RefreshBattleNetRoutes()
    if not CC.db then return end
    self:GetBattleNetFriends()
end

function Friends:RequestRoster()
    -- Some Classic builds expose both APIs while only one actually refreshes the
    -- roster. Call every guarded refresh route; UI reads remain independent.
    if _G.C_FriendList and type(_G.C_FriendList.RequestFriendList) == "function" then pcall(_G.C_FriendList.RequestFriendList) end
    if _G.C_FriendList and type(_G.C_FriendList.ShowFriends) == "function" then pcall(_G.C_FriendList.ShowFriends) end
    if type(_G.ShowFriends) == "function" then pcall(_G.ShowFriends) end
    if _G.C_BattleNet and type(_G.C_BattleNet.RequestFriendInfo) == "function" then pcall(_G.C_BattleNet.RequestFriendInfo) end
end

function Friends:AddFriend(value)
    value = trim(value)
    if value == "" then
        CC:Print("Enter a character name or BattleTag.")
        return false
    end

    if string.find(value, "#", 1, true) then
        local sent = tryActions({
            type(_G.BNInviteFriend) == "function" and _G.BNInviteFriend or nil,
            _G.C_BattleNet and type(_G.C_BattleNet.SendFriendInvite) == "function" and _G.C_BattleNet.SendFriendInvite or nil,
        }, value)
        if sent then
            CC:Print("Battle.net friend request sent to " .. value .. ".")
            self:NotifyUI()
            return true
        end
        CC:Print("Battle.net friend requests are unavailable on this client.")
        return false
    end

    local name = CC:CleanPlayerName(value)
    if name == "" then return false end
    if CC.RememberAccountFriend then CC:RememberAccountFriend(name, { source = "MANUAL", lastSeen = time and time() or 0 }) end
    local added = tryActions({
        _G.C_FriendList and type(_G.C_FriendList.AddFriend) == "function" and _G.C_FriendList.AddFriend or nil,
        type(_G.AddFriend) == "function" and _G.AddFriend or nil,
    }, name)
    CC:Print(CC:ShortName(name) .. " was added to CreshChat account friends" .. (added and " and submitted to Blizzard's friends list." or "."))
    self:RequestRoster()
    self:NotifyUI()
    return true
end

function Friends:InvitePlayer(name)
    name = CC:CleanPlayerName(name)
    if not name or name == "" then return false end

    if type(_G.UnitInParty) == "function" then
        local ok, inParty = pcall(_G.UnitInParty, name)
        if ok and inParty then
            CC:Print(CC:ShortName(name) .. " is already in your party.")
            return false
        end
    end

    local invited = tryActions({
        _G.C_PartyInfo and type(_G.C_PartyInfo.InviteUnit) == "function" and _G.C_PartyInfo.InviteUnit or nil,
        type(_G.InviteUnit) == "function" and _G.InviteUnit or nil,
    }, name)

    if invited then
        CC:Print("Party invite sent to " .. CC:ShortName(name) .. ".")
        return true
    end
    CC:Print("Party invitations are not available on this client.")
    return false
end

function Friends:RemovePlayer(name)
    name = CC:CleanPlayerName(name)
    if not name or name == "" then return false end

    local forgot = CC.ForgetAccountFriend and CC:ForgetAccountFriend(name) or false
    local removed = tryActions({
        _G.C_FriendList and type(_G.C_FriendList.RemoveFriend) == "function" and _G.C_FriendList.RemoveFriend or nil,
        type(_G.RemoveFriend) == "function" and _G.RemoveFriend or nil,
    }, name)

    if removed or forgot then
        CC:Print(CC:ShortName(name) .. " was removed from CreshChat account friends" .. (removed and " and Blizzard's friends list." or "."))
        self:RequestRoster()
        if _G.C_Timer and type(_G.C_Timer.After) == "function" then
            _G.C_Timer.After(0.20, function() Friends:RequestRoster(); Friends:NotifyUI() end)
        else self:NotifyUI() end
        return true
    end
    CC:Print("Unable to remove " .. CC:ShortName(name) .. " from the friends list.")
    return false
end

function Friends:RemoveBattleNetFriend(accountID, displayName, target)
    accountID = tonumber(accountID)
    local shared = CC.EnsureAccountWhisperStorage and CC:EnsureAccountWhisperStorage() or nil
    if not accountID then
        if shared and shared.battleNetFriends and target and shared.battleNetFriends[target] then
            shared.battleNetFriends[target] = nil
            CC:Print((displayName or "Battle.net friend") .. " was removed from CreshChat's cached account directory. Remove them through Battle.net when the live roster is available to remove the Blizzard friendship too.")
            self:NotifyUI()
            return true
        end
        return false
    end
    local removed = tryActions({
        type(_G.BNRemoveFriend) == "function" and _G.BNRemoveFriend or nil,
        _G.C_BattleNet and type(_G.C_BattleNet.RemoveFriend) == "function" and _G.C_BattleNet.RemoveFriend or nil,
    }, accountID)
    if removed then
        if shared and shared.battleNetFriends then
            for cachedTarget, cached in pairs(shared.battleNetFriends) do
                if cachedTarget == target or tonumber(cached and (cached.lastBnetAccountID or cached.bnetAccountID)) == accountID then
                    shared.battleNetFriends[cachedTarget] = nil
                end
            end
        end
        CC:Print((displayName or "Battle.net friend") .. " was removed from your Battle.net friends list.")
        self:NotifyUI()
        return true
    end
    CC:Print("Unable to remove that Battle.net friend on this client.")
    return false
end

function Friends:RemoveEntry(item)
    if not item then return false end
    if item.kind == "BATTLENET" then
        return self:RemoveBattleNetFriend(item.bnetAccountID, item.name, item.target)
    end
    return self:RemovePlayer(item.target or item.name)
end

function Friends:NotifyUI()
    if not (CC.UI and CC.UI.initialized) then return end
    if CC.UI.RequestRefresh then
        CC.UI:RequestRefresh({ conversations = true })
    elseif CC.UI.RefreshConversationList then
        CC.UI:RefreshConversationList()
    end
end

local frame = CreateFrame("Frame", "CreshChatFriendsEventFrame")
local events = {
    "ADDON_LOADED",
    "PLAYER_LOGIN",
    "PLAYER_ENTERING_WORLD",
    "FRIENDLIST_UPDATE",
    "GROUP_ROSTER_UPDATE",
    "PLAYER_ROLES_ASSIGNED",
    "GUILD_ROSTER_UPDATE",
    "PLAYER_GUILD_UPDATE",
    "WHO_LIST_UPDATE",
    "BN_FRIEND_LIST_SIZE_CHANGED",
    "BN_FRIEND_INFO_CHANGED",
    "BN_FRIEND_ACCOUNT_ONLINE",
    "BN_FRIEND_ACCOUNT_OFFLINE",
    "BN_INFO_CHANGED",
    "BN_CONNECTED",
    "BN_DISCONNECTED",
    "BN_FRIEND_INVITE_ADDED",
    "BN_FRIEND_INVITE_REMOVED",
    "ZONE_CHANGED",
    "ZONE_CHANGED_INDOORS",
    "ZONE_CHANGED_NEW_AREA",
}
for _, eventName in ipairs(events) do
    pcall(frame.RegisterEvent, frame, eventName)
end

frame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddon = ...
        if loadedAddon ~= CC.name then return end
    end
    if not CC:IsFeatureEnabled("friendsPresence") then return end

    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" or event == "ADDON_LOADED" then
        Friends:RequestRoster()
        Friends:SyncAllRosters()
        if _G.C_Timer and type(_G.C_Timer.After) == "function" then
            for _, delay in ipairs({ 0.20, 1.00, 3.00 }) do
                _G.C_Timer.After(delay, function()
                    Friends:RequestRoster()
                    Friends:SyncAllRosters()
                    Friends:NotifyUI()
                end)
            end
        end
    elseif event == "FRIENDLIST_UPDATE" then
        Friends:SyncPlayerFriends()
    elseif event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ROLES_ASSIGNED" then
        -- Party/Raid rosters are read directly from unit APIs; the UI refresh
        -- below is enough to rebuild their Online and Offline sections.
    elseif event == "GUILD_ROSTER_UPDATE" or event == "PLAYER_GUILD_UPDATE" then
        Friends:GetGuildRoster()
    elseif event == "WHO_LIST_UPDATE" then
        if _G.C_FriendList and type(_G.C_FriendList.SetWhoToUi) == "function" then pcall(_G.C_FriendList.SetWhoToUi, false) end
        if type(_G.SetWhoToUI) == "function" then pcall(_G.SetWhoToUI, 0) end
        Friends:CaptureLocalRoster()
    elseif string.sub(tostring(event or ""), 1, 3) == "BN_" then
        Friends:RefreshBattleNetRoutes()
    end
    Friends:NotifyUI()
end)
