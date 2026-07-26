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
  [string]$Version = "4.0.0"
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$fpcBin = Join-Path $Lazarus "fpc\3.2.2\bin\i386-win32"
$lazbuild = Join-Path $Lazarus "lazbuild.exe"

function Step($msg) { Write-Host "==> $msg" -ForegroundColor Cyan }
function Die($msg) { Write-Host "FAILED: $msg" -ForegroundColor Red; exit 1 }

if (-not (Test-Path $lazbuild)) { Die "lazbuild not found at $lazbuild (32-bit Lazarus is required, the project targets win32)" }

# --- the hex editor component lives in a zip to keep the tree small ---
if (-not (Test-Path "$root\mphexeditor")) {
  Step "extracting mphexeditor.zip"
  Expand-Archive -Path "$root\mphexeditor.zip" -DestinationPath $root -Force
}
$lpk = (Get-ChildItem -Recurse -Filter "mphexeditorlaz.lpk" $root | Select-Object -First 1).FullName
Step "registering $((Split-Path -Leaf $lpk))"
& $lazbuild --add-package-link $lpk | Out-Null

# --- tests first, they need no hardware ---
Step "running tests"
$testDir = Join-Path $env:TEMP "aspx-tests"
Remove-Item -Recurse -Force $testDir -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force $testDir | Out-Null
Copy-Item "$root\tests\*.lpr","$root\tests\spi25.pas" $testDir
Copy-Item "$root\software\fileformats.pas","$root\software\sfdp.pas",
          "$root\software\jedec.pas","$root\software\serialnum.pas" $testDir

Push-Location $testDir
foreach ($t in @("fftest", "unittests")) {
  & "$fpcBin\fpc.exe" -Twin32 -Pi386 -Mobjfpc -Sh "$t.lpr" | Out-Null
  if (-not (Test-Path "$testDir\$t.exe")) { Pop-Location; Die "$t did not compile" }
  & "$testDir\$t.exe"
  if ($LASTEXITCODE -ne 0) { Pop-Location; Die "$t reported failures" }
}
Pop-Location

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
