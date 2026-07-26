unit spi25;

{$mode objfpc}

interface

//หน่วยนี้ไม่พึ่ง LCL และไม่พึ่ง main โดยตั้งใจ
//ชั้นโปรโตคอลจึงเอาไปทดสอบกับฮาร์ดแวร์จำลองได้โดยไม่ต้องมีหน้าจอหรือชิปจริง
uses
  Classes, SysUtils, utilfunc, BaseHW;

const

  WT_PAGE = 0;
  WT_SSTB = 1;
  WT_SSTW = 2;

  //วิธีเข้าโหมดแอดเดรส 4 ไบต์ ค่ามาจาก SFDP หรือจากรหัสผู้ผลิต
  E4B_UNKNOWN = 0;   //ไม่รู้ ใช้ทางที่ปลอดภัยที่สุด
  E4B_NONE    = 1;   //ไม่ต้องสลับ ชิปอยู่ที่ 4 ไบต์อยู่แล้วหรือมีชุดคำสั่งเฉพาะ
  E4B_B7      = 2;   //ส่ง B7h ได้เลย
  E4B_WREN_B7 = 3;   //WREN ก่อนแล้วค่อย B7h
  E4B_BANK17  = 4;   //bank register แบบ Spansion opcode 17h
  E4B_EXTC5   = 5;   //extended address register opcode C5h
  E4B_NVB1    = 6;   //nonvolatile configuration register opcode B1h

type

  MEMORY_ID = record
    ID9FH: array[0..2] of byte;
    ID90H: array[0..1] of byte;
    IDABH: byte;
    ID15H: array[0..1] of byte;
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

//ลืมสิ่งที่รู้ทั้งหมด ต้องเรียกเมื่อเปลี่ยนชิปหรือเปลี่ยนซ็อกเก็ต
procedure Reset25ChipHints;

function UsbAsp25_Busy(): boolean;

function EnterProgMode25(spiSpeed: integer; SendAB: boolean = false): boolean;
procedure ExitProgMode25;

function UsbAsp25_Read(Opcode: Byte; Addr: longword; var buffer: array of byte; bufflen: integer): integer;
function UsbAsp25_Read32bitAddr(Opcode: byte; Addr: longword; var buffer: array of byte; bufflen: integer): integer;
function UsbAsp25_Write(Opcode: byte; Addr: longword; buffer: array of byte; bufflen: integer): integer;
function UsbAsp25_Write32bitAddr(Opcode: byte; Addr: longword; buffer: array of byte; bufflen: integer): integer;

function UsbAsp25_ReadID(var ID: MEMORY_ID): integer;
function UsbAsp25_ReadSFDP(Addr: longword; var buffer: array of byte; bufflen: integer): integer;
function UsbAsp25_ReadUniqueID(var buffer: array of byte): integer;
function UsbAsp25_ReadAuthStatus(var buffer: array of byte; bufflen: integer): integer;
function UsbAsp25_ReadSecReg(Addr: longword; var buffer: array of byte; bufflen: integer): integer;
function UsbAsp25_WriteSecReg(Addr: longword; buffer: array of byte; bufflen: integer): integer;
function UsbAsp25_EraseSecReg(Addr: longword): integer;

function UsbAsp25_Wren(): integer;
function UsbAsp25_Wrdi(): integer;
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

procedure Reset25ChipHints;
begin
  Chip25ManufID := 0;
  Chip25Entry4B := E4B_UNKNOWN;
  Chip25SRWrenOpcode := 0;
  Chip25SFDPRead := False;
end;

//รอจนกว่าชิปจะพร้อม
function UsbAsp25_Busy: boolean;
var
  sreg: byte;
begin
  Result := True;
  sreg := $FF;

  UsbAsp25_ReadSR(sreg);
  if not IsBitSet(sreg, 0) then Result := False;
end;

//เข้าสู่โหมดโปรแกรม
function EnterProgMode25(spiSpeed: integer; SendAB: boolean = false): boolean;
begin
  result := AsProgrammer.Programmer.SPIInit(spiSpeed);
  sleep(50);

  //ปลุกชิปจาก power-down
  if SendAB then SPIWrite(1, 1, $AB);
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
  buffer: array[0..3] of byte;
begin
  //9F
  buffer[0] := $9F;
  SPIWrite(0, 1, buffer);
  FillByte(buffer, 4, $FF);
  result := SPIRead(1, 3, buffer);
  move(buffer, ID.ID9FH, 3);

  //จำรหัสผู้ผลิตไว้ ทุกคำสั่งที่ต่างกันตามยี่ห้อจะดูจากค่านี้
  //00 กับ FF แปลว่าไม่มีชิปตอบ อย่าจำไว้เพราะจะทำให้เลือก opcode ผิด
  if (ID.ID9FH[0] <> $00) and (ID.ID9FH[0] <> $FF) then
    Chip25ManufID := ID.ID9FH[0];
  //90
  FillByte(buffer, 4, 0);
  buffer[0] := $90;
  SPIWrite(0, 4, buffer);
  result := SPIRead(1, 2, buffer);
  move(buffer, ID.ID90H, 2);
  //AB
  FillByte(buffer, 4, 0);
  buffer[0] := $AB;
  SPIWrite(0, 4, buffer);
  result := SPIRead(1, 1, buffer);
  move(buffer, ID.IDABH, 1);
  //15
  buffer[0] := $15;
  SPIWrite(0, 1, buffer);
  FillByte(buffer, 4, $FF);
  result := SPIRead(1, 2, buffer);
  move(buffer, ID.ID15H, 2);
end;

//อ่านตาราง SFDP (JESD216) opcode 5Ah: แอดเดรส 3 ไบต์ + ไบต์หลอก 1 ไบต์
function UsbAsp25_ReadSFDP(Addr: longword; var buffer: array of byte; bufflen: integer): integer;
var
  buff: array[0..4] of byte;
begin
  buff[0] := $5A;
  buff[1] := hi(addr);
  buff[2] := hi(lo(addr));
  buff[3] := lo(addr);
  buff[4] := $FF; //dummy

  if AsProgrammer.Current_HW = CHW_BUZZPIRAT then
  begin
    result := AsProgrammer.Programmer.SPIWriteRead(1, 5, buff, bufflen, buffer);
  end
  else
  begin
    SPIWrite(0, 5, buff);
    result := SPIRead(1, bufflen, buffer);
  end;
end;

//เลขประจำตัวจากโรงงาน opcode 4Bh: ไบต์หลอก 4 ไบต์ แล้วตามด้วยข้อมูล 8 ไบต์
function UsbAsp25_ReadUniqueID(var buffer: array of byte): integer;
var
  buff: array[0..4] of byte;
begin
  buff[0] := $4B;
  buff[1] := $FF;
  buff[2] := $FF;
  buff[3] := $FF;
  buff[4] := $FF;

  if AsProgrammer.Current_HW = CHW_BUZZPIRAT then
  begin
    result := AsProgrammer.Programmer.SPIWriteRead(1, 5, buff, 8, buffer);
  end
  else
  begin
    SPIWrite(0, 5, buff);
    result := SPIRead(1, 8, buffer);
  end;
end;

//Winbond W74M Authentication Flash opcode 96h: ไบต์หลอก แล้วตามด้วย
//Status[7:0] Tag[95:0] CounterData[31:0] Signature[255:0] รวม 49 ไบต์
//เป็นคำสั่งเดียวในตระกูลนี้ที่ไม่ต้องมีลายเซ็น HMAC
function UsbAsp25_ReadAuthStatus(var buffer: array of byte; bufflen: integer): integer;
var
  buff: array[0..1] of byte;
begin
  buff[0] := $96;
  buff[1] := $FF; //dummy

  if AsProgrammer.Current_HW = CHW_BUZZPIRAT then
  begin
    result := AsProgrammer.Programmer.SPIWriteRead(1, 2, buff, bufflen, buffer);
  end
  else
  begin
    SPIWrite(0, 2, buff);
    result := SPIRead(1, bufflen, buffer);
  end;
end;

//Security register (OTP) opcode 48h: แอดเดรส 3 ไบต์ + ไบต์หลอก 1 ไบต์
//ปกติมี 3 หน้า หน้าละ 256 ไบต์ ที่แอดเดรส 001000h, 002000h, 003000h
function UsbAsp25_ReadSecReg(Addr: longword; var buffer: array of byte; bufflen: integer): integer;
var
  buff: array[0..4] of byte;
begin
  buff[0] := $48;
  buff[1] := hi(addr);
  buff[2] := hi(lo(addr));
  buff[3] := lo(addr);
  buff[4] := $FF; //dummy

  if AsProgrammer.Current_HW = CHW_BUZZPIRAT then
  begin
    result := AsProgrammer.Programmer.SPIWriteRead(1, 5, buff, bufflen, buffer);
  end
  else
  begin
    SPIWrite(0, 5, buff);
    result := SPIRead(1, bufflen, buffer);
  end;
end;

//เขียน security register opcode 42h โดยผู้เรียกต้องสั่ง WREN มาก่อน
function UsbAsp25_WriteSecReg(Addr: longword; buffer: array of byte; bufflen: integer): integer;
var
  buff: array[0..3] of byte;
begin
  buff[0] := $42;
  buff[1] := hi(addr);
  buff[2] := hi(lo(addr));
  buff[3] := lo(addr);

  SPIWrite(0, 4, buff);
  result := SPIWrite(1, bufflen, buffer);
end;

//ลบ security register opcode 44h โดยผู้เรียกต้องสั่ง WREN มาก่อน
function UsbAsp25_EraseSecReg(Addr: longword): integer;
var
  buff: array[0..3] of byte;
begin
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

  buff[0] := Opcode;
  buff[1] := hi(addr);
  buff[2] := hi(lo(addr));
  buff[3] := lo(addr);

  if AsProgrammer.Current_HW = CHW_BUZZPIRAT then
  begin
    result := AsProgrammer.Programmer.SPIWriteRead(1, 4, buff, bufflen, buffer);
  end
  else
  begin
      SPIWrite(0, 4, buff);
      result := SPIRead(1, bufflen, buffer);
  end;
end;

function UsbAsp25_Read32bitAddr(Opcode: byte; Addr: longword; var buffer: array of byte; bufflen: integer): integer;
var
  buff: array[0..4] of byte;
begin

  buff[0] := Opcode;
  buff[1] := hi(hi(addr));
  buff[2] := lo(hi(addr));
  buff[3] := hi(lo(addr));
  buff[4] := lo(lo(addr));

  if AsProgrammer.Current_HW = CHW_BUZZPIRAT then
  begin
    result := AsProgrammer.Programmer.SPIWriteRead(1, 5, buff, bufflen, buffer);
  end
  else
  begin
      SPIWrite(0, 5, buff);
      result := SPIRead(1, bufflen, buffer);
  end;
end;

function UsbAsp25_Wren(): integer;
var
  buff: byte;
begin
  buff:= $06;
  result := SPIWrite(1, 1, buff);
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
  //Atmel AT25F รุ่นเก่าลบทั้งชิปด้วย 62h เท่านั้น
  if Chip25ManufID = $1F then
  begin
    UsbAsp25_Wren;
    buff := $62;
    SPIWrite(1, 1, buff);
  end;

  //SST ใช้ 60h ซึ่งเป็นคำสั่งลบทั้งชิปที่ถูกต้องของยี่ห้อนี้
  if Chip25ManufID = $BF then
  begin
    UsbAsp25_Wren;
    buff := $60;
    SPIWrite(1, 1, buff);
  end;

  //WEL ถูกล้างทุกครั้งที่คำสั่งลบเริ่มทำงาน จึงต้องสั่งใหม่ก่อน C7h
  UsbAsp25_Wren;
  buff := $C7;
  result := SPIWrite(1, 1, buff);
end;

//คำสั่งที่ต้องนำหน้า Write Status Register
//  06h WREN                                  ค่าที่เขียนอยู่ถาวร
//  50h Write Enable for Volatile Status Reg  ค่าที่เขียนหายเมื่อตัดไฟ
//เดิมส่ง 50h เสมอหลังจากที่ผู้เรียกส่ง 06h ไปแล้ว ตัวหลังชนะ ผลคือการ
//ปลดล็อกกลับมาล็อกเองทุกครั้งที่ถอดชิปออกแล้วเสียบใหม่
procedure SendSRWriteEnable(Volatile: boolean);
var
  buff: byte;
begin
  if Volatile then
  begin
    buff := $50;
    SPIWrite(1, 1, buff);
    Exit;
  end;

  //SFDP บอกมาตรง ๆ ว่าชิปตัวนี้ต้องการอะไร
  if Chip25SRWrenOpcode = $50 then
  begin
    buff := $50;
    SPIWrite(1, 1, buff);
    Exit;
  end;

  //SST รุ่นเก่าไม่มี SFDP และรับเฉพาะ 50h
  if (Chip25SRWrenOpcode = 0) and (Chip25ManufID = $BF) then
  begin
    buff := $50;
    SPIWrite(1, 1, buff);
    Exit;
  end;

  UsbAsp25_Wren;
end;

function UsbAsp25_WriteSR(sreg: byte; opcode: byte = $01; Volatile: boolean = False): integer;
var
  buff: array[0..1] of byte;
begin
  SendSRWriteEnable(Volatile);

  Buff[0] := opcode;
  Buff[1] := sreg;
  result := SPIWrite(1, 2, buff);
end;

function UsbAsp25_WriteSR_2byte(sreg1, sreg2: byte; Volatile: boolean = False): integer;
var
  buff: array[0..2] of byte;
begin
  SendSRWriteEnable(Volatile);

  //กรณีที่ status register ยาว 2 ไบต์
  Buff[0] := $01;
  Buff[1] := sreg1;
  Buff[2] := sreg2;
  result := SPIWrite(1, 3, buff);
end;

function UsbAsp25_ReadSR(var sreg: byte; opcode: byte = $05): integer;
begin
  if AsProgrammer.Current_HW = CHW_BUZZPIRAT then
    begin
      result := AsProgrammer.Programmer.SPIWriteRead(1, 1, opcode, 1, sreg);
    end
    else
    begin
         SPIWrite(0, 1, opcode);
         result := SPIRead(1, 1, sreg);
    end;
end;

//คืนจำนวนไบต์ที่เขียนได้
function UsbAsp25_Write(Opcode: byte; Addr: longword; buffer: array of byte; bufflen: integer): integer;
var
  buff: array[0..3] of byte;
begin

  buff[0] := Opcode;
  buff[1] := lo(hi(addr));
  buff[2] := hi(lo(addr));
  buff[3] := lo(lo(addr));

  SPIWrite(0, 4, buff);
  result := SPIWrite(1, bufflen, buffer);
end;

function UsbAsp25_Write32bitAddr(Opcode: byte; Addr: longword; buffer: array of byte; bufflen: integer): integer;
var
  buff: array[0..4] of byte;
begin

  buff[0] := Opcode;
  buff[1] := hi(hi(addr));
  buff[2] := lo(hi(addr));
  buff[3] := hi(lo(addr));
  buff[4] := lo(lo(addr));

  SPIWrite(0, 5, buff);
  result := SPIWrite(1, bufflen, buffer);
end;

function UsbAsp25_WriteSSTB(Opcode: byte; Data: byte): integer;
var
  buff: array[0..1] of byte;
begin
  buff[0] := Opcode;
  buff[1] := Data;

  result := SPIWrite(1, 2, buff)-1;
end;

function UsbAsp25_WriteSSTW(Opcode: byte; Data1, Data2: byte): integer;
var
  buff: array[0..2] of byte;
begin
  buff[0] := Opcode;
  buff[1] := Data1;
  buff[2] := Data2;

  result := SPIWrite(1, 3, buff)-1;
end;

//เขียน bank register ของ Spansion บิต EXTADD เลือกโหมดแอดเดรส
function WriteBankRegister(ExtAddr: boolean): integer;
var
  buff: byte;
begin
  buff := $17;
  SPIWrite(0, 1, buff);
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
        UsbAsp25_Wren;
        buff := $C5;
        SPIWrite(0, 1, buff);
        buff := 1;              //บิต A24 ของ extended address register
        Result := SPIWrite(1, 1, buff);
      end;

    E4B_NVB1:
      begin
        UsbAsp25_Wren;
        buff := $B1;
        SPIWrite(0, 1, buff);
        buff := 0;              //บิต 0 = 0 คือโหมด 4 ไบต์บน Micron
        SPIWrite(0, 1, buff);
        buff := $FF;
        Result := SPIWrite(1, 1, buff);
      end;

  else
    //E4B_WREN_B7 และกรณีที่ยังไม่รู้
    UsbAsp25_Wren;
    buff := $B7;
    Result := SPIWrite(1, 1, buff);

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
    E4B_NONE:
      Exit;

    E4B_BANK17:
      Result := WriteBankRegister(False);

    E4B_EXTC5:
      begin
        UsbAsp25_Wren;
        buff := $C5;
        SPIWrite(0, 1, buff);
        buff := 0;
        Result := SPIWrite(1, 1, buff);
      end;

  else
    UsbAsp25_Wren;
    buff := $E9;
    Result := SPIWrite(1, 1, buff);

    if Chip25ManufID = $01 then
      Result := WriteBankRegister(False);
  end;
end;

function SPIRead(CS: byte; BufferLen: integer; out buffer: array of byte): integer;
begin
  result := AsProgrammer.Programmer.SPIRead(CS, BufferLen, buffer);
end;

function SPIWrite(CS: byte; BufferLen: integer; buffer: array of byte): integer;
begin
  result := AsProgrammer.Programmer.SPIWrite(CS, BufferLen, buffer);
end;

function SPIReadWrite(CSR: byte; CSW: byte; RBufferLen: integer; out rbuffer: array of byte; WBufferLen: integer; wbuffer: array of byte): integer;
begin
  if AsProgrammer.Current_HW = CHW_BUZZPIRAT then
  begin
    result := AsProgrammer.Programmer.SPIWriteRead(1, WBufferLen, wbuffer, RBufferLen, rbuffer);
  end
  else
  begin
       SPIWrite(CSW, WBufferLen, wbuffer);
       result := SPIRead(CSR, RBufferLen, rbuffer);
  end;
end;

end.

