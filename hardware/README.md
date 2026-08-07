# hardware/

What the software believes about the board it is driving, and how those
beliefs were established.

The programmer this project targets is a commercial CH347Ⅱ V2.13 board, not
something designed here, so most of this directory is reverse engineering
rather than design output. That is exactly why it needs writing down: the
software makes refusal decisions — "do not write this 1.8 V part" — on the
basis of claims about hardware behaviour, and a claim nobody recorded is a
claim nobody can check.

## Contents

| File | What it is |
|---|---|
| [`pinout.md`](pinout.md) | The GPIO map and the rail/signal claims, each tagged with how it was established and how confident that makes it |
| [`test-procedure.md`](test-procedure.md) | The bench measurement that settles the one claim still marked unverified: whether CS/CLK/MOSI follow the target rail |
| [`revisions.md`](revisions.md) | Board revisions seen, and what changed between them |
| [`bom.csv`](bom.csv) | Parts, for the portions of the board that have been traced |

`schematic/`, `pcb/` and `gerbers/` do not exist yet, and creating empty
directories for them would only make the tree look more finished than it is.
They belong here when there is something to put in them — either a traced
schematic of the voltage-switching and level-shifting sections, or a design of
our own.

## The one thing to read first

`pinout.md` has a table of claims with a confidence column. One row says
**UNVERIFIED**, and it is the row that matters:

> CS/CLK/MOSI/MISO swing to the selected rail — inferred from the wiring and
> from the vendor presenting one control labelled "target voltage"

A board that switches VCC to 1.8 V while its logic keeps driving 3.3 V passes
every electrical check the software can perform, and destroys 1.8 V parts. The
program therefore reports the signal level as *assumed* rather than claiming a
figure, and authenticated production refuses to run on an assumption.

`test-procedure.md` is fifteen minutes with a scope that turns that row into a
fact, in either direction. Both answers are useful; only the absence of an
answer is not.

## What software depends on what is written here

| Claim here | Where the software acts on it |
|---|---|
| GPIO6 selects the rail, high = 1.8 V | `software/utilfunc.pas`, `CH347_GPIO_VCC` |
| GPIO4 is the LED, active low | `software/ch347hw.pas`, `ApplyLedGPIO` |
| Power-up rail is 1.8 V | `software/ch347hw.pas`, and the fail-safe default throughout |
| No ADC, no current sense, no backfeed detection | `TCH347Hardware.GetElectricalCapabilities` reports all four as `False`, which is why the rail report says "not measurable on this programmer" |
| Signal level follows the rail — *unverified* | `SignalVoltageVerified := False`, which produces the "assumed" caveat and blocks authenticated production |

Change a claim here without changing the code, or the reverse, and the program
will be confidently wrong about a rail. Keep them in step.
