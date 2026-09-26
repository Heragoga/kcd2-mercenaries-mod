<#
.SYNOPSIS
    Find the Kingdom Come Deliverance 2 install on THIS machine and print its path.

.DESCRIPTION
    Every packaging and harness script used to carry its own hardcoded
    "C:\Program Files\Steam\steamapps\common\KingdomComeDeliverance2", which is wrong
    the moment the repo is cloned onto another PC, a machine with Steam on D:, or a
    Steam library outside the default folder. This is the one place that knows how to
    find the game; everything else asks it.

    Resolution order, first hit wins:

      1. $env:KCD2_DIR            (or $env:KCD2_DEV_DIR with -Dev) - the escape hatch,
                                  and the only thing needed for a non-Steam install
      2. tools\local.paths.txt    "game=..." / "dev=..." lines, per-machine, gitignored
      3. Steam                    the registry's SteamPath, then EVERY library in
                                  libraryfolders.vdf - which is what makes a game on a
                                  second drive work
      4. a short list of the usual fixed locations

    A candidate only counts if it actually looks like the game (see Test-KCD2Dir), so a
    leftover empty folder cannot shadow the real install.

.PARAMETER Dev
    Resolve the separate DEV build (the one PackageModDev.bat deploys to) instead of the
    retail install. Falls back to the retail path if no dev build is configured.

.PARAMETER Quiet
    Suppress the diagnostic lines. The resolved path always goes to stdout ALONE, so
    `for /f` in a .bat can capture it; diagnostics go to stderr.

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File tools\Find-KCD2.ps1
.EXAMPLE
    $env:KCD2_DIR = "D:\Games\KCD2"     # override on a machine that autodetect misses
#>
[CmdletBinding()]
param(
    [switch]$Dev,
    [switch]$Quiet
)

$ErrorActionPreference = "Stop"

function Write-Note([string]$msg) {
    if (-not $Quiet) { [Console]::Error.WriteLine("[find-kcd2] $msg") }
}

# A real install has the game's own Data folder, or one of the known executables. The
# retail and dev builds ship different exe folders, so accept either.
$ExeRelPaths = @(
    "Bin\Win64MasterMasterSteamPGO\KingdomCome.exe",
    "Bin\Win64ReleaseSteamLTO_DLL\KingdomCome.exe",
    "Bin\Win64\KingdomCome.exe"
)

function Test-KCD2Dir([string]$dir) {
    if ([string]::IsNullOrWhiteSpace($dir)) { return $false }
    if (-not (Test-Path -LiteralPath $dir)) { return $false }
    foreach ($rel in $ExeRelPaths) {
        if (Test-Path -LiteralPath (Join-Path $dir $rel)) { return $true }
    }
    # A dev build may be mid-copy and have no exe yet; Data + Mods is enough to identify it.
    return (Test-Path -LiteralPath (Join-Path $dir "Data")) -and
           (Test-Path -LiteralPath (Join-Path $dir "Localization"))
}

# ---------------------------------------------------------------- 1. env override
$envName = if ($Dev) { "KCD2_DEV_DIR" } else { "KCD2_DIR" }
$fromEnv = [Environment]::GetEnvironmentVariable($envName)
if ($fromEnv) {
    if (Test-KCD2Dir $fromEnv) {
        Write-Note "using $envName"
        Write-Output (Resolve-Path -LiteralPath $fromEnv).Path
        exit 0
    }
    Write-Note "$envName is set to '$fromEnv' but that does not look like a KCD2 install - ignoring it"
}

# ---------------------------------------------------------------- 2. local.paths.txt
$localFile = Join-Path $PSScriptRoot "local.paths.txt"
if (Test-Path -LiteralPath $localFile) {
    $wantKey = if ($Dev) { "dev" } else { "game" }
    foreach ($line in Get-Content -LiteralPath $localFile) {
        $t = $line.Trim()
        if ($t -eq "" -or $t.StartsWith("#")) { continue }
        $eq = $t.IndexOf("=")
        if ($eq -lt 1) { continue }
        $k = $t.Substring(0, $eq).Trim().ToLower()
        $v = $t.Substring($eq + 1).Trim().Trim('"')
        if ($k -eq $wantKey -and $v) {
            if (Test-KCD2Dir $v) {
                Write-Note "using tools\local.paths.txt ($wantKey)"
                Write-Output (Resolve-Path -LiteralPath $v).Path
                exit 0
            }
            Write-Note "local.paths.txt $wantKey='$v' does not look like a KCD2 install - ignoring it"
        }
    }
}

# A dev build is opt-in only: there is nothing to autodetect it by, and silently
# handing back the retail install would have PackageModDev deploy to the wrong game.
if ($Dev) {
    Write-Note "no dev build configured (set KCD2_DEV_DIR, or a dev= line in tools\local.paths.txt)"
    exit 1
}

# ---------------------------------------------------------------- 3. Steam libraries
$candidates = New-Object System.Collections.Generic.List[string]

$steamRoots = @()
foreach ($key in @("HKCU:\Software\Valve\Steam", "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam",
                   "HKLM:\SOFTWARE\Valve\Steam")) {
    try {
        $p = (Get-ItemProperty -Path $key -ErrorAction Stop)
        foreach ($prop in @("SteamPath", "InstallPath")) {
            if ($p.$prop) { $steamRoots += [string]$p.$prop }
        }
    } catch { }
}
$steamRoots += @("C:\Program Files (x86)\Steam", "C:\Program Files\Steam")
$steamRoots = $steamRoots | Where-Object { $_ } | Select-Object -Unique

foreach ($root in $steamRoots) {
    $root = $root.Replace("/", "\")
    if (-not (Test-Path -LiteralPath $root)) { continue }
    # The library that Steam itself lives in, plus every library it knows about. The
    # .vdf is a small nested key/value format; every "path" value is a library root.
    $libs = New-Object System.Collections.Generic.List[string]
    $libs.Add($root)
    foreach ($vdf in @((Join-Path $root "steamapps\libraryfolders.vdf"),
                       (Join-Path $root "config\libraryfolders.vdf"))) {
        if (-not (Test-Path -LiteralPath $vdf)) { continue }
        try {
            foreach ($m in [regex]::Matches((Get-Content -LiteralPath $vdf -Raw),
                                            '"path"\s*"([^"]+)"')) {
                $libs.Add($m.Groups[1].Value.Replace("\\", "\"))
            }
        } catch { }
    }
    foreach ($lib in ($libs | Select-Object -Unique)) {
        $candidates.Add((Join-Path $lib "steamapps\common\KingdomComeDeliverance2"))
    }
}

# ---------------------------------------------------------------- 4. usual suspects
foreach ($fixed in @(
    "C:\Program Files (x86)\Steam\steamapps\common\KingdomComeDeliverance2",
    "C:\Program Files\Steam\steamapps\common\KingdomComeDeliverance2",
    "C:\Program Files (x86)\Epic Games\KingdomComeDeliverance2",
    "C:\Program Files\Epic Games\KingdomComeDeliverance2",
    "C:\GOG Games\Kingdom Come Deliverance II",
    "D:\Games\KingdomComeDeliverance2")) {
    $candidates.Add($fixed)
}

foreach ($c in ($candidates | Select-Object -Unique)) {
    if (Test-KCD2Dir $c) {
        Write-Note "found $c"
        Write-Output (Resolve-Path -LiteralPath $c).Path
        exit 0
    }
}

Write-Note "could not find Kingdom Come Deliverance 2 on this machine."
Write-Note "Checked $($candidates.Count) location(s), including every Steam library."
Write-Note "Fix it either way:"
Write-Note "    set KCD2_DIR=D:\path\to\KingdomComeDeliverance2"
Write-Note "  or put a line in tools\local.paths.txt (gitignored):"
Write-Note "    game=D:\path\to\KingdomComeDeliverance2"
exit 1
