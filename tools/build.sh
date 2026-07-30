#!/usr/bin/env bash
# Runs the hardware-free test suites on Linux or macOS.
#
#   ./tools/build.sh
#
# The GUI is still Windows only: main.pas pulls in the LCL and the hardware
# backends link CH341DLL, CH347DLL and ftd2xx, which have no build here. What
# does port cleanly is everything the program's correctness actually rests on
# -- the SFDP parser, the erase planner, the protection decoder, the file
# formats, the image checks, and the SPI and I2C protocol layers driven through
# the in-memory programmer. Those are the suites this runs.
#
# Needs Free Pascal:  apt install fp-compiler   /   brew install fpc

set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

if ! command -v fpc >/dev/null 2>&1; then
  echo "FAILED: fpc is not on PATH (apt install fp-compiler, brew install fpc)" >&2
  exit 1
fi

step() { printf '\033[36m==> %s\033[0m\n' "$1"; }
die()  { printf '\033[31mFAILED: %s\033[0m\n' "$1" >&2; exit 1; }

# --- the version has to agree in both places, same rule as the Windows build ---
prox_version="$(sed -n "s/.*PROX_VERSION *= *'\([0-9.]*\)'.*/\1/p" software/appver.pas)"
[ -n "$prox_version" ] || die "no PROX_VERSION in software/appver.pas"
lpi_version="$(sed -n 's/.*ProductVersion="\([0-9.]*\)".*/\1/p' software/AsProgrammer.lpi | head -1)"
[ -n "$lpi_version" ] || die "no ProductVersion in AsProgrammer.lpi"
[ "$prox_version" = "$lpi_version" ] || \
  die "version mismatch: appver.pas says $prox_version, AsProgrammer.lpi says $lpi_version"
step "version $prox_version"

# --- chip tables ---
if command -v python3 >/dev/null 2>&1; then
  step "checking the chip tables"
  extra=()
  [ -f chiplist-flashrom.xml ] && extra+=(chiplist-flashrom.xml)
  [ -f chiplist-ezp.xml ] && extra+=(chiplist-ezp.xml)
  python3 tools/validate_chiplist.py chiplist.xml "${extra[@]}" \
    || die "the chip tables have errors"
else
  echo "    python3 not found, skipped"
fi

# --- tests ---
#
# Two directories, because the suites need different versions of spi25: the
# logic tests link the stub that serves a synthetic SFDP table, the protocol
# tests link the real unit. In one directory whichever landed last would win.
step "running tests"

run_suite() {
  local name="$1" dir="$2"; shift 2
  local with_sfdp_corpus=0
  if [ "${1:-}" = "--with-sfdp-corpus" ]; then
    with_sfdp_corpus=1
    shift
  fi
  rm -rf "$dir"; mkdir -p "$dir"
  cp "$@" "$dir/"
  if [ "$with_sfdp_corpus" -eq 1 ]; then
    [ -f tests/sfdp/manifest.txt ] || die "the SFDP corpus manifest is missing"
    mkdir -p "$dir/sfdp"
    cp tests/sfdp/* "$dir/sfdp/"
  fi
  ( cd "$dir" && fpc -Mobjfpc -Sh "$name.lpr" >/dev/null ) \
    || die "$name did not compile"
  ( cd "$dir" && "./$name" ) || die "$name reported failures"
}

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

logic="$tmp/logic"
run_suite fftest "$logic" \
  tests/fftest.lpr tests/spi25.pas software/fileformats.pas

run_suite unittests "$logic" --with-sfdp-corpus \
  tests/unittests.lpr tests/spi25.pas \
  software/sfdp.pas software/jedec.pas software/serialnum.pas \
  software/protbits.pas software/opresult.pas software/prodlog.pas \
  software/fileformats.pas software/flashops.pas software/imgcheck.pas \
  software/ifd.pas

sfdp_map="$tmp/sfdp-map"
run_suite sfdp_sector_map_tests "$sfdp_map" \
  tests/sfdp_sector_map_tests.lpr tests/spi25.pas software/sfdp.pas

hw="$tmp/hw"
run_suite hwtests "$hw" \
  tests/hwtests.lpr tests/mockhw.pas \
  software/spi25.pas software/basehw.pas software/utilfunc.pas \
  software/i2c.pas software/electricalpreflight.pas

nor="$tmp/nor"
run_suite norengine_tests "$nor" \
  tests/norengine_tests.lpr tests/virtualspi25.pas \
  software/operationmodel.pas software/norplanner.pas software/norengine.pas

eeprom="$tmp/eeprom"
run_suite eepromengine_tests "$eeprom" \
  tests/eepromengine_tests.lpr tests/virtualeeprom.pas \
  software/operationmodel.pas software/eepromengine.pas

# SPI NAND geometry and bad-block-aware planning: the arithmetic that decides
# whether a bad block is ever touched.
nand="$tmp/nand"
run_suite nandplanner_tests "$nand" \
  tests/nandplanner_tests.lpr software/nandmodel.pas software/nandplanner.pas

# The NAND executor against the virtual chip: ECC verdicts, P_FAIL/E_FAIL,
# silent protection, cancellation, the fault matrix, and the id catalog.
nand_engine="$tmp/nand-engine"
run_suite nandengine_tests "$nand_engine" \
  tests/nandengine_tests.lpr tests/virtualspinand.pas \
  software/nandmodel.pas software/nandplanner.pas \
  software/nandengine.pas software/nandcatalog.pas

adapter="$tmp/spi25-adapter"
run_suite spi25noradapter_tests "$adapter" \
  tests/adapter/spi25noradapter_tests.lpr \
  software/spi25noradapter.pas software/spi25.pas software/basehw.pas \
  software/utilfunc.pas software/electricalpreflight.pas \
  software/operationmodel.pas software/norplanner.pas software/norengine.pas

legacy="$tmp/legacy"
run_suite legacy_protocol_tests "$legacy" \
  tests/legacy_protocol/legacy_protocol_tests.lpr \
  tests/legacy_protocol/legacy_mockhw.pas \
  software/basehw.pas software/utilfunc.pas software/spi25.pas \
  software/electricalpreflight.pas \
  software/i2c.pas software/spi95.pas software/spi45.pas \
  software/microwire.pas

profile="$tmp/chip-profile"
run_suite chipprofile_tests "$profile" \
  tests/chipprofile/chipprofile_tests.lpr software/chipprofile.pas

# The production suite runs here too: prodcrypto binds OpenSSL's libcrypto at
# run time and prodevidence/prodstate have native POSIX durable writes.
production="$tmp/production"
run_suite stage9tests "$production" \
  tests/stage9tests.lpr software/prodcrypto.pas software/prodjob.pas \
  software/prodevidence.pas software/prodstate.pas \
  software/electricalpreflight.pas software/productiongate.pas

step "done -- all suites passed"
echo "    the GUI itself still needs 32 bit Lazarus on Windows; see tools/build.ps1"
