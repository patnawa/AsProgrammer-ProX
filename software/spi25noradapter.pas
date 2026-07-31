unit spi25noradapter;

// Headless real-hardware adapter between TNORDevice and the existing
// TBaseHardware/SPI25 transport conventions.
//
// The adapter deliberately receives the selected TBaseHardware instance
// instead of reaching through a form or the global programmer selector.  It
// owns that instance's DevOpen/SPIInit/SPIDeinit/DevClose lifecycle, but it does
// not own or free the hardware object itself.
//
// Identity enforcement is fail closed.  A caller must either configure an
// expected three-byte 9Fh JEDEC ID and at least two identical passes, or
// explicitly disable the gate.  Leaving the policy unspecified is invalid.
// This matters when a trusted preflight snapshot is followed by a new executor
// session: the reopened session checks that the same stable chip is present
// before WREN, erase, or page program can be sent.

{$mode objfpc}{$H+}

interface

uses
  SysUtils, BaseHW, spi25, norengine;

type
  TSPI25AddressMode = (
    samUnspecified,
    sam3Byte,
    sam4Byte
  );

  // Most programmers keep CS asserted by using SPIWrite(CS=0) followed by
  // SPIRead(CS=1).  Hardware such as Bus Pirate needs one combined exchange.
  TSPI25ReadTransport = (
    srtSplitWriteRead,
    srtCombinedWriteRead
  );

  // Four address bytes alone are not enough to make a command safe.  A chip
  // either accepts dedicated stateless 4-byte opcodes (13h/12h/21h/DC, etc.),
  // or the session must explicitly enter a stateful 4-byte address mode.
  TSPI25FourByteStrategy = (
    fbsNotApplicable,
    fbsNativeDedicatedOpcodes,
    fbsEnterB7,
    fbsWriteEnableThenB7
  );

  TSPI25IdentityMode = (
    simUnspecified,
    simRequireExpected,
    simExplicitlyDisabled
  );

  TSPI25JEDECID = array[0..2] of byte;
  TSPI25UniqueID = array[0..7] of byte;

  TSPI25NORConfig = record
    SPISpeed: integer;
    SendAB: boolean;
    AddressMode: TSPI25AddressMode;
    ReadOpcode: byte;
    ProgramOpcode: byte;
    FastRead: boolean;
    ReadTransport: TSPI25ReadTransport;
    FourByteStrategy: TSPI25FourByteStrategy;

    IdentityMode: TSPI25IdentityMode;
    ExpectedJEDECID: TSPI25JEDECID;
    IdentityPasses: cardinal;
    RequireUniqueID: boolean;
    ExpectedUniqueID: TSPI25UniqueID;
    UniqueIDPasses: cardinal;

    // Existing EnterProgMode25 waits for the programmer/chip to settle.
    // They remain configurable so deterministic tests do not have to sleep.
    InitDelayMs: cardinal;
    WakeDelayMs: cardinal;
  end;

  TSPI25NORAdapter = class(TNORDevice)
  private
    FHardware: TBaseHardware;
    FConfig: TSPI25NORConfig;
    FOpened: boolean;
    FBusActive: boolean;
    FInitialized: boolean;
    FIdentityGatePassed: boolean;
    FFourByteModeActive: boolean;
    FWriteEnableMayBeSet: boolean;
    FHasLastJEDECID: boolean;
    FLastJEDECID: TSPI25JEDECID;

    function HardwareErrorText: string;
    function TransferResult(const Context: string; Actual,
      Expected: integer): TNORIOResult;
    function ExceptionResult(const Context: string;
      E: Exception): TNORIOResult;
    function RequireInitialized(const Context: string;
      out R: TNORIOResult): boolean;
    function RequireMutationReady(const Context: string;
      out R: TNORIOResult): boolean;
    function WriteExact(CS: byte; const Data: TBytes;
      const Context: string): TNORIOResult;
    function ReadExact(CS: byte; Len: cardinal; out Data: TBytes;
      const Context: string): TNORIOResult;
    function ExchangeExact(const Header: TBytes; Len: cardinal;
      out Data: TBytes; const Context: string): TNORIOResult;
    function SendOneByte(Value: byte;
      const Context: string): TNORIOResult;
    function AddressLimit: QWord;
    function CheckRange(Address: QWord; Len: cardinal;
      const Context: string): TNORIOResult;
    function BuildAddressHeader(Opcode: byte; Address: QWord;
      AddDummyByte: boolean; out Header: TBytes;
      const Context: string): TNORIOResult;
    function CheckIdentity: TNORIOResult;
    function EnterConfiguredAddressMode: TNORIOResult;
    function StopBus: TNORIOResult;
    procedure AppendRollbackError(var Primary: TNORIOResult;
      const Cleanup: TNORIOResult);
  public
    constructor Create(Hardware: TBaseHardware;
      const Config: TSPI25NORConfig);
    destructor Destroy; override;

    function Open: TNORIOResult; override;
    function Initialize: TNORIOResult; override;
    function GetStatus(out Busy, WriteEnabled: boolean): TNORIOResult; override;
    function WriteEnable: TNORIOResult; override;
    function WriteDisable: TNORIOResult; override;
    function Erase(Address: QWord; Len: cardinal;
      Opcode: byte): TNORIOResult; override;
    function ProgramPage(Address: QWord;
      const Data: TBytes): TNORIOResult; override;
    function Read(Address: QWord; Len: cardinal;
      out Data: TBytes): TNORIOResult; override;
    function Deinitialize: TNORIOResult; override;
    function Close: TNORIOResult; override;

    property Config: TSPI25NORConfig read FConfig;
    property IsOpen: boolean read FOpened;
    property IsInitialized: boolean read FInitialized;
    property FourByteModeActive: boolean read FFourByteModeActive;
    property HasLastJEDECID: boolean read FHasLastJEDECID;
    property LastJEDECID: TSPI25JEDECID read FLastJEDECID;
  end;

procedure InitSPI25NORConfig(out Config: TSPI25NORConfig);
procedure RequireSPI25Identity(var Config: TSPI25NORConfig;
  const Expected: TSPI25JEDECID; Passes: cardinal = 8);
function RequireSPI25MemoryIdentity(var Config: TSPI25NORConfig;
  const Identity: MEMORY_ID; Passes: cardinal;
  out ErrorText: string): boolean;
function RequireSPI25UniqueIdentity(var Config: TSPI25NORConfig;
  const ExpectedHex: string; Passes: cardinal;
  out ErrorText: string): boolean;
procedure DisableSPI25Identity(var Config: TSPI25NORConfig);
function ValidateSPI25NORConfig(const Config: TSPI25NORConfig;
  out ErrorText: string): boolean;
function SPI25JEDECIDHex(const ID: TSPI25JEDECID): string;

implementation

function AllJEDECBytes(const ID: TSPI25JEDECID; Value: byte): boolean;
begin
  Result := (ID[0] = Value) and (ID[1] = Value) and (ID[2] = Value);
end;

function SameJEDECID(const A, B: TSPI25JEDECID): boolean;
begin
  Result := (A[0] = B[0]) and (A[1] = B[1]) and (A[2] = B[2]);
end;

function AllUniqueIDBytes(const ID: TSPI25UniqueID; Value: byte): boolean;
var
  i: integer;
begin
  Result := True;
  for i := 0 to High(ID) do
    if ID[i] <> Value then Exit(False);
end;

function SameUniqueID(const A, B: TSPI25UniqueID): boolean;
var
  i: integer;
begin
  Result := True;
  for i := 0 to High(A) do
    if A[i] <> B[i] then Exit(False);
end;

function UniqueIDHex(const ID: TSPI25UniqueID): string;
var
  i: integer;
begin
  Result := '';
  for i := 0 to High(ID) do Result := Result + IntToHex(ID[i], 2);
end;

function HexNibble(Value: char; out Nibble: byte): boolean;
begin
  Result := True;
  case Value of
    '0'..'9': Nibble := Ord(Value) - Ord('0');
    'A'..'F': Nibble := Ord(Value) - Ord('A') + 10;
    'a'..'f': Nibble := Ord(Value) - Ord('a') + 10;
  else
    Nibble := 0;
    Result := False;
  end;
end;

function SPI25JEDECIDHex(const ID: TSPI25JEDECID): string;
begin
  Result := IntToHex(ID[0], 2) + IntToHex(ID[1], 2) +
            IntToHex(ID[2], 2);
end;

procedure InitSPI25NORConfig(out Config: TSPI25NORConfig);
begin
  FillChar(Config, SizeOf(Config), 0);
  Config.SPISpeed := 0;
  Config.SendAB := False;
  Config.AddressMode := sam3Byte;
  Config.ReadOpcode := $03;
  Config.ProgramOpcode := $02;
  Config.FastRead := False;
  Config.ReadTransport := srtSplitWriteRead;
  Config.FourByteStrategy := fbsNotApplicable;

  // Deliberately invalid until the caller chooses Require... or Disable....
  Config.IdentityMode := simUnspecified;
  Config.IdentityPasses := 0;
  Config.RequireUniqueID := False;
  FillChar(Config.ExpectedUniqueID, SizeOf(Config.ExpectedUniqueID), 0);
  Config.UniqueIDPasses := 0;

  Config.InitDelayMs := 50;
  Config.WakeDelayMs := 2;
end;

procedure RequireSPI25Identity(var Config: TSPI25NORConfig;
  const Expected: TSPI25JEDECID; Passes: cardinal);
begin
  Config.IdentityMode := simRequireExpected;
  Config.ExpectedJEDECID := Expected;
  Config.IdentityPasses := Passes;
end;

function RequireSPI25MemoryIdentity(var Config: TSPI25NORConfig;
  const Identity: MEMORY_ID; Passes: cardinal;
  out ErrorText: string): boolean;
var
  Expected: TSPI25JEDECID;
begin
  Result := False;
  ErrorText := '';
  if not Identity.Got9F then
  begin
    ErrorText := 'the preflight MEMORY_ID has no successful 9Fh response';
    Exit;
  end;

  Move(Identity.ID9FH[0], Expected[0], SizeOf(Expected));
  if AllJEDECBytes(Expected, $00) or AllJEDECBytes(Expected, $FF) then
  begin
    ErrorText := 'the preflight 9Fh response is not a usable JEDEC identity';
    Exit;
  end;

  RequireSPI25Identity(Config, Expected, Passes);
  Result := True;
end;

function RequireSPI25UniqueIdentity(var Config: TSPI25NORConfig;
  const ExpectedHex: string; Passes: cardinal;
  out ErrorText: string): boolean;
var
  i: integer;
  HiNibble, LoNibble: byte;
begin
  Result := False;
  ErrorText := '';
  Config.RequireUniqueID := False;
  FillChar(Config.ExpectedUniqueID, SizeOf(Config.ExpectedUniqueID), 0);
  Config.UniqueIDPasses := 0;

  if Length(ExpectedHex) <> SizeOf(Config.ExpectedUniqueID) * 2 then
  begin
    ErrorText := 'expected unique ID must contain exactly eight bytes of hex';
    Exit;
  end;
  for i := 0 to High(Config.ExpectedUniqueID) do
  begin
    if (not HexNibble(ExpectedHex[(i * 2) + 1], HiNibble)) or
       (not HexNibble(ExpectedHex[(i * 2) + 2], LoNibble)) then
    begin
      ErrorText := 'expected unique ID contains a non-hexadecimal character';
      FillChar(Config.ExpectedUniqueID, SizeOf(Config.ExpectedUniqueID), 0);
      Exit;
    end;
    Config.ExpectedUniqueID[i] := (HiNibble shl 4) or LoNibble;
  end;
  if AllUniqueIDBytes(Config.ExpectedUniqueID, $00) or
     AllUniqueIDBytes(Config.ExpectedUniqueID, $FF) then
  begin
    ErrorText := 'expected unique ID cannot be all 00h or all FFh';
    FillChar(Config.ExpectedUniqueID, SizeOf(Config.ExpectedUniqueID), 0);
    Exit;
  end;
  if Passes < 2 then
  begin
    ErrorText := 'unique-ID enforcement requires at least two passes';
    FillChar(Config.ExpectedUniqueID, SizeOf(Config.ExpectedUniqueID), 0);
    Exit;
  end;

  Config.RequireUniqueID := True;
  Config.UniqueIDPasses := Passes;
  Result := True;
end;

procedure DisableSPI25Identity(var Config: TSPI25NORConfig);
begin
  Config.IdentityMode := simExplicitlyDisabled;
  FillChar(Config.ExpectedJEDECID, SizeOf(Config.ExpectedJEDECID), 0);
  Config.IdentityPasses := 0;
  Config.RequireUniqueID := False;
  FillChar(Config.ExpectedUniqueID, SizeOf(Config.ExpectedUniqueID), 0);
  Config.UniqueIDPasses := 0;
end;

function ValidateSPI25NORConfig(const Config: TSPI25NORConfig;
  out ErrorText: string): boolean;
begin
  Result := False;
  ErrorText := '';

  if Config.SPISpeed < 0 then
  begin
    ErrorText := 'SPI speed selector must not be negative';
    Exit;
  end;

  case Config.AddressMode of
    sam3Byte:
      if Config.FourByteStrategy <> fbsNotApplicable then
      begin
        ErrorText :=
          '3-byte addressing cannot use a 4-byte session strategy';
        Exit;
      end;

    sam4Byte:
      begin
        case Config.FourByteStrategy of
          fbsNativeDedicatedOpcodes:
            begin
              // These are the ubiquitous stateful 3/4-byte opcodes.  Calling
              // them "native dedicated" would silently read/program the wrong
              // address on a chip that has not entered 4-byte mode.
              if Config.ReadOpcode in [$03, $0B] then
              begin
                ErrorText :=
                  'native 4-byte strategy requires a dedicated read opcode';
                Exit;
              end;
              if Config.ProgramOpcode = $02 then
              begin
                ErrorText :=
                  'native 4-byte strategy requires a dedicated program opcode';
                Exit;
              end;
            end;
          fbsEnterB7, fbsWriteEnableThenB7: ;
        else
          ErrorText :=
            '4-byte addressing requires an explicit native or B7 strategy';
          Exit;
        end;
      end;
  else
    ErrorText := 'SPI NOR address mode must be explicitly 3-byte or 4-byte';
    Exit;
  end;

  if Config.ReadOpcode = 0 then
  begin
    ErrorText := 'read opcode must be non-zero';
    Exit;
  end;
  // The dummy-byte decision must agree with the opcode: $0B/$0C clock one
  // dummy byte after the address, $03/$13 clock none.  A mismatch shifts
  // every read -- and therefore every verify -- by one byte.
  if (Config.ReadOpcode in [$0B, $0C]) and (not Config.FastRead) then
  begin
    ErrorText := 'fast-read opcode requires the fast-read dummy byte';
    Exit;
  end;
  if (Config.ReadOpcode in [$03, $13]) and Config.FastRead then
  begin
    ErrorText := 'a no-dummy read opcode cannot use fast-read framing';
    Exit;
  end;
  if Config.ProgramOpcode = 0 then
  begin
    ErrorText := 'page-program opcode must be non-zero';
    Exit;
  end;

  case Config.ReadTransport of
    srtSplitWriteRead, srtCombinedWriteRead: ;
  else
    ErrorText := 'unsupported SPI read transaction mode';
    Exit;
  end;

  case Config.IdentityMode of
    simRequireExpected:
      begin
        if Config.IdentityPasses < 2 then
        begin
          ErrorText := 'identity enforcement requires at least two passes';
          Exit;
        end;
        if AllJEDECBytes(Config.ExpectedJEDECID, $00) or
           AllJEDECBytes(Config.ExpectedJEDECID, $FF) then
        begin
          ErrorText := 'expected JEDEC identity cannot be all 00h or all FFh';
          Exit;
        end;
      end;

    simExplicitlyDisabled:
      begin
        if Config.IdentityPasses <> 0 then
        begin
          ErrorText :=
            'disabled identity enforcement must have zero identity passes';
          Exit;
        end;
        if not AllJEDECBytes(Config.ExpectedJEDECID, $00) then
        begin
          ErrorText :=
            'disabled identity enforcement must not retain an expected ID';
          Exit;
        end;
      end;

  else
    ErrorText :=
      'identity policy is unspecified; require an expected ID or explicitly disable it';
    Exit;
  end;

  if Config.RequireUniqueID then
  begin
    if Config.IdentityMode <> simRequireExpected then
    begin
      ErrorText := 'unique-ID enforcement also requires JEDEC identity enforcement';
      Exit;
    end;
    if Config.UniqueIDPasses < 2 then
    begin
      ErrorText := 'unique-ID enforcement requires at least two passes';
      Exit;
    end;
    if AllUniqueIDBytes(Config.ExpectedUniqueID, $00) or
       AllUniqueIDBytes(Config.ExpectedUniqueID, $FF) then
    begin
      ErrorText := 'expected unique ID cannot be all 00h or all FFh';
      Exit;
    end;
  end
  else
  begin
    if Config.UniqueIDPasses <> 0 then
    begin
      ErrorText := 'disabled unique-ID enforcement must have zero passes';
      Exit;
    end;
    if not AllUniqueIDBytes(Config.ExpectedUniqueID, $00) then
    begin
      ErrorText := 'disabled unique-ID enforcement must not retain an expected UID';
      Exit;
    end;
  end;

  Result := True;
end;

constructor TSPI25NORAdapter.Create(Hardware: TBaseHardware;
  const Config: TSPI25NORConfig);
var
  Err: string;
begin
  inherited Create;
  if Hardware = nil then
    raise EArgumentNilException.Create('SPI NOR hardware is nil');
  if not ValidateSPI25NORConfig(Config, Err) then
    raise EArgumentException.Create('invalid SPI NOR adapter config: ' + Err);

  FHardware := Hardware;
  FConfig := Config;
  FOpened := False;
  FBusActive := False;
  FInitialized := False;
  FIdentityGatePassed := False;
  FFourByteModeActive := False;
  FWriteEnableMayBeSet := False;
  FHasLastJEDECID := False;
  FillChar(FLastJEDECID, SizeOf(FLastJEDECID), 0);
end;

destructor TSPI25NORAdapter.Destroy;
begin
  // Last-resort leak prevention for callers outside TNORPlanExecutor.  Flags
  // are cleared before returning from every attempted lifecycle call, so no
  // action can be issued twice.
  if FBusActive then
    try
      StopBus;
    except
      // Destructors cannot return a typed cleanup result.
    end;

  if FOpened then
  begin
    FOpened := False;
    try
      FHardware.DevClose;
    except
      // Destructors cannot return a typed cleanup result.
    end;
  end;
  inherited Destroy;
end;

function TSPI25NORAdapter.HardwareErrorText: string;
begin
  Result := '';
  try
    Result := Trim(FHardware.GetLastError);
  except
    on E: Exception do
      Result := 'GetLastError raised ' + E.ClassName + ': ' + E.Message;
  end;
end;

function HasDisconnectedHint(const S: string): boolean;
var
  L: string;
begin
  L := LowerCase(S);
  Result := (Pos('disconnect', L) > 0) or
            (Pos('not connected', L) > 0) or
            (Pos('not open', L) > 0) or
            (Pos('no device', L) > 0) or
            (Pos('device not found', L) > 0) or
            (Pos('removed', L) > 0) or
            (Pos('closed', L) > 0);
end;

function TSPI25NORAdapter.TransferResult(const Context: string; Actual,
  Expected: integer): TNORIOResult;
var
  Detail, Msg: string;
  Kind: TNORIOError;
begin
  if Actual = Expected then Exit(NORIOSuccess(Expected));

  Detail := HardwareErrorText;
  Msg := Format('%s transferred %d of %d bytes',
                [Context, Actual, Expected]);
  if Detail <> '' then Msg := Msg + ': ' + Detail;

  if (Actual < 0) or HasDisconnectedHint(Detail) then
    Kind := nioDisconnected
  else
    Kind := nioTransport;
  Result := NORIOFailure(Kind, Msg);
end;

function TSPI25NORAdapter.ExceptionResult(const Context: string;
  E: Exception): TNORIOResult;
var
  Msg: string;
  Kind: TNORIOError;
begin
  Msg := Context + ' raised ' + E.ClassName + ': ' + E.Message;
  if HasDisconnectedHint(E.Message) then
    Kind := nioDisconnected
  else
    Kind := nioTransport;
  Result := NORIOFailure(Kind, Msg);
end;

function TSPI25NORAdapter.RequireInitialized(const Context: string;
  out R: TNORIOResult): boolean;
begin
  Result := False;
  if not FOpened then
  begin
    R := NORIOFailure(nioRejected, Context +
      ' requires an open programmer');
    Exit;
  end;
  if not FInitialized then
  begin
    R := NORIOFailure(nioRejected, Context +
      ' requires an initialized SPI session');
    Exit;
  end;
  Result := True;
end;

function TSPI25NORAdapter.RequireMutationReady(const Context: string;
  out R: TNORIOResult): boolean;
begin
  Result := RequireInitialized(Context, R);
  if not Result then Exit;
  if not FIdentityGatePassed then
  begin
    R := NORIOFailure(nioRejected, Context +
      ' is blocked because the identity gate did not pass');
    Exit(False);
  end;
end;

function TSPI25NORAdapter.WriteExact(CS: byte; const Data: TBytes;
  const Context: string): TNORIOResult;
var
  N: integer;
begin
  if Length(Data) = 0 then
    Exit(NORIOFailure(nioRejected, Context + ' has an empty write'));

  try
    N := FHardware.SPIWrite(CS, Length(Data), Data);
    Result := TransferResult(Context, N, Length(Data));
  except
    on E: Exception do Result := ExceptionResult(Context, E);
  end;
end;

function TSPI25NORAdapter.ReadExact(CS: byte; Len: cardinal;
  out Data: TBytes; const Context: string): TNORIOResult;
var
  N: integer;
begin
  Data := nil;
  if Len = 0 then
    Exit(NORIOFailure(nioRejected, Context + ' has an empty read'));
  if QWord(Len) > QWord(High(Integer)) then
    Exit(NORIOFailure(nioRejected, Context + ' is too large for this driver'));

  SetLength(Data, Len);
  FillByte(Data[0], Len, $FF);
  try
    N := FHardware.SPIRead(CS, Len, Data);
    Result := TransferResult(Context, N, Len);
  except
    on E: Exception do Result := ExceptionResult(Context, E);
  end;
  if not Result.Success then Data := nil;
end;

function TSPI25NORAdapter.ExchangeExact(const Header: TBytes; Len: cardinal;
  out Data: TBytes; const Context: string): TNORIOResult;
var
  N: integer;
begin
  Data := nil;
  if Length(Header) = 0 then
    Exit(NORIOFailure(nioRejected, Context + ' has an empty command header'));
  if (QWord(Len) > QWord(High(Integer))) or (Len = 0) then
    Exit(NORIOFailure(nioRejected, Context +
      ' does not fit the hardware driver'));

  if FConfig.ReadTransport = srtSplitWriteRead then
  begin
    Result := WriteExact(0, Header, Context + ' command');
    if not Result.Success then Exit;
    Exit(ReadExact(1, Len, Data, Context + ' reply'));
  end;

  SetLength(Data, Len);
  FillByte(Data[0], Len, $FF);
  try
    N := FHardware.SPIWriteRead(1, Length(Header), Header, Len, Data);
    Result := TransferResult(Context + ' combined reply', N, Len);
  except
    on E: Exception do Result := ExceptionResult(Context, E);
  end;
  if not Result.Success then Data := nil;
end;

function TSPI25NORAdapter.SendOneByte(Value: byte;
  const Context: string): TNORIOResult;
var
  Command: TBytes;
begin
  SetLength(Command, 1);
  Command[0] := Value;
  Result := WriteExact(1, Command, Context);
end;

function TSPI25NORAdapter.AddressLimit: QWord;
begin
  case FConfig.AddressMode of
    sam3Byte: Result := $FFFFFF;
    sam4Byte: Result := $FFFFFFFF;
  else
    Result := 0;
  end;
end;

function TSPI25NORAdapter.CheckRange(Address: QWord; Len: cardinal;
  const Context: string): TNORIOResult;
var
  Limit: QWord;
begin
  if Len = 0 then
    Exit(NORIOFailure(nioRejected, Context + ' length is zero'));

  Limit := AddressLimit;
  if (Address > Limit) or (QWord(Len - 1) > Limit - Address) then
    Exit(NORIOFailure(nioRejected, Context +
      ' does not fit the configured address width'));
  Result := NORIOSuccess;
end;

function TSPI25NORAdapter.BuildAddressHeader(Opcode: byte; Address: QWord;
  AddDummyByte: boolean; out Header: TBytes;
  const Context: string): TNORIOResult;
var
  AddressBytes, i, Extra: integer;
begin
  Header := nil;
  if Opcode = 0 then
    Exit(NORIOFailure(nioRejected, Context + ' opcode is zero'));
  if Address > AddressLimit then
    Exit(NORIOFailure(nioRejected, Context +
      ' address does not fit the configured address width'));

  if FConfig.AddressMode = sam3Byte then
    AddressBytes := 3
  else
    AddressBytes := 4;
  if AddDummyByte then Extra := 1 else Extra := 0;
  SetLength(Header, 1 + AddressBytes + Extra);
  Header[0] := Opcode;
  for i := 0 to AddressBytes - 1 do
    Header[1 + i] := byte(Address shr (8 * (AddressBytes - i - 1)));
  if AddDummyByte then Header[High(Header)] := $FF;
  Result := NORIOSuccess(Length(Header));
end;

function TSPI25NORAdapter.CheckIdentity: TNORIOResult;
var
  Header, Reply: TBytes;
  Reference, Current: TSPI25JEDECID;
  UIDReference, UIDCurrent: TSPI25UniqueID;
  Pass: cardinal;
begin
  FHasLastJEDECID := False;
  FIdentityGatePassed := False;
  FillChar(FLastJEDECID, SizeOf(FLastJEDECID), 0);

  if FConfig.IdentityMode = simExplicitlyDisabled then
  begin
    FIdentityGatePassed := True;
    Exit(NORIOSuccess);
  end;

  SetLength(Header, 1);
  Header[0] := $9F;
  FillChar(Reference, SizeOf(Reference), 0);

  for Pass := 1 to FConfig.IdentityPasses do
  begin
    Result := ExchangeExact(Header, SizeOf(Current), Reply,
      Format('JEDEC identity pass %d', [Pass]));
    if not Result.Success then Exit;
    Move(Reply[0], Current[0], SizeOf(Current));

    if AllJEDECBytes(Current, $00) or AllJEDECBytes(Current, $FF) then
      Exit(NORIOFailure(nioDisconnected,
        Format('JEDEC identity pass %d returned %s; no chip is responding',
               [Pass, SPI25JEDECIDHex(Current)])));

    if Pass = 1 then
      Reference := Current
    else if not SameJEDECID(Current, Reference) then
      Exit(NORIOFailure(nioRejected,
        Format('unstable JEDEC identity: pass 1 was %s, pass %d was %s',
          [SPI25JEDECIDHex(Reference), Pass,
           SPI25JEDECIDHex(Current)])));

    if not SameJEDECID(Current, FConfig.ExpectedJEDECID) then
      Exit(NORIOFailure(nioRejected,
        Format('JEDEC identity mismatch: expected %s, pass %d returned %s',
          [SPI25JEDECIDHex(FConfig.ExpectedJEDECID), Pass,
           SPI25JEDECIDHex(Current)])));
  end;

  FLastJEDECID := Reference;
  FHasLastJEDECID := True;

  if FConfig.RequireUniqueID then
  begin
    SetLength(Header, 5);
    Header[0] := $4B;
    Header[1] := 0;
    Header[2] := 0;
    Header[3] := 0;
    Header[4] := 0;
    FillChar(UIDReference, SizeOf(UIDReference), 0);
    for Pass := 1 to FConfig.UniqueIDPasses do
    begin
      Result := ExchangeExact(Header, SizeOf(UIDCurrent), Reply,
        Format('unique-ID identity pass %d', [Pass]));
      if not Result.Success then Exit;
      Move(Reply[0], UIDCurrent[0], SizeOf(UIDCurrent));

      if AllUniqueIDBytes(UIDCurrent, $00) or
         AllUniqueIDBytes(UIDCurrent, $FF) then
        Exit(NORIOFailure(nioRejected,
          Format('unique-ID pass %d returned an unusable all-00/all-FF value',
                 [Pass])));
      if Pass = 1 then
        UIDReference := UIDCurrent
      else if not SameUniqueID(UIDCurrent, UIDReference) then
        Exit(NORIOFailure(nioRejected,
          Format('unstable unique ID: pass 1 was %s, pass %d was %s',
            [UniqueIDHex(UIDReference), Pass, UniqueIDHex(UIDCurrent)])));
      if not SameUniqueID(UIDCurrent, FConfig.ExpectedUniqueID) then
        Exit(NORIOFailure(nioRejected,
          Format('unique-ID mismatch: expected %s, pass %d returned %s',
            [UniqueIDHex(FConfig.ExpectedUniqueID), Pass,
             UniqueIDHex(UIDCurrent)])));
    end;
  end;

  FIdentityGatePassed := True;
  Result := NORIOSuccess(SizeOf(Reference));
end;

function TSPI25NORAdapter.EnterConfiguredAddressMode: TNORIOResult;
begin
  if (FConfig.AddressMode <> sam4Byte) or
     (FConfig.FourByteStrategy = fbsNativeDedicatedOpcodes) then
    Exit(NORIOSuccess);

  if FConfig.FourByteStrategy = fbsWriteEnableThenB7 then
  begin
    // A short/exception return cannot prove that WREN stayed off the wire.
    // Keep the cleanup obligation until an exact WRDI succeeds.
    FWriteEnableMayBeSet := True;
    Result := SendOneByte($06, 'write enable before entering 4-byte mode');
    if not Result.Success then Exit;
  end;

  // Set the flag before crossing the transport boundary.  A short transfer or
  // exception does not prove that B7h stayed off the wire; cleanup must
  // conservatively attempt E9h before the bus is released.
  FFourByteModeActive := True;
  Result := SendOneByte($B7, 'enter 4-byte address mode');
end;

function TSPI25NORAdapter.StopBus: TNORIOResult;
var
  ExitModeResult, DisableResult, DeinitResult: TNORIOResult;
begin
  if not FBusActive then Exit(NORIOSuccess);

  // Clear state before calling an external adapter.  If it raises, cleanup is
  // still never issued twice and the result honestly reports an unknown bus.
  FInitialized := False;
  FIdentityGatePassed := False;
  ExitModeResult := NORIOSuccess;
  if FFourByteModeActive then
  begin
    // Clear ownership before the call: even an E9h exception/short transfer
    // must not lead to a duplicate command from Close or the destructor.
    FFourByteModeActive := False;
    if FConfig.FourByteStrategy = fbsWriteEnableThenB7 then
    begin
      // The chips that require WREN before B7h require it before E9h too
      // (N25Q256A class).  The executor's cleanup has already issued WRDI by
      // the time StopBus runs, so a bare E9h is accepted and silently ignored
      // and the chip stays in 4-byte mode for the next tool.  Re-arm WEL for
      // the exit and let the WRDI below clear it again.
      FWriteEnableMayBeSet := True;
      ExitModeResult := SendOneByte($06, 'write enable before exiting 4-byte mode');
      if ExitModeResult.Success then
        ExitModeResult := SendOneByte($E9, 'exit 4-byte address mode');
    end
    else
      ExitModeResult := SendOneByte($E9, 'exit 4-byte address mode');
  end;

  DisableResult := NORIOSuccess;
  if FWriteEnableMayBeSet then
  begin
    // Clear ownership before the call for the same exactly-once reason used by
    // E9 above.  A failed WRDI is reported, not silently retried later.
    FWriteEnableMayBeSet := False;
    DisableResult := SendOneByte($04, 'write disable during bus cleanup');
  end;

  FBusActive := False;
  try
    FHardware.SPIDeinit;
    DeinitResult := NORIOSuccess;
  except
    on E: Exception do
      DeinitResult := ExceptionResult('SPI deinitialization', E);
  end;

  if not ExitModeResult.Success then
  begin
    if not DisableResult.Success then
      ExitModeResult.ErrorText := ExitModeResult.ErrorText + '; ' +
                                  DisableResult.ErrorText;
    if not DeinitResult.Success then
      ExitModeResult.ErrorText := ExitModeResult.ErrorText + '; ' +
                                  DeinitResult.ErrorText;
    Result := ExitModeResult;
  end
  else if not DisableResult.Success then
  begin
    if not DeinitResult.Success then
      DisableResult.ErrorText := DisableResult.ErrorText + '; ' +
                                 DeinitResult.ErrorText;
    Result := DisableResult;
  end
  else
    Result := DeinitResult;
end;

function IsLegacyStatefulEraseOpcode(Opcode: byte): boolean;
begin
  Result := Opcode in [$20, $52, $D8];
end;

function NativeEraseOpcodeError(Opcode: byte): TNORIOResult;
begin
  Result := NORIOFailure(nioRejected,
    Format('erase opcode %s is a legacy stateful-address opcode; ' +
      'native 4-byte strategy requires its dedicated 4-byte counterpart',
      [IntToHex(Opcode, 2)]));
end;

procedure TSPI25NORAdapter.AppendRollbackError(var Primary: TNORIOResult;
  const Cleanup: TNORIOResult);
begin
  if Cleanup.Success then Exit;
  if Primary.ErrorText <> '' then
    Primary.ErrorText := Primary.ErrorText + '; ';
  Primary.ErrorText := Primary.ErrorText +
    'initialization rollback also failed: ' + Cleanup.ErrorText;
end;

function TSPI25NORAdapter.Open: TNORIOResult;
var
  OpenedOK: boolean;
  Detail: string;
begin
  if FOpened then
    Exit(NORIOFailure(nioRejected, 'programmer is already open'));

  try
    OpenedOK := FHardware.DevOpen;
  except
    on E: Exception do Exit(ExceptionResult('programmer open', E));
  end;

  if not OpenedOK then
  begin
    Detail := HardwareErrorText;
    if Detail <> '' then Detail := ': ' + Detail;
    Exit(NORIOFailure(nioDisconnected,
      'programmer could not be opened' + Detail));
  end;

  FOpened := True;
  FBusActive := False;
  FInitialized := False;
  FIdentityGatePassed := False;
  FHasLastJEDECID := False;
  FFourByteModeActive := False;
  FWriteEnableMayBeSet := False;
  Result := NORIOSuccess;
end;

function TSPI25NORAdapter.Initialize: TNORIOResult;
var
  InitOK: boolean;
  Cleanup: TNORIOResult;
  Detail: string;
begin
  if not FOpened then
    Exit(NORIOFailure(nioRejected,
      'SPI initialization requires an open programmer'));
  if FBusActive or FInitialized then
    Exit(NORIOFailure(nioRejected, 'SPI session is already initialized'));

  // SPIInit may partially configure hardware even when it returns False or
  // raises.  Mark it active before the call so every failure path attempts one
  // and only one SPIDeinit rollback.
  FBusActive := True;
  try
    InitOK := FHardware.SPIInit(FConfig.SPISpeed);
  except
    on E: Exception do
    begin
      Result := ExceptionResult('SPI initialization', E);
      Cleanup := StopBus;
      AppendRollbackError(Result, Cleanup);
      Exit;
    end;
  end;

  if not InitOK then
  begin
    Detail := HardwareErrorText;
    if Detail <> '' then Detail := ': ' + Detail;
    if HasDisconnectedHint(Detail) then
      Result := NORIOFailure(nioDisconnected,
        'SPI initialization lost the programmer' + Detail)
    else
      Result := NORIOFailure(nioTransport,
        'SPI initialization was rejected by the programmer' + Detail);
    Cleanup := StopBus;
    AppendRollbackError(Result, Cleanup);
    Exit;
  end;

  if FConfig.InitDelayMs > 0 then Sleep(FConfig.InitDelayMs);

  if FConfig.SendAB then
  begin
    Result := SendOneByte($AB, 'release from deep power-down');
    if not Result.Success then
    begin
      Cleanup := StopBus;
      AppendRollbackError(Result, Cleanup);
      Exit;
    end;
    if FConfig.WakeDelayMs > 0 then Sleep(FConfig.WakeDelayMs);
  end;

  Result := CheckIdentity;
  if not Result.Success then
  begin
    Cleanup := StopBus;
    AppendRollbackError(Result, Cleanup);
    Exit;
  end;

  Result := EnterConfiguredAddressMode;
  if not Result.Success then
  begin
    Cleanup := StopBus;
    AppendRollbackError(Result, Cleanup);
    Exit;
  end;

  FInitialized := True;
  Result := NORIOSuccess;
end;

function TSPI25NORAdapter.GetStatus(out Busy,
  WriteEnabled: boolean): TNORIOResult;
var
  Header, Reply: TBytes;
  Status: byte;
begin
  Busy := True;
  WriteEnabled := False;
  if not RequireInitialized('status read', Result) then Exit;

  SetLength(Header, 1);
  Header[0] := $05;
  Result := ExchangeExact(Header, 1, Reply, 'status read');
  if not Result.Success then Exit;

  Status := Reply[0];
  if Status = $FF then
    Exit(NORIOFailure(nioDisconnected,
      'status register returned FFh; the chip is not responding'));
  Busy := (Status and $01) <> 0;
  WriteEnabled := (Status and $02) <> 0;
  Result := NORIOSuccess(1);
end;

function TSPI25NORAdapter.WriteEnable: TNORIOResult;
begin
  if not RequireMutationReady('write enable', Result) then Exit;
  // Mark before transport: failure does not prove that opcode 06h was absent.
  FWriteEnableMayBeSet := True;
  Result := SendOneByte($06, 'write enable');
end;

function TSPI25NORAdapter.WriteDisable: TNORIOResult;
begin
  if not RequireInitialized('write disable', Result) then Exit;
  Result := SendOneByte($04, 'write disable');
  if Result.Success then FWriteEnableMayBeSet := False;
end;

function TSPI25NORAdapter.Erase(Address: QWord; Len: cardinal;
  Opcode: byte): TNORIOResult;
var
  Header: TBytes;
begin
  if not RequireMutationReady('erase', Result) then Exit;
  Result := CheckRange(Address, Len, 'erase range');
  if not Result.Success then Exit;
  if (FConfig.AddressMode = sam4Byte) and
     (FConfig.FourByteStrategy = fbsNativeDedicatedOpcodes) and
     IsLegacyStatefulEraseOpcode(Opcode) then
    Exit(NativeEraseOpcodeError(Opcode));
  Result := BuildAddressHeader(Opcode, Address, False, Header,
                               'erase command');
  if not Result.Success then Exit;
  Result := WriteExact(1, Header, 'erase command');
end;

function TSPI25NORAdapter.ProgramPage(Address: QWord;
  const Data: TBytes): TNORIOResult;
var
  Header: TBytes;
begin
  if not RequireMutationReady('page program', Result) then Exit;
  Result := CheckRange(Address, Length(Data), 'page-program range');
  if not Result.Success then Exit;
  Result := BuildAddressHeader(FConfig.ProgramOpcode, Address, False, Header,
                               'page-program command');
  if not Result.Success then Exit;

  Result := WriteExact(0, Header, 'page-program command');
  if not Result.Success then Exit;
  Result := WriteExact(1, Data, 'page-program payload');
  if Result.Success then Result.Transferred := Length(Data);
end;

function TSPI25NORAdapter.Read(Address: QWord; Len: cardinal;
  out Data: TBytes): TNORIOResult;
var
  Header, Part: TBytes;
  Limit, Done, N: cardinal;
  MaxTransfer: integer;
begin
  Data := nil;
  if not RequireInitialized('data read', Result) then Exit;
  Result := CheckRange(Address, Len, 'read range');
  if not Result.Success then Exit;

  //Vendor drivers have hard per-call ceilings (the CH341 DLL refuses SPI
  //data phases above ~3.9KB and reports it exactly like an unplugged
  //device), while verify steps are erase-block-sized.  Split a long read
  //into complete re-addressed commands, each within the driver's limit.
  try
    MaxTransfer := FHardware.SPIMaxTransfer;
  except
    on E: Exception do
      Exit(ExceptionResult('transfer-limit query', E));
  end;
  if MaxTransfer < 1 then
    Exit(NORIOFailure(nioRejected,
      'the hardware driver reports no usable transfer size'));
  Limit := cardinal(MaxTransfer);

  SetLength(Data, Len);
  Done := 0;
  while Done < Len do
  begin
    N := Len - Done;
    if N > Limit then N := Limit;
    Result := BuildAddressHeader(FConfig.ReadOpcode, Address + Done,
                                 FConfig.FastRead, Header,
                                 'read command');
    if not Result.Success then
    begin
      Data := nil;
      Exit;
    end;
    Result := ExchangeExact(Header, N, Part, 'data read');
    if not Result.Success then
    begin
      Data := nil;
      Exit;
    end;
    Move(Part[0], Data[Done], N);
    Inc(Done, N);
  end;
  Result := NORIOSuccess(Len);
end;

function TSPI25NORAdapter.Deinitialize: TNORIOResult;
begin
  if not FOpened then
    Exit(NORIOFailure(nioRejected,
      'SPI deinitialization requires an open programmer'));
  if not FBusActive then
    Exit(NORIOFailure(nioRejected, 'SPI session is not initialized'));
  Result := StopBus;
end;

function TSPI25NORAdapter.Close: TNORIOResult;
var
  Cleanup, CloseResult: TNORIOResult;
begin
  if not FOpened then
    Exit(NORIOFailure(nioRejected, 'programmer is not open'));

  Cleanup := NORIOSuccess;
  if FBusActive then Cleanup := StopBus;

  // As with StopBus, clear ownership before crossing the adapter boundary so
  // an exception never causes a second close attempt.
  FOpened := False;
  try
    FHardware.DevClose;
    CloseResult := NORIOSuccess;
  except
    on E: Exception do CloseResult := ExceptionResult('programmer close', E);
  end;

  if not Cleanup.Success then
  begin
    if not CloseResult.Success then
      Cleanup.ErrorText := Cleanup.ErrorText + '; ' + CloseResult.ErrorText;
    Result := Cleanup;
  end
  else
    Result := CloseResult;
end;

end.
