program norengine_tests;

// Whole-operation tests for operationmodel, norplanner, norengine and the
// stateful virtual SPI25 device.  No GUI or real programmer is involved.

{$mode objfpc}{$H+}

uses
  SysUtils, operationmodel, norplanner, norengine, virtualspi25;

const
  PROPERTY_ROUNDS = 500;

type
  TEventRecorder = class
  private
    FNow: QWord;
  public
    Events: array of TOperationEvent;
    procedure Receive(const Event: TOperationEvent);
    function NowMs: QWord;
    function HasKind(Kind: TOperationEventKind): boolean;
    function SequencesAreStrictlyIncreasing: boolean;
  end;

  // Simulates the hardest transport ambiguity: the adapter accepts an erase,
  // then raises before it can report success to the executor.
  TRaiseAfterEraseSPI25 = class(TVirtualSPI25)
  public
    function Erase(Address: QWord; Len: cardinal;
      Opcode: byte): TNORIOResult; override;
  end;

var
  Failures: integer = 0;
  Assertions: integer = 0;

procedure Check(const Name: string; Condition: boolean);
begin
  Inc(Assertions);
  if not Condition then
  begin
    Inc(Failures);
    WriteLn('  FAIL  ', Name);
  end;
end;

procedure TEventRecorder.Receive(const Event: TOperationEvent);
var
  N: SizeInt;
begin
  N := Length(Events);
  SetLength(Events, N + 1);
  Events[N] := Event;
end;

function TEventRecorder.NowMs: QWord;
begin
  Inc(FNow);
  Result := FNow;
end;

function TEventRecorder.HasKind(Kind: TOperationEventKind): boolean;
var
  i: SizeInt;
begin
  Result := False;
  for i := 0 to High(Events) do
    if Events[i].Kind = Kind then Exit(True);
end;

function TEventRecorder.SequencesAreStrictlyIncreasing: boolean;
var
  i: SizeInt;
begin
  Result := True;
  for i := 1 to High(Events) do
    if Events[i].Sequence <= Events[i - 1].Sequence then Exit(False);
end;

function TRaiseAfterEraseSPI25.Erase(Address: QWord; Len: cardinal;
  Opcode: byte): TNORIOResult;
begin
  Result := inherited Erase(Address, Len, Opcode);
  if Result.Success then
    raise Exception.Create('injected exception after erase delivery');
end;

procedure CopyArray(const Source: array of byte; out Dest: TBytes);
begin
  Dest := nil;
  SetLength(Dest, Length(Source));
  if Length(Source) > 0 then Move(Source[0], Dest[0], Length(Source));
end;

procedure Overlay(var Image: TBytes; Address: QWord;
  const Patch: array of byte);
begin
  if Length(Patch) > 0 then
    Move(Patch[0], Image[SizeInt(Address)], Length(Patch));
end;

function SameBytes(const A, B: array of byte): boolean;
var
  i: SizeInt;
begin
  Result := Length(A) = Length(B);
  if not Result then Exit;
  for i := 0 to High(A) do
    if A[i] <> B[i] then Exit(False);
end;

function NoMutationAfterCall(const Calls: TVirtualCalls;
  FailedCall: cardinal): boolean;
var
  i: SizeInt;
begin
  Result := True;
  // FailedCall is one-based.  The failed call itself may be a destructive
  // opcode with an unknown delivery result; no later one may be attempted.
  for i := SizeInt(FailedCall) to High(Calls) do
    if Calls[i].Mutating then Exit(False);
end;

function MakeRequest(Address, Len, Capacity: QWord): TOperationRequest;
begin
  InitOperationRequest(Result);
  Result.OperationID := 'virtual-test';
  Result.Kind := okProgram;
  Result.Target.Address := Address;
  Result.Target.Length := Len;
  Result.Chip.Name := 'virtual-spi25';
  Result.Chip.JedecID := 'EF4017';
  Result.Chip.Capacity := Capacity;
  Result.ImageHash := 'test-image';
  // The low-level executor proves the physical transaction.  An outer safe
  // operation owns durable backup and evidence sinks.
  Result.Policy.RequireEvidenceCommit := False;
end;

function MakeGeometry(ChipSize, PageSize, EraseSize: cardinal;
  out Geometry: TNORGeometry): boolean;
var
  Err: string;
begin
  Result := BuildUniformNORGeometry(ChipSize, PageSize, EraseSize, $20,
                                    Geometry, Err);
  if not Result then WriteLn('  geometry error: ', Err);
end;

procedure TestLifecycleCancellation;
var
  Request: TOperationRequest;
  Token: TCancellationToken;
  State: TOperationStateMachine;
begin
  WriteLn('Lifecycle: cancellation is deferred across physical commands');
  Request := MakeRequest(0, 1, 256);
  Token := TCancellationToken.Create;
  State := TOperationStateMachine.Create(Request, Token);
  try
    State.Start;
    Check('advance to execution', State.AdvanceTo(opExecuting));
    Check('critical command starts', State.TryBeginCriticalCommand);
    Token.RequestCancellation;
    Check('cancel cannot become terminal while command is in flight',
          not State.Cancel(ddKnownSafe));
    Check('state is still running', State.Outcome.Status = osRunning);
    State.EndCriticalCommand;
    Check('cancel succeeds after command drains', State.Cancel(ddKnownSafe));
    Check('terminal state is cancelled',
          State.Outcome.Status = osCancelled);
  finally
    State.Free;
    Token.Free;
  end;
end;

procedure TestPreservationPlanAndExecution;
const
  CHIP = 512;
  PATCH_ADDRESS = 70;
  PATCH_LENGTH = 210;
var
  Geometry: TNORGeometry;
  Initial, Patch, Expected: TBytes;
  Plan: TNORPlan;
  Request: TOperationRequest;
  Device: TVirtualSPI25;
  Executor: TNORPlanExecutor;
  Token: TCancellationToken;
  Outcome: TOperationOutcome;
  Recorder: TEventRecorder;
  Err: string;
  i: integer;
begin
  WriteLn('Transactional plan: erased neighbours are restored and verified');
  Check('uniform geometry created', MakeGeometry(CHIP, 16, 64, Geometry));

  SetLength(Initial, CHIP);
  for i := 0 to High(Initial) do
    Initial[i] := byte((i * 37 + (i div 7) * 11 + 3) and $FF);
  Initial[PATCH_ADDRESS] := $00; // patching this to FF guarantees an erase

  SetLength(Patch, PATCH_LENGTH);
  for i := 0 to High(Patch) do
    Patch[i] := byte((i * 19 + 91) and $FF);
  Patch[0] := $FF;

  CopyArray(Initial, Expected);
  Overlay(Expected, PATCH_ADDRESS, Patch);

  Check('plan builds',
    BuildNORDifferentialPlan(Initial, Patch, PATCH_ADDRESS, Geometry,
                             Plan, Err));
  Check('plan validates', ValidateNORPlan(Plan, Geometry, Err));
  Check('at least one erase is required',
        NORPlanCountKind(Plan, npsErase) > 0);
  Check('neighbour bytes are explicitly restored',
        Plan.PreservedBytesRewritten > 0);
  Check('every changed block is fully verified',
        NORPlanCountKind(Plan, npsVerify) > 0);

  Request := MakeRequest(PATCH_ADDRESS, PATCH_LENGTH, CHIP);
  Token := TCancellationToken.Create;
  Recorder := TEventRecorder.Create;
  Device := TVirtualSPI25.Create(Geometry, Initial);
  Device.CancellationToken := Token;
  Executor := TNORPlanExecutor.Create(Device, @Recorder.Receive,
                                      @Recorder.NowMs);
  try
    Outcome := Executor.Execute(Request, Plan, Geometry, Token);
    Check('operation succeeds', Outcome.Status = osSucceeded);
    Check('final memory exactly matches the ideal overlay',
          Device.MemoryEquals(Expected));
    Check('device was deinitialized exactly once',
          Device.DeinitializeCalls = 1);
    Check('device was closed exactly once', Device.CloseCalls = 1);
    Check('chip is idle after success', not Device.IsBusy);
    Check('WEL is clear after success', not Device.WriteEnabled);
    Check('events include command starts',
          Recorder.HasKind(evCommandStarted));
    Check('events include final success',
          Recorder.HasKind(evOperationFinished));
    Check('event sequence is strictly increasing',
          Recorder.SequencesAreStrictlyIncreasing);
  finally
    Executor.Free;
    Device.Free;
    Recorder.Free;
    Token.Free;
  end;
end;

procedure TestNoEraseAndIdempotence;
const
  CHIP = 256;
  PATCH_ADDRESS = 31;
  PATCH_LENGTH = 90;
var
  Geometry: TNORGeometry;
  Initial, Patch, Expected: TBytes;
  Plan, SecondPlan: TNORPlan;
  Request: TOperationRequest;
  Device: TVirtualSPI25;
  Executor: TNORPlanExecutor;
  Token: TCancellationToken;
  Outcome: TOperationOutcome;
  Err: string;
  i: integer;
begin
  WriteLn('Differential plan: legal 1->0 updates erase nothing; rerun is verified');
  Check('uniform geometry created', MakeGeometry(CHIP, 16, 64, Geometry));
  SetLength(Initial, CHIP);
  FillByte(Initial[0], Length(Initial), $FF);
  SetLength(Patch, PATCH_LENGTH);
  for i := 0 to High(Patch) do Patch[i] := byte(i * 13);

  CopyArray(Initial, Expected);
  Overlay(Expected, PATCH_ADDRESS, Patch);
  Check('differential plan builds',
    BuildNORDifferentialPlan(Initial, Patch, PATCH_ADDRESS, Geometry,
                             Plan, Err));
  Check('no erase command is planned',
        NORPlanCountKind(Plan, npsErase) = 0);
  Check('program commands are planned',
        NORPlanCountKind(Plan, npsProgram) > 0);

  Request := MakeRequest(PATCH_ADDRESS, PATCH_LENGTH, CHIP);
  Token := TCancellationToken.Create;
  Device := TVirtualSPI25.Create(Geometry, Initial);
  Executor := TNORPlanExecutor.Create(Device);
  try
    Outcome := Executor.Execute(Request, Plan, Geometry, Token);
    Check('1->0 operation succeeds', Outcome.Status = osSucceeded);
    Check('1->0 final image is exact', Device.MemoryEquals(Expected));
  finally
    Executor.Free;
    Device.Free;
    Token.Free;
  end;

  Check('second plan builds from final contents',
    BuildNORDifferentialPlan(Expected, Patch, PATCH_ADDRESS, Geometry,
                             SecondPlan, Err));
  Check('second identical application has no destructive steps',
        not NORPlanHasDestructiveSteps(SecondPlan));
  Check('second identical application still has physical verification',
        NORPlanCountKind(SecondPlan, npsVerify) > 0);
  Check('second verification covers the complete requested range',
        NORPlanVerifyCoversRequestedRange(SecondPlan));

  Token := TCancellationToken.Create;
  Device := TVirtualSPI25.Create(Geometry, Expected);
  Executor := TNORPlanExecutor.Create(Device);
  try
    Outcome := Executor.Execute(Request, SecondPlan, Geometry, Token);
    Check('identical rerun succeeds only after verification',
          Outcome.Status = osSucceeded);
    Check('identical rerun records completed physical verification',
          Outcome.PhysicalVerifyCompleted);
    Check('identical rerun issued no mutation', Device.MutationCount = 0);
  finally
    Executor.Free;
    Device.Free;
    Token.Free;
  end;
end;

procedure TestIgnoredMutationCannotPass;
const
  CHIP = 256;
var
  Geometry: TNORGeometry;
  Initial, Patch: TBytes;
  Plan: TNORPlan;
  Request: TOperationRequest;
  Device: TVirtualSPI25;
  Executor: TNORPlanExecutor;
  Token: TCancellationToken;
  Outcome: TOperationOutcome;
  Err: string;
  i: integer;
begin
  WriteLn('Virtual protection: a silently ignored mutation fails verification');
  Check('uniform geometry created', MakeGeometry(CHIP, 16, 64, Geometry));
  SetLength(Initial, CHIP);
  for i := 0 to High(Initial) do Initial[i] := byte(i * 29);
  SetLength(Patch, 80);
  FillByte(Patch[0], Length(Patch), $FF);
  Check('plan builds',
    BuildNORDifferentialPlan(Initial, Patch, 40, Geometry, Plan, Err));

  Request := MakeRequest(40, Length(Patch), CHIP);
  Token := TCancellationToken.Create;
  Device := TVirtualSPI25.Create(Geometry, Initial);
  Device.IgnoreMutations := True;
  Executor := TNORPlanExecutor.Create(Device);
  try
    Outcome := Executor.Execute(Request, Plan, Geometry, Token);
    Check('ignored mutation is not success',
          Outcome.Status = osFailed);
    Check('ignored mutation fails at verification',
          Outcome.ErrorCode = oeVerifyMismatch);
  finally
    Executor.Free;
    Device.Free;
    Token.Free;
  end;
end;

procedure TestCancellationDrainsCurrentCommand;
const
  CHIP = 512;
var
  Geometry: TNORGeometry;
  Initial, Patch: TBytes;
  Plan: TNORPlan;
  Request: TOperationRequest;
  Device: TVirtualSPI25;
  Executor: TNORPlanExecutor;
  Token: TCancellationToken;
  Outcome: TOperationOutcome;
  Err: string;
  i: integer;
begin
  WriteLn('Cancellation: current erase drains, no later mutation starts');
  Check('uniform geometry created', MakeGeometry(CHIP, 16, 64, Geometry));
  SetLength(Initial, CHIP);
  for i := 0 to High(Initial) do Initial[i] := byte(i * 17);
  SetLength(Patch, 250);
  FillByte(Patch[0], Length(Patch), $FF);
  Check('multi-block plan builds',
    BuildNORDifferentialPlan(Initial, Patch, 20, Geometry, Plan, Err));
  Check('plan has several destructive commands',
        NORPlanCountKind(Plan, npsErase) +
        NORPlanCountKind(Plan, npsProgram) > 1);

  Request := MakeRequest(20, Length(Patch), CHIP);
  Token := TCancellationToken.Create;
  Device := TVirtualSPI25.Create(Geometry, Initial);
  Device.CancellationToken := Token;
  Device.CancelAtMutation := 1;
  Device.EraseBusyPolls := 4;
  Executor := TNORPlanExecutor.Create(Device);
  try
    Outcome := Executor.Execute(Request, Plan, Geometry, Token);
    Check('outcome is cancelled', Outcome.Status = osCancelled);
    Check('only the in-flight mutation was issued', Device.MutationCount = 1);
    Check('no mutation starts with cancellation already pending',
          Device.CallsAfterCancellationAreNonMutating);
    Check('current command was polled to idle', not Device.IsBusy);
    Check('cleanup clears WEL', not Device.WriteEnabled);
    Check('cancelled session deinitializes once',
          Device.DeinitializeCalls = 1);
    Check('cancelled session closes once', Device.CloseCalls = 1);
    Check('cancelled device state is known safe',
          Outcome.DeviceDisposition = ddKnownSafe);
  finally
    Executor.Free;
    Device.Free;
    Token.Free;
  end;
end;

procedure TestStuckBusyIsHonest;
const
  CHIP = 256;
var
  Geometry: TNORGeometry;
  Initial, Patch: TBytes;
  Plan: TNORPlan;
  Request: TOperationRequest;
  Device: TVirtualSPI25;
  Executor: TNORPlanExecutor;
  Options: TNORExecutorOptions;
  Token: TCancellationToken;
  Outcome: TOperationOutcome;
  Err: string;
begin
  WriteLn('Timeout: a stuck chip cannot be reported as safe or successful');
  Check('uniform geometry created', MakeGeometry(CHIP, 16, 64, Geometry));
  SetLength(Initial, CHIP);
  FillByte(Initial[0], Length(Initial), $00);
  SetLength(Patch, 1);
  Patch[0] := $FF;
  Check('erase-requiring plan builds',
    BuildNORDifferentialPlan(Initial, Patch, 0, Geometry, Plan, Err));

  Request := MakeRequest(0, 1, CHIP);
  Token := TCancellationToken.Create;
  Device := TVirtualSPI25.Create(Geometry, Initial);
  Device.StuckBusy := True;
  Executor := TNORPlanExecutor.Create(Device);
  Options := Executor.Options;
  Options.MaxStatusPolls := 5;
  Executor.Options := Options;
  try
    Outcome := Executor.Execute(Request, Plan, Geometry, Token);
    Check('stuck busy operation fails', Outcome.Status = osFailed);
    Check('stuck busy failure is a timeout', Outcome.ErrorCode = oeTimeout);
    Check('stuck busy state is explicitly unknown',
          Outcome.DeviceDisposition <> ddKnownSafe);
    Check('virtual chip is still physically busy', Device.IsBusy);
    Check('device close was attempted exactly once', Device.CloseCalls = 1);
  finally
    Executor.Free;
    Device.Free;
    Token.Free;
  end;
end;

procedure TestPostDeliveryExceptionDrainsCommand;
const
  CHIP = 128;
var
  Geometry: TNORGeometry;
  Initial, Patch: TBytes;
  Plan: TNORPlan;
  Request: TOperationRequest;
  Device: TRaiseAfterEraseSPI25;
  Executor: TNORPlanExecutor;
  Token: TCancellationToken;
  Outcome: TOperationOutcome;
  Err: string;
begin
  WriteLn('Exceptions: post-delivery erase ambiguity is drained to idle');
  Check('uniform geometry created', MakeGeometry(CHIP, 16, 64, Geometry));
  SetLength(Initial, CHIP);
  FillByte(Initial[0], Length(Initial), $00);
  SetLength(Patch, 1);
  Patch[0] := $FF;
  Check('erase-requiring plan builds',
    BuildNORDifferentialPlan(Initial, Patch, 0, Geometry, Plan, Err));

  Request := MakeRequest(0, 1, CHIP);
  Token := TCancellationToken.Create;
  Device := TRaiseAfterEraseSPI25.Create(Geometry, Initial);
  Executor := TNORPlanExecutor.Create(Device);
  try
    Outcome := Executor.Execute(Request, Plan, Geometry, Token);
    Check('post-delivery exception cannot become PASS',
          Outcome.Status = osFailed);
    Check('adapter exception becomes a typed transport failure',
          Outcome.ErrorCode = oeTransport);
    Check('possibly delivered erase was polled to idle', not Device.IsBusy);
    Check('no later mutation starts after the ambiguous erase',
          Device.MutationCount = 1);
    Check('exception path closes exactly once', Device.CloseCalls = 1);
  finally
    Executor.Free;
    Device.Free;
    Token.Free;
  end;
end;

procedure TestEvidenceIsPartOfSuccess;
const
  CHIP = 128;
var
  Geometry: TNORGeometry;
  Initial, Patch, Expected: TBytes;
  Plan: TNORPlan;
  Request: TOperationRequest;
  Device: TVirtualSPI25;
  Executor: TNORPlanExecutor;
  Token: TCancellationToken;
  Outcome: TOperationOutcome;
  Err: string;
begin
  WriteLn('Evidence: programmed-but-unlogged is never PASS');
  Check('uniform geometry created', MakeGeometry(CHIP, 16, 64, Geometry));
  SetLength(Initial, CHIP);
  FillByte(Initial[0], Length(Initial), $FF);
  SetLength(Patch, 2);
  Patch[0] := $12;
  Patch[1] := $34;
  CopyArray(Initial, Expected);
  Overlay(Expected, 4, Patch);
  Check('plan builds',
    BuildNORDifferentialPlan(Initial, Patch, 4, Geometry, Plan, Err));

  Request := MakeRequest(4, Length(Patch), CHIP);
  Request.Policy.RequireEvidenceCommit := True;
  Token := TCancellationToken.Create;
  Device := TVirtualSPI25.Create(Geometry, Initial);
  Executor := TNORPlanExecutor.Create(Device); // deliberately no evidence sink
  try
    Outcome := Executor.Execute(Request, Plan, Geometry, Token);
    Check('physical image was programmed', Device.MemoryEquals(Expected));
    Check('missing evidence prevents success', Outcome.Status = osFailed);
    Check('failure is typed as evidence commit',
          Outcome.ErrorCode = oeEvidenceCommitFailed);
    Check('physical device is nevertheless known idle',
          Outcome.DeviceDisposition = ddKnownSafe);
  finally
    Executor.Free;
    Device.Free;
    Token.Free;
  end;
end;

procedure TestExhaustiveFailAtN;
const
  CHIP = 256;
var
  Geometry: TNORGeometry;
  Initial, Patch: TBytes;
  Plan: TNORPlan;
  Request: TOperationRequest;
  Device: TVirtualSPI25;
  Executor: TNORPlanExecutor;
  Token: TCancellationToken;
  Outcome: TOperationOutcome;
  Err: string;
  BaselineCalls, N: cardinal;
  i: integer;
  AllFailed, CleanupOnce, StoppedAfterFailure, InjectionReached: boolean;
begin
  WriteLn('Fault matrix: every individual device call fails without false PASS');
  Check('uniform geometry created', MakeGeometry(CHIP, 16, 64, Geometry));
  SetLength(Initial, CHIP);
  for i := 0 to High(Initial) do Initial[i] := byte(i * 31 + 7);
  SetLength(Patch, 150);
  for i := 0 to High(Patch) do Patch[i] := byte(255 - i);
  Patch[0] := $FF;
  Check('fault-test plan builds',
    BuildNORDifferentialPlan(Initial, Patch, 33, Geometry, Plan, Err));
  Request := MakeRequest(33, Length(Patch), CHIP);

  Token := TCancellationToken.Create;
  Device := TVirtualSPI25.Create(Geometry, Initial);
  Executor := TNORPlanExecutor.Create(Device);
  try
    Outcome := Executor.Execute(Request, Plan, Geometry, Token);
    Check('baseline operation succeeds', Outcome.Status = osSucceeded);
    BaselineCalls := Device.CallCount;
  finally
    Executor.Free;
    Device.Free;
    Token.Free;
  end;

  Check('baseline has a meaningful call surface', BaselineCalls > 10);
  AllFailed := True;
  CleanupOnce := True;
  StoppedAfterFailure := True;
  InjectionReached := True;

  for N := 1 to BaselineCalls do
  begin
    Token := TCancellationToken.Create;
    Device := TVirtualSPI25.Create(Geometry, Initial);
    Device.FailAtCall := N;
    Executor := TNORPlanExecutor.Create(Device);
    try
      Outcome := Executor.Execute(Request, Plan, Geometry, Token);
      if Outcome.Status = osSucceeded then
      begin
        AllFailed := False;
        WriteLn('    false PASS when call ', N, ' failed');
        Break;
      end;
      if Device.CallCount < N then
      begin
        InjectionReached := False;
        WriteLn('    injection ', N, ' was not reached');
        Break;
      end;
      if (Device.CloseCalls > 1) or (Device.DeinitializeCalls > 1) then
      begin
        CleanupOnce := False;
        WriteLn('    cleanup repeated after call ', N);
        Break;
      end;
      if not NoMutationAfterCall(Device.Calls, N) then
      begin
        StoppedAfterFailure := False;
        WriteLn('    a later mutation followed failed call ', N);
        Break;
      end;
    finally
      Executor.Free;
      Device.Free;
      Token.Free;
    end;
  end;

  Check(Format('all %d injected call failures prevent PASS', [BaselineCalls]),
        AllFailed);
  Check('every numbered injection point is reachable', InjectionReached);
  Check('cleanup is attempted at most once on every path', CleanupOnce);
  Check('no destructive command starts after a failed call',
        StoppedAfterFailure);
end;

procedure TestRandomPreservationProperties;
const
  CHIP = 512;
var
  Geometry: TNORGeometry;
  Initial, Patch, Expected, FinalImage: TBytes;
  Plan, Again: TNORPlan;
  Request: TOperationRequest;
  Device: TVirtualSPI25;
  Executor: TNORPlanExecutor;
  Token: TCancellationToken;
  Outcome: TOperationOutcome;
  Err, Why: string;
  RoundNo, i, PatchLen, PatchStart: integer;
  AllOK: boolean;
begin
  WriteLn('Properties: random unaligned patches preserve the complete chip');
  Check('uniform geometry created', MakeGeometry(CHIP, 16, 64, Geometry));
  RandSeed := 20260727;
  AllOK := True;
  Why := '';

  for RoundNo := 1 to PROPERTY_ROUNDS do
  begin
    SetLength(Initial, CHIP);
    for i := 0 to High(Initial) do Initial[i] := Random(256);

    PatchLen := 1 + Random(200);
    PatchStart := Random(CHIP - PatchLen + 1);
    SetLength(Patch, PatchLen);
    for i := 0 to High(Patch) do Patch[i] := Random(256);

    CopyArray(Initial, Expected);
    Overlay(Expected, PatchStart, Patch);

    if not BuildNORDifferentialPlan(Initial, Patch, PatchStart, Geometry,
                                    Plan, Err) then
    begin
      AllOK := False;
      Why := 'planner rejected valid input: ' + Err;
      Break;
    end;
    if not ValidateNORPlan(Plan, Geometry, Err) then
    begin
      AllOK := False;
      Why := 'planner emitted an invalid step: ' + Err;
      Break;
    end;

    Request := MakeRequest(PatchStart, PatchLen, CHIP);
    Token := TCancellationToken.Create;
    Device := TVirtualSPI25.Create(Geometry, Initial);
    Executor := TNORPlanExecutor.Create(Device);
    try
      Outcome := Executor.Execute(Request, Plan, Geometry, Token);
      if Outcome.Status <> osSucceeded then
      begin
        AllOK := False;
        Why := Format('executor failed: %s (%s)',
          [Outcome.ErrorText, OperationErrorName(Outcome.ErrorCode)]);
        Break;
      end;
      FinalImage := Device.Snapshot;
      if not SameBytes(FinalImage, Expected) then
      begin
        AllOK := False;
        Why := 'final image differs from ideal byte-array overlay';
        Break;
      end;
      if Device.IsBusy or Device.WriteEnabled then
      begin
        AllOK := False;
        Why := 'successful operation left WIP or WEL set';
        Break;
      end;
    finally
      Executor.Free;
      Device.Free;
      Token.Free;
    end;

    if not BuildNORDifferentialPlan(Expected, Patch, PatchStart, Geometry,
                                    Again, Err) then
    begin
      AllOK := False;
      Why := 'idempotence plan failed to build: ' + Err;
      Break;
    end;
    if NORPlanHasDestructiveSteps(Again) then
    begin
      AllOK := False;
      Why := 'applying the same patch twice was not a no-op';
      Break;
    end;
  end;

  if not AllOK then
    WriteLn(Format('    round %d start=%d len=%d: %s',
      [RoundNo, PatchStart, PatchLen, Why]));
  Check(Format('%d deterministic random operations satisfy all invariants',
               [PROPERTY_ROUNDS]), AllOK);
end;

begin
  WriteLn('AsProgrammer preservation-aware NOR engine tests');
  WriteLn;

  TestLifecycleCancellation;
  TestPreservationPlanAndExecution;
  TestNoEraseAndIdempotence;
  TestIgnoredMutationCannotPass;
  TestCancellationDrainsCurrentCommand;
  TestStuckBusyIsHonest;
  TestPostDeliveryExceptionDrainsCommand;
  TestEvidenceIsPartOfSuccess;
  TestExhaustiveFailAtN;
  TestRandomPreservationProperties;

  WriteLn;
  WriteLn(Assertions, ' assertions, ', Failures, ' failures');
  if Failures = 0 then WriteLn('ALL PASSED');
  Halt(Failures);
end.
