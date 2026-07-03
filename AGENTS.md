# CreshSuite Development Instructions

## Project

CreshSuite is a World of Warcraft: The Burning Crusade Anniversary addon suite
comprising three independent addons: CreshChat, CreshGames, and CreshCollect.

Git repository (source of truth):

    D:\CreshSuite\

Live deployment folder (read by WoW):

    D:\Battlenet\World of Warcraft\_anniversary_\Interface\AddOns\

Edits are made in the repository and deployed to WoW with Deploy-Local.ps1.
Do NOT edit files inside the live AddOns directories directly.

## Addon source directories

All three addon source trees live as siblings under the repo root:

    CreshChat\     — chat windows, UI, notifications, friends, voice, settings
    CreshGames\    — multiplayer/solo games, Battle Pass, dungeon games, audio
    CreshCollect\  — achievements, collection tracking, progression statistics

Development files that are NOT deployed (stay at repo root only):

    ArtSource\  Docs\  tools\  quarantine\  release\
    AGENTS.md  CLAUDE.md  .gitignore  .gitattributes

## Live deployment

To push source changes to WoW, close WoW first, then run:

    cd D:\CreshSuite
    .\tools\Deploy-Local.ps1             # deploys all three addons
    .\tools\Deploy-Local.ps1 -Addon CreshChat   # one addon only
    .\tools\Deploy-Local.ps1 -WhatIf     # dry run, no writes

Live addon destinations:

    CreshChat     D:\Battlenet\World of Warcraft\_anniversary_\Interface\AddOns\CreshChat\
    CreshGames    D:\Battlenet\World of Warcraft\_anniversary_\Interface\AddOns\CreshGames\
    CreshCollect  D:\Battlenet\World of Warcraft\_anniversary_\Interface\AddOns\CreshCollect\

## Scope

- Work only inside the D:\CreshSuite\ repository.
- Never edit files inside the live WoW AddOns directories. Always edit source
  in D:\CreshSuite\ and deploy with Deploy-Local.ps1.
- Do not inspect or modify sibling addon folders that are not part of CreshSuite.
- Do not inspect or modify WoW's WTF, Cache, Logs, Screenshots or executable folders.
- Do not delete or overwrite existing work without reviewing it.
- Do not push Git commits unless explicitly requested.
- Do not use force-push, hard reset or destructive cleanup commands.

## Addon independence

- CreshChat, CreshGames and CreshCollect must each load if the other two are
  absent, disabled, or not yet installed.
- Cross-addon calls must use the CreshChatAPI / CreshGamesAPI / CreshCollectAPI
  optional-chaining pattern. No direct table access across addon boundaries.
- Each addon's TOC must declare only its own files.
- Do not add hard Dependencies: or LoadWith: TOC directives between the three
  suite addons. All inter-addon wiring must be optional.
- Do not change the CreshGames multiplayer protocol without explicit approval.

## WoW requirements

- Target WoW TBC Anniversary (Interface 20505), not Retail WoW.
- Verify that APIs exist in the TBC Anniversary client before using them.
- Preserve the existing TOC load order within each addon.
- Preserve SavedVariables and provide migrations when structures change.
- Avoid protected-action and combat-lockdown violations.
- Do not automate protected player actions.
- Do not add external networking, executables or background services.
- Keep runtime Lua compatible with the WoW client (Lua 5.1).
- Avoid unsupported libraries such as io, os, package and require.
- Avoid expensive OnUpdate handlers.
- Keep variables local unless a global is required.

## Before editing

1. Run git status from D:\CreshSuite\.
2. Inspect the relevant TOC, Lua and XML files.
3. Identify the cause of the problem.
4. Present a focused plan.
5. Preserve unrelated features.

## After editing

1. Review git diff.
2. Check edited Lua files for syntax problems.
3. Verify TOC file names and load order.
4. Check for nil access, duplicate frames and duplicate events.
5. List every changed file.
6. Provide exact in-game testing instructions.
7. Do not claim that a change works until it has been tested in WoW.
