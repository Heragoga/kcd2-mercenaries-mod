@echo off
setlocal enabledelayedexpansion

:: ============================================================
::  KCD2 Mercenaries Mod - Release Packager
::
::  Produces two release ZIPs, both with voicelines:
::    mercenaries.zip            - companion limit as it stands in
::                                 mercenaries.lua (MaxCompanions)
::    UNLIMITED mercenaries.zip  - same build with MaxCompanions
::                                 patched to UNLIMITED_MAX
::
::  The unlimited build is patched inside the packed data pak, so the
::  source stays at the supported limit and only one build is tested.
::
::  Formation presets stop at mercenaries.FormationSizes' largest
::  entry (50). Past that the squad reuses the 50-slot preset - the
::  extra mercs still fight, they just share spots.
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
set "ZIP_UNLIMITED=%RELEASE_DIR%\UNLIMITED mercenaries.zip"
set "TMP_BUILD=%TEMP%\kcd2_release_build"
set "TMP_UNLIM=%TEMP%\kcd2_release_unlimited"

:: Cap the unlimited build ships with.
set "UNLIMITED_MAX=999"

:: Path of the lua inside data\mercenaries.pak. PackageMod.bat writes
:: backslash separators; the alt is there in case that ever changes.
set "PAK_LUA=Scripts\mods\mercenaries.lua"
set "PAK_LUA_ALT=Scripts/mods/mercenaries.lua"

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
echo  Companion limit: %MAXC%   (unlimited build: %UNLIMITED_MAX%)

:: Voicelines ship with the build. PackageMod.bat writes them to
:: localization\english.pak; warn loudly if they are missing.
if exist "%MOD_DIR%\localization\english.pak" (
    echo  Voicelines:      included
) else (
    echo  Voicelines:      *** MISSING - english.pak not found ***
    echo                   Check the voice folder and re-run PackageMod.bat.
)
echo.

echo [1/2] Building mercenaries.zip...

if exist "%TMP_BUILD%" rd /s /q "%TMP_BUILD%"
powershell -NoProfile -Command "Copy-Item -Path '%MOD_DIR%' -Destination '%TMP_BUILD%\mercenaries' -Recurse"
if errorlevel 1 ( echo       ERROR: copy failed & goto :error )

if exist "%ZIP_OUT%" del "%ZIP_OUT%"
powershell -NoProfile -Command "Add-Type -Assembly 'System.IO.Compression.FileSystem'; [System.IO.Compression.ZipFile]::CreateFromDirectory('%TMP_BUILD%', '%ZIP_OUT%', [System.IO.Compression.CompressionLevel]::Optimal, $false)"
if errorlevel 1 ( echo       ERROR: zip failed & goto :error )

rd /s /q "%TMP_BUILD%"
echo       Created: mercenaries.zip

echo [2/2] Building UNLIMITED mercenaries.zip (MaxCompanions=%UNLIMITED_MAX%)...

if exist "%TMP_UNLIM%" rd /s /q "%TMP_UNLIM%"
powershell -NoProfile -Command "Copy-Item -Path '%MOD_DIR%' -Destination '%TMP_UNLIM%\mercenaries' -Recurse"
if errorlevel 1 ( echo       ERROR: copy failed & goto :error )

set "UNLIM_PAK=%TMP_UNLIM%\mercenaries\data\mercenaries.pak"
if not exist "%UNLIM_PAK%" ( echo       ERROR: mercenaries.pak missing from the build & goto :error )

:: Rewrite just the one lua entry - repacking the whole pak would risk
:: changing the store-only layout the game expects.
call :patchcap "%UNLIM_PAK%" %UNLIMITED_MAX%
if errorlevel 1 ( echo       ERROR: could not patch MaxCompanions inside mercenaries.pak & goto :error )

:: Read the value back out of the patched pak - the same check the
:: regular build gets, against what a player actually installs.
for /f "tokens=*" %%A in ('powershell -NoProfile -Command "Add-Type -Assembly 'System.IO.Compression.FileSystem'; $z=[System.IO.Compression.ZipFile]::OpenRead('%UNLIM_PAK%'); $e=$z.GetEntry('%PAK_LUA%'); if(-not $e){ $e=$z.GetEntry('%PAK_LUA_ALT%') }; $r=New-Object System.IO.StreamReader($e.Open()); $t=$r.ReadToEnd(); $r.Dispose(); $z.Dispose(); if($t -match 'mercenaries\.MaxCompanions\s*=\s*(\d+)'){$Matches[1]}else{'?'}"') do set "UMAXC=%%A"
if not "%UMAXC%"=="%UNLIMITED_MAX%" ( echo       ERROR: patched pak reads %UMAXC%, expected %UNLIMITED_MAX% & goto :error )
echo       Patched pak reports MaxCompanions = %UMAXC%

if exist "%ZIP_UNLIMITED%" del "%ZIP_UNLIMITED%"
powershell -NoProfile -Command "Add-Type -Assembly 'System.IO.Compression.FileSystem'; [System.IO.Compression.ZipFile]::CreateFromDirectory('%TMP_UNLIM%', '%ZIP_UNLIMITED%', [System.IO.Compression.CompressionLevel]::Optimal, $false)"
if errorlevel 1 ( echo       ERROR: zip failed & goto :error )

rd /s /q "%TMP_UNLIM%"
echo       Created: UNLIMITED mercenaries.zip

:: Old multi-variant output would otherwise sit in release\ and get
:: uploaded alongside the real ones.
if exist "%RELEASE_DIR%\NOVOICELINES mercenaries.zip" (
    del "%RELEASE_DIR%\NOVOICELINES mercenaries.zip"
    echo       Removed stale NOVOICELINES mercenaries.zip
)

echo.
echo ============================================================
echo  Release packaging complete.
echo  Output: %ZIP_OUT%
echo          %ZIP_UNLIMITED%
echo ============================================================
goto :end

:: patchcap <pak> <limit> - rewrite MaxCompanions in the packed lua.
:patchcap
powershell -NoProfile -Command "Add-Type -Assembly 'System.IO.Compression.FileSystem'; $z=[System.IO.Compression.ZipFile]::Open('%~1','Update'); $e=$z.GetEntry('%PAK_LUA%'); if(-not $e){ $e=$z.GetEntry('%PAK_LUA_ALT%') }; if(-not $e){ $z.Dispose(); exit 1 }; $r=New-Object System.IO.StreamReader($e.Open()); $t=$r.ReadToEnd(); $r.Dispose(); if($t -notmatch 'mercenaries\.MaxCompanions\s*=\s*\d+'){ $z.Dispose(); exit 1 }; $t=$t -replace 'mercenaries\.MaxCompanions\s*=\s*\d+','mercenaries.MaxCompanions = %~2'; $n=$e.FullName; $e.Delete(); $ne=$z.CreateEntry($n,[System.IO.Compression.CompressionLevel]::NoCompression); $w=New-Object System.IO.StreamWriter($ne.Open()); $w.Write($t); $w.Dispose(); $z.Dispose()"
exit /b %errorlevel%

:error
echo.
echo ============================================================
echo  Release packaging FAILED. See errors above.
echo ============================================================
exit /b 1

:end
endlocal
