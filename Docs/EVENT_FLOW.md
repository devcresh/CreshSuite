# Event Flow

## Chat

1. Core registers all supported `CHAT_MSG_*` events directly on its event frame.
2. Non-suppressing Blizzard chat filters and message-handler hooks act only as backup capture routes.
3. `ShouldProcessChatEvent` de-duplicates the same Blizzard line across those sources.
4. `EnsureChatStorage` repairs and rebinds account/local history tables before processing.
5. `HandleChatEvent` routes direct, guild and general/activity messages into the correct store.
6. `NotifyChatUI` isolates presentation errors from message storage.
7. Three consecutive processing failures mark capture unsafe and reveal Blizzard chat/input as a fallback.
8. Outgoing CreshChat sends insert a pending row first; the matching Blizzard event marks it delivered instead of appending a duplicate.

## Battle.net and character friends

`Friends.lua` requests and synchronises the active character roster on addon load, login, world entry and every `FRIENDLIST_UPDATE`. Observed character friends are written to the account directory immediately, without requiring the Friends UI. Battle.net roster events rebuild current-session numeric routes and update cached stable identity/display metadata. Cached numeric IDs are never restored as live routes after login.

## Shared progression
A game start/result records per-game XP and feeds the main Battle Pass. Tetris level-ups also call `Tetris:SyncUnlocks` to grant any newly reached achievement sets.

## Tetris run
1. A mode creates a local board and active/next pieces.
2. Movement or rotation recomputes the legal landing row used by the ghost and guide lines.
3. Locking a piece clears rows, updates score/speed and checks the mode target.
4. VS CPU advances an opponent work meter on a difficulty-based interval.
5. Completion writes records/history, awards shared game rewards and adds dedicated Tetris Pass XP.
6. Pass claims add Cresh Coins and may unlock a Tetris theme.

## Voice
CreshChat peers exchange addon HELLO/ACK and call-control messages. Native voice functions are only called after agreement and are guarded.

## Dungeon Dwellers progression
1. `Progression.lua` validates WoW combat-log kills, then awards Dungeon Pass and main Pass XP.
2. First-time area discovery keeps the existing main Battle Pass exploration reward and separately records a Dungeon Pass zone visit without duplicating the main reward.
3. `QUEST_TURNED_IN` awards both pass tracks and stores the quest activity count.
4. `ACHIEVEMENT_EARNED`, when exposed by the client, records each achievement once and awards both pass tracks.
5. Dungeon enemy defeat calls `RecordDungeonKill`; bosses use the higher award.
6. Reaching a level enables its reward row. Claiming adds coins through the central economy and persists permanent boon totals.
7. Dungeon combat reads the saved boon totals together with the equipped armour statistics.


## Optimistic outgoing whispers

1. `CC:SendMessage("WHISPER", ...)` creates a pending outgoing row before calling the Blizzard send API.
2. The UI refreshes immediately so the player always sees what they sent.
3. `CHAT_MSG_WHISPER_INFORM` or `CHAT_MSG_BN_WHISPER_INFORM` searches the recent conversation for the same pending text.
4. A match is marked delivered and reused; no duplicate row is inserted.
5. Battle.net event routing first uses saved author/account fingerprints, then validates numeric event candidates against Battle.net account information.

## Account friend synchronisation

`Friends:GetPlayerFriends()` reads the active character's Blizzard roster, mirrors non-removed entries into `accountChat.accountFriends`, then merges the account records back into the displayed list. This makes the CreshChat Friends view consistent across player alts even when the underlying client roster differs.
