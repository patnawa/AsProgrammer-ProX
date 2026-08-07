# Cross-platform hardware and headless CLI

Status: headless CH347 path implemented and compile-checked on Windows/Linux;
live Linux validation remains required before its destructive gate can be
removed. The Windows GUI remains the primary interactive application.

## Delivered seams

- All Windows hardware libraries (`CH341DLL.DLL`, `CH347DLL.DLL`, D2XX,
  libusb0, and Buzzpirat helpers) bind dynamically. A missing library disables
  one backend instead of preventing process startup.
- `ch347proto.pas` owns the pure, byte-exact CH347 bulk packet layout. It is
  tested on both toolchains.
- `ch347usb.pas` implements `TBaseHardware` through dynamically loaded
  libusb 1.0. Missing libusb or hardware returns a typed absence/error.
- `operationrunner.pas` is the presentation-neutral interface used by the
  LCL-free CLI and runner tests for trusted reads, Smart Write preview, and
  Smart Write execution. It owns stable snapshots, planning, events,
  cancellation, and typed outcomes. The GUI uses the same lower-level
  planners and engines directly; it does not route through this runner.
- `AsProgrammerCLI.lpr` plus `headlesscli.pas` provides a real LCL-free entry
  point. It no longer imports `Forms` or delegates to GUI event handlers.
- `prodcrypto.pas` uses Windows CNG or the system OpenSSL `libcrypto`;
  `prodevidence.pas` and `prodstate.pas` have durable native Windows/POSIX
  implementations. The production suites run on both platforms.

## Current headless surface

The CLI supports CH347/libusb stable detection and reads, offline image scan,
offline SFDP decode, Smart Write preview, and Smart Write execution. Execution
is deliberately gated while live validation is pending: it requires `--yes`,
an atomic backup destination, and the exact sacrificial-chip environment token
printed by `--help`.

Linux needs FPC to build and the system libusb 1.0 runtime to run. Windows
release ZIPs contain `AsProgrammerCLI.exe` and an exact hash-verified official
x86 `libusb-1.0.dll`.

```bash
fpc -Mobjfpc -Sh -Fusoftware software/AsProgrammerCLI.lpr
./software/AsProgrammerCLI --detect
./software/AsProgrammerCLI --read dump.bin --size 8388608 --passes 2
```

`tools/build.sh` compiles the actual entrypoint and dependency graph on every
ordinary CI run but does not open hardware. `tools/hil.sh` separately compiles
and runs both the non-mutating `ch347smoke` program and headless CLI detect on a
labeled physical Linux runner.

## Live validation gate

The minimum evidence for graduating CH347/libusb destructive support is:

1. repeated stable JEDEC ID and status reads across process reopen;
2. two matching complete reads at conservative and faster clocks;
3. Smart Write preview with no mutating opcode in a USB trace;
4. a full destructive cycle on a socketed sacrificial chip, including trusted
   backup, required erase and no-erase plans, shuffled full verification,
   process restart, restore, and restore verification;
5. cancellation/fault injection at open, init, read, erase, program, verify,
   mode cleanup, close, backup commit, and evidence commit boundaries; and
6. recorded programmer revision, firmware, USB driver/library version, chip
   lot, adapter, and measured rail voltage.

Until that record exists, compile success must be described as compile
coverage—not silicon validation—and the destructive environment gate stays.
See [hardware-in-loop.md](hardware-in-loop.md).

### What lifts the gate

The six items above are the contents of `CH347_CHECKLIST` in
`software/validationgate.pas`. `headlesscli.pas` reads them, so a refused
`--smart-write` names the outstanding items and the document they come from
instead of saying "await live validation", and `--help` prints the state of
every gate.

The environment token is not a second way through. It is how the validation
run itself is performed: somebody has to issue destructive commands on a
sacrificial part before any evidence can exist. A run that uses the token
while the capability is gated prints a warning saying it is a validation
attempt, not a validated operation.

Releasing the capability is a transcription of a hardware-in-loop run into one
`Append(Result, gcCH347LibusbWrite, ...)` call in `BuildTable`, with a bit per
numbered item. Partial coverage keeps the gate shut and names what is missing.

If an item is added to or removed from the list above, change
`CH347_CHECKLIST` in the same commit; the suite asserts the count.

## Next backends

The next cross-platform work should reuse the same `TBaseHardware` capability
contract and `operationrunner` boundary:

1. validate and graduate CH347/libusb;
2. implement UsbAsp/AVRISP through libusb 1.0 with typed capability records;
3. add Linux production packaging only after runtime/udev/install behavior is
   documented and tested; and
4. consider a GTK/Qt GUI last, without coupling operation policy back into LCL.

No backend is allowed to claim a voltage, open-drain capability, protocol, or
clock it cannot establish. Unknown remains an admission failure for
destructive production work.
