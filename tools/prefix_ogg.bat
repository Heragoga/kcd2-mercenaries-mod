@echo off
setlocal

set "SOURCE_DIR=."

for %%f in ("%SOURCE_DIR%\*.ogg") do (
    copy "%%f" "%SOURCE_DIR%\jcom_%%~nxf" >nul
    copy "%%f" "%SOURCE_DIR%\phos2_%%~nxf" >nul
    copy "%%f" "%SOURCE_DIR%\sbar_%%~nxf" >nul
    echo Created variants for: %%~nxf
)

echo.
echo Done.
pause