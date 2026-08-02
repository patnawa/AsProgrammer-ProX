# Contributing

Thank you for improving AsProgrammer ProX. A programmer bug can erase the only
copy of a device's firmware, so small, reviewable changes with explicit
evidence are more valuable than broad rewrites.

## Before changing code

1. Search existing issues and the [changelog](CHANGELOG.md).
2. Open an issue first for a new backend, file format, destructive operation,
   production-policy change, or incompatible chip-database change.
3. Do not use a device containing unique data as a test target. Read twice,
   save a backup off-machine, and reproduce on a sacrificial chip.

Security problems follow [SECURITY.md](SECURITY.md), not the public issue
tracker.

## Build and test

Windows uses 32-bit Lazarus 4.8/FPC 3.2.2:

```powershell
powershell -ExecutionPolicy Bypass -File tools\build.ps1
```

Linux/macOS hardware-free suites and the headless-CLI compile check use:

```bash
./tools/build.sh
```

Run `python tools/check_project_metadata.py` when changing documentation,
translations, versions, or suite registration. The complete suite catalog and
responsibilities are in [docs/testing.md](docs/testing.md).

## Change rules

- Preserve typed failure results, exact transfer-count checks, cancellation
  cleanup, identity checks, backups, and full verification. Do not turn an
  unknown capability or ambiguous chip fact into an allowed default.
- Put protocol, planning, and operation logic in LCL-free units. GUI and CLI
  surfaces should translate requests/events/results, not reimplement policy.
- Add a regression test that fails before the fix. Hardware-independent tests
  should use the existing virtual devices or transcript mocks.
- A new suite must be registered in both build scripts and inside the marked
  catalog in `docs/testing.md`.
- Keep source-compatible Free Pascal syntax and existing line endings. Avoid
  unrelated formatting changes.
- Never add firmware dumps, production images, keys, serial logs, evidence,
  proprietary chip databases, or vendor installers to a pull request.

## Adding a chip

Prefer live SFDP facts and the manufacturer's datasheet. From a detected chip:

```powershell
AsProgrammer.exe --export-chip PART_NAME --sfdp
```

A chip-support pull request should include:

- the full manufacturer part number and datasheet URL/revision;
- JEDEC ID, capacity, page size, voltage, erase sizes/opcodes, and address mode;
- the generated XML entry;
- the raw SFDP fixture and an expected `tests/sfdp/manifest.txt` line when SFDP
  exists; and
- programmer, adapter, voltage, and read-twice result used for validation.

Redact surrounding firmware. An SFDP table contains geometry, not user data.
Do not infer missing I²C/MicroWire address geometry from capacity alone.

## Translations

Catalogs live in `software/lang/*.po`; `en.po` is the coverage reference.
Preserve placeholders, accelerator markers, punctuation that carries protocol
meaning, and multiline formatting. Run the metadata checker and include its
coverage row in the pull request. Incomplete catalogs are reported but do not
block unrelated contributions.

## Pull requests

Describe:

- the failure or operator need;
- the safety invariants that remain true;
- automated tests run and their result;
- live hardware used, if any, clearly separated from simulated coverage; and
- screenshots only when visible UI behavior changed.

Keep commits small enough to review independently. Do not bundle generated
binaries. Maintainers may ask for a hardware-in-loop run before enabling a new
destructive path.
