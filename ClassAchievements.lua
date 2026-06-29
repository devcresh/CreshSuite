local _, CC = ...
if not CC or not CC.Achievements then return end

local A = CC.Achievements
local ClassAchievements = { version = CC.version }
CC.ClassAchievements = ClassAchievements
if CC.RegisterModule then CC:RegisterModule("ClassAchievements", ClassAchievements) end

local floor, max = math.floor, math.max
local lower, upper = string.lower, string.upper

local CLASS_ACHIEVEMENTS = {
    { key="CLASS_DRUID_001", classToken="DRUID", title="Changing Shapes", description="Shapeshift 100 times.", tier=1, tierName="Bronze", coins=5, xp=5, metric="SHAPESHIFTS", goal=100 },
    { key="CLASS_DRUID_002", classToken="DRUID", title="Natural Adaptation", description="Shapeshift 1,000 times.", tier=2, tierName="Silver", coins=10, xp=10, metric="SHAPESHIFTS", goal=1000 },
    { key="CLASS_DRUID_003", classToken="DRUID", title="Nature's Rescuer", description="Successfully cast Rebirth on 10 dead players.", tier=2, tierName="Silver", coins=10, xp=10, metric="REBIRTHS", goal=10 },
    { key="CLASS_DRUID_004", classToken="DRUID", title="Guardian of the Fallen", description="Successfully cast Rebirth on 100 dead players.", tier=4, tierName="Epic", coins=35, xp=30, metric="REBIRTHS", goal=100 },
    { key="CLASS_DRUID_005", classToken="DRUID", title="Keeper's Gift", description="Cast Innervate on another player 50 times.", tier=3, tierName="Gold", coins=20, xp=18, metric="INNERVATE_OTHERS", goal=50 },
    { key="CLASS_DRUID_006", classToken="DRUID", title="Silent Predator", description="Open combat from Prowl 250 times.", tier=3, tierName="Gold", coins=20, xp=18, metric="PROWL_OPENS", goal=250 },
    { key="CLASS_DRUID_007", classToken="DRUID", title="Guardian of the Wild", description="Use Growl or Challenging Roar on 1,000 enemies.", tier=4, tierName="Epic", coins=35, xp=30, metric="DRUID_TAUNTS", goal=1000 },
    { key="CLASS_DRUID_008", classToken="DRUID", title="Life in Bloom", description="Cast Lifebloom or Swiftmend 1,000 times.", tier=4, tierName="Epic", coins=35, xp=30, metric="BLOOM_SWIFTMEND", goal=1000 },
    { key="CLASS_DRUID_009", classToken="DRUID", title="Master of Flight Form", description="Learn and use Flight Form in Outland.", tier=3, tierName="Gold", coins=20, xp=18, metric="FLIGHT_FORM", goal=1 },
    { key="CLASS_DRUID_010", classToken="DRUID", title="Archdruid of CreshChat", description="Complete 2,500 class-signature Druid actions across the account.", tier=5, tierName="Legendary", coins=60, xp=50, metric="SIGNATURE", goal=2500 },
    { key="CLASS_HUNTER_011", classToken="HUNTER", title="A Hunter's Companion", description="Tame your first hunter pet.", tier=1, tierName="Bronze", coins=5, xp=5, metric="UNIQUE_PETS", goal=1 },
    { key="CLASS_HUNTER_012", classToken="HUNTER", title="Stable Master", description="Tame 10 different pets.", tier=3, tierName="Gold", coins=20, xp=18, metric="UNIQUE_PETS", goal=10 },
    { key="CLASS_HUNTER_013", classToken="HUNTER", title="Always Prepared", description="Feed or Mend Pet 250 times.", tier=2, tierName="Silver", coins=10, xp=10, metric="PET_CARE", goal=250 },
    { key="CLASS_HUNTER_014", classToken="HUNTER", title="Feigning Expertise", description="Use Feign Death 250 times while in combat.", tier=3, tierName="Gold", coins=20, xp=18, metric="FEIGN_COMBAT", goal=250 },
    { key="CLASS_HUNTER_015", classToken="HUNTER", title="Trap Setter", description="Trigger 500 Freezing, Frost, Immolation, Explosive, or Snake Traps.", tier=3, tierName="Gold", coins=20, xp=18, metric="TRAPS", goal=500 },
    { key="CLASS_HUNTER_016", classToken="HUNTER", title="Perfect Distraction", description="Use Distracting Shot or Misdirection 250 times.", tier=4, tierName="Epic", coins=35, xp=30, metric="DISTRACTION", goal=250 },
    { key="CLASS_HUNTER_017", classToken="HUNTER", title="Command the Pack", description="Use Kill Command 1,000 times.", tier=4, tierName="Epic", coins=35, xp=30, metric="KILL_COMMAND", goal=1000 },
    { key="CLASS_HUNTER_018", classToken="HUNTER", title="Calming Shot", description="Remove 50 enemy enrages with Tranquilizing Shot.", tier=4, tierName="Epic", coins=35, xp=30, metric="TRANQ_DISPELS", goal=50 },
    { key="CLASS_HUNTER_019", classToken="HUNTER", title="Master Marksman", description="Land 5,000 ranged ability hits.", tier=4, tierName="Epic", coins=35, xp=30, metric="RANGED_HITS", goal=5000 },
    { key="CLASS_HUNTER_020", classToken="HUNTER", title="Huntmaster of CreshChat", description="Complete 5,000 class-signature Hunter actions across the account.", tier=5, tierName="Legendary", coins=60, xp=50, metric="SIGNATURE", goal=5000 },
    { key="CLASS_MAGE_021", classToken="MAGE", title="Refreshment Vendor", description="Conjure 500 food or water items.", tier=1, tierName="Bronze", coins=5, xp=5, metric="CONJURES", goal=500 },
    { key="CLASS_MAGE_022", classToken="MAGE", title="Portal Service", description="Open 100 portals for your group.", tier=3, tierName="Gold", coins=20, xp=18, metric="PORTALS", goal=100 },
    { key="CLASS_MAGE_023", classToken="MAGE", title="Seasoned Traveller", description="Teleport yourself 250 times.", tier=2, tierName="Silver", coins=10, xp=10, metric="TELEPORTS", goal=250 },
    { key="CLASS_MAGE_024", classToken="MAGE", title="Sheep Happens", description="Successfully Polymorph 500 enemies.", tier=3, tierName="Gold", coins=20, xp=18, metric="POLYMORPHS", goal=500 },
    { key="CLASS_MAGE_025", classToken="MAGE", title="Nothing to Cast", description="Successfully interrupt 250 spells with Counterspell.", tier=4, tierName="Epic", coins=35, xp=30, metric="COUNTERSPELL_INTERRUPTS", goal=250 },
    { key="CLASS_MAGE_026", classToken="MAGE", title="Borrowed Magic", description="Steal 100 beneficial effects with Spellsteal.", tier=4, tierName="Epic", coins=35, xp=30, metric="SPELLSTEALS", goal=100 },
    { key="CLASS_MAGE_027", classToken="MAGE", title="Now You See Me", description="Use Blink 500 times.", tier=2, tierName="Silver", coins=10, xp=10, metric="BLINKS", goal=500 },
    { key="CLASS_MAGE_028", classToken="MAGE", title="Cold Snap Survivor", description="Use Ice Block while below 25% health 25 times.", tier=3, tierName="Gold", coins=20, xp=18, metric="ICE_BLOCK_LOW", goal=25 },
    { key="CLASS_MAGE_029", classToken="MAGE", title="Arcane Recovery", description="Restore mana with Evocation 100 times.", tier=3, tierName="Gold", coins=20, xp=18, metric="EVOCATIONS", goal=100 },
    { key="CLASS_MAGE_030", classToken="MAGE", title="Archmage of CreshChat", description="Complete 5,000 class-signature Mage actions across the account.", tier=5, tierName="Legendary", coins=60, xp=50, metric="SIGNATURE", goal=5000 },
    { key="CLASS_PALADIN_031", classToken="PALADIN", title="A Blessing Upon You", description="Cast 500 Blessings on other players.", tier=1, tierName="Bronze", coins=5, xp=5, metric="BLESSINGS_OTHER", goal=500 },
    { key="CLASS_PALADIN_032", classToken="PALADIN", title="Keeper of Auras", description="Change active Aura 500 times.", tier=2, tierName="Silver", coins=10, xp=10, metric="AURAS", goal=500 },
    { key="CLASS_PALADIN_033", classToken="PALADIN", title="Clean Hands", description="Remove 500 harmful effects with Cleanse or Purify.", tier=3, tierName="Gold", coins=20, xp=18, metric="CLEANSES", goal=500 },
    { key="CLASS_PALADIN_034", classToken="PALADIN", title="A Final Miracle", description="Use Lay on Hands on a player below 20% health 25 times.", tier=4, tierName="Epic", coins=35, xp=30, metric="LAY_HANDS_LOW", goal=25 },
    { key="CLASS_PALADIN_035", classToken="PALADIN", title="Return to the Light", description="Resurrect 100 players with Redemption.", tier=3, tierName="Gold", coins=20, xp=18, metric="RESURRECTIONS", goal=100 },
    { key="CLASS_PALADIN_036", classToken="PALADIN", title="Protector's Challenge", description="Use Righteous Defense or Taunt effects 1,000 times.", tier=4, tierName="Epic", coins=35, xp=30, metric="PALADIN_TAUNTS", goal=1000 },
    { key="CLASS_PALADIN_037", classToken="PALADIN", title="Consecrated Ground", description="Damage 5,000 enemies with Consecration.", tier=4, tierName="Epic", coins=35, xp=30, metric="CONSECRATION_HITS", goal=5000 },
    { key="CLASS_PALADIN_038", classToken="PALADIN", title="Wings of Wrath", description="Use Avenging Wrath 250 times.", tier=3, tierName="Gold", coins=20, xp=18, metric="AVENGING_WRATH", goal=250 },
    { key="CLASS_PALADIN_039", classToken="PALADIN", title="Charger of the Light", description="Earn the Paladin epic class mount.", tier=4, tierName="Epic", coins=35, xp=30, metric="EPIC_MOUNT", goal=1 },
    { key="CLASS_PALADIN_040", classToken="PALADIN", title="Highlord of CreshChat", description="Complete 5,000 class-signature Paladin actions across the account.", tier=5, tierName="Legendary", coins=60, xp=50, metric="SIGNATURE", goal=5000 },
    { key="CLASS_PRIEST_041", classToken="PRIEST", title="Shield Bearer", description="Cast Power Word: Shield 1,000 times on other players.", tier=2, tierName="Silver", coins=10, xp=10, metric="SHIELDS_OTHER", goal=1000 },
    { key="CLASS_PRIEST_042", classToken="PRIEST", title="Faith Restored", description="Resurrect 100 players.", tier=3, tierName="Gold", coins=20, xp=18, metric="RESURRECTIONS", goal=100 },
    { key="CLASS_PRIEST_043", classToken="PRIEST", title="Purifying Light", description="Dispel 500 harmful effects from allies.", tier=3, tierName="Gold", coins=20, xp=18, metric="DISPELS", goal=500 },
    { key="CLASS_PRIEST_044", classToken="PRIEST", title="Chains of Faith", description="Successfully Shackle Undead 250 times.", tier=3, tierName="Gold", coins=20, xp=18, metric="SHACKLES", goal=250 },
    { key="CLASS_PRIEST_045", classToken="PRIEST", title="Borrowed Body", description="Successfully Mind Control 100 enemies or players.", tier=4, tierName="Epic", coins=35, xp=30, metric="MIND_CONTROLS", goal=100 },
    { key="CLASS_PRIEST_046", classToken="PRIEST", title="Prayer Answered", description="Cast Prayer of Mending 1,000 times.", tier=4, tierName="Epic", coins=35, xp=30, metric="PRAYER_MENDING", goal=1000 },
    { key="CLASS_PRIEST_047", classToken="PRIEST", title="Nothing Hidden", description="Successfully Mass Dispel 100 effects.", tier=4, tierName="Epic", coins=35, xp=30, metric="MASS_DISPELS", goal=100 },
    { key="CLASS_PRIEST_048", classToken="PRIEST", title="Fade Away", description="Use Fade 500 times while threatened by an enemy.", tier=2, tierName="Silver", coins=10, xp=10, metric="FADES_THREAT", goal=500 },
    { key="CLASS_PRIEST_049", classToken="PRIEST", title="Shadow's Companion", description="Summon Shadowfiend 250 times.", tier=3, tierName="Gold", coins=20, xp=18, metric="SHADOWFIENDS", goal=250 },
    { key="CLASS_PRIEST_050", classToken="PRIEST", title="High Priest of CreshChat", description="Complete 5,000 class-signature Priest actions across the account.", tier=5, tierName="Legendary", coins=60, xp=50, metric="SIGNATURE", goal=5000 },
    { key="CLASS_ROGUE_051", classToken="ROGUE", title="Light Fingers", description="Successfully Pick Pocket 250 enemies.", tier=2, tierName="Silver", coins=10, xp=10, metric="PICKPOCKETS", goal=250 },
    { key="CLASS_ROGUE_052", classToken="ROGUE", title="Master Locksmith", description="Open 250 locked boxes or doors.", tier=3, tierName="Gold", coins=20, xp=18, metric="LOCKS_OPENED", goal=250 },
    { key="CLASS_ROGUE_053", classToken="ROGUE", title="Quiet Please", description="Successfully Sap 500 targets.", tier=3, tierName="Gold", coins=20, xp=18, metric="SAPS", goal=500 },
    { key="CLASS_ROGUE_054", classToken="ROGUE", title="Not Today", description="Successfully interrupt 250 spells with Kick.", tier=4, tierName="Epic", coins=35, xp=30, metric="KICK_INTERRUPTS", goal=250 },
    { key="CLASS_ROGUE_055", classToken="ROGUE", title="Smoke and Shadows", description="Use Vanish 250 times while in combat.", tier=3, tierName="Gold", coins=20, xp=18, metric="VANISH_COMBAT", goal=250 },
    { key="CLASS_ROGUE_056", classToken="ROGUE", title="A Poisoned Blade", description="Apply poisons to weapons 500 times.", tier=2, tierName="Silver", coins=10, xp=10, metric="POISONS_APPLIED", goal=500 },
    { key="CLASS_ROGUE_057", classToken="ROGUE", title="Blinding Opportunity", description="Successfully Blind 250 targets.", tier=3, tierName="Gold", coins=20, xp=18, metric="BLINDS", goal=250 },
    { key="CLASS_ROGUE_058", classToken="ROGUE", title="Cloaked Escape", description="Use Cloak of Shadows to remove or avoid harmful magic 100 times.", tier=4, tierName="Epic", coins=35, xp=30, metric="CLOAKS", goal=100 },
    { key="CLASS_ROGUE_059", classToken="ROGUE", title="Perfect Finish", description="Use 5-combo-point finishing moves 1,000 times.", tier=4, tierName="Epic", coins=35, xp=30, metric="FIVE_POINT_FINISHERS", goal=1000 },
    { key="CLASS_ROGUE_060", classToken="ROGUE", title="Shadowmaster of CreshChat", description="Complete 5,000 class-signature Rogue actions across the account.", tier=5, tierName="Legendary", coins=60, xp=50, metric="SIGNATURE", goal=5000 },
    { key="CLASS_SHAMAN_061", classToken="SHAMAN", title="Totemic Beginning", description="Place 500 totems.", tier=1, tierName="Bronze", coins=5, xp=5, metric="TOTEMS", goal=500 },
    { key="CLASS_SHAMAN_062", classToken="SHAMAN", title="Totem Army", description="Place 5,000 totems.", tier=4, tierName="Epic", coins=35, xp=30, metric="TOTEMS", goal=5000 },
    { key="CLASS_SHAMAN_063", classToken="SHAMAN", title="Back on Your Feet", description="Use Reincarnation 25 times.", tier=3, tierName="Gold", coins=20, xp=18, metric="REINCARNATIONS", goal=25 },
    { key="CLASS_SHAMAN_064", classToken="SHAMAN", title="Purged Clean", description="Remove 250 beneficial enemy effects with Purge.", tier=3, tierName="Gold", coins=20, xp=18, metric="PURGES", goal=250 },
    { key="CLASS_SHAMAN_065", classToken="SHAMAN", title="Earth Says No", description="Interrupt 250 spells with Earth Shock.", tier=4, tierName="Epic", coins=35, xp=30, metric="EARTH_SHOCK_INTERRUPTS", goal=250 },
    { key="CLASS_SHAMAN_066", classToken="SHAMAN", title="Walking on Water", description="Cast Water Walking on players 250 times.", tier=2, tierName="Silver", coins=10, xp=10, metric="WATER_WALKING", goal=250 },
    { key="CLASS_SHAMAN_067", classToken="SHAMAN", title="Grounded", description="Absorb or redirect 100 hostile spells with Grounding Totem.", tier=4, tierName="Epic", coins=35, xp=30, metric="GROUNDING", goal=100 },
    { key="CLASS_SHAMAN_068", classToken="SHAMAN", title="No Fear Here", description="Break or prevent 100 fear, charm, or sleep effects with Tremor Totem.", tier=4, tierName="Epic", coins=35, xp=30, metric="TREMOR", goal=100 },
    { key="CLASS_SHAMAN_069", classToken="SHAMAN", title="Hero of the Group", description="Cast Bloodlust or Heroism 250 times while grouped.", tier=3, tierName="Gold", coins=20, xp=18, metric="HEROISM_GROUP", goal=250 },
    { key="CLASS_SHAMAN_070", classToken="SHAMAN", title="Farseer of CreshChat", description="Complete 5,000 class-signature Shaman actions across the account.", tier=5, tierName="Legendary", coins=60, xp=50, metric="SIGNATURE", goal=5000 },
    { key="CLASS_WARLOCK_071", classToken="WARLOCK", title="A Stone for the Fallen", description="Create or apply 100 Soulstones.", tier=3, tierName="Gold", coins=20, xp=18, metric="SOULSTONES", goal=100 },
    { key="CLASS_WARLOCK_072", classToken="WARLOCK", title="Healthstone Supplier", description="Create 500 Healthstones.", tier=2, tierName="Silver", coins=10, xp=10, metric="HEALTHSTONES", goal=500 },
    { key="CLASS_WARLOCK_073", classToken="WARLOCK", title="Ritual Coordinator", description="Summon 100 players with Ritual of Summoning.", tier=3, tierName="Gold", coins=20, xp=18, metric="SUMMONS", goal=100 },
    { key="CLASS_WARLOCK_074", classToken="WARLOCK", title="Demon Denied", description="Successfully Banish 250 demons or elementals.", tier=3, tierName="Gold", coins=20, xp=18, metric="BANISHES", goal=250 },
    { key="CLASS_WARLOCK_075", classToken="WARLOCK", title="Fear Itself", description="Successfully Fear 1,000 targets.", tier=4, tierName="Epic", coins=35, xp=30, metric="FEARS", goal=1000 },
    { key="CLASS_WARLOCK_076", classToken="WARLOCK", title="Soul Collector", description="Create 2,500 Soul Shards with Drain Soul or related effects.", tier=4, tierName="Epic", coins=35, xp=30, metric="SOUL_SHARDS", goal=2500 },
    { key="CLASS_WARLOCK_077", classToken="WARLOCK", title="Demon Master", description="Successfully Enslave Demon 100 times.", tier=4, tierName="Epic", coins=35, xp=30, metric="ENSLAVES", goal=100 },
    { key="CLASS_WARLOCK_078", classToken="WARLOCK", title="Seeds of Ruin", description="Damage 5,000 enemies with Seed of Corruption explosions.", tier=4, tierName="Epic", coins=35, xp=30, metric="SEED_HITS", goal=5000 },
    { key="CLASS_WARLOCK_079", classToken="WARLOCK", title="Dreadsteed Rider", description="Earn the Warlock epic class mount.", tier=4, tierName="Epic", coins=35, xp=30, metric="EPIC_MOUNT", goal=1 },
    { key="CLASS_WARLOCK_080", classToken="WARLOCK", title="Netherlord of CreshChat", description="Complete 5,000 class-signature Warlock actions across the account.", tier=5, tierName="Legendary", coins=60, xp=50, metric="SIGNATURE", goal=5000 },
    { key="CLASS_WARRIOR_081", classToken="WARRIOR", title="First Into Battle", description="Use Charge, Intercept, or Intervene 1,000 times.", tier=2, tierName="Silver", coins=10, xp=10, metric="CHARGES", goal=1000 },
    { key="CLASS_WARRIOR_082", classToken="WARRIOR", title="Hold Their Attention", description="Use Taunt or Challenging Shout on 1,000 enemies.", tier=3, tierName="Gold", coins=20, xp=18, metric="WARRIOR_TAUNTS", goal=1000 },
    { key="CLASS_WARRIOR_083", classToken="WARRIOR", title="Break Their Guard", description="Apply Sunder Armor or Devastate 5,000 times.", tier=4, tierName="Epic", coins=35, xp=30, metric="SUNDER_DEVASTATE", goal=5000 },
    { key="CLASS_WARRIOR_084", classToken="WARRIOR", title="No Casting Allowed", description="Interrupt 250 spells with Pummel or Shield Bash.", tier=4, tierName="Epic", coins=35, xp=30, metric="WARRIOR_INTERRUPTS", goal=250 },
    { key="CLASS_WARRIOR_085", classToken="WARRIOR", title="Disarmed and Dangerous", description="Successfully Disarm 250 enemies.", tier=3, tierName="Gold", coins=20, xp=18, metric="DISARMS", goal=250 },
    { key="CLASS_WARRIOR_086", classToken="WARRIOR", title="Battle Commander", description="Apply Battle Shout or Commanding Shout to group members 1,000 times.", tier=3, tierName="Gold", coins=20, xp=18, metric="SHOUTS_GROUP", goal=1000 },
    { key="CLASS_WARRIOR_087", classToken="WARRIOR", title="Executioner", description="Defeat 1,000 enemies with Execute.", tier=4, tierName="Epic", coins=35, xp=30, metric="EXECUTE_KILLS", goal=1000 },
    { key="CLASS_WARRIOR_088", classToken="WARRIOR", title="Stand Behind Me", description="Use Intervene on another player 250 times.", tier=4, tierName="Epic", coins=35, xp=30, metric="INTERVENES", goal=250 },
    { key="CLASS_WARRIOR_089", classToken="WARRIOR", title="Last One Standing", description="Use Shield Wall or Last Stand while below 25% health 50 times.", tier=4, tierName="Epic", coins=35, xp=30, metric="LAST_STANDS_LOW", goal=50 },
    { key="CLASS_WARRIOR_090", classToken="WARRIOR", title="Warlord of CreshChat", description="Complete 5,000 class-signature Warrior actions across the account.", tier=5, tierName="Legendary", coins=60, xp=50, metric="SIGNATURE", goal=5000 },
}

local function now()
    if type(_G.GetServerTime) == "function" then return _G.GetServerTime() end
    if type(_G.time) == "function" then return _G.time() end
    if type(_G.GetTime) == "function" then return floor(_G.GetTime()) end
    return 0
end

local function normalise(value)
    return lower(tostring(value or "")):gsub("^%s+", ""):gsub("%s+$", "")
end

local function currentClass()
    if type(_G.UnitClass) == "function" then
        local _, token = _G.UnitClass("player")
        return upper(tostring(token or ""))
    end
    return ""
end

local function classRoot()
    local save = A:Ensure()
    if not save then return nil end
    save.classProgress = type(save.classProgress) == "table" and save.classProgress or {}
    save.classProgress.stats = type(save.classProgress.stats) == "table" and save.classProgress.stats or {}
    save.classProgress.uniquePets = type(save.classProgress.uniquePets) == "table" and save.classProgress.uniquePets or {}
    save.classProgress.lastUpdated = tonumber(save.classProgress.lastUpdated) or 0
    return save.classProgress
end

local function statTable(classToken)
    local root = classRoot(); if not root then return nil end
    classToken = upper(tostring(classToken or ""))
    root.stats[classToken] = type(root.stats[classToken]) == "table" and root.stats[classToken] or {}
    return root.stats[classToken]
end

function ClassAchievements:QueueEvaluation()
    if self.pendingEvaluation then return end
    self.pendingEvaluation = true
    local function finish()
        ClassAchievements.pendingEvaluation = false
        if A and A.EvaluateAll then A:EvaluateAll(false) end
    end
    if _G.C_Timer and type(_G.C_Timer.After) == "function" then _G.C_Timer.After(0.35, finish) else finish() end
end

function ClassAchievements:Add(classToken, metric, amount)
    classToken, metric = upper(tostring(classToken or "")), upper(tostring(metric or ""))
    if classToken == "" or metric == "" then return end
    local stats = statTable(classToken); if not stats then return end
    stats[metric] = floor(max(0, tonumber(stats[metric]) or 0) + max(0, tonumber(amount) or 1))
    local root = classRoot(); if root then root.lastUpdated = now() end
    self:QueueEvaluation()
end

function ClassAchievements:SetAtLeast(classToken, metric, value)
    local stats = statTable(classToken); if not stats then return end
    metric = upper(tostring(metric or "")); value = floor(max(0, tonumber(value) or 0))
    if value > (tonumber(stats[metric]) or 0) then stats[metric] = value; self:QueueEvaluation() end
end

function ClassAchievements:AddUniquePet(name)
    local root = classRoot(); if not root then return end
    local key = normalise(name)
    if key == "" or root.uniquePets[key] then return end
    root.uniquePets[key] = { name = tostring(name), at = now() }
    self:QueueEvaluation()
end

local function countMap(tbl)
    local n=0; for _ in pairs(tbl or {}) do n=n+1 end; return n
end

function ClassAchievements:Get(classToken, metric)
    classToken, metric = upper(tostring(classToken or "")), upper(tostring(metric or ""))
    local root = classRoot(); if not root then return 0 end
    if metric == "UNIQUE_PETS" then return countMap(root.uniquePets) end
    local stats = root.stats[classToken] or {}
    if metric == "SIGNATURE" then
        local total=0
        for key,value in pairs(stats) do if key ~= "SIGNATURE" then total=total+floor(max(0,tonumber(value) or 0)) end end
        if classToken == "HUNTER" then total=total+countMap(root.uniquePets) end
        return total
    end
    return floor(max(0, tonumber(stats[metric]) or 0))
end

local oldBuildCatalog=A.BuildCatalog
function A:BuildCatalog()
    oldBuildCatalog(self)
    if self.classAchievementsBuilt then return end
    self.classAchievementsBuilt=true
    self.categoryNames.CLASSES="Class Mastery"
    local found=false
    for _,key in ipairs(self.categoryOrder or {}) do if key=="CLASSES" then found=true break end end
    if not found then table.insert(self.categoryOrder, max(1,#self.categoryOrder), "CLASSES") end
    for _,item in ipairs(CLASS_ACHIEVEMENTS) do
        local achievement={
            key=item.key, category="CLASSES", classToken=item.classToken,
            stat="CLASS|"..item.classToken.."|"..item.metric,
            goal=item.goal, title=item.title, description=item.description,
            coins=item.coins, xp=item.xp, tier=item.tier, tierName=item.tierName,
            classAchievement=true,
        }
        self.catalog[#self.catalog+1]=achievement
        self.byKey[achievement.key]=achievement
    end
end

local oldGetStat=A.GetStat
function A:GetStat(stat)
    stat=tostring(stat or "")
    if stat:sub(1,6)~="CLASS|" then return oldGetStat(self,stat) end
    local classToken,metric=stat:match("^CLASS|([^|]+)|(.+)$")
    return ClassAchievements:Get(classToken,metric)
end

local CAST_RULES={
    DRUID={
        SHAPESHIFTS={"bear form","dire bear form","cat form","travel form","aquatic form","moonkin form","tree of life","flight form","swift flight form"},
        BLOOM_SWIFTMEND={"lifebloom","swiftmend"}, DRUID_TAUNTS={"growl","challenging roar"},
    },
    HUNTER={PET_CARE={"mend pet","feed pet"},FEIGN_COMBAT={"feign death"},TRAPS={"freezing trap","frost trap","immolation trap","explosive trap","snake trap"},DISTRACTION={"distracting shot","misdirection"},KILL_COMMAND={"kill command"}},
    MAGE={BLINKS={"blink"},ICE_BLOCK_LOW={"ice block"},EVOCATIONS={"evocation"}},
    PALADIN={AURAS={"devotion aura","retribution aura","concentration aura","shadow resistance aura","frost resistance aura","fire resistance aura","sanctity aura","crusader aura"},PALADIN_TAUNTS={"righteous defense"},AVENGING_WRATH={"avenging wrath"}},
    PRIEST={PRAYER_MENDING={"prayer of mending"},FADES_THREAT={"fade"},SHADOWFIENDS={"shadowfiend"}},
    ROGUE={PICKPOCKETS={"pick pocket"},LOCKS_OPENED={"pick lock"},VANISH_COMBAT={"vanish"},POISONS_APPLIED={"instant poison","deadly poison","crippling poison","mind-numbing poison","wound poison","anesthetic poison"},CLOAKS={"cloak of shadows"}},
    SHAMAN={WATER_WALKING={"water walking"},GROUNDING={"grounding totem"},TREMOR={"tremor totem"},HEROISM_GROUP={"bloodlust","heroism"}},
    WARLOCK={SOULSTONES={"create soulstone","soulstone resurrection"},HEALTHSTONES={"create healthstone"},SUMMONS={"ritual of summoning"}},
    WARRIOR={CHARGES={"charge","intercept","intervene"},WARRIOR_TAUNTS={"taunt","challenging shout","mocking blow"},INTERVENES={"intervene"},LAST_STANDS_LOW={"shield wall","last stand"}},
}

local function spellMatches(spell, list)
    spell=normalise(spell)
    for _,name in ipairs(list or {}) do if spell==name or spell:find(name,1,true) then return true end end
    return false
end

local FINISHERS={["eviscerate"]=true,["envenom"]=true,["rupture"]=true,["slice and dice"]=true,["kidney shot"]=true,["expose armor"]=true,["deadly throw"]=true}

function ClassAchievements:HandleCast(spellName)
    local classToken=currentClass(); if classToken=="" then return end
    local spell=normalise(spellName); if spell=="" then return end
    local rules=CAST_RULES[classToken] or {}
    for metric,names in pairs(rules) do
        if spellMatches(spell,names) then
            if metric=="FEIGN_COMBAT" or metric=="VANISH_COMBAT" or metric=="FADES_THREAT" then
                if type(_G.UnitAffectingCombat)~="function" or _G.UnitAffectingCombat("player") then self:Add(classToken,metric,1) end
            elseif metric=="ICE_BLOCK_LOW" or metric=="LAST_STANDS_LOW" then
                local health=type(_G.UnitHealth)=="function" and tonumber(_G.UnitHealth("player")) or 1
                local maximum=type(_G.UnitHealthMax)=="function" and tonumber(_G.UnitHealthMax("player")) or 1
                if maximum>0 and health/maximum<=0.25 then self:Add(classToken,metric,1) end
            elseif metric=="HEROISM_GROUP" then
                local grouped=(type(_G.IsInGroup)=="function" and _G.IsInGroup()) or (type(_G.GetNumPartyMembers)=="function" and (_G.GetNumPartyMembers() or 0)>0)
                if grouped then self:Add(classToken,metric,1) end
            else self:Add(classToken,metric,1) end
        end
    end
    if classToken=="DRUID" and (spell=="flight form" or spell=="swift flight form") then self:SetAtLeast("DRUID","FLIGHT_FORM",1) end
    if classToken=="HUNTER" and spell=="tame beast" then self.pendingTame=now() end
    if classToken=="MAGE" then
        if spell:find("conjure ",1,true)==1 then self:Add("MAGE","CONJURES",1) end
        if spell:find("portal:",1,true)==1 or spell:find("portal ",1,true)==1 then self:Add("MAGE","PORTALS",1) end
        if spell:find("teleport:",1,true)==1 or spell:find("teleport ",1,true)==1 then self:Add("MAGE","TELEPORTS",1) end
    elseif classToken=="ROGUE" and FINISHERS[spell] then
        local points=type(_G.GetComboPoints)=="function" and tonumber(_G.GetComboPoints("player","target")) or 0
        if points>=5 or (self.lastComboPoints or 0)>=5 then self:Add("ROGUE","FIVE_POINT_FINISHERS",1); self.lastComboPoints=0 end
    end
end

local function unitForGUID(guid)
    if not guid or type(_G.UnitGUID)~="function" then return nil end
    local units={"player","target","mouseover","focus","party1","party2","party3","party4"}
    if type(_G.IsInRaid)=="function" and _G.IsInRaid() then for i=1,40 do units[#units+1]="raid"..i end end
    for _,unit in ipairs(units) do if _G.UnitGUID(unit)==guid then return unit end end
end

local function targetLow(guid)
    local unit=unitForGUID(guid); if not unit then return true end
    local h=type(_G.UnitHealth)=="function" and tonumber(_G.UnitHealth(unit)) or 1
    local m=type(_G.UnitHealthMax)=="function" and tonumber(_G.UnitHealthMax(unit)) or 1
    return m>0 and h/m<=0.20
end

function ClassAchievements:HandleCombatEvent(event)
    local playerGUID=type(_G.UnitGUID)=="function" and _G.UnitGUID("player") or nil
    if not playerGUID or event[4]~=playerGUID then return end
    local classToken=currentClass(); local subevent=tostring(event[2] or "")
    local destGUID=event[8]; local spell=normalise(event[13]); if spell=="" then return end
    if subevent=="SPELL_RESURRECT" then
        if classToken=="DRUID" and spell:find("rebirth",1,true) then self:Add(classToken,"REBIRTHS",1)
        elseif classToken=="PALADIN" and spell:find("redemption",1,true) then self:Add(classToken,"RESURRECTIONS",1)
        elseif classToken=="PRIEST" and (spell:find("resurrection",1,true) or spell:find("resurrect",1,true)) then self:Add(classToken,"RESURRECTIONS",1) end
    elseif subevent=="SPELL_INTERRUPT" then
        if classToken=="MAGE" and spell:find("counterspell",1,true) then self:Add(classToken,"COUNTERSPELL_INTERRUPTS",1)
        elseif classToken=="ROGUE" and spell=="kick" then self:Add(classToken,"KICK_INTERRUPTS",1)
        elseif classToken=="SHAMAN" and spell:find("earth shock",1,true) then self:Add(classToken,"EARTH_SHOCK_INTERRUPTS",1)
        elseif classToken=="WARRIOR" and (spell=="pummel" or spell:find("shield bash",1,true)) then self:Add(classToken,"WARRIOR_INTERRUPTS",1) end
    elseif subevent=="SPELL_DISPEL" then
        if classToken=="HUNTER" and spell:find("tranquilizing shot",1,true) then self:Add(classToken,"TRANQ_DISPELS",1)
        elseif classToken=="PALADIN" and (spell=="cleanse" or spell=="purify") then self:Add(classToken,"CLEANSES",1)
        elseif classToken=="PRIEST" and spell:find("mass dispel",1,true) then self:Add(classToken,"MASS_DISPELS",1); self:Add(classToken,"DISPELS",1)
        elseif classToken=="PRIEST" then self:Add(classToken,"DISPELS",1)
        elseif classToken=="SHAMAN" and spell=="purge" then self:Add(classToken,"PURGES",1) end
    elseif subevent=="SPELL_STOLEN" and classToken=="MAGE" then self:Add(classToken,"SPELLSTEALS",1)
    elseif subevent=="SPELL_AURA_APPLIED" or subevent=="SPELL_AURA_REFRESH" then
        if classToken=="DRUID" and spell=="innervate" and destGUID~=playerGUID then self:Add(classToken,"INNERVATE_OTHERS",1)
        elseif classToken=="MAGE" and spell:find("polymorph",1,true) then self:Add(classToken,"POLYMORPHS",1)
        elseif classToken=="PALADIN" and spell:find("blessing",1,true) and destGUID~=playerGUID then self:Add(classToken,"BLESSINGS_OTHER",1)
        elseif classToken=="PRIEST" and spell=="power word: shield" and destGUID~=playerGUID then self:Add(classToken,"SHIELDS_OTHER",1)
        elseif classToken=="PRIEST" and spell:find("shackle undead",1,true) then self:Add(classToken,"SHACKLES",1)
        elseif classToken=="PRIEST" and spell:find("mind control",1,true) then self:Add(classToken,"MIND_CONTROLS",1)
        elseif classToken=="ROGUE" and spell=="sap" then self:Add(classToken,"SAPS",1)
        elseif classToken=="ROGUE" and spell=="blind" then self:Add(classToken,"BLINDS",1)
        elseif classToken=="WARLOCK" and spell:find("banish",1,true) then self:Add(classToken,"BANISHES",1)
        elseif classToken=="WARLOCK" and (spell=="fear" or spell:find("howl of terror",1,true) or spell:find("death coil",1,true)) then self:Add(classToken,"FEARS",1)
        elseif classToken=="WARLOCK" and spell:find("enslave demon",1,true) then self:Add(classToken,"ENSLAVES",1)
        elseif classToken=="WARRIOR" and spell=="disarm" then self:Add(classToken,"DISARMS",1)
        elseif classToken=="WARRIOR" and (spell:find("battle shout",1,true) or spell:find("commanding shout",1,true)) and destGUID~=playerGUID then self:Add(classToken,"SHOUTS_GROUP",1)
        elseif classToken=="WARRIOR" and (spell:find("sunder armor",1,true) or spell=="devastate") then self:Add(classToken,"SUNDER_DEVASTATE",1) end
    elseif subevent=="SPELL_DAMAGE" or subevent=="RANGE_DAMAGE" then
        if classToken=="HUNTER" then self:Add(classToken,"RANGED_HITS",1) end
        if classToken=="PALADIN" and spell=="consecration" then self:Add(classToken,"CONSECRATION_HITS",1) end
        if classToken=="WARLOCK" and spell:find("seed of corruption",1,true) then self:Add(classToken,"SEED_HITS",1) end
        if classToken=="WARRIOR" and spell=="devastate" then self:Add(classToken,"SUNDER_DEVASTATE",1) end
        if classToken=="WARRIOR" and spell=="execute" then
            local overkill=tonumber(event[16]) or -1
            if overkill>=0 then self:Add(classToken,"EXECUTE_KILLS",1) end
        end
    elseif subevent=="SPELL_CAST_SUCCESS" then
        if classToken=="PALADIN" and spell:find("lay on hands",1,true) and targetLow(destGUID) then self:Add(classToken,"LAY_HANDS_LOW",1) end
    end
end

function ClassAchievements:ScanKnownClassSpells()
    local classToken=currentClass()
    if classToken=="DRUID" then
        local known=false
        if type(_G.IsSpellKnown)=="function" then known=_G.IsSpellKnown(33943) or _G.IsSpellKnown(40120) end
        if known then self:SetAtLeast(classToken,"FLIGHT_FORM",1) end
    elseif classToken=="PALADIN" then
        local known=type(_G.IsSpellKnown)=="function" and (_G.IsSpellKnown(23214) or _G.IsSpellKnown(34769) or _G.IsSpellKnown(34767))
        if known then self:SetAtLeast(classToken,"EPIC_MOUNT",1) end
    elseif classToken=="WARLOCK" then
        local known=type(_G.IsSpellKnown)=="function" and _G.IsSpellKnown(23161)
        if known then self:SetAtLeast(classToken,"EPIC_MOUNT",1) end
    end
end

function ClassAchievements:ScanSoulShards(initial)
    if currentClass()~="WARLOCK" or type(_G.GetItemCount)~="function" then return end
    local count=tonumber(_G.GetItemCount(6265)) or 0
    if self.lastSoulShards~=nil and count>self.lastSoulShards then self:Add("WARLOCK","SOUL_SHARDS",count-self.lastSoulShards) end
    self.lastSoulShards=count
end

local frame=CreateFrame("Frame")
for _,event in ipairs({"PLAYER_LOGIN","PLAYER_ENTERING_WORLD","SPELLS_CHANGED","UNIT_SPELLCAST_SUCCEEDED","UNIT_PET","UNIT_COMBO_POINTS","PLAYER_REGEN_DISABLED","PLAYER_DEAD","PLAYER_ALIVE","BAG_UPDATE_DELAYED","COMBAT_LOG_EVENT_UNFILTERED"}) do pcall(frame.RegisterEvent,frame,event) end
frame:SetScript("OnEvent",function(_,event,...)
    if event=="PLAYER_LOGIN" or event=="PLAYER_ENTERING_WORLD" or event=="SPELLS_CHANGED" then
        A:BuildCatalog(); classRoot(); ClassAchievements:ScanKnownClassSpells(); ClassAchievements:ScanSoulShards(true)
        if currentClass()=="HUNTER" and type(_G.UnitExists)=="function" and _G.UnitExists("pet") and type(_G.UnitName)=="function" then ClassAchievements:AddUniquePet(_G.UnitName("pet")) end
        A:EvaluateAll(true)
    elseif event=="UNIT_SPELLCAST_SUCCEEDED" then
        local unit,a,b,c,d=...
        if unit=="player" then
            local spellID=tonumber(d) or tonumber(c) or tonumber(b)
            local name
            if type(a)=="string" and not a:find("^Cast%-") and not a:find("^cast%-") then name=a end
            if (not name or name=="") and type(_G.GetSpellInfo)=="function" and spellID then name=_G.GetSpellInfo(spellID) end
            ClassAchievements:HandleCast(name)
        end
    elseif event=="UNIT_COMBO_POINTS" then
        local unit=...
        if unit=="player" and currentClass()=="ROGUE" and type(_G.GetComboPoints)=="function" then ClassAchievements.lastComboPoints=tonumber(_G.GetComboPoints("player","target")) or 0 end
    elseif event=="UNIT_PET" then
        local unit=...
        if unit=="player" and currentClass()=="HUNTER" and ClassAchievements.pendingTame and now()-ClassAchievements.pendingTame<8 then
            local petName=type(_G.UnitName)=="function" and _G.UnitName("pet") or nil
            if petName then ClassAchievements:AddUniquePet(petName) end
            ClassAchievements.pendingTame=nil
        end
    elseif event=="PLAYER_REGEN_DISABLED" then
        if currentClass()=="DRUID" and ClassAchievements.lastProwl and now()-ClassAchievements.lastProwl<10 then ClassAchievements:Add("DRUID","PROWL_OPENS",1); ClassAchievements.lastProwl=nil end
    elseif event=="PLAYER_DEAD" then
        if currentClass()=="SHAMAN" then
            ClassAchievements.wasDead=true
            local option=type(_G.HasSoulstone)=="function" and _G.HasSoulstone() or nil
            ClassAchievements.reincarnationReady=normalise(option):find("reincarnation",1,true)~=nil
        end
    elseif event=="PLAYER_ALIVE" then
        if currentClass()=="SHAMAN" and ClassAchievements.wasDead and ClassAchievements.reincarnationReady then ClassAchievements:Add("SHAMAN","REINCARNATIONS",1) end
        ClassAchievements.wasDead=false; ClassAchievements.reincarnationReady=false
    elseif event=="BAG_UPDATE_DELAYED" then ClassAchievements:ScanSoulShards(false)
    elseif event=="COMBAT_LOG_EVENT_UNFILTERED" and type(_G.CombatLogGetCurrentEventInfo)=="function" then
        ClassAchievements:HandleCombatEvent({_G.CombatLogGetCurrentEventInfo()})
    end
end)

-- Preserve Prowl intent from successful player casts without counting passive stealth.
local oldHandleCast=ClassAchievements.HandleCast
function ClassAchievements:HandleCast(spellName)
    if currentClass()=="DRUID" and normalise(spellName)=="prowl" then self.lastProwl=now() end
    oldHandleCast(self,spellName)
end
