unit labtools;

// The decidable parts of the bench tools: which I2C addresses may be probed,
// how a typed SPI command is parsed, and how a reply is shown.
//
// These are small, but they are the parts that are worth getting exactly
// right and are easy to get quietly wrong. An I2C scan that probes the
// reserved address ranges can put a device into a mode nobody asked for; a
// hex parser that silently drops a malformed byte sends a different command
// than the one on screen, which on a flash chip is how a typo becomes an
// erase.
//
// So the parsing and the address policy live here, tested, and the dialogs
// above them only move bytes and paint text.

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

type
  TByteArray = array of byte;

const
  // I2C reserved ranges, from the specification:
  //   0000 xxx  general call, start byte, CBUS, reserved
  //   1111 xxx  10-bit addressing and device ID
  // Probing them is not a read. The general call address is a broadcast
  // every device on the bus obeys, and 1111 0xx is the 10-bit escape, so a
  // "scan" that includes them is issuing commands rather than asking
  // questions.
  I2C_FIRST_PROBE_ADDRESS = $08;
  I2C_LAST_PROBE_ADDRESS  = $77;

// True when a 7-bit address is safe to probe with a bare address byte.
function I2CAddressIsProbeable(Address: byte): boolean;

// The 8-bit bus byte for a 7-bit address: address shifted up, R/W in bit 0.
// Getting this wrong by a factor of two is the single most common I2C
// mistake, so it is named and tested rather than inlined at each call site.
function I2CWriteByteFor(Address7: byte): byte;
function I2CReadByteFor(Address7: byte): byte;

// Parses a line of whitespace-separated hex bytes typed by an operator.
//
// Accepts "9F", "9f", "0x9F" and "9Fh" forms, separated by spaces, tabs or
// commas. Refuses anything else rather than skipping it: a console that
// silently drops a token sends a command the operator did not read on
// screen, and on a flash chip the difference between 0x20 and 0x60 is a
// sector and the whole part.
function ParseHexBytes(const Text: string; out Bytes: TByteArray;
  out ErrorText: string): boolean;

// Renders bytes as a canonical hex dump line: offset, hex, then ASCII with
// non-printables as dots.
function HexDumpLine(Offset: cardinal; const Data: TByteArray;
  Start, Count: integer): string;

// The whole buffer as hex dump lines, 16 bytes to a line.
function HexDump(const Data: TByteArray; BaseAddress: cardinal): TStringArray;

// Bytes as bare space-separated hex, for a one-line reply.
function BytesToHexText(const Data: TByteArray): string;

implementation

function I2CAddressIsProbeable(Address: byte): boolean;
begin
  Result := (Address >= I2C_FIRST_PROBE_ADDRESS) and
            (Address <= I2C_LAST_PROBE_ADDRESS);
end;

function I2CWriteByteFor(Address7: byte): byte;
begin
  Result := (Address7 shl 1) and $FE;
end;

function I2CReadByteFor(Address7: byte): byte;
begin
  Result := ((Address7 shl 1) and $FE) or $01;
end;

function HexDigitValue(C: char; out Value: byte): boolean;
begin
  Value := 0;
  case C of
    '0'..'9': Value := Ord(C) - Ord('0');
    'a'..'f': Value := 10 + Ord(C) - Ord('a');
    'A'..'F': Value := 10 + Ord(C) - Ord('A');
  else
    Exit(False);
  end;
  Result := True;
end;

function ParseOneToken(const Token: string; out Value: byte;
  out ErrorText: string): boolean;
var
  Body: string;
  Hi, Lo: byte;
begin
  Result := False;
  Value := 0;
  ErrorText := '';
  Body := Token;

  //Accept the three forms an operator might type without thinking about it.
  if (Length(Body) > 2) and (Body[1] = '0') and
     ((Body[2] = 'x') or (Body[2] = 'X')) then
    Body := Copy(Body, 3, MaxInt)
  else if (Length(Body) > 1) and
          ((Body[Length(Body)] = 'h') or (Body[Length(Body)] = 'H')) then
    Body := Copy(Body, 1, Length(Body) - 1);

  if Length(Body) = 1 then
  begin
    if not HexDigitValue(Body[1], Lo) then
    begin
      ErrorText := '"' + Token + '" is not a hex byte';
      Exit;
    end;
    Value := Lo;
    Exit(True);
  end;

  if Length(Body) <> 2 then
  begin
    //Three or more digits is almost always a missing space between two
    //bytes, and guessing where it belongs would send something else.
    ErrorText := '"' + Token + '" is not a single byte; separate bytes with ' +
                 'spaces';
    Exit;
  end;

  if (not HexDigitValue(Body[1], Hi)) or (not HexDigitValue(Body[2], Lo)) then
  begin
    ErrorText := '"' + Token + '" is not a hex byte';
    Exit;
  end;
  Value := (Hi shl 4) or Lo;
  Result := True;
end;

function ParseHexBytes(const Text: string; out Bytes: TByteArray;
  out ErrorText: string): boolean;
var
  i, TokenStart, Count: integer;
  Token: string;
  Value: byte;
  C: char;
begin
  Bytes := nil;
  ErrorText := '';
  Result := False;
  Count := 0;
  SetLength(Bytes, Length(Text) div 2 + 1);

  i := 1;
  while i <= Length(Text) + 1 do
  begin
    if i <= Length(Text) then C := Text[i] else C := ' ';
    if (C = ' ') or (C = #9) or (C = ',') or (i > Length(Text)) then
    begin
      Inc(i);
      Continue;
    end;

    TokenStart := i;
    while (i <= Length(Text)) and (Text[i] <> ' ') and (Text[i] <> #9) and
          (Text[i] <> ',') do
      Inc(i);
    Token := Copy(Text, TokenStart, i - TokenStart);

    if not ParseOneToken(Token, Value, ErrorText) then
    begin
      Bytes := nil;
      Exit;
    end;
    if Count > High(Bytes) then SetLength(Bytes, Count + 16);
    Bytes[Count] := Value;
    Inc(Count);
  end;

  SetLength(Bytes, Count);
  if Count = 0 then
  begin
    //An empty command is not an error the operator needs a message about,
    //but it must not be reported as a parsed command either.
    ErrorText := 'nothing to send';
    Exit;
  end;
  Result := True;
end;

function BytesToHexText(const Data: TByteArray): string;
var
  i: integer;
begin
  Result := '';
  for i := 0 to High(Data) do
  begin
    if i > 0 then Result := Result + ' ';
    Result := Result + IntToHex(Data[i], 2);
  end;
end;

function HexDumpLine(Offset: cardinal; const Data: TByteArray;
  Start, Count: integer): string;
var
  i: integer;
  Hex, Ascii: string;
  B: byte;
begin
  Hex := '';
  Ascii := '';
  for i := 0 to 15 do
  begin
    if i < Count then
    begin
      B := Data[Start + i];
      Hex := Hex + IntToHex(B, 2) + ' ';
      //Anything outside printable ASCII becomes a dot; a raw control byte
      //in a memo can move the caret or eat the rest of the line.
      if (B >= 32) and (B < 127) then
        Ascii := Ascii + Char(B)
      else
        Ascii := Ascii + '.';
    end
    else
      Hex := Hex + '   ';
    //A gap at the halfway mark, the way every hex dump has done it since
    //people started counting bytes by eye.
    if i = 7 then Hex := Hex + ' ';
  end;
  Result := IntToHex(Offset, 8) + '  ' + Hex + ' |' + Ascii + '|';
end;

function HexDump(const Data: TByteArray; BaseAddress: cardinal): TStringArray;
var
  Lines, i, Count: integer;
begin
  Result := nil;
  if Length(Data) = 0 then Exit;
  Lines := (Length(Data) + 15) div 16;
  SetLength(Result, Lines);
  for i := 0 to Lines - 1 do
  begin
    Count := Length(Data) - i * 16;
    if Count > 16 then Count := 16;
    Result[i] := HexDumpLine(BaseAddress + cardinal(i * 16), Data,
                             i * 16, Count);
  end;
end;

end.
