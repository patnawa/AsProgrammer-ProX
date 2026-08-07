# Changelog

All notable changes to Chipwright are recorded here. The version in the
first entry must match `software/appver.pas`; CI enforces that invariant.

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
