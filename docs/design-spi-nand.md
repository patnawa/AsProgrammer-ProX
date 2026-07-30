# Design: SPI NAND support with bad blocks and ECC

Status: **phase 2 built** (4.11.0.0). On top of phase 1's `nandmodel.pas` /
`nandplanner.pas` (49 checks, 500 randomised layouts):

- `nandengine.pas` — the executor. Scans factory markers with ECC off
  (an erased page has no codeword; GD5F flags that as an ECC failure) and
  restores the previous ECC state; checks the ECC verdict after every page
  of a main-only read and fails an uncorrectable page naming block and
  page; counts corrected pages; unlocks before programming and believes
  only the read-back of the protection register; checks E_FAIL/P_FAIL
  after every erase/program; reads every programmed page back.
- `tests/virtualspinand.pas` + `tests/nandengine_tests.lpr` — the virtual
  chip models AND-programming, factory markers, injectable corrected /
  uncorrectable pages, P_FAIL/E_FAIL, silent protection (a locked chip
  ignores program/erase without raising anything — only read-back
  catches a chip that lies about unlocking), and a fail-the-Nth-call
  fault matrix. 300 randomised layouts round-trip. Both toolchains.
- `spi25nandadapter.pas` — wire framing over `TBaseHardware` (13h/03h/
  02h/10h/D8h/0Fh/1Fh/FFh/9Fh), exact-transfer discipline, all-FF status
  treated as a silent bus, WEL confirmed after WREN, feature-register
  writes read back.
- `nandcatalog.pas` — the JEDEC-ID catalog (W25N512GV/01GV/02KV,
  GD5F1GQ4UA/UB, MX35LF1GE4AB, TC58CVG0S3), matching both the with-dummy
  and no-dummy 9Fh reply shapes. Only single-plane parts whose command
  set matches the adapter's assumptions are admitted.
- CLI: `--nand-info` (identify + bad-block scan, read-only) and
  `--nand-read FILE` (dump every good block in order, skip policy, ECC
  verdict per page; `--nand-raw` for main+spare with ECC off).

Still to build (phase 3): erase/write from the CLI, GUI integration, ONFI
parameter-page detection for parts not in the catalog (needs ECC-off page
reads at address 01h), and the chiplist `spicmd="NAND"` family once the
GUI knows what to do with it. Live validation on CH347 hardware with a
W25N01GV is the gate before erase/write ships.

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
