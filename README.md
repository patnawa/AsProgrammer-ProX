<div align="center">

# AsProgrammer ProX

**Flash memory programmer for SPI · I²C · MicroWire**

Sector-level erase · SFDP auto-detect · checksums · responsive UI

![version](https://img.shields.io/badge/version-4.0-2BB3F3?style=flat-square)
![platform](https://img.shields.io/badge/platform-Windows%20x86-94A3B8?style=flat-square)
![built with](https://img.shields.io/badge/built%20with-Lazarus%20%2F%20FPC-F5A524?style=flat-square)
![license](https://img.shields.io/badge/license-MIT-3DD68C?style=flat-square)

</div>

---

## What it does

Reads, writes, erases and verifies serial flash and EEPROM chips through cheap USB programmers.
v4 closes most of the feature gap with the software that ships with expensive commercial
programmers, while staying free and open source.

| | |
|---|---|
| **Sector / block erase** | Erase only the sectors covering a range instead of the whole chip. 4 KB (`20h`), 32 KB (`52h`), 64 KB (`D8h`), or the size declared by the chip. |
| **Smart write** | Unlock → erase just the needed sectors → write → verify, in one action. Patch a region of a BIOS without touching the rest. |
| **SFDP auto-detect** | Reads the JEDEC JESD216 parameter table from the chip itself (`5Ah`) and fills in size, page size, address width and erase types. Works on chips missing from the database. Also reads the **4-byte address instruction table** (`FF84h`), **DWORD-16** (how *this* chip enters 4-byte mode, and whether its status register needs `06h` or `50h`) and the **sector map** (`FF81h`), so parts with boot blocks of a different size are reported instead of silently mis-erased. |
| **Write protection guard** | Before every erase and write, the status register is decoded and the protected range compared against the target. A locked chip accepts the command and silently ignores it, which otherwise shows up much later as an unexplained verify failure. When `WPS=1` the BP bits mean nothing, so the individual block locks are read back one block at a time with `3Dh` — 4 KB granularity across the boot blocks, 64 KB elsewhere — instead of giving up and letting the write through unchecked. |
| **Erase follows the chip's own map** | When the chip publishes an SFDP sector map, the erase is planned against it: boot-block parts are erased with the sector size that region actually uses, and long runs use the largest erase opcode that still fits inside the requested range. A whole-chip erase of a boot-block 8 MB part takes 158 commands instead of 2048. |
| **Four byte addressing without mode switching** | Chips over 128 Mbit that publish a 4-byte address instruction table are driven with their own `13h` / `12h` / `21h` / `DCh` opcodes, so the chip is never left in a sticky 4-byte mode. Where a mode switch is still needed it is unwound in a `finally`, so a cancelled or failed job cannot leave the chip in a state the next tool reads as garbage. |
| **Empty socket is named as such** | A missing, unpowered or back-to-front chip reads `FFh` from the status register, which looks exactly like "busy forever". That is now detected in half a second and reported as no chip answering, rather than after the full timeout — up to ten minutes on a chip erase — as "the chip stayed busy". |
| **Save a detected chip** | A chip found only through SFDP can be written into `chiplist-user.xml` and is picked up from then on. Kept separate from the shipped list so a program update never overwrites it. |
| **Production traceability** | Each chip's factory unique id (`4Bh`) is logged with a timestamp, the image CRC32 and pass/fail. Optionally refuses a chip whose id already passed, so nothing is programmed or shipped twice. |
| **Job files** | A one-line `crc32=` file pins the approved image. If the loaded buffer does not match, the write is refused — the cheapest guard against programming the wrong revision. |
| **File formats** | Binary, **Intel HEX** and **Motorola S-record**, both directions. Gaps in a text file load as erased bytes, and record checksums are validated on load. |
| **Checksums** | CRC32, SUM32 and SUM16 over the buffer, for comparing a dump against a reference image. |
| **Buffer tools** | Fill buffer, swap bytes (16-bit), find, go to address, copy — plus save the log to a file. |
| **Chip ID check** | Verifies the JEDEC id against the selected chip before every write and erase. On by default. |
| **Pre-write backup** | Optionally dumps the chip to `backup\<chip>_<timestamp>.bin` before it is changed, and aborts if the dump fails. |
| **Side-by-side compare** | Buffer vs chip, file vs file, or chip vs chip. Opens a two-pane hex view with the differing bytes highlighted on both sides, synchronised scrolling, jump to next/previous difference (`F3`), and a saveable range report. |
| **Automatic chip detection** | Reads the JEDEC id as soon as a programmer is plugged in and selects the matching chip, or offers the list when the id matches several. Turn it off in *Options*. |
| **Project files** | One `.apxproj` holds the chip, all settings and the buffer. |
| **Serial numbers** | Increment, BCD date + increment or random, 1–8 bytes at any address, either endianness, appended to a log file as they are issued. |
| **Production batch** | Program N chips in a row with a prompt between each and a pass/fail summary. |
| **Background operations** | Long transfers run on a worker thread; the window stays responsive and Cancel keeps working. |
| **Dark industrial theme** | Modern flat icon set and a dark palette. Toggle in *Options*. |
| **Scripting** | Pascal-like scripts per chip for parts that need a custom unlock or programming sequence. |
| **Editable chip database** | Plain XML. Adding a chip is one line. |

## Supported hardware

| Programmer | SPI | I²C | MicroWire | Notes |
|---|:--:|:--:|:--:|---|
| **CH347** | ● | ● | | Fastest option, USB 2.0. Recommended. |
| **CH341a** | ● | ● | | The ubiquitous black/green dongle. |
| **FT232H** | ● | ● | | Up to 30 MHz. |
| **UsbAsp** | ● | ● | ● | |
| **Buzzpirat / Bus Pirate** | ● | ● | | Slow but flexible; open-drain and pull-ups for 1.8 V parts. |
| **AVRISP (LUFA)** | ● | | | |
| **Arduino** | ● | | | |

Chip families: 25-series SPI NOR, 45-series DataFlash, 95-series SPI EEPROM, 24-series I²C EEPROM,
93-series MicroWire EEPROM, KB9012 EC.

---

## Quick start

1. Download the latest release: **https://github.com/patnawa/AsProgrammer-ProX/releases**
2. Unzip anywhere and run `AsProgrammer.exe` (keep the whole folder together — see
   [Runtime files](#runtime-files)).
3. Pick your programmer under **Hardware**.
4. Connect the chip, press **Read ID**. If the chip is not in the list, use
   **Chip → Detect chip via SFDP**.
5. Press **Read** to dump, or load a file and use the write button's dropdown →
   *Unlock → erase only needed sectors → write → verify*.

> **Wrong voltage kills chips.** 1.8 V parts must never see 3.3 V or 5 V. Power them from an
> external 1.8 V supply, tie all grounds together, and set the programmer output to open-drain.

---

## Command line

Any `--switch` puts the program into command line mode: the window is never
shown, output goes to the calling console. The work runs through the same code
as the buttons, so there is no second implementation to keep in step.

```
AsProgrammer.exe --detect
AsProgrammer.exe --read dump.bin  --chip W25Q64BV
AsProgrammer.exe --write fw.hex   --chip W25Q64BV --erase --verify
AsProgrammer.exe --verify fw.bin  --chip W25Q64BV
AsProgrammer.exe --read dump.bin  --sfdp
AsProgrammer.exe --help
```

**Exit codes** — the contract a production line relies on:

| Code | Meaning |
|:--:|---|
| `0` | The operation succeeded |
| `1` | The operation failed: verify mismatch, chip still protected, busy timeout, no programmer |
| `2` | Wrong usage: unknown switch, missing file, no chip selected |

`--hw` forces a programmer (`ch341`, `ch347`, `ft232h`, `usbasp`, `avrisp`,
`arduino`, `buzzpirat`); without it the one that is plugged in is used.
`--sfdp` takes the chip parameters from the chip itself instead of the
database. File format follows the extension, so `.bin`, `.hex` and S-record
all work. An unrecognised switch is an error rather than being ignored.

`--json` prints one machine-readable line, so a test jig does not have to
parse the log:

```json
{"action":"write","ok":false,"chip":"W25Q64BV","size":8388608,"bytes":4096,
 "uid":"AABBCCDDEEFF0011","error":"the page did not read back as written","address":4096}
```

### Production switches

```
AsProgrammer.exe --write fw.bin --chip W25Q64BV --erase --verify \
                 --job product-a.job --log line1.csv --operator somchai
```

| Switch | Effect |
|---|---|
| `--job FILE` | Refuse to write unless the buffer matches the job file |
| `--log FILE` | Append one CSV row per chip: time, chip, unique id, serial, operator, size, CRC32, result |
| `--operator NAME` | Recorded in the log |
| `--force` | Proceed even when the target area is write protected, or the chip already passed |
| `--save-chip NAME` | Save the SFDP-detected chip into `chiplist-user.xml` |

A job file is plain `key=value`; `#` starts a comment. Any key may be omitted,
and only the keys present are checked:

```
# the approved image for product A
chip=W25Q64BV
size=8388608
crc32=0xDEADBEEF
```

## Runtime files

The `.exe` alone will not start. These must sit next to it — the DLL imports are static, so Windows
resolves them at process start even for hardware you never touch. A missing one produces a
*"cannot proceed because … .DLL was not found"* system error that looks like a broken build.

| File | Needed for |
|---|---|
| `CH341DLL.DLL` | CH341a |
| `CH347DLL.DLL` | CH347 |
| `ftd2xx.dll` | FT232H |
| `libusb0.dll` | UsbAsp / AVRISP |
| `buzzpirathlp.dll`, `libiconv2.dll`, `libintl3.dll` | Buzzpirat / Bus Pirate |

Data files, resolved relative to the working directory:

```
AsProgrammer.exe
chiplist.xml          chip database
chiplist-flashrom.xml chips converted from flashrom (GPL-2.0-or-later)
chiplist-ezp.xml      chips converted from an EZP programmer database
chiplist-user.xml     chips you saved yourself (created on demand)
settings.xml          saved options
lang/                 translations (.po)
scripts/              per-chip scripts
icons/modern/         toolbar icon set (falls back to built-in icons if absent)
```

---

## Chip database

`chiplist.xml` is plain XML, grouped by protocol and manufacturer.

```xml
<W25Q64BV id="EF4017" page="256" size="8388608" sector="4096" sectorcmd="20"/>
```

| Attribute | Meaning |
|---|---|
| `id` | JEDEC id in hex, as returned by `9Fh` / `90h` / `ABh` / `15h` |
| `page` | Program page size in bytes. `SSTB` / `SSTW` for SST AAI byte/word mode |
| `size` | Chip size in bytes |
| `sector` | *Optional.* Erase sector size in bytes. Defaults to `4096` |
| `sectorcmd` | *Optional.* Erase opcode in hex. Derived from `sector` when absent |
| `spicmd` | Command set: `25`, `45`, `95`, `KB` |
| `script` | Script file in `scripts/` for chips needing a custom sequence |

A second, optional list is loaded from `chiplist-flashrom.xml` if it sits next to the program. It
holds 204 further SPI chips converted from the [flashrom](https://github.com/flashrom/flashrom)
project's tables by `tools/import_flashchips.py`, and both files are merged into one chip menu and
searched together.

> **That file is GPL-2.0-or-later, not MIT.** It is a derived work of flashrom's chip tables, so it
> keeps flashrom's licence and copyright notices. It is kept as a separate data file, read at run
> time and never linked, so the program itself stays MIT. Delete the file if you would rather ship
> MIT-only, and everything still works — the built-in list and SFDP detection cover the rest.

A third file, `chiplist-ezp.xml`, holds chips converted from the chip database that ships with
the EZP2023+ / EZP2020 programmer software, by `tools/import_ezp.py`:

```powershell
python tools\import_ezp.py "EZP2023+.Dat" database.Dat -o chiplist-ezp.xml
```

The importer reads the EZP `.Dat` format directly — 68 byte records holding the name, the JEDEC
id, the size and the page size — and skips every chip already present in the tables above, so it
only ever adds. Chip ids and geometries are datasheet facts rather than authorship, but the
selection is somebody else's compilation, so it is kept in its own file exactly like the flashrom
table. Delete it and everything still works.

Only the SPI families are imported. The I²C and MicroWire entries are skipped by default because
chiplist needs an `addrtype` or an `addrbitlen` that the EZP file does not carry, and inventing one
means reading or writing the wrong part of an EEPROM with no error at all; `--i2c` opts in to
deriving `addrtype` from the standard 24Cxx geometries. `SPI_NAND` entries are skipped outright —
NAND needs bad block handling, spare areas and ECC, none of which this program has, so listing
those parts would only offer a chip it cannot actually read.

Parts that run at 1.8 V are marked `vcc="1.8"` on the way in. That matters because the old check
looked for `1.8V` in the chip *name*, and the largest group of 1.8 V parts — `W25Q64FW`,
`W25Q256FW` and the rest of the `EF60xx` family, plus `MX25U`, `MT25QU` and `GD25LQ` — never say so
in their names. Those chips are destroyed instantly by 3.3 V, and they were the ones getting no
warning.

A fourth list, `chiplist-user.xml`, holds chips you saved yourself. After **Chip → Detect chip via
SFDP** the program offers to store what it found there, and `--save-chip NAME` does the same from
the command line. It is deliberately a separate file: the shipped list is replaced on every update,
this one is not.

Unknown ids can be looked up in
[flashrom's `flashchips.h`](https://chromium.googlesource.com/chromiumos/third_party/flashrom/+/798d2adc9527f724bc5096a646cf99efdbb6b59e/flashchips.h).
Winbond ids are prefixed `EF`, so `0x6019` becomes `EF6019`. Append `_1.8V` to the name for 1.8 V
parts. *(Method by Floyd77.)*

---

## Building from source

Requires **32-bit Lazarus** — the project targets `win32` and the 64-bit IDE cannot build it
without an i386 cross compiler.

```powershell
git clone https://github.com/patnawa/AsProgrammer-ProX.git
cd AsProgrammer-ProX

# the hex editor component lives in a zip to keep the tree small
Expand-Archive mphexeditor.zip -DestinationPath .

lazbuild --add-package-link mphexeditor\src\mphexeditorlaz.lpk
lazbuild --build-mode=Release software\AsProgrammer.lpi
```

The binary lands in `software\AsProgrammer.exe`. Copy the runtime DLLs and data files next to it
before running — they are not kept in the repository.

To work in the IDE instead: open `software\AsProgrammer.lpi`, then *Package → Open package file*,
select `mphexeditor\src\mphexeditorlaz.lpk` and *Use → Install*.

Regenerate the toolbar icons after editing `tools\make_icons.ps1`:

```powershell
powershell -ExecutionPolicy Bypass -File tools\make_icons.ps1
```

### Tests

`tools\build.ps1` runs everything below before it compiles the program, so a broken
invariant stops the build rather than reaching a chip. None of it needs hardware.

| Suite | Covers |
|---|---|
| `tests\fftest.lpr` | Intel HEX and S-record round trips, sparse files, bad checksums, extended linear addressing |
| `tests\unittests.lpr` | SFDP parsing (basic table, DWORD-16, `FF84h`, sector maps), write protection decoding, individual block lock scanning, erase and write planning (`flashops`), the operation result channel, the production log and job files |
| `tests\hwtests.lpr` | The real `spi25` and `i2c` protocol layers driven through `tests\mockhw.pas`, a programmer that exists only in memory. Asserts on the exact opcodes sent and on how each I²C address type is split |
| `tools\validate_chiplist.py` | Duplicate chip entries, bad ids, page/sector/size sanity across both chip tables |

The two Pascal suites need different versions of `spi25`: the logic tests link a stub that
serves a synthetic SFDP image, the protocol tests link the real unit. `build.ps1` keeps them
in separate directories for that reason.

`hwtests` is the interesting one. The bugs that matter in a programmer are not arithmetic
mistakes, they are *"did we send an opcode this chip has never heard of"* — so the mock
records every byte and the tests assert on the transcript.

### Layout

```
software/
  main.pas / main.lfm     main window, flash operations, options
  spi25.pas               25-series SPI primitives (no LCL, no main — testable)
  flashops.pas            erase and write planning arithmetic (likewise testable)
  spi45.pas spi95.pas     DataFlash and SPI EEPROM
  i2c.pas microwire.pas   I²C and MicroWire
  sfdp.pas                JESD216 parameter table parser
  protbits.pas            status register / write protection decoding
  opresult.pas            the result of the last operation, and the exit code
  prodlog.pas             production CSV log and job files
  chipsave.pas            writing chips into chiplist-user.xml
  opthread.pas            worker thread for long operations
  basehw.pas              hardware abstraction, owns the AsProgrammer instance
  ch341hw ch347hw ft232hhw usbasphw avrisphw arduinohw buzzpirathw
  pascalc.pas             script interpreter
tests/mockhw.pas          in-memory programmer for the protocol tests
tools/build.ps1           validate, test, build, package
tools/validate_chiplist.py
tools/make_icons.ps1      icon set generator
chiplist.xml              chip database
```

### Debugging `buzzpirathlp.dll`

Build the x86 Debug configuration of `software\buzzpirathlp\buzzpirathlp.sln` in Visual Studio
2019, run a Release build of the program outside the IDE, then *Debug → Attach to Process* and pick
`AsProgrammer.exe`. Drop a `__debugbreak();` where you want to stop.

---

## Notes & caveats

- **Background operations** are experimental. Off by default; leave them off until you have tested
  on a chip you can afford to lose. With the option off the behaviour is identical to v3.
- With background operations off, long transfers freeze the window. That is expected, not a crash —
  watch the log and be patient.
- **Virtual machines and USB hubs cause problems.** Use a native OS and a direct port.
- Use a **short, good quality USB cable**. On the Bus Pirate keep protocol clocks around 100 kHz;
  long cables, clip adapters and low voltages all demand slower clocks.
- Some Bus Pirate firmwares have a binary-SPI bug. *Buzzpirat → Fix SPI Firmware Bug* works around
  it, and breaks firmwares that don't have the bug. Only enable it if you hit the problem.
- Reading flash from a Debug build can raise exceptions — use Release.

### Wiring examples

<details>
<summary>24C256 I²C EEPROM at 5 V</summary>

Feed 5 V to both `VCC` and `VPU`, enable pull-ups in *Buzzpirat → COM Port*, then select
*IC → I2C → _24Cxxx → _24C256*. *Buzzpirat → I2C → Just I2C Scanner* confirms the chip answers.
</details>

<details>
<summary>W25Q64 SPI NOR at 3.3 V</summary>

3.3 V to `VCC`, select the SPI radio button, press **Read ID** and pick `W25Q64BV`.
</details>

<details>
<summary>W25Q64FW SPI NOR at 1.8 V</summary>

**Never apply 3.3 V or 5 V.** Power `VCC` and `VPU` from an external 1.8 V supply with all grounds
tied together, enable pull-ups, set SPI output to open-drain and the clock to 30 kHz.
</details>

---

## Credits

AsProgrammer ProX stands on:

- **[nofeletru](https://github.com/nofeletru/UsbAsp-flash)** — AsProgrammer / UsbAsp-flash, the original program
- **[therealdreg](https://github.com/therealdreg/asprogrammer-dregmod)** — the dregmod fork this one started from, and its Buzzpirat / Bus Pirate support
- **[Ian Lesnet](https://buspirate.com/)** — creator of the Bus Pirate
- **Floyd77** — the add-an-unknown-chip method

Related: [flashrom-dregmod](https://github.com/therealdreg/flashrom-dregmod) ·
[flashrom for Windows x64](https://github.com/therealdreg/flashrom_build_windows_x64) ·
[buzzpirat](https://github.com/therealdreg/buzzpirat)

## License

MIT — see [LICENSE](LICENSE). Copyright (c) 2015 nofeletru and contributors.

## Issues

https://github.com/patnawa/AsProgrammer-ProX/issues

If the same problem reproduces with the official
[UsbAsp-flash](https://github.com/nofeletru/UsbAsp-flash), please report it upstream instead.
