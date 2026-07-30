program nandengine_tests;

{ The NAND engine against the virtual chip: scans, dumps, programs, and
  every way the chip itself says no (ECC, P_FAIL, E_FAIL, silent protection).

  Build and run:
    fpc -Mobjfpc -Sh nandengine_tests.lpr && nandengine_tests }

{$mode objfpc}{$H+}

uses
  SysUtils, nandmodel, nandplanner, nandengine, nandcatalog, virtualspinand;

var
  Failures: integer = 0;

procedure Check(const Name: string; Cond: boolean);
begin
  if Cond then
    WriteLn('  ok   ', Name)
  else
  begin
    WriteLn('  FAIL ', Name);
    Inc(Failures);
  end;
end;

//เรขาคณิตเล็ก ๆ ให้เทสต์วิ่งเร็ว: เพจ 512+16, บล็อกละ 4 เพจ, 16 บล็อก
function SmallGeometry(Layout: TNANDImageLayout): TNANDGeometry;
var
  Err: string;
begin
  if not BuildNANDGeometry(512, 16, 4, 16, Layout, Result, Err) then
  begin
    WriteLn('  FAIL the test geometry itself is invalid: ', Err);
    Halt(1);
  end;
end;

function PatternImage(Bytes: SizeInt; Seed: cardinal): TBytes;
var
  i: SizeInt;
begin
  Result := nil;
  SetLength(Result, Bytes);
  for i := 0 to Bytes - 1 do
    Result[i] := byte((cardinal(i) * 31 + Seed * 7 + 3) and $FF);
end;

var
  StopBudget: integer;

function StopNever: boolean;
begin
  Result := False;
end;

function StopAfterBudget: boolean;
begin
  Dec(StopBudget);
  Result := StopBudget < 0;
end;

procedure TestScan;
var
  Geo: TNANDGeometry;
  Chip: TVirtualSPINAND;
  Map: TNANDBlockMap;
  Err: string;
begin
  WriteLn('Scan: factory markers and ECC discipline');
  Geo := SmallGeometry(nilMainOnly);
  Chip := TVirtualSPINAND.Create(Geo);
  try
    Chip.MarkFactoryBad(3);
    Chip.MarkFactoryBad(9);
    Check('the scan succeeds', ScanNANDBadBlocks(Chip, Geo, Map, Err));
    Check('marked blocks are factory bad',
          (Map[3] = nbsFactoryBad) and (Map[9] = nbsFactoryBad));
    Check('unmarked blocks are good',
          (Map[0] = nbsGood) and (Map[15] = nbsGood));
    Check('usable count excludes the bad ones', NANDCountUsable(Map) = 14);
    Check('the markers were read with ECC off', Chip.ECCOffDuringScan);
    Check('the previous ECC state was restored', Chip.ECCOn);

    //สแกนล้มกลางทางต้องได้แผนที่ unknown ล้วน ไม่ใช่ครึ่ง ๆ กลาง ๆ
    Chip.FailAtCall := Chip.ReadCalls + 8;
    Check('a scan that dies midway reports failure',
          not ScanNANDBadBlocks(Chip, Geo, Map, Err));
    Check('and leaves no block believed good', NANDCountUsable(Map) = 0);
  finally
    Chip.Free;
  end;
end;

procedure TestProgramReadRoundTrip;
var
  Geo: TNANDGeometry;
  Chip: TVirtualSPINAND;
  Map: TNANDBlockMap;
  Plan: TNANDPlan;
  Image, Back: TBytes;
  Err: string;
  Rep: TNANDRunReport;
  i: SizeInt;
  Same: boolean;
begin
  WriteLn('Round trip: program then read, skipping the bad block');
  Geo := SmallGeometry(nilMainOnly);
  Chip := TVirtualSPINAND.Create(Geo);
  try
    Chip.MarkFactoryBad(1);
    Check('scan', ScanNANDBadBlocks(Chip, Geo, Map, Err));

    Image := PatternImage(3 * 4 * 512, 5); //สามบล็อกเต็ม
    Check('program plan builds',
          PlanNANDProgram(Geo, Map, 0, Length(Image), nbpSkip, Plan, Err));
    Rep := ExecuteNANDProgram(Chip, Geo, Map, Plan, Image, True,
                              @StopNever, nil);
    Check('program succeeds: ' + Rep.ErrorText, Rep.Success);
    Check('the bad block was never written',
          Chip.MainByte(1, 0, 0) = $FF);

    Check('read plan builds',
          PlanNANDRead(Geo, Map, 0, Length(Image), nbpSkip, Plan, Err));
    Back := nil;
    SetLength(Back, Length(Image));
    Rep := ExecuteNANDRead(Chip, Geo, Map, Plan, Back, @StopNever, nil);
    Check('read succeeds: ' + Rep.ErrorText, Rep.Success);
    Same := True;
    for i := 0 to High(Image) do
      if Image[i] <> Back[i] then begin Same := False; Break; end;
    Check('what was written is what reads back', Same);
    Check('no pages needed correction', Rep.CorrectedPages = 0);
  finally
    Chip.Free;
  end;
end;

procedure TestECCVerdicts;
var
  Geo: TNANDGeometry;
  Chip: TVirtualSPINAND;
  Map: TNANDBlockMap;
  Plan: TNANDPlan;
  Back: TBytes;
  Err: string;
  Rep: TNANDRunReport;
begin
  WriteLn('ECC: corrected is counted, uncorrectable fails with the address');
  Geo := SmallGeometry(nilMainOnly);
  Chip := TVirtualSPINAND.Create(Geo);
  try
    Check('scan', ScanNANDBadBlocks(Chip, Geo, Map, Err));
    Chip.InjectCorrected(0, 1);
    Chip.InjectCorrected(2, 0);
    Chip.InjectUncorrectable(3, 2);

    //อ่านสองบล็อกแรก เจอเฉพาะ corrected
    Check('read plan for two blocks',
          PlanNANDRead(Geo, Map, 0, 2 * 4 * 512, nbpSkip, Plan, Err));
    SetLength(Back, 2 * 4 * 512);
    Rep := ExecuteNANDRead(Chip, Geo, Map, Plan, Back, @StopNever, nil);
    Check('the dump succeeds', Rep.Success);
    Check('one corrected page was counted', Rep.CorrectedPages = 1);
    Check('the wear map blames block 0 and clears block 1',
          (Length(Rep.CorrectedPerBlock) = 16) and
          (Rep.CorrectedPerBlock[0] = 1) and (Rep.CorrectedPerBlock[1] = 0));

    //อ่านคลุมบล็อก 3 ต้องพังพร้อมชื่อเพจ
    Check('read plan across the rotten page',
          PlanNANDRead(Geo, Map, 3, 4 * 512, nbpSkip, Plan, Err));
    SetLength(Back, 4 * 512);
    Rep := ExecuteNANDRead(Chip, Geo, Map, Plan, Back, @StopNever, nil);
    Check('the dump is refused', not Rep.Success);
    Check('the failing page is named',
          Rep.HasFailAddress and (Rep.FailBlock = 3) and (Rep.FailPage = 2));
    Check('the message says uncorrectable',
          Pos('uncorrectable', Rep.ErrorText) > 0);
  finally
    Chip.Free;
  end;
end;

procedure TestChipReportedFailures;
var
  Geo: TNANDGeometry;
  Chip: TVirtualSPINAND;
  Map: TNANDBlockMap;
  Plan: TNANDPlan;
  Image: TBytes;
  Err: string;
  Rep: TNANDRunReport;
begin
  WriteLn('P_FAIL and E_FAIL: the chip''s own word is believed');
  Geo := SmallGeometry(nilMainOnly);

  Chip := TVirtualSPINAND.Create(Geo);
  try
    Check('scan', ScanNANDBadBlocks(Chip, Geo, Map, Err));
    Image := PatternImage(4 * 512, 1);
    Check('plan', PlanNANDProgram(Geo, Map, 2, Length(Image), nbpSkip,
                                  Plan, Err));
    Chip.FailEraseBlock := 2;
    Rep := ExecuteNANDProgram(Chip, Geo, Map, Plan, Image, True,
                              @StopNever, nil);
    Check('E_FAIL fails the run', not Rep.Success);
    Check('E_FAIL names the block',
          Rep.HasFailAddress and (Rep.FailBlock = 2));
    Check('the message says E_FAIL', Pos('E_FAIL', Rep.ErrorText) > 0);
  finally
    Chip.Free;
  end;

  Chip := TVirtualSPINAND.Create(Geo);
  try
    Check('scan again', ScanNANDBadBlocks(Chip, Geo, Map, Err));
    Image := PatternImage(4 * 512, 2);
    Check('plan again', PlanNANDProgram(Geo, Map, 0, Length(Image), nbpSkip,
                                        Plan, Err));
    Chip.FailProgramBlock := 0;
    Chip.FailProgramPage := 1;
    Rep := ExecuteNANDProgram(Chip, Geo, Map, Plan, Image, True,
                              @StopNever, nil);
    Check('P_FAIL fails the run', not Rep.Success);
    Check('P_FAIL names block and page',
          Rep.HasFailAddress and (Rep.FailBlock = 0) and (Rep.FailPage = 1));
    Check('the message says P_FAIL', Pos('P_FAIL', Rep.ErrorText) > 0);
  finally
    Chip.Free;
  end;
end;

type
  //ชิปที่โกหกว่าปลดล็อกแล้ว: UnlockAll รายงานสำเร็จแต่ยังล็อกอยู่ การเขียน
  //จะถูกเมินเงียบ ๆ ทั้งหมด มีแต่ read-back verify เท่านั้นที่จับได้
  TLyingLockNAND = class(TVirtualSPINAND)
  public
    function UnlockAll: TNANDIOResult; override;
  end;

function TLyingLockNAND.UnlockAll: TNANDIOResult;
begin
  Result.Success := True;
  Result.Error := nnioNone;
  Result.ErrorText := '';
end;

procedure TestSilentProtection;
var
  Geo: TNANDGeometry;
  Chip: TLyingLockNAND;
  Map: TNANDBlockMap;
  Plan: TNANDPlan;
  Image: TBytes;
  Err: string;
  Rep: TNANDRunReport;
begin
  WriteLn('Silent protection: only the read-back catches a chip that lies');
  Geo := SmallGeometry(nilMainOnly);
  Chip := TLyingLockNAND.Create(Geo);
  try
    Check('scan', ScanNANDBadBlocks(Chip, Geo, Map, Err));
    Image := PatternImage(512, 9);
    Check('plan', PlanNANDProgram(Geo, Map, 0, Length(Image), nbpSkip,
                                  Plan, Err));
    Rep := ExecuteNANDProgram(Chip, Geo, Map, Plan, Image, True,
                              @StopNever, nil);
    Check('the silently ignored write is caught', not Rep.Success);
    Check('and blamed on the right page',
          Rep.HasFailAddress and (Rep.FailBlock = 0) and (Rep.FailPage = 0));
  finally
    Chip.Free;
  end;
end;

procedure TestCancellation;
var
  Geo: TNANDGeometry;
  Chip: TVirtualSPINAND;
  Map: TNANDBlockMap;
  Plan: TNANDPlan;
  Image: TBytes;
  Err: string;
  Rep: TNANDRunReport;
begin
  WriteLn('Cancellation: stops at a step boundary, never reports success');
  Geo := SmallGeometry(nilMainOnly);
  Chip := TVirtualSPINAND.Create(Geo);
  try
    Check('scan', ScanNANDBadBlocks(Chip, Geo, Map, Err));
    Image := PatternImage(2 * 4 * 512, 4);
    Check('plan', PlanNANDProgram(Geo, Map, 0, Length(Image), nbpSkip,
                                  Plan, Err));
    StopBudget := 3;
    Rep := ExecuteNANDProgram(Chip, Geo, Map, Plan, Image, True,
                              @StopAfterBudget, nil);
    Check('the run reports cancellation',
          (not Rep.Success) and Rep.Cancelled);
    Check('some steps ran before the stop', Rep.StepsDone = 3);
  finally
    Chip.Free;
  end;
end;

procedure TestFaultMatrix;
var
  Geo: TNANDGeometry;
  Chip: TVirtualSPINAND;
  Map: TNANDBlockMap;
  Plan: TNANDPlan;
  Image: TBytes;
  Err: string;
  Rep: TNANDRunReport;
  RunCalls, BaseCalls, N: integer;
  FalsePass: boolean;
  i: SizeInt;
begin
  WriteLn('Fault matrix: any single device call may fail; no false PASS');
  Geo := SmallGeometry(nilMainOnly);
  Image := PatternImage(4 * 512 + 100, 7);

  //วัดก่อนว่างานเขียนเต็ม ๆ ใช้กี่ device call หลังจบสแกน
  Chip := TVirtualSPINAND.Create(Geo);
  try
    if not ScanNANDBadBlocks(Chip, Geo, Map, Err) then Halt(1);
    if not PlanNANDProgram(Geo, Map, 0, Length(Image), nbpSkip, Plan, Err)
      then Halt(1);
    BaseCalls := Chip.CallCount;
    Rep := ExecuteNANDProgram(Chip, Geo, Map, Plan, Image, True,
                              @StopNever, nil);
    if not Rep.Success then
    begin
      WriteLn('  FAIL the reference run itself failed: ', Rep.ErrorText);
      Halt(1);
    end;
    RunCalls := Chip.CallCount - BaseCalls;
  finally
    Chip.Free;
  end;

  //ยิงทีละ call: ทุกงานที่รายงานสำเร็จต้องทิ้งภาพที่ถูกจริงไว้บนชิป
  FalsePass := False;
  for N := 1 to RunCalls do
  begin
    Chip := TVirtualSPINAND.Create(Geo);
    try
      if not ScanNANDBadBlocks(Chip, Geo, Map, Err) then Continue;
      if not PlanNANDProgram(Geo, Map, 0, Length(Image), nbpSkip, Plan,
                             Err) then Continue;
      Chip.FailAtCall := Chip.CallCount + N;
      Rep := ExecuteNANDProgram(Chip, Geo, Map, Plan, Image, True,
                                @StopNever, nil);
      if Rep.Success then
      begin
        for i := 0 to High(Image) do
          if Chip.MainByte(cardinal(i div (4 * 512)),
                           cardinal((i div 512) mod 4),
                           cardinal(i mod 512)) <> Image[i] then
          begin
            FalsePass := True;
            Break;
          end;
      end;
    finally
      Chip.Free;
    end;
  end;
  Check('every injected failure either failed the run or left a correct ' +
        'image', not FalsePass);
end;

procedure TestRandomised;
var
  Geo: TNANDGeometry;
  Chip: TVirtualSPINAND;
  Map: TNANDBlockMap;
  Plan: TNANDPlan;
  Image, Back: TBytes;
  Err: string;
  Rep: TNANDRunReport;
  Round, b: integer;
  Bad: array of boolean;
  Size: SizeInt;
  Seed: cardinal;
  i: SizeInt;
  OK: boolean;
  UsableBytes: QWord;
begin
  WriteLn('Randomised: 300 layouts, program+read round trips, no bad touch');
  Geo := SmallGeometry(nilMainOnly);
  OK := True;
  Seed := 12345;

  for Round := 1 to 300 do
  begin
    Chip := TVirtualSPINAND.Create(Geo);
    try
      SetLength(Bad, Geo.BlockCount);
      for b := 0 to High(Bad) do
      begin
        //LCG ประจำบ้าน ผลซ้ำได้ทุกเครื่อง
        Seed := Seed * 1103515245 + 12345;
        Bad[b] := (Seed shr 16) mod 5 = 0; //ราวหนึ่งในห้าเป็นบล็อกเสีย
        if Bad[b] then Chip.MarkFactoryBad(cardinal(b));
      end;

      if not ScanNANDBadBlocks(Chip, Geo, Map, Err) then
      begin
        OK := False;
        Break;
      end;

      UsableBytes := QWord(NANDCountUsable(Map)) * 4 * 512;
      if UsableBytes = 0 then Continue;

      Seed := Seed * 1103515245 + 12345;
      Size := SizeInt((Seed shr 16) mod UsableBytes) + 1;
      Image := PatternImage(Size, Seed);

      if not PlanNANDProgram(Geo, Map, 0, Size, nbpSkip, Plan, Err) then
      begin
        OK := False;
        Break;
      end;
      Rep := ExecuteNANDProgram(Chip, Geo, Map, Plan, Image, True,
                                @StopNever, nil);
      if not Rep.Success then
      begin
        OK := False;
        Break;
      end;

      //บล็อกเสียต้องไม่ถูกแตะแม้แต่ไบต์เดียว
      for b := 0 to High(Bad) do
        if Bad[b] and (Chip.MainByte(cardinal(b), 0, 0) <> $FF) then
        begin
          OK := False;
          Break;
        end;
      if not OK then Break;

      if not PlanNANDRead(Geo, Map, 0, Size, nbpSkip, Plan, Err) then
      begin
        OK := False;
        Break;
      end;
      Back := nil;
      SetLength(Back, Size);
      Rep := ExecuteNANDRead(Chip, Geo, Map, Plan, Back, @StopNever, nil);
      if not Rep.Success then
      begin
        OK := False;
        Break;
      end;
      for i := 0 to Size - 1 do
        if Back[i] <> Image[i] then
        begin
          OK := False;
          Break;
        end;
      if not OK then Break;

      //โหมดเข้มงวด: มีบล็อกเสียในช่วงต้องปฏิเสธทั้งงาน
      for b := 0 to High(Bad) do
        if Bad[b] then
        begin
          if PlanNANDProgram(Geo, Map, cardinal(b),
                             QWord(Geo.PagesPerBlock) * Geo.PageSize,
                             nbpRefuse, Plan, Err) then OK := False;
          Break;
        end;
      if not OK then Break;
    finally
      Chip.Free;
    end;
  end;
  Check('all 300 rounds held every invariant', OK);
end;

procedure TestRawLayout;
var
  Geo: TNANDGeometry;
  Chip: TVirtualSPINAND;
  Map: TNANDBlockMap;
  Plan: TNANDPlan;
  Back: TBytes;
  Err: string;
  Rep: TNANDRunReport;
begin
  WriteLn('Raw layout: reads run with ECC off and carry the spare bytes');
  Geo := SmallGeometry(nilRaw);
  Chip := TVirtualSPINAND.Create(Geo);
  try
    Check('scan', ScanNANDBadBlocks(Chip, Geo, Map, Err));
    Check('read plan', PlanNANDRead(Geo, Map, 0, (512 + 16) * 4, nbpSkip,
                                    Plan, Err));
    SetLength(Back, (512 + 16) * 4);
    Rep := ExecuteNANDRead(Chip, Geo, Map, Plan, Back, @StopNever, nil);
    Check('the raw dump succeeds', Rep.Success);
    Check('ECC is off after a raw read', not Chip.ECCOn);
    Check('the spare area is present in the image',
          Back[512] = $FF); //ไบต์แรกของ spare ของเพจแรก
  finally
    Chip.Free;
  end;
end;

procedure TestCatalog;
var
  E: TNANDCatalogEntry;
begin
  WriteLn('Catalog: id matching with and without the dummy byte');
  Check('W25N01GV answers with a leading dummy byte',
        NANDIdentify([$00, $EF, $AA, $21], E) and (E.Name = 'W25N01GV'));
  Check('GD5F1GQ4UB answers without one',
        NANDIdentify([$C8, $D1, $48, $C8], E) and
        (E.Name = 'GD5F1GQ4UBYIG'));
  Check('MX35LF1GE4AB matches on two bytes',
        NANDIdentify([$C2, $12, $C2, $12], E) and
        (E.Name = 'MX35LF1GE4AB'));
  Check('a silent FF bus is not a chip',
        not NANDIdentify([$FF, $FF, $FF, $FF], E));
  Check('an undriven 00 bus is not a chip either',
        not NANDIdentify([$00, $00, $00, $00], E));
  Check('catalog geometries all validate', NANDCatalogList <> '');
end;

begin
  WriteLn('AsProgrammer SPI NAND engine tests');
  WriteLn;

  TestCatalog;
  TestScan;
  TestProgramReadRoundTrip;
  TestECCVerdicts;
  TestChipReportedFailures;
  TestSilentProtection;
  TestCancellation;
  TestFaultMatrix;
  TestRandomised;
  TestRawLayout;

  WriteLn;
  if Failures = 0 then
    WriteLn('ALL PASSED')
  else
    WriteLn(Failures, ' FAILURES');
  Halt(Failures);
end.
