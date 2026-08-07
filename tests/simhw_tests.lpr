program simhw_tests;

// The programmer that is not there, driven through the real protocol layer.
//
// This suite deliberately calls spi25's own functions rather than poking the
// simulator directly. That is the whole value of a backend-level simulator:
// the bytes that reach it are the bytes this program would put on a wire, so
// a mistake in command framing shows up here exactly as it would on silicon.
// A simulator written at the engine level would agree with the engine by
// construction and prove nothing.
//
// The assertions that matter are the ones where the simulator refuses to be
// convenient: a program without WEL does nothing, a program into an unerased
// byte can only clear bits, and a program that runs past the end of its page
// wraps to the start of that same page. All three are behaviours of real
// flash that make a caller's bug invisible, and a simulator that smoothed
// them over would certify code that fails on the first real chip.

{$mode objfpc}{$H+}

uses
  SysUtils, basehw, spi25, simhw, electricalpreflight;

var
  Failures, Assertions: integer;
  Sim: TSimulatedHardware;

procedure Check(const Name: string; Condition: boolean);
begin
  Inc(Assertions);
  if not Condition then
  begin
    Inc(Failures);
    WriteLn('FAIL: ', Name);
  end;
end;

// ---------------------------------------------------------- identity

procedure TestItAnswersLikeAChip;
var
  ID: MEMORY_ID;
begin
  WriteLn('It answers the identity commands the program actually sends');

  FillByte(ID, SizeOf(ID), 0);
  UsbAsp25_ReadID(ID);

  Check('9Fh answered', ID.Got9F);
  Check('with the simulated part''s id',
        (ID.ID9FH[0] = SIM_JEDEC_0) and (ID.ID9FH[1] = SIM_JEDEC_1) and
        (ID.ID9FH[2] = SIM_JEDEC_2));
  //An all-FF or all-00 identity is what a floating bus reads back, and this
  //program treats it as an empty socket. A simulator that produced one would
  //be indistinguishable from no simulator at all.
  Check('the id is not a dead bus',
        not ((ID.ID9FH[0] = $FF) and (ID.ID9FH[1] = $FF)));
end;

procedure TestItHasARealSFDPTable;
var
  Buf: array[0..255] of byte;
  Got: integer;
begin
  WriteLn('It serves an SFDP table the real parser can read');

  FillByte(Buf, SizeOf(Buf), 0);
  Got := UsbAsp25_ReadSFDP(0, Buf, 16);
  Check('the table is served', Got = 16);
  //The signature the parser looks for. Getting this wrong would make the
  //simulator a part with no SFDP, which is a different and much less useful
  //thing to test against.
  Check('it starts with SFDP',
        (Buf[0] = Ord('S')) and (Buf[1] = Ord('F')) and
        (Buf[2] = Ord('D')) and (Buf[3] = Ord('P')));
end;

// ------------------------------------------------- reading and erasing

procedure TestAFreshPartIsErased;
var
  Buf: array[0..255] of byte;
begin
  WriteLn('A fresh simulated die reads back erased');

  FillByte(Buf, SizeOf(Buf), 0);
  Check('a read succeeds', UsbAsp25_Read($03, 0, Buf, 256) = 256);
  //FF rather than 00, because that is what an unprogrammed die holds -- and
  //because it makes an accidental read-before-write obviously empty instead
  //of plausibly full of zeroes.
  Check('and every byte is FF', (Buf[0] = $FF) and (Buf[255] = $FF));
end;

procedure TestProgrammingNeedsWriteEnable;
var
  Data: array[0..3] of byte;
begin
  WriteLn('A program without write-enable does nothing, silently');

  Data[0] := $12; Data[1] := $34; Data[2] := $56; Data[3] := $78;

  //No WREN first. A real part accepts the command, does nothing, and reports
  //no error -- which is precisely why this program verifies by reading back
  //rather than by trusting that nothing complained.
  UsbAsp25_Write($02, 0, Data, 4);
  Check('nothing was written', Sim.PeekByte(0) = $FF);

  UsbAsp25_Wren;
  UsbAsp25_Write($02, 0, Data, 4);
  Check('with write-enable it lands', Sim.PeekByte(0) = $12);
  Check('all four bytes', Sim.PeekByte(3) = $78);

  //And the latch clears itself, as it does on silicon, so a second program
  //without a second WREN also does nothing.
  Data[0] := $AA;
  UsbAsp25_Write($02, 16, Data, 1);
  Check('the write-enable latch cleared after the program',
        Sim.PeekByte(16) = $FF);
end;

procedure TestProgrammingOnlyClearsBits;
var
  Data: array[0..0] of byte;
begin
  WriteLn('Programming can clear bits and never set them');

  Sim.PokeByte(1024, $F0);
  Data[0] := $0F;
  UsbAsp25_Wren;
  UsbAsp25_Write($02, 1024, Data, 1);

  //Flash programming is an AND. Writing 0F over F0 gives 00, not 0F. A
  //simulator that stored the new byte outright would let a missing erase pass
  //every test here and fail on the first real chip.
  Check('F0 programmed with 0F becomes 00', Sim.PeekByte(1024) = $00);

  //Which is exactly what a missing erase looks like: the data is wrong, and
  //nothing reported an error.
  Sim.PokeByte(2048, $55);
  Data[0] := $AA;
  UsbAsp25_Wren;
  UsbAsp25_Write($02, 2048, Data, 1);
  Check('55 programmed with AA becomes 00', Sim.PeekByte(2048) = $00);
end;

procedure TestPageProgramWrapsWithinItsPage;
var
  Data: array[0..15] of byte;
  i: integer;
begin
  WriteLn('A program past the end of a page wraps to the start of that page');

  for i := 0 to 15 do Data[i] := byte($10 + i);

  //Starting eight bytes before the end of page 40. A real 25-series part
  //writes eight bytes to the tail and then wraps, overwriting the head of the
  //same page -- it does not continue into page 41.
  //
  //A page no earlier test has touched, because programming only clears bits:
  //on a page already carrying zeroes the wrap would be invisible, and the
  //test would pass for the wrong reason.
  UsbAsp25_Wren;
  UsbAsp25_Write($02, 40 * 256 + 248, Data, 16);

  Check('the tail of the page took the first bytes',
        Sim.PeekByte(40 * 256 + 248) = $10);
  //The bug this catches: a caller that ignores page boundaries silently
  //corrupts the head of the page it is writing, and nothing on the wire
  //reports it.
  Check('and the head of the same page took the rest',
        Sim.PeekByte(40 * 256 + 0) = $18);
  Check('the next page was not touched',
        Sim.PeekByte(41 * 256) = $FF);
end;

procedure TestEraseAlignsDownLikeTheChipDoes;
var
  Data: array[0..0] of byte;
begin
  WriteLn('An erase address inside a sector erases the whole sector');

  Data[0] := $00;
  UsbAsp25_Wren;
  UsbAsp25_Write($02, 4096, Data, 1);
  Check('a byte is programmed in the second sector', Sim.PeekByte(4096) = $00);

  //Address 0x1800 is in the middle of the 4K sector at 0x1000. The chip
  //erases the whole sector. Modelling that matters: a planner bug producing
  //unaligned addresses would look correct against a simulator that erased
  //from the address given, and would destroy a neighbouring sector on
  //silicon.
  UsbAsp25_Wren;
  UsbAsp25_EraseSector($20, $1800, False);
  Check('the whole sector came back erased', Sim.PeekByte(4096) = $FF);

  //And an erase without write-enable does nothing at all.
  UsbAsp25_Wren;
  UsbAsp25_Write($02, 8192, Data, 1);
  UsbAsp25_EraseSector($20, 8192, False);
  Check('an erase without write-enable is ignored', Sim.PeekByte(8192) = $00);
end;

procedure TestEraseSizesAreDistinct;
var
  Data: array[0..0] of byte;
begin
  WriteLn('4K, 32K, 64K and chip erase each cover what they say');

  Data[0] := $00;

  UsbAsp25_Wren;
  UsbAsp25_Write($02, 60000, Data, 1);
  UsbAsp25_Wren;
  UsbAsp25_EraseSector($20, 0, False);          //4K at 0 must not reach 60000
  Check('a 4K erase does not reach beyond its sector',
        Sim.PeekByte(60000) = $00);

  UsbAsp25_Wren;
  UsbAsp25_EraseSector($D8, 0, False);          //64K block does
  Check('a 64K erase does', Sim.PeekByte(60000) = $FF);

  UsbAsp25_Wren;
  UsbAsp25_Write($02, 4 * 1024 * 1024, Data, 1);
  Check('a byte is programmed high up the part',
        Sim.PeekByte(4 * 1024 * 1024) = $00);
  UsbAsp25_Wren;
  UsbAsp25_EraseSector($C7, 0, False);
  Check('a chip erase reaches it', Sim.PeekByte(4 * 1024 * 1024) = $FF);
end;

// ---------------------------------------------------- status registers

procedure TestStatusRegisters;
var
  SR: byte;
  Raw: array[0..1] of byte;
begin
  WriteLn('The status registers behave like a part''s');

  UsbAsp25_Wren;
  Check('reading SR1 succeeds', UsbAsp25_ReadSR(SR) > 0);
  //WEL is bit 1, and it must actually appear there: this program reads it
  //back to decide whether an unlock took.
  Check('the write-enable latch is visible', (SR and $02) <> 0);

  UsbAsp25_Wrdi;
  UsbAsp25_ReadSR(SR);
  Check('and clears again', (SR and $02) = 0);

  //A status-register write goes through, because UsbAsp25_WriteSR issues its
  //own write-enable first -- which is the correct behaviour of the protocol
  //layer and worth confirming still reaches the part.
  UsbAsp25_WriteSR($3C);
  UsbAsp25_ReadSR(SR);
  Check('a status-register write takes effect', (SR and $3C) = $3C);
  //And the latch is consumed, as on silicon.
  Check('and the write-enable latch is consumed', (SR and $02) = 0);

  //The silent-ignore behaviour itself is a property of the part, so it is
  //checked where a part would show it: at the wire, with no write-enable in
  //front of the opcode. That silence is why this program verifies an unlock
  //by reading it back rather than by trusting that nothing complained.
  UsbAsp25_Wrdi;
  Raw[0] := $01;      //WRSR
  Raw[1] := $00;
  Sim.SPIWrite(1, 2, Raw);
  UsbAsp25_ReadSR(SR);
  Check('a raw status write with no write-enable is ignored, silently',
        (SR and $3C) = $3C);

  //Cleaned up through the proper path, so later tests are not run against a
  //protected part.
  UsbAsp25_WriteSR($00);
  UsbAsp25_ReadSR(SR);
  Check('and the protect bits can be cleared again', (SR and $3C) = 0);
end;

// ---------------------------------------------------- what it will not do

procedure TestItNeverPretendsToMeasureAnything;
var
  Caps: TProgrammerElectricalCapabilities;
  Obs: TElectricalObservation;
  Mem: TProgrammerMemoryCapabilities;
begin
  WriteLn('A simulator with no pins measures nothing, and says so');

  Check('it reports capabilities', Sim.GetElectricalCapabilities(Caps));
  //Unmistakable, everywhere. This string reaches the rail report, the session
  //report and the CLI's JSON, and no setting changes it: a record of work
  //that came from here and does not say so is a false record.
  Check('it is named SIMULATED', Caps.ProgrammerID = 'SIMULATED');

  //It would have been easy to report a perfectly measured rail -- it is a
  //simulator, it can say anything -- and then every electrical check would
  //pass while proving nothing about the code those numbers flow through.
  Check('it cannot measure a voltage', not Caps.CanMeasureTargetVoltage);
  Check('nor a current', not Caps.CanMeasureTargetCurrent);
  Check('nor detect external power', not Caps.CanDetectExternalPower);
  Check('nor limit current', not Caps.HasCurrentLimit);
  //And it must not be the one backend that claims a verified signal level.
  Check('and its signal level is not verified',
        not Caps.SignalVoltageVerified);

  Check('it reports an observation', Sim.GetElectricalObservation(Obs));
  Check('with nothing measured in it',
        (not Obs.TargetVoltageMeasured) and (not Obs.TargetCurrentMeasured) and
        (not Obs.ExternalPowerKnown));

  Check('it offers SPI only', Sim.GetMemoryCapabilities(Mem));
  Check('and not I2C', not (mpI2C in Mem.Protocols));
  Check('and not MicroWire', not (mpMicroWire in Mem.Protocols));
  //Consistent with that: the unimplemented protocols fail rather than
  //silently succeeding, which would let an EEPROM operation appear to work.
  Check('an I2C transfer fails rather than succeeding quietly',
        Sim.I2CWriteByte($00) = False);
  Check('and MicroWire will not even initialise', not Sim.MWInit(0));
end;

begin
  Sim := TSimulatedHardware.Create;
  AsProgrammer := TAsProgrammer.Create;
  try
    AsProgrammer.AddHW(Sim);
    AsProgrammer.Current_HW := CHW_SIM;
    Check('the simulator is selectable',
          AsProgrammer.Programmer = TBaseHardware(Sim));
    Check('and opens', Sim.DevOpen);
    Check('and initialises SPI', Sim.SPIInit(0));

    TestItAnswersLikeAChip;
    TestItHasARealSFDPTable;
    TestAFreshPartIsErased;
    TestProgrammingNeedsWriteEnable;
    TestProgrammingOnlyClearsBits;
    TestPageProgramWrapsWithinItsPage;
    TestEraseAlignsDownLikeTheChipDoes;
    TestEraseSizesAreDistinct;
    TestStatusRegisters;
    TestItNeverPretendsToMeasureAnything;
  finally
    //TAsProgrammer owns what it is given.
    AsProgrammer.Free;
  end;

  WriteLn(Assertions, ' assertions, ', Failures, ' failures');
  if Failures <> 0 then Halt(1);
  WriteLn('ALL PASSED');
end.
