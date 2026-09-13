# Closed-loop wall lab. Launches KCD2, presses Continue at the main menu (the newest save),
# waits for the world, taps F11 (merc_wall_lab_auto, bound at mod load), waits for the lab
# to report and quit, then prints every [NavLab] line the run wrote.
#
#   powershell -ExecutionPolicy Bypass -File tools\navlab.ps1
#
# Menu recipe is the torture harness's phase-B one: Continue is the top item, so a single
# Enter loads the newest save with no list navigation at all. The lab finds its own lane
# from wherever that leaves the player, and reports "no clear lane" and quits if it cannot.
param(
    [int]$LoadWaitSec = 300,
    [int]$RunWaitSec  = 1500,
    [switch]$AttachOnly
)

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
        "enter" { [KeySender]::Tap(0x1C, $false, 60) }
        "f11"   { [KeySender]::Tap(0x57, $false, 60) }
        "np9"   { [KeySender]::Tap(0x49, $false, 60) }
        "esc"   { [KeySender]::Tap(0x01, $false, 60) }
    }
    Start-Sleep -Milliseconds $after
}

function Focus-Game {
    $p = Get-Process KingdomCome -ErrorAction SilentlyContinue
    if (-not $p -or $p.MainWindowHandle -eq 0) { Write-Output "[navlab] no game window to focus"; return $false }
    for ($try = 0; $try -lt 5; $try++) {
        [KeySender]::Tap(0x38, $false, 30)
        [KeySender]::ShowWindow($p.MainWindowHandle, 9) | Out-Null
        [KeySender]::SetForegroundWindow($p.MainWindowHandle) | Out-Null
        Start-Sleep -Milliseconds 700
        if ([KeySender]::GetForegroundWindow() -eq $p.MainWindowHandle) { return $true }
        Start-Sleep -Milliseconds 800
    }
    Write-Output "[navlab] could not bring the game to the foreground"
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
        $tail = $sr.ReadToEnd(); $sr.Close(); $fs.Close()
        return $tail
    } catch { return "" }
}

function Wait-LogAny([string]$p1, [string]$p2, [int]$timeoutSec, [long]$fromLen) {
    $deadline = (Get-Date).AddSeconds($timeoutSec)
    while ((Get-Date) -lt $deadline) {
        $tail = Read-LogTailFrom $fromLen
        if ($tail.Contains($p1)) { return $p1 }
        if ($p2 -ne "" -and $tail.Contains($p2)) { return $p2 }
        $g = @(Get-Process KingdomCome -ErrorAction SilentlyContinue)
        if ($g.Count -eq 0) { return "GAME_DIED" }
        Start-Sleep -Seconds 2
    }
    return $null
}

function Launch-GameToMenu {
    Get-Process KingdomCome -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 3
    Write-Output "[navlab] launching..."
    Start-Process -FilePath $Exe -WorkingDirectory $GameDir -ArgumentList "-devmode","+exec","user.cfg"
    Start-Sleep -Seconds 12
    for ($try = 0; $try -lt 6; $try++) {
        $procs = @(Get-Process KingdomCome -ErrorAction SilentlyContinue)
        if ($procs.Count -le 1) { break }
        Start-Sleep -Seconds 5
        $procs = @(Get-Process KingdomCome -ErrorAction SilentlyContinue | Sort-Object StartTime)
        if ($procs.Count -gt 1) {
            for ($i = 0; $i -lt $procs.Count - 1; $i++) { Stop-Process -Id $procs[$i].Id -Force -ErrorAction SilentlyContinue }
        }
    }
    $up0 = Get-Date; $lastLen = -1; $quietSince = Get-Date
    while ($true) {
        $g = @(Get-Process KingdomCome -ErrorAction SilentlyContinue)
        if ($g.Count -eq 0) {
            Write-Output "[navlab] game vanished during init - relaunching"
            Start-Process -FilePath $Exe -WorkingDirectory $GameDir -ArgumentList "-devmode","+exec","user.cfg"
            Start-Sleep -Seconds 12; $up0 = Get-Date; $lastLen = -1; $quietSince = Get-Date
            continue
        }
        $len = 0; try { $len = (Get-Item $Log).Length } catch {}
        if ($len -ne $lastLen) { $lastLen = $len; $quietSince = Get-Date }
        $upSecs = ((Get-Date) - $up0).TotalSeconds
        $quietSecs = ((Get-Date) - $quietSince).TotalSeconds
        if ($upSecs -ge 40 -and $quietSecs -ge 10) { Write-Output "[navlab] menu idle"; break }
        if ($upSecs -ge 240) { Write-Output "[navlab] WARN: init never went quiet - proceeding"; break }
        Start-Sleep -Seconds 2
    }
}

$runStartLen = 0; try { $runStartLen = (Get-Item $Log).Length } catch {}
if (-not $AttachOnly) { Launch-GameToMenu; $runStartLen = 0 }

# ---------------------------------------------------------------- Continue
$loaded = $false
for ($attempt = 1; $attempt -le 3 -and -not $loaded; $attempt++) {
    if (-not (Focus-Game)) { break }
    $navLen = 0; try { $navLen = (Get-Item $Log).Length } catch {}
    Write-Output "[navlab] continue attempt ${attempt}: enter"
    Tap-Key "enter" 2500
    $deadline = (Get-Date).AddSeconds(30)
    while ((Get-Date) -lt $deadline -and -not $loaded) {
        $tail = Read-LogTailFrom $navLen
        if ($tail.Contains("Loading saved game")) {
            $m = [regex]::Match($tail, "Loading saved game '[^']*/([^/']+\.whs)'")
            Write-Output ("[navlab] loading " + $(if ($m.Success) { $m.Groups[1].Value } else { "?" }))
            $loaded = $true
        } else { Start-Sleep -Seconds 2 }
    }
    if (-not $loaded) { Focus-Game | Out-Null; Tap-Key "esc" 900 }
}
if (-not $loaded) {
    Write-Output "[navlab] FAIL: Continue never started a load"
    Get-Process KingdomCome -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    exit 1
}
$r = Wait-LogAny "Game loaded! Starting the inventory monitor" "" $LoadWaitSec $navLen
if ($r -ne "Game loaded! Starting the inventory monitor") {
    Write-Output "[navlab] FAIL: load never finished ($r)"
    Get-Process KingdomCome -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    exit 1
}
Write-Output "[navlab] world up - settling"
Start-Sleep -Seconds 15

# ---------------------------------------------------------------- F11
$labLen = 0; try { $labLen = (Get-Item $Log).Length } catch {}
if (-not (Focus-Game)) {
    Write-Output "[navlab] FAIL: cannot focus the game to start the lab"
    Get-Process KingdomCome -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    exit 1
}
Tap-Key "np9" 800
$started = Wait-LogAny "[NavLab] locating" "" 40 $labLen
if ($null -eq $started) {
    Write-Output "[navlab] lab did not start - refocusing and tapping F11 again"
    Focus-Game | Out-Null
    Tap-Key "np9" 800
    $started = Wait-LogAny "[NavLab] locating" "" 40 $labLen
}
if ($started -ne "[NavLab] locating") {
    Write-Output "[navlab] FAIL: lab never started ($started)"
} else {
    Write-Output "[navlab] locating a lane, then running..."
    $r = Wait-LogAny "[NavLab] auto-quit" "" $RunWaitSec $labLen
    if ($r -eq "GAME_DIED") { Write-Output "[navlab] game died mid-run - collecting what there is" }
    elseif ($null -eq $r) { Write-Output "[navlab] FAIL: run never reported within $RunWaitSec s" }
}
Start-Sleep -Seconds 4
Get-Process KingdomCome -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

Write-Output ""
Write-Output "================ [NavLab] output ================"
$all = Read-LogTailFrom $labLen
foreach ($line in ($all -split "`n")) {
    if ($line.Contains("[NavLab]") -or $line.Contains("[TestNpc]") -or $line.Contains("Lua Error") -or $line.Contains("[Error]")) {
        Write-Output $line.TrimEnd()
    }
}
