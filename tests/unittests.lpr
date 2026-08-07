program unittests;

{ Hardware-free tests for the parts of AsProgrammer ProX that are pure logic:
  the SFDP parser, the JEDEC vendor table, the serial number generator, the
  write protection decoder, the operation result channel and the production
  log.

  Build and run:
    copy ..\software\sfdp.pas ..\software\jedec.pas ..\software\serialnum.pas .
    fpc -Twin32 -Pi386 -Mobjfpc -Sh unittests.lpr && unittests.exe

  sfdp.pas normally talks to a chip through spi25. For the test a stub unit of
  the same name feeds it a synthetic parameter table instead, so the parser can
  be exercised without any hardware. }

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, Math, sfdp, jedec, serialnum, spi25, protbits, opresult,
  prodlog, flashops, imgcheck, ifd, utilfunc;

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

// ---------------------------------------------------------------- SFDP

procedure TestSFDPWinbond;
var
  Info: TSFDPInfo;
  Size: cardinal;
  Op: byte;
begin
  WriteLn('SFDP: a W25Q64 style table');
  SetFakeChip(fcWinbond64);

  Check('detected', SFDPDetect(Info));
  Check('revision 1.6', (Info.MajorRev = 1) and (Info.MinorRev = 6));
  Check('8 MiB', Info.Density = 8 * 1024 * 1024);
  Check('page 256', Info.PageSize = 256);
  Check('3 byte addressing', Info.AddrBytes = 3);
  Check('4K erase advertised', Info.Supports4KErase);
  Check('erase type 1 is 4K/20h',
        (Info.EraseTypes[1].Size = 4096) and (Info.EraseTypes[1].Opcode = $20));
  Check('erase type 2 is 32K/52h',
        (Info.EraseTypes[2].Size = 32768) and (Info.EraseTypes[2].Opcode = $52));
  Check('erase type 3 is 64K/D8h',
        (Info.EraseTypes[3].Size = 65536) and (Info.EraseTypes[3].Opcode = $D8));

  Check('smallest erase found', SFDPSmallestErase(Info, Size, Op));
  Check('smallest erase is 4K/20h', (Size = 4096) and (Op = $20));
  Check('address string', SFDPAddrBytesStr(Info) = '3');
end;

procedure TestSFDPNoSignature;
var
  Info: TSFDPInfo;
begin
  WriteLn('SFDP: a chip without a table');
  SetFakeChip(fcNoSFDP);
  Check('not detected', not SFDPDetect(Info));
  Check('marked invalid', not Info.Valid);
end;

procedure TestSFDPPowerOfTwoDensity;
var
  Info: TSFDPInfo;
begin
  WriteLn('SFDP: density given as a power of two');
  SetFakeChip(fcBigPow2);
  Check('detected', SFDPDetect(Info));
  // DWORD-2 bit31 set, value 34 -> 2^34 bits -> 2 GiB
  Check('2 GiB', Info.Density = cardinal(1) shl 31);
end;

procedure TestSFDPDword16;
var
  Info: TSFDPInfo;
begin
  WriteLn('SFDP: DWORD-16 says how to enter four byte addressing');
  SetFakeChip(fcMicron256);

  Check('detected', SFDPDetect(Info));
  Check('DWORD-16 was present', Info.HasDword16);
  Check('four byte addressing only', Info.AddrBytes = 4);
  Check('entry is WREN then B7h', Info.Entry4B.WrenB7);
  Check('the bank register method was not claimed', not Info.Entry4B.BankReg17);
  Check('a mode switch is still needed', SFDPNeeds4BSwitch(Info));
  Check('status register write enable is 06h', Info.SRWriteEnableOpcode = $06);
  Check('soft reset is 66h then 99h', Info.SoftReset66_99);
  Check('the description mentions WREN', Pos('WREN', SFDP4BEntryStr(Info)) > 0);
end;

procedure TestSFDP4BAIT;
var
  Info: TSFDPInfo;
begin
  WriteLn('SFDP: the four byte instruction table gives the real opcodes');
  SetFakeChip(fcMicron256);

  Check('detected', SFDPDetect(Info));
  Check('the table was found', Info.Has4BAIT);
  Check('read is 13h', Info.Read4BOpcode = $13);
  Check('page program is 12h', Info.PageProg4BOpcode = $12);
  Check('erase type 1 is 21h in four byte form', Info.EraseTypes[1].Opcode4B = $21);
  Check('erase type 3 is DCh in four byte form', Info.EraseTypes[3].Opcode4B = $DC);
  Check('erase type 2 has no four byte form', Info.EraseTypes[2].Opcode4B = 0);
end;

procedure TestSFDPUniformHasNoMap;
var
  Info: TSFDPInfo;
begin
  WriteLn('SFDP: a plain part has no sector map');
  SetFakeChip(fcWinbond64);

  Check('detected', SFDPDetect(Info));
  Check('no sector map', not Info.HasSectorMap);
end;

procedure TestSFDPSectorMap;
var
  Info: TSFDPInfo;
  Size: cardinal;
  Op: byte;
begin
  WriteLn('SFDP: a part with boot blocks reports them');
  SetFakeChip(fcBootBlock);

  Check('detected', SFDPDetect(Info));
  Check('the map was found', Info.HasSectorMap);
  Check('three regions', Info.RegionCount = 3);
  Check('the map is not uniform', not Info.Uniform);

  Check('region 1 is 64 KiB', Info.Regions[0].Size = 64 * 1024);
  Check('region 3 is 64 KiB', Info.Regions[2].Size = 64 * 1024);
  Check('the regions add up to the whole chip',
        Info.Regions[0].Size + Info.Regions[1].Size + Info.Regions[2].Size
          = 8 * 1024 * 1024);

  //ต้นชิปเป็นบล็อกเล็ก ลบได้เฉพาะ 4K
  Check('the first region only erases 4K',
        SFDPSectorAt(Info, 0, Size, Op) and (Size = 4096) and (Op = $20));

  //กลางชิปลบได้ทั้ง 4K และ 64K ตัวเล็กสุดคือ 4K
  Check('the middle region also offers 4K',
        SFDPSectorAt(Info, 1024 * 1024, Size, Op) and (Size = 4096));

  //เกินขอบชิปไปแล้วต้องไม่ตอบอะไร
  Check('past the end there is no region',
        not SFDPSectorAt(Info, 32 * 1024 * 1024, Size, Op));
end;

// ---------------------------------------------------- write protect bits

procedure TestProtBits;
var
  P: TProtInfo;
  FromA, ToA: cardinal;
const
  MB8 = 8 * 1024 * 1024;
begin
  WriteLn('Write protection decoding');

  // ไม่มีอะไรถูกล็อก
  P := DecodeProt($00, $00);
  Check('BP is zero', P.BP = 0);
  Check('nothing is protected', not ProtectedRange(P, MB8, FromA, ToA));

  // BP=1, ล็อกจากปลายบน หน่วยเป็นบล็อก 64K
  P := DecodeProt($04, $00);
  Check('BP reads as 1', P.BP = 1);
  Check('a range is protected', ProtectedRange(P, MB8, FromA, ToA));
  Check('it is the top 64 KiB',
        (FromA = MB8 - 64 * 1024) and (ToA = MB8 - 1));

  // TB=1 ย้ายไปล็อกจากปลายล่าง
  P := DecodeProt($24, $00);
  Check('TB is set', P.TB);
  Check('a range is protected', ProtectedRange(P, MB8, FromA, ToA));
  Check('it is the bottom 64 KiB', (FromA = 0) and (ToA = 64 * 1024 - 1));

  // BP=7 ล็อกทั้งชิป
  P := DecodeProt($1C, $00);
  Check('BP reads as 7', P.BP = 7);
  Check('the whole chip is protected', ProtectedRange(P, MB8, FromA, ToA));
  Check('from the first to the last byte', (FromA = 0) and (ToA = MB8 - 1));

  // BP=7 พร้อม SEC=1 ก็ยังคือทั้งชิป: ตาราง Winbond ระบุ 111 เป็น ALL
  // ทุกแถว สูตร 4K shl 6 = 256K ที่เคยใช้รายงานพื้นที่เล็กกว่าจริง 32 เท่า
  P := DecodeProt($5C, $00);
  Check('BP=7 with SEC set still reads as 7', P.BP = 7);
  Check('SEC is set', P.SEC);
  Check('BP=7 with SEC is still the whole chip',
        ProtectedRange(P, MB8, FromA, ToA));
  Check('all of it', (FromA = 0) and (ToA = MB8 - 1));

  // CMP กลับด้าน BP=0 กลายเป็นล็อกทั้งชิป
  P := DecodeProt($00, $40);
  Check('CMP is set', P.CMP);
  Check('the whole chip is protected', ProtectedRange(P, MB8, FromA, ToA));
  Check('from the first to the last byte', (FromA = 0) and (ToA = MB8 - 1));

  // SRP1 อ่านจากไบต์ที่สอง
  P := DecodeProt($00, $05);
  Check('SRP1 is set', P.SRP1);
  // WPS ตัวจริงอยู่ที่ SR3 บิต 2 (อ่านด้วย 15h) ไม่ใช่ SR2 บิต 2 ซึ่งเป็น
  // บิตสงวนที่อ่านได้ศูนย์เสมอ: การถอดจาก SR2 ทำให้การ์ดบิตล็อกรายบล็อก
  // ไม่เคยทำงานเลย
  Check('WPS is not taken from the reserved SR2 bit', not P.WPS);
  P := DecodeProtVendor($EF, $00, $00, %00000100, True);
  Check('WPS comes from SR3 bit 2', P.WPS);
  P := DecodeProtVendor($EF, $00, $00, $00, False);
  Check('an unread SR3 does not invent WPS', not P.WPS);

  // ประกอบกลับได้ค่าเดิม
  P := DecodeProt($64, $00);
  Check('SR1 round trips', EncodeProtSR1(P) = $64);

  // ชิปขนาดศูนย์ต้องไม่ทำให้คำนวณพัง
  P := DecodeProt($1C, $00);
  Check('a zero sized chip protects nothing',
        not ProtectedRange(P, 0, FromA, ToA));
end;

// -------------------------------------------------- operation result

procedure TestOpResult;
begin
  WriteLn('Operation result');

  OpBegin(opkWrite);
  Check('a fresh operation is not yet a failure', OpOK);

  OpFail('the page did not read back', $1234);
  Check('a failure sticks', not OpOK);
  Check('the message is kept', LastOp.ErrorText = 'the page did not read back');
  Check('the address is kept', LastOp.FailAddress = $1234);
  Check('the summary says which operation', Pos('write', OpSummary) > 0);
  Check('the summary says it failed', Pos('FAILED', OpSummary) > 0);
  Check('the summary carries the address', Pos('00001234', OpSummary) > 0);

  //สาเหตุแรกคือสาเหตุจริง ที่ตามมาเป็นผลพวง
  OpFail('something later');
  Check('the first cause is the one kept',
        LastOp.ErrorText = 'the page did not read back');

  OpBegin(opkVerify);
  Check('beginning again clears the failure', OpOK);
  OpProgress(100, 200);
  Check('progress is recorded', LastOp.BytesDone = 100);

  OpCancel;
  Check('cancelling counts as not OK', not OpOK);
  Check('cancelling is flagged separately', LastOp.Cancelled);

  //ความล้มเหลวที่เกิดก่อนใครเรียก OpBegin ต้องไม่หายเงียบ ๆ
  LastOp.Started := False;
  LastOp.Failed := False;
  OpFail('early failure');
  Check('a failure before any begin still counts', not OpOK);
end;

// ------------------------------------------------------- production log

procedure TestProdLog;
var
  Rec: TProdRecord;
  FileName: string;
  Passed, Failed: integer;
begin
  WriteLn('Production log');

  FileName := GetTempDir + 'aspx-prodlog-test.csv';
  DeleteFile(FileName);

  Rec.TimeStamp := EncodeDate(2026, 7, 26) + EncodeTime(12, 0, 0, 0);
  Rec.ChipName := 'W25Q64BV';
  Rec.UID := 'AABBCCDDEEFF0011';
  Rec.Serial := '00000001';
  Rec.Operator_ := 'somchai';
  Rec.Size := 8388608;
  Rec.CRC32 := $DEADBEEF;
  Rec.Outcome := poPass;
  Rec.Note := '';

  Check('the line has the chip name', Pos('W25Q64BV', ProdRecordToCSV(Rec)) > 0);
  Check('the line says PASS', Pos('PASS', ProdRecordToCSV(Rec)) > 0);
  Check('the crc is in hex', Pos('DEADBEEF', ProdRecordToCSV(Rec)) > 0);

  Check('the log was written', AppendProdLog(FileName, Rec));
  Check('the uid is now known to have passed',
        ProdLogHasPassedUID(FileName, 'AABBCCDDEEFF0011'));
  Check('case does not matter',
        ProdLogHasPassedUID(FileName, 'aabbccddeeff0011'));
  Check('a different uid is not known',
        not ProdLogHasPassedUID(FileName, '1122334455667788'));
  Check('an empty uid never matches', not ProdLogHasPassedUID(FileName, ''));

  //ตัวที่ตกต้องไม่ถูกนับว่าผ่าน ไม่งั้นด่านกันเขียนซ้ำจะปล่อยของเสียออกไป
  Rec.UID := '1122334455667788';
  Rec.Outcome := poFail;
  Rec.Note := 'verify failed at 0x1000';
  Check('the failing line was written', AppendProdLog(FileName, Rec));
  Check('a failed uid does not count as passed',
        not ProdLogHasPassedUID(FileName, '1122334455667788'));

  ProdLogCount(FileName, Passed, Failed);
  Check('one passed', Passed = 1);
  Check('one failed', Failed = 1);

  //ข้อความที่มีจุลภาคต้องไม่ทำให้คอลัมน์เลื่อน
  Rec.UID := '99AABBCCDDEE0011';
  Rec.Outcome := poPass;
  Rec.Note := 'a note, with a comma';
  Check('the quoted line was written', AppendProdLog(FileName, Rec));
  Check('a comma in a field does not shift the columns',
        ProdLogHasPassedUID(FileName, '99AABBCCDDEE0011'));

  DeleteFile(FileName);
end;

// ------------------------------------------------------------- job file

procedure TestJobFile;
var
  Job: TJobFile;
  FileName, ErrMsg: string;
  F: TextFile;
begin
  WriteLn('Job file');

  FileName := GetTempDir + 'aspx-job-test.txt';

  AssignFile(F, FileName);
  Rewrite(F);
  WriteLn(F, '# the approved image for this product');
  WriteLn(F, 'chip=W25Q64BV');
  WriteLn(F, 'size=8388608');
  WriteLn(F, 'crc32=0xDEADBEEF');
  CloseFile(F);

  Check('the job file loaded', LoadJobFile(FileName, Job, ErrMsg));
  Check('the chip name was read', Job.ChipName = 'W25Q64BV');
  Check('the size was read', Job.Size = 8388608);
  Check('the crc was read', Job.HasCRC and (Job.CRC32 = $DEADBEEF));

  Check('a matching buffer passes',
        CheckJob(Job, 'W25Q64BV', 8388608, $DEADBEEF, ErrMsg));

  Check('the wrong image is refused',
        not CheckJob(Job, 'W25Q64BV', 8388608, $12345678, ErrMsg));
  Check('and it says why', Pos('CRC32', ErrMsg) > 0);

  Check('the wrong chip is refused',
        not CheckJob(Job, 'MX25L6406E', 8388608, $DEADBEEF, ErrMsg));

  Check('the wrong size is refused',
        not CheckJob(Job, 'W25Q64BV', 4194304, $DEADBEEF, ErrMsg));

  //ไม่มีไฟล์งาน แปลว่าไม่ตรวจ ไม่ใช่ไม่ผ่าน
  FillChar(Job, SizeOf(Job), 0);
  Check('no job means no check',
        CheckJob(Job, 'anything', 1, 2, ErrMsg));

  Check('a missing file is reported',
        not LoadJobFile(GetTempDir + 'aspx-no-such-job.txt', Job, ErrMsg));

  DeleteFile(FileName);
end;

// --------------------------------------------------------------- JEDEC

procedure TestJedec;
var
  B: array[0..2] of byte;
begin
  WriteLn('JEDEC vendor table');
  Check('EF is Winbond', JedecVendor($EF) = 'Winbond');
  Check('C2 is Macronix', JedecVendor($C2) = 'Macronix');
  Check('C8 is GigaDevice', JedecVendor($C8) = 'GigaDevice');
  Check('1F is Atmel family', Pos('Atmel', JedecVendor($1F)) > 0);
  Check('7F is the continuation code', Pos('continuation', JedecVendor($7F)) > 0);
  Check('an unassigned id is empty', JedecVendor($44) = '');

  B[0] := 0; B[1] := 0; B[2] := 0;
  Check('all zero is a dead id', IsDeadID(B));
  B[0] := $FF; B[1] := $FF; B[2] := $FF;
  Check('all FF is a dead id', IsDeadID(B));
  B[0] := $EF; B[1] := $40; B[2] := $17;
  Check('a real id is alive', not IsDeadID(B));
end;

// -------------------------------------------------------- serial numbers

procedure TestSerial;
var
  S: TProdSettings;
  Bytes: array[0..7] of byte;
  Data: array[0..255] of byte;
  i: integer;
begin
  WriteLn('Serial numbers');
  DefaultProdSettings(S);
  S.SNEnabled := True;
  S.SNLength := 4;
  S.SNMode := smIncrement;
  S.SNValue := $12345678;
  S.SNBigEndian := True;

  BuildSerialBytes(S, Bytes);
  Check('big endian order',
        (Bytes[0] = $12) and (Bytes[1] = $34) and (Bytes[2] = $56) and (Bytes[3] = $78));
  Check('hex form', SerialToStr(S) = '12345678');

  S.SNBigEndian := False;
  BuildSerialBytes(S, Bytes);
  Check('little endian order',
        (Bytes[0] = $78) and (Bytes[1] = $56) and (Bytes[2] = $34) and (Bytes[3] = $12));

  // placing it in a buffer
  S.SNBigEndian := True;
  S.SNAddress := 16;
  FillChar(Data, SizeOf(Data), $FF);
  Check('applied', ApplySerial(S, Data, SizeOf(Data)));
  Check('written at the address',
        (Data[16] = $12) and (Data[19] = $78));
  Check('the byte before is untouched', Data[15] = $FF);
  Check('the byte after is untouched', Data[20] = $FF);

  // must refuse to run off the end of the buffer
  S.SNAddress := 254;
  Check('refuses to overflow the buffer', not ApplySerial(S, Data, SizeOf(Data)));

  // date mode puts a BCD date in the first three bytes
  S.SNAddress := 0;
  S.SNLength := 8;
  S.SNMode := smDateIncrement;
  S.SNValue := 1;
  BuildSerialBytes(S, Bytes);
  Check('BCD date digits are valid',
        ((Bytes[0] and $0F) <= 9) and ((Bytes[0] shr 4) <= 9) and
        ((Bytes[1] and $0F) <= 9) and ((Bytes[1] shr 4) <= 9) and
        ((Bytes[2] and $0F) <= 9) and ((Bytes[2] shr 4) <= 9));
  Check('month is between 1 and 12',
        ((Bytes[1] shr 4) * 10 + (Bytes[1] and $0F)) in [1..12]);
  Check('counter follows the date', Bytes[7] = 1);

  // random mode: eight random bytes twice running should not match
  S.SNMode := smRandom;
  S.SNLength := 8;
  Check('random mode fills the whole length', Length(SerialToStr(S)) = 16);
  Check('random mode varies between calls', SerialToStr(S) <> SerialToStr(S));
end;

// ------------------------------------------------- individual block locks

var
  FakeLockMap: array[0..511] of boolean;
  FakeLockReadable: boolean = True;

//ตัวอ่านปลอม บล็อกละ 64K เพื่อทดสอบการสแกนโดยไม่ต้องมีชิป
function FakeLockReader(Addr: cardinal; out Locked: boolean): boolean;
begin
  Locked := False;
  if not FakeLockReadable then Exit(False);
  Locked := FakeLockMap[(Addr div 65536) and 511];
  Result := True;
end;

procedure TestBlockLocks;
const
  CHIP = 8 * 1024 * 1024;
  BLK  = 64 * 1024;
var
  LockedAt: cardinal;
  Readable, Hit: boolean;
  i: integer;
begin
  WriteLn('Block locks: a WPS part is checked block by block');

  for i := 0 to High(FakeLockMap) do FakeLockMap[i] := False;
  FakeLockReadable := True;

  Hit := BlockLockConflict(@FakeLockReader, CHIP, BLK, 0, CHIP, LockedAt, Readable);
  Check('nothing locked means no conflict', not Hit);
  Check('and the bits were readable', Readable);

  //ล็อกบล็อกที่ 2 แล้วขอเขียนทับพอดี
  FakeLockMap[2] := True;
  Hit := BlockLockConflict(@FakeLockReader, CHIP, BLK, $20000, 100, LockedAt, Readable);
  Check('a locked block is found', Hit);
  Check('and it is named', LockedAt = $20000);

  //ขอเขียนที่อื่นซึ่งไม่ทับบล็อกที่ล็อก ต้องผ่าน
  Hit := BlockLockConflict(@FakeLockReader, CHIP, BLK, $50000, 100, LockedAt, Readable);
  Check('an untouched block is not a conflict', not Hit);

  //แอดเดรสกลางบล็อกต้องนับทั้งบล็อก เพราะบิตล็อกคุมทั้งบล็อก
  Hit := BlockLockConflict(@FakeLockReader, CHIP, BLK, $2F000, 16, LockedAt, Readable);
  Check('an address inside a locked block still conflicts', Hit);

  //ช่วงที่คร่อมหลายบล็อกต้องเจอตัวที่ล็อกด้วย
  Hit := BlockLockConflict(@FakeLockReader, CHIP, BLK, 0, $30000, LockedAt, Readable);
  Check('a range spanning into a locked block conflicts', Hit);
  Check('the first locked block is reported', LockedAt = $20000);

  //ความยาวที่ล้น cardinal ต้องถูกตัด ไม่ใช่วนกลับ
  Hit := BlockLockConflict(@FakeLockReader, CHIP, BLK, $7F0000, $FFFFFFFF,
                           LockedAt, Readable);
  Check('an overflowing length does not wrap', not Hit);

  //อ่านบิตไม่ได้เลยแปลว่าไม่รู้ ห้ามสรุปว่าปลอดภัย
  FakeLockReadable := False;
  Hit := BlockLockConflict(@FakeLockReader, CHIP, BLK, 0, CHIP, LockedAt, Readable);
  Check('an unreadable chip reports no conflict', not Hit);
  Check('but says so instead of claiming it is safe', not Readable);
end;

// ------------------------------------------------------------ flashops

procedure TestFirstChunk;
begin
  WriteLn('Write planning: the first chunk stops at the page boundary');

  //นี่คือบั๊กตัวจริงที่เคยทำให้โปรแกรมค้าง สูตรเดิมคืน 0 ตรงนี้
  //แล้ว Address ไม่ขยับ ลูปเขียนจึงวนไม่รู้จบ
  Check('an aligned start gets a whole page', FirstChunkSize($1000, 256) = 256);
  Check('address zero gets a whole page', FirstChunkSize(0, 256) = 256);
  Check('64 KiB boundary gets a whole page', FirstChunkSize($10000, 256) = 256);
  Check('1 MiB boundary gets a whole page', FirstChunkSize($100000, 256) = 256);

  //ครึ่งเพจต้องเขียนแค่ส่วนที่เหลือจนถึงขอบ
  Check('an unaligned start stops at the boundary',
        FirstChunkSize($1234, 256) = 204);
  Check('one byte before the boundary writes one byte',
        FirstChunkSize($10FF, 256) = 1);
  Check('a big page works the same', FirstChunkSize($800, 512) = 512);

  //ห้ามคืนศูนย์เด็ดขาด ไม่ว่าจะป้อนอะไรเข้ามา
  Check('never zero for a real page size',
        (FirstChunkSize($1000, 256) > 0) and (FirstChunkSize($1001, 256) > 0) and
        (FirstChunkSize($FFFFFF, 256) > 0));
end;

// ------------------------------------------------ read retry classification

//ความต่างที่เทสต์ชุดนี้ตรึงไว้คือหัวใจของเรื่อง: ทรานสเฟอร์ที่ไม่เกิดขึ้น
//สั่งใหม่ได้ เพราะการอ่านไม่เปลี่ยนอะไรบนชิป ส่วนคำตอบที่ได้มาไม่ครบคือคำตอบ
//ไม่ใช่อุบัติเหตุ สั่งซ้ำจะกลายเป็นการกลบข้อมูลที่ควรรายงาน
procedure TestReadRetry;
begin
  WriteLn('Read retry: what may be repeated, and what must not');

  Check('a full read is complete',
        ClassifyReadResult(2048, 2048) = rakComplete);
  //-1 คือรหัสความล้มเหลว ไม่ใช่จำนวนไบต์ ไม่มีข้อมูลเดินทางเลย
  Check('-1 is a transport failure, not a byte count',
        ClassifyReadResult(-1, 2048) = rakTransportFailure);
  Check('a partial count is a short read',
        ClassifyReadResult(1024, 2048) = rakShortRead);
  Check('zero of a nonzero request is a short read',
        ClassifyReadResult(0, 2048) = rakShortRead);
  //ขอศูนย์ไบต์แล้วได้ศูนย์ไบต์คือครบ
  Check('zero of zero is complete', ClassifyReadResult(0, 0) = rakComplete);

  //เฉพาะทรานสเฟอร์ที่ล้มเหลวเท่านั้นที่สั่งใหม่ได้
  Check('a failed transfer may be repeated',
        ShouldRetryRead(rakTransportFailure, 1, READ_MAX_ATTEMPTS));
  Check('and again on the second attempt',
        ShouldRetryRead(rakTransportFailure, 2, READ_MAX_ATTEMPTS));
  //สามครั้งติดกันไม่ใช่เรื่องบังเอิญแล้ว
  Check('but not past the limit',
        not ShouldRetryRead(rakTransportFailure, 3, READ_MAX_ATTEMPTS));

  //อันนี้คือข้อที่ห้ามพลาด: ชิปที่ตอบมาไม่ครบกำลังบอกอะไรบางอย่าง
  //การสั่งซ้ำคือการถามใหม่จนกว่าจะได้คำตอบที่ชอบ
  Check('a short read is never repeated',
        not ShouldRetryRead(rakShortRead, 1, READ_MAX_ATTEMPTS));
  Check('and a complete read has nothing to repeat',
        not ShouldRetryRead(rakComplete, 1, READ_MAX_ATTEMPTS));

  //ศูนย์ครั้งแปลว่ายังไม่ได้ลองเลย ซึ่งเป็นความผิดพลาดของผู้เรียก
  Check('a zero attempt count is refused',
        not ShouldRetryRead(rakTransportFailure, 0, READ_MAX_ATTEMPTS));
  //เพดานเท่าทางเขียน ทั้งสองทางควรทนสายสะดุดได้เท่ากัน
  Check('the ceiling matches the write path', READ_MAX_ATTEMPTS = 3);
end;

procedure TestAlignErase;
var
  F, T: cardinal;
begin
  WriteLn('Erase planning: the range is rounded out to whole sectors');

  Check('a range inside one sector covers that sector',
        AlignEraseRange($1800, $100, 4096, 8 * 1024 * 1024, F, T) and
        (F = $1000) and (T = $2000));

  Check('a range crossing a boundary covers both sectors',
        AlignEraseRange($1FFF, 2, 4096, 8 * 1024 * 1024, F, T) and
        (F = $1000) and (T = $3000));

  Check('the end is clamped to the chip',
        AlignEraseRange($7FF000, $8000, 4096, 8 * 1024 * 1024, F, T) and
        (T = 8 * 1024 * 1024));

  //ความยาวที่บวกแล้วล้น cardinal ต้องไม่กลายเป็นช่วงสั้น ๆ ที่ดูปกติ
  Check('a length that would overflow is clamped, not wrapped',
        AlignEraseRange($7FF000, $FFFFFFFF, 4096, 8 * 1024 * 1024, F, T) and
        (F = $7FF000) and (T = 8 * 1024 * 1024));

  Check('a start past the end is refused',
        not AlignEraseRange(8 * 1024 * 1024, 4096, 4096, 8 * 1024 * 1024, F, T));
  Check('a zero length is refused',
        not AlignEraseRange(0, 0, 4096, 8 * 1024 * 1024, F, T));
  Check('a zero sector size is refused',
        not AlignEraseRange(0, 4096, 0, 8 * 1024 * 1024, F, T));
end;

procedure TestPlanUniform;
var
  Plan: TErasePlan;
begin
  WriteLn('Erase planning: one sector size for the whole chip');

  Check('four sectors are planned',
        PlanEraseUniform($1000, 4096 * 4, 4096, 8 * 1024 * 1024, $20, Plan) and
        (Length(Plan) = 4));
  Check('they start where they should', Plan[0].Addr = $1000);
  Check('they run on from each other', Plan[3].Addr = $1000 + 3 * 4096);
  Check('they all use the given opcode',
        (Plan[0].Opcode = $20) and (Plan[3].Opcode = $20));
  Check('the total is the range', PlanTotalBytes(Plan) = 4096 * 4);
end;

procedure TestPlanSectorMap;
var
  Info: TSFDPInfo;
  Plan: TErasePlan;
  F, T: cardinal;
  i, Small, Big: integer;
begin
  WriteLn('Erase planning: a boot block part is erased by its own map');
  SetFakeChip(fcBootBlock);
  Check('detected', SFDPDetect(Info));

  //ลบทั้งชิป ช่วงหัวและท้ายเป็นบล็อกเล็กที่ลบได้แค่ 4K
  //ส่วนตรงกลางลบได้ทีละ 64K ซึ่งใช้คำสั่งน้อยกว่ากันสิบหกเท่า
  Check('a whole chip erase is planned',
        PlanEraseSFDP(Info, 0, 8 * 1024 * 1024, 8 * 1024 * 1024, Plan));
  Check('it covers the whole chip', PlanTotalBytes(Plan) = 8 * 1024 * 1024);
  Check('it starts at zero and ends at the top',
        PlanBounds(Plan, F, T) and (F = 0) and (T = 8 * 1024 * 1024));

  Small := 0;
  Big := 0;
  for i := 0 to High(Plan) do
  begin
    if Plan[i].Size = 4096 then Inc(Small);
    if Plan[i].Size = 65536 then Inc(Big);
  end;

  //หัว 64K และท้าย 64K อย่างละ 16 เซกเตอร์ 4K ที่เหลือ 126 บล็อก 64K
  Check('the boot regions use 4K sectors', Small = 32);
  Check('the middle uses 64K blocks', Big = 126);
  Check('158 commands instead of 2048', Length(Plan) = 158);

  Check('the small sectors carry 20h', Plan[0].Opcode = $20);
  Check('the big blocks carry D8h', Plan[16].Opcode = $D8);
  Check('the big blocks start after the boot region', Plan[16].Addr = $10000);

  //ขอลบแค่ไม่กี่ไบต์กลางชิป ต้องไม่ลามไปลบทั้งบล็อก 64K
  //ถ้าเซกเตอร์ 4K ใช้ได้ตรงนั้น
  Check('a small request in the middle stays small',
        PlanEraseSFDP(Info, $100000, 100, 8 * 1024 * 1024, Plan));
  Check('it is one 4K sector',
        (Length(Plan) = 1) and (Plan[0].Size = 4096) and (Plan[0].Addr = $100000));

  //ชิปที่ไม่มีแผนผังต้องบอกว่าวางแผนแบบนี้ไม่ได้ ผู้เรียกจะได้ถอยไปใช้แบบเดิม
  SetFakeChip(fcWinbond64);
  Check('detected', SFDPDetect(Info));
  Check('a uniform part has no map to follow',
        not PlanEraseSFDP(Info, 0, 8 * 1024 * 1024, 8 * 1024 * 1024, Plan));
end;

// ------------------------------------------ the four byte address decision

//บั๊กที่เทสต์ชุดนี้ตรึงไว้คือการตัดสินจากความยาวของงาน แทนที่จะตัดสินจาก
//แอดเดรสสูงสุดที่งานนั้นแตะ ซึ่งทำให้การเขียนบางส่วนลงชิปใหญ่ไปลงผิดที่
procedure Test4ByteDecision;
const
  MB = 1024 * 1024;
begin
  WriteLn('Address width: a partial write high up a big chip still needs four bytes');

  //ภาพ 4MB เขียนลงชิป 32MB ที่แอดเดรส 16MB
  //ความยาวคือ 4MB ซึ่งเล็กกว่าขอบ 3 ไบต์ แต่แอดเดรสที่แตะคือ 16MB ถึง 20MB
  //ซึ่งเก็บด้วย 3 ไบต์ไม่ได้ ถ้าตัดสินผิดตรงนี้ ข้อมูลจะไปลงที่ 0 แทน
  Check('a 4 MB write at 16 MB on a 32 MB chip needs four byte addresses',
        Needs4ByteAddress(16 * MB, 4 * MB, 32 * MB));

  Check('so does the same write judged only by where it reaches',
        Needs4ByteAddress(16 * MB, 4 * MB, 0));

  //ชิปใหญ่ต้องใช้ 4 ไบต์เสมอ แม้งานจะแตะแค่เพจเดียวที่ต้นชิป
  //เพราะทางอ่าน ทางลบ และทางตรวจต้องอยู่ในโหมดเดียวกันทั้งหมด
  Check('one page at address zero on a 32 MB chip still uses four bytes',
        Needs4ByteAddress(0, 256, 32 * MB));

  //ชิปเล็กไม่ต้องใช้
  Check('a whole 8 MB chip does not', not Needs4ByteAddress(0, 8 * MB, 8 * MB));
  Check('a page at the top of a 16 MB chip does not',
        not Needs4ByteAddress(16 * MB - 256, 256, 16 * MB));

  //ขอบพอดี 16MB คือไบต์สุดท้ายที่แอดเดรส 3 ไบต์เข้าถึงได้
  Check('exactly 16 MB from zero still fits in three bytes',
        not Needs4ByteAddress(0, 16 * MB, 16 * MB));
  Check('one byte past it does not',
        Needs4ByteAddress(0, 16 * MB + 1, 16 * MB + 1));

  //ความยาวมั่ว ๆ ต้องไม่ล้นแล้วกลายเป็นช่วงสั้น ๆ ที่ดูปลอดภัย
  Check('an overflowing length cannot look small',
        Needs4ByteAddress($FFFFFF00, $FFFFFF00, 0));
end;

// ------------------------------------------------- SFDP declared timing

procedure TestSFDPTiming;
begin
  WriteLn('SFDP timing: the unit encodings');
  Check('erase units are 1, 16, 128 and 1000 ms',
        (SFDPEraseUnitMs(0) = 1) and (SFDPEraseUnitMs(1) = 16) and
        (SFDPEraseUnitMs(2) = 128) and (SFDPEraseUnitMs(3) = 1000));
  Check('program units are 8 and 64 us',
        (SFDPProgUnitUs(0) = 8) and (SFDPProgUnitUs(1) = 64));
  Check('chip erase units are 16, 256, 4000 and 64000 ms',
        (SFDPChipEraseUnitMs(0) = 16) and (SFDPChipEraseUnitMs(1) = 256) and
        (SFDPChipEraseUnitMs(2) = 4000) and (SFDPChipEraseUnitMs(3) = 64000));

  WriteLn('SFDP timing: the busy ceiling never goes below the floor');
  Check('a chip that said nothing keeps the old constant',
        BusyTimeoutMs(0, 30000, 600000) = 30000);
  Check('a chip that asked for less still gets the floor',
        BusyTimeoutMs(50, 30000, 600000) = 30000);
  Check('a chip that asked for more gets what it asked for',
        BusyTimeoutMs(90000, 30000, 600000) = 90000);
  Check('a corrupt table cannot park the program for an hour',
        BusyTimeoutMs(9999999, 30000, 600000) = 600000);
end;

// -------------------------------------------- vendor protection layouts

procedure TestVendorLayouts;
var
  P: TProtInfo;
  F, T: cardinal;
begin
  WriteLn('Protection: the layout is chosen from the manufacturer byte');
  Check('Winbond', LayoutOf($EF) = plWinbond);
  Check('GigaDevice follows Winbond', LayoutOf($C8) = plWinbond);
  Check('Macronix', LayoutOf($C2) = plMacronix);
  Check('ISSI follows Macronix', LayoutOf($9D) = plMacronix);
  Check('Micron', LayoutOf($20) = plMicron);
  Check('Spansion', LayoutOf($01) = plSpansion);
  Check('SST', LayoutOf($BF) = plSST);
  Check('anything else is unknown', LayoutOf($77) = plUnknown);

  //Macronix เก็บ BP ไว้สี่บิต การอ่านด้วยแผนผัง Winbond จะได้แค่สามบิต
  //แล้วรายงานพื้นที่ที่ถูกล็อกน้อยกว่าความจริง ซึ่งคือการปล่อยให้เขียนทับ
  WriteLn('Protection: Macronix keeps four protect bits, not three');
  P := DecodeProtEx($C2, %00101100, 0, %00001000);   //BP = 1011b = 11, TB จาก CR
  Check('all four bits were read', P.BP = 11);
  Check('the field is four bits wide', P.BPBits = 4);
  Check('SEC does not exist here', not P.SEC);
  Check('the direction came from the configuration register', P.TB);

  P := DecodeProt(%00101100, 0);                     //แผนผังเดิมของ Winbond
  Check('the Winbond reading of the same byte is only three bits', P.BP = 3);

  WriteLn('Protection: Macronix without the configuration register is honest');
  P := DecodeProtEx($C2, %00101100, 0, 0);
  Check('it says the extent is not known', not P.RangeKnown);
  P := DecodeProtEx($C2, %00000000, 0, 0);
  Check('but nothing locked is still perfectly knowable', P.RangeKnown);

  //Spansion ใช้บิต 6 กับ 5 เป็นธงความผิดพลาด อ่านเป็น SEC/TB คือได้ทิศทาง
  //การล็อกที่กลับหัวทุกครั้งที่คำสั่งก่อนหน้าล้มเหลว
  WriteLn('Protection: Spansion bits 6 and 5 are error flags, not SEC and TB');
  P := DecodeProtEx($01, %01100100, 0, 0);
  Check('SEC was not taken from bit 6', not P.SEC);
  Check('TB was not taken from bit 5', not P.TB);
  Check('BP is still three bits', (P.BP = 1) and (P.BPBits = 3));

  WriteLn('Protection: Micron puts BP3 at bit 6 and TB at bit 5');
  P := DecodeProtEx($20, %01100100, 0, 0);
  Check('BP3 was lifted out of bit 6', P.BP = 9);
  Check('TB came from bit 5', P.TB);

  //บนแผนผังสี่บิต BP = 7 เป็นค่ากลาง ๆ ไม่ใช่ "ล็อกทั้งชิป"
  WriteLn('Protection: BP=7 only means the whole chip on a three bit layout');
  P := DecodeProt(%00011100, 0);
  Check('three bit layout: the whole 8 MB chip is locked',
        ProtectedRange(P, 8 * 1024 * 1024, F, T) and (F = 0) and
        (T = 8 * 1024 * 1024 - 1));
  P := DecodeProtEx($C2, %00011100, 0, %00001000);
  Check('four bit layout: BP=7 is 4 MB from the bottom, not everything',
        ProtectedRange(P, 8 * 1024 * 1024, F, T) and (F = 0) and
        (T = 4 * 1024 * 1024 - 1));
end;

procedure TestSRLock;
var
  P: TProtInfo;
begin
  WriteLn('Protection: SRP1:SRP0 says why an unlock will not stick');
  P := DecodeProt(0, 0);
  Check('0:0 is a plain software unlock', SRLockState(P) = srlSoftware);
  Check('and it can be unlocked', CanUnlockBySoftware(P));

  P := DecodeProt($80, 0);
  Check('0:1 hands the decision to the WP# pin', SRLockState(P) = srlHardware);
  Check('which we still attempt', CanUnlockBySoftware(P));

  P := DecodeProt(0, $01);
  Check('1:0 is locked until the next power cycle',
        SRLockState(P) = srlPowerLock);
  Check('so software cannot unlock it', not CanUnlockBySoftware(P));

  P := DecodeProt($80, $01);
  Check('1:1 is permanent', SRLockState(P) = srlPermanent);
  Check('and no unlock will ever work', not CanUnlockBySoftware(P));
end;

procedure TestClearProtection;
var
  P: TProtInfo;
  N1, N2: byte;
begin
  WriteLn('Unlock: the protect bits go, everything else stays');

  //Winbond: BP=3, TB, SEC, SRP0 ทั้งหมดต้องหายไป
  //SR2 มี QE ติดอยู่ ซึ่งเป็นบิตที่ห้ามหาย บอร์ดที่บูตจากแฟลชในโหมด quad
  //จะบูตไม่ขึ้นอีกเลยถ้ามันถูกล้างไปพร้อมกับบิตป้องกัน
  P := DecodeProtEx($EF, %11101100, %00000010, 0);
  ClearProtection(P, %11101100, %00000010, N1, N2);
  Check('every protect bit in SR1 is gone', N1 = 0);
  Check('quad enable survived the unlock', (N2 and %00000010) <> 0);

  //CMP ต้องหายไปด้วย ไม่งั้นการล้าง BP จนเป็นศูนย์กลายเป็นล็อกทั้งชิป
  P := DecodeProtEx($EF, %00001100, %01000010, 0);
  ClearProtection(P, %00001100, %01000010, N1, N2);
  Check('CMP is cleared, or clearing BP would lock everything',
        (N2 and %01000000) = 0);
  Check('and quad enable still survived', (N2 and %00000010) <> 0);

  //WPS ไม่อยู่ใน SR2 (บิต 2 ของ SR2 เป็นบิตสงวน) การปลดล็อกจึงห้ามไปแตะ
  //บิตนั้น: ของจริงที่ปลดล็อกตระกูล WPS คือคำสั่ง global unlock 98h
  //ซึ่งอยู่ในเส้นทางปลดล็อกของ main ไม่ใช่การเขียน status register
  P := DecodeProtEx($EF, %00001100, %00000100, 0);
  ClearProtection(P, %00001100, %00000100, N1, N2);
  Check('the reserved SR2 bit 2 is left untouched',
        (N2 and %00000100) <> 0);

  //Macronix เก็บ QE ไว้ที่บิต 6 ของ SR1 ซึ่งเป็นบิตที่แผนผัง Winbond
  //เรียกว่า SEC และจะล้างทิ้ง การใช้หน้ากากผิดยี่ห้อจึงล้าง QE โดยไม่ตั้งใจ
  P := DecodeProtEx($C2, %11111100, 0, 0);
  ClearProtection(P, %11111100, 0, N1, N2);
  Check('Macronix: the four protect bits are gone',
        (N1 and %00111100) = 0);
  Check('Macronix: bit 6 is quad enable and was left alone',
        (N1 and %01000000) <> 0);
  Check('Macronix: the status register write protect bit is gone',
        (N1 and %10000000) = 0);

  //Spansion บิต 6:5 เป็นธงความผิดพลาดซึ่งเขียนไม่ได้ ต้องไม่ไปยุ่งกับมัน
  P := DecodeProtEx($01, %11111100, 0, 0);
  ClearProtection(P, %11111100, 0, N1, N2);
  Check('Spansion: BP is gone', (N1 and %00011100) = 0);
  Check('Spansion: the error flags were not touched',
        (N1 and %01100000) = %01100000);

  WriteLn('Unlock: telling whether it actually worked');
  Check('a chip with BP set is still protected',
        StillProtected(DecodeProt(%00001100, 0)));
  Check('a chip with CMP set is still protected',
        StillProtected(DecodeProt(0, %01000000)));
  Check('a chip with WPS set is still protected',
        StillProtected(DecodeProtVendor($EF, 0, 0, %00000100, True)));
  Check('a fully cleared chip is not', not StillProtected(DecodeProt(0, 0)));
  Check('quad enable on its own is not protection',
        not StillProtected(DecodeProt(0, %00000010)));
end;

procedure TestProgEraseFail;
begin
  WriteLn('Protection: program and erase failures the chip reports itself');

  //Micron flag status register 70h: bit 5 erase error, bit 4 program error
  //(MT25Q/N25Q datasheet -- the previous assignment was swapped)
  Check('Micron reports an erase failure from FSR bit 5',
        ProgEraseFail($20, 0, %00100000, True) = peErase);
  Check('Micron reports a program failure from FSR bit 4',
        ProgEraseFail($20, 0, %00010000, True) = peProgram);
  Check('Micron reports a protection failure',
        ProgEraseFail($20, 0, %00000010, True) = peProtect);
  Check('a clean Micron flag register is not a failure',
        ProgEraseFail($20, 0, %10000000, True) = peNone);
  Check('without the flag register Micron says nothing',
        ProgEraseFail($20, $FF, 0, False) = peNone);

  //Spansion อ่านจาก SR1 เอง
  Check('Spansion reports a program failure from SR1 bit 6',
        ProgEraseFail($01, %01000000, 0, False) = peProgram);
  Check('Spansion reports an erase failure from SR1 bit 5',
        ProgEraseFail($01, %00100000, 0, False) = peErase);

  //Macronix security register 2Bh
  Check('Macronix reports a program failure',
        ProgEraseFail($C2, 0, %00100000, True) = peProgram);
  Check('Macronix reports an erase failure',
        ProgEraseFail($C2, 0, %01000000, True) = peErase);

  //ห้ามตีความบิต SEC/TB ของ Winbond ว่าเป็นความผิดพลาด ไม่งั้นชิปที่ล็อก
  //ไว้ตามปกติจะถูกรายงานว่าเสียทุกตัว
  Check('a Winbond chip with SEC and TB set is not a failure',
        ProgEraseFail($EF, %01100000, $FF, True) = peNone);
  Check('an unknown vendor is never guessed at',
        ProgEraseFail($77, %01100000, $FF, True) = peNone);

  Check('Micron needs the flag status register', VendorStatusOpcode($20) = $70);
  Check('Macronix needs the security register', VendorStatusOpcode($C2) = $2B);
  Check('Winbond needs nothing extra', VendorStatusOpcode($EF) = 0);
end;

// ------------------------------------------------------- image sanity

procedure TestImgCheck;
var
  Buf, Buf2: array of byte;
  S: TImgStats;
  i: integer;
  R: TDiffRanges;
begin
  WriteLn('Image check: a dump that is all FF is named as such');
  SetLength(Buf, 4096);
  FillByte(Buf[0], 4096, $FF);
  S := ScanImage(@Buf[0], 4096);
  Check('every byte counted', S.FFCount = 4096);
  Check('one distinct value', S.DistinctBytes = 1);
  Check('zero entropy', S.Entropy < 0.0001);
  Check('the verdict is blank or absent', ImageVerdict(S) = ivAllErased);

  WriteLn('Image check: a dump that is all 00');
  FillByte(Buf[0], 4096, $00);
  S := ScanImage(@Buf[0], 4096);
  Check('the verdict is a silent data line', ImageVerdict(S) = ivAllZero);

  WriteLn('Image check: a wrapped address shows up as a repeat');
  SetLength(Buf, 4096);
  for i := 0 to 4095 do Buf[i] := byte(i * 7 + (i div 256));
  //ทำให้ครึ่งหลังซ้ำครึ่งแรก เหมือนแอดเดรสวนกลับที่ 2K
  for i := 2048 to 4095 do Buf[i] := Buf[i - 2048];
  S := ScanImage(@Buf[0], 4096);
  Check('the stride was found', S.RepeatStride = 2048);
  Check('the verdict is a wrapped address', ImageVerdict(S) = ivRepeats);
  Check('the message names the stride',
        Pos('2048', VerdictText(ivRepeats, S)) > 0);

  WriteLn('Image check: ordinary data is left alone');
  for i := 0 to 4095 do Buf[i] := byte(i * 31 + (i * i) div 17);
  S := ScanImage(@Buf[0], 4096);
  Check('no repeat claimed', S.RepeatStride = 0);
  Check('the verdict is fine', ImageVerdict(S) = ivOK);

  WriteLn('Image check: known signatures');
  SetLength(Buf, 1024);
  FillByte(Buf[0], 1024, 0);
  Buf[$10] := $5A; Buf[$11] := $A5; Buf[$12] := $F0; Buf[$13] := $0F;
  Check('an Intel flash descriptor is recognised',
        DetectImageKind(@Buf[0], 1024) = 'Intel flash descriptor');

  FillByte(Buf[0], 1024, 0);
  Buf[$28] := byte('_'); Buf[$29] := byte('F');
  Buf[$2A] := byte('V'); Buf[$2B] := byte('H');
  Check('a UEFI firmware volume is recognised',
        DetectImageKind(@Buf[0], 1024) = 'UEFI firmware volume');

  WriteLn('Image check: comparing two reads of the same chip');
  SetLength(Buf, 1024);
  SetLength(Buf2, 1024);
  for i := 0 to 1023 do begin Buf[i] := byte(i); Buf2[i] := byte(i); end;
  Check('identical reads have no first difference',
        FirstDifference(@Buf[0], @Buf2[0], 1024) = -1);
  Check('and no differing bytes',
        CountDifferences(@Buf[0], @Buf2[0], 1024) = 0);

  Buf2[100] := $FF; Buf2[101] := $FF; Buf2[500] := $00;
  Check('the first difference is found',
        FirstDifference(@Buf[0], @Buf2[0], 1024) = 100);
  Check('all three differing bytes are counted',
        CountDifferences(@Buf[0], @Buf2[0], 1024) = 3);

  R := DiffRanges(@Buf[0], @Buf2[0], 1024, 16);
  Check('adjacent differences collapse into one range', Length(R) = 2);
  Check('the first range is 100 to 101',
        (R[0].First = 100) and (R[0].Last = 101));
  Check('the second range is the single byte at 500',
        (R[1].First = 500) and (R[1].Last = 500));
end;

// ---------------------------------------------------------------- IFD

//แรงดันเป้าหมายของบอร์ด CH347Ⅱ V2.13
//
//ตรรกะล้วน ๆ ทดสอบได้โดยไม่ต้องมีเครื่องจริง ที่สำคัญที่สุดคือทิศทางความ
//ปลอดภัย: ทุกทางที่ตอบว่าไม่รู้หรือไม่รองรับ ต้องจบที่ 1.8V ไม่ใช่ 3.3V
procedure TestCH347Vcc;
var
  Bits: byte;
  Mv, MinMv, MaxMv: cardinal;
begin
  WriteLn('-- CH347 target voltage --');

  Check('3.3V drives GPIO6 low',
    CH347VccDataBits(CH347_VCC_3V3_MV, Bits) and (Bits = 0));
  Check('1.8V drives GPIO6 high',
    CH347VccDataBits(CH347_VCC_1V8_MV, Bits) and (Bits = CH347_GPIO_VCC));

  //ระดับที่บอร์ดจ่ายไม่ได้ต้องถูกปฏิเสธ ไม่ใช่ปัดเป็นค่าใกล้เคียง
  Check('5V rejected', not CH347VccDataBits(5000, Bits));
  Check('5V still leaves the safe level in Bits', Bits = CH347_GPIO_VCC);
  Check('2.5V rejected', not CH347VccDataBits(2500, Bits));
  Check('zero rejected', not CH347VccDataBits(0, Bits));

  //เลือกตามช่วงของชิป
  Check('1.8V part picks 1.8V',
    CH347VccForChip(1650, 1950, Mv) and (Mv = CH347_VCC_1V8_MV));
  Check('3.3V part picks 3.3V',
    CH347VccForChip(2700, 3600, Mv) and (Mv = CH347_VCC_3V3_MV));
  //ชิปที่กินได้ทั้งสองระดับต้องได้ค่าต่ำ จ่ายเกินทำชิปพัง จ่ายขาดแค่ลองใหม่
  Check('wide range prefers the lower rail',
    CH347VccForChip(1700, 3600, Mv) and (Mv = CH347_VCC_1V8_MV));
  Check('5V part has no usable rail', not CH347VccForChip(4500, 5500, Mv));
  Check('5V part still reports the safe level', Mv = CH347_VCC_1V8_MV);
  Check('empty range refuses to guess', not CH347VccForChip(0, 0, Mv));
  Check('inverted range refuses to guess', not CH347VccForChip(3600, 2700, Mv));

  //ช่องข้อความของแค็ตตาล็อกต้องแปลงเป็นช่วงเดิมกับที่ CLI เคยใช้
  Check('catalog 3.3 parses',
    VccRangeMv('3.3', MinMv, MaxMv) and (MinMv = 2700) and (MaxMv = 3600));
  Check('catalog 1.8V parses',
    VccRangeMv('1.8V', MinMv, MaxMv) and (MinMv = 1650) and (MaxMv = 1950));
  Check('catalog blank rejected', not VccRangeMv('', MinMv, MaxMv));
  Check('catalog junk rejected', not VccRangeMv('about 3 volts', MinMv, MaxMv));

  //ต่อกันทั้งสายแบบที่ GUI ใช้จริง: ข้อความ -> ช่วง -> ระดับ -> บิต
  Check('3.3 catalog entry ends up driving GPIO6 low',
    VccRangeMv('3.3', MinMv, MaxMv) and
    CH347VccForChip(MinMv, MaxMv, Mv) and
    CH347VccDataBits(Mv, Bits) and (Bits = 0));
  Check('1.8 catalog entry ends up driving GPIO6 high',
    VccRangeMv('1.8', MinMv, MaxMv) and
    CH347VccForChip(MinMv, MaxMv, Mv) and
    CH347VccDataBits(Mv, Bits) and (Bits = CH347_GPIO_VCC));

  //สองขานี้ต้องไม่ทับกัน ไม่งั้นสลับแรงดันทีไรไฟกะพริบตาม
  Check('vcc and led pins are distinct',
    (CH347_GPIO_VCC and CH347_GPIO_ACT_LED) = 0);

  //ตัวตัดสินคำแนะนำหลังรู้จักชิป: ใช้เลือกข้อความชี้ทาง ไม่ใช่สลับไฟเอง
  //ทุกทางที่ไม่รู้ต้องทิ้ง WantMv ไว้ที่ 1.8V เหมือนผู้ช่วยตัวอื่น
  Mv := 12345;
  Check('advice: blank catalog text is unknown',
    (CH347VccAdvise('', 0, Mv) = cvaChipVccUnknown) and
    (Mv = CH347_VCC_1V8_MV));
  Check('advice: junk catalog text is unknown',
    CH347VccAdvise('about 3 volts', CH347_VCC_3V3_MV, Mv) = cvaChipVccUnknown);
  Mv := 12345;
  Check('advice: 5V part has no usable rail',
    (CH347VccAdvise('5', CH347_VCC_3V3_MV, Mv) = cvaNoUsableRail) and
    (Mv = CH347_VCC_1V8_MV));
  Check('advice: 2.5V part has no usable rail',
    CH347VccAdvise('2.5', 0, Mv) = cvaNoUsableRail);
  Check('advice: auto resolves a 1.8 part to 1.8',
    (CH347VccAdvise('1.8', 0, Mv) = cvaAutoWillApply) and
    (Mv = CH347_VCC_1V8_MV));
  Check('advice: auto resolves a 3.3 part to 3.3',
    (CH347VccAdvise('3.3', 0, Mv) = cvaAutoWillApply) and
    (Mv = CH347_VCC_3V3_MV));
  Check('advice: pinned level inside the chip range is fine',
    CH347VccAdvise('1.8', CH347_VCC_1V8_MV, Mv) = cvaPinnedMatches);
  Check('advice: 3.3 pinned on a 1.8 part is the dangerous direction',
    (CH347VccAdvise('1.8', CH347_VCC_3V3_MV, Mv) = cvaPinnedTooHigh) and
    (Mv = CH347_VCC_1V8_MV));
  Check('advice: 1.8 pinned on a 3.3 part is only mute, never fatal',
    (CH347VccAdvise('3.3', CH347_VCC_1V8_MV, Mv) = cvaPinnedTooLow) and
    (Mv = CH347_VCC_3V3_MV));

  //ข้อความระดับแรงดันต้องสะกดตรงกับเมนู และห้ามแปรตาม locale
  Check('level text 1.8', CH347VccLevelText(CH347_VCC_1V8_MV) = '1.8 V');
  Check('level text 3.3', CH347VccLevelText(CH347_VCC_3V3_MV) = '3.3 V');
  Check('level text of an odd value stays raw millivolts',
    CH347VccLevelText(2500) = '2500 mV');

  //ข้อความแรงดันจากแค็ตตาล็อก: เติมหน่วยเมื่อไม่มี คงเดิมเมื่อมีแล้ว
  Check('catalog display adds the unit', CatalogVccDisplay('1.8') = '1.8 V');
  Check('catalog display keeps an existing unit',
    CatalogVccDisplay(' 3.3V ') = '3.3V');
  Check('catalog display of blank stays blank', CatalogVccDisplay('  ') = '');

  //ตัวหาแรงดันสามชั้น: ช่อง vcc ชนะเสมอ แล้วค่อยดูท้ายชื่อรุ่น แล้วค่อย
  //ดูรหัส JEDEC และห้ามสรุปเป็น 3.3 จากรหัสเด็ดขาด
  Check('vcc resolver: the catalog field wins over everything',
    ChipVccText('3.3', 'SOMENAME_1.8V', 'EF6017') = '3.3');
  Check('vcc resolver: 1.8V name suffix',
    ChipVccText('', 'W25Q80BW_1.8V', '') = '1.8');
  Check('vcc resolver: 3.3V name suffix',
    ChipVccText('', 'SOMECHIP_3.3V', '') = '3.3');
  Check('vcc resolver: EF60 id is a 1.8V family even without a telltale name',
    ChipVccText('', 'W25Q64JW', 'EF6017') = '1.8');
  Check('vcc resolver: an MX25U name is 1.8V by the name rule',
    ChipVccText('', 'MX25U6435F', 'C22537') = '1.8');
  //C225 ห้ามตัดสินจากรหัส: MX25L6439E (3V) ใช้รหัสเดียวกับ MX25U6435F
  Check('vcc resolver: a 3V MX25L sharing the C225 id stays unknown',
    ChipVccText('', 'MX25L6439E', 'C22537') = '');
  Check('vcc resolver: a lower-case id still matches',
    ChipVccText('', '', 'ef6017') = '1.8');
  Check('vcc resolver: a 3.3V-family id is never guessed at',
    ChipVccText('', 'W25Q64JV', 'EF4017') = '');
  Check('vcc resolver: a short id is not matched',
    ChipVccText('', 'CHIP', 'EF6') = '');
  Check('vcc resolver: unknown everything stays empty',
    ChipVccText('', '', '') = '');
end;

procedure TestIFD;
var
  Buf: array of byte;
  Map: TIFDMap;
  R: TIFDRegion;
  Txt: string;

  procedure PutDword(Off, V: cardinal);
  begin
    Buf[Off]     := byte(V);
    Buf[Off + 1] := byte(V shr 8);
    Buf[Off + 2] := byte(V shr 16);
    Buf[Off + 3] := byte(V shr 24);
  end;

begin
  WriteLn('Intel flash descriptor: the region table');
  SetLength(Buf, 4096);
  FillByte(Buf[0], 4096, $FF);
  PutDword($10, IFD_SIGNATURE);
  PutDword($14, $00040000);      //FRBA = 40h
  PutDword($40, $00000000);      //fd:   0x000000..0x000FFF
  PutDword($44, $0FFF0500);      //bios: 0x500000..0xFFFFFF
  PutDword($48, $04FF0001);      //me:   0x001000..0x4FFFFF
  PutDword($4C, $00007FFF);      //gbe: unused, by convention
  PutDword($50, $00007FFF);
  PutDword($54, $00007FFF);
  PutDword($58, $00007FFF);
  PutDword($5C, $00007FFF);
  PutDword($60, $00007FFF);
  PutDword($64, $00007FFF);

  Check('a well formed descriptor parses', ParseIFD(@Buf[0], 4096, Map));
  Check('fd is 0..0xFFF',
        Map.Regions[0].Used and (Map.Regions[0].Base = 0) and
        (Map.Regions[0].Limit = $FFF));
  Check('bios is 0x500000..0xFFFFFF and the name lookup ignores case',
        IFDRegionByName(Map, 'BIOS', R) and (R.Base = $500000) and
        (R.Limit = $FFFFFF));
  Check('me is 0x1000..0x4FFFFF',
        IFDRegionByName(Map, 'me', R) and (R.Base = $1000) and
        (R.Limit = $4FFFFF));
  Check('an unused region is refused by name', not IFDRegionByName(Map, 'gbe', R));
  Check('an unknown name is refused', not IFDRegionByName(Map, 'bogus', R));

  Txt := IFDDescribe(Map, 16 * 1024 * 1024);
  Check('the table names bios', Pos('bios', Txt) > 0);
  Check('nothing exceeds a 16 MB dump', Pos('past the end', Txt) = 0);
  Txt := IFDDescribe(Map, 8 * 1024 * 1024);
  Check('a region past an 8 MB dump is flagged',
        Pos('past the end', Txt) > 0);

  //ดัมป์สั้น (เฉพาะเพจ descriptor) ยังต้องอ่านตารางได้ครบ
  Check('a 4 KB descriptor-only dump still parses',
        ParseIFD(@Buf[0], 4096, Map) and IFDRegionByName(Map, 'bios', R));

  Buf[$10] := 0;
  Check('a broken signature does not parse',
        not ParseIFD(@Buf[0], 4096, Map));
  PutDword($10, IFD_SIGNATURE);

  //ตารางที่ไม่มี region ใช้จริงสักช่องคือลายเซ็นที่บังเอิญตรง ไม่ใช่ descriptor
  PutDword($40, $00007FFF);
  PutDword($44, $00007FFF);
  PutDword($48, $00007FFF);
  Check('a descriptor with no used region does not parse',
        not ParseIFD(@Buf[0], 4096, Map));
end;

// -------------------------------- the erase planner, over random inputs

//แผนการลบคือที่ที่บั๊กทำให้ข้อมูลของคนอื่นหายจริง ๆ การทดสอบด้วยตัวอย่าง
//ที่เลือกมาเองจะเจอเฉพาะสิ่งที่คนเขียนนึกออก ตรงนี้จึงยิงค่าสุ่มใส่แล้ว
//ตรวจคุณสมบัติที่ต้องเป็นจริงเสมอ ไม่ว่าค่าที่เข้าไปจะเป็นอะไร
procedure TestPlanProperties;
const
  ROUNDS = 3000;
var
  Info: TSFDPInfo;
  Plan: TErasePlan;
  ChipSize, Start, Len, F, T: cardinal;
  i, r, RegionCount: integer;
  Ok, Contiguous, Aligned, InBounds, Covers: boolean;
  Bad: string;
begin
  WriteLn('Erase planner: properties that must hold for any request');
  RandSeed := 20260727;
  Bad := '';

  for r := 1 to ROUNDS do
  begin
    FillChar(Info, SizeOf(Info), 0);
    Info.Valid := True;
    Info.HasSectorMap := True;

    //ชนิดการลบมาตรฐาน 4K, 32K, 64K
    Info.EraseTypes[1].Size := 4096;   Info.EraseTypes[1].Opcode := $20;
    Info.EraseTypes[2].Size := 32768;  Info.EraseTypes[2].Opcode := $52;
    Info.EraseTypes[3].Size := 65536;  Info.EraseTypes[3].Opcode := $D8;

    //แผนผังแบบสุ่ม: ช่วงหัวและท้ายใช้ 4K ช่วงกลางใช้ได้ทุกขนาด
    RegionCount := 1 + Random(3);
    ChipSize := 0;
    for i := 0 to RegionCount - 1 do
    begin
      Info.Regions[i].Size := cardinal(1 + Random(16)) * 65536;
      if Random(2) = 0 then
        Info.Regions[i].EraseTypeMask := %0001     //4K เท่านั้น
      else
        Info.Regions[i].EraseTypeMask := %0111;    //4K, 32K, 64K
      Inc(ChipSize, Info.Regions[i].Size);
    end;
    Info.RegionCount := RegionCount;
    Info.Density := ChipSize;

    Start := cardinal(Random(integer(ChipSize)));
    Len   := 1 + cardinal(Random(integer(ChipSize)));

    if not PlanEraseSFDP(Info, Start, Len, ChipSize, Plan) then Continue;

    //1. ทุกขั้นต้องอยู่บนขอบของก้อนขนาดของตัวเอง
    //   ลบก้อนที่แอดเดรสไม่ตรงขอบ ชิปจะปัดลงเอง แล้วไปลบของที่อยู่ข้างล่าง
    Aligned := True;
    for i := 0 to High(Plan) do
      if (Plan[i].Size = 0) or ((Plan[i].Addr mod Plan[i].Size) <> 0) then
        Aligned := False;
    if not Aligned then Bad := 'a step was not aligned to its own size';

    //2. ขั้นต้องต่อกันสนิท ไม่ทับกัน ไม่มีรู
    Contiguous := True;
    for i := 1 to High(Plan) do
      if Plan[i].Addr <> Plan[i-1].Addr + Plan[i-1].Size then Contiguous := False;
    if not Contiguous then Bad := 'the steps were not contiguous';

    //3. ห้ามเลยขอบชิป
    InBounds := PlanBounds(Plan, F, T) and (T <= ChipSize);
    if not InBounds then Bad := 'the plan ran past the end of the chip';

    //4. ต้องครอบคลุมสิ่งที่ผู้ใช้ขอให้ลบทั้งหมด
    //   แผนที่กินน้อยกว่าที่ขอแปลว่าเหลือข้อมูลเก่าค้างอยู่ แล้วการเขียนทับ
    //   ลงไปจะได้ผลที่ไม่มีใครอธิบายได้
    Covers := (F <= Start) and
              (int64(T) >= Min(int64(Start) + int64(Len), int64(ChipSize)));
    if not Covers then Bad := 'the plan did not cover the requested range';

    //5. ผลรวมต้องเท่ากับช่วงที่ครอบคลุม ซึ่งตามมาจากข้อ 2 แต่ตรวจไว้อีกชั้น
    if PlanTotalBytes(Plan) <> (T - F) then
      Bad := 'the byte total did not match the bounds';

    if Bad <> '' then
    begin
      WriteLn(Format('    round %d: chip=%d start=%d len=%d regions=%d',
                     [r, ChipSize, Start, Len, RegionCount]));
      Break;
    end;
  end;

  Ok := Bad = '';
  Check(Format('%d random requests all planned correctly', [ROUNDS]), Ok);
  if not Ok then WriteLn('    ', Bad);
end;

// ------------------------------------------ real SFDP tables, decoded offline

//ค่าที่ manifest คาดไว้สำหรับตารางหนึ่งตาราง
function ExpectedValue(const Line, Key: string; out Value: string): boolean;
var
  P: integer;
  Rest: string;
begin
  Value := '';
  P := Pos(' ' + Key + '=', ' ' + Line);
  if P = 0 then Exit(False);

  Rest := Copy(' ' + Line, P + Length(Key) + 2, MaxInt);
  P := Pos(' ', Rest);
  if P > 0 then Rest := Copy(Rest, 1, P - 1);
  Value := Trim(Rest);
  Result := Value <> '';
end;

//เทียบตารางหนึ่งตารางกับบรรทัดหนึ่งบรรทัดของ manifest
procedure CheckFixture(const FileName, Line: string);
var
  F: TFileStream;
  Buf: array of byte;
  Info: TSFDPInfo;
  V: string;

  procedure Want(const Key: string; Actual: int64);
  var
    Exp: int64;
    S: string;
  begin
    if not ExpectedValue(Line, Key, S) then Exit;
    Exp := StrToInt64Def(S, -1);
    Check(Format('%s: %s is %d', [ExtractFileName(FileName), Key, Exp]),
          Actual = Exp);
  end;

  procedure WantHex(const Key: string; Actual: byte);
  var
    S: string;
  begin
    if not ExpectedValue(Line, Key, S) then Exit;
    Check(Format('%s: %s is %s', [ExtractFileName(FileName), Key, S]),
          UpperCase(IntToHex(Actual, 2)) = UpperCase(S));
  end;

  procedure WantErase(const Key: string; Idx: integer);
  var
    S, SizePart, OpPart: string;
    P: integer;
  begin
    if not ExpectedValue(Line, Key, S) then Exit;
    P := Pos('/', S);
    SizePart := Copy(S, 1, P - 1);
    OpPart := Copy(S, P + 1, MaxInt);
    Check(Format('%s: %s is %s', [ExtractFileName(FileName), Key, S]),
          (Info.EraseTypes[Idx].Size = cardinal(StrToInt64Def(SizePart, -1))) and
          (UpperCase(IntToHex(Info.EraseTypes[Idx].Opcode, 2)) = UpperCase(OpPart)));
  end;

begin
  F := TFileStream.Create(FileName, fmOpenRead or fmShareDenyNone);
  try
    SetLength(Buf, F.Size);
    if F.Size > 0 then F.ReadBuffer(Buf[0], F.Size);
  finally
    F.Free;
  end;

  if not SFDPDetectFromBuffer(@Buf[0], Length(Buf), Info) then
  begin
    Check(ExtractFileName(FileName) + ': decoded', False);
    Exit;
  end;
  Check(ExtractFileName(FileName) + ': decoded', True);

  Want('density', Info.Density);
  Want('page', Info.PageSize);
  Want('addr', Info.AddrBytes);
  Want('regions', Info.RegionCount);

  if ExpectedValue(Line, 'sectormap', V) then
    Check(ExtractFileName(FileName) + ': sector map presence',
          Info.HasSectorMap = (V = '1'));
  if ExpectedValue(Line, 'uniform', V) then
    Check(ExtractFileName(FileName) + ': uniform flag',
          Info.Uniform = (V = '1'));
  if ExpectedValue(Line, 'timing', V) then
    Check(ExtractFileName(FileName) + ': declared timing present',
          Info.HasTiming = (V = '1'));

  WantErase('erase1', 1);
  WantErase('erase2', 2);
  WantErase('erase3', 3);

  WantHex('read4b', Info.Read4BOpcode);
  WantHex('fastread4b', Info.FastRead4BOpcode);
  WantHex('prog4b', Info.PageProg4BOpcode);
  WantHex('erase1op4b', Info.EraseTypes[1].Opcode4B);
  WantHex('erase3op4b', Info.EraseTypes[3].Opcode4B);

  //ตารางที่แจ้งเวลามาต้องได้เพดานรอที่ใช้ได้จริง ไม่ใช่ศูนย์หรือค่ามหาศาล
  if Info.HasTiming then
  begin
    Check(ExtractFileName(FileName) + ': the page program ceiling is sane',
          (Info.PageProgTimeMaxMs > 0) and (Info.PageProgTimeMaxMs < 60000));
    Check(ExtractFileName(FileName) + ': the chip erase ceiling is sane',
          (Info.ChipEraseTimeMaxMs > 0) and (Info.ChipEraseTimeMaxMs < 3600000));
  end;
end;

//ไล่ทุกตารางที่วางไว้ใน tests\sfdp
//
//ตารางที่ดัมป์มาจากชิปจริงด้วย --sfdp-dump วางลงไปได้เลย เติมหนึ่งบรรทัดใน
//manifest แล้วมันจะกลายเป็นเทสต์กันการถอยหลังของชิปตัวนั้นตลอดไป โดยที่
//คนที่รันเทสต์ไม่ต้องมีชิปตัวนั้นอยู่ในมือ
procedure TestSFDPCorpus;
var
  Dir, Line, FileName: string;
  Manifest: TextFile;
  Count: integer;
begin
  WriteLn('SFDP corpus: tables decoded straight from a file');

  Dir := 'sfdp' + DirectorySeparator;
  if not FileExists(Dir + 'manifest.txt') then
  begin
    WriteLn('  --   no corpus next to the test, skipped');
    Exit;
  end;

  Count := 0;
  AssignFile(Manifest, Dir + 'manifest.txt');
  Reset(Manifest);
  try
    while not Eof(Manifest) do
    begin
      ReadLn(Manifest, Line);
      Line := Trim(Line);
      if (Line = '') or (Line[1] = '#') then Continue;

      FileName := Dir + Copy(Line, 1, Pos(' ', Line + ' ') - 1);
      if not FileExists(FileName) then
      begin
        Check('the manifest names a file that is there: ' + FileName, False);
        Continue;
      end;

      CheckFixture(FileName, Line);
      Inc(Count);
    end;
  finally
    CloseFile(Manifest);
  end;

  Check(Format('%d tables in the corpus were all decoded', [Count]), Count > 0);
end;

// -------------------------------------------------- WCH device classification

procedure TestWCHDeviceKind;
const
  //พาธจริงที่ CH341GetDeviceName คืนมาตอนเสียบ CH347T ไว้ตัวเดียว
  CH347T = '\\?\usb#vid_1a86&pid_55db&mi_02#7&2887b016&0&0002#' +
           '{5446f048-98b4-4ef0-96e8-27994bac0d00}';
  CH341A = '\\?\usb#vid_1a86&pid_5512#6&1a2b3c4d&0&1#' +
           '{5446f048-98b4-4ef0-96e8-27994bac0d00}';
begin
  WriteLn('WCH: telling CH341 and CH347 apart by device path');

  Check('a CH347T is not a CH341',
        WCHDeviceKindFromPath(CH347T) = wchCH347);
  Check('a CH341A still reads as a CH341',
        WCHDeviceKindFromPath(CH341A) = wchCH341);
  Check('CH341PAR''s 5584 also reads as a CH341',
        WCHDeviceKindFromPath('\\?\usb#vid_1a86&pid_5584#x') = wchCH341);
  Check('CH347F reads as a CH347',
        WCHDeviceKindFromPath('\\?\usb#vid_1a86&pid_55de#x') = wchCH347);
  Check('upper case paths classify the same',
        WCHDeviceKindFromPath('\\?\USB#VID_1A86&PID_55DB#X') = wchCH347);
  //ไม่รู้จักต้องคืน unknown ไม่ใช่เดา ผู้เรียกจะได้ปล่อยผ่านตามพฤติกรรมเดิม
  Check('an unlisted PID is unknown, not guessed',
        WCHDeviceKindFromPath('\\?\usb#vid_1a86&pid_7523#x') = wchUnknown);
  Check('a path with no PID is unknown',
        WCHDeviceKindFromPath('\\?\usb#nothing') = wchUnknown);
  Check('an empty path is unknown',
        WCHDeviceKindFromPath('') = wchUnknown);
  Check('a truncated PID is unknown',
        WCHDeviceKindFromPath('\\?\usb#vid_1a86&pid_55') = wchUnknown);
  Check('a non-hex PID is unknown',
        WCHDeviceKindFromPath('\\?\usb#vid_1a86&pid_zzzz#x') = wchUnknown);
end;

// ------------------------------------------------ CH347 backend device gate

//ตัวหาแรงดันสามชั้น
//
//ชั้นที่สามคือหัวใจ: chiplist.xml กรอกช่อง vcc ไว้แค่ 5 จาก 658 รายการ
//ถ้าดูช่องนั้นอย่างเดียว ชิป 1.8V เกือบทั้งหมดจะหลุดด่านเตือนไปเงียบ ๆ
procedure TestChipVccText;
begin
  WriteLn('-- chip voltage resolver --');

  //ชั้น 1: ช่อง vcc ชนะเสมอ
  Check('catalog vcc wins over everything',
    ChipVccText('3.3', 'W74M12JW_1.8V', 'EF6018') = '3.3');

  //ชั้น 2: ส่วนท้ายชื่อรุ่น
  Check('name suffix 1.8V is read',
    ChipVccText('', 'W74M12JW_1.8V', '') = '1.8');
  Check('name suffix 3.3V is read',
    ChipVccText('', 'MX25L6433F_3.3V', '') = '3.3');

  //ชั้น 2.5: ตระกูลที่สะกดแรงดันไว้ในชื่อ Macronix MX25U/MX66U คือ 1.8V
  //ต้องตัดสินจากชื่อ ไม่ใช่รหัส เพราะรหัส C225xx ถูกใช้ปนกับ MX25L (3V)
  //และ MX25V (ช่วงกว้าง)
  Check('Macronix MX25U name is 1.8V',
    ChipVccText('', 'MX25U6435F', 'C22537') = '1.8');
  Check('Macronix MX66U name is 1.8V',
    ChipVccText('', 'MX66U51235F', 'C2253A') = '1.8');
  Check('a 3V MX25L on the same C225 id stays unknown',
    ChipVccText('', 'MX25L3239E', 'C22536') = '');
  Check('a wide-range MX25V on a C225 id stays unknown',
    ChipVccText('', 'MX25V4035', 'C22553') = '');

  //ชั้น 3: รหัส JEDEC ของตระกูล 1.8V ที่ชื่อรุ่นไม่ได้บอก
  //นี่คือกลุ่มที่ของเดิมพลาดทั้งหมด
  Check('Winbond EF60xx is 1.8V even when the name is silent',
    ChipVccText('', 'W25Q64FW', 'EF6017') = '1.8');
  Check('Winbond EF80xx is 1.8V',
    ChipVccText('', 'W25Q64JW-IM', 'EF8017') = '1.8');
  Check('GigaDevice C860xx is 1.8V',
    ChipVccText('', 'GD25LQ32', 'C86016') = '1.8');
  Check('lower case id still matches',
    ChipVccText('', 'W25Q64FW', 'ef6017') = '1.8');

  //ตระกูลที่เพิ่มหลังไล่ตรวจแค็ตตาล็อกทั้งสี่ไฟล์
  Check('Micron MT25QU (20BB) is 1.8V without any name marker',
    ChipVccText('', 'MT25QU256', '20BB19') = '1.8');
  Check('ISSI IS25WQ (9D12) is 1.8V',
    ChipVccText('', 'IS25WQ040', '9D1253') = '1.8');
  Check('GigaDevice GD25LB..ME (C867) is 1.8V',
    ChipVccText('', 'GD25LB512ME', 'C8671A') = '1.8');
  Check('Winbond W77Q secure flash (EF8A) is 1.8V',
    ChipVccText('', 'W77Q64JW', 'EF8A17') = '1.8');

  //ห้ามสรุป 3.3V จากรหัส เดาสูงเกินคือทิศที่ทำชิปพัง
  Check('a 3.3V family id stays unknown, never guessed high',
    ChipVccText('', 'W25Q64', 'EF4017') = '');
  Check('an unknown id stays unknown',
    ChipVccText('', 'SOMECHIP', '123456') = '');
  Check('everything empty stays unknown',
    ChipVccText('', '', '') = '');
  Check('a short id does not crash the prefix test',
    ChipVccText('', 'X', 'EF') = '');
end;

procedure TestCH347Gate;
const
  CH347Path = '\\?\usb#vid_1a86&pid_55db&mi_02#7&2887b016&0&0002#{guid}';
  CH341Path = '\\?\usb#vid_1a86&pid_5512#6&1a2b3c4d&0&1#{guid}';
begin
  WriteLn('CH347: deciding which opened devices the backend keeps');

  Check('a CH347T is kept',
        CH347GateAccepts(CH347_CHIP_CH347T, CH347Path));
  Check('a CH347F is kept',
        CH347GateAccepts(CH347_CHIP_CH347F, CH347Path));
  Check('a CH339W is kept',
        CH347GateAccepts(CH347_CHIP_CH339W, ''));

  //หัวใจของบั๊ก: CH347GetChipType คืน 0 ทั้งตอนเป็น CH341 และตอนถามไม่สำเร็จ
  //ถ้าเชื่อ 0 อย่างเดียว CH347 ของจริงจะถูกปิดทิ้งและเครื่องหายไปทั้งตัว
  Check('chip type 0 with a CH347 path is kept, not mistaken for a CH341',
        CH347GateAccepts(CH347_CHIP_CH341, CH347Path));
  Check('chip type 0 with an unreadable path is kept',
        CH347GateAccepts(CH347_CHIP_CH341, ''));
  Check('chip type 0 with an unlisted PID is kept',
        CH347GateAccepts(CH347_CHIP_CH341, '\\?\usb#vid_1a86&pid_7523#x'));

  //ปฏิเสธได้ทางเดียวคือ PID ยืนยันว่าเป็น CH341 จริง
  Check('chip type 0 with a real CH341 path is rejected',
        not CH347GateAccepts(CH347_CHIP_CH341, CH341Path));
  Check('a CH341 path is rejected even when the chip type is unknown',
        not CH347GateAccepts(CH347_CHIP_UNKNOWN, CH341Path));

  //DLL รุ่นเก่าไม่มี export ตัวนี้ ต้องคงพฤติกรรมเดิมคือรับไว้ก่อน
  Check('an old DLL that cannot answer keeps the device',
        CH347GateAccepts(CH347_CHIP_UNKNOWN, ''));
  Check('an old DLL with a CH347 path keeps the device',
        CH347GateAccepts(CH347_CHIP_UNKNOWN, CH347Path));
end;

begin
  WriteLn('AsProgrammer ProX unit tests');
  WriteLn;

  TestWCHDeviceKind;
  TestCH347Gate;
  TestSFDPWinbond;
  TestSFDPNoSignature;
  TestSFDPPowerOfTwoDensity;
  TestSFDPDword16;
  TestSFDP4BAIT;
  TestSFDPUniformHasNoMap;
  TestSFDPSectorMap;
  TestProtBits;
  TestOpResult;
  TestProdLog;
  TestJobFile;
  TestJedec;
  TestSerial;
  TestBlockLocks;
  TestFirstChunk;
  TestReadRetry;
  TestAlignErase;
  TestPlanUniform;
  TestPlanSectorMap;
  TestPlanProperties;
  Test4ByteDecision;
  TestSFDPTiming;
  TestVendorLayouts;
  TestSRLock;
  TestClearProtection;
  TestProgEraseFail;
  TestImgCheck;
  TestIFD;
  TestCH347Vcc;
  TestChipVccText;
  TestSFDPCorpus;

  WriteLn;
  if Failures = 0 then
    WriteLn('ALL PASSED')
  else
    WriteLn(Failures, ' FAILURES');
  Halt(Failures);
end.
