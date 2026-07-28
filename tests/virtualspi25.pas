unit virtualspi25;

// Stateful SPI25 model for whole-operation tests.
//
// This is deliberately stricter than a transcript mock.  It models memory,
// WEL/WIP, delayed erase/program completion, legal erase geometry and page
// boundaries.  It can fail any numbered device call, request cancellation from
// inside a chosen destructive command, ignore mutations like a protected chip,
// corrupt one read address, or stay busy forever.

{$mode objfpc}{$H+}

interface

uses
  SysUtils, operationmodel, norplanner, norengine;

type
  TVirtualCallKind = (
    vckOpen,
    vckInitialize,
    vckGetStatus,
    vckWriteEnable,
    vckWriteDisable,
    vckErase,
    vckProgram,
    vckRead,
    vckDeinitialize,
    vckClose
  );

  TVirtualCall = record
    Kind: TVirtualCallKind;
    Address: QWord;
    Length: cardinal;
    Mutating: boolean;
    CancellationRequestedAtStart: boolean;
    Succeeded: boolean;
  end;

  TVirtualCalls = array of TVirtualCall;

  TPendingKind = (
    pkNone,
    pkErase,
    pkProgram
  );

  TVirtualSPI25 = class(TNORDevice)
  private
    FGeometry: TNORGeometry;
    FMemory: TBytes;
    FOpened: boolean;
    FInitialized: boolean;
    FWriteEnabled: boolean;
    FPendingKind: TPendingKind;
    FPendingAddress: QWord;
    FPendingLength: cardinal;
    FPendingData: TBytes;
    FBusyCycles: cardinal;
    FEraseBusyPolls: cardinal;
    FProgramBusyPolls: cardinal;
    FCalls: TVirtualCalls;
    FCallCount: cardinal;
    FMutationCount: cardinal;
    FMutationsAfterCancellation: cardinal;
    FCloseCalls: cardinal;
    FDeinitializeCalls: cardinal;
    FStatusPolls: cardinal;
    FFailAtCall: cardinal;
    FCancelAtMutation: cardinal;
    FToken: TCancellationToken;
    FIgnoreMutations: boolean;
    FStuckBusy: boolean;
    FFlipReadAddress: Int64;
    function StartCall(Kind: TVirtualCallKind; Address: QWord;
      Len: cardinal; Mutating: boolean; out TraceIndex: SizeInt): boolean;
    procedure FinishCall(TraceIndex: SizeInt; Succeeded: boolean);
    function ReadyForIO(out R: TNORIOResult): boolean;
    function ExactEraseBlock(Address: QWord; Len: cardinal;
      Opcode: byte): boolean;
    function GetIsBusy: boolean;
    procedure FinishPending;
    procedure ClearPending;
  public
    constructor Create(const Geometry: TNORGeometry;
      const InitialData: array of byte);
    procedure Reset(const InitialData: array of byte);
    procedure PowerCycle;
    function Snapshot: TBytes;
    function MemoryEquals(const Expected: array of byte): boolean;
    function CallsAfterCancellationAreNonMutating: boolean;

    function Open: TNORIOResult; override;
    function Initialize: TNORIOResult; override;
    function GetStatus(out Busy, WriteEnabled: boolean): TNORIOResult; override;
    function WriteEnable: TNORIOResult; override;
    function WriteDisable: TNORIOResult; override;
    function Erase(Address: QWord; Len: cardinal; Opcode: byte): TNORIOResult;
      override;
    function ProgramPage(Address: QWord;
      const Data: TBytes): TNORIOResult; override;
    function Read(Address: QWord; Len: cardinal;
      out Data: TBytes): TNORIOResult; override;
    function Deinitialize: TNORIOResult; override;
    function Close: TNORIOResult; override;

    property Calls: TVirtualCalls read FCalls;
    property CallCount: cardinal read FCallCount;
    property MutationCount: cardinal read FMutationCount;
    property MutationsAfterCancellation: cardinal
      read FMutationsAfterCancellation;
    property CloseCalls: cardinal read FCloseCalls;
    property DeinitializeCalls: cardinal read FDeinitializeCalls;
    property StatusPolls: cardinal read FStatusPolls;
    property IsBusy: boolean read GetIsBusy;
    property WriteEnabled: boolean read FWriteEnabled;
    property FailAtCall: cardinal read FFailAtCall write FFailAtCall;
    property CancelAtMutation: cardinal
      read FCancelAtMutation write FCancelAtMutation;
    property CancellationToken: TCancellationToken read FToken write FToken;
    property IgnoreMutations: boolean
      read FIgnoreMutations write FIgnoreMutations;
    property StuckBusy: boolean read FStuckBusy write FStuckBusy;
    property FlipReadAddress: Int64
      read FFlipReadAddress write FFlipReadAddress;
    property EraseBusyPolls: cardinal
      read FEraseBusyPolls write FEraseBusyPolls;
    property ProgramBusyPolls: cardinal
      read FProgramBusyPolls write FProgramBusyPolls;
  end;

function VirtualCallKindName(Kind: TVirtualCallKind): string;

implementation

function VirtualCallKindName(Kind: TVirtualCallKind): string;
begin
  case Kind of
    vckOpen:         Result := 'open';
    vckInitialize:   Result := 'initialize';
    vckGetStatus:    Result := 'get_status';
    vckWriteEnable:  Result := 'write_enable';
    vckWriteDisable: Result := 'write_disable';
    vckErase:        Result := 'erase';
    vckProgram:      Result := 'program';
    vckRead:         Result := 'read';
    vckDeinitialize: Result := 'deinitialize';
    vckClose:        Result := 'close';
  else
    Result := 'unknown';
  end;
end;

constructor TVirtualSPI25.Create(const Geometry: TNORGeometry;
  const InitialData: array of byte);
var
  Err: string;
begin
  inherited Create;
  if not ValidateNORGeometry(Geometry, Err) then
    raise EArgumentException.Create('invalid virtual geometry: ' + Err);

  FGeometry := Geometry;
  FEraseBusyPolls := 3;
  FProgramBusyPolls := 2;
  FFlipReadAddress := -1;
  Reset(InitialData);
end;

procedure TVirtualSPI25.ClearPending;
begin
  FPendingKind := pkNone;
  FPendingAddress := 0;
  FPendingLength := 0;
  FPendingData := nil;
  FBusyCycles := 0;
end;

procedure TVirtualSPI25.Reset(const InitialData: array of byte);
begin
  if QWord(Length(InitialData)) <> FGeometry.ChipSize then
    raise EArgumentException.CreateFmt(
      'initial image has %d bytes, virtual chip needs %d',
      [Length(InitialData), FGeometry.ChipSize]);

  SetLength(FMemory, Length(InitialData));
  if Length(InitialData) > 0 then
    Move(InitialData[0], FMemory[0], Length(InitialData));

  FOpened := False;
  FInitialized := False;
  FWriteEnabled := False;
  ClearPending;
  FCalls := nil;
  FCallCount := 0;
  FMutationCount := 0;
  FMutationsAfterCancellation := 0;
  FCloseCalls := 0;
  FDeinitializeCalls := 0;
  FStatusPolls := 0;
  FFailAtCall := 0;
  FCancelAtMutation := 0;
  FToken := nil;
  FIgnoreMutations := False;
  FStuckBusy := False;
  FFlipReadAddress := -1;
end;

procedure TVirtualSPI25.PowerCycle;
begin
  // A power loss aborts an in-flight model command.  Tests must treat its
  // partially completed physical state as unknown and re-read before resuming.
  FOpened := False;
  FInitialized := False;
  FWriteEnabled := False;
  ClearPending;
end;

function TVirtualSPI25.StartCall(Kind: TVirtualCallKind; Address: QWord;
  Len: cardinal; Mutating: boolean; out TraceIndex: SizeInt): boolean;
var
  CancelBefore: boolean;
begin
  Inc(FCallCount);
  CancelBefore := (FToken <> nil) and FToken.IsCancellationRequested;

  if Mutating then
  begin
    Inc(FMutationCount);
    if CancelBefore then Inc(FMutationsAfterCancellation);

    // The selected command is allowed to be issued, but cancellation becomes
    // visible while it is in flight.  A correct executor drains it and starts
    // no later destructive command.
    if (FCancelAtMutation > 0) and
       (FMutationCount = FCancelAtMutation) and (FToken <> nil) then
      FToken.RequestCancellation;
  end;

  TraceIndex := Length(FCalls);
  SetLength(FCalls, TraceIndex + 1);
  FCalls[TraceIndex].Kind := Kind;
  FCalls[TraceIndex].Address := Address;
  FCalls[TraceIndex].Length := Len;
  FCalls[TraceIndex].Mutating := Mutating;
  FCalls[TraceIndex].CancellationRequestedAtStart := CancelBefore;
  FCalls[TraceIndex].Succeeded := False;

  Result := (FFailAtCall = 0) or (FCallCount <> FFailAtCall);
end;

procedure TVirtualSPI25.FinishCall(TraceIndex: SizeInt; Succeeded: boolean);
begin
  FCalls[TraceIndex].Succeeded := Succeeded;
end;

function TVirtualSPI25.ReadyForIO(out R: TNORIOResult): boolean;
begin
  Result := False;
  if not FOpened then
  begin
    R := NORIOFailure(nioDisconnected, 'virtual programmer is closed');
    Exit;
  end;
  if not FInitialized then
  begin
    R := NORIOFailure(nioRejected, 'virtual SPI bus is not initialized');
    Exit;
  end;
  Result := True;
end;

function TVirtualSPI25.ExactEraseBlock(Address: QWord; Len: cardinal;
  Opcode: byte): boolean;
var
  i: SizeInt;
begin
  Result := False;
  for i := 0 to High(FGeometry.Blocks) do
    if (FGeometry.Blocks[i].Address = Address) and
       (FGeometry.Blocks[i].Size = Len) and
       (FGeometry.Blocks[i].Opcode = Opcode) then
      Exit(True);
end;

function TVirtualSPI25.GetIsBusy: boolean;
begin
  Result := FPendingKind <> pkNone;
end;

procedure TVirtualSPI25.FinishPending;
var
  i: cardinal;
begin
  if FIgnoreMutations then
  begin
    ClearPending;
    Exit;
  end;

  case FPendingKind of
    pkErase:
      for i := 0 to FPendingLength - 1 do
        FMemory[SizeInt(FPendingAddress + i)] := FGeometry.ErasedValue;

    pkProgram:
      for i := 0 to FPendingLength - 1 do
        FMemory[SizeInt(FPendingAddress + i)] :=
          FMemory[SizeInt(FPendingAddress + i)] and FPendingData[i];
  end;

  ClearPending;
end;

function TVirtualSPI25.Snapshot: TBytes;
begin
  Result := nil;
  SetLength(Result, Length(FMemory));
  if Length(FMemory) > 0 then Move(FMemory[0], Result[0], Length(FMemory));
end;

function TVirtualSPI25.MemoryEquals(const Expected: array of byte): boolean;
var
  i: SizeInt;
begin
  Result := Length(Expected) = Length(FMemory);
  if not Result then Exit;
  for i := 0 to High(FMemory) do
    if FMemory[i] <> Expected[i] then Exit(False);
end;

function TVirtualSPI25.CallsAfterCancellationAreNonMutating: boolean;
var
  i: SizeInt;
begin
  Result := True;
  for i := 0 to High(FCalls) do
    if FCalls[i].Mutating and
       FCalls[i].CancellationRequestedAtStart then Exit(False);
end;

function TVirtualSPI25.Open: TNORIOResult;
var
  T: SizeInt;
begin
  if not StartCall(vckOpen, 0, 0, False, T) then
  begin
    Result := NORIOFailure(nioTransport, 'injected open failure');
    Exit;
  end;
  if FOpened then
    Result := NORIOFailure(nioRejected, 'virtual programmer is already open')
  else
  begin
    FOpened := True;
    Result := NORIOSuccess;
  end;
  FinishCall(T, Result.Success);
end;

function TVirtualSPI25.Initialize: TNORIOResult;
var
  T: SizeInt;
begin
  if not StartCall(vckInitialize, 0, 0, False, T) then
  begin
    Result := NORIOFailure(nioTransport, 'injected initialize failure');
    Exit;
  end;
  if not FOpened then
    Result := NORIOFailure(nioDisconnected, 'initialize while closed')
  else if FInitialized then
    Result := NORIOFailure(nioRejected, 'virtual SPI bus already initialized')
  else
  begin
    FInitialized := True;
    Result := NORIOSuccess;
  end;
  FinishCall(T, Result.Success);
end;

function TVirtualSPI25.GetStatus(out Busy,
  WriteEnabled: boolean): TNORIOResult;
var
  T: SizeInt;
begin
  Busy := True;
  WriteEnabled := False;
  Inc(FStatusPolls);

  if not StartCall(vckGetStatus, 0, 1, False, T) then
  begin
    Result := NORIOFailure(nioTransport, 'injected status failure');
    Exit;
  end;
  if not ReadyForIO(Result) then
  begin
    FinishCall(T, False);
    Exit;
  end;

  if (FPendingKind <> pkNone) and (not FStuckBusy) then
  begin
    if FBusyCycles > 0 then Dec(FBusyCycles);
    if FBusyCycles = 0 then FinishPending;
  end;

  Busy := FPendingKind <> pkNone;
  WriteEnabled := FWriteEnabled;
  Result := NORIOSuccess(1);
  FinishCall(T, True);
end;

function TVirtualSPI25.WriteEnable: TNORIOResult;
var
  T: SizeInt;
begin
  if not StartCall(vckWriteEnable, 0, 0, False, T) then
  begin
    Result := NORIOFailure(nioTransport, 'injected WREN failure');
    Exit;
  end;
  if not ReadyForIO(Result) then
  begin
    FinishCall(T, False);
    Exit;
  end;
  if FPendingKind <> pkNone then
    Result := NORIOFailure(nioBusy, 'WREN while chip is busy')
  else
  begin
    FWriteEnabled := True;
    Result := NORIOSuccess;
  end;
  FinishCall(T, Result.Success);
end;

function TVirtualSPI25.WriteDisable: TNORIOResult;
var
  T: SizeInt;
begin
  if not StartCall(vckWriteDisable, 0, 0, False, T) then
  begin
    Result := NORIOFailure(nioTransport, 'injected WRDI failure');
    Exit;
  end;
  if not ReadyForIO(Result) then
  begin
    FinishCall(T, False);
    Exit;
  end;
  if FPendingKind <> pkNone then
    Result := NORIOFailure(nioBusy, 'WRDI while chip is busy')
  else
  begin
    FWriteEnabled := False;
    Result := NORIOSuccess;
  end;
  FinishCall(T, Result.Success);
end;

function TVirtualSPI25.Erase(Address: QWord; Len: cardinal;
  Opcode: byte): TNORIOResult;
var
  T: SizeInt;
begin
  if not StartCall(vckErase, Address, Len, True, T) then
  begin
    Result := NORIOFailure(nioTransport, 'injected erase failure');
    Exit;
  end;
  if not ReadyForIO(Result) then
  begin
    FinishCall(T, False);
    Exit;
  end;
  if FPendingKind <> pkNone then
    Result := NORIOFailure(nioBusy, 'erase while chip is busy')
  else if not FWriteEnabled then
    Result := NORIOFailure(nioRejected, 'erase without WEL')
  else if not ExactEraseBlock(Address, Len, Opcode) then
    Result := NORIOFailure(nioRejected,
      'erase does not match declared geometry/opcode')
  else
  begin
    FPendingKind := pkErase;
    FPendingAddress := Address;
    FPendingLength := Len;
    FPendingData := nil;
    FBusyCycles := FEraseBusyPolls;
    if FBusyCycles = 0 then FBusyCycles := 1;
    FWriteEnabled := False;
    Result := NORIOSuccess;
  end;
  FinishCall(T, Result.Success);
end;

function TVirtualSPI25.ProgramPage(Address: QWord;
  const Data: TBytes): TNORIOResult;
var
  T: SizeInt;
  StepEnd, FirstPage, LastPage: QWord;
begin
  if not StartCall(vckProgram, Address, Length(Data), True, T) then
  begin
    Result := NORIOFailure(nioTransport, 'injected program failure');
    Exit;
  end;
  if not ReadyForIO(Result) then
  begin
    FinishCall(T, False);
    Exit;
  end;
  if FPendingKind <> pkNone then
    Result := NORIOFailure(nioBusy, 'program while chip is busy')
  else if not FWriteEnabled then
    Result := NORIOFailure(nioRejected, 'program without WEL')
  else if Length(Data) = 0 then
    Result := NORIOFailure(nioRejected, 'zero-length page program')
  else if (Address >= FGeometry.ChipSize) or
          (QWord(Length(Data)) > FGeometry.ChipSize - Address) then
    Result := NORIOFailure(nioRejected, 'program runs past chip')
  else
  begin
    StepEnd := Address + QWord(Length(Data));
    FirstPage := Address div FGeometry.PageSize;
    LastPage := (StepEnd - 1) div FGeometry.PageSize;
    if FirstPage <> LastPage then
      Result := NORIOFailure(nioRejected, 'program crosses a page boundary')
    else
    begin
      FPendingKind := pkProgram;
      FPendingAddress := Address;
      FPendingLength := Length(Data);
      SetLength(FPendingData, Length(Data));
      Move(Data[0], FPendingData[0], Length(Data));
      FBusyCycles := FProgramBusyPolls;
      if FBusyCycles = 0 then FBusyCycles := 1;
      FWriteEnabled := False;
      Result := NORIOSuccess(Length(Data));
    end;
  end;
  FinishCall(T, Result.Success);
end;

function TVirtualSPI25.Read(Address: QWord; Len: cardinal;
  out Data: TBytes): TNORIOResult;
var
  T: SizeInt;
  FlipOffset: QWord;
begin
  Data := nil;
  if not StartCall(vckRead, Address, Len, False, T) then
  begin
    Result := NORIOFailure(nioTransport, 'injected read failure');
    Exit;
  end;
  if not ReadyForIO(Result) then
  begin
    FinishCall(T, False);
    Exit;
  end;
  if FPendingKind <> pkNone then
    Result := NORIOFailure(nioBusy, 'read while chip is busy')
  else if (Address > FGeometry.ChipSize) or
          (QWord(Len) > FGeometry.ChipSize - Address) then
    Result := NORIOFailure(nioRejected, 'read runs past chip')
  else
  begin
    SetLength(Data, Len);
    if Len > 0 then Move(FMemory[SizeInt(Address)], Data[0], Len);

    if (FFlipReadAddress >= 0) and
       (QWord(FFlipReadAddress) >= Address) and
       (QWord(FFlipReadAddress) < Address + Len) then
    begin
      FlipOffset := QWord(FFlipReadAddress) - Address;
      Data[SizeInt(FlipOffset)] := Data[SizeInt(FlipOffset)] xor 1;
    end;

    Result := NORIOSuccess(Len);
  end;
  FinishCall(T, Result.Success);
end;

function TVirtualSPI25.Deinitialize: TNORIOResult;
var
  T: SizeInt;
begin
  Inc(FDeinitializeCalls);
  if not StartCall(vckDeinitialize, 0, 0, False, T) then
  begin
    Result := NORIOFailure(nioTransport, 'injected deinitialize failure');
    Exit;
  end;
  if not FOpened then
    Result := NORIOFailure(nioDisconnected, 'deinitialize while closed')
  else if not FInitialized then
    Result := NORIOFailure(nioRejected, 'SPI bus is not initialized')
  else if FPendingKind <> pkNone then
    Result := NORIOFailure(nioBusy, 'deinitialize while chip is busy')
  else
  begin
    FInitialized := False;
    Result := NORIOSuccess;
  end;
  FinishCall(T, Result.Success);
end;

function TVirtualSPI25.Close: TNORIOResult;
var
  T: SizeInt;
begin
  Inc(FCloseCalls);
  if not StartCall(vckClose, 0, 0, False, T) then
  begin
    Result := NORIOFailure(nioTransport, 'injected close failure');
    Exit;
  end;
  if not FOpened then
    Result := NORIOFailure(nioRejected, 'virtual programmer already closed')
  else
  begin
    FOpened := False;
    FInitialized := False;
    FWriteEnabled := False;
    Result := NORIOSuccess;
  end;
  FinishCall(T, Result.Success);
end;

end.
