# สร้างไอคอนของโปรแกรม AsProgrammer ProX
#
#   powershell -ExecutionPolicy Bypass -File tools\make_appicon.ps1
#
# วาดรูปชิปแฟลชแบบ SOIC มองจากด้านบน แล้วประกอบเป็นไฟล์ .ico หลายขนาด
# ที่ software\AsProgrammer.ico
#
# ขนาด 16 ถึง 128 เก็บเป็น DIB 32 บิต ส่วน 256 เก็บเป็น PNG ตามที่ Windows
# รองรับ วิธีนี้ทำให้ทั้ง Explorer และตัวอ่านไอคอนของ Lazarus เปิดได้ทั้งคู่

Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent $PSScriptRoot
$outIco = Join-Path $root "software\AsProgrammer.ico"

$sizes = 16, 24, 32, 48, 64, 128, 256

function New-RoundedPath([single]$x, [single]$y, [single]$w, [single]$h, [single]$r) {
  $p = New-Object System.Drawing.Drawing2D.GraphicsPath
  $d = $r * 2
  $p.AddArc($x, $y, $d, $d, 180, 90)
  $p.AddArc(($x + $w - $d), $y, $d, $d, 270, 90)
  $p.AddArc(($x + $w - $d), ($y + $h - $d), $d, $d, 0, 90)
  $p.AddArc($x, ($y + $h - $d), $d, $d, 90, 90)
  $p.CloseFigure()
  return $p
}

function Draw-Icon([int]$s) {
  $bmp = New-Object System.Drawing.Bitmap($s, $s, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $g.Clear([System.Drawing.Color]::Transparent)

  $u = $s / 32.0    # หน่วยอ้างอิง ออกแบบบนผืน 32x32 แล้วขยายตาม

  # พื้นหลังมุมมนสีเข้ม ให้ไอคอนมีรูปทรงชัดบนพื้นสว่างและพื้นมืด
  $bgPath = New-RoundedPath (1.5*$u) (1.5*$u) ($s - 3*$u) ($s - 3*$u) (6*$u)
  $bgBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    (New-Object System.Drawing.Point(0,0)),
    (New-Object System.Drawing.Point($s,$s)),
    [System.Drawing.ColorTranslator]::FromHtml("#243447"),
    [System.Drawing.ColorTranslator]::FromHtml("#111820"))
  $g.FillPath($bgBrush, $bgPath)

  # ขาชิปสองข้าง
  $pin = New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml("#C8D3DF"))
  $pinW = 2.6*$u; $pinH = 1.5*$u
  for ($i = 0; $i -lt 4; $i++) {
    $y = (10.5 + $i * 3.2) * $u
    $g.FillRectangle($pin, (6.2*$u), $y, $pinW, $pinH)
    $g.FillRectangle($pin, ($s - 6.2*$u - $pinW), $y, $pinW, $pinH)
  }

  # ตัวชิป
  $bodyPath = New-RoundedPath (8.5*$u) (9*$u) ($s - 17*$u) ($s - 18*$u) (1.6*$u)
  $body = New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml("#0E1620"))
  $edge = New-Object System.Drawing.Pen([System.Drawing.ColorTranslator]::FromHtml("#3E5670"), (0.9*$u))
  $g.FillPath($body, $bodyPath)
  $g.DrawPath($edge, $bodyPath)

  # จุดบอกตำแหน่งขา 1
  $dot = New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml("#2BB3F3"))
  $g.FillEllipse($dot, (10*$u), (10.5*$u), (2.2*$u), (2.2*$u))

  # ลูกศรลง สื่อถึงการเขียนข้อมูลลงชิป
  if ($s -ge 24) {
    $acc = New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml("#2BB3F3"))
    $pen2 = New-Object System.Drawing.Pen([System.Drawing.ColorTranslator]::FromHtml("#2BB3F3"), (1.8*$u))
    $pen2.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $cxm = $s / 2.0
    $g.DrawLine($pen2, $cxm, (13.5*$u), $cxm, (19.5*$u))
    $tri = @(
      (New-Object System.Drawing.PointF(($cxm - 3.0*$u), (18.6*$u))),
      (New-Object System.Drawing.PointF(($cxm + 3.0*$u), (18.6*$u))),
      (New-Object System.Drawing.PointF($cxm, (22.6*$u)))
    )
    $g.FillPolygon($acc, $tri)
    $pen2.Dispose(); $acc.Dispose()
  }

  $g.Dispose()
  $bgBrush.Dispose(); $pin.Dispose(); $body.Dispose(); $edge.Dispose(); $dot.Dispose(); $bgPath.Dispose(); $bodyPath.Dispose()
  return $bmp
}

# ---- ประกอบไฟล์ .ico ----
$entries = @()
foreach ($s in $sizes) {
  $bmp = Draw-Icon $s
  if ($s -eq 256) {
    $ms = New-Object System.IO.MemoryStream
    $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
    $data = $ms.ToArray()
    $ms.Dispose()
  } else {
    # DIB: BITMAPINFOHEADER ที่ระบุความสูงสองเท่า ตามด้วยพิกเซล BGRA เรียงจากล่างขึ้นบน แล้วต่อด้วย AND mask
    $hdr = New-Object System.IO.MemoryStream
    $bw = New-Object System.IO.BinaryWriter($hdr)
    $bw.Write([uint32]40); $bw.Write([int32]$s); $bw.Write([int32]($s*2))
    $bw.Write([uint16]1); $bw.Write([uint16]32); $bw.Write([uint32]0)
    $bw.Write([uint32]($s*$s*4)); $bw.Write([int32]0); $bw.Write([int32]0)
    $bw.Write([uint32]0); $bw.Write([uint32]0)
    for ($y = $s - 1; $y -ge 0; $y--) {
      for ($x = 0; $x -lt $s; $x++) {
        $c = $bmp.GetPixel($x, $y)
        $bw.Write([byte]$c.B); $bw.Write([byte]$c.G); $bw.Write([byte]$c.R); $bw.Write([byte]$c.A)
      }
    }
    $maskRow = [math]::Floor(($s + 31) / 32) * 4
    for ($y = 0; $y -lt $s; $y++) { $bw.Write((New-Object byte[] $maskRow)) }
    $bw.Flush()
    $data = $hdr.ToArray()
    $bw.Dispose(); $hdr.Dispose()
  }
  $entries += ,@{ Size = $s; Data = $data }
  $bmp.Dispose()
}

$fs = [System.IO.File]::Create($outIco)
$w = New-Object System.IO.BinaryWriter($fs)
$w.Write([uint16]0); $w.Write([uint16]1); $w.Write([uint16]$entries.Count)
$offset = 6 + 16 * $entries.Count
foreach ($e in $entries) {
  $dim = if ($e.Size -ge 256) { 0 } else { $e.Size }
  $w.Write([byte]$dim); $w.Write([byte]$dim)
  $w.Write([byte]0); $w.Write([byte]0)
  $w.Write([uint16]1); $w.Write([uint16]32)
  $w.Write([uint32]$e.Data.Length); $w.Write([uint32]$offset)
  $offset += $e.Data.Length
}
foreach ($e in $entries) { $w.Write($e.Data) }
$w.Flush(); $w.Dispose(); $fs.Dispose()

Write-Host ("เขียน {0} ({1:N0} ไบต์, {2} ขนาด)" -f $outIco, (Get-Item $outIco).Length, $entries.Count)
