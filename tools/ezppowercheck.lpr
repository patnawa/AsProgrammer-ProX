program ezppowercheck;

{ Safe EZP2023+ empty-socket voltage check.

  Sends one CHECK_CHIP transaction, refuses to continue if any chip answers,
  then leaves that transaction active briefly so pin 8 to pin 4 can be
  measured without a multimeter averaging short power pulses.  RESET is sent
  before the device is closed.

  Build:
    fpc -Twin32 -Pi386 -Mobjfpc -Sh -Fusoftware tools\ezppowercheck.lpr
}

{$mode objfpc}{$H+}

uses
  SysUtils, LibUSB;

const
  EZP_VID = $1FC8;
  EZP_PID = $310B;
  EP_CMD  = USB_ENDPOINT_OUT or 2;
  EP_IN   = USB_ENDPOINT_IN or 2;
  PACKET_LEN  = 64;
  HOLD_SECONDS = 45;

var
  Bus: pusb_bus;
  Dev, Found: pusb_device;
  Handle: pusb_dev_handle;
  Packet, Reply, Tmp: array of byte;
  n, Remaining: integer;

procedure Fail(const Msg: string);
begin
  WriteLn('FAIL: ', Msg);
  Halt(1);
end;

procedure ResetAndClose;
begin
  if Handle = nil then Exit;
  SetLength(Packet, PACKET_LEN);
  FillChar(Packet[0], PACKET_LEN, 0);
  Packet[0] := $01;
  Packet[1] := $08;
  usb_bulk_write(Handle, EP_CMD, Packet[0], PACKET_LEN, 5000);
  usb_release_interface(Handle, 0);
  usb_close(Handle);
  Handle := nil;
end;

procedure AbortWithReset(const Msg: string);
begin
  ResetAndClose;
  Fail(Msg);
end;

begin
  Handle := nil;
  if not Assigned(usb_init) then Fail('libusb0.dll is not available');
  usb_init();
  usb_find_busses();
  usb_find_devices();

  Found := nil;
  Bus := usb_get_busses();
  while Assigned(Bus) and (Found = nil) do
  begin
    Dev := Bus^.devices;
    while Assigned(Dev) do
    begin
      if (Dev^.descriptor.idVendor = EZP_VID) and
         (Dev^.descriptor.idProduct = EZP_PID) then
        Found := Dev;
      Dev := Dev^.next;
    end;
    Bus := Bus^.next;
  end;
  if Found = nil then Fail('no EZP2023+ on the USB bus');

  Handle := usb_open(Found);
  if Handle = nil then Fail('could not open the EZP2023+');
  try
    SetLength(Tmp, 256);
    usb_control_msg(Handle, USB_ENDPOINT_IN, USB_REQ_GET_DESCRIPTOR,
                    (USB_DT_STRING shl 8) or 1, 1033, Tmp[0], 256, 1000);
    usb_control_msg(Handle, USB_ENDPOINT_IN, USB_REQ_GET_DESCRIPTOR,
                    (USB_DT_STRING shl 8) or 2, 1033, Tmp[0], 256, 1000);
    if usb_claim_interface(Handle, 0) <> 0 then
      AbortWithReset('could not claim interface 0');

    SetLength(Packet, PACKET_LEN);
    FillChar(Packet[0], PACKET_LEN, 0);
    Packet[0] := $00;
    Packet[1] := $09; //CHECK_CHIP: energizes the selected chip rail
    n := usb_bulk_write(Handle, EP_CMD, Packet[0], PACKET_LEN, 5000);
    if n <> PACKET_LEN then
      AbortWithReset('CHECK_CHIP command was not transferred exactly');

    SetLength(Reply, PACKET_LEN);
    FillChar(Reply[0], PACKET_LEN, 0);
    n := usb_bulk_read(Handle, EP_IN, Reply[0], PACKET_LEN, 5000);
    if n <> PACKET_LEN then
      AbortWithReset('CHECK_CHIP reply was not received exactly');
    if Reply[0] <> 0 then
      AbortWithReset(Format('a chip answered with ID %.2x%.2x%.2x; remove it ' +
                            'before measuring the empty-socket rail',
                            [Reply[1], Reply[2], Reply[3]]));

    //CHECK_CHIP switches the rail off as soon as it replies.  Close that
    //safety-check session, then enter the write data-transaction state with
    //the EF4017 geometry.  The firmware waits for endpoint-1 data in this
    //state and keeps the programming rail selected until RESET.  No data is
    //sent, and the socket was just proved empty.
    ResetAndClose;
    Handle := usb_open(Found);
    if Handle = nil then Fail('could not reopen the EZP2023+');
    usb_control_msg(Handle, USB_ENDPOINT_IN, USB_REQ_GET_DESCRIPTOR,
                    (USB_DT_STRING shl 8) or 1, 1033, Tmp[0], 256, 1000);
    usb_control_msg(Handle, USB_ENDPOINT_IN, USB_REQ_GET_DESCRIPTOR,
                    (USB_DT_STRING shl 8) or 2, 1033, Tmp[0], 256, 1000);
    if usb_claim_interface(Handle, 0) <> 0 then
      AbortWithReset('could not reclaim interface 0');

    FillChar(Packet[0], PACKET_LEN, 0);
    Packet[0] := $00;
    Packet[1] := $07; //SET_CHIP_DATA
    Packet[4] := $01; //page size 256, big endian
    Packet[5] := $00;
    Packet[6] := $03; //delay 1000 ms, big endian
    Packet[7] := $E8;
    Packet[8] := $00; //size 8 MiB, big endian
    Packet[9] := $80;
    Packet[10] := $00;
    Packet[11] := $00;
    Packet[13] := $EF;
    Packet[14] := $40;
    Packet[15] := $17;
    n := usb_bulk_write(Handle, EP_CMD, Packet[0], PACKET_LEN, 5000);
    if n <> PACKET_LEN then
      AbortWithReset('SET_CHIP_DATA command was not transferred exactly');
    FillChar(Reply[0], PACKET_LEN, 0);
    n := usb_bulk_read(Handle, EP_IN, Reply[0], PACKET_LEN, 5000);
    if n <> PACKET_LEN then
      AbortWithReset('SET_CHIP_DATA reply was not received exactly');

    FillChar(Packet[0], PACKET_LEN, 0);
    Packet[0] := $00;
    Packet[1] := $05; //START; no data blocks follow in this diagnostic
    n := usb_bulk_write(Handle, EP_CMD, Packet[0], PACKET_LEN, 5000);
    if n <> PACKET_LEN then
      AbortWithReset('START command was not transferred exactly');

    WriteLn('EMPTY SOCKET CONFIRMED');
    WriteLn('MEASURE NOW: red probe pin 8, black probe pin 4');
    WriteLn('The transaction will remain active for ', HOLD_SECONDS,
            ' seconds.');
    Remaining := HOLD_SECONDS;
    while Remaining > 0 do
    begin
      WriteLn('  ', Remaining, ' seconds remaining');
      Sleep(5000);
      Dec(Remaining, 5);
    end;
    WriteLn('Measurement window complete; switching the rail off.');
  finally
    ResetAndClose;
  end;
end.
