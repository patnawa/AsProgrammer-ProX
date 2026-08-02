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
  SysUtils, BaseHW, spi25, mockhw, i2c;

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
  Chip25Entry4B := E4B_ALWAYS4B;

  Check('entering reports success', UsbAsp25_EN4B = 1);
  Check('leaving reports success', UsbAsp25_EX4B = 1);
  Check('nothing was sent at all', Mock.SentCount = 0);

  //E4B_NONE คนละความหมาย: ไม่มีคำสั่งสลับที่ปลอดภัย ต้องล้มเหลวเงียบ ๆ
  //ห้ามตอบ "สำเร็จ" เพราะผู้เรียกจะส่งเฟรมสี่ไบต์ใส่ชิปที่ยังอยู่สามไบต์
  Fresh;
  Chip25Entry4B := E4B_NONE;
  Check('no safe switch method refuses', UsbAsp25_EN4B = 0);
  Check('and still sends nothing', Mock.SentCount = 0);
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

procedure TestExactJEDECProbeSendsOnly9F;
var
  ID: array[0..2] of byte;
begin
  WriteLn('Connection probe: exact JEDEC identity sends only 9Fh');
  Fresh;
  Mock.SetReply([$EF, $40, $17]);

  Check('exact 9F probe succeeds', UsbAsp25_ReadJEDEC9FExact(ID));
  Check('exact 9F probe returns all three bytes',
        (ID[0] = $EF) and (ID[1] = $40) and (ID[2] = $17));
  Check('the complete probe transcript is exactly 9F',
        Mock.Transcript = '9F');

  Fresh;
  Mock.FailReads := True;
  Check('short or failed transfer is rejected',
        not UsbAsp25_ReadJEDEC9FExact(ID));
  Check('failed transfer leaves a deterministic all-ones result',
        (ID[0] = $FF) and (ID[1] = $FF) and (ID[2] = $FF));
  Check('failed probe still sent no fallback opcodes',
        Mock.Transcript = '9F');
end;

// ------------------------------------------------------------------ I2C
//
// การแตกแอดเดรสของ I2C เคยถูกคัดลอกไว้สองที่ ก้อนละเจ็ดสาขา ตอนนี้เหลือก้อนเดียว
// เทสต์นี้ตรึงพฤติกรรมของทั้งเจ็ดสาขาไว้ว่าต้องได้ไบต์เดิมกับของเดิม

procedure TestI2CAddrTypes;
var
  A: TI2CAddr;
begin
  WriteLn('I2C: the address is split the same way as before');

  //ไม่มี word address เลย ใช้กับตัวสแกนหาอุปกรณ์
  Check('7 bit: the device address is shifted up one',
        BuildI2CAddr($A0, I2C_ADDR_TYPE_7BIT, $51, A) and
        (A.DevByte = $A2) and (A.AddrLen = 0));

  Check('1 byte: one address byte follows',
        BuildI2CAddr($A0, I2C_ADDR_TYPE_1BYTE, $37, A) and
        (A.DevByte = $A0) and (A.AddrLen = 1) and (A.AddrBytes[0] = $37));

  //บิตที่ 8 ของแอดเดรสขึ้นไปอยู่ที่บิต 1 ของไบต์คำสั่ง
  Check('1 byte + 1 bit: bit 8 moves into the control byte',
        BuildI2CAddr($A0, I2C_ADDR_TYPE_1BYTE_1BIT, $137, A) and
        (A.DevByte = $A2) and (A.AddrBytes[0] = $37));
  Check('1 byte + 1 bit: a clear bit 8 clears it again',
        BuildI2CAddr($A2, I2C_ADDR_TYPE_1BYTE_1BIT, $037, A) and
        (A.DevByte = $A0));

  Check('1 byte + 2 bits: bits 8 and 9 move up',
        BuildI2CAddr($A0, I2C_ADDR_TYPE_1BYTE_2BIT, $337, A) and
        (A.DevByte = $A6) and (A.AddrBytes[0] = $37));

  Check('1 byte + 3 bits: bits 8, 9 and 10 move up',
        BuildI2CAddr($A0, I2C_ADDR_TYPE_1BYTE_3BIT, $737, A) and
        (A.DevByte = $AE) and (A.AddrBytes[0] = $37));

  //word address สองไบต์ ไบต์สูงมาก่อนเสมอ
  Check('2 bytes: high byte first',
        BuildI2CAddr($A0, I2C_ADDR_TYPE_2BYTE, $1234, A) and
        (A.AddrLen = 2) and (A.AddrBytes[0] = $12) and (A.AddrBytes[1] = $34));

  Check('2 bytes + 1 bit: bit 16 moves to control bit 1',
        BuildI2CAddr($A0, I2C_ADDR_TYPE_2BYTE_1BIT, $11234, A) and
        (A.DevByte = $A2) and (A.AddrBytes[0] = $12) and (A.AddrBytes[1] = $34));
end;

procedure TestI2C24LC1025;
var
  A: TI2CAddr;
begin
  WriteLn('I2C: the 24LC1025 block select bit');

  //ไบต์คำสั่งของตระกูลนี้คือ 1 0 1 0 B0 A2 A1 R/W บิตเลือกบล็อกอยู่ที่บิต 3
  //ไม่ใช่บิต 1 แบบชนิด 2BYTE_1BIT ซึ่งเป็นเหตุผลที่ต้องมีชนิดแยกของตัวเอง
  Check('the lower block leaves the control byte alone',
        BuildI2CAddr($A0, I2C_ADDR_TYPE_24LC1025, $0000, A) and
        (A.DevByte = $A0) and (A.AddrLen = 2));

  Check('the last byte of the lower block is still block 0',
        BuildI2CAddr($A0, I2C_ADDR_TYPE_24LC1025, $FFFF, A) and
        (A.DevByte = $A0) and (A.AddrBytes[0] = $FF) and (A.AddrBytes[1] = $FF));

  //ข้ามไป 64KB ต้องพลิกไปบล็อกบน
  Check('the upper block sets bit 3',
        BuildI2CAddr($A0, I2C_ADDR_TYPE_24LC1025, $10000, A) and
        (A.DevByte = $A8) and (A.AddrBytes[0] = $00) and (A.AddrBytes[1] = $00));

  Check('the top of the chip is the top of the upper block',
        BuildI2CAddr($A0, I2C_ADDR_TYPE_24LC1025, $1FFFF, A) and
        (A.DevByte = $A8) and (A.AddrBytes[0] = $FF) and (A.AddrBytes[1] = $FF));

  //ไม่ใช่ที่เดียวกับชนิด 2BYTE_1BIT ถ้าเผลอใช้ชนิดนั้นจะได้ไบต์คำสั่งคนละตัว
  Check('it is not the same bit as the 2 byte + 1 bit type',
        BuildI2CAddr($A0, I2C_ADDR_TYPE_2BYTE_1BIT, $10000, A) and
        (A.DevByte = $A2));
end;

procedure TestI2CUnknownType;
var
  A: TI2CAddr;
begin
  WriteLn('I2C: an address type that does not exist is refused');

  //เดิมไม่มีสาขาสำรอง ไบต์คำสั่งจึงเป็นค่าที่ค้างอยู่ในสแตก
  //แล้วคำสั่งจะถูกส่งไปยังอุปกรณ์ตัวไหนก็ได้บนสาย
  Check('an unknown type is refused', not BuildI2CAddr($A0, 99, $1234, A));
  Check('and the control byte is not left as rubbish', A.DevByte = 0);
end;

procedure TestReadIDSilentBus;
var
  ID: MEMORY_ID;
begin
  WriteLn('Read id: a silent bus must not be reported as chip data');
  Fresh;

  //ชิปที่ไม่ตอบเลย คลิปหนีบไม่ติด ซ็อกเก็ตว่าง หรือชิปไม่ได้รับไฟ
  Mock.FailReads := True;
  UsbAsp25_ReadID(ID);

  Check('9Fh is reported as not answered', not ID.Got9F);
  Check('90h is reported as not answered', not ID.Got90);
  Check('ABh is reported as not answered', not ID.GotAB);
  Check('15h is reported as not answered', not ID.Got15);

  //นี่คือบั๊กตัวจริง เดิมทาง 90h กับ ABh ไม่ล้างบัฟเฟอร์ก่อนอ่าน
  //ไบต์ที่ค้างอยู่คือ opcode ที่เพิ่งส่งไป จึงรายงานออกมาเป็น ABh=AB
  //และ 90h=9000 ซึ่งดูเหมือนชิปตอบ ทั้งที่ไม่มีใครตอบเลย
  Check('ABh does not echo the ABh opcode back', ID.IDABH <> $AB);
  Check('90h does not echo the 90h opcode back', ID.ID90H[0] <> $90);
  Check('a silent bus reads as FF throughout',
        (ID.ID9FH[0] = $FF) and (ID.ID90H[0] = $FF) and
        (ID.IDABH = $FF) and (ID.ID15H[0] = $FF));

  //ห้ามจำยี่ห้อจากสายที่เงียบ ไม่งั้นจะเลือก opcode ตามยี่ห้อที่ไม่มีอยู่จริง
  Check('no vendor is remembered from a silent bus', Chip25ManufID = 0);

  //ชิปที่ตอบจริงต้องถูกรายงานว่าตอบ
  Fresh;
  Mock.SetReply([$EF, $40, $17]);
  UsbAsp25_ReadID(ID);
  Check('a real answer is marked as answered', ID.Got9F);
  Check('and the id came through', (ID.ID9FH[0] = $EF) and
        (ID.ID9FH[1] = $40) and (ID.ID9FH[2] = $17));
end;

// ------------------------------------------------------------- fast read

//03h ไม่มีไบต์หลอก 0Bh มีหนึ่งไบต์ ถ้าจำนวนไบต์หลอกผิดไปหนึ่งไบต์ ข้อมูล
//ทั้งก้อนจะเลื่อนไปหนึ่งตำแหน่ง ซึ่งอ่านออกมาแล้วดูเหมือนข้อมูลจริงทุกอย่าง
//นี่คือชนิดของความผิดพลาดที่ต้องจับที่ระดับไบต์ ไม่ใช่ที่ระดับผลลัพธ์
procedure TestFastReadSendsDummy;
var
  Buf: array[0..3] of byte;
begin
  WriteLn('Fast read: 0Bh carries three address bytes and one dummy');
  Fresh;

  UsbAsp25_ReadFast($0B, $123456, Buf, 4);

  Check('the whole command is 0B 12 34 56 FF',
        Mock.Transcript = '0B123456FF');
end;

procedure TestPlainReadHasNoDummy;
var
  Buf: array[0..3] of byte;
begin
  WriteLn('Plain read: 03h carries three address bytes and nothing else');
  Fresh;

  UsbAsp25_Read($03, $123456, Buf, 4);

  Check('the whole command is 03 12 34 56', Mock.Transcript = '03123456');
end;

procedure TestFastRead4Byte;
var
  Buf: array[0..3] of byte;
begin
  WriteLn('Fast read: 0Ch carries four address bytes and one dummy');
  Fresh;

  UsbAsp25_ReadFast32bitAddr($0C, $01234567, Buf, 4);

  Check('the whole command is 0C 01 23 45 67 FF',
        Mock.Transcript = '0C01234567FF');
end;

// -------------------------------------------------------- write enable

procedure TestWrenCheckedSeesTheLatch;
var
  WEL: boolean;
begin
  WriteLn('Write enable: the latch is read back, not assumed');
  Fresh;

  //ชิปตอบว่า WEL ติดแล้ว บิต 1
  Mock.SetReply([%00000010]);
  Check('a chip that latched reports success', UsbAsp25_WrenChecked(WEL));
  Check('and says so', WEL);
  Check('06h went out first', Mock.SentInOrder($06, $05));
end;

procedure TestWrenCheckedCatchesRefusal;
var
  WEL: boolean;
begin
  WriteLn('Write enable: a chip that ignores WREN is caught here');
  Fresh;

  //ชิปที่ขา WP# ถูกดึงต่ำรับคำสั่งไปแล้วไม่ทำอะไร WEL จึงยังเป็นศูนย์
  Mock.SetReply([%00000000]);
  Check('the refusal is reported', not UsbAsp25_WrenChecked(WEL));
  Check('and WEL is false', not WEL);
end;

procedure TestWrenCheckedOnSilentBus;
var
  WEL: boolean;
begin
  WriteLn('Write enable: an empty socket is not mistaken for a latched chip');
  Fresh;

  //FF ล้วนมีบิต 1 ติดอยู่ ซึ่งอ่านตรง ๆ แล้วดูเหมือน WEL ติด
  //แต่ FF ล้วนคือบัสที่ไม่มีใครขับ ไม่ใช่คำตอบของชิป
  Mock.SetReply([$FF]);
  Check('all ones is not a latched write enable',
        not UsbAsp25_WrenChecked(WEL));
end;

// ------------------------------------------------------------- recovery

procedure TestSoftReset;
begin
  WriteLn('Recovery: the JEDEC reset is 66h then 99h, in that order');
  Fresh;

  UsbAsp25_SoftReset;

  Check('both bytes went out in order', Mock.SentInOrder($66, $99));
  Check('and nothing else did', Mock.Transcript = '6699');
end;

procedure TestExitQPI;
begin
  WriteLn('Recovery: leaving QPI mode is a single FFh');
  Fresh;

  UsbAsp25_ExitQPI;

  Check('one byte, FFh', Mock.Transcript = 'FF');
end;

procedure TestGlobalUnlock;
begin
  WriteLn('Unlock: releasing every block lock is a single 98h');
  Fresh;

  UsbAsp25_GlobalUnlock;

  Check('one byte, 98h', Mock.Transcript = '98');
end;

begin
  WriteLn('AsProgrammer ProX protocol tests');
  WriteLn;

  TestI2CAddrTypes;
  TestI2C24LC1025;
  TestI2CUnknownType;
  TestReadIDSilentBus;

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
  TestExactJEDECProbeSendsOnly9F;

  TestPlainReadHasNoDummy;
  TestFastReadSendsDummy;
  TestFastRead4Byte;
  TestWrenCheckedSeesTheLatch;
  TestWrenCheckedCatchesRefusal;
  TestWrenCheckedOnSilentBus;
  TestSoftReset;
  TestExitQPI;
  TestGlobalUnlock;

  WriteLn;
  if Failures = 0 then
    WriteLn('ALL PASSED')
  else
    WriteLn(Failures, ' FAILURES');
  Halt(Failures);
end.
