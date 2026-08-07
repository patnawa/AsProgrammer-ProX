unit writejournal;

// What a write had done when the cable came out.
//
// Step 8 of the write chain is erase-and-program. If USB drops halfway
// through, the chip is in a state nothing in this program can describe: some
// blocks erased, some programmed, some untouched, and no record of which. The
// backup is intact and the manifest says what the chip used to hold, so the
// data is recoverable -- but only by writing the whole part again, which on a
// 16 MiB chip is minutes of work to redo something that was nearly finished,
// and which is itself another chance to be interrupted.
//
// So this records the accepted plan and the units completed under it, as they
// complete, and decides afterwards what is left to do.
//
// The format is append-only, and that is the entire design. A journal that
// rewrote itself after each block would have a window in which the file is
// half old and half new, and the crash this unit exists for is exactly the
// crash that lands in that window. Instead a header is written once and each
// completed unit is one appended line. A journal torn mid-line loses that
// line, which costs one repeated block.
//
// That is safe because every unit recorded here is idempotent: erasing an
// erased block sets it to FF again, and programming a page with the bytes it
// already holds writes the same bytes. Re-doing a unit that was in fact
// finished is wasted time and nothing else. Losing a unit that was *not*
// finished would be data loss, which is why the loss always goes the safe way
// -- a line only counts once its terminating newline is on disk.
//
// The refusals are the other half. A resume is only safe if nothing has moved
// underneath it, so the journal pins the chip identity, the chip capacity,
// the image and its address, and the backup with its hash. If the part in the
// socket answers differently, or the image loaded is not the image planned,
// or the backup no longer matches its manifest, this refuses and says which.
// A resume that guesses is worse than starting again.
//
// The parsing and the deciding are pure and take strings; only the two file
// helpers at the end touch a disk.
//
// No hardware access and no LCL unit is used here.

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, StrUtils;

const
  JOURNAL_MAGIC = 'chipwright-write-journal/1';
  // Long enough for a whole-chip plan on the largest part this program
  // handles, and short enough that a corrupt length field cannot ask for a
  // gigabyte of records.
  MAX_JOURNAL_MARKS = 1024 * 1024;

type
  TJournalLines = array of string;

  TJournalUnitKind = (
    juErase,
    juProgram
  );

  // One completed unit of work.
  TJournalMark = record
    Kind: TJournalUnitKind;
    Address: QWord;
    Length: QWord;
  end;

  TJournalMarks = array of TJournalMark;

  // Everything that has to still be true for a resume to be safe.
  TJournalHeader = record
    Valid: boolean;

    ProgramVersion: string;
    StartedUtc: string;

    ChipName: string;
    ChipJedecID: string;
    ChipCapacity: QWord;

    // The image this plan was made for, and where it goes. A resume against a
    // different image would program the tail of one file over the head of
    // another and verify each half against the wrong source.
    ImageSha256: string;
    Address: QWord;
    Length: QWord;

    // Recovery depends on this file. If it has moved or changed, a resume is
    // a write with no way back.
    BackupPath: string;
    BackupSha256: string;
  end;

  TWriteJournal = record
    Header: TJournalHeader;
    Marks: TJournalMarks;
  end;

  TResumeVerdict = (
    rvResume,        // work remains and it is safe to continue
    rvNothingToDo,   // the journal covers the whole plan already
    rvRefuse         // something moved; say what and start again
  );

// --- the document ---

// The header, as the lines that open a journal file. Written once.
function HeaderLines(const Header: TJournalHeader): TJournalLines;

// One completed unit, as the line appended when it completes.
function MarkLine(const Mark: TJournalMark): string;

// Reads a journal back.
//
// Lines must already have had any partial trailing line dropped -- see
// SplitCompleteLines, which is the only correct way to produce them. A
// malformed mark line is not an error: it is a line that was being written
// when the power went, so it and everything after it are discarded. A
// malformed *header* is an error, because a journal whose identity cannot be
// read cannot be checked against anything.
function ParseJournal(const Lines: array of string;
  out Journal: TWriteJournal; out ErrMsg: string): boolean;

// Splits a raw file into whole lines, discarding a trailing fragment.
//
// This is where the append-only design is actually enforced. A line counts
// only once its terminating newline reached the disk; anything after the last
// newline was in flight when the machine stopped and must be treated as work
// that did not happen.
function SplitCompleteLines(const Raw: string): TJournalLines;

// --- the decision ---

// Whether the journal may be resumed, and what is left.
//
// Plan is the freshly computed unit list for this job. It is recomputed
// rather than stored, because the planner is deterministic given the same
// chip, image, address and length -- all four of which the header pins -- and
// a stored plan is one more thing that can disagree with the code that made
// it.
//
// Remaining comes back in the plan's own order, which is the order the
// engine wants: erases before the programs that depend on them.
function DecideResume(const Journal: TWriteJournal;
  const Plan: TJournalMarks;
  const LiveChipJedecID: string; LiveChipCapacity: QWord;
  const LiveImageSha256, LiveBackupSha256: string;
  out Remaining: TJournalMarks; out Reason: string): TResumeVerdict;

// True when two units are the same piece of work. Address and length must
// match exactly: a program of 256 bytes at 0x1000 is not covered by a
// journal entry for 4096 bytes at 0x1000, because the engine that wrote that
// entry was doing something else.
function SameUnit(const A, B: TJournalMark): boolean;

function JournalUnitKindName(Kind: TJournalUnitKind): string;

// --- the two things that touch a disk ---

// Starts a journal, replacing any previous one for this job.
function BeginJournal(const FileName: string; const Header: TJournalHeader;
  out ErrMsg: string): boolean;

// Appends one completed unit and flushes it.
//
// Flushing on every unit is the point and is not negotiable for performance:
// a buffered journal describes a chip state that may be several blocks behind
// the real one, and the direction of that error is the unsafe one -- it says
// work was not done when it was, which is harmless, but a *reordered* buffer
// could say work was done when it was not.
function AppendJournalMark(const FileName: string;
  const Mark: TJournalMark; out ErrMsg: string): boolean;

// Reads a journal file. A missing file is not an error; it is the ordinary
// case of a job that has not been interrupted.
function LoadJournal(const FileName: string; out Journal: TWriteJournal;
  out Found: boolean; out ErrMsg: string): boolean;

implementation

const
  KEY_PROGRAM   = 'program=';
  KEY_STARTED   = 'started=';
  KEY_CHIP      = 'chip=';
  KEY_JEDEC     = 'jedec=';
  KEY_CAPACITY  = 'capacity=';
  KEY_IMAGE     = 'image_sha256=';
  KEY_ADDRESS   = 'address=';
  KEY_LENGTH    = 'length=';
  KEY_BACKUP    = 'backup=';
  KEY_BACKUPSHA = 'backup_sha256=';
  MARKS_MARKER  = '--';

function JournalUnitKindName(Kind: TJournalUnitKind): string;
begin
  case Kind of
    juErase:   Result := 'erase';
    juProgram: Result := 'program';
  else
    Result := '';
  end;
end;

function SameUnit(const A, B: TJournalMark): boolean;
begin
  Result := (A.Kind = B.Kind) and (A.Address = B.Address) and
            (A.Length = B.Length);
end;

// -------------------------------------------------------------- writing

function UIntText(Value: QWord): string;
begin
  Result := IntToStr(Value);
end;

function HeaderLines(const Header: TJournalHeader): TJournalLines;

  procedure Add(const Line: string);
  var
    N: integer;
  begin
    N := Length(Result);
    SetLength(Result, N + 1);
    Result[N] := Line;
  end;

begin
  Result := nil;
  Add(JOURNAL_MAGIC);
  Add(KEY_PROGRAM + Header.ProgramVersion);
  Add(KEY_STARTED + Header.StartedUtc);
  Add(KEY_CHIP + Header.ChipName);
  Add(KEY_JEDEC + Header.ChipJedecID);
  Add(KEY_CAPACITY + UIntText(Header.ChipCapacity));
  Add(KEY_IMAGE + Header.ImageSha256);
  Add(KEY_ADDRESS + UIntText(Header.Address));
  Add(KEY_LENGTH + UIntText(Header.Length));
  Add(KEY_BACKUP + Header.BackupPath);
  Add(KEY_BACKUPSHA + Header.BackupSha256);
  Add(MARKS_MARKER);
end;

function MarkLine(const Mark: TJournalMark): string;
begin
  Result := JournalUnitKindName(Mark.Kind) + ' ' +
            UIntText(Mark.Address) + ' ' + UIntText(Mark.Length);
end;

// -------------------------------------------------------------- reading

function SplitCompleteLines(const Raw: string): TJournalLines;
var
  Start, i, N: integer;
  Line: string;
begin
  Result := nil;
  Start := 1;
  for i := 1 to Length(Raw) do
    if Raw[i] = #10 then
    begin
      Line := Copy(Raw, Start, i - Start);
      //A file written on Windows and read here, or the reverse; the CR is not
      //part of the value either way.
      if (Length(Line) > 0) and (Line[Length(Line)] = #13) then
        SetLength(Line, Length(Line) - 1);
      N := Length(Result);
      SetLength(Result, N + 1);
      Result[N] := Line;
      Start := i + 1;
    end;
  //Anything after the last newline was in flight when the machine stopped.
  //Dropping it is the whole reason this function exists.
end;

function StrictQWord(const Value: string; out Number: QWord): boolean;
var
  i: integer;
  Digit: byte;
begin
  Result := False;
  Number := 0;
  if Value = '' then Exit;
  //A leading zero would let '0010' and '10' both parse, which means two
  //different files could describe the same journal.
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

function TakeValue(const Line, Key: string; out Value: string): boolean;
begin
  Value := '';
  Result := Copy(Line, 1, Length(Key)) = Key;
  if Result then Value := Copy(Line, Length(Key) + 1, Length(Line));
end;

function IsLowerHex64(const Value: string): boolean;
var
  i: integer;
begin
  Result := False;
  if Length(Value) <> 64 then Exit;
  for i := 1 to 64 do
    if not (Value[i] in ['0'..'9', 'a'..'f']) then Exit;
  Result := True;
end;

function ParseMark(const Line: string; out Mark: TJournalMark): boolean;
var
  FirstSpace, SecondSpace: integer;
  Kind, AddrText, LenText: string;
begin
  Mark := Default(TJournalMark);
  Result := False;

  FirstSpace := Pos(' ', Line);
  if FirstSpace < 2 then Exit;
  Kind := Copy(Line, 1, FirstSpace - 1);
  SecondSpace := PosEx(' ', Line, FirstSpace + 1);
  if SecondSpace < FirstSpace + 2 then Exit;

  AddrText := Copy(Line, FirstSpace + 1, SecondSpace - FirstSpace - 1);
  LenText := Copy(Line, SecondSpace + 1, Length(Line));

  if Kind = 'erase' then Mark.Kind := juErase
  else if Kind = 'program' then Mark.Kind := juProgram
  else Exit;

  if not StrictQWord(AddrText, Mark.Address) then Exit;
  if not StrictQWord(LenText, Mark.Length) then Exit;
  //A zero-length unit is not a unit. Admitting one would let a corrupt line
  //mark an address as done without any work having covered it.
  if Mark.Length = 0 then Exit;

  Result := True;
end;

function ParseJournal(const Lines: array of string;
  out Journal: TWriteJournal; out ErrMsg: string): boolean;
var
  i, Cursor: integer;
  Value: string;
  Mark: TJournalMark;
  N: integer;

  function Need(const Key: string; out Text: string): boolean;
  begin
    Result := False;
    Text := '';
    if Cursor > High(Lines) then
    begin
      ErrMsg := 'the journal ends before ' + Key;
      Exit;
    end;
    if not TakeValue(Lines[Cursor], Key, Text) then
    begin
      ErrMsg := 'expected ' + Key + ', found "' + Lines[Cursor] + '"';
      Exit;
    end;
    Inc(Cursor);
    Result := True;
  end;

begin
  Journal := Default(TWriteJournal);
  ErrMsg := '';
  Result := False;

  if Length(Lines) = 0 then
  begin
    ErrMsg := 'the journal is empty';
    Exit;
  end;
  if Lines[0] <> JOURNAL_MAGIC then
  begin
    //Either not a journal, or one written by a version whose format this
    //build does not know. Both mean the same thing here: do not act on it.
    ErrMsg := 'not a ' + JOURNAL_MAGIC + ' file';
    Exit;
  end;

  Cursor := 1;
  if not Need(KEY_PROGRAM, Journal.Header.ProgramVersion) then Exit;
  if not Need(KEY_STARTED, Journal.Header.StartedUtc) then Exit;
  if not Need(KEY_CHIP, Journal.Header.ChipName) then Exit;
  if not Need(KEY_JEDEC, Journal.Header.ChipJedecID) then Exit;
  if not Need(KEY_CAPACITY, Value) then Exit;
  if not StrictQWord(Value, Journal.Header.ChipCapacity) then
  begin
    ErrMsg := 'the recorded chip capacity is not a number';
    Exit;
  end;
  if not Need(KEY_IMAGE, Journal.Header.ImageSha256) then Exit;
  if not Need(KEY_ADDRESS, Value) then Exit;
  if not StrictQWord(Value, Journal.Header.Address) then
  begin
    ErrMsg := 'the recorded address is not a number';
    Exit;
  end;
  if not Need(KEY_LENGTH, Value) then Exit;
  if not StrictQWord(Value, Journal.Header.Length) then
  begin
    ErrMsg := 'the recorded length is not a number';
    Exit;
  end;
  if not Need(KEY_BACKUP, Journal.Header.BackupPath) then Exit;
  if not Need(KEY_BACKUPSHA, Journal.Header.BackupSha256) then Exit;

  if (Cursor > High(Lines)) or (Lines[Cursor] <> MARKS_MARKER) then
  begin
    ErrMsg := 'the journal header is not terminated';
    Exit;
  end;
  Inc(Cursor);

  //Identity fields have to be present and well formed, or there is nothing to
  //check the socket against.
  if not IsLowerHex64(Journal.Header.ImageSha256) then
  begin
    ErrMsg := 'the recorded image hash is not a SHA-256';
    Exit;
  end;
  if not IsLowerHex64(Journal.Header.BackupSha256) then
  begin
    ErrMsg := 'the recorded backup hash is not a SHA-256';
    Exit;
  end;
  if (Journal.Header.ChipJedecID = '') or (Journal.Header.BackupPath = '') then
  begin
    ErrMsg := 'the journal names no chip identity or no backup';
    Exit;
  end;
  if Journal.Header.Length = 0 then
  begin
    ErrMsg := 'the journal records a zero-length write';
    Exit;
  end;

  N := 0;
  SetLength(Journal.Marks, 0);
  for i := Cursor to High(Lines) do
  begin
    if Lines[i] = '' then Continue;
    if not ParseMark(Lines[i], Mark) then
      //Not an error. A line that does not parse is a line that was being
      //written when the power went, and nothing after it can be trusted
      //either -- the file was appended to in order.
      Break;
    if N >= MAX_JOURNAL_MARKS then Break;
    SetLength(Journal.Marks, N + 1);
    Journal.Marks[N] := Mark;
    Inc(N);
  end;

  Journal.Header.Valid := True;
  Result := True;
end;

// ------------------------------------------------------------- deciding

function DecideResume(const Journal: TWriteJournal;
  const Plan: TJournalMarks;
  const LiveChipJedecID: string; LiveChipCapacity: QWord;
  const LiveImageSha256, LiveBackupSha256: string;
  out Remaining: TJournalMarks; out Reason: string): TResumeVerdict;
var
  i, j, N: integer;
  Done: boolean;
begin
  Remaining := nil;
  Reason := '';

  if not Journal.Header.Valid then
  begin
    Reason := 'the journal could not be read';
    Exit(rvRefuse);
  end;

  //Each of these is a way the world can have moved between the interruption
  //and now, and each of them makes a resume a different operation from the
  //one that was planned.

  //The part in the socket. Somebody unplugging a programmer mid-write and
  //seating a different chip is not a strange scenario; it is what happens
  //when the first chip is presumed dead.
  if not SameText(Journal.Header.ChipJedecID, LiveChipJedecID) then
  begin
    Reason := Format('the journal was written for a chip answering %s; ' +
                     'this one answers %s',
                     [Journal.Header.ChipJedecID, LiveChipJedecID]);
    Exit(rvRefuse);
  end;
  if (LiveChipCapacity <> 0) and
     (Journal.Header.ChipCapacity <> LiveChipCapacity) then
  begin
    //Same identity, different capacity: one of the two readings is wrong, and
    //resuming would program past the end of a smaller part.
    Reason := Format('the journal records a %d byte chip; this one is %d',
                     [Journal.Header.ChipCapacity, LiveChipCapacity]);
    Exit(rvRefuse);
  end;

  //The image. Resuming against a different one programs the tail of one file
  //over the head of another, and verifies each half against the wrong source.
  if not SameText(Journal.Header.ImageSha256, LiveImageSha256) then
  begin
    Reason := 'the image loaded now is not the image this write was planned ' +
              'for';
    Exit(rvRefuse);
  end;

  //The backup. This is the one that would be tempting to skip, and it is the
  //one that matters most: resuming without a matching backup is a write with
  //no way back, on a chip that is already half-written.
  if not SameText(Journal.Header.BackupSha256, LiveBackupSha256) then
  begin
    Reason := Format('the backup at %s no longer matches the hash recorded ' +
                     'with it; recovery depends on that file',
                     [Journal.Header.BackupPath]);
    Exit(rvRefuse);
  end;

  if Length(Plan) = 0 then
  begin
    Reason := 'there is no plan to resume';
    Exit(rvRefuse);
  end;

  N := 0;
  SetLength(Remaining, Length(Plan));
  for i := 0 to High(Plan) do
  begin
    Done := False;
    for j := 0 to High(Journal.Marks) do
      if SameUnit(Plan[i], Journal.Marks[j]) then
      begin
        Done := True;
        Break;
      end;
    if Done then Continue;
    //Plan order is preserved: the engine needs erases before the programs
    //that depend on them, and re-sorting here would be this unit deciding
    //something it has no business deciding.
    Remaining[N] := Plan[i];
    Inc(N);
  end;
  SetLength(Remaining, N);

  if N = 0 then
  begin
    Reason := 'every unit in the plan is already recorded as done';
    Exit(rvNothingToDo);
  end;

  Reason := Format('%d of %d units remain', [N, Length(Plan)]);
  Result := rvResume;
end;

// ------------------------------------------------------------- the disk

function BeginJournal(const FileName: string; const Header: TJournalHeader;
  out ErrMsg: string): boolean;
var
  Lines: TJournalLines;
  Text: TStringList;
  i: integer;
begin
  ErrMsg := '';
  Result := False;
  Lines := HeaderLines(Header);
  Text := TStringList.Create;
  try
    try
      for i := 0 to High(Lines) do Text.Add(Lines[i]);
      //LF endings, written the same way on every platform, so a journal
      //written on one machine parses on another.
      Text.LineBreak := #10;
      Text.SaveToFile(FileName);
      Result := True;
    except
      on E: Exception do ErrMsg := 'could not start the write journal: ' +
                                   E.Message;
    end;
  finally
    Text.Free;
  end;
end;

function AppendJournalMark(const FileName: string;
  const Mark: TJournalMark; out ErrMsg: string): boolean;
var
  Stream: TFileStream;
  Line: RawByteString;
begin
  ErrMsg := '';
  Result := False;
  if not FileExists(FileName) then
  begin
    ErrMsg := 'the write journal is missing';
    Exit;
  end;
  try
    Stream := TFileStream.Create(FileName, fmOpenReadWrite or fmShareDenyWrite);
    try
      Stream.Seek(0, soEnd);
      //The newline is written in the same call as the text, so the two cannot
      //be separated by a crash: a torn write loses the whole line, which
      //SplitCompleteLines then discards, which costs one repeated block.
      Line := MarkLine(Mark) + #10;
      Stream.WriteBuffer(Line[1], Length(Line));
      //Flushed to the device, not merely to the operating system's cache.
      //A buffered journal describes a chip state several blocks behind the
      //real one, which is the whole thing this file exists to avoid.
      FileFlush(Stream.Handle);
      Result := True;
    finally
      Stream.Free;
    end;
  except
    on E: Exception do ErrMsg := 'could not record progress: ' + E.Message;
  end;
end;

function LoadJournal(const FileName: string; out Journal: TWriteJournal;
  out Found: boolean; out ErrMsg: string): boolean;
var
  Stream: TFileStream;
  Raw: RawByteString;
begin
  Journal := Default(TWriteJournal);
  Found := False;
  ErrMsg := '';
  Result := False;

  //A job that was never interrupted has no journal, and that is the ordinary
  //case rather than a fault.
  if not FileExists(FileName) then Exit(True);
  Found := True;

  try
    Stream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
    try
      SetLength(Raw, Stream.Size);
      if Stream.Size > 0 then Stream.ReadBuffer(Raw[1], Stream.Size);
    finally
      Stream.Free;
    end;
  except
    on E: Exception do
    begin
      ErrMsg := 'could not read the write journal: ' + E.Message;
      Exit;
    end;
  end;

  Result := ParseJournal(SplitCompleteLines(Raw), Journal, ErrMsg);
end;

end.
