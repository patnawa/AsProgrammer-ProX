unit sessionreport;

// Everything that happened in one bench session, as a document somebody can
// hand to somebody else.
//
// Authenticated production already produces signed evidence. Bench work
// produces a scrolling log pane, which is not an artefact: it cannot be
// attached to an invoice, it disappears when the window closes, and it
// interleaves the rail report with a hundred lines of progress. Meanwhile
// every fact worth recording is already computed somewhere in this program --
// the requested and measured rail, the chip that answered, each rung of the
// admission ladder, the backup and its SHA-256, the verify results and their
// timings. Nothing collects them.
//
// This does. It is a collector and a renderer, and it is deliberately dull:
// the value is entirely in what it refuses to smooth over.
//
//   - A step that was not run says so. It does not say "passed", and it does
//     not vanish from the list. The most misleading report this unit could
//     produce is one that shows six ticks because the seventh check never
//     happened.
//   - A refusal is recorded as an outcome, not as an absence. A session where
//     the program declined to write is a successful session, and the document
//     should read that way rather than looking like a session where nothing
//     occurred.
//   - Facts the hardware cannot observe are carried through verbatim from
//     whoever computed them, so "not measurable on this programmer" arrives
//     in the report as those words rather than as a blank or a zero.
//   - Nothing is inferred here. This unit has no opinion about whether a
//     session went well; it lays out what was recorded and lets the reader
//     decide.
//
// It takes its lines as plain string arrays rather than typed records from
// railreport or validationgate, so it has no dependency on either. The
// formatters in those units are already the single source of their own truth,
// and a second rendering here would be a second thing to keep in step.
//
// No hardware access and no LCL unit is used here.

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

type
  TReportLines = array of string;

  // What became of one recorded thing.
  //
  // soNotRun exists so that a check which never happened can appear in the
  // list. It is the whole reason this is an enumeration rather than a
  // boolean: "did not pass" and "was never attempted" are different things to
  // hand a customer.
  TSessionOutcome = (
    soNotRun,
    soPassed,
    soFailed,
    soRefused,
    soCancelled,
    soSkipped        // deliberately not applicable to this session
  );

  TSessionEntryKind = (
    ekStep,          // a rung of the admission ladder
    ekOperation,     // something that touched the chip
    ekArtefact,      // a file this session produced
    ekNote           // context that is not itself an outcome
  );

  TSessionEntry = record
    Kind: TSessionEntryKind;
    Title: string;
    Detail: string;
    Outcome: TSessionOutcome;
    // Separate from a zero elapsed time, which is a real measurement on a
    // fast operation.
    HasElapsed: boolean;
    ElapsedMs: QWord;
  end;

  // The collector.
  //
  // A class rather than a record because it accumulates across a session and
  // is held by the GUI for the lifetime of a window; passing a growing record
  // by var through twenty call sites is how one of them ends up holding a
  // stale copy.
  TSessionReport = class
  private
    FEntries: array of TSessionEntry;
    FProgramVersion: string;
    FStartedUtc: string;
    FProgrammer: string;
    FProgrammerFirmware: string;
    FChipName: string;
    FChipJedecID: string;
    FChipCapacity: QWord;
    FChipProvisional: boolean;
    FSafeMode: boolean;
    FRailLines: TReportLines;
    function GetCount: integer;
    function GetEntry(Index: integer): TSessionEntry;
  public
    constructor Create(const ProgramVersion, StartedUtc: string);

    // The session's fixed facts. Called once, when they become known.
    procedure SetProgrammer(const Name, Firmware: string);
    // Verbatim from railreport.RailReportLines. Not re-derived here: that
    // formatter is the single source of what "not measurable" reads as, and
    // a second copy is a second thing to keep in step.
    procedure SetRailLines(const Lines: array of string);
    procedure SetChip(const Name, JedecID: string; Capacity: QWord;
      Provisional: boolean);
    procedure SetSafeMode(Enabled: boolean);

    // The accumulating record.
    procedure AddStep(const Title: string; Outcome: TSessionOutcome;
      const Detail: string = '');
    procedure AddOperation(const Title: string; Outcome: TSessionOutcome;
      ElapsedMs: QWord; const Detail: string = '');
    // A file this session produced, with the hash that identifies it. A
    // backup path on its own answers none of the questions somebody asks when
    // they need the backup.
    procedure AddArtefact(const Title, Path, Sha256: string);
    procedure AddNote(const Title, Detail: string);

    // The document. Markdown because it stays readable as plain text, which
    // matters more here than any rendering: this is the file that gets
    // emailed, pasted into a ticket and printed.
    function Render: TReportLines;

    property Count: integer read GetCount;
    property Entry[Index: integer]: TSessionEntry read GetEntry;
  end;

function OutcomeText(Outcome: TSessionOutcome): string;
function OutcomeMark(Outcome: TSessionOutcome): string;

// Bytes as something a person reads, exactly. Sizes here are powers of two,
// so there is never a rounding decision to make.
function ByteSizeText(Bytes: QWord): string;

// Milliseconds as a duration. Deliberately not locale-formatted: a report
// that renders a different way on the machine that receives it than on the
// machine that wrote it is not a report.
function DurationText(Ms: QWord): string;

implementation

function OutcomeText(Outcome: TSessionOutcome): string;
begin
  case Outcome of
    soNotRun:    Result := 'not run';
    soPassed:    Result := 'passed';
    soFailed:    Result := 'FAILED';
    soRefused:   Result := 'refused';
    soCancelled: Result := 'cancelled';
    soSkipped:   Result := 'not applicable';
  else
    Result := '';
  end;
end;

function OutcomeMark(Outcome: TSessionOutcome): string;
begin
  //A distinct mark for each, and specifically not a tick for anything except
  //a step that actually ran and passed. A report that shows six ticks because
  //the seventh check never happened is the failure mode this unit exists to
  //avoid.
  case Outcome of
    soPassed:    Result := '[x]';
    soFailed:    Result := '[!]';
    soRefused:   Result := '[-]';
    soCancelled: Result := '[c]';
    soSkipped:   Result := '[.]';
  else
    Result := '[ ]';   //not run
  end;
end;

function ByteSizeText(Bytes: QWord): string;
begin
  if (Bytes >= 1024 * 1024) and ((Bytes mod (1024 * 1024)) = 0) then
    Result := Format('%d bytes (%d MiB)', [Bytes, Bytes div (1024 * 1024)])
  else if (Bytes >= 1024) and ((Bytes mod 1024) = 0) then
    Result := Format('%d bytes (%d KiB)', [Bytes, Bytes div 1024])
  else
    Result := Format('%d bytes', [Bytes]);
end;

function DurationText(Ms: QWord): string;
begin
  if Ms < 1000 then
    Result := Format('%d ms', [Ms])
  else if Ms < 60000 then
    //Tenths, computed as integers. DecimalSeparator turns 1.5 into "1,5" in
    //half of Europe, and a duration that renders differently per machine
    //cannot be compared with the one in the previous report.
    Result := Format('%d.%d s', [Ms div 1000, (Ms mod 1000) div 100])
  else
    Result := Format('%d m %d s', [Ms div 60000, (Ms mod 60000) div 1000]);
end;

constructor TSessionReport.Create(const ProgramVersion, StartedUtc: string);
begin
  inherited Create;
  FProgramVersion := ProgramVersion;
  FStartedUtc := StartedUtc;
  //Every other field stays empty until somebody says otherwise. An empty
  //field renders as "not recorded", which is true, rather than as a plausible
  //default that is not.
  SetLength(FEntries, 0);
  SetLength(FRailLines, 0);
end;

function TSessionReport.GetCount: integer;
begin
  Result := Length(FEntries);
end;

function TSessionReport.GetEntry(Index: integer): TSessionEntry;
begin
  Result := Default(TSessionEntry);
  if (Index < 0) or (Index >= Length(FEntries)) then Exit;
  Result := FEntries[Index];
end;

procedure TSessionReport.SetProgrammer(const Name, Firmware: string);
begin
  FProgrammer := Name;
  FProgrammerFirmware := Firmware;
end;

procedure TSessionReport.SetRailLines(const Lines: array of string);
var
  i: integer;
begin
  SetLength(FRailLines, Length(Lines));
  for i := 0 to High(Lines) do FRailLines[i] := Lines[i];
end;

procedure TSessionReport.SetChip(const Name, JedecID: string; Capacity: QWord;
  Provisional: boolean);
begin
  FChipName := Name;
  FChipJedecID := JedecID;
  FChipCapacity := Capacity;
  FChipProvisional := Provisional;
end;

procedure TSessionReport.SetSafeMode(Enabled: boolean);
begin
  FSafeMode := Enabled;
end;

procedure TSessionReport.AddStep(const Title: string;
  Outcome: TSessionOutcome; const Detail: string);
var
  N: integer;
begin
  N := Length(FEntries);
  SetLength(FEntries, N + 1);
  FEntries[N] := Default(TSessionEntry);
  FEntries[N].Kind := ekStep;
  FEntries[N].Title := Title;
  FEntries[N].Outcome := Outcome;
  FEntries[N].Detail := Detail;
end;

procedure TSessionReport.AddOperation(const Title: string;
  Outcome: TSessionOutcome; ElapsedMs: QWord; const Detail: string);
var
  N: integer;
begin
  N := Length(FEntries);
  SetLength(FEntries, N + 1);
  FEntries[N] := Default(TSessionEntry);
  FEntries[N].Kind := ekOperation;
  FEntries[N].Title := Title;
  FEntries[N].Outcome := Outcome;
  FEntries[N].Detail := Detail;
  //An operation that ran was timed, including one that took under a
  //millisecond. HasElapsed distinguishes that from an operation that was
  //never started.
  FEntries[N].HasElapsed := Outcome in [soPassed, soFailed, soCancelled];
  FEntries[N].ElapsedMs := ElapsedMs;
end;

procedure TSessionReport.AddArtefact(const Title, Path, Sha256: string);
var
  N: integer;
begin
  N := Length(FEntries);
  SetLength(FEntries, N + 1);
  FEntries[N] := Default(TSessionEntry);
  FEntries[N].Kind := ekArtefact;
  FEntries[N].Title := Title;
  //The hash travels with the path, always. A backup path on its own answers
  //none of the questions somebody asks at the moment they need the backup:
  //is this the right file, and is it the one that was taken here.
  if Sha256 <> '' then
    FEntries[N].Detail := Path + '  sha256:' + Sha256
  else
    FEntries[N].Detail := Path + '  (no hash recorded)';
  FEntries[N].Outcome := soPassed;
end;

procedure TSessionReport.AddNote(const Title, Detail: string);
var
  N: integer;
begin
  N := Length(FEntries);
  SetLength(FEntries, N + 1);
  FEntries[N] := Default(TSessionEntry);
  FEntries[N].Kind := ekNote;
  FEntries[N].Title := Title;
  FEntries[N].Detail := Detail;
  //A note is context, not a verdict. Giving it an outcome would put a mark
  //beside something that never passed or failed anything.
  FEntries[N].Outcome := soSkipped;
end;

function TSessionReport.Render: TReportLines;
var
  Lines: TReportLines;

  procedure Add(const Line: string);
  var
    N: integer;
  begin
    N := Length(Lines);
    SetLength(Lines, N + 1);
    Lines[N] := Line;
  end;

  function OrNotRecorded(const Value: string): string;
  begin
    //"not recorded" rather than an empty cell. An empty cell is read as
    //unimportant; this program's whole argument is that an unanswered
    //question should look like one.
    if Value = '' then Result := '_not recorded_' else Result := Value;
  end;

  procedure Section(const Title: string; Kind: TSessionEntryKind;
    const EmptyText: string);
  var
    i: integer;
    Any: boolean;
    Line: string;
  begin
    Any := False;
    for i := 0 to High(FEntries) do
      if FEntries[i].Kind = Kind then Any := True;

    Add('');
    Add('## ' + Title);
    Add('');
    if not Any then
    begin
      Add(EmptyText);
      Exit;
    end;

    for i := 0 to High(FEntries) do
    begin
      if FEntries[i].Kind <> Kind then Continue;
      if Kind = ekNote then
        Line := '- **' + FEntries[i].Title + '** ' + FEntries[i].Detail
      else
      begin
        Line := '- ' + OutcomeMark(FEntries[i].Outcome) + ' ' +
                FEntries[i].Title + ' -- ' + OutcomeText(FEntries[i].Outcome);
        if FEntries[i].HasElapsed then
          Line := Line + ', ' + DurationText(FEntries[i].ElapsedMs);
        if FEntries[i].Detail <> '' then
          Line := Line + LineEnding + '  ' + FEntries[i].Detail;
      end;
      Add(Line);
    end;
  end;

var
  i: integer;
begin
  Lines := nil;

  Add('# Chipwright session report');
  Add('');
  Add('| | |');
  Add('|---|---|');
  Add('| Program | Chipwright ' + OrNotRecorded(FProgramVersion) + ' |');
  Add('| Started (UTC) | ' + OrNotRecorded(FStartedUtc) + ' |');
  Add('| Programmer | ' + OrNotRecorded(FProgrammer) + ' |');
  Add('| Programmer firmware | ' + OrNotRecorded(FProgrammerFirmware) + ' |');
  if FSafeMode then
    //Worth its own row rather than a footnote. A session run in safe mode
    //could not have changed the chip, and that is the single most useful
    //sentence in the document for anyone asking what was done to their board.
    Add('| Read-only safe mode | **on -- this session could not change the ' +
        'chip** |')
  else
    Add('| Read-only safe mode | off |');

  Add('');
  Add('## Chip');
  Add('');
  Add('| | |');
  Add('|---|---|');
  Add('| Name | ' + OrNotRecorded(FChipName) + ' |');
  Add('| JEDEC ID | ' + OrNotRecorded(FChipJedecID) + ' |');
  if FChipCapacity > 0 then
    Add('| Capacity | ' + ByteSizeText(FChipCapacity) + ' |')
  else
    Add('| Capacity | _not recorded_ |');
  if FChipProvisional then
    //The reader has to know that this description came from the part rather
    //than from a chip table somebody checked against a datasheet.
    Add('| Description | provisional, from the chip''s own SFDP tables |')
  else
    Add('| Description | from the chip catalogue |');

  Add('');
  Add('## Target rail');
  Add('');
  if Length(FRailLines) = 0 then
    Add('_not recorded_')
  else
  begin
    //A fenced block, so the alignment the rail formatter produces survives.
    Add('```');
    for i := 0 to High(FRailLines) do Add(FRailLines[i]);
    Add('```');
  end;

  //An empty section still appears, and says what its emptiness means. A
  //missing "Operations" heading reads as a report that forgot to mention
  //them; an explicit "nothing touched the chip" reads as a fact.
  Section('Checks', ekStep, '_no checks were recorded in this session._');
  Section('Operations', ekOperation,
          '_nothing in this session touched the chip._');
  Section('Files produced', ekArtefact,
          '_this session produced no files._');
  Section('Notes', ekNote, '_none._');

  Add('');
  Add('---');
  Add('');
  //No summary verdict, deliberately. This unit has no basis for deciding
  //whether a session went well, and a green banner over a list containing a
  //refusal would be the report contradicting its own contents.
  Add('This report lists what was recorded. `[ ]` marks a check that was not ' +
      'run, which is not the same as one that passed.');

  Result := Lines;
end;

end.
