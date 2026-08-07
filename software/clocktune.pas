unit clocktune;

// Finding a clock the wiring in front of you can actually carry, and proving
// the connection holds still before anything destructive runs.
//
// The README already warns that clip leads and long cables do not survive
// 60 MHz and read back as FF.  Leaving that to the operator means choosing
// between a menu of numbers with no feedback: too fast reads garbage that
// looks like a blank chip, too slow wastes minutes per megabyte, and nothing
// in between tells you which side of the line you are on.
//
// So the program finds the line.  Start slow, where the wiring cannot be the
// problem, and establish what the chip says about itself.  Step up, asking
// the same question at each rung.  The moment the answer changes, the rung
// below was the last good one -- and then step down again for margin, because
// the boundary found once by a warm chip on a still bench is not a boundary
// that holds all afternoon.
//
// The second half of the unit is the gate that matters more.  A tuned clock
// proves the identity register came back intact; it does not prove that a
// megabyte of data will.  Before an erase or a write, the caller reads sample
// regions twice and hands both copies here.  If a chip returns two different
// answers to the same question, nothing that follows can be trusted -- not the
// backup, not the verify, not the erase plan -- and the only correct response
// is to refuse, not to retry.
//
// Everything here is a decision over observations.  No hardware access, no
// LCL, no I/O: the caller does the reading, this unit does the judging, and
// the judging is exercised in memory against fingerprints and buffers that a
// test writes by hand.

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

type
  // Candidate clocks in hertz, slowest first.  Slowest first is not a
  // convention, it is the safety property: the reference identity must be
  // established where the wiring cannot be the reason it is wrong.
  TClockLadder = array of cardinal;

  TTuneStatus = (
    // No clock on the ladder produced an answer at all.  Nothing is
    // connected, the chip is not powered, or the rail is wrong.
    tsNoAnswer,
    // The slowest clock produced answers that disagreed with each other.
    // Speed is not the problem; the connection is.  Slowing down further
    // will not fix a clip that is not touching.
    tsUnstableAtSlowest,
    tsTuned
  );

  TTuneResult = record
    Status: TTuneStatus;
    // The clock to use.  Only meaningful when Status is tsTuned.
    ChosenHz: cardinal;
    // The fastest rung that still agreed, before the safety margin was
    // subtracted.  Reported so an operator can see what the margin cost.
    HighestStableHz: cardinal;
    // What the chip said about itself at the slowest clock.
    Reference: string;
    Probes: integer;
    Detail: string;
  end;

  // Reads the chip's identity once, at ClockHz.  Identity is whatever the
  // caller considers to identify the part -- in this program, the JEDEC ID
  // followed by a digest of the SFDP table, so that a clock fast enough to
  // corrupt a long transfer but not a three-byte one is still caught.
  //
  // Returns False when the transaction itself did not complete.  A completed
  // transaction that returned nonsense is a True with a nonsense Identity,
  // and this unit tells the two apart.
  TIdentityReader = function(ClockHz: cardinal;
    out Identity: string): boolean;

  TSamplePair = record
    Address: cardinal;
    FirstOk: boolean;
    SecondOk: boolean;
    First: TBytes;
    Second: TBytes;
  end;

  TStabilityVerdict = record
    // False means no erase and no write.  Not "warn and continue": two
    // different answers to the same question invalidate the backup that
    // recovery depends on.
    Stable: boolean;
    Reason: string;
    FailedAddress: cardinal;
    // Where the two reads first parted company.  Named because "verify
    // failed" without an offset is the message that sends someone hunting
    // through a megabyte by hand.
    HasOffset: boolean;
    FirstDifferingOffset: cardinal;
    // Every sampled byte was FF in both reads.  Not a failure -- a blank
    // chip is a real thing -- but it does mean these samples proved much
    // less than they appear to, because a disconnected bus reads FF very
    // consistently.
    AllBlank: boolean;
  end;

// Halving ladder from a floor up to MaxHz, slowest first.  This is the shape
// every backend in this program actually exposes: CH347 divides 60 MHz by
// powers of two, FT232H and the AVR-based programmers do the same.
function StandardLadder(MaxHz, MinHz: cardinal): TClockLadder;

// True when an identity carries no information: all bits high is an
// undriven bus with pull-ups, all bits low is a bus held down, and a chip
// that is not answering produces one or the other rather than an error.
function IsMeaninglessIdentity(const Identity: string): boolean;

// Walks the ladder and returns the fastest clock whose answers all matched
// the reference, less SafetyMarginSteps rungs.
//
// RepeatsPerStep must be at least 2 for the comparison to mean anything; 3
// is the value the program uses, because two reads agreeing by chance is
// common on a marginal clock and three is not.
function AutoTuneClock(const Ladder: TClockLadder; Reader: TIdentityReader;
  RepeatsPerStep, SafetyMarginSteps: integer): TTuneResult;

// Judges paired reads of the same addresses.  Refuses on the first
// disagreement, and reports where.
function EvaluateSampleStability(
  const Samples: array of TSamplePair): TStabilityVerdict;

function TuneStatusName(Status: TTuneStatus): string;
function ClockText(Hz: cardinal): string;

implementation

function TuneStatusName(Status: TTuneStatus): string;
begin
  case Status of
    tsNoAnswer:          Result := 'no_answer';
    tsUnstableAtSlowest: Result := 'unstable_at_slowest';
    tsTuned:             Result := 'tuned';
  end;
end;

function ClockText(Hz: cardinal): string;
begin
  //Locale-independent, like every other number this program shows an
  //operator: a clock that renders as "1,875 MHz" on a German machine cannot
  //be matched against the menu entry that produced it.
  if Hz >= 1000000 then
    Result := Format('%d.%.3d MHz', [Hz div 1000000, (Hz mod 1000000) div 1000])
  else
    Result := Format('%d.%.3d kHz', [Hz div 1000, Hz mod 1000]);
  //Trim trailing zeros in the fraction, then a bare decimal point.
  while (Pos('.', Result) > 0) and
        (Copy(Result, Length(Result) - 4, 1) = '0') do
    Delete(Result, Length(Result) - 4, 1);
  if Copy(Result, Length(Result) - 4, 1) = '.' then
    Delete(Result, Length(Result) - 4, 1);
end;

function StandardLadder(MaxHz, MinHz: cardinal): TClockLadder;
var
  Descending: array of cardinal;
  Hz: cardinal;
  N, i: integer;
begin
  Result := nil;
  if (MaxHz = 0) or (MinHz = 0) or (MinHz > MaxHz) then Exit;

  Descending := nil;
  Hz := MaxHz;
  N := 0;
  //Bounded so a caller that passes a MinHz of 1 cannot spin: 32 halvings
  //takes any realistic clock below one hertz.
  while (Hz >= MinHz) and (N < 32) do
  begin
    SetLength(Descending, N + 1);
    Descending[N] := Hz;
    Inc(N);
    Hz := Hz div 2;
  end;

  //Slowest first.
  SetLength(Result, N);
  for i := 0 to N - 1 do
    Result[i] := Descending[N - 1 - i];
end;

function IsMeaninglessIdentity(const Identity: string): boolean;
var
  i: integer;
  AllF, AllZero, SawHexDigit: boolean;
  C: char;
begin
  if Identity = '' then Exit(True);
  AllF := True;
  AllZero := True;
  SawHexDigit := False;
  for i := 1 to Length(Identity) do
  begin
    C := UpCase(Identity[i]);
    //Separators and the caller's own labels carry no evidence either way.
    if not (C in ['0'..'9', 'A'..'F']) then Continue;
    SawHexDigit := True;
    if C <> 'F' then AllF := False;
    if C <> '0' then AllZero := False;
  end;
  Result := (not SawHexDigit) or AllF or AllZero;
end;

function AutoTuneClock(const Ladder: TClockLadder; Reader: TIdentityReader;
  RepeatsPerStep, SafetyMarginSteps: integer): TTuneResult;
var
  Reference, Identity: string;
  i, r, BestIndex, ChosenIndex: integer;
  Agreed: boolean;
begin
  Result.Status := tsNoAnswer;
  Result.ChosenHz := 0;
  Result.HighestStableHz := 0;
  Result.Reference := '';
  Result.Probes := 0;
  Result.Detail := '';

  if Length(Ladder) = 0 then
  begin
    Result.Detail := 'no candidate clocks were supplied';
    Exit;
  end;
  if Reader = nil then
  begin
    Result.Detail := 'no identity reader was supplied';
    Exit;
  end;
  //Two reads that agree prove very little on a marginal clock; the whole
  //method rests on repetition, so a caller that asks for one gets the
  //minimum that can carry the conclusion.
  if RepeatsPerStep < 2 then RepeatsPerStep := 2;
  if SafetyMarginSteps < 0 then SafetyMarginSteps := 0;

  //--- the reference, at the slowest clock the ladder offers ---
  Reference := '';
  for r := 1 to RepeatsPerStep do
  begin
    Inc(Result.Probes);
    if not Reader(Ladder[0], Identity) then
    begin
      Result.Status := tsNoAnswer;
      Result.Detail := 'the chip did not answer at ' + ClockText(Ladder[0]);
      Exit;
    end;
    if IsMeaninglessIdentity(Identity) then
    begin
      Result.Status := tsNoAnswer;
      Result.Detail := 'the reply at ' + ClockText(Ladder[0]) +
                       ' carried no identity';
      Exit;
    end;
    if r = 1 then
      Reference := Identity
    else if Identity <> Reference then
    begin
      //Slowing down cannot fix this.  Saying so is the point: the operator
      //is about to spend ten minutes trying slower clocks otherwise.
      Result.Status := tsUnstableAtSlowest;
      Result.Reference := Reference;
      Result.Detail := 'the chip gave different identities at ' +
        ClockText(Ladder[0]) + ', the slowest clock available; this is a ' +
        'connection fault, not a speed one';
      Exit;
    end;
  end;

  Result.Reference := Reference;
  Result.Status := tsTuned;
  BestIndex := 0;

  //--- climb until the answer changes ---
  for i := 1 to High(Ladder) do
  begin
    Agreed := True;
    for r := 1 to RepeatsPerStep do
    begin
      Inc(Result.Probes);
      if (not Reader(Ladder[i], Identity)) or
         IsMeaninglessIdentity(Identity) or
         (Identity <> Reference) then
      begin
        Agreed := False;
        Break;
      end;
    end;
    //The first rung that disagrees ends the climb.  Continuing past it to
    //look for a faster one that happens to agree is how a marginal clock
    //gets chosen: above the boundary the failures are intermittent, so some
    //rungs pass by luck.
    if not Agreed then Break;
    BestIndex := i;
  end;

  Result.HighestStableHz := Ladder[BestIndex];
  ChosenIndex := BestIndex - SafetyMarginSteps;
  if ChosenIndex < 0 then ChosenIndex := 0;
  Result.ChosenHz := Ladder[ChosenIndex];

  if BestIndex = High(Ladder) then
    Result.Detail := 'stable at every clock offered, up to ' +
                     ClockText(Ladder[BestIndex])
  else
    Result.Detail := 'stable to ' + ClockText(Ladder[BestIndex]) +
                     ', first disagreement at ' + ClockText(Ladder[BestIndex + 1]);
  if Result.ChosenHz <> Result.HighestStableHz then
    Result.Detail := Result.Detail + '; using ' + ClockText(Result.ChosenHz) +
                     ' for margin';
end;

function EvaluateSampleStability(
  const Samples: array of TSamplePair): TStabilityVerdict;
var
  i: integer;
  Offset: integer;
  Blank: boolean;
begin
  Result.Stable := False;
  Result.Reason := '';
  Result.FailedAddress := 0;
  Result.HasOffset := False;
  Result.FirstDifferingOffset := 0;
  Result.AllBlank := False;

  if Length(Samples) = 0 then
  begin
    //An empty sample set proves nothing, and "proves nothing" must never
    //come back as "stable".
    Result.Reason := 'no sample regions were read';
    Exit;
  end;

  Blank := True;
  for i := 0 to High(Samples) do
  begin
    if (not Samples[i].FirstOk) or (not Samples[i].SecondOk) then
    begin
      Result.Reason := 'a sample read did not complete';
      Result.FailedAddress := Samples[i].Address;
      Exit;
    end;
    if Length(Samples[i].First) = 0 then
    begin
      Result.Reason := 'a sample read returned no data';
      Result.FailedAddress := Samples[i].Address;
      Exit;
    end;
    if Length(Samples[i].First) <> Length(Samples[i].Second) then
    begin
      //Two reads of the same range that returned different lengths is a
      //short transfer, which is a disconnect wearing a disguise.
      Result.Reason := 'two reads of the same range returned different lengths';
      Result.FailedAddress := Samples[i].Address;
      Exit;
    end;

    for Offset := 0 to High(Samples[i].First) do
    begin
      if Samples[i].First[Offset] <> Samples[i].Second[Offset] then
      begin
        Result.Reason := 'the chip returned two different answers for the ' +
          'same address range';
        Result.FailedAddress := Samples[i].Address;
        Result.HasOffset := True;
        Result.FirstDifferingOffset := Samples[i].Address + cardinal(Offset);
        Exit;
      end;
      if (Samples[i].First[Offset] <> $FF) then Blank := False;
    end;
  end;

  Result.Stable := True;
  //Reported, not refused.  A blank chip really does read FF everywhere, and
  //so does a chip that is not connected -- the operator is the one who knows
  //which of those they are looking at.
  Result.AllBlank := Blank;
  if Blank then
    Result.Reason := 'every sampled byte was FF; these samples cannot tell a ' +
                     'blank chip from an unconnected one'
  else
    Result.Reason := 'both reads of every sample region agreed';
end;

end.
