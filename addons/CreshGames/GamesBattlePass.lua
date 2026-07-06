-- CreshGames/BattlePass.lua
-- CreshGames' own Battle Pass: earns Cresh Coins and Pass XP exclusively
-- from in-game activity (mini-game level-ups, see GameProgression's
-- AwardGameLevel bridge in CreshCollect/Progression.lua), and grants
-- exclusively game-owned rewards (card decks, Tetris themes, spendable
-- Cresh Coins). Deliberately separate from CreshCollect's own 200-level
-- Battle Pass, which stays fed by achievements/exploration/quests and keeps
-- its own reward catalog (world/chat themes) untouched.
--
-- State lives in CreshGamesDB.battlePass -- a brand-new table; nothing is
-- migrated from CreshCollectDB (that data remains CreshCollect's, describing
-- a different, still-active pass).
local _, CG = ...
if not CG then return end

local CC = setmetatable({}, { __index = function(_, k)
    local c = _G.CreshChat
    return c and c[k]
end })

local Pass = {
    version = CG.version,
    maxLevel = 50,
}
CG.BattlePass = Pass
if CG.RegisterModule then CG:RegisterModule("BattlePass", Pass) end

local floor, min, max = math.floor, math.min, math.max

local function now()
    if type(_G.time) == "function" then return _G.time() end
    if type(_G.GetTime) == "function" then return floor(_G.GetTime()) end
    return 0
end

local function clamp(value, low, high)
    value = tonumber(value) or low
    return max(low, min(high, value))
end

local function formatNumber(value)
    local text = tostring(floor(max(0, tonumber(value) or 0)))
    local grouped = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    if grouped:sub(1, 1) == "," then grouped = grouped:sub(2) end
    return grouped
end

-- The nine game-owned rewards formerly claimed through CreshCollect's Battle
-- Pass (levels 10/15/25/35/40/55/75/95/100 of that 100-level track), spread
-- across this pass's own 50 levels at roughly the same relative pacing.
Pass.gameRewardCatalog = {
    [5]  = { deckKey = "Alliance_Vanguard", deckName = "Alliance Vanguard" },
    [8]  = { tetrisThemeKey = "QUAKE_ARENA", tetrisThemeName = "Quake Arena" },
    [13] = { deckKey = "Horde_Warband", deckName = "Horde Warband" },
    [18] = { tetrisThemeKey = "DARK_PORTAL_BLOCKS", tetrisThemeName = "Dark Portal Blocks" },
    [20] = { deckKey = "Fel_Crusade", deckName = "Fel Crusade" },
    [28] = { deckKey = "Shattrath_Light", deckName = "Shattrath Light", tetrisThemeKey = "ASHBRINGER_LIGHT", tetrisThemeName = "Ashbringer Light" },
    [38] = { deckKey = "Netherstorm_Arcana", deckName = "Netherstorm Arcana", tetrisThemeKey = "ILLIDARI_FEL", tetrisThemeName = "Illidari Fel" },
    [48] = { tetrisThemeKey = "COSMIC_GRANDMASTER", tetrisThemeName = "Cosmic Grandmaster" },
    [50] = { deckKey = "Dark_Portal", deckName = "Dark Portal" },
}

Pass.levelNames = {
    "Arcade Initiate", "First Hop", "Lucky Draw", "Dungeon Scout", "Bronze Cache",
    "Opening Move", "River Reader", "Twenty-One", "Minion Recruit", "Silver Cache",
    "Traffic Dodger", "Pair Maker", "Room Delver", "Board Tactician", "Challenger Cache",
    "Line Breaker", "Paddle Keeper", "Dice Fighter", "Streak Seeker", "Gold Cache",
    "Frogger Veteran", "Card Shark", "Dungeon Captain", "Chess Strategist", "Heroic Cache",
    "Tetris Racer", "Pong Contender", "Blackjack Ace", "Boss Hunter", "Platinum Cache",
    "Endless Hopper", "Table Veteran", "Minion Master", "Chess Expert", "Champion Cache",
    "High Roller", "Dungeon Survivor", "Perfect Read", "Multiplayer Rival", "Mythic Cache",
    "Arcade Elite", "Board Master", "River King", "Endless Dweller", "Legend Cache",
    "Grandmaster Trial", "Casino Champion", "Game Night Hero", "Cresh Challenger", "Grand Arcade Vault",
}

function Pass:Ensure()
    if not _G.CreshGamesDB then return nil end
    _G.CreshGamesDB.battlePass = type(_G.CreshGamesDB.battlePass) == "table" and _G.CreshGamesDB.battlePass or {}
    local save = _G.CreshGamesDB.battlePass
    save.coins = floor(max(0, tonumber(save.coins) or 0))
    save.lifetimeCoins = floor(max(save.coins, tonumber(save.lifetimeCoins) or save.coins))
    save.xp = floor(max(0, tonumber(save.xp) or 0))
    save.claimed = type(save.claimed) == "table" and save.claimed or {}
    save.recent = type(save.recent) == "table" and save.recent or {}
    return save
end

-- Same closed-form leveling curve as CreshCollect's Battle Pass (proven
-- math, reused for consistency): GetNextLevelCost(level) = 50 + (level-1)*5.
function Pass:GetNextLevelCost(level)
    level = floor(clamp(level, 1, self.maxLevel))
    return 50 + ((level - 1) * 5)
end

function Pass:GetCumulativeXP(level)
    level = floor(clamp(level, 1, self.maxLevel))
    local completed = level - 1
    return completed * 50 + (5 * completed * (completed - 1)) / 2
end

function Pass:GetLevelFromXP(xp)
    xp = floor(max(0, tonumber(xp) or 0))
    local k = floor((-95 + math.sqrt(9025 + 40 * xp)) / 10)
    local level = max(1, min(self.maxLevel, 1 + k))
    while level < self.maxLevel and xp >= self:GetCumulativeXP(level + 1) do level = level + 1 end
    while level > 1               and xp <  self:GetCumulativeXP(level)     do level = level - 1 end
    return level
end

function Pass:GetProgress()
    local save = self:Ensure()
    if not save then return 1, 0, 50, 0 end
    local level = self:GetLevelFromXP(save.xp)
    local base = self:GetCumulativeXP(level)
    if level >= self.maxLevel then return level, 1, 1, 1 end
    local required = self:GetNextLevelCost(level)
    local current = max(0, save.xp - base)
    return level, current, required, clamp(current / max(1, required), 0, 1)
end

function Pass:GetReward(level)
    level = floor(clamp(level, 1, self.maxLevel))
    local coins
    if level == self.maxLevel then
        coins = 500 -- capstone: completing all 50 levels
    elseif level % 10 == 0 then
        coins = 100 + level * 2
    elseif level % 5 == 0 then
        coins = 45 + level
    else
        coins = 15 + floor((level - 1) / 5) * 5
    end
    local gameReward = self.gameRewardCatalog[level] or {}
    return {
        level = level, coins = coins,
        title = self.levelNames[level] or ("Games Battle Pass Level " .. level),
        deckKey = gameReward.deckKey,
        deckName = gameReward.deckName,
        tetrisThemeKey = gameReward.tetrisThemeKey,
        tetrisThemeName = gameReward.tetrisThemeName,
    }
end

function Pass:IsLevelReached(level)
    local save = self:Ensure()
    if not save then return false end
    return save.xp >= self:GetCumulativeXP(level)
end

function Pass:IsRewardClaimed(level)
    local save = self:Ensure()
    return save and save.claimed[tostring(level)] == true or false
end

function Pass:AddCoins(amount, _source)
    local save = self:Ensure()
    amount = floor(max(0, tonumber(amount) or 0))
    if not save or amount <= 0 then return 0 end
    save.coins = save.coins + amount
    save.lifetimeCoins = save.lifetimeCoins + amount
    return amount
end

function Pass:AddXP(amount, source, silent)
    local save = self:Ensure()
    amount = floor(max(0, tonumber(amount) or 0))
    if not save or amount <= 0 then return 0 end
    local previousLevel = self:GetLevelFromXP(save.xp)
    save.xp = save.xp + amount
    local newLevel = self:GetLevelFromXP(save.xp)
    save.recent = { text = tostring(source or "Activity") .. " reward", xp = amount, level = newLevel, at = now() }
    if not silent then
        self:RefreshWindow()
        if newLevel > previousLevel then
            local reward = self:GetReward(newLevel)
            local detail = "+" .. amount .. " Pass Points -- reward ready"
            if reward.deckName then detail = detail .. " -- " .. reward.deckName .. " deck" end
            if reward.tetrisThemeName then detail = detail .. " -- " .. reward.tetrisThemeName .. " Tetris set" end
            if CC.UI and CC.UI.ShowGameToast then
                CC.UI:ShowGameToast("Games Battle Pass Level " .. newLevel, detail, "SUCCESS", "GBP:LEVEL:" .. tostring(newLevel))
            end
        end
    end
    return amount, previousLevel, newLevel
end

-- Grants a claimed level's game-owned reward directly (same addon now, no
-- Suite-API hop needed).
local function grantGameReward(reward, silent)
    if reward.deckKey and CG.CardDecks and CG.CardDecks.UnlockDeck then
        CG.CardDecks:UnlockDeck(reward.deckKey, "GAMES_BATTLEPASS", silent ~= false)
    end
    if reward.tetrisThemeKey and CG.Tetris and CG.Tetris.UnlockTheme then
        CG.Tetris:UnlockTheme(reward.tetrisThemeKey, "GAMES_BATTLEPASS", silent ~= false)
    end
end

function Pass:ClaimReward(level, silent)
    local save = self:Ensure()
    level = floor(clamp(level, 1, self.maxLevel))
    if not save then return false end
    if not self:IsLevelReached(level) then
        local needed = max(0, self:GetCumulativeXP(level) - save.xp)
        if not silent and CC.Print then CC:Print("Games Battle Pass Level " .. level .. " needs " .. formatNumber(needed) .. " more points.") end
        return false
    end
    local key = tostring(level)
    if save.claimed[key] then return false end
    local reward = self:GetReward(level)
    save.claimed[key] = true
    self:AddCoins(reward.coins, "PASS")
    grantGameReward(reward, silent)
    save.recent = { text = "Level " .. level .. " unlocked", coins = reward.coins, deck = reward.deckKey, at = now() }
    if not silent then
        self:RefreshWindow()
        if CG.SoloGames and CG.SoloGames.RefreshTetrisPanels then CG.SoloGames:RefreshTetrisPanels(true) end
        if CC.UI and CC.UI.ShowGameToast then
            local detail = "+" .. tostring(reward.coins or 0) .. " Cresh Coins"
            if reward.deckName then detail = detail .. " -- " .. reward.deckName .. " deck unlocked" end
            if reward.tetrisThemeName then detail = detail .. " -- " .. reward.tetrisThemeName .. " Tetris set unlocked" end
            CC.UI:ShowGameToast("Games Battle Pass reward unlocked", "Level " .. level .. " -- " .. detail, "SUCCESS", "GBP:CLAIM:" .. tostring(level))
        end
    end
    return true
end

function Pass:ClaimAllAvailable()
    local claimed, total = 0, 0
    for level = 1, self.maxLevel do
        if self:IsLevelReached(level) and not self:IsRewardClaimed(level) then
            local reward = self:GetReward(level)
            if self:ClaimReward(level, true) then
                claimed = claimed + 1
                total = total + reward.coins
            end
        end
    end
    self:RefreshWindow()
    return claimed, total
end

-- ---------------------------------------------------------------------------
-- Minimal window: current level/progress, and the next few upcoming rewards
-- with claim buttons. Not a clone of CreshCollect's 200-level browser --
-- deliberately small, since this pass only has 50 levels.
-- ---------------------------------------------------------------------------
local function templateName()
    return _G.BackdropTemplateMixin and "BackdropTemplate" or nil
end

local COLORS = {
    panel = { 0.022, 0.026, 0.034, 0.98 },
    panelRaised = { 0.066, 0.074, 0.092, 1 },
    border = { 0.105, 0.120, 0.145, 1 },
    accent = { 0.130, 0.620, 0.950, 1 },
    text = { 0.93, 0.95, 0.98, 1 },
    muted = { 0.56, 0.61, 0.69, 1 },
    green = { 0.18, 0.78, 0.36, 1 },
    gold = { 0.95, 0.70, 0.20, 1 },
}

local function applyBackdrop(frame, color, border)
    if not frame then return end
    if frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        frame:SetBackdropColor(color[1], color[2], color[3], color[4] or 1)
        frame:SetBackdropBorderColor((border or COLORS.border)[1], (border or COLORS.border)[2], (border or COLORS.border)[3], 1)
    end
end

local function createFont(parent, size, color, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetFont(_G.STANDARD_TEXT_FONT, size or 12, "")
    color = color or COLORS.text
    fs:SetTextColor(color[1], color[2], color[3], color[4] or 1)
    fs:SetJustifyH(justify or "LEFT")
    return fs
end

function Pass:BuildWindow()
    if self.window then return self.window end
    local frame = CreateFrame("Frame", "CreshGamesBattlePassWindow", UIParent, templateName())
    frame:SetSize(360, 220)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("HIGH")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    applyBackdrop(frame, COLORS.panel)
    frame:Hide()

    frame.title = createFont(frame, 15, COLORS.text, "CENTER")
    frame.title:SetPoint("TOP", frame, "TOP", 0, -12)
    frame.title:SetText("Games Battle Pass")

    frame.close = CreateFrame("Button", nil, frame, templateName())
    frame.close:SetSize(20, 20)
    frame.close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -6)
    applyBackdrop(frame.close, COLORS.panelRaised)
    frame.close.label = createFont(frame.close, 12, COLORS.text, "CENTER")
    frame.close.label:SetAllPoints()
    frame.close.label:SetText("X")
    frame.close:SetScript("OnClick", function() frame:Hide() end)

    frame.levelText = createFont(frame, 13, COLORS.gold, "CENTER")
    frame.levelText:SetPoint("TOP", frame.title, "BOTTOM", 0, -10)

    frame.bar = CreateFrame("StatusBar", nil, frame)
    frame.bar:SetSize(320, 16)
    frame.bar:SetPoint("TOP", frame.levelText, "BOTTOM", 0, -10)
    frame.bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    frame.bar:SetStatusBarColor(COLORS.accent[1], COLORS.accent[2], COLORS.accent[3], 1)
    frame.barBG = frame.bar:CreateTexture(nil, "BACKGROUND")
    frame.barBG:SetAllPoints()
    frame.barBG:SetColorTexture(COLORS.panelRaised[1], COLORS.panelRaised[2], COLORS.panelRaised[3], 1)
    frame.barText = createFont(frame.bar, 11, COLORS.text, "CENTER")
    frame.barText:SetAllPoints()

    frame.coinsText = createFont(frame, 12, COLORS.muted, "CENTER")
    frame.coinsText:SetPoint("TOP", frame.bar, "BOTTOM", 0, -10)

    frame.nextRewardText = createFont(frame, 11, COLORS.muted, "CENTER")
    frame.nextRewardText:SetPoint("TOP", frame.coinsText, "BOTTOM", 0, -10)
    frame.nextRewardText:SetWidth(320)

    frame.claimButton = CreateFrame("Button", nil, frame, templateName())
    frame.claimButton:SetSize(160, 26)
    frame.claimButton:SetPoint("BOTTOM", frame, "BOTTOM", 0, 14)
    applyBackdrop(frame.claimButton, COLORS.green)
    frame.claimButton.label = createFont(frame.claimButton, 12, COLORS.text, "CENTER")
    frame.claimButton.label:SetAllPoints()
    frame.claimButton.label:SetText("Claim Available Rewards")
    frame.claimButton:SetScript("OnClick", function() self:ClaimAllAvailable() end)

    self.window = frame
    return frame
end

function Pass:RefreshWindow()
    local frame = self.window
    if not frame or not frame:IsShown() then return end
    local level, current, required, _ = self:GetProgress()
    frame.levelText:SetText("Level " .. level .. " / " .. self.maxLevel)
    frame.bar:SetMinMaxValues(0, max(1, required))
    frame.bar:SetValue(current)
    frame.barText:SetText(formatNumber(current) .. " / " .. formatNumber(required) .. " Pass Points")
    local save = self:Ensure()
    frame.coinsText:SetText(formatNumber(save and save.coins or 0) .. " Cresh Coins")

    local claimable = 0
    local nextLevel, nextReward
    for l = 1, self.maxLevel do
        if self:IsLevelReached(l) and not self:IsRewardClaimed(l) then claimable = claimable + 1 end
        if not nextLevel and not self:IsRewardClaimed(l) and (self.gameRewardCatalog[l] or l % 5 == 0) then
            nextLevel, nextReward = l, self:GetReward(l)
        end
    end
    if nextReward then
        local extra = ""
        if nextReward.deckName then extra = " -- " .. nextReward.deckName .. " deck" end
        if nextReward.tetrisThemeName then extra = extra .. " -- " .. nextReward.tetrisThemeName .. " Tetris set" end
        frame.nextRewardText:SetText("Next: Level " .. nextLevel .. " -- " .. nextReward.coins .. " coins" .. extra)
    else
        frame.nextRewardText:SetText("")
    end
    frame.claimButton:SetShown(claimable > 0)
end

function Pass:ToggleWindow()
    local frame = self:BuildWindow()
    if frame:IsShown() then frame:Hide(); return end
    frame:Show()
    self:RefreshWindow()
end

function Pass:IsWindowOpen()
    return self.window and self.window:IsShown() == true
end
