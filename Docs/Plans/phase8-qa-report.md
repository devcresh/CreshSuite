# Phase 8 — Full Regression, Performance, and In-Game QA Preparation

Status: static analysis and automated testing complete. **No in-game testing
has been performed.** Nothing in this report may be treated as "done" until
the checklist in `phase8-qa-checklist.md` is run in a live client and you
confirm the results. No files were deployed or committed as part of this
phase.

---

## Task 1 — Automated tests + Validate-Addons.ps1

```
.\tools\Validate-Addons.ps1   → 68 checks passed, 0 warnings, 0 errors
.\tools\Run-Tests.ps1         → 27 suites, 1175 assertions, 0 failures
```

All 27 suites passed: Bridge, UI Service, Suite Notifications, Database
Migration, Settings Shell, Slash Command, Game Drawer Availability,
Achievements Availability, Class Mastery Filter, Progression Performance,
Progression Window, Progress Overview, Launcher Routing, Launcher Layout,
Launcher Animation, Collection Unlock, BattlePass/CardDeck Recursion, Reward
Registry, Arcade Pass, Mastery Conversion, Games Achievements, Chronicle,
Theme Achievement, Game Level Migration, Unified Progression UI, Games Hub
Routing, Games Unlocks Catalogue.

## Task 2 — TOC and load order

- All three TOCs (`CreshChat.toc`, `CreshGames.toc`, `CreshCollect.toc`)
  list exactly the `.lua` files present on disk in each addon folder — no
  orphaned files, no missing references (cross-checked independently of
  Validate-Addons.ps1).
- Validate-Addons.ps1's own load-order checks (Suite.lua first, Database
  file second, Settings/CollectSettings/GamesSettings last, SavedVariables
  declared and referenced) all passed for all three addons.

## Task 3 — Static addon-combination safety

Rather than manually toggling addons on/off seven times (which still needs
to happen in-game — see the checklist), this was verified by tracing every
`_G.CreshChat` / `_G.CreshGames` / `_G.CreshCollect` access site across all
~65 Lua files in the three addons (66 total call sites traced) and
confirming each one degrades gracefully when the target addon is absent.

**Result: one confirmed violation, everything else clean.**

### 🔴 Critical — `CreshCollect/ProgressHub.lua:212-215` hard-fails without CreshChat

```lua
function Hub:Build()
    if self.frame then return self.frame end
    local UI = CC.UI
    if not UI then return nil end
```

`CC.UI` resolves to CreshChat's own internal `UI` module — not the shared,
addon-agnostic `_G.CreshSuiteUI` bridge that this same file already imports
correctly and uses everywhere else for palette/backdrop/text/tab rendering.
This means the Progress Hub (the World/Quest/Combat tracking window) **can
never open when CreshChat is not loaded**, directly contradicting the
project rule that each addon must fully function with the other two absent.

Confirmed reachable without CreshChat: launcher's "Prg" button → Suite
service `OpenProgressHub` (registered unconditionally) → `ProgressOverview`
window (itself CreshChat-independent) → its "WORLD / QUESTS / COMBAT" nav
button → `COL.ProgressHub:Toggle()` → `Build()` returns `nil` → **the button
silently does nothing, no error, no feedback.** A player running
CreshCollect standalone would perceive this as a dead/broken button with no
diagnostic trail.

Every other standalone window in CreshCollect (`Achievements.lua`,
`BattlePass.lua`, `ProgressOverview.lua`) correctly builds without requiring
`CC.UI`, using it only optionally for cosmetic extras. `ProgressHub.lua` is
the one outlier.

**This was not fixed** (Phase 8 is analysis-only per your instructions) —
flagging for a decision on whether to fix it now or schedule it.

### Everything else checked clean

- CreshChat: zero unguarded `_G.CreshGames`/`_G.CreshCollect` dotted
  accesses found (regex-verified for the "missing `and` before the dot"
  pattern specifically).
- CreshGames: all `_G.CreshChat`/`_G.CreshCollect` access goes through the
  established nil-safe `CC`/proxy pattern, with three narrow exceptions
  (below, category 4 findings) where a guard checks the wrong depth
  (`CC.UI` truthy but then indexes `CC.db.ui` without also checking
  `CC.db`) — real defects, but data-shape depth bugs, not addon-absence
  bugs (CreshChat being fully absent is handled fine; the issue is a
  narrow timing/shape edge case even when CreshChat *is* present).
- CreshCollect: 33 cross-addon call sites traced; only the ProgressHub
  case above fails to degrade gracefully.

## Task 4 — Code review findings

All findings below were confirmed by an independent agent reading the
actual source per addon (not inferred). Severity as assessed by each
reviewer. File:line references are relative to the repo root.

### CreshChat

| # | Severity | Location | Finding |
|---|----------|----------|---------|
| 1 | High | `addons/CreshChat/Settings.lua:2400-2427` (`Settings:RefreshProductPage`) | Every call creates a brand-new canvas frame and rebuilds all controls from scratch; the previous canvas is never hidden or reused — orphaned frame left behind each call. Not currently self-triggered from inside CreshChat, but it's a public method whose own doc comment says it exists for CreshGames/CreshCollect to call when their live data changes. **Needs a check**: does CreshGames or CreshCollect actually call this repeatedly? If so, this leaks one full page's worth of frames per call over a session. |
| 2 | Medium | `addons/CreshChat/UI.lua:3332-3337` (`RefreshGameDrawer`) | Reads `save.frogger.unlocked`, `save.dungeon.bestRoom`, `save.chess.level`, `save.holdem.bankroll`, `save.blackjack.bankroll` with no nil-guard on the per-game subtable, unlike the sibling `save.tetris` read one line below which is correctly guarded. Depends on CreshGames' save shape (not verified here) — could throw "attempt to index a nil value" for a character that never played one of those games. |
| 3 | Low | `addons/CreshChat/UI.lua:3702, 4730, 5630, 2683` (`BuildMainFrame`, `BuildQuickInput`, `BuildCombatPanel`, `BuildSettingsPanel`) | These four singleton-frame builders have no internal `if self.frame then return end` guard of their own — currently harmless because their only caller (`UI:Initialize()`) is itself guarded and only invoked once at login, but it's an inconsistency with every other builder in the file. |

Nil access (beyond #2), duplicate events, unbounded OnUpdate, and
unsupported Lua/API usage: **no findings** — all confirmed clean by direct
inspection.

### CreshGames

| # | Severity | Location | Finding |
|---|----------|----------|---------|
| 4 | Medium | `addons/CreshGames/Games.lua:755` (`ShowChallengePopup`) | `if CC.UI and CC.UI.ApplySafeFrameScale then CC.UI:ApplySafeFrameScale(popup, (CC.db.ui and CC.db.ui.scale) or 1, 22) end` — indexes `CC.db.ui` without first checking `CC.db` itself is non-nil. `CC.UI` being truthy doesn't guarantee `CC.db` is populated yet. The identical call in `SoloGames.lua:470` guards this correctly (`CC.db and CC.db.ui and CC.db.ui.scale`) — this is a real deviation from the codebase's own established convention, in the same file that has the correct version elsewhere. |
| 5 | Medium | `addons/CreshGames/Games.lua:935` (`BuildGameWindow`) | Same defect as #4. |
| 6 | Low-Medium | `addons/CreshGames/GamesSettings.lua:150-152` | The notification-category toggle's setter writes `CC.db.notificationSources = CC.db.notificationSources or {}` without checking `CC.db` truthy first, while the paired getter two lines above does guard correctly. Toggling a category right after a fresh login (before CreshChat's `db` populates) could throw. |
| 7 | Low (latent, not currently triggered) | `addons/CreshGames/Games.lua:66-70` (`join()`) | Uses `ipairs` to build the network payload — a `nil` argument anywhere in a future `SendGame` call would silently truncate the outgoing message rather than error. Spot-checked every current call site (chess/Tetris/Pong/Hold'em); none currently pass `nil`. Flagging as a protocol robustness gap for future additions, not a live bug. |

Duplicate frames, duplicate events, unbounded OnUpdate, SavedVariables
migrations, unsupported Lua/API, and the multiplayer payload-size guard:
**no findings** — all confirmed clean, including a spot-check of the
largest realistic Tetris/Hold'em payloads against the 250-char guard in
`Games:SendRaw` (comfortably under budget).

### CreshCollect

| # | Severity | Location | Finding |
|---|----------|----------|---------|
| — | Critical | `ProgressHub.lua:212-215` | See Task 3 above — the addon-independence violation. |
| 8 | High | `AchievementExpansion.lua:875,860,957` shadowing `Achievements.lua:826,986,815` | **Two competing definitions of `BuildDrawerPanel`/`RefreshDrawerPanel`/`GetPanelHeight`** exist on the same `Achievements` table. `AchievementExpansion.lua` loads after `Achievements.lua` in the TOC and simply reassigns these three method names (unlike `BuildCatalog`, which is properly wrapped with a call-through to the original). Result: **~230 lines of `Achievements.lua` (826-1059) are dead code** — the live drawer panel is entirely `AchievementExpansion.lua`'s version, which is missing `Achievements.lua`'s "ENABLED MODULES ONLY" toggle and has no `META` category filter entry. Not a crash, but real, silent feature drift: editing `Achievements.lua`'s copy of these three methods (as this session did for the standalone-window pagination work) has **zero effect on the drawer panel actually shown in-game**. |
| 9 | Medium | `AchievementExpansion.lua:942-952` (the drawer panel that's actually live, per #8) | Builds one frame + 4 font strings per catalog entry — with ~571 achievements today (129 base + 300 expansion + 135 class + 7 meta), that's ~570 frames + ~2,280 font strings built synchronously the first time the drawer panel opens. **Important correction to this session's earlier assumption**: the "drawer panel still uses one-frame-per-entry, left out of scope" note from the Achievements/BattlePass pagination work was written believing `Achievements.lua`'s own `BuildDrawerPanel` was the live code — it is not (see #8). The actually-reachable drawer-panel code has this same unfixed cost, and at a larger catalog size than assumed. |
| 10 | Medium | `BattlePass.lua:865,1463,1764,1831` | The standalone Chronicle window's pool still builds `POOL_SIZE` (14, the *drawer's* constant) rows and its update loop still iterates all 14, even though pagination now only ever needs `WINDOW_PAGE_SIZE` (6) — unlike `Achievements.lua`'s window, which was correctly resized to exactly 6. Currently harmless (the extra rows land below the clipped viewport) but wasted work on every page-flip/claim/refresh, and would leak the next page's rows into view if the window were ever made taller. |
| 11 | Low | `Achievements.lua:1081`, `AchievementExpansion.lua:1030`, `ClassAchievements.lua:472` | `PLAYER_LOGIN` (and, for the third, also `PLAYER_ENTERING_WORLD`/`SPELLS_CHANGED`) triggers a full `EvaluateAll(true)` catalog scan from three independent frames — not a correctness bug (idempotent/reentrancy-guarded), just 2-3x redundant CPU work at login/zone-change. |
| 12 | Low | `ProgressHub.lua:142,155,181,193,199` | Reads `CreshCollectDB.gameProgression...` without a `type(CreshCollectDB)=="table"` guard first (contrast with `Achievements.lua`'s equivalent, which does guard). Only reachable if SavedVariables somehow failed to load — unlikely in practice. |

Verification of this session's own reworked code (explicitly requested):
`.creshDisabled` is correctly checked by both files' `winCreateButton`
helpers; `GoToPage` clamping is correct and identical in both; no stale
`windowRows` references remain anywhere. The only defect found in the new
code is #10 above (pool/page-size mismatch in `BattlePass.lua`'s window,
not `Achievements.lua`'s, which was sized correctly).

SavedVariables migrations and unsupported Lua/API usage: **no findings** —
confirmed clean, including the v1/v2/v3 `CreshCollectDatabase.lua`
migrations and every module's own `Ensure()`.

### Findings summary

| Severity | Count | 
|---|---|
| Critical | 1 (ProgressHub.lua addon-independence violation) |
| High | 2 (Settings.lua frame leak; AchievementExpansion.lua dead-code shadow) |
| Medium | 5 (RefreshGameDrawer nil-guard; 2× Games.lua CC.db.ui depth; AchievementExpansion.lua per-entry frames; BattlePass.lua pool/page mismatch) |
| Low / Low-Medium | 6 |

None of these were fixed this phase (analysis-only, per your instructions).
Recommend deciding whether to fix the Critical + 2 High findings now (all
three are small, targeted, low-risk fixes) or schedule them as their own
phase.

## Task 5 — Notification profiling comparison

CreshSuite already has a purpose-built profiling harness for exactly this
comparison: `shared/SuiteNotifications.lua`'s `SetProfilingEnabled`,
`ResetProfile`, and `GetProfileReport`, using WoW's own `debugprofilestop()`
timer, bucketed into **cold** (pool empty, had to build a new card frame)
vs **warm** (pool hit, or an existing whisper conversation coalesced) paths,
broken into stages: `acquire_build` (cold only — the actual `CreateFrame` +
widget construction cost), `populate` (text/texture updates), `layout`
(positioning/stacking), `sound` (the `PlaySound`/`PlaySoundFile` call
itself), and `push_total` (end to end). This was **not built this phase**
— it already existed from earlier work — but nobody has used it to actually
capture numbers. That still needs to happen in-game:

```
-- in-game, after logging in and generating some notification traffic:
/run CreshSuiteNotifications:SetProfilingEnabled(true)
-- ...trigger the scenarios below...
/run print(CreshSuiteNotifications:GetProfileReport())
```

Analysis of what determines each comparison point, from reading the code:

- **First card vs. warm card**: the codebase already mitigates the naive
  "first card is always cold" case — a login-time pre-warm
  (`shared/SuiteNotifications.lua`, "Cold-start reduction") acquires 2 pool
  cards 0.5s and 1.2s after `PLAYER_LOGIN`, before any real event can
  plausibly arrive. In practice, "first card" should already be warm by the
  time a player can act; a genuinely cold card only happens if a burst
  exceeds the pre-warmed pool size before it's had time to grow. The
  `acquire_build` stage is the only one that differs between cold/warm —
  `populate`/`layout`/`sound` cost the same either way.
- **Sound on/off**: `CC:PlaySoundPreset` returns `false` immediately at the
  top when the category's sound is `OFF` — effectively free. When on, it's
  a single native `PlaySound`/`PlaySoundFile` call wrapped in `pcall`; no
  per-frame cost either way. Expect the `sound` stage in the profiling
  report to show near-zero for OFF and a small, roughly constant cost for
  ON regardless of which sound preset.
- **Icon on/off (and complexity)**: found a third, related lever beyond
  simple on/off — `UI:UpdatePlayerPortrait`'s `portraitStyle` setting
  (`CLASS`/`2D`/`3D`) changes what the icon actually renders: `CLASS` is a
  class-colored ring + text initial (cheapest, no texture/model load),
  `2D` loads a real portrait texture via `SetPortraitTexture` (moderate),
  `3D` creates and updates an actual `PlayerModel` (heaviest — a live 3D
  model render). `showPortraits == false` skips all of it. Worth profiling
  all three styles, not just on/off, if this matters to you.
- **One card vs. a burst**: two mechanisms are already in place —
  (a) repeat whispers from the same person **coalesce** into one card with
  an incrementing count (`cardCoalesce` setting, default on) instead of
  spawning N cards, and (b) once the card limit is hit (default 6
  slide-outs / 4 main cards), `MakeRoomForSlideToast` force-dismisses the
  oldest non-protected card immediately (no slide-out animation) to make
  room for the new one. Expect burst scenarios to show a mix of warm
  (recycled) and possibly one cold acquire if the burst is the first
  traffic of the session, then all subsequent cards in the burst reusing
  recycled frames.
- **CreshChat present vs. absent**: `shared/SuiteNotifications.lua`'s
  `buildCard()` is a fully self-contained renderer (own `CreateFrame`, own
  textures/fonts — no `_G.CreshChat` reference in construction at all).
  When CreshChat is present, cosmetic settings (theme colors, sizing) are
  read from `CC.db`; when absent, safe hardcoded defaults apply via the
  `ccDB()` helper's nil-chain. This is a *different, separate* card
  renderer from CreshChat's own native `UI.lua` toast system (used for
  CC's own chat-sourced whispers/guild/etc.) — worth being aware that the
  addon currently has two parallel card-rendering pipelines: CC's own
  (`UI.lua`, for its own chat events) and the shared one
  (`SuiteNotifications.lua`, for cross-addon CG/COL events, also usable by
  CC directly). This wasn't flagged as a bug — it may be intentional so
  CG/COL can render cards without depending on all of CC's UI machinery —
  but it's a real architectural fact worth confirming is intended.

## Task 6 — WoW test checklist

Written to `Docs/Plans/phase8-qa-checklist.md` — covers all 10 categories
you asked for (addon combinations, themes, UI scale/resolution, Achievement
filters + My Class, Locked/Ready/Unlocked/Equipped states, Solo/Multiplayer/
Unlocks routing, all notification sources, reload/relog persistence, combat
safety, multiplayer compatibility), plus a note to add checks for the two
newly-found issues below once you decide whether to fix them first.

**Recommend adding to the checklist once you've decided on the findings
above:**
- Open CreshCollect standalone (no CreshChat) → click the Progress Hub
  launcher button → confirm whether it silently fails (current behavior)
  or opens correctly (if #Critical is fixed).
- Time how long the Achievements drawer panel (not the standalone window)
  takes to first open, to gauge whether the ~570-frame construction
  (finding #9) is perceptible in practice.

## Task 7 — Changed files by phase

Nothing has been committed since `d5f0153` (the last merge), so this is a
single accumulated working-tree diff, not separate commits — grouped below
by my own knowledge of which phase touched each file. **Phases 1-4 are
lower-confidence** (that work predates the detailed context available to
me this session — file groupings are inferred from purpose, not verified
step-by-step); **Phases 5-6 and the two bug-fix rounds are high-confidence**
(done with full detail this session).

**Phase 1 (CreshSuiteUI foundation) — inferred:**
`shared/CreshUI.lua` (new) + per-addon copies (`addons/*/CreshUI.lua`, new),
`shared/Launcher.lua`, per-addon `Launcher.lua`.

**Phase 2 (Achievements filtering) — inferred:**
`addons/CreshCollect/Achievements.lua` (category/class/status cycle
controls), likely touching `ClassAchievements.lua`/`AchievementExpansion.lua`
/`MetaAchievements.lua` (not independently confirmed this session).

**Phase 3 (Suite notifications) — inferred:**
`shared/SuiteNotifications.lua` (new) + per-addon copies (new), 
`addons/CreshChat/Notifications.lua`, `NotificationsAdapter.lua`,
`addons/CreshGames/GamesNotifications.lua` (new),
`addons/CreshCollect/CollectNotifications.lua` (new),
deletion of `addons/CreshChat/NotificationCard.lua` (superseded).

**Phase 4 (Unified CreshGames Hub) — inferred:**
`addons/CreshGames/SoloGames.lua`, `Games.lua`, `GameProgression.lua`,
`DungeonCrawlerContent.lua`, `DungeonDwellersProgression.lua`,
`TetrisThemes.lua`, `GamesAchievements.lua`, `GamesDungeonAchievements.lua`,
`GamesBattlePass.lua`, `CreshGames.lua`/`.toc`.

**Phase 5 (Unlocks tab / catalogue) — confirmed:**
`addons/CreshGames/GamesUnlocksCatalog.lua` (new),
`tests/GamesUnlocksCatalogTests.lua` (new).

**Phase 6 (Settings simplification) — confirmed:**
`addons/CreshChat/Settings.lua`, `addons/CreshGames/GamesSettings.lua`,
`addons/CreshCollect/CollectSettings.lua`, `tests/SettingsShellTests.lua`.

**Bug-fix round 1 (overlap/blank-dropdown fix + Unlocks grid redesign) —
confirmed:** further edits to `Settings.lua` (Relayout/Refresh fix) and
`GamesUnlocksCatalog.lua` + its test file (scroll list → paginated grid).

**Bug-fix round 2 / this session's latest work — confirmed:**
`addons/CreshCollect/Achievements.lua` (3-line row layout + Prev/Next
pagination), `addons/CreshCollect/BattlePass.lua` (Prev/Next pagination),
`addons/CreshChat/Settings.lua` (Notifications compact table),
`tests/ProgressionWindowTests.lua`, `tests/ClassMasteryFilterTests.lua`.

**Files whose phase attribution I can't confidently place** (present in
`git status` but not independently traced this session):
`addons/CreshChat/Core.lua`, `Developer.lua`, `UI.lua`,
`addons/CreshCollect/CreshCollect.lua`, `ProgressHub.lua`, `Progression.lua`,
`addons/CreshGames/CreshGamesDatabase.lua`,
`tests/ArcadePassTests.lua`, `BattlePassCardDeckRecursionTests.lua`,
`DatabaseMigrationTests.lua`, `RewardRegistryTests.lua`,
`tools/Run-Tests.ps1`, `tools/Validate-Addons.ps1`, `.gitignore`,
`AGENTS.md`, `CLAUDE.md`. Untracked new test files
(`tests/CreshUITests.lua`, `GamesHubRoutingTests.lua`,
`SuiteNotificationsTests.lua`) likely correspond to Phases 1/3/4
respectively but weren't independently verified.

**Full flat file list** (ground truth, independent of phase grouping): see
`git status --porcelain` — 43 modified, 1 deleted, 18 untracked (2 new
directories `Docs/Memory/`, `Docs/Plans/`; `Logs/` also untracked).

## Task 8 — Explicit statement

**No files were deployed. Nothing in this phase should be treated as
verified until you've run the checklist in a live client and confirmed the
results.** The Critical and High findings above are real, reproducible-by-
reading-the-code defects, but their in-game impact (especially the
`RefreshProductPage` frame leak, which depends on call frequency from
CreshGames/CreshCollect that wasn't traced) still needs confirmation.
