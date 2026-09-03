# Closed-loop bench harness. Launches KCD2, navigates the main menu with scancode
# keystrokes (counts from the author's recipe), loads the bench save, then runs the
# bench through the devmode console: merc_dev (arms the dev command set - refused
# outside -devmode) + merc_bench_bindkeys (restores the session F-key triggers), then
# presses the F-key (merc_bench_auto QUITS the game when done) and parses kcd.log for
# the [Bench] results. The mod no longer binds ANY F-key on its own - players kept
# firing the test campaigns by accident - so the console preamble is mandatory.
#
#   powershell -ExecutionPolicy Bypass -File tools\autobench.ps1
#
# The menu recipe (override if the save list shifts):
#   -DownsToLoad 2   downs to reach the load-game entry
#   -DownsToSave 25  downs inside the save list
param(
    [int]$DownsToLoad = 2,
    [int]$DownsToSave = 25,
    [int]$MenuWaitSec = 35,
    [int]$Cores = 0,       # restrict the game to N PHYSICAL cores after load (0 = all).
                           # SMT pairs: N cores = 2N logical processors from CPU 0 up.
    [string]$Key = "f10",  # which bench to fire: f10 = full suite, f8 = per-merc scale ladder
    [string]$ConsoleCmd = "",  # type this into the devmode console instead of pressing $Key -
                               # immune to F-key bind conflicts (videofhotomode et al. own F-keys)
    [switch]$AttachOnly    # game already at the main menu: skip launch+wait
)

$ErrorActionPreference = "Stop"
# Where the game is is a per-machine question - Steam sits under Program Files (x86) on
# one rig and Program Files on another, and a library can be on any drive - so it is
# resolved rather than assumed. See tools\Find-KCD2.ps1; override with KCD2_DIR.
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

function Tap-Key([string]$name, [int]$after = 180) {
    switch ($name) {
        "down"  { [KeySender]::Tap(0x50, $true,  60) }
        "enter" { [KeySender]::Tap(0x1C, $false, 60) }
        "f8"    { [KeySender]::Tap(0x42, $false, 60) }
        "f9"    { [KeySender]::Tap(0x43, $false, 60) }
        "f10"   { [KeySender]::Tap(0x44, $false, 60) }
        "esc"   { [KeySender]::Tap(0x01, $false, 60) }
    }
    Start-Sleep -Milliseconds $after
}

# Focus the game and PROVE it took. Windows denies SetForegroundWindow to background
# processes (foreground lock); a synthetic Alt tap releases it. If the game still does not
# hold focus, ABORT rather than typing menu keys into whatever window does - stray Down/Enter
# keys landing in another application is worse than a failed run.
function Focus-Game {
    $p = Get-Process KingdomCome -ErrorAction SilentlyContinue
    if (-not $p -or $p.MainWindowHandle -eq 0) {
        Write-Output "[harness] FAIL: no game window to focus"
        exit 1
    }
    for ($try = 0; $try -lt 5; $try++) {
        [KeySender]::Tap(0x38, $false, 30)   # Alt tap releases the foreground lock
        [KeySender]::ShowWindow($p.MainWindowHandle, 9) | Out-Null   # SW_RESTORE
        [KeySender]::SetForegroundWindow($p.MainWindowHandle) | Out-Null
        Start-Sleep -Milliseconds 700
        if ([KeySender]::GetForegroundWindow() -eq $p.MainWindowHandle) {
            Write-Output "[harness] game window focused"
            return
        }
        Start-Sleep -Milliseconds 800
    }
    Write-Output "[harness] FAIL: could not bring the game to the foreground - not sending any keys"
    exit 1
}

function Read-LogTailFrom([long]$fromLen) {
    if (-not (Test-Path $Log)) { return "" }
    $len = 0; try { $len = (Get-Item $Log).Length } catch {}
    if ($len -lt $fromLen) { $fromLen = 0 }   # truncated by a relaunch
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

# Only content appended AFTER this call started can satisfy the wait - a marker left in the
# log by a previous run (the -AttachOnly case especially) must not read as fresh success.
function Wait-LogLine([string]$pattern, [int]$timeoutSec, [datetime]$since) {
    $deadline = (Get-Date).AddSeconds($timeoutSec)
    $startLen = 0
    if (Test-Path $Log) { try { $startLen = (Get-Item $Log).Length } catch {} }
    while ((Get-Date) -lt $deadline) {
        if (Test-Path $Log) {
            $len = 0
            try { $len = (Get-Item $Log).Length } catch {}
            if ($len -lt $startLen) { $startLen = 0 }   # log was truncated by a relaunch
            if ($len -gt $startLen) {
                try {
                    $fs = [System.IO.File]::Open($Log, 'Open', 'Read', 'ReadWrite')
                    $fs.Seek($startLen, 'Begin') | Out-Null
                    $sr = New-Object System.IO.StreamReader($fs)
                    $tail = $sr.ReadToEnd()
                    $sr.Close(); $fs.Close()
                    if ($tail.Contains($pattern)) { return $true }
                } catch {}
            }
        }
        Start-Sleep -Seconds 2
    }
    return $false
}

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

$t0 = Get-Date

if (-not $AttachOnly) {
    Get-Process KingdomCome -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 3
    Ensure-SteamAppId
    Write-Output "[harness] launching..."
    # "+exec user.cfg" is OPTIONAL - the engine shrugs at a user.cfg that does not exist, and
    # it is only here so a machine that HAS one gets its settings.
    Start-Process -FilePath $Exe -WorkingDirectory $GameDir -ArgumentList "-devmode","+exec","user.cfg"
    # steam_appid.txt beside the exe ALSO stops steam_api relaunching the game through Steam
    # (which briefly produced TWO instances). Belt and braces: wait for the process count
    # to settle, and if more than one survives, keep the newest - that is the real one.
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
    # Menu-ready detection: no single log marker is reliable across cold/warm launches, but
    # the shape is - the log grows fast through init and goes QUIET once the menu idles.
    # Wait until the log has not grown for 10s (minimum 40s uptime, cap 240s), relaunching
    # the game if it disappears mid-wait (a previous run killing it is exactly what stranded
    # one harness at the menu for five minutes).
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

# Navigation is VERIFIED, not fire-and-forget: the engine prints "Loading saved game" the
# moment a load actually starts, so each attempt waits for that; on a miss it backs out with
# Escape and tries again. Three misses = hard fail with the game killed.
# The success check reads the log from an offset captured BEFORE the keys are sent - a
# previous build snapshotted it AFTER the final Enter and raced the engine's own
# "Loading saved game" line into invisibility, declaring failure over a load that had
# succeeded (and its Escape-retries then re-loaded the save twice more). Success is EITHER
# marker: load-start, or the mod's fully-in-game line.
$loaded = $false
for ($attempt = 1; $attempt -le 3 -and -not $loaded; $attempt++) {
    Focus-Game
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
            Write-Output "[harness] load confirmed"
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
if (-not (Wait-LogLine "Game loaded! Starting the inventory monitor" 240 $t0)) {
    Write-Output "[harness] FAIL: load started but never finished"
    Get-Process KingdomCome -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    exit 1
}
Start-Sleep -Seconds 10

if ($Cores -gt 0) {
    $mask = [int64]0
    for ($i = 0; $i -lt ($Cores * 2); $i++) { $mask = $mask -bor ([int64]1 -shl $i) }
    $g = Get-Process KingdomCome -ErrorAction SilentlyContinue
    if ($g) {
        $g.ProcessorAffinity = [IntPtr]$mask
        Write-Output ("[harness] affinity restricted to " + $Cores + " cores (mask 0x" + $mask.ToString("X") + ")")
    }
}

Focus-Game
$benchLen = 0; try { $benchLen = (Get-Item $Log).Length } catch {}

# Open the devmode console (tilde, scancode 0x29), type one command, run it, close.
# The console PAUSES script timers while open, so close it straight after Enter.
function Send-ConsoleCmd([string]$cmd) {
    Write-Output "[harness] console: $cmd"
    [KeySender]::Tap(0x29, $false, 60); Start-Sleep -Milliseconds 700
    [KeySender]::TypeText($cmd, 30); Start-Sleep -Milliseconds 400
    Tap-Key "enter" 600
    [KeySender]::Tap(0x29, $false, 60); Start-Sleep -Milliseconds 400
}

# The bench commands are dev-gated now: merc_dev arms them (only in a -devmode launch,
# which this harness always uses), merc_bench_bindkeys puts the F-key triggers back.
Send-ConsoleCmd "merc_dev"
Send-ConsoleCmd "merc_bench_bindkeys"

if ($ConsoleCmd -ne "") {
    Send-ConsoleCmd $ConsoleCmd
} else {
    Write-Output "[harness] $Key - bench starts (auto-quit at the end)"
    Tap-Key $Key 500
}

# Prove the bench actually armed. Nothing else prints "[Bench]", so 30s with no line
# means the trigger never landed - fall back to the F-key once before giving up.
$armed = $false
$deadline = (Get-Date).AddSeconds(30)
while ((Get-Date) -lt $deadline -and -not $armed) {
    if ((Read-LogTailFrom $benchLen).Contains("[Bench]")) { $armed = $true } else { Start-Sleep -Seconds 2 }
}
if (-not $armed) {
    Write-Output "[harness] WARN: no [Bench] line 30s after trigger - falling back to $Key"
    Focus-Game
    Tap-Key $Key 500
}

if (-not (Wait-LogLine "[Bench] COMPLETE" 900 $t0)) {
    Write-Output "[harness] FAIL: bench never completed; killing the game"
    Get-Process KingdomCome -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    exit 1
}
Start-Sleep -Seconds 6
Get-Process KingdomCome -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

Write-Output ""
Write-Output "===== LOADED SAVE ====="
Select-String -Path $Log -Pattern "Loading saved game" | Select-Object -First 1 | ForEach-Object { $_.Line }
Write-Output "===== BENCH OUTPUT ====="
Select-String -Path $Log -Pattern "\[Bench\]" | ForEach-Object { $_.Line }
