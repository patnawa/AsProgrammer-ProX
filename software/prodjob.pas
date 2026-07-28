unit prodjob;

// Strict, versioned production-job manifests and detached authentication.
//
// A manifest parsed by ParseProductionJob is still untrusted.  Production
// callers must enter through LoadAuthenticatedProductionJob (or explicitly
// call VerifyDetachedJobAuth) before using any field.  Authentication is
// HMAC-SHA-256 through the operating-system CNG provider; no cryptographic
// primitive is implemented in this project.
//
// The manifest is deliberately canonical: fixed field order, ASCII, LF line
// endings, decimal integers without leading zeroes, and uppercase hashes.
// That gives every station exactly one byte representation to authenticate.
// See docs/production-job-security.md for the trust and key-management model.

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, prodcrypto, electricalpreflight;

const
  PRODUCTION_JOB_FORMAT = 'AsProgrammer-ProX/job';
  PRODUCTION_JOB_VERSION = 1;
  PRODUCTION_JOB_AUTH_FORMAT = 'AsProgrammer-ProX/job-auth';
  PRODUCTION_JOB_AUTH_VERSION = 1;
  PRODUCTION_JOB_AUTH_ALGORITHM = 'HMAC-SHA256';
  MAX_PRODUCTION_JOB_BYTES = 16 * 1024;
  MAX_PRODUCTION_AUTH_BYTES = 4 * 1024;

type
  TProductionVerifyMode = (pvmFull);

  TProductionJob = record
    Version: cardinal;
    JobID: string;
    Revision: cardinal;
    CreatedUTC: QWord; // inclusive Unix time in seconds
    ExpiresUTC: QWord; // inclusive Unix time in seconds

    Protocol: TSerialProtocol;
    ChipName: string;
    ChipID: string; // uppercase hex, or "none"
    ChipSize: QWord;
    ChipDefinitionSHA256: string;

    ImageFile: string; // a safe sibling basename, never a path
    ImageSize: QWord;
    ImageSHA256: string;
    StartAddress: QWord;
    WriteLength: QWord;

    VccMinMv: cardinal;
    VccMaxMv: cardinal;
    VioMaxMv: cardinal;
    MaxBusHz: cardinal;
    OpenDrainRequired: boolean;
    ExternalPowerAllowed: boolean;

    ReadPasses: cardinal;
    BackupRequired: boolean;
    UIDRequired: boolean;
    RequiredProgrammerID: string; // exact ID, or "any"
    RequiredAdapterID: string;    // exact ID, "any", or "none"
    VerifyMode: TProductionVerifyMode;
  end;

  TDetachedJobAuth = record
    Version: cardinal;
    Algorithm: string;
    KeyID: string;
    ManifestSHA256: string;
    MAC: string;
  end;

// Clears all fields to a non-valid state.  Useful for fail-closed APIs that
// must never expose a partially admitted job on error.
procedure ClearProductionJob(out Job: TProductionJob);

// Canonical serialization.  These functions do not imply that Job/Auth has
// been validated; producers should validate or use CreateDetachedJobAuth.
function CanonicalProductionJobBytes(const Job: TProductionJob): TBytes;
function CanonicalDetachedJobAuthBytes(const Auth: TDetachedJobAuth): TBytes;

function ValidateProductionJob(const Job: TProductionJob;
  out ErrMsg: string): boolean;
function ParseProductionJob(const Data: TBytes; out Job: TProductionJob;
  out ErrMsg: string): boolean;

function CreateDetachedJobAuth(const Job: TProductionJob;
  const KeyID: string; const Key: TBytes; out Auth: TDetachedJobAuth;
  out ErrMsg: string): boolean;
function ParseDetachedJobAuth(const Data: TBytes; out Auth: TDetachedJobAuth;
  out ErrMsg: string): boolean;
function VerifyDetachedJobAuth(const Job: TProductionJob;
  const Auth: TDetachedJobAuth; const ExpectedKeyID: string;
  const Key: TBytes; VerificationUTC: QWord; out ErrMsg: string): boolean;

// This is the safe production entry point: both files are read without write
// sharing, parsed canonically, and authenticated before Job is returned.
function LoadAuthenticatedProductionJob(const ManifestFile, AuthFile,
  ExpectedKeyID: string; const Key: TBytes; VerificationUTC: QWord;
  out Job: TProductionJob; out ErrMsg: string): boolean;

// Opens the safe sibling image with write/delete sharing denied, verifies size
// and SHA-256 on that same handle, rewinds it, and transfers ownership of the
// still-open stream to the caller.  The operation engine must consume this
// stream rather than reopen ResolvedFile, which would create a TOCTOU gap.
function OpenVerifiedProductionImage(const Job: TProductionJob;
  const ManifestDirectory: string; out ImageStream: TFileStream;
  out ResolvedFile: string; out ErrMsg: string): boolean;

// Convenience check for tooling.  Production programming should use
// OpenVerifiedProductionImage and retain its returned stream through use.
function VerifyProductionImage(const Job: TProductionJob;
  const ManifestDirectory: string; out ResolvedFile: string;
  out ErrMsg: string): boolean;

// ChipDefinitionBytes must be the exact canonical bytes used by the operation
// engine (not a display name or a reconstructed subset of the definition).
function VerifyChipDefinitionBytes(const Job: TProductionJob;
  const ChipDefinitionBytes: TBytes; out ErrMsg: string): boolean;

function JobToElectricalRequirements(const Job: TProductionJob):
  TTargetElectricalRequirements;

implementation

const
  JOB_FIELD_COUNT = 28;
  JOB_KEYS: array[0..JOB_FIELD_COUNT - 1] of string = (
    'format',
    'version',
    'job_id',
    'revision',
    'created_utc',
    'expires_utc',
    'protocol',
    'chip_name',
    'chip_id',
    'chip_size',
    'chip_definition_sha256',
    'image_file',
    'image_size',
    'image_sha256',
    'start_address',
    'write_length',
    'vcc_min_mv',
    'vcc_max_mv',
    'vio_max_mv',
    'max_bus_hz',
    'open_drain_required',
    'external_power_allowed',
    'read_passes',
    'backup_required',
    'uid_required',
    'programmer_id',
    'adapter_id',
    'verify'
  );

  AUTH_FIELD_COUNT = 6;
  AUTH_KEYS: array[0..AUTH_FIELD_COUNT - 1] of string = (
    'format',
    'version',
    'algorithm',
    'key_id',
    'manifest_sha256',
    'mac'
  );

  AUTH_DOMAIN = 'AsProgrammer-ProX/job-auth/v1';

type
  TStringArray = array of string;

procedure ClearProductionJob(out Job: TProductionJob);
begin
  Job.Version := 0;
  Job.JobID := '';
  Job.Revision := 0;
  Job.CreatedUTC := 0;
  Job.ExpiresUTC := 0;
  Job.Protocol := spSPI;
  Job.ChipName := '';
  Job.ChipID := '';
  Job.ChipSize := 0;
  Job.ChipDefinitionSHA256 := '';
  Job.ImageFile := '';
  Job.ImageSize := 0;
  Job.ImageSHA256 := '';
  Job.StartAddress := 0;
  Job.WriteLength := 0;
  Job.VccMinMv := 0;
  Job.VccMaxMv := 0;
  Job.VioMaxMv := 0;
  Job.MaxBusHz := 0;
  Job.OpenDrainRequired := False;
  Job.ExternalPowerAllowed := False;
  Job.ReadPasses := 0;
  Job.BackupRequired := False;
  Job.UIDRequired := False;
  Job.RequiredProgrammerID := '';
  Job.RequiredAdapterID := '';
  Job.VerifyMode := pvmFull;
end;

procedure ResetAuth(out Auth: TDetachedJobAuth);
begin
  Auth.Version := 0;
  Auth.Algorithm := '';
  Auth.KeyID := '';
  Auth.ManifestSHA256 := '';
  Auth.MAC := '';
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

function BoolText(Value: boolean): string;
begin
  if Value then Result := '1' else Result := '0';
end;

function ProtocolText(Value: TSerialProtocol): string;
begin
  case Value of
    spSPI: Result := 'spi';
    spI2C: Result := 'i2c';
    spMicrowire: Result := 'microwire';
  end;
end;

function VerifyModeText(Value: TProductionVerifyMode): string;
begin
  case Value of
    pvmFull: Result := 'full';
  end;
end;

function RawStringBytes(const Value: RawByteString): TBytes;
begin
  Result := nil;
  SetLength(Result, Length(Value));
  if Length(Value) > 0 then Move(Value[1], Result[0], Length(Value));
end;

function BytesEqual(const A, B: TBytes): boolean;
var
  i: integer;
begin
  if Length(A) <> Length(B) then Exit(False);
  for i := 0 to High(A) do
    if A[i] <> B[i] then Exit(False);
  Result := True;
end;

function CanonicalProductionJobBytes(const Job: TProductionJob): TBytes;
var
  Text: RawByteString;
begin
  Text :=
    'format=' + PRODUCTION_JOB_FORMAT + #10 +
    'version=' + UIntText(Job.Version) + #10 +
    'job_id=' + Job.JobID + #10 +
    'revision=' + UIntText(Job.Revision) + #10 +
    'created_utc=' + UIntText(Job.CreatedUTC) + #10 +
    'expires_utc=' + UIntText(Job.ExpiresUTC) + #10 +
    'protocol=' + ProtocolText(Job.Protocol) + #10 +
    'chip_name=' + Job.ChipName + #10 +
    'chip_id=' + Job.ChipID + #10 +
    'chip_size=' + UIntText(Job.ChipSize) + #10 +
    'chip_definition_sha256=' + Job.ChipDefinitionSHA256 + #10 +
    'image_file=' + Job.ImageFile + #10 +
    'image_size=' + UIntText(Job.ImageSize) + #10 +
    'image_sha256=' + Job.ImageSHA256 + #10 +
    'start_address=' + UIntText(Job.StartAddress) + #10 +
    'write_length=' + UIntText(Job.WriteLength) + #10 +
    'vcc_min_mv=' + UIntText(Job.VccMinMv) + #10 +
    'vcc_max_mv=' + UIntText(Job.VccMaxMv) + #10 +
    'vio_max_mv=' + UIntText(Job.VioMaxMv) + #10 +
    'max_bus_hz=' + UIntText(Job.MaxBusHz) + #10 +
    'open_drain_required=' + BoolText(Job.OpenDrainRequired) + #10 +
    'external_power_allowed=' + BoolText(Job.ExternalPowerAllowed) + #10 +
    'read_passes=' + UIntText(Job.ReadPasses) + #10 +
    'backup_required=' + BoolText(Job.BackupRequired) + #10 +
    'uid_required=' + BoolText(Job.UIDRequired) + #10 +
    'programmer_id=' + Job.RequiredProgrammerID + #10 +
    'adapter_id=' + Job.RequiredAdapterID + #10 +
    'verify=' + VerifyModeText(Job.VerifyMode) + #10;
  Result := RawStringBytes(Text);
end;

function CanonicalDetachedJobAuthBytes(const Auth: TDetachedJobAuth): TBytes;
var
  Text: RawByteString;
begin
  Text :=
    'format=' + PRODUCTION_JOB_AUTH_FORMAT + #10 +
    'version=' + UIntText(Auth.Version) + #10 +
    'algorithm=' + Auth.Algorithm + #10 +
    'key_id=' + Auth.KeyID + #10 +
    'manifest_sha256=' + Auth.ManifestSHA256 + #10 +
    'mac=' + Auth.MAC + #10;
  Result := RawStringBytes(Text);
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

function StrictBoolean(const Value: string; out Flag: boolean): boolean;
begin
  Result := True;
  if Value = '0' then Flag := False
  else if Value = '1' then Flag := True
  else
  begin
    Flag := False;
    Result := False;
  end;
end;

function ValidIdentifier(const Value: string; AllowSpecial: boolean): boolean;
var
  i: integer;
begin
  Result := False;
  if (Length(Value) < 1) or (Length(Value) > 96) then Exit;
  if AllowSpecial and ((Value = 'any') or (Value = 'none')) then Exit(True);
  for i := 1 to Length(Value) do
    if not (Value[i] in
      ['A'..'Z', 'a'..'z', '0'..'9', '.', '_', '-', '+']) then Exit;
  Result := True;
end;

function IsReservedWindowsBasename(const Value: string): boolean;
var
  Base, Upper: string;
  DotAt: SizeInt;
begin
  DotAt := Pos('.', Value);
  if DotAt > 0 then Base := Copy(Value, 1, DotAt - 1)
  else Base := Value;
  Upper := UpperCase(Base);
  Result := (Upper = 'CON') or (Upper = 'PRN') or (Upper = 'AUX') or
            (Upper = 'NUL') or (Upper = 'CLOCK$') or
            ((Length(Upper) = 4) and
             ((Copy(Upper, 1, 3) = 'COM') or
              (Copy(Upper, 1, 3) = 'LPT')) and
             (Upper[4] in ['1'..'9']));
end;

function ValidImageBasename(const Value: string): boolean;
var
  i: integer;
begin
  Result := False;
  if (Length(Value) < 1) or (Length(Value) > 128) then Exit;
  if (Value[1] = '.') or (Value[Length(Value)] = '.') or
     (Pos('..', Value) > 0) then Exit;
  for i := 1 to Length(Value) do
    if not (Value[i] in
      ['A'..'Z', 'a'..'z', '0'..'9', '.', '_', '-']) then Exit;
  if IsReservedWindowsBasename(Value) then Exit;
  Result := True;
end;

function ValidUpperHex(const Value: string; MinimumBytes,
  MaximumBytes: cardinal): boolean;
var
  i: integer;
begin
  Result := False;
  if ((Length(Value) and 1) <> 0) or
     (Length(Value) < integer(MinimumBytes * 2)) or
     (Length(Value) > integer(MaximumBytes * 2)) then Exit;
  for i := 1 to Length(Value) do
    if not (Value[i] in ['0'..'9', 'A'..'F']) then Exit;
  Result := True;
end;

function ValidDigestText(const Value: string): boolean;
var
  Digest: TSHA256Digest;
begin
  Result := (Length(Value) = SHA256_HEX_CHARS) and
            (Value = UpperCase(Value)) and HexToDigest(Value, Digest);
end;

function ParseFixedFields(const Data: TBytes; MaximumBytes: integer;
  const ExpectedKeys: array of string; out Values: TStringArray;
  out ErrMsg: string): boolean;
var
  i, LineStart, LineNumber, EqualsAt: integer;
  Line, Key, Value: string;
begin
  Result := False;
  SetLength(Values, 0);
  ErrMsg := '';
  if (Length(Data) = 0) or (Length(Data) > MaximumBytes) then
  begin
    ErrMsg := Format('file size must be 1..%d bytes', [MaximumBytes]);
    Exit;
  end;
  if Data[High(Data)] <> 10 then
  begin
    ErrMsg := 'canonical file must end with an LF';
    Exit;
  end;
  for i := 0 to High(Data) do
    if (Data[i] <> 10) and ((Data[i] < 32) or (Data[i] > 126)) then
    begin
      ErrMsg := Format('non-canonical byte at offset %d', [i]);
      Exit;
    end;

  SetLength(Values, Length(ExpectedKeys));
  LineStart := 0;
  LineNumber := 0;
  for i := 0 to High(Data) do
    if Data[i] = 10 then
    begin
      if LineNumber >= Length(ExpectedKeys) then
      begin
        ErrMsg := 'file contains too many fields';
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
      if Key <> ExpectedKeys[LineNumber] then
      begin
        ErrMsg := Format('expected field "%s", found "%s"',
                         [ExpectedKeys[LineNumber], Key]);
        Exit;
      end;
      Values[LineNumber] := Value;
      Inc(LineNumber);
      LineStart := i + 1;
    end;
  if LineNumber <> Length(ExpectedKeys) then
  begin
    ErrMsg := Format('file contains %d fields; expected %d',
                     [LineNumber, Length(ExpectedKeys)]);
    Exit;
  end;
  Result := True;
end;

function ValidateProductionJob(const Job: TProductionJob;
  out ErrMsg: string): boolean;
begin
  Result := False;
  ErrMsg := '';
  if Job.Version <> PRODUCTION_JOB_VERSION then
  begin
    ErrMsg := 'unsupported production-job version';
    Exit;
  end;
  if not ValidIdentifier(Job.JobID, False) then
  begin
    ErrMsg := 'invalid job ID';
    Exit;
  end;
  if Job.Revision = 0 then
  begin
    ErrMsg := 'job revision must be greater than zero';
    Exit;
  end;
  if (Job.CreatedUTC = 0) or (Job.ExpiresUTC <= Job.CreatedUTC) then
  begin
    ErrMsg := 'job time window is invalid';
    Exit;
  end;
  if not ValidIdentifier(Job.ChipName, False) then
  begin
    ErrMsg := 'invalid chip name';
    Exit;
  end;
  if (Job.ChipID <> 'none') and
     (not ValidUpperHex(Job.ChipID, 1, 64)) then
  begin
    ErrMsg := 'chip ID must be "none" or 1..64 bytes of uppercase hex';
    Exit;
  end;
  if Job.ChipSize = 0 then
  begin
    ErrMsg := 'chip size must be greater than zero';
    Exit;
  end;
  if not ValidDigestText(Job.ChipDefinitionSHA256) then
  begin
    ErrMsg := 'invalid chip-definition SHA-256';
    Exit;
  end;
  if not ValidImageBasename(Job.ImageFile) then
  begin
    ErrMsg := 'image file must be a safe sibling basename';
    Exit;
  end;
  if Job.ImageSize = 0 then
  begin
    ErrMsg := 'image size must be greater than zero';
    Exit;
  end;
  if not ValidDigestText(Job.ImageSHA256) then
  begin
    ErrMsg := 'invalid image SHA-256';
    Exit;
  end;
  if (Job.StartAddress >= Job.ChipSize) or
     (Job.WriteLength = 0) or
     (Job.WriteLength > Job.ChipSize - Job.StartAddress) then
  begin
    ErrMsg := 'write range is empty or outside the declared chip';
    Exit;
  end;
  if Job.ImageSize <> Job.WriteLength then
  begin
    ErrMsg := 'image size must equal write length';
    Exit;
  end;
  if (Job.VccMinMv < 500) or (Job.VccMaxMv > 6000) or
     (Job.VccMinMv > Job.VccMaxMv) then
  begin
    ErrMsg := 'target VCC range must be within 500..6000 mV';
    Exit;
  end;
  if (Job.VioMaxMv < 500) or (Job.VioMaxMv > 6000) then
  begin
    ErrMsg := 'target signal-voltage maximum must be within 500..6000 mV';
    Exit;
  end;
  if (Job.MaxBusHz = 0) or (Job.MaxBusHz > 200000000) then
  begin
    ErrMsg := 'maximum bus frequency must be within 1..200000000 Hz';
    Exit;
  end;
  if (Job.Protocol = spI2C) and (not Job.OpenDrainRequired) then
  begin
    ErrMsg := 'I2C production jobs must require open-drain signalling';
    Exit;
  end;
  if (Job.ReadPasses < 2) or (Job.ReadPasses > 16) then
  begin
    ErrMsg := 'read-pass count must be within 2..16';
    Exit;
  end;
  if not ValidIdentifier(Job.RequiredProgrammerID, True) or
     (Job.RequiredProgrammerID = 'none') then
  begin
    ErrMsg := 'invalid required programmer ID';
    Exit;
  end;
  if not ValidIdentifier(Job.RequiredAdapterID, True) then
  begin
    ErrMsg := 'invalid required adapter ID';
    Exit;
  end;
  if Job.VerifyMode <> pvmFull then
  begin
    ErrMsg := 'production jobs require full verification';
    Exit;
  end;
  Result := True;
end;

function ParseProductionJob(const Data: TBytes; out Job: TProductionJob;
  out ErrMsg: string): boolean;
var
  Values: TStringArray;
  Canonical: TBytes;
begin
  Result := False;
  ClearProductionJob(Job);
  if not ParseFixedFields(Data, MAX_PRODUCTION_JOB_BYTES, JOB_KEYS,
                          Values, ErrMsg) then Exit;
  if Values[0] <> PRODUCTION_JOB_FORMAT then
  begin
    ErrMsg := 'unsupported production-job format';
    Exit;
  end;
  if not StrictCardinal(Values[1], Job.Version) then
  begin
    ErrMsg := 'invalid production-job version';
    Exit;
  end;
  Job.JobID := Values[2];
  if not StrictCardinal(Values[3], Job.Revision) then
  begin
    ErrMsg := 'invalid job revision';
    Exit;
  end;
  if not StrictQWord(Values[4], Job.CreatedUTC) then
  begin
    ErrMsg := 'invalid creation timestamp';
    Exit;
  end;
  if not StrictQWord(Values[5], Job.ExpiresUTC) then
  begin
    ErrMsg := 'invalid expiry timestamp';
    Exit;
  end;
  if Values[6] = 'spi' then Job.Protocol := spSPI
  else if Values[6] = 'i2c' then Job.Protocol := spI2C
  else if Values[6] = 'microwire' then Job.Protocol := spMicrowire
  else
  begin
    ErrMsg := 'unsupported serial-memory protocol';
    Exit;
  end;
  Job.ChipName := Values[7];
  Job.ChipID := Values[8];
  if not StrictQWord(Values[9], Job.ChipSize) then
  begin
    ErrMsg := 'invalid chip size';
    Exit;
  end;
  Job.ChipDefinitionSHA256 := Values[10];
  Job.ImageFile := Values[11];
  if not StrictQWord(Values[12], Job.ImageSize) then
  begin
    ErrMsg := 'invalid image size';
    Exit;
  end;
  Job.ImageSHA256 := Values[13];
  if not StrictQWord(Values[14], Job.StartAddress) then
  begin
    ErrMsg := 'invalid start address';
    Exit;
  end;
  if not StrictQWord(Values[15], Job.WriteLength) then
  begin
    ErrMsg := 'invalid write length';
    Exit;
  end;
  if not StrictCardinal(Values[16], Job.VccMinMv) then
  begin
    ErrMsg := 'invalid minimum VCC';
    Exit;
  end;
  if not StrictCardinal(Values[17], Job.VccMaxMv) then
  begin
    ErrMsg := 'invalid maximum VCC';
    Exit;
  end;
  if not StrictCardinal(Values[18], Job.VioMaxMv) then
  begin
    ErrMsg := 'invalid maximum signal voltage';
    Exit;
  end;
  if not StrictCardinal(Values[19], Job.MaxBusHz) then
  begin
    ErrMsg := 'invalid maximum bus frequency';
    Exit;
  end;
  if not StrictBoolean(Values[20], Job.OpenDrainRequired) then
  begin
    ErrMsg := 'open-drain requirement must be 0 or 1';
    Exit;
  end;
  if not StrictBoolean(Values[21], Job.ExternalPowerAllowed) then
  begin
    ErrMsg := 'external-power permission must be 0 or 1';
    Exit;
  end;
  if not StrictCardinal(Values[22], Job.ReadPasses) then
  begin
    ErrMsg := 'invalid read-pass count';
    Exit;
  end;
  if not StrictBoolean(Values[23], Job.BackupRequired) then
  begin
    ErrMsg := 'backup requirement must be 0 or 1';
    Exit;
  end;
  if not StrictBoolean(Values[24], Job.UIDRequired) then
  begin
    ErrMsg := 'UID requirement must be 0 or 1';
    Exit;
  end;
  Job.RequiredProgrammerID := Values[25];
  Job.RequiredAdapterID := Values[26];
  if Values[27] = 'full' then Job.VerifyMode := pvmFull
  else
  begin
    ErrMsg := 'unsupported verification mode';
    Exit;
  end;

  if not ValidateProductionJob(Job, ErrMsg) then Exit;
  Canonical := CanonicalProductionJobBytes(Job);
  if not BytesEqual(Data, Canonical) then
  begin
    ErrMsg := 'production job is not in canonical byte form';
    Exit;
  end;
  Result := True;
end;

function BuildAuthInput(const Job: TProductionJob; const KeyID: string):
  TBytes;
var
  Prefix: TBytes;
  Manifest: TBytes;
  PrefixText: RawByteString;
begin
  Result := nil;
  PrefixText := AUTH_DOMAIN + #0 + KeyID + #0;
  Prefix := RawStringBytes(PrefixText);
  Manifest := CanonicalProductionJobBytes(Job);
  SetLength(Result, Length(Prefix) + Length(Manifest));
  if Length(Prefix) > 0 then Move(Prefix[0], Result[0], Length(Prefix));
  if Length(Manifest) > 0 then
    Move(Manifest[0], Result[Length(Prefix)], Length(Manifest));
end;

function CreateDetachedJobAuth(const Job: TProductionJob;
  const KeyID: string; const Key: TBytes; out Auth: TDetachedJobAuth;
  out ErrMsg: string): boolean;
var
  Manifest, MACInput: TBytes;
  Digest, MACDigest: TSHA256Digest;
begin
  Result := False;
  ResetAuth(Auth);
  if not ValidateProductionJob(Job, ErrMsg) then Exit;
  if not ValidIdentifier(KeyID, False) then
  begin
    ErrMsg := 'invalid authentication key ID';
    Exit;
  end;
  Manifest := CanonicalProductionJobBytes(Job);
  if not SHA256Bytes(Manifest, Digest, ErrMsg) then Exit;
  MACInput := BuildAuthInput(Job, KeyID);
  if not HMACSHA256(Key, MACInput, MACDigest, ErrMsg) then Exit;

  Auth.Version := PRODUCTION_JOB_AUTH_VERSION;
  Auth.Algorithm := PRODUCTION_JOB_AUTH_ALGORITHM;
  Auth.KeyID := KeyID;
  Auth.ManifestSHA256 := DigestToHex(Digest);
  Auth.MAC := DigestToHex(MACDigest);
  Result := True;
end;

function ParseDetachedJobAuth(const Data: TBytes; out Auth: TDetachedJobAuth;
  out ErrMsg: string): boolean;
var
  Values: TStringArray;
  Canonical: TBytes;
begin
  Result := False;
  ResetAuth(Auth);
  if not ParseFixedFields(Data, MAX_PRODUCTION_AUTH_BYTES, AUTH_KEYS,
                          Values, ErrMsg) then Exit;
  if Values[0] <> PRODUCTION_JOB_AUTH_FORMAT then
  begin
    ErrMsg := 'unsupported production-job authentication format';
    Exit;
  end;
  if not StrictCardinal(Values[1], Auth.Version) or
     (Auth.Version <> PRODUCTION_JOB_AUTH_VERSION) then
  begin
    ErrMsg := 'unsupported production-job authentication version';
    Exit;
  end;
  Auth.Algorithm := Values[2];
  if Auth.Algorithm <> PRODUCTION_JOB_AUTH_ALGORITHM then
  begin
    ErrMsg := 'unsupported production-job authentication algorithm';
    Exit;
  end;
  Auth.KeyID := Values[3];
  if not ValidIdentifier(Auth.KeyID, False) then
  begin
    ErrMsg := 'invalid authentication key ID';
    Exit;
  end;
  Auth.ManifestSHA256 := Values[4];
  if not ValidDigestText(Auth.ManifestSHA256) then
  begin
    ErrMsg := 'invalid authenticated manifest SHA-256';
    Exit;
  end;
  Auth.MAC := Values[5];
  if not ValidDigestText(Auth.MAC) then
  begin
    ErrMsg := 'invalid authentication MAC';
    Exit;
  end;
  Canonical := CanonicalDetachedJobAuthBytes(Auth);
  if not BytesEqual(Data, Canonical) then
  begin
    ErrMsg := 'authentication file is not in canonical byte form';
    Exit;
  end;
  Result := True;
end;

function VerifyDetachedJobAuth(const Job: TProductionJob;
  const Auth: TDetachedJobAuth; const ExpectedKeyID: string;
  const Key: TBytes; VerificationUTC: QWord; out ErrMsg: string): boolean;
var
  Manifest, MACInput: TBytes;
  ManifestDigest, DeclaredDigest, CalculatedMAC, DeclaredMAC: TSHA256Digest;
begin
  Result := False;
  ErrMsg := '';
  if not ValidateProductionJob(Job, ErrMsg) then Exit;
  if (Auth.Version <> PRODUCTION_JOB_AUTH_VERSION) or
     (Auth.Algorithm <> PRODUCTION_JOB_AUTH_ALGORITHM) or
     (not ValidIdentifier(Auth.KeyID, False)) or
     (not ValidDigestText(Auth.ManifestSHA256)) or
     (not ValidDigestText(Auth.MAC)) then
  begin
    ErrMsg := 'authentication record is invalid';
    Exit;
  end;
  if not ValidIdentifier(ExpectedKeyID, False) then
  begin
    ErrMsg := 'expected authentication key ID is invalid';
    Exit;
  end;
  if Auth.KeyID <> ExpectedKeyID then
  begin
    ErrMsg := 'authentication key ID is not the configured production key';
    Exit;
  end;
  if (VerificationUTC < Job.CreatedUTC) or
     (VerificationUTC > Job.ExpiresUTC) then
  begin
    ErrMsg := 'production job is not valid at the supplied UTC time';
    Exit;
  end;

  Manifest := CanonicalProductionJobBytes(Job);
  if not SHA256Bytes(Manifest, ManifestDigest, ErrMsg) then Exit;
  if not HexToDigest(Auth.ManifestSHA256, DeclaredDigest) or
     (not DigestEqualConstantTime(ManifestDigest, DeclaredDigest)) then
  begin
    ErrMsg := 'authenticated manifest SHA-256 does not match the job';
    Exit;
  end;

  MACInput := BuildAuthInput(Job, Auth.KeyID);
  if not HMACSHA256(Key, MACInput, CalculatedMAC, ErrMsg) then Exit;
  if not HexToDigest(Auth.MAC, DeclaredMAC) or
     (not DigestEqualConstantTime(CalculatedMAC, DeclaredMAC)) then
  begin
    ErrMsg := 'production-job authentication failed';
    Exit;
  end;
  Result := True;
end;

function ReadSmallFile(const FileName: string; MaximumBytes: integer;
  out Data: TBytes; out ErrMsg: string): boolean;
var
  Stream: TFileStream;
  Got: LongInt;
begin
  Result := False;
  SetLength(Data, 0);
  ErrMsg := '';
  try
    Stream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
    try
      if (Stream.Size < 1) or (Stream.Size > MaximumBytes) then
      begin
        ErrMsg := Format('"%s" must be 1..%d bytes',
                         [FileName, MaximumBytes]);
        Exit;
      end;
      SetLength(Data, Stream.Size);
      Got := Stream.Read(Data[0], Length(Data));
      if Got <> Length(Data) then
      begin
        ErrMsg := Format('short read from "%s": %d of %d bytes',
                         [FileName, Got, Length(Data)]);
        SetLength(Data, 0);
        Exit;
      end;
    finally
      Stream.Free;
    end;
  except
    on E: Exception do
    begin
      ErrMsg := 'cannot read "' + FileName + '": ' + E.Message;
      SetLength(Data, 0);
      Exit;
    end;
  end;
  Result := True;
end;

function LoadAuthenticatedProductionJob(const ManifestFile, AuthFile,
  ExpectedKeyID: string; const Key: TBytes; VerificationUTC: QWord;
  out Job: TProductionJob; out ErrMsg: string): boolean;
var
  ManifestData, AuthData: TBytes;
  Auth: TDetachedJobAuth;
begin
  Result := False;
  ClearProductionJob(Job);
  if not ReadSmallFile(ManifestFile, MAX_PRODUCTION_JOB_BYTES,
                       ManifestData, ErrMsg) then Exit;
  if not ParseProductionJob(ManifestData, Job, ErrMsg) then
  begin
    ErrMsg := 'invalid production job: ' + ErrMsg;
    ClearProductionJob(Job);
    Exit;
  end;
  if not ReadSmallFile(AuthFile, MAX_PRODUCTION_AUTH_BYTES,
                       AuthData, ErrMsg) then
  begin
    ClearProductionJob(Job);
    Exit;
  end;
  if not ParseDetachedJobAuth(AuthData, Auth, ErrMsg) then
  begin
    ErrMsg := 'invalid production-job authentication: ' + ErrMsg;
    ClearProductionJob(Job);
    Exit;
  end;
  if not VerifyDetachedJobAuth(Job, Auth, ExpectedKeyID, Key,
                               VerificationUTC, ErrMsg) then
  begin
    ClearProductionJob(Job);
    Exit;
  end;
  Result := True;
end;

function OpenVerifiedProductionImage(const Job: TProductionJob;
  const ManifestDirectory: string; out ImageStream: TFileStream;
  out ResolvedFile: string; out ErrMsg: string): boolean;
var
  BaseDirectory, Candidate, CandidateDirectory: string;
  FileSize: QWord;
  ActualDigest, ExpectedDigest: TSHA256Digest;
begin
  Result := False;
  ImageStream := nil;
  ResolvedFile := '';
  ErrMsg := '';
  if not ValidateProductionJob(Job, ErrMsg) then Exit;
  if not ValidImageBasename(Job.ImageFile) then
  begin
    ErrMsg := 'production image name is not a safe sibling basename';
    Exit;
  end;

  if ManifestDirectory = '' then BaseDirectory := ExpandFileName('.')
  else BaseDirectory := ExpandFileName(ManifestDirectory);
  if not DirectoryExists(BaseDirectory) then
  begin
    ErrMsg := 'manifest directory does not exist: ' + BaseDirectory;
    Exit;
  end;
  Candidate := ExpandFileName(
    IncludeTrailingPathDelimiter(BaseDirectory) + Job.ImageFile);
  CandidateDirectory := ExtractFileDir(Candidate);
  if CompareText(IncludeTrailingPathDelimiter(CandidateDirectory),
                 IncludeTrailingPathDelimiter(BaseDirectory)) <> 0 then
  begin
    ErrMsg := 'production image resolves outside the manifest directory';
    Exit;
  end;

  try
    ImageStream := TFileStream.Create(Candidate,
                                      fmOpenRead or fmShareDenyWrite);
    if ImageStream.Size < 0 then
    begin
      ErrMsg := 'production image reported a negative size';
      FreeAndNil(ImageStream);
      Exit;
    end;
    FileSize := QWord(ImageStream.Size);
  except
    on E: Exception do
    begin
      ErrMsg := 'cannot open production image: ' + E.Message;
      FreeAndNil(ImageStream);
      Exit;
    end;
  end;
  if FileSize <> Job.ImageSize then
  begin
    ErrMsg := Format('production image size is %s; job declares %s',
                     [UIntText(FileSize), UIntText(Job.ImageSize)]);
    FreeAndNil(ImageStream);
    Exit;
  end;
  ImageStream.Position := 0;
  if not SHA256Stream(ImageStream, ActualDigest, ErrMsg) then
  begin
    FreeAndNil(ImageStream);
    Exit;
  end;
  if not HexToDigest(Job.ImageSHA256, ExpectedDigest) or
     (not DigestEqualConstantTime(ActualDigest, ExpectedDigest)) then
  begin
    ErrMsg := 'production image SHA-256 does not match the job';
    FreeAndNil(ImageStream);
    Exit;
  end;
  ImageStream.Position := 0;
  ResolvedFile := Candidate;
  Result := True;
end;

function VerifyProductionImage(const Job: TProductionJob;
  const ManifestDirectory: string; out ResolvedFile: string;
  out ErrMsg: string): boolean;
var
  ImageStream: TFileStream;
begin
  ImageStream := nil;
  Result := OpenVerifiedProductionImage(Job, ManifestDirectory, ImageStream,
                                        ResolvedFile, ErrMsg);
  ImageStream.Free;
end;

function VerifyChipDefinitionBytes(const Job: TProductionJob;
  const ChipDefinitionBytes: TBytes; out ErrMsg: string): boolean;
var
  ActualDigest, ExpectedDigest: TSHA256Digest;
begin
  Result := False;
  ErrMsg := '';
  if not ValidateProductionJob(Job, ErrMsg) then Exit;
  if not SHA256Bytes(ChipDefinitionBytes, ActualDigest, ErrMsg) then Exit;
  if not HexToDigest(Job.ChipDefinitionSHA256, ExpectedDigest) or
     (not DigestEqualConstantTime(ActualDigest, ExpectedDigest)) then
  begin
    ErrMsg := 'chip-definition SHA-256 does not match the job';
    Exit;
  end;
  Result := True;
end;

function JobToElectricalRequirements(const Job: TProductionJob):
  TTargetElectricalRequirements;
begin
  Result.Protocol := Job.Protocol;
  Result.VccMinMv := Job.VccMinMv;
  Result.VccMaxMv := Job.VccMaxMv;
  Result.VioMaxMv := Job.VioMaxMv;
  Result.MaxBusHz := Job.MaxBusHz;
  Result.RequiredProgrammerID := Job.RequiredProgrammerID;
  Result.RequiredAdapterID := Job.RequiredAdapterID;
  Result.RequiresOpenDrain := Job.OpenDrainRequired;
  Result.AllowsExternalPower := Job.ExternalPowerAllowed;
end;

end.
