# Captures the primary screen to .cache/shots/<timestamp>.png and prints the path.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
$dir = Join-Path (Split-Path -Parent $PSScriptRoot) '.cache\shots'
New-Item -ItemType Directory -Force $dir | Out-Null
$b = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
$bmp = New-Object System.Drawing.Bitmap $b.Width, $b.Height
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen($b.Location, [System.Drawing.Point]::Empty, $b.Size)
$path = Join-Path $dir ("{0:yyyyMMdd-HHmmss}.png" -f (Get-Date))
$bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose()
Write-Output $path
