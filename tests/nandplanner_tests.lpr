program nandplanner_tests;

// Tests for the SPI NAND geometry model and the bad-block-aware planner.
// No hardware: the whole point is that the dangerous arithmetic is reachable
// from a test runner.

{$mode objfpc}{$H+}

uses
  SysUtils, nandmodel, nandplanner;

var
  ChecksRun: integer = 0;
  ChecksFailed: integer = 0;

procedure Check(Condition: boolean; const Name: string;
  const Detail: string = '');
begin
  Inc(ChecksRun);
  if Condition then Exit;
  Inc(ChecksFailed);
  if Detail = '' then WriteLn('FAIL: ', Name)
  else WriteLn('FAIL: ', Name, ' -- ', Detail);
end;

//A typical small SPI NAND: 2048-byte pages, 64-byte spare, 64 pages/block.
function Geo(Layout: TNANDImageLayout; Blocks: cardinal = 16): TNANDGeometry;
var
  Err: string;
begin
  if not BuildNANDGeometry(2048, 64, 64, Blocks, Layout, Result, Err) then
    WriteLn('fixture geometry refused: ', Err);
end;

function AllGood(const G: TNANDGeometry): TNANDBlockMap;
var
  i: SizeInt;
begin
  Result := NewNANDBlockMap(G);
  for i := 0 to High(Result) do Result[i] := nbsGood;
end;

procedure TestGeometry;
var
  G: TNANDGeometry;
  Err: string;
begin
  WriteLn('Geometry: layout arithmetic and rejection of impossible parts');

  G := Geo(nilMainOnly);
  Check(NANDImagePageStride(G) = 2048, 'main-only page stride excludes spare');
  Check(NANDImageBlockStride(G) = 2048 * 64, 'main-only block stride');
  Check(NANDMainSize(G) = QWord(2048) * 64 * 16, 'main size ignores spare');

  G := Geo(nilRaw);
  Check(NANDImagePageStride(G) = 2048 + 64, 'raw page stride includes spare');
  Check(NANDImageSize(G) = QWord(2048 + 64) * 64 * 16, 'raw image size');
  Check(NANDMainSize(G) = QWord(2048) * 64 * 16,
        'main size is the same whatever the layout');

  Check(not BuildNANDGeometry(2000, 64, 64, 16, nilRaw, G, Err),
        'a non-power-of-two page size is refused');
  Check(not BuildNANDGeometry(2048, 8, 64, 16, nilRaw, G, Err),
        'a spare area too small for a marker is refused');
  Check(not BuildNANDGeometry(2048, 64, 63, 16, nilRaw, G, Err),
        'a non-power-of-two block size is refused');
  Check(not BuildNANDGeometry(2048, 64, 64, 0, nilRaw, G, Err),
        'a chip with no blocks is refused');

  //Address mapping
  G := Geo(nilMainOnly);
  Check(NANDBlockOfMainAddress(G, 0) = 0, 'address 0 is in block 0');
  Check(NANDBlockOfMainAddress(G, QWord(2048) * 64 - 1) = 0,
        'the last byte of block 0 is still block 0');
  Check(NANDBlockOfMainAddress(G, QWord(2048) * 64) = 1,
        'the next byte starts block 1');
end;

procedure TestBlockMap;
var
  G: TNANDGeometry;
  Map: TNANDBlockMap;
begin
  WriteLn('Block map: unknown is not good');

  G := Geo(nilRaw);
  Map := NewNANDBlockMap(G);
  Check(Length(Map) = 16, 'a fresh map has one entry per block');
  Check(Map[0] = nbsUnknown, 'a fresh map is unknown, not good');
  Check(not NANDBlockIsUsable(Map, 0),
        'an unscanned block is never usable');
  Check(NANDCountUsable(Map) = 0, 'an unscanned map has no usable blocks');

  Map[0] := nbsGood;
  Check(NANDBlockIsUsable(Map, 0), 'a good block is usable');
  Check(not NANDBlockIsUsable(Map, 99),
        'a block index past the end is never usable');

  Check(NANDMarkerState($FF) = nbsGood, 'FF marks a good block');
  Check(NANDMarkerState($00) = nbsFactoryBad, '00 marks a bad block');
  Check(NANDMarkerState($F0) = nbsFactoryBad,
        'any non-FF marker means bad, not just 00');
end;

procedure TestPlanHappyPath;
var
  G: TNANDGeometry;
  Map: TNANDBlockMap;
  Plan: TNANDPlan;
  Err: string;
  Bytes: QWord;
begin
  WriteLn('Planning: the ordinary case');

  G := Geo(nilRaw);
  Map := AllGood(G);
  Check(not PlanNANDProgram(G, Map, 0, G.PageSize, nbpRefuse,
                            Plan, Err),
        'program planning refuses raw images that could overwrite spare data');

  G := Geo(nilMainOnly);
  Map := AllGood(G);

  //Exactly two blocks worth of image
  Bytes := NANDImageBlockStride(G) * 2;
  Check(PlanNANDProgram(G, Map, 0, Bytes, nbpRefuse, Plan, Err),
        'a two-block program plans', Err);
  Check(NANDPlanCountKind(Plan, nskErase) = 2,
        'each touched block is erased exactly once');
  Check(NANDPlanCountKind(Plan, nskProgram) = 128,
        'both blocks are programmed page by page');
  Check(Plan.ProgramBytes = Bytes, 'every image byte is programmed');
  Check((Plan.BlocksUsed = 2) and (Plan.BlocksSkipped = 0),
        'two good blocks used, none skipped');

  //A partial final page must still be transferred, not rounded away
  Bytes := NANDImageBlockStride(G) + 10;
  Check(PlanNANDProgram(G, Map, 0, Bytes, nbpRefuse, Plan, Err),
        'an image ending mid-page plans', Err);
  Check(Plan.ProgramBytes = Bytes,
        'the short final page carries its exact byte count');

  Check(PlanNANDRead(G, Map, 0, Bytes, nbpRefuse, Plan, Err) and
        (NANDPlanCountKind(Plan, nskErase) = 0),
        'a read plan never erases anything', Err);
  Check(Plan.ReadBytes = Bytes, 'the read plan covers the whole request');

  Check(PlanNANDProgram(G, Map, 0, 0, nbpRefuse, Plan, Err) and
        (Length(Plan.Steps) = 0),
        'an empty request is a valid empty plan', Err);
end;

procedure TestBadBlocks;
var
  G: TNANDGeometry;
  Map: TNANDBlockMap;
  Plan: TNANDPlan;
  Err: string;
  Bytes: QWord;
  i: SizeInt;
begin
  WriteLn('Planning: bad blocks are never touched');

  G := Geo(nilMainOnly);
  Map := AllGood(G);
  Map[1] := nbsFactoryBad;

  Bytes := NANDImageBlockStride(G) * 2;

  //Exact placement must refuse rather than silently move the payload
  Check(not PlanNANDProgram(G, Map, 0, Bytes, nbpRefuse, Plan, Err),
        'an exact request spanning a bad block is refused');
  Check(Length(Plan.Steps) = 0, 'a refused request leaves no plan behind');

  //Skip mode steps over it
  Check(PlanNANDProgram(G, Map, 0, Bytes, nbpSkip, Plan, Err),
        'skip mode plans around the bad block', Err);
  Check(Plan.BlocksSkipped = 1, 'the bad block is counted as skipped');
  Check(Plan.BlocksUsed = 2, 'two good blocks still carry the payload');
  for i := 0 to High(Plan.Steps) do
    if Plan.Steps[i].Block = 1 then
      Check(False, 'no step addresses the bad block');
  Check(Plan.ProgramBytes = Bytes,
        'skipping loses none of the payload');

  //A run of bad blocks at the start
  Map := AllGood(G);
  Map[0] := nbsFactoryBad;
  Map[1] := nbsRuntimeBad;
  Check(PlanNANDProgram(G, Map, 0, NANDImageBlockStride(G), nbpSkip,
                        Plan, Err),
        'a leading run of bad blocks is skipped', Err);
  Check(Plan.FirstBlock = 2, 'the plan starts at the first good block');

  //Unknown blocks are not usable even in skip mode
  Map := NewNANDBlockMap(G);
  Check(not PlanNANDProgram(G, Map, 0, NANDImageBlockStride(G), nbpSkip,
                            Plan, Err),
        'an unscanned map cannot satisfy any request');

  //Not enough good blocks left
  Map := AllGood(G);
  for i := 2 to High(Map) do Map[i] := nbsFactoryBad;
  Check(not PlanNANDProgram(G, Map, 0, NANDImageBlockStride(G) * 4,
                            nbpSkip, Plan, Err),
        'running out of good blocks fails rather than truncating');

  //A start block past the end
  Map := AllGood(G);
  Check(not PlanNANDProgram(G, Map, 99, NANDImageBlockStride(G), nbpSkip,
                            Plan, Err),
        'a start block past the end is refused');

  //An image bigger than the chip
  Check(not PlanNANDProgram(G, Map, 0, NANDImageSize(G) + 1, nbpSkip,
                            Plan, Err),
        'an image larger than the chip is refused');
end;

procedure TestErasePlanning;
var
  G: TNANDGeometry;
  Map: TNANDBlockMap;
  Plan: TNANDPlan;
  Err: string;
begin
  WriteLn('Planning: erase-only ranges obey the bad-block policy');

  G := Geo(nilMainOnly);
  Map := AllGood(G);

  Check(PlanNANDErase(G, Map, 2, 3, nbpRefuse, Plan, Err),
        'three known-good blocks can be erased exactly', Err);
  Check((Length(Plan.Steps) = 3) and
        (NANDPlanCountKind(Plan, nskErase) = 3),
        'an erase-only plan contains one erase step per block');
  Check((Plan.Steps[0].Block = 2) and (Plan.Steps[2].Block = 4),
        'the exact erase range keeps its physical block addresses');
  Check((Plan.ProgramBytes = 0) and (Plan.ReadBytes = 0),
        'erase-only planning never claims image bytes');

  Map[3] := nbsFactoryBad;
  Check(not PlanNANDErase(G, Map, 2, 3, nbpRefuse, Plan, Err),
        'exact erase refuses a bad block in the requested range');
  Check(Length(Plan.Steps) = 0,
        'a refused exact erase leaves no executable steps');

  Check(PlanNANDErase(G, Map, 2, 3, nbpSkip, Plan, Err),
        'skip erase moves around a known bad block', Err);
  Check((Plan.BlocksUsed = 3) and (Plan.BlocksSkipped = 1) and
        (Plan.Steps[0].Block = 2) and (Plan.Steps[1].Block = 4) and
        (Plan.Steps[2].Block = 5),
        'skip erase consumes three good blocks and never the bad one');

  Check(PlanNANDErase(G, Map, 0, 0, nbpRefuse, Plan, Err) and
        (Length(Plan.Steps) = 0),
        'an empty erase request is a valid no-op', Err);
end;

procedure TestValidatorCatchesBadPlans;
var
  G: TNANDGeometry;
  Map: TNANDBlockMap;
  Plan: TNANDPlan;
  Err: string;
begin
  WriteLn('Validator: hand-built broken plans are caught');

  G := Geo(nilRaw);
  Map := AllGood(G);
  Map[3] := nbsFactoryBad;

  //Program without erase
  ClearNANDPlan(Plan);
  SetLength(Plan.Steps, 1);
  Plan.Steps[0].Kind := nskProgram;
  Plan.Steps[0].Block := 0;
  Plan.Steps[0].Page := 0;
  Plan.Steps[0].ImageOffset := 0;
  Plan.Steps[0].Length := 2112;
  Check(not ValidateNANDPlan(Plan, G, Map, Err),
        'programming a block that was never erased is rejected');

  //Touching a bad block
  ClearNANDPlan(Plan);
  SetLength(Plan.Steps, 1);
  Plan.Steps[0].Kind := nskErase;
  Plan.Steps[0].Block := 3;
  Plan.Steps[0].Length := 0;
  Check(not ValidateNANDPlan(Plan, G, Map, Err),
        'erasing a bad block is rejected');

  //A gap in the image offsets
  ClearNANDPlan(Plan);
  SetLength(Plan.Steps, 3);
  Plan.Steps[0].Kind := nskErase;
  Plan.Steps[0].Block := 0;
  Plan.Steps[0].Length := 0;
  Plan.Steps[1].Kind := nskProgram;
  Plan.Steps[1].Block := 0;
  Plan.Steps[1].Page := 0;
  Plan.Steps[1].ImageOffset := 0;
  Plan.Steps[1].Length := 2112;
  Plan.Steps[2].Kind := nskProgram;
  Plan.Steps[2].Block := 0;
  Plan.Steps[2].Page := 1;
  Plan.Steps[2].ImageOffset := 9999; //gap
  Plan.Steps[2].Length := 2112;
  Check(not ValidateNANDPlan(Plan, G, Map, Err),
        'a gap in the image offsets is rejected');

  //A page index past the end of a block
  ClearNANDPlan(Plan);
  SetLength(Plan.Steps, 2);
  Plan.Steps[0].Kind := nskErase;
  Plan.Steps[0].Block := 0;
  Plan.Steps[0].Length := 0;
  Plan.Steps[1].Kind := nskProgram;
  Plan.Steps[1].Block := 0;
  Plan.Steps[1].Page := 64;
  Plan.Steps[1].ImageOffset := 0;
  Plan.Steps[1].Length := 2112;
  Check(not ValidateNANDPlan(Plan, G, Map, Err),
        'a page index past the end of a block is rejected');
end;

procedure TestRandomised;
const
  ROUNDS = 500;
var
  Round, i: integer;
  G: TNANDGeometry;
  Map: TNANDBlockMap;
  Plan: TNANDPlan;
  Err: string;
  Bytes, Covered: QWord;
  Blocks: cardinal;
  OK: boolean;
  s: SizeInt;
begin
  WriteLn('Randomised: ', ROUNDS, ' bad-block layouts keep every invariant');
  RandSeed := 20260728;
  OK := True;

  for Round := 1 to ROUNDS do
  begin
    Blocks := 4 + cardinal(Random(28));
    G := Geo(nilMainOnly, Blocks);

    Map := NewNANDBlockMap(G);
    for i := 0 to High(Map) do
      if Random(4) = 0 then Map[i] := nbsFactoryBad else Map[i] := nbsGood;

    Bytes := QWord(1 + Random(SizeInt(NANDImageSize(G))));

    if not PlanNANDProgram(G, Map, 0, Bytes, nbpSkip, Plan, Err) then
      Continue; //legitimately out of good blocks

    //Independent re-validation
    if not ValidateNANDPlan(Plan, G, Map, Err) then
    begin
      OK := False;
      WriteLn('  round ', Round, ': plan failed validation: ', Err);
      Break;
    end;
    //Every byte accounted for exactly once
    if Plan.ProgramBytes <> Bytes then
    begin
      OK := False;
      WriteLn('  round ', Round, ': planned ', Plan.ProgramBytes,
              ' bytes for a ', Bytes, '-byte image');
      Break;
    end;
    //No step may touch a block the map does not call good
    Covered := 0;
    for s := 0 to High(Plan.Steps) do
    begin
      if Map[Plan.Steps[s].Block] <> nbsGood then
      begin
        OK := False;
        WriteLn('  round ', Round, ': touched bad block ',
                Plan.Steps[s].Block);
        Break;
      end;
      if Plan.Steps[s].Kind = nskProgram then
        Inc(Covered, Plan.Steps[s].Length);
    end;
    if not OK then Break;
    if Covered <> Bytes then
    begin
      OK := False;
      WriteLn('  round ', Round, ': program steps cover ', Covered,
              ' of ', Bytes);
      Break;
    end;
  end;

  Check(OK, 'randomised bad-block layouts hold every invariant');
end;

begin
  TestGeometry;
  TestBlockMap;
  TestPlanHappyPath;
  TestBadBlocks;
  TestErasePlanning;
  TestValidatorCatchesBadPlans;
  TestRandomised;

  if ChecksFailed = 0 then
  begin
    WriteLn('PASS: ', ChecksRun, ' NAND planner checks');
    ExitCode := 0;
  end
  else
  begin
    WriteLn('FAIL: ', ChecksFailed, ' of ', ChecksRun, ' checks failed');
    ExitCode := 1;
  end;
end.
