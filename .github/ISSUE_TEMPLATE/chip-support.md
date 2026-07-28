---
name: Chip support / SFDP dump
about: Share a chip that works via SFDP detection so it can be added for everyone
labels: chip-support
---

<!--
The fastest way to get a chip added permanently:

    AsProgrammer.exe --sfdp --export-chip MYCHIPNAME

and attach BOTH files it writes:
  - MYCHIPNAME.export.txt  (the chiplist line)
  - MYCHIPNAME.sfdp.bin    (the raw SFDP table -- this becomes a regression
                            test, so the chip can never silently break again,
                            even for people who do not own one)
-->

**Chip marking (exactly as printed on the package):**

**JEDEC ID (from Read ID):**

**Files from `--export-chip` attached?**  yes / no

**Datasheet link (if you have one):**

**Anything unusual** (boot blocks, 1.8 V part, needed a slower clock, ...):
