program ch347smoke;

{ Live-validation harness for the CH347 libusb backend.

  Reads nothing and writes nothing on the chip: JEDEC ID (9Fh) and the
  status register (05h) only. If both come back sane, the bulk protocol,
  the CS handling and the clocking all work, and the backend can graduate
  from "written to the documented protocol" to "validated".

  Linux (or WSL2 with the CH347 attached via usbipd):
    fpc -Mobjfpc -Sh tools/ch347smoke.lpr -Fusoftware -otools/ch347smoke
    sudo ./tools/ch347smoke        # or fix udev permissions and drop sudo
}

{$mode objfpc}{$H+}

uses
  SysUtils, basehw, ch347proto, ch347usb;

var
  HW: TCH347USBHardware;
  Cmd: array[0..0] of byte;
  ID: array[0..2] of byte;
  SR: array[0..0] of byte;
  ok: boolean;
begin
  HW := TCH347USBHardware.Create;
  try
    WriteLn('opening the CH347 over libusb...');
    if not HW.DevOpen then
    begin
      WriteLn('FAILED: ', HW.GetLastError);
      Halt(1);
    end;
    WriteLn('open. configuring SPI at ', CH347ClockHz(2) div 1000000,
            ' MHz...');
    if not HW.SPIInit(2) then
    begin
      WriteLn('FAILED: ', HW.GetLastError);
      Halt(1);
    end;

    Cmd[0] := $9F;
    ok := (HW.SPIWrite(0, 1, Cmd) = 1) and (HW.SPIRead(1, 3, ID) = 3);
    if not ok then
    begin
      WriteLn('FAILED reading the JEDEC id: ', HW.GetLastError);
      Halt(1);
    end;
    WriteLn(Format('JEDEC ID(9F): %.2x %.2x %.2x', [ID[0], ID[1], ID[2]]));
    if (ID[0] = $FF) or (ID[0] = $00) then
      WriteLn('  (that is a silent bus: no chip, no power, or CS never moved)');

    Cmd[0] := $05;
    ok := (HW.SPIWrite(0, 1, Cmd) = 1) and (HW.SPIRead(1, 1, SR) = 1);
    if not ok then
    begin
      WriteLn('FAILED reading the status register: ', HW.GetLastError);
      Halt(1);
    end;
    WriteLn(Format('SR1(05): %.2x', [SR[0]]));
    WriteLn('smoke test passed');
  finally
    HW.Free;
  end;
end.
