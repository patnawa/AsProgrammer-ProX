unit ezphw;

// EZP2023+ (Spring 1FC8:310B, a CH552G board) over libusb0.
//
// This programmer is unlike every other backend here, and the difference
// decides what it can and cannot do. The others expose raw SPI: hand them
// opcode bytes, get the reply, and every feature of this program -- SFDP,
// protection decoding, Smart write, the chip health tests -- is built on
// that. The EZP2023+ exposes no such thing. Its firmware performs whole
// operations by itself: you send a 64-byte descriptor naming the chip
// class, an algorithm index, page size, delay, capacity, expected JEDEC id,
// clock and voltage, then say "go", and it streams the entire chip.
//
// So this backend implements the TBaseHardware SPI contract only as far as
// the firmware honestly allows:
//
//   9Fh (read JEDEC id)   the CHECK_CHIP command returns the id the
//                         programmer read itself, so identification works
//   03h (read data)       the first read of a session pulls the whole chip
//                         into memory and every 03h is served from it; the
//                         chip is read once no matter how the caller
//                         chunks it
//   everything else       refused with a message saying why, because the
//                         firmware has no way to send it
//
// That is enough for Read ID, Read, dump inspection, compare and
// verify-against-a-file. Erase and write are refused: the firmware can do
// whole-chip writes, but wiring that to this program's page-at-a-time
// write path would mean buffering a whole image and guessing when to flush
// it, and a wrong guess there costs somebody their chip. Reads first.
//
// Protocol source: the packet layout is documented by libezp2023plus
// (github.com/alexandro-45/libezp2023plus, GPL-2) and was re-checked
// against EZP2023+.Dat ver 3.0 here. This implementation is original; no
// GPL code is copied into this MIT program.

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, basehw, LibUSB, utilfunc, opthread, opresult;

const
  EZP_VID = $1FC8;
  EZP_PID = $310B;
  //ปลายทาง bulk: แพ็กเก็ตคำสั่งไป OUT|2 ข้อมูลดิบไป OUT|1 คำตอบมาจาก IN|2
  EZP_EP_CMD  = USB_ENDPOINT_OUT or 2;
  EZP_EP_DATA = USB_ENDPOINT_OUT or 1;
  EZP_EP_IN   = USB_ENDPOINT_IN  or 2;

  EZP_PACKET_LEN = 64;
  EZP_BLOCK_MIN  = 64;   //ก้อนสตรีมเล็กสุดที่เฟิร์มแวร์ใช้

  //คำสั่งในไบต์แรกสองไบต์ของแพ็กเก็ต เรียงแบบ big endian
  EZP_CMD_SET_CHIP_DATA = $0007;
  EZP_CMD_START         = $0005;
  EZP_CMD_CHECK_CHIP    = $0009;
  EZP_CMD_RESET         = $0108;

  //ท้ายแพ็กเก็ต CHECK_CHIP มีรหัสสี่ไบต์ของตัวเครื่อง ซึ่ง "ต่างกันไปตาม
  //เครื่อง": ตัวที่ไลบรารีอ้างอิงเจอคือ 9A7336BD ตัวที่ทดสอบที่นี่คือ
  //90381CBC จึงใช้ยืนยันรุ่นไม่ได้ เอาไว้แค่ดูว่ามีคนตอบจริงหรือไม่
  //(ศูนย์ล้วนหรือ FF ล้วนคือไม่มีใครตอบ) แล้วบันทึกไว้ให้คนอ่าน log เทียบ

  //ตระกูล SPI NOR ใช้ค่าชุดเดียวกันทั้ง 341 จาก 355 รายการใน EZP2023+.Dat
  //(class 0, algorithm 0, delay 1000 ms) จึงตั้งเป็นค่าตั้งต้นได้ ที่เหลือ
  //14 ตัวใช้ algorithm 1 ซึ่งต่างกันเฉพาะตอนเขียน ไม่ใช่ตอนอ่าน
  EZP_CLASS_SPI_FLASH = 0;
  EZP_ALGORITHM_SPI   = 0;
  EZP_DELAY_SPI_MS    = 1000;

type
  TEZPHardware = class(TBaseHardware)
  private
    FHandle: pusb_dev_handle;
    FOpened: boolean;
    FStrError: string;
    FSpeed: byte;
    //รหัสชิปที่เครื่องอ่านมาเอง (24 บิต) ใช้ตอบ 9Fh
    FChipID: array[0..2] of byte;
    FHaveID: boolean;
    FIdentityChecked: boolean;
    //ภาพทั้งชิปที่อ่านมาแล้วในรอบนี้ 03h ทุกครั้งเสิร์ฟจากตรงนี้
    FImage: TBytes;
    FImageValid: boolean;
    //คำสั่งล่าสุดที่รับไว้ ตั้งโดย SPIWrite แล้ว SPIRead มาใช้ต่อ
    //ต้องจำว่าเป็น 9Fh หรือ 03h แยกกัน ไม่ใช่แค่ "มีอะไรค้างอยู่":
    //ถ้าคำสั่งที่เพิ่งถูกปฏิเสธ (90h, ABh, 15h) แล้วผู้เรียกยังอ่านต่อ
    //การเสิร์ฟรหัส 9Fh ให้มันคือการกุคำตอบที่ชิปไม่ได้พูด
    FPendingRead: boolean;
    FPendingID: boolean;
    FRecovering: boolean;
    FIdentityLogged: boolean;
    FPendingAddr: cardinal;

    function FindAndOpen: boolean;
    function Recover: boolean;
    function BulkOut(Endpoint: longword; const Data: TBytes): boolean;
    function BulkIn(var Data: TBytes; Len, TimeoutMs: integer): boolean;
    function Command(Cmd: word; out Reply: TBytes): boolean;
    function CheckChip: boolean;
    function ReadWholeChip: boolean;
    function SendChipDescriptor: boolean;
  public
    constructor Create;
    destructor Destroy; override;

    //งานทั้งชิปที่เฟิร์มแวร์ทำได้เอง เรียกจากเส้นทางของตัวเองใน main
    //ไม่ใช่ผ่าน SPIWrite ทีละเพจ ซึ่งโปรโตคอลนี้ทำไม่ได้
    //ผู้เรียกต้องเปิดอุปกรณ์ไว้แล้ว และ Data ต้องยาวเท่าขนาดชิปพอดี
    function WriteWholeChip(const Data: TBytes): boolean;
    //อ่านทั้งชิปเข้า Data (ยาวเท่าขนาดชิป) ใช้ตรวจหลังเขียน
    function ReadBackWholeChip(out Data: TBytes): boolean;
    //ทิ้งภาพที่แคชไว้ บังคับให้การอ่านครั้งถัดไปไปเอาจากชิปจริง
    procedure ForgetImage;

    function GetLastError: string; override;
    function DevOpen: boolean; override;
    procedure DevClose; override;

    function SPIInit(speed: integer): boolean; override;
    procedure SPIDeinit; override;
    function SPIRead(CS: byte; BufferLen: integer;
      var buffer: array of byte): integer; override;
    function SPIWrite(CS: byte; BufferLen: integer;
      buffer: array of byte): integer; override;
    function SPIMaxTransfer: integer; override;

    procedure I2CInit; override;
    procedure I2CDeinit; override;
    function I2CReadWrite(DevAddr: byte;
      WBufferLen: integer; WBuffer: array of byte;
      RBufferLen: integer; var RBuffer: array of byte): integer; override;
    procedure I2CStart; override;
    procedure I2CStop; override;
    function I2CReadByte(ack: boolean): byte; override;
    function I2CWriteByte(data: byte): boolean; override;

    function MWInit(speed: integer): boolean; override;
    procedure MWDeinit; override;
    function MWRead(CS: byte; BufferLen: integer;
      var buffer: array of byte): integer; override;
    function MWWrite(CS: byte; BitsWrite: byte;
      buffer: array of byte): integer; override;
    function MWIsBusy: boolean; override;
  end;

implementation

uses main;

const
  TIMEOUT_MS      = 1000;   //แพ็กเก็ตคำสั่ง 64 ไบต์ ตอบทันทีหรือไม่ตอบเลย
  TIMEOUT_READ_MS = 20000;  //ก้อนข้อมูลของการอ่านทั้งชิป รอได้นานกว่า

var
  UsbInited: boolean = False;

constructor TEZPHardware.Create;
begin
  inherited Create;
  FHardwareName := 'EZP2023+';
  FHardwareID := CHW_EZP;
  FSpeed := 0;
end;

destructor TEZPHardware.Destroy;
begin
  DevClose;
  inherited Destroy;
end;

function TEZPHardware.GetLastError: string;
begin
  Result := FStrError;
end;

//หาอุปกรณ์แล้วเปิด ไม่ยุ่งกับชิปเลย ใช้ทั้งตอนเปิดครั้งแรกและตอนกู้
function TEZPHardware.FindAndOpen: boolean;
var
  bus: pusb_bus;
  dev: pusb_device;
begin
  Result := False;
  usb_find_busses();
  usb_find_devices();
  bus := usb_get_busses();
  while Assigned(bus) do
  begin
    dev := bus^.devices;
    while Assigned(dev) do
    begin
      if (dev^.descriptor.idVendor = EZP_VID) and
         (dev^.descriptor.idProduct = EZP_PID) then
      begin
        FHandle := usb_open(dev);
        if FHandle = nil then
        begin
          FStrError := 'the EZP2023+ was found but could not be opened; ' +
            'its libusb0 driver may not be installed (run the vendor''s ' +
            'Win10_11_driver installer once)';
          Exit;
        end;
        //ไม่ตั้ง configuration: บนไดรเวอร์ libusb0 ของเครื่องนี้มันไม่ช่วย
        //อะไรและบางเครื่องค้างไปเลย claim ล้มก็ไม่ใช่เรื่องคอขาด
        usb_claim_interface(FHandle, 0);
        FOpened := True;
        Exit(True);
      end;
      dev := dev^.next;
    end;
    bus := bus^.next;
  end;
  FStrError := 'no EZP2023+ found on the USB bus';
end;

//เครื่องนี้ค้างได้จริงและค้างบ่อย: เฟิร์มแวร์ CH552 ที่ถูกทิ้งคาไว้กลาง
//คำสั่งจะไม่รับ bulk อะไรอีกเลย ทั้งจากโปรแกรมนี้และจากซอฟต์แวร์ของผู้ผลิต
//วัดแล้วว่า set_configuration กับ clear_halt ไม่ช่วย แต่ usb_reset แล้ว
//เปิดใหม่ช่วยได้ จึงทำให้เป็นขั้นกู้อัตโนมัติ ไม่ใช่ให้คนไปถอดสายเอง
function TEZPHardware.Recover: boolean;
begin
  Result := False;
  if FHandle = nil then Exit;
  usb_reset(FHandle);
  usb_close(FHandle);
  FHandle := nil;
  FOpened := False;
  //ตัวเครื่องหายไปจากบัสชั่วครู่หลังรีเซ็ต ต้องรอให้มันกลับมา
  Sleep(1500);
  FImageValid := False;
  FIdentityChecked := False;
  Result := FindAndOpen;
end;

function TEZPHardware.DevOpen: boolean;
begin
  Result := False;
  if FOpened then DevClose;
  FStrError := '';

  if not Assigned(usb_open) then
  begin
    FStrError := 'libusb0.dll is not available, so no EZP2023+ can be ' +
      'opened. Put libusb0.dll next to AsProgrammer.exe (the release zip ' +
      'ships one)';
    Exit;
  end;

  if not UsbInited then
  begin
    usb_init();
    UsbInited := True;
  end;

  FImageValid := False;
  FHaveID := False;
  FIdentityChecked := False;
  FPendingRead := False;
  FPendingID := False;
  //ไม่คุยกับชิปตอนเปิด: ตัวตรวจว่ามีเครื่องเสียบอยู่เรียก DevOpen ทุก
  //สามวินาที ถ้าเปิดแล้วยิงคำสั่งด้วย หน้าต่างจะค้างเป็นจังหวะ
  Result := FindAndOpen;
end;

procedure TEZPHardware.DevClose;
begin
  if FHandle <> nil then
  begin
    usb_release_interface(FHandle, 0);
    usb_close(FHandle);
    FHandle := nil;
  end;
  FOpened := False;
  FImageValid := False;
  FImage := nil;
  FHaveID := False;
  FIdentityChecked := False;
  FPendingRead := False;
  FPendingID := False;
end;

function TEZPHardware.BulkOut(Endpoint: longword;
  const Data: TBytes): boolean;
var
  n: integer;
begin
  Result := False;
  if (not FOpened) or (Length(Data) = 0) then Exit;
  n := usb_bulk_write(FHandle, Endpoint, Data[0], Length(Data), TIMEOUT_MS);
  if n = Length(Data) then Exit(True);

  //ไม่รับคำสั่ง = เฟิร์มแวร์ค้าง กู้หนึ่งครั้งแล้วลองซ้ำ ถ้ายังไม่ได้
  //ค่อยบอกว่าเครื่องไม่ตอบ ไม่ใช่รายงานเลขติดลบดิบ ๆ ให้คนไปเดาเอง
  if not FRecovering then
  begin
    FRecovering := True;
    try
      if Recover then
      begin
        main.LogPrint('the EZP2023+ was not answering; a USB reset ' +
                      'brought it back');
        n := usb_bulk_write(FHandle, Endpoint, Data[0], Length(Data),
                            TIMEOUT_MS);
        if n = Length(Data) then Exit(True);
      end;
    finally
      FRecovering := False;
    end;
  end;

  FStrError := Format('the EZP2023+ would not accept a command even after ' +
    'a USB reset (%d of %d bytes). Unplug it, wait a few seconds and plug ' +
    'it back in: that power-cycles the CH552, which is what clears one ' +
    'that is truly stuck', [n, Length(Data)]);
end;

function TEZPHardware.BulkIn(var Data: TBytes; Len,
  TimeoutMs: integer): boolean;
var
  n: integer;
begin
  Result := False;
  SetLength(Data, Len);
  if not FOpened then Exit;
  n := usb_bulk_read(FHandle, EZP_EP_IN, Data[0], Len, longword(TimeoutMs));
  Result := n = Len;
  if not Result then
    FStrError := Format('the EZP2023+ returned %d of %d bytes', [n, Len]);
end;

//แพ็กเก็ตคำสั่งเปล่า ๆ หนึ่งชุดแล้วรอคำตอบหนึ่งชุด
function TEZPHardware.Command(Cmd: word; out Reply: TBytes): boolean;
var
  Pkt: TBytes;
begin
  Reply := nil;
  SetLength(Pkt, EZP_PACKET_LEN);
  FillByte(Pkt[0], EZP_PACKET_LEN, 0);
  //big endian ตามที่เฟิร์มแวร์คาด
  Pkt[0] := byte(Cmd shr 8);
  Pkt[1] := byte(Cmd);
  Result := BulkOut(EZP_EP_CMD, Pkt) and
            BulkIn(Reply, EZP_PACKET_LEN, TIMEOUT_MS);
end;

//CHECK_CHIP: ยืนยันตัวเครื่อง และคายรหัส JEDEC ของชิปในซ็อกเก็ตมาให้ด้วย
//เรียกครั้งแรกที่มีคนต้องใช้ ไม่ใช่ตอนเปิดอุปกรณ์
function TEZPHardware.CheckChip: boolean;
var
  Reply, Dummy: TBytes;
  Code: cardinal;
begin
  Result := False;
  if not Command(EZP_CMD_CHECK_CHIP, Reply) then Exit;

  Code := (cardinal(Reply[60]) shl 24) or (cardinal(Reply[61]) shl 16) or
          (cardinal(Reply[62]) shl 8) or cardinal(Reply[63]);
  //รหัสนี้ต่างกันไปตามเครื่อง (เห็นมาแล้ว 9A7336BD และ 90381CBC) เอามา
  //ตัดสินรุ่นไม่ได้ ที่ตัดสินได้คือ "มีคนตอบไหม": ศูนย์ล้วนหรือ FF ล้วน
  //คือไม่มี
  if (Code = 0) or (Code = $FFFFFFFF) then
  begin
    FStrError := 'the device at 1FC8:310B answered with no identity code ' +
      'at all, so it is not an EZP2023+ that this backend understands';
    Exit;
  end;
  if not FIdentityLogged then
  begin
    FIdentityLogged := True;
    main.LogPrint(Format('EZP2023+ identity code %.8x', [Code]));
  end;

  //ไบต์ 0 คือชนิดตระกูล (บวกหนึ่ง) สามไบต์ถัดไปคือรหัส 9Fh ของชิป
  //ศูนย์แปลว่าไม่มีชิปตอบ ซึ่งไม่ใช่ความผิดของเครื่อง
  FHaveID := Reply[0] <> 0;
  FChipID[0] := Reply[1];
  FChipID[1] := Reply[2];
  FChipID[2] := Reply[3];

  Command(EZP_CMD_RESET, Dummy);
  FIdentityChecked := True;
  Result := True;
end;

//แพ็กเก็ตบอกชิป ใช้เหมือนกันทั้งอ่านและเขียน: class/algorithm/delay เป็น
//ค่าของตระกูล SPI NOR ขนาดกับเพจมาจากชิปที่เลือกไว้
function TEZPHardware.SendChipDescriptor: boolean;
var
  Pkt, Reply: TBytes;
  Size, Page: cardinal;
begin
  Result := False;
  Size := main.CurrentICParam.Size;
  Page := main.CurrentICParam.Page;
  if (Size = 0) or (Page = 0) then
  begin
    FStrError := 'the EZP2023+ needs the chip size and page size first: ' +
      'press Read ID, or pick the chip from the list';
    Exit;
  end;
  if (Size mod Page) <> 0 then
  begin
    FStrError := 'the EZP2023+ works in whole pages only';
    Exit;
  end;

  //เฟิร์มแวร์เทียบรหัสชิปในแพ็กเก็ตกับของจริงก่อนลงมือ ทุกงานเปิด session
  //ใหม่ (ตัวเรียกเปิด-ปิดอุปกรณ์ต่อหนึ่งงาน) รหัสที่ได้จากตอนกด Read ID
  //จึงไม่อยู่แล้ว ถ้าส่งศูนย์ไปมันเงียบและงานล้มที่ไบต์แรก
  if not FIdentityChecked then
    if not CheckChip then Exit;
  SetLength(Pkt, EZP_PACKET_LEN);
  FillByte(Pkt[0], EZP_PACKET_LEN, 0);
  Pkt[0] := byte(EZP_CMD_SET_CHIP_DATA shr 8);
  Pkt[1] := byte(EZP_CMD_SET_CHIP_DATA);
  Pkt[2] := EZP_CLASS_SPI_FLASH;
  Pkt[3] := EZP_ALGORITHM_SPI;
  Pkt[4] := byte(Page shr 8);              //flash_page_size, big endian
  Pkt[5] := byte(Page);
  Pkt[6] := byte(EZP_DELAY_SPI_MS shr 8);  //delay
  Pkt[7] := byte(EZP_DELAY_SPI_MS and $FF);
  Pkt[8] := byte(Size shr 24);             //flash_size
  Pkt[9] := byte(Size shr 16);
  Pkt[10] := byte(Size shr 8);
  Pkt[11] := byte(Size);
  if FHaveID then                          //chip_id ที่เครื่องอ่านมาเอง
  begin
    Pkt[12] := 0;
    Pkt[13] := FChipID[0];
    Pkt[14] := FChipID[1];
    Pkt[15] := FChipID[2];
  end;
  Pkt[16] := FSpeed;
  //Pkt[28] คือ voltage: ศูนย์ = ราง 3.3 V ซึ่งเป็นค่าของ SPI NOR ทั้งวงศ์

  if not BulkOut(EZP_EP_CMD, Pkt) then Exit;
  Result := BulkIn(Reply, EZP_PACKET_LEN, TIMEOUT_MS);
end;

//อ่านทั้งชิปเข้าหน่วยความจำครั้งเดียวต่อรอบ
function TEZPHardware.ReadWholeChip: boolean;
var
  Reply, Block: TBytes;
  Size, Page, BlockLen, Got: cardinal;
begin
  Result := False;
  Size := main.CurrentICParam.Size;
  Page := main.CurrentICParam.Page;
  if not SendChipDescriptor then Exit;

  if not Command(EZP_CMD_START, Reply) then Exit;

  BlockLen := Page;
  if BlockLen < EZP_BLOCK_MIN then BlockLen := EZP_BLOCK_MIN;

  SetLength(FImage, Size);
  Got := 0;
  while Got < Size do
  begin
    if not BulkIn(Block, integer(BlockLen), TIMEOUT_READ_MS) then
    begin
      FImage := nil;
      Exit;
    end;
    Move(Block[0], FImage[Got], BlockLen);
    Inc(Got, BlockLen);
    //ผู้ใช้ต้องยกเลิกได้ และหน้าต่างต้องไม่ค้างระหว่างอ่านทั้งชิป
    OpProcessMessages;
    if main.UserCancel then
    begin
      FStrError := 'cancelled while the EZP2023+ was streaming the chip';
      FImage := nil;
      Command(EZP_CMD_RESET, Reply);
      Exit;
    end;
  end;

  Command(EZP_CMD_RESET, Reply);
  FImageValid := True;
  Result := True;
end;

function TEZPHardware.SPIInit(speed: integer): boolean;
begin
  //เครื่องรับความเร็วเป็นดัชนี 0..5 (12 MHz ลงไปถึง 375 kHz) ในแพ็กเก็ต
  //บอกชิป ไม่ใช่คำสั่งแยก จึงแค่จำไว้
  if (speed >= 0) and (speed <= 5) then FSpeed := byte(speed)
  else FSpeed := 0;
  //ชิปอาจถูกสลับตัวระหว่างรอบ ภาพที่แคชไว้จึงหมดอายุเมื่อเริ่มรอบใหม่
  FImageValid := False;
  Result := FOpened;
end;

procedure TEZPHardware.SPIDeinit;
begin
  FPendingRead := False;
end;

function TEZPHardware.SPIMaxTransfer: integer;
begin
  //เสิร์ฟจากภาพในหน่วยความจำ ไม่มีเพดานของสายจริงมาเกี่ยว
  Result := 65535;
end;

//ฝั่งเขียน: รับได้แค่ opcode ที่เฟิร์มแวร์ทำได้จริง
function TEZPHardware.SPIWrite(CS: byte; BufferLen: integer;
  buffer: array of byte): integer;
begin
  Result := -1;
  if not FOpened then Exit;
  if (BufferLen <= 0) or (BufferLen > Length(buffer)) then Exit;

  case buffer[0] of
    $9F:
      begin
        //ถามเครื่องตอนนี้ถ้ายังไม่เคยถาม
        FPendingRead := False;
        FPendingID := True;
        if not FIdentityChecked then
          if not CheckChip then Exit;
        Exit(BufferLen);
      end;
    $03, $0B:
      begin
        //03h A2 A1 A0 (0Bh มี dummy ต่อท้ายอีกไบต์) จำแอดเดรสไว้ให้ SPIRead
        if BufferLen < 4 then Exit;
        FPendingAddr := (cardinal(buffer[1]) shl 16) or
                        (cardinal(buffer[2]) shl 8) or cardinal(buffer[3]);
        FPendingRead := True;
        FPendingID := False;
        Exit(BufferLen);
      end;
  end;

  FPendingRead := False;
  FPendingID := False;
  FStrError := Format('the EZP2023+ firmware cannot send SPI command %.2xh. ' +
    'It only exposes whole-chip operations, so identification and reading ' +
    'work but nothing that needs raw SPI does', [buffer[0]]);
end;

function TEZPHardware.SPIRead(CS: byte; BufferLen: integer;
  var buffer: array of byte): integer;
begin
  Result := -1;
  if not FOpened then Exit;
  if (BufferLen <= 0) or (BufferLen > Length(buffer)) then Exit;

  //คำตอบของ 9Fh: สามไบต์ที่เครื่องอ่านมาเอง
  if FPendingID then
  begin
    FPendingID := False;
    if not FHaveID then
    begin
      FStrError := 'the EZP2023+ reports no chip in the socket';
      Exit;
    end;
    if BufferLen > 3 then Exit;
    Move(FChipID[0], buffer[0], BufferLen);
    Exit(BufferLen);
  end;

  //ไม่มีคำสั่งที่เรารับไว้ค้างอยู่: อ่านลอย ๆ ไม่มีคำตอบให้ ต้องบอกว่าไม่มี
  //ไม่ใช่หยิบอะไรก็ได้มาตอบ
  if not FPendingRead then
  begin
    FStrError := 'the EZP2023+ has no reply pending: the command before ' +
      'this read was one its firmware cannot send';
    Exit;
  end;

  //คำตอบของ 03h: เสิร์ฟจากภาพทั้งชิป อ่านจากตัวชิปครั้งเดียวต่อรอบ
  if not FImageValid then
    if not ReadWholeChip then
    begin
      //ผู้เรียกจะพิมพ์ข้อความกลาง ๆ ของตัวเอง ("short read: -1 of 2048")
      //ซึ่งไม่ได้บอกอะไรเลย เหตุผลจริงอยู่ที่นี่ ต้องพ่นออกไปด้วย
      if FStrError <> '' then main.LogPrint('EZP2023+: ' + FStrError);
      Exit;
    end;

  if QWord(FPendingAddr) + QWord(BufferLen) > QWord(Length(FImage)) then
  begin
    FStrError := Format('the EZP2023+ read stops at the chip size: ' +
      '0x%.6x + %d is past %d bytes',
      [FPendingAddr, BufferLen, Length(FImage)]);
    Exit;
  end;

  Move(FImage[FPendingAddr], buffer[0], BufferLen);
  FPendingRead := False;
  Result := BufferLen;
end;

procedure TEZPHardware.ForgetImage;
begin
  FImageValid := False;
  FImage := nil;
end;

function TEZPHardware.ReadBackWholeChip(out Data: TBytes): boolean;
begin
  Data := nil;
  //บังคับอ่านจากชิปจริง ไม่ใช่ภาพที่ค้างอยู่ก่อนเขียน
  ForgetImage;
  Result := ReadWholeChip;
  if Result then Data := Copy(FImage, 0, Length(FImage));
end;

//เขียนทั้งชิป: เฟิร์มแวร์จัดการลบและเขียนตามอัลกอริทึมของมันเอง เราแค่
//ป้อนภาพให้ครบ ลำดับต่างจากทางอ่านสองจุด และทั้งสองจุดสำคัญ: หลัง START
//ไม่มีคำตอบกลับ (รออยู่ก็ค้าง) และก้อนข้อมูลไปที่ปลายทาง OUT|1 ไม่ใช่ OUT|2
function TEZPHardware.WriteWholeChip(const Data: TBytes): boolean;
var
  Reply, Block: TBytes;
  Size, Page, BlockLen, Sent: cardinal;
  Pkt: TBytes;
begin
  Result := False;
  if not FOpened then
  begin
    FStrError := 'the EZP2023+ is not open';
    Exit;
  end;
  Size := main.CurrentICParam.Size;
  Page := main.CurrentICParam.Page;
  if cardinal(Length(Data)) <> Size then
  begin
    FStrError := Format('the EZP2023+ writes the whole chip at once, so the ' +
      'image must be exactly %d bytes; this one is %d',
      [Size, Length(Data)]);
    Exit;
  end;
  if not SendChipDescriptor then Exit;

  //START ของทางเขียนไม่มีคำตอบ อ่านรอจะค้างจนหมดเวลา
  SetLength(Pkt, EZP_PACKET_LEN);
  FillByte(Pkt[0], EZP_PACKET_LEN, 0);
  Pkt[0] := byte(EZP_CMD_START shr 8);
  Pkt[1] := byte(EZP_CMD_START and $FF);
  if not BulkOut(EZP_EP_CMD, Pkt) then Exit;

  BlockLen := Page;
  if BlockLen < EZP_BLOCK_MIN then BlockLen := EZP_BLOCK_MIN;

  SetLength(Block, BlockLen);
  Sent := 0;
  while Sent < Size do
  begin
    Move(Data[Sent], Block[0], BlockLen);
    if not BulkOut(EZP_EP_DATA, Block) then
    begin
      //ครึ่ง ๆ กลาง ๆ คือชิปที่เนื้อในผสมกันอยู่ ต้องบอกให้ชัดว่าถึงไหน
      FStrError := FStrError + Format(' (stopped %d bytes into the write; ' +
        'the chip now holds part of the new image and part of the old)',
        [Sent]);
      Command(EZP_CMD_RESET, Reply);
      ForgetImage;
      Exit;
    end;
    Inc(Sent, BlockLen);
    OpProgress(Sent, Size);
    OpProcessMessages;
    if main.UserCancel then
    begin
      FStrError := Format('cancelled %d bytes into the write; the chip now ' +
        'holds part of the new image and part of the old', [Sent]);
      Command(EZP_CMD_RESET, Reply);
      ForgetImage;
      Exit;
    end;
  end;

  //RESET ของทางเขียนก็ไม่มีคำตอบกลับเช่นกัน
  FillByte(Pkt[0], EZP_PACKET_LEN, 0);
  Pkt[0] := byte(EZP_CMD_RESET shr 8);
  Pkt[1] := byte(EZP_CMD_RESET and $FF);
  BulkOut(EZP_EP_CMD, Pkt);

  //สิ่งที่อยู่บนชิปเปลี่ยนไปแล้ว ภาพที่แคชไว้ใช้ไม่ได้อีก
  ForgetImage;
  Result := True;
end;

//I2C กับ MicroWire: เฟิร์มแวร์ทำได้ แต่ผ่านเส้นทางเดียวกับ SPI คือทั้งชิป
//เท่านั้น ซึ่งชั้นโปรโตคอลของโปรแกรมนี้เรียกทีละไบต์ จึงยังต่อกันไม่ได้

procedure TEZPHardware.I2CInit;
begin
  FStrError := 'I2C through the EZP2023+ is not implemented yet';
end;

procedure TEZPHardware.I2CDeinit;
begin
end;

function TEZPHardware.I2CReadWrite(DevAddr: byte;
  WBufferLen: integer; WBuffer: array of byte;
  RBufferLen: integer; var RBuffer: array of byte): integer;
begin
  FStrError := 'I2C through the EZP2023+ is not implemented yet';
  Result := -1;
end;

procedure TEZPHardware.I2CStart;
begin
end;

procedure TEZPHardware.I2CStop;
begin
end;

function TEZPHardware.I2CReadByte(ack: boolean): byte;
begin
  Result := $FF;
end;

function TEZPHardware.I2CWriteByte(data: byte): boolean;
begin
  Result := False;
end;

function TEZPHardware.MWInit(speed: integer): boolean;
begin
  FStrError := 'MicroWire through the EZP2023+ is not implemented yet';
  Result := False;
end;

procedure TEZPHardware.MWDeinit;
begin
end;

function TEZPHardware.MWRead(CS: byte; BufferLen: integer;
  var buffer: array of byte): integer;
begin
  Result := -1;
end;

function TEZPHardware.MWWrite(CS: byte; BitsWrite: byte;
  buffer: array of byte): integer;
begin
  Result := -1;
end;

function TEZPHardware.MWIsBusy: boolean;
begin
  Result := False;
end;

end.
