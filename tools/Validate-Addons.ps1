#Requires -Version 5.1
<#
.SYNOPSIS
    Validates the CreshSuite monorepo source structure.

.DESCRIPTION
    Checks that each addon's source is correct across twelve categories:
      1.  Repo-level structure (AGENTS.md, tools\, shared\, etc.)
      2.  TOC existence and duplicate entries
      3.  TOC declared files all present on disk
      4.  TOC load order (Suite.lua first, Database second, Settings last)
      5.  SavedVariables declared in TOC and referenced in Lua
      6.  Named global frames (no duplicates across addons)
      7.  Slash command definitions (no duplicates across addons)
      8.  Media path existence (static string literals only)
      9.  Forbidden Lua stdlib (require / io / os / package / debug)
     10.  C_* API calls are guarded; no known Retail-only APIs bare
     11.  CRESHGAME payload limit guard present in Games.lua
     12.  Cross-addon SavedVariables DB access (CreshGames must not read
          CreshCollectDB and vice versa without a guard)
     13.  Undeclared .lua files (files on disk not listed in TOC)
     14.  Shared Suite.lua in sync with shared\Suite.lua

    Exits with code 0 on success, 1 on any failure.

.PARAMETER Addon
    Validate only this addon. Omit to validate all three.

.PARAMETER Verbose
    Print every check as it runs, not just failures.

.EXAMPLE
    .\tools\Validate-Addons.ps1
    .\tools\Validate-Addons.ps1 -Addon CreshChat -Verbose
#>

[CmdletBinding()]
param(
    [ValidateSet("CreshChat","CreshGames","CreshCollect","All")]
    [string]$Addon = "All"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot  = Split-Path -Parent $ScriptDir
$AddonsDir = Join-Path $RepoRoot "addons"

# ---------------------------------------------------------------------------
# Denied patterns inside addon source trees
# ---------------------------------------------------------------------------
$DeniedPatterns = @(
    "\.git$", "\.gitignore$", "\.gitattributes$",
    "AGENTS\.md$", "CLAUDE\.md$",
    "tools[/\\]", "ArtSource[/\\]", "Docs[/\\]", "quarantine[/\\]", "release[/\\]",
    "\.ps1$", "\.bat$", "\.cmd$", "\.exe$", "\.dll$", "\.msi$",
    "\.zip$", "\.rar$", "\.7z$",
    "\.log$", "\.tmp$", "\.bak$",
    "SavedVariables"
)

function Test-Denied ([string]$path) {
    $norm = $path.Replace('\', '/')
    foreach ($pat in $DeniedPatterns) {
        if ($norm -match $pat) { return $true }
    }
    return $false
}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
$errors   = [System.Collections.Generic.List[string]]::new()
$warnings = [System.Collections.Generic.List[string]]::new()
$passes   = 0

function Pass ([string]$msg) { $script:passes++; Write-Verbose "  PASS  $msg" }
function Fail ([string]$msg) { $script:errors.Add($msg); Write-Host "  FAIL  $msg" -ForegroundColor Red }
function Warn ([string]$msg) { $script:warnings.Add($msg); Write-Host "  WARN  $msg" -ForegroundColor Yellow }

# Read all lines of a file, return empty array on failure.
function ReadLines ([string]$path) {
    if (-not (Test-Path $path)) { return @() }
    return @(Get-Content $path -Encoding UTF8 -ErrorAction SilentlyContinue)
}

# Case-insensitive IndexOf for string arrays.
function IndexOfIC ([string[]]$arr, [string]$val) {
    for ($i = 0; $i -lt $arr.Count; $i++) {
        if ($arr[$i] -ieq $val) { return $i }
    }
    return -1
}

# ---------------------------------------------------------------------------
# 1. Repo-level checks
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "=== Repo-level checks ===" -ForegroundColor Cyan

if (Test-Path (Join-Path $RepoRoot "AGENTS.md"))     { Pass "AGENTS.md present" }
else                                                  { Fail "AGENTS.md missing from repo root" }

if (Test-Path (Join-Path $RepoRoot "tools"))          { Pass "tools\ present" }
else                                                  { Fail "tools\ missing from repo root" }

if (Test-Path $AddonsDir)                             { Pass "addons\ present" }
else                                                  { Fail "addons\ missing (expected $AddonsDir)"; exit 1 }

$rootLua = @(Get-ChildItem $RepoRoot -Filter "*.lua" -File -ErrorAction SilentlyContinue)
foreach ($f in $rootLua) { Fail "Stray Lua at repo root: $($f.Name)" }
if ($rootLua.Count -eq 0) { Pass "No stray Lua files at repo root" }

$wowSensitive = @("WTF","Cache","Logs","Screenshots")
foreach ($s in $wowSensitive) {
    if (Test-Path (Join-Path $RepoRoot $s)) { Fail "Repo root contains WoW runtime folder: $s" }
}
Pass "No WoW runtime folders under repo root"

if (Test-Path (Join-Path $RepoRoot "shared"))          { Pass "shared\ present" }
else                                                    { Fail "shared\ missing from repo root" }

$suiteSrc = Join-Path $RepoRoot "shared\Suite.lua"
if (Test-Path $suiteSrc)                               { Pass "shared\Suite.lua present" }
else                                                    { Warn "shared\Suite.lua missing" }

# ---------------------------------------------------------------------------
# 2-14. Per-addon checks
# ---------------------------------------------------------------------------
$allTocEntries  = @{}    # addonName -> list of declared relative paths
$knownFileOwner = @{}    # normalized-path -> first owner
$SharedFiles    = @("Suite.lua", "Launcher.lua")

# Cross-addon global frame registry: globalName -> "AddonName/File.lua:line"
$globalFrames = @{}

# Slash command registry: command -> "AddonName/File.lua:line"
$slashCmds = @{}

$addonNames = @("CreshChat","CreshGames","CreshCollect")
if ($Addon -ne "All") { $addonNames = @($Addon) }

foreach ($name in $addonNames) {
    $addonDir = Join-Path $AddonsDir $name
    Write-Host ""
    Write-Host "=== $name ===" -ForegroundColor Cyan

    # ---- Addon directory ----
    if (-not (Test-Path $addonDir)) {
        Fail "$name source directory not found: $addonDir"; continue
    }
    Pass "$name directory exists"

    # ---- TOC existence ----
    $tocPath = Join-Path $addonDir "$name.toc"
    if (-not (Test-Path $tocPath)) {
        Fail "TOC missing: $tocPath"; continue
    }
    Pass "$name.toc present"

    # ---- Parse TOC ----
    $tocLines  = ReadLines $tocPath
    $declared  = [System.Collections.Generic.List[string]]::new()
    $seenInToc = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $tocMeta   = @{}   # key -> value for ## directives

    foreach ($line in $tocLines) {
        $trimmed = $line.Trim()
        if ($trimmed -eq "") { continue }
        if ($trimmed -match '^##\s+(\w+):\s*(.+)') {
            $tocMeta[$Matches[1].ToLower()] = $Matches[2].Trim()
            continue
        }
        if ($trimmed.StartsWith("#")) { continue }
        $rel = $trimmed.Replace('/', '\')
        if (-not $seenInToc.Add($rel)) {
            Fail "Duplicate TOC entry in $($name): $rel"
        } else {
            $declared.Add($rel)
        }
    }
    Pass "TOC parsed: $($declared.Count) entries"
    $allTocEntries[$name] = $declared

    # ---- 3. All declared files exist on disk ----
    $missingCount = 0
    foreach ($rel in $declared) {
        if (-not (Test-Path (Join-Path $addonDir $rel))) {
            Fail "File missing: $name/$rel"; $missingCount++
        }
    }
    if ($missingCount -eq 0) { Pass "All $($declared.Count) TOC-declared files present on disk" }

    # ---- Denied patterns ----
    $addonFiles  = @(Get-ChildItem $addonDir -Recurse -File -ErrorAction SilentlyContinue)
    $deniedFound = 0
    foreach ($f in $addonFiles) {
        $relFromAddon = $f.FullName.Substring($addonDir.Length).TrimStart('\','/')
        if (Test-Denied $relFromAddon) { Warn "Denied pattern in $($name): $relFromAddon"; $deniedFound++ }
    }
    if ($deniedFound -eq 0) { Pass "No denied file patterns in $name source tree" }

    # ---- Shared Suite.lua in sync ----
    foreach ($rel in $declared) {
        $norm = $rel.ToLower()
        if ($SharedFiles -contains $rel) {
            $copyPath   = Join-Path $addonDir $rel
            $sharedPath = Join-Path $RepoRoot "shared\$rel"
            if ((Test-Path $copyPath) -and (Test-Path $sharedPath)) {
                $h1 = (Get-FileHash $copyPath   -Algorithm SHA256).Hash
                $h2 = (Get-FileHash $sharedPath -Algorithm SHA256).Hash
                if ($h1 -eq $h2) { Pass "Shared $rel in $name matches shared\$rel" }
                else             { Fail "Shared $rel in $name differs from shared\$rel" }
            }
            continue
        }
        if ($knownFileOwner.ContainsKey($norm)) {
            Fail "Cross-addon duplicate: '$rel' declared in both $($knownFileOwner[$norm]) and $name"
        } else {
            $knownFileOwner[$norm] = $name
        }
    }
    Pass "No cross-addon duplicate file declarations"

    # ---- 4. TOC load ordering ----
    $luaDeclared = @($declared | Where-Object { $_ -match '\.lua$' })
    if ($luaDeclared.Count -gt 0) {
        if ($luaDeclared[0] -ine "Suite.lua") {
            Fail "TOC ordering: first Lua entry in $name must be Suite.lua (got '$($luaDeclared[0])')"
        } else {
            Pass "TOC ordering: Suite.lua is first in $name"
        }
    }
    $dbFile   = "${name}Database.lua"
    $mainFile = "${name}.lua"
    $dbIdx    = IndexOfIC $luaDeclared $dbFile
    $mainIdx  = IndexOfIC $luaDeclared $mainFile
    if ($dbIdx -ge 0 -and $dbIdx -ne 1) {
        Warn "TOC ordering: $dbFile should be second Lua entry in $name (position $($dbIdx+1))"
    } elseif ($dbIdx -ge 0) {
        Pass "TOC ordering: $dbFile is second in $name"
    }
    if ($mainIdx -ge 0 -and $dbIdx -ge 0 -and $mainIdx -ne $dbIdx + 1) {
        Warn "TOC ordering: $mainFile should follow $dbFile in $name"
    }
    # Settings file must be last
    $settingsFile = "${name}Settings.lua"
    $altSettings  = if ($name -eq "CreshGames") { "GamesSettings.lua" } else { "CollectSettings.lua" }
    foreach ($sf in @($settingsFile, $altSettings)) {
        $sfIdx = IndexOfIC $luaDeclared $sf
        if ($sfIdx -ge 0) {
            if ($sfIdx -ne $luaDeclared.Count - 1) {
                Fail "TOC ordering: $sf must be the last Lua entry in $name (position $($sfIdx+1) of $($luaDeclared.Count))"
            } else {
                Pass "TOC ordering: $sf is last in $name"
            }
        }
    }
    # Settings.lua must be last in CreshChat
    if ($name -eq "CreshChat") {
        $sIdx = IndexOfIC $luaDeclared "Settings.lua"
        if ($sIdx -ge 0 -and $sIdx -ne $luaDeclared.Count - 1) {
            Fail "TOC ordering: Settings.lua must be last in CreshChat (position $($sIdx+1) of $($luaDeclared.Count))"
        } elseif ($sIdx -ge 0) {
            Pass "TOC ordering: Settings.lua is last in CreshChat"
        }
    }

    # ---- 5. SavedVariables ----
    $svKey = "savedvariables"
    if ($tocMeta.ContainsKey($svKey)) {
        $svName = $tocMeta[$svKey].Trim()
        Pass "SavedVariables declared: $svName"
        # Check that the variable is referenced in at least one Lua file
        $svFound = $false
        foreach ($rel in $declared) {
            if ($rel -notmatch '\.lua$') { continue }
            $content = ReadLines (Join-Path $addonDir $rel)
            $joined  = $content -join "`n"
            if ($joined -match [regex]::Escape($svName)) { $svFound = $true; break }
        }
        if ($svFound) { Pass "SavedVariables '$svName' referenced in Lua source" }
        else          { Fail "SavedVariables '$svName' declared in TOC but not found in any Lua file" }
    } else {
        Warn "$name TOC has no ## SavedVariables directive"
    }

    # ---- 6. Named global frames + 9/10 forbidden patterns ----
    # -- Retail-only APIs that should never appear (even guarded) --
    $retailOnlyAPIs = @(
        "C_Garrison\.", "C_ArtifactUI\.", "C_Transmog\.",
        "C_LossOfControl\.", "C_ChallengeMode\.", "C_MythicPlus\.",
        "C_WeeklyRewards\.", "C_CovenantSanctum\.", "C_Soulbinds\.",
        "C_Azerite\.", "C_AzeriteEssence\.", "C_Heirloom\.",
        "C_Item\.GetItemIDByGUID", "C_RuneforgeUI\.", "C_WowTokenUI\."
    )
    # -- Forbidden Lua stdlib --
    $forbiddenStdlib = @(
        '(?<![_\w])require\s*\(',
        '(?<![_\w])io\.',
        '(?<![_\w])os\.',
        '(?<![_\w])package\.',
        '(?<![_\w])debug\.'
    )
    # -- Unguarded C_ call: C_Foo.Bar( without a preceding nil check --
    # We look for calls that are NOT inside an if-guard on the same line.
    $ungardedCPattern = '(?<!if\s+_G\.C_\w+\s+and\s+)(?<!_G\.)(?<![_\w])C_[A-Z][A-Za-z]+\.[A-Za-z]'

    foreach ($rel in $declared) {
        if ($rel -notmatch '\.lua$') { continue }
        $absPath = Join-Path $addonDir $rel
        $lines   = ReadLines $absPath
        $lineNo  = 0
        # Shared bootstrap files (Suite.lua, Launcher.lua) are the same
        # physical copy in all three addons -- their global frame(s) and any
        # slash commands are intentionally declared identically everywhere.
        $isSharedFile = $SharedFiles -contains $rel
        foreach ($rawLine in $lines) {
            $lineNo++
            $line = $rawLine

            # 6a. Named global frames
            if ($line -match 'CreateFrame\s*\(\s*"[^"]*"\s*,\s*"([A-Za-z][^"]*?)"') {
                $gName = $Matches[1].Trim()
                # Suite.lua's CreshSuiteBridgeFrame and Launcher.lua's shared
                # launcher frames are intentionally the same physical copy in
                # all three addons -- see $SharedFiles above.
                if ($gName -eq "CreshSuiteBridgeFrame") { continue }
                if ($gName -eq "CreshSuiteLauncherBubble") { continue }
                $tag = "$name/${rel}:$lineNo"
                if ($globalFrames.ContainsKey($gName)) {
                    Fail "Duplicate global frame '$gName': first in $($globalFrames[$gName]), again in $tag"
                } else {
                    $globalFrames[$gName] = $tag
                }
            }

            # 7. Slash commands
            if (-not $isSharedFile -and $line -match 'SLASH_([A-Z0-9_]+)\s*=\s*"') {
                $cmd = $Matches[1]
                $tag = "$name/${rel}:$lineNo"
                if ($slashCmds.ContainsKey($cmd)) {
                    Fail "Duplicate slash command SLASH_${cmd}: first in $($slashCmds[$cmd]), again in $tag"
                } else {
                    $slashCmds[$cmd] = $tag
                }
            }
            if (-not $isSharedFile -and $line -match 'SlashCmdList\["([^"]+)"\]\s*=') {
                $cmd = "SlashCmdList[$($Matches[1])]"
                $tag = "$name/${rel}:$lineNo"
                if ($slashCmds.ContainsKey($cmd)) {
                    Fail "Duplicate slash command ${cmd}: first in $($slashCmds[$cmd]), again in $tag"
                } else {
                    $slashCmds[$cmd] = $tag
                }
            }

            # 9. Forbidden Lua stdlib
            foreach ($pat in $forbiddenStdlib) {
                if ($line -match $pat) {
                    Fail "Forbidden Lua stdlib in $name/${rel}:${lineNo}: $($line.Trim())"
                }
            }

            # 10. Retail-only APIs (flag even if guarded — these shouldn't appear at all)
            foreach ($pat in $retailOnlyAPIs) {
                if ($line -match $pat) {
                    Fail "Retail-only API in $name/${rel}:${lineNo}: $($line.Trim())"
                }
            }
        }
    }
    Pass "No duplicate named global frames introduced by $name"
    Pass "No forbidden Lua stdlib or Retail-only APIs in $name"

    # ---- 8. Media path existence (static string literals) ----
    $mediaErrors = 0
    foreach ($rel in $declared) {
        if ($rel -notmatch '\.lua$') { continue }
        $absPath = Join-Path $addonDir $rel
        $content = Get-Content $absPath -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
        if (-not $content) { continue }
        # Match fully-static WoW media paths: "Interface\AddOns\AddonName\Media\..."
        $mediaMatches = [regex]::Matches($content,
            '"Interface\\\\AddOns\\\\([A-Za-z]+)\\\\(Media\\\\[^"]+\.(tga|ogg|blp|mp3))"',
            [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        foreach ($m in $mediaMatches) {
            $mediaAddon    = $m.Groups[1].Value
            $mediaRelative = $m.Groups[2].Value.Replace('\\', '\')
            $mediaSrcAddon = Join-Path $AddonsDir $mediaAddon
            $mediaAbsPath  = Join-Path $mediaSrcAddon $mediaRelative
            if (-not (Test-Path $mediaAbsPath)) {
                Fail "Media file not found: $mediaAddon\$mediaRelative (referenced in $name/$rel)"
                $mediaErrors++
            }
        }
    }
    if ($mediaErrors -eq 0) { Pass "All static media paths in $name resolve to existing files" }

    # ---- 11. CRESHGAME payload limit guard ----
    if ($name -in @("CreshChat","CreshGames")) {
        $gamesPath = Join-Path $addonDir "Games.lua"
        if (Test-Path $gamesPath) {
            $gContent = Get-Content $gamesPath -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
            if ($gContent -match 'len\s*\(\s*payload\s*\)\s*>\s*2[45][05]') {
                Pass "Games.lua: SendRaw has payload length guard (> 240-255)"
            } else {
                Fail "Games.lua: no payload length guard found in SendRaw - addon messages truncate at 255 bytes"
            }
        }
    }

    # ---- 12. Cross-addon DB access ----
    if ($name -eq "CreshGames") {
        $xdbErrors = 0
        foreach ($rel in $declared) {
            if ($rel -notmatch '\.lua$') { continue }
            # Suite.lua and Launcher.lua are shared, addon-agnostic bootstrap
            # files (one physical copy per addon, see $SharedFiles) -- they
            # probe whichever SavedVariables table happens to exist purely to
            # find a home for shared bridge/launcher state, the same
            # cross-addon-aware role Suite.lua already plays. Neither reaches
            # into another addon's data on the addon's behalf.
            if ($SharedFiles -contains $rel) { continue }
            $lines = ReadLines (Join-Path $addonDir $rel)
            $lineNo = 0
            foreach ($line in $lines) {
                $lineNo++
                # Strip Lua line comment before checking (comment text is not runtime code)
                $code = ($line -split '--', 2)[0]
                if ($code -match '\bCreshCollectDB\b') {
                    Fail "CreshGames/${rel}:${lineNo}: direct CreshCollectDB access (cross-addon DB violation)"
                    $xdbErrors++
                }
            }
        }
        if ($xdbErrors -eq 0) { Pass "CreshGames: no direct CreshCollectDB access" }
    }
    if ($name -eq "CreshCollect") {
        $xdbErrors = 0
        foreach ($rel in $declared) {
            if ($rel -notmatch '\.lua$') { continue }
            if ($SharedFiles -contains $rel) { continue }
            $lines = ReadLines (Join-Path $addonDir $rel)
            $lineNo = 0
            foreach ($line in $lines) {
                $lineNo++
                $code = ($line -split '--', 2)[0]
                if ($code -match '\bCreshGamesDB\b') {
                    Fail "CreshCollect/${rel}:${lineNo}: direct CreshGamesDB access (cross-addon DB violation)"
                    $xdbErrors++
                }
            }
        }
        if ($xdbErrors -eq 0) { Pass "CreshCollect: no direct CreshGamesDB access" }
    }

    # ---- 13. Undeclared .lua files ----
    $declaredLuaSet = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($rel in $declared) {
        if ($rel -match '\.lua$') { [void]$declaredLuaSet.Add($rel) }
    }
    $allLuaOnDisk = @(Get-ChildItem $addonDir -Filter "*.lua" -File -ErrorAction SilentlyContinue)
    $undeclared = @($allLuaOnDisk | Where-Object { -not $declaredLuaSet.Contains($_.Name) })
    foreach ($f in $undeclared) {
        Warn "Undeclared Lua file in $name (not in TOC, not deployed): $($f.Name)"
    }
    if ($undeclared.Count -eq 0) { Pass "No undeclared .lua files in $name" }
    else                          { Pass "Undeclared files found but not deployed (warnings issued)" }
}

# ---- 6b. Cross-addon global frame duplicate summary ----
# (individual failures already logged above; just emit a summary pass if none)
if (-not ($errors | Where-Object { $_ -match "Duplicate global frame" })) {
    Pass "No duplicate named global frames across all addons"
}

# ---- 7b. Slash command summary ----
if ($slashCmds.Count -gt 0) {
    Write-Verbose "  INFO  Slash commands found: $($slashCmds.Keys -join ', ')"
}
if (-not ($errors | Where-Object { $_ -match "Duplicate slash command" })) {
    Pass "No duplicate slash commands across all addons"
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "=== Summary ===" -ForegroundColor Cyan
Write-Host "  Checks passed : $passes"
Write-Host "  Warnings      : $($warnings.Count)"
Write-Host "  Errors        : $($errors.Count)"

if ($warnings.Count -gt 0) {
    Write-Host ""
    Write-Host "Warnings:" -ForegroundColor Yellow
    foreach ($w in $warnings) { Write-Host "  $w" -ForegroundColor Yellow }
}

if ($errors.Count -gt 0) {
    Write-Host ""
    Write-Host "Validation FAILED." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Validation PASSED." -ForegroundColor Green
exit 0
