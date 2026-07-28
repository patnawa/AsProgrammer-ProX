program stage9tests;

// Standalone tests for the production-safety foundation.  This executable is
// intentionally separate from the legacy/LCL test runner so it can be built
// with the stock FPC command line and no GUI dependencies.

{$mode objfpc}{$H+}

uses
  Classes, SysUtils,
  prodcrypto, prodjob, prodevidence, prodstate, electricalpreflight,
  productiongate;

var
  ChecksRun: integer = 0;
  ChecksFailed: integer = 0;

type
  TFailingReadStream = class(TMemoryStream)
  public
    function Read(var Buffer; Count: LongInt): LongInt; override;
  end;

function TFailingReadStream.Read(var Buffer; Count: LongInt): LongInt;
begin
  Result := 0;
  raise EReadError.Create('injected read failure');
end;

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

function ReplaceBytes(const Data: TBytes; const OldValue,
  NewValue: RawByteString; ReplaceAll: boolean = False): TBytes;
var
  Flags: TReplaceFlags;
begin
  Flags := [];
  if ReplaceAll then Include(Flags, rfReplaceAll);
  Result := StringBytes(StringReplace(BytesString(Data), OldValue,
                                      NewValue, Flags));
end;

function CopyBytes(const Data: TBytes): TBytes;
begin
  Result := nil;
  SetLength(Result, Length(Data));
  if Length(Data) > 0 then Move(Data[0], Result[0], Length(Data));
end;

procedure WriteBytes(const FileName: string; const Data: TBytes);
var
  Stream: TFileStream;
begin
  Stream := TFileStream.Create(FileName, fmCreate);
  try
    if Length(Data) > 0 then Stream.WriteBuffer(Data[0], Length(Data));
  finally
    Stream.Free;
  end;
end;

function ReadBytes(const FileName: string): TBytes;
var
  Stream: TFileStream;
begin
  Result := nil;
  Stream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
  try
    SetLength(Result, Stream.Size);
    if Length(Result) > 0 then Stream.ReadBuffer(Result[0], Length(Result));
  finally
    Stream.Free;
  end;
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

function MakeKey(StartValue: byte): TBytes;
var
  i: integer;
begin
  Result := nil;
  SetLength(Result, MIN_HMAC_KEY_BYTES);
  for i := 0 to High(Result) do Result[i] := StartValue + byte(i);
end;

function MakeTempDirectory: string;
var
  G: TGUID;
  Token: string;
begin
  if CreateGUID(G) <> 0 then
    raise Exception.Create('CreateGUID failed');
  Token := StringReplace(StringReplace(GUIDToString(G), '{', '',
                         [rfReplaceAll]), '}', '', [rfReplaceAll]);
  Result := IncludeTrailingPathDelimiter(GetTempDir(False)) +
            'asprogrammer-stage9-' + Token;
  if not CreateDir(Result) then
    raise Exception.Create('cannot create test directory: ' + Result);
end;

procedure DeleteKnownFiles(const Directory: string);
const
  NAMES: array[0..8] of string = (
    'firmware.bin', 'job.apjob', 'job.auth',
    'atomic.dat', 'evidence.dat', 'empty-evidence.dat',
    'signed-evidence.dat', 'state.log', 'state.log.head'
  );
var
  i: integer;
  Search: TSearchRec;
  Prefix: string;
begin
  for i := Low(NAMES) to High(NAMES) do
    if FileExists(IncludeTrailingPathDelimiter(Directory) + NAMES[i]) then
      DeleteFile(IncludeTrailingPathDelimiter(Directory) + NAMES[i]);
  Prefix := IncludeTrailingPathDelimiter(Directory) + 'collision.tmp-*';
  if FindFirst(Prefix, faAnyFile, Search) = 0 then
  begin
    repeat
      if (Search.Attr and faDirectory) = 0 then
        DeleteFile(IncludeTrailingPathDelimiter(Directory) + Search.Name);
    until FindNext(Search) <> 0;
    FindClose(Search);
  end;
  RemoveDir(IncludeTrailingPathDelimiter(Directory) + 'collision');
  RemoveDir(Directory);
end;

function HasMatchingFile(const Pattern: string): boolean;
var
  Search: TSearchRec;
begin
  Result := FindFirst(Pattern, faAnyFile, Search) = 0;
  if Result then FindClose(Search);
end;

procedure TestCrypto;
var
  Data, Key, ShortKey: TBytes;
  Digest, Other, MAC: TSHA256Digest;
  ErrMsg: string;
  FailingStream: TFailingReadStream;
begin
  Data := nil;
  Check(SHA256Bytes(Data, Digest, ErrMsg), 'SHA-256 empty succeeds', ErrMsg);
  Check(DigestToHex(Digest) =
    'E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855',
    'SHA-256 empty known vector');

  Data := StringBytes('abc');
  Check(SHA256Bytes(Data, Digest, ErrMsg), 'SHA-256 abc succeeds', ErrMsg);
  Check(DigestToHex(Digest) =
    'BA7816BF8F01CFEA414140DE5DAE2223B00361A396177A9CB410FF61F20015AD',
    'SHA-256 abc known vector');
  Check(HexToDigest(DigestToHex(Digest), Other),
        'digest uppercase hex decodes');
  Check(DigestEqualConstantTime(Digest, Other),
        'constant-time digest equality accepts match');
  Other[31] := Other[31] xor 1;
  Check(not DigestEqualConstantTime(Digest, Other),
        'constant-time digest equality rejects mismatch');

  SetLength(Key, 32);
  FillChar(Key[0], Length(Key), $0B);
  Data := StringBytes('Hi There');
  Check(HMACSHA256(Key, Data, MAC, ErrMsg), 'HMAC-SHA-256 succeeds', ErrMsg);
  Check(DigestToHex(MAC) =
    '198A607EB44BFBC69903A0F1CF2BBDC5BA0AA3F3D9AE3C1C7A3B1696A0B68CF7',
    'HMAC-SHA-256 independent known vector');

  SetLength(ShortKey, MIN_HMAC_KEY_BYTES - 1);
  Check(not HMACSHA256(ShortKey, Data, MAC, ErrMsg),
        'HMAC rejects a short production key');

  FailingStream := TFailingReadStream.Create;
  try
    Check(not SHA256Stream(FailingStream, Digest, ErrMsg),
          'stream hashing reports read exceptions without escaping');
  finally
    FailingStream.Free;
  end;
  ClearSensitiveBytes(Key);
  ClearSensitiveBytes(ShortKey);
end;

function MakeJob(const ImageDigest: string; ImageLength: cardinal):
  TProductionJob;
begin
  Result.Version := PRODUCTION_JOB_VERSION;
  Result.JobID := 'line-A_batch-0042';
  Result.Revision := 7;
  Result.CreatedUTC := 1700000000;
  Result.ExpiresUTC := 1900000000;
  Result.Protocol := spSPI;
  Result.ChipName := 'W25Q-Test';
  Result.ChipID := 'EF4017';
  Result.ChipSize := 1024;
  Result.ChipDefinitionSHA256 :=
    'BA7816BF8F01CFEA414140DE5DAE2223B00361A396177A9CB410FF61F20015AD';
  Result.ImageFile := 'firmware.bin';
  Result.ImageSize := ImageLength;
  Result.ImageSHA256 := ImageDigest;
  Result.StartAddress := 128;
  Result.WriteLength := ImageLength;
  Result.VccMinMv := 3000;
  Result.VccMaxMv := 3600;
  Result.VioMaxMv := 3600;
  Result.MaxBusHz := 10000000;
  Result.OpenDrainRequired := False;
  Result.ExternalPowerAllowed := False;
  Result.ReadPasses := 3;
  Result.BackupRequired := True;
  Result.UIDRequired := True;
  Result.RequiredProgrammerID := 'programmer-A';
  Result.RequiredAdapterID := 'none';
  Result.VerifyMode := pvmFull;
end;

procedure CheckJobRejects(const Data: TBytes; const Name: string);
var
  Parsed: TProductionJob;
  ErrMsg: string;
begin
  Check(not ParseProductionJob(Data, Parsed, ErrMsg), Name);
end;

procedure TestJobsAndImages(const Directory: string);
var
  Image, ChangedImage, Manifest, AuthBytes, Mutated: TBytes;
  Key, WrongKey, ShortKey: TBytes;
  ImageDigest: TSHA256Digest;
  Job, Parsed, ChangedJob, Loaded, SweepJob: TProductionJob;
  Auth, ParsedAuth, ChangedAuth, SweepAuth: TDetachedJobAuth;
  ErrMsg, Resolved: string;
  ManifestFile, AuthFile, ImageFile: string;
  VerifiedStream: TFileStream;
  i: integer;
  SweepOK, WriteBlocked: boolean;
begin
  Image := StringBytes('PROD1234');
  Check(SHA256Bytes(Image, ImageDigest, ErrMsg),
        'fixture image SHA-256 succeeds', ErrMsg);
  Job := MakeJob(DigestToHex(ImageDigest), Length(Image));
  Check(ValidateProductionJob(Job, ErrMsg), 'valid production job', ErrMsg);
  Check(VerifyChipDefinitionBytes(Job, StringBytes('abc'), ErrMsg),
        'exact chip-definition bytes match mandatory SHA-256', ErrMsg);
  Check(not VerifyChipDefinitionBytes(Job, StringBytes('abd'), ErrMsg),
        'changed chip-definition bytes are rejected');

  Manifest := CanonicalProductionJobBytes(Job);
  Check(ParseProductionJob(Manifest, Parsed, ErrMsg),
        'canonical production job parses', ErrMsg);
  Check((Parsed.JobID = Job.JobID) and
        (Parsed.ImageSHA256 = Job.ImageSHA256) and
        (Parsed.StartAddress = Job.StartAddress),
        'production job round trip retains security fields');

  Mutated := ReplaceBytes(Manifest, 'job_id=', 'unexpected=');
  CheckJobRejects(Mutated, 'unknown/reordered manifest key is rejected');
  Mutated := ReplaceBytes(Manifest, 'revision=7'#10, 'revision=07'#10);
  CheckJobRejects(Mutated, 'non-canonical leading-zero integer is rejected');
  Mutated := ReplaceBytes(Manifest, Job.ImageSHA256,
                          LowerCase(Job.ImageSHA256));
  CheckJobRejects(Mutated, 'lowercase manifest digest is rejected');
  Mutated := ReplaceBytes(Manifest, #10, #13#10, True);
  CheckJobRejects(Mutated, 'CRLF manifest is rejected as non-canonical');
  Mutated := CopyBytes(Manifest);
  SetLength(Mutated, Length(Mutated) - 1);
  CheckJobRejects(Mutated, 'manifest without final LF is rejected');
  Mutated := StringBytes(BytesString(Manifest) + 'extra=1'#10);
  CheckJobRejects(Mutated, 'extra manifest field is rejected');

  ChangedJob := Job;
  ChangedJob.ImageFile := '../firmware.bin';
  Check(not ValidateProductionJob(ChangedJob, ErrMsg),
        'manifest path traversal is rejected');
  ChangedJob := Job;
  ChangedJob.ImageFile := 'CON.bin';
  Check(not ValidateProductionJob(ChangedJob, ErrMsg),
        'Windows device basename is rejected');
  ChangedJob := Job;
  ChangedJob.StartAddress := ChangedJob.ChipSize - 1;
  ChangedJob.WriteLength := 2;
  ChangedJob.ImageSize := 2;
  Check(not ValidateProductionJob(ChangedJob, ErrMsg),
        'out-of-chip write range is rejected without overflow');
  ChangedJob := Job;
  ChangedJob.Protocol := spI2C;
  ChangedJob.OpenDrainRequired := False;
  Check(not ValidateProductionJob(ChangedJob, ErrMsg),
        'I2C job cannot disable open-drain requirement');

  Key := MakeKey(1);
  Check(CreateDetachedJobAuth(Job, 'factory-key-2026', Key, Auth, ErrMsg),
        'detached job authentication is created', ErrMsg);
  Check((Auth.ManifestSHA256 <> '') and (Auth.MAC <> ''),
        'detached authentication contains mandatory digests');
  AuthBytes := CanonicalDetachedJobAuthBytes(Auth);
  Check(ParseDetachedJobAuth(AuthBytes, ParsedAuth, ErrMsg),
        'canonical detached authentication parses', ErrMsg);
  Check(VerifyDetachedJobAuth(Job, ParsedAuth, 'factory-key-2026', Key,
                              1800000000, ErrMsg),
        'detached authentication verifies in validity window', ErrMsg);

  SweepOK := True;
  for i := 0 to High(Manifest) do
  begin
    Mutated := CopyBytes(Manifest);
    Mutated[i] := Mutated[i] xor 1;
    if ParseProductionJob(Mutated, SweepJob, ErrMsg) and
       VerifyDetachedJobAuth(SweepJob, ParsedAuth, 'factory-key-2026', Key,
                             1800000000, ErrMsg) then
    begin
      SweepOK := False;
      Break;
    end;
  end;
  Check(SweepOK,
        'every one-bit manifest mutation is rejected by parse or HMAC');

  SweepOK := True;
  for i := 0 to High(AuthBytes) do
  begin
    Mutated := CopyBytes(AuthBytes);
    Mutated[i] := Mutated[i] xor 1;
    if ParseDetachedJobAuth(Mutated, SweepAuth, ErrMsg) and
       VerifyDetachedJobAuth(Job, SweepAuth, 'factory-key-2026', Key,
                             1800000000, ErrMsg) then
    begin
      SweepOK := False;
      Break;
    end;
  end;
  Check(SweepOK,
        'every one-bit detached-auth mutation is rejected');

  ChangedJob := Job;
  Inc(ChangedJob.Revision);
  Check(not VerifyDetachedJobAuth(ChangedJob, ParsedAuth,
                                  'factory-key-2026', Key,
                                  1800000000, ErrMsg),
        'authenticated field tampering is rejected');
  WrongKey := MakeKey(77);
  Check(not VerifyDetachedJobAuth(Job, ParsedAuth, 'factory-key-2026',
                                  WrongKey, 1800000000, ErrMsg),
        'wrong HMAC key is rejected');
  Check(not VerifyDetachedJobAuth(Job, ParsedAuth, 'retired-key', Key,
                                  1800000000, ErrMsg),
        'unexpected key ID is rejected');
  Check(not VerifyDetachedJobAuth(Job, ParsedAuth, 'factory-key-2026', Key,
                                  Job.ExpiresUTC + 1, ErrMsg),
        'expired authenticated job is rejected');
  Check(not VerifyDetachedJobAuth(Job, ParsedAuth, 'factory-key-2026', Key,
                                  Job.CreatedUTC - 1, ErrMsg),
        'not-yet-valid authenticated job is rejected');

  ChangedAuth := ParsedAuth;
  if ChangedAuth.MAC[1] = '0' then ChangedAuth.MAC[1] := '1'
  else ChangedAuth.MAC[1] := '0';
  Check(not VerifyDetachedJobAuth(Job, ChangedAuth, 'factory-key-2026',
                                  Key, 1800000000, ErrMsg),
        'detached MAC tampering is rejected');
  SetLength(ShortKey, MIN_HMAC_KEY_BYTES - 1);
  Check(not CreateDetachedJobAuth(Job, 'factory-key-2026', ShortKey,
                                  ChangedAuth, ErrMsg),
        'job authentication refuses short keys');

  ManifestFile := IncludeTrailingPathDelimiter(Directory) + 'job.apjob';
  AuthFile := IncludeTrailingPathDelimiter(Directory) + 'job.auth';
  ImageFile := IncludeTrailingPathDelimiter(Directory) + Job.ImageFile;
  WriteBytes(ManifestFile, Manifest);
  WriteBytes(AuthFile, AuthBytes);
  WriteBytes(ImageFile, Image);
  Check(LoadAuthenticatedProductionJob(ManifestFile, AuthFile,
        'factory-key-2026', Key, 1800000000, Loaded, ErrMsg),
        'safe authenticated-job loader succeeds', ErrMsg);
  Check(Loaded.JobID = Job.JobID,
        'safe authenticated-job loader returns the verified job');

  Check(VerifyProductionImage(Job, Directory, Resolved, ErrMsg),
        'production image size and SHA-256 verify', ErrMsg);
  Check(CompareText(Resolved, ExpandFileName(ImageFile)) = 0,
        'production image resolves to manifest sibling');
  VerifiedStream := nil;
  Check(OpenVerifiedProductionImage(Job, Directory, VerifiedStream,
                                    Resolved, ErrMsg),
        'production image opens as a retained verified stream', ErrMsg);
  if VerifiedStream <> nil then
  begin
    Check((VerifiedStream.Position = 0) and
          (VerifiedStream.Size = Length(Image)),
          'verified image stream is rewound and retains its handle');
    WriteBlocked := False;
    try
      WriteBytes(ImageFile, StringBytes('PROD123X'));
    except
      on E: Exception do WriteBlocked := True;
    end;
    Check(WriteBlocked,
          'retained verified image handle denies concurrent replacement');
    VerifiedStream.Free;
    if not WriteBlocked then WriteBytes(ImageFile, Image);
  end;
  ChangedImage := StringBytes('PROD123X');
  WriteBytes(ImageFile, ChangedImage);
  Check(not VerifyProductionImage(Job, Directory, Resolved, ErrMsg),
        'same-size image tampering is rejected');
  WriteBytes(ImageFile, Image);
  ChangedImage := StringBytes('short');
  WriteBytes(ImageFile, ChangedImage);
  Check(not VerifyProductionImage(Job, Directory, Resolved, ErrMsg),
        'wrong-size production image is rejected');
  WriteBytes(ImageFile, Image);

  ClearSensitiveBytes(Key);
  ClearSensitiveBytes(WrongKey);
  ClearSensitiveBytes(ShortKey);
end;

procedure TestEvidence(const Directory: string);
var
  Payload, Envelope, Decoded, Tampered, OldData, NewData, OnDisk: TBytes;
  Info, ParsedInfo: TEvidenceEnvelopeInfo;
  ErrMsg, PayloadHash: string;
  AtomicFile, EvidenceFile, EmptyEvidenceFile, CollisionDirectory: string;
begin
  Payload := StringBytes('{"run":"R-42","result":"pass"}'#10);
  Check(BuildEvidenceEnvelope('R-42', Payload, Envelope, Info, ErrMsg),
        'evidence envelope builds', ErrMsg);
  Check((Info.PayloadLength = cardinal(Length(Payload))) and
        (Length(Info.ContentSHA256) = SHA256_HEX_CHARS),
        'evidence header carries mandatory size and SHA-256');
  Check(ValidateEvidenceEnvelope(Envelope, ParsedInfo, Decoded, ErrMsg),
        'evidence envelope validates', ErrMsg);
  Check((ParsedInfo.RunID = 'R-42') and SameBytes(Payload, Decoded),
        'evidence envelope round trip retains exact payload');

  Tampered := CopyBytes(Envelope);
  Tampered[High(Tampered)] := Tampered[High(Tampered)] xor 1;
  Check(not ValidateEvidenceEnvelope(Tampered, ParsedInfo, Decoded, ErrMsg),
        'evidence payload tampering is detected');
  Tampered := CopyBytes(Envelope);
  SetLength(Tampered, Length(Tampered) - 1);
  Check(not ValidateEvidenceEnvelope(Tampered, ParsedInfo, Decoded, ErrMsg),
        'truncated evidence payload is detected');
  // The content digest binds the run ID: header corruption that stays in the
  // valid charset must fail exactly like payload corruption.
  Tampered := ReplaceBytes(Envelope, 'run_id=R-42', 'run_id=R-43');
  Check(not ValidateEvidenceEnvelope(Tampered, ParsedInfo, Decoded, ErrMsg),
        'evidence run ID tampering is detected');
  Check(not BuildEvidenceEnvelope('../escape', Payload, Tampered,
                                  ParsedInfo, ErrMsg),
        'unsafe evidence run ID is rejected');

  AtomicFile := IncludeTrailingPathDelimiter(Directory) + 'atomic.dat';
  OldData := StringBytes('old');
  NewData := StringBytes('new-data');
  Check(AtomicWriteDurable(AtomicFile, OldData, False, ErrMsg),
        'durable atomic create succeeds', ErrMsg);
  Check(not AtomicWriteDurable(AtomicFile, NewData, False, ErrMsg),
        'durable atomic create refuses overwrite');
  OnDisk := ReadBytes(AtomicFile);
  Check(SameBytes(OnDisk, OldData),
        'refused overwrite preserves original bytes');
  Check(AtomicWriteDurable(AtomicFile, NewData, True, ErrMsg),
        'explicit durable atomic replace succeeds', ErrMsg);
  OnDisk := ReadBytes(AtomicFile);
  Check(SameBytes(OnDisk, NewData),
        'durable atomic replace installs all new bytes');

  CollisionDirectory := IncludeTrailingPathDelimiter(Directory) + 'collision';
  Check(CreateDir(CollisionDirectory),
        'atomic-failure fixture directory is created');
  Check(not AtomicWriteDurable(CollisionDirectory, NewData, False, ErrMsg),
        'atomic install failure is reported');
  Check(not HasMatchingFile(CollisionDirectory + '.tmp-*'),
        'failed atomic install cleans its sibling temporary file');
  RemoveDir(CollisionDirectory);

  EvidenceFile := IncludeTrailingPathDelimiter(Directory) + 'evidence.dat';
  Check(SaveEvidenceAtomic(EvidenceFile, 'R-42', Payload, PayloadHash,
                           ErrMsg),
        'immutable evidence save succeeds', ErrMsg);
  Check(PayloadHash = Info.ContentSHA256,
        'immutable evidence save returns content SHA-256');
  Check(not SaveEvidenceAtomic(EvidenceFile, 'R-42', Payload, PayloadHash,
                               ErrMsg),
        'immutable evidence save refuses duplicate run file');
  OnDisk := ReadBytes(EvidenceFile);
  Check(ValidateEvidenceEnvelope(OnDisk, ParsedInfo, Decoded, ErrMsg),
        'atomically saved evidence validates', ErrMsg);

  EmptyEvidenceFile := IncludeTrailingPathDelimiter(Directory) +
                       'empty-evidence.dat';
  Payload := nil;
  Check(SaveEvidenceAtomic(EmptyEvidenceFile, 'empty-run', Payload,
                           PayloadHash, ErrMsg),
        'zero-length evidence payload saves safely', ErrMsg);
  OnDisk := ReadBytes(EmptyEvidenceFile);
  Check(ValidateEvidenceEnvelope(OnDisk, ParsedInfo, Decoded, ErrMsg) and
        (Length(Decoded) = 0),
        'zero-length evidence payload validates', ErrMsg);
end;

procedure TestSignedEvidence(const Directory: string);
var
  Payload, Envelope, Decoded, Tampered, OnDisk: TBytes;
  Key, WrongKey, ShortKey: TBytes;
  Info, ParsedInfo: TEvidenceEnvelopeInfo;
  ErrMsg, PayloadHash: string;
  SignedFile: string;
begin
  Key := MakeKey(10);
  WrongKey := MakeKey(200);
  ShortKey := CopyBytes(Key);
  SetLength(ShortKey, MIN_HMAC_KEY_BYTES - 1);
  Payload := StringBytes('{"run":"S-7","result":"pass"}'#10);

  Check(BuildSignedEvidenceEnvelope('S-7', Payload, 'line-a-2026', Key,
                                    Envelope, Info, ErrMsg),
        'signed evidence envelope builds', ErrMsg);
  Check((Info.Version = EVIDENCE_SIGNED_VERSION) and
        (Info.AuthKeyID = 'line-a-2026'),
        'signed evidence info carries version and key ID');
  Check(ValidateSignedEvidenceEnvelope(Envelope, 'line-a-2026', Key,
                                       ParsedInfo, Decoded, ErrMsg),
        'signed evidence envelope validates', ErrMsg);
  Check((ParsedInfo.RunID = 'S-7') and SameBytes(Payload, Decoded) and
        (ParsedInfo.AuthKeyID = 'line-a-2026'),
        'signed evidence round trip retains payload and key ID');

  Check(not ValidateSignedEvidenceEnvelope(Envelope, 'line-a-2026', WrongKey,
                                           ParsedInfo, Decoded, ErrMsg),
        'signed evidence rejects the wrong key');
  Check(not ValidateSignedEvidenceEnvelope(Envelope, 'line-b-2026', Key,
                                           ParsedInfo, Decoded, ErrMsg),
        'signed evidence rejects an unexpected key ID');
  Check(not BuildSignedEvidenceEnvelope('S-7', Payload, 'line-a-2026',
                                        ShortKey, Tampered, ParsedInfo,
                                        ErrMsg),
        'signed evidence build rejects a short key');
  Check(not BuildSignedEvidenceEnvelope('S-7', Payload, 'bad key id',
                                        Key, Tampered, ParsedInfo, ErrMsg),
        'signed evidence build rejects an unsafe key ID');

  Tampered := ReplaceBytes(Envelope, 'run_id=S-7', 'run_id=S-8');
  Check(not ValidateSignedEvidenceEnvelope(Tampered, 'line-a-2026', Key,
                                           ParsedInfo, Decoded, ErrMsg),
        'signed evidence run ID tampering is detected');
  // Rewriting the key-ID line to match a different expectation must still
  // fail: the key ID is inside the MAC input.
  Tampered := ReplaceBytes(Envelope, 'auth_key_id=line-a-2026',
                           'auth_key_id=line-b-2026');
  Check(not ValidateSignedEvidenceEnvelope(Tampered, 'line-b-2026', Key,
                                           ParsedInfo, Decoded, ErrMsg),
        'signed evidence key-ID substitution is detected');
  Tampered := CopyBytes(Envelope);
  Tampered[High(Tampered)] := Tampered[High(Tampered)] xor 1;
  Check(not ValidateSignedEvidenceEnvelope(Tampered, 'line-a-2026', Key,
                                           ParsedInfo, Decoded, ErrMsg),
        'signed evidence payload tampering is detected');

  Check(not ValidateEvidenceEnvelope(Envelope, ParsedInfo, Decoded, ErrMsg),
        'a version-2 envelope does not validate as version 1');

  SignedFile := IncludeTrailingPathDelimiter(Directory) +
                'signed-evidence.dat';
  Check(SaveSignedEvidenceAtomic(SignedFile, 'S-7', Payload, 'line-a-2026',
                                 Key, PayloadHash, ErrMsg),
        'signed evidence save succeeds', ErrMsg);
  OnDisk := ReadBytes(SignedFile);
  Check(ValidateSignedEvidenceEnvelope(OnDisk, 'line-a-2026', Key,
                                       ParsedInfo, Decoded, ErrMsg) and
        (PayloadHash = ParsedInfo.ContentSHA256),
        'atomically saved signed evidence validates', ErrMsg);

  ClearSensitiveBytes(Key);
  ClearSensitiveBytes(WrongKey);
  ClearSensitiveBytes(ShortKey);
end;

procedure TestProductionState(const Directory: string);
var
  Key, WrongKey, Raw: TBytes;
  Entries: TProdStateEntries;
  ErrMsg, StateFile: string;
  i, LastLineAt: integer;
begin
  Key := MakeKey(33);
  WrongKey := MakeKey(77);
  StateFile := IncludeTrailingPathDelimiter(Directory) + 'state.log';

  Check(LoadProductionState(StateFile, Key, Entries, ErrMsg) and
        (Length(Entries) = 0),
        'missing production state loads as empty', ErrMsg);

  Check(AppendProductionState(StateFile, Key, 'job-A', 3, 'run-001',
        'AABBCCDD', 1800000000, ErrMsg),
        'first production state append succeeds', ErrMsg);
  Check(AppendProductionState(StateFile, Key, 'job-A', 3, 'run-002',
        'AABBCCDE', 1800000100, ErrMsg),
        'second production state append succeeds', ErrMsg);
  Check(LoadProductionState(StateFile, Key, Entries, ErrMsg) and
        (Length(Entries) = 2) and (Entries[0].RunID = 'run-001') and
        (Entries[0].JobID = 'job-A') and (Entries[0].Revision = 3) and
        (Entries[1].UID = 'AABBCCDE') and (Entries[1].Seq = 2) and
        (Entries[1].UTC = 1800000100),
        'production state round trip retains every field', ErrMsg);

  Check(not AppendProductionState(StateFile, Key, 'job-A', 3, 'run-001',
        'AABBCCDF', 1800000200, ErrMsg),
        'a duplicate run ID is refused');
  Check(not AppendProductionState(StateFile, Key, 'job-A', 2, 'run-003',
        'AABBCCDF', 1800000200, ErrMsg),
        'a stale job revision is refused');
  Check(not AppendProductionState(StateFile, Key, 'job-B', 1, 'run-004',
        'AABBCCDD', 1800000200, ErrMsg),
        'an already-consumed chip UID is refused');
  Check(not AppendProductionState(StateFile, Key, 'job-A', 4, 'run-005',
        'AABBCC00', 1799999999, ErrMsg),
        'a station clock that moved backwards is refused');
  Check(AppendProductionState(StateFile, Key, 'job-B', 1, 'run-006',
        'none', 1800000300, ErrMsg) and
        AppendProductionState(StateFile, Key, 'job-B', 1, 'run-007',
        'none', 1800000300, ErrMsg),
        'uid "none" may repeat and an equal timestamp is allowed', ErrMsg);

  Check(not LoadProductionState(StateFile, WrongKey, Entries, ErrMsg),
        'production state does not authenticate under the wrong key');

  Raw := ReadBytes(StateFile);
  Raw[10] := Raw[10] xor 1;
  WriteBytes(StateFile, Raw);
  Check(not LoadProductionState(StateFile, Key, Entries, ErrMsg),
        'production state tampering is detected');
  Raw[10] := Raw[10] xor 1;
  WriteBytes(StateFile, Raw);
  Check(LoadProductionState(StateFile, Key, Entries, ErrMsg) and
        (Length(Entries) = 4),
        'restored production state authenticates again', ErrMsg);

  //ตัดบรรทัดสุดท้ายออกทั้งบรรทัด: โซ่ที่เหลือยัง verify ผ่าน แต่สมอหัวโซ่
  //ต้องจับได้ว่ามีรายการหายไป
  LastLineAt := 0;
  for i := 0 to High(Raw) - 1 do
    if Raw[i] = 10 then LastLineAt := i + 1;
  Check(LastLineAt > 0, 'state fixture has more than one line');
  WriteBytes(StateFile, Copy(Raw, 0, LastLineAt));
  Check(not LoadProductionState(StateFile, Key, Entries, ErrMsg),
        'truncating whole recorded entries is detected by the head anchor');
  WriteBytes(StateFile, Raw);

  //ต่อท้ายไบต์ที่ไม่มี LF ปิด: การเขียนที่ขาดกลางคันต้อง fail closed
  SetLength(Raw, Length(Raw) + 4);
  Raw[High(Raw) - 3] := Ord('t');
  Raw[High(Raw) - 2] := Ord('o');
  Raw[High(Raw) - 1] := Ord('r');
  Raw[High(Raw)] := Ord('n');
  WriteBytes(StateFile, Raw);
  Check(not LoadProductionState(StateFile, Key, Entries, ErrMsg),
        'a torn final line is refused');
  SetLength(Raw, Length(Raw) - 4);
  WriteBytes(StateFile, Raw);

  //ลบไฟล์สถานะแต่เหลือสมอไว้: ต้องไม่ถูกมองว่าเป็นสถานีใหม่
  Check(DeleteFile(StateFile), 'state fixture file deletes');
  Check(not LoadProductionState(StateFile, Key, Entries, ErrMsg),
        'a missing state file with a surviving head anchor is refused');

  ClearSensitiveBytes(Key);
  ClearSensitiveBytes(WrongKey);
end;

function MakeProgrammer: TProgrammerElectricalCapabilities;
begin
  Result.Known := True;
  Result.ProgrammerID := 'programmer-A';
  Result.FirmwareVersion := '2.4.1';
  Result.SupportedProtocols := [spSPI, spI2C, spMicrowire];
  Result.PinsSafeAtOpen := True;
  Result.SupportsOpenDrain := True;
  Result.PowerCapability := pcSelectableTargetPower;
  Result.FixedTargetMv := 0;
  Result.TargetMinMv := 1800;
  Result.TargetMaxMv := 5000;
  Result.CanSetVio := True;
  Result.FixedVioMv := 0;
  Result.VioMinMv := 1200;
  Result.VioMaxMv := 5000;
  Result.CanDetectExternalPower := True;
  Result.CanMeasureTargetVoltage := True;
  Result.CanMeasureTargetCurrent := True;
  Result.HasCurrentLimit := True;
  Result.MaxBusHz[spSPI] := 20000000;
  Result.MaxBusHz[spI2C] := 1000000;
  Result.MaxBusHz[spMicrowire] := 2000000;
end;

function MakeNoAdapter: TAdapterElectricalCapabilities;
begin
  Result.Present := False;
  Result.IdentityVerified := False;
  Result.AdapterID := '';
  Result.SupportedProtocols := [];
  Result.TargetMinMv := 0;
  Result.TargetMaxMv := 0;
  Result.MaxProgrammerSideVioMv := 0;
  Result.MaxBusHz[spSPI] := 0;
  Result.MaxBusHz[spI2C] := 0;
  Result.MaxBusHz[spMicrowire] := 0;
  Result.LevelShiftsSignals := False;
  Result.ProvidesOpenDrain := False;
  Result.IsolatesTargetPower := False;
  Result.CalibrationValid := False;
end;

function MakeAdapter: TAdapterElectricalCapabilities;
begin
  Result.Present := True;
  Result.IdentityVerified := True;
  Result.AdapterID := 'adapter-A';
  Result.SupportedProtocols := [spSPI, spI2C];
  Result.TargetMinMv := 1800;
  Result.TargetMaxMv := 5000;
  Result.MaxProgrammerSideVioMv := 5000;
  Result.MaxBusHz[spSPI] := 12000000;
  Result.MaxBusHz[spI2C] := 1000000;
  Result.MaxBusHz[spMicrowire] := 0;
  Result.LevelShiftsSignals := True;
  Result.ProvidesOpenDrain := True;
  Result.IsolatesTargetPower := True;
  Result.CalibrationValid := True;
end;

function MakeTarget: TTargetElectricalRequirements;
begin
  Result.Protocol := spSPI;
  Result.VccMinMv := 3000;
  Result.VccMaxMv := 3600;
  Result.VioMaxMv := 3600;
  Result.MaxBusHz := 10000000;
  Result.RequiredProgrammerID := 'programmer-A';
  Result.RequiredAdapterID := 'none';
  Result.RequiresOpenDrain := False;
  Result.AllowsExternalPower := False;
end;

function MakeObservation: TElectricalObservation;
begin
  Result.TargetPowerEnabled := True;
  Result.SelectedTargetMv := 3300;
  Result.SelectedProgrammerVioMv := 3300;
  Result.EffectiveTargetVioMv := 3300;
  Result.RequestedBusHz := 8000000;
  Result.ExternalPowerKnown := True;
  Result.ExternalPowerPresent := False;
  Result.ExternalPowerCurrentLimited := False;
  Result.TargetVoltageMeasured := True;
  Result.MeasuredTargetMv := 3300;
  Result.CurrentLimitEnabled := True;
end;

function HasIssue(const Report: TPreflightReport;
  Code: TPreflightIssueCode): boolean;
var
  i: integer;
begin
  for i := 0 to High(Report.Issues) do
    if Report.Issues[i].Code = Code then Exit(True);
  Result := False;
end;

procedure CheckBlockedBy(const Report: TPreflightReport;
  Code: TPreflightIssueCode; const Name: string);
begin
  Check((not Report.Allowed) and HasIssue(Report, Code), Name,
        'expected issue ' + PreflightIssueCodeName(Code));
end;

procedure TestElectricalPreflight;
var
  Programmer, ChangedProgrammer: TProgrammerElectricalCapabilities;
  Adapter, ChangedAdapter: TAdapterElectricalCapabilities;
  Target, ChangedTarget: TTargetElectricalRequirements;
  Observation, ChangedObservation: TElectricalObservation;
  Policy: TPreflightPolicy;
  Report: TPreflightReport;
  ErrMsg: string;
begin
  Programmer := MakeProgrammer;
  Adapter := MakeNoAdapter;
  Target := MakeTarget;
  Observation := MakeObservation;
  DefaultProductionPreflightPolicy(Policy);
  Check(ValidateProgrammerCapabilities(Programmer, ErrMsg),
        'typed programmer capabilities validate', ErrMsg);
  Check(ValidateAdapterCapabilities(Adapter, ErrMsg),
        'typed absent-adapter capabilities validate', ErrMsg);
  Check(ValidateTargetRequirements(Target, ErrMsg),
        'typed target requirements validate', ErrMsg);

  Report := EvaluateElectricalPreflight(Programmer, Adapter, Target,
                                        Observation, Policy);
  Check(Report.Allowed, 'safe electrical topology passes preflight');
  Check(Report.MaxSafeBusHz = Target.MaxBusHz,
        'preflight reports the limiting safe bus frequency');

  ChangedProgrammer := Programmer;
  ChangedProgrammer.Known := False;
  Report := EvaluateElectricalPreflight(ChangedProgrammer, Adapter, Target,
                                        Observation, Policy);
  CheckBlockedBy(Report, piProgrammerCapabilitiesUnknown,
                 'unknown programmer capabilities fail closed');

  ChangedTarget := Target;
  ChangedTarget.RequiredProgrammerID := 'programmer-B';
  Report := EvaluateElectricalPreflight(Programmer, Adapter, ChangedTarget,
                                        Observation, Policy);
  CheckBlockedBy(Report, piProgrammerIdentityMismatch,
                 'wrong programmer identity is blocked');

  ChangedProgrammer := Programmer;
  Exclude(ChangedProgrammer.SupportedProtocols, spSPI);
  Report := EvaluateElectricalPreflight(ChangedProgrammer, Adapter, Target,
                                        Observation, Policy);
  CheckBlockedBy(Report, piProtocolUnsupportedByProgrammer,
                 'unsupported programmer protocol is blocked');

  ChangedProgrammer := Programmer;
  ChangedProgrammer.PinsSafeAtOpen := False;
  Report := EvaluateElectricalPreflight(ChangedProgrammer, Adapter, Target,
                                        Observation, Policy);
  CheckBlockedBy(Report, piPinsNotSafeAtOpen,
                 'unsafe initial pin state is blocked');

  ChangedTarget := Target;
  ChangedTarget.RequiredAdapterID := 'any';
  Report := EvaluateElectricalPreflight(Programmer, Adapter, ChangedTarget,
                                        Observation, Policy);
  CheckBlockedBy(Report, piAdapterRequired,
                 'missing required adapter is blocked');

  ChangedAdapter := MakeAdapter;
  Report := EvaluateElectricalPreflight(Programmer, ChangedAdapter, Target,
                                        Observation, Policy);
  CheckBlockedBy(Report, piUnexpectedAdapter,
                 'unexpected adapter topology is blocked');

  ChangedTarget := Target;
  ChangedTarget.RequiredAdapterID := 'adapter-A';
  ChangedAdapter := MakeAdapter;
  ChangedAdapter.IdentityVerified := False;
  Report := EvaluateElectricalPreflight(Programmer, ChangedAdapter,
                                        ChangedTarget, Observation, Policy);
  CheckBlockedBy(Report, piAdapterIdentityUnverified,
                 'unauthenticated adapter identity is blocked');

  ChangedAdapter := MakeAdapter;
  ChangedAdapter.MaxBusHz[spSPI] := 0;
  Report := EvaluateElectricalPreflight(Programmer, ChangedAdapter,
                                        ChangedTarget, Observation, Policy);
  CheckBlockedBy(Report, piAdapterCapabilitiesInvalid,
                 'malformed adapter capabilities fail closed');

  ChangedObservation := Observation;
  ChangedObservation.EffectiveTargetVioMv := 5000;
  Report := EvaluateElectricalPreflight(Programmer, Adapter, Target,
                                        ChangedObservation, Policy);
  CheckBlockedBy(Report, piSignalVoltageTooHigh,
                 'excessive target signal voltage is blocked');

  ChangedObservation := Observation;
  ChangedObservation.ExternalPowerPresent := True;
  ChangedTarget := Target;
  ChangedTarget.AllowsExternalPower := True;
  Report := EvaluateElectricalPreflight(Programmer, Adapter, ChangedTarget,
                                        ChangedObservation, Policy);
  CheckBlockedBy(Report, piPowerSourceContention,
                 'simultaneous power sources are blocked');

  ChangedObservation := Observation;
  ChangedObservation.TargetPowerEnabled := False;
  ChangedObservation.ExternalPowerPresent := True;
  ChangedObservation.ExternalPowerCurrentLimited := False;
  ChangedTarget := Target;
  ChangedTarget.AllowsExternalPower := True;
  Report := EvaluateElectricalPreflight(Programmer, Adapter, ChangedTarget,
                                        ChangedObservation, Policy);
  CheckBlockedBy(Report, piExternalPowerCurrentLimitUnavailable,
                 'unlimited external target supply is blocked');
  ChangedObservation.ExternalPowerCurrentLimited := True;
  ChangedProgrammer := Programmer;
  ChangedProgrammer.HasCurrentLimit := False;
  Report := EvaluateElectricalPreflight(ChangedProgrammer, Adapter,
                                        ChangedTarget, ChangedObservation,
                                        Policy);
  Check(Report.Allowed,
        'confirmed external supply limit replaces programmer power limit');

  ChangedObservation := Observation;
  ChangedObservation.CurrentLimitEnabled := False;
  Report := EvaluateElectricalPreflight(Programmer, Adapter, Target,
                                        ChangedObservation, Policy);
  CheckBlockedBy(Report, piCurrentLimitNotEnabled,
                 'disabled hardware current limit is blocked');

  ChangedObservation := Observation;
  ChangedObservation.RequestedBusHz := Target.MaxBusHz + 1;
  Report := EvaluateElectricalPreflight(Programmer, Adapter, Target,
                                        ChangedObservation, Policy);
  CheckBlockedBy(Report, piBusFrequencyTooHigh,
                 'excessive requested bus frequency is blocked');

  ChangedProgrammer := Programmer;
  ChangedProgrammer.SupportsOpenDrain := False;
  ChangedTarget := Target;
  ChangedTarget.RequiresOpenDrain := True;
  Report := EvaluateElectricalPreflight(ChangedProgrammer, Adapter,
                                        ChangedTarget, Observation, Policy);
  CheckBlockedBy(Report, piOpenDrainUnavailable,
                 'missing required open-drain drive is blocked');

  ChangedObservation := Observation;
  ChangedObservation.ExternalPowerKnown := False;
  Report := EvaluateElectricalPreflight(Programmer, Adapter, Target,
                                        ChangedObservation, Policy);
  CheckBlockedBy(Report, piExternalPowerStateUnknown,
                 'unknown external-power state is blocked');

  ChangedObservation := Observation;
  ChangedObservation.TargetVoltageMeasured := False;
  Report := EvaluateElectricalPreflight(Programmer, Adapter, Target,
                                        ChangedObservation, Policy);
  CheckBlockedBy(Report, piTargetVoltageNotMeasured,
                 'unmeasured destructive-operation voltage is blocked');

  ChangedTarget := Target;
  ChangedTarget.RequiredProgrammerID := 'none';
  Check(not ValidateTargetRequirements(ChangedTarget, ErrMsg),
        'target cannot request a nonexistent programmer');
end;

procedure TestProductionGate(const Directory: string);
var
  Key, WrongKey, ChipDefinition, Image, ChangedImage: TBytes;
  Programmer: TProgrammerElectricalCapabilities;
  Adapter: TAdapterElectricalCapabilities;
  Observation, ChangedObservation: TElectricalObservation;
  Job: TProductionJob;
  ImageStream: TFileStream;
  Report: TPreflightReport;
  Failure: TProductionAdmissionFailure;
  ErrMsg, ManifestFile, AuthFile, ImageFile: string;
begin
  ManifestFile := IncludeTrailingPathDelimiter(Directory) + 'job.apjob';
  AuthFile := IncludeTrailingPathDelimiter(Directory) + 'job.auth';
  ImageFile := IncludeTrailingPathDelimiter(Directory) + 'firmware.bin';
  Key := MakeKey(1);
  WrongKey := MakeKey(91);
  ChipDefinition := StringBytes('abc');
  Image := StringBytes('PROD1234');
  Programmer := MakeProgrammer;
  Adapter := MakeNoAdapter;
  Observation := MakeObservation;

  ImageStream := nil;
  Check(AdmitHMACProductionJob(ManifestFile, AuthFile, 'factory-key-2026',
        Key, 1800000000, ChipDefinition, Programmer, Adapter, Observation,
        Job, ImageStream, Report, Failure, ErrMsg),
        'aggregate production gate admits fully verified inputs', ErrMsg);
  Check((Failure = pafNone) and Report.Allowed and
        (ImageStream <> nil) and (ImageStream.Position = 0),
        'successful production gate returns typed state and retained image');
  ImageStream.Free;

  ImageStream := nil;
  Check(not AdmitHMACProductionJob(ManifestFile, AuthFile, 'factory-key-2026',
        WrongKey, 1800000000, ChipDefinition, Programmer, Adapter, Observation,
        Job, ImageStream, Report, Failure, ErrMsg),
        'aggregate production gate rejects wrong authentication key');
  Check((Failure = pafJobAuthentication) and (ImageStream = nil) and
        (Job.Version = 0),
        'authentication failure is typed and clears all admitted state');

  ImageStream := nil;
  Check(not AdmitHMACProductionJob(ManifestFile, AuthFile, 'factory-key-2026',
        Key, 1800000000, StringBytes('abd'), Programmer, Adapter, Observation,
        Job, ImageStream, Report, Failure, ErrMsg),
        'aggregate production gate rejects wrong chip definition');
  Check((Failure = pafChipDefinitionIntegrity) and (ImageStream = nil) and
        (Job.Version = 0),
        'chip-definition failure is typed and clears all admitted state');

  ChangedImage := StringBytes('PROD123X');
  WriteBytes(ImageFile, ChangedImage);
  ImageStream := nil;
  Check(not AdmitHMACProductionJob(ManifestFile, AuthFile, 'factory-key-2026',
        Key, 1800000000, ChipDefinition, Programmer, Adapter, Observation,
        Job, ImageStream, Report, Failure, ErrMsg),
        'aggregate production gate rejects changed image');
  Check((Failure = pafImageIntegrity) and (ImageStream = nil) and
        (Job.Version = 0),
        'image-integrity failure is typed and clears all admitted state');
  WriteBytes(ImageFile, Image);

  ChangedObservation := Observation;
  ChangedObservation.RequestedBusHz := 11000000;
  ImageStream := nil;
  Check(not AdmitHMACProductionJob(ManifestFile, AuthFile, 'factory-key-2026',
        Key, 1800000000, ChipDefinition, Programmer, Adapter,
        ChangedObservation, Job, ImageStream, Report, Failure, ErrMsg),
        'aggregate production gate rejects unsafe live electrical state');
  Check((Failure = pafElectricalPreflight) and (ImageStream = nil) and
        (Job.Version = 0) and HasIssue(Report, piBusFrequencyTooHigh),
        'electrical failure is typed, detailed, and clears admitted state');

  Check(ProductionAdmissionFailureName(pafElectricalPreflight) =
        'electrical_preflight',
        'production admission failure has stable evidence name');
  ClearSensitiveBytes(Key);
  ClearSensitiveBytes(WrongKey);
end;

var
  TestDirectory: string;
begin
  TestDirectory := MakeTempDirectory;
  try
    TestCrypto;
    TestJobsAndImages(TestDirectory);
    TestEvidence(TestDirectory);
    TestSignedEvidence(TestDirectory);
    TestProductionState(TestDirectory);
    TestElectricalPreflight;
    TestProductionGate(TestDirectory);
  finally
    DeleteKnownFiles(TestDirectory);
  end;
  TestDirectory := '';

  if ChecksFailed = 0 then
  begin
    WriteLn('PASS: ', ChecksRun, ' stage-9 foundation checks');
    ExitCode := 0;
  end;
  if ChecksFailed <> 0 then
  begin
    WriteLn('FAIL: ', ChecksFailed, ' of ', ChecksRun, ' checks failed');
    ExitCode := 1;
  end;
end.
