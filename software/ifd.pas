unit ifd;

//ตาราง region ของ Intel flash descriptor
//
//ภาพเฟิร์มแวร์ของบอร์ด Intel แบ่งเป็นส่วน (descriptor, BIOS, ME, GbE, ...)
//และงานซ่อมส่วนใหญ่ต้องยุ่งกับส่วนเดียว: เขียน BIOS ใหม่โดยไม่แตะ ME
//เพราะ ME ที่ถูกเขียนทับด้วยของผิดเครื่องทำให้บอร์ดไม่ตื่นเลย
//
//ตารางอยู่ในแฟลชเอง: ลายเซ็น 0FF0A55Ah ที่ออฟเซ็ต 10h, FLMAP0 ตามหลัง
//บอกตำแหน่งตาราง FLREG แต่ละช่องเก็บ base กับ limit เป็นหน่วย 4 KB
//ช่องที่ base > limit คือไม่ได้ใช้ (ค่าตามธรรมเนียมคือ 00007FFFh)
//
//จำนวน region จริงต่างกันตามรุ่นชิปเซ็ต และฟิลด์ NR ใน FLMAP0 เชื่อไม่ได้
//บนรุ่นใหม่ (Skylake ขึ้นไปรายงานศูนย์ทั้งที่มี region) จึงอ่านทั้งสิบช่อง
//แล้วตัดสินจาก base/limit ของแต่ละช่องเอง แบบเดียวกับที่ flashrom ทำ
//
//หน่วยนี้เป็น logic ล้วน ไม่แตะฮาร์ดแวร์ เพื่อให้ทดสอบได้บนทุกแพลตฟอร์ม

{$mode objfpc}{$H+}

interface

const
  IFD_SIGNATURE = $0FF0A55A;
  IFD_MAX_REGIONS = 10;

type
  TIFDRegion = record
    Index: integer;
    Name: string[8];     //ชื่อแบบเดียวกับ flashrom: fd, bios, me, gbe, pd, ec
    Base: cardinal;      //ไบต์แรกของ region
    Limit: cardinal;     //ไบต์สุดท้ายของ region (รวม)
    Used: boolean;
  end;

  TIFDMap = record
    Valid: boolean;
    FRBA: cardinal;      //ตำแหน่งตาราง FLREG ในภาพ
    Regions: array[0..IFD_MAX_REGIONS - 1] of TIFDRegion;
  end;

//คืน True เมื่อ Buf ขึ้นต้นด้วย descriptor ที่ลายเซ็นถูกและตารางอ่านได้
function ParseIFD(Buf: PByte; Size: cardinal; out Map: TIFDMap): boolean;

//หา region จากชื่อ (ตัวพิมพ์ไม่สำคัญ) คืน False เมื่อไม่รู้จักหรือไม่ได้ใช้
function IFDRegionByName(const Map: TIFDMap; const Name: string;
  out Region: TIFDRegion): boolean;

//ตารางอ่านง่ายหนึ่งบรรทัดต่อ region ที่ใช้จริง สำหรับพ่นลง log
//DumpSize > 0 จะเตือน region ที่เกินขนาดภาพด้วย
function IFDDescribe(const Map: TIFDMap; DumpSize: cardinal): string;

implementation

uses
  SysUtils;

const
  //ชื่อตามลำดับ region ของ Intel: flashrom ใช้ชุดเดียวกันนี้
  REGION_NAMES: array[0..IFD_MAX_REGIONS - 1] of string[8] =
    ('fd', 'bios', 'me', 'gbe', 'pd', 'reg5', 'reg6', 'reg7', 'ec', 'reg9');

function ReadDword(Buf: PByte; Size, Offset: cardinal; out V: cardinal): boolean;
begin
  V := 0;
  if (Buf = nil) or (int64(Offset) + 4 > int64(Size)) then Exit(False);
  V := cardinal(Buf[Offset]) or (cardinal(Buf[Offset + 1]) shl 8) or
       (cardinal(Buf[Offset + 2]) shl 16) or (cardinal(Buf[Offset + 3]) shl 24);
  Result := True;
end;

function ParseIFD(Buf: PByte; Size: cardinal; out Map: TIFDMap): boolean;
var
  V, FLMAP0: cardinal;
  i: integer;
  BaseField, LimitField: cardinal;
begin
  Result := False;
  Map.Valid := False;
  Map.FRBA := 0;
  for i := 0 to IFD_MAX_REGIONS - 1 do
  begin
    Map.Regions[i].Index := i;
    Map.Regions[i].Name := REGION_NAMES[i];
    Map.Regions[i].Base := 0;
    Map.Regions[i].Limit := 0;
    Map.Regions[i].Used := False;
  end;

  if not ReadDword(Buf, Size, $10, V) then Exit;
  if V <> IFD_SIGNATURE then Exit;
  if not ReadDword(Buf, Size, $14, FLMAP0) then Exit;

  //FRBA เก็บเป็นหน่วย 16 ไบต์ในบิต 23:16 ตารางทั้งหมดอยู่ในเพจ descriptor
  //4 KB แรกเสมอ ค่าที่ชี้พ้นออกไปคือ descriptor พัง ไม่ใช่ตารางที่ไกลจริง
  Map.FRBA := ((FLMAP0 shr 16) and $FF) shl 4;
  if (Map.FRBA = 0) or
     (Map.FRBA + IFD_MAX_REGIONS * 4 > 4096) then Exit;

  for i := 0 to IFD_MAX_REGIONS - 1 do
  begin
    //ภาพที่สั้นกว่าตาราง (ดัมป์เฉพาะ descriptor) อ่านได้เท่าที่มี
    if not ReadDword(Buf, Size, Map.FRBA + cardinal(i) * 4, V) then Break;
    BaseField := V and $7FFF;
    LimitField := (V shr 16) and $7FFF;
    if BaseField > LimitField then Continue;   //ช่องว่างตามธรรมเนียม
    Map.Regions[i].Base := BaseField shl 12;
    Map.Regions[i].Limit := (LimitField shl 12) or $FFF;
    Map.Regions[i].Used := True;
  end;

  //descriptor ที่ไม่มีสัก region เดียว ไม่มีประโยชน์และน่าจะเป็นขยะที่ลายเซ็น
  //บังเอิญตรง
  for i := 0 to IFD_MAX_REGIONS - 1 do
    if Map.Regions[i].Used then
    begin
      Map.Valid := True;
      Break;
    end;
  Result := Map.Valid;
end;

function IFDRegionByName(const Map: TIFDMap; const Name: string;
  out Region: TIFDRegion): boolean;
var
  i: integer;
begin
  Result := False;
  Region.Index := -1;
  Region.Name := '';
  Region.Base := 0;
  Region.Limit := 0;
  Region.Used := False;
  if not Map.Valid then Exit;
  for i := 0 to IFD_MAX_REGIONS - 1 do
    if SameText(string(Map.Regions[i].Name), Name) then
    begin
      if not Map.Regions[i].Used then Exit;
      Region := Map.Regions[i];
      Exit(True);
    end;
end;

function IFDDescribe(const Map: TIFDMap; DumpSize: cardinal): string;
var
  i: integer;
  R: TIFDRegion;
  SizeKB: cardinal;
  Line: string;
begin
  Result := '';
  if not Map.Valid then Exit;
  for i := 0 to IFD_MAX_REGIONS - 1 do
  begin
    R := Map.Regions[i];
    if not R.Used then Continue;
    SizeKB := (R.Limit - R.Base + 1) div 1024;
    Line := Format('  %-5s 0x%.8x..0x%.8x  %7d KB',
                   [string(R.Name), R.Base, R.Limit, SizeKB]);
    if (DumpSize > 0) and (QWord(R.Limit) >= QWord(DumpSize)) then
      Line := Line + '  (past the end of this image!)';
    if Result <> '' then Result := Result + LineEnding;
    Result := Result + Line;
  end;
end;

end.
