unit electricalpreflight;

// Typed, fail-closed electrical preflight for production operations.
//
// This unit describes facts.  It does not guess a programmer's voltage from
// its model name, and it never displays a confirmation dialog.  The hardware
// backend supplies capabilities and observations, the signed job supplies the
// target requirements, and EvaluateElectricalPreflight returns typed issues.
//
// No hardware access or LCL unit is used here, so the policy can be exercised
// exhaustively with an in-memory test fixture.

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

type
  TSerialProtocol = (spSPI, spI2C, spMicrowire);
  TSerialProtocols = set of TSerialProtocol;

  TPowerCapability = (
    pcNoTargetPower,
    pcFixedTargetPower,
    pcSelectableTargetPower
  );

  TProgrammerElectricalCapabilities = record
    Known: boolean;
    ProgrammerID: string;
    FirmwareVersion: string;
    SupportedProtocols: TSerialProtocols;

    // True only when opening/resetting the backend leaves every target-facing
    // pin high impedance until the operation engine explicitly configures it.
    PinsSafeAtOpen: boolean;
    SupportsOpenDrain: boolean;

    PowerCapability: TPowerCapability;
    FixedTargetMv: cardinal;
    TargetMinMv: cardinal;
    TargetMaxMv: cardinal;

    CanSetVio: boolean;
    FixedVioMv: cardinal;
    VioMinMv: cardinal;
    VioMaxMv: cardinal;

    CanDetectExternalPower: boolean;
    CanMeasureTargetVoltage: boolean;
    CanMeasureTargetCurrent: boolean;
    HasCurrentLimit: boolean;

    MaxBusHz: array[TSerialProtocol] of cardinal;
  end;

  TAdapterElectricalCapabilities = record
    Present: boolean;
    IdentityVerified: boolean;
    AdapterID: string;
    SupportedProtocols: TSerialProtocols;

    TargetMinMv: cardinal;
    TargetMaxMv: cardinal;
    MaxProgrammerSideVioMv: cardinal;
    MaxBusHz: array[TSerialProtocol] of cardinal;

    LevelShiftsSignals: boolean;
    ProvidesOpenDrain: boolean;
    IsolatesTargetPower: boolean;
    CalibrationValid: boolean;
  end;

  TTargetElectricalRequirements = record
    Protocol: TSerialProtocol;
    VccMinMv: cardinal;
    VccMaxMv: cardinal;
    VioMaxMv: cardinal;
    MaxBusHz: cardinal;

    RequiredProgrammerID: string; // exact ID, or "any"
    RequiredAdapterID: string;    // exact ID, "any", or "none"
    RequiresOpenDrain: boolean;
    AllowsExternalPower: boolean;
  end;

  TElectricalObservation = record
    TargetPowerEnabled: boolean;
    SelectedTargetMv: cardinal;
    SelectedProgrammerVioMv: cardinal;
    EffectiveTargetVioMv: cardinal;
    RequestedBusHz: cardinal;

    ExternalPowerKnown: boolean;
    ExternalPowerPresent: boolean;
    // Must reflect a fixture/supply hardware limit, not a software estimate.
    ExternalPowerCurrentLimited: boolean;
    TargetVoltageMeasured: boolean;
    MeasuredTargetMv: cardinal;
    CurrentLimitEnabled: boolean;
  end;

  TPreflightPolicy = record
    DestructiveOperation: boolean;
    RequireSafePinsAtOpen: boolean;
    RequireVerifiedAdapterIdentity: boolean;
    RequireVoltageMeasurementForDestructive: boolean;
    RequireCurrentLimitForDestructive: boolean;
    RequireExternalPowerDetection: boolean;
    RequireValidAdapterCalibration: boolean;
  end;

  TPreflightIssueCode = (
    piProgrammerCapabilitiesUnknown,
    piProgrammerIdentityMismatch,
    piProtocolUnsupportedByProgrammer,
    piPinsNotSafeAtOpen,
    piAdapterRequired,
    piUnexpectedAdapter,
    piAdapterCapabilitiesInvalid,
    piAdapterIdentityUnverified,
    piAdapterIdentityMismatch,
    piProtocolUnsupportedByAdapter,
    piAdapterCalibrationInvalid,
    piExternalPowerStateUnknown,
    piExternalPowerForbidden,
    piPowerSourceContention,
    piTargetPowerUnavailable,
    piTargetVoltageUnselectable,
    piTargetVoltageUnknown,
    piTargetVoltageOutOfRange,
    piTargetVoltageNotMeasured,
    piSignalVoltageUnknown,
    piSignalVoltageTooHigh,
    piAdapterInputVoltageTooHigh,
    piOpenDrainUnavailable,
    piExternalPowerCurrentLimitUnavailable,
    piCurrentLimitUnavailable,
    piCurrentLimitNotEnabled,
    piBusFrequencyUnknown,
    piBusFrequencyTooHigh
  );

  TPreflightIssue = record
    Code: TPreflightIssueCode;
    Detail: string;
  end;

  TPreflightIssues = array of TPreflightIssue;

  TPreflightReport = record
    Allowed: boolean;
    MaxSafeBusHz: cardinal;
    Issues: TPreflightIssues;
  end;

procedure DefaultProductionPreflightPolicy(out Policy: TPreflightPolicy);

function ValidateProgrammerCapabilities(
  const Capabilities: TProgrammerElectricalCapabilities;
  out ErrMsg: string): boolean;
function ValidateAdapterCapabilities(
  const Capabilities: TAdapterElectricalCapabilities;
  out ErrMsg: string): boolean;
function ValidateTargetRequirements(
  const Requirements: TTargetElectricalRequirements;
  out ErrMsg: string): boolean;

function EvaluateElectricalPreflight(
  const Programmer: TProgrammerElectricalCapabilities;
  const Adapter: TAdapterElectricalCapabilities;
  const Target: TTargetElectricalRequirements;
  const Observation: TElectricalObservation;
  const Policy: TPreflightPolicy): TPreflightReport;

function PreflightIssueCodeName(Code: TPreflightIssueCode): string;
function ProtocolName(Protocol_: TSerialProtocol): string;

implementation

procedure DefaultProductionPreflightPolicy(out Policy: TPreflightPolicy);
begin
  Policy.DestructiveOperation := True;
  Policy.RequireSafePinsAtOpen := True;
  Policy.RequireVerifiedAdapterIdentity := True;
  Policy.RequireVoltageMeasurementForDestructive := True;
  Policy.RequireCurrentLimitForDestructive := True;
  Policy.RequireExternalPowerDetection := True;
  Policy.RequireValidAdapterCalibration := True;
end;

function ValidIdentity(const Value: string; AllowSpecial: boolean): boolean;
var
  i: integer;
begin
  Result := False;
  if (Length(Value) < 1) or (Length(Value) > 96) then Exit;
  if AllowSpecial and ((Value = 'any') or (Value = 'none')) then Exit(True);
  // Charset must stay identical to prodjob.ValidIdentifier: an identifier
  // that authenticates in a manifest must never fail here as a misleading
  // electrical issue.
  for i := 1 to Length(Value) do
    if not (Value[i] in
      ['A'..'Z', 'a'..'z', '0'..'9', '.', '_', '-', '+']) then
      Exit;
  Result := True;
end;

function ValidVoltageRange(MinMv, MaxMv: cardinal): boolean;
begin
  Result := (MinMv >= 500) and (MaxMv <= 6000) and (MinMv <= MaxMv);
end;

function ValidateProgrammerCapabilities(
  const Capabilities: TProgrammerElectricalCapabilities;
  out ErrMsg: string): boolean;
var
  P: TSerialProtocol;
begin
  Result := False;
  ErrMsg := '';
  if not Capabilities.Known then
  begin
    ErrMsg := 'programmer capabilities are not known';
    Exit;
  end;
  if not ValidIdentity(Capabilities.ProgrammerID, False) then
  begin
    ErrMsg := 'programmer identity is empty or contains unsupported characters';
    Exit;
  end;
  if not ValidIdentity(Capabilities.FirmwareVersion, False) then
  begin
    ErrMsg := 'programmer firmware version is empty or invalid';
    Exit;
  end;
  if Capabilities.SupportedProtocols = [] then
  begin
    ErrMsg := 'programmer supports no serial-memory protocol';
    Exit;
  end;

  case Capabilities.PowerCapability of
    pcFixedTargetPower:
      if (Capabilities.FixedTargetMv < 500) or
         (Capabilities.FixedTargetMv > 6000) then
      begin
        ErrMsg := 'fixed target voltage is outside the supported safety range';
        Exit;
      end;
    pcSelectableTargetPower:
      if not ValidVoltageRange(Capabilities.TargetMinMv,
                               Capabilities.TargetMaxMv) then
      begin
        ErrMsg := 'selectable target voltage range is invalid';
        Exit;
      end;
  end;

  if Capabilities.CanSetVio then
  begin
    if not ValidVoltageRange(Capabilities.VioMinMv,
                             Capabilities.VioMaxMv) then
    begin
      ErrMsg := 'selectable signal-voltage range is invalid';
      Exit;
    end;
  end
  else if (Capabilities.FixedVioMv < 500) or
          (Capabilities.FixedVioMv > 6000) then
  begin
    ErrMsg := 'fixed signal voltage is outside the supported safety range';
    Exit;
  end;

  for P := Low(TSerialProtocol) to High(TSerialProtocol) do
    if (P in Capabilities.SupportedProtocols) and
       (Capabilities.MaxBusHz[P] = 0) then
    begin
      ErrMsg := ProtocolName(P) + ' maximum clock is unknown';
      Exit;
    end;
  Result := True;
end;

function ValidateAdapterCapabilities(
  const Capabilities: TAdapterElectricalCapabilities;
  out ErrMsg: string): boolean;
var
  P: TSerialProtocol;
begin
  Result := False;
  ErrMsg := '';
  if not Capabilities.Present then
  begin
    Result := True;
    Exit;
  end;
  if not ValidIdentity(Capabilities.AdapterID, False) then
  begin
    ErrMsg := 'adapter identity is empty or contains unsupported characters';
    Exit;
  end;
  if Capabilities.SupportedProtocols = [] then
  begin
    ErrMsg := 'adapter supports no serial-memory protocol';
    Exit;
  end;
  if not ValidVoltageRange(Capabilities.TargetMinMv,
                           Capabilities.TargetMaxMv) then
  begin
    ErrMsg := 'adapter target-voltage range is invalid';
    Exit;
  end;
  if (Capabilities.MaxProgrammerSideVioMv < 500) or
     (Capabilities.MaxProgrammerSideVioMv > 6000) then
  begin
    ErrMsg := 'adapter input signal-voltage limit is invalid';
    Exit;
  end;
  for P := Low(TSerialProtocol) to High(TSerialProtocol) do
    if (P in Capabilities.SupportedProtocols) and
       (Capabilities.MaxBusHz[P] = 0) then
    begin
      ErrMsg := ProtocolName(P) + ' adapter maximum clock is unknown';
      Exit;
    end;
  Result := True;
end;

function ValidateTargetRequirements(
  const Requirements: TTargetElectricalRequirements;
  out ErrMsg: string): boolean;
begin
  Result := False;
  ErrMsg := '';
  if not ValidVoltageRange(Requirements.VccMinMv,
                           Requirements.VccMaxMv) then
  begin
    ErrMsg := 'target supply-voltage range is invalid';
    Exit;
  end;
  if (Requirements.VioMaxMv < 500) or
     (Requirements.VioMaxMv > 6000) then
  begin
    ErrMsg := 'target maximum signal voltage is invalid';
    Exit;
  end;
  if Requirements.MaxBusHz = 0 then
  begin
    ErrMsg := 'target maximum bus clock is unknown';
    Exit;
  end;
  if not ValidIdentity(Requirements.RequiredProgrammerID, True) then
  begin
    ErrMsg := 'required programmer identity is invalid';
    Exit;
  end;
  if Requirements.RequiredProgrammerID = 'none' then
  begin
    ErrMsg := '"none" is not a valid required programmer identity';
    Exit;
  end;
  if not ValidIdentity(Requirements.RequiredAdapterID, True) then
  begin
    ErrMsg := 'required adapter identity is invalid';
    Exit;
  end;
  Result := True;
end;

procedure AddIssue(var Report: TPreflightReport; Code: TPreflightIssueCode;
  const Detail: string);
var
  N: integer;
begin
  N := Length(Report.Issues);
  SetLength(Report.Issues, N + 1);
  Report.Issues[N].Code := Code;
  Report.Issues[N].Detail := Detail;
  Report.Allowed := False;
end;

function LowerNonZero(A, B: cardinal): cardinal;
begin
  if A = 0 then Exit(B);
  if B = 0 then Exit(A);
  if A < B then Result := A else Result := B;
end;

function InRange(Value, MinValue, MaxValue: cardinal): boolean;
begin
  Result := (Value >= MinValue) and (Value <= MaxValue);
end;

function EvaluateElectricalPreflight(
  const Programmer: TProgrammerElectricalCapabilities;
  const Adapter: TAdapterElectricalCapabilities;
  const Target: TTargetElectricalRequirements;
  const Observation: TElectricalObservation;
  const Policy: TPreflightPolicy): TPreflightReport;
var
  ErrMsg: string;
  SupplyMv, ProgrammerVio: cardinal;
  SupplyKnown: boolean;
  NeedAdapter, OpenDrainAvailable: boolean;
begin
  Result.Allowed := True;
  Result.MaxSafeBusHz := 0;
  SetLength(Result.Issues, 0);

  if not ValidateTargetRequirements(Target, ErrMsg) then
  begin
    AddIssue(Result, piTargetVoltageUnknown, ErrMsg);
    Exit;
  end;

  if not ValidateProgrammerCapabilities(Programmer, ErrMsg) then
  begin
    AddIssue(Result, piProgrammerCapabilitiesUnknown, ErrMsg);
    Exit;
  end;

  if (Target.RequiredProgrammerID <> 'any') and
     (Target.RequiredProgrammerID <> Programmer.ProgrammerID) then
    AddIssue(Result, piProgrammerIdentityMismatch,
      Format('job requires programmer %s, connected programmer is %s',
             [Target.RequiredProgrammerID, Programmer.ProgrammerID]));

  if not (Target.Protocol in Programmer.SupportedProtocols) then
    AddIssue(Result, piProtocolUnsupportedByProgrammer,
      'programmer does not support ' + ProtocolName(Target.Protocol));

  if Policy.RequireSafePinsAtOpen and (not Programmer.PinsSafeAtOpen) then
    AddIssue(Result, piPinsNotSafeAtOpen,
      'programmer does not guarantee high-impedance target pins at open/reset');

  NeedAdapter := Target.RequiredAdapterID <> 'none';
  if NeedAdapter and (not Adapter.Present) then
    AddIssue(Result, piAdapterRequired, 'the production job requires an adapter');

  if Adapter.Present then
  begin
    if not ValidateAdapterCapabilities(Adapter, ErrMsg) then
    begin
      AddIssue(Result, piAdapterCapabilitiesInvalid, ErrMsg);
      Exit;
    end;

    if Target.RequiredAdapterID = 'none' then
      AddIssue(Result, piUnexpectedAdapter,
        'the production job approves direct connection, but an adapter is present');

    if Policy.RequireVerifiedAdapterIdentity and
       (not Adapter.IdentityVerified) then
      AddIssue(Result, piAdapterIdentityUnverified,
        'adapter identity has not been authenticated by the fixture');

    if (Target.RequiredAdapterID <> 'any') and
       (Target.RequiredAdapterID <> 'none') and
       (Target.RequiredAdapterID <> Adapter.AdapterID) then
      AddIssue(Result, piAdapterIdentityMismatch,
        Format('job requires adapter %s, connected adapter is %s',
               [Target.RequiredAdapterID, Adapter.AdapterID]));

    if not (Target.Protocol in Adapter.SupportedProtocols) then
      AddIssue(Result, piProtocolUnsupportedByAdapter,
        'adapter does not support ' + ProtocolName(Target.Protocol));

    if Policy.RequireValidAdapterCalibration and
       (not Adapter.CalibrationValid) then
      AddIssue(Result, piAdapterCalibrationInvalid,
        'adapter calibration is absent or expired');
  end
  else if Target.RequiredAdapterID = 'none' then
  begin
    // This is the explicitly approved direct-connection case.
  end;

  if Policy.RequireExternalPowerDetection and
     ((not Programmer.CanDetectExternalPower) or
      (not Observation.ExternalPowerKnown)) then
    AddIssue(Result, piExternalPowerStateUnknown,
      'external target power was not positively measured');

  if Observation.ExternalPowerPresent then
  begin
    if not Target.AllowsExternalPower then
      AddIssue(Result, piExternalPowerForbidden,
        'the job forbids an externally powered target');
    if Observation.TargetPowerEnabled then
      AddIssue(Result, piPowerSourceContention,
        'programmer target power and external target power are both present');
    if Adapter.Present and (not Adapter.IsolatesTargetPower) then
      AddIssue(Result, piPowerSourceContention,
        'adapter does not isolate programmer power from the powered target');
  end;

  SupplyMv := 0;
  SupplyKnown := False;
  if Observation.ExternalPowerPresent then
  begin
    if Observation.TargetVoltageMeasured then
    begin
      // A positively measured 0 mV is knowledge, not absence of knowledge:
      // it must reach the range checks below and fail them, never slide
      // past a "> 0" guard.
      SupplyMv := Observation.MeasuredTargetMv;
      SupplyKnown := True;
    end
    else
      AddIssue(Result, piTargetVoltageUnknown,
        'external target voltage was detected but not measured');
  end
  else if Observation.TargetPowerEnabled then
  begin
    case Programmer.PowerCapability of
      pcNoTargetPower:
        AddIssue(Result, piTargetPowerUnavailable,
          'programmer has no controllable target-power output');
      pcFixedTargetPower:
        begin
          SupplyMv := Programmer.FixedTargetMv;
          SupplyKnown := True;
          if (Observation.SelectedTargetMv <> 0) and
             (Observation.SelectedTargetMv <> SupplyMv) then
            AddIssue(Result, piTargetVoltageUnselectable,
              'requested target voltage differs from fixed programmer output');
        end;
      pcSelectableTargetPower:
        begin
          SupplyMv := Observation.SelectedTargetMv;
          SupplyKnown := True;
          if not InRange(SupplyMv, Programmer.TargetMinMv,
                         Programmer.TargetMaxMv) then
            AddIssue(Result, piTargetVoltageUnselectable,
              'selected target voltage is outside programmer capability');
        end;
    end;
  end
  else
    AddIssue(Result, piTargetPowerUnavailable,
      'neither controlled target power nor external target power is present');

  if SupplyKnown and
     (not InRange(SupplyMv, Target.VccMinMv, Target.VccMaxMv)) then
    AddIssue(Result, piTargetVoltageOutOfRange,
      Format('target supply is %d mV; job allows %d..%d mV',
             [SupplyMv, Target.VccMinMv, Target.VccMaxMv]));

  if Adapter.Present and SupplyKnown and
     (not InRange(SupplyMv, Adapter.TargetMinMv, Adapter.TargetMaxMv)) then
    AddIssue(Result, piTargetVoltageOutOfRange,
      Format('target supply is %d mV; adapter allows %d..%d mV',
             [SupplyMv, Adapter.TargetMinMv, Adapter.TargetMaxMv]));

  if Policy.DestructiveOperation and
     Policy.RequireVoltageMeasurementForDestructive then
  begin
    if (not Programmer.CanMeasureTargetVoltage) or
       (not Observation.TargetVoltageMeasured) then
      AddIssue(Result, piTargetVoltageNotMeasured,
        'destructive operation requires a measured target voltage')
    else if not InRange(Observation.MeasuredTargetMv,
                        Target.VccMinMv, Target.VccMaxMv) then
      AddIssue(Result, piTargetVoltageOutOfRange,
        Format('measured target voltage is %d mV; job allows %d..%d mV',
               [Observation.MeasuredTargetMv,
                Target.VccMinMv, Target.VccMaxMv]));
  end;

  ProgrammerVio := 0;
  if Programmer.CanSetVio then
  begin
    ProgrammerVio := Observation.SelectedProgrammerVioMv;
    if not InRange(ProgrammerVio, Programmer.VioMinMv,
                   Programmer.VioMaxMv) then
      AddIssue(Result, piSignalVoltageUnknown,
        'configured signal voltage is outside programmer capability');
  end
  else
    ProgrammerVio := Programmer.FixedVioMv;

  if Observation.EffectiveTargetVioMv = 0 then
    AddIssue(Result, piSignalVoltageUnknown,
      'effective target-side signal voltage is unknown')
  else if Observation.EffectiveTargetVioMv > Target.VioMaxMv then
    AddIssue(Result, piSignalVoltageTooHigh,
      Format('target-side signal voltage is %d mV; target maximum is %d mV',
             [Observation.EffectiveTargetVioMv, Target.VioMaxMv]));

  if Adapter.Present and (ProgrammerVio > Adapter.MaxProgrammerSideVioMv) then
    AddIssue(Result, piAdapterInputVoltageTooHigh,
      Format('programmer signal voltage is %d mV; adapter input maximum is %d mV',
             [ProgrammerVio, Adapter.MaxProgrammerSideVioMv]));

  OpenDrainAvailable := Programmer.SupportsOpenDrain or
                        (Adapter.Present and Adapter.ProvidesOpenDrain);
  if Target.RequiresOpenDrain and (not OpenDrainAvailable) then
    AddIssue(Result, piOpenDrainUnavailable,
      'target protocol/profile requires open-drain signalling');

  if Policy.DestructiveOperation and
     Policy.RequireCurrentLimitForDestructive then
  begin
    if Observation.ExternalPowerPresent then
    begin
      if not Observation.ExternalPowerCurrentLimited then
        AddIssue(Result, piExternalPowerCurrentLimitUnavailable,
          'external target supply has no confirmed hardware current limit');
    end
    else
    begin
      if not Programmer.HasCurrentLimit then
        AddIssue(Result, piCurrentLimitUnavailable,
          'destructive operation requires a hardware current limit')
      else if not Observation.CurrentLimitEnabled then
        AddIssue(Result, piCurrentLimitNotEnabled,
          'hardware current limit exists but is not enabled');
    end;
  end;

  Result.MaxSafeBusHz := Target.MaxBusHz;
  Result.MaxSafeBusHz := LowerNonZero(Result.MaxSafeBusHz,
                                     Programmer.MaxBusHz[Target.Protocol]);
  if Adapter.Present then
    Result.MaxSafeBusHz := LowerNonZero(Result.MaxSafeBusHz,
                                       Adapter.MaxBusHz[Target.Protocol]);

  if Observation.RequestedBusHz = 0 then
    AddIssue(Result, piBusFrequencyUnknown,
      'requested bus frequency is zero or unknown')
  else if (Result.MaxSafeBusHz = 0) or
          (Observation.RequestedBusHz > Result.MaxSafeBusHz) then
    AddIssue(Result, piBusFrequencyTooHigh,
      Format('requested clock is %d Hz; safe maximum is %d Hz',
             [Observation.RequestedBusHz, Result.MaxSafeBusHz]));
end;

function ProtocolName(Protocol_: TSerialProtocol): string;
begin
  case Protocol_ of
    spSPI: Result := 'SPI';
    spI2C: Result := 'I2C';
    spMicrowire: Result := 'MicroWire';
  end;
end;

function PreflightIssueCodeName(Code: TPreflightIssueCode): string;
begin
  case Code of
    piProgrammerCapabilitiesUnknown: Result := 'programmer_capabilities_unknown';
    piProgrammerIdentityMismatch: Result := 'programmer_identity_mismatch';
    piProtocolUnsupportedByProgrammer: Result := 'programmer_protocol_unsupported';
    piPinsNotSafeAtOpen: Result := 'pins_not_safe_at_open';
    piAdapterRequired: Result := 'adapter_required';
    piUnexpectedAdapter: Result := 'unexpected_adapter';
    piAdapterCapabilitiesInvalid: Result := 'adapter_capabilities_invalid';
    piAdapterIdentityUnverified: Result := 'adapter_identity_unverified';
    piAdapterIdentityMismatch: Result := 'adapter_identity_mismatch';
    piProtocolUnsupportedByAdapter: Result := 'adapter_protocol_unsupported';
    piAdapterCalibrationInvalid: Result := 'adapter_calibration_invalid';
    piExternalPowerStateUnknown: Result := 'external_power_state_unknown';
    piExternalPowerForbidden: Result := 'external_power_forbidden';
    piPowerSourceContention: Result := 'power_source_contention';
    piTargetPowerUnavailable: Result := 'target_power_unavailable';
    piTargetVoltageUnselectable: Result := 'target_voltage_unselectable';
    piTargetVoltageUnknown: Result := 'target_voltage_unknown';
    piTargetVoltageOutOfRange: Result := 'target_voltage_out_of_range';
    piTargetVoltageNotMeasured: Result := 'target_voltage_not_measured';
    piSignalVoltageUnknown: Result := 'signal_voltage_unknown';
    piSignalVoltageTooHigh: Result := 'signal_voltage_too_high';
    piAdapterInputVoltageTooHigh: Result := 'adapter_input_voltage_too_high';
    piOpenDrainUnavailable: Result := 'open_drain_unavailable';
    piExternalPowerCurrentLimitUnavailable:
      Result := 'external_power_current_limit_unavailable';
    piCurrentLimitUnavailable: Result := 'current_limit_unavailable';
    piCurrentLimitNotEnabled: Result := 'current_limit_not_enabled';
    piBusFrequencyUnknown: Result := 'bus_frequency_unknown';
    piBusFrequencyTooHigh: Result := 'bus_frequency_too_high';
  end;
end;

end.
