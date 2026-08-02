unit nandcatalog;

// The SPI NAND parts this program knows how to drive, keyed by JEDEC ID.
//
// Deliberately a short list. Every entry here has been checked against its
// datasheet for the geometry AND for the assumptions the adapter makes:
// plain 13h/03h/02h/10h/D8h command set, feature registers at A0/B0/C0,
// ECC-E at bit 4 of B0, ECC status at bits 5:4 of C0, and single-plane
// column addressing. A part that violates any of those (multi-plane 2Gb
// parts with a plane-select bit in the column, for instance) must not be
// added without teaching the adapter the difference -- a wrong entry here
// reads and writes the wrong pages while looking perfectly healthy.
//
// SPI NAND answers 9Fh in two shapes: some parts clock out a dummy byte
// before the manufacturer (Winbond, Toshiba/Kioxia), some do not (GigaDevice
// UA generation, Macronix). NANDIdentify therefore tries both alignments of
// the raw reply.
//
// Pure data and matching, no hardware: testable everywhere.

{$mode objfpc}{$H+}

interface

uses
  SysUtils, nandmodel;

type
  TNANDCatalogEntry = record
    Name: string[24];
    Vendor: string[16];
    ID: array[0..2] of byte;
    IDLen: byte;              //2 or 3 significant bytes
    PageSize: cardinal;
    SpareSize: cardinal;
    PagesPerBlock: cardinal;
    BlockCount: cardinal;
  end;

  //The fields from the first CRC-valid 256-byte ONFI parameter-page copy.
  //They remain separate from TNANDGeometry so callers can report an ONFI
  //shape that this adapter deliberately refuses to drive (multi-LUN, MLC,
  //or a different address-cycle count).
  TONFIParameterPage = record
    Revision: word;
    Manufacturer: string;
    Model: string;
    JedecManufacturerID: byte;
    PageSize: cardinal;
    SpareSize: cardinal;
    PagesPerBlock: cardinal;
    BlocksPerLUN: cardinal;
    LUNCount: byte;
    AddressCycles: byte;
    BitsPerCell: byte;
    SelectedCopy: cardinal;
  end;

  //Reading the ONFI page is not one universal SPI NAND command. The known
  //parts expose row 1 while a vendor-specific configuration mode is active.
  //Only catalog families whose documented mode has been checked get a
  //supported record; unknown sequences are never guessed on live hardware.
  TSPINANDParameterPageAccess = record
    Supported: boolean;
    ConfigSetMask: byte;
    ConfigClearMask: byte;
    RowAddress: cardinal;
    CopyCount: byte;
  end;

//Match the raw bytes clocked out after 9Fh (pass at least 4). Tries the
//no-dummy alignment first, then the one-dummy alignment.
function NANDIdentify(const Raw: array of byte;
  out Entry: TNANDCatalogEntry): boolean;

//Geometry for an identified part under the requested image layout.
function NANDCatalogGeometry(const Entry: TNANDCatalogEntry;
  Layout: TNANDImageLayout; out Geometry: TNANDGeometry;
  out ErrorText: string): boolean;

//ONFI CRC16 over Count bytes: polynomial $8005, initial value $4F4E,
//MSB first, no reflection and no final XOR.
function ONFICRC16(const Data: array of byte; Count: SizeInt): word;

//Select and parse the first signature+CRC-valid 256-byte copy. Raw may hold
//one or more consecutive redundant copies as read from the parameter cache.
function ParseONFIParameterPages(const Raw: array of byte;
  out Params: TONFIParameterPage; out ErrorText: string): boolean;

//Convert only the SPI shape the current adapter can address safely.
function ONFIParameterGeometry(const Params: TONFIParameterPage;
  Layout: TNANDImageLayout; out Geometry: TNANDGeometry;
  out ErrorText: string): boolean;

//Catalog-bound conversion for SPI NAND parameter pages whose address-cycle
//field is documented as 00/N/A. That exception is accepted only for an exact
//live-access allowlist entry, matching manufacturer, and matching catalog
//geometry. Generic ONFIParameterGeometry remains strict.
function NANDCatalogONFIGeometry(const Entry: TNANDCatalogEntry;
  const Params: TONFIParameterPage; Layout: TNANDImageLayout;
  out Geometry: TNANDGeometry; out ErrorText: string): boolean;

//Return the checked vendor mode used to read ONFI copies from this catalog
//entry. False means detection must stop rather than trying a likely bit.
function NANDParameterPageAccess(const Entry: TNANDCatalogEntry;
  out Access: TSPINANDParameterPageAccess): boolean;

//One line per known part, for --nand-info to print when nothing matches.
function NANDCatalogList: string;

implementation

const
  Catalog: array[0..6] of TNANDCatalogEntry = (
    (Name: 'W25N512GV';      Vendor: 'Winbond';    ID: ($EF, $AA, $20);
     IDLen: 3; PageSize: 2048; SpareSize: 64;  PagesPerBlock: 64;
     BlockCount: 512),
    (Name: 'W25N01GV';       Vendor: 'Winbond';    ID: ($EF, $AA, $21);
     IDLen: 3; PageSize: 2048; SpareSize: 64;  PagesPerBlock: 64;
     BlockCount: 1024),
    (Name: 'W25N02KV';       Vendor: 'Winbond';    ID: ($EF, $AA, $22);
     IDLen: 3; PageSize: 2048; SpareSize: 128; PagesPerBlock: 64;
     BlockCount: 2048),
    (Name: 'GD5F1GQ4UAYIG';  Vendor: 'GigaDevice'; ID: ($C8, $F1, $00);
     IDLen: 2; PageSize: 2048; SpareSize: 64;  PagesPerBlock: 64;
     BlockCount: 1024),
    (Name: 'GD5F1GQ4UBYIG';  Vendor: 'GigaDevice'; ID: ($C8, $D1, $00);
     IDLen: 2; PageSize: 2048; SpareSize: 128; PagesPerBlock: 64;
     BlockCount: 1024),
    (Name: 'MX35LF1GE4AB';   Vendor: 'Macronix';   ID: ($C2, $12, $00);
     IDLen: 2; PageSize: 2048; SpareSize: 64;  PagesPerBlock: 64;
     BlockCount: 1024),
    (Name: 'TC58CVG0S3HRAIG'; Vendor: 'Kioxia';    ID: ($98, $C2, $00);
     IDLen: 2; PageSize: 2048; SpareSize: 128; PagesPerBlock: 64;
     BlockCount: 1024)
  );

function MatchAt(const Raw: array of byte; Start: integer;
  const E: TNANDCatalogEntry): boolean;
var
  i: integer;
begin
  Result := False;
  if Start + E.IDLen > Length(Raw) then Exit;
  for i := 0 to E.IDLen - 1 do
    if Raw[Start + i] <> E.ID[i] then Exit;
  Result := True;
end;

function NANDCatalogONFIGeometry(const Entry: TNANDCatalogEntry;
  const Params: TONFIParameterPage; Layout: TNANDImageLayout;
  out Geometry: TNANDGeometry; out ErrorText: string): boolean;
var
  Adjusted: TONFIParameterPage;
  CatalogGeometry: TNANDGeometry;
  Access: TSPINANDParameterPageAccess;
begin
  FillChar(Geometry, SizeOf(Geometry), 0);
  Result := False;
  ErrorText := '';
  if Params.JedecManufacturerID <> Entry.ID[0] then
  begin
    ErrorText := Format(
      'ONFI manufacturer %.2x does not match catalog manufacturer %.2x',
      [Params.JedecManufacturerID, Entry.ID[0]]);
    Exit;
  end;

  Adjusted := Params;
  if Params.AddressCycles = $00 then
  begin
    if not NANDParameterPageAccess(Entry, Access) then
    begin
      ErrorText := 'ONFI address cycles are N/A, but this exact catalog ' +
                   'entry has no verified live parameter-page sequence';
      Exit;
    end;
    //SPI NAND uses the adapter's fixed 2-column/3-row framing; 00 in these
    //exact vendor tables means N/A, not a zero-cycle address. Feed the strict
    //converter the framing already established by the allowlisted adapter.
    Adjusted.AddressCycles := $23;
  end;
  if not ONFIParameterGeometry(Adjusted, Layout, Geometry, ErrorText) then
    Exit;
  if not NANDCatalogGeometry(Entry, Layout, CatalogGeometry, ErrorText) then
  begin
    FillChar(Geometry, SizeOf(Geometry), 0);
    Exit;
  end;
  if (Geometry.PageSize <> CatalogGeometry.PageSize) or
     (Geometry.SpareSize <> CatalogGeometry.SpareSize) or
     (Geometry.PagesPerBlock <> CatalogGeometry.PagesPerBlock) or
     (Geometry.BlockCount <> CatalogGeometry.BlockCount) then
  begin
    ErrorText := Format(
      'ONFI geometry %d x %d x (%d+%d) does not match catalog geometry ' +
      '%d x %d x (%d+%d)',
      [Geometry.BlockCount, Geometry.PagesPerBlock, Geometry.PageSize,
       Geometry.SpareSize, CatalogGeometry.BlockCount,
       CatalogGeometry.PagesPerBlock, CatalogGeometry.PageSize,
       CatalogGeometry.SpareSize]);
    FillChar(Geometry, SizeOf(Geometry), 0);
    Exit;
  end;
  Result := True;
end;

function NANDIdentify(const Raw: array of byte;
  out Entry: TNANDCatalogEntry): boolean;
var
  i: integer;
begin
  Result := False;
  FillChar(Entry, SizeOf(Entry), 0);
  if Length(Raw) < 2 then Exit;

  //บัสเงียบตอบ FF/00 ล้วน อย่าไปเทียบต่อให้เปลืองความหวัง
  if ((Raw[0] = $FF) and (Raw[1] = $FF)) or
     ((Raw[0] = $00) and (Raw[1] = $00)) then Exit;

  for i := Low(Catalog) to High(Catalog) do
    if MatchAt(Raw, 0, Catalog[i]) then
    begin
      Entry := Catalog[i];
      Exit(True);
    end;
  //ตระกูลที่คายไบต์ dummy มาก่อน (Winbond, Kioxia): เริ่มเทียบที่ไบต์สอง
  for i := Low(Catalog) to High(Catalog) do
    if MatchAt(Raw, 1, Catalog[i]) then
    begin
      Entry := Catalog[i];
      Exit(True);
    end;
end;

function NANDCatalogGeometry(const Entry: TNANDCatalogEntry;
  Layout: TNANDImageLayout; out Geometry: TNANDGeometry;
  out ErrorText: string): boolean;
begin
  Result := BuildNANDGeometry(Entry.PageSize, Entry.SpareSize,
    Entry.PagesPerBlock, Entry.BlockCount, Layout, Geometry, ErrorText);
end;

function ONFICRC16At(const Data: array of byte; Start, Count: SizeInt): word;
var
  i, BitIndex: SizeInt;
begin
  Result := $4F4E;
  if (Start < 0) or (Count < 0) or
     (Start > Length(Data)) or (Count > Length(Data) - Start) then Exit(0);
  for i := Start to Start + Count - 1 do
  begin
    Result := Result xor (word(Data[i]) shl 8);
    for BitIndex := 0 to 7 do
      if (Result and $8000) <> 0 then
        Result := word((Result shl 1) xor $8005)
      else
        Result := word(Result shl 1);
  end;
end;

function ONFICRC16(const Data: array of byte; Count: SizeInt): word;
begin
  Result := ONFICRC16At(Data, 0, Count);
end;

function ReadLE16(const Data: array of byte; Offset: SizeInt): word;
begin
  Result := word(Data[Offset]) or (word(Data[Offset + 1]) shl 8);
end;

function ReadLE32(const Data: array of byte; Offset: SizeInt): cardinal;
begin
  Result := cardinal(Data[Offset]) or
            (cardinal(Data[Offset + 1]) shl 8) or
            (cardinal(Data[Offset + 2]) shl 16) or
            (cardinal(Data[Offset + 3]) shl 24);
end;

function ONFIText(const Data: array of byte; Offset, Count: SizeInt): string;
var
  i: SizeInt;
begin
  Result := '';
  SetLength(Result, Count);
  for i := 0 to Count - 1 do Result[i + 1] := char(Data[Offset + i]);
  while (Length(Result) > 0) and
        ((Result[Length(Result)] = ' ') or
         (Result[Length(Result)] = #0) or
         (byte(Result[Length(Result)]) = $FF)) do
    Delete(Result, Length(Result), 1);
end;

function ParseONFIParameterPages(const Raw: array of byte;
  out Params: TONFIParameterPage; out ErrorText: string): boolean;
const
  ONFI_PAGE_BYTES = 256;
  ONFI_CRC_OFFSET = 254;
var
  CopyIndex, CopyCount: SizeInt;
  Base: SizeInt;
  StoredCRC, CalculatedCRC: word;
begin
  Params := Default(TONFIParameterPage);
  ErrorText := '';
  Result := False;
  CopyCount := Length(Raw) div ONFI_PAGE_BYTES;
  if CopyCount = 0 then
  begin
    ErrorText := 'the ONFI parameter data contains no complete 256-byte copy';
    Exit;
  end;

  for CopyIndex := 0 to CopyCount - 1 do
  begin
    Base := CopyIndex * ONFI_PAGE_BYTES;
    if (Raw[Base] <> Ord('O')) or (Raw[Base + 1] <> Ord('N')) or
       (Raw[Base + 2] <> Ord('F')) or (Raw[Base + 3] <> Ord('I')) then
      Continue;
    StoredCRC := ReadLE16(Raw, Base + ONFI_CRC_OFFSET);
    CalculatedCRC := ONFICRC16At(Raw, Base, ONFI_CRC_OFFSET);
    if StoredCRC <> CalculatedCRC then Continue;

    Params.Revision := ReadLE16(Raw, Base + 4);
    Params.Manufacturer := ONFIText(Raw, Base + 32, 12);
    Params.Model := ONFIText(Raw, Base + 44, 20);
    Params.JedecManufacturerID := Raw[Base + 64];
    Params.PageSize := ReadLE32(Raw, Base + 80);
    Params.SpareSize := ReadLE16(Raw, Base + 84);
    Params.PagesPerBlock := ReadLE32(Raw, Base + 92);
    Params.BlocksPerLUN := ReadLE32(Raw, Base + 96);
    Params.LUNCount := Raw[Base + 100];
    Params.AddressCycles := Raw[Base + 101];
    Params.BitsPerCell := Raw[Base + 102];
    Params.SelectedCopy := CopyIndex;
    Exit(True);
  end;

  ErrorText := Format(
    'none of the %d complete ONFI parameter-page copies has both the ONFI ' +
    'signature and a valid CRC16', [CopyCount]);
end;

function ONFIParameterGeometry(const Params: TONFIParameterPage;
  Layout: TNANDImageLayout; out Geometry: TNANDGeometry;
  out ErrorText: string): boolean;
var
  BlockCount64: QWord;
begin
  FillChar(Geometry, SizeOf(Geometry), 0);
  Result := False;
  ErrorText := '';
  if Params.LUNCount <> 1 then
  begin
    ErrorText := Format(
      'the ONFI device has %d LUNs; this SPI NAND adapter supports one',
      [Params.LUNCount]);
    Exit;
  end;
  if Params.BitsPerCell <> 1 then
  begin
    ErrorText := Format(
      'the ONFI device stores %d bits per cell; only SLC is supported',
      [Params.BitsPerCell]);
    Exit;
  end;
  //ONFI byte 101 stores column cycles in the high nibble and row cycles in
  //the low nibble. The adapter frames exactly two plus three respectively.
  if Params.AddressCycles <> $23 then
  begin
    ErrorText := Format(
      'the ONFI address-cycle byte is %.2x; this adapter requires 2 column ' +
      'and 3 row cycles (23)', [Params.AddressCycles]);
    Exit;
  end;
  BlockCount64 := QWord(Params.BlocksPerLUN) * QWord(Params.LUNCount);
  if BlockCount64 > High(cardinal) then
  begin
    ErrorText := 'the ONFI block count does not fit the adapter';
    Exit;
  end;
  Result := BuildNANDGeometry(Params.PageSize, Params.SpareSize,
    Params.PagesPerBlock, cardinal(BlockCount64), Layout, Geometry, ErrorText);
end;

function NANDParameterPageAccess(const Entry: TNANDCatalogEntry;
  out Access: TSPINANDParameterPageAccess): boolean;
begin
  FillChar(Access, SizeOf(Access), 0);
  Access.RowAddress := 1;
  Access.CopyCount := 3;
  if (Entry.ID[0] = $EF) and (Entry.ID[1] = $AA) and
     (Entry.ID[2] = $21) then
  begin
    Access.ConfigSetMask := $48; //W25N01GV OTP-E + buffer-read mode
    Access.ConfigClearMask := $10; //on-die ECC off
  end
  else if (Entry.ID[0] = $C2) and (Entry.ID[1] = $12) then
  begin
    Access.ConfigSetMask := $40;
    //MX35LF1GE4AB documents B0h=40h for parameter-page access, not merely
    //bit 6 set. Clear every other bit, then restore the original byte.
    Access.ConfigClearMask := $BF;
  end
  else
    Exit(False);
  Access.Supported := True;
  Result := True;
end;

function NANDCatalogList: string;
var
  i: integer;
  E: TNANDCatalogEntry;
  IDText: string;
  j: integer;
begin
  Result := '';
  for i := Low(Catalog) to High(Catalog) do
  begin
    E := Catalog[i];
    IDText := '';
    for j := 0 to E.IDLen - 1 do IDText := IDText + IntToHex(E.ID[j], 2);
    if Result <> '' then Result := Result + LineEnding;
    Result := Result + Format(
      '  %-17s %-11s id %-6s  %d blocks x %d pages x (%d+%d) bytes',
      [string(E.Name), string(E.Vendor), IDText, E.BlockCount,
       E.PagesPerBlock, E.PageSize, E.SpareSize]);
  end;
end;

end.
