unit eepromengine;

// Differential page-write planner and synchronous single-owner executor for
// byte-alterable EEPROMs (24Cxx I2C, 93xx MicroWire, 95xx SPI).
//
// EEPROMs have no erase step, so the transactional NOR machinery collapses
// to: compare a trusted snapshot against the desired image page by page,
// write only the pages that differ, then physically verify every page the
// requested range touches -- including unchanged ones, which is what catches
// a chip swapped between the snapshot and execution sessions.
//
// Hardware adapters implement TEEPROMDevice.  A page write is the critical
// section: the adapter owns the device's own write-cycle wait (I2C ack-poll,
// 93xx DO-poll, 95xx WIP-poll, all rejecting the FF dead-bus value) and only
// returns when the page is settled or has failed.  The executor serializes
// each run, defers cancellation across the critical section, and performs
// cleanup exactly once, mirroring norengine.

{$mode objfpc}{$H+}

interface

uses
  SysUtils, operationmodel;

type
  TEEPROMIOError = (
    eioNone,
    eioTransport,
    eioDisconnected,
    eioTimeout,
    eioRejected,
    eioBusy
  );

  TEEPROMIOResult = record
    Success: boolean;
    Error: TEEPROMIOError;
    ErrorText: string;
    Transferred: cardinal;
  end;

  TEEPROMDevice = class
  public
    function Open: TEEPROMIOResult; virtual; abstract;
    function Initialize: TEEPROMIOResult; virtual; abstract;
    // Writes one full page and waits out the device's write cycle before
    // returning.  Address is always page-aligned and Data always exactly one
    // page long; the adapter must reject anything else rather than clip.
    function WritePage(Address: QWord;
      const Data: TBytes): TEEPROMIOResult; virtual; abstract;
    function ReadPage(Address: QWord; Len: cardinal;
      out Data: TBytes): TEEPROMIOResult; virtual; abstract;
    function Deinitialize: TEEPROMIOResult; virtual; abstract;
    function Close: TEEPROMIOResult; virtual; abstract;
  end;

  TEEPROMPlanStepKind = (epsWrite, epsVerify);

  TEEPROMPlanStep = record
    Kind: TEEPROMPlanStepKind;
    Address: QWord;
    Length: cardinal;
    Data: TBytes; // desired page content, for writes and verify comparison
  end;

  TEEPROMPlanSteps = array of TEEPROMPlanStep;

  TEEPROMPlan = record
    RequestedAddress: QWord;
    RequestedLength: QWord;
    PageSize: cardinal;
    Steps: TEEPROMPlanSteps;
    ChangedBytes: QWord;
    WriteBytes: QWord;
    VerifyBytes: QWord;
  end;

procedure ClearEEPROMPlan(out Plan: TEEPROMPlan);

// Current is the trusted full-chip snapshot; its length is the chip size and
// must be an exact multiple of PageSize.  Patch is overlaid at PatchAddress.
function BuildEEPROMDifferentialPlan(const Current, Patch: array of byte;
  PatchAddress: QWord; PageSize: cardinal; out Plan: TEEPROMPlan;
  out ErrorText: string): boolean;

function ValidateEEPROMPlan(const Plan: TEEPROMPlan; ChipSize: QWord;
  out ErrorText: string): boolean;

function EEPROMPlanVerifyCoversRequestedRange(const Plan: TEEPROMPlan): boolean;
function EEPROMPlanWritesVerifiedAfterward(const Plan: TEEPROMPlan): boolean;
function EEPROMPlanCountKind(const Plan: TEEPROMPlan;
  Kind: TEEPROMPlanStepKind): integer;
function EEPROMPlanStepKindName(Kind: TEEPROMPlanStepKind): string;

type
  TEEPROMEvidenceProc = function(const Request: TOperationRequest;
    out ErrorText: string): boolean of object;

  TEEPROMPlanExecutor = class
  private
    FDevice: TEEPROMDevice;
    FOnEvent: TOperationEventProc;
    FClock: TOperationClockProc;
    FEvidenceCommit: TEEPROMEvidenceProc;
    FExecuting: LongInt;
  public
    constructor Create(Device: TEEPROMDevice;
      OnEvent: TOperationEventProc = nil; Clock: TOperationClockProc = nil;
      EvidenceCommit: TEEPROMEvidenceProc = nil);
    function Execute(const Request: TOperationRequest;
      const Plan: TEEPROMPlan; ChipSize: QWord;
      Token: TCancellationToken): TOperationOutcome;
  end;

function EEPROMIOSuccess(Transferred: cardinal = 0): TEEPROMIOResult;
function EEPROMIOFailure(Error: TEEPROMIOError;
  const ErrorText: string): TEEPROMIOResult;

implementation

function EEPROMIOSuccess(Transferred: cardinal): TEEPROMIOResult;
begin
  Result.Success := True;
  Result.Error := eioNone;
  Result.ErrorText := '';
  Result.Transferred := Transferred;
end;

function EEPROMIOFailure(Error: TEEPROMIOError;
  const ErrorText: string): TEEPROMIOResult;
begin
  Result.Success := False;
  Result.Error := Error;
  Result.ErrorText := ErrorText;
  Result.Transferred := 0;
end;

procedure ClearEEPROMPlan(out Plan: TEEPROMPlan);
begin
  Plan.RequestedAddress := 0;
  Plan.RequestedLength := 0;
  Plan.PageSize := 0;
  Plan.Steps := nil;
  Plan.ChangedBytes := 0;
  Plan.WriteBytes := 0;
  Plan.VerifyBytes := 0;
end;

function EEPROMPlanStepKindName(Kind: TEEPROMPlanStepKind): string;
begin
  case Kind of
    epsWrite:  Result := 'write';
    epsVerify: Result := 'verify';
  else
    Result := 'unknown';
  end;
end;

procedure AppendStep(var Plan: TEEPROMPlan; var StepCount: SizeInt;
  Kind: TEEPROMPlanStepKind; Address: QWord; Len: cardinal;
  const Desired: TBytes);
begin
  if StepCount = Length(Plan.Steps) then
  begin
    if Length(Plan.Steps) = 0 then
      SetLength(Plan.Steps, 16)
    else
      SetLength(Plan.Steps, Length(Plan.Steps) * 2);
  end;
  Plan.Steps[StepCount].Kind := Kind;
  Plan.Steps[StepCount].Address := Address;
  Plan.Steps[StepCount].Length := Len;
  Plan.Steps[StepCount].Data := nil;
  SetLength(Plan.Steps[StepCount].Data, Len);
  if Len > 0 then
    Move(Desired[SizeInt(Address)], Plan.Steps[StepCount].Data[0], Len);
  case Kind of
    epsWrite:  Inc(Plan.WriteBytes, Len);
    epsVerify: Inc(Plan.VerifyBytes, Len);
  end;
  Inc(StepCount);
end;

function BuildEEPROMDifferentialPlan(const Current, Patch: array of byte;
  PatchAddress: QWord; PageSize: cardinal; out Plan: TEEPROMPlan;
  out ErrorText: string): boolean;
var
  Desired: TBytes;
  ChipSize, PatchEnd, PageStart, PageEnd, At: QWord;
  StepCount: SizeInt;
  Different: boolean;
begin
  ClearEEPROMPlan(Plan);
  ErrorText := '';
  Result := False;

  ChipSize := Length(Current);
  if ChipSize = 0 then
  begin
    ErrorText := 'the snapshot is empty; there is no chip to plan against';
    Exit;
  end;
  if (PageSize = 0) or (PageSize > 65536) then
  begin
    ErrorText := 'the page size must be between 1 and 65536 bytes';
    Exit;
  end;
  if ChipSize mod PageSize <> 0 then
  begin
    ErrorText := Format('chip size %d is not a whole number of %d-byte pages',
                        [ChipSize, PageSize]);
    Exit;
  end;
  if PatchAddress > ChipSize then
  begin
    ErrorText := 'the patch starts past the end of the chip';
    Exit;
  end;
  if QWord(Length(Patch)) > ChipSize - PatchAddress then
  begin
    ErrorText := 'the patch runs past the end of the chip';
    Exit;
  end;

  Plan.RequestedAddress := PatchAddress;
  Plan.RequestedLength := Length(Patch);
  Plan.PageSize := PageSize;
  if Length(Patch) = 0 then Exit(True);
  PatchEnd := PatchAddress + QWord(Length(Patch));

  SetLength(Desired, ChipSize);
  Move(Current[0], Desired[0], ChipSize);
  Move(Patch[0], Desired[SizeInt(PatchAddress)], Length(Patch));

  StepCount := 0;

  // Pass 1: write every intersecting page that differs.  Whole pages, not
  // sub-runs: one page write costs one device write cycle regardless of how
  // many bytes it carries, and page-aligned full pages can never wrap inside
  // the device's page buffer.
  PageStart := (PatchAddress div PageSize) * PageSize;
  while PageStart < PatchEnd do
  begin
    PageEnd := PageStart + PageSize;
    Different := False;
    At := PageStart;
    while At < PageEnd do
    begin
      if Current[SizeInt(At)] <> Desired[SizeInt(At)] then
      begin
        Different := True;
        Inc(Plan.ChangedBytes);
      end;
      Inc(At);
    end;
    if Different then
      AppendStep(Plan, StepCount, epsWrite, PageStart, PageSize, Desired);
    Inc(PageStart, PageSize);
  end;

  // Pass 2: physically verify every intersecting page, changed or not.
  // Verifying the unchanged ones is deliberate: it is the only thing that
  // notices a same-model chip swapped in after the snapshot was taken.
  PageStart := (PatchAddress div PageSize) * PageSize;
  while PageStart < PatchEnd do
  begin
    AppendStep(Plan, StepCount, epsVerify, PageStart, PageSize, Desired);
    Inc(PageStart, PageSize);
  end;

  SetLength(Plan.Steps, StepCount);
  Result := ValidateEEPROMPlan(Plan, ChipSize, ErrorText);
end;

function ValidateEEPROMPlan(const Plan: TEEPROMPlan; ChipSize: QWord;
  out ErrorText: string): boolean;
var
  i: SizeInt;
begin
  Result := False;
  ErrorText := '';

  if Plan.RequestedLength = 0 then
  begin
    if Length(Plan.Steps) <> 0 then
    begin
      ErrorText := 'an empty request must produce an empty plan';
      Exit;
    end;
    Exit(True);
  end;
  if (Plan.PageSize = 0) or (ChipSize = 0) or
     (ChipSize mod Plan.PageSize <> 0) then
  begin
    ErrorText := 'the plan geometry is not usable';
    Exit;
  end;
  if (Plan.RequestedAddress > ChipSize) or
     (Plan.RequestedLength > ChipSize - Plan.RequestedAddress) then
  begin
    ErrorText := 'the requested range does not fit the chip';
    Exit;
  end;

  for i := 0 to High(Plan.Steps) do
  begin
    if Plan.Steps[i].Length <> Plan.PageSize then
    begin
      ErrorText := Format('step %d is not exactly one page long', [i]);
      Exit;
    end;
    if Plan.Steps[i].Address mod Plan.PageSize <> 0 then
    begin
      ErrorText := Format('step %d is not page aligned', [i]);
      Exit;
    end;
    if Plan.Steps[i].Address > ChipSize - Plan.PageSize then
    begin
      ErrorText := Format('step %d runs past the end of the chip', [i]);
      Exit;
    end;
    if cardinal(Length(Plan.Steps[i].Data)) <> Plan.Steps[i].Length then
    begin
      ErrorText := Format('step %d does not carry its page bytes', [i]);
      Exit;
    end;
  end;

  if not EEPROMPlanVerifyCoversRequestedRange(Plan) then
  begin
    ErrorText := 'the plan does not verify the complete requested range';
    Exit;
  end;
  if not EEPROMPlanWritesVerifiedAfterward(Plan) then
  begin
    ErrorText := 'a write step is not verified afterwards';
    Exit;
  end;

  Result := True;
end;

function EEPROMPlanVerifyCoversRequestedRange(const Plan: TEEPROMPlan): boolean;
var
  Cursor, RequestedEnd, StepEnd, Furthest: QWord;
  i: SizeInt;
begin
  if Plan.RequestedLength = 0 then Exit(True);
  if Plan.RequestedLength > High(QWord) - Plan.RequestedAddress then
    Exit(False);
  Cursor := Plan.RequestedAddress;
  RequestedEnd := Cursor + Plan.RequestedLength;

  // Verify steps are appended in ascending page order, so one sweep is
  // enough; do not assume it, prove it.
  Furthest := 0;
  for i := 0 to High(Plan.Steps) do
    if Plan.Steps[i].Kind = epsVerify then
    begin
      if Plan.Steps[i].Address > Cursor then Exit(False);
      StepEnd := Plan.Steps[i].Address + Plan.Steps[i].Length;
      if StepEnd > Furthest then Furthest := StepEnd;
      if Furthest > Cursor then Cursor := Furthest;
      if Cursor >= RequestedEnd then Exit(True);
    end;
  Result := Cursor >= RequestedEnd;
end;

function EEPROMPlanWritesVerifiedAfterward(const Plan: TEEPROMPlan): boolean;
var
  i, j: SizeInt;
  Found: boolean;
begin
  for i := 0 to High(Plan.Steps) do
    if Plan.Steps[i].Kind = epsWrite then
    begin
      Found := False;
      for j := i + 1 to High(Plan.Steps) do
        if (Plan.Steps[j].Kind = epsVerify) and
           (Plan.Steps[j].Address = Plan.Steps[i].Address) and
           (Plan.Steps[j].Length = Plan.Steps[i].Length) then
        begin
          Found := True;
          Break;
        end;
      if not Found then Exit(False);
    end;
  Result := True;
end;

function EEPROMPlanCountKind(const Plan: TEEPROMPlan;
  Kind: TEEPROMPlanStepKind): integer;
var
  i: SizeInt;
begin
  Result := 0;
  for i := 0 to High(Plan.Steps) do
    if Plan.Steps[i].Kind = Kind then Inc(Result);
end;

type
  TPendingFailure = record
    Code: TOperationErrorCode;
    Text: string;
    Address: QWord;
    HasAddress: boolean;
    Disposition: TDeviceDisposition;
  end;

function MapIOError(const R: TEEPROMIOResult;
  RejectedCode: TOperationErrorCode): TOperationErrorCode;
begin
  case R.Error of
    eioDisconnected: Result := oeDisconnected;
    eioTimeout:      Result := oeTimeout;
    eioRejected:     Result := RejectedCode;
    eioBusy:         Result := oeDeviceBusy;
  else
    Result := oeTransport;
  end;
end;

function IOFailureText(const Context: string;
  const R: TEEPROMIOResult): string;
begin
  Result := Context;
  if R.ErrorText <> '' then Result := Result + ': ' + R.ErrorText;
end;

procedure SetPending(var Pending: TPendingFailure;
  Code: TOperationErrorCode; const Msg: string;
  Disposition: TDeviceDisposition; Address: QWord = 0;
  HasAddress: boolean = False);
begin
  // Preserve the first causal failure; later failures may only worsen the
  // device disposition.
  if Pending.Code = oeNone then
  begin
    Pending.Code := Code;
    Pending.Text := Msg;
    Pending.Address := Address;
    Pending.HasAddress := HasAddress;
    Pending.Disposition := Disposition;
  end
  else if Ord(Disposition) > Ord(Pending.Disposition) then
    Pending.Disposition := Disposition;
end;

function DispositionForIO(const R: TEEPROMIOResult;
  CommandMayBeInFlight: boolean): TDeviceDisposition;
begin
  if R.Error = eioDisconnected then Exit(ddDisconnectedUnknown);
  if CommandMayBeInFlight then Exit(ddBusyUnknown);
  Result := ddKnownSafe;
end;

constructor TEEPROMPlanExecutor.Create(Device: TEEPROMDevice;
  OnEvent: TOperationEventProc; Clock: TOperationClockProc;
  EvidenceCommit: TEEPROMEvidenceProc);
begin
  inherited Create;
  FDevice := Device;
  FOnEvent := OnEvent;
  FClock := Clock;
  FEvidenceCommit := EvidenceCommit;
  FExecuting := 0;
end;

function TEEPROMPlanExecutor.Execute(const Request: TOperationRequest;
  const Plan: TEEPROMPlan; ChipSize: QWord;
  Token: TCancellationToken): TOperationOutcome;
var
  State: TOperationStateMachine;
  LocalToken: TCancellationToken;
  OwnToken: boolean;
  Pending: TPendingFailure;
  R: TEEPROMIOResult;
  Opened, Initialized, CancelAfterDrain: boolean;
  StepIndex, ByteIndex: SizeInt;
  DoneBytes, TotalBytes: QWord;
  ReadBack: TBytes;
  Err, EvidenceError: string;

  procedure FailFromIO(const Context: string; const IO: TEEPROMIOResult;
    RejectedCode: TOperationErrorCode; Address: QWord;
    HasAddress, MayBeInFlight: boolean);
  begin
    SetPending(Pending, MapIOError(IO, RejectedCode),
      IOFailureText(Context, IO), DispositionForIO(IO, MayBeInFlight),
      Address, HasAddress);
  end;

  procedure PerformCleanup;
  var
    CleanupResult: TEEPROMIOResult;
  begin
    if Initialized then
    begin
      Initialized := False;
      try
        CleanupResult := FDevice.Deinitialize;
        if not CleanupResult.Success then
          SetPending(Pending, oeCleanupFailed,
            IOFailureText('bus deinitialization', CleanupResult),
            ddModeUnknown);
      except
        on E: Exception do
          SetPending(Pending, oeCleanupFailed,
            'bus deinitialization raised ' + E.ClassName + ': ' + E.Message,
            ddModeUnknown);
      end;
    end;
    if Opened then
    begin
      Opened := False;
      try
        CleanupResult := FDevice.Close;
        if not CleanupResult.Success then
          SetPending(Pending, oeCleanupFailed,
            IOFailureText('device close', CleanupResult), ddModeUnknown);
      except
        on E: Exception do
          SetPending(Pending, oeCleanupFailed,
            'device close raised ' + E.ClassName + ': ' + E.Message,
            ddModeUnknown);
      end;
    end;
  end;

begin
  Pending.Code := oeNone;
  Pending.Text := '';
  Pending.Address := 0;
  Pending.HasAddress := False;
  Pending.Disposition := ddNotOpened;
  Opened := False;
  Initialized := False;
  CancelAfterDrain := False;
  ReadBack := nil;

  OwnToken := Token = nil;
  if OwnToken then
    LocalToken := TCancellationToken.Create
  else
    LocalToken := Token;

  State := TOperationStateMachine.Create(Request, LocalToken, FOnEvent,
                                         FClock);
  try
    State.Start;

    if InterlockedCompareExchange(FExecuting, 1, 0) <> 0 then
    begin
      State.Fail(oeInternalState,
        'another operation is already executing on this device',
        ddNotOpened);
      Result := State.Outcome;
      Exit;
    end;

    try
      try
        State.AdvanceTo(opValidating);
        if FDevice = nil then
          SetPending(Pending, oeInvalidRequest,
            'no EEPROM device adapter was supplied', ddNotOpened)
        else if not ValidateEEPROMPlan(Plan, ChipSize, Err) then
          SetPending(Pending, oeInvalidPlan, Err, ddNotOpened);

        if Pending.Code = oeNone then
        begin
          State.AdvanceTo(opReservingDevice);
          State.AdvanceTo(opOpening);
          R := FDevice.Open;
          if not R.Success then
            FailFromIO('device open', R, oeOpenFailed, 0, False, False)
          else
          begin
            Opened := True;
            Pending.Disposition := ddKnownSafe;
          end;
        end;

        if Pending.Code = oeNone then
        begin
          State.AdvanceTo(opInitializingBus);
          R := FDevice.Initialize;
          if not R.Success then
            FailFromIO('bus initialization', R, oeBusInitFailed, 0,
                       False, False)
          else
            Initialized := True;
        end;

        if Pending.Code = oeNone then
        begin
          State.AdvanceTo(opPlanning);
          State.AdvanceTo(opExecuting);
          DoneBytes := 0;
          TotalBytes := Plan.WriteBytes + Plan.VerifyBytes;
          State.ReportProgress(0, TotalBytes);

          for StepIndex := 0 to High(Plan.Steps) do
          begin
            if State.CancellationPending then
            begin
              CancelAfterDrain := True;
              Break;
            end;

            case Plan.Steps[StepIndex].Kind of
              epsWrite:
                begin
                  if not State.TryBeginCriticalCommand then
                  begin
                    CancelAfterDrain := State.CancellationPending;
                    Break;
                  end;
                  State.CommandStarted('write',
                    Plan.Steps[StepIndex].Address,
                    Plan.Steps[StepIndex].Length);
                  // The adapter owns the write-cycle wait, so when this call
                  // returns -- success or failure -- no command is left in
                  // flight unless the transport itself broke.
                  try
                    R := FDevice.WritePage(Plan.Steps[StepIndex].Address,
                                           Plan.Steps[StepIndex].Data);
                  except
                    on E: Exception do
                      R := EEPROMIOFailure(eioTransport,
                        'adapter raised ' + E.ClassName + ': ' + E.Message);
                  end;
                  State.EndCriticalCommand;
                  if not R.Success then
                  begin
                    FailFromIO('page write', R, oeProgramRejected,
                      Plan.Steps[StepIndex].Address, True, True);
                    Break;
                  end;
                  State.CommandFinished('write',
                    Plan.Steps[StepIndex].Address,
                    Plan.Steps[StepIndex].Length);
                  if State.CancellationPending then
                  begin
                    CancelAfterDrain := True;
                    // The page already settled; count it before stopping.
                    Inc(DoneBytes, Plan.Steps[StepIndex].Length);
                    State.ReportProgress(DoneBytes, TotalBytes);
                    Break;
                  end;
                end;

              epsVerify:
                begin
                  R := FDevice.ReadPage(Plan.Steps[StepIndex].Address,
                                        Plan.Steps[StepIndex].Length,
                                        ReadBack);
                  if not R.Success then
                  begin
                    FailFromIO('verify read', R, oeTransport,
                      Plan.Steps[StepIndex].Address, True, False);
                    Break;
                  end;
                  if (R.Transferred <> Plan.Steps[StepIndex].Length) or
                     (cardinal(Length(ReadBack)) <>
                      Plan.Steps[StepIndex].Length) then
                  begin
                    SetPending(Pending, oeShortTransfer,
                      Format('verify read returned %d of %d bytes',
                        [R.Transferred, Plan.Steps[StepIndex].Length]),
                      ddKnownSafe, Plan.Steps[StepIndex].Address, True);
                    Break;
                  end;
                  for ByteIndex := 0 to High(ReadBack) do
                    if ReadBack[ByteIndex] <>
                       Plan.Steps[StepIndex].Data[ByteIndex] then
                    begin
                      SetPending(Pending, oeVerifyMismatch,
                        'the chip does not match the differential plan',
                        ddKnownSafe,
                        Plan.Steps[StepIndex].Address + QWord(ByteIndex),
                        True);
                      Break;
                    end;
                  if Pending.Code <> oeNone then Break;
                end;
            end;

            Inc(DoneBytes, Plan.Steps[StepIndex].Length);
            State.ReportProgress(DoneBytes, TotalBytes);
          end;
        end;

        if (Pending.Code = oeNone) and (not CancelAfterDrain) then
        begin
          State.AdvanceTo(opVerifying);
          State.MarkPhysicalVerifyCompleted;
        end;

        if Ord(State.Outcome.Phase) < Ord(opQuiescing) then
          State.AdvanceTo(opQuiescing);
        PerformCleanup;

        if (Pending.Code = oeNone) and CancelAfterDrain then
          State.Cancel(ddKnownSafe)
        else if Pending.Code <> oeNone then
          State.Fail(Pending.Code, Pending.Text, Pending.Disposition,
                     Pending.Address, Pending.HasAddress)
        else
        begin
          if Request.Policy.RequireEvidenceCommit then
          begin
            State.AdvanceTo(opCommittingEvidence);
            if not Assigned(FEvidenceCommit) then
              SetPending(Pending, oeEvidenceCommitFailed,
                'evidence commit is required but no commit handler was supplied',
                ddKnownSafe)
            else
            begin
              EvidenceError := '';
              if not FEvidenceCommit(Request, EvidenceError) then
                SetPending(Pending, oeEvidenceCommitFailed,
                  'evidence commit failed: ' + EvidenceError, ddKnownSafe);
            end;
          end;

          if Pending.Code <> oeNone then
            State.Fail(Pending.Code, Pending.Text, Pending.Disposition,
                       Pending.Address, Pending.HasAddress)
          else
            State.Complete;
        end;

        Result := State.Outcome;
      finally
        if State.InCriticalCommand then
        begin
          State.EndCriticalCommand;
          if Pending.Code = oeNone then
            SetPending(Pending, oeTransport,
              'executor unwound while a page write was in flight',
              ddBusyUnknown);
        end;
        if Opened or Initialized then PerformCleanup;
        InterlockedExchange(FExecuting, 0);
      end;
    except
      on E: Exception do
      begin
        if Pending.Code = oeNone then
          SetPending(Pending, oeTransport,
            'device adapter raised ' + E.ClassName + ': ' + E.Message,
            ddModeUnknown);
        if not State.IsTerminal then
          State.Fail(Pending.Code, Pending.Text, Pending.Disposition,
                     Pending.Address, Pending.HasAddress);
        Result := State.Outcome;
      end;
    end;
  finally
    State.Free;
    if OwnToken then LocalToken.Free;
  end;
end;

end.
