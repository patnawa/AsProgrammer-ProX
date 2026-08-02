unit nandplanner;

// Bad-block-aware read/erase/program planning for SPI NAND.
//
// The planner never plans a step that touches a block the map does not say
// is good.  A block whose state is unknown is not good: the map must have
// been scanned first, and refusing to guess is the point.
//
// Two policies exist because both are legitimate and they mean opposite
// things:
//
//   nbpRefuse - the caller wants these exact bytes at these exact addresses
//               (a raw dump, a factory image with absolute offsets).  A bad
//               block anywhere in the range fails the whole request rather
//               than quietly producing something that is not what was asked
//               for.
//   nbpSkip   - the caller wants the payload written, and the chip's own
//               bad blocks are to be stepped over (how a bootloader that
//               understands skip-block layout expects to be programmed).
//
// v1 deliberately has no remapping table: skipping shifts later data to
// later blocks and that is all.  Remapping is a filesystem's job.

{$mode objfpc}{$H+}

interface

uses
  SysUtils, nandmodel;

type
  TNANDStepKind = (nskErase, nskProgram, nskRead);

  TNANDStep = record
    Kind: TNANDStepKind;
    Block: cardinal;
    Page: cardinal;      //page within the block; ignored for nskErase
    //Offset into the caller's image buffer that this step transfers.
    //Erase steps move no image bytes and carry Length = 0.
    ImageOffset: QWord;
    Length: cardinal;
  end;

  TNANDSteps = array of TNANDStep;

  TNANDPlan = record
    Steps: TNANDSteps;
    FirstBlock: cardinal;
    BlocksUsed: cardinal;    //good blocks the plan actually touches
    BlocksSkipped: cardinal; //bad blocks stepped over
    EraseCount: cardinal;
    ProgramBytes: QWord;
    ReadBytes: QWord;
  end;

procedure ClearNANDPlan(out Plan: TNANDPlan);

// Plans programming of Image starting at StartBlock.  Image is laid out per
// Geometry.Layout and is programmed page by page; every block that will be
// programmed is erased first.
function PlanNANDProgram(const Geometry: TNANDGeometry;
  const Map: TNANDBlockMap; StartBlock: cardinal; ImageBytes: QWord;
  Policy: TNANDBadBlockPolicy; out Plan: TNANDPlan;
  out ErrorText: string): boolean;

// Plans a read of ImageBytes worth of data starting at StartBlock.
function PlanNANDRead(const Geometry: TNANDGeometry;
  const Map: TNANDBlockMap; StartBlock: cardinal; ImageBytes: QWord;
  Policy: TNANDBadBlockPolicy; out Plan: TNANDPlan;
  out ErrorText: string): boolean;

//Plans erasure of BlocksToErase usable blocks beginning at StartBlock.
//nbpRefuse means those exact physical blocks must all be good; nbpSkip walks
//past known bad blocks without counting them toward BlocksToErase.
function PlanNANDErase(const Geometry: TNANDGeometry;
  const Map: TNANDBlockMap; StartBlock, BlocksToErase: cardinal;
  Policy: TNANDBadBlockPolicy; out Plan: TNANDPlan;
  out ErrorText: string): boolean;

// Every invariant the plan must satisfy, checked independently of how it was
// built, so the tests can assert on the plan rather than on the builder.
function ValidateNANDPlan(const Plan: TNANDPlan;
  const Geometry: TNANDGeometry; const Map: TNANDBlockMap;
  out ErrorText: string): boolean;

function NANDPlanCountKind(const Plan: TNANDPlan;
  Kind: TNANDStepKind): integer;

implementation

procedure ClearNANDPlan(out Plan: TNANDPlan);
begin
  Plan.Steps := nil;
  Plan.FirstBlock := 0;
  Plan.BlocksUsed := 0;
  Plan.BlocksSkipped := 0;
  Plan.EraseCount := 0;
  Plan.ProgramBytes := 0;
  Plan.ReadBytes := 0;
end;

procedure AppendStep(var Plan: TNANDPlan; var Count: SizeInt;
  Kind: TNANDStepKind; Block, Page: cardinal; ImageOffset: QWord;
  Len: cardinal);
begin
  if Count = Length(Plan.Steps) then
  begin
    if Length(Plan.Steps) = 0 then SetLength(Plan.Steps, 64)
    else SetLength(Plan.Steps, Length(Plan.Steps) * 2);
  end;
  Plan.Steps[Count].Kind := Kind;
  Plan.Steps[Count].Block := Block;
  Plan.Steps[Count].Page := Page;
  Plan.Steps[Count].ImageOffset := ImageOffset;
  Plan.Steps[Count].Length := Len;
  case Kind of
    nskErase:   Inc(Plan.EraseCount);
    nskProgram: Inc(Plan.ProgramBytes, Len);
    nskRead:    Inc(Plan.ReadBytes, Len);
  end;
  Inc(Count);
end;

//Shared walk for both directions: step across blocks honouring the policy,
//emitting per-page steps until the image is consumed.
function PlanWalk(const Geometry: TNANDGeometry; const Map: TNANDBlockMap;
  StartBlock: cardinal; ImageBytes: QWord; Policy: TNANDBadBlockPolicy;
  Programming: boolean; out Plan: TNANDPlan; out ErrorText: string): boolean;
var
  Count: SizeInt;
  Block, Page: cardinal;
  Offset, Remaining: QWord;
  Stride, Chunk: cardinal;
  FirstSet: boolean;
begin
  ClearNANDPlan(Plan);
  ErrorText := '';
  Result := False;

  if not ValidateNANDGeometry(Geometry, ErrorText) then Exit;
  if cardinal(Length(Map)) <> Geometry.BlockCount then
  begin
    ErrorText := Format('block map has %d entries, geometry declares %d',
                        [Length(Map), Geometry.BlockCount]);
    Exit;
  end;
  if StartBlock >= Geometry.BlockCount then
  begin
    ErrorText := 'the start block is past the end of the chip';
    Exit;
  end;
  if ImageBytes = 0 then Exit(True); //an empty request is a valid empty plan
  if ImageBytes > NANDImageSize(Geometry) then
  begin
    ErrorText := 'the image is larger than the whole chip';
    Exit;
  end;

  Stride := NANDImagePageStride(Geometry);
  Count := 0;
  Offset := 0;
  Remaining := ImageBytes;
  Block := StartBlock;
  FirstSet := False;

  while Remaining > 0 do
  begin
    if Block >= Geometry.BlockCount then
    begin
      ErrorText := Format(
        'the image needs more good blocks than remain from block %d',
        [StartBlock]);
      ClearNANDPlan(Plan);
      Exit;
    end;

    if not NANDBlockIsUsable(Map, Block) then
    begin
      if Policy = nbpRefuse then
      begin
        ErrorText := Format('block %d is %s and the request is exact',
          [Block, NANDBlockStateName(Map[Block])]);
        ClearNANDPlan(Plan);
        Exit;
      end;
      //nbpSkip: step over it entirely, consuming no image bytes
      Inc(Plan.BlocksSkipped);
      Inc(Block);
      Continue;
    end;

    if not FirstSet then
    begin
      Plan.FirstBlock := Block;
      FirstSet := True;
    end;
    Inc(Plan.BlocksUsed);

    //A block must be erased before any of its pages can be programmed.
    if Programming then
      AppendStep(Plan, Count, nskErase, Block, 0, 0, 0);

    Page := 0;
    while (Page < Geometry.PagesPerBlock) and (Remaining > 0) do
    begin
      if Remaining >= QWord(Stride) then Chunk := Stride
      else Chunk := cardinal(Remaining);
      if Programming then
        AppendStep(Plan, Count, nskProgram, Block, Page, Offset, Chunk)
      else
        AppendStep(Plan, Count, nskRead, Block, Page, Offset, Chunk);
      Inc(Offset, Chunk);
      Dec(Remaining, Chunk);
      Inc(Page);
    end;

    Inc(Block);
  end;

  SetLength(Plan.Steps, Count);
  Result := ValidateNANDPlan(Plan, Geometry, Map, ErrorText);
  if not Result then ClearNANDPlan(Plan);
end;

function PlanNANDProgram(const Geometry: TNANDGeometry;
  const Map: TNANDBlockMap; StartBlock: cardinal; ImageBytes: QWord;
  Policy: TNANDBadBlockPolicy; out Plan: TNANDPlan;
  out ErrorText: string): boolean;
begin
  if Geometry.Layout <> nilMainOnly then
  begin
    ClearNANDPlan(Plan);
    ErrorText := 'SPI NAND programming accepts main-area images only; ' +
      'raw images would overwrite bad-block markers and ECC bytes';
    Exit(False);
  end;
  Result := PlanWalk(Geometry, Map, StartBlock, ImageBytes, Policy, True,
                     Plan, ErrorText);
end;

function PlanNANDRead(const Geometry: TNANDGeometry;
  const Map: TNANDBlockMap; StartBlock: cardinal; ImageBytes: QWord;
  Policy: TNANDBadBlockPolicy; out Plan: TNANDPlan;
  out ErrorText: string): boolean;
begin
  Result := PlanWalk(Geometry, Map, StartBlock, ImageBytes, Policy, False,
                     Plan, ErrorText);
end;

function PlanNANDErase(const Geometry: TNANDGeometry;
  const Map: TNANDBlockMap; StartBlock, BlocksToErase: cardinal;
  Policy: TNANDBadBlockPolicy; out Plan: TNANDPlan;
  out ErrorText: string): boolean;
var
  Count: SizeInt;
  Block: cardinal;
  FirstSet: boolean;
begin
  ClearNANDPlan(Plan);
  ErrorText := '';
  Result := False;

  if not ValidateNANDGeometry(Geometry, ErrorText) then Exit;
  if cardinal(Length(Map)) <> Geometry.BlockCount then
  begin
    ErrorText := Format('block map has %d entries, geometry declares %d',
                        [Length(Map), Geometry.BlockCount]);
    Exit;
  end;
  if StartBlock >= Geometry.BlockCount then
  begin
    ErrorText := 'the start block is past the end of the chip';
    Exit;
  end;
  if BlocksToErase = 0 then Exit(True);

  Count := 0;
  Block := StartBlock;
  FirstSet := False;
  while Plan.BlocksUsed < BlocksToErase do
  begin
    if Block >= Geometry.BlockCount then
    begin
      ErrorText := Format(
        'the erase needs more good blocks than remain from block %d',
        [StartBlock]);
      ClearNANDPlan(Plan);
      Exit;
    end;

    if not NANDBlockIsUsable(Map, Block) then
    begin
      if Policy = nbpRefuse then
      begin
        ErrorText := Format('block %d is %s and the erase range is exact',
          [Block, NANDBlockStateName(Map[Block])]);
        ClearNANDPlan(Plan);
        Exit;
      end;
      Inc(Plan.BlocksSkipped);
      Inc(Block);
      Continue;
    end;

    if not FirstSet then
    begin
      Plan.FirstBlock := Block;
      FirstSet := True;
    end;
    AppendStep(Plan, Count, nskErase, Block, 0, 0, 0);
    Inc(Plan.BlocksUsed);
    Inc(Block);
  end;

  SetLength(Plan.Steps, Count);
  Result := ValidateNANDPlan(Plan, Geometry, Map, ErrorText);
  if not Result then ClearNANDPlan(Plan);
end;

function ValidateNANDPlan(const Plan: TNANDPlan;
  const Geometry: TNANDGeometry; const Map: TNANDBlockMap;
  out ErrorText: string): boolean;
var
  i: SizeInt;
  Stride: cardinal;
  ExpectedOffset: QWord;
  ErasedSoFar: array of boolean;
begin
  Result := False;
  ErrorText := '';
  Stride := NANDImagePageStride(Geometry);

  ErasedSoFar := nil;
  SetLength(ErasedSoFar, Geometry.BlockCount);
  ExpectedOffset := 0;

  for i := 0 to High(Plan.Steps) do
  begin
    if Plan.Steps[i].Block >= Geometry.BlockCount then
    begin
      ErrorText := Format('step %d addresses block %d, past the end',
                          [i, Plan.Steps[i].Block]);
      Exit;
    end;
    //The invariant that matters: never touch a block that is not good.
    if not NANDBlockIsUsable(Map, Plan.Steps[i].Block) then
    begin
      ErrorText := Format('step %d touches block %d, which is %s',
        [i, Plan.Steps[i].Block,
         NANDBlockStateName(Map[Plan.Steps[i].Block])]);
      Exit;
    end;

    case Plan.Steps[i].Kind of
      nskErase:
        begin
          if Plan.Steps[i].Length <> 0 then
          begin
            ErrorText := Format('erase step %d carries image bytes', [i]);
            Exit;
          end;
          ErasedSoFar[Plan.Steps[i].Block] := True;
        end;
      nskProgram:
        begin
          //Programming an un-erased block is how NAND images come out
          //corrupted; the plan must have erased it earlier.
          if not ErasedSoFar[Plan.Steps[i].Block] then
          begin
            ErrorText := Format(
              'step %d programs block %d before erasing it',
              [i, Plan.Steps[i].Block]);
            Exit;
          end;
        end;
      nskRead: ;
    end;

    if Plan.Steps[i].Kind in [nskProgram, nskRead] then
    begin
      if Plan.Steps[i].Page >= Geometry.PagesPerBlock then
      begin
        ErrorText := Format('step %d addresses page %d of %d',
          [i, Plan.Steps[i].Page, Geometry.PagesPerBlock]);
        Exit;
      end;
      if (Plan.Steps[i].Length = 0) or
         (Plan.Steps[i].Length > Stride) then
      begin
        ErrorText := Format('step %d transfers %d bytes; a page holds %d',
                            [i, Plan.Steps[i].Length, Stride]);
        Exit;
      end;
      //Image bytes must be consumed strictly in order with no gaps, or the
      //caller's buffer would be scattered across the chip.
      if Plan.Steps[i].ImageOffset <> ExpectedOffset then
      begin
        ErrorText := Format(
          'step %d reads image offset %d; expected %d',
          [i, Plan.Steps[i].ImageOffset, ExpectedOffset]);
        Exit;
      end;
      Inc(ExpectedOffset, Plan.Steps[i].Length);
    end;
  end;

  Result := True;
end;

function NANDPlanCountKind(const Plan: TNANDPlan;
  Kind: TNANDStepKind): integer;
var
  i: SizeInt;
begin
  Result := 0;
  for i := 0 to High(Plan.Steps) do
    if Plan.Steps[i].Kind = Kind then Inc(Result);
end;

end.
