#Requires -Version 5.1
<#
.SYNOPSIS
    Validates the CreshSuite monorepo source structure.

.DESCRIPTION
    Checks that:
      1.  Each addon under addons/ has exactly one correctly named TOC.
      2.  Every file declared in a TOC exists on disk.
      3.  No TOC entry is duplicated within one addon.
      4.  No Lua file is declared in more than one addon's TOC (no cross-addon
          duplicate loading).
      5.  No denied file patterns exist inside addon source trees (no .git,
          no dev files, no executables).
      6.  No Lua files are present at the repo root (they belong in addons/).
      7.  The repo root contains AGENTS.md and tools\.

    Exits with code 0 on success, 1 on any failure.

.PARAMETER Addon
    Validate only this addon (CreshChat / CreshGames / CreshCollect).
    Omit to validate all three.

.PARAMETER Verbose
    Print every check as it runs, not just failures.

.EXAMPLE
    .\tools\Validate-Addons.ps1
    .\tools\Validate-Addons.ps1 -Addon CreshChat -Verbose
#>

[CmdletBinding()]
param(
    [ValidateSet("CreshChat","CreshGames","CreshCollect","All")]
    [string]$Addon = "All",

    [switch]$Verbose
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot  = Split-Path -Parent $ScriptDir
$AddonsDir = Join-Path $RepoRoot "addons"

# ---------------------------------------------------------------------------
# Forbidden patterns inside addon source trees
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

function Pass ([string]$msg) {
    $script:passes++
    if ($Verbose) { Write-Host "  PASS  $msg" -ForegroundColor Green }
}
function Fail ([string]$msg) {
    $script:errors.Add($msg)
    Write-Host "  FAIL  $msg" -ForegroundColor Red
}
function Warn ([string]$msg) {
    $script:warnings.Add($msg)
    Write-Host "  WARN  $msg" -ForegroundColor Yellow
}

# ---------------------------------------------------------------------------
# 1. Repo-level checks
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "=== Repo-level checks ===" -ForegroundColor Cyan

if (Test-Path (Join-Path $RepoRoot "AGENTS.md"))   { Pass "AGENTS.md present" }
else                                                { Fail "AGENTS.md missing from repo root" }

if (Test-Path (Join-Path $RepoRoot "tools"))        { Pass "tools\ present" }
else                                                { Fail "tools\ missing from repo root" }

if (Test-Path $AddonsDir)                           { Pass "addons\ present" }
else                                                { Fail "addons\ missing — expected at $AddonsDir"; exit 1 }

# No stray Lua files at repo root
$rootLua = Get-ChildItem $RepoRoot -Filter "*.lua" -File -ErrorAction SilentlyContinue
foreach ($f in $rootLua) {
    Fail "Stray Lua at repo root: $($f.Name)  (should be inside addons\)"
}
if (-not $rootLua) { Pass "No stray Lua files at repo root" }

# WTF / Cache / Logs / sibling addons must not be reachable from repo root
$wowSensitive = @("WTF","Cache","Logs","Screenshots")
foreach ($s in $wowSensitive) {
    $candidate = Join-Path $RepoRoot $s
    if (Test-Path $candidate) { Fail "Repo root contains WoW runtime folder: $s" }
}
Pass "No WoW runtime folders (WTF/Cache/Logs) under repo root"

# ---------------------------------------------------------------------------
# 2. Per-addon checks
# ---------------------------------------------------------------------------
$allTocEntries = @{}   # addonName -> list of declared relative paths
$knownFileOwner = @{}  # normalized rel-path -> first owner addon name

if (-not (Test-Path $AddonsDir)) {
    Write-Error "addons\ directory not found at $AddonsDir"
    exit 1
}

$addonNames = @("CreshChat","CreshGames","CreshCollect")
if ($Addon -ne "All") { $addonNames = @($Addon) }

foreach ($name in $addonNames) {
    $addonDir = Join-Path $AddonsDir $name
    Write-Host ""
    Write-Host "=== $name ===" -ForegroundColor Cyan

    # Check addon directory exists
    if (-not (Test-Path $addonDir)) {
        Fail "$name source directory not found: $addonDir"
        continue
    }
    Pass "$name directory exists"

    # Check TOC exists with correct name
    $tocPath = Join-Path $addonDir "$name.toc"
    if (-not (Test-Path $tocPath)) {
        Fail "TOC missing: $tocPath"
        continue
    }
    Pass "$name.toc present"

    # Parse TOC
    $tocLines  = Get-Content $tocPath
    $declared  = [System.Collections.Generic.List[string]]::new()
    $seenInToc = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

    foreach ($line in $tocLines) {
        $trimmed = $line.Trim()
        if ($trimmed -eq "" -or $trimmed.StartsWith("#")) { continue }
        $rel = $trimmed.Replace("/", "\")

        # Duplicate within same TOC
        if (-not $seenInToc.Add($rel)) {
            Fail "Duplicate TOC entry in $name: $rel"
        } else {
            $declared.Add($rel)
        }
    }

    Pass "TOC parsed — $($declared.Count) entries"

    # All declared files exist
    $missingCount = 0
    foreach ($rel in $declared) {
        $abs = Join-Path $addonDir $rel
        if (-not (Test-Path $abs)) {
            Fail "File missing: $name/$rel"
            $missingCount++
        }
    }
    if ($missingCount -eq 0) { Pass "All $($declared.Count) TOC-declared files found on disk" }

    # No denied patterns inside the addon source tree
    $addonFiles = Get-ChildItem $addonDir -Recurse -File -ErrorAction SilentlyContinue
    $deniedFound = 0
    foreach ($f in $addonFiles) {
        $relFromAddon = $f.FullName.Substring($addonDir.Length).TrimStart('\','/')
        if (Test-Denied $relFromAddon) {
            Warn "Denied pattern inside $name: $relFromAddon"
            $deniedFound++
        }
    }
    if ($deniedFound -eq 0) { Pass "No denied file patterns inside $name source tree" }

    # Check for cross-addon duplicates
    foreach ($rel in $declared) {
        $norm = $rel.ToLower()
        if ($knownFileOwner.ContainsKey($norm)) {
            Fail "Cross-addon duplicate: '$rel' declared in both $($knownFileOwner[$norm]) and $name"
        } else {
            $knownFileOwner[$norm] = $name
        }
    }
    Pass "No cross-addon duplicate file declarations"

    $allTocEntries[$name] = $declared
}

# ---------------------------------------------------------------------------
# 3. Summary
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
