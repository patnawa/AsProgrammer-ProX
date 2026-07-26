unit spi25;

{$mode objfpc}

interface

uses
  Classes, Forms, SysUtils, utilfunc, BaseHW;

const

  WT_PAGE = 0;
  WT_SSTB = 1;
  WT_SSTW = 2;

type

  MEMORY_ID = record
    ID9FH: array[0..2] of byte;
    ID90H: array[0..1] of byte;
    IDABH: byte;
    ID15H: array[0..1] of byte;
  end;

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

function UsbAsp25_WriteSR(sreg: byte; opcode: byte = $01): integer;
function UsbAsp25_WriteSR_2byte(sreg1, sreg2: byte): integer;
function UsbAsp25_ReadSR(var sreg: byte; opcode: byte = $05): integer;

function UsbAsp25_WriteSSTB(Opcode: byte; Data: byte): integer;
function UsbAsp25_WriteSSTW(Opcode: byte; Data1, Data2: byte): integer;

function UsbAsp25_EN4B(): integer;
function UsbAsp25_EX4B(): integer;

function SPIRead(CS: byte; BufferLen: integer; out buffer: array of byte): integer;
function SPIWrite(CS: byte; BufferLen: integer; buffer: array of byte): integer;
function SPIReadWrite(CSR: byte; CSW: byte; RBufferLen: integer; out rbuffer: array of byte; WBufferLen: integer; wbuffer: array of byte): integer;

implementation

uses Main;

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

function UsbAsp25_ChipErase(): integer;
var
  buff: byte;
begin
  //Atmel บางรุ่นต้องใช้ 62H
  buff:= $62;
  SPIWrite(1, 1, buff);
  //SST รุ่นเก่าต้องใช้ 60H
  buff:= $60;
  SPIWrite(1, 1, buff);
  buff:= $C7;
  result := SPIWrite(1, 1, buff);
end;

function UsbAsp25_WriteSR(sreg: byte; opcode: byte = $01): integer;
var
  buff: array[0..1] of byte;
begin
  //SST รุ่นเก่าต้องสั่ง Enable-Write-Status-Register (50H) ก่อน
  Buff[0] := $50;
  SPIWrite(1, 1, buff);
  //
  Buff[0] := opcode;
  Buff[1] := sreg;
  result := SPIWrite(1, 2, buff);
end;

function UsbAsp25_WriteSR_2byte(sreg1, sreg2: byte): integer;
var
  buff: array[0..2] of byte;
begin
  //SST รุ่นเก่าต้องสั่ง Enable-Write-Status-Register (50H) ก่อน
  Buff[0] := $50;
  SPIWrite(1, 1, buff);

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

//เข้าโหมดแอดเดรส 4 ไบต์
function UsbAsp25_EN4B(): integer;
var
  buff: byte;
begin
  UsbAsp25_Wren;
  buff:= $B7;
  result := SPIWrite(1, 1, buff);
  //Access Spansion Bank Register to enable Extended address control bit (EXTADD) for 4-byte addressing
  buff:= $17;
  SPIWrite(0, 1, buff);
  buff:= %10000000; //EXTADD=1
  result := SPIWrite(1, 1, buff);
end;

//ออกจากโหมดแอดเดรส 4 ไบต์
function UsbAsp25_EX4B(): integer;
var
  buff: byte;
begin
  UsbAsp25_Wren;
  buff:= $E9;
  result := SPIWrite(1, 1, buff);
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

