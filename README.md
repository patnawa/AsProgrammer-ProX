<div align="center">

# Chipwright

**A flash programmer that refuses to guess your chip's voltage.**

SPI NOR · SPI NAND · I²C EEPROM · Microwire — across nine programmers.

[![Release](https://img.shields.io/github/v/release/patnawa/ch347_programer_proX?label=release)](https://github.com/patnawa/ch347_programer_proX/releases)
[![Platform](https://img.shields.io/badge/platform-Windows%20%C2%B7%20Linux-blue)](#building)
[![Built with](https://img.shields.io/badge/built%20with-Lazarus%20%2F%20FPC-orange)](https://www.lazarus-ide.org/)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

</div>

---

## Why this exists

Sending **3.3 V to a 1.8 V flash chip destroys it permanently**. Sending too little only means the chip doesn't answer, and you try again.

Those two outcomes are not equally bad — so Chipwright never treats them as if they were. Every path that cannot work out a chip's supply voltage **fails low**, and when it genuinely doesn't know, it stops and asks you to check the datasheet rather than quietly picking one.

That sounds obvious. It wasn't happening: the chip catalogue carries a voltage field on only **5 of its 658 entries**, and every voltage decision in the program read that field directly. Auto-voltage never worked, and the guard meant to stop a pinned 3.3 V rail reaching a 1.8 V part *could never fire.* Chipwright fixes that.

## Supported programmers

| Programmer | SPI | I²C | Microwire | Notes |
|---|:---:|:---:|:---:|---|
| **CH347** (T / F) | ✓ | ✓ | — | **target voltage 1.8 V / 3.3 V**, activity LED |
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

The **CH347 II V2.13** board is the only one of the nine with a switchable target rail. It's driven from **GPIO6** — low = 3.3 V, high = 1.8 V — while **GPIO4** runs the activity LED.

Neither is documented by WCH. Both were recovered from the vendor binary's `CH347GPIO_Set` call sites and then confirmed against real hardware, which reports a GPIO direction mask of `0x50` — exactly those two pins and nothing else.

> **Options → SPI → CH347 target voltage** — `1.8 V` · `3.3 V` · `Auto`

The board powers up at 1.8 V and Chipwright restores 1.8 V when it closes, so a rail left high by a previous job can never greet the next chip you seat.

### How a chip's voltage is worked out

| | Source | Example |
|:--:|---|---|
| 1 | the catalogue's `vcc=` attribute | rare, but authoritative |
| 2 | the `_1.8V` / `_3.3V` name suffix | `W74M12JW_1.8V` |
| 3 | known-1.8 V JEDEC id prefixes | `W25Q64FW` → `EF6017` |

Tier 3 covers the dangerous group: parts like `W25Q64FW` and `MX25U6435F` that are 1.8 V but whose *names say nothing*. The prefixes — `EF60` `EF80` `EF50` `C225` `C860` `2041` `2050` `9D70` `E060` `1C38` — were derived from the catalogue itself, not from memory.

**Tier 3 may only ever conclude 1.8 V.** It is never allowed to infer 3.3 V from an id, because that is the direction that kills chips.

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

1. Install the CH347 driver from **[`drivers/CH347T-Driver/`](drivers/CH347T-Driver)** — the CH341PAR package behind `wch.cn 2.6.2025.4`, confirmed working with this board.
2. Plug in the programmer. Windows should show *USB HighSpeed-SPI/I2C… CH347T* with no warning icon.
3. Run Chipwright, press **Detect**, and check the reported chip and voltage before doing anything that writes.

> [!WARNING]
> Set the target voltage to match your chip **before** erase, write or verify. The board defaults to 1.8 V, so a 3.3 V part simply won't answer until you raise it — that's the safe failure, and it's deliberate.

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

## Known issues

- **The activity LED polarity is inferred, not measured.** It's implemented active-low from observing GPIO4 idle high with the lamp off. If the light sits on constantly and goes *dark* during operations, it's inverted — swap the two `LedBits` assignments in `software/ch347hw.pas`.
- `software/ezpspy.log` (96 MB) is still in git history from an earlier commit and exceeds GitHub's recommended file size.

## Credits

Chipwright builds on **[AsProgrammer](https://github.com/nofeletru/UsbAsp-flash)** by nofeletru, via AsProgrammer ProX. The chip catalogue, protocol engines and most backends are their work; this fork adds CH347 voltage control, the activity LED and the voltage-resolution fixes described above.

See [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md) for the full list. Released under the [MIT licence](LICENSE).

<div align="center">
<sub>Built for people who would rather read a datasheet than replace a chip.</sub>
</div>
