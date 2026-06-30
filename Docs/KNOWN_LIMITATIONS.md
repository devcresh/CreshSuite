# Known Limitations

- Reserved Druid and Shaman armour icons/full-body images remain placeholders until those future-class art sets are supplied.
- The chest reveal is functional but does not yet include animated lid frames, particles or crate-opening sound variations.
- Portrait and full-body cosmetic rewards are stored as tokens until the custom player-profile image library is available.
- Dungeon run and boss checkpoint combat state is not preserved through `/reload`, logout or client closure; unopened chest drops are preserved separately.
- Boss and high-level enemy balance is data-driven but should be tuned through live play, particularly levels 150–200.
- Battle.net numeric account IDs are live-session routes rather than permanent conversation identities. CreshChat reconnects history using BattleTag/account identity when available; a contact exposed only as an anonymous numeric ID may not be matched across a later session until the roster provides identifying data.
- Battle.net rich presence and active-character details depend on the fields exposed by the specific TBC Anniversary client build. Chat remains available when those optional details are absent, but character-only party/game/voice actions require an active WoW character route.


## Friend main/alt identification

WoW does not expose an account identifier for arbitrary character-only friends. CreshChat can label a character as a linked alt only when Battle.net presence has exposed the same account/character relationship, usually after the main and alternate characters have both been seen. Unlinked character friends still remain account-wide in CreshChat, but no automatic MAIN/ALT tabs are shown until that relationship can be established.

## Character friend import across alts

WoW exposes only the currently logged-in character's ordinary character-friend list. CreshChat cannot discover a friend that existed only on a different alt before this build until that alt is logged in once. After each alt has loaded v0.3.71 once, its observed friends remain in the shared CreshChat account directory on every alt.

Cached Battle.net entries may be displayed offline while the live roster is temporarily unavailable, but sending/removing through Blizzard requires the current session's numeric account route to be refreshed first. This deliberately prevents stale IDs from being reused after relogging.
