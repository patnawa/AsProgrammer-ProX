# CH347Ⅱ V2.13 programmer board — what the software believes about it

This is a reverse-engineered description of a commercial board, not a design
document for one. Everything below is either read out of the vendor's own
program, confirmed against a real device, or marked as **unverified**.

The distinction matters more than usual here. The software refuses operations
based on what it thinks this board does with 1.8 V and 3.3 V. A wrong entry in
this file is a destroyed chip, not a cosmetic error.

## Provenance of each claim

| Claim | How it was established | Confidence |
|---|---|---|
| GPIO6 (`$40`) selects target VCC | Two `CH347GPIO_Set` call sites in the vendor program differing only in the data byte (`$00` / `$40`), selected by the ItemIndex of the voltage radio group | Confirmed |
| GPIO6 low = 3.3 V, high = 1.8 V | Same call sites, cross-checked against the vendor UI labels | Confirmed |
| GPIO4 (`$10`) drives the activity LED, active low | `CH347GPIO_Get` reads direction `$50`, which is exactly these two pins; LED behaviour confirmed on a real board | Confirmed |
| The LED is not driven by bus traffic | GPIO4 sampled during 400 SPI transfers; the value never moved | Confirmed by measurement |
| Power-up rail is 1.8 V | Vendor hardware and vendor software both start there | Confirmed |
| **CS/CLK/MOSI/MISO swing to the selected rail** | Inferred from the wiring and from the vendor presenting one control labelled "target voltage" | **UNVERIFIED — see test-procedure.md** |
| No ADC on the target rail | No such call exists in the vendor DLL, and no sense point is visible on the board | Confirmed by absence |
| No current sensing, no current limit, no load switch | Same | Confirmed by absence |
| No backfeed detection | Same | Confirmed by absence |

## The unverified row is the important one

The software currently reports the signal level as *assumed*:

```
Signal (CS/CLK/MOSI):      1.8 V (assumed to follow the rail, not measured)
```

and `electricalpreflight.TProgrammerElectricalCapabilities.SignalVoltageVerified`
is `False` for this board. Authenticated production refuses to run on that
basis; bench work proceeds with the caveat printed.

If the board switches VCC to 1.8 V but keeps driving 3.3 V logic, every other
electrical check still passes and 1.8 V parts still die. Running the procedure
in `test-procedure.md` is what turns this row from an inference into a fact,
and lets `SignalVoltageVerified` become `True`.

## GPIO map

```
GPIO6  $40   target VCC select    low = 3.3 V, high = 1.8 V
GPIO4  $10   activity LED         low = lit (active low)
```

Both are written with a one-bit mask, so switching the rail cannot disturb the
LED and vice versa. `software/ch347hw.pas` keeps them in separate calls for
exactly that reason; do not merge them into one masked write.

`DevOpen` deliberately does not touch GPIO at all. These pins are shared with
other CH347 functions, and claiming them as outputs before anyone has asked
for a voltage change broke I²C EEPROM detection. Safety does not depend on
that write: the hardware powers up at 1.8 V.

## ZIF socket mapping

Not yet documented. The board carries a 300-mil ZIF and the usual jumper block
for 8-pin SOIC/DIP orientation. Somebody should trace it and add the table
here; until then the sensible reference is the silkscreen and the pin-1 marker.

Related: the software has no way to know which way round a part is seated, so
a wrong orientation shows up only as "no chip answered" (`--detect` exit code
5). That is one of the reasons pin-1 marking is on the hardware wishlist.
