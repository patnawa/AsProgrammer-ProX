program ezpwrite;

{ Writes one image to an EZP2023+ using exactly the sequence captured from
  the vendor software, and NOTHING else -- no identification probe, no
  read-back, no drain. The point is to measure whether the write itself
  lands, without this program's own read path (which has been shown to be
  fed stale data by libusb0 on this stack) being able to lie about it.

  It prints the reply to the 0007 descriptor, which is the tell: the vendor
  gets a status packet starting 01 EF 40 17, and anything else means the
  firmware and we are out of phase.

  DESTRUCTIVE: it rewrites the whole chip.

  Build and run (32-bit), after a power cycle of the programmer:
    fpc -Twin32 -Pi386 -Mobjfpc -Sh -Fusoftware tools\ezpwrite.lpr
    ezpwrite <image> <size> <page> <id-hex>
    ezpwrite dump.bin 8388608 256 EF4017
}

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, LibUSB;

const
  EZP_VID = $1FC8;
  EZP_PID = $310B;
  EP_CMD  = USB_ENDPOINT_OUT or 2;
  EP_DATA = USB_ENDPOINT_OUT or 1;
  EP_IN   = USB_ENDPOINT_IN  or 2;
  PACKET  = 64;

var
  bus: pusb_bus;
  dev, found: pusb_device;
  h: pusb_dev_handle;
  Pkt, Reply, Buf: array of byte;
  Img: TMemoryStream;
  Size, Page, ChipID: cardinal;
  n, i: integer;
  Sent: cardinal;
  s: string;
  Detected: boolean;

procedure Fail(const Msg: string);
begin
  WriteLn('FAIL: ', Msg);
  Halt(1);
end;

//หาและเปิดอุปกรณ์หนึ่งครั้ง ตามลำดับของผู้ผลิต: เปิด -> อ่าน string
//descriptor สองอัน -> claim
function OpenOnce: pusb_dev_handle;
var
  b: pusb_bus;
  d, f: pusb_device;
  Tmp: array of byte;
begin
  Result := nil;
  usb_find_busses();
  usb_find_devices();
  f := nil;
  b := usb_get_busses();
  while Assigned(b) and (f = nil) do
  begin
    d := b^.devices;
    while Assigned(d) do
    begin
      if (d^.descriptor.idVendor = EZP_VID) and
         (d^.descriptor.idProduct = EZP_PID) then f := d;
      d := d^.next;
    end;
    b := b^.next;
  end;
  if f = nil then Exit;
  Result := usb_open(f);
  if Result = nil then Exit;
  SetLength(Tmp, 256);
  usb_control_msg(Result, USB_ENDPOINT_IN, USB_REQ_GET_DESCRIPTOR,
                  (USB_DT_STRING shl 8) or 1, 1033, Tmp[0], 256, 1000);
  usb_control_msg(Result, USB_ENDPOINT_IN, USB_REQ_GET_DESCRIPTOR,
                  (USB_DT_STRING shl 8) or 2, 1033, Tmp[0], 256, 1000);
  usb_claim_interface(Result, 0);
end;

//ส่งแพ็กเก็ตคำสั่งหนึ่งชุด ถ้าแพ็กเก็ตแรกหลังเปิดใหม่ถูกปฏิเสธ (เจอบ่อยบน
//สแต็กนี้: -5 หรือ -116) ให้ไล่กู้แล้วลองซ้ำ คืน handle ที่ใช้ได้กลับไป
function SendCmd(var Dev: pusb_dev_handle; const Cmd: array of byte): boolean;
var
  Local: array of byte;
  k: integer;
begin
  SetLength(Local, PACKET);
  FillChar(Local[0], PACKET, 0);
  for k := 0 to High(Cmd) do Local[k] := Cmd[k];

  if usb_bulk_write(Dev, EP_CMD, Local[0], PACKET, 5000) = PACKET then
    Exit(True);

  usb_set_configuration(Dev, 1);
  usb_claim_interface(Dev, 0);
  if usb_bulk_write(Dev, EP_CMD, Local[0], PACKET, 5000) = PACKET then
    Exit(True);

  usb_reset(Dev);
  usb_close(Dev);
  Sleep(1500);
  Dev := OpenOnce;
  if Dev = nil then Exit(False);
  Result := usb_bulk_write(Dev, EP_CMD, Local[0], PACKET, 5000) = PACKET;
end;

//หนึ่ง session ของ CHECK_CHIP แบบครบวงจร: เปิด -> 0009 -> อ่านคำตอบ ->
//0108 -> ปิด
//
//นี่คือขั้นที่หายไป: ซอฟต์แวร์ของผู้ผลิตทำสิ่งนี้ให้จบสองรอบก่อนจะเข้ารอบ
//เขียน เฟิร์มแวร์ไปตรวจชิปจริงตอนนี้ พอถึงรอบเขียน 0007 จึงได้คำตอบสถานะ
//(01 EF 40 17) ถ้าไม่ทำ 0007 จะได้ FF FF FF แล้วข้อมูลถูกทิ้งทั้งหมด
function PrimeCheckChip(out Detected: boolean): boolean;
var
  Dev: pusb_dev_handle;
  Rep: array of byte;
  k, m: integer;
  Line: string;
begin
  Result := False;
  Detected := False;
  Dev := OpenOnce;
  if Dev = nil then Exit;
  try
    if not SendCmd(Dev, [$00, $09]) then Exit;
    SetLength(Rep, PACKET);
    FillChar(Rep[0], PACKET, 0);
    m := usb_bulk_read(Dev, EP_IN, Rep[0], PACKET, 5000);
    Line := '';
    for k := 0 to 7 do Line := Line + IntToHex(Rep[k], 2) + ' ';
    WriteLn('  check-chip reply (', m, '): ', Line);
    Detected := (m = PACKET) and (Rep[0] = 1);
    SendCmd(Dev, [$01, $08]);
    Result := True;
  finally
    if Dev <> nil then
    begin
      usb_release_interface(Dev, 0);
      usb_close(Dev);
    end;
  end;
end;

begin
  if ParamCount < 4 then
    Fail('usage: ezpwrite <image> <size> <page> <id-hex>');
  Size := StrToInt(ParamStr(2));
  Page := StrToInt(ParamStr(3));
  ChipID := StrToInt('$' + ParamStr(4));

  Img := TMemoryStream.Create;
  Img.LoadFromFile(ParamStr(1));
  if cardinal(Img.Size) <> Size then
    Fail(Format('the image is %d bytes, the chip is %d', [Img.Size, Size]));
  WriteLn(Format('image %s: %d bytes; chip page %d, id %.6x',
                 [ParamStr(1), Img.Size, Page, ChipID]));

  if not Assigned(usb_init) then Fail('libusb0.dll is not available');
  usb_init();
  usb_find_busses();
  usb_find_devices();

  found := nil;
  bus := usb_get_busses();
  while Assigned(bus) and (found = nil) do
  begin
    dev := bus^.devices;
    while Assigned(dev) do
    begin
      if (dev^.descriptor.idVendor = EZP_VID) and
         (dev^.descriptor.idProduct = EZP_PID) then found := dev;
      dev := dev^.next;
    end;
    bus := bus^.next;
  end;
  if found = nil then Fail('no EZP2023+ on the bus');

  //ขั้นเตรียม: CHECK_CHIP ให้จบเป็น session ของตัวเอง สองรอบ เหมือนผู้ผลิต
  WriteLn('priming with check-chip sessions, the way the vendor does:');
  if not PrimeCheckChip(Detected) then Fail('the check-chip session failed');
  if not PrimeCheckChip(Detected) then Fail('the second check-chip failed');
  if Detected then
    WriteLn('  the firmware has identified the chip')
  else
    WriteLn('  WARNING: the firmware still does not report a chip');

  //รอบเขียน: session ใหม่ทั้งหมด
  h := OpenOnce;
  if h = nil then Fail('could not open the programmer for the write');

  //0007 descriptor: class 0, algorithm 0, page, delay 1000, size, chip id
  SetLength(Pkt, PACKET);
  FillChar(Pkt[0], PACKET, 0);
  Pkt[0] := $00; Pkt[1] := $07;
  Pkt[4] := byte(Page shr 8);
  Pkt[5] := byte(Page and $FF);
  Pkt[6] := $03; Pkt[7] := $E8;
  Pkt[8] := byte(Size shr 24);
  Pkt[9] := byte(Size shr 16);
  Pkt[10] := byte(Size shr 8);
  Pkt[11] := byte(Size);
  Pkt[13] := byte(ChipID shr 16);
  Pkt[14] := byte(ChipID shr 8);
  Pkt[15] := byte(ChipID);

  if not SendCmd(h, [$00, $07, 0, 0, byte(Page shr 8), byte(Page and $FF),
                     $03, $E8, byte(Size shr 24), byte(Size shr 16),
                     byte(Size shr 8), byte(Size), 0,
                     byte(ChipID shr 16), byte(ChipID shr 8), byte(ChipID)]) then
    Fail('the programmer would not take the descriptor');
  WriteLn('0007 descriptor sent');

  SetLength(Reply, PACKET);
  FillChar(Reply[0], PACKET, 0);
  n := usb_bulk_read(h, EP_IN, Reply[0], PACKET, 5000);
  s := '';
  for i := 0 to 15 do s := s + IntToHex(Reply[i], 2) + ' ';
  WriteLn('0007 reply (', n, ' bytes): ', s);
  if (n = PACKET) and (Reply[0] = 1) then
    WriteLn('  GOOD: the firmware reports a detected chip, like the vendor')
  else
    WriteLn('  BAD: the vendor sees 01 EF 40 17 here. We are out of phase, ' +
            'so this write will very likely be discarded.');

  //0005 START, no reply read (that is what the vendor does)
  FillChar(Pkt[0], PACKET, 0);
  Pkt[0] := $00; Pkt[1] := $05;
  n := usb_bulk_write(h, EP_CMD, Pkt[0], PACKET, 5000);
  WriteLn('0005 start sent -> ', n);
  if n <> PACKET then Fail('the programmer would not take the start command');

  WriteLn('streaming ', Size div 1024, ' KB in ', Page, '-byte blocks...');
  SetLength(Buf, Page);
  Img.Position := 0;
  Sent := 0;
  while Sent < Size do
  begin
    Img.ReadBuffer(Buf[0], Page);
    n := usb_bulk_write(h, EP_DATA, Buf[0], Page, 5000);
    if n <> integer(Page) then
      Fail(Format('block at %d took %d of %d bytes', [Sent, n, Page]));
    Inc(Sent, Page);
    if (Sent mod (1024 * 1024)) = 0 then
      WriteLn('  ', Sent div 1024, ' KB');
  end;

  //0108 RESET, no reply read
  FillChar(Pkt[0], PACKET, 0);
  Pkt[0] := $01; Pkt[1] := $08;
  usb_bulk_write(h, EP_CMD, Pkt[0], PACKET, 5000);

  usb_release_interface(h, 0);
  usb_close(h);
  Img.Free;
  WriteLn('the whole image was accepted. Now read the chip back with a ');
  WriteLn('separate program to find out whether it actually landed.');
end.
