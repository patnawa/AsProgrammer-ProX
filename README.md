<div align="center">

# Chipwright

**A flash programmer that refuses to guess your chip's voltage.**

SPI NOR · SPI NAND · I²C EEPROM · Microwire — across nine programmers.

[![Release](https://img.shields.io/github/v/release/patnawa/Chipwright?label=release)](https://github.com/patnawa/Chipwright/releases)
[![CI](https://img.shields.io/github/actions/workflow/status/patnawa/Chipwright/build.yml?branch=main&label=CI)](https://github.com/patnawa/Chipwright/actions/workflows/build.yml)
[![Changelog](https://img.shields.io/badge/changelog-every%20release%27s%20story-blueviolet)](CHANGELOG.md)
[![Platform](https://img.shields.io/badge/platform-Windows%20%C2%B7%20Linux-blue)](#building)
[![Built with](https://img.shields.io/badge/built%20with-Lazarus%20%2F%20FPC-orange)](https://www.lazarus-ide.org/)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

</div>

---

<div align="center">
<img src="assets/chipwright-main.png" alt="Chipwright main window" width="820">
</div>

---

## Why this exists

Sending **3.3 V to a 1.8 V flash chip destroys it permanently**. Sending too little only means the chip doesn't answer, and you try again.

Those two outcomes are not equally bad — so Chipwright never treats them as if they were. Every path that cannot work out a chip's supply voltage **fails low**, and when it genuinely doesn't know, it stops and asks you to check the datasheet rather than quietly picking one.

That sounds obvious. It wasn't happening: the chip catalogue carries a voltage field on only **5 of its 658 entries**, and every voltage decision in the program read that field directly. Auto-voltage never worked, and the guard meant to stop a pinned 3.3 V rail reaching a 1.8 V part *could never fire.* Chipwright fixes that.

## Supported programmers

| Programmer | SPI | I²C | Microwire | Notes |
|---|:---:|:---:|:---:|---|
| **CH347** (T / F) | ✓ | ✓ | — | **target voltage 1.8 V / 3.3 V** |
| **CH341A** | ✓ | ✓ | ✓ | the classic black/green dongle |
| **FT232H** | ✓ | ✓ | ✓ | |
| **EZP2023+** | ✓ | — | — | native whole-chip read / write / erase |
| **AVRISP mkII** | ✓ | ✓ | ✓ | |
| **USBasp** | ✓ | ✓ | ✓ | |
| **Arduino** | ✓ | ✓ | ✓ | |
| **Bus Pirate** | ✓ | ✓ | — | open-drain, external supply |
| **serprog** | ✓ | — | — | flashrom serial protocol |

**Chip families:** 25-series SPI NOR · SPI NAND · 24-series I²C EEPROM · 93-series Microwire · 45/95-series.

## CH347 target voltage

The **CH347 II V2.13** board is the only one of the nine with a switchable target rail. It's driven from **GPIO6** — low = 3.3 V, high = 1.8 V. That pin assignment is not documented by WCH; it was recovered from the vendor binary's `CH347GPIO_Set` call sites and then confirmed against real hardware.

GPIO6 is also the *only* pin Chipwright drives. The board's green activity LED blinks from bus traffic through its own circuit — SPI and I²C alike — so the software deliberately leaves GPIO4 untouched rather than replacing a lamp that already works with one that wouldn't.

> **Options → SPI → CH347 target voltage** — `1.8 V` · `3.3 V` · `Auto`

The same switch sits directly on the main window whenever a CH347 is selected: a **Target voltage** box with the three radio buttons and a `Chip:` line showing the selected part's supply voltage — the same front-screen control the board vendor's own software has. The box and the menu mirror each other, and either applies immediately while the device is open.

The board powers up at 1.8 V and Chipwright applies 1.8 V when it starts, so a rail left high by a previous session can never greet the next chip you seat. Within a session the level you pick stays put — it is not wound back between operations, or picking 3.3 V would never survive the read you picked it for.

### How a chip's voltage is worked out

| | Source | Example |
|:--:|---|---|
| 1 | the catalogue's `vcc=` attribute | rare, but authoritative |
| 2 | the `_1.8V` / `_3.3V` name suffix | `W74M12JW_1.8V` |
| 3 | model names that encode the voltage | `MX25U…` / `MX66U…` → 1.8 V |
| 4 | known all-1.8 V JEDEC id prefixes | `W25Q64FW` → `EF6017` |

Tier 4 covers the dangerous group: parts like `W25Q64FW` and `MT25QU256` that are 1.8 V but whose *names say nothing*. The nineteen prefixes — `EF50` `EF60` `EF80` `EF8A` `EF8E` `EF5B` `C860` `C863` `C867` `2041` `2050` `2044` `20BB` `2C5B` `9D70` `9D12` `E060` `1C38` `BA00` — were audited against **all 1,751 entries of the four shipped chip tables**, and `tools/validate_chiplist.py` re-proves the claim on every build, so a future catalogue import cannot quietly poison it.

`C225` is deliberately absent. Macronix used that id prefix for the 1.8 V MX25U family *and* for 3 V parts (`MX25L1635E`, `MX25L3239E`, `MX25L6439E`) *and* for wide-range MX25V — an id that cannot prove a voltage. That is why MX25U is recognised by **name** in tier 3 instead: the names never collide even where the ids do.

**Tiers 3 and 4 may only ever conclude 1.8 V.** Nothing is ever inferred *up* to 3.3 V, because that is the direction that kills chips.

If none of the three resolves, Chipwright asks:

```
The catalog does not state the supply voltage for W25Q64.

Open the chip datasheet and pick its supply voltage. Nothing is
guessed for you here on purpose: sending 3.3 V to a 1.8 V part
destroys it permanently, while too low a rail only means the chip
does not answer and you can try again.

          [ 1.8 V ]    [ 3.3 V ]    [ Decide later ]
```

Your answer is pinned into the voltage menu, so the level in use stays visible instead of hiding in a variable.

## Getting started

<table>
<tr>
<td width="42%"><img src="assets/programmer-hardware.jpg" alt="WCH programmer with a ZIF socket, held in a work jig"></td>
<td>

Any of the nine supported programmers will do. The one above is a WCH board with a ZIF socket — `PWR` and `RUN` on the silkscreen are the power and activity lamps.

Chipwright drives the **CH347** and **CH341A** through WCH's own DLLs, so the same driver package covers both.

Seat the chip with **pin 1 at the lever end** of the socket and close the lever before plugging in.

</td>
</tr>
</table>

1. Install the CH347 driver from **[`drivers/CH347T-Driver/`](drivers/CH347T-Driver)** — the CH341PAR package behind `wch.cn 2.6.2025.4`, confirmed working with this board.
2. Plug the programmer in. Windows should show *USB HighSpeed-SPI/I2C… CH347T* with no warning icon.
3. Download [`Chipwright-<version>.zip`](https://github.com/patnawa/Chipwright/releases) and unpack it. `Chipwright.exe` runs from the folder — no installer.

## Usage

The toolbar across the top is the safe order to work in, left to right.

### Reading a chip

| | Step | What to check |
|:--:|---|---|
| 1 | **Set the target voltage** | `Target voltage` on the left. `Auto` matches the chip once one is selected; otherwise pin it yourself |
| 2 | **Detect chip** | *Chip profile* fills in and the **Chip** lamp turns green |
| 3 | **Read chip** | Bytes appear in the hex view; *Last operation* shows the timing |
| 4 | Save with **Ctrl+S** | |

If detection finds nothing, the log says why — a wrong rail and a loose clip look identical to the chip, and both read back as all `FF`.

### Writing a chip

**Smart write** is the one to use. It reads the chip first, works out the minimum erase and program needed, shows you that plan, and only proceeds once you accept it. Nothing is written before you have seen what it intends to do.

> [!WARNING]
> Set the target voltage to match your chip **before** erase, write or verify. The board defaults to 1.8 V, so a 3.3 V part simply will not answer until you raise it — that is the safe failure, and it is deliberate.

### Reading the status strip

The four panels under the toolbar answer "why is this not working" without digging in the log:

- **Connection** — which programmer is actually attached
- **Interface / clock** — bus and SPI clock. A clip lead or long cable often cannot hold 60 MHz; a bus that cannot keep up reads back all `FF`, exactly like an empty socket. Drop to 15 MHz or slower if reads look blank
- **Chip profile** — the selected part and whether its ID has been confirmed
- **Last operation** — result and elapsed time

### Keyboard

`F5` detect · `Ctrl+O` open · `Esc` cancel · `F1` console

### Command line

`ChipwrightCLI.exe` drives the same engine headlessly for scripting and CI. Run it with `--help` for the current options.

## Building

Needs [Lazarus](https://www.lazarus-ide.org/) with FPC 3.2.2 (32-bit).

```sh
powershell -ExecutionPolicy Bypass -File tools\build.ps1     # Windows
./tools/build.sh                                             # Linux
```

Add `-Release` to zip a runnable release folder with the DLLs in place. Tests:

```sh
fpc -Mobjfpc -Sh -Fusoftware -FUtests/lib -otests/unittests.exe tests/unittests.lpr && ./tests/unittests.exe
```

## Changelog

Every release tells its story in **[`CHANGELOG.md`](CHANGELOG.md)** — what was wrong, why it mattered, and what the fix protects. Binaries with checksums are on the [releases page](https://github.com/patnawa/Chipwright/releases); CI rebuilds, re-tests and packages every tagged release from scratch before it is published.

## Credits

Chipwright builds on **[AsProgrammer](https://github.com/nofeletru/UsbAsp-flash)** by nofeletru, via AsProgrammer ProX. The chip catalogue, protocol engines and most backends are their work; this fork adds CH347 voltage control, the activity LED and the voltage-resolution fixes described above.

See [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md) for the full list. Released under the [MIT licence](LICENSE).

<div align="center">
<sub>Built for people who would rather read a datasheet than replace a chip.</sub>
</div>
