@echo off
setlocal enabledelayedexpansion

echo Engaging FFmpeg: Stripping absolute silence and adding "jstra_" prefix...
echo ---------------------------------------------------

:: Loop through every file in the current folder
for %%F in (*) do (
    set "filename=%%~nxF"
    
    :: Prevent the script from processing itself
    if not "!filename!"=="%~nx0" (
        
        :: Prevent processing files that already have the prefix
        if /I not "!filename:~0,6!"=="jstra_" (
            echo Processing: !filename!
            
            :: Run FFmpeg to strip silence and export with the new name
            ffmpeg -i "%%F" -af "silenceremove=start_periods=1:start_duration=0.1:start_threshold=-90dB:stop_periods=-1:stop_duration=0.1:stop_threshold=-90dB" -y "jstra_!filename!"
        )
    )
)

echo ---------------------------------------------------
echo Mission Accomplished.
pause