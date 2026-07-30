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

//Match the raw bytes clocked out after 9Fh (pass at least 4). Tries the
//no-dummy alignment first, then the one-dummy alignment.
function NANDIdentify(const Raw: array of byte;
  out Entry: TNANDCatalogEntry): boolean;

//Geometry for an identified part under the requested image layout.
function NANDCatalogGeometry(const Entry: TNANDCatalogEntry;
  Layout: TNANDImageLayout; out Geometry: TNANDGeometry;
  out ErrorText: string): boolean;

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
