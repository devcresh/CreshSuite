#Requires -Version 5.1
<#
.SYNOPSIS
    Stages and packages CreshSuite addons for release.

.DESCRIPTION
    For each addon under addons/ (or a single addon specified with -Addon):
      1.  Parses the TOC to build an explicit file allowlist.
      2.  Copies those files plus the addon's own Media\ into _staging_\AddonName\.
      3.  Unless -StageOnly is set, zips the staged tree as
              release\AddonName-v<version>-TBC-Anniversary.zip

    Never includes dev files, .git, Docs, tools, ArtSource, AGENTS.md, etc.
    Runs Validate-Addons.ps1 first and aborts if validation fails.

.PARAMETER Addon
    Build only this addon. Omit for all three.

.PARAMETER StageOnly
    Copy files to _staging_\ but do not create ZIP files.

.PARAMETER SkipValidation
    Skip the Validate-Addons.ps1 pre-flight check (useful when called from
    a CI step that already validated separately).

.EXAMPLE
    .\tools\Build-Release.ps1
    .\tools\Build-Release.ps1 -Addon CreshChat
    .\tools\Build-Release.ps1 -StageOnly
#>

[CmdletBinding()]
param(
    [ValidateSet("CreshChat","CreshGames","CreshCollect","All")]
    [string]$Addon = "All",

    [switch]$StageOnly,
    [switch]$SkipValidation
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot   = Split-Path -Parent $ScriptDir
$AddonsDir  = Join-Path $RepoRoot "addons"
$StageRoot  = Join-Path $RepoRoot "_staging_"
$ReleaseDir = Join-Path $RepoRoot "release"

$AddonNames = @("CreshChat","CreshGames","CreshCollect")
if ($Addon -ne "All") { $AddonNames = @($Addon) }

# ---------------------------------------------------------------------------
# Forbidden patterns — never land in staged output or ZIP
# ---------------------------------------------------------------------------
$Denied = @(
    "\.git", "AGENTS\.md", "CLAUDE\.md",
    "tools[/\\]", "ArtSource[/\\]", "Docs[/\\]", "quarantine[/\\]",
    "_staging_[/\\]", "release[/\\]",
    "\.ps1$", "\.bat$", "\.cmd$", "\.exe$", "\.dll$", "\.msi$",
    "\.zip$", "\.rar$", "\.7z$",
    "\.log$", "\.tmp$", "\.bak$",
    "SavedVariables", "WTF", "Cache", "Logs"
)

function Test-Denied ([string]$rel) {
    $norm = $rel.Replace('\','/')
    foreach ($p in $Denied) {
        if ($norm -match $p) { return $true }
    }
    return $false
}

# ---------------------------------------------------------------------------
# Pre-flight: validate
# ---------------------------------------------------------------------------
if (-not $SkipValidation) {
    Write-Host "Running Validate-Addons.ps1..." -ForegroundColor Cyan
    $validateScript = Join-Path $ScriptDir "Validate-Addons.ps1"
    if (-not (Test-Path $validateScript)) {
        Write-Error "Validate-Addons.ps1 not found at $validateScript"
        exit 1
    }
    & $validateScript -Addon $Addon
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Validation failed — aborting build."
        exit 1
    }
    Write-Host ""
}

# ---------------------------------------------------------------------------
# Clear and recreate staging root
# ---------------------------------------------------------------------------
if (Test-Path $StageRoot) { Remove-Item $StageRoot -Recurse -Force }
New-Item -ItemType Directory -Path $StageRoot | Out-Null

if (-not (Test-Path $ReleaseDir)) {
    New-Item -ItemType Directory -Path $ReleaseDir | Out-Null
}

Write-Host "=== CreshSuite Build-Release ===" -ForegroundColor Cyan
if ($StageOnly) { Write-Host "  Mode: STAGE ONLY (no ZIP)" }
else             { Write-Host "  Mode: STAGE + ZIP" }
Write-Host ""

$results = @()

foreach ($name in $AddonNames) {
    $srcDir  = Join-Path $AddonsDir $name
    $tocPath = Join-Path $srcDir "$name.toc"
    $stageDir = Join-Path $StageRoot $name

    Write-Host "--- $name ---"

    if (-not (Test-Path $tocPath)) {
        Write-Host "  SKIP: $tocPath not found (addon not yet extracted)" -ForegroundColor Yellow
        Write-Host ""
        continue
    }

    # Read version from TOC
    $version = $null
    foreach ($line in (Get-Content $tocPath)) {
        if ($line -match '^\s*##\s*Version\s*:\s*(.+)') {
            $version = $Matches[1].Trim(); break
        }
    }
    if (-not $version) {
        Write-Error "$name.toc has no ## Version field"
        exit 1
    }

    # Build allowlist from TOC + Media\
    $allowList = [System.Collections.Generic.List[string]]::new()
    $allowList.Add("$name.toc")

    foreach ($line in (Get-Content $tocPath)) {
        $trimmed = $line.Trim()
        if ($trimmed -eq "" -or $trimmed.StartsWith("#")) { continue }
        $rel = $trimmed.Replace("/", "\")
        if (Test-Denied $rel) {
            Write-Error "TOC declares a denied file: $rel"
            exit 1
        }
        $abs = Join-Path $srcDir $rel
        if (-not (Test-Path $abs)) {
            Write-Error "TOC-declared file missing: $name\$rel"
            exit 1
        }
        $allowList.Add($rel)
    }

    $mediaDir = Join-Path $srcDir "Media"
    if (Test-Path $mediaDir) {
        foreach ($item in (Get-ChildItem $mediaDir -Recurse -File)) {
            $rel = $item.FullName.Substring($srcDir.Length).TrimStart('\')
            if (-not (Test-Denied $rel)) { $allowList.Add($rel) }
        }
    }

    # Stage files
    New-Item -ItemType Directory -Path $stageDir | Out-Null

    foreach ($rel in $allowList) {
        $src = Join-Path $srcDir $rel
        $dst = Join-Path $stageDir $rel
        $dstParent = Split-Path -Parent $dst
        if (-not (Test-Path $dstParent)) {
            New-Item -ItemType Directory -Path $dstParent -Force | Out-Null
        }
        Copy-Item $src $dst -Force
    }

    Write-Host "  Staged: $($allowList.Count) files → $stageDir"

    if ($StageOnly) {
        $results += [PSCustomObject]@{ Name = $name; Version = $version; Files = $allowList.Count; Zip = $null }
        Write-Host ""
        continue
    }

    # ZIP the staged addon folder
    $zipName = "$name-v$version-TBC-Anniversary.zip"
    $zipPath = Join-Path $ReleaseDir $zipName
    if (Test-Path $zipPath) { Remove-Item $zipPath -Force }

    Compress-Archive -Path (Join-Path $stageDir "*") -DestinationPath $zipPath -CompressionLevel Optimal

    # Validate ZIP
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [System.IO.Compression.ZipFile]::OpenRead($zipPath)
    try {
        foreach ($entry in $zip.Entries) {
            $n = $entry.FullName.Replace('\','/')
            if ($n -match '\.\.' -or $n.StartsWith('/')) {
                Write-Error "Path traversal in ZIP: $($entry.FullName)"
                exit 1
            }
            if (Test-Denied $n) {
                Write-Error "Denied file in ZIP: $($entry.FullName)"
                exit 1
            }
        }
        $entryCount = $zip.Entries.Count
    } finally { $zip.Dispose() }

    $sha = (Get-FileHash $zipPath -Algorithm SHA256).Hash
    $sizeMB = [math]::Round((Get-Item $zipPath).Length / 1MB, 2)

    Write-Host "  ZIP: $zipName ($sizeMB MB, $entryCount entries)"
    Write-Host "  SHA-256: $sha"

    $results += [PSCustomObject]@{
        Name    = $name
        Version = $version
        Files   = $allowList.Count
        Zip     = $zipPath
        SHA256  = $sha
    }
    Write-Host ""
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
Write-Host "=== Build complete ===" -ForegroundColor Green
foreach ($r in $results) {
    if ($r.Zip) { Write-Host "  $($r.Name) v$($r.Version) — $($r.Files) files — $($r.Zip)" }
    else         { Write-Host "  $($r.Name) v$($r.Version) — $($r.Files) staged files" }
}
