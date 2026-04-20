@echo off
echo Starting dynamic conversion...
echo -----------------------------------

:: Create a temporary PowerShell script to handle the complex text replacement
set "ps_script=%temp%\convert_audio.ps1"

echo $ErrorActionPreference = "Stop" > "%ps_script%"
echo if (!(Get-Command ffmpeg -ErrorAction SilentlyContinue)) { Write-Host "[ERROR] FFmpeg not found. Please install it." -ForegroundColor Red; Pause; exit } >> "%ps_script%"
echo $out = "Ready_For_Game" >> "%ps_script%"
echo if (!(Test-Path $out)) { New-Item -ItemType Directory -Path $out ^| Out-Null } >> "%ps_script%"
echo Get-ChildItem -Filter "*.wav" ^| ForEach-Object { >> "%ps_script%"
echo     $name = $_.BaseName >> "%ps_script%"
echo     $name = $name -replace '_\(No Noise\)', '' >> "%ps_script%"
echo     $name = $name -replace '_\(No Reverb\)', '' >> "%ps_script%"
echo     $name = $name -replace '^\d+_\d+_', '' >> "%ps_script%"
echo     $newName = "jstra_$name.ogg" >> "%ps_script%"
echo     Write-Host "Converting: $($_.Name) --^> $newName" >> "%ps_script%"
echo     ffmpeg -i $_.FullName -q:a 6 "$out\$newName" -loglevel error -y ^| Out-Null >> "%ps_script%"
echo } >> "%ps_script%"
echo Write-Host "-----------------------------------" >> "%ps_script%"
echo Write-Host "Success! All files converted dynamically." -ForegroundColor Green >> "%ps_script%"

:: Run the temporary script
powershell -NoProfile -ExecutionPolicy Bypass -File "%ps_script%"

:: Clean up
del "%ps_script%"
pause