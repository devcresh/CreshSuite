# CreshChat Developer Guide — v0.3.56

CreshChat uses one addon namespace (`CC`) loaded by `Core.lua`. Modules register through `CC:RegisterModule`. SavedVariables use `CreshChatDB` at schema 75. Account-wide Battle Pass, Cresh Coins, games, unlocks and all 537 achievements live in the shared progression store; character profiles retain interface placement and profile-specific chat presentation. Schema migrations preserve existing data and expose compatibility aliases only where older modules still require them.

## Tetris ownership and rewards
`TetrisThemes.lua` owns the 100-set catalogue, 70-background reveal rotation, 1,000-level speed curve, stable keys, ownership checks, selected set and 100-level Tetris Pass. Do not store full palettes in SavedVariables. Add new sets to the catalogue with a unique key and a supported source (`DEFAULT`, `GAME_LEVEL`, `TETRIS_PASS`, `MAIN_PASS`).

## Solo and CPU Tetris
`SoloGames.lua` owns the 10 x 20 player board, landing guides, theme preview gallery, quick theme cycling, the visible CPU board and CPU garbage logic. `cpuVersusMode` persists as `RACE` or `ENDLESS`. Keep CPU evaluation bounded; it runs inside the WoW UI thread.

## Multiplayer Tetris
`Games.lua` owns challenge/session transport and Tetris protocol 2. Multiplayer STAT payloads contain packed board rows and active-piece metadata. Keep each addon message below 250 bytes. Any incompatible payload change must increment `Games.protocol` and preserve the explicit old-client rejection path.

## Endless Attack
Both engines use the same 1/2/4/6 line-clear attack table, incoming cancellation and bottom garbage insertion. Garbage is applied after a piece locks. Match state and board snapshots are transient; only the preferred `multiplayerMode` and records persist.

## Release checks
Run Lua parser validation on all TOC entries, construct both Tetris views against the frame mock, exercise a forced line clear and board snapshot round trip, validate media paths and package hashes, then test two real TBC clients before public release.
