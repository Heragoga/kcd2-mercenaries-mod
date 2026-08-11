@echo off
setlocal enabledelayedexpansion

:: ============================================================
::  KCD2 Mercenaries Mod - Release Packager
::
::  Produces ONE release ZIP: voicelines included, companion limit
::  as it stands in mercenaries.lua (MaxCompanions).
::
::  There used to be three variants - regular (limit 6), UNLIMITED
::  (999) and NOVOICELINES (999 with english.pak stripped). They are
::  gone on purpose: one build means one thing to test, one thing to
::  support, and no way for a player to pick the wrong download.
::  The limit now lives in the source, so change it there, not here.
::
::  Run PackageMod.bat first to build the mod, then run this.
:: ============================================================

set "REPO_ROOT=%~dp0"
set "REPO_ROOT=%REPO_ROOT:~0,-1%"

set "MODS_DIR=C:\Program Files\Steam\steamapps\common\KingdomComeDeliverance2\Mods"
set "MOD_DIR=%MODS_DIR%\mercenaries"
set "LUA_SRC=%REPO_ROOT%\data\Scripts\mods\mercenaries.lua"
set "RELEASE_DIR=%REPO_ROOT%\release"

set "ZIP_OUT=%RELEASE_DIR%\mercenaries.zip"
set "TMP_BUILD=%TEMP%\kcd2_release_build"

echo ============================================================
echo  KCD2 Mercenaries Mod - Release Packager
echo ============================================================
echo.

if not exist "%MOD_DIR%" (
    echo ERROR: Mod folder not found at %MOD_DIR%
    echo        Run PackageMod.bat first.
    pause
    exit /b 1
)

if not exist "%LUA_SRC%" (
    echo ERROR: mercenaries.lua not found at %LUA_SRC%
    pause
    exit /b 1
)

if not exist "%RELEASE_DIR%" mkdir "%RELEASE_DIR%"

:: Report the limit that is actually going out, so a wrong value is
:: caught here rather than by a player.
for /f "tokens=*" %%A in ('powershell -NoProfile -Command "$m=Select-String -Path '%LUA_SRC%' -Pattern 'mercenaries\.MaxCompanions\s*=\s*(\d+)'; if($m){$m.Matches[0].Groups[1].Value}else{'?'}"') do set "MAXC=%%A"
echo  Companion limit: %MAXC%

:: Voicelines ship with the build. PackageMod.bat writes them to
:: localization\english.pak; warn loudly if they are missing.
if exist "%MOD_DIR%\localization\english.pak" (
    echo  Voicelines:      included
) else (
    echo  Voicelines:      *** MISSING - english.pak not found ***
    echo                   Check the voice folder and re-run PackageMod.bat.
)
echo.

echo [1/1] Building mercenaries.zip...

if exist "%TMP_BUILD%" rd /s /q "%TMP_BUILD%"
powershell -NoProfile -Command "Copy-Item -Path '%MOD_DIR%' -Destination '%TMP_BUILD%\mercenaries' -Recurse"
if errorlevel 1 ( echo       ERROR: copy failed & goto :error )

if exist "%ZIP_OUT%" del "%ZIP_OUT%"
powershell -NoProfile -Command "Add-Type -Assembly 'System.IO.Compression.FileSystem'; [System.IO.Compression.ZipFile]::CreateFromDirectory('%TMP_BUILD%', '%ZIP_OUT%', [System.IO.Compression.CompressionLevel]::Optimal, $false)"
if errorlevel 1 ( echo       ERROR: zip failed & goto :error )

rd /s /q "%TMP_BUILD%"

:: Old multi-variant output would otherwise sit in release\ and get
:: uploaded alongside the real one.
if exist "%RELEASE_DIR%\UNLIMITED mercenaries.zip" (
    del "%RELEASE_DIR%\UNLIMITED mercenaries.zip"
    echo       Removed stale UNLIMITED mercenaries.zip
)
if exist "%RELEASE_DIR%\NOVOICELINES mercenaries.zip" (
    del "%RELEASE_DIR%\NOVOICELINES mercenaries.zip"
    echo       Removed stale NOVOICELINES mercenaries.zip
)

echo       Created: mercenaries.zip
echo.
echo ============================================================
echo  Release packaging complete.
echo  Output: %ZIP_OUT%
echo ============================================================
goto :end

:error
echo.
echo ============================================================
echo  Release packaging FAILED. See errors above.
echo ============================================================
exit /b 1

:end
endlocal
