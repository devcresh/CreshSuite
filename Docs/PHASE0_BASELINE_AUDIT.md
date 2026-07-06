# Phase 0 — Baseline Audit and Catalog Freeze

No runtime changes were made in this phase. This is a factual snapshot of the
current progression systems, taken before the CreshSuite Progression and
Unlockables Rework begins.

## 1. Battle Pass / Mastery tracks

| Track | File | Max level | Next-level cost formula | SavedVariables |
|---|---|---|---|---|
| CreshCollect main pass | `CreshCollect/BattlePass.lua` | 200 | `50 + (level-1)*5` | `CreshCollectDB.arcadeRewards` |
| CreshGames arcade pass | `CreshGames/GamesBattlePass.lua` | 50 | `50 + (level-1)*5` (reuses Collect's formula) | `CreshGamesDB.battlePass` (fresh, not migrated) |
| Tetris Pass | `CreshGames/TetrisThemes.lua` | 100 | `35 + (level-1)*2.5` | `CreshGamesDB.soloGames.tetris` (`.passXP`, `.passClaimed`) |
| Dungeon Dwellers Pass | `CreshGames/DungeonDwellersProgression.lua` | 100 | `40 + (level-1)*4` | `CreshGamesDB.soloGames.dungeon.battlePass` |

Reward cadence:
- **Collect pass**: coins every level; 9 levels (10,15,25,35,40,55,75,95,100) pay 150-500 bonus coins (formerly card-deck/Tetris-theme rewards, migrated out in the prior phase); 5 world/chat-theme unlocks at levels 110-200.
- **Games arcade pass**: coins every level; `gameRewardCatalog` grants (card decks / Tetris themes) at 9 specific levels — the same 9 rewards redistributed from Collect's old 100-level track.
- **Tetris Pass**: 20 "mini pass" theme unlocks (levels 10-100 step 10) + 10 more via an `extraThemes` table (levels 5,15,25,...,95); separately, 5 "MAIN_PASS" premium themes unlock when CreshCollect's main pass reaches levels 15/35/55/75/95.
- **Dungeon Dwellers Pass**: coins + stat buffs (maxHP, attack, minionPower, regenRoom, regenTurn, bossDamage, extraDieChance, coinBonus) per level; full per-level table not enumerated in this pass (accessor-only read).

**Overlap**: four independent leveling curves/state trees exist today, each with its own SavedVariables location. Collect's and Games' passes are an intentional split (confirmed by in-code comments from the prior phase); Tetris and Dungeon Dwellers passes are pre-existing, separate systems this rework will convert to "Mastery" tracks per Phase 4.

## 2. Achievement keys

| File | Keys | Categories |
|---|---|---|
| `Achievements.lua` | 152 | EXPLORATION, COMBAT, DUNGEONS, PROFESSIONS, GAMES |
| `AchievementExpansion.lua` | 300 | QUESTS, COMBAT, COMMUNITY, DUNGEONS, EXPLORATION, PROFESSIONS, PVP, RAIDS, REPUTATION |
| `ClassAchievements.lua` | 135 | CLASSES |
| `DungeonAchievements.lua` | 93 | Dungeon Dweller-specific |

- Account catalog (excluding Dungeon Dwellers) = 152 + 300 + 135 = **587**, matches expected baseline exactly.
- Dungeon Dwellers = **93**, matches expected baseline exactly.
- GAMES-category achievements inside `Achievements.lua` = **23** (GAME_PLAYS, GAME_WINS, GAME_LEVELS, UNLOCKS series), matches expected baseline exactly. These are the CreshGames-mini-game achievements mixed into the account catalog that Phase 5 will move.
- All non-GAMES categories are genuine WoW-world achievements (quests, zones, kills, dungeons, raids, reputation, PvP, professions, classes, community) and must not be removed per the rework's terminology rules.
- Not exhaustively cross-checked: exact-string key collisions between the `ACH_` prefix used in both `Achievements.lua` and `DungeonAchievements.lua`.

## 3. Reward/unlock catalogs

| Catalog | File | Count found | Expected | Status |
|---|---|---|---|---|
| Card decks | `CardDeckLibrary.lua` | 7 | 7 | Matches |
| Tetris themes | `TetrisThemes.lua` | 50 (15 direct GAME_LEVEL + 5 direct MAIN_PASS + 10 via `miniThemes` loop (TETRIS_PASS) + 20 via `extraThemes` loop (10 GAME_LEVEL + 10 TETRIS_PASS)) | 50 | Matches (corrected — see note) |
| Tetris backgrounds | `TetrisThemes.lua` | 50 (`zoneRevealThemes` table, lines 247-296) | 50 | Matches |
| Dungeon armour sets | `DungeonCrawlerContent.lua` (`Content.armourSets`, not `DungeonDwellersAssetSets.lua`) | 50 (10 classes × 5 tiers: PALADIN/WARRIOR/ROGUE/RANGER/MAGE/PRIEST/WARLOCK/DEFENDER = 40 live sets, matching `liveArmourCount = 40`; DRUID/SHAMAN = 10 more, explicitly reserved placeholder art per file header comment) | 50 | Matches (corrected — see note) |

**Correction note**: the original audit pass mis-counted both figures.
- *Tetris themes*: a naive grep for `addTheme(` also matched the function's own `local function addTheme(...)` definition line and miscounted the two loop-driven blocks; reading `TetrisThemes.lua` directly (lines 133-242) confirms exactly 50 unique theme entries — matches baseline.
- *Dungeon armour*: `DungeonDwellersAssetSets.lua` genuinely has no armour category (it only holds portraits/full-body/minion/boss cosmetics, 7 asset sets) — the real armour catalog lives in `DungeonCrawlerContent.lua`'s `Content.armourSets` table, keyed by class, which the original pass didn't inspect. It holds 8 fully-live classes × 5 tiers (40 sets, matching the `liveArmourCount = 40` field exactly) plus Druid and Shaman × 5 tiers (10 more sets) explicitly marked as reserved placeholder art awaiting real assets. Total defined entries = 50, matching baseline exactly; 40 are currently live, 10 are placeholder-only pending art.

No further reconciliation needed before Phase 4 — both catalogs are already at the expected size. The one real note to carry into Phase 4: Druid/Shaman armour tiers exist as data but have `placeholderArt = true` and must stay excluded from live reward grants until real art is supplied (per the rework's rule against including placeholder cosmetics in global pass rewards).

## 4. CreshChat themes

- `Themes.lua`: 75 named presets + 10 guild presets.
- `UI.lua` holds 25 more base presets merged at runtime into `THEME_PRESETS`.
- Total: 75 + 25 = **100 named themes**, + **10 guild themes** = **110**, matches expected baseline exactly.
- No unlock/source/shop/achievement field exists on any theme entry today — themes are not currently gated by any acquisition mechanism in `Themes.lua`. Phase 7's 20/15/20/45 distribution work starts from an ungated baseline, not a partially-gated one.
- CreshChat's persisted "selected theme" SavedVariables path was not located in this pass (likely `Core.lua`/`Settings.lua`) — flag for Phase 1 API work.

## 5. SavedVariables locations

`.toc` declarations:
- `CreshChat.toc` → `CreshChatDB`
- `CreshCollect.toc` → `CreshCollectDB`
- `CreshGames.toc` → `CreshGamesDB`

Known sub-key mapping:
- Collect main pass → `CreshCollectDB.arcadeRewards`
- Collect per-game level migration source (frozen) → `CreshCollectDB.gameProgression.games`
- Collect exploration tracking → `CreshCollectDB.gameProgression.exploration`
- Games arcade pass → `CreshGamesDB.battlePass`
- Games per-game level tracking → `CreshGamesDB.gameLevels`
- Tetris (state + pass + themes/backgrounds) → `CreshGamesDB.soloGames.tetris`
- Dungeon Dwellers (stats + pass) → `CreshGamesDB.soloGames.dungeon` (pass sub-table `.battlePass`)
- Card decks → `CreshGamesDB.cardDecks`

## 6. Duplicates / overlaps identified

1. **Tetris theme unlock triple-path**: `Tetris.miniPassThemeRewards` (Tetris Pass) and `MAIN_PASS`-tagged themes (Collect's main pass) both ultimately call `Tetris:UnlockTheme`, meaning the same theme key can be reached through two independent progression systems. Not a bug today (different theme keys per path), but a structural risk once tracks are consolidated into Mastery.
2. **Four independent leveling curves** (Collect 200-lvl, Games 50-lvl, Tetris 100-lvl, Dungeon 100-lvl) with near-identical closed-form XP formulas but different constants — expected given the plan's Mastery-track design, not a bug, but confirms the scope of Phase 3/4 work.
3. **Dungeon armour catalog location**: the real armour data lives in `DungeonCrawlerContent.lua`, not `DungeonDwellersAssetSets.lua` where a first pass would expect it — worth keeping in mind for Phase 4/9 so the Mastery-armour UI reads from the correct file.

## Stable keys identified as migration-safe

- Achievement keys (`ACH_*`, `EXP_*`, class-achievement keys) — stable strings, safe to carry forward as-is or alias.
- Card deck keys (`Classic_8Bit`, `Alliance_Vanguard`, `Horde_Warband`, `Fel_Crusade`, `Shattrath_Light`, `Netherstorm_Arcana`, `Dark_Portal`) — stable, only 7, low migration risk.
- CreshChat theme keys — stable strings, no current gating, low migration risk for Phase 7 as long as new source-tagging is additive.

## Migration risks flagged for later phases

- Per-level Dungeon Dwellers reward table not fully enumerated — must be read in full before Phase 4 conversion to avoid silently dropping a buff tier.
- Druid and Shaman armour tiers (10 of the 50 armour-set entries) are placeholder-art-only (`placeholderArt = true`) — Phase 4 must keep them excluded from live Mastery reward grants until real art exists, per the rework's rule against placeholder cosmetics in global pass rewards.
- CreshChat's actual persisted theme-ownership storage path is unconfirmed — needed before Phase 7's entitlement-cache design.
