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
  opresult, prodlog, serialnum, spi25, utilfunc;

const
  EXIT_OK    = 0;
  EXIT_FAIL  = 1;
  EXIT_USAGE = 2;

  //สวิตช์ที่ตามด้วยค่า
  ValueSwitches: array[0..8] of string = (
    'chip', 'hw', 'read', 'write', 'verify', 'job', 'operator', 'log', 'save-chip'
  );

  //สวิตช์ที่เป็นธงเปล่า ๆ
  FlagSwitches: array[0..6] of string = (
    'erase', 'detect', 'sfdp', 'help', 'force', 'json', 'verify'
  );

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
  Say('AsProgrammer ProX ' + PROX_VERSION + ', command line mode');
  Say('');
  Say('  AsProgrammer.exe --read out.bin  --chip W25Q64BV');
  Say('  AsProgrammer.exe --write in.bin  --chip W25Q64BV --erase --verify');
  Say('  AsProgrammer.exe --verify in.bin --chip W25Q64BV');
  Say('  AsProgrammer.exe --erase --chip W25Q64BV');
  Say('  AsProgrammer.exe --detect');
  Say('');
  Say('  --chip NAME     pick a chip from the chip list');
  Say('  --sfdp          take the chip parameters from SFDP instead of the list');
  Say('  --hw NAME       ch341, ch347, ft232h, usbasp, avrisp, arduino, buzzpirat');
  Say('  --erase         erase before writing');
  Say('  --verify        verify after writing');
  Say('  --detect        report the programmer and the chip, then exit');
  Say('  --force         go ahead even when the target area is write protected');
  Say('                  or when the chip was already programmed');
  Say('  --json          print the result as one line of JSON');
  Say('  --help');
  Say('');
  Say('  Production:');
  Say('  --job FILE      refuse to write unless the buffer matches the job file');
  Say('                  (keys: chip=, size=, crc32=)');
  Say('  --log FILE      append one CSV line per chip to FILE');
  Say('  --operator NAME put NAME in the log');
  Say('  --save-chip N   save the detected chip into chiplist-user.xml as N');
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
var
  i: integer;
begin
  Result := '';
  for i := 1 to Length(S) do
    case S[i] of
      '"':  Result := Result + '\"';
      '\':  Result := Result + '\\';
      #13:  Result := Result + '\r';
      #10:  Result := Result + '\n';
      #9:   Result := Result + '\t';
    else
      Result := Result + S[i];
    end;
end;

//บรรทัดเดียวที่สคริปต์เอาไปอ่านต่อได้ โดยไม่ต้องแกะข้อความ log
procedure SayJson(const Action: string);
var
  s: string;
begin
  s := '{"action":"' + JsonEscape(Action) + '"' +
       ',"ok":' + BoolToStr(OpOK, 'true', 'false') +
       ',"chip":"' + JsonEscape(CurrentICParam.Name) + '"' +
       ',"size":' + IntToStr(CurrentICParam.Size) +
       ',"bytes":' + IntToStr(LastOp.BytesDone);

  if LastChipUID <> '' then
    s := s + ',"uid":"' + JsonEscape(LastChipUID) + '"';

  if not OpOK then
  begin
    s := s + ',"error":"' + JsonEscape(LastOp.ErrorText) + '"';
    if LastOp.FailAddress >= 0 then
      s := s + ',"address":' + IntToStr(LastOp.FailAddress);
  end;

  Say(s + '}');
end;

//รหัสออกที่ตรงกับผลจริง เดิมคืน 0 เสมอไม่ว่าจะเกิดอะไรขึ้น
function ResultCode: integer;
begin
  if OpOK then Result := EXIT_OK else Result := EXIT_FAIL;
end;

function RunCLI: integer;
var
  ChipName, FileName, HWName, Bad, SaveName: string;
  HW: THardwareList;
  Stream: TMemoryStream;
  ErrMsg: string;
  Json: boolean;
  Action: string;
begin
  Result := EXIT_USAGE;
  Action := 'none';

  //ไม่มีใครนั่งอยู่หน้าจอ ทุกด่านที่ปกติจะถามต้องตัดสินใจเอง
  CLIMode := True;

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

  Json := HasSwitch('json');
  CLIForce := HasSwitch('force');

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
    Exit(EXIT_FAIL);
  end;
  Say('programmer: ' + AsProgrammer.Programmer.HardwareName);

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

  if HasSwitch('detect') then
  begin
    Action := 'detect';
    MainForm.ButtonReadIDClick(nil);
    DumpLog;
    if Json then SayJson(Action);
    Exit(ResultCode);
  end;

  //บันทึกชิปที่เพิ่งตรวจเจอลงตารางของผู้ใช้
  SaveName := SwitchValue('save-chip');
  if SaveName <> '' then
  begin
    if SaveCurrentChipToUserList(SaveName) then
      Say('chip saved as ' + SaveName)
    else
      Say('could not save the chip');
    DumpLog;
  end;

  if CurrentICParam.Size = 0 then
  begin
    Say('no chip selected: pass --chip NAME or --sfdp');
    Exit(EXIT_USAGE);
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
  if FileName = '' then FileName := SwitchValue('verify');

  if FileName = '' then
  begin
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
    Stream.Position := 0;
    MainForm.MPHexEditorEx.LoadFromStream(Stream);
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
