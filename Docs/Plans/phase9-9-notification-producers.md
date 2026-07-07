# Phase 9.9 — CreshCollect notification producers

## Context

CreshCollect.lua (`CreshCollect/CreshCollect.lua`) exists and correctly registers the
CRESHCOLLECT source + 5 categories with `CC.Notifications`, but it is **not listed in
CreshChat.toc**, so it never loads.

Consequence:
- `Notifications:IsSourceEnabled("CRESHCOLLECT")` returns `false`
- The adapter's `suiteSourceFromKey` falls back to `"CRESHCHAT:GAME"` for all
  `ACHIEVEMENT:*` and `DD_ACH:*` coalesceKeys instead of routing to CRESHCOLLECT
- Settings → Notifications never shows the "CreshCollect notifications" section
  (Settings.lua already has the wiring at lines 1036-1065)

Everything else is already in place:
- The registration stub in `CreshCollect/CreshCollect.lua` is correct
- The adapter already routes `ACHIEVEMENT:*` → `CRESHCOLLECT:ACHIEVEMENT`
  and `DD_ACH:*` → `CRESHCOLLECT:ACHIEVEMENT`
- `Achievements:Unlock()` calls `ShowBattlePassToast(... "ACHIEVEMENT:"..key)` which
  the adapter intercepts
- `DungeonAchievements.lua` uses `"DD_ACH:"..key` coalesceKeys which also route correctly

## Change

**CreshChat.toc** — add one line after line 34 (`DungeonAchievements.lua`):
```
CreshCollect\CreshCollect.lua
```

That's the only change. Adding the TOC entry causes the stub to load, which registers
the source + categories, which fixes the routing chain.

## Verification

1. `/reload` in WoW
2. `/cc notifcards on`
3. Settings → Notifications → confirm "CreshCollect notifications" section appears with 5 toggles
4. Trigger an achievement in-game (or evaluate via `/run CC.Achievements:EvaluateAll()`) — 
   card should appear attributed to CreshCollect, not CRESHCHAT/GAME
