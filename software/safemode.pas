unit safemode;

// A latch that makes the program incapable of changing a chip.
//
// The situation it exists for: an unknown part, or a customer's board, that
// you need to read and identify and nothing more. Every safeguard elsewhere
// in this program is a judgement -- is this rail right, is this clip solid,
// does this image fit. Judgements can be wrong, and the ones here are made by
// software reading a chip that may be lying about what it is.
//
// This is not a judgement. It is a switch that removes the capability, so
// that no sequence of buttons, no CLI switch, no script, and no mistake in
// any of the judgements above can erase, write, unlock, or edit a status
// register while it is on. The only way past it is to turn it off, which is
// a decision a person makes on purpose rather than a dialog they dismiss.
//
// Deliberately not overridable by --force. --force means "I know what I am
// doing" and it belongs on gates that guard against things an operator can
// actually know. Safe Mode guards against the operator, at the operator's own
// earlier request; a flag that switched it off would make it a suggestion.
//
// Status-register writes are in scope, and that is the non-obvious part. They
// do not change a single byte of the array, so it is tempting to treat them
// as harmless. They are how a chip becomes permanently locked: SRP/WPS bits
// can be set into one-time-programmable configurations that no software will
// ever undo. On a customer's part that is worse than a bad write, because a
// bad write can be restored from the backup.
//
// No hardware access and no LCL unit, so the rule is one testable table.

{$mode objfpc}{$H+}

interface

type
  TGuardedAction = (
    // Reading in every form. Never blocked; the whole point of Safe Mode is
    // to make reading the only thing that can happen.
    gaRead,
    gaDetect,
    gaVerify,
    gaCompare,

    // Everything that can change the part.
    gaErase,
    gaWrite,
    gaUnlock,
    gaWriteStatusRegister,
    // The capacity and surface tests deliberately destroy and restore. They
    // are diagnostics, but they are diagnostics that write.
    gaDestructiveSelfTest
  );

// Off at startup: a safety mode that is on by default gets switched off once,
// on the first day, and never switched back on.
function SafeModeActive: boolean;
procedure SetSafeMode(Enabled: boolean);

// The single question every destructive path asks. True means refuse.
function SafeModeBlocks(Action: TGuardedAction): boolean;

// The sentence to show when it refuses. Empty when the action is allowed.
function SafeModeRefusal(Action: TGuardedAction): string;

function GuardedActionName(Action: TGuardedAction): string;

implementation

uses
  SysUtils;

var
  FActive: boolean = False;

function SafeModeActive: boolean;
begin
  Result := FActive;
end;

procedure SetSafeMode(Enabled: boolean);
begin
  FActive := Enabled;
end;

function ActionChangesTheChip(Action: TGuardedAction): boolean;
begin
  case Action of
    gaRead, gaDetect, gaVerify, gaCompare:
      Result := False;
    gaErase, gaWrite, gaUnlock, gaWriteStatusRegister,
    gaDestructiveSelfTest:
      Result := True;
  else
    //A new action nobody classified is treated as destructive.  The cost of
    //being wrong that way is a refused operation; the cost of the default
    //going the other way is a customer's chip.
    Result := True;
  end;
end;

function SafeModeBlocks(Action: TGuardedAction): boolean;
begin
  Result := FActive and ActionChangesTheChip(Action);
end;

function GuardedActionName(Action: TGuardedAction): string;
begin
  case Action of
    gaRead:                 Result := 'read';
    gaDetect:               Result := 'detect';
    gaVerify:               Result := 'verify';
    gaCompare:              Result := 'compare';
    gaErase:                Result := 'erase';
    gaWrite:                Result := 'write';
    gaUnlock:               Result := 'unlock';
    gaWriteStatusRegister:  Result := 'status register write';
    gaDestructiveSelfTest:  Result := 'destructive self test';
  else
    Result := 'operation';
  end;
end;

function SafeModeRefusal(Action: TGuardedAction): string;
begin
  Result := '';
  if not SafeModeBlocks(Action) then Exit;
  Result := 'read-only safe mode is on, so ' + GuardedActionName(Action) +
            ' is not available. Turn it off in Options if you intend to ' +
            'change this chip.';
  if Action = gaWriteStatusRegister then
    //Say why this one counts, because it is the one people are surprised by.
    Result := Result + ' Status-register writes are included because SRP and ' +
              'WPS bits can lock a part permanently without changing a byte ' +
              'of its contents.';
end;

end.
