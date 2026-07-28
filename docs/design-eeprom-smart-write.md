# Design: differential Smart Write for the EEPROM families

Status: IMPLEMENTED in 4.6.0.0. Shipped as `eepromengine.pas` (planner and
executor), `eepromadapters.pas` (the I2C/95xx/93xx hardware adapters),
`tests/virtualeeprom.pas` + `tests/eepromengine_tests.lpr` (29 checks
including a full fault matrix and 400 randomized rounds), routed from
`MenuSmartWriteClick` and accepted by CLI `--smart` / `--smart --plan-only`.

Two decisions changed during implementation, both deliberately:

- The virtual chip **rejects** a page write that is unaligned or not exactly
  one page, instead of reproducing the 24Cxx page-buffer wrap. Modelling the
  corruption would let a planner bug produce a subtly wrong image that a
  test might miss; rejecting turns the same bug into an immediate failure.
- Verification covers **every page the requested range touches**, not only
  the pages that were written. Reading back unchanged pages is the only
  thing that detects a same-model chip swapped in after the snapshot.

The text below is the original design and remains accurate.

## Why

I²C 24Cxx, MicroWire 93xx, and SPI 95xx writes currently go through the
legacy chained path: write everything, optionally verify everything.
EEPROMs are byte-alterable — there is no erase, so the transactional NOR
machinery (norplanner's erase/preserve logic) is mostly unnecessary — but
the *shape* of Smart Write still pays off:

- write only the pages that differ (a 1-byte patch on a 24C256 becomes one
  page write, not 512);
- verify exactly the affected pages afterward;
- report through the same typed outcome channel (`operationmodel`) so the
  CLI JSON and evidence stay uniform.

## Shape

One new LCL-free unit, `eepromengine.pas`:

```
TEEPROMDevice = interface-ish record of function pointers (like TNORDevice):
  ReadPage(Addr, Len, out Data)      // whole-page read
  WritePage(Addr, const Data)        // page write incl. ack-poll/WaitReady
  Capabilities: PageSize, ChipSize, WriteCycleMs
```

Planner: compare snapshot vs desired page by page (page size from the
device record, which for I²C must be the *device* write-page, not the
256-byte bank). Plan steps: `epsWrite(page)`, `epsVerify(page)`. No erase
kind exists, which is the point.

Executor: for each write step — write, wait ready (ack-poll for I²C, DO
poll for 93xx, WIP for 95xx, all rejecting the $FF dead-bus value), then
verify step reads back and compares. Cancellation between steps only; a
page write is the critical section. Typed outcomes reuse
`TOperationErrorCode`.

Adapters: three thin records over the existing `i2c.pas`, `microwire.pas`,
`spi95.pas` primitives — those already carry the exact-transfer checks.
The snapshot pass reuses the existing full read + `ReadPassesAgree`
double-read when the user has read-verification enabled.

## Testing

A `virtualeeprom.pas` sibling of `virtualspi25.pas`: page buffer wrap
semantics (write past a page boundary wraps inside the page — the model
must reproduce the 24Cxx failure mode this project just fixed in
EraseFlashI2C), ack-poll timeouts, injected failures at every call index.
Property test: for random (snapshot, patch) pairs, executing the plan on
the virtual chip always produces desired = patch over snapshot, and the
number of page writes equals the number of differing pages.

## UI/CLI binding

`--smart` on a 24/93/95 chip routes here instead of erroring; the GUI
Smart Write menu item does the same. `--plan-only` prints page counts and
the write-cycle-derived worst-case time, mirroring the NOR preview.

## Order of work

1. `eepromengine.pas` + `virtualeeprom.pas` + suite (pure, Linux-testable)
2. I²C adapter + CLI binding (most-used family)
3. 95xx, then 93xx adapters
4. GUI menu routing
