@echo off
setlocal

:: ==========================================
:: Configuration Variables
:: ==========================================
:: The directory to scan. "." means the current folder where the .bat is located.
set "SEARCH_DIR=."

:: The name of the output file.
set "OUTPUT_FILE=unique_functions.txt"

:: The word you are looking for.
set "SEARCH_WORD=Function"
:: ==========================================

echo Scanning directory for "%SEARCH_WORD%"...
echo Extracting unique lines to %OUTPUT_FILE%...
echo This might take a moment depending on the number of files...

:: Run the search, extraction, and deduplication command
powershell -NoProfile -Command ^
    "Get-ChildItem -Path '%SEARCH_DIR%' -File -Recurse -Exclude '%OUTPUT_FILE%' | " ^
    "Select-String -Pattern '%SEARCH_WORD%' -SimpleMatch | " ^
    "Select-Object -ExpandProperty Line | " ^
    "Select-Object -Unique | " ^
    "Out-File -FilePath '%OUTPUT_FILE%' -Encoding UTF8"

echo.
echo Process Complete! Check %OUTPUT_FILE% for the results.
pause