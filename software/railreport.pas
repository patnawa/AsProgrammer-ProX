unit railreport;

// The four facts about the target rail that an operator and a machine both
// need before the bus is allowed to move:
//
//   Requested voltage:         1.8 V
//   Measured voltage:          not measurable on this programmer
//   Target current:            not measurable on this programmer
//   External voltage detected: unknown
//
// "not measurable" and "unknown" are answers.  They are the whole reason this
// unit exists.  Before it, the program showed the level it had *asked* for and
// nothing else, which reads as confirmation: the operator sees "1.8 V", and
// there is no way to tell that from a board that measured 1.79 V and agreed.
// A CH347 with a stuck GPIO, a clip on the wrong pad, or a rail loaded down by
// a motherboard all display exactly the same "1.8 V".
//
// So the report separates what was commanded from what was observed, and says
// plainly when nothing was observed.  No CH341, CH347 or FT232H has an ADC on
// the target rail, a sense resistor, or backfeed detection, so today the
// honest answer for all three is "this programmer cannot tell you".  When a
// board with sensing arrives it fills the observation and every caller here
// starts reporting real numbers without changing.
//
// No hardware access and no LCL unit is used here.

{$mode objfpc}{$H+}

interface

uses
  SysUtils, electricalpreflight;

type
  // Declared here rather than taken from SysUtils/Types: this unit is linked
  // into small test programs that must not depend on which RTL alias for
  // "array of string" a given FPC release happens to export.
  TRailLines = array of string;

  // Three-valued on purpose.  A boolean cannot distinguish "no external
  // voltage is present" from "this hardware cannot see external voltage",
  // and collapsing those two is exactly the mistake that gets a chip written
  // while a motherboard is backfeeding its rail.
  TRailFinding = (
    rfUnsupported,   // the hardware has no way to know
    rfUnknown,       // it can know, but did not observe this time
    rfNo,
    rfYes
  );

  TRailReport = record
    ProgrammerKnown: boolean;
    ProgrammerID: string;

    // What software asked the hardware for.
    RequestedKnown: boolean;
    RequestedMv: cardinal;

    // What the hardware reported back from a sensor.
    MeasuredSupported: boolean;
    MeasuredKnown: boolean;
    MeasuredMv: cardinal;

    CurrentSupported: boolean;
    CurrentKnown: boolean;
    CurrentUa: cardinal;

    CurrentLimit: TRailFinding;
    CurrentLimitUa: cardinal;

    ExternalPower: TRailFinding;

    // The level the target's CS/CLK/MOSI pins actually see.  Distinct from
    // the supply on purpose: a board that switches VCC to 1.8 V but keeps
    // driving 3.3 V logic has a correct-looking supply and a dead chip.
    SignalKnown: boolean;
    SignalMv: cardinal;
    // False when the figure above is an inference from how the board is
    // wired rather than a measurement taken on the pins.  Reported, never
    // hidden: an assumed signal level is the single most expensive thing in
    // this record to get wrong.
    SignalVerified: boolean;
  end;

// Builds the report from what the backend was able to say.  ObservationValid
// is the backend's own answer to "did I manage to observe anything at all";
// False collapses every observed field to unknown rather than to zero, which
// would read as a measured 0 mV.
function BuildRailReport(
  const Capabilities: TProgrammerElectricalCapabilities;
  const Observation: TElectricalObservation;
  CapabilitiesValid, ObservationValid: boolean): TRailReport;

// The report as the lines shown above, in that order, ready for a log pane or
// a CLI.  One formatter so the GUI and the CLI cannot drift apart.
function RailReportLines(const Report: TRailReport): TRailLines;

type
  TBenchVerdict = record
    // False means no CS and no CLK.  The caller must not start the bus.
    Allowed: boolean;
    Blocking: TPreflightIssues;
    Advisory: TPreflightIssues;
    MaxSafeBusHz: cardinal;
  end;

// The gate the GUI, the CLI and any future API all pass through before the
// bus moves, so that "do not write when the rail is wrong" is one rule in one
// place rather than three that drift.
//
// It runs the same EvaluateElectricalPreflight as authenticated production,
// under the bench policy, and then sorts the issues by
// IsAdvisoryForInteractiveUse.  Advisory issues are printed and the operation
// continues; a single blocking issue stops it.
function EvaluateBenchPreflight(
  const Programmer: TProgrammerElectricalCapabilities;
  const Adapter: TAdapterElectricalCapabilities;
  const Target: TTargetElectricalRequirements;
  const Observation: TElectricalObservation;
  Destructive: boolean): TBenchVerdict;

// The verdict as lines to print, blocking issues first.  Empty when the
// verdict is allowed with nothing to say.
function BenchVerdictLines(const Verdict: TBenchVerdict): TRailLines;

// Millivolts as "1.8 V", locale-independent.  DecimalSeparator turns 1.8 into
// "1,8" in half of Europe, and a voltage that renders differently per machine
// is not something an operator can compare against a datasheet.
function VoltageText(Millivolts: cardinal): string;
function CurrentText(Microamps: cardinal): string;
function RailFindingText(Finding: TRailFinding): string;

implementation

const
  NOT_MEASURABLE = 'not measurable on this programmer';

function VoltageText(Millivolts: cardinal): string;
begin
  Result := Format('%d.%.2d V', [Millivolts div 1000,
                                 (Millivolts mod 1000) div 10]);
  //Trailing hundredths only earn their place when they say something: 1.80 V
  //is noise, 1.79 V is the entire point of measuring.  The digit sits two
  //characters before the end, ahead of the space and the 'V'.
  if Copy(Result, Length(Result) - 2, 1) = '0' then
    Delete(Result, Length(Result) - 2, 1);
end;

function CurrentText(Microamps: cardinal): string;
begin
  if Microamps < 1000 then
    Result := Format('%d uA', [Microamps])
  else
    Result := Format('%d.%.1d mA', [Microamps div 1000,
                                    (Microamps mod 1000) div 100]);
end;

function RailFindingText(Finding: TRailFinding): string;
begin
  case Finding of
    rfUnsupported: Result := NOT_MEASURABLE;
    rfUnknown:     Result := 'unknown';
    rfNo:          Result := 'No';
    rfYes:         Result := 'Yes';
  end;
end;

function BuildRailReport(
  const Capabilities: TProgrammerElectricalCapabilities;
  const Observation: TElectricalObservation;
  CapabilitiesValid, ObservationValid: boolean): TRailReport;
var
  Caps: boolean;
begin
  //Default rather than FillChar: the record holds a string, and zeroing its
  //bytes behind the reference counter's back is how a managed field ends up
  //pointing at freed memory.
  Result := Default(TRailReport);

  Caps := CapabilitiesValid and Capabilities.Known;
  Result.ProgrammerKnown := Caps;
  if Caps then Result.ProgrammerID := Capabilities.ProgrammerID;

  Result.MeasuredSupported := Caps and Capabilities.CanMeasureTargetVoltage;
  Result.CurrentSupported := Caps and Capabilities.CanMeasureTargetCurrent;

  if not ObservationValid then
  begin
    //Nothing was observed.  Every observed field stays unknown; none of them
    //is allowed to fall back to a zero that reads like a reading.  What the
    //hardware *could* do in principle is still worth saying, so a board with
    //no ADC reads "not measurable" rather than the vaguer "unknown".
    if Caps and Capabilities.CanDetectExternalPower then
      Result.ExternalPower := rfUnknown
    else
      Result.ExternalPower := rfUnsupported;
    if Caps and Capabilities.HasCurrentLimit then
      Result.CurrentLimit := rfUnknown
    else
      Result.CurrentLimit := rfUnsupported;
    Exit;
  end;

  //The rail the program commanded.  Zero is this record's documented "not
  //known", not a request for 0 mV.
  Result.RequestedKnown := Observation.SelectedTargetMv > 0;
  Result.RequestedMv := Observation.SelectedTargetMv;

  Result.MeasuredKnown := Result.MeasuredSupported and
                          Observation.TargetVoltageMeasured;
  if Result.MeasuredKnown then Result.MeasuredMv := Observation.MeasuredTargetMv;

  Result.CurrentKnown := Result.CurrentSupported and
                         Observation.TargetCurrentMeasured;
  if Result.CurrentKnown then Result.CurrentUa := Observation.MeasuredTargetUa;

  if not (Caps and Capabilities.HasCurrentLimit) then
    Result.CurrentLimit := rfUnsupported
  else if Observation.CurrentLimitEnabled then
  begin
    Result.CurrentLimit := rfYes;
    Result.CurrentLimitUa := Observation.CurrentLimitUa;
  end
  else
    Result.CurrentLimit := rfNo;

  if not (Caps and Capabilities.CanDetectExternalPower) then
    Result.ExternalPower := rfUnsupported
  else if not Observation.ExternalPowerKnown then
    Result.ExternalPower := rfUnknown
  else if Observation.ExternalPowerPresent then
    Result.ExternalPower := rfYes
  else
    Result.ExternalPower := rfNo;

  Result.SignalKnown := Observation.EffectiveTargetVioMv > 0;
  Result.SignalMv := Observation.EffectiveTargetVioMv;
  Result.SignalVerified := Caps and Capabilities.SignalVoltageVerified;
end;

function RailReportLines(const Report: TRailReport): TRailLines;

  procedure Add(const Line: string);
  var
    N: integer;
  begin
    N := Length(Result);
    SetLength(Result, N + 1);
    Result[N] := Line;
  end;

var
  Limit: string;
begin
  SetLength(Result, 0);

  if Report.RequestedKnown then
    Add('Requested voltage:         ' + VoltageText(Report.RequestedMv))
  else
    Add('Requested voltage:         not set');

  if Report.MeasuredKnown then
    Add('Measured voltage:          ' + VoltageText(Report.MeasuredMv))
  else if Report.MeasuredSupported then
    Add('Measured voltage:          unknown')
  else
    Add('Measured voltage:          ' + NOT_MEASURABLE);

  if Report.CurrentKnown then
    Add('Target current:            ' + CurrentText(Report.CurrentUa))
  else if Report.CurrentSupported then
    Add('Target current:            unknown')
  else
    Add('Target current:            ' + NOT_MEASURABLE);

  Limit := RailFindingText(Report.CurrentLimit);
  if (Report.CurrentLimit = rfYes) and (Report.CurrentLimitUa > 0) then
    Limit := Limit + ', ' + CurrentText(Report.CurrentLimitUa);
  Add('Current limit enabled:     ' + Limit);

  Add('External voltage detected: ' + RailFindingText(Report.ExternalPower));

  //Only worth a line when it is known, and then always worth one: a supply
  //that switched and signals that did not is the failure this catches.
  if Report.SignalKnown and Report.SignalVerified then
    Add('Signal (CS/CLK/MOSI):      ' + VoltageText(Report.SignalMv))
  else if Report.SignalKnown then
    Add('Signal (CS/CLK/MOSI):      ' + VoltageText(Report.SignalMv) +
        ' (assumed to follow the rail, not measured)')
  else
    Add('Signal (CS/CLK/MOSI):      unknown');
end;

function EvaluateBenchPreflight(
  const Programmer: TProgrammerElectricalCapabilities;
  const Adapter: TAdapterElectricalCapabilities;
  const Target: TTargetElectricalRequirements;
  const Observation: TElectricalObservation;
  Destructive: boolean): TBenchVerdict;
var
  Policy: TPreflightPolicy;
  Report: TPreflightReport;
  i, B, A: integer;
begin
  DefaultInteractivePreflightPolicy(Policy, Destructive);
  Report := EvaluateElectricalPreflight(Programmer, Adapter, Target,
                                        Observation, Policy);

  Result.MaxSafeBusHz := Report.MaxSafeBusHz;
  SetLength(Result.Blocking, Length(Report.Issues));
  SetLength(Result.Advisory, Length(Report.Issues));
  B := 0;
  A := 0;
  for i := 0 to High(Report.Issues) do
    if IsAdvisoryForInteractiveUse(Report.Issues[i].Code) then
    begin
      Result.Advisory[A] := Report.Issues[i];
      Inc(A);
    end
    else
    begin
      Result.Blocking[B] := Report.Issues[i];
      Inc(B);
    end;
  SetLength(Result.Blocking, B);
  SetLength(Result.Advisory, A);

  //Report.Allowed is False as soon as any issue exists, advisory ones
  //included.  Bench work turns on the blocking set alone.
  Result.Allowed := B = 0;
end;

function BenchVerdictLines(const Verdict: TBenchVerdict): TRailLines;

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
begin
  SetLength(Result, 0);
  for i := 0 to High(Verdict.Blocking) do
    Add('preflight refused: ' +
        PreflightIssueCodeName(Verdict.Blocking[i].Code) + ': ' +
        Verdict.Blocking[i].Detail);
  for i := 0 to High(Verdict.Advisory) do
    Add('preflight note: ' +
        PreflightIssueCodeName(Verdict.Advisory[i].Code) + ': ' +
        Verdict.Advisory[i].Detail);
end;

end.
