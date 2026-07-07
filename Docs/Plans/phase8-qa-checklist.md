# Phase 8 — In-Game QA Checklist

Status: automated tests + static review complete — see `phase8-qa-report.md`
for the full findings. **Nothing in this checklist has been run in a live
WoW client yet.** Every box below needs a real in-game pass before any of
this work can be called done. Deploy first:

```
.\tools\Deploy-Local.ps1
```

## 0. Confirm/repro the static-review findings (see phase8-qa-report.md)

- [ ] **Critical**: Run CreshCollect standalone (CreshChat disabled). Open Progress Hub from the launcher's "Prg" button → ProgressOverview → "WORLD/QUESTS/COMBAT" nav button. Confirm whether it silently does nothing (current expected behavior per static review) — this is the addon-independence violation in `ProgressHub.lua:Build()`.
- [ ] **Medium**: Time how long the CreshCollect Achievements *drawer panel* (embedded in the CreshChat dock, not the standalone window) takes to first open — it builds ~570 frames synchronously per the static review.
- [ ] **Medium**: In CreshGames, receive a game challenge whisper within the first 1-2 seconds after login (before `CC.db` is likely populated) and confirm it doesn't error (`Games.lua:755`/`935`).
- [ ] **Low-Medium**: Open CreshGames Settings → Notifications immediately after a fresh login and toggle a category checkbox — confirm no error (`GamesSettings.lua:150`).

---

## 1. Static addon combinations

Load each combination below (toggle addons off in the WoW AddOns list, then
`/reload`) and confirm: no Lua error on login, the addon's own UI opens
normally, and no other addon's window/tab is silently missing content it
should still show.

- [ ] CreshChat only
- [ ] CreshGames only
- [ ] CreshCollect only
- [ ] CreshChat + CreshGames
- [ ] CreshChat + CreshCollect
- [ ] CreshGames + CreshCollect
- [ ] All three together

For each combination, specifically check:
- [ ] CreshChat Settings' product tabs show "not installed" / "disabled" state correctly for whichever addons are absent, with no broken/blank tab.
- [ ] CreshGames' Unlocks catalogue shows "Requires CreshChat" (or CreshCollect) for entries it can't read, instead of erroring.
- [ ] CreshCollect's Chronicle & Collections settings page shows "module is not loaded" text instead of erroring when CreshGames/CreshChat are absent.
- [ ] No `/cc`, `/cg`, `/ccol` slash command errors when its own addon is the only one loaded.

## 2. Themes

100 named presets exist (25 in `UI.lua` + 75 in `Themes.lua`) — testing all
100 individually isn't practical. Instead:

- [ ] Pick one theme from each category shown in the Appearance dropdown (Faction, Zone, and any others present) and confirm it applies live across: main chat window, dock, notification cards, Settings window itself.
- [ ] Select a **locked** theme (e.g. any Battle Pass/Chronicle-gated preset) and confirm it shows `[LOCKED]` in the dropdown and cannot be applied, but doesn't error.
- [ ] Select **Custom** and confirm the 7 surface-color pickers (panel/border/accent/etc.) work and persist.
- [ ] Confirm the dropdown's Prev/Next paging (not a scrollbar) works across all ~100 entries without blank/overlapping text (this was the bug fixed earlier this session — re-confirm it stayed fixed).
- [ ] Guild-specific theme presets (separate list in `Themes.lua`) apply independently of the main theme.

## 3. UI scale / resolution

- [ ] Quality profile presets: MINIMAL, MESSENGER, POPOUT, PERFORMANCE, BALANCED — apply each from Settings and confirm the described bundle of changes actually takes effect (e.g. PERFORMANCE disables animations, MINIMAL uses class-color portraits only).
- [ ] `panelScale` slider (Settings → Appearance/Windows) across its full range — confirm no overlapping text or off-screen frames at the extremes.
- [ ] WoW's own UI Scale slider (Options → Interface) combined with a CreshChat panel scale — confirm cards/windows don't drift off-screen or become unreadable.
- [ ] Low resolution (test at 1280x720 or the lowest resolution available) — confirm the Settings window, notification cards, and CreshGames/CreshCollect windows don't overflow the screen or clip off-screen.
- [ ] Resize the Settings window narrower and wider — confirm the Notifications table (checkbox/name/sound/priority) and the Unlocks catalogue's card grid both reflow instead of overlapping.

## 4. Achievements — filters and My Class

- [ ] Category filter cycles through all categories (ALL, EXPLORATION, COMBAT, DUNGEONS, PROFESSIONS, CLASSES, and any from AchievementExpansion/MetaAchievements) via left-click (forward) and right-click (back).
- [ ] Selecting CLASSES reveals the class-filter row; selecting any other category hides it.
- [ ] Class filter: MY_CLASS resolves to your logged-in character's class; ALL_CLASSES shows all 9 classes' achievements; picking a specific class token isolates just that class regardless of your own.
- [ ] Status filter: ALL / UNLOCKED / LOCKED each show the expected subset.
- [ ] "Enabled modules only" toggle hides feature-gated categories when their feature is off.
- [ ] Search box filters by title/description/category text live as you type.
- [ ] **Text no longer cuts off**: confirm title, detail, progress, and reward lines are all fully readable on every row, including achievements with long names/descriptions and large reward numbers (+100 coins, +99 XP style values).
- [ ] Prev/Next paging: confirm the page indicator, and that Prev disables on page 1 / Next disables on the last page, for both a small filtered set (few achievements) and the full unfiltered catalog.
- [ ] Drawer panel (embedded in the CreshChat dock, not the standalone window) still scrolls correctly and shows the same fixed layout (this one was NOT converted to paging this session — confirm it still works as a scrolling list).

## 5. Locked / Ready / Unlocked / Equipped states

Applies to: CreshGames Unlocks catalogue, Achievements windows, Azeroth
Chronicle/Battle Pass window.

- [ ] LOCKED entries show the locked visual state and clicking them navigates to the relevant Pass/Mastery/achievement rather than erroring.
- [ ] AVAILABLE/READY entries are visually distinct from LOCKED and UNLOCKED.
- [ ] UNLOCKED entries show the unlocked visual state and no longer offer a "claim" action.
- [ ] EQUIPPED (dungeon armour / minion skins) shows a distinct state from plain UNLOCKED, and equipping a different unlocked item updates which one shows EQUIPPED.
- [ ] Claiming a Battle Pass reward moves it from READY to UNLOCKED immediately, updates the hero progress bar, and "CLAIM ALL READY" clears every ready reward in one click.

## 6. Solo / Multiplayer / Unlocks routing

- [ ] CreshGames hub opens to whichever tab was last active (persisted across `/reload`).
- [ ] Switching Solo → Multiplayer → Unlocks → Solo preserves each tab's own scroll/filter/page state independently.
- [ ] A locked Unlocks entry's action button correctly opens the Solo or Multiplayer game (or Battle Pass/Achievements window) it's gated behind.
- [ ] Opening the hub from the launcher, from a slash command, and from a notification card's click-through all land on the expected tab.

## 7. Notification sources

All 9 CreshChat categories (Whispers, Guild, Party invitations, Party
messages, Public mentions, Friends, Quest dialogue, System, Games and
rewards) plus CreshGames/CreshCollect-sourced cards:

- [ ] Each category's checkbox in the new Notifications table actually suppresses its card popup when unchecked, and the card popup still fires when checked.
- [ ] Each category's Sound dropdown actually changes which sound plays (or silences it on OFF).
- [ ] Each category's Priority dropdown actually changes card placement (Critical/High → main-card lane, Normal/Low → compact slide-out) and expiry behavior.
- [ ] Guild card trigger dropdown (All / Mentions only / Never) still works from its new "Category-specific options" location.
- [ ] "Hide unavailable-player whisper line" toggle still works from its new location.
- [ ] Preview buttons (Whisper/Guild/Party/Friend/Reward/System) each produce a visually correct card.
- [ ] A real party invite still shows the actionable ACCEPT/DECLINE card and both buttons work.
- [ ] Trigger a burst (e.g. several whispers from different people within a second, or join a busy guild channel) and confirm: oldest cards get replaced instead of stacking unbounded, and repeated whispers from the *same* person coalesce into one card with an incrementing count instead of spawning duplicates.
- [ ] With CreshChat absent (CreshGames/CreshCollect only), confirm their own notification cards still render using the fallback renderer (no CreshChat-specific styling, but no errors either).

## 8. Reload / relog persistence

- [ ] Achievements window: category/class/status filters, search text, and current page reset sensibly after `/reload` (confirm what actually happens — either persists or cleanly resets to ALL/page 1, not a stale/broken state).
- [ ] Azeroth Chronicle window: filter and current page after `/reload`.
- [ ] CreshGames hub: active tab (Solo/Multiplayer/Unlocks) persists across `/reload` and full relog.
- [ ] Settings window: last-viewed page per product persists or resets cleanly.
- [ ] Notification preferences (per-category enabled/sound/priority) persist exactly across `/reload` and relog.
- [ ] Theme selection (including Custom colors) persists across relog.
- [ ] Window positions (Achievements, Chronicle, Settings, main chat) persist across relog.

## 9. Combat safety

- [ ] Enter combat with the Settings window open — confirm no taint/protected-action errors and the window remains usable (or gracefully doesn't require a protected action at all).
- [ ] Enter combat with a notification card animating in/out — confirm no errors.
- [ ] Trigger a party-invite card while in combat — confirm ACCEPT/DECLINE still work (or fail gracefully without a taint error) per WoW's protected-function rules for party invites.
- [ ] Open/close the Achievements, Chronicle, and Unlocks windows while in combat.
- [ ] Confirm no addon tries to move/reposition a protected frame during combat lockdown.

## 10. Multiplayer compatibility

- [ ] Two players with CreshGames run a multiplayer game end-to-end (whichever games support multiplayer) — confirm no protocol errors and the payload-size guard doesn't reject normal traffic.
- [ ] One player has CreshSuite addons, the other doesn't (or has a different version) — confirm no errors on either side, graceful degradation.
- [ ] Achievements/Chronicle/Unlocks state stays account-wide-correct per character (not corrupted by another player's data).

---

## Notes for whoever runs this

- Check off items as you go; leave a one-line note next to anything that fails instead of just leaving it unchecked, so it's clear whether it wasn't tested yet vs. actually broke.
- If you find a Lua error, capture the full error text (BugSack/BugGrabber output if installed, or the default UI error frame text) — file/line plus the exact action that triggered it is what's needed to fix it.
- This checklist doesn't replace the automated test suite (`tools\Run-Tests.ps1`, 27 suites / 1175 assertions, all currently passing) — it covers what those tests structurally can't: real rendering, real WoW API behavior, real timing/animation, and real multiplayer.
