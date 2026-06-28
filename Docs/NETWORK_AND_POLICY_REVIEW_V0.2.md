# CreshChat v0.2 — Network and Blizzard Policy Review

Review date: 27 June 2026

## Scope

Static review of all Lua, TOC and bundled text files. This is a technical compliance review, not legal advice and not a guarantee that Blizzard will never change its policies or APIs.

## Network behaviour

- CreshChat uses only Blizzard-provided in-game APIs.
- Chat is sent through `SendChatMessage`, `C_ChatInfo.SendChatMessage` or `BNSendWhisper` after a player action.
- Multiplayer games and voice-call handshakes use private `SendAddonMessage` whispers with registered prefixes.
- No HTTP, sockets, external processes, DLLs, executables, shell commands, telemetry upload or out-of-game service is present.
- Peer discovery is capped at 12 targets, spaced at 0.15 seconds and protected by a 15-second cooldown.
- Automatic full-roster probing at login has been removed.
- Fast multiplayer state updates were reduced to safer rates; payloads remain within the 250-byte addon-message limit used by this build.

## Player-action and automation review

- Sending chat, invitations, accepting/declining invitations, starting voice calls and game actions require a user click or key action.
- No movement, combat rotation, target selection, spell casting, item use, auction action or repeated input is automated.
- Achievement tracking observes Blizzard events and grants only CreshChat-local virtual progress; it does not alter WoW rewards or character state.
- The custom party invitation card calls Blizzard invite APIs only when the user clicks Accept or Decline.

## Add-on policy review

- Source code is visible Lua and is not obfuscated.
- The archive contains no advertisements or donation requests.
- Cresh Coins, Battle Pass and “premium” labels are entirely free, local, fictional unlock systems; there is no real-money purchase path.
- No offensive content was identified in the code/text audit.
- Network load was reduced to avoid unnecessary chat/addon-message traffic.

## Remaining limitations

- Blizzard may restrict or disable APIs at any time.
- Voice functionality depends on the client exposing the relevant `C_VoiceChat` functions.
- Protected UI behaviour can only be fully confirmed inside the live TBC Anniversary client.
- A live test should cover party acceptance, voice join/leave, Battle.net friends, Guild roster refresh, all chat routes and multiplayer games.
