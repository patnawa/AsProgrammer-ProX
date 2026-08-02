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

function HexBytes(const Hex: string): TBytes;
var
  i: SizeInt;
  V: integer;
begin
  Result := nil;
  if (Length(Hex) and 1) <> 0 then Exit;
  SetLength(Result, Length(Hex) div 2);
  for i := 0 to High(Result) do
  begin
    if not TryStrToInt('$' + Copy(Hex, i * 2 + 1, 2), V) then
    begin
      Result := nil;
      Exit;
    end;
    Result[i] := byte(V);
  end;
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
    Chip.MarkFactoryBadOnSecondPage(12);
    Check('the scan succeeds', ScanNANDBadBlocks(Chip, Geo, Map, Err));
    Check('marked blocks are factory bad',
          (Map[3] = nbsFactoryBad) and (Map[9] = nbsFactoryBad) and
          (Map[12] = nbsFactoryBad));
    Check('unmarked blocks are good',
          (Map[0] = nbsGood) and (Map[15] = nbsGood));
    Check('usable count excludes the bad ones', NANDCountUsable(Map) = 13);
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
    Rep := ExecuteNANDWrite(Chip, Geo, Map, Plan, Image,
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

procedure TestFullPageWriteVerification;
var
  Geo: TNANDGeometry;
  Chip: TVirtualSPINAND;
  Map: TNANDBlockMap;
  Plan: TNANDPlan;
  Image: TBytes;
  Err: string;
  Rep: TNANDRunReport;
  BytesBefore: QWord;
  ErasesBefore, ProgramsBefore: integer;
begin
  WriteLn('Write: verification covers the full physical page and is mandatory');
  Geo := SmallGeometry(nilMainOnly);
  Chip := TVirtualSPINAND.Create(Geo);
  try
    Check('scan', ScanNANDBadBlocks(Chip, Geo, Map, Err));
    Image := PatternImage(17, 33); //deliberately ends in the first page
    Check('partial-page plan',
          PlanNANDProgram(Geo, Map, 0, Length(Image), nbpRefuse, Plan, Err));

    BytesBefore := Chip.ReadBytes;
    Rep := ExecuteNANDWrite(Chip, Geo, Map, Plan, Image,
                            @StopNever, nil);
    Check('partial-page write succeeds: ' + Rep.ErrorText,
          Rep.Success and (Rep.ErrorCode = nreNone));
    Check('read-back covers the complete main area of the physical page',
          Chip.ReadBytes - BytesBefore = Geo.PageSize);

    ErasesBefore := Chip.EraseCalls;
    ProgramsBefore := Chip.ProgramCalls;
    Rep := ExecuteNANDProgram(Chip, Geo, Map, Plan, Image, False,
                              @StopNever, nil);
    Check('the legacy no-verify bypass is rejected before mutation',
          (not Rep.Success) and (Rep.ErrorCode = nreInvalidRequest) and
          (Chip.EraseCalls = ErasesBefore) and
          (Chip.ProgramCalls = ProgramsBefore));
  finally
    Chip.Free;
  end;
end;

procedure TestEraseExecution;
var
  Geo: TNANDGeometry;
  Chip: TVirtualSPINAND;
  Map: TNANDBlockMap;
  Plan: TNANDPlan;
  Image: TBytes;
  Err: string;
  Rep: TNANDRunReport;
  ReadsBeforeErase: integer;
  Page: cardinal;
  Blank: boolean;
begin
  WriteLn('Erase: every selected block is read back in full before PASS');
  Geo := SmallGeometry(nilMainOnly);
  Chip := TVirtualSPINAND.Create(Geo);
  try
    Check('scan', ScanNANDBadBlocks(Chip, Geo, Map, Err));

    Image := PatternImage(Geo.PageSize * Geo.PagesPerBlock, 21);
    Check('seed program plan',
          PlanNANDProgram(Geo, Map, 0, Length(Image), nbpRefuse, Plan, Err));
    Rep := ExecuteNANDProgram(Chip, Geo, Map, Plan, Image, True,
                              @StopNever, nil);
    Check('seed data was programmed: ' + Rep.ErrorText, Rep.Success);

    Check('erase plan', PlanNANDErase(Geo, Map, 0, 1, nbpRefuse,
                                      Plan, Err));
    ReadsBeforeErase := Chip.ReadCalls;
    Rep := ExecuteNANDErase(Chip, Geo, Map, Plan, @StopNever, nil);
    Check('verified erase succeeds: ' + Rep.ErrorText,
          Rep.Success and (Rep.ErrorCode = nreNone));
    Check('every page was read back after erase',
          Chip.ReadCalls - ReadsBeforeErase = integer(Geo.PagesPerBlock));

    Blank := True;
    for Page := 0 to Geo.PagesPerBlock - 1 do
      if (Chip.MainByte(0, Page, 0) <> $FF) or
         (Chip.MainByte(0, Page, Geo.PageSize - 1) <> $FF) then
        Blank := False;
    Check('the complete block is blank', Blank);
    Check('erase verification restores the caller ECC state', Chip.ECCOn);
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
    Check('uncorrectable ECC has a typed outcome',
          Rep.ErrorCode = nreUncorrectableECC);
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
    Check('E_FAIL has a typed outcome', Rep.ErrorCode = nreEraseFailed);
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
    Check('P_FAIL has a typed outcome', Rep.ErrorCode = nreProgramFailed);
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

procedure TestEraseFailureAndCancellation;
var
  Geo: TNANDGeometry;
  Chip: TVirtualSPINAND;
  LyingChip: TLyingLockNAND;
  Map: TNANDBlockMap;
  Plan: TNANDPlan;
  Err: string;
  Rep: TNANDRunReport;
begin
  WriteLn('Erase safety: E_FAIL, silent locks, and block-boundary cancellation');
  Geo := SmallGeometry(nilMainOnly);

  Chip := TVirtualSPINAND.Create(Geo);
  try
    Check('erase E_FAIL scan', ScanNANDBadBlocks(Chip, Geo, Map, Err));
    Check('erase E_FAIL plan',
          PlanNANDErase(Geo, Map, 2, 1, nbpRefuse, Plan, Err));
    Chip.FailEraseBlock := 2;
    Rep := ExecuteNANDErase(Chip, Geo, Map, Plan, @StopNever, nil);
    Check('erase-only E_FAIL is typed and addressed',
          (not Rep.Success) and (Rep.ErrorCode = nreEraseFailed) and
          Rep.HasFailAddress and (Rep.FailBlock = 2));
  finally
    Chip.Free;
  end;

  LyingChip := TLyingLockNAND.Create(Geo);
  try
    Check('silent-lock erase scan',
          ScanNANDBadBlocks(LyingChip, Geo, Map, Err));
    LyingChip.SeedMain(0, 0, 0, $00);
    Check('silent-lock erase plan',
          PlanNANDErase(Geo, Map, 0, 1, nbpRefuse, Plan, Err));
    Rep := ExecuteNANDErase(LyingChip, Geo, Map, Plan, @StopNever, nil);
    Check('blank read-back catches a silently ignored erase',
          (not Rep.Success) and (Rep.ErrorCode = nreVerifyMismatch) and
          Rep.HasFailAddress and (Rep.FailBlock = 0) and
          (Rep.FailPage = 0));
  finally
    LyingChip.Free;
  end;

  Chip := TVirtualSPINAND.Create(Geo);
  try
    Check('cancel erase scan', ScanNANDBadBlocks(Chip, Geo, Map, Err));
    Chip.SeedMain(0, 0, 0, $00);
    Chip.SeedMain(1, 0, 0, $00);
    Check('cancel erase plan',
          PlanNANDErase(Geo, Map, 0, 2, nbpRefuse, Plan, Err));
    StopBudget := 1;
    Rep := ExecuteNANDErase(Chip, Geo, Map, Plan, @StopAfterBudget, nil);
    Check('erase cancellation is typed at the next block boundary',
          (not Rep.Success) and Rep.Cancelled and
          (Rep.ErrorCode = nreCancelled) and (Rep.StepsDone = 1));
    Check('the current block was erased and fully checked before cancel',
          Chip.MainByte(0, 0, 0) = $FF);
    Check('the next block was not touched', Chip.MainByte(1, 0, 0) = $00);
  finally
    Chip.Free;
  end;
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
    Check('the read-back mismatch has a typed outcome',
          Rep.ErrorCode = nreVerifyMismatch);
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
  WriteLn('Cancellation: stops between blocks, never inside a mutated block');
  Geo := SmallGeometry(nilMainOnly);
  Chip := TVirtualSPINAND.Create(Geo);
  try
    Check('scan', ScanNANDBadBlocks(Chip, Geo, Map, Err));
    Image := PatternImage(2 * 4 * 512, 4);
    Check('plan', PlanNANDProgram(Geo, Map, 0, Length(Image), nbpSkip,
                                  Plan, Err));
    //The callback is polled at block boundaries. Permit block 0, then ask to
    //stop before block 1; block 0 must be completely written and verified.
    StopBudget := 1;
    Rep := ExecuteNANDProgram(Chip, Geo, Map, Plan, Image, True,
                              @StopAfterBudget, nil);
    Check('the run reports cancellation',
          (not Rep.Success) and Rep.Cancelled);
    Check('cancellation has a typed outcome',
          Rep.ErrorCode = nreCancelled);
    Check('the completed block includes erase plus every page',
          Rep.StepsDone = 5);
    Check('the first block was completed before cancellation',
          (Chip.MainByte(0, 0, 0) = Image[0]) and
          (Chip.MainByte(0, 3, 511) = Image[4 * 512 - 1]));
    Check('the next block was not mutated',
          (Chip.MainByte(1, 0, 0) = $FF) and
          (Chip.MainByte(1, 3, 511) = $FF));
  finally
    Chip.Free;
  end;
end;

procedure TestMutationSessionCleanup;
var
  Geo: TNANDGeometry;
  Chip: TVirtualSPINAND;
  Map: TNANDBlockMap;
  Plan: TNANDPlan;
  Image: TBytes;
  Err: string;
  Rep: TNANDRunReport;
begin
  WriteLn('Mutation session: drain disposition and exact A0/B0 restoration');
  Geo := SmallGeometry(nilMainOnly);
  Image := PatternImage(Geo.PageSize, 51);

  Chip := TVirtualSPINAND.Create(Geo);
  try
    Chip.ProtectionValue := $38;
    Chip.ConfigurationValue := $A5;
    Check('cleanup success scan', ScanNANDBadBlocks(Chip, Geo, Map, Err));
    Check('cleanup success plan',
          PlanNANDProgram(Geo, Map, 0, Length(Image), nbpRefuse, Plan, Err));
    Rep := ExecuteNANDWrite(Chip, Geo, Map, Plan, Image, @StopNever, nil);
    Check('the reference mutation succeeds', Rep.Success);
    Check('successful mutation restores the exact inherited registers',
          (Chip.ProtectionValue = $38) and
          (Chip.ConfigurationValue = $A5));
    Check('successful mutation proves the array idle',
          (Chip.EnsureIdleCalls > 0) and
          (Rep.Disposition = nrdArrayIdle));
  finally
    Chip.Free;
  end;

  Chip := TVirtualSPINAND.Create(Geo);
  try
    Chip.ProtectionValue := $38;
    Chip.ConfigurationValue := $A5;
    Check('post-issue scan', ScanNANDBadBlocks(Chip, Geo, Map, Err));
    Check('post-issue erase plan',
          PlanNANDErase(Geo, Map, 0, 1, nbpRefuse, Plan, Err));
    Chip.FailEraseAfterIssue := True;
    Rep := ExecuteNANDErase(Chip, Geo, Map, Plan, @StopNever, nil);
    Check('a possibly-issued erase keeps its primary transport failure',
          (not Rep.Success) and (Rep.ErrorCode = nreTransport));
    Check('the engine drains a possibly-issued command before cleanup',
          (Chip.EnsureIdleCalls > 0) and
          (Rep.Disposition = nrdArrayIdle));
    Check('post-error cleanup restores both exact registers',
          (Chip.ProtectionValue = $38) and
          (Chip.ConfigurationValue = $A5));
  finally
    Chip.Free;
  end;

  Chip := TVirtualSPINAND.Create(Geo);
  try
    Chip.ProtectionValue := $38;
    Chip.ConfigurationValue := $A5;
    Check('unknown-busy scan', ScanNANDBadBlocks(Chip, Geo, Map, Err));
    Check('unknown-busy plan',
          PlanNANDErase(Geo, Map, 0, 1, nbpRefuse, Plan, Err));
    Chip.FailEraseAfterIssue := True;
    Chip.FailEnsureIdle := True;
    Chip.RemainBusy := True;
    Rep := ExecuteNANDErase(Chip, Geo, Map, Plan, @StopNever, nil);
    Check('an undrainable command has explicit unknown-busy disposition',
          (not Rep.Success) and
          (Rep.Disposition = nrdArrayBusyUnknown));
    Check('unknown busy is surfaced as cleanup state without hiding primary',
          (Rep.ErrorCode = nreTransport) and Rep.CleanupFailed and
          (Pos('busy', LowerCase(Rep.CleanupErrorText)) > 0));
  finally
    Chip.Free;
  end;

  Chip := TVirtualSPINAND.Create(Geo);
  try
    Chip.ProtectionValue := $38;
    Chip.ConfigurationValue := $A5;
    Check('cleanup-failure scan', ScanNANDBadBlocks(Chip, Geo, Map, Err));
    Check('cleanup-failure plan',
          PlanNANDProgram(Geo, Map, 0, Length(Image), nbpRefuse, Plan, Err));
    Chip.FailProgramBlock := 0;
    Chip.FailProgramPage := 0;
    Chip.FailConfigurationRestore := True;
    Rep := ExecuteNANDWrite(Chip, Geo, Map, Plan, Image, @StopNever, nil);
    Check('cleanup failure preserves the primary P_FAIL outcome',
          (not Rep.Success) and (Rep.ErrorCode = nreProgramFailed));
    Check('cleanup failure is independently visible',
          Rep.CleanupFailed and
          (Pos('configuration', LowerCase(Rep.CleanupErrorText)) > 0));
    Check('a B0 restore failure does not prevent the A0 restore attempt',
          Chip.ProtectionValue = $38);
  finally
    Chip.Free;
  end;

  Chip := TVirtualSPINAND.Create(Geo);
  try
    Chip.ProtectionValue := $38;
    Chip.ConfigurationValue := $A5;
    Check('post-WREN scan', ScanNANDBadBlocks(Chip, Geo, Map, Err));
    Check('post-WREN plan',
          PlanNANDProgram(Geo, Map, 0, Length(Image), nbpRefuse, Plan, Err));
    Chip.FailProgramAfterWREN := True;
    Rep := ExecuteNANDWrite(Chip, Geo, Map, Plan, Image, @StopNever, nil);
    Check('a program-load transport failure remains the primary outcome',
          (not Rep.Success) and (Rep.ErrorCode = nreTransport));
    Check('cleanup sends checked write-disable after a post-WREN failure',
          (Chip.WriteDisableCalls > 0) and (not Chip.WriteEnabled));
    Check('post-WREN cleanup restores exact A0h and B0h',
          (Chip.ProtectionValue = $38) and
          (Chip.ConfigurationValue = $A5));
  finally
    Chip.Free;
  end;

  Chip := TVirtualSPINAND.Create(Geo);
  try
    Chip.ProtectionValue := $38;
    Chip.ConfigurationValue := $A5;
    Check('unproven-WEL scan', ScanNANDBadBlocks(Chip, Geo, Map, Err));
    Check('unproven-WEL plan',
          PlanNANDProgram(Geo, Map, 0, Length(Image), nbpRefuse, Plan, Err));
    Chip.FailProgramAfterWREN := True;
    Chip.FailWriteDisable := True;
    Rep := ExecuteNANDWrite(Chip, Geo, Map, Plan, Image, @StopNever, nil);
    Check('failed WEL cleanup has an explicit unknown-device disposition',
          (not Rep.Success) and
          (Rep.Disposition = nrdDeviceStateUnknown));
    Check('failed WEL cleanup preserves the primary transport outcome',
          (Rep.ErrorCode = nreTransport) and Rep.CleanupFailed and
          (Pos('WEL', Rep.CleanupErrorText) > 0));
    Check('the virtual chip proves WEL was not falsely reported clear',
          Chip.WriteEnabled);
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

procedure TestONFIParameterPage;
const
  //A fixed ONFI 2.x parameter page shaped like the documented Macronix
  //MX35LF1GE4AB values, including byte 101=00 (address cycles N/A). CRC
  //bytes C9 4D encode the independently calculated CRC16 $4DC9 over bytes
  //0..253 (ONFI polynomial $8005, initial $4F4E).
  FixtureHex =
    '4F4E464900000000000000000000030000000000000000000000000000000000' +
    '4D4143524F4E4958202020204D5833354C463147453441422020202020202020' +
    'C200000000000000000000000000000000080000400000020000100040000000' +
    '0004000001000100000000000000000000000000000000000000000000000000' +
    '0000000000000000000000000000000000000000000000000000000000000000' +
    '0000000000000000000000000000000000000000000000000000000000000000' +
    '0000000000000000000000000000000000000000000000000000000000000000' +
    '000000000000000000000000000000000000000000000000000000000000C94D';
var
  Page, Raw: TBytes;
  Params, ChangedParams: TONFIParameterPage;
  Geo: TNANDGeometry;
  Entry: TNANDCatalogEntry;
  Access: TSPINANDParameterPageAccess;
  Err: string;
begin
  WriteLn('ONFI: CRC-checked redundant parameter-page parsing');
  Page := HexBytes(FixtureHex);
  Check('the fixed parameter page is exactly 256 bytes', Length(Page) = 256);
  Check('the ONFI CRC matches its independent fixture value',
        ONFICRC16(Page, 254) = $4DC9);

  SetLength(Raw, 3 * Length(Page));
  Move(Page[0], Raw[0], Length(Page));
  Move(Page[0], Raw[Length(Page)], Length(Page));
  Move(Page[0], Raw[2 * Length(Page)], Length(Page));
  Raw[20] := Raw[20] xor 1;
  Raw[256 + 20] := Raw[256 + 20] xor 1;

  Err := '';
  Check('a valid third redundant copy is accepted',
        ParseONFIParameterPages(Raw, Params, Err));
  Check('the parser identifies the surviving copy', Params.SelectedCopy = 2);
  Check('manufacturer and model strings are trimmed',
        (Params.Manufacturer = 'MACRONIX') and
        (Params.Model = 'MX35LF1GE4AB'));
  Check('the JEDEC manufacturer and geometry fields decode little-endian',
        (Params.JedecManufacturerID = $C2) and
        (Params.PageSize = 2048) and (Params.SpareSize = 64) and
        (Params.PagesPerBlock = 64) and (Params.BlocksPerLUN = 1024) and
        (Params.LUNCount = 1) and (Params.AddressCycles = $00) and
        (Params.BitsPerCell = 1));
  Check('generic admission rejects a zero/N-A address-cycle field',
        not ONFIParameterGeometry(Params, nilMainOnly, Geo, Err));
  Check('identify the exact catalog entry for bound ONFI admission',
        NANDIdentify([$C2, $12, $00, $00], Entry));
  Check('the exact catalog-bound N/A shape becomes main-area geometry',
        NANDCatalogONFIGeometry(Entry, Params, nilMainOnly, Geo, Err));
  Check('the ONFI geometry agrees with the fixture',
        (Geo.PageSize = 2048) and (Geo.SpareSize = 64) and
        (Geo.PagesPerBlock = 64) and (Geo.BlockCount = 1024));
  ChangedParams := Params;
  ChangedParams.JedecManufacturerID := $EF;
  Check('catalog-bound admission rejects a manufacturer mismatch',
        not NANDCatalogONFIGeometry(Entry, ChangedParams, nilMainOnly,
                                     Geo, Err));
  ChangedParams := Params;
  ChangedParams.PageSize := 4096;
  Check('catalog-bound admission rejects a geometry mismatch',
        not NANDCatalogONFIGeometry(Entry, ChangedParams, nilMainOnly,
                                     Geo, Err));
  ChangedParams := Params;
  ChangedParams.AddressCycles := $23;
  Check('the generic path still admits an explicitly declared 2+3 shape',
        ONFIParameterGeometry(ChangedParams, nilMainOnly, Geo, Err));

  Raw[512 + 20] := Raw[512 + 20] xor 1;
  Check('three bad CRCs are rejected',
        not ParseONFIParameterPages(Raw, Params, Err));

  Check('identify Winbond for parameter-page access policy',
        NANDIdentify([$EF, $AA, $21, $00], Entry));
  Check('Winbond ONFI access enables OTP and buffer mode but disables ECC',
        NANDParameterPageAccess(Entry, Access) and Access.Supported and
        (Access.ConfigSetMask = $48) and (Access.ConfigClearMask = $10) and
        (Access.RowAddress = 1) and (Access.CopyCount = 3));
  Check('identify an unverified Winbond sibling',
        NANDIdentify([$EF, $AA, $22, $00], Entry));
  Check('vendor similarity alone does not enable a live ONFI sequence',
        not NANDParameterPageAccess(Entry, Access));
  Check('identify Macronix for parameter-page access policy',
        NANDIdentify([$C2, $12, $00, $00], Entry));
  Check('Macronix ONFI access enables secure OTP and disables ECC',
        NANDParameterPageAccess(Entry, Access) and
        (Access.ConfigSetMask = $40) and (Access.ConfigClearMask = $BF));
  Check('identify GigaDevice for fail-closed parameter-page policy',
        NANDIdentify([$C8, $D1, $00, $00], Entry));
  Check('an unverified GigaDevice sequence is not guessed',
        not NANDParameterPageAccess(Entry, Access));
  Check('identify Kioxia for fail-closed parameter-page policy',
        NANDIdentify([$98, $C2, $00, $00], Entry));
  Check('an unverified vendor access sequence is not guessed',
        not NANDParameterPageAccess(Entry, Access));
end;

begin
  WriteLn('AsProgrammer SPI NAND engine tests');
  WriteLn;

  TestCatalog;
  TestONFIParameterPage;
  TestScan;
  TestProgramReadRoundTrip;
  TestFullPageWriteVerification;
  TestEraseExecution;
  TestECCVerdicts;
  TestChipReportedFailures;
  TestEraseFailureAndCancellation;
  TestSilentProtection;
  TestCancellation;
  TestMutationSessionCleanup;
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
