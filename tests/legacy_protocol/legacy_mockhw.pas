unit legacy_mockhw;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, BaseHW;

type
  TI2CTransaction = record
    DevAddr: byte;
    WriteLen: integer;
    ReadLen: integer;
    WriteData: array of byte;
  end;

  TMWTransaction = record
    KeepCS: byte;
    BitLen: byte;
    Data: array of byte;
  end;

  TLegacyMockHardware = class(TBaseHardware)
  private
    FSPIBytes: array of byte;
    FSPIReply: array of byte;
    FSPIReplyPos: integer;
    FPollDevAddr: array of byte;
  public
    I2CTransactions: array of TI2CTransaction;
    MWTransactions: array of TMWTransaction;

    FailSPIReads: boolean;
    FailSPIWriteCall: integer;
    SPIWriteCalls: integer;
    SPIReadCalls: integer;
    SPICombinedCalls: integer;
    ShortSPIWriteCall: integer;
    ShortSPIWriteCount: integer;
    ShortSPIReadCall: integer;
    ShortSPIReadCount: integer;
    ShortSPICombinedCall: integer;
    ShortSPICombinedCount: integer;
    FailI2C: boolean;
    AlwaysNack: boolean;
    NackPollsRemaining: integer;
    FailMWWriteCall: integer;
    MWWriteCalls: integer;
    BusyPollsRemaining: integer;

    constructor Create;
    procedure Reset;
    procedure UseSplitTransport;
    procedure UseCombinedTransport;
    procedure SetSPIReply(const Bytes: array of byte);
    function SPITranscript: string;
    function SPIByte(Index: integer): byte;
    function PollCount: integer;
    function PollDevAddr(Index: integer): byte;

    function GetLastError: string; override;
    function DevOpen: boolean; override;
    procedure DevClose; override;

    function SPIInit(speed: integer): boolean; override;
    procedure SPIDeinit; override;
    function SPIRead(CS: byte; BufferLen: integer;
      var buffer: array of byte): integer; override;
    function SPIWrite(CS: byte; BufferLen: integer;
      buffer: array of byte): integer; override;
    function SPIWriteRead(CS: byte; WBufferLen: integer;
      WBuffer: array of byte; RBufferLen: integer;
      var RBuffer: array of byte): integer; override;

    procedure I2CInit; override;
    procedure I2CDeinit; override;
    function I2CReadWrite(DevAddr: byte; WBufferLen: integer;
      WBuffer: array of byte; RBufferLen: integer;
      var RBuffer: array of byte): integer; override;
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

function InstallLegacyMock: TLegacyMockHardware;

implementation

var
  LegacyMock: TLegacyMockHardware = nil;

constructor TLegacyMockHardware.Create;
begin
  inherited Create;
  FHardwareName := 'Legacy protocol mock';
  FHardwareID := CHW_CH341;
  Reset;
end;

procedure TLegacyMockHardware.Reset;
begin
  FHardwareID := CHW_CH341;
  SetLength(FSPIBytes, 0);
  SetLength(FSPIReply, 0);
  FSPIReplyPos := 0;
  SetLength(FPollDevAddr, 0);
  SetLength(I2CTransactions, 0);
  SetLength(MWTransactions, 0);
  FailSPIReads := False;
  FailSPIWriteCall := 0;
  SPIWriteCalls := 0;
  SPIReadCalls := 0;
  SPICombinedCalls := 0;
  ShortSPIWriteCall := 0;
  ShortSPIWriteCount := 0;
  ShortSPIReadCall := 0;
  ShortSPIReadCount := 0;
  ShortSPICombinedCall := 0;
  ShortSPICombinedCount := 0;
  FailI2C := False;
  AlwaysNack := False;
  NackPollsRemaining := 0;
  FailMWWriteCall := 0;
  MWWriteCalls := 0;
  BusyPollsRemaining := 0;
end;

procedure TLegacyMockHardware.UseSplitTransport;
begin
  FHardwareID := CHW_CH341;
  AsProgrammer.Current_HW := CHW_CH341;
end;

procedure TLegacyMockHardware.UseCombinedTransport;
begin
  FHardwareID := CHW_BUZZPIRAT;
  AsProgrammer.Current_HW := CHW_BUZZPIRAT;
end;

procedure TLegacyMockHardware.SetSPIReply(const Bytes: array of byte);
var
  i: integer;
begin
  SetLength(FSPIReply, Length(Bytes));
  for i := 0 to High(Bytes) do FSPIReply[i] := Bytes[i];
  FSPIReplyPos := 0;
end;

function TLegacyMockHardware.SPITranscript: string;
var
  i: integer;
begin
  Result := '';
  for i := 0 to High(FSPIBytes) do
    Result := Result + IntToHex(FSPIBytes[i], 2);
end;

function TLegacyMockHardware.SPIByte(Index: integer): byte;
begin
  if (Index < 0) or (Index > High(FSPIBytes)) then Exit(0);
  Result := FSPIBytes[Index];
end;

function TLegacyMockHardware.PollCount: integer;
begin
  Result := Length(FPollDevAddr);
end;

function TLegacyMockHardware.PollDevAddr(Index: integer): byte;
begin
  if (Index < 0) or (Index > High(FPollDevAddr)) then Exit(0);
  Result := FPollDevAddr[Index];
end;

function TLegacyMockHardware.GetLastError: string;
begin
  Result := '';
end;

function TLegacyMockHardware.DevOpen: boolean;
begin
  Result := True;
end;

procedure TLegacyMockHardware.DevClose;
begin
end;

function TLegacyMockHardware.SPIInit(speed: integer): boolean;
begin
  Result := True;
end;

procedure TLegacyMockHardware.SPIDeinit;
begin
end;

function TLegacyMockHardware.SPIRead(CS: byte; BufferLen: integer;
  var buffer: array of byte): integer;
var
  Count, i: integer;
begin
  Inc(SPIReadCalls);
  if FailSPIReads then Exit(0);

  Count := BufferLen;
  if (ShortSPIReadCall > 0) and (SPIReadCalls = ShortSPIReadCall) then
  begin
    Count := ShortSPIReadCount;
    if Count < 0 then Count := 0;
    if Count > BufferLen then Count := BufferLen;
  end;

  for i := 0 to Count - 1 do
  begin
    if FSPIReplyPos <= High(FSPIReply) then
    begin
      buffer[i] := FSPIReply[FSPIReplyPos];
      Inc(FSPIReplyPos);
    end
    else
      buffer[i] := $FF;
  end;
  Result := Count;
end;

function TLegacyMockHardware.SPIWrite(CS: byte; BufferLen: integer;
  buffer: array of byte): integer;
var
  Base, Count, i: integer;
begin
  Inc(SPIWriteCalls);
  if (FailSPIWriteCall > 0) and (SPIWriteCalls = FailSPIWriteCall) then
    Exit(0);

  Count := BufferLen;
  if (ShortSPIWriteCall > 0) and (SPIWriteCalls = ShortSPIWriteCall) then
  begin
    Count := ShortSPIWriteCount;
    if Count < 0 then Count := 0;
    if Count > BufferLen then Count := BufferLen;
  end;

  Base := Length(FSPIBytes);
  SetLength(FSPIBytes, Base + Count);
  for i := 0 to Count - 1 do
    FSPIBytes[Base + i] := buffer[i];
  Result := Count;
end;

function TLegacyMockHardware.SPIWriteRead(CS: byte; WBufferLen: integer;
  WBuffer: array of byte; RBufferLen: integer;
  var RBuffer: array of byte): integer;
var
  Base, Count, i: integer;
begin
  Inc(SPICombinedCalls);

  Base := Length(FSPIBytes);
  SetLength(FSPIBytes, Base + WBufferLen);
  for i := 0 to WBufferLen - 1 do
    FSPIBytes[Base + i] := WBuffer[i];

  Count := RBufferLen;
  if (ShortSPICombinedCall > 0) and
     (SPICombinedCalls = ShortSPICombinedCall) then
  begin
    Count := ShortSPICombinedCount;
    if Count < 0 then Count := 0;
    if Count > RBufferLen then Count := RBufferLen;
  end;

  for i := 0 to Count - 1 do
  begin
    if FSPIReplyPos <= High(FSPIReply) then
    begin
      RBuffer[i] := FSPIReply[FSPIReplyPos];
      Inc(FSPIReplyPos);
    end
    else
      RBuffer[i] := $FF;
  end;
  Result := Count;
end;

procedure TLegacyMockHardware.I2CInit;
begin
end;

procedure TLegacyMockHardware.I2CDeinit;
begin
end;

function TLegacyMockHardware.I2CReadWrite(DevAddr: byte;
  WBufferLen: integer; WBuffer: array of byte; RBufferLen: integer;
  var RBuffer: array of byte): integer;
var
  Index, i: integer;
begin
  if FailI2C then Exit(-1);

  Index := Length(I2CTransactions);
  SetLength(I2CTransactions, Index + 1);
  I2CTransactions[Index].DevAddr := DevAddr;
  I2CTransactions[Index].WriteLen := WBufferLen;
  I2CTransactions[Index].ReadLen := RBufferLen;
  SetLength(I2CTransactions[Index].WriteData, WBufferLen);
  for i := 0 to WBufferLen - 1 do
    I2CTransactions[Index].WriteData[i] := WBuffer[i];
  for i := 0 to RBufferLen - 1 do
    RBuffer[i] := byte($10 + Index + i);

  Result := WBufferLen + RBufferLen;
end;

procedure TLegacyMockHardware.I2CStart;
begin
end;

procedure TLegacyMockHardware.I2CStop;
begin
end;

function TLegacyMockHardware.I2CReadByte(ack: boolean): byte;
begin
  Result := $FF;
end;

function TLegacyMockHardware.I2CWriteByte(data: byte): boolean;
var
  Index: integer;
begin
  Index := Length(FPollDevAddr);
  SetLength(FPollDevAddr, Index + 1);
  FPollDevAddr[Index] := data;

  if AlwaysNack then Exit(False);
  if NackPollsRemaining > 0 then
  begin
    Dec(NackPollsRemaining);
    Exit(False);
  end;
  Result := True;
end;

function TLegacyMockHardware.MWInit(speed: integer): boolean;
begin
  Result := True;
end;

procedure TLegacyMockHardware.MWDeinit;
begin
end;

function TLegacyMockHardware.MWRead(CS: byte; BufferLen: integer;
  var buffer: array of byte): integer;
var
  i: integer;
begin
  for i := 0 to BufferLen - 1 do buffer[i] := byte($A0 + i);
  Result := BufferLen;
end;

function TLegacyMockHardware.MWWrite(CS: byte; BitsWrite: byte;
  buffer: array of byte): integer;
var
  Index, Count, i: integer;
begin
  Inc(MWWriteCalls);
  if (FailMWWriteCall > 0) and (MWWriteCalls = FailMWWriteCall) then
    Exit(0);

  Index := Length(MWTransactions);
  SetLength(MWTransactions, Index + 1);
  MWTransactions[Index].KeepCS := CS;
  MWTransactions[Index].BitLen := BitsWrite;
  Count := (integer(BitsWrite) + 7) div 8;
  SetLength(MWTransactions[Index].Data, Count);
  for i := 0 to Count - 1 do MWTransactions[Index].Data[i] := buffer[i];
  Result := BitsWrite;
end;

function TLegacyMockHardware.MWIsBusy: boolean;
begin
  Result := BusyPollsRemaining > 0;
  if BusyPollsRemaining > 0 then Dec(BusyPollsRemaining);
end;

function InstallLegacyMock: TLegacyMockHardware;
begin
  if AsProgrammer = nil then AsProgrammer := TAsProgrammer.Create;
  if LegacyMock = nil then
  begin
    LegacyMock := TLegacyMockHardware.Create;
    AsProgrammer.AddHW(LegacyMock);
  end;
  LegacyMock.Reset;
  AsProgrammer.Current_HW := CHW_CH341;
  Result := LegacyMock;
end;

end.
