unit serproghw;

// serprog: flashrom's serial-programmer protocol, spoken over a COM port.
//
// One backend, dozens of programmers: a Raspberry Pi Pico running
// pico-serprog, an STM32 blue pill, an ESP32, frser-duino on any Arduino,
// or anything else that implements the protocol from flashrom's
// Documentation/serprog-protocol.txt. Every command gets an ACK (06h) or
// NAK (15h); the device advertises which commands it supports in a 32-byte
// bitmap, and SPI transfers are single atomic operations (O_SPIOP: send
// slen bytes, then clock rlen bytes back, CS handled by the firmware).
//
// That transactional shape does not match the house SPIWrite(CS=0) /
// SPIRead(CS=1) split, so the adapter buffers: a write that leaves CS
// asserted is queued, and the next call that releases CS executes the
// whole exchange as one O_SPIOP. The protocol layers see the semantics
// they expect; the wire sees the transactions serprog requires. A read
// that asks to keep CS asserted afterwards cannot be honoured on this
// protocol and fails closed, saying so (only the KB9012 EC path does
// that, and an EC is not a thing anyone flashes through serprog).
//
// SPI only, by the protocol's own design: I2C and MicroWire report
// honestly unsupported.

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, basehw, Synaser;

type
  TSerprogHardware = class(TBaseHardware)
  private
    FDevOpened: boolean;
    FStrError: string;
    FSerial: TBlockSerial;
    FCmdMap: array[0..31] of byte;
    FWrnMax, FRdnMax: cardinal;
    FPending: TBytes;
    FPendingLen: integer;
    FProgName: string;

    function CmdSupported(Cmd: byte): boolean;
    function SendAll(const Buf; Len: integer): boolean;
    function RecvExact(var Buf; Len: integer): boolean;
    function AckedCmd(Cmd: byte; const Params: array of byte;
      RespLen: integer; out Resp: TBytes): boolean;
    function Sync: boolean;
    function DoSPIOp(RLen: integer; var RBuffer: array of byte): boolean;
    procedure DropPending;
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
    function SPIWriteRead(CS: byte; WBufferLen: integer;
      WBuffer: array of byte; RBufferLen: integer;
      var RBuffer: array of byte): integer; override;

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
  TIMEOUT_MS = 2000;

  S_ACK = $06;
  S_NAK = $15;

  S_CMD_NOP        = $00;
  S_CMD_Q_IFACE    = $01;
  S_CMD_Q_CMDMAP   = $02;
  S_CMD_Q_PGMNAME  = $03;
  S_CMD_Q_BUSTYPE  = $05;
  S_CMD_Q_WRNMAXLEN= $08;
  S_CMD_SYNCNOP    = $10;
  S_CMD_Q_RDNMAXLEN= $11;
  S_CMD_S_BUSTYPE  = $12;
  S_CMD_O_SPIOP    = $13;
  S_CMD_S_SPI_FREQ = $14;
  S_CMD_S_PIN_STATE= $15;

  BUS_SPI = $08;

  //ถ้าเฟิร์มแวร์ไม่บอกเพดานมา ใช้ค่าที่เฟิร์มแวร์จริงทุกตัวรับได้แน่
  DEFAULT_WRN_MAX = 256;
  DEFAULT_RDN_MAX = 256;
  //ขอความถี่กลาง ๆ ที่คลิปหนีบยังไหว เฟิร์มแวร์ที่ตั้งไม่ได้ก็ใช้ค่าของมันเอง
  DEFAULT_SPI_HZ = 4000000;

constructor TSerprogHardware.Create;
begin
  FHardwareName := 'serprog';
  FHardwareID := CHW_SERPROG;
  FSerial := TBlockSerial.Create;
  FWrnMax := DEFAULT_WRN_MAX;
  FRdnMax := DEFAULT_RDN_MAX;
end;

destructor TSerprogHardware.Destroy;
begin
  DevClose;
  FSerial.Free;
  inherited Destroy;
end;

function TSerprogHardware.GetLastError: string;
begin
  Result := FStrError;
  if (Result = '') and (FSerial.LastError <> 0) then
    Result := FSerial.LastErrorDesc;
end;

function TSerprogHardware.CmdSupported(Cmd: byte): boolean;
begin
  Result := (FCmdMap[Cmd shr 3] and (1 shl (Cmd and 7))) <> 0;
end;

function TSerprogHardware.SendAll(const Buf; Len: integer): boolean;
begin
  Result := FSerial.SendBuffer(@Buf, Len) = Len;
  if not Result then FStrError := 'serial write failed: ' + FSerial.LastErrorDesc;
end;

function TSerprogHardware.RecvExact(var Buf; Len: integer): boolean;
begin
  Result := FSerial.RecvBufferEx(@Buf, Len, TIMEOUT_MS) = Len;
  if not Result then
    FStrError := 'the programmer did not answer in time';
end;

//ส่งคำสั่ง+พารามิเตอร์ รอ ACK แล้วอ่านคำตอบตามจำนวนที่คาด
function TSerprogHardware.AckedCmd(Cmd: byte; const Params: array of byte;
  RespLen: integer; out Resp: TBytes): boolean;
var
  Status: byte;
begin
  Resp := nil;
  Result := False;
  if not SendAll(Cmd, 1) then Exit;
  if Length(Params) > 0 then
    if not SendAll(Params[0], Length(Params)) then Exit;
  if not RecvExact(Status, 1) then Exit;
  if Status <> S_ACK then
  begin
    FStrError := Format('the programmer refused command %.2x', [Cmd]);
    Exit;
  end;
  if RespLen > 0 then
  begin
    SetLength(Resp, RespLen);
    if not RecvExact(Resp[0], RespLen) then
    begin
      Resp := nil;
      Exit;
    end;
  end;
  Result := True;
end;

//SYNCNOP ตอบ NAK แล้วตามด้วย ACK เป็นวิธีเดียวที่แยก "โปรแกรมเมอร์กำลังฟัง"
//ออกจากขยะที่ค้างอยู่ในบัฟเฟอร์ ยิงซ้ำได้สูงสุดแปดครั้งแบบเดียวกับ flashrom
function TSerprogHardware.Sync: boolean;
var
  Tries: integer;
  B: byte;
begin
  Result := False;
  for Tries := 1 to 8 do
  begin
    FSerial.Purge;
    B := S_CMD_SYNCNOP;
    if not SendAll(B, 1) then Exit;
    if FSerial.RecvBufferEx(@B, 1, 500) <> 1 then Continue;
    if B <> S_NAK then Continue;
    if FSerial.RecvBufferEx(@B, 1, 500) <> 1 then Continue;
    if B = S_ACK then Exit(True);
  end;
  FStrError := 'no serprog answered on this port (SYNCNOP got no NAK+ACK)';
end;

function TSerprogHardware.DevOpen: boolean;
var
  Resp: TBytes;
  i: integer;
begin
  if FDevOpened then DevClose;
  Result := False;
  FStrError := '';
  FPending := nil;
  FPendingLen := 0;

  if main.Serprog_COMPort = '' then
  begin
    FStrError := 'No port selected!';
    Exit;
  end;

  FSerial.Connect(main.Serprog_COMPort);
  if FSerial.LastError <> 0 then
  begin
    FStrError := FSerial.LastErrorDesc;
    Exit;
  end;
  FSerial.Config(main.Serprog_BaudRate, 8, 'N', SB1, false, false);
  FSerial.Purge;

  if not Sync then
  begin
    FSerial.CloseSocket;
    Exit;
  end;

  //โปรโตคอลเวอร์ชัน 1 เท่านั้นที่นิยามไว้ ใครตอบเลขอื่นคือไม่ใช่ serprog
  if (not AckedCmd(S_CMD_Q_IFACE, [], 2, Resp)) or
     (word(Resp[0]) or (word(Resp[1]) shl 8) <> 1) then
  begin
    if FStrError = '' then
      FStrError := 'this device speaks a serprog version this program does not';
    FSerial.CloseSocket;
    Exit;
  end;

  if not AckedCmd(S_CMD_Q_CMDMAP, [], 32, Resp) then
  begin
    FSerial.CloseSocket;
    Exit;
  end;
  for i := 0 to 31 do FCmdMap[i] := Resp[i];

  if not CmdSupported(S_CMD_O_SPIOP) then
  begin
    FStrError := 'this serprog cannot do SPI operations (no O_SPIOP)';
    FSerial.CloseSocket;
    Exit;
  end;

  FProgName := '';
  if CmdSupported(S_CMD_Q_PGMNAME) and
     AckedCmd(S_CMD_Q_PGMNAME, [], 16, Resp) then
    for i := 0 to 15 do
      if Resp[i] <> 0 then FProgName := FProgName + chr(Resp[i]);

  FWrnMax := DEFAULT_WRN_MAX;
  if CmdSupported(S_CMD_Q_WRNMAXLEN) and
     AckedCmd(S_CMD_Q_WRNMAXLEN, [], 3, Resp) then
    FWrnMax := cardinal(Resp[0]) or (cardinal(Resp[1]) shl 8) or
               (cardinal(Resp[2]) shl 16);
  FRdnMax := DEFAULT_RDN_MAX;
  if CmdSupported(S_CMD_Q_RDNMAXLEN) and
     AckedCmd(S_CMD_Q_RDNMAXLEN, [], 3, Resp) then
    FRdnMax := cardinal(Resp[0]) or (cardinal(Resp[1]) shl 8) or
               (cardinal(Resp[2]) shl 16);
  //ศูนย์แปลว่า "ไม่จำกัด" ตามสเปก ตีเป็นเพดานที่โค้ดฝั่งเราแบ่งก้อนได้จริง
  if (FWrnMax = 0) or (FWrnMax > 65535) then FWrnMax := 65535;
  if (FRdnMax = 0) or (FRdnMax > 65535) then FRdnMax := 65535;

  if CmdSupported(S_CMD_S_BUSTYPE) then
    if not AckedCmd(S_CMD_S_BUSTYPE, [BUS_SPI], 0, Resp) then
    begin
      FStrError := 'the programmer refused to switch its bus to SPI';
      FSerial.CloseSocket;
      Exit;
    end;

  //เปิดไดรเวอร์ขา ถ้าเฟิร์มแวร์รองรับ (บางตัวปล่อยขาลอยจนกว่าจะสั่ง)
  if CmdSupported(S_CMD_S_PIN_STATE) then
    AckedCmd(S_CMD_S_PIN_STATE, [1], 0, Resp);

  FDevOpened := True;
  Result := True;
end;

procedure TSerprogHardware.DevClose;
var
  Resp: TBytes;
begin
  if FDevOpened then
  begin
    //ปล่อยขาก่อนจาก จะได้ไม่ค้างดันบัสของบอร์ดที่หนีบอยู่
    if CmdSupported(S_CMD_S_PIN_STATE) then
      AckedCmd(S_CMD_S_PIN_STATE, [0], 0, Resp);
  end;
  FDevOpened := False;
  DropPending;
  FSerial.CloseSocket;
end;

procedure TSerprogHardware.DropPending;
begin
  FPending := nil;
  FPendingLen := 0;
end;

function TSerprogHardware.SPIInit(speed: integer): boolean;
var
  Params: array[0..3] of byte;
  Resp: TBytes;
  Hz: cardinal;
begin
  Result := FDevOpened;
  if not Result then Exit;
  DropPending;
  //ความถี่เป็นของแถม: เฟิร์มแวร์ที่ตั้งไม่ได้ก็วิ่งความถี่ของมันเอง
  if CmdSupported(S_CMD_S_SPI_FREQ) then
  begin
    Hz := DEFAULT_SPI_HZ;
    Params[0] := byte(Hz);
    Params[1] := byte(Hz shr 8);
    Params[2] := byte(Hz shr 16);
    Params[3] := byte(Hz shr 24);
    AckedCmd(S_CMD_S_SPI_FREQ, Params, 4, Resp);
  end;
end;

procedure TSerprogHardware.SPIDeinit;
begin
  DropPending;
end;

function TSerprogHardware.SPIMaxTransfer: integer;
begin
  Result := integer(FRdnMax);
end;

//หัวใจของอะแดปเตอร์: [13h][slen24][rlen24][sdata] -> ACK แล้วตามด้วย rdata
function TSerprogHardware.DoSPIOp(RLen: integer;
  var RBuffer: array of byte): boolean;
var
  Header: array[0..6] of byte;
  Status: byte;
begin
  Result := False;
  Header[0] := S_CMD_O_SPIOP;
  Header[1] := byte(FPendingLen);
  Header[2] := byte(FPendingLen shr 8);
  Header[3] := byte(FPendingLen shr 16);
  Header[4] := byte(RLen);
  Header[5] := byte(RLen shr 8);
  Header[6] := byte(RLen shr 16);
  if not SendAll(Header, 7) then Exit;
  if FPendingLen > 0 then
    if not SendAll(FPending[0], FPendingLen) then Exit;
  if not RecvExact(Status, 1) then Exit;
  if Status <> S_ACK then
  begin
    FStrError := 'the programmer refused the SPI operation';
    Exit;
  end;
  if RLen > 0 then
    if not RecvExact(RBuffer[0], RLen) then Exit;
  Result := True;
end;

function TSerprogHardware.SPIWrite(CS: byte; BufferLen: integer;
  buffer: array of byte): integer;
var
  Dummy: array[0..0] of byte;
begin
  Result := -1;
  if not FDevOpened then Exit;
  if (BufferLen < 0) or (BufferLen > Length(buffer)) then Exit;

  if QWord(FPendingLen) + QWord(BufferLen) > QWord(FWrnMax) then
  begin
    FStrError := Format('this serprog can only send %d bytes per SPI ' +
                        'operation; the command needs %d',
                        [FWrnMax, FPendingLen + BufferLen]);
    DropPending;
    Exit;
  end;

  if BufferLen > 0 then
  begin
    if Length(FPending) < FPendingLen + BufferLen then
      SetLength(FPending, FPendingLen + BufferLen);
    Move(buffer[0], FPending[FPendingLen], BufferLen);
    Inc(FPendingLen, BufferLen);
  end;

  //CS=0 คือค้างไว้รอเฟสถัดไป ยังไม่แตะสาย CS=1 คือจบธุรกรรม ยิงได้เลย
  if CS = 1 then
  begin
    if not DoSPIOp(0, Dummy) then
    begin
      DropPending;
      Exit;
    end;
    DropPending;
  end;
  Result := BufferLen;
end;

function TSerprogHardware.SPIRead(CS: byte; BufferLen: integer;
  var buffer: array of byte): integer;
begin
  Result := -1;
  if not FDevOpened then Exit;
  if (BufferLen < 0) or (BufferLen > Length(buffer)) then Exit;

  //serprog คุม CS เองต่อธุรกรรม อ่านแล้วขอค้าง CS ต่อทำไม่ได้บนโปรโตคอลนี้
  if CS = 0 then
  begin
    FStrError := 'serprog cannot keep CS asserted after a read; ' +
                 'this chip family is not usable on a serprog';
    DropPending;
    Exit;
  end;
  if cardinal(BufferLen) > FRdnMax then
  begin
    FStrError := Format('this serprog can only read %d bytes per SPI ' +
                        'operation', [FRdnMax]);
    DropPending;
    Exit;
  end;

  if not DoSPIOp(BufferLen, buffer) then
  begin
    DropPending;
    Exit;
  end;
  DropPending;
  Result := BufferLen;
end;

function TSerprogHardware.SPIWriteRead(CS: byte; WBufferLen: integer;
  WBuffer: array of byte; RBufferLen: integer;
  var RBuffer: array of byte): integer;
begin
  Result := -1;
  if not FDevOpened then Exit;
  if (WBufferLen < 0) or (WBufferLen > Length(WBuffer)) or
     (RBufferLen < 0) or (RBufferLen > Length(RBuffer)) then Exit;
  if WBufferLen > 0 then
    if SPIWrite(0, WBufferLen, WBuffer) <> WBufferLen then Exit;
  if RBufferLen = 0 then
  begin
    //ไม่มีเฟสอ่านก็ยังต้องปิดธุรกรรมให้ CS ยก
    if SPIWrite(1, 0, WBuffer) < 0 then Exit;
    Exit(0);
  end;
  Result := SPIRead(CS, RBufferLen, RBuffer);
end;

//I2C: serprog ไม่มีในโปรโตคอล บอกตรง ๆ

procedure TSerprogHardware.I2CInit;
begin
  FStrError := 'serprog has no I2C in its protocol';
end;

procedure TSerprogHardware.I2CDeinit;
begin
end;

function TSerprogHardware.I2CReadWrite(DevAddr: byte;
  WBufferLen: integer; WBuffer: array of byte;
  RBufferLen: integer; var RBuffer: array of byte): integer;
begin
  FStrError := 'serprog has no I2C in its protocol';
  Result := -1;
end;

procedure TSerprogHardware.I2CStart;
begin
end;

procedure TSerprogHardware.I2CStop;
begin
end;

function TSerprogHardware.I2CReadByte(ack: boolean): byte;
begin
  Result := $FF;
end;

function TSerprogHardware.I2CWriteByte(data: byte): boolean;
begin
  Result := False;
end;

function TSerprogHardware.MWInit(speed: integer): boolean;
begin
  FStrError := 'serprog has no MicroWire in its protocol';
  Result := False;
end;

procedure TSerprogHardware.MWDeinit;
begin
end;

function TSerprogHardware.MWRead(CS: byte; BufferLen: integer;
  var buffer: array of byte): integer;
begin
  Result := -1;
end;

function TSerprogHardware.MWWrite(CS: byte; BitsWrite: byte;
  buffer: array of byte): integer;
begin
  Result := -1;
end;

function TSerprogHardware.MWIsBusy: boolean;
begin
  Result := False;
end;

end.
