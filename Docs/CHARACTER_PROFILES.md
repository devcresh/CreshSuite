# Character Profiles

CreshChat creates a profile the first time each `Character - Realm` loads the addon.

## Character-specific data
Each profile keeps its own:
- interface settings, theme selection and window positions
- console layout and notification preferences
- session-local Guild, General, Combat and quest feeds

## Account-wide progression
Every character now shares one progression store containing:
- Battle Pass XP, reward claims and Cresh Coins
- all Cresh game levels, XP, records and unlocks
- Dungeon Dwellers progress, armour, minions, crates and collection data
- card-deck ownership and collectible themes
- exploration totals and achievements

Existing per-character progression snapshots remain only as migration sources and are no longer rebound when switching characters.

## Copying interface settings
Open **Settings > Profiles**, select a character, then choose **COPY UI + LAYOUT**.

This copies visual and interface settings only: theme, colours, scale, console configuration, alerts, sounds, window dimensions and positions. Progression, currency, rewards, records, decks and unlock ownership are already shared account-wide, so they are not part of the copy operation.

A source character appears only after it has logged into CreshChat at least once.

## Chat lifecycle
Direct conversations are account-wide. Normal player whispers and Battle.net chats are stored in `accountChat`, remain available after `/reload`, and appear on every character using the same SavedVariables file.

Guild, General, Combat and quest-conversation feeds remain session-only. They are cleared on login or `/reload` and are not copied between character profiles. Clearing CreshChat history explicitly removes both the shared direct-message store and the local feeds. This does not affect Blizzard chat logs or game progression.

## Account friend lifecycle

Ordinary WoW character friends are character-specific in Blizzard's client, but CreshChat stores the union of every observed roster in `accountChat.accountFriends`. Synchronisation runs even when the Friends screen is closed. Existing friends that were never observed by this build require one login on the alt that owns them; after that, they appear on all profiles. Account-level removal markers prevent a different alt's roster from silently restoring a friend removed through CreshChat.
