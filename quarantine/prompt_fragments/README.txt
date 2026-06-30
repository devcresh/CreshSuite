Quarantined accidental files — prompt fragments and captured command output
=========================================================================

Date quarantined: 2026-06-29
Quarantined by: release engineering audit (v0.2.1)

These files were found in the repository root. They are NOT addon source files.
They appear to be accidental captures of shell command output (git diff, git
status, man page text) and partial prompt sentences that were written to the
filesystem during prior AI-assisted sessions.

None of these files contain addon code, assets, or configuration. They contain
binary TGA diff output, ANSI-escape terminal text, and git status text.

Files:
  tatus              — git status/diff output (12 KB); original was staged in index
  textures_unicode_  — git diff output with Unicode filename (41 KB); was staged in index
  fragment           — file "genuinely required by the running addon, exclude:" (40 KB)
  LoadOnDemand       — git diff output captured to prompt-fragment filename (41 KB)
  and folders        — git diff output (40 KB)
  code               — man-page output for 'less' (16 KB)
  ted_by_toc         — terminal output (16 KB)
  terAddonMessagePre — terminal output (16 KB)
  ts                 — git diff output (41 KB)
  fragment_10..15    — remaining prompt-fragment files with trailing-period names

All were removed from the git index before this commit.
These files are preserved here for audit purposes only and have no runtime use.

--- v0.2.2 audit additions ---

Date quarantined: 2026-06-30
Quarantined by: release engineering audit (v0.2.2)

  commit_command_fragment.quarantine (quarantine/)
    — Original filename was a malformed Private-Use-Area Unicode string:
      "e CreshChat v0.2.1[U+F022]git commit -m [U+F022]Release CreshChat v0.2.1[U+F022]"
    — Content: captured git diff --stat output (1981 bytes); a prior session accidentally
      wrote git diff output as a file whose name was a fragment of a commit command.
    — Removed from git index with `git rm --cached`; file deleted from repo root;
      content preserved here for audit reference.

  Docs/Guides/commit
    — A file named "commit" inside Docs/Guides/ containing git workflow commands.
    — Accidental: created when shell commands were written to a file instead of run.
    — Removed from git tracking with `git rm --cached`; excluded permanently via .gitignore.

--- 2026-06-30 full-project audit additions ---

Date quarantined: 2026-06-30
Quarantined by: full-project audit (v0.2.2, post "Merge GitHub history with restored
local project" commit)

  tatus_20260630b
    — Repo-root file literally named "tatus" (488 bytes); `less` pager help-screen text.
    — Untracked (never made it into the git index this time).

  Backup_created_ForegroundColor_Green_20260630
    — Repo-root file named "t Backup created\357\200\272  -ForegroundColor Green" (16653 bytes);
      same `less` pager help-screen text as the original "code"/"ted_by_toc" fragments above.
    — Filename fragment matches a PowerShell `Write-Host "...Backup created..." -ForegroundColor Green`
      line, suggesting a backup/restore script's status output was redirected to a file
      instead of the console.
    — Untracked; both files were created at the same timestamp (12:42) as the
      "Merge GitHub history with restored local project" commit (12:40:53), so they are
      most likely a byproduct of that recovery operation, not new addon work.

  rce_PUA_arrow_20260630
    — Originally committed under the path "rce \357\201\274" in the squashed local
      commit d8830bd ("Merge GitHub history with restored local project") —
      \357\201\274 is the UTF-8 byte sequence for a Private-Use-Area "arrow" glyph
      from a Nerd Font prompt icon set, same family as the U+F022 fragment already
      quarantined in commit_command_fragment.quarantine.
    — Content: identical `less` pager help-screen text (327 lines / 16653 bytes) to
      the two untracked files above.
    — This file never existed in the real GitHub history (origin/main) — it was an
      artifact of the squash commit only. Recovered from the squashed commit and
      placed here (gitignored, like its siblings) purely for the audit trail; it is
      not part of the recovery branch's tracked tree and never will be.
    — Confirmed NOT referenced by CreshChat.toc or any .lua file.

This is a recurring environment issue (same `less`-help-text capture pattern as the
2026-06-29 batch above) — most likely a shell/pager misconfiguration in the AI-assisted
session tooling, not anything in the addon's own Lua/TOC code. Worth fixing at the
tooling level so it stops recurring, but out of scope for the addon source itself.
