unit ch347usb;

// CH347 over libusb-1.0: the Linux transport for the packets ch347proto
// builds. Implements the TBaseHardware SPI contract; I2C and MicroWire
// honestly report unsupported rather than pretending.
//
// libusb is bound dynamically (dynlibs), same policy as every vendor DLL on
// Windows: a machine without libusb sees "that programmer is absent", not a
// process that will not start. Only the handful of functions actually used
// are resolved.
//
// CS semantics follow the house convention the protocol layers rely on:
// SPIWrite(CS=0) asserts CS and leaves it asserted; SPIWrite(CS=1) is a
// complete transaction; SPIRead(CS=1) reads and then releases CS;
// SPIRead(CS=0) reads and leaves CS asserted.
//
// Status: written to the documented protocol, compiles on Linux, NOT yet
// validated against a live CH347. tools/ch347smoke.lpr is the harness; see
// docs/design-cross-platform.md for the usbipd-into-WSL recipe.

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, dynlibs, basehw, electricalpreflight, ch347proto;

type
  TCH347USBHardware = class(TBaseHardware)
  private
    FLib: TLibHandle;
    FCtx: Pointer;
    FDev: Pointer;
    FOpened: boolean;
    FCSAsserted: boolean;
    FStrError: string;

    function BindLibUSB: boolean;
    function Bulk(Endpoint: byte; Data: PByte; Len: integer;
      out Transferred: integer): boolean;
    function SendPacket(const Packet: TBytes): boolean;
    function ReadReply(var Reply: array of byte; MaxLen: integer): integer;
    function SetCS(AssertCS: boolean): boolean;
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

const
  BULK_TIMEOUT_MS = 1000;
  {$IFDEF DARWIN}
  LIBUSB_NAME = 'libusb-1.0.dylib';
  {$ELSE}
  LIBUSB_NAME = 'libusb-1.0.so.0';
  {$ENDIF}

type
  Tlibusb_init = function(ctx: PPointer): integer; cdecl;
  Tlibusb_exit = procedure(ctx: Pointer); cdecl;
  Tlibusb_open_device_with_vid_pid = function(ctx: Pointer;
    vid, pid: word): Pointer; cdecl;
  Tlibusb_close = procedure(dev: Pointer); cdecl;
  Tlibusb_claim_interface = function(dev: Pointer;
    ifnum: integer): integer; cdecl;
  Tlibusb_release_interface = function(dev: Pointer;
    ifnum: integer): integer; cdecl;
  Tlibusb_set_auto_detach_kernel_driver = function(dev: Pointer;
    enable: integer): integer; cdecl;
  Tlibusb_bulk_transfer = function(dev: Pointer; endpoint: byte;
    data: PByte; length: integer; transferred: Pinteger;
    timeout: cardinal): integer; cdecl;

var
  p_init: Tlibusb_init = nil;
  p_exit: Tlibusb_exit = nil;
  p_open_vid_pid: Tlibusb_open_device_with_vid_pid = nil;
  p_close: Tlibusb_close = nil;
  p_claim: Tlibusb_claim_interface = nil;
  p_release: Tlibusb_release_interface = nil;
  p_autodetach: Tlibusb_set_auto_detach_kernel_driver = nil;
  p_bulk: Tlibusb_bulk_transfer = nil;

constructor TCH347USBHardware.Create;
begin
  inherited Create;
  FHardwareName := 'CH347-libusb';
  FHardwareID := CHW_CH347;
  FLib := NilHandle;
  FCtx := nil;
  FDev := nil;
end;

destructor TCH347USBHardware.Destroy;
begin
  DevClose;
  if FLib <> NilHandle then
  begin
    UnloadLibrary(FLib);
    FLib := NilHandle;
  end;
  inherited Destroy;
end;

function TCH347USBHardware.GetLastError: string;
begin
  Result := FStrError;
end;

function TCH347USBHardware.BindLibUSB: boolean;

  function Need(const Name: string): Pointer;
  begin
    Result := GetProcedureAddress(FLib, Name);
    if Result = nil then
      FStrError := LIBUSB_NAME + ' has no ' + Name;
  end;

begin
  Result := False;
  if FLib = NilHandle then
  begin
    FLib := LoadLibrary(LIBUSB_NAME);
    if FLib = NilHandle then
    begin
      FStrError := LIBUSB_NAME + ' is not installed';
      Exit;
    end;
  end;
  Pointer(p_init) := Need('libusb_init');
  Pointer(p_exit) := Need('libusb_exit');
  Pointer(p_open_vid_pid) := Need('libusb_open_device_with_vid_pid');
  Pointer(p_close) := Need('libusb_close');
  Pointer(p_claim) := Need('libusb_claim_interface');
  Pointer(p_release) := Need('libusb_release_interface');
  Pointer(p_bulk) := Need('libusb_bulk_transfer');
  //อันนี้มีมาตั้งแต่ 1.0.16 แต่ถือเป็นของแถม: ไม่มีก็แค่ต้องถอด kernel
  //driver เอง ไม่ใช่เหตุให้เปิดไม่ได้
  Pointer(p_autodetach) :=
    GetProcedureAddress(FLib, 'libusb_set_auto_detach_kernel_driver');
  Result := Assigned(p_init) and Assigned(p_exit) and
            Assigned(p_open_vid_pid) and Assigned(p_close) and
            Assigned(p_claim) and Assigned(p_release) and Assigned(p_bulk);
end;

function TCH347USBHardware.DevOpen: boolean;
var
  rc: integer;
begin
  Result := False;
  if FOpened then DevClose;
  if not BindLibUSB then Exit;

  rc := p_init(@FCtx);
  if rc <> 0 then
  begin
    FStrError := Format('libusb_init failed (%d)', [rc]);
    Exit;
  end;

  FDev := p_open_vid_pid(FCtx, CH347_USB_VID, CH347_USB_PID_MODE1);
  if FDev = nil then
    FDev := p_open_vid_pid(FCtx, CH347_USB_VID, CH347_USB_PID_MODE3);
  if FDev = nil then
  begin
    FStrError := Format('no CH347 found (%04x:%04x or %04x:%04x); check ' +
      'the cable, the mode switch, and udev permissions',
      [CH347_USB_VID, CH347_USB_PID_MODE1,
       CH347_USB_VID, CH347_USB_PID_MODE3]);
    p_exit(FCtx);
    FCtx := nil;
    Exit;
  end;

  if Assigned(p_autodetach) then p_autodetach(FDev, 1);
  rc := p_claim(FDev, CH347_USB_INTERFACE);
  if rc <> 0 then
  begin
    FStrError := Format('claiming interface %d failed (%d); another ' +
      'driver or program owns the CH347', [CH347_USB_INTERFACE, rc]);
    p_close(FDev);
    FDev := nil;
    p_exit(FCtx);
    FCtx := nil;
    Exit;
  end;

  FOpened := True;
  FCSAsserted := False;
  Result := True;
end;

procedure TCH347USBHardware.DevClose;
begin
  if FDev <> nil then
  begin
    //อย่าทิ้งบัสไว้กับ CS ที่ค้างต่ำ
    if FOpened and FCSAsserted then SetCS(False);
    p_release(FDev, CH347_USB_INTERFACE);
    p_close(FDev);
    FDev := nil;
  end;
  if FCtx <> nil then
  begin
    p_exit(FCtx);
    FCtx := nil;
  end;
  FOpened := False;
  FCSAsserted := False;
end;

function TCH347USBHardware.Bulk(Endpoint: byte; Data: PByte; Len: integer;
  out Transferred: integer): boolean;
var
  rc: integer;
begin
  Transferred := 0;
  Result := False;
  if not FOpened then
  begin
    FStrError := 'the CH347 is not open';
    Exit;
  end;
  rc := p_bulk(FDev, Endpoint, Data, Len, @Transferred, BULK_TIMEOUT_MS);
  if rc <> 0 then
  begin
    FStrError := Format('bulk transfer on endpoint %.2x failed (%d)',
                        [Endpoint, rc]);
    Exit;
  end;
  Result := True;
end;

function TCH347USBHardware.SendPacket(const Packet: TBytes): boolean;
var
  Sent: integer;
begin
  Result := Bulk(CH347_EP_OUT, @Packet[0], Length(Packet), Sent) and
            (Sent = Length(Packet));
  if (not Result) and (FStrError = '') then
    FStrError := 'short USB write to the CH347';
end;

function TCH347USBHardware.ReadReply(var Reply: array of byte;
  MaxLen: integer): integer;
var
  Got: integer;
begin
  Result := -1;
  if MaxLen > Length(Reply) then MaxLen := Length(Reply);
  if not Bulk(CH347_EP_IN, @Reply[0], MaxLen, Got) then Exit;
  Result := Got;
end;

function TCH347USBHardware.SetCS(AssertCS: boolean): boolean;
begin
  //แพ็กเก็ต CS ไม่มีคำตอบกลับ
  Result := SendPacket(CH347BuildCSControl(AssertCS));
  if Result then FCSAsserted := AssertCS;
end;

function TCH347USBHardware.SPIInit(speed: integer): boolean;
var
  Packet: TBytes;
  Reply: array[0..CH347_MAX_PACKET - 1] of byte;
  Err: string;
  Got: integer;
begin
  Result := False;
  if not FOpened then Exit;
  if (speed < 0) or (speed > CH347_DIVISOR_MAX) then speed := 1; //30 MHz
  if not CH347BuildSPIConfig(byte(speed), Packet, Err) then
  begin
    FStrError := Err;
    Exit;
  end;
  if not SendPacket(Packet) then Exit;
  //เครื่องตอบรับการตั้งค่าด้วยแพ็กเก็ตสั้น ๆ อ่านทิ้งเพื่อล้างคิว
  Got := ReadReply(Reply, Length(Reply));
  Result := Got >= 3;
  if not Result then
    FStrError := 'the CH347 did not acknowledge the SPI configuration';
end;

procedure TCH347USBHardware.SPIDeinit;
begin
  if FOpened and FCSAsserted then SetCS(False);
end;

function TCH347USBHardware.SPIMaxTransfer: integer;
begin
  //ทางอ่าน 0xC3 ประกาศจำนวนเป็น 32 บิต แต่เพดานนี้คือขนาดที่พิสูจน์แล้ว
  //บนไดรเวอร์ Windows และตัวแบ่งก้อนของโปรแกรมก็อิงเลขนี้อยู่แล้ว
  Result := 65535;
end;

function TCH347USBHardware.SPIWrite(CS: byte; BufferLen: integer;
  buffer: array of byte): integer;
var
  Packet: TBytes;
  Reply: array[0..7] of byte;
  Offset: SizeInt;
  Chunk: word;
  Got: integer;
begin
  Result := -1;
  if not FOpened then Exit;
  if (BufferLen < 0) or (BufferLen > Length(buffer)) then Exit;
  if BufferLen = 0 then Exit(0);

  if not FCSAsserted then
    if not SetCS(True) then Exit;

  Offset := 0;
  while Offset < BufferLen do
  begin
    if BufferLen - Offset > CH347_MAX_DATA then Chunk := CH347_MAX_DATA
    else Chunk := word(BufferLen - Offset);
    Packet := CH347BuildSPIOut(buffer, Offset, Chunk);
    if Packet = nil then Exit;
    if not SendPacket(Packet) then Exit;
    //ทุกก้อนเขียนมีแพ็กเก็ตตอบรับ 4 ไบต์ สถานะศูนย์คือสำเร็จ
    Got := ReadReply(Reply, Length(Reply));
    if not CH347OutAckOK(Reply, Got) then
    begin
      FStrError := 'the CH347 rejected an SPI write chunk';
      Exit;
    end;
    Inc(Offset, Chunk);
  end;

  if CS = 1 then
    if not SetCS(False) then Exit;
  Result := BufferLen;
end;

function TCH347USBHardware.SPIRead(CS: byte; BufferLen: integer;
  var buffer: array of byte): integer;
var
  Reply: array[0..CH347_MAX_PACKET - 1] of byte;
  Got, Have: integer;
  Cmd: byte;
  PayloadLen: word;
begin
  Result := -1;
  if not FOpened then Exit;
  if (BufferLen < 0) or (BufferLen > Length(buffer)) then Exit;
  if BufferLen = 0 then Exit(0);

  if not FCSAsserted then
    if not SetCS(True) then Exit;

  if not SendPacket(CH347BuildSPIInRequest(cardinal(BufferLen))) then Exit;

  //คำตอบมาเป็นแพ็กเก็ต [C3][len][len][data] ต่อกันจนครบที่ขอ
  Have := 0;
  while Have < BufferLen do
  begin
    Got := ReadReply(Reply, Length(Reply));
    if Got < 0 then Exit;
    if not CH347ParseHeader(Reply, Got, Cmd, PayloadLen) then
    begin
      FStrError := 'a truncated packet came back from the CH347';
      Exit;
    end;
    if (Cmd <> CH347_CMD_SPI_IN) or (integer(PayloadLen) <> Got - 3) or
       (Have + PayloadLen > BufferLen) then
    begin
      FStrError := Format('an unexpected packet (%.2x, %d bytes) came ' +
        'back from the CH347 mid-read', [Cmd, PayloadLen]);
      Exit;
    end;
    Move(Reply[3], buffer[Have], PayloadLen);
    Inc(Have, PayloadLen);
  end;

  if CS = 1 then
    if not SetCS(False) then Exit;
  Result := BufferLen;
end;

//I2C and MicroWire: not yet on this transport. Saying so beats pretending.

procedure TCH347USBHardware.I2CInit;
begin
  FStrError := 'I2C over the CH347 libusb backend is not implemented yet';
end;

procedure TCH347USBHardware.I2CDeinit;
begin
end;

function TCH347USBHardware.I2CReadWrite(DevAddr: byte;
  WBufferLen: integer; WBuffer: array of byte;
  RBufferLen: integer; var RBuffer: array of byte): integer;
begin
  FStrError := 'I2C over the CH347 libusb backend is not implemented yet';
  Result := -1;
end;

procedure TCH347USBHardware.I2CStart;
begin
end;

procedure TCH347USBHardware.I2CStop;
begin
end;

function TCH347USBHardware.I2CReadByte(ack: boolean): byte;
begin
  Result := $FF;
end;

function TCH347USBHardware.I2CWriteByte(data: byte): boolean;
begin
  Result := False;
end;

function TCH347USBHardware.MWInit(speed: integer): boolean;
begin
  FStrError := 'MicroWire is not supported on the CH347';
  Result := False;
end;

procedure TCH347USBHardware.MWDeinit;
begin
end;

function TCH347USBHardware.MWRead(CS: byte; BufferLen: integer;
  var buffer: array of byte): integer;
begin
  Result := -1;
end;

function TCH347USBHardware.MWWrite(CS: byte; BitsWrite: byte;
  buffer: array of byte): integer;
begin
  Result := -1;
end;

function TCH347USBHardware.MWIsBusy: boolean;
begin
  Result := False;
end;

end.
