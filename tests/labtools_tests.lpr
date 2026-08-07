program labtools_tests;

// The decidable parts of the bench tools.
//
// Small surface, but the failure modes are not small. A scan that probes the
// I2C reserved ranges is issuing broadcasts rather than asking questions, and
// a hex parser that silently drops a malformed token sends a command the
// operator never read on screen.

{$mode objfpc}{$H+}

uses
  SysUtils, labtools;

var
  Failures, Assertions: integer;

procedure Check(const Name: string; Condition: boolean);
begin
  Inc(Assertions);
  if not Condition then
  begin
    Inc(Failures);
    WriteLn('FAIL: ', Name);
  end;
end;

procedure CheckText(const Name, Expected, Actual: string);
begin
  Inc(Assertions);
  if Expected <> Actual then
  begin
    Inc(Failures);
    WriteLn('FAIL: ', Name, ' (expected "', Expected, '", got "',
            Actual, '")');
  end;
end;

procedure TestI2CAddressPolicy;
var
  A: integer;
  Probeable: integer;
begin
  //0000 xxx is general call / start byte / CBUS, and 1111 xxx is the 10-bit
  //escape and device ID. Probing those is not a read: the general call
  //address is a broadcast every device on the bus obeys.
  Check('the general call address is never probed',
    not I2CAddressIsProbeable($00));
  Check('the low reserved range is never probed',
    not I2CAddressIsProbeable($07));
  Check('the 10-bit escape range is never probed',
    not I2CAddressIsProbeable($78));
  Check('the top reserved address is never probed',
    not I2CAddressIsProbeable($7F));

  Check('the first usable address is probed', I2CAddressIsProbeable($08));
  Check('a typical EEPROM address is probed', I2CAddressIsProbeable($50));
  Check('the last usable address is probed', I2CAddressIsProbeable($77));

  Probeable := 0;
  for A := 0 to $FF do
    if I2CAddressIsProbeable(byte(A)) then Inc(Probeable);
  //0x08..0x77 inclusive is 112 addresses, and nothing above 0x7F can be a
  //7-bit address at all.
  Check('exactly 112 addresses are probeable', Probeable = 112);
end;

procedure TestI2CBusBytes;
begin
  //Off by a factor of two is the most common I2C mistake there is, so the
  //shift is named and pinned rather than written out at each call site.
  Check('a write byte shifts the address up', I2CWriteByteFor($50) = $A0);
  Check('a read byte sets bit 0', I2CReadByteFor($50) = $A1);
  Check('the low bit of the address never leaks into the R/W bit',
    I2CWriteByteFor($51) = $A2);
  Check('and the read form matches', I2CReadByteFor($51) = $A3);
  Check('address 0x08 writes as 0x10', I2CWriteByteFor($08) = $10);
  Check('address 0x77 writes as 0xEE', I2CWriteByteFor($77) = $EE);
end;

procedure TestHexParsingAccepts;
var
  B: TByteArray;
  E: string;
begin
  Check('a bare pair parses', ParseHexBytes('9F', B, E));
  Check('as one byte', (Length(B) = 1) and (B[0] = $9F));

  Check('lower case parses', ParseHexBytes('9f', B, E));
  Check('to the same byte', (Length(B) = 1) and (B[0] = $9F));

  Check('the 0x form parses', ParseHexBytes('0x9F', B, E));
  Check('to the same byte', (Length(B) = 1) and (B[0] = $9F));

  Check('the trailing-h form parses', ParseHexBytes('9Fh', B, E));
  Check('to the same byte', (Length(B) = 1) and (B[0] = $9F));

  Check('a single digit is a byte', ParseHexBytes('5', B, E));
  Check('padded on the left', (Length(B) = 1) and (B[0] = $05));

  //A real command: read status register, then two dummy bytes.
  Check('several bytes parse', ParseHexBytes('05 00 00', B, E));
  Check('in order',
    (Length(B) = 3) and (B[0] = $05) and (B[1] = $00) and (B[2] = $00));

  Check('commas and tabs separate too',
    ParseHexBytes('03,00' + #9 + '00 00', B, E));
  Check('giving four bytes', Length(B) = 4);

  Check('leading and trailing space is fine',
    ParseHexBytes('   9F   ', B, E));
  Check('still one byte', Length(B) = 1);

  Check('a long command parses',
    ParseHexBytes('06 02 00 00 00 DE AD BE EF', B, E));
  Check('with every byte kept', Length(B) = 9);
  Check('including the last', B[8] = $EF);
end;

procedure TestHexParsingRefuses;
var
  B: TByteArray;
  E: string;
begin
  //Silently dropping a bad token would send a command the operator did not
  //read on screen. On a flash chip, 0x20 and 0x60 are a sector and the
  //whole part.
  Check('a non-hex token is refused', not ParseHexBytes('ZZ', B, E));
  Check('and says which token', Pos('ZZ', E) > 0);
  Check('and returns no bytes at all', Length(B) = 0);

  Check('a bad token anywhere refuses the whole line',
    not ParseHexBytes('9F 00 GG 00', B, E));
  Check('with nothing sent', Length(B) = 0);

  //Three digits is almost always a missing space, and guessing where it
  //belongs would send something different from what was typed.
  Check('three digits are refused', not ParseHexBytes('9F0', B, E));
  Check('and suggest the fix', Pos('separate bytes with spaces', E) > 0);

  Check('an empty line is not a command', not ParseHexBytes('', B, E));
  Check('and says so', E = 'nothing to send');
  Check('whitespace only is not a command',
    not ParseHexBytes('   ' + #9 + ' ', B, E));

  Check('a lone 0x prefix is refused', not ParseHexBytes('0x', B, E));
  Check('a lone h suffix is refused', not ParseHexBytes('h', B, E));
end;

procedure TestHexDump;
var
  B: TByteArray;
  Lines: TStringArray;
  i: integer;
begin
  SetLength(B, 16);
  for i := 0 to 15 do B[i] := byte($40 + i);
  Lines := HexDump(B, 0);
  Check('sixteen bytes are one line', Length(Lines) = 1);
  //Offset, hex with the usual gap at the halfway mark, then ASCII.
  CheckText('the line is canonical',
    '00000000  40 41 42 43 44 45 46 47  48 49 4A 4B 4C 4D 4E 4F  |@ABCDEFGHIJKLMNO|',
    Lines[0]);

  //A short tail must pad the hex column so the ASCII column stays put.
  SetLength(B, 3);
  B[0] := $41; B[1] := $42; B[2] := $43;
  Lines := HexDump(B, $1000);
  Check('a short line still dumps', Length(Lines) = 1);
  CheckText('padded so the ASCII column does not move',
    '00001000  41 42 43                                          |ABC|',
    Lines[0]);

  //Control bytes must never reach a memo raw: a stray CR moves the caret
  //and eats the line.
  SetLength(B, 4);
  B[0] := $00; B[1] := $0D; B[2] := $7F; B[3] := $FF;
  Lines := HexDump(B, 0);
  Check('non-printables become dots', Pos('|....|', Lines[0]) > 0);

  SetLength(B, 33);
  for i := 0 to 32 do B[i] := byte(i);
  Lines := HexDump(B, 0);
  Check('33 bytes are three lines', Length(Lines) = 3);
  Check('the second line is offset by 16', Pos('00000010', Lines[1]) = 1);
  Check('the third by 32', Pos('00000020', Lines[2]) = 1);

  SetLength(B, 0);
  Lines := HexDump(B, 0);
  Check('no data is no lines', Length(Lines) = 0);
end;

procedure TestBytesToHexText;
var
  B: TByteArray;
begin
  SetLength(B, 3);
  B[0] := $EF; B[1] := $60; B[2] := $17;
  CheckText('a reply renders as spaced hex', 'EF 60 17', BytesToHexText(B));
  SetLength(B, 1);
  B[0] := $00;
  CheckText('a single zero byte still renders', '00', BytesToHexText(B));
  SetLength(B, 0);
  CheckText('no bytes render as nothing', '', BytesToHexText(B));
end;

begin
  TestI2CAddressPolicy;
  TestI2CBusBytes;
  TestHexParsingAccepts;
  TestHexParsingRefuses;
  TestHexDump;
  TestBytesToHexText;
  WriteLn(Assertions, ' assertions, ', Failures, ' failures');
  if Failures <> 0 then Halt(1);
  WriteLn('ALL PASSED');
end.
