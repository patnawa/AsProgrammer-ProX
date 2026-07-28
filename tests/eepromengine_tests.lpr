program eepromengine_tests;

// Tests for the differential EEPROM planner and executor, driven entirely
// through the in-memory virtual chip.  No hardware, no LCL.

{$mode objfpc}{$H+}

uses
  SysUtils, operationmodel, eepromengine, virtualeeprom;

var
  ChecksRun: integer = 0;
  ChecksFailed: integer = 0;

procedure Check(Condition: boolean; const Name: string;
  const Detail: string = '');
begin
  Inc(ChecksRun);
  if Condition then Exit;
  Inc(ChecksFailed);
  if Detail = '' then
    WriteLn('FAIL: ', Name)
  else
    WriteLn('FAIL: ', Name, ' -- ', Detail);
end;

function MakeRequest(const ID: string): TOperationRequest;
begin
  InitOperationRequest(Result);
  Result.OperationID := ID;
  Result.Kind := okProgram;
  // These tests exercise the physical engine; the evidence channel has its
  // own coverage in stage9tests.
  Result.Policy.RequireEvidenceCommit := False;
end;

function BytesOf(const S: RawByteString): TBytes;
begin
  Result := nil;
  SetLength(Result, Length(S));
  if Length(S) > 0 then Move(S[1], Result[0], Length(S));
end;

function SameBytes(const A, B: TBytes): boolean;
var
  i: SizeInt;
begin
  if Length(A) <> Length(B) then Exit(False);
  for i := 0 to High(A) do
    if A[i] <> B[i] then Exit(False);
  Result := True;
end;

function OverlaidCopy(const Base: TBytes; const Patch: TBytes;
  At: QWord): TBytes;
begin
  Result := nil;
  SetLength(Result, Length(Base));
  if Length(Base) > 0 then Move(Base[0], Result[0], Length(Base));
  if Length(Patch) > 0 then Move(Patch[0], Result[SizeInt(At)], Length(Patch));
end;

function DifferingPages(const Current, Desired: TBytes;
  PageSize: cardinal): integer;
var
  PageAt: QWord;
  i: cardinal;
  Diff: boolean;
begin
  Result := 0;
  PageAt := 0;
  while PageAt < QWord(Length(Current)) do
  begin
    Diff := False;
    for i := 0 to PageSize - 1 do
      if Current[SizeInt(PageAt) + SizeInt(i)] <>
         Desired[SizeInt(PageAt) + SizeInt(i)] then
      begin
        Diff := True;
        Break;
      end;
    if Diff then Inc(Result);
    Inc(PageAt, PageSize);
  end;
end;

procedure TestPlanner;
var
  Current, Patch: TBytes;
  Plan: TEEPROMPlan;
  Err: string;
begin
  WriteLn('Planner: page-differential plans');

  // 4 pages of 8 bytes, all FF
  Current := nil;
  SetLength(Current, 32);
  FillChar(Current[0], 32, $FF);

  // empty patch: valid empty plan
  Patch := nil;
  Check(BuildEEPROMDifferentialPlan(Current, Patch, 0, 8, Plan, Err) and
        (Length(Plan.Steps) = 0),
        'an empty patch plans no steps', Err);

  // one changed byte in page 1: one write, one verify, both page-aligned
  Patch := BytesOf(#$00);
  Check(BuildEEPROMDifferentialPlan(Current, Patch, 9, 8, Plan, Err),
        'a one-byte patch plans', Err);
  Check((EEPROMPlanCountKind(Plan, epsWrite) = 1) and
        (EEPROMPlanCountKind(Plan, epsVerify) = 1) and
        (Plan.Steps[0].Address = 8) and (Plan.Steps[0].Length = 8),
        'a one-byte change writes exactly its containing page');
  Check(Plan.ChangedBytes = 1, 'changed bytes are counted exactly');

  // a patch identical to the chip: no writes, but the pages still verify
  Patch := BytesOf(#$FF#$FF#$FF);
  Check(BuildEEPROMDifferentialPlan(Current, Patch, 14, 8, Plan, Err) and
        (EEPROMPlanCountKind(Plan, epsWrite) = 0) and
        (EEPROMPlanCountKind(Plan, epsVerify) = 2),
        'an already-matching patch still verifies its pages', Err);

  // spanning three pages with the middle page already matching
  SetLength(Patch, 17);
  FillChar(Patch[0], 17, $FF);
  Patch[0] := $11;              // page 0 differs
  Patch[16] := $22;             // page 2 differs
  Check(BuildEEPROMDifferentialPlan(Current, Patch, 0, 8, Plan, Err) and
        (EEPROMPlanCountKind(Plan, epsWrite) = 2) and
        (EEPROMPlanCountKind(Plan, epsVerify) = 3),
        'only differing pages are written; every touched page verifies', Err);

  // geometry rejections
  Check(not BuildEEPROMDifferentialPlan(Current, Patch, 0, 0, Plan, Err),
        'page size zero is rejected');
  Check(not BuildEEPROMDifferentialPlan(Current, Patch, 0, 7, Plan, Err),
        'a chip that is not whole pages is rejected');
  Check(not BuildEEPROMDifferentialPlan(Current, Patch, 30, 8, Plan, Err),
        'a patch past the end of the chip is rejected');
end;

procedure TestExecutorHappyPath;
var
  Chip: TVirtualEEPROM;
  Executor: TEEPROMPlanExecutor;
  Current, Patch, Desired: TBytes;
  Plan: TEEPROMPlan;
  Outcome: TOperationOutcome;
  Err: string;
begin
  WriteLn('Executor: differential write round trip');

  Current := nil;
  SetLength(Current, 64);
  FillChar(Current[0], 64, $AA);

  Patch := BytesOf(#$01#$02#$03#$04#$05);
  Desired := OverlaidCopy(Current, Patch, 30);

  Check(BuildEEPROMDifferentialPlan(Current, Patch, 30, 16, Plan, Err),
        'round-trip plan builds', Err);

  Chip := TVirtualEEPROM.Create(64, 16, $AA);
  Executor := TEEPROMPlanExecutor.Create(Chip);
  try
    Outcome := Executor.Execute(MakeRequest('rt-1'), Plan, 64, nil);
    Check(Outcome.Status = osSucceeded, 'round trip succeeds',
          Outcome.ErrorText);
    Check(SameBytes(Chip.Memory, Desired),
          'the chip holds exactly snapshot overlaid with patch');
    Check(Chip.WritePagesDone = DifferingPages(Current, Desired, 16),
          'page writes equal the number of differing pages');
    Check(Outcome.PhysicalVerifyCompleted,
          'physical verification is reported completed');
    Check((Chip.OpenCount = 1) and (Chip.InitCount = 1) and
          (Chip.DeinitCount = 1) and (Chip.CloseCount = 1),
          'open/init/deinit/close each happen exactly once');
    Check(Outcome.BytesCompleted = Plan.WriteBytes + Plan.VerifyBytes,
          'progress is byte-denominated and complete');
  finally
    Executor.Free;
    Chip.Free;
  end;
end;

procedure TestVerifyCatchesBadChip;
var
  Chip: TVirtualEEPROM;
  Executor: TEEPROMPlanExecutor;
  Current, Patch: TBytes;
  Plan: TEEPROMPlan;
  Outcome: TOperationOutcome;
  Err: string;
begin
  WriteLn('Executor: verification and short transfers fail closed');

  Current := nil;
  SetLength(Current, 32);
  FillChar(Current[0], 32, $FF);
  Patch := BytesOf(#$5A);

  Check(BuildEEPROMDifferentialPlan(Current, Patch, 4, 8, Plan, Err),
        'bad-chip fixture plan builds', Err);

  // A chip that corrupts every written page must be caught by verify.
  Chip := TVirtualEEPROM.Create(32, 8, $FF);
  Chip.CorruptWrites := True;
  Executor := TEEPROMPlanExecutor.Create(Chip);
  try
    Outcome := Executor.Execute(MakeRequest('bad-1'), Plan, 32, nil);
    Check((Outcome.Status = osFailed) and
          (Outcome.ErrorCode = oeVerifyMismatch),
          'a chip that will not take the data fails verification');
    // CorruptWrites flips byte 0 of the written page, and the patch at
    // address 4 rewrites its whole containing page, so the first byte that
    // disagrees is the page base.
    Check(Outcome.HasFailureAddress and (Outcome.FailureAddress = 0),
          'the verify mismatch names the exact failing address');
    Check(not Outcome.PhysicalVerifyCompleted,
          'a failed run never claims completed verification');
  finally
    Executor.Free;
    Chip.Free;
  end;

  // A short verify read is a typed failure, never a comparison of garbage.
  Chip := TVirtualEEPROM.Create(32, 8, $FF);
  Chip.ShortReadBy := 1;
  Executor := TEEPROMPlanExecutor.Create(Chip);
  try
    Outcome := Executor.Execute(MakeRequest('bad-2'), Plan, 32, nil);
    Check((Outcome.Status = osFailed) and
          (Outcome.ErrorCode = oeShortTransfer),
          'a short verify read fails closed');
  finally
    Executor.Free;
    Chip.Free;
  end;
end;

procedure TestCancellation;
var
  Chip: TVirtualEEPROM;
  Executor: TEEPROMPlanExecutor;
  Token: TCancellationToken;
  Current, Patch: TBytes;
  Plan: TEEPROMPlan;
  Outcome: TOperationOutcome;
  Err: string;
  i: SizeInt;
begin
  WriteLn('Executor: cancellation boundaries');

  Current := nil;
  SetLength(Current, 64);
  FillChar(Current[0], 64, $FF);
  Patch := nil;
  SetLength(Patch, 64);
  for i := 0 to High(Patch) do Patch[i] := byte(i);

  Check(BuildEEPROMDifferentialPlan(Current, Patch, 0, 16, Plan, Err),
        'cancellation fixture plan builds', Err);

  // Cancelled before the run starts: nothing is written.
  Chip := TVirtualEEPROM.Create(64, 16, $FF);
  Token := TCancellationToken.Create;
  Token.RequestCancellation;
  Executor := TEEPROMPlanExecutor.Create(Chip);
  try
    Outcome := Executor.Execute(MakeRequest('cancel-1'), Plan, 64, Token);
    Check((Outcome.Status = osCancelled) and (Chip.WritePagesDone = 0),
          'cancelling before the run writes nothing');
    Check((Chip.DeinitCount = 1) and (Chip.CloseCount = 1),
          'a cancelled run still cleans up exactly once');
  finally
    Executor.Free;
    Chip.Free;
    Token.Free;
  end;

  // Cancelled from inside write 2: the settled page counts, and no further
  // page is started.
  Chip := TVirtualEEPROM.Create(64, 16, $FF);
  Token := TCancellationToken.Create;
  Chip.CancelToken := Token;
  Chip.CancelInWriteNumber := 2;
  Executor := TEEPROMPlanExecutor.Create(Chip);
  try
    Outcome := Executor.Execute(MakeRequest('cancel-2'), Plan, 64, Token);
    Check((Outcome.Status = osCancelled) and (Chip.WritePagesDone = 2),
          'cancelling mid-run stops after the in-flight page settles');
    Check((Chip.DeinitCount = 1) and (Chip.CloseCount = 1),
          'a mid-run cancel still cleans up exactly once');
  finally
    Executor.Free;
    Chip.Free;
    Token.Free;
  end;
end;

procedure TestFaultMatrix;
var
  Chip: TVirtualEEPROM;
  Executor: TEEPROMPlanExecutor;
  Current, Patch, Desired: TBytes;
  Plan: TEEPROMPlan;
  Outcome: TOperationOutcome;
  Err: string;
  Calls, At: cardinal;
  AllClosed: boolean;
begin
  WriteLn('Executor: every device call can fail without a false PASS');

  Current := nil;
  SetLength(Current, 48);
  FillChar(Current[0], 48, $FF);
  Patch := BytesOf(#$10#$20#$30#$40#$50#$60#$70#$80#$90);
  Desired := OverlaidCopy(Current, Patch, 12);

  Check(BuildEEPROMDifferentialPlan(Current, Patch, 12, 8, Plan, Err),
        'fault-matrix plan builds', Err);
  Calls := TVirtualEEPROM.CallsForPlan(Plan);

  AllClosed := True;
  for At := 1 to Calls do
  begin
    Chip := TVirtualEEPROM.Create(48, 8, $FF);
    Chip.FailAtCall := At;
    Executor := TEEPROMPlanExecutor.Create(Chip);
    try
      Outcome := Executor.Execute(MakeRequest('fault-' + IntToStr(At)),
                                  Plan, 48, nil);
      if Outcome.Status = osSucceeded then
      begin
        AllClosed := False;
        WriteLn('  false PASS with failure injected at call ', At);
      end;
      if Outcome.ErrorCode = oeNone then
      begin
        AllClosed := False;
        WriteLn('  untyped failure at call ', At);
      end;
      // A failure injected into cleanup (the calls after the plan steps)
      // comes after verification genuinely finished; claiming completed
      // verification there is the truth, not a defect.
      if Outcome.PhysicalVerifyCompleted and
         (At <= 2 + cardinal(Length(Plan.Steps))) then
      begin
        AllClosed := False;
        WriteLn('  failed run claims completed verification at call ', At);
      end;
    finally
      Executor.Free;
      Chip.Free;
    end;
  end;
  Check(AllClosed,
        Format('all %d injection points fail closed and typed', [Calls]));
end;

procedure TestRandomisedInvariants;
const
  ROUNDS = 400;
  PAGE_CHOICES: array[0..4] of cardinal = (8, 16, 32, 64, 128);
var
  Round: integer;
  PageSize, Pages, ChipSize: cardinal;
  Current, Patch, Desired: TBytes;
  PatchAt: QWord;
  Plan: TEEPROMPlan;
  Outcome: TOperationOutcome;
  Err: string;
  Chip: TVirtualEEPROM;
  Executor: TEEPROMPlanExecutor;
  i: SizeInt;
  OK: boolean;
begin
  WriteLn('Randomised: ', ROUNDS,
          ' snapshot/patch pairs keep every invariant');

  RandSeed := 900418; // deterministic: a failure here must reproduce
  OK := True;

  for Round := 1 to ROUNDS do
  begin
    PageSize := PAGE_CHOICES[Random(Length(PAGE_CHOICES))];
    Pages := 1 + cardinal(Random(24));
    ChipSize := Pages * PageSize;

    Current := nil;
    SetLength(Current, ChipSize);
    for i := 0 to High(Current) do Current[i] := byte(Random(256));

    Patch := nil;
    SetLength(Patch, Random(SizeInt(ChipSize)) + 1);
    PatchAt := QWord(Random(SizeInt(ChipSize - QWord(Length(Patch)) + 1)));
    for i := 0 to High(Patch) do
      // Bias towards matching bytes so unchanged pages actually occur.
      if Random(3) = 0 then
        Patch[i] := byte(Random(256))
      else
        Patch[i] := Current[SizeInt(PatchAt) + i];

    Desired := OverlaidCopy(Current, Patch, PatchAt);

    if not BuildEEPROMDifferentialPlan(Current, Patch, PatchAt, PageSize,
                                       Plan, Err) then
    begin
      OK := False;
      WriteLn('  round ', Round, ': plan refused: ', Err);
      Break;
    end;

    Chip := TVirtualEEPROM.Create(ChipSize, PageSize, 0);
    Move(Current[0], Chip.Memory[0], ChipSize);
    Executor := TEEPROMPlanExecutor.Create(Chip);
    try
      Outcome := Executor.Execute(MakeRequest('rand-' + IntToStr(Round)),
                                  Plan, ChipSize, nil);
      if Outcome.Status <> osSucceeded then
      begin
        OK := False;
        WriteLn('  round ', Round, ': run failed: ', Outcome.ErrorText);
        Break;
      end;
      if not SameBytes(Chip.Memory, Desired) then
      begin
        OK := False;
        WriteLn('  round ', Round, ': chip does not match desired image');
        Break;
      end;
      if Chip.WritePagesDone <> DifferingPages(Current, Desired,
                                               PageSize) then
      begin
        OK := False;
        WriteLn('  round ', Round, ': wrote ', Chip.WritePagesDone,
                ' pages; ', DifferingPages(Current, Desired, PageSize),
                ' differ');
        Break;
      end;
    finally
      Executor.Free;
      Chip.Free;
    end;
  end;

  Check(OK, 'randomised differential rounds hold every invariant');
end;

begin
  TestPlanner;
  TestExecutorHappyPath;
  TestVerifyCatchesBadChip;
  TestCancellation;
  TestFaultMatrix;
  TestRandomisedInvariants;

  if ChecksFailed = 0 then
  begin
    WriteLn('PASS: ', ChecksRun, ' EEPROM engine checks');
    ExitCode := 0;
  end
  else
  begin
    WriteLn('FAIL: ', ChecksFailed, ' of ', ChecksRun, ' checks failed');
    ExitCode := 1;
  end;
end.
