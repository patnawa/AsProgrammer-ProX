<div align="center">

# AsProgrammer ProX

**Flash memory programmer for SPI · I²C · MicroWire**

Sector-level erase · SFDP auto-detect · checksums · responsive UI

![version](https://img.shields.io/badge/version-4.21.1-2BB3F3?style=flat-square)
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
| **Transactional Smart write** | Takes two matching full-chip snapshots, builds a preservation-aware differential plan, unlocks safely, then programs and fully verifies every affected erase block. A `0→1` change erases only its containing block and restores untouched neighbour bytes from the trusted snapshot; pure `1→0` changes skip erase. Identity, exact transfer counts, WEL, BUSY, cancellation cleanup, and evidence are one typed operation rather than loosely chained buttons. |
| **Smart write on EEPROMs too** | 24Cxx, 93xx and 95xx are byte-alterable, so there is no erase to plan — but the shape still pays. A snapshot is taken, only the pages that actually differ are written, and every page the range touches is read back and compared, including the unchanged ones. Changing one byte of a 24C256 costs one page write instead of 512, and verifying the untouched pages is what notices a chip swapped between snapshot and write. `--smart --plan-only` previews the plan here too. |
| **SFDP auto-detect** | Reads the JEDEC JESD216 parameter table from the chip itself (`5Ah`) and fills in size, page size, address width and erase types. Works on chips missing from the database. Also reads the **4-byte address instruction table** (`FF84h`), **DWORD-16** (how *this* chip enters 4-byte mode, and whether its status register needs `06h` or `50h`) and the **sector map** (`FF81h`), so parts with boot blocks of a different size are reported instead of silently mis-erased. |
| **Write protection guard** | Before every erase and write, the status register is decoded and the protected range compared against the target. A locked chip accepts the command and silently ignores it, which otherwise shows up much later as an unexplained verify failure. When `WPS=1` the BP bits mean nothing, so the individual block locks are read back one block at a time with `3Dh` — 4 KB granularity across the boot blocks, 64 KB elsewhere — instead of giving up and letting the write through unchecked. |
| **Erase follows the chip's own map** | When the chip publishes an SFDP sector map, the erase is planned against it: boot-block parts are erased with the sector size that region actually uses, and long runs use the largest erase opcode that still fits inside the requested range. A whole-chip erase of a boot-block 8 MB part takes 158 commands instead of 2048. |
| **Four byte addressing without mode switching** | Chips over 128 Mbit that publish a 4-byte address instruction table are driven with their own `13h` / `12h` / `21h` / `DCh` opcodes, so the chip is never left in a sticky 4-byte mode. Where a mode switch is still needed it is unwound in a `finally`, so a cancelled or failed job cannot leave the chip in a state the next tool reads as garbage. |
| **Empty socket is named as such** | A missing, unpowered or back-to-front chip reads `FFh` from the status register, which looks exactly like "busy forever". That is now detected in half a second and reported as no chip answering, rather than after the full timeout — up to ten minutes on a chip erase — as "the chip stayed busy". |
| **Read twice and compare** | A SOIC clip with one marginal contact returns a dump that is the right size, reads every byte, raises nothing, and is wrong. Reading the chip twice and diffing is the only thing that catches it. When the passes disagree, the SPI clock steps down the programmer's own speed menu and both passes are reread — a marginal contact is usually fine one step slower — and the dump is refused only when the slowest clock still disagrees. One that stabilised below the selected clock says so, naming the speed that worked. |
| **Intel flash descriptor regions** | A dump holding an Intel descriptor logs its region map — where the BIOS starts, where the ME ends, and whether a region runs off the end of the image (the signature of a too-small chip selection). On the command line, `--region bios` reads, writes or verifies just that region; with `--smart` it reflashes a BIOS without touching the ME. |
| **SPI NAND (read, CLI)** | `--nand-info` identifies the chip and scans the factory bad-block markers; `--nand-read` dumps every good block in order with the chip's own ECC verdict checked after every page — an uncorrectable page fails the dump by block and page instead of returning plausible garbage. W25N512GV/01GV/02KV, GD5F1GQ4UA/UB, MX35LF1GE4AB, TC58CVG0S3. Erase/write land after live hardware validation. |
| **Chip health checks** | A non-destructive *chip doctor* (id stability, id opcode cross-check, WREN/WRDI execution proof, SFDP size consistency, fast-vs-slow clock read). A *true capacity test* that catches remarked fakes the way h2testw catches fake USB sticks — markers at power-of-two boundaries, with every touched sector backed up, restored and byte-verified. A destructive *surface scan* (badblocks for SPI NOR): erase/55/AA/address-stamp per block with a bad-block map; both tests drive 4-byte addressing on chips beyond 16 MB. Erase jobs warn when blocks erase five times slower than the median — flash slows down before it fails. |
| **AT45 geometry from the chip** | A DataFlash declares its family, capacity and page mode in its status register, so the selected page size is checked against the real chip before every operation — a 161 in power-of-2 mode has 512-byte pages, and driving it as 528 would shift every address in the job. Read ID fills both size fields from the chip itself. |
| **The connection is checked before anything is touched** | The JEDEC id is read eight times before every read, write and erase. If it is not identical every time, the job stops before a single byte moves. |
| **Write enable is confirmed, not assumed** | `WREN` is followed by a status register read to confirm `WEL` actually latched. A chip with `WP#` held low accepts `WREN`, ignores it, and then silently ignores everything after it. That used to surface as "verify failed at every address" after the whole write; now it is *"the chip did not accept write enable"* before the first page. |
| **Program and erase failures the chip reports itself** | Micron's flag status register (`70h`), Macronix's security register (`2Bh`) and Spansion's `SR1` error bits are read after each erase and program. Those parts clear BUSY normally and raise a flag instead, so a failed erase used to pass unnoticed unless verify happened to be on. |
| **The erase is checked to have taken** | A protected chip accepts the erase command, clears BUSY, and keeps its data. Each erased block is spot-checked afterwards, so *"the erase did not take"* is reported instead of a write over live data. |
| **Vendor-aware protection bits** | Macronix and ISSI keep **four** protect bits where Winbond keeps three, so reading them the Winbond way reported a smaller locked area than the real one and let writes through. Spansion uses bits 6 and 5 as error flags, not `SEC`/`TB`. Each family is now decoded by its own layout, and a vendor whose layout is not known says so rather than guessing. |
| **`SRP1:SRP0` explained** | The four combinations mean genuinely different things. Instead of an unexplained failure later you get *"hold WP# high or the unlock will be accepted and silently ignored"*, or *"this chip is permanently locked"*. |
| **Timeouts come from the chip** | JESD216 DWORD-10 and DWORD-11 carry each part's real erase and program times. A 256 Mbit chip erase that legitimately needs twelve minutes is no longer cut off at ten, and a page write that should take 3 ms no longer blocks for five seconds before admitting failure. |
| **Fast read** | Reads use `0Bh` (or `0Ch` for native four-byte parts) when the chip publishes SFDP. `03h` is specified to roughly 33–50 MHz on most parts, which is right at the edge of the clocks the FT232H and CH347 already run at. |
| **Stuck chips are recovered** | A chip left in QPI mode or four-byte mode by another tool answers `9Fh` with all-`00` or all-`FF` and reads as dead. A QPI exit and a JEDEC soft reset (`66h`/`99h`) are tried before believing it. |
| **The dump itself is checked** | After a read: entropy, the FF/00 ratio, and whether the image repeats at some stride. *"Every byte is FF"* and *"the dump repeats every 1 MB, so the address wrapped and the selected size is too large"* are the two commonest silent failures, and both are now named. Intel flash descriptors, UEFI volumes and coreboot images are identified. |
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
| **Editable chip database** | 1751 chips across five plain-XML files: the master list, flashrom- and EZP-derived lists, IMSProg-derived parts, and your own `chiplist-user.xml`, which survives program updates. Adding a chip is one line; `tools/merge_chiplist.py` folds other lists in without hand-editing, reporting conflicts instead of overwriting. |

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
| **serprog** | ● | | | Any board speaking flashrom's serial protocol: Raspberry Pi Pico (pico-serprog), STM32, ESP32, frser-duino. Set the COM port under *Settings*. |
| **EZP2023+** | ◐ | | | Identify, read, whole-chip write and erase. Every write is read back in a fresh USB session and compared byte for byte. SFDP, protection decoding, Smart write and the chip health tests cannot work through it — those need raw SPI commands, which the firmware has no way to send. Uses libusb-win32 1.4.0.2; the device-mode driver must be installed once. |

Chip families: 25-series SPI NOR, 45-series DataFlash, 95-series SPI EEPROM, 24-series I²C EEPROM,
93-series MicroWire EEPROM, KB9012 EC, and SPI NAND (W25N / GD5F / MX35 / TC58 — read and
bad-block scan from the command line, erase/write after live validation).

---

## Quick start

1. Download the latest release: **https://github.com/patnawa/AsProgrammer-ProX/releases**
2. Unzip anywhere and run `AsProgrammer.exe` (keep the whole folder together — see
   [Runtime files](#runtime-files)).
3. Pick your programmer under **Hardware**.
4. Connect the chip, press **Read ID**. If the chip is not in the list, use
   **Chip → Detect chip via SFDP**.
5. Press **Read** to dump, or load a file and use the write button's dropdown →
   **Smart write** for a preservation-aware, differential write with full
   affected-block verification. With an EZP2023+, use ordinary **Write**
   instead: its firmware replaces the whole chip and AsProgrammer verifies
   the complete result automatically.

The complete signed EZP driver bundle is stored in
`drivers\EZP2023Plus`; no separate Desktop download is required. With exactly
one EZP connected, run `tools\update_ezp_libusb1402.ps1` from an elevated
64-bit PowerShell. On a new PC it installs the signed EZP-specific binding; on
an existing installation it updates the kernel and 32/64-bit libusb runtime to
1.4.0.2. The updater validates every signature, creates a rollback backup,
restarts only `1FC8:310B`, and rolls back automatically if the device does not
return with status `OK`. See `drivers\EZP2023Plus\README.md` for package
contents, checksums and verification commands.

The **Safe workflow** strip keeps the normal path visible: **Detect chip →
Open image → Smart write**, with `Read chip` and `Verify` kept to the right of
a divider as the supporting tools. Each step enables only when its
prerequisites are met, the next step you can actually take is the one shown in
bold, and the message on the right says what is missing — including the things
that used to surface only after you pressed Write, such as an image that does
not fit the chip from the current start address. A step you cannot press
explains why in its tooltip rather than just sitting greyed out. Useful
shortcuts are `F5` to detect, `Ctrl+O` to open an image, `Ctrl+R` to read,
`Ctrl+Shift+P` for Smart Write, `Ctrl+Shift+V` to verify, and `Esc` to request
a safe cancellation.

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
AsProgrammer.exe --write patch.bin --chip W25Q64BV --smart
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

### Checking

```
AsProgrammer.exe --read dump.bin --chip W25Q64BV --read-passes 2
AsProgrammer.exe --compare approved.bin --chip W25Q64BV
AsProgrammer.exe --sfdp-dump w25q64.sfdp.bin
AsProgrammer.exe --sfdp-decode w25q64.sfdp.bin      # no hardware needed
AsProgrammer.exe --scan dump.bin                    # no hardware needed
```

| Switch | Effect |
|---|---|
| `--read-passes N` | Read the chip N times (1–16) and fail if the reads disagree. The only thing that catches a clip making a marginal contact: the dump is otherwise indistinguishable from a good one |
| `--compare FILE` | Compare the chip against `FILE` and report the first difference |
| `--sfdp-dump FILE` | Write the chip's raw SFDP table to `FILE` |
| `--sfdp-decode FILE` | Decode a table saved earlier, with no chip attached |
| `--scan FILE` | Report on a dump without any hardware: entropy, a wrapped address, an all-FF read, the image type. Exit code 1 if it looks wrong |
| `--no-fast-read` | Use `03h` instead of `0Bh` even when the chip declares SFDP |
| `--smart` | Run SPI NOR through the transactional differential planner and executor. The planner preserves bytes outside the patch, performs only required erases/programs, and fully verifies affected blocks. On 24Cxx, 93xx and 95xx it runs the EEPROM differential executor instead: write only the differing pages, verify every page the range touches |
| `--smart --plan-only` | Dry run: take the trusted snapshot, build the differential plan, and print it — erase blocks per opcode, program pages, verify coverage, and the chip-declared worst-case time — without touching the status register or writing anything |

`--scan` and `--sfdp-decode` never touch a programmer, so they work on a
machine that has none.

`--hw` forces a programmer (`ch341`, `ch347`, `ft232h`, `usbasp`, `avrisp`,
`arduino`, `buzzpirat`, `serprog`, `ezp`); without it the one that is plugged
in is used. EZP writes always replace and verify the complete chip; `--smart`,
SFDP and the chip tests are unavailable through that firmware.
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
| `--export-chip NAME` | Write `NAME.export.txt` (a ready-to-contribute `chiplist.xml` line plus instructions) and `NAME.sfdp.bin` (a drop-in regression fixture for `tests/sfdp/`). One detected chip on your bench becomes coverage for everyone |

A job file is plain `key=value`; `#` starts a comment. Any key may be omitted,
and only the keys present are checked:

```
# the approved image for product A
chip=W25Q64BV
size=8388608
crc32=0xDEADBEEF
```

For a fail-closed production station, use an authenticated production manifest
instead of the legacy optional job file:

```powershell
$env:ASPX_LINE_HMAC = '<hex-encoded secret of at least 32 bytes>'
AsProgrammer.exe --prod-job product-a.job --prod-auth product-a.job.auth `
  --prod-key-id line-a-2026 --prod-key-env ASPX_LINE_HMAC `
  --evidence-dir D:\aspx-evidence --chip W25Q64JV
```

| Switch | Strict production meaning |
|---|---|
| `--prod-job FILE` | Canonical production manifest; its authenticated image path, range, chip profile, electrical limits, verification, UID, and read-pass requirements become the immutable request |
| `--prod-auth FILE` | Detached HMAC-SHA-256 authentication record for the exact manifest bytes |
| `--prod-key-id ID` | Independently configured key identifier that must match the authentication record |
| `--prod-key-env NAME` | Name of the environment variable containing the hex HMAC key. The key itself must never be placed on the command line or in logs |
| `--evidence-dir DIR` | Durable evidence destination. A programmed unit is not reported as PASS until full physical verification, atomic publication of the HMAC-signed evidence envelope, and recording into the station's HMAC-chained `consumed.log` anti-replay state all succeed. That state also refuses stale job revisions, already-passed chip UIDs, and a station clock that moved backwards |

The five strict-production switches are used together. The image is read from
the already verified, retained manifest image handle rather than reopened by
filename. This mode is SPI-NOR-only and automatically enters transactional
Smart Write; combining it with `--write`, legacy `--job`, or `--erase` is a
usage error. Admission fails closed on authentication, expiry, chip-profile,
programmer/adapter, or live electrical-preflight uncertainty. See
[the production security model](docs/production-job-security.md) for the trust
boundary and deployment requirements.

## Runtime files

The `.exe` starts on its own: every hardware DLL is loaded at run time, so you only need the
files for the programmers you actually use. A missing DLL makes that one programmer report as
absent — the same as if it were unplugged — instead of the old *"cannot proceed because … .DLL
was not found"* system error before the window even opened.

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
| `tests\unittests.lpr` | SFDP parsing (basic table, DWORD-16, DWORD-10/11 timing, `FF84h`, sector maps), per-vendor write protection decoding, `SRP1:SRP0`, the program/erase failure flags, individual block lock scanning, erase and write planning (`flashops`), image sanity checks (`imgcheck`), the operation result channel, the production log and job files |
| `tests\hwtests.lpr` | The real `spi25` and `i2c` protocol layers driven through `tests\mockhw.pas`, a programmer that exists only in memory. Asserts on the exact opcodes sent and on how each I²C address type is split |
| `tests\adapter\spi25noradapter_tests.lpr` | The real hardware adapter's exact SPI framing, repeated JEDEC identity gate, native and stateful four-byte strategies, short-transfer rejection, and exactly-once cleanup |
| `tests\norengine_tests.lpr` | Preservation-aware differential plans, typed operation outcomes, cancellation boundaries, deterministic failure injection at every device call, and randomized invariants |
| `tests\eepromengine_tests.lpr` | The EEPROM sibling: page-differential plans, round trips against a virtual chip that *rejects* unaligned page writes rather than reproducing the wrap, verification catching a chip that will not take the data, cancellation boundaries, failure injected at every device call, and 400 randomized snapshot/patch rounds asserting the chip ends up exactly `snapshot ← patch` with one write per differing page |
| `tests\sfdp_sector_map_tests.lpr` | JESD216 sector-map descriptor bit semantics and fail-closed rejection of unresolved or ambiguous maps |
| `tests\sfdp\` | Whole SFDP tables decoded straight from a file and checked against `manifest.txt`. Dump a table from any chip with `--sfdp-dump`, drop it in, add one manifest line, and that part can never silently regress again — including for people who do not own it |
| `tests\chipprofile\chipprofile_tests.lpr` | Stable canonical SPI NOR profile bytes and strict rejection of ambiguous records before production hashing |
| `tests\stage9tests.lpr` | HMAC-authenticated manifests, retained image handles, electrical preflight, atomic durable evidence envelopes (unsigned and HMAC-signed), and the HMAC-chained anti-replay production state |
| `tools\validate_chiplist.py` | Duplicate chip entries, bad ids, page/sector/size sanity, erase opcodes that no 25-series part defines, and supply voltages outside anything a serial flash runs at |

The erase planner is also tested against **3000 randomly generated requests**
per run, asserting the four properties that must hold whatever goes in: every
step is aligned to its own size, the steps are contiguous, nothing runs past
the end of the chip, and the plan covers everything that was asked for. That
function is where a bug destroys somebody's data, and hand-picked examples only
find the cases the author already thought of.

The platform-independent suites are LCL-free, so they also build and run on
Linux and macOS:

```bash
./tools/build.sh          # needs fp-compiler; runs everything, no hardware
```

CI runs the Windows build and, separately, the same suites on Linux x86-64 — a
second compiler and a second word size over the code that decides whether a
chip survives.

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
  spi25noradapter.pas     exact real-hardware adapter for the NOR executor
  operationmodel.pas      immutable requests, typed outcomes/events, cancellation
  norplanner.pas          preservation-aware differential erase/program plans
  norengine.pas           fail-closed single-owner transactional executor
  eepromengine.pas        page-differential planner/executor for 24/93/95
  eepromadapters.pas      those three families' real-hardware adapters
  flashops.pas            erase and write planning arithmetic (likewise testable)
  spi45.pas spi95.pas     DataFlash and SPI EEPROM
  i2c.pas microwire.pas   I²C and MicroWire
  sfdp.pas                JESD216 parameter table parser, including declared timing
  protbits.pas            status register / write protection decoding, per vendor
  imgcheck.pas            what a dump looks like: entropy, wrapped address, image type
  opresult.pas            the result of the last operation, and the exit code
  prodlog.pas             production CSV log and job files
  prodjob.pas prodcrypto.pas productiongate.pas
                          authenticated production admission
  chipprofile.pas         canonical hashable SPI NOR definitions
  electricalpreflight.pas typed fail-closed electrical policy
  prodevidence.pas        atomic durable run evidence
  chipsave.pas            writing chips into chiplist-user.xml
  opthread.pas            worker thread for long operations
  basehw.pas              hardware abstraction, owns the AsProgrammer instance
  ch341hw ch347hw ft232hhw usbasphw avrisphw arduinohw buzzpirathw
  pascalc.pas             script interpreter
tests/mockhw.pas          in-memory programmer for the protocol tests
tests/sfdp/               SFDP tables plus the manifest of what each should decode to
tools/build.ps1           validate, test, build, package (Windows)
tools/build.sh            the hardware-free suites on Linux and macOS
tools/validate_chiplist.py
tools/make_sfdp_fixtures.py
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
  on a chip you can afford to lose. As of 4.4 they cover I²C, MicroWire and the 45/95/KB families
  too — before that the option silently applied to SPI-25 only.
- With background operations off, long transfers freeze the window. That is expected, not a crash —
  watch the log and be patient.
- **Fast read is on by default** for chips that publish an SFDP table, because `03h` is out of spec
  at the clocks the FT232H and CH347 run at. If a chip misbehaves, turn it off in *Options* or pass
  `--no-fast-read`, and please report it.
- The **connection check** costs eight `9Fh` reads before each operation. If you are driving a
  chip that cannot answer `9Fh`, turn it off in *Options*.
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

## Changelog

### 4.22.0.2 — release driver bundle stays byte-exact

Git attributes now prevent Windows checkout from changing line endings inside
the checksum-pinned EZP driver bundle. Release assembly validates all 24
vendor/upstream payload hashes after copying and fails before publishing if
even a licence or documentation byte differs.

### 4.22.0.1 — EZP2023+ is detected safely at startup

Automatic programmer detection now finds an attached EZP2023+ even when the
saved/default backend is a serial programmer. Detection only enumerates the
USB descriptor for `1FC8:310B`: it does not open or claim the programmer,
reset it, or send a chip command. The same non-invasive check tracks EZP
disconnect/reconnect events without bringing back the old three-second window
freeze or disturbing a whole-chip transfer.

### 4.22.0.0 — EZP2023+ write fixed and verified on the real programmer

Whole-chip Write and Erase are enabled again. The missing protocol state was
not another packet in the captured write itself: the vendor program performs
two complete CHECK_CHIP sessions first, closes both, and opens a third session
for descriptor, START and data. The descriptor reply must be `01` plus the
selected JEDEC id. AsProgrammer now reproduces that state machine and refuses
to send any image data if either priming pass or the descriptor reply disagrees.

The USB transport is hardened as well. RESET is one-way rather than a command
with a reply, negative read interruptions are retried without shifting the
stream, and a stuck CH552 gets up to three full reset/reopen cycles before the
user is asked to power-cycle it. The bundled 32-bit `libusb0.dll` is the signed
1.4.0.2 release; it includes upstream large-transfer, ordering, hang and bulk
ZLP fixes absent from 1.2.6.0.

The repository also carries a self-contained Windows driver bundle under
`drivers\EZP2023Plus`: the signed EZP-specific device package, the unmodified
signed libusb-win32 1.4.0.2 AMD64/x86/ARM64 runtime, upstream licences and
SHA-256 checksums. The elevated updater consumes these project-local files and
supports both a first installation and an idempotent upgrade.

Validated on the connected EZP2023+ (`1FC8:310B`, identity `90381CBC`) and a
W25Q64-class 8 MiB chip (`EF 40 17`): a backup was read twice, written back
through the isolated writer, then read twice with exactly the same SHA-256.
The integrated application follows every write with its own fresh-session,
full-chip byte comparison. Smart write, SFDP and health tests remain disabled
for EZP because its firmware cannot issue arbitrary SPI commands.

### 4.21.1.0 — EZP2023+ writing is disabled: it corrupts chips

4.21.0.0 shipped a whole-chip write for that programmer on the strength of
the protocol documentation. Tested against real hardware it destroys data,
so it is now refused outright.

What happens: the firmware accepts all 8 MB without reporting anything
wrong, and the chip then reads back as neither the old image nor the new
one. So the sequence being used — descriptor, START, data blocks to the
second OUT endpoint, RESET — is still missing something. Notably the
reference implementation does not verify its write path either, and the
erase commands it defines (`0102h`, `0Ah`) are never called by it.

Two real bugs were fixed on the way and are worth keeping: data blocks
were being sent with the one-second command timeout, though the firmware
erases the whole chip after START and ignores the bus for tens of seconds
first; and the automatic USB-reset recovery could fire *during* a data
stream, which knocks the firmware out of its receiving state so every
later block lands in the wrong place. Recovery is now forbidden mid-stream
on principle — resetting a device that is halfway through writing a chip
can only make things worse.

Reading remains verified: a full 8 MB dump of a W25Q64JV, twice.

### 4.21.0.0 — the EZP2023+ writes and erases too (withdrawn in 4.21.1.0)

Verified on real hardware: a W25Q64JV read back all 8 MB through the
programmer, Intel descriptor and all.

The firmware cannot accept a page-at-a-time write, but it writes a whole
chip perfectly well, so the ordinary Write and Erase buttons now route to
that when the EZP2023+ is selected — no separate menu to learn. Because
the same programmer can also read, every write is followed by a full
read-back and a byte-for-byte compare, which is a stronger check than the
page-level verify the other backends do. Erase is a whole-chip write of
FF, which is the only erase this firmware offers and lands in the same
verified state. A buffer shorter than the chip is allowed and says so
first: the remainder becomes FF, because a whole-chip write cannot leave
it alone. A write interrupted midway reports exactly how far it got and
that the chip now holds part of each image.

The bug behind "read: FAILED, received -1 of 2048 bytes": each operation
opens its own session, so the chip id captured when you pressed Read ID
was gone by the time the read described the chip to the firmware, and a
descriptor carrying id zero is silently refused. The id is now fetched
whenever the descriptor is built. The backend's own explanation also
reaches the log now instead of being replaced by the caller's generic
"short read" line.

### 4.20.2.0 — the EZP2023+ un-wedges itself

Measured against real hardware with a new standalone diagnostic
(`tools/ezpsmoke.lpr`, read-only), which is what finally separated "our
code is wrong" from "the board is not answering". The device enumerated
perfectly — bound to libusb0, `Status: OK`, endpoints exactly `0x82` in
and `0x02`/`0x01` out, all bulk — and still refused every 64-byte command
packet with a timeout, in this program *and* in the vendor's own software.
`set_configuration` did not help, nor did `clear_halt`; `usb_reset`
followed by reopening did, every time. A stuck CH552 is now recovered
automatically on the first refused command instead of being reported as a
dead programmer, and the log says when that happened.

The other fix that diagnostic found: the four-byte identity code at the
end of the CHECK_CHIP reply is per-device, not a model constant. The
reference implementation's `9A7336BD` and the `90381CBC` on the unit here
are both valid, so requiring one of them rejected a perfectly good
programmer. The code is now logged for reference and only an all-zero or
all-FF answer counts as "nothing there".

### 4.20.1.0 — the EZP2023+ no longer freezes the window

Three faults in yesterday's backend, all of them mine. The programmer
poller reopens the selected device every three seconds, and opening the
EZP2023+ also talked to the chip — so the window stalled on USB traffic
on a loop; opening now touches the USB device only, and the identity
check and chip id happen when something actually asks. Every reply was
waited for with the twenty-second timeout meant for whole-chip data
blocks, turning one unanswered 64-byte packet into a twenty-second
freeze; command replies now use one second. And `usb_set_configuration`
on an already-configured libusb0 device can hang outright, so it is gone
and a failed interface claim is no longer treated as fatal — neither is
something the working reference implementation does. Auto-detect no
longer probes the EZP either: opening somebody else's programmer every
three seconds while it may be mid-stream is not worth the convenience.

Also fixed: after refusing an opcode the firmware cannot send (`90h`,
`ABh`, `15h`), a following read was served the `9Fh` id as though it were
that command's answer. A read with nothing pending now says so instead of
fabricating a reply.

### 4.20.0.0 — the EZP2023+ can identify and read

Reverse engineering that programmer (Spring 1FC8:310B, a CH552G board on
libusb0 — the same driver stack this program already binds for UsbAsp)
turned up a protocol unlike every other backend's: it exposes no raw SPI
at all. You hand the firmware a 64-byte descriptor — chip class, algorithm
index, page size, delay, capacity, expected JEDEC id, clock, voltage — and
it performs the entire read or write by itself, streaming 64-byte blocks.

So the new backend implements exactly what that allows and says so about
the rest: `9Fh` is answered from the programmer's own chip detection, `03h`
reads are served from a whole-chip image pulled once per session (so the
chip is read once however the caller chunks it), and every other opcode is
refused with a message naming the reason. Read ID, Read, dump inspection,
compare and verify-against-a-file work. Write, erase, SFDP, Smart write
and the chip health tests do not, and cannot until someone teaches this
program a whole-image write path worth trusting.

### 4.19.2.0 — "FT_Open device not found" now says which problem it is

The D2XX driver returns the same `FT_DEVICE_NOT_FOUND` whether no FTDI
board is attached or `ftd2xx.dll` is missing entirely — and this program's
own fail-closed stubs, which exist so a missing DLL cannot stop the exe
from starting, return it too. One message, three causes, and the operator
goes hunting for a cable when the real answer is a file. The FT232H
backend now checks whether the driver actually bound, and says either
*"ftd2xx.dll is not available — put it next to AsProgrammer.exe"* (the
release zip ships one; a freshly built exe has no DLLs beside it) or
*"the driver answered but found no FTDI device — check the cable, and that
the board is not claimed by the VCP driver instead of D2XX"*.

### 4.19.1.0 — 42 chips learn their real supply voltage

Reverse engineering the EZP2023+ ver 3.0 chip database named the record
fields the importer had listed as unknown, and turned up something worth
knowing: the voltage byte is the rail that programmer switches on, not the
chip's rating. Every SPI flash in the file reads 3.3 V — including every
part whose own name ends in `(1.8V)` — so trusting it would have labelled
every 1.8 V part as 3.3 V, which is the mistake that destroys one. 1.8 V
therefore still comes from the part name; the 5 V records, which match
their datasheets, gave 42 chips in `chiplist-ezp.xml` a real `vcc`.

The EZP2023+ itself remains unsupported as a programmer, and that is a
protocol limit rather than an oversight: its firmware exposes only
whole-chip read/write/erase, with no way to send an arbitrary SPI command,
so SFDP, protection decoding, Smart write and the chip health tests have
nothing to talk to.

### 4.19.0.0 — and the C5h bank-register chips too

4.18 refused chips that reach their upper banks through the extended
address register; now they are driven properly. The tests track the
current 16 MB bank, rewrite the C5h register whenever an operation
crosses into another bank — and read it back with C8h, because a bank
that did not stick means every following command lands 16 MB away from
where it was aimed — keep every frame 3-byte, clamp read chunks at bank
boundaries (a 3-byte read that runs off the edge wraps silently back
into the same bank), and always park the register at bank 0 on the way
out, since that is what every other tool assumes.

### 4.18.0.0 — the chip tests learn 4-byte addressing

The capacity test and the surface scan now drive chips beyond 16 MB —
W25Q256, MX25L256, GD25Q256 and friends up to 256 MB. The session enters
the chip's own 4-byte mode (B7h, WREN+B7h, the Spansion bank register or
Micron's B1h, per what the chip declares) and every erase, program and
read frame carries the full four-byte address; the mode is unwound in a
`finally` like everywhere else. Chips that reach their upper banks only
through the C5h extended address register are refused with a message
saying exactly that, rather than silently testing the wrong 16 MB.

### 4.17.0.0 — surface scan: badblocks for SPI NOR

Per block: erase and confirm blank, program 55h and confirm, AAh and
confirm, then a pattern where every dword holds its own address — the one
pattern a broken address line cannot survive — and erase again. Bad blocks
are mapped rather than aborting at the first one; the chip ends fully
erased and both UIs say so loudly before starting (`--surface-scan` needs
`--force`). First-round erase timings feed the wear detector.

### 4.16.0.0 — wear telemetry, and a verify that cannot be echoed

Erase jobs now keep the per-block durations the BUSY polls already
produced: blocks erasing five times slower than the median get a wear
warning naming the worst offender, because flash slows down before it
fails. NAND dumps report corrected-ECC counts per block — a cluster in one
block is a block dying, not noise. And the verify pass reads the array,
not the device's recent memory: a JEDEC 66h/99h reset precedes the final
compare, and chunks are checked in deterministically shuffled order, which
a device echoing recently transferred data cannot pass.

### 4.15.0.0 — the counterfeit test and the chip doctor

The commonest bad chip is remarked, not broken: a 4 MB die sold as a
W25Q128 that wraps every address above its real size and verifies every
write through the same wrap. The capacity test writes distinct markers at
every power-of-two boundary and looks where they landed — the first
address holding somebody else's marker is the real capacity. Every sector
the test can touch is backed up first, restored afterwards, byte-verified;
a chip that simply loses markers is reported as failing writes, not fake.
Chip menu or `--capacity-test --force`; a detected fake exits 1. The chip
doctor (`--chip-test`) is the non-destructive sibling: id stability, the
9F/90/AB/15 opcodes telling one story, WREN/WRDI as proof the chip
executes commands, SFDP-vs-selected size, and the same quarter megabyte
read at the fastest and slowest clock.

### 4.14.0.0 — serprog: every DIY programmer at once

A Raspberry Pi Pico running pico-serprog costs four dollars and speaks
flashrom's documented serial protocol; so do STM32, ESP32 and frser-duino
boards. One new backend supports them all: pick **serprog** under
*Programmator*, set its COM port once, done. serprog's SPI operations are
atomic (the firmware owns chip select), so the backend queues the command
phase and executes each transaction as one exchange — the protocol layers
never notice. SPI only, honestly: I2C, MicroWire and the KB9012 EC path
say so instead of misbehaving.

Releases are also published by CI now: pushing `v<version>` builds, runs
every suite, and attaches the zip those suites just ran against — after a
fast gate that the tag matches `PROX_VERSION`, so a tag on the wrong
commit cannot ship a mislabelled build.

### 4.13.0.0 — 119 more chips, from everyone's lists at once

Every open chip database checked against ours: latest flashrom (already
fully mined), upstream UsbAsp-flash (11 new), the community-consolidated
list from upstream issue 163 (51 new after filtering out what must not be
taken — AVR parts this program cannot drive, NAND entries the GUI cannot
drive *yet*, and page-variant duplicates the live AT45 detection obsoletes),
and IMSProg's database, which turned out to use the same 68-byte records as
the EZP files (57 parts nobody else had, shipped as `chiplist-imsprog.xml`,
GPL-3-or-later, deletable). 1751 chips total. The Find IC search dialog now
actually searches all five files instead of two.

The machinery is reusable: `tools/merge_chiplist.py` diffs any chip list
against the master, reports what is new, identical, or conflicting, and
`--write` inserts the new entries under the right vendor group without
disturbing the master's hand formatting — then validates the result.

### 4.12.0.0 — CH347 over libusb, awaiting silicon

Cross-platform step 3, first half: the CH347's reverse-engineered bulk
packet layout as a pure, byte-exact-tested unit; a libusb-1.0 transport
implementing the standard hardware contract; and a non-destructive smoke
harness (`tools/ch347smoke.lpr`). Compile-checked on every Linux CI run,
kept out of every UI until it passes on a real CH347.

### 4.11.0.0 — SPI NAND phase 2: it executes now

Phase 1 planned around bad blocks; this executes the plans. The engine
scans factory markers with ECC off (GD5F flags an erased page as an ECC
failure, which would make a fresh chip scan as all-bad), checks the chip's
ECC verdict after every dumped page and refuses uncorrectable ones by
block and page, unlocks before programming and believes only the read-back,
checks E_FAIL/P_FAIL after every erase and program, and reads every written
page straight back. The CLI gains `--nand-info` and `--nand-read` for
W25N512GV/01GV/02KV, GD5F1GQ4UA/UB, MX35LF1GE4AB and TC58CVG0S3. Erase and
write wait for live CH347 validation.

### 4.10.0.0 — Intel flash descriptor regions, named and usable

A dump holding an Intel flash descriptor now logs its region table — where
the BIOS starts, where the ME ends, and whether a region runs off the end
of the image (the signature of a too-small chip selection). The command
line gains `--region bios` (or fd/me/gbe/pd/ec): `--read` keeps only that
region at full-chip offsets, `--write --smart` reflashes a BIOS without
touching the ME, and `--region --erase` is refused because a whole-chip
erase under a one-region write would destroy the other regions.

### 4.9.0.0 — the clock steps down before the dump is refused

When read-twice-and-compare disagrees, the commonest cause is a clip
contact that is marginal at the selected clock and fine one step slower.
The reads now walk the programmer's own speed menu downward — rereading
both passes, since the fast reference may be the corrupted side — and only
refuse when the slowest clock still disagrees. A dump that stabilised below
the selected clock says so, naming the speed that worked.

### 4.8.0.0 — the AT45 tells you its own geometry

The two oldest TODOs in the tree. A DataFlash declares its family, capacity
and current page mode in its status register, so the page-size field is now
checked against the chip before every read, write and verify — a 161 in
power-of-2 mode has 512-byte pages, and driving it as 528 shifts every
address in the job with nothing to say so until verify. Read ID fills both
size fields from the chip itself, because the XML table cannot know a chip
was switched permanently to binary mode.

### 4.7.1.0 — a big verify read is not a disconnect

Smart write on a CH341A failed instantly with *"disconnected: verify read:
data read reply transferred -1 of 4096 bytes at 0x00000000"* — before a
single byte had been written. The chip was fine and so was the cable. The
CH341 vendor DLL refuses any single SPI transfer above 3937 bytes (measured
on hardware; its command buffer is 4096 bytes minus per-packet overhead) and
reports that refusal exactly like an unplugged programmer. The legacy read
path always dodged this with 2048-byte chunks, but the Smart-write engine
verifies in erase-block-sized reads — 4096 bytes — so the very first verify
step died on every CH341.

The hardware layer now states its per-call ceiling (`SPIMaxTransfer`: 2048
on CH341 and other conservative backends, 16787 on FT232H, 65535 on CH347),
and the NOR adapter splits long reads into complete re-addressed read
commands within that ceiling. Same wire format, same data, no more phantom
disconnects.

### 4.7.0.0 — the strip knows a new chip from an old one

The strip could see whether a chip was *selected* and whether the buffer was
*full*. It could not see the one thing that decides whether pressing Smart
write is routine or irreversible: **does this chip already hold data?** A
factory-blank part and a laptop's only surviving BIOS produced the identical
green "Ready for Smart write" — and auto-backup is **off by default**.

Three facts are now tracked, each tied to the chip identity it was learned
from, so they expire the moment you change chip, size, protocol, or unplug
the programmer:

- **Chip content** — after any full read the program remembers whether the
  chip came back blank or holding data. All-`FF` is only called *blank* when
  there is proof the chip actually answered (a JEDEC id on SPI, an ACK on
  I²C); otherwise it stays *unknown*, because a dead bus reads `FF` too.
- **Buffer provenance** — from a file (named in the strip), read from this
  chip, or edited by hand. Writing back what you just read is not the same
  risk as writing a stranger's file.
- **Identity proven or merely chosen** — `Detect chip` going green used to
  mean "a size is configured", which is true the instant you pick a name from
  a menu with nothing in the socket. The strip now says when a chip was
  chosen by hand and never confirmed against the socket.

From those it names the real situation: *chip reads blank — nothing to
lose*, *chip HAS DATA and it will be backed up first*, *chip HAS DATA and
auto-backup is OFF — it will be lost* (in red), *buffer was read from this
chip — writing it back changes nothing*, or *ready, but the chip has not
been read — you do not know what is on it*.

### 4.6.2.0 — the bar stopped painting its own name

A `TPanel` draws its `Caption`, and the LCL copies `Name` into `Caption`
when the caption is empty — so the workflow bar painted the word
"WorkflowPanel" across itself. The buttons covered all but the slivers
falling in the gaps between them, which looked like text hidden behind
`Read chip` and `Verify`.

### 4.6.1.0 — the Safe workflow strip tells you what is wrong

- **Smart write is reachable for the EEPROM families.** The strip still gated
  it on "is this SPI NOR", so the three families that gained a differential
  writer in 4.6.0.0 were locked out of their own button.
- **An image that does not fit the chip is reported before you press Write**,
  with the two sizes that disagree, instead of after — and Smart write stays
  disarmed until it does fit.
- A step you cannot press **explains why in its tooltip**: wrong family, no
  image, does not fit, odd MicroWire address.
- `Next: detect or select a chip` no longer appears on I²C and MicroWire,
  where Read ID does not exist and the Detect button is disabled.
- The start-address box **refreshes the strip** (it never did), and parses
  with `TryStrToQWord` — `Hex2Dec` raises on pasted non-hex text that the
  keypress filter cannot stop.
- **Layout is measured, not pinned to pixels**, so translations, larger fonts
  and high-DPI displays no longer overlap or clip the buttons. Bold marks the
  step you can take right now rather than sitting permanently on Smart write.

### 4.6.0.0 — Smart write for the EEPROM families

24Cxx, 93xx and 95xx are byte-alterable, so there is no erase to plan — but
the shape of Smart write still pays. A snapshot is taken, **only the pages
that differ are written**, and every page the range touches is read back,
including the unchanged ones: that is what notices a same-model chip swapped
in between snapshot and write. Changing one byte of a 24C256 costs one page
write instead of 512. `--smart` and `--smart --plan-only` accept these
families; strict production stays SPI-NOR-only.

### 4.5.0.0 — fifteen hunted bugs, signed evidence, no DLLs needed to start

A four-way deep-inspection review found fifteen real defects. The ones that
could cost data:

- the **write-protection guard decoded every vendor with the Winbond layout**,
  so a locked Macronix or ISSI chip sailed straight through it;
- **Spansion TBPROT was read from an opcode those chips do not implement**, so
  a floating-bus `FF` inverted the reported lock direction;
- **`Enter4B` failures were ignored** on write, read, verify and blank check,
  wrapping 4-byte addresses onto block 0;
- **auto-backup hard-failed every 95/45/KB write and erase**;
- an **aborted serial-number apply could log PASS** for a unit that was never
  programmed;
- Micron's flag-status erase/program bits were swapped, AT45 busy-polls
  trusted a dead bus reading `FF`, and an unaligned I²C erase wrapped onto
  bytes below the requested range.

Also new: evidence envelopes bind the run ID into their digest and strict
production **signs them under the station key**; `prodstate.pas` gives a
single station **fail-closed anti-replay state** (stale revisions, duplicate
runs, consumed UIDs and a backwards clock are all refused before PASS);
`--smart --plan-only` prints the full plan and the chip-declared worst-case
time without touching the chip; `--export-chip` emits a ready-to-PR chiplist
line plus a test fixture; the production suite **runs on Linux** as well as
Windows; and **every hardware DLL is loaded at run time**, so the program
starts with none of them present and a missing one reads as an absent
programmer rather than a startup error.

### 4.3.1.0 — the write loop that hung

`WriteFlash25` sized its first chunk as `(ChipSize - StartAddress) mod
PageSize`, which is **zero whenever the start address sits on a page
boundary** — the loop then ran forever issuing zero-length page programs.
Patching at `0x1000` on an 8 MB part hit it every time. The arithmetic moved
into `flashops.pas`, which has no LCL and no `main`, so the test suite can
reach it. Erase now follows the chip's own SFDP sector map, and a silent bus
is named as such.

### 4.2.0.0 — the command line told the truth

`Result := 0` was set after every write regardless of outcome, so a verify
mismatch, a still-protected chip and a busy timeout all exited `0`. There was
no channel from the operation layer back to the caller at all. `--verify` was
also parsed as both a flag and a value switch, so `--write fw.bin --verify
--erase` read `--erase` as the verify filename.

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
