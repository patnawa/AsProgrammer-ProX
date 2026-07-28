unit operationmodel;

// Headless operation contracts shared by future GUI, CLI and test runners.
//
// This unit deliberately has no LCL or hardware dependencies.  An operation
// request is an immutable snapshot from the executor's point of view; outcomes
// and events use stable enum values instead of asking callers to parse log text.
//
// Cancellation is cooperative.  A token may be requested from another thread,
// but TOperationStateMachine will not enter the cancelled terminal state while
// a physical erase/program command is in flight.  The executor must first poll
// that command to a known quiescent state and call EndCriticalCommand.

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

type
  TOperationKind = (
    okNone,
    okRead,
    okProgram,
    okErase,
    okVerify,
    okDetect
  );

  TOperationStatus = (
    osNotStarted,
    osRunning,
    osSucceeded,
    osFailed,
    osCancelled
  );

  TOperationPhase = (
    opCreated,
    opValidating,
    opReservingDevice,
    opOpening,
    opInitializingBus,
    opIdentifying,
    opCheckingContact,
    opBackingUp,
    opPlanning,
    opCheckingProtection,
    opExecuting,
    opVerifying,
    opQuiescing,
    opCommittingEvidence,
    opCompleted
  );

  TOperationErrorCode = (
    oeNone,
    oeInvalidRequest,
    oeInvalidPlan,
    oeDeviceBusy,
    oeOpenFailed,
    oeBusInitFailed,
    oeTransport,
    oeShortTransfer,
    oeTimeout,
    oeDisconnected,
    oeIdentityMismatch,
    oeContactUnstable,
    oeBackupUntrusted,
    oeProtected,
    oeWriteEnableRejected,
    oeEraseRejected,
    oeProgramRejected,
    oeVerifyMismatch,
    oeCleanupFailed,
    oeEvidenceCommitFailed,
    oeCancelled,
    oeInternalState
  );

  // Whether another tool may safely assume that the chip is idle and back in
  // its ordinary command mode after this operation.
  TDeviceDisposition = (
    ddNotOpened,
    ddKnownSafe,
    ddBusyUnknown,
    ddDisconnectedUnknown,
    ddModeUnknown
  );

  TOperationEventKind = (
    evOperationStarted,
    evPhaseChanged,
    evProgress,
    evCommandStarted,
    evCommandFinished,
    evWarning,
    evFailure,
    evCancelled,
    evOperationFinished
  );

  TOperationRange = record
    Address: QWord;
    Length: QWord;
  end;

  TChipIdentity = record
    Name: string;
    JedecID: string;
    UniqueID: string;
    ProfileHash: string;
    Capacity: QWord;
  end;

  TOperationPolicy = record
    RequireTrustedBackup: boolean;
    RequireStableIdentity: boolean;
    RequireFullVerify: boolean;
    RequireEvidenceCommit: boolean;
    PreserveOutsideRange: boolean;
  end;

  TOperationRequest = record
    OperationID: string;
    Kind: TOperationKind;
    Target: TOperationRange;
    Chip: TChipIdentity;
    ImageHash: string;
    Policy: TOperationPolicy;
  end;

  TOperationOutcome = record
    OperationID: string;
    Kind: TOperationKind;
    Status: TOperationStatus;
    Phase: TOperationPhase;
    ErrorCode: TOperationErrorCode;
    ErrorText: string;
    FailureAddress: QWord;
    HasFailureAddress: boolean;
    BytesPlanned: QWord;
    BytesCompleted: QWord;
    StartedAtMs: QWord;
    FinishedAtMs: QWord;
    DeviceDisposition: TDeviceDisposition;
    PhysicalVerifyCompleted: boolean;
  end;

  TOperationEvent = record
    OperationID: string;
    Sequence: QWord;
    TimestampMs: QWord;
    Kind: TOperationEventKind;
    Phase: TOperationPhase;
    ErrorCode: TOperationErrorCode;
    MessageText: string;
    Address: QWord;
    Length: QWord;
    HasAddress: boolean;
    Attempt: cardinal;
    BytesDone: QWord;
    BytesTotal: QWord;
  end;

  // The record is copied into the receiver.  Event producers never retain or
  // mutate an event after publishing it.
  TOperationEventProc = procedure(const Event: TOperationEvent) of object;
  TOperationClockProc = function: QWord of object;

  TCancellationToken = class
  private
    FRequested: LongInt;
  public
    constructor Create;
    procedure RequestCancellation;
    function IsCancellationRequested: boolean;
  end;

  // Small, deterministic lifecycle guard.  It rejects backwards phase moves,
  // prevents success/failure from being overwritten, and enforces deferred
  // cancellation while a destructive command is physically in flight.
  TOperationStateMachine = class
  private
    FRequest: TOperationRequest;
    FOutcome: TOperationOutcome;
    FToken: TCancellationToken;
    FOnEvent: TOperationEventProc;
    FClock: TOperationClockProc;
    FSequence: QWord;
    FInCriticalCommand: boolean;
    function NowMs: QWord;
    procedure Publish(Kind: TOperationEventKind; const Msg: string = '';
      ErrorCode: TOperationErrorCode = oeNone; Address: QWord = 0;
      HasAddress: boolean = False; Len: QWord = 0);
  public
    constructor Create(const Request: TOperationRequest;
      Token: TCancellationToken; OnEvent: TOperationEventProc = nil;
      Clock: TOperationClockProc = nil);
    procedure Start;
    function AdvanceTo(NewPhase: TOperationPhase): boolean;
    function TryBeginCriticalCommand: boolean;
    procedure EndCriticalCommand;
    procedure ReportProgress(BytesDone, BytesTotal: QWord);
    procedure CommandStarted(const Msg: string; Address, Len: QWord);
    procedure CommandFinished(const Msg: string; Address, Len: QWord);
    procedure MarkPhysicalVerifyCompleted;
    procedure Warn(const Msg: string; Address: QWord = 0;
      HasAddress: boolean = False);
    procedure Fail(Code: TOperationErrorCode; const Msg: string;
      Disposition: TDeviceDisposition; Address: QWord = 0;
      HasAddress: boolean = False);
    function Cancel(Disposition: TDeviceDisposition;
      const Msg: string = 'cancelled by request'): boolean;
    function Complete: boolean;
    function IsTerminal: boolean;
    function CancellationPending: boolean;
    property Outcome: TOperationOutcome read FOutcome;
    property InCriticalCommand: boolean read FInCriticalCommand;
  end;

procedure InitOperationRequest(out Request: TOperationRequest);
function IsValidPhaseAdvance(Current, Next: TOperationPhase): boolean;
function OperationErrorName(Code: TOperationErrorCode): string;
function OperationPhaseName(Phase: TOperationPhase): string;

implementation

procedure InitOperationRequest(out Request: TOperationRequest);
begin
  FillChar(Request, SizeOf(Request), 0);
  Request.Kind := okNone;
  Request.Policy.RequireTrustedBackup := True;
  Request.Policy.RequireStableIdentity := True;
  Request.Policy.RequireFullVerify := True;
  Request.Policy.RequireEvidenceCommit := True;
  Request.Policy.PreserveOutsideRange := True;
end;

function IsValidPhaseAdvance(Current, Next: TOperationPhase): boolean;
begin
  // Phases are declared in their only legal forward order.  Skipping an
  // optional phase is allowed; moving backwards or remaining in place is not.
  Result := Ord(Next) > Ord(Current);
end;

function OperationErrorName(Code: TOperationErrorCode): string;
begin
  case Code of
    oeNone:                 Result := 'none';
    oeInvalidRequest:       Result := 'invalid_request';
    oeInvalidPlan:          Result := 'invalid_plan';
    oeDeviceBusy:           Result := 'device_busy';
    oeOpenFailed:           Result := 'open_failed';
    oeBusInitFailed:        Result := 'bus_init_failed';
    oeTransport:            Result := 'transport';
    oeShortTransfer:        Result := 'short_transfer';
    oeTimeout:              Result := 'timeout';
    oeDisconnected:         Result := 'disconnected';
    oeIdentityMismatch:     Result := 'identity_mismatch';
    oeContactUnstable:      Result := 'contact_unstable';
    oeBackupUntrusted:      Result := 'backup_untrusted';
    oeProtected:            Result := 'protected';
    oeWriteEnableRejected:  Result := 'write_enable_rejected';
    oeEraseRejected:        Result := 'erase_rejected';
    oeProgramRejected:      Result := 'program_rejected';
    oeVerifyMismatch:       Result := 'verify_mismatch';
    oeCleanupFailed:        Result := 'cleanup_failed';
    oeEvidenceCommitFailed: Result := 'evidence_commit_failed';
    oeCancelled:            Result := 'cancelled';
    oeInternalState:        Result := 'internal_state';
  else
    Result := 'unknown';
  end;
end;

function OperationPhaseName(Phase: TOperationPhase): string;
begin
  case Phase of
    opCreated:            Result := 'created';
    opValidating:         Result := 'validating';
    opReservingDevice:    Result := 'reserving_device';
    opOpening:            Result := 'opening';
    opInitializingBus:    Result := 'initializing_bus';
    opIdentifying:        Result := 'identifying';
    opCheckingContact:    Result := 'checking_contact';
    opBackingUp:          Result := 'backing_up';
    opPlanning:           Result := 'planning';
    opCheckingProtection: Result := 'checking_protection';
    opExecuting:          Result := 'executing';
    opVerifying:          Result := 'verifying';
    opQuiescing:          Result := 'quiescing';
    opCommittingEvidence: Result := 'committing_evidence';
    opCompleted:          Result := 'completed';
  else
    Result := 'unknown';
  end;
end;

constructor TCancellationToken.Create;
begin
  inherited Create;
  FRequested := 0;
end;

procedure TCancellationToken.RequestCancellation;
begin
  InterlockedExchange(FRequested, 1);
end;

function TCancellationToken.IsCancellationRequested: boolean;
begin
  Result := InterlockedCompareExchange(FRequested, 0, 0) <> 0;
end;

constructor TOperationStateMachine.Create(const Request: TOperationRequest;
  Token: TCancellationToken; OnEvent: TOperationEventProc;
  Clock: TOperationClockProc);
begin
  inherited Create;
  FRequest := Request;
  FToken := Token;
  FOnEvent := OnEvent;
  FClock := Clock;
  FSequence := 0;
  FInCriticalCommand := False;

  FillChar(FOutcome, SizeOf(FOutcome), 0);
  FOutcome.OperationID := Request.OperationID;
  FOutcome.Kind := Request.Kind;
  FOutcome.Status := osNotStarted;
  FOutcome.Phase := opCreated;
  FOutcome.ErrorCode := oeNone;
  FOutcome.DeviceDisposition := ddNotOpened;
end;

function TOperationStateMachine.NowMs: QWord;
begin
  if Assigned(FClock) then
    Result := FClock()
  else
    Result := GetTickCount64;
end;

procedure TOperationStateMachine.Publish(Kind: TOperationEventKind;
  const Msg: string; ErrorCode: TOperationErrorCode; Address: QWord;
  HasAddress: boolean; Len: QWord);
var
  E: TOperationEvent;
begin
  if not Assigned(FOnEvent) then Exit;

  FillChar(E, SizeOf(E), 0);
  Inc(FSequence);
  E.OperationID := FRequest.OperationID;
  E.Sequence := FSequence;
  E.TimestampMs := NowMs;
  E.Kind := Kind;
  E.Phase := FOutcome.Phase;
  E.ErrorCode := ErrorCode;
  E.MessageText := Msg;
  E.Address := Address;
  E.HasAddress := HasAddress;
  E.Length := Len;
  E.BytesDone := FOutcome.BytesCompleted;
  E.BytesTotal := FOutcome.BytesPlanned;
  FOnEvent(E);
end;

procedure TOperationStateMachine.Start;
begin
  if FOutcome.Status <> osNotStarted then Exit;
  FOutcome.Status := osRunning;
  FOutcome.StartedAtMs := NowMs;
  Publish(evOperationStarted);
end;

function TOperationStateMachine.AdvanceTo(NewPhase: TOperationPhase): boolean;
begin
  Result := False;
  if FOutcome.Status <> osRunning then Exit;

  if not IsValidPhaseAdvance(FOutcome.Phase, NewPhase) then
  begin
    Fail(oeInternalState,
      Format('invalid phase transition %s -> %s',
        [OperationPhaseName(FOutcome.Phase), OperationPhaseName(NewPhase)]),
      FOutcome.DeviceDisposition);
    Exit;
  end;

  FOutcome.Phase := NewPhase;
  Publish(evPhaseChanged, OperationPhaseName(NewPhase));
  Result := True;
end;

function TOperationStateMachine.TryBeginCriticalCommand: boolean;
begin
  Result := False;
  if FOutcome.Status <> osRunning then Exit;
  if FInCriticalCommand then
  begin
    Fail(oeInternalState, 'a critical command is already in flight',
      FOutcome.DeviceDisposition);
    Exit;
  end;
  if CancellationPending then Exit;

  FInCriticalCommand := True;
  Result := True;
end;

procedure TOperationStateMachine.EndCriticalCommand;
begin
  FInCriticalCommand := False;
end;

procedure TOperationStateMachine.ReportProgress(BytesDone, BytesTotal: QWord);
begin
  if FOutcome.Status <> osRunning then Exit;
  if BytesDone > BytesTotal then BytesDone := BytesTotal;
  FOutcome.BytesCompleted := BytesDone;
  FOutcome.BytesPlanned := BytesTotal;
  Publish(evProgress);
end;

procedure TOperationStateMachine.CommandStarted(const Msg: string;
  Address, Len: QWord);
begin
  Publish(evCommandStarted, Msg, oeNone, Address, True, Len);
end;

procedure TOperationStateMachine.CommandFinished(const Msg: string;
  Address, Len: QWord);
begin
  Publish(evCommandFinished, Msg, oeNone, Address, True, Len);
end;

procedure TOperationStateMachine.MarkPhysicalVerifyCompleted;
begin
  if FOutcome.Status = osRunning then
    FOutcome.PhysicalVerifyCompleted := True;
end;

procedure TOperationStateMachine.Warn(const Msg: string; Address: QWord;
  HasAddress: boolean);
begin
  Publish(evWarning, Msg, oeNone, Address, HasAddress);
end;

procedure TOperationStateMachine.Fail(Code: TOperationErrorCode;
  const Msg: string; Disposition: TDeviceDisposition; Address: QWord;
  HasAddress: boolean);
begin
  if IsTerminal then Exit;
  FOutcome.Status := osFailed;
  FOutcome.ErrorCode := Code;
  FOutcome.ErrorText := Msg;
  FOutcome.DeviceDisposition := Disposition;
  FOutcome.FailureAddress := Address;
  FOutcome.HasFailureAddress := HasAddress;
  FOutcome.FinishedAtMs := NowMs;
  Publish(evFailure, Msg, Code, Address, HasAddress);
  Publish(evOperationFinished, Msg, Code, Address, HasAddress);
end;

function TOperationStateMachine.Cancel(Disposition: TDeviceDisposition;
  const Msg: string): boolean;
begin
  Result := False;
  if IsTerminal then Exit;

  // A physical command may still be changing the chip.  The executor must
  // continue polling it and explicitly end the critical section first.
  if FInCriticalCommand then Exit;

  FOutcome.Status := osCancelled;
  FOutcome.ErrorCode := oeCancelled;
  FOutcome.ErrorText := Msg;
  FOutcome.DeviceDisposition := Disposition;
  FOutcome.FinishedAtMs := NowMs;
  Publish(evCancelled, Msg, oeCancelled);
  Publish(evOperationFinished, Msg, oeCancelled);
  Result := True;
end;

function TOperationStateMachine.Complete: boolean;
begin
  Result := False;
  if FOutcome.Status <> osRunning then Exit;
  if FInCriticalCommand then
  begin
    Fail(oeInternalState, 'cannot complete with a critical command in flight',
      FOutcome.DeviceDisposition);
    Exit;
  end;

  if FOutcome.Phase <> opCompleted then
    if not AdvanceTo(opCompleted) then Exit;

  FOutcome.Status := osSucceeded;
  FOutcome.ErrorCode := oeNone;
  FOutcome.ErrorText := '';
  FOutcome.DeviceDisposition := ddKnownSafe;
  FOutcome.FinishedAtMs := NowMs;
  Publish(evOperationFinished);
  Result := True;
end;

function TOperationStateMachine.IsTerminal: boolean;
begin
  Result := FOutcome.Status in [osSucceeded, osFailed, osCancelled];
end;

function TOperationStateMachine.CancellationPending: boolean;
begin
  Result := (FToken <> nil) and FToken.IsCancellationRequested;
end;

end.
