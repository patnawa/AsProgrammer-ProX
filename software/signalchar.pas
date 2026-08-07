unit signalchar;

// What level a programmer actually drives on CS, CLK and MOSI -- measured,
// not assumed.
//
// Everything else in this program is downstream of one sentence in
// railreport: "assumed to follow the rail, not measured". A board that
// switches VCC to 1.8 V while its logic keeps swinging to 3.3 V passes the
// rail check, passes the preflight, passes the admission ladder, and destroys
// the part. It is the one failure the electrical model cannot see, because no
// supported programmer has a sensor anywhere near those pins.
//
// The only thing that settles it is a scope on the board. So this unit is
// where such a measurement is written down, and the rest of the program reads
// its answer instead of assuming one.
//
// Three rules, and they are the whole unit:
//
//   - Absence is not verification. A programmer with no record is unverified,
//     forever, however obvious its behaviour seems. That is why the table
//     below starts empty rather than starting with a plausible guess.
//   - A rail is verified on its own. A board measured at 3.3 V has said
//     nothing about what it does at 1.8 V; those are different states of a
//     different regulator, and the dangerous one is the one nobody checked.
//   - The measured level is the level that counts. When a record exists, the
//     preflight uses the number that was measured on the pins, not the rail
//     that was requested. If those two disagree, the disagreement is the
//     finding, and SignalFollowsRail says so.
//
// The table is compiled in on purpose. This claim is the one that unlocks the
// strictest gate in the program -- production admission refuses to run
// without it -- so it has to be reviewable in source and travel with the
// binary. A text file dropped next to the exe would let an unreviewed claim
// turn that gate off.
//
// Every rule is also exported in a form that takes the table as an argument,
// so the suite can exercise all of them against synthetic records. That is
// why there is no procedure here for editing the compiled-in table: the tests
// never needed one, and a caller that could add an entry at runtime could
// verify a board by asserting it.
//
// hardware/test-procedure.md is the bench work that produces a record. It is
// about fifteen minutes with a scope and a chip socket.
//
// No hardware access and no LCL unit is used here.

{$mode objfpc}{$H+}

interface

uses
  SysUtils, electricalpreflight;

type
  TSignalLines = array of string;

  // One bench measurement: this programmer, at this rail, drives this level.
  TSignalCharacterisation = record
    Known: boolean;

    ProgrammerID: string;
    // The rail the board was commanded to when the measurement was taken.
    RailMv: cardinal;
    // The worst (highest) level seen on CS, CLK or MOSI at that rail. Highest
    // rather than typical: the number exists to be compared against the
    // chip's absolute maximum, and an average hides the excursion that kills.
    SignalMv: cardinal;

    // How it was established, in a few words, and when. Both travel into the
    // session report, because a measurement whose provenance nobody can state
    // is not usefully different from an assumption.
    Method: string;
    MeasuredOn: string;    // ISO-8601 date, UTC
    Procedure_: string;    // the revision of hardware/test-procedure.md used
  end;

  TSignalCharacterisations = array of TSignalCharacterisation;

const
  // How far the measured level may sit from the rail and still be called
  // "follows the rail". 10% covers regulator tolerance, probe loading and
  // scope accuracy; it does not come close to covering 1.8 V against 3.3 V,
  // which is the confusion that matters.
  SIGNAL_RAIL_TOLERANCE_PERCENT = 10;

  // How far a commanded rail may sit from a recorded rail and still be the
  // same rail. 150 mV separates 1800 from 3300 by an order of magnitude while
  // absorbing every regulator this program has met.
  RAIL_MATCH_TOLERANCE_MV = 150;

// --- the rules, against whatever table the caller has ---
//
// These are what the suite drives. The compiled-in table is one particular
// argument to them, not a hidden dependency inside them.

// Validation for a record before it is trusted, so a typo in the table below
// is a test failure rather than a silently permissive entry.
function ValidateSignalCharacterisation(
  const Characterisation: TSignalCharacterisation; out ErrMsg: string): boolean;

// True when the measured level tracks the rail closely enough that the parts
// on the bus see what the rail says they see.
//
// False is the finding this whole unit exists to surface: a board whose
// supply switched and whose signals did not. It is not an error in the
// measurement, it is a fact about the board, and callers must treat it as
// one -- the preflight's existing piSignalVoltageTooHigh fires on the
// measured number and stops the operation without needing to know why.
function SignalFollowsRail(const Characterisation: TSignalCharacterisation): boolean;

// Whether this exact programmer has been measured at this exact rail.
//
// RailMv is matched within a tolerance band rather than exactly: a board
// commanded to 1800 mV and measured with its regulator sitting at 1790 mV was
// measured at the 1.8 V rail, and demanding equality would discard the
// measurement over rounding. The band is deliberately narrow enough that
// 1.8 V and 3.3 V can never be confused for one another.
function LookupSignalCharacterisationIn(
  const Records: TSignalCharacterisations; const ProgrammerID: string;
  RailMv: cardinal; out Found: TSignalCharacterisation): boolean;

// The level to hand the preflight as the effective target-side signal, and
// whether that level was measured or inferred.
//
// This is the function callers want. With a record it returns the measured
// number and Verified=True; without one it returns the rail and False, which
// is exactly the behaviour the program had before this unit existed -- so
// adding it changes nothing until a measurement is actually taken.
//
// It never returns zero for a non-zero rail. Zero is railreport's documented
// "not known", and a signal level of zero would read as a measurement of a
// dead bus.
procedure ResolveSignalMvIn(const Records: TSignalCharacterisations;
  const ProgrammerID: string; RailMv: cardinal;
  out SignalMv: cardinal; out Verified: boolean);

// Everything recorded for one programmer, for a report or a log pane. Empty
// when nothing has been measured, which is the honest answer and not a gap.
function SignalCharacterisationLinesIn(
  const Records: TSignalCharacterisations;
  const ProgrammerID: string): TSignalLines;

// --- the same rules against this build's own table ---

function LookupSignalCharacterisation(const ProgrammerID: string;
  RailMv: cardinal; out Found: TSignalCharacterisation): boolean;
procedure ResolveSignalMv(const ProgrammerID: string; RailMv: cardinal;
  out SignalMv: cardinal; out Verified: boolean);
function SignalCharacterisationLines(const ProgrammerID: string): TSignalLines;

// The whole table, copied, for the suite and for a diagnostics dump.
function AllSignalCharacterisations: TSignalCharacterisations;

// --- what a hardware backend calls ---
//
// These two exist so that no backend has to decide, on its own, whether its
// signal level has been established. Three backends previously wrote
// `SignalVoltageVerified := False` and `EffectiveTargetVioMv := <the rail>`
// by hand, which meant that recording a measurement would have required
// finding and correcting three separate claims -- and that a fourth backend
// could be added without ever making one.
//
// A backend now states its rail and its identity and asks. Nothing else about
// it changes, and a measurement added to the table above reaches every one of
// them at once.

// Sets Capabilities.SignalVoltageVerified from whether this programmer has
// been measured at the rail it is currently supplying.
procedure ApplyMeasuredSignalLevel(const ProgrammerID: string; RailMv: cardinal;
  var Capabilities: TProgrammerElectricalCapabilities);

// Sets Observation.EffectiveTargetVioMv to the level the target's pins
// actually see: the measured figure where one exists, the rail otherwise.
//
// This is the field the preflight compares against the chip's absolute
// maximum, so a board measured driving 3.3 V logic on a 1.8 V rail is refused
// here by the rule that was already written -- piSignalVoltageTooHigh -- with
// no new policy anywhere.
procedure ApplyObservedSignalLevel(const ProgrammerID: string; RailMv: cardinal;
  var Observation: TElectricalObservation);

// "1.8 V" from 1800, locale-independent.
//
// Deliberately a local copy of railreport's VoltageText rather than a use
// clause. This unit sits *below* railreport -- railreport asks it what a
// board drives -- and pulling the formatter down would make that a cycle.
function RailText(Millivolts: cardinal): string;

implementation

// ---------------------------------------------------------------- the table
//
// Empty. Not "not yet filled in" -- empty is the correct and current state of
// the world, and the program says so rather than implying otherwise.
//
// No CH341, CH347 or FT232H in this project's hands has had a probe put on
// its signal pins at both rails. Until one does, every one of them is
// unverified, railreport prints "assumed to follow the rail, not measured",
// and production admission refuses. That is the design working, not a gap in
// it.
//
// To add a record, take the measurement described in
// hardware/test-procedure.md and append one entry to BuildTable:
//
//   Append(Result, 'CH347', 1800, 1810,
//          'scope on CS/CLK/MOSI, 10x probe, 100 transfers',
//          '2026-08-14', 'test-procedure.md rev 1');
//
// and tests/signalchar_tests.lpr will hold it to the rules above. Nothing
// else in the program needs to change: railreport, the preflight and the
// session report all start carrying the measured number on their own.

procedure Append(var Records: TSignalCharacterisations;
  const ProgrammerID: string; RailMv, SignalMv: cardinal;
  const Method, MeasuredOn, Procedure_: string);
var
  N: integer;
begin
  N := Length(Records);
  SetLength(Records, N + 1);
  Records[N].Known := True;
  Records[N].ProgrammerID := ProgrammerID;
  Records[N].RailMv := RailMv;
  Records[N].SignalMv := SignalMv;
  Records[N].Method := Method;
  Records[N].MeasuredOn := MeasuredOn;
  Records[N].Procedure_ := Procedure_;
end;

function BuildTable: TSignalCharacterisations;
begin
  Result := nil;

  //Nothing has been measured. Add Append(Result, ...) calls here, one per
  //bench measurement, and delete the "table is empty" assertion in
  //tests/signalchar_tests.lpr in the same commit.
end;

var
  Table: TSignalCharacterisations = nil;

function AllSignalCharacterisations: TSignalCharacterisations;
var
  i: integer;
begin
  //A copy, so a caller cannot edit the program's own claim about a board.
  Result := nil;
  SetLength(Result, Length(Table));
  for i := 0 to High(Table) do Result[i] := Table[i];
end;

function RailText(Millivolts: cardinal): string;
begin
  Result := Format('%d.%.1d V', [Millivolts div 1000,
                                 (Millivolts mod 1000) div 100]);
end;

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

function ValidateSignalCharacterisation(
  const Characterisation: TSignalCharacterisation; out ErrMsg: string): boolean;
begin
  Result := False;
  ErrMsg := '';

  if not Characterisation.Known then
  begin
    ErrMsg := 'characterisation is not marked known';
    Exit;
  end;
  if not PrintableWithin(Characterisation.ProgrammerID, 96) then
  begin
    ErrMsg := 'programmer identity is empty or not printable ASCII';
    Exit;
  end;
  //The same 500..6000 mV band the electrical model uses everywhere else. A
  //rail outside it is a typo, and a typo that widens a safety claim is the
  //worst kind.
  if (Characterisation.RailMv < 500) or (Characterisation.RailMv > 6000) then
  begin
    ErrMsg := 'recorded rail is outside 500..6000 mV';
    Exit;
  end;
  if (Characterisation.SignalMv < 500) or (Characterisation.SignalMv > 6000) then
  begin
    //Zero would be the most dangerous value to admit: it is railreport's
    //"not known", so a zeroed record would read as an unverified board while
    //claiming to be a verified one.
    ErrMsg := 'measured signal level is outside 500..6000 mV';
    Exit;
  end;
  if not PrintableWithin(Characterisation.Method, 160) then
  begin
    ErrMsg := 'measurement method must say how the number was obtained';
    Exit;
  end;
  if not PrintableWithin(Characterisation.MeasuredOn, 32) then
  begin
    ErrMsg := 'measurement date is missing';
    Exit;
  end;
  if not PrintableWithin(Characterisation.Procedure_, 96) then
  begin
    ErrMsg := 'the procedure that produced the measurement is not named';
    Exit;
  end;
  Result := True;
end;

function SignalFollowsRail(const Characterisation: TSignalCharacterisation): boolean;
var
  Allowed, Delta: QWord;
begin
  Result := False;
  if not Characterisation.Known then Exit;
  if (Characterisation.RailMv = 0) or (Characterisation.SignalMv = 0) then Exit;

  //Widened to QWord: a percentage of a cardinal computed in cardinal is one
  //careless multiply away from wrapping, and a wrapped tolerance is an
  //unbounded one.
  Allowed := (QWord(Characterisation.RailMv) *
              SIGNAL_RAIL_TOLERANCE_PERCENT) div 100;
  if Characterisation.SignalMv >= Characterisation.RailMv then
    Delta := QWord(Characterisation.SignalMv) - QWord(Characterisation.RailMv)
  else
    Delta := QWord(Characterisation.RailMv) - QWord(Characterisation.SignalMv);

  Result := Delta <= Allowed;
end;

function RailsMatch(A, B: cardinal): boolean;
begin
  if A >= B then
    Result := (QWord(A) - QWord(B)) <= RAIL_MATCH_TOLERANCE_MV
  else
    Result := (QWord(B) - QWord(A)) <= RAIL_MATCH_TOLERANCE_MV;
end;

function LookupSignalCharacterisationIn(
  const Records: TSignalCharacterisations; const ProgrammerID: string;
  RailMv: cardinal; out Found: TSignalCharacterisation): boolean;
var
  i: integer;
  ErrMsg: string;
begin
  Found := Default(TSignalCharacterisation);
  Result := False;
  if (ProgrammerID = '') or (RailMv = 0) then Exit;

  for i := 0 to High(Records) do
  begin
    if not SameText(Records[i].ProgrammerID, ProgrammerID) then Continue;
    if not RailsMatch(Records[i].RailMv, RailMv) then Continue;
    //A malformed entry is treated as no entry. Refusing to read a broken
    //record is fail-closed; reading it anyway would let a typo verify a board.
    if not ValidateSignalCharacterisation(Records[i], ErrMsg) then Continue;
    Found := Records[i];
    Exit(True);
  end;
end;

procedure ResolveSignalMvIn(const Records: TSignalCharacterisations;
  const ProgrammerID: string; RailMv: cardinal;
  out SignalMv: cardinal; out Verified: boolean);
var
  Found: TSignalCharacterisation;
begin
  //The unmeasured answer, which is what the program has always said: the
  //signals are assumed to follow the rail.
  SignalMv := RailMv;
  Verified := False;

  if LookupSignalCharacterisationIn(Records, ProgrammerID, RailMv, Found) then
  begin
    //The measured number replaces the assumption -- including, and especially,
    //when it is higher than the rail. That case is the entire point: the
    //preflight compares this figure against the chip's maximum and refuses,
    //without needing to be told that the board is the reason.
    SignalMv := Found.SignalMv;
    Verified := True;
  end;
end;

function SignalCharacterisationLinesIn(
  const Records: TSignalCharacterisations;
  const ProgrammerID: string): TSignalLines;

  procedure Add(const Line: string);
  var
    N: integer;
  begin
    N := Length(Result);
    SetLength(Result, N + 1);
    Result[N] := Line;
  end;

var
  i: integer;
  ErrMsg: string;
begin
  SetLength(Result, 0);
  if ProgrammerID = '' then Exit;

  for i := 0 to High(Records) do
  begin
    if not SameText(Records[i].ProgrammerID, ProgrammerID) then Continue;
    if not ValidateSignalCharacterisation(Records[i], ErrMsg) then Continue;

    if SignalFollowsRail(Records[i]) then
      Add(Format('%s rail: signals measured at %d mV (%s, %s)',
                 [RailText(Records[i].RailMv), Records[i].SignalMv,
                  Records[i].Method, Records[i].MeasuredOn]))
    else
      //Named as loudly as a line of text can. A board in this state looks
      //correct in every other field the program prints.
      Add(Format('%s rail: signals measured at %d mV -- THE SIGNALS DO NOT ' +
                 'FOLLOW THE RAIL (%s, %s)',
                 [RailText(Records[i].RailMv), Records[i].SignalMv,
                  Records[i].Method, Records[i].MeasuredOn]));
  end;
end;

function LookupSignalCharacterisation(const ProgrammerID: string;
  RailMv: cardinal; out Found: TSignalCharacterisation): boolean;
begin
  Result := LookupSignalCharacterisationIn(Table, ProgrammerID, RailMv, Found);
end;

procedure ResolveSignalMv(const ProgrammerID: string; RailMv: cardinal;
  out SignalMv: cardinal; out Verified: boolean);
begin
  ResolveSignalMvIn(Table, ProgrammerID, RailMv, SignalMv, Verified);
end;

function SignalCharacterisationLines(const ProgrammerID: string): TSignalLines;
begin
  Result := SignalCharacterisationLinesIn(Table, ProgrammerID);
end;

procedure ApplyMeasuredSignalLevel(const ProgrammerID: string; RailMv: cardinal;
  var Capabilities: TProgrammerElectricalCapabilities);
var
  Mv: cardinal;
  Verified: boolean;
begin
  ResolveSignalMv(ProgrammerID, RailMv, Mv, Verified);
  Capabilities.SignalVoltageVerified := Verified;
end;

procedure ApplyObservedSignalLevel(const ProgrammerID: string; RailMv: cardinal;
  var Observation: TElectricalObservation);
var
  Mv: cardinal;
  Verified: boolean;
begin
  ResolveSignalMv(ProgrammerID, RailMv, Mv, Verified);
  Observation.EffectiveTargetVioMv := Mv;
end;

initialization
  Table := BuildTable;

end.
