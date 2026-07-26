unit cli;

//โหมดสั่งงานผ่านบรรทัดคำสั่ง
//
//โปรแกรมนี้เป็น GUI จึงไม่มีคอนโซลมาให้ ต้องไปเกาะคอนโซลของตัวที่เรียกเราเอง
//ถ้าถูกเรียกจาก cmd หรือ PowerShell ข้อความจะไปโผล่ที่หน้าต่างนั้น
//
//งานจริงยังใช้โค้ดชุดเดียวกับปุ่มบนหน้าจอ หน้าต่างหลักถูกสร้างแต่ไม่ถูกแสดง
//วิธีนี้ทำให้ไม่มีโค้ดสองชุดที่ต้องดูแลให้ตรงกัน

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
  Windows, Forms, main, basehw, fileformats, findchip, sfdp, jedec, appver;

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

function HasSwitch(const Name: string): boolean;
var
  i: integer;
begin
  Result := False;
  for i := 1 to ParamCount do
    if SameText(ParamStr(i), '--' + Name) then Exit(True);
end;

//ค่าที่ตามหลังสวิตช์ คืนสตริงว่างถ้าไม่มี
function SwitchValue(const Name: string): string;
var
  i: integer;
begin
  Result := '';
  for i := 1 to ParamCount - 1 do
    if SameText(ParamStr(i), '--' + Name) then Exit(ParamStr(i + 1));
end;

function WantsCLI: boolean;
var
  i: integer;
begin
  Result := False;
  for i := 1 to ParamCount do
    if Copy(ParamStr(i), 1, 2) = '--' then Exit(True);
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
  Say('  --hw NAME       ch341, ch347, ft232h, usbasp, avrisp');
  Say('  --erase         erase before writing');
  Say('  --verify        verify after writing');
  Say('  --detect        report the programmer and the chip, then exit');
  Say('  --help');
  Say('');
  Say('  Files may be .bin, .hex or Motorola S-record; the format is taken');
  Say('  from the extension. Exit code is 0 on success.');
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

function RunCLI: integer;
var
  ChipName, FileName, HWName: string;
  HW: THardwareList;
  Stream: TMemoryStream;
  ErrMsg: string;
begin
  Result := 1;

  if HasSwitch('help') then
  begin
    Usage;
    Exit(0);
  end;

  //เลือกเครื่องโปรแกรมก่อน ถ้าไม่ระบุก็ใช้ตัวที่ตรวจเจอ
  HWName := SwitchValue('hw');
  if HWName <> '' then
  begin
    if not ParseHW(HWName, HW) then
    begin
      Say('unknown programmer: ' + HWName);
      Exit;
    end;
    SelectHW(HW);
    SetHardwareMenuCheck(HW);
  end;

  PollProgrammer(False);
  if not ProgrammerPresent then
  begin
    Say('no programmer detected');
    Exit;
  end;
  Say('programmer: ' + AsProgrammer.Programmer.HardwareName);

  //เลือกชิป
  ChipName := SwitchValue('chip');
  if ChipName <> '' then
  begin
    if not SelectChipAny(ChipName) then
    begin
      Say('chip not found in the chip list: ' + ChipName);
      Exit;
    end;
    Say('chip: ' + CurrentICParam.Name + '  ' + CurrentICParam.ID +
        '  ' + IntToStr(CurrentICParam.Size) + ' bytes');
  end;

  if HasSwitch('sfdp') then
  begin
    MainForm.MenuSFDPDetectClick(nil);
    if CurrentICParam.Size = 0 then
    begin
      Say('SFDP did not return usable parameters');
      Exit;
    end;
  end;

  if HasSwitch('detect') then
  begin
    MainForm.ButtonReadIDClick(nil);
    DumpLog;
    Exit(0);
  end;

  if CurrentICParam.Size = 0 then
  begin
    Say('no chip selected: pass --chip NAME or --sfdp');
    Exit;
  end;

  //ตั้งแต่นี้ไปใช้เส้นทางเดียวกับปุ่มบนหน้าจอ
  LogShown := MainForm.Log.Lines.Count;

  if HasSwitch('erase') and (SwitchValue('write') = '') then
  begin
    MainForm.ButtonEraseClick(MainForm.ComboItem1);
    DumpLog;
    Exit(0);
  end;

  FileName := SwitchValue('read');
  if FileName <> '' then
  begin
    MainForm.ButtonReadClick(nil);
    DumpLog;
    Stream := TMemoryStream.Create;
    try
      MainForm.MPHexEditorEx.SaveToStream(Stream);
      if not SaveFirmware(FileName, Stream, DetectFormat(FileName), ErrMsg) then
      begin
        Say('could not save: ' + ErrMsg);
        Exit;
      end;
    finally
      Stream.Free;
    end;
    Say('written to ' + FileName);
    Exit(0);
  end;

  FileName := SwitchValue('write');
  if FileName = '' then FileName := SwitchValue('verify');
  if FileName = '' then
  begin
    Usage;
    Exit;
  end;

  if not FileExists(FileName) then
  begin
    Say('no such file: ' + FileName);
    Exit;
  end;

  Stream := TMemoryStream.Create;
  try
    if not LoadFirmware(FileName, Stream, CurrentICParam.Size, $FF, ErrMsg) then
    begin
      Say('could not load: ' + ErrMsg);
      Exit;
    end;
    Stream.Position := 0;
    MainForm.MPHexEditorEx.LoadFromStream(Stream);
  finally
    Stream.Free;
  end;

  if SwitchValue('verify') <> '' then
  begin
    MainForm.ButtonVerifyClick(nil);
    DumpLog;
    Exit(0);
  end;

  if HasSwitch('erase') then MainForm.ButtonEraseClick(MainForm.ComboItem1);
  MainForm.MenuAutoCheck.Checked := HasSwitch('verify');
  MainForm.ButtonWriteClick(MainForm.ComboItem1);
  DumpLog;

  Result := 0;
end;

end.
