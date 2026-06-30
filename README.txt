CreshChat v0.2.3 — Modular Feature System and Games-Only Mode (Unreleased)

- Adds a Settings > Modules panel to genuinely enable/disable Chat, Games, World
  Progression, Combat Tracking, Quest Capture, Friends, Voice, Notifications and
  related subsystems, with one-click presets (Full, Games Only, Chat Only, Minimal).
- Adds Games-Only mode: play the Games hub, Battle Pass and Achievements with Chat
  fully disabled.
- Adds a Progress Hub for World Progression, Quest and Combat stats, reachable
  even with Chat and Games both disabled.
- All existing accounts upgrade with every module enabled by default — no change
  in behaviour unless you visit Settings > Modules.
- Fixes several cases where a disabled module could still be reached (slash
  commands, toast notifications) or still award progress, plus a bug where every
  finished game funded the Battle Pass twice.
- See CHANGELOG.txt for full details and the previous v0.2.2 / v0.2.1 release notes.

--- Previous release ---

CreshChat v0.2.1 — Final Compatibility and UI Audit

- Repairs direct and backup live chat capture for Whisper, Guild, Officer, public channels, Party, Raid and Instance tabs.
- Refreshes the visible CreshChat conversation immediately when a live CHAT_MSG event arrives.
- Suppresses only the unavailable-player whisper system line and marks the outgoing row failed instead.
- Routes Blizzard player-frame, target-frame, party-frame and raid-frame Whisper actions into CreshChat.
- Preserves all 531 account-wide achievements, games, progression, social rosters and notification controls.
