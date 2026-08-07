# Assembly

There is nothing to assemble. The programmer is a commercial CH347Ⅱ V2.13
board, bought built.

This file exists so that the absence is recorded rather than looking like an
oversight — and because the improvements below are the ones that would need an
assembly step if anyone acts on them.

## Setup, such as it is

1. Install the WCH CH34xPAR driver. It is not in this repository; see
   [`../vendor-manifest.json`](../vendor-manifest.json) for what the package is
   and its SHA-256.
2. Plug the board in. The program's hardware menu should show CH347 as present.
3. Confirm the rail before seating anything: Options → SPI → CH347 target
   voltage. The board powers up at 1.8 V, which is the level that damages
   nothing.
4. Seat the part, watching pin 1. The software cannot detect a reversed part;
   it looks exactly like "no chip answered".

## Modifications worth making

These are recorded because they change what the software can promise, not as
general advice.

**A cover for the solder side.** The underside contacts the bench directly.
This is the cheapest of these by a wide margin and removes a whole class of
accident.

**Strain relief at the USB-A plug.** The board and its ZIF socket hang off the
plug. A knock during a write is a mid-operation disconnect — the software has
a distinct exit code for it (4), but no amount of software makes a half-written
chip whole.

**A keyed external header.** A clip harness can currently be seated reversed,
and the software cannot tell that from an unseated part.

**A larger pin-1 marker**, with the 24/25/93-series orientations printed beside
the socket. Same failure mode, same lack of software visibility.

**22–47 Ω in series with CLK and MOSI**, if the board does not already have
them. Ringing on clip leads is the most likely cause of the FF reads at high
clock that `Auto tune clock` works around; damping them would let the tuner
settle on a faster rung. Check for existing resistors first — see
[`test-procedure.md`](test-procedure.md).

**Test points for VCC, GND, CS, CLK, MOSI, MISO.** Needed to run
`test-procedure.md` comfortably at all; currently the measurement is taken at
the socket, which is awkward with a part seated.

**Separate LEDs for USB power, target power, bus activity and fault.** The
board has one, and the software drives it for bus activity only.

## What would need a new board, not a modification

The software already models all of these, reports them as "not measurable on
this programmer", and would start reporting real numbers the moment a backend
could supply them — see `TElectricalObservation` in
`software/electricalpreflight.pas`:

- **An ADC on the target rail**, so `measured_mv` stops being `null`.
- **A sense resistor**, so `target_current_ua` stops being `null`.
- **A load switch that trips on overcurrent**, so preflight can require a
  hardware current limit for destructive work rather than merely noting its
  absence.
- **Backfeed detection**, so `external_power_detected` can be `false` rather
  than `null` — the difference between "no external voltage is present" and
  "this programmer cannot see external voltage", which matters most when
  flashing on a powered motherboard.

None of these need software changes beyond filling in the observation record.
The policy that consumes them is already written and already tested.
