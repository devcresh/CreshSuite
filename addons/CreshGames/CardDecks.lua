local _, CG = ...
if not CG then return end
-- CC is a nil-safe proxy for optional CreshChat integration when CreshChat is not loaded.
local CC = setmetatable({}, { __index = function(_, k) local c = _G.CreshChat; return c and c[k] end })

local Decks = {
    version = CG.version,
    defaultDeck = "Classic_8Bit",
    gameKeys = { "HOLDEM", "BLACKJACK", "HIGHERLOWER" },
    premiumOrder = {
        "Alliance_Vanguard", "Horde_Warband", "Fel_Crusade",
        "Shattrath_Light", "Netherstorm_Arcana", "Dark_Portal",
    },
}
CG.CardDecks = Decks
if CG.RegisterModule then CG:RegisterModule("CardDecks", Decks) end

local floor, max = math.floor, math.max
local upper = string.upper

local function library()
    return _G.CreshGamesCardDecks or {}
end

local function hashText(text)
    local value = 5381
    text = tostring(text or "")
    for index = 1, #text do
        value = (value * 33 + string.byte(text, index)) % 2147483647
    end
    return value
end

local function identitySeed()
    local pieces = {}
    if type(_G.UnitGUID) == "function" then pieces[#pieces + 1] = _G.UnitGUID("player") or "" end
    if type(_G.UnitName) == "function" then pieces[#pieces + 1] = _G.UnitName("player") or "" end
    if type(_G.GetRealmName) == "function" then pieces[#pieces + 1] = _G.GetRealmName() or "" end
    local text = table.concat(pieces, ":")
    if text == "::" or text == "" then
        local stamp = type(_G.time) == "function" and _G.time() or 1
        text = "CreshChat:" .. tostring(stamp)
    end
    return hashText(text)
end

function Decks:GetDeckInfo(deckKey)
    return library()[tostring(deckKey or "")]
end

function Decks:GetDisplayName(deckKey)
    local info = self:GetDeckInfo(deckKey)
    return info and info.displayName or tostring(deckKey or "Classic 8-Bit")
end

function Decks:ChooseStarterDeck()
    local index = (identitySeed() % #self.premiumOrder) + 1
    return self.premiumOrder[index]
end

function Decks:Ensure()
    if not CreshGamesDB then return nil end
    CreshGamesDB.cardDecks = type(CreshGamesDB.cardDecks) == "table" and CreshGamesDB.cardDecks or {}
    local save = CreshGamesDB.cardDecks
    save.unlocked = type(save.unlocked) == "table" and save.unlocked or {}
    save.selected = type(save.selected) == "table" and save.selected or {}
    if not self:GetDeckInfo(save.starterDeck) or save.starterDeck == self.defaultDeck then
        save.starterDeck = self:ChooseStarterDeck()
    end
    save.unlocked[self.defaultDeck] = true
    save.unlocked[save.starterDeck] = true
    save.unlockSources = type(save.unlockSources) == "table" and save.unlockSources or {}
    save.unlockSources[self.defaultDeck] = save.unlockSources[self.defaultDeck] or "DEFAULT"
    save.unlockSources[save.starterDeck] = save.unlockSources[save.starterDeck] or "RANDOM_STARTER"

    for _, gameKey in ipairs(self.gameKeys) do
        local selected = save.selected[gameKey]
        if not self:GetDeckInfo(selected) or save.unlocked[selected] ~= true then
            save.selected[gameKey] = self.defaultDeck
        end
    end
    return save
end

function Decks:GetStarterDeck()
    local save = self:Ensure()
    return save and save.starterDeck or self.premiumOrder[1]
end

function Decks:IsUnlocked(deckKey)
    local save = self:Ensure()
    return save and save.unlocked[tostring(deckKey or "")] == true or false
end

function Decks:UnlockDeck(deckKey, source, silent)
    local save = self:Ensure()
    deckKey = tostring(deckKey or "")
    if not save or not self:GetDeckInfo(deckKey) then return false end
    local newlyUnlocked = save.unlocked[deckKey] ~= true
    save.unlocked[deckKey] = true
    save.unlockSources[deckKey] = save.unlockSources[deckKey] or tostring(source or "REWARD")
    if newlyUnlocked then
        if not silent and CC.Print then CC:Print(self:GetDisplayName(deckKey) .. " card deck unlocked.") end
        local Suite = _G.CreshSuite
        if Suite and Suite.Publish then
            Suite:Publish("CRESHGAMES_COLLECTION_UNLOCK", { source = "CRESHGAMES", type = "CARD_DECK", key = deckKey })
        end
    end
    return newlyUnlocked
end

-- A reward slot that names a specific deck (e.g. an Arcade Pass level) can
-- target a deck the player already owns -- most commonly their own randomly
-- assigned starter deck. Rather than let that reward silently do nothing,
-- substitute the next locked premium deck; if every premium deck is already
-- owned, tell the caller so it can substitute a coin voucher instead.
-- Returns true if a deck was newly unlocked (the named one or a substitute),
-- false if every premium deck was already owned (nothing left to grant).
function Decks:GrantDeckOrVoucher(deckKey, source, silent)
    if self:UnlockDeck(deckKey, source, silent) then return true end
    local save = self:Ensure()
    if not save then return false end
    for _, candidate in ipairs(self.premiumOrder) do
        if candidate ~= save.starterDeck and not save.unlocked[candidate] then
            return self:UnlockDeck(candidate, tostring(source or "REWARD") .. ":VOUCHER", silent)
        end
    end
    return false
end

function Decks:GetUnlockedOrder()
    local save = self:Ensure()
    local result, seen = {}, {}
    local function add(deckKey)
        if deckKey and not seen[deckKey] and self:GetDeckInfo(deckKey) and save and save.unlocked[deckKey] then
            seen[deckKey] = true
            result[#result + 1] = deckKey
        end
    end
    add(self.defaultDeck)
    add(save and save.starterDeck)
    for _, deckKey in ipairs(self.premiumOrder) do add(deckKey) end
    return result
end

function Decks:GetSelected(gameKey)
    local save = self:Ensure()
    gameKey = upper(tostring(gameKey or "HOLDEM"))
    if gameKey == "MULTI_HOLDEM" then gameKey = "HOLDEM" end
    local selected = save and save.selected[gameKey] or self.defaultDeck
    if not self:IsUnlocked(selected) then selected = self.defaultDeck end
    return selected
end

function Decks:SetSelected(gameKey, deckKey)
    local save = self:Ensure()
    gameKey = upper(tostring(gameKey or "HOLDEM"))
    if gameKey == "MULTI_HOLDEM" then gameKey = "HOLDEM" end
    deckKey = tostring(deckKey or "")
    if not save or not self:IsUnlocked(deckKey) then return false end
    save.selected[gameKey] = deckKey
    return true
end

function Decks:Cycle(gameKey, direction)
    local order = self:GetUnlockedOrder()
    if #order == 0 then return self.defaultDeck end
    local current = self:GetSelected(gameKey)
    local index = 1
    for position, deckKey in ipairs(order) do if deckKey == current then index = position break end end
    direction = tonumber(direction) or 1
    index = ((index - 1 + direction) % #order) + 1
    self:SetSelected(gameKey, order[index])
    return order[index]
end

function Decks:CardCode(card)
    if type(card) == "string" then
        local code = upper(card)
        if string.sub(code, 1, 1) == "T" then code = "10" .. string.sub(code, 2) end
        return code
    end
    card = tonumber(card)
    if not card or card < 1 or card > 52 then return nil end
    local rank = ((card - 1) % 13) + 2
    local suitIndex = floor((card - 1) / 13) + 1
    local suits = { "S", "H", "D", "C" }
    local rankText
    if rank == 14 then rankText = "A"
    elseif rank == 13 then rankText = "K"
    elseif rank == 12 then rankText = "Q"
    elseif rank == 11 then rankText = "J"
    else rankText = tostring(rank) end
    return rankText .. suits[suitIndex]
end

function Decks:GetCardTexture(gameKey, card, hidden)
    local selected = self:GetSelected(gameKey)
    local info = self:GetDeckInfo(selected) or self:GetDeckInfo(self.defaultDeck)
    if not info then return nil end
    if hidden then return info.back end
    local code = self:CardCode(card)
    if not code then return nil end
    return info.cards and info.cards[code] or nil
end

function Decks:ApplyCardFrame(frame, card, hidden, gameKey)
    if not frame then return false end
    frame.creshDeckGameKey = gameKey or frame.creshDeckGameKey or "HOLDEM"
    local path = self:GetCardTexture(frame.creshDeckGameKey, card, hidden)
    if not path then
        if frame.cardTexture then frame.cardTexture:Hide() end
        if frame.text then frame.text:Show() end
        return false
    end
    if not frame.cardTexture then
        frame.cardTexture = frame:CreateTexture(nil, "ARTWORK")
        frame.cardTexture:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
        frame.cardTexture:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
    end
    frame.cardTexture:SetTexture(path)
    frame.cardTexture:SetTexCoord(0.125, 0.875, 0, 1)
    frame.cardTexture:SetVertexColor(1, 1, 1, 1)
    frame.cardTexture:Show()
    if frame.text then frame.text:Hide() end
    return true
end

function Decks:GetButtonText(gameKey)
    return "DECK · " .. self:GetDisplayName(self:GetSelected(gameKey))
end

function Decks:StyleDeckButton(button, gameKey)
    if not button then return end
    button.creshDeckGameKey = gameKey
    if button.RegisterForClicks then button:RegisterForClicks("LeftButtonUp", "RightButtonUp") end
    if not button.deckIcon then
        button.deckIcon = button:CreateTexture(nil, "ARTWORK")
        button.deckIcon:SetSize(20, 20)
        button.deckIcon:SetPoint("LEFT", button, "LEFT", 4, 0)
    end
    if button.label then
        button.label:ClearAllPoints()
        button.label:SetPoint("LEFT", button.deckIcon, "RIGHT", 4, 0)
        button.label:SetPoint("RIGHT", button, "RIGHT", -5, 0)
        button.label:SetJustifyH("LEFT")
    end
    button.RefreshDeck = function(selfButton)
        local selected = Decks:GetSelected(selfButton.creshDeckGameKey)
        local info = Decks:GetDeckInfo(selected)
        if selfButton.label then selfButton.label:SetText(Decks:GetButtonText(selfButton.creshDeckGameKey)) end
        if selfButton.deckIcon and info and info.icon then
            selfButton.deckIcon:SetTexture(info.icon)
            selfButton.deckIcon:SetTexCoord(0, 1, 0, 1)
            selfButton.deckIcon:Show()
        elseif selfButton.deckIcon then selfButton.deckIcon:Hide() end
    end
    if button.HookScript then
        button:HookScript("OnEnter", function(selfButton)
            if not _G.GameTooltip then return end
            _G.GameTooltip:SetOwner(selfButton, "ANCHOR_RIGHT")
            _G.GameTooltip:AddLine("Card Deck", 1, 0.82, 0.2)
            _G.GameTooltip:AddLine(Decks:GetDisplayName(Decks:GetSelected(selfButton.creshDeckGameKey)), 1, 1, 1)
            _G.GameTooltip:AddLine("Left-click: next unlocked deck", 0.75, 0.82, 0.92)
            _G.GameTooltip:AddLine("Right-click: previous unlocked deck", 0.75, 0.82, 0.92)
            _G.GameTooltip:AddLine("More decks unlock through the Battle Pass.", 0.55, 0.72, 1)
            _G.GameTooltip:Show()
        end)
        button:HookScript("OnLeave", function() if _G.GameTooltip then _G.GameTooltip:Hide() end end)
    end
    button:RefreshDeck()
end
