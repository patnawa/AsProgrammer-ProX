program writejournal_tests;

// Resuming a write that was interrupted, and refusing to when it would be a
// different write.
//
// Two properties carry this suite.
//
// The first is that a torn journal loses work rather than inventing it. A
// line only counts once its newline is on disk, so a crash mid-append costs
// one repeated block -- and repeating a block is free, because erasing an
// erased block and programming a page with the bytes it already holds are
// both idempotent. The opposite error, a line surviving for work that did not
// finish, is data loss, and these tests hold the loss to the safe direction.
//
// The second is the set of refusals. A resume is only the same operation as
// the one that was planned if the chip, the capacity, the image and the
// backup are all still what they were. Each is tested on its own, and the
// backup one matters most: resuming without it is a write with no way back,
// on a chip that is already half written.

{$mode objfpc}{$H+}

uses
  SysUtils, writejournal;

var
  Failures, Assertions: integer;

procedure Check(const Name: string; Condition: boolean);
begin
  Inc(Assertions);
  if not Condition then
  begin
    Inc(Failures);
    WriteLn('FAIL: ', Name);
  end;
end;

const
  IMAGE_SHA  = '9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08';
  BACKUP_SHA = '60303ae22b998861bce3b28f33eec1be758a213c86c93c076dbe9f558c11c752';

function SampleHeader: TJournalHeader;
begin
  Result := Default(TJournalHeader);
  Result.ProgramVersion := '4.36.0.0';
  Result.StartedUtc := '2026-08-07T09:15:00Z';
  Result.ChipName := 'W25Q64FW';
  Result.ChipJedecID := 'EF6017';
  Result.ChipCapacity := 8 * 1024 * 1024;
  Result.ImageSha256 := IMAGE_SHA;
  Result.Address := 0;
  Result.Length := 8 * 1024 * 1024;
  Result.BackupPath := 'backup/W25Q64FW-20260807.bin';
  Result.BackupSha256 := BACKUP_SHA;
end;

function Unit_(Kind: TJournalUnitKind; Addr, Len: QWord): TJournalMark;
begin
  Result.Kind := Kind;
  Result.Address := Addr;
  Result.Length := Len;
end;

// A four-unit plan: erase two sectors, then program a page in each.
function SamplePlan: TJournalMarks;
begin
  Result := nil;
  SetLength(Result, 4);
  Result[0] := Unit_(juErase, 0, 4096);
  Result[1] := Unit_(juErase, 4096, 4096);
  Result[2] := Unit_(juProgram, 0, 256);
  Result[3] := Unit_(juProgram, 4096, 256);
end;

// The raw bytes of a journal with the given completed units appended.
function RawJournal(const Header: TJournalHeader;
  const Marks: TJournalMarks; TruncateLast: boolean): string;
var
  Lines: TJournalLines;
  i: integer;
begin
  Result := '';
  Lines := HeaderLines(Header);
  for i := 0 to High(Lines) do Result := Result + Lines[i] + #10;
  for i := 0 to High(Marks) do
    if TruncateLast and (i = High(Marks)) then
      //The crash case: the text of the last line reached the disk and its
      //newline did not.
      Result := Result + MarkLine(Marks[i])
    else
      Result := Result + MarkLine(Marks[i]) + #10;
end;

function LoadFrom(const Raw: string; out J: TWriteJournal): boolean;
var
  ErrMsg: string;
begin
  Result := ParseJournal(SplitCompleteLines(Raw), J, ErrMsg);
end;

// ---------------------------------------------------- the append-only rule

procedure TestATornLineIsWorkThatDidNotHappen;
var
  J: TWriteJournal;
  Marks, Remaining: TJournalMarks;
  Verdict: TResumeVerdict;
  Reason: string;
begin
  WriteLn('A line without its newline is work that did not happen');

  Marks := nil;
  SetLength(Marks, 3);
  Marks[0] := Unit_(juErase, 0, 4096);
  Marks[1] := Unit_(juErase, 4096, 4096);
  Marks[2] := Unit_(juProgram, 0, 256);

  //Whole file: all three count.
  Check('a complete journal is read',
        LoadFrom(RawJournal(SampleHeader, Marks, False), J));
  Check('and all three units are recorded', Length(J.Marks) = 3);

  //Torn: the last line was in flight, so it does not count.
  Check('a torn journal is still read',
        LoadFrom(RawJournal(SampleHeader, Marks, True), J));
  Check('and the torn line is dropped', Length(J.Marks) = 2);

  //Which costs exactly one repeated unit, and nothing else. Repeating is
  //free: erasing an erased block sets it to FF again, and programming a page
  //with the bytes it already holds writes the same bytes.
  Verdict := DecideResume(J, SamplePlan, 'EF6017', 8 * 1024 * 1024,
                          IMAGE_SHA, BACKUP_SHA, Remaining, Reason);
  Check('the resume goes ahead', Verdict = rvResume);
  Check('and repeats the dropped unit', Length(Remaining) = 2);
  Check('starting with the one that was torn',
        SameUnit(Remaining[0], Unit_(juProgram, 0, 256)));
end;

procedure TestAMalformedLineStopsTheReplay;
var
  J: TWriteJournal;
  Raw: string;
  Marks: TJournalMarks;
begin
  WriteLn('Nothing after an unreadable line is trusted');

  Marks := nil;
  SetLength(Marks, 1);
  Marks[0] := Unit_(juErase, 0, 4096);
  Raw := RawJournal(SampleHeader, Marks, False);
  //A half-written line followed by a whole one. Either way, the file is no
  //longer a record of the order the work was done in.
  Raw := Raw + 'era' + #10 + MarkLine(Unit_(juProgram, 0, 256)) + #10;

  Check('the journal is still read', LoadFrom(Raw, J));
  Check('the good line before it counts', Length(J.Marks) = 1);
  Check('and it is the right one',
        SameUnit(J.Marks[0], Unit_(juErase, 0, 4096)));
end;

procedure TestGarbageMarksAreRefusedIndividually;
var
  J: TWriteJournal;
  Raw: string;
  Marks: TJournalMarks;
begin
  WriteLn('A mark has to be a whole, plausible unit of work');
  Marks := nil;

  //A zero-length unit is not a unit. Admitting one would let a corrupt line
  //mark an address as done without any work having covered it.
  Raw := RawJournal(SampleHeader, Marks, False) + 'erase 0 0' + #10;
  Check('a zero-length mark is not a unit',
        LoadFrom(Raw, J) and (Length(J.Marks) = 0));

  Raw := RawJournal(SampleHeader, Marks, False) + 'wipe 0 4096' + #10;
  Check('an unknown kind is refused',
        LoadFrom(Raw, J) and (Length(J.Marks) = 0));

  //A leading zero would let two different files describe the same journal.
  Raw := RawJournal(SampleHeader, Marks, False) + 'erase 00 4096' + #10;
  Check('a non-canonical number is refused',
        LoadFrom(Raw, J) and (Length(J.Marks) = 0));

  Raw := RawJournal(SampleHeader, Marks, False) + 'erase 0' + #10;
  Check('a mark missing its length is refused',
        LoadFrom(Raw, J) and (Length(J.Marks) = 0));
end;

// --------------------------------------------------------- the header

procedure TestAnUnreadableHeaderIsAnError;
var
  J: TWriteJournal;
  ErrMsg: string;
  Lines: TJournalLines;
begin
  WriteLn('A journal whose identity cannot be read is an error, not a warning');

  //Unlike a mark, a header cannot be partly trusted: it is what the socket is
  //checked against, so an unreadable one leaves nothing to check.
  Check('an empty file is refused',
        not ParseJournal(SplitCompleteLines(''), J, ErrMsg));
  Check('and says so', Pos('empty', ErrMsg) > 0);

  Check('a file with the wrong magic is refused',
        not ParseJournal(SplitCompleteLines('something else' + #10), J, ErrMsg));

  //A header that stops halfway is a file from a crash during BeginJournal,
  //before any work started. Refusing means the job starts over, which is
  //correct: nothing had been done.
  Lines := HeaderLines(SampleHeader);
  SetLength(Lines, 4);
  Check('a truncated header is refused', not ParseJournal(Lines, J, ErrMsg));

  //Hashes must be well formed, or the comparisons that protect the resume
  //would be comparing one piece of nonsense against another.
  Lines := HeaderLines(SampleHeader);
  Lines[6] := 'image_sha256=notahash';
  Check('a malformed image hash is refused',
        not ParseJournal(Lines, J, ErrMsg));
  Check('and says which', Pos('image hash', ErrMsg) > 0);

  Lines := HeaderLines(SampleHeader);
  Lines[10] := 'backup_sha256=';
  Check('a missing backup hash is refused',
        not ParseJournal(Lines, J, ErrMsg));
end;

procedure TestAJournalRoundTrips;
var
  J: TWriteJournal;
  Marks: TJournalMarks;
begin
  WriteLn('Everything written into the header comes back out of it');
  Marks := nil;
  SetLength(Marks, 1);
  Marks[0] := Unit_(juProgram, 65536, 256);

  Check('it is read', LoadFrom(RawJournal(SampleHeader, Marks, False), J));
  Check('the chip name', J.Header.ChipName = 'W25Q64FW');
  Check('the identity', J.Header.ChipJedecID = 'EF6017');
  Check('the capacity', J.Header.ChipCapacity = 8 * 1024 * 1024);
  Check('the image hash', J.Header.ImageSha256 = IMAGE_SHA);
  Check('the address', J.Header.Address = 0);
  Check('the length', J.Header.Length = 8 * 1024 * 1024);
  Check('the backup path',
        J.Header.BackupPath = 'backup/W25Q64FW-20260807.bin');
  Check('the backup hash', J.Header.BackupSha256 = BACKUP_SHA);
  Check('and the mark', (Length(J.Marks) = 1) and
        SameUnit(J.Marks[0], Unit_(juProgram, 65536, 256)));
end;

// ------------------------------------------------------- the refusals

procedure TestEveryWayTheWorldCanHaveMoved;
var
  J: TWriteJournal;
  Marks, Remaining: TJournalMarks;
  Reason: string;
begin
  WriteLn('A resume is refused whenever it would be a different write');
  Marks := nil;
  SetLength(Marks, 1);
  Marks[0] := Unit_(juErase, 0, 4096);
  Check('the journal is read',
        LoadFrom(RawJournal(SampleHeader, Marks, False), J));

  //A different part in the socket. Not a strange scenario: it is what happens
  //when the first chip is presumed dead and swapped out.
  Check('a different chip is refused',
        DecideResume(J, SamplePlan, 'EF4017', 8 * 1024 * 1024,
                     IMAGE_SHA, BACKUP_SHA, Remaining, Reason) = rvRefuse);
  Check('and it names both identities',
        (Pos('EF6017', Reason) > 0) and (Pos('EF4017', Reason) > 0));

  //Same identity, different capacity: one reading is wrong, and resuming
  //would program past the end of a smaller part.
  Check('a different capacity is refused',
        DecideResume(J, SamplePlan, 'EF6017', 4 * 1024 * 1024,
                     IMAGE_SHA, BACKUP_SHA, Remaining, Reason) = rvRefuse);

  //A different image programs the tail of one file over the head of another,
  //and verifies each half against the wrong source.
  Check('a different image is refused',
        DecideResume(J, SamplePlan, 'EF6017', 8 * 1024 * 1024,
                     BACKUP_SHA, BACKUP_SHA, Remaining, Reason) = rvRefuse);
  Check('and says the image is not the one planned for',
        Pos('not the image', Reason) > 0);

  //The one it would be tempting to skip, and the one that matters most.
  Check('a backup that no longer matches is refused',
        DecideResume(J, SamplePlan, 'EF6017', 8 * 1024 * 1024,
                     IMAGE_SHA, IMAGE_SHA, Remaining, Reason) = rvRefuse);
  Check('and names the file recovery depends on',
        Pos('backup/W25Q64FW-20260807.bin', Reason) > 0);
  Check('and says why it matters', Pos('recovery depends', Reason) > 0);

  //And nothing comes back to act on in any refusal.
  Check('a refusal hands back no work', Length(Remaining) = 0);
end;

procedure TestAnUnknownCapacityDoesNotRefuse;
var
  J: TWriteJournal;
  Marks, Remaining: TJournalMarks;
  Reason: string;
begin
  WriteLn('A capacity nobody read is not a capacity that disagrees');
  Marks := nil;
  Check('the journal is read',
        LoadFrom(RawJournal(SampleHeader, Marks, False), J));

  //Zero means the caller has not established it. Treating that as a mismatch
  //would refuse every resume on a path that happens not to report capacity,
  //which teaches people to bypass the check.
  Check('an unknown capacity is not a conflict',
        DecideResume(J, SamplePlan, 'EF6017', 0,
                     IMAGE_SHA, BACKUP_SHA, Remaining, Reason) = rvResume);
end;

// ---------------------------------------------------------- what is left

procedure TestOnlyExactUnitsCountAsDone;
var
  J: TWriteJournal;
  Marks, Remaining: TJournalMarks;
  Reason: string;
begin
  WriteLn('A unit counts as done only if it is the same piece of work');
  Marks := nil;
  SetLength(Marks, 1);
  //A 4096-byte erase at 0 does not cover a 256-byte program at 0: the engine
  //that wrote that entry was doing something else entirely.
  Marks[0] := Unit_(juErase, 0, 4096);
  Check('the journal is read',
        LoadFrom(RawJournal(SampleHeader, Marks, False), J));

  Check('the resume goes ahead',
        DecideResume(J, SamplePlan, 'EF6017', 8 * 1024 * 1024,
                     IMAGE_SHA, BACKUP_SHA, Remaining, Reason) = rvResume);
  Check('three of four units remain', Length(Remaining) = 3);
  Check('the erase at 0 is not repeated',
        not SameUnit(Remaining[0], Unit_(juErase, 0, 4096)));
  Check('but the program at 0 still is',
        SameUnit(Remaining[1], Unit_(juProgram, 0, 256)));

  Check('the count is reported', Pos('3 of 4', Reason) > 0);

  //Order is the plan's order, not the journal's: the engine needs erases
  //before the programs that depend on them.
  Check('erases still come before their programs',
        (Remaining[0].Kind = juErase) and (Remaining[2].Kind = juProgram));
end;

procedure TestACompleteJournalHasNothingToDo;
var
  J: TWriteJournal;
  Remaining: TJournalMarks;
  Reason: string;
begin
  WriteLn('A journal covering the whole plan is finished, not resumable');
  Check('the journal is read',
        LoadFrom(RawJournal(SampleHeader, SamplePlan, False), J));

  //Distinct from a refusal, because the caller's next move differs: verify
  //and finish, rather than start again.
  Check('there is nothing to do',
        DecideResume(J, SamplePlan, 'EF6017', 8 * 1024 * 1024,
                     IMAGE_SHA, BACKUP_SHA, Remaining, Reason) = rvNothingToDo);
  Check('and nothing is handed back', Length(Remaining) = 0);
  Check('and it says so', Pos('already recorded as done', Reason) > 0);
end;

procedure TestAnEmptyPlanIsRefused;
var
  J: TWriteJournal;
  Empty, Remaining: TJournalMarks;
  Reason: string;
begin
  WriteLn('There has to be a plan to resume into');
  Empty := nil;
  Check('the journal is read',
        LoadFrom(RawJournal(SampleHeader, Empty, False), J));
  Check('an empty plan is refused',
        DecideResume(J, Empty, 'EF6017', 8 * 1024 * 1024,
                     IMAGE_SHA, BACKUP_SHA, Remaining, Reason) = rvRefuse);
end;

// ----------------------------------------------------------- on a disk

procedure TestTheFileRoundTrip;
var
  FileName, ErrMsg: string;
  J: TWriteJournal;
  Found: boolean;
  Remaining: TJournalMarks;
  Reason: string;
begin
  WriteLn('The same thing, through an actual file');
  FileName := GetTempDir + 'chipwright-journal-test.txt';
  DeleteFile(FileName);

  //A job that was never interrupted has no journal, and that is the ordinary
  //case rather than a fault.
  Check('a missing journal is not an error',
        LoadJournal(FileName, J, Found, ErrMsg) and (not Found));

  Check('a journal starts', BeginJournal(FileName, SampleHeader, ErrMsg));
  Check('it can be read back straight away',
        LoadJournal(FileName, J, Found, ErrMsg) and Found);
  Check('with no units done yet', Length(J.Marks) = 0);

  Check('a unit is appended',
        AppendJournalMark(FileName, Unit_(juErase, 0, 4096), ErrMsg));
  Check('and another',
        AppendJournalMark(FileName, Unit_(juErase, 4096, 4096), ErrMsg));

  Check('both come back', LoadJournal(FileName, J, Found, ErrMsg) and
        (Length(J.Marks) = 2));
  Check('in the order they were done',
        SameUnit(J.Marks[0], Unit_(juErase, 0, 4096)) and
        SameUnit(J.Marks[1], Unit_(juErase, 4096, 4096)));

  Check('and the resume knows what is left',
        (DecideResume(J, SamplePlan, 'EF6017', 8 * 1024 * 1024,
                      IMAGE_SHA, BACKUP_SHA, Remaining, Reason) = rvResume) and
        (Length(Remaining) = 2));

  //Starting a fresh journal for a new job must not leave the previous job's
  //completed units behind, or the new write would skip blocks.
  Check('a new journal replaces the old one',
        BeginJournal(FileName, SampleHeader, ErrMsg));
  Check('with no units carried over',
        LoadJournal(FileName, J, Found, ErrMsg) and (Length(J.Marks) = 0));

  //Appending to a journal that was never begun must fail rather than create
  //a headerless file that later parses as nothing.
  DeleteFile(FileName);
  Check('appending without a journal fails',
        not AppendJournalMark(FileName, Unit_(juErase, 0, 4096), ErrMsg));
  Check('and says so', ErrMsg <> '');

  DeleteFile(FileName);
end;

begin
  TestATornLineIsWorkThatDidNotHappen;
  TestAMalformedLineStopsTheReplay;
  TestGarbageMarksAreRefusedIndividually;
  TestAnUnreadableHeaderIsAnError;
  TestAJournalRoundTrips;
  TestEveryWayTheWorldCanHaveMoved;
  TestAnUnknownCapacityDoesNotRefuse;
  TestOnlyExactUnitsCountAsDone;
  TestACompleteJournalHasNothingToDo;
  TestAnEmptyPlanIsRefused;
  TestTheFileRoundTrip;
  WriteLn(Assertions, ' assertions, ', Failures, ' failures');
  if Failures <> 0 then Halt(1);
  WriteLn('ALL PASSED');
end.
