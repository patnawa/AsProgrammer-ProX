unit quadpolicy;

// Whether a quad read may be used, given that setting it up is not allowed.
//
// Every read this program does is single-bit. The CH347 and the FT232H both
// clock four data lines, and a 16 MiB part read four bits at a time is the
// difference between a coffee and a glance. So the speed is there for the
// taking -- except for one thing.
//
// Quad mode needs the QE bit set in a status register, and QE is
// *non-volatile on most parts*. Setting it is a permanent modification to
// somebody else's chip, made for the programmer's convenience rather than at
// the operator's request, and this program exists on the premise that it does
// not do that. Read-only safe mode forbids status-register writes outright,
// and a board that boots its flash in single-bit mode can be made
// unbootable by having QE turned on behind its back.
//
// So the rule here is narrow and absolute: **use quad if it is already on,
// never turn it on.** A chip that arrives with QE set gets read four times
// faster for free; a chip that does not is read exactly as it is today. There
// is no switch to change that, because a switch would be the feature.
//
// The second thing this unit refuses is continuous-read mode. The 1-4-4 and
// 1-1-4 encodings can require "mode clocks" -- a byte sent after the address
// that keeps the chip in read mode so the next transfer can skip the opcode.
// Get it wrong and the part stays in that mode, and the next command it
// receives is interpreted as an address instead. Recovering means a reset the
// programmer may not be able to issue. A speed feature is not worth that, so
// any declared mode requiring non-zero mode clocks is refused and said so.
//
// Everything decided here comes from the chip's own SFDP tables plus one
// status-register byte the caller has already read. The reason it must come
// from SFDP and not from the manufacturer byte is that QE lives in different
// places per vendor: Winbond puts it at bit 1 of status register 2, Macronix
// at bit 6 of status register 1 -- which is the bit the Winbond layout calls
// SEC. Reading the wrong table does not give a wrong answer, it gives a
// plausible wrong answer.
//
// No hardware access and no LCL unit is used here.

{$mode objfpc}{$H+}

interface

uses
  SysUtils, sfdp;

type
  TQuadLines = array of string;

  TQuadVerdict = (
    qvSingleBit,        // read one bit at a time, as always
    qvQuadAvailable     // the chip is already in a state where quad works
  );

  // Why the verdict is what it is. Every refusal is a distinct reason,
  // because they call for different things from the operator: "your chip
  // does not have QE set" is a fact about that chip, while "this chip
  // requires mode clocks" is a fact about what this program will not do.
  TQuadReason = (
    qrNoSFDP,               // nothing was read from the part
    qrNotDeclared,          // the chip declares no quad read mode
    qrNoParameters,         // declared, but the table is too short to say how
    qrOpcodeUnusable,       // the declared opcode is 00 or FF
    qrModeClocksRequired,   // continuous-read mode; refused, see above
    qrQENotLocatable,       // SFDP does not say where the QE bit lives
    qrQEBitNotRead,         // the caller did not supply the register
    qrQEBitClear,           // QE is off, and this program will not turn it on
    qrProgrammerCannot,     // the chip is ready; nothing here can drive it
    qrQEAlreadySet,         // the good case, by a bit that is set
    qrQEAlwaysOn            // the good case, on a part with no QE bit at all
  );

  TQuadPlan = record
    Verdict: TQuadVerdict;
    Reason: TQuadReason;

    // Only meaningful when Verdict is qvQuadAvailable.
    Opcode: byte;
    DummyCycles: byte;

    // Which status register byte the caller has to read, and which bit in it
    // to test, before calling again. Zero when the question does not arise
    // (a part with no QE bit) or cannot be answered.
    QEReadOpcode: byte;
    QEBitIndex: byte;

    // One sentence for the log. Reads as an explanation, not an apology: a
    // single-bit read is the normal case and is not a failure.
    Note: string;
  end;

// What the caller needs to read before a plan can be decided.
//
// Split out so that a caller can do the register read only when it is going
// to matter. Returns False when there is no QE bit to look at, which is a
// perfectly good outcome and not an error.
function QuadStatusRegisterNeeded(const Info: TSFDPInfo;
  out ReadOpcode: byte; out BitIndex: byte): boolean;

// The decision.
//
// StatusRegisterKnown says whether StatusRegister holds a byte the caller
// actually read from the part. False is not the same as a byte of zero: an
// unread register must never be treated as a QE bit that happens to be clear,
// because the two lead to the same behaviour today but to opposite ones if
// this policy is ever loosened.
//
// ProgrammerSupportsQuad is, today, False for every backend this program has
// -- see the note above TProgrammerMemoryCapabilities.SupportsQuadSPI. It is
// checked last, so that a chip which is ready and waiting is reported as
// exactly that: the operator learns their part would go four times faster on
// hardware that could drive it, rather than being told nothing.
function PlanQuadRead(SFDPValid: boolean; const Info: TSFDPInfo;
  StatusRegisterKnown: boolean; StatusRegister: byte;
  ProgrammerSupportsQuad: boolean): TQuadPlan;

// How many times faster a quad read is than a single-bit one, for the same
// clock, accounting for the opcode and address phases still being single-bit
// and for the dummy cycles quad requires.
//
// It exists so the log can say something true rather than "4x faster". On a
// short read the overhead dominates and the answer is nowhere near four.
function QuadSpeedupPercent(const Plan: TQuadPlan; AddressBytes: byte;
  TransferBytes: cardinal): integer;

function QuadReasonText(Reason: TQuadReason): string;
function QuadPlanLines(const Plan: TQuadPlan): TQuadLines;

implementation

function QuadReasonText(Reason: TQuadReason): string;
begin
  case Reason of
    qrNoSFDP:
      Result := 'the chip has no readable SFDP table';
    qrNotDeclared:
      Result := 'the chip declares no quad read mode';
    qrNoParameters:
      Result := 'the chip declares a quad read mode but its SFDP table is ' +
                'too short to say how to issue it';
    qrOpcodeUnusable:
      Result := 'the declared quad read opcode is 00 or FF, which is not a ' +
                'command';
    qrModeClocksRequired:
      Result := 'the declared quad read needs continuous-read mode clocks, ' +
                'which this program does not issue: leaving a chip in that ' +
                'mode makes it read the next command as an address';
    qrQENotLocatable:
      Result := 'SFDP does not say which register holds the quad-enable bit';
    qrQEBitNotRead:
      Result := 'the quad-enable bit has not been read from the chip';
    qrQEBitClear:
      Result := 'the chip''s quad-enable bit is clear, and this program does ' +
                'not set it: that is a permanent change to the chip, made ' +
                'for the programmer''s convenience';
    qrProgrammerCannot:
      Result := 'the chip is ready for a quad read, but this programmer ' +
                'drives only one data line';
    qrQEAlreadySet:
      Result := 'the chip''s quad-enable bit is already set';
    qrQEAlwaysOn:
      Result := 'the chip has no quad-enable bit; all four lines are always ' +
                'available';
  else
    Result := '';
  end;
end;

function QuadStatusRegisterNeeded(const Info: TSFDPInfo;
  out ReadOpcode: byte; out BitIndex: byte): boolean;
begin
  ReadOpcode := 0;
  BitIndex := 0;
  //A part with no QE bit needs no register read. Reporting False here rather
  //than an error is the difference between "nothing to check" and "cannot
  //check", and the caller acts differently on each.
  if SFDPQuadAlwaysEnabled(Info) then Exit(False);
  Result := SFDPQuadEnableBit(Info, ReadOpcode, BitIndex);
end;

function PlanQuadRead(SFDPValid: boolean; const Info: TSFDPInfo;
  StatusRegisterKnown: boolean; StatusRegister: byte;
  ProgrammerSupportsQuad: boolean): TQuadPlan;
var
  Opcode, Dummy, ModeClocks: byte;
  Declared: boolean;

  //The chip is ready. Whether anything can actually clock four lines is a
  //separate question, asked last so that the answer names the real obstacle.
  procedure ChipIsReady(Because: TQuadReason);
  begin
    if ProgrammerSupportsQuad then
    begin
      Result.Verdict := qvQuadAvailable;
      Result.Reason := Because;
      Result.Note := QuadReasonText(Because);
      Exit;
    end;
    Result.Verdict := qvSingleBit;
    Result.Reason := qrProgrammerCannot;
    //Both halves, because the operator's next move depends on both: the chip
    //is fine, and different hardware would make the read four times faster.
    Result.Note := QuadReasonText(qrProgrammerCannot) + ' (' +
                   QuadReasonText(Because) + ')';
    Result.Opcode := 0;
    Result.DummyCycles := 0;
  end;

begin
  Result := Default(TQuadPlan);
  Result.Verdict := qvSingleBit;

  if (not SFDPValid) or (not Info.Valid) then
  begin
    Result.Reason := qrNoSFDP;
    Result.Note := QuadReasonText(Result.Reason);
    Exit;
  end;

  //--- which encoding, if any ---
  //
  //1-1-4 is preferred over 1-4-4 even though 1-4-4 is marginally faster.
  //1-1-4 puts only the data on four lines; 1-4-4 puts the address there too,
  //which is where the mode-bit machinery lives on most parts and where a
  //misconfigured dummy count corrupts the address rather than the data. A
  //corrupted address in a read is a read of somewhere else that looks
  //entirely plausible.
  Declared := False;
  Opcode := 0; Dummy := 0; ModeClocks := 0;

  if Info.Supports114 and Info.HasQuadInfo then
  begin
    Declared := True;
    Opcode := Info.Read114Opcode;
    Dummy := Info.Read114DummyCycles;
    ModeClocks := Info.Read114ModeClocks;
  end
  else if Info.Supports144 and Info.HasQuadInfo then
  begin
    Declared := True;
    Opcode := Info.Read144Opcode;
    Dummy := Info.Read144DummyCycles;
    ModeClocks := Info.Read144ModeClocks;
  end;

  if (not Declared) and (Info.Supports114 or Info.Supports144) then
  begin
    //The chip says it can, and the table stops before saying how. Guessing
    //the usual 6Bh with eight dummy cycles would be right most of the time,
    //and wrong silently the rest: too few dummy cycles shifts every byte.
    Result.Reason := qrNoParameters;
    Result.Note := QuadReasonText(Result.Reason);
    Exit;
  end;
  if not Declared then
  begin
    Result.Reason := qrNotDeclared;
    Result.Note := QuadReasonText(Result.Reason);
    Exit;
  end;

  if (Opcode = $00) or (Opcode = $FF) then
  begin
    Result.Reason := qrOpcodeUnusable;
    Result.Note := QuadReasonText(Result.Reason);
    Exit;
  end;

  if ModeClocks <> 0 then
  begin
    //Refused on purpose, and this is the one refusal that is about what the
    //program will do rather than about the chip. Continuous-read mode is
    //recoverable only by a reset this program may have no way to issue.
    Result.Reason := qrModeClocksRequired;
    Result.Note := QuadReasonText(Result.Reason);
    Exit;
  end;

  Result.Opcode := Opcode;
  Result.DummyCycles := Dummy;

  //--- is it already on ---

  if SFDPQuadAlwaysEnabled(Info) then
  begin
    ChipIsReady(qrQEAlwaysOn);
    Exit;
  end;

  if not SFDPQuadEnableBit(Info, Result.QEReadOpcode, Result.QEBitIndex) then
  begin
    Result.Opcode := 0;
    Result.DummyCycles := 0;
    Result.Reason := qrQENotLocatable;
    Result.Note := QuadReasonText(Result.Reason);
    Exit;
  end;

  if not StatusRegisterKnown then
  begin
    //Not the same as a register full of zeroes. Today both end in a
    //single-bit read, but they are different facts, and collapsing them is
    //how "we never checked" turns into "we checked and it was off" in a log.
    Result.Opcode := 0;
    Result.DummyCycles := 0;
    Result.Reason := qrQEBitNotRead;
    Result.Note := QuadReasonText(Result.Reason);
    Exit;
  end;

  if (StatusRegister and (byte(1) shl Result.QEBitIndex)) = 0 then
  begin
    Result.Opcode := 0;
    Result.DummyCycles := 0;
    Result.Reason := qrQEBitClear;
    Result.Note := QuadReasonText(Result.Reason);
    Exit;
  end;

  ChipIsReady(qrQEAlreadySet);
end;

function QuadSpeedupPercent(const Plan: TQuadPlan; AddressBytes: byte;
  TransferBytes: cardinal): integer;
var
  SingleClocks, QuadClocks: QWord;
begin
  //Nothing to compare when quad is not on the table.
  Result := 0;
  if Plan.Verdict <> qvQuadAvailable then Exit;
  if (TransferBytes = 0) or (AddressBytes = 0) then Exit;

  //Single-bit fast read: opcode, address and 8 dummy cycles all on one line,
  //then eight clocks per byte.
  SingleClocks := QWord(1 + AddressBytes) * 8 + 8 + QWord(TransferBytes) * 8;

  //1-1-4: opcode and address still single-bit, the declared dummy cycles,
  //then two clocks per byte.
  QuadClocks := QWord(1 + AddressBytes) * 8 + QWord(Plan.DummyCycles) +
                QWord(TransferBytes) * 2;

  if QuadClocks = 0 then Exit;
  //A percentage rather than a multiplier, because on a three-byte JEDEC ID
  //read the overhead dominates and a multiplier of "1.1x" reads like a bug
  //while "11% fewer clocks" reads like the truth.
  if SingleClocks <= QuadClocks then Exit;
  Result := integer(((SingleClocks - QuadClocks) * 100) div SingleClocks);
end;

function QuadPlanLines(const Plan: TQuadPlan): TQuadLines;

  procedure Add(const Line: string);
  var
    N: integer;
  begin
    N := Length(Result);
    SetLength(Result, N + 1);
    Result[N] := Line;
  end;

begin
  Result := nil;
  if Plan.Verdict = qvQuadAvailable then
    Add(Format('Quad read available: opcode %.2X, %d dummy cycles -- %s',
               [Plan.Opcode, Plan.DummyCycles, Plan.Note]))
  else
  begin
    //Phrased as the normal case, because it is. Single-bit reads are what
    //this program has always done and they are not a degraded mode.
    Add('Reading one bit at a time: ' + Plan.Note + '.');
    if Plan.Reason = qrQEBitClear then
      Add(Format('  The quad-enable bit is bit %d of the register read with ' +
                 '%.2Xh. Setting it is a permanent change to this chip; if ' +
                 'you want it set, set it deliberately and elsewhere.',
                 [Plan.QEBitIndex, Plan.QEReadOpcode]));
  end;
end;

end.
