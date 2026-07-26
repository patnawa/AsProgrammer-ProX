unit spi25;

{ Test stub standing in for the real spi25 unit.

  sfdp.pas only needs UsbAsp25_ReadSFDP, so this serves a synthetic SFDP image
  out of memory and the parser can be tested with no programmer and no chip.
  Only the tests ever compile against this file; the program links the real
  unit from software\.

  The images here are hand built from the JESD216 layout, one per shape of
  chip worth testing: a plain uniform part, a part that declares how to enter
  four byte addressing, and a part with boot blocks of a different size. }

{$mode objfpc}{$H+}

interface

type
  TFakeChip = (
    fcWinbond64,   // W25Q64 shaped: 8 MiB, 256 byte page, 4K/32K/64K erase
    fcNoSFDP,      // answers FF to everything
    fcBigPow2,     // density expressed as a power of two
    fcMicron256,   // DWORD-16 and a 4 byte address instruction table
    fcBootBlock    // a sector map with regions of different erase sizes
  );

procedure SetFakeChip(AChip: TFakeChip);
function UsbAsp25_ReadSFDP(Addr: longword; var buffer: array of byte;
  bufflen: integer): integer;

implementation

var
  Image: array[0..511] of byte;
  HasImage: boolean = False;

procedure PutDword(Offset: integer; Value: longword);
begin
  Image[Offset]     := byte(Value);
  Image[Offset + 1] := byte(Value shr 8);
  Image[Offset + 2] := byte(Value shr 16);
  Image[Offset + 3] := byte(Value shr 24);
end;

// one entry of the parameter header list, Index counts from zero
procedure PutParamHeader(Index: integer; IdLSB, IdMSB: byte;
  Dwords: byte; Ptr: longword);
var
  Base: integer;
begin
  Base := 8 + Index * 8;
  Image[Base]     := IdLSB;
  Image[Base + 1] := $06;          // minor revision
  Image[Base + 2] := $01;          // major revision
  Image[Base + 3] := Dwords;
  Image[Base + 4] := byte(Ptr);
  Image[Base + 5] := byte(Ptr shr 8);
  Image[Base + 6] := byte(Ptr shr 16);
  Image[Base + 7] := IdMSB;
end;

procedure SetFakeChip(AChip: TFakeChip);
const
  TablePtr = $40;   // the basic table
  Ptr4BAIT = $A0;   // the four byte address instruction table
  PtrMap   = $B0;   // the sector map
begin
  FillChar(Image, SizeOf(Image), $FF);
  HasImage := AChip <> fcNoSFDP;
  if not HasImage then Exit;

  // header: 'SFDP', minor 6, major 1
  Image[0] := $53; Image[1] := $46; Image[2] := $44; Image[3] := $50;
  Image[4] := $06;
  Image[5] := $01;
  Image[6] := $00;          // NPH is stored as count - 1
  Image[7] := $FF;

  PutParamHeader(0, $00, $FF, 20, TablePtr);

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

  case AChip of

    fcMicron256:
      begin
        Image[6] := $01;                       // two parameter headers
        PutParamHeader(1, $84, $FF, 2, Ptr4BAIT);

        // DWORD-1 again, this time declaring four byte addressing only
        PutDword(TablePtr + 0, $00042001);

        // DWORD-16
        //   bits 7:0 = 02h  status register write enable is 06h
        //   bit  11        soft reset with 66h then 99h
        //   bit  25        enter four byte mode with WREN then B7h
        PutDword(TablePtr + 60, $02000802);

        // 4BAIT DWORD-1: 13h read, 12h page program,
        //                erase types 1 and 3 have four byte opcodes
        PutDword(Ptr4BAIT + 0, $00000A41);

        // 4BAIT DWORD-2: type 1 = 21h, type 2 unused, type 3 = DCh
        PutDword(Ptr4BAIT + 4, $00DC0021);
      end;

    fcBootBlock:
      begin
        Image[6] := $01;                       // two parameter headers
        PutParamHeader(1, $81, $FF, 4, PtrMap);

        // map descriptor: bit 0 = map descriptor, bit 1 = last, three regions
        PutDword(PtrMap + 0, $00020003);

        // region 1: 64 KiB, erase type 1 only
        PutDword(PtrMap + 4, $0000FF01);
        // region 2: 8 MiB - 128 KiB, erase types 1 and 3
        PutDword(PtrMap + 8, $007DFF05);
        // region 3: 64 KiB, erase type 1 only
        PutDword(PtrMap + 12, $0000FF01);
      end;

  end;
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
