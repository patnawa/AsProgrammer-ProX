# Testing

The default builds are hardware-free. They compile the real protocol and
operation units against in-memory devices, then assert exact wire transcripts,
failure cleanup, preservation, and verification behavior. A failing invariant
stops before the GUI is built.

Run the complete platform suite with:

```powershell
powershell -ExecutionPolicy Bypass -File tools\build.ps1
```

```bash
./tools/build.sh
```

The Windows build requires 32-bit Lazarus/FPC 3.2.2. The POSIX build requires
`fpc`; its production crypto tests also need the system OpenSSL `libcrypto`.

## Suite catalog

The names inside this marked block are checked against both build scripts by
`tools/check_project_metadata.py`. Add a suite here in the same change that
adds it to the builds.

<!-- suite-catalog:start -->
- `fftest`
- `unittests`
- `sfdp_sector_map_tests`
- `sfdpprofile_tests`
- `quadpolicy_tests`
- `hwtests`
- `hardwarecapability_tests`
- `simhw_tests`
- `sessionstate_tests`
- `sessionreport_tests`
- `railreport_tests`
- `signalchar_tests`
- `voltagewarning_tests`
- `validationgate_tests`
- `clocktune_tests`
- `clicontract_tests`
- `safemode_tests`
- `writeadmission_tests`
- `writejournal_tests`
- `labtools_tests`
- `norgeometrybuild_tests`
- `norengine_tests`
- `eepromengine_tests`
- `operationrunner_tests`
- `nandplanner_tests`
- `nandengine_tests`
- `nandadapter_tests`
- `chiptest_tests`
- `ch347proto_tests`
- `spi25noradapter_tests`
- `legacy_protocol_tests`
- `chipprofile_tests`
- `stage9tests`
<!-- suite-catalog:end -->

| Area | What is proved |
|---|---|
| File formats and SFDP | Intel HEX/S-record round trips, malformed input, JESD216 tables, address strategies, declared timings, and ambiguous sector-map rejection |
| Hardware protocols | Exact SPI/I²C/legacy frames, transfer limits, typed backend capabilities, live-identity gates, cleanup, and four-byte address strategies |
| NOR and EEPROM operations | Differential planning, preserved neighbor bytes, read-twice trust, cancellation boundaries, fail-at-every-call matrices, and randomized final-image invariants |
| SPI NAND | Geometry, bad-block planning, ECC verdicts, protection, status failures, cancellation, and virtual-device execution |
| Chip health | Capacity/counterfeit tests restore the original data; protocol packet layouts remain byte-exact |
| Write admission | An image ending exactly at the last byte is admitted and one byte past it is not, the fit test cannot be wrapped by an enormous buffer or a near-maximum address, word-addressed parts demand even address and length, and the refusal names the next thing to fix rather than the worst thing wrong |
| Lab tools | The I2C reserved ranges are never probed, the 7-bit to bus-byte shift is exact, a typed hex command with any malformed token is refused whole rather than partially sent, and control bytes never reach a memo raw |
| Erase geometry | Boot-block regions tile the chip exactly, the smallest *aligned* erase type wins, a type that does not divide its region is refused, a declared-but-ambiguous sector map is never replaced with a guessed uniform one, and a missing dedicated 4-byte opcode fails the build instead of silently erasing at a wrapped address |
| Read-only safe mode | Every action that can change a chip is refused while the latch is on, including status-register writes; no read is ever refused; an unclassified action defaults to destructive; and the refusal names both the operation and where the switch is |
| Machine-facing contract | Exit codes and JSON key names stay pinned across releases, every engine error maps to an action an automated caller can take, no two outcomes share a number, and an unmeasurable value serialises as null rather than zero |
| Clock tuning and connection trust | The boundary between a clock the wiring carries and one it does not is found by repetition, an all-FF reply is never mistaken for agreement, a connection fault is reported as one rather than as a speed problem, and two disagreeing reads of the same range refuse the erase |
| Target rail | Requested and measured voltage stay separate fields, unmeasurable facts never render as numbers, and a decided electrical failure blocks the bus while an uncharacterised backend only warns |
| Signal characterisation | An unmeasured programmer keeps the behaviour it had, a measurement at one rail never verifies the other, a malformed record verifies nothing, and a board whose signals do not follow its supply is reported as exactly that rather than averaged into agreement |
| Validation gates | Six of seven checklist items leaves the gate shut and names the seventh, coverage never accumulates across separate runs, and a record that cannot answer for its chip lot, clock, rail or evidence bundle counts for nothing |
| Provisional chip profiles | Every incoherent SFDP geometry falls back to read-only rather than to a guess, an impossible density/addressing combination yields no profile at all, and a synthesised name can never match the patterns the voltage inference keys on |
| Quad reads | A clear quad-enable bit means a single-bit read with no flag that changes it, continuous-read mode clocks are refused, the QE bit is located from SFDP rather than the vendor byte, and no backend claims a capability its driver does not have |
| Session report | An unrun check is never rendered as a passed one, an empty section states what its emptiness means, a refusal is an outcome rather than an absence, and a file never appears without the hash that identifies it |
| Write journal | A line without its terminating newline is work that did not happen, nothing after an unreadable line is trusted, and a resume is refused whenever the chip, capacity, image or backup has moved |
| Simulated programmer | Driven through the real protocol layer: no write-enable does nothing silently, programming only clears bits, a page program wraps within its own page, an erase aligns down to its sector, and nothing electrical is ever claimed to be measured |
| Voltage warning | Across every combination of production mode, external power, rail selectability and Auto resolution, a high rail is never approved for a 1.8 V part and a board that cannot switch is never offered a switch |
| Session admission | The ladder from Disconnected to Armed, and the revocations that matter: a rail change invalidates chip detection and arming, a fresh image invalidates the preflight, and one arming buys one destructive run |
| Production | Canonical chip profiles, HMAC-authenticated jobs, electrical admission, durable signed evidence, and anti-replay state |
| Shared operation interface | Read, Smart Write preview, and execution use one presentation-neutral request/result/event contract |

The build scripts also validate every chip-list XML file. On Linux they
compile-check `tools/ch347smoke.lpr` and the LCL-free
`software/AsProgrammerCLI.lpr` entrypoint with its real CH347/libusb and
operation-engine dependency graph. Ordinary CI does not open hardware.

## Live hardware tests

Dedicated self-hosted runners execute the separate
[`hardware-in-loop.yml`](https://github.com/patnawa/Chipwright/blob/main/.github/workflows/hardware-in-loop.yml)
workflow.
Its weekly schedule is read-only. See [Hardware in the loop](hardware-in-loop.md)
before provisioning a runner or enabling a destructive sacrificial-fixture run.

## Metadata and localization

Run:

```bash
python tools/check_project_metadata.py
```

It fails if the application, Lazarus project, README badge, and newest
changelog version disagree, or if Windows/POSIX/documented suite catalogs
drift. It prints translation coverage relative to `en.po`; incomplete
languages are visible in CI but do not block unrelated fixes.
