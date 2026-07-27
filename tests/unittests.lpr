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
  SysUtils, sfdp, jedec, serialnum, spi25, protbits, opresult, prodlog, flashops;

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

  // CMP กลับด้าน BP=0 กลายเป็นล็อกทั้งชิป
  P := DecodeProt($00, $40);
  Check('CMP is set', P.CMP);
  Check('the whole chip is protected', ProtectedRange(P, MB8, FromA, ToA));
  Check('from the first to the last byte', (FromA = 0) and (ToA = MB8 - 1));

  // SRP1 กับ WPS อ่านจากไบต์ที่สอง
  P := DecodeProt($00, $05);
  Check('SRP1 is set', P.SRP1);
  Check('WPS is set', P.WPS);

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

begin
  WriteLn('AsProgrammer ProX unit tests');
  WriteLn;

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
  TestAlignErase;
  TestPlanUniform;
  TestPlanSectorMap;

  WriteLn;
  if Failures = 0 then
    WriteLn('ALL PASSED')
  else
    WriteLn(Failures, ' FAILURES');
  Halt(Failures);
end.
