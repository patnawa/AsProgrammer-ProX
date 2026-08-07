unit validationgate;

// Which capabilities are still waiting on hardware, and what exactly it would
// take to release one.
//
// Two of this program's largest features are written, tested and unreachable.
// SPI NAND erase and program exist but are disabled by default and never
// reached the GUI. Destructive Smart Write over libusb exists but demands an
// environment token naming a sacrificial chip. Both design documents say
// "pending live validation" and then set out a numbered checklist of what
// that validation involves.
//
// What neither of them says is *what result lifts the gate*. So the gate
// stays shut not because the evidence is missing but because nobody can point
// at the thing that would settle it -- which is a judgement call wearing the
// costume of a policy.
//
// This unit removes the judgement call. The checklists live here as data, a
// release is a record attesting each numbered item, and the gate is a lookup.
// Releasing a capability becomes a reviewable commit that transcribes a HIL
// run, and a refusal can always say which item is outstanding rather than
// "pending live validation".
//
// The evidence table is compiled in, for the same reason signalchar's is: it
// opens a destructive path, so it must be reviewable in source and travel
// with the binary. A file next to the exe would be a gate anyone can open by
// writing a file.
//
// One thing this unit deliberately does NOT do is replace the environment
// token in headlesscli. That token is not a second way through the gate --
// it is how the validation run itself is performed. Somebody has to issue
// destructive commands on a sacrificial part *before* any evidence exists, or
// no evidence can ever exist. So the two coexist: a released capability needs
// no token, an unreleased one is reachable only by someone who has typed out
// what they are doing.
//
// No hardware access and no LCL unit is used here.

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

type
  TGateLines = array of string;

  TGatedCapability = (
    // Destructive Smart Write driven through ch347usb/libusb, the path the
    // headless CLI and any Linux host use. docs/design-cross-platform.md.
    gcCH347LibusbWrite,
    // SPI NAND erase and program. docs/design-spi-nand.md.
    gcSPINANDMutation
  );

const
  // The widest checklist any capability has. The coverage mask is a cardinal,
  // so this could grow to 32 before the representation has to change; the
  // validator refuses anything that would silently exceed it.
  MAX_CHECKLIST_ITEMS = 16;

type
  // One HIL run that covered a capability's checklist, transcribed from the
  // retained evidence bundle.
  //
  // Every field is here because a validation that cannot answer it is not
  // reusable by the next person. "It worked on my bench" is not evidence; "it
  // worked on this programmer, at this firmware, on this chip lot, at this
  // rail, at this clock, on this commit, and here is the hash of the trace"
  // is.
  TValidationEvidence = record
    Known: boolean;
    Capability: TGatedCapability;

    RunID: string;              // the hardware-in-loop workflow run
    Commit: string;             // the software revision that was exercised
    PerformedOn: string;        // ISO-8601 date, UTC

    Programmer: string;
    ProgrammerFirmware: string;
    ChipMarking: string;
    ChipLot: string;
    RailMv: cardinal;
    ClockHz: cardinal;

    // Bit N set means numbered checklist item N+1 was covered. A partial run
    // is recorded as a partial run: the gate then names the items still
    // outstanding instead of treating almost-complete as complete.
    ChecklistCovered: cardinal;

    // SHA-256 of the retained evidence bundle, so the record points at
    // something rather than merely asserting it.
    ArtefactSha256: string;
  end;

  TValidationEvidenceList = array of TValidationEvidence;

// The checklist for a capability: the numbered steps its design document
// sets out, as data. These are the strings a refusal quotes back, so they are
// written to be read by whoever has to go and do the work.
function ChecklistItemCount(Capability: TGatedCapability): integer;
function ChecklistItemText(Capability: TGatedCapability;
  Index: integer): string;

// Every item of the checklist, as a bit mask. A release must cover all of it;
// there is no partial credit, because the items that get skipped under time
// pressure are the fault-injection ones, which is where the value is.
function RequiredChecklistMask(Capability: TGatedCapability): cardinal;

function CapabilityName(Capability: TGatedCapability): string;
function CapabilityDocument(Capability: TGatedCapability): string;

// A record is trusted only if it is complete. A half-filled evidence entry
// releasing a destructive path is worse than none, because it looks like
// diligence.
function ValidateEvidence(const Evidence: TValidationEvidence;
  out ErrMsg: string): boolean;

// The gate itself.
//
// Reason is filled in both cases. When released it cites the run that
// released it, so a log line can say why a destructive path was available.
// When refused it names the specific outstanding checklist items -- that is
// the entire improvement over "pending live validation", which tells the
// reader nothing they can act on.
function IsReleasedIn(const Records: TValidationEvidenceList;
  Capability: TGatedCapability; out Reason: string): boolean;
function IsReleased(Capability: TGatedCapability;
  out Reason: string): boolean;

// The state of every gate, for --help, the About box and the session report.
function GateStatusLinesIn(const Records: TValidationEvidenceList): TGateLines;
function GateStatusLines: TGateLines;

// The checklist as printable lines, marked off against a record. This is what
// somebody about to do a HIL run wants to see.
function ChecklistLinesIn(const Records: TValidationEvidenceList;
  Capability: TGatedCapability): TGateLines;

// The whole table, copied, for the suite and for a diagnostics dump.
function AllValidationEvidence: TValidationEvidenceList;

implementation

// --------------------------------------------------------- the checklists
//
// Transcribed from the design documents. They are duplicated here rather than
// parsed out of Markdown at runtime, and that is the right trade: the gate
// must be decidable in a program with no data files, and a checklist that
// could be edited without a compile is not much of a gate.
//
// If a design document's list changes, this changes in the same commit. The
// suite asserts the counts, so an item added to one and not the other is a
// build failure rather than a quietly weakened requirement.

const
  CH347_CHECKLIST: array[0..5] of string = (
    'repeated stable JEDEC ID and status reads across process reopen',
    'two matching complete reads at conservative and faster clocks',
    'Smart Write preview with no mutating opcode in a USB trace',
    'a full destructive cycle on a socketed sacrificial chip: trusted ' +
      'backup, required-erase and no-erase plans, shuffled full ' +
      'verification, process restart, restore, restore verification',
    'cancellation and fault injection at open, init, read, erase, program, ' +
      'verify, mode cleanup, close, backup commit and evidence commit',
    'recorded programmer revision, firmware, USB driver/library version, ' +
      'chip lot, adapter and measured rail voltage'
  );

  NAND_CHECKLIST: array[0..6] of string = (
    'recorded programmer revision and firmware, chip marking/lot, adapter, ' +
      'software commit, USB library/driver, clock and measured rail voltage',
    'identification and ONFI reads repeated across disconnect/reopen, with ' +
      'the decoded geometry and raw parameter copies retained',
    'the complete device read twice, the dumps proved identical, and the ' +
      'recovery file committed before the first mutating opcode',
    'both refuse and skip bad-block policies exercised against known marker ' +
      'layouts, with neither erase nor program touching a factory-bad block',
    'erase, full blank check, address-sensitive and 00/55/AA patterns ' +
      'written, fully verified, the process restarted, and verified again',
    'cancellation and transport faults injected at identify, ONFI, marker ' +
      'scan, backup, erase, program, verify, ECC restore and close',
    'the original recovery image restored and a final full verification ' +
      'retained'
  );

function ChecklistItemCount(Capability: TGatedCapability): integer;
begin
  case Capability of
    gcCH347LibusbWrite: Result := Length(CH347_CHECKLIST);
    gcSPINANDMutation:  Result := Length(NAND_CHECKLIST);
  else
    Result := 0;
  end;
end;

function ChecklistItemText(Capability: TGatedCapability;
  Index: integer): string;
begin
  Result := '';
  if (Index < 0) or (Index >= ChecklistItemCount(Capability)) then Exit;
  case Capability of
    gcCH347LibusbWrite: Result := CH347_CHECKLIST[Index];
    gcSPINANDMutation:  Result := NAND_CHECKLIST[Index];
  end;
end;

function RequiredChecklistMask(Capability: TGatedCapability): cardinal;
var
  Count: integer;
begin
  Count := ChecklistItemCount(Capability);
  if (Count <= 0) or (Count > MAX_CHECKLIST_ITEMS) then Exit(0);
  //Built by shifting rather than by (1 shl Count) - 1 so that a Count of 32
  //could never produce an undefined shift.
  Result := (cardinal(1) shl Count) - 1;
end;

function CapabilityName(Capability: TGatedCapability): string;
begin
  case Capability of
    gcCH347LibusbWrite: Result := 'ch347_libusb_write';
    gcSPINANDMutation:  Result := 'spi_nand_mutation';
  else
    Result := 'unknown';
  end;
end;

function CapabilityDocument(Capability: TGatedCapability): string;
begin
  case Capability of
    gcCH347LibusbWrite: Result := 'docs/design-cross-platform.md';
    gcSPINANDMutation:  Result := 'docs/design-spi-nand.md';
  else
    Result := '';
  end;
end;

// ------------------------------------------------------------- the table
//
// Empty. No capability has been released, because no hardware-in-loop run has
// produced the evidence to release one.
//
// That is the same state the program was already in; what changes is that a
// refusal can now say which of the numbered items is outstanding, and that
// releasing one is a transcription rather than a decision.
//
// To release a capability, run the destructive hardware-in-loop workflow
// against a sacrificial part, retain its evidence bundle, and add one entry
// to BuildTable:
//
//   Append(Result, gcCH347LibusbWrite,
//          '18234567890', '54e4a86', '2026-08-20',
//          'CH347', 'unavailable', 'W25Q64FW', 'lot 2438A',
//          1800, 15000000, $3F,
//          '9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08');
//
// ChecklistCovered is a bit per numbered item, so $3F is items 1..6. A run
// that covered five of six is recorded as five of six: the gate then refuses
// and names the sixth, which is the behaviour that makes the record worth
// keeping.

procedure Append(var Records: TValidationEvidenceList;
  Capability: TGatedCapability;
  const RunID, Commit, PerformedOn: string;
  const Programmer, ProgrammerFirmware, ChipMarking, ChipLot: string;
  RailMv, ClockHz, ChecklistCovered: cardinal;
  const ArtefactSha256: string);
var
  N: integer;
begin
  N := Length(Records);
  SetLength(Records, N + 1);
  Records[N].Known := True;
  Records[N].Capability := Capability;
  Records[N].RunID := RunID;
  Records[N].Commit := Commit;
  Records[N].PerformedOn := PerformedOn;
  Records[N].Programmer := Programmer;
  Records[N].ProgrammerFirmware := ProgrammerFirmware;
  Records[N].ChipMarking := ChipMarking;
  Records[N].ChipLot := ChipLot;
  Records[N].RailMv := RailMv;
  Records[N].ClockHz := ClockHz;
  Records[N].ChecklistCovered := ChecklistCovered;
  Records[N].ArtefactSha256 := ArtefactSha256;
end;

function BuildTable: TValidationEvidenceList;
begin
  Result := nil;

  //No capability has been validated on silicon. Add Append(Result, ...) calls
  //here, one per hardware-in-loop run, and delete the "no capability is
  //released" assertion in tests/validationgate_tests.lpr in the same commit.
end;

var
  Table: TValidationEvidenceList = nil;

function AllValidationEvidence: TValidationEvidenceList;
var
  i: integer;
begin
  Result := nil;
  SetLength(Result, Length(Table));
  for i := 0 to High(Table) do Result[i] := Table[i];
end;

// ------------------------------------------------------------ validation

function PrintableWithin(const Value: string; MaxLen: integer): boolean;
var
  i: integer;
begin
  Result := False;
  if (Length(Value) < 1) or (Length(Value) > MaxLen) then Exit;
  for i := 1 to Length(Value) do
    if (Value[i] < #32) or (Value[i] > #126) then Exit;
  Result := True;
end;

function IsLowerHex(const Value: string; Len: integer): boolean;
var
  i: integer;
begin
  Result := False;
  if Length(Value) <> Len then Exit;
  for i := 1 to Len do
    if not (Value[i] in ['0'..'9', 'a'..'f']) then Exit;
  Result := True;
end;

function ValidateEvidence(const Evidence: TValidationEvidence;
  out ErrMsg: string): boolean;
var
  Required: cardinal;
begin
  Result := False;
  ErrMsg := '';

  if not Evidence.Known then
  begin
    ErrMsg := 'evidence record is not marked known';
    Exit;
  end;
  if not PrintableWithin(Evidence.RunID, 64) then
  begin
    ErrMsg := 'the hardware-in-loop run is not identified';
    Exit;
  end;
  if not PrintableWithin(Evidence.Commit, 64) then
  begin
    //Without a commit the record says a program was validated but not which
    //one, which is the same as saying nothing.
    ErrMsg := 'the software revision under test is not recorded';
    Exit;
  end;
  if not PrintableWithin(Evidence.PerformedOn, 32) then
  begin
    ErrMsg := 'the date of the run is missing';
    Exit;
  end;
  if not PrintableWithin(Evidence.Programmer, 96) then
  begin
    ErrMsg := 'the programmer is not identified';
    Exit;
  end;
  if not PrintableWithin(Evidence.ProgrammerFirmware, 96) then
  begin
    //'unavailable' is an acceptable value here, as it is in the electrical
    //capabilities; an empty one is not, because it cannot be told apart from
    //a field nobody filled in.
    ErrMsg := 'the programmer firmware is not recorded';
    Exit;
  end;
  if not PrintableWithin(Evidence.ChipMarking, 96) then
  begin
    ErrMsg := 'the sacrificial chip marking is not recorded';
    Exit;
  end;
  if not PrintableWithin(Evidence.ChipLot, 96) then
  begin
    ErrMsg := 'the sacrificial chip lot is not recorded';
    Exit;
  end;
  if (Evidence.RailMv < 500) or (Evidence.RailMv > 6000) then
  begin
    ErrMsg := 'the measured rail is outside 500..6000 mV';
    Exit;
  end;
  if Evidence.ClockHz = 0 then
  begin
    ErrMsg := 'the bus clock the run used is not recorded';
    Exit;
  end;
  if not IsLowerHex(Evidence.ArtefactSha256, 64) then
  begin
    //A record with no artefact hash asserts a result instead of pointing at
    //one, and an assertion is what this unit exists to replace.
    ErrMsg := 'the retained evidence bundle has no SHA-256';
    Exit;
  end;

  Required := RequiredChecklistMask(Evidence.Capability);
  if Required = 0 then
  begin
    ErrMsg := 'this capability has no checklist, so nothing can attest it';
    Exit;
  end;
  //Bits above the checklist mean the record was written against a different
  //version of the list. Refusing is fail-closed; masking them off would let a
  //shortened list silently release a capability the longer one had not.
  if (Evidence.ChecklistCovered and (not Required)) <> 0 then
  begin
    ErrMsg := 'the record covers checklist items this capability does not have';
    Exit;
  end;
  Result := True;
end;

// ------------------------------------------------------------- the gate

function OutstandingItems(const Records: TValidationEvidenceList;
  Capability: TGatedCapability; out Covered: cardinal;
  out BestIndex: integer): cardinal;
var
  i: integer;
  ErrMsg: string;
begin
  //Coverage does not accumulate across runs. One run has to have done the
  //whole checklist, because the value of items 4 and 5 is that they were
  //exercised on the same part, in the same session, as items 1 to 3 -- a
  //restore verified against a backup taken by some other run last month is
  //not a restore that was verified.
  Covered := 0;
  BestIndex := -1;
  for i := 0 to High(Records) do
  begin
    if Records[i].Capability <> Capability then Continue;
    if not ValidateEvidence(Records[i], ErrMsg) then Continue;
    if Records[i].ChecklistCovered > Covered then
    begin
      Covered := Records[i].ChecklistCovered;
      BestIndex := i;
    end;
  end;
  Result := RequiredChecklistMask(Capability) and (not Covered);
end;

function OutstandingText(Capability: TGatedCapability;
  Outstanding: cardinal): string;
var
  i, Count: integer;
begin
  Result := '';
  Count := ChecklistItemCount(Capability);
  for i := 0 to Count - 1 do
    if (Outstanding and (cardinal(1) shl i)) <> 0 then
    begin
      if Result <> '' then Result := Result + '; ';
      Result := Result + Format('(%d) %s', [i + 1, ChecklistItemText(Capability, i)]);
    end;
end;

function IsReleasedIn(const Records: TValidationEvidenceList;
  Capability: TGatedCapability; out Reason: string): boolean;
var
  Covered, Outstanding: cardinal;
  BestIndex: integer;
begin
  Outstanding := OutstandingItems(Records, Capability, Covered, BestIndex);
  Result := (RequiredChecklistMask(Capability) <> 0) and (Outstanding = 0);

  if Result then
    Reason := Format(
      '%s was validated on %s by run %s (%s, %s, commit %s)',
      [CapabilityName(Capability), Records[BestIndex].PerformedOn,
       Records[BestIndex].RunID, Records[BestIndex].Programmer,
       Records[BestIndex].ChipMarking, Records[BestIndex].Commit])
  else if BestIndex < 0 then
    //The state the program ships in. It names the document and every item, so
    //the reader is one page away from knowing what to do rather than being
    //told a decision was made somewhere.
    Reason := Format(
      '%s has no hardware-in-loop validation on record. %s lists what is ' +
      'required: %s',
      [CapabilityName(Capability), CapabilityDocument(Capability),
       OutstandingText(Capability, Outstanding)])
  else
    Reason := Format(
      '%s was partly validated by run %s; still outstanding: %s',
      [CapabilityName(Capability), Records[BestIndex].RunID,
       OutstandingText(Capability, Outstanding)]);
end;

function IsReleased(Capability: TGatedCapability;
  out Reason: string): boolean;
begin
  Result := IsReleasedIn(Table, Capability, Reason);
end;

// ------------------------------------------------------------- reporting

procedure AddLine(var Lines: TGateLines; const Line: string);
var
  N: integer;
begin
  N := Length(Lines);
  SetLength(Lines, N + 1);
  Lines[N] := Line;
end;

function GateStatusLinesIn(const Records: TValidationEvidenceList): TGateLines;
var
  C: TGatedCapability;
  Reason: string;
  Covered, Outstanding: cardinal;
  BestIndex: integer;
begin
  //One line each, deliberately.  This goes in --help and the About box, where
  //the reader wants to know whether a path is open; the full checklist is a
  //page of text and belongs behind --gates, which is the command someone runs
  //when the answer is "no" and they want to know why.
  Result := nil;
  for C := Low(TGatedCapability) to High(TGatedCapability) do
  begin
    Outstanding := OutstandingItems(Records, C, Covered, BestIndex);
    if IsReleasedIn(Records, C, Reason) then
      AddLine(Result, Format('released: %s (run %s, %s)',
                             [CapabilityName(C), Records[BestIndex].RunID,
                              Records[BestIndex].PerformedOn]))
    else
      AddLine(Result, Format(
        'gated:    %s -- %d of %d checklist items outstanding (%s)',
        [CapabilityName(C), PopCnt(Outstanding), ChecklistItemCount(C),
         CapabilityDocument(C)]));
  end;
end;

function GateStatusLines: TGateLines;
begin
  Result := GateStatusLinesIn(Table);
end;

function ChecklistLinesIn(const Records: TValidationEvidenceList;
  Capability: TGatedCapability): TGateLines;
var
  Covered, Outstanding: cardinal;
  BestIndex, i: integer;
  Mark: string;
begin
  Result := nil;
  Outstanding := OutstandingItems(Records, Capability, Covered, BestIndex);

  AddLine(Result, CapabilityName(Capability) + ' -- ' +
                  CapabilityDocument(Capability));
  for i := 0 to ChecklistItemCount(Capability) - 1 do
  begin
    if (Covered and (cardinal(1) shl i)) <> 0 then
      Mark := '[x]'
    else
      Mark := '[ ]';
    AddLine(Result, Format('  %s %d. %s',
                           [Mark, i + 1, ChecklistItemText(Capability, i)]));
  end;
  if Outstanding = 0 then
    AddLine(Result, '  all items covered')
  else
    AddLine(Result, Format('  %d item(s) outstanding',
                           [PopCnt(Outstanding)]));
end;

initialization
  Table := BuildTable;

end.
