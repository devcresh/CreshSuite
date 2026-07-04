# Phase 10 In-Game Test Checklist

All 7 addon combinations for CreshSuite v0.2.3 (TBC Anniversary, Interface 20505).

## Setup

1. Run `tools\Build-TestPackage.ps1` — verify "Validation PASSED" and ZIP produced.
2. Deploy to WoW: `tools\Deploy-Local.ps1`
3. Launch WoW.  Use the **AddOns** button on the character-select screen to enable/disable addons for each combination below.
4. After changing the enabled set, click **Okay** and log in (or `/reload` if already in game).

**Error check after every reload:**
- Red text in the default chat frame = Lua error. Note the error and stop testing that combination.
- `/run print("OK")` in chat — if it echoes "OK", Lua is working.

---

## Combination 1 — CreshChat only

Enable: **CreshChat**
Disable: CreshGames, CreshCollect

### Load check
```
/reload
```
- No red Lua errors.
- `/run print(CC and CC.version or "MISSING")` — prints a version string.

### Launcher
- The floating **C** bubble appears near the edge of the screen.
- Left-clicking the C bubble opens the chat window.

### Chat
- `/cc` — opens/closes the CreshChat window.
- Type a message and send it — message appears in chat.
- `/cc settings` — Settings panel opens; sidebar shows General, Chat, Notifications, Themes, Voice tabs.
- Settings → Modules: "CreshGames — not loaded", "CreshCollect — not loaded".

### SavedVariables
- `/run print(CreshChatDB and "DB OK" or "DB MISSING")` — prints "DB OK".
- `/run print(CreshGamesDB == nil and "absent" or "unexpected")` — prints "absent".
- `/run print(CreshCollectDB == nil and "absent" or "unexpected")` — prints "absent".

### Notifications
- `/cc notifytest` — two test cards appear.
- Cards dismiss on click or after timeout.

### Developer diagnostics
These are separate from the user-facing commands above and are not part of the
golden path — they exist for debugging CreshChat itself.
- `/cc test on` — enables developer test mode (snapshots the DB).
- `/cc test run` — runs the L1-L26 developer test suite; no red Lua errors.
- `/cc test off` — disables developer test mode and restores the DB snapshot.
- `/cc test status` — prints current mode/verbose/snapshot state.
- `/cc devprogress` — prints ProgressRouter diagnostics (not the Progress Hub UI).

---

## Combination 2 — CreshGames only

Enable: **CreshGames**
Disable: CreshChat, CreshCollect

> CreshGames has no standalone UI. The game drawer lives in CreshChat.
> This test verifies silent load and DB isolation only.

### Load check
```
/reload
```
- No red Lua errors.
- `/run print(CreshSuite and CreshSuite:GetProduct("CreshGames") and "registered" or "MISSING")` — prints "registered".

### SavedVariables
- `/run print(CreshGamesDB and "DB OK" or "DB MISSING")` — prints "DB OK".
- `/run print(CreshChatDB == nil and "absent" or "unexpected")` — prints "absent".
- `/run print(CreshCollectDB == nil and "absent" or "unexpected")` — prints "absent".

### No phantom globals
- `/run print(CC == nil and "absent" or "unexpected")` — prints "absent".

---

## Combination 3 — CreshCollect only

Enable: **CreshCollect**
Disable: CreshChat, CreshGames

> Same as above: no standalone UI. Tests load and DB isolation.

### Load check
```
/reload
```
- No red Lua errors.
- `/run print(CreshSuite and CreshSuite:GetProduct("CreshCollect") and "registered" or "MISSING")` — prints "registered".

### SavedVariables
- `/run print(CreshCollectDB and "DB OK" or "DB MISSING")` — prints "DB OK".
- `/run print(CreshChatDB == nil and "absent" or "unexpected")` — prints "absent".
- `/run print(CreshGamesDB == nil and "absent" or "unexpected")` — prints "absent".

---

## Combination 4 — CreshChat + CreshGames

Enable: **CreshChat**, **CreshGames**
Disable: CreshCollect

### Load check
```
/reload
```
- No red Lua errors.
- Both products registered:
  ```
  /run print(CreshSuite:GetProduct("CreshGames") and "Games OK" or "MISSING")
  ```

### SavedVariables
- `/run print(CreshChatDB and "CC OK" or "MISSING")` — "CC OK".
- `/run print(CreshGamesDB and "CG OK" or "MISSING")` — "CG OK".
- `/run print(CreshCollectDB == nil and "absent" or "unexpected")` — "absent".

### Launcher
- C bubble appears. Left-click opens chat.
- **Gm** satellite button visible. Click it — the game drawer opens.

### Games
- `/cc games` — game drawer slides open showing Multiplayer and Solo game modes.
- `/cc solo` — solo game selection opens.
- Open any solo game (e.g. `/cc tetris`) — game starts without error.
- Settings → Games tab visible in `/cc settings` with 9 pages (General, Game Audio, Solo Games, Multiplayer, Tetris, Dungeon, Controls, Notifications, Reset).

### Audio
- Toggle a game sound in Settings → Games → Game Audio — no error.

---

## Combination 5 — CreshChat + CreshCollect

Enable: **CreshChat**, **CreshCollect**
Disable: CreshGames

### Load check
```
/reload
```
- No red Lua errors.
- `/run print(CreshSuite:GetProduct("CreshCollect") and "Collect OK" or "MISSING")` — "Collect OK".

### SavedVariables
- `/run print(CreshChatDB and "CC OK" or "MISSING")` — "CC OK".
- `/run print(CreshCollectDB and "COL OK" or "MISSING")` — "COL OK".
- `/run print(CreshGamesDB == nil and "absent" or "unexpected")` — "absent".

### Launcher
- C bubble present. **Ach** satellite button visible.
- Click Ach — Achievements tab opens in the game drawer.

### Achievements
- `/cc achievements` — Achievements panel opens.
- `/cc progress` — Progress Hub opens showing World Progression and Quests tabs.
- `/cc battlepass` — Battle Pass opens (level bar + tier grid visible).

### Settings
- `/cc settings` → Collections tab present with 8 pages (Progress Hub, Achievements, Battle Pass, Currency, Collections, Combat, Notifications, Reset).

---

## Combination 6 — CreshGames + CreshCollect

Enable: **CreshGames**, **CreshCollect**
Disable: CreshChat

> No launcher or visible UI without CreshChat. Tests that both modules
> coexist and cross-communicate through the Suite bridge.

### Load check
```
/reload
```
- No red Lua errors.
- Both registered:
  ```
  /run local s=CreshSuite; print(s:GetProduct("CreshGames") and "CG" or "!CG", s:GetProduct("CreshCollect") and "COL" or "!COL")
  ```
  — prints "CG  COL".

### SavedVariables
- `/run print(CreshGamesDB and "CG OK" or "MISSING")` — "CG OK".
- `/run print(CreshCollectDB and "COL OK" or "MISSING")` — "COL OK".
- `/run print(CreshChatDB == nil and "absent" or "unexpected")` — "absent".

### Suite event bridge
- `/run CreshSuite:Publish("CRESHGAMES_COLLECTION_UNLOCK", {key="TEST_DECK", type="CARD_DECK"})` — no error.
- DB state: `/run print(CreshCollectDB.collections and CreshCollectDB.collections.cardDecks and CreshCollectDB.collections.cardDecks.TEST_DECK and "bridged" or "not bridged")` — "bridged".
- Popup behaviour: N/A for this combination — CreshChat is not loaded, so there is no notification UI to check. The unlock must still apply to the database above with no Lua error.

---

## Combination 7 — All Three

Enable: **CreshChat**, **CreshGames**, **CreshCollect**

This is the golden path. Every feature should work together.

### Load check
```
/reload
```
- No red Lua errors.
- All three registered:
  ```
  /run local s=CreshSuite; print(s:GetProduct("CreshChat") and "CC" or "!CC", s:GetProduct("CreshGames") and "CG" or "!CG", s:GetProduct("CreshCollect") and "COL" or "!COL")
  ```
  — prints "CC  CG  COL".

### SavedVariables
- `/run print(CreshChatDB and CreshGamesDB and CreshCollectDB and "All 3 DBs OK" or "MISSING")` — "All 3 DBs OK".

### Launcher
- C bubble present. Both **Gm** and **Ach** satellite buttons visible.
- Left-click C: opens chat (or last destination, depending on `launcherDefault`).
- Click Gm: game drawer opens.
- Click Ach: Achievements tab opens.

### Chat
- `/cc` toggles chat window. Messages send and receive.
- `/cc settings` — Settings panel has sidebar tabs: General, Chat, Notifications, Themes, Voice, Games (9 pages), Collections (8 pages).
- Settings → Modules: both CreshGames and CreshCollect shown as **loaded**.

### Games
- `/cc solo` — solo game selection opens.
- Play one game to completion — result appears in game history.
- `/cc leaderboard` — shared leaderboard visible.
- `/cc gamehistory` — recent results listed.

### Collect
- `/cc progress` — Progress Hub: World Progression, Quests, Combat tabs.
- `/cc achievements` — Achievement catalog visible.
- `/cc battlepass` — Battle Pass level bar and tiers visible.

### Notifications
- `/cc notifytest` — test cards appear for all enabled sources (CreshChat, CreshGames, CreshCollect).
- `/cc notifcards on` then trigger an in-game achievement or game event — notification card appears.

### Cross-addon unlock (requires playing a game first)
- Complete a Tetris game to unlock a zone background:
  - `/run CreshSuite:Publish("CRESHGAMES_COLLECTION_UNLOCK", {key="ZONE_ELWYNN",type="TETRIS_BACKGROUND"})` (simulated unlock)
  - DB state: open `/cc settings` → Collections → Collections page — ZONE_ELWYNN listed.
  - Popup behaviour: a "Collection Unlocked" notification card appears immediately after the unlock (no need to have Settings open). If Settings is already open on the Collections page, its counts update in place without closing/reopening Settings.

### Voice
- `/cc call PlayerName` (with another CreshChat user online) — voice call initiates.
- `/cc hangup` — call ends.
- (If no second player available: verify the command prints a usage hint, not an error.)

### Persistence check
- `/reload` a second time — all settings and data survive the reload without error.

---

## Reporting results

For each combination, record:

| Combination | Load OK? | DB OK? | UI OK? | Notes |
|-------------|----------|--------|--------|-------|
| Chat only   |          |        |        |       |
| Games only  |          |        | N/A    |       |
| Collect only|          |        | N/A    |       |
| Chat+Games  |          |        |        |       |
| Chat+Collect|          |        |        |       |
| Games+Collect|         |        | N/A    |       |
| All three   |          |        |        |       |

Do not mark any combination as passing until you have run it in WoW and observed the results above.
