# Security policy

## Reporting a vulnerability

Please report vulnerabilities privately through the repository's
[GitHub Security Advisories](https://github.com/patnawa/Chipwright/security/advisories/new).
Do not open a public issue for an unpatched vulnerability.

Include the affected version/commit, platform, programmer, reproduction steps,
impact, and any proposed mitigation. Remove firmware contents, production
secrets, HMAC keys, device UIDs, operator names, and evidence files. A minimal
synthetic fixture is preferred.

Maintainers will acknowledge a complete report when project availability
allows, reproduce it privately, coordinate a fix and release, then credit the
reporter unless anonymity is requested. Please do not publish details before a
fix is available.

## Supported versions

Security fixes are made on the latest release line. Older portable ZIPs do not
auto-update and should be replaced when a security release is published.

## In scope

- production-job authentication, key handling, replay controls, and evidence;
- path traversal, unsafe replacement, or arbitrary file writes;
- release-workflow or dependency-integrity bypasses;
- programmer identity/electrical checks that can be bypassed by untrusted
  input;
- silent success after failed erase, program, backup, restore, or verify;
- unsafe command-line combinations that cross a documented destructive gate;
  and
- memory corruption or code execution from chip data, image files, XML, PO,
  SFDP, or hardware replies.

Hardware damage caused solely by ignoring the documented voltage, orientation,
or sacrificial-fixture requirements is a safety/support issue rather than a
software vulnerability. A code path that defeats or misstates those safeguards
is in scope.

## Production deployment boundary

The application cannot make an operator account, station clock, filesystem,
USB stack, or shared HMAC key trustworthy. Production users must follow
[docs/production-job-security.md](docs/production-job-security.md), restrict
station access, protect keys with an OS/hardware secret store, retain off-host
evidence, and enforce central revision/revocation/serialization rules where
required.

## Release verification

Official tag releases publish `SHA256SUMS.txt` and a GitHub build-provenance
attestation. Verify the checksum before moving a ZIP to an offline station and
verify the attestation with GitHub CLI where policy requires it:

```bash
sha256sum -c SHA256SUMS.txt
gh attestation verify AsProgrammer-ProX-*.zip --repo patnawa/Chipwright
```
