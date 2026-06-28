# CreshChat v0.2

Current runtime build: **0.2**, SavedVariables schema **75**, WoW interface **20505**.

This final compatibility build preserves the complete CreshChat feature set while resetting the public release number to v0.2. It includes live chat routing, account-wide progression, 531 achievements, social rosters, the notification centre, games, Battle Pass, Cresh Coins, themes, voice-call integration and the responsive console UI.

Start with `DEVELOPER_GUIDE.md`, then use the module, schema, event, UI, game, asset, policy and test references in this directory.

## Current architecture

- `Core.lua` owns SavedVariables migration, direct/backup chat capture, native slash-command routing, chat delivery state, party invitations and account/profile binding.
- `UI.lua` owns the main console, connected composer, responsive two-row header, roster collapse, cards, drawers and pop-outs.
- `Friends.lua` owns Game Friends, TBC Anniversary Battle.net friends, Guild/group/local rosters and social actions.
- `Achievements.lua`, `AchievementExpansion.lua` and `ClassAchievements.lua` provide 531 account-wide achievements.
- `Games.lua`, `SoloGames.lua`, `DungeonDwellersProgression.lua` and `BattlePass.lua` own multiplayer/solo games, Dungeon Dwellers, shared unlocks and reward progression.

## Release audit

- Missing live settings were added to the Settings UI.
- Main header controls use separate global/context rows to avoid narrow-width overlap.
- Top-level windows use clamping or explicit screen-bound positioning and safe scale limits.
- Addon-message peer discovery is capped, paced and cooldown-protected.
- No external networking, executables, advertising, donation solicitation, client modification or combat automation is bundled.

See `FINAL_UI_SETTINGS_AUDIT_V0.2.md`, `NETWORK_AND_POLICY_REVIEW_V0.2.md` and `VALIDATION_0.2.json` for the final review.
