# Third-party notices

AsProgrammer ProX is MIT-licensed, but a runnable Windows release also contains
separately licensed runtime libraries and data files. Their inclusion does not
change the project's source-code license.

- `libusb-1.0.dll` is the official x86 Visual Studio 2022 binary from
  [libusb 1.0.29](https://github.com/libusb/libusb/releases/tag/v1.0.29),
  licensed LGPL-2.1-or-later. Corresponding source is available from that tag.
- `libusb0.dll` and the EZP driver bundle come from libusb-win32 1.4.0.2 and
  retain their upstream notices and licenses under `drivers/EZP2023Plus`.
- `CH341DLL.DLL`, `CH347DLL.DLL`, `ftd2xx.dll`, `buzzpirathlp.dll`,
  `libiconv2.dll`, and `libintl3.dll` are redistributed byte-for-byte from the
  pinned asprogrammer-dregmod v3.17 runtime archive and retain their respective
  upstream/vendor licenses.
- `chiplist-flashrom.xml` is derived from flashrom and is
  GPL-2.0-or-later. It remains a separate runtime data file and may be removed.
  Other imported chip catalogs retain the notices recorded beside their
  importers/data files.

[`vendor-manifest.json`](vendor-manifest.json) is the machine-readable version
of this list: every third-party binary with its SHA-256, its licence, and how
its origin was established. Entries marked `unrecorded` there have known bytes
and an unknown origin — no URL has been invented to fill the gap. A release ZIP
also carries a CycloneDX SBOM listing every packaged file with its hash.

Most of the driver installers that used to sit under `drivers/` are no longer
in a source checkout. They remain in git history, and the manifest records what
each one was; fetch the current version from the vendor rather than from a
clone of this repository.

See the packaged upstream readmes and repository history for attribution. Do
not assume a third-party component is MIT merely because it is in the release
ZIP.
