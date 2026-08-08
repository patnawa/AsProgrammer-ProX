unit spimulti;

{$mode objfpc}

interface

uses
  Classes, Forms, SysUtils, safemode;


function UsbAspMulti_EnableEDI(): integer;
function UsbAspMulti_WriteReg(RegAddr: Word; RegData: byte): integer;
function UsbAspMulti_ReadReg(RegAddr: Word; var RegData: byte): integer;

function UsbAspMulti_Read(Addr: longword; var Data: byte): integer;

function UsbAspMulti_ErasePage(Addr: longword): integer;
function UsbAspMulti_WritePage(Addr: longword; var Data: array of byte): integer;

function UsbAspMulti_Busy(): boolean;

implementation

uses Main, basehw, opthread;

const
  //EDI ตอบ $50 ภายในไม่กี่มิลลิวินาทีเมื่อชิปอยู่จริง ห้านาทีคือสายหลุดแน่นอน
  //เดิมลูปนี้ไม่มีเพดาน ทำให้ deadline 30 วินาทีต่อเพจของ WriteFlashKB
  //ไม่มีวันได้ทำงาน เพราะแขวนอยู่ในนี้ก่อนถึงมือมัน
  MULTI_READY_TIMEOUT_MS = 5000;

//คำสั่งแรกหลังรีเซ็ต ต้องใช้ความถี่ไม่เกิน 8MHz

//เปิดสิทธิ์เขียนรีจิสเตอร์ EFCMD ที่ 0xFEAC
function UsbAspMulti_EnableEDI(): integer;
var
  Buff: array[0..4] of byte;
begin
  Buff[0] := $40;
  Buff[1] := 0;
  Buff[2] := $FE;
  Buff[3] := $AD;

  Buff[4] := $08;

  result := AsProgrammer.Programmer.SPIWrite(1, 5, Buff);
end;

function UsbAspMulti_WriteReg(RegAddr: Word; RegData: byte): integer;
var
  Buff: array[0..4] of byte;
begin
  Buff[0] := $40;
  Buff[1] := 0;

  Buff[2] := hi(RegAddr);
  Buff[3] := lo(RegAddr);

  Buff[4] := RegData;

  result := AsProgrammer.Programmer.SPIWrite(1, 5, Buff);
end;


function UsbAspMulti_ReadReg(RegAddr: Word; var RegData: byte): integer;
var
  Buff: array[0..4] of byte;
  ReadyStat: byte;
  Started: QWord;
begin
  Result := -1;
  //FPC ทำตัวแปร local ที่มีค่าเริ่มต้นให้เป็น static ค่าจะค้างข้ามการเรียก
  ReadyStat := 0;

  Buff[0] := $30;
  Buff[1] := 0;

  Buff[2] := hi(RegAddr);
  Buff[3] := lo(RegAddr);

  if AsProgrammer.Programmer.SPIWrite(0, 4, Buff) <> 4 then Exit;

  //รอสถานะพร้อม มีเพดานเวลา: ชิปหาย/คลิปหลุดต้องจบด้วย -1 ไม่ใช่ค้างตลอดกาล
  Started := GetTickCount64;
  repeat
    OpProcessMessages; //ปั๊มคิวเฉพาะบน thread หลัก
    if UserCancel then Exit;
    if GetTickCount64 - Started >= MULTI_READY_TIMEOUT_MS then Exit;

    AsProgrammer.Programmer.SPIRead(0, 1, ReadyStat);
  until (ReadyStat = $50);

  result := AsProgrammer.Programmer.SPIRead(1, 1, regdata);
end;

function UsbAspMulti_Read(Addr: longword; var Data: byte): integer;
begin

   UsbAspMulti_WriteReg($FEAA, lo(hi(Addr)) );
   UsbAspMulti_WriteReg($FEA9, hi(lo(Addr)) );
   UsbAspMulti_WriteReg($FEA8, lo(lo(Addr)) );

   UsbAspMulti_WriteReg($FEAC, $03);

   Result := UsbAspMulti_ReadReg($FEAB, Data);

end;

//เพจละ 128 ไบต์
function UsbAspMulti_WritePage(Addr: longword; var Data: array of byte): integer;
var
  i: integer;
begin
   //แลตช์โหมดอ่านอย่างเดียว ปิดที่ตัวคำสั่งแบบเดียวกับ spi25
   if SafeModeBlocks(gaWrite) then Exit(-1);
   if Length(Data) < 128 then Exit(-1);

   UsbAspMulti_WriteReg($FEAA, lo(hi(Addr)) );
   UsbAspMulti_WriteReg($FEA9, hi(lo(Addr)) );
   //UsbAspMulti_WriteReg($FEA8, lo(lo(page)) );

   UsbAspMulti_WriteReg($FEAC, $80); //ล้างบัฟเฟอร์

   for i:=0 to 127 do
   begin
     UsbAspMulti_WriteReg($FEA8, lo(lo(Addr)) + i );
     UsbAspMulti_WriteReg($FEAB, Data[i]);
     UsbAspMulti_WriteReg($FEAC, $02); //แลตช์เพจ
   end;

   result := UsbAspMulti_WriteReg($FEAC, $70); //สั่งเขียนเพจ
end;

function UsbAspMulti_ErasePage(Addr: longword): integer;
begin
   if SafeModeBlocks(gaErase) then Exit(-1);

   UsbAspMulti_WriteReg($FEAA, lo(hi(Addr)) );
   UsbAspMulti_WriteReg($FEA9, hi(lo(Addr)) );
   UsbAspMulti_WriteReg($FEA8, lo(lo(Addr)) );

   result := UsbAspMulti_WriteReg($FEAC, $20);
end;

function UsbAspMulti_Busy(): boolean;
var
  sreg: byte;
begin
  sreg := $FF;
  UsbAspMulti_ReadReg($FEAD, sreg);
  if (sreg and 2) = 0 then Result := False else Result := True;
end;

end.

