@echo off
setlocal enabledelayedexpansion

:: ============================================================
::  Forge Anywhere - Package Script
::  Run from the root of this mod folder.
:: ============================================================

set "REPO_ROOT=%~dp0"
set "REPO_ROOT=%REPO_ROOT:~0,-1%"
set "MODS_DIR=C:\Program Files\Steam\steamapps\common\KingdomComeDeliverance2\Mods"
set "OUT_DIR=%MODS_DIR%\forgeanywhere"

echo ============================================================
echo  Forge Anywhere Packager
echo ============================================================
echo  Repo:   %REPO_ROOT%
echo  Output: %OUT_DIR%
echo.

:: ------------------------------------------------------------
:: 1. Create/recreate output folder
:: ------------------------------------------------------------
echo [1/4] Preparing output folder...
if exist "%OUT_DIR%" (
    echo       Deleting existing folder...
    rd /s /q "%OUT_DIR%"
)
mkdir "%OUT_DIR%"
mkdir "%OUT_DIR%\data"
mkdir "%OUT_DIR%\localization"
echo       Done.

:: ------------------------------------------------------------
:: 2. Copy manifest
:: ------------------------------------------------------------
echo [2/4] Copying mod.manifest...
copy /y "%REPO_ROOT%\mod.manifest" "%OUT_DIR%\mod.manifest" >nul
echo       Done.

:: ------------------------------------------------------------
:: 3. Pack data folder -> data\forgeanywhere.pak (store / 0 compression)
:: ------------------------------------------------------------
echo [3/4] Packing data folder...
set "DATA_SRC=%REPO_ROOT%\data"
set "DATA_PAK=%OUT_DIR%\data\forgeanywhere.pak"

if not exist "%DATA_SRC%" (
    echo       WARNING: data folder not found, skipping.
) else (
    powershell -NoProfile -Command "Add-Type -Assembly 'System.IO.Compression.FileSystem'; [System.IO.Compression.ZipFile]::CreateFromDirectory('%DATA_SRC%', '%DATA_PAK%', [System.IO.Compression.CompressionLevel]::NoCompression, $false)"
    if errorlevel 1 (
        echo       ERROR: Failed to create data pak.
        goto :error
    )
    echo       Created: %DATA_PAK%
)

:: ------------------------------------------------------------
:: 4. Pack each localization file -> localization\<lang>.pak
::    File inside the archive is always: test__forgeanywhere.xml
:: ------------------------------------------------------------
echo [4/4] Packing localization files...
set "LOC_SRC=%REPO_ROOT%\localization"
set "LOC_OUT=%OUT_DIR%\localization"

if not exist "%LOC_SRC%" (
    echo       WARNING: localization folder not found, skipping.
) else (
    for %%L in (Chineses_xml Chineset_xml Czech_xml English_xml French_xml German_xml Italian_xml Japanese_xml Korean_xml Polish_xml Portuguese_xml Russian_xml Spanish_xml Turkish_xml Ukrainian_xml Vietnamese_xml) do (
        set "SRC_FILE=%LOC_SRC%\%%L.xml"
        set "PAK_FILE=%LOC_OUT%\%%L.pak"
        set "TMP_LOC=%TEMP%\fa_loc_%%L"

        if not exist "!SRC_FILE!" (
            echo       WARNING: !SRC_FILE! not found, skipping %%L.
        ) else (
            if exist "!TMP_LOC!" rd /s /q "!TMP_LOC!"
            mkdir "!TMP_LOC!"
            copy /y "!SRC_FILE!" "!TMP_LOC!\test__forgeanywhere.xml" >nul

            powershell -NoProfile -Command "Add-Type -Assembly 'System.IO.Compression.FileSystem'; [System.IO.Compression.ZipFile]::CreateFromDirectory('!TMP_LOC!', '!PAK_FILE!', [System.IO.Compression.CompressionLevel]::NoCompression, $false)"
            rd /s /q "!TMP_LOC!"

            if errorlevel 1 (
                echo       ERROR: Failed to pack %%L.
                goto :error
            )
            echo       Created: %%L.pak
        )
    )
)

echo.
echo ============================================================
echo  Packaging complete!
echo  Output: %OUT_DIR%
echo ============================================================
goto :end

:error
echo.
echo ============================================================
echo  Packaging FAILED. See errors above.
echo ============================================================
exit /b 1

:end
endlocal
