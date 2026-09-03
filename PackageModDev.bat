@echo off
setlocal enabledelayedexpansion

:: ============================================================
::  KCD2 Mercenaries Mod - Package to the DEV build
::
::  PackageMod.bat deploys to KingdomComeDeliverance2 and launches the
::  RELEASE exe, which SILENTLY SWALLOWS rejected Skald nodes - a broken
::  quest just stops working, with nothing in any log.
::
::  This script deploys the same pak to the KCD2Mod dev build and launches
::  that instead. The dev build writes KCD2Mod\kcd.log with [Error]/[Warning]
::  lines naming the exact node that failed. Use this whenever a quest
::  change misbehaves.
:: ============================================================

set "REPO_ROOT=%~dp0"
set "REPO_ROOT=%REPO_ROOT:~0,-1%"

:: The dev build is a SEPARATE install from the retail one, and there is nothing to
:: autodetect it by - so it is opt-in per machine and never guessed. Find-KCD2.ps1 -Dev
:: reads KCD2_DEV_DIR or the dev= line in tools\local.paths.txt, and deliberately does
:: NOT fall back to the retail install: deploying a dev pak into the game you actually
:: play would be worse than failing.
set "DEV_ROOT="
for /f "usebackq delims=" %%i in (`powershell -NoProfile -ExecutionPolicy Bypass -File "%REPO_ROOT%\tools\Find-KCD2.ps1" -Dev`) do set "DEV_ROOT=%%i"
if not defined DEV_ROOT (
    echo.
    echo ERROR: no DEV build configured on this machine - nothing was packaged.
    echo        The dev build is the one that writes kcd.log with [Error]/[Warning]
    echo        lines; the retail build swallows rejected Skald nodes silently.
    echo        Point this script at yours, then re-run:
    echo            set KCD2_DEV_DIR=D:\path\to\KCD2Mod
    echo        or add   dev=D:\path\to\KCD2Mod   to tools\local.paths.txt
    echo        To package for the normal game instead, use PackageMod.bat.
    exit /b 1
)
set "OUT_DIR=%DEV_ROOT%\Mods\mercenaries"
set "DEV_EXE=%DEV_ROOT%\Bin\Win64ReleaseSteamLTO_DLL\KingdomCome.exe"

echo ============================================================
echo  Packaging to the DEV build (logs go to kcd.log in the dev root)
echo  Repo:   %REPO_ROOT%
echo  Dev:    %DEV_ROOT%
echo  Output: %OUT_DIR%
echo ============================================================

echo [1/4] Preparing output folder...
if exist "%OUT_DIR%" rd /s /q "%OUT_DIR%"
mkdir "%OUT_DIR%"
mkdir "%OUT_DIR%\data"
mkdir "%OUT_DIR%\localization"

echo [2/4] Copying manifest...
copy /y "%REPO_ROOT%\mod.manifest" "%OUT_DIR%\mod.manifest" >nul
copy /y "%REPO_ROOT%\mod.cfg" "%OUT_DIR%\mod.cfg" >nul

echo [3/4] Packing data folder...
powershell -NoProfile -Command "Add-Type -Assembly 'System.IO.Compression.FileSystem'; [System.IO.Compression.ZipFile]::CreateFromDirectory('%REPO_ROOT%\data', '%OUT_DIR%\data\mercenaries.pak', [System.IO.Compression.CompressionLevel]::NoCompression, $false)"
if errorlevel 1 (
    echo ERROR: failed to create data pak.
    exit /b 1
)

echo [4/5] Packing English localization...
set "TMP_LOC=%TEMP%\kcd2_loc_dev"
if exist "%TMP_LOC%" rd /s /q "%TMP_LOC%"
mkdir "%TMP_LOC%"
copy /y "%REPO_ROOT%\localization\English_xml.xml" "%TMP_LOC%\test__mercenaries.xml" >nul
powershell -NoProfile -Command "Add-Type -Assembly 'System.IO.Compression.FileSystem'; [System.IO.Compression.ZipFile]::CreateFromDirectory('%TMP_LOC%', '%OUT_DIR%\localization\English_xml.pak', [System.IO.Compression.CompressionLevel]::NoCompression, $false)"

:: ------------------------------------------------------------
:: 5. OPTIONAL: Pack voice files -> localization\english.pak
::    Flattens all subfolders, .ogg only.
::    Internal path: dialog/mercenaries_background_quest/<file>.ogg
:: ------------------------------------------------------------
echo [5/5] Packing voice files (optional)...
set "VOICE_SRC=%REPO_ROOT%\voice"
set "VOICE_PAK=%OUT_DIR%\localization\english.pak"

:: Declare temp paths OUTSIDE the if block so %var% expansion works correctly
set "TMP_VOICE=%TEMP%\kcd2_voice_tmp"
set "TMP_VOICE_INNER=%TEMP%\kcd2_voice_tmp\dialog\mercenaries_background_quest"

if not exist "%VOICE_SRC%" (
    echo       No voice folder found, skipping.
) else (
    if exist "!TMP_VOICE!" rd /s /q "!TMP_VOICE!"
    mkdir "!TMP_VOICE_INNER!"

    powershell -NoProfile -Command "Get-ChildItem -Path '!VOICE_SRC!' -Recurse -Filter '*.ogg' | ForEach-Object { Copy-Item $_.FullName -Destination '!TMP_VOICE_INNER!\' }; $n = (Get-ChildItem '!TMP_VOICE_INNER!').Count; Write-Host ('Copied ' + $n + ' .ogg file(s).')"

    powershell -NoProfile -Command "Add-Type -Assembly 'System.IO.Compression.FileSystem'; [System.IO.Compression.ZipFile]::CreateFromDirectory('!TMP_VOICE!', '!VOICE_PAK!', [System.IO.Compression.CompressionLevel]::NoCompression, $false)"

    rd /s /q "!TMP_VOICE!"

    if errorlevel 1 (
        echo       ERROR: Failed to create english.pak.
        goto :error
    )
    echo       Created: !VOICE_PAK!
)
rd /s /q "%TMP_LOC%"

:: Clear the old log so the next run is unambiguous - we spent several rounds
:: reading a log that turned out to be days stale.
if exist "%DEV_ROOT%\kcd.log" del /q "%DEV_ROOT%\kcd.log"

echo.
echo ============================================================
echo  Done. Launching the dev build.
echo  After it loads, check:  %DEV_ROOT%\kcd.log
echo  Look for:  [Error] ... mercenaries_background_quest
echo ============================================================
start "" "%DEV_EXE%"

endlocal
