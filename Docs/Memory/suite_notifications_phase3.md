---
name: suite-notifications-phase3
description: Phase 3 suite-wide notification service shipped and confirmed working in-game
metadata:
  type: project
---

Phase 3 moved CreshChat's notification registration contract *and* card
renderer (previously `Notifications.lua` + `NotificationCard.lua`, gated on
`CC.UI` existing) to `shared/SuiteNotifications.lua` (`_G.CreshSuiteNotifications`),
following the same physically-copied shared-file pattern as
[[creshsuite_ui_service_phase1]]. All 27 CreshGames/CreshCollect notification
call sites (24 toast wrappers + 3 direct `Notifications:Push` sites the
initial research pass missed — multiplayer result/challenge-sent/challenge-
declined) now push through addon-local helpers
(`GamesNotifications.lua`/`CollectNotifications.lua`) with no `CC.UI`
dependency. Confirmed working in-game (2026-07-07).

**Non-obvious things discovered during implementation, worth knowing before
touching this system again:**

1. **CreshGames.lua and CreshCollect.lua already had their own source/category
   registration blocks** (`CC.Notifications:RegisterSource("CRESHGAMES", ...)`
   etc.) sitting in their `PLAYER_LOGIN`/`ADDON_LOADED` handlers, gated on
   `if CC and CC.Notifications then ... end`. This wasn't obvious from
   grepping the toast-wrapper call sites alone — a plain producer-call-site
   search misses registration-only code. Always grep for `RegisterSource`/
   `RegisterCategory` directly, not just `Push`/`ShowXToast`, before assuming
   a source was never registered anywhere.

2. **`Push()` must pcall its own card-rendering path.** Several pre-existing
   unit tests (`ArcadePassTests.lua`, `RewardRegistryTests.lua`,
   `BattlePassCardDeckRecursionTests.lua`) load individual game-logic files
   in isolation with a minimal `CreateFrame` stub that doesn't support real
   widget methods. Once producers started actually calling `Push()` (instead
   of a stub), these narrow tests crashed inside `buildCard()`. The fix
   (wrapping `ShowCard` in `pcall` inside `Push`) is also a genuine
   production safety requirement, not just a test workaround: a card-
   rendering failure must never propagate into the gameplay code that
   triggered the notification.

3. Any existing test file that loads a production file which now calls a
   `CG:ShowXToast`/`COL:ShowXToast` notification helper must also load
   `shared/SuiteNotifications.lua` + the relevant `GamesNotifications.lua`/
   `CollectNotifications.lua` earlier in its own `loadProductionFile` chain,
   or the helper method is nil and the test crashes.

**How to apply:** before adding a new CreshGames/CreshCollect notification
producer, check `GamesNotifications.lua`/`CollectNotifications.lua` for an
existing category/helper that fits rather than inventing a new one.
