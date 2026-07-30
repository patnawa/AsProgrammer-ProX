# Updates the installed EZP2023+ libusb-win32 runtime to the signed 1.4.0.2
# binaries. Run from an elevated 64-bit PowerShell process.
#
# The release INF is intentionally left untouched and staged in the Windows
# Driver Store so its Microsoft-signed catalogue remains valid. The EZP's
# older device-specific INF is kept because it is the signed package that
# matches USB\VID_1FC8&PID_310B. Its service uses the conventional
# System32\drivers\libusb0.sys path, which is updated below.

[CmdletBinding()]
param(
  [string]$PackageRoot = '',
  [string]$DevicePackageRoot = '',
  [string]$InstanceId = '',
  [string]$BackupRoot = (Join-Path ([Environment]::GetFolderPath('Desktop')) ('EZP2023-driver-backup-' + (Get-Date -Format 'yyyyMMdd'))),
  [string]$LogPath = (Join-Path ([Environment]::GetFolderPath('Desktop')) ('EZP2023-driver-update-' + (Get-Date -Format 'yyyyMMdd') + '.log'))
)

$ErrorActionPreference = 'Stop'

function Write-Step([string]$Message) {
  $line = '{0:yyyy-MM-dd HH:mm:ss}  {1}' -f (Get-Date), $Message
  $line | Tee-Object -FilePath $LogPath -Append
}

function Invoke-Native([string]$Program, [string[]]$Arguments,
  [int[]]$AllowedExitCodes = @(0)) {
  Write-Step ('> ' + $Program + ' ' + ($Arguments -join ' '))
  & $Program @Arguments 2>&1 | Tee-Object -FilePath $LogPath -Append
  $code = $LASTEXITCODE
  if ($AllowedExitCodes -notcontains $code) {
    throw "$Program exited with code $code"
  }
}

function Copy-ProtectedFile([string]$Source, [string]$Destination) {
  $oldAcl = Get-Acl -LiteralPath $Destination
  $oldSddl = $oldAcl.Sddl
  try {
    Invoke-Native 'takeown.exe' @('/f', $Destination, '/a')
    Invoke-Native 'icacls.exe' @($Destination, '/grant', '*S-1-5-32-544:F')
    Copy-Item -LiteralPath $Source -Destination $Destination -Force
  }
  finally {
    $restoredAcl = New-Object System.Security.AccessControl.FileSecurity
    $restoredAcl.SetSecurityDescriptorSddlForm($oldSddl)
    Set-Acl -LiteralPath $Destination -AclObject $restoredAcl
  }
}

function Assert-FileHashMatch([string]$Source, [string]$Destination) {
  $sourceHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $Source).Hash
  $destHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $Destination).Hash
  if ($sourceHash -ne $destHash) {
    throw "File hash mismatch: $Destination"
  }
}

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)) {
  throw 'This update must run as Administrator.'
}
if (-not [Environment]::Is64BitProcess) {
  throw 'Use 64-bit PowerShell so System32 and SysWOW64 are not redirected.'
}
if ($env:PROCESSOR_ARCHITECTURE -ne 'AMD64') {
  throw 'This updater supports AMD64 Windows only. The project preserves the ' +
    'upstream ARM64 runtime, but the signed EZP device INF has no ARM64 binding.'
}

if ([string]::IsNullOrWhiteSpace($PackageRoot)) {
  $projectRuntime = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\drivers\EZP2023Plus\libusb-win32-1.4.0.2'))
  if (Test-Path -LiteralPath $projectRuntime -PathType Container) {
    $PackageRoot = $projectRuntime
  }
  else {
    $PackageRoot = Join-Path ([Environment]::GetFolderPath('Desktop')) 'libusb-win32-bin-1.4.0.2\libusb-win32-bin-1.4.0.2'
  }
}
if ([string]::IsNullOrWhiteSpace($DevicePackageRoot)) {
  $DevicePackageRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\drivers\EZP2023Plus\device-package-1.2.6.0'))
}

if ([string]::IsNullOrWhiteSpace($InstanceId)) {
  $ezpDevices = @(Get-PnpDevice -PresentOnly |
    Where-Object { $_.InstanceId -like 'USB\VID_1FC8&PID_310B\*' })
  if ($ezpDevices.Count -ne 1) {
    throw "Expected exactly one connected EZP2023+; found $($ezpDevices.Count)."
  }
  $InstanceId = $ezpDevices[0].InstanceId
}
$deviceDriver = Get-CimInstance Win32_PnPSignedDriver |
  Where-Object { $_.DeviceID -ieq $InstanceId } |
  Select-Object -First 1

# A new Windows installation first needs the vendor's signed package because
# it is the package that actually matches USB\VID_1FC8&PID_310B. After that,
# the signed 1.4 runtime can safely replace the old service files.
if (($null -eq $deviceDriver) -or
    ($deviceDriver.DriverProviderName -ne 'libusb-win32') -or
    [string]::IsNullOrWhiteSpace($deviceDriver.InfName)) {
  $deviceInf = Join-Path $DevicePackageRoot 'WinUSBComm.inf'
  $deviceCat = Join-Path $DevicePackageRoot 'WinUSBCommX64.cat'
  if ((-not (Test-Path -LiteralPath $deviceInf -PathType Leaf)) -or
      (-not (Test-Path -LiteralPath $deviceCat -PathType Leaf))) {
    throw "The signed EZP device package is missing from $DevicePackageRoot"
  }
  if ((Get-AuthenticodeSignature -LiteralPath $deviceCat).Status -ne 'Valid') {
    throw "Signature check failed for $deviceCat"
  }
  Invoke-Native 'pnputil.exe' @('/add-driver', $deviceInf, '/install')
  Start-Sleep -Seconds 3
  $deviceDriver = Get-CimInstance Win32_PnPSignedDriver |
    Where-Object { $_.DeviceID -ieq $InstanceId } |
    Select-Object -First 1
}
if (($null -eq $deviceDriver) -or
    ($deviceDriver.DriverProviderName -ne 'libusb-win32') -or
    [string]::IsNullOrWhiteSpace($deviceDriver.InfName)) {
  throw "The signed libusb-win32 device package did not bind to $InstanceId"
}
$deviceInfName = $deviceDriver.InfName

$sourceInf = Join-Path $PackageRoot 'bin\libusb0.inf'
$sourceCat = Join-Path $PackageRoot 'bin\libusb0.cat'
$sourceSys = Join-Path $PackageRoot 'bin\amd64\libusb0.sys'
$sourceDll64 = Join-Path $PackageRoot 'bin\amd64\libusb0.dll'
$sourceDll32 = Join-Path $PackageRoot 'bin\x86\libusb0_x86.dll'
$destSys = Join-Path $env:SystemRoot 'System32\drivers\libusb0.sys'
$destDll64 = Join-Path $env:SystemRoot 'System32\libusb0.dll'
$destDll32 = Join-Path $env:SystemRoot 'SysWOW64\libusb0.dll'
$sources = @($sourceInf, $sourceCat, $sourceSys, $sourceDll64, $sourceDll32)

foreach ($source in $sources) {
  if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
    throw "Required release file is missing: $source"
  }
}

foreach ($signedFile in @($sourceCat, $sourceSys, $sourceDll64, $sourceDll32)) {
  $signature = Get-AuthenticodeSignature -LiteralPath $signedFile
  if ($signature.Status -ne 'Valid') {
    throw "Signature check failed for $signedFile ($($signature.Status))"
  }
}
foreach ($versionedFile in @($sourceSys, $sourceDll64, $sourceDll32)) {
  $version = (Get-Item -LiteralPath $versionedFile).VersionInfo.FileVersion
  if ($version -ne '1.4.0.2') {
    throw "Expected version 1.4.0.2, found $version in $versionedFile"
  }
}

$installedVersions = @($destSys, $destDll64, $destDll32) |
  ForEach-Object {
    if (Test-Path -LiteralPath $_ -PathType Leaf) {
      (Get-Item -LiteralPath $_).VersionInfo.FileVersion
    }
    else {
      ''
    }
  }
if (($installedVersions | Where-Object { $_ -eq '1.4.0.2' }).Count -eq 3) {
  foreach ($pair in @(
      @($sourceSys, $destSys),
      @($sourceDll64, $destDll64),
      @($sourceDll32, $destDll32))) {
    Assert-FileHashMatch $pair[0] $pair[1]
  }
  foreach ($installedFile in @($destSys, $destDll64, $destDll32)) {
    $signature = Get-AuthenticodeSignature -LiteralPath $installedFile
    if ($signature.Status -ne 'Valid') {
      throw "Installed-file signature check failed for $installedFile " +
        "($($signature.Status))"
    }
  }
  $device = Get-PnpDevice -InstanceId $InstanceId
  if ($device.Status -ne 'OK') {
    throw "EZP2023+ status is $($device.Status), not OK."
  }
  Write-Step 'libusb-win32 1.4.0.2 is already installed; no files changed.'
  Write-Step 'Installed file hashes and signatures match the saved release.'
  Write-Step "EZP2023+ instance: $InstanceId"
  Write-Step "EZP2023+ status: $($device.Status)"
  exit 0
}
if (($installedVersions | Where-Object { $_ -eq '1.4.0.2' }).Count -ne 0) {
  throw 'The system has a partial 1.4.0.2 installation. Restore the saved ' +
    'runtime files before running this updater again.'
}

New-Item -ItemType Directory -Path $BackupRoot -Force | Out-Null
Write-Step 'Validated signed libusb-win32 1.4.0.2 release files.'

# Preserve the signed, device-specific package and the exact live files.
Invoke-Native 'pnputil.exe' @('/export-driver', $deviceInfName, $BackupRoot)
$backupSys = Join-Path $BackupRoot 'libusb0-1.2.6.0-amd64.sys'
$backupDll64 = Join-Path $BackupRoot 'libusb0-1.2.6.0-amd64.dll'
$backupDll32 = Join-Path $BackupRoot 'libusb0-1.2.6.0-x86.dll'
Copy-Item -LiteralPath $destSys -Destination $backupSys -Force
Copy-Item -LiteralPath $destDll64 -Destination $backupDll64 -Force
Copy-Item -LiteralPath $destDll32 -Destination $backupDll32 -Force
Write-Step "Rollback files are in $BackupRoot"

# This registers the untouched Microsoft-signed catalogue with Code Integrity.
# Its INF has another hardware ID, so /install cannot and must not bind it to
# the EZP. The existing signed EZP INF remains the device match.
Invoke-Native 'pnputil.exe' @('/add-driver', $sourceInf)

$deviceDisabled = $false
try {
  Invoke-Native 'pnputil.exe' @('/disable-device', $InstanceId)
  $deviceDisabled = $true
  # PnP drivers normally unload as part of /disable-device. Depending on the
  # exact Windows build, sc reports either success, already stopped (1062), or
  # that an explicit stop control is not valid for this PnP service (1052).
  Invoke-Native 'sc.exe' @('stop', 'libusb0') @(0, 1052, 1062)

  Copy-ProtectedFile $sourceSys $destSys
  Copy-ProtectedFile $sourceDll64 $destDll64
  Copy-ProtectedFile $sourceDll32 $destDll32

  Invoke-Native 'sc.exe' @('config', 'libusb0',
    'DisplayName=', 'libusb-win32 - Kernel Driver 01/09/2026 1.4.0.2')

  foreach ($pair in @(
      @($sourceSys, $destSys),
      @($sourceDll64, $destDll64),
      @($sourceDll32, $destDll32))) {
    Assert-FileHashMatch $pair[0] $pair[1]
  }
  Write-Step 'The installed kernel and user-mode files match release 1.4.0.2.'

  Invoke-Native 'pnputil.exe' @('/enable-device', $InstanceId)
  $deviceDisabled = $false
  Start-Sleep -Seconds 3
  Invoke-Native 'pnputil.exe' @('/restart-device', $InstanceId)
  Start-Sleep -Seconds 3

  $device = Get-PnpDevice -InstanceId $InstanceId
  if ($device.Status -ne 'OK') {
    throw "EZP2023+ did not restart cleanly (status: $($device.Status))"
  }
}
catch {
  Write-Step "UPDATE FAILED: $($_.Exception.Message)"
  Write-Step 'Restoring the saved 1.2.6.0 runtime files.'
  if (-not $deviceDisabled) {
    Invoke-Native 'pnputil.exe' @('/disable-device', $InstanceId)
    $deviceDisabled = $true
  }
  Invoke-Native 'sc.exe' @('stop', 'libusb0') @(0, 1052, 1062)
  Copy-ProtectedFile $backupSys $destSys
  Copy-ProtectedFile $backupDll64 $destDll64
  Copy-ProtectedFile $backupDll32 $destDll32
  Invoke-Native 'sc.exe' @('config', 'libusb0',
    'DisplayName=', 'libusb-win32 - Kernel Driver 01/18/2012 1.2.6.0')
  Invoke-Native 'pnputil.exe' @('/enable-device', $InstanceId)
  $deviceDisabled = $false
  Start-Sleep -Seconds 3
  Invoke-Native 'pnputil.exe' @('/restart-device', $InstanceId)
  throw
}
finally {
  if ($deviceDisabled) {
    Invoke-Native 'pnputil.exe' @('/enable-device', $InstanceId)
  }
}

foreach ($installedFile in @($destSys, $destDll64, $destDll32)) {
  $item = Get-Item -LiteralPath $installedFile
  Write-Step "$installedFile => $($item.VersionInfo.FileVersion)"
}
Write-Step "EZP2023+ status: $($device.Status)"
Write-Step 'UPDATE SUCCEEDED'
