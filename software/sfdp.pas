unit sfdp;

//Serial Flash Discoverable Parameters (JEDEC JESD216)
//ใช้อ่านสเปกของชิปที่ไม่มีอยู่ใน chiplist.xml
//
//นอกจากตารางพื้นฐานแล้ว หน่วยนี้ยังอ่านอีกสามอย่างที่เปลี่ยนการเดาให้เป็นการรู้
//
//  DWORD-16 ของตารางพื้นฐาน  บอกวิธีเข้าโหมดแอดเดรส 4 ไบต์ที่ชิปตัวนี้รองรับจริง
//                            บอกด้วยว่า write status register ต้องนำหน้าด้วย 06h หรือ 50h
//  ตาราง FF84h               opcode ชุด 4 ไบต์ตัวจริง 13h 12h 21h DCh ฯลฯ
//  ตาราง FF81h               แผนผังเซกเตอร์ ชิปที่มีบล็อกหัวหรือท้ายไม่เท่ากัน
//                            จะลบผิดช่วงถ้าเชื่อว่าทั้งชิปใช้เซกเตอร์ขนาดเดียว

{$mode objfpc}

interface

uses
  Classes, SysUtils;

type

  TSFDPEraseType = record
    Size: cardinal;    //ขนาดเซกเตอร์เป็นไบต์ ถ้าเป็น 0 คือชิปไม่รองรับขนาดนี้
    Opcode: byte;      //opcode สำหรับลบขนาดนี้
    Opcode4B: byte;    //opcode เดียวกันในชุดคำสั่งแอดเดรส 4 ไบต์ 0 = ไม่มี
  end;

  //วิธีเข้าโหมดแอดเดรส 4 ไบต์ที่ชิปแจ้งว่ารองรับ
  //เดิมโปรแกรมยิง B7h แล้วตามด้วย 17h ของ Spansion ให้ทุกตัวโดยไม่ถาม
  //ซึ่งเป็นการส่ง opcode ที่ไม่นิยามใส่ชิปที่ไม่ใช่ Spansion
  TSFDP4BEntry = record
    B7NoWren: boolean;      //ส่ง B7h ได้เลย
    WrenB7: boolean;        //ต้อง WREN ก่อนแล้วค่อย B7h
    ExtAddrReg: boolean;    //เขียน extended address register ด้วย C5h
    BankReg17: boolean;     //เขียน bank register ด้วย 17h แบบ Spansion
    NvConfigB1: boolean;    //เขียน nonvolatile config register ด้วย B1h
    DedicatedSet: boolean;  //มีชุดคำสั่ง 4 ไบต์เฉพาะ ไม่ต้องสลับโหมดเลย
    Always4B: boolean;      //ชิปทำงานที่ 4 ไบต์อยู่แล้วเสมอ
  end;

  //หนึ่งช่วงของแผนผังเซกเตอร์
  TSFDPRegion = record
    Size: cardinal;         //ขนาดช่วงเป็นไบต์
    EraseTypeMask: byte;    //บิต 0..3 คือชนิดการลบ 1..4 ที่ใช้ได้ในช่วงนี้
  end;

const
  SFDP_MAX_REGIONS = 16;

type

  TSFDPInfo = record
    Valid: boolean;
    MajorRev: byte;
    MinorRev: byte;
    Density: cardinal;              //ขนาดชิปเป็นไบต์
    PageSize: cardinal;             //ขนาดเพจสำหรับเขียนเป็นไบต์
    AddrBytes: byte;                //3 = 3 ไบต์เท่านั้น, 4 = 4 ไบต์เท่านั้น, 34 = ได้ทั้งสองแบบ
    Supports4KErase: boolean;
    Erase4KOpcode: byte;
    EraseTypes: array[1..4] of TSFDPEraseType;

    //--- DWORD-16 ของตารางพื้นฐาน มีตั้งแต่ JESD216 rev A ขึ้นไป ---
    HasDword16: boolean;
    Entry4B: TSFDP4BEntry;
    SRWriteEnableOpcode: byte;      //06h หรือ 50h, 0 = ชิปไม่ได้บอก
    SoftReset66_99: boolean;        //รีเซ็ตด้วย 66h ตามด้วย 99h
    SoftResetF0: boolean;           //รีเซ็ตด้วย F0h

    //--- ตาราง 4-Byte Address Instruction Table (FF84h) ---
    Has4BAIT: boolean;
    Read4BOpcode: byte;             //13h ถ้าชิปรองรับ ไม่งั้น 0
    PageProg4BOpcode: byte;         //12h ถ้าชิปรองรับ ไม่งั้น 0

    //--- ตาราง Sector Map (FF81h) ---
    HasSectorMap: boolean;
    Uniform: boolean;               //True เมื่อทุกช่วงมีขนาดเซกเตอร์เท่ากัน
    RegionCount: integer;
    Regions: array[0..SFDP_MAX_REGIONS-1] of TSFDPRegion;
  end;

  //ตัวอ่าน SFDP หนึ่งครั้ง ใช้แยกตัวแยกวิเคราะห์ออกจากฮาร์ดแวร์
  //เทสต์ป้อนตารางสังเคราะห์เข้ามาทางนี้ได้โดยไม่ต้องมีชิป
  TSFDPReadProc = function(Addr: longword; var buffer: array of byte;
    bufflen: integer): integer;

//อ่านผ่านฮาร์ดแวร์จริง
function SFDPDetect(out Info: TSFDPInfo): boolean;

//อ่านผ่านตัวอ่านที่กำหนดเอง
function SFDPDetectVia(Reader: TSFDPReadProc; out Info: TSFDPInfo): boolean;

//ขนาดลบที่เล็กที่สุดที่ชิปรองรับ ปกติคือ 4K
function SFDPSmallestErase(const Info: TSFDPInfo; out Size: cardinal; out Opcode: byte): boolean;
function SFDPAddrBytesStr(const Info: TSFDPInfo): string;

//ชิปต้องสลับโหมดเพื่อใช้แอดเดรส 4 ไบต์หรือไม่
//ชิปที่มีชุดคำสั่งเฉพาะหรือทำงานที่ 4 ไบต์อยู่แล้วไม่ต้องสลับ
function SFDPNeeds4BSwitch(const Info: TSFDPInfo): boolean;

//คำอธิบายวิธีเข้าโหมด 4 ไบต์แบบอ่านออก
function SFDP4BEntryStr(const Info: TSFDPInfo): string;

//ช่วงที่แอดเดรส Addr ตกอยู่ คืนขนาดเซกเตอร์ที่ใช้ได้จริงในช่วงนั้น
//คืน False เมื่อไม่มีแผนผัง ซึ่งแปลว่าให้ใช้ขนาดเดียวทั้งชิปตามเดิม
function SFDPSectorAt(const Info: TSFDPInfo; Addr: cardinal;
  out Size: cardinal; out Opcode: byte): boolean;

implementation

uses spi25;

const
  SFDP_SIGNATURE = $50444653;  //'SFDP' แบบ little endian

  //รหัสตารางพารามิเตอร์ ไบต์ต่ำและไบต์สูง
  TBL_BASIC_LSB   = $00;  TBL_BASIC_MSB   = $FF;
  TBL_SECTORMAP_LSB = $81; TBL_SECTORMAP_MSB = $FF;
  TBL_4BAIT_LSB   = $84;  TBL_4BAIT_MSB   = $FF;

  MAX_TABLE_DWORDS = 24;

type
  TDwordBuf = array[0..MAX_TABLE_DWORDS*4-1] of byte;

//2^N พร้อมกันการเลื่อนบิตเกินขอบ
function Pow2(N: cardinal): cardinal;
begin
  if N > 31 then
    Result := 0
  else
    Result := cardinal(1) shl N;
end;

function GetDword(const Buf: array of byte; Offset: integer): cardinal;
begin
  Result := cardinal(Buf[Offset]) or
            (cardinal(Buf[Offset+1]) shl 8) or
            (cardinal(Buf[Offset+2]) shl 16) or
            (cardinal(Buf[Offset+3]) shl 24);
end;

//ตัวอ่านมาตรฐาน คุยกับชิปผ่าน spi25
function HardwareRead(Addr: longword; var buffer: array of byte;
  bufflen: integer): integer;
begin
  Result := UsbAsp25_ReadSFDP(Addr, buffer, bufflen);
end;

//---------------------------------------------------------------- DWORD-16

//DWORD-16 บิต 7:0 บอกว่า write status register ต้องนำหน้าด้วยอะไร
//50h คือ Write Enable for Volatile Status Register ส่วน 06h คือ WREN ปกติ
//การส่ง 50h ใส่ชิปที่ต้องการ 06h ทำให้คำสั่งถูกทิ้งเงียบ ๆ
procedure ParseSRWriteEnable(Dw: cardinal; var Info: TSFDPInfo);
var
  B: byte;
begin
  B := Dw and $FF;

  //บิต 2 คือ status register ชนิด volatile ที่ปลดล็อกด้วย 50h
  if (B and $04) <> 0 then
    Info.SRWriteEnableOpcode := $50
  else if (B and $03) <> 0 then
    Info.SRWriteEnableOpcode := $06
  else if (B and $08) <> 0 then
    //มีทั้งคู่ ตัวที่เขียนแล้วอยู่ถาวรใช้ 06h ซึ่งเป็นสิ่งที่เราต้องการ
    Info.SRWriteEnableOpcode := $06
  else
    Info.SRWriteEnableOpcode := 0;
end;

procedure ParseSoftReset(Dw: cardinal; var Info: TSFDPInfo);
var
  B: byte;
begin
  B := (Dw shr 8) and $3F;
  Info.SoftResetF0    := (B and $04) <> 0;
  Info.SoftReset66_99 := (B and $08) <> 0;
end;

procedure Parse4BEntry(Dw: cardinal; var Info: TSFDPInfo);
var
  B: byte;
begin
  B := (Dw shr 24) and $FF;
  Info.Entry4B.B7NoWren     := (B and $01) <> 0;
  Info.Entry4B.WrenB7       := (B and $02) <> 0;
  Info.Entry4B.ExtAddrReg   := (B and $04) <> 0;
  Info.Entry4B.BankReg17    := (B and $08) <> 0;
  Info.Entry4B.NvConfigB1   := (B and $10) <> 0;
  Info.Entry4B.DedicatedSet := (B and $20) <> 0;
  Info.Entry4B.Always4B     := (B and $40) <> 0;
end;

//------------------------------------------------------------------ 4BAIT

//ตาราง FF84h บอก opcode ชุดแอดเดรส 4 ไบต์ที่ชิปรองรับจริง
//DWORD-1 เป็นบิตธง DWORD-2 เป็น opcode ของการลบสี่ชนิด
procedure Parse4BAIT(const Buf: TDwordBuf; DwordCount: integer;
  var Info: TSFDPInfo);
var
  Flags, Ops: cardinal;
  i: integer;
begin
  if DwordCount < 1 then Exit;

  Flags := GetDword(Buf, 0);
  Info.Has4BAIT := True;

  if (Flags and $01) <> 0 then Info.Read4BOpcode := $13;
  if (Flags and $40) <> 0 then Info.PageProg4BOpcode := $12;

  if DwordCount < 2 then Exit;

  //บิต 9..12 บอกว่าการลบชนิดที่ 1..4 มีคู่ขนานแบบ 4 ไบต์หรือไม่
  Ops := GetDword(Buf, 4);
  for i := 1 to 4 do
    if (Flags and (cardinal(1) shl (8 + i))) <> 0 then
      Info.EraseTypes[i].Opcode4B := (Ops shr ((i - 1) * 8)) and $FF;
end;

//------------------------------------------------------------- Sector Map

//ตาราง FF81h เป็นลำดับของตัวบรรยาย สองชนิดปนกัน
//  บิต 0 = 0  ตัวบรรยายคำสั่งตรวจการตั้งค่า ยาวสองดเวิร์ด ข้ามไป
//  บิต 0 = 1  ตัวบรรยายแผนผัง ตามด้วยดเวิร์ดของแต่ละช่วง
//ชิปที่ตั้งค่าได้จะมีหลายแผนผัง เราใช้อันแรกซึ่งเป็นค่ามาจากโรงงาน
procedure ParseSectorMap(const Buf: TDwordBuf; DwordCount: integer;
  var Info: TSFDPInfo);
var
  Idx, Regions, i: integer;
  Dw: cardinal;
  FirstMask: byte;
begin
  Idx := 0;

  while Idx < DwordCount do
  begin
    Dw := GetDword(Buf, Idx * 4);

    if (Dw and $01) = 0 then
    begin
      //ตัวบรรยายคำสั่งตรวจการตั้งค่า ยาวสองดเวิร์ดเสมอ
      Inc(Idx, 2);
      //บิต 1 ติดแปลว่าเป็นตัวสุดท้ายของลำดับตรวจ ตัวถัดไปคือแผนผัง
      Continue;
    end;

    //ตัวบรรยายแผนผัง
    Regions := ((Dw shr 16) and $FF) + 1;
    if Regions > SFDP_MAX_REGIONS then Regions := SFDP_MAX_REGIONS;

    //ดเวิร์ดของช่วงต้องอยู่ในตารางครบ ไม่งั้นตารางเสีย
    if Idx + 1 + Regions > DwordCount then Exit;

    Info.RegionCount := 0;
    for i := 0 to Regions - 1 do
    begin
      Dw := GetDword(Buf, (Idx + 1 + i) * 4);
      Info.Regions[i].EraseTypeMask := Dw and $0F;
      //ขนาดเก็บเป็นจำนวนก้อนละ 256 ไบต์ ลบหนึ่ง
      Info.Regions[i].Size := (((Dw shr 8) and $FFFFFF) + 1) * 256;
      Inc(Info.RegionCount);
    end;

    Info.HasSectorMap := Info.RegionCount > 0;

    //ทุกช่วงลบด้วยชนิดเดียวกันหรือไม่ ถ้าไม่ ชิปนี้มีบล็อกหัวหรือท้ายพิเศษ
    Info.Uniform := True;
    if Info.RegionCount > 0 then
    begin
      FirstMask := Info.Regions[0].EraseTypeMask;
      for i := 1 to Info.RegionCount - 1 do
        if Info.Regions[i].EraseTypeMask <> FirstMask then Info.Uniform := False;
    end;

    Exit;   //ใช้แผนผังแรกที่เจอ
  end;
end;

//---------------------------------------------------------------- ตัวหลัก

function SFDPDetectVia(Reader: TSFDPReadProc; out Info: TSFDPInfo): boolean;
var
  Header: array[0..7] of byte;
  ParamHeader: array[0..7] of byte;
  Table: TDwordBuf;
  NumHeaders, i, TableLen, DwordCount: integer;
  TablePtr: cardinal;
  Dw: cardinal;
  Found: boolean;
  ShiftVal: cardinal;

  //ตำแหน่งและความยาวของตารางเสริมที่เจอระหว่างไล่หัวตาราง
  Ptr4BAIT, PtrMap: cardinal;
  Len4BAIT, LenMap: integer;

  //อ่านตารางหนึ่งตารางเข้ามาใน Table คืนจำนวนดเวิร์ดที่อ่านได้จริง
  function LoadTable(Ptr: cardinal; Dwords: integer): integer;
  begin
    if Dwords > MAX_TABLE_DWORDS then Dwords := MAX_TABLE_DWORDS;
    if Dwords < 1 then Exit(0);
    FillByte(Table, SizeOf(Table), 0);
    Reader(Ptr, Table, Dwords * 4);
    Result := Dwords;
  end;

begin
  Result := False;

  FillChar(Info, SizeOf(Info), 0);
  FillByte(Header, SizeOf(Header), 0);

  Reader(0, Header, SizeOf(Header));

  if GetDword(Header, 0) <> SFDP_SIGNATURE then Exit;

  Info.MinorRev := Header[4];
  Info.MajorRev := Header[5];
  NumHeaders := Header[6] + 1;     //NPH เก็บค่าเป็นจำนวนลบหนึ่ง
  if NumHeaders > 16 then NumHeaders := 16;

  //ไล่หัวตารางทั้งหมดรอบเดียว เก็บตำแหน่งของทุกตารางที่เราสนใจ
  Found := False;
  TablePtr := 0;
  DwordCount := 0;
  Ptr4BAIT := 0; Len4BAIT := 0;
  PtrMap := 0;   LenMap := 0;

  for i := 0 to NumHeaders - 1 do
  begin
    FillByte(ParamHeader, SizeOf(ParamHeader), 0);
    Reader(8 + cardinal(i) * 8, ParamHeader, SizeOf(ParamHeader));

    //ParamHeader: [0]=ID LSB [1]=minor [2]=major [3]=ความยาวเป็น dword [4..6]=ptr [7]=ID MSB
    if (ParamHeader[0] = TBL_BASIC_LSB) and (not Found) then
    begin
      DwordCount := ParamHeader[3];
      TablePtr := cardinal(ParamHeader[4]) or
                  (cardinal(ParamHeader[5]) shl 8) or
                  (cardinal(ParamHeader[6]) shl 16);
      Found := True;
    end
    else if (ParamHeader[0] = TBL_4BAIT_LSB) and (ParamHeader[7] = TBL_4BAIT_MSB) then
    begin
      Len4BAIT := ParamHeader[3];
      Ptr4BAIT := cardinal(ParamHeader[4]) or
                  (cardinal(ParamHeader[5]) shl 8) or
                  (cardinal(ParamHeader[6]) shl 16);
    end
    else if (ParamHeader[0] = TBL_SECTORMAP_LSB) and (ParamHeader[7] = TBL_SECTORMAP_MSB) then
    begin
      LenMap := ParamHeader[3];
      PtrMap := cardinal(ParamHeader[4]) or
                (cardinal(ParamHeader[5]) shl 8) or
                (cardinal(ParamHeader[6]) shl 16);
    end;
  end;

  if (not Found) or (DwordCount < 2) then Exit;

  if DwordCount > MAX_TABLE_DWORDS then DwordCount := MAX_TABLE_DWORDS;
  TableLen := DwordCount * 4;

  FillByte(Table, SizeOf(Table), 0);
  Reader(TablePtr, Table, TableLen);

  //DWORD-1: แฟล็กการลบและรูปแบบแอดเดรส
  Dw := GetDword(Table, 0);
  Info.Supports4KErase := (Dw and $03) = $01;
  Info.Erase4KOpcode := (Dw shr 8) and $FF;

  case (Dw shr 17) and $03 of
    0: Info.AddrBytes := 3;
    1: Info.AddrBytes := 34;
    2: Info.AddrBytes := 4;
  else
    Info.AddrBytes := 3;
  end;

  //DWORD-2: ความจุ
  Dw := GetDword(Table, 4);
  if (Dw and $80000000) = 0 then
    Info.Density := (Dw + 1) div 8            //ค่าที่อ่านได้คือจำนวนบิตลบหนึ่ง
  else
  begin
    ShiftVal := Dw and $7FFFFFFF;
    //2^N บิต เกิน 2^34 บิต (2 GB) ใส่ใน cardinal ไม่พอ
    if (ShiftVal < 3) or (ShiftVal > 34) then
      Info.Density := 0
    else
      Info.Density := Pow2(ShiftVal - 3);
  end;

  //DWORD-8 และ DWORD-9: ชนิดการลบ ขนาดคือ 2^N ไบต์
  if DwordCount >= 8 then
  begin
    Dw := GetDword(Table, 28);
    if (Dw and $FF) <> 0 then
    begin
      Info.EraseTypes[1].Size := Pow2(Dw and $FF);
      Info.EraseTypes[1].Opcode := (Dw shr 8) and $FF;
    end;
    if ((Dw shr 16) and $FF) <> 0 then
    begin
      Info.EraseTypes[2].Size := Pow2((Dw shr 16) and $FF);
      Info.EraseTypes[2].Opcode := (Dw shr 24) and $FF;
    end;
  end;

  if DwordCount >= 9 then
  begin
    Dw := GetDword(Table, 32);
    if (Dw and $FF) <> 0 then
    begin
      Info.EraseTypes[3].Size := Pow2(Dw and $FF);
      Info.EraseTypes[3].Opcode := (Dw shr 8) and $FF;
    end;
    if ((Dw shr 16) and $FF) <> 0 then
    begin
      Info.EraseTypes[4].Size := Pow2((Dw shr 16) and $FF);
      Info.EraseTypes[4].Opcode := (Dw shr 24) and $FF;
    end;
  end;

  //DWORD-11: ขนาดเพจ มีเฉพาะ JESD216 rev A ขึ้นไป
  if DwordCount >= 11 then
  begin
    Dw := GetDword(Table, 40);
    Info.PageSize := Pow2((Dw shr 4) and $0F);
  end;

  //DWORD-16: วิธีเข้าโหมด 4 ไบต์ การรีเซ็ต และคำสั่งปลดล็อก status register
  if DwordCount >= 16 then
  begin
    Info.HasDword16 := True;
    Dw := GetDword(Table, 60);
    ParseSRWriteEnable(Dw, Info);
    ParseSoftReset(Dw, Info);
    Parse4BEntry(Dw, Info);
  end;

  //ถ้าตารางสั้นไปหรือค่าที่อ่านได้ไม่สมเหตุสมผล ใช้ขนาดเพจมาตรฐาน
  if (Info.PageSize < 1) or (Info.PageSize > 2048) then Info.PageSize := 256;

  //ตารางเสริม อ่านทีหลังเพราะใช้บัฟเฟอร์เดียวกันกับตารางพื้นฐาน
  //ต้องเรียก LoadTable ให้เสร็จก่อนค่อยแยกวิเคราะห์ ลำดับการคำนวณอาร์กิวเมนต์
  //ไม่ได้ถูกกำหนดไว้ในภาษา จึงไม่ฝากความถูกต้องไว้กับมัน
  if (Len4BAIT > 0) and (Ptr4BAIT > 0) then
  begin
    TableLen := LoadTable(Ptr4BAIT, Len4BAIT);
    Parse4BAIT(Table, TableLen, Info);
  end;

  if (LenMap > 0) and (PtrMap > 0) then
  begin
    TableLen := LoadTable(PtrMap, LenMap);
    ParseSectorMap(Table, TableLen, Info);
  end;

  Info.Valid := Info.Density > 0;
  Result := Info.Valid;
end;

function SFDPDetect(out Info: TSFDPInfo): boolean;
begin
  Result := SFDPDetectVia(@HardwareRead, Info);
end;

function SFDPSmallestErase(const Info: TSFDPInfo; out Size: cardinal; out Opcode: byte): boolean;
var
  i: integer;
begin
  Result := False;
  Size := 0;
  Opcode := 0;

  for i := 1 to 4 do
    if Info.EraseTypes[i].Size > 0 then
      if (Size = 0) or (Info.EraseTypes[i].Size < Size) then
      begin
        Size := Info.EraseTypes[i].Size;
        Opcode := Info.EraseTypes[i].Opcode;
        Result := True;
      end;

  //ถ้าไม่มีตารางชนิดการลบ แต่ชิปแจ้งว่ารองรับ 4K
  if (not Result) and Info.Supports4KErase and (Info.Erase4KOpcode <> 0) and
     (Info.Erase4KOpcode <> $FF) then
  begin
    Size := 4096;
    Opcode := Info.Erase4KOpcode;
    Result := True;
  end;
end;

function SFDPAddrBytesStr(const Info: TSFDPInfo): string;
begin
  case Info.AddrBytes of
    3: Result := '3';
    4: Result := '4';
    34: Result := '3 or 4';
  else
    Result := '?';
  end;
end;

function SFDPNeeds4BSwitch(const Info: TSFDPInfo): boolean;
begin
  //ชิปที่ทำงานที่ 4 ไบต์อยู่แล้ว หรือมีชุดคำสั่งเฉพาะ ไม่ต้องสลับโหมด
  if not Info.HasDword16 then Exit(True);
  Result := not (Info.Entry4B.Always4B or Info.Entry4B.DedicatedSet);
end;

function SFDP4BEntryStr(const Info: TSFDPInfo): string;

  procedure Add(const S: string);
  begin
    if Result <> '' then Result := Result + ', ';
    Result := Result + S;
  end;

begin
  Result := '';
  if not Info.HasDword16 then Exit('not declared');

  if Info.Entry4B.Always4B     then Add('always 4 byte');
  if Info.Entry4B.DedicatedSet then Add('dedicated 4 byte instructions');
  if Info.Entry4B.B7NoWren     then Add('B7h');
  if Info.Entry4B.WrenB7       then Add('WREN + B7h');
  if Info.Entry4B.ExtAddrReg   then Add('C5h extended address register');
  if Info.Entry4B.BankReg17    then Add('17h bank register');
  if Info.Entry4B.NvConfigB1   then Add('B1h config register');

  if Result = '' then Result := 'none declared';
end;

function SFDPSectorAt(const Info: TSFDPInfo; Addr: cardinal;
  out Size: cardinal; out Opcode: byte): boolean;
var
  i, t: integer;
  Base: cardinal;
begin
  Result := False;
  Size := 0;
  Opcode := 0;

  if (not Info.HasSectorMap) or (Info.RegionCount = 0) then Exit;

  Base := 0;
  for i := 0 to Info.RegionCount - 1 do
  begin
    if (Addr >= Base) and (Addr < Base + Info.Regions[i].Size) then
    begin
      //เลือกชนิดการลบที่เล็กที่สุดที่ช่วงนี้ใช้ได้
      for t := 1 to 4 do
        if ((Info.Regions[i].EraseTypeMask and (1 shl (t - 1))) <> 0) and
           (Info.EraseTypes[t].Size > 0) then
          if (Size = 0) or (Info.EraseTypes[t].Size < Size) then
          begin
            Size := Info.EraseTypes[t].Size;
            Opcode := Info.EraseTypes[t].Opcode;
            Result := True;
          end;
      Exit;
    end;
    Inc(Base, Info.Regions[i].Size);
  end;
end;

end.
