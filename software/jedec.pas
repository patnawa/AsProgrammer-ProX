unit jedec;

//ตารางรหัสผู้ผลิตตามมาตรฐาน JEDEC JEP106
//ใช้บอกยี่ห้อของชิปได้แม้ชิปตัวนั้นจะไม่มีอยู่ใน chiplist.xml
//ไบต์แรกของคำสั่ง 9Fh คือรหัสผู้ผลิต ส่วน 7Fh คือไบต์ต่อขยายไปยังธนาคารถัดไป

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

//คืนชื่อผู้ผลิตจากรหัส ถ้าไม่รู้จักจะคืนสตริงว่าง
function JedecVendor(ID: byte): string;

//ตรวจว่ารหัสที่อ่านมาใช้งานไม่ได้ เช่น ไม่มีชิป สายหลุด หรือไม่มีไฟเลี้ยง
function IsDeadID(const B: array of byte): boolean;

implementation

type
  TVendorEntry = record
    ID: byte;
    Name: string;
  end;

const
  Vendors: array[0..25] of TVendorEntry = (
    (ID: $01; Name: 'Spansion / Cypress / Infineon'),
    (ID: $04; Name: 'Fujitsu'),
    (ID: $0B; Name: 'XTX Technology'),
    (ID: $0E; Name: 'Fremont Micro Devices'),
    (ID: $1C; Name: 'EON / ESMT'),
    (ID: $1F; Name: 'Atmel / Adesto / Microchip'),
    (ID: $20; Name: 'Micron / STMicroelectronics'),
    (ID: $2C; Name: 'Micron'),
    (ID: $37; Name: 'AMIC Technology'),
    (ID: $5E; Name: 'Tenx Technology'),
    (ID: $62; Name: 'Sanyo'),
    (ID: $68; Name: 'Boya Microelectronics'),
    (ID: $85; Name: 'Puya Semiconductor'),
    (ID: $89; Name: 'Intel'),
    (ID: $8C; Name: 'ESMT'),
    (ID: $9D; Name: 'ISSI'),
    (ID: $A1; Name: 'Fudan Microelectronics'),
    (ID: $AD; Name: 'SK Hynix'),
    (ID: $B0; Name: 'Sharp'),
    (ID: $BA; Name: 'Zetta Device'),
    (ID: $BF; Name: 'SST / Microchip'),
    (ID: $C2; Name: 'Macronix'),
    (ID: $C8; Name: 'GigaDevice'),
    (ID: $E0; Name: 'Paragon Technology'),
    (ID: $EF; Name: 'Winbond'),
    (ID: $F8; Name: 'Fidelix')
  );

function JedecVendor(ID: byte): string;
var
  i: integer;
begin
  Result := '';

  //7Fh ไม่ใช่ผู้ผลิต แต่เป็นไบต์บอกให้ข้ามไปธนาคารรหัสถัดไป
  if ID = $7F then Exit('(continuation code)');

  for i := Low(Vendors) to High(Vendors) do
    if Vendors[i].ID = ID then Exit(Vendors[i].Name);
end;

function IsDeadID(const B: array of byte): boolean;
var
  i: integer;
  AllZero, AllFF: boolean;
begin
  AllZero := True;
  AllFF := True;

  for i := Low(B) to High(B) do
  begin
    if B[i] <> $00 then AllZero := False;
    if B[i] <> $FF then AllFF := False;
  end;

  Result := AllZero or AllFF;
end;

end.
