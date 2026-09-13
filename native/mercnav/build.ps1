# Build mercenaries_nav.asi with the MSVC toolchain that Visual Studio 2022 installs.
#   powershell -ExecutionPolicy Bypass -File native\mercnav\build.ps1
# Output: native\mercnav\out\mercenaries_nav.asi (a plain x64 DLL with the .asi extension).
param([switch]$Debug)
$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$out = Join-Path $here "out"
New-Item -ItemType Directory -Force $out | Out-Null

$vswhere = "C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe"
$vs = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if (-not $vs) { throw "no Visual Studio with the C++ x64 toolset" }
$vcvars = Join-Path $vs "VC\Auxiliary\Build\vcvars64.bat"

$opt = if ($Debug) { "/Od /Zi" } else { "/O2" }
$cmd = "call `"$vcvars`" >nul && cl /nologo /std:c++17 /EHsc /W4 $opt /MT /LD /D_CRT_SECURE_NO_WARNINGS " +
       "`"$here\mercnav.cpp`" /Fo`"$out\\`" /Fe`"$out\mercenaries_nav.asi`" /link /DLL kernel32.lib user32.lib"
Write-Host $cmd
cmd /c $cmd
if ($LASTEXITCODE -ne 0) { throw "build failed" }
Get-Item (Join-Path $out "mercenaries_nav.asi") | Select-Object FullName, Length, LastWriteTime
