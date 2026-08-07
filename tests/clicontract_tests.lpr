program clicontract_tests;

// The published interface to anything that is not a person.
//
// These assertions are mostly about stability rather than logic. Exit codes
// and JSON key names are things other people write scripts against, so the
// tests exist to make renaming one a deliberate act rather than a side effect
// of tidying an enum.

{$mode objfpc}{$H+}

uses
  SysUtils, operationmodel, clicontract;

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

procedure CheckInt(const Name: string; Expected, Actual: integer);
begin
  Inc(Assertions);
  if Expected <> Actual then
  begin
    Inc(Failures);
    WriteLn('FAIL: ', Name, ' (expected ', Expected, ', got ', Actual, ')');
  end;
end;

procedure TestExitCodesArePinned;
var
  O: TCLIOutcome;
  Seen: array[0..63] of boolean;
  Code: integer;
begin
  //The three that already existed keep their meaning, or every script that
  //checks "exit code 2 means I typed it wrong" breaks silently.
  CheckInt('success is still 0', 0, CLIExitCode(coOK));
  CheckInt('generic failure is still 1', 1, CLIExitCode(coFailed));
  CheckInt('a usage error is still 2', 2, CLIExitCode(coUsage));

  //Everything else is a published number.
  CheckInt('no programmer', 3, CLIExitCode(coNoProgrammer));
  CheckInt('programmer lost', 4, CLIExitCode(coProgrammerLost));
  CheckInt('no chip', 5, CLIExitCode(coNoChip));
  CheckInt('chip mismatch', 6, CLIExitCode(coChipMismatch));
  CheckInt('voltage refused', 7, CLIExitCode(coVoltageRefused));
  CheckInt('connection unstable', 8, CLIExitCode(coUnstable));
  CheckInt('chip locked', 9, CLIExitCode(coChipLocked));
  CheckInt('file size mismatch', 10, CLIExitCode(coFileSizeMismatch));
  CheckInt('verify failed', 11, CLIExitCode(coVerifyFailed));
  CheckInt('file error', 12, CLIExitCode(coFileError));
  CheckInt('cancelled', 13, CLIExitCode(coCancelled));

  //Two outcomes sharing a number would make them indistinguishable to the
  //only consumer that matters.
  FillChar(Seen, SizeOf(Seen), 0);
  for O := Low(TCLIOutcome) to High(TCLIOutcome) do
  begin
    Code := CLIExitCode(O);
    Check('every exit code is in range', (Code >= 0) and (Code <= 63));
    Check('no two outcomes share an exit code', not Seen[Code]);
    Seen[Code] := True;
  end;

  //Every outcome must have a name and a sentence; an empty one reaches a
  //user as a blank line where the reason should be.
  for O := Low(TCLIOutcome) to High(TCLIOutcome) do
  begin
    Check('every outcome has a stable name', CLIOutcomeName(O) <> '');
    Check('every outcome has an explanation', CLIOutcomeText(O) <> '');
    Check('names are snake_case, not sentences',
      Pos(' ', CLIOutcomeName(O)) = 0);
  end;
end;

procedure TestEngineErrorsMapToActions;
var
  E: TOperationErrorCode;
begin
  //The mapping's job is to answer "what should the caller do differently",
  //not to mirror the engine's internals.
  Check('no error is success',
    OutcomeFromOperationError(oeNone) = coOK);
  Check('a device that will not open is a missing programmer',
    OutcomeFromOperationError(oeOpenFailed) = coNoProgrammer);
  Check('a disconnect during work is its own outcome',
    OutcomeFromOperationError(oeDisconnected) = coProgrammerLost);
  Check('the wrong chip is a mismatch',
    OutcomeFromOperationError(oeIdentityMismatch) = coChipMismatch);
  Check('a verify mismatch is a verify failure',
    OutcomeFromOperationError(oeVerifyMismatch) = coVerifyFailed);

  //Protection has four engine-level shapes and one operator-level answer.
  Check('a protected chip is locked',
    OutcomeFromOperationError(oeProtected) = coChipLocked);
  Check('a refused write enable is locked',
    OutcomeFromOperationError(oeWriteEnableRejected) = coChipLocked);
  Check('a refused erase is locked',
    OutcomeFromOperationError(oeEraseRejected) = coChipLocked);
  Check('a refused program is locked',
    OutcomeFromOperationError(oeProgramRejected) = coChipLocked);

  //A timeout and a bad clip are the same instruction from outside: stop and
  //reseat.  Retrying either into a half-erased chip is how a recoverable
  //fault becomes a dead part.
  Check('a timeout is a stability problem',
    OutcomeFromOperationError(oeTimeout) = coUnstable);
  Check('a short transfer is a stability problem',
    OutcomeFromOperationError(oeShortTransfer) = coUnstable);
  Check('an untrusted backup is a stability problem',
    OutcomeFromOperationError(oeBackupUntrusted) = coUnstable);
  Check('an unstable contact is a stability problem',
    OutcomeFromOperationError(oeContactUnstable) = coUnstable);

  Check('a cancellation is not a failure to diagnose',
    OutcomeFromOperationError(oeCancelled) = coCancelled);

  //Nothing may map to success by accident; a new engine error code landing
  //in the catch-all is acceptable, landing on coOK is not.
  for E := Low(TOperationErrorCode) to High(TOperationErrorCode) do
    if E <> oeNone then
      Check('only oeNone maps to success',
        OutcomeFromOperationError(E) <> coOK);
end;

procedure TestJsonWriter;
var
  J: TJsonObject;
begin
  J.Init;
  CheckText('an empty object is still valid JSON', '{}', J.Text);

  J.Init;
  J.AddInt('schema_version', CLI_SCHEMA_VERSION);
  J.AddString('programmer', 'CH347T');
  J.AddString('interface', 'SPI');
  J.AddString('chip', 'W25Q64FW');
  J.AddString('jedec_id', 'EF6017');
  J.AddInt('requested_mv', 1800);
  J.AddNull('measured_mv');
  J.AddInt('clock_hz', 15000000);
  J.AddBool('connection_stable', True);
  J.AddString('result', CLIOutcomeName(coOK));
  CheckText('the payload is built in order',
    '{"schema_version":1,"programmer":"CH347T","interface":"SPI",' +
    '"chip":"W25Q64FW","jedec_id":"EF6017","requested_mv":1800,' +
    '"measured_mv":null,"clock_hz":15000000,"connection_stable":true,' +
    '"result":"ok"}',
    J.Text);

  //An unmeasured value must reach the consumer as null.  Emitting 0 here is
  //the same mistake as printing "0.0 V" to a person: it reads as a
  //measurement of zero rather than as the absence of one.
  J.Init;
  J.AddNull('measured_mv');
  CheckText('an unmeasurable value is null, never zero',
    '{"measured_mv":null}', J.Text);

  J.Init;
  J.AddStrings('notes', ['first', 'second']);
  CheckText('string arrays nest correctly',
    '{"notes":["first","second"]}', J.Text);
  J.Init;
  J.AddStrings('notes', []);
  CheckText('an empty array is an empty array', '{"notes":[]}', J.Text);
end;

procedure TestJsonEscaping;
var
  J: TJsonObject;
begin
  //Error text reaches these fields verbatim, and error text contains file
  //paths.  An unescaped backslash turns a valid payload into a parse error
  //at the far end, which a script reports as "the programmer crashed".
  //Pascal string literals have no escapes, so the expected value below is
  //literally two backslashes per input backslash -- which is what JSON wants.
  CheckText('backslashes are escaped', 'C:\\temp\\dump.bin',
            JsonEscapeText('C:\temp\dump.bin'));
  CheckText('quotes are escaped', 'he said \"no\"',
            JsonEscapeText('he said "no"'));
  CheckText('newlines are escaped', 'one\nline\ttab',
            JsonEscapeText('one' + #10 + 'line' + #9 + 'tab'));
  CheckText('carriage returns are escaped', 'a\rb',
            JsonEscapeText('a' + #13 + 'b'));
  //Anything else below a space must become \u00XX or the object is invalid.
  CheckText('other control characters become escapes', 'a\u0001b',
            JsonEscapeText('a' + #1 + 'b'));
  //UTF-8 passes through: JSON carries it directly, and the program's
  //strings are already UTF-8.
  CheckText('utf-8 is not mangled', 'แรงดัน', JsonEscapeText('แรงดัน'));

  J.Init;
  J.AddString('error', 'cannot open "C:\x"' + #10 + 'twice');
  CheckText('escaping survives the writer',
    '{"error":"cannot open \"C:\\x\"\ntwice"}', J.Text);
end;

procedure TestFirstCauseWins;
begin
  //A refused rail that then produces a failed read is a refused rail. If the
  //last writer won, every specific reason would be overwritten by the
  //generic failure it caused a moment later.
  ResetCLIOutcome;
  Check('the default before anything is noted is a plain failure',
    CurrentCLIOutcome = coFailed);

  NoteCLIOutcome(coVoltageRefused);
  NoteCLIOutcome(coFailed);
  NoteCLIOutcome(coVerifyFailed);
  Check('the first cause survives its consequences',
    CurrentCLIOutcome = coVoltageRefused);

  ResetCLIOutcome;
  NoteCLIOutcome(coUnstable);
  Check('a reset lets the next operation speak for itself',
    CurrentCLIOutcome = coUnstable);
end;

begin
  TestExitCodesArePinned;
  TestFirstCauseWins;
  TestEngineErrorsMapToActions;
  TestJsonWriter;
  TestJsonEscaping;
  WriteLn(Assertions, ' assertions, ', Failures, ' failures');
  if Failures <> 0 then Halt(1);
  WriteLn('ALL PASSED');
end.
