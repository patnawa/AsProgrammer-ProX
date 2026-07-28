unit nandmodel;

// Geometry, bad-block map and image layout for SPI NAND.
//
// NAND differs from NOR in ways that destroy data if they are treated as
// details:
//
//   - Bad blocks are normal, including on a factory-fresh part.  They are
//     marked in the spare area of the first page of the block and must never
//     be erased or programmed.  A tool that writes them produces an image
//     that reads back wrong with nothing reporting an error.
//   - Every page carries a spare area (typically 64 or 128 bytes on a
//     2048-byte page) holding the bad-block marker and the ECC bytes.  So
//     "the image" is ambiguous: main-only and raw (main+spare) are both
//     legitimate and mean different things.
//   - Erase works on whole blocks; program works on pages; a page may be
//     programmed only once between erases.
//
// This unit is pure arithmetic and bookkeeping: no hardware, no LCL, no
// opcodes.  It is the piece the planner and the tests can reason about.

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

const
  //A factory bad-block marker lives in the first byte of the spare area of
  //the first page of a block.  Any value other than FF means bad.
  NAND_GOOD_MARKER = $FF;
  MAX_NAND_BLOCKS = 65536;

type
  TNANDImageLayout = (
    nilMainOnly,   //the image holds page data only; the chip's ECC owns spare
    nilRaw         //the image holds page+spare exactly as stored
  );

  TNANDGeometry = record
    PageSize: cardinal;      //main area, bytes (2048 typical)
    SpareSize: cardinal;     //spare/OOB per page, bytes (64/128 typical)
    PagesPerBlock: cardinal; //64 typical
    BlockCount: cardinal;
    Layout: TNANDImageLayout;
  end;

  //One entry per block.  Unknown means the map has not been scanned yet and
  //must not be treated as good -- that is the whole point of scanning.
  TNANDBlockState = (nbsUnknown, nbsGood, nbsFactoryBad, nbsRuntimeBad);
  TNANDBlockMap = array of TNANDBlockState;

  //What to do when a requested range covers a bad block.
  TNANDBadBlockPolicy = (
    nbpRefuse,   //fail the whole request: the caller wanted these exact bytes
    nbpSkip      //step over the bad block and carry on at the next good one
  );

function BuildNANDGeometry(PageSize, SpareSize, PagesPerBlock: cardinal;
  BlockCount: cardinal; Layout: TNANDImageLayout;
  out Geometry: TNANDGeometry; out ErrorText: string): boolean;

function ValidateNANDGeometry(const Geometry: TNANDGeometry;
  out ErrorText: string): boolean;

//Bytes the image occupies per page and per block under this layout.
function NANDImagePageStride(const Geometry: TNANDGeometry): cardinal;
function NANDImageBlockStride(const Geometry: TNANDGeometry): QWord;
//Total bytes an image of the whole chip occupies under this layout.
function NANDImageSize(const Geometry: TNANDGeometry): QWord;
//Bytes of real storage in the whole chip, spare excluded.
function NANDMainSize(const Geometry: TNANDGeometry): QWord;

function NewNANDBlockMap(const Geometry: TNANDGeometry): TNANDBlockMap;
function NANDBlockIsUsable(const Map: TNANDBlockMap; Block: cardinal): boolean;
function NANDCountUsable(const Map: TNANDBlockMap): cardinal;
function NANDBlockStateName(S: TNANDBlockState): string;

//Reads the factory marker out of one block's first-page spare area and
//returns the state it implies.  SpareFirstByte is that byte as read.
function NANDMarkerState(SpareFirstByte: byte): TNANDBlockState;

//Which block holds a given main-area (spare-excluded) address.
function NANDBlockOfMainAddress(const Geometry: TNANDGeometry;
  Address: QWord): cardinal;

implementation

function BuildNANDGeometry(PageSize, SpareSize, PagesPerBlock: cardinal;
  BlockCount: cardinal; Layout: TNANDImageLayout;
  out Geometry: TNANDGeometry; out ErrorText: string): boolean;
begin
  Geometry.PageSize := PageSize;
  Geometry.SpareSize := SpareSize;
  Geometry.PagesPerBlock := PagesPerBlock;
  Geometry.BlockCount := BlockCount;
  Geometry.Layout := Layout;
  Result := ValidateNANDGeometry(Geometry, ErrorText);
  if not Result then FillChar(Geometry, SizeOf(Geometry), 0);
end;

function ValidateNANDGeometry(const Geometry: TNANDGeometry;
  out ErrorText: string): boolean;
begin
  Result := False;
  ErrorText := '';

  //Page sizes are powers of two on every SPI NAND in production; refusing
  //anything else keeps the address arithmetic exact.
  if (Geometry.PageSize < 512) or (Geometry.PageSize > 16384) or
     ((Geometry.PageSize and (Geometry.PageSize - 1)) <> 0) then
  begin
    ErrorText := 'page size must be a power of two between 512 and 16384';
    Exit;
  end;
  //The spare area must be big enough to hold the bad-block marker.
  if (Geometry.SpareSize < 16) or (Geometry.SpareSize > Geometry.PageSize) then
  begin
    ErrorText := 'spare area must be 16 bytes or more and no larger than a page';
    Exit;
  end;
  if (Geometry.PagesPerBlock < 2) or (Geometry.PagesPerBlock > 1024) or
     ((Geometry.PagesPerBlock and (Geometry.PagesPerBlock - 1)) <> 0) then
  begin
    ErrorText := 'pages per block must be a power of two between 2 and 1024';
    Exit;
  end;
  if (Geometry.BlockCount = 0) or (Geometry.BlockCount > MAX_NAND_BLOCKS) then
  begin
    ErrorText := Format('block count must be between 1 and %d',
                        [MAX_NAND_BLOCKS]);
    Exit;
  end;
  Result := True;
end;

function NANDImagePageStride(const Geometry: TNANDGeometry): cardinal;
begin
  if Geometry.Layout = nilRaw then
    Result := Geometry.PageSize + Geometry.SpareSize
  else
    Result := Geometry.PageSize;
end;

function NANDImageBlockStride(const Geometry: TNANDGeometry): QWord;
begin
  Result := QWord(NANDImagePageStride(Geometry)) *
            QWord(Geometry.PagesPerBlock);
end;

function NANDImageSize(const Geometry: TNANDGeometry): QWord;
begin
  Result := NANDImageBlockStride(Geometry) * QWord(Geometry.BlockCount);
end;

function NANDMainSize(const Geometry: TNANDGeometry): QWord;
begin
  Result := QWord(Geometry.PageSize) * QWord(Geometry.PagesPerBlock) *
            QWord(Geometry.BlockCount);
end;

function NewNANDBlockMap(const Geometry: TNANDGeometry): TNANDBlockMap;
var
  i: SizeInt;
begin
  Result := nil;
  SetLength(Result, Geometry.BlockCount);
  //Unknown until scanned.  Defaulting to good would silently reintroduce
  //exactly the bug this map exists to prevent.
  for i := 0 to High(Result) do Result[i] := nbsUnknown;
end;

function NANDBlockIsUsable(const Map: TNANDBlockMap;
  Block: cardinal): boolean;
begin
  Result := (Block < cardinal(Length(Map))) and (Map[Block] = nbsGood);
end;

function NANDCountUsable(const Map: TNANDBlockMap): cardinal;
var
  i: SizeInt;
begin
  Result := 0;
  for i := 0 to High(Map) do
    if Map[i] = nbsGood then Inc(Result);
end;

function NANDBlockStateName(S: TNANDBlockState): string;
begin
  case S of
    nbsGood:       Result := 'good';
    nbsFactoryBad: Result := 'factory bad';
    nbsRuntimeBad: Result := 'bad';
  else
    Result := 'unknown';
  end;
end;

function NANDMarkerState(SpareFirstByte: byte): TNANDBlockState;
begin
  if SpareFirstByte = NAND_GOOD_MARKER then
    Result := nbsGood
  else
    Result := nbsFactoryBad;
end;

function NANDBlockOfMainAddress(const Geometry: TNANDGeometry;
  Address: QWord): cardinal;
var
  PerBlock: QWord;
begin
  PerBlock := QWord(Geometry.PageSize) * QWord(Geometry.PagesPerBlock);
  if PerBlock = 0 then Exit(0);
  Result := cardinal(Address div PerBlock);
end;

end.
