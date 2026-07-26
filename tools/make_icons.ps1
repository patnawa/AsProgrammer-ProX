# สร้างชุดไอคอนของแถบเครื่องมือ AsProgrammer ProX
#
# วาดสัญลักษณ์จากฟอนต์ Segoe Fluent Icons / Segoe MDL2 Assets ลงบนแผ่นสี่เหลี่ยม
# มุมมนที่ระบายสีอ่อน ๆ ตามหน้าที่ของปุ่ม ให้ดูเป็นชุดเดียวกันและอ่านออกง่าย
# ทั้งบนธีมสว่างและธีมมืด
#
#   powershell -ExecutionPolicy Bypass -File tools\make_icons.ps1
#
# ไฟล์ออกที่ software\icons\modern\ โปรแกรมโหลดโฟลเดอร์นี้ตอนเปิด
# จึงเปลี่ยนไอคอนได้โดยไม่ต้อง build ใหม่

Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent $PSScriptRoot
$out = Join-Path $root "software\icons\modern"
New-Item -ItemType Directory -Force $out | Out-Null

$fontName = "Segoe Fluent Icons"
$installed = (New-Object System.Drawing.Text.InstalledFontCollection).Families.Name
if ($installed -notcontains $fontName) { $fontName = "Segoe MDL2 Assets" }
if ($installed -notcontains $fontName) { throw "ไม่พบฟอนต์ Segoe icon บนเครื่องนี้" }
Write-Host "ใช้ฟอนต์: $fontName"

# ลำดับต้องตรงกับ ImageIndex ใน main.lfm
#   0 write  1 read  2 id  3 save  4 open  5 erase  6 verify  7 unlock  8 cancel
$icons = @(
  @{ n = "00_write";  g = [char]0xE898; c = "#C2410C" }  # Upload
  @{ n = "01_read";   g = [char]0xE896; c = "#0B5FB0" }  # Download
  @{ n = "02_id";     g = [char]0xE721; c = "#6D28D9" }  # Search
  @{ n = "03_save";   g = [char]0xE74E; c = "#44546A" }  # Save
  @{ n = "04_open";   g = [char]0xE8E5; c = "#44546A" }  # OpenFile
  @{ n = "05_erase";  g = [char]0xE75C; c = "#B3261E" }  # Clear
  @{ n = "06_verify"; g = [char]0xE73E; c = "#0B7A43" }  # CheckMark
  @{ n = "07_unlock"; g = [char]0xE785; c = "#B45309" }  # Unlock
  @{ n = "08_cancel"; g = [char]0xE711; c = "#B3261E" }  # Cancel
)

$size = 40          # ขนาดผืนผ้าใบ
$pad = 3            # ระยะขอบของแผ่นสีพื้นหลัง
$radius = 9         # รัศมีมุมมน
$glyphPx = 21       # ขนาดสัญลักษณ์

function New-RoundedPath([int]$x, [int]$y, [int]$w, [int]$h, [int]$r) {
  $p = New-Object System.Drawing.Drawing2D.GraphicsPath
  $d = $r * 2
  $p.AddArc($x, $y, $d, $d, 180, 90)
  $p.AddArc(($x + $w - $d), $y, $d, $d, 270, 90)
  $p.AddArc(($x + $w - $d), ($y + $h - $d), $d, $d, 0, 90)
  $p.AddArc($x, ($y + $h - $d), $d, $d, 90, 90)
  $p.CloseFigure()
  return $p
}

foreach ($i in $icons) {
  $bmp = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
  $g.Clear([System.Drawing.Color]::Transparent)

  $col = [System.Drawing.ColorTranslator]::FromHtml($i.c)

  # แผ่นพื้นหลังสีจาง ๆ ทำให้ปุ่มมีน้ำหนักและดูเป็นชุดเดียวกัน
  $fill = [System.Drawing.Color]::FromArgb(38, $col.R, $col.G, $col.B)
  $edge = [System.Drawing.Color]::FromArgb(90, $col.R, $col.G, $col.B)
  $path = New-RoundedPath $pad $pad ($size - $pad * 2) ($size - $pad * 2) $radius
  $bg = New-Object System.Drawing.SolidBrush($fill)
  $pen = New-Object System.Drawing.Pen($edge, 1.2)
  $g.FillPath($bg, $path)
  $g.DrawPath($pen, $path)

  $font = New-Object System.Drawing.Font($fontName, $glyphPx, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
  $brush = New-Object System.Drawing.SolidBrush($col)
  $fmt = New-Object System.Drawing.StringFormat
  $fmt.Alignment = [System.Drawing.StringAlignment]::Center
  $fmt.LineAlignment = [System.Drawing.StringAlignment]::Center

  $rect = New-Object System.Drawing.RectangleF(0, 0, $size, $size)
  $g.DrawString([string]$i.g, $font, $brush, $rect, $fmt)

  $g.Dispose()
  $bmp.Save((Join-Path $out ($i.n + ".png")), [System.Drawing.Imaging.ImageFormat]::Png)
  $bmp.Dispose()
  $font.Dispose(); $brush.Dispose(); $fmt.Dispose(); $bg.Dispose(); $pen.Dispose(); $path.Dispose()
  Write-Host ("  " + $i.n + ".png")
}

Write-Host "เสร็จ -> $out"
