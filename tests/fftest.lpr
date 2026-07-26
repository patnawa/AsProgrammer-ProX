program fftest;

{$mode objfpc}{$H+}

uses
  Classes, SysUtils, fileformats;

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

//Round trip: buffer -> file -> buffer
procedure RoundTrip(const Name, FileName: string; Fmt: TFwFormat; Size: cardinal);
var
  Src, Dst: TMemoryStream;
  A, B: array of byte;
  i: integer;
  Err: string;
  Same: boolean;
begin
  SetLength(A, Size);
  for i := 0 to Size - 1 do
    A[i] := byte((i * 7 + (i shr 8) * 31 + 5) and $FF);

  Src := TMemoryStream.Create;
  Dst := TMemoryStream.Create;
  try
    Src.WriteBuffer(A[0], Size);

    Check(Name + ': save', SaveFirmware(FileName, Src, Fmt, Err));
    if Err <> '' then WriteLn('       save msg: ', Err);

    Check(Name + ': load', LoadFirmware(FileName, Dst, Size, $FF, Err));
    if Err <> '' then WriteLn('       load msg: ', Err);

    Check(Name + ': size', Dst.Size = Int64(Size));

    SetLength(B, Size);
    Dst.Position := 0;
    Dst.ReadBuffer(B[0], Size);

    Same := True;
    for i := 0 to Size - 1 do
      if A[i] <> B[i] then
      begin
        WriteLn(Format('       first diff at 0x%.6x: %.2x <> %.2x', [i, A[i], B[i]]));
        Same := False;
        Break;
      end;
    Check(Name + ': content', Same);
  finally
    Src.Free;
    Dst.Free;
  end;
end;

//Gaps in the file must stay at the fill value
procedure SparseTest;
var
  F: TextFile;
  St: TMemoryStream;
  B: array of byte;
  Err: string;
  fn: string;
begin
  fn := 'sparse.hex';
  AssignFile(F, fn);
  Rewrite(F);
  //4 bytes at 0x0000 and 4 bytes at 0x0100
  WriteLn(F, ':040000001122334452');
  WriteLn(F, ':04010000AABBCCDDED');
  WriteLn(F, ':00000001FF');
  CloseFile(F);

  St := TMemoryStream.Create;
  try
    Check('sparse: load', LoadFirmware(fn, St, 512, $FF, Err));
    if St.Size < 512 then begin WriteLn('       msg: ', Err); Exit; end;
    SetLength(B, 512);
    St.Position := 0;
    St.ReadBuffer(B[0], 512);
    Check('sparse: data at 0', (B[0] = $11) and (B[3] = $44));
    Check('sparse: gap is FF', (B[4] = $FF) and (B[255] = $FF));
    Check('sparse: data at 0x100', (B[$100] = $AA) and (B[$103] = $DD));
    Check('sparse: tail is FF', B[511] = $FF);
  finally
    St.Free;
  end;
end;

//A corrupted checksum must be rejected, not silently accepted
procedure BadChecksumTest;
var
  F: TextFile;
  St: TMemoryStream;
  Err: string;
begin
  AssignFile(F, 'bad.hex');
  Rewrite(F);
  WriteLn(F, ':0400000011223344FF');   // wrong checksum
  WriteLn(F, ':00000001FF');
  CloseFile(F);

  St := TMemoryStream.Create;
  try
    Check('bad checksum rejected', not LoadFirmware('bad.hex', St, 512, $FF, Err));
    WriteLn('       msg: ', Err);
  finally
    St.Free;
  end;
end;

//Extended linear addressing above 64K
procedure ExtLinearTest;
var
  F: TextFile;
  St: TMemoryStream;
  B: array of byte;
  Err: string;
begin
  AssignFile(F, 'ext.hex');
  Rewrite(F);
  WriteLn(F, ':020000040001F9');        // base = 0x00010000
  WriteLn(F, ':040000005566778842');    // 4 bytes at 0x00010000
  WriteLn(F, ':00000001FF');
  CloseFile(F);

  St := TMemoryStream.Create;
  try
    Check('ext linear: load', LoadFirmware('ext.hex', St, $20000, $FF, Err));
    if St.Size < $20000 then begin WriteLn('       msg: ', Err); Exit; end;
    SetLength(B, $20000);
    St.Position := 0;
    St.ReadBuffer(B[0], $20000);
    Check('ext linear: data at 0x10000', (B[$10000] = $55) and (B[$10003] = $88));
    Check('ext linear: below is FF', B[0] = $FF);
  finally
    St.Free;
  end;
end;

begin
  WriteLn('fileformats round trip tests');

  RoundTrip('ihex 4K',   'rt4k.hex',  ffIntelHex, 4096);
  RoundTrip('ihex 128K', 'rt128k.hex', ffIntelHex, 131072);   // crosses 64K
  RoundTrip('srec 4K',   'rt4k.s19',  ffSRecord,  4096);
  RoundTrip('srec 128K', 'rt128k.s19', ffSRecord,  131072);
  RoundTrip('bin 4K',    'rt4k.bin',  ffBinary,   4096);

  SparseTest;
  BadChecksumTest;
  ExtLinearTest;

  WriteLn;
  if Failures = 0 then
    WriteLn('ALL PASSED')
  else
    WriteLn(Failures, ' FAILURES');
  Halt(Failures);
end.
