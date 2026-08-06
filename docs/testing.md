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
- `hwtests`
- `hardwarecapability_tests`
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
