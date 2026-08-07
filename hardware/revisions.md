# Board revisions

One entry per physical board that has been used with this software. A
measurement without a revision beside it cannot be reused by the next person,
because the next person may not have the same board.

## CH347Ⅱ V2.13

The board this project is developed against. Marking is silkscreened on the
top side.

| Property | Value | How established |
|---|---|---|
| USB interface | CH347T (or CH347F / CH339W; the software accepts all three) | `CH347GetChipType`, gated in `utilfunc.CH347GateAccepts` |
| Target rails | 1.8 V and 3.3 V, selected by GPIO6 | Vendor program, confirmed on hardware |
| Power-up rail | 1.8 V | Vendor hardware and vendor software |
| Activity LED | GPIO4, active low, software-driven | Measured: GPIO4 does not move on bus traffic |
| VCC measurement | none | No such call in the vendor DLL |
| Current sensing / limit | none | — |
| Backfeed detection | none | — |
| Signal level at 1.8 V | **not measured** | See `test-procedure.md` |
| Max SPI clock | 60 MHz at the DLL; clip leads do not reliably carry it | `Auto tune clock` exists because of this |
| Connector | USB-A plug, board-mounted, no strain relief | Observed |

### Known weak points

Recorded here because they change how the software should behave, not as a
shopping list:

- **No strain relief on the USB-A plug.** The board and its ZIF socket hang off
  the plug. A knock during a write is a mid-operation disconnect, which is why
  the CLI has a distinct exit code (4) for the programmer disappearing.
- **Exposed solder side.** The underside contacts a bench directly. Anything
  conductive under the board is a short across whatever it lands on.
- **Unkeyed external header.** A clip lead harness can be seated reversed.
  Software cannot detect this: a reversed harness looks identical to "no chip
  answered" (exit code 5).
- **Pin 1 marking is small.** Same failure mode, same lack of software
  visibility.
- **One LED for everything.** USB power, target power, bus activity and fault
  are not distinguishable at a glance. The software drives the single LED for
  bus activity only.

## Older DLL / no GPIO export

Not a board revision, but it presents as one and belongs in the same table.

Some CH347 DLL versions export no GPIO functions at all. On those, the rail
cannot be switched and stays wherever the hardware powers up — 1.8 V.

`TCH347Hardware.GetElectricalCapabilities` reports this as
`pcFixedTargetPower` at 1800 mV, rather than as "no target power". The board
really is supplying the chip; software just cannot change the level. Reporting
"no target power" would make preflight refuse every operation on a board that
is working correctly, which is the wrong kind of caution.
