# Look-tuning harness for the battle command interface (docs/ui.md).
#
# -Setup launches KCD2 and loads a save. That part alone needs the keyboard, because the
# save has to be picked from the main menu, and it takes the foreground while it does it.
# EVERYTHING after that is keyboard-free: the mod arms its own poll of merc_ui_ctl.cfg in
# the game root (see mercenaries_cmdui.lua), so -Send and -Shot never touch focus or input.
# Launches windowed so the game does not take over a whole display.
#
#   powershell -ExecutionPolicy Bypass -File tools\uitune.ps1 -Setup
#   powershell -ExecutionPolicy Bypass -File tools\uitune.ps1 -Shot out.jpg
#   powershell -ExecutionPolicy Bypass -File tools\uitune.ps1 -Send "merc_cmd_lay sTag 11"
param(
    [switch]$Setup,
    [switch]$Bootstrap,
    [string]$Send = "",
    [string]$Shot = "",
    [int]$DownsToLoad = 2,
    [int]$DownsToSave = 1        # latecamp: 50 mercs, open camp - a busy backdrop
)

$ErrorActionPreference = "Stop"
$GameDir  = "C:\Program Files\Steam\steamapps\common\KingdomComeDeliverance2"
$Exe      = Join-Path $GameDir "Bin\Win64MasterMasterSteamPGO\KingdomCome.exe"
$Log      = Join-Path $GameDir "kcd.log"
$Ctl      = Join-Path $GameDir "merc_ui_ctl.cfg"
$ShotDir  = "C:\Users\Alex\Saved Games\kingdomcome2\screenshots"

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class K {
    [StructLayout(LayoutKind.Sequential)]
    struct INPUT { public uint type; public KEYBDINPUT ki; public ulong pad; }
    [StructLayout(LayoutKind.Sequential)]
    struct KEYBDINPUT { public ushort wVk; public ushort wScan; public uint dwFlags; public uint time; public IntPtr dwExtraInfo; }
    [DllImport("user32.dll", SetLastError=true)] static extern uint SendInput(uint n, INPUT[] inputs, int size);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    const uint SC = 0x8; const uint UP = 0x2; const uint EXT = 0x1;
    static void One(ushort scan, bool ext, bool up) {
        uint fl = SC | (ext ? EXT : 0) | (up ? UP : 0);
        var a = new INPUT[]{ new INPUT{ type=1, ki=new KEYBDINPUT{ wScan=scan, dwFlags=fl } } };
        SendInput(1, a, Marshal.SizeOf(typeof(INPUT)));
    }
    public static void Tap(ushort scan, bool ext, int hold) {
        One(scan, ext, false); System.Threading.Thread.Sleep(hold); One(scan, ext, true);
    }
    public static void ShiftTap(ushort scan, int hold) {
        One(0x2A, false, false); System.Threading.Thread.Sleep(15);
        One(scan, false, false); System.Threading.Thread.Sleep(hold); One(scan, false, true);
        System.Threading.Thread.Sleep(15); One(0x2A, false, true);
    }
}
"@

$SCAN = @{
 'a'=0x1E;'b'=0x30;'c'=0x2E;'d'=0x20;'e'=0x12;'f'=0x21;'g'=0x22;'h'=0x23;'i'=0x17;'j'=0x24
 'k'=0x25;'l'=0x26;'m'=0x32;'n'=0x31;'o'=0x18;'p'=0x19;'q'=0x10;'r'=0x13;'s'=0x1F;'t'=0x14
 'u'=0x16;'v'=0x2F;'w'=0x11;'x'=0x2D;'y'=0x15;'z'=0x2C
 '1'=0x02;'2'=0x03;'3'=0x04;'4'=0x05;'5'=0x06;'6'=0x07;'7'=0x08;'8'=0x09;'9'=0x0A;'0'=0x0B
 ' '=0x39;'-'=0x0C;'.'=0x34
}

function Type-Text([string]$text) {
    foreach ($ch in $text.ToCharArray()) {
        $c = [string]$ch
        if ($c -eq '_') { [K]::ShiftTap(0x0C, 25) }
        elseif ($SCAN.ContainsKey($c)) { [K]::Tap([uint16]$SCAN[$c], $false, 25) }
        Start-Sleep -Milliseconds 18
    }
}

function Focus-Game {
    $p = Get-Process KingdomCome -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $p -or $p.MainWindowHandle -eq 0) { return $false }
    for ($t = 0; $t -lt 5; $t++) {
        [K]::Tap(0x38, $false, 30)
        [K]::ShowWindow($p.MainWindowHandle, 9) | Out-Null
        [K]::SetForegroundWindow($p.MainWindowHandle) | Out-Null
        Start-Sleep -Milliseconds 700
        if ([K]::GetForegroundWindow() -eq $p.MainWindowHandle) { return $true }
        Start-Sleep -Milliseconds 800
    }
    return $false
}

function Console-Cmd([string]$cmd) {
    [K]::Tap(0x29, $false, 60)          # grave/tilde opens the console
    Start-Sleep -Milliseconds 500
    Type-Text $cmd
    Start-Sleep -Milliseconds 200
    [K]::Tap(0x1C, $false, 60)          # enter
    Start-Sleep -Milliseconds 400
    [K]::Tap(0x29, $false, 60)          # close it again
    Start-Sleep -Milliseconds 400
}

# ------------------------------------------------------------------ -Send
if ($Send -ne "") {
    Set-Content -Path $Ctl -Value $Send -Encoding ascii
    Write-Output "[uitune] sent: $Send"
    Start-Sleep -Seconds 2
    Set-Content -Path $Ctl -Value "" -Encoding ascii    # so it does not re-run every poll
    exit 0
}

# ------------------------------------------------------------------ -Shot
if ($Shot -ne "") {
    $before = @(Get-ChildItem $ShotDir -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime)
    $beforeNewest = if ($before.Count) { $before[-1].LastWriteTime } else { [datetime]::MinValue }
    Set-Content -Path $Ctl -Value "r_GetScreenShot 1" -Encoding ascii
    Start-Sleep -Seconds 3
    Set-Content -Path $Ctl -Value "" -Encoding ascii
    for ($i = 0; $i -lt 10; $i++) {
        $f = @(Get-ChildItem $ShotDir -File -ErrorAction SilentlyContinue |
               Where-Object { $_.LastWriteTime -gt $beforeNewest } | Sort-Object LastWriteTime)
        if ($f.Count) {
            Copy-Item $f[-1].FullName $Shot -Force
            Write-Output ("[uitune] shot -> " + $Shot + " (" + $f[-1].Name + ")")
            exit 0
        }
        Start-Sleep -Seconds 1
    }
    Write-Output "[uitune] FAIL: no new screenshot appeared in $ShotDir"
    exit 1
}

# ------------------------------------------------------------------ -Setup
if ($Bootstrap) {
    if (-not (Focus-Game)) { Write-Output "[uitune] FAIL: cannot focus"; exit 1 }
    Set-Content -Path $Ctl -Value "" -Encoding ascii
    Write-Output "[uitune] bootstrapping via console..."
    Console-Cmd "merc_dev"
    Console-Cmd "merc_cmd_remote"
    Console-Cmd "merc_cmd_keys"
    Console-Cmd "merc_cmd_f2"
    Write-Output "[uitune] ready"
    exit 0
}

if (-not $Setup) { Write-Output "nothing to do - pass -Setup, -Bootstrap, -Send or -Shot"; exit 0 }

Set-Content -Path $Ctl -Value "" -Encoding ascii

Get-Process KingdomCome -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 3
Write-Output "[uitune] launching..."
Start-Process -FilePath $Exe -WorkingDirectory $GameDir -ArgumentList "-devmode","+exec","user.cfg","+r_Fullscreen","0","+wh_gfx_useSWF","1"
Start-Sleep -Seconds 15

# wait for the log to go quiet = main menu idle
$lastLen = -1; $quiet = Get-Date; $up0 = Get-Date
while ($true) {
    $len = 0; try { $len = (Get-Item $Log).Length } catch {}
    if ($len -ne $lastLen) { $lastLen = $len; $quiet = Get-Date }
    if (((Get-Date) - $up0).TotalSeconds -ge 40 -and ((Get-Date) - $quiet).TotalSeconds -ge 10) { break }
    if (((Get-Date) - $up0).TotalSeconds -ge 240) { Write-Output "[uitune] WARN: init never quiet"; break }
    Start-Sleep -Seconds 2
}
Write-Output "[uitune] menu idle"

if (-not (Focus-Game)) { Write-Output "[uitune] FAIL: cannot focus"; exit 1 }
$navLen = 0; try { $navLen = (Get-Item $Log).Length } catch {}
for ($i = 0; $i -lt $DownsToLoad; $i++) { [K]::Tap(0x50, $true, 60); Start-Sleep -Milliseconds 300 }
[K]::Tap(0x1C, $false, 60); Start-Sleep -Milliseconds 1500
[K]::Tap(0x1C, $false, 60); Start-Sleep -Milliseconds 2000
for ($i = 0; $i -lt $DownsToSave; $i++) { [K]::Tap(0x50, $true, 60); Start-Sleep -Milliseconds 200 }
[K]::Tap(0x1C, $false, 60); Start-Sleep -Milliseconds 1800
[K]::Tap(0x1C, $false, 60)

Write-Output "[uitune] waiting for the save to load..."
$dl = (Get-Date).AddSeconds(300); $ok = $false
while ((Get-Date) -lt $dl) {
    $tail = ""
    try {
        $fs = [System.IO.File]::Open($Log, 'Open', 'Read', 'ReadWrite')
        $fs.Seek($navLen, 'Begin') | Out-Null
        $sr = New-Object System.IO.StreamReader($fs)
        $tail = $sr.ReadToEnd(); $sr.Close(); $fs.Close()
    } catch {}
    if ($tail.Contains("Game loaded! Starting the inventory monitor")) { $ok = $true; break }
    Start-Sleep -Seconds 3
}
if (-not $ok) { Write-Output "[uitune] FAIL: save never finished loading"; exit 1 }
Write-Output "[uitune] loaded"
Start-Sleep -Seconds 10

Write-Output "[uitune] ready - the mod arms its own control-file poll; drive it with -Send / -Shot"
