unit operationrunner;

// Deep, presentation-neutral interface for trusted SPI NOR operations.
//
// Callers provide an immutable request and a TNORDevice adapter.  The runner
// owns the safety workflow that used to be repeated by front ends: acquire two
// matching full-chip snapshots, build a preservation-aware plan, optionally
// return that plan without mutation, and execute it through the transactional
// NOR engine.  GUI and CLI code only translate inputs and render the response.

{$mode objfpc}{$H+}

interface

uses
  SysUtils, operationmodel, norplanner, norengine;

type
  TNOROperationMode = (
    nomRead,
    nomSmartPreview,
    nomSmartWrite
  );

  TNOROperationInput = record
    Mode: TNOROperationMode;
    Operation: TOperationRequest;
    Geometry: TNORGeometry;
    Patch: TBytes;
    ReadPasses: cardinal;
  end;

  TNOROperationResponse = record
    Outcome: TOperationOutcome;
    // nomRead returns the requested range.  Smart modes return the trusted
    // full-chip snapshot so a caller can publish the pre-write backup without
    // rereading the device.
    Data: TBytes;
    Plan: TNORPlan;
    HasPlan: boolean;
  end;

  TOperationBackupProc = function(const Request: TOperationRequest;
    const Snapshot: TBytes; out ErrorText: string): boolean of object;

  TNOROperationRunner = class
  private
    FDevice: TNORDevice;
    FOnEvent: TOperationEventProc;
    FClock: TOperationClockProc;
    FBackupCommit: TOperationBackupProc;
    FEvidenceCommit: TOperationEvidenceProc;
    FExecuting: LongInt;
    function ReadSession(const Request: TOperationRequest; Address,
      Len: QWord; Passes: cardinal; Token: TCancellationToken;
      out Data: TBytes): TOperationOutcome;
    function FailedOutcome(const Request: TOperationRequest;
      Code: TOperationErrorCode; const ErrorText: string;
      Address: QWord = 0; HasAddress: boolean = False): TOperationOutcome;
  public
    constructor Create(Device: TNORDevice;
      OnEvent: TOperationEventProc = nil; Clock: TOperationClockProc = nil;
      BackupCommit: TOperationBackupProc = nil;
      EvidenceCommit: TOperationEvidenceProc = nil);
    function Execute(const Input: TNOROperationInput;
      Token: TCancellationToken = nil): TNOROperationResponse;
  end;

procedure InitNOROperationInput(out Input: TNOROperationInput);

implementation

type
  TReadFailure = record
    Code: TOperationErrorCode;
    Text: string;
    Address: QWord;
    HasAddress: boolean;
    Disposition: TDeviceDisposition;
  end;

procedure InitNOROperationInput(out Input: TNOROperationInput);
begin
  Input := Default(TNOROperationInput);
  Input.Mode := nomRead;
  InitOperationRequest(Input.Operation);
  Input.ReadPasses := 2;
end;

function SameBytes(const A, B: array of byte; out Difference: QWord): boolean;
var
  I: SizeInt;
begin
  Difference := 0;
  Result := Length(A) = Length(B);
  if not Result then Exit;
  for I := 0 to High(A) do
    if A[I] <> B[I] then
    begin
      Difference := QWord(I);
      Exit(False);
    end;
end;

function MapReadError(const R: TNORIOResult;
  OpenOrInit: TOperationErrorCode): TOperationErrorCode;
begin
  case R.Error of
    nioDisconnected: Result := oeDisconnected;
    nioTimeout: Result := oeTimeout;
    nioBusy: Result := oeDeviceBusy;
    nioRejected: Result := OpenOrInit;
  else
    Result := oeTransport;
  end;
end;

function WithContext(const Context: string; const R: TNORIOResult): string;
begin
  Result := Context;
  if R.ErrorText <> '' then Result := Result + ': ' + R.ErrorText;
end;

procedure KeepFirstFailure(var Failure: TReadFailure;
  Code: TOperationErrorCode; const ErrorText: string;
  Disposition: TDeviceDisposition; Address: QWord = 0;
  HasAddress: boolean = False);
begin
  if Failure.Code = oeNone then
  begin
    Failure.Code := Code;
    Failure.Text := ErrorText;
    Failure.Address := Address;
    Failure.HasAddress := HasAddress;
    Failure.Disposition := Disposition;
  end
  else if Ord(Disposition) > Ord(Failure.Disposition) then
    Failure.Disposition := Disposition;
end;

constructor TNOROperationRunner.Create(Device: TNORDevice;
  OnEvent: TOperationEventProc; Clock: TOperationClockProc;
  BackupCommit: TOperationBackupProc;
  EvidenceCommit: TOperationEvidenceProc);
begin
  inherited Create;
  FDevice := Device;
  FOnEvent := OnEvent;
  FClock := Clock;
  FBackupCommit := BackupCommit;
  FEvidenceCommit := EvidenceCommit;
  FExecuting := 0;
end;

function TNOROperationRunner.FailedOutcome(const Request: TOperationRequest;
  Code: TOperationErrorCode; const ErrorText: string; Address: QWord;
  HasAddress: boolean): TOperationOutcome;
var
  State: TOperationStateMachine;
begin
  State := TOperationStateMachine.Create(Request, nil, FOnEvent, FClock);
  try
    State.Start;
    State.AdvanceTo(opValidating);
    State.Fail(Code, ErrorText, ddNotOpened, Address, HasAddress);
    Result := State.Outcome;
  finally
    State.Free;
  end;
end;

function TNOROperationRunner.ReadSession(const Request: TOperationRequest;
  Address, Len: QWord; Passes: cardinal; Token: TCancellationToken;
  out Data: TBytes): TOperationOutcome;
var
  ProbeRequest: TOperationRequest;
  State: TOperationStateMachine;
  LocalToken: TCancellationToken;
  OwnToken: boolean;
  Failure: TReadFailure;
  R, Cleanup: TNORIOResult;
  Current: TBytes;
  Difference: QWord;
  Pass: cardinal;
  Opened, Initialized, Cancelled: boolean;
begin
  Data := nil;
  ProbeRequest := Request;
  ProbeRequest.Kind := okRead;
  ProbeRequest.Target.Address := Address;
  ProbeRequest.Target.Length := Len;
  ProbeRequest.Policy.RequireTrustedBackup := False;
  ProbeRequest.Policy.RequireFullVerify := False;
  ProbeRequest.Policy.RequireEvidenceCommit := False;

  FillChar(Failure, SizeOf(Failure), 0);
  Failure.Code := oeNone;
  Failure.Disposition := ddNotOpened;
  Opened := False;
  Initialized := False;
  Cancelled := False;
  OwnToken := Token = nil;
  if OwnToken then LocalToken := TCancellationToken.Create
  else LocalToken := Token;

  State := TOperationStateMachine.Create(ProbeRequest, LocalToken,
    FOnEvent, FClock);
  try
    State.Start;
    State.AdvanceTo(opValidating);
    if FDevice = nil then
      KeepFirstFailure(Failure, oeInvalidRequest, 'NOR device is nil',
        ddNotOpened)
    else if (Passes < 2) or (Passes > 16) then
      KeepFirstFailure(Failure, oeInvalidRequest,
        'trusted read pass count must be from 2 through 16', ddNotOpened)
    else if (Len > QWord(High(SizeInt))) or (Len > High(cardinal)) then
      KeepFirstFailure(Failure, oeInvalidRequest,
        'requested range is too large for this process', ddNotOpened)
    else if (Address > Request.Chip.Capacity) or
            (Len > Request.Chip.Capacity - Address) then
      KeepFirstFailure(Failure, oeInvalidRequest,
        'requested range runs past the declared chip capacity', ddNotOpened);

    try
      if Failure.Code = oeNone then
      begin
        State.AdvanceTo(opReservingDevice);
        State.AdvanceTo(opOpening);
        R := FDevice.Open;
        if not R.Success then
          KeepFirstFailure(Failure, MapReadError(R, oeOpenFailed),
            WithContext('device open', R), ddNotOpened)
        else
        begin
          Opened := True;
          Failure.Disposition := ddKnownSafe;
        end;
      end;

      if Failure.Code = oeNone then
      begin
        State.AdvanceTo(opInitializingBus);
        R := FDevice.Initialize;
        if not R.Success then
          KeepFirstFailure(Failure, MapReadError(R, oeBusInitFailed),
            WithContext('bus initialization', R), ddKnownSafe)
        else
          Initialized := True;
      end;

      if Failure.Code = oeNone then
      begin
        State.AdvanceTo(opCheckingContact);
        State.AdvanceTo(opBackingUp);
        State.ReportProgress(0, Len * Passes);
        for Pass := 1 to Passes do
        begin
          if State.CancellationPending then
          begin
            Cancelled := True;
            Break;
          end;
          R := FDevice.Read(Address, cardinal(Len), Current);
          if not R.Success then
          begin
            KeepFirstFailure(Failure, MapReadError(R, oeTransport),
              WithContext(Format('trusted read pass %d', [Pass]), R),
              ddKnownSafe, Address, True);
            Break;
          end;
          if (R.Transferred <> Len) or (QWord(Length(Current)) <> Len) then
          begin
            KeepFirstFailure(Failure, oeShortTransfer,
              Format('trusted read pass %d returned %d of %d bytes',
                [Pass, R.Transferred, Len]), ddKnownSafe, Address, True);
            Break;
          end;
          if Pass = 1 then
            Data := Copy(Current)
          else if not SameBytes(Data, Current, Difference) then
          begin
            KeepFirstFailure(Failure, oeContactUnstable,
              Format('trusted read passes disagree at 0x%x',
                [Address + Difference]), ddKnownSafe,
              Address + Difference, True);
            Break;
          end;
          State.ReportProgress(Len * Pass, Len * Passes);
        end;
      end;
    except
      on E: Exception do
        KeepFirstFailure(Failure, oeTransport,
          'trusted read raised ' + E.ClassName + ': ' + E.Message,
          ddModeUnknown);
    end;

    if Ord(State.Outcome.Phase) < Ord(opQuiescing) then
      State.AdvanceTo(opQuiescing);

    if Initialized then
    begin
      try
        Cleanup := FDevice.Deinitialize;
        if not Cleanup.Success then
          KeepFirstFailure(Failure, oeCleanupFailed,
            WithContext('bus deinitialize cleanup', Cleanup), ddModeUnknown);
      except
        on E: Exception do
          KeepFirstFailure(Failure, oeCleanupFailed,
            'bus deinitialize cleanup raised ' + E.ClassName + ': ' +
            E.Message, ddModeUnknown);
      end;
    end;
    if Opened then
    begin
      try
        Cleanup := FDevice.Close;
        if not Cleanup.Success then
          KeepFirstFailure(Failure, oeCleanupFailed,
            WithContext('device close cleanup', Cleanup), ddModeUnknown);
      except
        on E: Exception do
          KeepFirstFailure(Failure, oeCleanupFailed,
            'device close cleanup raised ' + E.ClassName + ': ' + E.Message,
            ddModeUnknown);
      end;
    end;

    if Failure.Code <> oeNone then
      State.Fail(Failure.Code, Failure.Text, Failure.Disposition,
        Failure.Address, Failure.HasAddress)
    else if Cancelled or State.CancellationPending then
      State.Cancel(ddKnownSafe)
    else
      State.Complete;
    Result := State.Outcome;
  finally
    State.Free;
    if OwnToken then LocalToken.Free;
  end;
end;

function TNOROperationRunner.Execute(const Input: TNOROperationInput;
  Token: TCancellationToken): TNOROperationResponse;
var
  Snapshot: TBytes;
  Err, BackupError: string;
  Executor: TNORPlanExecutor;
  PreviewState: TOperationStateMachine;
begin
  Result := Default(TNOROperationResponse);
  ClearNORPlan(Result.Plan);
  Result.HasPlan := False;

  if InterlockedCompareExchange(FExecuting, 1, 0) <> 0 then
  begin
    Result.Outcome := FailedOutcome(Input.Operation, oeDeviceBusy,
      'this operation runner is already executing');
    Exit;
  end;

  try

    if not ValidateNORGeometry(Input.Geometry, Err) then
    begin
      Result.Outcome := FailedOutcome(Input.Operation, oeInvalidRequest, Err);
      Exit;
    end;
    if (Input.Operation.Chip.Capacity <> 0) and
       (Input.Operation.Chip.Capacity <> Input.Geometry.ChipSize) then
    begin
      Result.Outcome := FailedOutcome(Input.Operation, oeInvalidRequest,
        'request chip capacity does not match geometry');
      Exit;
    end;

    case Input.Mode of
    nomRead:
      begin
        Result.Outcome := ReadSession(Input.Operation,
          Input.Operation.Target.Address, Input.Operation.Target.Length,
          Input.ReadPasses, Token, Result.Data);
        Exit;
      end;

    nomSmartPreview, nomSmartWrite:
      begin
        if QWord(Length(Input.Patch)) <> Input.Operation.Target.Length then
        begin
          Result.Outcome := FailedOutcome(Input.Operation, oeInvalidRequest,
            'patch length does not match the requested operation range');
          Exit;
        end;
        Result.Outcome := ReadSession(Input.Operation, 0,
          Input.Geometry.ChipSize, Input.ReadPasses, Token, Snapshot);
        Result.Outcome.Kind := Input.Operation.Kind;
        Result.Outcome.OperationID := Input.Operation.OperationID;
        Result.Data := Snapshot;
        if Result.Outcome.Status <> osSucceeded then Exit;

        if not BuildNORDifferentialPlan(Snapshot, Input.Patch,
          Input.Operation.Target.Address, Input.Geometry, Result.Plan, Err) then
        begin
          Result.Outcome := FailedOutcome(Input.Operation, oeInvalidPlan, Err);
          Exit;
        end;
        Result.HasPlan := True;

        if Input.Mode = nomSmartPreview then
        begin
          PreviewState := TOperationStateMachine.Create(Input.Operation, Token,
            FOnEvent, FClock);
          try
            PreviewState.Start;
            PreviewState.AdvanceTo(opValidating);
            PreviewState.AdvanceTo(opPlanning);
            PreviewState.ReportProgress(0, Result.Plan.EraseBytes +
              Result.Plan.ProgramBytes + Result.Plan.VerifyBytes);
            PreviewState.AdvanceTo(opQuiescing);
            PreviewState.Complete;
            Result.Outcome := PreviewState.Outcome;
          finally
            PreviewState.Free;
          end;
          Exit;
        end;

        // A required backup is a precondition of mutation, not a file the
        // caller may choose to save after success.  Publishing through this
        // seam makes it impossible for a front end to accidentally program
        // first and discover a full disk or invalid destination afterward.
        if Input.Operation.Policy.RequireTrustedBackup and
           NORPlanHasDestructiveSteps(Result.Plan) then
        begin
          if not Assigned(FBackupCommit) then
          begin
            Result.Outcome := FailedOutcome(Input.Operation,
              oeBackupUntrusted,
              'a trusted backup is required but no backup sink was provided');
            Exit;
          end;
          BackupError := '';
          try
            if not FBackupCommit(Input.Operation, Snapshot, BackupError) then
            begin
              if BackupError = '' then
                BackupError := 'the backup sink refused the trusted snapshot';
              Result.Outcome := FailedOutcome(Input.Operation,
                oeBackupUntrusted, BackupError);
              Exit;
            end;
          except
            on E: Exception do
            begin
              Result.Outcome := FailedOutcome(Input.Operation,
                oeBackupUntrusted, 'backup commit raised ' + E.ClassName +
                ': ' + E.Message);
              Exit;
            end;
          end;
        end;

        Executor := TNORPlanExecutor.Create(FDevice, FOnEvent, FClock,
          FEvidenceCommit);
        try
          Result.Outcome := Executor.ExecuteBound(Input.Operation, Result.Plan,
            Input.Geometry, Snapshot, Token);
        finally
          Executor.Free;
        end;
      end;
    end;
  finally
    InterlockedExchange(FExecuting, 0);
  end;
end;

end.
