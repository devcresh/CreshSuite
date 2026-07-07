# Phase 6 — Simplify every settings page

## Context

All three addons' settings currently mix genuine preferences with statistics,
records, and lengthy prose, spread across too many pages (CreshChat alone has
11), all built eagerly the first time Settings opens (every control on every
page, whether visited or not), with no search, no collapsible grouping, and
destructive reset buttons that fire instantly with zero confirmation.

**Architecture already in place, confirmed by research, that this phase
builds on rather than replaces:**

- `addons/CreshChat/Settings.lua` is the one shared settings *shell* for all
  three addons. CreshChat's own 11 pages are built directly inside it;
  CreshGames (`GamesSettings.lua`) and CreshCollect (`CollectSettings.lua`)
  each call `Suite:RegisterSettingsProvider(addonName, { pages = { {key,
  label, desc, build(builder)}, ... } })`, and `Settings:
  BuildProductSettingsPanel` renders their pages through the *exact same*
  `Settings:NewBuilder`/`Builder` machinery CreshChat's own pages use
  (`Settings.lua:1893-1992`). One redesign of `Builder` benefits all three
  addons' pages simultaneously — this is the single highest-leverage file.
- The `Builder` object (`Settings:NewBuilder`, `Settings.lua:661-802`) already
  provides the auto-flow layer every page's `build(builder)` callback uses:
  `Section/HalfToggle/HalfColor/Dropdown/Slider/Note/Buttons/Finish`. It
  already tracks a vertical cursor and 2-column pairing — it just hardcodes a
  different pixel increment per method (33/37/54/34) instead of shared
  constants. This is what "standardise control spacing" extends, not
  replaces.
- **Both eager-build points are identified and confirmed**: `Settings:Build()`
  (`Settings.lua:1669-1679`) calls all 11 `Settings:BuildXxx(page)` functions
  unconditionally the first time Settings ever opens (once per session, but
  paying for every page regardless of which one is visited); `Settings:
  BuildProductSettingsPanel` (`Settings.lua:1936-1985`) does the identical
  thing for every provider page. Both need the same fix: build the tab +
  empty container up front, defer the actual `BuildXxx`/`pageSpec.build`
  call to first `SetPage`/`SetProductPage` for that key.
- **No search, confirmation dialog, or collapsible-section primitive exists
  anywhere in the file today** (confirmed by full-file grep) — all three are
  net-new additions to the shared `Builder`/`Settings` layer.
- The only existing destructive action with no confirmation: CreshChat's
  "RESET UI" (`Settings.lua:1342` → `Core.lua:3242`, wipes `db.ui/colors/
  panelScale/positions/sizes`) and "COPY UI + LAYOUT" (`Settings.lua:1249`,
  full appearance overwrite from another character). CreshGames' "RESET GAME
  STATS" and CreshCollect's "RESET ACHIEVEMENTS"/"RESET COLLECTIONS" are the
  same pattern (immediate `ReloadUI()`, zero confirmation).
- Two real bugs found that migration should fix in passing (not scope
  creep — the controls are being rebuilt anyway): CreshChat's General-page
  "OPEN PROGRESS HUB" button references `CC.ProgressHub`, which is never
  assigned anywhere in the addon — the section silently never renders. Fix
  by routing through `_G.CreshSuite:GetService("OpenProgressHub")`, the same
  pattern already used correctly in `Core.lua:3455`/`Launcher.lua:147-153`.
  CreshCollect's "OPEN AZEROTH CHRONICLE" button checks `COL.BattlePass.Open`
  (a method that doesn't exist — `BattlePass.lua` only has `OpenWindow`), so
  it always silently falls through to a `CC.UI:OpenGameDrawer` fallback; fix
  to call `COL.BattlePass:OpenWindow()` directly. Also: CreshGames' Tetris
  "Versus CPU mode" dropdown offers `ENDLESS/TIMED/CLASSIC` but the game only
  implements `ENDLESS/ATTACK` (`SoloGames.lua:263-264`) — fix the dropdown's
  value list to match reality. CreshCollect's Achievements page has no
  "open achievements" button at all (a gap, not a regression) — add one
  (`COL.Achievements:ToggleWindow()` exists and is unused).

## Design

### 1. Shared `Settings.lua` infrastructure (built once, used by all three addons)

- **Lazy page building.** `CreatePage`/tab-button creation stays eager
  (cheap: empty scroll+canvas); each page gets a `built` flag. `SetPage(name)`
  and `SetProductPage(productKey, pageKey)` call the page's `build` function
  on first visit only, then flip the flag. `Settings:Build()`/
  `BuildProductSettingsPanel` no longer call `BuildXxx`/`pageSpec.build`
  directly — they just register which function to call later. This is the
  minimal change satisfying "initial settings open creates substantially
  fewer frames" without touching the builder API pages already use.
- **Centralized spacing constants**: replace the hardcoded 33/37/54/34 (etc.)
  literals in `CreateToggle`/`CreateDropdown`/`CreateSlider`/`CreateColorRow`
  and the `Builder` methods with named locals (`ROW_HEIGHT`, `DROPDOWN_ROW`,
  `SLIDER_ROW`, `BUTTON_ROW`) defined once near the top of the file.
- **`Builder:CollapsibleSection(title, buildFn)`** — new method: draws a
  clickable header (▸/▾ indicator, reuses the existing `Section` divider
  style), starts collapsed, and on expand calls `buildFn(builder)` to lazily
  construct its controls into a sub-frame whose height feeds back into
  `Finish()`'s canvas-height calculation. Session-only state (no new
  SavedVariables key — collapsing is about scannability, not a persisted
  preference). Used for: CreshChat Advanced's diagnostic buttons (Health/
  Optimise/Status/Test All/Version/Dev Report/Assets — 7 rarely-used dev
  utilities that don't need to be visible by default), and any other
  page-specific "uncommon control" cluster found during implementation.
- **Two-step confirmation**: one `StaticPopupDialogs` entry (WoW's own
  native confirm-dialog idiom — the standard, zero-new-frame way every
  addon does this) registered once, wrapped as `Settings:ConfirmAction(
  message, onConfirm)`. Applied to: CreshChat's "RESET UI" and "COPY UI +
  LAYOUT", CreshGames' "RESET GAME STATS", CreshCollect's "RESET
  ACHIEVEMENTS" and "RESET COLLECTIONS". Left as one-click (already low
  blast-radius, reversible): "RESET DOCK", "CORE ONLY"/"CHAT FOCUS" presets,
  "RESET LAUNCHER PREFS" (both addons).
- **Search**: pages declare a `keywords` string/array alongside their
  existing `label`/`desc` (a small addition to the page-spec shape already
  used by `BuildProductSettingsPanel`, and mirrored for CreshChat's own
  pages). `Settings:Search(query)` matches the active product's page
  list only (label + desc + keywords + labels of any already-built
  controls on that page, via `self.refreshables`) — satisfies "search finds
  controls across the active product" at the practical granularity of
  "jump to the page containing that control" (a control on an unbuilt page
  can't be scrolled-to/highlighted before the page exists anyway). Selecting
  a result calls `SetPage`/`SetProductPage`, which lazily builds if needed.
  Search box sits above the page-tab sidebar, one per product (searching
  while on CreshChat's tab searches CreshChat's 6 pages; switching product
  tabs searches that product's own pages).
- **Disabled-state explanations**: continue the existing convention
  (`Settings.lua` already does this for Notifications pages: "Requires
  CreshChat") — every new page/control that's conditionally unavailable gets
  a one-line `Note` explaining why, not just a greyed-out control.

### 2. CreshChat: 11 pages → General / Chat / Windows / Notifications /
   Appearance / Advanced

| New page | Absorbs | Notes |
|---|---|---|
| **General** | `BuildGeneral` + `BuildProfiles` | Profiles' "COPY UI + LAYOUT" gets confirmation (see above); fixes the dead `CC.ProgressHub` button. |
| **Chat** | `BuildGuild` + `BuildChannels` + `BuildConsole` | All three are chat-content/color/tab-visibility, none touch window chrome — confirmed by reading every control. |
| **Windows** | `BuildDock` + `BuildWindows` | Dock is composer/dock *window* geometry+motion despite its name, not chat content — belongs with Windows, not Chat. Keeps the shared `CC.db.ui.animationDuration` slider here (single control instance; Notifications gets a one-line note pointing to it here, mirroring the existing Guild→Notifications cross-reference pattern already in the codebase). |
| **Notifications** | `BuildAlerts` only | Already a complete, coherent page — no content moves in or out beyond the animationDuration note above. |
| **Appearance** | `BuildThemes` only | Global theme + 7 surface colors; Guild/Channel colors stay in Chat (grouped by "what it's for," not "what kind of control it is"). |
| **Advanced** | `BuildModules` + `BuildAdvanced` | Diagnostic buttons (Health/Optimise/Status/Test All/Version/Dev Report/Assets) become one `CollapsibleSection("Diagnostics", ...)`; drop the redundant "MODULES" chat-dump button (duplicates the Modules toggle list one section up) and the redundant "RESTORE BLIZZARD CHAT" button (duplicates General's toggle); "RESET UI" gets confirmation. |

### 3. CreshGames: 9 pages → General / Gameplay / Notifications / Advanced

| New page | Absorbs | Notes |
|---|---|---|
| **General** | `GENERAL` | Unchanged (launcher toggle + note). |
| **Gameplay** | `AUDIO` (all 6 controls) + the 2 genuine settings from `TETRIS` (`cpuLevel`, `cpuVersusMode` — fixing the stale ENDLESS/TIMED/CLASSIC value list to ENDLESS/ATTACK) | Every statistics block (`SOLO`, `MULTIPLAYER`, `TETRIS` records, `DUNGEON`, `CONTROLS`) is replaced by short summary `Note`s + `Buttons` calling `CG.SoloGames:SelectHubTab("SOLO"\|"MULTIPLAYER"\|"UNLOCKS")` — reusing the Phase 4/5 hub and catalogue instead of re-displaying the same numbers a third place. |
| **Notifications** | `NOTIFICATIONS` | Unchanged (dynamic per-category loop). |
| **Advanced** | `RESET` | "RESET GAME STATS" gets confirmation; "RESET LAUNCHER PREFS" stays one-click. |

### 4. CreshCollect: 8 pages → Tracking / Achievements / Chronicle &
   Collections / Notifications / Advanced

| New page | Absorbs | Notes |
|---|---|---|
| **Tracking** | `PROGRESS` + `COMBAT` | Keep "OPEN PROGRESS HUB" (`COL.ProgressHub:Toggle()`); collapse the exploration-stat `Note`s duplicated across both old pages into one summary line. |
| **Achievements** | `ACHIEVEMENTS` | Drop raw count/XP/coin `Note`s; **add** the missing `Buttons({"OPEN ACHIEVEMENTS", function() COL.Achievements:ToggleWindow() end})` (currently absent entirely). |
| **Chronicle & Collections** | `BATTLEPASS` + `CURRENCY` + `COLLECTIONS` | One "OPEN AZEROTH CHRONICLE" button, fixed to call `COL.BattlePass:OpenWindow()` directly; one short coin-balance summary line (drop itemized source breakdown); one short cosmetics-count summary line (drop itemized per-bucket counts — the full browsable version is CreshGames' Unlocks catalogue, cross-addon, not reproduced here). |
| **Notifications** | `NOTIFICATIONS` | Unchanged. |
| **Advanced** | `RESET` | "RESET ACHIEVEMENTS" and "RESET COLLECTIONS" get confirmation; "RESET LAUNCHER PREFS" stays one-click. |

### Scope boundary (explicit)

"Standardise toggle language / dropdown wording" is applied to *new* text
this phase introduces (summaries, confirm-dialog copy, search UI, page
descriptions) and to the handful of controls the bug-fixes above touch
directly — this phase does not rewrite the wording of the ~100 existing,
already-working control labels across three files; that's a much larger,
separate copy-editing pass with its own risk profile, not a navigation
restructuring task.

## Files touched

- `addons/CreshChat/Settings.lua` — lazy build, spacing constants,
  `CollapsibleSection`, `ConfirmAction`, `Search`, the 6-page restructure,
  bug fixes.
- `addons/CreshChat/Core.lua` — no logic changes expected; confirm
  `ResetUISettings`/`CopyUIFromCharacterProfile` remain called exactly as
  today, just from behind the new confirmation step.
- `addons/CreshGames/GamesSettings.lua` — 9→4 page restructure, hub-redirect
  buttons, Tetris dropdown fix.
- `addons/CreshCollect/CollectSettings.lua` — 8→5 page restructure,
  `BattlePass:OpenWindow()` fix, new Achievements-open button.
- Tests: extend `tests/SettingsShellTests.lua` with the same "mirror the
  pure logic inline" convention it already uses for `detectAddonStatus`
  (the file's own header explains why: `Settings.lua` needs the full WoW
  UI environment and can't load standalone) — add coverage for the new
  search-matching predicate and the lazy-build-flag logic as pure, inlined
  functions; add a new small test asserting each provider's registered
  `spec.pages` list matches the new 4/5-page structure by key.

## Verification

1. `tools/Validate-Addons.ps1` — expect PASS.
2. `tools/Run-Tests.ps1` — all existing suites green + updated
   `SettingsShellTests.lua`.
3. Manual diff review: nil-safety, Lua 5.1 compatibility, no duplicate
   frame names, every old SavedVariables key still referenced somewhere.
4. In-game instructions: open Settings, confirm each of the three product
   tabs shows its new, shorter page list; confirm a page you haven't
   clicked yet builds no frames until clicked (spot-check via `/framestack`
   or simply that opening Settings feels instant regardless of history
   size); use search on each product tab and confirm it jumps to the right
   page; expand/collapse the Advanced diagnostics section; trigger "RESET
   UI" and confirm the two-step dialog blocks an accidental single click;
   confirm every hub-redirect button (Progress Hub, Achievements, Azeroth
   Chronicle, Solo/Multiplayer/Unlocks) actually opens its target window;
   change the theme and confirm colors update live across every page
   already visited.
5. No deploy or commit — stop after this phase for approval.
