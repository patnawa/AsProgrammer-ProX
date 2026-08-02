# Design: SPI NAND support with bad blocks and ECC

Status: **Phase 3 is implemented but mutation is gated pending live
validation** (4.24.0.0). Identification, factory-bad-block scanning, and
ECC-checked reads are available from the Windows command line. Erase/write
code exists only in that command-line path, is disabled by default, and has
not graduated to the GUI.

## Delivered architecture

The implementation is LCL-free below the command-line adapter:

- `nandmodel.pas` defines geometry, main-only versus raw image layouts,
  bad-block states, and typed results.
- `nandplanner.pas` creates read, erase, and program plans. The default
  mutation policy refuses a range containing a factory-bad block;
  `--nand-bad-policy skip` is an explicit request to walk around known bad
  blocks. There is no hidden remapping table.
- `nandengine.pas` scans byte 0 of the spare area on the first **two** pages of
  every block with ECC disabled, then restores the previous ECC state. Reads
  check the on-die ECC verdict on every main-area page and stop on an
  uncorrectable result.
- `spi25nandadapter.pas` owns the exact 9Fh, 13h, 03h, 02h, 10h, D8h, 0Fh,
  1Fh, FFh, and parameter-page wire framing over `TBaseHardware`. Transfers,
  WEL, feature-register writes, BUSY, P_FAIL, E_FAIL, and all-FF silent-bus
  responses are checked rather than inferred.
- `nandcatalog.pas` admits only the catalogued single-plane parts whose
  command shape matches the adapter: W25N512GV/01GV/02KV, GD5F1GQ4UA/UB,
  MX35LF1GE4AB, and TC58CVG0S3.
- `virtualspinand.pas`, `nandplanner_tests.lpr`, and
  `nandengine_tests.lpr` cover layout arithmetic, random bad-block maps,
  corrected/uncorrectable ECC, silent protection, P_FAIL/E_FAIL, cancellation,
  verification failures, redundant ONFI copies, and injected transport
  faults without requiring hardware.

## Phase 3 mutation boundary

`--nand-write FILE` and `--nand-erase` deliberately fail before hardware is
opened unless all of these conditions hold:

1. A bench that has completed the live-validation checklist sets
   `ASPROGRAMMER_NAND_LIVE_VALIDATED=1`.
2. The invocation includes `--force`.
3. `--nand-backup FILE` names a new file in an existing directory. Existing
   files are never overwritten.
4. JEDEC ID matches a supported catalog entry. An ONFI parameter page does
   not make an otherwise unknown part writable.
5. The part has a primary-source-checked parameter-page access sequence. The
   current allowlist is W25N01GV and MX35LF1GE4AB; similar vendor IDs are not
   guessed.
6. One of three redundant 256-byte ONFI copies has the required signature and
   CRC16, describes the supported single-LUN SLC shape, and exactly agrees
   with the catalog page, spare, pages-per-block, and block counts.
7. The factory marker scan succeeds. The default bad-block policy is
   `refuse`; skipping requires `--nand-bad-policy skip`.

Before either mutation, the CLI reads the main area of every good block twice
with ECC checking enabled. The byte-identical result must be atomically
published as the new recovery file before an erase or program command is
sent. That file is recovery evidence, not an automatic rollback: restoring it
after a failure remains an explicit operator action.

Raw mutation is always rejected because it could overwrite factory markers
or chip-managed ECC bytes. Main-only writes erase each selected good block,
check E_FAIL/P_FAIL, and read back every complete physical main-area page;
even the unwritten tail of a partial page must remain FFh. Erase reads every
byte of every page in each selected block with ECC disabled and reports
success only when the full main area is blank.

The read-only surface remains usable without the station gate:

```powershell
AsProgrammer.exe --nand-info --hw ch347
AsProgrammer.exe --nand-read recovery.bin --hw ch347
AsProgrammer.exe --nand-read raw.bin --nand-raw --hw ch347
```

After a station has independently satisfied the validation checklist, a
mutation invocation has this shape (do not set the environment gate merely to
bypass the refusal):

```powershell
$env:ASPROGRAMMER_NAND_LIVE_VALIDATED = '1'
AsProgrammer.exe --nand-write image.bin --nand-backup recovery.bin `
  --nand-bad-policy refuse --force --hw ch347
```

## Why NAND needs a separate path

- **Bad blocks are normal.** Factory markers must be discovered before a plan
  is built and must never be erased or programmed.
- **Spare areas carry metadata.** A typical 2 KiB page has an additional
  64/128-byte spare area containing bad-block marks and ECC state.
- **On-die ECC is stateful.** Main-area reads require a verdict after every
  page, while raw reads and blank pages require carefully scoped ECC-off
  access followed by state restoration.
- **The command model is not NOR.** NAND stages a physical page through a
  cache, then separately executes program or erase against row addresses.

## Current limits

- No GUI NAND workflow and no `chiplist.xml` `spicmd="NAND"` integration.
- No ONFI-only discovery of unknown parts. JEDEC catalog identity remains the
  first admission gate.
- Mutation is eligible only for the two catalog parts with checked ONFI access
  sequences, and it remains disabled by default until live evidence exists.
- Writes accept main-area images only; user-supplied spare/ECC data is not
  programmed.
- No wear-leveling, logical remapping, filesystem awareness, JFFS2/UBI policy,
  or automatic recovery after an interrupted job.

## Live-validation checklist

Graduating a part requires retained evidence from a socketed sacrificial chip:

1. Record programmer revision and firmware, chip marking/lot, adapter,
   software commit, USB library/driver, clock, and measured rail voltage.
2. Repeat identification and ONFI reads across disconnect/reopen cycles and
   retain the decoded geometry plus raw parameter copies.
3. Read the complete device twice, prove the dumps identical, and confirm the
   recovery file is committed before the first mutating opcode.
4. Exercise both `refuse` and `skip` policies against known marker layouts;
   confirm neither erase nor program touches a factory-bad block.
5. Erase, full blank-check, write address-sensitive and 00/55/AA patterns,
   fully verify, restart the process, and verify again.
6. Inject cancellation and transport faults at identify, ONFI, marker scan,
   backup, erase, program, verify, ECC restore, and close boundaries.
7. Restore the original recovery image and retain a final full verification.

Until that record exists, tests and successful compilation are evidence of
software behavior only—not proof that destructive commands are safe on
silicon.
