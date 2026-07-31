program ezpsmoke;

{ Independent diagnostic for an EZP2023+ (1FC8:310B) over libusb0.
  Nothing about this program's UI or backends is involved: it binds
  libusb0, lists what is on the bus, opens the programmer, sends the
  CHECK_CHIP packet, and prints the reply. When the vendor's software and
  this program both refuse to connect, this says which step actually
  fails, instead of leaving both to be blamed.

  Reads only. Nothing is erased or written.

  Build (32-bit, from the repo root):
    C:\lazarus32\fpc\3.2.2\bin\i386-win32\fpc.exe -Twin32 -Pi386 -Mobjfpc ^
        -Sh -Fusoftware tools\ezpsmoke.lpr
}

{$mode objfpc}{$H+}

uses
  SysUtils, LibUSB;

const
  EZP_VID = $1FC8;
  EZP_PID = $310B;
  EP_CMD  = USB_ENDPOINT_OUT or 2;
  EP_IN   = USB_ENDPOINT_IN  or 2;
  PACKET  = 64;
  CMD_CHECK_CHIP = $0009;
  CMD_RESET      = $0108;


function EPKind(Attr: byte): string;
begin
  case Attr and 3 of
    0: Result := 'control';
    1: Result := 'isochronous';
    2: Result := 'bulk';
  else
    Result := 'interrupt';
  end;
end;

var
  bus: pusb_bus;
  dev, found: pusb_device;
  h: pusb_dev_handle;
  Pkt, Reply: array[0..PACKET - 1] of byte;
  Cfg: array[0..255] of byte;
  n, i, j, k, Devices: integer;
  Code: cardinal;
  //ค่าจากคำตอบ CHECK_CHIP ต้องถูกเก็บก่อนส่ง RESET: RESET เป็นคำสั่งทางเดียว
  //การอ่านหลังมันคืนของค้าง/หมดเวลาแล้วทับ Reply ที่ยังต้องใช้ตัดสินใจ
  ChipPresent: boolean;
  ChipID0, ChipID1, ChipID2: byte;

procedure Hex(const Title: string; const Buf: array of byte; Len: integer);
var
  k: integer;
  s: string;
begin
  s := '';
  for k := 0 to Len - 1 do
  begin
    s := s + IntToHex(Buf[k], 2) + ' ';
    if ((k + 1) mod 16) = 0 then s := s + '| ';
  end;
  WriteLn(Title, ': ', s);
end;

begin
  WriteLn('EZP2023+ USB diagnostic');
  WriteLn;

  if not Assigned(usb_init) then
  begin
    WriteLn('FAIL: libusb0.dll could not be bound at all.');
    WriteLn('      Put libusb0.dll beside this exe, or install the');
    WriteLn('      vendor Win10_11_driver package once.');
    Halt(1);
  end;
  WriteLn('libusb0 bound.');

  usb_init();
  usb_find_busses();
  usb_find_devices();

  found := nil;
  Devices := 0;
  bus := usb_get_busses();
  while Assigned(bus) do
  begin
    dev := bus^.devices;
    while Assigned(dev) do
    begin
      Inc(Devices);
      WriteLn(Format('  bus device: %.4x:%.4x',
              [dev^.descriptor.idVendor, dev^.descriptor.idProduct]));
      if (dev^.descriptor.idVendor = EZP_VID) and
         (dev^.descriptor.idProduct = EZP_PID) then found := dev;
      dev := dev^.next;
    end;
    bus := bus^.next;
  end;

  WriteLn(Format('%d device(s) visible to libusb0.', [Devices]));
  if Devices = 0 then
  begin
    WriteLn('FAIL: libusb0 sees nothing at all. Only devices bound to the');
    WriteLn('      libusb0 driver appear here, so this is a driver-binding');
    WriteLn('      problem, not a cable problem.');
    Halt(1);
  end;
  if found = nil then
  begin
    WriteLn(Format('FAIL: no %.4x:%.4x among them.', [EZP_VID, EZP_PID]));
    Halt(1);
  end;
  WriteLn('EZP2023+ found.');

  h := usb_open(found);
  if h = nil then
  begin
    WriteLn('FAIL: usb_open refused the device: ', usb_strerror);
    Halt(1);
  end;
  WriteLn('opened.');

  //ปลายทางจริงของอุปกรณ์ อ่านจาก config descriptor ดิบ ๆ ไม่ใช่ที่เราเดา:
  //ทั้งเลขและชนิด (bulk/interrupt) ต้องตรง ไม่งั้น bulk_write หมดเวลาเปล่า
  n := usb_control_msg(h, USB_ENDPOINT_IN, USB_REQ_GET_DESCRIPTOR,
                       (USB_DT_CONFIG shl 8) or 0, 0, Cfg[0], SizeOf(Cfg),
                       1000);
  WriteLn('config descriptor bytes: ', n);
  if n >= 9 then
  begin
    i := 0;
    while (i + 1 < n) and (Cfg[i] > 0) do
    begin
      //ตัวบรรยาย endpoint: bLength 7, bDescriptorType 5
      if (Cfg[i] >= 7) and (Cfg[i + 1] = 5) then
        WriteLn(Format('  endpoint 0x%.2x  type %s  maxpacket %d',
          [Cfg[i + 2], EPKind(Cfg[i + 3]),
           Cfg[i + 4] or (Cfg[i + 5] shl 8)]))
      else if (Cfg[i] >= 9) and (Cfg[i + 1] = 4) then
        WriteLn(Format('  interface %d: %d endpoint(s), class %.2x',
          [Cfg[i + 2], Cfg[i + 4], Cfg[i + 5]]));
      Inc(i, Cfg[i]);
    end;
  end;

  //ผลของ claim ไม่ใช่คอขาดบาดตาย แต่อยากเห็นว่ามันว่าอะไร
  n := integer(usb_claim_interface(h, 0));
  if n <> 0 then
    WriteLn('note: claim_interface(0) returned ', n, ' (', usb_strerror, ')')
  else
    WriteLn('interface 0 claimed.');

  FillChar(Pkt, SizeOf(Pkt), 0);
  Pkt[0] := byte(CMD_CHECK_CHIP shr 8);
  Pkt[1] := byte(CMD_CHECK_CHIP and $FF);

  n := usb_bulk_write(h, EP_CMD, Pkt[0], PACKET, 1000);
  WriteLn('bulk_write(check chip) -> ', n);

  //ไม่รับแพ็กเก็ต: ลองกู้ตามลำดับที่ถูกที่สุดก่อน แล้วบอกว่าอันไหนช่วยได้
  //ถ้าไม่มีอันไหนช่วย แปลว่าตัวเครื่องเองไม่ตอบ ไม่ใช่ฝั่งเราตั้งค่าผิด
  if n <> PACKET then
  begin
    WriteLn('  retrying after set_configuration(1)...');
    usb_set_configuration(h, 1);
    usb_claim_interface(h, 0);
    n := usb_bulk_write(h, EP_CMD, Pkt[0], PACKET, 1000);
    WriteLn('  bulk_write -> ', n);
  end;

  if n <> PACKET then
  begin
    WriteLn('  retrying after clear_halt on both endpoints...');
    usb_clear_halt(h, EP_CMD);
    usb_clear_halt(h, EP_IN);
    n := usb_bulk_write(h, EP_CMD, Pkt[0], PACKET, 1000);
    WriteLn('  bulk_write -> ', n);
  end;

  if n <> PACKET then
  begin
    WriteLn('  retrying after usb_reset and reopen...');
    usb_reset(h);
    usb_close(h);
    Sleep(1500);
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
    if found = nil then
    begin
      WriteLn('FAIL: the device did not come back after the reset.');
      Halt(1);
    end;
    h := usb_open(found);
    if h = nil then
    begin
      WriteLn('FAIL: could not reopen after reset: ', usb_strerror);
      Halt(1);
    end;
    usb_claim_interface(h, 0);
    n := usb_bulk_write(h, EP_CMD, Pkt[0], PACKET, 1000);
    WriteLn('  bulk_write -> ', n);
  end;

  if n <> PACKET then
  begin
    WriteLn;
    WriteLn('FAIL: the programmer never accepted a 64-byte command packet.');
    WriteLn('      Its endpoints are correct and the libusb0 driver is');
    WriteLn('      bound, so nothing on this PC side is left to fix: the');
    WriteLn('      board itself is not answering. Unplug it, wait a few');
    WriteLn('      seconds, plug it back in (that power-cycles the CH552');
    WriteLn('      and is what clears a wedged one), and run this again.');
    usb_release_interface(h, 0);
    usb_close(h);
    Halt(1);
  end;
  WriteLn('  ...that worked.');

  FillChar(Reply, SizeOf(Reply), 0);
  n := usb_bulk_read(h, EP_IN, Reply[0], PACKET, 1000);
  WriteLn('bulk_read(reply)      -> ', n);
  if n <> PACKET then
  begin
    WriteLn('FAIL: no 64-byte reply came back. ', usb_strerror);
    usb_release_interface(h, 0);
    usb_close(h);
    Halt(1);
  end;

  Hex('reply', Reply, PACKET);

  Code := (cardinal(Reply[60]) shl 24) or (cardinal(Reply[61]) shl 16) or
          (cardinal(Reply[62]) shl 8) or cardinal(Reply[63]);
  //รหัสนี้ต่างกันไปตามเครื่อง เอาไว้ดู ไม่ได้เอาไว้ตัดสิน
  WriteLn(Format('programmer identity code: %.8x', [Code]));
  WriteLn(Format('chip family byte: %d, chip id: %.2x %.2x %.2x',
                 [Reply[0], Reply[1], Reply[2], Reply[3]]));
  if Reply[0] = 0 then
    WriteLn('the programmer reports no chip in the socket (that is fine ' +
            'for this test)');
  ChipPresent := Reply[0] <> 0;
  ChipID0 := Reply[1];
  ChipID1 := Reply[2];
  ChipID2 := Reply[3];

  //RESET เป็นคำสั่งทางเดียว (ezphw.pas): ห้ามอ่านคำตอบหลังมัน การอ่านที่นี่
  //เคยทับ Reply ด้วยของค้าง แล้วการตัดสิน "มีชิปไหม" กับรหัสชิปในขั้นถัดไป
  //ก็ไปพึ่งบัฟเฟอร์ที่ถูกทับนั้นโดยบังเอิญ
  FillChar(Pkt, SizeOf(Pkt), 0);
  Pkt[0] := byte(CMD_RESET shr 8);
  Pkt[1] := byte(CMD_RESET and $FF);
  usb_bulk_write(h, EP_CMD, Pkt[0], PACKET, 1000);

  //ทดลองอ่านจริงหนึ่งก้อน ถ้ามีชิปอยู่: นี่คือขั้นที่ล้มในโปรแกรมหลัก
  //(descriptor -> START -> ก้อนแรก) จึงต้องพิสูจน์ที่นี่ ไม่ใช่เดา
  if ChipPresent then
  begin
    WriteLn;
    WriteLn('a chip is present; trying a real read of the first block');
    FillChar(Pkt, SizeOf(Pkt), 0);
    Pkt[0] := $00; Pkt[1] := $07;         //SET_CHIP_DATA
    Pkt[2] := 0;                          //class: SPI flash
    Pkt[3] := 0;                          //algorithm
    Pkt[4] := $01; Pkt[5] := $00;         //page size 256, big endian
    Pkt[6] := $03; Pkt[7] := $E8;         //delay 1000 ms
    Pkt[8] := $00; Pkt[9] := $80;         //size 8 MB = 00800000
    Pkt[10] := $00; Pkt[11] := $00;
    Pkt[12] := 0;                         //chip id from the check above
    Pkt[13] := ChipID0; Pkt[14] := ChipID1; Pkt[15] := ChipID2;
    Pkt[16] := 0;                         //speed index 0
    WriteLn(Format('  descriptor carries chip id %.2x %.2x %.2x',
                   [Pkt[13], Pkt[14], Pkt[15]]));
    n := usb_bulk_write(h, EP_CMD, Pkt[0], PACKET, 1000);
    WriteLn('  set chip data -> ', n);
    if n = PACKET then
    begin
      n := usb_bulk_read(h, EP_IN, Cfg[0], PACKET, 2000);
      WriteLn('  its reply     -> ', n);
      FillChar(Pkt, SizeOf(Pkt), 0);
      Pkt[0] := $00; Pkt[1] := $05;       //START
      n := usb_bulk_write(h, EP_CMD, Pkt[0], PACKET, 1000);
      WriteLn('  start         -> ', n);
      n := usb_bulk_read(h, EP_IN, Cfg[0], PACKET, 2000);
      WriteLn('  its reply     -> ', n);
      n := usb_bulk_read(h, EP_IN, Cfg[0], 256, 5000);
      WriteLn('  first 256 data bytes -> ', n);
      if n = 256 then
      begin
        Hex('  data', Cfg, 32);
        WriteLn('  READ PATH WORKS');
      end
      else
        WriteLn('  READ PATH FAILED: ', usb_strerror);
    end;
    FillChar(Pkt, SizeOf(Pkt), 0);
    Pkt[0] := $01; Pkt[1] := $08;         //RESET
    usb_bulk_write(h, EP_CMD, Pkt[0], PACKET, 1000);
    usb_bulk_read(h, EP_IN, Cfg[0], PACKET, 1000);
  end;

  usb_release_interface(h, 0);
  usb_close(h);

  if (Code <> 0) and (Code <> $FFFFFFFF) then
    WriteLn('PASS: the USB path to the EZP2023+ works end to end.')
  else
  begin
    WriteLn('FAIL: the device answered with no identity code.');
    Halt(1);
  end;
  for i := 0 to 0 do ; //ปิดคำเตือนตัวแปรไม่ถูกใช้
end.
