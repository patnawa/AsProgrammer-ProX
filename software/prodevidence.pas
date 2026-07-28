unit prodevidence;

// Durable evidence-file primitives.
//
// A completed unit can be represented as one immutable evidence envelope.
// The envelope carries a domain-separated SHA-256 digest over the run ID,
// the payload length, and the payload, so corruption of the header fields is
// detected exactly like corruption of the payload.  AtomicWriteDurable
// writes a sibling temporary file, flushes it, and installs it with a
// same-volume, write-through rename.
//
// A version-1 envelope's digest is not an authenticator: anyone able to
// alter the evidence file can calculate a new digest.  A version-2 envelope
// adds a detached-style HMAC-SHA-256 over the header under a station key,
// which makes the whole envelope (header fields and, through the content
// digest, the payload) tamper-evident to anyone holding that key.  See
// docs/production-job-security.md.

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, prodcrypto
  {$IFDEF WINDOWS}, Windows{$ENDIF};

const
  EVIDENCE_FORMAT = 'AsProgrammer-ProX/evidence';
  EVIDENCE_VERSION = 1;
  EVIDENCE_SIGNED_VERSION = 2;
  MAX_EVIDENCE_PAYLOAD = 64 * 1024 * 1024;

type
  TEvidenceEnvelopeInfo = record
    Version: cardinal;
    RunID: string;
    PayloadLength: cardinal;
    ContentSHA256: string;
    AuthKeyID: string; // empty for version 1
  end;

// Writes bytes atomically in the target directory.  ReplaceExisting=False is
// the production-safe default: an existing run ID can never be overwritten.
function AtomicWriteDurable(const FileName: string; const Data: TBytes;
  ReplaceExisting: boolean; out ErrMsg: string): boolean;

function BuildEvidenceEnvelope(const RunID: string; const Payload: TBytes;
  out Envelope: TBytes; out Info: TEvidenceEnvelopeInfo;
  out ErrMsg: string): boolean;
function ValidateEvidenceEnvelope(const Envelope: TBytes;
  out Info: TEvidenceEnvelopeInfo; out Payload: TBytes;
  out ErrMsg: string): boolean;

// Version-2 envelopes carry an HMAC-SHA-256 over the header under a station
// key, so evidence cannot be forged or re-attributed by anyone without the
// key.  The key follows the same rules as the job-auth key: at least
// MIN_HMAC_KEY_BYTES bytes, configured externally, never stored in evidence.
function BuildSignedEvidenceEnvelope(const RunID: string;
  const Payload: TBytes; const KeyID: string; const Key: TBytes;
  out Envelope: TBytes; out Info: TEvidenceEnvelopeInfo;
  out ErrMsg: string): boolean;
function ValidateSignedEvidenceEnvelope(const Envelope: TBytes;
  const ExpectedKeyID: string; const Key: TBytes;
  out Info: TEvidenceEnvelopeInfo; out Payload: TBytes;
  out ErrMsg: string): boolean;

function SaveEvidenceAtomic(const FileName, RunID: string;
  const Payload: TBytes; out PayloadSHA256: string;
  out ErrMsg: string): boolean;
function SaveSignedEvidenceAtomic(const FileName, RunID: string;
  const Payload: TBytes; const KeyID: string; const Key: TBytes;
  out PayloadSHA256: string; out ErrMsg: string): boolean;

implementation

{$IFNDEF WINDOWS}
uses
  BaseUnix, Unix;
{$ENDIF}

function ValidRunID(const Value: string): boolean;
var
  i: integer;
begin
  Result := False;
  if (Length(Value) < 1) or (Length(Value) > 96) then Exit;
  for i := 1 to Length(Value) do
    if not (Value[i] in ['A'..'Z', 'a'..'z', '0'..'9', '.', '_', '-']) then
      Exit;
  Result := True;
end;

function StringToBytes(const Value: RawByteString): TBytes;
begin
  Result := nil;
  SetLength(Result, Length(Value));
  if Length(Value) > 0 then Move(Value[1], Result[0], Length(Value));
end;

function StrictCardinal(const Value: string; out Number: cardinal): boolean;
var
  i: integer;
  V: QWord;
  D: byte;
begin
  Result := False;
  Number := 0;
  if Value = '' then Exit;
  if (Length(Value) > 1) and (Value[1] = '0') then Exit;
  V := 0;
  for i := 1 to Length(Value) do
  begin
    if not (Value[i] in ['0'..'9']) then Exit;
    D := Ord(Value[i]) - Ord('0');
    if V > (High(cardinal) - D) div 10 then Exit;
    V := (V * 10) + D;
  end;
  Number := cardinal(V);
  Result := True;
end;

const
  // Domain separation: the content digest and the header MAC can never be
  // confused with each other or with the job-auth MAC.
  EVIDENCE_CONTENT_DOMAIN = 'AsProgrammer-ProX/evidence-content/v1';
  EVIDENCE_AUTH_DOMAIN = 'AsProgrammer-ProX/evidence-auth/v2';
  MAX_EVIDENCE_HEADER = 4096;
  V1_FIELD_COUNT = 5;
  V2_FIELD_COUNT = 7;
  V1_KEYS: array[0..V1_FIELD_COUNT - 1] of string =
    ('format', 'version', 'run_id', 'payload_length', 'content_sha256');
  V2_KEYS: array[0..V2_FIELD_COUNT - 1] of string =
    ('format', 'version', 'run_id', 'payload_length', 'content_sha256',
     'auth_key_id', 'auth_mac');

type
  TValueArray = array of string;

// Same identifier rules as a job-auth key ID (prodjob.ValidIdentifier
// without the "any"/"none" specials): NUL, '=' and LF are all excluded, so
// a key ID can neither break the canonical header nor the MAC input.
function ValidKeyID(const Value: string): boolean;
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

procedure ResetInfo(out Info: TEvidenceEnvelopeInfo);
begin
  Info.Version := 0;
  Info.RunID := '';
  Info.PayloadLength := 0;
  Info.ContentSHA256 := '';
  Info.AuthKeyID := '';
end;

// The content digest binds the run ID and the declared length to the payload
// bytes, so header corruption fails validation exactly like payload
// corruption.
function ComputeContentDigest(const RunID: string; const Payload: TBytes;
  out Digest: TSHA256Digest; out ErrMsg: string): boolean;
var
  Prefix: RawByteString;
  Input: TBytes;
begin
  Prefix := EVIDENCE_CONTENT_DOMAIN + #0 + RunID + #0 +
            IntToStr(Length(Payload)) + #0;
  Input := StringToBytes(Prefix);
  SetLength(Input, Length(Prefix) + Length(Payload));
  if Length(Payload) > 0 then
    Move(Payload[0], Input[Length(Prefix)], Length(Payload));
  Result := SHA256Bytes(Input, Digest, ErrMsg);
end;

// The five fields every envelope version shares, each line LF-terminated.
// These exact bytes are what a version-2 MAC covers.
function CoreHeaderText(Version: cardinal; const RunID: string;
  PayloadLength: cardinal; const ContentHex: string): RawByteString;
begin
  Result :=
    'format=' + EVIDENCE_FORMAT + #10 +
    'version=' + IntToStr(Version) + #10 +
    'run_id=' + RunID + #10 +
    'payload_length=' + IntToStr(PayloadLength) + #10 +
    'content_sha256=' + ContentHex + #10;
end;

function ComputeHeaderMAC(const KeyID: string; const Key: TBytes;
  const CoreHeader: RawByteString; out MAC: TSHA256Digest;
  out ErrMsg: string): boolean;
begin
  Result := HMACSHA256(Key,
    StringToBytes(EVIDENCE_AUTH_DOMAIN + #0 + KeyID + #0 + CoreHeader),
    MAC, ErrMsg);
end;

function ParseHeaderFields(const Envelope: TBytes;
  const ExpectedKeys: array of string; out Values: TValueArray;
  out PayloadAt: integer; out ErrMsg: string): boolean;
var
  HeaderEnd, i, StartAt, LineNo, EqAt: integer;
  Line, Key: string;
begin
  Result := False;
  SetLength(Values, Length(ExpectedKeys));
  PayloadAt := 0;
  ErrMsg := '';

  HeaderEnd := -1;
  for i := 0 to Length(Envelope) - 2 do
    if (Envelope[i] = 10) and (Envelope[i + 1] = 10) then
    begin
      HeaderEnd := i;
      Break;
    end;
  if HeaderEnd < 0 then
  begin
    ErrMsg := 'evidence envelope has no header terminator';
    Exit;
  end;
  if HeaderEnd > MAX_EVIDENCE_HEADER then
  begin
    ErrMsg := 'evidence envelope header is too large';
    Exit;
  end;

  StartAt := 0;
  LineNo := 0;
  for i := 0 to HeaderEnd do
    if Envelope[i] = 10 then
    begin
      if LineNo >= Length(ExpectedKeys) then
      begin
        ErrMsg := 'evidence envelope has too many header fields';
        Exit;
      end;
      SetLength(Line, i - StartAt);
      if Length(Line) > 0 then Move(Envelope[StartAt], Line[1], Length(Line));
      if (Line = '') or (Pos(#13, Line) > 0) then
      begin
        ErrMsg := Format('invalid evidence header line %d', [LineNo + 1]);
        Exit;
      end;
      EqAt := Pos('=', Line);
      if EqAt < 2 then
      begin
        ErrMsg := Format('invalid evidence header line %d', [LineNo + 1]);
        Exit;
      end;
      Key := Copy(Line, 1, EqAt - 1);
      if Key <> ExpectedKeys[LineNo] then
      begin
        ErrMsg := Format('expected evidence field %s, found %s',
                         [ExpectedKeys[LineNo], Key]);
        Exit;
      end;
      Values[LineNo] := Copy(Line, EqAt + 1, Length(Line));
      Inc(LineNo);
      StartAt := i + 1;
    end;

  if LineNo <> Length(ExpectedKeys) then
  begin
    ErrMsg := Format('evidence envelope has %d fields; expected %d',
                     [LineNo, Length(ExpectedKeys)]);
    Exit;
  end;
  PayloadAt := HeaderEnd + 2;
  Result := True;
end;

// Checks the five shared fields and extracts the payload bytes; the caller
// still owns digest and MAC verification.
function ValidateCommonFields(const Envelope: TBytes;
  const Values: TValueArray; PayloadAt: integer; ExpectedVersion: cardinal;
  out Info: TEvidenceEnvelopeInfo; out Payload: TBytes;
  out ExpectedDigest: TSHA256Digest; out ErrMsg: string): boolean;
begin
  Result := False;
  ResetInfo(Info);
  SetLength(Payload, 0);
  FillChar(ExpectedDigest, SizeOf(ExpectedDigest), 0);
  ErrMsg := '';

  if Values[0] <> EVIDENCE_FORMAT then
  begin
    ErrMsg := 'unsupported evidence format';
    Exit;
  end;
  if Values[1] <> IntToStr(ExpectedVersion) then
  begin
    ErrMsg := 'unsupported evidence version';
    Exit;
  end;
  if not ValidRunID(Values[2]) then
  begin
    ErrMsg := 'invalid evidence run ID';
    Exit;
  end;
  if not StrictCardinal(Values[3], Info.PayloadLength) then
  begin
    ErrMsg := 'invalid evidence payload length';
    Exit;
  end;
  if Info.PayloadLength > MAX_EVIDENCE_PAYLOAD then
  begin
    ErrMsg := 'evidence payload exceeds the safety limit';
    Exit;
  end;
  if (Length(Values[4]) <> SHA256_HEX_CHARS) or
     (Values[4] <> UpperCase(Values[4])) or
     (not HexToDigest(Values[4], ExpectedDigest)) then
  begin
    ErrMsg := 'invalid evidence content SHA-256';
    Exit;
  end;
  if Length(Envelope) - PayloadAt <> integer(Info.PayloadLength) then
  begin
    ErrMsg := Format('evidence payload length is %d; header declares %d',
                     [Length(Envelope) - PayloadAt, Info.PayloadLength]);
    Exit;
  end;
  SetLength(Payload, Info.PayloadLength);
  if Info.PayloadLength > 0 then
    Move(Envelope[PayloadAt], Payload[0], Info.PayloadLength);

  Info.Version := ExpectedVersion;
  Info.RunID := Values[2];
  Info.ContentSHA256 := Values[4];
  Result := True;
end;

function BuildEnvelopeInternal(Version: cardinal; const RunID: string;
  const Payload: TBytes; const KeyID: string; const Key: TBytes;
  out Envelope: TBytes; out Info: TEvidenceEnvelopeInfo;
  out ErrMsg: string): boolean;
var
  Digest, MAC: TSHA256Digest;
  Core, Header: RawByteString;
  HeaderBytes: TBytes;
begin
  Result := False;
  SetLength(Envelope, 0);
  ResetInfo(Info);
  ErrMsg := '';

  if not ValidRunID(RunID) then
  begin
    ErrMsg := 'evidence run ID is empty or contains unsupported characters';
    Exit;
  end;
  if Length(Payload) > MAX_EVIDENCE_PAYLOAD then
  begin
    ErrMsg := Format('evidence payload exceeds %d bytes',
                     [MAX_EVIDENCE_PAYLOAD]);
    Exit;
  end;
  if not ComputeContentDigest(RunID, Payload, Digest, ErrMsg) then Exit;

  Info.Version := Version;
  Info.RunID := RunID;
  Info.PayloadLength := Length(Payload);
  Info.ContentSHA256 := DigestToHex(Digest);

  Core := CoreHeaderText(Version, RunID, Info.PayloadLength,
                         Info.ContentSHA256);
  if Version = EVIDENCE_SIGNED_VERSION then
  begin
    if not ValidKeyID(KeyID) then
    begin
      ErrMsg := 'evidence auth key ID is empty or contains unsupported characters';
      ResetInfo(Info);
      Exit;
    end;
    if not ComputeHeaderMAC(KeyID, Key, Core, MAC, ErrMsg) then
    begin
      ResetInfo(Info);
      Exit;
    end;
    Info.AuthKeyID := KeyID;
    Header := Core +
      'auth_key_id=' + KeyID + #10 +
      'auth_mac=' + DigestToHex(MAC) + #10#10;
  end
  else
    Header := Core + #10;

  HeaderBytes := StringToBytes(Header);
  SetLength(Envelope, Length(HeaderBytes) + Length(Payload));
  if Length(HeaderBytes) > 0 then
    Move(HeaderBytes[0], Envelope[0], Length(HeaderBytes));
  if Length(Payload) > 0 then
    Move(Payload[0], Envelope[Length(HeaderBytes)], Length(Payload));
  Result := True;
end;

function BuildEvidenceEnvelope(const RunID: string; const Payload: TBytes;
  out Envelope: TBytes; out Info: TEvidenceEnvelopeInfo;
  out ErrMsg: string): boolean;
var
  NoKey: TBytes;
begin
  SetLength(NoKey, 0);
  Result := BuildEnvelopeInternal(EVIDENCE_VERSION, RunID, Payload, '',
                                  NoKey, Envelope, Info, ErrMsg);
end;

function BuildSignedEvidenceEnvelope(const RunID: string;
  const Payload: TBytes; const KeyID: string; const Key: TBytes;
  out Envelope: TBytes; out Info: TEvidenceEnvelopeInfo;
  out ErrMsg: string): boolean;
begin
  Result := BuildEnvelopeInternal(EVIDENCE_SIGNED_VERSION, RunID, Payload,
                                  KeyID, Key, Envelope, Info, ErrMsg);
end;

function ValidateEvidenceEnvelope(const Envelope: TBytes;
  out Info: TEvidenceEnvelopeInfo; out Payload: TBytes;
  out ErrMsg: string): boolean;
var
  Values: TValueArray;
  PayloadAt: integer;
  Digest, ExpectedDigest: TSHA256Digest;
begin
  Result := False;
  ResetInfo(Info);
  SetLength(Payload, 0);

  if not ParseHeaderFields(Envelope, V1_KEYS, Values, PayloadAt,
                           ErrMsg) then Exit;
  if not ValidateCommonFields(Envelope, Values, PayloadAt, EVIDENCE_VERSION,
                              Info, Payload, ExpectedDigest, ErrMsg) then Exit;
  if not ComputeContentDigest(Info.RunID, Payload, Digest, ErrMsg) then
  begin
    ResetInfo(Info);
    SetLength(Payload, 0);
    Exit;
  end;
  if not DigestEqualConstantTime(Digest, ExpectedDigest) then
  begin
    ErrMsg := 'evidence content SHA-256 does not match the header';
    ResetInfo(Info);
    SetLength(Payload, 0);
    Exit;
  end;
  Result := True;
end;

function ValidateSignedEvidenceEnvelope(const Envelope: TBytes;
  const ExpectedKeyID: string; const Key: TBytes;
  out Info: TEvidenceEnvelopeInfo; out Payload: TBytes;
  out ErrMsg: string): boolean;
var
  Values: TValueArray;
  PayloadAt: integer;
  Digest, ExpectedDigest, MAC, ExpectedMAC: TSHA256Digest;
  Core: RawByteString;
begin
  Result := False;
  ResetInfo(Info);
  SetLength(Payload, 0);

  if not ValidKeyID(ExpectedKeyID) then
  begin
    ErrMsg := 'expected evidence auth key ID is invalid';
    Exit;
  end;
  if not ParseHeaderFields(Envelope, V2_KEYS, Values, PayloadAt,
                           ErrMsg) then Exit;
  if not ValidateCommonFields(Envelope, Values, PayloadAt,
                              EVIDENCE_SIGNED_VERSION, Info, Payload,
                              ExpectedDigest, ErrMsg) then Exit;

  // The MAC gate comes before the content digest: nothing later is trusted
  // unless the header authenticates under the expected station key.
  if not ValidKeyID(Values[5]) then
  begin
    ErrMsg := 'invalid evidence auth key ID';
    ResetInfo(Info);
    SetLength(Payload, 0);
    Exit;
  end;
  if Values[5] <> ExpectedKeyID then
  begin
    ErrMsg := Format('evidence auth key ID is %s; expected %s',
                     [Values[5], ExpectedKeyID]);
    ResetInfo(Info);
    SetLength(Payload, 0);
    Exit;
  end;
  if (Length(Values[6]) <> SHA256_HEX_CHARS) or
     (Values[6] <> UpperCase(Values[6])) or
     (not HexToDigest(Values[6], ExpectedMAC)) then
  begin
    ErrMsg := 'invalid evidence auth MAC';
    ResetInfo(Info);
    SetLength(Payload, 0);
    Exit;
  end;

  // Byte-exact reconstruction: field order and content were just verified,
  // so these are the same bytes the producer MACed.
  Core := CoreHeaderText(EVIDENCE_SIGNED_VERSION, Info.RunID,
                         Info.PayloadLength, Info.ContentSHA256);
  if not ComputeHeaderMAC(Values[5], Key, Core, MAC, ErrMsg) then
  begin
    ResetInfo(Info);
    SetLength(Payload, 0);
    Exit;
  end;
  if not DigestEqualConstantTime(MAC, ExpectedMAC) then
  begin
    ErrMsg := 'evidence auth MAC does not verify under the expected key';
    ResetInfo(Info);
    SetLength(Payload, 0);
    Exit;
  end;

  if not ComputeContentDigest(Info.RunID, Payload, Digest, ErrMsg) then
  begin
    ResetInfo(Info);
    SetLength(Payload, 0);
    Exit;
  end;
  if not DigestEqualConstantTime(Digest, ExpectedDigest) then
  begin
    ErrMsg := 'evidence content SHA-256 does not match the header';
    ResetInfo(Info);
    SetLength(Payload, 0);
    Exit;
  end;

  Info.AuthKeyID := Values[5];
  Result := True;
end;

{$IFDEF WINDOWS}

const
  MOVEFILE_REPLACE_EXISTING_FLAG = $00000001;
  MOVEFILE_WRITE_THROUGH_FLAG = $00000008;

function WinError(const Context: string): string;
begin
  Result := Context + ': ' + SysErrorMessage(GetLastError);
end;

function AtomicWriteDurable(const FileName: string; const Data: TBytes;
  ReplaceExisting: boolean; out ErrMsg: string): boolean;
var
  AbsoluteName, TempName: string;
  WideName, WideTemp: UnicodeString;
  Handle: THandle;
  Written, Chunk, Offset: cardinal;
  G: TGUID;
  MoveFlags: cardinal;
  Installed: boolean;
begin
  Result := False;
  ErrMsg := '';
  if Trim(FileName) = '' then
  begin
    ErrMsg := 'atomic output filename is empty';
    Exit;
  end;

  AbsoluteName := ExpandFileName(FileName);
  if not DirectoryExists(ExtractFileDir(AbsoluteName)) then
  begin
    ErrMsg := 'atomic output directory does not exist: ' +
              ExtractFileDir(AbsoluteName);
    Exit;
  end;

  if (not ReplaceExisting) and FileExists(AbsoluteName) then
  begin
    ErrMsg := 'refusing to overwrite existing evidence: ' + AbsoluteName;
    Exit;
  end;

  if CreateGUID(G) <> 0 then
  begin
    ErrMsg := 'could not create a unique temporary filename';
    Exit;
  end;
  TempName := AbsoluteName + '.tmp-' +
              StringReplace(StringReplace(GUIDToString(G), '{', '',
                            [rfReplaceAll]), '}', '', [rfReplaceAll]);
  WideTemp := UTF8Decode(TempName);
  // FILE_ATTRIBUTE_NORMAL, not TEMPORARY: the attribute survives the rename,
  // and backup tooling may deprioritize files still flagged temporary.
  Handle := CreateFileW(PWideChar(WideTemp), GENERIC_WRITE, 0, nil,
    CREATE_NEW, FILE_ATTRIBUTE_NORMAL or FILE_FLAG_WRITE_THROUGH, 0);
  if Handle = INVALID_HANDLE_VALUE then
  begin
    ErrMsg := WinError('cannot create atomic temporary file');
    Exit;
  end;

  Installed := False;
  try
    Offset := 0;
    while Offset < cardinal(Length(Data)) do
    begin
      Chunk := cardinal(Length(Data)) - Offset;
      if Chunk > 1024 * 1024 then Chunk := 1024 * 1024;
      Written := 0;
      if not WriteFile(Handle, Data[Offset], Chunk, Written, nil) then
      begin
        ErrMsg := WinError('cannot write atomic temporary file');
        Exit;
      end;
      if Written <> Chunk then
      begin
        ErrMsg := Format(
          'short write to atomic temporary file: %d of %d bytes',
          [Written, Chunk]);
        Exit;
      end;
      Inc(Offset, Written);
    end;
    if not FlushFileBuffers(Handle) then
    begin
      ErrMsg := WinError('cannot flush atomic temporary file');
      Exit;
    end;

    // The file must be closed before the same-volume rename.
    CloseHandle(Handle);
    Handle := INVALID_HANDLE_VALUE;

    MoveFlags := MOVEFILE_WRITE_THROUGH_FLAG;
    if ReplaceExisting then
      MoveFlags := MoveFlags or MOVEFILE_REPLACE_EXISTING_FLAG;
    WideName := UTF8Decode(AbsoluteName);
    if not MoveFileExW(PWideChar(WideTemp), PWideChar(WideName),
                       MoveFlags) then
    begin
      ErrMsg := WinError('cannot install atomic output file');
      Exit;
    end;
    Installed := True;
    Result := True;
  finally
    if Handle <> INVALID_HANDLE_VALUE then CloseHandle(Handle);
    if not Installed then DeleteFileW(PWideChar(WideTemp));
  end;
end;

{$ELSE}

// POSIX: the same guarantees the Windows path requests, spelled natively --
// exclusive temp sibling, fsync of the data, atomic install, fsync of the
// directory so the rename itself is durable.  ReplaceExisting=False installs
// with link(), which fails if the target exists instead of replacing it, so
// the no-overwrite promise holds even against a concurrent writer.

function PosixError(const Context: string): string;
begin
  Result := Context + ': ' + SysErrorMessage(fpgeterrno);
end;

function AtomicWriteDurable(const FileName: string; const Data: TBytes;
  ReplaceExisting: boolean; out ErrMsg: string): boolean;
var
  AbsoluteName, TempName, DirName: string;
  Fd, DirFd: cint;
  Written: TsSize;
  Offset, Chunk: SizeInt;
  G: TGUID;
  Installed: boolean;
begin
  Result := False;
  ErrMsg := '';
  if Trim(FileName) = '' then
  begin
    ErrMsg := 'atomic output filename is empty';
    Exit;
  end;

  AbsoluteName := ExpandFileName(FileName);
  DirName := ExtractFileDir(AbsoluteName);
  if not DirectoryExists(DirName) then
  begin
    ErrMsg := 'atomic output directory does not exist: ' + DirName;
    Exit;
  end;

  if (not ReplaceExisting) and FileExists(AbsoluteName) then
  begin
    ErrMsg := 'refusing to overwrite existing evidence: ' + AbsoluteName;
    Exit;
  end;

  if CreateGUID(G) <> 0 then
  begin
    ErrMsg := 'could not create a unique temporary filename';
    Exit;
  end;
  TempName := AbsoluteName + '.tmp-' +
              StringReplace(StringReplace(GUIDToString(G), '{', '',
                            [rfReplaceAll]), '}', '', [rfReplaceAll]);

  Fd := fpOpen(PChar(TempName), O_WRONLY or O_CREAT or O_EXCL, &644);
  if Fd < 0 then
  begin
    ErrMsg := PosixError('cannot create atomic temporary file');
    Exit;
  end;

  Installed := False;
  try
    Offset := 0;
    while Offset < Length(Data) do
    begin
      Chunk := Length(Data) - Offset;
      if Chunk > 1024 * 1024 then Chunk := 1024 * 1024;
      Written := fpWrite(Fd, Data[Offset], Chunk);
      if Written < 0 then
      begin
        ErrMsg := PosixError('cannot write atomic temporary file');
        Exit;
      end;
      if Written = 0 then
      begin
        ErrMsg := 'short write to atomic temporary file';
        Exit;
      end;
      Inc(Offset, Written);
    end;
    if fpfsync(Fd) <> 0 then
    begin
      ErrMsg := PosixError('cannot flush atomic temporary file');
      Exit;
    end;
    fpClose(Fd);
    Fd := -1;

    if ReplaceExisting then
    begin
      if fpRename(PChar(TempName), PChar(AbsoluteName)) <> 0 then
      begin
        ErrMsg := PosixError('cannot install atomic output file');
        Exit;
      end;
    end
    else
    begin
      // link() refuses an existing target atomically; rename() would
      // silently replace it.
      if FpLink(PChar(TempName), PChar(AbsoluteName)) <> 0 then
      begin
        ErrMsg := PosixError('cannot install atomic output file');
        Exit;
      end;
      fpUnlink(PChar(TempName));
    end;
    Installed := True;

    // The rename/link is only durable once the directory itself is synced.
    DirFd := fpOpen(PChar(DirName), O_RDONLY);
    if DirFd >= 0 then
    begin
      if fpfsync(DirFd) <> 0 then
      begin
        fpClose(DirFd);
        ErrMsg := PosixError('cannot flush the output directory');
        Exit;
      end;
      fpClose(DirFd);
    end;

    Result := True;
  finally
    if Fd >= 0 then fpClose(Fd);
    if not Installed then fpUnlink(PChar(TempName));
  end;
end;

{$ENDIF}

function SaveEvidenceAtomic(const FileName, RunID: string;
  const Payload: TBytes; out PayloadSHA256: string;
  out ErrMsg: string): boolean;
var
  Envelope: TBytes;
  Info: TEvidenceEnvelopeInfo;
begin
  PayloadSHA256 := '';
  Result := BuildEvidenceEnvelope(RunID, Payload, Envelope, Info, ErrMsg);
  if not Result then Exit;
  Result := AtomicWriteDurable(FileName, Envelope, False, ErrMsg);
  if Result then PayloadSHA256 := Info.ContentSHA256;
end;

function SaveSignedEvidenceAtomic(const FileName, RunID: string;
  const Payload: TBytes; const KeyID: string; const Key: TBytes;
  out PayloadSHA256: string; out ErrMsg: string): boolean;
var
  Envelope: TBytes;
  Info: TEvidenceEnvelopeInfo;
begin
  PayloadSHA256 := '';
  Result := BuildSignedEvidenceEnvelope(RunID, Payload, KeyID, Key,
                                        Envelope, Info, ErrMsg);
  if not Result then Exit;
  Result := AtomicWriteDurable(FileName, Envelope, False, ErrMsg);
  if Result then PayloadSHA256 := Info.ContentSHA256;
end;

end.
