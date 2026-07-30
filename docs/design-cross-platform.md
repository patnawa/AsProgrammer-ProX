# Design: cross-platform hardware backends

Status: in progress (task 11). Steps 1 and 2 are complete. Step 1: all four
vendor bindings (`ch347dll.pas`, `ch341dll.pas`, `D2XXUnit.pas`,
`LibUSB.pas`) are dynamic — the exe starts with no hardware DLLs present,
and a missing DLL reads as "that programmer is absent", per-DLL and even
per-export. Step 2: `prodcrypto` binds OpenSSL's libcrypto at run time and
`prodevidence`/`prodstate` have native POSIX durable writes, so the complete
stage-9 production suite runs live on Linux (`tools/build.sh`).

Step 3 is **built, pending live validation** (4.12.0.0). The split:

- `ch347proto.pas` — the CH347 bulk packet layout (config/CS/out/in and
  reply headers), pure and byte-exact-tested on both toolchains
  (`tests/ch347proto_tests.lpr`). The layout follows flashrom's
  `ch347_spi` and the kernel's `spi-ch347`, mystery bytes included.
- `ch347usb.pas` — libusb-1.0 transport implementing the `TBaseHardware`
  SPI contract (dynamic binding via `dynlibs`; missing libusb reads as
  "absent programmer"). I2C/MicroWire honestly report unsupported.
- `tools/ch347smoke.lpr` — the validation harness: JEDEC ID + status
  register, nothing destructive. `tools/build.sh` compile-checks the
  backend and harness on every Linux run.

To validate on this machine: `usbipd list; usbipd bind --busid <id>;
usbipd attach --wsl --busid <id>` on Windows, then build and run the
smoke tool inside WSL (root or a udev rule for 1a86:55db/55de). Until
that passes on real silicon, the backend must not be offered in any UI.

Remaining: wire the validated backend into a CLI-only Linux build (the
CLI currently pulls in `main.pas` and thus the LCL — the actual porting
work of step 3's second half), then step 4 (UsbAsp/AVRISP via libusb,
GUI last).

## Where the Windows coupling actually lives

The protocol layers (`spi25`, `i2c`, `microwire`, `spi45`, `spi95`), the
NOR engine stack, and every test suite already build and run on Linux —
CI proves it on every push. What does not:

1. **Hardware backends.** `ch341hw`/`ch347hw` statically import vendor
   DLLs; `ft232hhw` imports `ftd2xx.dll`; `usbasphw`/`avrisphw` use
   libusb0 (which has a Linux twin); `buzzpirathw` goes through a helper
   DLL.
2. **Crypto.** `prodcrypto` is CNG-only; non-Windows deliberately returns
   "unsupported".
3. **Durable writes.** `prodevidence.AtomicWriteDurable` uses Win32
   handles, `MoveFileExW`, and `FlushFileBuffers`.
4. **The GUI.** Lazarus LCL builds on GTK/Qt mostly for free once the
   backends do; the CLI matters more for production boxes anyway.

## Approach, in order of value per risk

1. **Dynamic binding seam.** Replace static `external 'CH347DLL.DLL'`
   imports with a small loader record resolved at runtime (`LoadLibrary`/
   `dlopen`). Windows behavior is unchanged (same DLLs); the seam is what
   makes a Linux implementation possible at all, and it also fixes the
   "exe will not start because a DLL for hardware you never touch is
   missing" caveat in the README.
2. **CH347 libusb backend.** The CH347 exposes its SPI/I2C protocol over
   plain bulk endpoints; wch ships a Linux `libch347` and the protocol is
   documented by several open implementations. One backend unit
   implementing the existing `TBaseHardware` contract against libusb-1.0,
   selected by the same seam. UsbAsp/AVRISP follow almost free via
   libusb.
3. **Crypto backend.** Keep the "no handwritten crypto" rule: on Linux,
   bind OpenSSL's `libcrypto` (EVP SHA-256 / HMAC) behind the existing
   `prodcrypto` interface. The API surface used is four functions; the
   backend choice is compile-time per platform.
4. **Durable writes.** POSIX implementation of `AtomicWriteDurable`:
   `O_TMPFILE`/temp sibling + `fsync` + `rename` + directory `fsync` —
   the same guarantees the Windows path requests.
5. **GUI last.** Only after a CLI-only Linux release has soaked.

## Testing

The seam gets a fake-loader test (missing library → typed error, not a
process-start failure). The libusb backend validates against hwtests'
transcript discipline with a capture replay; live validation needs the
user's CH347 on a Linux box. Crypto backend must pass the exact HMAC
test vectors already in stage9tests.

## Order of work

1. Loader seam for CH341/CH347/FT232H (Windows-only release, no behavior
   change, kills the missing-DLL startup failure)
2. prodcrypto OpenSSL backend + prodevidence POSIX path (stage9 suite
   then runs on Linux CI too)
3. CH347 libusb backend, CLI-only Linux build
4. UsbAsp/AVRISP via libusb; GUI port last
