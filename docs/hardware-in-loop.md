# Hardware in the loop

The HIL workflow validates real USB transports and sacrificial chips on
dedicated self-hosted GitHub runners. It supplements virtual-device and wire-
transcript tests; it does not replace them.

## Safety model

- The weekly schedule is read-only and cannot select destructive mode.
- `tools/hil.ps1` defaults to `ReadOnly`; `tools/hil.sh` refuses destructive
  mode entirely.
- A destructive Windows run requires a manual workflow dispatch, approval of
  the `hardware-in-loop-destructive` environment, a target-specific runner, the
  exact station environment token
  `ASPX_HIL_DESTRUCTIVE=ERASE_SACRIFICIAL_FIXTURE`, an exact chip name, a
  full-chip `.bin`, and its SHA-256.
- The destructive harness takes two matching reads, keeps the backup as an
  artifact, programs and verifies the test image, then restores and verifies
  the backup. Failure to restore is a failed run, never a warning.
- Only socketed sacrificial parts containing synthetic, publishable data belong
  on these stations. Never attach a motherboard, production unit, unique
  firmware, or in-circuit clip to an automated runner.

## Runner layout

Register one runner per controlled fixture and apply exactly one hardware
label:

| Runner OS | Required label | Live path |
|---|---|---|
| Windows | `aspx-hil-ch341` | Application detect/read through CH341 DLL |
| Windows | `aspx-hil-ch347` | Application detect/read through CH347 DLL |
| Windows | `aspx-hil-ezp` | Independent `ezpsmoke` plus application detect/read |
| Linux | `aspx-hil-ch347-libusb` | `ch347smoke` plus headless CLI detect |

All runners also carry the standard `self-hosted` and OS labels. Do not place
the HIL label on a general-purpose developer runner.

Windows stations need 32-bit Lazarus 4.8 at `C:\lazarus32`, Python, `curl`,
`tar`, the approved device driver, and direct USB access. The build downloads
release runtimes only from hash-pinned sources. Linux needs FPC, OpenSSL
`libcrypto`, the libusb 1.0 runtime, and either a udev rule or a narrowly scoped
runner service account allowed to open the CH347. Do not run the whole runner
as root.

Protect the destructive GitHub environment with required reviewers. Set the
station token in the runner service's local environment, not in repository
YAML or workflow inputs. Restrict filesystem and interactive login access to
bench maintainers.

## Read-only runs

The schedule in `.github/workflows/hardware-in-loop.yml` runs every Monday.
Manual dispatch can select one target or all targets. A chip name is optional:
without it, Windows performs identity/detection only; with `-Chip`, the local
harness also saves a two-pass matching dump.

For local diagnosis:

```powershell
powershell -ExecutionPolicy Bypass -File tools\build.ps1 -Release
powershell -ExecutionPolicy Bypass -File tools\hil.ps1 `
  -Mode ReadOnly -Target ch341 -Chip W25Q64BV
```

```bash
ASPX_HIL_ARTIFACT_DIR="$PWD/hil-results" ./tools/hil.sh readonly
```

The EZP smoke tool reads USB descriptors, runs CHECK_CHIP, and, when a chip is
present, reads the first block. The CH347 smoke tool sends only JEDEC-ID (`9Fh`)
and status-register (`05h`) reads. The headless CLI detect path performs stable
identity reads. None sends write-enable, erase, or program opcodes.

## Destructive fixture cycle

Use the workflow UI, choose exactly one Windows target, choose `destructive`,
and provide:

- the exact database chip name;
- an absolute path to a station-local, full-capacity `.bin` containing only a
  synthetic test pattern; and
- the image's exact SHA-256.

Approval authorizes one run, not permanent mutation rights. The station must
also hold the local token. CH341/CH347 use transactional Smart Write and a
separate verify; EZP uses its native whole-chip erase/program/full-verify path.

Every run uses a timestamp-and-GUID artifact name, so a rerun cannot overwrite
an earlier last-known-good fixture image. If restoration fails, disconnect
power, preserve the `*-restore-backup.bin`
artifact, and investigate before reusing the fixture. Do not rerun a different
image over a failed restore.

## Current limitation

The workflow and harness are ready, but they produce real coverage only after
the repository owner registers and maintains the labeled physical runners.
An absent runner leaves a scheduled job queued; a passing compile-only CI job
is not evidence that a programmer has been validated on silicon. Record the
programmer hardware revision, driver/library version, chip lot, adapter, and
measured rail voltage in the runner inventory outside the repository.
