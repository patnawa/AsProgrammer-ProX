unit chiptest;

// Chip health checks that answer "is this chip what it claims to be" --
// not "did this write land", which the ordinary verify already answers.
//
// The centrepiece is the capacity test. The commonest bad chip is not
// damaged, it is remarked: a 4 MB die lasered to read W25Q128, answering
// the 16 MB JEDEC id and wrapping every address above its real size. It
// accepts all commands, verifies every write (the readback wraps the same
// way the write did), and fails only in the field, when the upper half of
// an image quietly lands on top of the lower half. The one test that
// cannot be fooled is the one h2testw applies to fake USB sticks: write a
// distinct marker at every power-of-two boundary, then look where those
// markers actually ended up.
//
// Flash needs more care than a USB stick, because programming requires an
// erase first, and an erase at a wrapped address destroys real data at
// the aliased sector. So the engine backs up every sector it can possibly
// touch before the first erase, restores every one of them afterwards --
// in any order, which works because a backup read through an aliased
// address is by definition identical to the backup of the sector it
// aliases onto -- and verifies the restoration byte for byte. When the
// test itself fails midway, restoration of everything backed up is still
// attempted before the error is reported.
//
// The unit is pure: hardware access arrives as three callbacks, so the
// tests can run the engine against a fake chip whose real capacity is
// whatever the test says it is.

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

const
  CAPTEST_MARKER_LEN = 64;
  //เพดาน 2Gbit: ใหญ่สุดที่ SPI NOR จริงมีขาย ตัว callback ฝั่งฮาร์ดแวร์
  //จัดการเรื่องแอดเดรส 3/4 ไบต์เอง เครื่องทดสอบนี้คิดแต่เลขคณิต
  CAPTEST_MAX_SIZE = QWord(256) * 1024 * 1024;

type
  TChipTestLog = procedure(const Msg: string);

  //สัญญาของ callback: อ่าน/ลบ/เขียนที่แอดเดรสตรง ๆ ตัวลบจัดการ WREN และรอ
  //BUSY เองให้จบในตัว ตัวเขียนรับไม่เกินหนึ่งเพจ (256 ไบต์) ต่อครั้ง
  TChipIORead = function(Address: QWord; Len: cardinal; out Data: TBytes;
    out ErrorText: string): boolean;
  TChipIOErase = function(Address: QWord; out ErrorText: string): boolean;
  TChipIOProgram = function(Address: QWord; const Data: TBytes;
    out ErrorText: string): boolean;

  TCapacityResult = record
    ClaimedSize: QWord;
    DetectedSize: QWord;   //ศูนย์ = ยังไม่รู้ (งานล้มก่อนถึงขั้นอ่านผล)
    Genuine: boolean;      //Detected = Claimed และงานจบสมบูรณ์
    Completed: boolean;    //ทุกขั้นรวมทั้งการกู้คืนผ่านการตรวจแล้ว
    RestoredOK: boolean;   //ข้อมูลเดิมกลับไปครบและอ่านตรวจแล้วตรง
    ErrorText: string;
    ProbeCount: integer;
  end;

function RunCapacityTest(ClaimedSize: QWord; SectorSize: cardinal;
  ReadFn: TChipIORead; EraseFn: TChipIOErase; ProgramFn: TChipIOProgram;
  Log: TChipTestLog; out R: TCapacityResult): boolean;

//เครื่องหมายประจำแอดเดรส เปิดเป็น public เพื่อให้เทสต์ตรวจแยกแยะได้
function CapacityMarker(Address: QWord): TBytes;

type
  //ผลสแกนผิวทั้งชิป (ทำลายข้อมูล: จบงานแล้วชิปว่างทั้งตัว)
  TSurfaceScanResult = record
    BlocksTested: cardinal;
    BlocksBad: cardinal;
    FirstBadAddr: QWord;
    HasFirstBad: boolean;
    Completed: boolean;
    Cancelled: boolean;
    ErrorText: string;
    //บล็อกที่ลบช้าผิดฝูง (เกินห้าเท่าของมัธยฐาน) จากรอบลบแรก
    SlowBlocks: integer;
    SlowWorstMs, SlowMedianMs: cardinal;
    SlowWorstAddr: QWord;
  end;

  TSurfaceProgress = procedure(BlocksDone, BlocksTotal: cardinal);
  TSurfaceShouldStop = function: boolean;

//สแกนผิวแบบ badblocks: ต่อบล็อก ลบแล้วตรวจว่าว่างจริง เขียน 55h ตรวจ
//เขียน AAh ตรวจ เขียนลาย "แอดเดรสประทับในตัวเอง" ตรวจ แล้วลบทิ้ง
//บล็อกที่ผิดลายถูกนับและตั้งชื่อ แล้วสแกนต่อ (แผนที่ความเสียหายมีค่า
//กว่าการหยุดที่ศพแรก) ปัญหาระดับสายส่งถึงยกเลิกทั้งงาน
//
//สิ่งที่สแกนนี้ตั้งใจไม่ทำ: จับชิปปลอมย้อมความจุ (ตรวจทันทีต่อบล็อก
//มองไม่เห็นการวนแอดเดรส) นั่นคืองานของ RunCapacityTest
function RunSurfaceScan(ChipSize: QWord; SectorSize: cardinal;
  ReadFn: TChipIORead; EraseFn: TChipIOErase; ProgramFn: TChipIOProgram;
  Log: TChipTestLog; Progress: TSurfaceProgress;
  ShouldStop: TSurfaceShouldStop; out R: TSurfaceScanResult): boolean;

//แฟลชตายแบบช้าลงก่อนแล้วค่อยพัง: บล็อกที่ใช้เวลาลบ/เขียนนานผิดฝูงคือ
//บล็อกที่กำลังหมดอายุ ก่อนที่ verify จะเริ่มจับได้เสียอีก ตัวเลขพวกนี้
//ได้มาฟรีจากการรอ BUSY อยู่แล้ว เหลือแค่ดูให้เป็น
function TimingMedian(const Durations: array of cardinal): cardinal;

//นับตัวที่ช้ากว่ามัธยฐานเกิน Factor เท่า คืนจำนวน พร้อมชี้ตัวที่แย่สุด
function CountTimingOutliers(const Durations: array of cardinal;
  Factor: cardinal; out Median, Worst: cardinal;
  out WorstIndex: integer): integer;

//หมอตรวจชิป: รหัสจากโอปโค้ดต่างยุคต้องเล่าเรื่องเดียวกัน ชิปปลอมจำนวนมาก
//ทำการบ้านแค่ 9Fh แล้วปล่อยโอปโค้ดเก่าตอบมั่ว ค่าที่ไม่ตอบ (เงียบ/FF/00)
//ไม่นับว่าขัดแย้ง เพราะชิปแท้บางรุ่นก็ไม่รองรับโอปโค้ดเก่าจริง ๆ
function CrossCheckIDs(const ID9F: array of byte; Got9F: boolean;
  const ID90: array of byte; Got90: boolean;
  IDAB: byte; GotAB: boolean;
  const ID15: array of byte; Got15: boolean;
  out Detail: string): boolean;

implementation

function CapacityMarker(Address: QWord): TBytes;
const
  SIG: array[0..15] of byte =
    (byte('P'), byte('r'), byte('o'), byte('X'), byte('-'), byte('c'),
     byte('a'), byte('p'), byte('a'), byte('c'), byte('i'), byte('t'),
     byte('y'), byte('-'), byte('t'), byte('!'));
var
  i: integer;
begin
  Result := nil;
  SetLength(Result, CAPTEST_MARKER_LEN);
  for i := 0 to 15 do Result[i] := SIG[i];
  for i := 0 to 7 do Result[16 + i] := byte(Address shr (8 * i));
  for i := 0 to 7 do Result[24 + i] := byte(Address shr (8 * i)) xor $FF;
  //ที่เหลือถมด้วยลวดลายที่ขึ้นกับแอดเดรส กันการชนกันโดยบังเอิญ
  for i := 32 to CAPTEST_MARKER_LEN - 1 do
    Result[i] := byte((Address shr 12) * 31 + QWord(i) * 7 + 5);
end;

function SameBytes(const A, B: TBytes; Len: integer): boolean;
var
  i: integer;
begin
  Result := False;
  if (Length(A) < Len) or (Length(B) < Len) then Exit;
  for i := 0 to Len - 1 do
    if A[i] <> B[i] then Exit;
  Result := True;
end;

function IsPowerOfTwo(V: QWord): boolean;
begin
  Result := (V <> 0) and ((V and (V - 1)) = 0);
end;

function RunCapacityTest(ClaimedSize: QWord; SectorSize: cardinal;
  ReadFn: TChipIORead; EraseFn: TChipIOErase; ProgramFn: TChipIOProgram;
  Log: TChipTestLog; out R: TCapacityResult): boolean;
var
  Probes: array of QWord;       //แอดเดรสกำลังสอง ต่ำไปสูง
  Managed: array of QWord;      //[0] + Probes: ทุกเซกเตอร์ที่แตะได้
  Backups: array of TBytes;
  i, j: integer;
  P: QWord;
  Err: string;
  Data, Marker, Chunk: TBytes;
  Off: cardinal;
  RestoreFailed: boolean;

  procedure Say(const Msg: string);
  begin
    if Assigned(Log) then Log(Msg);
  end;

  //กู้ทุกเซกเตอร์ที่สำรองไว้ ลำดับไม่สำคัญ (ดูหัวไฟล์) แต่ต้องครบทุกตัว
  //และอ่านกลับมาตรวจ ให้ค่าคืนบอกว่ากู้สำเร็จหมดหรือไม่
  function RestoreAll: boolean;
  var
    k: integer;
    RErr: string;
    Back: TBytes;
  begin
    Result := True;
    for k := 0 to High(Managed) do
    begin
      if not EraseFn(Managed[k], RErr) then
      begin
        Say(Format('  restore: erase at 0x%.8x failed: %s',
                   [Managed[k], RErr]));
        Result := False;
        Continue;
      end;
      Off := 0;
      while Off < SectorSize do
      begin
        Chunk := nil;
        SetLength(Chunk, 256);
        Move(Backups[k][Off], Chunk[0], 256);
        if not ProgramFn(Managed[k] + Off, Chunk, RErr) then
        begin
          Say(Format('  restore: program at 0x%.8x failed: %s',
                     [Managed[k] + Off, RErr]));
          Result := False;
          Break;
        end;
        Inc(Off, 256);
      end;
      if not ReadFn(Managed[k], SectorSize, Back, RErr) then
      begin
        Say(Format('  restore: verify read at 0x%.8x failed: %s',
                   [Managed[k], RErr]));
        Result := False;
        Continue;
      end;
      if not SameBytes(Back, Backups[k], SectorSize) then
      begin
        Say(Format('  restore: sector 0x%.8x did not read back as its ' +
                   'backup', [Managed[k]]));
        Result := False;
      end;
    end;
  end;

  //อะไรอยู่ที่แอดเดรสนี้ตอนนี้: -1 ไม่ใช่เครื่องหมาย, ไม่งั้นดัชนีของ probe
  function MarkerIndexAt(const Bytes: TBytes): integer;
  var
    k: integer;
  begin
    Result := -1;
    for k := 0 to High(Probes) do
      if SameBytes(Bytes, CapacityMarker(Probes[k]), CAPTEST_MARKER_LEN) then
        Exit(k);
  end;

begin
  Result := False;
  R.ClaimedSize := ClaimedSize;
  R.DetectedSize := 0;
  R.Genuine := False;
  R.Completed := False;
  R.RestoredOK := False;
  R.ErrorText := '';
  R.ProbeCount := 0;

  if (not Assigned(ReadFn)) or (not Assigned(EraseFn)) or
     (not Assigned(ProgramFn)) then
  begin
    R.ErrorText := 'no device callbacks';
    Exit;
  end;
  if not IsPowerOfTwo(ClaimedSize) then
  begin
    R.ErrorText := 'the declared chip size is not a power of two; ' +
                   'the wrap arithmetic of this test needs one';
    Exit;
  end;
  if ClaimedSize > CAPTEST_MAX_SIZE then
  begin
    R.ErrorText := 'no real SPI NOR is larger than 256 MB; a declared ' +
                   'size above that is a configuration mistake';
    Exit;
  end;
  if (SectorSize = 0) or (not IsPowerOfTwo(SectorSize)) or
     (ClaimedSize < QWord(SectorSize) * 2) then
  begin
    R.ErrorText := 'the sector size does not fit this test';
    Exit;
  end;

  //จุดเจาะ: ทุกกำลังสองตั้งแต่หนึ่งเซกเตอร์จนถึงครึ่งหนึ่งของขนาดที่อ้าง
  Probes := nil;
  P := SectorSize;
  while P < ClaimedSize do
  begin
    SetLength(Probes, Length(Probes) + 1);
    Probes[High(Probes)] := P;
    P := P * 2;
  end;
  R.ProbeCount := Length(Probes);

  SetLength(Managed, Length(Probes) + 1);
  Managed[0] := 0;
  for i := 0 to High(Probes) do Managed[i + 1] := Probes[i];

  //ขั้นสำรอง: อ่านทุกเซกเตอร์ที่อาจถูกแตะ ก่อนจะลบอะไรทั้งสิ้น
  Say(Format('backing up %d sectors before touching anything',
             [Length(Managed)]));
  SetLength(Backups, Length(Managed));
  for i := 0 to High(Managed) do
    if not ReadFn(Managed[i], SectorSize, Backups[i], Err) then
    begin
      R.ErrorText := Format('backup read at 0x%.8x failed: %s',
                            [Managed[i], Err]);
      Exit; //ยังไม่ได้ลบอะไร ไม่ต้องกู้
    end;

  //ขั้นเขียน: เครื่องหมายประจำแอดเดรส จากต่ำไปสูง ชิปปลอมจะพาการลบและ
  //การเขียนของแอดเดรสสูงวนกลับมาทับของต่ำ ซึ่งคือหลักฐานที่เราตามหา
  Say(Format('writing %d markers at power-of-two boundaries',
             [Length(Probes)]));
  for i := 0 to High(Probes) do
  begin
    if not EraseFn(Probes[i], Err) then
    begin
      R.ErrorText := Format('erase at 0x%.8x failed: %s', [Probes[i], Err]);
      R.RestoredOK := RestoreAll;
      Exit;
    end;
    Marker := CapacityMarker(Probes[i]);
    if not ProgramFn(Probes[i], Marker, Err) then
    begin
      R.ErrorText := Format('marker write at 0x%.8x failed: %s',
                            [Probes[i], Err]);
      R.RestoredOK := RestoreAll;
      Exit;
    end;
  end;

  //ขั้นอ่านผล: แอดเดรสแรกที่ถือเครื่องหมายของคนอื่นคือความจุจริง
  R.DetectedSize := ClaimedSize;
  for i := 0 to High(Probes) do
  begin
    if not ReadFn(Probes[i], CAPTEST_MARKER_LEN, Data, Err) then
    begin
      R.ErrorText := Format('result read at 0x%.8x failed: %s',
                            [Probes[i], Err]);
      R.DetectedSize := 0;
      R.RestoredOK := RestoreAll;
      Exit;
    end;
    j := MarkerIndexAt(Data);
    if j = i then Continue;              //เครื่องหมายของตัวเอง ตามคาด
    if j > i then
    begin
      //ของคนที่สูงกว่ามาโผล่ที่นี่: แอดเดรสวน ความจุจริงคือแอดเดรสนี้เอง
      R.DetectedSize := Probes[i];
      Say(Format('address 0x%.8x holds the marker written to 0x%.8x: ' +
                 'the address wrapped', [Probes[i], Probes[j]]));
      Break;
    end;
    //ไม่ใช่เครื่องหมายของใครเลย: ชิปเก็บข้อมูลไม่อยู่ นั่นคนละโรคกับปลอม
    R.ErrorText := Format('the marker at 0x%.8x did not read back as any ' +
      'marker at all; the chip is failing writes, which is a different ' +
      'disease than a remarked capacity', [Probes[i]]);
    R.DetectedSize := 0;
    R.RestoredOK := RestoreAll;
    Exit;
  end;

  //ขั้นกู้คืน: ทุกอย่างกลับที่เดิม แล้วอ่านตรวจทุกไบต์
  Say('restoring the backed-up sectors');
  RestoreFailed := not RestoreAll;
  R.RestoredOK := not RestoreFailed;
  if RestoreFailed then
  begin
    R.ErrorText := 'the test finished but restoring the original data did ' +
                   'not verify everywhere; check the sectors named above';
    Exit;
  end;

  R.Completed := True;
  R.Genuine := R.DetectedSize = ClaimedSize;
  Result := True;
end;

function RunSurfaceScan(ChipSize: QWord; SectorSize: cardinal;
  ReadFn: TChipIORead; EraseFn: TChipIOErase; ProgramFn: TChipIOProgram;
  Log: TChipTestLog; Progress: TSurfaceProgress;
  ShouldStop: TSurfaceShouldStop; out R: TSurfaceScanResult): boolean;
var
  Blocks, B: cardinal;
  Base: QWord;
  Err: string;
  EraseMs: array of cardinal;
  T0: QWord;
  WorstIdx: integer;
  BlockBad: boolean;

  procedure Say(const Msg: string);
  begin
    if Assigned(Log) then Log(Msg);
  end;

  //ลายประจำรอบ: Fill = ค่าคงที่, ประทับแอดเดรส = ทุก dword เก็บแอดเดรส
  //ของตัวเอง (จับสายแอดเดรสพัง/ลัดที่ลายทึบมองไม่เห็น)
  function PatternByte(UseStamp: boolean; Fill: byte; Addr: QWord): byte;
  begin
    if not UseStamp then Exit(Fill);
    Result := byte((Addr and (not QWord(3))) shr ((Addr and 3) * 8));
  end;

  //เขียนทั้งบล็อกด้วยลายที่ขอ แล้วอ่านกลับเทียบทุกไบต์
  //คืน False เฉพาะปัญหาระดับสายส่ง ผลลายผิดรายงานผ่าน BadOut
  function WriteAndCheck(UseStamp: boolean; Fill: byte;
    out BadOut: boolean): boolean;
  var
    Off, i: cardinal;
    Chunk, Back: TBytes;
  begin
    Result := False;
    BadOut := False;
    Chunk := nil;
    SetLength(Chunk, 256);
    Off := 0;
    while Off < SectorSize do
    begin
      for i := 0 to 255 do
        Chunk[i] := PatternByte(UseStamp, Fill, Base + Off + i);
      if not ProgramFn(Base + Off, Chunk, Err) then
      begin
        R.ErrorText := Format('program at 0x%.8x failed: %s',
                              [Base + Off, Err]);
        Exit;
      end;
      Inc(Off, 256);
    end;
    if not ReadFn(Base, SectorSize, Back, Err) then
    begin
      R.ErrorText := Format('readback at 0x%.8x failed: %s', [Base, Err]);
      Exit;
    end;
    for i := 0 to SectorSize - 1 do
      if Back[i] <> PatternByte(UseStamp, Fill, Base + i) then
      begin
        BadOut := True;
        Break;
      end;
    Result := True;
  end;

  function EraseAndCheckBlank(TimeIt: boolean; out BadOut: boolean): boolean;
  var
    i: cardinal;
    Back: TBytes;
  begin
    Result := False;
    BadOut := False;
    T0 := GetTickCount64;
    if not EraseFn(Base, Err) then
    begin
      R.ErrorText := Format('erase at 0x%.8x failed: %s', [Base, Err]);
      Exit;
    end;
    if TimeIt then EraseMs[B] := cardinal(GetTickCount64 - T0);
    if not ReadFn(Base, SectorSize, Back, Err) then
    begin
      R.ErrorText := Format('blank readback at 0x%.8x failed: %s',
                            [Base, Err]);
      Exit;
    end;
    for i := 0 to SectorSize - 1 do
      if Back[i] <> $FF then
      begin
        BadOut := True;
        Break;
      end;
    Result := True;
  end;

  //หนึ่งบล็อกเต็มรอบ: ว่างจริง, 55h, AAh, ลายประทับแอดเดรส, แล้วลบทิ้ง
  function TestOneBlock(out BadOut: boolean): boolean;
  var
    Bad1: boolean;
  begin
    Result := False;
    BadOut := False;
    if not EraseAndCheckBlank(True, Bad1) then Exit;
    BadOut := BadOut or Bad1;
    if not WriteAndCheck(False, $55, Bad1) then Exit;
    BadOut := BadOut or Bad1;
    if not EraseAndCheckBlank(False, Bad1) then Exit;
    BadOut := BadOut or Bad1;
    if not WriteAndCheck(False, $AA, Bad1) then Exit;
    BadOut := BadOut or Bad1;
    if not EraseAndCheckBlank(False, Bad1) then Exit;
    BadOut := BadOut or Bad1;
    if not WriteAndCheck(True, 0, Bad1) then Exit;
    BadOut := BadOut or Bad1;
    if not EraseAndCheckBlank(False, Bad1) then Exit;
    BadOut := BadOut or Bad1;
    Result := True;
  end;

begin
  Result := False;
  R.BlocksTested := 0;
  R.BlocksBad := 0;
  R.FirstBadAddr := 0;
  R.HasFirstBad := False;
  R.Completed := False;
  R.Cancelled := False;
  R.ErrorText := '';
  R.SlowBlocks := 0;
  R.SlowWorstMs := 0;
  R.SlowMedianMs := 0;
  R.SlowWorstAddr := 0;

  if (not Assigned(ReadFn)) or (not Assigned(EraseFn)) or
     (not Assigned(ProgramFn)) then
  begin
    R.ErrorText := 'no device callbacks';
    Exit;
  end;
  if (SectorSize = 0) or ((SectorSize mod 256) <> 0) or
     (ChipSize = 0) or ((ChipSize mod SectorSize) <> 0) then
  begin
    R.ErrorText := 'the chip/sector geometry does not fit this scan';
    Exit;
  end;
  if ChipSize > CAPTEST_MAX_SIZE then
  begin
    R.ErrorText := 'no real SPI NOR is larger than 256 MB; a declared ' +
                   'size above that is a configuration mistake';
    Exit;
  end;

  Blocks := cardinal(ChipSize div SectorSize);
  EraseMs := nil;
  SetLength(EraseMs, Blocks);
  Say(Format('surface scan: %d blocks of %d bytes; every cell will be ' +
             'exercised and the chip ends fully erased', [Blocks,
             SectorSize]));

  B := 0;
  while B < Blocks do
  begin
    if Assigned(ShouldStop) and ShouldStop() then
    begin
      R.Cancelled := True;
      R.ErrorText := 'cancelled';
      Exit;
    end;

    Base := QWord(B) * SectorSize;
    if not TestOneBlock(BlockBad) then Exit; //ปัญหาสายส่ง: เลิกทั้งงาน
    Inc(R.BlocksTested);
    if BlockBad then
    begin
      Inc(R.BlocksBad);
      if not R.HasFirstBad then
      begin
        R.HasFirstBad := True;
        R.FirstBadAddr := Base;
      end;
      Say(Format('  BAD block at 0x%.8x', [Base]));
    end;
    if Assigned(Progress) then Progress(B + 1, Blocks);
    Inc(B);
  end;

  R.SlowBlocks := CountTimingOutliers(EraseMs, 5, R.SlowMedianMs,
                                      R.SlowWorstMs, WorstIdx);
  if WorstIdx >= 0 then
    R.SlowWorstAddr := QWord(WorstIdx) * SectorSize;

  R.Completed := True;
  Result := True;
end;

function TimingMedian(const Durations: array of cardinal): cardinal;
var
  Sorted: array of cardinal;
  i, j: integer;
  T: cardinal;
begin
  Result := 0;
  if Length(Durations) = 0 then Exit;
  Sorted := nil;
  SetLength(Sorted, Length(Durations));
  for i := 0 to High(Durations) do Sorted[i] := Durations[i];
  //insertion sort ก็พอ: จำนวนบล็อกต่องานอยู่หลักพันอย่างมาก
  for i := 1 to High(Sorted) do
  begin
    T := Sorted[i];
    j := i - 1;
    while (j >= 0) and (Sorted[j] > T) do
    begin
      Sorted[j + 1] := Sorted[j];
      Dec(j);
    end;
    Sorted[j + 1] := T;
  end;
  Result := Sorted[Length(Sorted) div 2];
end;

function CountTimingOutliers(const Durations: array of cardinal;
  Factor: cardinal; out Median, Worst: cardinal;
  out WorstIndex: integer): integer;
var
  i: integer;
begin
  Result := 0;
  Worst := 0;
  WorstIndex := -1;
  Median := TimingMedian(Durations);
  if (Median = 0) or (Factor = 0) then Exit;
  for i := 0 to High(Durations) do
  begin
    if Durations[i] > QWord(Median) * Factor then Inc(Result);
    if Durations[i] > Worst then
    begin
      Worst := Durations[i];
      WorstIndex := i;
    end;
  end;
end;

function CrossCheckIDs(const ID9F: array of byte; Got9F: boolean;
  const ID90: array of byte; Got90: boolean;
  IDAB: byte; GotAB: boolean;
  const ID15: array of byte; Got15: boolean;
  out Detail: string): boolean;

  function Silent(B: byte): boolean;
  begin
    Result := (B = $00) or (B = $FF);
  end;

begin
  Result := True;
  Detail := '';

  if (not Got9F) or (Length(ID9F) < 3) or Silent(ID9F[0]) then
  begin
    //ไม่มี 9F ก็ไม่มีหลักให้เทียบ ปล่อยให้ด่านตรวจชิปหลักจัดการเรื่องนั้น
    Detail := 'no usable 9F id to compare against';
    Exit;
  end;

  if Got90 and (Length(ID90) >= 2) and (not Silent(ID90[0])) and
     (ID90[0] <> ID9F[0]) then
  begin
    Result := False;
    Detail := Format('9Fh says manufacturer %.2x but 90h says %.2x; a ' +
      'genuine part tells one story across its id opcodes',
      [ID9F[0], ID90[0]]);
    Exit;
  end;

  if Got15 and (Length(ID15) >= 1) and (not Silent(ID15[0])) and
     (ID15[0] <> ID9F[0]) then
  begin
    Result := False;
    Detail := Format('9Fh says manufacturer %.2x but 15h says %.2x',
                     [ID9F[0], ID15[0]]);
    Exit;
  end;

  if GotAB and Got90 and (Length(ID90) >= 2) and
     (not Silent(IDAB)) and (not Silent(ID90[1])) and
     (IDAB <> ID90[1]) then
  begin
    Result := False;
    Detail := Format('the legacy device id differs between ABh (%.2x) ' +
      'and 90h (%.2x)', [IDAB, ID90[1]]);
    Exit;
  end;

  Detail := 'the id opcodes that answered agree with each other';
end;

end.
