unit scriptsfunc;

{$mode objfpc}{$H+}
interface

uses
  Classes, SysUtils, Variants, Dialogs, graphics, BaseHW,
  spi25, msgstr, PasCalc, pasfunc;

procedure SetScriptFunctions(PC : TPasCalc);
procedure SetScriptVars();
procedure RunScript(ScriptText: TStrings);
function RunScriptFromFile(ScriptFile: string; Section: string): boolean;
function ParseScriptText(Script: TStrings; SectionName: string; var ScriptText: TStrings ): Boolean;
function GetScriptSectionsFromFile(ScriptFile: string): TStrings;

implementation

uses main, scriptedit, opresult;

const _SPI_SPEED_MAX = 255;


function GetScriptSectionsFromFile(ScriptFile: string): TStrings;
var
  st, SectionName: string;
  i: integer;
  ScriptText: TStrings;
begin
  if not FileExists(ScriptsPath+ScriptFile) then Exit;

  Result:= TStringList.Create;
  ScriptText:= TStringList.Create;

  ScriptText.LoadFromFile(ScriptsPath+ScriptFile);

  for i:= 0 to ScriptText.Count-1 do
  begin
    st := Trim(Upcase(ScriptText.Strings[i]));
    if Copy(st, 1, 2) = '{$' then
    begin
      SectionName := Trim(Copy(st, 3, pos('}', st)-3));
      if SectionName <> '' then
      begin
        Result.Add(SectionName);
      end;
    end;
  end;

end;

{คืนข้อความของเซกชันที่เลือก
 ถ้าไม่พบเซกชันจะคืนค่า false}
function ParseScriptText(Script: TStrings; SectionName: string; var ScriptText: TStrings ): Boolean;
var
  st: string;
  i: integer;
  s: boolean;
begin
  Result := false;
  s:= false;

  for i:=0 to Script.Count-1 do
  begin
    st:= Script.Strings[i];

    if s then
    begin
      if Trim(Copy(st, 1, 2)) = '{$' then break;
      ScriptText.Append(st);
    end
    else
    begin
      st:= StringReplace(st, ' ', '', [rfReplaceAll]);
      if Pos('{$' + Upcase(SectionName) + '}', Upcase(st)) <> 0 then
      //if Upcase(st) = '{$' + Upcase(SectionName) + '}' then
      begin
        s := true;
        Result := true;
      end;
    end;

  end;
end;

//รันสคริปต์
procedure RunScript(ScriptText: TStrings);
var
  TimeCounter: TDateTime;
begin
  LogPrint(TimeToStr(Time()));
  TimeCounter := Time();
  MainForm.Log.Append(STR_USING_SCRIPT + CurrentICParam.Script);

  RomF.Clear;

  //กำหนดตัวแปรตั้งต้นให้สคริปต์
  ScriptEngine.ClearVars;
  SyncUI_ICParam();
  SetScriptVars();

  MainForm.StatusBar.Panels.Items[2].Text := CurrentICParam.Name;
  ScriptEngine.Execute(ScriptText.Text);

  if ScriptEngine.ErrCode<>0 then
  begin
    OpFail('chip script failed: ' + ScriptEngine.ErrMsg);
    if not ScriptEditForm.Visible then
    begin
      LogPrint(ScriptEngine.ErrMsg);
      LogPrint(ScriptEngine.ErrLine);
    end
    else
    begin
      ScriptLogPrint(ScriptEngine.ErrMsg);
      ScriptLogPrint(ScriptEngine.ErrLine);
    end;
  end;

  LogPrint(STR_TIME + TimeToStr(Time() - TimeCounter));
end;

{รันเซกชันของสคริปต์จากไฟล์
 ถ้าไม่มีไฟล์หรือไม่มีเซกชันจะคืนค่า false}
function RunScriptFromFile(ScriptFile: string; Section: string): boolean;
var
  ScriptText, ParsedScriptText: TStrings;
begin
  Result := False;
  if not FileExists(ScriptsPath+ScriptFile) then Exit(false);
  try
    ScriptText:= TStringList.Create;
    ParsedScriptText:= TStringList.Create;

    try
      ScriptText.LoadFromFile(ScriptsPath+ScriptFile);
      if not ParseScriptText(ScriptText, Section, ParsedScriptText) then Exit(false);
      RunScript(ParsedScriptText);
      Result := true;
    except
      on E: Exception do
      begin
        OpFail('chip script raised an exception: ' + E.Message);
        LogPrint('Script: ' + E.Message);
        Result := True; //the section existed; never fall through to raw commands
      end;
    end;
  finally
    ScriptText.Free;
    ParsedScriptText.Free;
  end;
end;

function VarIsString(V : TVar) : boolean;
var t: integer;
begin
  t := VarType(V.Value);
  Result := (t=varString) or (t=varOleStr);
end;

//------------------------------------------------------------------------------

{Script Delay(ms: WORD);
 หยุดการทำงานของสคริปต์เป็นเวลา ms มิลลิวินาที
}
function Script_Delay(Sender:TObject; var A:TVarList): boolean;
begin
  if A.Count < 1 then Exit(false);
  Sleep(TPVar(A.Items[0])^.Value);
  Result := true;
end;

{Script ShowMessage(text);
 ทำงานเหมือน ShowMessage}
function Script_ShowMessage(Sender:TObject; var A:TVarList) : boolean;
var s: string;
begin
  if A.Count < 1 then Exit(false);

  s := TPVar(A.Items[0])^.Value;
  ShowMessage(s);
  Result := true;
end;

{Script InputBox(Captiontext, Prompttext, Defaulttext): value;
 ทำงานเหมือน InputBox}
function Script_InputBox(Sender:TObject; var A:TVarList; var R:TVar) : boolean;
begin
  if A.Count < 3 then Exit(false);

  R.Value := InputBox(TPVar(A.Items[0])^.Value, TPVar(A.Items[1])^.Value, TPVar(A.Items[2])^.Value);

  Result := true;
end;

{Script LogPrint(text);
 แสดงข้อความลงใน log
 พารามิเตอร์:
   text ข้อความที่จะแสดง}
function Script_LogPrint(Sender:TObject; var A:TVarList) : boolean;
var
  s: string;
begin
  if A.Count < 1 then Exit(false);

  s := TPVar(A.Items[0])^.Value;
  LogPrint('Script: ' + s);
  Result := true;
end;

{Script CreateByteArray(size): variant;
 สร้างอาเรย์ที่สมาชิกเป็นชนิด varbyte}
function Script_CreateByteArray(Sender:TObject; var A:TVarList; var R:TVar) : boolean;
begin
  if A.Count < 1 then Exit(false);
  R.Value := VarArrayCreate([0, TPVar(A.Items[0])^.Value - 1], varByte);
  Result := true;
end;

{Script GetArrayItem(array, index): variant;
 คืนค่าของสมาชิกในอาเรย์}
function Script_GetArrayItem(Sender:TObject; var A:TVarList; var R:TVar) : boolean;
begin
  if (A.Count < 2) or (not VarIsArray(TPVar(A.Items[0])^.Value)) then Exit(false);
  R.Value := TPVar(A.Items[0])^.Value[TPVar(A.Items[1])^.Value];
  Result := true;
end;

{Script SetArrayItem(array, index, value);
 กำหนดค่าให้สมาชิกในอาเรย์}
function Script_SetArrayItem(Sender:TObject; var A:TVarList) : boolean;
begin
  if (A.Count < 3) or (not VarIsArray(TPVar(A.Items[0])^.Value)) then Exit(false);
  TPVar(A.Items[0])^.Value[TPVar(A.Items[1])^.Value] := TPVar(A.Items[2])^.Value;
  Result := true;
end;

{Script IntToHex(value, digits): string;
 ทำงานเหมือน IntToHex}
function Script_IntToHex(Sender:TObject; var A:TVarList; var R:TVar) : boolean;
begin
  if A.Count < 2 then Exit(false);

  R.Value:= IntToHex(Int64(TPVar(A.Items[0])^.Value), TPVar(A.Items[1])^.Value);
  Result := true;
end;

{Script CHR(byte): char;
 ทำงานเหมือน CHR}
function Script_CHR(Sender:TObject; var A:TVarList; var R:TVar) : boolean;
begin
  if A.Count < 1 then Exit(false);

  R.Value:= CHR(TPVar(A.Items[0])^.Value);
  Result := true;
end;

{Script SPIEnterProgMode(speed): boolean;
 ตั้งค่าขาสำหรับ SPI และกำหนดความถี่ SPI
 ถ้าตั้งความถี่ไม่สำเร็จจะคืนค่า false
 ไม่มีผลกับ CH341}
function Script_SPIEnterProgMode(Sender:TObject; var A:TVarList; var R:TVar) : boolean;
var speed: byte;
begin
  if not OpenDevice() then Exit(false);
  if A.Count < 1 then Exit(false);

  speed := TPVar(A.Items[0])^.Value;
  if speed = _SPI_SPEED_MAX then speed := 13;
  if EnterProgMode25(SetSPISpeed(speed), MainForm.MenuSendAB.Checked) then
    R.Value := True
  else
    R.Value := False;
  Result := true;
end;

{Script SPIExitProgMode();
 ปิดการใช้งานขา SPI}
function Script_SPIExitProgMode(Sender:TObject; var A:TVarList) : boolean;
begin
  ExitProgMode25;
  AsProgrammer.Programmer.DevClose;
  Result := true;
end;

{Script ProgressBar(inc, max, pos);
 กำหนดสถานะของ ProgressBar
 พารามิเตอร์:
   inc เพิ่มตำแหน่งขึ้นเท่าไร
 พารามิเตอร์ที่ไม่บังคับ:
   max ตำแหน่งสูงสุดของ ProgressBar
   pos กำหนดตำแหน่งเป็นค่าที่ระบุ}
function Script_ProgressBar(Sender:TObject; var A:TVarList) : boolean;
begin

  if A.Count < 1 then Exit(false);

  MainForm.ProgressBar.Position := MainForm.ProgressBar.Position + TPVar(A.Items[0])^.Value;

  if A.Count > 1 then
    MainForm.ProgressBar.Max := TPVar(A.Items[1])^.Value;
  if A.Count > 2 then
    MainForm.ProgressBar.Position := TPVar(A.Items[2])^.Value;

  Result := true;
end;

{Script SPIRead(cs, size, buffer..): integer;
 อ่านข้อมูลลงบัฟเฟอร์
 พารามิเตอร์:
   cs ถ้า cs=1 จะปล่อย Chip Select หลังอ่านข้อมูลเสร็จ
   size ขนาดข้อมูลเป็นไบต์
   buffer ตัวแปรสำหรับเก็บข้อมูล หรืออาเรย์ที่สร้างด้วย CreateByteArray
 คืนจำนวนไบต์ที่อ่านได้}
function Script_SPIRead(Sender:TObject; var A:TVarList; var R: TVar) : boolean;
var
  i, size, cs: integer;
  DataArr: array of byte;
begin

  if A.Count < 3 then Exit(false);

  cs := TPVar(A.Items[0])^.Value;
  size := TPVar(A.Items[1])^.Value;

  SetLength(DataArr, size);

  R.Value := SPIRead(cs, size, DataArr[0]);

  //กรณีที่ buffer เป็นอาเรย์
  if (VarIsArray(TPVar(A.Items[2])^.Value)) then
  for i := 0 to size-1 do
  begin
    TPVar(A.Items[2])^.Value[i] := DataArr[i];
  end
  else
  for i := 0 to size-1 do
  begin
    TPVar(A.Items[i+2])^.Value := DataArr[i];
  end;

  Result := true;
end;

{Script SPIWrite(cs, size, buffer..): integer;
 เขียนข้อมูลจากบัฟเฟอร์
 พารามิเตอร์:
   cs ถ้า cs=1 จะปล่อย Chip Select หลังเขียนข้อมูลเสร็จ
   size ขนาดข้อมูลเป็นไบต์
   buffer ตัวแปรสำหรับเก็บข้อมูล หรืออาเรย์ที่สร้างด้วย CreateByteArray
 คืนจำนวนไบต์ที่เขียนได้}
function Script_SPIWrite(Sender:TObject; var A:TVarList; var R: TVar) : boolean;
var
  i, size, cs: integer;
  DataArr: array of byte;
begin

  if A.Count < 3 then Exit(false);

  size := TPVar(A.Items[1])^.Value;
  cs := TPVar(A.Items[0])^.Value;
  SetLength(DataArr, size);

  //กรณีที่ buffer เป็นอาเรย์
  if (VarIsArray(TPVar(A.Items[2])^.Value)) then
  for i := 0 to size-1 do
  begin
    DataArr[i] := TPVar(A.Items[2])^.Value[i];
  end
  else
  for i := 0 to size-1 do
  begin
    DataArr[i] := TPVar(A.Items[i+2])^.Value;
  end;

  R.Value := SPIWrite(cs, size, DataArr);
  Result := true;
end;

{Script SPIReadToEditor(cs, size): integer;
 อ่านข้อมูลเข้าไปใน hex editor
 พารามิเตอร์:
   cs ถ้า cs=1 จะปล่อย Chip Select หลังอ่านข้อมูลเสร็จ
   size ขนาดข้อมูลเป็นไบต์
 คืนจำนวนไบต์ที่อ่านได้}
function Script_SPIReadToEditor(Sender:TObject; var A:TVarList; var R: TVar) : boolean;
var
  DataArr: array of byte;
  BufferLen: integer;
begin

  if A.Count < 2 then Exit(false);

  BufferLen := TPVar(A.Items[1])^.Value;
  SetLength(DataArr, BufferLen);

  R.Value := SPIRead(TPVar(A.Items[0])^.Value, BufferLen, DataArr[0]);

  RomF.Clear;
  RomF.WriteBuffer(DataArr[0], BufferLen);
  RomF.Position := 0;

  try
    MainForm.MPHexEditorEx.InsertMode:= true;
    MainForm.MPHexEditorEx.NoSizeChange:= false;
    MainForm.MPHexEditorEx.ReadOnlyView:= true;

    MainForm.MPHexEditorEx.AppendBuffer(RomF.Memory , BufferLen);
  finally
    MainForm.MPHexEditorEx.ReadOnlyView:= false;
    MainForm.MPHexEditorEx.InsertMode:= MainForm.AllowInsertItem.Checked;
    MainForm.MPHexEditorEx.NoSizeChange:= not MainForm.AllowInsertItem.Checked;
  end;

  Result := true;
end;

{Script SPIWriteFromEditor(cs, size, position): integer;
 เขียนข้อมูลจาก hex editor ขนาด size เริ่มจากตำแหน่ง position
 พารามิเตอร์:
   cs ถ้า cs=1 จะปล่อย Chip Select หลังเขียนข้อมูลเสร็จ
   size ขนาดข้อมูลเป็นไบต์
   position ตำแหน่งใน hex editor
 คืนจำนวนไบต์ที่เขียนได้}
function Script_SPIWriteFromEditor(Sender:TObject; var A:TVarList; var R: TVar) : boolean;
var
  DataArr: array of byte;
  BufferLen: integer;
begin

  if A.Count < 3 then Exit(false);

  BufferLen := TPVar(A.Items[1])^.Value;
  SetLength(DataArr, BufferLen);

  RomF.Clear;
  MainForm.MPHexEditorEx.SaveToStream(RomF);
  RomF.Position := TPVar(A.Items[2])^.Value;
  RomF.ReadBuffer(DataArr[0], BufferLen);

  R.Value := SPIWrite(TPVar(A.Items[0])^.Value, BufferLen, DataArr);

  Result := true;
end;

//I2C---------------------------------------------------------------------------

{Script I2CEnterProgMode;
 ตั้งค่าสถานะของขา}
function Script_I2CEnterProgMode(Sender:TObject; var A:TVarList) : boolean;
begin
  if not OpenDevice() then Exit(false);
  Asprogrammer.Programmer.I2CInit;
  Result := true;
end;

{Script I2cExitProgMode();
 ปิดการใช้งานขา}
function Script_I2CExitProgMode(Sender:TObject; var A:TVarList) : boolean;
begin
  Asprogrammer.Programmer.I2CDeinit;
  AsProgrammer.Programmer.DevClose;
  Result := true;
end;

{Script I2CReadWrite(DevAddr, wsize, rsize, wbuffer.., rbuffer...): integer;
 เขียนข้อมูลจากบัฟเฟอร์
 พารามิเตอร์:
   DevAddr แอดเดรสของอุปกรณ์
   size ขนาดข้อมูลเป็นไบต์
   buffer ตัวแปรสำหรับเก็บข้อมูล หรืออาเรย์ที่สร้างด้วย CreateByteArray
 คืนผลรวมจำนวนไบต์ที่เขียนและที่อ่านได้}
function Script_I2CReadWrite(Sender:TObject; var A:TVarList; var R: TVar) : boolean;
var
  i, rsize, wsize: integer;
  WDataArr, RDataArr: array of byte;
  DevAddr: byte;
begin

  if A.Count < 4 then Exit(false);

  DevAddr := TPVar(A.Items[0])^.Value;
  wsize := TPVar(A.Items[1])^.Value;
  if wsize < 1 then Exit(false);
  rsize := TPVar(A.Items[2])^.Value;
  SetLength(WDataArr, wsize);
  SetLength(RDataArr, rsize);

  //กรณีที่ wbuffer เป็นอาเรย์
  if (VarIsArray(TPVar(A.Items[3])^.Value)) then
  for i := 0 to wsize-1 do
  begin
    WDataArr[i] := TPVar(A.Items[3])^.Value[i];
  end
  else
  for i := 0 to wsize-1 do
  begin
    WDataArr[i] := TPVar(A.Items[i+3])^.Value;
  end;

  R.Value := AsProgrammer.Programmer.I2CReadWrite(DevAddr, wsize, WDataArr, rsize, RDataArr);

  if rsize < 1 then Exit(true);

  if (VarIsArray(TPVar(A.Items[3])^.Value)) then wsize := 1;
  //กรณีที่ rbuffer เป็นอาเรย์
  if (VarIsArray(TPVar(A.Items[wsize+3])^.Value)) then
  for i := 0 to rsize-1 do
  begin
    TPVar(A.Items[wsize+3])^.Value[i] := RDataArr[i];
  end
  else
  for i := 0 to rsize-1 do
  begin
    TPVar(A.Items[i+wsize+3])^.Value := RDataArr[i];
  end;

  Result := true;
end;

{Script I2CStart;
  ใช้คู่กับ I2CWriteByte และ I2CReadByte
 }
function Script_I2CStart(Sender:TObject) : boolean;
begin
  AsProgrammer.Programmer.I2CStart;
  result := true;
end;

{Script I2CStop;
  ใช้คู่กับ I2CWriteByte และ I2CReadByte
 }
function Script_I2CStop(Sender:TObject) : boolean;
begin
  AsProgrammer.Programmer.I2CStop;
  result := true;
end;

{Script I2CWriteByte(data): boolean;
 คืนค่า ack/nack
 พารามิเตอร์:
   data ไบต์ข้อมูลที่จะเขียน
   คืนค่า ack/nack}
function Script_I2CWriteByte(Sender:TObject; var A:TVarList; var R: TVar) : boolean;
begin
  if A.Count < 1 then Exit(false);

  R.Value := AsProgrammer.Programmer.I2CWriteByte(TPVar(A.Items[0])^.Value);
  result := true;
end;

{Script I2CReadByte(ack: boolean): data;
 คืนไบต์ข้อมูล
 พารามิเตอร์:
   ack ack/nack
   คืนไบต์ข้อมูลที่อ่านได้}
function Script_I2CReadByte(Sender:TObject; var A:TVarList; var R: TVar) : boolean;
begin
  if A.Count < 1 then Exit(false);

  R.Value := AsProgrammer.Programmer.I2CReadByte(TPVar(A.Items[0])^.Value);
  result := true;
end;

{Script ReadToEditor(size, position, buffer...);
 เขียนข้อมูลจากบัฟเฟอร์ลงใน hex editor
 พารามิเตอร์:
   size ขนาดข้อมูลเป็นไบต์
   position ตำแหน่งใน hex editor
   buffer ตัวแปรสำหรับเก็บข้อมูล หรืออาเรย์ที่สร้างด้วย CreateByteArray}
function Script_ReadToEditor(Sender:TObject; var A:TVarList) : boolean;
var
  DataArr: array of byte;
  size, i: integer;
begin

  if A.Count < 3 then Exit(false);

  size := TPVar(A.Items[0])^.Value;
  if size < 1 then Exit(false);
  if TPVar(A.Items[1])^.Value < 0 then Exit(false);
  SetLength(DataArr, size);

  //กรณีที่ buffer เป็นอาเรย์
  if (VarIsArray(TPVar(A.Items[2])^.Value)) then
  for i := 0 to size-1 do
  begin
    DataArr[i] := TPVar(A.Items[2])^.Value[i];
  end
  else
  for i := 0 to size-1 do
  begin
    DataArr[i] := TPVar(A.Items[i+2])^.Value;
  end;

  RomF.Clear;
  MainForm.MPHexEditorEx.SaveToStream(RomF);
  RomF.Position := TPVar(A.Items[1])^.Value;

  RomF.WriteBuffer(DataArr[0], size);

  RomF.Position := 0;
  MainForm.MPHexEditorEx.LoadFromStream(RomF);

  Result := true;
end;

{Script WriteFromEditor(size, position, buffer...);
 เขียนข้อมูลจาก hex editor ขนาด size เริ่มจากตำแหน่ง position
 พารามิเตอร์:
   size ขนาดข้อมูลเป็นไบต์
   position ตำแหน่งใน hex editor
   buffer ตัวแปรสำหรับเก็บข้อมูล หรืออาเรย์ที่สร้างด้วย CreateByteArray}
function Script_WriteFromEditor(Sender:TObject; var A:TVarList) : boolean;
var
  DataArr: array of byte;
  size, i: integer;
begin

  if A.Count < 3 then Exit(false);

  size := TPVar(A.Items[0])^.Value;
   if size < 1 then Exit(false);
  SetLength(DataArr, size);

  RomF.Clear;
  MainForm.MPHexEditorEx.SaveToStream(RomF);
  RomF.Position := TPVar(A.Items[1])^.Value;
  RomF.ReadBuffer(DataArr[0], size);

  //กรณีที่ buffer เป็นอาเรย์
  if (VarIsArray(TPVar(A.Items[2])^.Value)) then
  for i := 0 to size-1 do
  begin
    TPVar(A.Items[2])^.Value[i] := DataArr[i];
  end
  else
  for i := 0 to size-1 do
  begin
    TPVar(A.Items[i+2])^.Value := DataArr[i];
  end;

  Result := true;
end;

{Script GetEditorDataSize: Longword;
 คืนขนาดข้อมูลใน hex editor
 }
function Script_GetEditorDataSize(Sender:TObject; var A:TVarList; var R: TVar) : boolean;
begin
  R.Value := MainForm.MPHexEditorEx.DataSize;
  result := true;
end;


//------------------------------------------------------------------------------
procedure SetScriptFunctions(PC : TPasCalc);
begin
  PC.SetFunction('Delay', @Script_Delay);
  PC.SetFunction('ShowMessage', @Script_ShowMessage);
  PC.SetFunction('InputBox', @Script_InputBox);
  PC.SetFunction('LogPrint', @Script_LogPrint);
  PC.SetFunction('ProgressBar', @Script_ProgressBar);
  PC.SetFunction('IntToHex', @Script_IntToHex);
  PC.SetFunction('CHR', @Script_CHR);

  PC.SetFunction('ReadToEditor', @Script_ReadToEditor);
  PC.SetFunction('WriteFromEditor', @Script_WriteFromEditor);
  PC.SetFunction('GetEditorDataSize', @Script_GetEditorDataSize);

  PC.SetFunction('CreateByteArray', @Script_CreateByteArray);
  PC.SetFunction('GetArrayItem', @Script_GetArrayItem);
  PC.SetFunction('SetArrayItem', @Script_SetArrayItem);

  PC.SetFunction('SPIEnterProgMode', @Script_SPIEnterProgMode);
  PC.SetFunction('SPIExitProgMode', @Script_SPIExitProgMode);
  PC.SetFunction('SPIRead', @Script_SPIRead);
  PC.SetFunction('SPIWrite', @Script_SPIWrite);
  PC.SetFunction('SPIReadToEditor', @Script_SPIReadToEditor);
  PC.SetFunction('SPIWriteFromEditor', @Script_SPIWriteFromEditor);

  PC.SetFunction('I2CEnterProgMode', @Script_I2CEnterProgMode);
  PC.SetFunction('I2CExitProgMode', @Script_I2CExitProgMode);
  PC.SetFunction('I2CReadWrite', @Script_I2CReadWrite);
  PC.SetFunction('I2CStart', @Script_I2CStart);
  PC.SetFunction('I2CStop', @Script_I2CStop);
  PC.SetFunction('I2CWriteByte', @Script_I2CWriteByte);
  PC.SetFunction('I2CReadByte', @Script_I2CReadByte);

  SetFunctions(PC);
end;

procedure SetScriptVars();
begin
  ScriptEngine.SetValue('_IC_Name', CurrentICParam.Name);
  ScriptEngine.SetValue('_IC_Size', CurrentICParam.Size);
  ScriptEngine.SetValue('_IC_Page', CurrentICParam.Page);
  ScriptEngine.SetValue('_IC_SpiCmd', CurrentICParam.SpiCmd);
  ScriptEngine.SetValue('_IC_MWAddrLen', CurrentICParam.MWAddLen);
  ScriptEngine.SetValue('_IC_I2CAddrType', CurrentICParam.I2CAddrType);
  ScriptEngine.SetValue('_SPI_SPEED_MAX', _SPI_SPEED_MAX);
end;

end.

