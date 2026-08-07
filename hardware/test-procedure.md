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
| All four signals now swing to ~1.8 V | The board level-shifts with the rail, as assumed | Set `SignalVoltageVerified := True` in `TCH347Hardware.GetElectricalCapabilities` and record the measurements in `pinout.md` |
| VCC moved but the signals still swing to ~3.3 V | The board switches supply only | **Do not program 1.8 V parts on this board without an external level shifter.** Leave `SignalVoltageVerified` at `False`, and change `FixedVioMv` in `ch347hw.pas` to 3300 so preflight refuses 1.8 V parts outright |
| Some signals shift and others do not | Partial level shifting — the worst case, because it looks fine at a glance | Record which pins do what, and treat the highest as the effective signal level |
| VCC did not move | GPIO6 is not doing what `pinout.md` says on this board revision | Stop and re-establish the GPIO map before trusting anything else in this file |

**6 — Record the result.**

Put the actual numbers in `pinout.md`, replacing the unverified row, and note
the board revision and date in `revisions.md`. A measurement without a board
revision beside it is not reusable by the next person.

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
