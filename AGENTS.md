# CreshChat Development Instructions

## Project

CreshChat is a World of Warcraft: The Burning Crusade Anniversary addon.

Live development folder:

D:\Battlenet\World of Warcraft\_anniversary_\Interface\AddOns\CreshChat

Edits made in this repository affect the locally installed addon.

## Scope

- Work only inside this CreshChat repository.
- Do not inspect or modify sibling addon folders.
- Do not inspect or modify WoW's WTF, Cache, Logs, Screenshots or executable folders.
- Do not delete or overwrite existing work without reviewing it.
- Do not push Git commits unless explicitly requested.
- Do not use force-push, hard reset or destructive cleanup commands.

## WoW requirements

- Target WoW TBC Anniversary, not Retail WoW.
- Verify that APIs exist in the TBC Anniversary client.
- Preserve the existing TOC load order.
- Preserve SavedVariables and provide migrations when structures change.
- Avoid protected-action and combat-lockdown violations.
- Do not automate protected player actions.
- Do not add external networking, executables or background services.
- Keep runtime Lua compatible with the WoW client.
- Avoid unsupported libraries such as io, os, package and require.
- Avoid expensive OnUpdate handlers.
- Keep variables local unless a global is required.

## Before editing

1. Run git status.
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
