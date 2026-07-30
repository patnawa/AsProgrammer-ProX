program legacy_protocol_tests;

{$mode objfpc}{$H+}

uses
  SysUtils, BaseHW, legacy_mockhw, i2c, spi95, spi25, microwire, spi45;

var
  Failures: integer = 0;
  Mock: TLegacyMockHardware;

procedure Check(const Name: string; Condition: boolean);
begin
  if Condition then
    WriteLn('  ok   ', Name)
  else
  begin
    WriteLn('  FAIL ', Name);
    Inc(Failures);
  end;
end;

procedure Fresh;
begin
  Mock := InstallLegacyMock;
end;

procedure TestI2CGeometry;
var
  A: TI2CAddr;
begin
  WriteLn('I2C geometry and address limits');
  Fresh;

  Check('24C04 capacity', I2CAddrCapacity(I2C_ADDR_TYPE_1BYTE_1BIT) = 512);
  Check('last 24C04 byte is valid',
        I2CAddressRangeValid(I2C_ADDR_TYPE_1BYTE_1BIT, $1FF, 1));
  Check('range past 24C04 is refused',
        not I2CAddressRangeValid(I2C_ADDR_TYPE_1BYTE_1BIT, $1FF, 2));
  Check('BuildI2CAddr refuses truncated high bits',
        not BuildI2CAddr($A0, I2C_ADDR_TYPE_1BYTE, $100, A));
  Check('refused address leaves safe control byte', A.DevByte = 0);
  Check('unknown address type leaves safe control byte',
        (not BuildI2CAddr($A0, 99, 0, A)) and (A.DevByte = 0));
  Check('chunk stops at control-byte bank',
        I2CChunkToBankBoundary(I2C_ADDR_TYPE_1BYTE_2BIT, $FF, 8) = 1);
  Check('aligned chunk can use whole request',
        I2CChunkToBankBoundary(I2C_ADDR_TYPE_1BYTE_2BIT, $100, 8) = 8);
end;

procedure TestI2CBankSplit;
var
  Data: array[0..1] of byte;
begin
  WriteLn('I2C bank-aware transfers and ACK polling');
  Fresh;

  Check('cross-bank read succeeds',
        UsbAspI2C_Read($A0, I2C_ADDR_TYPE_1BYTE_1BIT, $FF,
                       Data, Length(Data)) = 2);
  Check('cross-bank read was split', Length(Mock.I2CTransactions) = 2);
  Check('first bank used A0',
        (Mock.I2CTransactions[0].DevAddr = $A0) and
        (Mock.I2CTransactions[0].WriteData[0] = $FF));
  Check('second bank used A2',
        (Mock.I2CTransactions[1].DevAddr = $A2) and
        (Mock.I2CTransactions[1].WriteData[0] = $00));
  Check('both pieces reached caller', (Data[0] = $10) and (Data[1] = $11));

  Fresh;
  Data[0] := $55;
  Check('upper-bank write succeeds',
        UsbAspI2C_Write($A0, I2C_ADDR_TYPE_1BYTE_1BIT, $100, Data, 1) = 1);
  Check('write used upper bank', Mock.I2CTransactions[0].DevAddr = $A2);
  Check('ready poll used the same upper bank',
        (Mock.PollCount > 0) and (Mock.PollDevAddr(0) = $A2));

  Fresh;
  Mock.AlwaysNack := True;
  Check('bank-aware ready helper reports timeout',
        not UsbAspI2C_WaitReadyAt($A0, I2C_ADDR_TYPE_24LC1025,
                                  $10000, 0));
  Check('24LC1025 poll lifts B0 into bit 3',
        (Mock.PollCount = 1) and (Mock.PollDevAddr(0) = $A8));
end;

procedure TestSPI95Framing;
var
  Data: array[0..1] of byte;
begin
  WriteLn('SPI 95xx framing and range checks');

  Fresh;
  Mock.SetSPIReply([$11]);
  Check('8-bit read succeeds', UsbAsp95_Read(256, $12, Data, 1) = 1);
  Check('8-bit frame', Mock.SPITranscript = '0312');

  Fresh;
  Mock.SetSPIReply([$22]);
  Check('A8-in-opcode read succeeds', UsbAsp95_Read(512, $100, Data, 1) = 1);
  Check('upper half uses 0Bh', Mock.SPITranscript = '0B00');

  Fresh;
  Mock.SetSPIReply([$33]);
  Check('16-bit read succeeds', UsbAsp95_Read(65536, $1234, Data, 1) = 1);
  Check('16-bit frame', Mock.SPITranscript = '031234');

  Fresh;
  Mock.SetSPIReply([$44]);
  Check('24-bit read succeeds', UsbAsp95_Read(131072, $12345, Data, 1) = 1);
  Check('24-bit frame', Mock.SPITranscript = '03012345');

  Fresh;
  Check('ambiguous 300-byte geometry is refused',
        UsbAsp95_Read(300, 0, Data, 1) = -1);
  Check('refused geometry touched no wire', Mock.SPITranscript = '');
  Check('out-of-range write is refused',
        UsbAsp95_Write(256, 255, Data, 2) = -1);
  Check('aligned page chunk is never zero', SPI95PageChunk($100, 16, 16) = 16);
  Check('unaligned page chunk ends at boundary', SPI95PageChunk($10F, 16, 16) = 1);
end;

procedure TestSPI95Status;
var
  WEL: boolean;
  Status: byte;
begin
  WriteLn('SPI 95xx checked WREN and ready polling');

  Fresh;
  Mock.SetSPIReply([$02]);
  Check('latched WREN is accepted', UsbAsp95_WrenChecked(WEL) and WEL);
  Check('WREN then RDSR frame', Mock.SPITranscript = '0605');

  Fresh;
  Mock.SetSPIReply([$00]);
  Check('clear WEL is rejected', not UsbAsp95_WrenChecked(WEL));

  Fresh;
  Mock.SetSPIReply([$01, $01, $00]);
  Check('ready helper waits through WIP',
        UsbAsp95_WaitReady(100, Status) and (Status = 0));
  Check('status was read three times', Mock.SPITranscript = '050505');

  Fresh;
  Mock.FailSPIWriteCall := 1;
  Check('failed command header aborts read',
        UsbAsp95_Read(256, 0, Status, 1) = -1);
end;

procedure TestSPI25ExactTransfers;
var
  Data: array[0..3] of byte;
  Tiny: array[0..3] of byte;
  Command: array[0..3] of byte;
  ID: MEMORY_ID;
  WEL, Locked: boolean;
  Status: byte;
begin
  WriteLn('SPI NOR exact transfers and address guards');

  Fresh;
  Check('oversized read buffer is refused',
        UsbAsp25_Read($03, 0, Data, Length(Data) + 1) = -1);
  Check('negative read length is refused',
        UsbAsp25_Read($03, 0, Data, -1) = -1);
  Check('invalid lengths touch no wire', Mock.SPITranscript = '');

  Fresh;
  Check('three-byte read cannot wrap at 16 MiB',
        UsbAsp25_Read($03, $00FFFFFE, Data, Length(Data)) = -1);
  Check('wrapped three-byte read touches no wire', Mock.SPITranscript = '');

  Fresh;
  Check('four-byte read cannot wrap at 4 GiB',
        UsbAsp25_Read32bitAddr($13, $FFFFFFFE, Data, Length(Data)) = -1);
  Check('wrapped four-byte read touches no wire', Mock.SPITranscript = '');

  Fresh;
  Mock.ShortSPIWriteCall := 1;
  Mock.ShortSPIWriteCount := 3;
  Check('short split read header fails',
        UsbAsp25_Read($03, $123456, Data, Length(Data)) = -1);
  Check('short header aborts before reply', Mock.SPIReadCalls = 0);
  Check('only the transferred header bytes reached the wire',
        Mock.SPITranscript = '031234');

  Fresh;
  Mock.SetSPIReply([$10, $11, $12, $13]);
  Mock.ShortSPIReadCall := 1;
  Mock.ShortSPIReadCount := 3;
  Check('short split reply fails',
        UsbAsp25_Read($03, $123456, Data, Length(Data)) = -1);
  Check('partial split reply is discarded',
        (Data[0] = $FF) and (Data[3] = $FF));

  Fresh;
  Mock.SetSPIReply([$10, $11, $12, $13]);
  Check('exact split read succeeds',
        UsbAsp25_Read($03, $123456, Data, Length(Data)) = Length(Data));
  Check('exact split reply reaches caller',
        (Data[0] = $10) and (Data[3] = $13));

  Fresh;
  FillByte(Data, SizeOf(Data), $A5);
  Mock.ShortSPIWriteCall := 1;
  Mock.ShortSPIWriteCount := 3;
  Check('short program header fails',
        UsbAsp25_Write($02, $123456, Data, Length(Data)) = -1);
  Check('short program header suppresses payload', Mock.SPIWriteCalls = 1);

  Fresh;
  FillByte(Data, SizeOf(Data), $A5);
  Mock.ShortSPIWriteCall := 2;
  Mock.ShortSPIWriteCount := 3;
  Check('short program payload fails',
        UsbAsp25_Write($02, $123456, Data, Length(Data)) = -1);

  Fresh;
  Check('zero-byte page program is a safe no-op',
        UsbAsp25_Write($02, 0, Data, 0) = 0);
  Check('zero-byte page program touches no wire', Mock.SPITranscript = '');

  Fresh;
  Mock.UseCombinedTransport;
  Mock.SetSPIReply([$20, $21, $22, $23]);
  Mock.ShortSPICombinedCall := 1;
  Mock.ShortSPICombinedCount := 3;
  Check('short combined reply fails',
        UsbAsp25_Read($03, $123456, Data, Length(Data)) = -1);
  Check('partial combined reply is discarded',
        (Data[0] = $FF) and (Data[3] = $FF));
  Check('combined path used one atomic exchange',
        (Mock.SPICombinedCalls = 1) and
        (Mock.SPIWriteCalls = 0) and (Mock.SPIReadCalls = 0));

  Fresh;
  Mock.UseCombinedTransport;
  Mock.SetSPIReply([$30, $31, $32, $33]);
  Check('exact combined fast read succeeds',
        UsbAsp25_ReadFast($0B, $123456, Data, Length(Data)) =
        Length(Data));
  Check('combined fast-read header includes dummy byte',
        Mock.SPITranscript = '0B123456FF');

  Fresh;
  Mock.UseCombinedTransport;
  Mock.ShortSPICombinedCall := 1;
  Mock.ShortSPICombinedCount := 0;
  Check('short combined block-lock reply fails closed',
        not UsbAsp25_ReadBlockLock(0, False, Locked));

  Fresh;
  Command[0] := $03;
  Command[1] := $12;
  Command[2] := $34;
  Command[3] := $56;
  Mock.ShortSPIWriteCall := 1;
  Mock.ShortSPIWriteCount := 2;
  Check('public split exchange rejects short command',
        SPIReadWrite(1, 0, Length(Data), Data,
                     Length(Command), Command) = -1);
  Check('public split exchange does not read after short command',
        Mock.SPIReadCalls = 0);

  Fresh;
  Mock.UseCombinedTransport;
  Mock.ShortSPICombinedCall := 1;
  Mock.ShortSPICombinedCount := 2;
  Check('public combined exchange rejects short reply',
        SPIReadWrite(1, 0, Length(Data), Data,
                     Length(Command), Command) = -1);

  Fresh;
  Mock.FailSPIWriteCall := 1;
  Status := $FF;
  Check('status read rejects a short opcode',
        UsbAsp25_ReadSR(Status) = -1);
  Check('status read is not attempted after short opcode',
        Mock.SPIReadCalls = 0);

  Fresh;
  Mock.FailSPIWriteCall := 1;
  Check('ID read returns -1 on a short command',
        UsbAsp25_ReadID(ID) = -1);
  Check('failed ID transaction leaves every result untrusted',
        (not ID.Got9F) and (not ID.Got90) and
        (not ID.GotAB) and (not ID.Got15));

  Fresh;
  Check('UID read requires its full eight-byte destination',
        UsbAsp25_ReadUniqueID(Tiny) = -1);
  Check('short UID destination touches no wire', Mock.SPITranscript = '');

  Fresh;
  Mock.FailSPIWriteCall := 1;
  Check('failed WREN aborts checked-WEL read',
        not UsbAsp25_WrenChecked(WEL));
  Check('failed WREN did not issue RDSR',
        (Mock.SPIWriteCalls = 1) and (Mock.SPIReadCalls = 0));

  Fresh;
  Mock.FailSPIWriteCall := 1;
  Check('reset-enable short transfer aborts reset',
        UsbAsp25_SoftReset = -1);
  Check('reset opcode was not sent after failed reset-enable',
        Mock.SPIWriteCalls = 1);

  Fresh;
  Mock.ShortSPIWriteCall := 1;
  Mock.ShortSPIWriteCount := 1;
  Check('short SST byte program normalizes to -1',
        UsbAsp25_WriteSSTB($AD, $5A) = -1);
end;

procedure TestMicrowire;
var
  Data: array[0..1] of byte;
begin
  WriteLn('Microwire guards, EWDS and timeout');

  Fresh;
  Check('too-short address length rejected', not MWAddressValid(1, 0));
  Check('too-long address length rejected', not MWAddressValid(17, 0));
  Check('address outside declared width rejected', not MWAddressValid(6, 64));
  Check('invalid read emits no command',
        UsbAspMW_Read(6, 64, Data, 2) = -1);
  Check('invalid read touched no wire', Length(Mock.MWTransactions) = 0);

  Fresh;
  Check('valid word read succeeds', UsbAspMW_Read(6, 3, Data, 2) = 2);
  Check('READ command is 9 bits',
        (Length(Mock.MWTransactions) = 1) and
        (Mock.MWTransactions[0].BitLen = 9));
  Check('read data returned', (Data[0] = $A0) and (Data[1] = $A1));

  Fresh;
  Check('EWEN succeeds', UsbAspMW_Ewen(6) = 9);
  Check('EWEN command starts 98h',
        Mock.MWTransactions[0].Data[0] = $98);
  Check('EWDS succeeds', UsbAspMW_Ewds(6) = 9);
  Check('EWDS command starts 80h',
        Mock.MWTransactions[1].Data[0] = $80);

  Fresh;
  Mock.BusyPollsRemaining := 2;
  Check('ready helper waits for DO high', UsbAspMW_WaitReady(100));
  Fresh;
  Mock.BusyPollsRemaining := 10;
  Check('zero timeout reports busy', not UsbAspMW_WaitReady(0));
end;

procedure TestDataFlash;
var
  Small: array[0..0] of byte;
  FullPage: array[0..263] of byte;
  ShortLock: array[0..7] of byte;
  Addr: array[0..2] of byte;
  Status: byte;
begin
  WriteLn('AT45 DataFlash command and buffer safety');

  Fresh;
  Check('disable protection command succeeds', UsbAsp45_DisableSP = 4);
  Check('disable protection command is exact',
        Mock.SPITranscript = '3D2A7F9A');

  Check('264-byte address builds',
        AT45BuildAddress(1, 264, 0, Addr) and
        (Addr[0] = 0) and (Addr[1] = 2) and (Addr[2] = 0));
  Check('offset outside page rejected',
        not AT45BuildAddress(0, 264, 264, Addr));
  Check('24-bit address overflow rejected',
        not AT45BuildAddress($10000, 1056, 0, Addr));

  Fresh;
  Mock.SetSPIReply([$5A]);
  Check('one-byte partial read is safe',
        UsbAsp45_ReadEx(1, 264, 0, Small, 1) = 1);
  Check('read command owns its eight-byte buffer',
        Mock.SPITranscript = 'E800020000000000');
  Check('read result was not overwritten by command', Small[0] = $5A);

  Fresh;
  Check('partial page program is rejected',
        UsbAsp45_WriteEx(1, 264, 0, Small, 1) = -1);
  Check('rejected partial program touched no wire', Mock.SPITranscript = '');

  Fresh;
  FillByte(FullPage, SizeOf(FullPage), $A5);
  Check('full page program succeeds',
        UsbAsp45_WriteEx(1, 264, 0, FullPage, Length(FullPage)) =
        Length(FullPage));
  Check('full page program has correct address prefix',
        Copy(Mock.SPITranscript, 1, 8) = '82000200');

  Fresh;
  Check('short lockdown output is rejected',
        UsbAsp45_ReadSectorLockdown(ShortLock) = -1);
  Check('short lockdown touched no wire', Mock.SPITranscript = '');

  Fresh;
  Mock.FailSPIReads := True;
  Check('failed status read fails closed as busy', UsbAsp45_Busy);

  Fresh;
  Mock.SetSPIReply([$00, $80]);
  Check('ready helper waits for status bit 7',
        UsbAsp45_WaitReady(100, Status) and (Status = $80));
end;

procedure TestDataFlashGeometry;
var
  Geo: TAT45Geometry;
  PowerOf2, Known: boolean;
  PageSize: word;
  Total: cardinal;
  Err: string;
begin
  WriteLn('AT45 DataFlash geometry from the status register');

  Check('density 0111 is an AT45DB041',
        AT45GeometryFromStatus(%10011100, Geo) and
        (Geo.Family = 'AT45DB041') and (Geo.Pages = 2048) and
        (Geo.StdPageSize = 264) and (Geo.BinPageSize = 256));
  Check('density 1111 is an AT45DB642, not a dead bus',
        AT45GeometryFromStatus(%10111100, Geo) and
        (Geo.Family = 'AT45DB642') and (Geo.Pages = 8192) and
        (Geo.StdPageSize = 1056) and (Geo.BinPageSize = 1024));
  Check('reserved density code is refused',
        not AT45GeometryFromStatus(%10000100, Geo));

  Fresh;
  Mock.SetSPIReply([$AD]); //AT45DB161 ready, binary page mode
  Check('161 in binary mode reports 512-byte pages',
        UsbAsp45_DetectGeometry(Geo, PowerOf2, PageSize, Total, Known, Err) and
        Known and PowerOf2 and (PageSize = 512) and
        (Total = cardinal(4096) * 512));

  Fresh;
  Mock.SetSPIReply([$AC]); //AT45DB161 ready, standard DataFlash page mode
  Check('161 in standard mode reports 528-byte pages',
        UsbAsp45_DetectGeometry(Geo, PowerOf2, PageSize, Total, Known, Err) and
        Known and (not PowerOf2) and (PageSize = 528) and
        (Total = cardinal(4096) * 528));

  Fresh;
  Mock.SetSPIReply([$84]); //answers, but the density code is reserved
  Check('unknown density answers but is not trusted',
        UsbAsp45_DetectGeometry(Geo, PowerOf2, PageSize, Total, Known, Err) and
        (not Known) and (PageSize = 0) and (Total = 0));

  Fresh;
  Mock.SetSPIReply([$FF]); //nobody driving the bus
  Check('a dead FF bus is not a geometry',
        (not UsbAsp45_DetectGeometry(Geo, PowerOf2, PageSize, Total,
                                     Known, Err)) and (Err <> ''));

  Fresh;
  Mock.FailSPIReads := True;
  Check('a failed status read is not a geometry',
        not UsbAsp45_DetectGeometry(Geo, PowerOf2, PageSize, Total,
                                    Known, Err));
end;

begin
  WriteLn('AsProgrammer legacy protocol hardening tests');
  WriteLn;

  TestI2CGeometry;
  TestI2CBankSplit;
  TestSPI95Framing;
  TestSPI95Status;
  TestSPI25ExactTransfers;
  TestMicrowire;
  TestDataFlash;
  TestDataFlashGeometry;

  WriteLn;
  if Failures = 0 then
    WriteLn('ALL PASSED')
  else
    WriteLn(Failures, ' FAILURES');
  Halt(Failures);
end.
