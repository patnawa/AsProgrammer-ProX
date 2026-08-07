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
    FastRead4BOpcode: byte;         //0Ch ถ้าชิปรองรับ ไม่งั้น 0
    PageProg4BOpcode: byte;         //12h ถ้าชิปรองรับ ไม่งั้น 0

    //--- ตาราง Sector Map (FF81h) ---
    //True when an FF81h parameter header was present, even if its map could
    //not be resolved or validated.  Destructive callers must distinguish
    //"no sector map declared" from "a sector map exists but is ambiguous";
    //falling back to a uniform 4K geometry in the latter case can erase the
    //wrong physical block.
    SectorMapDeclared: boolean;
    //True เฉพาะเมื่อรู้ว่า map นี้คือ configuration ที่กำลังใช้อยู่จริง
    //ตารางที่ต้องอ่าน configuration register แต่ยังไม่ได้อ่านจะ fail closed
    HasSectorMap: boolean;
    Uniform: boolean;               //True เมื่อทุกช่วงมีขนาดเซกเตอร์เท่ากัน
    RegionCount: integer;
    Regions: array[0..SFDP_MAX_REGIONS-1] of TSFDPRegion;

    //--- Quad read: DWORD-1, DWORD-3 และ DWORD-15 ---
    //
    //ชิปส่วนใหญ่อ่านสี่เส้นได้ ซึ่งเร็วกว่าเส้นเดียวเกือบสี่เท่า แต่การจะใช้ได้
    //ต้องมีบิต QE ตั้งอยู่แล้ว และ QE อยู่คนละที่กันในแต่ละยี่ห้อ
    //
    //DWORD-15 บิต 22:20 คือ Quad Enable Requirements ซึ่งบอกว่าบิตนั้นอยู่
    //รีจิสเตอร์ไหน บิตที่เท่าไร และอ่านด้วย opcode อะไร โปรแกรมนี้ไม่เคย "ตั้ง"
    //QE ให้ใคร เพราะนั่นคือการแก้ชิปของลูกค้าอย่างถาวรเพื่อความเร็วของเราเอง
    //แต่ถ้ามันตั้งอยู่แล้วก็ใช้ได้ฟรี ๆ จึงเก็บมาเฉพาะฝั่งอ่าน
    //
    //Mode clocks สำคัญไม่แพ้กัน โหมด continuous read ที่ต้องส่ง mode byte
    //ถ้าส่งผิดชิปจะค้างอยู่ในสถานะที่ตีความคำสั่งถัดไปเป็นแอดเดรส
    HasQuadInfo: boolean;
    Supports114: boolean;           //อ่านข้อมูลสี่เส้น แอดเดรสเส้นเดียว (6Bh)
    Supports144: boolean;           //ทั้งแอดเดรสและข้อมูลสี่เส้น (EBh)
    Read114Opcode: byte;
    Read114DummyCycles: byte;
    Read114ModeClocks: byte;
    Read144Opcode: byte;
    Read144DummyCycles: byte;
    Read144ModeClocks: byte;

    HasQER: boolean;
    QERCode: byte;                  //0..7 ตาม JESD216 DWORD-15 บิต 22:20

    //--- DWORD-10 และ DWORD-11: เวลาที่ชิปบอกเองว่าใช้จริง ---
    //
    //เดิมเพดานรอเป็นค่าคงที่ 5 วินาทีต่อเพจ 30 วินาทีต่อเซกเตอร์ 600 วินาทีต่อชิป
    //ซึ่งผิดทั้งสองทาง ชิป 256Mbit ที่ลบทั้งตัวจริง ๆ ใช้เวลาเกินสิบนาทีจะถูกตัดบท
    //ว่าล้มเหลวทั้งที่กำลังทำงานอยู่ ส่วนเพจที่ควรเขียนเสร็จใน 3 มิลลิวินาที
    //ต้องรอจนครบ 5 วินาทีก่อนจะยอมบอกว่าชิปไม่ตอบ
    //
    //ค่าที่เก็บไว้ตรงนี้คือเวลาสูงสุดตามที่ชิปแจ้ง ไม่ใช่เวลาปกติ
    //ตัวคูณจากเวลาปกติไปเป็นเวลาสูงสุดอยู่ในตารางเดียวกัน
    HasTiming: boolean;
    EraseTimeMaxMs: array[1..4] of cardinal;  //ต่อหนึ่งคำสั่งลบของชนิดนั้น
    PageProgTimeMaxMs: cardinal;
    ChipEraseTimeMaxMs: cardinal;
  end;

  //ตัวอ่าน SFDP หนึ่งครั้ง ใช้แยกตัวแยกวิเคราะห์ออกจากฮาร์ดแวร์
  //เทสต์ป้อนตารางสังเคราะห์เข้ามาทางนี้ได้โดยไม่ต้องมีชิป
  TSFDPReadProc = function(Addr: longword; var buffer: array of byte;
    bufflen: integer): integer;

//อ่านผ่านฮาร์ดแวร์จริง
function SFDPDetect(out Info: TSFDPInfo): boolean;

//อ่านผ่านตัวอ่านที่กำหนดเอง
function SFDPDetectVia(Reader: TSFDPReadProc; out Info: TSFDPInfo): boolean;

//แยกวิเคราะห์ดัมป์ที่เก็บไว้แล้ว โดยไม่ต้องมีชิปหรือเครื่องโปรแกรม
//
//ตารางดิบมีค่ากว่าคำอธิบายที่เราแปลออกมา เพราะเอาไปแยกใหม่ได้เมื่อตัวแยก
//ดีขึ้น และเอาไปแนบรายงานปัญหาได้โดยที่คนอ่านไม่ต้องมีชิปตัวนั้นอยู่ในมือ
function SFDPDetectFromBuffer(Buf: PByte; Size: cardinal;
  out Info: TSFDPInfo): boolean;

//ตาราง SFDP ของชิปนี้ยาวถึงไบต์ไหน ใช้ตอนดัมป์ว่าจะอ่านมาเท่าไหร่จึงจะครบ
//คืน 0 เมื่อไม่มีลายเซ็น SFDP
function SFDPExtent(Reader: TSFDPReadProc): cardinal;

//ขนาดลบที่เล็กที่สุดที่ชิปรองรับ ปกติคือ 4K
function SFDPSmallestErase(const Info: TSFDPInfo; out Size: cardinal; out Opcode: byte): boolean;
function SFDPAddrBytesStr(const Info: TSFDPInfo): string;

//บิต QE อยู่ที่ไหน ตามรหัส QER ที่ชิปแจ้ง
//
//คืน False เมื่อรหัสนั้นเป็นค่าสงวน หรือเมื่อชิปบอกว่าไม่มีบิต QE เลย
//(รหัส 0 แปลว่าสี่เส้นใช้ได้อยู่แล้วตลอด ซึ่ง QuadAlwaysEnabled ตอบแยก)
//
//Opcode ที่คืนมาคือ opcode สำหรับ *อ่าน* รีจิสเตอร์นั้น หน่วยนี้ไม่มีฝั่งเขียน
//โดยตั้งใจ การตั้ง QE คือการแก้ชิปของคนอื่นอย่างถาวรเพื่อความเร็วของเราเอง
function SFDPQuadEnableBit(const Info: TSFDPInfo;
  out ReadOpcode: byte; out BitIndex: byte): boolean;

//ชิปแจ้งว่าสี่เส้นเปิดอยู่เสมอ ไม่มีบิตให้ตั้ง
function SFDPQuadAlwaysEnabled(const Info: TSFDPInfo): boolean;

//ชิปต้องสลับโหมดเพื่อใช้แอดเดรส 4 ไบต์หรือไม่
//ชิปที่มีชุดคำสั่งเฉพาะหรือทำงานที่ 4 ไบต์อยู่แล้วไม่ต้องสลับ
function SFDPNeeds4BSwitch(const Info: TSFDPInfo): boolean;

//คำอธิบายวิธีเข้าโหมด 4 ไบต์แบบอ่านออก
function SFDP4BEntryStr(const Info: TSFDPInfo): string;

//ช่วงที่แอดเดรส Addr ตกอยู่ คืนขนาดเซกเตอร์ที่ใช้ได้จริงในช่วงนั้น
//คืน False เมื่อไม่มีแผนผัง ซึ่งแปลว่าให้ใช้ขนาดเดียวทั้งชิปตามเดิม
function SFDPSectorAt(const Info: TSFDPInfo; Addr: cardinal;
  out Size: cardinal; out Opcode: byte): boolean;

//หน่วยเวลาที่ SFDP ใช้เข้ารหัส แยกออกมาให้ทดสอบได้ตรง ๆ
function SFDPEraseUnitMs(Units: byte): cardinal;
function SFDPProgUnitUs(Units: byte): cardinal;
function SFDPChipEraseUnitMs(Units: byte): cardinal;

//เวลาสูงสุดที่ชิปแจ้งไว้สำหรับการลบชนิดนั้น คืน 0 เมื่อชิปไม่ได้บอก
function SFDPEraseTimeoutMs(const Info: TSFDPInfo; EraseType: integer): cardinal;

//เวลาสูงสุดที่ชิปแจ้งไว้สำหรับการลบตามขนาดเซกเตอร์ที่ระบุ
//ใช้ตอนวางแผนลบ เพราะแผนบอกขนาดมา ไม่ได้บอกหมายเลขชนิด
function SFDPEraseTimeoutForSize(const Info: TSFDPInfo; Size: cardinal): cardinal;

//เพดานรอที่ควรใช้จริง
//
//เอาค่าที่ชิปแจ้งมาใช้ แต่ไม่ต่ำกว่าค่าพื้นและไม่สูงกว่าเพดานแข็ง
//ตารางที่เสียหายหรืออ่านมาผิดไม่ควรทำให้โปรแกรมค้างเป็นชั่วโมง และก็ไม่ควร
//ทำให้งานที่กำลังไปได้ดีถูกตัดบทกลางคัน DeclaredMs = 0 แปลว่าชิปไม่ได้บอก
function BusyTimeoutMs(DeclaredMs, FloorMs, CeilingMs: cardinal): cardinal;

implementation

uses spi25;

const
  SFDP_SIGNATURE = $50444653;  //'SFDP' แบบ little endian

  //รหัสตารางพารามิเตอร์ ไบต์ต่ำและไบต์สูง
  TBL_BASIC_LSB   = $00;  TBL_BASIC_MSB   = $FF;
  TBL_SECTORMAP_LSB = $81; TBL_SECTORMAP_MSB = $FF;
  TBL_4BAIT_LSB   = $84;  TBL_4BAIT_MSB   = $FF;

  SMPT_DESC_END = $01;
  SMPT_DESC_MAP = $02;

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

//------------------------------------------------- DWORD-1 / DWORD-3 / DWORD-15

//DWORD-3 เก็บพารามิเตอร์ของการอ่านสี่เส้นสองแบบไว้ในดเวิร์ดเดียว
//  บิต 4:0    จำนวน dummy cycle ของ (1-4-4)
//  บิต 7:5    จำนวน mode clock ของ (1-4-4)
//  บิต 15:8   opcode ของ (1-4-4)
//  บิต 20:16  จำนวน dummy cycle ของ (1-1-4)
//  บิต 23:21  จำนวน mode clock ของ (1-1-4)
//  บิต 31:24  opcode ของ (1-1-4)
procedure ParseQuadReadParams(Dw: cardinal; var Info: TSFDPInfo);
begin
  Info.Read144DummyCycles := Dw and $1F;
  Info.Read144ModeClocks  := (Dw shr 5) and $07;
  Info.Read144Opcode      := (Dw shr 8) and $FF;

  Info.Read114DummyCycles := (Dw shr 16) and $1F;
  Info.Read114ModeClocks  := (Dw shr 21) and $07;
  Info.Read114Opcode      := (Dw shr 24) and $FF;
end;

//DWORD-15 บิต 22:20 คือ Quad Enable Requirements
procedure ParseQER(Dw: cardinal; var Info: TSFDPInfo);
begin
  Info.HasQER := True;
  Info.QERCode := (Dw shr 20) and $07;
end;

function SFDPQuadAlwaysEnabled(const Info: TSFDPInfo): boolean;
begin
  //รหัส 0 คือ "ไม่มีบิต QE ทั้งสี่เส้นใช้ได้ตลอด"
  Result := Info.HasQER and (Info.QERCode = 0);
end;

function SFDPQuadEnableBit(const Info: TSFDPInfo;
  out ReadOpcode: byte; out BitIndex: byte): boolean;
begin
  ReadOpcode := 0;
  BitIndex := 0;
  Result := False;
  if not Info.HasQER then Exit;

  //ตาราง QER ของ JESD216B ฝั่งอ่านอย่างเดียว
  //ตัวเลขพวกนี้คือเหตุผลที่ต้องอ่านจาก SFDP แทนที่จะเดาจากรหัสผู้ผลิต:
  //Winbond เก็บ QE ไว้ที่ SR2 บิต 1 ส่วน Macronix เก็บไว้ที่ SR1 บิต 6
  //ซึ่งเป็นบิตที่แผนผังของ Winbond เรียกว่า SEC การอ่านผิดตารางจึงไม่ใช่แค่
  //ได้คำตอบผิด แต่ได้คำตอบผิดที่ดูสมเหตุสมผล
  case Info.QERCode of
    //1: SR2 บิต 1 อ่านด้วย 35h
    1: begin ReadOpcode := $35; BitIndex := 1; Result := True; end;
    //2: SR1 บิต 6 อ่านด้วย 05h
    2: begin ReadOpcode := $05; BitIndex := 6; Result := True; end;
    //3: SR2 บิต 7 อ่านด้วย 3Fh
    3: begin ReadOpcode := $3F; BitIndex := 7; Result := True; end;
    //4, 5, 6: SR2 บิต 1 อ่านได้ด้วย 35h เหมือนกัน ต่างกันแค่ฝั่งเขียน
    //ซึ่งหน่วยนี้ไม่แตะ
    4, 5, 6: begin ReadOpcode := $35; BitIndex := 1; Result := True; end;
  else
    //0 คือไม่มีบิต ส่วน 7 เป็นค่าสงวน ทั้งคู่ไม่มีที่ให้ไปอ่าน
  end;
end;

//------------------------------------------------------- DWORD-10 / DWORD-11

//หน่วยของเวลาลบ สองบิต
function SFDPEraseUnitMs(Units: byte): cardinal;
begin
  case Units and $03 of
    0: Result := 1;
    1: Result := 16;
    2: Result := 128;
  else
    Result := 1000;
  end;
end;

//หน่วยของเวลาเขียนหนึ่งเพจ หนึ่งบิต
function SFDPProgUnitUs(Units: byte): cardinal;
begin
  if (Units and $01) <> 0 then Result := 64 else Result := 8;
end;

//หน่วยของเวลาลบทั้งชิป สองบิต
function SFDPChipEraseUnitMs(Units: byte): cardinal;
begin
  case Units and $03 of
    0: Result := 16;
    1: Result := 256;
    2: Result := 4000;
  else
    Result := 64000;
  end;
end;

//DWORD-10 เก็บเวลาลบของทั้งสี่ชนิดไว้ในดเวิร์ดเดียว ชนิดละ 7 บิต
//  บิต 3:0    ตัวคูณจากเวลาปกติไปเวลาสูงสุด  max = 2 * (N + 1) * typ
//  บิต 10:4   ชนิดที่ 1   บิต 8:4 คือจำนวน บิต 10:9 คือหน่วย
//  บิต 17:11  ชนิดที่ 2
//  บิต 24:18  ชนิดที่ 3
//  บิต 31:25  ชนิดที่ 4
//เวลาปกติคือ (จำนวน + 1) คูณหน่วย
procedure ParseEraseTiming(Dw: cardinal; var Info: TSFDPInfo);
var
  Mult, i, Shift: cardinal;
  Count, Units: byte;
  Typ: int64;
begin
  Mult := 2 * ((Dw and $0F) + 1);

  for i := 1 to 4 do
  begin
    Shift := 4 + (i - 1) * 7;
    Count := (Dw shr Shift) and $1F;
    Units := (Dw shr (Shift + 5)) and $03;

    Typ := int64(Count + 1) * int64(SFDPEraseUnitMs(Units));
    Typ := Typ * int64(Mult);

    //ค่าที่ล้นออกนอกความเป็นจริงแปลว่าอ่านตารางมาผิด อย่าเอาไปใช้
    if (Typ <= 0) or (Typ > 3600000) then
      Info.EraseTimeMaxMs[i] := 0
    else
      Info.EraseTimeMaxMs[i] := cardinal(Typ);
  end;
end;

//DWORD-11 เก็บขนาดเพจกับเวลาเขียนและเวลาลบทั้งชิป
//  บิต 3:0    ตัวคูณจากเวลาปกติไปเวลาสูงสุดของการเขียน
//  บิต 7:4    ขนาดเพจ 2^N  (อ่านไว้แล้วที่อื่น)
//  บิต 12:8   จำนวนของเวลาเขียนหนึ่งเพจ  บิต 13 คือหน่วย
//  บิต 18:14  เวลาเขียนไบต์แรก           ไม่ได้ใช้
//  บิต 23:19  เวลาเขียนไบต์ถัดไป         ไม่ได้ใช้
//  บิต 28:24  จำนวนของเวลาลบทั้งชิป      บิต 30:29 คือหน่วย
//
//ตัวคูณของการลบทั้งชิปมาจาก DWORD-10 เพราะเป็นการลบ ไม่ใช่การเขียน
procedure ParseProgTiming(Dw, EraseDw: cardinal; var Info: TSFDPInfo);
var
  ProgMult, EraseMult: cardinal;
  Count, Units: byte;
  Typ: int64;
begin
  ProgMult  := 2 * ((Dw and $0F) + 1);
  EraseMult := 2 * ((EraseDw and $0F) + 1);

  //เวลาเขียนหนึ่งเพจ เก็บเป็นไมโครวินาที คิดเป็นมิลลิวินาทีแบบปัดขึ้น
  Count := (Dw shr 8) and $1F;
  Units := (Dw shr 13) and $01;
  Typ := int64(Count + 1) * int64(SFDPProgUnitUs(Units)) * int64(ProgMult);
  Typ := (Typ + 999) div 1000;
  if (Typ <= 0) or (Typ > 600000) then
    Info.PageProgTimeMaxMs := 0
  else
    Info.PageProgTimeMaxMs := cardinal(Typ);

  //เวลาลบทั้งชิป
  Count := (Dw shr 24) and $1F;
  Units := (Dw shr 29) and $03;
  Typ := int64(Count + 1) * int64(SFDPChipEraseUnitMs(Units)) * int64(EraseMult);
  if (Typ <= 0) or (Typ > 7200000) then
    Info.ChipEraseTimeMaxMs := 0
  else
    Info.ChipEraseTimeMaxMs := cardinal(Typ);
end;

function SFDPEraseTimeoutMs(const Info: TSFDPInfo; EraseType: integer): cardinal;
begin
  if (not Info.HasTiming) or (EraseType < 1) or (EraseType > 4) then Exit(0);
  Result := Info.EraseTimeMaxMs[EraseType];
end;

function SFDPEraseTimeoutForSize(const Info: TSFDPInfo; Size: cardinal): cardinal;
var
  i: integer;
begin
  Result := 0;
  if (not Info.HasTiming) or (Size = 0) then Exit;

  for i := 1 to 4 do
    if Info.EraseTypes[i].Size = Size then
      Exit(Info.EraseTimeMaxMs[i]);
end;

function BusyTimeoutMs(DeclaredMs, FloorMs, CeilingMs: cardinal): cardinal;
begin
  //ชิปไม่ได้บอกก็ใช้ค่าพื้น ซึ่งเป็นพฤติกรรมเดิมทั้งหมด
  if DeclaredMs = 0 then Exit(FloorMs);

  Result := DeclaredMs;
  if Result < FloorMs then Result := FloorMs;
  if (CeilingMs > 0) and (Result > CeilingMs) then Result := CeilingMs;
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
  if (Flags and $02) <> 0 then Info.FastRead4BOpcode := $0C;
  if (Flags and $40) <> 0 then Info.PageProg4BOpcode := $12;

  if DwordCount < 2 then Exit;

  //บิต 9..12 บอกว่าการลบชนิดที่ 1..4 มีคู่ขนานแบบ 4 ไบต์หรือไม่
  Ops := GetDword(Buf, 4);
  for i := 1 to 4 do
    if (Flags and (cardinal(1) shl (8 + i))) <> 0 then
      Info.EraseTypes[i].Opcode4B := (Ops shr ((i - 1) * 8)) and $FF;
end;

//------------------------------------------------------------- Sector Map

//ตาราง FF81h เป็นลำดับของตัวบรรยายสองชนิด
//  บิต 1 = 0  configuration detection command descriptor ยาวสอง DWORD
//  บิต 1 = 1  configuration map descriptor ตามด้วย DWORD ของแต่ละช่วง
//  บิต 0      end indicator ของ descriptor ชนิดนั้น
//
//Reader ของหน่วยนี้อ่านได้เฉพาะพื้นที่ SFDP จึงยังรัน detection command
//เพื่อหาค่า configuration selector ปัจจุบันไม่ได้ ถ้าพบ command descriptor
//หรือหลาย map จะไม่เดาว่า map แรกคือค่าโรงงาน เพราะผู้ใช้อาจเปลี่ยนค่ามาแล้ว
//กรณีเดียวที่เลือกได้แน่นอนคือตารางไม่มี command และมี map ID 0 เพียง map เดียว
procedure ParseSectorMap(const Buf: TDwordBuf; DwordCount: integer;
  var Info: TSFDPInfo);
var
  Idx, Regions, i, t: integer;
  Dw, RegionDw: cardinal;
  FirstMask, SupportedMask: byte;
  RegionSizes: array[0..SFDP_MAX_REGIONS-1] of cardinal;
  RegionMasks: array[0..SFDP_MAX_REGIONS-1] of byte;
  EncodedSize, TotalSize: QWord;
  HasCommands: boolean;
begin
  //อย่าทิ้ง map บางส่วนไว้ให้ erase planner ใช้เมื่อ validation ล้มกลางทาง
  Info.HasSectorMap := False;
  Info.Uniform := False;
  Info.RegionCount := 0;
  FillChar(Info.Regions, SizeOf(Info.Regions), 0);

  if DwordCount < 2 then Exit; //header หนึ่ง DWORD + อย่างน้อยหนึ่ง region

  Idx := 0;
  HasCommands := False;

  //Command descriptors มาก่อน map descriptors เสมอ และยาวคู่ละสอง DWORD
  while Idx < DwordCount do
  begin
    Dw := GetDword(Buf, Idx * 4);
    if (Dw and SMPT_DESC_MAP) <> 0 then Break; //bit 1 เลือก map descriptor

    HasCommands := True;
    if Idx + 2 > DwordCount then Exit; //command ต้องมี address DWORD ตามหลัง
    Inc(Idx, 2);

    //bit 0 = command descriptor ตัวสุดท้าย จากนี้ต้องเป็น map
    if (Dw and SMPT_DESC_END) <> 0 then Break;
  end;

  //เราไม่ได้ execute detection commands จึงยังไม่รู้ selector ที่ active อยู่
  if HasCommands then Exit;
  if Idx >= DwordCount then Exit;

  Dw := GetDword(Buf, Idx * 4);
  if (Dw and SMPT_DESC_MAP) = 0 then Exit;  //ต้องเป็น map descriptor จริง

  //ไม่มี detection command หมายถึง selector เริ่มต้นเป็นศูนย์ตาม JESD216
  if ((Dw shr 8) and $FF) <> 0 then Exit;

  //map ที่ไม่ใช่ตัวสุดท้ายแปลว่ามีหลาย configuration แต่ไม่มีวิธี resolve
  if (Dw and SMPT_DESC_END) = 0 then Exit;

  Regions := ((Dw shr 16) and $FF) + 1;
  //ห้าม truncate จำนวนช่วง เพราะจะทำให้ปลายชิปถูกตีความด้วย geometry ผิด
  if Regions > SFDP_MAX_REGIONS then Exit;

  //ตัวสุดท้ายต้องกินตารางครบพอดี ทั้งกัน truncation และ descriptor แอบต่อท้าย
  if Idx + 1 + Regions <> DwordCount then Exit;

  SupportedMask := 0;
  for t := 1 to 4 do
    if (Info.EraseTypes[t].Size > 0) and
       (Info.EraseTypes[t].Opcode <> 0) then
      SupportedMask := SupportedMask or (1 shl (t - 1));

  TotalSize := 0;
  for i := 0 to Regions - 1 do
  begin
    RegionDw := GetDword(Buf, (Idx + 1 + i) * 4);
    RegionMasks[i] := RegionDw and $0F;

    //ทุก region ต้องมี erase type ที่ BFPT ประกาศไว้จริง
    if (RegionMasks[i] = 0) or
       ((RegionMasks[i] and SupportedMask) <> RegionMasks[i]) then Exit;

    //ขนาดเก็บเป็นจำนวนก้อนละ 256 ไบต์ ลบหนึ่ง คำนวณกว้างก่อน
    //เพราะค่า FFFFFFh หมายถึง 4 GiB และจะวนเป็นศูนย์ใน cardinal
    EncodedSize := (QWord((RegionDw shr 8) and $FFFFFF) + 1) * 256;
    if EncodedSize > QWord(High(cardinal)) then Exit;

    RegionSizes[i] := cardinal(EncodedSize);
    Inc(TotalSize, EncodedSize);
    if TotalSize > QWord(Info.Density) then Exit;
  end;

  //แผนผังต้องครอบคลุม data array ทั้งตัว ไม่ขาดและไม่ล้ำ
  if TotalSize <> QWord(Info.Density) then Exit;

  //Validation ครบแล้วจึง commit ทีเดียว
  Info.RegionCount := Regions;
  for i := 0 to Regions - 1 do
  begin
    Info.Regions[i].Size := RegionSizes[i];
    Info.Regions[i].EraseTypeMask := RegionMasks[i];
  end;

  Info.HasSectorMap := True;
  Info.Uniform := True;
  FirstMask := Info.Regions[0].EraseTypeMask;
  for i := 1 to Info.RegionCount - 1 do
    if Info.Regions[i].EraseTypeMask <> FirstMask then Info.Uniform := False;
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
  var
    Bytes: integer;
  begin
    if Dwords > MAX_TABLE_DWORDS then Dwords := MAX_TABLE_DWORDS;
    if Dwords < 1 then Exit(0);
    FillByte(Table, SizeOf(Table), 0);
    Bytes := Dwords * 4;
    if Reader(Ptr, Table, Bytes) <> Bytes then Exit(0);
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

  //บิต 21 และ 22 บอกว่ารองรับการอ่านสี่เส้นแบบไหน
  Info.Supports144 := (Dw and (cardinal(1) shl 21)) <> 0;
  Info.Supports114 := (Dw and (cardinal(1) shl 22)) <> 0;

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

  //DWORD-3: opcode, dummy cycle และ mode clock ของการอ่านสี่เส้น
  //HasQuadInfo แยกจาก Supports114/144 เพราะตารางที่สั้นกว่าสาม DWORD
  //ไม่ได้แปลว่าชิปไม่รองรับ แต่แปลว่าเราไม่รู้ว่าต้องส่งอะไร ซึ่งต่างกัน
  if DwordCount >= 3 then
  begin
    Info.HasQuadInfo := True;
    ParseQuadReadParams(GetDword(Table, 8), Info);
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

  //DWORD-10 กับ DWORD-11: เวลาที่ชิปแจ้งเอง ต้องมีครบทั้งคู่จึงจะเชื่อได้
  //เพราะตัวคูณของการลบทั้งชิปอยู่ใน DWORD-10 แต่ตัวเลขอยู่ใน DWORD-11
  if DwordCount >= 11 then
  begin
    Info.HasTiming := True;
    ParseEraseTiming(GetDword(Table, 36), Info);
    ParseProgTiming(GetDword(Table, 40), GetDword(Table, 36), Info);
  end;

  //DWORD-15: บิต QE อยู่รีจิสเตอร์ไหน บิตที่เท่าไร
  if DwordCount >= 15 then
    ParseQER(GetDword(Table, 56), Info);

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

  Info.SectorMapDeclared := LenMap > 0;

  //อย่าวิเคราะห์ prefix ของตารางที่ยาวกว่าบัฟเฟอร์เหมือนเป็นตารางครบ
  if (LenMap > 0) and (LenMap <= MAX_TABLE_DWORDS) and (PtrMap > 0) then
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

//--- การอ่านจากบัฟเฟอร์ ---
//
//TSFDPReadProc เป็นตัวชี้ฟังก์ชันธรรมดา ส่งพารามิเตอร์เพิ่มเข้าไปไม่ได้
//บัฟเฟอร์จึงต้องฝากไว้ที่ตัวแปรระดับหน่วย เหมือนที่ตัวอ่านฮาร์ดแวร์ฝาก
//สถานะไว้กับ AsProgrammer
var
  BufSource: PByte = nil;
  BufSize: cardinal = 0;

function BufferRead(Addr: longword; var buffer: array of byte;
  bufflen: integer): integer;
var
  i: integer;
begin
  Result := 0;
  if (BufSource = nil) or (bufflen <= 0) then Exit;

  for i := 0 to bufflen - 1 do
  begin
    //นอกขอบดัมป์ให้เป็น FF ซึ่งเป็นสิ่งเดียวกับที่ชิปตอบเมื่อไม่มีตารางตรงนั้น
    if (int64(Addr) + i) < int64(BufSize) then
      buffer[i] := BufSource[Addr + cardinal(i)]
    else
      buffer[i] := $FF;
  end;

  Result := bufflen;
end;

function SFDPDetectFromBuffer(Buf: PByte; Size: cardinal;
  out Info: TSFDPInfo): boolean;
begin
  FillChar(Info, SizeOf(Info), 0);
  if (Buf = nil) or (Size < 16) then Exit(False);

  BufSource := Buf;
  BufSize := Size;
  try
    Result := SFDPDetectVia(@BufferRead, Info);
  finally
    BufSource := nil;
    BufSize := 0;
  end;
end;

function SFDPExtent(Reader: TSFDPReadProc): cardinal;
var
  Header: array[0..7] of byte;
  ParamHeader: array[0..7] of byte;
  NumHeaders, i: integer;
  Ptr, EndOf: cardinal;
begin
  Result := 0;

  FillByte(Header, SizeOf(Header), 0);
  Reader(0, Header, SizeOf(Header));
  if GetDword(Header, 0) <> SFDP_SIGNATURE then Exit;

  NumHeaders := Header[6] + 1;
  if NumHeaders > 16 then NumHeaders := 16;

  //หัวตารางเองก็นับด้วย 8 ไบต์แรกบวกหัวละ 8 ไบต์
  Result := 8 + cardinal(NumHeaders) * 8;

  for i := 0 to NumHeaders - 1 do
  begin
    FillByte(ParamHeader, SizeOf(ParamHeader), 0);
    Reader(8 + cardinal(i) * 8, ParamHeader, SizeOf(ParamHeader));

    Ptr := cardinal(ParamHeader[4]) or (cardinal(ParamHeader[5]) shl 8) or
           (cardinal(ParamHeader[6]) shl 16);
    EndOf := Ptr + cardinal(ParamHeader[3]) * 4;
    if EndOf > Result then Result := EndOf;
  end;

  //ตารางที่อ้างตำแหน่งไกลเกินจริงแปลว่าอ่านมาผิด อย่าไปดัมป์เป็นเมกะไบต์
  if Result > 4096 then Result := 4096;
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
