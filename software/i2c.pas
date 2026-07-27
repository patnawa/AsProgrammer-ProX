unit i2c;

{$mode objfpc}

interface

uses
  Classes, SysUtils, DateUtils, utilfunc;

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
  Result := not AsProgrammer.Programmer.I2CWriteByte(Address);
  AsProgrammer.Programmer.I2CStop;
end;

function UsbAspI2C_WaitReady(DevByte: byte; TimeoutMs: integer): boolean;
var
  Started: TDateTime;
begin
  Started := Now;

  repeat
    if not UsbAspI2C_BUSY(DevByte) then Exit(True);
  until MilliSecondsBetween(Now, Started) > TimeoutMs;

  //ถามครั้งสุดท้ายหลังหมดเวลา เผื่อชิปเพิ่งพร้อมพอดี
  Result := not UsbAspI2C_BUSY(DevByte);
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
  A.DevByte := DevAddr;
  A.AddrBytes[0] := 0;
  A.AddrBytes[1] := 0;
  A.AddrLen := 0;
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

//คืนจำนวนไบต์ที่อ่านได้
function UsbAspI2C_Read(DevAddr, AddrType: byte; Address: longword; var buffer: array of byte; bufflen: integer): integer;
var
  A: TI2CAddr;
  wBuffer: array of byte;
  i: integer;
begin
  if not BuildI2CAddr(DevAddr, AddrType, Address, A) then Exit(-1);

  SetLength(wBuffer, A.AddrLen);
  for i := 0 to A.AddrLen - 1 do
    wBuffer[i] := A.AddrBytes[i];

  Result := AsProgrammer.Programmer.I2CReadWrite(A.DevByte, A.AddrLen, wBuffer,
                                                bufflen, buffer) - A.AddrLen;
end;

//คืนจำนวนไบต์ที่เขียนได้
function UsbAspI2C_Write(DevAddr, AddrType: byte; Address: longword; buffer: array of byte; bufflen: integer): integer;
var
  A: TI2CAddr;
  wBuffer: array of byte;
  dummy: byte;
  i: integer;
begin
  if not BuildI2CAddr(DevAddr, AddrType, Address, A) then Exit(-1);

  SetLength(wBuffer, A.AddrLen + bufflen);
  for i := 0 to A.AddrLen - 1 do
    wBuffer[i] := A.AddrBytes[i];
  if bufflen > 0 then
    move(buffer, wBuffer[A.AddrLen], bufflen);

  Result := AsProgrammer.Programmer.I2CReadWrite(A.DevByte, A.AddrLen + bufflen,
                                                wBuffer, 0, dummy) - A.AddrLen;

  //ชิปกำลังเขียนลงเซลล์อยู่ ถามจนกว่าจะตอบรับ แทนที่จะหน่วงเวลาเดา ๆ
  //ถ้าไม่รอแล้วยิงเพจถัดไปทันที ชิปจะไม่ตอบรับ แล้วข้อมูลเพจนั้นหายเงียบ ๆ
  if Result > 0 then
    UsbAspI2C_WaitReady(A.DevByte, I2C_WRITE_CYCLE_MS);
end;

end.
