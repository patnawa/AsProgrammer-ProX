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
lpi_file_version="$(sed -n \
  -e 's/.*<MajorVersionNr Value="\([0-9]*\)".*/\1/p' \
  -e 's/.*<MinorVersionNr Value="\([0-9]*\)".*/.\1/p' \
  -e 's/.*<RevisionNr Value="\([0-9]*\)".*/.\1/p' \
  -e 's/.*<BuildNr Value="\([0-9]*\)".*/.\1/p' \
  software/AsProgrammer.lpi | tr -d '\n')"
[ "$prox_version" = "$lpi_version" ] && [ "$prox_version" = "$lpi_file_version" ] || \
  die "version mismatch: appver.pas says $prox_version, AsProgrammer.lpi ProductVersion says $lpi_version and FileVersion says $lpi_file_version"
step "version $prox_version"

# --- chip tables ---
if command -v python3 >/dev/null 2>&1; then
  step "checking release, suite and localization metadata"
  python3 tools/check_project_metadata.py \
    || die "project metadata has drifted"
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
  software/ifd.pas software/utilfunc.pas

sfdp_map="$tmp/sfdp-map"
run_suite sfdp_sector_map_tests "$sfdp_map" \
  tests/sfdp_sector_map_tests.lpr tests/spi25.pas software/sfdp.pas

hw="$tmp/hw"
run_suite hwtests "$hw" \
  tests/hwtests.lpr tests/mockhw.pas \
  software/spi25.pas software/basehw.pas software/utilfunc.pas \
  software/i2c.pas software/electricalpreflight.pas software/safemode.pas

capability="$tmp/hardware-capability"
run_suite hardwarecapability_tests "$capability" \
  tests/hardwarecapability_tests.lpr \
  software/basehw.pas software/electricalpreflight.pas

# The admission ladder between a button press and the bus: which facts have
# been established, and which of them a rail change or a fresh image revokes.
session="$tmp/session-state"
run_suite sessionstate_tests "$session" \
  tests/sessionstate_tests.lpr software/sessionstate.pas

# What the operator is told about the target rail, and which electrical facts
# stop bench work rather than merely warning it.
rail="$tmp/rail-report"
run_suite railreport_tests "$rail" \
  tests/railreport_tests.lpr software/railreport.pas \
  software/electricalpreflight.pas

# The one measurement the whole electrical model rests on: what a programmer
# actually drives on CS/CLK/MOSI. The assertions that matter are the refusals
# -- an unmeasured rail is never verified by a measurement at the other one.
signal="$tmp/signal-char"
run_suite signalchar_tests "$signal" \
  tests/signalchar_tests.lpr software/signalchar.pas \
  software/electricalpreflight.pas

# What it takes to release a capability that is written but unreachable. The
# assertions that matter are about partial credit: six of seven leaves the gate
# shut and names the seventh, and coverage never accumulates across runs.
gate="$tmp/validation-gate"
run_suite validationgate_tests "$gate" \
  tests/validationgate_tests.lpr software/validationgate.pas

# Choosing a clock the wiring can carry, against a fake chip with a
# configurable breaking point, and refusing to erase when the same address
# range comes back two different ways.
clock="$tmp/clock-tune"
run_suite clocktune_tests "$clock" \
  tests/clocktune_tests.lpr software/clocktune.pas

# Whether an image fits a chip at an address, and the one sentence saying why
# not. Shared by the GUI workflow strip and the command line so the two can
# never disagree about the same job.
admit="$tmp/write-admission"
run_suite writeadmission_tests "$admit" \
  tests/writeadmission_tests.lpr software/writeadmission.pas

# The decidable parts of the bench tools: which I2C addresses may be probed,
# and how a typed SPI command is parsed before it is sent.
lab="$tmp/lab-tools"
run_suite labtools_tests "$lab" \
  tests/labtools_tests.lpr software/labtools.pas

# The arithmetic that decides which blocks an erase may touch. Lifted out of
# main.pas so it can be exercised at all; a wrong block list erases data that
# was never part of the job and reports success.
geom="$tmp/nor-geometry"
run_suite norgeometrybuild_tests "$geom" \
  tests/norgeometrybuild_tests.lpr software/norgeometrybuild.pas \
  software/norplanner.pas software/operationmodel.pas \
  tests/spi25.pas software/sfdp.pas

# Describing a chip the catalogue has never heard of, from its own SFDP
# tables. Every incoherent geometry must fall back to read-only rather than to
# a guess, and no path here may narrow the voltage question.
sfdp_profile="$tmp/sfdp-profile"
run_suite sfdpprofile_tests "$sfdp_profile" \
  tests/sfdpprofile_tests.lpr software/sfdpprofile.pas \
  tests/spi25.pas software/sfdp.pas

# Whether a quad read may be used, given that setting it up is not allowed.
# The assertion that looks like a missing feature is the point: a clear
# quad-enable bit means a single-bit read, with no flag that changes it.
quad="$tmp/quad-policy"
run_suite quadpolicy_tests "$quad" \
  tests/quadpolicy_tests.lpr software/quadpolicy.pas \
  tests/spi25.pas software/sfdp.pas \
  software/basehw.pas software/electricalpreflight.pas

# The document a bench session leaves behind. Almost every assertion is about
# something it refuses to do: render an unrun check as a passed one, drop an
# empty section, or let a backup path appear without its hash.
report="$tmp/session-report"
run_suite sessionreport_tests "$report" \
  tests/sessionreport_tests.lpr software/sessionreport.pas

# What a write had done when the cable came out. The append-only rule is the
# design: a torn line loses one repeated block, never invents finished work,
# and a resume is refused outright when the chip, image or backup has moved.
journal="$tmp/write-journal"
run_suite writejournal_tests "$journal" \
  tests/writejournal_tests.lpr software/writejournal.pas

# A programmer that is not there, driven through the real spi25 protocol
# layer. The assertions that matter are where it refuses to be convenient:
# no write-enable does nothing, programming only clears bits, and a program
# past the end of a page wraps to the head of that same page.
sim="$tmp/simulated-hw"
run_suite simhw_tests "$sim" \
  tests/simhw_tests.lpr software/simhw.pas \
  software/spi25.pas software/basehw.pas software/utilfunc.pas \
  software/electricalpreflight.pas software/safemode.pas \
  software/signalchar.pas

# The last warning before a 1.8 V part meets a rail that would destroy it.
# Lifted out of a GUI function so its cases can be reached at all; the one
# that matters is an Auto rail that cannot resolve, which must warn rather
# than be mistaken for an Auto rail that happens to be right.
volt="$tmp/voltage-warning"
run_suite voltagewarning_tests "$volt" \
  tests/voltagewarning_tests.lpr software/voltagewarning.pas

# The latch that makes the program incapable of changing a chip: what it
# stops, what it must never stop, and that nothing quietly falls off the list.
safe="$tmp/safe-mode"
run_suite safemode_tests "$safe" \
  tests/safemode_tests.lpr software/safemode.pas

# The published machine-facing interface: exit codes and JSON key names that
# other people's scripts depend on, pinned so renaming one is deliberate.
contract="$tmp/cli-contract"
run_suite clicontract_tests "$contract" \
  tests/clicontract_tests.lpr software/clicontract.pas \
  software/operationmodel.pas

nor="$tmp/nor"
run_suite norengine_tests "$nor" \
  tests/norengine_tests.lpr tests/virtualspi25.pas \
  software/operationmodel.pas software/norplanner.pas software/norengine.pas

eeprom="$tmp/eeprom"
run_suite eepromengine_tests "$eeprom" \
  tests/eepromengine_tests.lpr tests/virtualeeprom.pas \
  software/operationmodel.pas software/eepromengine.pas

runner="$tmp/operation-runner"
run_suite operationrunner_tests "$runner" \
  tests/operationrunner_tests.lpr tests/virtualspi25.pas \
  software/operationmodel.pas software/norplanner.pas \
  software/norengine.pas software/operationrunner.pas

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

# Real TBaseHardware-to-NAND-device framing, including ambiguous command
# issuance, bounded status draining, and checked write-disable cleanup.
nand_adapter="$tmp/nand-adapter"
run_suite nandadapter_tests "$nand_adapter" \
  tests/nandadapter_tests.lpr tests/mockhw.pas \
  software/spi25nandadapter.pas software/nandmodel.pas \
  software/nandengine.pas software/nandplanner.pas \
  software/nandcatalog.pas software/basehw.pas \
  software/electricalpreflight.pas

# The capacity/counterfeit test engine against fake chips of every stripe.
chip_test="$tmp/chiptest"
run_suite chiptest_tests "$chip_test" \
  tests/chiptest_tests.lpr software/chiptest.pas

# CH347 bulk-protocol packet layout: byte-exact, platform-free.
ch347="$tmp/ch347proto"
run_suite ch347proto_tests "$ch347" \
  tests/ch347proto_tests.lpr software/ch347proto.pas

# The libusb transport and its smoke tool only make sense on a machine with
# libusb, so this is a compile check: the smoke run itself needs a CH347
# plugged into this box (see docs/design-cross-platform.md).
step "compiling the CH347 libusb backend and smoke tool"
smoke="$tmp/ch347smoke"
rm -rf "$smoke" && mkdir -p "$smoke"
cp tools/ch347smoke.lpr software/ch347proto.pas software/ch347usb.pas \
   software/basehw.pas software/electricalpreflight.pas "$smoke/"
(cd "$smoke" && fpc -Mobjfpc -Sh ch347smoke.lpr >/dev/null) \
  || die "the CH347 smoke tool did not compile"

# The production CLI is intentionally LCL-free. Compile the real entrypoint
# and its complete dependency graph, but do not touch hardware in ordinary CI.
step "compiling the headless Linux CLI"
headless="$tmp/headless-cli"
mkdir -p "$headless/units"
fpc -Mobjfpc -Sh -Fusoftware -FU"$headless/units" -FE"$headless" \
  software/AsProgrammerCLI.lpr >/dev/null \
  || die "the headless Linux CLI did not compile"
[ -x "$headless/AsProgrammerCLI" ] \
  || die "the headless Linux CLI executable was not produced"

# These QWord values would wrap to plausible 32-bit geometry without an
# explicit bound check. Both invocations must fail as usage before USB opens.
if "$headless/AsProgrammerCLI" --smart-preview unused.bin --size 8388608 \
    --address 0 --page-size 4294967552 --erase-size 4096 \
    --erase-opcode 20 >/dev/null 2>&1; then
  die "headless CLI admitted overflowing page geometry"
else
  code=$?
  [ "$code" -eq 2 ] || die "headless CLI returned $code for overflowing page geometry"
fi
if "$headless/AsProgrammerCLI" --smart-preview unused.bin --size 8388608 \
    --address 0 --page-size 256 --erase-size 4294971392 \
    --erase-opcode 20 >/dev/null 2>&1; then
  die "headless CLI admitted overflowing erase geometry"
else
  code=$?
  [ "$code" -eq 2 ] || die "headless CLI returned $code for overflowing erase geometry"
fi
if "$headless/AsProgrammerCLI" --detect --speeed 1 >/dev/null 2>&1; then
  die "headless CLI ignored an unknown option"
else
  code=$?
  [ "$code" -eq 2 ] || die "headless CLI returned $code for an unknown option"
fi
if "$headless/AsProgrammerCLI" --detect --detect >/dev/null 2>&1; then
  die "headless CLI accepted a duplicate option"
else
  code=$?
  [ "$code" -eq 2 ] || die "headless CLI returned $code for a duplicate option"
fi

adapter="$tmp/spi25-adapter"
run_suite spi25noradapter_tests "$adapter" \
  tests/adapter/spi25noradapter_tests.lpr \
  software/spi25noradapter.pas software/spi25.pas software/basehw.pas \
  software/utilfunc.pas software/electricalpreflight.pas software/safemode.pas \
  software/operationmodel.pas software/norplanner.pas software/norengine.pas

legacy="$tmp/legacy"
run_suite legacy_protocol_tests "$legacy" \
  tests/legacy_protocol/legacy_protocol_tests.lpr \
  tests/legacy_protocol/legacy_mockhw.pas \
  software/basehw.pas software/utilfunc.pas software/spi25.pas \
  software/electricalpreflight.pas software/safemode.pas \
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
