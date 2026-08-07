program clocktune_tests;

// Choosing a clock the wiring can carry, and refusing to erase when the chip
// answers the same question two different ways.
//
// The reader below is a fake chip with a configurable breaking point, which
// is the only way to exercise the interesting cases: real hardware will not
// reliably corrupt a transfer on demand, and the cases worth pinning are
// exactly the ones that are intermittent on a bench.

{$mode objfpc}{$H+}

uses
  SysUtils, clocktune;

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

procedure CheckText(const Name, Expected, Actual: string);
begin
  Inc(Assertions);
  if Expected <> Actual then
  begin
    Inc(Failures);
    WriteLn('FAIL: ', Name, ' (expected "', Expected, '", got "',
            Actual, '")');
  end;
end;

// --- the fake chip -------------------------------------------------------
//
// Answers 'EF4017' below FakeBreaksAboveHz and misbehaves above it, in
// whichever way FakeMode selects.

type
  TFakeMode = (fmGarbageWhenFast, fmFailWhenFast, fmIntermittentWhenFast,
               fmDeadEverywhere, fmUnstableEverywhere, fmBlankWhenFast);

var
  FakeBreaksAboveHz: cardinal;
  FakeMode: TFakeMode;
  FakeCalls: integer;

function FakeReader(ClockHz: cardinal; out Identity: string): boolean;
begin
  Inc(FakeCalls);
  Identity := '';
  Result := True;

  if FakeMode = fmDeadEverywhere then Exit(False);
  if FakeMode = fmUnstableEverywhere then
  begin
    //A clip that is barely touching: a different answer every time, at any
    //speed at all.
    Identity := 'EF40' + IntToHex(FakeCalls and $FF, 2);
    Exit;
  end;

  if ClockHz <= FakeBreaksAboveHz then
  begin
    Identity := 'EF4017';
    Exit;
  end;

  case FakeMode of
    fmGarbageWhenFast:
      Identity := 'EF40' + IntToHex((FakeCalls * 37) and $FF, 2);
    fmFailWhenFast:
      Result := False;
    fmBlankWhenFast:
      //The failure the README warns about: too fast reads back as FF, which
      //is a completed transaction carrying no information.
      Identity := 'FFFFFF';
    fmIntermittentWhenFast:
      //Right two times in three.  A tuner that stops at the first agreement
      //walks straight past the boundary.
      if (FakeCalls mod 3) = 0 then
        Identity := 'EF4000'
      else
        Identity := 'EF4017';
  end;
end;

procedure ResetFake(BreaksAboveHz: cardinal; Mode: TFakeMode);
begin
  FakeBreaksAboveHz := BreaksAboveHz;
  FakeMode := Mode;
  FakeCalls := 0;
end;

function CH347Ladder: TClockLadder;
begin
  //Exactly the rungs the CH347 menu offers: 60 MHz halved down to 468.75 kHz.
  Result := StandardLadder(60000000, 468750);
end;

// --- ladder --------------------------------------------------------------

procedure TestLadder;
var
  L: TClockLadder;
begin
  L := CH347Ladder;
  Check('the CH347 ladder has eight rungs', Length(L) = 8);
  //Slowest first is the safety property, not a formatting choice.
  Check('the ladder starts at the slowest clock', L[0] = 468750);
  Check('and ends at the fastest', L[High(L)] = 60000000);
  Check('each rung is double the one below', L[1] = 937500);

  L := StandardLadder(0, 1000);
  Check('a zero maximum produces no ladder', Length(L) = 0);
  L := StandardLadder(1000, 2000);
  Check('a floor above the ceiling produces no ladder', Length(L) = 0);
  L := StandardLadder(1000000, 1);
  Check('an absurd floor still terminates', Length(L) <= 32);
end;

procedure TestClockText;
begin
  CheckText('a whole megahertz drops its fraction', '60 MHz',
            ClockText(60000000));
  CheckText('a fractional megahertz keeps it', '1.875 MHz',
            ClockText(1875000));
  CheckText('sub-megahertz reads in kilohertz', '468.75 kHz',
            ClockText(468750));
  CheckText('and trims to a whole kilohertz', '937.5 kHz',
            ClockText(937500));
end;

// --- identity sanity -----------------------------------------------------

procedure TestMeaninglessIdentities;
begin
  //An undriven bus with pull-ups reads FF; a bus held down reads 00.  Both
  //are completed transactions carrying nothing, and both have been mistaken
  //for chips.
  Check('all-FF is not an identity', IsMeaninglessIdentity('FFFFFF'));
  Check('all-00 is not an identity', IsMeaninglessIdentity('000000'));
  Check('an empty reply is not an identity', IsMeaninglessIdentity(''));
  Check('separators do not make FF meaningful',
    IsMeaninglessIdentity('FF-FF-FF'));
  Check('a real JEDEC ID is an identity',
    not IsMeaninglessIdentity('EF4017'));
  //EF6017 is a 1.8 V Winbond: mostly high bits, and it must not be mistaken
  //for an undriven bus.
  Check('a mostly-high real ID survives',
    not IsMeaninglessIdentity('EF6017'));
end;

// --- tuning --------------------------------------------------------------

procedure TestTunesToTheBoundary;
var
  R: TTuneResult;
begin
  //A clip lead that carries 7.5 MHz and not 15 MHz.
  ResetFake(7500000, fmGarbageWhenFast);
  R := AutoTuneClock(CH347Ladder, @FakeReader, 3, 0);
  Check('a working chip tunes', R.Status = tsTuned);
  Check('the reference is what the chip said slowly', R.Reference = 'EF4017');
  Check('the boundary is found exactly', R.HighestStableHz = 7500000);
  Check('and with no margin asked for, it is used', R.ChosenHz = 7500000);
  Check('the operator is told where it broke',
    Pos('15 MHz', R.Detail) > 0);
end;

procedure TestSafetyMarginStepsDown;
var
  R: TTuneResult;
begin
  //The boundary found once on a still bench is not one that holds all
  //afternoon, so the program does not sit on it.
  ResetFake(7500000, fmGarbageWhenFast);
  R := AutoTuneClock(CH347Ladder, @FakeReader, 3, 1);
  Check('the margin does not change what was measured',
    R.HighestStableHz = 7500000);
  Check('but the clock used is one rung below', R.ChosenHz = 3750000);
  Check('and the operator is told the margin cost something',
    Pos('margin', R.Detail) > 0);

  //A margin larger than the ladder must land on the slowest rung, not
  //underflow past it.
  ResetFake(937500, fmGarbageWhenFast);
  R := AutoTuneClock(CH347Ladder, @FakeReader, 3, 9);
  Check('an oversized margin stops at the slowest rung',
    R.ChosenHz = 468750);
end;

procedure TestFailureModesAtSpeedAllStopTheClimb;
var
  R: TTuneResult;
begin
  //A transfer that does not complete.
  ResetFake(3750000, fmFailWhenFast);
  R := AutoTuneClock(CH347Ladder, @FakeReader, 3, 0);
  Check('a failed transaction ends the climb', R.Status = tsTuned);
  Check('at the last rung that answered', R.ChosenHz = 3750000);

  //The exact failure the README describes: too fast reads back as FF.  A
  //tuner that only compared "did it answer" would climb straight past this.
  ResetFake(3750000, fmBlankWhenFast);
  R := AutoTuneClock(CH347Ladder, @FakeReader, 3, 0);
  Check('an all-FF reply is not mistaken for agreement',
    R.ChosenHz = 3750000);
end;

procedure TestIntermittentFailuresAreCaught;
var
  R: TTuneResult;
begin
  //Right two times in three above the boundary.  One read per rung would
  //accept this clock two thirds of the time, which is the worst possible
  //outcome: fast, plausible, and wrong during the write.
  ResetFake(1875000, fmIntermittentWhenFast);
  R := AutoTuneClock(CH347Ladder, @FakeReader, 3, 0);
  Check('repetition catches an intermittent clock',
    R.ChosenHz <= 1875000);
end;

procedure TestConnectionFaultsAreNotSpeedFaults;
var
  R: TTuneResult;
begin
  //A clip that is not touching gives a different answer every time, at every
  //speed.  Reporting this as "try a slower clock" sends the operator down a
  //ten-minute dead end.
  ResetFake(60000000, fmUnstableEverywhere);
  R := AutoTuneClock(CH347Ladder, @FakeReader, 3, 0);
  Check('an unstable connection is named as one',
    R.Status = tsUnstableAtSlowest);
  Check('and is not offered a clock to use', R.ChosenHz = 0);
  Check('and says so in words',
    Pos('connection fault, not a speed one', R.Detail) > 0);

  ResetFake(60000000, fmDeadEverywhere);
  R := AutoTuneClock(CH347Ladder, @FakeReader, 3, 0);
  Check('a chip that never answers is a third, distinct outcome',
    R.Status = tsNoAnswer);
  Check('and is not offered a clock either', R.ChosenHz = 0);
end;

procedure TestDegenerateInputs;
var
  R: TTuneResult;
  Empty: TClockLadder;
begin
  SetLength(Empty, 0);
  ResetFake(60000000, fmGarbageWhenFast);
  R := AutoTuneClock(Empty, @FakeReader, 3, 0);
  Check('an empty ladder is refused, not guessed', R.Status = tsNoAnswer);

  R := AutoTuneClock(CH347Ladder, nil, 3, 0);
  Check('a missing reader is refused', R.Status = tsNoAnswer);

  //One read per rung cannot compare anything, so the floor is raised rather
  //than silently producing a conclusion that rests on nothing.
  ResetFake(60000000, fmGarbageWhenFast);
  R := AutoTuneClock(CH347Ladder, @FakeReader, 1, 0);
  Check('a single read per rung is raised to a comparison',
    FakeCalls >= 2 * Length(CH347Ladder));
end;

// --- the stability gate --------------------------------------------------

function Sample(Address: cardinal; const A, B: array of byte;
  AOk: boolean = True; BOk: boolean = True): TSamplePair;
var
  i: integer;
begin
  Result.Address := Address;
  Result.FirstOk := AOk;
  Result.SecondOk := BOk;
  SetLength(Result.First, Length(A));
  for i := 0 to High(A) do Result.First[i] := A[i];
  SetLength(Result.Second, Length(B));
  for i := 0 to High(B) do Result.Second[i] := B[i];
end;

procedure TestStabilityGate;
var
  Samples: array of TSamplePair;
  V: TStabilityVerdict;
begin
  SetLength(Samples, 2);
  Samples[0] := Sample($000000, [$12, $34, $56], [$12, $34, $56]);
  Samples[1] := Sample($7F0000, [$AA, $BB], [$AA, $BB]);
  V := EvaluateSampleStability(Samples);
  Check('two agreeing reads are stable', V.Stable);
  Check('and are not mistaken for a blank chip', not V.AllBlank);

  //The whole point: a chip that answers differently invalidates the backup,
  //so there is nothing to fall back to if the erase goes wrong.
  Samples[1] := Sample($7F0000, [$AA, $BB, $CC], [$AA, $B7, $CC]);
  V := EvaluateSampleStability(Samples);
  Check('a disagreement is refused', not V.Stable);
  Check('the failing region is named', V.FailedAddress = $7F0000);
  //"Verify failed" with no offset is what sends someone through a megabyte
  //by hand.
  Check('the first differing byte is located', V.HasOffset);
  Check('at its absolute address', V.FirstDifferingOffset = $7F0001);

  SetLength(Samples, 1);
  Samples[0] := Sample($10, [$01], [$01], True, False);
  V := EvaluateSampleStability(Samples);
  Check('a read that did not complete is refused', not V.Stable);

  //A short second transfer is a disconnect in disguise, not a shorter answer.
  Samples[0] := Sample($10, [$01, $02, $03], [$01, $02]);
  V := EvaluateSampleStability(Samples);
  Check('differing lengths are refused', not V.Stable);
  Check('and named as such', Pos('different lengths', V.Reason) > 0);

  SetLength(Samples, 0);
  V := EvaluateSampleStability(Samples);
  //"Proved nothing" must never come back as "stable".
  Check('an empty sample set is not stable', not V.Stable);
end;

procedure TestBlankIsReportedNotRefused;
var
  Samples: array of TSamplePair;
  V: TStabilityVerdict;
begin
  //A genuinely blank chip reads FF everywhere, and so does a chip that is
  //not connected.  Refusing would block legitimate work on erased parts;
  //staying silent would let a dead bus pass as a verified connection.
  SetLength(Samples, 1);
  Samples[0] := Sample($00, [$FF, $FF, $FF], [$FF, $FF, $FF]);
  V := EvaluateSampleStability(Samples);
  Check('an all-FF sample is still stable', V.Stable);
  Check('but is flagged as proving little', V.AllBlank);
  Check('and says why',
    Pos('cannot tell a blank chip from an unconnected one', V.Reason) > 0);

  //One non-FF byte anywhere is proof something is driving the bus.
  Samples[0] := Sample($00, [$FF, $00, $FF], [$FF, $00, $FF]);
  V := EvaluateSampleStability(Samples);
  Check('one driven byte clears the blank flag', not V.AllBlank);
end;

begin
  TestLadder;
  TestClockText;
  TestMeaninglessIdentities;
  TestTunesToTheBoundary;
  TestSafetyMarginStepsDown;
  TestFailureModesAtSpeedAllStopTheClimb;
  TestIntermittentFailuresAreCaught;
  TestConnectionFaultsAreNotSpeedFaults;
  TestDegenerateInputs;
  TestStabilityGate;
  TestBlankIsReportedNotRefused;
  WriteLn(Assertions, ' assertions, ', Failures, ' failures');
  if Failures <> 0 then Halt(1);
  WriteLn('ALL PASSED');
end.
