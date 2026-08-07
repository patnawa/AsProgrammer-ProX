# Bench procedure: does the signal level follow the target rail?

This is the measurement that turns the one unverified row in `pinout.md` into
a fact. It takes about fifteen minutes and needs a scope or a decent meter.

## Why it is worth doing

The software can already refuse to write a 1.8 V part while the rail is at
3.3 V. What it cannot do is notice a board that switches VCC to 1.8 V while
its logic keeps swinging to 3.3 V — because from software, that board looks
completely correct. Every field of the electrical record is right except the
one nobody has measured.

A 1.8 V flash part with 3.3 V on CS, CLK and MOSI is being driven roughly
1.5 V above its absolute-maximum input rating on three pins at once. It may
work. It may work for months. It is not something to find out about from a
customer's board.

So the program currently says "assumed" instead of claiming a number, and
authenticated production refuses to run at all. This procedure is how that
changes.

## What you need

- The CH347Ⅱ V2.13 programmer, connected over USB.
- An oscilloscope (10× probe) or a multimeter with a peak-hold / max function.
  A plain averaging meter will read a fraction of the true swing on a clocking
  line and is not good enough for CLK or MOSI.
- No chip in the socket for steps 1–3. A chip loads the rail and muddies the
  reading, and if the answer is bad you do not want a part in there.

## Procedure

**1 — Establish the reference at 3.3 V.**

Set Options → SPI → CH347 target voltage → 3.3 V. Measure VCC at the socket
against GND. Record it.

**2 — Measure the idle levels at 3.3 V.**

With the bus idle, measure the DC level on CS, CLK, MOSI and MISO at the
socket. CS idles high; CLK and MOSI idle at whatever the driver parks them at.
Record all four.

**3 — Measure the swing at 3.3 V.**

Start a read (`--detect` is enough) and capture the peak-to-peak swing on CLK
and MOSI, and the high level on CS. Record them. These are your reference
numbers: whatever the board does at 3.3 V, it does correctly.

**4 — Switch to 1.8 V and repeat steps 1–3.**

Set the rail to 1.8 V. Measure VCC — it should now read near 1.8 V, confirming
the GPIO6 claim. Then repeat the idle and swing measurements on all four
signal pins.

**5 — Compare.**

| Result | What it means | What to do |
|---|---|---|
| All four signals now swing to ~1.8 V | The board level-shifts with the rail, as assumed | Record both rails in `signalchar.pas` (step 6). The program starts saying "1.8 V" instead of "assumed", and production admission stops refusing |
| VCC moved but the signals still swing to ~3.3 V | The board switches supply only | **Do not program 1.8 V parts on this board without an external level shifter.** Record it anyway — a record saying `RailMv: 1800; SignalMv: 3300` is what makes the preflight refuse every 1.8 V part on absolute maximum instead of clocking them |
| Some signals shift and others do not | Partial level shifting — the worst case, because it looks fine at a glance | Record the **highest** of the four as `SignalMv`, and say which pin it was in `Method`. The field is defined as the worst level for exactly this case |
| VCC did not move | GPIO6 is not doing what `pinout.md` says on this board revision | Stop and re-establish the GPIO map before trusting anything else in this file |

Note that only the first row is good news, and all four rows are worth
recording. The second and third are the results the software cannot reach any
other way, and leaving them unrecorded keeps the program guessing in exactly
the direction that destroys parts.

**6 — Record the result.**

One place, in `software/signalchar.pas`, inside `BuildTable`. Add one call per
rail measured:

```pascal
Append(Result, 'CH347', 1800, 1810,
       'peak on CLK at the socket, 10x probe, during --detect',
       '2026-08-14', 'test-procedure.md rev 1');
Append(Result, 'CH347', 3300, 3310,
       'peak on CLK at the socket, 10x probe, during --detect',
       '2026-08-14', 'test-procedure.md rev 1');
```

`SignalMv` is the **highest** level seen on CS, CLK or MOSI at that rail, not
a typical or average one: the number exists to be compared against a chip's
absolute maximum, and an average hides the excursion that does the damage.

Each rail is a separate record. Measuring 3.3 V says nothing about 1.8 V —
different regulator state, and the unmeasured one is the dangerous one — so a
single record verifies a single rail and the program keeps saying "assumed"
about the other.

Then delete the `the compiled-in table is empty` assertion in
`tests/signalchar_tests.lpr`, in the same commit. It exists so that a claim
about real hardware cannot appear as a side effect of an unrelated change.

Nothing else needs editing. `ch347hw.pas` and `ft232hhw.pas` already ask
`signalchar` rather than asserting an answer, so the rail report, the
electrical preflight, the CLI's `signal_mv`/`signal_measured` fields and the
session report all start carrying the measured number at once.

Finally, put the actual numbers in `pinout.md`, replacing the unverified row,
and note the board revision and date in `revisions.md`. A measurement without a
board revision beside it is not reusable by the next person.

## Also worth checking while you are there

These are on the improvement list and the same session can settle them:

- **I²C pull-ups at 1.8 V.** Measure SDA and SCL idle high with an I²C part
  seated. Pull-ups sized for 3.3 V give a slow rise at 1.8 V, which shows up
  as intermittent detection rather than as an obvious failure.
- **Series resistance on the SPI lines.** Probe for 22–47 Ω in series with
  CLK and MOSI. If there is none, ringing on clip leads is the likely cause
  of the FF reads at high clock, and `Auto tune clock` will be settling for a
  slower rung than the board could otherwise carry.
- **Current draw.** Measure the rail current with a known part idle and during
  a read. This is the number the software would report as `target_current_ua`
  if the hardware could measure it, and knowing the real figure sets the
  threshold for any future current-limit design.

## What the software does with the answer

One flag, in one function:

```pascal
// software/ch347hw.pas, TCH347Hardware.GetElectricalCapabilities
Capabilities.SignalVoltageVerified := False;   // <- this
Capabilities.FixedVioMv := FTargetVoltageMv;   // <- and the level it claims
```

Setting the flag to `True` stops the "assumed" caveat appearing in the rail
report and lets authenticated production run. Nothing else in the program
changes. That is deliberate: the measurement is the only thing standing
between an inference and a fact, so it is the only thing that should be
required to change.
