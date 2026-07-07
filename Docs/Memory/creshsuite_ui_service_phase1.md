---
name: creshsuite-ui-service-phase1
description: Phase 1 cross-addon UI foundation (CreshSuiteUI) shipped and confirmed working in-game
metadata: 
  node_type: memory
  type: project
  originSessionId: a1883b5b-bd94-421c-8ae0-042bc5ccf28f
---

Phase 1 of the CreshSuite UI foundation is done and in-game verified (as of
2026-07-06): `shared/CreshUI.lua` (physically copied into all three addon
folders as `CreshUI.lua`, declared in each TOC right after `Launcher.lua`)
now provides palette resolution, semantic states (LOCKED/AVAILABLE/READY/
UNLOCKED/EQUIPPED/DISABLED), button/backdrop/tab/text helpers, safe
screen-fit scaling, minimal window chrome, owner-addon position persistence,
and a `SUITE_THEME_CHANGED` pub/sub event. `CreshChatAPI.GetActivePalette()`
was added so callers never read CreshChat's private `CC.db` directly.
`addons/CreshCollect/ProgressHub.lua` was converted as the one proof-of-contract
window (including moving its position storage from `CreshChatDB` into its own
`CreshCollectDB`).

**Why this matters going forward:** Games.lua, SoloGames.lua, BattlePass.lua,
Achievements.lua, and ProgressOverview.lua still have their own local
palette()/applyBackdrop()/createButton()/darken() duplicates and still read
`CC.db.colors` directly — they were deliberately NOT touched in Phase 1
("don't broadly migrate yet"). Any future phase that migrates one of those
files should follow the exact pattern validated here: thin local wrapper
functions delegating to `_G.CreshSuiteUI` (not a full rewrite of call sites),
same-named locals preserved so the rest of the file needs no changes, and
position persistence moved to that addon's own SavedVariables via
`CreshSuiteUI:SavePosition/RestorePosition` with a one-time legacy-value
migration read.

**How to apply:** When asked to continue this work, check `D:\CreshSuite\Plans\`
for the Phase 1 plan file (`shimmering-fluttering-river.md`) for full design
rationale before proposing Phase 2. See also [[plan-file-location]].
