# Phase 2 — Achievements Overflow Fix + Class Mastery Filtering

## Context

`addons/CreshCollect/Achievements.lua` builds two presentations of the same
achievement catalog: a standalone window (`BuildWindow`/`RefreshWindow`) and
a panel embedded in CreshChat's game drawer (`BuildDrawerPanel`/
`RefreshDrawerPanel`). The achievement catalog itself is assembled at runtime
by three other files hooking `Achievements:BuildCatalog()` in a chain
(`AchievementExpansion.lua` → `ClassAchievements.lua` → `MetaAchievements.lua`,
each capturing and calling the previous `BuildCatalog`). The final category
list is 11 entries: `QUESTS, EXPLORATION, DUNGEONS, RAIDS, COMBAT,
PROFESSIONS, REPUTATION, PVP, COMMUNITY, CLASSES, META`.

Two concrete bugs follow from this:

1. **Overflow**: `BuildWindow`'s category filter (`Achievements.lua:1122-1143`)
   builds one fixed-width button *per category* (`ALL` + all 11) chained
   left-to-right in a single row with no wrapping or clipping. In the 480px
   standalone window this is ~800px of buttons — it visibly overhangs the
   window. The achievement rows themselves are also sized via a magic
   `SetWidth(450)` (`Achievements.lua:1163,1176`) unrelated to the window's
   actual 480px width or its scroll-inset geometry.
2. **Unreachable / unfiltered categories**: the drawer's category filter
   (`BuildDrawerPanel`, `Achievements.lua:722-725`) is a *hardcoded* list of
   5 buttons (`ALL, EXPLORATION, COMBAT, DUNGEONS, PROFESSIONS`) written
   before the other three category-contributing files existed — 7 of the 11
   real categories (`QUESTS, RAIDS, REPUTATION, PVP, COMMUNITY, CLASSES,
   META`) have no drawer filter button at all. And even where `CLASSES` is
   reachable (via the standalone window's per-category loop), all 9 classes'
   ~135 achievements are shown mixed together with no way to narrow to one
   class.

Goal: replace the per-category button wall with a small, fixed set of
compact "cycle" controls (category / class / completion status) that can
never overhang regardless of catalog size, back both the window and the
drawer with one shared filter function so they can't drift apart, add class
resolution/filtering for `CLASSES`, and adopt Phase 1's `CreshSuiteUI`
semantic row styling. No changes to catalog building, unlock evaluation, or
SavedVariables shape.

## Design

### 1. One shared, pure filter function

Add to `Achievements` (near the existing `isCategoryEnabled`/
`achievementMissingAddon` locals, `Achievements.lua:36-73`):

- `Achievements:GetPlayerClassToken()` — `UnitClass("player")` token
  resolution, same pattern as `ClassAchievements.lua`'s existing private
  `currentClass()` (`ClassAchievements.lua:176-182`), kept as its own small
  copy here (Achievements.lua has no dependency on ClassAchievements.lua
  today and shouldn't gain one). Returns `""` when `UnitClass` isn't
  available, matching the existing convention.
- `Achievements:GetClassTokens()` — scans `self.catalog` for
  `category == "CLASSES"` and returns the sorted, de-duplicated list of
  `achievement.classToken` values actually present (no hardcoded roster;
  works whether or not `ClassAchievements.lua` has run yet).
- `Achievements:ResolveClassFilterOnCategoryChange(previousCategory,
  newCategory, currentClassFilter)` — pure rule: entering `CLASSES` from any
  other category resets to `"MY_CLASS"`; otherwise keeps the current value
  (defaulting to `"MY_CLASS"` if unset). Used by both the window's and the
  drawer's category-cycle click handlers.
- `Achievements:MatchesFilter(achievement, save, state, playerClassToken)` —
  the single combined-filter predicate. `state` is a plain table:
  `{ search, category, classFilter, status, enabledOnly }`. Replaces the
  duplicated inline filter logic in `RefreshDrawerPanel`
  (`Achievements.lua:809-847`), `RefreshWindow` (`Achievements.lua:1213-1252`)
  and `GetPanelHeight` (`Achievements.lua:657-666`) — all three become thin
  callers of this one function. Adds two dimensions that don't exist today:
  `classFilter` (`"MY_CLASS"` / `"ALL_CLASSES"` / a specific class token,
  only consulted when `category == "CLASSES"`) and `status` (`"ALL"` /
  `"UNLOCKED"` / `"LOCKED"`, per task 3's "completion state" filter).

`GetPanelHeight(filter, category, status, classFilter)` gains the two new
params and calls `MatchesFilter` per catalog entry instead of its own
inline count logic. `addons/CreshChat/UI.lua:3283` already speculatively
passes a `status` 3rd argument to `GetPanelHeight` that today's 2-param
version silently ignores — this gets a 4th `classFilter` argument added at
the same call site so the drawer's pre-refresh height estimate stays
accurate.

### 2. Replace the button wall with 3 fixed cycle-controls

In both `BuildWindow` and `BuildDrawerPanel`, delete the per-category button
loop and replace with three always-full-width buttons (`TOPLEFT`/`TOPRIGHT`
anchored to their row, never a fixed pixel wall), left-click cycles forward
/ right-click cycles back (`RegisterForClicks("LeftButtonUp",
"RightButtonUp")`, same convention already used for the settings button in
`ProgressHub.lua`):

- **Category**: cycles `ALL` → each entry of `self.categoryOrder`. Label:
  `"CATEGORY: <name>"`.
- **Class** (only shown, via `SetShown`, when `category == "CLASSES"`):
  cycles `MY_CLASS` → `ALL_CLASSES` → each token from `GetClassTokens()`.
  Label: `"CLASS: My Class (Druid)"` / `"CLASS: All Classes"` / `"CLASS:
  Warrior"`. On the category button's click handler, when the new category
  is `CLASSES`, call `ResolveClassFilterOnCategoryChange` to reset to
  `MY_CLASS` on first entry.
- **Status**: cycles `ALL` → `UNLOCKED` → `LOCKED`. Label: `"STATUS: All"` /
  `"STATUS: Unlocked"` / `"STATUS: Locked"`.

These three (plus the existing "ENABLED MODULES ONLY" toggle, kept as-is)
are a fixed, constant-size set of controls — the count never grows with the
catalog, so overhang can't recur structurally. Rows below react to the
class button's visibility via a small `LayoutFilterRows()`-style
re-anchoring, same manual-reflow style already used for the toggle
row/scroll frame today.

### 3. Fix the standalone window's row/content width

Replace the unrelated magic `SetWidth(450)` (both `content` and each row,
`Achievements.lua:1163,1176`) with a width derived from the window's real
geometry: `local CONTENT_WIDTH = WINDOW_W - 8` (matching the scroll frame's
actual right inset, `Achievements.lua:1160`), used for both. This ties row
width to the window's actual declared size instead of a disconnected
constant, directly per task 8. The drawer's rows already anchor
`TOPLEFT`/`TOPRIGHT` per-row (no fixed width) and need no change here.

### 4. Phase 1 semantic styling on achievement rows

In both refresh functions' per-row rendering, replace the ad hoc
`complete and darken(colors.green, 0.58) or colors.panelSoft` /
`disabled and muted or ...` branching with one call into Phase 1's shared
service (`shared/CreshUI.lua`, already loaded in this addon before
`Achievements.lua` per the TOC):

```lua
local state = complete and "UNLOCKED" or (disabled and "LOCKED" or "AVAILABLE")
local sc = _G.CreshSuiteUI and _G.CreshSuiteUI:GetStateColor(state, colors)
if sc then
    applyBackdrop(row, sc.bg, sc.border)
    row.title:SetTextColor(sc.text[1], sc.text[2], sc.text[3], 1)
    row:SetAlpha(sc.alpha or 1)
else
    applyBackdrop(row, colors.panelSoft, colors.border) -- cheap insurance, not an expected path
end
```

`LOCKED`'s dimmed/0.55-alpha mapping and `UNLOCKED`'s green mapping match
today's actual visual weight; `AVAILABLE` (not yet complete, not disabled)
shifts from `panelSoft` to `panelRaised`, the deliberate Phase 1 palette.

### 5. Tests

- New `tests/ClassMasteryFilterTests.lua` (BOM-safe `loadProductionFile`
  loader, same convention as `tests/AchievementsAvailabilityTests.lua`),
  loading `Achievements.lua` + `ClassAchievements.lua` together (so the real
  `CLASSES` category and all 9 real class tokens exist), covering:
  - `GetPlayerClassToken()` via a mocked `_G.UnitClass` (present and
    absent).
  - `GetClassTokens()` returns all 9 expected tokens, sorted.
  - `ResolveClassFilterOnCategoryChange` resets to `MY_CLASS` only when
    entering `CLASSES` from elsewhere, preserves the current value
    otherwise.
  - `MatchesFilter` combined filtering: `MY_CLASS` shows only the mocked
    player's class; `ALL_CLASSES` restores the full ~135-entry catalogue;
    a specific class token isolates that class; search + status +
    `enabledOnly` all combine correctly with `category`/`classFilter`
    together (not just individually).
  - Standalone-vs-drawer parity: build both with the same `state`, assert
    the same set of visible achievement keys.
- Extend `tests/ProgressionWindowTests.lua` (already exercises
  `Achievements:BuildWindow`/`RefreshWindow`) with a layout-sizing section:
  the number of persistent filter controls stays fixed/small regardless of
  category count (proving the button wall is gone), and
  `#Achievements.windowRows == #Achievements.catalog` still holds (existing
  invariant, must not regress).
- Register the new suite in `tools/Run-Tests.ps1`.

## Files touched

- `addons/CreshCollect/Achievements.lua` — all of the above.
- `addons/CreshChat/UI.lua` — one line, adds the 4th `classFilter` arg to
  the existing `GetPanelHeight` call at line 3283.
- `tests/ClassMasteryFilterTests.lua` — new.
- `tests/ProgressionWindowTests.lua` — extended.
- `tools/Run-Tests.ps1` — register the new suite.

Not touched: `AchievementExpansion.lua`, `ClassAchievements.lua`,
`MetaAchievements.lua` (catalog/stat logic untouched), any SavedVariables
shape, `GetCounts`/`GetPoints`/unlock evaluation.

## Verification

1. `tools/Validate-Addons.ps1` — all three addons, expect PASS.
2. `tools/Run-Tests.ps1` — new suite plus `ProgressionWindowTests`,
   `AchievementsAvailabilityTests`, `ProgressOverviewTests` all still green.
3. Manual diff review: TOC untouched (no new files this phase), nil-safety
   of every `_G.CreshSuiteUI` / `_G.UnitClass` lookup, Lua 5.1 compatibility.
4. In-game test instructions provided for manual verification (open
   standalone Achievements window and the drawer's Achievements tab at
   default UI scale, confirm no control extends past either window's edge,
   cycle Category to Class Mastery and confirm it defaults to "My Class"
   showing only the logged-in character's class achievements, cycle to "All
   Classes" and to a couple of specific classes, combine with search and
   status, and confirm the drawer and standalone window show the same rows
   for the same filter state).
5. Per standing instructions: no deploy, no commit — stop after this phase
   for approval.
