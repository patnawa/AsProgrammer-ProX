#!/usr/bin/env bash
# Read-only live validation for the CH347 libusb backend. The headless CLI's
# destructive path remains separately gated until this bench is graduated.

set -euo pipefail

mode="${1:-readonly}"
case "$mode" in
  readonly) ;;
  destructive)
    echo "FAILED: Linux HIL is read-only; use the reviewed transactional Windows fixture harness" >&2
    exit 2
    ;;
  *)
    echo "usage: tools/hil.sh [readonly]" >&2
    exit 2
    ;;
esac

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
command -v fpc >/dev/null 2>&1 || {
  echo "FAILED: fpc is not on PATH" >&2
  exit 1
}

artifact_dir="${ASPX_HIL_ARTIFACT_DIR:-$root/hil-results}"
mkdir -p "$artifact_dir"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

cp tools/ch347smoke.lpr software/ch347proto.pas software/ch347usb.pas \
  software/basehw.pas software/electricalpreflight.pas "$work/"
(
  cd "$work"
  fpc -Mobjfpc -Sh ch347smoke.lpr -och347smoke >/dev/null
)

mkdir -p "$work/units"
fpc -Mobjfpc -Sh -Fusoftware -FU"$work/units" -FE"$work" \
  software/AsProgrammerCLI.lpr >/dev/null

echo "HIL mode=readonly target=ch347-libusb"
"$work/ch347smoke" 2>&1 | tee "$artifact_dir/ch347-libusb-readonly.log"
"$work/AsProgrammerCLI" --detect 2>&1 | tee -a "$artifact_dir/ch347-libusb-readonly.log"
echo "PASS: smoke and headless CLI reads completed; no write opcode was sent"
