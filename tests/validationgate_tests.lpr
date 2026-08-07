program validationgate_tests;

// What it takes to release a capability that is written but unreachable.
//
// The assertions worth reading twice are about partial credit. A run that
// covered six of seven items must leave the gate shut and name the seventh;
// coverage must not accumulate across separate runs; and a record that fails
// validation must count for nothing at all rather than for what it claims.
//
// One test pins the fact that this build releases nothing. A released
// capability is a statement that somebody put a sacrificial part in a socket,
// and it must not be able to arrive as a side effect of an unrelated change.

{$mode objfpc}{$H+}

uses
  SysUtils, validationgate;

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

function Ev(Capability: TGatedCapability; Covered: cardinal):
  TValidationEvidence;
begin
  Result := Default(TValidationEvidence);
  Result.Known := True;
  Result.Capability := Capability;
  Result.RunID := '18234567890';
  Result.Commit := '54e4a86';
  Result.PerformedOn := '2026-08-20';
  Result.Programmer := 'CH347';
  Result.ProgrammerFirmware := 'unavailable';
  Result.ChipMarking := 'W25Q64FW';
  Result.ChipLot := 'lot-2438A';
  Result.RailMv := 1800;
  Result.ClockHz := 15000000;
  Result.ChecklistCovered := Covered;
  Result.ArtefactSha256 :=
    '9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08';
end;

function TableOf(const Items: array of TValidationEvidence):
  TValidationEvidenceList;
var
  i: integer;
begin
  Result := nil;
  SetLength(Result, Length(Items));
  for i := 0 to High(Items) do Result[i] := Items[i];
end;

function LinesContain(const Lines: TGateLines; const Needle: string): boolean;
var
  i: integer;
begin
  for i := 0 to High(Lines) do
    if Pos(Needle, Lines[i]) > 0 then Exit(True);
  Result := False;
end;

// ------------------------------------------------------------ checklists

procedure TestChecklistsMatchTheDesignDocuments;
var
  i: integer;
begin
  WriteLn('The checklists are the ones the design documents set out');

  //docs/design-cross-platform.md, "Live validation gate", six numbered items.
  Check('the libusb write checklist has six items',
        ChecklistItemCount(gcCH347LibusbWrite) = 6);
  //docs/design-spi-nand.md, "Live-validation checklist", seven numbered items.
  Check('the NAND mutation checklist has seven items',
        ChecklistItemCount(gcSPINANDMutation) = 7);

  //If an item is added to a design document and not here, that is a quietly
  //weakened requirement; these counts are what makes it a build failure.
  Check('six items is a mask of $3F',
        RequiredChecklistMask(gcCH347LibusbWrite) = $3F);
  Check('seven items is a mask of $7F',
        RequiredChecklistMask(gcSPINANDMutation) = $7F);

  for i := 0 to ChecklistItemCount(gcCH347LibusbWrite) - 1 do
    Check('libusb item ' + IntToStr(i + 1) + ' says something',
          Length(ChecklistItemText(gcCH347LibusbWrite, i)) > 20);
  for i := 0 to ChecklistItemCount(gcSPINANDMutation) - 1 do
    Check('NAND item ' + IntToStr(i + 1) + ' says something',
          Length(ChecklistItemText(gcSPINANDMutation, i)) > 20);

  Check('an index past the end returns nothing, not a neighbour',
        ChecklistItemText(gcCH347LibusbWrite, 6) = '');
  Check('and neither does a negative one',
        ChecklistItemText(gcCH347LibusbWrite, -1) = '');

  Check('each capability names its document',
        (CapabilityDocument(gcCH347LibusbWrite) =
           'docs/design-cross-platform.md') and
        (CapabilityDocument(gcSPINANDMutation) = 'docs/design-spi-nand.md'));
end;

// --------------------------------------------------------- what this build

procedure TestThisBuildReleasesNothing;
var
  Reason: string;
  All: TValidationEvidenceList;
  ErrMsg: string;
  i: integer;
begin
  WriteLn('This build has validated nothing on silicon, and says which items');

  //Deliberately pinned. Delete this in the same commit as a genuine record.
  All := AllValidationEvidence;
  Check('the compiled-in evidence table is empty', Length(All) = 0);

  //Whatever it holds, every entry must survive validation, or a typo would
  //release a destructive path while looking like diligence.
  for i := 0 to High(All) do
    Check('evidence entry ' + IntToStr(i) + ' is well formed',
          ValidateEvidence(All[i], ErrMsg));

  Check('destructive libusb write is gated',
        not IsReleased(gcCH347LibusbWrite, Reason));
  //This is the whole improvement over "pending live validation": the refusal
  //is actionable.
  Check('and the refusal names the design document',
        Pos('design-cross-platform.md', Reason) > 0);
  Check('and names an outstanding item', Pos('(1)', Reason) > 0);
  Check('and the last one too', Pos('(6)', Reason) > 0);

  Check('SPI NAND mutation is gated',
        not IsReleased(gcSPINANDMutation, Reason));
  Check('and the refusal names its document',
        Pos('design-spi-nand.md', Reason) > 0);
  Check('and its seventh item', Pos('(7)', Reason) > 0);

  Check('the status summary lists both gates',
        Length(GateStatusLines) = 2);
  Check('and marks them gated', LinesContain(GateStatusLines, 'gated:'));
  //One line each. The summary goes in --help; the page of checklist text
  //belongs behind --gates, which is what somebody runs after reading it.
  Check('the summary counts the outstanding items rather than listing them',
        LinesContain(GateStatusLines, '7 of 7 checklist items outstanding'));
  Check('and stays short enough to read',
        Length(GateStatusLines[0]) < 120);
end;

// ------------------------------------------------------- a complete run

procedure TestACompleteRunReleasesTheCapability;
var
  Records_: TValidationEvidenceList;
  Reason: string;
begin
  WriteLn('A run that covered every item releases the capability');
  Records_ := TableOf([Ev(gcCH347LibusbWrite, $3F)]);

  Check('the gate opens', IsReleasedIn(Records_, gcCH347LibusbWrite, Reason));
  //Released is not silent: a destructive path that became available should be
  //able to say why, in a log, at the moment it is used.
  Check('and it cites the run', Pos('18234567890', Reason) > 0);
  Check('and the chip it was proved on', Pos('W25Q64FW', Reason) > 0);
  Check('and the commit', Pos('54e4a86', Reason) > 0);

  //Releasing one capability must not release the other. They are different
  //code paths on different silicon.
  Check('the other capability is untouched',
        not IsReleasedIn(Records_, gcSPINANDMutation, Reason));

  Check('the summary says released',
        LinesContain(GateStatusLinesIn(Records_), 'released:'));
end;

procedure TestPartialCoverageDoesNotRelease;
var
  Records_: TValidationEvidenceList;
  Reason: string;
begin
  WriteLn('Six of seven is not seven');

  //Item 7 -- restore the original image and verify it -- omitted. In practice
  //that is exactly the item that gets skipped when a bench session runs long,
  //and it is the one that proves the part survived.
  Records_ := TableOf([Ev(gcSPINANDMutation, $3F)]);

  Check('the gate stays shut',
        not IsReleasedIn(Records_, gcSPINANDMutation, Reason));
  Check('and it says a run exists', Pos('partly validated', Reason) > 0);
  Check('and names the missing item and only that one',
        (Pos('(7)', Reason) > 0) and (Pos('(1)', Reason) = 0));

  Check('the checklist shows six ticked and one not',
        LinesContain(ChecklistLinesIn(Records_, gcSPINANDMutation),
                     '1 item(s) outstanding'));
  Check('with the covered items marked',
        LinesContain(ChecklistLinesIn(Records_, gcSPINANDMutation), '[x] 1.'));
  Check('and the outstanding one not',
        LinesContain(ChecklistLinesIn(Records_, gcSPINANDMutation), '[ ] 7.'));
end;

procedure TestCoverageDoesNotAccumulateAcrossRuns;
var
  Records_: TValidationEvidenceList;
  Reason: string;
begin
  WriteLn('Two half-runs are not one whole run');

  //The point of items 4 and 5 is that they happened to the same part, in the
  //same session, as items 1 to 3. A restore verified against a backup some
  //other run took last month is not a verified restore, so unioning the masks
  //would release the gate on evidence that never existed.
  Records_ := TableOf([Ev(gcCH347LibusbWrite, $07),
                       Ev(gcCH347LibusbWrite, $38)]);

  Check('the gate stays shut',
        not IsReleasedIn(Records_, gcCH347LibusbWrite, Reason));
  Check('and the outstanding list is against the best single run, not the union',
        (Pos('(1)', Reason) > 0) and (Pos('(2)', Reason) > 0) and
        (Pos('(3)', Reason) > 0));

  //And one complete run alongside the partial ones does release it.
  Records_ := TableOf([Ev(gcCH347LibusbWrite, $07),
                       Ev(gcCH347LibusbWrite, $3F),
                       Ev(gcCH347LibusbWrite, $38)]);
  Check('a complete run among partial ones is found',
        IsReleasedIn(Records_, gcCH347LibusbWrite, Reason));
end;

// ------------------------------------------------------------ validation

procedure TestIncompleteRecordsCountForNothing;
var
  Broken: TValidationEvidence;
  ErrMsg, Reason: string;
  Records_: TValidationEvidenceList;
begin
  WriteLn('A record that cannot answer for itself releases nothing');

  Check('a complete record validates',
        ValidateEvidence(Ev(gcCH347LibusbWrite, $3F), ErrMsg));

  Broken := Ev(gcCH347LibusbWrite, $3F);
  Broken.Known := False;
  Check('an unknown record is refused',
        not ValidateEvidence(Broken, ErrMsg));

  Broken := Ev(gcCH347LibusbWrite, $3F);
  Broken.Commit := '';
  //Without it the record says a program was validated but not which one.
  Check('a record with no software revision is refused',
        not ValidateEvidence(Broken, ErrMsg));

  Broken := Ev(gcCH347LibusbWrite, $3F);
  Broken.ChipLot := '';
  Check('a record with no chip lot is refused',
        not ValidateEvidence(Broken, ErrMsg));

  Broken := Ev(gcCH347LibusbWrite, $3F);
  Broken.RailMv := 0;
  Check('a record with no measured rail is refused',
        not ValidateEvidence(Broken, ErrMsg));

  Broken := Ev(gcCH347LibusbWrite, $3F);
  Broken.ClockHz := 0;
  Check('a record with no clock is refused',
        not ValidateEvidence(Broken, ErrMsg));

  Broken := Ev(gcCH347LibusbWrite, $3F);
  Broken.ArtefactSha256 := '';
  //A record with no artefact asserts a result instead of pointing at one.
  Check('a record with no evidence bundle is refused',
        not ValidateEvidence(Broken, ErrMsg));
  Broken.ArtefactSha256 := 'NOTHEX';
  Check('and a malformed hash is refused too',
        not ValidateEvidence(Broken, ErrMsg));
  Broken.ArtefactSha256 :=
    '9F86D081884C7D659A2FEAA0C55AD015A3BF4F1B2B0B822CD15D6C15B0F00A08';
  Check('an uppercase hash is not the canonical form',
        not ValidateEvidence(Broken, ErrMsg));

  //Bits above the checklist mean the record was written against a different
  //version of the list, so it cannot be read as covering this one.
  Broken := Ev(gcCH347LibusbWrite, $FF);
  Check('a record claiming items this capability lacks is refused',
        not ValidateEvidence(Broken, ErrMsg));

  //And the gate must agree with the validator.
  Broken := Ev(gcCH347LibusbWrite, $3F);
  Broken.ArtefactSha256 := '';
  Records_ := TableOf([Broken]);
  Check('a broken record does not open the gate',
        not IsReleasedIn(Records_, gcCH347LibusbWrite, Reason));
  Check('and the gate reports it as having no validation at all',
        Pos('no hardware-in-loop validation', Reason) > 0);
end;

procedure TestNamesAreStable;
begin
  WriteLn('The capability names are a published interface');
  //They appear in --help output, in refusals, and in the session report, so a
  //rename is a user-visible change and should have to be deliberate.
  Check('libusb write', CapabilityName(gcCH347LibusbWrite) = 'ch347_libusb_write');
  Check('NAND mutation', CapabilityName(gcSPINANDMutation) = 'spi_nand_mutation');
end;

begin
  TestChecklistsMatchTheDesignDocuments;
  TestThisBuildReleasesNothing;
  TestACompleteRunReleasesTheCapability;
  TestPartialCoverageDoesNotRelease;
  TestCoverageDoesNotAccumulateAcrossRuns;
  TestIncompleteRecordsCountForNothing;
  TestNamesAreStable;
  WriteLn(Assertions, ' assertions, ', Failures, ' failures');
  if Failures <> 0 then Halt(1);
  WriteLn('ALL PASSED');
end.
