# Changelog

All notable changes to Chipwright are recorded here. The version in the
first entry must match `software/appver.pas`; CI enforces that invariant.

## 4.37.3.0 — the clock panel now follows a finished tune

- **The bus-clock box no longer shows the old clock after a tune.**

  Auto tune applies its result by ticking the frequency menu item, and the
  panel combo box reads its selection from that same menu — but ticking a
  menu item from code does not fire the menu's OnClick, and nothing told
  the panel to re-read. So after a tune the combo sitting right next to
  the Tune button kept displaying whatever clock was set before (reported
  from a CH347T stuck showing 7.5 MHz). The tuned clock *was* in effect —
  every operation reads the menu, not the combo — but a panel that
  contradicts the log's "auto tune: using 30 MHz" one line away reads as
  a tune that did nothing. The tune now refreshes the panel the same way
  a manual combo change always did.

## 4.37.2.0 — a chip busy erasing is not an empty socket

- **The contact gate now tells a busy chip apart from a missing one.**

  A 25-series chip that is executing an erase or write ignores the JEDEC
  `9Fh` identity command entirely — it reads back all `FF`, exactly like an
  empty socket — but it still answers the `05h` status register with the
  busy bit set. The contact-stability gate judged only by the ID, so a
  retry during a chip erase (which takes minutes on large parts) was
  reported as *"No chip is answering... what an empty socket looks like"*,
  sending the operator to re-seat a clip that was fine. The message even
  claimed the status register read back FF when nothing had read it.

  Worse, the mute-chip recovery then fired a QPI exit and a soft reset at
  the part — and a reset landing mid-erase cuts the operation short.

  When the ID is mute, the gate now reads the status register first. If it
  answers with busy set (and is not the floating-bus `FF`), the gate says
  so, waits for the operation to drain under the existing chip-erase
  timeout with cancel support, and only then resumes the stability passes.
  The reset is never sent at a chip that is provably mid-operation. A bus
  where both ID and status read `FF` still gets the empty-socket verdict —
  and now that verdict's wording is true.

## 4.37.1.0 — a preflight that passes with a note now counts as passed

- **Erase and write no longer refuse chips whose supply voltage is unknown.**

  When the catalog did not know a chip's Vcc, `BenchPreflightOK` printed
  `preflight note: the chip supply voltage is unknown` and returned OK — by
  design, since refusing there would lock out most of the catalog. But it
  returned OK **without recording `sePreflightPassed`** in the session state
  machine, unlike the normal success path. Arming then demanded that fact
  and refused with `erase cannot be armed: electrical preflight has not
  passed` — a message contradicting the note printed two lines above it.

  Seen in the field on an EF4017 (Winbond W25Q64): connection stable 8/8,
  ID matched, and erase still failed "out of order". The unknown-voltage
  path now records the pass exactly as the checked path does, under the
  same guard (only once a chip has actually answered).

## 4.37.0.0 — the three things that have to be right before a chip answers

A chip stays silent for five reasons — empty socket, dead part, bad clip,
wrong rail, clock too fast — and all five produce the same all-`FF` reply.
The program used to name three of them at once and leave the operator to
guess. This release makes it narrow the list instead, and it draws the line
where safety draws it: the clock is swept automatically because sweeping a
clock cannot damage anything, and the rail is not, because it can.

- **A read that loses one USB transfer no longer loses the whole read.**

  A CH341A reported `received -1 of 2048 bytes at 0x004A8000` — 4.6 MB into
  an 8 MiB read, after the connection-stability gate had passed 8 out of 8.
  That `-1` is not a short read. It means the transfer never completed and
  **nothing** was read. The loop treated it as fatal, so a single dropped
  transaction anywhere in 4096 chunks ended the job.

  The CH347 is a well-behaved high-speed device and essentially never drops
  one, so the same code passed there and failed on the dongle — and the
  failure read as `read: FAILED`, which sounds like a dead chip rather than a
  cable.

  The asymmetry that gave it away: the *write* path has retried pages for
  years (`MaxPageRetry = 3`). The *read* path — the one that cannot damage
  anything — had no tolerance at all.

  So reads now retry, and the rule is a typed decision in `flashops` rather
  than a number in a loop, because it is one distinction away from being
  wrong:

  | | means | response |
  |---|---|---|
  | `-1` | the transfer never happened; nothing was read | **retry** — re-issuing a read is idempotent |
  | short count | the chip answered with fewer bytes | **report** — that is an answer, not an accident |
  | two reads disagreeing | the chip answered differently | **refuse** — unchanged, still `ConnectionStableForDestructive` |

  Retrying a failed transport is not asking until the answer is agreeable; it
  is completing an operation that never occurred. Retrying a *disagreement*
  would be the sin, and that path is untouched.

  A read that succeeded but needed repeats now says so. The data is correct
  and the link is marginal, and an operator who is never told will find out on
  the day three drops land in a row.

- **Detect sweeps the clock itself before calling a socket empty.**

  The commonest cause of "no chip answered" is a clock the wiring cannot
  carry, and the program already knew how to find the boundary — Auto tune
  clock has existed for releases. It just sat in a menu nobody visits while
  wondering why a populated socket reads as empty.

  Now a silent detect walks the ladder automatically, once per session, and
  re-reads the ID if a chip appears. The log stops contradicting itself: the
  `ID(9F): FFFFFF` line is replaced by the real one rather than left standing
  as evidence against the result.

  And when the ladder comes back empty, the program **stops advising a slower
  clock**. That advice is correct until someone has tried it and misleading
  afterwards; the message now says the bus speed has been ruled out and what
  is left is the rail, the clip, or the part. Three simultaneous maybes become
  one narrowed answer.

  Once per session, reset when the rail or the programmer changes — because
  those are the moments the world actually changed. Detecting on an empty
  socket is the normal state before seating a chip, and it must not cost a
  ladder walk every time.

- **The rail is never swept, and now it is one click away.**

  This was asked for as "auto detect voltage", and the automatic version is
  the one thing in this area that must not be built. The reasoning an
  automatic sweep would have to make is:

  > Nothing answered at 1.8 V, therefore it is not a 1.8 V part, therefore
  > 3.3 V is safe.

  The middle step is false. "Nothing answered at 1.8 V" is equally consistent
  with a 1.8 V part that is not clipped properly — which is not a rare case,
  it is the commonest condition on a bench. The sweep would put 3.3 V on it,
  and the moment the clip seats, the part is gone. Too little voltage costs a
  retry; too much costs the chip. That asymmetry is what this whole program is
  built on.

  So the rail stays a decision, and what changed is the distance between
  knowing what to do and doing it. After the clock has been ruled out — and
  only then — a **Try 3.3 V** button appears in the Target voltage box, with
  the consequence stated next to it. It disappears as soon as a chip answers
  or the rail changes. The click is still the operator's.

- **An SPI clock box on the left panel**, beside Target voltage, with a
  **Tune** button. The two things that must be right before a chip will answer
  are now visible together, instead of one being on screen and the other two
  menus deep.

- **The shipped default clock is 15 MHz, not 60 MHz.** 60 MHz is the top of
  the CH347's range, and the program's own diagnostic calls it "often too fast
  for a clip lead or a long cable". Shipping the most aggressive setting and
  letting the user discover the consequence is backwards for a program whose
  every other default fails safe. Note this helps new installs only — an
  existing `settings.xml` keeps its saved value, which is precisely why the
  automatic sweep above matters more than the default does.

### The build produces Chipwright.exe

Carried over from 4.36.0.0 and worth repeating because it changes what you
run: `tools\build.ps1` now produces `software\Chipwright.exe` and
`ChipwrightCLI.exe` directly, rather than building `AsProgrammer*.exe` and
renaming only inside the release ZIP.

## 4.36.0.0 — eight things that were decided somewhere nobody could look

Eight changes, and what they have in common is that each replaces a judgement
call with something a person can check. A gate that says "pending live
validation" and a gate that names the six outstanding checklist items refuse
exactly the same operations; only one of them tells you what to do next.

- **`signalchar`**, the place a bench measurement of what a programmer drives
  on CS/CLK/MOSI is written down.

  Everything in this program's electrical model is downstream of one sentence
  in the rail report: *"assumed to follow the rail, not measured"*. A board
  that switches VCC to 1.8 V while its logic keeps swinging to 3.3 V passes the
  rail check, passes the preflight, passes the whole admission ladder, and
  destroys the part. Nothing in software can see it.

  `ch347hw` and `ft232hhw` no longer assert an answer to that question; they
  ask this unit. The table is **empty**, which is the correct and current state
  of the world — nobody has put a probe on those pins — so the program still
  says "assumed" and production admission still refuses. What changes is that
  recording a measurement is now a six-line diff in one place, after which the
  rail report, the preflight, the CLI's `signal_mv`/`signal_measured` and the
  session report all start carrying the measured number without further edits.

  And if the measurement comes back *bad* — signals at 3.3 V on a 1.8 V rail —
  the preflight refuses on `signal_voltage_too_high`, using a rule that was
  already written. The table is compiled in rather than read from a file, for
  the same reason the evidence table below is: it unlocks the strictest gate in
  the program, so it has to be reviewable in source.

  `hardware/test-procedure.md` now ends by telling you where to put the result,
  and says plainly that three of its four possible outcomes are still worth
  recording.

- **`validationgate`**, which turns "pending live validation" into a checklist
  with ticks against it.

  SPI NAND erase/program and destructive Smart Write over libusb are both
  written, both tested, and both unreachable. Each design document sets out a
  numbered list of what live validation involves — and neither says what result
  lifts the gate. So the gate stayed shut not because the evidence was missing
  but because nobody could point at the thing that would settle it.

  The two checklists now live in this unit as data. `ChipwrightCLI --gates`
  prints them with covered items ticked; a refused `--nand-write` or
  `--smart-write` names the outstanding items and the document they come from.
  Releasing a capability is a transcription of a hardware-in-loop run into one
  `Append(...)` call, and the destructive HIL workflow now leaves behind a
  draft of exactly that record — with the checklist coverage deliberately left
  at zero, because a workflow that filled that in for itself would be attesting
  to work it cannot see.

  Coverage does not accumulate across runs. The value of "restore the original
  image and verify it" is that it happened to the same part, in the same
  session, as the identification that opened the run.

  The environment tokens stay, and are not a second way through: they are how
  the validation run itself is performed, since somebody has to issue
  destructive commands before any evidence can exist. A run that uses one while
  the capability is gated now says it is a validation attempt, not a validated
  operation.

- **`sfdpprofile`**, which describes a chip the catalogue has never heard of.

  The catalogue holds 658 SPI NOR entries. A part that is missing from it was a
  dead end: the JEDEC ID came back, the vendor byte decoded, and there was
  nowhere to go — while the chip had been carrying a full description of its own
  geometry the whole time, in the SFDP tables this program already parses
  completely.

  Every incoherent geometry falls back to **read-only** rather than to a guess:
  a declared-but-unresolvable sector map, a capacity that is not a whole number
  of erase units, a part above 16 MiB that names no four-byte erase opcode.
  Reading is the operation that cannot destroy anything and is how somebody
  gets their data off an unknown part, so it is the last thing surrendered.

  It narrows the voltage question by nothing, and that is what makes it safe to
  add. SFDP has no supply-voltage field anywhere, so the four-tier ladder runs
  unchanged — including tier 4, which works from the JEDEC ID and catches the
  dangerous parts. The synthesised name is prefixed `SFDP-` and is built so it
  cannot trip the name-based inference rules; the suite asserts that, because a
  voltage inferred from a string this program made up itself would be the worst
  kind of wrong.

  The GUI's SFDP path used to name such a part `SFDP 8192K` and leave its
  JEDEC ID blank — so two different parts got the same name in the log, the
  backup manifest and the evidence file, and the identity re-check before every
  destructive step had nothing to compare against. It now carries the ID that
  was read.

- **`quadpolicy`**, and an honest answer about quad reads.

  Most parts can be read four bits at a time, which on a 16 MiB chip is the
  difference between a coffee and a glance. Quad needs the QE bit set, and QE
  is non-volatile: setting it is a permanent modification to somebody else's
  chip, made for the programmer's convenience, and a board that boots its flash
  in single-bit mode can be made unbootable by it. So the rule is narrow and
  absolute — **use quad if it is already on, never turn it on** — and there is
  no flag that changes it.

  `sfdp` now parses the three words the decision needs: DWORD-1's mode bits,
  DWORD-3's opcodes and dummy cycles, and DWORD-15's quad-enable requirement,
  which is what says whether QE lives at bit 1 of SR2 (Winbond) or bit 6 of
  SR1 (Macronix — the bit the Winbond layout calls SEC). Reading the wrong
  table does not give a wrong answer, it gives a plausible wrong answer.

  A declared mode needing continuous-read mode clocks is refused outright: get
  the mode byte wrong and the part reads the next command as an address, and
  the way out is a reset the programmer may not be able to issue.

  And then the honest part. **No supported programmer can drive four data
  lines.** The WCH DLL's fastest SPI entry point is `CH347StreamSPI4`, where the
  4 counts wires — CS, CLK, MOSI, MISO — and there is no quad entry point at
  all; FT232H MPSSE drives one line out and one in. So `SupportsQuadSPI` is
  False on every backend, and the SFDP report says the useful thing: your chip
  is ready, your programmer is the limit. That is worth more than silence, and
  the policy is in place for the day a backend gains the ability.

- **`sessionreport`**, the document a bench session leaves behind.

  Authenticated production produces signed evidence. Bench work produced a
  scrolling log pane, which cannot be attached to an invoice and disappears
  when the window closes. Every fact worth recording was already computed
  somewhere; nothing collected them. **Log → Save session report...** now does.

  Its value is entirely in what it refuses to smooth over. A check that never
  ran is marked `[ ]` and stays in the list, because a report showing six ticks
  because the seventh check never happened is worse than no report. A refusal is
  an outcome, not an absence — a session where the program declined to write is
  a successful session and reads that way. The rail lines are carried through
  from `railreport` verbatim, so "not measurable on this programmer" and
  "assumed to follow the rail" arrive intact. There is no summary verdict,
  because this unit has no basis for deciding whether a session went well.

- **`writejournal`**, so an interrupted write does not have to be redone in full.

  Step 8 of the write chain is erase-and-program. If USB drops halfway, the chip
  is in a state nothing in this program could describe: some blocks erased, some
  programmed, and no record of which. The backup made the data recoverable, but
  only by writing the whole part again — minutes of redone work, and another
  chance to be interrupted.

  The journal is append-only, and that is the entire design. A file that rewrote
  itself after each block would have a window in which it is half old and half
  new, and the crash this exists for is exactly the crash that lands in that
  window. A header is written once and each completed unit is one appended,
  flushed line. A line counts only once its newline is on disk.

  That is safe because every recorded unit is idempotent: erasing an erased
  block sets it to FF again, programming a page with the bytes it already holds
  writes the same bytes. A torn line costs one repeated block. The opposite
  error — a line surviving for work that did not finish — would be data loss,
  and the loss is held to the safe direction by construction.

  The refusals are the other half. A resume is only the same operation as the
  one that was planned if the chip identity, the capacity, the image and the
  backup are all still what they were, and each is checked separately. The
  backup one matters most: resuming without a matching backup is a write with
  no way back, on a chip that is already half written.

- **`simhw`**, a programmer that is not there.

  The program has been unusable without hardware, which costs three things:
  nobody can evaluate it before buying a CH347, a bug report cannot be
  reproduced without the reporter's chip, and the README screenshots can only be
  made at a bench. The test suites solved this for themselves four times over,
  but all of those sit above or beside `TBaseHardware`, so none could be
  *selected*. This one is a `TBaseHardware`: **Hardware → Simulated (no
  hardware)**, and everything above it runs unchanged.

  It models the wire, not the engine. A program without WEL does nothing,
  silently. Programming only clears bits, so a missing erase produces exactly
  the corruption it produces on silicon. A program past the end of a page wraps
  to the head of that same page. An erase address inside a sector erases the
  whole sector. All four are behaviours that make a caller's bug invisible, and
  a simulator that smoothed them over would certify code that fails on the
  first real chip.

  It calls itself SIMULATED everywhere the programmer name reaches, and there
  is no setting that changes that: a screenshot or a report that came from here
  and does not say so is a false record of work on somebody's board. Its
  electrical capabilities are the honest ones for a thing with no pins — it
  reports that it cannot measure anything, exactly as the CH347 does. Reporting
  a perfect 1.8 V would have made every electrical check pass while proving
  nothing about them. It is last in the hardware list and auto-detection never
  selects it.

- **`voltagewarning`**, lifted out of a GUI function.

  The last warning before a 1.8 V part meets a rail that would destroy it lived
  inside `VoltageWarningOK`, interleaved with three `MessageDlg` calls, so none
  of its cases could be exercised. The decision has nothing to do with a screen:
  it is a function of the chip's range, the programmer, and the rail that
  programmer is set to. The dialogs are what you do with the answer.

  The case worth having tests for is Auto. On a board that can switch its rail,
  "Auto" is not a rail, and the rule has to tell an Auto that will resolve to
  1.8 V from an Auto that cannot resolve at all — nagging about a correct rail
  trains people to click through warnings, and staying silent about an
  unresolvable one costs a chip. The suite walks every combination the context
  record can hold and asserts two invariants across all of them: no verdict ever
  approves a high rail for a low-voltage part, and no board that cannot switch
  is ever offered a switch.

  `DefaultMemoryCapabilities` came out of `TBaseHardware` in the same spirit —
  the model-to-capability table needed a constructed backend to exercise, and a
  backend needs a DLL present, so the table was untestable and a capability
  could have quietly become True.

Eight new suites, ~500 assertions, all hardware-free: `signalchar_tests`,
`validationgate_tests`, `sfdpprofile_tests`, `quadpolicy_tests`,
`sessionreport_tests`, `writejournal_tests`, `simhw_tests`,
`voltagewarning_tests`.

### The build produces Chipwright.exe, not AsProgrammer.exe

The Lazarus target filename is now `Chipwright`, and the headless CLI is built
with `-oChipwrightCLI`. Both were previously named after the project files they
were built from and only renamed on the way into a `-Release` package, so an
ordinary `tools\build.ps1` left `software\AsProgrammer.exe` behind — the binary
a developer ran was never the one a user ran, and only the packaged copy
carried the right name. The `.lpi` and `.lpr` files keep their names; nothing
about the project layout changes.

That surfaced a bug in `tools/hil.ps1`, which searched `release\` for
`AsProgrammer.exe`. The release folder stopped containing that name some time
ago, so the search always fell through to its source-tree fallback — meaning a
hardware-in-loop run could be exercising a developer's last local build while
reporting on the packaged release. It now looks for `Chipwright.exe` and fails
loudly if it is absent.

## 4.35.1.0 — the credits describe what this program actually is

The About box and README still read as though this were a fork with a few
patches on top. That stopped being true some time ago, and the licence file
named only the upstream author for a codebase whose safety architecture,
electrical model, machine interface and entire test suite were written here.

- `LICENSE` now carries **both** copyright lines, which is exactly what MIT is
  built for. The project's own line comes first; the upstream line stays and
  says what it covers — the inherited protocol units, hardware backends,
  script engine and chip catalogue — and that it must be retained for as long
  as those remain in the tree.

  That second line is not optional and is not about which licence this project
  chose. MIT requires the notice to travel with the code it covers, so
  removing it would make the result undistributable. Everything else that read
  as deference to the upstream project is gone.

- The About box leads with Chipwright and names its own work first. Prior work
  is a factual paragraph further down rather than the headline, and the
  separately licensed components — MPHexEditor, Ararat Synapse, FTDI D2XX,
  flashrom's chip data — are listed as what they are.

- Promotional links to the upstream repositories are removed from the About
  box, the Credits dialog and the Buzzpirat help menu item, which now points
  at this project's own repository. Someone pressing Help in this program
  wants this program's documentation.

  One upstream URL stays, in `tools/build.ps1`: the pinned archive the vendor
  runtime DLLs are downloaded and hash-verified from. That is a functional
  dependency recorded in `vendor-manifest.json`, not a credit, and removing it
  would break the release build.

- `OriginalFilename` in the exe resource said `AsProgrammer.exe` while the
  shipped binary has been `Chipwright.exe` for some time.

## 4.35.0.0 — one answer to "does this image fit this chip"

- **`writeadmission`**, a new core unit holding the rule that decides whether
  an image can be written to a chip at an address, and the one sentence saying
  why not.

  The rule lived inside the GUI's workflow-strip painter, which meant the
  command line had its own separate answer to the same question. Two answers to
  "does this fit" is one answer too many — the GUI would grey out a button
  while the CLI accepted the job, or the reverse, and which one was right
  depended on which file somebody had edited more recently.

  It is also the check that decides whether a write runs off the end of a part.
  Getting it wrong produces no error: it produces a write that stops partway
  with the chip half-programmed, discovered at verify if verify is on at all.

- 37 assertions, and the ones worth reading are the boundaries. An image
  ending exactly at the last byte is admitted and one byte past it is not. The
  fit test is written as `ChipSize - StartAddress` rather than
  `StartAddress + BufferSize` specifically so an enormous buffer or an address
  near the top of the range cannot wrap the addition into a false fit — and
  that has a test rather than only a comment.

- The refusal names **the next thing to fix, not the worst thing wrong**. An
  operator with three problems wants the first one, so the order runs from
  "connect a programmer" through to "the chip has not answered an identity
  read yet".

  That last one is the softest reason and is flagged as such in the result,
  because picking a chip by name and writing it is a real workflow — just an
  unproven one. Callers get an explicit boolean instead of pattern-matching
  the sentence.

- MicroWire is exempted from the page-size check, because its handler fixes
  the page at two bytes itself and refusing a job over a field with no effect
  would be a rule enforcing nothing.

## 4.34.0.0 — Lab Tools

A new top-level **Lab Tools** menu, deliberately separate from the flash
programmer surface. The main window has one job; folding a bus scanner and a
serial terminal into it would clutter the screen that most needs to stay clear
without gaining anything.

- **I²C bus scanner.** Probes `0x08`–`0x77` with a bare address byte and
  reports what acknowledges, flagging `0x50`–`0x57` as typical 24-series
  EEPROM addresses without deciding for you.

  It never touches the I²C reserved ranges, and that is not fastidiousness.
  `0000 xxx` includes the general call address, which *every* device on the
  bus obeys, and `1111 xxx` is the 10-bit addressing escape. A "scan" that
  includes them is issuing commands rather than asking questions.

  When nothing answers it says what to check, including that pull-ups sized
  for 3.3 V rise too slowly at 1.8 V and produce intermittent detection rather
  than clean silence.

- **SPI console.** Type command bytes, optionally read N back, see a canonical
  hex dump. It accepts `9F`, `9f`, `0x9F` and `9Fh`.

  A malformed token refuses the **whole line** rather than being skipped. A
  console that silently drops a token sends a command the operator never read
  on screen, and on a flash chip the difference between `20` and `60` is one
  sector versus the entire part. Three hex digits are refused too — that is
  almost always a missing space, and guessing where it belongs sends something
  else.

  The window says plainly that it bypasses every guard in the program, and
  that `9F` reads an ID while `C7` erases the chip. The one guard it cannot
  bypass is read-only safe mode, because that latch is on the opcodes
  themselves rather than on the buttons.

- **UART terminal.** Talks straight to a COM port through the same `synaser`
  the Arduino, Bus Pirate and serprog backends use, so it works with anything
  plugged in rather than only with a programmer. Receive is polled on a timer
  rather than a reader thread — a terminal does not need the synchronisation
  machinery a thread would drag in.

- The decidable parts — the address policy, the hex parser, the dump
  formatting — live in a `labtools` core unit with 57 assertions. The dialogs
  above them only move bytes and paint text.

- The windows themselves live in a new `labtoolsui` unit, not in `main.pas`.
  Adding 450 lines of dialog code to the file this project is trying to break
  apart would have been the wrong direction, so the three handlers left behind
  in the form are three lines each.

  `labtoolsui`'s implementation uses `main`, and `main`'s implementation uses
  `labtoolsui`. That circularity is legal because it is implementation to
  implementation, and it is the seam that lets UI leave `main.pas` one window
  at a time rather than in a flag-day rewrite. `LockControl`, `UnlockControl`
  and `OperationRunning` moved to `main`'s interface so the extracted window
  shares the real ones instead of growing a second, divergent copy.

## 4.33.0.0 — the erase geometry becomes testable, and FT232H gets characterised

- **`BuildCurrentNORGeometry` moved out of `main.pas`** into a new
  `norgeometrybuild` core unit. It is the most consequential arithmetic in the
  program: the block list it produces is what the erase actually erases, and a
  block of the wrong size, at the wrong address, or carrying the wrong opcode
  does not fail loudly — it destroys data that was never part of the job and
  reports success.

  It was already pure logic. It just read four `main.pas` globals, which meant
  it could not be exercised without a GUI and a chip. It now takes them as
  arguments, and 34 assertions cover what nothing covered before: boot-block
  regions tiling the chip exactly, the smallest *aligned* erase type winning
  (a type that is merely offered is unusable if it would straddle a region
  boundary), a map that under- or over-covers the part being refused, a
  declared-but-ambiguous sector map never being replaced with a guessed
  uniform one, and a missing dedicated 4-byte opcode failing the build instead
  of silently erasing at a wrapped address above 16 MiB.

  Writing those tests found a real thing worth knowing: my first fixture gave
  a boot-block part's upper region *both* erase sizes, and the code correctly
  chose 4 KB over 64 KB. Erasing 64 KB where 4 KB would do destroys 60 KB of
  neighbours on a partial write, so "smallest aligned type wins" is load
  bearing, and it is now pinned.

- **FT232H is characterised.** Its facts come from the FTDI part rather than
  from whichever board it is on: MPSSE I/O swings to VCCIO, breakouts tie
  VCCIO to the same 3.3 V that feeds the target, the clock ceiling is the
  30 MHz this program's own divisor sets, and there is no ADC, sense resistor,
  load switch or backfeed detection anywhere on the part.

  `SignalVoltageVerified` stays `False` — the reasoning is sound and still an
  inference, since a breakout strapped to 5 V VCCIO looks identical from
  software. The useful effect is that **1.8 V parts are now refused on an
  FT232H**: 3.3 V logic into a 1.8 V flash is about 1.5 V over its absolute
  maximum, on three pins at once.

- **CH341A is deliberately left uncharacterised, and now says why.** This is
  the one case where "unknown" is not laziness. Boards of that family are
  widely reported to drive 5 V on CS/CLK/MOSI while VCC reads 3.3 V; the usual
  fix is a wire soldered across the board; and a modified board is identical
  to an unmodified one from the driver's point of view.

  Filling in a number would be wrong for half the boards in the world in one
  direction or the other — 3.3 V understates the hazard on unmodified boards,
  5 V refuses all work on modified ones. So opening a CH341A now prints a
  specific caution naming the 5 V issue and saying not to put a 1.8 V part on
  it, instead of the generic "capabilities unknown" it printed before.

## 4.32.0.0 — the admission ladder now actually gates something

The `sessionstate` unit shipped in 4.27.0.0 with its rules complete and no
button feeding it. It is wired now, and it refuses.

- Events are fed at **funnels, not call sites**. `OpenDevice` for the
  programmer, `ApplyCH347Vcc` for the rail, `MPHexEditorExChange` for the
  buffer, and the JEDEC identity read for the chip. There are eight places
  that load the buffer and eight that read an ID; hooking each would have
  missed the ninth somebody adds later. The funnels are where the fact
  actually changes.

- `ProtectionGuardOK` is the single choke point all seven destructive paths
  pass through, and it now **establishes what it needs rather than assuming
  an earlier step did it**. That distinction was the whole difficulty: only
  one of the seven paths ran the identity check, so a gate that trusted an
  earlier step would have refused legitimate work on the other five —
  capacity test, surface scan, plain write, erase range, and block erase.

  So the guard reads the JEDEC identity itself, immediately before the
  destructive step. That is strictly better than trusting an earlier check:
  it is evidence the chip is answering *now*, not evidence it answered when
  a button was pressed two minutes ago. An all-FF or all-00 reply is a
  floating or held-down bus, not a chip, and stops the operation.

- The guard then re-runs the electrical preflight **against the chip that
  actually answered**, rather than the one that was selected in the UI.

- Arming is asked as `MayArm`, not `MayStart`. A caller that armed and then
  asked whether it could start would be asking a question it had just made
  true, which proves nothing. There is deliberately no new Arm button: the
  operator already confirms destructive work at the Smart Write plan, the
  erase dialog, or `--force`, and the ladder enforces the *order* of
  everything upstream of that confirmation without adding a ceremony.

- What this stops, that nothing stopped before: erasing after changing the
  target rail (chip detection is revoked, because a chip that answered at
  3.3 V is not evidence of a chip at 1.8 V); writing an image loaded after
  the preflight that judged the previous one; and any destructive step
  reached while the chip has stopped answering.

## 4.31.0.0 — a backup that can answer questions, and a second opinion

- Every automatic backup now writes a `.json` manifest beside the `.bin`,
  recording the chip name, JEDEC ID, capacity, programmer, the rail it was
  read at, the UTC timestamp, and the SHA-256 of the file as written to disk.

  A bare `.bin` cannot answer any of the questions that get asked at recovery
  time — which chip is this from, when, at what voltage, and are the bytes
  still what they were. Those get asked precisely when they are hardest to
  reconstruct.

  The rail follows the same rule as everywhere else: `requested_mv` and
  `measured_mv` are separate, and an unmeasurable one is `null` rather than
  `0`. A backup claiming it was read at 0 V is worse than one admitting it
  does not know.

  A manifest that fails to write does not fail the backup — the `.bin` is
  already durable and still restores — but it says so rather than going quiet.

- After a write verifies, the program now closes the USB device, reopens it,
  restarts the bus, and verifies a second time. This catches reads cached in
  the driver or the DLL, contact that is marginal only until something is
  re-initialised, and chip state that does not survive a full bus reconfigure.

  **It is not the power-cycle verify that was asked for, and it does not claim
  to be.** No supported programmer can remove target power: the CH347's GPIO6
  *selects* between 1.8 V and 3.3 V and has no off state, and no other backend
  has a power-control command at all. So this is a fresh USB session, the log
  says exactly that, and data retention across a real power loss remains
  untested. Testing it needs the load switch already recorded on the hardware
  wishlist in `hardware/assembly.md`.

  A chip that verifies once and then disagrees in a fresh session has the
  write reported as failed, not as a warning.

## 4.30.0.0 — a switch that removes the ability to change a chip

- **Read-only safe mode**, in Options and as `--safe` on the command line. For
  an unknown part, or a customer's board, that you need to read and identify
  and nothing more.

  Every other safeguard in this program is a judgement — is this rail right,
  is this clip solid, does this image fit. Judgements can be wrong, and these
  ones are made by software reading a chip that may be lying about what it is.
  This is not a judgement. It is a switch that removes the capability.

- The latch sits on the eleven mutating SPI NOR opcodes in `spi25.pas`, not on
  the buttons. Guarding the buttons means guarding only the doors somebody
  remembered, and the write path is reached from menus, scripts, the
  status-register editor, the capacity test and the command line. Putting it
  where the capability actually lives closes every route, including the ones
  nobody has written yet — a new call site is covered the day it is added.

  The protocol layer refuses silently with the same `-1` it returns for a
  disconnected cable, which every caller already checks. The sentence
  explaining *why* comes from the UI layer, which is the layer that knows what
  the operator was trying to do.

- Status-register writes are included, and that is the part people argue with.
  They change no byte of the array, so they look harmless. They are how a chip
  becomes permanently locked: SRP and WPS bits can be set into one-time
  configurations no software will ever undo. On a customer's part that is
  worse than a bad write, because a bad write restores from the backup.

- `--force` does not override it, deliberately. `--force` means "I know what I
  am doing", which belongs on gates gaurding things an operator can know. Safe
  mode guards against the operator at the operator's own earlier request; a
  flag that switched it off would make it a suggestion rather than a latch.

- Off at startup. A safety mode that defaults to on gets switched off once, on
  the first day, and never switched back on.

- An action nobody classified counts as destructive. The cost of being wrong
  that way is a refused operation; the cost of the default going the other way
  is somebody else's chip.

## 4.29.1.0 — the source tree stops carrying 27 MB that was never source

- Removed from the working tree (git history was deliberately left alone, so
  nothing is lost and no clone or fork is invalidated):

  - `software/.text`, `.data`, `.bss`, `.idata` and `.rsrc/` — 2.8 MB of PE
    sections someone had unpacked out of a built `AsProgrammer.exe` and
    committed. `.text` is the compiled code and `.rsrc` holds the form and
    icon resources; every build regenerates all of it.
  - Six vendor runtime DLLs from `software/`, plus two duplicates under
    `software/buzzpirathlp/`. `tools/build.ps1` already downloads these from
    one pinned upstream archive and checks every byte against a recorded
    SHA-256, so the copies in the tree were a second, unverified answer to a
    question that already had a verified one.
  - 15.8 MB of Zadig — three builds of one tool, for an OS matrix that has not
    included Windows XP or Vista for a long time.
  - The FTDI and WCH driver installers, and `CH341PAR.ZIP`, which duplicated
    the extracted `CH341PAR/` directory sitting beside it.
  - `firmware/AVRISP-MKII/WindowsDriver/`, byte-identical to
    `drivers/AVRISPMK2/`.

  `software/libusb0.dll`, `mphexeditor.zip` and `drivers/EZP2023Plus/` stay:
  the build needs all three locally and no pinned download exists for them.

- New `vendor-manifest.json` records every third-party binary — what it is,
  its SHA-256, its licence, and where it came from. The `provenance` field is
  the honest part: `pinned` means the build downloads it from the recorded URL
  and refuses to package it on a hash mismatch; `unrecorded` means the bytes
  are known and the origin is not, because nobody wrote down where the file
  was downloaded from. No URL has been invented to fill a gap.

- Releases now carry a CycloneDX SBOM listing every packaged file with its
  SHA-256, generated from the assembled folder rather than a hand-kept list,
  and a `.sha256` file beside the ZIP.

- New `hardware/` directory. The board is a commercial CH347Ⅱ V2.13, so this
  is reverse engineering rather than design output — which is precisely why it
  needs recording, because the software refuses operations on the strength of
  claims about how this board behaves.

  `pinout.md` tags every claim with how it was established. One is marked
  UNVERIFIED: whether CS/CLK/MOSI actually follow the target rail. A board
  that switches VCC to 1.8 V while its logic keeps driving 3.3 V passes every
  check the software can perform and destroys 1.8 V parts.
  `test-procedure.md` is the fifteen minutes with a scope that settles it, in
  either direction, and says exactly which line of `ch347hw.pas` changes for
  each possible answer.

- The driver hints in the log named paths under `drivers\` that a fresh clone
  no longer has. They now name the driver — "the WCH CH34xPAR driver" — and
  point at `vendor-manifest.json` for the vendor, version and hash.

## 4.29.0.0 — a caller that is not a person gets a real answer

- Both front ends used to answer every question with 0, 1 or 2. A script could
  tell success from failure and from a typo, and nothing else. Anything that
  wanted to know *why* had to match substrings against log lines written for
  people — lines that get reworded whenever someone improves them, and that
  are translated.

  The reasons where the correct next action differs now have their own exit
  codes: 3 no programmer, 4 programmer lost mid-operation, 5 no chip answered,
  6 the wrong chip answered, 7 the rail was refused, 8 the connection is
  unstable, 9 the chip is locked, 10 the file does not fit the chip, 11 verify
  failed, 12 a local file could not be read or written, 13 cancelled. 0, 1 and
  2 keep their old meanings, so existing scripts are unaffected.

  Anything finer would be a taxonomy of internals. A timeout, a short transfer
  and a bad clip all arrive as 8, because from outside they are one
  instruction: stop and reseat. Retrying a timeout into a half-erased chip is
  how a recoverable fault becomes a dead part.

- `--json` now emits `schema_version` first, so a consumer can refuse a
  payload it does not understand instead of reading a renamed field as absent,
  and carries the rail state alongside the result:

      {"schema_version":1,"action":"detect","ok":true,"result":"ok",
       "programmer":"CH347","chip":"W25Q64FW","jedec_id":"EF6017",
       "size":8388608,"bytes":0,"requested_mv":1800,"measured_mv":null,
       "target_current_ua":null,"external_power_detected":null,
       "signal_mv":1800,"signal_measured":false}

  Unmeasurable values serialise as `null`, never `0`. A consumer reading
  `"measured_mv":0` as a measurement of zero volts is the machine-facing
  version of exactly the mistake the rail report exists to prevent for people.
  `external_power_detected` is three-valued for the same reason: `false` means
  "no external voltage is present", `null` means "this programmer cannot see
  external voltage", and merging them is how a chip gets written while a
  motherboard backfeeds its rail.

- New `--preflight`: reports the rail and whether a destructive operation
  would be allowed, without touching the bus. It asks the destructive
  question even though it writes nothing — reporting "fine" because it only
  asked the read-only question, and then being refused during the actual
  write, would be wrong in the worst direction.

- The JSON escaper moved into the shared contract unit and now escapes
  control characters properly. Error text carries file paths, and an
  unescaped backslash turned a valid payload into a parse error at the far
  end — which a calling script reports as "the programmer crashed".

## 4.28.0.0 — the program finds the clock the wiring can carry

- Options → SPI → Частота → **Auto tune clock**. It starts at the slowest
  clock on the ladder, where the wiring cannot be the reason an answer is
  wrong, and establishes what the chip says about itself. Then it climbs,
  asking the same question three times per rung. The first rung whose answer
  changes ends the climb, and the program steps down one further rung for
  margin before ticking the menu entry it chose.

  Three reads per rung, not one: above the boundary the failures are
  intermittent, so a single read accepts a marginal clock most of the time —
  fast, plausible, and wrong during the write. The climb also stops at the
  first disagreement rather than looking for a faster rung that happens to
  agree, for the same reason.

  The fingerprint compared at each rung is the JEDEC ID *and* a CRC of a real
  4 KB data read. A clock that corrupts long transfers but not three-byte ones
  sails through an ID-only comparison and then fails during the actual read,
  which is far too late.

- Three outcomes, told apart, because the operator's next move differs:

  - **tuned** — a clock was found, and the log says where it broke and what
    the safety margin cost.
  - **unstable at the slowest clock** — the chip gave different answers at the
    slowest speed available. This is a contact fault, and the program says so
    instead of suggesting a slower clock, which is the ten-minute dead end an
    operator otherwise walks down.
  - **no answer** — nothing replied at any speed, so the log points at the
    rail, pin 1 orientation and seating rather than at the clock.

- Erase and write now read three sample regions — start, middle and end —
  twice each, and compare, before touching a status register. A chip that
  answers the same question two different ways invalidates more than the
  current operation: it invalidates the backup that recovery depends on. So
  this refuses rather than retries, and `--force` deliberately does not
  bypass it. `--force` means "I know what I am doing", which applies to things
  an operator can know; an intermittent clip is not one of them.

  The refusal names the first differing address, not just "verify failed".

  Samples that are entirely FF are reported rather than refused: a blank chip
  really does read FF everywhere, and so does a disconnected bus. The log says
  the check cannot tell those apart, which is the honest position.

## 4.27.0.0 — what was asked for and what was measured are no longer the same line

- The program used to show the rail it had *asked* for and nothing else, which
  reads as confirmation. An operator sees "1.8 V", and there is no way to tell
  that from a board that actually measured 1.79 V and agreed. A CH347 with a
  stuck GPIO, a clip on the wrong pad, and a rail loaded down by a motherboard
  all displayed exactly the same "1.8 V".

  Opening a programmer now prints what is commanded and what is observed as
  separate facts:

      Requested voltage:         1.8 V
      Measured voltage:          not measurable on this programmer
      Target current:            not measurable on this programmer
      Current limit enabled:     not measurable on this programmer
      External voltage detected: not measurable on this programmer
      Signal (CS/CLK/MOSI):      1.8 V (assumed to follow the rail, not measured)

  "not measurable" is the answer, not a gap in the report. No CH341, CH347 or
  FT232H has an ADC on the target rail, a sense resistor, a load switch, or
  backfeed detection, so today that is the honest reply for all three. When a
  board with sensing arrives it fills the observation and these lines start
  carrying real numbers with no other change.

- `EnterProgModeSPI25` — the one place CS and CLK start moving for the whole
  program, GUI, CLI and scripts alike — now runs the same electrical preflight
  that authenticated production has always used, under a bench policy. A rail
  outside the chip's range, or a signal level above what the chip tolerates,
  stops the operation before the first clock edge rather than after it.

  The bench policy differs from the production policy only in what it demands
  the hardware be able to *prove*. A policy that required a measured voltage
  and an enabled current limit would refuse every operation on every programmer
  this program supports, which teaches operators to bypass the gate and takes
  the decided failures down with it. So an uncharacterised backend produces a
  note and continues; a wrong rail produces a refusal. Production admission is
  unchanged and still refuses both.

- The signal level a programmer drives on CS/CLK/MOSI is now tracked separately
  from the supply, and separately again from whether anyone has measured it. A
  board that switches VCC to 1.8 V while its logic keeps swinging to 3.3 V
  passes every other electrical check and destroys 1.8 V parts; this is the
  only field that catches it. Nobody has put a scope on the CH347 board's
  signal pins at both rail settings, so the program says "assumed" rather than
  claiming a figure, and `hardware/test-procedure.md` records how to settle it.
  Production now refuses a programmer whose signal level is an inference.

- New `sessionstate` unit: the admission ladder from Disconnected through
  RailConfigured, ChipDetected, ImageLoaded, PreflightPassed and Armed to
  Completed, with the revocations that carry the safety. Changing the target
  rail invalidates chip detection and arming, because a chip that answered at
  3.3 V is not evidence of a chip at 1.8 V; loading a different image
  invalidates the preflight that judged the previous one; one arming buys
  exactly one destructive run.

  The unit and its rules are complete and tested. No button feeds it events
  yet, deliberately: wiring a safety machine into a 580 KB form one call site
  at a time produces one that is half correct, which is worse than none at all
  because operators believe it is watching. It is wired when `main.pas` is
  split into core and UI.

## 4.26.6.0 — the target-voltage selector actually changes the rail

- Selecting 1.8 V or 3.3 V did nothing at all. Two faults stacked on top of
  each other.

  The program opens the CH347 only for the duration of an operation and
  closes it immediately afterwards, so when the user clicks the selector the
  device is not open. `SupportsTargetVoltage` returned False and
  `ApplyCH347Vcc` returned without setting anything and without saying so.

  `DevClose` then wound the rail back to 1.8 V on every close, so even a
  level applied during an operation was undone the moment that operation
  finished. Between the two, the selector could never have had a visible
  effect.

  `ApplyCH347Vcc` now opens the device when it is not already open, applies
  the level, and closes only what it opened — the setting persists in the
  CH347 after close, so it still governs the next operation. `DevClose` no
  longer changes the rail at all.

  The safety default did not disappear, it moved to where the vendor keeps
  it: the hardware powers up at 1.8 V, and the program applies 1.8 V when it
  starts. A level left standing is now one the user chose, rather than one
  that leaked out of a previous job unnoticed.

- The "no chip answered, continue anyway?" dialog is gone. It fired whenever
  nothing replied to the id commands, which includes the ordinary case of an
  empty socket before a chip is seated, and it had to be dismissed every
  time while telling the user nothing the log had not already said.

  A chip id *mismatch* still asks, because erasing or writing a part that is
  not the one selected destroys data. Nothing answering cannot damage
  anything: the operation reads FF or fails on its own. The explanation and
  the too-fast-clock hint stay in the log.

## 4.26.5.0 — the activity LED lights for EEPROM too

- The activity LED works again, and now lights for I2C work as well as SPI.

  This took three attempts, and the measurement should have come first.
  Sampling GPIO4 across 400 SPI transactions returned `dir1_lvl1` four
  hundred times out of four hundred: the pin never moves on its own. The
  board does not blink the lamp from bus traffic, so software has to drive
  it, exactly as the vendor binary does from its two `CH347GPIO_Set` call
  sites.

  The original defect was never that the LED was software-driven. It was
  that only `SPIInit`/`SPIDeinit` lit it, and EEPROM runs over I2C — so
  reading an EEPROM lit nothing at all. 4.26.3.0 removed the software
  control on the mistaken belief that the hardware would take over, which
  left the lamp dark for every operation instead of just the I2C ones.

  `SetActivityLED` now drives GPIO4 through its own mask, so the LED and the
  target-voltage pin at GPIO6 can never disturb each other. It is lit from
  both `SPIInit` and `I2CInit`, cleared from both Deinits and from
  `DevClose`, and `QuiesceActivityLED` in `RunOperation` still catches
  operations that end by throwing.

- `DevOpen` no longer writes GPIO at all. The CH347T multiplexes its GPIO
  pins, and claiming one before anything has asked for it disturbed
  unrelated buses. The hardware powers up at 1.8V by itself, `ApplyCH347Vcc`
  still sets the level before every SPI operation, and `DevClose` still
  winds a raised rail back down, so nothing about the safety behaviour
  changes.

- The About box and the remaining documentation now point at
  `patnawa/Chipwright`.

## 4.26.4.0 — the voltage box no longer sits on the chip picture

- The chip picture and the log below it laid out wrongly. The target-voltage
  box added in 4.26.1.0 was placed at `Top=330` with `Height=68`, so it
  occupied 330-398 inside `GroupChipSettings` — and `ChipView`, the chip
  picture, starts at `Top=340`. The two overlapped by 58 pixels. The box was
  also 188 wide against a parent client width of 156, so it overran sideways
  as well.

  It now sits below the picture (`ChipView` ends at 570, the box starts at
  575) and is 184 wide, matching `ChipView`'s column.

- Documentation now points at `patnawa/Chipwright` following the repository
  rename.

## 4.26.3.0 — the board lights its own LED

- The green activity light on the CH347 stopped blinking during reads. That
  was a regression introduced with target-voltage support, and the fix is to
  stop touching the pin at all.

  Before that feature existed nothing ever wrote GPIO4, so the pin stayed an
  input and the board's own circuit blinked the LED from bus traffic —
  covering SPI and I2C alike, with no software involvement. `DevOpen` then
  began claiming GPIO4 as a driven output and parking it high, which
  suppressed that circuit outright.

  EEPROM reads never stood a chance either way: the software LED was only
  wired into `SPIInit`/`SPIDeinit`, and EEPROM runs over I2C.

  Checked against the hardware before changing any code — releasing GPIO4
  back to input moves the GPIO direction mask from `0x50` to `0x40` and
  leaves GPIO6 and the target voltage untouched.

  `ApplyGPIO` is now `ApplyVccGPIO` and masks GPIO6 only. The
  `SetActivityLED` override is gone; `TBaseHardware`'s no-op stands.
  `QuiesceActivityLED` stays in `RunOperation` for backends that really do
  have a software-controlled lamp. A hardware LED that already worked for
  both buses beats a software one that only knew about SPI.

- The application is now called **Chipwright**, in the window title, the
  command line, the About box, the compare report and the version resource.
  Release packages are named `Chipwright-<version>.zip`.

## 4.26.2.0 — the first release cut from the Chipwright repository

- The Linux CI suite could not compile `unittests`: `tools/build.sh` never
  listed `software/utilfunc.pas`, while the Windows list had it, and the
  metadata check only compares suite *names* — not their file lists — so the
  drift stayed invisible until the first tag build. The voltage-resolver
  tests now compile and run on both platforms.
- The release-badge check in `tools/check_project_metadata.py` still pointed
  at the old AsProgrammer-ProX repository; it now requires this repository's
  badge, matching the new front page.
- The front page caught up with the code it describes: the voltage-resolution
  section now shows all four tiers including the MX25U/MX66U name rule and
  the audited nineteen-prefix list (and why `C225` is deliberately absent),
  the on-window Target voltage box is documented, and the changelog and CI
  are linked from the badges. The stale note about a 96 MB log file in git
  history is gone together with the file itself — the repository history was
  rewritten before publication.

## 4.26.1.0 — the voltage database survives an audit of all 1751 catalog entries

- The 1.8V-family id-prefix list was checked against every entry of every
  shipped chip table, and `C225` turned out to be a trap: Macronix put the
  MX25U 1.8 V family, the 3 V MX25L1635E/1636E/3239E/6439E and the
  wide-range MX25V4035/8035 on the same `C225xx` ids. The resolver was
  reporting those 3 V parts as 1.8 V — electrically harmless (undervolting
  only mutes a chip) but wrong, and in Auto mode it would have powered them
  at a level they cannot answer at. `C225` is gone; MX25U/MX66U are now
  recognized by model name, which never collides even where the ids do.
- Ten more families that the audit proved unanimously 1.8 V joined the list:
  Micron MT25QU (`20BB`, this rescues the bare-named MT25QU256 entry) and
  MT35XU (`2C5B`), ISSI IS25WQ (`9D12`), GigaDevice GD25LF (`C863`) and
  GD25LB/LR..E (`C867`), Winbond W77Q (`EF8A`), W77T (`EF8E`) and W35T
  (`EF5B`), XMC `2044`, and Zetta ZD25LQ (`BA00`). Genuinely mixed prefixes
  (SST/Sanyo `6216`, SST/PCT `BF25`, Atmel `1F4x`, Macronix MX77 `C275`,
  wide-range GD25WQ/WB and FM25W) stay excluded on purpose.
- `tools/validate_chiplist.py` now enforces all of this on every build: each
  `vcc` attribute must be a value the application can actually parse, a name
  may not carry both 1.8V and 3.3V markers or contradict its `vcc` attribute,
  and no catalog entry may ever contradict a family on the 1.8V prefix list
  or the MX25U/MX66U name rule — so the next imported chip table cannot
  silently poison the voltage detection the CH347 guidance relies on.

## 4.26.0.0 — an on-window voltage switch, like the CH347Ⅱ board's own software

- The CH347 target voltage can now be switched right on the main window. A
  "Target voltage" box with 1.8 V / 3.3 V / Auto radio buttons appears on the
  left panel whenever the CH347 is the selected programmer — the same control
  the board vendor's own software puts on its front screen ("切换电压"),
  matched by a "Chip:" line that shows the selected chip's supply voltage the
  way the vendor shows "芯片电压". The box mirrors the existing
  Options -> SPI -> CH347 target voltage menu in both directions: clicking a
  radio applies immediately when the device is open, exactly like the menu,
  and the guidance dialogs' one-click fixes update the radios too. The chip
  drawing below slides down while the box is shown and takes the space back
  for other programmers.
- Everything that reads the chip's supply voltage now goes through the
  three-tier resolver (catalog `vcc` field, then a 1.8V/3.3V marker in the
  model name, then JEDEC ids of all-1.8 V families such as `EF60xx` W25Q..JW
  or `C225xx` MX25U). The chiplist ships a `vcc` attribute on only 5 of 658
  entries, so the chip panel, the telemetry line, the voltage warning gate's
  Auto resolution, and the Chip Doctor report were all blind to well-known
  1.8 V parts whose names don't say so. The resolver never concludes 3.3 V
  from an id — guessing high is the direction that kills chips.

## 4.25.0.0 — the CH347 probes at 1.8 V, reads the chip's voltage, and shows the way

- Read ID on a voltage-switching CH347 board now always probes at 1.8 V, the
  one level that damages no chip. The Auto voltage mode used to inherit the
  catalog voltage of whatever chip was still *selected* — a leftover 3.3 V
  profile would have put 3.3 V on an unknown, possibly 1.8 V, part in the
  socket. A menu pinned at 3.3 V is still honored, because that is the only
  way a 3.3 V-only chip that ignores 1.8 V can be detected at all; the log
  says so when it happens.
- Once a chip is identified — by Read ID, the search window, the chip menu,
  or `--chip` — the program reads its supply voltage from the catalog, shows
  it on the chip panel (`Vcc 1.8 V`) and in the log, and compares it with the
  CH347 voltage menu. A mismatch opens a dialog that offers to switch to the
  right level with one click and names the exact menu (Options -> SPI ->
  CH347 target voltage); Auto mode just reports what it will apply. The
  dangerous direction (chip 1.8 V, menu pinned 3.3 V) and the merely mute
  direction (chip 3.3 V, menu pinned 1.8 V) are told apart in plain words.
- When no chip answers at 1.8 V, the dead-socket message now explains that a
  3.3 V-only part often cannot answer at that level and offers to pin 3.3 V
  for the next attempt — while warning that a badly clipped 1.8 V chip would
  be destroyed by that, so contact should be checked first. The program never
  raises the voltage on its own.
- The 1.8 V warning gate understands the switching board: it stays silent
  when 1.8 V is what will actually be supplied, and when 3.3 V is pinned
  against a 1.8 V chip it offers "pin 1.8 V and continue" instead of the old
  external-supply lecture, which only applies to boards that cannot switch.
  Non-switching CH347 boards keep the old warning.
- The three CH347 voltage log strings added in 4.24.x are now represented in
  `en.po`, so the localization metadata check passes again.

- The CH347 SPI clock defaulted to 60 MHz, the fastest rate the chip offers.
  A clip lead, a long cable or a breadboard rarely survives that, and a bus
  that cannot keep up reads back as all FF — indistinguishable from an empty
  socket. On the reference rig a W25Q64 returned `FFFFFF` at 60 and 30 MHz and
  a clean `EF4017` at 15 MHz and below. The default is now 15 MHz, matching
  the rate the CH347 libusb bench has always used. Existing `settings.xml`
  files keep whatever rate they already recorded.
- "No chip answered" now adds a second line naming the current clock and
  pointing at the menu when the CH347 is running at 60 or 30 MHz. The old
  message only listed the socket, pin 1, the cable and the supply, which sent
  people to re-seat wiring that was never the problem.
- The CH347 backend no longer rejects a device just because `CH347GetChipType`
  answered 0. In the vendor DLL every failure path of that call returns 0 —
  a failed `DeviceIoControl` and a chip-version byte below 0x18 both land on
  the same `xor al,al` — so 0 means "a CH341, or the question did not get
  through", and the two cannot be told apart. Treating 0 as proof of a CH341
  made a genuine CH347 vanish whenever the query failed. The backend now
  rejects a device only when the USB PID in its device path positively says
  CH341, and keeps it in every ambiguous case. The path is read through the
  same DLL that opened the device, because the two vendor DLLs number their
  devices independently.

## 4.24.1.0 — CH347 is detected as a CH347, not as a CH341

- Automatic hardware detection no longer mistakes a CH347 for a CH341A. Both
  chips sit under the same WCH `CH34xPAR` driver and share one device interface
  GUID, so `CH341DLL.DLL` enumerates and happily opens a CH347 as if it were one
  of its own. Detection tries CH341 first, so a machine with only a CH347
  plugged in always settled on CH341 and never reached the CH347 backend. Each
  backend now checks what it actually opened — CH341 reads the USB PID out of
  the device path, CH347 asks `CH347GetChipType` — and hands back anything from
  the other family instead of claiming it. Vendor DLLs too old to export
  `CH347GetChipType` keep the previous behaviour.
- Both backends now release the handles they opened while scanning, so a
  rejected device does not stay claimed against the next programmer selection.
- The "install the driver" hints pointed at directories that do not ship:
  `drivers\CH341\` and `drivers\CH343\`. They now name the real installers,
  `drivers\USBCH341\CH341PAR.EXE` and `drivers\CH34X\CH34XPAR.EXE`.

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
