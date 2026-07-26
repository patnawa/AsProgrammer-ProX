unit spi25;

{ Test stub standing in for the real spi25 unit.

  sfdp.pas only needs UsbAsp25_ReadSFDP, so this serves a synthetic SFDP image
  out of memory and the parser can be tested with no programmer and no chip.
  Only the tests ever compile against this file; the program links the real
  unit from software\. }

{$mode objfpc}{$H+}

interface

type
  TFakeChip = (
    fcWinbond64,   // W25Q64 shaped: 8 MiB, 256 byte page, 4K/32K/64K erase
    fcNoSFDP,      // answers FF to everything
    fcBigPow2      // density expressed as a power of two
  );

procedure SetFakeChip(AChip: TFakeChip);
function UsbAsp25_ReadSFDP(Addr: longword; var buffer: array of byte;
  bufflen: integer): integer;

implementation

var
  Image: array[0..255] of byte;
  HasImage: boolean = False;

procedure PutDword(Offset: integer; Value: longword);
begin
  Image[Offset]     := byte(Value);
  Image[Offset + 1] := byte(Value shr 8);
  Image[Offset + 2] := byte(Value shr 16);
  Image[Offset + 3] := byte(Value shr 24);
end;

procedure SetFakeChip(AChip: TFakeChip);
const
  TablePtr = $30;
begin
  FillChar(Image, SizeOf(Image), $FF);
  HasImage := AChip <> fcNoSFDP;
  if not HasImage then Exit;

  // header: 'SFDP', minor 6, major 1, one parameter header
  Image[0] := $53; Image[1] := $46; Image[2] := $44; Image[3] := $50;
  Image[4] := $06;
  Image[5] := $01;
  Image[6] := $00;          // NPH is stored as count - 1
  Image[7] := $FF;

  // parameter header: JEDEC basic table, 16 dwords, at TablePtr
  Image[8]  := $00;         // id LSB
  Image[9]  := $06;
  Image[10] := $01;
  Image[11] := 16;          // length in dwords
  Image[12] := byte(TablePtr);
  Image[13] := 0;
  Image[14] := 0;
  Image[15] := $FF;         // id MSB

  // DWORD-1: 4K erase supported, opcode 20h, three byte addressing
  PutDword(TablePtr + 0, $00002001);

  // DWORD-2: density
  if AChip = fcBigPow2 then
    PutDword(TablePtr + 4, $80000000 or 34)   // 2^34 bits = 2 GiB
  else
    PutDword(TablePtr + 4, 8 * 1024 * 1024 * 8 - 1);  // 64 Mbit, minus one

  // DWORD-8: erase type 1 = 2^12 with 20h, type 2 = 2^15 with 52h
  PutDword(TablePtr + 28, $520F200C);

  // DWORD-9: erase type 3 = 2^16 with D8h, type 4 unused
  PutDword(TablePtr + 32, $0000D810);

  // DWORD-11: page size 2^8
  PutDword(TablePtr + 40, $00000080);
end;

function UsbAsp25_ReadSFDP(Addr: longword; var buffer: array of byte;
  bufflen: integer): integer;
var
  i: integer;
begin
  for i := 0 to bufflen - 1 do
    if (not HasImage) or (Addr + longword(i) > High(Image)) then
      buffer[i] := $FF
    else
      buffer[i] := Image[Addr + longword(i)];

  Result := bufflen;
end;

end.
