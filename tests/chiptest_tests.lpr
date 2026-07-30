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
  Check('a chip above 16 MB is refused for now',
        not RunCapacityTest(QWord(32) * 1024 * 1024, SECTOR, @FakeRead,
                            @FakeErase, @FakeProgram, @QuietLog, R));
  Check('the reason is addressing', Pos('4-byte', R.ErrorText) > 0);
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
  TestCrossCheck;

  WriteLn;
  if Failures = 0 then
    WriteLn('ALL PASSED')
  else
    WriteLn(Failures, ' FAILURES');
  Halt(Failures);
end.
