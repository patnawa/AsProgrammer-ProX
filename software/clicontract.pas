unit clicontract;

// The machine-facing contract: what a caller that is not a human gets back.
//
// Until now both front ends answered every question with 0, 1 or 2. A script
// could tell success from failure and from a typo, and nothing else. Which
// means an automated caller that wanted to know *why* had to match substrings
// against log lines written for people -- lines that change wording whenever
// someone improves them, and that are translated.
//
// So the reasons a caller can act on differently get their own numbers:
//
//   nothing is plugged in            -> plug something in
//   the chip did not answer          -> check seating and pin 1
//   the wrong chip answered          -> check the part against the job
//   the rail was refused             -> fix the voltage selection
//   the connection was unstable      -> reseat, do not retry
//   the chip is locked               -> unlock, or accept it is read-only
//   the file is the wrong size       -> fix the file, not the hardware
//   verify failed                    -> the chip did not take the data
//   the programmer disappeared       -> USB fell out mid-operation
//
// These are the distinctions where the correct next action differs. Anything
// finer would be a taxonomy of internals, which is not something a caller
// should be coupled to.
//
// The JSON side follows the same rule: a stable, versioned object with
// snake_case keys that mean the same thing across releases. schema_version
// exists so a consumer can refuse a payload it does not understand rather
// than silently reading a renamed field as absent.
//
// No hardware access and no LCL unit, so both front ends and the tests share
// exactly one copy of these numbers.

{$mode objfpc}{$H+}
//TJsonObject keeps its buffer private and its methods with it, so no caller
//can append a fragment that is not valid JSON.  That needs advanced records.
{$modeswitch advancedrecords}

interface

uses
  SysUtils, operationmodel;

const
  // Bump when a key changes meaning or disappears. Adding a key is not a
  // breaking change and does not bump this.
  CLI_SCHEMA_VERSION = 1;

type
  TCLIOutcome = (
    coOK,
    // The catch-all. Anything that lands here and turns out to be common is
    // a candidate for its own code.
    coFailed,
    coUsage,
    coNoProgrammer,
    coProgrammerLost,
    coNoChip,
    coChipMismatch,
    coVoltageRefused,
    coUnstable,
    coChipLocked,
    coFileSizeMismatch,
    coVerifyFailed,
    coFileError,
    coCancelled
  );

// The process exit code. Kept explicit rather than Ord(): the numbers are a
// published interface, and reordering the enum must not renumber them.
function CLIExitCode(Outcome: TCLIOutcome): integer;

// The stable identifier for the "result" field. snake_case, never
// translated, never reworded.
function CLIOutcomeName(Outcome: TCLIOutcome): string;

// A one-line human explanation. This one may be reworded freely; nothing
// machine-facing depends on it.
function CLIOutcomeText(Outcome: TCLIOutcome): string;

// Maps the operation engine's own error taxonomy onto the contract.
//
// Codes that describe how the transport failed rather than what the operator
// should do next (oeTransport, oeTimeout, oeShortTransfer) deliberately all
// arrive as coUnstable: from outside, an intermittent cable and a timeout are
// the same instruction -- stop, reseat, do not retry into a chip that is half
// erased.
function OutcomeFromOperationError(Code: TOperationErrorCode): TCLIOutcome;

{ TJsonObject }

// A deliberately small JSON writer: flat objects of strings, integers,
// booleans and one nested array of strings. That is the whole shape of every
// payload this program emits, and a general JSON library would be a
// dependency bought for nothing.
type
  TJsonObject = record
  private
    FBody: string;
    procedure AddRaw(const Key, RawValue: string);
  public
    procedure Init;
    procedure AddString(const Key, Value: string);
    procedure AddInt(const Key: string; Value: int64);
    procedure AddBool(const Key: string; Value: boolean);
    // Emitted as JSON null, which is how "this hardware cannot tell you"
    // reaches a consumer. Never emit 0 for an unmeasured value: a consumer
    // reading 0 mV as a measurement is the exact failure the rail report
    // exists to prevent.
    procedure AddNull(const Key: string);
    procedure AddStrings(const Key: string; const Values: array of string);
    function Text: string;
  end;

function JsonEscapeText(const S: string): string;

// The most specific reason the current operation failed.
//
// This lives here, and not in opresult, because of the unit graph: cli.pas
// uses main, so main cannot use cli, and the gates that know *why* something
// was refused are all in main.  A neutral unit both can reach is the only
// place the fact fits.
//
// First writer wins, exactly like opresult.OpFail: the first cause is the
// real cause and everything after it is consequence.  A refused rail that
// then produces a failed read must be reported as a refused rail.
procedure ResetCLIOutcome;
procedure NoteCLIOutcome(Outcome: TCLIOutcome);
function CurrentCLIOutcome: TCLIOutcome;

implementation

var
  FOutcome: TCLIOutcome = coFailed;
  FOutcomeNoted: boolean = False;

procedure ResetCLIOutcome;
begin
  FOutcome := coFailed;
  FOutcomeNoted := False;
end;

procedure NoteCLIOutcome(Outcome: TCLIOutcome);
begin
  if FOutcomeNoted then Exit;
  FOutcome := Outcome;
  FOutcomeNoted := True;
end;

function CurrentCLIOutcome: TCLIOutcome;
begin
  Result := FOutcome;
end;

function CLIExitCode(Outcome: TCLIOutcome): integer;
begin
  case Outcome of
    coOK:               Result := 0;
    coFailed:           Result := 1;
    coUsage:            Result := 2;
    coNoProgrammer:     Result := 3;
    coProgrammerLost:   Result := 4;
    coNoChip:           Result := 5;
    coChipMismatch:     Result := 6;
    coVoltageRefused:   Result := 7;
    coUnstable:         Result := 8;
    coChipLocked:       Result := 9;
    coFileSizeMismatch: Result := 10;
    coVerifyFailed:     Result := 11;
    coFileError:        Result := 12;
    coCancelled:        Result := 13;
  else
    Result := 1;
  end;
end;

function CLIOutcomeName(Outcome: TCLIOutcome): string;
begin
  case Outcome of
    coOK:               Result := 'ok';
    coFailed:           Result := 'failed';
    coUsage:            Result := 'usage';
    coNoProgrammer:     Result := 'no_programmer';
    coProgrammerLost:   Result := 'programmer_lost';
    coNoChip:           Result := 'no_chip';
    coChipMismatch:     Result := 'chip_mismatch';
    coVoltageRefused:   Result := 'voltage_refused';
    coUnstable:         Result := 'connection_unstable';
    coChipLocked:       Result := 'chip_locked';
    coFileSizeMismatch: Result := 'file_size_mismatch';
    coVerifyFailed:     Result := 'verify_failed';
    coFileError:        Result := 'file_error';
    coCancelled:        Result := 'cancelled';
  end;
end;

function CLIOutcomeText(Outcome: TCLIOutcome): string;
begin
  case Outcome of
    coOK:
      Result := 'the operation completed';
    coFailed:
      Result := 'the operation failed';
    coUsage:
      Result := 'the command line was not understood';
    coNoProgrammer:
      Result := 'no programmer was found';
    coProgrammerLost:
      Result := 'the programmer disappeared during the operation';
    coNoChip:
      Result := 'no chip answered on the bus';
    coChipMismatch:
      Result := 'the chip that answered is not the expected one';
    coVoltageRefused:
      Result := 'the electrical preflight refused the target rail';
    coUnstable:
      Result := 'the connection is not stable enough to trust';
    coChipLocked:
      Result := 'the chip is write protected';
    coFileSizeMismatch:
      Result := 'the file does not match the chip capacity';
    coVerifyFailed:
      Result := 'the chip contents do not match the image';
    coFileError:
      Result := 'a local file could not be read or written';
    coCancelled:
      Result := 'the operation was cancelled';
  end;
end;

function OutcomeFromOperationError(Code: TOperationErrorCode): TCLIOutcome;
begin
  case Code of
    oeNone:
      Result := coOK;
    oeInvalidRequest, oeInvalidPlan:
      Result := coUsage;
    oeOpenFailed, oeDeviceBusy:
      Result := coNoProgrammer;
    oeDisconnected:
      Result := coProgrammerLost;
    oeIdentityMismatch:
      Result := coChipMismatch;
    //From outside the program these are one instruction: stop and reseat.
    //Retrying a timeout into a half-erased chip is how a recoverable bad
    //contact becomes an unrecoverable one.
    oeTransport, oeTimeout, oeShortTransfer, oeContactUnstable,
    oeBackupUntrusted, oeBusInitFailed:
      Result := coUnstable;
    oeProtected, oeWriteEnableRejected, oeEraseRejected, oeProgramRejected:
      Result := coChipLocked;
    oeVerifyMismatch:
      Result := coVerifyFailed;
    oeCancelled:
      Result := coCancelled;
  else
    Result := coFailed;
  end;
end;

function JsonEscapeText(const S: string): string;
var
  i: integer;
  C: char;
begin
  Result := '';
  for i := 1 to Length(S) do
  begin
    C := S[i];
    case C of
      '"':  Result := Result + '\"';
      '\':  Result := Result + '\\';
      #8:   Result := Result + '\b';
      #9:   Result := Result + '\t';
      #10:  Result := Result + '\n';
      #12:  Result := Result + '\f';
      #13:  Result := Result + '\r';
    else
      //Everything below a space must be escaped or the object is invalid
      //JSON.  Bytes above 127 are passed through: the program's strings are
      //UTF-8 and JSON carries UTF-8 directly.
      if C < ' ' then
        Result := Result + '\u' + LowerCase(IntToHex(Ord(C), 4))
      else
        Result := Result + C;
    end;
  end;
end;

{ TJsonObject }

procedure TJsonObject.Init;
begin
  FBody := '';
end;

procedure TJsonObject.AddRaw(const Key, RawValue: string);
begin
  if FBody <> '' then FBody := FBody + ',';
  FBody := FBody + '"' + JsonEscapeText(Key) + '":' + RawValue;
end;

procedure TJsonObject.AddString(const Key, Value: string);
begin
  AddRaw(Key, '"' + JsonEscapeText(Value) + '"');
end;

procedure TJsonObject.AddInt(const Key: string; Value: int64);
begin
  AddRaw(Key, IntToStr(Value));
end;

procedure TJsonObject.AddBool(const Key: string; Value: boolean);
begin
  if Value then AddRaw(Key, 'true') else AddRaw(Key, 'false');
end;

procedure TJsonObject.AddNull(const Key: string);
begin
  AddRaw(Key, 'null');
end;

procedure TJsonObject.AddStrings(const Key: string;
  const Values: array of string);
var
  i: integer;
  Items: string;
begin
  Items := '';
  for i := 0 to High(Values) do
  begin
    if i > 0 then Items := Items + ',';
    Items := Items + '"' + JsonEscapeText(Values[i]) + '"';
  end;
  AddRaw(Key, '[' + Items + ']');
end;

function TJsonObject.Text: string;
begin
  Result := '{' + FBody + '}';
end;

end.
