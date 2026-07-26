# Generates the AsProgrammer ProX toolbar icon set.
#
# Draws Segoe Fluent Icons / Segoe MDL2 Assets glyphs into 32x32 PNGs with an
# accent colour per action. Run it from anywhere:
#
#   powershell -ExecutionPolicy Bypass -File tools\make_icons.ps1
#
# Output goes to software\icons\modern\. The program loads that folder at
# startup, so the icons can be changed without rebuilding.

Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent $PSScriptRoot
$out = Join-Path $root "software\icons\modern"
New-Item -ItemType Directory -Force $out | Out-Null

# Pick whichever icon font this Windows has
$fontName = "Segoe Fluent Icons"
$installed = (New-Object System.Drawing.Text.InstalledFontCollection).Families.Name
if ($installed -notcontains $fontName) { $fontName = "Segoe MDL2 Assets" }
if ($installed -notcontains $fontName) { throw "No Segoe icon font found on this system" }
Write-Host "Using font: $fontName"

# index, file name, glyph, accent colour
# The index must match ImageIndex in main.lfm:
#   0 write  1 read  2 id  3 save  4 open  5 erase  6 verify  7 unlock  8 cancel
#
# Colours are deliberately mid-tone so the same set stays legible on the light
# theme (near white chrome) and on the dark one.
$icons = @(
  @{ n = "00_write";  g = [char]0xE898; c = "#D97706" }  # Upload
  @{ n = "01_read";   g = [char]0xE896; c = "#0A6ED1" }  # Download
  @{ n = "02_id";     g = [char]0xE721; c = "#7C3AED" }  # Search
  @{ n = "03_save";   g = [char]0xE74E; c = "#546575" }  # Save
  @{ n = "04_open";   g = [char]0xE8E5; c = "#546575" }  # OpenFile
  @{ n = "05_erase";  g = [char]0xE75C; c = "#D93025" }  # Clear
  @{ n = "06_verify"; g = [char]0xE73E; c = "#0F9D58" }  # CheckMark
  @{ n = "07_unlock"; g = [char]0xE785; c = "#D97706" }  # Unlock
  @{ n = "08_cancel"; g = [char]0xE711; c = "#D93025" }  # Cancel
)

$size = 32

foreach ($i in $icons) {
  $bmp = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
  $g.Clear([System.Drawing.Color]::Transparent)

  $font = New-Object System.Drawing.Font($fontName, 19, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
  $col = [System.Drawing.ColorTranslator]::FromHtml($i.c)
  $brush = New-Object System.Drawing.SolidBrush($col)

  $fmt = New-Object System.Drawing.StringFormat
  $fmt.Alignment = [System.Drawing.StringAlignment]::Center
  $fmt.LineAlignment = [System.Drawing.StringAlignment]::Center

  $rect = New-Object System.Drawing.RectangleF(0, 0, $size, $size)
  $g.DrawString([string]$i.g, $font, $brush, $rect, $fmt)

  $g.Dispose()
  $path = Join-Path $out ($i.n + ".png")
  $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
  $bmp.Dispose()
  $font.Dispose(); $brush.Dispose(); $fmt.Dispose()
  Write-Host ("  " + $i.n + ".png")
}

Write-Host "Done -> $out"
