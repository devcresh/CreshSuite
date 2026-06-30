#Requires -Version 5.1
<#
.SYNOPSIS
    Builds a CurseForge-ready ZIP for CreshChat (TBC Anniversary).

.DESCRIPTION
    Reads the version from CreshChat.toc, assembles only the runtime-required
    files into a clean staging directory, zips them as:
        release/CreshChat-<version>-TBC-Anniversary.zip
    and validates the archive contents.

.NOTES
    Run from any directory; the script locates the repo root from its own path.
    Requires PowerShell 5.1+ and the built-in Compress-Archive cmdlet.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ---------------------------------------------------------------------------
# 1. Paths
# ---------------------------------------------------------------------------
$ScriptDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot    = Split-Path -Parent $ScriptDir
$TocFile     = Join-Path $RepoRoot "CreshChat.toc"
$ReleaseDir  = Join-Path $RepoRoot "release"
$StageDir    = Join-Path $RepoRoot "_staging_"
$AddonName   = "CreshChat"

# ---------------------------------------------------------------------------
# 2. Read version from .toc
# ---------------------------------------------------------------------------
if (-not (Test-Path $TocFile)) {
    Write-Error "CreshChat.toc not found at: $TocFile"
    exit 1
}

$Version = $null
foreach ($line in (Get-Content $TocFile)) {
    if ($line -match '^\s*##\s*Version\s*:\s*(.+)') {
        $Version = $Matches[1].Trim()
        break
    }
}

if (-not $Version) {
    Write-Error "Could not read ## Version from CreshChat.toc"
    exit 1
}

$ZipName = "${AddonName}-v${Version}-TBC-Anniversary.zip"
$ZipPath = Join-Path $ReleaseDir $ZipName

Write-Host ""
Write-Host "=== CreshChat CurseForge Release Builder ===" -ForegroundColor Cyan
Write-Host "  Version  : $Version"
Write-Host "  Repo     : $RepoRoot"
Write-Host "  Output   : $ZipPath"
Write-Host ""

# ---------------------------------------------------------------------------
# 3. Runtime file allowlist
#    All paths are relative to $RepoRoot.
#    We include:
#      - CreshChat.toc
#      - All Lua files listed in the .toc
#      - The full Media/ tree (textures, sounds, voice icon)
#    We exclude everything else (ArtSource, Docs, tools, dev files, etc.)
# ---------------------------------------------------------------------------

# Parse toc for listed Lua files
$TocEntries = [System.Collections.Generic.List[string]]::new()
$TocEntries.Add("CreshChat.toc")

foreach ($line in (Get-Content $TocFile)) {
    $trimmed = $line.Trim()
    # Skip blank lines and ## directives
    if ($trimmed -eq "" -or $trimmed.StartsWith("#")) { continue }
    # Normalise path separators
    $normalised = $trimmed.Replace("\", "/")
    $TocEntries.Add($normalised)
}

Write-Host "TOC-declared files ($($TocEntries.Count)):"
foreach ($e in $TocEntries) { Write-Host "  $e" }
Write-Host ""

# ---------------------------------------------------------------------------
# 4. Forbidden file patterns — refuse to package these
# ---------------------------------------------------------------------------
$ForbiddenPatterns = @(
    '\.git$', '\.gitignore$', '\.gitattributes$', '\.vscode', '\.idea',
    '\.tmp$', '\.bak$', '\.old$', '\.log$',
    'thumbs\.db$', 'desktop\.ini$', '\.ds_store$',
    '^tatus$', 'textures `',         # malformed filenames
    '\.zip$', '\.rar$', '\.7z$',    # nested archives
    '\.exe$', '\.dll$', '\.bat$', '\.cmd$', '\.msi$', '\.ps1$',
    'CLAUDE\.md$', 'AGENTS\.md$', 'QC_REPORT\.txt$',
    'FILE_MANIFEST\.txt$', 'README\.txt$', 'CHANGELOG\.txt$',
    '^ArtSource[/\\]', '^Docs[/\\]', '^quarantine[/\\]', '^tools[/\\]',
    '^release[/\\]', '^_staging_[/\\]',
    'SavedVariables', '\.lua\.old$'
)

function Test-Forbidden {
    param([string]$RelPath)
    foreach ($pat in $ForbiddenPatterns) {
        if ($RelPath -match $pat) { return $true }
    }
    return $false
}

# ---------------------------------------------------------------------------
# 5. Build the full set of files to include
# ---------------------------------------------------------------------------
$FilesToInclude = [System.Collections.Generic.List[string]]::new()

# TOC-declared files
foreach ($rel in $TocEntries) {
    $abs = Join-Path $RepoRoot $rel
    if (-not (Test-Path $abs)) {
        Write-Error "TOC-declared file missing: $rel"
        exit 1
    }
    if (Test-Forbidden $rel) {
        Write-Error "TOC-declared file matches forbidden pattern: $rel"
        exit 1
    }
    $FilesToInclude.Add($rel)
}

# Media/ folder — include everything inside it recursively
$MediaDir = Join-Path $RepoRoot "Media"
if (Test-Path $MediaDir) {
    $mediaItems = Get-ChildItem -Path $MediaDir -Recurse -File
    foreach ($item in $mediaItems) {
        $rel = $item.FullName.Substring($RepoRoot.Length).TrimStart('\', '/')
        $rel = $rel.Replace('\', '/')
        if (Test-Forbidden $rel) {
            Write-Warning "Skipping forbidden Media file: $rel"
            continue
        }
        $FilesToInclude.Add($rel)
    }
    Write-Host "Media files included: $($mediaItems.Count)"
} else {
    Write-Warning "No Media/ directory found."
}

Write-Host "Total files to package: $($FilesToInclude.Count)"
Write-Host ""

# ---------------------------------------------------------------------------
# 6. Rebuild staging directory
# ---------------------------------------------------------------------------
if (Test-Path $StageDir) { Remove-Item -Recurse -Force $StageDir }
New-Item -ItemType Directory -Path $StageDir | Out-Null

$AddonStageDir = Join-Path $StageDir $AddonName
New-Item -ItemType Directory -Path $AddonStageDir | Out-Null

foreach ($rel in $FilesToInclude) {
    $src = Join-Path $RepoRoot $rel
    $dst = Join-Path $AddonStageDir $rel
    $dstDir = Split-Path -Parent $dst
    if (-not (Test-Path $dstDir)) {
        New-Item -ItemType Directory -Path $dstDir -Force | Out-Null
    }
    Copy-Item -Path $src -Destination $dst -Force
}

Write-Host "Staging complete: $AddonStageDir"
Write-Host ""

# ---------------------------------------------------------------------------
# 7. Safety checks before zipping
# ---------------------------------------------------------------------------

# Confirm CreshChat/CreshChat.toc is in staging
$TocInStage = Join-Path $AddonStageDir "CreshChat.toc"
if (-not (Test-Path $TocInStage)) {
    Write-Error "CreshChat.toc is missing from staging directory!"
    exit 1
}

# Confirm no absolute paths or traversal entries made it in
$stageFiles = Get-ChildItem -Path $AddonStageDir -Recurse -File
foreach ($f in $stageFiles) {
    $name = $f.Name
    if ($name -match '\.\.' -or $name.StartsWith('/') -or $name.StartsWith('\')) {
        Write-Error "Path traversal entry detected: $($f.FullName)"
        exit 1
    }
    if ($f.Length -eq 0) {
        # Warn but allow — some valid TGA headers could theoretically be 0 bytes
        # Runtime zero-byte Lua files are flagged
        if ($f.Extension -eq ".lua") {
            Write-Error "Zero-byte Lua file detected: $($f.FullName)"
            exit 1
        }
        Write-Warning "Zero-byte file: $($f.FullName)"
    }
}

# ---------------------------------------------------------------------------
# 8. Create release directory and ZIP
# ---------------------------------------------------------------------------
if (-not (Test-Path $ReleaseDir)) {
    New-Item -ItemType Directory -Path $ReleaseDir | Out-Null
}

if (Test-Path $ZipPath) { Remove-Item -Force $ZipPath }

Compress-Archive -Path (Join-Path $StageDir "*") -DestinationPath $ZipPath -CompressionLevel Optimal
Write-Host "ZIP created: $ZipPath"

# ---------------------------------------------------------------------------
# 9. Validate the ZIP
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "=== Validating ZIP ===" -ForegroundColor Cyan

Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)
try {
    $entries = $zip.Entries

    # Top-level entries must all start with CreshChat/
    $topLevelFolders = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($entry in $entries) {
        # Normalize both / and \ separators
        $normalised = $entry.FullName.Replace('\', '/')
        $firstSegment = $normalised.Split('/')[0]
        if ($firstSegment -ne "") { $topLevelFolders.Add($firstSegment) | Out-Null }
    }
    if ($topLevelFolders.Count -ne 1 -or -not $topLevelFolders.Contains($AddonName)) {
        Write-Error "ZIP top-level folder is wrong. Found: $($topLevelFolders -join ', ')"
        exit 1
    }
    Write-Host "  Top-level folder: $AddonName  OK"

    # CreshChat/CreshChat.toc must exist
    $hasToc = $entries | Where-Object { $_.FullName.Replace('\','/') -eq "CreshChat/CreshChat.toc" }
    if (-not $hasToc) {
        Write-Error "CreshChat/CreshChat.toc not found inside ZIP"
        exit 1
    }
    Write-Host "  CreshChat/CreshChat.toc exists  OK"

    # No path traversal, no absolute paths
    foreach ($entry in $entries) {
        $n = $entry.FullName.Replace('\','/')
        if ($n -match '\.\.' -or $n.StartsWith('/')) {
            Write-Error "Path traversal or absolute path in ZIP: $($entry.FullName)"
            exit 1
        }
    }
    Write-Host "  No path traversal entries  OK"

    # No executables
    $badExts = @('.exe', '.dll', '.bat', '.cmd', '.msi', '.ps1')
    foreach ($entry in $entries) {
        $ext = [System.IO.Path]::GetExtension($entry.Name).ToLower()
        if ($ext -in $badExts) {
            Write-Error "Executable found in ZIP: $($entry.FullName)"
            exit 1
        }
    }
    Write-Host "  No executables  OK"

    # No nested archives
    $archiveExts = @('.zip', '.rar', '.7z')
    foreach ($entry in $entries) {
        $ext = [System.IO.Path]::GetExtension($entry.Name).ToLower()
        if ($ext -in $archiveExts) {
            Write-Error "Nested archive found in ZIP: $($entry.FullName)"
            exit 1
        }
    }
    Write-Host "  No nested archives  OK"

    # No SavedVariables
    foreach ($entry in $entries) {
        $n = $entry.FullName.Replace('\','/')
        if ($n -match 'SavedVariables|WTF') {
            Write-Error "SavedVariables/WTF data found in ZIP: $($entry.FullName)"
            exit 1
        }
    }
    Write-Host "  No SavedVariables  OK"

    # No dev/repo files
    $devPatterns = @('ArtSource', 'Docs/', 'tools/', 'quarantine/', '.git', 'CLAUDE.md',
                     'AGENTS.md', 'QC_REPORT', 'FILE_MANIFEST', '_staging_')
    foreach ($entry in $entries) {
        $n = $entry.FullName.Replace('\','/')
        foreach ($pat in $devPatterns) {
            if ($n -match [regex]::Escape($pat)) {
                Write-Error "Development file found in ZIP: $($entry.FullName)"
                exit 1
            }
        }
    }
    Write-Host "  No development files  OK"

    $entryCount = $entries.Count
    $uncompressedSize = ($entries | Measure-Object -Property Length -Sum).Sum
} finally {
    $zip.Dispose()
}

# ---------------------------------------------------------------------------
# 10. Statistics and hash
# ---------------------------------------------------------------------------
$zipInfo = Get-Item $ZipPath
$compressedSize = $zipInfo.Length
$hash = (Get-FileHash -Path $ZipPath -Algorithm SHA256).Hash

Write-Host ""
Write-Host "=== Release Summary ===" -ForegroundColor Green
Write-Host "  ZIP path          : $ZipPath"
Write-Host "  File count        : $entryCount"
Write-Host "  Uncompressed size : $([math]::Round($uncompressedSize / 1MB, 2)) MB"
Write-Host "  Compressed size   : $([math]::Round($compressedSize / 1MB, 2)) MB"
Write-Host "  SHA-256           : $hash"
Write-Host ""

# ---------------------------------------------------------------------------
# 11. Clean staging directory
# ---------------------------------------------------------------------------
Remove-Item -Recurse -Force $StageDir
Write-Host "Staging directory cleaned."
Write-Host ""
Write-Host "BUILD SUCCESSFUL. Upload: $ZipName" -ForegroundColor Green

# Write stats to a file for audit report use
$statsPath = Join-Path $ReleaseDir "build_stats.txt"
@"
ZIP=$ZipPath
VERSION=$Version
FILE_COUNT=$entryCount
UNCOMPRESSED_BYTES=$uncompressedSize
COMPRESSED_BYTES=$compressedSize
SHA256=$hash
"@ | Set-Content -Path $statsPath -Encoding UTF8
