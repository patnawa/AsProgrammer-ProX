program writeadmission_tests;

// Whether an image can be written to a chip at an address.
//
// This rule used to live inside the GUI's workflow-strip painter, so the
// command line had a second, separate answer to the same question. The tests
// that matter here are the boundary ones: an image that ends exactly at the
// last byte must be allowed, one byte more must not, and neither may be
// decided by an addition that wraps.

{$mode objfpc}{$H+}

uses
  SysUtils, writeadmission;

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

procedure CheckReason(const Name: string; const A: TWriteAdmission;
  const Needle: string);
begin
  Inc(Assertions);
  if Pos(Needle, A.Reason) = 0 then
  begin
    Inc(Failures);
    WriteLn('FAIL: ', Name, ' (expected "', Needle, '", got "',
            A.Reason, '")');
  end;
end;

// A job that is ready to go: 64 KiB into an 8 MiB SPI NOR at address 0.
function GoodTarget: TWriteTarget;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Protocol := wpSPI25;
  Result.BufferSize := 65536;
  Result.ChipSize := 8388608;
  Result.ChipSizeKnown := True;
  Result.StartAddress := 0;
  Result.StartAddressValid := True;
  Result.PageSize := 256;
  Result.PageSizeValid := True;
  Result.ProgrammerPresent := True;
  Result.ChipSelected := True;
  Result.ChipIdentityProven := True;
  Result.SmartWriteSupported := True;
end;

procedure TestAGoodJobIsAdmitted;
var
  A: TWriteAdmission;
begin
  A := EvaluateWriteAdmission(GoodTarget);
  Check('a complete job may write', A.MayWrite);
  Check('and may smart write', A.MaySmartWrite);
  Check('with nothing to complain about', A.Reason = '');
  Check('the buffer is seen', A.HasBuffer);
  Check('and it fits', A.FitsChip);
end;

procedure TestTheFitBoundary;
var
  T: TWriteTarget;
  A: TWriteAdmission;
begin
  //Exactly filling the chip is the commonest real job there is.
  T := GoodTarget;
  T.BufferSize := T.ChipSize;
  A := EvaluateWriteAdmission(T);
  Check('an image that exactly fills the chip is admitted', A.MayWrite);

  //One byte more is not.
  T.BufferSize := T.ChipSize + 1;
  A := EvaluateWriteAdmission(T);
  Check('one byte too many is refused', not A.MayWrite);
  CheckReason('and says it does not fit', A, 'does not fit');

  //Ending exactly at the last byte from an offset is admitted...
  T := GoodTarget;
  T.StartAddress := T.ChipSize - 4096;
  T.BufferSize := 4096;
  A := EvaluateWriteAdmission(T);
  Check('an image ending at the last byte is admitted', A.MayWrite);

  //...and one byte past it is not.
  T.BufferSize := 4097;
  A := EvaluateWriteAdmission(T);
  Check('running one byte past the end is refused', not A.MayWrite);

  //A start address at the very end of the chip has no room at all.
  T := GoodTarget;
  T.StartAddress := T.ChipSize;
  T.BufferSize := 1;
  A := EvaluateWriteAdmission(T);
  Check('starting at the end of the chip is refused', not A.MayWrite);
end;

procedure TestTheAdditionDoesNotWrap;
var
  T: TWriteTarget;
  A: TWriteAdmission;
begin
  //Computed as StartAddress + BufferSize this wraps and reports a fit. The
  //rule is written as ChipSize - StartAddress for exactly this reason, and
  //that is worth a test rather than a comment.
  T := GoodTarget;
  T.StartAddress := High(QWord) - 1024;
  T.BufferSize := 4096;
  A := EvaluateWriteAdmission(T);
  Check('an address near the top of the range cannot wrap into a fit',
    not A.MayWrite);

  T := GoodTarget;
  T.BufferSize := High(QWord);
  A := EvaluateWriteAdmission(T);
  Check('an enormous buffer cannot wrap into a fit', not A.MayWrite);
end;

procedure TestWordAddressedAlignment;
var
  T: TWriteTarget;
  A: TWriteAdmission;
begin
  //93-series parts address words. An odd address or an odd length is not a
  //rounding matter, it is a job the handler cannot express.
  T := GoodTarget;
  T.Protocol := wpMicrowire;
  T.StartAddress := 1;
  A := EvaluateWriteAdmission(T);
  Check('an odd start address is refused on a word-addressed part',
    not A.MayWrite);
  CheckReason('and says why', A, 'word addressed');

  T.StartAddress := 0;
  T.BufferSize := 65535;
  A := EvaluateWriteAdmission(T);
  Check('an odd length is refused too', not A.MayWrite);

  T.BufferSize := 65536;
  A := EvaluateWriteAdmission(T);
  Check('even address and even length are admitted', A.MayWrite);

  //A byte-addressed part has no such constraint.
  T := GoodTarget;
  T.StartAddress := 1;
  T.BufferSize := 65535;
  A := EvaluateWriteAdmission(T);
  Check('odd values are fine on a byte-addressed part', A.MayWrite);
end;

procedure TestPageSize;
var
  T: TWriteTarget;
  A: TWriteAdmission;
begin
  T := GoodTarget;
  T.PageSizeValid := False;
  A := EvaluateWriteAdmission(T);
  Check('an unparsable page size is refused', not A.MayWrite);
  CheckReason('and names the range', A, 'page size must be a number');

  T := GoodTarget;
  T.PageSize := 0;
  A := EvaluateWriteAdmission(T);
  Check('a zero page size is refused', not A.MayWrite);

  T.PageSize := MAX_PAGE_SIZE + 1;
  A := EvaluateWriteAdmission(T);
  Check('an oversized page is refused', not A.MayWrite);

  T.PageSize := MAX_PAGE_SIZE;
  A := EvaluateWriteAdmission(T);
  Check('the largest real page size is admitted', A.MayWrite);

  //MicroWire fixes its own page at two bytes, so demanding a valid page-size
  //box would refuse a job over a field that has no effect.
  T := GoodTarget;
  T.Protocol := wpMicrowire;
  T.PageSizeValid := False;
  A := EvaluateWriteAdmission(T);
  Check('MicroWire does not need the page-size box', A.MayWrite);
end;

procedure TestReasonsAreOrderedByWhatToDoNext;
var
  T: TWriteTarget;
  A: TWriteAdmission;
begin
  //An operator with three things wrong wants the first one to fix, and the
  //order runs from "you have not started" to "you are nearly there".
  T := GoodTarget;
  T.ProgrammerPresent := False;
  T.BufferSize := 0;
  T.ChipSelected := False;
  A := EvaluateWriteAdmission(T);
  CheckReason('the programmer comes first', A, 'Connect a programmer');

  T.ProgrammerPresent := True;
  A := EvaluateWriteAdmission(T);
  CheckReason('then the image', A, 'Open an image');

  T.BufferSize := 65536;
  A := EvaluateWriteAdmission(T);
  CheckReason('then the chip', A, 'Select or detect a chip');

  T.ChipSelected := True;
  T.ChipSizeKnown := False;
  A := EvaluateWriteAdmission(T);
  CheckReason('then its size', A, 'chip size is not set');

  T.ChipSizeKnown := True;
  T.StartAddressValid := False;
  A := EvaluateWriteAdmission(T);
  CheckReason('then the address', A, 'not a valid hex number');
end;

procedure TestUnprovenIdentityIsTheSoftestReason;
var
  T: TWriteTarget;
  A: TWriteAdmission;
begin
  //Picking a chip by name and writing it is a real workflow. It is just one
  //nobody has proved, so it is the only reason a caller may reasonably
  //downgrade to a warning -- and the flag says so explicitly rather than
  //leaving each caller to pattern-match the sentence.
  T := GoodTarget;
  T.ChipIdentityProven := False;
  A := EvaluateWriteAdmission(T);
  Check('an unproven identity still permits a write', A.MayWrite);
  Check('and a smart write', A.MaySmartWrite);
  Check('but it is flagged', A.OnlyIdentityUnproven);
  CheckReason('and stated', A, 'has not answered an identity read');

  //A hard failure must never be mistaken for the soft one.
  T.BufferSize := 0;
  A := EvaluateWriteAdmission(T);
  Check('a real failure is not flagged as merely unproven',
    not A.OnlyIdentityUnproven);
end;

procedure TestSmartWriteSupport;
var
  T: TWriteTarget;
  A: TWriteAdmission;
begin
  //A protocol with no differential writer can still take a plain write.
  T := GoodTarget;
  T.SmartWriteSupported := False;
  A := EvaluateWriteAdmission(T);
  Check('an unsupported protocol may still write plainly', A.MayWrite);
  Check('but not smart write', not A.MaySmartWrite);
  CheckReason('and says which protocols do', A, 'Smart write covers');
end;

begin
  TestAGoodJobIsAdmitted;
  TestTheFitBoundary;
  TestTheAdditionDoesNotWrap;
  TestWordAddressedAlignment;
  TestPageSize;
  TestReasonsAreOrderedByWhatToDoNext;
  TestUnprovenIdentityIsTheSoftestReason;
  TestSmartWriteSupport;
  WriteLn(Assertions, ' assertions, ', Failures, ' failures');
  if Failures <> 0 then Halt(1);
  WriteLn('ALL PASSED');
end.
