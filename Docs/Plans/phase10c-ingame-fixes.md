# Phase 10C — Fix Failed In-Game Integration Tests

## Context

Phase 10 manual in-game testing failed. Branch `phase-10c-ingame-fixes` has been
created off `phase-10-fixes` (confirmed the newest branch containing all Phase 10
work — it's a descendant of `origin/folder-fixing` and no other local/remote branch
is ahead of it). This plan fixes eight concrete, independently-verified bugs found
by reading the actual source, not by assumption. Nothing is committed, pushed, or
deployed until explicitly authorised, per CLAUDE.md.

One pre-existing uncommitted change was found sitting in the working tree:
`Docs/TEST-CHECKLIST.md` had several lines blanked out (a stray `/run print(...)`
turned into an empty code fence). This is exactly the "damaged character encoding"
bug item 7 asks to fix, so it will be folded into that fix rather than reverted
separately.

---

## 1. Slash-command collisions (Developer.lua / Core.lua)

**Root cause**: `Core.lua:3244` defines `CC:HandleSlashCommand` as an if/elseif
chain (the "real" handler, help text at `Core.lua:3206-3242`). `Developer.lua:1182`
then monkey-patches it (`originalHandleSlashCommand = CC.HandleSlashCommand`),
intercepting `"progress"` (→ `Developer:HandleProgressCommand`, ProgressRouter
diagnostics) and `"test"` (→ `Developer:HandleTestCommand`, the L1-L26 dev suite)
**before** falling through to the original handler. This permanently shadows:
- `Core.lua:3283-3286` — `if command == "test" then self:RunTest() end` (the two
  notification preview cards, `CC:RunTest()` at `Core.lua:3166-3193`)
- `Core.lua:3326-3329` — `if command == "progress" or "hub" or "tracking"` →
  `self.ProgressHub:Toggle()` (the real Progress Hub, bridged in from CreshCollect)

**Fix**:
- `Core.lua:3283`: rename the branch from `command == "test"` to
  `command == "notifytest"`, keep calling `self:RunTest()`. Update the help text
  at `Core.lua:3208`.
- `Developer.lua:1194` (dispatcher) and `1216` (help text): rename the intercepted
  word from `"progress"` to `"devprogress"`. This removes Developer.lua's
  interception of `"progress"`, so `/cc progress` and `/cc hub` fall through to the
  real handler at `Core.lua:3326`.
- `Developer.lua:1201-1204`: `/cc test on|run|off|verbose|status` keep working
  exactly as today (Developer.lua still owns `"test"` for its own suite; only
  `"notifytest"` and `"progress"`/`"hub"` move).
- Update `Developer.lua`'s own `ShowHelp` addendum (`Developer.lua:1212-1222`) and
  `CC:ShowHelp` (`Core.lua:3219`) to reflect `/cc notifytest`, `/cc devprogress`.

**Regression test**: add `tests/SlashCommandTests.lua` (new), following the
existing hand-rolled pass/fail pattern used by `tests/SettingsShellTests.lua`
(`pass()/fail()/eq()`, `dofile()` of production files). It will `dofile` a
minimal WoW-API stub + `Core.lua` + `Developer.lua` and assert:
- `/cc notifytest` invokes `RunTest` (not the dev suite)
- `/cc test on|run|off` invoke the dev suite (not `RunTest`)
- `/cc progress` / `/cc hub` invoke `ProgressHub:Toggle` (not `HandleProgressCommand`)
- `/cc devprogress` invokes `HandleProgressCommand`
- a third, later-defined wrapper cannot re-shadow `notifytest`/`progress` once
  patched (proves the fix generalises, not just fixes today's specific collision)

Register it in `tools/Run-Tests.ps1`'s `$Suites` array (currently 3 entries,
`Run-Tests.ps1:27-50`) as a 4th entry, `"Slash Command Tests"`.

---

## 2. CreshGames media packaging

**Root cause**: every CreshGames Lua file (`GameAudio.lua`, `TetrisThemes.lua`,
`ChessTextureManifest.lua`, `Games.lua`, `SoloGames.lua`,
`DungeonDwellersProgression.lua`, `DungeonDwellersAssetSets.lua`,
`CardDeckLibrary.lua`) references
`Interface\AddOns\CreshGames\Media\{GameAudio,Games}\...`, but those 906 files
physically live under `addons/CreshChat/Media/{GameAudio,Games}/...` instead.
Confirmed CreshChat's own Lua never references `CreshChat\Media\Games\...` or
`CreshChat\Media\GameAudio\...` — that whole subtree belongs exclusively to
CreshGames. (CreshChat's own `Media/Sounds` and `Media/Voice` are unaffected and
stay put.)

`tools/Build-Release.ps1:154-160` already stages **only** `<addon>/Media/*` per
addon — once the files physically move, packaging picks them up with no script
change needed. `tools/Validate-Addons.ps1:370-392` already regex-scans for
referenced media paths and checks they resolve — but calls `Warn` (line 387,
non-fatal) instead of `Fail`. `tools/Build-TestPackage.ps1:37-41` already aborts
if `Validate-Addons.ps1` exits non-zero.

**Fix**:
1. `git mv addons/CreshChat/Media/GameAudio addons/CreshGames/Media/GameAudio`
2. `git mv addons/CreshChat/Media/Games addons/CreshGames/Media/Games`
3. `tools/Validate-Addons.ps1:387`: change `Warn "Media file not found..."` to
   `Fail "Media file not found..."` so a missing referenced file now fails
   validation (and therefore fails `Build-TestPackage.ps1` and any release build)
   instead of silently warning.
4. Re-run `Validate-Addons.ps1` after the move to confirm zero media errors and
   confirm the existing "19 undeclared Lua file" / TOC-order checks are unaffected.

---

## 3. Silent direct module calls → CreshSuite services

**Root cause**: `shared/Suite.lua` already implements a full, currently-unused
service registry (`Suite:RegisterService` / `Suite:GetService`,
`Suite.lua:106-116`). Instead, seven command entry points in
`Core.lua:HandleSlashCommand` reach directly into fields that CreshGames/
CreshCollect bridge onto the CreshChat table (`self.Games`, `self.SoloGames`,
`self.ProgressHub`, `self.Achievements` via `UI.lua`, `self.BattlePass` via
`UI.lua`), and silently `return` if the field is nil — no message, per
CLAUDE.md's ban on silent no-ops matters here directly:

| Action | Command branch | Current guard |
|---|---|---|
| Games | `Core.lua:3311-3314` | `if self.Games and self.Games.OpenHub` |
| Solo games | `Core.lua:3356-3358` | `if self.SoloGames and self.SoloGames.OpenHub` |
| Leaderboard | `Core.lua:3396-3399` | `if self.SoloGames and self.SoloGames.OpenLeaderboard` |
| Game history | `Core.lua:3401-3404` | `if self.SoloGames and self.SoloGames.OpenHistory` |
| Achievements | `Core.lua:3316-3319` → `UI:LauncherToggleMode` | `if self.UI.LauncherToggleMode` (drawer itself guards `CC.Achievements` in `UI.lua:3401`) |
| Battle Pass | `Core.lua:3321-3324` → `UI:OpenGameDrawer` | `if not CC.BattlePass then return end` (`UI.lua:3400`) |
| Progress Hub | `Core.lua:3326-3329` | `if self.ProgressHub and self.ProgressHub.Toggle` |

The launcher buttons (`UI.lua:5397-5414` OnClick handlers, `UI:LauncherToggleMode`
at `UI.lua:5164-5210`, `UI:OpenGameDrawer`'s top guard at `UI.lua:3397-3403`) have
the identical shape and silently no-op the same way.

**Fix** (scoped to these 7 "opening" entry points only — internal drawer-content
wiring inside `UI.lua` that reads `CC.Games`/`CC.BattlePass` for rendering detail,
e.g. peer lists, theme lookups, is unrelated plumbing and stays as-is):

- **CreshGames** (`addons/CreshGames/CreshGames.lua`, next to the existing
  `Suite:RegisterProduct("CreshGames", ...)` at line 34): register
  `Suite:RegisterService("OpenGames", ...)`, `"OpenSoloGames"`,
  `"OpenLeaderboard"`, `"OpenGameHistory"` — each a thin lazy wrapper around
  `CG.Games:OpenHub`/`CG.SoloGames:OpenHub`/`OpenLeaderboard`/`OpenHistory`
  (checked at call time, so registration order vs. module load order inside
  CreshGames doesn't matter).
- **CreshCollect** (`addons/CreshCollect/CreshCollect.lua`, next to
  `Suite:RegisterProduct("CreshCollect", ...)` at line 20): register
  `"OpenProgressHub"` (wraps `COL.ProgressHub:Toggle`), `"OpenAchievements"` and
  `"OpenBattlePass"` (each calls back into `CC.UI:LauncherToggleMode("ACHIEVEMENTS")`
  / `CC.UI:OpenGameDrawer("BATTLEPASS")` via the same `CC` proxy pattern the file
  already uses at lines 4-7 — the actual panel still lives in CreshChat's drawer,
  only the availability decision moves to a formal contract).
- **CreshChat** (`Core.lua`, the 7 branches above, and the matching `UI.lua`
  launcher paths): replace the direct field check with
  `local svc = _G.CreshSuite and _G.CreshSuite:GetService("OpenX")` — if present,
  call it; if not, `self:Print("CreshGames is not installed or loaded.")` or
  `"CreshCollect is not installed or loaded."` as appropriate. Never a bare `return`.

---

## 4. Settings dynamic provider discovery

**Root cause**: `Settings:Build()` (`Settings.lua:1535`) is guarded by
`if self.frame then return end` (line 1536) — it runs **once** per session. The
provider-registration scan (`Settings.lua:1662-1670`, loops `PRODUCTS`, calls
`Suite:GetSettingsProvider`, builds the panel) lives **only** inside that one-shot
`Build()`. If Settings is opened before `GamesSettings.lua` / `CollectSettings.lua`
have called `Suite:RegisterSettingsProvider` (both register at file-scope, gated
only on `if not Suite then return end`), that product's real pages are missed for
the rest of the session and `Settings:SelectProduct` (`Settings.lua:1975`) falls
back to `ShowProductStatus`'s "coming in a future update" placeholder forever
(`Settings.lua:1993-1996`), since `BuildProductSettingsPanel` is itself idempotent
(`Settings.lua:1883`, returns immediately if already built) and nothing ever
re-triggers it.

**Fix**:
- Extract lines `1662-1670` into a new `Settings:DiscoverProviders()` method that
  loops `PRODUCTS` and calls `BuildProductSettingsPanel` for any not yet in
  `self.productPanels` — safe to call repeatedly (existing idempotency guard).
- Call `Settings:DiscoverProviders()` from three points, matching the task's three
  required triggers:
  1. Inside `Settings:Build()` (replaces the inline block).
  2. `UI:OpenSettings()` (`Settings.lua:1688`), before `Settings:Refresh()` —
     covers "Settings opens" even on the 2nd+ open in a session.
  3. `Settings:SelectProduct(key)` (`Settings.lua:1975`), right before the
     `if ps then ... else ShowProductStatus ... end` branch at line 1986 — covers
     "a product tab is selected" and guarantees a late-registering provider is
     picked up and its real pages shown instead of the fallback, with no
     logout/reload required.

---

## 5. Collection unlock feedback

**Root cause**: `CreshCollect.lua:24-35`'s
`Suite:Subscribe("CRESHGAMES_COLLECTION_UNLOCK", ...)` handler only writes into
`CreshCollectDB.collections`. It never refreshes an open Collections settings
page and never calls `CC.Notifications:Push`, even though
`registerNotifications()` (`CreshCollect.lua:58-69`) already registers a
`COLLECTION_UNLOCK` category for exactly this purpose.

The "Collections page" is the CreshCollect Settings sub-page (`CollectSettings.lua`
key `"COLLECTIONS"`, lines 122-140) — its `build(b)` closure reads
`CreshCollectDB.collections` counts once, at panel-construction time
(`Settings.lua:1880` `BuildProductSettingsPanel`); `SetProductPage`
(`Settings.lua:1859`) only toggles `SetShown` between already-built pages, it
doesn't re-run `build`.

**Fix**:
- In `Settings.lua`, have `BuildProductSettingsPanel` retain each page's `build`
  closure and content frame (small addition to the existing per-page table), and
  add `Settings:RefreshProductPage(productKey, pageKey)` that clears and
  re-invokes `build` for that one page in place.
- In `CreshCollect.lua`'s unlock handler, after updating `CreshCollectDB`:
  - if `_G.CreshChat` and its `Settings.frame` is shown, `activeProductKey == "COL"`,
    and the active page is `"COLLECTIONS"`, call
    `CC.Settings:RefreshProductPage("COL", "COLLECTIONS")`.
  - if `CC.Notifications` exists, `CC.Notifications:Push({ sourceAddon =
    "CRESHCOLLECT", category = "COLLECTION_UNLOCK", priority = "NORMAL", title =
    "Collection Unlocked", detail = <human label derived from type/key> })`
    (matching the shape already used in `NotificationsAdapter.lua:137-145`).
  - All of the above stays inside `if CC then ... end` guards — when CreshChat is
    absent the handler still updates `CreshCollectDB` exactly as it does today,
    silently and correctly.

---

## 6. Launcher interaction (C bubble / Ach button)

Static review of `UI.lua:5234-5427` (`BuildBubble`) and `UI.lua:3949-4010`
(`SetBubbleGroupShown` / `PositionQuickButtons`): buttons are plain
`CreateFrame("Button", ...)` (mouse-enabled by default for the Button frame type),
all share `SetFrameStrata("HIGH")`, no competing frame is created at a higher
level over them, and visibility/positioning already reacts live to
`CC.Games`/`CC.Achievements` via the CreshGames/CreshCollect bridge functions
(`CreshGames.lua`'s and `CreshCollect.lua`'s `bridgeToCreshChat`, both wired to
`ADDON_LOADED`/`PLAYER_LOGIN`, not a one-shot). No concrete static bug found.

Since this is fundamentally a live-client interaction check I cannot run myself,
the plan is:
- Do one more targeted pass immediately before the in-game retest specifically
  looking for any frame created **after** the bubble/buttons at the same or
  higher strata that could visually or mechanically sit on top (e.g. toast/drawer
  frames spawned near the launcher position).
- If nothing concrete turns up in code, ship a precise manual repro (below, item 8)
  and only add temporary `frame:GetName()` / click-through print diagnostics if
  the user's in-game test actually reproduces a problem — then remove them before
  considering the item done, exactly as the task specifies.

---

## 7. Docs/TEST-CHECKLIST.md repair

Current file (including the pre-existing uncommitted corruption) needs:
- Line 28: restore `` `/run print(CC and CC.version or "MISSING")` `` (currently
  blanked to an empty code fence).
- Lines 47-48: change `/cc test` → `/cc notifytest` for the two-card preview
  (Combination 1), matching item 1's rename.
- Lines 208-211: restore
  `` `/run local s=CreshSuite; print(s:GetProduct("CreshChat") and "CC" or "!CC", s:GetProduct("CreshGames") and "CG" or "!CG", s:GetProduct("CreshCollect") and "COL" or "!COL")` ``
  (Combination 7, currently blanked).
- Line 239: `/cc test` → `/cc notifytest` (Combination 7 Notifications section).
- Add a short **Developer diagnostics** subsection (once, near Combination 1's
  Notifications block) documenting `/cc test on|run|off|verbose|status` (dev
  suite) and `/cc devprogress` separately from the user-facing `/cc notifytest`,
  `/cc progress`, `/cc hub`.
- Combination 6 (line 190-191) and Combination 7 (line 244-245): split the single
  DB-state assertion into two separate checks — one for `CreshCollectDB.collections`
  state (as today), one new one confirming a notification card/popup appears when
  CreshChat is loaded (ties to item 5's fix; note that Combination 6 has no
  CreshChat loaded, so its check stays DB-only, while Combination 7's check gets
  the added popup assertion).
- Review the "Known warnings (not failures)" section (lines 257-260) against
  current `Validate-Addons.ps1`/`Deploy-Local.ps1` behaviour post-fix and remove
  whatever no longer applies (the Phase 7 stale-file and junction-symlink notes
  predate this phase's changes).

---

## 8. Verification

Run, in order, after all edits above:
```
.\tools\Run-Tests.ps1
.\tools\Validate-Addons.ps1
.\tools\Build-TestPackage.ps1
```
Then report: test totals (including the new Slash Command Tests suite),
validation pass/fail/warning totals, the produced ZIP path, a full list of changed
files, and the exact in-game retest checklist (the 7 combinations in
`Docs/TEST-CHECKLIST.md`, called out explicitly for the areas this phase touched:
`/cc notifytest`, `/cc devprogress`, `/cc progress`/`/cc hub`, CreshGames media
load with no red errors, Settings showing 9/8 real pages without reload, launcher
button clicks with CreshGames disabled, and the collection-unlock popup).

No commit, push, deploy, or "Phase 10 complete" declaration happens until the user
authorises it after reviewing this verification output — and even then, per
CLAUDE.md, in-game behaviour is only "confirmed" once the user has actually run it
in WoW.
