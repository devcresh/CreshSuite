# Architecture

`Core.lua` owns defaults, schema migration, character-profile binding, account-wide direct-message storage, Battle.net identity/routing, chat capture, sound dispatch and slash commands. `Friends.lua` combines account-wide Battle.net contacts, character friends and current-zone quest givers. `UI.lua` owns the console, Friends/conversation presentation, drawer, messages and visual refreshes. `BattlePass.lua` owns Cresh Coins, main-pass XP, rewards and milestone goals. `Progression.lua` owns game levels, movement, area discovery and kill totals. `Voice.lua` owns addon presence/call handshakes. `GameAudio.lua` owns game playback.

Tetris is intentionally split:
- `TetrisThemes.lua`: the 30-set catalogue, ownership, selection and Tetris Pass rewards.
- `SoloGames.lua`: local board engine, large theme preview, quick theme selection, visible CPU board, Timed Endless, Endless Attack and background-reveal progression.
- `Games.lua`: multiplayer session transport, protocol-2 board snapshots, dual-board rendering and garbage exchange.

CPU and multiplayer match boards are transient. Only records, unlocks, selected theme, difficulty and versus-format preferences are stored. Multiplayer wire changes must remain below the addon-message limit and must increment the protocol when incompatible. Cross-module calls occur at runtime and remain nil-guarded.


Friends.lua now merges the active Blizzard roster with the account-wide character-friend directory, while Core.lua owns persistent identity links and pending-outgoing reconciliation. UI.lua renders add/remove controls, ALT presence badges and right-side contact-route tabs.
