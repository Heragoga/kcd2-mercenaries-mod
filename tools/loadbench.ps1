# Load-time bench. Launches KCD2, loads THE ONLY save in the isolated test user folder
# (sys_user_folder = kcd2bisect, set in system.cfg), times the load from the engine's own
# log, then kills the game. Mod-independent: every marker it waits on is a vanilla engine
# line, so it works with the mod installed and with it uninstalled.
#
#   powershell -ExecutionPolicy Bypass -File tools\loadbench.ps1 -Save <path.whs> -Label baseline
#
# Requires log_Verbosity 4 + log_IncludeTime 5 in user.cfg (the <hh:mm:ss> <seconds> prefix).
param(
    [Parameter(Mandatory=$true)][string]$Save,
    [string]$Label = "run",
    [int]$DownsToLoad = 2,
    [int]$DownsToSave = 0,
    [switch]$KeepRunning,     # leave the game up (for the save-with-mod step)
    [int]$HoldSec = 0,        # after load, hold this long before quitting
    [string]$ConsoleCmd = "", # run one devmode console command after the load
    [string]$OutDir = ""
)

$ErrorActionPreference = "Stop"
$GameDir = & (Join-Path $PSScriptRoot "Find-KCD2.ps1")
if (-not $GameDir) { Write-Output "[bench] FAIL: game not found"; exit 1 }
$Exe      = Join-Path $GameDir "Bin\Win64MasterMasterSteamPGO\KingdomCome.exe"
$Log      = Join-Path $GameDir "kcd.log"
$SaveDir  = "$env:USERPROFILE\Saved Games\kcd2bisect\saves\playline0"

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class KB {
    [StructLayout(LayoutKind.Sequential)] struct INPUT { public uint type; public KI ki; public ulong pad; }
    [StructLayout(LayoutKind.Sequential)] struct KI { public ushort wVk; public ushort wScan; public uint dwFlags; public uint time; public IntPtr extra; }
    [DllImport("user32.dll")] static extern uint SendInput(uint n, INPUT[] i, int s);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int n);
    const uint SCAN = 0x8; const uint UP = 0x2; const uint EXT = 0x1; const uint UNI = 0x4;
    public static void Tap(ushort scan, bool ext, int hold) {
        uint f = SCAN | (ext ? EXT : 0);
        var d = new INPUT[]{ new INPUT{ type=1, ki=new KI{ wScan=scan, dwFlags=f } } };
        var u = new INPUT[]{ new INPUT{ type=1, ki=new KI{ wScan=scan, dwFlags=f|UP } } };
        SendInput(1, d, Marshal.SizeOf(typeof(INPUT))); System.Threading.Thread.Sleep(hold);
        SendInput(1, u, Marshal.SizeOf(typeof(INPUT)));
    }
    public static void Type(string s, int per) {
        foreach (char c in s) {
            var d = new INPUT[]{ new INPUT{ type=1, ki=new KI{ wVk=0, wScan=c, dwFlags=UNI } } };
            var u = new INPUT[]{ new INPUT{ type=1, ki=new KI{ wVk=0, wScan=c, dwFlags=UNI|UP } } };
            SendInput(1, d, Marshal.SizeOf(typeof(INPUT))); System.Threading.Thread.Sleep(15);
            SendInput(1, u, Marshal.SizeOf(typeof(INPUT))); System.Threading.Thread.Sleep(per);
        }
    }
}
"@
$SC = @{ down=0x50; enter=0x1C; esc=0x01; tilde=0x29 }
$EXTK = @{ down=$true; enter=$false; esc=$false; tilde=$false }
function Tap([string]$k,[int]$ms){ [KB]::Tap([uint16]$SC[$k], [bool]$EXTK[$k], 40); Start-Sleep -Milliseconds $ms }

function Focus-Game {
    $p = Get-Process KingdomCome -ErrorAction SilentlyContinue
    if (-not $p -or $p.MainWindowHandle -eq 0) { Write-Output "[bench] FAIL: no window"; exit 1 }
    for ($t=0; $t -lt 6; $t++) {
        [KB]::Tap(0x38,$false,30)
        [KB]::ShowWindow($p.MainWindowHandle,9) | Out-Null
        [KB]::SetForegroundWindow($p.MainWindowHandle) | Out-Null
        Start-Sleep -Milliseconds 700
        if ([KB]::GetForegroundWindow() -eq $p.MainWindowHandle) { return }
        Start-Sleep -Milliseconds 800
    }
    Write-Output "[bench] FAIL: could not focus the game - sending no keys"; exit 1
}
function LogTail([long]$from) {
    if (-not (Test-Path $Log)) { return "" }
    $len = 0; try { $len = (Get-Item $Log).Length } catch {}
    if ($len -lt $from) { $from = 0 }
    if ($len -le $from) { return "" }
    try {
        $fs = [System.IO.File]::Open($Log,'Open','Read','ReadWrite'); $fs.Seek($from,'Begin') | Out-Null
        $sr = New-Object System.IO.StreamReader($fs); $t = $sr.ReadToEnd(); $sr.Close(); $fs.Close(); return $t
    } catch { return "" }
}

# --- stage the save: the isolated playline holds exactly ONE save, so menu nav is fixed ---
if (-not (Test-Path $Save)) { Write-Output "[bench] FAIL: no such save $Save"; exit 1 }
Get-Process KingdomCome -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 3
New-Item -ItemType Directory -Force -Path $SaveDir | Out-Null
Get-ChildItem $SaveDir -Filter *.whs -ErrorAction SilentlyContinue | Remove-Item -Force
Copy-Item $Save (Join-Path $SaveDir "autosave233.whs") -Force
$mods = Test-Path (Join-Path $GameDir "Mods\mercenaries")
Write-Output ("[bench] label='{0}' save='{1}' mod_installed={2}" -f $Label, (Split-Path $Save -Leaf), $mods)

$appId = Join-Path $GameDir "Bin\Win64MasterMasterSteamPGO\steam_appid.txt"
if (-not (Test-Path $appId)) { [System.IO.File]::WriteAllText($appId, "1771300") }

Write-Output "[bench] launching..."
Start-Process -FilePath $Exe -WorkingDirectory $GameDir -ArgumentList "-devmode","+exec","user.cfg"
Start-Sleep -Seconds 12
# menu-ready: the log goes quiet once the main menu idles
$up0 = Get-Date; $lastLen = -1; $quiet = Get-Date
while ($true) {
    if (-not (Get-Process KingdomCome -ErrorAction SilentlyContinue)) {
        Write-Output "[bench] game vanished during init"; exit 1
    }
    $len = 0; try { $len = (Get-Item $Log).Length } catch {}
    if ($len -ne $lastLen) { $lastLen = $len; $quiet = Get-Date }
    if (((Get-Date)-$up0).TotalSeconds -ge 40 -and ((Get-Date)-$quiet).TotalSeconds -ge 10) { break }
    if (((Get-Date)-$up0).TotalSeconds -ge 240) { Write-Output "[bench] WARN: init never quiet"; break }
    Start-Sleep -Seconds 2
}
Write-Output "[bench] menu idle"

$loaded = $false
for ($a=1; $a -le 3 -and -not $loaded; $a++) {
    Focus-Game
    $navLen = 0; try { $navLen = (Get-Item $Log).Length } catch {}
    for ($i=0; $i -lt $DownsToLoad; $i++) { Tap "down" 300 }
    Tap "enter" 1500; Tap "enter" 2000
    for ($i=0; $i -lt $DownsToSave; $i++) { Tap "down" 180 }
    Tap "enter" 1800; Tap "enter" 1000
    $dl = (Get-Date).AddSeconds(25)
    while ((Get-Date) -lt $dl -and -not $loaded) {
        if ((LogTail $navLen).Contains("Loading saved game")) { $loaded = $true } else { Start-Sleep -Seconds 2 }
    }
    if (-not $loaded) { Focus-Game; Tap "esc" 900; Tap "esc" 900; Tap "esc" 1500 }
}
if (-not $loaded) {
    Write-Output "[bench] FAIL: navigation never started a load"
    Get-Process KingdomCome -ErrorAction SilentlyContinue | Stop-Process -Force
    exit 1
}
Write-Output "[bench] load started - waiting for RUNNING (cap 20 min)..."
$dl = (Get-Date).AddSeconds(1200); $ok = $false
while ((Get-Date) -lt $dl -and -not $ok) {
    if (-not (Get-Process KingdomCome -ErrorAction SilentlyContinue)) {
        Write-Output "[bench] RESULT $Label : CRASHED during load"; exit 2
    }
    $all = LogTail 0
    if ($all -match "SetGlobalState 12->13 '?LEVEL_LOAD_COMPLETE'?->'?RUNNING") { $ok = $true } else { Start-Sleep -Seconds 3 }
}
if (-not $ok) { Write-Output "[bench] RESULT $Label : TIMEOUT (>20 min)"; Get-Process KingdomCome -EA SilentlyContinue | Stop-Process -Force; exit 3 }

if ($ConsoleCmd -ne "") {
    Start-Sleep -Seconds 8
    Focus-Game
    foreach ($c in $ConsoleCmd -split ';;') {
        if ($c.Trim() -match '^wait:(\d+)$') {
            Write-Output ("[bench] wait {0}s" -f $matches[1]); Start-Sleep -Seconds ([int]$matches[1]); continue
        }
        Write-Output "[bench] console: $c"
        [KB]::Tap(0x29,$false,60); Start-Sleep -Milliseconds 800
        [KB]::Type($c.Trim(), 25); Start-Sleep -Milliseconds 400
        Tap "enter" 800
        [KB]::Tap(0x29,$false,60); Start-Sleep -Milliseconds 600
    }
}
if ($HoldSec -gt 0) { Start-Sleep -Seconds $HoldSec }

# --- parse the timing out of the log ---
$lines = Get-Content $Log
$t = @{}
$startWall=$null; $endWall=$null; $lvl=$null; $errs=0; $whichSave=$null
foreach ($l in $lines) {
    if ($l -match "^<(\d\d):(\d\d):(\d\d)>") { $w = [int]$matches[1]*3600 + [int]$matches[2]*60 + [int]$matches[3] } else { $w = $null }
    if ($l -match "Loading saved game '([^']+)'") { if (-not $startWall) { $startWall = $w; $whichSave = $matches[1] } }
    if ($l -match "Level \w+ loading time: ([0-9.]+) seconds") { $lvl = [double]$matches[1] }
    if ($l -match "SetGlobalState 12->13") { if (-not $endWall) { $endWall = $w } }
    if ($l -match "\[Error\]\[LoadGame\]") { $errs++ }
}
$total = if ($startWall -ne $null -and $endWall -ne $null) { $endWall - $startWall } else { -1 }
Write-Output ""
Write-Output ("[bench] RESULT {0} : total {1}s  (level {2}s)  loadgame_errors={3}  save={4}  mod={5}" -f $Label, $total, $lvl, $errs, $whichSave, $mods)

if ($OutDir -ne "") {
    New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
    Copy-Item $Log (Join-Path $OutDir ("$Label.log")) -Force
    ("{0},{1},{2},{3},{4}" -f $Label, $total, $lvl, $errs, $mods) |
        Out-File -Append -Encoding utf8 (Join-Path $OutDir "results.csv")
}
if (-not $KeepRunning) {
    Get-Process KingdomCome -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
}
