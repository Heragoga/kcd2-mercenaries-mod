@echo off
setlocal

:: ============================================================
::  KCD2 Mercenaries Mod - Auto Translator
::  Run from the root of the repository.
::
::  Requires Python 3.9+. No pip packages needed (uses stdlib only).
::
::  API Key (pick one):
::    1. Set DEEPL_API_KEY environment variable
::    2. Create a .env file next to translate.py:
::         DEEPL_API_KEY=your_key_here
::    3. Pass it directly: translate.bat --api-key your_key_here
:: ============================================================

set "SCRIPT_DIR=%~dp0"
set "SCRIPT=%SCRIPT_DIR%tools\translate.py"
set "LOC_DIR=%SCRIPT_DIR%localization"

:: Check Python is available
python --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Python not found. Install Python 3.9+ and make sure it's on PATH.
    pause
    exit /b 1
)

:: Check script exists
if not exist "%SCRIPT%" (
    echo ERROR: translate.py not found at %SCRIPT%
    pause
    exit /b 1
)

echo ============================================================
echo  KCD2 Mercenaries Mod - Auto Translator
echo ============================================================
echo  Localization dir: %LOC_DIR%
echo.

:: Forward any extra arguments (e.g. --dry-run, --langs German_xml)
python "%SCRIPT%" --loc-dir "%LOC_DIR%" %*

if errorlevel 1 (
    echo.
    echo Translation FAILED.
    pause
    exit /b 1
)

pause
endlocal