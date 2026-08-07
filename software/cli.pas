unit cli;

//โหมดสั่งงานผ่านบรรทัดคำสั่ง
//
//โปรแกรมนี้เป็น GUI จึงไม่มีคอนโซลมาให้ ต้องไปเกาะคอนโซลของตัวที่เรียกเราเอง
//ถ้าถูกเรียกจาก cmd หรือ PowerShell ข้อความจะไปโผล่ที่หน้าต่างนั้น
//
//งานจริงยังใช้โค้ดชุดเดียวกับปุ่มบนหน้าจอ หน้าต่างหลักถูกสร้างแต่ไม่ถูกแสดง
//วิธีนี้ทำให้ไม่มีโค้ดสองชุดที่ต้องดูแลให้ตรงกัน
//
//รหัสออกจากโปรแกรมคือสัญญาที่สายการผลิตใช้ตัดสิน
//  0  สำเร็จ
//  1  งานล้มเหลว เช่น เขียนแล้วอ่านกลับไม่ตรง หรือชิปยังถูกล็อกอยู่
//  2  เรียกใช้ผิด เช่น สวิตช์ที่ไม่รู้จัก หรือหาไฟล์ไม่เจอ

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

//มีอาร์กิวเมนต์ที่เป็นคำสั่งหรือไม่ ถ้าไม่มีก็เปิดหน้าต่างตามปกติ
function WantsCLI: boolean;

//รันคำสั่งแล้วคืนรหัสออกจากโปรแกรม 0 คือสำเร็จ
function RunCLI: integer;

implementation

uses
  Windows, Forms, main, basehw, fileformats, findchip, sfdp, jedec, appver,
  opresult, prodlog, serialnum, spi25, utilfunc, imgcheck, ifd, DateUtils,
  prodcrypto, prodjob, prodstate, productiongate, electricalpreflight,
  railreport, clicontract,
  safemode,
  chipprofile, chipsave,
  nandmodel, nandplanner, nandengine, spi25nandadapter, nandcatalog;

const
  EXIT_OK    = 0;
  EXIT_FAIL  = 1;
  EXIT_USAGE = 2;

  //สวิตช์ที่ตามด้วยค่า
  ValueSwitches: array[0..24] of string = (
    'chip', 'hw', 'read', 'write', 'verify', 'job', 'operator', 'log', 'save-chip',
    'read-passes', 'sfdp-dump', 'sfdp-decode', 'compare', 'scan',
    'prod-job', 'prod-auth', 'prod-key-id', 'prod-key-env', 'evidence-dir',
    'export-chip', 'region', 'nand-read', 'nand-write', 'nand-bad-policy',
    'nand-backup'
  );

  //สวิตช์ที่เป็นธงเปล่า ๆ
  FlagSwitches: array[0..17] of string = (
    'erase', 'detect', 'sfdp', 'help', 'force', 'json', 'verify',
    'no-fast-read', 'smart', 'plan-only', 'nand-info', 'nand-raw',
    'chip-test', 'capacity-test', 'surface-scan', 'nand-erase',
    'preflight', 'safe'
  );

  //The secret source is station policy, not an arbitrary caller-selected
  //environment variable.  --prod-key-env is an assertion that the launcher
  //uses this fixed name; it cannot redirect trust to an attacker-owned key.
  STATION_KEY_ID_ENV = 'ASPROGRAMMER_PROD_KEY_ID';
  STATION_HMAC_KEY_ENV = 'ASPROGRAMMER_PROD_HMAC_KEY';

  //Phase 3 intentionally ships fail-closed until the mutation path has been
  //validated on each programmer/part combination. Read/info need no gate.
  NAND_LIVE_GATE_ENV = 'ASPROGRAMMER_NAND_LIVE_VALIDATED';
  NAND_LIVE_GATE_VALUE = '1';
  MOVEFILE_WRITE_THROUGH_FLAG = $00000008;

var
  ConsoleReady: boolean = False;

procedure NeedConsole;
begin
  if ConsoleReady then Exit;
  //เกาะคอนโซลของตัวที่เรียก ถ้าไม่มีก็เปิดใหม่
  if not AttachConsole(DWORD(-1)) then AllocConsole;
  IsConsole := True;
  SysInitStdIO;
  ConsoleReady := True;
end;

procedure Say(const S: string);
begin
  NeedConsole;
  WriteLn(S);
  Flush(Output);
end;

function IsSwitch(const S: string): boolean;
begin
  Result := (Length(S) > 2) and (Copy(S, 1, 2) = '--');
end;

function SwitchName(const S: string): string;
begin
  Result := LowerCase(Copy(S, 3, Length(S)));
end;

function InList(const Name: string; const List: array of string): boolean;
var
  i: integer;
begin
  Result := False;
  for i := Low(List) to High(List) do
    if List[i] = Name then Exit(True);
end;

function HasSwitch(const Name: string): boolean;
var
  i: integer;
begin
  Result := False;
  for i := 1 to ParamCount do
    if SameText(ParamStr(i), '--' + Name) then Exit(True);
end;

function NANDMutationGateEnabled: boolean;
begin
  Result := SysUtils.GetEnvironmentVariable(NAND_LIVE_GATE_ENV) =
            NAND_LIVE_GATE_VALUE;
end;

//ค่าที่ตามหลังสวิตช์ คืนสตริงว่างถ้าไม่มี
//
//สิ่งที่ตามมาต้องไม่ใช่สวิตช์อีกตัว ไม่งั้น --write a.bin --verify --erase
//จะอ่าน --erase เป็นชื่อไฟล์ของ --verify แล้วโปรแกรมจะไปทำงานผิดเส้นทาง
//คือไปตรวจสอบแทนที่จะเขียน โดยไม่มีอะไรฟ้องเลย
function SwitchValue(const Name: string): string;
var
  i: integer;
begin
  Result := '';
  for i := 1 to ParamCount - 1 do
    if SameText(ParamStr(i), '--' + Name) then
    begin
      if IsSwitch(ParamStr(i + 1)) then Exit('');
      Exit(ParamStr(i + 1));
    end;
end;

function WantsCLI: boolean;
var
  i: integer;
begin
  Result := False;
  for i := 1 to ParamCount do
    if Copy(ParamStr(i), 1, 2) = '--' then Exit(True);
end;

//สวิตช์ที่สะกดผิดต้องหยุดตั้งแต่ยังไม่แตะชิป ไม่ใช่ปล่อยผ่านแล้วไปทำอย่างอื่น
function CheckSwitches(out Bad: string): boolean;
var
  i: integer;
  Name: string;
begin
  Result := True;
  Bad := '';

  i := 1;
  while i <= ParamCount do
  begin
    if IsSwitch(ParamStr(i)) then
    begin
      Name := SwitchName(ParamStr(i));

      if (not InList(Name, ValueSwitches)) and (not InList(Name, FlagSwitches)) then
      begin
        Bad := ParamStr(i);
        Exit(False);
      end;

      //ข้ามค่าที่ตามมา จะได้ไม่เอาชื่อไฟล์ไปตรวจว่าเป็นสวิตช์
      if InList(Name, ValueSwitches) and (i < ParamCount) and
         (not IsSwitch(ParamStr(i + 1))) then
        Inc(i);
    end;

    Inc(i);
  end;
end;

procedure Usage;
begin
  Say('Chipwright ' + PROX_VERSION + ', command line mode');
  Say('');
  Say('  AsProgrammer.exe --read out.bin  --chip W25Q64BV');
  Say('  AsProgrammer.exe --write in.bin  --chip W25Q64BV --erase --verify');
  Say('  AsProgrammer.exe --write patch.bin --chip W25Q64BV --smart');
  Say('  AsProgrammer.exe --verify in.bin --chip W25Q64BV');
  Say('  AsProgrammer.exe --erase --chip W25Q64BV');
  Say('  AsProgrammer.exe --detect');
  Say('');
  Say('  --chip NAME     pick a chip from the chip list');
  Say('  --sfdp          take the chip parameters from SFDP instead of the list');
  Say('  --hw NAME       ch341, ch347, ft232h, usbasp, avrisp, arduino,');
  Say('                  buzzpirat, serprog (Pico/STM32/ESP32 flashrom-style');
  Say('                  serial programmers; set the port in the GUI once),');
  Say('                  ezp (EZP2023+: identify, read, whole-chip write and');
  Say('                  erase with automatic byte-for-byte read-back.');
  Say('                  Smart write, SFDP and chip tests need raw SPI and');
  Say('                  therefore cannot work through this firmware)');
  Say('  --erase         erase before writing');
  Say('  --smart         SPI NOR transactional differential write: two-pass');
  Say('                  backup, neighbour preservation and full-block verify');
  Say('  --plan-only     with --smart: read the chip, print the differential');
  Say('                  plan and the chip-declared worst-case time, write nothing');
  Say('  --verify        verify after writing');
  Say('  --region NAME   work on one Intel flash descriptor region only.');
  Say('                  With --read everything outside the region is FF in');
  Say('                  the file; with --write or --verify only that range');
  Say('                  is written or checked (offsets stay full-chip).');
  Say('                  Names: fd, bios, me, gbe, pd, ec. Combine --write');
  Say('                  --region bios --smart to reflash a BIOS without');
  Say('                  touching the ME');
  Say('  --detect        report the programmer and the chip, then exit');
  Say('  --force         go ahead even when the target area is write protected');
  Say('                  or when the chip was already programmed');
  Say('  --json          print the result as one line of JSON');
  Say('  --help');
  Say('');
  Say('  Checking:');
  Say('  --chip-test     non-destructive health check: id stability, id');
  Say('                  opcode cross-check, WEL command execution, SFDP');
  Say('                  size consistency, and a fast-vs-slow clock read');
  Say('  --capacity-test prove the chip''s real capacity (counterfeit');
  Say('                  check). Erases and rewrites up to 17 sectors,');
  Say('                  backed up first and restored with verification;');
  Say('                  needs --force because a power loss mid-test');
  Say('                  loses those sectors. Exit 1 on a remarked fake');
  Say('  --surface-scan  badblocks for SPI NOR: erase/55/AA/address-stamp');
  Say('                  every block and verify each step. ERASES THE');
  Say('                  WHOLE CHIP, nothing is backed up; needs --force.');
  Say('                  Reports a bad-block map and slow-erase wear');
  Say('  --read-passes N read the chip N times and fail if the reads disagree.');
  Say('                  The only way to catch a clip that is making a bad');
  Say('                  contact: the dump looks perfectly valid otherwise');
  Say('  --scan FILE     report on a dump without any hardware: entropy, a');
  Say('                  wrapped address, an all-FF read, the image type');
  Say('  --compare FILE  compare the chip against FILE and list what differs');
  Say('  --sfdp-dump F   write the chip''s raw SFDP table to F');
  Say('  --sfdp-decode F decode an SFDP table saved earlier, no chip needed');
  Say('  --no-fast-read  use 03h instead of 0Bh even when the chip declares SFDP');
  Say('');
  Say('  SPI NAND (W25N, GD5F, MX35 and friends -- separate command model,');
  Say('  bad blocks and on-die ECC; --chip is not used):');
  Say('  --nand-info     identify the chip, scan the factory bad-block');
  Say('                  markers and report the map. Read-only');
  Say('  --nand-read F   dump every good block in order to F, skipping bad');
  Say('                  blocks, with the chip''s ECC verdict checked on');
  Say('                  every page. An uncorrectable page fails the dump');
  Say('  --nand-raw      with --nand-read: include the spare areas (ECC off,');
  Say('                  bytes exactly as stored)');
  Say('  --nand-write F  erase and write a main-area binary image from block 0;');
  Say('                  every programmed physical page is read back in full');
  Say('  --nand-erase    erase every selected good block and read every page');
  Say('                  back blank before reporting success');
  Say('  --nand-bad-policy refuse|skip');
  Say('                  mutation default is refuse; skip explicitly walks');
  Say('                  around known factory-bad blocks');
  Say('  --nand-backup F required for mutation: two matching ECC-checked');
  Say('                  main-area reads of every good block are atomically');
  Say('                  published to a new recovery file before mutation');
  Say('                  NAND mutation is disabled by default pending live');
  Say('                  validation. A validated station must set');
  Say('                  ' + NAND_LIVE_GATE_ENV + '=1, and every destructive');
  Say('                  invocation must also include --force');
  Say('');
  Say('  Safety:');
  Say('  --safe          read-only safe mode: erase, write, unlock and');
  Say('                  status-register edits are refused at the protocol');
  Say('                  layer, so nothing can reach them. --force does not');
  Say('                  override it. Use it on unknown or customer chips.');
  Say('');
  Say('  Machine-facing:');
  Say('  --preflight     report the target rail and whether a destructive');
  Say('                  operation would be allowed, without touching the bus');
  Say('  --json          print one line of JSON carrying schema_version, the');
  Say('                  rail state, and a stable "result" name. Unmeasurable');
  Say('                  values are null, never zero.');
  Say('                  Exit codes: 0 ok, 1 failed, 2 usage, 3 no programmer,');
  Say('                  4 programmer lost, 5 no chip, 6 chip mismatch,');
  Say('                  7 voltage refused, 8 connection unstable,');
  Say('                  9 chip locked, 10 file size mismatch,');
  Say('                  11 verify failed, 12 file error, 13 cancelled');
  Say('');
  Say('  Production:');
  Say('  --job FILE      refuse to write unless the buffer matches the job file');
  Say('                  (keys: chip=, size=, crc32=)');
  Say('  --log FILE      append one CSV line per chip to FILE');
  Say('  --operator NAME put NAME in the log');
  Say('  --save-chip N   save the detected chip into chiplist-user.xml as N');
  Say('  --export-chip N write N.export.txt (a ready-to-PR chiplist line) and');
  Say('                  N.sfdp.bin (a test fixture for tests/sfdp)');
  Say('');
  Say('  Authenticated production (implies SPI NOR Smart Write):');
  Say('  --prod-job F --prod-auth F --prod-key-id ID');
  Say('  --prod-key-env ASPROGRAMMER_PROD_HMAC_KEY --evidence-dir DIR');
  Say('                  authenticate a canonical job, retain its verified image');
  Say('                  handle, enforce measured electrical admission, UID binding,');
  Say('                  full physical verification, then durably commit evidence');
  Say('                  before returning success. Station policy supplies the fixed');
  Say('                  key ID and secret through ASPROGRAMMER_PROD_KEY_ID and');
  Say('                  ASPROGRAMMER_PROD_HMAC_KEY; no secret is accepted on argv.');
  Say('');
  Say('  Files may be .bin, .hex or Motorola S-record; the format is taken');
  Say('  from the extension.');
  Say('');
  Say('  Exit code: 0 success, 1 the operation failed, 2 wrong usage.');
end;

function ParseHW(const S: string; out HW: THardwareList): boolean;
begin
  Result := True;
  if SameText(S, 'ch341') then HW := CHW_CH341
  else if SameText(S, 'ch347') then HW := CHW_CH347
  else if SameText(S, 'ft232h') then HW := CHW_FT232H
  else if SameText(S, 'usbasp') then HW := CHW_USBASP
  else if SameText(S, 'avrisp') then HW := CHW_AVRISP
  else if SameText(S, 'arduino') then HW := CHW_ARDUINO
  else if SameText(S, 'buzzpirat') then HW := CHW_BUZZPIRAT
  else if SameText(S, 'serprog') then HW := CHW_SERPROG
  else if SameText(S, 'ezp') then HW := CHW_EZP
  else
  begin
    HW := CHW_NONE;
    Result := False;
  end;
end;

var
  LogShown: integer = 0;

//ส่งบรรทัด log ที่เพิ่งเพิ่มเข้ามาออกคอนโซล จะได้เห็นสิ่งเดียวกับที่หน้าจอเห็น
procedure DumpLog;
var
  i: integer;
begin
  for i := LogShown to MainForm.Log.Lines.Count - 1 do
    Say(MainForm.Log.Lines[i]);
  LogShown := MainForm.Log.Lines.Count;
end;

function JsonEscape(const S: string): string;
begin
  //The escaper lives in clicontract now, so both front ends and the tests
  //share one copy.  This wrapper keeps the existing call sites readable.
  Result := JsonEscapeText(S);
end;

//The electrical state of the rail right now, as JSON.
//
//Every measured field is null rather than zero when the hardware cannot
//observe it.  A consumer reading 0 for measured_mv would take it as a
//measurement of zero volts, which is the machine-facing version of exactly
//the mistake the rail report exists to prevent for people.
procedure AddRailFields(var J: TJsonObject);
var
  Caps: TProgrammerElectricalCapabilities;
  Obs: TElectricalObservation;
  CapsValid, ObsValid: boolean;
  Report: TRailReport;
begin
  FillChar(Caps, SizeOf(Caps), 0);
  FillChar(Obs, SizeOf(Obs), 0);
  CapsValid := False;
  ObsValid := False;
  if AsProgrammer.Programmer <> nil then
  begin
    CapsValid := AsProgrammer.Programmer.GetElectricalCapabilities(Caps);
    ObsValid := AsProgrammer.Programmer.GetElectricalObservation(Obs);
  end;
  Report := BuildRailReport(Caps, Obs, CapsValid, ObsValid);

  if Report.RequestedKnown then
    J.AddInt('requested_mv', Report.RequestedMv)
  else
    J.AddNull('requested_mv');

  if Report.MeasuredKnown then
    J.AddInt('measured_mv', Report.MeasuredMv)
  else
    J.AddNull('measured_mv');

  if Report.CurrentKnown then
    J.AddInt('target_current_ua', Report.CurrentUa)
  else
    J.AddNull('target_current_ua');

  //Three-valued, and it must stay that way: "no external voltage" and "this
  //programmer cannot see external voltage" are different answers, and
  //collapsing them is how a chip gets written while a motherboard backfeeds
  //its rail.
  case Report.ExternalPower of
    rfYes: J.AddBool('external_power_detected', True);
    rfNo:  J.AddBool('external_power_detected', False);
  else
    J.AddNull('external_power_detected');
  end;

  if Report.SignalKnown then
    J.AddInt('signal_mv', Report.SignalMv)
  else
    J.AddNull('signal_mv');
  J.AddBool('signal_measured', Report.SignalVerified);
end;

//บรรทัดเดียวที่สคริปต์เอาไปอ่านต่อได้ โดยไม่ต้องแกะข้อความ log
procedure SayJson(const Action: string);
var
  J: TJsonObject;
begin
  J.Init;
  //schema_version first so a consumer that does not recognise the version
  //can stop reading before it misinterprets anything below it.
  J.AddInt('schema_version', CLI_SCHEMA_VERSION);
  J.AddString('action', Action);
  J.AddBool('ok', OpOK);
  //The stable reason, alongside ok.  This is what an automated caller
  //branches on; the process exit code carries the same value as a number.
  if OpOK then
    J.AddString('result', CLIOutcomeName(coOK))
  else
    J.AddString('result', CLIOutcomeName(CurrentCLIOutcome));

  //ต้อง "เจอจริง" ไม่ใช่แค่ "ถูกเลือกไว้" เพราะ AsProgrammer.Programmer
  //ชี้ไปที่ backend ที่ติ๊กไว้ในเมนูเสมอ แม้ไม่มีอะไรเสียบอยู่เลย การรายงาน
  //ชื่อรุ่นคู่กับ "no_programmer" อ่านแล้วขัดกันเอง และทำให้ผู้เรียกที่เป็น
  //เครื่องเชื่อว่ามีของอยู่
  if ProgrammerPresent and (AsProgrammer.Programmer <> nil) then
    J.AddString('programmer', AsProgrammer.Programmer.HardwareName)
  else
    J.AddNull('programmer');
  J.AddString('chip', CurrentICParam.Name);
  J.AddString('jedec_id', UpperCase(CurrentICParam.ID));
  J.AddInt('size', CurrentICParam.Size);
  J.AddInt('bytes', LastOp.BytesDone);

  AddRailFields(J);

  if LastChipUID <> '' then J.AddString('uid', LastChipUID);

  //ดัมป์ที่หน้าตาน่าสงสัยไม่ได้ทำให้งาน "ล้มเหลว" เพราะชิปเปล่าอ่านได้ FF
  //ทั้งก้อนอย่างถูกต้องเสมอ แต่สคริปต์ที่เรียกเราควรได้เห็นมันโดยไม่ต้อง
  //ไปแกะข้อความจาก log
  if LastImageWarning <> '' then J.AddString('warning', LastImageWarning);

  if not OpOK then
  begin
    //งานที่ล้มก่อนจะเริ่ม (ยังไม่มีใครเรียก OpFail) จะไม่มีข้อความของตัวเอง
    //ส่งค่าว่างออกไปแปลว่าผู้เรียกได้ช่องที่มีอยู่แต่ไม่มีเนื้อ ใช้ประโยคของ
    //เหตุผลนั้นแทน ดีกว่าปล่อยว่าง
    if LastOp.ErrorText <> '' then
      J.AddString('error', LastOp.ErrorText)
    else
      J.AddString('error', CLIOutcomeText(CurrentCLIOutcome));
    if LastOp.FailAddress >= 0 then
      J.AddInt('address', LastOp.FailAddress);
  end;

  Say(J.Text);
end;

//--- งานที่ไม่ต้องมีฮาร์ดแวร์ ---

//แยกวิเคราะห์ตาราง SFDP ที่เก็บไว้แล้ว
function DecodeSFDPFile(const FileName: string): integer;
var
  F: TFileStream;
  Buf: array of byte;
  Info: TSFDPInfo;
begin
  if not FileExists(FileName) then
  begin
    Say('no such file: ' + FileName);
    Exit(EXIT_USAGE);
  end;

  F := TFileStream.Create(FileName, fmOpenRead or fmShareDenyNone);
  try
    if F.Size = 0 then
    begin
      Say(FileName + ' is empty');
      Exit(EXIT_USAGE);
    end;
    SetLength(Buf, F.Size);
    F.ReadBuffer(Buf[0], F.Size);
  finally
    F.Free;
  end;

  Say(Format('%s: %d bytes', [FileName, Length(Buf)]));

  if not SFDPDetectFromBuffer(@Buf[0], Length(Buf), Info) then
  begin
    Say('this file does not start with an SFDP signature');
    Exit(EXIT_FAIL);
  end;

  LogShown := MainForm.Log.Lines.Count;
  LogSFDPDetails(Info);
  DumpLog;
  Result := EXIT_OK;
end;

//รายงานสิ่งที่บอกได้จากตัวไฟล์ โดยไม่ต้องมีชิป
function ScanFile(const FileName: string): integer;
var
  F: TFileStream;
  Buf: array of byte;
  S: TImgStats;
  V: TImgVerdict;
  Kind: string;
begin
  if not FileExists(FileName) then
  begin
    Say('no such file: ' + FileName);
    Exit(EXIT_USAGE);
  end;

  F := TFileStream.Create(FileName, fmOpenRead or fmShareDenyNone);
  try
    if F.Size = 0 then
    begin
      Say(FileName + ' is empty');
      Exit(EXIT_USAGE);
    end;
    SetLength(Buf, F.Size);
    F.ReadBuffer(Buf[0], F.Size);
  finally
    F.Free;
  end;

  S := ScanImage(@Buf[0], Length(Buf));
  Say(FileName + ': ' + StatsText(S));

  Kind := DetectImageKind(@Buf[0], Length(Buf));
  if Kind <> '' then Say('looks like a ' + Kind);

  V := ImageVerdict(S);
  if V = ivOK then
  begin
    Say('nothing suspicious');
    Exit(EXIT_OK);
  end;

  Say('suspicious: ' + VerdictText(V, S));
  Result := EXIT_FAIL;
end;

//รหัสออกที่ตรงกับผลจริง เดิมคืน 0 เสมอไม่ว่าจะเกิดอะไรขึ้น
function ResultCode: integer;
begin
  //A failing operation returns the most specific reason any gate recorded,
  //not a flat 1.  A caller that must tell "the rail was refused" from "the
  //chip is locked" from "the clip fell off" can now do it without matching
  //substrings against log lines that are written for people and translated.
  if OpOK then
    Result := EXIT_OK
  else
    Result := CLIExitCode(CurrentCLIOutcome);
end;

function SameBytes(const A, B: TBytes): boolean;
var
  i: integer;
begin
  if Length(A) <> Length(B) then Exit(False);
  for i := 0 to High(A) do
    if A[i] <> B[i] then Exit(False);
  Result := True;
end;

//ตารางเดิมย้ายไปอยู่ที่ utilfunc แล้ว เพราะฝั่ง GUI ต้องใช้ตัวเดียวกันตอน
//เลือกแรงดันอัตโนมัติ และ cli หน่วยนี้ uses main อยู่ main จึงเรียกกลับมาไม่ได้
function LocalVccRange(const Text: string; out MinMv,
  MaxMv: cardinal): boolean;
begin
  Result := VccRangeMv(Text, MinMv, MaxMv);
end;

function ProductionModeRequested: boolean;
begin
  Result := HasSwitch('prod-job') or HasSwitch('prod-auth') or
            HasSwitch('prod-key-id') or HasSwitch('prod-key-env') or
            HasSwitch('evidence-dir');
end;

function RunAuthenticatedProduction(const RequestedChip: string;
  Json: boolean): integer;
var
  ManifestFile, AuthFile, EvidenceDir, ExpectedKeyID, KeyEnvName: string;
  StationKeyID, KeyHex, ErrMsg, ProfileHash: string;
  Key, ProfileBytes, BeforeJobBytes, AdmittedJobBytes: TBytes;
  BeforeJob, Job: TProductionJob;
  ImageStream: TFileStream;
  Profile: TSPINORChipProfile;
  ProgrammerCaps: TProgrammerElectricalCapabilities;
  AdapterCaps: TAdapterElectricalCapabilities;
  Observation: TElectricalObservation;
  ElectricalReport: TPreflightReport;
  AdmissionFailure: TProductionAdmissionFailure;
  Digest: TSHA256Digest;
  VerificationUTC: QWord;
  LocalMinMv, LocalMaxMv: cardinal;
  SavedProdLog: string;
  StateFile, RecordUID: string;
  StateEntries: TProdStateEntries;
  i: integer;

  function Reject(const MessageText: string;
    ExitCode: integer = EXIT_FAIL): integer;
  begin
    Say(MessageText);
    OpBegin(opkWrite);
    OpFail(MessageText);
    if Json then SayJson('authenticated-production');
    Result := ExitCode;
  end;

begin
  Result := EXIT_FAIL;
  ImageStream := nil;
  Key := nil;
  ProfileBytes := nil;
  BeforeJobBytes := nil;
  AdmittedJobBytes := nil;
  KeyHex := '';
  SavedProdLog := ProdSettings.ProdLogFile;

  ManifestFile := SwitchValue('prod-job');
  AuthFile := SwitchValue('prod-auth');
  ExpectedKeyID := SwitchValue('prod-key-id');
  KeyEnvName := SwitchValue('prod-key-env');
  EvidenceDir := SwitchValue('evidence-dir');

  if (ManifestFile = '') or (AuthFile = '') or (ExpectedKeyID = '') or
     (KeyEnvName = '') or (EvidenceDir = '') then
    Exit(Reject('authenticated production requires --prod-job, --prod-auth, ' +
      '--prod-key-id, --prod-key-env, and --evidence-dir', EXIT_USAGE));

  if (SwitchValue('write') <> '') or (SwitchValue('read') <> '') or
     HasSwitch('verify') or HasSwitch('erase') or
     (SwitchValue('job') <> '') or (SwitchValue('log') <> '') or
     HasSwitch('force') or HasSwitch('detect') or HasSwitch('sfdp') or
     HasSwitch('plan-only') or
     (SwitchValue('compare') <> '') or (SwitchValue('scan') <> '') or
     (SwitchValue('sfdp-dump') <> '') or
     (SwitchValue('sfdp-decode') <> '') or
     (SwitchValue('save-chip') <> '') or
     (SwitchValue('export-chip') <> '') or
     (SwitchValue('read-passes') <> '') or
     HasSwitch('nand-info') or HasSwitch('nand-read') or
     HasSwitch('nand-write') or HasSwitch('nand-erase') or
     HasSwitch('nand-bad-policy') or HasSwitch('nand-backup') or
     HasSwitch('chip-test') or HasSwitch('capacity-test') or
     HasSwitch('surface-scan') then
    Exit(Reject('authenticated production cannot be combined with read, ' +
      'write, erase, verify, force, legacy-job/log, detection, NAND, or ' +
      'offline inspection switches', EXIT_USAGE));

  if KeyEnvName <> STATION_HMAC_KEY_ENV then
    Exit(Reject('--prod-key-env must name the station-locked ' +
                STATION_HMAC_KEY_ENV, EXIT_USAGE));
  StationKeyID := Trim(SysUtils.GetEnvironmentVariable(STATION_KEY_ID_ENV));
  if (StationKeyID = '') or (ExpectedKeyID <> StationKeyID) then
    Exit(Reject('the requested production key ID is not trusted by this station',
                EXIT_USAGE));

  try
    //อ่านและแปลงกุญแจภายใน try เท่านั้น: ทางออกที่ปฏิเสธก่อนหน้านี้เคยข้าม
    //finally ไป แล้วทิ้งกุญแจ HMAC ค้างอยู่ในหน่วยความจำที่ถูกปล่อยแล้ว
    KeyHex := SysUtils.GetEnvironmentVariable(STATION_HMAC_KEY_ENV);
    if (KeyHex = '') or (KeyHex <> Trim(KeyHex)) or
       (not HexToBytes(KeyHex, Key)) or
       (Length(Key) < MIN_HMAC_KEY_BYTES) then
      Exit(Reject('the station HMAC key is missing or is not canonical hex ' +
                  'with at least 32 bytes', EXIT_USAGE));

    if not DirectoryExists(EvidenceDir) then
      Exit(Reject('evidence directory does not exist: ' + EvidenceDir,
                  EXIT_USAGE));
    EvidenceDir := ExpandFileName(EvidenceDir);

    VerificationUTC := QWord(DateTimeToUnix(Now, False));
    if not LoadAuthenticatedProductionJob(ManifestFile, AuthFile,
      ExpectedKeyID, Key, VerificationUTC, BeforeJob, ErrMsg) then
      Exit(Reject('production job authentication failed: ' + ErrMsg));

    if BeforeJob.Protocol <> spSPI then
      Exit(Reject('authenticated production currently supports SPI NOR only'));
    if (BeforeJob.ChipID = 'none') or (Length(BeforeJob.ChipID) <> 6) then
      Exit(Reject('strict SPI NOR jobs require an exact three-byte JEDEC ID'));
    if BeforeJob.ChipSize > 16777216 then
      Exit(Reject('strict chip-profile v1 cannot bind 4-byte opcodes above 16 MiB'));
    if not BeforeJob.UIDRequired then
      Exit(Reject('strict two-session programming requires uid_required=1'));
    if ProdSettings.SNEnabled then
      Exit(Reject('strict jobs cannot use unsigned serial personalization settings'));

    if (RequestedChip <> '') and
       (RequestedChip <> BeforeJob.ChipName) then
      Exit(Reject('--chip does not match the authenticated job chip name',
                  EXIT_USAGE));
    if not SelectChipAny(BeforeJob.ChipName) then
      Exit(Reject('authenticated job chip is not in the local chip list: ' +
                  BeforeJob.ChipName, EXIT_USAGE));
    if (not MainForm.RadioSPI.Checked) or
       (MainForm.ComboSPICMD.ItemIndex <> SPI_CMD_25) then
      Exit(Reject('the authenticated chip definition is not SPI 25-series NOR'));

    if (CurrentICParam.Name <> BeforeJob.ChipName) or
       (UpperCase(CurrentICParam.ID) <> BeforeJob.ChipID) or
       (CurrentICParam.Size <> BeforeJob.ChipSize) then
      Exit(Reject('local chip name, JEDEC ID, or capacity contradicts the job'));
    if (CurrentICParam.Page < 1) or (CurrentICParam.Page > 2048) or
       (CurrentICParam.Sector = 0) or
       (CurrentICParam.SectorOpcode = 0) then
      Exit(Reject('strict production requires explicit page, sector, and ' +
                  'sectorcmd fields in the local chip definition'));
    if not LocalVccRange(CurrentICParam.Vcc, LocalMinMv, LocalMaxMv) then
      Exit(Reject('strict production requires an explicit supported vcc field ' +
                  'in the local chip definition'));
    if (BeforeJob.VccMinMv <> LocalMinMv) or
       (BeforeJob.VccMaxMv <> LocalMaxMv) then
      Exit(Reject('job VCC bounds contradict the local chip definition'));

    ClearSPINORChipProfile(Profile);
    Profile.Version := SPI_NOR_PROFILE_VERSION;
    Profile.Name := CurrentICParam.Name;
    Profile.JedecID := UpperCase(CurrentICParam.ID);
    Profile.CapacityBytes := CurrentICParam.Size;
    Profile.PageSize := CurrentICParam.Page;
    Profile.EraseSize := CurrentICParam.Sector;
    Profile.EraseOpcode := CurrentICParam.SectorOpcode;
    Profile.VccMinMv := LocalMinMv;
    Profile.VccMaxMv := LocalMaxMv;
    if not TryCanonicalSPINORChipProfileBytes(Profile, ProfileBytes,
                                               ErrMsg) then
      Exit(Reject('local chip profile is not canonical: ' + ErrMsg));
    if not SHA256Bytes(ProfileBytes, Digest, ErrMsg) then
      Exit(Reject('cannot hash the canonical chip profile: ' + ErrMsg));
    ProfileHash := DigestToHex(Digest);
    if ProfileHash <> BeforeJob.ChipDefinitionSHA256 then
      Exit(Reject('local canonical chip profile hash does not match the job'));

    FillChar(ProgrammerCaps, SizeOf(ProgrammerCaps), 0);
    ProgrammerCaps.ProgrammerID := '';
    ProgrammerCaps.FirmwareVersion := '';
    AsProgrammer.Programmer.GetElectricalCapabilities(ProgrammerCaps);
    FillChar(Observation, SizeOf(Observation), 0);
    AsProgrammer.Programmer.GetElectricalObservation(Observation);
    FillChar(AdapterCaps, SizeOf(AdapterCaps), 0);
    AdapterCaps.Present := False;
    AdapterCaps.AdapterID := '';

    BeforeJobBytes := CanonicalProductionJobBytes(BeforeJob);
    if not AdmitHMACProductionJob(ManifestFile, AuthFile, ExpectedKeyID,
      Key, VerificationUTC, ProfileBytes, ProgrammerCaps, AdapterCaps,
      Observation, Job, ImageStream, ElectricalReport, AdmissionFailure,
      ErrMsg) then
      Exit(Reject('production admission rejected at ' +
        ProductionAdmissionFailureName(AdmissionFailure) + ': ' + ErrMsg));

    AdmittedJobBytes := CanonicalProductionJobBytes(Job);
    if not SameBytes(BeforeJobBytes, AdmittedJobBytes) then
      Exit(Reject('production manifest changed during admission'));
    if (Job.ChipName <> Profile.Name) or
       (Job.ChipID <> Profile.JedecID) or
       (Job.ChipSize <> Profile.CapacityBytes) or
       (Job.VccMinMv <> Profile.VccMinMv) or
       (Job.VccMaxMv <> Profile.VccMaxMv) then
      Exit(Reject('admitted job fields contradict the authenticated chip profile'));
    if (Job.StartAddress > High(cardinal)) or
       (Job.WriteLength > High(cardinal)) or
       (Job.ImageSize <> Job.WriteLength) then
      Exit(Reject('admitted image range is not representable by this build'));

    ImageStream.Position := 0;
    MainForm.MPHexEditorEx.LoadFromStream(ImageStream);
    if MainForm.MPHexEditorEx.DataSize <> cardinal(Job.WriteLength) then
      Exit(Reject('the retained verified image did not load at its exact size'));
    MainForm.StartAddressEdit.Text := IntToHex(cardinal(Job.StartAddress), 1);
    MainForm.MenuCheckIDBefore.Checked := True;
    MainForm.MenuAutoCheck.Checked := True;

    //ด่านสถานะกันซ้ำของสถานี: ปฏิเสธ revision ที่เก่ากว่าที่เคยรัน และ
    //นาฬิกาที่เดินถอยหลังผ่านเวลาที่เคยบันทึกไว้ (ขั้นตอนที่ 5 ของลำดับ
    //ที่ docs/production-job-security.md กำหนด สำหรับสถานีเดี่ยวที่ไม่มี MES)
    StateFile := IncludeTrailingPathDelimiter(EvidenceDir) + 'consumed.log';
    if not LoadProductionState(StateFile, Key, StateEntries, ErrMsg) then
      Exit(Reject('the durable production state could not be verified: ' +
                  ErrMsg));
    if not CheckJobFreshness(StateEntries, Job.JobID, Job.Revision,
                             VerificationUTC, ErrMsg) then
      Exit(Reject('the durable production state refused this job: ' +
                  ErrMsg));

    StrictProductionMode := True;
    StrictProductionJobID := Job.JobID;
    StrictProductionJobRevision := Job.Revision;
    StrictEvidenceDirectory := EvidenceDir;
    //หลักฐานของ strict run ถูกเซ็นด้วยกุญแจสถานีตัวเดียวกับที่ตรวจ manifest
    //ตัวกุญแจถูกล้างใน finally ด้านล่างเสมอ ไม่ว่างานจบแบบไหน
    StrictEvidenceKeyID := ExpectedKeyID;
    StrictEvidenceKey := Key;
    StrictProductionUIDRequired := Job.UIDRequired;
    StrictProductionReadPasses := Job.ReadPasses;
    StrictProductionProfileHash := ProfileHash;
    StrictProductionImageHash := Job.ImageSHA256;
    StrictProductionExpectedID := Job.ChipID;
    StrictProductionPageSize := Profile.PageSize;
    StrictProductionEraseSize := Profile.EraseSize;
    StrictProductionEraseOpcode := Profile.EraseOpcode;
    StrictAdmittedProgrammerID := ProgrammerCaps.ProgrammerID;
    ProdSettings.ProdLogFile := '';
    CLIForce := False;

    LogShown := MainForm.Log.Lines.Count;
    MainForm.MenuSmartWriteClick(MainForm.ComboItem1);
    DumpLog;
    Result := ResultCode;

    //หน่วยที่ผ่านต้องถูกบันทึกลงสถานะกันซ้ำก่อนถึงจะรายงาน PASS ได้
    //ถ้าบันทึกไม่สำเร็จ ผลของงานคือล้มเหลว เหมือนกติกาเดียวกับหลักฐาน
    if Result = EXIT_OK then
    begin
      RecordUID := LastChipUID;
      if RecordUID = '' then RecordUID := 'none';
      //ต้องใช้เวลาเดียวกับตอนรับงาน ไม่ใช่อ่านนาฬิกาใหม่
      //
      //งานเขียนกินเวลาหลายนาที ถ้า NTP ปรับเวลาถอยหลังระหว่างนั้น การอ่าน
      //นาฬิกาใหม่จะทำให้ด่านนาฬิกาเดินถอยหลังปฏิเสธการบันทึก ทั้งที่ชิปถูก
      //เขียนไปเรียบร้อยแล้ว ผลคือหน่วยนั้นถูกใช้ไปแต่ไม่มีบันทึก และ UID
      //เดิมยังเขียนซ้ำได้อีก
      if not AppendProductionState(StateFile, Key, Job.JobID, Job.Revision,
               LastStrictRunID, RecordUID, VerificationUTC, ErrMsg) then
      begin
        Say('the unit passed physically but the durable production state ' +
            'could not record it: ' + ErrMsg);
        OpFail('the durable production state could not record the unit: ' +
               ErrMsg);
        Result := EXIT_FAIL;
      end;
    end;

    if Json then SayJson('authenticated-production');
  finally
    StrictProductionMode := False;
    StrictProductionJobID := '';
    StrictProductionJobRevision := 0;
    StrictEvidenceDirectory := '';
    StrictEvidenceKeyID := '';
    //StrictEvidenceKey ใช้บัฟเฟอร์เดียวกับ Key ข้างล่าง การล้าง Key จึงล้าง
    //ไบต์ชุดเดียวกัน แต่ต้องปล่อย reference นี้ก่อนกันไม่ให้ SetLength ใน
    //ClearSensitiveBytes ทำสำเนาแล้วเหลือไบต์จริงไว้ในก้อนที่ยังถูกอ้างถึง
    StrictEvidenceKey := nil;
    StrictProductionUIDRequired := False;
    StrictProductionReadPasses := 2;
    StrictProductionProfileHash := '';
    StrictProductionImageHash := '';
    StrictProductionExpectedID := '';
    StrictProductionPageSize := 0;
    StrictProductionEraseSize := 0;
    StrictProductionEraseOpcode := 0;
    StrictAdmittedProgrammerID := '';
    ProdSettings.ProdLogFile := SavedProdLog;
    ImageStream.Free;
    ClearSensitiveBytes(Key);
    for i := 1 to Length(KeyHex) do KeyHex[i] := #0;
    KeyHex := '';
  end;
end;

//งาน SPI NAND ทั้งหมดของ CLI: ระบุชิป สแกนบล็อกเสีย และดัมป์
//แยกจากทางปุ่มของหน้าต่างหลักทั้งเส้น เพราะ NAND ใช้ตัววางแผนกับ
//ตัวปฏิบัติการของมันเอง ไม่มีปุ่มบนจอให้ยืม
function RunNANDCLI(Json: boolean): integer;
var
  Config: TSPINANDConfig;
  Dev: TSPINANDDevice;
  Raw, ONFIRaw: TBytes;
  Entry: TNANDCatalogEntry;
  Geo, ONFIGeo: TNANDGeometry;
  ONFIParams: TONFIParameterPage;
  ParameterAccess: TSPINANDParameterPageAccess;
  Layout: TNANDImageLayout;
  Policy: TNANDBadBlockPolicy;
  Map: TNANDBlockMap;
  Plan, BackupPlan: TNANDPlan;
  Image, BackupFirst, BackupSecond: TBytes;
  Err, FileName, IDText, BadText, Action, PolicyText, BackupFile: string;
  IO: TNANDIOResult;
  Rep: TNANDRunReport;
  i: SizeInt;
  BadCount, BlocksToErase: cardinal;
  ActionCount: integer;
  Mutation: boolean;
  F: TFileStream;
  UsableBytes: QWord;

  function PublishBackupAtomic(const Destination: string;
    const Data: TBytes; out ErrorText: string): boolean;
  var
    AbsoluteDestination, DirectoryName, TempName: string;
    OutFile: TFileStream;
    SavedError: DWORD;
  begin
    Result := False;
    ErrorText := '';
    AbsoluteDestination := ExpandFileName(Destination);
    DirectoryName := ExtractFileDir(AbsoluteDestination);
    if not DirectoryExists(DirectoryName) then
    begin
      ErrorText := 'backup directory does not exist: ' + DirectoryName;
      Exit;
    end;
    if FileExists(AbsoluteDestination) then
    begin
      ErrorText := 'refusing to overwrite existing recovery backup: ' +
                   AbsoluteDestination;
      Exit;
    end;
    TempName := AbsoluteDestination + '.tmp-' +
      IntToHex(GetCurrentProcessId, 8) + '-' + IntToHex(GetTickCount64, 16);
    if FileExists(TempName) then
    begin
      ErrorText := 'the recovery backup temporary path already exists';
      Exit;
    end;

    try
      try
        OutFile := TFileStream.Create(TempName, fmCreate or fmShareExclusive);
        try
          if Length(Data) > 0 then OutFile.WriteBuffer(Data[0], Length(Data));
          if not FlushFileBuffers(THandle(OutFile.Handle)) then
          begin
            SavedError := GetLastError;
            ErrorText := 'flushing the recovery backup failed: ' +
                         SysErrorMessage(SavedError);
            Exit;
          end;
        finally
          OutFile.Free;
        end;
        //The temporary file is in the destination directory, so this is one
        //same-volume atomic publication. No replace flag means a racing
        //target creation fails rather than destroying an existing backup.
        if not MoveFileEx(PChar(TempName), PChar(AbsoluteDestination),
                          MOVEFILE_WRITE_THROUGH_FLAG) then
        begin
          SavedError := GetLastError;
          ErrorText := 'publishing the recovery backup failed: ' +
                       SysErrorMessage(SavedError);
          Exit;
        end;
        Result := True;
      except
        on E: Exception do
          ErrorText := 'writing the recovery backup failed: ' + E.Message;
      end;
    finally
      if (not Result) and FileExists(TempName) then
        SysUtils.DeleteFile(TempName);
    end;
  end;

  function Fail(const Msg: string; Code: integer = EXIT_FAIL): integer;
  begin
    Say(Msg);
    OpFail(Msg);
    if Json then SayJson(Action);
    Result := Code;
  end;

begin
  Action := 'nand';
  FileName := '';
  BackupFile := SwitchValue('nand-backup');
  Image := nil;
  BackupFirst := nil;
  BackupSecond := nil;
  ActionCount := 0;
  if HasSwitch('nand-info') then
  begin
    Action := 'nand-info';
    Inc(ActionCount);
  end;
  if HasSwitch('nand-read') then
  begin
    Action := 'nand-read';
    FileName := SwitchValue('nand-read');
    Inc(ActionCount);
  end;
  if HasSwitch('nand-write') then
  begin
    Action := 'nand-write';
    FileName := SwitchValue('nand-write');
    Inc(ActionCount);
  end;
  if HasSwitch('nand-erase') then
  begin
    Action := 'nand-erase';
    Inc(ActionCount);
  end;

  if Action = 'nand-read' then OpBegin(opkRead)
  else if Action = 'nand-write' then OpBegin(opkWrite)
  else if Action = 'nand-erase' then OpBegin(opkErase)
  else OpBegin(opkDetect);

  if ActionCount <> 1 then
    Exit(Fail('choose exactly one of --nand-info, --nand-read, ' +
      '--nand-write, or --nand-erase', EXIT_USAGE));
  if ((Action = 'nand-read') or (Action = 'nand-write')) and
     (FileName = '') then
    Exit(Fail('--' + Action + ' needs a file name', EXIT_USAGE));

  Mutation := (Action = 'nand-write') or (Action = 'nand-erase');
  if Mutation and (not NANDMutationGateEnabled) then
    Exit(Fail('SPI NAND mutation is disabled pending live validation. ' +
      'A validated station must set ' + NAND_LIVE_GATE_ENV + '=1'));
  if Mutation and (not HasSwitch('force')) then
    Exit(Fail('--nand-write and --nand-erase are destructive; add --force ' +
      'to acknowledge this invocation', EXIT_USAGE));
  if Mutation and (BackupFile = '') then
    Exit(Fail('--nand-write and --nand-erase require --nand-backup FILE ' +
      'for pre-mutation recovery', EXIT_USAGE));
  if (not Mutation) and HasSwitch('nand-backup') then
    Exit(Fail('--nand-backup is only used by --nand-write and --nand-erase',
      EXIT_USAGE));
  if Mutation then
  begin
    BackupFile := ExpandFileName(BackupFile);
    if FileExists(BackupFile) then
      Exit(Fail('refusing to overwrite existing recovery backup: ' +
                BackupFile, EXIT_USAGE));
    if not DirectoryExists(ExtractFileDir(BackupFile)) then
      Exit(Fail('backup directory does not exist: ' +
                ExtractFileDir(BackupFile), EXIT_USAGE));
    if (Action = 'nand-write') and
       SameFileName(ExpandFileName(FileName), BackupFile) then
      Exit(Fail('--nand-write input and --nand-backup output must be ' +
                'different files', EXIT_USAGE));
  end;
  if Mutation and HasSwitch('nand-raw') then
    Exit(Fail('--nand-write and --nand-erase accept main-area layout only; ' +
      'raw mutation could overwrite bad-block markers and ECC bytes',
      EXIT_USAGE));

  PolicyText := LowerCase(Trim(SwitchValue('nand-bad-policy')));
  if HasSwitch('nand-bad-policy') and (PolicyText = '') then
    Exit(Fail('--nand-bad-policy needs refuse or skip', EXIT_USAGE));
  if PolicyText = '' then Policy := nbpRefuse
  else if PolicyText = 'refuse' then Policy := nbpRefuse
  else if PolicyText = 'skip' then Policy := nbpSkip
  else
    Exit(Fail('--nand-bad-policy must be refuse or skip', EXIT_USAGE));
  if (not Mutation) and HasSwitch('nand-bad-policy') then
    Exit(Fail('--nand-bad-policy is only used by --nand-write and ' +
      '--nand-erase', EXIT_USAGE));

  if HasSwitch('nand-raw') then Layout := nilRaw else Layout := nilMainOnly;

  //Read the exact main-area binary before opening a programmer. Bad paths,
  //empty files, and process-size overflows therefore cannot reach the chip.
  if Action = 'nand-write' then
  begin
    if not FileExists(FileName) then
      Exit(Fail('no such file: ' + FileName, EXIT_USAGE));
    try
      F := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
      try
        if F.Size = 0 then
          Exit(Fail(FileName + ' is empty', EXIT_USAGE));
        if QWord(F.Size) > QWord(High(SizeInt)) then
          Exit(Fail(FileName + ' is too large for this build', EXIT_USAGE));
        SetLength(Image, SizeInt(F.Size));
        F.ReadBuffer(Image[0], Length(Image));
      finally
        F.Free;
      end;
    except
      on E: Exception do
        Exit(Fail('could not read ' + FileName + ': ' + E.Message,
                  EXIT_USAGE));
    end;
  end;

  if not OpenDevice() then
    Exit(Fail('the programmer could not be opened'));
  try
    if not EnterProgModeSPI25 then
      Exit(Fail('the programmer could not initialize the SPI bus'));

    Config := DefaultSPINANDConfig;
    if AsProgrammer.Current_HW = CHW_BUZZPIRAT then
      Config.ReadTransport := sntCombinedWriteRead;

    //ยังไม่รู้ว่าชิปตัวไหน: reset กับอ่าน ID ไม่พึ่ง geometry จริง
    //ใช้ตัวเล็ก ๆ ไปพลางก่อน แล้วสร้างใหม่เมื่อรู้แล้ว
    if not BuildNANDGeometry(2048, 64, 64, 1, Layout, Geo, Err) then
      Exit(Fail('internal geometry error: ' + Err));

    Dev := TSPINANDDevice.Create(AsProgrammer.Programmer, Geo, Config);
    try
      IO := Dev.Reset;
      if not IO.Success then
        Exit(Fail('the NAND did not come out of reset: ' + IO.ErrorText));
      IO := Dev.ReadRawID(Raw);
      if not IO.Success then
        Exit(Fail('reading the NAND id failed: ' + IO.ErrorText));
    finally
      Dev.Free;
    end;

    IDText := '';
    for i := 0 to High(Raw) do IDText := IDText + IntToHex(Raw[i], 2);
    Say('NAND ID(9F): ' + IDText);

    if not NANDIdentify(Raw, Entry) then
    begin
      Say('this id is not in the NAND catalog. The parts this build can drive:');
      Say(NANDCatalogList);
      Exit(Fail('unknown SPI NAND id ' + IDText));
    end;
    if not NANDCatalogGeometry(Entry, Layout, Geo, Err) then
      Exit(Fail('the catalog geometry does not validate: ' + Err));

    Say(Format('%s %s: %d blocks x %d pages x (%d+%d) bytes, %d MB main',
        [string(Entry.Vendor), string(Entry.Name), Geo.BlockCount,
         Geo.PagesPerBlock, Geo.PageSize, Geo.SpareSize,
         NANDMainSize(Geo) div (1024 * 1024)]));

    Dev := TSPINANDDevice.Create(AsProgrammer.Programmer, Geo, Config);
    try
      //Known vendors expose three redundant ONFI copies through a checked
      //configuration-register mode. A geometry contradiction always stops;
      //a mutation also requires the supported ONFI read itself to succeed.
      if NANDParameterPageAccess(Entry, ParameterAccess) then
      begin
        IO := Dev.ReadONFIParameterPages(ParameterAccess, ONFIRaw);
        if not IO.Success then
        begin
          if Mutation then
            Exit(Fail('ONFI live validation failed before mutation: ' +
                      IO.ErrorText));
          Say('ONFI parameter page unavailable; using catalog geometry: ' +
              IO.ErrorText);
        end
        else if not ParseONFIParameterPages(ONFIRaw, ONFIParams, Err) then
        begin
          if Mutation then
            Exit(Fail('ONFI live validation failed before mutation: ' + Err));
          Say('ONFI parameter page was not CRC-valid; using catalog geometry: ' +
              Err);
        end
        else if not NANDCatalogONFIGeometry(Entry, ONFIParams, Layout,
                                             ONFIGeo, Err) then
          Exit(Fail('the ONFI device shape is unsupported: ' + Err))
        else if (ONFIGeo.PageSize <> Geo.PageSize) or
                (ONFIGeo.SpareSize <> Geo.SpareSize) or
                (ONFIGeo.PagesPerBlock <> Geo.PagesPerBlock) or
                (ONFIGeo.BlockCount <> Geo.BlockCount) then
          Exit(Fail(Format(
            'ONFI geometry contradicts the catalog for %s: ' +
            'ONFI says %d x %d x (%d+%d), catalog says %d x %d x (%d+%d)',
            [string(Entry.Name), ONFIGeo.BlockCount,
             ONFIGeo.PagesPerBlock, ONFIGeo.PageSize, ONFIGeo.SpareSize,
             Geo.BlockCount, Geo.PagesPerBlock, Geo.PageSize,
             Geo.SpareSize])))
        else
          Say(Format('ONFI copy %d: %s %s, geometry confirmed',
            [ONFIParams.SelectedCopy + 1, ONFIParams.Manufacturer,
             ONFIParams.Model]));
      end
      else if Mutation then
        Exit(Fail('this NAND family has no primary-source-verified ONFI ' +
          'parameter-page access sequence; mutation is disabled'));

      Say('scanning the factory bad-block markers...');
      if not ScanNANDBadBlocks(Dev, Geo, Map, Err) then
        Exit(Fail('the bad-block scan failed: ' + Err));

      BadCount := Geo.BlockCount - NANDCountUsable(Map);
      BadText := '';
      for i := 0 to High(Map) do
        if Map[i] <> nbsGood then
        begin
          if BadText <> '' then BadText := BadText + ', ';
          BadText := BadText + IntToStr(i);
          if Length(BadText) > 200 then
          begin
            BadText := BadText + ', ...';
            Break;
          end;
        end;
      if BadCount = 0 then
        Say('no bad blocks')
      else
        Say(Format('%d bad blocks: %s', [BadCount, BadText]));

      if Mutation then
      begin
        //Validate the destructive plan before spending time or publishing a
        //backup. The executor receives this exact, already checked plan after
        //the stable recovery image is durable.
        if Action = 'nand-erase' then
        begin
          if Policy = nbpSkip then
            BlocksToErase := NANDCountUsable(Map)
          else
            BlocksToErase := Geo.BlockCount;
          if BlocksToErase = 0 then
            Exit(Fail('every block is bad; there is nothing safe to erase'));
          if not PlanNANDErase(Geo, Map, 0, BlocksToErase, Policy,
                               Plan, Err) then
            Exit(Fail('planning the erase failed before mutation: ' + Err));
        end
        else if not PlanNANDProgram(Geo, Map, 0, Length(Image), Policy,
                                    Plan, Err) then
          Exit(Fail('planning the write failed before mutation: ' + Err));

        UsableBytes := QWord(NANDCountUsable(Map)) *
                       NANDImageBlockStride(Geo);
        if UsableBytes = 0 then
          Exit(Fail('every block is bad; no recovery backup can be made'));
        if UsableBytes > QWord(High(SizeInt)) then
          Exit(Fail('the recovery image is too large for this build'));
        if not PlanNANDRead(Geo, Map, 0, UsableBytes, nbpSkip,
                            BackupPlan, Err) then
          Exit(Fail('planning the recovery backup failed before mutation: ' +
                    Err));

        SetLength(BackupFirst, SizeInt(UsableBytes));
        SetLength(BackupSecond, SizeInt(UsableBytes));
        Say(Format('recovery backup pass 1/2: reading %d main-area bytes...',
                   [UsableBytes]));
        Rep := ExecuteNANDRead(Dev, Geo, Map, BackupPlan, BackupFirst,
                               nil, nil);
        if not Rep.Success then
          Exit(Fail('recovery backup pass 1 failed before mutation: ' +
                    Rep.ErrorText));
        Say('recovery backup pass 2/2: confirming a stable read...');
        Rep := ExecuteNANDRead(Dev, Geo, Map, BackupPlan, BackupSecond,
                               nil, nil);
        if not Rep.Success then
          Exit(Fail('recovery backup pass 2 failed before mutation: ' +
                    Rep.ErrorText));
        if not SameBytes(BackupFirst, BackupSecond) then
          Exit(Fail('the two recovery reads differ; refusing mutation'));
        if not PublishBackupAtomic(BackupFile, BackupFirst, Err) then
          Exit(Fail('recovery backup was not published; refusing mutation: ' +
                    Err));
        Say('stable recovery backup published atomically to ' + BackupFile);
        BackupFirst := nil;
        BackupSecond := nil;
      end;

      if Action = 'nand-info' then
      begin
        if Json then SayJson(Action);
        Exit(EXIT_OK);
      end;

      if Action = 'nand-erase' then
      begin
        Say(Format('erasing and fully blank-checking %d good blocks...',
                   [Plan.BlocksUsed]));
        Rep := ExecuteNANDErase(Dev, Geo, Map, Plan, nil, nil);
        if not Rep.Success then
          Exit(Fail(Format('the erase failed (outcome %d): %s',
            [Ord(Rep.ErrorCode), Rep.ErrorText])));
        UsableBytes := QWord(Plan.BlocksUsed) *
                       QWord(Geo.PagesPerBlock) * QWord(Geo.PageSize);
        if UsableBytes <= High(cardinal) then
          OpProgress(cardinal(UsableBytes), cardinal(UsableBytes));
        Say(Format('erase verified: %d blocks are blank',
                   [Plan.BlocksUsed]));
        if Json then SayJson(Action);
        Exit(EXIT_OK);
      end;

      if Action = 'nand-write' then
      begin
        Say(Format('writing %d main-area bytes across %d good blocks; ' +
                   'full physical-page verification is mandatory...',
                   [Length(Image), Plan.BlocksUsed]));
        Rep := ExecuteNANDWrite(Dev, Geo, Map, Plan, Image, nil, nil);
        if not Rep.Success then
          Exit(Fail(Format('the write failed (outcome %d): %s',
            [Ord(Rep.ErrorCode), Rep.ErrorText])));
        if QWord(Length(Image)) <= High(cardinal) then
          OpProgress(cardinal(Length(Image)), cardinal(Length(Image)));
        if Plan.BlocksSkipped > 0 then
          Say(Format('%d bad blocks were skipped by explicit policy',
                     [Plan.BlocksSkipped]));
        Say('write and full read-back verification passed');
        if Json then SayJson(Action);
        Exit(EXIT_OK);
      end;

      //ดัมป์บล็อกดีทั้งหมดตามลำดับ ข้ามบล็อกเสีย (แผน nbpSkip)
      UsableBytes := QWord(NANDCountUsable(Map)) * NANDImageBlockStride(Geo);
      if UsableBytes = 0 then
        Exit(Fail('every block is bad; there is nothing to dump'));
      if not PlanNANDRead(Geo, Map, 0, UsableBytes, nbpSkip, Plan, Err) then
        Exit(Fail('planning the dump failed: ' + Err));

      Image := nil;
      SetLength(Image, Plan.ReadBytes);
      Say(Format('reading %d bytes from %d good blocks...',
                 [Plan.ReadBytes, Plan.BlocksUsed]));
      Rep := ExecuteNANDRead(Dev, Geo, Map, Plan, Image, nil, nil);
      if not Rep.Success then
        Exit(Fail('the dump failed: ' + Rep.ErrorText));
      if Rep.CorrectedPages > 0 then
      begin
        Say(Format('the chip corrected bit errors on %d pages; the data ' +
                   'is good but the part is aging', [Rep.CorrectedPages]));
        //บล็อกที่แก้บิตกระจุกตัวคือบล็อกที่กำลังตาย ชี้ให้เห็นเป็นรายบล็อก
        BadText := '';
        for i := 0 to High(Rep.CorrectedPerBlock) do
          if Rep.CorrectedPerBlock[i] > 0 then
          begin
            if BadText <> '' then BadText := BadText + ', ';
            BadText := BadText + Format('%d (%d pages)',
                                        [i, Rep.CorrectedPerBlock[i]]);
            if Length(BadText) > 180 then
            begin
              BadText := BadText + ', ...';
              Break;
            end;
          end;
        if BadText <> '' then
          Say('  wear map, corrected pages per block: ' + BadText);
      end;

      try
        F := TFileStream.Create(FileName, fmCreate);
        try
          F.WriteBuffer(Image[0], Length(Image));
        finally
          F.Free;
        end;
      except
        on E: Exception do
          Exit(Fail('could not save ' + FileName + ': ' + E.Message));
      end;
      if Plan.BlocksSkipped > 0 then
        Say(Format('%d bad blocks were skipped; the file holds the good ' +
                   'blocks in order', [Plan.BlocksSkipped]));
      Say('written to ' + FileName);
      if Json then SayJson(Action);
      Exit(EXIT_OK);
    finally
      Dev.Free;
    end;
  finally
    ExitProgMode25;
    AsProgrammer.Programmer.DevClose;
  end;
end;

//--region: หา region ที่ขอจาก descriptor ในภาพ แล้วตรวจว่าอยู่ในภาพจริง
//พ่นเหตุผลเองเมื่อไม่ผ่าน ผู้เรียกแค่จบงานด้วยรหัสที่เหมาะ
function FindRegionInStream(Stream: TMemoryStream; const Name: string;
  out Region: TIFDRegion): boolean;
var
  Map: TIFDMap;
begin
  Result := False;
  if not ParseIFD(PByte(Stream.Memory), Stream.Size, Map) then
  begin
    Say('the image has no Intel flash descriptor, so --region cannot be used');
    Exit;
  end;
  if not IFDRegionByName(Map, Name, Region) then
  begin
    Say('no region named "' + Name + '" is in use in this descriptor. The table:');
    Say(IFDDescribe(Map, Stream.Size));
    Exit;
  end;
  if QWord(Region.Limit) >= QWord(Stream.Size) then
  begin
    Say(Format('region %s (0x%.8x..0x%.8x) extends past the %d-byte image; ' +
               'the selected chip is smaller than the board this image is for',
               [string(Region.Name), Region.Base, Region.Limit, Stream.Size]));
    Exit;
  end;
  Result := True;
end;

function RunCLI: integer;
var
  ChipName, FileName, HWName, Bad, SaveName: string;
  HW: THardwareList;
  Stream, Slice: TMemoryStream;
  ErrMsg: string;
  Json: boolean;
  Action: string;
  ProdMode: boolean;
  RegionName: string;
  Region: TIFDRegion;
  DidSaveChip: boolean;
begin
  Result := EXIT_USAGE;
  Action := 'none';
  DidSaveChip := False;

  //ไม่มีใครนั่งอยู่หน้าจอ ทุกด่านที่ปกติจะถามต้องตัดสินใจเอง
  CLIMode := True;
  //เหตุผลของงานก่อนหน้าต้องไม่ไหลมาถึงงานนี้
  ResetCLIOutcome;

  //ตั้งก่อนตรวจสวิตช์อื่นทั้งหมด งานที่ขอมาพร้อมกันในบรรทัดเดียวจะได้อยู่
  //ใต้แลตช์ตั้งแต่ต้น ไม่ใช่หลังจากเริ่มไปแล้ว
  //
  //ไม่มี --force ที่ปลดล็อกได้ โดยตั้งใจ: --safe คือคำสั่งของผู้ใช้เองว่า
  //"รอบนี้ห้ามแตะชิป" ธงที่ยกเลิกมันได้จะทำให้มันเป็นแค่ข้อเสนอแนะ
  if HasSwitch('safe') then
  begin
    SetSafeMode(True);
    Say('read-only safe mode: erase, write, unlock and status-register ' +
        'edits are refused at the protocol layer');
  end;

  if HasSwitch('help') then
  begin
    Usage;
    Exit(EXIT_OK);
  end;

  if not CheckSwitches(Bad) then
  begin
    Say('unknown option: ' + Bad);
    Say('run with --help to see the options');
    Exit(EXIT_USAGE);
  end;

  //Defense at the outermost boundary: a disabled NAND mutation request is
  //rejected before PollProgrammer or OpenDevice can acquire hardware.
  if (HasSwitch('nand-write') or HasSwitch('nand-erase')) and
     (not NANDMutationGateEnabled) then
  begin
    Say('SPI NAND mutation is disabled pending live validation. A validated ' +
        'station must set ' + NAND_LIVE_GATE_ENV + '=1');
    Exit(EXIT_FAIL);
  end;
  if (HasSwitch('nand-write') or HasSwitch('nand-erase')) and
     (not HasSwitch('force')) then
  begin
    Say('--nand-write and --nand-erase are destructive; add --force to ' +
        'acknowledge this invocation');
    Exit(EXIT_USAGE);
  end;
  if (HasSwitch('nand-write') or HasSwitch('nand-erase')) and
     (SwitchValue('nand-backup') = '') then
  begin
    Say('--nand-write and --nand-erase require --nand-backup FILE for ' +
        'pre-mutation recovery');
    Exit(EXIT_USAGE);
  end;

  Json := HasSwitch('json');
  CLIForce := HasSwitch('force');

  RegionName := SwitchValue('region');
  if RegionName <> '' then
  begin
    //ลบทั้งชิปแล้วเขียนกลับแค่ region เดียวคือการทำลาย region ที่เหลือ
    if HasSwitch('erase') then
    begin
      Say('--region does not combine with --erase: the plain erase is whole-chip.');
      Say('use --write FILE --region ' + RegionName + ' --smart instead; it plans');
      Say('and erases only the blocks the region write actually changes');
      Exit(EXIT_USAGE);
    end;
    if (SwitchValue('read') = '') and (SwitchValue('write') = '') and
       (SwitchValue('verify') = '') then
    begin
      Say('--region only means something with --read, --write or --verify');
      Exit(EXIT_USAGE);
    end;
  end;
  ProdMode := ProductionModeRequested;

  if ProdMode then
  begin
    if (SwitchValue('prod-job') = '') or
       (SwitchValue('prod-auth') = '') or
       (SwitchValue('prod-key-id') = '') or
       (SwitchValue('prod-key-env') = '') or
       (SwitchValue('evidence-dir') = '') then
    begin
      Say('authenticated production is missing one or more required values');
      Exit(EXIT_USAGE);
    end;
    if (SwitchValue('write') <> '') or (SwitchValue('read') <> '') or
       HasSwitch('verify') or HasSwitch('erase') or HasSwitch('force') or
       (SwitchValue('job') <> '') or (SwitchValue('log') <> '') or
       HasSwitch('detect') or HasSwitch('sfdp') or
       (SwitchValue('compare') <> '') or (SwitchValue('scan') <> '') or
       (SwitchValue('sfdp-dump') <> '') or
       (SwitchValue('sfdp-decode') <> '') or
       (SwitchValue('save-chip') <> '') or
       (SwitchValue('export-chip') <> '') or
       HasSwitch('plan-only') or
       (SwitchValue('read-passes') <> '') or
       HasSwitch('nand-info') or HasSwitch('nand-read') or
       HasSwitch('nand-write') or HasSwitch('nand-erase') or
       HasSwitch('nand-bad-policy') or HasSwitch('nand-backup') then
    begin
      Say('authenticated production cannot be combined with other operation switches');
      Exit(EXIT_USAGE);
    end;
  end;

  //งานที่ไม่ต้องมีเครื่องโปรแกรมเลย ทำให้เสร็จก่อนจะไปหาฮาร์ดแวร์
  //ไม่งั้นการถอดรหัสดัมป์ที่เก็บไว้จะล้มเหลวเพราะไม่มีชิปเสียบอยู่
  if SwitchValue('sfdp-decode') <> '' then
    Exit(DecodeSFDPFile(SwitchValue('sfdp-decode')));

  if SwitchValue('scan') <> '' then
    Exit(ScanFile(SwitchValue('scan')));

  //จำนวนรอบการอ่าน ต้องตั้งก่อนงานใด ๆ เริ่ม เพราะ CaptureUIState อ่านค่านี้
  if SwitchValue('read-passes') <> '' then
  begin
    if not TryStrToInt(SwitchValue('read-passes'), CLIReadPasses) then
    begin
      Say('--read-passes needs a number');
      Exit(EXIT_USAGE);
    end;
    if (CLIReadPasses < 1) or (CLIReadPasses > 16) then
    begin
      Say('--read-passes must be between 1 and 16');
      Exit(EXIT_USAGE);
    end;
  end;

  if HasSwitch('no-fast-read') then MainForm.MenuFastRead.Checked := False;

  //ตั้งค่าการผลิตจากบรรทัดคำสั่ง ทับค่าที่บันทึกไว้ใน settings.xml
  if SwitchValue('log') <> '' then ProdSettings.ProdLogFile := SwitchValue('log');
  if SwitchValue('operator') <> '' then ProdSettings.Operator_ := SwitchValue('operator');

  if SwitchValue('job') <> '' then
  begin
    if not LoadJobFile(SwitchValue('job'), CurrentJob, ErrMsg) then
    begin
      Say(ErrMsg);
      Exit(EXIT_USAGE);
    end;
    Say('job file loaded: ' + SwitchValue('job'));
  end;

  //เลือกเครื่องโปรแกรมก่อน ถ้าไม่ระบุก็ใช้ตัวที่ตรวจเจอ
  HWName := SwitchValue('hw');
  if HWName <> '' then
  begin
    if not ParseHW(HWName, HW) then
    begin
      Say('unknown programmer: ' + HWName);
      Exit(EXIT_USAGE);
    end;
    SelectHW(HW);
    SetHardwareMenuCheck(HW);
  end;

  PollProgrammer(False);
  if not ProgrammerPresent then
  begin
    Say('no programmer detected');
    //ไม่มีเครื่องเสียบอยู่ กับงานที่ล้มเหลว ต้องแยกกันให้ผู้เรียกที่เป็น
    //เครื่องรู้ว่าต้องไปเสียบสาย ไม่ใช่ไปไล่ดู log
    NoteCLIOutcome(coNoProgrammer);
    if Json then SayJson('connect');
    Exit(CLIExitCode(coNoProgrammer));
  end;
  Say('programmer: ' + AsProgrammer.Programmer.HardwareName);

  if ProdMode then
    Exit(RunAuthenticatedProduction(SwitchValue('chip'), Json));

  //เลือกชิป
  ChipName := SwitchValue('chip');
  if ChipName <> '' then
  begin
    if not SelectChipAny(ChipName) then
    begin
      Say('chip not found in the chip list: ' + ChipName);
      Exit(EXIT_USAGE);
    end;
    Say('chip: ' + CurrentICParam.Name + '  ' + CurrentICParam.ID +
        '  ' + IntToStr(CurrentICParam.Size) + ' bytes');
  end;

  LogShown := MainForm.Log.Lines.Count;

  if HasSwitch('sfdp') then
  begin
    Action := 'sfdp';
    MainForm.MenuSFDPDetectClick(nil);
    DumpLog;
    if CurrentICParam.Size = 0 then
    begin
      Say('SFDP did not return usable parameters');
      if Json then SayJson(Action);
      Exit(EXIT_FAIL);
    end;
  end;

  //ตรวจสภาพทางไฟฟ้าอย่างเดียว ไม่แตะบัสเลย
  //
  //มีไว้ให้ผู้เรียกที่เป็นเครื่องถามได้ว่า "ถ้าสั่งเขียนตอนนี้จะโดนปฏิเสธไหม"
  //ก่อนจะไปหยิบไฟล์เฟิร์มแวร์มา ไม่ใช่รู้ตอนที่งานเดินไปครึ่งทางแล้ว
  if HasSwitch('preflight') then
  begin
    Action := 'preflight';
    OpBegin(opkDetect);
    ResetCLIOutcome;
    LogRailReport;
    //ถามแบบ destructive เสมอ เพราะคำถามคือ "จะเขียนได้ไหม" การรายงานว่า
    //ผ่านเพราะถามแบบอ่านอย่างเดียว แล้วไปโดนปฏิเสธตอนเขียนจริง คือคำตอบ
    //ที่ผิดในทิศที่แย่ที่สุด
    if not BenchPreflightOK(True) then
      OpFail('the electrical preflight refused a destructive operation');
    DumpLog;
    if Json then SayJson(Action);
    Exit(ResultCode);
  end;

  if HasSwitch('detect') then
  begin
    Action := 'detect';
    MainForm.ButtonReadIDClick(nil);
    DumpLog;
    //ไม่มีชิปตอบ กับงานล้มเหลวด้วยเหตุอื่น ไม่เหมือนกันสำหรับผู้เรียกที่
    //เป็นเครื่อง อย่างแรกให้ไปดูการเสียบ อย่างหลังให้ไปดู log
    if (not OpOK) and (CurrentICParam.Size = 0) then
      NoteCLIOutcome(coNoChip);
    //อย่าจบตรงนี้ถ้ามี --save-chip ต่อท้าย: เดิมทางนี้ Exit ก่อนถึงบล็อก
    //บันทึกเสมอ "--detect --save-chip NAME" จึงไม่เคยบันทึกอะไรเลย
    if (SwitchValue('save-chip') = '') or (not OpOK) then
    begin
      if Json then SayJson(Action);
      Exit(ResultCode);
    end;
  end;

  //บันทึกชิปที่เพิ่งตรวจเจอลงตารางของผู้ใช้
  SaveName := SwitchValue('save-chip');
  if SaveName <> '' then
  begin
    if SaveCurrentChipToUserList(SaveName) then
    begin
      Say('chip saved as ' + SaveName);
      //จำไว้เพื่อจบด้วย exit 0 ถ้าคำสั่งนี้เป็นงานสุดท้ายของบรรทัด
      //(เดิมมันไหลไปชนหน้า usage แล้วออก 2 ทั้งที่บันทึกสำเร็จ)
      DidSaveChip := True;
      DumpLog;
    end
    else
    begin
      Say('could not save the chip');
      DumpLog;
      if Json then SayJson('save-chip');
      Exit(EXIT_FAIL);
    end;
  end;

  //ส่งออกชิปที่ตรวจเจอเป็นชุดพร้อมแชร์: บรรทัด XML สำหรับ chiplist,
  //ดัมป์ SFDP ดิบสำหรับ tests/sfdp และบรรทัด manifest ตั้งต้น
  SaveName := SwitchValue('export-chip');
  if SaveName <> '' then
  begin
    Action := 'export-chip';
    if CurrentICParam.Size = 0 then
    begin
      Say('no chip parameters to export: select or detect a chip first ' +
          '(--chip NAME or --sfdp)');
      Exit(EXIT_USAGE);
    end;

    FileName := SafeElementName(Trim(SaveName));
    ErrMsg := '';
    with TStringList.Create do
    try
      Add('This bundle was generated by AsProgrammer --export-chip.');
      Add('To share the chip with everyone, open a pull request that:');
      Add('');
      Add('1. adds this line to chiplist.xml under the right vendor:');
      Add('');
      if CurrentICParam.Sector > 0 then
        Add(Format('  <%s id="%s" page="%d" size="%d" sector="%d" ' +
                   'sectorcmd="%s"/>',
          [FileName, LastID9F, CurrentICParam.Page, CurrentICParam.Size,
           CurrentICParam.Sector, IntToHex(CurrentICParam.SectorOpcode, 2)]))
      else
        Add(Format('  <%s id="%s" page="%d" size="%d"/>',
          [FileName, LastID9F, CurrentICParam.Page, CurrentICParam.Size]));
      Add('');
      Add('2. copies ' + FileName + '.sfdp.bin into tests/sfdp/ and adds');
      Add('   this starter line to tests/sfdp/manifest.txt (extend it with');
      Add('   the values your datasheet confirms):');
      Add('');
      Add(Format('  %s.sfdp.bin density=%d page=%d',
        [FileName, CurrentICParam.Size, CurrentICParam.Page]));
      try
        SaveToFile(FileName + '.export.txt');
      except
        on E: Exception do ErrMsg := E.Message;
      end;
    finally
      Free;
    end;
    if ErrMsg <> '' then
    begin
      Say('could not write ' + FileName + '.export.txt: ' + ErrMsg);
      Exit(EXIT_FAIL);
    end;

    //ดัมป์ SFDP ต้องเปิดอุปกรณ์เอง เหตุผลเดียวกับทาง --sfdp-dump
    if not OpenDevice() then
    begin
      Say('the programmer could not be opened');
      Exit(EXIT_FAIL);
    end;
    try
      if (not EnterProgModeSPI25) or
         (not DumpSFDPToFile(FileName + '.sfdp.bin', ErrMsg)) then
      begin
        Say('exported ' + FileName + '.export.txt, but the SFDP dump ' +
            'failed: ' + ErrMsg);
        Say('the XML line is still usable; the test fixture is not');
        DumpLog;
        Exit(EXIT_FAIL);
      end;
    finally
      ExitProgMode25;
      AsProgrammer.Programmer.DevClose;
    end;
    DumpLog;
    Say('exported ' + FileName + '.export.txt and ' + FileName +
        '.sfdp.bin -- see the .txt for how to contribute them');
    if Json then SayJson(Action);
    Exit(EXIT_OK);
  end;

  //ดัมป์ตาราง SFDP ดิบ ๆ ต้องมีชิปแต่ไม่ต้องรู้ว่ามันเป็นรุ่นอะไร
  if SwitchValue('sfdp-dump') <> '' then
  begin
    Action := 'sfdp-dump';
    //ทางนี้เป็นทางเดียวใน CLI ที่ไม่ได้วิ่งผ่านปุ่มของหน้าต่างหลัก จึงต้อง
    //เปิดอุปกรณ์เอง: PollProgrammer ที่ตรวจว่ามีเครื่องเสียบอยู่ปิดอุปกรณ์
    //ทิ้งไว้แล้ว ถ้าไม่เปิดใหม่ ทุกคำสั่งจะวิ่งใส่ handle ที่ปิดอยู่ แล้วชิป
    //ดี ๆ จะถูกสรุปว่า "ไม่มีตาราง SFDP"
    if not OpenDevice() then
    begin
      Say('the programmer could not be opened');
      OpFail('the programmer could not be opened');
      if Json then SayJson(Action);
      Exit(EXIT_FAIL);
    end;
    try
      if not EnterProgModeSPI25 then
      begin
        Say('the programmer could not initialize the SPI bus');
        OpFail('the programmer could not initialize the SPI bus');
        DumpLog;
        if Json then SayJson(Action);
        Exit(EXIT_FAIL);
      end;
      if not DumpSFDPToFile(SwitchValue('sfdp-dump'), ErrMsg) then
      begin
        Say('could not dump the SFDP table: ' + ErrMsg);
        OpFail(ErrMsg);
        DumpLog;
        if Json then SayJson(Action);
        Exit(EXIT_FAIL);
      end;
      DumpLog;
      Say('SFDP table written to ' + SwitchValue('sfdp-dump'));
      if Json then SayJson(Action);
      Exit(EXIT_OK);
    finally
      ExitProgMode25;
      AsProgrammer.Programmer.DevClose;
    end;
  end;

  //SPI NAND เดินคนละเส้นทั้งสาย: ไม่ใช้ตารางชิป ไม่ใช้ปุ่มของหน้าต่างหลัก
  if HasSwitch('nand-info') or HasSwitch('nand-read') or
     HasSwitch('nand-write') or HasSwitch('nand-erase') then
    Exit(RunNANDCLI(Json));

  if HasSwitch('chip-test') then
  begin
    Action := 'chip-test';
    LogShown := MainForm.Log.Lines.Count;
    RunChipDoctor;
    DumpLog;
    if Json then SayJson(Action);
    Exit(ResultCode);
  end;

  if HasSwitch('capacity-test') then
  begin
    Action := 'capacity-test';
    //เขียนจริง แม้จะสำรอง-กู้คืนให้ ก็ต้องให้คนยืนยันความตั้งใจมาในคำสั่ง
    if not CLIForce then
    begin
      Say('--capacity-test really erases and rewrites up to 17 sectors ' +
          '(backed up and restored, byte-verified). Add --force to run it');
      Exit(EXIT_USAGE);
    end;
    LogShown := MainForm.Log.Lines.Count;
    RunChipCapacityTest;
    DumpLog;
    if Json then SayJson(Action);
    Exit(ResultCode);
  end;

  if HasSwitch('surface-scan') then
  begin
    Action := 'surface-scan';
    if not CLIForce then
    begin
      Say('--surface-scan ERASES THE WHOLE CHIP and leaves it blank; ' +
          'nothing is backed up. Add --force if that is what you want');
      Exit(EXIT_USAGE);
    end;
    LogShown := MainForm.Log.Lines.Count;
    RunChipSurfaceScan;
    DumpLog;
    if Json then SayJson(Action);
    Exit(ResultCode);
  end;

  if CurrentICParam.Size = 0 then
  begin
    Say('no chip selected: pass --chip NAME or --sfdp');
    Exit(EXIT_USAGE);
  end;

  //เทียบชิปกับไฟล์แล้วรายงานว่าต่างกันตรงไหน
  //หน้าต่างเทียบข้อมูลมีอยู่แล้วแต่เรียกจากสคริปต์ไม่ได้ ซึ่งเป็นสิ่งที่
  //เครื่องทดสอบบนสายการผลิตต้องการมากที่สุด
  if SwitchValue('compare') <> '' then
  begin
    Action := 'compare';
    FileName := SwitchValue('compare');

    if not FileExists(FileName) then
    begin
      Say('no such file: ' + FileName);
      Exit(EXIT_USAGE);
    end;

    Stream := TMemoryStream.Create;
    try
      if not LoadFirmware(FileName, Stream, CurrentICParam.Size, $FF, ErrMsg) then
      begin
        Say('could not load: ' + ErrMsg);
        Exit(EXIT_USAGE);
      end;
      Stream.Position := 0;
      MainForm.MPHexEditorEx.LoadFromStream(Stream);
    finally
      Stream.Free;
    end;

    LogShown := MainForm.Log.Lines.Count;
    MainForm.ButtonVerifyClick(nil);
    DumpLog;
    if Json then SayJson(Action);
    Exit(ResultCode);
  end;

  //ตั้งแต่นี้ไปใช้เส้นทางเดียวกับปุ่มบนหน้าจอ
  LogShown := MainForm.Log.Lines.Count;

  FileName := SwitchValue('write');

  if HasSwitch('erase') and (FileName = '') then
  begin
    Action := 'erase';
    MainForm.ButtonEraseClick(MainForm.ComboItem1);
    DumpLog;
    if Json then SayJson(Action);
    Exit(ResultCode);
  end;

  if SwitchValue('read') <> '' then
  begin
    Action := 'read';
    FileName := SwitchValue('read');
    MainForm.ButtonReadClick(nil);
    DumpLog;

    if not OpOK then
    begin
      if Json then SayJson(Action);
      Exit(EXIT_FAIL);
    end;

    Stream := TMemoryStream.Create;
    try
      MainForm.MPHexEditorEx.SaveToStream(Stream);

      //--region: เก็บเฉพาะส่วนที่ขอ ที่เหลือเป็น FF ออฟเซ็ตในไฟล์ยังตรง
      //กับชิปทั้งตัว เอาไปเขียนกลับหรือป้อนเครื่องมือ UEFI ได้เลย
      if RegionName <> '' then
      begin
        if not FindRegionInStream(Stream, RegionName, Region) then
        begin
          OpFail('the requested descriptor region is not usable');
          if Json then SayJson(Action);
          Exit(EXIT_FAIL);
        end;
        if Region.Base > 0 then
          FillByte(PByte(Stream.Memory)^, Region.Base, $FF);
        if QWord(Region.Limit) + 1 < QWord(Stream.Size) then
          FillByte((PByte(Stream.Memory) + Region.Limit + 1)^,
                   Stream.Size - Region.Limit - 1, $FF);
        Say(Format('kept region %s 0x%.8x..0x%.8x; the rest of the file is FF',
                   [string(Region.Name), Region.Base, Region.Limit]));
      end;

      if not SaveFirmware(FileName, Stream, DetectFormat(FileName), ErrMsg) then
      begin
        Say('could not save: ' + ErrMsg);
        OpFail('could not save ' + FileName + ': ' + ErrMsg);
        if Json then SayJson(Action);
        Exit(EXIT_FAIL);
      end;
    finally
      Stream.Free;
    end;

    Say('written to ' + FileName);
    if Json then SayJson(Action);
    Exit(EXIT_OK);
  end;

  //--verify ทำหน้าที่สองอย่าง ตามด้วยชื่อไฟล์คือสั่งตรวจอย่างเดียว
  //ถ้าเป็นธงเปล่า ๆ คือสั่งตรวจหลังเขียน ซึ่งจัดการอยู่ข้างล่าง
  //สองความหมายนี้ผสมกันไม่ได้: "--write a.bin --verify b.bin" เคยทิ้ง
  //b.bin เงียบ ๆ แล้วตรวจกับ a.bin แทน ต้องบอกตรง ๆ ว่าใช้แบบนี้ไม่ได้
  if (SwitchValue('write') <> '') and (SwitchValue('verify') <> '') then
  begin
    Say('--write cannot combine with "--verify FILE": after a write, plain ' +
        '--verify re-checks the written image; comparing against another ' +
        'file needs its own verify run');
    Exit(EXIT_USAGE);
  end;
  if FileName = '' then FileName := SwitchValue('verify');

  if FileName = '' then
  begin
    //บรรทัดที่จบด้วยการบันทึกชิปสำเร็จ ไม่ใช่บรรทัดที่ใช้ผิด
    if DidSaveChip then
    begin
      if Json then SayJson('save-chip');
      Exit(EXIT_OK);
    end;
    Usage;
    Exit(EXIT_USAGE);
  end;

  if not FileExists(FileName) then
  begin
    Say('no such file: ' + FileName);
    Exit(EXIT_USAGE);
  end;

  Stream := TMemoryStream.Create;
  try
    if not LoadFirmware(FileName, Stream, CurrentICParam.Size, $FF, ErrMsg) then
    begin
      Say('could not load: ' + ErrMsg);
      Exit(EXIT_USAGE);
    end;

    if RegionName <> '' then
    begin
      //โหลดเฉพาะช่วงของ region เข้าบัฟเฟอร์ แล้วเลื่อน start address ไปที่
      //ฐานของมัน เส้นทางเขียนธรรมดา เขียนแบบ smart และตรวจสอบ ล้วนอ่าน
      //ช่วงงานจากสองค่านี้อยู่แล้ว จึงไม่ต้องมีโค้ดเขียนพิเศษอีกชุด
      if not FindRegionInStream(Stream, RegionName, Region) then
        Exit(EXIT_USAGE);
      Slice := TMemoryStream.Create;
      try
        Stream.Position := Region.Base;
        Slice.CopyFrom(Stream, Region.Limit - Region.Base + 1);
        Slice.Position := 0;
        MainForm.MPHexEditorEx.LoadFromStream(Slice);
      finally
        Slice.Free;
      end;
      MainForm.StartAddressEdit.Text := IntToHex(Region.Base, 8);
      Say(Format('working only on region %s 0x%.8x..0x%.8x',
                 [string(Region.Name), Region.Base, Region.Limit]));
    end
    else
    begin
      Stream.Position := 0;
      MainForm.MPHexEditorEx.LoadFromStream(Stream);
    end;
  finally
    Stream.Free;
  end;

  if SwitchValue('write') = '' then
  begin
    Action := 'verify';
    MainForm.ButtonVerifyClick(nil);
    DumpLog;
    if Json then SayJson(Action);
    Exit(ResultCode);
  end;

  Action := 'write';

  if HasSwitch('plan-only') and (not HasSwitch('smart')) then
  begin
    Say('--plan-only only means something together with --smart');
    Exit(EXIT_USAGE);
  end;

  if HasSwitch('smart') then
  begin
    Action := 'smart-write';
    //SPI25 NOR วิ่งผ่านตัวจัดการแบบธุรกรรม ส่วน 24Cxx/93xx/95xx ที่ลบไม่ได้
    //วิ่งผ่านตัวจัดการ EEPROM ซึ่ง MenuSmartWriteClick เลือกให้เอง
    if not ((MainForm.RadioSPI.Checked and
             (MainForm.ComboSPICMD.ItemIndex in [SPI_CMD_25, SPI_CMD_95])) or
            MainForm.RadioI2C.Checked or MainForm.RadioMW.Checked) then
    begin
      Say('--smart supports SPI 25-series NOR, SPI 95-series EEPROM, ' +
          'I2C 24-series and MicroWire 93-series');
      Exit(EXIT_USAGE);
    end;
    if HasSwitch('erase') then
    begin
      Say('--smart already plans the required erases; do not combine it with --erase');
      Exit(EXIT_USAGE);
    end;
    if HasSwitch('plan-only') then
    begin
      Action := 'smart-plan';
      SmartWritePlanOnly := True;
    end;

    try
      MainForm.MenuSmartWriteClick(MainForm.ComboItem1);
    finally
      SmartWritePlanOnly := False;
    end;
    DumpLog;
    if Json then SayJson(Action);
    Exit(ResultCode);
  end;

  if HasSwitch('erase') then
  begin
    MainForm.ButtonEraseClick(MainForm.ComboItem1);
    DumpLog;

    //ลบไม่ผ่านแล้วยังเขียนต่อ ได้ข้อมูลเพี้ยนแน่นอน
    if not OpOK then
    begin
      if Json then SayJson(Action);
      Exit(EXIT_FAIL);
    end;
  end;

  MainForm.MenuAutoCheck.Checked := HasSwitch('verify');
  MainForm.ButtonWriteClick(MainForm.ComboItem1);
  DumpLog;

  if Json then SayJson(Action);
  Result := ResultCode;
end;

end.
