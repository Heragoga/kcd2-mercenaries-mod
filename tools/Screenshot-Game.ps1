# Capture the primary screen to a PNG - for seeing what the game is actually showing when
# a keystroke-driven harness step fails (a menu that does not load, a dialog nobody knew
# about, a death screen). The harness cannot read the UI; this is the next best thing.
#
#   powershell -ExecutionPolicy Bypass -File tools\Screenshot-Game.ps1 [-Path out.png]
param(
    [string]$Path = (Join-Path $env:TEMP ("kcd2_screen_" + (Get-Date -Format "HHmmss") + ".png"))
)
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$b = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
$bmp = New-Object System.Drawing.Bitmap $b.Width, $b.Height
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen($b.Location, [System.Drawing.Point]::Empty, $b.Size)
$g.Dispose()
$bmp.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
Write-Output $Path
