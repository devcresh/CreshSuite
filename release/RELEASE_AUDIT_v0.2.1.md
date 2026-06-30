# CreshChat Release Audit — v0.2.1
Date: 2026-06-29

---

## 1. Selected Addon Version

**0.2.1**

`CreshChat.toc` declares `## Version: 0.2.1` and `Core.lua` declares `CC.BUILD.version = "0.2.1"`. The CHANGELOG heading "CreshChat v0.2.1 - Version Correction (2026-06-29)" confirms this is the intended current release. This is a patch release over v0.2 that corrects the release version numbering only; no functional changes were made.

---

## 2. Target Client and Interface Number

- **Game**: World of Warcraft: Burning Crusade Classic Anniversary Edition
- **Interface**: `20505` (declared in `.toc` and confirmed in `CC.BUILD.interface`)
- Unchanged from v0.2.

---

## 3. Git Working-Tree Status

Several files are staged but not yet committed (ArtSource texture remaster batches, release artifacts). All are correctly excluded from the release ZIP.

Recent commits on `main` are unchanged from the v0.2 audit. The v0.2.1 version changes were made as working-tree edits per project policy (no commit requested).

---

## 4. Files Examined

Same set as the v0.2 audit. All 25 Lua modules, the TOC file, and the full Media/ tree were included unchanged. Version references were checked across all source files.

---

## 5. Compliance Findings

All findings are inherited unchanged from the v0.2 audit. No new code was added in this patch.

### A. Free Distribution — PASS
### B. Visible Source Code — PASS
### C. No In-Game Advertising or Donation Requests — PASS
### D. Realm, Network, Chat, and Performance Safety — PASS
### E. Automation and Protected Actions — PASS
### F. Privacy and Data Handling — PASS
### G. Content and Copyright — PASS (advisory: no LICENSE file)

See `RELEASE_AUDIT_0.2.md` for full details of each finding.

---

## 6. Blizzard Policy Findings

No violations. Unchanged from v0.2 audit.

---

## 7. CurseForge Moderation Findings

No violations. Unchanged from v0.2 audit.

---

## 8. Network / Addon-Message Findings

Unchanged from v0.2 audit. PASS.

---

## 9. Performance Findings

Unchanged from v0.2 audit. PASS.

---

## 10. Protected-Action Findings

No protected-action calls outside click handlers. PASS.

---

## 11. Privacy Findings

No credentials, tokens, personal data, or telemetry. PASS.

---

## 12. Copyright / Attribution Findings

Same as v0.2: original source code and media assets, no third-party libraries.
Advisory: no LICENSE file present — recommended for a future release.

---

## 13. Files Changed in This Release (v0.2 → v0.2.1)

| File | Old value | New value | Notes |
|------|-----------|-----------|-------|
| [CreshChat.toc](../CreshChat.toc) | `## Version: 0.2` | `## Version: 0.2.1` | TOC metadata |
| [Core.lua](../Core.lua) | `version = "0.2"` | `version = "0.2.1"` | Runtime constant; drives `/cc version` output |
| [CHANGELOG.txt](../CHANGELOG.txt) | Headed "v0.2 - Final Compatibility…" | New v0.2.1 entry added at top; v0.2 entry preserved as history | |
| [README.txt](../README.txt) | "CreshChat v0.2 —…" | "CreshChat v0.2.1 —…" | Title line |
| [FILE_MANIFEST.txt](../FILE_MANIFEST.txt) | "CreshChat v0.2 file manifest" | "CreshChat v0.2.1 file manifest" | Dev file header |
| [QC_REPORT.txt](../QC_REPORT.txt) | "CreshChat 0.2-final-audit" | "CreshChat 0.2.1-final-audit" | Dev file header; historical entries below unchanged |
| [tools/Build-CurseForgeRelease.ps1](../tools/Build-CurseForgeRelease.ps1) | `${AddonName}-${Version}-TBC-Anniversary.zip` | `${AddonName}-v${Version}-TBC-Anniversary.zip` | Adds `v` prefix to ZIP filename; also removed unused `$QuarantineDir` variable |

---

## 14. Version References Deliberately Left Unchanged

| Location | Value | Reason |
|----------|-------|--------|
| `Core.lua:8` — `schema = 76` | 76 | SavedVariables schema; not a release version |
| `Core.lua:9` — `interface = 20505` | 20505 | WoW client Interface number; not a release version |
| `CHANGELOG.txt` — all entries below v0.2.1 | v0.2, v0.3.x, etc. | Historical release history; must not be changed |
| `QC_REPORT.txt` — all entries below the header | 0.2, 0.3.x, etc. | Historical audit records |
| `CardDecks.lua:275` — `0.2` | 0.2 | RGBA colour alpha value, not a version |
| `Settings.lua:31` — `0.2` | 0.2 | RGBA colour component, not a version |
| `UI.lua:3893` — `v0.2.5` | v0.2.5 | Historical internal design note in a comment, not the current release |
| `release/RELEASE_AUDIT_0.2.md` | 0.2 | v0.2 audit record; retained as historical reference |
| `release/CURSEFORGE_CHANGELOG_0.2.txt` | 0.2 | v0.2 release notes; retained as historical reference |
| `release/CURSEFORGE_UPLOAD_CHECKLIST_0.2.txt` | 0.2 | v0.2 checklist; retained as historical reference |
| `release/build_stats.txt` | 0.2 | Superseded stats file from previous build; replaced by new build_stats.txt |

---

## 15. Files Quarantined

Same as v0.2 audit:

| File | Reason |
|------|--------|
| `tatus` (root, git-tracked) | Accidental git diff output. Copied to `quarantine/tatus.quarantine`. Not in ZIP. |
| `textures \`` (git index ghost) | Unicode-named ghost entry, not on disk. Not in ZIP. |

---

## 16. Files Included in the ZIP

Identical to v0.2. 26 Lua/TOC files + 906 Media files = 932 source files → 958 ZIP entries.

See `RELEASE_AUDIT_0.2.md` Section 15 for the full file list.

---

## 17. Files Deliberately Excluded

Same as v0.2 audit. See `RELEASE_AUDIT_0.2.md` Section 16.

---

## 18. Tests Performed (Static)

| Test | Result |
|------|--------|
| TOC Interface value = 20505 | PASS |
| TOC Version = "0.2.1" | PASS |
| Core.lua version = "0.2.1" | PASS |
| CHANGELOG.txt has v0.2.1 entry at top | PASS |
| Historical changelog entries unchanged | PASS |
| SavedVariables schema unchanged (76) | PASS |
| No donation/payment text in Lua sources | PASS (inherited from v0.2) |
| No external URLs in Lua sources | PASS (inherited from v0.2) |
| No DLL/EXE/BAT/PS1 in release ZIP | PASS |
| No nested archives in release ZIP | PASS |
| No SavedVariables in release ZIP | PASS |
| No ArtSource/Docs/dev files in release ZIP | PASS |
| ZIP top-level folder = CreshChat/ | PASS |
| CreshChat/CreshChat.toc present in ZIP | PASS |
| No path traversal entries in ZIP | PASS |
| ZIP filename uses v prefix (v0.2.1) | PASS |
| SHA-256 hash computed | PASS |

---

## 19. Tests That Could Not Be Performed

Same as v0.2 audit. The following require the live TBC Anniversary client:

- Clean login without Lua errors
- `/reload` without errors
- All chat tab send/receive
- Whisper routing from unit frames
- Battle Pass and Dungeon Dwellers gameplay
- Achievement trigger tracking
- SavedVariables persistence
- Frame-rate and memory profile

---

## 20. Manual In-Game Test Checklist

- [ ] Login without Lua errors (`/console scriptErrors 1`)
- [ ] `/reload` without Lua errors
- [ ] `/cc version` output reads "0.2.1"
- [ ] Open CreshChat console; all tabs load
- [ ] Type in whisper, guild, party, general tabs — messages send and appear
- [ ] Receive a whisper — notification card appears
- [ ] Right-click a player frame → Whisper routes into CreshChat
- [ ] Whisper an offline character — row marked failed, no Blizzard system message
- [ ] Join a party; Party tab appears
- [ ] Accept a party invite via CreshChat card
- [ ] Open Friends tab — game friends and Battle.net friends visible
- [ ] Open Settings — all pages render
- [ ] Play one Dungeon Dwellers run to completion
- [ ] Play one Tetris game and verify background reveal
- [ ] Claim a Battle Pass reward
- [ ] Claim a Dungeon Pass reward
- [ ] Enter and exit combat — no taint errors
- [ ] Log out and back in — chat history and achievements persist

---

## 21. Remaining Warnings

1. **No LICENSE file** — advisory; not a CurseForge upload blocker.
2. **`tatus` ghost in git index** — remove at next opportunity with `git rm tatus`.
3. **`textures \`` Unicode ghost** — remove with `git rm` at next opportunity.
4. **AI-generated artwork** — if CurseForge requires disclosure, note that game textures were produced via an AI-assisted pipeline; source prompts are in `ArtSource/TextureRemaster/`.

---

## 22. Blocking Issues

**None.** The addon is compliant with Blizzard's add-on development policy and CurseForge moderation requirements based on static analysis.

---

## 23. Final ZIP Path

```
release/CreshChat-v0.2.1-TBC-Anniversary.zip
```

Full path:
```
D:\Battlenet\World of Warcraft\_anniversary_\Interface\AddOns\CreshChat\release\CreshChat-v0.2.1-TBC-Anniversary.zip
```

---

## 24. ZIP File Count and Size

| Metric | Value |
|--------|-------|
| Total entries | 958 |
| Uncompressed size | 121.23 MB |
| Compressed size | 24.22 MB |

---

## 25. SHA-256 Hash

```
82B3B459275FC4A294A428C784A6B4F6A21A73E435082529FA800EA4A4D69594
```

---

## 26. Final Recommendation

> **READY AFTER MANUAL IN-GAME TEST**

All static checks pass. Version references are consistent at v0.2.1 across all runtime and release files. Run the manual in-game test checklist (Section 20) before wider release.

---

*This is a best-effort compliance audit. It is not formal legal approval from Blizzard Entertainment or CurseForge/Overwolf.*
