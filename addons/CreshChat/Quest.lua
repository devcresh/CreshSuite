local _, CC = ...
if not CC then
    return
end

local Quest = { version = CC.version }
CC.Quest = Quest
if CC.RegisterModule then CC:RegisterModule("Quest", Quest) end

local KEY_SEPARATOR = "\031"

local function trim(text)
    text = tostring(text or "")
    text = string.gsub(text, "^%s+", "")
    text = string.gsub(text, "%s+$", "")
    return text
end

local function safeCall(func, ...)
    if type(func) ~= "function" then
        return nil
    end
    local ok, result = pcall(func, ...)
    if ok then
        return result
    end
    return nil
end

local function firstText(...)
    for index = 1, select("#", ...) do
        local value = select(index, ...)
        if type(value) == "string" and trim(value) ~= "" then
            return trim(value)
        end
    end
    return nil
end

function CC:EnsureQuestStorage()
    if not self.db then
        return false
    end
    self.db.history = self.db.history or {}
    self.db.history.quests = self.db.history.quests or {}
    self.db.questConversations = self.db.questConversations or {}
    self.state.unreadQuests = tonumber(self.state.unreadQuests) or 0
    return true
end

function CC:GetQuestZoneName()
    local zone = safeCall(_G.GetRealZoneText)
    if not zone or zone == "" then zone = safeCall(_G.GetZoneText) end
    if not zone or zone == "" then zone = "Unknown Zone" end
    return trim(zone)
end

function CC:GetQuestNPCName()
    local function readName(fontString)
        if fontString and type(fontString.GetText) == "function" then
            local name = safeCall(fontString.GetText, fontString)
            if name and name ~= "" then return trim(name) end
        end
        return nil
    end

    local name = readName(_G.QuestFrameNpcNameText)
        or readName(_G.GossipFrameNpcNameText)
        or readName(_G.QuestFrameGreetingPanel and _G.QuestFrameGreetingPanel.NpcNameText)
        or readName(_G.GossipFrame and _G.GossipFrame.GreetingPanel and _G.GossipFrame.GreetingPanel.NpcNameText)
    if name then return name end

    local units = { "questnpc", "npc", "target", "mouseover" }
    for _, unit in ipairs(units) do
        if type(UnitExists) ~= "function" or UnitExists(unit) then
            local name = safeCall(UnitName, unit)
            if name and name ~= "" then return trim(name) end
        end
    end
    return "Quest Giver"
end

function CC:QuestConversationKey(npcName, zone)
    npcName = trim(npcName)
    zone = trim(zone)
    if npcName == "" then npcName = "Quest Giver" end
    if zone == "" then zone = "Unknown Zone" end
    return zone .. KEY_SEPARATOR .. npcName
end

function CC:GetQuestConversationMeta(key)
    self:EnsureQuestStorage()
    return self.db and self.db.questConversations and self.db.questConversations[key] or nil
end

function CC:EnsureQuestConversation(npcName, zone, timestamp)
    if not self:EnsureQuestStorage() then
        return nil
    end
    npcName = trim(npcName)
    zone = trim(zone)
    if npcName == "" then npcName = "Quest Giver" end
    if zone == "" then zone = self:GetQuestZoneName() end

    local key = self:QuestConversationKey(npcName, zone)
    self.db.history.quests[key] = self.db.history.quests[key] or {}
    local meta = self.db.questConversations[key] or {}
    meta.npcName = npcName
    meta.zone = zone
    meta.updated = tonumber(timestamp) or time()
    meta.hidden = false
    self.db.questConversations[key] = meta
    return key, meta
end

function CC:AddQuestMessage(npcName, text, stage, questTitle, incoming, zone, timestamp)
    text = trim(text)
    if text == "" then
        return nil
    end

    timestamp = tonumber(timestamp) or time()
    zone = trim(zone)
    if zone == "" then zone = self:GetQuestZoneName() end
    local key, meta = self:EnsureQuestConversation(npcName, zone, timestamp)
    if not key then
        return nil
    end

    local list = self.db.history.quests[key]
    local cleanText = self:CleanText(text)
    local cleanTitle = trim(questTitle)
    local cleanStage = string.upper(trim(stage))
    local isIncoming = incoming ~= false
    local previous = list[#list]
    if previous
        and previous.text == cleanText
        and tostring(previous.questTitle or "") == cleanTitle
        and (previous.incoming and true or false) == isIncoming
        and math.abs(timestamp - (tonumber(previous.timestamp) or 0)) <= 4 then
        meta.updated = timestamp
        return nil, key
    end

    local sender = isIncoming and meta.npcName or (self.state.playerName ~= "" and self.state.playerName or "You")
    local message = {
        timestamp = timestamp,
        text = cleanText,
        sender = sender,
        incoming = isIncoming,
        channel = "QUEST",
        target = key,
        stage = cleanStage ~= "" and cleanStage or "DIALOGUE",
        questTitle = cleanTitle ~= "" and cleanTitle or nil,
        npcName = meta.npcName,
        zone = meta.zone,
    }

    table.insert(list, message)
    self:TrimHistory(list)
    meta.updated = timestamp
    return message, key
end

local function frameText(frame)
    if frame and type(frame.GetText) == "function" then
        return safeCall(frame.GetText, frame)
    end
    return nil
end

local function getCurrentQuestTitle()
    return firstText(
        safeCall(_G.GetTitleText),
        frameText(_G.QuestInfoTitleHeader),
        Quest.lastContext and Quest.lastContext.title
    )
end

local function getCurrentQuestID()
    local questID = safeCall(_G.GetQuestID)
    if tonumber(questID) and tonumber(questID) > 0 then
        return tonumber(questID)
    end
    return nil
end

local function updateContext(npcName, zone, title, questID)
    Quest.lastContext = {
        npcName = npcName or (Quest.lastContext and Quest.lastContext.npcName) or CC:GetQuestNPCName(),
        zone = zone or (Quest.lastContext and Quest.lastContext.zone) or CC:GetQuestZoneName(),
        title = title or (Quest.lastContext and Quest.lastContext.title),
        questID = questID or (Quest.lastContext and Quest.lastContext.questID),
    }
    Quest.lastContext.key = CC:QuestConversationKey(Quest.lastContext.npcName, Quest.lastContext.zone)
    return Quest.lastContext
end

local function emit(npcName, zone, text, stage, title, incoming)
    local message, key = CC:AddQuestMessage(npcName, text, stage, title, incoming, zone)
    if message and CC.UI and CC.UI.OnNewMessage then
        CC.UI:OnNewMessage("QUEST", key, message, false)
    end
    if message and incoming ~= false and CC.PlayAlertSound then
        -- Quest frames can emit several text blocks at once. Core throttles this
        -- channel so one interaction produces a single gentle notification.
        CC:PlayAlertSound("QUEST")
    end
    return message, key
end

local function captureQuestMenu(npcName, zone)
    local available = {}
    local availableCount = tonumber(safeCall(_G.GetNumAvailableQuests)) or 0
    for index = 1, availableCount do
        local title = safeCall(_G.GetAvailableTitle, index)
        if title and title ~= "" then table.insert(available, title) end
    end
    if #available > 0 then
        emit(npcName, zone, "Available quests: " .. table.concat(available, ", "), "MENU", nil, true)
    end

    local active = {}
    local activeCount = tonumber(safeCall(_G.GetNumActiveQuests)) or 0
    for index = 1, activeCount do
        local title = safeCall(_G.GetActiveTitle, index)
        if title and title ~= "" then table.insert(active, title) end
    end
    if #active > 0 then
        emit(npcName, zone, "In progress: " .. table.concat(active, ", "), "MENU", nil, true)
    end
end

function Quest:CaptureGossip()
    local npcName = CC:GetQuestNPCName()
    local zone = CC:GetQuestZoneName()
    local text
    if _G.C_GossipInfo and type(_G.C_GossipInfo.GetText) == "function" then
        text = safeCall(_G.C_GossipInfo.GetText)
    end
    text = firstText(text, safeCall(_G.GetGossipText))
    updateContext(npcName, zone, nil, nil)
    if text then emit(npcName, zone, text, "GOSSIP", nil, true) end
end

function Quest:CaptureGreeting()
    local npcName = CC:GetQuestNPCName()
    local zone = CC:GetQuestZoneName()
    local text = firstText(safeCall(_G.GetGreetingText), frameText(_G.QuestFrameGreetingText), frameText(_G.GossipGreetingText))
    updateContext(npcName, zone, nil, nil)
    if text then emit(npcName, zone, text, "GREETING", nil, true) end
    captureQuestMenu(npcName, zone)
end

function Quest:CaptureDetail()
    local npcName = CC:GetQuestNPCName()
    local zone = CC:GetQuestZoneName()
    local title = getCurrentQuestTitle()
    local questID = getCurrentQuestID()
    updateContext(npcName, zone, title, questID)

    local description = firstText(safeCall(_G.GetQuestText), frameText(_G.QuestInfoDescriptionText))
    local objective = firstText(safeCall(_G.GetObjectiveText), frameText(_G.QuestInfoObjectivesText))
    if description then emit(npcName, zone, description, "DETAIL", title, true) end
    if objective and objective ~= description then emit(npcName, zone, objective, "OBJECTIVE", title, true) end
end

function Quest:CaptureProgress()
    local npcName = CC:GetQuestNPCName()
    local zone = CC:GetQuestZoneName()
    local title = getCurrentQuestTitle()
    local questID = getCurrentQuestID()
    updateContext(npcName, zone, title, questID)
    local text = firstText(safeCall(_G.GetProgressText), frameText(_G.QuestProgressText))
    if text then emit(npcName, zone, text, "PROGRESS", title, true) end
end

function Quest:CaptureComplete()
    local npcName = CC:GetQuestNPCName()
    local zone = CC:GetQuestZoneName()
    local title = getCurrentQuestTitle()
    local questID = getCurrentQuestID()
    updateContext(npcName, zone, title, questID)
    local text = firstText(safeCall(_G.GetRewardText), frameText(_G.QuestRewardText))
    if text then emit(npcName, zone, text, "REWARD", title, true) end
end

local function questTitleFromLogIndex(index)
    index = tonumber(index)
    if not index or type(_G.GetQuestLogTitle) ~= "function" then return nil end
    local title = safeCall(_G.GetQuestLogTitle, index)
    return firstText(title)
end

function Quest:CaptureAccepted(...)
    local firstArg, secondArg = ...
    local context = Quest.lastContext or updateContext(CC:GetQuestNPCName(), CC:GetQuestZoneName(), nil, nil)
    local title = firstText(context.title, questTitleFromLogIndex(firstArg))
    local questID = tonumber(secondArg) or tonumber(firstArg) or context.questID
    context.title = title or context.title
    context.questID = questID or context.questID
    local label = context.title and ("Accepted quest: " .. context.title) or "Quest accepted"
    emit(context.npcName, context.zone, label, "ACCEPTED", context.title, false)
end

function Quest:CaptureTurnedIn(questID)
    local context = Quest.lastContext
    if not context then return end
    if tonumber(questID) and context.questID and tonumber(questID) ~= tonumber(context.questID) then
        return
    end
    local label = context.title and ("Completed quest: " .. context.title) or "Quest completed"
    emit(context.npcName, context.zone, label, "COMPLETED", context.title, false)
end

function Quest:EnsureReady()
    if not CC.db then
        CC:InitializeDatabase()
    end
    CC:EnsureQuestStorage()
end

local frame = CreateFrame("Frame", "CreshChatQuestEventFrame")
local events = {
    "ADDON_LOADED",
    "PLAYER_LOGIN",
    "GOSSIP_SHOW",
    "QUEST_GREETING",
    "QUEST_DETAIL",
    "QUEST_PROGRESS",
    "QUEST_COMPLETE",
    "QUEST_ACCEPTED",
    "QUEST_TURNED_IN",
    "QUEST_FINISHED",
}

for _, eventName in ipairs(events) do
    pcall(frame.RegisterEvent, frame, eventName)
end

frame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddon = ...
        if loadedAddon == CC.name then Quest:EnsureReady() end
        return
    end
    if event == "PLAYER_LOGIN" then
        Quest:EnsureReady()
        return
    end
    if not CC.db then return end
    if not CC:IsFeatureEnabled("questCapture") then return end

    if event == "GOSSIP_SHOW" then Quest:CaptureGossip()
    elseif event == "QUEST_GREETING" then Quest:CaptureGreeting()
    elseif event == "QUEST_DETAIL" then Quest:CaptureDetail()
    elseif event == "QUEST_PROGRESS" then Quest:CaptureProgress()
    elseif event == "QUEST_COMPLETE" then Quest:CaptureComplete()
    elseif event == "QUEST_ACCEPTED" then Quest:CaptureAccepted(...)
    elseif event == "QUEST_TURNED_IN" then Quest:CaptureTurnedIn(...)
    elseif event == "QUEST_FINISHED" then Quest.pending = nil end
end)
