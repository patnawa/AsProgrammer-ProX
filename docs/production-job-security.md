# Production-job security model

This document defines the security boundary of strict production admission in
`prodjob.pas`, `prodcrypto.pas`, `chipprofile.pas`,
`electricalpreflight.pas`, `productiongate.pas`, and `prodevidence.pas`.
Those policy and artifact units remain independent of the GUI. The CLI binds
them to the same transactional Smart Write executor used by the application;
an unimplemented or uncertain hardware capability remains an admission
failure rather than being guessed.

## Artifacts and invariants

A production job is a versioned, canonical ASCII manifest. Version 1 has a
fixed field set and order, LF endings, strict unsigned decimal numbers,
uppercase hexadecimal digests, and no optional fields. Unknown, duplicated,
missing, reordered, or non-canonical fields are rejected.

Every accepted job contains:

- a SHA-256 digest of the exact image and its exact byte length;
- a SHA-256 digest of the exact canonical chip-definition bytes;
- a bounded chip address range and full-verification requirement;
- target voltage, signal-voltage, bus-speed, and open-drain requirements;
- programmer and adapter identity requirements;
- backup, UID, and independent read-pass requirements; and
- a job ID, monotonic revision field, creation time, and expiry time.

`created_utc` and `expires_utc` are unsigned seconds since
1970-01-01T00:00:00Z (Unix time), not local wall-clock text. The version-1
verifier treats both endpoints as inclusive.

`OpenVerifiedProductionImage` accepts only a safe sibling basename, rejects
Windows device names and traversal syntax, then checks both length and
SHA-256 on one handle. It returns that handle still open with write/delete
sharing denied. Production code must consume the returned stream and must not
reopen the filename after verification, which would introduce a
time-of-check/time-of-use gap. `VerifyProductionImage` is only a convenience
check for tooling.
`VerifyChipDefinitionBytes` checks the exact definition bytes that the
operation engine will use. A display name alone is not an acceptable
chip-definition identity.

The only safe job-file entry point is
`LoadAuthenticatedProductionJob`. `ParseProductionJob` is exposed for tooling
and tests, but its output remains untrusted until detached authentication has
been verified.

## Authentication mechanism

Version 1 uses detached HMAC-SHA-256:

```
format=AsProgrammer-ProX/job-auth
version=1
algorithm=HMAC-SHA256
key_id=<configured-key-id>
manifest_sha256=<uppercase SHA-256>
mac=<uppercase HMAC-SHA-256>
```

The authenticated byte sequence is:

```
"AsProgrammer-ProX/job-auth/v1" || NUL ||
key_id || NUL || canonical_manifest_bytes
```

The domain string and separators prevent the MAC from being reused as a valid
authenticator for another protocol or an ambiguous concatenation. The
manifest digest and MAC are compared without mismatch-position early exits.
Keys shorter than 32 bytes are rejected.

SHA-256 and HMAC-SHA-256 are performed by the operating system's own
maintained library: Windows CNG (`bcrypt.dll`) on Windows, OpenSSL's
`libcrypto` (loaded at run time) elsewhere. The project does not contain a
handwritten hash, MAC, signature, or public-key implementation.

### What HMAC proves

Assuming the key remains secret and Windows CNG is trustworthy, successful
verification proves that the canonical manifest was authorized by an entity
that held that key and that authenticated fields have not changed.

HMAC does **not** provide:

- confidentiality—the manifest, image, and evidence remain readable;
- public verifiability or non-repudiation;
- identity among multiple stations sharing the same key;
- protection after any verifier holding the shared key is compromised; or
- automatic replay, rollback, clone, or duplicate-unit prevention.

Every verifier with the key can also create a valid job. Where that trust is
too broad, job creation should move to an isolated service or HSM and a
reviewed public-key signature library should be introduced as a new,
versioned algorithm. Do not invent or paste a custom public-key primitive into
this code.

## Key management requirements

The HMAC key is external configuration, never a manifest field. Production
deployment must:

1. generate at least 32 random bytes with a cryptographic RNG;
2. keep the key out of source control, build artifacts, command lines,
   screenshots, evidence, and logs;
3. protect it with a machine/service identity and an OS secret facility such
   as DPAPI/Credential Manager, or preferably a hardware-backed secret store;
4. apply least-privilege ACLs to the station and evidence directories;
5. configure the expected key ID independently of the detached auth file;
6. support overlap during rotation, then revoke the old key centrally; and
7. zero caller-owned temporary key buffers when practical.

`ClearSensitiveBytes` is best effort only. Managed-language copies, swap,
debuggers, crash dumps, and a compromised process remain outside that
guarantee.

### CLI binding

A strict run supplies all of these switches together:

```
--prod-job <canonical-manifest>
--prod-auth <detached-auth-record>
--prod-key-id <independently-configured-id>
--prod-key-env <name-of-environment-variable-containing-hex-key>
--evidence-dir <durable-output-directory>
```

The key value is never accepted as a command-line argument. The named
environment variable contains a hex-encoded key of at least 32 bytes and the
caller-owned decoded buffer is cleared after admission. The manifest, rather
than an independent `--write` filename, identifies the image; programming
consumes the verified stream retained by `AdmitHMACProductionJob`. Strict
production is SPI-NOR-only and automatically uses transactional Smart Write.
It rejects combinations with `--write`, the legacy `--job`, or `--erase`.

## Required verification sequence

The local cryptographic, artifact, and electrical gates are combined in the
single `AdmitHMACProductionJob` call in `productiongate.pas`. The name is
intentional: UI and CLI surfaces must describe this mode as HMAC-authenticated,
not digitally signed. It requires the
manifest path, auth path, independently configured expected key ID and key,
trusted UTC, exact canonical chip-definition bytes, typed programmer/adapter
capabilities, and a live electrical observation. On success it returns the
authenticated job, allowed preflight report, and the same verified image
stream positioned at zero. On failure the image stream is closed and a typed
gate failure is returned; the output job is cleared to a non-valid state.
Central anti-replay, revision, revocation, and
unit-serialization checks are deliberately not represented as locally trusted
booleans; the controller must obtain those decisions from its durable
production authority.

The complete controller sequence is:

1. Read the manifest and detached auth with write sharing denied.
2. Strictly parse both canonical formats.
3. Require the independently configured key ID and verify HMAC.
4. Require `created_utc <= trusted_utc <= expires_utc`.
5. Consult durable production state and reject stale `(job_id, revision)`,
   already-consumed serials, duplicate run IDs, or revoked jobs.
6. Verify the exact chip-definition bytes.
7. Open the sibling image and verify its size and digest on the retained
   handle.
8. Obtain programmer/adapter capabilities and live observations from trusted
   hardware backends.
9. Run typed electrical preflight and stop on every issue.
10. Program from that retained image handle; do not reopen its path.
11. Perform backup, programming, full verification, UID checks, and evidence
    capture as one fail-closed operation state machine.
12. Publish the durable evidence envelope before reporting PASS. Evidence
    publication failure makes the run fail even if physical verification
    already succeeded.

Local time-window checking alone cannot stop a valid old job being replayed
within its window. Revision, revocation, unit serialization, and single-use
rules require durable MES or production-database state. A station clock also
needs an authenticated, monitored time source; setting the clock backwards
must not silently re-enable a job.

### Local durable state for a single station

For stations without an MES, `prodstate.pas` implements step 5 locally as
`consumed.log` in the evidence directory: an append-only log of passed units
`(job_id, revision, run_id, uid, utc)`, each line HMAC-SHA-256-chained to the
previous line under the station key, with the current chain head anchored in
`consumed.log.head` via the same atomic write-through install evidence uses.
Admission refuses a stale `(job_id, revision)` and a trusted time earlier
than any recorded entry (a rolled-back clock), and recording a passed unit
refuses duplicate run IDs and already-consumed chip UIDs. A PASS is not
reported until the unit is recorded; a unit that verified physically but
could not be recorded is reported as failed.

The protection is tamper-evident, not tamper-proof: every holder of the
station key can rewrite the log, and deleting both files together is
indistinguishable from a new station. Directory ACLs (append/write denied to
the operator account where the platform allows it), backup, and a central
authority remain the stronger layers; this state exists so that a single
station fails closed instead of not checking at all.

## Electrical preflight trust boundary

The electrical preflight is deterministic policy over typed facts. It rejects
unknown programmer capabilities, identity mismatches, unsupported protocols,
unsafe initial pin states, missing or unexpected adapters, unauthenticated or
invalid adapter capabilities, power-source contention, voltage uncertainty or
excess, missing open-drain support, missing/disabled current limiting
(including the external supply's own hardware limit), and unsafe clocks.

Those checks are only as trustworthy as their inputs. Capability records must
come from an approved backend/fixture mapping or authenticated device data;
operators must not be allowed to type arbitrary “known safe” values.
Voltage/external-power observations must come from live measurements taken
after connection and immediately before enabling destructive actions. The
controller must hold an exclusive programmer/fixture lease from observation
through completion, and should continuously monitor voltage/current where the
hardware supports it. Firmware-version approval belongs in the trusted
capability mapping; merely supplying a syntactically valid version string does
not approve firmware.

## Evidence durability and limitations

An evidence envelope binds an arbitrary payload to a run ID, exact length, and
a domain-separated SHA-256 over the run ID, the declared length, and the
payload together — so corruption of the header (a flipped `run_id` byte
re-attributing evidence to a different run) fails validation exactly like
payload corruption. `SaveEvidenceAtomic` uses a unique sibling temporary
file, denies sharing, writes with write-through, flushes file buffers, closes
the file, and installs it with a same-volume write-through rename. Its safe
default refuses to replace an existing run file.

A version-1 envelope prevents consumers from observing a partially written
final file and detects ordinary corruption or truncation. It does not make
evidence authentic: anyone who can edit an envelope can recalculate its
digest.

A version-2 envelope adds `auth_key_id` and `auth_mac` header fields carrying
an HMAC-SHA-256 over the canonical header under a station key, with its own
domain separator (`evidence-auth/v2`) so the MAC can never be confused with a
job-auth MAC. The payload is bound through the content digest inside the
MACed header. Strict production runs always write version-2 envelopes signed
under the same station key that verified the manifest
(`SaveSignedEvidenceAtomic`); verification requires the independently
configured key ID and rejects key-ID substitution, header tampering, and
payload tampering alike. The HMAC caveats above apply unchanged: every holder
of the key can also forge evidence, so where that trust is too broad the
envelope should additionally be uploaded to an authenticated MES. Directory
ACLs, central uniqueness, retention, backup, and audit-log immutability
remain deployment responsibilities.

The operating system and the underlying filesystem/storage device ultimately
define power-loss behavior. On Windows `MOVEFILE_WRITE_THROUGH` is requested;
on POSIX platforms the data file is fsynced, installed with `rename` (or
`link` when overwrite is refused, which fails atomically on an existing
target), and the directory is fsynced so the install itself is durable. The
unit does not claim stronger durability than the OS and hardware provide.
