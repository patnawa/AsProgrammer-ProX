unit sessionstate;

// The session-level state machine that stands between a button press and the
// bus.
//
// operationmodel.TOperationPhase already describes what happens *inside* one
// operation.  This unit describes what must be established *before* one may
// start: which programmer is open, which rail was configured, which chip
// answered, which image is loaded, whether preflight passed, and whether the
// operator armed the destructive step.
//
// The point is not bookkeeping.  It is that a GUI button, a CLI switch and a
// future API all reach the same guard, and that a fact learned earlier is
// invalidated the moment its premise changes.  Re-selecting the target rail
// revokes arming, because the preflight that allowed it was evaluated against
// the old rail; a chip that answered at 3.3 V is not evidence that a chip is
// present at 1.8 V.
//
// The ladder the operator sees
//
//   Disconnected -> Connected -> RailConfigured -> ChipDetected
//   -> ImageLoaded -> PreflightPassed -> Armed -> Writing -> Verifying
//   -> Completed
//
// is derived, not stored.  Storing it as a cursor would force an erase (which
// needs no image) to pretend an image was loaded in order to reach Armed.
// Facts are stored; the rung is whatever those facts add up to.  The names and
// their order are exactly the ladder above.
//
// No hardware access and no LCL unit is used here, so every transition can be
// exercised in memory.

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

type
  TSessionState = (
    ssDisconnected,
    ssConnected,
    ssRailConfigured,
    ssChipDetected,
    ssImageLoaded,
    ssPreflightPassed,
    ssArmed,
    ssWriting,
    ssVerifying,
    ssCompleted
  );

  // What the session has established.  Every one of these is revocable, and
  // the revocation rules in Apply are the safety-carrying part of this unit.
  TSessionFact = (
    sfProgrammerOpen,
    sfRailConfigured,
    sfChipDetected,
    sfImageLoaded,
    sfPreflightPassed,
    sfArmed
  );
  TSessionFacts = set of TSessionFact;

  TSessionEvent = (
    seProgrammerOpened,
    seProgrammerClosed,
    seRailConfigured,
    // The rail moved after it was configured.  Everything downstream of it
    // was concluded under the old rail and is now worthless.
    seRailChanged,
    seChipDetected,
    seChipLost,
    seImageLoaded,
    seImageCleared,
    sePreflightPassed,
    sePreflightFailed,
    seArmed,
    seDisarmed,
    seWriteStarted,
    seVerifyStarted,
    seOperationSucceeded,
    seOperationFailed
  );

  // What a caller is about to do.  Each one names the facts it needs; nothing
  // else in the program decides that.
  TSessionOperation = (
    soDetect,
    soRead,
    soVerify,
    soErase,
    soWrite,
    soUnlock
  );

  { TProgrammingSession }

  TProgrammingSession = class
  private
    FFacts: TSessionFacts;
    FWriting: boolean;
    FVerifying: boolean;
    FCompleted: boolean;
    procedure Invalidate(Fact: TSessionFact);
    procedure EndActivity;
    function Refuse(const Reason: string; out Refusal: string): boolean;
  public
    constructor Create;

    // Applies one event.  Returns False and fills Refusal when the event
    // cannot follow from what the session has established; the session is
    // left untouched in that case.  Revoking events (a closed programmer, a
    // moved rail, a lost chip) always apply: losing a fact is never refused.
    function Apply(Event: TSessionEvent; out Refusal: string): boolean;

    // The rung of the ladder the session is standing on.
    function State: TSessionState;

    function Holds(Fact: TSessionFact): boolean;

    // The single admission gate.  MayStart is the question; StartRefusal is
    // the sentence to show the operator, and is empty exactly when MayStart
    // is True.
    function MayStart(Op: TSessionOperation): boolean;
    function StartRefusal(Op: TSessionOperation): string;

    property Facts: TSessionFacts read FFacts;
  end;

function SessionStateName(State: TSessionState): string;
function SessionOperationName(Op: TSessionOperation): string;

// The facts an operation needs before it may touch the bus.  Exposed so a
// caller can explain a refusal in its own words instead of re-deriving the
// rule and drifting from it.
function RequiredFacts(Op: TSessionOperation): TSessionFacts;

implementation

function SessionStateName(State: TSessionState): string;
begin
  case State of
    ssDisconnected:    Result := 'disconnected';
    ssConnected:       Result := 'connected';
    ssRailConfigured:  Result := 'rail_configured';
    ssChipDetected:    Result := 'chip_detected';
    ssImageLoaded:     Result := 'image_loaded';
    ssPreflightPassed: Result := 'preflight_passed';
    ssArmed:           Result := 'armed';
    ssWriting:         Result := 'writing';
    ssVerifying:       Result := 'verifying';
    ssCompleted:       Result := 'completed';
  end;
end;

function SessionOperationName(Op: TSessionOperation): string;
begin
  case Op of
    soDetect: Result := 'detect';
    soRead:   Result := 'read';
    soVerify: Result := 'verify';
    soErase:  Result := 'erase';
    soWrite:  Result := 'write';
    soUnlock: Result := 'unlock';
  end;
end;

function RequiredFacts(Op: TSessionOperation): TSessionFacts;
begin
  case Op of
    // Detection is how a chip is found in the first place, so it cannot
    // require one.  It still requires a configured rail: the whole reason a
    // 1.8 V part survives detection is that nobody probed it at 3.3 V.
    soDetect:
      Result := [sfProgrammerOpen, sfRailConfigured];
    soRead:
      Result := [sfProgrammerOpen, sfRailConfigured, sfChipDetected];
    soVerify:
      Result := [sfProgrammerOpen, sfRailConfigured, sfChipDetected,
                 sfImageLoaded];
    // Erase and unlock destroy without needing an image.  Arming is what
    // stands in for the operator's intent.
    soErase, soUnlock:
      Result := [sfProgrammerOpen, sfRailConfigured, sfChipDetected,
                 sfPreflightPassed, sfArmed];
    soWrite:
      Result := [sfProgrammerOpen, sfRailConfigured, sfChipDetected,
                 sfImageLoaded, sfPreflightPassed, sfArmed];
  end;
end;

function MissingFactReason(Fact: TSessionFact): string;
begin
  case Fact of
    sfProgrammerOpen:
      Result := 'no programmer is open';
    sfRailConfigured:
      Result := 'the target rail has not been configured';
    sfChipDetected:
      Result := 'no chip has answered on the bus';
    sfImageLoaded:
      Result := 'no image is loaded';
    sfPreflightPassed:
      Result := 'electrical preflight has not passed';
    sfArmed:
      Result := 'the operation is not armed';
  end;
end;

{ TProgrammingSession }

constructor TProgrammingSession.Create;
begin
  inherited Create;
  FFacts := [];
  FWriting := False;
  FVerifying := False;
  FCompleted := False;
end;

// What stops being true when Fact stops being true.
//
// This is a table and not a subtraction over the enum order, because the
// facts are not a chain.  An image comes from a file and knows nothing about
// the rail or the socket, so changing the rail must not unload it; the
// ladder in TSessionState puts ImageLoaded above ChipDetected only because
// that is the order an operator meets them, not because one causes the other.
//
// The two that depend on everything are the two that were *concluded* rather
// than observed: a preflight is a judgement about a specific rail, chip and
// image, and an arming is a judgement about a specific preflight.
function DependentsOf(Fact: TSessionFact): TSessionFacts;
begin
  case Fact of
    sfProgrammerOpen:
      Result := [sfRailConfigured, sfChipDetected, sfImageLoaded,
                 sfPreflightPassed, sfArmed];
    sfRailConfigured:
      Result := [sfChipDetected, sfPreflightPassed, sfArmed];
    sfChipDetected:
      Result := [sfPreflightPassed, sfArmed];
    sfImageLoaded:
      Result := [sfPreflightPassed, sfArmed];
    sfPreflightPassed:
      Result := [sfArmed];
    sfArmed:
      Result := [];
  end;
end;

// Drops Fact and everything that was concluded on top of it.
procedure TProgrammingSession.Invalidate(Fact: TSessionFact);
begin
  FFacts := FFacts - DependentsOf(Fact) - [Fact];
  //A revoked premise also ends whatever was running on it.  Completed goes
  //too: it described the run that just lost its footing.
  EndActivity;
end;

procedure TProgrammingSession.EndActivity;
begin
  FWriting := False;
  FVerifying := False;
  FCompleted := False;
end;

function TProgrammingSession.Refuse(const Reason: string;
  out Refusal: string): boolean;
begin
  Refusal := Reason;
  Result := False;
end;

function TProgrammingSession.Apply(Event: TSessionEvent;
  out Refusal: string): boolean;
begin
  Refusal := '';
  Result := True;

  case Event of
    seProgrammerOpened:
      begin
        //Opening again is a fresh session, not a no-op: the device may be a
        //different one, and its rail is whatever the hardware powers up at.
        FFacts := [sfProgrammerOpen];
        EndActivity;
      end;

    seProgrammerClosed:
      begin
        FFacts := [];
        EndActivity;
      end;

    seRailConfigured:
      begin
        if not (sfProgrammerOpen in FFacts) then
          Exit(Refuse('the target rail cannot be configured before a ' +
                      'programmer is open', Refusal));
        Include(FFacts, sfRailConfigured);
      end;

    seRailChanged:
      begin
        if not (sfProgrammerOpen in FFacts) then
          Exit(Refuse('no programmer is open', Refusal));
        //The rail itself is still configured -- to the new level.  What dies
        //is everything concluded at the old one, chip detection included.
        Invalidate(sfChipDetected);
        Include(FFacts, sfRailConfigured);
      end;

    seChipDetected:
      begin
        if not (sfRailConfigured in FFacts) then
          Exit(Refuse('a chip cannot be detected before the target rail is ' +
                      'configured', Refusal));
        Include(FFacts, sfChipDetected);
      end;

    seChipLost:
      Invalidate(sfChipDetected);

    seImageLoaded:
      begin
        //An image may be loaded with nothing connected; that is ordinary
        //offline work.  What it must not do is keep a stale arming alive:
        //the preflight and the arming both spoke about the previous image.
        Invalidate(sfPreflightPassed);
        Include(FFacts, sfImageLoaded);
      end;

    seImageCleared:
      Invalidate(sfImageLoaded);

    sePreflightPassed:
      begin
        if not (sfChipDetected in FFacts) then
          Exit(Refuse('preflight has nothing to evaluate until a chip has ' +
                      'answered', Refusal));
        Include(FFacts, sfPreflightPassed);
      end;

    sePreflightFailed:
      Invalidate(sfPreflightPassed);

    seArmed:
      begin
        if not (sfPreflightPassed in FFacts) then
          Exit(Refuse('arming requires a passed electrical preflight',
                      Refusal));
        Include(FFacts, sfArmed);
      end;

    seDisarmed:
      Invalidate(sfArmed);

    seWriteStarted:
      begin
        if not (sfArmed in FFacts) then
          Exit(Refuse('a destructive operation cannot start before arming',
                      Refusal));
        FWriting := True;
        FVerifying := False;
        FCompleted := False;
      end;

    seVerifyStarted:
      begin
        //Verify runs both as the tail of a write and on its own.  On its own
        //it needs a chip and an image, nothing more: it writes nothing.
        if not (sfChipDetected in FFacts) then
          Exit(Refuse('verify needs a chip that has answered', Refusal));
        if not (sfImageLoaded in FFacts) then
          Exit(Refuse('verify needs a loaded image to compare against',
                      Refusal));
        FWriting := False;
        FVerifying := True;
        FCompleted := False;
      end;

    seOperationSucceeded:
      begin
        FWriting := False;
        FVerifying := False;
        FCompleted := True;
        //One arming, one destructive run.  The next unit in the socket has
        //to go through preflight and arming again.
        Exclude(FFacts, sfArmed);
      end;

    seOperationFailed:
      begin
        EndActivity;
        Exclude(FFacts, sfArmed);
      end;
  end;
end;

function TProgrammingSession.State: TSessionState;
begin
  if not (sfProgrammerOpen in FFacts) then Exit(ssDisconnected);
  if FWriting then Exit(ssWriting);
  if FVerifying then Exit(ssVerifying);
  if FCompleted then Exit(ssCompleted);
  if sfArmed in FFacts then Exit(ssArmed);
  if sfPreflightPassed in FFacts then Exit(ssPreflightPassed);
  if sfImageLoaded in FFacts then Exit(ssImageLoaded);
  if sfChipDetected in FFacts then Exit(ssChipDetected);
  if sfRailConfigured in FFacts then Exit(ssRailConfigured);
  Result := ssConnected;
end;

function TProgrammingSession.Holds(Fact: TSessionFact): boolean;
begin
  Result := Fact in FFacts;
end;

function TProgrammingSession.MayStart(Op: TSessionOperation): boolean;
begin
  Result := RequiredFacts(Op) <= FFacts;
end;

function TProgrammingSession.StartRefusal(Op: TSessionOperation): string;
var
  Needed: TSessionFacts;
  F: TSessionFact;
begin
  Result := '';
  Needed := RequiredFacts(Op);
  //Name the earliest missing fact, not all of them.  The first gap is the
  //one the operator has to close, and the rest usually follow from it.
  for F := Low(TSessionFact) to High(TSessionFact) do
    if (F in Needed) and not (F in FFacts) then
      Exit(SessionOperationName(Op) + ' refused: ' + MissingFactReason(F));
end;

end.
