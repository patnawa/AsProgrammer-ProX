program voltagewarning_tests;

// The last warning before a 1.8 V part meets a rail that would destroy it.
//
// This rule was inside a GUI function, interleaved with three dialog calls,
// so none of it could be exercised. The cases below are the ones that were
// unreachable, and the Auto path is the one worth reading twice: on a board
// that can switch its rail, "Auto" is not a rail, and the decision has to
// tell an Auto that will resolve to 1.8 V from an Auto that cannot resolve at
// all. Getting that wrong means either nagging about a correct rail or --
// far worse -- staying silent about an incorrect one.
//
// Two invariants are asserted across every combination the record can hold:
// no verdict ever concludes that a 3.3 V rail is fine for a 1.8 V part, and
// every unresolvable rail warns rather than proceeding.

{$mode objfpc}{$H+}

uses
  SysUtils, voltagewarning;

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
  LOW_RAIL = 1800;
  HIGH_RAIL = 3300;

// A CH347-shaped context: a 1.8 V part, a board that can switch, Auto.
function Ctx: TVoltageContext;
begin
  Result := Default(TVoltageContext);
  Result.ChipVccText := '1.8';
  Result.RailSelectable := True;
  Result.SelectedRailMv := 0;         //Auto
  Result.AutoResolvesToMv := LOW_RAIL;
  Result.LowRailMv := LOW_RAIL;
end;

// ------------------------------------------------------ the simple cases

procedure TestAThreeVoltPartIsNotThisUnitsProblem;
var
  C: TVoltageContext;
begin
  WriteLn('A part that is not 1.8 V passes straight through');

  C := Ctx;
  C.ChipVccText := '3.3';
  Check('a 3.3 V part proceeds', AdviseVoltage(C) = vaProceed);

  C.ChipVccText := '2.7-3.6';
  Check('a wide-range 3 V part proceeds', AdviseVoltage(C) = vaProceed);

  //The resolver's own vocabulary, matched as a substring. Re-parsing it into
  //millivolts here would be a second parser to keep in step with the first.
  //Checked against a fixed-rail programmer, where a low-voltage part is the
  //only thing that produces a warning at all.
  C := Ctx;
  C.RailSelectable := False;
  C.ChipVccText := '1.8V';
  Check('a 1.8V spelling is recognised',
        AdviseVoltage(C) = vaWarnRailTooHigh);
  C.ChipVccText := '1.65-1.95';
  Check('but a range spelled without 1.8 is not this unit''s business',
        AdviseVoltage(C) = vaProceed);

  Check('the low-voltage test is the shared one',
        IsLowVoltagePart('1.8') and IsLowVoltagePart('1.8V') and
        (not IsLowVoltagePart('3.3')) and (not IsLowVoltagePart('')));
end;

procedure TestProductionIsNeverSecondGuessed;
var
  C: TVoltageContext;
begin
  WriteLn('Authenticated production has already decided this');

  //It passed a typed electrical gate against measured facts. A heuristic that
  //reads model names must not overrule it in either direction: it cannot
  //approve what the gate refused, and it must not interrupt what it approved.
  C := Ctx;
  C.StrictProduction := True;
  C.SelectedRailMv := HIGH_RAIL;
  Check('even the worst combination defers to the gate',
        AdviseVoltage(C) = vaProductionGateDecides);

  C.ChipVccText := '';
  Check('and so does an unresolved one',
        AdviseVoltage(C) = vaProductionGateDecides);
end;

procedure TestAnExternallyPoweredFixtureIsExempt;
var
  C: TVoltageContext;
begin
  WriteLn('A fixture that supplies its own target is not warned about');

  //Bus Pirate and Arduino present open-drain pins and the target is fed from
  //elsewhere, so the programmer's rail is not what the chip sees. Warning
  //here would be warning about a rail that is not connected.
  C := Ctx;
  C.ExternallyPowered := True;
  C.RailSelectable := False;
  C.SelectedRailMv := HIGH_RAIL;
  Check('it proceeds', AdviseVoltage(C) = vaProceed);
end;

procedure TestAFixedRailProgrammerCanOnlyWarn;
var
  C: TVoltageContext;
begin
  WriteLn('A programmer with a fixed rail states the fact and stops');

  //A CH341A or an FT232H. There is no correct action to offer, only something
  //to say before the first clock edge.
  C := Ctx;
  C.RailSelectable := False;
  C.SelectedRailMv := 0;
  C.AutoResolvesToMv := 0;
  Check('it warns', AdviseVoltage(C) = vaWarnRailTooHigh);
  Check('and the warning says what happens',
        Pos('destroys it permanently', VoltageAdviceText(vaWarnRailTooHigh)) > 0);

  //Even if some caller filled in a rail figure, a board that cannot select
  //one cannot be asked to change it.
  C.SelectedRailMv := LOW_RAIL;
  Check('a fixed rail is still fixed', AdviseVoltage(C) = vaWarnRailTooHigh);
end;

// ------------------------------------------------------ the switchable rail

procedure TestAPinnedLowRailIsCorrectAndSilent;
var
  C: TVoltageContext;
begin
  WriteLn('A rail already pinned to 1.8 V needs no warning');
  C := Ctx;
  C.SelectedRailMv := LOW_RAIL;
  Check('it proceeds', AdviseVoltage(C) = vaProceed);
end;

procedure TestAPinnedHighRailIsOfferedAFix;
var
  C: TVoltageContext;
begin
  WriteLn('A rail pinned to 3.3 V gets an offer, not a lecture');
  C := Ctx;
  C.SelectedRailMv := HIGH_RAIL;

  //An offer rather than a bare warning, because there is a correct action
  //available and the operator should not have to go and find it in a menu.
  Check('it offers to pin the low rail',
        AdviseVoltage(C) = vaOfferPinLowRail);
  Check('and says the board can switch',
        Pos('can switch it', VoltageAdviceText(vaOfferPinLowRail)) > 0);
end;

procedure TestAutoThatResolvesCorrectlyIsSilent;
var
  C: TVoltageContext;
begin
  WriteLn('Auto that will resolve to 1.8 V is already right');
  C := Ctx;
  C.SelectedRailMv := 0;
  C.AutoResolvesToMv := LOW_RAIL;

  //Warning here would be nagging about a rail that is about to be correct,
  //which is how operators learn to click through warnings.
  Check('it proceeds', AdviseVoltage(C) = vaProceed);
end;

procedure TestAutoThatCannotResolveWarns;
var
  C: TVoltageContext;
begin
  WriteLn('Auto that cannot resolve is not Auto that happens to be right');

  //This is the case the extraction was worth doing for. Zero means the
  //catalogue gave no range to work from, so nobody knows what the board will
  //supply -- and a rail nobody could work out is not a rail that is correct.
  C := Ctx;
  C.SelectedRailMv := 0;
  C.AutoResolvesToMv := 0;
  Check('it offers to pin the low rail rather than proceeding',
        AdviseVoltage(C) = vaOfferPinLowRail);

  //And an Auto that resolves upward is the same answer for the same reason.
  C.AutoResolvesToMv := HIGH_RAIL;
  Check('so does an Auto that resolves to 3.3 V',
        AdviseVoltage(C) = vaOfferPinLowRail);
end;

// ------------------------------------- the two invariants, over everything

procedure TestNoCombinationEverApprovesAHighRailForALowPart;
var
  C: TVoltageContext;
  Selected, Auto: integer;
  Strict_, External_, Selectable: boolean;
  Advice: TVoltageAdvice;
  Rails: array[0..2] of cardinal = (0, LOW_RAIL, HIGH_RAIL);
begin
  WriteLn('Across every combination, a high rail is never approved');

  //Exhaustive over the record's meaningful states. The two invariants below
  //are the whole safety argument of this unit, and asserting them case by
  //case would leave exactly the combination nobody thought of.
  for Strict_ := False to True do
    for External_ := False to True do
      for Selectable := False to True do
        for Selected := 0 to 2 do
          for Auto := 0 to 2 do
          begin
            C := Default(TVoltageContext);
            C.ChipVccText := '1.8';
            C.StrictProduction := Strict_;
            C.ExternallyPowered := External_;
            C.RailSelectable := Selectable;
            C.SelectedRailMv := Rails[Selected];
            C.AutoResolvesToMv := Rails[Auto];
            C.LowRailMv := LOW_RAIL;

            Advice := AdviseVoltage(C);

            //Invariant one: this unit never *approves* 3.3 V into a 1.8 V
            //part on its own account. It may proceed only when production
            //already decided, when the rail is not connected to the chip, or
            //when the rail in use is the low one.
            if Advice = vaProceed then
              Check('proceeding is justified: strict=' + BoolToStr(Strict_, True) +
                    ' external=' + BoolToStr(External_, True) +
                    ' selectable=' + BoolToStr(Selectable, True) +
                    ' selected=' + IntToStr(Rails[Selected]) +
                    ' auto=' + IntToStr(Rails[Auto]),
                    External_ or
                    (Selectable and (Rails[Selected] = LOW_RAIL)) or
                    (Selectable and (Rails[Selected] = 0) and
                     (Rails[Auto] = LOW_RAIL)));

            //Invariant two: a board that cannot switch never gets an offer to
            //switch, because there is nothing behind that button.
            if Advice = vaOfferPinLowRail then
              Check('an offer to switch implies a board that can',
                    Selectable and (not External_) and (not Strict_));
          end;
end;

procedure TestEveryAdviceIsNamed;
var
  A: TVoltageAdvice;
begin
  WriteLn('Every verdict has a name and, unless silent, a sentence');
  for A := Low(TVoltageAdvice) to High(TVoltageAdvice) do
  begin
    Check('advice ' + IntToStr(Ord(A)) + ' is named',
          VoltageAdviceName(A) <> '');
    if A <> vaProceed then
      Check('advice ' + IntToStr(Ord(A)) + ' explains itself',
            Length(VoltageAdviceText(A)) > 20);
  end;
  //Nothing to say when there is nothing to say.
  Check('proceeding says nothing', VoltageAdviceText(vaProceed) = '');
end;

begin
  TestAThreeVoltPartIsNotThisUnitsProblem;
  TestProductionIsNeverSecondGuessed;
  TestAnExternallyPoweredFixtureIsExempt;
  TestAFixedRailProgrammerCanOnlyWarn;
  TestAPinnedLowRailIsCorrectAndSilent;
  TestAPinnedHighRailIsOfferedAFix;
  TestAutoThatResolvesCorrectlyIsSilent;
  TestAutoThatCannotResolveWarns;
  TestNoCombinationEverApprovesAHighRailForALowPart;
  TestEveryAdviceIsNamed;
  WriteLn(Assertions, ' assertions, ', Failures, ' failures');
  if Failures <> 0 then Halt(1);
  WriteLn('ALL PASSED');
end.
