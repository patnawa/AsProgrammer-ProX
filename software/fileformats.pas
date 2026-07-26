unit fileformats;

//Загрузка и сохранение прошивок в текстовых форматах:
//Intel HEX (.hex) и Motorola S-record (.s19/.srec/.mot)
//
//Загрузка всегда возвращает непрерывный образ: пропуски в файле заполняются
//FillValue, поэтому незаписанные области остаются стертыми

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  TFwFormat = (ffBinary, ffIntelHex, ffSRecord);

//Определяет формат по расширению имени файла
function DetectFormat(const FileName: string): TFwFormat;

//Загружает файл в Stream. MaxSize ограничивает образ размером микросхемы.
//ErrMsg заполняется при ошибке разбора
function LoadFirmware(const FileName: string; Stream: TMemoryStream;
  MaxSize: cardinal; FillValue: byte; out ErrMsg: string): boolean;

function SaveFirmware(const FileName: string; Stream: TMemoryStream;
  Fmt: TFwFormat; out ErrMsg: string): boolean;

implementation

const
  HexDigits = ['0'..'9', 'A'..'F', 'a'..'f'];

function DetectFormat(const FileName: string): TFwFormat;
var
  Ext: string;
begin
  Ext := LowerCase(ExtractFileExt(FileName));

  if (Ext = '.hex') or (Ext = '.ihx') or (Ext = '.i8hex') then
    Result := ffIntelHex
  else if (Ext = '.s19') or (Ext = '.s28') or (Ext = '.s37') or
          (Ext = '.srec') or (Ext = '.mot') or (Ext = '.sre') then
    Result := ffSRecord
  else
    Result := ffBinary;
end;

function HexByte(const S: string; Pos: integer; out Value: byte): boolean;
begin
  Result := False;
  if Pos + 1 > Length(S) then Exit;
  if not (S[Pos] in HexDigits) then Exit;
  if not (S[Pos+1] in HexDigits) then Exit;
  Value := StrToInt('$' + Copy(S, Pos, 2));
  Result := True;
end;

//------------------------------------------------------------------ Intel HEX

function ParseIntelHex(Lines: TStringList; var Buf: array of byte;
  MaxSize: cardinal; out HighAddr: cardinal; out ErrMsg: string): boolean;
var
  i, j, p: integer;
  S: string;
  Len, RecType, B, Sum: byte;
  Offset, Base, Addr: cardinal;
  Truncated: boolean;
begin
  Result := False;
  ErrMsg := '';
  HighAddr := 0;
  Base := 0;
  Truncated := False;

  for i := 0 to Lines.Count - 1 do
  begin
    S := Trim(Lines[i]);
    if S = '' then Continue;
    if S[1] <> ':' then Continue;   //мусор между записями игнорируем

    if Length(S) < 11 then
    begin
      ErrMsg := Format('Intel HEX: short record at line %d', [i + 1]);
      Exit;
    end;

    if not HexByte(S, 2, Len) then
    begin
      ErrMsg := Format('Intel HEX: bad length at line %d', [i + 1]);
      Exit;
    end;

    if Length(S) < 11 + Len * 2 then
    begin
      ErrMsg := Format('Intel HEX: truncated record at line %d', [i + 1]);
      Exit;
    end;

    //Контрольная сумма записи
    Sum := 0;
    p := 2;
    for j := 0 to Len + 4 do
    begin
      if not HexByte(S, p, B) then
      begin
        ErrMsg := Format('Intel HEX: bad hex at line %d', [i + 1]);
        Exit;
      end;
      Sum := byte(Sum + B);
      Inc(p, 2);
    end;

    if Sum <> 0 then
    begin
      ErrMsg := Format('Intel HEX: checksum error at line %d', [i + 1]);
      Exit;
    end;

    HexByte(S, 4, B);  Offset := cardinal(B) shl 8;
    HexByte(S, 6, B);  Offset := Offset or B;
    HexByte(S, 8, RecType);

    case RecType of
      $00:  //данные
        begin
          for j := 0 to Len - 1 do
          begin
            HexByte(S, 10 + j * 2, B);
            Addr := Base + Offset + cardinal(j);

            if Addr >= MaxSize then
            begin
              Truncated := True;
              Continue;
            end;

            Buf[Addr] := B;
            if Addr > HighAddr then HighAddr := Addr;
          end;
        end;

      $01: Break;   //конец файла

      $02:  //extended segment address
        begin
          HexByte(S, 10, B);  Base := cardinal(B) shl 8;
          HexByte(S, 12, B);  Base := (Base or B) shl 4;
        end;

      $04:  //extended linear address
        begin
          HexByte(S, 10, B);  Base := cardinal(B) shl 8;
          HexByte(S, 12, B);  Base := (Base or B) shl 16;
        end;

      //03 и 05 задают точку старта, для памяти смысла не имеют
      $03, $05: ;
    end;
  end;

  if Truncated then
    ErrMsg := 'Some records were outside the chip size and were skipped';

  Result := True;
end;

//--------------------------------------------------------------- Motorola SREC

function ParseSRecord(Lines: TStringList; var Buf: array of byte;
  MaxSize: cardinal; out HighAddr: cardinal; out ErrMsg: string): boolean;
var
  i, j, p, AddrLen, DataLen: integer;
  S: string;
  Count, B, Sum: byte;
  Addr: cardinal;
  Truncated: boolean;
begin
  Result := False;
  ErrMsg := '';
  HighAddr := 0;
  Truncated := False;

  for i := 0 to Lines.Count - 1 do
  begin
    S := Trim(Lines[i]);
    if S = '' then Continue;
    if (S[1] <> 'S') and (S[1] <> 's') then Continue;
    if Length(S) < 4 then Continue;

    case S[2] of
      '1': AddrLen := 2;
      '2': AddrLen := 3;
      '3': AddrLen := 4;
      '0', '5', '6', '7', '8', '9': Continue;   //заголовок, счетчик, конец
    else
      Continue;
    end;

    if not HexByte(S, 3, Count) then
    begin
      ErrMsg := Format('S-record: bad count at line %d', [i + 1]);
      Exit;
    end;

    if Length(S) < 4 + Count * 2 then
    begin
      ErrMsg := Format('S-record: truncated record at line %d', [i + 1]);
      Exit;
    end;

    //Контрольная сумма: дополнение до единицы суммы count, адреса и данных
    Sum := 0;
    p := 3;
    for j := 0 to Count do
    begin
      if not HexByte(S, p, B) then
      begin
        ErrMsg := Format('S-record: bad hex at line %d', [i + 1]);
        Exit;
      end;
      Sum := byte(Sum + B);
      Inc(p, 2);
    end;

    if Sum <> $FF then
    begin
      ErrMsg := Format('S-record: checksum error at line %d', [i + 1]);
      Exit;
    end;

    Addr := 0;
    for j := 0 to AddrLen - 1 do
    begin
      HexByte(S, 5 + j * 2, B);
      Addr := (Addr shl 8) or B;
    end;

    //count = адрес + данные + контрольная сумма
    DataLen := Count - AddrLen - 1;

    for j := 0 to DataLen - 1 do
    begin
      HexByte(S, 5 + AddrLen * 2 + j * 2, B);

      if (Addr + cardinal(j)) >= MaxSize then
      begin
        Truncated := True;
        Continue;
      end;

      Buf[Addr + cardinal(j)] := B;
      if (Addr + cardinal(j)) > HighAddr then HighAddr := Addr + cardinal(j);
    end;
  end;

  if Truncated then
    ErrMsg := 'Some records were outside the chip size and were skipped';

  Result := True;
end;

//---------------------------------------------------------------------- Load

function LoadFirmware(const FileName: string; Stream: TMemoryStream;
  MaxSize: cardinal; FillValue: byte; out ErrMsg: string): boolean;
var
  Lines: TStringList;
  Buf: array of byte;
  HighAddr: cardinal;
  Fmt: TFwFormat;
  OK: boolean;
begin
  Result := False;
  ErrMsg := '';

  Fmt := DetectFormat(FileName);

  if Fmt = ffBinary then
  begin
    Stream.Clear;
    Stream.LoadFromFile(FileName);
    Stream.Position := 0;
    Exit(True);
  end;

  if MaxSize = 0 then
  begin
    ErrMsg := 'Set the chip size before loading a HEX or S-record file';
    Exit;
  end;

  SetLength(Buf, MaxSize);
  FillChar(Buf[0], MaxSize, FillValue);

  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(FileName);

    if Fmt = ffIntelHex then
      OK := ParseIntelHex(Lines, Buf, MaxSize, HighAddr, ErrMsg)
    else
      OK := ParseSRecord(Lines, Buf, MaxSize, HighAddr, ErrMsg);

    if not OK then Exit;

    Stream.Clear;
    Stream.WriteBuffer(Buf[0], MaxSize);
    Stream.Position := 0;
    Result := True;
  finally
    Lines.Free;
  end;
end;

//---------------------------------------------------------------------- Save

function SaveIntelHex(const FileName: string; Stream: TMemoryStream): boolean;
const
  BytesPerLine = 16;
var
  F: TextFile;
  Data: array of byte;
  Size, Addr: cardinal;
  Len, i: integer;
  Sum: byte;
  S: string;
  LastBase, Base: cardinal;
begin
  Result := False;
  Size := Stream.Size;
  if Size = 0 then Exit;

  SetLength(Data, Size);
  Stream.Position := 0;
  Stream.ReadBuffer(Data[0], Size);

  AssignFile(F, FileName);
  Rewrite(F);
  try
    LastBase := $FFFFFFFF;
    Addr := 0;

    while Addr < Size do
    begin
      Base := Addr shr 16;

      //Смена старших 16 бит адреса - запись типа 04
      if Base <> LastBase then
      begin
        Sum := byte(2 + 0 + 0 + 4 + byte(Base shr 8) + byte(Base));
        WriteLn(F, Format(':02000004%.4X%.2X', [Base, byte(-Sum)]));
        LastBase := Base;
      end;

      Len := BytesPerLine;
      if cardinal(Len) > Size - Addr then Len := Size - Addr;
      //Не переходим границу 64K внутри одной записи
      if ((Addr and $FFFF) + cardinal(Len)) > $10000 then
        Len := $10000 - (Addr and $FFFF);

      Sum := byte(Len) + byte((Addr and $FFFF) shr 8) + byte(Addr and $FF);
      S := Format(':%.2X%.4X00', [Len, Addr and $FFFF]);

      for i := 0 to Len - 1 do
      begin
        S := S + IntToHex(Data[Addr + cardinal(i)], 2);
        Sum := byte(Sum + Data[Addr + cardinal(i)]);
      end;

      WriteLn(F, S + IntToHex(byte(-Sum), 2));
      Inc(Addr, cardinal(Len));
    end;

    WriteLn(F, ':00000001FF');
    Result := True;
  finally
    CloseFile(F);
  end;
end;

function SaveSRecord(const FileName: string; Stream: TMemoryStream): boolean;
const
  BytesPerLine = 16;
var
  F: TextFile;
  Data: array of byte;
  Size, Addr: cardinal;
  Len, i, AddrLen: integer;
  Count, Sum: byte;
  S: string;
  RecCount: cardinal;
begin
  Result := False;
  Size := Stream.Size;
  if Size = 0 then Exit;

  SetLength(Data, Size);
  Stream.Position := 0;
  Stream.ReadBuffer(Data[0], Size);

  //Ширина адреса по размеру образа: S1 до 64K, S2 до 16M, иначе S3
  if Size <= $10000 then AddrLen := 2
  else if Size <= $1000000 then AddrLen := 3
  else AddrLen := 4;

  AssignFile(F, FileName);
  Rewrite(F);
  try
    WriteLn(F, 'S0030000FC');   //пустой заголовок

    Addr := 0;
    RecCount := 0;

    while Addr < Size do
    begin
      Len := BytesPerLine;
      if cardinal(Len) > Size - Addr then Len := Size - Addr;

      Count := byte(Len + AddrLen + 1);
      Sum := Count;

      S := 'S' + IntToStr(AddrLen - 1) + IntToHex(Count, 2);

      for i := AddrLen - 1 downto 0 do
      begin
        S := S + IntToHex(byte(Addr shr (i * 8)), 2);
        Sum := byte(Sum + byte(Addr shr (i * 8)));
      end;

      for i := 0 to Len - 1 do
      begin
        S := S + IntToHex(Data[Addr + cardinal(i)], 2);
        Sum := byte(Sum + Data[Addr + cardinal(i)]);
      end;

      WriteLn(F, S + IntToHex(byte(not Sum), 2));
      Inc(Addr, cardinal(Len));
      Inc(RecCount);
    end;

    //Завершающая запись, парная типу данных
    case AddrLen of
      2: WriteLn(F, 'S9030000FC');
      3: WriteLn(F, 'S804000000FB');
    else
      WriteLn(F, 'S70500000000FA');
    end;

    Result := True;
  finally
    CloseFile(F);
  end;
end;

function SaveFirmware(const FileName: string; Stream: TMemoryStream;
  Fmt: TFwFormat; out ErrMsg: string): boolean;
begin
  ErrMsg := '';
  Result := False;

  try
    case Fmt of
      ffIntelHex: Result := SaveIntelHex(FileName, Stream);
      ffSRecord:  Result := SaveSRecord(FileName, Stream);
    else
      begin
        Stream.Position := 0;
        Stream.SaveToFile(FileName);
        Result := True;
      end;
    end;

    if not Result then ErrMsg := 'Nothing to save: the buffer is empty';
  except
    on E: Exception do ErrMsg := E.Message;
  end;
end;

end.
