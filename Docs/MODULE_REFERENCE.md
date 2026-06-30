# Module Reference

| Module | Responsibility |
|---|---|
| Core.lua | Namespace, schema 74, account progression migration, direct/backup chat capture, history repair, outgoing reconciliation, safety fallback, account direct storage and commands |
| SoundLibrary.lua | Validated notification sound definitions |
| Quest.lua | Quest conversation capture |
| Friends.lua | Dual legacy/modern roster discovery, account friend synchronisation, explicit online/offline sections, Battle.net identity cache/live routes, add/remove and party-invite actions |
| Voice.lua | CreshChat peer discovery, call requests and guarded Blizzard voice bridge |
| Themes.lua | Main interface theme library |
| CardDeckLibrary.lua / CardDecks.lua | Card textures, ownership, selection and Battle Pass deck unlocks |
| UI.lua | Main console, clickable Friends tab, direct chat-alias routing, conversation/friend presentation, sending/failed states, game drawer, cards, pop-outs, BP bar/coin display and microphone actions |
| TetrisThemes.lua | Separate 50-theme tetromino palette catalogue and 50-image background catalogue, ten-row reveal progress, migration, ownership, selection and 1,000-level gravity curve |
| Games.lua | Addon multiplayer games; Tetris protocol 5, dual-board image/grid rendering, non-overlapping versus panels, snapshots and garbage attacks |
| SoloGames.lua | Seven solo games; Dungeon Collection/Statistics/Pass UI; Tetris block-theme browser, 50-image gallery/preview, grid rendering, graphical metrics, CPU and ten-row reveals |
| BattlePass.lua | Cresh Coins, main Pass XP, themes, decks, Tetris premium sets and goals |
| DungeonDwellersProgression.lua | Dedicated Dungeon pass, XP activity hooks, reward claims, permanent boons and schema-61 Dungeon collection normalisation |
| Progression.lua | Account-wide per-game levels, walking rewards, zone/area discovery and creature kills |
| Achievements.lua | Base account achievements, shared rewards, real-WoW dungeon tracks, Dungeon Dwellers game tracks and common statistics |
| AchievementExpansion.lua | 300 TBC Anniversary achievements, completion filters, expanded tracking, class-filter UI and category browser |
| ClassAchievements.lua | 90 class-only achievements, per-class account counters, spell/combat tracking and known class-spell backfills |
| GameAudio.lua | Background loops, effects and gain variants |
| Quality.lua | SavedVariables clamping, chat storage repair, capture diagnostics and `/cc chatcheck` |
| Developer.lua | Runtime, module and asset reports including Tetris set count |
| Settings.lua | Settings UI and controls |

| DungeonCrawlerContent.lua | New enemy roster, level-gated pools, class armour library and final placeholder texture paths |

- `DungeonCrawlerContent.lua` owns enemy, boss, crate, armour artwork and armour-stat profiles.
- `SoloGames.lua` owns the Dungeon chest popup, three-choice generation, queued-drop restoration and reward claiming.
- `SoloGames.lua` owns armour selection, artwork application, Collection/Statistics/Pass rendering and runtime combat effects.
- `DungeonDwellersProgression.lua` owns Dungeon Pass XP, claims, permanent boon totals and WoW activity event hooks.


Friends.lua synchronises the active Blizzard roster on login and every roster update, then merges it with the account-wide character-friend directory. Core.lua owns persistent identity links, current-session Battle.net routes, all chat capture paths, optimistic outgoing rows and delivery reconciliation. UI.lua renders add/remove controls, sending/failed status, ALT presence badges and right-side contact-route tabs.
