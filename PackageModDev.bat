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
set "DEV_ROOT=C:\Program Files\Steam\steamapps\common\KCD2Mod"
set "OUT_DIR=%DEV_ROOT%\Mods\mercenaries"
set "DEV_EXE=%DEV_ROOT%\Bin\Win64ReleaseSteamLTO_DLL\KingdomCome.exe"

echo ============================================================
echo  Packaging to the DEV build (logs go to KCD2Mod\kcd.log)
echo  Repo:   %REPO_ROOT%
echo  Output: %OUT_DIR%
echo ============================================================

if not exist "%DEV_ROOT%" (
    echo ERROR: dev build not found at %DEV_ROOT%
    exit /b 1
)

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

echo [4/4] Packing English localization...
set "TMP_LOC=%TEMP%\kcd2_loc_dev"
if exist "%TMP_LOC%" rd /s /q "%TMP_LOC%"
mkdir "%TMP_LOC%"
copy /y "%REPO_ROOT%\localization\English_xml.xml" "%TMP_LOC%\test__mercenaries.xml" >nul
powershell -NoProfile -Command "Add-Type -Assembly 'System.IO.Compression.FileSystem'; [System.IO.Compression.ZipFile]::CreateFromDirectory('%TMP_LOC%', '%OUT_DIR%\localization\English_xml.pak', [System.IO.Compression.CompressionLevel]::NoCompression, $false)"
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
