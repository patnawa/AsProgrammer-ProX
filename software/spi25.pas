unit spi25;

{$mode objfpc}

interface

//หน่วยนี้ไม่พึ่ง LCL และไม่พึ่ง main โดยตั้งใจ
//ชั้นโปรโตคอลจึงเอาไปทดสอบกับฮาร์ดแวร์จำลองได้โดยไม่ต้องมีหน้าจอหรือชิปจริง
uses
  Classes, SysUtils, utilfunc, BaseHW, safemode;

const

  WT_PAGE = 0;
  WT_SSTB = 1;
  WT_SSTW = 2;

  //วิธีเข้าโหมดแอดเดรส 4 ไบต์ ค่ามาจาก SFDP หรือจากรหัสผู้ผลิต
  E4B_UNKNOWN = 0;   //ไม่รู้ ใช้ทางที่ปลอดภัยที่สุด
  E4B_NONE    = 1;   //ไม่มีคำสั่งสลับโหมดทันทีที่ปลอดภัย (มีแต่ชุดคำสั่ง
                     //4 ไบต์เฉพาะ หรือมีแต่ B1h ซึ่งเปลี่ยนค่าตั้งต้นตอน
                     //เปิดไฟ ไม่ใช่โหมดปัจจุบัน) งานที่ต้องสลับต้องถูกปฏิเสธ
  E4B_B7      = 2;   //ส่ง B7h ได้เลย
  E4B_WREN_B7 = 3;   //WREN ก่อนแล้วค่อย B7h
  E4B_BANK17  = 4;   //bank register แบบ Spansion opcode 17h
  E4B_EXTC5   = 5;   //extended address register opcode C5h
  //ค่า 6 เคยเป็น B1h (nonvolatile configuration register) ซึ่งถูกถอดออก:
  //การเขียน B1h ทับทั้ง register ด้วยค่าตายตัวเคยเสี่ยงตั้ง dual/quad
  //ถาวรบน Micron (ชิปเปิดเครื่องมาแล้วไม่คุยกับ SPI ธรรมดาอีก) และต่อให้
  //เขียนถูก มันก็เปลี่ยนแค่ค่าตั้งต้นตอนเปิดไฟ ไม่ได้สลับโหมดของ session นี้
  E4B_ALWAYS4B = 7;  //ชิปทำงานที่ 4 ไบต์ตลอดเวลา ทุกคำสั่งรับแอดเดรสสี่ไบต์
                     //อยู่แล้ว ไม่มีอะไรต้องส่ง

type

  MEMORY_ID = record
    ID9FH: array[0..2] of byte;
    ID90H: array[0..1] of byte;
    IDABH: byte;
    ID15H: array[0..1] of byte;

    //อ่านคำสั่งนั้นได้คำตอบจริงหรือไม่ แยกจากค่าที่อ่านมาได้
    //
    //"ไม่มีใครตอบ" กับ "ตอบมาว่า FF" เป็นคนละเรื่องกัน และเดิมแยกไม่ออก
    //เพราะบัฟเฟอร์ตัวเดียวถูกใช้ทั้งตอนส่งและตอนรับ ถ้าการอ่านล้มเหลว
    //ไบต์คำสั่งที่เพิ่งส่งไปจะยังค้างอยู่ แล้วถูกรายงานว่าเป็นคำตอบของชิป
    //อาการที่เห็นคือ ABh=AB กับ 90h=9000 ซึ่งคือคำสั่งสะท้อนกลับมาเอง
    //ไม่ใช่ข้อมูลจากชิป และมันทำให้คนไปตามหาปัญหาผิดที่
    Got9F, Got90, GotAB, Got15: boolean;
  end;

var
  //สิ่งที่รู้เกี่ยวกับชิปที่เสียบอยู่ ใช้เลือกว่าจะส่ง opcode ไหน
  //เดิมโปรแกรมยิง opcode ของทุกยี่ห้อใส่ชิปทุกตัวโดยไม่ถาม ซึ่งแปลว่า
  //ชิปที่ระบุรุ่นผิดจะได้รับคำสั่งที่ไม่นิยามในดาต้าชีตของมัน
  Chip25ManufID: byte = 0;         //ไบต์แรกของ 9Fh 0 = ยังไม่รู้
  Chip25Entry4B: byte = E4B_UNKNOWN;
  Chip25SRWrenOpcode: byte = 0;    //06h หรือ 50h ตามที่ SFDP แจ้ง 0 = ไม่รู้

  //อ่าน SFDP มาแล้วหรือยังสำหรับชิปตัวที่เสียบอยู่
  //แยกจาก Chip25ManufID เพราะการอ่านรหัสผู้ผลิตกับการอ่าน SFDP เป็นคนละเรื่อง
  //ชิปที่รู้ยี่ห้อแล้วแต่ยังไม่ได้อ่าน SFDP ยังไม่รู้วิธีเข้าโหมด 4 ไบต์
  Chip25SFDPRead: boolean = False;

  //ใช้คำสั่งอ่านเร็ว 0Bh แทน 03h ได้หรือไม่
  //
  //03h เป็นคำสั่งอ่านที่ไม่มีไบต์หลอก ซึ่งแลกมาด้วยเพดานความถี่ที่ต่ำกว่ามาก
  //ดาต้าชีตส่วนใหญ่ให้ 03h ไว้ที่ 33 ถึง 50 MHz ส่วน 0Bh ไปได้ถึง 104 MHz
  //เครื่องที่รองรับอยู่ตอนนี้ยิงได้ถึง 30 MHz ขึ้นไป ซึ่งอยู่ริมเพดานของ 03h
  //พอดี อาการที่ได้คือข้อมูลเพี้ยนเป็นครั้งคราวโดยไม่มีอะไรฟ้อง
  //
  //เปิดเฉพาะเมื่ออ่าน SFDP สำเร็จ เพราะนั่นแปลว่าเป็นชิปตามมาตรฐาน JESD216
  //ซึ่งมี 0Bh แน่นอน ชิปเก่าที่ไม่มีตาราง SFDP ก็ไม่ได้รับคำสั่งนี้
  Chip25FastRead: boolean = False;
  Chip25FastRead4BOpcode: byte = 0;  //0Ch ถ้าตาราง 4BAIT บอกว่ามี

  //opcode ชุดแอดเดรส 4 ไบต์ตัวจริง มาจากตาราง 4BAIT (FF84h) 0 = ชิปไม่มี
  //
  //ชิปที่มี opcode ชุดนี้ไม่ต้องสลับโหมดเลย ซึ่งปลอดภัยกว่ามาก เพราะการ
  //สลับโหมดทิ้งสถานะไว้ในตัวชิป ถ้าโปรแกรมตายหรือสายหลุดกลางคัน ชิปจะค้าง
  //อยู่ที่โหมด 4 ไบต์ แล้วเครื่องมือตัวถัดไปที่มาอ่านจะได้ข้อมูลผิดทั้งหมด
  Chip25Read4BOpcode: byte = 0;      //13h
  Chip25PageProg4BOpcode: byte = 0;  //12h

//ลืมสิ่งที่รู้ทั้งหมด ต้องเรียกเมื่อเปลี่ยนชิปหรือเปลี่ยนซ็อกเก็ต
procedure Reset25ChipHints;

function UsbAsp25_Busy(): boolean;

//เหมือน UsbAsp25_Busy แต่คืน status register ดิบมาด้วย
//
//ผู้เรียกต้องแยกให้ออกระหว่างชิปที่กำลังยุ่งอยู่จริง กับชิปที่ไม่ตอบเลย
//ซ็อกเก็ตว่าง สายขาด หรือชิปไม่ได้รับไฟ จะอ่าน status register ได้ FF ล้วน
//ซึ่งบิต 0 ติดอยู่ แปลว่ายุ่งตลอดกาล ถ้าเชื่อค่านั้นก็จะรอจนหมดเวลา
//ซึ่งบนคำสั่งลบทั้งชิปคือสิบนาที แล้วรายงานว่าชิปยุ่ง ซึ่งชี้ไปผิดทาง
function UsbAsp25_BusyEx(out sreg: byte): boolean;

//อ่านสถานะล็อกของบล็อกที่แอดเดรสนี้ opcode 3Dh
//
//ใช้กับชิปที่ตั้ง WPS = 1 ซึ่งแปลว่าบิต BP ไม่มีความหมายอีกต่อไป
//และพื้นที่ที่ถูกล็อกมาจากบิตล็อกรายบล็อกแทน ซึ่งอ่านจาก status register ไม่ได้
//คืน False เมื่ออ่านไม่สำเร็จ
function UsbAsp25_ReadBlockLock(Addr: longword; FourByteAddr: boolean;
  out Locked: boolean): boolean;

function EnterProgMode25(spiSpeed: integer; SendAB: boolean = false): boolean;
procedure ExitProgMode25;

function UsbAsp25_Read(Opcode: Byte; Addr: longword; var buffer: array of byte; bufflen: integer): integer;
function UsbAsp25_Read32bitAddr(Opcode: byte; Addr: longword; var buffer: array of byte; bufflen: integer): integer;

//อ่านเร็ว แอดเดรส 3 ไบต์ตามด้วยไบต์หลอกหนึ่งไบต์ opcode ปกติคือ 0Bh
function UsbAsp25_ReadFast(Opcode: byte; Addr: longword; var buffer: array of byte; bufflen: integer): integer;
//อ่านเร็ว แอดเดรส 4 ไบต์ opcode ปกติคือ 0Ch
function UsbAsp25_ReadFast32bitAddr(Opcode: byte; Addr: longword; var buffer: array of byte; bufflen: integer): integer;
function UsbAsp25_Write(Opcode: byte; Addr: longword; buffer: array of byte; bufflen: integer): integer;
function UsbAsp25_Write32bitAddr(Opcode: byte; Addr: longword; buffer: array of byte; bufflen: integer): integer;

function UsbAsp25_ReadID(var ID: MEMORY_ID): integer;
// Connection Doctor probe: one JEDEC command, one exact three-byte reply.
// It deliberately does not fall back to vendor-specific 90h/ABh/15h probes
// and does not mutate the process-wide manufacturer hint.
function UsbAsp25_ReadJEDEC9FExact(var ID: array of byte): boolean;
function UsbAsp25_ReadSFDP(Addr: longword; var buffer: array of byte; bufflen: integer): integer;
function UsbAsp25_ReadUniqueID(var buffer: array of byte): integer;
function UsbAsp25_ReadAuthStatus(var buffer: array of byte; bufflen: integer): integer;
function UsbAsp25_ReadSecReg(Addr: longword; var buffer: array of byte; bufflen: integer): integer;
function UsbAsp25_WriteSecReg(Addr: longword; buffer: array of byte; bufflen: integer): integer;
function UsbAsp25_EraseSecReg(Addr: longword): integer;

function UsbAsp25_Wren(): integer;
function UsbAsp25_Wrdi(): integer;

//สั่ง WREN แล้วอ่านกลับมาดูว่าแลตช์ติดจริงหรือไม่
//
//ชิปที่ขา WP# ถูกดึงต่ำ ชิปที่ status register ถูกล็อกไว้ หรือซ็อกเก็ตที่
//ต่อไม่ติด จะรับคำสั่ง WREN ไปเงียบ ๆ แล้วไม่ทำอะไรเลย ทุกคำสั่งเขียนและลบ
//หลังจากนั้นก็จะถูกทิ้งเงียบ ๆ เหมือนกัน กว่าจะรู้ตัวคือตอนตรวจข้อมูลกลับ
//ซึ่งบนชิป 8MB คือหลังจากเสียเวลาไปทั้งงาน แล้วยังชี้สาเหตุผิดอีกด้วย
//
//การอ่าน status register หนึ่งครั้งต่อหนึ่งงานเปลี่ยนคำตอบนั้นให้เป็น
//"ชิปไม่ยอมรับ write enable" ตั้งแต่ก่อนเริ่ม
//คืน False เมื่อ WEL ไม่ติด รวมถึงกรณีที่อ่าน status register ไม่ได้เลย
function UsbAsp25_WrenChecked(out WEL: boolean): boolean;

//รีเซ็ตชิปด้วยวิธีที่ JEDEC กำหนด 66h แล้วตามด้วย 99h
//
//เครื่องมือตัวก่อนหน้าที่ตายกลางคันทิ้งชิปไว้ในโหมดแอดเดรส 4 ไบต์ได้
//ชิปที่ค้างแบบนั้นตอบคำสั่งทุกอย่างด้วยข้อมูลจากแอดเดรสที่ผิดไปทั้งก้อน
function UsbAsp25_SoftReset(): integer;

//ออกจากโหมด QPI
//
//ชิปที่ค้างอยู่ในโหมด QPI ไม่เข้าใจคำสั่งที่ส่งมาทางขาเดียว 9Fh จึงได้
//คำตอบเป็น 00 หรือ FF ล้วน ซึ่งอ่านออกมาเหมือนชิปตายสนิท ทั้งที่ยังดีอยู่
//FFh เป็นคำสั่งออกจากโหมด QPI ที่ตีความได้ตรงกันทั้งในโหมด QPI และโหมดปกติ
function UsbAsp25_ExitQPI(): integer;

//อ่านรีจิสเตอร์เฉพาะยี่ห้อที่บอกว่าคำสั่งก่อนหน้าล้มเหลวหรือไม่
//Micron ใช้ 70h ส่วน Macronix ใช้ 2Bh
function UsbAsp25_ReadVendorStatus(Opcode: byte; out Value: byte): boolean;

//ปลดล็อกทุกบล็อกพร้อมกัน opcode 98h
//
//ใช้เฉพาะกับชิปที่ตั้ง WPS = 1 ซึ่งแปลว่าพื้นที่ที่ถูกล็อกมาจากบิตรายบล็อก
//ไม่ใช่จากบิต BP การล้าง BP จึงไม่ปลดอะไรเลยบนชิปกลุ่มนี้
//ผู้เรียกต้องสั่ง WREN มาก่อน และต้องไม่ส่งคำสั่งนี้ให้ชิปที่ไม่ได้ตั้ง WPS
//เพราะเป็น opcode ที่ไม่มีนิยามในดาต้าชีตของชิปที่ไม่มีบิตล็อกรายบล็อก
function UsbAsp25_GlobalUnlock(): integer;

//ล้างธงความผิดพลาดของ Micron 50h
//ธงพวกนี้ค้างอยู่จนกว่าจะถูกล้าง ถ้าไม่ล้างก่อนเริ่มงานใหม่ ความล้มเหลว
//ของงานก่อนหน้าจะถูกรายงานซ้ำอีกครั้งในงานที่จริง ๆ แล้วสำเร็จ
function UsbAsp25_ClearFlagStatus(): integer;
function UsbAsp25_ChipErase(): integer;
function UsbAsp25_EraseSector(Opcode: byte; Addr: longword; FourByteAddr: boolean): integer;

//Volatile = True เขียนแบบชั่วคราว ค่าหายเมื่อตัดไฟ
//ค่าเริ่มต้นคือเขียนแบบถาวร ซึ่งเป็นสิ่งที่ปุ่มปลดล็อกต้องการ
function UsbAsp25_WriteSR(sreg: byte; opcode: byte = $01; Volatile: boolean = False): integer;
function UsbAsp25_WriteSR_2byte(sreg1, sreg2: byte; Volatile: boolean = False): integer;
function UsbAsp25_ReadSR(var sreg: byte; opcode: byte = $05): integer;

function UsbAsp25_WriteSSTB(Opcode: byte; Data: byte): integer;
function UsbAsp25_WriteSSTW(Opcode: byte; Data1, Data2: byte): integer;

function UsbAsp25_EN4B(): integer;
function UsbAsp25_EX4B(): integer;

function SPIRead(CS: byte; BufferLen: integer; out buffer: array of byte): integer;
function SPIWrite(CS: byte; BufferLen: integer; buffer: array of byte): integer;
function SPIReadWrite(CSR: byte; CSW: byte; RBufferLen: integer; out rbuffer: array of byte; WBufferLen: integer; wbuffer: array of byte): integer;

implementation

//ด่านโหมดอ่านอย่างเดียว วางไว้ที่ตัวคำสั่ง ไม่ใช่ที่ปุ่ม
//
//วางไว้ที่ปุ่มแปลว่ามันคุมเฉพาะประตูที่มีคนนึกออก คำสั่งเขียนใน SPI 25 ถูก
//เรียกจากหลายที่มาก ทั้งเมนู สคริปต์ หน้าต่างแก้ status register เครื่อง
//ทดสอบความจุ และเส้นทางบรรทัดคำสั่ง การไล่ปิดทีละที่จึงพลาดแน่ ๆ สักที่หนึ่ง
//และที่พลาดคือที่ที่ไม่มีใครนึกถึงตอนเพิ่มโค้ดใหม่
//
//ที่นี่คือที่ที่ความสามารถอยู่จริง ปิดตรงนี้แล้วปิดหมดทุกทาง รวมถึงทางที่
//ยังไม่มีใครเขียน
//
//คืน -1 เงียบ ๆ (เท่ากับ "ส่งไม่สำเร็จ") ผู้เรียกทุกคนตรวจค่านี้อยู่แล้ว
//เพราะเป็นค่าเดียวกับที่ได้ตอนสายหลุด ส่วนข้อความอธิบายให้คนอ่านเป็นหน้าที่
//ของชั้น UI ซึ่งรู้ว่าผู้ใช้กำลังพยายามทำอะไรอยู่
function RefusedBySafeMode(Action: TGuardedAction): boolean; inline;
begin
  Result := SafeModeBlocks(Action);
end;

procedure Reset25ChipHints;
begin
  Chip25ManufID := 0;
  Chip25Entry4B := E4B_UNKNOWN;
  Chip25SRWrenOpcode := 0;
  Chip25SFDPRead := False;
  Chip25Read4BOpcode := 0;
  Chip25PageProg4BOpcode := 0;
  Chip25FastRead := False;
  Chip25FastRead4BOpcode := 0;
end;

function SPI25BufferLengthValid(Requested: integer;
  const BufferLength: SizeInt): boolean;
begin
  Result := (Requested >= 0) and
            (QWord(Requested) <= QWord(BufferLength));
end;

function SPI25AddressRangeValid(Addr: longword; Count: integer;
  FourByteAddr: boolean): boolean;
var
  Limit: QWord;
begin
  Result := False;
  if Count < 0 then Exit;

  if FourByteAddr then
    Limit := QWord(1) shl 32
  else
    Limit := QWord(1) shl 24;

  //Use an exclusive end so both a zero-length request at the last address and
  //a one-byte request ending exactly at the address-space limit are valid.
  Result := (QWord(Addr) < Limit) and
            (QWord(Addr) + QWord(Count) <= Limit);
end;

function SPI25CommandReadExact(CSR, CSW: byte;
  const Command: array of byte; CommandLen: integer;
  var Data: array of byte; DataLen: integer): integer;
var
  Sent, Got: integer;
begin
  Result := -1;
  if (CommandLen < 1) or
     (not SPI25BufferLengthValid(CommandLen, Length(Command))) or
     (not SPI25BufferLengthValid(DataLen, Length(Data))) then Exit;

  //A zero-byte read is a no-op.  In particular, do not leave CS asserted after
  //sending a header that can never have a matching reply phase.
  if DataLen = 0 then Exit(0);
  FillByte(Data[0], DataLen, $FF);

  if AsProgrammer.Current_HW = CHW_BUZZPIRAT then
    Got := AsProgrammer.Programmer.SPIWriteRead(
      CSR, CommandLen, Command, DataLen, Data)
  else
  begin
    Sent := SPIWrite(CSW, CommandLen, Command);
    if Sent <> CommandLen then Exit;
    Got := SPIRead(CSR, DataLen, Data);
  end;

  if Got <> DataLen then
  begin
    FillByte(Data[0], DataLen, $FF);
    Exit;
  end;
  Result := DataLen;
end;

function SPI25CommandWriteExact(const Command: array of byte;
  CommandLen: integer; const Data: array of byte;
  DataLen: integer): integer;
begin
  Result := -1;
  if (CommandLen < 1) or
     (not SPI25BufferLengthValid(CommandLen, Length(Command))) or
     (not SPI25BufferLengthValid(DataLen, Length(Data))) then Exit;

  //Issuing a page-program opcode without any data is at best undefined and at
  //worst starts a device-specific command.  Treat it as a safe no-op.
  if DataLen = 0 then Exit(0);

  if SPIWrite(0, CommandLen, Command) <> CommandLen then Exit;
  if SPIWrite(1, DataLen, Data) <> DataLen then Exit;
  Result := DataLen;
end;

function UsbAsp25_BusyEx(out sreg: byte): boolean;
var
  n: integer;
begin
  sreg := $FF;
  n := UsbAsp25_ReadSR(sreg);

  //อ่านไม่ได้เลยก็ถือว่ายังไม่พร้อม และปล่อยให้ค่า FF บอกเรื่องราวเอง
  if n <= 0 then sreg := $FF;

  Result := IsBitSet(sreg, 0);
end;

//รอจนกว่าชิปจะพร้อม
function UsbAsp25_Busy: boolean;
var
  sreg: byte;
begin
  Result := UsbAsp25_BusyEx(sreg);
end;

function UsbAsp25_ReadBlockLock(Addr: longword; FourByteAddr: boolean;
  out Locked: boolean): boolean;
var
  buff: array[0..4] of byte;
  value: byte;
  len, n: integer;
begin
  Locked := False;
  if not SPI25AddressRangeValid(Addr, 1, FourByteAddr) then Exit(False);

  buff[0] := $3D;
  if FourByteAddr then
  begin
    buff[1] := hi(hi(addr));
    buff[2] := lo(hi(addr));
    buff[3] := hi(lo(addr));
    buff[4] := lo(lo(addr));
    len := 5;
  end
  else
  begin
    buff[1] := hi(addr);
    buff[2] := hi(lo(addr));
    buff[3] := lo(addr);
    len := 4;
  end;

  value := $FF;
  n := SPI25CommandReadExact(1, 0, buff, len, value, 1);

  //FF ล้วนคือคำตอบของชิปที่ไม่รู้จักคำสั่งนี้ หรือของซ็อกเก็ตที่ว่างอยู่
  //อย่าตีความว่าถูกล็อก เพราะจะกลายเป็นห้ามเขียนทั้งที่ไม่มีอะไรล็อก
  if (n <> 1) or (value = $FF) then Exit(False);

  //บิต 0 คือสถานะล็อกของบล็อกที่แอดเดรสนี้ตกอยู่
  Locked := IsBitSet(value, 0);
  Result := True;
end;

//เข้าสู่โหมดโปรแกรม
function EnterProgMode25(spiSpeed: integer; SendAB: boolean = false): boolean;
begin
  result := AsProgrammer.Programmer.SPIInit(spiSpeed);
  if not Result then Exit;
  sleep(50);

  //ปลุกชิปจาก power-down
  if SendAB and (SPIWrite(1, 1, $AB) <> 1) then Exit(False);
  sleep(2);
end;

//ออกจากโหมดโปรแกรม
procedure ExitProgMode25;
begin
  AsProgrammer.Programmer.SPIDeinit;
end;

//อ่าน id แล้วเติมลงโครงสร้าง
function UsbAsp25_ReadID(var ID: MEMORY_ID): integer;
var
  command, buffer: array[0..3] of byte;

  //อ่านคำตอบของคำสั่งที่เพิ่งส่งไป
  //
  //ต้องล้างบัฟเฟอร์ก่อนอ่านทุกครั้ง เพราะบัฟเฟอร์ตัวเดียวกันนี้เพิ่งถูกใช้
  //ส่ง opcode ออกไป ถ้าไม่ล้างแล้วการอ่านล้มเหลว ไบต์ที่ค้างอยู่คือ opcode
  //ของเราเอง ซึ่งจะถูกรายงานออกไปเหมือนเป็นคำตอบของชิป
  //เดิมทาง 9Fh กับ 15h ล้าง แต่ทาง 90h กับ ABh ไม่ล้าง
  function ReadCommand(CommandLen, ReplyLen: integer): boolean;
  begin
    FillByte(buffer, 4, $FF);
    Result := SPI25CommandReadExact(1, 0, command, CommandLen,
                                     buffer, ReplyLen) = ReplyLen;
    if not Result then FillByte(buffer, 4, $FF);
  end;

begin
  FillByte(ID.ID9FH, SizeOf(ID.ID9FH), $FF);
  FillByte(ID.ID90H, SizeOf(ID.ID90H), $FF);
  ID.IDABH := $FF;
  FillByte(ID.ID15H, SizeOf(ID.ID15H), $FF);
  ID.Got9F := False;
  ID.Got90 := False;
  ID.GotAB := False;
  ID.Got15 := False;
  Result := -1;

  //9F
  FillByte(command, SizeOf(command), 0);
  command[0] := $9F;
  ID.Got9F := ReadCommand(1, 3);
  move(buffer, ID.ID9FH, 3);
  if not ID.Got9F then Exit;

  //จำรหัสผู้ผลิตไว้ ทุกคำสั่งที่ต่างกันตามยี่ห้อจะดูจากค่านี้
  //00 กับ FF แปลว่าไม่มีชิปตอบ อย่าจำไว้เพราะจะทำให้เลือก opcode ผิด
  if ID.Got9F and (ID.ID9FH[0] <> $00) and (ID.ID9FH[0] <> $FF) then
    Chip25ManufID := ID.ID9FH[0];

  //90
  FillByte(command, SizeOf(command), 0);
  command[0] := $90;
  ID.Got90 := ReadCommand(4, 2);
  move(buffer, ID.ID90H, 2);
  if not ID.Got90 then Exit;

  //AB
  FillByte(command, SizeOf(command), 0);
  command[0] := $AB;
  ID.GotAB := ReadCommand(4, 1);
  move(buffer, ID.IDABH, 1);
  if not ID.GotAB then Exit;

  //15
  FillByte(command, SizeOf(command), 0);
  command[0] := $15;
  ID.Got15 := ReadCommand(1, 2);
  move(buffer, ID.ID15H, 2);
  if not ID.Got15 then Exit;

  //Public compatibility: this function has always counted successful ID
  //commands rather than bytes.
  Result := 4;
end;

function UsbAsp25_ReadJEDEC9FExact(var ID: array of byte): boolean;
var
  Command: byte;
begin
  Result := False;
  if Length(ID) < 3 then Exit;

  FillByte(ID[0], 3, $FF);
  Command := $9F;
  Result := SPI25CommandReadExact(1, 0, Command, 1, ID, 3) = 3;
  if not Result then FillByte(ID[0], 3, $FF);
end;

//อ่านตาราง SFDP (JESD216) opcode 5Ah: แอดเดรส 3 ไบต์ + ไบต์หลอก 1 ไบต์
function UsbAsp25_ReadSFDP(Addr: longword; var buffer: array of byte; bufflen: integer): integer;
var
  buff: array[0..4] of byte;
begin
  if (not SPI25BufferLengthValid(bufflen, Length(buffer))) or
     (not SPI25AddressRangeValid(Addr, bufflen, False)) then Exit(-1);

  buff[0] := $5A;
  buff[1] := hi(addr);
  buff[2] := hi(lo(addr));
  buff[3] := lo(addr);
  buff[4] := $FF; //dummy

  Result := SPI25CommandReadExact(1, 0, buff, 5, buffer, bufflen);
end;

//เลขประจำตัวจากโรงงาน opcode 4Bh: ไบต์หลอก 4 ไบต์ แล้วตามด้วยข้อมูล 8 ไบต์
function UsbAsp25_ReadUniqueID(var buffer: array of byte): integer;
var
  buff: array[0..4] of byte;
begin
  if Length(buffer) < 8 then Exit(-1);

  buff[0] := $4B;
  buff[1] := $FF;
  buff[2] := $FF;
  buff[3] := $FF;
  buff[4] := $FF;

  Result := SPI25CommandReadExact(1, 0, buff, 5, buffer, 8);
end;

//Winbond W74M Authentication Flash opcode 96h: ไบต์หลอก แล้วตามด้วย
//Status[7:0] Tag[95:0] CounterData[31:0] Signature[255:0] รวม 49 ไบต์
//เป็นคำสั่งเดียวในตระกูลนี้ที่ไม่ต้องมีลายเซ็น HMAC
function UsbAsp25_ReadAuthStatus(var buffer: array of byte; bufflen: integer): integer;
var
  buff: array[0..1] of byte;
begin
  if not SPI25BufferLengthValid(bufflen, Length(buffer)) then Exit(-1);

  buff[0] := $96;
  buff[1] := $FF; //dummy

  Result := SPI25CommandReadExact(1, 0, buff, 2, buffer, bufflen);
end;

//Security register (OTP) opcode 48h: แอดเดรส 3 ไบต์ + ไบต์หลอก 1 ไบต์
//ปกติมี 3 หน้า หน้าละ 256 ไบต์ ที่แอดเดรส 001000h, 002000h, 003000h
function UsbAsp25_ReadSecReg(Addr: longword; var buffer: array of byte; bufflen: integer): integer;
var
  buff: array[0..4] of byte;
begin
  if (not SPI25BufferLengthValid(bufflen, Length(buffer))) or
     (not SPI25AddressRangeValid(Addr, bufflen, False)) then Exit(-1);

  buff[0] := $48;
  buff[1] := hi(addr);
  buff[2] := hi(lo(addr));
  buff[3] := lo(addr);
  buff[4] := $FF; //dummy

  Result := SPI25CommandReadExact(1, 0, buff, 5, buffer, bufflen);
end;

//เขียน security register opcode 42h โดยผู้เรียกต้องสั่ง WREN มาก่อน
function UsbAsp25_WriteSecReg(Addr: longword; buffer: array of byte; bufflen: integer): integer;
var
  buff: array[0..3] of byte;
begin
  if RefusedBySafeMode(gaWrite) then Exit(-1);
  if (not SPI25BufferLengthValid(bufflen, Length(buffer))) or
     (not SPI25AddressRangeValid(Addr, bufflen, False)) then Exit(-1);

  buff[0] := $42;
  buff[1] := hi(addr);
  buff[2] := hi(lo(addr));
  buff[3] := lo(addr);

  Result := SPI25CommandWriteExact(buff, 4, buffer, bufflen);
end;

//ลบ security register opcode 44h โดยผู้เรียกต้องสั่ง WREN มาก่อน
function UsbAsp25_EraseSecReg(Addr: longword): integer;
var
  buff: array[0..3] of byte;
begin
  if RefusedBySafeMode(gaErase) then Exit(-1);
  if not SPI25AddressRangeValid(Addr, 1, False) then Exit(-1);

  buff[0] := $44;
  buff[1] := hi(addr);
  buff[2] := hi(lo(addr));
  buff[3] := lo(addr);

  result := SPIWrite(1, 4, buff);
end;

//ลบหนึ่งเซกเตอร์หรือหนึ่งบล็อก opcode: 20h(4K), 52h(32K), D8h(64K)
//ผู้เรียกต้องสั่ง WREN มาก่อน
function UsbAsp25_EraseSector(Opcode: byte; Addr: longword; FourByteAddr: boolean): integer;
var
  buff: array[0..4] of byte;
begin
  if RefusedBySafeMode(gaErase) then Exit(-1);
  if not SPI25AddressRangeValid(Addr, 1, FourByteAddr) then Exit(-1);

  buff[0] := Opcode;

  if FourByteAddr then
  begin
    buff[1] := hi(hi(addr));
    buff[2] := lo(hi(addr));
    buff[3] := hi(lo(addr));
    buff[4] := lo(lo(addr));
    result := SPIWrite(1, 5, buff);
  end
  else
  begin
    buff[1] := hi(addr);
    buff[2] := hi(lo(addr));
    buff[3] := lo(addr);
    result := SPIWrite(1, 4, buff);
  end;
end;

//คืนจำนวนไบต์ที่อ่านได้
function UsbAsp25_Read(Opcode: byte; Addr: longword; var buffer: array of byte; bufflen: integer): integer;
var
  buff: array[0..3] of byte;
begin
  if (not SPI25BufferLengthValid(bufflen, Length(buffer))) or
     (not SPI25AddressRangeValid(Addr, bufflen, False)) then Exit(-1);

  buff[0] := Opcode;
  buff[1] := hi(addr);
  buff[2] := hi(lo(addr));
  buff[3] := lo(addr);

  Result := SPI25CommandReadExact(1, 0, buff, 4, buffer, bufflen);
end;

function UsbAsp25_Read32bitAddr(Opcode: byte; Addr: longword; var buffer: array of byte; bufflen: integer): integer;
var
  buff: array[0..4] of byte;
begin
  if (not SPI25BufferLengthValid(bufflen, Length(buffer))) or
     (not SPI25AddressRangeValid(Addr, bufflen, True)) then Exit(-1);

  buff[0] := Opcode;
  buff[1] := hi(hi(addr));
  buff[2] := lo(hi(addr));
  buff[3] := hi(lo(addr));
  buff[4] := lo(lo(addr));

  Result := SPI25CommandReadExact(1, 0, buff, 5, buffer, bufflen);
end;

//อ่านเร็ว opcode + แอดเดรส 3 ไบต์ + ไบต์หลอก 1 ไบต์
function UsbAsp25_ReadFast(Opcode: byte; Addr: longword; var buffer: array of byte; bufflen: integer): integer;
var
  buff: array[0..4] of byte;
begin
  if (not SPI25BufferLengthValid(bufflen, Length(buffer))) or
     (not SPI25AddressRangeValid(Addr, bufflen, False)) then Exit(-1);

  buff[0] := Opcode;
  buff[1] := hi(addr);
  buff[2] := hi(lo(addr));
  buff[3] := lo(addr);
  buff[4] := $FF; //dummy

  Result := SPI25CommandReadExact(1, 0, buff, 5, buffer, bufflen);
end;

//อ่านเร็ว opcode + แอดเดรส 4 ไบต์ + ไบต์หลอก 1 ไบต์
function UsbAsp25_ReadFast32bitAddr(Opcode: byte; Addr: longword; var buffer: array of byte; bufflen: integer): integer;
var
  buff: array[0..5] of byte;
begin
  if (not SPI25BufferLengthValid(bufflen, Length(buffer))) or
     (not SPI25AddressRangeValid(Addr, bufflen, True)) then Exit(-1);

  buff[0] := Opcode;
  buff[1] := hi(hi(addr));
  buff[2] := lo(hi(addr));
  buff[3] := hi(lo(addr));
  buff[4] := lo(lo(addr));
  buff[5] := $FF; //dummy

  Result := SPI25CommandReadExact(1, 0, buff, 6, buffer, bufflen);
end;

function UsbAsp25_Wren(): integer;
var
  buff: byte;
begin
  buff:= $06;
  result := SPIWrite(1, 1, buff);
end;

function UsbAsp25_WrenChecked(out WEL: boolean): boolean;
var
  sreg: byte;
  n: integer;
begin
  WEL := False;

  if UsbAsp25_Wren <> 1 then Exit(False);

  sreg := $FF;
  n := UsbAsp25_ReadSR(sreg);

  //อ่าน status register ไม่ได้ หรือได้ FF ล้วน แปลว่าไม่มีใครตอบอยู่ตรงนั้น
  //ไม่ใช่ว่า WEL ติด ทั้งที่บิต 1 ของ FF ก็เป็นหนึ่งเหมือนกัน
  if (n <= 0) or (sreg = $FF) then Exit(False);

  WEL := IsBitSet(sreg, 1);
  Result := WEL;
end;

function UsbAsp25_SoftReset(): integer;
var
  buff: byte;
begin
  buff := $66;
  if SPIWrite(1, 1, buff) <> 1 then Exit(-1);
  buff := $99;
  Result := SPIWrite(1, 1, buff);
  //ชิปต้องการเวลาตั้งตัวหลังรีเซ็ต ดาต้าชีตให้ไว้ราว 30 ไมโครวินาที
  sleep(2);
end;

function UsbAsp25_ExitQPI(): integer;
var
  buff: byte;
begin
  buff := $FF;
  Result := SPIWrite(1, 1, buff);
  sleep(1);
end;

function UsbAsp25_ReadVendorStatus(Opcode: byte; out Value: byte): boolean;
var
  n: integer;
begin
  Value := $FF;
  if Opcode = 0 then Exit(False);

  n := SPI25CommandReadExact(1, 0, Opcode, 1, Value, 1);

  Result := n = 1;
end;

function UsbAsp25_ClearFlagStatus(): integer;
var
  buff: byte;
begin
  buff := $50;
  Result := SPIWrite(1, 1, buff);
end;

function UsbAsp25_GlobalUnlock(): integer;
var
  buff: byte;
begin
  if RefusedBySafeMode(gaUnlock) then Exit(-1);
  buff := $98;
  Result := SPIWrite(1, 1, buff);
end;

function UsbAsp25_Wrdi(): integer;
var
  buff: byte;
begin
  buff:= $04;
  result := SPIWrite(1, 1, buff);
end;

//ลบทั้งชิป
//C7h เป็นคำสั่งมาตรฐานที่ชิปตระกูล 25 แทบทุกตัวรับ ส่วน 62h กับ 60h
//เป็นของเฉพาะยี่ห้อ เดิมโปรแกรมยิงทั้งสามตัวใส่ชิปทุกตัว ซึ่งแปลว่าชิป
//ที่ไม่ได้นิยาม opcode เหล่านั้นจะได้รับคำสั่งที่ไม่รู้จักก่อนคำสั่งจริง
function UsbAsp25_ChipErase(): integer;
var
  buff: byte;
begin
  if RefusedBySafeMode(gaErase) then Exit(-1);
  //Atmel AT25F รุ่นเก่าลบทั้งชิปด้วย 62h เท่านั้น
  if Chip25ManufID = $1F then
  begin
    if UsbAsp25_Wren <> 1 then Exit(-1);
    buff := $62;
    if SPIWrite(1, 1, buff) <> 1 then Exit(-1);
  end;

  //SST ใช้ 60h ซึ่งเป็นคำสั่งลบทั้งชิปที่ถูกต้องของยี่ห้อนี้
  if Chip25ManufID = $BF then
  begin
    if UsbAsp25_Wren <> 1 then Exit(-1);
    buff := $60;
    if SPIWrite(1, 1, buff) <> 1 then Exit(-1);
  end;

  //WEL ถูกล้างทุกครั้งที่คำสั่งลบเริ่มทำงาน จึงต้องสั่งใหม่ก่อน C7h
  if UsbAsp25_Wren <> 1 then Exit(-1);
  buff := $C7;
  result := SPIWrite(1, 1, buff);
end;

//คำสั่งที่ต้องนำหน้า Write Status Register
//  06h WREN                                  ค่าที่เขียนอยู่ถาวร
//  50h Write Enable for Volatile Status Reg  ค่าที่เขียนหายเมื่อตัดไฟ
//เดิมส่ง 50h เสมอหลังจากที่ผู้เรียกส่ง 06h ไปแล้ว ตัวหลังชนะ ผลคือการ
//ปลดล็อกกลับมาล็อกเองทุกครั้งที่ถอดชิปออกแล้วเสียบใหม่
function SendSRWriteEnable(Volatile: boolean): boolean;
var
  buff: byte;
begin
  Result := False;
  if Volatile then
  begin
    buff := $50;
    Result := SPIWrite(1, 1, buff) = 1;
    Exit;
  end;

  //SFDP บอกมาตรง ๆ ว่าชิปตัวนี้ต้องการอะไร
  if Chip25SRWrenOpcode = $50 then
  begin
    buff := $50;
    Result := SPIWrite(1, 1, buff) = 1;
    Exit;
  end;

  //SST รุ่นเก่าไม่มี SFDP และรับเฉพาะ 50h
  if (Chip25SRWrenOpcode = 0) and (Chip25ManufID = $BF) then
  begin
    buff := $50;
    Result := SPIWrite(1, 1, buff) = 1;
    Exit;
  end;

  Result := UsbAsp25_Wren = 1;
end;

function UsbAsp25_WriteSR(sreg: byte; opcode: byte = $01; Volatile: boolean = False): integer;
var
  buff: array[0..1] of byte;
begin
  if RefusedBySafeMode(gaWriteStatusRegister) then Exit(-1);
  if not SendSRWriteEnable(Volatile) then Exit(-1);

  Buff[0] := opcode;
  Buff[1] := sreg;
  result := SPIWrite(1, 2, buff);
end;

function UsbAsp25_WriteSR_2byte(sreg1, sreg2: byte; Volatile: boolean = False): integer;
var
  buff: array[0..2] of byte;
begin
  if RefusedBySafeMode(gaWriteStatusRegister) then Exit(-1);
  if not SendSRWriteEnable(Volatile) then Exit(-1);

  //กรณีที่ status register ยาว 2 ไบต์
  Buff[0] := $01;
  Buff[1] := sreg1;
  Buff[2] := sreg2;
  result := SPIWrite(1, 3, buff);
end;

function UsbAsp25_ReadSR(var sreg: byte; opcode: byte = $05): integer;
begin
  Result := SPI25CommandReadExact(1, 0, opcode, 1, sreg, 1);
end;

//คืนจำนวนไบต์ที่เขียนได้
function UsbAsp25_Write(Opcode: byte; Addr: longword; buffer: array of byte; bufflen: integer): integer;
var
  buff: array[0..3] of byte;
begin
  if RefusedBySafeMode(gaWrite) then Exit(-1);
  if (not SPI25BufferLengthValid(bufflen, Length(buffer))) or
     (not SPI25AddressRangeValid(Addr, bufflen, False)) then Exit(-1);

  buff[0] := Opcode;
  buff[1] := lo(hi(addr));
  buff[2] := hi(lo(addr));
  buff[3] := lo(lo(addr));

  Result := SPI25CommandWriteExact(buff, 4, buffer, bufflen);
end;

function UsbAsp25_Write32bitAddr(Opcode: byte; Addr: longword; buffer: array of byte; bufflen: integer): integer;
var
  buff: array[0..4] of byte;
begin
  if RefusedBySafeMode(gaWrite) then Exit(-1);
  if (not SPI25BufferLengthValid(bufflen, Length(buffer))) or
     (not SPI25AddressRangeValid(Addr, bufflen, True)) then Exit(-1);

  buff[0] := Opcode;
  buff[1] := hi(hi(addr));
  buff[2] := lo(hi(addr));
  buff[3] := hi(lo(addr));
  buff[4] := lo(lo(addr));

  Result := SPI25CommandWriteExact(buff, 5, buffer, bufflen);
end;

function UsbAsp25_WriteSSTB(Opcode: byte; Data: byte): integer;
var
  buff: array[0..1] of byte;
begin
  if RefusedBySafeMode(gaWrite) then Exit(-1);
  buff[0] := Opcode;
  buff[1] := Data;

  if SPIWrite(1, 2, buff) <> 2 then Exit(-1);
  Result := 1;
end;

function UsbAsp25_WriteSSTW(Opcode: byte; Data1, Data2: byte): integer;
var
  buff: array[0..2] of byte;
begin
  if RefusedBySafeMode(gaWrite) then Exit(-1);
  buff[0] := Opcode;
  buff[1] := Data1;
  buff[2] := Data2;

  if SPIWrite(1, 3, buff) <> 3 then Exit(-1);
  Result := 2;
end;

//เขียน bank register ของ Spansion บิต EXTADD เลือกโหมดแอดเดรส
function WriteBankRegister(ExtAddr: boolean): integer;
var
  buff: byte;
begin
  buff := $17;
  if SPIWrite(0, 1, buff) <> 1 then Exit(-1);
  if ExtAddr then buff := %10000000 else buff := 0;
  Result := SPIWrite(1, 1, buff);
end;

//เข้าโหมดแอดเดรส 4 ไบต์
//วิธีเข้าต่างกันไปตามยี่ห้อ SFDP DWORD-16 บอกไว้ว่าชิปตัวนี้รับวิธีไหน
//ถ้าไม่รู้ก็ใช้ WREN + B7h ซึ่งเป็นวิธีที่ชิปที่รองรับโหมดนี้แทบทุกตัวรับ
//และไม่ส่ง 17h ของ Spansion ใส่ชิปยี่ห้ออื่นอีกต่อไป
function UsbAsp25_EN4B(): integer;
var
  buff: byte;
begin
  Result := 0;

  case Chip25Entry4B of
    //ทำงานที่ 4 ไบต์อยู่แล้ว: สำเร็จโดยไม่ต้องส่งอะไร ผู้เรียกใช้เฟรม
    //สี่ไบต์ต่อได้เลย
    E4B_ALWAYS4B:
      Exit(1);

    //ไม่มีคำสั่งสลับที่ปลอดภัย: ล้มเหลวตรง ๆ ห้ามคืน "สำเร็จ" เพราะผู้เรียก
    //จะส่งเฟรมสี่ไบต์ใส่ชิปที่ยังตีความสามไบต์ แล้วคำสั่งลบ/เขียนจะลง
    //ผิดเซกเตอร์แบบเงียบ ๆ
    E4B_NONE:
      Exit;

    E4B_B7:
      begin
        buff := $B7;
        Result := SPIWrite(1, 1, buff);
      end;

    E4B_BANK17:
      Result := WriteBankRegister(True);

    E4B_EXTC5:
      begin
        if UsbAsp25_Wren <> 1 then Exit(-1);
        buff := $C5;
        if SPIWrite(0, 1, buff) <> 1 then Exit(-1);
        buff := 1;              //บิต A24 ของ extended address register
        Result := SPIWrite(1, 1, buff);
      end;

  else
    //E4B_WREN_B7 และกรณีที่ยังไม่รู้
    if UsbAsp25_Wren <> 1 then Exit(-1);
    buff := $B7;
    Result := SPIWrite(1, 1, buff);
    if Result <> 1 then Exit(-1);

    //Spansion, Cypress และ Infineon ใช้ bank register แทน B7h
    if Chip25ManufID = $01 then
      Result := WriteBankRegister(True);
  end;
end;

//ออกจากโหมดแอดเดรส 4 ไบต์
function UsbAsp25_EX4B(): integer;
var
  buff: byte;
begin
  Result := 0;

  case Chip25Entry4B of
    E4B_ALWAYS4B:
      Exit(1);

    E4B_NONE:
      Exit;

    E4B_BANK17:
      Result := WriteBankRegister(False);

    E4B_EXTC5:
      begin
        if UsbAsp25_Wren <> 1 then Exit(-1);
        buff := $C5;
        if SPIWrite(0, 1, buff) <> 1 then Exit(-1);
        buff := 0;
        Result := SPIWrite(1, 1, buff);
      end;

  else
    if UsbAsp25_Wren <> 1 then Exit(-1);
    buff := $E9;
    Result := SPIWrite(1, 1, buff);
    if Result <> 1 then Exit(-1);

    if Chip25ManufID = $01 then
      Result := WriteBankRegister(False);
  end;
end;

function SPIRead(CS: byte; BufferLen: integer; out buffer: array of byte): integer;
begin
  Result := -1;
  if not SPI25BufferLengthValid(BufferLen, Length(buffer)) then Exit;
  if BufferLen = 0 then Exit(0);

  Result := AsProgrammer.Programmer.SPIRead(CS, BufferLen, buffer);
  if Result <> BufferLen then
  begin
    FillByte(buffer[0], BufferLen, $FF);
    Result := -1;
  end;
end;

function SPIWrite(CS: byte; BufferLen: integer; buffer: array of byte): integer;
begin
  Result := -1;
  if not SPI25BufferLengthValid(BufferLen, Length(buffer)) then Exit;
  if BufferLen = 0 then Exit(0);

  Result := AsProgrammer.Programmer.SPIWrite(CS, BufferLen, buffer);
  if Result <> BufferLen then Result := -1;
end;

function SPIReadWrite(CSR: byte; CSW: byte; RBufferLen: integer; out rbuffer: array of byte; WBufferLen: integer; wbuffer: array of byte): integer;
var
  Sent, Got: integer;
begin
  Result := -1;
  if (WBufferLen < 1) or
     (not SPI25BufferLengthValid(WBufferLen, Length(wbuffer))) or
     (not SPI25BufferLengthValid(RBufferLen, Length(rbuffer))) then Exit;
  if RBufferLen = 0 then Exit(0);

  FillByte(rbuffer[0], RBufferLen, $FF);
  if AsProgrammer.Current_HW = CHW_BUZZPIRAT then
    Got := AsProgrammer.Programmer.SPIWriteRead(
      CSR, WBufferLen, wbuffer, RBufferLen, rbuffer)
  else
  begin
    Sent := SPIWrite(CSW, WBufferLen, wbuffer);
    if Sent <> WBufferLen then Exit;
    Got := SPIRead(CSR, RBufferLen, rbuffer);
  end;

  if Got <> RBufferLen then
  begin
    FillByte(rbuffer[0], RBufferLen, $FF);
    Exit;
  end;
  Result := RBufferLen;
end;

end.

