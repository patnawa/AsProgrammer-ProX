unit mockhw;

{ A programmer that exists only in memory.

  Every byte the protocol layer sends is appended to a transcript, so a test
  can assert on the exact opcodes that went down the wire. That is the whole
  point: the interesting bugs in a chip programmer are not "did it compute the
  right number", they are "did it send an opcode this chip has never heard of".

  Reads come back from a small script of canned answers, which is enough for
  status register polling and for reading an id. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, BaseHW;

type

  TMockHardware = class(TBaseHardware)
  private
    FSent: array of byte;
    FReply: array of byte;
    FReplyPos: integer;
    FReadCalls: integer;
  public
    //จำลองชิปที่ไม่ตอบ ซ็อกเก็ตว่าง คลิปหนีบไม่ติด หรือชิปไม่ได้รับไฟ
    //การอ่านจะคืน 0 และไม่แตะบัฟเฟอร์เลย ซึ่งเป็นพฤติกรรมจริงของสายที่เงียบ
    //และเป็นเงื่อนไขที่ทำให้ค่าที่ค้างอยู่ในบัฟเฟอร์ถูกรายงานผิดเป็นคำตอบ
    FailReads: boolean;
    //One-shot transport faults used by adapter tests. -1/0 disables them.
    //A short write still records every supplied byte because the dangerous
    //case is precisely that the backend cannot tell how much reached silicon.
    ShortWriteOpcode: integer;
    ShortReadAtCall: integer;

    constructor Create;

    procedure Reset;

    //ทุกไบต์ที่ถูกส่งออกไป เรียงตามลำดับ เป็นเลขฐานสิบหกต่อกัน
    function Transcript: string;
    //ไบต์ที่จะตอบกลับเมื่อมีการอ่าน
    procedure SetReply(const Bytes: array of byte);
    //opcode นี้ถูกส่งออกไปหรือไม่ ดูเฉพาะไบต์แรกของแต่ละคำสั่ง
    function Sent(Opcode: byte): boolean;
    //ลำดับ opcode สองตัวนี้ถูกส่งติดกันหรือไม่
    function SentInOrder(First, Second: byte): boolean;
    function SentCount: integer;

    function GetLastError: string; override;
    function DevOpen: boolean; override;
    procedure DevClose; override;

    function SPIInit(speed: integer): boolean; override;
    procedure SPIDeinit; override;
    function SPIRead(CS: byte; BufferLen: integer; var buffer: array of byte): integer; override;
    function SPIWrite(CS: byte; BufferLen: integer; buffer: array of byte): integer; override;
    function SPIWriteRead(CS: byte; WBufferLen: integer; WBuffer: array of byte;
      RBufferLen: integer; var RBuffer: array of byte): integer; override;

    procedure I2CInit; override;
    procedure I2CDeinit; override;
    function I2CReadWrite(DevAddr: byte; WBufferLen: integer; WBuffer: array of byte;
      RBufferLen: integer; var RBuffer: array of byte): integer; override;
    procedure I2CStart; override;
    procedure I2CStop; override;
    function I2CReadByte(ack: boolean): byte; override;
    function I2CWriteByte(data: byte): boolean; override;

    function MWInit(speed: integer): boolean; override;
    procedure MWDeinit; override;
    function MWRead(CS: byte; BufferLen: integer; var buffer: array of byte): integer; override;
    function MWWrite(CS: byte; BitsWrite: byte; buffer: array of byte): integer; override;
    function MWIsBusy: boolean; override;
  end;

//สร้าง AsProgrammer ที่ผูกกับฮาร์ดแวร์จำลอง คืนตัวจำลองไว้ให้ตรวจสอบ
function InstallMockProgrammer: TMockHardware;

implementation

var
  //ตัวจำลองถูกยึดโดย TAsProgrammer ซึ่งจะ Free ให้เอง เก็บอ้างอิงไว้ตรวจสอบ
  TheMock: TMockHardware = nil;

constructor TMockHardware.Create;
begin
  inherited Create;
  FHardwareName := 'Mock';
  //ยืมรหัสของ CH341 มาใช้ เพราะเส้นทางโค้ดของมันคือเส้นทางปกติ
  //ไม่ใช่เส้นทางพิเศษของ Buzzpirat ที่รวมเขียนกับอ่านเป็นคำสั่งเดียว
  FHardwareID := CHW_CH341;
  Reset;
end;

procedure TMockHardware.Reset;
begin
  SetLength(FSent, 0);
  SetLength(FReply, 0);
  FReplyPos := 0;
  FailReads := False;
  ShortWriteOpcode := -1;
  ShortReadAtCall := 0;
  FReadCalls := 0;
end;

function TMockHardware.Transcript: string;
var
  i: integer;
begin
  Result := '';
  for i := 0 to High(FSent) do
    Result := Result + IntToHex(FSent[i], 2);
end;

procedure TMockHardware.SetReply(const Bytes: array of byte);
var
  i: integer;
begin
  SetLength(FReply, Length(Bytes));
  for i := 0 to High(Bytes) do FReply[i] := Bytes[i];
  FReplyPos := 0;
end;

function TMockHardware.SentCount: integer;
begin
  Result := Length(FSent);
end;

function TMockHardware.Sent(Opcode: byte): boolean;
var
  i: integer;
begin
  Result := False;
  for i := 0 to High(FSent) do
    if FSent[i] = Opcode then Exit(True);
end;

function TMockHardware.SentInOrder(First, Second: byte): boolean;
var
  i, j: integer;
begin
  Result := False;
  for i := 0 to High(FSent) do
    if FSent[i] = First then
      for j := i + 1 to High(FSent) do
        if FSent[j] = Second then Exit(True);
end;

function TMockHardware.GetLastError: string;
begin
  Result := '';
end;

function TMockHardware.DevOpen: boolean;
begin
  Result := True;
end;

procedure TMockHardware.DevClose;
begin
end;

function TMockHardware.SPIInit(speed: integer): boolean;
begin
  Result := True;
end;

procedure TMockHardware.SPIDeinit;
begin
end;

function TMockHardware.SPIRead(CS: byte; BufferLen: integer;
  var buffer: array of byte): integer;
var
  i: integer;
begin
  Inc(FReadCalls);
  //สายเงียบ ไม่มีอะไรถูกเขียนลงบัฟเฟอร์ และคืนศูนย์ไบต์
  if FailReads or ((ShortReadAtCall > 0) and
     (FReadCalls = ShortReadAtCall)) then Exit(0);

  for i := 0 to BufferLen - 1 do
  begin
    if FReplyPos <= High(FReply) then
    begin
      buffer[i] := FReply[FReplyPos];
      Inc(FReplyPos);
    end
    else
      buffer[i] := $FF;
  end;
  Result := BufferLen;
end;

function TMockHardware.SPIWrite(CS: byte; BufferLen: integer;
  buffer: array of byte): integer;
var
  i, Base: integer;
begin
  Base := Length(FSent);
  SetLength(FSent, Base + BufferLen);
  for i := 0 to BufferLen - 1 do
    FSent[Base + i] := buffer[i];
  if (BufferLen > 0) and (ShortWriteOpcode >= 0) and
     (buffer[0] = byte(ShortWriteOpcode)) then
  begin
    ShortWriteOpcode := -1;
    Exit(BufferLen - 1);
  end;
  Result := BufferLen;
end;

function TMockHardware.SPIWriteRead(CS: byte; WBufferLen: integer;
  WBuffer: array of byte; RBufferLen: integer; var RBuffer: array of byte): integer;
begin
  SPIWrite(CS, WBufferLen, WBuffer);
  Result := SPIRead(CS, RBufferLen, RBuffer);
end;

procedure TMockHardware.I2CInit;
begin
end;

procedure TMockHardware.I2CDeinit;
begin
end;

function TMockHardware.I2CReadWrite(DevAddr: byte; WBufferLen: integer;
  WBuffer: array of byte; RBufferLen: integer; var RBuffer: array of byte): integer;
begin
  Result := 0;
end;

procedure TMockHardware.I2CStart;
begin
end;

procedure TMockHardware.I2CStop;
begin
end;

function TMockHardware.I2CReadByte(ack: boolean): byte;
begin
  Result := $FF;
end;

function TMockHardware.I2CWriteByte(data: byte): boolean;
begin
  Result := True;
end;

function TMockHardware.MWInit(speed: integer): boolean;
begin
  Result := True;
end;

procedure TMockHardware.MWDeinit;
begin
end;

function TMockHardware.MWRead(CS: byte; BufferLen: integer;
  var buffer: array of byte): integer;
begin
  Result := 0;
end;

function TMockHardware.MWWrite(CS: byte; BitsWrite: byte;
  buffer: array of byte): integer;
begin
  Result := 0;
end;

function TMockHardware.MWIsBusy: boolean;
begin
  Result := False;
end;

function InstallMockProgrammer: TMockHardware;
begin
  if AsProgrammer = nil then AsProgrammer := TAsProgrammer.Create;

  if TheMock = nil then
  begin
    TheMock := TMockHardware.Create;
    AsProgrammer.AddHW(TheMock);
  end;

  AsProgrammer.Current_HW := CHW_CH341;
  TheMock.Reset;
  Result := TheMock;
end;

end.
