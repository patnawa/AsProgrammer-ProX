program spi25noradapter_tests;

// Focused wire/lifecycle tests for the real TBaseHardware SPI25 adapter.
// The mock is intentionally below the adapter, at the hardware API boundary,
// so exact CS framing, command bytes, reply counts, identity gates, and cleanup
// ownership are all exercised without LCL or a physical programmer.

{$mode objfpc}{$H+}

uses
  SysUtils, BaseHW, spi25, norengine, spi25noradapter;

type
  TAdapterMockHardware = class(TBaseHardware)
  private
    FTrace: string;
    FLastHeader: TBytes;
    procedure AddTrace(const S: string);
    procedure RememberHeader(const Data: array of byte);
    procedure FillReply(BufferLen: integer; var Buffer: array of byte);
  public
    OpenOK: boolean;
    InitOK: boolean;
    LastErrorText: string;
    OpenCalls: integer;
    CloseCalls: integer;
    InitCalls: integer;
    DeinitCalls: integer;
    WriteCalls: integer;
    ReadCalls: integer;
    ExchangeCalls: integer;
    LastSpeed: integer;
    ShortWriteOnCall: integer;
    ShortReadOnCall: integer;
    ShortExchangeOnCall: integer;
    StatusValue: byte;
    Identity: TSPI25JEDECID;
    AlternateIdentity: TSPI25JEDECID;
    SwitchIdentityAtPass: cardinal;
    IdentityReadCount: cardinal;
    UniqueID: TSPI25UniqueID;
    AlternateUniqueID: TSPI25UniqueID;
    SwitchUniqueIDAtPass: cardinal;
    UniqueIDReadCount: cardinal;

    constructor Create;
    function Trace: string;
    function Saw(const Fragment: string): boolean;

    function GetLastError: string; override;
    function DevOpen: boolean; override;
    procedure DevClose; override;
    function SPIInit(Speed: integer): boolean; override;
    procedure SPIDeinit; override;
    function SPIRead(CS: byte; BufferLen: integer;
      var Buffer: array of byte): integer; override;
    function SPIWrite(CS: byte; BufferLen: integer;
      Buffer: array of byte): integer; override;
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
    function I2CReadByte(Ack: boolean): byte; override;
    function I2CWriteByte(Data: byte): boolean; override;

    function MWInit(Speed: integer): boolean; override;
    procedure MWDeinit; override;
    function MWRead(CS: byte; BufferLen: integer;
      var Buffer: array of byte): integer; override;
    function MWWrite(CS: byte; BitsWrite: byte;
      Buffer: array of byte): integer; override;
    function MWIsBusy: boolean; override;
  end;

var
  Assertions: integer = 0;
  Failures: integer = 0;

procedure Check(const Name: string; Condition: boolean);
begin
  Inc(Assertions);
  if not Condition then
  begin
    Inc(Failures);
    WriteLn('  FAIL  ', Name);
  end;
end;

function BytesHex(const Data: array of byte): string;
var
  i: SizeInt;
begin
  Result := '';
  for i := 0 to High(Data) do
    Result := Result + IntToHex(Data[i], 2);
end;

function MakeID(A, B, C: byte): TSPI25JEDECID;
begin
  Result[0] := A;
  Result[1] := B;
  Result[2] := C;
end;

function SameID(const A, B: TSPI25JEDECID): boolean;
begin
  Result := (A[0] = B[0]) and (A[1] = B[1]) and (A[2] = B[2]);
end;

function MakeUID(A, B, C, D, E, F, G, H: byte): TSPI25UniqueID;
begin
  Result[0] := A;
  Result[1] := B;
  Result[2] := C;
  Result[3] := D;
  Result[4] := E;
  Result[5] := F;
  Result[6] := G;
  Result[7] := H;
end;

procedure ZeroDelays(var Config: TSPI25NORConfig);
begin
  Config.InitDelayMs := 0;
  Config.WakeDelayMs := 0;
end;

constructor TAdapterMockHardware.Create;
begin
  inherited Create;
  FHardwareName := 'adapter-mock';
  FHardwareID := CHW_CH341;
  OpenOK := True;
  InitOK := True;
  StatusValue := 0;
  Identity := MakeID($EF, $40, $17);
  AlternateIdentity := Identity;
  UniqueID := MakeUID($01, $02, $03, $04, $05, $06, $07, $08);
  AlternateUniqueID := UniqueID;
end;

procedure TAdapterMockHardware.AddTrace(const S: string);
begin
  FTrace := FTrace + S + ';';
end;

procedure TAdapterMockHardware.RememberHeader(const Data: array of byte);
begin
  FLastHeader := nil;
  SetLength(FLastHeader, Length(Data));
  if Length(Data) > 0 then Move(Data[0], FLastHeader[0], Length(Data));
end;

procedure TAdapterMockHardware.FillReply(BufferLen: integer;
  var Buffer: array of byte);
var
  i: integer;
  CurrentID: TSPI25JEDECID;
  CurrentUID: TSPI25UniqueID;
begin
  for i := 0 to BufferLen - 1 do Buffer[i] := byte($A0 + (i and $0F));
  if Length(FLastHeader) = 0 then Exit;

  case FLastHeader[0] of
    $9F:
      begin
        Inc(IdentityReadCount);
        CurrentID := Identity;
        if (SwitchIdentityAtPass > 0) and
           (IdentityReadCount >= SwitchIdentityAtPass) then
          CurrentID := AlternateIdentity;
        for i := 0 to BufferLen - 1 do
          if i <= High(CurrentID) then Buffer[i] := CurrentID[i];
      end;

    $05:
      if BufferLen > 0 then Buffer[0] := StatusValue;

    $4B:
      begin
        Inc(UniqueIDReadCount);
        CurrentUID := UniqueID;
        if (SwitchUniqueIDAtPass > 0) and
           (UniqueIDReadCount >= SwitchUniqueIDAtPass) then
          CurrentUID := AlternateUniqueID;
        for i := 0 to BufferLen - 1 do
          if i <= High(CurrentUID) then Buffer[i] := CurrentUID[i];
      end;
  end;
end;

function TAdapterMockHardware.Trace: string;
begin
  Result := FTrace;
end;

function TAdapterMockHardware.Saw(const Fragment: string): boolean;
begin
  Result := Pos(Fragment, FTrace) > 0;
end;

function TAdapterMockHardware.GetLastError: string;
begin
  Result := LastErrorText;
end;

function TAdapterMockHardware.DevOpen: boolean;
begin
  Inc(OpenCalls);
  AddTrace('OPEN');
  Result := OpenOK;
  if not Result and (LastErrorText = '') then
    LastErrorText := 'device not found';
end;

procedure TAdapterMockHardware.DevClose;
begin
  Inc(CloseCalls);
  AddTrace('CLOSE');
end;

function TAdapterMockHardware.SPIInit(Speed: integer): boolean;
begin
  Inc(InitCalls);
  LastSpeed := Speed;
  AddTrace('INIT:' + IntToStr(Speed));
  Result := InitOK;
end;

procedure TAdapterMockHardware.SPIDeinit;
begin
  Inc(DeinitCalls);
  AddTrace('DEINIT');
end;

function TAdapterMockHardware.SPIRead(CS: byte; BufferLen: integer;
  var Buffer: array of byte): integer;
begin
  Inc(ReadCalls);
  AddTrace('R' + IntToStr(CS) + ':' + IntToStr(BufferLen));
  FillReply(BufferLen, Buffer);
  if (ShortReadOnCall > 0) and (ReadCalls = ShortReadOnCall) then
    Result := BufferLen - 1
  else
    Result := BufferLen;
end;

function TAdapterMockHardware.SPIWrite(CS: byte; BufferLen: integer;
  Buffer: array of byte): integer;
begin
  Inc(WriteCalls);
  AddTrace('W' + IntToStr(CS) + ':' + BytesHex(Buffer));
  if CS = 0 then RememberHeader(Buffer);
  if (ShortWriteOnCall > 0) and (WriteCalls = ShortWriteOnCall) then
    Result := BufferLen - 1
  else
    Result := BufferLen;
end;

function TAdapterMockHardware.SPIWriteRead(CS: byte; WBufferLen: integer;
  WBuffer: array of byte; RBufferLen: integer;
  var RBuffer: array of byte): integer;
begin
  Inc(ExchangeCalls);
  AddTrace('X' + IntToStr(CS) + ':' + BytesHex(WBuffer) + '>' +
           IntToStr(RBufferLen));
  RememberHeader(WBuffer);
  FillReply(RBufferLen, RBuffer);
  if (ShortExchangeOnCall > 0) and
     (ExchangeCalls = ShortExchangeOnCall) then
    Result := RBufferLen - 1
  else
    Result := RBufferLen;
end;

procedure TAdapterMockHardware.I2CInit;
begin
end;

procedure TAdapterMockHardware.I2CDeinit;
begin
end;

function TAdapterMockHardware.I2CReadWrite(DevAddr: byte;
  WBufferLen: integer; WBuffer: array of byte; RBufferLen: integer;
  var RBuffer: array of byte): integer;
begin
  Result := 0;
end;

procedure TAdapterMockHardware.I2CStart;
begin
end;

procedure TAdapterMockHardware.I2CStop;
begin
end;

function TAdapterMockHardware.I2CReadByte(Ack: boolean): byte;
begin
  Result := $FF;
end;

function TAdapterMockHardware.I2CWriteByte(Data: byte): boolean;
begin
  Result := False;
end;

function TAdapterMockHardware.MWInit(Speed: integer): boolean;
begin
  Result := False;
end;

procedure TAdapterMockHardware.MWDeinit;
begin
end;

function TAdapterMockHardware.MWRead(CS: byte; BufferLen: integer;
  var Buffer: array of byte): integer;
begin
  Result := 0;
end;

function TAdapterMockHardware.MWWrite(CS: byte; BitsWrite: byte;
  Buffer: array of byte): integer;
begin
  Result := 0;
end;

function TAdapterMockHardware.MWIsBusy: boolean;
begin
  Result := False;
end;

procedure TestStableIdentityAndSplitWireFormat;
var
  Hardware: TAdapterMockHardware;
  Adapter: TSPI25NORAdapter;
  Config: TSPI25NORConfig;
  Expected: TSPI25JEDECID;
  R: TNORIOResult;
  Busy, WEL: boolean;
  Data, Payload: TBytes;
begin
  WriteLn('Stable identity: gate, SPI settings, exact 3-byte wire format');
  Hardware := TAdapterMockHardware.Create;
  Expected := MakeID($EF, $40, $17);
  Hardware.Identity := Expected;
  Hardware.StatusValue := $02;
  InitSPI25NORConfig(Config);
  ZeroDelays(Config);
  Config.SPISpeed := 7;
  Config.SendAB := True;
  RequireSPI25Identity(Config, Expected, 3);
  Adapter := TSPI25NORAdapter.Create(Hardware, Config);
  try
    R := Adapter.Open;
    Check('open succeeds', R.Success);
    R := Adapter.Initialize;
    Check('initialization and identity gate succeed', R.Success);
    Check('configured SPI speed reaches hardware', Hardware.LastSpeed = 7);
    Check('AB wake command is emitted', Hardware.Saw('W1:AB;'));
    Check('JEDEC ID is checked for every configured pass',
          Hardware.IdentityReadCount = 3);
    Check('adapter retains the verified JEDEC ID',
          Adapter.HasLastJEDECID and SameID(Adapter.LastJEDECID, Expected));

    R := Adapter.GetStatus(Busy, WEL);
    Check('status read succeeds', R.Success);
    Check('status bits are decoded', (not Busy) and WEL);

    R := Adapter.Read($123456, 4, Data);
    Check('normal read succeeds with exact reply', R.Success and
          (Length(Data) = 4));
    Check('3-byte read command is big endian',
          Hardware.Saw('W0:03123456;'));

    R := Adapter.WriteEnable;
    Check('WREN succeeds', R.Success and Hardware.Saw('W1:06;'));

    SetLength(Payload, 4);
    Payload[0] := $DE;
    Payload[1] := $AD;
    Payload[2] := $BE;
    Payload[3] := $EF;
    R := Adapter.ProgramPage($123400, Payload);
    Check('page program succeeds', R.Success and (R.Transferred = 4));
    Check('program command and payload keep CS framing',
          Hardware.Saw('W0:02123400;W1:DEADBEEF;'));

    R := Adapter.Erase($120000, $1000, $20);
    Check('erase succeeds', R.Success);
    Check('erase opcode carries a 3-byte address',
          Hardware.Saw('W1:20120000;'));

    R := Adapter.WriteDisable;
    Check('WRDI succeeds', R.Success and Hardware.Saw('W1:04;'));
    R := Adapter.Deinitialize;
    Check('deinitialize succeeds exactly once',
          R.Success and (Hardware.DeinitCalls = 1));
    R := Adapter.Close;
    Check('close succeeds exactly once',
          R.Success and (Hardware.CloseCalls = 1));

    R := Adapter.Deinitialize;
    Check('duplicate deinitialize is rejected without another call',
          (not R.Success) and (R.Error = nioRejected) and
          (Hardware.DeinitCalls = 1));
    R := Adapter.Close;
    Check('duplicate close is rejected without another call',
          (not R.Success) and (R.Error = nioRejected) and
          (Hardware.CloseCalls = 1));
  finally
    Adapter.Free;
    Check('destructor does not repeat completed cleanup',
          (Hardware.DeinitCalls = 1) and (Hardware.CloseCalls = 1));
    Hardware.Free;
  end;
end;

procedure TestFastFourByteCombinedRead;
var
  Hardware: TAdapterMockHardware;
  Adapter: TSPI25NORAdapter;
  Config: TSPI25NORConfig;
  R: TNORIOResult;
  Data, Payload: TBytes;
  WritesBefore: integer;
begin
  WriteLn('Four-byte mode: native opcodes, fast-read dummy, combined exchange');
  Hardware := TAdapterMockHardware.Create;
  InitSPI25NORConfig(Config);
  ZeroDelays(Config);
  DisableSPI25Identity(Config);
  Config.AddressMode := sam4Byte;
  Config.FourByteStrategy := fbsNativeDedicatedOpcodes;
  Config.ReadOpcode := $0C;
  Config.ProgramOpcode := $12;
  Config.FastRead := True;
  Config.ReadTransport := srtCombinedWriteRead;
  Adapter := TSPI25NORAdapter.Create(Hardware, Config);
  try
    Check('open succeeds', Adapter.Open.Success);
    Check('explicitly identity-disabled initialization succeeds',
          Adapter.Initialize.Success);
    Check('disabled identity performs no JEDEC reads',
          Hardware.IdentityReadCount = 0);

    R := Adapter.Read($01234567, 2, Data);
    Check('combined fast read succeeds', R.Success and (Length(Data) = 2));
    Check('4-byte fast read has opcode, address, and one dummy byte',
          Hardware.Saw('X1:0C01234567FF>2;'));

    SetLength(Payload, 2);
    Payload[0] := $55;
    Payload[1] := $AA;
    R := Adapter.ProgramPage($89ABCDEF, Payload);
    Check('native 4-byte page program succeeds', R.Success);
    Check('4-byte program command is big endian',
          Hardware.Saw('W0:1289ABCDEF;W1:55AA;'));

    R := Adapter.Erase($01230000, $10000, $DC);
    Check('native 4-byte erase succeeds', R.Success);
    Check('4-byte erase command is exact',
          Hardware.Saw('W1:DC01230000;'));

    WritesBefore := Hardware.WriteCalls;
    R := Adapter.Erase($01230000, $1000, $20);
    Check('native strategy rejects a legacy 20h erase opcode',
          (not R.Success) and (R.Error = nioRejected));
    Check('rejected legacy erase sends no command',
          Hardware.WriteCalls = WritesBefore);

    R := Adapter.Erase(QWord($100000000), $1000, $DC);
    Check('address beyond four bytes is rejected',
          (not R.Success) and (R.Error = nioRejected));
    Check('rejected address sends no command',
          Hardware.WriteCalls = WritesBefore);

    Check('close defensively deinitializes an active bus',
          Adapter.Close.Success);
    Check('auto cleanup is exactly once',
          (Hardware.DeinitCalls = 1) and (Hardware.CloseCalls = 1));
  finally
    Adapter.Free;
    Hardware.Free;
  end;
end;

procedure TestStatefulFourByteCleanup;
var
  Hardware: TAdapterMockHardware;
  Adapter: TSPI25NORAdapter;
  Config: TSPI25NORConfig;
  R: TNORIOResult;
begin
  WriteLn('Four-byte sessions: B7 strategies always attempt exact E9 cleanup');
  InitSPI25NORConfig(Config);
  ZeroDelays(Config);
  DisableSPI25Identity(Config);
  Config.AddressMode := sam4Byte;
  Config.FourByteStrategy := fbsEnterB7;

  Hardware := TAdapterMockHardware.Create;
  Adapter := TSPI25NORAdapter.Create(Hardware, Config);
  try
    Check('B7 case opens', Adapter.Open.Success);
    Check('B7 session initializes', Adapter.Initialize.Success);
    Check('B7 is sent and state ownership is recorded',
          Hardware.Saw('W1:B7;') and Adapter.FourByteModeActive);
    R := Adapter.Deinitialize;
    Check('B7 session deinitializes successfully', R.Success);
    Check('E9 is sent before SPI deinitialization',
          Hardware.Saw('W1:B7;W1:E9;DEINIT;'));
    Check('successful E9 clears state ownership',
          not Adapter.FourByteModeActive);
    Check('B7 session closes exactly once', Adapter.Close.Success and
          (Hardware.CloseCalls = 1));
  finally
    Adapter.Free;
    Hardware.Free;
  end;

  Config.FourByteStrategy := fbsWriteEnableThenB7;
  Hardware := TAdapterMockHardware.Create;
  Adapter := TSPI25NORAdapter.Create(Hardware, Config);
  try
    Check('WREN+B7 case opens', Adapter.Open.Success);
    Check('WREN+B7 session initializes', Adapter.Initialize.Success);
    Check('WREN is immediately followed by B7',
          Hardware.Saw('W1:06;W1:B7;'));
    Check('close emits E9, clears possible WEL, and deinitializes once',
          Adapter.Close.Success and
          Hardware.Saw('W1:E9;W1:04;DEINIT;CLOSE;') and
          (Hardware.DeinitCalls = 1));
  finally
    Adapter.Free;
    Hardware.Free;
  end;

  Config.FourByteStrategy := fbsEnterB7;
  Hardware := TAdapterMockHardware.Create;
  Hardware.ShortWriteOnCall := 1;
  Adapter := TSPI25NORAdapter.Create(Hardware, Config);
  try
    Check('ambiguous B7 case opens', Adapter.Open.Success);
    R := Adapter.Initialize;
    Check('short B7 cannot pass initialization',
          (not R.Success) and (R.Error = nioTransport));
    Check('ambiguous B7 delivery still triggers E9 and bus rollback',
          Hardware.Saw('W1:B7;W1:E9;DEINIT;') and
          (Hardware.DeinitCalls = 1));
    Check('rollback clears state ownership',
          not Adapter.FourByteModeActive);
    Check('post-rollback close does not repeat E9',
          Adapter.Close.Success and (Hardware.WriteCalls = 2) and
          (Hardware.CloseCalls = 1));
  finally
    Adapter.Free;
    Hardware.Free;
  end;

  Config.FourByteStrategy := fbsWriteEnableThenB7;
  Hardware := TAdapterMockHardware.Create;
  Hardware.ShortWriteOnCall := 1;
  Adapter := TSPI25NORAdapter.Create(Hardware, Config);
  try
    Check('ambiguous entry-WREN case opens', Adapter.Open.Success);
    R := Adapter.Initialize;
    Check('short entry WREN cannot pass initialization',
          (not R.Success) and (R.Error = nioTransport));
    Check('failed entry WREN does not proceed to B7',
          not Hardware.Saw('W1:B7;'));
    Check('ambiguous entry WREN triggers WRDI before rollback',
          Hardware.Saw('W1:06;W1:04;DEINIT;') and
          (Hardware.DeinitCalls = 1));
    Check('WREN rollback session closes once',
          Adapter.Close.Success and (Hardware.CloseCalls = 1));
  finally
    Adapter.Free;
    Hardware.Free;
  end;

  Config.FourByteStrategy := fbsEnterB7;
  Hardware := TAdapterMockHardware.Create;
  Adapter := TSPI25NORAdapter.Create(Hardware, Config);
  try
    Check('E9-failure case opens', Adapter.Open.Success);
    Check('E9-failure session initializes', Adapter.Initialize.Success);
    Hardware.ShortWriteOnCall := Hardware.WriteCalls + 1;
    R := Adapter.Deinitialize;
    Check('short E9 is reported as a transport failure',
          (not R.Success) and (R.Error = nioTransport));
    Check('SPI deinitialize still runs after failed E9',
          Hardware.DeinitCalls = 1);
    Check('close never retries an ambiguous E9',
          Adapter.Close.Success and (Hardware.WriteCalls = 2) and
          (Hardware.CloseCalls = 1));
  finally
    Adapter.Free;
    Hardware.Free;
  end;
end;

procedure TestIdentityFailuresBlockMutation;
var
  Hardware: TAdapterMockHardware;
  Adapter: TSPI25NORAdapter;
  Config: TSPI25NORConfig;
  Expected: TSPI25JEDECID;
  R: TNORIOResult;
begin
  WriteLn('Identity gate: swapped and unstable chips fail before mutation');
  Expected := MakeID($EF, $40, $17);

  Hardware := TAdapterMockHardware.Create;
  Hardware.Identity := MakeID($C2, $20, $18);
  InitSPI25NORConfig(Config);
  ZeroDelays(Config);
  RequireSPI25Identity(Config, Expected, 4);
  Adapter := TSPI25NORAdapter.Create(Hardware, Config);
  try
    Check('mismatch case opens', Adapter.Open.Success);
    R := Adapter.Initialize;
    Check('swapped chip is rejected', (not R.Success) and
          (R.Error = nioRejected) and
          (Pos('mismatch', LowerCase(R.ErrorText)) > 0));
    Check('failed initialization rolls SPI back once',
          Hardware.DeinitCalls = 1);
    R := Adapter.WriteEnable;
    Check('WREN remains blocked after identity failure',
          (not R.Success) and (R.Error = nioRejected) and
          (not Hardware.Saw('W1:06;')));
    Check('close after rollback closes once', Adapter.Close.Success and
          (Hardware.CloseCalls = 1));
  finally
    Adapter.Free;
    Hardware.Free;
  end;

  Hardware := TAdapterMockHardware.Create;
  Hardware.Identity := Expected;
  Hardware.AlternateIdentity := MakeID($EF, $40, $18);
  Hardware.SwitchIdentityAtPass := 2;
  Adapter := TSPI25NORAdapter.Create(Hardware, Config);
  try
    Check('unstable case opens', Adapter.Open.Success);
    R := Adapter.Initialize;
    Check('changing JEDEC ID is rejected as unstable',
          (not R.Success) and (R.Error = nioRejected) and
          (Pos('unstable', LowerCase(R.ErrorText)) > 0));
    Check('unstable check stops on the second pass',
          Hardware.IdentityReadCount = 2);
    Check('unstable identity rollback deinitializes once',
          Hardware.DeinitCalls = 1);
    Check('unstable session closes once', Adapter.Close.Success and
          (Hardware.CloseCalls = 1));
  finally
    Adapter.Free;
    Hardware.Free;
  end;
end;

procedure TestUniqueIDSwapRejectedBeforeMutation;
var
  Hardware: TAdapterMockHardware;
  Adapter: TSPI25NORAdapter;
  Config: TSPI25NORConfig;
  Expected: TSPI25JEDECID;
  R: TNORIOResult;
  Err: string;
begin
  WriteLn('Unique-ID gate: same-JEDEC chip swap is rejected before WREN');
  Expected := MakeID($EF, $40, $17);
  Hardware := TAdapterMockHardware.Create;
  Hardware.Identity := Expected;
  //The trusted preflight session admitted 0102030405060708.  The second
  //session now sees a different physical part with the same JEDEC ID.
  Hardware.UniqueID :=
    MakeUID($11, $12, $13, $14, $15, $16, $17, $18);
  InitSPI25NORConfig(Config);
  ZeroDelays(Config);
  RequireSPI25Identity(Config, Expected, 2);
  Check('exact expected UID configures the second-session gate',
        RequireSPI25UniqueIdentity(Config, '0102030405060708', 2, Err));
  Adapter := TSPI25NORAdapter.Create(Hardware, Config);
  try
    Check('UID-swap case opens', Adapter.Open.Success);
    R := Adapter.Initialize;
    Check('same-JEDEC different-UID chip is rejected',
          (not R.Success) and (R.Error = nioRejected) and
          (Pos('unique-ID mismatch', R.ErrorText) > 0));
    Check('JEDEC remained stable across the configured passes',
          Hardware.IdentityReadCount = 2);
    Check('the exact 4Bh UID transaction ran before rejection',
          (Hardware.UniqueIDReadCount = 1) and
          Hardware.Saw('W0:4B00000000;R1:8;'));
    Check('identity rejection rolls the bus back once',
          Hardware.DeinitCalls = 1);
    R := Adapter.WriteEnable;
    Check('WREN is blocked after the UID mismatch',
          (not R.Success) and (R.Error = nioRejected) and
          (not Hardware.Saw('W1:06;')));
    Check('rejected UID session closes exactly once',
          Adapter.Close.Success and (Hardware.CloseCalls = 1));
  finally
    Adapter.Free;
    Hardware.Free;
  end;
end;

procedure TestExactCountsAndDisconnectMapping;
var
  Hardware: TAdapterMockHardware;
  Adapter: TSPI25NORAdapter;
  Config: TSPI25NORConfig;
  R: TNORIOResult;
  Data: TBytes;
  Busy, WEL: boolean;
begin
  WriteLn('Failures: short transfers and missing devices are typed and closed');
  InitSPI25NORConfig(Config);
  ZeroDelays(Config);
  DisableSPI25Identity(Config);
  Hardware := TAdapterMockHardware.Create;
  Adapter := TSPI25NORAdapter.Create(Hardware, Config);
  try
    Check('open succeeds', Adapter.Open.Success);
    Check('initialize succeeds', Adapter.Initialize.Success);

    Hardware.ShortWriteOnCall := Hardware.WriteCalls + 1;
    R := Adapter.WriteEnable;
    Check('short WREN is a transport failure',
          (not R.Success) and (R.Error = nioTransport));
    Hardware.ShortWriteOnCall := 0;

    Hardware.ShortReadOnCall := Hardware.ReadCalls + 1;
    R := Adapter.Read(0, 8, Data);
    Check('short read is a transport failure',
          (not R.Success) and (R.Error = nioTransport));
    Check('failed read exposes no partial buffer', Length(Data) = 0);
    Hardware.ShortReadOnCall := 0;

    Hardware.StatusValue := $FF;
    R := Adapter.GetStatus(Busy, WEL);
    Check('all-FF status is mapped to disconnected',
          (not R.Success) and (R.Error = nioDisconnected));

    Check('normal close still cleans up once', Adapter.Close.Success and
          (Hardware.DeinitCalls = 1) and (Hardware.CloseCalls = 1));
  finally
    Adapter.Free;
    Hardware.Free;
  end;

  Hardware := TAdapterMockHardware.Create;
  Hardware.OpenOK := False;
  Hardware.LastErrorText := 'device not found';
  Adapter := TSPI25NORAdapter.Create(Hardware, Config);
  try
    R := Adapter.Open;
    Check('missing programmer maps to disconnected',
          (not R.Success) and (R.Error = nioDisconnected));
    Check('failed open is attempted once and never closed',
          (Hardware.OpenCalls = 1) and (Hardware.CloseCalls = 0));
  finally
    Adapter.Free;
    Hardware.Free;
  end;
end;

procedure TestIdentityConfigurationMustBeExplicit;
var
  Config: TSPI25NORConfig;
  Identity: MEMORY_ID;
  Err: string;
begin
  WriteLn('Configuration: identity enforcement cannot be accidentally omitted');
  InitSPI25NORConfig(Config);
  Check('default unspecified identity policy is invalid',
        not ValidateSPI25NORConfig(Config, Err));
  DisableSPI25Identity(Config);
  Check('explicit disable is valid',
        ValidateSPI25NORConfig(Config, Err));

  Config.AddressMode := sam4Byte;
  Check('four-byte width without a strategy fails closed',
        not ValidateSPI25NORConfig(Config, Err));

  InitSPI25NORConfig(Config);
  FillChar(Identity, SizeOf(Identity), 0);
  Check('MEMORY_ID without a successful 9F read is rejected',
        not RequireSPI25MemoryIdentity(Config, Identity, 8, Err));
  Identity.Got9F := True;
  Identity.ID9FH[0] := $EF;
  Identity.ID9FH[1] := $40;
  Identity.ID9FH[2] := $17;
  Check('successful preflight identity configures the gate',
        RequireSPI25MemoryIdentity(Config, Identity, 8, Err));
  Check('preflight-derived identity config validates',
        ValidateSPI25NORConfig(Config, Err));
end;

begin
  WriteLn('AsProgrammer SPI25 real-hardware adapter tests');
  WriteLn;

  TestStableIdentityAndSplitWireFormat;
  TestFastFourByteCombinedRead;
  TestStatefulFourByteCleanup;
  TestIdentityFailuresBlockMutation;
  TestUniqueIDSwapRejectedBeforeMutation;
  TestExactCountsAndDisconnectMapping;
  TestIdentityConfigurationMustBeExplicit;

  WriteLn;
  WriteLn(Assertions, ' assertions, ', Failures, ' failures');
  if Failures = 0 then WriteLn('ALL PASSED');
  Halt(Failures);
end.
