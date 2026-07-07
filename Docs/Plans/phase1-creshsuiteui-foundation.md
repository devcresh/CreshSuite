# Phase 1 — Cross-Addon UI Foundation (`CreshSuiteUI`)

## Context

`CreshChat`, `CreshGames`, and `CreshCollect` are an incomplete split of one
original monolithic addon. Every window-building file re-implements its own
copy of the same handful of primitives: a `palette()` resolver, `FALLBACK`
color table, `applyBackdrop`/`createButton`/`createText`/`darken`/`brighten`,
and (in some files) `setTabActive`. Confirmed byte-for-byte-numerically
identical duplicates exist in:

- `addons/CreshGames/Games.lua` (`palette`, `FALLBACK`, `applyBackdrop`, `createButton`, `createText`, `darken`, `brighten`)
- `addons/CreshGames/SoloGames.lua` (same set, `FALLBACK` plus two extra keys)
- `addons/CreshCollect/BattlePass.lua` (`winPalette`/`winApplyBackdrop`/`winCreateButton`/`winCreateText`/`winDarken`)
- `addons/CreshCollect/ProgressHub.lua` (`palette`, `applyBackdrop`, `createButton`, `createText`, `darken`, `setTabActive`)
- `addons/CreshCollect/ProgressOverview.lua` (`winPalette`/`winApplyBackdrop`/`winCreateButton`)

Worse, every `palette()` reads `CC.db.colors` directly, where `CC` is a
nil-safe proxy for `_G.CreshChat` — i.e. every non-CreshChat addon reaches
into CreshChat's *private* SavedVariables table to build its UI. This
violates AGENTS.md's "no direct table access across addon boundaries" rule.
`ProgressHub.lua` goes further and **writes** its own window position into
`CC.db.positions.progressHub` (CreshChat's db, not CreshCollect's own
`CreshCollectDB`) — a second, worse instance of the same violation.

Goal for this phase: introduce one small shared UI service that gives all
three addons the same button/backdrop/tab/scale/window/position primitives,
resolves colors through a real public API instead of a private table, and
works standalone with sane fallback colors when CreshChat is absent — without
redesigning or migrating any existing window wholesale.

## Design

### 1. New shared module: `shared/CreshUI.lua`

Follows the exact convention already established by `shared/Suite.lua` and
`shared/Launcher.lua`: one canonical source file, physically copied
byte-for-byte into each addon folder as `CreshUI.lua`, guarded by an
idempotent `_G.CreshSuiteUI` / `BRIDGE_VERSION` check (copy the same
if-already-loaded / version-mismatch-warn pattern used at the top of
`shared/Suite.lua`). Pure library — no `CreateFrame` calls at file scope, so
no named-global-frame or TOC-uniqueness concerns.

`_G.CreshSuiteUI` API:

- **Palette**
  - `CreshSuiteUI.FALLBACK` — one unified standalone color table (the
    superset of every duplicated `FALLBACK` found: `panel`, `panelSoft`,
    `panelRaised`, `border`, `accent`, `incoming`, `outgoing`, `text`,
    `muted`, `green`, `red`, `gold`, `quest`, `blue`), using the values that
    are already identical across all current copies.
  - `CreshSuiteUI:GetPalette()` — if `_G.CreshChatAPI.GetActivePalette` exists,
    return that (merged over `FALLBACK` for any missing key); otherwise
    return `FALLBACK`. Never touches `CC.db`.
- **Semantic states** — `CreshSuiteUI.STATE = { LOCKED, AVAILABLE, READY,
  UNLOCKED, EQUIPPED, DISABLED }` and `CreshSuiteUI:GetStateColor(state,
  palette)` mapping each to a palette-derived color (locked/disabled → dimmed
  `muted`, available → `panelRaised`/`border`, ready/unlocked → `accent`/
  `green`, equipped → `gold`).
- **Buttons/backdrop/tabs/text** — `ApplyBackdrop`, `CreateButton`,
  `SetButtonState`, `CreateTab`, `SetTabActive`, `CreateText`, `Darken`,
  `Brighten`, `TemplateName` — direct generalizations of the duplicated
  locals (same backdrop table, same hover/enter/leave behavior).
- **Scaling** — `GetSafeFrameScale` / `ApplySafeFrameScale`, moved here
  verbatim from `addons/CreshChat/UI.lua:122-143` (`UI:GetSafeFrameScale` /
  `UI:ApplySafeFrameScale`), generalized to not depend on `CC`.
- **Window chrome** — `CreateWindow(opts)` — minimal backdrop-templated frame
  constructor used only by the one proof conversion below; existing bespoke
  window builders are untouched this phase.
- **Position persistence** — `SavePosition(ownerDB, key, frame)` /
  `RestorePosition(ownerDB, key, frame, defaults)`. `ownerDB` is supplied by
  the caller (e.g. `_G.CreshCollectDB`), so each addon persists into its own
  SavedVariables — mirrors the "each addon owns its own state" spirit of
  `shared/Launcher.lua`'s `getLauncherDB()`.
- **Theme-change event** — reuses the existing `_G.CreshSuite` pub/sub bus
  (no new event system). `CreshSuiteUI:OnThemeChanged(callback)` subscribes
  to `"SUITE_THEME_CHANGED"` via `_G.CreshSuite:Subscribe` when the Suite
  bridge is present, and is a safe no-op when it isn't.

### 2. CreshChat: new public API method

In `addons/CreshChat/Core.lua`, next to the existing `ChatAPI.GetThemeInfo`
etc. (~line 24-49): add `ChatAPI.GetActivePalette()`, returning a shallow
copy of `CC.db.colors` (or `defaults.colors` if `CC.db` isn't ready). This is
the one addition needed so `CreshSuiteUI:GetPalette()` never has to read
`CC.db` directly.

In `addons/CreshChat/UI.lua`, wherever theme colors actually change today —
`ApplyThemePreset` and the `ApplyVisualSettings` path that already calls
`CC.Games:ApplyTheme()` / `CC.SoloGames:ApplyTheme()` (~line 6397) — add
`if _G.CreshSuite then _G.CreshSuite:Publish("SUITE_THEME_CHANGED") end`.

### 3. Packaging

- Add `CreshUI.lua` to all three TOCs immediately after `Launcher.lua`. This
  slot was checked against every rule `tools/Validate-Addons.ps1` enforces
  (Suite.lua first, `${name}Database.lua` second, main file directly after
  that, `*Settings.lua` last) — inserting after `Launcher.lua` in all three
  addons doesn't disturb any of them.
- In `tools/Validate-Addons.ps1`, add `"CreshUI.lua"` to the `$SharedFiles`
  array (~line 133) so the existing hash-sync-with-`shared/` check and the
  cross-addon-duplicate-declaration exemption cover it automatically, same
  as `Suite.lua`/`Launcher.lua`.
- No changes needed to `Deploy-Local.ps1` or the `Build-*.ps1` scripts — they
  already deploy/package whatever each addon's own TOC declares.

### 4. Minimal proof integration: `CreshCollect/ProgressHub.lua`

Smallest, most self-contained window among the duplicated files (781 lines,
a single floating summary window, currently has zero dedicated test
coverage so there's nothing to break). Convert only this file:

- Remove its local `palette`/`FALLBACK`/`BACKDROP`/`applyBackdrop`/
  `createButton`/`createText`/`darken`/`setTabActive` block; call
  `_G.CreshSuiteUI` equivalents instead (nil-guarded as cheap insurance,
  even though `CreshUI.lua` always ships inside CreshCollect too).
- Replace its position save/restore (currently `CC.db.positions.progressHub`
  — CreshChat's db) with `CreshSuiteUI:SavePosition(_G.CreshCollectDB,
  "progressHub", frame)` / `:RestorePosition(...)`, migrating any existing
  `CC.db.positions.progressHub` value once as the initial default so
  current users don't lose their saved window spot.
- No other file (`Games.lua`, `SoloGames.lua`, `BattlePass.lua`,
  `Achievements.lua`, `ProgressOverview.lua`, CreshChat's own `UI.lua`
  windows) is touched this phase, per the explicit "don't broadly migrate
  yet" instruction. `Hub:` method signatures are unchanged, so no other
  caller (Launcher's `OpenProgressHub` service, etc.) is affected.

### 5. Tests

New `tests/CreshUITests.lua`, following the existing convention (see
`tests/SuiteBridgeTests.lua`: `dofile`, mocked `CreateFrame`/`GetTime`,
pass/fail counters, `os.exit(1)` on failure):

- Standalone load + idempotency of `_G.CreshSuiteUI` (double-`dofile`).
- `GetPalette()` returns `FALLBACK` with no `_G.CreshChatAPI` present, and
  returns `CreshChatAPI.GetActivePalette()`'s values when a mock is present.
- All six semantic states resolve to a non-nil color.
- `OnThemeChanged` doesn't error with `_G.CreshSuite` absent, and fires the
  callback after `dofile("shared/Suite.lua")` + `Suite:Publish("SUITE_THEME_CHANGED")`.
- `SavePosition`/`RestorePosition` round-trip against a fake `ownerDB`
  table, including the legacy-migration path.
- `GetSafeFrameScale` clamping behavior (mirrors current `UI.lua` logic).

Add this suite to `tools/Run-Tests.ps1`'s `$Suites` array (same shape as the
`"CreshSuite Bridge Tests"` entry, pointing at `shared/CreshUI.lua`).

## Verification

1. `powershell -File tools\Validate-Addons.ps1` (all three addons) — expect
   PASS, including the new `CreshUI.lua` hash-sync check.
2. `powershell -File tools\Run-Tests.ps1` (or a targeted `lua` invocation if
   no interpreter is on PATH, in which case say so explicitly) — new
   `CreshUITests.lua` suite plus every existing suite still green.
3. Manual diff review: TOC ordering, no duplicate global frames/events, Lua
   5.1 compatibility (no `io`/`os`/`require` in addon source — `tests/` is
   exempt), nil-safety of every new `_G.CreshSuiteUI`/`_G.CreshChatAPI`
   lookup.
4. In-game test instructions will be provided for manual verification in
   WoW (load order sane in all three addons, ProgressHub still opens,
   remembers its position across `/reload`, and looks visually unchanged).
5. Per standing instructions: no deploy, no commit — stop after this phase
   for approval before continuing.
