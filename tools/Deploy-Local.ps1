#Requires -Version 5.1
<#
.SYNOPSIS
    Deploys CreshSuite addon source trees to the local WoW AddOns directory.

.DESCRIPTION
    Copies TOC-declared files (plus each addon's Media\ folder) from the repo
    source tree into the three live WoW AddOn destinations.  Never deploys dev
    files (.git, tools, ArtSource, Docs, AGENTS.md, etc.).

    Safety rules enforced:
      1.  Aborts if Wow.exe or Wow_classic_era.exe is running.
      2.  Verifies every TOC-declared file exists in source before writing.
      3.  Allowlist-only copy: only TOC files + Media\ are deployed.
      4.  Never deploys dev file patterns (see $DeniedFragments below).
      5.  Never deletes destination files not in the source allowlist.
      6.  Never touches SavedVariables directories.
      7.  Supports -WhatIf (dry run) and -Addon (per-addon targeting).
      8.  Verifies destination file count after deployment.
      9.  Writes a timestamped log to %TEMP%.
     10.  Locates repo root from script path (works from any working directory).

.PARAMETER Addon
    Which addon to deploy: CreshChat, CreshGames, CreshCollect, or All (default).

.PARAMETER WhatIf
    List every intended file copy without writing anything to disk.

.EXAMPLE
    .\tools\Deploy-Local.ps1
    .\tools\Deploy-Local.ps1 -Addon CreshChat
    .\tools\Deploy-Local.ps1 -WhatIf
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [ValidateSet("CreshChat", "CreshGames", "CreshCollect", "All")]
    [string]$Addon = "All",

    [switch]$WhatIf
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot   = Split-Path -Parent $ScriptDir
$WoWAddOns  = "D:\Battlenet\World of Warcraft\_anniversary_\Interface\AddOns"

$AddonDefs = @(
    [ordered]@{ Name = "CreshChat";    Src = Join-Path $RepoRoot "CreshChat"    }
    [ordered]@{ Name = "CreshGames";   Src = Join-Path $RepoRoot "CreshGames"   }
    [ordered]@{ Name = "CreshCollect"; Src = Join-Path $RepoRoot "CreshCollect" }
)

if ($Addon -ne "All") {
    $AddonDefs = $AddonDefs | Where-Object { $_.Name -eq $Addon }
}

# ---------------------------------------------------------------------------
# Denied file patterns — never land in a live destination
# ---------------------------------------------------------------------------
$DeniedFragments = @(
    ".git", "tools\", "ArtSource\", "Docs\", "quarantine\", "release\",
    "_staging_", "AGENTS.md", "CLAUDE.md",
    ".ps1", ".bat", ".cmd", ".exe", ".dll", ".msi",
    ".zip", ".rar", ".7z",
    ".bak", ".log", ".tmp", ".old",
    "SavedVariables"
)

function Test-Denied {
    param([string]$RelPath)
    $norm = $RelPath.Replace('\','/')
    foreach ($frag in $DeniedFragments) {
        if ($norm -match [regex]::Escape($frag.Replace('\','/'))) { return $true }
    }
    return $false
}

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
$Timestamp  = (Get-Date).ToString("yyyyMMdd-HHmmss")
$LogPath    = "$env:TEMP\CreshSuite-Deploy-$Timestamp.log"
$LogLines   = [System.Collections.Generic.List[string]]::new()

function Write-Log {
    param([string]$msg)
    $LogLines.Add($msg)
    Write-Host $msg
}

# ---------------------------------------------------------------------------
# Rule 1: abort if WoW is running
# ---------------------------------------------------------------------------
$running = Get-Process "Wow","Wow_classic_era" -ErrorAction SilentlyContinue
if ($running) {
    Write-Error "WoW is running ($($running.Name -join ', ')). Close it before deploying."
    exit 1
}

Write-Log ""
Write-Log "=== CreshSuite Deploy-Local ==="
Write-Log "  Repo   : $RepoRoot"
Write-Log "  Target : $WoWAddOns"
Write-Log "  Addons : $(($AddonDefs | ForEach-Object { $_.Name }) -join ', ')"
if ($WhatIf) { Write-Log "  Mode   : DRY RUN (no writes)" }
else          { Write-Log "  Mode   : LIVE" }
Write-Log ""

$totalCopied = 0

foreach ($def in $AddonDefs) {
    $addonName = $def.Name
    $srcDir    = $def.Src
    $dstDir    = Join-Path $WoWAddOns $addonName
    $tocPath   = Join-Path $srcDir "$addonName.toc"

    Write-Log "--- $addonName ---"

    # Rule 2: verify TOC exists
    if (-not (Test-Path $tocPath)) {
        Write-Log "  SKIP: $tocPath not found (addon not yet extracted)"
        Write-Log ""
        continue
    }

    # Parse TOC for declared files
    $allowList = [System.Collections.Generic.List[string]]::new()
    $allowList.Add("$addonName.toc")

    foreach ($line in (Get-Content $tocPath)) {
        $trimmed = $line.Trim()
        if ($trimmed -eq "" -or $trimmed.StartsWith("#")) { continue }
        $normalised = $trimmed.Replace("/", "\")
        $allowList.Add($normalised)
    }

    # Add Media\ tree if present
    $mediaDir = Join-Path $srcDir "Media"
    if (Test-Path $mediaDir) {
        $mediaItems = Get-ChildItem -Path $mediaDir -Recurse -File
        foreach ($item in $mediaItems) {
            $rel = $item.FullName.Substring($srcDir.Length).TrimStart('\')
            $allowList.Add($rel)
        }
    }

    # Rule 3+4: verify all TOC-declared files exist and are not denied
    $valid = $true
    foreach ($rel in $allowList) {
        if (Test-Denied $rel) {
            Write-Log "  ERROR: denied pattern in allowlist: $rel"
            $valid = $false
            continue
        }
        $abs = Join-Path $srcDir $rel
        if (-not (Test-Path $abs)) {
            Write-Log "  ERROR: declared file missing: $rel"
            $valid = $false
        }
    }
    if (-not $valid) {
        Write-Error "$addonName has missing or denied files; aborting."
        exit 1
    }

    # Create destination if needed
    if (-not (Test-Path $dstDir)) {
        if (-not $WhatIf) {
            New-Item -ItemType Directory -Path $dstDir -Force | Out-Null
            Write-Log "  Created: $dstDir"
        } else {
            Write-Log "  [WhatIf] Would create: $dstDir"
        }
    }

    # Copy files
    $copied = 0
    foreach ($rel in $allowList) {
        $src = Join-Path $srcDir $rel
        $dst = Join-Path $dstDir $rel

        # Rule 6: never touch SavedVariables
        if ($dst -match "SavedVariables") {
            Write-Log "  SKIP (SavedVariables): $rel"
            continue
        }

        $dstParent = Split-Path -Parent $dst
        if (-not $WhatIf) {
            if (-not (Test-Path $dstParent)) {
                New-Item -ItemType Directory -Path $dstParent -Force | Out-Null
            }
            # Atomic write: copy to .tmp then rename
            $tmp = "$dst.tmp"
            Copy-Item -Path $src -Destination $tmp -Force
            if (Test-Path $dst) { Remove-Item $dst -Force }
            Rename-Item -Path $tmp -NewName (Split-Path -Leaf $dst)
        } else {
            Write-Log "  [WhatIf] $rel"
        }
        $copied++
    }

    $totalCopied += $copied

    if (-not $WhatIf) {
        # Rule 8: verify destination count matches allowlist
        $dstCount = (Get-ChildItem -Path $dstDir -File -Recurse |
            Where-Object { $_.FullName -notmatch "SavedVariables" }).Count
        $srcCount  = $allowList.Count
        $threshold = [math]::Ceiling($srcCount * 0.05)
        if ([math]::Abs($dstCount - $srcCount) -gt $threshold) {
            Write-Log "  WARNING: deployed $dstCount files but expected ~$srcCount"
        } else {
            Write-Log "  OK: $copied files deployed to $dstDir"
        }
    } else {
        Write-Log "  [WhatIf] $copied files would be deployed to $dstDir"
    }
    Write-Log ""
}

# ---------------------------------------------------------------------------
# Summary and log
# ---------------------------------------------------------------------------
Write-Log "=== Done ==="
if (-not $WhatIf) {
    Write-Log "  Total files deployed: $totalCopied"
} else {
    Write-Log "  Total files that would be deployed: $totalCopied"
}
Write-Log ""

$LogLines | Set-Content -Path $LogPath -Encoding UTF8
Write-Log "Log written to: $LogPath"
