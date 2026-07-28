unit flashops;

//การวางแผนงานเขียนและงานลบ แยกออกมาจากหน้าจอ
//
//หน่วยนี้ไม่พึ่ง LCL และไม่พึ่ง main โดยตั้งใจ แบบเดียวกับ spi25
//เหตุผลคือบั๊กที่ทำให้ชิปพังไม่ได้อยู่ในลูปรับส่งข้อมูล แต่อยู่ในเลขคณิต
//ของแอดเดรส ว่าจะลบเซกเตอร์ไหน จะเขียนกี่ไบต์ ก่อนถึงขอบเพจถัดไป
//ตราบใดที่เลขพวกนี้ยังคำนวณอยู่ในฟอร์ม ก็เอามาทดสอบไม่ได้เลย
//
//ทุกอย่างในนี้เป็นฟังก์ชันล้วน ไม่แตะฮาร์ดแวร์ ไม่แตะหน้าจอ

{$mode objfpc}{$H+}

interface

uses
  SysUtils, sfdp;

type

  //หนึ่งคำสั่งลบ
  TEraseStep = record
    Addr: cardinal;
    Size: cardinal;
    Opcode: byte;      //ชุดคำสั่งแอดเดรส 3 ไบต์
    Opcode4B: byte;    //ชุดคำสั่งแอดเดรส 4 ไบต์ตัวจริง 0 = ชิปไม่มี
  end;

  TErasePlan = array of TEraseStep;

//แอดเดรสเกิน 3 ไบต์หรือไม่ ชิปที่ใหญ่กว่า 128Mbit ต้องใช้แอดเดรส 4 ไบต์
const
  ADDR_3BYTE_LIMIT = 16777216;   //16MB คือทั้งหมดที่แอดเดรส 3 ไบต์เข้าถึงได้

//งานนี้ต้องใช้แอดเดรส 4 ไบต์หรือไม่
//
//ตัวตัดสินคือแอดเดรสสูงสุดที่จะถูกแตะ ไม่ใช่จำนวนไบต์ที่จะถูกแตะ
//สองอย่างนี้เท่ากันเฉพาะตอนที่งานเริ่มจากแอดเดรสศูนย์เท่านั้น
//
//เดิมทางเขียนกับทางตรวจตัดสินจากความยาวของบัฟเฟอร์ ผลคือการเขียนภาพ 4MB
//ลงชิป 32MB ที่แอดเดรส 16MB ถูกส่งด้วยแอดเดรส 3 ไบต์ ซึ่งเก็บ 16MB ไม่ได้
//แอดเดรสจึงวนกลับไปที่ 0 แล้วข้อมูลไปทับบล็อกแรกของชิปแทน
//และรอบตรวจก็ตัดสินผิดแบบเดียวกัน จึงไปอ่านที่ 0 มาเทียบแล้วรายงานว่าผ่าน
//
//ChipSize เป็นตัวตัดสินหลัก เพื่อให้ทางอ่าน ทางเขียน ทางลบ และทางตรวจ
//ใช้โหมดแอดเดรสเดียวกันเสมอบนชิปตัวเดียวกัน ชิปที่ถูกสลับเข้าโหมด 4 ไบต์
//แล้วไม่เข้าใจคำสั่งที่มีแอดเดรส 3 ไบต์อีกต่อไป
function Needs4ByteAddress(StartAddress, RangeLen, ChipSize: cardinal): boolean;

//จำนวนไบต์ที่เขียนได้จนถึงขอบเพจถัดไป
//
//ชิปตระกูล 25 จะวนแอดเดรสกลับไปต้นเพจเมื่อเขียนเลยขอบเพจ ไบต์ที่ล้นออกไป
//จึงไปทับต้นเพจเดิมแทนที่จะไปต่อเพจถัดไป การเขียนก้อนแรกต้องสั้นลงพอดี
//ให้จบตรงขอบเพจ หลังจากนั้นทุกก้อนจึงเต็มเพจได้
//
//แอดเดรสที่ตรงขอบเพจอยู่แล้วเขียนได้เต็มเพจ ต้องคืน PageSize ไม่ใช่ 0
function FirstChunkSize(StartAddress: cardinal; PageSize: word): word;

//ปัดช่วงที่ขอมาให้ตรงขอบเซกเตอร์ เพราะลบครึ่งเซกเตอร์ไม่ได้
//ปัดจุดเริ่มลง ปัดจุดจบขึ้น แล้วตัดไม่ให้เลยขนาดชิป
//FromAddr คือไบต์แรกที่จะถูกลบ ToAddr คือไบต์ถัดจากไบต์สุดท้าย
function AlignEraseRange(StartAddress, RangeLen, SectorSize, ChipSize: cardinal;
  out FromAddr, ToAddr: cardinal): boolean;

//แผนการลบแบบเซกเตอร์ขนาดเดียวทั้งชิป ซึ่งเป็นพฤติกรรมเดิม
function PlanEraseUniform(StartAddress, RangeLen, SectorSize, ChipSize: cardinal;
  Opcode: byte; out Plan: TErasePlan): boolean;

//แผนการลบที่เดินตามแผนผังเซกเตอร์ของ SFDP
//
//ได้สองอย่างที่แบบขนาดเดียวให้ไม่ได้
//  ถูกต้อง  ชิปที่มีบล็อกหัวหรือท้ายขนาดไม่เท่ากันจะถูกลบตามขนาดจริงของช่วงนั้น
//  เร็ว     ช่วงที่ยาวพอจะใช้ opcode ก้อนใหญ่ที่สุดที่ยังอยู่ในช่วงที่ขอ
//           ลบ 8MB ด้วยบล็อก 64K ใช้คำสั่งน้อยกว่าเซกเตอร์ 4K อยู่สิบหกเท่า
//
//คืน False เมื่อชิปไม่มีแผนผัง ผู้เรียกต้องถอยไปใช้ PlanEraseUniform
function PlanEraseSFDP(const Info: TSFDPInfo; StartAddress, RangeLen, ChipSize: cardinal;
  out Plan: TErasePlan): boolean;

//จำนวนไบต์รวมที่แผนนี้จะลบ
function PlanTotalBytes(const Plan: TErasePlan): cardinal;

//ช่วงที่แผนนี้ครอบคลุม ใช้บอกผู้ใช้ว่าจะแตะไปถึงไหนจริง ๆ
function PlanBounds(const Plan: TErasePlan; out FromAddr, ToAddr: cardinal): boolean;

//ทุกขั้นในแผนมี opcode ชุดแอดเดรส 4 ไบต์ของตัวเองครบหรือไม่
//
//ถ้าครบก็ลบได้โดยไม่ต้องสลับโหมดเลย ซึ่งปลอดภัยกว่า เพราะการสลับโหมด
//ทิ้งสถานะไว้ในตัวชิป ถ้างานล้มกลางคันชิปจะค้างอยู่ที่โหมด 4 ไบต์
function PlanAllHave4B(const Plan: TErasePlan): boolean;

implementation

function Needs4ByteAddress(StartAddress, RangeLen, ChipSize: cardinal): boolean;
begin
  //ชิปใหญ่ทั้งตัวใช้โหมด 4 ไบต์ ไม่ว่างานนี้จะแตะแค่ไหนก็ตาม
  if ChipSize > ADDR_3BYTE_LIMIT then Exit(True);

  //ชิปเล็กแต่ช่วงที่ขอเลยขอบ 3 ไบต์ ก็ยังต้องใช้ 4 ไบต์อยู่ดี
  //บวกด้วย int64 เพราะผลรวมล้น cardinal ได้
  Result := (int64(StartAddress) + int64(RangeLen)) > ADDR_3BYTE_LIMIT;
end;

function FirstChunkSize(StartAddress: cardinal; PageSize: word): word;
var
  Offset: cardinal;
begin
  if PageSize = 0 then Exit(0);

  Offset := StartAddress mod PageSize;
  if Offset = 0 then
    Result := PageSize
  else
    Result := PageSize - Offset;
end;

function AlignEraseRange(StartAddress, RangeLen, SectorSize, ChipSize: cardinal;
  out FromAddr, ToAddr: cardinal): boolean;
var
  EndAddr: int64;
begin
  FromAddr := 0;
  ToAddr := 0;
  Result := False;

  if (SectorSize = 0) or (RangeLen = 0) or (ChipSize = 0) then Exit;
  if StartAddress >= ChipSize then Exit;

  //บวกด้วย int64 เพราะ StartAddress + RangeLen ล้น cardinal ได้
  //ถ้าผู้ใช้พิมพ์ความยาวมั่ว ๆ มา แล้วผลลัพธ์ที่ล้นจะกลายเป็นช่วงสั้น ๆ
  //ที่ดูสมเหตุสมผล ซึ่งอันตรายกว่าการปฏิเสธไปเลย
  EndAddr := int64(StartAddress) + int64(RangeLen);
  if EndAddr > ChipSize then EndAddr := ChipSize;

  FromAddr := (StartAddress div SectorSize) * SectorSize;
  EndAddr := ((EndAddr + SectorSize - 1) div SectorSize) * SectorSize;
  if EndAddr > ChipSize then EndAddr := ChipSize;

  ToAddr := cardinal(EndAddr);
  Result := ToAddr > FromAddr;
end;

function PlanEraseUniform(StartAddress, RangeLen, SectorSize, ChipSize: cardinal;
  Opcode: byte; out Plan: TErasePlan): boolean;
var
  FromAddr, ToAddr, Addr: cardinal;
  Count, i: integer;
begin
  Plan := nil;
  Result := AlignEraseRange(StartAddress, RangeLen, SectorSize, ChipSize,
                            FromAddr, ToAddr);
  if not Result then Exit;

  Count := (ToAddr - FromAddr + SectorSize - 1) div SectorSize;
  SetLength(Plan, Count);

  Addr := FromAddr;
  for i := 0 to Count - 1 do
  begin
    Plan[i].Addr := Addr;
    Plan[i].Size := SectorSize;
    Plan[i].Opcode := Opcode;
    Plan[i].Opcode4B := 0;
    Inc(Addr, SectorSize);
  end;
end;

//ขอบเขตของช่วงที่แอดเดรส Addr ตกอยู่ในแผนผังเซกเตอร์
//คืน False เมื่อ Addr อยู่นอกทุกช่วง
function RegionAt(const Info: TSFDPInfo; Addr: cardinal;
  out RegionIdx: integer; out RegionEnd: cardinal): boolean;
var
  i: integer;
  Base: cardinal;
begin
  Result := False;
  RegionIdx := -1;
  RegionEnd := 0;
  Base := 0;

  for i := 0 to Info.RegionCount - 1 do
  begin
    if (Addr >= Base) and (Addr < Base + Info.Regions[i].Size) then
    begin
      RegionIdx := i;
      RegionEnd := Base + Info.Regions[i].Size;
      Exit(True);
    end;
    Inc(Base, Info.Regions[i].Size);
  end;
end;

//ก้อนลบที่ใหญ่ที่สุดที่ใช้ได้ที่แอดเดรสนี้ โดยไม่ล้นออกนอกช่วงที่ขอ
//และไม่ข้ามขอบของ region เพราะ opcode ที่ช่วงนี้รับอาจไม่มีในช่วงถัดไป
function BestEraseAt(const Info: TSFDPInfo; Addr, LimitAddr: cardinal;
  out Size: cardinal; out Opcode, Opcode4B: byte): boolean;
var
  RegionIdx, t: integer;
  RegionEnd, Cap, S: cardinal;
  Mask: byte;
begin
  Result := False;
  Size := 0;
  Opcode := 0;
  Opcode4B := 0;

  if not RegionAt(Info, Addr, RegionIdx, RegionEnd) then Exit;

  //ห้ามเลยทั้งขอบช่วงที่ขอ และขอบ region
  Cap := LimitAddr;
  if RegionEnd < Cap then Cap := RegionEnd;

  Mask := Info.Regions[RegionIdx].EraseTypeMask;

  for t := 1 to 4 do
  begin
    if (Mask and (1 shl (t - 1))) = 0 then Continue;
    S := Info.EraseTypes[t].Size;
    if S = 0 then Continue;

    //ใช้ได้ก็ต่อเมื่อแอดเดรสตรงขอบของก้อนขนาดนี้ และก้อนทั้งก้อนอยู่ในช่วง
    if (Addr mod S) <> 0 then Continue;
    if (int64(Addr) + int64(S)) > int64(Cap) then Continue;

    if S > Size then
    begin
      Size := S;
      Opcode := Info.EraseTypes[t].Opcode;
      Opcode4B := Info.EraseTypes[t].Opcode4B;
      Result := True;
    end;
  end;
end;

//ขนาดลบที่เล็กที่สุดที่ใช้ได้ที่แอดเดรสนี้ ใช้ตอนปัดขอบช่วง
function SmallestEraseAt(const Info: TSFDPInfo; Addr: cardinal;
  out Size: cardinal; out Opcode: byte): boolean;
begin
  Result := SFDPSectorAt(Info, Addr, Size, Opcode);
end;

function PlanEraseSFDP(const Info: TSFDPInfo; StartAddress, RangeLen, ChipSize: cardinal;
  out Plan: TErasePlan): boolean;
var
  StartGran, EndGran: cardinal;
  DummyOp: byte;
  FromAddr, ToAddr, Addr, Size: cardinal;
  Opcode, Opcode4B: byte;
  EndAddr: int64;
  Count: integer;
  LastAddr: cardinal;
begin
  Plan := nil;
  Result := False;

  if (not Info.Valid) or (not Info.HasSectorMap) or (Info.RegionCount = 0) then Exit;
  if (RangeLen = 0) or (ChipSize = 0) or (StartAddress >= ChipSize) then Exit;

  EndAddr := int64(StartAddress) + int64(RangeLen);
  if EndAddr > ChipSize then EndAddr := ChipSize;

  //ปัดขอบด้วยขนาดเซกเตอร์ที่เล็กที่สุดของช่วงที่ขอบนั้นตกอยู่
  //ปัดด้วยขนาดของอีกช่วงหนึ่งจะกินพื้นที่ที่ผู้ใช้ไม่ได้ขอให้ลบ
  if not SmallestEraseAt(Info, StartAddress, StartGran, DummyOp) then Exit;
  if StartGran = 0 then Exit;
  FromAddr := (StartAddress div StartGran) * StartGran;

  if not SmallestEraseAt(Info, cardinal(EndAddr - 1), EndGran, DummyOp) then Exit;
  if EndGran = 0 then Exit;
  EndAddr := ((EndAddr + EndGran - 1) div EndGran) * EndGran;
  if EndAddr > ChipSize then EndAddr := ChipSize;
  ToAddr := cardinal(EndAddr);

  if ToAddr <= FromAddr then Exit;

  Addr := FromAddr;
  Count := 0;
  SetLength(Plan, 0);

  while Addr < ToAddr do
  begin
    LastAddr := Addr;

    if not BestEraseAt(Info, Addr, ToAddr, Size, Opcode, Opcode4B) then
    begin
      //ไม่มีก้อนใหญ่ที่ลงตัว ลองก้อนเล็กที่สุดของช่วงนี้
      //ทางนี้ไม่รู้ opcode ชุด 4 ไบต์ จึงปล่อยเป็น 0 ซึ่งแปลว่าให้สลับโหมดเอา
      Opcode4B := 0;
      if not SmallestEraseAt(Info, Addr, Size, Opcode) then
      begin
        Plan := nil;
        Exit(False);
      end;
      //ก้อนเล็กที่สุดยังล้นออกนอกช่วง แปลว่าปัดขอบไว้ไม่พอ
      if (int64(Addr) + int64(Size)) > int64(ToAddr) then
      begin
        Plan := nil;
        Exit(False);
      end;
    end;

    if Size = 0 then
    begin
      Plan := nil;
      Exit(False);
    end;

    SetLength(Plan, Count + 1);
    Plan[Count].Addr := Addr;
    Plan[Count].Size := Size;
    Plan[Count].Opcode := Opcode;
    Plan[Count].Opcode4B := Opcode4B;
    Inc(Count);

    Inc(Addr, Size);

    //กันลูปไม่รู้จบไว้อีกชั้น ถ้าแอดเดรสไม่ขยับก็ยอมแพ้ ดีกว่าค้าง
    if Addr <= LastAddr then
    begin
      Plan := nil;
      Exit(False);
    end;
  end;

  Result := Length(Plan) > 0;
end;

function PlanTotalBytes(const Plan: TErasePlan): cardinal;
var
  i: integer;
begin
  Result := 0;
  for i := 0 to High(Plan) do
    Inc(Result, Plan[i].Size);
end;

function PlanAllHave4B(const Plan: TErasePlan): boolean;
var
  i: integer;
begin
  Result := Length(Plan) > 0;
  for i := 0 to High(Plan) do
    if Plan[i].Opcode4B = 0 then Exit(False);
end;

function PlanBounds(const Plan: TErasePlan; out FromAddr, ToAddr: cardinal): boolean;
var
  i: integer;
begin
  FromAddr := 0;
  ToAddr := 0;
  if Length(Plan) = 0 then Exit(False);

  FromAddr := Plan[0].Addr;
  ToAddr := Plan[0].Addr + Plan[0].Size;

  for i := 1 to High(Plan) do
  begin
    if Plan[i].Addr < FromAddr then FromAddr := Plan[i].Addr;
    if Plan[i].Addr + Plan[i].Size > ToAddr then ToAddr := Plan[i].Addr + Plan[i].Size;
  end;

  Result := True;
end;

end.
