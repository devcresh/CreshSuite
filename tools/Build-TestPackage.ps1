#Requires -Version 5.1
<#
.SYNOPSIS
    Builds a single combined test ZIP for all three CreshSuite addons.

.DESCRIPTION
    1. Runs Validate-Addons.ps1 (abort on failure).
    2. Re-uses Build-Release.ps1 -StageOnly to build the exact same allowlist
       and staged file tree that a release build would produce.
    3. Zips all three staged folders into one combined archive:
           release\CreshSuite-TESTBUILD-<date>.zip

    Drop the ZIP contents directly into WoW\Interface\AddOns\ to install.
    Use the WoW AddOn manager to enable/disable individual addons as needed.

.EXAMPLE
    .\tools\Build-TestPackage.ps1
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot   = Split-Path -Parent $ScriptDir
$StageRoot  = Join-Path $RepoRoot "_staging_"
$ReleaseDir = Join-Path $RepoRoot "release"

# ---------------------------------------------------------------------------
# 1. Validate
# ---------------------------------------------------------------------------
Write-Host "=== Build-TestPackage ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Step 1: Validate..." -ForegroundColor Cyan
& (Join-Path $ScriptDir "Validate-Addons.ps1")
if ($LASTEXITCODE -ne 0) {
    Write-Error "Validation failed - aborting test build."
    exit 1
}
Write-Host ""

# ---------------------------------------------------------------------------
# 2. Stage (TOC-exact allowlist, same as release build)
# ---------------------------------------------------------------------------
Write-Host "Step 2: Stage files..." -ForegroundColor Cyan
& (Join-Path $ScriptDir "Build-Release.ps1") -StageOnly -SkipValidation
if ($LASTEXITCODE -ne 0) {
    Write-Error "Staging failed - aborting test build."
    exit 1
}
Write-Host ""

# ---------------------------------------------------------------------------
# 3. Combine staged folders into one ZIP
# ---------------------------------------------------------------------------
if (-not (Test-Path $ReleaseDir)) {
    New-Item -ItemType Directory -Path $ReleaseDir | Out-Null
}

$datestamp = (Get-Date -Format "yyyyMMdd-HHmm")
$zipName   = "CreshSuite-TESTBUILD-$datestamp.zip"
$zipPath   = Join-Path $ReleaseDir $zipName

Write-Host "Step 3: Creating combined ZIP..." -ForegroundColor Cyan
Write-Host "  -> $zipPath"

if (Test-Path $zipPath) { Remove-Item $zipPath -Force }

# Compress each staged addon folder as a subfolder inside the ZIP
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$zip = [System.IO.Compression.ZipFile]::Open($zipPath, [System.IO.Compression.ZipArchiveMode]::Create)
try {
    $addonNames = @("CreshChat","CreshGames","CreshCollect")
    $totalFiles = 0

    foreach ($name in $addonNames) {
        $stageDir = Join-Path $StageRoot $name
        if (-not (Test-Path $stageDir)) {
            Write-Warning "Staged folder not found: $stageDir  (addon may not have been built)"
            continue
        }

        $files = @(Get-ChildItem $stageDir -Recurse -File)
        foreach ($f in $files) {
            $rel = $f.FullName.Substring($stageDir.Length).TrimStart('\','/')
            $entryName = "$name/$rel".Replace('\','/')
            [void][System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
                $zip, $f.FullName, $entryName,
                [System.IO.Compression.CompressionLevel]::Optimal
            )
            $totalFiles++
        }
        Write-Host "  Added $($files.Count) files from $name"
    }
} finally {
    $zip.Dispose()
}

$sha    = (Get-FileHash $zipPath -Algorithm SHA256).Hash
$sizeMB = [math]::Round((Get-Item $zipPath).Length / 1MB, 2)

Write-Host ""
Write-Host "=== Test package ready ===" -ForegroundColor Green
Write-Host "  File    : $zipPath"
Write-Host "  Size    : $sizeMB MB ($totalFiles files)"
Write-Host "  SHA-256 : $sha"
Write-Host ""
Write-Host "Install instructions:"
Write-Host "  1. Extract the ZIP."
Write-Host "  2. Copy CreshChat\, CreshGames\, CreshCollect\ into:"
Write-Host "     WoW\_anniversary_\Interface\AddOns\"
Write-Host "  3. Log in and use the AddOn manager to enable/disable"
Write-Host "     individual addons for each test combination."
