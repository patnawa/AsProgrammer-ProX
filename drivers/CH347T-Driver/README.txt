CH347T DRIVER PACKAGE
=====================
Placed here 2026-08-06.

WHAT THIS IS
------------
WCH CH341PAR v2.6 (released 2025-04-24), downloaded from the official WCH site:
  https://www.wch-ic.com/downloads/CH341PAR_ZIP.html

Despite the "CH341" name, this is the correct package for the CH347 --- WCH ships
CH347 vendor-mode support (JTAG/SPI/I2C/GPIO) inside it. It also covers CH339.

CH341PAR.ZIP SHA-256:
  1E50A624F3C2D77A5F7A10EED5AFFFD5EFDE927BF4CD91306E769E4CF866F0FD

All .SYS / .DLL / .CAT binaries are signed by:
  CN=Microsoft Windows Hardware Compatibility Publisher (WHQL)


CONTENTS
--------
CH341PAR.ZIP            Original untouched download from WCH.
CH341PAR\               Extracted driver. Legacy build (XP / 7 / 8).
CH341PAR\WIN 1X\        Extracted driver. Windows 10 / 11 build.  <-- THIS ONE IS INSTALLED
CH341PAR\SETUP.EXE      WCH one-key GUI installer (picks the right build itself).
CH341PAR\DRVSETUP64\    Command-line installer used by SETUP.EXE.
LIB\CH347\              SDK for writing your own code against CH347DLL:
                          CH347DLL.H      headers (Chinese comments)
                          CH347DLL_EN.H   headers (English comments)
                          i386\           32-bit import lib
                          amd64\          64-bit import lib
                          arm64\          ARM64 import lib
LIB\CH341\              Same, for the CH341 API.


WHAT WAS ACTUALLY INSTALLED ON THIS MACHINE
-------------------------------------------
Installed from CH341PAR\WIN 1X\CH341WDM.INF via:
    pnputil /add-driver "CH341WDM.INF" /install

  Published as ......... oem76.inf
  Driver version ....... 2.6.2025.04
  Kernel service ....... CH341_A64  (C:\Windows\System32\Drivers\CH341W64.SYS v2.5)
  64-bit DLL ........... C:\Windows\System32\CH347DLLA64.DLL   v1.50
  32-bit DLL ........... C:\Windows\SysWOW64\CH347DLL.DLL      v1.50

Device state after install (CH347T in mode 1, USB VID_1A86 PID_55DB):
  MI_00 -> "USB-HiSpeed-SERIAL-A CH347 (COM5)"   class Ports, driver ch343ser.inf
  MI_02 -> "USB HighSpeed-SPI/I2C... CH347T"     class WCH,   driver oem76.inf   [Started]

Verified working: CH347OpenDevice(0) returned a valid handle, CH347CloseDevice(0)
returned true.

Why it did not work before: an older ch341wdm.inf (2.3.2022.5, from 2022) was already
staged on this machine. That build predates CH347 support entirely --- its INF has no
USB\VID_1A86&PID_55DB&MI_02 entry --- so nothing ever claimed the SPI/I2C/JTAG
interface. The UART half worked the whole time because it is served by a separate
driver (ch343ser.inf).


REINSTALLING / OTHER MACHINES
-----------------------------
Easiest: run CH341PAR\SETUP.EXE as Administrator.
Manual:  pnputil /add-driver "CH341PAR\WIN 1X\CH341WDM.INF" /install
         pnputil /scan-devices

To uninstall: pnputil /delete-driver oem76.inf /uninstall
(Published name may differ on another machine --- check `pnputil /enum-drivers`.)


NOTE ON OTHER TOOLING
---------------------
This WCH driver is what WCH's own tools and CH347DLL need. Open-source tooling
(OpenOCD, flashrom, libusb-based code) instead wants MI_02 bound to WinUSB/libusb,
which you would set with Zadig. The two are mutually exclusive on the same interface;
rebinding with Zadig will detach this driver, and re-running SETUP.EXE reverses it.
