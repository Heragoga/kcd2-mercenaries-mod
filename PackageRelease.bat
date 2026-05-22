@echo off
setlocal enabledelayedexpansion

:: ============================================================
::  KCD2 Mercenaries Mod - Release Packager
::  Produces three release ZIPs from the installed mod folder.
::
::  Run PackageMod.bat first to build the mod, then run this.
:: ============================================================

set "REPO_ROOT=%~dp0"
set "REPO_ROOT=%REPO_ROOT:~0,-1%"

set "MODS_DIR=C:\Program Files\Steam\steamapps\common\KingdomComeDeliverance2\Mods"
set "MOD_DIR=%MODS_DIR%\mercenaries"
set "LUA_SRC=%REPO_ROOT%\data\Scripts\mods\mercenaries.lua"
set "RELEASE_DIR=%REPO_ROOT%\release"

set "ZIP_REGULAR=%RELEASE_DIR%\mercenaries.zip"
set "ZIP_UNLIMITED=%RELEASE_DIR%\UNLIMITED mercenaries.zip"
set "ZIP_NOVOICE=%RELEASE_DIR%\NOVOICELINES mercenaries.zip"

set "TMP_BASE=%TEMP%\kcd2_release"

echo ============================================================
echo  KCD2 Mercenaries Mod - Release Packager
echo ============================================================
echo.

:: Verify mod has been packaged
if not exist "%MOD_DIR%" (
    echo ERROR: Mod folder not found at %MOD_DIR%
    echo        Run PackageMod.bat first.
    pause
    exit /b 1
)

:: Verify mercenaries.lua exists in the repo for patching
if not exist "%LUA_SRC%" (
    echo ERROR: mercenaries.lua not found at %LUA_SRC%
    pause
    exit /b 1
)

:: Create release output folder
if not exist "%RELEASE_DIR%" mkdir "%RELEASE_DIR%"

:: ============================================================
:: Helper: read the mercenaries.pak, patch the lua inside it,
::         and write a new pak to a temp location.
::
:: We do this by:
::   1. Extracting mercenaries.pak to a temp folder
::   2. Patching the .lua file with PowerShell
::   3. Repacking to a new .pak
:: ============================================================

:: ============================================================
:: VARIANT 1 - mercenaries.zip  (MaxCompanions = 6)
:: ============================================================
echo [1/3] Building mercenaries.zip (MaxCompanions=6)...

set "TMP_V1=%TMP_BASE%_regular"
set "TMP_V1_PAK=%TMP_BASE%_regular_pak"
if exist "%TMP_V1%"     rd /s /q "%TMP_V1%"
if exist "%TMP_V1_PAK%" rd /s /q "%TMP_V1_PAK%"

:: Copy full mod folder to temp
powershell -NoProfile -Command "Copy-Item -Path '%MOD_DIR%' -Destination '%TMP_V1%\mercenaries' -Recurse"

:: Extract, patch, repack mercenaries.pak
set "PAK_IN=%TMP_V1%\mercenaries\data\mercenaries.pak"
mkdir "%TMP_V1_PAK%"
powershell -NoProfile -Command "Add-Type -Assembly 'System.IO.Compression.FileSystem'; [System.IO.Compression.ZipFile]::ExtractToDirectory('%PAK_IN%', '%TMP_V1_PAK%')"
powershell -NoProfile -Command "(Get-Content '%TMP_V1_PAK%\Scripts\mods\mercenaries.lua') -replace 'mercenaries\.MaxCompanions\s*=\s*\d+', 'mercenaries.MaxCompanions = 6' | Set-Content '%TMP_V1_PAK%\Scripts\mods\mercenaries.lua'"
del "%PAK_IN%"
powershell -NoProfile -Command "Add-Type -Assembly 'System.IO.Compression.FileSystem'; [System.IO.Compression.ZipFile]::CreateFromDirectory('%TMP_V1_PAK%', '%PAK_IN%', [System.IO.Compression.CompressionLevel]::NoCompression, $false)"
rd /s /q "%TMP_V1_PAK%"

:: Zip the mercenaries folder
if exist "%ZIP_REGULAR%" del "%ZIP_REGULAR%"
powershell -NoProfile -Command "Add-Type -Assembly 'System.IO.Compression.FileSystem'; [System.IO.Compression.ZipFile]::CreateFromDirectory('%TMP_V1%', '%ZIP_REGULAR%', [System.IO.Compression.CompressionLevel]::Optimal, $false)"
rd /s /q "%TMP_V1%"

if errorlevel 1 ( echo       ERROR & goto :error )
echo       Created: mercenaries.zip

:: ============================================================
:: VARIANT 2 - UNLIMITED mercenaries.zip  (MaxCompanions = 999)
:: ============================================================
echo [2/3] Building UNLIMITED mercenaries.zip (MaxCompanions=999)...

set "TMP_V2=%TMP_BASE%_unlimited"
if exist "%TMP_V2%" rd /s /q "%TMP_V2%"

powershell -NoProfile -Command "Copy-Item -Path '%MOD_DIR%' -Destination '%TMP_V2%\mercenaries' -Recurse"

if exist "%ZIP_UNLIMITED%" del "%ZIP_UNLIMITED%"
powershell -NoProfile -Command "Add-Type -Assembly 'System.IO.Compression.FileSystem'; [System.IO.Compression.ZipFile]::CreateFromDirectory('%TMP_V2%', '%ZIP_UNLIMITED%', [System.IO.Compression.CompressionLevel]::Optimal, $false)"
rd /s /q "%TMP_V2%"

if errorlevel 1 ( echo       ERROR & goto :error )
echo       Created: UNLIMITED mercenaries.zip

:: ============================================================
:: VARIANT 3 - NOVOICELINES mercenaries.zip  (MaxCompanions = 999, no english.pak)
:: ============================================================
echo [3/3] Building NOVOICELINES mercenaries.zip (MaxCompanions=999, no english.pak)...

set "TMP_V3=%TMP_BASE%_novoice"
if exist "%TMP_V3%" rd /s /q "%TMP_V3%"

powershell -NoProfile -Command "Copy-Item -Path '%MOD_DIR%' -Destination '%TMP_V3%\mercenaries' -Recurse"

:: Remove english.pak if it exists
if exist "%TMP_V3%\mercenaries\localization\english.pak" (
    del "%TMP_V3%\mercenaries\localization\english.pak"
    echo       Removed english.pak
) else (
    echo       Note: english.pak was not present, nothing to remove.
)

if exist "%ZIP_NOVOICE%" del "%ZIP_NOVOICE%"
powershell -NoProfile -Command "Add-Type -Assembly 'System.IO.Compression.FileSystem'; [System.IO.Compression.ZipFile]::CreateFromDirectory('%TMP_V3%', '%ZIP_NOVOICE%', [System.IO.Compression.CompressionLevel]::Optimal, $false)"
rd /s /q "%TMP_V3%"

if errorlevel 1 ( echo       ERROR & goto :error )
echo       Created: NOVOICELINES mercenaries.zip

:: ============================================================
echo.
echo ============================================================
echo  Release packaging complete!
echo  Output folder: %RELEASE_DIR%
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