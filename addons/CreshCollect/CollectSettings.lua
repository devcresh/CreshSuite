local addonName, COL = ...
if not COL then return end

-- Deferred CC access
local CC = setmetatable({}, { __index = function(_, k)
    local c = _G.CreshChat; return c and c[k]
end })

local function colDB() return _G.CreshCollectDB end

local function countTable(t)
    local n = 0
    if type(t) == "table" then for _ in pairs(t) do n = n + 1 end end
    return n
end

local Suite = _G.CreshSuite
if not Suite then return end

Suite:RegisterSettingsProvider("CreshCollect", {
    pages = {
        {
            key      = "TRACKING",
            label    = "Tracking",
            desc     = "Exploration, combat and world-event tracking. Live totals live in the Progress Hub, not here.",
            keywords = "progress hub exploration combat world zones steps",
            build = function(b)
                b:Section("Progress Hub")
                if COL.ProgressHub then
                    b:Buttons({
                        { "OPEN PROGRESS HUB", function() COL.ProgressHub:Toggle() end, 170 },
                    })
                    b:Note("Exploration progress, zone visits, quest completions and combat statistics all live in the Progress Hub.")
                else
                    b:Note("Progress Hub module is not loaded.")
                end
                b:Section("Tracking status")
                local db  = colDB()
                local exp = db and db.gameProgression and db.gameProgression.exploration
                if COL.CombatTracker then
                    b:Note("Combat tracking is active and feeding Progress Hub totals.")
                else
                    b:Note("CombatTracker module is not loaded.")
                end
                if exp then
                    b:Note("Total steps: " .. tostring(exp.totalSteps or 0) .. "  \194\183  New zones: " .. tostring(exp.newZones or 0) .. "  \194\183  Dungeon clears: " .. tostring(exp.dungeonClears or 0))
                else
                    b:Note("No exploration data yet. Play with CreshCollect loaded to begin tracking.")
                end
            end,
        },
        {
            key      = "ACHIEVEMENTS",
            label    = "Achievements",
            desc     = "WoW achievement tracking. CreshGames and Dungeon Dweller achievements live in CreshGames' own Achievements panel.",
            keywords = "achievements unlocked points",
            build = function(b)
                local db  = colDB()
                local ach = db and db.achievements
                b:Section("Achievements")
                if COL.Achievements then
                    b:Buttons({
                        { "OPEN ACHIEVEMENTS", function() COL.Achievements:ToggleWindow() end, 170 },
                    })
                end
                if ach and COL.Achievements then
                    local unlocked, total = COL.Achievements:GetCounts()
                    b:Note("World achievements unlocked: " .. tostring(unlocked) .. " / " .. tostring(total))
                else
                    b:Note("No achievement data yet. Play with CreshCollect loaded to begin tracking.")
                end
                b:Note("Cresh Games and Dungeon Dwellers achievements moved to CreshGames' own Achievements panel.")
            end,
        },
        {
            key      = "CHRONICLE",
            label    = "Chronicle & Collections",
            desc     = "Azeroth Chronicle progress and cosmetic unlock counts. The full browsable catalogue lives in CreshGames' Unlocks tab.",
            keywords = "battlepass chronicle currency coins collections themes cardDecks armour cosmetics",
            build = function(b)
                local db  = colDB()
                local arc = db and db.arcadeRewards
                local col = db and db.collections
                b:Section("Azeroth Chronicle")
                if COL.BattlePass then
                    -- Phase 6 bug fix: this used to check COL.BattlePass.Open,
                    -- a method that does not exist on this module (only
                    -- OpenWindow does) -- the button always silently fell
                    -- through to the CC.UI drawer fallback below.
                    b:Buttons({
                        { "OPEN AZEROTH CHRONICLE", function() COL.BattlePass:OpenWindow() end, 190 },
                    })
                else
                    b:Note("Azeroth Chronicle module is not loaded.")
                end
                if arc then
                    local claimedCount = 0
                    if type(arc.claimed) == "table" then for _ in pairs(arc.claimed) do claimedCount = claimedCount + 1 end end
                    b:Note("Pass XP earned: " .. tostring(arc.passXP or 0) .. "  \194\183  Level rewards claimed: " .. tostring(claimedCount))
                    b:Note("Cresh Coins: " .. tostring(arc.coins or 0) .. " current  \194\183  " .. tostring(arc.lifetimeCoins or 0) .. " lifetime  \194\183  " .. tostring(arc.spentCoins or 0) .. " spent")
                else
                    b:Note("No Azeroth Chronicle data yet. Explore Azeroth and complete achievements with CreshCollect loaded.")
                end

                b:Section("Collections")
                if col then
                    local themes  = countTable(col.themes) + countTable(col.backgrounds)
                    local other   = countTable(col.cardDecks) + countTable(col.dungeonArmour) + countTable(col.cosmetics)
                    b:Note("Themes/backgrounds unlocked: " .. tostring(themes) .. "  \194\183  Card decks/armour/other cosmetics: " .. tostring(other))
                    b:Note("The full browsable catalogue (with search, filters and requirements) is in CreshGames \226\134\146 Unlocks. Counts here are synced from CreshGames and never duplicated or overwritten.")
                else
                    b:Note("No collection data yet. Earn Cresh Coins and complete Azeroth Chronicle levels to unlock cosmetics.")
                end
            end,
        },
        {
            key      = "NOTIFICATIONS",
            label    = "Notifications",
            desc     = "CreshCollect notification card categories. Requires CreshChat.",
            keywords = "notifications cards sound alerts",
            build = function(b)
                local ccObj = _G.CreshChat
                b:Section("CreshCollect notification cards")
                if not ccObj or not ccObj.Notifications then
                    b:Note("CreshChat is not loaded. Load CreshChat alongside CreshCollect to configure notification card display.")
                    return
                end
                local cats     = ccObj.Notifications:GetRegisteredCategories("CRESHCOLLECT")
                local catOrder = {}
                for catKey in pairs(cats) do catOrder[#catOrder + 1] = catKey end
                table.sort(catOrder)
                if #catOrder == 0 then
                    b:Note("No CreshCollect notification categories are registered yet. Log in with CreshCollect loaded to register them.")
                    return
                end
                for _, catKey in ipairs(catOrder) do
                    local info = cats[catKey]
                    local cCat = catKey
                    b:HalfToggle(info.label,
                        function()
                            local s = ccObj.db and ccObj.db.notificationSources and ccObj.db.notificationSources.CRESHCOLLECT
                            return not s or s[cCat] ~= false
                        end,
                        function(v)
                            ccObj.db.notificationSources = ccObj.db.notificationSources or {}
                            ccObj.db.notificationSources.CRESHCOLLECT = ccObj.db.notificationSources.CRESHCOLLECT or {}
                            ccObj.db.notificationSources.CRESHCOLLECT[cCat] = v and true or false
                        end)
                end
                b:Note("These control which CreshCollect event types show as notification cards in CreshChat. Master card visibility is set in CreshChat Settings \226\134\146 Notifications.")
            end,
        },
        {
            key      = "ADVANCED",
            label    = "Advanced",
            desc     = "Permanently reset CreshCollect data. Cannot be undone.",
            keywords = "reset advanced delete achievements collections",
            build = function(b)
                b:Section("Reset collection data")
                b:Note("WARNING: The buttons below permanently delete CreshCollect data. CreshChat settings, chat history and CreshGames data are not affected.")
                b:Buttons({
                    { "RESET ACHIEVEMENTS", function()
                        b:ConfirmAction(
                            "Permanently delete all tracked CreshCollect achievement records, then reload the UI?\n\nThis cannot be undone.",
                            function()
                                local db = colDB()
                                if db then
                                    db.achievements  = nil
                                    db.ddAchievements = nil
                                    if _G.ReloadUI then _G.ReloadUI() end
                                end
                            end)
                    end, 170 },
                })
                b:Note("Clears all tracked achievement records. A UI reload follows to reinitialise the database.")
                b:Buttons({
                    { "RESET COLLECTIONS", function()
                        b:ConfirmAction(
                            "Permanently delete all CreshCollect cosmetic-unlock records?\n\nUnlocks can be re-earned by playing games. This cannot be undone.",
                            function()
                                local db = colDB()
                                if db then
                                    db.collections = nil
                                    if _G.ReloadUI then _G.ReloadUI() end
                                end
                            end)
                    end, 170 },
                })
                b:Note("Clears all cosmetic unlock records. Unlocks can be re-earned by playing games.")
                b:Buttons({
                    { "RESET LAUNCHER PREFS", function()
                        local db = colDB()
                        if db then db.launcher = { showAchievements = false, showProgress = false } end
                    end, 180 },
                })
                b:Note("Resets only the Achievements and Progress Hub launcher button preferences back to hidden.")
            end,
        },
    },
})
