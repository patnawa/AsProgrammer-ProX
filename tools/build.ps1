# Builds AsProgrammer ProX, runs the tests, and assembles a release folder.
#
#   powershell -ExecutionPolicy Bypass -File tools\build.ps1
#   powershell -ExecutionPolicy Bypass -File tools\build.ps1 -Release
#
# -Release also zips the result into release\Chipwright-<version>.zip,
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

function Assert-Sha256($Path, $Expected, $Label) {
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    Die "$Label is missing: $Path"
  }
  $actual = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
  if ($actual -ne $Expected.ToUpperInvariant()) {
    Die "$Label SHA-256 mismatch: expected $Expected, got $actual"
  }
}

function Download-PinnedFile($Url, $Destination, $Sha256, $Label) {
  & curl.exe -L --fail --retry 3 --proto '=https' --tlsv1.2 `
    -o $Destination $Url
  if ($LASTEXITCODE -ne 0) { Die "could not download $Label" }
  Assert-Sha256 $Destination $Sha256 $Label
}

if (-not (Test-Path $lazbuild)) { Die "lazbuild not found at $lazbuild (32-bit Lazarus is required, the project targets win32)" }

# --- the version lives in software\appver.pas; everything else must agree ---
# The number goes into the About box, the log banner and the exe resource, so a
# stale copy in one of them is worse than no number at all.
$verSrc = Get-Content "$root\software\appver.pas" -Raw
if ($verSrc -notmatch "PROX_VERSION\s*=\s*'([0-9.]+)'") { Die "no PROX_VERSION in software\appver.pas" }
$proxVersion = $Matches[1]

$lpiSrc = Get-Content "$root\software\AsProgrammer.lpi" -Raw
if ($lpiSrc -notmatch 'ProductVersion="([0-9.]+)"') { Die "no ProductVersion in AsProgrammer.lpi" }
$lpiProductVersion = $Matches[1]
$lpiParts = @(
  @('MajorVersionNr', '<MajorVersionNr Value="([0-9]+)"'),
  @('MinorVersionNr', '<MinorVersionNr Value="([0-9]+)"'),
  @('RevisionNr', '<RevisionNr Value="([0-9]+)"'),
  @('BuildNr', '<BuildNr Value="([0-9]+)"')
)
$lpiFileVersionParts = foreach ($part in $lpiParts) {
  if ($lpiSrc -notmatch $part[1]) { Die "no $($part[0]) in AsProgrammer.lpi" }
  $Matches[1]
}
$lpiFileVersion = $lpiFileVersionParts -join '.'
if (($lpiProductVersion -ne $proxVersion) -or ($lpiFileVersion -ne $proxVersion)) {
  Die "version mismatch: appver.pas says $proxVersion, AsProgrammer.lpi ProductVersion says $lpiProductVersion and FileVersion says $lpiFileVersion. Bump all fields."
}
Step "version $proxVersion"

$python = (Get-Command python -ErrorAction SilentlyContinue)
if ($python) {
  Step "checking release, suite and localization metadata"
  & $python.Source "$root\tools\check_project_metadata.py"
  if ($LASTEXITCODE -ne 0) { Die "project metadata has drifted" }
}

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
if ($python) {
  & $python.Source "$root\tools\validate_chiplist.py" "$root\chiplist.xml" `
    $(if (Test-Path "$root\chiplist-flashrom.xml") { "$root\chiplist-flashrom.xml" }) `
    $(if (Test-Path "$root\chiplist-ezp.xml") { "$root\chiplist-ezp.xml" }) `
    $(if (Test-Path "$root\chiplist-imsprog.xml") { "$root\chiplist-imsprog.xml" })
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

function Run-Suite($name, $dir, $files, [switch]$WithSfdpCorpus) {
  Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue
  New-Item -ItemType Directory -Force $dir | Out-Null
  Copy-Item $files $dir
  if ($WithSfdpCorpus) {
    $corpusSource = "$root\tests\sfdp"
    if (-not (Test-Path "$corpusSource\manifest.txt")) {
      Die "the SFDP corpus manifest is missing"
    }
    $corpusDest = Join-Path $dir "sfdp"
    New-Item -ItemType Directory -Force $corpusDest | Out-Null
    Copy-Item "$corpusSource\*" $corpusDest -Force
  }
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
  "$root\software\fileformats.pas", "$root\software\flashops.pas",
  "$root\software\imgcheck.pas", "$root\software\ifd.pas",
  "$root\software\utilfunc.pas") -WithSfdpCorpus

# Focused JESD216 sector-map descriptor semantics.  Keep the synthetic spi25
# provider isolated from the real protocol unit used by the adapter suite.
$sfdpMapDir = Join-Path $env:TEMP "aspx-tests-sfdp-map"
Run-Suite "sfdp_sector_map_tests" $sfdpMapDir @(
  "$root\tests\sfdp_sector_map_tests.lpr", "$root\tests\spi25.pas",
  "$root\software\sfdp.pas")

# the real SPI 25 and I2C protocol layers, driven through a programmer that is
# all in memory
$hwDir = Join-Path $env:TEMP "aspx-tests-hw"
Run-Suite "hwtests" $hwDir @(
  "$root\tests\hwtests.lpr", "$root\tests\mockhw.pas",
  "$root\software\spi25.pas", "$root\software\basehw.pas",
  "$root\software\utilfunc.pas", "$root\software\i2c.pas",
  "$root\software\electricalpreflight.pas")

# Every backend advertises typed voltage, protocol and clock capabilities;
# unknown facts must remain unknown rather than becoming permissive defaults.
$capabilityDir = Join-Path $env:TEMP "aspx-tests-hardware-capability"
Run-Suite "hardwarecapability_tests" $capabilityDir @(
  "$root\tests\hardwarecapability_tests.lpr",
  "$root\software\basehw.pas", "$root\software\electricalpreflight.pas")

# The admission ladder between a button press and the bus: which facts have
# been established, and which of them a rail change or a fresh image revokes.
$sessionDir = Join-Path $env:TEMP "aspx-tests-session-state"
Run-Suite "sessionstate_tests" $sessionDir @(
  "$root\tests\sessionstate_tests.lpr", "$root\software\sessionstate.pas")

# What the operator is told about the target rail, and which electrical facts
# stop bench work rather than merely warning it.
$railDir = Join-Path $env:TEMP "aspx-tests-rail-report"
Run-Suite "railreport_tests" $railDir @(
  "$root\tests\railreport_tests.lpr", "$root\software\railreport.pas",
  "$root\software\electricalpreflight.pas")

# preservation-aware whole-operation service, including deterministic
# fail-at-every-call and randomized invariant checks
$norDir = Join-Path $env:TEMP "aspx-tests-nor"
Run-Suite "norengine_tests" $norDir @(
  "$root\tests\norengine_tests.lpr", "$root\tests\virtualspi25.pas",
  "$root\software\operationmodel.pas", "$root\software\norplanner.pas",
  "$root\software\norengine.pas")

# The EEPROM sibling of the NOR service: page-differential plans and the
# executor, with the same fault matrix and randomized invariants.
$eepromDir = Join-Path $env:TEMP "aspx-tests-eeprom"
Run-Suite "eepromengine_tests" $eepromDir @(
  "$root\tests\eepromengine_tests.lpr", "$root\tests\virtualeeprom.pas",
  "$root\software\operationmodel.pas", "$root\software\eepromengine.pas")

# The presentation-neutral operation facade: stable read, preview and write
# requests with one typed result/event contract for the headless CLI and tests.
# The GUI consumes the same planners and engines through its mature LCL bridge.
$runnerDir = Join-Path $env:TEMP "aspx-tests-operation-runner"
Run-Suite "operationrunner_tests" $runnerDir @(
  "$root\tests\operationrunner_tests.lpr", "$root\tests\virtualspi25.pas",
  "$root\software\operationmodel.pas", "$root\software\norplanner.pas",
  "$root\software\norengine.pas", "$root\software\operationrunner.pas")

# SPI NAND geometry and bad-block-aware planning: the arithmetic that decides
# whether a bad block is ever touched.
$nandDir = Join-Path $env:TEMP "aspx-tests-nand"
Run-Suite "nandplanner_tests" $nandDir @(
  "$root\tests\nandplanner_tests.lpr", "$root\software\nandmodel.pas",
  "$root\software\nandplanner.pas")

# The NAND executor against the virtual chip: ECC verdicts, P_FAIL/E_FAIL,
# silent protection, cancellation, the fault matrix, and the id catalog.
$nandEngineDir = Join-Path $env:TEMP "aspx-tests-nand-engine"
Run-Suite "nandengine_tests" $nandEngineDir @(
  "$root\tests\nandengine_tests.lpr", "$root\tests\virtualspinand.pas",
  "$root\software\nandmodel.pas", "$root\software\nandplanner.pas",
  "$root\software\nandengine.pas", "$root\software\nandcatalog.pas")

# Real TBaseHardware-to-NAND-device framing, including ambiguous command
# issuance, bounded status draining, and checked write-disable cleanup.
$nandAdapterDir = Join-Path $env:TEMP "aspx-tests-nand-adapter"
Run-Suite "nandadapter_tests" $nandAdapterDir @(
  "$root\tests\nandadapter_tests.lpr", "$root\tests\mockhw.pas",
  "$root\software\spi25nandadapter.pas", "$root\software\nandmodel.pas",
  "$root\software\nandengine.pas", "$root\software\nandplanner.pas",
  "$root\software\nandcatalog.pas", "$root\software\basehw.pas",
  "$root\software\electricalpreflight.pas")

# The capacity/counterfeit test engine against fake chips of every stripe;
# the invariant is that original content is always restored and verified.
$chipTestDir = Join-Path $env:TEMP "aspx-tests-chiptest"
Run-Suite "chiptest_tests" $chipTestDir @(
  "$root\tests\chiptest_tests.lpr", "$root\software\chiptest.pas")

# CH347 bulk-protocol packet layout: the bytes three projects had to
# reverse engineer, pinned so they can never drift.
$ch347Dir = Join-Path $env:TEMP "aspx-tests-ch347proto"
Run-Suite "ch347proto_tests" $ch347Dir @(
  "$root\tests\ch347proto_tests.lpr", "$root\software\ch347proto.pas")

# Real TBaseHardware-to-NOR-service adapter framing, identity gates, exact
# transfer counts, four-byte strategies, and exactly-once cleanup.
$adapterDir = Join-Path $env:TEMP "aspx-tests-spi25-adapter"
Run-Suite "spi25noradapter_tests" $adapterDir @(
  "$root\tests\adapter\spi25noradapter_tests.lpr",
  "$root\software\spi25noradapter.pas", "$root\software\spi25.pas",
  "$root\software\basehw.pas", "$root\software\utilfunc.pas",
  "$root\software\electricalpreflight.pas",
  "$root\software\operationmodel.pas", "$root\software\norplanner.pas",
  "$root\software\norengine.pas")

# legacy EEPROM/DataFlash protocols have different framing rules from SPI NOR
# and therefore keep their own stateful mock and suite
$legacyDir = Join-Path $env:TEMP "aspx-tests-legacy"
Run-Suite "legacy_protocol_tests" $legacyDir @(
  "$root\tests\legacy_protocol\legacy_protocol_tests.lpr",
  "$root\tests\legacy_protocol\legacy_mockhw.pas",
  "$root\software\basehw.pas", "$root\software\utilfunc.pas",
  "$root\software\electricalpreflight.pas",
  "$root\software\spi25.pas", "$root\software\i2c.pas",
  "$root\software\spi95.pas", "$root\software\spi45.pas",
  "$root\software\microwire.pas")

# authenticated production manifests, durable evidence, and typed electrical
# capability/preflight policy (Windows CNG supplies SHA-256/HMAC)
$productionDir = Join-Path $env:TEMP "aspx-tests-production"
Run-Suite "stage9tests" $productionDir @(
  "$root\tests\stage9tests.lpr", "$root\software\prodcrypto.pas",
  "$root\software\prodjob.pas", "$root\software\prodevidence.pas",
  "$root\software\prodstate.pas",
  "$root\software\electricalpreflight.pas",
  "$root\software\productiongate.pas")

# Stable canonical chip-definition bytes used by authenticated production
# manifests.  This suite is platform-independent even though CNG admission is
# exercised above only on Windows.
$profileDir = Join-Path $env:TEMP "aspx-tests-chip-profile"
Run-Suite "chipprofile_tests" $profileDir @(
  "$root\tests\chipprofile\chipprofile_tests.lpr",
  "$root\software\chipprofile.pas")

# --- the bench diagnostics in tools\ ---
# These are the programs someone reaches for when hardware misbehaves; a
# refactor in software\ (LibUSB.pas and friends) must not be able to break
# them unnoticed until they are needed at a bench. ezpspy\libusb0.dpr is a
# Delphi-dialect shim DLL and ch347smoke targets Linux, so both are skipped.
Step "building the tools"
foreach ($tool in "ezpsmoke", "ezpwrite", "ezppowercheck") {
  & "$fpcBin\fpc.exe" -Twin32 -Pi386 -Mobjfpc -Sh "-Fu$root\software" `
    "$root\tools\$tool.lpr" | Out-Null
  if (-not (Test-Path "$root\tools\$tool.exe")) { Die "$tool did not compile" }
  Write-Host "    $tool.exe"
}

# Build the LCL-free CLI with the same 32-bit compiler as the GUI. Unit and
# executable output stay in a private directory so source folders remain clean.
Step "building the headless CLI"
$headlessDir = Join-Path $env:TEMP "aspx-headless-cli-win32"
Remove-Item -LiteralPath $headlessDir -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path (Join-Path $headlessDir "units") -Force | Out-Null
& "$fpcBin\fpc.exe" -Twin32 -Pi386 -Mobjfpc -Sh `
  "-Fu$root\software" "-FU$headlessDir\units" "-FE$headlessDir" `
  "$root\software\AsProgrammerCLI.lpr" | Out-Null
$headlessExe = Join-Path $headlessDir "AsProgrammerCLI.exe"
if (($LASTEXITCODE -ne 0) -or -not (Test-Path -LiteralPath $headlessExe)) {
  Die "the headless Windows CLI did not compile"
}
Write-Host "    AsProgrammerCLI.exe"

# Parser boundary checks run without opening USB. These values wrap to 256
# and 4096 if a QWord is truncated before the geometry builder sees it.
foreach ($badGeometry in @(
  @{ Page = '4294967552'; Erase = '4096' },
  @{ Page = '256'; Erase = '4294971392' }
)) {
  $cliArgs = @('--smart-preview', 'unused.bin', '--size', '8388608',
    '--address', '0', '--page-size', $badGeometry.Page,
    '--erase-size', $badGeometry.Erase, '--erase-opcode', '20')
  & $headlessExe @cliArgs 2>&1 | Out-Null
  if ($LASTEXITCODE -ne 2) {
    Die "headless CLI admitted or mishandled overflowing geometry"
  }
}
Write-Host "    overflowing geometry refused before USB open"
& $headlessExe --detect --speeed 1 2>&1 | Out-Null
if ($LASTEXITCODE -ne 2) { Die "headless CLI ignored an unknown option" }
& $headlessExe --detect --detect 2>&1 | Out-Null
if ($LASTEXITCODE -ne 2) { Die "headless CLI accepted a duplicate option" }
Write-Host "    unknown and duplicate options refused before USB open"

# --- the program ---
Step "building AsProgrammer.exe"
& $lazbuild --build-mode=Release "$root\software\AsProgrammer.lpi" | Out-Null
if ($LASTEXITCODE -ne 0) { Die "the build failed" }
$exe = "$root\software\AsProgrammer.exe"
if (-not (Test-Path $exe)) { Die "no executable was produced" }
Write-Host ("    {0:N0} bytes" -f (Get-Item $exe).Length)

if (-not $Release) {
  Remove-Item -LiteralPath $headlessDir -Recurse -Force
  Step "done"
  exit 0
}

# --- release folder ---
$out = Join-Path $root "release\Chipwright-$Version"
Step "assembling $out"
Remove-Item -Recurse -Force $out -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force $out | Out-Null

# The build targets are still named AsProgrammer*.exe because the Lazarus
# project files are, but the shipped program is Chipwright. Rename on the way
# into the package so the download matches the application. Doing it here and
# not as a manual step afterwards is the point: CI rebuilds every tagged
# release from scratch, and a manual rename does not survive that.
Copy-Item $exe (Join-Path $out "Chipwright.exe")
Copy-Item $headlessExe (Join-Path $out "ChipwrightCLI.exe")
Remove-Item -LiteralPath $headlessDir -Recurse -Force
Copy-Item "$root\chiplist.xml","$root\settings.xml" $out
if (Test-Path "$root\chiplist-flashrom.xml") { Copy-Item "$root\chiplist-flashrom.xml" $out }
if (Test-Path "$root\chiplist-ezp.xml") { Copy-Item "$root\chiplist-ezp.xml" $out }
if (Test-Path "$root\chiplist-imsprog.xml") { Copy-Item "$root\chiplist-imsprog.xml" $out }
Copy-Item "$root\LICENSE","$root\README.md","$root\CHANGELOG.md",`
  "$root\CONTRIBUTING.md","$root\SECURITY.md",`
  "$root\THIRD_PARTY_NOTICES.md" $out
Copy-Item "$root\docs" $out -Recurse
Copy-Item "$root\scripts" $out -Recurse
Copy-Item "$root\software\lang" $out -Recurse
New-Item -ItemType Directory -Force "$out\icons" | Out-Null
Copy-Item "$root\software\icons\modern" "$out\icons" -Recurse
New-Item -ItemType Directory -Force "$out\drivers","$out\tools" | Out-Null
Copy-Item "$root\drivers\EZP2023Plus" "$out\drivers" -Recurse
Copy-Item "$root\tools\update_ezp_libusb1402.ps1" "$out\tools"

# The bundle checksum file covers the untouched vendor/upstream payload.
# Validate after copying so a Git checkout line-ending conversion, damaged
# source file, or packaging mistake cannot reach a GitHub release.
$driverRoot = "$out\drivers\EZP2023Plus"
$driverSums = Join-Path $driverRoot "SHA256SUMS.txt"
$driverHashCount = 0
foreach ($line in Get-Content -LiteralPath $driverSums) {
  if ([string]::IsNullOrWhiteSpace($line)) { continue }
  if ($line -notmatch '^([0-9a-fA-F]{64})  (.+)$') {
    Die "malformed EZP driver checksum line: $line"
  }
  $expectedHash = $Matches[1].ToUpperInvariant()
  $relativeDriverPath = $Matches[2].Replace(
    '/', [IO.Path]::DirectorySeparatorChar)
  $driverFile = Join-Path $driverRoot $relativeDriverPath
  if (-not (Test-Path -LiteralPath $driverFile -PathType Leaf)) {
    Die "EZP driver checksum names a missing file: $relativeDriverPath"
  }
  $actualHash = (Get-FileHash -LiteralPath $driverFile -Algorithm SHA256).Hash
  if ($actualHash -ne $expectedHash) {
    Die "EZP driver checksum mismatch: $relativeDriverPath"
  }
  $driverHashCount++
}
if ($driverHashCount -eq 0) { Die "the EZP driver checksum file is empty" }
Write-Host "    $driverHashCount EZP driver payload hashes verified"

# The EZP transport uses the signed libusb-win32 1.4.0.2 runtime kept in this
# repository. Do not replace it with the older libusb0.dll in the upstream
# release while assembling the ZIP.
$libusbDll = "$root\software\libusb0.dll"
if (-not (Test-Path $libusbDll)) { Die "software\libusb0.dll is missing" }
$libusbVersion = (Get-Item $libusbDll).VersionInfo.FileVersion
if ($libusbVersion -ne "1.4.0.2") {
  Die "software\libusb0.dll is $libusbVersion, expected signed release 1.4.0.2"
}
Assert-Sha256 $libusbDll `
  "F56C6F28BFB864761CEBC05494B56AF8BED97493F3B6E7B19AFCB8F1ABCD2CBE" `
  "repository libusb-win32 1.4.0.2 runtime"
Copy-Item $libusbDll $out

# The remaining DLLs come from one immutable upstream release archive. Both
# the archive and each exact entry are pinned. A fresh private directory is
# used for every package, so an old file in %TEMP% can never enter a release.
$runtimeArchiveUrl = "https://github.com/therealdreg/asprogrammer-dregmod/releases/download/v3.17/asprogrammer-dregmod-v3.17.zip"
$runtimeArchiveSha256 = "23BF51CDE094FCFDE873DEE0EFBA4492F3E0B93CE382575D6126D21F6F7EBB59"
$runtimeArchiveRoot = "asprogrammer-dregmod-v3.17"
$runtimeDlls = [ordered]@{
  "CH341DLL.DLL" = "935F5D2EA6A40D47FCBB4892127670E09633374CA524B8739615B30A02C4D178"
  "CH347DLL.DLL" = "6B63BBDFCD36BF4945A4F7DA49F11AF36DC1AB0A77DD65D6A2E88443D5C8E14A"
  "ftd2xx.dll" = "60BB0D6348B1EB0127401AA902F34C963D9196D2778C66F4008A6CF0C6F098A5"
  "buzzpirathlp.dll" = "5026074608F9BC859725252B5D1E3CFAD97B68FCE22A0A47A2479E4DB14C28DD"
  "libiconv2.dll" = "6DEEDAD652BFAB7B09EBD0E06045810390B6AC6CB5AA9EF41C9DAA5616181F22"
  "libintl3.dll" = "F48CE1866602B114E653C876334B771107559ACF1C685373D2305034613958F0"
}

Step "fetching and verifying pinned runtime DLLs"
$runtimeTemp = Join-Path ([IO.Path]::GetTempPath()) `
  ("aspx-runtime-" + [Guid]::NewGuid().ToString("N"))
try {
  New-Item -ItemType Directory -Path $runtimeTemp | Out-Null
  $runtimeArchive = Join-Path $runtimeTemp "runtime.zip"
  Download-PinnedFile $runtimeArchiveUrl $runtimeArchive `
    $runtimeArchiveSha256 "upstream runtime archive v3.17"
  $runtimeExtract = Join-Path $runtimeTemp "extract"
  Expand-Archive -LiteralPath $runtimeArchive -DestinationPath $runtimeExtract

  foreach ($entry in $runtimeDlls.GetEnumerator()) {
    $source = Join-Path (Join-Path $runtimeExtract $runtimeArchiveRoot) $entry.Key
    Assert-Sha256 $source $entry.Value ("runtime DLL " + $entry.Key)
    Copy-Item -LiteralPath $source -Destination $out
    Assert-Sha256 (Join-Path $out $entry.Key) $entry.Value `
      ("packaged runtime DLL " + $entry.Key)
    Write-Host "    $($entry.Key) verified"
  }

  # The headless x86 Windows CLI uses official libusb-1.0.29. The upstream
  # binary release is a 7z archive; Windows' built-in bsdtar extracts it.
  $libusb1Url = "https://github.com/libusb/libusb/releases/download/v1.0.29/libusb-1.0.29.7z"
  $libusb1ArchiveHash = "964A38152CA9A104CD00EC8D2F0617B89CD814F9B635E29763C68563D951521D"
  $libusb1DllHash = "E868ED4705CCC82506EE66A22D981ABC90DEBD300C0F38B5D17873CEB0C0A43A"
  $libusb1Archive = Join-Path $runtimeTemp "libusb-1.0.29.7z"
  Download-PinnedFile $libusb1Url $libusb1Archive $libusb1ArchiveHash `
    "official libusb 1.0.29 Windows archive"
  $libusb1Extract = Join-Path $runtimeTemp "libusb1"
  New-Item -ItemType Directory -Path $libusb1Extract | Out-Null
  & tar.exe -xf $libusb1Archive -C $libusb1Extract
  if ($LASTEXITCODE -ne 0) { Die "could not extract official libusb 1.0.29 archive" }
  $libusb1Source = Join-Path $libusb1Extract "VS2022\MS32\dll\libusb-1.0.dll"
  Assert-Sha256 $libusb1Source $libusb1DllHash "x86 libusb-1.0.29 runtime"
  Copy-Item -LiteralPath $libusb1Source -Destination $out
  Assert-Sha256 (Join-Path $out "libusb-1.0.dll") $libusb1DllHash `
    "packaged x86 libusb-1.0.29 runtime"
  Copy-Item -LiteralPath (Join-Path $libusb1Extract "README.txt") `
    -Destination (Join-Path $out "libusb-1.0-README.txt")
  Write-Host "    libusb-1.0.dll verified"
} finally {
  if (Test-Path -LiteralPath $runtimeTemp) {
    Remove-Item -LiteralPath $runtimeTemp -Recurse -Force
  }
}

$zipOut = "$root\release\Chipwright-$Version.zip"
Remove-Item $zipOut -ErrorAction SilentlyContinue

# The entries are added one at a time so the paths inside the zip are written
# with forward slashes.
#
# The ZIP spec requires that (APPNOTE 4.4.17.1: every slash must be a forward
# slash). Compress-Archive writes backslashes, and so does .NET Framework's
# ZipFile.CreateFromDirectory, which takes the platform separator -- that was
# only fixed in .NET Core, and this script runs under Windows PowerShell 5.1.
#
# Windows Explorer and 7-Zip paper over it. unzip on Linux and macOS does not:
# it reads 'icons\modern\00_write.png' as one long filename, so the icon set,
# the translations and the per-chip scripts all land flat in the top directory,
# and the program silently falls back to its built-in icons with no lang folder.
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::Open($zipOut, 'Create')
try {
  $prefix = (Resolve-Path $out).Path.TrimEnd('\') + '\'
  foreach ($file in Get-ChildItem -Recurse -File $out | Sort-Object FullName) {
    $rel = $file.FullName.Substring($prefix.Length) -replace '\\', '/'
    [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
      $zip, $file.FullName, $rel,
      [System.IO.Compression.CompressionLevel]::Optimal) | Out-Null
  }
} finally {
  $zip.Dispose()
}

# A zip that extracts wrongly on half the machines that download it is worth
# catching here rather than in an issue report.
$check = [System.IO.Compression.ZipFile]::OpenRead($zipOut)
try {
  $bad = @($check.Entries | Where-Object { $_.FullName -match '\\' })
  if ($bad.Count -gt 0) { Die "the zip has $($bad.Count) entries with backslash separators" }
  Write-Host ("    {0} entries, all with forward slashes" -f $check.Entries.Count)
} finally {
  $check.Dispose()
}
Step ("done -> {0} ({1:N0} bytes)" -f $zipOut, (Get-Item $zipOut).Length)
