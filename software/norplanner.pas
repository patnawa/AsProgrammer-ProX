unit norplanner;

// Preservation-aware differential planning for parallel-addressed SPI NOR.
//
// The planner receives a trusted snapshot of the whole chip and a patch for an
// arbitrary byte range.  It never assumes that bytes adjacent to the requested
// range are disposable:
//
// * If every changed bit is a legal 1 -> 0 transition, only changed runs are
//   programmed.
// * If any bit needs 0 -> 1, the containing erase block is erased, then every
//   non-erased run from the complete desired block image is programmed back.
//   That includes bytes outside the requested patch, preserving erase-block
//   neighbours.
// * Every touched block ends with a full-block verify step.
//
// The unit is pure arithmetic: no LCL, files, threads or hardware.

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

type
  TNOREraseBlock = record
    Address: QWord;
    Size: cardinal;
    Opcode: byte;
  end;

  TNOREraseBlocks = array of TNOREraseBlock;

  TNORGeometry = record
    ChipSize: QWord;
    PageSize: cardinal;
    ErasedValue: byte;
    Blocks: TNOREraseBlocks;
  end;

  TNORPlanStepKind = (
    npsErase,
    npsProgram,
    npsVerify
  );

  TNORPlanStep = record
    Kind: TNORPlanStepKind;
    Address: QWord;
    Length: cardinal;
    Opcode: byte;
    Data: TBytes;       // program payload or expected verify bytes
  end;

  TNORPlanSteps = array of TNORPlanStep;

  TNORPlan = record
    RequestedAddress: QWord;
    RequestedLength: QWord;
    AffectedAddress: QWord;
    AffectedLength: QWord;
    Steps: TNORPlanSteps;
    ChangedBytes: QWord;
    EraseBytes: QWord;
    ProgramBytes: QWord;
    VerifyBytes: QWord;
    PreservedBytesRewritten: QWord;
  end;

procedure ClearNORPlan(out Plan: TNORPlan);

function BuildUniformNORGeometry(ChipSize: QWord; PageSize, EraseSize: cardinal;
  EraseOpcode: byte; out Geometry: TNORGeometry; out ErrorText: string): boolean;

function ValidateNORGeometry(const Geometry: TNORGeometry;
  out ErrorText: string): boolean;

function BuildNORDifferentialPlan(const Current, Patch: array of byte;
  PatchAddress: QWord; const Geometry: TNORGeometry; out Plan: TNORPlan;
  out ErrorText: string): boolean;

function ValidateNORPlan(const Plan: TNORPlan; const Geometry: TNORGeometry;
  out ErrorText: string): boolean;

function NORPlanHasDestructiveSteps(const Plan: TNORPlan): boolean;
function NORPlanVerifyCoversRequestedRange(const Plan: TNORPlan): boolean;
function NORPlanDestructiveStepsVerifiedAfterward(const Plan: TNORPlan): boolean;
function NORPlanCountKind(const Plan: TNORPlan; Kind: TNORPlanStepKind): integer;
function NORPlanStepKindName(Kind: TNORPlanStepKind): string;

implementation

procedure ClearNORPlan(out Plan: TNORPlan);
begin
  Plan.RequestedAddress := 0;
  Plan.RequestedLength := 0;
  Plan.AffectedAddress := 0;
  Plan.AffectedLength := 0;
  Plan.Steps := nil;
  Plan.ChangedBytes := 0;
  Plan.EraseBytes := 0;
  Plan.ProgramBytes := 0;
  Plan.VerifyBytes := 0;
  Plan.PreservedBytesRewritten := 0;
end;

function AddQWordWouldOverflow(A, B: QWord): boolean;
begin
  Result := B > High(QWord) - A;
end;

function BuildUniformNORGeometry(ChipSize: QWord; PageSize,
  EraseSize: cardinal; EraseOpcode: byte; out Geometry: TNORGeometry;
  out ErrorText: string): boolean;
var
  Count: QWord;
  i: SizeInt;
begin
  Geometry.ChipSize := ChipSize;
  Geometry.PageSize := PageSize;
  Geometry.ErasedValue := $FF;
  Geometry.Blocks := nil;
  ErrorText := '';
  Result := False;

  if (ChipSize = 0) or (PageSize = 0) or (EraseSize = 0) then
  begin
    ErrorText := 'chip, page and erase sizes must be non-zero';
    Exit;
  end;
  if EraseOpcode = 0 then
  begin
    ErrorText := 'erase opcode must be non-zero';
    Exit;
  end;
  if (ChipSize mod EraseSize) <> 0 then
  begin
    ErrorText := 'chip size is not a multiple of erase size';
    Exit;
  end;
  if (EraseSize mod PageSize) <> 0 then
  begin
    ErrorText := 'erase size is not a multiple of page size';
    Exit;
  end;

  Count := ChipSize div EraseSize;
  if Count > QWord(High(SizeInt)) then
  begin
    ErrorText := 'erase block count does not fit this build';
    Exit;
  end;

  SetLength(Geometry.Blocks, SizeInt(Count));
  for i := 0 to High(Geometry.Blocks) do
  begin
    Geometry.Blocks[i].Address := QWord(i) * EraseSize;
    Geometry.Blocks[i].Size := EraseSize;
    Geometry.Blocks[i].Opcode := EraseOpcode;
  end;

  Result := ValidateNORGeometry(Geometry, ErrorText);
end;

function ValidateNORGeometry(const Geometry: TNORGeometry;
  out ErrorText: string): boolean;
var
  Cursor, BlockEnd: QWord;
  i: SizeInt;
begin
  Result := False;
  ErrorText := '';

  if Geometry.ChipSize = 0 then
  begin
    ErrorText := 'chip size is zero';
    Exit;
  end;
  if Geometry.ChipSize > QWord(High(SizeInt)) then
  begin
    ErrorText := 'chip snapshot does not fit this process';
    Exit;
  end;
  if Geometry.PageSize = 0 then
  begin
    ErrorText := 'page size is zero';
    Exit;
  end;
  if Length(Geometry.Blocks) = 0 then
  begin
    ErrorText := 'erase block map is empty';
    Exit;
  end;

  Cursor := 0;
  for i := 0 to High(Geometry.Blocks) do
  begin
    if Geometry.Blocks[i].Address <> Cursor then
    begin
      ErrorText := Format('erase block %d leaves a gap or overlaps', [i]);
      Exit;
    end;
    if Geometry.Blocks[i].Size = 0 then
    begin
      ErrorText := Format('erase block %d has zero size', [i]);
      Exit;
    end;
    if Geometry.Blocks[i].Opcode = 0 then
    begin
      ErrorText := Format('erase block %d has no opcode', [i]);
      Exit;
    end;
    if (Geometry.Blocks[i].Address mod Geometry.PageSize) <> 0 then
    begin
      ErrorText := Format('erase block %d is not page aligned', [i]);
      Exit;
    end;
    if (Geometry.Blocks[i].Size mod Geometry.PageSize) <> 0 then
    begin
      ErrorText := Format('erase block %d is not a whole number of pages', [i]);
      Exit;
    end;
    if AddQWordWouldOverflow(Geometry.Blocks[i].Address,
                             Geometry.Blocks[i].Size) then
    begin
      ErrorText := Format('erase block %d address overflows', [i]);
      Exit;
    end;

    BlockEnd := Geometry.Blocks[i].Address + Geometry.Blocks[i].Size;
    if BlockEnd > Geometry.ChipSize then
    begin
      ErrorText := Format('erase block %d runs past the chip', [i]);
      Exit;
    end;
    Cursor := BlockEnd;
  end;

  if Cursor <> Geometry.ChipSize then
  begin
    ErrorText := 'erase block map does not cover the whole chip';
    Exit;
  end;

  Result := True;
end;

procedure CopyBytes(const Source: array of byte; SourceOffset: QWord;
  Count: cardinal; out Dest: TBytes);
begin
  SetLength(Dest, Count);
  if Count > 0 then
    Move(Source[SizeInt(SourceOffset)], Dest[0], Count);
end;

// StepCount is the number of used entries; Plan.Steps is grown
// geometrically while building and trimmed to StepCount afterwards, so a
// full-chip plan (a million steps on a large part) does not pay a
// reallocation per step.
procedure AppendStep(var Plan: TNORPlan; var StepCount: SizeInt;
  Kind: TNORPlanStepKind; Address: QWord; Len: cardinal; Opcode: byte;
  const Data: array of byte; DataOffset: QWord);
begin
  if StepCount = Length(Plan.Steps) then
  begin
    if Length(Plan.Steps) = 0 then
      SetLength(Plan.Steps, 64)
    else
      SetLength(Plan.Steps, Length(Plan.Steps) * 2);
  end;
  Plan.Steps[StepCount].Kind := Kind;
  Plan.Steps[StepCount].Address := Address;
  Plan.Steps[StepCount].Length := Len;
  Plan.Steps[StepCount].Opcode := Opcode;
  Plan.Steps[StepCount].Data := nil;

  if Kind in [npsProgram, npsVerify] then
    CopyBytes(Data, DataOffset, Len, Plan.Steps[StepCount].Data);

  case Kind of
    npsErase:   Inc(Plan.EraseBytes, Len);
    npsProgram: Inc(Plan.ProgramBytes, Len);
    npsVerify:  Inc(Plan.VerifyBytes, Len);
  end;
  Inc(StepCount);
end;

function ByteNeedsErase(CurrentValue, DesiredValue: byte): boolean;
begin
  // NOR programming can clear bits only.  A desired 1 where the current bit is
  // 0 requires an erase before any page program can produce the desired byte.
  Result := (CurrentValue and DesiredValue) <> DesiredValue;
end;

procedure AppendProgramRuns(var Plan: TNORPlan; var StepCount: SizeInt;
  const Current, Desired: array of byte; FromAddress, ToAddress: QWord;
  const Geometry: TNORGeometry; AfterErase: boolean);
var
  PageEnd, At, RunStart: QWord;
  Need: boolean;
begin
  At := FromAddress;
  while At < ToAddress do
  begin
    PageEnd := ((At div Geometry.PageSize) + 1) * Geometry.PageSize;
    if PageEnd > ToAddress then PageEnd := ToAddress;

    while At < PageEnd do
    begin
      if AfterErase then
        Need := Desired[SizeInt(At)] <> Geometry.ErasedValue
      else
        Need := Desired[SizeInt(At)] <> Current[SizeInt(At)];

      if not Need then
      begin
        Inc(At);
        Continue;
      end;

      RunStart := At;
      repeat
        Inc(At);
        if At >= PageEnd then Break;
        if AfterErase then
          Need := Desired[SizeInt(At)] <> Geometry.ErasedValue
        else
          Need := Desired[SizeInt(At)] <> Current[SizeInt(At)];
      until not Need;

      AppendStep(Plan, StepCount, npsProgram, RunStart,
                 cardinal(At - RunStart), 0, Desired, RunStart);
    end;
  end;
end;

function BuildNORDifferentialPlan(const Current, Patch: array of byte;
  PatchAddress: QWord; const Geometry: TNORGeometry; out Plan: TNORPlan;
  out ErrorText: string): boolean;
var
  Desired: TBytes;
  PatchEnd, BlockStart, BlockEnd, At: QWord;
  FirstAffected, LastAffectedEnd: QWord;
  i, StepCount: SizeInt;
  Different, NeedsErase, InPatch: boolean;
begin
  ClearNORPlan(Plan);
  ErrorText := '';
  Result := False;

  if not ValidateNORGeometry(Geometry, ErrorText) then Exit;
  if QWord(Length(Current)) <> Geometry.ChipSize then
  begin
    ErrorText := Format('snapshot has %d bytes, chip geometry has %d',
                        [Length(Current), Geometry.ChipSize]);
    Exit;
  end;
  if PatchAddress > Geometry.ChipSize then
  begin
    ErrorText := 'patch starts past the end of the chip';
    Exit;
  end;
  if QWord(Length(Patch)) > Geometry.ChipSize - PatchAddress then
  begin
    ErrorText := 'patch runs past the end of the chip';
    Exit;
  end;

  Plan.RequestedAddress := PatchAddress;
  Plan.RequestedLength := Length(Patch);
  if Length(Patch) = 0 then Exit(True);
  PatchEnd := PatchAddress + QWord(Length(Patch));

  SetLength(Desired, Length(Current));
  if Length(Current) > 0 then Move(Current[0], Desired[0], Length(Current));
  Move(Patch[0], Desired[SizeInt(PatchAddress)], Length(Patch));

  FirstAffected := High(QWord);
  LastAffectedEnd := 0;
  StepCount := 0;

  for i := 0 to High(Geometry.Blocks) do
  begin
    BlockStart := Geometry.Blocks[i].Address;
    BlockEnd := BlockStart + Geometry.Blocks[i].Size;

    if (BlockEnd <= PatchAddress) or (BlockStart >= PatchEnd) then Continue;

    Different := False;
    NeedsErase := False;
    At := BlockStart;
    while At < BlockEnd do
    begin
      if Current[SizeInt(At)] <> Desired[SizeInt(At)] then
      begin
        Different := True;
        Inc(Plan.ChangedBytes);
        if ByteNeedsErase(Current[SizeInt(At)], Desired[SizeInt(At)]) then
          NeedsErase := True;
      end;
      Inc(At);
    end;

    if FirstAffected = High(QWord) then FirstAffected := BlockStart;
    LastAffectedEnd := BlockEnd;

    //A full-verify request must still perform physical I/O when the desired
    //image already matches the trusted snapshot.  Verifying every physical
    //block intersecting the requested range also detects a same-model chip
    //swap between the snapshot and execution sessions.
    if not Different then
    begin
      AppendStep(Plan, StepCount, npsVerify, BlockStart,
                 Geometry.Blocks[i].Size, 0, Desired, BlockStart);
      Continue;
    end;

    if NeedsErase then
    begin
      AppendStep(Plan, StepCount, npsErase, BlockStart,
                 Geometry.Blocks[i].Size, Geometry.Blocks[i].Opcode,
                 Desired, 0);

      // Count bytes outside the user's patch that an erase would destroy and
      // that therefore have to be written back from the trusted snapshot.
      At := BlockStart;
      while At < BlockEnd do
      begin
        InPatch := (At >= PatchAddress) and (At < PatchEnd);
        if (not InPatch) and
           (Desired[SizeInt(At)] <> Geometry.ErasedValue) then
          Inc(Plan.PreservedBytesRewritten);
        Inc(At);
      end;

      AppendProgramRuns(Plan, StepCount, Current, Desired, BlockStart,
                        BlockEnd, Geometry, True);
    end
    else
      AppendProgramRuns(Plan, StepCount, Current, Desired, BlockStart,
                        BlockEnd, Geometry, False);

    // Verify the complete physical erase block, not only the requested bytes.
    // This proves that preservation of neighbouring bytes really happened.
    AppendStep(Plan, StepCount, npsVerify, BlockStart,
               Geometry.Blocks[i].Size, 0, Desired, BlockStart);
  end;

  // Trim the geometric growth: every consumer takes Length(Plan.Steps) as
  // the step count.
  SetLength(Plan.Steps, StepCount);

  if FirstAffected <> High(QWord) then
  begin
    Plan.AffectedAddress := FirstAffected;
    Plan.AffectedLength := LastAffectedEnd - FirstAffected;
  end;

  Result := ValidateNORPlan(Plan, Geometry, ErrorText);
end;

function FindExactBlock(const Geometry: TNORGeometry; Address: QWord;
  Len: cardinal; Opcode: byte): boolean;
var
  i: SizeInt;
begin
  Result := False;
  for i := 0 to High(Geometry.Blocks) do
    if (Geometry.Blocks[i].Address = Address) and
       (Geometry.Blocks[i].Size = Len) and
       (Geometry.Blocks[i].Opcode = Opcode) then
      Exit(True);
end;

function ValidateNORPlan(const Plan: TNORPlan; const Geometry: TNORGeometry;
  out ErrorText: string): boolean;
var
  i: SizeInt;
  S: TNORPlanStep;
  StepEnd, FirstPage, LastPage: QWord;
begin
  Result := False;
  ErrorText := '';
  if not ValidateNORGeometry(Geometry, ErrorText) then Exit;

  if Plan.RequestedAddress > Geometry.ChipSize then
  begin
    ErrorText := 'requested range starts past the chip';
    Exit;
  end;
  if Plan.RequestedLength > Geometry.ChipSize - Plan.RequestedAddress then
  begin
    ErrorText := 'requested range runs past the chip';
    Exit;
  end;

  for i := 0 to High(Plan.Steps) do
  begin
    S := Plan.Steps[i];
    if S.Length = 0 then
    begin
      ErrorText := Format('step %d has zero length', [i]);
      Exit;
    end;
    if AddQWordWouldOverflow(S.Address, S.Length) then
    begin
      ErrorText := Format('step %d address overflows', [i]);
      Exit;
    end;
    StepEnd := S.Address + S.Length;
    if StepEnd > Geometry.ChipSize then
    begin
      ErrorText := Format('step %d runs past the chip', [i]);
      Exit;
    end;

    case S.Kind of
      npsErase:
        begin
          if Length(S.Data) <> 0 then
          begin
            ErrorText := Format('erase step %d unexpectedly has data', [i]);
            Exit;
          end;
          if not FindExactBlock(Geometry, S.Address, S.Length, S.Opcode) then
          begin
            ErrorText := Format('erase step %d is not a declared block', [i]);
            Exit;
          end;
        end;

      npsProgram:
        begin
          if Length(S.Data) <> S.Length then
          begin
            ErrorText := Format('program step %d payload length differs', [i]);
            Exit;
          end;
          FirstPage := S.Address div Geometry.PageSize;
          LastPage := (StepEnd - 1) div Geometry.PageSize;
          if FirstPage <> LastPage then
          begin
            ErrorText := Format('program step %d crosses a page', [i]);
            Exit;
          end;
        end;

      npsVerify:
        if Length(S.Data) <> S.Length then
        begin
          ErrorText := Format('verify step %d expected-data length differs', [i]);
          Exit;
        end;
    end;
  end;

  Result := True;
end;

function NORPlanHasDestructiveSteps(const Plan: TNORPlan): boolean;
var
  i: SizeInt;
begin
  Result := False;
  for i := 0 to High(Plan.Steps) do
    if Plan.Steps[i].Kind in [npsErase, npsProgram] then Exit(True);
end;

function NORPlanVerifyCoversRequestedRange(const Plan: TNORPlan): boolean;
var
  Starts, Ends: array of QWord;
  Cursor, RequestedEnd, Furthest: QWord;
  i, Count, Next: SizeInt;

  // Plain in-place quicksort over the (start, end) pairs by start address.
  // A full-chip plan on a large part has hundreds of thousands of verify
  // steps; the previous rescan-per-advance was O(blocks x steps).
  procedure Sort(L, R: SizeInt);
  var
    Lo, Hi: SizeInt;
    PivotStart, TmpQ: QWord;
  begin
    while L < R do
    begin
      Lo := L;
      Hi := R;
      PivotStart := Starts[(L + R) div 2];
      repeat
        while Starts[Lo] < PivotStart do Inc(Lo);
        while Starts[Hi] > PivotStart do Dec(Hi);
        if Lo <= Hi then
        begin
          TmpQ := Starts[Lo]; Starts[Lo] := Starts[Hi]; Starts[Hi] := TmpQ;
          TmpQ := Ends[Lo]; Ends[Lo] := Ends[Hi]; Ends[Hi] := TmpQ;
          Inc(Lo);
          Dec(Hi);
        end;
      until Lo > Hi;
      if Hi - L < R - Lo then
      begin
        if L < Hi then Sort(L, Hi);
        L := Lo;
      end
      else
      begin
        if Lo < R then Sort(Lo, R);
        R := Hi;
      end;
    end;
  end;

begin
  if Plan.RequestedLength = 0 then Exit(True);
  if AddQWordWouldOverflow(Plan.RequestedAddress,
                           Plan.RequestedLength) then Exit(False);
  Cursor := Plan.RequestedAddress;
  RequestedEnd := Cursor + Plan.RequestedLength;

  Count := 0;
  SetLength(Starts, Length(Plan.Steps));
  SetLength(Ends, Length(Plan.Steps));
  for i := 0 to High(Plan.Steps) do
    if (Plan.Steps[i].Kind = npsVerify) and
       (not AddQWordWouldOverflow(Plan.Steps[i].Address,
                                  Plan.Steps[i].Length)) then
    begin
      Starts[Count] := Plan.Steps[i].Address;
      Ends[Count] := Plan.Steps[i].Address + Plan.Steps[i].Length;
      Inc(Count);
    end;
  if Count = 0 then Exit(False);
  Sort(0, Count - 1);

  Next := 0;
  while Cursor < RequestedEnd do
  begin
    Furthest := Cursor;
    while (Next < Count) and (Starts[Next] <= Cursor) do
    begin
      if Ends[Next] > Furthest then Furthest := Ends[Next];
      Inc(Next);
    end;
    if Furthest = Cursor then Exit(False);
    Cursor := Furthest;
  end;
  Result := True;
end;

function NORPlanDestructiveStepsVerifiedAfterward(const Plan: TNORPlan): boolean;
var
  i, j: SizeInt;
  DestructiveEnd, VerifyEnd: QWord;
  Found: boolean;
begin
  for i := 0 to High(Plan.Steps) do
    if Plan.Steps[i].Kind in [npsErase, npsProgram] then
    begin
      if AddQWordWouldOverflow(Plan.Steps[i].Address,
                               Plan.Steps[i].Length) then Exit(False);
      DestructiveEnd := Plan.Steps[i].Address + Plan.Steps[i].Length;
      Found := False;
      for j := i + 1 to High(Plan.Steps) do
        if (Plan.Steps[j].Kind = npsVerify) and
           (Plan.Steps[j].Address <= Plan.Steps[i].Address) and
           (not AddQWordWouldOverflow(Plan.Steps[j].Address,
                                      Plan.Steps[j].Length)) then
        begin
          VerifyEnd := Plan.Steps[j].Address + Plan.Steps[j].Length;
          if VerifyEnd >= DestructiveEnd then
          begin
            Found := True;
            Break;
          end;
        end;
      if not Found then Exit(False);
    end;
  Result := True;
end;

function NORPlanCountKind(const Plan: TNORPlan;
  Kind: TNORPlanStepKind): integer;
var
  i: SizeInt;
begin
  Result := 0;
  for i := 0 to High(Plan.Steps) do
    if Plan.Steps[i].Kind = Kind then Inc(Result);
end;

function NORPlanStepKindName(Kind: TNORPlanStepKind): string;
begin
  case Kind of
    npsErase:   Result := 'erase';
    npsProgram: Result := 'program';
    npsVerify:  Result := 'verify';
  else
    Result := 'unknown';
  end;
end;

end.
