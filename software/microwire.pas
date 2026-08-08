unit microwire;

{$mode objfpc}

interface

uses
  Classes, SysUtils, utilfunc, safemode;

const
  MW_MIN_ADDR_BITS = 2;
  MW_MAX_ADDR_BITS = 16;

  function UsbAspMW_Busy(): boolean;
  function UsbAspMW_Read(AddrBitLen: byte; Addr: word; var buffer: array of byte; bufflen: integer): integer;
  function UsbAspMW_Write(AddrBitLen: byte; Addr: word; buffer: array of byte; bufflen: integer): integer;
  function UsbAspMW_ChipErase(AddrBitLen: byte): integer;
  function UsbAspMW_Ewen(AddrBitLen: byte): integer;
  function UsbAspMW_Ewds(AddrBitLen: byte): integer;

  function MWAddressValid(AddrBitLen: byte; Addr: cardinal): boolean;
  function UsbAspMW_WaitReady(TimeoutMs: cardinal): boolean;

implementation

uses basehw;

function UsbAspMW_Busy(): boolean;
begin
  result := AsProgrammer.Programmer.MWIsBusy;
end;

function MWAddressValid(AddrBitLen: byte; Addr: cardinal): boolean;
var
  Limit: cardinal;
begin
  Result := False;
  if (AddrBitLen < MW_MIN_ADDR_BITS) or
     (AddrBitLen > MW_MAX_ADDR_BITS) then Exit;

  Limit := cardinal(1) shl AddrBitLen;
  Result := Addr < Limit;
end;

function BuildMWCommand(Opcode, AddrBitLen: byte; Addr: word;
  out WriteBuff: array of byte): boolean;
var
  Op: cardinal;
begin
  Result := False;
  if Length(WriteBuff) < 4 then Exit;
  if not MWAddressValid(AddrBitLen, Addr) then Exit;

  Op := 1;                         //start bit
  Op := (Op shl 2) or (Opcode and 3);
  Op := (Op shl AddrBitLen) or cardinal(Addr);
  Op := Op shl (32 - AddrBitLen - 3);

  WriteBuff[0] := byte(Op shr 24);
  WriteBuff[1] := byte(Op shr 16);
  WriteBuff[2] := byte(Op shr 8);
  WriteBuff[3] := byte(Op);
  Result := True;
end;

function BuildMWControl(SubOpcode, AddrBitLen: byte;
  out WriteBuff: array of byte): boolean;
var
  Op: cardinal;
begin
  Result := False;
  if Length(WriteBuff) < 4 then Exit;
  if (AddrBitLen < MW_MIN_ADDR_BITS) or
     (AddrBitLen > MW_MAX_ADDR_BITS) then Exit;

  //start + opcode 00 + subopcode 2 บิต + don't-care ให้ยาวเท่าคำสั่งปกติ
  Op := 1;
  Op := (Op shl 4) or (SubOpcode and 3);
  Op := Op shl (AddrBitLen - 2);
  Op := Op shl (32 - AddrBitLen - 3);

  WriteBuff[0] := byte(Op shr 24);
  WriteBuff[1] := byte(Op shr 16);
  WriteBuff[2] := byte(Op shr 8);
  WriteBuff[3] := byte(Op);
  Result := True;
end;

//คืนจำนวนไบต์ที่อ่านได้
function UsbAspMW_Read(AddrBitLen: byte; Addr: word; var buffer: array of byte; bufflen: integer): integer;
var
  writebuff: array[0..3] of byte;
  Sent, Got: integer;
begin
  if (bufflen < 0) or (bufflen > Length(buffer)) then Exit(-1);
  if bufflen = 0 then Exit(0);
  if not BuildMWCommand(2, AddrBitLen, Addr, writebuff) then Exit(-1);

  Sent := AsProgrammer.Programmer.MWWrite(0, AddrBitLen + 3, writebuff);
  if Sent <> AddrBitLen + 3 then Exit(-1);

  Got := AsProgrammer.Programmer.MWRead(1, bufflen, buffer);
  if Got <> bufflen then Exit(-1);
  Result := Got;
end;

//คืนจำนวนไบต์ที่เขียนได้
function UsbAspMW_Write(AddrBitLen: byte; Addr: word; buffer: array of byte; bufflen: integer): integer;
var
  writebuff: array[0..3] of byte;
  Sent, DataBits: integer;
begin
  //แลตช์โหมดอ่านอย่างเดียวต้องปิดที่ตัวคำสั่งแบบเดียวกับ spi25 ไม่ใช่แค่ปุ่ม
  //คืน -1 เหมือนส่งไม่สำเร็จ ผู้เรียกทุกคนตรวจค่านี้อยู่แล้ว
  if SafeModeBlocks(gaWrite) then Exit(-1);
  if (bufflen < 0) or (bufflen > Length(buffer)) then Exit(-1);
  if bufflen = 0 then Exit(0);
  //BitsWrite ของชั้นฮาร์ดแวร์เป็น byte ห้ามปล่อยให้คูณแล้ววนกลับ
  if bufflen > 31 then Exit(-1);
  if not BuildMWCommand(1, AddrBitLen, Addr, writebuff) then Exit(-1);

  Sent := AsProgrammer.Programmer.MWWrite(0, AddrBitLen + 3, writebuff);
  if Sent <> AddrBitLen + 3 then Exit(-1);

  DataBits := bufflen * 8;
  Sent := AsProgrammer.Programmer.MWWrite(1, DataBits, buffer);
  if Sent <> DataBits then Exit(-1);
  Result := bufflen;
end;

function UsbAspMW_ChipErase(AddrBitLen: byte): integer;
var
  writebuff: array[0..3] of byte;
begin
  if SafeModeBlocks(gaErase) then Exit(-1);
  if not BuildMWControl(2, AddrBitLen, writebuff) then Exit(-1); //ERAL
  Result := AsProgrammer.Programmer.MWWrite(1, AddrBitLen + 3, writebuff);
  if Result <> AddrBitLen + 3 then Result := -1;
end;

function UsbAspMW_Ewen(AddrBitLen: byte): integer;
var
  writebuff: array[0..3] of byte;
begin
  //EWEN คือประตูของทุกการเขียน/ลบ ปิดที่นี่ด้วยเพื่อกันสคริปต์เรียกตรง
  if SafeModeBlocks(gaUnlock) then Exit(-1);
  if not BuildMWControl(3, AddrBitLen, writebuff) then Exit(-1); //EWEN
  Result := AsProgrammer.Programmer.MWWrite(1, AddrBitLen + 3, writebuff);
  if Result <> AddrBitLen + 3 then Result := -1;
end;

function UsbAspMW_Ewds(AddrBitLen: byte): integer;
var
  writebuff: array[0..3] of byte;
begin
  if not BuildMWControl(0, AddrBitLen, writebuff) then Exit(-1); //EWDS
  Result := AsProgrammer.Programmer.MWWrite(1, AddrBitLen + 3, writebuff);
  if Result <> AddrBitLen + 3 then Result := -1;
end;

function UsbAspMW_WaitReady(TimeoutMs: cardinal): boolean;
var
  Deadline: QWord;
begin
  Deadline := GetTickCount64 + QWord(TimeoutMs);
  repeat
    if not UsbAspMW_Busy then Exit(True);
    if GetTickCount64 >= Deadline then Exit(False);
    Sleep(1);
  until False;
end;

end.

