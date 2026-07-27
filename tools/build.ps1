# Builds AsProgrammer ProX, runs the tests, and assembles a release folder.
#
#   powershell -ExecutionPolicy Bypass -File tools\build.ps1
#   powershell -ExecutionPolicy Bypass -File tools\build.ps1 -Release
#
# -Release also zips the result into release\AsProgrammer-ProX-<version>.zip,
# with the runtime DLLs and data files already in place, so the zip is what
# someone can actually run. The DLLs are fetched from the upstream release the
# first time, because they are not kept in the repository.

param(
  [switch]$Release,
  [string]$Lazarus = "C:\lazarus32",
  [string]$Version = ""
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$fpcBin = Join-Path $Lazarus "fpc\3.2.2\bin\i386-win32"
$lazbuild = Join-Path $Lazarus "lazbuild.exe"

function Step($msg) { Write-Host "==> $msg" -ForegroundColor Cyan }
function Die($msg) { Write-Host "FAILED: $msg" -ForegroundColor Red; exit 1 }

if (-not (Test-Path $lazbuild)) { Die "lazbuild not found at $lazbuild (32-bit Lazarus is required, the project targets win32)" }

# --- the version lives in software\appver.pas; everything else must agree ---
# The number goes into the About box, the log banner and the exe resource, so a
# stale copy in one of them is worse than no number at all.
$verSrc = Get-Content "$root\software\appver.pas" -Raw
if ($verSrc -notmatch "PROX_VERSION\s*=\s*'([0-9.]+)'") { Die "no PROX_VERSION in software\appver.pas" }
$proxVersion = $Matches[1]

$lpiSrc = Get-Content "$root\software\AsProgrammer.lpi" -Raw
if ($lpiSrc -notmatch 'ProductVersion="([0-9.]+)"') { Die "no ProductVersion in AsProgrammer.lpi" }
if ($Matches[1] -ne $proxVersion) {
  Die "version mismatch: appver.pas says $proxVersion, AsProgrammer.lpi says $($Matches[1]). Bump both."
}
Step "version $proxVersion"

# The zip name follows the same number unless the caller overrides it.
if ($Version -eq "") { $Version = $proxVersion }

# --- the hex editor component lives in a zip to keep the tree small ---
if (-not (Test-Path "$root\mphexeditor")) {
  Step "extracting mphexeditor.zip"
  Expand-Archive -Path "$root\mphexeditor.zip" -DestinationPath $root -Force
}
$lpk = (Get-ChildItem -Recurse -Filter "mphexeditorlaz.lpk" $root | Select-Object -First 1).FullName
Step "registering $((Split-Path -Leaf $lpk))"
& $lazbuild --add-package-link $lpk | Out-Null

# --- the chip tables, before anything is compiled ---
# A typo here breaks one chip and nothing else, which means it is only found
# when somebody puts that exact part in the socket. Catch it now instead.
Step "checking the chip tables"
$python = (Get-Command python -ErrorAction SilentlyContinue)
if ($python) {
  & $python.Source "$root\tools\validate_chiplist.py" "$root\chiplist.xml" `
    $(if (Test-Path "$root\chiplist-flashrom.xml") { "$root\chiplist-flashrom.xml" }) `
    $(if (Test-Path "$root\chiplist-ezp.xml") { "$root\chiplist-ezp.xml" })
  if ($LASTEXITCODE -ne 0) { Die "the chip tables have errors" }
} else {
  Write-Host "    python not found, skipped" -ForegroundColor Yellow
}

# --- tests, they need no hardware ---
#
# Two directories, because the two suites need different versions of spi25:
# the logic tests link a stub that serves a synthetic SFDP image, while the
# protocol tests link the real unit and drive it through a mock programmer.
# Put both in one directory and whichever spi25.pas landed last would win.
Step "running tests"

function Run-Suite($name, $dir, $files) {
  Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue
  New-Item -ItemType Directory -Force $dir | Out-Null
  Copy-Item $files $dir
  Push-Location $dir
  & "$fpcBin\fpc.exe" -Twin32 -Pi386 -Mobjfpc -Sh "$name.lpr" | Out-Null
  if (-not (Test-Path "$dir\$name.exe")) { Pop-Location; Die "$name did not compile" }
  & "$dir\$name.exe"
  $code = $LASTEXITCODE
  Pop-Location
  if ($code -ne 0) { Die "$name reported failures" }
}

# pure logic: SFDP parsing, protection bits, results, production log, formats
$logicDir = Join-Path $env:TEMP "aspx-tests-logic"
Run-Suite "fftest" $logicDir @(
  "$root\tests\fftest.lpr", "$root\tests\spi25.pas",
  "$root\software\fileformats.pas")
Run-Suite "unittests" $logicDir @(
  "$root\tests\unittests.lpr", "$root\tests\spi25.pas",
  "$root\software\sfdp.pas", "$root\software\jedec.pas",
  "$root\software\serialnum.pas", "$root\software\protbits.pas",
  "$root\software\opresult.pas", "$root\software\prodlog.pas",
  "$root\software\fileformats.pas", "$root\software\flashops.pas")

# the real SPI 25 and I2C protocol layers, driven through a programmer that is
# all in memory
$hwDir = Join-Path $env:TEMP "aspx-tests-hw"
Run-Suite "hwtests" $hwDir @(
  "$root\tests\hwtests.lpr", "$root\tests\mockhw.pas",
  "$root\software\spi25.pas", "$root\software\basehw.pas",
  "$root\software\utilfunc.pas", "$root\software\i2c.pas")

# --- the program ---
Step "building AsProgrammer.exe"
& $lazbuild --build-mode=Release "$root\software\AsProgrammer.lpi" | Out-Null
if ($LASTEXITCODE -ne 0) { Die "the build failed" }
$exe = "$root\software\AsProgrammer.exe"
if (-not (Test-Path $exe)) { Die "no executable was produced" }
Write-Host ("    {0:N0} bytes" -f (Get-Item $exe).Length)

if (-not $Release) { Step "done"; exit 0 }

# --- release folder ---
$out = Join-Path $root "release\AsProgrammer-ProX-$Version"
Step "assembling $out"
Remove-Item -Recurse -Force $out -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force $out | Out-Null

Copy-Item $exe $out
Copy-Item "$root\chiplist.xml","$root\settings.xml" $out
if (Test-Path "$root\chiplist-flashrom.xml") { Copy-Item "$root\chiplist-flashrom.xml" $out }
if (Test-Path "$root\chiplist-ezp.xml") { Copy-Item "$root\chiplist-ezp.xml" $out }
Copy-Item "$root\LICENSE","$root\README.md" $out
Copy-Item "$root\scripts" $out -Recurse
Copy-Item "$root\software\lang" $out -Recurse
New-Item -ItemType Directory -Force "$out\icons" | Out-Null
Copy-Item "$root\software\icons\modern" "$out\icons" -Recurse

# DLLs the program links against. They are not in the repository, so take them
# from the upstream release, which is where they have always been published.
$dlls = "CH341DLL.DLL","CH347DLL.DLL","ftd2xx.dll","libusb0.dll",
        "buzzpirathlp.dll","libiconv2.dll","libintl3.dll"
$cache = Join-Path $env:TEMP "aspx-dlls"
$missing = $dlls | Where-Object { -not (Test-Path (Join-Path $cache $_)) }

if ($missing) {
  Step "fetching the runtime DLLs from the upstream release"
  New-Item -ItemType Directory -Force $cache | Out-Null
  $zip = Join-Path $env:TEMP "upstream.zip"
  $url = "https://github.com/therealdreg/asprogrammer-dregmod/releases/download/v3.17/asprogrammer-dregmod-v3.17.zip"
  curl.exe -sL --fail -o $zip $url
  if (-not (Test-Path $zip)) { Die "could not download the upstream release for the DLLs" }
  $tmp = Join-Path $env:TEMP "upstream-extract"
  Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
  Expand-Archive -Path $zip -DestinationPath $tmp -Force
  foreach ($d in $dlls) {
    $found = Get-ChildItem -Recurse -Filter $d $tmp | Select-Object -First 1
    if ($found) { Copy-Item $found.FullName $cache -Force }
  }
}

foreach ($d in $dlls) {
  $p = Join-Path $cache $d
  if (Test-Path $p) { Copy-Item $p $out } else { Write-Host "    missing $d" -ForegroundColor Yellow }
}

$zipOut = "$root\release\AsProgrammer-ProX-$Version.zip"
Remove-Item $zipOut -ErrorAction SilentlyContinue
Compress-Archive -Path "$out\*" -DestinationPath $zipOut
Step ("done -> {0} ({1:N0} bytes)" -f $zipOut, (Get-Item $zipOut).Length)
