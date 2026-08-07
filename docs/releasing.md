# Releasing

Releases are built, tested, checksummed, attested, and published from an exact
`v<version>` tag. Do not upload a locally assembled ZIP as an official release.

## Version and documentation gate

The version source is `PROX_VERSION` in `software/appver.pas`. Before tagging:

1. set the same value in `software/AsProgrammer.lpi`;
2. add that version as the first `##` entry in `CHANGELOG.md`;
3. run `python tools/check_project_metadata.py`; and
4. run both platform build scripts or confirm their protected CI jobs pass.

The README badge reads the repository's latest published release directly, so
it contains no manually copied version. Metadata CI also enforces that Windows,
POSIX, and documented test-suite catalogs agree and publishes translation
coverage in the job summary.

## Pinned build inputs

`.github/workflows/build.yml` downloads the 32-bit Lazarus 4.8/FPC 3.2.2
installer and verifies its exact SHA-256 before installation. The release
script uses fresh private temporary directories and admits runtime files only
from these sources:

- asprogrammer-dregmod v3.17 ZIP: exact archive hash plus an exact hash for
  each of six selected DLL entries;
- repository `libusb0.dll`: exact hash and file-version check;
- official libusb 1.0.29 Windows 7z: exact archive hash and exact VS2022 x86
  DLL hash; and
- the checked-in EZP driver `SHA256SUMS.txt`, verified after packaging.

There is no fallback to a pre-existing `%TEMP%` cache and no warning-only
missing-DLL path. Download, extraction, entry selection, hash, or copy failure
stops the release.

When updating a dependency, use the primary upstream release, record its exact
immutable URL/version, independently calculate the archive and selected-file
SHA-256 values, review architecture/license changes, update
`THIRD_PARTY_NOTICES.md`, and require a second reviewer for the hash change.
Never "fix" a mismatch by copying the observed hash without establishing why
the bytes changed.

## Workflow trust boundary

Build/test jobs have `contents: read` and check out without persisted GitHub
credentials. The Windows job invokes `tools/build.ps1 -Release` once, so the
ZIP is produced by the same run that executed its tests. Linux independently
compiles/runs the platform suites and builds the headless CLI.

Only the `publish` job runs for a pushed `v*` tag. It depends on both builds,
downloads the already-tested artifact, writes `SHA256SUMS.txt`, creates a
GitHub build-provenance attestation using OIDC, and then receives the narrowly
scoped permissions needed to create the GitHub release. Third-party actions
are pinned to immutable full commit SHAs.

The workflow binds its privileged `publish` job to the `github-release`
environment. **Naming an environment in a workflow enforces nothing** — an
environment with an empty `protection_rules` list gates nothing at all, and
the publish job runs unattended. That was this repository's actual state from
2026-08-02 until 4.37.0.0, during which every tagged release published with
no review, while `check_project_metadata.py` reported "publish job is bound to
github-release" on every build.

The current configuration:

| Setting | Value | Why |
|---|---|---|
| Required reviewers | `patnawa` | the publish job waits for a deliberate approval |
| Prevent self-review | **off** | see below |
| Admins can bypass | **off** | otherwise the reviewer requirement is advisory |
| Deployment branch policy | tag `v*` only | a branch push can never reach the publish job |

Self-review is permitted, deliberately and against the earlier version of this
document. With a single maintainer, preventing self-review means the only
person who could approve is forbidden from approving, and no release can ever
be published. The rule is worth turning on the moment there is a second
maintainer, and worthless before then. A requirement nobody can satisfy is not
a stricter control, it is an absent one.

Verify all of the above with:

```bash
python tools/check_release_protection.py
```

That script asks GitHub. `check_project_metadata.py` only reads the workflow
file and now says so — it reports that the job *names* the environment, which
is a string in YAML, not a control. The distinction is the same one this
program makes about a target rail: requested is not measured.

Protect the tag pattern separately, and require reviewed pull requests and
passing build jobs for the tagged commit.

## Tagging

```bash
python tools/check_project_metadata.py
git tag -s v<version> -m "AsProgrammer ProX <version>"
git push origin v<version>
```

Replace `<version>` with the exact `PROX_VERSION`. The workflow rejects a tag that does
not exactly equal `v<PROX_VERSION>`.

After publication, download the ZIP and checksum file on a separate machine:

```bash
sha256sum -c SHA256SUMS.txt
gh attestation verify AsProgrammer-ProX-*.zip --repo patnawa/Chipwright
```

Smoke-start both executables from the extracted ZIP with no programmers
attached, then run the read-only HIL workflow. Destructive HIL remains a
separate reviewed decision.
