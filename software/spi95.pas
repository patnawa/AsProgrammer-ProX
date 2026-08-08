unit spi95;

{$mode objfpc}

interface

uses
  Classes, SysUtils, spi25, BaseHW, safemode;

const
  SPI95_MAX_3BYTE_SIZE = 16777216;

function UsbAsp95_Read(ChipSize: integer; Addr: longword; var buffer: array of byte; bufflen: integer): integer;
function UsbAsp95_Write(ChipSize: integer; Addr: longword; buffer: array of byte; bufflen: integer): integer;
function UsbAsp95_Wren(): integer;
function UsbAsp95_Wrdi(): integer;
function UsbAsp95_WriteSR(var sreg: byte): integer;
function UsbAsp95_ReadSR(var sreg: byte): integer;

//ตรวจว่าขนาดชิปแปลงเป็นรูปแบบแอดเดรสที่หน่วยนี้รองรับได้หรือไม่
//คืนความยาว command header: 2 = address byte เดียวหรือ A8-in-opcode,
//3 = address 2 ไบต์, 4 = address 3 ไบต์, 0 = รูปแบบไม่ชัดเจน/เกินขอบ
function SPI95CommandLength(ChipSize: integer): integer;
function SPI95AddressRangeValid(ChipSize: integer; Addr: longword;
  DataLen: integer): boolean;
function SPI95PageChunk(Addr: longword; Requested: integer;
  PageSize: word): integer;

//WREN ที่ยืนยัน WEL และตัวรอสถานะที่มี timeout แบบ monotonic
function UsbAsp95_WrenChecked(out WEL: boolean): boolean;
function UsbAsp95_WaitReady(TimeoutMs: cardinal; out LastStatus: byte): boolean;

implementation

function SPI95CommandLength(ChipSize: integer): integer;
begin
  if (ChipSize > 0) and (ChipSize <= 256) then
    Exit(2); //opcode + address 1 byte

  if ChipSize = 512 then
    Exit(2); //A8 อยู่ใน opcode 0Ah/0Bh

  //257..511 ไบต์ไม่สามารถอ้างครบด้วย address byte เดียว และไม่มีข้อมูลพอ
  //ให้เดาว่าใช้รูปแบบ A8-in-opcode แบบชิป 512 ไบต์
  if (ChipSize > 512) and (ChipSize <= 65536) then
    Exit(3); //opcode + address 2 ไบต์

  if (ChipSize > 65536) and (ChipSize <= SPI95_MAX_3BYTE_SIZE) then
    Exit(4); //opcode + address 3 ไบต์

  Result := 0;
end;

function SPI95AddressRangeValid(ChipSize: integer; Addr: longword;
  DataLen: integer): boolean;
var
  EndAddr: QWord;
begin
  Result := False;
  if (SPI95CommandLength(ChipSize) = 0) or (DataLen < 0) then Exit;

  EndAddr := QWord(Addr) + QWord(DataLen);
  Result := (Addr < longword(ChipSize)) and (EndAddr <= QWord(ChipSize));
end;

function SPI95PageChunk(Addr: longword; Requested: integer;
  PageSize: word): integer;
var
  Remain: longword;
begin
  Result := 0;
  if (Requested <= 0) or (PageSize = 0) then Exit;

  Remain := longword(PageSize) - (Addr mod longword(PageSize));
  if QWord(Requested) < QWord(Remain) then
    Result := Requested
  else
    Result := integer(Remain);
end;

function Build95Command(WriteCommand: boolean; ChipSize: integer;
  Addr: longword; out Buff: array of byte; out Len: byte): boolean;
begin
  Result := False;
  Len := SPI95CommandLength(ChipSize);
  if (Len = 0) or (Length(Buff) < Len) then Exit;

  if ChipSize <= 256 then
  begin
    if WriteCommand then Buff[0] := $02 else Buff[0] := $03;
    Buff[1] := byte(Addr);
  end
  else if ChipSize = 512 then
  begin
    if WriteCommand then
      if Addr < 256 then Buff[0] := $02 else Buff[0] := $0A
    else
      if Addr < 256 then Buff[0] := $03 else Buff[0] := $0B;
    Buff[1] := byte(Addr and $FF);
  end
  else if ChipSize <= 65536 then
  begin
    if WriteCommand then Buff[0] := $02 else Buff[0] := $03;
    Buff[1] := byte((Addr shr 8) and $FF);
    Buff[2] := byte(Addr and $FF);
  end
  else
  begin
    if WriteCommand then Buff[0] := $02 else Buff[0] := $03;
    Buff[1] := byte((Addr shr 16) and $FF);
    Buff[2] := byte((Addr shr 8) and $FF);
    Buff[3] := byte(Addr and $FF);
  end;

  Result := True;
end;

function UsbAsp95_Read(ChipSize: integer; Addr: longword; var buffer: array of byte; bufflen: integer): integer;
var
  len: byte;
  buff: array[0..3] of byte;
  Sent, Got: integer;
begin
  if (bufflen < 0) or (bufflen > Length(buffer)) then Exit(-1);
  if bufflen = 0 then Exit(0);
  if not SPI95AddressRangeValid(ChipSize, Addr, bufflen) then Exit(-1);
  if not Build95Command(False, ChipSize, Addr, buff, len) then Exit(-1);

  FillByte(buffer[0], bufflen, $FF);

  if AsProgrammer.Current_HW = CHW_BUZZPIRAT then
    Got := AsProgrammer.Programmer.SPIWriteRead(1, len, buff,
                                                bufflen, buffer)
  else
  begin
    Sent := SPIWrite(0, len, buff);
    if Sent <> len then Exit(-1);
    Got := SPIRead(1, bufflen, buffer);
  end;

  if Got <> bufflen then Exit(-1);
  Result := Got;
end;

function UsbAsp95_Write(ChipSize: integer; Addr: longword; buffer: array of byte; bufflen: integer): integer;
var
  len: byte;
  buff: array[0..3] of byte;
  Sent: integer;
begin
  //แลตช์โหมดอ่านอย่างเดียว ปิดที่ตัวคำสั่งแบบเดียวกับ spi25
  if SafeModeBlocks(gaWrite) then Exit(-1);
  if (bufflen < 0) or (bufflen > Length(buffer)) then Exit(-1);
  if bufflen = 0 then Exit(0);
  if not SPI95AddressRangeValid(ChipSize, Addr, bufflen) then Exit(-1);
  if not Build95Command(True, ChipSize, Addr, buff, len) then Exit(-1);

  Sent := SPIWrite(0, len, buff);
  if Sent <> len then Exit(-1);

  Sent := SPIWrite(1, bufflen, buffer);
  if Sent <> bufflen then Exit(-1);
  Result := Sent;
end;

function UsbAsp95_Wren(): integer;
var
  buff: byte;
begin
  buff:= $06;
  result := SPIWrite(1, 1, buff);
end;

function UsbAsp95_WrenChecked(out WEL: boolean): boolean;
var
  sreg: byte;
begin
  WEL := False;
  if UsbAsp95_Wren <> 1 then Exit(False);
  if UsbAsp95_ReadSR(sreg) <> 1 then Exit(False);
  if sreg = $FF then Exit(False);

  WEL := (sreg and $02) <> 0;
  Result := WEL;
end;

function UsbAsp95_WaitReady(TimeoutMs: cardinal; out LastStatus: byte): boolean;
var
  Deadline: QWord;
begin
  Result := False;
  LastStatus := $FF;
  Deadline := GetTickCount64 + QWord(TimeoutMs);

  repeat
    if UsbAsp95_ReadSR(LastStatus) <> 1 then Exit(False);
    if LastStatus = $FF then Exit(False);
    if (LastStatus and $01) = 0 then Exit(True);
    if GetTickCount64 >= Deadline then Exit(False);
    Sleep(1);
  until False;
end;

function UsbAsp95_Wrdi(): integer;
var
  buff: byte;
begin
  buff:= $04;
  result := SPIWrite(1, 1, buff);
end;

function UsbAsp95_WriteSR(var sreg: byte): integer;
var
  buff: array[0..1] of byte;
begin
  if SafeModeBlocks(gaWriteStatusRegister) then Exit(-1);
  Buff[0] := $01;
  Buff[1] := sreg;
  result := SPIWrite(1, 2, buff);
  if Result <> 2 then Result := -1;
end;

function UsbAsp95_ReadSR(var sreg: byte): integer;
var
  opcode, value: byte;
  Sent, Got: integer;
begin
  opcode := $05;
  value := $FF;

  if AsProgrammer.Current_HW = CHW_BUZZPIRAT then
    Got := AsProgrammer.Programmer.SPIWriteRead(1, 1, opcode, 1, value)
  else
  begin
    Sent := SPIWrite(0, 1, opcode);
    if Sent <> 1 then
    begin
      sreg := $FF;
      Exit(-1);
    end;
    Got := SPIRead(1, 1, value);
  end;

  if Got <> 1 then
  begin
    sreg := $FF;
    Exit(-1);
  end;

  sreg := value;
  Result := 1;
end;

end.

