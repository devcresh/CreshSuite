# CreshChat Release Audit — v0.2
Date: 2026-06-29

---

## 1. Selected Addon Version

**0.2**

Both `CreshChat.toc` (`## Version: 0.2`) and `Core.lua` (`CC.BUILD.version = "0.2"`) declare this version consistently. The CHANGELOG heading "CreshChat v0.2 - Final Compatibility and UI Audit" confirms this is the intended current release. All prior 0.3.x entries in the changelog are internal development history; the developer intentionally reset the public version to 0.2.

---

## 2. Target Client and Interface Number

- **Game**: World of Warcraft: Burning Crusade Classic Anniversary Edition
- **Interface**: `20505` (declared in `.toc` and confirmed in `CC.BUILD.interface`)
- No Retail, Classic Era, Cataclysm, or Mists interface numbers are present.

---

## 3. Git Working-Tree Status

Several files are staged but not yet committed, including large batches of `ArtSource/` texture remaster artwork. These are development/source assets and are excluded from the release ZIP. The two most important malformed tracked files are noted under Section 5 (Files Quarantined).

Recent commits on `main` (last 7):
- `cf6b19f` fix: notify users when chat capture falls back to Blizzard chat
- `e53254c` Merge pull request #4 from devcresh/fix/chatcheck-help-text
- `6cc33a9` fix: update /cc chatcheck help text to mention filter status output
- `373364e` fix: complete TBC compatibility and stability audit
- `aadb188` Fix CreshChat console toggle
- `d94879c` Create CreshChat development baseline
- `6728484` Baseline before AI development setup

---

## 4. Files Examined

- `CreshChat.toc` — TOC declarations, Interface number, version, SavedVariables
- `Core.lua` — version constants, schema migration code, chat send/receive, timers, event handlers
- `BattlePass.lua` — in-game progression, Cresh Coins, "premium" themes (in-game only)
- `CardDecks.lua`, `CardDeckLibrary.lua` — card game logic, deck ordering
- `Games.lua` — multiplayer game coordinator, addon message prefix and throttling
- `Voice.lua` — voice-call signaling via addon messages over WHISPER
- `SoundLibrary.lua`, `GameAudio.lua` — audio registrations
- `Achievements.lua`, `AchievementExpansion.lua`, `ClassAchievements.lua` — achievement catalogue
- `DungeonCrawlerContent.lua`, `DungeonDwellersAssetSets.lua`, `DungeonDwellersProgression.lua` — dungeon game
- `ChessTextureManifest.lua`, `TetrisThemes.lua` — media manifests
- `UI.lua`, `Settings.lua`, `Quality.lua`, `Developer.lua` — UI, settings, self-test
- `Quest.lua`, `Friends.lua`, `Themes.lua`, `Progression.lua`, `SoloGames.lua` — supporting modules
- `CHANGELOG.txt`, `README.txt`, `QC_REPORT.txt` — documentation
- `Media/` folder — 906 runtime media files (textures, sounds, music, voice icon)
- `.gitignore`, `.gitattributes`, `.vscode/settings.json` — dev tooling (excluded from ZIP)
- `ArtSource/` (tracked but not in ZIP) — source artwork for future texture remaster candidates
- `Docs/` (tracked but not in ZIP) — developer documentation

---

## 5. Compliance Findings

### A. Free Distribution
**PASS.** No paywalls, subscription tiers, Patreon links, Ko-fi links, PayPal requests, or premium-only feature gates were found. "Cresh Coins" and "premium themes" in `BattlePass.lua` are entirely in-game: coins are earned by playing and themes are unlocked by spending earned coins or claiming Battle Pass rewards. No real-money path exists.

### B. Visible Source Code
**PASS.** All 25 Lua modules are plain text, syntactically valid, and human-readable. No obfuscation, encoding, encryption, or compiled payloads are present. No DLL, EXE, BAT, CMD, MSI, or PowerShell scripts are included in the runtime addon package.

### C. No In-Game Advertising or Donation Requests
**PASS.** A full-text search across all Lua, TOC, and text files found no donation requests, Patreon mentions, Ko-fi mentions, PayPal mentions, subscription prompts, affiliate links, or commercial advertising. The only external-looking URL-shaped strings are WoW built-in texture paths (`Interface\Buttons\WHITE8X8`, `Interface\Icons\...`), which reference Blizzard's own internal resources.

### D. Realm, Network, Chat, and Performance Safety
**PASS — with notes.**

Addon messages:
- Games.lua uses prefix `"CRESHGAME"`, sent only via `WHISPER` to a named target — no broadcast.
- Voice.lua uses prefix `"CRVOICE1"`, sent only via `WHISPER` to a named target — no broadcast.
- Payload length is capped at 250 bytes before sending.
- Prefix registration is guarded against double-registration.
- Incoming messages validate prefix and channel (`WHISPER` only) before processing.
- Peer discovery is rate-limited to 6.7 probes/second with a 15-second cooldown and a 12-target cap (confirmed in CHANGELOG and QC_REPORT).

Timers: `C_Timer.After` is used for deferred execution. No `OnUpdate` frame handlers were found. No busy-loop timers. Timers are short-lived (0–1 second) for frame-defer operations.

Chat send: All outgoing chat goes through `CC:CallSendChatMessage` which guards against missing APIs, uses both `SendChatMessage` and `C_ChatInfo.SendChatMessage`, and only sends when the player explicitly types or acts.

Public chat (Say, Yell): requires explicit player slash-command action; not automatic.

### E. Automation and Protected Actions
**PASS.** No spell casting, item usage, targeting, or combat automation was found. Party invite acceptance uses `AcceptGroup` / `C_PartyInfo.AcceptInvite` from a real user button click. Party invite suppression uses visual overlay (frame made transparent/non-interactive) rather than `StaticPopup_Hide`. No protected-action calls were identified outside of legitimate click handlers.

### F. Privacy and Data Handling
**PASS.** No API keys, credentials, or external telemetry were found. The SavedVariables table (`CreshChatDB`) stores only player progression, UI preferences, and in-game social data needed for documented addon functionality. Schema 76 includes a migration that prunes oversized `playerCache` entries, actively reducing the SavedVariables footprint. No developer test data was found.

### G. Content and Copyright
**PARTIAL — see note.**

All Lua source code is original. Media files (TGA textures, OGG audio) appear to be original works created for this addon based on the art source naming convention and the structured batch pipeline visible in `ArtSource/TextureRemaster/`. However:
- **No LICENSE file** exists in the repository. There is no explicit license declaration for the addon or its assets.
- The QC_REPORT.txt states "no external executables, web requests, code obfuscation, advertisements, donation requests, combat automation or client modification were found" (prior static scan).
- AI-generated artwork is referenced in `ArtSource/TextureRemaster/GenerationPrompts.md` — these are source materials for the TGA textures. CurseForge's current policies do not prohibit AI-assisted artwork, but this should be disclosed if CurseForge requests it.

**Recommendation**: Add a brief license statement (e.g., "All Rights Reserved" or MIT/CC0) to the project before future releases.

---

## 6. Blizzard Policy Findings

No violations detected. Specifically confirmed absent:
- No automation of protected actions
- No currency generation or item duplication
- No chat spam
- No realm/server exploitation
- No client modification
- No bypassing of Blizzard's secure frame restrictions

---

## 7. CurseForge Moderation Findings

No violations detected. Specifically:
- No adult content
- No harassment material
- No hate speech
- No piracy
- No malware
- No hidden executables

---

## 8. Network / Addon-Message Findings

| Item | Status |
|------|--------|
| Addon prefix registered once per session | PASS |
| All messages sent only to specific WHISPER targets | PASS |
| No broadcast (PARTY, RAID, GUILD, SAY channels) | PASS |
| Payload length capped at 250 bytes | PASS |
| Incoming messages validated before use | PASS |
| Peer discovery rate-limited and cooldown-protected | PASS |
| No automatic login-wide probing | PASS (removed in v0.2) |

---

## 9. Performance Findings

| Item | Status |
|------|--------|
| No OnUpdate busy-loop handlers | PASS |
| C_Timer.After used for deferred work | PASS |
| Peer discovery rate-limited | PASS |
| playerCache pruned at schema 76 upgrade | PASS |
| No repeated SavedVariables rebuild | PASS |
| Media files loaded on demand, not pre-cached | PASS (inferred) |

---

## 10. Protected-Action Findings

No protected-action calls were found outside of click handlers. Party invite acceptance is triggered only by a real user button click. No spell casting, targeting, or combat logic automation was detected.

---

## 11. Privacy Findings

No credentials, tokens, personal data, or external telemetry detected. SavedVariables contain only documented in-game progression and UI state.

---

## 12. Copyright / Attribution Findings

- Original Lua source code: no third-party libraries detected.
- Original media assets: TGA textures and OGG audio appear to be created for this addon.
- AI-generated source artwork in `ArtSource/`: present in development tree, not in release ZIP.
- **No LICENSE file**: advisory warning — not a blocking issue for CurseForge upload but recommended for a future release.

---

## 13. Files Changed

| File | Change |
|------|--------|
| `CHANGELOG.txt` | Corrected schema version from 75 to 76 in v0.2 entry (matches Core.lua) |

---

## 14. Files Quarantined

| File | Reason |
|------|--------|
| `tatus` (12 269 bytes, root) | Accidental file containing pasted `git diff` output. Name is a fragment of "status". Copied to `quarantine/tatus.quarantine`. Not included in release ZIP. |
| `textures \`` (git index only, not on disk) | Filename with Unicode character — ghost entry in git index, does not exist on disk. Not copyable and automatically excluded. |

Neither file is a Lua source file or runtime asset. Their exclusion does not affect addon functionality.

---

## 15. Files Included in the ZIP

**26 Lua / TOC runtime files** (from `.toc`):
- `CreshChat.toc`
- `Core.lua`, `SoundLibrary.lua`, `Quest.lua`, `Friends.lua`, `Voice.lua`, `Themes.lua`
- `CardDeckLibrary.lua`, `CardDecks.lua`, `UI.lua`, `ChessTextureManifest.lua`
- `DungeonDwellersAssetSets.lua`, `DungeonCrawlerContent.lua`, `TetrisThemes.lua`
- `Games.lua`, `SoloGames.lua`, `BattlePass.lua`, `DungeonDwellersProgression.lua`
- `Progression.lua`, `Achievements.lua`, `AchievementExpansion.lua`, `ClassAchievements.lua`
- `GameAudio.lua`, `Quality.lua`, `Developer.lua`, `Settings.lua`

**906 media files** in `Media/` (textures, sounds, music, voice icon):
- `Media/GameAudio/Music/` — 16 OGG music files (arcade, cards, dungeon, strategy; 4 volume variants each)
- `Media/GameAudio/SFX/` — 40 OGG SFX files (card_flip, game_loss, game_move, game_win, level_up, tetris_line_clear, tetris_reveal, ui_click; 4 variants each)
- `Media/Games/Cards/` — 6 card deck folders × 54 cards + back + jokers + deck icons
- `Media/Games/Chess/` — 12 chess piece TGAs
- `Media/Games/DungeonDwellers/` — boss art, class armour, chests, crates, dice, enemy icons, player portraits/full-body, reward icons
- `Media/Games/Icons8Bit/` — 8 game launch icons
- `Media/Games/Tetris/Backgrounds/` — 50 zone background TGAs
- `Media/Sounds/` — 80 notification SFX OGGs (arcane_pulse, bubble_pop, crystal_ping, soft_bell, whisper_tone, wood_tick; 4 variants each)
- `Media/Voice/Microphone.tga` — voice-call UI icon

**Total ZIP entries**: 958 (includes directory entries)

---

## 16. Files Deliberately Excluded

- `.git/`, `.gitignore`, `.gitattributes`, `.vscode/` — repository tooling
- `ArtSource/` — source artwork and texture remaster pipeline (not runtime)
- `Docs/` — developer documentation
- `AGENTS.md`, `CLAUDE.md` — AI development instructions
- `CHANGELOG.txt`, `README.txt` — not required at runtime; content reproduced in CurseForge changelog
- `QC_REPORT.txt`, `FILE_MANIFEST.txt` — development reports
- `tools/` — packaging scripts
- `quarantine/` — quarantined malformed files
- `release/` — release output folder (not packaged into itself)
- `tatus`, `textures \`` — malformed filenames (quarantined)

---

## 17. Tests Performed (Static)

| Test | Result |
|------|--------|
| TOC Interface value = 20505 | PASS |
| TOC Version = "0.2" | PASS |
| Core.lua version = "0.2" | PASS |
| All 25 TOC-listed Lua files exist on disk | PASS |
| No TOC-listed file is missing | PASS |
| No donation/payment text in Lua sources | PASS |
| No external URLs in Lua sources | PASS |
| No DLL/EXE/BAT/PS1 in release ZIP | PASS |
| No nested archives in release ZIP | PASS |
| No SavedVariables in release ZIP | PASS |
| No ArtSource/Docs/dev files in release ZIP | PASS |
| ZIP top-level folder = CreshChat/ | PASS |
| CreshChat/CreshChat.toc present in ZIP | PASS |
| No path traversal entries in ZIP | PASS |
| SHA-256 hash computed | PASS |
| Malformed filenames detected and quarantined | PASS |
| Schema 76 migration present and meaningful | PASS |

---

## 18. Tests That Could Not Be Performed

The following require the actual WoW TBC Anniversary client and are outside the scope of static analysis:

- Lua syntax validation against the live WoW client parser
- XML well-formedness (no XML files present — N/A)
- In-game load without Lua errors
- Chat capture for each tab type
- Whisper send and receive
- Guild/Officer chat
- Party and raid messaging
- Addon message multiplayer game session
- Voice call handshake
- Battle Pass and Dungeon Dwellers gameplay
- Achievement tracking triggers
- SavedVariables migration from previous schema versions
- Frame-rate and memory profile under load
- Secure button taint check
- `/reload` and logout/login persistence

---

## 19. Manual In-Game Test Checklist

Before shipping to a broader audience, verify in-game:

- [ ] Login without Lua errors (`/console scriptErrors 1`)
- [ ] `/reload` without Lua errors
- [ ] Open CreshChat console; all tabs load
- [ ] Type in whisper, guild, party, general tabs — messages send and appear
- [ ] Receive a whisper from another character — notification card appears
- [ ] Right-click a player frame → Whisper routes into CreshChat
- [ ] Whisper an offline character — row marked failed, no Blizzard system message shown
- [ ] Join a party; Party tab appears automatically
- [ ] Accept a party invite via CreshChat card — join confirmed
- [ ] Open Friends tab — game friends and Battle.net friends visible
- [ ] Open Settings — all pages render; sliders adjust live
- [ ] Play one Dungeon Dwellers run to completion
- [ ] Play one Tetris game and verify background reveal
- [ ] Claim a Battle Pass reward
- [ ] Claim a Dungeon Pass reward
- [ ] Check `/cc version` output matches "0.2"
- [ ] Enter and exit combat — no taint errors
- [ ] Log out and back in — chat history and achievements persist

---

## 20. Remaining Warnings

1. **No LICENSE file** — the addon and its assets have no declared license. Advisory warning, not a CurseForge upload blocker, but recommended for future releases.
2. **`tatus` ghost in git index** — the `tatus` file should be removed from git tracking (`git rm tatus`) at the next opportunity to clean the repository.
3. **`textures ` Unicode ghost** — a git index entry with a Unicode filename that does not exist on disk. Should be removed from git (`git rm "textures \`"`).
4. **AI-generated artwork disclosure** — if CurseForge explicitly requires disclosure of AI-generated assets, the artwork in `Media/Games/DungeonDwellers/` and `Media/Games/Cards/` was generated using AI pipelines visible in `ArtSource/TextureRemaster/GenerationPrompts.md`.
5. **Schema 76 CHANGELOG/QC_REPORT discrepancy** — corrected in this release (CHANGELOG.txt now says schema 76). QC_REPORT.txt still references schema 75 but is a dev-only file excluded from the ZIP.

---

## 21. Blocking Issues

**None.** The addon is compliant with Blizzard's add-on development policy and CurseForge moderation requirements based on static analysis.

---

## 22. Final ZIP Path

```
release/CreshChat-0.2-TBC-Anniversary.zip
```

Full path:
```
D:\Battlenet\World of Warcraft\_anniversary_\Interface\AddOns\CreshChat\release\CreshChat-0.2-TBC-Anniversary.zip
```

---

## 23. ZIP File Count and Size

| Metric | Value |
|--------|-------|
| Total entries | 958 |
| Uncompressed size | 121.23 MB |
| Compressed size | 24.22 MB |
| Compression ratio | ~80% |

---

## 24. SHA-256 Hash

```
A00E97F78E9D60B5E8FABECFD7E5E75C03FA9568CBDD3F779B35E7BEEDD0A74B
```

---

## 25. Final Recommendation

> **READY AFTER MANUAL IN-GAME TEST**

Static analysis, policy review, and packaging validation all pass. The addon should be tested in the live TBC Anniversary client using the checklist in Section 19 before a broader public announcement. The ZIP is otherwise ready for CurseForge upload.

---

*This is a best-effort compliance audit. It is not formal legal approval from Blizzard Entertainment or CurseForge/Overwolf.*
