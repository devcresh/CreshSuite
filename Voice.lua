local _, CC = ...
if not CC then return end

local Voice = {
    version = CC.version,
    prefix = "CRVOICE1",
    peers = {},
    pending = {},
    active = nil,
}
CC.Voice = Voice
if CC.RegisterModule then CC:RegisterModule("Voice", Voice) end

local function now()
    return type(_G.GetTime) == "function" and _G.GetTime() or 0
end

local function cleanName(name)
    return tostring(name or ""):gsub("%s+", "")
end

local function shortName(name)
    return CC.ShortName and CC:ShortName(name) or tostring(name or "")
end

local function routeName(name)
    return cleanName(name)
end

local function peerKey(name)
    return string.lower(shortName(name))
end

local function namesEquivalent(first, second)
    if CC.WhisperNamesEquivalent then return CC:WhisperNamesEquivalent(first, second) end
    return string.lower(shortName(first)) == string.lower(shortName(second))
end

local function send(target, payload)
    target = routeName(target)
    payload = tostring(payload or "")
    if target == "" or payload == "" or string.len(payload) > 250 then return false end
    if _G.C_ChatInfo and type(_G.C_ChatInfo.SendAddonMessage) == "function" then
        local ok = pcall(_G.C_ChatInfo.SendAddonMessage, Voice.prefix, payload, "WHISPER", target)
        return ok
    elseif type(_G.SendAddonMessage) == "function" then
        return pcall(_G.SendAddonMessage, Voice.prefix, payload, "WHISPER", target)
    end
    return false
end

local function voiceStatusOK(status)
    status = tonumber(status)
    -- Success, OperationPending, ChannelAlreadyExists and AlreadyInChannel.
    return status == nil or status == 0 or status == 1 or status == 9 or status == 10
end

local function safeChannelPart(value)
    value = string.lower(tostring(value or "player"))
    value = value:gsub("[^%w]", "")
    if value == "" then value = "player" end
    return value
end

local function sessionName(target, token)
    local ownName = CC.state and (CC.state.playerFullName or CC.state.playerName) or "player"
    local first, second = safeChannelPart(ownName), safeChannelPart(target)
    if first > second then first, second = second, first end
    return string.sub("Cresh-" .. first .. "-" .. second .. "-" .. tostring(token or "0"), 1, 48)
end

local function unitFullName(unit)
    if type(_G.UnitName) ~= "function" then return nil end
    local name, realm = _G.UnitName(unit)
    if not name then return nil end
    if realm and realm ~= "" then return name .. "-" .. realm end
    return name
end

local function targetIsGroupMember(target)
    target = tostring(target or "")
    if target == "" then return false end
    local maximum = (type(_G.IsInRaid) == "function" and _G.IsInRaid()) and 40 or 4
    local prefix = maximum == 40 and "raid" or "party"
    for index = 1, maximum do
        local unit = prefix .. tostring(index)
        if type(_G.UnitExists) ~= "function" or _G.UnitExists(unit) then
            local unitName = unitFullName(unit)
            if unitName and namesEquivalent(unitName, target) then return true end
        end
    end
    return false
end

local function groupChannelType()
    local types = _G.Enum and _G.Enum.ChatChannelType
    if not types then return nil end
    if type(_G.IsInGroup) == "function" and _G.LE_PARTY_CATEGORY_INSTANCE and _G.IsInGroup(_G.LE_PARTY_CATEGORY_INSTANCE) then
        return types.Instance or types.Party
    end
    if type(_G.IsInRaid) == "function" and _G.IsInRaid() then return types.Raid or types.Party end
    return types.Party
end

function Voice:Ensure()
    if not CC.db then return nil end
    CC.db.voice = type(CC.db.voice) == "table" and CC.db.voice or {}
    if CC.db.voice.enabled == nil then CC.db.voice.enabled = true end
    return CC.db.voice
end

function Voice:Register()
    if self.registered then return true end
    local ok = false
    if _G.C_ChatInfo and type(_G.C_ChatInfo.RegisterAddonMessagePrefix) == "function" then
        ok = pcall(_G.C_ChatInfo.RegisterAddonMessagePrefix, self.prefix)
    elseif type(_G.RegisterAddonMessagePrefix) == "function" then
        ok = pcall(_G.RegisterAddonMessagePrefix, self.prefix)
    end
    self.registered = ok and true or false
    return self.registered
end

function Voice:IsPeerReady(name)
    local peer = self.peers[peerKey(name)]
    return peer and now() - (peer.seen or 0) < 600 or false
end

function Voice:Probe(name)
    if not self:Ensure() or CC.db.voice.enabled == false then return false end
    self:Register()
    self.lastProbe = self.lastProbe or {}
    local key = peerKey(name)
    if now() - (self.lastProbe[key] or 0) < 20 then return self:IsPeerReady(name) end
    self.lastProbe[key] = now()
    send(name, "HELLO~" .. tostring(CC.version))
    return self:IsPeerReady(name)
end

function Voice:MarkPeer(name)
    self.peers[peerKey(name)] = { name = name, seen = now() }
    if CC.UI and CC.UI.RefreshConversationList then CC.UI:RefreshConversationList() end
    if CC.UI and CC.UI.RefreshWhisperChrome then CC.UI:RefreshWhisperChrome() end
end

function Voice:CanUseNative()
    if not _G.C_VoiceChat then return false end
    if type(_G.C_VoiceChat.CanPlayerUseVoiceChat) == "function" then
        local ok, available = pcall(_G.C_VoiceChat.CanPlayerUseVoiceChat)
        if ok and available == false then return false end
    end
    return type(_G.C_VoiceChat.CreateChannel) == "function"
        or type(_G.C_VoiceChat.RequestJoinChannelByChannelType) == "function"
end

function Voice:ActivateNative(target, token)
    if not self:CanUseNative() then
        if CC.Print then CC:Print("Blizzard voice chat is unavailable on this client or account.") end
        return false
    end

    if type(_G.C_VoiceChat.Login) == "function" then pcall(_G.C_VoiceChat.Login) end

    local joined = false
    local custom = false
    local channelName

    -- Only use party/raid voice when the requested player is actually in the same group.
    if targetIsGroupMember(target) and type(_G.C_VoiceChat.RequestJoinChannelByChannelType) == "function" then
        local channelType = groupChannelType()
        if channelType ~= nil then
            joined = pcall(_G.C_VoiceChat.RequestJoinChannelByChannelType, channelType, true)
        end
    end

    if not joined and type(_G.C_VoiceChat.CreateChannel) == "function" then
        custom = true
        channelName = sessionName(target, token)
        local ok, status = pcall(_G.C_VoiceChat.CreateChannel, channelName)
        joined = ok and voiceStatusOK(status)
    end

    if not joined then
        if CC.Print then CC:Print("WoW could not create or join the voice channel for " .. shortName(target) .. ".") end
        return false
    end

    self.active = {
        target = target,
        token = token,
        started = now(),
        connecting = true,
        custom = custom,
        channelName = channelName,
    }

    if CC.UI and CC.UI.ShowSystemToast then
        CC.UI:ShowSystemToast("Voice call", "Connecting with " .. shortName(target) .. " through Blizzard voice chat.", "INFO")
    end
    if CC.UI and CC.UI.RefreshWhisperChrome then CC.UI:RefreshWhisperChrome() end
    return true
end

function Voice:DeactivateNative()
    local active = self.active
    if not active or not _G.C_VoiceChat then return end
    local channelID = active.channelID
    if not channelID and type(_G.C_VoiceChat.GetActiveChannelID) == "function" then
        local ok, value = pcall(_G.C_VoiceChat.GetActiveChannelID)
        if ok then channelID = value end
    end
    if not channelID then return end

    if type(_G.C_VoiceChat.DeactivateChannel) == "function" then
        pcall(_G.C_VoiceChat.DeactivateChannel, channelID)
    end
    if active.custom and type(_G.C_VoiceChat.LeaveChannel) == "function" then
        pcall(_G.C_VoiceChat.LeaveChannel, channelID)
    end
end

function Voice:EndCall(silent, remoteEnded)
    local target = self.active and self.active.target
    self:DeactivateNative()
    self.active = nil
    if target and not remoteEnded then send(target, "END") end
    if not silent and CC.Print then CC:Print("Voice call ended.") end
    if CC.UI and CC.UI.RefreshWhisperChrome then CC.UI:RefreshWhisperChrome() end
end

function Voice:RequestCall(target)
    target = routeName(target)
    if target == "" then return false end
    if not self:CanUseNative() then
        if CC.Print then
            CC:Print("Voice calls require Blizzard native voice chat, which is not available on this client.")
        end
        return false
    end
    if self.active and namesEquivalent(self.active.target, target) then
        self:EndCall()
        return true
    elseif self.active then
        if CC.Print then CC:Print("End the current voice call before calling another player.") end
        return false
    end
    if not self:Ensure() or CC.db.voice.enabled == false then
        if CC.Print then CC:Print("Voice calls are disabled in Settings.") end
        return false
    end

    self:Register()
    self:Probe(target)
    local token = tostring(math.floor(now() * 1000) % 1000000)
    self.pending[peerKey(target)] = { target = target, token = token, at = now() }
    send(target, "CALL~" .. token)

    if CC.UI and CC.UI.ShowSystemToast then
        CC.UI:ShowSystemToast("Voice call sent", "Waiting for " .. shortName(target) .. " to accept.", "INFO")
    end

    if _G.C_Timer and type(_G.C_Timer.After) == "function" then
        _G.C_Timer.After(8, function()
            local key = peerKey(target)
            if Voice.pending[key] then
                Voice.pending[key] = nil
                if CC.Print then CC:Print(shortName(target) .. " did not answer the voice call. They may not have CreshChat.") end
            end
        end)
    end
    return true
end

function Voice:ShowIncoming(sender, token)
    if self.active then
        send(sender, "DECLINE")
        return
    end
    if not _G.StaticPopupDialogs or not _G.StaticPopup_Show then return end
    if not _G.StaticPopupDialogs.CRESHCHAT_VOICE_CALL then
        _G.StaticPopupDialogs.CRESHCHAT_VOICE_CALL = {
            text = "Voice call from %s",
            button1 = _G.ACCEPT or "Accept",
            button2 = _G.DECLINE or "Decline",
            timeout = 20,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
            OnAccept = function(_, data)
                if not data then return end
                send(data.sender, "ACCEPT~" .. data.token)
                Voice:ActivateNative(data.sender, data.token)
            end,
            OnCancel = function(_, data)
                if data and data.sender then send(data.sender, "DECLINE") end
            end,
        }
    end
    _G.StaticPopup_Show("CRESHCHAT_VOICE_CALL", shortName(sender), nil, { sender = sender, token = token })
end

function Voice:Handle(sender, message)
    if not self:Ensure() or CC.db.voice.enabled == false then return end
    local operation, argument = tostring(message or ""):match("^([^~]+)~?(.*)$")
    operation = string.upper(operation or "")

    if operation == "HELLO" then
        self:MarkPeer(sender)
        send(sender, "ACK~" .. tostring(CC.version))
    elseif operation == "ACK" then
        self:MarkPeer(sender)
    elseif operation == "CALL" then
        self:MarkPeer(sender)
        self:ShowIncoming(sender, argument)
    elseif operation == "ACCEPT" then
        self:MarkPeer(sender)
        self.pending[peerKey(sender)] = nil
        self:ActivateNative(sender, argument)
    elseif operation == "DECLINE" then
        self.pending[peerKey(sender)] = nil
        if CC.Print then CC:Print(shortName(sender) .. " declined the voice call.") end
    elseif operation == "END" and self.active and namesEquivalent(self.active.target, sender) then
        self:EndCall(true, true)
        if CC.Print then CC:Print(shortName(sender) .. " ended the voice call.") end
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("CHAT_MSG_ADDON")
pcall(function() eventFrame:RegisterEvent("VOICE_CHAT_CHANNEL_JOINED") end)
eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        Voice:Register()
        Voice:Ensure()
    elseif event == "CHAT_MSG_ADDON" then
        local prefix, message, _, sender = ...
        if prefix == Voice.prefix then Voice:Handle(sender, message) end
    elseif event == "VOICE_CHAT_CHANNEL_JOINED" then
        local status, channelID = ...
        if Voice.active and voiceStatusOK(status) and channelID then
            Voice.active.channelID = channelID
            Voice.active.connecting = false
            if _G.C_VoiceChat and type(_G.C_VoiceChat.ActivateChannel) == "function" then
                pcall(_G.C_VoiceChat.ActivateChannel, channelID)
            end
            if CC.UI and CC.UI.ShowSystemToast then
                CC.UI:ShowSystemToast("Voice call connected", "Connected with " .. shortName(Voice.active.target) .. ".", "SUCCESS")
            end
            if CC.UI and CC.UI.RefreshWhisperChrome then CC.UI:RefreshWhisperChrome() end
        end
    end
end)
