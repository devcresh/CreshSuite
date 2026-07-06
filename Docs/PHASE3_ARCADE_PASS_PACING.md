# Phase 3 — Arcade Battle Pass Pacing Report

Generated from the real `Pass.balance` table and `GetCumulativeXP` formula in
`addons/CreshGames/GamesBattlePass.lua` (not hand-calculated) via a one-off
script loading the production file directly. Re-run any time `Pass.balance`
changes to get updated numbers.

## Method

"Games required for level N" = `ceil(GetCumulativeXP(N) / averageXPPerGame)`
for three named play profiles, each defined transparently from balance
constants (not an arbitrary guess):

| Profile | Definition | Average XP/game |
|---|---|---|
| Casual solo | Mostly solo RUN-type games, low scores, no multiplayer/achievements/mastery | 16.7 |
| Regular mixed | Wins/losses, occasional multiplayer, light achievement/Mastery trickle | 32.9 |
| Dedicated grinder | Frequent multiplayer wins, active achievement/Mastery hunting | 78.0 |

## Results

| Level | Casual solo | Regular mixed | Dedicated grinder |
|---|---|---|---|
| 10 | 38 games | 20 games | 9 games |
| 25 | 155 games | 79 games | 34 games |
| 50 | 500 games | 254 games | 107 games |
| 75 | 1,033 games | 523 games | 221 games |
| 100 | 1,753 games | 888 games | 375 games |

Cumulative XP required: level 10 = 630, level 25 = 2,580, level 50 = 8,330,
level 75 = 17,205, level 100 = 29,205.

## Assessment

- **Dedicated grinder** reaches the level 100 capstone in the low hundreds of
  games -- plausible over a few months of active multi-game play across the
  suite's 8 mini-games.
- **Regular mixed** and especially **Casual solo** are considerably grindier
  for a full 100-level completion (888 and 1,753 games respectively). Levels
  1-50 (where the real card-deck/Tetris-theme rewards live) complete in a
  much more reasonable range for all three profiles, since level 50's
  cumulative cost (8,330 XP) is well under a third of the full pass's total.
- This is presented as data, not a recommendation to retune -- there was no
  stated target completion time to design against. If a faster or slower
  full-pass pace is wanted, every relevant constant (`xpGameStart`,
  `xpCompleteWin/Draw/Loss`, `xpMultiplayerMultiplier`, `xpMasteryLevelUp`,
  `xpAchievementUnlock`, `xpBaseCost`/`xpCostPerLevel`) lives in the single
  `Pass.balance` table, so retuning is a one-place edit with no other code
  changes required.
