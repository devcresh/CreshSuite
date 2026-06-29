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
