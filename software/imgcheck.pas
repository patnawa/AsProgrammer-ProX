unit imgcheck;

//ตรวจตัวข้อมูลที่อ่านมาได้ ไม่ใช่ตรวจว่าการรับส่งสำเร็จ
//
//การอ่านที่ "สำเร็จ" ทุกไบต์แต่ได้ข้อมูลผิดเป็นความล้มเหลวที่เงียบที่สุด
//ที่เครื่องโปรแกรมทำได้ และมันเกิดบ่อยมากกับคลิปหนีบ SOIC สองแบบที่พบเสมอคือ
//
//  ทั้งก้อนเป็น FF   ชิปไม่ได้รับไฟ คลิปหนีบไม่ติด หรือหนีบกลับด้าน
//  ก้อนซ้ำตัวเอง     เลือกขนาดชิปใหญ่กว่าของจริง แอดเดรสจึงวนกลับ
//                    ไฟล์ที่ได้ดูสมบูรณ์ทุกประการและใช้ไม่ได้เลย
//
//ทั้งสองอย่างตรวจได้ด้วยการไล่บัฟเฟอร์รอบเดียว หน่วยนี้ไม่พึ่ง LCL และ
//ไม่แตะฮาร์ดแวร์ ทุกอย่างเป็นฟังก์ชันล้วน

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Math;

type

  TImgStats = record
    Size: cardinal;
    FFCount: cardinal;         //จำนวนไบต์ที่เป็น FF
    ZeroCount: cardinal;       //จำนวนไบต์ที่เป็น 00
    DistinctBytes: integer;    //จำนวนค่าไบต์ที่ต่างกันที่พบ 1..256
    RepeatStride: cardinal;    //ก้อนซ้ำทุกกี่ไบต์ 0 = ไม่ซ้ำ
    Entropy: double;           //บิตต่อไบต์ 0..8
  end;

  TImgVerdict = (
    ivOK,
    ivAllErased,     //ทั้งก้อนเป็น FF
    ivAllZero,       //ทั้งก้อนเป็น 00
    ivUniform,       //ทั้งก้อนเป็นไบต์เดียวกันซ้ำ ๆ ที่ไม่ใช่ FF หรือ 00
    ivRepeats        //ก้อนซ้ำตัวเอง แอดเดรสน่าจะวนกลับ
  );

  //ช่วงที่สองบัฟเฟอร์ไม่ตรงกัน
  TDiffRange = record
    First: cardinal;
    Last: cardinal;
  end;
  TDiffRanges = array of TDiffRange;

//ไล่บัฟเฟอร์รอบเดียวแล้วเก็บสถิติ
function ScanImage(Buf: PByte; Size: cardinal): TImgStats;

//สรุปว่าก้อนนี้น่าเชื่อถือหรือไม่
function ImageVerdict(const S: TImgStats): TImgVerdict;

//คำอธิบายที่เอาไปขึ้น log ได้ตรง ๆ
function VerdictText(V: TImgVerdict; const S: TImgStats): string;

//สรุปสถิติหนึ่งบรรทัด
function StatsText(const S: TImgStats): string;

//ชนิดของภาพเท่าที่เดาได้จากลายเซ็นที่รู้จัก คืนสตริงว่างเมื่อเดาไม่ออก
//
//เป็นข้อมูลประกอบเท่านั้น ไม่ใช่การตัดสิน ภาพที่เดาชนิดไม่ออกไม่ได้แปลว่าเสีย
function DetectImageKind(Buf: PByte; Size: cardinal): string;

//ตำแหน่งแรกที่ไม่ตรงกัน คืน -1 เมื่อตรงกันทั้งหมด
function FirstDifference(A, B: PByte; Size: cardinal): int64;

//จำนวนไบต์ที่ไม่ตรงกัน
function CountDifferences(A, B: PByte; Size: cardinal): cardinal;

//ช่วงที่ไม่ตรงกัน รวมไบต์ที่ติดกันเป็นช่วงเดียว
//หยุดเก็บเมื่อครบ MaxRanges เพราะรายงานที่ยาวเป็นล้านบรรทัดไม่มีใครอ่าน
function DiffRanges(A, B: PByte; Size: cardinal; MaxRanges: integer): TDiffRanges;

implementation

function ScanImage(Buf: PByte; Size: cardinal): TImgStats;
var
  Hist: array[0..255] of cardinal;
  i: cardinal;
  v: integer;
  P: double;
  Stride: cardinal;
  Same: boolean;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Size := Size;
  if (Buf = nil) or (Size = 0) then Exit;

  FillChar(Hist, SizeOf(Hist), 0);
  for i := 0 to Size - 1 do
    Inc(Hist[Buf[i]]);

  Result.FFCount   := Hist[$FF];
  Result.ZeroCount := Hist[$00];

  for v := 0 to 255 do
    if Hist[v] > 0 then
    begin
      Inc(Result.DistinctBytes);
      P := Hist[v] / Size;
      Result.Entropy := Result.Entropy - P * Log2(P);
    end;

  //หาก้อนซ้ำ ลองเฉพาะระยะที่เป็นกำลังสอง เพราะแอดเดรสที่วนกลับเกิดจากการ
  //ส่งบิตแอดเดรสไปไม่ครบ ระยะซ้ำจึงเป็นกำลังสองเสมอ ไล่จากเล็กไปใหญ่แล้ว
  //หยุดที่เจอครั้งแรก จะได้ระยะที่สั้นที่สุดซึ่งเป็นระยะจริง
  //เพดานคือ Size div 2 ระยะซ้ำที่ใหญ่กว่านั้นหารภาพไม่ลงตัวอยู่แล้ว และการคูณ
  //สองไปเรื่อย ๆ บนภาพที่ใหญ่กว่า 2 GiB จะล้น cardinal เป็นศูนย์แล้วหารด้วยศูนย์
  Stride := 256;
  while (Stride <= Size div 2) do
  begin
    if (Size mod Stride) = 0 then
    begin
      Same := True;
      i := Stride;
      while i < Size do
      begin
        if Buf[i] <> Buf[i - Stride] then
        begin
          Same := False;
          Break;
        end;
        Inc(i);
      end;
      if Same then
      begin
        Result.RepeatStride := Stride;
        Break;
      end;
    end;
    Stride := Stride * 2;
  end;
end;

function ImageVerdict(const S: TImgStats): TImgVerdict;
begin
  Result := ivOK;
  if S.Size = 0 then Exit;

  if S.FFCount = S.Size then Exit(ivAllErased);
  if S.ZeroCount = S.Size then Exit(ivAllZero);
  if S.DistinctBytes = 1 then Exit(ivUniform);
  if S.RepeatStride > 0 then Exit(ivRepeats);
end;

function StatsText(const S: TImgStats): string;
begin
  if S.Size = 0 then Exit('empty buffer');

  Result := Format('%d bytes, %d distinct values, %.2f bits/byte, ' +
                   'FF %.1f%%, 00 %.1f%%',
                   [S.Size, S.DistinctBytes, S.Entropy,
                    S.FFCount * 100.0 / S.Size,
                    S.ZeroCount * 100.0 / S.Size]);
end;

function VerdictText(V: TImgVerdict; const S: TImgStats): string;
begin
  case V of
    ivAllErased:
      Result := 'every byte is FF: the chip is blank, or it never answered ' +
                '(no power, clip not seated, or fitted backwards)';
    ivAllZero:
      Result := 'every byte is 00: the chip did not drive the data line';
    ivUniform:
      Result := 'the whole dump is one repeated byte value, which no real ' +
                'image looks like';
    ivRepeats:
      Result := Format('the dump repeats every %d bytes, so the address ' +
                       'wrapped: the selected chip size (%d) is larger than ' +
                       'the part actually in the socket',
                       [S.RepeatStride, S.Size]);
  else
    Result := '';
  end;
end;

//อ่าน dword แบบ little endian โดยไม่หลุดขอบบัฟเฟอร์
function PeekDword(Buf: PByte; Size, Offset: cardinal; out V: cardinal): boolean;
begin
  V := 0;
  if (Buf = nil) or (int64(Offset) + 4 > int64(Size)) then Exit(False);
  V := cardinal(Buf[Offset]) or (cardinal(Buf[Offset+1]) shl 8) or
       (cardinal(Buf[Offset+2]) shl 16) or (cardinal(Buf[Offset+3]) shl 24);
  Result := True;
end;

function Match4(Buf: PByte; Size, Offset: cardinal; const Sig: string): boolean;
var
  i: integer;
begin
  Result := False;
  if int64(Offset) + Length(Sig) > int64(Size) then Exit;
  for i := 1 to Length(Sig) do
    if Buf[Offset + cardinal(i) - 1] <> byte(Sig[i]) then Exit;
  Result := True;
end;

function DetectImageKind(Buf: PByte; Size: cardinal): string;
var
  V, Off: cardinal;
begin
  Result := '';
  if (Buf = nil) or (Size < 512) then Exit;

  //Intel flash descriptor: ลายเซ็น 0FF0A55Ah ที่ออฟเซ็ต 10h
  if PeekDword(Buf, Size, $10, V) and (V = $0FF0A55A) then
    Exit('Intel flash descriptor');

  //UEFI firmware volume: ลายเซ็น _FVH อยู่ที่ออฟเซ็ต 28h ของหัว volume
  //หัว volume วางอยู่ตรงขอบบล็อก จึงมองทีละ 64K พอ
  Off := 0;
  while Off + $30 < Size do
  begin
    if Match4(Buf, Size, Off + $28, '_FVH') then Exit('UEFI firmware volume');
    Inc(Off, $10000);
  end;

  //coreboot เก็บสารบัญไว้เป็น LARCHIVE ตรงขอบ 64 ไบต์
  Off := 0;
  while Off + 8 < Size do
  begin
    if Match4(Buf, Size, Off, 'LARCHIVE') then Exit('coreboot image');
    Inc(Off, 64);
  end;

  //ตารางพาร์ทิชันของ PC ลงท้ายเซกเตอร์แรกด้วย 55 AA
  if (Size >= 512) and (Buf[510] = $55) and (Buf[511] = $AA) then
    Exit('boot sector or legacy BIOS image');
end;

function FirstDifference(A, B: PByte; Size: cardinal): int64;
var
  i: cardinal;
begin
  Result := -1;
  if (A = nil) or (B = nil) or (Size = 0) then Exit;
  for i := 0 to Size - 1 do
    if A[i] <> B[i] then Exit(int64(i));
end;

function CountDifferences(A, B: PByte; Size: cardinal): cardinal;
var
  i: cardinal;
begin
  Result := 0;
  if (A = nil) or (B = nil) or (Size = 0) then Exit;
  for i := 0 to Size - 1 do
    if A[i] <> B[i] then Inc(Result);
end;

function DiffRanges(A, B: PByte; Size: cardinal; MaxRanges: integer): TDiffRanges;
var
  i: cardinal;
  InRange: boolean;
  Count: integer;
begin
  Result := nil;
  if (A = nil) or (B = nil) or (Size = 0) or (MaxRanges <= 0) then Exit;

  InRange := False;
  Count := 0;

  for i := 0 to Size - 1 do
  begin
    if A[i] <> B[i] then
    begin
      if not InRange then
      begin
        if Count >= MaxRanges then Exit;
        SetLength(Result, Count + 1);
        Result[Count].First := i;
        Result[Count].Last := i;
        InRange := True;
      end
      else
        Result[Count].Last := i;
    end
    else if InRange then
    begin
      InRange := False;
      Inc(Count);
    end;
  end;
end;

end.
