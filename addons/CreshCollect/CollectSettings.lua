local addonName, COL = ...
if not COL then return end

-- Deferred CC access
local CC = setmetatable({}, { __index = function(_, k)
    local c = _G.CreshChat; return c and c[k]
end })

local function colDB() return _G.CreshCollectDB end

local Suite = _G.CreshSuite
if not Suite then return end

Suite:RegisterSettingsProvider("CreshCollect", {
    pages = {
        {
            key   = "PROGRESS",
            label = "Progress Hub",
            desc  = "Exploration, zone discovery and overall progression tracking.",
            build = function(b)
                b:Section("Progress Hub")
                if COL.ProgressHub then
                    b:Buttons({
                        { "OPEN PROGRESS HUB", function() COL.ProgressHub:Toggle() end, 170 },
                    })
                    b:Note("The Progress Hub shows exploration progress, zone visits, quest completions and combat statistics collected by CreshCollect.")
                else
                    b:Note("Progress Hub module is not loaded.")
                end
                b:Section("Exploration tracking")
                local db   = colDB()
                local exp  = db and db.gameProgression and db.gameProgression.exploration
                if exp then
                    b:Note("Total steps: " .. tostring(exp.totalSteps or 0) .. "  \xc2\xb7  New areas: " .. tostring(exp.newAreas or 0) .. "  \xc2\xb7  New zones: " .. tostring(exp.newZones or 0))
                    b:Note("Dungeon clears: " .. tostring(exp.dungeonClears or 0) .. "  \xc2\xb7  Total kills: " .. tostring(exp.totalKills or 0))
                else
                    b:Note("No exploration data yet. Play with CreshCollect loaded to begin tracking.")
                end
            end,
        },
        {
            key   = "ACHIEVEMENTS",
            label = "Achievements",
            desc  = "WoW achievement tracking and class challenge records.",
            build = function(b)
                local db  = colDB()
                local ach = db and db.achievements
                b:Section("Achievement summary")
                if ach then
                    local count = 0
                    if type(ach.unlocked) == "table" then for _ in pairs(ach.unlocked) do count = count + 1 end end
                    b:Note("Achievements tracked: " .. tostring(count))
                    b:Note("Lifetime Pass XP from achievements: " .. tostring(ach.totalPassXP or 0))
                    b:Note("Lifetime Cresh Coins from achievements: " .. tostring(ach.totalCoins or 0))
                else
                    b:Note("No achievement data yet. Play with CreshCollect loaded to begin tracking.")
                end
                b:Section("Dungeon achievements")
                local ddA = db and db.ddAchievements
                if ddA then
                    local ddCount = 0
                    if type(ddA.unlocked) == "table" then for _ in pairs(ddA.unlocked) do ddCount = ddCount + 1 end end
                    b:Note("Dungeon achievements unlocked: " .. tostring(ddCount))
                else
                    b:Note("No Dungeon Dwellers achievement data yet.")
                end
            end,
        },
        {
            key   = "BATTLEPASS",
            label = "Battle Pass",
            desc  = "Battle Pass progress, XP and level reward history.",
            build = function(b)
                local db  = colDB()
                local arc = db and db.arcadeRewards
                b:Section("Battle Pass progress")
                if arc then
                    b:Note("Pass XP earned: " .. tostring(arc.passXP or 0))
                    local claimedCount = 0
                    if type(arc.claimed) == "table" then for _ in pairs(arc.claimed) do claimedCount = claimedCount + 1 end end
                    b:Note("Level rewards claimed: " .. tostring(claimedCount))
                else
                    b:Note("No Battle Pass data yet. Play games and complete activities with CreshCollect loaded.")
                end
                b:Section("Actions")
                if COL.BattlePass then
                    b:Buttons({
                        { "OPEN BATTLE PASS", function()
                            if COL.BattlePass.Open then COL.BattlePass:Open()
                            elseif CC.UI and CC.UI.OpenGameDrawer then CC.UI:OpenGameDrawer("BATTLEPASS") end
                        end, 160 },
                    })
                else
                    b:Note("Battle Pass module is not loaded.")
                end
            end,
        },
        {
            key   = "CURRENCY",
            label = "Currency",
            desc  = "Cresh Coin balance, lifetime earnings and spending history.",
            build = function(b)
                local db  = colDB()
                local arc = db and db.arcadeRewards
                b:Section("Cresh Coins")
                if arc then
                    b:Note("Current balance: " .. tostring(arc.coins or 0))
                    b:Note("Lifetime earned: " .. tostring(arc.lifetimeCoins or 0) .. "  \xc2\xb7  Spent: " .. tostring(arc.spentCoins or 0))
                    b:Section("Coin sources")
                    b:Note("From games: " .. tostring(arc.gameCoins or 0))
                    b:Note("From activities: " .. tostring(arc.activityCoins or 0))
                    b:Note("From exploration: " .. tostring(arc.explorationCoins or 0))
                    if (arc.gamesRewarded or 0) > 0 then
                        b:Note("Games with coin rewards: " .. tostring(arc.gamesRewarded))
                    end
                else
                    b:Note("No currency data yet. Earn Cresh Coins by playing games and completing activities.")
                end
            end,
        },
        {
            key   = "COLLECTIONS",
            label = "Collections",
            desc  = "Cosmetic unlocks: themes, card decks, dungeon armour and more.",
            build = function(b)
                local db  = colDB()
                local col = db and db.collections
                b:Section("Cosmetic unlocks")
                if col then
                    local function countTable(t) local n = 0; if type(t) == "table" then for _ in pairs(t) do n = n + 1 end end; return n end
                    b:Note("Themes: "        .. tostring(countTable(col.themes)))
                    b:Note("Backgrounds: "   .. tostring(countTable(col.backgrounds)))
                    b:Note("Card decks: "    .. tostring(countTable(col.cardDecks)))
                    b:Note("Dungeon armour: " .. tostring(countTable(col.dungeonArmour)))
                    b:Note("Other cosmetics: " .. tostring(countTable(col.cosmetics)))
                else
                    b:Note("No collection data yet. Earn Cresh Coins and complete Battle Pass levels to unlock cosmetics.")
                end
                b:Note("Unlocks are synced from CreshGames via the CreshSuite event bus and are never duplicated or overwritten.")
            end,
        },
        {
            key   = "COMBAT",
            label = "Combat",
            desc  = "Combat and world event tracking preferences.",
            build = function(b)
                b:Section("Combat tracking")
                if COL.CombatTracker then
                    b:Note("CombatTracker is active and logging combat events for Progress Hub statistics.")
                    b:Note("Combat data is stored in CreshCollect and contributes to Progress Hub totals and exploration rewards.")
                else
                    b:Note("CombatTracker module is not loaded.")
                end
                b:Section("World tracking")
                local db  = colDB()
                local exp = db and db.gameProgression and db.gameProgression.exploration
                if exp then
                    local visitedAreas = 0; if type(exp.visitedAreas) == "table" then for _ in pairs(exp.visitedAreas) do visitedAreas = visitedAreas + 1 end end
                    local visitedZones = 0; if type(exp.visitedZones) == "table" then for _ in pairs(exp.visitedZones) do visitedZones = visitedZones + 1 end end
                    b:Note("Visited areas: " .. tostring(visitedAreas) .. "  \xc2\xb7  Visited zones: " .. tostring(visitedZones))
                    b:Note("Dungeon clears tracked: " .. tostring(exp.dungeonClears or 0))
                else
                    b:Note("No world tracking data yet.")
                end
            end,
        },
        {
            key   = "NOTIFICATIONS",
            label = "Notifications",
            desc  = "CreshCollect notification card categories. Requires CreshChat.",
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
            key   = "RESET",
            label = "Reset",
            desc  = "Permanently reset CreshCollect data. Cannot be undone.",
            build = function(b)
                b:Section("Reset collection data")
                b:Note("WARNING: The buttons below permanently delete CreshCollect data. CreshChat settings, chat history and CreshGames data are not affected.")
                b:Buttons({
                    { "RESET ACHIEVEMENTS", function()
                        local db = colDB()
                        if db then
                            db.achievements  = nil
                            db.ddAchievements = nil
                            if _G.ReloadUI then _G.ReloadUI() end
                        end
                    end, 170 },
                })
                b:Note("Clears all tracked achievement records. A UI reload follows to reinitialise the database.")
                b:Buttons({
                    { "RESET COLLECTIONS", function()
                        local db = colDB()
                        if db then
                            db.collections = nil
                            if _G.ReloadUI then _G.ReloadUI() end
                        end
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
