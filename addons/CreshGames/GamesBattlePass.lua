-- CreshGames/GamesBattlePass.lua
-- CreshGames' own Arcade Battle Pass: one global, account-wide, 100-level
-- pass earning Cresh Coins and Pass XP exclusively from CreshGames activity
-- (game starts, completed results, achievement completions, per-game
-- Mastery level-ups -- see AwardGameStart/AwardGameResult/
-- AwardAchievementCompletion/AwardMasteryLevelUp below), and granting
-- exclusively game-owned rewards (card decks, Tetris themes, spendable Cresh
-- Coins). Deliberately separate from CreshCollect's own 200-level Battle
-- Pass (soon "Azeroth Chronicle"), which stays fed by achievements/
-- exploration/quests and keeps its own reward catalog (world/chat themes)
-- untouched -- neither pass ever funds the other.
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
    maxLevel = 100,
}
CG.BattlePass = Pass
if CG.RegisterModule then CG:RegisterModule("BattlePass", Pass) end

local floor, min, max = math.floor, math.min, math.max

-- Rework Phase 3: every previously-scattered numeric constant lives here
-- instead, so pacing can be retuned in one place (and the pacing report in
-- Docs/PHASE3_ARCADE_PASS_PACING.md can be regenerated from it).
Pass.balance = {
    -- Leveling curve: GetNextLevelCost(level) = xpBaseCost + (level-1)*xpCostPerLevel
    xpBaseCost = 50,
    xpCostPerLevel = 5,

    -- Direct XP sources (do not require a per-game Mastery level-up first)
    xpGameStart = 5,
    xpGameStartMultiplayerBonus = 5,
    xpGameStartCooldownSeconds = 30, -- anti-farm: repeat "start" XP for the same game within this window is not paid again
    xpCompleteBase = 10,
    xpCompleteWin = 30,
    xpCompleteDraw = 20,
    xpCompleteLoss = 15,
    xpCompleteRunScorePer = 250,     -- RUN-type results: + floor(score / this) XP
    xpCompleteRunScoreCap = 20,
    xpMultiplayerMultiplier = 2,
    xpScoreMilestoneStep = 500,      -- any result: + xpScoreMilestoneAmount per this many score points
    xpScoreMilestoneAmount = 5,
    xpScoreMilestoneCap = 25,
    xpAchievementUnlock = 15,        -- per CreshGames-category achievement completion
    xpMasteryLevelUp = 20,           -- per Tetris/Dungeon Mastery pass level gained

    -- Coin reward rhythm (levels 1-50 additionally carry the fixed card-deck/
    -- Tetris-theme grants in gameRewardCatalog below; every level of the full
    -- 1-100 range also gets a tier-based coin payout from this table)
    coinsNormal = 20,
    coinsNormalLevelStep = 2,
    coinsGuaranteed = 60,       -- every 5th level
    coinsCollectionChoice = 100, -- every 10th level
    coinsMajorBundle = 250,     -- levels 25, 50, 75
    coinsCapstone = 750,        -- level 100

    -- Fallback payout if a deck-reward level's target deck AND every other
    -- premium deck are already owned -- keeps the reward slot from ever
    -- paying out nothing.
    deckVoucherFallbackCoins = 50,

    -- Ring-buffer cap for the duplicate-result-submission guard.
    recentResultIdCap = 200,
}

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
    -- Levels 51-100 (Rework Phase 3: expanded from a 50-level to a 100-level pass)
    "Rally Point", "Second Wind", "High Score Hunter", "Combo Breaker", "Vault Cache",
    "Speed Runner", "Precision Player", "Iron Nerve", "Clutch Caller", "Collector's Cache",
    "Marathon Gamer", "Streak Master", "Tactical Mind", "Bluff Master", "Jackpot Cache",
    "Line Clearer", "Combo Architect", "Endgame Tactician", "Rivalry Veteran", "Champion's Cache",
    "Arcade Veteran", "Board Sage", "Card Sharp Elite", "Dungeon Warden", "Grand Bundle Cache",
    "Perfect Streaker", "Tetromino Master", "Table Legend", "Dice Whisperer", "Vanguard Cache",
    "Multiplayer Ace", "Solo Grinder", "Puzzle Sage", "Room Conqueror", "Diamond Cache",
    "Board Room Legend", "Chess Grandmaster", "Card Table Icon", "Boss Slayer", "Titanium Cache",
    "Cresh Veteran", "Arcade Sage", "Ultimate Rival", "Dungeon Legend", "Platinum Vault Cache",
    "Grand Strategist", "Perfect Record", "Cresh Grandmaster", "Arcade Paragon", "Arcade Champion",
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
    -- Rework Phase 3: anti-farm and duplicate-submission guards for the new
    -- direct XP sources (AwardGameStart/AwardGameResult below).
    save.startCooldowns = type(save.startCooldowns) == "table" and save.startCooldowns or {}
    save.recentResultIds = type(save.recentResultIds) == "table" and save.recentResultIds or {}
    save.arcadeChampion = save.arcadeChampion == true
    return save
end

-- Same closed-form leveling curve as CreshCollect's Battle Pass (proven
-- math, reused for consistency), parameterized by Pass.balance.
function Pass:GetNextLevelCost(level)
    level = floor(clamp(level, 1, self.maxLevel))
    local b = self.balance
    return b.xpBaseCost + ((level - 1) * b.xpCostPerLevel)
end

function Pass:GetCumulativeXP(level)
    level = floor(clamp(level, 1, self.maxLevel))
    local b = self.balance
    local completed = level - 1
    return completed * b.xpBaseCost + (b.xpCostPerLevel * completed * (completed - 1)) / 2
end

-- Closed-form inverse of GetCumulativeXP, i.e. the quadratic solution of
-- xp = xpBaseCost*n + (xpCostPerLevel/2)*n*(n-1) for n = level-1. The
-- constants below (9025 = 95^2, 40, 95, 10) are algebraically derived from
-- balance.xpBaseCost=50/xpCostPerLevel=5 specifically -- if either of those
-- two balance values ever changes, these must be re-derived to match (the
-- while loops below are a safety net that corrects small drift, but a large
-- constant mismatch would make every GetLevelFromXP call loop needlessly).
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
    if not save then return 1, 0, self.balance.xpBaseCost, 0 end
    local level = self:GetLevelFromXP(save.xp)
    local base = self:GetCumulativeXP(level)
    if level >= self.maxLevel then return level, 1, 1, 1 end
    local required = self:GetNextLevelCost(level)
    local current = max(0, save.xp - base)
    return level, current, required, clamp(current / max(1, required), 0, 1)
end

-- Reward rhythm (Rework Phase 3): every level pays coins; every 5th level is
-- a guaranteed bonus; every 10th is a bigger "collection choice" bonus;
-- levels 25/50/75 are major bundles; level 100 is the capstone. Independent
-- of this, levels 1-50 additionally carry the fixed card-deck/Tetris-theme
-- grants in gameRewardCatalog (unchanged from before this pass's expansion).
function Pass:GetRewardTier(level)
    if level == self.maxLevel then return "CAPSTONE" end
    if level == 25 or level == 50 or level == 75 then return "MAJOR_BUNDLE" end
    if level % 10 == 0 then return "COLLECTION_CHOICE" end
    if level % 5 == 0 then return "GUARANTEED" end
    return "NORMAL"
end

function Pass:GetReward(level)
    level = floor(clamp(level, 1, self.maxLevel))
    local b = self.balance
    local tier = self:GetRewardTier(level)
    local coins
    if tier == "CAPSTONE" then coins = b.coinsCapstone
    elseif tier == "MAJOR_BUNDLE" then coins = b.coinsMajorBundle
    elseif tier == "COLLECTION_CHOICE" then coins = b.coinsCollectionChoice
    elseif tier == "GUARANTEED" then coins = b.coinsGuaranteed
    else coins = b.coinsNormal + floor((level - 1) / 5) * b.coinsNormalLevelStep end
    local gameReward = self.gameRewardCatalog[level] or {}
    return {
        level = level, coins = coins, tier = tier,
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
            CG:ShowBattlePassToast("Games Battle Pass Level " .. newLevel, detail, "SUCCESS", "GBP:LEVEL:" .. tostring(newLevel))
        end
    end
    return amount, previousLevel, newLevel
end

-- ---------------------------------------------------------------------------
-- Rework Phase 3: direct XP sources. Unlike per-game Mastery XP
-- (GameProgression.lua), Arcade Pass XP never requires a per-game level-up
-- first -- every source below pays into this pass's own save.xp directly.
-- ---------------------------------------------------------------------------

-- "Valid game start" source. Anti-farmed: a repeat start for the same game
-- within xpGameStartCooldownSeconds pays no further XP, so rapidly
-- starting/abandoning a game cannot be used to grind XP.
function Pass:AwardGameStart(game, mode, silent)
    local save = self:Ensure()
    if not save then return 0 end
    local b = self.balance
    game = string.upper(tostring(game or "GAME"))
    local last = tonumber(save.startCooldowns[game]) or 0
    if now() - last < b.xpGameStartCooldownSeconds then return 0 end
    save.startCooldowns[game] = now()
    local amount = b.xpGameStart
    mode = string.upper(tostring(mode or "SOLO"))
    if mode == "MULTIPLAYER" or mode == "MULTI" then amount = amount + b.xpGameStartMultiplayerBonus end
    return self:AddXP(amount, "GAME_START", silent)
end

-- "Completed game" / "win, loss or draw" / "score milestones" / "multiplayer
-- completion" sources, all in one call: every one of those is a property of
-- a single completed-game `entry` (the same shape GameProgression:
-- OnGameCompleted receives). Guards against duplicate submission of the
-- exact same result via a persisted, capped ring buffer of recent result
-- ids -- unlike Games.lua's in-memory-only multiplayer dedup, this survives
-- reload and covers solo results too.
function Pass:AwardGameResult(entry, silent)
    local save = self:Ensure()
    if not save or type(entry) ~= "table" then return 0 end
    local b = self.balance

    local resultId = table.concat({
        tostring(entry.game), tostring(entry.mode), tostring(entry.result),
        tostring(entry.score or 0), tostring(entry.timestamp or now()),
    }, ":")
    if save.recentResultIds[resultId] then return 0 end
    save.recentResultIds[resultId] = now()
    local count = 0
    for _ in pairs(save.recentResultIds) do count = count + 1 end
    if count > b.recentResultIdCap then
        local oldestId, oldestAt
        for id, at in pairs(save.recentResultIds) do
            if not oldestAt or at < oldestAt then oldestId, oldestAt = id, at end
        end
        if oldestId then save.recentResultIds[oldestId] = nil end
    end

    local result = string.upper(tostring(entry.result or "RUN"))
    local amount = b.xpCompleteBase
    if result == "WIN" then amount = b.xpCompleteWin
    elseif result == "DRAW" then amount = b.xpCompleteDraw
    elseif result == "LOSS" then amount = b.xpCompleteLoss
    elseif result == "RUN" then
        amount = b.xpCompleteBase + min(b.xpCompleteRunScoreCap, floor((tonumber(entry.score) or 0) / b.xpCompleteRunScorePer))
    end
    local mode = string.upper(tostring(entry.mode or "SOLO"))
    if mode == "MULTIPLAYER" or mode == "MULTI" then amount = amount * b.xpMultiplayerMultiplier end

    local score = tonumber(entry.score) or 0
    if score > 0 then
        amount = amount + min(b.xpScoreMilestoneCap, floor(score / b.xpScoreMilestoneStep) * b.xpScoreMilestoneAmount)
    end

    return self:AddXP(amount, "GAME_RESULT", silent)
end

-- "Game achievement completion" source. Called directly by
-- GamesAchievements.lua's Unlock() -- same addon (Rework Phase 5 moved the
-- GAMES achievement category here from CreshCollect), no Suite hop needed.
-- Earlier (Phase 3-4), this fired via a Suite subscription to CreshCollect's
-- unlock notification, since CreshCollect owned that catalog at the time.
function Pass:AwardAchievementCompletion(silent)
    return self:AddXP(self.balance.xpAchievementUnlock, "ACHIEVEMENT", silent)
end

-- "Per-game Mastery milestones" source. Tetris' and Dungeon Dwellers' own
-- passes (Mastery tracks, Phase 4) call this directly on their own
-- level-ups -- same addon, no Suite hop needed.
function Pass:AwardMasteryLevelUp(silent)
    return self:AddXP(self.balance.xpMasteryLevelUp, "MASTERY", silent)
end

-- Grants a claimed level's game-owned reward directly (same addon now, no
-- Suite-API hop needed).
local function grantGameReward(reward, silent)
    if reward.deckKey and CG.CardDecks and CG.CardDecks.GrantDeckOrVoucher then
        if not CG.CardDecks:GrantDeckOrVoucher(reward.deckKey, "GAMES_BATTLEPASS", silent ~= false) then
            Pass:AddCoins(Pass.balance.deckVoucherFallbackCoins, "GAMES_BATTLEPASS:DECK_VOUCHER")
        end
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
    if reward.tier == "CAPSTONE" then save.arcadeChampion = true end
    save.recent = { text = "Level " .. level .. " unlocked", coins = reward.coins, deck = reward.deckKey, at = now() }
    local suite = _G.CreshSuite
    if suite and suite.Publish then
        suite:Publish("CRESHGAMES_REWARD_UNLOCKED", {
            source = "CRESHGAMES", level = level, coins = reward.coins,
            deckKey = reward.deckKey, tetrisThemeKey = reward.tetrisThemeKey,
        })
    end
    if not silent then
        self:RefreshWindow()
        if CG.SoloGames and CG.SoloGames.RefreshTetrisPanels then CG.SoloGames:RefreshTetrisPanels(true) end
        do
            local detail = "+" .. tostring(reward.coins or 0) .. " Cresh Coins"
            if reward.deckName then detail = detail .. " -- " .. reward.deckName .. " deck unlocked" end
            if reward.tetrisThemeName then detail = detail .. " -- " .. reward.tetrisThemeName .. " Tetris set unlocked" end
            CG:ShowBattlePassToast("Games Battle Pass reward unlocked", "Level " .. level .. " -- " .. detail, "SUCCESS", "GBP:CLAIM:" .. tostring(level))
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
    local uiSvc = _G.CreshSuiteUI
    if uiSvc and uiSvc.InstallWindowFocus then uiSvc:InstallWindowFocus(frame) end

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
