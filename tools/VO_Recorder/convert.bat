@echo off
setlocal enabledelayedexpansion

echo Running Local AI Denoise and FFmpeg Conversion...
echo ---------------------------------------------------

if not exist "Temp_Clean" mkdir "Temp_Clean"
if not exist "Final_Game_Audio" mkdir "Final_Game_Audio"

:: Step 1: AI Denoise using DeepFilterNet via the Python module
echo [1/2] Stripping noise with AI...
for %%F in (*.wav) do (
    echo Denoising: %%F
    python -m df.enhance "%%F" -o "Temp_Clean"
)

:: Step 2: Volume Normalization, Fixing the Name, and OGG Conversion
echo [2/2] Normalizing and Converting to .ogg...
for %%C in (Temp_Clean\*.wav) do (
    :: Grab the file name
    set "filename=%%~nC"
    
    :: Automatically strip out the annoying suffix DeepFilterNet adds
    set "filename=!filename:_DeepFilterNet3=!"
    set "filename=!filename:_DeepFilterNet2=!"
    set "filename=!filename:_DeepFilterNet=!"
    
    :: Convert and save with the final clean name (-y auto-overwrites if you run it twice)
    ffmpeg -i "%%C" -af "loudnorm=I=-18:TP=-1.5:LRA=11" -c:a libvorbis -q:a 5 -y "Final_Game_Audio\jstra_!filename!.ogg"
)

echo ---------------------------------------------------
echo All done! Your crystal-clear files are in Final_Game_Audio.
pause