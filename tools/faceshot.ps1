# Look at a mercenary's face.
#
# Launches KCD2, loads the bench save, hires three raw foot, then turns the camera through a
# full circle taking a screenshot at every step. The men follow the player, so turning to
# face them is what puts a face in frame; a burst around the circle is cheaper and far more
# reliable than trying to compute one correct heading.
#
#   powershell -ExecutionPolicy Bypass -File tools\faceshot.ps1 -OutDir <dir>
#
# Menu navigation, focus handling and the console helper are lifted from tools\autobench.ps1
# and behave the same way - see the notes there. The difference at the end: this harness does
# NOT kill the game. A face is judged by eye, and leaving it standing lets you take more
# shots by hand (or re-run with -AttachOnly).
param(
    [int]$DownsToLoad = 2,
    [int]$DownsToSave = 25,
    [string]$OutDir = "",
    [string]$Hire = "merc_hire_weak 3",
    [int]$Steps = 8,           # screenshots around the circle
    [int]$SettleSec = 12,      # let the men walk into shot before the first frame
    [switch]$HideOthers,       # merc_hide_others: strip the town out of the background
    [switch]$AttachOnly,       # game already at the main menu
    [switch]$InGame            # game already loaded and standing in the world: only hire+shoot
)

$ErrorActionPreference = "Stop"
$GameDir = & (Join-Path $PSScriptRoot "Find-KCD2.ps1")
if (-not $GameDir) {
    Write-Output "[faceshot] FAIL: Kingdom Come Deliverance 2 not found on this machine."
    Write-Output "[faceshot]        set KCD2_DIR=D:\path\to\KingdomComeDeliverance2"
    exit 1
}
$Exe = Join-Path $GameDir "Bin\Win64MasterMasterSteamPGO\KingdomCome.exe"
$Log = Join-Path $GameDir "kcd.log"
if ($OutDir -eq "") { $OutDir = Join-Path $env:TEMP ("kcd2_faceshot_" + (Get-Date -Format "yyyyMMdd_HHmmss")) }
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
Write-Output "[faceshot] game: $GameDir"
Write-Output "[faceshot] out:  $OutDir"

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class Sender {
    [StructLayout(LayoutKind.Sequential)]
    struct INPUT { public uint type; public INPUTUNION u; }
    [StructLayout(LayoutKind.Explicit)]
    struct INPUTUNION {
        [FieldOffset(0)] public MOUSEINPUT mi;
        [FieldOffset(0)] public KEYBDINPUT ki;
    }
    [StructLayout(LayoutKind.Sequential)]
    struct MOUSEINPUT { public int dx; public int dy; public uint mouseData; public uint dwFlags; public uint time; public IntPtr dwExtraInfo; public ulong pad; }
    [StructLayout(LayoutKind.Sequential)]
    struct KEYBDINPUT { public ushort wVk; public ushort wScan; public uint dwFlags; public uint time; public IntPtr dwExtraInfo; public ulong pad; }
    [DllImport("user32.dll", SetLastError=true)] static extern uint SendInput(uint n, INPUT[] inputs, int size);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

    const uint KEYEVENTF_SCANCODE = 0x8; const uint KEYEVENTF_KEYUP = 0x2; const uint KEYEVENTF_EXTENDEDKEY = 0x1;
    const uint KEYEVENTF_UNICODE = 0x4; const uint MOUSEEVENTF_MOVE = 0x0001;

    static INPUT K(ushort scan, uint flags) {
        var i = new INPUT(); i.type = 1; i.u.ki = new KEYBDINPUT{ wScan = scan, dwFlags = flags }; return i;
    }
    public static void Tap(ushort scan, bool extended, int holdMs) {
        uint fl = KEYEVENTF_SCANCODE | (extended ? KEYEVENTF_EXTENDEDKEY : 0);
        SendInput(1, new INPUT[]{ K(scan, fl) }, Marshal.SizeOf(typeof(INPUT)));
        System.Threading.Thread.Sleep(holdMs);
        SendInput(1, new INPUT[]{ K(scan, fl|KEYEVENTF_KEYUP) }, Marshal.SizeOf(typeof(INPUT)));
    }
    public static void TypeText(string s, int perCharMs) {
        foreach (char c in s) {
            SendInput(1, new INPUT[]{ K((ushort)c, KEYEVENTF_UNICODE) }, Marshal.SizeOf(typeof(INPUT)));
            System.Threading.Thread.Sleep(20);
            SendInput(1, new INPUT[]{ K((ushort)c, KEYEVENTF_UNICODE|KEYEVENTF_KEYUP) }, Marshal.SizeOf(typeof(INPUT)));
            System.Threading.Thread.Sleep(perCharMs);
        }
    }
    // Raw relative mouse motion. The game reads raw input, so absolute cursor placement does
    // nothing to the camera; only MOUSEEVENTF_MOVE deltas turn the player. Sent in small
    // increments because one large delta gets clamped by the game's own turn-rate limiter.
    public static void Turn(int dx, int chunks, int gapMs) {
        int per = dx / chunks;
        for (int i = 0; i < chunks; i++) {
            var m = new INPUT(); m.type = 0;
            m.u.mi = new MOUSEINPUT{ dx = per, dy = 0, dwFlags = MOUSEEVENTF_MOVE };
            SendInput(1, new INPUT[]{ m }, Marshal.SizeOf(typeof(INPUT)));
            System.Threading.Thread.Sleep(gapMs);
        }
    }
}
"@

function Tap-Key([string]$name, [int]$after = 180) {
    switch ($name) {
        "down"  { [Sender]::Tap(0x50, $true,  60) }
        "enter" { [Sender]::Tap(0x1C, $false, 60) }
        "esc"   { [Sender]::Tap(0x01, $false, 60) }
    }
    Start-Sleep -Milliseconds $after
}

function Focus-Game {
    $p = Get-Process KingdomCome -ErrorAction SilentlyContinue
    if (-not $p -or $p.MainWindowHandle -eq 0) { Write-Output "[faceshot] FAIL: no game window to focus"; exit 1 }
    for ($try = 0; $try -lt 5; $try++) {
        [Sender]::Tap(0x38, $false, 30)
        [Sender]::ShowWindow($p.MainWindowHandle, 9) | Out-Null
        [Sender]::SetForegroundWindow($p.MainWindowHandle) | Out-Null
        Start-Sleep -Milliseconds 700
        if ([Sender]::GetForegroundWindow() -eq $p.MainWindowHandle) { return }
        Start-Sleep -Milliseconds 800
    }
    Write-Output "[faceshot] FAIL: could not bring the game to the foreground - not sending any input"
    exit 1
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

function Wait-LogLine([string]$pattern, [int]$timeoutSec) {
    $deadline = (Get-Date).AddSeconds($timeoutSec)
    $startLen = 0
    if (Test-Path $Log) { try { $startLen = (Get-Item $Log).Length } catch {} }
    while ((Get-Date) -lt $deadline) {
        if ((Read-LogTailFrom $startLen).Contains($pattern)) { return $true }
        Start-Sleep -Seconds 2
    }
    return $false
}

function Ensure-SteamAppId {
    $f = Join-Path $GameDir "Bin\Win64MasterMasterSteamPGO\steam_appid.txt"
    if (-not (Test-Path $f)) { try { [System.IO.File]::WriteAllText($f, "1771300") } catch {} }
}

function Send-ConsoleCmd([string]$cmd) {
    Write-Output "[faceshot] console: $cmd"
    [Sender]::Tap(0x29, $false, 60); Start-Sleep -Milliseconds 700
    [Sender]::TypeText($cmd, 30); Start-Sleep -Milliseconds 400
    Tap-Key "enter" 600
    [Sender]::Tap(0x29, $false, 60); Start-Sleep -Milliseconds 400
}

function Shoot([string]$tag) {
    $path = Join-Path $OutDir ($tag + ".png")
    $b = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    $bmp = New-Object System.Drawing.Bitmap $b.Width, $b.Height
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen($b.Location, [System.Drawing.Point]::Empty, $b.Size)
    $g.Dispose(); $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
    Write-Output "[faceshot] shot: $path"
}

# ---------------------------------------------------------------- launch + load

if (-not $InGame) {
    if (-not $AttachOnly) {
        Get-Process KingdomCome -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 3
        Ensure-SteamAppId
        Write-Output "[faceshot] launching..."
        Start-Process -FilePath $Exe -WorkingDirectory $GameDir -ArgumentList "-devmode","+exec","user.cfg"
        Start-Sleep -Seconds 12
        $up0 = Get-Date; $lastLen = -1; $quietSince = Get-Date
        while ($true) {
            $g = @(Get-Process KingdomCome -ErrorAction SilentlyContinue)
            if ($g.Count -eq 0) {
                Write-Output "[faceshot] game vanished during init - relaunching"
                Ensure-SteamAppId
                Start-Process -FilePath $Exe -WorkingDirectory $GameDir -ArgumentList "-devmode","+exec","user.cfg"
                Start-Sleep -Seconds 12; $up0 = Get-Date; $lastLen = -1; $quietSince = Get-Date; continue
            }
            $len = 0; try { $len = (Get-Item $Log).Length } catch {}
            if ($len -ne $lastLen) { $lastLen = $len; $quietSince = Get-Date }
            if (((Get-Date) - $up0).TotalSeconds -ge 40 -and ((Get-Date) - $quietSince).TotalSeconds -ge 10) {
                Write-Output "[faceshot] log quiet - menu should be idle"; break
            }
            if (((Get-Date) - $up0).TotalSeconds -ge 240) { Write-Output "[faceshot] WARN: init never went quiet"; break }
            Start-Sleep -Seconds 2
        }
    }

    $loaded = $false
    for ($attempt = 1; $attempt -le 3 -and -not $loaded; $attempt++) {
        Focus-Game
        $navLen = 0; try { $navLen = (Get-Item $Log).Length } catch {}
        Write-Output "[faceshot] menu attempt ${attempt}"
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
                Write-Output "[faceshot] load confirmed"; $loaded = $true
            } else { Start-Sleep -Seconds 2 }
        }
        if (-not $loaded) {
            Write-Output "[faceshot] no load detected - Escape and retry"
            Focus-Game; Tap-Key "esc" 900; Tap-Key "esc" 900; Tap-Key "esc" 1500
        }
    }
    if (-not $loaded) { Write-Output "[faceshot] FAIL: navigation never started a load"; Shoot "FAIL_menu"; exit 1 }

    Write-Output "[faceshot] waiting for the save to finish loading..."
    if (-not (Wait-LogLine "Game loaded! Starting the inventory monitor" 300)) {
        Write-Output "[faceshot] FAIL: load started but never finished"; Shoot "FAIL_load"; exit 1
    }
    Start-Sleep -Seconds 10
}

# ---------------------------------------------------------------- hire + shoot

Focus-Game
$hireLen = 0; try { $hireLen = (Get-Item $Log).Length } catch {}
if ($HideOthers) { Send-ConsoleCmd "merc_hide_others" }
Send-ConsoleCmd $Hire
Start-Sleep -Seconds $SettleSec
Shoot "00_after_hire"

# One full circle. 8 steps of 45 degrees by default: whatever the men's heading, one of these
# looks straight at them. The per-step delta is a guess at mouse sensitivity and is corrected
# by eye from the frames, not computed - the game's sensitivity setting is per-machine.
$per = [int](2600 / $Steps)
for ($s = 1; $s -le $Steps; $s++) {
    [Sender]::Turn($per, 12, 25)
    Start-Sleep -Milliseconds 1200
    Shoot ("{0:d2}_turn" -f $s)
}

Write-Output ""
Write-Output "===== log since hire ====="
$tail = Read-LogTailFrom $hireLen
$tail -split "`n" | Where-Object { $_ -match "Mercenaries|Error|Warning|f_head|f_hair|merc_f01|Skin|skeleton|attachment" } |
    Select-Object -First 80 | ForEach-Object { $_.TrimEnd() }
Write-Output ""
Write-Output "[faceshot] game left running. Screenshots: $OutDir"
