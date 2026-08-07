program norgeometrybuild_tests;

// The arithmetic that decides which blocks an erase is allowed to touch.
//
// This could not be tested at all until it was lifted out of main.pas, which
// is the reason it was lifted. A wrong block list does not fail loudly: it
// erases data that was never part of the job and reports success. On a boot
// block part, where 4 KB sectors sit beside 64 KB blocks, a wrong region
// boundary wipes the bootloader.

{$mode objfpc}{$H+}

uses
  SysUtils, sfdp, norplanner, norgeometrybuild;

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

procedure CheckFails(const Name: string; Built: boolean;
  const ErrorText, Needle: string);
begin
  Inc(Assertions);
  if Built then
  begin
    Inc(Failures);
    WriteLn('FAIL: ', Name, ' (it was accepted)');
  end
  else if Pos(Needle, ErrorText) = 0 then
  begin
    Inc(Failures);
    WriteLn('FAIL: ', Name, ' (expected "', Needle, '", got "',
            ErrorText, '")');
  end;
end;

// --- fixtures ------------------------------------------------------------

procedure ClearSFDP(out S: TSFDPInfo);
begin
  FillChar(S, SizeOf(S), 0);
end;

// A plain part: one erase size across the whole array.
procedure UniformSFDP(out S: TSFDPInfo; Density: QWord;
  EraseSize: cardinal; Opcode: byte);
begin
  ClearSFDP(S);
  S.Valid := True;
  S.Density := Density;
  S.EraseTypes[1].Size := EraseSize;
  S.EraseTypes[1].Opcode := Opcode;
end;

// A boot-block part: 64 KB of 4 KB sectors at the bottom, 64 KB blocks above.
// This is the layout that punishes a wrong boundary.
procedure BootBlockSFDP(out S: TSFDPInfo; Density: QWord);
begin
  ClearSFDP(S);
  S.Valid := True;
  S.Density := Density;
  S.HasSectorMap := True;
  S.SectorMapDeclared := True;

  S.EraseTypes[1].Size := 4096;
  S.EraseTypes[1].Opcode := $20;
  S.EraseTypes[2].Size := 65536;
  S.EraseTypes[2].Opcode := $D8;

  S.RegionCount := 2;
  S.Regions[0].Size := 65536;
  S.Regions[0].EraseTypeMask := 1;              // 4 KB only
  S.Regions[1].Size := Density - 65536;
  //64 KB only, which is how real boot-block parts describe the upper
  //region. Offering both here would be a different layout, and the
  //"smallest aligned type wins" rule would correctly pick 4 KB -- which
  //TestSmallestAlignedEraseTypeWins checks separately.
  S.Regions[1].EraseTypeMask := 2;
end;

function TotalCovered(const G: TNORGeometry): QWord;
var
  i: integer;
begin
  Result := 0;
  for i := 0 to High(G.Blocks) do Inc(Result, G.Blocks[i].Size);
end;

function BlocksAreContiguous(const G: TNORGeometry): boolean;
var
  i: integer;
  Next: QWord;
begin
  Next := 0;
  for i := 0 to High(G.Blocks) do
  begin
    if G.Blocks[i].Address <> Next then Exit(False);
    Inc(Next, G.Blocks[i].Size);
  end;
  Result := True;
end;

// --- no SFDP at all ------------------------------------------------------

procedure TestFallbackWithoutSFDP;
var
  S: TSFDPInfo;
  G: TNORGeometry;
  E: string;
begin
  //Older parts have no SFDP. The catalogue's sector size is the answer, and
  //it must produce a complete uniform map.
  ClearSFDP(S);
  Check('a chip with no SFDP uses the catalogue sector size',
    BuildNORGeometryFrom(1048576, 256, False, False, S, 4096, $20, G, E));
  Check('and covers the whole chip', TotalCovered(G) = 1048576);
  Check('with 256 blocks of 4 KB', Length(G.Blocks) = 256);
  Check('contiguous from zero', BlocksAreContiguous(G));
  Check('carrying the catalogue opcode', G.Blocks[0].Opcode = $20);
  Check('and the erased value is FF', G.ErasedValue = $FF);
end;

procedure TestDegenerateInputs;
var
  S: TSFDPInfo;
  G: TNORGeometry;
  E: string;
begin
  ClearSFDP(S);
  CheckFails('a zero chip size is refused',
    BuildNORGeometryFrom(0, 256, False, False, S, 4096, $20, G, E),
    E, 'non-zero');
  CheckFails('a zero page size is refused',
    BuildNORGeometryFrom(1048576, 0, False, False, S, 4096, $20, G, E),
    E, 'non-zero');
end;

// --- SFDP disagreements --------------------------------------------------

procedure TestDensityMismatchIsRefused;
var
  S: TSFDPInfo;
  G: TNORGeometry;
  E: string;
begin
  //The chip says 8 MiB, the operator selected 16 MiB. One of them is wrong
  //about the part in the socket and there is no basis for preferring either,
  //so neither is used.
  UniformSFDP(S, 8388608, 4096, $20);
  CheckFails('an SFDP density that disagrees with the selection is refused',
    BuildNORGeometryFrom(16777216, 256, False, True, S, 4096, $20, G, E),
    E, 'disagrees with the live SFDP density');

  //A density of zero means SFDP did not state one, which is not a conflict.
  UniformSFDP(S, 0, 4096, $20);
  Check('an unstated density is not treated as a conflict',
    BuildNORGeometryFrom(1048576, 256, False, True, S, 4096, $20, G, E));
end;

procedure TestAmbiguousSectorMapIsRefused;
var
  S: TSFDPInfo;
  G: TNORGeometry;
  E: string;
begin
  //A chip that declares a sector map and then produces an unusable one is
  //not a chip to guess about. Falling back to a uniform map here is exactly
  //how a hybrid part gets erased across a region boundary.
  UniformSFDP(S, 1048576, 4096, $20);
  S.SectorMapDeclared := True;
  S.HasSectorMap := False;
  CheckFails('a declared but unresolved sector map is refused',
    BuildNORGeometryFrom(1048576, 256, False, True, S, 4096, $20, G, E),
    E, 'ambiguous or invalid');
end;

// --- boot block layouts --------------------------------------------------

procedure TestBootBlockRegions;
var
  S: TSFDPInfo;
  G: TNORGeometry;
  E: string;
  i, Small, Large: integer;
begin
  //1 MiB part: 64 KB of 4 KB sectors, then 960 KB of 64 KB blocks.
  BootBlockSFDP(S, 1048576);
  Check('a boot block part builds',
    BuildNORGeometryFrom(1048576, 256, False, True, S, 4096, $20, G, E));
  Check('the map covers the whole chip exactly',
    TotalCovered(G) = 1048576);
  Check('and tiles it without gaps or overlaps', BlocksAreContiguous(G));

  Small := 0;
  Large := 0;
  for i := 0 to High(G.Blocks) do
    if G.Blocks[i].Size = 4096 then Inc(Small)
    else if G.Blocks[i].Size = 65536 then Inc(Large);
  //16 sectors of 4 KB in the first 64 KB, 15 blocks of 64 KB above it.
  Check('the bottom region uses 4 KB sectors', Small = 16);
  Check('the top region uses 64 KB blocks', Large = 15);
  Check('every block is accounted for', Small + Large = Length(G.Blocks));

  //The boundary is the assertion that matters: the last small block must end
  //exactly where the first large one begins.
  Check('the region boundary lands at 64 KB',
    (G.Blocks[15].Address + G.Blocks[15].Size = 65536) and
    (G.Blocks[16].Address = 65536));
  Check('the small blocks carry the 4 KB opcode', G.Blocks[0].Opcode = $20);
  Check('the large blocks carry the 64 KB opcode', G.Blocks[16].Opcode = $D8);
end;

procedure TestSmallestAlignedEraseTypeWins;
var
  S: TSFDPInfo;
  G: TNORGeometry;
  E: string;
begin
  //When both types are offered for a region and the smaller one divides it
  //exactly, the smaller one must be chosen: erasing 64 KB where 4 KB would
  //do destroys 60 KB of neighbours that were never part of the job.
  BootBlockSFDP(S, 1048576);
  S.Regions[1].EraseTypeMask := 1 or 2;
  Check('a region offering both sizes builds',
    BuildNORGeometryFrom(1048576, 256, False, True, S, 4096, $20, G, E));
  //960 KB of 4 KB sectors = 240, plus 16 below = 256 blocks total.
  Check('the smaller aligned erase type is preferred',
    Length(G.Blocks) = 256);
end;

procedure TestMisalignedEraseTypeIsNotUsed;
var
  S: TSFDPInfo;
  G: TNORGeometry;
  E: string;
begin
  //An erase type that is present in the mask but does not divide the region
  //cannot be used, even though it is smaller. Using it would place block
  //boundaries at offsets the chip does not honour.
  ClearSFDP(S);
  S.Valid := True;
  S.Density := 98304;                  // 96 KB
  S.HasSectorMap := True;
  S.SectorMapDeclared := True;
  S.EraseTypes[1].Size := 65536;
  S.EraseTypes[1].Opcode := $D8;
  S.RegionCount := 1;
  S.Regions[0].Size := 98304;          // 96 KB is not a multiple of 64 KB
  S.Regions[0].EraseTypeMask := 1;
  CheckFails('an erase type that does not divide its region is refused',
    BuildNORGeometryFrom(98304, 256, False, True, S, 4096, $20, G, E),
    E, 'no erase type aligned to the whole region');
end;

procedure TestRegionsMustTileTheChip;
var
  S: TSFDPInfo;
  G: TNORGeometry;
  E: string;
begin
  //A map that covers less than the part would leave a tail unerased; one
  //that covers more would erase past the end. Both are maps for a different
  //part, and neither is repairable by guessing.
  BootBlockSFDP(S, 1048576);
  S.Regions[1].Size := S.Regions[1].Size - 65536;
  CheckFails('a map that under-covers the chip is refused',
    BuildNORGeometryFrom(1048576, 256, False, True, S, 4096, $20, G, E),
    E, 'do not cover the selected chip');

  BootBlockSFDP(S, 1048576);
  S.Regions[1].Size := S.Regions[1].Size + 65536;
  CheckFails('a map that over-covers the chip is refused',
    BuildNORGeometryFrom(1048576, 256, False, True, S, 4096, $20, G, E),
    E, 'do not cover the selected chip');
end;

// --- four-byte addressing ------------------------------------------------

procedure TestNativeFourByteOpcodes;
var
  S: TSFDPInfo;
  G: TNORGeometry;
  E: string;
begin
  //Above 16 MiB a 3-byte erase opcode erases at a wrapped address. If SFDP
  //does not declare a dedicated 4-byte opcode, refusing is the only safe
  //answer -- substituting the 3-byte one destroys the wrong sector.
  UniformSFDP(S, 33554432, 4096, $20);
  CheckFails('4-byte opcodes are refused when SFDP declares none',
    BuildNORGeometryFrom(33554432, 256, True, True, S, 4096, $20, G, E),
    E, 'no dedicated 4-byte erase opcode');

  CheckFails('and refused outright when SFDP is not valid at all',
    BuildNORGeometryFrom(33554432, 256, True, False, S, 4096, $20, G, E),
    E, 'require valid SFDP data');

  //With one declared, it is used in place of the 3-byte opcode.
  UniformSFDP(S, 33554432, 4096, $20);
  S.EraseTypes[1].Opcode4B := $21;
  Check('a declared 4-byte opcode builds',
    BuildNORGeometryFrom(33554432, 256, True, True, S, 4096, $20, G, E));
  Check('and is the opcode carried by every block',
    (Length(G.Blocks) > 0) and (G.Blocks[0].Opcode = $21));

  //Not asking for them leaves the 3-byte opcode in place.
  Check('without the request the 3-byte opcode stays',
    BuildNORGeometryFrom(33554432, 256, False, True, S, 4096, $20, G, E) and
    (G.Blocks[0].Opcode = $20));
end;

procedure TestFourByteOpcodesAcrossRegions;
var
  S: TSFDPInfo;
  G: TNORGeometry;
  E: string;
begin
  //A hybrid part needs a 4-byte opcode for *every* size it uses. One
  //missing means the whole build fails rather than half the chip getting
  //the wrong opcode.
  BootBlockSFDP(S, 33554432);
  S.EraseTypes[1].Opcode4B := $21;
  CheckFails('a missing 4-byte opcode for one region fails the build',
    BuildNORGeometryFrom(33554432, 256, True, True, S, 4096, $20, G, E),
    E, 'no dedicated 4-byte erase opcode');

  S.EraseTypes[2].Opcode4B := $DC;
  Check('with both declared it builds',
    BuildNORGeometryFrom(33554432, 256, True, True, S, 4096, $20, G, E));
  Check('the small region uses its own 4-byte opcode',
    G.Blocks[0].Opcode = $21);
  Check('and the large region uses its own',
    G.Blocks[16].Opcode = $DC);
end;

begin
  TestFallbackWithoutSFDP;
  TestDegenerateInputs;
  TestDensityMismatchIsRefused;
  TestAmbiguousSectorMapIsRefused;
  TestBootBlockRegions;
  TestSmallestAlignedEraseTypeWins;
  TestMisalignedEraseTypeIsNotUsed;
  TestRegionsMustTileTheChip;
  TestNativeFourByteOpcodes;
  TestFourByteOpcodesAcrossRegions;
  WriteLn(Assertions, ' assertions, ', Failures, ' failures');
  if Failures <> 0 then Halt(1);
  WriteLn('ALL PASSED');
end.
