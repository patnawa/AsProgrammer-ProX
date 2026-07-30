program ch347proto_tests;

{ Byte-exact pins for the CH347 bulk packet layout. The transport cannot be
  tested without hardware, but the packets can be tested everywhere -- and
  the packet bytes are the part that took three open-source projects to
  reverse engineer, so they are the part that must never drift. }

{$mode objfpc}{$H+}

uses
  SysUtils, ch347proto;

var
  Failures: integer = 0;

procedure Check(const Name: string; Cond: boolean);
begin
  if Cond then
    WriteLn('  ok   ', Name)
  else
  begin
    WriteLn('  FAIL ', Name);
    Inc(Failures);
  end;
end;

procedure TestConfig;
var
  P: TBytes;
  Err: string;
  i: integer;
  Zeros: boolean;
begin
  WriteLn('SPI configuration packet');
  Check('divisor 0 builds', CH347BuildSPIConfig(0, P, Err));
  Check('29 bytes long', Length(P) = 29);
  Check('command C0', P[0] = $C0);
  Check('payload length 26 little-endian', (P[1] = 26) and (P[2] = 0));
  Check('vendor mystery bytes 5/6/14/19',
        (P[5] = 4) and (P[6] = 1) and (P[14] = 2) and (P[19] = 7));
  Check('SPI mode 0', (P[9] = 0) and (P[11] = 0));
  Check('MSB first', P[17] = 0);
  Check('CS active low', P[24] = 0);
  Check('divisor 0 encodes 60 MHz', P[15] = 0);

  Check('divisor 5 builds', CH347BuildSPIConfig(5, P, Err));
  Check('divisor lives in bits 5:3', P[15] = 5 shl 3);

  Zeros := True;
  for i := 0 to High(P) do
    if not (i in [0, 1, 5, 6, 14, 15, 19]) then
      if P[i] <> 0 then Zeros := False;
  Check('every other byte is zero', Zeros);

  Check('divisor 8 is refused',
        (not CH347BuildSPIConfig(8, P, Err)) and (Err <> ''));
  Check('clock table: 0 is 60 MHz', CH347ClockHz(0) = 60000000);
  Check('clock table: 7 is 468.75 kHz', CH347ClockHz(7) = 468750);
  Check('clock table: 8 is nothing', CH347ClockHz(8) = 0);
end;

procedure TestCS;
var
  P: TBytes;
begin
  WriteLn('CS control packet');
  P := CH347BuildCSControl(True);
  Check('13 bytes long', Length(P) = 13);
  Check('command C1, payload 10', (P[0] = $C1) and (P[1] = 10) and (P[2] = 0));
  Check('assert drives CS1 with change+assert', P[3] = $80);
  Check('CS2 is left alone', P[8] = 0);
  P := CH347BuildCSControl(False);
  Check('deassert drives CS1 with change+deassert', P[3] = $C0);
end;

procedure TestOutIn;
var
  Data: array[0..699] of byte;
  P: TBytes;
  i: integer;
  Copied: boolean;
  Cmd: byte;
  PayloadLen: word;
  Ack: array[0..3] of byte;
begin
  WriteLn('Write chunks, read requests, and reply headers');
  for i := 0 to High(Data) do Data[i] := byte(i * 13);

  P := CH347BuildSPIOut(Data, 0, 5);
  Check('write chunk is header plus data', Length(P) = 8);
  Check('command C4, length 5', (P[0] = $C4) and (P[1] = 5) and (P[2] = 0));
  Copied := True;
  for i := 0 to 4 do
    if P[3 + i] <> Data[i] then Copied := False;
  Check('the payload is the caller''s bytes', Copied);

  P := CH347BuildSPIOut(Data, 100, 507);
  Check('a full 507-byte chunk builds from an offset',
        (Length(P) = 510) and (P[1] = $FB) and (P[2] = $01) and
        (P[3] = Data[100]));
  Check('508 bytes is refused', CH347BuildSPIOut(Data, 0, 508) = nil);
  Check('reading past the buffer is refused',
        CH347BuildSPIOut(Data, 697, 5) = nil);

  P := CH347BuildSPIInRequest($12345);
  Check('read request is 7 bytes', Length(P) = 7);
  Check('command C3, payload length 4',
        (P[0] = $C3) and (P[1] = 4) and (P[2] = 0));
  Check('count is 32-bit little-endian',
        (P[3] = $45) and (P[4] = $23) and (P[5] = $01) and (P[6] = 0));
  Check('a zero-byte read request is refused',
        CH347BuildSPIInRequest(0) = nil);

  Ack[0] := $C4; Ack[1] := 1; Ack[2] := 0; Ack[3] := 0;
  Check('a clean write ack parses', CH347OutAckOK(Ack, 4));
  Ack[3] := 1;
  Check('a nonzero status is not an ack', not CH347OutAckOK(Ack, 4));
  Ack[3] := 0;
  Ack[0] := $C3;
  Check('the wrong command is not an ack', not CH347OutAckOK(Ack, 4));
  Check('a short reply is not an ack', not CH347OutAckOK(Ack, 2));

  Ack[0] := $C3; Ack[1] := $FB; Ack[2] := $01;
  Check('header parse returns command and length',
        CH347ParseHeader(Ack, 4, Cmd, PayloadLen) and (Cmd = $C3) and
        (PayloadLen = 507));
  Check('two bytes is not a header',
        not CH347ParseHeader(Ack, 2, Cmd, PayloadLen));
end;

begin
  WriteLn('CH347 bulk protocol packet tests');
  WriteLn;

  TestConfig;
  TestCS;
  TestOutIn;

  WriteLn;
  if Failures = 0 then
    WriteLn('ALL PASSED')
  else
    WriteLn(Failures, ' FAILURES');
  Halt(Failures);
end.
