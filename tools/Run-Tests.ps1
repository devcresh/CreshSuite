#Requires -Version 5.1
<#
.SYNOPSIS
    Runs the CreshSuite Lua unit tests.

.DESCRIPTION
    Locates a Lua 5.1-compatible interpreter (lua, lua51, lua54) on PATH,
    then executes all test files in tests\ against the relevant source files.
    Exits with code 0 on success, 1 on any test failure, 2 if Lua is absent.

.EXAMPLE
    .\tools\Run-Tests.ps1
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot  = Split-Path -Parent $ScriptDir

# ---------------------------------------------------------------------------
# Test suites: each entry is @{ Label; Args = @(lua args...) }
# ---------------------------------------------------------------------------
$Suites = @(
    @{
        Label = "CreshSuite Bridge Tests"
        Args  = @(
            (Join-Path $RepoRoot "tests\SuiteBridgeTests.lua"),
            (Join-Path $RepoRoot "shared\Suite.lua")
        )
    },
    @{
        Label = "Database Migration Tests"
        Args  = @(
            (Join-Path $RepoRoot "tests\DatabaseMigrationTests.lua"),
            (Join-Path $RepoRoot "addons\CreshGames\CreshGamesDatabase.lua"),
            (Join-Path $RepoRoot "addons\CreshCollect\CreshCollectDatabase.lua")
        )
    },
    @{
        Label = "Settings Shell Tests"
        Args  = @(
            (Join-Path $RepoRoot "tests\SettingsShellTests.lua"),
            (Join-Path $RepoRoot "addons\CreshChat\VersionCompare.lua")
        )
    },
    @{
        Label = "Slash Command Tests"
        Args  = @(
            (Join-Path $RepoRoot "tests\SlashCommandTests.lua"),
            (Join-Path $RepoRoot "addons\CreshChat\Core.lua"),
            (Join-Path $RepoRoot "addons\CreshChat\Developer.lua")
        )
    },
    @{
        Label = "Game Drawer Availability Tests"
        Args  = @(
            (Join-Path $RepoRoot "tests\GameDrawerAvailabilityTests.lua"),
            (Join-Path $RepoRoot "addons\CreshChat\UI.lua")
        )
    },
    @{
        Label = "Achievements Availability Tests"
        Args  = @(
            (Join-Path $RepoRoot "tests\AchievementsAvailabilityTests.lua"),
            (Join-Path $RepoRoot "addons\CreshCollect\Achievements.lua")
        )
    },
    @{
        Label = "Progression Window Tests"
        Args  = @(
            (Join-Path $RepoRoot "tests\ProgressionWindowTests.lua"),
            (Join-Path $RepoRoot "addons\CreshCollect\BattlePass.lua"),
            (Join-Path $RepoRoot "addons\CreshCollect\Achievements.lua")
        )
    },
    @{
        Label = "Progress Overview Tests"
        Args  = @(
            (Join-Path $RepoRoot "tests\ProgressOverviewTests.lua"),
            (Join-Path $RepoRoot "addons\CreshCollect\BattlePass.lua"),
            (Join-Path $RepoRoot "addons\CreshCollect\Achievements.lua"),
            (Join-Path $RepoRoot "addons\CreshCollect\ProgressOverview.lua")
        )
    },
    @{
        Label = "Launcher Routing Tests"
        Args  = @(
            (Join-Path $RepoRoot "tests\LauncherRoutingTests.lua"),
            (Join-Path $RepoRoot "addons\CreshChat\UI.lua")
        )
    },
    @{
        Label = "Collection Unlock Tests"
        Args  = @(
            (Join-Path $RepoRoot "tests\CollectionUnlockTests.lua"),
            (Join-Path $RepoRoot "shared\Suite.lua"),
            (Join-Path $RepoRoot "addons\CreshCollect\CreshCollectDatabase.lua"),
            (Join-Path $RepoRoot "addons\CreshCollect\CreshCollect.lua")
        )
    },
    @{
        Label = "BattlePass/CardDeck Recursion Tests"
        Args  = @(
            (Join-Path $RepoRoot "tests\BattlePassCardDeckRecursionTests.lua")
        )
    }
)

# ---------------------------------------------------------------------------
# Locate Lua interpreter
# ---------------------------------------------------------------------------
$luaExe = $null
foreach ($candidate in @("lua", "lua51", "lua54", "lua5.1", "lua5.4")) {
    try {
        $cmd = Get-Command $candidate -ErrorAction Stop
        $luaExe = $cmd.Source
        break
    } catch { }
}

if (-not $luaExe) {
    Write-Host ""
    Write-Host "Lua interpreter not found on PATH." -ForegroundColor Yellow
    Write-Host "Install Lua 5.1 or 5.4 and ensure it is on PATH, then re-run this script."
    Write-Host ""
    Write-Host "Windows: https://luabinaries.sourceforge.net/ (lua-5.4.x_Win64_bin.zip)"
    Write-Host "         Extract and add the folder to your PATH."
    Write-Host ""
    Write-Host "Skipping tests (exit 2)." -ForegroundColor Yellow
    exit 2
}

Write-Host "Lua: $luaExe" -ForegroundColor Cyan

# ---------------------------------------------------------------------------
# Run all suites
# ---------------------------------------------------------------------------
$overallExit = 0

foreach ($suite in $Suites) {
    # Verify all required files exist before running.
    $missing = $suite.Args | Where-Object { -not (Test-Path $_) }
    if ($missing) {
        Write-Host ""
        Write-Host "[$($suite.Label)] SKIP - missing files:" -ForegroundColor Yellow
        $missing | ForEach-Object { Write-Host "  $_" }
        continue
    }

    Write-Host ""
    Write-Host "=== $($suite.Label) ===" -ForegroundColor Cyan
    Write-Host ""

    & $luaExe @($suite.Args)
    $exitCode = $LASTEXITCODE

    Write-Host ""
    if ($exitCode -eq 0) {
        Write-Host "$($suite.Label): passed." -ForegroundColor Green
    } else {
        Write-Host "$($suite.Label): FAILED (exit $exitCode)." -ForegroundColor Red
        $overallExit = 1
    }
}

Write-Host ""
if ($overallExit -eq 0) {
    Write-Host "All suites passed." -ForegroundColor Green
} else {
    Write-Host "One or more suites FAILED." -ForegroundColor Red
}

exit $overallExit
