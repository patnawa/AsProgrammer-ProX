unit sfdp;

//Serial Flash Discoverable Parameters (JEDEC JESD216)
//Позволяет определить параметры микросхемы, которой нет в chiplist.xml

{$mode objfpc}

interface

uses
  Classes, SysUtils;

type

  TSFDPEraseType = record
    Size: cardinal;    //Размер сектора в байтах. 0 - тип не поддерживается
    Opcode: byte;      //Опкод стирания для этого размера
  end;

  TSFDPInfo = record
    Valid: boolean;
    MajorRev: byte;
    MinorRev: byte;
    Density: cardinal;              //Размер микросхемы в байтах
    PageSize: cardinal;             //Размер страницы записи в байтах
    AddrBytes: byte;                //3 - только 3 байта, 4 - только 4, 34 - оба
    Supports4KErase: boolean;
    Erase4KOpcode: byte;
    EraseTypes: array[1..4] of TSFDPEraseType;
  end;

function SFDPDetect(out Info: TSFDPInfo): boolean;
//Наименьший поддерживаемый размер стирания (обычно 4K)
function SFDPSmallestErase(const Info: TSFDPInfo; out Size: cardinal; out Opcode: byte): boolean;
function SFDPAddrBytesStr(const Info: TSFDPInfo): string;

implementation

uses spi25;

const
  SFDP_SIGNATURE = $50444653;  //'SFDP' little endian
  JEDEC_BASIC_TABLE_ID = $00;

//2^N с защитой от переполнения сдвига
function Pow2(N: cardinal): cardinal;
begin
  if N > 31 then
    Result := 0
  else
    Result := cardinal(1) shl N;
end;

function GetDword(const Buf: array of byte; Offset: integer): cardinal;
begin
  Result := cardinal(Buf[Offset]) or
            (cardinal(Buf[Offset+1]) shl 8) or
            (cardinal(Buf[Offset+2]) shl 16) or
            (cardinal(Buf[Offset+3]) shl 24);
end;

function SFDPDetect(out Info: TSFDPInfo): boolean;
var
  Header: array[0..7] of byte;
  ParamHeader: array[0..7] of byte;
  Table: array[0..79] of byte;    //20 DWORD - с запасом для JESD216B
  NumHeaders, i, TableLen, DwordCount: integer;
  TablePtr: cardinal;
  Dw: cardinal;
  Found: boolean;
  ShiftVal: cardinal;
begin
  Result := False;

  FillChar(Info, SizeOf(Info), 0);
  FillByte(Header, SizeOf(Header), 0);

  UsbAsp25_ReadSFDP(0, Header, SizeOf(Header));

  if GetDword(Header, 0) <> SFDP_SIGNATURE then Exit;

  Info.MinorRev := Header[4];
  Info.MajorRev := Header[5];
  NumHeaders := Header[6] + 1;     //NPH хранится как количество-1
  if NumHeaders > 16 then NumHeaders := 16;

  //Ищем JEDEC Basic Flash Parameter Table
  Found := False;
  TablePtr := 0;
  DwordCount := 0;

  for i := 0 to NumHeaders - 1 do
  begin
    FillByte(ParamHeader, SizeOf(ParamHeader), 0);
    UsbAsp25_ReadSFDP(8 + cardinal(i) * 8, ParamHeader, SizeOf(ParamHeader));

    //ParamHeader: [0]=ID LSB [1]=minor [2]=major [3]=length in dwords [4..6]=ptr [7]=ID MSB
    if ParamHeader[0] = JEDEC_BASIC_TABLE_ID then
    begin
      DwordCount := ParamHeader[3];
      TablePtr := cardinal(ParamHeader[4]) or
                  (cardinal(ParamHeader[5]) shl 8) or
                  (cardinal(ParamHeader[6]) shl 16);
      Found := True;
      Break;
    end;
  end;

  if (not Found) or (DwordCount < 2) then Exit;

  if DwordCount > 20 then DwordCount := 20;
  TableLen := DwordCount * 4;

  FillByte(Table, SizeOf(Table), 0);
  UsbAsp25_ReadSFDP(TablePtr, Table, TableLen);

  //DWORD-1: флаги стирания и адресация
  Dw := GetDword(Table, 0);
  Info.Supports4KErase := (Dw and $03) = $01;
  Info.Erase4KOpcode := (Dw shr 8) and $FF;

  case (Dw shr 17) and $03 of
    0: Info.AddrBytes := 3;
    1: Info.AddrBytes := 34;
    2: Info.AddrBytes := 4;
  else
    Info.AddrBytes := 3;
  end;

  //DWORD-2: плотность
  Dw := GetDword(Table, 4);
  if (Dw and $80000000) = 0 then
    Info.Density := (Dw + 1) div 8            //значение = количество бит - 1
  else
  begin
    ShiftVal := Dw and $7FFFFFFF;
    //2^N бит. Больше 2^34 бит (2 ГБайт) в cardinal не помещается
    if (ShiftVal < 3) or (ShiftVal > 34) then
      Info.Density := 0
    else
      Info.Density := Pow2(ShiftVal - 3);
  end;

  //DWORD-8 и DWORD-9: типы стирания (размер = 2^N байт)
  if DwordCount >= 8 then
  begin
    Dw := GetDword(Table, 28);
    if (Dw and $FF) <> 0 then
    begin
      Info.EraseTypes[1].Size := Pow2(Dw and $FF);
      Info.EraseTypes[1].Opcode := (Dw shr 8) and $FF;
    end;
    if ((Dw shr 16) and $FF) <> 0 then
    begin
      Info.EraseTypes[2].Size := Pow2((Dw shr 16) and $FF);
      Info.EraseTypes[2].Opcode := (Dw shr 24) and $FF;
    end;
  end;

  if DwordCount >= 9 then
  begin
    Dw := GetDword(Table, 32);
    if (Dw and $FF) <> 0 then
    begin
      Info.EraseTypes[3].Size := Pow2(Dw and $FF);
      Info.EraseTypes[3].Opcode := (Dw shr 8) and $FF;
    end;
    if ((Dw shr 16) and $FF) <> 0 then
    begin
      Info.EraseTypes[4].Size := Pow2((Dw shr 16) and $FF);
      Info.EraseTypes[4].Opcode := (Dw shr 24) and $FF;
    end;
  end;

  //DWORD-11: размер страницы (только JESD216 rev A и новее)
  if DwordCount >= 11 then
  begin
    Dw := GetDword(Table, 40);
    Info.PageSize := Pow2((Dw shr 4) and $0F);
  end;

  //Страница по умолчанию, если таблица короткая или значение бессмысленное
  if (Info.PageSize < 1) or (Info.PageSize > 2048) then Info.PageSize := 256;

  Info.Valid := Info.Density > 0;
  Result := Info.Valid;
end;

function SFDPSmallestErase(const Info: TSFDPInfo; out Size: cardinal; out Opcode: byte): boolean;
var
  i: integer;
begin
  Result := False;
  Size := 0;
  Opcode := 0;

  for i := 1 to 4 do
    if Info.EraseTypes[i].Size > 0 then
      if (Size = 0) or (Info.EraseTypes[i].Size < Size) then
      begin
        Size := Info.EraseTypes[i].Size;
        Opcode := Info.EraseTypes[i].Opcode;
        Result := True;
      end;

  //Если таблица типов стирания недоступна, но чип заявил поддержку 4K
  if (not Result) and Info.Supports4KErase and (Info.Erase4KOpcode <> 0) and
     (Info.Erase4KOpcode <> $FF) then
  begin
    Size := 4096;
    Opcode := Info.Erase4KOpcode;
    Result := True;
  end;
end;

function SFDPAddrBytesStr(const Info: TSFDPInfo): string;
begin
  case Info.AddrBytes of
    3: Result := '3';
    4: Result := '4';
    34: Result := '3 or 4';
  else
    Result := '?';
  end;
end;

end.
