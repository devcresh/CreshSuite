-- CreshCollect registers its notification source with the CreshChat
-- shared service. CreshChat is guaranteed loaded first (see Dependencies).
-- This stub establishes the source and category registry so the Settings
-- panel (Phase 8) can display CreshCollect controls before event migration
-- (Phase 7) moves the actual producers here.

local CC = _G.CreshChat
if not CC or not CC.Notifications then return end

CC.Notifications:RegisterSource("CRESHCOLLECT", "CreshCollect")
CC.Notifications:RegisterCategory("CRESHCOLLECT", "ACHIEVEMENT",         "Achievement Earned",    "Achievement completion notifications.",            { priority = "NORMAL" })
CC.Notifications:RegisterCategory("CRESHCOLLECT", "ACHIEVEMENT_PROGRESS","Achievement Progress",  "Incremental achievement progress updates.",        { priority = "LOW" })
CC.Notifications:RegisterCategory("CRESHCOLLECT", "COLLECTION_UNLOCK",   "Collection Unlocks",   "New collectible or cosmetic unlock notices.",      { priority = "NORMAL" })
CC.Notifications:RegisterCategory("CRESHCOLLECT", "COSMETIC_REWARD",     "Cosmetic Rewards",     "Cosmetic item reward notifications.",              { priority = "LOW" })
CC.Notifications:RegisterCategory("CRESHCOLLECT", "MILESTONE",           "Milestones",           "Collection or progression milestone completions.", { priority = "LOW" })
