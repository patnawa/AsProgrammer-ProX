unit protbits;

//แปลความหมายบิตป้องกันการเขียนของ SPI NOR ตระกูล 25
//
//status register ดิบ ๆ อ่านแล้วไม่รู้เรื่อง หน่วยนี้แปลงเป็นข้อความที่อ่านออก
//และคำนวณกลับได้ว่าช่วงไหนของชิปถูกล็อกอยู่
//
//การจัดวางบิตยึดตาม Winbond W25Q ซึ่ง GigaDevice, XMC, Zetta และอีกหลายเจ้า
//ทำตาม ยี่ห้ออื่นอาจต่างออกไป จึงต้องบอกผู้ใช้ว่านี่คือการตีความ

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

type
  TProtInfo = record
    BP: byte;          //BP0..BP2 รวมเป็นตัวเลข 0..7
    TB: boolean;       //True = ล็อกจากล่าง, False = ล็อกจากบน
    SEC: boolean;      //True = หน่วยเป็นเซกเตอร์ 4K, False = บล็อก 64K
    CMP: boolean;      //กลับด้านพื้นที่ที่ถูกล็อก
    SRP0, SRP1: boolean;
    QE: boolean;
    WPS: boolean;
    Busy, WEL: boolean;
  end;

//แยกบิตออกจาก status register สองไบต์
function DecodeProt(SR1, SR2: byte): TProtInfo;

//คำอธิบายแต่ละบิตแบบอ่านออก หนึ่งบรรทัดต่อหนึ่งเรื่อง
function ProtToText(const P: TProtInfo): string;

//ช่วงที่ถูกล็อกของชิปขนาด ChipSize
//คืน False เมื่อไม่มีอะไรถูกล็อก
function ProtectedRange(const P: TProtInfo; ChipSize: cardinal;
  out FromAddr, ToAddr: cardinal): boolean;

//ประกอบ SR1 กลับจากค่าที่แก้แล้ว
function EncodeProtSR1(const P: TProtInfo): byte;

type
  //ตัวอ่านบิตล็อกของบล็อกหนึ่งบล็อก แยกออกจากฮาร์ดแวร์เพื่อให้ทดสอบได้
  //คืน False เมื่ออ่านไม่สำเร็จ ซึ่งไม่เหมือนกับอ่านได้ว่าไม่ล็อก
  TBlockLockProc = function(Addr: cardinal; out Locked: boolean): boolean;

//หาว่าช่วงที่จะแตะทับกับบล็อกที่ถูกล็อกไว้หรือไม่ เมื่อชิปตั้ง WPS = 1
//
//WPS = 1 แปลว่าบิต BP ใน status register ไม่มีความหมายแล้ว พื้นที่ที่ถูก
//ล็อกมาจากบิตรายบล็อกซึ่งต้องอ่านทีละบล็อกด้วย 3Dh เดิมโปรแกรมได้แค่บอกว่า
//ตีความไม่ได้แล้วปล่อยผ่าน ซึ่งแปลว่าชิปกลุ่มนี้ไม่มีการ์ดกันเขียนเลย
//
//สแกนเฉพาะบล็อกที่ทับกับช่วงที่ขอ ไม่ต้องไล่ทั้งชิป
//Readable บอกว่าอ่านบิตล็อกได้อย่างน้อยหนึ่งบล็อกหรือไม่ ถ้าอ่านไม่ได้เลย
//แปลว่าไม่รู้ ผู้เรียกต้องบอกผู้ใช้แบบนั้น ห้ามสรุปว่าปลอดภัย
function BlockLockConflict(Reader: TBlockLockProc;
  ChipSize, BlockSize, StartAddr, Len: cardinal;
  out LockedAt: cardinal; out Readable: boolean): boolean;

implementation

function DecodeProt(SR1, SR2: byte): TProtInfo;
begin
  Result.Busy := (SR1 and $01) <> 0;
  Result.WEL  := (SR1 and $02) <> 0;
  Result.BP   := (SR1 shr 2) and $07;
  Result.TB   := (SR1 and $20) <> 0;
  Result.SEC  := (SR1 and $40) <> 0;
  Result.SRP0 := (SR1 and $80) <> 0;

  Result.SRP1 := (SR2 and $01) <> 0;
  Result.QE   := (SR2 and $02) <> 0;
  Result.CMP  := (SR2 and $40) <> 0;
  Result.WPS  := (SR2 and $04) <> 0;
end;

function EncodeProtSR1(const P: TProtInfo): byte;
begin
  Result := (P.BP and $07) shl 2;
  if P.TB then Result := Result or $20;
  if P.SEC then Result := Result or $40;
  if P.SRP0 then Result := Result or $80;
end;

function ProtectedRange(const P: TProtInfo; ChipSize: cardinal;
  out FromAddr, ToAddr: cardinal): boolean;
var
  Unit_, Area: cardinal;
begin
  Result := False;
  FromAddr := 0;
  ToAddr := 0;
  if ChipSize = 0 then Exit;

  //BP=0 คือไม่ล็อกอะไรเลย เว้นแต่ CMP กลับด้านให้กลายเป็นล็อกทั้งชิป
  if P.BP = 0 then
  begin
    if P.CMP then
    begin
      FromAddr := 0;
      ToAddr := ChipSize - 1;
      Exit(True);
    end;
    Exit(False);
  end;

  //BP=7 ล็อกทั้งชิป ถ้าไม่ได้อยู่ในโหมดเซกเตอร์
  if (P.BP = 7) and (not P.SEC) then
  begin
    if P.CMP then Exit(False);
    FromAddr := 0;
    ToAddr := ChipSize - 1;
    Exit(True);
  end;

  if P.SEC then Unit_ := 4 * 1024 else Unit_ := 64 * 1024;

  //ขนาดพื้นที่คือ 2^(BP-1) หน่วย
  Area := Unit_ shl (P.BP - 1);
  if Area > ChipSize then Area := ChipSize;

  if P.TB then
  begin
    //ล็อกจากปลายล่าง
    FromAddr := 0;
    ToAddr := Area - 1;
  end
  else
  begin
    //ล็อกจากปลายบน
    FromAddr := ChipSize - Area;
    ToAddr := ChipSize - 1;
  end;

  //CMP กลับด้าน พื้นที่ที่เหลือกลายเป็นพื้นที่ที่ถูกล็อกแทน
  if P.CMP then
  begin
    if P.TB then
    begin
      FromAddr := Area;
      ToAddr := ChipSize - 1;
    end
    else
    begin
      FromAddr := 0;
      ToAddr := ChipSize - Area - 1;
    end;
  end;

  Result := ToAddr >= FromAddr;
end;

function BlockLockConflict(Reader: TBlockLockProc;
  ChipSize, BlockSize, StartAddr, Len: cardinal;
  out LockedAt: cardinal; out Readable: boolean): boolean;
var
  Addr, EndAddr: int64;
  Locked: boolean;
begin
  Result := False;
  Readable := False;
  LockedAt := 0;

  if (Reader = nil) or (ChipSize = 0) or (BlockSize = 0) or (Len = 0) then Exit;
  if StartAddr >= ChipSize then Exit;

  //บวกด้วย int64 เพราะ StartAddr + Len ล้น cardinal ได้
  EndAddr := int64(StartAddr) + int64(Len);
  if EndAddr > ChipSize then EndAddr := ChipSize;

  //เริ่มที่ต้นบล็อกที่แอดเดรสเริ่มตกอยู่ เพราะบิตล็อกคุมทั้งบล็อก
  Addr := (int64(StartAddr) div BlockSize) * BlockSize;

  while Addr < EndAddr do
  begin
    if Reader(cardinal(Addr), Locked) then
    begin
      Readable := True;
      if Locked then
      begin
        LockedAt := cardinal(Addr);
        Exit(True);
      end;
    end;
    Inc(Addr, BlockSize);
  end;
end;

function ProtToText(const P: TProtInfo): string;
begin
  Result :=
    Format('BP2..BP0  %d      protected size selector', [P.BP]) + LineEnding +
    Format('TB        %d      protect from the %s', [Ord(P.TB),
           BoolToStr(P.TB, 'bottom', 'top')]) + LineEnding +
    Format('SEC       %d      units are %s', [Ord(P.SEC),
           BoolToStr(P.SEC, '4 KB sectors', '64 KB blocks')]) + LineEnding +
    Format('CMP       %d      %s', [Ord(P.CMP),
           BoolToStr(P.CMP, 'the protected area is inverted', 'normal')]) + LineEnding +
    Format('SRP1:SRP0 %d:%d    status register protection', [Ord(P.SRP1), Ord(P.SRP0)]) + LineEnding +
    Format('WPS       %d      %s', [Ord(P.WPS),
           BoolToStr(P.WPS, 'individual block locks are in use', 'BP bits are in use')]) + LineEnding +
    Format('QE        %d      quad enable', [Ord(P.QE)]) + LineEnding +
    Format('WEL       %d      write enable latch', [Ord(P.WEL)]) + LineEnding +
    Format('BUSY      %d', [Ord(P.Busy)]);
end;

end.
