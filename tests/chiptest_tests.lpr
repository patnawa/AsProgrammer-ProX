program chiptest_tests;

{ The capacity test against fake chips of every stripe: genuine, remarked
  at various real sizes, failing writes, dying mid-test. The invariant that
  matters most: whatever happens, the chip's original content is restored
  and verified -- and when it cannot be, the result says so.

  Build and run:
    fpc -Mobjfpc -Sh chiptest_tests.lpr && chiptest_tests }

{$mode objfpc}{$H+}

uses
  SysUtils, chiptest;

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

//---------------------------------------------------------------- fake chip
//ชิปปลอมในหน่วยความจำ: แอดเดรสวนที่ RealSize, ลบทีละเซกเตอร์เป็น FF,
//การเขียน AND บิตแบบแฟลชจริง, ยิง call ที่กำหนดให้ล้มได้

const
  SECTOR = 4096;

var
  FakeMem: TBytes;
  RealSize: QWord;
  EraseCalls, ProgramCalls, ReadCalls: integer;
  FailEraseAt: QWord = High(QWord);   //ลบที่แอดเดรสนี้ (หลัง alias) ให้ล้ม
  DropWritesAbove: QWord = High(QWord); //การเขียนที่แอดเดรสจริง >= นี้หายเงียบ
  StuckZeroAddr: QWord = High(QWord);   //ไบต์ที่บิต 0 ค้างศูนย์หลังลบ

procedure FakeReset(ARealSize: QWord);
var
  i: SizeInt;
begin
  RealSize := ARealSize;
  FakeMem := nil;
  SetLength(FakeMem, ARealSize);
  for i := 0 to High(FakeMem) do
    FakeMem[i] := byte(i * 13 + (i shr 8) * 7 + 1);
  EraseCalls := 0;
  ProgramCalls := 0;
  ReadCalls := 0;
  FailEraseAt := High(QWord);
  DropWritesAbove := High(QWord);
  StuckZeroAddr := High(QWord);
end;

function FakeRead(Address: QWord; Len: cardinal; out Data: TBytes;
  out ErrorText: string): boolean;
var
  i: cardinal;
begin
  ErrorText := '';
  Inc(ReadCalls);
  Data := nil;
  SetLength(Data, Len);
  for i := 0 to Len - 1 do
    Data[i] := FakeMem[(Address + i) mod RealSize];
  Result := True;
end;

function FakeErase(Address: QWord; out ErrorText: string): boolean;
var
  Phys: QWord;
  i: cardinal;
begin
  ErrorText := '';
  Inc(EraseCalls);
  Phys := (Address mod RealSize) and (not QWord(SECTOR - 1));
  if Phys = FailEraseAt then
  begin
    ErrorText := 'injected erase failure';
    Exit(False);
  end;
  for i := 0 to SECTOR - 1 do FakeMem[Phys + i] := $FF;
  //เซลล์ที่บิตค้างศูนย์: ลบยังไงก็อ่านได้ FE ไม่ใช่ FF
  if (StuckZeroAddr >= Phys) and (StuckZeroAddr < Phys + SECTOR) then
    FakeMem[StuckZeroAddr] := $FE;
  Result := True;
end;

function FakeProgram(Address: QWord; const Data: TBytes;
  out ErrorText: string): boolean;
var
  Phys: QWord;
  i: SizeInt;
begin
  ErrorText := '';
  Inc(ProgramCalls);
  Phys := Address mod RealSize;
  if Phys >= DropWritesAbove then Exit(True); //ชิปพยักหน้าแล้วเก็บไม่อยู่
  for i := 0 to High(Data) do
    FakeMem[(Phys + QWord(i)) mod RealSize] :=
      FakeMem[(Phys + QWord(i)) mod RealSize] and Data[i];
  Result := True;
end;

procedure QuietLog(const Msg: string);
begin
  //เทสต์ไม่อยากได้เสียงบรรยาย แต่อยากได้ครอบคลุมโค้ดเส้นที่พ่น log
  if Msg = '' then WriteLn('');
end;

function SnapshotEquals(const Before: TBytes): boolean;
var
  i: SizeInt;
begin
  Result := Length(Before) = Length(FakeMem);
  if not Result then Exit;
  for i := 0 to High(FakeMem) do
    if Before[i] <> FakeMem[i] then Exit(False);
end;

procedure TestMarkers;
var
  A, B: TBytes;
  i: integer;
  Diff: boolean;
begin
  WriteLn('Markers: distinct per address, stable per address');
  A := CapacityMarker($10000);
  B := CapacityMarker($20000);
  Diff := False;
  for i := 0 to CAPTEST_MARKER_LEN - 1 do
    if A[i] <> B[i] then Diff := True;
  Check('two addresses give two markers', Diff);
  B := CapacityMarker($10000);
  Diff := False;
  for i := 0 to CAPTEST_MARKER_LEN - 1 do
    if A[i] <> B[i] then Diff := True;
  Check('the same address gives the same marker', not Diff);
end;

procedure TestGenuine;
var
  Before: TBytes;
  R: TCapacityResult;
begin
  WriteLn('A genuine 1 MB chip');
  FakeReset(1024 * 1024);
  Before := Copy(FakeMem, 0, Length(FakeMem));
  Check('the test runs to completion',
        RunCapacityTest(1024 * 1024, SECTOR, @FakeRead, @FakeErase,
                        @FakeProgram, @QuietLog, R));
  Check('detected equals claimed', R.DetectedSize = 1024 * 1024);
  Check('verdict genuine', R.Genuine and R.Completed);
  Check('restoration verified', R.RestoredOK);
  Check('the chip holds exactly its original bytes', SnapshotEquals(Before));
  Check('eight probes for 1 MB with 4 KB sectors', R.ProbeCount = 8);
end;

procedure TestFake;
var
  Before: TBytes;
  R: TCapacityResult;
begin
  WriteLn('A 256 KB die remarked as 1 MB');
  FakeReset(256 * 1024);
  Before := Copy(FakeMem, 0, Length(FakeMem));
  Check('the test completes despite the fake',
        RunCapacityTest(1024 * 1024, SECTOR, @FakeRead, @FakeErase,
                        @FakeProgram, @QuietLog, R));
  Check('the real capacity is found', R.DetectedSize = 256 * 1024);
  Check('the verdict is not genuine', (not R.Genuine) and R.Completed);
  Check('the original content survives on the real die',
        SnapshotEquals(Before));

  WriteLn('A 64 KB die remarked as 1 MB');
  FakeReset(64 * 1024);
  Before := Copy(FakeMem, 0, Length(FakeMem));
  Check('the test completes',
        RunCapacityTest(1024 * 1024, SECTOR, @FakeRead, @FakeErase,
                        @FakeProgram, @QuietLog, R));
  Check('64 KB is found', R.DetectedSize = 64 * 1024);
  Check('content restored', R.RestoredOK and SnapshotEquals(Before));
end;

procedure TestFailingWrites;
var
  R: TCapacityResult;
begin
  WriteLn('A chip that accepts writes and holds nothing');
  FakeReset(1024 * 1024);
  DropWritesAbove := 0; //ทุกการเขียนหายเงียบ
  Check('the run reports failure',
        not RunCapacityTest(1024 * 1024, SECTOR, @FakeRead, @FakeErase,
                            @FakeProgram, @QuietLog, R));
  Check('the message says failing writes, not fake',
        Pos('failing writes', R.ErrorText) > 0);
  Check('no capacity verdict is invented', R.DetectedSize = 0);
end;

procedure TestEraseDiesMidway;
var
  R: TCapacityResult;
begin
  WriteLn('An erase fails during the marker phase');
  FakeReset(1024 * 1024);
  FailEraseAt := 64 * 1024; //ล้มที่ probe กลาง ๆ
  Check('the run reports failure',
        not RunCapacityTest(1024 * 1024, SECTOR, @FakeRead, @FakeErase,
                            @FakeProgram, @QuietLog, R));
  Check('the error names the address', Pos('00010000', R.ErrorText) > 0);
  //การกู้คืนล้มที่เซกเตอร์เดียวกัน (ตัวลบยังพัง) และผลบอกตามตรง
  Check('restoration is honestly reported as incomplete', not R.RestoredOK);
end;

procedure TestRefusals;
var
  R: TCapacityResult;
begin
  WriteLn('Refusals happen before anything is touched');
  FakeReset(1024 * 1024);
  Check('a non-power-of-two size is refused',
        not RunCapacityTest(1000000, SECTOR, @FakeRead, @FakeErase,
                            @FakeProgram, @QuietLog, R));
  Check('nothing was erased or written',
        (EraseCalls = 0) and (ProgramCalls = 0));
  Check('a size beyond any real SPI NOR is refused',
        not RunCapacityTest(QWord(512) * 1024 * 1024, SECTOR, @FakeRead,
                            @FakeErase, @FakeProgram, @QuietLog, R));
  Check('the reason names the 256 MB ceiling',
        Pos('256 MB', R.ErrorText) > 0);
end;

procedure TestBeyond16MB;
var
  Before: TBytes;
  R: TCapacityResult;
begin
  WriteLn('Chips beyond the 3-byte address space');
  FakeReset(QWord(32) * 1024 * 1024);
  Before := Copy(FakeMem, 0, Length(FakeMem));
  Check('a genuine 32 MB chip tests clean',
        RunCapacityTest(QWord(32) * 1024 * 1024, SECTOR, @FakeRead,
                        @FakeErase, @FakeProgram, @QuietLog, R) and
        R.Genuine and R.RestoredOK);
  Check('thirteen probes cover 32 MB', R.ProbeCount = 13);
  Check('its content survives', SnapshotEquals(Before));

  FakeReset(4 * 1024 * 1024);
  Before := Copy(FakeMem, 0, Length(FakeMem));
  Check('a 4 MB die remarked as 32 MB is exposed',
        RunCapacityTest(QWord(32) * 1024 * 1024, SECTOR, @FakeRead,
                        @FakeErase, @FakeProgram, @QuietLog, R) and
        (not R.Genuine) and (R.DetectedSize = 4 * 1024 * 1024));
  Check('the real die is restored', R.RestoredOK and SnapshotEquals(Before));
end;

var
  StopAfterBlocks: integer = -1; //-1 = ไม่หยุด

function SurfaceStop: boolean;
begin
  Result := StopAfterBlocks = 0;
  if StopAfterBlocks > 0 then Dec(StopAfterBlocks);
end;

procedure TestSurfaceScan;
var
  R: TSurfaceScanResult;
  i: SizeInt;
  AllFF: boolean;
begin
  WriteLn('Surface scan: pattern walk per block');
  FakeReset(64 * 1024);
  StopAfterBlocks := -1;
  Check('a clean chip scans clean',
        RunSurfaceScan(64 * 1024, SECTOR, @FakeRead, @FakeErase,
                       @FakeProgram, @QuietLog, nil, @SurfaceStop, R) and
        R.Completed and (R.BlocksTested = 16) and (R.BlocksBad = 0));
  AllFF := True;
  for i := 0 to High(FakeMem) do
    if FakeMem[i] <> $FF then AllFF := False;
  Check('the chip is left fully erased', AllFF);

  FakeReset(64 * 1024);
  StuckZeroAddr := 5 * SECTOR + 123; //บิตค้างศูนย์กลางบล็อกที่ห้า
  Check('a stuck bit does not stop the scan',
        RunSurfaceScan(64 * 1024, SECTOR, @FakeRead, @FakeErase,
                       @FakeProgram, @QuietLog, nil, @SurfaceStop, R) and
        R.Completed);
  Check('exactly one block is bad and it is named',
        (R.BlocksBad = 1) and R.HasFirstBad and
        (R.FirstBadAddr = 5 * SECTOR));
  Check('the other blocks still passed', R.BlocksTested = 16);

  FakeReset(64 * 1024);
  StopAfterBlocks := 3;
  Check('cancellation stops at a block boundary',
        not RunSurfaceScan(64 * 1024, SECTOR, @FakeRead, @FakeErase,
                           @FakeProgram, @QuietLog, nil, @SurfaceStop, R));
  Check('the run says cancelled after three blocks',
        R.Cancelled and (R.BlocksTested = 3));
  StopAfterBlocks := -1;

  FakeReset(64 * 1024);
  FailEraseAt := 2 * SECTOR;
  Check('a transport-level failure aborts the whole scan',
        not RunSurfaceScan(64 * 1024, SECTOR, @FakeRead, @FakeErase,
                           @FakeProgram, @QuietLog, nil, @SurfaceStop, R));
  Check('and is not blamed on the chip surface',
        (not R.Completed) and (R.BlocksBad = 0) and
        (Pos('erase at', R.ErrorText) > 0));
end;

procedure TestTiming;
var
  Median, Worst: cardinal;
  WorstIdx: integer;
begin
  WriteLn('Wear timing: median and outliers');
  Check('uniform timings have no outliers',
        (CountTimingOutliers([100, 101, 99, 100], 5, Median, Worst,
                             WorstIdx) = 0) and (Median = 100));
  Check('one dying block is flagged and named',
        (CountTimingOutliers([100, 100, 100, 900], 5, Median, Worst,
                             WorstIdx) = 1) and (WorstIdx = 3) and
        (Worst = 900));
  Check('an empty list decides nothing',
        CountTimingOutliers([], 5, Median, Worst, WorstIdx) = 0);
  Check('a zero median decides nothing',
        CountTimingOutliers([0, 0, 0, 50], 5, Median, Worst, WorstIdx) = 0);
end;

procedure TestCrossCheck;
var
  Detail: string;
begin
  WriteLn('ID cross-checks');
  Check('agreeing ids pass',
        CrossCheckIDs([$EF, $40, $17], True, [$EF, $16], True,
                      $16, True, [$EF, $17], True, Detail));
  Check('a manufacturer mismatch between 9F and 90 fails',
        not CrossCheckIDs([$EF, $40, $17], True, [$C8, $16], True,
                          $16, True, [], False, Detail));
  Check('and the detail names both bytes',
        (Pos('ef', LowerCase(Detail)) > 0) and
        (Pos('c8', LowerCase(Detail)) > 0));
  Check('an AB/90 device-id disagreement fails',
        not CrossCheckIDs([$EF, $40, $17], True, [$EF, $16], True,
                          $15, True, [], False, Detail));
  Check('a silent 90 answer is not a contradiction',
        CrossCheckIDs([$EF, $40, $17], True, [$FF, $FF], True,
                      $16, False, [], False, Detail));
  Check('no 9F means nothing to compare, not a failure',
        CrossCheckIDs([$FF, $FF, $FF], True, [$EF, $16], True,
                      $16, True, [], False, Detail));
end;

begin
  WriteLn('AsProgrammer chip capacity and identity tests');
  WriteLn;

  TestMarkers;
  TestGenuine;
  TestFake;
  TestFailingWrites;
  TestEraseDiesMidway;
  TestRefusals;
  TestBeyond16MB;
  TestSurfaceScan;
  TestTiming;
  TestCrossCheck;

  WriteLn;
  if Failures = 0 then
    WriteLn('ALL PASSED')
  else
    WriteLn(Failures, ' FAILURES');
  Halt(Failures);
end.
