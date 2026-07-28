unit chipprofile;

// Canonical, LCL-free SPI NOR chip definitions for production-job hashing.
//
// A display label or an in-memory record must never be hashed directly:
// compiler layout, code pages and line endings are not stable interfaces.
// This unit instead emits a small, versioned ASCII document with a fixed field
// order and LF endings.  ParseSPINORChipProfile accepts only that exact byte
// representation, so every station hashes the same definition.

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

const
  SPI_NOR_PROFILE_FORMAT = 'AsProgrammer-ProX/spi-nor-profile';
  SPI_NOR_PROFILE_VERSION = 1;
  MAX_SPI_NOR_PROFILE_BYTES = 2048;

type
  TSPINORChipProfile = record
    Version: cardinal;
    Name: string;
    JedecID: string;       // Exact response, uppercase hexadecimal.
    CapacityBytes: QWord;
    PageSize: cardinal;
    EraseSize: cardinal;   // Uniform erase unit represented by EraseOpcode.
    EraseOpcode: byte;
    VccMinMv: cardinal;
    VccMaxMv: cardinal;
  end;

procedure ClearSPINORChipProfile(out Profile: TSPINORChipProfile);

function ValidateSPINORChipProfile(const Profile: TSPINORChipProfile;
  out ErrMsg: string): boolean;

// Returns no bytes on validation failure.
function TryCanonicalSPINORChipProfileBytes(
  const Profile: TSPINORChipProfile; out Data: TBytes;
  out ErrMsg: string): boolean;

// Convenience for callers that already treat an invalid local definition as a
// programming error.  Raises EArgumentException instead of returning bytes for
// an invalid profile.
function CanonicalSPINORChipProfileBytes(
  const Profile: TSPINORChipProfile): TBytes;

// Strict parser for tooling and fixtures.  It rejects reordered/unknown fields,
// CRLF, non-ASCII bytes, non-minimal decimal values and non-canonical hex.
function ParseSPINORChipProfile(const Data: TBytes;
  out Profile: TSPINORChipProfile; out ErrMsg: string): boolean;

implementation

const
  PROFILE_FIELD_COUNT = 10;
  PROFILE_KEYS: array[0..PROFILE_FIELD_COUNT - 1] of string = (
    'format',
    'version',
    'name',
    'jedec_id',
    'capacity_bytes',
    'page_size',
    'erase_size',
    'erase_opcode',
    'vcc_min_mv',
    'vcc_max_mv'
  );
  MAX_SPI_NOR_CAPACITY_BYTES = QWord(1) shl 48;

type
  TStringArray = array of string;

procedure ClearSPINORChipProfile(out Profile: TSPINORChipProfile);
begin
  Profile.Version := 0;
  Profile.Name := '';
  Profile.JedecID := '';
  Profile.CapacityBytes := 0;
  Profile.PageSize := 0;
  Profile.EraseSize := 0;
  Profile.EraseOpcode := 0;
  Profile.VccMinMv := 0;
  Profile.VccMaxMv := 0;
end;

function UIntText(Value: QWord): string;
var
  Buffer: array[0..31] of char;
  At: integer;
begin
  if Value = 0 then Exit('0');
  At := High(Buffer) + 1;
  while Value > 0 do
  begin
    Dec(At);
    Buffer[At] := Chr(Ord('0') + (Value mod 10));
    Value := Value div 10;
  end;
  SetString(Result, PChar(@Buffer[At]), High(Buffer) - At + 1);
end;

function ByteHex(Value: byte): string;
const
  DIGITS: array[0..15] of char = '0123456789ABCDEF';
begin
  SetLength(Result, 2);
  Result[1] := DIGITS[Value shr 4];
  Result[2] := DIGITS[Value and $0F];
end;

function RawStringBytes(const Value: RawByteString): TBytes;
begin
  Result := nil;
  SetLength(Result, Length(Value));
  if Length(Value) > 0 then Move(Value[1], Result[0], Length(Value));
end;

function SameBytes(const A, B: TBytes): boolean;
var
  i: integer;
begin
  if Length(A) <> Length(B) then Exit(False);
  for i := 0 to High(A) do
    if A[i] <> B[i] then Exit(False);
  Result := True;
end;

function IsPowerOfTwo(Value: QWord): boolean;
begin
  Result := (Value <> 0) and ((Value and (Value - 1)) = 0);
end;

function ValidName(const Value: string): boolean;
var
  i: integer;
begin
  Result := False;
  if (Length(Value) < 1) or (Length(Value) > 96) then Exit;
  for i := 1 to Length(Value) do
    if not (Value[i] in
      ['A'..'Z', 'a'..'z', '0'..'9', '.', '_', '-', '+']) then Exit;
  Result := True;
end;

function ValidJedecID(const Value: string): boolean;
var
  i: integer;
  AllZero, AllFF: boolean;
begin
  Result := False;
  // A production SPI NOR profile requires at least the standard three-byte
  // manufacturer/type/capacity response.  Extension bytes remain supported.
  if ((Length(Value) and 1) <> 0) or
     (Length(Value) < 6) or (Length(Value) > 32) then Exit;
  AllZero := True;
  AllFF := True;
  for i := 1 to Length(Value) do
  begin
    if not (Value[i] in ['0'..'9', 'A'..'F']) then Exit;
    if Value[i] <> '0' then AllZero := False;
    if Value[i] <> 'F' then AllFF := False;
  end;
  if AllZero or AllFF then Exit;
  Result := True;
end;

function ValidateSPINORChipProfile(const Profile: TSPINORChipProfile;
  out ErrMsg: string): boolean;
begin
  Result := False;
  ErrMsg := '';
  if Profile.Version <> SPI_NOR_PROFILE_VERSION then
  begin
    ErrMsg := 'unsupported SPI NOR profile version';
    Exit;
  end;
  if not ValidName(Profile.Name) then
  begin
    ErrMsg := 'chip name must be 1..96 portable ASCII identifier characters';
    Exit;
  end;
  if not ValidJedecID(Profile.JedecID) then
  begin
    ErrMsg := 'JEDEC ID must be 3..16 bytes of uppercase hex and not all 00/FF';
    Exit;
  end;
  if (Profile.CapacityBytes = 0) or
     (Profile.CapacityBytes > MAX_SPI_NOR_CAPACITY_BYTES) then
  begin
    ErrMsg := 'capacity must be within 1..2^48 bytes';
    Exit;
  end;
  if (Profile.PageSize = 0) or (Profile.PageSize > 65536) or
     (not IsPowerOfTwo(Profile.PageSize)) then
  begin
    ErrMsg := 'page size must be a power of two within 1..65536 bytes';
    Exit;
  end;
  if (Profile.EraseSize < 256) or
     (not IsPowerOfTwo(Profile.EraseSize)) then
  begin
    ErrMsg := 'erase size must be a power of two of at least 256 bytes';
    Exit;
  end;
  if Profile.PageSize > Profile.EraseSize then
  begin
    ErrMsg := 'page size must not exceed erase size';
    Exit;
  end;
  if (Profile.EraseSize mod Profile.PageSize) <> 0 then
  begin
    ErrMsg := 'erase size must contain a whole number of pages';
    Exit;
  end;
  if Profile.CapacityBytes < Profile.EraseSize then
  begin
    ErrMsg := 'capacity must be at least one erase unit';
    Exit;
  end;
  if (Profile.CapacityBytes mod Profile.EraseSize) <> 0 then
  begin
    ErrMsg := 'capacity must contain a whole number of erase units';
    Exit;
  end;
  if (Profile.EraseOpcode = $00) or (Profile.EraseOpcode = $FF) then
  begin
    ErrMsg := 'erase opcode 00/FF is invalid or ambiguous';
    Exit;
  end;
  if (Profile.VccMinMv < 500) or (Profile.VccMaxMv > 6000) or
     (Profile.VccMinMv > Profile.VccMaxMv) then
  begin
    ErrMsg := 'VCC range must be ordered and within 500..6000 mV';
    Exit;
  end;
  Result := True;
end;

function UncheckedCanonicalBytes(const Profile: TSPINORChipProfile): TBytes;
var
  Text: RawByteString;
begin
  Text :=
    'format=' + SPI_NOR_PROFILE_FORMAT + #10 +
    'version=' + UIntText(Profile.Version) + #10 +
    'name=' + Profile.Name + #10 +
    'jedec_id=' + Profile.JedecID + #10 +
    'capacity_bytes=' + UIntText(Profile.CapacityBytes) + #10 +
    'page_size=' + UIntText(Profile.PageSize) + #10 +
    'erase_size=' + UIntText(Profile.EraseSize) + #10 +
    'erase_opcode=' + ByteHex(Profile.EraseOpcode) + #10 +
    'vcc_min_mv=' + UIntText(Profile.VccMinMv) + #10 +
    'vcc_max_mv=' + UIntText(Profile.VccMaxMv) + #10;
  Result := RawStringBytes(Text);
end;

function TryCanonicalSPINORChipProfileBytes(
  const Profile: TSPINORChipProfile; out Data: TBytes;
  out ErrMsg: string): boolean;
begin
  Data := nil;
  Result := ValidateSPINORChipProfile(Profile, ErrMsg);
  if Result then Data := UncheckedCanonicalBytes(Profile);
end;

function CanonicalSPINORChipProfileBytes(
  const Profile: TSPINORChipProfile): TBytes;
var
  ErrMsg: string;
begin
  if not TryCanonicalSPINORChipProfileBytes(Profile, Result, ErrMsg) then
    raise EArgumentException.Create('invalid SPI NOR chip profile: ' + ErrMsg);
end;

function StrictQWord(const Value: string; out Number: QWord): boolean;
var
  i: integer;
  Digit: byte;
begin
  Result := False;
  Number := 0;
  if Value = '' then Exit;
  if (Length(Value) > 1) and (Value[1] = '0') then Exit;
  for i := 1 to Length(Value) do
  begin
    if not (Value[i] in ['0'..'9']) then Exit;
    Digit := Ord(Value[i]) - Ord('0');
    if Number > (High(QWord) - Digit) div 10 then
    begin
      Number := 0;
      Exit;
    end;
    Number := (Number * 10) + Digit;
  end;
  Result := True;
end;

function StrictCardinal(const Value: string; out Number: cardinal): boolean;
var
  Parsed: QWord;
begin
  Number := 0;
  Result := StrictQWord(Value, Parsed) and (Parsed <= High(cardinal));
  if Result then Number := cardinal(Parsed);
end;

function StrictByteHex(const Value: string; out Number: byte): boolean;
var
  i, Nibble: integer;
begin
  Result := False;
  Number := 0;
  if Length(Value) <> 2 then Exit;
  for i := 1 to 2 do
  begin
    if Value[i] in ['0'..'9'] then
      Nibble := Ord(Value[i]) - Ord('0')
    else if Value[i] in ['A'..'F'] then
      Nibble := Ord(Value[i]) - Ord('A') + 10
    else
      Exit;
    Number := (Number shl 4) or byte(Nibble);
  end;
  Result := True;
end;

function ParseFixedFields(const Data: TBytes; out Values: TStringArray;
  out ErrMsg: string): boolean;
var
  i, LineStart, LineNumber, EqualsAt: integer;
  Line, Key, Value: string;
begin
  Result := False;
  SetLength(Values, 0);
  ErrMsg := '';
  if (Length(Data) = 0) or (Length(Data) > MAX_SPI_NOR_PROFILE_BYTES) then
  begin
    ErrMsg := Format('profile size must be 1..%d bytes',
                     [MAX_SPI_NOR_PROFILE_BYTES]);
    Exit;
  end;
  if Data[High(Data)] <> 10 then
  begin
    ErrMsg := 'canonical profile must end with an LF';
    Exit;
  end;
  for i := 0 to High(Data) do
    if (Data[i] <> 10) and ((Data[i] < 32) or (Data[i] > 126)) then
    begin
      ErrMsg := Format('non-canonical byte at offset %d', [i]);
      Exit;
    end;

  SetLength(Values, PROFILE_FIELD_COUNT);
  LineStart := 0;
  LineNumber := 0;
  for i := 0 to High(Data) do
    if Data[i] = 10 then
    begin
      if LineNumber >= PROFILE_FIELD_COUNT then
      begin
        ErrMsg := 'profile contains too many fields';
        Exit;
      end;
      SetLength(Line, i - LineStart);
      if Length(Line) > 0 then
        Move(Data[LineStart], Line[1], Length(Line));
      if Line = '' then
      begin
        ErrMsg := Format('empty line at field %d', [LineNumber + 1]);
        Exit;
      end;
      EqualsAt := Pos('=', Line);
      if EqualsAt < 2 then
      begin
        ErrMsg := Format('missing separator at field %d', [LineNumber + 1]);
        Exit;
      end;
      Key := Copy(Line, 1, EqualsAt - 1);
      Value := Copy(Line, EqualsAt + 1, Length(Line));
      if (Value = '') or (Pos('=', Value) > 0) then
      begin
        ErrMsg := Format('invalid value at field %d', [LineNumber + 1]);
        Exit;
      end;
      if Key <> PROFILE_KEYS[LineNumber] then
      begin
        ErrMsg := Format('expected field "%s", found "%s"',
                         [PROFILE_KEYS[LineNumber], Key]);
        Exit;
      end;
      Values[LineNumber] := Value;
      Inc(LineNumber);
      LineStart := i + 1;
    end;
  if LineNumber <> PROFILE_FIELD_COUNT then
  begin
    ErrMsg := Format('profile contains %d fields; expected %d',
                     [LineNumber, PROFILE_FIELD_COUNT]);
    Exit;
  end;
  Result := True;
end;

function ParseSPINORChipProfile(const Data: TBytes;
  out Profile: TSPINORChipProfile; out ErrMsg: string): boolean;
var
  Values: TStringArray;
  ParsedVersion: cardinal;
  Canonical: TBytes;
begin
  Result := False;
  ClearSPINORChipProfile(Profile);
  if not ParseFixedFields(Data, Values, ErrMsg) then Exit;
  if Values[0] <> SPI_NOR_PROFILE_FORMAT then
  begin
    ErrMsg := 'unsupported SPI NOR profile format';
    Exit;
  end;
  if not StrictCardinal(Values[1], ParsedVersion) then
  begin
    ErrMsg := 'invalid profile version';
    Exit;
  end;
  Profile.Version := ParsedVersion;
  Profile.Name := Values[2];
  Profile.JedecID := Values[3];
  if not StrictQWord(Values[4], Profile.CapacityBytes) then
  begin
    ErrMsg := 'invalid capacity';
    ClearSPINORChipProfile(Profile);
    Exit;
  end;
  if not StrictCardinal(Values[5], Profile.PageSize) then
  begin
    ErrMsg := 'invalid page size';
    ClearSPINORChipProfile(Profile);
    Exit;
  end;
  if not StrictCardinal(Values[6], Profile.EraseSize) then
  begin
    ErrMsg := 'invalid erase size';
    ClearSPINORChipProfile(Profile);
    Exit;
  end;
  if not StrictByteHex(Values[7], Profile.EraseOpcode) then
  begin
    ErrMsg := 'invalid erase opcode';
    ClearSPINORChipProfile(Profile);
    Exit;
  end;
  if not StrictCardinal(Values[8], Profile.VccMinMv) then
  begin
    ErrMsg := 'invalid minimum VCC';
    ClearSPINORChipProfile(Profile);
    Exit;
  end;
  if not StrictCardinal(Values[9], Profile.VccMaxMv) then
  begin
    ErrMsg := 'invalid maximum VCC';
    ClearSPINORChipProfile(Profile);
    Exit;
  end;
  if not ValidateSPINORChipProfile(Profile, ErrMsg) then
  begin
    ClearSPINORChipProfile(Profile);
    Exit;
  end;
  Canonical := UncheckedCanonicalBytes(Profile);
  if not SameBytes(Data, Canonical) then
  begin
    ErrMsg := 'profile is not in canonical byte form';
    ClearSPINORChipProfile(Profile);
    Exit;
  end;
  Result := True;
end;

end.
