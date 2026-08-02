unit norengine;

// Synchronous, single-owner executor for TNORPlan.
//
// Hardware adapters implement TNORDevice.  The executor serializes each run,
// verifies WEL before every destructive command, treats erase/program as a
// non-cancellable critical section, drains BUSY before honouring cancellation,
// verifies the bytes declared by the plan, and performs cleanup exactly once.
//
// It does not create a thread.  A GUI may host one executor on a dedicated
// device thread; a CLI or test can call it directly.  All calls belonging to a
// run occur on that one caller thread, avoiding open/I/O/close thread changes.

{$mode objfpc}{$H+}

interface

uses
  SysUtils, operationmodel, norplanner;

type
  TNORIOError = (
    nioNone,
    nioTransport,
    nioDisconnected,
    nioTimeout,
    nioRejected,
    nioBusy
  );

  TNORIOResult = record
    Success: boolean;
    Error: TNORIOError;
    ErrorText: string;
    Transferred: cardinal;
  end;

  TNORDevice = class
  public
    function Open: TNORIOResult; virtual; abstract;
    function Initialize: TNORIOResult; virtual; abstract;
    function GetStatus(out Busy, WriteEnabled: boolean): TNORIOResult;
      virtual; abstract;
    function WriteEnable: TNORIOResult; virtual; abstract;
    function WriteDisable: TNORIOResult; virtual; abstract;
    function Erase(Address: QWord; Len: cardinal; Opcode: byte): TNORIOResult;
      virtual; abstract;
    function ProgramPage(Address: QWord; const Data: TBytes): TNORIOResult;
      virtual; abstract;
    function Read(Address: QWord; Len: cardinal; out Data: TBytes): TNORIOResult;
      virtual; abstract;
    function Deinitialize: TNORIOResult; virtual; abstract;
    function Close: TNORIOResult; virtual; abstract;
  end;

  TOperationEvidenceProc = function(const Request: TOperationRequest;
    out ErrorText: string): boolean of object;

  TNORExecutorOptions = record
    MaxStatusPolls: cardinal;
    ProgramTimeoutMs: cardinal;
    EraseTimeoutMs: cardinal;
    StatusPollDelayMs: cardinal;
  end;

  TNORPlanExecutor = class
  private
    FDevice: TNORDevice;
    FOnEvent: TOperationEventProc;
    FClock: TOperationClockProc;
    FEvidenceCommit: TOperationEvidenceProc;
    FExecuting: LongInt;
    FOptions: TNORExecutorOptions;
    function ExecuteInternal(const Request: TOperationRequest;
      const Plan: TNORPlan; const Geometry: TNORGeometry;
      const ExpectedPreimage: TBytes; BindPreimage: boolean;
      Token: TCancellationToken): TOperationOutcome;
  public
    constructor Create(Device: TNORDevice;
      OnEvent: TOperationEventProc = nil; Clock: TOperationClockProc = nil;
      EvidenceCommit: TOperationEvidenceProc = nil);
    function Execute(const Request: TOperationRequest; const Plan: TNORPlan;
      const Geometry: TNORGeometry; Token: TCancellationToken): TOperationOutcome;
    // Re-open, initialize, and prove that the complete chip still equals the
    // trusted planning snapshot in the same uninterrupted session as any
    // mutation.  No WREN is issued when this admission check fails.
    function ExecuteBound(const Request: TOperationRequest; const Plan: TNORPlan;
      const Geometry: TNORGeometry; const ExpectedPreimage: TBytes;
      Token: TCancellationToken): TOperationOutcome;
    property Options: TNORExecutorOptions read FOptions write FOptions;
  end;

function NORIOSuccess(Transferred: cardinal = 0): TNORIOResult;
function NORIOFailure(Error: TNORIOError; const ErrorText: string): TNORIOResult;

implementation

type
  TPendingFailure = record
    Code: TOperationErrorCode;
    Text: string;
    Address: QWord;
    HasAddress: boolean;
    Disposition: TDeviceDisposition;
  end;

function NORIOSuccess(Transferred: cardinal): TNORIOResult;
begin
  Result.Success := True;
  Result.Error := nioNone;
  Result.ErrorText := '';
  Result.Transferred := Transferred;
end;

function NORIOFailure(Error: TNORIOError;
  const ErrorText: string): TNORIOResult;
begin
  Result.Success := False;
  Result.Error := Error;
  Result.ErrorText := ErrorText;
  Result.Transferred := 0;
end;

function MapIOError(const R: TNORIOResult;
  RejectedCode: TOperationErrorCode): TOperationErrorCode;
begin
  case R.Error of
    nioDisconnected: Result := oeDisconnected;
    nioTimeout:      Result := oeTimeout;
    nioRejected:     Result := RejectedCode;
    nioBusy:         Result := oeDeviceBusy;
  else
    Result := oeTransport;
  end;
end;

function IOFailureText(const Context: string; const R: TNORIOResult): string;
begin
  Result := Context;
  if R.ErrorText <> '' then Result := Result + ': ' + R.ErrorText;
end;

procedure SetPending(var Pending: TPendingFailure;
  Code: TOperationErrorCode; const Msg: string;
  Disposition: TDeviceDisposition; Address: QWord = 0;
  HasAddress: boolean = False);
begin
  // Preserve the first causal failure.  Cleanup failures may still worsen the
  // device disposition, but must not hide why the operation originally failed.
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

function DispositionForIO(const R: TNORIOResult;
  CommandMayBeInFlight: boolean): TDeviceDisposition;
begin
  if R.Error = nioDisconnected then Exit(ddDisconnectedUnknown);
  if CommandMayBeInFlight then Exit(ddBusyUnknown);
  Result := ddKnownSafe;
end;

constructor TNORPlanExecutor.Create(Device: TNORDevice;
  OnEvent: TOperationEventProc; Clock: TOperationClockProc;
  EvidenceCommit: TOperationEvidenceProc);
begin
  inherited Create;
  FDevice := Device;
  FOnEvent := OnEvent;
  FClock := Clock;
  FEvidenceCommit := EvidenceCommit;
  FExecuting := 0;
  FOptions.MaxStatusPolls := 100000;
  FOptions.ProgramTimeoutMs := 30000;
  FOptions.EraseTimeoutMs := 3600000;
  FOptions.StatusPollDelayMs := 0;
end;

function TNORPlanExecutor.Execute(const Request: TOperationRequest;
  const Plan: TNORPlan; const Geometry: TNORGeometry;
  Token: TCancellationToken): TOperationOutcome;
begin
  Result := ExecuteInternal(Request, Plan, Geometry, nil, False, Token);
end;

function TNORPlanExecutor.ExecuteBound(const Request: TOperationRequest;
  const Plan: TNORPlan; const Geometry: TNORGeometry;
  const ExpectedPreimage: TBytes;
  Token: TCancellationToken): TOperationOutcome;
begin
  Result := ExecuteInternal(Request, Plan, Geometry, ExpectedPreimage, True,
    Token);
end;

function TNORPlanExecutor.ExecuteInternal(const Request: TOperationRequest;
  const Plan: TNORPlan; const Geometry: TNORGeometry;
  const ExpectedPreimage: TBytes; BindPreimage: boolean;
  Token: TCancellationToken): TOperationOutcome;
var
  State: TOperationStateMachine;
  LocalToken: TCancellationToken;
  OwnToken: boolean;
  Pending: TPendingFailure;
  R, CleanupResult: TNORIOResult;
  Busy, WEL: boolean;
  Opened, Initialized, CancelAfterDrain: boolean;
  StepIndex, ByteIndex: SizeInt;
  Polls, CommandTimeoutMs: cardinal;
  DoneBytes, TotalBytes: QWord;
  ReadBack, SessionPreimage: TBytes;
  Err, EvidenceError: string;

  procedure FailFromIO(const Context: string; const IO: TNORIOResult;
    RejectedCode: TOperationErrorCode; Address: QWord;
    HasAddress, MayBeInFlight: boolean);
  begin
    SetPending(Pending, MapIOError(IO, RejectedCode),
      IOFailureText(Context, IO), DispositionForIO(IO, MayBeInFlight),
      Address, HasAddress);
  end;

  function NowMs: QWord;
  begin
    if Assigned(FClock) then Result := FClock()
    else Result := GetTickCount64;
  end;

  function DrainCriticalCommand(Address: QWord;
    TimeoutMs: cardinal): boolean;
  var
    StartedAt, CurrentAt: QWord;
  begin
    Result := False;
    Polls := 0;
    StartedAt := NowMs;
    repeat
      R := FDevice.GetStatus(Busy, WEL);
      if not R.Success then
      begin
        FailFromIO('status poll after destructive command', R, oeTransport,
                   Address, True, True);
        Exit;
      end;

      if not Busy then
      begin
        // The transport may have failed while returning the command result,
        // but a successful status read proving WIP=0 restores certainty about
        // the physical device state.
        if Pending.Disposition = ddBusyUnknown then
          Pending.Disposition := ddKnownSafe;
        Exit(True);
      end;
      Inc(Polls);
      if Polls >= FOptions.MaxStatusPolls then
      begin
        SetPending(Pending, oeTimeout,
          Format('chip remained busy for %d status polls', [Polls]),
          ddBusyUnknown, Address, True);
        Exit;
      end;
      CurrentAt := NowMs;
      if (CurrentAt >= StartedAt) and
         (CurrentAt - StartedAt >= TimeoutMs) then
      begin
        SetPending(Pending, oeTimeout,
          Format('chip remained busy for %d ms', [TimeoutMs]),
          ddBusyUnknown, Address, True);
        Exit;
      end;
      if FOptions.StatusPollDelayMs > 0 then
        Sleep(FOptions.StatusPollDelayMs);

      // Deliberately do not return on cancellation here.  The current physical
      // command must reach idle before cancellation can become terminal.
    until False;
  end;

  procedure PerformCleanup;
  begin
    if State.InCriticalCommand then State.EndCriticalCommand;

    if Initialized then
    begin
      try
        CleanupResult := FDevice.WriteDisable;
        if not CleanupResult.Success then
          SetPending(Pending, oeCleanupFailed,
            IOFailureText('write disable cleanup', CleanupResult),
            DispositionForIO(CleanupResult,
              Pending.Disposition = ddBusyUnknown));
      except
        on E: Exception do
          SetPending(Pending, oeCleanupFailed,
            'write disable cleanup raised ' + E.ClassName + ': ' + E.Message,
            ddModeUnknown);
      end;

      try
        CleanupResult := FDevice.Deinitialize;
        if not CleanupResult.Success then
          SetPending(Pending, oeCleanupFailed,
            IOFailureText('bus deinitialize cleanup', CleanupResult),
            ddModeUnknown);
      except
        on E: Exception do
          SetPending(Pending, oeCleanupFailed,
            'bus deinitialize cleanup raised ' + E.ClassName + ': ' +
            E.Message, ddModeUnknown);
      end;
      Initialized := False;
    end;

    if Opened then
    begin
      try
        CleanupResult := FDevice.Close;
        if not CleanupResult.Success then
          SetPending(Pending, oeCleanupFailed,
            IOFailureText('device close cleanup', CleanupResult),
            ddModeUnknown);
      except
        on E: Exception do
          SetPending(Pending, oeCleanupFailed,
            'device close cleanup raised ' + E.ClassName + ': ' + E.Message,
            ddModeUnknown);
      end;
      Opened := False;
    end;
  end;

begin
  FillChar(Pending, SizeOf(Pending), 0);
  Pending.Code := oeNone;
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

  State := TOperationStateMachine.Create(Request, LocalToken, FOnEvent, FClock);
  try
    State.Start;

    // One executor instance represents one physical programmer session and may
    // not be entered concurrently or recursively.
    if InterlockedCompareExchange(FExecuting, 1, 0) <> 0 then
    begin
      State.Fail(oeDeviceBusy, 'this device executor is already running',
                 ddNotOpened);
      Exit(State.Outcome);
    end;

    try
      try
        State.AdvanceTo(opValidating);
      if FDevice = nil then
        SetPending(Pending, oeInvalidRequest, 'NOR device is nil', ddNotOpened)
      else if not ValidateNORPlan(Plan, Geometry, Err) then
        SetPending(Pending, oeInvalidPlan, Err, ddNotOpened)
      else if (Request.Target.Address <> Plan.RequestedAddress) or
              (Request.Target.Length <> Plan.RequestedLength) then
        SetPending(Pending, oeInvalidRequest,
          'request range does not match the immutable plan', ddNotOpened)
      else if (Request.Chip.Capacity <> 0) and
              (Request.Chip.Capacity <> Geometry.ChipSize) then
        SetPending(Pending, oeInvalidRequest,
          'request chip capacity does not match plan geometry', ddNotOpened)
      else if BindPreimage and
              (QWord(Length(ExpectedPreimage)) <> Geometry.ChipSize) then
        SetPending(Pending, oeInvalidRequest,
          'bound preimage length does not match plan geometry', ddNotOpened)
      else if BindPreimage and (Geometry.ChipSize > High(cardinal)) then
        SetPending(Pending, oeInvalidRequest,
          'bound preimage is too large for one exact device read', ddNotOpened)
      else if Request.Policy.RequireFullVerify and
              (not NORPlanVerifyCoversRequestedRange(Plan)) then
        SetPending(Pending, oeInvalidPlan,
          'plan does not physically verify the complete requested range',
          ddNotOpened)
      else if not NORPlanDestructiveStepsVerifiedAfterward(Plan) then
        SetPending(Pending, oeInvalidPlan,
          'a destructive step has no later covering verification',
          ddNotOpened)
      else if (FOptions.MaxStatusPolls = 0) or
              (FOptions.ProgramTimeoutMs = 0) or
              (FOptions.EraseTimeoutMs = 0) then
        SetPending(Pending, oeInvalidRequest,
          'executor poll and elapsed-time limits must be non-zero',
          ddNotOpened);

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
          FailFromIO('bus initialization', R, oeBusInitFailed, 0, False, False)
        else
          Initialized := True;
      end;

      if Pending.Code = oeNone then
      begin
        if BindPreimage then
        begin
          State.AdvanceTo(opCheckingContact);
          SessionPreimage := nil;
          R := FDevice.Read(0, cardinal(Geometry.ChipSize), SessionPreimage);
          if not R.Success then
            FailFromIO('bound preimage read', R, oeTransport, 0, True, False)
          else if (R.Transferred <> Geometry.ChipSize) or
                  (QWord(Length(SessionPreimage)) <> Geometry.ChipSize) then
            SetPending(Pending, oeShortTransfer,
              Format('bound preimage read returned %d of %d bytes',
                [R.Transferred, Geometry.ChipSize]), ddKnownSafe, 0, True)
          else
            for ByteIndex := 0 to High(SessionPreimage) do
              if SessionPreimage[ByteIndex] <> ExpectedPreimage[ByteIndex] then
              begin
                SetPending(Pending, oeContactUnstable,
                  'chip content changed since the trusted planning snapshot',
                  ddKnownSafe, QWord(ByteIndex), True);
                Break;
              end;
          SessionPreimage := nil;
        end;
      end;

      if Pending.Code = oeNone then
      begin
        // Identity, backup, and protection are separate admission adapters.
        // Bound callers additionally prove the trusted snapshot above without
        // releasing this physical session before mutation.
        State.AdvanceTo(opPlanning);
        State.AdvanceTo(opExecuting);
        // Progress is byte-denominated: consumers publish these values as
        // "bytes" in summaries and CLI JSON, so step indices would lie.
        DoneBytes := 0;
        TotalBytes := Plan.EraseBytes + Plan.ProgramBytes + Plan.VerifyBytes;
        State.ReportProgress(0, TotalBytes);

        for StepIndex := 0 to High(Plan.Steps) do
        begin
          if State.CancellationPending then
          begin
            CancelAfterDrain := True;
            Break;
          end;

          case Plan.Steps[StepIndex].Kind of
            npsErase, npsProgram:
              begin
                R := FDevice.WriteEnable;
                if not R.Success then
                begin
                  FailFromIO('write enable', R, oeWriteEnableRejected,
                    Plan.Steps[StepIndex].Address, True, False);
                  Break;
                end;

                R := FDevice.GetStatus(Busy, WEL);
                if not R.Success then
                begin
                  FailFromIO('write-enable status check', R,
                    oeWriteEnableRejected, Plan.Steps[StepIndex].Address,
                    True, False);
                  Break;
                end;
                if Busy then
                begin
                  SetPending(Pending, oeDeviceBusy,
                    'chip was already busy before a destructive command',
                    ddBusyUnknown, Plan.Steps[StepIndex].Address, True);
                  Break;
                end;
                if not WEL then
                begin
                  SetPending(Pending, oeWriteEnableRejected,
                    'WEL stayed clear after write enable', ddKnownSafe,
                    Plan.Steps[StepIndex].Address, True);
                  Break;
                end;

                // Recheck cancellation after WREN but before issuing the
                // destructive opcode.
                if not State.TryBeginCriticalCommand then
                begin
                  CancelAfterDrain := State.CancellationPending;
                  Break;
                end;

                State.CommandStarted(
                  NORPlanStepKindName(Plan.Steps[StepIndex].Kind),
                  Plan.Steps[StepIndex].Address,
                  Plan.Steps[StepIndex].Length);

                // An adapter exception is just as ambiguous as a transport
                // error return: the opcode may already be on the wire.  Turn
                // it into a typed result here so the common path still polls
                // WIP to idle before any cleanup or cancellation is honoured.
                try
                  if Plan.Steps[StepIndex].Kind = npsErase then
                    R := FDevice.Erase(Plan.Steps[StepIndex].Address,
                      Plan.Steps[StepIndex].Length,
                      Plan.Steps[StepIndex].Opcode)
                  else
                    R := FDevice.ProgramPage(Plan.Steps[StepIndex].Address,
                      Plan.Steps[StepIndex].Data);
                except
                  on E: Exception do
                    R := NORIOFailure(nioTransport,
                      'adapter raised ' + E.ClassName + ': ' + E.Message);
                end;

                if not R.Success then
                begin
                  if Plan.Steps[StepIndex].Kind = npsErase then
                    FailFromIO('erase command', R, oeEraseRejected,
                      Plan.Steps[StepIndex].Address, True, True)
                  else
                    FailFromIO('program command', R, oeProgramRejected,
                      Plan.Steps[StepIndex].Address, True, True);
                end;

                // Even when the transport reports failure, the opcode may have
                // reached the chip.  Attempt to drain it before cleanup.
                if Plan.Steps[StepIndex].Kind = npsErase then
                  CommandTimeoutMs := FOptions.EraseTimeoutMs
                else
                  CommandTimeoutMs := FOptions.ProgramTimeoutMs;
                if not DrainCriticalCommand(Plan.Steps[StepIndex].Address,
                                            CommandTimeoutMs) then
                begin
                  State.EndCriticalCommand;
                  Break;
                end;

                State.EndCriticalCommand;
                State.CommandFinished(
                  NORPlanStepKindName(Plan.Steps[StepIndex].Kind),
                  Plan.Steps[StepIndex].Address,
                  Plan.Steps[StepIndex].Length);
                if Pending.Code <> oeNone then Break;
                if State.CancellationPending then
                begin
                  CancelAfterDrain := True;
                  Break;
                end;
              end;

            npsVerify:
              begin
                R := FDevice.Read(Plan.Steps[StepIndex].Address,
                                  Plan.Steps[StepIndex].Length, ReadBack);
                if not R.Success then
                begin
                  FailFromIO('verify read', R, oeTransport,
                    Plan.Steps[StepIndex].Address, True, False);
                  Break;
                end;
                if (R.Transferred <> Plan.Steps[StepIndex].Length) or
                   (Length(ReadBack) <> Plan.Steps[StepIndex].Length) then
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
                      'chip does not match the preservation-aware plan',
                      ddKnownSafe,
                      Plan.Steps[StepIndex].Address + QWord(ByteIndex), True);
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
            try
              if not FEvidenceCommit(Request, EvidenceError) then
                SetPending(Pending, oeEvidenceCommitFailed,
                  'evidence commit failed: ' + EvidenceError, ddKnownSafe);
            except
              on E: Exception do
                // Physical verification and bus cleanup have already
                // completed.  A storage callback exception is therefore an
                // evidence failure, not a transport ambiguity.
                SetPending(Pending, oeEvidenceCommitFailed,
                  'evidence commit raised ' + E.ClassName + ': ' + E.Message,
                  ddKnownSafe);
            end;
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
        // Protect against an unexpected language/runtime exception in an
        // adapter. Cleanup is idempotent by the Opened/Initialized flags.
        if State.InCriticalCommand then
        begin
          State.EndCriticalCommand;
          if Pending.Code = oeNone then
            SetPending(Pending, oeTransport,
              'executor unwound while a destructive command was in flight',
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
