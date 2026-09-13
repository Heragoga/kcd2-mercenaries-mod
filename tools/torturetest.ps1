# Closed-loop FUNCTIONAL test harness. Launches KCD2, loads the test save from the main
# menu, TYPES merc_torture_auto into the devmode console (the in-game campaign in
# mercenaries_torture.lua), then - when the campaign logs "SAVED - awaiting reload" -
# relaunches and resumes, arms phase B the same way, and parses kcd.log for the verdicts.
#
# Nothing here is fired by an F-key any more. A run tapped F8 after a clean
# "dev binds applied" and NOTHING happened - the game's own bindings shadow the F-keys -
# and because the plan is what arms god mode, Henry stood unprotected and was killed. Every
# trigger is a typed console command now, and every one is PROVEN to have started (see
# Start-Torture) before the harness commits to a long wait.
#
#   powershell -ExecutionPolicy Bypass -File tools\torturetest.ps1
#
# Three runs live here now:
#   -Plan campaign   (default) the two-phase camp campaign, exactly as before
#   -Plan field      the single-session FIELD plan - walking, following at 5/12/24, a fight
#                    in the open, camp, patrol pressure and a raid. Typed into the console
#                    as merc_torture_field_auto; no save, no relaunch, no phase B.
#   -Plan field_aggro  ...plus the base-game-NPC fight. BANDIT SAVES ONLY.
#   -Plan quest      the multi-session QUEST plan - a whole Kleinkrieg playthrough across REAL
#                    saves and REAL relaunches. Typed in as merc_torture_quest_auto; the Lua
#                    side picks the stage off the TortureStage stamp in the loaded save, so the
#                    same command runs Q1 on a fresh save and Q2/Q3 after each relaunch. The
#                    harness loops SAVED -> relaunch -> Continue -> retype until COMPLETE, at
#                    most -QuestMaxRelaunches (4) times. Meant for a KUTTENBERG save.
#   -SaveFile save492.whs   name the save instead of counting menu downs
#
# Menu recipe knobs (override if the save list shifts):
#   -DownsToLoad 2       downs at the MAIN menu to reach the load-game entry
#   -DownsToSave 26      downs inside the main-menu save list (the in-field save moved
#                        one deeper than the old bench save's 25). -SaveFile computes this.
#   In-field reload, per the user: escape, down, enter (save), wait, enter,
#   then one down, enter, enter (into the save list), downs to the newest save, enter.
param(
    [int]$DownsToLoad = 2,
    [int]$DownsToSave = 26,
    [int]$MenuWaitSec = 35,
    [switch]$AttachOnly,
    [switch]$MenuReload,  # drive the reload by Escape-menu keystrokes instead of relaunch+Continue
    [string]$Scenario = "",   # ambush|latecamp|kuttenberg|banditcamp|trosky -> load that save, run the F7 probe
    [int]$ScenarioDowns = -1, # override the scenario's save-list position if the list has shifted
    # campaign = the two-phase camp campaign (F8 + relaunch + phase B), unchanged and the default.
    # field    = the single-session FIELD plan (merc_torture_field_auto): walking, following,
    #            fighting, camping, patrols and a raid, no save and no phase B.
    # field_aggro = the same plus the base-game-NPC fight. BANDIT SAVES ONLY - on a save with
    #            civilians nearby it calls five mercs onto a civilian.
    # quest    = the multi-session QUEST plan (merc_torture_quest_auto): a whole Kleinkrieg
    #            playthrough across real saves and relaunches. Three stages, stamped Q1/Q2/Q3;
    #            the harness loops relaunch+Continue+retype until COMPLETE (max 4 relaunches).
    [ValidateSet("campaign", "field", "field_aggro", "quest")]
    [string]$Plan = "campaign",
    # Name the save you want (e.g. save492.whs) and let the harness find its menu position,
    # instead of counting downs by hand. Overrides -DownsToSave / -ScenarioDowns.
    [string]$SaveFile = "",
    [int]$FieldTimeout = 1700, # seconds to wait for the field plan's "[Torture] COMPLETE" (Lua deadline is 1620)
    # -Plan quest: seconds to wait for ONE stage to reach either "SAVED - awaiting reload" or
    # "COMPLETE". The plan's own TortureQuestDeadline is 1440, deliberately just under it, so a
    # stage that runs out of time is the one that says so - a truncated report beats no report.
    [int]$QuestTimeout = 1500,
    [int]$QuestMaxRelaunches = 4
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

# The saves folder. Also used by the campaign's phase-A "was a save actually written" check.
$SaveDir = Join-Path $env:USERPROFILE "Saved Games\kingdomcome2\saves\playline0"

# -SaveFile: work the menu position out from the folder instead of counting downs by hand.
# The main-menu list is NEWEST FIRST by write time - which is exactly WHY the documented
# positions keep drifting: a completed campaign writes an autosave to the top of the list and
# pushes every other entry down one. Recomputing the index every run makes that drift a
# non-issue, and the loaded-file check below still catches a menu that did something else.
if ($SaveFile -ne "") {
    $allSaves = @(Get-ChildItem $SaveDir -Filter *.whs -ErrorAction SilentlyContinue |
                  Sort-Object LastWriteTime -Descending)
    if ($allSaves.Count -eq 0) {
        Write-Output "[harness] FAIL: no .whs saves in $SaveDir"
        exit 1
    }
    $idx = -1
    for ($i = 0; $i -lt $allSaves.Count; $i++) {
        if ($allSaves[$i].Name -eq $SaveFile) { $idx = $i; break }
    }
    if ($idx -lt 0) {
        Write-Output ("[harness] FAIL: '" + $SaveFile + "' is not in " + $SaveDir)
        Write-Output ("[harness]       newest are: " + ((@($allSaves | Select-Object -First 8) | ForEach-Object { $_.Name }) -join ", "))
        exit 1
    }
    $DownsToSave  = $idx
    $ScenarioFile = $SaveFile     # ...and so it is verified after the load like a scenario
    Write-Output ("[harness] -SaveFile " + $SaveFile + ": position " + $idx + " of " + $allSaves.Count + " (newest first)")
}

$ErrorActionPreference = "Stop"
$GameDir = & (Join-Path $PSScriptRoot "Find-KCD2.ps1")
if (-not $GameDir) {
    Write-Output "[harness] FAIL: Kingdom Come Deliverance 2 not found on this machine."
    Write-Output "[harness]       set KCD2_DIR=D:\path\to\KingdomComeDeliverance2"
    Write-Output "[harness]       or add  game=D:\path\...  to tools\local.paths.txt"
    exit 1
}
$Exe     = Join-Path $GameDir "Bin\Win64MasterMasterSteamPGO\KingdomCome.exe"
$Log     = Join-Path $GameDir "kcd.log"
Write-Output "[harness] game: $GameDir"

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
    const uint KEYEVENTF_UNICODE = 0x4;
    // Layout-independent character injection (WM_CHAR path) for the console's edit box.
    // The console OPEN key still needs a raw scancode - the game reads keybinds from raw
    // input - but once the console has focus its text field accepts unicode input.
    public static void TypeText(string s, int perCharMs) {
        foreach (char c in s) {
            var d = new INPUT[]{ new INPUT{ type=1, ki=new KEYBDINPUT{ wVk=0, wScan=c, dwFlags=KEYEVENTF_UNICODE } } };
            var u = new INPUT[]{ new INPUT{ type=1, ki=new KEYBDINPUT{ wVk=0, wScan=c, dwFlags=KEYEVENTF_UNICODE|KEYEVENTF_KEYUP } } };
            SendInput(1, d, Marshal.SizeOf(typeof(INPUT)));
            System.Threading.Thread.Sleep(20);
            SendInput(1, u, Marshal.SizeOf(typeof(INPUT)));
            System.Threading.Thread.Sleep(perCharMs);
        }
    }
}
"@

# Open the devmode console (tilde, scancode 0x29), run one command, close. The console
# PAUSES script timers while open, so close it straight after Enter.
function Send-ConsoleCmd([string]$cmd) {
    Write-Output "[harness] console: $cmd"
    [KeySender]::Tap(0x29, $false, 60); Start-Sleep -Milliseconds 700
    [KeySender]::TypeText($cmd, 30); Start-Sleep -Milliseconds 400
    [KeySender]::Tap(0x1C, $false, 60); Start-Sleep -Milliseconds 600
    [KeySender]::Tap(0x29, $false, 60); Start-Sleep -Milliseconds 400
}

# The torture commands are dev-gated (players kept firing the auto-quit campaigns through
# the old always-on F-key binds): merc_dev arms the dev set, and only in the -devmode launch
# this harness always uses. Must run again after every game relaunch.
#
# merc_torture_bindkeys is deliberately NOT run any more. A run typed both commands, logged
# "dev binds applied", tapped F8 - and nothing happened, not one [Torture] line - because the
# game's own bindings shadow the F-keys (autobench's -ConsoleCmd exists for exactly this:
# "videofhotomode et al. own F-keys"). Worse, the plan is what arms god mode, so a trigger
# that silently does nothing leaves Henry standing unprotected in the open; that run killed
# him. Every trigger is typed now. The keybind command stays registered in Lua for manual use.
function Arm-DevCommands {
    Send-ConsoleCmd "merc_dev"
}

# Type a start command and PROVE it took, by waiting for the plan's own banner in kcd.log.
# One retype, then a loud failure - never a silent 800s wait on a run that never began.
#
# The answer comes back in $script:TortureStarted, NOT as a return value. Write-Output inside
# a function ADDS to that function's output, so a "return $true" after a few progress lines
# hands the caller an ARRAY - and any non-empty array is truthy, so the check would have
# passed whatever happened. (Focus-Game in this file has the same shape and is therefore
# effectively always true; left alone deliberately, since its callers have relied on that
# permissiveness through every green run so far.)
function Start-Torture([string]$cmd, [string]$banner) {
    $script:TortureStarted = $false
    $len = 0; try { $len = (Get-Item $Log).Length } catch {}
    Send-ConsoleCmd $cmd
    $deadline = (Get-Date).AddSeconds(30)
    while ((Get-Date) -lt $deadline) {
        if ((Read-LogTailFrom $len).Contains($banner)) {
            Write-Output "[harness] '$cmd' is running"
            $script:TortureStarted = $true
            return
        }
        Start-Sleep -Seconds 2
    }
    Write-Output "[harness] '$cmd' produced no [Torture] output in 30s - re-focusing and retyping once"
    Focus-Game | Out-Null
    Send-ConsoleCmd $cmd
    $deadline = (Get-Date).AddSeconds(45)
    while ((Get-Date) -lt $deadline) {
        if ((Read-LogTailFrom $len).Contains($banner)) {
            Write-Output "[harness] '$cmd' is running"
            $script:TortureStarted = $true
            return
        }
        Start-Sleep -Seconds 2
    }
    Write-Output "[harness] ***************************************************************"
    Write-Output "[harness] ***** FAIL: '$cmd' NEVER STARTED - no [Torture] line in 45s after two attempts."
    Write-Output "[harness] ***** Check: is this a -devmode launch, did merc_dev arm the set, is the mod actually loaded,"
    Write-Output "[harness] ***** and did the console take the text (a UI overlay eats keystrokes)?"
    Write-Output "[harness] ***** Not waiting out the run timeout on a run that never began."
    Write-Output "[harness] ***************************************************************"
}

# Menu navigation only. The F-key cases are gone on purpose - see Arm-DevCommands: nothing in
# this harness fires a test by keypress any more.
function Tap-Key([string]$name, [int]$after = 180) {
    switch ($name) {
        "down"  { [KeySender]::Tap(0x50, $true,  60) }
        "up"    { [KeySender]::Tap(0x48, $true,  60) }
        "enter" { [KeySender]::Tap(0x1C, $false, 60) }
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

# Press Continue at the main menu and wait for the load to COMPLETE. The stamped save is the
# newest by time (Game.SaveGameViaResting / QuickSave both write to the top of the list), and
# Continue resumes exactly that - the one main-menu surface these keystrokes have driven
# reliably in every run. Used only by -Plan quest, which needs it in a loop; the campaign keeps
# its own inline copy so nothing about that path changes.
#
# The answer comes back in $script:ContinueLoaded, NOT as a return value: Write-Output inside a
# function ADDS to its output, so a "return $true" after progress lines hands the caller an
# array, and any non-empty array is truthy. Same trap, same fix, as Start-Torture.
function Invoke-ContinueFromMenu {
    $script:ContinueLoaded = $false
    for ($attempt = 1; $attempt -le 3 -and -not $script:ContinueLoaded; $attempt++) {
        if (-not (Focus-Game)) { break }
        $navLen = 0; try { $navLen = (Get-Item $Log).Length } catch {}
        if ($attempt -eq 1) {
            Write-Output "[harness] continue attempt 1: enter"
            Tap-Key "enter" 2500
        } else {
            Write-Output "[harness] continue attempt ${attempt}: up x3, enter"
            Tap-Key "up" 300; Tap-Key "up" 300; Tap-Key "up" 300
            Tap-Key "enter" 2500
        }
        $started = $false
        $deadline = (Get-Date).AddSeconds(30)
        while ((Get-Date) -lt $deadline -and -not $started) {
            if ((Read-LogTailFrom $navLen).Contains("Loading saved game")) {
                Write-Output "[harness] continue load started"
                $started = $true
            } else { Start-Sleep -Seconds 2 }
        }
        if (-not $started) {
            Write-Output "[harness] continue attempt $attempt did not take - backing out"
            if (-not (Focus-Game)) { break }
            Tap-Key "esc" 900; Tap-Key "esc" 1200
            continue
        }
        # Only a COMPLETED load counts: the save list prints "Loading saved game ..." merely
        # from selecting an entry.
        $r0 = Wait-LogAny "Game loaded! Starting the inventory monitor" "" 240
        if ($r0 -eq "Game loaded! Starting the inventory monitor") {
            $script:ContinueLoaded = $true
            Start-Sleep -Seconds 12
        } else {
            Write-Output "[harness] the continue load started but never finished ($r0)"
        }
    }
}

$t0 = Get-Date

# Launch (killing any prior instance) and wait until the main menu idles.
function Ensure-SteamAppId {
    # Launched directly (not through Steam), steam_api refuses to initialise and the game
    # quits during init with "CSystem::Quit ... reason: Steam Service Quit - not started
    # through Steam". steam_appid.txt beside the exe is what tells it which app it is, and it
    # had only ever been created by hand on one machine - so a fresh checkout on a new PC saw
    # the game exit before the main menu with nothing in the log to explain it.
    $appIdFile = Join-Path $GameDir "Bin\Win64MasterMasterSteamPGO\steam_appid.txt"
    if (-not (Test-Path $appIdFile)) {
        try {
            [System.IO.File]::WriteAllText($appIdFile, "1771300")
            Write-Output "[harness] wrote steam_appid.txt (1771300) beside the exe - the game quits at init without it when launched directly"
        } catch {
            Write-Output ("[harness] WARN: could not write " + $appIdFile + " - " + $_.Exception.Message)
        }
    }
}

function Launch-GameToMenu {
    Get-Process KingdomCome -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 3
    Ensure-SteamAppId
    Write-Output "[harness] launching..."
    # "+exec user.cfg" is OPTIONAL - the engine shrugs at a user.cfg that does not exist, and
    # it is only here so a machine that HAS one gets its settings. Nothing in the harness
    # depends on it.
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
            Ensure-SteamAppId
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

# ---------------------------------------------------------------- is this the right world?
# Generalised from the scenario path, because -SaveFile needs exactly the same guarantee: a
# drifted menu list must ABORT, never silently test whatever it landed on. $ScenarioFile is
# set by -Scenario or by -SaveFile; when neither names a file there is nothing to check and
# the run proceeds from whatever state it gets (which is the campaign's documented habit).
$wrongWorld = $false
if ($ScenarioFile -ne "" -and $script:LoadedFile -ne "" -and $script:LoadedFile -ne $ScenarioFile) {
    Write-Output ("[harness] FAIL: wanted " + $ScenarioFile + " but the engine loaded " + $script:LoadedFile + " - not testing the wrong world (adjust -SaveFile / -ScenarioDowns / -DownsToSave)")
    Get-Process KingdomCome -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    $wrongWorld = $true
}

# ---------------------------------------------------------------- phase A
if ($wrongWorld) {
    Write-Output "[harness] skipping the run - falling through to the report"
}
elseif ($Plan -eq "quest") {
    # ------------------------------------------------------------ the QUEST plan
    # A Kleinkrieg playthrough across REAL saves and REAL relaunches. Three stages
    # (mercenaries_torture_quest.lua), each typed in as merc_torture_quest_auto; the Lua side
    # dispatches on the TortureStage stamp in the loaded save, so the SAME command runs stage
    # Q1 on a fresh save and Q2/Q3 on the ones the previous stage wrote. Loop: wait for either
    # "SAVED - awaiting reload" or "COMPLETE", and on SAVED relaunch, press Continue, re-arm
    # merc_dev (the dev gate died with the old process) and type the command again.
    $questDone  = $false
    $relaunches = 0
    $stage      = 0
    while (-not $questDone) {
        $stage++
        if (-not (Focus-Game)) {
            Write-Output "[harness] FAIL: cannot focus the game to start quest stage $stage"
            break
        }
        Arm-DevCommands
        Write-Output ("[harness] quest stage " + $stage + ": merc_torture_quest_auto")
        $script:TortureStarted = $false
        Start-Torture "merc_torture_quest_auto" "=== torture QUEST plan"
        if (-not $script:TortureStarted) {
            Write-Output "[harness] quest stage $stage never began - not waiting out a run that never started"
            break
        }
        Write-Output ("[harness] waiting up to " + $QuestTimeout + "s for SAVED or COMPLETE")
        $rq = Wait-LogAny "[Torture] SAVED - awaiting reload" "[Torture] COMPLETE" $QuestTimeout
        if ($rq -eq "[Torture] COMPLETE") {
            Write-Output "[harness] the quest plan reached COMPLETE"
            $questDone = $true
            break
        }
        if ($rq -eq "GAME_DIED") {
            Write-Output "[harness] GAME DIED during quest stage $stage - collecting what there is"
            break
        }
        if ($null -eq $rq) {
            Write-Output "[harness] FAIL: quest stage $stage neither saved nor completed inside $QuestTimeout s"
            break
        }
        # ---- SAVED: relaunch and Continue onto the save the stage just wrote ----
        if ($relaunches -ge $QuestMaxRelaunches) {
            Write-Output "[harness] FAIL: the quest plan asked for more than $QuestMaxRelaunches relaunch(es) - stopping"
            break
        }
        # A save FILE must exist before a relaunch can resume it: Game.QuickSave produced
        # nothing for five runs of the campaign (airborne player) and phase B silently starved.
        # A silent save failure has to be a loud harness failure, not a starved next stage.
        $fresh = $null
        $deadline = (Get-Date).AddSeconds(45)
        while ((Get-Date) -lt $deadline -and -not $fresh) {
            $fresh = Get-ChildItem $SaveDir -Filter *.whs -ErrorAction SilentlyContinue |
                     Where-Object { $_.LastWriteTime -gt $t0 } |
                     Sort-Object LastWriteTime -Descending | Select-Object -First 1
            if (-not $fresh) { Start-Sleep -Seconds 3 }
        }
        if (-not $fresh) {
            Write-Output "[harness] FAIL: no save file written this run - the next quest stage is impossible"
            break
        }
        Write-Output ("[harness] fresh save on disk: " + $fresh.Name + " (" + $fresh.LastWriteTime.ToString("HH:mm:ss") + ")")
        Write-Output "[harness] letting the save settle, then relaunching to Continue"
        Start-Sleep -Seconds 10
        Launch-GameToMenu
        $relaunches++
        Invoke-ContinueFromMenu
        if (-not $script:ContinueLoaded) {
            Write-Output "[harness] FAIL: could not drive Continue - the quest plan cannot go on"
            break
        }
    }
    Write-Output ("[harness] quest run: " + $stage + " stage(s) attempted, " + $relaunches + " relaunch(es)")
    Start-Sleep -Seconds 6
    Get-Process KingdomCome -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
}
elseif ($Plan -ne "campaign") {
    # ------------------------------------------------------------ the FIELD plan
    # Typed into the console rather than pressed: the field plan is deliberately not on any
    # F-key (see the release policy), and typing is immune to whatever else owns F8 on this
    # machine. One session, no save, no phase B - the plan quits the game itself when done.
    if (-not (Focus-Game)) {
        Write-Output "[harness] FAIL: cannot focus the game to start the field plan"
        Get-Process KingdomCome -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    } else {
        Arm-DevCommands
        $fieldCmd = "merc_torture_field_auto"
        if ($Plan -eq "field_aggro") { $fieldCmd = "merc_torture_field_aggro_auto" }
        Start-Torture $fieldCmd "=== torture FIELD plan"
        if ($script:TortureStarted) {
            Write-Output ("[harness] waiting up to " + $FieldTimeout + "s for [Torture] COMPLETE")
            $rf = Wait-LogAny "[Torture] COMPLETE" "" $FieldTimeout
            if ($rf -eq "GAME_DIED") { Write-Output "[harness] GAME DIED during the field plan" }
            elseif ($null -eq $rf)   { Write-Output "[harness] FAIL: the field plan never completed inside $FieldTimeout s" }
        }
    }
    Start-Sleep -Seconds 6
    Get-Process KingdomCome -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
}
elseif ($Scenario -ne "") {
    # ------------------------------------------------------------ scenario probe (F7)
    if (-not (Focus-Game)) {
        Write-Output "[harness] FAIL: cannot focus the game to start the probe"
        Get-Process KingdomCome -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        $reportOnly = $true
    } else {
        Arm-DevCommands
        $probeCmd = "merc_torture_probe"
        if ($ScenarioMap[$Scenario].ContainsKey("Aggro") -and $ScenarioMap[$Scenario].Aggro) {
            $probeCmd = "merc_torture_probe_aggro"
        }
        Write-Output "[harness] scenario probe: $probeCmd"
        Start-Torture $probeCmd "=== scenario probe"
        if ($script:TortureStarted) {
            $rp = Wait-LogAny "[Torture] COMPLETE" "" 900
            if ($rp -eq "GAME_DIED") { Write-Output "[harness] GAME DIED during the probe" }
            elseif ($null -eq $rp)   { Write-Output "[harness] FAIL: probe never completed" }
        }
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
Arm-DevCommands
Write-Output "[harness] torture campaign: merc_torture_auto"
$r = "NEVER_STARTED"
Start-Torture "merc_torture_auto" "=== torture campaign"
if ($script:TortureStarted) {
    $r = Wait-LogAny "[Torture] SAVED - awaiting reload" "[Torture] COMPLETE" 800
}
if ($r -eq "NEVER_STARTED") {
    Write-Output "[harness] phase A never began - nothing to verify, and no relaunch is worth burning on it"
} elseif ($r -eq "GAME_DIED") {
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
    # $SaveDir is resolved once near the top now (-SaveFile needs the same folder).
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
        # Phase B is armed by running merc_torture_auto a SECOND time (it never self-arms -
        # see mercenaries_torture.lua): TortureStart sees the stage stamp in the loaded save
        # and runs the persistence checks instead of a fresh campaign.
        $r0 = Wait-LogAny "Game loaded! Starting the inventory monitor" "" 240
        Start-Sleep -Seconds 12
        $script:TortureStarted = $false
        if (Focus-Game) {
            # Fresh process: the dev gate died with the old one.
            Arm-DevCommands
            Write-Output "[harness] phase B: merc_torture_auto on the stamped save"
            Start-Torture "merc_torture_auto" "=== phase B:"
        }
        if ($script:TortureStarted) {
            Write-Output "[harness] waiting for phase B verdicts..."
            $r2 = Wait-LogAny "[Torture] COMPLETE" "" 420
            if ($r2 -eq "GAME_DIED") { Write-Output "[harness] GAME DIED during phase B" }
            elseif ($null -eq $r2)   { Write-Output "[harness] FAIL: phase B never completed (wrong save resumed?)" }
        } else {
            Write-Output "[harness] FAIL: phase B never armed - the stamp may not be in the resumed save"
        }
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
        # Same arming as the relaunch path: phase B never self-arms, so it has to be asked
        # for. The keystroke-reload path used to just wait here and would have waited for
        # ever. merc_dev survives in this process, but running it again is free.
        Start-Sleep -Seconds 10
        $script:TortureStarted = $false
        if (Focus-Game) {
            Arm-DevCommands
            Write-Output "[harness] phase B: merc_torture_auto on the stamped save"
            Start-Torture "merc_torture_auto" "=== phase B:"
        }
        if ($script:TortureStarted) {
            Write-Output "[harness] waiting for phase B verdicts..."
            $r2 = Wait-LogAny "[Torture] COMPLETE" "" 300
            if ($r2 -eq "GAME_DIED") { Write-Output "[harness] GAME DIED during phase B" }
            elseif ($null -eq $r2)   { Write-Output "[harness] FAIL: phase B never completed" }
        } else {
            Write-Output "[harness] FAIL: phase B never armed after the in-field reload"
        }
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
# A relaunch rotates kcd.log into LogBackups, taking that session's verdicts with it - report
# across EVERY backup written since this run began, oldest first, then the current log. The
# campaign relaunches once and so has exactly one; the quest plan relaunches up to four times
# and would otherwise lose every stage but the last two.
$reportLogs = @()
Get-ChildItem (Join-Path $GameDir "LogBackups") -Filter *.log -ErrorAction SilentlyContinue |
    Where-Object { $_.LastWriteTime -gt $t0 } |
    Sort-Object LastWriteTime | ForEach-Object { $script:reportLogs += $_.FullName }
$reportLogs += $Log
# Three passes over the same lines so each one appears exactly once, in the block where it is
# useful: verdicts first, then the measurements, then the POS trace as a COUNT. The trace is
# the field plan's per-merc position dump - deliberately enormous, and what turns "the follow
# test failed" into "this man peeled off at t=140" - so it is left in kcd.log to be read
# there rather than reprinted here.
$posLines = 0
foreach ($rl in $reportLogs) {
    Select-String -Path $rl -Pattern "\[Torture\]" -ErrorAction SilentlyContinue | ForEach-Object {
        if ($_.Line -match "\[Torture\] POS ") { $script:posLines++ }
        elseif ($_.Line -notmatch "\[Torture\] INFO ") { $_.Line }
    }
}

# Every measurement the run took, in one block: the verdicts above say WHAT passed, these say
# by how much - distances, gang gaps, loot counts, raid timings.
Write-Output ""
Write-Output "===== MEASUREMENTS (INFO) ====="
foreach ($rl in $reportLogs) {
    Select-String -Path $rl -Pattern "\[Torture\] INFO " -ErrorAction SilentlyContinue | ForEach-Object { $_.Line }
}
Write-Output ""
Write-Output ("[harness] " + $posLines + " [Torture] POS line(s) of per-merc position trace in the log(s)")

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
