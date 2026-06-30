# v0.2.3 — Modular Feature System and Games-Only Mode (Unreleased)

Schema 79. Adds FeatureManager.lua (11 toggleable subsystems, dependency cascades,
4 presets), a Settings > Modules panel, Games-Only mode (UI:BuildGamesAnchor
replaces the main chat frame when Chat is disabled), the Progress Hub, and an
adaptive C launcher that appears whenever Chat, Games, Game Progression or the
Progress Hub is enabled. Fixes a gap where World Progression's background polling
didn't fully stop when the module was disabled, and closes a structural isolation
gap in AchievementExpansion:RecordQuestTurnIn.

A subsequent multi-phase audit (combat/achievement correctness, progression
routing, major-feature repairs, UI/navigation, assets) found and fixed several
related feature-isolation gaps: a handful of entry points (game drawer modes,
combat panel, solo game launch, voice calls) could still run when reached
directly even with their owning module disabled; the toast notification system
didn't respect the Notifications or Friends/Presence flags; and game completions
could award progress with Game Progression disabled. It also found and fixed a
genuine duplicate-reward bug where every finished game funded the Battle Pass
twice through two independent, uncoordinated reward paths. See CHANGELOG.txt for
full detail.

## v0.2.2 — Per-Character Combat Tracking and Class Achievement Key Migration

Schema 78. Per-character combat tracking alongside the account-aggregate table;
CHARACTER scope for class achievements; class achievement keys renamed from
CLASS_*_NNN to the stable ACH_CLASS_*_NNN format via an idempotent migration.

## v0.2.1 — Version Correction

Version numbering correction only (v0.2 → v0.2.1); no schema change, no
functional changes.

# v0.2 — Final Compatibility and UI Audit

Public version reset; schema 75; responsive header, complete live settings coverage, paced addon networking and final policy review.

## 0.3.84 — Live Chat and Unit-Frame Whisper Repair

- Repaired retryable direct/filter/FrameXML chat capture and immediate visible-tab refresh.
- Routed native unit-menu Whisper actions into CreshChat with cross-realm target resolution.
- Suppressed only unavailable-player whisper system lines while preserving an inline failed message.
- Upgraded SavedVariables to schema 74.

## 0.3.83 — Class Achievements and Dungeon Split

- Added 90 account-wide class-only achievements across all nine TBC classes.
- Added class filters to the achievement browser.
- Separated real WoW dungeon counters from Dungeon Dwellers counters.
- Moved Dungeon Dwellers achievements into the Games category.
- Upgraded SavedVariables to schema 73 without resetting progression.

## 0.3.82 — TBC Achievement Expansion

- Expanded account achievements from 108 to 408 with 300 TBC Anniversary goals.
- Added completion filters for Achievements and claim-state filters for Battle Pass rewards.
- Added live quest, exploration, dungeon, raid, profession, reputation, PvP and community tracking.
- Moved social roster-card visibility to Windows settings and repaired TBC legacy Battle.net roster parsing.

## 0.3.81 — Roster Visibility Controls

- Independent online/offline filters for Game Friends, Battle.net Friends and Guild members.
- Friend directories remain isolated from the guild roster.
- Schema 71 migration enables all new filters by default.

## v0.3.79 — Account Progression and Achievements

- Rebound Battle Pass, Cresh Coins, all games, records, collections and unlocks to `accountProgression`.
- Added a safe schema-70 migration that keeps strongest progress and unions ownership across existing character profiles.
- Added 108 tiered achievements covering exploration, combat, detailed dungeon progress, professions and Cresh games.
- Added increasing coin/Pass XP rewards, improved exploration rewards and direct actual-dungeon boss rewards.
- Added an `ACH unlocked/total` button beside Battle Pass with search and category filtering.
- Added account-wide event tracking for deaths, flights, zones, dungeon entries, mobs, bosses and professions.

## v0.3.77 — Social Roster Sections

- Isolated the Party roster from General `/who` results and limited it to current party units only.
- Added Online and Offline sections for Party, Raid and Instance group rosters.
- Split Friends into separate Battle.net and in-game Online/Offline sections, followed by Previous Whispers.
- Preserved duplicate source membership when someone is both a Battle.net and character friend.
- Kept exact character-friend connectivity independent from an online Battle.net alt.
- Kept SavedVariables schema 68 unchanged.

## v0.3.76 — TBC Friend Actions

- Filtered Battle.net Friends by the Burning Crusade Classic project ID instead of the generic WoW client code.
- Added explicit account-message and active-character whisper controls alongside Party and Voice actions.
- Suppressed Blizzard's Who UI while retaining CreshChat's General-area roster refresh.
- Applied the selected theme accent to the active Friends tab.
- Kept SavedVariables schema 68 unchanged.

## v0.3.75 — Notification Control Centre

- Consolidated all notification-card settings into one page.
- Added per-category visibility, priority, sound and volume, with card visibility independent from category sound.
- Added global notification animation selection.
- Routed public mentions and group messages into configured card categories.
- Added schema 68 migration while preserving all existing data.

## v0.3.74 — Social Rosters & Whisper Actions

- Added prominent Add Friend and Party Invite controls to whisper conversations.
- Grouped the Friends page into `FRIENDS` and `PREVIOUS WHISPERS`.
- Rendered Battle.net account names as the primary contact, with the currently active WoW character beneath in an accent colour.
- Added online/offline Guild membership to the Guild chat sidebar.
- Added a throttled current-zone player rail to General, retaining missing names as `OFFLINE / LEFT AREA`.
- Added row actions for whispers, guild members and local players while preserving the custom party-invite flow.
- Kept SavedVariables schema 67 unchanged.

## v0.3.73 — Custom Party Invite Repair

- Restored the CreshChat party invitation card as the only visible invite interface by default.
- Added an immediate `StaticPopup_Show` compatibility hook that suppresses only Blizzard PARTY_INVITE popup types.
- Changed ACCEPT to call the party API directly from the CreshChat hardware click instead of clicking Blizzard's hidden Yes button.
- Kept the native popup transparent until group membership is confirmed, then dismissed and restored its reusable frame state.
- Extended the Classic acceptance-race safeguard before treating a cancellation as final.
- Renamed the setting to `Use CreshChat party invite only`.
- Migrated SavedVariables to schema 67 without clearing existing data.

## v0.3.72 — Messaging, Friends & Invite Repair

- Routed common chat aliases directly through guarded WoW chat APIs, retaining Blizzard handling for non-chat slash commands.
- Added fallback support for global and namespaced chat/Battle.net APIs.
- Repaired Friends tab click priority and migrated every existing profile to keep the tab visible.
- Combined legacy and modern character/Battle.net roster APIs and separated online/offline contacts.
- Changed party acceptance to prefer Blizzard's own popup button and fall back across both accept APIs.
- Disabled party-popup replacement by default so guild and unrelated invitation popups remain native.
- Migrated SavedVariables to schema 66.

## v0.3.71 — Chat Foundation Repair

- Rebuilt chat capture around direct events with duplicate-safe Blizzard handler/filter fallbacks.
- Added history self-repair and protected UI dispatch so one malformed table or UI callback cannot disable all chat.
- Added immediate outgoing rows and delivery reconciliation for direct, guild, group, local and named-channel messages.
- Added automatic Blizzard-chat restoration after repeated processing failures.
- Synchronised character friends on login and every roster update without requiring the Friends view.
- Preserved cached Battle.net identities while refusing to reuse stale numeric routes after relogging.
- Added `/cc chatcheck`, expanded health diagnostics and migrated SavedVariables to schema 65.

## v0.3.70 — Party Invite & Chat Fix

- Replaced destructive party-popup hiding with transparent, non-interactive visual suppression.
- Added dedicated accept and decline compatibility wrappers.
- Kept pending invite cards active and protected from notification trimming.
- Automatically exposes the Party tab while grouped.
- Verified party and party-leader messages in Party and General views.
- Schema remains 64.

## v0.3.69 — Tetris Image Reveal Fix

- Rebuilt the reveal renderer around the actual zone texture rather than coloured empty cells.
- Added a dark full-image base and ten bright cropped bands revealed every 10 lines.
- Moved image layers above legacy TBC backdrops and below blocks/grid lines.
- Applied the renderer consistently to solo, CPU and multiplayer boards in both supported formats.
- Kept SavedVariables schema 64 and multiplayer protocol 5.

## v0.3.68 — Tetris Theme & Background Separation

- Separated 50 block colour themes from 50 WoW-zone image backgrounds.
- Retired the 20 palette textures as board images while retaining their block colour sets.
- Added large image previews and independent selected-background ownership fields.
- Added explicit grid lines above image artwork in solo, CPU and multiplayer.
- Reflowed multiplayer versus information and controls to prevent overlap.
- Audited Timed Endless and Endless Attack across local, CPU and multiplayer screens.
- Migrated SavedVariables to schema 64 while preserving partial reveal progress; protocol remains 5.

## v0.3.67 — Account Friends & Alt Chat

- Immediate outgoing whisper rows with event reconciliation and no duplicates.
- Account-wide ordinary character-friend directory across player alts.
- Friends-header add dialog and per-row account removal.
- Removal markers prevent deleted entries being restored by another alt's local roster.
- Battle.net-linked active-character and known-main metadata.
- ALT status badge with hover name and direct-chat shortcut.
- Right-side B.NET / MAIN / ALT conversation route tabs.
- Schema 63 migration preserving all existing user data.

## v0.3.66 — Tetris Reveal & Match UI
- Fixed reveal strips so the first background row is visibly drawn at 10 cumulative lines in solo, CPU and multiplayer Tetris.
- Added a 70-image background gallery with All, Unlocked and Locked filters, preview art and progress states.
- Added exact lines-to-next-row and lines-to-full-image information to every Tetris play mode.
- Added compact bottom control guides and graphical score, line, time, speed, versus, garbage and reveal panels.
- Migrated SavedVariables to schema 62 while preserving Tetris progression and all other addon data.

## v0.3.65 — Dungeon Collection & Battle Pass
- Added filterable Collection, Statistics and Dungeon Dwellers Battle Pass tabs to the Dungeon game.
- Added persistent minion-skin ownership/recruit counts and per-class run records.
- Added a 100-level activity pass with Cresh Coins and permanent Dungeon combat/economy boons.
- Connected WoW kills, quests, first-time zones, achievements and Dungeon kills to both the Dungeon pass and main CreshChat pass.
- Migrated SavedVariables to schema 61 without resetting existing content.

## v0.3.64 — Tetris Zone Reveal
- Stretched the standard relative gravity curve across 1,000 speed levels at 10 lines per level.
- Added ten-section reveal progression to every solo, CPU and multiplayer Tetris format.
- Added 50 original WoW-zone-themed TGA backgrounds, increasing the catalogue to 100 themes and 70 reveal images.
- Upgraded multiplayer protocol to 5 and SavedVariables schema to 60.

## v0.3.63 — Account-wide Friends and conversations
- Added account-wide Battle.net online/offline friends to the CreshChat Friends panel.
- Added stable Battle.net account conversations with refreshed live sending routes.
- Shared normal whisper and Battle.net history between alts while leaving public/local feeds session-only.
- Added modern and legacy TBC Battle.net API compatibility.
- Migrated SavedVariables to schema 59 and merged/de-duplicated previous per-character whisper logs.

## v0.3.62 — Directional notification hub
- Replaced separate priority/secondary popup lanes with a coordinated main-slot and slide-out notification hub.
- Added configurable top, bottom, left and right slide directions and one overall hub scale control.
- Promotes the newest slide notification to the full-size main slot when no normal notice exists, then smoothly demotes it when a normal notice arrives.
- Added top-edge notification-colour lines and compact slide cards for Whisper, Guild, friend, party and Battle Pass events.
- Added Battle Pass goal, level, reward and theme-unlock slide-outs with direct drawer navigation.
- Registered the console for Escape dismissal and made focused composer Escape close the entire console/drawer group.
- Migrated SavedVariables to schema 58 while preserving existing popup size preferences and character profiles.

## v0.3.61 — Tetris reveal progression and Dungeon dice UI
- Removed Race 10 from solo and multiplayer Tetris.
- Added Timed Endless and Endless Attack to local CPU and multiplayer play, with 5–60 minute Timed Endless durations.
- Fixed false top-outs caused by Endless Attack garbage arriving while a locked piece was still treated as active.
- Added translucent single-line landing guides, generated line-clear/reveal audio and progressive solo background reveals.
- Background themes reveal every 10 lines, unlock at 100 lines and then rotate to the next available image.
- Reworked Dungeon dice into equal-size centred cards and kept the attack control permanently visible.
- Migrated SavedVariables to schema 57 and multiplayer protocol 4.

## v0.3.60 — Dungeon dice, UI audit and expanded Tetris
- Repaired Dungeon hero/enemy full-body layout overlap, tier labels, armour controls and long armour stat rows.
- Added eight animated dice faces and a webbed-die texture in WoW TBC-ready TGA format.
- Added rolling/shaking hero and enemy dice to Dungeon attacks.
- Split multiplayer Tetris into Race 10, timed Endless and Endless Attack with 5–60 minute duration choices.
- Fixed the incoming-garbage state-order bug that caused false top-outs after a row was sent.
- Added 20 piece/background theme sets, bringing the Tetris collection to 50.
- Migrated SavedVariables to schema 56.

## v0.3.59 — Boss art pack 2
- Converted the remaining 10 generated boss composite images into WoW TBC-ready textures.
- Added matching 256×256 icons and 256×512 full-body art for Nexus Lord Vaelrix, High Seer Skyrend, Akoru the Soulkeeper, Sunblade Grand Magister, Gorvak the Unchained, The Drowned Ancient, Astralax the Devourer, Prototype Omega-Reaver, ZLR Arena Overlord and CATS, Master of the Base.
- All 20 milestone bosses now use integrated artwork.
- Remaining placeholders are limited to the reserved Druid and Shaman armour sets.

## v0.3.58 — ZLR Arena Overlord artwork
- Replaced the ZLR Arena Overlord placeholder with the selected Quake-inspired boss artwork.
- Added matching 256×256 icon and 256×512 full-body TGA files.
- Preserved the existing boss asset key and texture paths.

## v0.3.57 — Boss art pack 1
- Converted the first 10 generated boss composite images into WoW TBC-ready textures.
- Added matching 256×256 icons and 256×512 full-body art for King Candlewick, Gnarlfang the Packlord, Murkfin Tide King, Zariss the Coil Queen, Grumbar Earthbreaker, Stormtalon Matriarch, Xavros Felwhisper, Azarak the Web Tyrant, Lord Coldgrave and Emperor Blackfuse.
- Kept the existing boss asset keys and Lua paths unchanged so the new art loads automatically.
- Remaining milestone bosses 11–20, Druid/Shaman armour sets and custom profile cosmetics remain on placeholders.

# Version History

## v0.3.56 — Dungeon texture pack integration

- Integrated pack v4.0 for 20 enemies, 40 active-class armour sets, five milestone chests and five reward icons.
- Chest popups now use progressive full-size chest art and reward cards display their matching icons.
- Boss and future Druid/Shaman art remains on placeholders pending separate assets.
- Schema remains 55.

## v0.3.55 — Dungeon chest choice
- Replaced automatic crate resolution with a themed chest reveal popup.
- Added three generated reward cards and one-choice claiming by mouse or keys 1–3.
- Added multi-crate queueing and persistent unopened drops.
- Added selected reward details to crate history.
- Migrated SavedVariables to schema 55.

## v0.3.54 — Dungeon enemy balance
- Replaced shallow enemy health and Attack growth with nonlinear level-based curves.
- Added stronger health acceleration after level 100 and additional Attack growth after level 120.
- Applied controlled per-enemy variance while preserving enemy-type and boss multipliers.
- Added a reusable data-driven balance table and validation report.
- Kept SavedVariables schema 54 unchanged.

## v0.3.53 — Dungeon armour statistics
- Added 20 fixed milestone bosses across levels 10–200 with active unique mechanics.
- Added boss checkpoint retries, guaranteed crates, armour drops, first-kill rewards and pity systems.
- Added 40 boss placeholder textures and four TBC-ready crate textures.
- Migrated SavedVariables to schema 54.

## v0.3.52 — Dungeon boss milestones
- Added 20 fixed milestone bosses across levels 10–200 with active unique mechanics.
- Added boss checkpoint retries, guaranteed crates, armour drops, first-kill rewards and pity systems.
- Added 40 boss placeholder textures and four TBC-ready crate textures.
- Migrated SavedVariables to schema 53.

## v0.3.51 — Dungeon content placeholders
- Added 20 level-gated enemy types and per-type kill tracking.
- Added five named armour tiers for eight active classes plus reserved Druid and Shaman libraries.
- Added final-path TGA placeholders for every enemy icon, enemy full body, armour icon and armour full body.
- Migrated SavedVariables to schema 52.


## v0.3.50 — Tetris versus and theme preview
- Added large mini-board previews for all 30 themes, one-click equip, unlocked filtering and quick owned-theme cycling.
- Rebuilt VS Computer and multiplayer around visible simultaneous 10 x 20 boards.
- Added a real lightweight CPU board with placement, clears, garbage receiving and top-out.
- Added Race 10 and Endless Attack formats to CPU and multiplayer games.
- Added garbage attacks, cancellation and bottom-row insertion.
- Added compact live multiplayer board snapshots and raised Tetris protocol to 2.
- Migrated SavedVariables to schema 51 while preserving all schema-50 progression and unlocks.

## v0.3.49 — Tetris expansion
- Added 10-Line Challenge, VS Computer and Endless Tetris modes.
- Added five CPU difficulties, live race progress and persistent VS/Endless statistics.
- Added 30 collectible piece themes and achievement-style game-level unlocks.
- Added a separate 100-level Tetris Pass with coins and ten exclusive themes.
- Added five premium Tetris sets to the main Battle Pass.
- Added landing ghosts and vertical landing-guide lines to Solo and multiplayer Tetris.
- Migrated SavedVariables to schema 50 while preserving schema 49 profiles and progression.

## v0.3.48 — Battle Pass header control
- Moved the Battle Pass indicator into the main header control row.
- Combined BP level and coin balance in a compact themed two-line button.
- Added direct Battle Pass drawer access and active/hover theme states.
- Kept SavedVariables schema 49 unchanged.

## v0.3.47 — Character profiles and session-clean chat
- Added independent per-character progression and interface profiles.
- Added Settings > Profiles UI/layout copying.
- Cleared captured chat and whisper history at login/reload.
- Migrated SavedVariables to schema 49.

## v0.3.46 — Progression, voice and game audio
- Added 1,000-step rewards, Battle Pass goals, console economy displays, CreshChat voice coordination, game audio and repaired game XP bars.
- Removed Daily/Weekly activities, navigation, TomTom and Questie integrations.

## v0.3.32–0.3.45 — Games, themes and media
- Added the arcade, progression, card decks, game art, custom sounds, Dungeon Dweller systems and developer documentation.
