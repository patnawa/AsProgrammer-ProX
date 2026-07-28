program chipprofile_tests;

{$mode objfpc}{$H+}

uses
  SysUtils, chipprofile;

var
  ChecksRun: integer = 0;
  ChecksFailed: integer = 0;

procedure Check(Condition: boolean; const Name: string;
  const Detail: string = '');
begin
  Inc(ChecksRun);
  if Condition then Exit;
  Inc(ChecksFailed);
  if Detail = '' then
    WriteLn('FAIL: ', Name)
  else
    WriteLn('FAIL: ', Name, ' -- ', Detail);
end;

function StringBytes(const Value: RawByteString): TBytes;
begin
  Result := nil;
  SetLength(Result, Length(Value));
  if Length(Value) > 0 then Move(Value[1], Result[0], Length(Value));
end;

function BytesString(const Value: TBytes): RawByteString;
begin
  SetLength(Result, Length(Value));
  if Length(Value) > 0 then Move(Value[0], Result[1], Length(Value));
end;

function SameProfile(const A, B: TSPINORChipProfile): boolean;
begin
  Result :=
    (A.Version = B.Version) and
    (A.Name = B.Name) and
    (A.JedecID = B.JedecID) and
    (A.CapacityBytes = B.CapacityBytes) and
    (A.PageSize = B.PageSize) and
    (A.EraseSize = B.EraseSize) and
    (A.EraseOpcode = B.EraseOpcode) and
    (A.VccMinMv = B.VccMinMv) and
    (A.VccMaxMv = B.VccMaxMv);
end;

function ValidFixture: TSPINORChipProfile;
begin
  ClearSPINORChipProfile(Result);
  Result.Version := SPI_NOR_PROFILE_VERSION;
  Result.Name := 'W25Q64JV';
  Result.JedecID := 'EF4017';
  Result.CapacityBytes := 8388608;
  Result.PageSize := 256;
  Result.EraseSize := 4096;
  Result.EraseOpcode := $20;
  Result.VccMinMv := 2700;
  Result.VccMaxMv := 3600;
end;

procedure MustRejectProfile(const Profile: TSPINORChipProfile;
  const Name: string);
var
  Data: TBytes;
  ErrMsg: string;
begin
  Check(not ValidateSPINORChipProfile(Profile, ErrMsg),
        Name + ' validation');
  Data := StringBytes('must be cleared');
  Check(not TryCanonicalSPINORChipProfileBytes(Profile, Data, ErrMsg),
        Name + ' canonicalization');
  Check(Length(Data) = 0, Name + ' returns no hashable bytes');
end;

procedure MustRejectBytes(const Data: TBytes; const Name: string);
var
  Profile: TSPINORChipProfile;
  ErrMsg: string;
begin
  Check(not ParseSPINORChipProfile(Data, Profile, ErrMsg), Name, ErrMsg);
  Check(Profile.Version = 0, Name + ' clears output');
end;

function ReplaceOnce(const Data: TBytes; const OldValue,
  NewValue: RawByteString): TBytes;
var
  Text: RawByteString;
  At: SizeInt;
begin
  Text := BytesString(Data);
  At := Pos(OldValue, Text);
  if At = 0 then raise Exception.Create('test replacement target missing');
  Delete(Text, At, Length(OldValue));
  Insert(NewValue, Text, At);
  Result := StringBytes(Text);
end;

procedure TestCanonicalFixture;
const
  EXPECTED: RawByteString =
    'format=AsProgrammer-ProX/spi-nor-profile'#10 +
    'version=1'#10 +
    'name=W25Q64JV'#10 +
    'jedec_id=EF4017'#10 +
    'capacity_bytes=8388608'#10 +
    'page_size=256'#10 +
    'erase_size=4096'#10 +
    'erase_opcode=20'#10 +
    'vcc_min_mv=2700'#10 +
    'vcc_max_mv=3600'#10;
var
  Profile, Parsed: TSPINORChipProfile;
  Data, Other: TBytes;
  ErrMsg: string;
begin
  Profile := ValidFixture;
  Check(ValidateSPINORChipProfile(Profile, ErrMsg),
        'valid fixture validates', ErrMsg);
  Check(TryCanonicalSPINORChipProfileBytes(Profile, Data, ErrMsg),
        'try canonical succeeds', ErrMsg);
  Check(BytesString(Data) = EXPECTED, 'golden canonical bytes');
  Other := CanonicalSPINORChipProfileBytes(Profile);
  Check(BytesString(Other) = EXPECTED, 'raising canonical API is stable');
  Check(ParseSPINORChipProfile(Data, Parsed, ErrMsg),
        'canonical profile parses', ErrMsg);
  Check(SameProfile(Profile, Parsed), 'round trip preserves all fields');
end;

procedure TestInvalidRecords;
var
  P: TSPINORChipProfile;
begin
  P := ValidFixture; P.Version := 2;
  MustRejectProfile(P, 'unknown version');
  P := ValidFixture; P.Name := 'W25 Q64';
  MustRejectProfile(P, 'ambiguous name');
  P := ValidFixture; P.JedecID := 'ef4017';
  MustRejectProfile(P, 'lowercase JEDEC');
  P := ValidFixture; P.JedecID := 'EF40';
  MustRejectProfile(P, 'short JEDEC');
  P := ValidFixture; P.JedecID := '000000';
  MustRejectProfile(P, 'floating-low JEDEC');
  P := ValidFixture; P.JedecID := 'FFFFFF';
  MustRejectProfile(P, 'floating-high JEDEC');
  P := ValidFixture; P.CapacityBytes := 0;
  MustRejectProfile(P, 'zero capacity');
  P := ValidFixture; P.CapacityBytes := 8388609;
  MustRejectProfile(P, 'unaligned capacity');
  P := ValidFixture; P.PageSize := 192;
  MustRejectProfile(P, 'non-power-of-two page');
  P := ValidFixture; P.PageSize := 8192;
  MustRejectProfile(P, 'page larger than erase');
  P := ValidFixture; P.EraseSize := 3072;
  MustRejectProfile(P, 'non-power-of-two erase');
  P := ValidFixture; P.EraseOpcode := $00;
  MustRejectProfile(P, 'zero opcode');
  P := ValidFixture; P.EraseOpcode := $FF;
  MustRejectProfile(P, 'FF opcode');
  P := ValidFixture; P.VccMinMv := 3700;
  MustRejectProfile(P, 'reversed VCC');
  P := ValidFixture; P.VccMinMv := 499;
  MustRejectProfile(P, 'unsafe low VCC');
  P := ValidFixture; P.VccMaxMv := 6001;
  MustRejectProfile(P, 'unsafe high VCC');
end;

procedure TestStrictParser;
var
  P: TSPINORChipProfile;
  Data, Mutated: TBytes;
  ErrMsg: string;
begin
  P := ValidFixture;
  Data := CanonicalSPINORChipProfileBytes(P);

  Mutated := ReplaceOnce(Data, 'version=1'#10, 'version=01'#10);
  MustRejectBytes(Mutated, 'leading-zero integer rejected');
  Mutated := ReplaceOnce(Data, 'erase_opcode=20'#10,
                         'erase_opcode=020'#10);
  MustRejectBytes(Mutated, 'wide opcode rejected');
  Mutated := ReplaceOnce(Data, 'erase_opcode=20'#10,
                         'erase_opcode=2a'#10);
  MustRejectBytes(Mutated, 'lowercase opcode rejected');
  Mutated := ReplaceOnce(Data, 'jedec_id=EF4017'#10,
                         'jedec_id=ef4017'#10);
  MustRejectBytes(Mutated, 'lowercase ID bytes rejected');
  Mutated := ReplaceOnce(Data, 'page_size=256'#10,
                         'erase_size=4096'#10);
  MustRejectBytes(Mutated, 'reordered or duplicate key rejected');
  Mutated := ReplaceOnce(Data, 'name=W25Q64JV'#10,
                         'unknown=value'#10 + 'name=W25Q64JV'#10);
  MustRejectBytes(Mutated, 'unknown key rejected');
  Mutated := ReplaceOnce(Data, #10, #13#10);
  MustRejectBytes(Mutated, 'CRLF rejected');
  SetLength(Mutated, Length(Data) - 1);
  if Length(Mutated) > 0 then Move(Data[0], Mutated[0], Length(Mutated));
  MustRejectBytes(Mutated, 'missing final LF rejected');
  Mutated := Copy(Data, 0, Length(Data));
  Mutated[5] := 0;
  MustRejectBytes(Mutated, 'non-ASCII byte rejected');

  Check(ParseSPINORChipProfile(Data, P, ErrMsg),
        'valid bytes remain accepted after mutations', ErrMsg);
end;

procedure TestCanonicalRaises;
var
  P: TSPINORChipProfile;
  Raised: boolean;
  Data: TBytes;
begin
  P := ValidFixture;
  P.JedecID := '';
  Raised := False;
  try
    Data := CanonicalSPINORChipProfileBytes(P);
    Check(Length(Data) = 0, 'invalid raising result is not usable');
  except
    on E: EArgumentException do Raised := True;
  end;
  Check(Raised, 'invalid convenience canonicalization raises');
end;

begin
  TestCanonicalFixture;
  TestInvalidRecords;
  TestStrictParser;
  TestCanonicalRaises;
  if ChecksFailed = 0 then
  begin
    WriteLn('PASS: ', ChecksRun, ' chip-profile checks');
    Halt(0);
  end;
  WriteLn('FAIL: ', ChecksFailed, ' of ', ChecksRun,
          ' chip-profile checks');
  Halt(1);
end.
