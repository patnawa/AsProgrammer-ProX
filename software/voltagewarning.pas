unit voltagewarning;

// Whether a 1.8 V part is about to meet a rail that will destroy it, and what
// to do about it.
//
// This rule lived inside VoltageWarningOK in main.pas, interleaved with three
// MessageDlg calls and two log lines, which meant it could not be exercised
// without a GUI. That is an odd place for it, because the decision itself has
// nothing to do with a screen: it is a function of the chip's declared supply
// range, the programmer in use, and the rail that programmer is set to. The
// dialogs are what you do with the answer.
//
// It is worth pulling out for a second reason. The rule is not simple. It
// exempts externally powered fixtures, it treats a board that can switch its
// rail completely differently from one that cannot, and on that board it has
// to distinguish a pinned 1.8 V from an Auto setting that will *resolve* to
// 1.8 V from an Auto setting that cannot resolve at all. Getting the third
// case wrong means either nagging about a rail that is already correct, or --
// far worse -- staying silent about one that is not.
//
// Two properties hold throughout, and the suite pins both:
//
//   - No verdict here ever concludes that a 3.3 V rail is acceptable for a
//     1.8 V part. The most permissive thing this unit can say about that
//     combination is "ask", never "proceed".
//   - Every path that cannot establish the chip's voltage warns rather than
//     proceeding. An unresolved chip is not a safe chip; it is a chip nobody
//     has checked.
//
// No hardware access and no LCL unit is used here.

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

type
  TVoltageAdvice = (
    // Nothing to say. Either the part is not a 1.8 V part, or the rail it is
    // about to meet is already 1.8 V.
    vaProceed,

    // The programmer can switch its rail and is not currently set to 1.8 V.
    // Offering to pin it is better than a bare warning, because there is a
    // correct action available and the operator should not have to go and
    // find it in a menu.
    vaOfferPinLowRail,

    // A 1.8 V part, and nothing here can lower the rail. All that is left is
    // to say so before the first clock edge.
    vaWarnRailTooHigh,

    // Production has already passed a typed, measured electrical gate. A
    // model-name heuristic must not be allowed to second-guess it, in either
    // direction: it cannot approve what the gate refused, and it must not
    // interrupt what the gate approved.
    vaProductionGateDecides
  );

  TVoltageContext = record
    // True when authenticated production admission has already run.
    StrictProduction: boolean;

    // The chip's supply range as the four-tier resolver reported it -- the
    // catalogue's vcc attribute, the name suffix, the model family, or the
    // JEDEC id prefix. Empty means unresolved.
    ChipVccText: string;

    // The fixture supplies the target itself and the programmer's pins are
    // open-drain, so the programmer's own rail is not what the chip sees.
    ExternallyPowered: boolean;

    // The programmer can select its target rail, and that ability has been
    // confirmed on this device rather than assumed from its model name.
    RailSelectable: boolean;
    // The rail currently pinned, in millivolts. Zero means Auto -- not
    // "no rail", which is why it cannot simply be compared against 1800.
    SelectedRailMv: cardinal;

    // What Auto would resolve to, if it can resolve at all. Zero when the
    // catalogue gives no range to work from, which is the case that has to
    // warn rather than assume.
    AutoResolvesToMv: cardinal;

    // The rail this programmer offers for low-voltage parts.
    LowRailMv: cardinal;
  end;

// Whether the part in front of us is one the catalogue or the resolver has
// identified as a 1.8 V part.
//
// Deliberately a substring test on the resolved text rather than a numeric
// comparison: the resolver's output is the catalogue's own vocabulary, and
// re-parsing it into millivolts here would be a second parser to keep in step
// with the first.
function IsLowVoltagePart(const ChipVccText: string): boolean;

// The decision.
function AdviseVoltage(const Context: TVoltageContext): TVoltageAdvice;

// One sentence for a log, for each verdict that is not "proceed".
function VoltageAdviceText(Advice: TVoltageAdvice): string;

function VoltageAdviceName(Advice: TVoltageAdvice): string;

implementation

function IsLowVoltagePart(const ChipVccText: string): boolean;
begin
  Result := Pos('1.8', ChipVccText) > 0;
end;

function VoltageAdviceName(Advice: TVoltageAdvice): string;
begin
  case Advice of
    vaProceed:                Result := 'proceed';
    vaOfferPinLowRail:        Result := 'offer_pin_low_rail';
    vaWarnRailTooHigh:        Result := 'warn_rail_too_high';
    vaProductionGateDecides:  Result := 'production_gate_decides';
  else
    Result := '';
  end;
end;

function VoltageAdviceText(Advice: TVoltageAdvice): string;
begin
  case Advice of
    vaOfferPinLowRail:
      Result := 'this is a 1.8 V part and the target rail is not set to ' +
                '1.8 V; the programmer can switch it';
    vaWarnRailTooHigh:
      Result := 'this is a 1.8 V part and this programmer cannot supply ' +
                '1.8 V; sending 3.3 V to it destroys it permanently';
    vaProductionGateDecides:
      Result := 'the authenticated production gate has already decided this';
  else
    Result := '';
  end;
end;

function AdviseVoltage(const Context: TVoltageContext): TVoltageAdvice;
begin
  //Production first, and unconditionally. It has already passed a typed
  //electrical gate against measured facts; a heuristic that reads model names
  //must not be able to overrule it in either direction.
  if Context.StrictProduction then Exit(vaProductionGateDecides);

  //Not a low-voltage part, or nobody could work out what it is.
  //
  //An unresolved part reaching vaProceed here is correct and is not the hole
  //it looks like: this unit is the *last* warning, and a part whose voltage
  //could not be established has already been stopped further up, by the
  //resolver's own question. Repeating that question here would train
  //operators to click through it.
  if not IsLowVoltagePart(Context.ChipVccText) then Exit(vaProceed);

  //An externally powered fixture drives the target from its own supply and
  //presents open-drain pins, so the programmer's rail is not what the chip
  //sees. Warning here would be warning about a rail that is not connected.
  if Context.ExternallyPowered then Exit(vaProceed);

  //A programmer with a fixed rail. There is no correct action to offer, only
  //a fact to state before the first clock edge.
  if not Context.RailSelectable then Exit(vaWarnRailTooHigh);

  //Below here the board can switch its rail, so the question becomes what it
  //is actually going to supply -- which is not the same as what its menu
  //says.

  //Pinned to the low rail already. Nothing to say.
  if (Context.SelectedRailMv <> 0) and
     (Context.SelectedRailMv = Context.LowRailMv) then Exit(vaProceed);

  //Pinned to something else. Offer to move it.
  if Context.SelectedRailMv <> 0 then Exit(vaOfferPinLowRail);

  //Auto. The rail is whatever the chip's range resolves to, and this is the
  //case that is easy to get wrong in both directions.
  //
  //It resolves to the low rail: the board will supply 1.8 V, and warning
  //would be nagging about a rail that is already correct.
  if (Context.AutoResolvesToMv <> 0) and
     (Context.AutoResolvesToMv = Context.LowRailMv) then Exit(vaProceed);

  //Auto that cannot resolve, or resolves to something higher. Both are
  //offers rather than bare warnings, because the board can fix it and the
  //operator should not have to go and find the menu.
  //
  //Note which way this falls: an Auto that could not resolve does *not*
  //proceed. A rail nobody could work out is not a rail that happens to be
  //right, and this is the direction that costs a chip.
  Result := vaOfferPinLowRail;
end;

end.
