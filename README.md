<div align="center">

# AsProgrammer ProX

**Safe, open-source flash and EEPROM programming for affordable USB hardware**

SPI NOR · SPI NAND reads · I²C · MicroWire · DataFlash · Windows GUI · headless Linux CLI

![latest release](https://img.shields.io/github/v/release/patnawa/AsProgrammer-ProX?display_name=tag&sort=semver&style=flat-square&color=2BB3F3)
![platform](https://img.shields.io/badge/GUI-Windows%20x86-94A3B8?style=flat-square)
![cli](https://img.shields.io/badge/headless-Linux%20CH347-3DD68C?style=flat-square)
![built with](https://img.shields.io/badge/Lazarus%20%2F%20FPC-3.2.2-F5A524?style=flat-square)
![license](https://img.shields.io/badge/license-MIT-3DD68C?style=flat-square)

</div>

AsProgrammer ProX reads, writes, erases, verifies, diagnoses, and safely
updates serial memory. Its transactional Smart Write path takes two matching
snapshots, previews the preservation plan, changes only what is necessary,
and verifies every affected block.

> **Voltage is a hardware safety boundary.** A 1.8 V chip can be destroyed by
> 3.3 V. Confirm the part, orientation, adapter, voltage, and common ground
> before connecting power. Start with a read-only ID check.

## Choose a task

| I want to… | Start here |
|---|---|
| Read or recover a chip | [Five-minute safe start](#five-minute-safe-start) |
| Preview or write an image | [Safe write workflow](#safe-write-workflow) |
| Automate a bench | [Command line](#command-line) |
| Use Linux without a GUI | [Headless Linux CLI](#headless-linux-cli) |
| Add a chip or translation | [Contributing](CONTRIBUTING.md) |
| Build or run tests | [Testing guide](docs/testing.md) |
| Validate real programmers | [Hardware-in-loop guide](docs/hardware-in-loop.md) |
| Understand a release | [Changelog](CHANGELOG.md) · [release process](docs/releasing.md) |
| Report a vulnerability | [Security policy](SECURITY.md) |

## Why this fork

The code treats every operation that can destroy unique firmware as a
fail-closed transaction rather than a sequence of unrelated buttons.

| Capability | Safety property |
|---|---|
| **Smart Write preview and execution** | Shows erase blocks/opcodes, program pages, preserved bytes, verification coverage, backup policy, and worst-case time before confirmation. The GUI previews and executes the shared planner/engine output directly; the LCL-free CLI and tests exercise those layers through a presentation-neutral runner. |
| **Preservation-aware SPI NOR updates** | A `0→1` change erases only its containing block and restores untouched neighbours from the trusted snapshot. Pure `1→0` changes skip erase. |
| **Differential EEPROM updates** | 24Cxx, 93xx, and 95xx write only differing pages, then verify every touched page. |
| **Trusted snapshots and backups** | Two full reads must match before existing content is trusted. Destructive workflows back up nonblank supported chips and stop if the backup cannot be committed. |
| **Identity and electrical gates** | Repeated JEDEC identity, typed programmer capabilities, voltage policy, WEL/BUSY checks, protection decoding, exact transfer counts, and cleanup all fail closed. |
| **SFDP and four-byte support** | Uses JESD216 geometry, timings, erase maps, and address strategies instead of guessing from capacity. |
| **Dump and chip diagnostics** | Detects blank/silent buses, repeating wrapped dumps, unstable contacts, remarked capacity, slow-wearing blocks, and uncorrectable NAND ECC. |
| **Production evidence** | Supports HMAC-authenticated jobs, retained image handles, full verification, signed durable evidence, and local anti-replay state. |

The full release history, including withdrawn behavior and hardware findings,
lives in [CHANGELOG.md](CHANGELOG.md).

## Supported programmers

| Programmer | SPI | I²C | MicroWire | Notes |
|---|:--:|:--:|:--:|---|
| **CH347** | ● | ● | | Fast USB 2.0 option. Windows vendor-DLL backend; CH347 SPI also has a Linux libusb backend. |
| **CH341A** | ● | ● | ● | Common black/green programmer. Check board voltage modifications before use. |
| **FT232H** | ● | ● | ● | D2XX backend, up to 30 MHz. |
| **UsbAsp** | ● | ● | ● | Uses libusb. |
| **Buzzpirat / Bus Pirate** | ● | ● | | Flexible open-drain/pull-up support; comparatively slow. |
| **AVRISP (LUFA)** | ● | ● | ● | |
| **Arduino** | ● | ● | ● | |
| **serprog** | ● | | | Pico, STM32, ESP32, frser-duino, and other flashrom-compatible serial programmers. |
| **EZP2023+** | ◐ | | | Identify, read, whole-chip erase/write, and full verify. Its firmware cannot expose raw SPI, so SFDP, protection decoding, Smart Write, and chip-health tests are unavailable. |

Supported families include 25-series SPI NOR, 45-series DataFlash, 95-series
SPI EEPROM, 24-series I²C EEPROM, 93-series MicroWire EEPROM, and KB9012 EC.
SPI NAND supports identification, bad-block scanning, and ECC-checked reads
from the Windows command line. Phase 3 erase/write paths are implemented but
disabled by default until a sacrificial-chip validation record exists; there
is no GUI NAND workflow yet. See
[the NAND design status and safety gate](docs/design-spi-nand.md).

## Five-minute safe start

1. Download the latest ZIP from
   [GitHub Releases](https://github.com/patnawa/AsProgrammer-ProX/releases),
   extract the complete folder, and run `AsProgrammer.exe`.
2. Select the programmer under **Hardware**. For EZP2023+, install the signed
   device-mode package described in `drivers/EZP2023Plus/README.md`.
3. Confirm the chip voltage and pin 1. Connect the chip with target power off.
4. Press **Read ID** (`F5`). For an unlisted SPI NOR, use
   **Chip → Detect chip via SFDP**.
5. Press **Read** (`Ctrl+R`) with two read passes. Save the dump somewhere
   separate before attempting any change.
6. Run the offline dump scan or compare its hash with a known-good reference.

### SPI NOR wiring

The exact programmer header varies; confirm its manual. This repository's
existing reference diagram shows the chip-side signals:

![SPI 25-series connection diagram](schemeSPI25.gif)

Other included diagrams: [I²C](schemeI2C.gif) ·
[MicroWire](schemeMW.gif) · [DataFlash](schemeSPI45.gif).

## Safe write workflow

The GUI's workflow strip follows **Connect → Identify → Read/backup → Preview
→ Confirm → Execute → Verify**. Disabled steps explain the missing
prerequisite in their tooltip.

1. Read and save the original content.
2. Open the replacement image and confirm it fits the selected range.
3. Choose **Smart Write preview** (`Ctrl+Shift+P`). Review which blocks will
   erase, what data will be preserved, backup status, verification coverage,
   and the declared worst-case time.
4. Confirm only when the detected identity, voltage, address range, and plan
   all match the intended device.
5. Keep power and the clip stable until full verification completes. `Esc`
   requests cancellation at a cleanup-safe boundary; it cannot undo a block
   already erased.

EZP2023+ cannot execute a differential Smart Write. Use ordinary whole-chip
Write; the application performs native erase, independent blank checks,
programming, and independent full comparisons.

## Command line

Any switch starts the Windows executable without showing the window. It uses
the same core planners and engines as the GUI and returns `0` on success, `1`
on an operation failure, and `2` for invalid usage.

```powershell
AsProgrammer.exe --detect --hw ch341
AsProgrammer.exe --read original.bin --chip W25Q64BV --read-passes 2
AsProgrammer.exe --write patch.bin --chip W25Q64BV --smart --plan-only
AsProgrammer.exe --write patch.bin --chip W25Q64BV --smart
AsProgrammer.exe --verify approved.bin --chip W25Q64BV --json
AsProgrammer.exe --scan original.bin
AsProgrammer.exe --help
```

Useful switches:

| Switch | Meaning |
|---|---|
| `--hw NAME` | Force `ch341`, `ch347`, `ft232h`, `usbasp`, `avrisp`, `arduino`, `buzzpirat`, `serprog`, or `ezp`. |
| `--sfdp` | Take supported SPI NOR geometry from the live chip. |
| `--read-passes N` | Require 1–16 matching reads; use at least two for recovery. |
| `--smart --plan-only` | Build and print the differential plan without changing status registers or array data. |
| `--region bios` | Limit read/write/verify to an Intel descriptor region (`fd`, `bios`, `me`, `gbe`, `pd`, `ec`). |
| `--json` | Emit a machine-readable final result. |
| `--scan FILE` | Inspect a dump offline for blank data, wrapping, entropy, and known image structures. |

SPI NAND uses separate `--nand-info` and `--nand-read FILE` commands. Its
Phase 3 `--nand-write FILE` and `--nand-erase` paths additionally require an
unused `--nand-backup FILE`, `--force`, an explicit bad-block policy when
skipping is intended, and the live-validation station gate described in
[the NAND design document](docs/design-spi-nand.md). Raw NAND mutation is
always refused.

Strict production adds authenticated manifest, key-ID, environment-key, and
evidence-directory switches. Those are security controls, not convenience
flags; read [the production security model](docs/production-job-security.md)
before deploying them.

## Headless Linux CLI

`software/AsProgrammerCLI.lpr` is LCL-free and uses the CH347 libusb backend.
It supports stable read-only detection/read, offline scan/SFDP decoding, Smart
Write preview, and a separately gated sacrificial-chip write path while live
validation is still being completed.

```bash
fpc -Mobjfpc -Sh -Fusoftware software/AsProgrammerCLI.lpr
./software/AsProgrammerCLI --detect
./software/AsProgrammerCLI --read dump.bin --size 8388608 --passes 2
./software/AsProgrammerCLI --smart-preview patch.bin --size 8388608 \
  --address 0 --page-size 256 --erase-size 4096 --erase-opcode 20
```

Run `./software/AsProgrammerCLI --help` before use. The cross-platform status
and live-validation boundary are tracked in
[docs/design-cross-platform.md](docs/design-cross-platform.md). Linux requires
the system libusb 1.0 runtime (normally the `libusb-1.0-0` package). The Windows
release ZIP includes the exact hash-verified x86 libusb 1.0 runtime beside
`AsProgrammerCLI.exe`.

## Runtime bundle

Keep the release directory together. Hardware libraries are loaded at run
time, so a missing DLL disables only its programmer rather than preventing the
application from starting.

| File | Programmer |
|---|---|
| `CH341DLL.DLL` | CH341A |
| `CH347DLL.DLL` | CH347 on Windows |
| `ftd2xx.dll` | FT232H |
| `libusb0.dll` | UsbAsp, AVRISP, and EZP2023+ |
| `libusb-1.0.dll` | Headless CH347 CLI on Windows |
| `buzzpirathlp.dll`, `libiconv2.dll`, `libintl3.dll` | Buzzpirat / Bus Pirate |

Release packaging downloads these from one pinned upstream archive, verifies
the archive and every exact DLL with SHA-256, and fails if anything is missing.
It never reuses an unverified temporary cache. The release also includes chip
lists, translations, scripts, icons, the signed EZP driver bundle, its
checksums, this README, the changelog, licenses, and
[third-party notices](THIRD_PARTY_NOTICES.md).

## Chip database

Chip definitions are plain XML. The master `chiplist.xml` is supplemented at
run time by separately licensed/imported lists and the update-safe local
`chiplist-user.xml`.

```xml
<W25Q64BV id="EF4017" page="256" size="8388608" sector="4096" sectorcmd="20"/>
```

Never infer voltage, address width, page size, or erase geometry when a
datasheet or SFDP table can establish it. To contribute a detected part, use
`--export-chip NAME`; it produces a proposed XML entry and SFDP fixture. See
[CONTRIBUTING.md](CONTRIBUTING.md) for the required evidence.

## Building

The Windows GUI targets Win32 and requires 32-bit Lazarus 4.8/FPC 3.2.2:

```powershell
powershell -ExecutionPolicy Bypass -File tools\build.ps1
powershell -ExecutionPolicy Bypass -File tools\build.ps1 -Release
```

The second command builds one runnable ZIP. Runtime inputs and the compiler
installer used by CI are hash-pinned; see [the release process](docs/releasing.md).

For hardware-free POSIX tests and a compile check of the headless CLI:

```bash
./tools/build.sh
```

The authoritative suite catalog and test responsibilities are in
[docs/testing.md](docs/testing.md).

## Project documentation

| Topic | Document |
|---|---|
| Test suites and metadata drift | [docs/testing.md](docs/testing.md) |
| Live CH341/CH347/EZP validation | [docs/hardware-in-loop.md](docs/hardware-in-loop.md) |
| Release inputs and publication | [docs/releasing.md](docs/releasing.md) |
| Production trust boundary | [docs/production-job-security.md](docs/production-job-security.md) |
| Cross-platform architecture | [docs/design-cross-platform.md](docs/design-cross-platform.md) |
| EEPROM Smart Write | [docs/design-eeprom-smart-write.md](docs/design-eeprom-smart-write.md) |
| SPI NAND status | [docs/design-spi-nand.md](docs/design-spi-nand.md) |

## Credits and license

AsProgrammer ProX builds on
[nofeletru/UsbAsp-flash](https://github.com/nofeletru/UsbAsp-flash) and
[therealdreg/asprogrammer-dregmod](https://github.com/therealdreg/asprogrammer-dregmod),
with Bus Pirate work from Ian Lesnet and the community. Floyd77 documented the
unknown-chip identification method. See the repository history for all
contributors.

MIT — see [LICENSE](LICENSE). Copyright © 2015 nofeletru and contributors.
