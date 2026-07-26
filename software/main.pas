unit main;

//TODO: at45 กำหนดขนาดเพจ
//TODO: at45 ตรวจขนาดเพจก่อนเริ่มทำงาน


{$mode objfpc}{$H+}
{$modeswitch nestedprocvars}

interface

uses
  Classes, SysUtils, LazFileUtils, Forms, Controls, Graphics, Dialogs, StdCtrls,
  ExtCtrls, ComCtrls, Menus, ActnList, Buttons, StrUtils, spi25,
  spi45, spi95, i2c, microwire, spimulti, ft232hhw,
  XMLRead, XMLWrite, DOM, msgstr, Translations, LCLProc, LCLType, LCLTranslator,
  LResources, MPHexEditorEx, MPHexEditor, search, sregedit,
  utilfunc, findchip, DateUtils, lazUTF8, sfdp, opthread, fileformats, prodconfig, serialnum, jedec, protbits,
  pascalc, ScriptsFunc, ScriptEdit, baseHW, UsbAspHW, ch341hw, ch347hw, avrisphw, arduinohw, buzzpirathw;

type

  { TMainForm }

  TMainForm = class(TForm)
    CheckBox_I2C_A1: TToggleBox;
    CheckBox_I2C_A0: TToggleBox;
    CheckBox_I2C_ByteRead: TCheckBox;
    CheckBox_I2C_DevA6: TToggleBox;
    CheckBox_I2C_DevA5: TToggleBox;
    CheckBox_I2C_DevA4: TToggleBox;
    CheckBox_I2C_A2: TToggleBox;
    ComboAddrType: TComboBox;
    ComboBox_chip_scriptrun: TComboBox;
    ComboSPICMD: TComboBox;
    ComboChipSize: TComboBox;
    ComboMWBitLen: TComboBox;
    ComboPageSize: TComboBox;
    Label6: TLabel;
    Label_StartAddress: TLabel;
    MenuHWFT232H: TMenuItem;
    MenuFT232SPIClock: TMenuItem;
    MenuFT232SPI30Mhz: TMenuItem;
    MenuFT232SPI6Mhz: TMenuItem;
    MenuHWCH347: TMenuItem;
    MenuCH347SPIClock: TMenuItem;
    MenuCH347SPIClock468_75KHz: TMenuItem;
    MenuCH347SPIClock60MHz: TMenuItem;
    MenuCH347SPIClock30MHz: TMenuItem;
    MenuCH347SPIClock15MHz: TMenuItem;
    MenuCH347SPIClock7_5MHz: TMenuItem;
    MenuCH347SPIClock3_75MHz: TMenuItem;
    MenuCH347SPIClock1_875MHz: TMenuItem;
    MenuCH347SPIClock937_5KHz: TMenuItem;
    MenuSendAB: TMenuItem;
    StartAddressEdit: TEdit;
    GroupChipSettings: TGroupBox;
    ImageList: TImageList;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    Label5: TLabel;
    Label_chip_scripts: TLabel;
    Label_I2C_DevAddr: TLabel;
    LabelSPICMD: TLabel;
    LabelChipName: TLabel;
    LabelChipInfo: TLabel;
    ChipView: TPaintBox;
    HwTimer: TTimer;
    MenuAutoDetectHW: TMenuItem;
    MenuBlankBeforeWrite: TMenuItem;
    MainMenu: TMainMenu;
    Log: TMemo;
    Menu32Khz: TMenuItem;
    Menu93_75Khz: TMenuItem;
    MenuChip: TMenuItem;
    MenuAutoCheck: TMenuItem;
    ComboItem1: TMenuItem;
    Menu3Mhz: TMenuItem;
    MenuIgnoreBusyBit: TMenuItem;
    MenuGotoOffset: TMenuItem;
    MenuFind: TMenuItem;
    MenuItem1: TMenuItem;
    MenuCopyToClip: TMenuItem;
    CopyLogMenuItem: TMenuItem;
    ClearLogMenuItem: TMenuItem;
    MenuHWUSBASP: TMenuItem;
    MenuHWCH341A: TMenuItem;
    MenuFindChip: TMenuItem;
    MenuHWAVRISP: TMenuItem;
    MenuAVRISPSPIClock: TMenuItem;
    MenuAVRISP8MHz: TMenuItem;
    MenuAVRISP4MHz: TMenuItem;
    MenuAVRISP2MHz: TMenuItem;
    MenuAVRISP1MHz: TMenuItem;
    MenuAVRISP500KHz: TMenuItem;
    MenuAVRISP250KHz: TMenuItem;
    MenuAVRISP125KHz: TMenuItem;
    LangMenuItem: TMenuItem;
    BlankCheckMenuItem: TMenuItem;
    AllowInsertItem: TMenuItem;
    MenuHWARDUINO: TMenuItem;
    MenuHWBUZZPIRAT: TMenuItem;
    MenuArduinoSPIClock: TMenuItem;
    MenuArduinoISP8MHz: TMenuItem;
    MenuArduinoISP4MHz: TMenuItem;
    MenuArduinoISP2MHz: TMenuItem;
    MenuArduinoISP1MHz: TMenuItem;
    MenuArduinoCOMPort: TMenuItem;
    MenuBuzzpiratCOMPort: TMenuItem;
    MenuSkipFF: TMenuItem;
    MenuEraseRangeAuto: TMenuItem;
    MenuEraseRange4K: TMenuItem;
    MenuEraseRange32K: TMenuItem;
    MenuEraseRange64K: TMenuItem;
    MenuEraseSeparator: TMenuItem;
    MenuEraseChip: TMenuItem;
    MenuSmartWrite: TMenuItem;
    MenuChecksum: TMenuItem;
    MenuSFDPDetect: TMenuItem;
    MenuBackgroundOps: TMenuItem;
    MenuDarkTheme: TMenuItem;
    SaveLogMenuItem: TMenuItem;
    MenuFillBuffer: TMenuItem;
    MenuSwapBytes: TMenuItem;
    MenuCheckIDBefore: TMenuItem;
    MenuAutoBackup: TMenuItem;
    MenuCompareChip: TMenuItem;
    MenuCompareFiles: TMenuItem;
    MenuCompareChips: TMenuItem;
    MenuAbout: TMenuItem;
    MenuCredits: TMenuItem;
    MenuOpenProject: TMenuItem;
    MenuSaveProject: TMenuItem;
    MenuProdConfig: TMenuItem;
    MenuRunBatch: TMenuItem;
    MenuSecReg: TMenuItem;
    MenuSecRegWrite: TMenuItem;
    MenuProtInfo: TMenuItem;
    EraseDropDownMenu: TPopupMenu;
    MPHexEditorEx: TMPHexEditorEx;
    ScriptsMenuItem: TMenuItem;
    CreditsMenuItem: TMenuItem;
    BzHelpMenuItem: TMenuItem;
    DebugconsoleMenuItem: TMenuItem;
    ListcomportsMenuItem: TMenuItem;
    MenuItemHardware: TMenuItem;
    MenuBuzzpirat: TMenuItem;
    MenuBuzzpiratPullups: TMenuItem;
    MenuBuzzpiratSPIBUG: TMenuItem;
    MenuBuzzpiratResetEach: TMenuItem;
    ClearBuzzlogMenuItem: TMenuItem;
    MenuBuzzpiratPower: TMenuItem;
	MenuBuzzpiratLessdbg: TMenuItem;
    MenuBuzzpiratSPINormal: TMenuItem;
    MenuBuzzpiratSPIHiz: TMenuItem;
    MenuBuzzpiratSPI8MHz: TMenuItem;
    MenuBuzzpiratSPI4MHz: TMenuItem;
    MenuBuzzpiratSPI2P6MHz: TMenuItem;
    MenuBuzzpiratSPI2MHz: TMenuItem;
    MenuBuzzpiratSPI1MHz: TMenuItem;
    MenuBuzzpiratSPI250KHz: TMenuItem;
    MenuBuzzpiratSPI125KHz: TMenuItem;
    MenuBuzzpiratSPI30KHz: TMenuItem;
    MenuBuzzpiratI2CClock: TMenuItem;
    MenuBuzzpiratI2C400KHz: TMenuItem;
    MenuBuzzpiratI2C100KHz: TMenuItem;
    MenuBuzzpiratI2C50KHz: TMenuItem;
    MenuBuzzpiratI2C5KHz: TMenuItem;
    MenuBuzzpiratJustI2CScan: TMenuItem;
    MenuItemBenchmark: TMenuItem;
    MenuItemEditSreg: TMenuItem;
    MenuItemReadSreg: TMenuItem;
    MenuItemLockFlash: TMenuItem;
    MenuItem4: TMenuItem;
    MenuMW8Khz: TMenuItem;
    MenuMW16Khz: TMenuItem;
    MenuMicrowire: TMenuItem;
    MenuMW32Khz: TMenuItem;
    MenuMWClock: TMenuItem;
    MenuOptions: TMenuItem;
    MenuSPI: TMenuItem;
    MenuSPIClock: TMenuItem;
    Menu1_5Mhz: TMenuItem;
    Menu750Khz: TMenuItem;
    Menu375Khz: TMenuItem;
    Menu187_5Khz: TMenuItem;
    OpenDialog: TOpenDialog;
    DropDownMenu: TPopupMenu;
    EditorPopupMenu: TPopupMenu;
    LogPopupMenu: TPopupMenu;
    DropdownMenuLock: TPopupMenu;
    Panel_I2C_DevAddr: TPanel;
    BlankCheckDropDownMenu: TPopupMenu;
    ProgressBar: TProgressBar;
    RadioI2C: TRadioButton;
    RadioMw: TRadioButton;
    RadioSPI: TRadioButton;
    SaveDialog: TSaveDialog;
    SpeedButton1: TSpeedButton;
    Splitter1: TSplitter;
    StatusBar: TStatusBar;
    CheckBox_I2C_DevA7: TToggleBox;
    ToolBar: TToolBar;
    ButtonRead: TToolButton;
    ButtonWrite: TToolButton;
    ButtonVerify: TToolButton;
    ToolButton1: TToolButton;
    ButtonReadID: TToolButton;
    ButtonErase: TToolButton;
    ToolButton2: TToolButton;
    ToolButton3: TToolButton;
    ButtonBlock: TToolButton;
    ButtonOpenHex: TToolButton;
    ButtonSaveHex: TToolButton;
    ButtonCancel: TToolButton;
    ToolButton4: TToolButton;
    ToolButton5: TToolButton;
    procedure BlankCheckMenuItemClick(Sender: TObject);
    procedure MenuEraseRangeClick(Sender: TObject);
    procedure MenuSmartWriteClick(Sender: TObject);
    procedure MenuChecksumClick(Sender: TObject);
    procedure MenuSFDPDetectClick(Sender: TObject);
    procedure MenuBackgroundOpsClick(Sender: TObject);
    procedure MenuDarkThemeClick(Sender: TObject);
    procedure SaveLogMenuItemClick(Sender: TObject);
    procedure MenuFillBufferClick(Sender: TObject);
    procedure MenuSwapBytesClick(Sender: TObject);
    procedure MenuCompareChipClick(Sender: TObject);
    procedure MenuCompareFilesClick(Sender: TObject);
    procedure MenuCompareChipsClick(Sender: TObject);
    procedure MenuAboutClick(Sender: TObject);
    procedure MenuCreditsClick(Sender: TObject);
    procedure VersionCopyClick(Sender: TObject);
    procedure MenuOpenProjectClick(Sender: TObject);
    procedure MenuSaveProjectClick(Sender: TObject);
    procedure MenuProdConfigClick(Sender: TObject);
    procedure MenuRunBatchClick(Sender: TObject);
    procedure MenuSecRegClick(Sender: TObject);
    procedure MenuSecRegWriteClick(Sender: TObject);
    procedure MenuProtInfoClick(Sender: TObject);
    procedure ChipViewPaint(Sender: TObject);
    procedure HwTimerTimer(Sender: TObject);
    procedure ButtonEraseClick(Sender: TObject);
    procedure ButtonReadClick(Sender: TObject);
    procedure ClearLogMenuItemClick(Sender: TObject);
    procedure ComboSPICMDChange(Sender: TObject);
    procedure CopyLogMenuItemClick(Sender: TObject);
    procedure AllowInsertItemClick(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: boolean);
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure FormDropFiles(Sender: TObject; const FileNames: array of string);
    procedure FormDestroy(Sender: TObject);
    procedure ChipClick(Sender: TObject);
    procedure ChangeLang(Sender: TObject);
    procedure ComboItem1Click(Sender: TObject);
    procedure MenuArduinoCOMPortClick(Sender: TObject);
    procedure MenuBuzzpiratCOMPortClick(Sender: TObject);
    procedure MenuHWARDUINOClick(Sender: TObject);
    procedure MenuHWBUZZPIRATClick(Sender: TObject);
    procedure MenuHWAVRISPClick(Sender: TObject);
    procedure MenuCopyToClipClick(Sender: TObject);
    procedure MenuFindChipClick(Sender: TObject);
    procedure MenuFindClick(Sender: TObject);
    procedure MenuGotoOffsetClick(Sender: TObject);
    procedure MenuHWCH341AClick(Sender: TObject);
    procedure MenuHWCH347Click(Sender: TObject);
    procedure MenuHWFT232HClick(Sender: TObject);
    procedure MenuHWUSBASPClick(Sender: TObject);
    procedure MenuItemBenchmarkClick(Sender: TObject);
    procedure MenuItemEditSregClick(Sender: TObject);
    procedure MenuItemLockFlashClick(Sender: TObject);
    procedure MenuItemReadSregClick(Sender: TObject);
    procedure MPHexEditorExChange(Sender: TObject);
    procedure RadioI2CChange(Sender: TObject);
    procedure RadioMwChange(Sender: TObject);
    procedure RadioSPIChange(Sender: TObject);
    procedure ButtonWriteClick(Sender: TObject);
    procedure ButtonVerifyClick(Sender: TObject);
    procedure ButtonBlockClick(Sender: TObject);
    procedure ButtonReadIDClick(Sender: TObject);
    procedure ButtonOpenHexClick(Sender: TObject);
    procedure ButtonSaveHexClick(Sender: TObject);
    procedure ButtonCancelClick(Sender: TObject);
    procedure I2C_DevAddrChange(Sender: TObject);
    procedure ScriptsMenuItemClick(Sender: TObject);
    procedure CreditsMenuItemClick(Sender: TObject);
    procedure BzHelpMenuItemClick(Sender: TObject);
    procedure DebugconsoleMenuItemClick(Sender: TObject);
    procedure ListcomportsMenuItemClick(Sender: TObject);
    procedure SpeedButton1Click(Sender: TObject);
    procedure StartAddressEditChange(Sender: TObject);
    procedure StartAddressEditKeyPress(Sender: TObject; var Key: char);
    procedure VerifyFlash(BlankCheck: boolean = false);
  private
    { ส่วนประกาศแบบ private }
  public
    { ส่วนประกาศแบบ public }

  end;

  procedure LogPrint(text: string);
  procedure SaveOptions(XMLfile: TXMLDocument);
  Procedure LoadOptions(XMLfile: TXMLDocument);
  procedure LoadXML;
  procedure Translate(XMLfile: TXMLDocument);
  function OpenDevice: boolean;
  function SetSPISpeed(OverrideSpeed: byte): integer;
  procedure SyncUI_ICParam();
  function UserCancel(): boolean;

const
  SPI_CMD_25             = 0;
  SPI_CMD_45             = 1;
  SPI_CMD_KB             = 2;
  SPI_CMD_95             = 3;

  ChipListFileName       = 'chiplist.xml';
  //ตารางชิปเพิ่มเติมที่แปลงมาจาก flashrom ไฟล์นี้เป็น GPL ไม่ใช่ MIT
  //จึงแยกไว้ต่างหาก ถ้าไม่มีไฟล์ก็ทำงานได้ตามปกติ
  ChipListFile2Name      = 'chiplist-flashrom.xml';
  SettingsFileName       = 'settings.xml';
  ScriptsPath            = 'scripts'+DirectorySeparator;

type

  TCurrentICParam = record
    Name: string;
    Page: integer;
    Size: Longword;
    SpiCmd: byte;
    I2CAddrType: byte;
    MWAddLen: byte;
    Sector: Longword;    //ขนาดเซกเตอร์สำหรับลบ ถ้าเป็น 0 คือไม่ระบุ จะใช้ 4096
    SectorOpcode: byte;  //opcode สำหรับลบเซกเตอร์ ถ้าเป็น 0 จะเลือกให้ตามขนาด
    ID: string;          //id จาก chiplist.xml ใช้ตรวจก่อนเริ่มทำงานกับชิป
    Note: string;        //หมายเหตุจาก chiplist.xml เช่นข้อควรระวังเรื่องแรงดัน

    Script: string;
  end;


var
  MainForm: TMainForm;
  ChipListFile: TXMLDocument;
  ChipListFile2: TXMLDocument;
  SettingsFile: TXMLDocument;
  CurrentICParam: TCurrentICParam;
  ScriptEngine: TPasCalc;
  RomF: TMemoryStream;

  AsProgrammer: TAsProgrammer;

  Buzzpirat_ClocKhz: integer = 0;
  Buzzpirat_Pulls: integer = 0;
  Buzzpirat_Power: integer = 0;
  Arduino_COMPort: string;
  Arduino_BaudRate: integer = 1000000;
  Buzzpirat_COMPort: string;
implementation


var
  TimeCounter: TDateTime;
  CurrentLang: string = 'en';

{$R *.lfm}

type
  //ส่งการอัปเดตหน้าจอจาก thread เบื้องหลังไปให้ thread หลัก
  TUIProxy = class
  private
    FMsg: string;
    FValue: integer;
    procedure SyncLog;
    procedure SyncProgressMax;
    procedure SyncProgressPos;
    procedure SyncProgressReset;
    procedure SyncStatus;
  public
    procedure Status(const S: string);
    procedure Log(const S: string);
    procedure ProgressMax(V: integer);
    procedure ProgressPos(V: integer);
    procedure ProgressReset;
  end;

var
  UIProxy: TUIProxy;

  //กันการเรียกซ้อน เพราะเมนูไม่เหมือนปุ่มบนแถบเครื่องมือ
  //มันยังคลิกได้อยู่ตอนที่ thread หลักกำลังปั๊ม message
  OperationRunning: boolean = False;

  //เลขรันนิ่งอัตโนมัติและการผลิตเป็นชุด
  ProdSettings: TProdSettings;

  //สถานะที่วาดเป็นไฟบอกสถานะในแผงด้านซ้าย
  ProgrammerPresent: boolean = False;
  ChipDetected: boolean = False;

  //สถานะหน้าจอที่อ่านเก็บไว้บน thread หลักก่อนเริ่มงาน
  //thread เบื้องหลังต้องอ่านจากตรงนี้ ห้ามอ่านจาก control โดยตรง
  OpUI: record
    ChipSize: cardinal;
    SkipFF: boolean;
    AutoCheck: boolean;
    IgnoreBusy: boolean;
  end;

procedure TUIProxy.SyncLog;
begin
  MainForm.Log.Lines.Add(FMsg);
end;

procedure TUIProxy.SyncProgressMax;
begin
  MainForm.ProgressBar.Max := FValue;
end;

procedure TUIProxy.SyncProgressPos;
begin
  MainForm.ProgressBar.Position := FValue;
end;

procedure TUIProxy.SyncProgressReset;
begin
  MainForm.ProgressBar.Style := pbstNormal;
  MainForm.ProgressBar.Position := 0;
end;

procedure TUIProxy.SyncStatus;
begin
  MainForm.StatusBar.Panels.Items[1].Text := FMsg;
end;

procedure TUIProxy.Status(const S: string);
begin
  FMsg := S;
  TThread.Synchronize(nil, @SyncStatus);
end;

procedure TUIProxy.Log(const S: string);
begin
  FMsg := S;
  TThread.Synchronize(nil, @SyncLog);
end;

procedure TUIProxy.ProgressMax(V: integer);
begin
  FValue := V;
  TThread.Synchronize(nil, @SyncProgressMax);
end;

procedure TUIProxy.ProgressPos(V: integer);
begin
  FValue := V;
  TThread.Synchronize(nil, @SyncProgressPos);
end;

procedure TUIProxy.ProgressReset;
begin
  TThread.Synchronize(nil, @SyncProgressReset);
end;

//ความเร็วและเวลาที่เหลือ คิดจากงานที่ทำไปแล้วเทียบกับเวลาที่ใช้
//เป็นข้อมูลที่ต้องมีเวลารออ่านชิป 64 Mbit ซึ่งกินเวลาหลายสิบนาที
procedure ShowSpeed(BytesDone, BytesTotal: cardinal; Started: TDateTime);
var
  Sec, Rate: double;
  Remain: integer;
  s: string;
begin
  Sec := MilliSecondsBetween(Now, Started) / 1000;
  if (Sec < 0.5) or (BytesDone = 0) then Exit;

  Rate := BytesDone / Sec;
  if Rate < 1024 then
    s := Format('%.0f B/s', [Rate])
  else if Rate < 1024 * 1024 then
    s := Format('%.1f KB/s', [Rate / 1024])
  else
    s := Format('%.2f MB/s', [Rate / (1024 * 1024)]);

  if (BytesTotal > BytesDone) and (Rate > 0) then
  begin
    Remain := Round((BytesTotal - BytesDone) / Rate);
    s := s + Format('   %d:%.2d left', [Remain div 60, Remain mod 60]);
  end;

  if InWorkerThread then
    UIProxy.Status(s)
  else
    MainForm.StatusBar.Panels.Items[1].Text := s;
end;

procedure ClearSpeed;
begin
  if InWorkerThread then
    UIProxy.Status('')
  else
    MainForm.StatusBar.Panels.Items[1].Text := '';
end;

//ตั้งค่า progress แบบปลอดภัยต่อ thread
procedure SetProgressMax(V: integer);
begin
  if InWorkerThread then
    UIProxy.ProgressMax(V)
  else
    MainForm.ProgressBar.Max := V;
end;

procedure SetProgressPos(V: integer);
begin
  if InWorkerThread then
    UIProxy.ProgressPos(V)
  else
    MainForm.ProgressBar.Position := V;
end;

//อ่านสถานะหน้าจอเก็บไว้ ต้องเรียกจาก thread หลักเท่านั้น
//และต้องเรียกก่อนเริ่มงาน
procedure CaptureUIState;
begin
  OpUI.ChipSize := 0;
  if IsNumber(MainForm.ComboChipSize.Text) then
    OpUI.ChipSize := StrToInt(MainForm.ComboChipSize.Text);

  OpUI.SkipFF     := MainForm.MenuSkipFF.Checked;
  OpUI.AutoCheck  := MainForm.MenuAutoCheck.Checked;
  OpUI.IgnoreBusy := MainForm.MenuIgnoreBusyBit.Checked;
end;

procedure SyncUI_ICParam();
begin
  CurrentICParam.SpiCmd := MainForm.ComboSPICMD.ItemIndex;
  CurrentICParam.I2CAddrType := MainForm.ComboAddrType.ItemIndex;

  if IsNumber(MainForm.ComboMWBitLen.Text) then
    CurrentICParam.MWAddLen := StrToInt(MainForm.ComboMWBitLen.Text) else
      CurrentICParam.MWAddLen := 0;

  if IsNumber(MainForm.ComboPageSize.Text) then
    CurrentICParam.Page := StrToInt(MainForm.ComboPageSize.Text)
  else if UpCase(MainForm.ComboPageSize.Text) = 'SSTB' then
    CurrentICParam.Page := -1
  else if UpCase(MainForm.ComboPageSize.Text) = 'SSTW' then
    CurrentICParam.Page := -2
  else
    CurrentICParam.Page := 0;

  if IsNumber(MainForm.ComboChipSize.Text) then
    CurrentICParam.Size := StrToInt(MainForm.ComboChipSize.Text) else
      CurrentICParam.Size := 0;
end;

function UserCancel(): boolean;
begin
  Result := false;
  if MainForm.ButtonCancel.Tag <> 0 then
  begin
    LogPrint(STR_USER_CANCEL);

    if InWorkerThread then
      UIProxy.ProgressReset
    else
    begin
      MainForm.ProgressBar.Style := pbstNormal;
      MainForm.ProgressBar.Position:= 0;
    end;

    Result := true;
  end;
end;

procedure LoadXML;
var
  RootNode: TDOMNode;
begin
  ChipListFile := nil;
  ChipListFile2 := nil;
  SettingsFile := nil;
  if FileExists(ChipListFileName) then
  begin
    try
      ReadXMLFile(ChipListFile, ChipListFileName);
    except
      on E: EXMLReadError do
      begin
        ShowMessage(E.Message);
        ChipListFile := nil;
      end;
    end;
  end;

  //ไฟล์เสริม มีก็ใช้ ไม่มีก็ข้ามไปเงียบ ๆ
  if FileExists(ChipListFile2Name) then
  begin
    try
      ReadXMLFile(ChipListFile2, ChipListFile2Name);
    except
      on E: EXMLReadError do
      begin
        ShowMessage(E.Message);
        ChipListFile2 := nil;
      end;
    end;
  end;

  if FileExists(SettingsFileName) then
  begin
    try
      ReadXMLFile(SettingsFile, SettingsFileName);
    except
      on E: EXMLReadError do
      begin
        ShowMessage(E.Message);
        SettingsFile := nil;
      end;
    end;
  end else
  begin
    SettingsFile := TXMLDocument.Create;
    // สร้าง root node
    RootNode := SettingsFile.CreateElement('settings');
    SettingsFile.Appendchild(RootNode);
  end;

end;

procedure TMainForm.ChangeLang(Sender: TObject);
begin
  CurrentLang := TMenuItem(Sender).Hint;

  Translations.TranslateResourceStrings(GetCurrentDir + '/lang/' + CurrentLang + '.po');
  LRSTranslator.Free;
  LRSTranslator:= TPOTranslator.Create(GetCurrentDir + '/lang/' + CurrentLang + '.po');
  TPOTranslator(LRSTranslator).UpdateTranslation(MainForm);
  TPOTranslator(LRSTranslator).UpdateTranslation(ScriptEditForm);
  TPOTranslator(LRSTranslator).UpdateTranslation(ChipSearchForm);
  TPOTranslator(LRSTranslator).UpdateTranslation(sregeditForm);
  TPOTranslator(LRSTranslator).UpdateTranslation(SearchForm);
end;

procedure LoadLangList();
var
  LangDir: string;
  LangName: string;
  LangFile: Text;
  SearchRec : TSearchRec;
  MenuItem: TMenuItem;
begin
  LangDir := GetCurrentDir + '/lang/';

  If FindFirstUTF8(LangDir+'*.po', faAnyFile, SearchRec) = 0 then
  begin
    Repeat
      AssignFile(LangFile, LangDir+SearchRec.Name);
      Reset(LangFile);
      ReadLn(LangFile, LangName);
      CloseFile(LangFile);
      Delete(LangName, 1, 1);

      MenuItem := NewItem(LangName, 0, False, True, @MainForm.ChangeLang, 0, '');
      MenuItem.Hint := ExtractFileNameOnly(SearchRec.Name);
      MenuItem.AutoCheck := true;
      MenuItem.RadioItem := true;
      MainForm.LangMenuItem.Add(MenuItem);
      if MenuItem.Hint = Currentlang then MenuItem.Checked := true;

    Until FindNextUTF8(SearchRec) <> 0;
  end;

  FindCloseUTF8(SearchRec);
end;

procedure Translate(XMLfile: TXMLDocument);
var
   PODirectory: String;
   Node: TDOMNode;
begin

  PODirectory:= GetCurrentDir + '/lang/';
  CurrentLang:='';

  if XMLfile <> nil then
  begin

      Node := XMLfile.DocumentElement.FindNode('locale');

      if (Node <> nil) then
      if (Node.HasAttributes) then
      begin

        if  Node.Attributes.GetNamedItem('lang') <> nil then
          CurrentLang := UTF16ToUTF8(Node.Attributes.GetNamedItem('lang').NodeValue);

      end;
  end;

  if CurrentLang = '' then
  begin
    CurrentLang := 'en';
    LRSTranslator:= TPOTranslator.Create(PODirectory + CurrentLang + '.po');
    Translations.TranslateResourceStrings(PODirectory + CurrentLang + '.po');
    Exit;
  end;

  if FileExistsUTF8(PODirectory + CurrentLang + '.po') then
  begin
    LRSTranslator:= TPOTranslator.Create(PODirectory + CurrentLang + '.po');
    Translations.TranslateResourceStrings(PODirectory + CurrentLang + '.po');
  end;

end;               

procedure LogPrint(text: string);
begin
  if InWorkerThread then
    UIProxy.Log(text)
  else
    MainForm.Log.Lines.Add(text);
end;


//บอกให้ตรงจุดว่าไดรเวอร์ของฮาร์ดแวร์ตัวไหนน่าจะยังไม่ได้ติดตั้ง
//ข้อความจาก DLL มักบอกแค่ว่าเปิดอุปกรณ์ไม่ได้ ซึ่งไม่ช่วยอะไรเลย
procedure LogDriverHint;
begin
  case AsProgrammer.Current_HW of
    CHW_CH341:
      LogPrint(STR_DRIVER_HINT + 'drivers\CH341\CH341PAR.EXE (WCH CH341PAR)');
    CHW_CH347:
      LogPrint(STR_DRIVER_HINT + 'drivers\CH343\CH343 (WCH CH347PAR)');
    CHW_FT232H:
      LogPrint(STR_DRIVER_HINT + 'drivers\FT232\CDM212364_Setup.exe (FTDI D2XX)');
    CHW_USBASP, CHW_AVRISP:
      LogPrint(STR_DRIVER_HINT + 'drivers\usbasp\zadig (libusb-win32)');
    CHW_ARDUINO, CHW_BUZZPIRAT:
      LogPrint(STR_DRIVER_HINT_COM);
  end;
end;

function OpenDevice: boolean;
begin
  if not AsProgrammer.Programmer.DevOpen then
  begin
    LogPrint(AsProgrammer.Programmer.GetLastError);
    LogDriverHint;
    result := false;
    Exit;
  end;

  LogPrint(STR_CURR_HW+AsProgrammer.Programmer.HardwareName);
  result := true
end;


function IsLockBitsEnabled: boolean;
var
  sreg: byte;
begin
  result := false;
  sreg := 0;
  if MainForm.ComboSPICMD.ItemIndex = SPI_CMD_25 then
  begin
    UsbAsp25_ReadSR(sreg);
    if IsBitSet(sreg, 2) or
       IsBitSet(sreg, 3) or
       IsBitSet(sreg, 4) or
       IsBitSet(sreg, 5) or
       IsBitSet(sreg, 6) or
       IsBitSet(sreg, 7)
    then
    begin
      LogPrint(STR_BLOCK_EN);
      Result := true;
    end;
  end;

  if MainForm.ComboSPICMD.ItemIndex = SPI_CMD_45 then
  begin
    UsbAsp45_ReadSR(sreg);
    if (sreg and 2 <> 0) then
    begin
      LogPrint(STR_BLOCK_EN);
      Result := true;
    end;
  end;

end;

//------------------------------------------------------------------------
// หน้าตาโปรแกรม: ชุดไอคอนและธีมสไตล์เครื่องมือช่าง
//------------------------------------------------------------------------

const
  IconDirName = 'icons' + DirectorySeparator + 'modern' + DirectorySeparator;
  IconPixelSize = 40;         //ขนาดไฟล์ไอคอนใน icons\modern
  ToolButtonSize = 48;        //ขนาดปุ่มบนแถบเครื่องมือ

  //TColor เก็บเป็น $00BBGGRR ลำดับไบต์จึงกลับด้านกับโค้ดสี HTML

  //ธีมสว่าง เป็นค่าเริ่มต้น
  LIGHT_CHROME  = $F7F4F2;  //#F2F4F7 พื้นหลังหน้าต่างและแผงต่าง ๆ
  LIGHT_SURFACE = $FFFFFF;  //#FFFFFF ช่อง log และ hex editor
  LIGHT_TEXT    = $33291F;  //#1F2933 ตัวอักษร
  LIGHT_ACCENT  = $D16E0A;  //#0A6ED1 สีเน้น

  //ธีมมืด
  DARK_CHROME   = $241F1B;  //#1B1F24
  DARK_SURFACE  = $1C1814;  //#14181C
  DARK_TEXT     = $D9D1C9;  //#C9D1D9
  DARK_ACCENT   = $F3B32B;  //#2BB3F3

//เปลี่ยนไอคอนที่ฝังมาในโปรแกรมเป็นไฟล์จาก icons\modern
//ถ้าไม่มีโฟลเดอร์หรือไฟล์ไม่ครบ จะใช้ไอคอนเดิมที่ฝังไว้
procedure LoadModernIcons;
var
  Files: TStringList;
  png: TPortableNetworkGraphic;
  sr: TSearchRec;
  i: integer;
begin
  if not DirectoryExists(IconDirName) then Exit;

  Files := TStringList.Create;
  try
    if FindFirst(IconDirName + '*.png', faAnyFile, sr) = 0 then
    begin
      repeat
        if (sr.Attr and faDirectory) = 0 then Files.Add(sr.Name);
      until FindNext(sr) <> 0;
      FindClose(sr);
    end;

    //ลำดับกำหนดด้วยชื่อไฟล์ 00_ ถึง 08_
    if Files.Count < MainForm.ImageList.Count then Exit;
    Files.Sort;

    //ไอคอนชุดนี้เป็น 40x40 ต้องตั้งขนาดก่อนใส่ ไม่งั้นจะถูกย่อลงเป็น 32
    MainForm.ImageList.Clear;
    MainForm.ImageList.Width := IconPixelSize;
    MainForm.ImageList.Height := IconPixelSize;

    for i := 0 to Files.Count - 1 do
    begin
      png := TPortableNetworkGraphic.Create;
      try
        png.LoadFromFile(IconDirName + Files[i]);
        MainForm.ImageList.Add(png, nil);
      finally
        png.Free;
      end;
    end;
  finally
    Files.Free;
  end;
end;

procedure ApplyTheme(Dark: boolean);
var
  i: integer;
  C: TComponent;
  ChromeColor, SurfaceColor, TextColor, AccentColor: TColor;
begin
  if Dark then
  begin
    ChromeColor  := DARK_CHROME;
    SurfaceColor := DARK_SURFACE;
    TextColor    := DARK_TEXT;
    AccentColor  := DARK_ACCENT;
  end
  else
  begin
    ChromeColor  := LIGHT_CHROME;
    SurfaceColor := LIGHT_SURFACE;
    TextColor    := LIGHT_TEXT;
    AccentColor  := LIGHT_ACCENT;
  end;

  MainForm.Color := ChromeColor;
  MainForm.ToolBar.Color := ChromeColor;
  MainForm.ToolBar.Flat := True;

  //ปุ่มบนแถบเครื่องมือต้องใหญ่พอกับไอคอน 40 พิกเซล
  MainForm.ToolBar.ButtonWidth := ToolButtonSize;
  MainForm.ToolBar.ButtonHeight := ToolButtonSize;
  MainForm.ToolBar.Height := ToolButtonSize + 8;

  //ตัวเลือกโปรโตคอลอยู่บนแถบเดียวกัน ต้องจัดให้อยู่กลางแนวตั้ง
  MainForm.RadioSPI.Top := (MainForm.ToolBar.Height - MainForm.RadioSPI.Height) div 2;
  MainForm.RadioI2C.Top := MainForm.RadioSPI.Top;
  MainForm.RadioMw.Top  := MainForm.RadioSPI.Top;
  MainForm.StatusBar.Color := ChromeColor;
  MainForm.Panel_I2C_DevAddr.Color := ChromeColor;
  MainForm.GroupChipSettings.Color := ChromeColor;

  //ให้ log ใช้ฟอนต์ความกว้างคงที่ อ่านแอดเดรสกับ hex ได้ง่ายกว่ามาก
  MainForm.Log.Color := SurfaceColor;
  MainForm.Log.Font.Color := TextColor;
  MainForm.Log.Font.Name := 'Consolas';

  MainForm.MPHexEditorEx.Color := SurfaceColor;
  MainForm.MPHexEditorEx.Font.Color := TextColor;

  //สีของไบต์ที่ต่างกันตอนเทียบข้อมูล ต้องเด่นพอให้เห็นทันทีในตาราง
  if Dark then
  begin
    MainForm.MPHexEditorEx.Colors.ChangedText := TColor($8080FF);        //#FF8080
    MainForm.MPHexEditorEx.Colors.ChangedBackground := TColor($1F1A3A);  //#3A1A1F
  end
  else
  begin
    MainForm.MPHexEditorEx.Colors.ChangedText := TColor($1E26B3);        //#B3261E
    MainForm.MPHexEditorEx.Colors.ChangedBackground := TColor($DEE1FF);  //#FFE1DE
  end;

  //ป้ายบางตัวใน main.lfm ปิด ParentFont ไว้ จึงต้องตั้งสีให้ทีละตัว
  for i := 0 to MainForm.ComponentCount - 1 do
  begin
    C := MainForm.Components[i];

    if C is TLabel then
    begin
      TLabel(C).Transparent := True;
      TLabel(C).Font.Color := TextColor;
    end;

    if C is TRadioButton then TRadioButton(C).Font.Color := TextColor;
    if C is TCheckBox then TCheckBox(C).Font.Color := TextColor;
    if C is TGroupBox then TGroupBox(C).Font.Color := TextColor;
  end;

  //บล็อกสรุปข้อมูลชิปใช้ฟอนต์ความกว้างคงที่ ตัวเลขจะได้เรียงตรงกัน
  MainForm.LabelChipInfo.Font.Name := 'Consolas';
  MainForm.LabelChipInfo.Font.Color := TextColor;

  MainForm.LabelChipName.Font.Color := AccentColor;
  MainForm.LabelChipName.Font.Style := [fsBold];
end;

//------------------------------------------------------------------------
// ไฟล์โปรเจกต์: เก็บชิป การตั้งค่า และเนื้อหาบัฟเฟอร์ไว้ในไฟล์เดียว
//
// รูปแบบ: 'APXPROJ1' | ความยาวส่วนหัว 4 ไบต์ LE | ส่วนหัว XML | ข้อมูลดิบ
// ส่วนหัวเป็นข้อความ ข้อมูลเป็นไบต์ดิบ ไม่ใช้ base64 ไฟล์จึงไม่บวมสามเท่า
//------------------------------------------------------------------------

const
  ProjectMagic = 'APXPROJ1';

function SaveProjectFile(const FileName: string): boolean;
var
  F: TFileStream;
  Header: string;
  HeaderBytes: TBytes;
  Len: longword;
  Buf: TMemoryStream;
begin
  Result := False;

  Header :=
    '<asprogrammer_project version="4">' + LineEnding +
    '  <chip name="' + CurrentICParam.Name + '"' +
          ' id="' + CurrentICParam.ID + '"' +
          ' size="' + MainForm.ComboChipSize.Text + '"' +
          ' page="' + MainForm.ComboPageSize.Text + '"' +
          ' sector="' + IntToStr(CurrentICParam.Sector) + '"' +
          ' sectorcmd="' + IntToHex(CurrentICParam.SectorOpcode, 2) + '"' +
          ' spicmd="' + IntToStr(MainForm.ComboSPICMD.ItemIndex) + '"' +
          ' protocol="' + BoolToStr(MainForm.RadioSPI.Checked, 'spi',
                          BoolToStr(MainForm.RadioI2C.Checked, 'i2c', 'mw')) + '"' +
          ' addrtype="' + IntToStr(MainForm.ComboAddrType.ItemIndex) + '"' +
          ' mwbitlen="' + MainForm.ComboMWBitLen.Text + '"/>' + LineEnding +
    '  <options startaddr="' + MainForm.StartAddressEdit.Text + '"' +
          ' verify="' + BoolToStr(MainForm.MenuAutoCheck.Checked, '1', '0') + '"' +
          ' skipff="' + BoolToStr(MainForm.MenuSkipFF.Checked, '1', '0') + '"' +
          ' script="' + CurrentICParam.Script + '"/>' + LineEnding +
    '</asprogrammer_project>' + LineEnding;

  HeaderBytes := TEncoding.UTF8.GetBytes(Header);
  Len := Length(HeaderBytes);

  Buf := TMemoryStream.Create;
  try
    MainForm.MPHexEditorEx.SaveToStream(Buf);

    F := TFileStream.Create(FileName, fmCreate);
    try
      F.WriteBuffer(ProjectMagic[1], Length(ProjectMagic));
      F.WriteBuffer(Len, SizeOf(Len));
      if Len > 0 then F.WriteBuffer(HeaderBytes[0], Len);

      Buf.Position := 0;
      if Buf.Size > 0 then F.CopyFrom(Buf, Buf.Size);
    finally
      F.Free;
    end;

    Result := True;
  finally
    Buf.Free;
  end;
end;

//ดึงค่า attribute จากส่วนหัวโปรเจกต์ด้วยการค้นสตริงตรง ๆ
//ใช้ XML parser เต็มรูปแบบตรงนี้เกินความจำเป็น และเพิ่มการพึ่งพา DOM โดยไม่ต้อง
function ProjectAttr(const Header, Name: string): string;
var
  p, q: integer;
  Key: string;
begin
  Result := '';
  Key := ' ' + Name + '="';
  p := Pos(Key, Header);
  if p = 0 then Exit;

  Inc(p, Length(Key));
  q := p;
  while (q <= Length(Header)) and (Header[q] <> '"') do Inc(q);
  Result := Copy(Header, p, q - p);
end;

function LoadProjectFile(const FileName: string; out ErrMsg: string): boolean;
var
  F: TFileStream;
  Magic: string;
  Len: longword;
  HeaderBytes: TBytes;
  Header, s: string;
  Buf: TMemoryStream;
begin
  Result := False;
  ErrMsg := '';

  F := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
  try
    if F.Size < Length(ProjectMagic) + SizeOf(Len) then
    begin
      ErrMsg := 'Not an AsProgrammer project file';
      Exit;
    end;

    SetLength(Magic, Length(ProjectMagic));
    F.ReadBuffer(Magic[1], Length(ProjectMagic));
    if Magic <> ProjectMagic then
    begin
      ErrMsg := 'Not an AsProgrammer project file';
      Exit;
    end;

    F.ReadBuffer(Len, SizeOf(Len));
    if Len > cardinal(F.Size) then
    begin
      ErrMsg := 'Project header is corrupt';
      Exit;
    end;

    SetLength(HeaderBytes, Len);
    if Len > 0 then F.ReadBuffer(HeaderBytes[0], Len);
    Header := TEncoding.UTF8.GetString(HeaderBytes);

    Buf := TMemoryStream.Create;
    try
      if F.Size > F.Position then Buf.CopyFrom(F, F.Size - F.Position);

      //ต้องตั้งโปรโตคอลก่อนเป็นอันดับแรก เพราะการสลับ radio จะล้างค่าในช่องต่าง ๆ
      s := ProjectAttr(Header, 'protocol');
      if s = 'i2c' then MainForm.RadioI2C.Checked := True
      else if s = 'mw' then MainForm.RadioMw.Checked := True
      else MainForm.RadioSPI.Checked := True;

      s := ProjectAttr(Header, 'spicmd');
      if IsNumber(s) then MainForm.ComboSPICMD.ItemIndex := StrToInt(s);

      if MainForm.RadioSPI.Checked then MainForm.RadioSPIChange(MainForm);

      MainForm.ComboChipSize.Text := ProjectAttr(Header, 'size');
      MainForm.ComboPageSize.Text := ProjectAttr(Header, 'page');
      MainForm.ComboMWBitLen.Text := ProjectAttr(Header, 'mwbitlen');
      MainForm.StartAddressEdit.Text := ProjectAttr(Header, 'startaddr');

      s := ProjectAttr(Header, 'addrtype');
      if IsNumber(s) then MainForm.ComboAddrType.ItemIndex := StrToInt(s);

      CurrentICParam.Name := ProjectAttr(Header, 'name');
      CurrentICParam.ID := ProjectAttr(Header, 'id');
      CurrentICParam.Script := ProjectAttr(Header, 'script');
      MainForm.LabelChipName.Caption := CurrentICParam.Name;

      s := ProjectAttr(Header, 'sector');
      if IsNumber(s) then CurrentICParam.Sector := StrToInt(s);

      s := ProjectAttr(Header, 'sectorcmd');
      if IsNumber('$' + s) then CurrentICParam.SectorOpcode := StrToInt('$' + s);

      MainForm.MenuAutoCheck.Checked := ProjectAttr(Header, 'verify') = '1';
      MainForm.MenuSkipFF.Checked := ProjectAttr(Header, 'skipff') = '1';

      if Buf.Size > 0 then
      begin
        Buf.Position := 0;
        MainForm.MPHexEditorEx.LoadFromStream(Buf);
      end;

      Result := True;
    finally
      Buf.Free;
    end;
  finally
    F.Free;
  end;
end;

//opcode สำหรับลบตามขนาดเซกเตอร์: 20h(4K), 52h(32K), D8h(64K)
function SectorEraseOpcode(SectorSize: cardinal): byte;
begin
  case SectorSize of
    4096:  Result := $20;
    32768: Result := $52;
    65536: Result := $D8;
  else
    Result := $20;
  end;
end;

//ขนาดเซกเตอร์ของชิปปัจจุบัน มาจาก chiplist.xml (sector=) หรือ SFDP
//ถ้าไม่มีจะใช้ 4096 ซึ่งใช้ได้กับ SPI NOR สมัยใหม่แทบทุกตัว
function CurrentSectorSize: cardinal;
begin
  if CurrentICParam.Sector > 0 then
    Result := CurrentICParam.Sector
  else
    Result := 4096;
end;

//opcode สำหรับลบเซกเตอร์ของชิปปัจจุบัน
function CurrentSectorOpcode: byte;
begin
  if (CurrentICParam.Sector > 0) and (CurrentICParam.SectorOpcode <> 0) then
    Result := CurrentICParam.SectorOpcode
  else
    Result := SectorEraseOpcode(CurrentSectorSize);
end;

//สรุปข้อมูลชิปที่เลือกไว้ ลงในช่องว่างของแผงด้านซ้าย
//เป็นข้อมูลที่ต้องดูบ่อยที่สุดตอนทำงานจริง
procedure UpdateChipInfo;
var
  s, v: string;
begin
  s := '';

  if CurrentICParam.ID <> '' then
  begin
    s := 'ID      ' + CurrentICParam.ID;

    if (Length(CurrentICParam.ID) >= 2) and IsNumber('$' + Copy(CurrentICParam.ID, 1, 2)) then
    begin
      v := JedecVendor(StrToInt('$' + Copy(CurrentICParam.ID, 1, 2)));
      if v <> '' then s := s + LineEnding + v;
    end;
  end;

  if CurrentICParam.Size > 0 then
  begin
    if s <> '' then s := s + LineEnding;
    s := s + 'Size    ' + IntToStr(CurrentICParam.Size div 1024) + ' KB';
  end;

  if CurrentICParam.Size > 0 then
  begin
    s := s + LineEnding + 'Sector  ' + IntToStr(CurrentSectorSize div 1024) + ' KB (' +
         IntToHex(CurrentSectorOpcode, 2) + 'h)';
  end;

  if CurrentICParam.Note <> '' then
  begin
    if s <> '' then s := s + LineEnding;
    s := s + CurrentICParam.Note;
  end;

  if s = '' then s := STR_NO_CHIP_SELECTED;

  MainForm.LabelChipInfo.Caption := s;

  ChipDetected := CurrentICParam.Size > 0;
  MainForm.ChipView.Invalidate;
end;

//แผงด้านซ้ายในไฟล์ฟอร์มถูกวางไว้แบบพิกัดตายตัวและแคบเกินไป
//จัดตำแหน่งใหม่ตอนรัน ให้กว้างขึ้นและทุกอย่างอยู่กึ่งกลาง
procedure LayoutLeftPanel;
const
  PanelW = 200;
  ComboW = 116;
var
  cx: integer;
begin
  MainForm.GroupChipSettings.Width := PanelW;
  cx := (PanelW - ComboW) div 2;

  MainForm.LabelChipName.Left := 8;
  MainForm.LabelChipName.Width := PanelW - 16;

  MainForm.Label2.Left := cx;         MainForm.Label2.Width := ComboW;
  MainForm.ComboChipSize.Left := cx;  MainForm.ComboChipSize.Width := ComboW;

  MainForm.Label1.Left := cx;         MainForm.Label1.Width := ComboW;
  MainForm.ComboPageSize.Left := cx;  MainForm.ComboPageSize.Width := ComboW;

  MainForm.LabelSPICMD.Left := cx;    MainForm.LabelSPICMD.Width := ComboW;
  MainForm.ComboSPICMD.Left := cx;    MainForm.ComboSPICMD.Width := ComboW;

  MainForm.Label4.Left := cx;         MainForm.Label4.Width := ComboW;
  MainForm.ComboAddrType.Left := cx;  MainForm.ComboAddrType.Width := ComboW;

  MainForm.Label5.Left := cx;         MainForm.Label5.Width := ComboW;
  MainForm.ComboMWBitLen.Left := cx;  MainForm.ComboMWBitLen.Width := ComboW;

  MainForm.Panel_I2C_DevAddr.Left := (PanelW - MainForm.Panel_I2C_DevAddr.Width) div 2;

  //บล็อกข้อมูลชิปกินความกว้างเต็มแผง ข้อความจะได้ไม่ห่อบรรทัดถี่เกินไป
  MainForm.LabelChipInfo.Left := 12;
  MainForm.LabelChipInfo.Width := PanelW - 24;

  MainForm.Label_chip_scripts.Left := cx;
  MainForm.ComboBox_chip_scriptrun.Left := cx;
  MainForm.ComboBox_chip_scriptrun.Width := ComboW - 28;
  MainForm.SpeedButton1.Left := cx + ComboW - 23;

  MainForm.Label_StartAddress.Left := cx;
  MainForm.Label6.Left := cx;
  MainForm.StartAddressEdit.Left := cx + 20;

  //ภาพชิปกินพื้นที่ที่เหลือทั้งหมดด้านล่าง และยืดตามความสูงหน้าต่าง
  MainForm.ChipView.Left := 6;
  MainForm.ChipView.Width := PanelW - 12;
  MainForm.ChipView.Top := 330;
  MainForm.ChipView.Anchors := [akLeft, akTop, akRight, akBottom];
  MainForm.ChipView.Height := MainForm.GroupChipSettings.ClientHeight - 336;
  if MainForm.ChipView.Height < 160 then MainForm.ChipView.Height := 160;
end;

//เวลารอสูงสุดของแต่ละคำสั่ง หน่วยเป็นมิลลิวินาที
//ตัวเลขเผื่อไว้มากกว่าที่ดาต้าชีตระบุหลายเท่า ถ้าเกินนี้แปลว่าชิปมีปัญหาจริง
const
  BUSY_TIMEOUT_PAGE    = 5000;      //เขียนหนึ่งเพจ
  BUSY_TIMEOUT_SECTOR  = 30000;     //ลบหนึ่งเซกเตอร์หรือบล็อก
  BUSY_TIMEOUT_CHIP    = 600000;    //ลบทั้งชิป ชิปใหญ่ ๆ ใช้เวลาหลายนาที

  //จำนวนครั้งที่ยอมเขียนเพจเดิมซ้ำเมื่อตรวจแล้วไม่ตรง
  MaxPageRetry = 3;

//รอจนแฟล็ก Busy ดับ
//คืน false เมื่อผู้ใช้ยกเลิก หรือเมื่อรอเกินเวลาที่กำหนด
//เดิมไม่มีเวลาหมดอายุเลย ชิปที่ไม่ตอบสนองจะทำให้โปรแกรมวนรอไม่รู้จบ
function WaitNotBusy25(TimeoutMs: integer): boolean;
var
  Started: TDateTime;
begin
  Result := True;
  Started := Now;

  while UsbAsp25_Busy() do
  begin
    OpProcessMessages;
    if UserCancel then Exit(False);

    if MilliSecondsBetween(Now, Started) > TimeoutMs then
    begin
      LogPrint(Format(STR_BUSY_TIMEOUT, [TimeoutMs div 1000]));
      Exit(False);
    end;
  end;
end;

//ลบเฉพาะเซกเตอร์ที่อยู่ในช่วง StartAddress ถึง StartAddress+RangeLen-1
//ขอบถูกปัดให้ตรงเซกเตอร์ เพราะลบครึ่งเซกเตอร์ไม่ได้
function EraseRange25(StartAddress, RangeLen, SectorSize: cardinal; Opcode: byte): boolean;
const
  FLASH_SIZE_128MBIT = 16777216;
var
  ChipSize, Addr, EndAddr, Total, Idx: cardinal;
  Use4B: boolean;
  OK: boolean;

  //ตัวงานจริง จะรันบน thread เบื้องหลังถ้าเปิดโหมดนั้นไว้
  procedure DoWork;
  begin
  OK := False;

  if (SectorSize = 0) or (RangeLen = 0) then
  begin
    LogPrint(STR_CHECK_SETTINGS);
    Exit;
  end;

  ChipSize := OpUI.ChipSize;

  if (ChipSize = 0) or (StartAddress >= ChipSize) then
  begin
    LogPrint(STR_CHECK_SETTINGS);
    Exit;
  end;

  //ปัดจุดเริ่มลง ปัดจุดจบขึ้น ให้ตรงขอบเซกเตอร์
  Addr := (StartAddress div SectorSize) * SectorSize;
  EndAddr := StartAddress + RangeLen;
  if EndAddr > ChipSize then EndAddr := ChipSize;
  EndAddr := ((EndAddr + SectorSize - 1) div SectorSize) * SectorSize;
  if EndAddr > ChipSize then EndAddr := ChipSize;

  Total := (EndAddr - Addr + SectorSize - 1) div SectorSize;
  if Total = 0 then
  begin
    LogPrint(STR_CHECK_SETTINGS);
    Exit;
  end;

  LogPrint(STR_ERASING_RANGE + '0x' + IntToHex(Addr, 8) + ' - 0x' + IntToHex(EndAddr - 1, 8) +
           ' (' + IntToStr(Total) + ' x ' + IntToStr(SectorSize) + ' bytes, opcode 0x' +
           IntToHex(Opcode, 2) + ')');

  Use4B := ChipSize > FLASH_SIZE_128MBIT;
  if Use4B then UsbAsp25_EN4B();

  SetProgressPos(0);
  SetProgressMax(Integer(Total));
  Idx := 0;

  try
    while Addr < EndAddr do
    begin
      UsbAsp25_WREN();
      UsbAsp25_EraseSector(Opcode, Addr, Use4B);

      if not WaitNotBusy25(BUSY_TIMEOUT_SECTOR) then Exit;

      Inc(Addr, SectorSize);
      Inc(Idx);
      SetProgressPos(Integer(Idx));
      OpProcessMessages;

      if UserCancel then Exit;
    end;

    OK := True;
  finally
    if Use4B then UsbAsp25_EX4B();
    UsbAsp25_Wrdi();
    SetProgressPos(0);
  end;
  end;

begin
  OK := False;
  RunOperation(@DoWork);
  Result := OK;
end;

//ลบทั้งชิปตระกูล 25 พร้อมรอจนพร้อมใช้งาน
procedure ChipErase25;

  //ตัวงานจริง จะรันบน thread เบื้องหลังถ้าเปิดโหมดนั้นไว้
  procedure DoWork;
  var
    Started: TDateTime;
  begin
    UsbAsp25_WREN();
    UsbAsp25_ChipErase();

    LogPrint(STR_ERASE_NOTICE);
    Started := Now;

    if not WaitNotBusy25(BUSY_TIMEOUT_CHIP) then Exit;

    //การลบทั้งชิปเป็นไปไม่ได้ที่จะเสร็จในเสี้ยววินาที เกือบทุกครั้ง
    //แปลว่าชิปปฏิเสธคำสั่งเพราะยังถูกป้องกันการเขียนอยู่
    if MilliSecondsBetween(Now, Started) < 1000 then
      LogPrint(STR_ERASE_TOO_FAST);
  end;

begin
  RunOperation(@DoWork);
end;

//ตัวจริงอยู่ถัดลงไปในไฟล์ ประกาศไว้ก่อนเพราะการสำรองข้อมูลอัตโนมัติต้องใช้
procedure ReadFlash25(var RomStream: TMemoryStream; StartAddress, ChipSize: cardinal); forward;

//ตัวช่วยของงานเทียบข้อมูล ตัวจริงอยู่ท้ายไฟล์ แต่มีผู้เรียกอยู่ก่อนหน้านั้น
function ReportDiff(const A, B: array of byte; Size: integer): integer; forward;
function UIChipSize: cardinal; forward;
procedure ShowDiffInEditor(const A, B: array of byte; Size: integer); forward;
function ReadCurrentChip(Stream: TMemoryStream; Size: cardinal): boolean; forward;

//ตรวจว่าชิปที่เสียบอยู่ตรงกับที่เลือกไว้จริงหรือไม่
//ต้องเรียกตอนอยู่ในโหมดโปรแกรม คืน False เมื่อผู้ใช้เลือกไม่ทำต่อ
function VerifyChipID: boolean;
var
  ID: MEMORY_ID;
  Expected, s9F, s90, sAB, s15: string;
begin
  Result := True;

  if not MainForm.MenuCheckIDBefore.Checked then Exit;
  if not MainForm.RadioSPI.Checked then Exit;
  if MainForm.ComboSPICMD.ItemIndex <> SPI_CMD_25 then Exit;

  Expected := UpperCase(Trim(CurrentICParam.ID));
  //ชิปบางตัวไม่มี id จึงไม่มีอะไรให้ตรวจ
  if (Expected = '') or (Expected = '0') then Exit;

  FillByte(ID.ID9FH, 3, $FF);
  FillByte(ID.ID90H, 2, $FF);
  FillByte(ID.IDABH, 1, $FF);
  FillByte(ID.ID15H, 2, $FF);

  UsbAsp25_ReadID(ID);

  s9F := UpperCase(IntToHex(ID.ID9FH[0], 2) + IntToHex(ID.ID9FH[1], 2) + IntToHex(ID.ID9FH[2], 2));
  s90 := UpperCase(IntToHex(ID.ID90H[0], 2) + IntToHex(ID.ID90H[1], 2));
  sAB := UpperCase(IntToHex(ID.IDABH, 2));
  s15 := UpperCase(IntToHex(ID.ID15H[0], 2) + IntToHex(ID.ID15H[1], 2));

  if (Expected = s9F) or (Expected = s90) or (Expected = sAB) or (Expected = s15) then
  begin
    LogPrint(STR_ID_OK + Expected);
    Exit;
  end;

  LogPrint(STR_ID_MISMATCH + Expected + ', read 9Fh=' + s9F + ' 90h=' + s90 +
           ' ABh=' + sAB + ' 15h=' + s15);

  Result := MessageDlg('AsProgrammer', STR_ID_MISMATCH_Q, mtWarning, [mbYes, mbNo], 0) = mrYes;
end;

//เตือนก่อนแตะชิป 1.8 โวลต์ ถ้าเครื่องโปรแกรมจ่ายไฟให้ไม่ได้
//CH341A จ่าย 3.3-5V, CH347 กับ FT232H จ่าย 3.3V ทั้งหมดสูงเกินไปสำหรับชิป 1.8V
//ต่อผิดครั้งเดียวชิปพังถาวร จึงต้องถามก่อนทุกครั้ง
function VoltageWarningOK: boolean;
begin
  Result := True;

  //ธรรมเนียมของ chiplist คือใส่ _1.8V ต่อท้ายชื่อรุ่น
  if Pos('1.8V', UpperCase(CurrentICParam.Name)) = 0 then Exit;

  //Bus Pirate ตั้งขาเป็น open-drain แล้วจ่ายไฟจากภายนอกได้ จึงไม่เตือน
  if AsProgrammer.Current_HW in [CHW_BUZZPIRAT, CHW_ARDUINO] then Exit;

  Result := MessageDlg('AsProgrammer', STR_VOLT_WARN, mtWarning, [mbYes, mbNo], 0) = mrYes;
  if not Result then LogPrint(STR_VOLT_ABORTED);
end;

//ตรวจว่าพื้นที่ที่จะเขียนถูกลบแล้วจริง
//การเขียนทับข้อมูลเดิมที่ยังไม่ได้ลบ แฟลชจะทำได้แค่เปลี่ยนบิต 1 เป็น 0
//ผลคือข้อมูลเพี้ยนโดยไม่มีใครแจ้ง จนกว่าจะไปเจอตอน verify
function BlankCheckBeforeWrite(StartAddress, Len: cardinal): boolean;
var
  Chunk: array[0..2047] of byte;
  Addr, Remain: cardinal;
  n, i: integer;
  BlankByte: byte;
begin
  Result := True;

  if not MainForm.MenuBlankBeforeWrite.Checked then Exit;
  if not MainForm.RadioSPI.Checked then Exit;
  if MainForm.ComboSPICMD.ItemIndex <> SPI_CMD_25 then Exit;
  if Len = 0 then Exit;

  LogPrint(STR_BLANK_CHECKING);
  BlankByte := $FF;
  Addr := StartAddress;
  Remain := Len;

  while Remain > 0 do
  begin
    n := SizeOf(Chunk);
    if cardinal(n) > Remain then n := Remain;

    FillByte(Chunk, SizeOf(Chunk), 0);
    UsbAsp25_Read($03, Addr, Chunk, n);

    for i := 0 to n - 1 do
      if Chunk[i] <> BlankByte then
      begin
        LogPrint(STR_NOT_BLANK + IntToHex(Addr + cardinal(i), 8));
        Result := MessageDlg('AsProgrammer', STR_NOT_BLANK_Q,
                             mtWarning, [mbYes, mbNo], 0) = mrYes;
        Exit;
      end;

    Inc(Addr, cardinal(n));
    Dec(Remain, cardinal(n));

    OpProcessMessages;
    if UserCancel then Exit(False);
  end;
end;

//สำรองเนื้อหาชิปก่อนเขียนหรือลบ
//คืน False เมื่อสำรองไม่สำเร็จ ซึ่งแปลว่าห้ามทำต่อ
function AutoBackupChip: boolean;
var
  Backup: TMemoryStream;
  Dir, FileName, ChipName: string;
  i: integer;
begin
  Result := True;

  if not MainForm.MenuAutoBackup.Checked then Exit;
  if not MainForm.RadioSPI.Checked then Exit;
  if MainForm.ComboSPICMD.ItemIndex <> SPI_CMD_25 then Exit;
  if OpUI.ChipSize = 0 then Exit;

  Dir := 'backup' + DirectorySeparator;
  if not DirectoryExists(Dir) then
    if not CreateDir(Dir) then
    begin
      LogPrint(STR_BACKUP_FAILED);
      Exit(False);
    end;

  //ชื่อชิปจะไปอยู่ในชื่อไฟล์ ต้องล้างอักขระที่ใช้ไม่ได้ออกก่อน
  ChipName := CurrentICParam.Name;
  if ChipName = '' then ChipName := 'chip';
  for i := 1 to Length(ChipName) do
    if not (ChipName[i] in ['0'..'9', 'A'..'Z', 'a'..'z', '_', '-', '.']) then
      ChipName[i] := '_';

  FileName := Dir + ChipName + '_' + FormatDateTime('yyyymmdd-hhnnss', Now) + '.bin';

  LogPrint(STR_BACKUP_MAKING);

  Backup := TMemoryStream.Create;
  try
    ReadFlash25(Backup, 0, OpUI.ChipSize);

    if Backup.Size < OpUI.ChipSize then
    begin
      LogPrint(STR_BACKUP_FAILED);
      Exit(False);
    end;

    Backup.SaveToFile(FileName);
    LogPrint(STR_BACKUP_DONE + FileName);
  finally
    Backup.Free;
  end;
end;

//ใส่เลขรันนิ่งตัวถัดไปลงในสตรีมก่อนเขียน และถ้ากำหนดไฟล์บันทึกไว้
//ก็เขียนเลขที่จ่ายไปต่อท้ายไฟล์นั้นด้วย
procedure ApplySerialToStream(Stream: TMemoryStream);
var
  Data: array of byte;
  Size: integer;
  LogF: TextFile;
begin
  if not ProdSettings.SNEnabled then Exit;

  Size := Stream.Size;
  if Size = 0 then Exit;

  if ProdSettings.SNAddress + ProdSettings.SNLength > cardinal(Size) then
  begin
    LogPrint(STR_SERIAL_NOFIT);
    Exit;
  end;

  SetLength(Data, Size);
  Stream.Position := 0;
  Stream.ReadBuffer(Data[0], Size);

  if ApplySerial(ProdSettings, Data, cardinal(Size)) then
  begin
    LogPrint(STR_SERIAL_WRITTEN + SerialToStr(ProdSettings) +
             ' @ 0x' + IntToHex(ProdSettings.SNAddress, 6));

    if ProdSettings.SNLogFile <> '' then
      try
        AssignFile(LogF, ProdSettings.SNLogFile);
        if FileExists(ProdSettings.SNLogFile) then Append(LogF) else Rewrite(LogF);
        WriteLn(LogF, FormatDateTime('yyyy-mm-dd hh:nn:ss', Now) + #9 +
                      CurrentICParam.Name + #9 + SerialToStr(ProdSettings));
        CloseFile(LogF);
      except
        LogPrint('Cannot write the serial number log file');
      end;

    Stream.Position := 0;
    Stream.WriteBuffer(Data[0], Size);
  end;

  Stream.Position := 0;
end;

//เติมค่าที่อ่านได้จาก SFDP ลงในหน้าจอและใน CurrentICParam
//ลำดับสำคัญ เพราะ RadioSPIChange จะล้างค่าในช่องต่าง ๆ ทิ้ง
procedure ApplySFDPInfo(const Info: TSFDPInfo);
var
  i: integer;
  ESize: cardinal;
  EOpcode: byte;
begin
  LogPrint(STR_SFDP_FOUND + ' (JESD216 rev ' + IntToStr(Info.MajorRev) + '.' +
           IntToStr(Info.MinorRev) + ')');
  LogPrint('  Size: ' + IntToStr(Info.Density) + ' bytes');
  LogPrint('  Page: ' + IntToStr(Info.PageSize) + ' bytes');
  LogPrint('  Address bytes: ' + SFDPAddrBytesStr(Info));

  for i := 1 to 4 do
    if Info.EraseTypes[i].Size > 0 then
      LogPrint('  Erase type ' + IntToStr(i) + ': ' + IntToStr(Info.EraseTypes[i].Size) +
               ' bytes, opcode 0x' + IntToHex(Info.EraseTypes[i].Opcode, 2));

  MainForm.ComboSPICMD.ItemIndex := SPI_CMD_25;
  MainForm.RadioSPI.Checked := True;
  MainForm.RadioSPIChange(MainForm);

  MainForm.ComboChipSize.Text := IntToStr(Info.Density);
  MainForm.ComboPageSize.Text := IntToStr(Info.PageSize);
  MainForm.LabelChipName.Caption := 'SFDP ' + IntToStr(Info.Density div 1024) + 'K';

  CurrentICParam.Name := MainForm.LabelChipName.Caption;
  CurrentICParam.Size := Info.Density;
  CurrentICParam.Page := Info.PageSize;
  CurrentICParam.SpiCmd := SPI_CMD_25;
  CurrentICParam.Script := '';
  CurrentICParam.ID := '';
  MainForm.ComboBox_chip_scriptrun.Items.Clear;

  if SFDPSmallestErase(Info, ESize, EOpcode) then
  begin
    CurrentICParam.Sector := ESize;
    CurrentICParam.SectorOpcode := EOpcode;
  end
  else
  begin
    CurrentICParam.Sector := 0;
    CurrentICParam.SectorOpcode := 0;
  end;

  UpdateChipInfo;
  LogPrint(STR_SFDP_APPLIED);
end;

//ตั้งความเร็วของ spi และ Microwire
function SetSPISpeed(OverrideSpeed: byte): integer;
var
  Speed: byte;
begin
  if AsProgrammer.Current_HW = CHW_ARDUINO then
  begin
    if MainForm.MenuArduinoISP8Mhz.Checked then Speed := MainForm.MenuArduinoISP8Mhz.Tag;
    if MainForm.MenuArduinoISP4Mhz.Checked then Speed := MainForm.MenuArduinoISP4Mhz.Tag;
    if MainForm.MenuArduinoISP2Mhz.Checked then Speed := MainForm.MenuArduinoISP2Mhz.Tag;
    if MainForm.MenuArduinoISP1Mhz.Checked then Speed := MainForm.MenuArduinoISP1Mhz.Tag;
  end;

  if AsProgrammer.Current_HW = CHW_BUZZPIRAT then
  begin
    if MainForm.MenuArduinoISP8Mhz.Checked then Speed := MainForm.MenuArduinoISP8Mhz.Tag;
    if MainForm.MenuArduinoISP4Mhz.Checked then Speed := MainForm.MenuArduinoISP4Mhz.Tag;
    if MainForm.MenuArduinoISP2Mhz.Checked then Speed := MainForm.MenuArduinoISP2Mhz.Tag;
    if MainForm.MenuArduinoISP1Mhz.Checked then Speed := MainForm.MenuArduinoISP1Mhz.Tag;
  end;

  if AsProgrammer.Current_HW = CHW_AVRISP then
  begin
    if MainForm.MenuAVRISP8Mhz.Checked then Speed := MainForm.MenuAVRISP8Mhz.Tag;
    if MainForm.MenuAVRISP4Mhz.Checked then Speed := MainForm.MenuAVRISP4Mhz.Tag;
    if MainForm.MenuAVRISP2Mhz.Checked then Speed := MainForm.MenuAVRISP2Mhz.Tag;
    if MainForm.MenuAVRISP1Mhz.Checked then Speed := MainForm.MenuAVRISP1Mhz.Tag;
    if MainForm.MenuAVRISP500Khz.Checked then Speed := MainForm.MenuAVRISP500Khz.Tag;
    if MainForm.MenuAVRISP250Khz.Checked then Speed := MainForm.MenuAVRISP250Khz.Tag;
    if MainForm.MenuAVRISP125Khz.Checked then Speed := MainForm.MenuAVRISP125Khz.Tag;
  end;

  if (MainForm.RadioSPI.Checked) and (AsProgrammer.Current_HW = CHW_USBASP) then
  begin
    if MainForm.Menu3Mhz.Checked then Speed := MainForm.Menu3Mhz.Tag;
    if MainForm.Menu1_5Mhz.Checked then Speed := MainForm.Menu1_5Mhz.Tag;
    if MainForm.Menu750Khz.Checked then Speed := MainForm.Menu750Khz.Tag;
    if MainForm.Menu375Khz.Checked then Speed := MainForm.Menu375Khz.Tag;
    if MainForm.Menu187_5Khz.Checked then Speed := MainForm.Menu187_5Khz.Tag;
    if MainForm.Menu93_75Khz.Checked then Speed := MainForm.Menu93_75Khz.Tag;
    if MainForm.Menu32Khz.Checked then Speed := MainForm.Menu32Khz.Tag;
  end;

  if (MainForm.RadioMw.Checked) and (AsProgrammer.Current_HW = CHW_USBASP) then
  begin
    if MainForm.MenuMW32Khz.Checked then Speed := MainForm.MenuMW32Khz.Tag;
    if MainForm.MenuMW16Khz.Checked then Speed := MainForm.MenuMW16Khz.Tag;
    if MainForm.MenuMW8Khz.Checked then Speed := MainForm.MenuMW8Khz.Tag;
  end;

  if (MainForm.RadioSPI.Checked) and (AsProgrammer.Current_HW = CHW_FT232H) then
  begin
    if MainForm.MenuFT232SPI30Mhz.Checked then Speed := MainForm.MenuFT232SPI30Mhz.Tag;
    if MainForm.MenuFT232SPI6Mhz.Checked then Speed := MainForm.MenuFT232SPI6Mhz.Tag;
  end;

  if (MainForm.RadioSPI.Checked) and (AsProgrammer.Current_HW = CHW_CH347) then
  begin
    if MainForm.MenuCH347SPIClock60MHz.Checked then Speed := MainForm.MenuCH347SPIClock60MHz.Tag;
    if MainForm.MenuCH347SPIClock30MHz.Checked then Speed := MainForm.MenuCH347SPIClock30MHz.Tag;
    if MainForm.MenuCH347SPIClock15MHz.Checked then Speed := MainForm.MenuCH347SPIClock15MHz.Tag;
    if MainForm.MenuCH347SPIClock7_5MHz.Checked then Speed := MainForm.MenuCH347SPIClock7_5MHz.Tag;
    if MainForm.MenuCH347SPIClock3_75MHz.Checked then Speed := MainForm.MenuCH347SPIClock3_75MHz.Tag;
    if MainForm.MenuCH347SPIClock1_875MHz.Checked then Speed := MainForm.MenuCH347SPIClock1_875MHz.Tag;
    if MainForm.MenuCH347SPIClock937_5KHz.Checked then Speed := MainForm.MenuCH347SPIClock937_5KHz.Tag;
    if MainForm.MenuCH347SPIClock468_75KHz.Checked then Speed := MainForm.MenuCH347SPIClock468_75KHz.Tag;
  end;

  if OverrideSpeed <> 0 then Speed := OverrideSpeed;

  result := speed;
end;


function SetI2CDevAddr(): byte;
begin
    result := 0;
    With MainForm do
    begin
      if (CheckBox_I2C_A0.Checked) then result := SetBit(result, 1);
      if (CheckBox_I2C_A1.Checked) then result := SetBit(result, 2);
      if (CheckBox_I2C_A2.Checked) then result := SetBit(result, 3);

      if (CheckBox_I2C_DevA4.Checked) then result := SetBit(result, 4);
      if (CheckBox_I2C_DevA5.Checked) then result := SetBit(result, 5);
      if (CheckBox_I2C_DevA6.Checked) then result := SetBit(result, 6);
      if (CheckBox_I2C_DevA7.Checked) then result := SetBit(result, 7);
    end;
end;

procedure ReadFlashMW(var RomStream: TMemoryStream; AddrBitLen: byte; StartAddress, ChipSize: cardinal);
var
  ChunkSize: Word;
  BytesRead: integer;
  DataChunk: array[0..2047] of byte;
  Address: cardinal;
begin
  if (StartAddress >= ChipSize) or (ChipSize = 0) then
  begin
    LogPrint(STR_CHECK_SETTINGS);
    exit;
  end;

  ChunkSize := 2;
  if ChunkSize > ChipSize then ChunkSize := ChipSize;

  LogPrint(STR_READING_FLASH);
  BytesRead := 0;
  Address := StartAddress;
  MainForm.ProgressBar.Max := ChipSize div ChunkSize;

  RomStream.Clear;

  while Address < ChipSize div 2 do
  begin
    //if ChunkSize > ((ChipSize div 2) - Address) then ChunkSize := (ChipSize div 2) - Address;

    BytesRead := BytesRead + UsbAspMW_Read(AddrBitLen, Address, datachunk, ChunkSize);
    RomStream.WriteBuffer(datachunk, ChunkSize);
    Inc(Address, ChunkSize div 2);

    MainForm.ProgressBar.Position := MainForm.ProgressBar.Position + 2;
    Application.ProcessMessages;

    if UserCancel then Break;
  end;

  if BytesRead <> ChipSize then
    LogPrint(STR_WRONG_BYTES_READ)
  else
    LogPrint(STR_DONE);

  MainForm.ProgressBar.Position := 0;
end;

procedure WriteFlashMW(var RomStream: TMemoryStream; AddrBitLen: byte; StartAddress, ChipSize: cardinal);
var
  DataChunk: array[0..2047] of byte;
  Address, BytesWrite: cardinal;
  ChunkSize: Word;
begin
  if (StartAddress >= ChipSize) or (ChipSize = 0) then
  begin
    LogPrint(STR_CHECK_SETTINGS);
    exit;
  end;

  LogPrint(STR_WRITING_FLASH);
  BytesWrite := 0;
  Address := StartAddress;
  MainForm.ProgressBar.Max := ChipSize;

  ChunkSize := 2;

  if ChunkSize > ChipSize then ChunkSize := ChipSize;

  UsbAspMW_EWEN(AddrBitLen);

  while Address < ChipSize div 2 do
  begin
    RomStream.ReadBuffer(DataChunk, ChunkSize);

    BytesWrite := BytesWrite + UsbAspMW_Write(AddrBitLen, Address, datachunk, ChunkSize);
    Inc(Address, ChunkSize div 2);

    while UsbAspMW_Busy do
    begin
       Application.ProcessMessages;
       if UserCancel then Exit;
    end; 

    MainForm.ProgressBar.Position := MainForm.ProgressBar.Position + ChunkSize;
    Application.ProcessMessages;

    if UserCancel then Break;
  end;

  if BytesWrite <> ChipSize then
    LogPrint(STR_WRONG_BYTES_WRITE)
  else
    LogPrint(STR_DONE);

  MainForm.ProgressBar.Position := 0;
end;

procedure WriteFlash25(var RomStream: TMemoryStream; StartAddress, WriteSize: cardinal; PageSize: word; WriteType: integer);
const
  FLASH_SIZE_128MBIT = 16777216;
var
  DataChunk: array[0..2047] of byte;
  DataChunk2: array[0..2047] of byte;
  Address, BytesWrite: cardinal;
  PageSizeTemp: word;
  ProgressPos: integer;
  SkipPage: boolean;
  Retry, BadOffset: integer;
  OpStarted: TDateTime;

  //ตัวงานจริง จะรันบน thread เบื้องหลังถ้าเปิดโหมดนั้นไว้
  //ตัวนับลูปต้องเป็นตัวแปรในตัวเอง เพราะ FPC ไม่ยอมให้ใช้ตัวแปร
  //ของโพรซีเยอร์ชั้นนอกมาเป็นตัวนับ for
  procedure DoWork;
  var
    i: integer;
  begin
  if (WriteSize = 0) then
  begin
    LogPrint(STR_CHECK_SETTINGS);
    exit;
  end;

  if OpUI.AutoCheck then
    LogPrint(STR_WRITING_FLASH_WCHK) else
      LogPrint(STR_WRITING_FLASH);

  PageSizeTemp := PageSize;
  BytesWrite := 0;
  Address := StartAddress;
  SetProgressMax(WriteSize div PageSize);
  SetProgressPos(0);
  ProgressPos := 0;
  Retry := 0;
  OpStarted := Now;

  if WriteSize > FLASH_SIZE_128MBIT then UsbAsp25_EN4B();

  while (Address-StartAddress) < WriteSize do
  begin
    //ต้องรีเซ็ตทุกเพจ เพราะตัวแปร local ที่มีค่าเริ่มต้นใน FPC เป็นแบบ static
    //ค่าจึงค้างข้ามมาจากการเขียนรอบก่อน
    SkipPage := False;

    //เฉพาะตอนเริ่มของ aai
    if (((WriteType = WT_SSTB) or (WriteType = WT_SSTW)) and (Address = StartAddress)) or
    //ตอนเริ่มเพจ
    (WriteType = WT_PAGE) then UsbAsp25_WREN();

    //คำนวณขนาดบัฟเฟอร์เพจแรก กันไม่ให้บัฟเฟอร์วนกลับเมื่อชนขอบแอดเดรส
        if (StartAddress > 0) and (Address = StartAddress) and (PageSize > 2) then
           PageSize := (OpUI.ChipSize - StartAddress) mod PageSize else
              PageSize := PageSizeTemp;

    if (WriteSize - (Address-StartAddress)) < PageSize then PageSize := (WriteSize - (Address-StartAddress));
    RomStream.ReadBuffer(DataChunk, PageSize);

    if (WriteType = WT_SSTB) then
      if (Address = StartAddress) then //เขียนไบต์แรกพร้อมแอดเดรส
        BytesWrite := BytesWrite + UsbAsp25_Write($AF, Address, datachunk, PageSize)
        else
        //ไบต์ที่เหลือเขียนโดยไม่ต้องส่งแอดเดรส
        BytesWrite := BytesWrite + UsbAsp25_WriteSSTB($AF, datachunk[0]);

    if (WriteType = WT_SSTW) then
      if (Address = StartAddress) then //เขียนสองไบต์แรกพร้อมแอดเดรส
        BytesWrite := BytesWrite + UsbAsp25_Write($AD, Address, datachunk, PageSize)
        else
        //ไบต์ที่เหลือเขียนโดยไม่ต้องส่งแอดเดรส
        BytesWrite := BytesWrite + UsbAsp25_WriteSSTW($AD, datachunk[0], datachunk[1]);

    if WriteType = WT_PAGE then
    begin
      //ถ้าทั้งเพจเป็น FF ก็ไม่ต้องเขียน
      if OpUI.SkipFF then
      begin
        SkipPage := True;
        for i:=0 to PageSize-1 do
          if DataChunk[i] <> $FF then
          begin
            SkipPage := False;
            Break;
          end;
      end;

      if not SkipPage then
      begin
        if WriteSize > FLASH_SIZE_128MBIT then //หน่วยความจำใหญ่กว่า 128Mbit
        begin
          //ใช้แอดเดรส 4 ไบต์
          BytesWrite := BytesWrite + UsbAsp25_Write32bitAddr($02, Address, datachunk, PageSize)
        end
        else //หน่วยความจำไม่เกิน 128Mbit
          BytesWrite := BytesWrite + UsbAsp25_Write($02, Address, datachunk, PageSize);
      end else BytesWrite := BytesWrite + PageSize;
    end;

    if (not OpUI.IgnoreBusy) and (not SkipPage) then  //ข้ามการตรวจสถานะ
      if not WaitNotBusy25(BUSY_TIMEOUT_PAGE) then Exit;

    if (OpUI.AutoCheck) and (WriteType = WT_PAGE) then
    begin
	  
      if WriteSize > FLASH_SIZE_128MBIT then
        UsbAsp25_Read32bitAddr($03, Address, datachunk2, PageSize)
      else
        UsbAsp25_Read($03, Address, datachunk2, PageSize);

      BadOffset := -1;
      for i := 0 to PageSize - 1 do
        if DataChunk2[i] <> DataChunk[i] then
        begin
          BadOffset := i;
          Break;
        end;

      //เพจที่ตรวจไม่ผ่านให้ลองเขียนซ้ำก่อน ไม่ใช่ล้มทั้งงานทันที
      //ความผิดพลาดชั่วคราวบนสาย USB หรือสายที่ยาวเกินไปเกิดขึ้นได้เป็นปกติ
      if BadOffset >= 0 then
      begin
        if Retry < MaxPageRetry then
        begin
          Inc(Retry);
          LogPrint(STR_PAGE_RETRY + IntToStr(Retry) + ' @ 0x' + IntToHex(Address, 8));
          RomStream.Position := RomStream.Position - PageSize;
          Continue;
        end;

        LogPrint(STR_VERIFY_ERROR + IntToHex(Address + cardinal(BadOffset), 8));
        SetProgressPos(0);
        Exit;
      end;

      Retry := 0;
    end;

    Inc(Address, PageSize);
    Inc(ProgressPos);
    SetProgressPos(ProgressPos);
    ShowSpeed(Address - StartAddress, WriteSize, OpStarted);
    OpProcessMessages;

    if UserCancel then Break;
  end;

  if WriteSize > FLASH_SIZE_128MBIT then UsbAsp25_EX4B();
  UsbAsp25_Wrdi(); //สำหรับ sst

  if BytesWrite <> WriteSize then
    LogPrint(STR_WRONG_BYTES_WRITE)
  else
    LogPrint(STR_DONE);

  SetProgressPos(0);
  ClearSpeed;
  end;

begin
  RunOperation(@DoWork);
end;

procedure WriteFlash95(var RomStream: TMemoryStream; StartAddress, WriteSize: cardinal; PageSize: word; ChipSize: integer);
var
  DataChunk: array[0..2047] of byte;
  DataChunk2: array[0..2047] of byte;
  Address, BytesWrite: cardinal;
  PageSizeTemp: word;
  i: integer;
begin
  if (WriteSize = 0) then
  begin
    LogPrint(STR_CHECK_SETTINGS);
    exit;
  end;

  if MainForm.MenuAutoCheck.Checked then
    LogPrint(STR_WRITING_FLASH_WCHK) else
      LogPrint(STR_WRITING_FLASH);

  PageSizeTemp := PageSize;
  BytesWrite := 0;
  Address := StartAddress;
  MainForm.ProgressBar.Max := WriteSize div PageSize;

  while (Address-StartAddress) < WriteSize do
  begin
    UsbAsp95_WREN();

    //คำนวณขนาดบัฟเฟอร์เพจแรก กันไม่ให้บัฟเฟอร์วนกลับเมื่อชนขอบแอดเดรส
        if (StartAddress > 0) and (Address = StartAddress) and (PageSize > 1) then
           PageSize := (ChipSize - StartAddress) mod PageSize else
              PageSize := PageSizeTemp;

    if (WriteSize - (Address-StartAddress)) < PageSize then PageSize := (WriteSize - (Address-StartAddress));
    RomStream.ReadBuffer(DataChunk, PageSize);

    BytesWrite := BytesWrite + UsbAsp95_Write(ChipSize, Address, datachunk, PageSize);

    if not MainForm.MenuIgnoreBusyBit.Checked then  //ข้ามการตรวจสถานะ
      if not WaitNotBusy25(BUSY_TIMEOUT_SECTOR) then Exit;

    if MainForm.MenuAutoCheck.Checked then
    begin
      UsbAsp95_Read(ChipSize, Address, datachunk2, PageSize);
      for i:=0 to PageSize-1 do
        if DataChunk2[i] <> DataChunk[i] then
        begin
          LogPrint(STR_VERIFY_ERROR+IntToHex(Address+i, 8));
          MainForm.ProgressBar.Position := 0;
          Exit;
        end;
    end;

    Inc(Address, PageSize);
    MainForm.ProgressBar.Position := MainForm.ProgressBar.Position + 1;
    Application.ProcessMessages;
    if UserCancel then Break;
  end;

  if BytesWrite <> WriteSize then
    LogPrint(STR_WRONG_BYTES_WRITE)
  else
    LogPrint(STR_DONE);

  MainForm.ProgressBar.Position := 0;
end;

procedure EraseEEPROM25(StartAddress, WriteSize: cardinal; PageSize: word; ChipSize: integer);
var
  DataChunk: array[0..2047] of byte;
  DataChunk2: array[0..2047] of byte;
  Address, BytesWrite: cardinal;
  i: integer;
begin
  if (StartAddress >= WriteSize) or (WriteSize = 0) {or (PageSize > WriteSize)} then
  begin
    LogPrint(STR_CHECK_SETTINGS);
    exit;
  end;

  BytesWrite := 0;
  Address := StartAddress;
  MainForm.ProgressBar.Max := WriteSize div PageSize;

  while Address < WriteSize do
  begin
    UsbAsp95_WREN();

    if (WriteSize - Address) < PageSize then PageSize := (WriteSize - Address);

    FillByte(DataChunk, PageSize, $FF);

    BytesWrite := BytesWrite + UsbAsp95_Write(ChipSize, Address, datachunk, PageSize);

    if not MainForm.MenuIgnoreBusyBit.Checked then  //ข้ามการตรวจสถานะ
      if not WaitNotBusy25(BUSY_TIMEOUT_SECTOR) then Exit;

    if MainForm.MenuAutoCheck.Checked then
    begin
      UsbAsp95_Read(ChipSize, Address, datachunk2, PageSize);
      for i:=0 to PageSize-1 do
        if DataChunk2[i] <> DataChunk[i] then
        begin
          LogPrint(STR_VERIFY_ERROR+IntToHex(Address+i, 8));
          MainForm.ProgressBar.Position := 0;
          Exit;
        end;
    end;

    Inc(Address, PageSize);
    MainForm.ProgressBar.Position := MainForm.ProgressBar.Position + 1;
    Application.ProcessMessages;

    if UserCancel then Break;
  end;

  if BytesWrite <> WriteSize then
    LogPrint(STR_WRONG_BYTES_WRITE)
  else
    LogPrint(STR_DONE);

  MainForm.ProgressBar.Position := 0;
end;

function EraseFlashKB(chipsize: longword; pagesize: word): integer;
var
  i: integer;
  busy: boolean;
begin
  MainForm.ProgressBar.Max := chipsize div pagesize;

  UsbAspMulti_EnableEDI();
  UsbAspMulti_WriteReg($FEA7, $A4); //เปิดสิทธิ์เขียน

  for i:= 0 to (chipsize div pagesize)-1 do
  begin
    UsbAspMulti_ErasePage(i * pagesize);
    //busy
    repeat
      if UserCancel then Exit;
      busy := UsbAspMulti_Busy();
    until busy = false;

    MainForm.ProgressBar.Position := MainForm.ProgressBar.Position + 1;
  end;

  MainForm.ProgressBar.Position := 0;
end;

procedure WriteFlashKB(var RomStream: TMemoryStream; StartAddress, WriteSize: cardinal; PageSize: word);
var
  DataChunk: array[0..2047] of byte;
  DataChunk2: array[0..2047] of byte;
  Address, BytesWrite: cardinal;
  i: integer;
  busy: boolean;
  SkipPage: boolean;
begin
  if (StartAddress >= WriteSize) or (WriteSize = 0) {or (PageSize > WriteSize)} then
  begin
    LogPrint(STR_CHECK_SETTINGS);
    exit;
  end;

  if MainForm.MenuAutoCheck.Checked then
    LogPrint(STR_WRITING_FLASH_WCHK) else
      LogPrint(STR_WRITING_FLASH);

  BytesWrite := 0;
  Address := StartAddress;
  MainForm.ProgressBar.Max := WriteSize div PageSize;

  UsbAspMulti_EnableEDI();
  UsbAspMulti_WriteReg($FEA7, $A4); //เปิดสิทธิ์เขียน

  while Address < WriteSize do
  begin

    //ต้องรีเซ็ตทุกเพจ ตัวแปรมีค่าค้างจากรอบก่อนได้
    SkipPage := False;

    RomStream.ReadBuffer(DataChunk, PageSize);


    //ถ้าทั้งเพจเป็น 00 ก็ไม่ต้องเขียน
    if MainForm.MenuSkipFF.Checked then
    begin
      SkipPage := True;
      for i:=0 to PageSize-1 do
        if DataChunk[i] <> $00 then
        begin
          SkipPage := False;
          Break;
        end;
    end;

    if not SkipPage then
      UsbAspMulti_WritePage(Address, datachunk);

    //busy
    repeat
      if UserCancel then Exit;
      busy := UsbAspMulti_Busy();
    until busy = false;

    BytesWrite := BytesWrite + PageSize;

     if (MainForm.MenuAutoCheck.Checked) then
      begin
        for i:=0 to PageSize-1 do
        begin
          UsbAspMulti_Read(Address+i, DataChunk2[0]);
          if DataChunk2[0] <> DataChunk[i] then
          begin
            LogPrint(STR_VERIFY_ERROR+IntToHex(Address+i, 8));
            MainForm.ProgressBar.Position := 0;
            Exit;
          end;
        end;
      end;

    Inc(Address, PageSize);
    MainForm.ProgressBar.Position := MainForm.ProgressBar.Position + 1;
    Application.ProcessMessages;
    if UserCancel then Exit;
  end;

  if BytesWrite <> WriteSize then
    LogPrint(STR_WRONG_BYTES_WRITE)
  else
    LogPrint(STR_DONE);

  MainForm.ProgressBar.Position := 0;
end;

procedure WriteFlash45(var RomStream: TMemoryStream; StartAddress, ChipSize: cardinal; PageSize: word; WriteType: integer);
var
  DataChunk: array[0..2047] of byte;
  DataChunk2: array[0..2047] of byte;
  PageAddress, BytesWrite: cardinal;
  i: integer;
begin
  if (StartAddress >= ChipSize) or (ChipSize = 0) or (PageSize > ChipSize) then
  begin
    LogPrint(STR_CHECK_SETTINGS);
    exit;
  end;

  if MainForm.MenuAutoCheck.Checked then
    LogPrint(STR_WRITING_FLASH_WCHK) else
      LogPrint(STR_WRITING_FLASH);

  BytesWrite := 0;
  PageAddress := StartAddress;
  MainForm.ProgressBar.Max := ChipSize div PageSize;

  while PageAddress < ChipSize div PageSize do
  begin
    //UsbAsp45_WREN(hUSBDev);
    RomStream.ReadBuffer(DataChunk, PageSize);

    if WriteType = WT_PAGE then
      BytesWrite := BytesWrite + UsbAsp45_Write(PageAddress, datachunk, PageSize);

    while UsbAsp45_Busy() do
    begin
      Application.ProcessMessages;
      if UserCancel then Exit;
    end;

    if MainForm.MenuAutoCheck.Checked then
    begin
      UsbAsp45_Read(PageAddress, datachunk2, PageSize);
      for i:=0 to PageSize-1 do
        if DataChunk2[i] <> DataChunk[i] then
        begin
          LogPrint(STR_VERIFY_ERROR+IntToHex((PageAddress*PageSize )+i, 8));
          Exit;
        end;
    end;

    Inc(PageAddress, 1);
    MainForm.ProgressBar.Position := MainForm.ProgressBar.Position + 1;
    Application.ProcessMessages;
    if UserCancel then Break;
  end;

  if BytesWrite <> ChipSize then
    LogPrint(STR_WRONG_BYTES_WRITE)
  else
    LogPrint(STR_DONE);

  MainForm.ProgressBar.Position := 0;
end;

procedure ReadFlash25(var RomStream: TMemoryStream; StartAddress, ChipSize: cardinal);
const
  FLASH_SIZE_128MBIT = 16777216;
var
  ChunkSize: Word;
  BytesRead: integer;
  DataChunk: array[0..65534] of byte;
  Address: cardinal;
  ProgressPos: integer;
  OpStarted: TDateTime;

  //ตัวงานจริง จะรันบน thread เบื้องหลังถ้าเปิดโหมดนั้นไว้
  procedure DoWork;
  begin
  if (StartAddress >= ChipSize) or (ChipSize = 0) then
  begin
    LogPrint(STR_CHECK_SETTINGS);
    exit;
  end;

  if ASProgrammer.Current_HW = CHW_FT232H then
    ChunkSize := 16787 else
  if ASProgrammer.Current_HW = CHW_CH347 then
    ChunkSize := SizeOf(DataChunk)
  else
    ChunkSize := 2048;



  if ChunkSize > ChipSize then ChunkSize := ChipSize;

  LogPrint(STR_READING_FLASH);
  BytesRead := 0;
  Address := StartAddress;
  SetProgressMax(ChipSize div ChunkSize);
  SetProgressPos(0);
  ProgressPos := 0;
  OpStarted := Now;

  RomStream.Clear;

  if ChipSize > FLASH_SIZE_128MBIT then UsbAsp25_EN4B();

  while Address < ChipSize do
  begin
    if ChunkSize > (ChipSize - Address) then ChunkSize := ChipSize - Address;

    if ChipSize > FLASH_SIZE_128MBIT then
      BytesRead := BytesRead + UsbAsp25_Read32bitAddr($03, Address, datachunk, ChunkSize)
    else
      BytesRead := BytesRead + UsbAsp25_Read($03, Address, datachunk, ChunkSize);

    RomStream.WriteBuffer(datachunk, chunksize);
    Inc(Address, ChunkSize);

    Inc(ProgressPos);
    SetProgressPos(ProgressPos);
    ShowSpeed(Address - StartAddress, ChipSize - StartAddress, OpStarted);
    OpProcessMessages;

    if UserCancel then Break;
  end;

  if ChipSize > FLASH_SIZE_128MBIT then UsbAsp25_EX4B();

  if BytesRead <> ChipSize then
    LogPrint(STR_WRONG_BYTES_READ)
  else
    LogPrint(STR_DONE);

  SetProgressPos(0);
  ClearSpeed;
  end;

begin
  RunOperation(@DoWork);
end;

procedure ReadFlash95(var RomStream: TMemoryStream; StartAddress, ChipSize: cardinal);
var
  ChunkSize: Word;
  BytesRead: integer;
  DataChunk: array[0..2047] of byte;
  Address: cardinal;
begin
  if (StartAddress >= ChipSize) or (ChipSize = 0) then
  begin
    LogPrint(STR_CHECK_SETTINGS);
    exit;
  end;

  ChunkSize := SizeOf(DataChunk);
  if ChunkSize > ChipSize then ChunkSize := ChipSize;

  LogPrint(STR_READING_FLASH);
  BytesRead := 0;
  Address := StartAddress;
  MainForm.ProgressBar.Max := ChipSize div ChunkSize;

  RomStream.Clear;

  while Address < ChipSize do
  begin
    if ChunkSize > (ChipSize - Address) then ChunkSize := ChipSize - Address;

    BytesRead := BytesRead + UsbAsp95_Read(ChipSize, Address, datachunk, ChunkSize);
    RomStream.WriteBuffer(datachunk, chunksize);
    Inc(Address, ChunkSize);

    MainForm.ProgressBar.Position := MainForm.ProgressBar.Position + 1;
    Application.ProcessMessages;

    if UserCancel then Break;
  end;

  if BytesRead <> ChipSize then
    LogPrint(STR_WRONG_BYTES_READ)
  else
    LogPrint(STR_DONE);

  MainForm.ProgressBar.Position := 0;
end;

procedure ReadFlash45(var RomStream: TMemoryStream; StartAddress, PageSize, ChipSize: cardinal);
var
  ChunkSize: Word;
  BytesRead: integer;
  DataChunk: array[0..2047] of byte;
  Address: cardinal;
begin
  if (StartAddress >= ChipSize) or (ChipSize = 0) then
  begin
    LogPrint(STR_CHECK_SETTINGS);
    exit;
  end;

  ChunkSize := PageSize;
  if ChunkSize > ChipSize then ChunkSize := ChipSize;

  LogPrint(STR_READING_FLASH);
  BytesRead := 0;
  Address := StartAddress;
  MainForm.ProgressBar.Max := ChipSize div ChunkSize;

  RomStream.Clear;

  while Address < ChipSize div ChunkSize do
  begin
    if ChunkSize > (ChipSize - Address) then ChunkSize := ChipSize - Address;

    BytesRead := BytesRead + UsbAsp45_Read(Address, datachunk, ChunkSize);
    RomStream.WriteBuffer(datachunk, chunksize);
    Inc(Address, 1);

    MainForm.ProgressBar.Position := MainForm.ProgressBar.Position + 1;
    Application.ProcessMessages;

    if UserCancel then Break;
  end;

  if BytesRead <> ChipSize then
    LogPrint(STR_WRONG_BYTES_READ)
  else
    LogPrint(STR_DONE);

  MainForm.ProgressBar.Position := 0;
end;

procedure ReadFlashKB(var RomStream: TMemoryStream; StartAddress, ChipSize: cardinal);
var
  ChunkSize: byte;
  BytesRead: integer;
  DataChunk: byte;
  Address: cardinal;
begin
  if (StartAddress >= ChipSize) or (ChipSize = 0) then
  begin
    LogPrint(STR_CHECK_SETTINGS);
    exit;
  end;

  ChunkSize := SizeOf(DataChunk);
  if ChunkSize > ChipSize then ChunkSize := ChipSize;

  LogPrint(STR_READING_FLASH);
  BytesRead := 0;
  Address := StartAddress;
  MainForm.ProgressBar.Max := ChipSize div ChunkSize;

  UsbAspMulti_EnableEDI();

  RomStream.Clear;

  while Address < ChipSize do
  begin
    if ChunkSize > (ChipSize - Address) then ChunkSize := ChipSize - Address;

    BytesRead := BytesRead + UsbAspMulti_Read(Address, datachunk);
    RomStream.WriteBuffer(datachunk, chunksize);
    Inc(Address, ChunkSize);

    MainForm.ProgressBar.Position := MainForm.ProgressBar.Position + 1;
    Application.ProcessMessages;

    if UserCancel then Break;
  end;

  if BytesRead <> ChipSize then
    LogPrint(STR_WRONG_BYTES_READ)
  else
    LogPrint(STR_DONE);

  MainForm.ProgressBar.Position := 0;
end;


procedure VerifyFlash25(var RomStream: TMemoryStream; StartAddress, DataSize: cardinal);
const
  FLASH_SIZE_128MBIT = 16777216;
var
  ChunkSize: Word;
  BytesRead: integer;
  DataChunk: array[0..16786] of byte;
  DataChunkFile: array[0..16786] of byte;
  Address: cardinal;
  ProgressPos: integer;
  OpStarted: TDateTime;

  //ตัวงานจริง จะรันบน thread เบื้องหลังถ้าเปิดโหมดนั้นไว้
  //ตัวนับลูปต้องเป็นตัวแปรในตัวเอง เพราะ FPC ไม่ยอมให้ใช้ตัวแปร
  //ของโพรซีเยอร์ชั้นนอกมาเป็นตัวนับ for
  procedure DoWork;
  var
    i: integer;
  begin
  if (DataSize = 0) then
  begin
    LogPrint(STR_CHECK_SETTINGS);
    exit;
  end;

  if ASProgrammer.Current_HW = CHW_FT232H then
    ChunkSize := SizeOf(DataChunk)
  else
    ChunkSize := 2048;

  if ChunkSize > DataSize then ChunkSize := DataSize;

  LogPrint(STR_VERIFY);
  BytesRead := 0;
  Address := StartAddress;
  SetProgressMax(DataSize div ChunkSize);
  SetProgressPos(0);
  ProgressPos := 0;
  OpStarted := Now;

  if DataSize > FLASH_SIZE_128MBIT then UsbAsp25_EN4B();

  while (Address-StartAddress) < DataSize do
  begin
    if ChunkSize > (DataSize - (Address-StartAddress)) then ChunkSize := DataSize - (Address-StartAddress);

    if DataSize > FLASH_SIZE_128MBIT then
        BytesRead := BytesRead + UsbAsp25_Read32bitAddr($03, Address, datachunk, ChunkSize)
      else
        BytesRead := BytesRead + UsbAsp25_Read($03, Address, datachunk, ChunkSize);

    RomStream.ReadBuffer(DataChunkFile, ChunkSize);

    for i := 0 to ChunkSize -1 do
    if DataChunk[i] <> DataChunkFile[i] then
    begin
      LogPrint(STR_VERIFY_ERROR+IntToHex(Address+i, 8));
      SetProgressPos(0);
      Exit;
    end;

    Inc(Address, ChunkSize);

    Inc(ProgressPos);
    SetProgressPos(ProgressPos);
    ShowSpeed(Address - StartAddress, DataSize, OpStarted);
    OpProcessMessages;

    if UserCancel then Break;
  end;

  if DataSize > FLASH_SIZE_128MBIT then UsbAsp25_EX4B();

  if (BytesRead <> DataSize) then
    LogPrint(STR_WRONG_BYTES_READ)
  else
    LogPrint(STR_DONE);

  SetProgressPos(0);
  ClearSpeed;
  end;

begin
  RunOperation(@DoWork);
end;

procedure VerifyFlash95(var RomStream: TMemoryStream; StartAddress, DataSize, ChipSize: cardinal);
var
  ChunkSize: Word;
  BytesRead, i: integer;
  DataChunk: array[0..2047] of byte;
  DataChunkFile: array[0..2047] of byte;
  Address: cardinal;
begin
  if (DataSize = 0) then
  begin
    LogPrint(STR_CHECK_SETTINGS);
    exit;
  end;

  ChunkSize := SizeOf(DataChunk);
  if ChunkSize > DataSize then ChunkSize := DataSize;

  LogPrint(STR_VERIFY);
  BytesRead := 0;
  Address := StartAddress;
  MainForm.ProgressBar.Max := DataSize div ChunkSize;

  while (Address-StartAddress) < DataSize do
  begin
    if ChunkSize > (DataSize - (Address-StartAddress)) then ChunkSize := DataSize - (Address-StartAddress);

    BytesRead := BytesRead + UsbAsp95_Read(ChipSize, Address, datachunk, ChunkSize);
    RomStream.ReadBuffer(DataChunkFile, ChunkSize);

    for i := 0 to ChunkSize -1 do
    if DataChunk[i] <> DataChunkFile[i] then
    begin
      LogPrint(STR_VERIFY_ERROR+IntToHex(Address+i, 8));
      MainForm.ProgressBar.Position := 0;
      Exit;
    end;

    Inc(Address, ChunkSize);

    MainForm.ProgressBar.Position := MainForm.ProgressBar.Position + 1;
    Application.ProcessMessages;

    if UserCancel then Break;
  end;

  if (BytesRead <> DataSize) then
    LogPrint(STR_WRONG_BYTES_READ)
  else
    LogPrint(STR_DONE);

  MainForm.ProgressBar.Position := 0;
end;

procedure VerifyFlash45(var RomStream: TMemoryStream; StartAddress, PageSize, ChipSize: cardinal);
var
  ChunkSize: Word;
  BytesRead, i: integer;
  DataChunk: array[0..2047] of byte;
  DataChunkFile: array[0..2047] of byte;
  PageAddress: cardinal;
begin
  if (StartAddress >= ChipSize) or (ChipSize = 0) then
  begin
    LogPrint(STR_CHECK_SETTINGS);
    exit;
  end;

  ChunkSize := PageSize;
  if ChunkSize > ChipSize then ChunkSize := ChipSize;

  LogPrint(STR_VERIFY);
  BytesRead := 0;
  PageAddress := StartAddress;
  MainForm.ProgressBar.Max := ChipSize div ChunkSize;

  while PageAddress < ChipSize div ChunkSize do
  begin
    //if ChunkSize > (ChipSize - Address) then ChunkSize := ChipSize - Address;

    BytesRead := BytesRead + UsbAsp45_Read(PageAddress, datachunk, ChunkSize);
    RomStream.ReadBuffer(DataChunkFile, ChunkSize);

    for i := 0 to ChunkSize -1 do
    if DataChunk[i] <> DataChunkFile[i] then
    begin
      LogPrint(STR_VERIFY_ERROR+IntToHex((PageAddress*ChunkSize)+i, 8));
      MainForm.ProgressBar.Position := 0;
      Exit;
    end;

    Inc(PageAddress, 1);

    MainForm.ProgressBar.Position := MainForm.ProgressBar.Position + 1;
    Application.ProcessMessages;

    if UserCancel then Break;
  end;

  if (BytesRead <> ChipSize) then
    LogPrint(STR_WRONG_BYTES_READ)
  else
    LogPrint(STR_DONE);

  MainForm.ProgressBar.Position := 0;
end;

procedure VerifyFlashMW(var RomStream: TMemoryStream; AddrBitLen: byte; StartAddress, ChipSize: cardinal);
var
  ChunkSize: Word;
  BytesRead, i: integer;
  DataChunk: array[0..2047] of byte;
  DataChunkFile: array[0..2047] of byte;
  Address: cardinal;
begin
  if (StartAddress >= ChipSize) or (ChipSize = 0) then
  begin
    LogPrint(STR_CHECK_SETTINGS);
    exit;
  end;

  ChunkSize := 2;
  if ChunkSize > ChipSize then ChunkSize := ChipSize;

  LogPrint(STR_VERIFY);
  BytesRead := 0;
  Address := StartAddress;
  MainForm.ProgressBar.Max := ChipSize div ChunkSize;

  while Address < ChipSize div 2 do
  begin
    BytesRead := BytesRead + UsbAspMW_Read(AddrBitLen, Address, datachunk, ChunkSize);
    RomStream.ReadBuffer(DataChunkFile, ChunkSize);

    for i := 0 to ChunkSize -1 do
    if DataChunk[i] <> DataChunkFile[i] then
    begin
      LogPrint(STR_VERIFY_ERROR+IntToHex(Address+i, 8));
      MainForm.ProgressBar.Position := 0;
      Exit;
    end;

    Inc(Address, ChunkSize div 2);

    MainForm.ProgressBar.Position := MainForm.ProgressBar.Position + 2;
    Application.ProcessMessages;
    if UserCancel then Break;
  end;

  if (BytesRead <> ChipSize) then
    LogPrint(STR_WRONG_BYTES_READ)
  else
    LogPrint(STR_DONE);

  MainForm.ProgressBar.Position := 0;
end;

procedure VerifyFlashKB(var RomStream: TMemoryStream; StartAddress, ChipSize: cardinal);
var
  ChunkSize: byte;
  BytesRead: integer;
  DataChunk: byte;
  DataChunkFile: byte;
  Address: cardinal;
begin
  if (StartAddress >= ChipSize) or (ChipSize = 0) then
  begin
    LogPrint(STR_CHECK_SETTINGS);
    exit;
  end;

  ChunkSize := SizeOf(DataChunk);
  if ChunkSize > ChipSize then ChunkSize := ChipSize;

  LogPrint(STR_VERIFY);
  BytesRead := 0;
  Address := StartAddress;
  MainForm.ProgressBar.Max := ChipSize div ChunkSize;

  UsbAspMulti_EnableEDI();
  UsbAspMulti_WriteReg($FEAD, $08); //เปิดใช้งานแฟลช

  //RomStream.Clear;

  while Address < ChipSize do
  begin
    if ChunkSize > (ChipSize - Address) then ChunkSize := ChipSize - Address;

    BytesRead := BytesRead + UsbAspMulti_Read(Address, datachunk);
    RomStream.ReadBuffer(DataChunkFile, ChunkSize);

    if DataChunk <> DataChunkFile then
    begin
      LogPrint(STR_VERIFY_ERROR+IntToHex(Address, 8));
      MainForm.ProgressBar.Position := 0;
      Exit;
    end;

    Inc(Address, ChunkSize);

    MainForm.ProgressBar.Position := MainForm.ProgressBar.Position + 1;
    Application.ProcessMessages;

    if UserCancel then Break;
  end;

  if BytesRead <> ChipSize then
    LogPrint(STR_WRONG_BYTES_READ)
  else
    LogPrint(STR_DONE);

  MainForm.ProgressBar.Position := 0;
end;

procedure ReadFlashI2C(var RomStream: TMemoryStream; StartAddress, ChipSize: cardinal; ChunkSize: Word; DevAddr: byte);
var
  BytesRead: integer;
  DataChunk: array[0..255] of byte;
  Address: cardinal;
begin
  if ChipSize = 0 then
  begin
    LogPrint(STR_CHECK_SETTINGS);
    exit;
  end;

  if ChunkSize > SizeOf(DataChunk) then ChunkSize := SizeOf(DataChunk);
  if ChunkSize < 1 then ChunkSize := 1;
  if ChunkSize > ChipSize then ChunkSize := ChipSize;

  LogPrint(STR_READING_FLASH);
  BytesRead := 0;
  Address := StartAddress;
  MainForm.ProgressBar.Max := ChipSize div ChunkSize;

  RomStream.Clear;

  while Address < ChipSize do
  begin
    if ChunkSize > (ChipSize - Address) then ChunkSize := ChipSize - Address;

    BytesRead := BytesRead + UsbAspI2C_Read(DevAddr, MainForm.ComboAddrType.ItemIndex, Address, datachunk, ChunkSize);
    RomStream.WriteBuffer(DataChunk, ChunkSize);
    Inc(Address, ChunkSize);

    MainForm.ProgressBar.Position := MainForm.ProgressBar.Position + 1;
    Application.ProcessMessages;
    if UserCancel then Break;
  end;

  if BytesRead <> ChipSize then
    LogPrint(STR_WRONG_BYTES_READ)
  else
    LogPrint(STR_DONE);

  MainForm.ProgressBar.Position := 0;
end;

procedure WriteFlashI2C(var RomStream: TMemoryStream; StartAddress, WriteSize: cardinal; PageSize: word; DevAddr: byte);
var
  DataChunk: array[0..2047] of byte;
  Address, BytesWrite: cardinal;
  PageSizeTemp: word;
begin
  if {(StartAddress >= WriteSize) or} (WriteSize = 0) {or (PageSize > WriteSize)} then
  begin
    LogPrint(STR_CHECK_SETTINGS);
    exit;
  end;

  PageSizeTemp := PageSize;
  LogPrint(STR_WRITING_FLASH);
  BytesWrite := 0;
  Address := StartAddress;
  MainForm.ProgressBar.Max := WriteSize div PageSize;

  while (Address-StartAddress) < WriteSize do
  begin
    //คำนวณขนาดบัฟเฟอร์เพจแรก กันไม่ให้บัฟเฟอร์วนกลับเมื่อชนขอบแอดเดรส
    if (StartAddress > 0) and (Address = StartAddress) and (PageSize > 1) then
       PageSize := (StrToInt(MainForm.ComboChipSize.Text) - StartAddress) mod PageSize else
           PageSize := PageSizeTemp;

    if (WriteSize - (Address-StartAddress)) < PageSize then PageSize := (WriteSize - (Address-StartAddress));

    RomStream.ReadBuffer(DataChunk, PageSize);
    BytesWrite := BytesWrite + UsbAspI2C_Write(DevAddr, MainForm.ComboAddrType.ItemIndex, Address, datachunk, PageSize);
    Inc(Address, PageSize);

    while UsbAspI2C_BUSY(DevAddr) do
    begin
      Application.ProcessMessages;
      if UserCancel then Exit;
    end; 

    MainForm.ProgressBar.Position := MainForm.ProgressBar.Position + 1;
    Application.ProcessMessages;
    if UserCancel then Break;
  end;

  if BytesWrite <> WriteSize then
    LogPrint(STR_WRONG_BYTES_WRITE)
  else
    LogPrint(STR_DONE);

  MainForm.ProgressBar.Position := 0;
end;

procedure EraseFlashI2C(StartAddress, WriteSize: cardinal; PageSize: word; DevAddr: byte);
var
  DataChunk: array[0..2047] of byte;
  Address, BytesWrite: cardinal;
begin
  if (StartAddress >= WriteSize) or (WriteSize = 0) then
  begin
    LogPrint(STR_CHECK_SETTINGS);
    exit;
  end;

  LogPrint(STR_ERASING_FLASH);
  BytesWrite := 0;
  Address := StartAddress;
  MainForm.ProgressBar.Max := WriteSize div PageSize;

  while Address < WriteSize do
  begin
    if (WriteSize - Address) < PageSize then PageSize := (WriteSize - Address);
    FillByte(DataChunk, PageSize, $FF);
    BytesWrite := BytesWrite + UsbAspI2C_Write(DevAddr, MainForm.ComboAddrType.ItemIndex, Address, datachunk, PageSize);
    Inc(Address, PageSize);

    while UsbAspI2C_BUSY(DevAddr) do
    begin
      Application.ProcessMessages;
      if UserCancel then Exit;
    end; 

    MainForm.ProgressBar.Position := MainForm.ProgressBar.Position + 1;
    Application.ProcessMessages;
    if UserCancel then Break;
  end;

  if BytesWrite <> WriteSize then
    LogPrint(STR_WRONG_BYTES_WRITE)
  else
    LogPrint(STR_DONE);

  MainForm.ProgressBar.Position := 0;
end;

procedure VerifyFlashI2C(var RomStream: TMemoryStream; StartAddress, DataSize: cardinal; ChunkSize: Word; DevAddr: byte);
var
  BytesRead, i: integer;
  DataChunk: array[0..2047] of byte;
  DataChunkFile: array[0..2047] of byte;
  Address: cardinal;
begin
  if (DataSize = 0) then
  begin
    LogPrint(STR_CHECK_SETTINGS);
    exit;
  end;

  if ChunkSize > SizeOf(DataChunk) then ChunkSize := SizeOf(DataChunk);
  if ChunkSize < 1 then ChunkSize := 1;
  if ChunkSize > DataSize then ChunkSize := DataSize;

  LogPrint(STR_VERIFY);
  BytesRead := 0;
  Address := StartAddress;
  MainForm.ProgressBar.Max := DataSize div ChunkSize;

  while (Address-StartAddress) < DataSize do
  begin
    if ChunkSize > (DataSize - (Address - StartAddress)) then ChunkSize := DataSize -(Address - StartAddress) ;

    BytesRead := BytesRead + UsbAspI2C_Read(DevAddr, MainForm.ComboAddrType.ItemIndex, Address, datachunk, ChunkSize);
    RomStream.ReadBuffer(DataChunkFile, ChunkSize);

    for i := 0 to ChunkSize -1 do
    if DataChunk[i] <> DataChunkFile[i] then
    begin
      LogPrint(STR_VERIFY_ERROR+IntToHex(Address+i, 8));
      MainForm.ProgressBar.Position := 0;
      Exit;
    end;

    Inc(Address, ChunkSize);

    MainForm.ProgressBar.Position := MainForm.ProgressBar.Position + 1;
    Application.ProcessMessages;
    if UserCancel then Break;
  end;

  if (BytesRead <> DataSize) then
    LogPrint(STR_WRONG_BYTES_READ)
  else
    LogPrint(STR_DONE);

  MainForm.ProgressBar.Position := 0;
end;

procedure SelectHW(programmer: THardwareList);
begin
  //เมนู Buzzpirat กับรายการพอร์ต COM ใช้เฉพาะกับเครื่องที่คุยผ่านพอร์ตอนุกรม
  //ถ้าใช้ CH341/CH347/FT232H อยู่ก็ไม่ต้องมีให้เกะกะ
  MainForm.MenuBuzzpirat.Visible := programmer = CHW_BUZZPIRAT;
  MainForm.ListcomportsMenuItem.Visible := programmer in [CHW_BUZZPIRAT, CHW_ARDUINO];

  if programmer = CHW_USBASP then
  begin
    MainForm.MenuSPIClock.Visible:= true;
    MainForm.MenuCH347SPIClock.Visible:= false;
    MainForm.MenuAVRISPSPIClock.Visible:= false;
    MainForm.MenuArduinoSPIClock.Visible:= false;
    MainForm.MenuFT232SPIClock.Visible:= false;
    MainForm.MenuMicrowire.Enabled:= true;
    AsProgrammer.Current_HW := CHW_USBASP;
  end;

  if programmer = CHW_CH341 then
  begin
    MainForm.MenuSPIClock.Visible:= false;
    MainForm.MenuCH347SPIClock.Visible:= false;
    MainForm.MenuAVRISPSPIClock.Visible:= false;
    MainForm.MenuArduinoSPIClock.Visible:= false;
    MainForm.MenuFT232SPIClock.Visible:= false;
    MainForm.MenuMicrowire.Enabled:= false;
    AsProgrammer.Current_HW := CHW_CH341;
  end;

  if programmer = CHW_CH347 then
  begin
    MainForm.MenuCH347SPIClock.Visible:= true;
    MainForm.MenuSPIClock.Visible:= false;
    MainForm.MenuAVRISPSPIClock.Visible:= false;
    MainForm.MenuArduinoSPIClock.Visible:= false;
    MainForm.MenuFT232SPIClock.Visible:= false;
    MainForm.MenuMicrowire.Enabled:= false;
    AsProgrammer.Current_HW := CHW_CH347;
  end;

  if programmer = CHW_AVRISP then
  begin
    MainForm.MenuSPIClock.Visible:= false;
    MainForm.MenuCH347SPIClock.Visible:= false;
    MainForm.MenuAVRISPSPIClock.Visible:= true;
    MainForm.MenuArduinoSPIClock.Visible:= false;
    MainForm.MenuFT232SPIClock.Visible:= false;
    MainForm.MenuMicrowire.Enabled:= false;
    AsProgrammer.Current_HW := CHW_AVRISP;
  end;

  if programmer = CHW_ARDUINO then
  begin
    MainForm.MenuSPIClock.Visible:= false;
    MainForm.MenuCH347SPIClock.Visible:= false;
    MainForm.MenuAVRISPSPIClock.Visible:= false;
    MainForm.MenuArduinoSPIClock.Visible:= true;
    MainForm.MenuFT232SPIClock.Visible:= false;
    MainForm.MenuMicrowire.Enabled:= false;
    AsProgrammer.Current_HW := CHW_ARDUINO;
  end;

  if programmer = CHW_BUZZPIRAT then
  begin
    MainForm.MenuSPIClock.Visible:= false;
    MainForm.MenuAVRISPSPIClock.Visible:= false;
    MainForm.MenuArduinoSPIClock.Visible:= false;
    MainForm.MenuFT232SPIClock.Visible:= false;
    MainForm.MenuMicrowire.Enabled:= false;
    AsProgrammer.Current_HW := CHW_BUZZPIRAT;
  end;

  if programmer = CHW_FT232H then
  begin
    MainForm.MenuFT232SPIClock.Visible:= true;
    MainForm.MenuCH347SPIClock.Visible:= false;
    MainForm.MenuSPIClock.Visible:= false;
    MainForm.MenuAVRISPSPIClock.Visible:= false;
    MainForm.MenuArduinoSPIClock.Visible:= false;
    MainForm.MenuMicrowire.Enabled:= false;
    AsProgrammer.Current_HW := CHW_FT232H;
  end;

end;

//ไล่เปิดอุปกรณ์ทีละตัว เพื่อดูว่ามีเครื่องโปรแกรมตัวไหนเสียบอยู่จริง
//ข้ามพวกที่ใช้พอร์ตอนุกรม เพราะการไล่เปิดพอร์ตมั่ว ๆ จะไปกวนอุปกรณ์อื่น
function ProbeProgrammer(out Found: THardwareList): boolean;
const
  Candidates: array[0..4] of THardwareList =
    (CHW_CH341, CHW_CH347, CHW_FT232H, CHW_USBASP, CHW_AVRISP);
var
  i: integer;
  Saved: THardwareList;
begin
  Result := False;
  Found := CHW_NONE;
  Saved := AsProgrammer.Current_HW;

  for i := Low(Candidates) to High(Candidates) do
  begin
    AsProgrammer.Current_HW := Candidates[i];
    if AsProgrammer.Programmer.DevOpen then
    begin
      AsProgrammer.Programmer.DevClose;
      Found := Candidates[i];
      AsProgrammer.Current_HW := Saved;
      Exit(True);
    end;
  end;

  AsProgrammer.Current_HW := Saved;
end;

//ติ๊กเมนู Hardware ให้ตรงกับอุปกรณ์ที่ใช้งานอยู่จริง
procedure SetHardwareMenuCheck(HW: THardwareList);
begin
  MainForm.MenuHWUSBASP.Checked    := HW = CHW_USBASP;
  MainForm.MenuHWCH341A.Checked    := HW = CHW_CH341;
  MainForm.MenuHWCH347.Checked     := HW = CHW_CH347;
  MainForm.MenuHWAVRISP.Checked    := HW = CHW_AVRISP;
  MainForm.MenuHWARDUINO.Checked   := HW = CHW_ARDUINO;
  MainForm.MenuHWBUZZPIRAT.Checked := HW = CHW_BUZZPIRAT;
  MainForm.MenuHWFT232H.Checked    := HW = CHW_FT232H;
end;

//เช็คว่ามีเครื่องโปรแกรมต่ออยู่ไหม ถ้าตัวที่เลือกไว้หายไปและเปิดโหมดค้นหาอัตโนมัติ
//ก็สลับไปใช้ตัวที่เจอแทน
procedure PollProgrammer(Announce: boolean);
var
  Present, Was: boolean;
  Found: THardwareList;
begin
  if OperationRunning then Exit;

  Was := ProgrammerPresent;

  //อุปกรณ์ที่ใช้พอร์ตอนุกรมไม่เอามาวนเช็ค เพราะจะไปจับพอร์ตทิ้งขว้างตลอดเวลา
  if AsProgrammer.Current_HW in [CHW_ARDUINO, CHW_BUZZPIRAT] then
  begin
    ProgrammerPresent := True;
    MainForm.ChipView.Invalidate;
    Exit;
  end;

  Present := AsProgrammer.Programmer.DevOpen;
  if Present then AsProgrammer.Programmer.DevClose;

  if (not Present) and MainForm.MenuAutoDetectHW.Checked then
    if ProbeProgrammer(Found) then
    begin
      SelectHW(Found);
      SetHardwareMenuCheck(Found);
      Present := True;
      LogPrint(STR_HW_SWITCHED + AsProgrammer.Programmer.HardwareName);
    end;

  ProgrammerPresent := Present;

  //พูดเฉพาะตอนสถานะเปลี่ยน ไม่งั้น log จะเต็มไปด้วยข้อความซ้ำทุกสามวินาที
  if Announce or (Was <> ProgrammerPresent) then
  begin
    if ProgrammerPresent then
      LogPrint(STR_HW_CONNECTED + AsProgrammer.Programmer.HardwareName)
    else
      LogPrint(STR_HW_DISCONNECTED);
  end;

  MainForm.ChipView.Invalidate;
end;

procedure LockControl;
begin
  //อ่านสถานะหน้าจอเก็บไว้ก่อนเริ่มงาน thread เบื้องหลังจะอ่านค่า
  //จาก OpUI ไม่ใช่จาก control โดยตรง
  CaptureUIState;
  OperationRunning := True;

  MainForm.ButtonRead.Enabled := False;
  MainForm.ButtonWrite.Enabled := False;
  MainForm.ButtonVerify.Enabled := False;
  MainForm.ButtonReadID.Enabled := False;
  MainForm.ButtonBlock.Enabled := False;
  MainForm.ButtonErase.Enabled := False;
  MainForm.ButtonOpenHex.Enabled := False;
  MainForm.ButtonSaveHex.Enabled := False;

  MainForm.GroupChipSettings.Enabled := false;
  MainForm.MPHexEditorEx.Enabled := false;
end;

procedure UnlockControl;
begin
  OperationRunning := False;

  MainForm.MPHexEditorEx.Enabled := true;
  MainForm.GroupChipSettings.Enabled := true;
  MainForm.ButtonRead.Enabled := True;
  MainForm.ButtonWrite.Enabled := True;
  MainForm.ButtonVerify.Enabled := True;
  MainForm.ButtonOpenHex.Enabled := True;
  MainForm.ButtonSaveHex.Enabled := True;
  MainForm.ButtonErase.Enabled := True;

  if MainForm.RadioSPI.Checked then
  begin
    MainForm.ButtonReadID.Enabled := True;
    if MainForm.ComboSPICMD.ItemIndex = SPI_CMD_KB then
      MainForm.ButtonBlock.Enabled := False
    else
      MainForm.ButtonBlock.Enabled := True;
  end;
end;

//เลือกชิปตามชื่อ โดยหาในไฟล์หลักก่อน แล้วค่อยหาในไฟล์เสริม
function SelectChipAny(const AName: string): boolean;
begin
  Result := findchip.SelectChip(ChipListFile, AName);
  if not Result then
    Result := findchip.SelectChip(ChipListFile2, AName);
  UpdateChipInfo;
end;

procedure TMainForm.ChipClick(Sender: TObject);
begin
  if Sender is TMenuItem then
    SelectChipAny(TMenuItem(Sender).Caption);
end;

procedure TMainForm.MPHexEditorExChange(Sender: TObject);
begin
  StatusBar.Panels.Items[0].Text := STR_SIZE+IntToStr(MPHexEditorEx.DataSize);
  if MPHexEditorEx.Modified then
    StatusBar.Panels.Items[1].Text := STR_CHANGED
  else
    StatusBar.Panels.Items[1].Text := '';
end;

procedure TMainForm.ComboItem1Click(Sender: TObject);
var
  CheckTemp: Boolean;
begin
  if MessageDlg('AsProgrammer', STR_COMBO_WARN, mtConfirmation, [mbYes, mbNo], 0)
    <> mrYes then Exit;

  if ButtonBlock.Enabled then
    ButtonBlockClick(Sender);
  if ButtonErase.Enabled then
    if ComboSPICMD.ItemIndex <> SPI_CMD_45 then  //ชิปพวกนี้ลบเพจให้เองอยู่แล้ว
      ButtonEraseClick(Sender);

  CheckTemp := MenuAutoCheck.Checked;
  MenuAutoCheck.Checked := True;

  ButtonWriteClick(Sender);

  MenuAutoCheck.Checked := CheckTemp;
end;

procedure TMainForm.MenuArduinoCOMPortClick(Sender: TObject);
begin
  Arduino_COMPort := InputBox('Arduino COMPort','',Arduino_COMPort);
  MainForm.MenuArduinoCOMPort.Caption := 'Arduino COMPort: '+Arduino_COMPort;
end;

procedure TMainForm.MenuBuzzpiratCOMPortClick(Sender: TObject);
begin
  Buzzpirat_COMPort := InputBox('Buzzpirat / Buspirate COMPort','',Buzzpirat_COMPort);
  MainForm.MenuBuzzpiratCOMPort.Caption := 'Buzzpirat / Buspirate COMPort: '+Buzzpirat_COMPort;
end;

procedure TMainForm.MenuCopyToClipClick(Sender: TObject);
begin
    MainForm.MPHexEditorEx.CBCopy;
end;

procedure TMainForm.MenuFindChipClick(Sender: TObject);
begin
  ChipSearchForm.EditSearch.Text:= '';
  ChipSearchForm.ListBoxChips.Items.Clear;
  ChipSearchForm.Show;
  ChipSearchForm.EditSearch.SetFocus;
end;

procedure TMainForm.MenuFindClick(Sender: TObject);
begin
  Search.SearchForm.Show;
end;

procedure TMainForm.MenuGotoOffsetClick(Sender: TObject);
var
  s : string;
  addr: integer;
begin
  s := InputBox(STR_GOTO_ADDR,'','');
  s := Trim(s);
  if IsNumber('$'+s)  then
  begin
    addr := StrToInt('$' + s);
    MainForm.MPHexEditorEx.SelStart := addr;
    MainForm.MPHexEditorEx.SelEnd := addr;
  end;
end;

procedure TMainForm.MenuHWCH341AClick(Sender: TObject);
begin
  SelectHW(CHW_CH341);
end;

procedure TMainForm.MenuHWCH347Click(Sender: TObject);
begin
  SelectHW(CHW_CH347);
end;

procedure TMainForm.MenuHWFT232HClick(Sender: TObject);
begin
  SelectHW(CHW_FT232H);
end;

procedure TMainForm.MenuHWUSBASPClick(Sender: TObject);
begin
  SelectHW(CHW_USBASP);
end;

procedure TMainForm.MenuHWAVRISPClick(Sender: TObject);
begin
  SelectHW(CHW_AVRISP);
end;

procedure TMainForm.MenuHWARDUINOClick(Sender: TObject);
begin
  SelectHW(CHW_ARDUINO);
end;

procedure TMainForm.MenuHWBUZZPIRATClick(Sender: TObject);
begin
  SelectHW(CHW_BUZZPIRAT);
end;

procedure TMainForm.MenuItemBenchmarkClick(Sender: TObject);
var
  buffer: array[0..2047] of byte;
  i, cycles: integer;
  t: TDateTime;
  timeval: integer;
  ms, sec, d: word;
begin
  ButtonCancel.Tag := 0;
  if not OpenDevice() then exit;
  EnterProgMode25(SetSPISpeed(0), MainForm.MenuSendAB.Checked);
  LockControl();

  if (AsProgrammer.Current_HW = CHW_CH341) or (AsProgrammer.Current_HW = CHW_AVRISP) or (AsProgrammer.Current_HW = CHW_CH347)
    or (AsProgrammer.Current_HW = CHW_FT232H) then
    cycles := 256
  else
    cycles := 32;

  LogPrint('Benchmark read '+ IntToStr(SizeOf(buffer))+' bytes * '+ IntToStr(cycles) +' cycles');
  Application.ProcessMessages();
  TimeCounter := Time();

  for i:=1 to cycles do
  begin
    UsbAsp25_Read(0, 0, buffer, sizeof(buffer));
    Application.ProcessMessages;

    if UserCancel then Break;
  end;

  t :=  Time() - TimeCounter;
  DecodeDateTime(t, d, d, d, d, d, sec, ms);

  timeval := (sec * 1000) + ms;
  if timeval = 0 then timeval := 1;

  LogPrint(STR_TIME + TimeToStr(t)+' '+
    IntToStr( Trunc(((cycles*sizeof(buffer)) / timeval) * 1000)) +' bytes/s');

  LogPrint('Benchmark write '+ IntToStr(SizeOf(buffer))+' bytes * '+ IntToStr(cycles) +' cycles');
  Application.ProcessMessages();
  TimeCounter := Time();

  for i:=1 to cycles do
  begin
    UsbAsp25_Write(0, 0, buffer, sizeof(buffer));
    Application.ProcessMessages;

    if UserCancel then Break;
  end;

  t :=  Time() - TimeCounter;
  DecodeDateTime(t, d, d, d, d, d, sec, ms);

  timeval := (sec * 1000) + ms;
  if timeval = 0 then timeval := 1;

  LogPrint(STR_TIME + TimeToStr(t)+' '+
    IntToStr( Trunc(((cycles*sizeof(buffer)) / timeval) * 1000)) +' bytes/s');

  ExitProgMode25;
  AsProgrammer.Programmer.DevClose;
  UnlockControl();
end;

procedure TMainForm.MenuItemEditSregClick(Sender: TObject);
begin
  if MainForm.ComboSPICMD.ItemIndex = SPI_CMD_25 then
    sregedit.sregeditForm.Show;
end;

procedure TMainForm.MenuItemLockFlashClick(Sender: TObject);
var
  sreg: byte;
begin
  try
  ButtonCancel.Tag := 0;
  if not OpenDevice() then exit;
  sreg:= 0;
  LockControl();
  EnterProgMode25(SetSPISpeed(0), MainForm.MenuSendAB.Checked);

  if ComboSPICMD.ItemIndex = SPI_CMD_25 then
  begin
    UsbAsp25_ReadSR(sreg); //อ่าน register
    LogPrint(STR_OLD_SREG+IntToBin(sreg, 8));

    sreg := %10011100; //
    UsbAsp25_WREN(); //เปิดสิทธิ์เขียน
    UsbAsp25_WriteSR(sreg); //ตั้งค่า register

    //รอจนกว่าชิปจะพร้อม
    if not WaitNotBusy25(BUSY_TIMEOUT_SECTOR) then Exit;

    LogPrint(STR_NEW_SREG+IntToBin(sreg, 8));
  end;

  if ComboSPICMD.ItemIndex = SPI_CMD_95 then
  begin
    UsbAsp95_ReadSR(sreg); //อ่าน register
    LogPrint(STR_OLD_SREG+IntToBin(sreg, 8));

    sreg := %10011100; //
    UsbAsp95_WREN(); //เปิดสิทธิ์เขียน
    UsbAsp95_WriteSR(sreg); //ตั้งค่า register

    //รอจนกว่าชิปจะพร้อม
    if not WaitNotBusy25(BUSY_TIMEOUT_SECTOR) then Exit;

    LogPrint(STR_NEW_SREG+IntToBin(sreg, 8));
  end;


finally
  ExitProgMode25;
  AsProgrammer.Programmer.DevClose;
  UnlockControl();
end;

end;

procedure TMainForm.MenuItemReadSregClick(Sender: TObject);
var
  sreg, sreg2, sreg3: byte;
begin
  try
  ButtonCancel.Tag := 0;
  if not OpenDevice() then exit;
  sreg:= 0;
  LockControl();
  EnterProgMode25(SetSPISpeed(0), MainForm.MenuSendAB.Checked);

  if ComboSPICMD.ItemIndex = SPI_CMD_25 then
  begin
    UsbAsp25_ReadSR(sreg); //อ่าน register
    UsbAsp25_ReadSR(sreg2, $35); //ไบต์ที่สอง
    UsbAsp25_ReadSR(sreg3, $15); //ไบต์ที่สาม
    LogPrint('Sreg: '+IntToBin(sreg, 8)+'(0x'+(IntToHex(sreg, 2)+'), ')
                                         +IntToBin(sreg2, 8)+'(0x'+(IntToHex(sreg2, 2)+'), ')
                                         +IntToBin(sreg3, 8)+'(0x'+(IntToHex(sreg3, 2)+')'));
  end;

  if ComboSPICMD.ItemIndex = SPI_CMD_95 then
  begin
    UsbAsp95_ReadSR(sreg); //อ่าน register
    LogPrint('Sreg: '+IntToBin(sreg, 8));
  end;

  if ComboSPICMD.ItemIndex = SPI_CMD_45 then
  begin
    UsbAsp45_ReadSR(sreg); //อ่าน register
    LogPrint('Sreg: '+IntToBin(sreg, 8));
  end;

finally
  ExitProgMode25;
  AsProgrammer.Programmer.DevClose;
  UnlockControl();
end;

end;

procedure TMainForm.RadioI2CChange(Sender: TObject);
begin
  LabelChipInfo.Visible       := False;
  Label1.Visible              := True;
  Label4.Visible              := True;
  ComboAddrType.Visible       := True;
  ComboPageSize.Visible       := True;
  Label5.Visible              := False;
  LabelSPICMD.Visible         := False;
  ButtonReadID.Enabled        := False;
  ButtonBlock.Enabled         := False;
  ButtonErase.Enabled         := True;
  ComboMWBitLen.Visible       := False;
  ComboSPICMD.Visible         := False;
  Panel_I2C_DevAddr.Visible   := True;

  ComboMWBitLen.Text:= 'MW addr len';
  ComboAddrType.Text:= '';
  ComboPageSize.Text:= 'Page size';
  ComboChipSize.Text:= 'Chip size';
  ChipView.Invalidate;
end;

procedure TMainForm.RadioMwChange(Sender: TObject);
begin
  LabelChipInfo.Visible       := False;
  Label1.Visible              := False;
  ComboPageSize.Visible       := False;
  ComboAddrType.Visible       := False;
  ComboSPICMD.Visible         := False;
  ButtonReadID.Enabled        := False;
  ButtonBlock.Enabled         := False;
  Label4.Visible              := False;
  LabelSPICMD.Visible         := False;
  Panel_I2C_DevAddr.Visible   := False;
  Label5.Visible              := True;
  ButtonErase.Enabled         := True;
  ComboMWBitLen.Visible       := True;


  ComboMWBitLen.Text:= 'MW addr len';
  ComboAddrType.Text:= '';
  ComboPageSize.Text:= 'Page size';
  ComboChipSize.Text:= 'Chip size';
  ChipView.Invalidate;
end;

procedure TMainForm.RadioSPIChange(Sender: TObject);
var
  SkipFFLabel: string;
begin
  Label1.Visible              := True;
  LabelSPICMD.Visible         := True;
  ComboPageSize.Visible       := True;
  ComboSPICMD.Visible         := True;

  ButtonErase.Enabled         := True;
  ButtonReadID.Enabled        := True;

  if ComboSPICMD.ItemIndex = SPI_CMD_KB then
  begin
    ButtonBlock.Enabled := False;

    SkipFFLabel := MenuSkipFF.Caption;
    Delete(SkipFFLabel, Length(SkipFFLabel)-1 ,2);
    MenuSkipFF.Caption := SkipFFLabel + '00';
  end
  else
  begin
    ButtonBlock.Enabled := True;

    SkipFFLabel := MenuSkipFF.Caption;
    Delete(SkipFFLabel, Length(SkipFFLabel)-1 ,2);
    MenuSkipFF.Caption := SkipFFLabel + 'FF'
  end;

  ComboMWBitLen.Visible       := False;
  Label4.Visible              := False;
  Label5.Visible              := False;
  ComboAddrType.Visible       := False;

  Panel_I2C_DevAddr.Visible  := False;
  LabelChipInfo.Visible      := True;

  ComboMWBitLen.Text:= 'MW addr len';
  ComboAddrType.Text:= '';
  ComboPageSize.Text:= 'Page size';
  ComboChipSize.Text:= 'Chip size';
  ChipView.Invalidate;
end;

procedure TMainForm.ButtonWriteClick(Sender: TObject);
var
  PageSize: word;
  WriteType: byte;
  I2C_DevAddr: byte;
  I2C_ChunkSize: Word;
begin
  I2C_ChunkSize := 65535;
try
  ButtonCancel.Tag := 0;
  if not OpenDevice() then exit;
  if Sender <> ComboItem1 then
    if MessageDlg('AsProgrammer', STR_START_WRITE, mtConfirmation, [mbYes, mbNo], 0)
      <> mrYes then Exit;
  LockControl();

  if RunScriptFromFile(CurrentICParam.Script, 'write') then Exit;

  LogPrint(TimeToStr(Time()));

  if (not IsNumber(ComboChipSize.Text)) then
  begin
    LogPrint(STR_CHECK_SETTINGS);
    Exit;
  end;

  if MPHexEditorEx.DataSize > StrToInt(ComboChipSize.Text) - Hex2Dec('$'+StartAddressEdit.Text) then
  begin
    LogPrint(STR_WRONG_FILE_SIZE);
    Exit;
  end;

  //SPI
  if RadioSPI.Checked then
  begin
    EnterProgMode25(SetSPISpeed(0), MainForm.MenuSendAB.Checked);

    if not VoltageWarningOK then Exit;
    if not VerifyChipID then Exit;
    if not AutoBackupChip then Exit;
    if not BlankCheckBeforeWrite(Hex2Dec('$'+StartAddressEdit.Text), MPHexEditorEx.DataSize) then Exit;

    if ComboSPICMD.ItemIndex <> SPI_CMD_KB then
      IsLockBitsEnabled;
    if (not IsNumber(ComboPageSize.Text)) and (UpperCase(ComboPageSize.Text)<>'SSTB') and (UpperCase(ComboPageSize.Text)<>'SSTW') then
    begin
      LogPrint(STR_CHECK_SETTINGS);
      Exit;
    end;
    TimeCounter := Time();

    RomF.Position := 0;
    MPHexEditorEx.SaveToStream(RomF);
    RomF.Position := 0;

    ApplySerialToStream(RomF);

    if UpperCase(ComboPageSize.Text)='SSTB' then
    begin
      PageSize := 1;
      WriteType := WT_SSTB;
    end;

    if UpperCase(ComboPageSize.Text)='SSTW' then
    begin
      PageSize := 2;
      WriteType := WT_SSTW;
    end;

    if IsNumber(ComboPageSize.Text) then
    begin
      PageSize := StrToInt(ComboPageSize.Text);
      if PageSize < 1 then
      begin
        PageSize := 1;
        ComboPageSize.Text := '1';
      end;
      WriteType := WT_PAGE;
    end;

    if ComboSPICMD.ItemIndex = SPI_CMD_25 then
      WriteFlash25(RomF, Hex2Dec('$'+StartAddressEdit.Text), MPHexEditorEx.DataSize, PageSize, WriteType);
    if ComboSPICMD.ItemIndex = SPI_CMD_95 then
      WriteFlash95(RomF, Hex2Dec('$'+StartAddressEdit.Text), MPHexEditorEx.DataSize, PageSize, StrToInt(ComboChipSize.Text));
    if ComboSPICMD.ItemIndex = SPI_CMD_45 then
      WriteFlash45(RomF, 0, MPHexEditorEx.DataSize, PageSize, WriteType);
    if ComboSPICMD.ItemIndex = SPI_CMD_KB then
      WriteFlashKB(RomF, 0, MPHexEditorEx.DataSize, PageSize);

    if (MenuAutoCheck.Checked) and (WriteType <> WT_PAGE) then
    begin
      LogPrint(STR_TIME + TimeToStr(Time() - TimeCounter));
      TimeCounter := Time();
      RomF.Position :=0;
      MPHexEditorEx.SaveToStream(RomF);
      RomF.Position :=0;
      if ComboSPICMD.ItemIndex <> SPI_CMD_KB then
        VerifyFlash25(RomF, Hex2Dec('$'+StartAddressEdit.Text), MPHexEditorEx.DataSize)
      else
        VerifyFlashKB(RomF, 0, MPHexEditorEx.DataSize);
    end;

  end;
  //I2C
  if RadioI2C.Checked then
  begin
    if ( (ComboAddrType.ItemIndex < 0) or (not IsNumber(ComboPageSize.Text)) ) then
    begin
      LogPrint(STR_CHECK_SETTINGS);
      Exit;
    end;

    EnterProgModeI2C();

    //แอดเดรสของชิปตามช่องติ๊ก
    I2C_DevAddr := SetI2CDevAddr();

    if CheckBox_I2C_ByteRead.Checked then I2C_ChunkSize := 1;

    if UsbAspI2C_BUSY(I2C_DevAddr) then
    begin
      LogPrint(STR_I2C_NO_ANSWER);
      exit;
    end;
    TimeCounter := Time();

    RomF.Position := 0;
    MPHexEditorEx.SaveToStream(RomF);
    RomF.Position := 0;

    if StrToInt(ComboPageSize.Text) < 1 then ComboPageSize.Text := '1';

    WriteFlashI2C(RomF, Hex2Dec('$'+StartAddressEdit.Text), MPHexEditorEx.DataSize, StrToInt(ComboPageSize.Text), I2C_DevAddr);

    if MenuAutoCheck.Checked then
    begin
      if UsbAspI2C_BUSY(I2C_DevAddr) then
      begin
        LogPrint(STR_I2C_NO_ANSWER);
        exit;
      end;
      LogPrint(STR_TIME + TimeToStr(Time() - TimeCounter));

      TimeCounter := Time();

      RomF.Position :=0;
      MPHexEditorEx.SaveToStream(RomF);
      RomF.Position :=0;
      VerifyFlashI2C(RomF, Hex2Dec('$'+StartAddressEdit.Text), RomF.Size, I2C_ChunkSize, I2C_DevAddr);
    end;

  end;
  //Microwire
  if RadioMW.Checked then
  begin
    if (not IsNumber(ComboMWBitLen.Text)) then
    begin
      LogPrint(STR_CHECK_SETTINGS);
      Exit;
    end;

    AsProgrammer.Programmer.MWInit(SetSPISpeed(0));
    TimeCounter := Time();

    RomF.Position := 0;
    MPHexEditorEx.SaveToStream(RomF);
    RomF.Position := 0;

    WriteFlashMW(RomF, StrToInt(ComboMWBitLen.Text), 0, MPHexEditorEx.DataSize);

    if MenuAutoCheck.Checked then
    begin
      TimeCounter := Time();
      RomF.Position :=0;
      MPHexEditorEx.SaveToStream(RomF);
      RomF.Position :=0;
      VerifyFlashMW(RomF, StrToInt(ComboMWBitLen.Text), 0, StrToInt(ComboChipSize.Text));
    end;

  end;

  //เลื่อนตัวนับต่อเมื่อการเขียนทำจนจบจริง
  if ProdSettings.SNEnabled and (ButtonCancel.Tag = 0) then
    ProdSettings.SNValue := ProdSettings.SNValue + ProdSettings.SNStep;

  LogPrint(STR_TIME + TimeToStr(Time() - TimeCounter));

finally
  ExitProgMode25;
  AsProgrammer.Programmer.DevClose;
  UnlockControl();
end;
end;

procedure TMainForm.ButtonVerifyClick(Sender: TObject);
begin
  VerifyFlash(false);
end;

procedure TMainForm.VerifyFlash(BlankCheck: boolean = false);
var
  I2C_DevAddr: byte;
  I2C_ChunkSize: Word;
  i: Longword;
  BlankByte: byte;
begin
  I2C_ChunkSize := 65535;
try
  ButtonCancel.Tag := 0;
  if not OpenDevice() then exit;
  LockControl();

  if RunScriptFromFile(CurrentICParam.Script, 'verify') then Exit;

  LogPrint(TimeToStr(Time()));

  if not IsNumber(ComboChipSize.Text) then
  begin
    LogPrint(STR_CHECK_SETTINGS);
    Exit;
  end;

  if (MPHexEditorEx.DataSize > StrToInt(ComboChipSize.Text) - Hex2Dec('$'+StartAddressEdit.Text)) and (not BlankCheck) then
  begin
    LogPrint(STR_WRONG_FILE_SIZE);
    Exit;
  end;

  //SPI
  if RadioSPI.Checked then
  begin
    EnterProgMode25(SetSPISpeed(0), MainForm.MenuSendAB.Checked);
    TimeCounter := Time();

    RomF.Clear;
    if BlankCheck then
    begin
      if ComboSPICMD.ItemIndex = SPI_CMD_KB then
        BlankByte := $00
      else
        BlankByte := $FF;

      for i:=1 to StrToInt(ComboChipSize.Text) do
        RomF.WriteByte(BlankByte);
    end
    else
      MPHexEditorEx.SaveToStream(RomF);
    RomF.Position :=0;

    if ComboSPICMD.ItemIndex = SPI_CMD_KB then
      VerifyFlashKB(RomF, 0, RomF.Size);

    if ComboSPICMD.ItemIndex = SPI_CMD_25 then
      VerifyFlash25(RomF, Hex2Dec('$'+StartAddressEdit.Text), RomF.Size);

    if ComboSPICMD.ItemIndex = SPI_CMD_95 then
      VerifyFlash95(RomF, Hex2Dec('$'+StartAddressEdit.Text), RomF.Size, StrToInt(ComboChipSize.Text));

    if ComboSPICMD.ItemIndex = SPI_CMD_45 then
     begin
      if (not IsNumber(ComboPageSize.Text)) then
      begin
        LogPrint(STR_CHECK_SETTINGS);
        Exit;
      end;
      VerifyFlash45(RomF, 0, StrToInt(ComboPageSize.Text), RomF.Size);
    end;


  end;
  //I2C
  if RadioI2C.Checked then
  begin
    if ComboAddrType.ItemIndex < 0 then
    begin
      LogPrint(STR_CHECK_SETTINGS);
      Exit;
    end;

    EnterProgModeI2C();

    //แอดเดรสของชิปตามช่องติ๊ก
    I2C_DevAddr := SetI2CDevAddr();

    if CheckBox_I2C_ByteRead.Checked then I2C_ChunkSize := 1;

    if UsbAspI2C_BUSY(I2C_DevAddr) then
    begin
      LogPrint(STR_I2C_NO_ANSWER);
      exit;
    end;
    TimeCounter := Time();

    RomF.Clear;
    if BlankCheck then
    begin
      for i:=1 to StrToInt(ComboChipSize.Text) do
        RomF.WriteByte($FF);
    end
    else
      MPHexEditorEx.SaveToStream(RomF);
    RomF.Position :=0;

    VerifyFlashI2C(RomF, Hex2Dec('$'+StartAddressEdit.Text), RomF.Size, I2C_ChunkSize, I2C_DevAddr);
  end;

  //Microwire
  if RadioMW.Checked then
  begin
    if (not IsNumber(ComboMWBitLen.Text)) then
    begin
      LogPrint(STR_CHECK_SETTINGS);
      Exit;
    end;

    AsProgrammer.Programmer.MWInit(SetSPISpeed(0));
    TimeCounter := Time();

    RomF.Clear;
    if BlankCheck then
    begin
      for i:=1 to StrToInt(ComboChipSize.Text) do
        RomF.WriteByte($FF);
    end
    else
      MPHexEditorEx.SaveToStream(RomF);
    RomF.Position :=0;

    VerifyFlashMW(RomF, StrToInt(ComboMWBitLen.Text), 0, RomF.Size);
  end;

  LogPrint(STR_TIME + TimeToStr(Time() - TimeCounter));

finally
  ExitProgMode25;
  AsProgrammer.Programmer.DevClose;
  UnlockControl();
end;
end;

procedure TMainForm.ButtonBlockClick(Sender: TObject);
var
  sreg: byte;
  i: integer;
  s: string;
  SLreg: array[0..31] of byte;
begin
try
  ButtonCancel.Tag := 0;
  if not OpenDevice() then exit;
  sreg := 0;
  LockControl();

  if RunScriptFromFile(CurrentICParam.Script, 'unlock') then Exit;

  EnterProgMode25(SetSPISpeed(0), MainForm.MenuSendAB.Checked);

  if ComboSPICMD.ItemIndex = SPI_CMD_25 then
  begin
    UsbAsp25_ReadSR(sreg); //อ่าน register
    LogPrint(STR_OLD_SREG+IntToBin(sreg, 8)+'(0x'+(IntToHex(sreg, 2)+')'));

    sreg := 0;

    UsbAsp25_WREN(); //เปิดสิทธิ์เขียน
    UsbAsp25_WriteSR(sreg); //ล้างค่า register

    //รอจนกว่าชิปจะพร้อม
    if not WaitNotBusy25(BUSY_TIMEOUT_SECTOR) then Exit;

    UsbAsp25_ReadSR(sreg); //อ่าน register
    LogPrint(STR_NEW_SREG+IntToBin(sreg, 8)+'(0x'+(IntToHex(sreg, 2)+')'));
  end;

  if ComboSPICMD.ItemIndex = SPI_CMD_95 then
  begin
    UsbAsp95_ReadSR(sreg); //อ่าน register
    LogPrint(STR_OLD_SREG+IntToBin(sreg, 8));

    sreg := 0; //
    UsbAsp95_WREN(); //เปิดสิทธิ์เขียน
    UsbAsp95_WriteSR(sreg); //ล้างค่า register

    //รอจนกว่าชิปจะพร้อม
    if not WaitNotBusy25(BUSY_TIMEOUT_SECTOR) then Exit;

    UsbAsp95_ReadSR(sreg); //อ่าน register
    LogPrint(STR_NEW_SREG+IntToBin(sreg, 8));
  end;

  if ComboSPICMD.ItemIndex = SPI_CMD_45 then
  begin
    UsbAsp45_DisableSP();
    UsbAsp45_ReadSR(sreg); //อ่าน register
    LogPrint('Sreg: '+IntToBin(sreg, 8));

    UsbAsp45_ReadSectorLockdown(SLreg); //อ่าน Lockdown register

    s := '';
    for i:=0 to 31 do
    begin
      s := s + IntToHex(SLreg[i], 2);
    end;
    LogPrint('Sector Lockdown register: 0x'+s);
    if UsbAsp45_isPagePowerOfTwo() then LogPrint(STR_45PAGE_POWEROF2)
      else LogPrint(STR_45PAGE_STD);

  end;


finally
  ExitProgMode25;
  AsProgrammer.Programmer.DevClose;
  UnlockControl();
end;

end;

procedure TMainForm.ButtonReadIDClick(Sender: TObject);
var
  XMLfile: TXMLDocument;
  ID: MEMORY_ID;
  IDstr9FH: string[6];
  IDstr90H: string[4];
  IDstrABH: string[6];
  IDstr15H: string[4];
  Matches: TStringList;
  Vendor, ChipName: string;
  Info: TSFDPInfo;
  SfdpOK: boolean;
begin
  try
    if not OpenDevice() then exit;
    LockControl();

    FillByte(ID.ID9FH, 3, $FF);
    FillByte(ID.ID90H, 2, $FF);
    FillByte(ID.IDABH, 1, $FF);
    FillByte(ID.ID15H, 2, $FF);

    EnterProgMode25(SetSPISpeed(0), MainForm.MenuSendAB.Checked);

    if ComboSPICMD.ItemIndex = SPI_CMD_KB then
    begin
      UsbAspMulti_EnableEDI();
      UsbAspMulti_EnableEDI();
      UsbAspMulti_ReadReg($FF00, ID.IDABH); //อ่านเวอร์ชันฮาร์ดแวร์ของ EC
      LogPrint('KB9012 EC Hardware version: '+IntToHex(ID.IDABH, 2));
      UsbAspMulti_ReadReg($FF24, ID.IDABH); //อ่านเวอร์ชัน EDI
      LogPrint('KB9012 EDI version: '+IntToHex(ID.IDABH, 2));
      ExitProgMode25;
      Exit;
    end;

    UsbAsp25_ReadID(ID);

    //อ่าน SFDP ตอนที่ยังอยู่ในโหมดโปรแกรม เผื่อชิปไม่มีในฐานข้อมูล
    SfdpOK := SFDPDetect(Info);

    ExitProgMode25;
    AsProgrammer.Programmer.DevClose;

    IDstr9FH := Upcase(IntToHex(ID.ID9FH[0], 2)+IntToHex(ID.ID9FH[1], 2)+IntToHex(ID.ID9FH[2], 2));
    IDstr90H := Upcase(IntToHex(ID.ID90H[0], 2)+IntToHex(ID.ID90H[1], 2));
    IDstrABH := Upcase(IntToHex(ID.IDABH, 2));
    IDstr15H := Upcase(IntToHex(ID.ID15H[0], 2)+IntToHex(ID.ID15H[1], 2));

    LogPrint('ID(9F): '+ IDstr9FH);
    LogPrint('ID(90): '+ IDstr90H);
    LogPrint('ID(AB): '+ IDstrABH);
    LogPrint('ID(15): '+ IDstr15H);

    //ทั้ง 00 หรือทั้ง FF แปลว่าไม่มีชิปตอบกลับ ไม่ต้องไปค้นฐานข้อมูลให้เสียเวลา
    if IsDeadID(ID.ID9FH) then
    begin
      LogPrint(STR_NO_CHIP);
      Exit;
    end;

    Vendor := JedecVendor(ID.ID9FH[0]);
    if Vendor <> '' then LogPrint(STR_VENDOR + Vendor);

    Matches := TStringList.Create;
    try
      //ไล่จาก 9F ก่อน แล้วค่อยลองโอปโค้ดเก่ากว่าถ้ายังไม่เจอ
      //ค้นทั้งไฟล์หลักและไฟล์เสริมพร้อมกัน
      FindChipInto(ChipListFile, '', IDstr9FH, Matches);
      FindChipInto(ChipListFile2, '', IDstr9FH, Matches);

      if Matches.Count = 0 then
      begin
        FindChipInto(ChipListFile, '', IDstr90H, Matches);
        FindChipInto(ChipListFile2, '', IDstr90H, Matches);
      end;

      if Matches.Count = 0 then
      begin
        FindChipInto(ChipListFile, '', IDstrABH, Matches);
        FindChipInto(ChipListFile2, '', IDstrABH, Matches);
      end;

      if Matches.Count = 0 then
      begin
        FindChipInto(ChipListFile, '', IDstr15H, Matches);
        FindChipInto(ChipListFile2, '', IDstr15H, Matches);
      end;

      if Matches.Count = 1 then
      begin
        //ตรงตัวเดียว เลือกให้เลย ไม่ต้องให้ผู้ใช้มากดซ้ำ
        ChipName := Matches[0];
        ChipName := Copy(ChipName, 1, Pos(' (', ChipName) - 1);
        SelectChipAny(ChipName);
        LogPrint(STR_DETECT_ONE + ChipName);
      end
      else if Matches.Count > 1 then
      begin
        LogPrint(Format(STR_DETECT_MANY, [Matches.Count]));
        ChipSearchForm.EditSearch.Text := '';
        ChipSearchForm.ListBoxChips.Items.Assign(Matches);
        ChipSearchForm.Show;
      end
      else
      begin
        //ไม่มีในฐานข้อมูล ยังเหลือทาง SFDP ให้ลอง
        if SfdpOK then
        begin
          LogPrint(STR_DETECT_SFDP);
          ApplySFDPInfo(Info);
        end
        else
          LogPrint(STR_DETECT_NONE);
      end;
    finally
      Matches.Free;
    end;

  finally
    UnlockControl();
  end;

end;

procedure TMainForm.ButtonOpenHexClick(Sender: TObject);
var
  Stream: TMemoryStream;
  ChipSize: cardinal;
  BlankByte: byte;
  ErrMsg: string;
begin
  if not OpenDialog.Execute then Exit;

  //ไฟล์ไบนารีโหลดแบบเดิม ไม่ต้องผ่านบัฟเฟอร์กลาง
  if DetectFormat(OpenDialog.FileName) = ffBinary then
  begin
    MPHexEditorEx.LoadFromFile(OpenDialog.FileName);
    StatusBar.Panels.Items[2].Text := OpenDialog.FileName;
    Exit;
  end;

  //ไฟล์รูปแบบข้อความจะกางออกเป็นภาพเต็มขนาดชิป
  //ช่องว่างยังคงสถานะถูกลบไว้
  ChipSize := 0;
  if IsNumber(ComboChipSize.Text) then ChipSize := StrToInt(ComboChipSize.Text);

  if RadioSPI.Checked and (ComboSPICMD.ItemIndex = SPI_CMD_KB) then
    BlankByte := $00
  else
    BlankByte := $FF;

  Stream := TMemoryStream.Create;
  try
    if not LoadFirmware(OpenDialog.FileName, Stream, ChipSize, BlankByte, ErrMsg) then
    begin
      LogPrint(ErrMsg);
      Exit;
    end;

    if ErrMsg <> '' then LogPrint(ErrMsg);   //เป็นแค่คำเตือน ข้อมูลโหลดสำเร็จแล้ว

    Stream.Position := 0;
    MPHexEditorEx.LoadFromStream(Stream);
    StatusBar.Panels.Items[2].Text := OpenDialog.FileName;
    LogPrint(STR_FILE_LOADED + IntToStr(Stream.Size) + ' bytes');
  finally
    Stream.Free;
  end;
end;

procedure TMainForm.ButtonSaveHexClick(Sender: TObject);
var
  Stream: TMemoryStream;
  Fmt: TFwFormat;
  FileName, ErrMsg: string;
begin
  if not SaveDialog.Execute then Exit;

  FileName := SaveDialog.FileName;
  Fmt := DetectFormat(FileName);

  //ถ้าผู้ใช้ไม่พิมพ์นามสกุลมา ให้ดูรูปแบบจากตัวกรองที่เลือก
  if (Fmt = ffBinary) and (ExtractFileExt(FileName) = '') then
    case SaveDialog.FilterIndex of
      2: begin Fmt := ffIntelHex; FileName := FileName + '.hex'; end;
      3: begin Fmt := ffSRecord;  FileName := FileName + '.s19'; end;
    else
      FileName := FileName + '.bin';
    end;

  if Fmt = ffBinary then
  begin
    MPHexEditorEx.SaveToFile(FileName);
    StatusBar.Panels.Items[2].Text := FileName;
    Exit;
  end;

  Stream := TMemoryStream.Create;
  try
    MPHexEditorEx.SaveToStream(Stream);

    if not SaveFirmware(FileName, Stream, Fmt, ErrMsg) then
    begin
      LogPrint(ErrMsg);
      Exit;
    end;

    StatusBar.Panels.Items[2].Text := FileName;
    LogPrint(STR_FILE_SAVED + FileName);
  finally
    Stream.Free;
  end;
end;

//บันทึก log ลงไฟล์
procedure TMainForm.SaveLogMenuItemClick(Sender: TObject);
var
  Dlg: TSaveDialog;
begin
  Dlg := TSaveDialog.Create(nil);
  try
    Dlg.Filter := 'Text file|*.txt|All files|*.*';
    Dlg.DefaultExt := 'txt';
    Dlg.FileName := 'asprogrammer-log.txt';
    if Dlg.Execute then Log.Lines.SaveToFile(Dlg.FileName);
  finally
    Dlg.Free;
  end;
end;

//เติมค่าเดียวกันลงทั้งบัฟเฟอร์
procedure TMainForm.MenuFillBufferClick(Sender: TObject);
var
  s: string;
  Value: integer;
  Size: cardinal;
  Data: array of byte;
  Stream: TMemoryStream;
begin
  if OperationRunning then Exit;

  Size := 0;
  if IsNumber(ComboChipSize.Text) then Size := StrToInt(ComboChipSize.Text);
  if Size = 0 then Size := MPHexEditorEx.DataSize;

  if Size = 0 then
  begin
    LogPrint(STR_CHECK_SETTINGS);
    Exit;
  end;

  s := Trim(InputBox(STR_FILL_BUFFER, STR_FILL_VALUE_HEX, 'FF'));
  if s = '' then Exit;

  if not IsNumber('$' + s) then
  begin
    LogPrint(STR_SPECIFY_HEX);
    Exit;
  end;

  Value := StrToInt('$' + s) and $FF;

  SetLength(Data, Size);
  FillChar(Data[0], Size, byte(Value));

  Stream := TMemoryStream.Create;
  try
    Stream.WriteBuffer(Data[0], Size);
    Stream.Position := 0;
    MPHexEditorEx.LoadFromStream(Stream);
  finally
    Stream.Free;
  end;

  LogPrint(STR_FILL_BUFFER + ' 0x' + IntToHex(Value, 2) + ', ' +
           IntToStr(Size) + ' bytes');
end;

procedure TMainForm.MenuSaveProjectClick(Sender: TObject);
var
  Dlg: TSaveDialog;
begin
  if OperationRunning then Exit;

  Dlg := TSaveDialog.Create(nil);
  try
    Dlg.Filter := 'AsProgrammer project|*.apxproj|All files|*.*';
    Dlg.DefaultExt := 'apxproj';
    Dlg.Options := Dlg.Options + [ofOverwritePrompt];
    if CurrentICParam.Name <> '' then Dlg.FileName := CurrentICParam.Name + '.apxproj';

    if not Dlg.Execute then Exit;

    if SaveProjectFile(Dlg.FileName) then
    begin
      StatusBar.Panels.Items[2].Text := Dlg.FileName;
      LogPrint(STR_PROJECT_SAVED + Dlg.FileName);
    end
    else
      LogPrint(STR_PROJECT_FAILED);
  finally
    Dlg.Free;
  end;
end;

//เทียบไฟล์สองไฟล์ ไม่ต้องใช้ฮาร์ดแวร์เลย
//โหลดผ่านตัวอ่านเดียวกับเมนูเปิดไฟล์ จึงเทียบ .hex กับ .bin ข้ามรูปแบบกันได้
procedure TMainForm.MenuCompareFilesClick(Sender: TObject);
var
  Dlg: TOpenDialog;
  F1, F2: string;
  S1, S2: TMemoryStream;
  A, B: array of byte;
  Size: integer;
  ErrMsg: string;
begin
  if OperationRunning then Exit;

  Dlg := TOpenDialog.Create(nil);
  S1 := TMemoryStream.Create;
  S2 := TMemoryStream.Create;
  try
    Dlg.Filter := OpenDialog.Filter;
    Dlg.Options := Dlg.Options + [ofFileMustExist];

    Dlg.Title := STR_CMP_PICK_FIRST;
    if not Dlg.Execute then Exit;
    F1 := Dlg.FileName;

    Dlg.Title := STR_CMP_PICK_SECOND;
    if not Dlg.Execute then Exit;
    F2 := Dlg.FileName;

    //ขนาดชิปใช้เป็นกรอบตอนกางไฟล์ HEX ถ้าไม่ได้ตั้งไว้ก็ใช้ขนาดไฟล์เอง
    if not LoadFirmware(F1, S1, UIChipSize, $FF, ErrMsg) then
    begin
      LogPrint(ExtractFileName(F1) + ': ' + ErrMsg);
      Exit;
    end;
    if not LoadFirmware(F2, S2, UIChipSize, $FF, ErrMsg) then
    begin
      LogPrint(ExtractFileName(F2) + ': ' + ErrMsg);
      Exit;
    end;

    LogPrint(STR_CMP_FILES);
    LogPrint('  A: ' + ExtractFileName(F1) + '  ' + IntToStr(S1.Size) + ' bytes  CRC32=' +
             IntToHex(UpdateCRC32($FFFFFFFF, S1.Memory, S1.Size), 8));
    LogPrint('  B: ' + ExtractFileName(F2) + '  ' + IntToStr(S2.Size) + ' bytes  CRC32=' +
             IntToHex(UpdateCRC32($FFFFFFFF, S2.Memory, S2.Size), 8));

    //เทียบเท่าที่ยาวเท่ากัน ส่วนที่เกินรายงานแยก
    Size := S1.Size;
    if S2.Size < Size then Size := S2.Size;
    if Size = 0 then
    begin
      LogPrint(STR_CHECKSUM_EMPTY);
      Exit;
    end;

    if S1.Size <> S2.Size then
      LogPrint(STR_CMP_SIZE_DIFF + IntToStr(Abs(S1.Size - S2.Size)) + ' bytes');

    SetLength(A, Size);
    SetLength(B, Size);
    S1.Position := 0;  S1.ReadBuffer(A[0], Size);
    S2.Position := 0;  S2.ReadBuffer(B[0], Size);

    if ReportDiff(A, B, Size) > 0 then ShowDiffInEditor(A, B, Size);
  finally
    S1.Free;
    S2.Free;
    Dlg.Free;
  end;
end;

//เทียบชิปสองตัว อ่านตัวแรก ให้สลับชิป แล้วอ่านตัวที่สอง
procedure TMainForm.MenuCompareChipsClick(Sender: TObject);
var
  S1, S2: TMemoryStream;
  A, B: array of byte;
  Size: integer;
begin
  if OperationRunning then Exit;

  S1 := TMemoryStream.Create;
  S2 := TMemoryStream.Create;
try
  ButtonCancel.Tag := 0;
  if not OpenDevice() then Exit;
  LockControl();

  if OpUI.ChipSize = 0 then
  begin
    LogPrint(STR_CHECK_SETTINGS);
    Exit;
  end;
  Size := OpUI.ChipSize;

  LogPrint(STR_CMP_READ_FIRST);
  if not ReadCurrentChip(S1, cardinal(Size)) then Exit;

  ExitProgMode25;
  AsProgrammer.Programmer.DevClose;

  if MessageDlg('AsProgrammer', STR_CMP_SWAP, mtConfirmation, [mbOk, mbCancel], 0) <> mrOk then
  begin
    LogPrint(STR_USER_CANCEL);
    Exit;
  end;

  if not OpenDevice() then Exit;

  LogPrint(STR_CMP_READ_SECOND);
  if not ReadCurrentChip(S2, cardinal(Size)) then Exit;

  LogPrint('  A: ' + IntToStr(S1.Size) + ' bytes  CRC32=' +
           IntToHex(UpdateCRC32($FFFFFFFF, S1.Memory, S1.Size), 8));
  LogPrint('  B: ' + IntToStr(S2.Size) + ' bytes  CRC32=' +
           IntToHex(UpdateCRC32($FFFFFFFF, S2.Memory, S2.Size), 8));

  SetLength(A, Size);
  SetLength(B, Size);
  S1.Position := 0;  S1.ReadBuffer(A[0], Size);
  S2.Position := 0;  S2.ReadBuffer(B[0], Size);

  if ReportDiff(A, B, Size) > 0 then ShowDiffInEditor(A, B, Size);

finally
  ExitProgMode25;
  AsProgrammer.Programmer.DevClose;
  UnlockControl();
  S1.Free;
  S2.Free;
end;
end;

procedure TMainForm.MenuOpenProjectClick(Sender: TObject);
var
  Dlg: TOpenDialog;
  ErrMsg: string;
begin
  if OperationRunning then Exit;

  Dlg := TOpenDialog.Create(nil);
  try
    Dlg.Filter := 'AsProgrammer project|*.apxproj|All files|*.*';
    Dlg.Options := Dlg.Options + [ofFileMustExist];

    if not Dlg.Execute then Exit;

    if LoadProjectFile(Dlg.FileName, ErrMsg) then
    begin
      StatusBar.Panels.Items[2].Text := Dlg.FileName;
      LogPrint(STR_PROJECT_LOADED + Dlg.FileName);
    end
    else
      LogPrint(STR_PROJECT_FAILED + ' ' + ErrMsg);
  finally
    Dlg.Free;
  end;
end;

procedure TMainForm.MenuProdConfigClick(Sender: TObject);
begin
  if OperationRunning then Exit;
  if EditProdSettings(ProdSettings) then
    LogPrint(STR_PROD_SAVED);
end;

//การผลิตเป็นชุด: เขียนชิปทีละตัวแล้วนับผลลัพธ์
//แต่ละรอบคือ ปลดล็อก ลบ แล้วเขียนพร้อมตรวจสอบ
procedure TMainForm.MenuRunBatchClick(Sender: TObject);
var
  Done, Passed, Failed: integer;
  Reply: integer;
begin
  if OperationRunning then Exit;

  if MPHexEditorEx.DataSize = 0 then
  begin
    LogPrint(STR_ERASE_RANGE_EMPTY);
    Exit;
  end;

  if not ProdSettings.BatchEnabled then
  begin
    LogPrint(STR_BATCH_DISABLED);
    Exit;
  end;

  Done := 0;
  Passed := 0;
  Failed := 0;

  LogPrint(STR_BATCH_START + IntToStr(ProdSettings.BatchTarget));

  while Done < ProdSettings.BatchTarget do
  begin
    Reply := MessageDlg('AsProgrammer',
      Format(STR_BATCH_INSERT, [Done + 1, ProdSettings.BatchTarget]),
      mtConfirmation, [mbOk, mbCancel], 0);

    if Reply <> mrOk then Break;

    ButtonCancel.Tag := 0;

    if ButtonBlock.Enabled then ButtonBlockClick(ComboItem1);
    if ButtonCancel.Tag = 0 then ButtonEraseClick(ComboItem1);
    if ButtonCancel.Tag = 0 then ButtonWriteClick(ComboItem1);

    Inc(Done);

    //การยกเลิกหรือข้อผิดพลาดจะตั้งค่า Tag ไว้ ไม่มีรหัสผลลัพธ์แยกต่างหาก
    if ButtonCancel.Tag <> 0 then
    begin
      Inc(Failed);
      LogPrint(Format(STR_BATCH_UNIT_FAIL, [Done]));
    end
    else
    begin
      Inc(Passed);
      LogPrint(Format(STR_BATCH_UNIT_OK, [Done]));
    end;
  end;

  LogPrint(Format(STR_BATCH_SUMMARY, [Done, Passed, Failed]));
end;

//เลขประจำตัวชิปและ security register (OTP)
//security register ล็อกถาวรได้ การเขียนจึงต้องผ่านการยืนยัน
//และโค้ดนี้ไม่แตะบิตล็อกเลย
//วาดตัวชิปตามโปรโตคอลที่เลือก พร้อมชื่อขา และไฟบอกสถานะข้างล่าง
//ชื่อขาใช้เป็นแผนผังต่อสายได้เลย ซึ่งเป็นสิ่งที่ต้องเปิดดาต้าชีตหาทุกครั้ง
procedure TMainForm.ChipViewPaint(Sender: TObject);
const
  PinsSPI: array[0..7] of string = ('CS', 'DO', 'WP', 'GND', 'DI', 'CLK', 'HOLD', 'VCC');
  PinsI2C: array[0..7] of string = ('A0', 'A1', 'A2', 'GND', 'SDA', 'SCL', 'WP', 'VCC');
  PinsMW:  array[0..7] of string = ('CS', 'CLK', 'DI', 'DO', 'GND', 'ORG', 'NC', 'VCC');
  BodyW = 74;
  PinW = 15;
  PinH = 7;
var
  C: TCanvas;
  Pins: array[0..7] of string;
  Dark: boolean;
  ColText, ColDim, ColBody, ColEdge, ColPin, ColAccent: TColor;
  BodyL, BodyT, BodyH, Pitch, i, py, ledY, Avail: integer;
  s: string;

  procedure Led(ATop: integer; const ACaption, AValue: string; AOn: boolean);
  begin
    if AOn then C.Brush.Color := TColor($5B9E2E)   //#2E9E5B
    else        C.Brush.Color := ColDim;
    C.Pen.Color := C.Brush.Color;
    C.Ellipse(4, ATop, 15, ATop + 11);

    C.Brush.Style := bsClear;
    C.Font.Color := ColText;
    C.TextOut(22, ATop - 2, ACaption);
    C.Font.Color := ColDim;
    C.TextOut(22 + C.TextWidth(ACaption) + 6, ATop - 2, AValue);
    C.Brush.Style := bsSolid;
  end;

begin
  C := ChipView.Canvas;
  Dark := MenuDarkTheme.Checked;

  if Dark then
  begin
    ColText   := TColor($D9D1C9);
    ColDim    := TColor($8E8578);
    ColBody   := TColor($241F1B);
    ColEdge   := TColor($6E6055);
    ColPin    := TColor($B8AFA4);
    ColAccent := TColor($F3B32B);
    C.Brush.Color := TColor($241F1B);
  end
  else
  begin
    ColText   := TColor($33291F);
    ColDim    := TColor($9A8E80);
    ColBody   := TColor($3A322C);
    ColEdge   := TColor($6E6055);
    ColPin    := TColor($9A9186);
    ColAccent := TColor($D16E0A);
    C.Brush.Color := TColor($F7F4F2);
  end;

  C.FillRect(0, 0, ChipView.Width, ChipView.Height);
  C.Font.Name := 'Segoe UI';
  C.Font.Size := 7;

  //ชื่อขาขึ้นกับโปรโตคอลที่กำลังใช้
  //คัดลอกทีละตัว ห้ามใช้ Move เพราะสตริงมีตัวนับอ้างอิงอยู่
  for i := 0 to 7 do
    if RadioI2C.Checked then Pins[i] := PinsI2C[i]
    else if RadioMw.Checked then Pins[i] := PinsMW[i]
    else Pins[i] := PinsSPI[i];

  BodyL := (ChipView.Width - BodyW) div 2;

  //ไฟสถานะไว้บนสุด เป็นสิ่งที่ต้องเหลือบดูบ่อยที่สุด และไม่มีวันตกขอบล่าง
  ledY := 4;
  C.Font.Size := 8;

  if ProgrammerPresent then
    s := AsProgrammer.Programmer.HardwareName
  else
    s := '';
  Led(ledY, STR_LED_PROGRAMMER, s, ProgrammerPresent);

  if ChipDetected then s := CurrentICParam.ID else s := '';
  Led(ledY + 21, STR_LED_CHIP, s, ChipDetected);

  C.Font.Size := 7;

  //ที่เหลือใต้ไฟสถานะเป็นของรูปชิป ย่อขยายตามพื้นที่จริงเพื่อไม่ให้ล้นขอบ
  Avail := ChipView.Height - 50;
  if Avail < 60 then Exit;    //เตี้ยเกินกว่าจะวาดอะไรได้

  BodyH := Avail - 12;
  if BodyH > 112 then BodyH := 112;
  BodyT := 50 + (Avail - BodyH) div 2;
  Pitch := BodyH div 4;

  //ขาชิป ซ้ายนับ 1-4 จากบนลงล่าง ขวานับ 5-8 จากล่างขึ้นบน ตามมาตรฐาน
  C.Brush.Color := ColPin;
  C.Pen.Color := ColEdge;
  for i := 0 to 3 do
  begin
    py := BodyT + (Pitch - PinH) div 2 + i * Pitch;
    C.Rectangle(BodyL - PinW, py, BodyL, py + PinH);
    C.Rectangle(BodyL + BodyW, py, BodyL + BodyW + PinW, py + PinH);
  end;

  //ตัวถัง
  C.Brush.Color := ColBody;
  C.Pen.Color := ColEdge;
  C.RoundRect(BodyL, BodyT, BodyL + BodyW, BodyT + BodyH, 6, 6);

  //จุดบอกขา 1
  C.Brush.Color := ColAccent;
  C.Pen.Color := ColAccent;
  C.Ellipse(BodyL + 7, BodyT + 8, BodyL + 15, BodyT + 16);

  //ชื่อรุ่นบนตัวถัง ตัดถ้ายาวเกินความกว้าง
  C.Brush.Style := bsClear;
  C.Font.Color := TColor($E8E2DA);
  s := CurrentICParam.Name;
  if s = '' then s := STR_PKG_UNKNOWN;
  while (s <> '') and (C.TextWidth(s) > BodyW - 8) do Delete(s, Length(s), 1);
  C.TextOut(BodyL + (BodyW - C.TextWidth(s)) div 2, BodyT + BodyH div 2 - 6, s);

  //ชื่อขา ฝั่งซ้ายชิดขวา ฝั่งขวาชิดซ้าย
  C.Font.Color := ColText;
  for i := 0 to 3 do
  begin
    py := BodyT + (Pitch - PinH) div 2 + i * Pitch - 3;

    s := IntToStr(i + 1) + ' ' + Pins[i];
    C.TextOut(BodyL - PinW - 4 - C.TextWidth(s), py, s);

    s := Pins[7 - i] + ' ' + IntToStr(8 - i);
    C.TextOut(BodyL + BodyW + PinW + 4, py, s);
  end;

end;

procedure TMainForm.HwTimerTimer(Sender: TObject);
begin
  PollProgrammer(False);
end;

//อธิบายบิตป้องกันการเขียนเป็นภาษาคน พร้อมบอกว่าช่วงไหนของชิปถูกล็อกอยู่
//ของเดิมมีแต่ให้ดู SREG เป็นเลขฐานสอง ซึ่งต้องเปิดดาต้าชีตแปลเอง
procedure TMainForm.MenuProtInfoClick(Sender: TObject);
var
  SR1, SR2: byte;
  P: TProtInfo;
  FromA, ToA: cardinal;
begin
  if OperationRunning then Exit;

  if (not RadioSPI.Checked) or (ComboSPICMD.ItemIndex <> SPI_CMD_25) then
  begin
    LogPrint(STR_SECTOR_SPI25_ONLY);
    Exit;
  end;

try
  ButtonCancel.Tag := 0;
  if not OpenDevice() then Exit;
  LockControl();

  EnterProgMode25(SetSPISpeed(0), MenuSendAB.Checked);

  SR1 := 0;
  SR2 := 0;
  UsbAsp25_ReadSR(SR1, $05);
  UsbAsp25_ReadSR(SR2, $35);

  LogPrint(Format(STR_PROT_HEADER, [SR1, SR2]));
  LogPrint(ProtToText(DecodeProt(SR1, SR2)));

  P := DecodeProt(SR1, SR2);
  if ProtectedRange(P, OpUI.ChipSize, FromA, ToA) then
    LogPrint(Format(STR_PROT_RANGE, [FromA, ToA, (ToA - FromA + 1) div 1024]))
  else
    LogPrint(STR_PROT_NONE);

  LogPrint(STR_PROT_CAVEAT);

finally
  ExitProgMode25;
  AsProgrammer.Programmer.DevClose;
  UnlockControl();
end;
end;

//เขียนหรือลบ security register (OTP)
//หน้าเหล่านี้ล็อกถาวรได้ จึงต้องยืนยันสองชั้น และโค้ดนี้ไม่แตะบิตล็อกเลย
procedure TMainForm.MenuSecRegWriteClick(Sender: TObject);
const
  SecRegAddr: array[0..2] of longword = ($001000, $002000, $003000);
var
  s: string;
  RegNo: integer;
  Data: array[0..255] of byte;
  Stream: TMemoryStream;
  Erase: boolean;
begin
  if OperationRunning then Exit;

  if (not RadioSPI.Checked) or (ComboSPICMD.ItemIndex <> SPI_CMD_25) then
  begin
    LogPrint(STR_SECTOR_SPI25_ONLY);
    Exit;
  end;

  s := Trim(InputBox(STR_OTP_TITLE, STR_OTP_WHICH, '1'));
  if (s = '') or (not IsNumber(s)) then Exit;
  RegNo := StrToInt(s);
  if (RegNo < 1) or (RegNo > 3) then Exit;

  Erase := MessageDlg(STR_OTP_TITLE, STR_OTP_ERASE_Q, mtConfirmation,
                      [mbYes, mbNo], 0) = mrYes;

  if (not Erase) and (MPHexEditorEx.DataSize < 256) then
  begin
    LogPrint(STR_OTP_NEED_256);
    Exit;
  end;

  if MessageDlg(STR_OTP_TITLE, Format(STR_OTP_CONFIRM, [RegNo]),
                mtWarning, [mbYes, mbNo], 0) <> mrYes then Exit;

try
  ButtonCancel.Tag := 0;
  if not OpenDevice() then Exit;
  LockControl();

  EnterProgMode25(SetSPISpeed(0), MenuSendAB.Checked);

  if not VerifyChipID then Exit;

  if Erase then
  begin
    LogPrint(Format(STR_OTP_ERASING, [RegNo]));
    UsbAsp25_WREN();
    UsbAsp25_EraseSecReg(SecRegAddr[RegNo - 1]);
    if not WaitNotBusy25(BUSY_TIMEOUT_SECTOR) then Exit;
  end
  else
  begin
    //256 ไบต์แรกของเอดิเตอร์คือข้อมูลที่จะเขียนลงหน้านั้น
    Stream := TMemoryStream.Create;
    try
      MPHexEditorEx.SaveToStream(Stream);
      Stream.Position := 0;
      Stream.ReadBuffer(Data[0], 256);
    finally
      Stream.Free;
    end;

    LogPrint(Format(STR_OTP_WRITING, [RegNo]));
    UsbAsp25_WREN();
    UsbAsp25_WriteSecReg(SecRegAddr[RegNo - 1], Data, 256);
    if not WaitNotBusy25(BUSY_TIMEOUT_PAGE) then Exit;
  end;

  UsbAsp25_Wrdi();
  LogPrint(STR_DONE);

finally
  ExitProgMode25;
  AsProgrammer.Programmer.DevClose;
  UnlockControl();
end;
end;

procedure TMainForm.MenuSecRegClick(Sender: TObject);
const
  SecRegAddr: array[0..2] of longword = ($001000, $002000, $003000);
var
  UID: array[0..7] of byte;
  Auth: array[0..48] of byte;
  Reg: array[0..255] of byte;
  i, j, k: integer;
  s: string;
  Blank: boolean;
begin
  if OperationRunning then Exit;

  if (not RadioSPI.Checked) or (ComboSPICMD.ItemIndex <> SPI_CMD_25) then
  begin
    LogPrint(STR_SECTOR_SPI25_ONLY);
    Exit;
  end;

try
  ButtonCancel.Tag := 0;
  if not OpenDevice() then Exit;
  LockControl();

  EnterProgMode25(SetSPISpeed(0), MenuSendAB.Checked);

  //เลขประจำตัว opcode 4Bh
  FillByte(UID, SizeOf(UID), $FF);
  UsbAsp25_ReadUniqueID(UID);

  s := '';
  for i := 0 to 7 do s := s + IntToHex(UID[i], 2);
  LogPrint(STR_UNIQUE_ID + s);

  //W74M Authentication Flash: คำสั่งเดียวของตระกูลนี้ที่ไม่ต้องมีลายเซ็น HMAC
  //คำสั่งอื่น (9Bh) ทั้งหมดใช้ไม่ได้ถ้าไม่มี root key
  FillByte(Auth, SizeOf(Auth), $FF);
  UsbAsp25_ReadAuthStatus(Auth, SizeOf(Auth));

  //ถ้าได้ FF ทุกไบต์ แปลว่าชิปไม่เข้าใจคำสั่งนี้
  Blank := True;
  for i := 0 to High(Auth) do
    if Auth[i] <> $FF then
    begin
      Blank := False;
      Break;
    end;

  if Blank then
    LogPrint(STR_AUTH_NOT_SUPPORTED)
  else
  begin
    LogPrint(STR_AUTH_STATUS + IntToHex(Auth[0], 2) +
             ' (bit0 busy=' + IntToStr(Auth[0] and 1) + ')');

    s := '';
    for i := 13 to 16 do s := s + IntToHex(Auth[i], 2);
    LogPrint(STR_AUTH_COUNTER + s);
    LogPrint(STR_AUTH_NEEDS_KEY);
  end;

  //security register สามหน้า หน้าละ 256 ไบต์
  for i := 0 to 2 do
  begin
    FillByte(Reg, SizeOf(Reg), $FF);
    UsbAsp25_ReadSecReg(SecRegAddr[i], Reg, SizeOf(Reg));

    Blank := True;
    for j := 0 to 255 do
      if Reg[j] <> $FF then
      begin
        Blank := False;
        Break;
      end;

    if Blank then
      LogPrint(Format(STR_SECREG_BLANK, [i + 1, SecRegAddr[i]]))
    else
    begin
      LogPrint(Format(STR_SECREG_HEADER, [i + 1, SecRegAddr[i]]));

      //พิมพ์บรรทัดละ 16 ไบต์ ให้เหมือนใน hex editor
      for j := 0 to 15 do
      begin
        s := '  ' + IntToHex(j * 16, 4) + ': ';
        for k := 0 to 15 do
          s := s + IntToHex(Reg[j * 16 + k], 2) + ' ';
        LogPrint(s);
      end;
    end;
  end;

finally
  ExitProgMode25;
  AsProgrammer.Programmer.DevClose;
  UnlockControl();
end;
end;

//สลับไบต์ในคำขนาด 16 บิต ใช้กับภาพข้อมูลที่ดึงมาจากบัสที่
//เรียงไบต์กลับด้าน
procedure TMainForm.MenuSwapBytesClick(Sender: TObject);
var
  Stream: TMemoryStream;
  Data: array of byte;
  i, Size: integer;
  t: byte;
begin
  if OperationRunning then Exit;

  Size := MPHexEditorEx.DataSize;
  if Size < 2 then
  begin
    LogPrint(STR_CHECKSUM_EMPTY);
    Exit;
  end;

  Stream := TMemoryStream.Create;
  try
    MPHexEditorEx.SaveToStream(Stream);
    Stream.Position := 0;
    SetLength(Data, Size);
    Stream.ReadBuffer(Data[0], Size);

    i := 0;
    while i + 1 < Size do
    begin
      t := Data[i];
      Data[i] := Data[i + 1];
      Data[i + 1] := t;
      Inc(i, 2);
    end;

    Stream.Clear;
    Stream.WriteBuffer(Data[0], Size);
    Stream.Position := 0;
    MPHexEditorEx.LoadFromStream(Stream);
  finally
    Stream.Free;
  end;

  LogPrint(STR_SWAP_DONE + IntToStr(Size div 2));
end;

//รายงานความต่างระหว่างข้อมูลสองชุด เป็นช่วง ๆ พร้อมยอดรวม
//ใช้ร่วมกันทั้งการเทียบกับชิป เทียบไฟล์ และเทียบชิปสองตัว
function ReportDiff(const A, B: array of byte; Size: integer): integer;
var
  i, DiffCount, RangeCount, RangeStart: integer;
  InRange: boolean;
begin
  DiffCount := 0;
  RangeCount := 0;
  InRange := False;
  RangeStart := 0;

  for i := 0 to Size - 1 do
  begin
    if A[i] <> B[i] then
    begin
      Inc(DiffCount);
      if not InRange then
      begin
        InRange := True;
        RangeStart := i;
        Inc(RangeCount);
        if RangeCount = 1 then LogPrint(STR_COMPARE_RANGES);
      end;
    end
    else
      if InRange then
      begin
        InRange := False;
        if RangeCount <= 20 then
          LogPrint('  0x' + IntToHex(RangeStart, 8) + ' - 0x' + IntToHex(i - 1, 8) +
                   '  (' + IntToStr(i - RangeStart) + ' bytes)');
      end;
  end;

  if InRange and (RangeCount <= 20) then
    LogPrint('  0x' + IntToHex(RangeStart, 8) + ' - 0x' + IntToHex(Size - 1, 8) +
             '  (' + IntToStr(Size - RangeStart) + ' bytes)');

  if DiffCount = 0 then
    LogPrint(STR_COMPARE_EQUAL)
  else
    LogPrint(STR_COMPARE_DIFF + IntToStr(DiffCount) + ' / ' + IntToStr(Size) +
             ',  ranges: ' + IntToStr(RangeCount));

  //ผลลัพธ์ต้องเด้งให้เห็น ไม่ใช่ซ่อนอยู่ในบรรทัดล่างสุดของ log
  if DiffCount = 0 then
    ShowMessage(STR_COMPARE_EQUAL)
  else
    ShowMessage(STR_COMPARE_DIFF + IntToStr(DiffCount) + ' / ' + IntToStr(Size) +
                LineEnding + 'Ranges: ' + IntToStr(RangeCount) +
                LineEnding + LineEnding + STR_COMPARE_SEE_LOG);

  Result := DiffCount;
end;

//แสดงผลต่างในตารางกลาง
//โหลดข้อมูลฝั่ง B ลงตาราง แล้วทำเครื่องหมายไบต์ที่ต่างจากฝั่ง A ว่า "เปลี่ยนแล้ว"
//MPHexEditor จะระบายสีไบต์ที่มีเครื่องหมายนี้ด้วย ChangedText/ChangedBackground
//ทำเครื่องหมายตรง ๆ ผ่าน ByteChanged ไม่เขียนทับข้อมูลทีละไบต์ เพราะการเขียน
//ไม่ได้ตั้งบิตนี้ให้ แถมยังสร้างรายการ undo ทีละไบต์จนช้า
procedure ShowDiffInEditor(const A, B: array of byte; Size: integer);
var
  S: TMemoryStream;
  i, FirstDiff: integer;
begin
  S := TMemoryStream.Create;
  try
    S.WriteBuffer(B[0], Size);
    S.Position := 0;
    MainForm.MPHexEditorEx.LoadFromStream(S);
  finally
    S.Free;
  end;

  FirstDiff := -1;

  for i := 0 to Size - 1 do
    if A[i] <> B[i] then
    begin
      if FirstDiff < 0 then FirstDiff := i;
      MainForm.MPHexEditorEx.ByteChanged[i] := True;
    end;

  //พาเคอร์เซอร์ไปจุดแรกที่ต่างกัน จะได้ไม่ต้องไล่หาเอง
  if FirstDiff >= 0 then
  begin
    MainForm.MPHexEditorEx.SelStart := FirstDiff;
    MainForm.MPHexEditorEx.SelEnd := FirstDiff;
  end;

  MainForm.MPHexEditorEx.Invalidate;
  MainForm.MPHexEditorExChange(MainForm);
  LogPrint(STR_DIFF_IN_EDITOR);
end;

//ขนาดชิปที่ตั้งไว้บนหน้าจอ อ่านสด ไม่ผ่าน OpUI ซึ่งมีค่าเฉพาะหลังเริ่มงานแล้ว
function UIChipSize: cardinal;
begin
  Result := 0;
  if IsNumber(MainForm.ComboChipSize.Text) then
    Result := StrToInt(MainForm.ComboChipSize.Text);
end;

//อ่านชิปด้วยวิธีของโปรโตคอลที่กำลังใช้อยู่
//ผู้เรียกต้องเปิดอุปกรณ์และล็อกหน้าจอมาก่อนแล้ว
function ReadCurrentChip(Stream: TMemoryStream; Size: cardinal): boolean;
var
  I2C_DevAddr: byte;
  I2C_ChunkSize: Word;
begin
  Result := False;
  I2C_ChunkSize := 65535;

  if MainForm.RadioI2C.Checked then
  begin
    if MainForm.ComboAddrType.ItemIndex < 0 then
    begin
      LogPrint(STR_CHECK_SETTINGS);
      Exit;
    end;

    EnterProgModeI2C();
    I2C_DevAddr := SetI2CDevAddr();

    if UsbAspI2C_BUSY(I2C_DevAddr) then
    begin
      LogPrint(STR_I2C_NO_ANSWER);
      Exit;
    end;

    if MainForm.CheckBox_I2C_ByteRead.Checked then I2C_ChunkSize := 1;
    ReadFlashI2C(Stream, 0, Size, I2C_ChunkSize, I2C_DevAddr);
  end
  else if MainForm.RadioMw.Checked then
  begin
    if not IsNumber(MainForm.ComboMWBitLen.Text) then
    begin
      LogPrint(STR_CHECK_SETTINGS);
      Exit;
    end;

    AsProgrammer.Programmer.MWInit(SetSPISpeed(0));
    ReadFlashMW(Stream, StrToInt(MainForm.ComboMWBitLen.Text), 0, Size);
  end
  else
  begin
    EnterProgMode25(SetSPISpeed(0), MainForm.MenuSendAB.Checked);

    case MainForm.ComboSPICMD.ItemIndex of
      SPI_CMD_95: ReadFlash95(Stream, 0, Size);
      SPI_CMD_45:
        begin
          if not IsNumber(MainForm.ComboPageSize.Text) then
          begin
            LogPrint(STR_CHECK_SETTINGS);
            Exit;
          end;
          ReadFlash45(Stream, 0, StrToInt(MainForm.ComboPageSize.Text), Size);
        end;
      SPI_CMD_KB: ReadFlashKB(Stream, 0, Size);
    else
      ReadFlash25(Stream, 0, Size);
    end;
  end;

  Result := Stream.Size >= Int64(Size);
end;

//เทียบบัฟเฟอร์กับเนื้อหาในชิปแล้วรายงานเป็นช่วง ๆ
//ต่างจาก verify ตรงที่ verify จะหยุดที่จุดแรกที่ไม่ตรง
procedure TMainForm.MenuCompareChipClick(Sender: TObject);
var
  ChipData, BufStream: TMemoryStream;
  A, B: array of byte;
  Size: integer;
begin
  if OperationRunning then Exit;

  if MPHexEditorEx.DataSize = 0 then
  begin
    LogPrint(STR_CHECKSUM_EMPTY);
    Exit;
  end;

  ChipData := TMemoryStream.Create;
  BufStream := TMemoryStream.Create;
try
  ButtonCancel.Tag := 0;
  if not OpenDevice() then Exit;
  LockControl();

  if OpUI.ChipSize = 0 then
  begin
    LogPrint(STR_CHECK_SETTINGS);
    Exit;
  end;

  Size := MPHexEditorEx.DataSize;
  if cardinal(Size) > OpUI.ChipSize then Size := OpUI.ChipSize;

  LogPrint(STR_COMPARE_READING);
  TimeCounter := Time();

  if not ReadCurrentChip(ChipData, cardinal(Size)) then Exit;

  MPHexEditorEx.SaveToStream(BufStream);

  SetLength(A, Size);
  SetLength(B, Size);
  ChipData.Position := 0;   ChipData.ReadBuffer(A[0], Size);
  BufStream.Position := 0;  BufStream.ReadBuffer(B[0], Size);

  if ReportDiff(A, B, Size) > 0 then ShowDiffInEditor(A, B, Size);
  LogPrint(STR_TIME + TimeToStr(Time() - TimeCounter));

finally
  ExitProgMode25;
  AsProgrammer.Programmer.DevClose;
  UnlockControl();
  ChipData.Free;
  BufStream.Free;
end;
end;

procedure TMainForm.ButtonCancelClick(Sender: TObject);
begin
  ButtonCancel.Tag:= 1;
  ScriptEngine.Stop:= true;
end;

procedure TMainForm.I2C_DevAddrChange(Sender: TObject);
begin
  if TToggleBox(Sender).State = cbUnchecked then
  TToggleBox(Sender).Caption:= '0';
  if TToggleBox(Sender).State = cbChecked then
  TToggleBox(Sender).Caption:= '1';
end;

procedure TMainForm.ScriptsMenuItemClick(Sender: TObject);
begin
  ScriptEditForm.Show;
end;

procedure TMainForm.DebugconsoleMenuItemClick(Sender: TObject);
begin
     ExecuteProcess('cmd.exe', '/c start tail -F buzzpirathlp.log', []);
end;

procedure TMainForm.BzHelpMenuItemClick(Sender: TObject);
begin
     ExecuteProcess('cmd.exe', '/c start https://github.com/therealdreg/asprogrammer-dregmod', []);
end;

//นับจำนวนชิปในไฟล์ฐานข้อมูล ใช้โชว์ในหน้าต่างข้อมูลรุ่น
function CountChips(XMLfile: TXMLDocument): integer;
var
  Node: TDOMNode;
  j, i: integer;
begin
  Result := 0;
  if XMLfile = nil then Exit;

  Node := XMLfile.DocumentElement.FirstChild;
  while Assigned(Node) do
  begin
    with Node.ChildNodes do
    try
      for j := 0 to Count - 1 do
        for i := 0 to Item[j].ChildNodes.Count - 1 do
          if Item[j].ChildNodes.Item[i].HasAttributes then
            if Item[j].ChildNodes.Item[i].Attributes.GetNamedItem('size') <> nil then
              Inc(Result);
    finally
      Free;
    end;
    Node := Node.NextSibling;
  end;
end;

//หน้าต่างข้อมูลรุ่น สร้างด้วยโค้ดและใส่ข้อความไว้ใน memo
//ผู้ใช้จะได้เลือกคัดลอกไปแปะตอนแจ้งปัญหาได้เลย
procedure ShowVersionDialog(ShowCredits: boolean);
var
  F: TForm;
  M: TMemo;
  BtnClose, BtnCopy: TButton;
  s: TStringList;
  ExeName: string;
begin
  s := TStringList.Create;
  try
    ExeName := Application.ExeName;

    if ShowCredits then
    begin
      s.Add('AsProgrammer ProX is built on the work of:');
      s.Add('');
      s.Add('  nofeletru');
      s.Add('    AsProgrammer / UsbAsp-flash, the original program');
      s.Add('    https://github.com/nofeletru/UsbAsp-flash');
      s.Add('');
      s.Add('  Dreg  @therealdreg');
      s.Add('    the dregmod fork and its Buzzpirat / Bus Pirate support');
      s.Add('    https://github.com/therealdreg/asprogrammer-dregmod');
      s.Add('');
      s.Add('  Ian Lesnet');
      s.Add('    creator of the Bus Pirate');
      s.Add('    https://buspirate.com/');
      s.Add('');
      s.Add('  Floyd77');
      s.Add('    the method for adding an unknown chip to the database');
      s.Add('');
      s.Add('  the flashrom project');
      s.Add('    chip data in chiplist-flashrom.xml, GPL-2.0-or-later');
      s.Add('    https://github.com/flashrom/flashrom');
      s.Add('');
      s.Add('  David Sanchez and Mecanico');
      s.Add('    the wiring photographs');
      s.Add('');
      s.Add('  Markus Stephany');
      s.Add('    MPHexEditor, the hex editor component');
      s.Add('');
      s.Add('Licence: MIT, see the LICENSE file next to the program.');
      s.Add('Copyright (c) 2015 nofeletru and contributors.');
    end
    else
    begin
      s.Add('AsProgrammer ProX');
      s.Add('Version 4.0.0.0');
      s.Add('');
      s.Add('Serial flash and EEPROM programmer for SPI, I2C and MicroWire.');
      s.Add('https://github.com/patnawa/AsProgrammer-ProX');
      s.Add('');
      s.Add('--- Build ---');
      s.Add('Executable   ' + ExeName);
      if FileExists(ExeName) then
        s.Add('Built        ' + FormatDateTime('yyyy-mm-dd hh:nn',
                                 FileDateToDateTime(FileAge(ExeName))));
      s.Add('Compiler     Free Pascal ' + {$I %FPCVERSION%});
      s.Add('Target       ' + {$I %FPCTARGETCPU%} + '-' + {$I %FPCTARGETOS%});
      s.Add('Widgetset    LCL');
      s.Add('');
      s.Add('--- Chip database ---');
      s.Add('chiplist.xml           ' + IntToStr(CountChips(ChipListFile)) + ' chips');
      if ChipListFile2 <> nil then
        s.Add('chiplist-flashrom.xml  ' + IntToStr(CountChips(ChipListFile2)) +
              ' chips  (GPL-2.0-or-later)')
      else
        s.Add('chiplist-flashrom.xml  not loaded');
      s.Add('Unknown chips are still usable through SFDP auto-detect.');
      s.Add('');
      s.Add('--- Programmers ---');
      s.Add('CH341a, CH347, FT232H, UsbAsp, AVRISP(LUFA), Arduino,');
      s.Add('Buzzpirat / Bus Pirate');
      s.Add('');
      s.Add('--- Protocols ---');
      s.Add('SPI 25 / 45 / 95 series, I2C 24 series, MicroWire 93 series,');
      s.Add('KB9012 EC');
      s.Add('');
      s.Add('--- This session ---');
      if ProgrammerPresent then
        s.Add('Programmer   ' + AsProgrammer.Programmer.HardwareName + ' connected')
      else
        s.Add('Programmer   none detected');
      if CurrentICParam.Name <> '' then
        s.Add('Chip         ' + CurrentICParam.Name + '  ' + CurrentICParam.ID)
      else
        s.Add('Chip         none selected');
      s.Add('Language     ' + CurrentLang);
      s.Add('');
      s.Add('Licence: MIT. See Version -> Credits for the people this is built on.');
    end;

    F := TForm.CreateNew(nil);
    try
      if ShowCredits then F.Caption := 'Credits' else F.Caption := 'Version';
      F.BorderStyle := bsSizeable;
      F.Position := poMainFormCenter;
      F.ClientWidth := 560;
      F.ClientHeight := 460;

      M := TMemo.Create(F);
      M.Parent := F;
      M.Align := alClient;
      M.BorderSpacing.Around := 8;
      M.BorderSpacing.Bottom := 44;
      M.ReadOnly := True;
      M.ScrollBars := ssAutoBoth;
      M.WordWrap := False;
      M.Font.Name := 'Consolas';
      M.Font.Size := 9;
      M.Lines.Assign(s);

      BtnCopy := TButton.Create(F);
      BtnCopy.Parent := F;
      BtnCopy.Caption := 'Copy';
      BtnCopy.Width := 90;
      BtnCopy.Anchors := [akRight, akBottom];
      BtnCopy.AnchorSideRight.Control := F;
      BtnCopy.AnchorSideRight.Side := asrRight;
      BtnCopy.AnchorSideBottom.Control := F;
      BtnCopy.AnchorSideBottom.Side := asrBottom;
      BtnCopy.BorderSpacing.Right := 106;
      BtnCopy.BorderSpacing.Bottom := 8;
      BtnCopy.OnClick := @MainForm.VersionCopyClick;
      BtnCopy.Tag := PtrInt(M);

      BtnClose := TButton.Create(F);
      BtnClose.Parent := F;
      BtnClose.Caption := 'Close';
      BtnClose.Width := 90;
      BtnClose.Anchors := [akRight, akBottom];
      BtnClose.AnchorSideRight.Control := F;
      BtnClose.AnchorSideRight.Side := asrRight;
      BtnClose.AnchorSideBottom.Control := F;
      BtnClose.AnchorSideBottom.Side := asrBottom;
      BtnClose.BorderSpacing.Right := 8;
      BtnClose.BorderSpacing.Bottom := 8;
      BtnClose.ModalResult := mrOk;
      BtnClose.Default := True;
      BtnClose.Cancel := True;

      F.ShowModal;
    finally
      F.Free;
    end;
  finally
    s.Free;
  end;
end;

procedure TMainForm.VersionCopyClick(Sender: TObject);
begin
  if Sender is TButton then
    TMemo(Pointer(TButton(Sender).Tag)).SelectAll;
  if Sender is TButton then
    TMemo(Pointer(TButton(Sender).Tag)).CopyToClipboard;
end;

procedure TMainForm.MenuAboutClick(Sender: TObject);
begin
  ShowVersionDialog(False);
end;

procedure TMainForm.MenuCreditsClick(Sender: TObject);
begin
  ShowVersionDialog(True);
end;

procedure TMainForm.CreditsMenuItemClick(Sender: TObject);
var
  credits: string;
begin
  //เครดิตย้ายมาอยู่ที่นี่ที่เดียว แถบ log ตอนเปิดโปรแกรมไม่ต้องแสดงแล้ว
  credits :=
    'AsProgrammer ProX v4' + LineEnding +
    'https://github.com/patnawa/AsProgrammer-ProX' + LineEnding + LineEnding +
    'Built on:' + LineEnding +
    '  nofeletru - AsProgrammer / UsbAsp-flash' + LineEnding +
    '  https://github.com/nofeletru/UsbAsp-flash' + LineEnding + LineEnding +
    '  Dreg @therealdreg - dregmod fork' + LineEnding +
    '  https://github.com/therealdreg/asprogrammer-dregmod' + LineEnding + LineEnding +
    '  Ian Lesnet - Bus Pirate' + LineEnding +
    '  Chip data in chiplist-flashrom.xml from the flashrom project (GPL-2.0-or-later)' +
    LineEnding + LineEnding +
    'MIT licence, see LICENSE';

  ShowMessage(credits);
end;

procedure TMainForm.ListcomportsMenuItemClick(Sender: TObject);
begin
     ExecuteProcess('cmd.exe', '/c start cmd /k mode', []);
end;

procedure TMainForm.SpeedButton1Click(Sender: TObject);
begin
  if ComboBox_chip_scriptrun.Items.Capacity < 1 then Exit;;
  if not OpenDevice() then exit;
  if RunScriptFromFile(CurrentICParam.Script, ComboBox_chip_scriptrun.Text) then Exit;
end;

procedure TMainForm.StartAddressEditChange(Sender: TObject);
begin
  if StartAddressEdit.Text = '' then StartAddressEdit.Text := '0';
  if Hex2Dec('$'+StartAddressEdit.Text) > 0 then
     StartAddressEdit.Color:= clYellow
  else
     StartAddressEdit.Color:= clDefault;
end;

procedure TMainForm.StartAddressEditKeyPress(Sender: TObject; var Key: char);
begin
  Key := UpCase(Key);
  if not(Key in['A'..'F', '0'..'9', Char(VK_BACK)]) then Key := Char('');
end;

procedure LoadChipList(XMLfile: TXMLDocument);
var
  Node: TDOMNode;
  j, i: integer;
  SectionItem, VendorItem: TMenuItem;
begin
  if XMLfile <> nil then
  begin

    Node := XMLfile.DocumentElement.FirstChild;

    while Assigned(Node) do
    begin

     if (LowerCase(Node.NodeName) = 'options') or (LowerCase(Node.NodeName) = 'locale') then
     begin
       Node := Node.NextSibling;
       continue;
     end;

     //ถ้าเมนูหมวดนี้มีอยู่แล้วก็ใช้ของเดิม เพราะรายชื่อชิปมาจากหลายไฟล์
     //และต้องรวมเข้าไปในต้นไม้เมนูเดียวกัน ไม่ใช่สร้างหมวดซ้ำ
     SectionItem := MainForm.MenuChip.Find(UTF16ToUTF8(Node.NodeName));
     if SectionItem = nil then
     begin
       MainForm.MenuChip.Add(NewItem(UTF16ToUTF8(Node.NodeName), 0, False, True, nil, 0, '')); //หมวด (SPI, I2C...)
       SectionItem := MainForm.MenuChip.Find(UTF16ToUTF8(Node.NodeName));
     end;

     // ใช้พรอเพอร์ตี ChildNodes
     with Node.ChildNodes do
     try
       for j := 0 to (Count - 1) do
       begin
         VendorItem := SectionItem.Find(UTF16ToUTF8(Item[j].NodeName));
         if VendorItem = nil then
         begin
           SectionItem.Add(NewItem(UTF16ToUTF8(Item[j].NodeName) ,0, False, True, nil, 0, '')); //หมวดผู้ผลิต
           VendorItem := SectionItem.Find(UTF16ToUTF8(Item[j].NodeName));
         end;

         for i := 0 to (Item[j].ChildNodes.Count - 1) do
           VendorItem.Add(NewItem(UTF16ToUTF8(Item[j].ChildNodes.Item[i].NodeName),
                                  0, False, True, @MainForm.ChipClick, 0, '' )); //ชิป
       end;
     finally
       Free;
     end;
     Node := Node.NextSibling;
    end;
  end;

end;

{ TMainForm }

procedure TMainForm.FormCreate(Sender: TObject);
begin
  AsProgrammer := TAsProgrammer.Create;
  AsProgrammer.AddHW(TUsbAspHardware.Create);
  AsProgrammer.AddHW(TCH341Hardware.Create);
  AsProgrammer.AddHW(TAvrispHardware.Create);
  AsProgrammer.AddHW(TArduinoHardware.Create);
  AsProgrammer.AddHW(TBuzzpiratHardware.Create);
  AsProgrammer.AddHW(TFT232HHardware.Create);
  AsProgrammer.AddHW(TCH347Hardware.Create);

  SelectHW(CHW_BUZZPIRAT); // ทางลัดแบบหยาบ ๆ ของ dreg

  LoadChipList(ChipListFile);
  LoadChipList(ChipListFile2);
  RomF := TMemoryStream.Create;
  ScriptEngine := TPasCalc.Create;
  ScriptsFunc.SetScriptFunctions(ScriptEngine);

  MPHexEditorEx.NoSizeChange := true;
  MPHexEditorEx.InsertMode := false;
  DefaultProdSettings(ProdSettings);
  LoadOptions(SettingsFile);
  LoadLangList();

  LoadModernIcons;
  LayoutLeftPanel;
  ApplyTheme(MenuDarkTheme.Checked);
  UpdateChipInfo;

  //ค้นหาเครื่องโปรแกรมที่เสียบอยู่ตั้งแต่เปิดโปรแกรม แล้วเฝ้าดูต่อเป็นระยะ
  SetHardwareMenuCheck(AsProgrammer.Current_HW);
  PollProgrammer(True);
  HwTimer.Enabled := True;
end;

//ตอน FormCreate ยังไม่รู้ความสูงจริงของแผง ต้องจัดวางซ้ำหลังหน้าต่างขึ้นแล้ว
//ไม่งั้นรูปชิปจะถูกคำนวณจากขนาดตอนออกแบบและโดนตัดขอบ
//คืนขนาดและตำแหน่งหน้าต่างที่ผู้ใช้ตั้งไว้ครั้งก่อน
//ต้องทำที่นี่ ไม่ใช่ตอนอ่านค่า เพราะหน้าต่างยังไม่มีตัวตนจริงตอนนั้น
procedure RestoreWindowGeometry;
var
  Node: TDOMNode;

  function Attr(const Name: string; Def: integer): integer;
  var
    v: string;
  begin
    Result := Def;
    if Node.Attributes.GetNamedItem(Name) = nil then Exit;
    v := UTF16ToUTF8(Node.Attributes.GetNamedItem(Name).NodeValue);
    if IsNumber(v) then Result := StrToInt(v);
  end;

var
  L, T, W, H: integer;
begin
  if SettingsFile = nil then Exit;
  Node := SettingsFile.DocumentElement.FindNode('options');
  if (Node = nil) or (not Node.HasAttributes) then Exit;

  W := Attr('win_width', 0);
  H := Attr('win_height', 0);

  //หน้าจออาจเปลี่ยนไปแล้ว อย่าคืนตำแหน่งที่มองไม่เห็น
  if (W > 400) and (H > 300) then
  begin
    L := Attr('win_left', MainForm.Left);
    T := Attr('win_top', MainForm.Top);

    if (L > -50) and (T > -50) and
       (L < Screen.DesktopWidth - 100) and (T < Screen.DesktopHeight - 100) then
    begin
      MainForm.Position := poDesigned;
      MainForm.SetBounds(L, T, W, H);
    end
    else
      MainForm.SetBounds(MainForm.Left, MainForm.Top, W, H);
  end;

  if Node.Attributes.GetNamedItem('win_max') <> nil then
    if UTF16ToUTF8(Node.Attributes.GetNamedItem('win_max').NodeValue) = '1' then
      MainForm.WindowState := wsMaximized;
end;

procedure TMainForm.FormShow(Sender: TObject);
begin
  RestoreWindowGeometry;
  LayoutLeftPanel;
  ChipView.Invalidate;

  //คำใบ้ปุ่มลัดอยู่ตรงนี้ ไม่ใช่บนแถบชื่อหน้าต่าง
  ButtonCancel.Hint := ButtonCancel.Hint + ' (Esc)';
  StatusBar.Panels.Items[3].Text := STR_HINT_KEYS;
end;

//ลากไฟล์มาวางบนหน้าต่างแล้วโหลดเข้าเอดิเตอร์ได้เลย
//รองรับทุกนามสกุลที่เมนูเปิดไฟล์รองรับ รวมถึง .hex และ S-record
procedure TMainForm.FormDropFiles(Sender: TObject; const FileNames: array of string);
var
  Stream: TMemoryStream;
  ErrMsg: string;
  BlankByte: byte;
begin
  if OperationRunning then Exit;
  if Length(FileNames) = 0 then Exit;

  if DetectFormat(FileNames[0]) = ffBinary then
  begin
    MPHexEditorEx.LoadFromFile(FileNames[0]);
    StatusBar.Panels.Items[2].Text := FileNames[0];
    LogPrint(STR_FILE_LOADED + ExtractFileName(FileNames[0]));
    Exit;
  end;

  if RadioSPI.Checked and (ComboSPICMD.ItemIndex = SPI_CMD_KB) then
    BlankByte := $00
  else
    BlankByte := $FF;

  Stream := TMemoryStream.Create;
  try
    if not LoadFirmware(FileNames[0], Stream, UIChipSize, BlankByte, ErrMsg) then
    begin
      LogPrint(ErrMsg);
      Exit;
    end;
    if ErrMsg <> '' then LogPrint(ErrMsg);

    Stream.Position := 0;
    MPHexEditorEx.LoadFromStream(Stream);
    StatusBar.Panels.Items[2].Text := FileNames[0];
    LogPrint(STR_FILE_LOADED + ExtractFileName(FileNames[0]));
  finally
    Stream.Free;
  end;
end;

//ESC ยกเลิกงานที่ทำอยู่ F1 เปิดคอนโซลดีบัก
//เดิมแถบชื่อหน้าต่างโฆษณาสองปุ่มนี้ไว้ แต่ในโค้ดไม่เคยมีตัวรับปุ่มเลย
procedure TMainForm.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key = VK_ESCAPE then
  begin
    if OperationRunning then
    begin
      ButtonCancel.Tag := 1;
      Key := 0;
    end;
  end
  else if Key = VK_F1 then
  begin
    DebugconsoleMenuItemClick(Sender);
    Key := 0;
  end;
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  AsProgrammer.Free;
  MainForm.MPHexEditorEx.Free;
  RomF.Free;
  SaveOptions(SettingsFile);
  ChipListFile.Free;
  ChipListFile2.Free;
  SettingsFile.Free;
  ScriptEngine.Free;
end;

procedure TMainForm.ButtonReadClick(Sender: TObject);
var
  I2C_DevAddr: byte;
  I2C_ChunkSize: word;
  CRC32: Cardinal;
begin
  I2C_ChunkSize := 65535;
try
  ButtonCancel.Tag := 0;
  if not OpenDevice() then exit;
  LockControl();

  if RunScriptFromFile(CurrentICParam.Script, 'read') then Exit;

  LogPrint(TimeToStr(Time()));

  if (not IsNumber(ComboChipSize.Text)) then
  begin
    LogPrint(STR_CHECK_SETTINGS);
    Exit;
  end;

  //SPI
  if RadioSPI.Checked then
  begin
    EnterProgMode25(SetSPISpeed(0), MainForm.MenuSendAB.Checked);
    TimeCounter := Time();

    if  ComboSPICMD.ItemIndex = SPI_CMD_KB then
    begin
      ReadFlashKB(RomF, 0, StrToInt(ComboChipSize.Text));
    end;

    if  ComboSPICMD.ItemIndex = SPI_CMD_25 then
      ReadFlash25(RomF, Hex2Dec('$'+StartAddressEdit.Text), StrToInt(ComboChipSize.Text));
    if  ComboSPICMD.ItemIndex = SPI_CMD_45 then
    begin
      if (not IsNumber(ComboPageSize.Text)) then
      begin
        LogPrint(STR_CHECK_SETTINGS);
        Exit;
      end;
      ReadFlash45(RomF, 0, StrToInt(ComboPageSize.Text), StrToInt(ComboChipSize.Text));
    end;

    if  ComboSPICMD.ItemIndex = SPI_CMD_95 then
      ReadFlash95(RomF, Hex2Dec('$'+StartAddressEdit.Text), StrToInt(ComboChipSize.Text));

    RomF.Position := 0;
    MPHexEditorEx.LoadFromStream(RomF);
    StatusBar.Panels.Items[2].Text := LabelChipName.Caption;
  end;
  //I2C
  if RadioI2C.Checked then
  begin
    if ComboAddrType.ItemIndex < 0 then
    begin
      LogPrint(STR_CHECK_SETTINGS);
      Exit;
    end;

    EnterProgModeI2c();

    //แอดเดรสของชิปตามช่องติ๊ก
    I2C_DevAddr := SetI2CDevAddr();

    if CheckBox_I2C_ByteRead.Checked then I2C_ChunkSize := 1;

    if UsbAspI2C_BUSY(I2C_DevAddr) then
    begin
      LogPrint(STR_I2C_NO_ANSWER);
      exit;
    end;
    TimeCounter := Time();
    ReadFlashI2C(RomF, Hex2Dec('$'+StartAddressEdit.Text), StrToInt(ComboChipSize.Text), I2C_ChunkSize, I2C_DevAddr);

    RomF.Position := 0;
    MPHexEditorEx.LoadFromStream(RomF);
    StatusBar.Panels.Items[2].Text := LabelChipName.Caption;
  end;
  //Microwire
  if RadioMw.Checked then
  begin
    if (not IsNumber(ComboMWBitLen.Text)) then
    begin
      LogPrint(STR_CHECK_SETTINGS);
      Exit;
    end;

    if not AsProgrammer.Programmer.MWInit(SetSPISpeed(0)) then Exit;
    TimeCounter := Time();
    ReadFlashMW(RomF, StrToInt(ComboMWBitLen.Text), 0, StrToInt(ComboChipSize.Text));

    RomF.Position := 0;
    MPHexEditorEx.LoadFromStream(RomF);
    StatusBar.Panels.Items[2].Text := LabelChipName.Caption;
  end;

  LogPrint(STR_TIME + TimeToStr(Time() - TimeCounter));

  CRC32 := UpdateCRC32($FFFFFFFF, Romf.Memory, Romf.Size);
  LogPrint('CRC32 = 0x'+IntToHex(CRC32, 8));

finally
  ExitProgMode25;
  AsProgrammer.Programmer.DevClose;
  UnlockControl();
end;
end;

procedure TMainForm.ClearLogMenuItemClick(Sender: TObject);
begin
  Log.Lines.Clear;
end;

procedure TMainForm.ComboSPICMDChange(Sender: TObject);
begin
  RadioSPI.OnChange(Sender);
end;

procedure TMainForm.CopyLogMenuItemClick(Sender: TObject);
begin
  Log.CopyToClipboard;
end;

procedure TMainForm.AllowInsertItemClick(Sender: TObject);
begin
  MPHexEditorEx.NoSizeChange := not AllowInsertItem.Checked;
  MPHexEditorEx.InsertMode := AllowInsertItem.Checked;
end;

procedure TMainForm.FormCloseQuery(Sender: TObject; var CanClose: boolean);
begin
  ButtonCancel.Tag := 1;

  //ในโหมดเบื้องหลังหน้าต่างยังใช้งานได้ จึงปิดได้ทั้งที่ยังคุยกับชิปอยู่
  //ต้องรอให้งานที่ทำอยู่จบก่อน
  if OperationRunning then
  begin
    CanClose := False;
    Exit;
  end;

  ScriptEditForm.FormCloseQuery(Sender, CanClose);
end;

procedure TMainForm.ButtonEraseClick(Sender: TObject);
var
  I2C_DevAddr: byte;
begin
try
  ButtonCancel.Tag := 0;
  if not OpenDevice() then exit;
  if Sender <> ComboItem1 then
    if MessageDlg('AsProgrammer', STR_START_ERASE, mtConfirmation, [mbYes, mbNo], 0)
      <> mrYes then Exit;
  LockControl();

  if RunScriptFromFile(CurrentICParam.Script, 'erase') then Exit;

  LogPrint(TimeToStr(Time()));

  //SPI
  if RadioSPI.Checked then
  begin
    EnterProgMode25(SetSPISpeed(0), MainForm.MenuSendAB.Checked);

    if not VoltageWarningOK then Exit;
    if not VerifyChipID then Exit;
    if not AutoBackupChip then Exit;

    if ComboSPICMD.ItemIndex <> SPI_CMD_KB then
      IsLockBitsEnabled;
    TimeCounter := Time();

    LogPrint(STR_ERASING_FLASH);

    if ComboSPICMD.ItemIndex = SPI_CMD_KB then
    begin

      if (not IsNumber(ComboChipSize.Text)) then
      begin
        LogPrint(STR_CHECK_SETTINGS);
        Exit;
      end;

      if (not IsNumber(ComboPageSize.Text)) then
      begin
        LogPrint(STR_CHECK_SETTINGS);
        Exit;
      end;

      EraseFlashKB(StrToInt(ComboChipSize.Text), StrToInt(ComboPageSize.Text));
    end;

    if ComboSPICMD.ItemIndex = SPI_CMD_25 then
    begin
      ProgressBar.Style:= pbstMarquee;
      ProgressBar.Max:= 1;
      ProgressBar.Position:= 1;

      ChipErase25;

      ProgressBar.Style:= pbstNormal;
      ProgressBar.Position:= 0;
    end;

    if ComboSPICMD.ItemIndex = SPI_CMD_95 then
      begin
        if ( (not IsNumber(ComboChipSize.Text)) or (not IsNumber(ComboPageSize.Text))) then
        begin
          LogPrint(STR_CHECK_SETTINGS);
          Exit;
        end;

      EraseEEPROM25(0, StrToInt(ComboChipSize.Text), StrToInt(ComboPageSize.Text), StrToInt(ComboChipSize.Text));
    end;

    if ComboSPICMD.ItemIndex = SPI_CMD_45 then
    begin
      UsbAsp45_ChipErase();

      while UsbAsp45_Busy() do
      begin
        Application.ProcessMessages;
        if UserCancel then Exit;
      end;
    end;

  end;

  //I2C
  if RadioI2C.Checked then
  begin
  if ( (ComboAddrType.ItemIndex < 0) or (not IsNumber(ComboPageSize.Text)) ) then
    begin
      LogPrint(STR_CHECK_SETTINGS);
      Exit;
    end;

    EnterProgModeI2C();

    //แอดเดรสของชิปตามช่องติ๊ก
    I2C_DevAddr := SetI2CDevAddr();

    if UsbAspI2C_BUSY(I2C_DevAddr) then
    begin
      LogPrint(STR_I2C_NO_ANSWER);
      exit;
    end;

    TimeCounter := Time();

    if StrToInt(ComboPageSize.Text) < 1 then ComboPageSize.Text := '1';

    EraseFlashI2C(0, StrToInt(ComboChipSize.Text), StrToInt(ComboPageSize.Text), I2C_DevAddr);
  end;

  //Microwire
  if RadioMW.Checked then
  begin
    if (not IsNumber(ComboMWBitLen.Text)) then
    begin
      LogPrint(STR_CHECK_SETTINGS);
      Exit;
    end;

    AsProgrammer.Programmer.MWInit(SetSPISpeed(0));
    TimeCounter := Time();
    LogPrint(STR_ERASING_FLASH);
    UsbAspMW_Ewen(StrToInt(ComboMWBitLen.Text));
    UsbAspMW_ChipErase(StrToInt(ComboMWBitLen.Text));

     while UsbAspMW_Busy do
     begin
       Application.ProcessMessages;
       if UserCancel then Exit;
     end;

  end;


  LogPrint(STR_DONE);
  LogPrint(STR_TIME + TimeToStr(Time() - TimeCounter));

finally
  ExitProgMode25;
  AsProgrammer.Programmer.DevClose;
  UnlockControl();
end;
end;

procedure TMainForm.BlankCheckMenuItemClick(Sender: TObject);
begin
  VerifyFlash(true);
end;

//ลบเฉพาะเซกเตอร์ที่อยู่ในช่วงที่กำหนด
//จุดเริ่มมาจากช่อง Start address ความยาวมาจากขนาดข้อมูลใน hex editor
//ค่า Tag ของเมนูกำหนดขนาดเซกเตอร์ ถ้าเป็น 0 จะเอาจาก chiplist.xml หรือ SFDP
procedure TMainForm.MenuEraseRangeClick(Sender: TObject);
var
  SectorSize, RangeLen, StartAddr: cardinal;
  Opcode: byte;
begin
  if OperationRunning then Exit;
try
  ButtonCancel.Tag := 0;

  if (not RadioSPI.Checked) or (ComboSPICMD.ItemIndex <> SPI_CMD_25) then
  begin
    LogPrint(STR_SECTOR_SPI25_ONLY);
    Exit;
  end;

  SectorSize := CurrentSectorSize;
  Opcode := CurrentSectorOpcode;

  if Sender is TMenuItem then
    if TMenuItem(Sender).Tag > 0 then
    begin
      SectorSize := cardinal(TMenuItem(Sender).Tag);
      Opcode := SectorEraseOpcode(SectorSize);
    end;

  StartAddr := Hex2Dec('$' + StartAddressEdit.Text);
  RangeLen := MPHexEditorEx.DataSize;
  if RangeLen = 0 then RangeLen := SectorSize;

  //ถ้าเรียกมาจาก smart write ผู้ใช้ยืนยันไปแล้ว ไม่ต้องถามซ้ำ
  if Sender <> MenuSmartWrite then
    if MessageDlg('AsProgrammer', STR_ERASE_RANGE_Q + LineEnding +
       '0x' + IntToHex(StartAddr, 8) + ' + ' + IntToStr(RangeLen) + ' bytes',
       mtConfirmation, [mbYes, mbNo], 0) <> mrYes then Exit;

  if not OpenDevice() then Exit;
  LockControl();

  LogPrint(TimeToStr(Time()));
  EnterProgMode25(SetSPISpeed(0), MenuSendAB.Checked);

  if not VoltageWarningOK then Exit;
  if not VerifyChipID then Exit;
  if not AutoBackupChip then Exit;

  IsLockBitsEnabled;
  TimeCounter := Time();

  if EraseRange25(StartAddr, RangeLen, SectorSize, Opcode) then
    LogPrint(STR_DONE);

  LogPrint(STR_TIME + TimeToStr(Time() - TimeCounter));

finally
  ExitProgMode25;
  AsProgrammer.Programmer.DevClose;
  UnlockControl();
end;
end;

//ปลดล็อก -> ลบเฉพาะเซกเตอร์ที่ต้องใช้ -> เขียน -> ตรวจสอบ
procedure TMainForm.MenuSmartWriteClick(Sender: TObject);
var
  CheckTemp: boolean;
begin
  if OperationRunning then Exit;

  if MPHexEditorEx.DataSize = 0 then
  begin
    LogPrint(STR_ERASE_RANGE_EMPTY);
    Exit;
  end;

  if (not RadioSPI.Checked) or (ComboSPICMD.ItemIndex <> SPI_CMD_25) then
  begin
    LogPrint(STR_SECTOR_SPI25_ONLY);
    Exit;
  end;

  if MessageDlg('AsProgrammer', STR_COMBO_WARN, mtConfirmation, [mbYes, mbNo], 0)
    <> mrYes then Exit;

  if ButtonBlock.Enabled then
    ButtonBlockClick(ComboItem1);

  MenuEraseRangeClick(MenuSmartWrite);

  if ButtonCancel.Tag <> 0 then Exit;

  CheckTemp := MenuAutoCheck.Checked;
  MenuAutoCheck.Checked := True;

  ButtonWriteClick(ComboItem1);

  MenuAutoCheck.Checked := CheckTemp;
end;

//สลับโหมดรันงานบน thread เบื้องหลัง
procedure TMainForm.MenuBackgroundOpsClick(Sender: TObject);
begin
  UseWorkerThread := MenuBackgroundOps.Checked;
end;

procedure TMainForm.MenuDarkThemeClick(Sender: TObject);
begin
  ApplyTheme(MenuDarkTheme.Checked);
end;

//ค่า checksum ของข้อมูลใน hex editor
procedure TMainForm.MenuChecksumClick(Sender: TObject);
var
  Stream: TMemoryStream;
  Data: array of byte;
  crc, sum32: cardinal;
  i: integer;
begin
  if OperationRunning then Exit;

  if MPHexEditorEx.DataSize = 0 then
  begin
    LogPrint(STR_CHECKSUM_EMPTY);
    Exit;
  end;

  Stream := TMemoryStream.Create;
  try
    MPHexEditorEx.SaveToStream(Stream);
    Stream.Position := 0;
    SetLength(Data, MPHexEditorEx.DataSize);
    if Length(Data) = 0 then Exit;
    Stream.ReadBuffer(Data[0], Length(Data));
  finally
    Stream.Free;
  end;

  crc := UpdateCRC32($FFFFFFFF, @Data[0], Length(Data));

  sum32 := 0;
  for i := 0 to High(Data) do
    sum32 := sum32 + Data[i];

  LogPrint(STR_CHECKSUM +
           'size=' + IntToStr(Length(Data)) +
           '  CRC32=' + IntToHex(crc, 8) +
           '  SUM32=' + IntToHex(sum32, 8) +
           '  SUM16=' + IntToHex(sum32 and $FFFF, 4));
end;

//อ่านสเปกของชิปผ่าน SFDP (JESD216)
procedure TMainForm.MenuSFDPDetectClick(Sender: TObject);
var
  Info: TSFDPInfo;
  i: integer;
  ESize: cardinal;
  EOpcode: byte;
begin
  if OperationRunning then Exit;
try
  ButtonCancel.Tag := 0;

  if not RadioSPI.Checked then
  begin
    LogPrint(STR_SECTOR_SPI25_ONLY);
    Exit;
  end;

  if not OpenDevice() then Exit;
  LockControl();

  LogPrint(STR_SFDP_READING);
  EnterProgMode25(SetSPISpeed(0), MenuSendAB.Checked);

  if not SFDPDetect(Info) then
  begin
    LogPrint(STR_SFDP_NOT_FOUND);
    Exit;
  end;

  LogPrint(STR_SFDP_FOUND + ' (JESD216 rev ' + IntToStr(Info.MajorRev) + '.' +
           IntToStr(Info.MinorRev) + ')');
  LogPrint('  Size: ' + IntToStr(Info.Density) + ' bytes');
  LogPrint('  Page: ' + IntToStr(Info.PageSize) + ' bytes');
  LogPrint('  Address bytes: ' + SFDPAddrBytesStr(Info));

  for i := 1 to 4 do
    if Info.EraseTypes[i].Size > 0 then
      LogPrint('  Erase type ' + IntToStr(i) + ': ' + IntToStr(Info.EraseTypes[i].Size) +
               ' bytes, opcode 0x' + IntToHex(Info.EraseTypes[i].Opcode, 2));

  //เติมค่าลงช่องต่าง ๆ ลำดับสำคัญ เพราะ RadioSPIChange จะล้างค่าทิ้ง
  ComboSPICMD.ItemIndex := SPI_CMD_25;
  RadioSPI.Checked := True;
  RadioSPIChange(MainForm);

  ComboChipSize.Text := IntToStr(Info.Density);
  ComboPageSize.Text := IntToStr(Info.PageSize);
  LabelChipName.Caption := 'SFDP ' + IntToStr(Info.Density div 1024) + 'K';

  CurrentICParam.Name := LabelChipName.Caption;
  CurrentICParam.Size := Info.Density;
  CurrentICParam.Page := Info.PageSize;
  CurrentICParam.SpiCmd := SPI_CMD_25;
  CurrentICParam.Script := '';
  ComboBox_chip_scriptrun.Items.Clear;

  if SFDPSmallestErase(Info, ESize, EOpcode) then
  begin
    CurrentICParam.Sector := ESize;
    CurrentICParam.SectorOpcode := EOpcode;
  end
  else
  begin
    CurrentICParam.Sector := 0;
    CurrentICParam.SectorOpcode := 0;
  end;

  LogPrint(STR_SFDP_APPLIED);

finally
  ExitProgMode25;
  AsProgrammer.Programmer.DevClose;
  UnlockControl();
end;
end;

procedure SaveOptions(XMLfile: TXMLDocument);
var
  Node, ParentNode: TDOMNode;
begin
  if XMLfile <> nil then
  begin
    //ลบรายการเดิมทิ้ง
    Node := XMLfile.DocumentElement.FindNode('locale');
    if (Node <> nil) then XMLfile.DocumentElement.RemoveChild(Node);
    //แล้วสร้างใหม่
    Node:= XMLfile.DocumentElement;
    ParentNode := XMLfile.CreateElement('locale');
    TDOMElement(ParentNode).SetAttribute('lang', CurrentLang);
    Node.Appendchild(parentNode);

    //ลบรายการเดิมทิ้ง
    Node := XMLfile.DocumentElement.FindNode('options');
    if (Node <> nil) then XMLfile.DocumentElement.RemoveChild(Node);

    Node:= XMLfile.DocumentElement;
    ParentNode := XMLfile.CreateElement('options');

    if MainForm.MenuAutoCheck.Checked then
      TDOMElement(ParentNode).SetAttribute('verify', '1') else
        TDOMElement(ParentNode).SetAttribute('verify', '0');

    if MainForm.MenuSkipFF.Checked then
      TDOMElement(ParentNode).SetAttribute('skipff', '1') else
        TDOMElement(ParentNode).SetAttribute('skipff', '0');

    if MainForm.MenuSendAB.Checked then
      TDOMElement(ParentNode).SetAttribute('sendab', '1') else
        TDOMElement(ParentNode).SetAttribute('sendab', '0');

    if MainForm.MenuBackgroundOps.Checked then
      TDOMElement(ParentNode).SetAttribute('background_ops', '1') else
        TDOMElement(ParentNode).SetAttribute('background_ops', '0');

    if MainForm.MenuDarkTheme.Checked then
      TDOMElement(ParentNode).SetAttribute('dark_theme', '1') else
        TDOMElement(ParentNode).SetAttribute('dark_theme', '0');

    if MainForm.MenuAutoDetectHW.Checked then
      TDOMElement(ParentNode).SetAttribute('auto_detect_hw', '1') else
        TDOMElement(ParentNode).SetAttribute('auto_detect_hw', '0');

    if MainForm.MenuBlankBeforeWrite.Checked then
      TDOMElement(ParentNode).SetAttribute('blank_before_write', '1') else
        TDOMElement(ParentNode).SetAttribute('blank_before_write', '0');

    if MainForm.MenuCheckIDBefore.Checked then
      TDOMElement(ParentNode).SetAttribute('check_id', '1') else
        TDOMElement(ParentNode).SetAttribute('check_id', '0');

    if MainForm.MenuAutoBackup.Checked then
      TDOMElement(ParentNode).SetAttribute('auto_backup', '1') else
        TDOMElement(ParentNode).SetAttribute('auto_backup', '0');

    if MainForm.Menu3Mhz.Checked then
      TDOMElement(ParentNode).SetAttribute('spi_speed', '3Mhz');
    if MainForm.Menu1_5Mhz.Checked then
      TDOMElement(ParentNode).SetAttribute('spi_speed', '1_5Mhz');
    if MainForm.Menu750Khz.Checked then
      TDOMElement(ParentNode).SetAttribute('spi_speed', '750Khz');
    if MainForm.Menu375Khz.Checked then
      TDOMElement(ParentNode).SetAttribute('spi_speed', '375Khz');
    if MainForm.Menu187_5Khz.Checked then
      TDOMElement(ParentNode).SetAttribute('spi_speed', '187_5Khz');
    if MainForm.Menu93_75Khz.Checked then
      TDOMElement(ParentNode).SetAttribute('spi_speed', '93_75Khz');
    if MainForm.Menu32Khz.Checked then
      TDOMElement(ParentNode).SetAttribute('spi_speed', '32Khz');

    if MainForm.MenuCH347SPIClock60MHz.Checked then
      TDOMElement(ParentNode).SetAttribute('ch347_spi_speed', '60Mhz');
    if MainForm.MenuCH347SPIClock30MHz.Checked then
      TDOMElement(ParentNode).SetAttribute('ch347_spi_speed', '30Mhz');
    if MainForm.MenuCH347SPIClock15MHz.Checked then
      TDOMElement(ParentNode).SetAttribute('ch347_spi_speed', '15Mhz');
    if MainForm.MenuCH347SPIClock7_5MHz.Checked then
      TDOMElement(ParentNode).SetAttribute('ch347_spi_speed', '7_5Mhz');
    if MainForm.MenuCH347SPIClock3_75MHz.Checked then
      TDOMElement(ParentNode).SetAttribute('ch347_spi_speed', '3_75Mhz');
    if MainForm.MenuCH347SPIClock1_875MHz.Checked then
      TDOMElement(ParentNode).SetAttribute('ch347_spi_speed', '1_875MHz');
    if MainForm.MenuCH347SPIClock937_5KHz.Checked then
      TDOMElement(ParentNode).SetAttribute('ch347_spi_speed', '937_5KHz');
    if MainForm.MenuCH347SPIClock468_75KHz.Checked then
      TDOMElement(ParentNode).SetAttribute('ch347_spi_speed', '468_75KHz');

    if MainForm.MenuMW32Khz.Checked then
      TDOMElement(ParentNode).SetAttribute('mw_speed', '32Khz');
    if MainForm.MenuMW16Khz.Checked then
      TDOMElement(ParentNode).SetAttribute('mw_speed', '16Khz');
    if MainForm.MenuMW8Khz.Checked then
      TDOMElement(ParentNode).SetAttribute('mw_speed', '8Khz');

    if MainForm.MenuHWUSBASP.Checked then
      TDOMElement(ParentNode).SetAttribute('hw', 'usbasp');
    if MainForm.MenuHWCH341A.Checked then
      TDOMElement(ParentNode).SetAttribute('hw', 'ch341a');
    if MainForm.MenuHWCH347.Checked then
      TDOMElement(ParentNode).SetAttribute('hw', 'ch347');
    if MainForm.MenuHWAVRISP.Checked then
      TDOMElement(ParentNode).SetAttribute('hw', 'avrisp');
    if MainForm.MenuHWARDUINO.Checked then
      TDOMElement(ParentNode).SetAttribute('hw', 'arduino');
    if MainForm.MenuHWBUZZPIRAT.Checked then
      TDOMElement(ParentNode).SetAttribute('hw', 'buzzpirat');
    if MainForm.MenuHWFT232H.Checked then
      TDOMElement(ParentNode).SetAttribute('hw', 'ft232h');

    //เลขรันนิ่งและการผลิตเป็นชุด
    TDOMElement(ParentNode).SetAttribute('sn_enabled', BoolToStr(ProdSettings.SNEnabled, '1', '0'));
    TDOMElement(ParentNode).SetAttribute('sn_address', IntToHex(ProdSettings.SNAddress, 6));
    TDOMElement(ParentNode).SetAttribute('sn_length', IntToStr(ProdSettings.SNLength));
    TDOMElement(ParentNode).SetAttribute('sn_mode', IntToStr(Ord(ProdSettings.SNMode)));
    TDOMElement(ParentNode).SetAttribute('sn_value', IntToStr(ProdSettings.SNValue));
    TDOMElement(ParentNode).SetAttribute('sn_step', IntToStr(ProdSettings.SNStep));
    TDOMElement(ParentNode).SetAttribute('sn_bigendian', BoolToStr(ProdSettings.SNBigEndian, '1', '0'));
    TDOMElement(ParentNode).SetAttribute('sn_logfile', ProdSettings.SNLogFile);
    TDOMElement(ParentNode).SetAttribute('batch_enabled', BoolToStr(ProdSettings.BatchEnabled, '1', '0'));
    TDOMElement(ParentNode).SetAttribute('batch_target', IntToStr(ProdSettings.BatchTarget));

    //ขนาดและตำแหน่งหน้าต่าง เก็บเฉพาะตอนไม่ได้ขยายเต็มจอ
    if MainForm.WindowState = wsNormal then
    begin
      TDOMElement(ParentNode).SetAttribute('win_left', IntToStr(MainForm.Left));
      TDOMElement(ParentNode).SetAttribute('win_top', IntToStr(MainForm.Top));
      TDOMElement(ParentNode).SetAttribute('win_width', IntToStr(MainForm.Width));
      TDOMElement(ParentNode).SetAttribute('win_height', IntToStr(MainForm.Height));
    end;
    TDOMElement(ParentNode).SetAttribute('win_max',
      BoolToStr(MainForm.WindowState = wsMaximized, '1', '0'));

    TDOMElement(ParentNode).SetAttribute('arduino_comport', Arduino_COMPort);
    TDOMElement(ParentNode).SetAttribute('arduino_baudrate', IntToStr(Arduino_BaudRate));

    Node.Appendchild(parentNode);

    WriteXMLFile(XMLfile, SettingsFileName);
  end;

end;

procedure LoadOptions(XMLfile: TXMLDocument);
var
    Node: TDOMNode;
    OptVal: string;
begin
  if XMLfile <> nil then
  begin
    Node := XMLfile.DocumentElement.FindNode('options');

    if (Node <> nil) then
    if (Node.HasAttributes) then
    begin

      if  Node.Attributes.GetNamedItem('verify') <> nil then
      begin
        if Node.Attributes.GetNamedItem('verify').NodeValue = '1' then
          MainForm.MenuAutoCheck.Checked := true;
      end;

      if  Node.Attributes.GetNamedItem('sendab') <> nil then
      begin
        if Node.Attributes.GetNamedItem('sendab').NodeValue = '1' then
          MainForm.MenuSendAB.Checked := true;
      end;

      if  Node.Attributes.GetNamedItem('skipff') <> nil then
      begin
        if Node.Attributes.GetNamedItem('skipff').NodeValue = '1' then
          MainForm.MenuSkipFF.Checked := true;
      end;

      if  Node.Attributes.GetNamedItem('background_ops') <> nil then
      begin
        if Node.Attributes.GetNamedItem('background_ops').NodeValue = '1' then
          MainForm.MenuBackgroundOps.Checked := true;
        UseWorkerThread := MainForm.MenuBackgroundOps.Checked;
      end;

      if  Node.Attributes.GetNamedItem('dark_theme') <> nil then
        MainForm.MenuDarkTheme.Checked :=
          Node.Attributes.GetNamedItem('dark_theme').NodeValue = '1';

      if  Node.Attributes.GetNamedItem('blank_before_write') <> nil then
        MainForm.MenuBlankBeforeWrite.Checked :=
          Node.Attributes.GetNamedItem('blank_before_write').NodeValue = '1';

      if  Node.Attributes.GetNamedItem('auto_detect_hw') <> nil then
        MainForm.MenuAutoDetectHW.Checked :=
          Node.Attributes.GetNamedItem('auto_detect_hw').NodeValue = '1';

      if  Node.Attributes.GetNamedItem('check_id') <> nil then
        MainForm.MenuCheckIDBefore.Checked :=
          Node.Attributes.GetNamedItem('check_id').NodeValue = '1';

      if  Node.Attributes.GetNamedItem('auto_backup') <> nil then
        MainForm.MenuAutoBackup.Checked :=
          Node.Attributes.GetNamedItem('auto_backup').NodeValue = '1';

      //เลขรันนิ่งและการผลิตเป็นชุด
      if Node.Attributes.GetNamedItem('sn_enabled') <> nil then
        ProdSettings.SNEnabled := Node.Attributes.GetNamedItem('sn_enabled').NodeValue = '1';

      if Node.Attributes.GetNamedItem('sn_address') <> nil then
      begin
        OptVal := UTF16ToUTF8(Node.Attributes.GetNamedItem('sn_address').NodeValue);
        if IsNumber('$' + OptVal) then ProdSettings.SNAddress := StrToInt('$' + OptVal);
      end;

      if Node.Attributes.GetNamedItem('sn_length') <> nil then
      begin
        OptVal := UTF16ToUTF8(Node.Attributes.GetNamedItem('sn_length').NodeValue);
        if IsNumber(OptVal) then ProdSettings.SNLength := StrToInt(OptVal);
      end;

      if Node.Attributes.GetNamedItem('sn_mode') <> nil then
      begin
        OptVal := UTF16ToUTF8(Node.Attributes.GetNamedItem('sn_mode').NodeValue);
        if IsNumber(OptVal) and (StrToInt(OptVal) in [0..2]) then
          ProdSettings.SNMode := TSerialMode(StrToInt(OptVal));
      end;

      if Node.Attributes.GetNamedItem('sn_value') <> nil then
      begin
        OptVal := UTF16ToUTF8(Node.Attributes.GetNamedItem('sn_value').NodeValue);
        if IsNumber(OptVal) then ProdSettings.SNValue := StrToQWord(OptVal);
      end;

      if Node.Attributes.GetNamedItem('sn_step') <> nil then
      begin
        OptVal := UTF16ToUTF8(Node.Attributes.GetNamedItem('sn_step').NodeValue);
        if IsNumber(OptVal) then ProdSettings.SNStep := StrToInt(OptVal);
      end;

      if Node.Attributes.GetNamedItem('sn_bigendian') <> nil then
        ProdSettings.SNBigEndian := Node.Attributes.GetNamedItem('sn_bigendian').NodeValue = '1';

      if Node.Attributes.GetNamedItem('sn_logfile') <> nil then
        ProdSettings.SNLogFile := UTF16ToUTF8(Node.Attributes.GetNamedItem('sn_logfile').NodeValue);

      if Node.Attributes.GetNamedItem('batch_enabled') <> nil then
        ProdSettings.BatchEnabled := Node.Attributes.GetNamedItem('batch_enabled').NodeValue = '1';

      if Node.Attributes.GetNamedItem('batch_target') <> nil then
      begin
        OptVal := UTF16ToUTF8(Node.Attributes.GetNamedItem('batch_target').NodeValue);
        if IsNumber(OptVal) then ProdSettings.BatchTarget := StrToInt(OptVal);
      end;

      if  Node.Attributes.GetNamedItem('spi_speed') <> nil then
      begin
        OptVal := UTF16ToUTF8(Node.Attributes.GetNamedItem('spi_speed').NodeValue);

        if OptVal = '3Mhz' then MainForm.Menu3Mhz.Checked := true;
        if OptVal = '1_5Mhz' then MainForm.Menu1_5Mhz.Checked := true;
        if OptVal = '750Khz' then MainForm.Menu750Khz.Checked := true;
        if OptVal = '375Khz' then MainForm.Menu375Khz.Checked := true;
        if OptVal = '187_5Khz' then MainForm.Menu187_5Khz.Checked := true;
        if OptVal = '93_75Khz' then MainForm.Menu93_75Khz.Checked := true;
        if OptVal = '32Khz' then MainForm.Menu32Khz.Checked := true;
      end;

      if  Node.Attributes.GetNamedItem('ch347_spi_speed') <> nil then
      begin
        OptVal := UTF16ToUTF8(Node.Attributes.GetNamedItem('ch347_spi_speed').NodeValue);

        if OptVal = '60Mhz' then MainForm.MenuCH347SPIClock60MHz.Checked := true;
        if OptVal = '30Mhz' then MainForm.MenuCH347SPIClock30MHz.Checked := true;
        if OptVal = '15Mhz' then MainForm.MenuCH347SPIClock15MHz.Checked := true;
        if OptVal = '7_5Mhz' then MainForm.MenuCH347SPIClock7_5MHz.Checked := true;
        if OptVal = '3_75Mhz' then MainForm.MenuCH347SPIClock3_75MHz.Checked := true;
        if OptVal = '1_875MHz' then MainForm.MenuCH347SPIClock1_875MHz.Checked := true;
        if OptVal = '937_5KHz' then MainForm.MenuCH347SPIClock937_5KHz.Checked := true;
        if OptVal = '468_75KHz' then MainForm.MenuCH347SPIClock468_75KHz.Checked := true;
      end;


      if  Node.Attributes.GetNamedItem('mw_speed') <> nil then
      begin
        OptVal := UTF16ToUTF8(Node.Attributes.GetNamedItem('mw_speed').NodeValue);

        if OptVal = '32Khz' then MainForm.MenuMW32Khz.Checked := true;
        if OptVal = '16Khz' then MainForm.MenuMW16Khz.Checked := true;
        if OptVal = '8Khz' then MainForm.MenuMW8Khz.Checked := true;
      end;

      if  Node.Attributes.GetNamedItem('hw') <> nil then
      begin
        OptVal := UTF16ToUTF8(Node.Attributes.GetNamedItem('hw').NodeValue);

        if OptVal = 'usbasp' then
        begin
          MainForm.MenuHWUSBASP.Checked := true;
          SelectHW(CHW_USBASP);
        end;

        if OptVal = 'ch341a' then
        begin
          MainForm.MenuHWCH341A.Checked := true;
          SelectHW(CHW_CH341);
        end;

        if OptVal = 'ch347' then
        begin
          MainForm.MenuHWCH347.Checked := true;
          SelectHW(CHW_CH347);
        end;

        if OptVal = 'avrisp' then
        begin
          MainForm.MenuHWAVRISP.Checked := true;
          SelectHW(CHW_AVRISP);
        end;

        if OptVal = 'arduino' then
        begin
          MainForm.MenuHWArduino.Checked := true;
          SelectHW(CHW_ARDUINO);
        end;

        if OptVal = 'buzzpirat' then
        begin
          MainForm.MenuHWBuzzpirat.Checked := true;
          SelectHW(CHW_BUZZPIRAT);
        end;

        if OptVal = 'ft232h' then
        begin
          MainForm.MenuHWFT232H.Checked := true;
          SelectHW(CHW_FT232H);
        end;


      end;

      if  Node.Attributes.GetNamedItem('arduino_comport') <> nil then
      begin
        OptVal := UTF16ToUTF8(Node.Attributes.GetNamedItem('arduino_comport').NodeValue);

        Arduino_COMPort := OptVal;
        MainForm.MenuArduinoCOMPort.Caption := 'Arduino COMPort: '+ Arduino_COMPort;
      end;

      if  Node.Attributes.GetNamedItem('arduino_baudrate') <> nil then
      begin
        OptVal := UTF16ToUTF8(Node.Attributes.GetNamedItem('arduino_baudrate').NodeValue);

        Arduino_BaudRate := StrToInt(OptVal);
      end;

    end;
  end;

end;

initialization
  UIProxy := TUIProxy.Create;

finalization
  UIProxy.Free;

end.
