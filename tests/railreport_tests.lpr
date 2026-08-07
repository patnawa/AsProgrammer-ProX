program railreport_tests;

// What the operator is told about the rail, and what stops the bus.
//
// The assertions worth reading twice are the ones about absence: a programmer
// with no ADC must say so, and must never let "nothing was measured" render as
// a number.  A silent zero here is a chip.

{$mode objfpc}{$H+}

uses
  SysUtils, electricalpreflight, railreport;

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

function LinesContain(const Lines: TRailLines;
  const Needle: string): boolean;
var
  i: integer;
begin
  for i := 0 to High(Lines) do
    if Pos(Needle, Lines[i]) > 0 then Exit(True);
  Result := False;
end;

// A CH347 as it really is: it switches the rail and observes nothing.
procedure BlindSelectableProgrammer(
  out Caps: TProgrammerElectricalCapabilities);
var
  P: TSerialProtocol;
begin
  FillChar(Caps, SizeOf(Caps), 0);
  Caps.Known := True;
  Caps.ProgrammerID := 'CH347';
  Caps.FirmwareVersion := 'unavailable';
  Caps.SupportedProtocols := [spSPI, spI2C];
  Caps.PowerCapability := pcSelectableTargetPower;
  Caps.TargetMinMv := 1800;
  Caps.TargetMaxMv := 3300;
  Caps.CanSetVio := False;
  Caps.FixedVioMv := 1800;
  Caps.SignalVoltageVerified := False;
  for P := Low(TSerialProtocol) to High(TSerialProtocol) do
    Caps.MaxBusHz[P] := 0;
  Caps.MaxBusHz[spSPI] := 60000000;
  Caps.MaxBusHz[spI2C] := 750000;
end;

procedure BlindObservation(out Obs: TElectricalObservation; RailMv: cardinal);
begin
  FillChar(Obs, SizeOf(Obs), 0);
  Obs.TargetPowerEnabled := True;
  Obs.SelectedTargetMv := RailMv;
  Obs.SelectedProgrammerVioMv := RailMv;
  Obs.EffectiveTargetVioMv := RailMv;
  Obs.RequestedBusHz := 15000000;
end;

procedure ChipAt(out Target: TTargetElectricalRequirements;
  MinMv, MaxMv, VioMaxMv: cardinal);
begin
  FillChar(Target, SizeOf(Target), 0);
  Target.Protocol := spSPI;
  Target.VccMinMv := MinMv;
  Target.VccMaxMv := MaxMv;
  Target.VioMaxMv := VioMaxMv;
  Target.MaxBusHz := 60000000;
  Target.RequiredProgrammerID := 'any';
  Target.RequiredAdapterID := 'none';
  Target.AllowsExternalPower := False;
end;

procedure TestVoltageAndCurrentText;
begin
  //Locale must not reach these: a comma decimal separator makes a voltage
  //that cannot be compared against a datasheet.
  CheckText('1.8 V renders plainly', '1.8 V', VoltageText(1800));
  CheckText('the hundredth survives when it matters', '1.79 V',
            VoltageText(1790));
  CheckText('3.3 V renders plainly', '3.3 V', VoltageText(3300));
  CheckText('a whole volt keeps one decimal', '5.0 V', VoltageText(5000));
  CheckText('microamps stay microamps', '850 uA', CurrentText(850));
  CheckText('milliamps round to a tenth', '12.0 mA', CurrentText(12000));
  CheckText('a fractional milliamp shows', '1.5 mA', CurrentText(1500));
end;

procedure TestBlindProgrammerAdmitsIt;
var
  Caps: TProgrammerElectricalCapabilities;
  Obs: TElectricalObservation;
  Report: TRailReport;
  Lines: TRailLines;
begin
  BlindSelectableProgrammer(Caps);
  BlindObservation(Obs, 1800);
  Report := BuildRailReport(Caps, Obs, True, True);
  Lines := RailReportLines(Report);

  Check('the requested rail is known', Report.RequestedKnown);
  CheckText('and is the rail that was selected', '1.8 V',
            VoltageText(Report.RequestedMv));

  //The heart of it: asked-for and observed are different fields, and this
  //board cannot fill the second one.
  Check('measurement is not claimed', not Report.MeasuredKnown);
  Check('measurement is not even supported', not Report.MeasuredSupported);
  Check('the report says measuring is impossible here',
    LinesContain(Lines, 'Measured voltage:          not measurable'));
  Check('current is not claimed either',
    LinesContain(Lines, 'Target current:            not measurable'));
  Check('backfeed detection is not claimed',
    LinesContain(Lines, 'External voltage detected: not measurable'));
  Check('the current limit is not claimed',
    LinesContain(Lines, 'Current limit enabled:     not measurable'));

  //An unverified signal level is reported as unverified, not as a figure.
  Check('the signal level is flagged as an assumption',
    LinesContain(Lines, 'assumed to follow the rail, not measured'));

  Check('no line ever renders an unmeasured value as 0 V',
    not LinesContain(Lines, '0.0 V'));
end;

procedure TestMeasuringProgrammerReportsBothNumbers;
var
  Caps: TProgrammerElectricalCapabilities;
  Obs: TElectricalObservation;
  Report: TRailReport;
  Lines: TRailLines;
begin
  //The board this program does not have yet.  Nothing in railreport changes
  //when it arrives; only these flags do.
  BlindSelectableProgrammer(Caps);
  Caps.CanMeasureTargetVoltage := True;
  Caps.CanMeasureTargetCurrent := True;
  Caps.CanDetectExternalPower := True;
  Caps.HasCurrentLimit := True;
  Caps.SignalVoltageVerified := True;

  BlindObservation(Obs, 1800);
  Obs.TargetVoltageMeasured := True;
  Obs.MeasuredTargetMv := 1790;
  Obs.TargetCurrentMeasured := True;
  Obs.MeasuredTargetUa := 12000;
  Obs.ExternalPowerKnown := True;
  Obs.ExternalPowerPresent := False;
  Obs.CurrentLimitEnabled := True;
  Obs.CurrentLimitUa := 50000;

  Report := BuildRailReport(Caps, Obs, True, True);
  Lines := RailReportLines(Report);

  Check('requested and measured are both reported',
    LinesContain(Lines, 'Requested voltage:         1.8 V') and
    LinesContain(Lines, 'Measured voltage:          1.79 V'));
  Check('the measured draw is reported',
    LinesContain(Lines, 'Target current:            12.0 mA'));
  Check('a negative backfeed answer is a No, not an unknown',
    LinesContain(Lines, 'External voltage detected: No'));
  Check('an enabled limit reports its value',
    LinesContain(Lines, 'Current limit enabled:     Yes, 50.0 mA'));
  Check('a measured signal level carries no caveat',
    not LinesContain(Lines, 'assumed'));
end;

procedure TestBackfeedIsThreeValued;
var
  Caps: TProgrammerElectricalCapabilities;
  Obs: TElectricalObservation;
  Report: TRailReport;
begin
  //"No" and "cannot tell" are the two answers that must never merge: the
  //second one is what a motherboard backfeeding the rail looks like on
  //hardware without a comparator.
  BlindSelectableProgrammer(Caps);
  BlindObservation(Obs, 1800);
  Report := BuildRailReport(Caps, Obs, True, True);
  Check('no detector means unsupported, not No',
    Report.ExternalPower = rfUnsupported);

  Caps.CanDetectExternalPower := True;
  Obs.ExternalPowerKnown := False;
  Report := BuildRailReport(Caps, Obs, True, True);
  Check('a detector that did not report means unknown, not No',
    Report.ExternalPower = rfUnknown);

  Obs.ExternalPowerKnown := True;
  Obs.ExternalPowerPresent := False;
  Report := BuildRailReport(Caps, Obs, True, True);
  Check('a detector that reported absence means No',
    Report.ExternalPower = rfNo);

  Obs.ExternalPowerPresent := True;
  Report := BuildRailReport(Caps, Obs, True, True);
  Check('a detector that found voltage means Yes',
    Report.ExternalPower = rfYes);
end;

procedure TestNothingObservedStaysUnknown;
var
  Caps: TProgrammerElectricalCapabilities;
  Obs: TElectricalObservation;
  Report: TRailReport;
  Lines: TRailLines;
begin
  //A closed device observes nothing.  Every field must read as absent, and
  //none of them may render the zeroed record as a reading.
  BlindSelectableProgrammer(Caps);
  Caps.CanMeasureTargetVoltage := True;
  FillChar(Obs, SizeOf(Obs), 0);
  Report := BuildRailReport(Caps, Obs, True, False);
  Lines := RailReportLines(Report);

  Check('nothing was requested', not Report.RequestedKnown);
  Check('nothing was measured', not Report.MeasuredKnown);
  Check('an unobserved rail says "not set"',
    LinesContain(Lines, 'Requested voltage:         not set'));
  //Supported but not observed is "unknown", which is a different sentence
  //from "this hardware cannot".
  Check('a capable but silent sensor reads unknown',
    LinesContain(Lines, 'Measured voltage:          unknown'));
  Check('no zero volts appears anywhere', not LinesContain(Lines, '0.0 V'));
end;

procedure TestBenchGateBlocksTheDecidedFailures;
var
  Caps: TProgrammerElectricalCapabilities;
  Adapter: TAdapterElectricalCapabilities;
  Obs: TElectricalObservation;
  Target: TTargetElectricalRequirements;
  Verdict: TBenchVerdict;
begin
  BlindSelectableProgrammer(Caps);
  FillChar(Adapter, SizeOf(Adapter), 0);

  //A 1.8 V part on a 1.8 V rail: allowed, with the honest notes attached.
  BlindObservation(Obs, 1800);
  ChipAt(Target, 1700, 1950, 1980);
  Verdict := EvaluateBenchPreflight(Caps, Adapter, Target, Obs, True);
  Check('a correct rail is allowed to write', Verdict.Allowed);
  //An allowed verdict is silent on purpose: what this hardware cannot
  //measure is stated once, by the rail report, rather than repeated as a
  //preflight complaint on every operation.
  Check('an allowed verdict adds no noise',
    (Length(Verdict.Blocking) = 0) and (Length(Verdict.Advisory) = 0));

  //The same part with the rail left at 3.3 V.  This is the failure the whole
  //feature exists to stop, and no advisory downgrade may reach it.
  BlindObservation(Obs, 3300);
  Verdict := EvaluateBenchPreflight(Caps, Adapter, Target, Obs, True);
  Check('3.3 V into a 1.8 V part is refused', not Verdict.Allowed);
  Check('the refusal is reported as blocking',
    Length(Verdict.Blocking) > 0);
  Check('the operator is told which rule stopped it',
    LinesContain(BenchVerdictLines(Verdict), 'preflight refused:'));

  //Reading is not destructive, but an overvoltage rail destroys the part
  //just as thoroughly on a read as on a write.
  Verdict := EvaluateBenchPreflight(Caps, Adapter, Target, Obs, False);
  Check('a non-destructive operation is refused the same rail',
    not Verdict.Allowed);
end;

procedure TestUncharacterisedBackendWarnsRatherThanBlocks;
var
  Caps: TProgrammerElectricalCapabilities;
  Adapter: TAdapterElectricalCapabilities;
  Obs: TElectricalObservation;
  Target: TTargetElectricalRequirements;
  Verdict: TBenchVerdict;
begin
  //CH341 and FT232H report nothing yet.  Refusing every operation on them
  //would teach operators to switch the gate off, taking the decided
  //failures above down with it.
  FillChar(Caps, SizeOf(Caps), 0);
  Caps.Known := False;
  FillChar(Adapter, SizeOf(Adapter), 0);
  BlindObservation(Obs, 3300);
  ChipAt(Target, 3000, 3600, 3600);

  Verdict := EvaluateBenchPreflight(Caps, Adapter, Target, Obs, True);
  Check('an uncharacterised backend does not block bench work',
    Verdict.Allowed);
  Check('but it is reported', Length(Verdict.Advisory) > 0);
  Check('and it is named as a note, not a refusal',
    LinesContain(BenchVerdictLines(Verdict), 'preflight note:'));

  //Production keeps refusing it; that is the entire difference between the
  //two policies.
  Check('production admission is unaffected by the bench downgrade',
    not IsAdvisoryForInteractiveUse(piTargetVoltageOutOfRange));
  Check('an unmeasured voltage is advisory only for bench work',
    IsAdvisoryForInteractiveUse(piTargetVoltageNotMeasured));
end;

procedure TestSignalTooHighBlocksEvenWhenTheRailIsRight;
var
  Caps: TProgrammerElectricalCapabilities;
  Adapter: TAdapterElectricalCapabilities;
  Obs: TElectricalObservation;
  Target: TTargetElectricalRequirements;
  Verdict: TBenchVerdict;
begin
  //The failure mode the user asked about: VCC switched to 1.8 V, logic did
  //not.  The supply passes every check; the signal level is what saves the
  //part, and only if it is checked separately.
  BlindSelectableProgrammer(Caps);
  FillChar(Adapter, SizeOf(Adapter), 0);
  BlindObservation(Obs, 1800);
  Obs.EffectiveTargetVioMv := 3300;
  ChipAt(Target, 1700, 1950, 1980);

  Verdict := EvaluateBenchPreflight(Caps, Adapter, Target, Obs, True);
  Check('a correct supply with 3.3 V logic is refused', not Verdict.Allowed);
  Check('and the refusal names the signal level, not the supply',
    LinesContain(BenchVerdictLines(Verdict), 'signal_voltage_too_high'));
end;

begin
  TestVoltageAndCurrentText;
  TestBlindProgrammerAdmitsIt;
  TestMeasuringProgrammerReportsBothNumbers;
  TestBackfeedIsThreeValued;
  TestNothingObservedStaysUnknown;
  TestBenchGateBlocksTheDecidedFailures;
  TestUncharacterisedBackendWarnsRatherThanBlocks;
  TestSignalTooHighBlocksEvenWhenTheRailIsRight;
  WriteLn(Assertions, ' assertions, ', Failures, ' failures');
  if Failures <> 0 then Halt(1);
  WriteLn('ALL PASSED');
end.
