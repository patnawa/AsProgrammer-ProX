program safemode_tests;

// The latch that makes the program incapable of changing a chip.
//
// The assertions here are almost all about what Safe Mode does NOT let
// through. That asymmetry is the point: a safety latch is only worth having
// if the list of things it stops is exhaustive and cannot quietly shrink when
// somebody adds a new destructive operation.

{$mode objfpc}{$H+}

uses
  SysUtils, safemode;

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

procedure TestOffByDefault;
begin
  //A safety mode that starts on gets switched off once, on the first day,
  //and never switched back on.
  Check('safe mode is off at startup', not SafeModeActive);
  Check('and blocks nothing while off', not SafeModeBlocks(gaErase));
  Check('nor writes', not SafeModeBlocks(gaWrite));
end;

procedure TestBlocksEverythingThatChangesTheChip;
begin
  SetSafeMode(True);
  Check('safe mode reports itself active', SafeModeActive);

  Check('erase is blocked', SafeModeBlocks(gaErase));
  Check('write is blocked', SafeModeBlocks(gaWrite));
  Check('unlock is blocked', SafeModeBlocks(gaUnlock));
  //The non-obvious one. A status-register write changes no data byte, but
  //SRP/WPS bits can lock a part permanently, and on a customer's chip that
  //is worse than a bad write because a bad write restores from backup.
  Check('a status register write is blocked',
    SafeModeBlocks(gaWriteStatusRegister));
  //These restore what they destroy, but they destroy first.
  Check('a destructive self test is blocked',
    SafeModeBlocks(gaDestructiveSelfTest));
end;

procedure TestNeverBlocksReading;
begin
  SetSafeMode(True);
  //Safe Mode exists to make reading the only thing that can happen, so
  //blocking any read would defeat it entirely.
  Check('read is allowed', not SafeModeBlocks(gaRead));
  Check('detect is allowed', not SafeModeBlocks(gaDetect));
  Check('verify is allowed', not SafeModeBlocks(gaVerify));
  Check('compare is allowed', not SafeModeBlocks(gaCompare));
end;

procedure TestEveryActionIsClassified;
var
  A: TGuardedAction;
  BlockedCount: integer;
begin
  SetSafeMode(True);
  BlockedCount := 0;
  for A := Low(TGuardedAction) to High(TGuardedAction) do
  begin
    Check('every action has a name', GuardedActionName(A) <> '');
    if SafeModeBlocks(A) then Inc(BlockedCount);
  end;
  //Five destructive actions today. If somebody adds one and forgets to
  //classify it, the default in ActionChangesTheChip catches it -- but this
  //count going up unexpectedly is the signal to look.
  Check('five actions are destructive', BlockedCount = 5);

  SetSafeMode(False);
  for A := Low(TGuardedAction) to High(TGuardedAction) do
    Check('nothing is blocked while off', not SafeModeBlocks(A));
end;

procedure TestRefusalsExplainThemselves;
var
  A: TGuardedAction;
begin
  SetSafeMode(True);
  for A := Low(TGuardedAction) to High(TGuardedAction) do
    if SafeModeBlocks(A) then
    begin
      Check('a blocked action explains itself', SafeModeRefusal(A) <> '');
      //The operator has to be able to find the switch.
      Check('and says where the switch is',
        Pos('Options', SafeModeRefusal(A)) > 0);
      Check('and names the operation',
        Pos(GuardedActionName(A), SafeModeRefusal(A)) > 0);
    end
    else
      Check('an allowed action has no refusal', SafeModeRefusal(A) = '');

  //Status-register writes get an extra sentence, because that is the
  //inclusion people are surprised by and argue with.
  Check('the status register refusal explains why it counts',
    Pos('lock a part permanently',
        SafeModeRefusal(gaWriteStatusRegister)) > 0);

  SetSafeMode(False);
  Check('no refusal is produced while off', SafeModeRefusal(gaErase) = '');
end;

procedure TestToggling;
begin
  SetSafeMode(True);
  Check('on blocks', SafeModeBlocks(gaWrite));
  SetSafeMode(False);
  Check('off allows', not SafeModeBlocks(gaWrite));
  SetSafeMode(True);
  Check('back on blocks again', SafeModeBlocks(gaWrite));
  SetSafeMode(False);
end;

begin
  TestOffByDefault;
  TestBlocksEverythingThatChangesTheChip;
  TestNeverBlocksReading;
  TestEveryActionIsClassified;
  TestRefusalsExplainThemselves;
  TestToggling;
  WriteLn(Assertions, ' assertions, ', Failures, ' failures');
  if Failures <> 0 then Halt(1);
  WriteLn('ALL PASSED');
end.
