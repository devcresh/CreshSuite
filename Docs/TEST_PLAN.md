# v0.3.77 Social Roster Sections test plan

## Party isolation

1. Join a five-player party and open Party.
2. Confirm the roster contains only the player and current `party1`–`party4` units.
3. Confirm no nearby `/who`, guild, friend or raid names appear.
4. Disconnect one party client and confirm that member moves to **OFFLINE** while connected members remain under **ONLINE**.
5. Leave the party and confirm the Party roster becomes empty without retaining cached names.
6. Convert the party to a raid and confirm the Party roster does not display raid members.

## Raid and instance rosters

1. Open Raid while in a raid and confirm only current `raid1`–`raid40` units appear.
2. Confirm connected and disconnected members are separated into **ONLINE** and **OFFLINE**.
3. Open Instance and confirm it follows the current party or raid roster rather than local `/who` results.

## Friends sections

1. Confirm Friends is ordered as **BATTLE.NET ONLINE**, **GAME FRIENDS ONLINE**, **BATTLE.NET OFFLINE**, **GAME FRIENDS OFFLINE**, then **PREVIOUS WHISPERS**.
2. Add the same person as both a Battle.net friend and a character friend and confirm both source entries remain visible.
3. Log that person onto a different Battle.net alt and confirm the exact saved character remains under Game Friends Offline while the Battle.net account remains online.
4. Confirm Battle.net contacts are still restricted to verified TBC Anniversary accounts.

## Existing roster regression

1. Open Guild and confirm Online and Offline guild-member sections remain available.
2. Open General and confirm the current-area Online and Offline / Left Area sections remain available without opening Blizzard's Who window.
3. Confirm current Party/Raid members do not receive a redundant Party Invite action.
4. Confirm row click, Add Friend, whisper and voice actions remain usable where appropriate.

# v0.3.75 Notification Control Centre regression

Confirm notification visibility, priority, animation, sound, volume and the custom party-invite card continue to use Settings > Notifications.
