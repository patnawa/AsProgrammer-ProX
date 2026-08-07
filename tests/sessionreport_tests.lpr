program sessionreport_tests;

// The document a session leaves behind.
//
// Almost every assertion here is about something the report refuses to do. It
// must not render a check that never ran as one that passed; it must not drop
// an empty section, because a missing heading reads as an omission while an
// explicit "nothing touched the chip" reads as a fact; it must not put a
// summary verdict over a list containing a refusal; and it must not let a
// backup path appear without the hash that identifies it.
//
// The one thing it may do freely is carry other units' words through
// verbatim. "not measurable on this programmer" is railreport's sentence, and
// re-deriving it here would be a second thing to keep in step with the first.

{$mode objfpc}{$H+}

uses
  SysUtils, sessionreport;

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

function Joined(const Lines: TReportLines): string;
var
  i: integer;
begin
  Result := '';
  for i := 0 to High(Lines) do Result := Result + Lines[i] + LineEnding;
end;

function Has(const Lines: TReportLines; const Needle: string): boolean;
begin
  Result := Pos(Needle, Joined(Lines)) > 0;
end;

function FreshReport: TSessionReport;
begin
  Result := TSessionReport.Create('4.36.0.0', '2026-08-07T09:15:00Z');
  Result.SetProgrammer('CH347', 'unavailable');
  Result.SetChip('W25Q64FW', 'EF6017', 8 * 1024 * 1024, False);
end;

// ------------------------------------------------ what did not happen

procedure TestAnUnrunCheckIsNeverATick;
var
  R: TSessionReport;
  Lines: TReportLines;
begin
  WriteLn('A check that never ran is not a check that passed');
  R := FreshReport;
  try
    R.AddStep('Chip identity, read now', soPassed);
    R.AddStep('Electrical preflight', soPassed);
    //The session stopped here. The remaining rungs were never attempted, and
    //a report showing six ticks because the seventh check never happened is
    //the failure this whole unit exists to avoid.
    R.AddStep('Connection stability', soNotRun);
    R.AddStep('Byte-by-byte verify', soNotRun);

    Lines := R.Render;
    Check('a passed step is ticked', Has(Lines, '[x] Chip identity'));
    Check('an unrun step is not', Has(Lines, '[ ] Connection stability'));
    Check('and it says so in words',
          Has(Lines, 'Connection stability -- not run'));
    //It must still appear. Silently omitting it would leave a list of two
    //ticks and no indication that anything else was ever required.
    Check('the unrun steps are still listed',
          Has(Lines, 'Byte-by-byte verify'));

    //The distinction is spelled out at the bottom, because a reader who has
    //never seen this format will otherwise read [ ] as a minor variant of a
    //tick.
    Check('the legend explains the empty box',
          Has(Lines, 'not the same as one that passed'));
  finally
    R.Free;
  end;
end;

procedure TestOutcomesAreAllDistinct;
var
  O: TSessionOutcome;
  Seen: string;
begin
  WriteLn('Every outcome has its own word and its own mark');
  Seen := '';
  for O := Low(TSessionOutcome) to High(TSessionOutcome) do
  begin
    Check('outcome ' + IntToStr(Ord(O)) + ' has text',
          OutcomeText(O) <> '');
    Check('outcome ' + IntToStr(Ord(O)) + ' has a mark',
          OutcomeMark(O) <> '');
    //Two outcomes sharing a mark would make the list unreadable exactly where
    //it matters: a refusal looking like a pass.
    Check('mark for outcome ' + IntToStr(Ord(O)) + ' is not a duplicate',
          Pos(OutcomeMark(O), Seen) = 0);
    Seen := Seen + OutcomeMark(O) + '|';
  end;
  //Only one of them may be a tick.
  Check('only a pass gets a tick', OutcomeMark(soPassed) = '[x]');
  Check('a failure does not', OutcomeMark(soFailed) <> '[x]');
  Check('and a refusal does not', OutcomeMark(soRefused) <> '[x]');
end;

procedure TestARefusalIsRecordedAsAnOutcome;
var
  R: TSessionReport;
  Lines: TReportLines;
begin
  WriteLn('A session where the program declined to write is a real session');
  R := FreshReport;
  try
    R.AddStep('Chip identity, read now', soPassed);
    //The program did its job. The document should read that way rather than
    //looking like a session in which nothing occurred.
    R.AddStep('Electrical preflight', soRefused,
              'target supply is 3300 mV; chip allows 1650..1950 mV');
    R.AddOperation('Erase', soNotRun, 0);

    Lines := R.Render;
    Check('the refusal is listed', Has(Lines, 'Electrical preflight -- refused'));
    Check('with the reason', Has(Lines, '1650..1950 mV'));
    //And there is no cheerful banner over the top contradicting it.
    Check('no summary verdict is invented',
          (not Has(Lines, 'SUCCESS')) and (not Has(Lines, 'All checks passed')));
  finally
    R.Free;
  end;
end;

// ------------------------------------------------- empty sections speak

procedure TestEmptySectionsSayWhatTheirEmptinessMeans;
var
  R: TSessionReport;
  Lines: TReportLines;
begin
  WriteLn('An empty section is a statement, not a gap');
  R := FreshReport;
  try
    Lines := R.Render;

    //A missing "Operations" heading reads as a report that forgot to mention
    //them. An explicit sentence reads as a fact somebody can rely on.
    Check('the operations section exists', Has(Lines, '## Operations'));
    Check('and says nothing touched the chip',
          Has(Lines, 'nothing in this session touched the chip'));
    Check('the checks section exists', Has(Lines, '## Checks'));
    Check('and says none were recorded', Has(Lines, 'no checks were recorded'));
    Check('the files section exists', Has(Lines, '## Files produced'));
    Check('and says there were none', Has(Lines, 'produced no files'));
  finally
    R.Free;
  end;
end;

procedure TestUnrecordedFieldsSaySo;
var
  R: TSessionReport;
  Lines: TReportLines;
begin
  WriteLn('A field nobody filled in looks like one');
  R := TSessionReport.Create('4.36.0.0', '2026-08-07T09:15:00Z');
  try
    Lines := R.Render;
    //An empty cell is read as unimportant. This program's entire argument is
    //that an unanswered question should look like one.
    Check('an unset programmer says not recorded', Has(Lines, '_not recorded_'));
    Check('and the rail section says so too',
          Has(Lines, '## Target rail'));
    Check('the capacity is not rendered as zero bytes',
          not Has(Lines, '0 bytes'));
  finally
    R.Free;
  end;
end;

// --------------------------------------------------- carried through

procedure TestRailLinesArePassedThroughVerbatim;
var
  R: TSessionReport;
  Lines: TReportLines;
begin
  WriteLn('The rail report arrives in the document word for word');
  R := FreshReport;
  try
    //railreport's formatter is the single source of what "not measurable"
    //reads as. Re-deriving it here would be a second thing to keep in step,
    //and the two would drift on the day a board with an ADC arrives.
    R.SetRailLines([
      'Requested voltage:         1.8 V',
      'Measured voltage:          not measurable on this programmer',
      'Signal (CS/CLK/MOSI):      1.8 V (assumed to follow the rail, not measured)']);

    Lines := R.Render;
    Check('the requested rail survives', Has(Lines, 'Requested voltage:         1.8 V'));
    Check('and so does "not measurable"',
          Has(Lines, 'not measurable on this programmer'));
    //Including the word that matters most: an assumed signal level must not
    //be quietly promoted to a measured one on its way into a document
    //somebody keeps.
    Check('and the word "assumed" is not lost',
          Has(Lines, 'assumed to follow the rail'));
    //Fenced, so the column alignment the formatter produced survives Markdown.
    Check('the block is fenced', Has(Lines, '```'));
  finally
    R.Free;
  end;
end;

procedure TestSafeModeIsStatedProminently;
var
  R: TSessionReport;
  Lines: TReportLines;
begin
  WriteLn('A safe-mode session says the chip could not have been changed');
  R := FreshReport;
  try
    R.SetSafeMode(True);
    Lines := R.Render;
    //The single most useful sentence in the document for anyone asking what
    //was done to their board.
    Check('safe mode is in the header',
          Has(Lines, 'could not change the chip'));
  finally
    R.Free;
  end;

  R := FreshReport;
  try
    Lines := R.Render;
    Check('and an ordinary session does not claim it',
          not Has(Lines, 'could not change the chip'));
    Check('but still says which it was', Has(Lines, 'safe mode | off'));
  finally
    R.Free;
  end;
end;

procedure TestAProvisionalChipIsLabelled;
var
  R: TSessionReport;
  Lines: TReportLines;
begin
  WriteLn('A chip described by itself is labelled as such');
  R := TSessionReport.Create('4.36.0.0', '2026-08-07T09:15:00Z');
  try
    R.SetChip('SFDP-EF4017-8M', 'EF4017', 8 * 1024 * 1024, True);
    Lines := R.Render;
    //The reader has to know this description came from the part rather than
    //from a table somebody checked against a datasheet.
    Check('the report says the description is provisional',
          Has(Lines, 'provisional'));
    Check('and where it came from', Has(Lines, 'own SFDP tables'));
  finally
    R.Free;
  end;

  R := FreshReport;
  try
    Check('a catalogue part says that instead',
          Has(R.Render, 'from the chip catalogue'));
  finally
    R.Free;
  end;
end;

// ----------------------------------------------------------- artefacts

procedure TestABackupNeverAppearsWithoutItsHash;
var
  R: TSessionReport;
  Lines: TReportLines;
begin
  WriteLn('A file is recorded with the hash that identifies it');
  R := FreshReport;
  try
    R.AddArtefact('Trusted backup',
      'backup/W25Q64FW-20260807-091530.bin',
      '9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08');
    Lines := R.Render;
    Check('the path is listed', Has(Lines, 'W25Q64FW-20260807-091530.bin'));
    //A path on its own answers none of the questions somebody asks at the
    //moment they need the backup: is this the right file, and is it the one
    //taken here.
    Check('and so is the hash', Has(Lines, '9f86d081884c7d'));

    //And when there is no hash, that is said rather than left to be assumed.
    R.AddArtefact('Session log', 'logs/session.txt', '');
    Lines := R.Render;
    Check('a missing hash is stated', Has(Lines, 'no hash recorded'));
  finally
    R.Free;
  end;
end;

procedure TestOperationsCarryTheirTiming;
var
  R: TSessionReport;
  Lines: TReportLines;
begin
  WriteLn('An operation that ran was timed; one that did not was not');
  R := FreshReport;
  try
    R.AddOperation('Read chip', soPassed, 42500);
    R.AddOperation('Erase', soNotRun, 0);

    Lines := R.Render;
    Check('the read reports its time', Has(Lines, '42.5 s'));
    //Zero milliseconds is a real measurement on a fast operation, so an
    //operation that never started must be told apart by something other than
    //its elapsed time being zero.
    Check('the unrun erase reports no time at all',
          not Has(Lines, 'Erase -- not run, '));

    Check('entry count is what was added', R.Count = 2);
    Check('and an entry knows whether it was timed',
          R.Entry[0].HasElapsed and (not R.Entry[1].HasElapsed));
    //An out-of-range index must not return a neighbour's outcome.
    Check('an index past the end is empty', R.Entry[99].Title = '');
  finally
    R.Free;
  end;
end;

procedure TestNotesAreNotVerdicts;
var
  R: TSessionReport;
  Lines: TReportLines;
begin
  WriteLn('A note is context, not something that passed');
  R := FreshReport;
  try
    R.AddNote('Clock', 'auto-tuned to 7.5 MHz; 15 MHz was unstable');
    Lines := R.Render;
    Check('the note appears', Has(Lines, 'auto-tuned to 7.5 MHz'));
    //Giving it a mark would put a tick beside something that never passed or
    //failed anything.
    Check('but not with a tick beside it',
          not Has(Lines, '[x] Clock'));
  finally
    R.Free;
  end;
end;

// ------------------------------------------------------------ formatting

procedure TestFormattingIsLocaleIndependent;
begin
  WriteLn('Sizes and durations read the same on every machine');
  //A report that renders one way on the machine that wrote it and another on
  //the machine that receives it is not a report.
  Check('milliseconds', DurationText(250) = '250 ms');
  Check('seconds with a tenth', DurationText(42500) = '42.5 s');
  Check('minutes and seconds', DurationText(125000) = '2 m 5 s');
  Check('exactly one second', DurationText(1000) = '1.0 s');

  Check('a MiB size', ByteSizeText(8 * 1024 * 1024) = '8388608 bytes (8 MiB)');
  Check('a KiB size', ByteSizeText(4096) = '4096 bytes (4 KiB)');
  Check('an odd size stays exact', ByteSizeText(1000) = '1000 bytes');
end;

begin
  TestAnUnrunCheckIsNeverATick;
  TestOutcomesAreAllDistinct;
  TestARefusalIsRecordedAsAnOutcome;
  TestEmptySectionsSayWhatTheirEmptinessMeans;
  TestUnrecordedFieldsSaySo;
  TestRailLinesArePassedThroughVerbatim;
  TestSafeModeIsStatedProminently;
  TestAProvisionalChipIsLabelled;
  TestABackupNeverAppearsWithoutItsHash;
  TestOperationsCarryTheirTiming;
  TestNotesAreNotVerdicts;
  TestFormattingIsLocaleIndependent;
  WriteLn(Assertions, ' assertions, ', Failures, ' failures');
  if Failures <> 0 then Halt(1);
  WriteLn('ALL PASSED');
end.
