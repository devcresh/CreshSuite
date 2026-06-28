# Game and Progression Systems

## Account-wide progression and achievements
Schema 70 stores the main Battle Pass, Cresh Coins, game levels, game saves, records, decks, themes, Dungeon collections and all unlocks in one account progression record. Switching characters changes interface/chat profile data but never swaps game ownership or currency.

The Achievements drawer sits beside Battle Pass and contains 408 goals with search, completion status, and Questing, Exploration, Dungeons, Raids, Combat, Professions, Reputation, PvP, Community and Games filters. Each track has escalating tiers; later tiers award increasingly larger Cresh Coin and Battle Pass XP amounts. Dungeon coverage is intentionally deeper, separating dungeon mobs, total bosses, different bosses and dungeon expeditions.

Tracked account activities include estimated walking steps, discovered zones/areas, completed taxi flights, creature kills, deaths, actual WoW dungeon entries/mobs/bosses, Dungeon Dwellers progress, profession ranks and Cresh game participation/wins/levels/unlocks. Historical statistics that Blizzard does not expose, such as old deaths or flights from before installation, begin tracking with this build.

## Shared game levels
Each game has independent persistent XP. Participation and completed results award XP, with multiplayer results doubled. Every game level awards Cresh Coins and main Battle Pass XP. Tetris game levels also unlock selected piece sets.

## Tetris
Tetris centres on **Timed Endless** and **Endless Attack** across solo, CPU and multiplayer play. The automatic-drop curve uses the relative percentages of the common Tetris Worlds / Guideline gravity table, interpolated smoothly across 1,000 CreshChat speed levels. One speed level requires 10 cleared lines. Level 1 drops one row every 0.90 seconds; level 1,000 reaches the no-lock-delay safety cap of 0.10 seconds per row.

### Independent cosmetics
The cosmetic system is intentionally split:

- **50 block themes** control only tetromino colours, highlights, landing-guide colour and the solid board tint.
- **50 image backgrounds** are 256x256 uncompressed 32-bit TGA zone artworks used only by the reveal renderer.

No block theme contains a background texture path. `selectedTheme` and `selectedBackground` are independent, so changing block colours cannot replace the reveal image.

### Image reveal
Background reveal progress is shared by every current Tetris format. The active locked image is divided into ten horizontal strips drawn above the board backdrop and below the cells/pieces. Each 10 cumulative cleared lines reveals one additional strip; at 100 lines the complete image is shown, ownership is saved and progression advances to the next locked image. Explicit 10x20 grid lines are rendered above the image and empty-cell tint so board boundaries remain readable.

Multiplayer protocol 5 transmits the active image key and reveal stage so each player can see both boards' progress. Partial progress survives schema-64 migration even when an older save pointed at one of the retired block-texture backgrounds.

### Interface coverage
The **Block Themes** tab previews/equips tetromino palettes. The separate **Backgrounds** gallery displays all 50 images in eight-card pages with All, Unlocked and Locked filters and a large preview overlay. Solo, VS CPU and multiplayer screens all include controls guidance, graphical score/line information, reveal progress and appropriate timer, reset, comparison or garbage information.

## Dungeon enemy level scaling
Dungeon enemies use a nonlinear curve defined by `DungeonCrawlerContent.enemyBalance`. Normal enemy health combines a base value, linear level growth, quadratic growth and an additional post-level-100 term. Attack combines steady level growth, quadratic growth and a post-level-120 ramp.

The generator applies approximately 8% health variance and 7% Attack variance, followed by the selected enemy type's `hpMultiplier` and `attackBonus`. Milestone bosses use the same scaled base before boss-tier additions and the boss record's unique health multiplier and Attack bonus. This keeps later enemies relevant without scaling directly from the current player build or changing difficulty mid-fight.

Reference base values before enemy-type modifiers:

| Level | Normal HP | Normal Attack | Boss base HP | Boss base Attack |
|---:|---:|---:|---:|---:|
| 10 | 21 | 2 | 49 | 3 |
| 40 | 87 | 9 | 193 | 12 |
| 80 | 216 | 23 | 467 | 29 |
| 100 | 297 | 32 | 637 | 39 |
| 150 | 564 | 63 | 1,191 | 73 |
| 200 | 931 | 103 | 1,945 | 117 |

## Dungeon dice presentation
Dungeon attacks now use eight custom dice-face textures. Hero, armour bonus and minion rolls appear on the left of the action card; the enemy roll appears on the right. The relevant dice rapidly cycle faces and use a short decaying positional shake before settling on the actual result. A dedicated webbed-die face represents a trapped minion. The attack control remains visible and mouse-enabled throughout the run; guarded clicks cannot start another attack until the current player/enemy roll sequence or reward state has completed.

## Dungeon milestone bosses
Dungeon Dweller uses ordinary encounter rooms between fixed boss gates. A milestone boss appears on levels 10, 20, 30 and every tenth level. The next level cannot be entered until the guardian and any summoned adds are defeated.

The first 20 milestone bosses are unique and cover levels 10–200. Their data includes permanent keys, names, creature families, stat multipliers, coin ranges, crate quality weights, armour chances, first-kill rewards and final art paths. Above level 200 the roster repeats while room-based health and attack scaling continue.

### Active boss mechanics
- King Candlewick: empowered candle extinguished by a high roll.
- Gnarlfang: summons packlings.
- Murkfin: interruptible tidal healing.
- Zariss: alternating shield and assault stance.
- Grumbar: warned earthquake attack.
- Stormtalon: airborne evasion followed by a dive.
- Xavros: Fel Drain damage and healing.
- Azarak: minion or hero webbing.
- Lord Coldgrave: freezes the next hero attack.
- Emperor Blackfuse: timed bombs.
- Vaelrix: phase evasion and ambush.
- Skyrend: stacking War Winds.
- Akoru: summoned soul echoes.
- Sunblade Grand Magister: Attack theft.
- Gorvak: rage thresholds at 75%, 50% and 25% health.
- Drowned Ancient: regenerating bark armour.
- Astralax: absorbs high rolls into Arcane Discharge.
- Omega-Reaver: rotating armour, assault and repair modes.
- ZLR Arena Overlord: scheduled double attacks.
- CATS: staged drones and warned Base Laser attacks.

### Boss checkpoints
Entering a milestone room snapshots hero maximum health, Attack, minions, score and kills. Dying during that fight enables **Retry Boss**, restoring the pre-boss party and resetting the complete encounter. Ordinary-room deaths still begin a fresh run.

### Crates and rewards
Every completed milestone grants boss coins and one crate drop. The Dungeon action controls are paused while the chest popup is active. The player opens the displayed crate, receives three generated reward cards and selects exactly one. Multiple drops are queued and shown sequentially. Unopened drops are stored in the active character profile and restored after reload.

The three choices are generated as:
- **Wealth:** a guaranteed Cresh Coin option within the crate's configured range.
- **Power:** permanent starting Attack or Armour Shards, weighted by crate quality and damage chance.
- **Collection:** class armour, portrait token, full-body token, enhanced shards or a larger coin payout using the crate's armour and cosmetic odds.

Crate quality shifts upward at higher milestones:

| Boss levels | Adventurer | Warbound | Royal | Voidlord |
|---|---:|---:|---:|---:|
| 10–40 | 70% | 20% | 9% | 1% |
| 50–90 | 50% | 27% | 18% | 5% |
| 100–140 | 35% | 30% | 27% | 8% |
| 150–190 | 20% | 30% | 38% | 12% |
| 200 | 10% | 25% | 45% | 20% |

Crates can offer Cresh Coins, permanent Dungeon damage, Armour Shards, class armour, portrait tokens and full-body tokens. Only the selected card is granted. A ten-boss pity counter forces a Voidlord Reliquary if none has dropped. Crate history records the claimed option.

### Armour rewards
Boss armour always uses the selected Dungeon class. Direct drop chances and eligible tiers are stored per boss. A five-boss pity counter forces an eligible armour result. Duplicate armour converts into two Armour Shards; ten shards automatically unlock the next missing eligible class set.

### Armour loadouts and combat statistics
Every armour set contains a static `stats` table. Supported effects are bonus Max HP, starting Attack, fixed extra dice, chance-based bonus dice, double damage, bleed damage over time, turn regeneration, room healing, flat damage reduction, block chance/strength, evasion, boss damage and minion damage.

The ARMOUR window displays the five sets for the selected class. Locked skins remain previewable; unlocked skins can be equipped with one click. Equipping or removing a set begins a fresh run. This prevents swapping health, dice or defensive bonuses during a boss checkpoint.

Extra dice attack independently and use each set's `extraDiePower` scaling. Bleed ticks before the enemy action and can defeat an enemy before it attacks. Turn regeneration occurs after surviving the enemy action. Room regeneration is applied when the room is cleared. Class and armour defence values stack, with evasion capped at 60% and block chance capped at 75%.


## Dungeon collection and statistics
The **DWELLERS** button opens one archive with Collection, Statistics and Dungeon Dwellers Battle Pass tabs. Collection entries are built from the live minion-variant, class, armour, crate, milestone-chest and reward-icon tables. Filters can limit the list by category, locked/unlocked state and class. Recruiting a minion records both its gameplay archetype and exact visual variant.

Lifetime Dungeon statistics retain aggregate totals and add independent records for every playable class. A class record tracks runs, maximum room, kills, bosses, best score and deaths. Starting a run, clearing rooms, defeating enemies and ending a run update these records automatically.

## Dungeon Dwellers Battle Pass
The dedicated pass has 100 levels. Level costs begin at 40 XP and rise by 4 XP per level. Supported awards are:

| Activity | Dungeon Pass XP | Main CreshChat Pass XP |
|---|---:|---:|
| WoW mob kill | 1 | 1 |
| Dungeon enemy | 2 | 1 |
| Dungeon milestone boss | 5 | 3 |
| Quest turn-in | 15 | 5 |
| First visit to a zone | 20 | Existing exploration award only |
| WoW achievement | 50 | 15 |

Every reached level has a claimable Cresh Coin reward. Milestones also grant permanent Dungeon boons: starting Max HP, starting Attack, recruited-minion power, room healing, turn regeneration, boss damage, bonus-die chance and Dungeon coin bonuses. Claimed totals are merged with armour statistics when a run starts. Health, Attack and minion-power rewards can also update a live run safely when claimed from the pass panel.

## Main Battle Pass and exploration
Every 1,000 estimated steps awards 1 Cresh Coin and 1 main Battle Pass XP. New-area discovery, walking, mob-kill milestones and completed games feed the shared progression systems.

### Live Dungeon artwork

Texture pack v4.0 supplies live artwork for the 20 expansion enemies and all 40 active-class armour sets. The chest-choice overlay uses five progressive milestone chest displays and matching badges. Reward choices use dedicated icons for coin, damage, portrait, full-body and armour/shard rewards.


## Dark-image reveal renderer

Each Tetris board draws the current zone texture in three ordered layers: the frame backdrop, a very dark full-image silhouette, and up to ten bright cropped bands. Tetromino cells render above those image layers, while explicit grid lines render above both the image and cells. Every ten cumulative cleared lines activates the next band from the bottom upward. The same renderer is called by local solo/CPU play and both multiplayer boards.
