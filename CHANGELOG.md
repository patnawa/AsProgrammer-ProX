# Changelog

All notable changes to AsProgrammer ProX are recorded here. The version in the
first entry must match `software/appver.pas`; CI enforces that invariant.

## 4.24.0.0 — safer workflows, gated NAND writes, and a real headless CLI

- The GUI can preview Smart Write as an operator-facing plan before
  confirmation, and destructive workflows persist trusted backups across the
  supported writable families.
- A presentation-neutral operation runner now owns stable reads, planning,
  execution, events, cancellation, and typed outcomes for the new LCL-free
  `AsProgrammerCLI` and its tests. The GUI continues to consume the shared
  planners and engines directly, including its operator-facing preview.
- CH347/libusb has a headless Windows/Linux entrypoint. Linux CI compiles its
  real dependency graph; dedicated benches run its read-only live path.
- SPI NAND Phase 3 adds CRC-checked redundant ONFI parameter pages and gated
  CLI erase/write paths. Mutation requires a known catalog part, a verified
  vendor access sequence whose geometry agrees with ONFI, an explicit station
  gate and `--force`, plus a new atomic two-pass recovery backup. Factory
  markers are checked on the first two pages; erase blank-checks every page and
  writes require full physical-page read-back. Mutation remains disabled by
  default pending sacrificial-chip validation, and there is no GUI NAND path.
- Release inputs are fail-closed: Lazarus, upstream runtime archives, and every
  packaged DLL are SHA-256 pinned. Build jobs are read-only, publishing is an
  isolated tag-only job, and the Windows candidate is built only once.
- Weekly self-hosted HIL checks cover CH341, CH347, EZP2023+, and the CH347
  Linux backend without mutation. Destructive fixture cycles require a
  protected environment, an exact station token, a hash-pinned full-chip
  image, a two-pass backup, and a verified restore.
- The task-oriented README, testing/release/HIL guides, contribution and
  security policies, suite-catalog drift check, and translation coverage
  report replace the oversized embedded release history.

## 4.23.2.0 — a full-codebase bug hunt

A systematic audit of the flash engines, the operation lifecycle, the EZP
backend, the CLI and the support units, with every finding verified against
the code before it was fixed.

Safety and correctness:

- The EZP2023+ whole-chip write/erase path now passes the same supply-voltage
  gate as every other destructive path, and the automatic family profile no
  longer overwrites the catalogue voltage with a hardcoded 2.7–3.6 V — a
  1.8 V family (EF60xx) detected at startup kept its warning suppressed while
  the EZP drives a 3.3 V rail.
- WPS (individual block locks) was decoded from a reserved bit of SR2, where
  it always reads 0; it lives in SR3 bit 2 (opcode 15h). The block-lock scan
  and the 98h global unlock existed but could never trigger. SR3 is now read
  for the Winbond family and the whole path works; the scan also switches to
  4-byte addressing on >16 MB chips instead of sending misframed commands.
- `BP=7` with `SEC=1` reported 256 KB locked instead of the whole chip, so
  the write guard let doomed writes through on fully-protected parts.
- The SFDP 4-byte-entry mapping preferred "dedicated instruction set" over an
  actually-declared switch method, so range erase on a W25Q256JV-class chip
  failed before touching the flash; and the B1h nonvolatile-config entry
  wrote fixed bytes over the whole register — on Micron parts that
  permanently enables quad protocol (the chip stops answering plain SPI
  after the next power cycle). B1h entry is removed entirely; chips that
  really are 4-byte-only now fail closed with an explanation.
- The transactional writer's cleanup sent a bare E9h after WRDI; N25Q256A-
  class chips (the WREN+B7 strategy) ignore it and stay in 4-byte mode for
  the next tool. Cleanup now re-arms WEL before E9h.
- A HEX/S-record file containing no data records (empty, truncated, or a
  binary misnamed .hex) loaded "successfully" as an all-FF image — which the
  write path would then erase a chip to match. Both parsers now refuse.
- A pasted non-hex start address raised an exception that escaped the
  operation frame: the run ended with no failure recorded, a "write: OK"
  summary, and a PASS row in the production log for a chip that was never
  written. The address field now sanitizes itself on every change.
- Erase status polling on the EZP2023+ accounts for every re-sent 000A poll
  and drains the extra replies; an aborted erase terminates the firmware
  session (0108) instead of leaving stale status packets to phase-shift the
  next session. The stream-block guard also refuses geometry that would
  overrun the image buffer.

Lifecycle and UI:

- Chip Doctor, True capacity test and Surface scan now lock the window like
  every other operation; seven always-enabled menu entries gained re-entrancy
  guards, so a click during a long job can no longer start a second
  interleaved operation on the same device (which ended with DevClose under
  a running write). Benchmark survives an exception without permanently
  wedging every button and the close box.
- Closing the window no longer latches a cancellation that aborts the *next*
  operation when the close was vetoed; Read ID closes the device on its
  early exits; replace-all in the hex search no longer skips adjacent
  matches, and invalid hex patterns are rejected instead of searching
  uninitialized memory.
- Chip-list numeric attributes are parsed defensively (a typo in
  chiplist-user.xml crashed chip selection; in CLI mode with runtime error
  217 instead of an exit code), XML comment nodes no longer appear as
  selectable "#comment" chips, and a failed selection no longer half-renames
  the previously selected chip.
- CLI: `--detect --save-chip` actually saves now (it exited before the save
  block), a successful save exits 0 instead of printing usage and exiting 2,
  a failed save exits 1, `--write a.bin --verify b.bin` is rejected instead
  of silently verifying against the wrong file, and multi-match detection no
  longer pops a chooser window in headless mode.
- CRC32 no longer reads up to 3 bytes past the end of the buffer, USB string
  descriptors from misbehaving devices can no longer write through an
  uninitialized index, and vendor-name device matching compares against the
  requested name instead of an RTL function that always returns ''.
- tools\build.ps1 now compiles ezpsmoke, ezpwrite and ezppowercheck so a
  refactor in software\ cannot break the bench diagnostics unnoticed, and
  ezpsmoke no longer reads a reply after RESET (one-way command) into the
  buffer it then makes decisions from.

## 4.23.1.0 — 50 ms that make erase and write real

Root cause of every "erase reports complete but the chip is untouched" and
"the programmer accepted the whole image and discarded it" failure: after
answering the `0007` chip descriptor, the CH552 firmware spends several
milliseconds configuring its erase/program algorithm, and any modification
command (`0102` erase, `0005` write) that arrives inside that window is
accepted at the USB layer and silently dropped — the erase status poll then
answers "complete" after one poll, and no error is ever raised.
Identification and reads are immune, which made the failure masquerade as
chip protection.

Proven by byte-level differential capture against the vendor software using
the ezpspy shim: with packet streams identical to the byte, our
back-to-back command timing failed while the vendor's GUI — which pauses
for milliseconds between calls simply by being a GUI — succeeded. Pausing
30 ms at exactly one point, between the descriptor reply and the erase
command, made the same probe erase run its real 34 busy polls. This also
explains why `tools\ezpwrite` always validated: its console prints between
steps were accidental arming delays. The backend now waits a deliberate
50 ms after every descriptor reply and after the write-start command,
documented as `EZP_ARM_DELAY_MS`.

The write/verify path also now mirrors the vendor's session discipline
exactly: sessions end with the `0108` firmware reset, close, reopen,
identify, close, reopen — and never a USB port reset (a 7.5-hour vendor
capture with 25 device opens contains not a single `usb_reset`).
Independent verification read-backs use those session boundaries instead of
USB resets — measured to return fresh, correct data seven consecutive
sessions in one process — which also removes four ~2.5 s re-enumeration
waits from every verified write. `usb_reset` remains only as last-resort
recovery for a device that has stopped answering, and write-session
commands fail closed rather than auto-recovering mid-operation. The ezpspy
shim now also logs `usb_get_descriptor`/`usb_get_string` calls it
previously forwarded invisibly, so future captures cannot hide EP0
traffic.

## 4.23.0.0 — native EZP erase and professional live telemetry

EZP2023+ Erase now uses the firmware's real `0102` start command and `000A`
busy/completion polling protocol. Writing an all-`FF` image was not an erase:
the firmware skips blank pages, so old zero bits survived and verification
failed at address zero. Native erase is followed by two independent full-chip
read-backs, each separated by a real USB reset; the operation succeeds only
when both reads agree and every byte is `FF`.

Write now follows the vendor manual's actual three-step workflow: Erase, Write,
Verify. A controlled EF4017 probe proved that the `0005` data stream programs
`FF` to `FE` but cannot restore `FE` to `FF`; it does not erase automatically.
AsProgrammer therefore refuses to send any image page until native erase has
passed both complete blank read-backs. After programming, the same two-pass
connection-stability gate compares every byte with the image.

Verification now performs a real USB device reset, waits for re-enumeration,
then re-primes the firmware with a complete `0009` identification transaction
before every read-back. A close/reopen pair was not enough to flush stale
libusb-win32 endpoint data, while a second reset/read without re-priming
returned `FF FF FF FF`. If the firmware accepts every page or reports erase
complete but the reset read-back still contains old data, the result identifies
likely status-register/WP# protection, supply-voltage trouble, or in-circuit
bus contention, with isolation guidance, instead of reporting a generic
mismatch or false success.

The main window now keeps four engineering cards visible for connection and
transport, interface and requested clock, chip profile, and the last measured
operation. EZP reports `USB 1FC8:310B`, libusb-win32 `1.4.0.2`, and `12 MHz
requested (firmware setting)` without pretending it measured the physical SCK
waveform. Completed operations retain byte count, elapsed time, and effective
throughput, including verification time.

Startup detection now reads the live JEDEC ID and automatically loads a safe
compatible family profile when several exact suffixes share one ID. The UI
states that the suffix remains ambiguous instead of claiming false precision.
For the connected `EF4017` family it exposes the confirmed 8 MiB capacity,
256-byte page, 4 KiB/`20h` sector geometry, three-byte addressing, and the
manufacturer-specified 2.7–3.6 V range.

## 4.22.0.2 — release driver bundle stays byte-exact

Git attributes now prevent Windows checkout from changing line endings inside
the checksum-pinned EZP driver bundle. Release assembly validates all 24
vendor/upstream payload hashes after copying and fails before publishing if
even a licence or documentation byte differs.

## 4.22.0.1 — EZP2023+ is detected safely at startup

Automatic programmer detection now finds an attached EZP2023+ even when the
saved/default backend is a serial programmer. Detection only enumerates the
USB descriptor for `1FC8:310B`: it does not open or claim the programmer,
reset it, or send a chip command. The same non-invasive check tracks EZP
disconnect/reconnect events without bringing back the old three-second window
freeze or disturbing a whole-chip transfer.

## 4.22.0.0 — EZP2023+ write fixed and verified on the real programmer

Whole-chip Write and Erase are enabled again. The missing protocol state was
not another packet in the captured write itself: the vendor program performs
two complete CHECK_CHIP sessions first, closes both, and opens a third session
for descriptor, START and data. The descriptor reply must be `01` plus the
selected JEDEC id. AsProgrammer now reproduces that state machine and refuses
to send any image data if either priming pass or the descriptor reply disagrees.

The USB transport is hardened as well. RESET is one-way rather than a command
with a reply, negative read interruptions are retried without shifting the
stream, and a stuck CH552 gets up to three full reset/reopen cycles before the
user is asked to power-cycle it. The bundled 32-bit `libusb0.dll` is the signed
1.4.0.2 release; it includes upstream large-transfer, ordering, hang and bulk
ZLP fixes absent from 1.2.6.0.

The repository also carries a self-contained Windows driver bundle under
`drivers\EZP2023Plus`: the signed EZP-specific device package, the unmodified
signed libusb-win32 1.4.0.2 AMD64/x86/ARM64 runtime, upstream licences and
SHA-256 checksums. The elevated updater consumes these project-local files and
supports both a first installation and an idempotent upgrade.

Validated on the connected EZP2023+ (`1FC8:310B`, identity `90381CBC`) and a
W25Q64-class 8 MiB chip (`EF 40 17`): a backup was read twice, written back
through the isolated writer, then read twice with exactly the same SHA-256.
The integrated application follows every write with its own fresh-session,
full-chip byte comparison. Smart write, SFDP and health tests remain disabled
for EZP because its firmware cannot issue arbitrary SPI commands.

## 4.21.1.0 — EZP2023+ writing is disabled: it corrupts chips

4.21.0.0 shipped a whole-chip write for that programmer on the strength of
the protocol documentation. Tested against real hardware it destroys data,
so it is now refused outright.

What happens: the firmware accepts all 8 MB without reporting anything
wrong, and the chip then reads back as neither the old image nor the new
one. So the sequence being used — descriptor, START, data blocks to the
second OUT endpoint, RESET — is still missing something. Notably the
reference implementation does not verify its write path either, and the
erase commands it defines (`0102h`, `0Ah`) are never called by it.

Two real bugs were fixed on the way and are worth keeping: data blocks
were being sent with the one-second command timeout, though the firmware
erases the whole chip after START and ignores the bus for tens of seconds
first; and the automatic USB-reset recovery could fire *during* a data
stream, which knocks the firmware out of its receiving state so every
later block lands in the wrong place. Recovery is now forbidden mid-stream
on principle — resetting a device that is halfway through writing a chip
can only make things worse.

Reading remains verified: a full 8 MB dump of a W25Q64JV, twice.

## 4.21.0.0 — the EZP2023+ writes and erases too (withdrawn in 4.21.1.0)

Verified on real hardware: a W25Q64JV read back all 8 MB through the
programmer, Intel descriptor and all.

The firmware cannot accept a page-at-a-time write, but it writes a whole
chip perfectly well, so the ordinary Write and Erase buttons now route to
that when the EZP2023+ is selected — no separate menu to learn. Because
the same programmer can also read, every write is followed by a full
read-back and a byte-for-byte compare, which is a stronger check than the
page-level verify the other backends do. Erase is a whole-chip write of
FF, which is the only erase this firmware offers and lands in the same
verified state. A buffer shorter than the chip is allowed and says so
first: the remainder becomes FF, because a whole-chip write cannot leave
it alone. A write interrupted midway reports exactly how far it got and
that the chip now holds part of each image.

The bug behind "read: FAILED, received -1 of 2048 bytes": each operation
opens its own session, so the chip id captured when you pressed Read ID
was gone by the time the read described the chip to the firmware, and a
descriptor carrying id zero is silently refused. The id is now fetched
whenever the descriptor is built. The backend's own explanation also
reaches the log now instead of being replaced by the caller's generic
"short read" line.

## 4.20.2.0 — the EZP2023+ un-wedges itself

Measured against real hardware with a new standalone diagnostic
(`tools/ezpsmoke.lpr`, read-only), which is what finally separated "our
code is wrong" from "the board is not answering". The device enumerated
perfectly — bound to libusb0, `Status: OK`, endpoints exactly `0x82` in
and `0x02`/`0x01` out, all bulk — and still refused every 64-byte command
packet with a timeout, in this program *and* in the vendor's own software.
`set_configuration` did not help, nor did `clear_halt`; `usb_reset`
followed by reopening did, every time. A stuck CH552 is now recovered
automatically on the first refused command instead of being reported as a
dead programmer, and the log says when that happened.

The other fix that diagnostic found: the four-byte identity code at the
end of the CHECK_CHIP reply is per-device, not a model constant. The
reference implementation's `9A7336BD` and the `90381CBC` on the unit here
are both valid, so requiring one of them rejected a perfectly good
programmer. The code is now logged for reference and only an all-zero or
all-FF answer counts as "nothing there".

## 4.20.1.0 — the EZP2023+ no longer freezes the window

Three faults in yesterday's backend, all of them mine. The programmer
poller reopens the selected device every three seconds, and opening the
EZP2023+ also talked to the chip — so the window stalled on USB traffic
on a loop; opening now touches the USB device only, and the identity
check and chip id happen when something actually asks. Every reply was
waited for with the twenty-second timeout meant for whole-chip data
blocks, turning one unanswered 64-byte packet into a twenty-second
freeze; command replies now use one second. And `usb_set_configuration`
on an already-configured libusb0 device can hang outright, so it is gone
and a failed interface claim is no longer treated as fatal — neither is
something the working reference implementation does. Auto-detect no
longer probes the EZP either: opening somebody else's programmer every
three seconds while it may be mid-stream is not worth the convenience.

Also fixed: after refusing an opcode the firmware cannot send (`90h`,
`ABh`, `15h`), a following read was served the `9Fh` id as though it were
that command's answer. A read with nothing pending now says so instead of
fabricating a reply.

## 4.20.0.0 — the EZP2023+ can identify and read

Reverse engineering that programmer (Spring 1FC8:310B, a CH552G board on
libusb0 — the same driver stack this program already binds for UsbAsp)
turned up a protocol unlike every other backend's: it exposes no raw SPI
at all. You hand the firmware a 64-byte descriptor — chip class, algorithm
index, page size, delay, capacity, expected JEDEC id, clock, voltage — and
it performs the entire read or write by itself, streaming 64-byte blocks.

So the new backend implements exactly what that allows and says so about
the rest: `9Fh` is answered from the programmer's own chip detection, `03h`
reads are served from a whole-chip image pulled once per session (so the
chip is read once however the caller chunks it), and every other opcode is
refused with a message naming the reason. Read ID, Read, dump inspection,
compare and verify-against-a-file work. Write, erase, SFDP, Smart write
and the chip health tests do not, and cannot until someone teaches this
program a whole-image write path worth trusting.

## 4.19.2.0 — "FT_Open device not found" now says which problem it is

The D2XX driver returns the same `FT_DEVICE_NOT_FOUND` whether no FTDI
board is attached or `ftd2xx.dll` is missing entirely — and this program's
own fail-closed stubs, which exist so a missing DLL cannot stop the exe
from starting, return it too. One message, three causes, and the operator
goes hunting for a cable when the real answer is a file. The FT232H
backend now checks whether the driver actually bound, and says either
*"ftd2xx.dll is not available — put it next to AsProgrammer.exe"* (the
release zip ships one; a freshly built exe has no DLLs beside it) or
*"the driver answered but found no FTDI device — check the cable, and that
the board is not claimed by the VCP driver instead of D2XX"*.

## 4.19.1.0 — 42 chips learn their real supply voltage

Reverse engineering the EZP2023+ ver 3.0 chip database named the record
fields the importer had listed as unknown, and turned up something worth
knowing: the voltage byte is the rail that programmer switches on, not the
chip's rating. Every SPI flash in the file reads 3.3 V — including every
part whose own name ends in `(1.8V)` — so trusting it would have labelled
every 1.8 V part as 3.3 V, which is the mistake that destroys one. 1.8 V
therefore still comes from the part name; the 5 V records, which match
their datasheets, gave 42 chips in `chiplist-ezp.xml` a real `vcc`.

The EZP2023+ itself remains unsupported as a programmer, and that is a
protocol limit rather than an oversight: its firmware exposes only
whole-chip read/write/erase, with no way to send an arbitrary SPI command,
so SFDP, protection decoding, Smart write and the chip health tests have
nothing to talk to.

## 4.19.0.0 — and the C5h bank-register chips too

4.18 refused chips that reach their upper banks through the extended
address register; now they are driven properly. The tests track the
current 16 MB bank, rewrite the C5h register whenever an operation
crosses into another bank — and read it back with C8h, because a bank
that did not stick means every following command lands 16 MB away from
where it was aimed — keep every frame 3-byte, clamp read chunks at bank
boundaries (a 3-byte read that runs off the edge wraps silently back
into the same bank), and always park the register at bank 0 on the way
out, since that is what every other tool assumes.

## 4.18.0.0 — the chip tests learn 4-byte addressing

The capacity test and the surface scan now drive chips beyond 16 MB —
W25Q256, MX25L256, GD25Q256 and friends up to 256 MB. The session enters
the chip's own 4-byte mode (B7h, WREN+B7h, the Spansion bank register or
Micron's B1h, per what the chip declares) and every erase, program and
read frame carries the full four-byte address; the mode is unwound in a
`finally` like everywhere else. Chips that reach their upper banks only
through the C5h extended address register are refused with a message
saying exactly that, rather than silently testing the wrong 16 MB.

## 4.17.0.0 — surface scan: badblocks for SPI NOR

Per block: erase and confirm blank, program 55h and confirm, AAh and
confirm, then a pattern where every dword holds its own address — the one
pattern a broken address line cannot survive — and erase again. Bad blocks
are mapped rather than aborting at the first one; the chip ends fully
erased and both UIs say so loudly before starting (`--surface-scan` needs
`--force`). First-round erase timings feed the wear detector.

## 4.16.0.0 — wear telemetry, and a verify that cannot be echoed

Erase jobs now keep the per-block durations the BUSY polls already
produced: blocks erasing five times slower than the median get a wear
warning naming the worst offender, because flash slows down before it
fails. NAND dumps report corrected-ECC counts per block — a cluster in one
block is a block dying, not noise. And the verify pass reads the array,
not the device's recent memory: a JEDEC 66h/99h reset precedes the final
compare, and chunks are checked in deterministically shuffled order, which
a device echoing recently transferred data cannot pass.

## 4.15.0.0 — the counterfeit test and the chip doctor

The commonest bad chip is remarked, not broken: a 4 MB die sold as a
W25Q128 that wraps every address above its real size and verifies every
write through the same wrap. The capacity test writes distinct markers at
every power-of-two boundary and looks where they landed — the first
address holding somebody else's marker is the real capacity. Every sector
the test can touch is backed up first, restored afterwards, byte-verified;
a chip that simply loses markers is reported as failing writes, not fake.
Chip menu or `--capacity-test --force`; a detected fake exits 1. The chip
doctor (`--chip-test`) is the non-destructive sibling: id stability, the
9F/90/AB/15 opcodes telling one story, WREN/WRDI as proof the chip
executes commands, SFDP-vs-selected size, and the same quarter megabyte
read at the fastest and slowest clock.

## 4.14.0.0 — serprog: every DIY programmer at once

A Raspberry Pi Pico running pico-serprog costs four dollars and speaks
flashrom's documented serial protocol; so do STM32, ESP32 and frser-duino
boards. One new backend supports them all: pick **serprog** under
*Programmator*, set its COM port once, done. serprog's SPI operations are
atomic (the firmware owns chip select), so the backend queues the command
phase and executes each transaction as one exchange — the protocol layers
never notice. SPI only, honestly: I2C, MicroWire and the KB9012 EC path
say so instead of misbehaving.

Releases are also published by CI now: pushing `v<version>` builds, runs
every suite, and attaches the zip those suites just ran against — after a
fast gate that the tag matches `PROX_VERSION`, so a tag on the wrong
commit cannot ship a mislabelled build.

## 4.13.0.0 — 119 more chips, from everyone's lists at once

Every open chip database checked against ours: latest flashrom (already
fully mined), upstream UsbAsp-flash (11 new), the community-consolidated
list from upstream issue 163 (51 new after filtering out what must not be
taken — AVR parts this program cannot drive, NAND entries the GUI cannot
drive *yet*, and page-variant duplicates the live AT45 detection obsoletes),
and IMSProg's database, which turned out to use the same 68-byte records as
the EZP files (57 parts nobody else had, shipped as `chiplist-imsprog.xml`,
GPL-3-or-later, deletable). 1751 chips total. The Find IC search dialog now
actually searches all five files instead of two.

The machinery is reusable: `tools/merge_chiplist.py` diffs any chip list
against the master, reports what is new, identical, or conflicting, and
`--write` inserts the new entries under the right vendor group without
disturbing the master's hand formatting — then validates the result.

## 4.12.0.0 — CH347 over libusb, awaiting silicon

Cross-platform step 3, first half: the CH347's reverse-engineered bulk
packet layout as a pure, byte-exact-tested unit; a libusb-1.0 transport
implementing the standard hardware contract; and a non-destructive smoke
harness (`tools/ch347smoke.lpr`). Compile-checked on every Linux CI run,
kept out of every UI until it passes on a real CH347.

## 4.11.0.0 — SPI NAND phase 2: it executes now

Phase 1 planned around bad blocks; this executes the plans. The engine
scans factory markers with ECC off (GD5F flags an erased page as an ECC
failure, which would make a fresh chip scan as all-bad), checks the chip's
ECC verdict after every dumped page and refuses uncorrectable ones by
block and page, unlocks before programming and believes only the read-back,
checks E_FAIL/P_FAIL after every erase and program, and reads every written
page straight back. The CLI gains `--nand-info` and `--nand-read` for
W25N512GV/01GV/02KV, GD5F1GQ4UA/UB, MX35LF1GE4AB and TC58CVG0S3. Erase and
write wait for live CH347 validation.

## 4.10.0.0 — Intel flash descriptor regions, named and usable

A dump holding an Intel flash descriptor now logs its region table — where
the BIOS starts, where the ME ends, and whether a region runs off the end
of the image (the signature of a too-small chip selection). The command
line gains `--region bios` (or fd/me/gbe/pd/ec): `--read` keeps only that
region at full-chip offsets, `--write --smart` reflashes a BIOS without
touching the ME, and `--region --erase` is refused because a whole-chip
erase under a one-region write would destroy the other regions.

## 4.9.0.0 — the clock steps down before the dump is refused

When read-twice-and-compare disagrees, the commonest cause is a clip
contact that is marginal at the selected clock and fine one step slower.
The reads now walk the programmer's own speed menu downward — rereading
both passes, since the fast reference may be the corrupted side — and only
refuse when the slowest clock still disagrees. A dump that stabilised below
the selected clock says so, naming the speed that worked.

## 4.8.0.0 — the AT45 tells you its own geometry

The two oldest TODOs in the tree. A DataFlash declares its family, capacity
and current page mode in its status register, so the page-size field is now
checked against the chip before every read, write and verify — a 161 in
power-of-2 mode has 512-byte pages, and driving it as 528 shifts every
address in the job with nothing to say so until verify. Read ID fills both
size fields from the chip itself, because the XML table cannot know a chip
was switched permanently to binary mode.

## 4.7.1.0 — a big verify read is not a disconnect

Smart write on a CH341A failed instantly with *"disconnected: verify read:
data read reply transferred -1 of 4096 bytes at 0x00000000"* — before a
single byte had been written. The chip was fine and so was the cable. The
CH341 vendor DLL refuses any single SPI transfer above 3937 bytes (measured
on hardware; its command buffer is 4096 bytes minus per-packet overhead) and
reports that refusal exactly like an unplugged programmer. The legacy read
path always dodged this with 2048-byte chunks, but the Smart-write engine
verifies in erase-block-sized reads — 4096 bytes — so the very first verify
step died on every CH341.

The hardware layer now states its per-call ceiling (`SPIMaxTransfer`: 2048
on CH341 and other conservative backends, 16787 on FT232H, 65535 on CH347),
and the NOR adapter splits long reads into complete re-addressed read
commands within that ceiling. Same wire format, same data, no more phantom
disconnects.

## 4.7.0.0 — the strip knows a new chip from an old one

The strip could see whether a chip was *selected* and whether the buffer was
*full*. It could not see the one thing that decides whether pressing Smart
write is routine or irreversible: **does this chip already hold data?** A
factory-blank part and a laptop's only surviving BIOS produced the identical
green "Ready for Smart write" — and auto-backup is **off by default**.

Three facts are now tracked, each tied to the chip identity it was learned
from, so they expire the moment you change chip, size, protocol, or unplug
the programmer:

- **Chip content** — after any full read the program remembers whether the
  chip came back blank or holding data. All-`FF` is only called *blank* when
  there is proof the chip actually answered (a JEDEC id on SPI, an ACK on
  I²C); otherwise it stays *unknown*, because a dead bus reads `FF` too.
- **Buffer provenance** — from a file (named in the strip), read from this
  chip, or edited by hand. Writing back what you just read is not the same
  risk as writing a stranger's file.
- **Identity proven or merely chosen** — `Detect chip` going green used to
  mean "a size is configured", which is true the instant you pick a name from
  a menu with nothing in the socket. The strip now says when a chip was
  chosen by hand and never confirmed against the socket.

From those it names the real situation: *chip reads blank — nothing to
lose*, *chip HAS DATA and it will be backed up first*, *chip HAS DATA and
auto-backup is OFF — it will be lost* (in red), *buffer was read from this
chip — writing it back changes nothing*, or *ready, but the chip has not
been read — you do not know what is on it*.

## 4.6.2.0 — the bar stopped painting its own name

A `TPanel` draws its `Caption`, and the LCL copies `Name` into `Caption`
when the caption is empty — so the workflow bar painted the word
"WorkflowPanel" across itself. The buttons covered all but the slivers
falling in the gaps between them, which looked like text hidden behind
`Read chip` and `Verify`.

## 4.6.1.0 — the Safe workflow strip tells you what is wrong

- **Smart write is reachable for the EEPROM families.** The strip still gated
  it on "is this SPI NOR", so the three families that gained a differential
  writer in 4.6.0.0 were locked out of their own button.
- **An image that does not fit the chip is reported before you press Write**,
  with the two sizes that disagree, instead of after — and Smart write stays
  disarmed until it does fit.
- A step you cannot press **explains why in its tooltip**: wrong family, no
  image, does not fit, odd MicroWire address.
- `Next: detect or select a chip` no longer appears on I²C and MicroWire,
  where Read ID does not exist and the Detect button is disabled.
- The start-address box **refreshes the strip** (it never did), and parses
  with `TryStrToQWord` — `Hex2Dec` raises on pasted non-hex text that the
  keypress filter cannot stop.
- **Layout is measured, not pinned to pixels**, so translations, larger fonts
  and high-DPI displays no longer overlap or clip the buttons. Bold marks the
  step you can take right now rather than sitting permanently on Smart write.

## 4.6.0.0 — Smart write for the EEPROM families

24Cxx, 93xx and 95xx are byte-alterable, so there is no erase to plan — but
the shape of Smart write still pays. A snapshot is taken, **only the pages
that differ are written**, and every page the range touches is read back,
including the unchanged ones: that is what notices a same-model chip swapped
in between snapshot and write. Changing one byte of a 24C256 costs one page
write instead of 512. `--smart` and `--smart --plan-only` accept these
families; strict production stays SPI-NOR-only.

## 4.5.0.0 — fifteen hunted bugs, signed evidence, no DLLs needed to start

A four-way deep-inspection review found fifteen real defects. The ones that
could cost data:

- the **write-protection guard decoded every vendor with the Winbond layout**,
  so a locked Macronix or ISSI chip sailed straight through it;
- **Spansion TBPROT was read from an opcode those chips do not implement**, so
  a floating-bus `FF` inverted the reported lock direction;
- **`Enter4B` failures were ignored** on write, read, verify and blank check,
  wrapping 4-byte addresses onto block 0;
- **auto-backup hard-failed every 95/45/KB write and erase**;
- an **aborted serial-number apply could log PASS** for a unit that was never
  programmed;
- Micron's flag-status erase/program bits were swapped, AT45 busy-polls
  trusted a dead bus reading `FF`, and an unaligned I²C erase wrapped onto
  bytes below the requested range.

Also new: evidence envelopes bind the run ID into their digest and strict
production **signs them under the station key**; `prodstate.pas` gives a
single station **fail-closed anti-replay state** (stale revisions, duplicate
runs, consumed UIDs and a backwards clock are all refused before PASS);
`--smart --plan-only` prints the full plan and the chip-declared worst-case
time without touching the chip; `--export-chip` emits a ready-to-PR chiplist
line plus a test fixture; the production suite **runs on Linux** as well as
Windows; and **every hardware DLL is loaded at run time**, so the program
starts with none of them present and a missing one reads as an absent
programmer rather than a startup error.

## 4.3.1.0 — the write loop that hung

`WriteFlash25` sized its first chunk as `(ChipSize - StartAddress) mod
PageSize`, which is **zero whenever the start address sits on a page
boundary** — the loop then ran forever issuing zero-length page programs.
Patching at `0x1000` on an 8 MB part hit it every time. The arithmetic moved
into `flashops.pas`, which has no LCL and no `main`, so the test suite can
reach it. Erase now follows the chip's own SFDP sector map, and a silent bus
is named as such.

## 4.2.0.0 — the command line told the truth

`Result := 0` was set after every write regardless of outcome, so a verify
mismatch, a still-protected chip and a busy timeout all exited `0`. There was
no channel from the operation layer back to the caller at all. `--verify` was
also parsed as both a flag and a value switch, so `--write fw.bin --verify
--erase` read `--erase` as the verify filename.
