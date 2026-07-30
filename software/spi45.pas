unit spi45;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, utilfunc, spi25, BaseHW;

function UsbAsp45_Busy(): boolean;

function UsbAsp45_isPagePowerOfTwo(): boolean;

function UsbAsp45_Write(PageAddr: word; buffer: array of byte; bufflen: integer): integer;
function UsbAsp45_Read(PageAddr: word; var buffer: array of byte; bufflen: integer): integer;

//รุ่น Ex แยก geometry ออกจากจำนวนไบต์ โดย ReadEx อ่านบางส่วนของ page ได้
//ส่วน WriteEx ต้องรับทั้ง page เพราะ opcode 82h erase/program ทั้ง page
function UsbAsp45_WriteEx(PageAddr: cardinal; PageSize, ByteOffset: word;
  buffer: array of byte; bufflen: integer): integer;
function UsbAsp45_ReadEx(PageAddr: cardinal; PageSize, ByteOffset: word;
  var buffer: array of byte; bufflen: integer): integer;

function AT45PageSizeValid(PageSize: word): boolean;
function AT45BuildAddress(PageAddr: cardinal; PageSize, ByteOffset: word;
  out AddrBytes: array of byte): boolean;

type
  //geometry ของตระกูล AT45 ถอดจากบิต density (5:2) ของ status register
  TAT45Geometry = record
    DensityCode: byte;   //บิต 5:2 ของ D7h
    Family: string[12];  //'AT45DB161' ฯลฯ
    Pages: cardinal;
    StdPageSize: word;   //เพจ DataFlash มาตรฐาน (264/528/1056)
    BinPageSize: word;   //เพจโหมด power-of-2 (256/512/1024)
  end;

function AT45GeometryFromStatus(sreg: byte; out Geo: TAT45Geometry): boolean;

//อ่าน status แล้วสรุปว่าชิปตัวจริงใช้เพจขนาดเท่าไรอยู่ตอนนี้
//คืน False = คุยกับชิปไม่ได้ (ErrMsg บอกเหตุ)
//คืน True, Known=False = ชิปตอบแต่รหัสความจุไม่อยู่ในตาราง ตรวจต่อไม่ได้
//คืน True, Known=True = PageSize/TotalBytes คือของจริงจากชิป
function UsbAsp45_DetectGeometry(out Geo: TAT45Geometry; out PowerOf2: boolean;
  out PageSize: word; out TotalBytes: cardinal;
  out Known: boolean; out ErrMsg: string): boolean;

//
function UsbAsp45_ChipErase(): integer;

//Disable Sector protect
function UsbAsp45_DisableSP(): integer;
//
function UsbAsp45_ReadSR(var sreg: byte): integer;
//read sector lockdown
function UsbAsp45_ReadSectorLockdown(var buffOut: array of byte): integer;

function UsbAsp45_WaitReady(TimeoutMs: cardinal; out LastStatus: byte): boolean;


implementation

function SPI45CommandRead(const Command: array of byte; CommandLen: integer;
  var Data: array of byte; DataLen: integer): integer;
var
  Sent, Got: integer;
begin
  if (CommandLen < 1) or (CommandLen > Length(Command)) or
     (DataLen < 0) or (DataLen > Length(Data)) then Exit(-1);
  if DataLen = 0 then Exit(0);

  FillByte(Data[0], DataLen, $FF);

  if AsProgrammer.Current_HW = CHW_BUZZPIRAT then
    Got := AsProgrammer.Programmer.SPIWriteRead(1, CommandLen, Command,
                                                DataLen, Data)
  else
  begin
    Sent := SPIWrite(0, CommandLen, Command);
    if Sent <> CommandLen then Exit(-1);
    Got := SPIRead(1, DataLen, Data);
  end;

  if Got <> DataLen then Exit(-1);
  Result := Got;
end;

function AT45PageSizeValid(PageSize: word): boolean;
begin
  //binary page และ legacy DataFlash page ที่พบในตระกูล 1Mbit..128Mbit
  case PageSize of
    128, 132, 256, 264, 512, 528, 1024, 1056: Result := True;
  else
    Result := False;
  end;
end;

function AT45BuildAddress(PageAddr: cardinal; PageSize, ByteOffset: word;
  out AddrBytes: array of byte): boolean;
var
  OffsetBits: integer;
  Linear: QWord;
begin
  Result := False;
  if Length(AddrBytes) < 3 then Exit;
  if not AT45PageSizeValid(PageSize) then Exit;
  if ByteOffset >= PageSize then Exit;

  //DataFlash จอง ceil(log2(page size)) บิตล่างไว้เป็น byte offset
  OffsetBits := BitNum(PageSize);
  Linear := (QWord(PageAddr) shl OffsetBits) or QWord(ByteOffset);
  if Linear > $FFFFFF then Exit;

  AddrBytes[0] := byte(Linear shr 16);
  AddrBytes[1] := byte(Linear shr 8);
  AddrBytes[2] := byte(Linear);
  Result := True;
end;

function AT45GeometryFromStatus(sreg: byte; out Geo: TAT45Geometry): boolean;
begin
  Geo.DensityCode := (sreg shr 2) and $0F;
  Geo.Family := '';
  Geo.Pages := 0;
  Geo.StdPageSize := 0;
  Geo.BinPageSize := 0;
  Result := True;
  case Geo.DensityCode of
    %0011: begin Geo.Family := 'AT45DB011'; Geo.Pages := 512;  Geo.StdPageSize := 264;  Geo.BinPageSize := 256;  end;
    %0101: begin Geo.Family := 'AT45DB021'; Geo.Pages := 1024; Geo.StdPageSize := 264;  Geo.BinPageSize := 256;  end;
    %0111: begin Geo.Family := 'AT45DB041'; Geo.Pages := 2048; Geo.StdPageSize := 264;  Geo.BinPageSize := 256;  end;
    %1001: begin Geo.Family := 'AT45DB081'; Geo.Pages := 4096; Geo.StdPageSize := 264;  Geo.BinPageSize := 256;  end;
    %1011: begin Geo.Family := 'AT45DB161'; Geo.Pages := 4096; Geo.StdPageSize := 528;  Geo.BinPageSize := 512;  end;
    %1101: begin Geo.Family := 'AT45DB321'; Geo.Pages := 8192; Geo.StdPageSize := 528;  Geo.BinPageSize := 512;  end;
    %1111: begin Geo.Family := 'AT45DB642'; Geo.Pages := 8192; Geo.StdPageSize := 1056; Geo.BinPageSize := 1024; end;
  else
    Result := False;
  end;
end;

function UsbAsp45_DetectGeometry(out Geo: TAT45Geometry; out PowerOf2: boolean;
  out PageSize: word; out TotalBytes: cardinal;
  out Known: boolean; out ErrMsg: string): boolean;
var
  sreg: byte;
begin
  Result := False;
  PowerOf2 := False;
  PageSize := 0;
  TotalBytes := 0;
  Known := False;
  ErrMsg := '';
  Geo.DensityCode := 0;
  Geo.Family := '';
  Geo.Pages := 0;
  Geo.StdPageSize := 0;
  Geo.BinPageSize := 0;

  if UsbAsp45_ReadSR(sreg) <> 1 then
  begin
    ErrMsg := 'the DataFlash status register could not be read';
    Exit;
  end;
  //FF ล้วนคือบัสที่ไม่มีใครขับ: ต้องเกิด RDY+COMP+density 1111+PROTECT+
  //binary page พร้อมกันหมดถึงจะเป็นชิปจริง ซึ่งเทียบกับคลิปหลุดแล้ว
  //โอกาสน้อยกว่ามาก จึงตัดเป็นบัสเงียบ
  if sreg = $FF then
  begin
    ErrMsg := 'the DataFlash status bus reads FF; no chip is answering';
    Exit;
  end;

  Result := True;
  PowerOf2 := (sreg and 1) <> 0;
  if not AT45GeometryFromStatus(sreg, Geo) then Exit;

  Known := True;
  if PowerOf2 then PageSize := Geo.BinPageSize else PageSize := Geo.StdPageSize;
  TotalBytes := Geo.Pages * cardinal(PageSize);
end;

//รอจนกว่าชิปจะพร้อม
function UsbAsp45_Busy(): boolean;
var
  sreg: byte;
begin
  //อ่านสถานะไม่สำเร็จต้อง fail closed ไม่ใช่ตีความ opcode D7h ที่ค้างอยู่
  //เป็น ready เพราะบิต 7 ของ D7h ติดอยู่
  if UsbAsp45_ReadSR(sreg) <> 1 then Exit(True);
  //FF ล้วนคือบัสที่ไม่มีใครขับ ไม่ใช่ชิปที่พร้อม: ชิปจริงจะอ่านได้ FF ต้องเป็น
  //AT45DB642 (density 1111) ที่ RDY+COMP+PROTECT+binary page พร้อมกันหมด
  //ซึ่งเทียบกับคลิปหลุดแล้วโอกาสน้อยกว่ามาก ถ้าปล่อยผ่าน คลิปที่หลุดกลางงาน
  //เขียนจะ "พร้อม" ทันทีทุกหน้า แล้วงานจบแบบสำเร็จทั้งที่ชิปไม่ได้รับอะไรเลย
  if sreg = $FF then Exit(True);
  Result := not IsBitSet(Sreg, 7);
end;

function UsbAsp45_isPagePowerOfTwo(): boolean;
var
  sreg: byte;
begin
  if UsbAsp45_ReadSR(sreg) <> 1 then Exit(False);
  if (sreg and 1) = 1 then Result := True else Result := false;
end;

function UsbAsp45_ChipErase(): integer;
var
  buff: array[0..3] of byte;
begin
  buff[0]:= $C7;
  buff[1]:= $94;
  buff[2]:= $80;
  buff[3]:= $9A;
  result := SPIWrite(1, 4, buff);
  if Result <> 4 then Result := -1;
end;

function UsbAsp45_DisableSP(): integer;
var
  buff: array[0..3] of byte;
begin
  Buff[0] := $3D;
  Buff[1] := $2A;
  Buff[2] := $7F;
  Buff[3] := $9A;
  result := SPIWrite(1, 4, buff);
  if Result <> 4 then Result := -1;
end;

function UsbAsp45_ReadSectorLockdown(var buffOut: array of byte): integer;
var
  buff: array[0..3] of byte;
begin
  if Length(buffOut) < 32 then Exit(-1);
  Buff[0] := $35;
  Buff[1] := $00;
  Buff[2] := $00;
  Buff[3] := $00;
  Result := SPI45CommandRead(buff, 4, buffOut, 32);
end;

function UsbAsp45_ReadSR(var sreg: byte): integer;
var
  command: array[0..0] of byte;
  reply: array[0..0] of byte;
begin
  command[0] := $D7; //57H Legacy
  Result := SPI45CommandRead(command, 1, reply, 1);
  if Result <> 1 then
  begin
    sreg := $FF;
    Exit(-1);
  end;
  sreg := reply[0];
end;

//คืนจำนวนไบต์ที่เขียนได้
function UsbAsp45_Write(PageAddr: word; buffer: array of byte; bufflen: integer): integer;
begin
  if (bufflen < 0) or (bufflen > High(word)) then Exit(-1);
  Result := UsbAsp45_WriteEx(PageAddr, word(bufflen), 0, buffer, bufflen);
end;

function UsbAsp45_WriteEx(PageAddr: cardinal; PageSize, ByteOffset: word;
  buffer: array of byte; bufflen: integer): integer;
var
  buff: array[0..3] of byte;
  addr: array[0..2] of byte;
  Sent: integer;
begin
  if (bufflen < 0) or (bufflen > Length(buffer)) then Exit(-1);
  //82h (Main Memory Page Program Through Buffer 1) may erase/program bytes
  //outside a short payload. Refuse partial updates rather than destroy data.
  if (ByteOffset <> 0) or (bufflen <> PageSize) then Exit(-1);
  if not AT45BuildAddress(PageAddr, PageSize, ByteOffset, addr) then Exit(-1);

  buff[0] := $82;
  buff[1] := addr[0];
  buff[2] := addr[1];
  buff[3] := addr[2];

  Sent := SPIWrite(0, 4, buff);
  if Sent <> 4 then Exit(-1);
  Sent := SPIWrite(1, bufflen, buffer);
  if Sent <> bufflen then Exit(-1);
  Result := Sent;
end;

function UsbAsp45_Read(PageAddr: word; var buffer: array of byte; bufflen: integer): integer;
begin
  if (bufflen < 0) or (bufflen > High(word)) then Exit(-1);
  Result := UsbAsp45_ReadEx(PageAddr, word(bufflen), 0, buffer, bufflen);
end;

function UsbAsp45_ReadEx(PageAddr: cardinal; PageSize, ByteOffset: word;
  var buffer: array of byte; bufflen: integer): integer;
var
  command: array[0..7] of byte;
  addr: array[0..2] of byte;
begin
  if (bufflen < 0) or (bufflen > Length(buffer)) then Exit(-1);
  if bufflen = 0 then Exit(0);
  if (QWord(ByteOffset) + QWord(bufflen)) > QWord(PageSize) then Exit(-1);
  if not AT45BuildAddress(PageAddr, PageSize, ByteOffset, addr) then Exit(-1);

  command[0] := $E8;
  command[1] := addr[0];
  command[2] := addr[1];
  command[3] := addr[2];
  command[4] := 0;
  command[5] := 0;
  command[6] := 0;
  command[7] := 0;

  Result := SPI45CommandRead(command, Length(command), buffer, bufflen);
end;

function UsbAsp45_WaitReady(TimeoutMs: cardinal; out LastStatus: byte): boolean;
var
  Deadline: QWord;
begin
  Result := False;
  LastStatus := $FF;
  Deadline := GetTickCount64 + QWord(TimeoutMs);

  repeat
    if UsbAsp45_ReadSR(LastStatus) <> 1 then Exit(False);
    //FF ล้วนคือบัสตาย ไม่ใช่ ready แม้บิต 7 จะติด: ชิปจริงต้องเป็น AT45DB642
    //ที่ทุกบิตติดพร้อมกัน ซึ่งโอกาสน้อยกว่าคลิปหลุดมาก
    //spi95 ก็ตัดจบทันทีแบบเดียวกัน คืน False พร้อม LastStatus = FF
    //ให้ผู้เรียกรายงานว่าบัสเงียบ แทนที่จะรอครบ timeout หรือแกล้งสำเร็จ
    if LastStatus = $FF then Exit(False);
    if IsBitSet(LastStatus, 7) then Exit(True);
    if GetTickCount64 >= Deadline then Exit(False);
    Sleep(1);
  until False;
end;

end.

