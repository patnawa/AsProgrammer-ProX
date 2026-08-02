<#
.SYNOPSIS
  Runs a hardware-in-the-loop check on a dedicated Windows bench.

.DESCRIPTION
  ReadOnly is the default and never sends erase or program commands.
  Destructive mode is for a socketed sacrificial fixture only. It requires an
  exact environment acknowledgement, a hash-pinned full-chip test image, and
  restores and verifies the two-pass backup before returning success.
#>

[CmdletBinding()]
param(
  [ValidateSet('ReadOnly', 'Destructive')]
  [string]$Mode = 'ReadOnly',

  [Parameter(Mandatory = $true)]
  [ValidateSet('ch341', 'ch347', 'ezp')]
  [string]$Target,

  [string]$Chip = '',
  [string]$Image = '',
  [string]$ExpectedImageSha256 = '',
  [string]$ProgramPath = '',
  [string]$ArtifactDir = ''
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

function Fail([string]$Message) { throw "HIL FAILED: $Message" }

if ([string]::IsNullOrWhiteSpace($ArtifactDir)) {
  $ArtifactDir = Join-Path $root 'hil-results'
}
New-Item -ItemType Directory -Path $ArtifactDir -Force | Out-Null
$ArtifactDir = (Resolve-Path -LiteralPath $ArtifactDir).Path
$runId = "{0}-{1}" -f ([DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ')),
  ([Guid]::NewGuid().ToString('N'))
$logPath = Join-Path $ArtifactDir `
  ("{0}-{1}-{2}.log" -f $Target, $Mode.ToLowerInvariant(), $runId)
if (Test-Path -LiteralPath $logPath) {
  Fail "refusing to replace an existing HIL log: $logPath"
}

if ([string]::IsNullOrWhiteSpace($ProgramPath)) {
  $candidate = Get-ChildItem -LiteralPath (Join-Path $root 'release') `
    -Filter AsProgrammer.exe -File -Recurse -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1
  if ($candidate) { $ProgramPath = $candidate.FullName }
  else { $ProgramPath = Join-Path $root 'software\AsProgrammer.exe' }
}
if (-not (Test-Path -LiteralPath $ProgramPath -PathType Leaf)) {
  Fail "AsProgrammer.exe was not found; run tools\build.ps1 -Release first"
}
$ProgramPath = (Resolve-Path -LiteralPath $ProgramPath).Path
$runtimeDir = Split-Path -Parent $ProgramPath
$env:PATH = "$runtimeDir;$env:PATH"

function Write-Log([string]$Message) {
  $line = "[{0}] {1}" -f ([DateTime]::UtcNow.ToString('o')), $Message
  Write-Host $line
  Add-Content -LiteralPath $logPath -Value $line -Encoding UTF8
}

function Invoke-Logged([string]$File, [string[]]$Arguments) {
  Write-Log ("RUN {0} {1}" -f (Split-Path -Leaf $File), ($Arguments -join ' '))
  $output = @(& $File @Arguments 2>&1)
  $exitCode = $LASTEXITCODE
  foreach ($line in $output) {
    Write-Host $line
    Add-Content -LiteralPath $logPath -Value ([string]$line) -Encoding UTF8
  }
  if ($exitCode -ne 0) {
    Fail "$(Split-Path -Leaf $File) exited $exitCode"
  }
  return $output
}

function Invoke-Prox([string[]]$Arguments) {
  return Invoke-Logged $ProgramPath $Arguments
}

function Assert-DetectedChip([object[]]$Output) {
  if ([string]::IsNullOrWhiteSpace($Chip)) { return }
  $jsonLine = $Output | Where-Object { ([string]$_).TrimStart().StartsWith('{') } |
    Select-Object -Last 1
  if (-not $jsonLine) { Fail 'detect returned no JSON result' }
  $result = ([string]$jsonLine) | ConvertFrom-Json
  if (-not $result.ok) { Fail 'programmer did not detect a usable chip' }
  if (-not [string]::Equals([string]$result.chip, $Chip,
      [StringComparison]::OrdinalIgnoreCase)) {
    Fail "fixture identity mismatch: expected '$Chip', detected '$($result.chip)'"
  }
}

Write-Log "mode=$Mode target=$Target executable=$ProgramPath"

# Every target first proves the non-mutating detection/read path. EZP's
# independent smoke program exercises its USB descriptors and first data block.
if ($Target -eq 'ezp') {
  $smoke = Join-Path $root 'tools\ezpsmoke.exe'
  if (-not (Test-Path -LiteralPath $smoke -PathType Leaf)) {
    Fail 'tools\ezpsmoke.exe is missing; tools\build.ps1 builds it'
  }
  Invoke-Logged $smoke @() | Out-Null
}
$detect = Invoke-Prox @('--detect', '--hw', $Target, '--json')
Assert-DetectedChip $detect

if ($Mode -eq 'ReadOnly') {
  if (-not [string]::IsNullOrWhiteSpace($Chip)) {
    $dump = Join-Path $ArtifactDir ("{0}-{1}-two-pass.bin" -f $Target, $runId)
    if (Test-Path -LiteralPath $dump) {
      Fail "refusing to replace an existing read-only HIL dump: $dump"
    }
    Invoke-Prox @('--read', $dump, '--chip', $Chip, '--hw', $Target,
      '--read-passes', '2', '--json') | Out-Null
    Write-Log "two matching reads saved to $dump"
  } else {
    Write-Log 'chip not supplied; detection-only read-only check completed'
  }
  Write-Log 'PASS (read-only; no erase/program command requested)'
  exit 0
}

# The workflow's protected environment is one gate. This station-local token
# is a second gate and prevents a copied command or unreviewed workflow edit
# from turning an ordinary runner into an erasing bench.
if ($env:ASPX_HIL_DESTRUCTIVE -ne 'ERASE_SACRIFICIAL_FIXTURE') {
  Fail 'set ASPX_HIL_DESTRUCTIVE=ERASE_SACRIFICIAL_FIXTURE on the sacrificial station'
}
if ([string]::IsNullOrWhiteSpace($Chip)) { Fail '-Chip is required in Destructive mode' }
if ([string]::IsNullOrWhiteSpace($Image)) { Fail '-Image is required in Destructive mode' }
if ([string]::IsNullOrWhiteSpace($ExpectedImageSha256) -or
    $ExpectedImageSha256 -notmatch '^[0-9A-Fa-f]{64}$') {
  Fail '-ExpectedImageSha256 must be an exact 64-digit SHA-256'
}
if (-not (Test-Path -LiteralPath $Image -PathType Leaf)) { Fail "test image is missing: $Image" }
$Image = (Resolve-Path -LiteralPath $Image).Path
$actualImageHash = (Get-FileHash -LiteralPath $Image -Algorithm SHA256).Hash
if ($actualImageHash -ne $ExpectedImageSha256.ToUpperInvariant()) {
  Fail "test image SHA-256 mismatch: expected $ExpectedImageSha256, got $actualImageHash"
}
if ([IO.Path]::GetExtension($Image) -ne '.bin') {
  Fail 'destructive HIL accepts a full-chip .bin image only'
}

$backup = Join-Path $ArtifactDir `
  ("{0}-{1}-restore-backup.bin" -f $Target, $runId)
if (Test-Path -LiteralPath $backup) {
  Fail "refusing to replace an existing fixture recovery image: $backup"
}
Invoke-Prox @('--read', $backup, '--chip', $Chip, '--hw', $Target,
  '--read-passes', '2', '--json') | Out-Null
if ((Get-Item -LiteralPath $backup).Length -ne (Get-Item -LiteralPath $Image).Length) {
  Fail 'test image length differs from the two-pass full-chip backup'
}
$backupHash = (Get-FileHash -LiteralPath $backup -Algorithm SHA256).Hash
Write-Log "restore backup SHA-256=$backupHash"

$testFailure = $null
try {
  if ($Target -eq 'ezp') {
    Invoke-Prox @('--write', $Image, '--chip', $Chip, '--hw', $Target,
      '--erase', '--verify', '--json') | Out-Null
  } else {
    Invoke-Prox @('--write', $Image, '--chip', $Chip, '--hw', $Target,
      '--smart', '--json') | Out-Null
    Invoke-Prox @('--verify', $Image, '--chip', $Chip, '--hw', $Target,
      '--json') | Out-Null
  }
  Write-Log 'test image programmed and verified'
} catch {
  $testFailure = $_
  Write-Log "test phase failed: $($_.Exception.Message)"
} finally {
  Write-Log 'restoring the pre-test fixture image'
  if ($Target -eq 'ezp') {
    Invoke-Prox @('--write', $backup, '--chip', $Chip, '--hw', $Target,
      '--erase', '--verify', '--json') | Out-Null
  } else {
    Invoke-Prox @('--write', $backup, '--chip', $Chip, '--hw', $Target,
      '--smart', '--json') | Out-Null
    Invoke-Prox @('--verify', $backup, '--chip', $Chip, '--hw', $Target,
      '--json') | Out-Null
  }
  Write-Log 'fixture restore verified'
}
if ($testFailure) { throw $testFailure }
Write-Log 'PASS (destructive fixture cycle and verified restore)'
