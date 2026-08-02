program nandadapter_tests;

//Wire-level ambiguity and cleanup tests for the SPI NAND adapter.

{$mode objfpc}{$H+}

uses
  SysUtils, nandmodel, nandengine, spi25nandadapter, mockhw;

var
  Assertions: integer = 0;
  Failures: integer = 0;

procedure Check(const Name: string; Condition: boolean);
begin
  Inc(Assertions);
  if Condition then
    WriteLn('  ok   ', Name)
  else
  begin
    Inc(Failures);
    WriteLn('  FAIL ', Name);
  end;
end;

function Geometry: TNANDGeometry;
var
  Err: string;
begin
  if not BuildNANDGeometry(2048, 64, 64, 1024, nilMainOnly, Result, Err) then
    raise Exception.Create(Err);
end;

procedure TestShortExecute;
var
  HW: TMockHardware;
  Dev: TSPINANDDevice;
  Config: TSPINANDConfig;
  Payload: TBytes;
  IO: TNANDIOResult;
  Failed: boolean;
begin
  WriteLn('Possibly issued: short 10h and D8h are never reported as safe');
  Config := DefaultSPINANDConfig;
  Config.DrainTimeoutMs := 0;

  HW := TMockHardware.Create;
  try
    HW.SetReply([$02, $00]); //WEL accepted; cleanup observes OIP clear
    HW.ShortWriteOpcode := $10;
    Dev := TSPINANDDevice.Create(HW, Geometry, Config);
    try
      SetLength(Payload, 16);
      FillByte(Payload[0], Length(Payload), $5A);
      IO := Dev.ProgramPage(1, 2, 0, Payload, Failed);
      Check('short program execute is a transport failure',
            (not IO.Success) and (IO.Error = nnioTransport));
      Check('short program execute is tagged possibly issued',
            IO.MutationState = nimsPossiblyIssued);
      Check('the bounded drain can subsequently prove idle',
            Dev.EnsureIdle.Success);
    finally
      Dev.Free;
    end;
  finally
    HW.Free;
  end;

  HW := TMockHardware.Create;
  try
    HW.SetReply([$02, $00]);
    HW.ShortWriteOpcode := $D8;
    Dev := TSPINANDDevice.Create(HW, Geometry, Config);
    try
      IO := Dev.EraseBlock(3, Failed);
      Check('short block erase is tagged possibly issued',
            (not IO.Success) and
            (IO.MutationState = nimsPossiblyIssued));
      Check('erase ambiguity also drains to an observed idle status',
            Dev.EnsureIdle.Success);
    finally
      Dev.Free;
    end;
  finally
    HW.Free;
  end;
end;

procedure TestTimeoutThenDrain;
var
  HW: TMockHardware;
  Dev: TSPINANDDevice;
  Config: TSPINANDConfig;
  IO: TNANDIOResult;
  Failed: boolean;
begin
  WriteLn('Timeout: operation failure retains issuance ambiguity until drain');
  Config := DefaultSPINANDConfig;
  Config.EraseTimeoutMs := 0;
  Config.DrainTimeoutMs := 0;
  HW := TMockHardware.Create;
  try
    //WREN, timed-out normal poll, then cleanup drain.
    HW.SetReply([$02, $01, $00]);
    Dev := TSPINANDDevice.Create(HW, Geometry, Config);
    try
      IO := Dev.EraseBlock(0, Failed);
      Check('busy timeout is tagged possibly issued',
            (not IO.Success) and (IO.Error = nnioTimeout) and
            (IO.MutationState = nimsPossiblyIssued));
      Check('a later idle sample resolves the array ambiguity',
            Dev.EnsureIdle.Success);
    finally
      Dev.Free;
    end;
  finally
    HW.Free;
  end;
end;

procedure TestDrainRetriesAndWriteDisable;
var
  HW: TMockHardware;
  Dev: TSPINANDDevice;
  Config: TSPINANDConfig;
  IO: TNANDIOResult;
begin
  WriteLn('Cleanup wire protocol: transient drain retry and checked 04h');
  Config := DefaultSPINANDConfig;
  Config.DrainTimeoutMs := 50;
  HW := TMockHardware.Create;
  try
    HW.ShortReadAtCall := 1;
    HW.SetReply([$00]);
    Dev := TSPINANDDevice.Create(HW, Geometry, Config);
    try
      Check('drain retries a transient short status read within its bound',
            Dev.EnsureIdle.Success);
    finally
      Dev.Free;
    end;
  finally
    HW.Free;
  end;

  HW := TMockHardware.Create;
  try
    HW.SetReply([$00]);
    Dev := TSPINANDDevice.Create(HW, Geometry, Config);
    try
      IO := Dev.WriteDisable;
      Check('write-disable succeeds only after WEL reads clear', IO.Success);
      Check('write-disable clocks opcode 04h', HW.Sent($04));
      Check('write-disable verifies status with 0Fh/C0h',
            Pos('0FC0', HW.Transcript) > 0);
    finally
      Dev.Free;
    end;
  finally
    HW.Free;
  end;

  HW := TMockHardware.Create;
  try
    HW.SetReply([$02]);
    Dev := TSPINANDDevice.Create(HW, Geometry, Config);
    try
      IO := Dev.WriteDisable;
      Check('stuck WEL makes cleanup fail closed',
            (not IO.Success) and (IO.Error = nnioRejected));
    finally
      Dev.Free;
    end;
  finally
    HW.Free;
  end;
end;

begin
  WriteLn('AsProgrammer SPI NAND adapter tests');
  WriteLn;
  TestShortExecute;
  TestTimeoutThenDrain;
  TestDrainRetriesAndWriteDisable;
  WriteLn;
  WriteLn(Assertions - Failures, '/', Assertions, ' passed');
  if Failures <> 0 then Halt(1);
end.
