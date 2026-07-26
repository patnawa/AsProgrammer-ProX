program unittests;

{ Hardware-free tests for the parts of AsProgrammer ProX that are pure logic:
  the SFDP parser, the JEDEC vendor table and the serial number generator.

  Build and run:
    copy ..\software\sfdp.pas ..\software\jedec.pas ..\software\serialnum.pas .
    fpc -Twin32 -Pi386 -Mobjfpc -Sh unittests.lpr && unittests.exe

  sfdp.pas normally talks to a chip through spi25. For the test a stub unit of
  the same name feeds it a synthetic parameter table instead, so the parser can
  be exercised without any hardware. }

{$mode objfpc}{$H+}

uses
  SysUtils, sfdp, jedec, serialnum, spi25;

var
  Failures: integer = 0;

procedure Check(const Name: string; Cond: boolean);
begin
  if Cond then
    WriteLn('  ok   ', Name)
  else
  begin
    WriteLn('  FAIL ', Name);
    Inc(Failures);
  end;
end;

// ---------------------------------------------------------------- SFDP

procedure TestSFDPWinbond;
var
  Info: TSFDPInfo;
  Size: cardinal;
  Op: byte;
begin
  WriteLn('SFDP: a W25Q64 style table');
  SetFakeChip(fcWinbond64);

  Check('detected', SFDPDetect(Info));
  Check('revision 1.6', (Info.MajorRev = 1) and (Info.MinorRev = 6));
  Check('8 MiB', Info.Density = 8 * 1024 * 1024);
  Check('page 256', Info.PageSize = 256);
  Check('3 byte addressing', Info.AddrBytes = 3);
  Check('4K erase advertised', Info.Supports4KErase);
  Check('erase type 1 is 4K/20h',
        (Info.EraseTypes[1].Size = 4096) and (Info.EraseTypes[1].Opcode = $20));
  Check('erase type 2 is 32K/52h',
        (Info.EraseTypes[2].Size = 32768) and (Info.EraseTypes[2].Opcode = $52));
  Check('erase type 3 is 64K/D8h',
        (Info.EraseTypes[3].Size = 65536) and (Info.EraseTypes[3].Opcode = $D8));

  Check('smallest erase found', SFDPSmallestErase(Info, Size, Op));
  Check('smallest erase is 4K/20h', (Size = 4096) and (Op = $20));
  Check('address string', SFDPAddrBytesStr(Info) = '3');
end;

procedure TestSFDPNoSignature;
var
  Info: TSFDPInfo;
begin
  WriteLn('SFDP: a chip without a table');
  SetFakeChip(fcNoSFDP);
  Check('not detected', not SFDPDetect(Info));
  Check('marked invalid', not Info.Valid);
end;

procedure TestSFDPPowerOfTwoDensity;
var
  Info: TSFDPInfo;
begin
  WriteLn('SFDP: density given as a power of two');
  SetFakeChip(fcBigPow2);
  Check('detected', SFDPDetect(Info));
  // DWORD-2 bit31 set, value 34 -> 2^34 bits -> 2 GiB
  Check('2 GiB', Info.Density = cardinal(1) shl 31);
end;

// --------------------------------------------------------------- JEDEC

procedure TestJedec;
var
  B: array[0..2] of byte;
begin
  WriteLn('JEDEC vendor table');
  Check('EF is Winbond', JedecVendor($EF) = 'Winbond');
  Check('C2 is Macronix', JedecVendor($C2) = 'Macronix');
  Check('C8 is GigaDevice', JedecVendor($C8) = 'GigaDevice');
  Check('1F is Atmel family', Pos('Atmel', JedecVendor($1F)) > 0);
  Check('7F is the continuation code', Pos('continuation', JedecVendor($7F)) > 0);
  Check('an unassigned id is empty', JedecVendor($44) = '');

  B[0] := 0; B[1] := 0; B[2] := 0;
  Check('all zero is a dead id', IsDeadID(B));
  B[0] := $FF; B[1] := $FF; B[2] := $FF;
  Check('all FF is a dead id', IsDeadID(B));
  B[0] := $EF; B[1] := $40; B[2] := $17;
  Check('a real id is alive', not IsDeadID(B));
end;

// -------------------------------------------------------- serial numbers

procedure TestSerial;
var
  S: TProdSettings;
  Bytes: array[0..7] of byte;
  Data: array[0..255] of byte;
  i: integer;
begin
  WriteLn('Serial numbers');
  DefaultProdSettings(S);
  S.SNEnabled := True;
  S.SNLength := 4;
  S.SNMode := smIncrement;
  S.SNValue := $12345678;
  S.SNBigEndian := True;

  BuildSerialBytes(S, Bytes);
  Check('big endian order',
        (Bytes[0] = $12) and (Bytes[1] = $34) and (Bytes[2] = $56) and (Bytes[3] = $78));
  Check('hex form', SerialToStr(S) = '12345678');

  S.SNBigEndian := False;
  BuildSerialBytes(S, Bytes);
  Check('little endian order',
        (Bytes[0] = $78) and (Bytes[1] = $56) and (Bytes[2] = $34) and (Bytes[3] = $12));

  // placing it in a buffer
  S.SNBigEndian := True;
  S.SNAddress := 16;
  FillChar(Data, SizeOf(Data), $FF);
  Check('applied', ApplySerial(S, Data, SizeOf(Data)));
  Check('written at the address',
        (Data[16] = $12) and (Data[19] = $78));
  Check('the byte before is untouched', Data[15] = $FF);
  Check('the byte after is untouched', Data[20] = $FF);

  // must refuse to run off the end of the buffer
  S.SNAddress := 254;
  Check('refuses to overflow the buffer', not ApplySerial(S, Data, SizeOf(Data)));

  // date mode puts a BCD date in the first three bytes
  S.SNAddress := 0;
  S.SNLength := 8;
  S.SNMode := smDateIncrement;
  S.SNValue := 1;
  BuildSerialBytes(S, Bytes);
  Check('BCD date digits are valid',
        ((Bytes[0] and $0F) <= 9) and ((Bytes[0] shr 4) <= 9) and
        ((Bytes[1] and $0F) <= 9) and ((Bytes[1] shr 4) <= 9) and
        ((Bytes[2] and $0F) <= 9) and ((Bytes[2] shr 4) <= 9));
  Check('month is between 1 and 12',
        ((Bytes[1] shr 4) * 10 + (Bytes[1] and $0F)) in [1..12]);
  Check('counter follows the date', Bytes[7] = 1);

  // random mode: eight random bytes twice running should not match
  S.SNMode := smRandom;
  S.SNLength := 8;
  Check('random mode fills the whole length', Length(SerialToStr(S)) = 16);
  Check('random mode varies between calls', SerialToStr(S) <> SerialToStr(S));
end;

begin
  WriteLn('AsProgrammer ProX unit tests');
  WriteLn;

  TestSFDPWinbond;
  TestSFDPNoSignature;
  TestSFDPPowerOfTwoDensity;
  TestJedec;
  TestSerial;

  WriteLn;
  if Failures = 0 then
    WriteLn('ALL PASSED')
  else
    WriteLn(Failures, ' FAILURES');
  Halt(Failures);
end.
