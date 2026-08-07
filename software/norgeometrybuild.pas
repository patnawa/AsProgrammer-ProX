unit norgeometrybuild;

// Turning what a chip says about itself into the list of blocks an erase is
// allowed to touch.
//
// This is the most consequential arithmetic in the program. The block list it
// produces is what the planner erases; a block that is the wrong size, at the
// wrong address, or carrying the wrong opcode does not fail loudly, it
// destroys data that was never part of the job. On a boot-block part, where
// 4 KB sectors sit next to 64 KB blocks, getting the region boundaries wrong
// wipes the bootloader while reporting success.
//
// It lived inside main.pas, reading four module-level globals, which meant it
// could not be exercised without a GUI and a chip. Nothing about it needs
// either: it is a pure function of the chip size, the page size, the SFDP
// tables, and a fallback sector size. So it takes those as arguments and
// lives here, where the SFDP corpus in tests/sfdp can be pointed straight at
// it.
//
// The rules it enforces, in order:
//
//   - A declared-but-unreadable sector map is refused outright. A chip that
//     says "I have a sector map" and then produces an ambiguous one is not a
//     chip to guess about.
//   - An SFDP density that disagrees with the selected chip size is refused.
//     One of the two is wrong and neither is safe to prefer.
//   - Within each region, the erase type chosen is the smallest one that
//     divides the region exactly *and* is aligned to the region's base. An
//     erase type that is merely present is not usable if using it would
//     straddle a boundary.
//   - Regions must tile the chip exactly. A map that covers less than the
//     part, or more, is a map for a different part.
//   - Dedicated 4-byte erase opcodes are used only when SFDP actually
//     declares one for that exact size and 3-byte opcode. Substituting a
//     3-byte opcode above 16 MiB erases at a wrapped address.

{$mode objfpc}{$H+}

interface

uses
  SysUtils, sfdp, norplanner;

// Builds the erase-block list for a chip.
//
// SFDPValid says whether SFDP was read successfully; when it is False the
// tables are ignored entirely and the fallback sector size and opcode are
// used to build a uniform geometry. FallbackEraseSize/Opcode come from the
// chip catalogue and are the answer for parts with no SFDP at all.
//
// Native4BOpcodes asks for dedicated 4-byte erase opcodes, which only exist
// when SFDP declares them; the call fails rather than silently using the
// 3-byte opcode, because above 16 MiB that erases somewhere else entirely.
function BuildNORGeometryFrom(
  ChipSize, PageSize: cardinal;
  Native4BOpcodes: boolean;
  SFDPValid: boolean; const SFDP: TSFDPInfo;
  FallbackEraseSize: cardinal; FallbackEraseOpcode: byte;
  out Geometry: TNORGeometry; out ErrorText: string): boolean;

implementation

function BuildNORGeometryFrom(
  ChipSize, PageSize: cardinal;
  Native4BOpcodes: boolean;
  SFDPValid: boolean; const SFDP: TSFDPInfo;
  FallbackEraseSize: cardinal; FallbackEraseOpcode: byte;
  out Geometry: TNORGeometry; out ErrorText: string): boolean;
var
  RegionIndex, BestType, BlockIndex: integer;
  RegionBase, BlockCount, TotalBlocks, j: QWord;
  BlockSize: cardinal;
  BlockOpcode, StandardOpcode, NativeOpcode: byte;

  //Picks the erase type to use for one region.
  //
  //Smallest wins, but only among types that divide the region exactly and
  //are aligned to where the region starts.  A type that is present in the
  //mask but misaligned would place block boundaries inside the region at
  //offsets the chip does not honour.
  function BestEraseTypeFor(Index: integer; Base: QWord): integer;
  var
    t: integer;
  begin
    Result := 0;
    for t := 1 to 4 do
      if ((SFDP.Regions[Index].EraseTypeMask and (1 shl (t - 1))) <> 0) and
         (SFDP.EraseTypes[t].Size > 0) and
         ((Result = 0) or
          (SFDP.EraseTypes[t].Size < SFDP.EraseTypes[Result].Size)) and
         ((Base mod SFDP.EraseTypes[t].Size) = 0) and
         ((SFDP.Regions[Index].Size mod SFDP.EraseTypes[t].Size) = 0) then
        Result := t;
  end;

  function NativeOpcodeFor(Size: cardinal; Standard: byte;
    out Opcode: byte): boolean;
  var
    t: integer;
  begin
    Opcode := Standard;
    if not Native4BOpcodes then Exit(True);

    Result := False;
    if not SFDPValid then
    begin
      ErrorText := 'dedicated 4-byte erase opcodes require valid SFDP data';
      Exit;
    end;
    for t := 1 to 4 do
      if (SFDP.EraseTypes[t].Size = Size) and
         (SFDP.EraseTypes[t].Opcode = Standard) and
         (SFDP.EraseTypes[t].Opcode4B <> 0) then
      begin
        Opcode := SFDP.EraseTypes[t].Opcode4B;
        Exit(True);
      end;
    //Falling back to the 3-byte opcode here would erase at a wrapped
    //address on anything above 16 MiB.  Refusing is the only safe answer.
    ErrorText := Format(
      'SFDP has no dedicated 4-byte erase opcode for %d-byte opcode %.2x',
      [Size, Standard]);
  end;

begin
  FillChar(Geometry, SizeOf(Geometry), 0);
  Geometry.ErasedValue := $FF;
  ErrorText := '';
  Result := False;

  if (ChipSize = 0) or (PageSize = 0) then
  begin
    ErrorText := 'chip size and page size must be non-zero';
    Exit;
  end;
  if SFDPValid and (SFDP.Density <> 0) and (SFDP.Density <> ChipSize) then
  begin
    //One of these two is wrong about the part in the socket, and there is no
    //basis for preferring either.
    ErrorText := Format(
      'selected chip size %d disagrees with the live SFDP density %d',
      [ChipSize, SFDP.Density]);
    Exit;
  end;
  if SFDPValid and SFDP.SectorMapDeclared and (not SFDP.HasSectorMap) then
  begin
    ErrorText :=
      'the chip declares an SFDP sector map, but its active map is ambiguous or invalid';
    Exit;
  end;

  if SFDPValid and SFDP.HasSectorMap then
  begin
    Geometry.ChipSize := ChipSize;
    Geometry.PageSize := PageSize;
    TotalBlocks := 0;
    RegionBase := 0;

    //First pass selects an erase type that is valid and aligned throughout
    //each region and obtains an exact allocation size.
    for RegionIndex := 0 to SFDP.RegionCount - 1 do
    begin
      BestType := BestEraseTypeFor(RegionIndex, RegionBase);
      if BestType = 0 then
      begin
        ErrorText := Format(
          'SFDP region %d has no erase type aligned to the whole region',
          [RegionIndex]);
        Exit;
      end;
      BlockCount := SFDP.Regions[RegionIndex].Size div
                    SFDP.EraseTypes[BestType].Size;
      if BlockCount > QWord(High(SizeInt)) - TotalBlocks then
      begin
        ErrorText := 'SFDP erase-block count does not fit this build';
        Exit;
      end;
      Inc(TotalBlocks, BlockCount);
      Inc(RegionBase, SFDP.Regions[RegionIndex].Size);
    end;

    if RegionBase <> ChipSize then
    begin
      //A map that does not tile the part exactly is a map for a different
      //part, and using it would erase past the end or leave a tail unerased.
      ErrorText := 'SFDP sector-map regions do not cover the selected chip';
      Exit;
    end;

    SetLength(Geometry.Blocks, SizeInt(TotalBlocks));
    RegionBase := 0;
    BlockIndex := 0;
    for RegionIndex := 0 to SFDP.RegionCount - 1 do
    begin
      BestType := BestEraseTypeFor(RegionIndex, RegionBase);
      BlockSize := SFDP.EraseTypes[BestType].Size;
      StandardOpcode := SFDP.EraseTypes[BestType].Opcode;
      if not NativeOpcodeFor(BlockSize, StandardOpcode, NativeOpcode) then Exit;
      BlockCount := SFDP.Regions[RegionIndex].Size div BlockSize;
      j := 0;
      while j < BlockCount do
      begin
        Geometry.Blocks[BlockIndex].Address :=
          RegionBase + j * QWord(BlockSize);
        Geometry.Blocks[BlockIndex].Size := BlockSize;
        Geometry.Blocks[BlockIndex].Opcode := NativeOpcode;
        Inc(BlockIndex);
        Inc(j);
      end;
      Inc(RegionBase, SFDP.Regions[RegionIndex].Size);
    end;
    Exit(ValidateNORGeometry(Geometry, ErrorText));
  end;

  //No sector map: one block size for the whole part.  SFDP's smallest erase
  //if it told us one, otherwise whatever the catalogue says.
  BlockSize := 0;
  StandardOpcode := 0;
  if SFDPValid then SFDPSmallestErase(SFDP, BlockSize, StandardOpcode);
  if BlockSize = 0 then
  begin
    BlockSize := FallbackEraseSize;
    StandardOpcode := FallbackEraseOpcode;
  end;
  if not NativeOpcodeFor(BlockSize, StandardOpcode, BlockOpcode) then Exit;
  Result := BuildUniformNORGeometry(ChipSize, PageSize, BlockSize,
                                    BlockOpcode, Geometry, ErrorText);
end;

end.
