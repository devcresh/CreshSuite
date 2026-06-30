# SavedVariables schema 75

Schema 73 keeps the account-wide progression store, adds class-specific achievement counters, and separates real WoW dungeon statistics from Dungeon Dwellers game statistics.

## Account progression root

`CreshChatDB.accountProgression` owns the live versions of:

- `soloGames`
- `arcadeRewards` (Cresh Coins, Battle Pass XP, claims and themes)
- `gameProgression` (game levels, exploration and achievements)
- `gameHistory`
- `gameLeaderboards`
- `multiplayerStats`
- `cardDecks`

The legacy top-level fields are rebound to these same tables so existing modules continue to work without parallel saves.

## Achievement data

`accountProgression.gameProgression.achievements` contains:

- `unlocked`: achievement key to unlock timestamp/value
- `stats`: deaths, flights, dungeon mobs, bosses and dungeon entries
- `uniqueBosses`: account-wide boss-name registry
- `professionRanks`: highest observed rank for each profession across characters
- `visitedZones`: achievement zone registry
- `totalCoins` and `totalPassXP`: lifetime achievement rewards

## Migration

Every pre-schema-70 character progression snapshot is considered. Numeric progression retains the strongest existing value and collections are unioned, preventing duplicate profile snapshots from inflating balances while preserving owned content. Interface layout, chat storage, friends and notification settings remain under their existing profile/account stores.


## Roster visibility

`ui` stores six independent booleans, all defaulting to `true` during migration:

- `showGameFriendsOnline`
- `showGameFriendsOffline`
- `showBattleNetFriendsOnline`
- `showBattleNetFriendsOffline`
- `showGuildMembersOnline`
- `showGuildMembersOffline`

Friend roster filters apply only to Blizzard game/Battle.net friend sources. Guild visibility is evaluated separately.

## Achievement expansion

`accountProgression.gameProgression.achievements.expansion` stores account-wide live counters and keyed maps for the 300 TBC goals. Historical activities not exposed by Blizzard begin at schema 72.


## Class achievement progress

`accountProgression.gameProgression.achievements.classProgress` contains:

- `stats[classToken][metric]`: account-wide class-action counters, isolated by class.
- `uniquePets`: Hunter pet names observed after successful tames or from the current active pet.
- `lastUpdated`: the most recent class-progress update time.

Only a character of the matching class records progress. Unlocks and rewards remain shared account-wide.

## Dungeon separation

Real WoW dungeon goals use the `achievements.expansion` five-player dungeon counters. Dungeon Dwellers goals read only `accountProgression.soloGames.dungeon` (`runs`, `kills`, `bosses`, and `bossKillsByType`) and are displayed under Cresh Games. The two sources no longer contribute to one another.
