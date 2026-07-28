# Design: SPI NAND support with bad blocks and ECC

Status: designed, not yet implemented (task 10). This is the largest open
feature: it is the reason `SPI_NAND` entries are deliberately skipped by
the EZP importer today.

## What makes NAND different (and why the current code must not touch it)

- **Bad blocks are normal.** Factory-marked bad blocks (non-FF byte 0 of
  the spare area of a block's first page, vendor-dependent) must be
  scanned before anything else and never written or erased. A dump or
  write that ignores them corrupts data silently.
- **Spare areas.** Each page (typically 2048 B) carries a spare region
  (typically 64/128 B) holding bad-block marks and ECC. The user must
  choose raw (page+spare) or main-only images; both are legitimate.
- **On-die ECC.** Most SPI NAND (Winbond W25N, GD5F, MX35, Toshiba/Kioxia)
  has internal ECC enabled by default; the status register reports
  corrected / uncorrectable after every page read. An uncorrectable read
  must fail the dump, not return garbage bytes that look plausible.
- **Different command model.** Page-to-cache (13h) + read-from-cache
  (03h/0Bh with column address), program-load (02h/84h) + program-execute
  (10h), block erase (D8h with row address), feature registers via 0Fh/1Fh.

## Shape

Follows the proven NOR split, all LCL-free:

- `nandmodel.pas` — geometry (page, spare, pages/block, blocks), image
  layout (raw vs main-only), bad-block map type, typed outcomes reusing
  `operationmodel`.
- `nandplanner.pas` — plans reads/writes/erases over *good* blocks only;
  fails closed if the requested range cannot be satisfied without a
  skip-bad-block policy the user has not chosen (plain skip vs strict
  refuse; no remapping table in v1).
- `nandengine.pas` — executor: feature-register gate (ECC on/off as the
  job demands, block-protection bits cleared and read back), bad-block
  scan, then per-page operations with ECC status checked after every read
  and program-execute status (P_FAIL/E_FAIL) after every program/erase.
- `spi25nandadapter.pas` — exact wire framing over `TBaseHardware`, with
  the same exact-transfer discipline as the NOR adapter.
- Detection: JEDEC 9Fh (with the dummy-byte variant NAND vendors use) plus
  the ONFI-style parameter page (ECh) where present; chips land in
  `chiplist.xml` with a new `spicmd="NAND"` family carrying page/spare/
  block geometry explicitly.

## Testing

`virtualspinand.pas`: models cache, program-execute, factory bad-block
marks, injectable bit errors (corrected and uncorrectable), and P_FAIL.
Property tests: a dump over a chip with random bad blocks never reads a
bad block in skip mode and always refuses in strict mode; uncorrectable
ECC always fails the operation with the failing page address; a write plan
never touches a factory-bad block.

## Explicit v1 non-goals

Wear-leveling, logical remapping, JFFS2/UBI awareness, and writing the
spare area from user images (main-only writes compute/leave ECC to the
chip). These belong to filesystem tools, not a programmer.

## Order of work

1. `nandmodel` + `virtualspinand` + planner + suite (Linux-testable)
2. Adapter + engine, CLI `--nand-info` (scan + bad-block report, read-only)
3. Read/dump path (safest first), then erase/write
4. Chip entries for W25N01GV and GD5F1GQ4 as the first two validated parts
   (user has CH347 hardware for live validation)
