unit i2c;

{$mode objfpc}

interface

uses
  Classes, SysUtils, DateUtils, utilfunc, safemode;

const

  //วิธีส่งแอดเดรสของเซลล์ไปยังชิป
  I2C_ADDR_TYPE_7BIT             = 0;
  I2C_ADDR_TYPE_1BYTE            = 1;
  I2C_ADDR_TYPE_1BYTE_1BIT       = 2;
  I2C_ADDR_TYPE_1BYTE_2BIT       = 3;
  I2C_ADDR_TYPE_1BYTE_3BIT       = 4;
  I2C_ADDR_TYPE_2BYTE            = 5;
  I2C_ADDR_TYPE_2BYTE_1BIT       = 6;

  //24LC1025 และญาติ ๆ 24AA1025 24FC1025
  //
  //ชิปพวกนี้มี 128KB ซึ่งต้องใช้แอดเดรส 17 บิต แต่ word address มีแค่ 16 บิต
  //บิตที่ 17 คือบิตเลือกบล็อก B0 ซึ่งอยู่ในไบต์คำสั่ง ไม่ใช่ในแอดเดรส
  //
  //ไบต์คำสั่งของตระกูลนี้คือ  1 0 1 0 B0 A2 A1 R/W
  //B0 จึงอยู่ที่บิต 3 ไม่ใช่บิต 1 แบบ I2C_ADDR_TYPE_2BYTE_1BIT
  //ซึ่งเป็นเหตุผลว่าทำไมชนิดเดิมใช้กับชิปตัวนี้ไม่ได้
  I2C_ADDR_TYPE_24LC1025         = 7;

  //ค่าเริ่มต้นของเวลารอให้ชิปเขียนเสร็จ ดาต้าชีตของ 24Cxx ส่วนใหญ่บอก 5ms
  //เผื่อไว้ให้มากกว่านั้นเพราะชิปเก่าและชิปราคาถูกช้ากว่าที่แจ้ง
  I2C_WRITE_CYCLE_MS             = 50;

type

  //แอดเดรสที่แตกออกมาแล้ว พร้อมส่งลงสาย
  TI2CAddr = record
    DevByte: byte;                    //ไบต์คำสั่ง บิต R/W เป็น 0
    AddrBytes: array[0..1] of byte;   //word address ไบต์สูงมาก่อน
    AddrLen: integer;                 //0, 1 หรือ 2
  end;

procedure EnterProgModeI2C();
function UsbAspI2C_BUSY(Address: byte): Boolean;

//แตกแอดเดรสออกเป็นไบต์คำสั่งกับ word address
//
//เดิมตรรกะก้อนนี้ถูกคัดลอกไว้สองที่ ทั้งในทางอ่านและทางเขียน ก้อนละเจ็ดสาขา
//แก้ที่หนึ่งแล้วลืมอีกที่คือความผิดพลาดที่รอเกิดอยู่แล้ว และทั้งสองก้อน
//ไม่มีสาขาสำรอง ชนิดแอดเดรสที่ไม่รู้จักจึงปล่อยให้ DevByte เป็นค่าขยะในสแตก
//แล้วส่งคำสั่งไปยังอุปกรณ์ที่ไม่ได้ตั้งใจ
//
//คืน False เมื่อไม่รู้จักชนิดแอดเดรส ผู้เรียกต้องหยุด ไม่ใช่เดาต่อ
function BuildI2CAddr(DevAddr, AddrType: byte; Address: longword;
  out A: TI2CAddr): boolean;

//จำนวนตำแหน่งสูงสุดที่รูปแบบแอดเดรสนี้อ้างถึงได้
//คืน 0 เมื่อไม่รู้จักรูปแบบ
function I2CAddrCapacity(AddrType: byte): longword;

//ตรวจทั้งต้นและปลายช่วงก่อนที่บิตสูงของแอดเดรสจะถูกตัดทิ้ง
function I2CAddressRangeValid(AddrType: byte; Address: longword;
  DataLen: integer): boolean;

//จำนวนไบต์ที่ส่งต่อเนื่องได้โดยไม่ข้ามขอบที่บิตแอดเดรสย้ายไปอยู่ใน
//control byte ชิปจะไม่ carry บิตข้ามขอบนี้ระหว่าง sequential read/write
function I2CChunkToBankBoundary(AddrType: byte; Address: longword;
  Requested: integer): integer;

function UsbAspI2C_Read(DevAddr, AddrType: byte; Address: longword;var buffer: array of byte; bufflen: integer): integer;
function UsbAspI2C_Write(DevAddr, AddrType: byte; Address: longword; buffer: array of byte; bufflen: integer): integer;

//รอให้รอบการเขียนภายในชิปจบ ด้วยการถามชิปว่าตอบรับหรือยัง
//
//หลังรับข้อมูลครบเพจ ชิปจะตัดตัวเองออกจากสายไปเขียนลงเซลล์จริง ระหว่างนั้น
//มันจะไม่ตอบรับไบต์คำสั่ง วิธีที่ดาต้าชีตบอกให้ใช้คือถามซ้ำจนกว่าจะตอบ
//ซึ่งเร็วกว่าการหน่วงเวลาตายตัว และไม่มีทางเผลอเขียนทับตอนที่ชิปยังไม่พร้อม
//
//คืน False เมื่อรอจนหมดเวลาแล้วชิปยังไม่ตอบ
function UsbAspI2C_WaitReady(DevByte: byte; TimeoutMs: integer): boolean;

//เหมือนด้านบน แต่สร้าง control byte จากแอดเดรสจริง จึง poll bank เดียวกับ
//คำสั่งเขียนที่เพิ่งส่งไป
function UsbAspI2C_WaitReadyAt(DevAddr, AddrType: byte; Address: longword;
  TimeoutMs: integer): boolean;

implementation

uses basehw;

procedure EnterProgModeI2C();
begin
  AsProgrammer.Programmer.I2CInit;
  sleep(50);
end;

function UsbAspI2C_BUSY(Address: byte): Boolean;
begin
  AsProgrammer.Programmer.I2CStart;
  //ACK polling ต้องเป็นคำสั่งเขียนเสมอ
  Result := not AsProgrammer.Programmer.I2CWriteByte(Address and $FE);
  AsProgrammer.Programmer.I2CStop;
end;

function UsbAspI2C_WaitReady(DevByte: byte; TimeoutMs: integer): boolean;
var
  Deadline: QWord;
begin
  if TimeoutMs < 0 then Exit(False);
  Deadline := GetTickCount64 + QWord(TimeoutMs);

  repeat
    if not UsbAspI2C_BUSY(DevByte) then Exit(True);
    if GetTickCount64 >= Deadline then Break;
    //ไม่ยิง USB/I2C แบบ tight loop จนกินทั้ง CPU และบัส
    Sleep(1);
  until False;

  Result := False;
end;

function I2CAddrCapacity(AddrType: byte): longword;
begin
  case AddrType of
    I2C_ADDR_TYPE_7BIT:       Result := 128;
    I2C_ADDR_TYPE_1BYTE:      Result := 256;
    I2C_ADDR_TYPE_1BYTE_1BIT: Result := 512;
    I2C_ADDR_TYPE_1BYTE_2BIT: Result := 1024;
    I2C_ADDR_TYPE_1BYTE_3BIT: Result := 2048;
    I2C_ADDR_TYPE_2BYTE:      Result := 65536;
    I2C_ADDR_TYPE_2BYTE_1BIT,
    I2C_ADDR_TYPE_24LC1025:   Result := 131072;
  else
    Result := 0;
  end;
end;

function I2CBankSize(AddrType: byte): longword;
begin
  case AddrType of
    I2C_ADDR_TYPE_7BIT:       Result := 128;
    I2C_ADDR_TYPE_1BYTE,
    I2C_ADDR_TYPE_1BYTE_1BIT,
    I2C_ADDR_TYPE_1BYTE_2BIT,
    I2C_ADDR_TYPE_1BYTE_3BIT: Result := 256;
    I2C_ADDR_TYPE_2BYTE,
    I2C_ADDR_TYPE_2BYTE_1BIT,
    I2C_ADDR_TYPE_24LC1025:   Result := 65536;
  else
    Result := 0;
  end;
end;

function I2CAddressRangeValid(AddrType: byte; Address: longword;
  DataLen: integer): boolean;
var
  Capacity: longword;
  EndAddr: QWord;
begin
  Result := False;
  if DataLen < 0 then Exit;

  Capacity := I2CAddrCapacity(AddrType);
  if Capacity = 0 then Exit;

  EndAddr := QWord(Address) + QWord(DataLen);
  Result := (Address < Capacity) and (EndAddr <= QWord(Capacity));
end;

function I2CChunkToBankBoundary(AddrType: byte; Address: longword;
  Requested: integer): integer;
var
  BankSize, Remain: longword;
begin
  Result := 0;
  if Requested <= 0 then Exit;

  BankSize := I2CBankSize(AddrType);
  if BankSize = 0 then Exit;

  Remain := BankSize - (Address mod BankSize);
  if QWord(Requested) < QWord(Remain) then
    Result := Requested
  else
    Result := integer(Remain);
end;

function BuildI2CAddr(DevAddr, AddrType: byte; Address: longword;
  out A: TI2CAddr): boolean;

  //ยกบิตที่ Bit ของแอดเดรสหน่วยความจำขึ้นไปไว้ในไบต์คำสั่งที่ตำแหน่ง DevBit
  procedure Lift(AddrBit, DevBit: byte);
  begin
    if ((Address shr AddrBit) and 1) <> 0 then
      A.DevByte := SetBit(A.DevByte, DevBit)
    else
      A.DevByte := ClearBit(A.DevByte, DevBit);
  end;

begin
  //Output ต้องอยู่ในสถานะปลอดภัยแม้ validation ล้มเหลวก่อนเข้า case
  A.DevByte := 0;
  A.AddrBytes[0] := 0;
  A.AddrBytes[1] := 0;
  A.AddrLen := 0;
  Result := False;

  //ห้ามปล่อยให้บิตสูงหายไปเงียบ ๆ แล้ววนกลับไปเขียนต้นชิป
  if not I2CAddressRangeValid(AddrType, Address, 0) then Exit;
  A.DevByte := DevAddr and $FE;
  Result := True;

  case AddrType of

    //ไม่มี word address เลย Address คือแอดเดรสของอุปกรณ์เอง
    //ใช้กับตัวสแกนหาอุปกรณ์บนสาย
    I2C_ADDR_TYPE_7BIT:
      A.DevByte := Byte(Address) shl 1;

    I2C_ADDR_TYPE_1BYTE:
      begin
        A.AddrBytes[0] := Byte(Address);
        A.AddrLen := 1;
      end;

    //ชิปเล็กที่แอดเดรสเกินหนึ่งไบต์ ส่วนที่เกินไปอยู่ในไบต์คำสั่ง
    I2C_ADDR_TYPE_1BYTE_1BIT:
      begin
        Lift(8, 1);
        A.AddrBytes[0] := Byte(Address);
        A.AddrLen := 1;
      end;

    I2C_ADDR_TYPE_1BYTE_2BIT:
      begin
        Lift(8, 1);
        Lift(9, 2);
        A.AddrBytes[0] := Byte(Address);
        A.AddrLen := 1;
      end;

    I2C_ADDR_TYPE_1BYTE_3BIT:
      begin
        Lift(8, 1);
        Lift(9, 2);
        Lift(10, 3);
        A.AddrBytes[0] := Byte(Address);
        A.AddrLen := 1;
      end;

    I2C_ADDR_TYPE_2BYTE:
      begin
        A.AddrBytes[0] := hi(Word(Address));
        A.AddrBytes[1] := lo(Word(Address));
        A.AddrLen := 2;
      end;

    //บิตที่ 17 อยู่ที่บิต 1 ของไบต์คำสั่ง
    I2C_ADDR_TYPE_2BYTE_1BIT:
      begin
        Lift(16, 1);
        A.AddrBytes[0] := hi(Word(Address));
        A.AddrBytes[1] := lo(Word(Address));
        A.AddrLen := 2;
      end;

    //24LC1025: ไบต์คำสั่งคือ 1 0 1 0 B0 A2 A1 R/W บิตเลือกบล็อกอยู่ที่บิต 3
    I2C_ADDR_TYPE_24LC1025:
      begin
        Lift(16, 3);
        A.AddrBytes[0] := hi(Word(Address));
        A.AddrBytes[1] := lo(Word(Address));
        A.AddrLen := 2;
      end;

  else
    //ไม่รู้จักชนิดนี้ ห้ามเดา เพราะการเดาแปลว่าส่งคำสั่งไปยังอุปกรณ์ที่ไม่ได้ตั้งใจ
    A.DevByte := 0;
    Result := False;
  end;
end;

function UsbAspI2C_WaitReadyAt(DevAddr, AddrType: byte; Address: longword;
  TimeoutMs: integer): boolean;
var
  A: TI2CAddr;
begin
  if not BuildI2CAddr(DevAddr, AddrType, Address, A) then Exit(False);
  Result := UsbAspI2C_WaitReady(A.DevByte, TimeoutMs);
end;

//คืนจำนวนไบต์ที่อ่านได้
function UsbAspI2C_Read(DevAddr, AddrType: byte; Address: longword; var buffer: array of byte; bufflen: integer): integer;
var
  A: TI2CAddr;
  wBuffer, rBuffer: array of byte;
  i, Chunk, Got, Total: integer;
  CurAddr: longword;
begin
  if (bufflen < 0) or (bufflen > Length(buffer)) then Exit(-1);
  if bufflen = 0 then Exit(0);
  if not I2CAddressRangeValid(AddrType, Address, bufflen) then Exit(-1);

  Total := 0;
  CurAddr := Address;
  while Total < bufflen do
  begin
    Chunk := I2CChunkToBankBoundary(AddrType, CurAddr, bufflen - Total);
    if Chunk <= 0 then Exit(-1);
    if not BuildI2CAddr(DevAddr, AddrType, CurAddr, A) then Exit(-1);

    SetLength(wBuffer, A.AddrLen);
    for i := 0 to A.AddrLen - 1 do
      wBuffer[i] := A.AddrBytes[i];
    SetLength(rBuffer, Chunk);

    Got := AsProgrammer.Programmer.I2CReadWrite(A.DevByte, A.AddrLen, wBuffer,
                                               Chunk, rBuffer);
    if Got <> A.AddrLen + Chunk then Exit(-1);

    Move(rBuffer[0], buffer[Total], Chunk);
    Inc(Total, Chunk);
    Inc(CurAddr, longword(Chunk));
  end;

  Result := Total;
end;

//คืนจำนวนไบต์ที่เขียนได้
function UsbAspI2C_Write(DevAddr, AddrType: byte; Address: longword; buffer: array of byte; bufflen: integer): integer;
var
  A: TI2CAddr;
  wBuffer: array of byte;
  dummy: byte;
  i, Chunk, Sent, Total: integer;
  CurAddr: longword;
begin
  //แลตช์โหมดอ่านอย่างเดียวต้องปิดที่ตัวคำสั่งแบบเดียวกับ spi25 ไม่ใช่แค่ปุ่ม
  //คืน -1 เหมือนส่งไม่สำเร็จ ผู้เรียกทุกคนตรวจค่านี้อยู่แล้ว
  if SafeModeBlocks(gaWrite) then Exit(-1);
  if (bufflen < 0) or (bufflen > Length(buffer)) then Exit(-1);
  if bufflen = 0 then Exit(0);
  if not I2CAddressRangeValid(AddrType, Address, bufflen) then Exit(-1);

  Total := 0;
  CurAddr := Address;
  while Total < bufflen do
  begin
    Chunk := I2CChunkToBankBoundary(AddrType, CurAddr, bufflen - Total);
    if Chunk <= 0 then Exit(-1);
    if not BuildI2CAddr(DevAddr, AddrType, CurAddr, A) then Exit(-1);

    SetLength(wBuffer, A.AddrLen + Chunk);
    for i := 0 to A.AddrLen - 1 do
      wBuffer[i] := A.AddrBytes[i];
    Move(buffer[Total], wBuffer[A.AddrLen], Chunk);

    Sent := AsProgrammer.Programmer.I2CReadWrite(A.DevByte, A.AddrLen + Chunk,
                                                wBuffer, 0, dummy);
    if Sent <> A.AddrLen + Chunk then Exit(-1);

    //ต้อง poll control byte ของ bank ที่เพิ่งเขียน และ timeout ต้องเป็นผลล้มเหลว
    if not UsbAspI2C_WaitReady(A.DevByte, I2C_WRITE_CYCLE_MS) then Exit(-1);

    Inc(Total, Chunk);
    Inc(CurAddr, longword(Chunk));
  end;

  Result := Total;
end;

end.
