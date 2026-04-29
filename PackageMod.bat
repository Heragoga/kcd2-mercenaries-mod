@echo off
setlocal enabledelayedexpansion

:: ============================================================
::  KCD2 Mercenaries Mod - Package Script
::  Run from the root of the repository.
:: ============================================================

set "REPO_ROOT=%~dp0"
set "REPO_ROOT=%REPO_ROOT:~0,-1%"
set "MODS_DIR=C:\Program Files\Steam\steamapps\common\KingdomComeDeliverance2\Mods"
set "OUT_DIR=%MODS_DIR%\mercenaries"

echo ============================================================
echo  KCD2 Mercenaries Mod Packager
echo ============================================================
echo  Repo:   %REPO_ROOT%
echo  Output: %OUT_DIR%
echo.

:: ------------------------------------------------------------
:: 1. Create/recreate output folder
:: ------------------------------------------------------------
echo [1/5] Preparing output folder...
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
echo [2/5] Copying mod.manifest...
copy /y "%REPO_ROOT%\mod.manifest" "%OUT_DIR%\mod.manifest" >nul
echo       Done.

:: ------------------------------------------------------------
:: 3. Pack data folder -> data\mercenaries.pak (store / 0 compression)
:: ------------------------------------------------------------
echo [3/5] Packing data folder...
set "DATA_SRC=%REPO_ROOT%\data"
set "DATA_PAK=%OUT_DIR%\data\mercenaries.pak"

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
::    File inside the archive is always: test__mercenaries.xml
:: ------------------------------------------------------------
echo [4/5] Packing localization files...
set "LOC_SRC=%REPO_ROOT%\localization"
set "LOC_OUT=%OUT_DIR%\localization"

if not exist "%LOC_SRC%" (
    echo       WARNING: localization folder not found, skipping.
) else (
    for %%L in (Chineses_xml Chineset_xml Czech_xml English_xml French_xml German_xml Russian_xml Turkish_xml Japanese_xml) do (
        set "SRC_FILE=%LOC_SRC%\%%L.xml"
        set "PAK_FILE=%LOC_OUT%\%%L.pak"
        set "TMP_LOC=%TEMP%\kcd2_loc_%%L"

        if not exist "!SRC_FILE!" (
            echo       WARNING: !SRC_FILE! not found, skipping %%L.
        ) else (
            if exist "!TMP_LOC!" rd /s /q "!TMP_LOC!"
            mkdir "!TMP_LOC!"
            copy /y "!SRC_FILE!" "!TMP_LOC!\test__mercenaries.xml" >nul

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

:: ------------------------------------------------------------
:: 5. OPTIONAL: Pack voice files -> localization\english.pak
::    Flattens all subfolders, .ogg only.
::    Internal path: dialog/mercenaries_background_quest/<file>.ogg
:: ------------------------------------------------------------
echo [5/5] Packing voice files (optional)...
set "VOICE_SRC=%REPO_ROOT%\voice"
set "VOICE_PAK=%LOC_OUT%\english.pak"

:: Declare temp paths OUTSIDE the if block so %var% expansion works correctly
set "TMP_VOICE=%TEMP%\kcd2_voice_tmp"
set "TMP_VOICE_INNER=%TEMP%\kcd2_voice_tmp\dialog\mercenaries_background_quest"

if not exist "%VOICE_SRC%" (
    echo       No voice folder found, skipping.
) else (
    if exist "%TMP_VOICE%" rd /s /q "%TMP_VOICE%"
    mkdir "%TMP_VOICE_INNER%"

    powershell -NoProfile -Command "Get-ChildItem -Path '%VOICE_SRC%' -Recurse -Filter '*.ogg' | ForEach-Object { Copy-Item $_.FullName -Destination '%TMP_VOICE_INNER%\' }; $n = (Get-ChildItem '%TMP_VOICE_INNER%').Count; Write-Host ('Copied ' + $n + ' .ogg file(s).')"

    powershell -NoProfile -Command "Add-Type -Assembly 'System.IO.Compression.FileSystem'; [System.IO.Compression.ZipFile]::CreateFromDirectory('%TMP_VOICE%', '%VOICE_PAK%', [System.IO.Compression.CompressionLevel]::NoCompression, $false)"

    rd /s /q "%TMP_VOICE%"

    if errorlevel 1 (
        echo       ERROR: Failed to create english.pak.
        goto :error
    )
    echo       Created: %VOICE_PAK%
)

:: ------------------------------------------------------------
echo.
echo ============================================================
echo  Packaging complete!
echo  Output: %OUT_DIR%
echo ============================================================
start "" "C:\Program Files\Steam\steamapps\common\KingdomComeDeliverance2\Bin\Win64MasterMasterSteamPGO\KingdomCome.exe"
goto :end

:error
echo.
echo ============================================================
echo  Packaging FAILED. See errors above.
echo ============================================================
exit /b 1

:end
endlocal