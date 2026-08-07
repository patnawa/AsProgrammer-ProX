program signalchar_tests;

// The one measurement everything else rests on.
//
// The assertions worth reading twice are the ones that refuse: a rail nobody
// measured is not verified by a measurement at the other rail, a malformed
// record verifies nothing at all, and a board whose signals do not follow its
// supply is reported as exactly that rather than averaged into agreement.
//
// The build's own table is empty, and one test pins that fact: an entry
// appearing there is a claim about real hardware, and it must arrive with a
// bench measurement rather than as a side effect of some other change.

{$mode objfpc}{$H+}

uses
  SysUtils, signalchar;

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

function Rec(const ProgrammerID: string; RailMv, SignalMv: cardinal):
  TSignalCharacterisation;
begin
  Result := Default(TSignalCharacterisation);
  Result.Known := True;
  Result.ProgrammerID := ProgrammerID;
  Result.RailMv := RailMv;
  Result.SignalMv := SignalMv;
  Result.Method := 'scope on CS/CLK/MOSI, 10x probe';
  Result.MeasuredOn := '2026-08-07';
  Result.Procedure_ := 'test-procedure.md rev 1';
end;

function TableOf(const Items: array of TSignalCharacterisation):
  TSignalCharacterisations;
var
  i: integer;
begin
  Result := nil;
  SetLength(Result, Length(Items));
  for i := 0 to High(Items) do Result[i] := Items[i];
end;

function LinesContain(const Lines: TSignalLines; const Needle: string): boolean;
var
  i: integer;
begin
  for i := 0 to High(Lines) do
    if Pos(Needle, Lines[i]) > 0 then Exit(True);
  Result := False;
end;

// ------------------------------------------------------------- the default

procedure TestNothingMeasuredMeansNothingVerified;
var
  Empty: TSignalCharacterisations;
  Mv: cardinal;
  Verified: boolean;
begin
  WriteLn('An unmeasured board keeps the behaviour the program always had');
  SetLength(Empty, 0);

  ResolveSignalMvIn(Empty, 'CH347', 1800, Mv, Verified);
  Check('the rail is passed through unchanged', Mv = 1800);
  Check('and it is not claimed to be measured', not Verified);

  //This is the property that makes the unit safe to add: until somebody takes
  //a measurement, every caller sees precisely what it saw before.
  ResolveSignalMvIn(Empty, 'CH341', 3300, Mv, Verified);
  Check('the same at 3.3 V', (Mv = 3300) and (not Verified));

  Check('and there is nothing to report',
        Length(SignalCharacterisationLinesIn(Empty, 'CH347')) = 0);
end;

procedure TestThisBuildHasMeasuredNothing;
var
  Mv: cardinal;
  Verified: boolean;
  Found: TSignalCharacterisation;
  All: TSignalCharacterisations;
  ErrMsg: string;
  i: integer;
begin
  WriteLn('This build claims no measurements, and says so everywhere');

  //Deliberately pinned. An entry here is a statement about real hardware that
  //somebody put a probe on; it must not be able to appear as a side effect of
  //an unrelated change. If this assertion fails because a genuine measurement
  //was added, delete it in the same commit as the record.
  All := AllSignalCharacterisations;
  Check('the compiled-in table is empty', Length(All) = 0);

  //Whatever the table holds, every entry in it must survive validation --
  //otherwise a typo would silently drop a board back to unverified while
  //looking like it had been characterised.
  for i := 0 to High(All) do
    Check('table entry ' + IntToStr(i) + ' is well formed',
          ValidateSignalCharacterisation(All[i], ErrMsg));

  ResolveSignalMv('CH347', 1800, Mv, Verified);
  Check('the CH347 is unverified at 1.8 V', not Verified);
  Check('and reports the rail it was asked for', Mv = 1800);
  ResolveSignalMv('CH347', 3300, Mv, Verified);
  Check('the CH347 is unverified at 3.3 V', not Verified);
  ResolveSignalMv('CH341', 3300, Mv, Verified);
  Check('so is the CH341', not Verified);
  ResolveSignalMv('FT232H', 3300, Mv, Verified);
  Check('so is the FT232H', not Verified);

  Check('and nothing is found for any of them',
        not LookupSignalCharacterisation('CH347', 1800, Found));
end;

// ------------------------------------------------------- a measured board

procedure TestAMeasuredBoardReportsTheMeasurement;
var
  Records_: TSignalCharacterisations;
  Mv: cardinal;
  Verified: boolean;
begin
  WriteLn('A measured board reports the number that was measured');
  Records_ := TableOf([Rec('CH347', 1800, 1810)]);

  ResolveSignalMvIn(Records_, 'CH347', 1800, Mv, Verified);
  Check('the measured level is returned, not the requested rail', Mv = 1810);
  Check('and it is marked as measured', Verified);

  Check('the report names the rail and the level',
        LinesContain(SignalCharacterisationLinesIn(Records_, 'CH347'), '1810'));
  Check('and does not warn about a board that is behaving',
        not LinesContain(SignalCharacterisationLinesIn(Records_, 'CH347'),
                         'DO NOT FOLLOW'));
end;

procedure TestOneRailSaysNothingAboutTheOther;
var
  Records_: TSignalCharacterisations;
  Mv: cardinal;
  Verified: boolean;
begin
  WriteLn('Measuring 3.3 V does not verify 1.8 V');
  Records_ := TableOf([Rec('CH347', 3300, 3300)]);

  ResolveSignalMvIn(Records_, 'CH347', 3300, Mv, Verified);
  Check('the measured rail is verified', Verified and (Mv = 3300));

  //The 1.8 V state is a different regulator setting, and it is the one that
  //kills parts. Carrying the 3.3 V result across would verify precisely the
  //case nobody looked at.
  ResolveSignalMvIn(Records_, 'CH347', 1800, Mv, Verified);
  Check('the unmeasured rail stays unverified', not Verified);
  Check('and falls back to the requested rail', Mv = 1800);
end;

procedure TestADifferentProgrammerIsADifferentBoard;
var
  Records_: TSignalCharacterisations;
  Mv: cardinal;
  Verified: boolean;
begin
  WriteLn('A measurement belongs to the board it was taken on');
  Records_ := TableOf([Rec('CH347', 1800, 1810)]);

  ResolveSignalMvIn(Records_, 'CH341', 1800, Mv, Verified);
  Check('another programmer is not covered', not Verified);
  Check('and gets the unmeasured answer', Mv = 1800);

  //Identity comparison is case-insensitive, because the backends spell their
  //own names and a case difference is not a different board.
  ResolveSignalMvIn(Records_, 'ch347', 1800, Mv, Verified);
  Check('case does not make it a different board', Verified);
end;

// -------------------------------------------------- the dangerous finding

procedure TestSignalsThatDoNotFollowTheRail;
var
  Records_: TSignalCharacterisations;
  Mv: cardinal;
  Verified: boolean;
  Found: TSignalCharacterisation;
begin
  WriteLn('A board whose supply switched and whose signals did not');

  //The failure this unit exists for: VCC at 1.8 V, logic still swinging to
  //3.3 V. Every other field in every other report reads as correct.
  Records_ := TableOf([Rec('CH347', 1800, 3300)]);

  Check('the record is found', LookupSignalCharacterisationIn(
        Records_, 'CH347', 1800, Found));
  Check('and it is not treated as following the rail',
        not SignalFollowsRail(Found));

  ResolveSignalMvIn(Records_, 'CH347', 1800, Mv, Verified);
  //This is the whole payoff. The preflight compares this number against the
  //chip's absolute maximum and refuses; it never has to learn why.
  Check('the measured 3.3 V is what the preflight will see', Mv = 3300);
  Check('and it is a measurement, so the refusal is decided, not advisory',
        Verified);

  Check('the report says so in as many words',
        LinesContain(SignalCharacterisationLinesIn(Records_, 'CH347'),
                     'DO NOT FOLLOW THE RAIL'));
end;

procedure TestToleranceCoversRealBoardsAndNotTheKillingCase;
begin
  WriteLn('The tolerance absorbs regulators, not rail confusion');

  Check('a level right on the rail follows it',
        SignalFollowsRail(Rec('CH347', 1800, 1800)));
  Check('10% high still follows it',
        SignalFollowsRail(Rec('CH347', 1800, 1980)));
  Check('10% low still follows it',
        SignalFollowsRail(Rec('CH347', 1800, 1620)));
  Check('a little beyond does not',
        not SignalFollowsRail(Rec('CH347', 1800, 2000)));

  //The band must never be wide enough to call 3.3 V a 1.8 V rail, at either
  //end. If someone widens SIGNAL_RAIL_TOLERANCE_PERCENT far enough to break
  //this, that is the assertion that should stop them.
  Check('3.3 V is never within tolerance of a 1.8 V rail',
        not SignalFollowsRail(Rec('CH347', 1800, 3300)));
  Check('1.8 V is never within tolerance of a 3.3 V rail',
        not SignalFollowsRail(Rec('CH347', 3300, 1800)));

  Check('an unknown record follows nothing',
        not SignalFollowsRail(Default(TSignalCharacterisation)));
end;

procedure TestRailMatchingIsNarrow;
var
  Records_: TSignalCharacterisations;
  Mv: cardinal;
  Verified: boolean;
begin
  WriteLn('A rail matches its own measurement and no other');
  Records_ := TableOf([Rec('CH347', 1800, 1810)]);

  //A regulator sitting slightly off its nominal is still that rail.
  ResolveSignalMvIn(Records_, 'CH347', 1790, Mv, Verified);
  Check('a rail 10 mV away is the same rail', Verified);
  ResolveSignalMvIn(Records_, 'CH347', 1950, Mv, Verified);
  Check('a rail 150 mV away is still the same rail', Verified);

  ResolveSignalMvIn(Records_, 'CH347', 2500, Mv, Verified);
  Check('a rail 700 mV away is not', not Verified);
  ResolveSignalMvIn(Records_, 'CH347', 3300, Mv, Verified);
  Check('and 3.3 V certainly is not', not Verified);
end;

// ------------------------------------------------------------- validation

procedure TestMalformedRecordsVerifyNothing;
var
  Broken: TSignalCharacterisation;
  ErrMsg: string;
  Records_: TSignalCharacterisations;
  Mv: cardinal;
  Verified: boolean;
begin
  WriteLn('A record that does not validate cannot verify a board');

  Check('a good record validates',
        ValidateSignalCharacterisation(Rec('CH347', 1800, 1810), ErrMsg));

  Broken := Rec('CH347', 1800, 1810);
  Broken.Known := False;
  Check('an unknown record is refused',
        not ValidateSignalCharacterisation(Broken, ErrMsg));

  Broken := Rec('', 1800, 1810);
  Check('a nameless programmer is refused',
        not ValidateSignalCharacterisation(Broken, ErrMsg));

  Broken := Rec('CH347', 1800, 0);
  //Zero is railreport's "not known". Admitting it would produce a record that
  //claims to be a measurement while carrying the value that means there isn't
  //one -- the single most misleading state this unit could reach.
  Check('a zero signal level is refused',
        not ValidateSignalCharacterisation(Broken, ErrMsg));

  Broken := Rec('CH347', 0, 1810);
  Check('a zero rail is refused',
        not ValidateSignalCharacterisation(Broken, ErrMsg));

  Broken := Rec('CH347', 1800, 9000);
  Check('a level outside the safety band is refused',
        not ValidateSignalCharacterisation(Broken, ErrMsg));

  Broken := Rec('CH347', 1800, 1810);
  Broken.Method := '';
  Check('a measurement with no stated method is refused',
        not ValidateSignalCharacterisation(Broken, ErrMsg));
  Broken := Rec('CH347', 1800, 1810);
  Broken.MeasuredOn := '';
  Check('a measurement with no date is refused',
        not ValidateSignalCharacterisation(Broken, ErrMsg));
  Broken := Rec('CH347', 1800, 1810);
  Broken.Procedure_ := '';
  Check('a measurement with no named procedure is refused',
        not ValidateSignalCharacterisation(Broken, ErrMsg));

  //And the lookup must agree with the validator, or a broken entry would
  //verify a board that the validator says was never characterised.
  Broken := Rec('CH347', 1800, 1810);
  Broken.Method := '';
  Records_ := TableOf([Broken]);
  ResolveSignalMvIn(Records_, 'CH347', 1800, Mv, Verified);
  Check('a broken entry leaves the board unverified', not Verified);
  Check('and the rail comes back untouched', Mv = 1800);
  Check('and it is not reported as a measurement',
        Length(SignalCharacterisationLinesIn(Records_, 'CH347')) = 0);
end;

procedure TestFirstMatchingRecordWins;
var
  Records_: TSignalCharacterisations;
  Mv: cardinal;
  Verified: boolean;
begin
  WriteLn('Several rails on one board are kept apart');
  Records_ := TableOf([Rec('CH347', 1800, 1810), Rec('CH347', 3300, 3290),
                       Rec('CH341', 3300, 5000)]);

  ResolveSignalMvIn(Records_, 'CH347', 1800, Mv, Verified);
  Check('1.8 V finds its own record', Verified and (Mv = 1810));
  ResolveSignalMvIn(Records_, 'CH347', 3300, Mv, Verified);
  Check('3.3 V finds its own record', Verified and (Mv = 3290));

  //The classic modified CH341A: VCC reads 3.3 V, the lines drive 5 V.
  ResolveSignalMvIn(Records_, 'CH341', 3300, Mv, Verified);
  Check('the 5 V CH341 reports 5 V', Verified and (Mv = 5000));

  Check('both CH347 rails are listed',
        Length(SignalCharacterisationLinesIn(Records_, 'CH347')) = 2);
  Check('and the CH341 is not mixed in with them',
        Length(SignalCharacterisationLinesIn(Records_, 'CH341')) = 1);
end;

procedure TestFormatting;
begin
  WriteLn('Voltages read the same on every machine');
  //DecimalSeparator turns 1.8 into "1,8" in half of Europe, and a rail that
  //renders differently per machine is not one an operator can compare against
  //a datasheet.
  Check('1800 mV is 1.8 V', RailText(1800) = '1.8 V');
  Check('3300 mV is 3.3 V', RailText(3300) = '3.3 V');
  Check('5000 mV is 5.0 V', RailText(5000) = '5.0 V');
end;

begin
  TestNothingMeasuredMeansNothingVerified;
  TestThisBuildHasMeasuredNothing;
  TestAMeasuredBoardReportsTheMeasurement;
  TestOneRailSaysNothingAboutTheOther;
  TestADifferentProgrammerIsADifferentBoard;
  TestSignalsThatDoNotFollowTheRail;
  TestToleranceCoversRealBoardsAndNotTheKillingCase;
  TestRailMatchingIsNarrow;
  TestMalformedRecordsVerifyNothing;
  TestFirstMatchingRecordWins;
  TestFormatting;
  WriteLn(Assertions, ' assertions, ', Failures, ' failures');
  if Failures <> 0 then Halt(1);
  WriteLn('ALL PASSED');
end.
