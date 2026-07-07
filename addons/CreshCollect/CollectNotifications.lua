local _, COL = ...
if not COL then return end

-- CreshCollect's own registration against the suite-wide notification
-- service (shared/SuiteNotifications.lua, loaded earlier in this TOC --
-- guaranteed present regardless of whether CreshChat is loaded). Replaces
-- the old registerNotifications() in CreshCollect.lua, which only ever ran
-- once CC.Notifications existed (i.e. never, without CreshChat). Category
-- set is unchanged from that function.

local Notif = _G.CreshSuiteNotifications
if not Notif then return end

Notif:RegisterSource("CRESHCOLLECT", "CreshCollect")
Notif:RegisterCategory("CRESHCOLLECT", "ACHIEVEMENT",          "Achievement Earned",   "Achievement completion notifications.",            { priority = "NORMAL" })
Notif:RegisterCategory("CRESHCOLLECT", "ACHIEVEMENT_PROGRESS", "Achievement Progress", "Incremental achievement progress updates.",        { priority = "LOW"    })
Notif:RegisterCategory("CRESHCOLLECT", "COLLECTION_UNLOCK",    "Collection Unlocks",   "New collectible or cosmetic unlock notices.",      { priority = "NORMAL" })
Notif:RegisterCategory("CRESHCOLLECT", "COSMETIC_REWARD",      "Cosmetic Rewards",     "Cosmetic item reward notifications.",              { priority = "LOW"    })
Notif:RegisterCategory("CRESHCOLLECT", "MILESTONE",            "Milestones",           "Collection or progression milestone completions.", { priority = "LOW"    })

-- ----------------------------------------------------------------
-- Producer helpers -- no CC.UI/CC.Notifications reference.
-- ----------------------------------------------------------------

local function push(category, title, message, status, key, extra)
    local event = {
        sourceAddon = "CRESHCOLLECT",
        category    = category,
        status      = status or "SUCCESS",
        title       = tostring(title or "CreshCollect"),
        detail      = tostring(message or ""),
        coalesceKey = key,
    }
    if type(extra) == "table" then
        for k, v in pairs(extra) do event[k] = v end
    end
    return Notif:Push(event)
end

-- Azeroth Chronicle / Renown level-ups and reward claims.
function COL:ShowBattlePassToast(title, message, status, key)
    return push("MILESTONE", title or "Battle Pass", message or "New progress is ready.", status or "BATTLEPASS", key)
end

-- World exploration and other background-progression rewards.
function COL:ShowGameToast(title, message, status, key)
    return push("MILESTONE", title, message, status, key)
end

-- Chat theme purchased/unlocked via the Chronicle shop.
function COL:ShowCosmeticRewardToast(title, message, key)
    return push("COSMETIC_REWARD", title, message, "SUCCESS", key)
end

-- CreshCollect catalog achievement unlock.
function COL:ShowAchievementToast(title, message, key)
    return push("ACHIEVEMENT", title, message, "ACHIEVEMENT", key)
end
