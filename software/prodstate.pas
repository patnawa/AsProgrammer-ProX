unit prodstate;

// Durable local production state: an append-only, HMAC-chained log of
// consumed production runs, for a single station that has no MES.
//
// Each line records one admitted-and-passed unit: (job_id, revision,
// run_id, uid, utc).  Every line carries an HMAC-SHA-256 over the line body
// and the previous line's MAC, so the file cannot be truncated, reordered,
// or edited without the station key.  The checks this state supports:
//
//   - stale revision:   a job_id must never run with a lower revision than
//                       one already recorded;
//   - duplicate run:    a run_id can be recorded only once;
//   - consumed unit:    a chip UID that already passed is refused;
//   - monotonic time:   trusted UTC must never move backwards past the
//                       newest recorded entry, so setting the station clock
//                       back cannot silently re-enable an expired job.
//
// A MAC chain alone cannot detect whole-line truncation from the end, so the
// current chain head is anchored in a sibling "<file>.head" record installed
// with the same atomic write-through rename evidence uses.  Dropping recorded
// entries then breaks the anchor.
//
// Everything fails closed: an unreadable file, a broken chain, a torn final
// line, or a missing/mismatched head anchor refuses admission until an
// operator repairs the state from authority.  This is deliberate -- guessing
// here re-opens the replay hole the file exists to close.
//
// The unit has no LCL dependency and is exercised by tests/stage9tests.lpr.

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, prodcrypto, prodevidence;

const
  PRODSTATE_MAX_BYTES = 16 * 1024 * 1024;
  PRODSTATE_MAX_ENTRIES = 100000;

type
  TProdStateEntry = record
    Seq: cardinal;
    JobID: string;
    Revision: cardinal;
    RunID: string;
    UID: string; // uppercase hex, or 'none'
    UTC: QWord;
  end;

  TProdStateEntries = array of TProdStateEntry;

// Reads and verifies the whole chain.  A missing file is an empty, valid
// state; anything else that is not a perfect chain is an error.
function LoadProductionState(const FileName: string; const Key: TBytes;
  out Entries: TProdStateEntries; out ErrMsg: string): boolean;
function LoadProductionStateEx(const FileName: string; const Key: TBytes;
  out Entries: TProdStateEntries; out ChainHead: TSHA256Digest;
  out ErrMsg: string): boolean;

// The part of the admission decision that is known before the chip is even
// touched: stale revision and clock monotonicity.  Called at manifest
// admission, when the run ID and chip UID do not exist yet.
function CheckJobFreshness(const Entries: TProdStateEntries;
  const JobID: string; Revision: cardinal; TrustedUTC: QWord;
  out ErrMsg: string): boolean;

// The complete admission decision, pure over loaded state so it can be
// tested exhaustively.  TrustedUTC is the controller's current trusted time.
function CheckProductionAdmission(const Entries: TProdStateEntries;
  const JobID: string; Revision: cardinal; const RunID, UID: string;
  TrustedUTC: QWord; out ErrMsg: string): boolean;

// Verifies the existing chain, appends one entry, and flushes it to disk.
// The append re-runs CheckProductionAdmission first, so a caller cannot
// record an entry the state itself would have refused.
function AppendProductionState(const FileName: string; const Key: TBytes;
  const JobID: string; Revision: cardinal; const RunID, UID: string;
  TrustedUTC: QWord; out ErrMsg: string): boolean;

implementation

{$IFDEF WINDOWS}
uses
  Windows;
{$ELSE}
uses
  BaseUnix, Unix;
{$ENDIF}

const
  CHAIN_DOMAIN = 'AsProgrammer-ProX/prodstate/v1';

type
  TStringArray = array of string;

function ValidStateIdentifier(const Value: string): boolean;
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

function ValidStateUID(const Value: string): boolean;
var
  i: integer;
begin
  if Value = 'none' then Exit(True);
  Result := False;
  if ((Length(Value) and 1) <> 0) or (Length(Value) < 2) or
     (Length(Value) > 64) then Exit;
  for i := 1 to Length(Value) do
    if not (Value[i] in ['0'..'9', 'A'..'F']) then Exit;
  Result := True;
end;

function UIntText(Value: QWord): string;
begin
  Str(Value, Result);
end;

function StrictQWordText(const Value: string; out Number: QWord): boolean;
var
  i: integer;
  D: byte;
begin
  Result := False;
  Number := 0;
  if Value = '' then Exit;
  if (Length(Value) > 1) and (Value[1] = '0') then Exit;
  for i := 1 to Length(Value) do
  begin
    if not (Value[i] in ['0'..'9']) then Exit;
    D := Ord(Value[i]) - Ord('0');
    if Number > (High(QWord) - D) div 10 then Exit;
    Number := (Number * 10) + D;
  end;
  Result := True;
end;

function StrictCardinalText(const Value: string; out Number: cardinal): boolean;
var
  Q: QWord;
begin
  Result := StrictQWordText(Value, Q) and (Q <= High(cardinal));
  if Result then Number := cardinal(Q) else Number := 0;
end;

// The exact bytes one line's MAC covers.  Tab separators are safe because
// every field's charset excludes tabs, and the previous MAC is bound as its
// 32 raw bytes so the chain cannot be re-rooted.
function LineBody(Seq: cardinal; const JobID: string; Revision: cardinal;
  const RunID, UID: string; UTC: QWord): RawByteString;
begin
  Result := UIntText(Seq) + #9 + JobID + #9 + UIntText(Revision) + #9 +
            RunID + #9 + UID + #9 + UIntText(UTC);
end;

function ChainMAC(const Key: TBytes; const PrevMAC: TSHA256Digest;
  const Body: RawByteString; out MAC: TSHA256Digest;
  out ErrMsg: string): boolean;
var
  Input: TBytes;
  Prefix: RawByteString;
begin
  Prefix := CHAIN_DOMAIN + #0;
  SetLength(Input, Length(Prefix) + SizeOf(PrevMAC) + 1 + Length(Body));
  Move(Prefix[1], Input[0], Length(Prefix));
  Move(PrevMAC[0], Input[Length(Prefix)], SizeOf(PrevMAC));
  Input[Length(Prefix) + SizeOf(PrevMAC)] := 0;
  if Length(Body) > 0 then
    Move(Body[1], Input[Length(Prefix) + SizeOf(PrevMAC) + 1], Length(Body));
  Result := HMACSHA256(Key, Input, MAC, ErrMsg);
  ClearSensitiveBytes(Input);
end;

function ReadHeadAnchor(const FileName: string; out HeadHex: string;
  out ErrMsg: string): boolean;
var
  Stream: TFileStream;
  Raw: RawByteString;
begin
  Result := False;
  HeadHex := '';
  ErrMsg := '';
  if not FileExists(FileName + '.head') then
  begin
    ErrMsg := 'the production state head anchor is missing';
    Exit;
  end;
  try
    Stream := TFileStream.Create(FileName + '.head',
                                 fmOpenRead or fmShareDenyWrite);
    try
      if Stream.Size > 80 then
      begin
        ErrMsg := 'the production state head anchor is malformed';
        Exit;
      end;
      SetLength(Raw, Stream.Size);
      if Length(Raw) > 0 then Stream.ReadBuffer(Raw[1], Length(Raw));
    finally
      Stream.Free;
    end;
  except
    on Ex: Exception do
    begin
      ErrMsg := 'cannot read the production state head anchor: ' + Ex.Message;
      Exit;
    end;
  end;
  HeadHex := Trim(string(Raw));
  if Length(HeadHex) <> SHA256_HEX_CHARS then
  begin
    HeadHex := '';
    ErrMsg := 'the production state head anchor is malformed';
    Exit;
  end;
  Result := True;
end;

function WriteHeadAnchor(const FileName: string;
  const Head: TSHA256Digest; out ErrMsg: string): boolean;
var
  Data: TBytes;
  Text: RawByteString;
begin
  Text := DigestToHex(Head) + #10;
  SetLength(Data, Length(Text));
  Move(Text[1], Data[0], Length(Text));
  Result := AtomicWriteDurable(FileName + '.head', Data, True, ErrMsg);
end;

function SplitTabs(const Line: string; out Fields: TStringArray): boolean;
var
  i, StartAt, N: integer;
begin
  N := 0;
  SetLength(Fields, 8);
  StartAt := 1;
  for i := 1 to Length(Line) + 1 do
    if (i > Length(Line)) or (Line[i] = #9) then
    begin
      if N >= Length(Fields) then Exit(False);
      Fields[N] := Copy(Line, StartAt, i - StartAt);
      Inc(N);
      StartAt := i + 1;
    end;
  SetLength(Fields, N);
  Result := True;
end;

function LoadProductionStateEx(const FileName: string; const Key: TBytes;
  out Entries: TProdStateEntries; out ChainHead: TSHA256Digest;
  out ErrMsg: string): boolean;
var
  Stream: TFileStream;
  Raw: RawByteString;
  Line: string;
  Fields: TStringArray;
  PrevMAC, MAC, ExpectedMAC: TSHA256Digest;
  i, LineStart, Count: integer;
  E: TProdStateEntry;
begin
  Result := False;
  SetLength(Entries, 0);
  FillChar(ChainHead, SizeOf(ChainHead), 0);
  ErrMsg := '';

  if not FileExists(FileName) then
  begin
    //ไฟล์สถานะหายแต่สมออยู่ = ไฟล์ถูกลบหรือสลับ ไม่ใช่สถานีใหม่
    //(การลบทั้งคู่พร้อมกันแยกไม่ออกจากสถานีใหม่ นั่นคือขอบเขตของการป้องกัน
    //แบบโลคัล ต้องพึ่ง ACL ของไดเรกทอรีหรือ MES สำหรับชั้นถัดไป)
    if FileExists(FileName + '.head') then
    begin
      ErrMsg := 'a production state head anchor exists but the state file ' +
                'is missing; the state file has been removed';
      Exit;
    end;
    Exit(True); // empty state is valid
  end;

  try
    Stream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
    try
      if Stream.Size > PRODSTATE_MAX_BYTES then
      begin
        ErrMsg := 'production state file exceeds the safety limit';
        Exit;
      end;
      SetLength(Raw, Stream.Size);
      if Length(Raw) > 0 then Stream.ReadBuffer(Raw[1], Length(Raw));
    finally
      Stream.Free;
    end;
  except
    on Ex: Exception do
    begin
      ErrMsg := 'cannot read the production state file: ' + Ex.Message;
      Exit;
    end;
  end;

  FillChar(PrevMAC, SizeOf(PrevMAC), 0);
  Count := 0;
  LineStart := 1;
  for i := 1 to Length(Raw) + 1 do
  begin
    if (i <= Length(Raw)) and (Raw[i] <> #10) then Continue;
    if (i > Length(Raw)) and (LineStart >= i) then Break; // clean final LF

    // A final line without its LF is a torn write: fail closed.
    if i > Length(Raw) then
    begin
      ErrMsg := 'the production state file ends in a torn line';
      SetLength(Entries, 0);
      Exit;
    end;

    Line := Copy(Raw, LineStart, i - LineStart);
    LineStart := i + 1;

    if Count >= PRODSTATE_MAX_ENTRIES then
    begin
      ErrMsg := 'production state has too many entries';
      SetLength(Entries, 0);
      Exit;
    end;
    if (Line = '') or (Pos(#13, Line) > 0) or
       (not SplitTabs(Line, Fields)) or (Length(Fields) <> 7) then
    begin
      ErrMsg := Format('invalid production state line %d', [Count + 1]);
      SetLength(Entries, 0);
      Exit;
    end;

    if (not StrictCardinalText(Fields[0], E.Seq)) or
       (E.Seq <> cardinal(Count + 1)) or
       (not ValidStateIdentifier(Fields[1])) or
       (not StrictCardinalText(Fields[2], E.Revision)) or
       (not ValidStateIdentifier(Fields[3])) or
       (not ValidStateUID(Fields[4])) or
       (not StrictQWordText(Fields[5], E.UTC)) or
       (Length(Fields[6]) <> SHA256_HEX_CHARS) or
       (Fields[6] <> UpperCase(Fields[6])) or
       (not HexToDigest(Fields[6], ExpectedMAC)) then
    begin
      ErrMsg := Format('invalid production state line %d', [Count + 1]);
      SetLength(Entries, 0);
      Exit;
    end;
    E.JobID := Fields[1];
    E.RunID := Fields[3];
    E.UID := Fields[4];

    if not ChainMAC(Key, PrevMAC,
                    LineBody(E.Seq, E.JobID, E.Revision, E.RunID, E.UID,
                             E.UTC), MAC, ErrMsg) then
    begin
      SetLength(Entries, 0);
      Exit;
    end;
    if not DigestEqualConstantTime(MAC, ExpectedMAC) then
    begin
      ErrMsg := Format(
        'production state line %d does not authenticate; the file has been ' +
        'altered or truncated', [Count + 1]);
      SetLength(Entries, 0);
      Exit;
    end;

    PrevMAC := ExpectedMAC;
    if Count >= Length(Entries) then
    begin
      if Length(Entries) = 0 then SetLength(Entries, 16)
      else SetLength(Entries, Length(Entries) * 2);
    end;
    Entries[Count] := E;
    Inc(Count);
  end;

  SetLength(Entries, Count);
  ChainHead := PrevMAC;

  // The head anchor must exist and match whenever entries exist: a chain
  // that verifies but has lost its anchor has been truncated or replaced.
  if Count > 0 then
  begin
    if not ReadHeadAnchor(FileName, Line, ErrMsg) then
    begin
      SetLength(Entries, 0);
      Exit;
    end;
    if Line <> DigestToHex(ChainHead) then
    begin
      ErrMsg := 'the production state head anchor does not match; entries ' +
                'have been removed or replaced';
      SetLength(Entries, 0);
      Exit;
    end;
  end
  else if FileExists(FileName + '.head') then
  begin
    ErrMsg := 'a production state head anchor exists but the state file is ' +
              'empty; the state file has been removed or replaced';
    Exit;
  end;

  Result := True;
end;

function LoadProductionState(const FileName: string; const Key: TBytes;
  out Entries: TProdStateEntries; out ErrMsg: string): boolean;
var
  Head: TSHA256Digest;
begin
  Result := LoadProductionStateEx(FileName, Key, Entries, Head, ErrMsg);
end;

function CheckJobFreshness(const Entries: TProdStateEntries;
  const JobID: string; Revision: cardinal; TrustedUTC: QWord;
  out ErrMsg: string): boolean;
var
  i: SizeInt;
begin
  Result := False;
  ErrMsg := '';

  if not ValidStateIdentifier(JobID) then
  begin
    ErrMsg := 'production state job ID is not a safe identifier';
    Exit;
  end;

  for i := 0 to High(Entries) do
  begin
    if (Entries[i].JobID = JobID) and (Entries[i].Revision > Revision) then
    begin
      ErrMsg := Format(
        'job %s already ran at revision %d; revision %d is stale',
        [JobID, Entries[i].Revision, Revision]);
      Exit;
    end;
    // Trusted time must never step backwards past what the station has
    // already witnessed: a rolled-back clock re-enables expired jobs.
    if Entries[i].UTC > TrustedUTC then
    begin
      ErrMsg := Format(
        'trusted time %d is earlier than already-recorded time %d; the ' +
        'station clock has moved backwards', [TrustedUTC, Entries[i].UTC]);
      Exit;
    end;
  end;

  Result := True;
end;

function CheckProductionAdmission(const Entries: TProdStateEntries;
  const JobID: string; Revision: cardinal; const RunID, UID: string;
  TrustedUTC: QWord; out ErrMsg: string): boolean;
var
  i: SizeInt;
begin
  Result := False;

  if not CheckJobFreshness(Entries, JobID, Revision, TrustedUTC,
                           ErrMsg) then Exit;
  if not ValidStateIdentifier(RunID) then
  begin
    ErrMsg := 'production state run ID is not a safe identifier';
    Exit;
  end;
  if not ValidStateUID(UID) then
  begin
    ErrMsg := 'production state UID must be uppercase hex or "none"';
    Exit;
  end;

  for i := 0 to High(Entries) do
  begin
    if Entries[i].RunID = RunID then
    begin
      ErrMsg := 'this run ID has already been recorded';
      Exit;
    end;
    if (UID <> 'none') and (Entries[i].UID = UID) then
    begin
      ErrMsg := 'a unit with this chip UID has already passed';
      Exit;
    end;
  end;

  Result := True;
end;

function AppendProductionState(const FileName: string; const Key: TBytes;
  const JobID: string; Revision: cardinal; const RunID, UID: string;
  TrustedUTC: QWord; out ErrMsg: string): boolean;
var
  Entries: TProdStateEntries;
  PrevMAC, MAC: TSHA256Digest;
  Body, LineText: RawByteString;
  Stream: TFileStream;
  Mode: word;
begin
  Result := False;

  if not LoadProductionStateEx(FileName, Key, Entries, PrevMAC,
                               ErrMsg) then Exit;
  if not CheckProductionAdmission(Entries, JobID, Revision, RunID, UID,
                                  TrustedUTC, ErrMsg) then Exit;

  Body := LineBody(cardinal(Length(Entries) + 1), JobID, Revision, RunID,
                   UID, TrustedUTC);
  if not ChainMAC(Key, PrevMAC, Body, MAC, ErrMsg) then Exit;
  LineText := Body + #9 + DigestToHex(MAC) + #10;

  try
    if FileExists(FileName) then
      Mode := fmOpenReadWrite or fmShareDenyWrite
    else
      Mode := fmCreate or fmShareDenyWrite;
    Stream := TFileStream.Create(FileName, Mode);
    try
      Stream.Seek(0, soEnd);
      Stream.WriteBuffer(LineText[1], Length(LineText));
      {$IFDEF WINDOWS}
      if not FlushFileBuffers(Stream.Handle) then
      begin
        ErrMsg := 'the production state append could not be flushed to disk';
        Exit;
      end;
      {$ELSE}
      if fpfsync(Stream.Handle) <> 0 then
      begin
        ErrMsg := 'the production state append could not be flushed to disk';
        Exit;
      end;
      {$ENDIF}
    finally
      Stream.Free;
    end;
  except
    on Ex: Exception do
    begin
      ErrMsg := 'cannot append to the production state file: ' + Ex.Message;
      Exit;
    end;
  end;

  //สมอหัวโซ่ต้องตามบรรทัดใหม่ไป ถ้าเขียนสมอไม่สำเร็จ การโหลดครั้งถัดไปจะ
  //fail closed ซึ่งถูกต้อง: สถานะที่สมอไม่ตรงห้ามใช้ตัดสินการผลิต
  Result := WriteHeadAnchor(FileName, MAC, ErrMsg);
end;

end.
