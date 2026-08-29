# Closed-loop FUNCTIONAL test harness. Launches KCD2, loads the test save from the main
# menu, presses F8 (merc_torture_auto - the in-game campaign in mercenaries_torture.lua),
# then - when the campaign logs "SAVED - awaiting reload" - drives the Escape-menu
# save+reload by keystroke (the user's own recipe), waits for phase B to verify the
# reloaded world, and parses kcd.log for the verdicts.
#
#   powershell -ExecutionPolicy Bypass -File tools\torturetest.ps1
#
# Menu recipe knobs (override if the save list shifts):
#   -DownsToLoad 2       downs at the MAIN menu to reach the load-game entry
#   -DownsToSave 26      downs inside the main-menu save list (the in-field save moved
#                        one deeper than the old bench save's 25)
#   In-field reload, per the user: escape, down, enter (save), wait, enter,
#   then one down, enter, enter (into the save list), downs to the newest save, enter.
param(
    [int]$DownsToLoad = 2,
    [int]$DownsToSave = 26,
    [int]$MenuWaitSec = 35,
    [switch]$AttachOnly,
    [switch]$MenuReload,  # drive the reload by Escape-menu keystrokes instead of relaunch+Continue
    [string]$Scenario = "",   # ambush|latecamp|kuttenberg|banditcamp|trosky -> load that save, run the F7 probe
    [int]$ScenarioDowns = -1  # override the scenario's save-list position if the list has shifted
)

# The user's purpose-built saves, by main-menu list position (newest first) and the
# exact file the engine must report loading - a mismatch aborts rather than probing
# the wrong world. Positions drift as new saves appear; -ScenarioDowns overrides.
$ScenarioMap = @{
    "ambush"     = @{ Downs = 0; File = "save495.whs" }   # a bandit 3m from Henry
    "latecamp"   = @{ Downs = 1; File = "save494.whs" }   # 50 mercs, full palisade, towers, carts
    "kuttenberg" = @{ Downs = 2; File = "save493.whs" }   # mid-city, Kleinkrieg active
    "banditcamp" = @{ Downs = 3; File = "save492.whs"; Aggro = $true }   # beside a vanilla bandit camp
    "trosky"     = @{ Downs = -1; File = "save454.whs" }  # position unknown - needs -ScenarioDowns
}
$ScenarioFile = ""
if ($Scenario -ne "") {
    if (-not $ScenarioMap.ContainsKey($Scenario)) {
        Write-Output ("[harness] FAIL: unknown scenario '" + $Scenario + "' (" + ($ScenarioMap.Keys -join ", ") + ")")
        exit 1
    }
    $ScenarioFile = $ScenarioMap[$Scenario].File
    $d = $ScenarioMap[$Scenario].Downs
    if ($ScenarioDowns -ge 0) { $d = $ScenarioDowns }
    if ($d -lt 0) {
        Write-Output "[harness] FAIL: scenario '$Scenario' has no known list position - pass -ScenarioDowns"
        exit 1
    }
    $DownsToSave = $d
    Write-Output ("[harness] scenario '" + $Scenario + "': expecting " + $ScenarioFile + " at " + $DownsToSave + " down")
}

$ErrorActionPreference = "Stop"
$GameDir = "C:\Program Files\Steam\steamapps\common\KingdomComeDeliverance2"
$Exe     = Join-Path $GameDir "Bin\Win64MasterMasterSteamPGO\KingdomCome.exe"
$Log     = Join-Path $GameDir "kcd.log"

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class KeySender {
    [StructLayout(LayoutKind.Sequential)]
    struct INPUT { public uint type; public KEYBDINPUT ki; public ulong pad; }
    [StructLayout(LayoutKind.Sequential)]
    struct KEYBDINPUT { public ushort wVk; public ushort wScan; public uint dwFlags; public uint time; public IntPtr dwExtraInfo; }
    [DllImport("user32.dll", SetLastError=true)] static extern uint SendInput(uint n, INPUT[] inputs, int size);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    const uint KEYEVENTF_SCANCODE = 0x8; const uint KEYEVENTF_KEYUP = 0x2; const uint KEYEVENTF_EXTENDEDKEY = 0x1;
    public static void Tap(ushort scan, bool extended, int holdMs) {
        uint fl = KEYEVENTF_SCANCODE | (extended ? KEYEVENTF_EXTENDEDKEY : 0);
        var d = new INPUT[]{ new INPUT{ type=1, ki=new KEYBDINPUT{ wScan=scan, dwFlags=fl } } };
        var u = new INPUT[]{ new INPUT{ type=1, ki=new KEYBDINPUT{ wScan=scan, dwFlags=fl|KEYEVENTF_KEYUP } } };
        SendInput(1, d, Marshal.SizeOf(typeof(INPUT)));
        System.Threading.Thread.Sleep(holdMs);
        SendInput(1, u, Marshal.SizeOf(typeof(INPUT)));
    }
}
"@

function Tap-Key([string]$name, [int]$after = 180) {
    switch ($name) {
        "down"  { [KeySender]::Tap(0x50, $true,  60) }
        "up"    { [KeySender]::Tap(0x48, $true,  60) }
        "enter" { [KeySender]::Tap(0x1C, $false, 60) }
        "f6"    { [KeySender]::Tap(0x40, $false, 60) }
        "f7"    { [KeySender]::Tap(0x41, $false, 60) }
        "f8"    { [KeySender]::Tap(0x42, $false, 60) }
        "esc"   { [KeySender]::Tap(0x01, $false, 60) }
    }
    Start-Sleep -Milliseconds $after
}

function Focus-Game {
    $p = Get-Process KingdomCome -ErrorAction SilentlyContinue
    if (-not $p -or $p.MainWindowHandle -eq 0) {
        Write-Output "[harness] no game window to focus"
        return $false
    }
    for ($try = 0; $try -lt 5; $try++) {
        [KeySender]::Tap(0x38, $false, 30)   # Alt tap releases the foreground lock
        [KeySender]::ShowWindow($p.MainWindowHandle, 9) | Out-Null
        [KeySender]::SetForegroundWindow($p.MainWindowHandle) | Out-Null
        Start-Sleep -Milliseconds 700
        if ([KeySender]::GetForegroundWindow() -eq $p.MainWindowHandle) {
            Write-Output "[harness] game window focused"
            return $true
        }
        Start-Sleep -Milliseconds 800
    }
    Write-Output "[harness] could not bring the game to the foreground - not sending keys"
    return $false
}

function Read-LogTailFrom([long]$fromLen) {
    if (-not (Test-Path $Log)) { return "" }
    $len = 0; try { $len = (Get-Item $Log).Length } catch {}
    if ($len -lt $fromLen) { $fromLen = 0 }
    if ($len -le $fromLen) { return "" }
    try {
        $fs = [System.IO.File]::Open($Log, 'Open', 'Read', 'ReadWrite')
        $fs.Seek($fromLen, 'Begin') | Out-Null
        $sr = New-Object System.IO.StreamReader($fs)
        $tail = $sr.ReadToEnd()
        $sr.Close(); $fs.Close()
        return $tail
    } catch { return "" }
}

# Waits for EITHER pattern (second may be ""), from content appended after the call began.
function Wait-LogAny([string]$p1, [string]$p2, [int]$timeoutSec) {
    $deadline = (Get-Date).AddSeconds($timeoutSec)
    $startLen = 0
    if (Test-Path $Log) { try { $startLen = (Get-Item $Log).Length } catch {} }
    while ((Get-Date) -lt $deadline) {
        $tail = Read-LogTailFrom $startLen
        if ($tail.Contains($p1)) { return $p1 }
        if ($p2 -ne "" -and $tail.Contains($p2)) { return $p2 }
        # A crash mid-wait: report rather than sit out the timeout.
        $g = @(Get-Process KingdomCome -ErrorAction SilentlyContinue)
        if ($g.Count -eq 0) { return "GAME_DIED" }
        Start-Sleep -Seconds 2
    }
    return $null
}

$t0 = Get-Date

# Launch (killing any prior instance) and wait until the main menu idles.
function Launch-GameToMenu {
    Get-Process KingdomCome -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 3
    Write-Output "[harness] launching..."
    Start-Process -FilePath $Exe -WorkingDirectory $GameDir -ArgumentList "-devmode","+exec","user.cfg"
    Start-Sleep -Seconds 12
    for ($try = 0; $try -lt 6; $try++) {
        $procs = @(Get-Process KingdomCome -ErrorAction SilentlyContinue)
        if ($procs.Count -le 1) { break }
        Write-Output ("[harness] " + $procs.Count + " game instances - waiting for the Steam bounce to settle")
        Start-Sleep -Seconds 5
        $procs = @(Get-Process KingdomCome -ErrorAction SilentlyContinue | Sort-Object StartTime)
        if ($procs.Count -gt 1) {
            for ($i = 0; $i -lt $procs.Count - 1; $i++) {
                Write-Output ("[harness] killing older duplicate PID " + $procs[$i].Id)
                Stop-Process -Id $procs[$i].Id -Force -ErrorAction SilentlyContinue
            }
        }
    }
    # Menu-ready: the log grows fast through init and goes quiet once the menu idles.
    $up0 = Get-Date
    $lastLen = -1; $quietSince = Get-Date
    while ($true) {
        $g = @(Get-Process KingdomCome -ErrorAction SilentlyContinue)
        if ($g.Count -eq 0) {
            Write-Output "[harness] game vanished during init - relaunching"
            Start-Process -FilePath $Exe -WorkingDirectory $GameDir -ArgumentList "-devmode","+exec","user.cfg"
            Start-Sleep -Seconds 12; $up0 = Get-Date; $lastLen = -1; $quietSince = Get-Date
            continue
        }
        $len = 0; try { $len = (Get-Item $Log).Length } catch {}
        if ($len -ne $lastLen) { $lastLen = $len; $quietSince = Get-Date }
        $upSecs = ((Get-Date) - $up0).TotalSeconds
        $quietSecs = ((Get-Date) - $quietSince).TotalSeconds
        if ($upSecs -ge 40 -and $quietSecs -ge 10) { Write-Output "[harness] log quiet - menu should be idle"; break }
        if ($upSecs -ge 240) { Write-Output "[harness] WARN: init never went quiet - proceeding anyway"; break }
        Start-Sleep -Seconds 2
    }
}

# ---------------------------------------------------------------- launch + main menu
if (-not $AttachOnly) { Launch-GameToMenu }

# ---------------------------------------------------------------- load the test save
$loaded = $false
for ($attempt = 1; $attempt -le 3 -and -not $loaded; $attempt++) {
    if (-not (Focus-Game)) {
        Write-Output "[harness] FAIL: cannot focus the game at the main menu"
        Get-Process KingdomCome -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        exit 1
    }
    $navLen = 0; try { $navLen = (Get-Item $Log).Length } catch {}
    Write-Output "[harness] menu attempt ${attempt}: down x$DownsToLoad, enter, enter, down x$DownsToSave, enter, enter"
    for ($i = 0; $i -lt $DownsToLoad; $i++) { Tap-Key "down" 300 }
    Tap-Key "enter" 1500
    Tap-Key "enter" 2000
    for ($i = 0; $i -lt $DownsToSave; $i++) { Tap-Key "down" 180 }
    Tap-Key "enter" 1800
    Tap-Key "enter" 1000
    $deadline = (Get-Date).AddSeconds(25)
    while ((Get-Date) -lt $deadline -and -not $loaded) {
        $tail = Read-LogTailFrom $navLen
        if ($tail.Contains("Loading saved game") -or $tail.Contains("Game loaded! Starting the inventory monitor")) {
            $m = [regex]::Match($tail, "Loading saved game '[^']*/([^/']+\.whs)'")
            $script:LoadedFile = if ($m.Success) { $m.Groups[1].Value } else { "" }
            Write-Output ("[harness] load confirmed (" + $script:LoadedFile + ")")
            $loaded = $true
        } else { Start-Sleep -Seconds 2 }
    }
    if (-not $loaded) {
        Write-Output "[harness] no load detected - backing out with Escape and retrying"
        Focus-Game
        Tap-Key "esc" 900; Tap-Key "esc" 900; Tap-Key "esc" 1500
    }
}
if (-not $loaded) {
    Write-Output "[harness] FAIL: navigation never started a load after 3 attempts - check -DownsToLoad/-DownsToSave"
    Get-Process KingdomCome -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    exit 1
}

Write-Output "[harness] waiting for the save to finish loading..."
$r = Wait-LogAny "Game loaded! Starting the inventory monitor" "" 240
if ($r -ne "Game loaded! Starting the inventory monitor") {
    Write-Output "[harness] FAIL: load started but never finished ($r)"
    Get-Process KingdomCome -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    exit 1
}
if ($Scenario -ne "") { Start-Sleep -Seconds 4 } else { Start-Sleep -Seconds 12 }

# ---------------------------------------------------------------- phase A
if ($Scenario -ne "") {
    # ------------------------------------------------------------ scenario probe (F7)
    if ($ScenarioFile -ne "" -and $script:LoadedFile -ne "" -and $script:LoadedFile -ne $ScenarioFile) {
        Write-Output ("[harness] FAIL: wanted " + $ScenarioFile + " but the engine loaded " + $script:LoadedFile + " - not probing the wrong world (adjust -ScenarioDowns)")
        Get-Process KingdomCome -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        $reportOnly = $true
    } elseif (-not (Focus-Game)) {
        Write-Output "[harness] FAIL: cannot focus the game to start the probe"
        Get-Process KingdomCome -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        $reportOnly = $true
    } else {
        $probeKey = "f7"
        if ($ScenarioMap[$Scenario].ContainsKey("Aggro") -and $ScenarioMap[$Scenario].Aggro) { $probeKey = "f6" }
        Write-Output "[harness] $probeKey - scenario probe starts"
        # Snapshot the log BEFORE the tap: the banner can flush faster than Wait-LogAny
        # gets to capture its baseline, making a started probe read as never-started.
        $f7Len = 0; try { $f7Len = (Get-Item $Log).Length } catch {}
        Tap-Key $probeKey 500
        $started = $null
        $dl = (Get-Date).AddSeconds(30)
        while ((Get-Date) -lt $dl -and -not $started) {
            if ((Read-LogTailFrom $f7Len).Contains("=== scenario probe")) { $started = "=== scenario probe" }
            else { Start-Sleep -Seconds 2 }
        }
        if ($started -ne "=== scenario probe") {
            Write-Output "[harness] probe did not start - re-focusing and re-tapping $probeKey"
            Focus-Game | Out-Null
            Tap-Key $probeKey 500
            $started = Wait-LogAny "=== scenario probe" "" 30
        }
        if ($started -ne "=== scenario probe") {
            Write-Output "[harness] FAIL: probe never started after two F7 presses"
        }
        $rp = Wait-LogAny "[Torture] COMPLETE" "" 900
        if ($rp -eq "GAME_DIED") { Write-Output "[harness] GAME DIED during the probe" }
        elseif ($null -eq $rp)   { Write-Output "[harness] FAIL: probe never completed" }
    }
    Start-Sleep -Seconds 6
    Get-Process KingdomCome -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
}
else {
if (-not (Focus-Game)) {
    Write-Output "[harness] FAIL: cannot focus the game to start the campaign"
    Get-Process KingdomCome -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    exit 1
}
Write-Output "[harness] F8 - torture campaign starts"
Tap-Key "f8" 500

$r = Wait-LogAny "[Torture] SAVED - awaiting reload" "[Torture] COMPLETE" 800
if ($r -eq "GAME_DIED") {
    Write-Output "[harness] GAME DIED during phase A - collecting what there is"
} elseif ($r -eq "[Torture] COMPLETE") {
    Write-Output "[harness] campaign completed without reaching the save step (see verdicts below)"
} elseif ($null -eq $r) {
    Write-Output "[harness] FAIL: phase A never reached the save step within the timeout"
} elseif (-not $MenuReload) {
    # ------------------------------------------------------------ relaunch + Continue
    # The stamped save is an AUTOSAVE (Game.QuickSave writes that slot), so it is the
    # newest save by time - and the main menu's Continue resumes exactly that. The main
    # menu is the one surface these keystrokes have driven reliably in every run.
    # Phase B self-validates: it only arms on the stage stamp in the loaded save, so a
    # wrong save shows as a timeout here, never as a false pass.
    # A save FILE must exist before a relaunch can resume it - Game.QuickSave produced
    # nothing for five runs (airborne player), and phase B silently starved. Demand a
    # save newer than the campaign's start before burning a relaunch on it.
    $SaveDir = Join-Path $env:USERPROFILE "Saved Games\kingdomcome2\saves\playline0"
    $fresh = $null
    $deadline = (Get-Date).AddSeconds(45)
    while ((Get-Date) -lt $deadline -and -not $fresh) {
        $fresh = Get-ChildItem $SaveDir -Filter *.whs -ErrorAction SilentlyContinue |
                 Where-Object { $_.LastWriteTime -gt $t0 } |
                 Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if (-not $fresh) { Start-Sleep -Seconds 3 }
    }
    if (-not $fresh) {
        Write-Output "[harness] FAIL: no save file written this run - phase B impossible"
    } else {
        Write-Output ("[harness] fresh save on disk: " + $fresh.Name + " (" + $fresh.LastWriteTime.ToString("HH:mm:ss") + ")")
    }
    Write-Output "[harness] letting the save settle, then relaunching to Continue"
    Start-Sleep -Seconds 10
    Launch-GameToMenu
    $bLoaded = $false
    for ($attempt = 1; $attempt -le 3 -and -not $bLoaded; $attempt++) {
        if (-not (Focus-Game)) { break }
        $navLen = 0; try { $navLen = (Get-Item $Log).Length } catch {}
        if ($attempt -eq 1) {
            # Continue is the default-highlighted top item.
            Write-Output "[harness] continue attempt 1: enter"
            Tap-Key "enter" 2500
        } else {
            # Cursor was elsewhere: press up a few times to reach the top, then enter.
            Write-Output "[harness] continue attempt ${attempt}: up x3, enter"
            Tap-Key "up" 300; Tap-Key "up" 300; Tap-Key "up" 300
            Tap-Key "enter" 2500
        }
        $deadline = (Get-Date).AddSeconds(30)
        while ((Get-Date) -lt $deadline -and -not $bLoaded) {
            $tail = Read-LogTailFrom $navLen
            if ($tail.Contains("Loading saved game")) {
                Write-Output "[harness] continue load started"
                $bLoaded = $true
            } else { Start-Sleep -Seconds 2 }
        }
        if (-not $bLoaded) {
            Write-Output "[harness] continue attempt $attempt did not take - backing out"
            if (-not (Focus-Game)) { break }
            Tap-Key "esc" 900; Tap-Key "esc" 1200
        }
    }
    if ($bLoaded) {
        # Phase B is armed by a second F8 now (never self-arms - see mercenaries_torture.lua).
        $r0 = Wait-LogAny "Game loaded! Starting the inventory monitor" "" 240
        Start-Sleep -Seconds 12
        if (Focus-Game) {
            Write-Output "[harness] F8 - phase B"
            Tap-Key "f8" 500
        }
        Write-Output "[harness] waiting for phase B verdicts..."
        $r2 = Wait-LogAny "[Torture] COMPLETE" "" 420
        if ($r2 -eq "GAME_DIED") { Write-Output "[harness] GAME DIED during phase B" }
        elseif ($null -eq $r2)   { Write-Output "[harness] FAIL: phase B never completed (wrong save resumed?)" }
    } else {
        Write-Output "[harness] FAIL: could not drive Continue - phase B unverified"
    }
} else {
    # ------------------------------------------------------------ in-field save + reload
    Write-Output "[harness] quicksave written - driving the Escape-menu save + reload"
    Start-Sleep -Seconds 6

    $reloaded = $false
    for ($attempt = 1; $attempt -le 3 -and -not $reloaded; $attempt++) {
        if (-not (Focus-Game)) { break }
        $navLen = 0; try { $navLen = (Get-Item $Log).Length } catch {}
        if ($attempt -eq 1) {
            # The FULL proven chain from runs 1-2, where the menu-save turned out to be
            # LOAD-BEARING: it creates the newest manual save, and the load half then
            # finds it one down in the list (the user said it: "the in field save file
            # is now an additional one down"). Run 3 skipped the save half and its load
            # never completed.
            Write-Output "[harness] reload attempt 1: menu save, unwind, then load the fresh save"
            Tap-Key "esc" 1200
            Tap-Key "down" 400; Tap-Key "enter" 2500        # Save
            Start-Sleep -Seconds 7                           # let it write
            Tap-Key "enter" 1500                             # dismiss
            Tap-Key "esc" 900; Tap-Key "esc" 900             # unwind to gameplay
            Tap-Key "esc" 1200                               # pause menu again
            Tap-Key "down" 300; Tap-Key "down" 300; Tap-Key "enter" 1800   # Load
            Tap-Key "enter" 2000                             # into the save list
            Tap-Key "down" 300                               # the fresh field save
            Tap-Key "enter" 1800
            Tap-Key "enter" 1500                             # confirm
        } elseif ($attempt -eq 2) {
            # Straight load of whatever sits one down in the list.
            Write-Output "[harness] reload attempt 2: esc, down x2, enter, enter, down x1, enter, enter"
            Tap-Key "esc" 900; Tap-Key "esc" 900       # close any dialog left behind
            Tap-Key "esc" 1200
            Tap-Key "down" 300; Tap-Key "down" 300; Tap-Key "enter" 1800
            Tap-Key "enter" 2000
            Tap-Key "down" 300
            Tap-Key "enter" 1800
            Tap-Key "enter" 1500
        } else {
            # Load one down from the top, newest at the top.
            Write-Output "[harness] reload attempt 3: esc, down x1, enter, enter, enter, enter"
            Tap-Key "esc" 900; Tap-Key "esc" 900
            Tap-Key "esc" 1200
            Tap-Key "down" 300; Tap-Key "enter" 1800
            Tap-Key "enter" 2000
            Tap-Key "enter" 1800
            Tap-Key "enter" 1500
        }
        # Only a COMPLETED load counts. The save list prints "Loading saved game ..."
        # merely from SELECTING an entry (the details panel reads its header) - which is
        # exactly how run 3 declared success over a load that never happened.
        $deadline = (Get-Date).AddSeconds(90)
        while ((Get-Date) -lt $deadline -and -not $reloaded) {
            $tail = Read-LogTailFrom $navLen
            if ($tail.Contains("Game loaded! Starting the inventory monitor")) {
                Write-Output "[harness] reload confirmed (load completed)"
                $reloaded = $true
            } else { Start-Sleep -Seconds 2 }
        }
        if (-not $reloaded) {
            Write-Output "[harness] reload attempt $attempt did not take - backing out"
            if (-not (Focus-Game)) { break }
            Tap-Key "esc" 900; Tap-Key "esc" 900; Tap-Key "esc" 1500
        }
    }

    if ($reloaded) {
        Write-Output "[harness] waiting for phase B verdicts..."
        $r2 = Wait-LogAny "[Torture] COMPLETE" "" 300
        if ($r2 -eq "GAME_DIED") { Write-Output "[harness] GAME DIED during phase B" }
        elseif ($null -eq $r2)   { Write-Output "[harness] FAIL: phase B never completed" }
    } else {
        Write-Output "[harness] FAIL: could not drive the in-field reload - phase B unverified"
    }
}

Start-Sleep -Seconds 6
Get-Process KingdomCome -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
}

# ---------------------------------------------------------------- verdicts
Write-Output ""
Write-Output "===== TORTURE OUTPUT ====="
# A relaunch rotates kcd.log into LogBackups, taking phase A's verdicts with it -
# report across the current log AND the newest backup.
$reportLogs = @()
$bak = Get-ChildItem (Join-Path $GameDir "LogBackups") -Filter *.log -ErrorAction SilentlyContinue |
       Where-Object { $_.LastWriteTime -gt $t0 } |
       Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($bak) { $reportLogs += $bak.FullName }
$reportLogs += $Log
foreach ($rl in $reportLogs) {
    Select-String -Path $rl -Pattern "\[Torture\]" -ErrorAction SilentlyContinue | ForEach-Object { $_.Line }
}

Write-Output ""
Write-Output "===== HEALTH COUNTERS ====="
foreach ($pat in @("Going to play random line", "would not leave his pose", "STALL ",
                   "stalled 3x", "Out of memory", "SpawnMercCamp error", "restore failed",
                   "tick error", "run error", "action error")) {
    $n = 0
    foreach ($rl in $reportLogs) {
        $n += @(Select-String -Path $rl -Pattern ([regex]::Escape($pat)) -ErrorAction SilentlyContinue).Count
    }
    Write-Output ("{0,-32} {1}" -f $pat, $n)
}
Write-Output ""
Write-Output "===== SCRIPT ERRORS (grep) ====="
Select-String -Path $Log -Pattern "Lua Error|SCRIPT ERROR|\.lua:" | Select-Object -First 25 | ForEach-Object { $_.Line }
Write-Output "[harness] done"
