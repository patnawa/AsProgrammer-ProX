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
  Classes, SysUtils, basehw, LibUSB, utilfunc, opthread;

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

  //รหัสที่เครื่องจริงตอบกลับท้ายแพ็กเก็ต CHECK_CHIP
  EZP_PROGRAMMER_CODE = $9A7336BD;

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
    //ภาพทั้งชิปที่อ่านมาแล้วในรอบนี้ 03h ทุกครั้งเสิร์ฟจากตรงนี้
    FImage: TBytes;
    FImageValid: boolean;
    //แอดเดรสที่คำสั่ง 03h ล่าสุดขอ ตั้งโดย SPIWrite แล้ว SPIRead มาใช้ต่อ
    FPendingRead: boolean;
    FPendingAddr: cardinal;

    function BulkOut(Endpoint: longword; const Data: TBytes): boolean;
    function BulkIn(var Data: TBytes; Len: integer): boolean;
    function Command(Cmd: word; out Reply: TBytes): boolean;
    function CheckChip: boolean;
    function ReadWholeChip: boolean;
  public
    constructor Create;
    destructor Destroy; override;

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
  TIMEOUT_MS      = 3000;
  TIMEOUT_READ_MS = 20000;  //อ่านทั้งชิปใช้เวลาเป็นนาทีบนชิปใหญ่

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

function TEZPHardware.DevOpen: boolean;
var
  bus: pusb_bus;
  dev: pusb_device;
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
        //อินเทอร์เฟซ 0 คือที่อยู่ของ bulk endpoint ทั้งสามเส้น
        usb_set_configuration(FHandle, 1);
        if usb_claim_interface(FHandle, 0) <> 0 then
        begin
          FStrError := 'another program already owns the EZP2023+ ' +
            '(close the vendor software and try again)';
          usb_close(FHandle);
          FHandle := nil;
          Exit;
        end;
        FOpened := True;
        FImageValid := False;
        FHaveID := False;
        FPendingRead := False;
        //ยืนยันว่าเป็น EZP จริงไม่ใช่อะไรที่ id ชนกัน และเก็บรหัสชิปไว้เลย
        if not CheckChip then
        begin
          DevClose;
          Exit;
        end;
        Exit(True);
      end;
      dev := dev^.next;
    end;
    bus := bus^.next;
  end;

  FStrError := 'no EZP2023+ found on the USB bus';
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
  FPendingRead := False;
end;

function TEZPHardware.BulkOut(Endpoint: longword;
  const Data: TBytes): boolean;
var
  n: integer;
begin
  Result := False;
  if (not FOpened) or (Length(Data) = 0) then Exit;
  n := usb_bulk_write(FHandle, Endpoint, Data[0], Length(Data), TIMEOUT_MS);
  Result := n = Length(Data);
  if not Result then
    FStrError := Format('the EZP2023+ accepted %d of %d bytes',
                        [n, Length(Data)]);
end;

function TEZPHardware.BulkIn(var Data: TBytes; Len: integer): boolean;
var
  n: integer;
begin
  Result := False;
  SetLength(Data, Len);
  if not FOpened then Exit;
  n := usb_bulk_read(FHandle, EZP_EP_IN, Data[0], Len, TIMEOUT_READ_MS);
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
  Result := BulkOut(EZP_EP_CMD, Pkt) and BulkIn(Reply, EZP_PACKET_LEN);
end;

//CHECK_CHIP: ยืนยันตัวเครื่อง และคายรหัส JEDEC ของชิปในซ็อกเก็ตมาให้ด้วย
function TEZPHardware.CheckChip: boolean;
var
  Reply, Dummy: TBytes;
  Code: cardinal;
begin
  Result := False;
  if not Command(EZP_CMD_CHECK_CHIP, Reply) then Exit;

  Code := (cardinal(Reply[60]) shl 24) or (cardinal(Reply[61]) shl 16) or
          (cardinal(Reply[62]) shl 8) or cardinal(Reply[63]);
  if Code <> EZP_PROGRAMMER_CODE then
  begin
    FStrError := Format('this device answered 1FC8:310B but its identity ' +
      'code is %.8x, not an EZP2023+', [Code]);
    Exit;
  end;

  //ไบต์ 0 คือชนิดตระกูล (บวกหนึ่ง) สามไบต์ถัดไปคือรหัส 9Fh ของชิป
  //ศูนย์แปลว่าไม่มีชิปตอบ ซึ่งไม่ใช่ความผิดของเครื่อง
  FHaveID := Reply[0] <> 0;
  FChipID[0] := Reply[1];
  FChipID[1] := Reply[2];
  FChipID[2] := Reply[3];

  Command(EZP_CMD_RESET, Dummy);
  Result := True;
end;

//อ่านทั้งชิปเข้าหน่วยความจำครั้งเดียวต่อรอบ ขนาดกับเพจมาจากชิปที่เลือกไว้
function TEZPHardware.ReadWholeChip: boolean;
var
  Pkt, Reply, Block: TBytes;
  Size, Page, BlockLen, Got: cardinal;
begin
  Result := False;
  Size := main.CurrentICParam.Size;
  Page := main.CurrentICParam.Page;
  if (Size = 0) or (Page = 0) then
  begin
    FStrError := 'the EZP2023+ needs the chip size and page size before it ' +
      'can read: pick the chip (Read ID, or choose it from the list) first';
    Exit;
  end;
  if (Size mod Page) <> 0 then
  begin
    FStrError := 'the EZP2023+ can only read a whole number of pages';
    Exit;
  end;

  //แพ็กเก็ตบอกชิป: class/algorithm/delay เป็นค่าของตระกูล SPI NOR
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
  if not BulkIn(Reply, EZP_PACKET_LEN) then Exit;

  if not Command(EZP_CMD_START, Reply) then Exit;

  BlockLen := Page;
  if BlockLen < EZP_BLOCK_MIN then BlockLen := EZP_BLOCK_MIN;

  SetLength(FImage, Size);
  Got := 0;
  while Got < Size do
  begin
    if not BulkIn(Block, integer(BlockLen)) then
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
        //ตัวรหัสมีอยู่แล้วจาก CHECK_CHIP ตอนเปิดเครื่อง
        FPendingRead := False;
        Exit(BufferLen);
      end;
    $03, $0B:
      begin
        //03h A2 A1 A0 (0Bh มี dummy ต่อท้ายอีกไบต์) จำแอดเดรสไว้ให้ SPIRead
        if BufferLen < 4 then Exit;
        FPendingAddr := (cardinal(buffer[1]) shl 16) or
                        (cardinal(buffer[2]) shl 8) or cardinal(buffer[3]);
        FPendingRead := True;
        Exit(BufferLen);
      end;
  end;

  FPendingRead := False;
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
  if not FPendingRead then
  begin
    if not FHaveID then
    begin
      FStrError := 'the EZP2023+ reports no chip in the socket';
      Exit;
    end;
    if BufferLen > 3 then Exit;
    Move(FChipID[0], buffer[0], BufferLen);
    Exit(BufferLen);
  end;

  //คำตอบของ 03h: เสิร์ฟจากภาพทั้งชิป อ่านจากตัวชิปครั้งเดียวต่อรอบ
  if not FImageValid then
    if not ReadWholeChip then Exit;

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
