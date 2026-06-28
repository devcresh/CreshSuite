# UI Reference

The main console top accent is the main Battle Pass XP bar. A compact themed `BP <level>` / `<balance> COINS` button sits in the header row and opens the Battle Pass drawer.

## Tetris cosmetics and play screens

**BLOCK THEMES** and **BACKGROUNDS** are separate tabs. Block-theme rows preview seven tetromino colours and never display zone textures. The Backgrounds gallery contains 50 zone images, supports All/Unlocked/Locked filters and opens a 500-pixel preview overlay for locked, active, unlocked or equipped images.

During play, the current block theme is labelled `BLOCKS`, while the reveal artwork is labelled `IMAGE`. Every solo, CPU and multiplayer board has an explicit 10x20 grid drawn above the image. The local side panel and multiplayer centre panel include score, lines, speed, time/mode, reveal progress, next-row requirement and compact controls. Timed formats show timer/reset information; attack formats show incoming/outgoing garbage.

## Friends and account conversations
The Friends view combines Battle.net accounts, character friends and current-zone quest givers. Battle.net accounts are grouped as **BATTLE.NET ONLINE** or **BATTLE.NET OFFLINE** and appear on every alt. Clicking either state opens the account-wide conversation. Party invite, game challenge and voice controls appear only when the account currently exposes an active WoW character.

Direct conversation labels use the saved Battle.net account name rather than the internal `BNET:` key. Normal player whispers and Battle.net messages share the same conversation list and persist across character changes.

## Notification hub
Normal system notifications occupy the full-size main slot. Whisper, Guild, friend-presence, party-invite and Battle Pass cards use the compact slide lane. The newest slide card is promoted into the main slot whenever no normal notification is present, then smoothly moves into the configured lane when a normal notification arrives. Slide direction can be **TOP**, **BOTTOM**, **LEFT** or **RIGHT**. Cards use a thin source-colour line across the top and the **Overall popup size** setting scales the complete hub together. Right-dragging any card moves the hub when card position is unlocked.

Battle Pass slide cards cover exploration milestones, pass level-ups, ready/claimed rewards, claim-all summaries and purchased theme unlocks. Clicking a Battle Pass card opens the Battle Pass drawer.

## Console dismissal
The named main frame is registered as a WoW Escape-closeable special frame. Escape closes the main console and also dismisses the connected composer and open Games/Battle Pass drawer. The focused composer explicitly calls the same close path so keyboard focus cannot leave part of the console visible.

## Solo Tetris
The Tetris view has tabs for **TIMED ENDLESS**, **VS CPU**, **TETRIS PASS**, **PIECES** and **BACKGROUNDS**. Timed Endless supports 5, 10, 15, 30, 45 and 60 minute runs. VS CPU shows both boards simultaneously and switches between **TIMED ENDLESS** and **ENDLESS ATTACK**. The play panel uses graphical Score, Lines, Speed and Time/Mode cards, a background-reveal progress bar, next-row/full-image line counts and a compact controls guide at the bottom.

The **BACKGROUNDS** gallery displays all 50 reveal images in eight-card pages. Filters cycle through **ALL**, **UNLOCKED** and **LOCKED**. Each card shows its preview, ownership state, equipped state or current 0–100 reveal progress. Every 10 cumulative cleared lines exposes one horizontal image row; the full image unlocks at 100 lines.

The active theme name has previous/next controls that cycle through unlocked sets. Landing ghosts and vertical guides remain visible on the local board.

## Theme collection
Six compact rows appear beside a large mini-board preview. Clicking any row previews the complete seven-piece palette, including locked sets. Owned sets can be equipped with one click. Locked sets show the requirement and route to the relevant Tetris Pass, main Battle Pass or game-level goal. **SHOW: ALL** and **SHOW: UNLOCKED** simplify browsing.

## Multiplayer Tetris
Multiplayer Timed Endless and Endless Attack use the same ten-row reveal renderer. The centre panel contains a graphical YOU-versus-opponent card, line comparison bars, local and opponent reveal stages, next-image-row information and mode-specific reset/garbage details. A compact bottom strip lists movement, rotation, soft drop, hard drop and mode controls.

The multiplayer view shows both 10 × 20 boards at once with names, score, line and status information in the centre. **TIMED ENDLESS** and **ENDLESS ATTACK** controls sit above the boards. A duration control cycles Timed Endless through 5, 10, 15, 30, 45 and 60 minutes. Each player’s selected theme/background is shown at reduced opacity, while occupancy, active piece, timer, reset count and pending garbage refresh through compact protocol-v5 addon messages.

## Dungeon armour
The hero panel places a compact CLASS button beside a 158-pixel ARMOUR button. The full-body plate is anchored below both controls and above the statistics/minion rows so tier text and controls cannot overlap the character art. The loadout panel uses five rows with icon, tier, wrapped effect summary and EQUIP/LOCKED state.


## Dungeon chest popup
A full-screen mouse blocker places a 650 × 390 themed modal above the Dungeon stage. The closed state shows crate art and odds. The revealed state replaces the open action with three 196 × 126 reward cards. Space/Enter opens the chest; keys 1–3 claim cards. No close control is provided because a dropped reward must be resolved before play continues.

## Dungeon dice
The action panel displays up to four hero-side dice and one enemy die. The active side shakes and cycles faces for approximately 0.44 seconds, then settles on the actual roll. The inactive side remains steady so the player can distinguish attack and retaliation rolls.

## Dungeon Dwellers archive
A **DWELLERS** control on the Dungeon header opens a 680 × 470 overlay. **COLLECTION** provides category, ownership and class filters with mouse-wheel scrolling. **STATS** displays aggregate totals and per-class maximum-room records. **DWELLER PASS** shows current XP, activity counters, active boons, six scrollable reward rows and a claim-all control. Escape closes this archive before returning to normal Dungeon keyboard controls. Dungeon Pass level/reward notifications use a dedicated DD slide-out; clicking one opens this Pass tab without restarting an existing run.


## Friends and direct-message controls

- The Friends header `+` button accepts a character name or BattleTag.
- Every non-quest friend row includes a remove button.
- A linked friend online on a different known character displays an `ALT` badge; hover identifies the character and clicking opens its direct whisper.
- Right-side contact routes appear for linked conversations:
  - `B.NET`: account conversation, shared across the friend's characters.
  - `MAIN`: direct whisper to the saved main character.
  - `ALT`: direct whisper to the currently active alternate character.
- Each route preserves its own conversation history and send target.


## Tetris image layering

1. Neutral frame backdrop.
2. Dark full zone image.
3. Bright revealed image bands.
4. Nearly transparent empty-cell surfaces and solid tetrominoes.
5. Grid lines, highlights and guide lines.

This ordering prevents block-theme background colours from appearing as reveal tiles.

## Party invitations and chat

When party-popup replacement is enabled, CreshChat visually suppresses Blizzard's invite frame without hiding or cancelling it. The custom card stays actionable until the client resolves the invitation. While grouped, the Party tab is always visible; party messages are also retained in the combined General feed.

## v0.3.77 social roster rails

- **Friends:** Battle.net Online, Game Friends Online, Battle.net Offline, Game Friends Offline, Previous Whispers.
- **Party:** current `player` and `party1`–`party4` units only; raid and local `/who` entries are excluded.
- **Raid:** current `raid1`–`raid40` units only.
- **Instance:** follows the current party or raid unit roster.
- **Guild:** Online and Offline guild members.
- **General/public feeds:** current-area Online and Offline / Left Area entries.

Party and Raid members already in the group do not show a redundant Party Invite action.
