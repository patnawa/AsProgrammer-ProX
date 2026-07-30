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
// Read ID, Read, dump inspection, compare and verify-against-a-file use that
// emulated SPI contract. Write and Erase deliberately bypass it and call the
// firmware's whole-chip operation: two isolated CHECK_CHIP priming sessions,
// a fresh descriptor session whose status must contain the selected JEDEC id,
// START, the exact-size image on OUT|1, RESET, then another fresh whole-chip
// read and a byte-for-byte comparison. Smart write, SFDP and the chip tests
// remain unavailable because they require arbitrary SPI commands.
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

  //เพดานเวลาที่วัดมาจากซอฟต์แวร์ของผู้ผลิตเอง (จับ USB ด้วย tools/ezpspy):
  //มันใช้ 5000 ms กับทุกทรานสเฟอร์ ทั้งแพ็กเก็ตคำสั่ง คำตอบ และก้อนข้อมูล
  //หนึ่งวินาทีที่เคยใช้สั้นเกินไปสำหรับคำตอบของ 0007 ที่เฟิร์มแวร์ต้องไป
  //คุยกับชิปก่อน
  TIMEOUT_MS       = 5000;
  TIMEOUT_READ_MS  = 20000;  //ก้อนข้อมูลของการอ่านทั้งชิป เผื่อไว้มากกว่า
  TIMEOUT_WRITE_MS = 20000;  //ก้อนข้อมูลของการเขียน เผื่อจากของผู้ผลิต
  EZP_RECOVERY_ATTEMPTS = 3;
  EZP_RECOVERY_DELAY_MS = 2500;
  EZP_STREAM_RETRIES    = 200;
  EZP_RETRY_DELAY_MS    = 2;

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
    FInWriteSession: boolean;
    FPendingAddr: cardinal;

    function FindAndOpen: boolean;
    function Recover: boolean;
    function BulkOut(Endpoint: longword; const Data: TBytes;
      TimeoutMs: integer = TIMEOUT_MS;
      MayRecover: boolean = True): boolean;
    function BulkOutStream(Endpoint: longword; const Data: TBytes;
      TimeoutMs: integer): boolean;
    function BulkIn(var Data: TBytes; Len, TimeoutMs: integer;
      Retries: integer = 0): boolean;
    function DrainIn(MaxRounds: integer): integer;
    procedure CleanSession;
    function Command(Cmd: word; out Reply: TBytes): boolean;
    function SendReset: boolean;
    function CheckChip: boolean;
    //รหัส 9Fh จากตารางชิปที่ผู้ใช้เลือก ใส่ลง FChipID ถ้าอ่านได้
    function ChipIDFromTable: boolean;
    function ReadWholeChip: boolean;
    function SendChipDescriptor: boolean;
    function PrimeWriteSessions(ExpectedID: cardinal): boolean;
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

//Enumerate only: no open, interface claim, reset or command is sent.  This is
//safe for startup/hot-plug detection even if another program owns the EZP.
function EZPDevicePresent: boolean;

implementation

uses main;

var
  UsbInited: boolean = False;

function EZPDevicePresent: boolean;
var
  bus: pusb_bus;
  dev: pusb_device;
  LoadError: string;
begin
  Result := False;
  if not LibUSBAvailable(LoadError) then Exit;

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
        Exit(True);
      dev := dev^.next;
    end;
    bus := bus^.next;
  end;
end;

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
        //ลำดับตามของผู้ผลิต: เปิด -> อ่าน string descriptor -> claim
        FOpened := True;
        CleanSession;
        usb_claim_interface(FHandle, 0);
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
  Sleep(EZP_RECOVERY_DELAY_MS);
  FImageValid := False;
  FIdentityChecked := False;
  Result := FindAndOpen;
end;

function TEZPHardware.DevOpen: boolean;
var
  LoadError: string;
begin
  Result := False;
  if FOpened then DevClose;
  FStrError := '';

  if not LibUSBAvailable(LoadError) then
  begin
    FStrError := LoadError + ', so no EZP2023+ can be opened. Put ' +
      'libusb0.dll next to AsProgrammer.exe (the release zip ships one)';
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
  const Data: TBytes; TimeoutMs: integer; MayRecover: boolean): boolean;
var
  n, Attempt: integer;
begin
  Result := False;
  if (not FOpened) or (Length(Data) = 0) then Exit;
  n := usb_bulk_write(FHandle, Endpoint, Data[0], Length(Data),
                      longword(TimeoutMs));
  if n = Length(Data) then Exit(True);

  //ไม่รับคำสั่ง = เฟิร์มแวร์ค้าง กู้แล้วลองซ้ำ ถ้ายังไม่ได้
  //ค่อยบอกว่าเครื่องไม่ตอบ ไม่ใช่รายงานเลขติดลบดิบ ๆ ให้คนไปเดาเอง
  //
  //ห้ามกู้กลางสตรีมเด็ดขาด: การรีเซ็ตตอนที่เฟิร์มแวร์กำลังรับข้อมูลทั้งชิป
  //ทำให้มันหลุดสถานะ ก้อนที่ส่งต่อจากนั้นลงผิดที่ทั้งหมด ผลคือชิปพัง
  //ทั้งที่รายงานว่าเขียนต่อได้ วัดมาแล้วด้วยการทดลองที่ทำให้ชิปทดสอบเสียหาย
  if MayRecover and (not FRecovering) then
  begin
    FRecovering := True;
    try
      for Attempt := 1 to EZP_RECOVERY_ATTEMPTS do
      begin
        if not Recover then Continue;
        n := usb_bulk_write(FHandle, Endpoint, Data[0], Length(Data),
                            longword(TimeoutMs));
        if n = Length(Data) then
        begin
          main.LogPrint(Format('the EZP2023+ was not answering; USB reset ' +
            'cycle %d brought it back', [Attempt]));
          Exit(True);
        end;
      end;
    finally
      FRecovering := False;
    end;
  end;

  FStrError := Format('the EZP2023+ would not accept a command even after ' +
    '%d USB reset cycles (%d of %d bytes). Unplug it, wait a few seconds and plug ' +
    'it back in: that power-cycles the CH552, which is what clears one ' +
    'that is truly stuck', [EZP_RECOVERY_ATTEMPTS, n, Length(Data)]);
end;

//ก้อนข้อมูลกลางสตรีมห้ามเรียก Recover: USB reset จะทำให้เฟิร์มแวร์หลุด
//ตำแหน่งและข้อมูลที่ตามมาทั้งหมดเหลื่อม ลองซ้ำได้เฉพาะค่าติดลบซึ่งแปลว่า
//ไม่มีไบต์ถูกส่ง ค่าบวกที่สั้นอาจกินบางส่วนไปแล้วจึงต้องหยุดทันที
function TEZPHardware.BulkOutStream(Endpoint: longword;
  const Data: TBytes; TimeoutMs: integer): boolean;
var
  n, Attempt: integer;
begin
  Result := False;
  if (not FOpened) or (Length(Data) = 0) then Exit;

  for Attempt := 0 to EZP_STREAM_RETRIES do
  begin
    n := usb_bulk_write(FHandle, Endpoint, Data[0], Length(Data),
                        longword(TimeoutMs));
    if n = Length(Data) then Exit(True);
    if (n >= 0) or (Attempt >= EZP_STREAM_RETRIES) then Break;
    Sleep(EZP_RETRY_DELAY_MS);
  end;

  FStrError := Format('the EZP2023+ accepted %d of %d stream bytes after ' +
    '%d retries', [n, Length(Data), Attempt]);
end;

function TEZPHardware.BulkIn(var Data: TBytes; Len,
  TimeoutMs, Retries: integer): boolean;
var
  n, Attempt: integer;
begin
  Result := False;
  SetLength(Data, Len);
  if not FOpened then Exit;
  for Attempt := 0 to Retries do
  begin
    n := usb_bulk_read(FHandle, EZP_EP_IN, Data[0], Len,
                       longword(TimeoutMs));
    if n = Len then Exit(True);

    //ค่าติดลบหมายถึงไม่มีข้อมูลถูกส่งมา จึงลองอ่านก้อนเดิมใหม่ได้โดยไม่
    //ทำให้ตำแหน่งเลื่อน แต่ short packet ที่เป็นบวกกินข้อมูลไปแล้ว ห้ามลอง
    //ซ้ำเพราะจะทำให้ภาพทั้งชิปเหลื่อมหนึ่งก้อน
    if (n >= 0) or (Attempt >= Retries) then Break;
    Sleep(EZP_RETRY_DELAY_MS);
  end;
  FStrError := Format('the EZP2023+ returned %d of %d bytes after %d ' +
    'retries', [n, Len, Attempt]);
end;

//ล้างท่อ IN ให้ว่างก่อนเริ่มงาน
//
//นี่คือต้นเหตุของเรื่องทั้งหมด: งานที่ล้มกลางทาง (อ่านไม่จบ, timeout) ทิ้ง
//ข้อมูลค้างอยู่ในคิวของอุปกรณ์ รอบถัดไปที่เราคิดว่าอ่าน "คำตอบของ 0007"
//จะได้ข้อมูลชิปเก่านั่นแทน แล้วทุกอย่างเลื่อนเฟสไปหมด เฟิร์มแวร์อยู่คนละ
//สถานะกับที่เราคิด การเขียนจึงรับข้อมูลครบแล้วทิ้งทั้งหมดโดยไม่บ่นอะไร
//วัดเห็นได้จาก log ของ tools/ezpspy: คำตอบของ 0007 เป็น BA F8 0C EF...
//ซึ่งเป็นเนื้อชิป ไม่ใช่แพ็กเก็ตสถานะแบบที่ซอฟต์แวร์ผู้ผลิตได้ (01 EF 40 17)
function TEZPHardware.DrainIn(MaxRounds: integer): integer;
var
  Junk: TBytes;
  n: integer;
begin
  Result := 0;
  if not FOpened then Exit;
  //ต้องอ่านทีละ 64 ไบต์ ซึ่งเท่า max packet ของปลายทางนี้พอดี
  //อ่านทีละมากกว่านั้น (ลอง 4096 มาแล้ว) libusb0 บนอุปกรณ์นี้คืน "สำเร็จ"
  //พร้อมบัฟเฟอร์เป็นศูนย์ทั้งก้อน แม้ไม่มีอะไรให้อ่าน ตัวนับจึงไม่มีความหมาย
  //และครั้งก่อนมันพาไปสั่ง usb_reset ทับ ซึ่งทำให้เฟิร์มแวร์หาชิปไม่เจอ
  SetLength(Junk, 64);
  repeat
    n := usb_bulk_read(FHandle, EZP_EP_IN, Junk[0], 64, 50);
    if n > 0 then Inc(Result);
  until (n <= 0) or (Result >= MaxRounds);
end;

//เริ่ม session ให้สะอาด: สั่งเลิกงานเก่าก่อน แล้วดูดของค้างออกให้หมด
//
//งานอ่านที่เลิกกลางทางทำให้เฟิร์มแวร์สตรีมชิปต่อไปเรื่อย ๆ ข้อมูลค้างอยู่ใน
//คิวข้าม process ได้ด้วย รอบถัดไปที่อ่าน "คำตอบของ 0007" จึงได้เนื้อชิปเก่า
//แทนแพ็กเก็ตสถานะ (วัดเทียบกับของผู้ผลิตแล้ว: เขาได้ 01 EF 40 17 เราได้
//BA F8 0C EF) แล้วทุกอย่างเลื่อนเฟส การเขียนรับครบแล้วทิ้งทั้งหมดเงียบ ๆ
procedure TEZPHardware.CleanSession;
var
  Buf: TBytes;
begin
  if not FOpened then Exit;

  //ทำตามซอฟต์แวร์ของผู้ผลิตทุกขั้น รวมขั้นที่ดูเหมือนไม่จำเป็น
  //
  //มันอ่าน string descriptor สองอันทุกครั้งที่เปิดอุปกรณ์ ก่อน claim ด้วย
  //(จับมาได้: CTRL rt=80 req=06 val=0301 idx=1033, แล้ว val=0302)
  //ทางเราไม่เคยอ่าน แล้วผลต่างที่เหลืออยู่ก็คือ: ของเขาได้คำตอบสถานะจริง
  //(01 EF 40 17) ของเราได้เนื้อชิปเก่าซ้ำ ๆ ไม่จบ
  //
  //การล้างท่อด้วยการอ่านทิ้งใช้ไม่ได้บนสแต็กนี้: usb_bulk_read คืนบัฟเฟอร์
  //เดิมซ้ำไม่รู้จบ (ลอง 300000 รอบแล้วได้ 64 ไบต์เดียวกันทุกครั้ง) จึงแยก
  //"ท่อว่าง" กับ "ของค้าง" ไม่ออกเลย เลิกใช้วิธีนั้น
  SetLength(Buf, 256);
  usb_control_msg(FHandle, USB_ENDPOINT_IN, USB_REQ_GET_DESCRIPTOR,
                  (USB_DT_STRING shl 8) or 1, 1033, Buf[0], 256, 1000);
  usb_control_msg(FHandle, USB_ENDPOINT_IN, USB_REQ_GET_DESCRIPTOR,
                  (USB_DT_STRING shl 8) or 2, 1033, Buf[0], 256, 1000);
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

//RESET เป็นคำสั่งทางเดียว ซอฟต์แวร์ผู้ผลิตไม่อ่านคำตอบหลังมัน การอ่านรอ
//จะได้แพ็กเก็ตเก่าซ้ำจาก libusb0 แล้วทำให้คำตอบทุกคำสั่งหลังจากนั้นเลื่อนเฟส
function TEZPHardware.SendReset: boolean;
var
  Pkt: TBytes;
begin
  SetLength(Pkt, EZP_PACKET_LEN);
  FillByte(Pkt[0], EZP_PACKET_LEN, 0);
  Pkt[0] := byte(EZP_CMD_RESET shr 8);
  Pkt[1] := byte(EZP_CMD_RESET and $FF);
  Result := BulkOut(EZP_EP_CMD, Pkt);
end;

//รหัสจากตารางชิป: CurrentICParam.ID เก็บเป็นสตริงเลขฐานสิบหกหกตัว
function TEZPHardware.ChipIDFromTable: boolean;
var
  Hex: string;
  V: longint;
begin
  Result := False;
  Hex := UpperCase(Trim(main.CurrentICParam.ID));
  if Length(Hex) <> 6 then Exit;
  if not TryStrToInt('$' + Hex, V) then Exit;
  FChipID[0] := byte(V shr 16);
  FChipID[1] := byte(V shr 8);
  FChipID[2] := byte(V);
  FHaveID := True;
  Result := True;
end;

//CHECK_CHIP: ยืนยันตัวเครื่อง และคายรหัส JEDEC ของชิปในซ็อกเก็ตมาให้ด้วย
//เรียกครั้งแรกที่มีคนต้องใช้ ไม่ใช่ตอนเปิดอุปกรณ์
function TEZPHardware.CheckChip: boolean;
var
  Reply, Pkt: TBytes;
  Code: cardinal;
  Size, Page: cardinal;
begin
  Result := False;

  //ของผู้ผลิตส่ง descriptor เต็มไปพร้อมคำสั่ง 0009 ไม่ใช่แพ็กเก็ตเปล่า
  //(จับมาได้: 00 09 00 00 01 00 03 E8 00 80 00 00 00 EF 40 17)
  //ตอนกด Read ID อาจยังไม่ได้เลือกชิป ช่องที่ไม่รู้ก็ปล่อยศูนย์ไว้
  SetLength(Pkt, EZP_PACKET_LEN);
  FillByte(Pkt[0], EZP_PACKET_LEN, 0);
  Pkt[0] := byte(EZP_CMD_CHECK_CHIP shr 8);
  Pkt[1] := byte(EZP_CMD_CHECK_CHIP and $FF);
  Size := main.CurrentICParam.Size;
  Page := main.CurrentICParam.Page;
  if (Size > 0) and (Page > 0) then
  begin
    Pkt[2] := EZP_CLASS_SPI_FLASH;
    Pkt[3] := EZP_ALGORITHM_SPI;
    Pkt[4] := byte(Page shr 8);
    Pkt[5] := byte(Page);
    Pkt[6] := byte(EZP_DELAY_SPI_MS shr 8);
    Pkt[7] := byte(EZP_DELAY_SPI_MS and $FF);
    Pkt[8] := byte(Size shr 24);
    Pkt[9] := byte(Size shr 16);
    Pkt[10] := byte(Size shr 8);
    Pkt[11] := byte(Size);
  end;
  Pkt[16] := FSpeed;
  if not BulkOut(EZP_EP_CMD, Pkt) then Exit;
  if not BulkIn(Reply, EZP_PACKET_LEN, TIMEOUT_MS) then Exit;

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

  if not SendReset then Exit;
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

  //รหัสชิปเอาจากตารางชิปที่เลือกไว้ ไม่ใช่ไปถามเครื่อง
  //
  //ห้ามเรียก CheckChip ติดกับ 0007 ใน session เขียน: CHECK_CHIP ปิดท้ายด้วย
  //RESET และ 0007 จะตอบข้อมูลเก่าหรือรับภาพไปทิ้ง ซอฟต์แวร์ผู้ผลิตทำการ
  //ตรวจสอง session แยกก่อน แล้วเปิด session ที่สามเพื่อ 0007/START/data
  //รหัสใน descriptor ของ session ที่สามมาจากฐานข้อมูล เราก็ทำแบบเดียวกัน
  if not ChipIDFromTable then
  begin
    //ไม่มีรหัสในตาราง (เช่นชิปที่มาจาก SFDP) ก็ยังถามเครื่องได้ แต่ต้อง
    //ไม่ใช่ระหว่างรอบเขียน
    if FInWriteSession then
    begin
      FStrError := 'the EZP2023+ needs the chip''s JEDEC id and the ' +
        'selected chip does not carry one: pick the part from the chip ' +
        'list (its id comes with it) rather than an SFDP-detected entry';
      Exit;
    end;
    if not FIdentityChecked then
      if not CheckChip then Exit;
  end;
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
  if not BulkIn(Reply, EZP_PACKET_LEN, TIMEOUT_MS) then Exit;

  //ทางเขียนต้อง fail closed: ถ้าได้ข้อมูลเก่าซ้ำแทนสถานะ 01 + JEDEC id
  //แปลว่าฝั่งเครื่องกับฝั่งเราคิดว่าอยู่คนละ session การส่งภาพต่อไปจะถูก
  //ทิ้งหรือวางผิดตำแหน่งโดยไม่มี error จากเฟิร์มแวร์
  if FInWriteSession and
     ((Reply[0] <> 1) or
      (Reply[1] <> FChipID[0]) or
      (Reply[2] <> FChipID[1]) or
      (Reply[3] <> FChipID[2])) then
  begin
    FStrError := Format('the EZP2023+ descriptor reply was %.2x %.2x %.2x ' +
      '%.2x, expected 01 %.2x %.2x %.2x; no image data was sent',
      [Reply[0], Reply[1], Reply[2], Reply[3],
       FChipID[0], FChipID[1], FChipID[2]]);
    Exit;
  end;
  Result := True;
end;

//ซอฟต์แวร์ผู้ผลิตตรวจชิปสอง session เต็มก่อนเปิด session ใหม่เพื่อเขียน
//จริง การตรวจนั้นเป็นจุดที่เฟิร์มแวร์เติมสถานะชิปซึ่ง 0007 ใช้ต่อ ข้ามขั้น
//นี้แล้ว 0007 อาจตอบ FF หรือข้อมูลเก่าและรับภาพไปทิ้งเงียบ ๆ
function TEZPHardware.PrimeWriteSessions(ExpectedID: cardinal): boolean;
var
  Pass: integer;
  GotID: cardinal;
begin
  Result := False;
  for Pass := 1 to 2 do
  begin
    DevClose;
    if not DevOpen then Exit;
    if not CheckChip then Exit;
    if not FHaveID then
    begin
      FStrError := Format('the EZP2023+ did not detect the expected chip ' +
        '%.6x during write priming pass %d', [ExpectedID, Pass]);
      Exit;
    end;
    GotID := (cardinal(FChipID[0]) shl 16) or
             (cardinal(FChipID[1]) shl 8) or cardinal(FChipID[2]);
    if GotID <> ExpectedID then
    begin
      FStrError := Format('the selected chip is %.6x but the EZP2023+ ' +
        'detected %.6x during write priming pass %d',
        [ExpectedID, GotID, Pass]);
      Exit;
    end;
    main.LogPrint(Format('EZP2023+: write priming pass %d detected %.6x',
                         [Pass, GotID]));
    DevClose;
  end;

  //descriptor + START + data ต้องอยู่ใน session ใหม่ทั้งหมด
  Result := DevOpen;
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
    if not BulkIn(Block, integer(BlockLen), TIMEOUT_READ_MS,
                  EZP_STREAM_RETRIES) then
    begin
      //เลิกเฉย ๆ ไม่ได้: เฟิร์มแวร์จะสตรีมต่อจนจบชิป แล้วงานหน้าจะไปเจอ
      //ข้อมูลค้างเต็มท่อ ซึ่งเป็นที่มาของบั๊กเฟสทั้งหมดที่ตามหากันมา
      SendReset;
      DrainIn(64);
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
      SendReset;
      Exit;
    end;
  end;

  SendReset;
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
  //บังคับอ่านจากชิปจริงใน session ใหม่ ไม่ใช่ภาพหรือสถานะ USB ที่ค้างจาก
  //รอบเขียน การแยก session นี้เป็นเงื่อนไขเดียวกับที่ทดสอบบนฮาร์ดแวร์จริง
  ForgetImage;
  DevClose;
  if not DevOpen then Exit(False);
  Result := ReadWholeChip;
  if Result then Data := Copy(FImage, 0, Length(FImage));
end;

//เขียนทั้งชิป: เฟิร์มแวร์จัดการลบและเขียนตามอัลกอริทึมของมันเอง เราแค่
//ป้อนภาพให้ครบ ลำดับต่างจากทางอ่านสองจุด และทั้งสองจุดสำคัญ: หลัง START
//ไม่มีคำตอบกลับ (รออยู่ก็ค้าง) และก้อนข้อมูลไปที่ปลายทาง OUT|1 ไม่ใช่ OUT|2
function TEZPHardware.WriteWholeChip(const Data: TBytes): boolean;
var
  Block: TBytes;
  Size, Page, BlockLen, Sent, ExpectedID: cardinal;
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
  if not ChipIDFromTable then
  begin
    FStrError := 'the EZP2023+ write path needs a six-digit JEDEC id from ' +
      'the selected chip entry';
    Exit;
  end;
  ExpectedID := (cardinal(FChipID[0]) shl 16) or
                (cardinal(FChipID[1]) shl 8) or cardinal(FChipID[2]);
  if not PrimeWriteSessions(ExpectedID) then Exit;

  FInWriteSession := True;
  try
    //DevOpen ของ session ใหม่ล้าง id ที่ prime มา จึงใส่ค่าจากตารางกลับไป
    if not ChipIDFromTable then Exit;
    if not SendChipDescriptor then Exit;

    //START ของทางเขียนไม่มีคำตอบ อ่านรอจะค้างจนหมดเวลา
    SetLength(Pkt, EZP_PACKET_LEN);
    FillByte(Pkt[0], EZP_PACKET_LEN, 0);
    Pkt[0] := byte(EZP_CMD_START shr 8);
    Pkt[1] := byte(EZP_CMD_START and $FF);
    if not BulkOut(EZP_EP_CMD, Pkt, TIMEOUT_MS, False) then Exit;

    BlockLen := Page;
    if BlockLen < EZP_BLOCK_MIN then BlockLen := EZP_BLOCK_MIN;

    main.LogPrint('the firmware erases the chip before it takes data; the ' +
                  'first block can take a minute on a large part');
    SetLength(Block, BlockLen);
    Sent := 0;
    while Sent < Size do
    begin
      Move(Data[Sent], Block[0], BlockLen);
      if not BulkOutStream(EZP_EP_DATA, Block, TIMEOUT_WRITE_MS) then
      begin
        //ครึ่ง ๆ กลาง ๆ คือชิปที่เนื้อในผสมกันอยู่ ต้องบอกให้ชัดว่าถึงไหน
        FStrError := FStrError + Format(' (stopped %d bytes into the write; ' +
          'the chip now holds part of the new image and part of the old)',
          [Sent]);
        SendReset;
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
        SendReset;
        ForgetImage;
        Exit;
      end;
    end;

    //RESET ของทางเขียนก็ไม่มีคำตอบกลับเช่นกัน และห้าม USB-recover หลัง
    //ก้อนสุดท้ายเพราะอาจรีเซ็ตเครื่องขณะที่ชิปยังปิดงานเพจสุดท้าย
    FillByte(Pkt[0], EZP_PACKET_LEN, 0);
    Pkt[0] := byte(EZP_CMD_RESET shr 8);
    Pkt[1] := byte(EZP_CMD_RESET and $FF);
    BulkOut(EZP_EP_CMD, Pkt, TIMEOUT_MS, False);

    //สิ่งที่อยู่บนชิปเปลี่ยนไปแล้ว ภาพที่แคชไว้ใช้ไม่ได้อีก
    ForgetImage;
    Result := True;
  finally
    FInWriteSession := False;
  end;
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
