program quadpolicy_tests;

// Using a quad read when it is already available, and never making it so.
//
// The assertion this suite exists for is the one that looks like a missing
// feature: a chip whose quad-enable bit is clear must be read one bit at a
// time, and there must be no argument, flag or code path that changes that.
// Setting QE is a permanent modification to somebody else's chip made for the
// programmer's convenience, and a board that boots its flash in single-bit
// mode can be made unbootable by it.
//
// The other refusal worth reading is continuous-read mode. It is refused
// because getting the mode byte wrong leaves the part interpreting the next
// command as an address, and the way out is a reset the programmer may not be
// able to issue.

{$mode objfpc}{$H+}

uses
  SysUtils, spi25, sfdp, quadpolicy, basehw;

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

// A Winbond-style part: 1-1-4 with 6Bh and eight dummy cycles, QE at bit 1 of
// status register 2, read with 35h.
function WinbondLike: TSFDPInfo;
begin
  Result := Default(TSFDPInfo);
  Result.Valid := True;
  Result.Density := 8 * 1024 * 1024;
  Result.PageSize := 256;
  Result.AddrBytes := 3;
  Result.HasQuadInfo := True;
  Result.Supports114 := True;
  Result.Read114Opcode := $6B;
  Result.Read114DummyCycles := 8;
  Result.Read114ModeClocks := 0;
  Result.HasQER := True;
  Result.QERCode := 1;
end;

// Shorthand for the hypothetical programmer that can drive four lines. No
// backend in this program can, which is what TestNoBackendCanActuallyDoThis
// pins; the rest of the suite is about the chip-side rules, which have to be
// right for the day one can.
function ChipPlan(const Info: TSFDPInfo; SRKnown: boolean; SR: byte): TQuadPlan;
begin
  Result := PlanQuadRead(True, Info, SRKnown, SR, True);
end;

function LinesContain(const Lines: TQuadLines; const Needle: string): boolean;
var
  i: integer;
begin
  for i := 0 to High(Lines) do
    if Pos(Needle, Lines[i]) > 0 then Exit(True);
  Result := False;
end;

// -------------------------------------------------------- the good cases

procedure TestQEAlreadySetIsTakenForFree;
var
  Plan: TQuadPlan;
begin
  WriteLn('A chip that arrives with quad enabled is read four bits at a time');

  //Bit 1 of SR2 set: the part is already in quad mode because whatever wrote
  //it last put it there. Using it costs nothing and changes nothing.
  Plan := ChipPlan(WinbondLike, True, %00000010);
  Check('quad is available', Plan.Verdict = qvQuadAvailable);
  Check('because the bit was already set', Plan.Reason = qrQEAlreadySet);
  Check('with the declared opcode', Plan.Opcode = $6B);
  Check('and the declared dummy cycles', Plan.DummyCycles = 8);
  Check('the log says so', LinesContain(QuadPlanLines(Plan), 'Quad read available'));
end;

procedure TestAPartWithNoQEBitNeedsNothingRead;
var
  Info: TSFDPInfo;
  Plan: TQuadPlan;
  Op, Bit_: byte;
begin
  WriteLn('A part with no quad-enable bit is always available');
  Info := WinbondLike;
  Info.QERCode := 0;   //JESD216: no QE bit, all four lines always usable

  //"Nothing to check" is not the same as "cannot check", and the caller
  //behaves differently on each.
  Check('no status register needs reading',
        not QuadStatusRegisterNeeded(Info, Op, Bit_));

  Plan := ChipPlan(Info, False, 0);
  Check('quad is available without reading anything',
        Plan.Verdict = qvQuadAvailable);
  Check('and the reason says why', Plan.Reason = qrQEAlwaysOn);
end;

// ------------------------------------------- the refusal that is the point

procedure TestAClearQEBitIsNeverSet;
var
  Plan: TQuadPlan;
  Lines: TQuadLines;
begin
  WriteLn('A clear quad-enable bit means a single-bit read, and nothing else');

  //QE is non-volatile on most parts. Setting it is a permanent change to
  //somebody else's chip, made for our convenience rather than at their
  //request -- and a board that boots its flash single-bit can be made
  //unbootable by it. There is deliberately no argument to this function that
  //changes the outcome.
  Plan := ChipPlan(WinbondLike, True, %00000000);
  Check('the read stays single-bit', Plan.Verdict = qvSingleBit);
  Check('and it says the bit is clear', Plan.Reason = qrQEBitClear);
  //No opcode is offered, so a caller that ignored the verdict and used the
  //fields anyway would send opcode 00 rather than a working quad read.
  Check('no opcode is offered', Plan.Opcode = 0);
  Check('and no dummy cycle count', Plan.DummyCycles = 0);

  Lines := QuadPlanLines(Plan);
  //The operator is told where the bit is, so they can set it themselves and
  //on purpose if that is what they want.
  Check('the log names the bit', LinesContain(Lines, 'bit 1'));
  Check('and the register to read it from', LinesContain(Lines, '35h'));
  Check('and says setting it is permanent',
        LinesContain(Lines, 'permanent change'));
  //And it does not read as a fault. A single-bit read is what this program
  //has always done.
  Check('a single-bit read is not reported as a failure',
        LinesContain(Lines, 'Reading one bit at a time'));
end;

procedure TestModeClocksAreRefused;
var
  Info: TSFDPInfo;
  Plan: TQuadPlan;
begin
  WriteLn('A quad read needing continuous-read mode clocks is refused');

  //Get the mode byte wrong and the part stays in continuous read, where the
  //next command it receives is taken as an address. Recovering means a reset
  //this program may have no way to issue. Not worth a faster read.
  Info := WinbondLike;
  Info.Read114ModeClocks := 2;

  Plan := ChipPlan(Info, True, %00000010);
  Check('quad is refused even with QE set', Plan.Verdict = qvSingleBit);
  Check('and the reason is the mode clocks',
        Plan.Reason = qrModeClocksRequired);
  Check('and it explains the consequence',
        Pos('next command as an address', Plan.Note) > 0);
end;

// ----------------------------------------------------- the other refusals

procedure TestPreferences;
var
  Info: TSFDPInfo;
  Plan: TQuadPlan;
begin
  WriteLn('1-1-4 is preferred to 1-4-4 where both are declared');

  //1-4-4 is marginally faster and puts the address on four lines too, which
  //is where a miscounted dummy phase corrupts the address rather than the
  //data. A read of somewhere else looks entirely plausible.
  Info := WinbondLike;
  Info.Supports144 := True;
  Info.Read144Opcode := $EB;
  Info.Read144DummyCycles := 6;

  Plan := ChipPlan(Info, True, %00000010);
  Check('the 1-1-4 opcode is chosen', Plan.Opcode = $6B);

  //With only 1-4-4 declared, and no mode clocks, it is used.
  Info.Supports114 := False;
  Plan := ChipPlan(Info, True, %00000010);
  Check('1-4-4 is used when it is the only one', Plan.Opcode = $EB);
  Check('with its own dummy count', Plan.DummyCycles = 6);
end;

procedure TestEveryWayQuadIsUnavailable;
var
  Info: TSFDPInfo;
  Plan: TQuadPlan;
begin
  WriteLn('Every way a quad read can be unavailable is a distinct answer');

  Plan := PlanQuadRead(False, WinbondLike, True, $FF, True);
  Check('no SFDP at all', Plan.Reason = qrNoSFDP);

  Info := WinbondLike;
  Info.Supports114 := False;
  Info.Supports144 := False;
  Plan := ChipPlan(Info, True, $FF);
  Check('no quad mode declared', Plan.Reason = qrNotDeclared);

  //Declared, but the table stops before saying how to issue it. Guessing 6Bh
  //with eight dummy cycles is right most of the time and silently wrong the
  //rest: too few dummy cycles shifts every byte that follows.
  Info := WinbondLike;
  Info.HasQuadInfo := False;
  Plan := ChipPlan(Info, True, $FF);
  Check('declared but unparameterised', Plan.Reason = qrNoParameters);

  Info := WinbondLike;
  Info.Read114Opcode := $FF;
  Plan := ChipPlan(Info, True, $FF);
  Check('an FF opcode is not a command', Plan.Reason = qrOpcodeUnusable);

  Info := WinbondLike;
  Info.HasQER := False;
  Plan := ChipPlan(Info, True, $FF);
  Check('nowhere to look for the bit', Plan.Reason = qrQENotLocatable);

  Info := WinbondLike;
  Info.QERCode := 7;   //reserved
  Plan := ChipPlan(Info, True, $FF);
  Check('a reserved QER code is not guessed at', Plan.Reason = qrQENotLocatable);

  //Unread is not the same as read-and-clear. Both end in a single-bit read
  //today, but they are different facts, and merging them is how "we never
  //checked" becomes "we checked and it was off" in a log.
  Plan := ChipPlan(WinbondLike, False, 0);
  Check('an unread register is not a cleared bit', Plan.Reason = qrQEBitNotRead);
end;

procedure TestTheBitIsFoundWhereSFDPSaysItIs;
var
  Info: TSFDPInfo;
  Op, Bit_: byte;
  Plan: TQuadPlan;
begin
  WriteLn('The quad-enable bit is located from SFDP, not from the vendor byte');

  //This is why it has to come from SFDP. Winbond keeps QE at bit 1 of status
  //register 2; Macronix keeps it at bit 6 of status register 1, which is the
  //bit the Winbond layout calls SEC. Reading the wrong table does not give a
  //wrong answer, it gives a plausible wrong answer.
  Info := WinbondLike;
  Info.QERCode := 1;
  Check('QER 1 is SR2 bit 1 via 35h',
        QuadStatusRegisterNeeded(Info, Op, Bit_) and
        (Op = $35) and (Bit_ = 1));

  Info.QERCode := 2;
  Check('QER 2 is SR1 bit 6 via 05h',
        QuadStatusRegisterNeeded(Info, Op, Bit_) and
        (Op = $05) and (Bit_ = 6));

  Info.QERCode := 3;
  Check('QER 3 is SR2 bit 7 via 3Fh',
        QuadStatusRegisterNeeded(Info, Op, Bit_) and
        (Op = $3F) and (Bit_ = 7));

  //And the bit tested is the one located, not bit 1 every time.
  Info.QERCode := 2;
  Plan := ChipPlan(Info, True, %01000000);   //bit 6 set
  Check('a Macronix-style bit 6 is honoured',
        Plan.Verdict = qvQuadAvailable);
  Plan := ChipPlan(Info, True, %00000010);   //bit 1 set, bit 6 clear
  Check('and bit 1 does not stand in for it',
        Plan.Verdict = qvSingleBit);
end;

// ------------------------------------------------------------ the payoff

procedure TestTheSpeedupIsReportedHonestly;
var
  Plan: TQuadPlan;
begin
  WriteLn('The speedup is what it actually is, not "four times"');
  Plan := ChipPlan(WinbondLike, True, %00000010);

  //A whole 8 MiB read: the per-byte cost dominates and the answer approaches
  //the theoretical 75% fewer clocks.
  Check('a whole-chip read saves about three quarters of the clocks',
        (QuadSpeedupPercent(Plan, 3, 8 * 1024 * 1024) >= 74) and
        (QuadSpeedupPercent(Plan, 3, 8 * 1024 * 1024) <= 75));

  //A short read is dominated by the opcode, address and dummy phases, which
  //are single-bit either way. Reporting "4x" here would be a lie the operator
  //could time with a stopwatch.
  Check('a 16-byte read saves far less',
        QuadSpeedupPercent(Plan, 3, 16) < 60);
  Check('but still saves something',
        QuadSpeedupPercent(Plan, 3, 16) > 0);

  //And there is no speedup to report when quad is not being used.
  Plan := ChipPlan(WinbondLike, True, 0);
  Check('a single-bit plan claims no speedup',
        QuadSpeedupPercent(Plan, 3, 8 * 1024 * 1024) = 0);
end;

// ------------------------------------------- against a real parameter table

procedure TestTheWordsAreParsedFromARealTable;
var
  Info: TSFDPInfo;
  Plan: TQuadPlan;
begin
  WriteLn('The bit positions are proved against a table, not a hand-built record');

  //Everything above drives PlanQuadRead with a TSFDPInfo built by hand, which
  //proves the policy and nothing about the parser. A transposed shift in
  //DWORD-3 sends the wrong dummy-cycle count, and the wrong dummy-cycle count
  //shifts every byte of a read -- silently, into data that still looks like
  //data.
  SetFakeChip(fcQuad);
  Check('the table is read', SFDPDetect(Info));

  Check('DWORD-1 bit 22 gave 1-1-4', Info.Supports114);
  Check('DWORD-1 bit 21 gave 1-4-4', Info.Supports144);
  Check('DWORD-3 gave the 1-1-4 opcode', Info.Read114Opcode = $6B);
  Check('and its eight dummy cycles', Info.Read114DummyCycles = 8);
  Check('and no mode clocks', Info.Read114ModeClocks = 0);
  Check('DWORD-3 gave the 1-4-4 opcode', Info.Read144Opcode = $EB);
  Check('and its six dummy cycles', Info.Read144DummyCycles = 6);
  Check('DWORD-15 gave the quad-enable requirement', Info.HasQER);
  Check('which is code 1', Info.QERCode = 1);

  Plan := ChipPlan(Info, True, %00000010);
  Check('and the whole chain ends in a usable quad read',
        (Plan.Verdict = qvQuadAvailable) and (Plan.Opcode = $6B) and
        (Plan.DummyCycles = 8));

  //The mode-clock trap fixture differs from the good one by three bits.
  SetFakeChip(fcQuadModeClocks);
  Check('the trap table is read', SFDPDetect(Info));
  Check('its mode clocks are seen', Info.Read114ModeClocks = 2);
  Plan := ChipPlan(Info, True, %00000010);
  Check('and it is refused', Plan.Reason = qrModeClocksRequired);

  //A part whose table says nothing about quad must not acquire it from the
  //zeroes around it.
  SetFakeChip(fcWinbond64);
  Check('a plain table is read', SFDPDetect(Info));
  Check('and declares no quad mode',
        (not Info.Supports114) and (not Info.Supports144));
  Plan := ChipPlan(Info, True, $FF);
  Check('so the read stays single-bit', Plan.Verdict = qvSingleBit);
end;

// ------------------------------------------- what no programmer here can do

procedure TestNoBackendCanActuallyDriveFourLines;
var
  P: TQuadPlan;
  Caps: TProgrammerMemoryCapabilities;
  HW: THardwareList;
  Any: boolean;
begin
  WriteLn('The chip may be ready; no programmer here can drive four lines');

  //This is the honest finding, and it is why the feature ships as a report
  //rather than as a speedup. The WCH DLL's fastest SPI entry point is
  //CH347StreamSPI4, where the 4 counts wires -- CS, CLK, MOSI, MISO -- and
  //there is no quad entry point at all. FT232H MPSSE drives one data line out
  //and one in.
  Any := False;
  for HW := Low(THardwareList) to High(THardwareList) do
  begin
    Caps := DefaultMemoryCapabilities(HW);
    if Caps.SupportsQuadSPI then Any := True;
  end;
  Check('no backend claims quad SPI', not Any);

  //And with the chip ready and the programmer not, the operator is told both
  //halves: nothing is wrong with their part, and different hardware would
  //make the read four times faster. Saying only "single-bit read" would leave
  //them with no idea which end to change.
  P := PlanQuadRead(True, WinbondLike, True, %00000010, False);
  Check('the read stays single-bit', P.Verdict = qvSingleBit);
  Check('and names the programmer as the limit',
        P.Reason = qrProgrammerCannot);
  Check('while saying the chip was ready',
        Pos('already set', P.Note) > 0);
  Check('and no opcode is handed out for a bus that cannot carry it',
        P.Opcode = 0);

  //A chip that is not ready reports its own reason, not the programmer's:
  //fixing the programmer would not help.
  P := PlanQuadRead(True, WinbondLike, True, %00000000, False);
  Check('a chip-side reason still wins', P.Reason = qrQEBitClear);
end;

begin
  TestNoBackendCanActuallyDriveFourLines;
  TestTheWordsAreParsedFromARealTable;
  TestQEAlreadySetIsTakenForFree;
  TestAPartWithNoQEBitNeedsNothingRead;
  TestAClearQEBitIsNeverSet;
  TestModeClocksAreRefused;
  TestPreferences;
  TestEveryWayQuadIsUnavailable;
  TestTheBitIsFoundWhereSFDPSaysItIs;
  TestTheSpeedupIsReportedHonestly;
  WriteLn(Assertions, ' assertions, ', Failures, ' failures');
  if Failures <> 0 then Halt(1);
  WriteLn('ALL PASSED');
end.
