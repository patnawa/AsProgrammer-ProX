# EZP2023+ Windows driver bundle

This directory contains the complete signed driver material used by
AsProgrammer ProX for the EZP2023+ (`USB\VID_1FC8&PID_310B`).

## Contents

- `device-package-1.2.6.0/` is the EZP vendor's signed Windows 10/11 package.
  Its `WinUSBComm.inf` is the package that matches the programmer's real USB
  id, so Windows needs it for a first-time device binding.
- `libusb-win32-1.4.0.2/` contains the official signed libusb-win32 1.4.0.2
  driver/runtime files referenced by its INF, for x86, AMD64 and ARM64. The
  upstream licence and changelog files are included unchanged.
- `SHA256SUMS.txt` pins every copied upstream/vendor file.
- `tools/update_ezp_libusb1402.ps1` at the repository root installs or updates
  the driver and validates the result.

The 1.4.0.2 INF is signed for a different test USB id. Do not edit it or force
it onto the EZP: changing it invalidates the signed catalogue. The updater
keeps the signed EZP-specific device binding, stages the untouched 1.4.0.2
catalogue with Windows Code Integrity, and updates the live `libusb0` kernel
and 32/64-bit runtime files. This is also why Device Manager may continue to
show `1.2.6.0` from the binding INF even though the loaded runtime is 1.4.0.2.

## Install or update

Connect exactly one EZP2023+, open a 64-bit PowerShell window as Administrator
on AMD64 Windows, change to the repository root, and run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\update_ezp_libusb1402.ps1
```

On a new machine the script first installs the signed device package. On an
existing installation it preserves the current matching INF. In both cases it:

1. validates the catalogue and binary signatures;
2. exports the current device package and runtime files to a dated Desktop
   rollback directory;
3. stages the unmodified 1.4.0.2 package;
4. disables only the connected EZP, replaces only the `libusb0` files, and
   restores their original Windows ACLs;
5. restarts the EZP and requires PnP status `OK`;
6. restores the saved runtime automatically if the update fails.

The operation is idempotent: if all three Windows runtime files are already
1.4.0.2, it verifies their release hashes and signatures plus PnP status,
then makes no changes.

The upstream ARM64 files are preserved in this bundle, but the EZP vendor's
signed device INF has no ARM64 binding. The updater therefore refuses ARM64
instead of attempting to install an incompatible AMD64 kernel driver.

## Verify

```powershell
Get-Item C:\Windows\System32\drivers\libusb0.sys,
         C:\Windows\System32\libusb0.dll,
         C:\Windows\SysWOW64\libusb0.dll |
  Select-Object FullName, @{n='Version';e={$_.VersionInfo.FileVersion}}

Get-PnpDevice -PresentOnly |
  Where-Object InstanceId -like 'USB\VID_1FC8&PID_310B\*'
```

All three files should report `1.4.0.2`, and the device should report `OK`.
Run `tools\ezpsmoke.exe` or an AsProgrammer read afterwards to verify actual
bulk transfers.

This bundle was validated on 64-bit Windows with EZP identity `90381CBC` and a
W25Q64-class chip reporting JEDEC id `EF4017`.
