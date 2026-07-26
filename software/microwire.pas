unit microwire;

{$mode objfpc}

interface

uses
  Classes, SysUtils, utilfunc;

  function UsbAspMW_Busy(): boolean;
  function UsbAspMW_Read(AddrBitLen: byte; Addr: word; var buffer: array of byte; bufflen: integer): integer;
  function UsbAspMW_Write(AddrBitLen: byte; Addr: word; buffer: array of byte; bufflen: integer): integer;
  function UsbAspMW_ChipErase(AddrBitLen: byte): integer;
  function UsbAspMW_Ewen(AddrBitLen: byte): integer;

implementation

uses basehw;

function UsbAspMW_Busy(): boolean;
begin
  result := AsProgrammer.Programmer.MWIsBusy;
end;

//คืนจำนวนไบต์ที่อ่านได้
function UsbAspMW_Read(AddrBitLen: byte; Addr: word; var buffer: array of byte; bufflen: integer): integer;
var
  op: cardinal;
  writebuff: array[0..3] of byte;
begin

  if AddrBitLen > 29 then exit(0);

  //ประกอบแพ็กเก็ต
  op := 1; //Start bit
  op := (op shl 2) or 2; //opcode
  op := (op shl AddrBitLen) or Addr; //แอดเดรส
  op := op shl (32-AddrBitLen-3);

  //AddrBitLen+3; //จะส่งกี่บิต
  writebuff[0] := hi(hi(op));
  writebuff[1] := lo(hi(op));
  writebuff[2] := hi(lo(op));
  writebuff[3] := lo(lo(op));

  AsProgrammer.Programmer.MWWrite(0, AddrBitLen+3, writebuff);
  result := AsProgrammer.Programmer.MWRead(1, bufflen, buffer);
end;

//คืนจำนวนไบต์ที่เขียนได้
function UsbAspMW_Write(AddrBitLen: byte; Addr: word; buffer: array of byte; bufflen: integer): integer;
var
  op: cardinal;
  writebuff: array[0..3] of byte;
begin

  if AddrBitLen > 29 then exit(0);

  //ประกอบแพ็กเก็ต
  op := 1; //Start bit
  op := (op shl 2) or 1; //opcode
  op := (op shl AddrBitLen) or Addr; //แอดเดรส
  op := op shl (32-AddrBitLen-3);

  writebuff[0] := hi(hi(op));
  writebuff[1] := lo(hi(op));
  writebuff[2] := hi(lo(op));
  writebuff[3] := lo(lo(op));

  AsProgrammer.Programmer.MWWrite(0, AddrBitLen+3, writebuff);

  result := ByteNum(AsProgrammer.Programmer.MWWrite(1, bufflen*8, buffer));
end;

function UsbAspMW_ChipErase(AddrBitLen: byte): integer;
var
  op: cardinal;
  writebuff: array[0..3] of byte;
begin
  op := 1; //Start bit
  op := (op shl 4) or 2; //opcode 0010
  op := op shl (AddrBitLen-2);
  op := op shl (32-AddrBitLen-3);

  writebuff[0] := hi(hi(op));
  writebuff[1] := lo(hi(op));
  writebuff[2] := hi(lo(op));
  writebuff[3] := lo(lo(op));

  result := AsProgrammer.Programmer.MWWrite(1, AddrBitLen+3, writebuff);
end;

function UsbAspMW_Ewen(AddrBitLen: byte): integer;
var
  op: cardinal;
  writebuff: array[0..3] of byte;
begin
  op := 1; //Start bit
  op := (op shl 4) or 3; //opcode 0011
  op := op shl (AddrBitLen-2);
  op := op shl (32-AddrBitLen-3);

  writebuff[0] := hi(hi(op));
  writebuff[1] := lo(hi(op));
  writebuff[2] := hi(lo(op));
  writebuff[3] := lo(lo(op));

  result := AsProgrammer.Programmer.MWWrite(1, AddrBitLen+3, writebuff);
end;

end.

