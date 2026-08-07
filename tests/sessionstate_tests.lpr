program sessionstate_tests;

// The admission ladder that stands between a button press and the bus.
//
// Most of these tests are about revocation rather than progress.  Reaching
// Armed is easy to get right; staying armed after the premise moved is the
// bug that costs a chip, so that is what the bulk of this file pins.

{$mode objfpc}{$H+}

uses
  SysUtils, sessionstate;

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

procedure CheckState(const Name: string; S: TProgrammingSession;
  Expected: TSessionState);
begin
  Inc(Assertions);
  if S.State <> Expected then
  begin
    Inc(Failures);
    WriteLn('FAIL: ', Name, ' (expected ', SessionStateName(Expected),
            ', got ', SessionStateName(S.State), ')');
  end;
end;

// Drives the session up to and including Armed, the way a real write does.
procedure ArmFor(S: TProgrammingSession; WithImage: boolean);
var
  Refusal: string;
begin
  S.Apply(seProgrammerOpened, Refusal);
  S.Apply(seRailConfigured, Refusal);
  S.Apply(seChipDetected, Refusal);
  if WithImage then S.Apply(seImageLoaded, Refusal);
  S.Apply(sePreflightPassed, Refusal);
  S.Apply(seArmed, Refusal);
end;

procedure TestLadder;
var
  S: TProgrammingSession;
  R: string;
begin
  S := TProgrammingSession.Create;
  try
    CheckState('a fresh session is disconnected', S, ssDisconnected);

    Check('opening a programmer is accepted',
      S.Apply(seProgrammerOpened, R));
    CheckState('an open programmer is connected', S, ssConnected);

    Check('the rail is configured after opening',
      S.Apply(seRailConfigured, R));
    CheckState('a configured rail shows', S, ssRailConfigured);

    Check('a chip may answer once the rail is set',
      S.Apply(seChipDetected, R));
    CheckState('a detected chip shows', S, ssChipDetected);

    Check('an image loads', S.Apply(seImageLoaded, R));
    CheckState('a loaded image shows', S, ssImageLoaded);

    Check('preflight passes', S.Apply(sePreflightPassed, R));
    CheckState('a passed preflight shows', S, ssPreflightPassed);

    Check('arming is accepted', S.Apply(seArmed, R));
    CheckState('an armed session shows', S, ssArmed);

    Check('a write starts', S.Apply(seWriteStarted, R));
    CheckState('a running write shows', S, ssWriting);

    Check('verify follows the write', S.Apply(seVerifyStarted, R));
    CheckState('a running verify shows', S, ssVerifying);

    Check('the run completes', S.Apply(seOperationSucceeded, R));
    CheckState('a finished run shows', S, ssCompleted);
  finally
    S.Free;
  end;
end;

procedure TestStepsCannotBeSkipped;
var
  S: TProgrammingSession;
  R: string;
begin
  S := TProgrammingSession.Create;
  try
    Check('the rail cannot be configured with nothing open',
      not S.Apply(seRailConfigured, R));
    Check('refusing the rail explains itself', R <> '');

    S.Apply(seProgrammerOpened, R);
    Check('a chip cannot be detected before the rail is configured',
      not S.Apply(seChipDetected, R));

    S.Apply(seRailConfigured, R);
    Check('arming without a preflight is refused', not S.Apply(seArmed, R));

    S.Apply(seChipDetected, R);
    Check('arming still needs the preflight', not S.Apply(seArmed, R));

    S.Apply(sePreflightPassed, R);
    Check('a write cannot start before arming',
      not S.Apply(seWriteStarted, R));

    Check('now arming is accepted', S.Apply(seArmed, R));
    Check('and the write starts', S.Apply(seWriteStarted, R));
  finally
    S.Free;
  end;
end;

procedure TestRailChangeRevokesEverythingDownstream;
var
  S: TProgrammingSession;
  R: string;
begin
  S := TProgrammingSession.Create;
  try
    ArmFor(S, True);
    CheckState('armed before the rail moves', S, ssArmed);

    Check('a rail change is always accepted', S.Apply(seRailChanged, R));
    Check('the rail change disarms', not S.Holds(sfArmed));
    Check('the rail change invalidates the preflight',
      not S.Holds(sfPreflightPassed));
    //A chip that answered at the old rail is not evidence of a chip at the
    //new one.  This is the assertion the whole unit exists for.
    Check('the rail change invalidates chip detection',
      not S.Holds(sfChipDetected));
    Check('the rail itself is still configured', S.Holds(sfRailConfigured));
    Check('the loaded image survives a rail change',
      S.Holds(sfImageLoaded));
    Check('a write is refused after the rail moved',
      not S.MayStart(soWrite));
    Check('an erase is refused after the rail moved',
      not S.MayStart(soErase));
  finally
    S.Free;
  end;
end;

procedure TestNewImageRevokesArming;
var
  S: TProgrammingSession;
  R: string;
begin
  S := TProgrammingSession.Create;
  try
    ArmFor(S, True);
    Check('loading another image is accepted', S.Apply(seImageLoaded, R));
    Check('the new image disarms', not S.Holds(sfArmed));
    Check('the new image invalidates the preflight',
      not S.Holds(sfPreflightPassed));
    Check('the chip is still detected', S.Holds(sfChipDetected));
    CheckState('the session falls back to image loaded', S, ssImageLoaded);
  finally
    S.Free;
  end;
end;

procedure TestDisconnectClearsEverything;
var
  S: TProgrammingSession;
  R: string;
begin
  S := TProgrammingSession.Create;
  try
    ArmFor(S, True);
    S.Apply(seWriteStarted, R);
    Check('a closed programmer is always accepted',
      S.Apply(seProgrammerClosed, R));
    CheckState('a closed programmer is disconnected', S, ssDisconnected);
    Check('nothing survives the close', S.Facts = []);
    Check('detect is refused with nothing open', not S.MayStart(soDetect));

    //Re-opening must not resurrect what the previous device established.
    ArmFor(S, True);
    Check('reopening drops the old facts',
      S.Apply(seProgrammerOpened, R) and (S.Facts = [sfProgrammerOpen]));
  finally
    S.Free;
  end;
end;

procedure TestArmingIsSpentByARun;
var
  S: TProgrammingSession;
  R: string;
begin
  S := TProgrammingSession.Create;
  try
    ArmFor(S, True);
    S.Apply(seWriteStarted, R);
    S.Apply(seOperationSucceeded, R);
    //The next part in the socket is a different part.
    Check('a completed run consumes the arming', not S.Holds(sfArmed));
    Check('the next write is refused until re-armed',
      not S.MayStart(soWrite));

    ArmFor(S, True);
    S.Apply(seWriteStarted, R);
    S.Apply(seOperationFailed, R);
    Check('a failed run consumes the arming too', not S.Holds(sfArmed));
    CheckState('a failed run leaves the preflight standing', S,
      ssPreflightPassed);
  finally
    S.Free;
  end;
end;

procedure TestOperationAdmission;
var
  S: TProgrammingSession;
  R: string;
begin
  S := TProgrammingSession.Create;
  try
    S.Apply(seProgrammerOpened, R);
    Check('detect needs a configured rail', not S.MayStart(soDetect));
    S.Apply(seRailConfigured, R);
    Check('detect runs once the rail is configured', S.MayStart(soDetect));
    Check('read still needs a chip', not S.MayStart(soRead));

    S.Apply(seChipDetected, R);
    Check('read runs on a detected chip', S.MayStart(soRead));
    Check('read never needs arming', S.MayStart(soRead));
    Check('verify still needs an image', not S.MayStart(soVerify));
    //Erase carries no image, and must not be forced to pretend it does.
    Check('erase needs arming, not an image', not S.MayStart(soErase));

    S.Apply(sePreflightPassed, R);
    S.Apply(seArmed, R);
    Check('erase runs armed with no image at all', S.MayStart(soErase));
    Check('unlock runs armed with no image at all', S.MayStart(soUnlock));
    Check('write still needs the image', not S.MayStart(soWrite));

    S.Apply(seImageLoaded, R);
    Check('the fresh image disarmed the session', not S.MayStart(soWrite));
    S.Apply(sePreflightPassed, R);
    S.Apply(seArmed, R);
    Check('write runs armed with an image', S.MayStart(soWrite));
    Check('verify runs with a chip and an image', S.MayStart(soVerify));
  finally
    S.Free;
  end;
end;

procedure TestRefusalsNameTheEarliestGap;
var
  S: TProgrammingSession;
  R: string;
begin
  S := TProgrammingSession.Create;
  try
    Check('a refusal is produced when nothing is open',
      Pos('no programmer is open', S.StartRefusal(soWrite)) > 0);

    S.Apply(seProgrammerOpened, R);
    Check('the next gap named is the rail',
      Pos('target rail', S.StartRefusal(soWrite)) > 0);

    S.Apply(seRailConfigured, R);
    Check('the next gap named is the chip',
      Pos('no chip', S.StartRefusal(soWrite)) > 0);

    S.Apply(seChipDetected, R);
    Check('the next gap named is the image',
      Pos('no image', S.StartRefusal(soWrite)) > 0);

    S.Apply(seImageLoaded, R);
    Check('the next gap named is the preflight',
      Pos('preflight', S.StartRefusal(soWrite)) > 0);

    S.Apply(sePreflightPassed, R);
    Check('the last gap named is the arming',
      Pos('not armed', S.StartRefusal(soWrite)) > 0);

    S.Apply(seArmed, R);
    Check('an allowed operation has no refusal to give',
      S.StartRefusal(soWrite) = '');
  finally
    S.Free;
  end;
end;

procedure TestStandaloneVerify;
var
  S: TProgrammingSession;
  R: string;
begin
  S := TProgrammingSession.Create;
  try
    S.Apply(seProgrammerOpened, R);
    S.Apply(seRailConfigured, R);
    S.Apply(seChipDetected, R);
    Check('verify with no image is refused',
      not S.Apply(seVerifyStarted, R));
    S.Apply(seImageLoaded, R);
    //Verify writes nothing, so it must not be gated behind arming.
    Check('verify runs unarmed', S.Apply(seVerifyStarted, R));
    CheckState('a standalone verify shows', S, ssVerifying);
  finally
    S.Free;
  end;
end;

begin
  TestLadder;
  TestStepsCannotBeSkipped;
  TestRailChangeRevokesEverythingDownstream;
  TestNewImageRevokesArming;
  TestDisconnectClearsEverything;
  TestArmingIsSpentByARun;
  TestOperationAdmission;
  TestRefusalsNameTheEarliestGap;
  TestStandaloneVerify;
  WriteLn(Assertions, ' assertions, ', Failures, ' failures');
  if Failures <> 0 then Halt(1);
  WriteLn('ALL PASSED');
end.
