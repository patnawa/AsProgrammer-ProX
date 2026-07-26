program hwtests;

{ Tests for the SPI 25 protocol layer, run against a programmer that exists
  only in memory.

  These assert on the bytes that go down the wire. A chip programmer that
  sends an opcode the chip has never heard of does not report an error, it
  just does something undefined, so "which opcodes were sent" is exactly the
  thing worth pinning down.

  Build and run:
    copy ..\software\spi25.pas ..\software\basehw.pas ..\software\utilfunc.pas .
    fpc -Twin32 -Pi386 -Mobjfpc -Sh hwtests.lpr && hwtests.exe }

{$mode objfpc}{$H+}

uses
  SysUtils, BaseHW, spi25, mockhw;

var
  Failures: integer = 0;
  Mock: TMockHardware;

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

//เริ่มต้นใหม่ทุกครั้ง สิ่งที่รู้จากเทสต์ก่อนหน้าต้องไม่รั่วมา
procedure Fresh;
begin
  Mock := InstallMockProgrammer;
  Reset25ChipHints;
end;

// ------------------------------------------------------------ chip erase

procedure TestChipEraseUnknownVendor;
begin
  WriteLn('Chip erase: an unidentified chip gets only the standard opcode');
  Fresh;

  UsbAsp25_ChipErase;

  Check('C7h was sent', Mock.Sent($C7));
  Check('62h was not sent', not Mock.Sent($62));
  Check('60h was not sent', not Mock.Sent($60));
  Check('write enable came before the erase', Mock.SentInOrder($06, $C7));
end;

procedure TestChipEraseAtmel;
begin
  WriteLn('Chip erase: an Atmel part also gets 62h');
  Fresh;
  Chip25ManufID := $1F;

  UsbAsp25_ChipErase;

  Check('62h was sent', Mock.Sent($62));
  Check('C7h was sent as well', Mock.Sent($C7));
  Check('60h was not sent', not Mock.Sent($60));
  Check('62h came after a write enable', Mock.SentInOrder($06, $62));
end;

procedure TestChipEraseSST;
begin
  WriteLn('Chip erase: an SST part also gets 60h');
  Fresh;
  Chip25ManufID := $BF;

  UsbAsp25_ChipErase;

  Check('60h was sent', Mock.Sent($60));
  Check('C7h was sent as well', Mock.Sent($C7));
  Check('62h was not sent', not Mock.Sent($62));
end;

// ------------------------------------------------- four byte address mode

procedure TestEN4BDefault;
begin
  WriteLn('Enter 4 byte mode: an unidentified chip gets WREN then B7h only');
  Fresh;

  UsbAsp25_EN4B;

  Check('B7h was sent', Mock.Sent($B7));
  Check('write enable came first', Mock.SentInOrder($06, $B7));
  Check('the Spansion bank register was not touched', not Mock.Sent($17));
end;

procedure TestEN4BSpansion;
begin
  WriteLn('Enter 4 byte mode: a Spansion part also gets the bank register');
  Fresh;
  Chip25ManufID := $01;

  UsbAsp25_EN4B;

  Check('B7h was sent', Mock.Sent($B7));
  Check('17h was sent', Mock.Sent($17));
end;

procedure TestEN4BNotNeeded;
begin
  WriteLn('Enter 4 byte mode: a chip that is already there is left alone');
  Fresh;
  Chip25Entry4B := E4B_NONE;

  UsbAsp25_EN4B;
  UsbAsp25_EX4B;

  Check('nothing was sent at all', Mock.SentCount = 0);
end;

procedure TestEN4BFromSFDP;
begin
  WriteLn('Enter 4 byte mode: SFDP said use the extended address register');
  Fresh;
  Chip25Entry4B := E4B_EXTC5;

  UsbAsp25_EN4B;

  Check('C5h was sent', Mock.Sent($C5));
  Check('B7h was not sent', not Mock.Sent($B7));
end;

// -------------------------------------------------- status register write

procedure TestWriteSRIsNonVolatile;
begin
  WriteLn('Write status register: the default write must survive a power cycle');
  Fresh;

  UsbAsp25_WriteSR($00);

  //50h ทำให้การเขียนกลายเป็นแบบชั่วคราว ปุ่มปลดล็อกจึงต้องไม่ใช้มัน
  Check('06h was used', Mock.Sent($06));
  Check('50h was not used', not Mock.Sent($50));
  Check('the status register opcode followed', Mock.SentInOrder($06, $01));
end;

procedure TestWriteSRVolatileOnRequest;
begin
  WriteLn('Write status register: a volatile write is still possible');
  Fresh;

  UsbAsp25_WriteSR($00, $01, True);

  Check('50h was used', Mock.Sent($50));
end;

procedure TestWriteSRSST;
begin
  WriteLn('Write status register: an SST part needs 50h');
  Fresh;
  Chip25ManufID := $BF;

  UsbAsp25_WriteSR($00);

  Check('50h was used', Mock.Sent($50));
end;

procedure TestWriteSRFollowsSFDP;
begin
  WriteLn('Write status register: SFDP overrides the guess');
  Fresh;
  Chip25ManufID := $EF;
  Chip25SRWrenOpcode := $50;

  UsbAsp25_WriteSR($00);

  Check('50h was used because the chip asked for it', Mock.Sent($50));
end;

procedure TestWriteSR2Byte;
begin
  WriteLn('Write status register: the two byte form behaves the same way');
  Fresh;

  UsbAsp25_WriteSR_2byte($00, $00);

  Check('06h was used', Mock.Sent($06));
  Check('50h was not used', not Mock.Sent($50));
end;

// ----------------------------------------------------------------- read id

procedure TestReadIDRemembersVendor;
var
  ID: MEMORY_ID;
begin
  WriteLn('Read id: the manufacturer is remembered for later opcode choices');
  Fresh;
  Mock.SetReply([$EF, $40, $17, $EF, $16, $16, $EF, $40]);

  UsbAsp25_ReadID(ID);

  Check('9Fh was sent', Mock.Sent($9F));
  Check('the manufacturer byte was kept', Chip25ManufID = $EF);
  Check('the id bytes came back', (ID.ID9FH[0] = $EF) and (ID.ID9FH[2] = $17));
end;

procedure TestReadIDIgnoresDeadChip;
var
  ID: MEMORY_ID;
begin
  WriteLn('Read id: an empty socket must not be remembered as a vendor');
  Fresh;

  //ซ็อกเก็ตว่างจะอ่านได้ FF ล้วน ถ้าจำค่านั้นไว้จะเลือก opcode ผิดทั้งชุด
  Mock.SetReply([$FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF]);

  UsbAsp25_ReadID(ID);

  Check('nothing was remembered', Chip25ManufID = 0);
end;

begin
  WriteLn('AsProgrammer ProX protocol tests');
  WriteLn;

  TestChipEraseUnknownVendor;
  TestChipEraseAtmel;
  TestChipEraseSST;
  TestEN4BDefault;
  TestEN4BSpansion;
  TestEN4BNotNeeded;
  TestEN4BFromSFDP;
  TestWriteSRIsNonVolatile;
  TestWriteSRVolatileOnRequest;
  TestWriteSRSST;
  TestWriteSRFollowsSFDP;
  TestWriteSR2Byte;
  TestReadIDRemembersVendor;
  TestReadIDIgnoresDeadChip;

  WriteLn;
  if Failures = 0 then
    WriteLn('ALL PASSED')
  else
    WriteLn(Failures, ' FAILURES');
  Halt(Failures);
end.
