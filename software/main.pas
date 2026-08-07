unit main;

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
  opresult, prodlog, chipsave, flashops, imgcheck, ifd, chiptest,
  operationmodel, norplanner, norengine, spi25noradapter, prodcrypto,
  prodevidence, eepromengine, eepromadapters,
  pascalc, ScriptsFunc, ScriptEdit, comparewnd, appver,
  electricalpreflight, railreport, sessionstate, clocktune, clicontract,
  safemode,
  baseHW, UsbAspHW, ch341hw, ch347hw, avrisphw, arduinohw, buzzpirathw,
  serproghw, ezphw;

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
    MenuSPIClockSeparator: TMenuItem;
    MenuAutoTuneClock: TMenuItem;
    MenuCH347SPIClock468_75KHz: TMenuItem;
    MenuCH347SPIClock60MHz: TMenuItem;
    MenuCH347SPIClock30MHz: TMenuItem;
    MenuCH347SPIClock15MHz: TMenuItem;
    MenuCH347SPIClock7_5MHz: TMenuItem;
    MenuCH347SPIClock3_75MHz: TMenuItem;
    MenuCH347SPIClock1_875MHz: TMenuItem;
    MenuCH347SPIClock937_5KHz: TMenuItem;
    MenuCH347Vcc: TMenuItem;
    MenuCH347Vcc1V8: TMenuItem;
    MenuCH347Vcc3V3: TMenuItem;
    MenuCH347VccAuto: TMenuItem;
    GroupCH347Vcc: TGroupBox;
    RadioCH347Vcc1V8: TRadioButton;
    RadioCH347Vcc3V3: TRadioButton;
    RadioCH347VccAuto: TRadioButton;
    LabelCH347ChipVcc: TLabel;
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
    MenuAutoDetectChip: TMenuItem;
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
    MenuSerprogCOMPort: TMenuItem;
    MenuHWSERPROG: TMenuItem;
    MenuHWEZP: TMenuItem;
    MenuChipDoctor: TMenuItem;
    MenuCapacityTest: TMenuItem;
    MenuSurfaceScan: TMenuItem;
    MenuSkipFF: TMenuItem;
    //ตัวเลือกที่เพิ่มมาในรุ่น 4.4
    MenuFastRead: TMenuItem;
    MenuResetChip: TMenuItem;
    MenuVerifyErase: TMenuItem;
    MenuDoubleRead: TMenuItem;
    MenuCheckContact: TMenuItem;
    MenuScanImage: TMenuItem;
    MenuEraseRangeAuto: TMenuItem;
    MenuEraseRange4K: TMenuItem;
    MenuEraseRange32K: TMenuItem;
    MenuEraseRange64K: TMenuItem;
    MenuEraseSeparator: TMenuItem;
    MenuEraseChip: TMenuItem;
    MenuSmartWrite: TMenuItem;
    MenuSmartWritePreview: TMenuItem;
    MenuChecksum: TMenuItem;
    MenuSFDPDetect: TMenuItem;
    MenuBackgroundOps: TMenuItem;
    MenuDarkTheme: TMenuItem;
    SaveLogMenuItem: TMenuItem;
    MenuFillBuffer: TMenuItem;
    MenuSwapBytes: TMenuItem;
    MenuCheckIDBefore: TMenuItem;
    MenuAutoBackup: TMenuItem;
    MenuSafeMode: TMenuItem;
    MenuConnectionDoctor: TMenuItem;
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
    procedure MenuSmartWritePreviewClick(Sender: TObject);
    procedure SmartWriteEEPROM(Sender: TObject);
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
    procedure MenuConnectionDoctorClick(Sender: TObject);
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
    procedure ComboChipSizeChange(Sender: TObject);
    procedure ChangeLang(Sender: TObject);
    procedure ComboItem1Click(Sender: TObject);
    procedure MenuArduinoCOMPortClick(Sender: TObject);
    procedure MenuBuzzpiratCOMPortClick(Sender: TObject);
    procedure MenuSerprogCOMPortClick(Sender: TObject);
    procedure MenuHWSERPROGClick(Sender: TObject);
    procedure MenuHWEZPClick(Sender: TObject);
    procedure MenuChipDoctorClick(Sender: TObject);
    procedure MenuCapacityTestClick(Sender: TObject);
    procedure MenuSurfaceScanClick(Sender: TObject);
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
    procedure MenuCH347VccClick(Sender: TObject);
    procedure MenuAutoTuneClockClick(Sender: TObject);
    procedure MenuSafeModeClick(Sender: TObject);
    procedure RadioCH347VccChange(Sender: TObject);
    procedure SpeedButton1Click(Sender: TObject);
    procedure StartAddressEditChange(Sender: TObject);
    procedure StartAddressEditKeyPress(Sender: TObject; var Key: char);
    procedure VerifyFlash(BlankCheck: boolean = false);
  private
    FWorkflowPanel: TPanel;
    FWorkflowTitle: TLabel;
    FWorkflowState: TLabel;
    FWorkflowSep: TPanel;
    FWorkflowDetect: TButton;
    FWorkflowOpen: TButton;
    FWorkflowSmart: TButton;
    FWorkflowRead: TButton;
    FWorkflowVerify: TButton;
    FTelemetryPanel: TPanel;
    FTelemetryCards: array[0..3] of TPanel;
    FTelemetryTitles: array[0..3] of TLabel;
    FTelemetryValues: array[0..3] of TLabel;
    FOperationStartedAt: TDateTime;
    FLastOperationText: string;
    FLastOperationHint: string;
    procedure CreateWorkflowBar;
    procedure LayoutWorkflowBar;
    procedure UpdateWorkflowText;
    procedure UpdateWorkflowState;
    procedure CreateTelemetryPanel;
    procedure LayoutTelemetryPanel(Sender: TObject);
    procedure UpdateTelemetry;
    procedure BeginOperationTelemetry;
    procedure FinishOperationTelemetry;
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

  //ใช้จากโหมดบรรทัดคำสั่ง
  procedure SelectHW(programmer: THardwareList);
  procedure SetHardwareMenuCheck(HW: THardwareList);
  procedure PollProgrammer(Announce: boolean;
    StartupScan: boolean = False);
  function SelectChipAny(const AName: string): boolean;

  //หมอตรวจชิป (ไม่ทำลายข้อมูล) กับเครื่องพิสูจน์ความจุจริง (เขียนจริง
  //พร้อมสำรอง-กู้คืน) ใช้ร่วมกันทั้งเมนูและโหมดบรรทัดคำสั่ง
  procedure RunChipDoctor;
  procedure RunChipCapacityTest;
  //สแกนผิวทั้งชิป ทำลายข้อมูล: จบงานแล้วชิปว่างทั้งตัว
  procedure RunChipSurfaceScan;

  //งานทั้งชิปของ EZP2023+ เฟิร์มแวร์ตัวนั้นทำงานเป็นชิปทั้งตัว ไม่ใช่เพจ
  //Blank = True คือใช้คำสั่ง native erase แล้วอ่านกลับตรวจ FF ทุกไบต์
  procedure RunEZPWholeChipWrite(Blank: boolean);

  //อ่านเลขประจำตัวของชิปที่เสียบอยู่ ต้องเรียกตอนอยู่ในโหมดโปรแกรม
  //คืนสตริงว่างเมื่อชิปไม่มีเลขประจำตัว
  function ReadChipUID: string;

  //บันทึกชิปที่ตั้งค่าอยู่ตอนนี้ลง chiplist-user.xml
  function SaveCurrentChipToUserList(const AName: string): boolean;

  //ด่านตรวจบิตป้องกันการเขียนก่อนลบหรือเขียน
  //คืน False เมื่อพื้นที่เป้าหมายถูกล็อกอยู่และผู้ใช้ไม่ยืนยัน
  function ProtectionGuardOK(StartAddr, Len: cardinal): boolean;

  //ตรวจภาพในบัฟเฟอร์กับไฟล์งาน คืน False เมื่อไม่ตรง
  function JobFileGuardOK(Size: cardinal): boolean;

  //เขียนหนึ่งบรรทัดลงบันทึกการผลิต ใช้ผลของงานล่าสุดเป็นตัวตัดสินผ่านหรือไม่ผ่าน
  procedure WriteProdLogEntry(Size, CRC: cardinal; const UID: string);

  //เข้าโหมดโปรแกรม SPI ด้วยความเร็วที่ตั้งไว้บนหน้าจอ
  //โหมดบรรทัดคำสั่งต้องเรียกเองสำหรับงานที่ไม่ได้ผ่านปุ่มบนหน้าจอ
  function EnterProgModeSPI25: boolean;

  //สถานะของ session ที่ใช้ร่วมกันทั้งหน้าจอและบรรทัดคำสั่ง กติกาว่างานไหน
  //เริ่มได้เมื่อไรอยู่ใน sessionstate ที่เดียว ไม่ได้กระจายอยู่ตามปุ่ม
  //
  //เหตุการณ์ถูกป้อนที่ "ทางรวม" ไม่ใช่ที่ปุ่มทีละปุ่ม: OpenDevice สำหรับ
  //เครื่อง, ApplyCH347Vcc สำหรับราง, MPHexEditorExChange สำหรับบัฟเฟอร์,
  //ด่านตรวจ ID ก่อนงานสำหรับชิป และ BenchPreflightOK สำหรับด่านไฟฟ้า
  //ทางรวมพวกนี้คือที่ที่ข้อเท็จจริงเปลี่ยนจริง ๆ การไปดักที่ปุ่มจะพลาดทาง
  //ที่ไม่มีใครนึกถึงเสมอ
  function Session: TProgrammingSession;

  //ป้อนเหตุการณ์เข้าเครื่องสถานะ ล้มเหลวไม่ทำให้งานล้ม แต่เขียนลง log ไว้
  //เพราะเหตุการณ์ที่ถูกปฏิเสธแปลว่าที่ใดที่หนึ่งเดินผิดลำดับ
  procedure NoteSession(Event: TSessionEvent);

  //ด่านลำดับขั้น: งานนี้เริ่มได้หรือยัง คืน False พร้อมเขียนเหตุผลลง log
  function SessionAllows(Op: TSessionOperation): boolean;

  //สี่บรรทัดที่บอกสภาพรางไฟจริง ๆ ตอนนี้ (ขอไปเท่าไร วัดได้เท่าไร กระแส
  //เท่าไร มีไฟย้อนมาไหม) เขียนลง log ให้ผู้ใช้เห็นก่อนงานเริ่ม
  procedure LogRailReport;

  //ด่านไฟฟ้าก่อนปลุกบัส คืน False เมื่อมีเหตุที่ตัดสินได้แล้วว่าห้ามเดินต่อ
  //เช่นรางไฟอยู่นอกช่วงที่ชิปรับได้ หรือระดับสัญญาณสูงเกินกว่าที่ชิปทน
  //เรื่องที่ "ยังไม่มีใครวัด" จะเตือนแล้วปล่อยผ่าน ไม่ใช่ปฏิเสธ
  function BenchPreflightOK(Destructive: boolean): boolean;

  //หาความเร็ว SPI ที่สายชุดนี้รับไหวจริง แล้วติ๊กเมนูให้ตามนั้น
  //ต้องอยู่ในโหมดโปรแกรมแล้ว (เปิดอุปกรณ์ไว้) ก่อนเรียก
  //คืน False เมื่อหาไม่ได้ ซึ่งรวมถึงกรณีที่ต่อไม่ติดกับกรณีที่ไม่เสถียร
  //แม้ที่คล็อกช้าที่สุด สองอย่างนี้แยกกันในข้อความที่เขียนลง log
  function AutoTuneSPIClock: boolean;

  //อ่านพื้นที่ตัวอย่างสองรอบแล้วเทียบ ก่อนจะยอมให้ลบหรือเขียน
  //ชิปที่ตอบคำถามเดียวกันสองแบบ แปลว่าสำรองที่เพิ่งอ่านมาก็เชื่อไม่ได้
  //ต้องอยู่ในโหมดโปรแกรมแล้วก่อนเรียก
  function ConnectionStableForDestructive: boolean;

  //ตรวจซ้ำในเซสชัน USB ใหม่หลังเขียนผ่านรอบแรก ไม่ใช่ power cycle จริง
  //เพราะไม่มีบอร์ดไหนที่รองรับตัดไฟฝั่งเป้าหมายได้
  function ReVerifyInFreshSession(StartAddr, Len: cardinal): boolean;

  //ดัมป์ตาราง SFDP ดิบ ๆ ลงไฟล์ ต้องอยู่ในโหมดโปรแกรมแล้ว
  function DumpSFDPToFile(const FileName: string; out ErrMsg: string): boolean;

  //พิมพ์คำอธิบายตาราง SFDP ลง log
  procedure LogSFDPDetails(const Info: TSFDPInfo);

const
  SPI_CMD_25             = 0;
  SPI_CMD_45             = 1;
  SPI_CMD_KB             = 2;
  SPI_CMD_95             = 3;

  ChipListFileName       = 'chiplist.xml';
  //ตารางชิปเพิ่มเติมที่แปลงมาจาก flashrom ไฟล์นี้เป็น GPL ไม่ใช่ MIT
  //จึงแยกไว้ต่างหาก ถ้าไม่มีไฟล์ก็ทำงานได้ตามปกติ
  ChipListFile2Name      = 'chiplist-flashrom.xml';
  //ชิปที่ผู้ใช้เพิ่มเอง อัปเดตโปรแกรมทับแล้วไม่หาย
  ChipListFile3Name      = UserChipListName;
  //ตารางชิปที่แปลงมาจากฐานข้อมูลของเครื่องโปรแกรม EZP ด้วย tools/import_ezp.py
  //เป็นข้อมูลของบุคคลที่สาม จึงแยกไฟล์ไว้แบบเดียวกับ chiplist-flashrom.xml
  //ลบไฟล์นี้ทิ้งแล้วโปรแกรมก็ยังทำงานได้ตามปกติ
  ChipListFile4Name      = 'chiplist-ezp.xml';
  //ตารางชิปจากฐานข้อมูลของโครงการ IMSProg (GPL-3+) แปลงด้วยเครื่องมือ
  //ตัวเดียวกับของ EZP เพราะใช้เรคคอร์ด 68 ไบต์แบบเดียวกัน แยกไฟล์ไว้
  //ตามสัญญาอนุญาตเช่นเคย ลบทิ้งได้โดยไม่กระทบโปรแกรม
  ChipListFile5Name      = 'chiplist-imsprog.xml';
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
    Vcc: string;         //แรงดันใช้งานจาก chiplist.xml เช่น 1.8 ว่างคือไม่ระบุ

    Script: string;
  end;


var
  MainForm: TMainForm;
  ChipListFile: TXMLDocument;
  ChipListFile2: TXMLDocument;
  ChipListFile3: TXMLDocument;
  ChipListFile4: TXMLDocument;
  ChipListFile5: TXMLDocument;
  SettingsFile: TXMLDocument;
  CurrentICParam: TCurrentICParam;
  ScriptEngine: TPasCalc;
  RomF: TMemoryStream;

  //AsProgrammer ย้ายไปอยู่ใน basehw ซึ่งเป็นที่ที่ชนิดของมันประกาศอยู่
  //หน่วยที่คุยกับฮาร์ดแวร์จึงไม่ต้อง uses main อีกต่อไป

  Buzzpirat_ClocKhz: integer = 0;
  Buzzpirat_Pulls: integer = 0;
  Buzzpirat_Power: integer = 0;
  Arduino_COMPort: string;
  Arduino_BaudRate: integer = 1000000;
  Buzzpirat_COMPort: string;
  //serprog วิ่งบน USB-CDC เป็นหลัก ค่า baud จึงเป็นพิธี แต่ UART จริงก็มี
  Serprog_COMPort: string;
  Serprog_BaudRate: integer = 115200;

  //สถานะที่วาดเป็นไฟบอกสถานะในแผงด้านซ้าย
  ProgrammerPresent: boolean = False;
  ChipDetected: boolean = False;

  //หน้าต่างหลักขึ้นแล้วหรือยัง ตรวจชิปอัตโนมัติอาจเปิดไดอะล็อก
  //ซึ่งห้ามเกิดตอนที่หน้าต่างยังสร้างไม่เสร็จ
  AppReady: boolean = False;
  //แยกการตรวจที่เกิดจาก startup/hot-plug ออกจากการกด Read ID ด้วยมือ
  //เพื่อไม่ให้หน้าต่างเลือกรุ่นเด้งขึ้นเองเมื่อ JEDEC ID ใช้ร่วมกันหลาย suffix
  AutomaticChipDetection: boolean = False;

  //ทำงานจากบรรทัดคำสั่ง ไม่มีคนนั่งอยู่หน้าจอที่จะตอบไดอะล็อกได้
  //ทุกจุดที่ปกติจะถาม ต้องตัดสินใจเองแบบปลอดภัยไว้ก่อน
  CLIMode: boolean = False;
  //ผู้ใช้สั่ง --force มาแล้ว ยอมข้ามด่านที่ปกติจะปฏิเสธ
  CLIForce: boolean = False;

  //เลขประจำตัวของชิปที่อ่านได้ครั้งล่าสุด ใช้ตอนเขียนบันทึกการผลิต
  LastChipUID: string = '';
  //True only when the complete eight-byte 4Bh reply was transferred.  An
  //empty UID after an exact reply means "unsupported/all blank"; an empty UID
  //after a short reply means the electrical transaction itself was invalid.
  LastChipUIDTransferExact: boolean = False;

  //คำเตือนจากการดูตัวข้อมูลที่อ่านมาได้ล่าสุด สตริงว่างแปลว่าไม่มีอะไรน่าสงสัย
  //เก็บไว้ให้โหมดบรรทัดคำสั่งรายงานต่อได้ โดยไม่ต้องไปแกะข้อความจาก log
  LastImageWarning: string = '';

  //--- ชิปใหม่หรือชิปเก่า: สิ่งที่โปรแกรมรู้จริงเกี่ยวกับชิปที่เสียบอยู่ ---
  //
  //แถบ Safe workflow เดิมมองเห็นแค่ "มีชิปถูกเลือกไหม" กับ "มีข้อมูลในบัฟเฟอร์
  //ไหม" ซึ่งทำให้ชิปเปล่าจากโรงงานกับชิปที่มีข้อมูลชิ้นเดียวในโลกอยู่ข้างใน
  //ได้ไฟเขียวหน้าตาเหมือนกันเป๊ะ ทั้งที่การกดเขียนบนตัวหลังคือการทำลายถาวร
  //และค่าเริ่มต้นของ "สำรองก่อนเขียน" คือปิดอยู่
  ChipContentKnown: (ckUnknown, ckBlank, ckHasData) = ckUnknown;
  //ความรู้ข้างบนเป็นของชิปตัวไหน ถ้าตัวตนที่เลือกอยู่เปลี่ยนไป ความรู้เก่า
  //เป็นโมฆะทันที ห้ามเอาไปตัดสินใจแทนชิปตัวใหม่
  ChipContentOwner: string = '';
  //ตัวตนของชิปได้รับการยืนยันกับซ็อกเก็ตจริงหรือยัง
  //ChipDetected เป็นแค่ "ถูกเลือกไว้ในหน้าจอ" ซึ่งเป็นคนละเรื่องกัน
  ChipIdentityConfirmed: boolean = False;

  //บัฟเฟอร์นี้มาจากไหน การเขียนไฟล์ทับชิปเก่ากับการเขียนสิ่งที่เพิ่งอ่าน
  //ออกมาจากชิปตัวเดียวกัน อันตรายไม่เท่ากันเลย
  BufferSource: (bsNone, bsFile, bsChip, bsEdited) = bsNone;
  BufferSourceName: string = '';

  //โหมดบรรทัดคำสั่งสั่งจำนวนรอบการอ่านมาเองได้ 0 = ใช้ค่าจากหน้าจอ
  CLIReadPasses: integer = 0;

  //รหัส 9Fh ที่อ่านได้ครั้งล่าสุด ใช้ตอนบันทึกชิปใหม่ลงตารางของผู้ใช้
  LastID9F: string = '';

  //บอร์ด CH347 ที่เสียบอยู่พิสูจน์แล้วว่าสลับแรงดันด้วย GPIO ได้
  //
  //จำข้ามการปิดอุปกรณ์ เพราะด่านเตือนแรงดันทำงานก่อนงานจะเปิดอุปกรณ์
  //และตัวชี้ทางทำงานหลังงานปิดอุปกรณ์ไปแล้ว ทั้งคู่ต้องรู้ว่าเมนูแรงดัน
  //กดแล้วมีผลจริงไหม จะได้ไม่ชี้ไปเมนูที่ไม่ทำอะไรบนบอร์ดรุ่นเก่า
  //ค่าอัปเดตทุกครั้งที่เปิด CH347 สำเร็จ เสียบบอร์ดคนละรุ่นก็ตามทัน
  CH347VoltageControlSeen: boolean = False;

  //กล่องเลือกแรงดันบนหน้าหลักกำลังถูกตั้งค่าจากโค้ด OnChange ของปุ่มใน
  //กล่องยิงทั้งตอนผู้ใช้คลิกและตอนโค้ดสะท้อนสถานะเมนู กระจกต้องไม่สะท้อนกลับ
  CH347VccPanelUpdating: boolean = False;

  //ไฟล์งานที่โหลดไว้ ถ้ามี
  CurrentJob: TJobFile;
  //A configured job that failed to load must never be indistinguishable from
  //"no job configured".  The old Loaded=False shortcut silently disabled the
  //production guard after a missing, truncated, or malformed job file.
  CurrentJobLoadError: string = '';

  //เลขรันนิ่งอัตโนมัติและการผลิตเป็นชุด
  //อยู่ในส่วน interface เพราะโหมดบรรทัดคำสั่งต้องทับค่าบางตัวได้
  ProdSettings: TProdSettings;

  //Set only by authenticated production-job admission in cli.pas.  Smart
  //Write captures these values into its evidence bridge before execution.
  StrictProductionMode: boolean = False;
  StrictProductionJobID: string = '';
  StrictProductionJobRevision: cardinal = 0;
  StrictEvidenceDirectory: string = '';
  //กุญแจของสถานีสำหรับเซ็นหลักฐาน (ตัวเดียวกับที่ตรวจ manifest) ถูกตั้งค่า
  //เฉพาะช่วง strict run และถูกล้างใน finally ของ cli.pas เสมอ
  StrictEvidenceKeyID: string = '';
  StrictEvidenceKey: TBytes = nil;
  //OperationID ของ strict run ล่าสุด ให้ cli.pas เอาไปบันทึกลงสถานะกันซ้ำ
  LastStrictRunID: string = '';

  //โหมดดูแผนอย่างเดียวของ Smart Write: อ่านชิป วางแผน พิมพ์แผน แล้วจบ
  //โดยไม่แตะ status register และไม่ส่งคำสั่งทำลายข้อมูลใด ๆ (--plan-only)
  SmartWritePlanOnly: boolean = False;
  StrictProductionUIDRequired: boolean = False;
  StrictProductionReadPasses: cardinal = 2;
  StrictProductionProfileHash: string = '';
  StrictProductionImageHash: string = '';
  StrictProductionExpectedID: string = '';
  StrictProductionPageSize: cardinal = 0;
  StrictProductionEraseSize: cardinal = 0;
  StrictProductionEraseOpcode: byte = 0;
  StrictAdmittedProgrammerID: string = '';

  //Identity and digest of the exact personalized image used by the current
  //write.  Never regenerate a random serial while logging the same unit.
  CurrentSerial: TSerialAllocation;
  CurrentSerialValid: boolean = False;
  CurrentSerialReserved: boolean = False;
  LastProgramCRC: cardinal = 0;
implementation


var
  TimeCounter: TDateTime;
  CurrentLang: string = 'en';
  //Set only after a trusted snapshot has been atomically published.  Plan
  //previews use this to distinguish an in-memory safety snapshot from a
  //recoverable backup file without ever promising a file that was not saved.
  LastBackupFileName: string = '';
  //Older settings files have no marker, so existing users see the new doctor
  //once.  Afterwards it remains available from Options.
  ConnectionDoctorSeen: boolean = False;

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

  //Bridges the headless typed NOR executor to the existing GUI/CLI result
  //surface.  It contains no mutable operation inputs: those are captured in
  //TOperationRequest and TNORPlan before the device worker starts.
  TNORUIBridge = class
  public
    EvidenceSize: cardinal;
    EvidenceCRC: cardinal;
    EvidenceUID: string;
    EvidenceCommitted: boolean;
    StrictMode: boolean;
    StrictJobID: string;
    StrictJobRevision: cardinal;
    EvidenceDirectory: string;
    EvidenceKeyID: string;
    EvidenceKey: TBytes;
    OperatorName: string;
    ProgrammerID: string;
    ReadPasses: cardinal;
    SerialText: string;
    PhysicalVerifyCompleted: boolean;
    procedure Receive(const Event: TOperationEvent);
    function CommitEvidence(const Request: TOperationRequest;
      out ErrorText: string): boolean;
    function CommitFailureEvidence(const Request: TOperationRequest;
      const FailureText: string; out ErrorText: string): boolean;
  end;

var
  UIProxy: TUIProxy;
  ActiveNORCancellation: TCancellationToken = nil;

  //กันการเรียกซ้อน เพราะเมนูไม่เหมือนปุ่มบนแถบเครื่องมือ
  //มันยังคลิกได้อยู่ตอนที่ thread หลักกำลังปั๊ม message
  OperationRunning: boolean = False;

  //สถานะหน้าจอที่อ่านเก็บไว้บน thread หลักก่อนเริ่มงาน
  //thread เบื้องหลังต้องอ่านจากตรงนี้ ห้ามอ่านจาก control โดยตรง
  OpUI: record
    ChipSize: cardinal;
    SkipFF: boolean;
    AutoCheck: boolean;
    IgnoreBusy: boolean;
    FastRead: boolean;
    VerifyErase: boolean;
    ScanImage: boolean;
    ReadPasses: integer;   //อ่านซ้ำกี่รอบแล้วเทียบกัน 1 = รอบเดียวแบบเดิม
    I2CAddrType: integer;  //ชนิดแอดเดรสของ I2C อ่านจาก control ไม่ได้บน thread
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

//The telemetry cards deliberately use IEC units for byte counts and rates.
//They describe measured application throughput, not an inferred SPI clock.
function FormatTelemetryBytes(Value: QWord): string;
begin
  if Value >= QWord(1024) * 1024 * 1024 then
    Result := Format('%.2f GiB', [Value / (1024.0 * 1024 * 1024)])
  else if Value >= QWord(1024) * 1024 then
    Result := Format('%.2f MiB', [Value / (1024.0 * 1024)])
  else if Value >= 1024 then
    Result := Format('%.2f KiB', [Value / 1024.0])
  else
    Result := IntToStr(Value) + ' B';
end;

function FormatTelemetryRate(BytesPerSecond: double): string;
begin
  if BytesPerSecond >= 1024 * 1024 then
    Result := Format('%.2f MiB/s', [BytesPerSecond / (1024 * 1024)])
  else if BytesPerSecond >= 1024 then
    Result := Format('%.1f KiB/s', [BytesPerSecond / 1024])
  else
    Result := Format('%.0f B/s', [BytesPerSecond]);
end;

function FormatTelemetryElapsed(Milliseconds: int64): string;
begin
  if Milliseconds < 1000 then
    Result := IntToStr(Milliseconds) + ' ms'
  else if Milliseconds < 60000 then
    Result := Format('%.1f s', [Milliseconds / 1000.0])
  else
    Result := Format('%d:%.2d', [Milliseconds div 60000,
                                 (Milliseconds div 1000) mod 60]);
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

//ตัวนับความคืบหน้าของงานที่กำลังทำอยู่
//
//เดิมหลายเส้นทางนับด้วยการอ่านค่าเดิมจาก ProgressBar แล้วบวกหนึ่ง ซึ่งอ่าน
//control จาก thread เบื้องหลังไม่ได้ นั่นคือเหตุผลเดียวที่เส้นทางเหล่านั้น
//ยังทำงานเบื้องหลังไม่ได้ ตัวนับที่เก็บไว้เองแก้ปัญหานั้นโดยไม่ต้องแตะอะไรอีก
var
  ProgressCounter: integer = 0;

procedure ProgressReset(Max: integer);
begin
  ProgressCounter := 0;
  SetProgressMax(Max);
  SetProgressPos(0);
end;

procedure ProgressStep(By: integer = 1);
begin
  Inc(ProgressCounter, By);
  SetProgressPos(ProgressCounter);
end;

procedure TNORUIBridge.Receive(const Event: TOperationEvent);
var
  Done, Total: cardinal;
begin
  case Event.Kind of
    evProgress:
      begin
        if Event.BytesDone > High(cardinal) then Done := High(cardinal)
        else Done := cardinal(Event.BytesDone);
        if Event.BytesTotal > High(cardinal) then Total := High(cardinal)
        else Total := cardinal(Event.BytesTotal);
        OpProgress(Done, Total);
        if Total <= cardinal(High(integer)) then
        begin
          SetProgressMax(integer(Total));
          if Done <= cardinal(High(integer)) then SetProgressPos(integer(Done));
        end;
      end;
    evWarning:
      LogPrint('NOR warning: ' + Event.MessageText);
  end;
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

  OpUI.FastRead    := MainForm.MenuFastRead.Checked;
  OpUI.VerifyErase := MainForm.MenuVerifyErase.Checked;
  OpUI.ScanImage   := MainForm.MenuScanImage.Checked;
  OpUI.I2CAddrType := MainForm.ComboAddrType.ItemIndex;

  if CLIReadPasses > 0 then
    OpUI.ReadPasses := CLIReadPasses
  else if MainForm.MenuDoubleRead.Checked then
    OpUI.ReadPasses := 2
  else
    OpUI.ReadPasses := 1;
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
  Result := OperationCancellationRequested;
  if Result then
  begin
    //Only report the request once.  Busy waits deliberately keep polling the
    //command already in flight; cancellation prevents the next command.
    if not LastOp.Cancelled then
    begin
      LogPrint(STR_USER_CANCEL);
      OpCancel;
    end;

    if InWorkerThread then
      UIProxy.ProgressReset
    else
    begin
      MainForm.ProgressBar.Style := pbstNormal;
      SetProgressPos(0);
    end;
  end;
end;

procedure LoadXML;
var
  RootNode: TDOMNode;
begin
  ChipListFile := nil;
  ChipListFile2 := nil;
  ChipListFile3 := nil;
  ChipListFile4 := nil;
  ChipListFile5 := nil;
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

  //ชิปที่ผู้ใช้บันทึกเอง ค้นทีหลังสองไฟล์แรก
  if FileExists(ChipListFile3Name) then
  begin
    try
      ReadXMLFile(ChipListFile3, ChipListFile3Name);
    except
      on E: EXMLReadError do
      begin
        ShowMessage(E.Message);
        ChipListFile3 := nil;
      end;
    end;
  end;

  if FileExists(ChipListFile4Name) then
  begin
    try
      ReadXMLFile(ChipListFile4, ChipListFile4Name);
    except
      on E: EXMLReadError do
      begin
        ShowMessage(E.Message);
        ChipListFile4 := nil;
      end;
    end;
  end;

  if FileExists(ChipListFile5Name) then
  begin
    try
      ReadXMLFile(ChipListFile5, ChipListFile5Name);
    except
      on E: EXMLReadError do
      begin
        ShowMessage(E.Message);
        ChipListFile5 := nil;
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
  UpdateWorkflowText;
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
//
//ชี้ไปที่ "ไดรเวอร์ตัวไหนของใคร" ไม่ใช่พาธในโฟลเดอร์ drivers\ อีกต่อไป
//ตัวติดตั้งของผู้ผลิตถูกย้ายออกจาก source tree แล้ว (ดู vendor-manifest.json)
//การชี้ไปยังไฟล์ที่ clone ใหม่ไม่มี คือคำแนะนำที่พาไปเจอทางตัน
procedure LogDriverHint;
begin
  case AsProgrammer.Current_HW of
    CHW_CH341:
      LogPrint(STR_DRIVER_HINT + 'the WCH CH341PAR driver');
    CHW_CH347:
      LogPrint(STR_DRIVER_HINT + 'the WCH CH34xPAR driver');
    CHW_FT232H:
      LogPrint(STR_DRIVER_HINT + 'the FTDI D2XX (CDM) driver');
    CHW_USBASP, CHW_AVRISP:
      LogPrint(STR_DRIVER_HINT + 'libusb-win32, installed with Zadig');
    CHW_ARDUINO, CHW_BUZZPIRAT:
      LogPrint(STR_DRIVER_HINT_COM);
  end;
  if AsProgrammer.Current_HW in [CHW_CH341, CHW_CH347, CHW_FT232H,
                                 CHW_USBASP, CHW_AVRISP] then
    LogPrint('see vendor-manifest.json for the vendor, version and SHA-256 ' +
             'of each driver package');
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

  //DevOpen ของ CH347 เพิ่งบังคับ 1.8V ไปแล้วถ้าบอร์ดสลับได้ จดไว้ตรงนี้
  //เพราะหลังปิดอุปกรณ์ SupportsTargetVoltage กลับเป็น False ทั้งที่ข้อเท็จจริง
  //ของบอร์ดไม่ได้หายไปไหน
  if AsProgrammer.Current_HW = CHW_CH347 then
    CH347VoltageControlSeen := AsProgrammer.Programmer.SupportsTargetVoltage;

  LogPrint(STR_CURR_HW+AsProgrammer.Programmer.HardwareName);
  //สภาพรางไฟตอนนี้ ทันทีที่เปิดอุปกรณ์ได้ ก่อนงานใด ๆ จะเริ่ม
  //ที่สำคัญกว่าตัวเลขคือบรรทัดที่บอกว่าอะไรที่เครื่องนี้ "วัดไม่ได้"
  LogRailReport;

  //โปรแกรมนี้เปิดและปิดอุปกรณ์ทุกงาน การนับ "เปิดอุปกรณ์" เป็นการเริ่ม
  //เซสชันใหม่ทุกครั้งจะล้างข้อเท็จจริงทิ้งทุกงาน ซึ่งไม่ใช่สิ่งที่ต้องการ
  //เซสชันเริ่มเมื่อยังไม่เคยเริ่ม ที่เหลือคือการเปิดซ้ำของเซสชันเดิม
  if Session.State = ssDisconnected then
  begin
    NoteSession(seProgrammerOpened);
    //"ตั้งรางแล้ว" ที่นี่แปลว่า "โปรแกรมรู้ว่ากำลังจ่ายระดับไหนอยู่" ไม่ใช่
    //"ผู้ใช้เพิ่งเลือกมา" ซึ่งเป็นความจริงตั้งแต่เปิดอุปกรณ์: บอร์ดที่ตั้ง
    //ไม่ได้จ่ายระดับตายตัว ส่วน CH347 ตั้งต้นที่ 1.8V ตอนจ่ายไฟ
    //
    //คุณค่าของขั้นนี้อยู่ที่ seRailChanged ที่ล้างการตรวจเจอชิปทิ้งเมื่อราง
    //ขยับ ไม่ใช่ที่การบังคับให้ผู้ใช้กดเลือกแรงดันก่อนถึงจะอ่านชิปได้ ซึ่ง
    //จะทำให้ชิปที่ยังไม่รู้ว่าคืออะไรอ่านไม่ได้เลย ทั้งที่การอ่านคือวิธีเดียว
    //ที่จะรู้ว่ามันคืออะไร
    NoteSession(seRailConfigured);
  end;
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

//ตัวช่วยที่แถบ Safe workflow ต้องใช้ แต่นิยามอยู่ท้ายไฟล์
function IsEEPROMSmartWriteTarget: boolean; forward;
function CurrentSectorSize: cardinal; forward;
function CurrentSectorOpcode: byte; forward;

//กุญแจของ "ชิปตัวที่ตั้งค่าไว้ตอนนี้"
//
//ใช้ผูกความรู้เรื่องเนื้อในชิปกับตัวตนที่มันถูกอ่านมา พอผู้ใช้เปลี่ยนชิป
//เปลี่ยนขนาด หรือสลับโปรโตคอล กุญแจจะเปลี่ยน ความรู้เก่าจึงถูกทิ้งเอง
//โดยไม่ต้องไล่ล้างตามทุกจุดที่แก้ค่าได้
function CurrentChipKey: string;
begin
  //แอดเดรสเริ่มต้องอยู่ในกุญแจด้วย ไม่งั้นการอ่านจากออฟเซ็ตหนึ่งจะถูกจำว่า
  //เป็นความรู้เรื่องทั้งชิป: อ่านครึ่งบนที่ว่างเปล่าแล้วเลื่อนกลับมาที่ 0
  //แถบจะประกาศว่า "ชิปเปล่า" ทั้งที่ครึ่งล่างมีบูตโหลดเดอร์อยู่
  Result := IntToStr(Ord(MainForm.RadioSPI.Checked)) + '/' +
            IntToStr(Ord(MainForm.RadioI2C.Checked)) + '/' +
            IntToStr(Ord(MainForm.RadioMW.Checked)) + '/' +
            IntToStr(MainForm.ComboSPICMD.ItemIndex) + '/' +
            CurrentICParam.Name + '/' + LastID9F + '/' +
            Trim(MainForm.ComboChipSize.Text) + '/' +
            UpperCase(Trim(MainForm.StartAddressEdit.Text));
end;

//ตัวตนของชิปถือว่าได้รับการยืนยันแล้วหรือยัง
//
//นอกจากธงที่ตั้งตอนตรวจสำเร็จ ยังนับกรณีที่รหัสซึ่งซ็อกเก็ตตอบมาล่าสุดตรงกับ
//รหัสของชิปที่เลือกอยู่ด้วย ซึ่งครอบคลุมทั้งการเลือกจากรายการที่รหัสตรงหลายตัว
//และการที่ผู้ใช้เลือกเองแล้วบังเอิญตรงกับของจริง
//
//ชิปที่ไม่มีรหัสให้เทียบเลย (ตารางไม่ได้ระบุ หรือมาจาก SFDP ซึ่งตั้ง ID เป็น
//ค่าว่างโดยตั้งใจ) ไม่มีทางยืนยันด้วยวิธีนี้ได้ จึงต้องไม่ไปทวงถามผู้ใช้
//ตลอดกาล ให้ถือว่า "ไม่มีอะไรให้ยืนยัน" แทน
function ChipIdentityUnproven: boolean;
var
  Expected: string;
begin
  Result := False;
  if ChipIdentityConfirmed then Exit;
  Expected := UpperCase(Trim(CurrentICParam.ID));
  if (Expected = '') or (Expected = '0') then Exit; //ไม่มีอะไรให้เทียบ
  if (LastID9F <> '') and (Expected = LastID9F) then Exit;
  Result := True;
end;

//ความรู้เรื่องเนื้อในชิปยังใช้ได้อยู่หรือไม่
function ChipContentValid: boolean;
begin
  Result := (ChipContentKnown <> ckUnknown) and
            (ChipContentOwner = CurrentChipKey);
end;

//บันทึกว่าชิปที่เพิ่งอ่านมาทั้งตัวนั้นเปล่าหรือมีข้อมูล
//
//FF ล้วนมีสองความหมายเสมอ: ชิปเปล่าจริง ๆ กับบัสที่ไม่มีใครขับ แยกสองอย่าง
//นี้ได้ต่อเมื่อชิปตอบรหัส 9Fh มาแล้วเท่านั้น ถ้าตัวตนยังไม่ถูกยืนยัน ห้าม
//ประกาศว่า "ชิปเปล่า" เพราะคำนั้นจะกลายเป็นใบอนุญาตให้เขียนทับ
procedure RememberChipContent(Stream: TMemoryStream);
var
  S: TImgStats;
begin
  ChipContentKnown := ckUnknown;
  ChipContentOwner := '';
  if (Stream = nil) or (Stream.Size = 0) then Exit;

  S := imgcheck.ScanImage(PByte(Stream.Memory), Stream.Size);
  if S.FFCount = S.Size then
  begin
    //ต้องมีหลักฐานว่าชิปตอบจริงก่อนถึงจะพูดคำว่า "เปล่า" ได้
    //SPI ใช้รหัสที่อ่านได้เป็นหลักฐาน ส่วน I2C ต้องมี ACK อยู่แล้วไม่งั้น
    //อ่านไม่ผ่านตั้งแต่แรก ตระกูลอื่นพิสูจน์ไม่ได้ ให้คงสถานะ "ไม่รู้" ไว้
    if not (ChipIdentityConfirmed or
            (MainForm.RadioSPI.Checked and (LastID9F <> '')) or
            MainForm.RadioI2C.Checked) then Exit;
    ChipContentKnown := ckBlank;
  end
  else
    //ข้อมูลจริงที่ไม่ใช่ FF ล้วน ออกมาจากบัสที่ตายแล้วไม่ได้ จึงเชื่อได้เลย
    ChipContentKnown := ckHasData;
  ChipContentOwner := CurrentChipKey;
end;

//เนื้อในชิปเปลี่ยนไปแล้ว (เพิ่งเขียนหรือเพิ่งลบ) แต่ตัวตนยังเป็นตัวเดิม
procedure ForgetChipContent;
begin
  ChipContentKnown := ckUnknown;
  ChipContentOwner := '';
end;

//เลือกชิปตัวใหม่ด้วยมือ: สิ่งที่รู้เรื่องเนื้อในและธงยืนยันตัวตนตกไป
//แต่รหัสที่ซ็อกเก็ตเคยตอบมายังเป็นข้อเท็จจริงของซ็อกเก็ต ไม่ใช่ของการเลือก
//จึงเก็บไว้ (ผู้ใช้ที่เลือกชิปตรงกับที่เสียบอยู่จริงต้องนับว่าพิสูจน์แล้ว)
procedure ForgetChipSelectionKnowledge;
begin
  ForgetChipContent;
  ChipIdentityConfirmed := False;
end;

//ซ็อกเก็ตเปลี่ยนไปแล้ว หรือการตรวจล้มเหลว: ทุกอย่างรวมถึงรหัสที่อ่านได้
//
//ต้องล้างรหัสด้วย ไม่งั้นรหัสของชิปตัวก่อนจะกลายเป็น "หลักฐาน" ให้ชิปตัวใหม่
//การตรวจที่ล้มเหลวจะไม่เตือน และที่แย่กว่านั้นคือมันเป็นใบอนุญาตให้เรียก
//ดัมป์ FF ล้วนว่า "ชิปเปล่า" ทั้งที่ซ็อกเก็ตเงียบสนิท
procedure ForgetChipKnowledge;
begin
  ForgetChipSelectionKnowledge;
  LastID9F := '';
end;

//บัฟเฟอร์มาจากไฟล์ ไม่ใช่จากชิปที่เสียบอยู่
procedure NoteBufferFromFile(const FileName: string);
begin
  BufferSource := bsFile;
  BufferSourceName := ExtractFileName(FileName);
  MainForm.UpdateWorkflowState;
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

  if MainForm.FWorkflowPanel <> nil then
  begin
    MainForm.FWorkflowPanel.Color := ChromeColor;
    MainForm.FWorkflowTitle.Font.Color := TextColor;
    MainForm.FWorkflowState.Font.Color := TextColor;

    MainForm.FWorkflowDetect.Color := SurfaceColor;
    MainForm.FWorkflowDetect.Font.Color := TextColor;
    MainForm.FWorkflowOpen.Color := SurfaceColor;
    MainForm.FWorkflowOpen.Font.Color := TextColor;
    MainForm.FWorkflowRead.Color := SurfaceColor;
    MainForm.FWorkflowRead.Font.Color := TextColor;
    MainForm.FWorkflowVerify.Color := SurfaceColor;
    MainForm.FWorkflowVerify.Font.Color := TextColor;

    MainForm.FWorkflowSmart.Color := SurfaceColor;
    MainForm.FWorkflowSmart.Font.Color := AccentColor;

    if MainForm.FWorkflowSep <> nil then
      MainForm.FWorkflowSep.Color := TextColor;

    //ตัวหนาเป็นของ UpdateWorkflowState ซึ่งเน้นเฉพาะขั้นที่กดได้จริง
    //ไม่ใช่ตั้งค้างไว้ที่ Smart write ตลอดเวลา
    MainForm.LayoutWorkflowBar;
    MainForm.UpdateWorkflowState;
  end;

  if MainForm.FTelemetryPanel <> nil then
  begin
    MainForm.FTelemetryPanel.Color := ChromeColor;
    for i := 0 to High(MainForm.FTelemetryCards) do
    begin
      MainForm.FTelemetryCards[i].Color := SurfaceColor;
      MainForm.FTelemetryTitles[i].Font.Color := AccentColor;
      MainForm.FTelemetryValues[i].Font.Color := TextColor;
    end;
    MainForm.LayoutTelemetryPanel(nil);
    MainForm.UpdateTelemetry;
  end;
end;

//แถบนี้ทำให้เส้นทางที่ปลอดภัยมองเห็นได้ตลอดเวลา แทนที่จะซ่อน Smart Write
//ไว้หลังลูกศรเล็ก ๆ ของปุ่ม Write ผู้ใช้ขั้นสูงยังใช้ปุ่มเดิมและเมนูเดิมได้
//ทั้งหมด จึงไม่มีการเปลี่ยนความหมายของคำสั่งเก่า
procedure TMainForm.CreateWorkflowBar;
const
  BarHeight = 50;
  ButtonTop = 8;
  ButtonHeight = 34;

  procedure MakeButton(out B: TButton; Handler: TNotifyEvent);
  begin
    B := TButton.Create(Self);
    B.Parent := FWorkflowPanel;
    B.SetBounds(0, ButtonTop, 80, ButtonHeight);
    B.OnClick := Handler;
    B.TabStop := True;
  end;

begin
  if FWorkflowPanel <> nil then Exit;

  FWorkflowPanel := TPanel.Create(Self);
  FWorkflowPanel.Parent := Self;
  FWorkflowPanel.Name := 'WorkflowPanel';
  //TPanel วาด Caption ของตัวเอง และการตั้ง Name ให้แผงที่ Caption ยังว่าง
  //ทำให้ LCL คัดลอกชื่อไปเป็น Caption โดยอัตโนมัติ ผลคือคำว่า
  //"WorkflowPanel" ถูกวาดกลางแถบ แล้วโผล่ออกมาตามช่องว่างระหว่างปุ่ม
  FWorkflowPanel.Caption := '';
  FWorkflowPanel.BevelOuter := bvNone;
  FWorkflowPanel.Width := ClientWidth;
  FWorkflowPanel.Height := BarHeight;
  FWorkflowPanel.Top := ToolBar.Height;
  FWorkflowPanel.Align := alTop;
  //วาดลงบัฟเฟอร์ก่อนแล้วค่อยยกลงจอ พื้นหลังจึงถูกล้างทั้งแถบทุกครั้ง
  //ถ้าไม่ทำ ตัวอักษรของปุ่มจากตำแหน่งเดิมจะค้างอยู่ในช่องว่างระหว่างปุ่ม
  //เมื่อ LayoutWorkflowBar ถูกเรียกรอบที่สองแล้วความกว้างขยับ
  FWorkflowPanel.DoubleBuffered := True;
  FWorkflowPanel.ParentColor := False;

  FWorkflowTitle := TLabel.Create(Self);
  FWorkflowTitle.Parent := FWorkflowPanel;
  FWorkflowTitle.SetBounds(12, 5, 88, 40);
  FWorkflowTitle.Alignment := taLeftJustify;
  FWorkflowTitle.Layout := tlCenter;
  FWorkflowTitle.AutoSize := False;
  FWorkflowTitle.Font.Style := [fsBold];

  MakeButton(FWorkflowDetect, @ButtonReadIDClick);
  MakeButton(FWorkflowOpen,   @ButtonOpenHexClick);
  MakeButton(FWorkflowSmart,  @MenuSmartWriteClick);

  //เส้นคั่นระหว่างเส้นทางสามขั้นกับปุ่มช่วยเหลือ ทำให้เห็นว่าอะไรคือ
  //"ทางที่ควรเดิน" และอะไรคือเครื่องมือประกอบ
  FWorkflowSep := TPanel.Create(Self);
  FWorkflowSep.Parent := FWorkflowPanel;
  FWorkflowSep.Caption := '';
  FWorkflowSep.BevelOuter := bvNone;
  FWorkflowSep.SetBounds(0, ButtonTop + 4, 1, ButtonHeight - 8);

  MakeButton(FWorkflowRead,   @ButtonReadClick);
  MakeButton(FWorkflowVerify, @ButtonVerifyClick);

  FWorkflowState := TLabel.Create(Self);
  FWorkflowState.Parent := FWorkflowPanel;
  FWorkflowState.SetBounds(0, 5, 100, 40);
  FWorkflowState.Anchors := [akLeft, akTop, akRight];
  FWorkflowState.Alignment := taRightJustify;
  FWorkflowState.Layout := tlCenter;
  FWorkflowState.AutoSize := False;
  //ข้อความเต็มอยู่ใน Hint เสมอ เผื่อหน้าต่างแคบจนป้ายแสดงได้ไม่หมด
  FWorkflowState.ShowHint := True;
  FWorkflowState.WordWrap := False;

  UpdateWorkflowText;
end;

//วางตำแหน่งจากความกว้างของข้อความจริง ไม่ใช่พิกัดตายตัว
//
//ของเดิมตรึงพิกัดไว้ที่ 106/222/338/466/568/670 ซึ่งพอดีกับข้อความอังกฤษที่
//ฟอนต์ขนาดปกติเท่านั้น พอแปลเป็นภาษาอื่น เปลี่ยนฟอนต์ หรือเปิดจอ DPI สูง
//ปุ่มจะทับกันหรือข้อความถูกตัด
procedure TMainForm.LayoutWorkflowBar;
const
  GAP = 6;
  PAD = 26;   //ที่ว่างซ้ายขวาในปุ่ม
  SEP_GAP = 12;
var
  X: integer;


  procedure Place(B: TButton);
  var
    W: integer;
  begin
    W := FWorkflowPanel.Canvas.TextWidth(B.Caption) + PAD;
    if W < 70 then W := 70;
    B.SetBounds(X, B.Top, W, B.Height);
    Inc(X, W + GAP);
  end;

begin
  if FWorkflowPanel = nil then Exit;

  FWorkflowPanel.DisableAlign;
  try
    FWorkflowPanel.Canvas.Font := FWorkflowTitle.Font;
    FWorkflowTitle.Width := FWorkflowPanel.Canvas.TextWidth(
                              FWorkflowTitle.Caption) + 8;
    X := FWorkflowTitle.Left + FWorkflowTitle.Width + GAP + 4;

    //ปุ่มใช้ฟอนต์ของตัวเอง วัดด้วยฟอนต์นั้นถึงจะได้ความกว้างจริง
    FWorkflowPanel.Canvas.Font := FWorkflowDetect.Font;
    Place(FWorkflowDetect);
    Place(FWorkflowOpen);
    Place(FWorkflowSmart);

    Inc(X, SEP_GAP - GAP);
    FWorkflowSep.Left := X;
    Inc(X, FWorkflowSep.Width + SEP_GAP);

    Place(FWorkflowRead);
    Place(FWorkflowVerify);

    //ป้ายสถานะกินที่ว่างที่เหลือ และหดได้เมื่อหน้าต่างแคบ
    FWorkflowState.Left := X + GAP;
    FWorkflowState.Width := FWorkflowPanel.ClientWidth -
                            FWorkflowState.Left - 12;
    if FWorkflowState.Width < 40 then FWorkflowState.Width := 40;
  finally
    FWorkflowPanel.EnableAlign;
  end;

  //ต้องล้างพื้นหลังทั้งแถบเดี๋ยวนั้น ไม่ใช่แค่ทำเครื่องหมายว่าต้องวาดใหม่
  //
  //ฟังก์ชันนี้ถูกเรียกมากกว่าหนึ่งครั้ง (ตอนตั้งข้อความ และตอนเปลี่ยนธีม)
  //ถ้าความกว้างที่วัดได้ขยับแม้แต่พิกเซลเดียว ปุ่มจะย้ายที่ แต่พื้นที่เดิม
  //ไม่ถูกวาดทับ ตัวอักษรของรอบก่อนจึงค้างอยู่ในช่องว่างระหว่างปุ่ม
  FWorkflowPanel.Repaint;
end;

procedure TMainForm.UpdateWorkflowText;
begin
  if FWorkflowPanel = nil then Exit;

  FWorkflowTitle.Caption := STR_WORKFLOW_TITLE;
  FWorkflowDetect.Caption := STR_WORKFLOW_DETECT;
  FWorkflowOpen.Caption := STR_WORKFLOW_OPEN;
  FWorkflowSmart.Caption := STR_WORKFLOW_SMART;
  FWorkflowRead.Caption := STR_WORKFLOW_READ;
  FWorkflowVerify.Caption := STR_WORKFLOW_VERIFY;

  FWorkflowDetect.Hint := STR_WORKFLOW_DETECT + ' (F5)';
  FWorkflowDetect.ShowHint := True;
  FWorkflowOpen.Hint := STR_WORKFLOW_OPEN + ' (Ctrl+O)';
  FWorkflowOpen.ShowHint := True;
  FWorkflowSmart.ShowHint := True;
  FWorkflowRead.Hint := STR_WORKFLOW_READ + ' (Ctrl+R)';
  FWorkflowRead.ShowHint := True;
  FWorkflowVerify.Hint := STR_WORKFLOW_VERIFY + ' (Ctrl+Shift+V)';
  FWorkflowVerify.ShowHint := True;

  LayoutWorkflowBar;
  UpdateWorkflowState;
end;

//บอกขั้นต่อไปด้วยสถานะจริงของโปรแกรม และปิดเฉพาะปุ่มลัดชุดใหม่เมื่อเงื่อนไข
//ยังไม่ครบ ปุ่มดั้งเดิมยังอยู่เพื่อไม่ขวางงานวิเคราะห์/ฮาร์ดแวร์แบบพิเศษ
//
//ปุ่มที่กดไม่ได้ต้องมีเหตุผลที่อ่านได้เสมอ ทั้งในป้ายสถานะและใน tooltip
//ของปุ่มนั้นเอง การปิดปุ่มเฉย ๆ โดยไม่บอกว่าทำไม คือทางที่ผู้ใช้ไปติดแล้ว
//เดาเอาเองว่าโปรแกรมพัง
procedure TMainForm.UpdateWorkflowState;
var
  HasBuffer, SmartCapable, SizeKnown, AddrOK, FitsChip, MWAligned: boolean;
  PageOK: boolean;
  BufSize, ChipSize, StartAddr: QWord;
  Parsed: QWord;
  StateText, SmartWhy: string;
  StateColor: TColor;
  NextStep: TButton;
begin
  if FWorkflowPanel = nil then Exit;

  BufSize := MPHexEditorEx.DataSize;
  HasBuffer := BufSize > 0;

  //Smart write ไม่ใช่ของ SPI NOR อย่างเดียวอีกแล้ว ตั้งแต่ 4.6 ตระกูลที่ลบ
  //ไม่ได้ (24Cxx, 93xx, 95xx) ก็มีตัวจัดการ differential ของตัวเอง
  SmartCapable := (RadioSPI.Checked and
                   (ComboSPICMD.ItemIndex = SPI_CMD_25)) or
                  IsEEPROMSmartWriteTarget;

  ChipSize := 0;
  if IsNumber(ComboChipSize.Text) then
    ChipSize := StrToInt64Def(ComboChipSize.Text, 0);
  SizeKnown := ChipSize > 0;

  StartAddr := 0;
  AddrOK := TryStrToQWord('$' + Trim(StartAddressEdit.Text), Parsed);
  if AddrOK then StartAddr := Parsed;

  //ภาพที่ใหญ่เกินพื้นที่ที่เหลือจากแอดเดรสเริ่ม เดิมรู้ตัวหลังกดเขียนแล้ว
  FitsChip := SizeKnown and AddrOK and (StartAddr < ChipSize) and
              (BufSize <= ChipSize - StartAddr);

  //93xx เป็นชิปแบบคำ ตัวจัดการต้องการแอดเดรสและความยาวเป็นเลขคู่
  MWAligned := (not RadioMW.Checked) or
               (((StartAddr and 1) = 0) and ((BufSize and 1) = 0));

  //ทางเขียนต้องการหน้าเพจที่เป็นตัวเลข 1..2048 ถ้าไม่ตรวจที่นี่ด้วย แถบจะ
  //ไฟเขียวแล้วงานไปตายเอาหลังกดยืนยันการทำลายข้อมูลไปแล้ว
  //MicroWire ไม่ใช้ช่องนี้ ตัวจัดการบังคับหน้าเพจเป็น 2 ไบต์เอง
  PageOK := RadioMW.Checked or
            (TryStrToQWord(Trim(ComboPageSize.Text), Parsed) and
             (Parsed >= 1) and (Parsed <= 2048));

  FWorkflowOpen.Enabled := not OperationRunning;
  FWorkflowDetect.Enabled := (not OperationRunning) and
    ProgrammerPresent and RadioSPI.Checked;
  FWorkflowRead.Enabled := (not OperationRunning) and
    ProgrammerPresent and ChipDetected and SizeKnown;
  FWorkflowVerify.Enabled := FWorkflowRead.Enabled and HasBuffer;
  FWorkflowSmart.Enabled := FWorkflowVerify.Enabled and SmartCapable and
                            FitsChip and MWAligned and PageOK;

  //tooltip ของ Smart write บอกเหตุผลที่กดไม่ได้ ไม่ใช่คำอธิบายทั่วไปที่
  //ไม่เกี่ยวกับสถานะตรงหน้า
  if FWorkflowSmart.Enabled then
    SmartWhy := 'Preserve neighbouring bytes, write only what differs, ' +
                'and verify (Ctrl+Shift+P)'
  else if not SmartCapable then
    SmartWhy := 'Smart write covers SPI NOR, SPI 95, I2C 24 and MicroWire 93'
  else if not HasBuffer then
    SmartWhy := 'Open an image first'
  else if not FitsChip then
    SmartWhy := 'The image does not fit the chip from this start address'
  else if not MWAligned then
    SmartWhy := STR_WORKFLOW_MW_ODD
  else if not PageOK then
    SmartWhy := STR_WORKFLOW_BAD_PAGE
  else
    SmartWhy := 'Connect a programmer and select a chip first';
  FWorkflowSmart.Hint := SmartWhy;

  NextStep := nil;
  if OperationRunning then
  begin
    StateText := STR_WORKFLOW_RUNNING;
    StateColor := TColor($2BB3F3);
  end
  else if not ProgrammerPresent then
  begin
    StateText := STR_WORKFLOW_CONNECT;
    StateColor := TColor($6E8EB0);
  end
  else if not ChipDetected then
  begin
    //Read ID ใช้ได้เฉพาะ SPI การบอกให้ "detect" บนชิป I2C/MicroWire คือการ
    //ชี้ไปที่ปุ่มที่กดไม่ได้
    if RadioSPI.Checked then
    begin
      StateText := STR_WORKFLOW_PICK_CHIP;
      NextStep := FWorkflowDetect;
    end
    else
      StateText := STR_WORKFLOW_PICK_LIST;
    StateColor := TColor($D16E0A);
  end
  else if not SizeKnown then
  begin
    StateText := STR_WORKFLOW_NO_SIZE;
    StateColor := TColor($D16E0A);
  end
  else if RadioSPI.Checked and ChipIdentityUnproven then
  begin
    //ChipDetected แปลว่า "มีขนาดตั้งไว้" ไม่ใช่ "ชิปในซ็อกเก็ตตอบแล้ว"
    //ผู้ใช้ที่เลือกชื่อจากเมนูเองยังไม่ได้พิสูจน์อะไรเลย และการเขียนด้วย
    //หน้าเพจ/opcode ของชิปผิดรุ่นคือการทำลายข้อมูลแบบเงียบ ๆ
    StateText := STR_WF_CHIP_PICKED;
    StateColor := TColor($D16E0A);
    if FWorkflowDetect.Enabled then NextStep := FWorkflowDetect;
  end
  else if not HasBuffer then
  begin
    StateText := STR_WORKFLOW_LOAD;
    StateColor := TColor($D16E0A);
    NextStep := FWorkflowOpen;
  end
  else if not AddrOK then
  begin
    StateText := STR_WORKFLOW_BAD_ADDR;
    StateColor := TColor($C0392B);
  end
  else if not FitsChip then
  begin
    StateText := Format(STR_WORKFLOW_TOO_BIG,
      [BufSize, ChipSize - StartAddr, IntToHex(StartAddr, 1)]);
    if StartAddr >= ChipSize then
      StateText := Format(STR_WORKFLOW_TOO_BIG,
        [BufSize, 0, IntToHex(StartAddr, 1)]);
    StateColor := TColor($C0392B);
  end
  else if not MWAligned then
  begin
    StateText := STR_WORKFLOW_MW_ODD;
    StateColor := TColor($C0392B);
  end
  else if not PageOK then
  begin
    StateText := STR_WORKFLOW_BAD_PAGE;
    StateColor := TColor($D16E0A);
  end
  else if SmartCapable then
  begin
    //--- ถึงตรงนี้ทุกอย่างพร้อมทางเทคนิคแล้ว คำถามที่เหลือคือคำถามเดียวที่
    //--- สำคัญจริง: ชิปตัวนี้มีอะไรให้เสียหรือไม่ ---
    NextStep := FWorkflowSmart;
    StateColor := TColor($5B9E2E);

    if not ChipContentValid then
    begin
      //ยังไม่เคยอ่านชิปตัวนี้ จึงไม่มีใครรู้ว่าข้างในมีอะไร การเขียนทับ
      //ของที่ไม่รู้ว่าคืออะไร คือความเสี่ยงที่ควรพูดออกมา ไม่ใช่ไฟเขียวเฉย ๆ
      StateText := STR_WF_UNREAD;
      StateColor := TColor($D16E0A);
      if FWorkflowRead.Enabled then NextStep := FWorkflowRead;
    end
    else if ChipContentKnown = ckBlank then
      StateText := STR_WF_BLANK
    else if (BufferSource = bsChip) and (ChipContentOwner = CurrentChipKey) then
      //เขียนสิ่งที่เพิ่งอ่านออกมาจากชิปตัวเดียวกันกลับลงไป = ไม่มีอะไรเปลี่ยน
      StateText := STR_WF_SAME_AS_CHIP
    else
    begin
      //ชิปมีข้อมูลอยู่จริง และกำลังจะถูกเขียนทับด้วยของจากที่อื่น
      //นี่คือจุดที่ผู้ใช้เสียข้อมูลถาวรได้ ต้องบอกว่าจะมีสำเนาไว้หรือไม่
      StateText := STR_WF_HASDATA_BACKUP;
    end;

    //บอกด้วยว่าของที่จะเขียนมาจากไหน คนละความเสี่ยงกันโดยสิ้นเชิง
    if BufferSource = bsFile then
      StateText := StateText + '  (' + Format(STR_WF_FROM_FILE,
                                              [BufferSourceName]) + ')'
    else if BufferSource = bsEdited then
      StateText := StateText + '  (' + STR_WF_EDITED + ')';
  end
  else
  begin
    StateText := STR_WORKFLOW_LEGACY;
    StateColor := TColor($5B9E2E);
  end;

  //เน้นเฉพาะขั้นที่กดได้จริงตอนนี้ ของเดิมตัวหนาที่ Smart write ตลอดเวลา
  //ซึ่งชี้ไปที่ปุ่มที่ยังกดไม่ได้ตั้งแต่เปิดโปรแกรม
  //ต้องล้างทั้งห้าปุ่ม ไม่ใช่แค่สามปุ่มของเส้นทางหลัก เพราะ Read chip ก็ถูก
  //ตั้งเป็นขั้นถัดไปได้ ถ้าล้างไม่ครบมันจะหนาค้างไว้ตลอด แล้วแถบจะชี้ไปสอง
  //ที่พร้อมกัน หรือชี้ไปที่ปุ่มที่ถูกปิดไปแล้ว
  FWorkflowDetect.Font.Style := [];
  FWorkflowOpen.Font.Style := [];
  FWorkflowSmart.Font.Style := [];
  FWorkflowRead.Font.Style := [];
  FWorkflowVerify.Font.Style := [];
  if (NextStep <> nil) and NextStep.Enabled then
    NextStep.Font.Style := [fsBold];

  FWorkflowState.Caption := StateText;
  FWorkflowState.Hint := StateText;
  FWorkflowState.Font.Color := StateColor;
  FWorkflowState.Font.Style := [fsBold];
  UpdateTelemetry;
end;

//Four persistent cards keep engineering facts visible after the transient
//status-bar rate has disappeared.  The clock card always says "requested" or
//"selected" because the programmers do not measure the physical SCK waveform.
procedure TMainForm.CreateTelemetryPanel;
const
  PanelHeight = 112;
  Titles: array[0..3] of string = (
    'CONNECTION', 'INTERFACE / CLOCK', 'CHIP PROFILE', 'LAST OPERATION'
  );
var
  i: integer;
begin
  if FTelemetryPanel <> nil then Exit;

  FTelemetryPanel := TPanel.Create(Self);
  FTelemetryPanel.Parent := Self;
  FTelemetryPanel.Name := 'TelemetryPanel';
  FTelemetryPanel.Caption := '';
  FTelemetryPanel.BevelOuter := bvNone;
  FTelemetryPanel.ParentColor := False;
  FTelemetryPanel.DoubleBuffered := True;
  FTelemetryPanel.Height := PanelHeight;
  if FWorkflowPanel <> nil then
    FTelemetryPanel.Top := FWorkflowPanel.Top + FWorkflowPanel.Height;
  FTelemetryPanel.Align := alTop;
  FTelemetryPanel.OnResize := @LayoutTelemetryPanel;

  for i := 0 to High(FTelemetryCards) do
  begin
    FTelemetryCards[i] := TPanel.Create(Self);
    FTelemetryCards[i].Parent := FTelemetryPanel;
    FTelemetryCards[i].Caption := '';
    FTelemetryCards[i].BevelOuter := bvLowered;
    FTelemetryCards[i].ParentColor := False;

    FTelemetryTitles[i] := TLabel.Create(Self);
    FTelemetryTitles[i].Parent := FTelemetryCards[i];
    FTelemetryTitles[i].Caption := Titles[i];
    FTelemetryTitles[i].AutoSize := False;
    FTelemetryTitles[i].Font.Style := [fsBold];
    FTelemetryTitles[i].Transparent := True;

    FTelemetryValues[i] := TLabel.Create(Self);
    FTelemetryValues[i].Parent := FTelemetryCards[i];
    FTelemetryValues[i].AutoSize := False;
    FTelemetryValues[i].Transparent := True;
    FTelemetryValues[i].WordWrap := True;
    FTelemetryValues[i].ShowHint := True;
  end;

  FOperationStartedAt := 0;
  FLastOperationText := 'No completed operation yet' + LineEnding +
                        'Live effective rate and ETA appear in the status bar';
  FLastOperationHint := FLastOperationText;
  LayoutTelemetryPanel(nil);
  UpdateTelemetry;
end;

procedure TMainForm.LayoutTelemetryPanel(Sender: TObject);
const
  Gap = 6;
  Outer = 8;
var
  i, X, W, LastW: integer;
begin
  if FTelemetryPanel = nil then Exit;

  W := (FTelemetryPanel.ClientWidth - (Outer * 2) -
        (Gap * High(FTelemetryCards))) div Length(FTelemetryCards);
  if W < 90 then W := 90;
  X := Outer;
  for i := 0 to High(FTelemetryCards) do
  begin
    if i = High(FTelemetryCards) then
      LastW := FTelemetryPanel.ClientWidth - Outer - X
    else
      LastW := W;
    if LastW < 90 then LastW := 90;
    FTelemetryCards[i].SetBounds(X, 5, LastW,
      FTelemetryPanel.ClientHeight - 10);
    FTelemetryTitles[i].SetBounds(10, 7,
      FTelemetryCards[i].ClientWidth - 20, 18);
    FTelemetryValues[i].SetBounds(10, 27,
      FTelemetryCards[i].ClientWidth - 20,
      FTelemetryCards[i].ClientHeight - 33);
    Inc(X, W + Gap);
  end;
end;

//ห้ามอ่าน CurrentICParam.Vcc ตรง ๆ เพื่อตัดสินใจเรื่องแรงดัน เพราะ
//chiplist.xml ใส่แอตทริบิวต์ vcc ไว้แค่ 5 รายการจาก 658 รายการ ผู้เรียกที่
//ดูช่องนั้นอย่างเดียวจะได้ค่าว่างเกือบตลอดแล้วเงียบทั้งที่ควรเตือน
function CurrentChipVccText: string;
begin
  Result := ChipVccText(CurrentICParam.Vcc, CurrentICParam.Name,
                        CurrentICParam.ID);
end;

procedure TMainForm.UpdateTelemetry;
var
  ConnectionText, InterfaceText, ChipText, IDText, IdentityText: string;
  ClockText, TransportText, AddressText, VoltageText: string;
  ChipSize: QWord;
  ClockMenu: TMenuItem;

  function CheckedCaption(Root: TMenuItem): string;
  var
    n: integer;
  begin
    Result := '';
    if Root = nil then Exit;
    for n := 0 to Root.Count - 1 do
      if Root.Items[n].Checked then
        Exit(StringReplace(Root.Items[n].Caption, '&', '', [rfReplaceAll]));
  end;

begin
  //Programmer เป็น nil ได้ตอน Current_HW = CHW_NONE แผงข้อมูลห้ามพาแอป
  //ล้มเพราะเรื่องแค่นี้
  if (FTelemetryPanel = nil) or (AsProgrammer = nil) or
     (AsProgrammer.Programmer = nil) then Exit;

  case AsProgrammer.Current_HW of
    CHW_EZP:
      begin
        TransportText := 'USB 1FC8:310B | libusb-win32 1.4.0.2';
        ClockText := '12 MHz requested (firmware setting)';
        InterfaceText := 'SPI NOR | ' + ClockText + LineEnding +
          'Native erase | whole-chip read/write | full read-back verify';
        FTelemetryValues[1].Hint := '12 MHz is the configured EZP2023+ ' +
          'firmware clock. It is not a measured oscilloscope frequency. ' +
          'Measured effective operation throughput is shown separately.';
      end;
    CHW_SERPROG:
      begin
        TransportText := 'Serial/USB-CDC transport';
        InterfaceText := 'SPI | clock controlled by serprog firmware';
        FTelemetryValues[1].Hint := InterfaceText;
      end;
    CHW_ARDUINO, CHW_BUZZPIRAT, CHW_AVRISP:
      TransportText := 'Serial transport';
  else
    TransportText := 'USB transport';
  end;

  if AsProgrammer.Current_HW <> CHW_EZP then
  begin
    ClockMenu := nil;
    case AsProgrammer.Current_HW of
      CHW_CH341, CHW_USBASP: ClockMenu := MenuSPIClock;
      CHW_CH347: ClockMenu := MenuCH347SPIClock;
      CHW_FT232H: ClockMenu := MenuFT232SPIClock;
      CHW_AVRISP: ClockMenu := MenuAVRISPSPIClock;
      CHW_ARDUINO: ClockMenu := MenuArduinoSPIClock;
      CHW_BUZZPIRAT:
        if FindComponent('MenuBuzzpiratSPIClock') is TMenuItem then
          ClockMenu := TMenuItem(FindComponent('MenuBuzzpiratSPIClock'));
    end;
    ClockText := CheckedCaption(ClockMenu);
    if ClockText = '' then ClockText := 'firmware/default';
    if InterfaceText = '' then
    begin
      InterfaceText := 'SPI | ' + ClockText + ' selected' + LineEnding +
        'Measured effective throughput is reported per operation';
      //เขียน hint เฉพาะตอนที่ประกอบข้อความเองตรงนี้ ตัวที่มีคำอธิบายเฉพาะ
      //ของมันแล้ว (เช่น serprog) ต้องไม่โดนทับ
      FTelemetryValues[1].Hint := 'The menu value is the requested bus ' +
        'clock, not a measured waveform. Operation speed is measured from ' +
        'bytes and time.';
    end;
  end;

  if ProgrammerPresent then
    ConnectionText := 'CONNECTED | ' + AsProgrammer.Programmer.HardwareName
  else
    ConnectionText := 'DISCONNECTED | ' + AsProgrammer.Programmer.HardwareName;
  ConnectionText := ConnectionText + LineEnding + TransportText;
  FTelemetryValues[0].Caption := ConnectionText;
  FTelemetryValues[0].Hint := ConnectionText;
  FTelemetryValues[1].Caption := InterfaceText;

  ChipSize := CurrentICParam.Size;
  if (ChipSize = 0) and IsNumber(ComboChipSize.Text) then
    ChipSize := StrToQWordDef(ComboChipSize.Text, 0);

  if LastID9F <> '' then
  begin
    IDText := LastID9F;
    if ChipIdentityConfirmed or
       SameText(LastID9F, CurrentICParam.ID) then
      IdentityText := 'live confirmed'
    else
      IdentityText := 'live read';
  end
  else if CurrentICParam.ID <> '' then
  begin
    IDText := CurrentICParam.ID;
    IdentityText := 'selected, not read';
  end
  else
  begin
    IDText := 'ID unavailable';
    IdentityText := 'unconfirmed';
  end;

  if RadioSPI.Checked and (ComboSPICMD.ItemIndex = SPI_CMD_25) then
  begin
    if ChipSize > QWord(16) * 1024 * 1024 then
      AddressText := '4-byte address'
    else
      AddressText := '3-byte address';
  end
  else
    AddressText := 'addressing by selected protocol';

  VoltageText := CatalogVccDisplay(CurrentChipVccText);
  if VoltageText = '' then VoltageText := 'VCC not specified';

  if CurrentICParam.Name <> '' then
    ChipText := CurrentICParam.Name
  else
    ChipText := STR_NO_CHIP_SELECTED;
  ChipText := ChipText + ' | ' + IDText + ' (' + IdentityText + ')';
  if ChipSize > 0 then
  begin
    ChipText := ChipText + LineEnding + FormatTelemetryBytes(ChipSize);
    if CurrentICParam.Page > 0 then
      ChipText := ChipText + ' | page ' + IntToStr(CurrentICParam.Page) + ' B';
    if RadioSPI.Checked and (ComboSPICMD.ItemIndex = SPI_CMD_25) then
      ChipText := ChipText + ' | sector ' +
        FormatTelemetryBytes(CurrentSectorSize) + '/' +
        IntToHex(CurrentSectorOpcode, 2) + 'h';
    ChipText := ChipText + ' | ' + AddressText + ' | ' + VoltageText;
  end;
  FTelemetryValues[2].Caption := ChipText;
  FTelemetryValues[2].Hint := ChipText;

  if OperationRunning then
  begin
    FTelemetryValues[3].Caption := UpperCase(OpKindName(LastOp.Kind)) +
      ' RUNNING' + LineEnding +
      'Live effective rate and ETA: status bar';
    FTelemetryValues[3].Hint := FTelemetryValues[3].Caption;
  end
  else
  begin
    FTelemetryValues[3].Caption := FLastOperationText;
    FTelemetryValues[3].Hint := FLastOperationHint;
  end;
end;

procedure TMainForm.BeginOperationTelemetry;
begin
  FOperationStartedAt := Now;
  UpdateTelemetry;
end;

procedure TMainForm.FinishOperationTelemetry;
var
  ElapsedMs: int64;
  Bytes: QWord;
  StateText, DetailText: string;
begin
  if FOperationStartedAt = 0 then
  begin
    UpdateTelemetry;
    Exit;
  end;

  ElapsedMs := Abs(MilliSecondsBetween(Now, FOperationStartedAt));
  Bytes := LastOp.BytesDone;
  if (Bytes = 0) and (not LastOp.Failed) then Bytes := LastOp.BytesTotal;

  if LastOp.Cancelled then
    StateText := 'CANCELLED'
  else if LastOp.Failed then
    StateText := 'FAILED'
  else
    StateText := 'OK';

  DetailText := FormatTelemetryElapsed(ElapsedMs);
  if Bytes > 0 then
  begin
    DetailText := FormatTelemetryBytes(Bytes) + ' | ' + DetailText;
    if ElapsedMs > 0 then
      DetailText := DetailText + ' | ' +
        FormatTelemetryRate(Bytes / (ElapsedMs / 1000.0)) +
        ' effective';
  end;

  FLastOperationText := UpperCase(OpKindName(LastOp.Kind)) + ' ' +
                        StateText + LineEnding + DetailText;
  FLastOperationHint := FLastOperationText;
  if LastOp.Failed and (LastOp.ErrorText <> '') then
    FLastOperationHint := FLastOperationHint + LineEnding + LastOp.ErrorText;
  if LastOp.FailAddress >= 0 then
    FLastOperationHint := FLastOperationHint + LineEnding + 'Failure address 0x' +
      IntToHex(QWord(LastOp.FailAddress), 8);

  FOperationStartedAt := 0;
  UpdateTelemetry;
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
//นิยามอยู่ข้างกลไกเมนูแรงดันของ CH347 แต่ UpdateChipInfo ต้องเรียกมัน
//ทุกครั้งที่ข้อมูลชิปเปลี่ยน เพื่อให้ช่อง "Chip:" ในกล่องแรงดันตามทัน
procedure RefreshCH347VccPanel; forward;

procedure UpdateChipInfo;
var
  s, v: string;
  UISize: int64;
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

  //แรงดันของชิปต้องมองเห็นตรงแผงข้อมูล ไม่ใช่ซ่อนอยู่ใน log อย่างเดียว
  //ผู้ใช้ CH347 ต้องใช้ค่านี้ตัดสินว่าจะตั้งเมนูแรงดันไว้ที่ไหน
  //ผ่านตัวหาสามชั้น เพราะช่อง vcc ดิบว่างเปล่ากับชิปเกือบทุกตัว
  v := CatalogVccDisplay(CurrentChipVccText);
  if v <> '' then
  begin
    if s <> '' then s := s + LineEnding;
    s := s + 'Vcc     ' + v;
  end;

  if CurrentICParam.Note <> '' then
  begin
    if s <> '' then s := s + LineEnding;
    s := s + CurrentICParam.Note;
  end;

  //ผู้ใช้อาจไม่ได้เลือกจากรายการ แต่พิมพ์ขนาดลงช่อง Size เอง
  //กรณีนี้โปรแกรมทำงานได้จริง ไฟดวง Chip จึงต้องติดเหมือนกัน
  if IsNumber(MainForm.ComboChipSize.Text) then
    UISize := StrToInt64Def(MainForm.ComboChipSize.Text, 0)
  else
    UISize := 0;

  if (s = '') and (UISize > 0) then
    s := 'Size    ' + IntToStr(UISize div 1024) + ' KB';

  if s = '' then s := STR_NO_CHIP_SELECTED;

  MainForm.LabelChipInfo.Caption := s;

  ChipDetected := (CurrentICParam.Size > 0) or (UISize > 0);
  MainForm.ChipView.Invalidate;
  MainForm.UpdateWorkflowState;

  //ช่อง "Chip:" ในกล่องแรงดันของ CH347 แสดงค่าเดียวกันนี้ ต้องตามให้ทัน
  RefreshCH347VccPanel;
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

  //กล่องเลือกแรงดันของ CH347 อยู่ใต้แถวแอดเดรส โผล่เฉพาะตอนเลือก CH347
  MainForm.GroupCH347Vcc.Left := 6;
  MainForm.GroupCH347Vcc.Width := PanelW - 12;
  MainForm.GroupCH347Vcc.Top := 330;

  //ภาพชิปกินพื้นที่ที่เหลือทั้งหมดด้านล่าง และยืดตามความสูงหน้าต่าง
  //ถ้ากล่องแรงดันโผล่ ภาพชิปขยับลงไปต่อท้าย ถ้าหุบก็ทวงพื้นที่คืน
  MainForm.ChipView.Left := 6;
  MainForm.ChipView.Width := PanelW - 12;
  if MainForm.GroupCH347Vcc.Visible then
    MainForm.ChipView.Top := MainForm.GroupCH347Vcc.Top +
                             MainForm.GroupCH347Vcc.Height + 6
  else
    MainForm.ChipView.Top := 330;
  MainForm.ChipView.Anchors := [akLeft, akTop, akRight, akBottom];
  MainForm.ChipView.Height := MainForm.GroupChipSettings.ClientHeight -
                              MainForm.ChipView.Top - 6;
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
const
  //ซ็อกเก็ตว่าง สายขาด หรือชิปไม่ได้รับไฟ จะอ่าน status register ได้ FF ล้วน
  //ซึ่งบิต 0 ติดอยู่ แปลว่ายุ่งตลอดกาล ชิปที่ทำงานอยู่จริงไม่เคยค้างที่ FF
  //นานขนาดนี้ ระหว่างลบหรือเขียนค่าปกติคือ 03h
  //
  //เดิมรอจนหมดเวลาแล้วรายงานว่าชิปยุ่ง ซึ่งบนคำสั่งลบทั้งชิปคือรอสิบนาที
  //เพื่อจะได้คำตอบที่ชี้ไปผิดเรื่อง
  NOT_RESPONDING_MS = 500;
var
  Started, Elapsed: QWord;
  sreg: byte;
  AllOnes, CancelSeen: boolean;
begin
  Result := True;
  Started := GetTickCount64;
  AllOnes := True;
  CancelSeen := False;

  while UsbAsp25_BusyEx(sreg) do
  begin
    if sreg <> $FF then AllOnes := False;

    OpProcessMessages;
    //A program/erase command cannot be cancelled on the wire.  Closing the
    //programmer immediately can leave the part busy and make EX4B/WRDI cleanup
    //get ignored.  Record the request, drain the current command, then stop.
    if UserCancel then CancelSeen := True;

    Elapsed := GetTickCount64 - Started;

    if AllOnes and (Elapsed > NOT_RESPONDING_MS) then
    begin
      LogPrint(STR_NOT_RESPONDING);
      OpFail('no chip is answering: the status register reads back as FF');
      Exit(False);
    end;

    if Elapsed > QWord(TimeoutMs) then
    begin
      LogPrint(Format(STR_BUSY_TIMEOUT, [TimeoutMs div 1000]));
      OpFail(Format('the chip stayed busy for more than %d seconds',
                    [TimeoutMs div 1000]));
      Exit(False);
    end;

    Sleep(1);
  end;

  if OperationCancellationRequested then
  begin
    if not LastOp.Cancelled then OpCancel;
    CancelSeen := True;
  end;
  if CancelSeen then Result := False;
end;

//95-series EEPROM uses the same WIP/WEL bit positions as SPI NOR, but its
//protocol unit has its own exact-transfer status reader.  Never poll it through
//the 25-series shortcut because that hides a failed command phase.
function WaitNotBusy95(TimeoutMs: integer): boolean;
var
  Started: QWord;
  Status: byte;
  CancelSeen: boolean;
begin
  Result := False;
  Started := GetTickCount64;
  CancelSeen := False;

  repeat
    if UsbAsp95_ReadSR(Status) <> 1 then
    begin
      OpFail('the SPI EEPROM status register could not be read exactly');
      Exit;
    end;
    if Status = $FF then
    begin
      OpFail('no SPI EEPROM is answering: status reads as FF');
      Exit;
    end;
    if (Status and $01) = 0 then Break;

    OpProcessMessages;
    if UserCancel then CancelSeen := True;
    if GetTickCount64 - Started > QWord(TimeoutMs) then
    begin
      OpFail(Format('the SPI EEPROM stayed busy for more than %d seconds',
                    [TimeoutMs div 1000]));
      Exit;
    end;
    Sleep(1);
  until False;

  if OperationCancellationRequested then
  begin
    if not LastOp.Cancelled then OpCancel;
    CancelSeen := True;
  end;
  Result := not CancelSeen;
end;

function WaitNotBusy45(TimeoutMs: integer): boolean;
var
  Started: QWord;
  Status: byte;
  CancelSeen: boolean;
begin
  Result := False;
  Started := GetTickCount64;
  CancelSeen := False;

  repeat
  begin
    if UsbAsp45_ReadSR(Status) <> 1 then
    begin
      OpFail('the DataFlash status register could not be read exactly');
      Exit;
    end;
    //FF ล้วนคือบัสที่ไม่มีใครขับ ไม่ใช่ชิปที่พร้อม (ชิปจริงต้องเป็น AT45DB642
    //ที่ทุกบิตติดพร้อมกัน ซึ่งโอกาสน้อยกว่าคลิปหลุดมาก)
    //ถ้าเชื่อบิต 7 ของค่านั้น คลิปที่หลุดกลางงานเขียนจะ "พร้อม" ทันทีทุกหน้า
    if Status = $FF then
    begin
      OpFail('the DataFlash status bus reads FF; no chip is answering');
      Exit;
    end;
    if (Status and $80) <> 0 then Break;

    OpProcessMessages;
    if UserCancel then CancelSeen := True;
    if GetTickCount64 - Started > QWord(TimeoutMs) then
    begin
      OpFail(Format('DataFlash stayed busy for more than %d seconds',
                    [TimeoutMs div 1000]));
      Exit(False);
    end;
    Sleep(1);
  end;
  until False;

  if OperationCancellationRequested then
  begin
    if not LastOp.Cancelled then OpCancel;
    CancelSeen := True;
  end;
  Result := not CancelSeen;
end;

//ตรวจ geometry ของ DataFlash กับชิปตัวจริงก่อนเริ่มงาน ขนาดเพจที่เลือกต้องตรง
//กับโหมดเพจปัจจุบันของชิป (บิต 0 ของ status register) และช่วงงานต้องไม่เกิน
//ความจุจริง ไม่งั้นทุกแอดเดรสในงานจะเพี้ยนพร้อมกันหมดโดยไม่มีอะไรฟ้อง
//จนกว่าจะ verify ไม่ผ่าน หรือแย่กว่านั้นคือเขียนทับข้อมูลผิดตำแหน่ง
function Check45Geometry(SelectedPageSize: cardinal; RangeBytes: QWord): boolean;
var
  Geo: TAT45Geometry;
  PowerOf2, Known: boolean;
  ChipPage: word;
  TotalBytes: cardinal;
  ErrMsg, ModeStr: string;
  OtherModePage: word;
begin
  Result := False;

  if not UsbAsp45_DetectGeometry(Geo, PowerOf2, ChipPage, TotalBytes,
                                 Known, ErrMsg) then
  begin
    OpFail(ErrMsg);
    Exit;
  end;

  if not Known then
  begin
    //ชิปตอบแต่รหัสความจุไม่อยู่ในตาราง AT45 ตรวจไม่ได้ก็บอกตรง ๆ แล้วทำต่อ
    //การหยุดงานทั้งที่ชิปคุยรู้เรื่องจะขวางชิปแปลกที่ผู้ใช้ตั้งค่าเองถูกแล้ว
    LogPrint(Format('DataFlash density code %s is not recognised; ' +
                    'the selected page size cannot be cross-checked',
                    [IntToBin(Geo.DensityCode, 4)]));
    Exit(True);
  end;

  if PowerOf2 then ModeStr := 'binary (power-of-2)'
  else ModeStr := 'standard DataFlash';

  if SelectedPageSize <> ChipPage then
  begin
    if PowerOf2 then OtherModePage := Geo.StdPageSize
    else OtherModePage := Geo.BinPageSize;
    if SelectedPageSize = OtherModePage then
      //ผู้ใช้เลือกขนาดของอีกโหมด บอกให้ชัดว่าชิปอยู่โหมดไหนและต้องตั้งเท่าไร
      OpFail(Format('the %s is in %s page mode: its pages are %d bytes, ' +
                    'not %d. Set the page size to %d and the chip size to %d',
                    [Geo.Family, ModeStr, ChipPage, SelectedPageSize,
                     ChipPage, TotalBytes]))
    else
      OpFail(Format('the selected %d-byte page size does not match the %s, ' +
                    'whose pages are %d bytes in its current %s mode',
                    [SelectedPageSize, Geo.Family, ChipPage, ModeStr]));
    Exit;
  end;

  if RangeBytes > QWord(TotalBytes) then
  begin
    OpFail(Format('the requested %d bytes exceed the %s''s %d bytes ' +
                  '(%d pages of %d)',
                  [RangeBytes, Geo.Family, TotalBytes, Geo.Pages, ChipPage]));
    Exit;
  end;

  LogPrint(Format('%s: %d pages of %d bytes (%s page mode)',
                  [Geo.Family, Geo.Pages, ChipPage, ModeStr]));
  Result := True;
end;

function WaitNotBusyMW(TimeoutMs: integer): boolean;
var
  Started: QWord;
  CancelSeen: boolean;
begin
  Result := True;
  Started := GetTickCount64;
  CancelSeen := False;

  while UsbAspMW_Busy do
  begin
    OpProcessMessages;
    if UserCancel then CancelSeen := True;
    if GetTickCount64 - Started > QWord(TimeoutMs) then
    begin
      OpFail(Format('MicroWire EEPROM stayed busy for more than %d seconds',
                    [TimeoutMs div 1000]));
      Exit(False);
    end;
    Sleep(1);
  end;

  if OperationCancellationRequested then
  begin
    if not LastOp.Cancelled then OpCancel;
    CancelSeen := True;
  end;
  if CancelSeen then Result := False;
end;

//ตาราง SFDP ของชิปตัวที่เสียบอยู่ เก็บไว้ทั้งก้อน เพราะทั้งแผนผังเซกเตอร์
//และ opcode ชุดแอดเดรส 4 ไบต์ ต้องใช้ตอนวางแผนลบและตอนเขียน
//ล้างทุกครั้งที่เปลี่ยนชิปหรือเปลี่ยนซ็อกเก็ต พร้อมกับ Reset25ChipHints
var
  CurrentSFDP: TSFDPInfo;
  CurrentSFDPValid: boolean = False;

procedure ForgetSFDP;
begin
  FillChar(CurrentSFDP, SizeOf(CurrentSFDP), 0);
  CurrentSFDPValid := False;
end;

//--- โหมดแอดเดรส 4 ไบต์ ---
//
//การสลับโหมดด้วย B7h ทิ้งสถานะไว้ในตัวชิป ถ้างานล้มกลางคัน สายหลุด หรือ
//โปรแกรมตาย แล้วไม่ได้สลับกลับ ชิปจะค้างอยู่ที่โหมด 4 ไบต์ เครื่องมือตัวถัดไป
//ที่มาอ่านด้วยแอดเดรส 3 ไบต์จะได้ข้อมูลผิดทั้งก้อนโดยไม่มีอะไรบอก
//
//ทางที่ปลอดภัยกว่าคือใช้ opcode ชุด 4 ไบต์ของชิปเอง (13h อ่าน 12h เขียน)
//ซึ่งบอกแอดเดรสครบสี่ไบต์มากับคำสั่งเลย ไม่มีสถานะค้างอยู่ที่ไหน
//ตาราง 4BAIT ของ SFDP เป็นคนบอกว่าชิปตัวนี้มี opcode ชุดนั้นหรือไม่
var
  Mode4BActive: boolean = False;

function Native4BRead: boolean;
begin
  Result := Chip25Read4BOpcode <> 0;
end;

function Native4BWrite: boolean;
begin
  Result := Chip25PageProg4BOpcode <> 0;
end;

function Enter4B: boolean;
begin
  if Mode4BActive then Exit(True);
  if Chip25Entry4B = E4B_NONE then
  begin
    //ชิปไม่ประกาศคำสั่งสลับโหมดทันทีเลย (SFDP มีแต่ dedicated 4-byte set
    //หรือ B1h) การเดา B7h ใส่แล้วเชื่อว่าสลับสำเร็จจะพาเฟรมสี่ไบต์ไปลง
    //ชิปที่ยังตีความสามไบต์ ซึ่งคือการลบ/เขียนผิดตำแหน่งแบบเงียบ ๆ
    OpFail('this chip advertises no immediate 4-byte-address switch; the ' +
      'area past 16 MB is reachable only through its dedicated 4-byte ' +
      'opcodes, which this operation path does not have for every command ' +
      'it needs');
    Exit(False);
  end;
  if UsbAsp25_EN4B() <> 1 then
  begin
    OpFail('the SPI NOR did not accept an exact enter-4-byte-address command');
    Exit(False);
  end;
  Mode4BActive := True;
  Result := True;
end;

//เรียกซ้ำได้ปลอดภัย ใช้ในบล็อก finally เสมอ
procedure Leave4B;
begin
  if not Mode4BActive then Exit;
  if UsbAsp25_EX4B() = 1 then
    Mode4BActive := False
  else
    OpFail('the SPI NOR 4-byte-address cleanup command was not transferred exactly');
end;

//--- เพดานรอที่มาจากตัวชิปเอง ---
//
//ค่าคงที่ก้อนเดียวใช้กับชิปทุกตัวผิดทั้งสองทาง ชิป 256Mbit ที่ลบทั้งตัวจริง ๆ
//ใช้เวลาเกินสิบนาทีจะถูกตัดบทว่าล้มเหลวทั้งที่กำลังทำงานอยู่ ส่วนเพจที่ควร
//เขียนเสร็จใน 3 มิลลิวินาทีต้องรอจนครบ 5 วินาทีก่อนจะยอมบอกว่าชิปไม่ตอบ
//JESD216 rev A เก็บเวลาจริงของชิปแต่ละตัวไว้ใน DWORD-10 กับ DWORD-11 อยู่แล้ว
const
  BUSY_CEILING_PAGE   = 30000;
  BUSY_CEILING_SECTOR = 300000;
  BUSY_CEILING_CHIP   = 3600000;

function PageProgTimeout: integer;
var
  Declared: cardinal;
begin
  Declared := 0;
  if CurrentSFDPValid and CurrentSFDP.HasTiming then
    Declared := CurrentSFDP.PageProgTimeMaxMs;
  Result := integer(BusyTimeoutMs(Declared, BUSY_TIMEOUT_PAGE, BUSY_CEILING_PAGE));
end;

function EraseTimeoutFor(SectorSize: cardinal): integer;
var
  Declared: cardinal;
begin
  Declared := 0;
  if CurrentSFDPValid and CurrentSFDP.HasTiming then
    Declared := SFDPEraseTimeoutForSize(CurrentSFDP, SectorSize);
  Result := integer(BusyTimeoutMs(Declared, BUSY_TIMEOUT_SECTOR, BUSY_CEILING_SECTOR));
end;

function ChipEraseTimeout: integer;
var
  Declared: cardinal;
begin
  Declared := 0;
  if CurrentSFDPValid and CurrentSFDP.HasTiming then
    Declared := CurrentSFDP.ChipEraseTimeMaxMs;
  Result := integer(BusyTimeoutMs(Declared, BUSY_TIMEOUT_CHIP, BUSY_CEILING_CHIP));
end;

//Build the exact erase geometry consumed by the transactional NOR planner.
//An unresolved SFDP sector map is never replaced with a guessed uniform map:
//doing so can erase across a hybrid-region boundary and destroy neighbours.
function BuildCurrentNORGeometry(ChipSize, PageSize: cardinal;
  Native4BOpcodes: boolean; out Geometry: TNORGeometry;
  out ErrorText: string): boolean;
var
  RegionIndex, EraseType, BestType, BlockIndex: integer;
  RegionBase, BlockCount, TotalBlocks, j: QWord;
  BlockSize: cardinal;
  BlockOpcode, StandardOpcode, NativeOpcode: byte;

  function NativeOpcodeFor(Size: cardinal; Standard: byte;
    out Opcode: byte): boolean;
  var
    t: integer;
  begin
    Opcode := Standard;
    if not Native4BOpcodes then Exit(True);

    Result := False;
    if not CurrentSFDPValid then
    begin
      ErrorText := 'dedicated 4-byte erase opcodes require valid SFDP data';
      Exit;
    end;
    for t := 1 to 4 do
      if (CurrentSFDP.EraseTypes[t].Size = Size) and
         (CurrentSFDP.EraseTypes[t].Opcode = Standard) and
         (CurrentSFDP.EraseTypes[t].Opcode4B <> 0) then
      begin
        Opcode := CurrentSFDP.EraseTypes[t].Opcode4B;
        Exit(True);
      end;
    ErrorText := Format(
      'SFDP has no dedicated 4-byte erase opcode for %d-byte opcode %.2x',
      [Size, Standard]);
  end;

begin
  FillChar(Geometry, SizeOf(Geometry), 0);
  Geometry.ErasedValue := $FF;
  ErrorText := '';
  Result := False;

  if (ChipSize = 0) or (PageSize = 0) then
  begin
    ErrorText := 'chip size and page size must be non-zero';
    Exit;
  end;
  if CurrentSFDPValid and (CurrentSFDP.Density <> 0) and
     (CurrentSFDP.Density <> ChipSize) then
  begin
    ErrorText := Format(
      'selected chip size %d disagrees with the live SFDP density %d',
      [ChipSize, CurrentSFDP.Density]);
    Exit;
  end;
  if CurrentSFDPValid and CurrentSFDP.SectorMapDeclared and
     (not CurrentSFDP.HasSectorMap) then
  begin
    ErrorText :=
      'the chip declares an SFDP sector map, but its active map is ambiguous or invalid';
    Exit;
  end;

  if CurrentSFDPValid and CurrentSFDP.HasSectorMap then
  begin
    Geometry.ChipSize := ChipSize;
    Geometry.PageSize := PageSize;
    TotalBlocks := 0;
    RegionBase := 0;

    //First pass selects an erase type that is valid and aligned throughout
    //each region and obtains an exact allocation size.
    for RegionIndex := 0 to CurrentSFDP.RegionCount - 1 do
    begin
      BestType := 0;
      for EraseType := 1 to 4 do
        if ((CurrentSFDP.Regions[RegionIndex].EraseTypeMask and
             (1 shl (EraseType - 1))) <> 0) and
           (CurrentSFDP.EraseTypes[EraseType].Size > 0) and
           ((BestType = 0) or
            (CurrentSFDP.EraseTypes[EraseType].Size <
             CurrentSFDP.EraseTypes[BestType].Size)) and
           ((RegionBase mod CurrentSFDP.EraseTypes[EraseType].Size) = 0) and
           ((CurrentSFDP.Regions[RegionIndex].Size mod
             CurrentSFDP.EraseTypes[EraseType].Size) = 0) then
          BestType := EraseType;

      if BestType = 0 then
      begin
        ErrorText := Format(
          'SFDP region %d has no erase type aligned to the whole region',
          [RegionIndex]);
        Exit;
      end;
      BlockCount := CurrentSFDP.Regions[RegionIndex].Size div
                    CurrentSFDP.EraseTypes[BestType].Size;
      if BlockCount > QWord(High(SizeInt)) - TotalBlocks then
      begin
        ErrorText := 'SFDP erase-block count does not fit this build';
        Exit;
      end;
      Inc(TotalBlocks, BlockCount);
      Inc(RegionBase, CurrentSFDP.Regions[RegionIndex].Size);
    end;

    if RegionBase <> ChipSize then
    begin
      ErrorText := 'SFDP sector-map regions do not cover the selected chip';
      Exit;
    end;

    SetLength(Geometry.Blocks, SizeInt(TotalBlocks));
    RegionBase := 0;
    BlockIndex := 0;
    for RegionIndex := 0 to CurrentSFDP.RegionCount - 1 do
    begin
      BestType := 0;
      for EraseType := 1 to 4 do
        if ((CurrentSFDP.Regions[RegionIndex].EraseTypeMask and
             (1 shl (EraseType - 1))) <> 0) and
           (CurrentSFDP.EraseTypes[EraseType].Size > 0) and
           ((BestType = 0) or
            (CurrentSFDP.EraseTypes[EraseType].Size <
             CurrentSFDP.EraseTypes[BestType].Size)) and
           ((RegionBase mod CurrentSFDP.EraseTypes[EraseType].Size) = 0) and
           ((CurrentSFDP.Regions[RegionIndex].Size mod
             CurrentSFDP.EraseTypes[EraseType].Size) = 0) then
          BestType := EraseType;

      BlockSize := CurrentSFDP.EraseTypes[BestType].Size;
      StandardOpcode := CurrentSFDP.EraseTypes[BestType].Opcode;
      if not NativeOpcodeFor(BlockSize, StandardOpcode, NativeOpcode) then Exit;
      BlockCount := CurrentSFDP.Regions[RegionIndex].Size div BlockSize;
      j := 0;
      while j < BlockCount do
      begin
        Geometry.Blocks[BlockIndex].Address :=
          RegionBase + j * QWord(BlockSize);
        Geometry.Blocks[BlockIndex].Size := BlockSize;
        Geometry.Blocks[BlockIndex].Opcode := NativeOpcode;
        Inc(BlockIndex);
        Inc(j);
      end;
      Inc(RegionBase, CurrentSFDP.Regions[RegionIndex].Size);
    end;
    Exit(ValidateNORGeometry(Geometry, ErrorText));
  end;

  BlockSize := 0;
  StandardOpcode := 0;
  if CurrentSFDPValid then
    SFDPSmallestErase(CurrentSFDP, BlockSize, StandardOpcode);
  if BlockSize = 0 then
  begin
    BlockSize := CurrentSectorSize;
    StandardOpcode := CurrentSectorOpcode;
  end;
  if not NativeOpcodeFor(BlockSize, StandardOpcode, BlockOpcode) then Exit;
  Result := BuildUniformNORGeometry(ChipSize, PageSize, BlockSize,
                                    BlockOpcode, Geometry, ErrorText);
end;

//--- ชิปแจ้งความล้มเหลวเอง ---
//
//หลายยี่ห้อล้างบิต BUSY ตามปกติแล้วยกธงไว้ในรีจิสเตอร์อีกตัว เดิมโปรแกรม
//ไม่เคยอ่านธงนั้น ความล้มเหลวจึงไปโผล่ตอนตรวจข้อมูลกลับ หรือไม่โผล่เลยถ้า
//ปิดการตรวจไว้ ซึ่งแปลว่าชิปที่ลบไม่สำเร็จผ่านด่านออกไปได้
function ChipReportedFailure(const Context: string): boolean;
var
  Op, V, SR1: byte;
  Have: boolean;
  F: TPEFail;
begin
  Result := False;

  Op := VendorStatusOpcode(Chip25ManufID);
  V := 0;
  Have := False;
  if Op <> 0 then Have := UsbAsp25_ReadVendorStatus(Op, V);

  //Spansion เก็บธงไว้ใน SR1 เอง ยี่ห้ออื่นไม่ต้องอ่านซ้ำ
  SR1 := 0;
  if Chip25ManufID = $01 then UsbAsp25_ReadSR(SR1);

  F := ProgEraseFail(Chip25ManufID, SR1, V, Have);
  if F = peNone then Exit;

  LogPrint(Format(STR_CHIP_REPORTED_FAIL, [PEFailText(F)]) + ' (' + Context + ')');
  OpFail(PEFailText(F));

  //ธงของ Micron ค้างอยู่จนกว่าจะถูกล้าง ไม่ล้างแล้วงานถัดไปจะถูกกล่าวหาซ้ำ
  if Chip25ManufID = $20 then UsbAsp25_ClearFlagStatus;

  Result := True;
end;

//สั่ง WREN แล้วยืนยันว่าแลตช์ติดจริง คืน False พร้อมรายงานเมื่อไม่ติด
function WrenOK: boolean;
var
  WEL: boolean;
begin
  Result := UsbAsp25_WrenChecked(WEL);
  if Result then Exit;

  LogPrint(STR_WREN_REFUSED);
  OpFail('the chip did not accept write enable, WEL stayed clear');
end;

//--- ด่านตรวจก่อนแตะข้อมูล ---

//ปลุกชิปที่เครื่องมือตัวก่อนทิ้งไว้ในโหมดที่ตอบคำสั่งปกติไม่ได้
//
//ชิปที่ค้างอยู่ในโหมด QPI หรือค้างอยู่ในโหมดแอดเดรส 4 ไบต์ตอบ 9Fh ด้วย
//00 หรือ FF ล้วน ซึ่งอ่านออกมาเหมือนชิปตายสนิทหรือซ็อกเก็ตว่าง ทั้งที่ยังดีอยู่
//คืน True เมื่อได้ลองกู้แล้ว ผู้เรียกต้องอ่านรหัสใหม่อีกรอบ
function TryRecoverMuteChip(const Seen: byte): boolean;
begin
  Result := False;
  if (Seen <> $00) and (Seen <> $FF) then Exit;

  LogPrint(Format(STR_QPI_RECOVER, [Seen]));
  UsbAsp25_ExitQPI;
  UsbAsp25_SoftReset;
  Result := True;
end;

//อ่านรหัสชิปซ้ำ ๆ แล้วดูว่าได้ค่าเดิมทุกครั้งหรือไม่
//
//คลิปหนีบ SOIC ที่ขาใดขาหนึ่งแตะไม่สนิทให้ผลที่ดูปกติทุกอย่าง ไฟล์ที่ได้
//มีขนาดถูกต้อง อ่านครบทุกไบต์ ไม่มีข้อความผิดพลาดใด ๆ แล้วมีไบต์ผิดอยู่
//กลางไฟล์ซึ่งไม่มีใครสังเกตจนกว่าจะเอาไปใช้จริง
//
//การอ่าน 9Fh แปดครั้งใช้เวลาไม่ถึงเสี้ยววินาที และจับปัญหานี้ได้ตั้งแต่
//ก่อนไปแตะข้อมูล ซึ่งเป็นจุดเดียวที่จับได้แบบไม่ต้องเดา
function ContactIsStable: boolean;
const
  PASSES = 8;
var
  ID: MEMORY_ID;
  Ref, Cur: string;
  i: integer;
  Recovered: boolean;
begin
  Result := True;
  if not MainForm.MenuCheckContact.Checked then Exit;
  if not MainForm.RadioSPI.Checked then Exit;
  if MainForm.ComboSPICMD.ItemIndex <> SPI_CMD_25 then Exit;

  LogPrint(STR_CONTACT_CHECKING);
  Ref := '';
  Recovered := False;

  i := 1;
  while i <= PASSES do
  begin
    FillChar(ID, SizeOf(ID), 0);
    UsbAsp25_ReadID(ID);

    //ชิปที่ตอบ 00 หรือ FF ล้วนอาจแค่ค้างอยู่ในโหมดที่คุยด้วยแบบนี้ไม่ได้
    //ลองกู้หนึ่งครั้งแล้วเริ่มนับใหม่ ดีกว่ารายงานว่าไม่มีชิป
    if (not Recovered) and (ID.ID9FH[0] = ID.ID9FH[1]) and
       (ID.ID9FH[1] = ID.ID9FH[2]) and TryRecoverMuteChip(ID.ID9FH[0]) then
    begin
      Recovered := True;
      Ref := '';
      i := 1;
      Continue;
    end;

    Cur := IntToHex(ID.ID9FH[0], 2) + IntToHex(ID.ID9FH[1], 2) +
           IntToHex(ID.ID9FH[2], 2);

    //00 หรือ FF ล้วนคือซ็อกเก็ตว่าง สายขาด หรือชิปไม่ได้รับไฟ ค่าเหล่านี้
    //"นิ่ง" ทุกครั้งที่อ่าน จึงผ่านการตรวจความนิ่งไปได้อย่างสบาย แล้วเราจะ
    //ขึ้นข้อความว่าการเชื่อมต่อมั่นคงให้กับซ็อกเก็ตที่ไม่มีชิปอยู่เลย
    //ซึ่งชี้ให้คนไปตามหาปัญหาผิดที่ทั้งหมด
    if (Cur = '000000') or (Cur = 'FFFFFF') then
    begin
      LogPrint(STR_NOT_RESPONDING);
      OpFail('no chip is answering: the id reads back as ' + Cur);
      Exit(False);
    end;

    if Ref = '' then
      Ref := Cur
    else if Cur <> Ref then
    begin
      LogPrint(Format(STR_CONTACT_UNSTABLE, [Ref, Cur]));
      OpFail(Format('the chip id is not stable: %s then %s', [Ref, Cur]));
      Exit(False);
    end;

    Inc(i);
  end;

  LogPrint(Format(STR_CONTACT_OK, [PASSES]));
end;

//--- การเลือก opcode อ่าน ---
//
//เดิมการเลือกถูกคัดลอกไว้สามที่ คือตอนอ่าน ตอนตรวจหลังเขียนทีละเพจ และตอน
//ตรวจข้อมูลทั้งก้อน แก้ที่หนึ่งแล้วลืมอีกสองที่คือความผิดพลาดที่รอเกิดอยู่แล้ว
//
//03h ไม่มีไบต์หลอก จึงเร็วกว่าในแง่จำนวนไบต์ แต่ดาต้าชีตให้เพดานความถี่ไว้
//แค่ 33 ถึง 50 MHz ส่วน 0Bh ไปได้ถึง 104 MHz เครื่องที่รองรับอยู่ยิงได้ถึง
//30 MHz ขึ้นไปซึ่งอยู่ริมเพดานของ 03h พอดี อาการคือข้อมูลเพี้ยนเป็นครั้งคราว
procedure PickReadOpcode(Native4B: boolean; out Opcode: byte; out Fast: boolean);
begin
  Fast := OpUI.FastRead and Chip25FastRead;

  if Native4B then
  begin
    if Fast and (Chip25FastRead4BOpcode <> 0) then
      Opcode := Chip25FastRead4BOpcode
    else
    begin
      Fast := False;
      Opcode := Chip25Read4BOpcode;
    end;
    Exit;
  end;

  //ชิปที่ถูกสลับเข้าโหมด 4 ไบต์แล้วใช้ opcode ชุดเดียวกับโหมด 3 ไบต์
  //ต่างกันแค่จำนวนไบต์แอดเดรสที่ตามหลัง ซึ่ง Use4B เป็นตัวบอก
  if Fast then Opcode := $0B else Opcode := $03;
end;

function ReadData25(Opcode: byte; Fast, Use4B: boolean; Addr: cardinal;
  var Buf: array of byte; Len: integer): integer;
begin
  if Use4B then
  begin
    if Fast then
      Result := UsbAsp25_ReadFast32bitAddr(Opcode, Addr, Buf, Len)
    else
      Result := UsbAsp25_Read32bitAddr(Opcode, Addr, Buf, Len);
  end
  else
  begin
    if Fast then
      Result := UsbAsp25_ReadFast(Opcode, Addr, Buf, Len)
    else
      Result := UsbAsp25_Read(Opcode, Addr, Buf, Len);
  end;
end;

//ลบเฉพาะเซกเตอร์ที่อยู่ในช่วง StartAddress ถึง StartAddress+RangeLen-1
//ขอบถูกปัดให้ตรงเซกเตอร์ เพราะลบครึ่งเซกเตอร์ไม่ได้
function EraseRange25(StartAddress, RangeLen, SectorSize: cardinal; Opcode: byte): boolean;
const
  FLASH_SIZE_128MBIT = 16777216;
var
  ChipSize, Addr, EndAddr: cardinal;
  Total: integer;
  Use4B, Native4B, UsePlan: boolean;
  Plan: TErasePlan;
  OK: boolean;

  //ตัวงานจริง จะรันบน thread เบื้องหลังถ้าเปิดโหมดนั้นไว้
  //ตัวนับลูปต้องเป็นตัวแปรในตัวเอง เพราะ FPC ไม่ยอมให้ใช้ตัวแปร
  //ของโพรซีเยอร์ชั้นนอกมาเป็นตัวนับ for
  procedure DoWork;
  var
    Idx, Byt, Sent, Got: integer;
    EtaMs: QWord;
    Probe: array[0..15] of byte;
    ChkOp: byte;
    ChkFast, ReadNative4B: boolean;
    EraseMs: array of cardinal;
    T0: QWord;
    SlowCount, WorstIdx: integer;
    MedianMs, WorstMs: cardinal;
  begin
  OK := False;

  if (SectorSize = 0) or (RangeLen = 0) then
  begin
    LogPrint(STR_CHECK_SETTINGS);
    OpFail('sector size or range length is zero');
    Exit;
  end;

  ChipSize := OpUI.ChipSize;

  if (ChipSize = 0) or (StartAddress >= ChipSize) then
  begin
    LogPrint(STR_CHECK_SETTINGS);
    OpFail('the chip size is not set, or the range starts past the end');
    Exit;
  end;

  //ชิปที่บอกแผนผังเซกเตอร์ของตัวเองมาแล้ว ให้เดินตามแผนผังนั้น
  //
  //ได้สองอย่างที่การไล่ทีละเซกเตอร์ขนาดเดียวให้ไม่ได้
  //  ถูกต้อง  ชิปที่มีบล็อกหัวหรือท้ายขนาดไม่เท่ากันจะถูกลบตามขนาดจริง
  //  เร็ว     ช่วงยาว ๆ ใช้ opcode ก้อนใหญ่ที่สุดที่ยังอยู่ในช่วงที่ขอ
  //           ลบ 8MB ด้วยบล็อก 64K ใช้คำสั่ง 158 ครั้งแทนที่จะเป็น 2048 ครั้ง
  UsePlan := False;
  if CurrentSFDPValid then
    UsePlan := PlanEraseSFDP(CurrentSFDP, StartAddress, RangeLen, ChipSize, Plan);

  if not UsePlan then
    if not PlanEraseUniform(StartAddress, RangeLen, SectorSize, ChipSize,
                            Opcode, Plan) then
    begin
      LogPrint(STR_CHECK_SETTINGS);
      OpFail('the chip size, the page size or the range is not usable');
      exit;
    end;

  Total := Length(Plan);
  if Total = 0 then
  begin
    LogPrint(STR_CHECK_SETTINGS);
    OpFail('the chip size, the page size or the range is not usable');
    exit;
  end;

  if not PlanBounds(Plan, Addr, EndAddr) then Exit;

  if UsePlan then
    LogPrint(Format(STR_ERASE_MAP, [Total, Addr, EndAddr - 1]))
  else
    LogPrint(STR_ERASING_RANGE + '0x' + IntToHex(Addr, 8) + ' - 0x' + IntToHex(EndAddr - 1, 8) +
             ' (' + IntToStr(Total) + ' x ' + IntToStr(SectorSize) + ' bytes, opcode 0x' +
             IntToHex(Opcode, 2) + ')');

  //เพดานเวลารวมจากตัวเลขที่ชิปประกาศเอง จะได้รู้ล่วงหน้าว่ารอได้แค่ไหน
  EtaMs := 0;
  for Idx := 0 to Total - 1 do
    Inc(EtaMs, QWord(EraseTimeoutFor(Plan[Idx].Size)));
  if EtaMs >= 2000 then
    LogPrint(Format('The chip itself declares this erase may take up to %d s',
                    [(EtaMs + 999) div 1000]));

  //ชิปใหญ่กว่า 128Mbit ต้องใช้แอดเดรส 4 ไบต์
  //ถ้าทุกขั้นในแผนมี opcode ชุด 4 ไบต์ของตัวเองครบ ก็ไม่ต้องสลับโหมดเลย
  //ซึ่งปลอดภัยกว่ามาก เพราะการสลับโหมดทิ้งสถานะไว้ในตัวชิป งานที่ล้ม
  //กลางคันจะทิ้งชิปไว้ที่โหมด 4 ไบต์ แล้วเครื่องมือตัวถัดไปจะอ่านได้ขยะ
  Use4B := Needs4ByteAddress(StartAddress, RangeLen, ChipSize);
  Native4B := Use4B and PlanAllHave4B(Plan);
  if Native4B then LogPrint(STR_4B_NATIVE);

  SetProgressPos(0);
  SetProgressMax(Integer(Total));

  //สลับโหมดเฉพาะตอนที่จำเป็นจริง ๆ และต้องกลับออกมาให้ได้เสมอ
  if Use4B and (not Native4B) then
    if not Enter4B then Exit;

  try
    SetLength(EraseMs, Total);
    for Idx := 0 to Total - 1 do
    begin
      //WEL is cleared by every accepted erase command.  Therefore every
      //sector needs a new WREN followed by an observed WEL=1; checking only
      //the first sector can silently skip all remaining sectors.
      if not WrenOK then Exit;

      T0 := GetTickCount64;

      if Native4B then
        Sent := UsbAsp25_EraseSector(Plan[Idx].Opcode4B,
                                    Plan[Idx].Addr, True)
      else
        Sent := UsbAsp25_EraseSector(Plan[Idx].Opcode,
                                    Plan[Idx].Addr, Use4B);
      if Sent <> 4 + Ord(Use4B) then
      begin
        OpFail(Format('short erase command: sent %d of %d bytes',
                      [Sent, 4 + Ord(Use4B)]), Plan[Idx].Addr);
        Exit;
      end
      ;

      if not WaitNotBusy25(EraseTimeoutFor(Plan[Idx].Size)) then Exit;

      //เวลาลบต่อบล็อกได้มาฟรีจากการรอ BUSY แฟลชตายแบบช้าลงก่อนพัง
      //เก็บไว้แล้วค่อยดูตอนจบว่ามีบล็อกไหนช้าผิดฝูง
      EraseMs[Idx] := cardinal(GetTickCount64 - T0);

      //ชิปแจ้งเองว่าคำสั่งลบล้มเหลวหรือไม่
      if ChipReportedFailure('erase at 0x' + IntToHex(Plan[Idx].Addr, 8)) then Exit;

      SetProgressPos(Idx + 1);
      OpProcessMessages;

      if UserCancel then Exit;
    end;

    //บล็อกที่ลบช้ากว่ามัธยฐานเกินห้าเท่าคือบล็อกที่กำลังหมดอายุ ตัวเลข
    //มัธยฐานต่ำกว่าความละเอียดของนาฬิกา (บล็อกจิ๋วหรือชิปไว) ตัดสินไม่ได้
    //ก็ไม่ตัดสิน
    if Total >= 4 then
    begin
      SlowCount := CountTimingOutliers(EraseMs, 5, MedianMs, WorstMs,
                                       WorstIdx);
      if (MedianMs >= 10) and (SlowCount > 0) and (WorstIdx >= 0) then
        LogPrint(Format(STR_ERASE_WEAR_WARNING,
          [SlowCount, WorstMs, Plan[WorstIdx].Addr, MedianMs]));
    end;

    //ตรวจว่าคำสั่งลบทำงานจริง
    //
    //ชิปที่ยังถูกป้องกันอยู่จะรับคำสั่งลบ ล้างบิต BUSY ตามปกติ แล้วไม่ลบ
    //อะไรเลย เดิมโปรแกรมเชื่อว่าสำเร็จเพราะไม่มีอะไรฟ้อง ข้อมูลเก่ายังอยู่ครบ
    //แล้วการเขียนทับลงไปให้ผลที่อธิบายไม่ได้
    //
    //ดูแค่ต้นของแต่ละก้อนที่สั่งลบ ไม่ได้ไล่ทุกไบต์ เพราะอาการที่จับอยู่คือ
    //"ลบแล้วไม่มีอะไรเกิดขึ้น" ซึ่งเห็นได้จากไบต์แรกของก้อน และการไล่ทั้ง
    //ช่วงจะทำให้เวลาที่ใช้เพิ่มเป็นสองเท่าเพื่อข้อมูลที่ไม่ได้เพิ่มขึ้น
    if OpUI.VerifyErase then
    begin
      LogPrint(STR_BLANK_AFTER_ERASE);

      //Native4B ข้างบนหมายถึง "ทุกขั้นในแผนมี opcode ลบชุด 4 ไบต์" ซึ่งเป็น
      //คนละเรื่องกับการมี opcode อ่านชุด 4 ไบต์ เอามาตัดสินการอ่านไม่ได้
      //
      //ถ้าเอามาใช้ ชิปที่มี opcode ลบชุด 4 ไบต์แต่ไม่มี opcode อ่านชุดนั้น
      //จะได้ Chip25Read4BOpcode ซึ่งเป็นศูนย์ แล้วเราจะส่ง opcode 00h ออกไป
      //ซึ่งไม่มีนิยามในดาต้าชีตของชิปไหนเลย
      ReadNative4B := Use4B and Native4BRead;

      //ทางลบที่ใช้ opcode ชุด 4 ไบต์ไม่ได้สลับโหมดไว้ ถ้าทางอ่านไม่มี opcode
      //ชุดนั้นของตัวเอง ก็ต้องสลับโหมดก่อน ไม่งั้นแอดเดรส 4 ไบต์ที่ส่งออกไป
      //จะถูกชิปตีความเป็นแอดเดรส 3 ไบต์บวกไบต์ข้อมูล
      if Use4B and (not ReadNative4B) then
        if not Enter4B then Exit;

      PickReadOpcode(ReadNative4B, ChkOp, ChkFast);

      for Idx := 0 to Total - 1 do
      begin
        Got := ReadData25(ChkOp, ChkFast, Use4B, Plan[Idx].Addr,
                          Probe, SizeOf(Probe));
        if Got <> SizeOf(Probe) then
        begin
          OpFail(Format('short erase-verification read: received %d of %d bytes',
                        [Got, SizeOf(Probe)]), Plan[Idx].Addr);
          Exit;
        end;

        for Byt := 0 to SizeOf(Probe) - 1 do
          if Probe[Byt] <> $FF then
          begin
            LogPrint(Format(STR_ERASE_DID_NOT_TAKE,
                            [Plan[Idx].Addr + cardinal(Byt), Probe[Byt]]));
            OpFail('the erase did not take, the area still holds data',
                   Plan[Idx].Addr + cardinal(Byt));
            Exit;
          end;

        OpProcessMessages;
        if UserCancel then Exit;
      end;
    end;

    OK := True;
  finally
    Leave4B;
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
    Spot, Byt: integer;
    At: int64;
    Probe: array[0..15] of byte;
    ChkOp: byte;
    ChkFast, Use4B, Native4B: boolean;
    Got: integer;
  begin
    //ชิปที่ไม่ยอมรับ write enable จะรับคำสั่งลบไปแล้วไม่ทำอะไร แล้วเราจะรอ
    //อยู่นานถึงสิบนาทีเพื่อจะได้คำตอบที่ชี้ไปผิดเรื่อง
    if not WrenOK then Exit;
    if UsbAsp25_ChipErase() <> 1 then
    begin
      OpFail('the SPI NOR chip-erase command was not transferred exactly');
      Exit;
    end;

    LogPrint(STR_ERASE_NOTICE);
    //บอกเพดานเวลาที่มาจากตัวชิปเองไว้ก่อน จะได้ไม่มีใครถอดสายกลางคันเพราะ
    //คิดว่าโปรแกรมค้าง ชิป 256Mbit ลบทั้งตัวอาจใช้เวลาหลายนาทีจริง ๆ
    LogPrint(Format('The chip itself declares this erase may take up to %d s',
                    [ChipEraseTimeout div 1000]));
    Started := Now;

    if not WaitNotBusy25(ChipEraseTimeout) then Exit;

    if ChipReportedFailure('chip erase') then Exit;

    //สุ่มดูสิบหกจุดกระจายทั่วชิปว่าถูกลบจริง ชิปที่ยังถูกป้องกันอยู่จะรับ
    //คำสั่งไปแล้วไม่ทำอะไร ซึ่งเดิมไม่มีอะไรฟ้องเลย
    if OpUI.VerifyErase and (OpUI.ChipSize > 0) then
    begin
      LogPrint(STR_BLANK_AFTER_ERASE);
      Use4B := OpUI.ChipSize > 16777216;
      Native4B := Use4B and Native4BRead;
      if Use4B and (not Native4B) then
        if not Enter4B then Exit;
      PickReadOpcode(Native4B, ChkOp, ChkFast);

      try
        for Spot := 0 to 15 do
        begin
          At := (int64(OpUI.ChipSize) * Spot) div 16;
          Got := ReadData25(ChkOp, ChkFast, Use4B, cardinal(At),
                            Probe, SizeOf(Probe));
          if Got <> SizeOf(Probe) then
          begin
            OpFail(Format(
              'short chip-erase verification read: received %d of %d bytes',
              [Got, SizeOf(Probe)]), At);
            Exit;
          end;

          for Byt := 0 to SizeOf(Probe) - 1 do
            if Probe[Byt] <> $FF then
            begin
              LogPrint(Format(STR_ERASE_DID_NOT_TAKE,
                              [cardinal(At) + cardinal(Byt), Probe[Byt]]));
              OpFail('the chip erase did not take, the chip still holds data',
                     At + Byt);
              Exit;
            end;

          OpProcessMessages;
          if UserCancel then Exit;
        end;
      finally
        Leave4B;
      end;
    end;

    //การลบทั้งชิปเป็นไปไม่ได้ที่จะเสร็จในเสี้ยววินาที เกือบทุกครั้ง
    //แปลว่าชิปปฏิเสธคำสั่งเพราะยังถูกป้องกันการเขียนอยู่
    //นับเป็นความล้มเหลว ไม่ใช่แค่คำเตือน ชิปที่ไม่ได้ถูกลบจริงต้องไม่ผ่านด่าน
    if MilliSecondsBetween(Now, Started) < 1000 then
    begin
      LogPrint(STR_ERASE_TOO_FAST);
      OpFail('erase returned too fast, the chip is probably still protected');
    end;
  end;

begin
  RunOperation(@DoWork);
end;

//ตัวจริงอยู่ถัดลงไปในไฟล์ ประกาศไว้ก่อนเพราะการสำรองข้อมูลอัตโนมัติต้องใช้
procedure ReadFlash25(var RomStream: TMemoryStream; StartAddress, ChipSize: cardinal); forward;
procedure ReadFlash95(var RomStream: TMemoryStream; StartAddress,
  ChipSize: cardinal); forward;
procedure ReadFlash45(var RomStream: TMemoryStream; StartAddress, PageSize,
  ChipSize: cardinal); forward;
procedure ReadFlashKB(var RomStream: TMemoryStream; StartAddress,
  ChipSize: cardinal); forward;
procedure ReadFlashI2C(var RomStream: TMemoryStream; StartAddress,
  ChipSize: cardinal; ChunkSize: Word; DevAddr: byte); forward;
procedure ReadFlashMW(var RomStream: TMemoryStream; AddrBitLen: byte;
  StartAddress, ChipSize: cardinal); forward;
function SetI2CDevAddr(): byte; forward;

//อ่านซ้ำอีกหลายรอบแล้วเทียบกับรอบแรก
//
//นี่คือด่านเดียวที่จับ "อ่านครบทุกไบต์แต่ได้ข้อมูลผิด" ได้ ซึ่งเป็นความ
//ล้มเหลวที่เงียบที่สุดของงานประเภทนี้ คลิปหนีบที่ขาใดขาหนึ่งแตะไม่สนิท
//ให้ไฟล์ที่ขนาดถูก อ่านครบ ไม่มีข้อความผิดพลาด และมีไบต์ผิดอยู่ข้างใน
//
//เมื่อสองรอบไม่ตรงกัน เราบอกไม่ได้ว่ารอบไหนถูก และไม่ควรเดา
//สิ่งที่บอกได้คือดัมป์นี้เชื่อไม่ได้ ซึ่งเป็นข้อมูลที่มีค่ากว่าการเดา
//ลำดับเมนูความเร็ว SPI ของโปรแกรมเมอร์ตัวปัจจุบัน เรียงจากเร็วสุดไปช้าสุด
//คืนจำนวนขั้น ศูนย์ = ฮาร์ดแวร์ตัวนี้ไม่มีเมนูความเร็วให้ถอย (เช่น CH341)
function SPISpeedMenuLadder(var Items: array of TMenuItem): integer;
var
  N: integer;

  procedure Add(Item: TMenuItem);
  begin
    if N <= High(Items) then
    begin
      Items[N] := Item;
      Inc(N);
    end;
  end;

begin
  N := 0;
  if AsProgrammer.Current_HW = CHW_CH347 then
  begin
    Add(MainForm.MenuCH347SPIClock60MHz);
    Add(MainForm.MenuCH347SPIClock30MHz);
    Add(MainForm.MenuCH347SPIClock15MHz);
    Add(MainForm.MenuCH347SPIClock7_5MHz);
    Add(MainForm.MenuCH347SPIClock3_75MHz);
    Add(MainForm.MenuCH347SPIClock1_875MHz);
    Add(MainForm.MenuCH347SPIClock937_5KHz);
    Add(MainForm.MenuCH347SPIClock468_75KHz);
  end
  else if AsProgrammer.Current_HW = CHW_FT232H then
  begin
    Add(MainForm.MenuFT232SPI30Mhz);
    Add(MainForm.MenuFT232SPI6Mhz);
  end
  else if AsProgrammer.Current_HW = CHW_USBASP then
  begin
    Add(MainForm.Menu3Mhz);
    Add(MainForm.Menu1_5Mhz);
    Add(MainForm.Menu750Khz);
    Add(MainForm.Menu375Khz);
    Add(MainForm.Menu187_5Khz);
    Add(MainForm.Menu93_75Khz);
    Add(MainForm.Menu32Khz);
  end
  else if (AsProgrammer.Current_HW = CHW_ARDUINO) or
          (AsProgrammer.Current_HW = CHW_BUZZPIRAT) then
  begin
    Add(MainForm.MenuArduinoISP8Mhz);
    Add(MainForm.MenuArduinoISP4Mhz);
    Add(MainForm.MenuArduinoISP2Mhz);
    Add(MainForm.MenuArduinoISP1Mhz);
  end
  else if AsProgrammer.Current_HW = CHW_AVRISP then
  begin
    Add(MainForm.MenuAVRISP8Mhz);
    Add(MainForm.MenuAVRISP4Mhz);
    Add(MainForm.MenuAVRISP2Mhz);
    Add(MainForm.MenuAVRISP1Mhz);
    Add(MainForm.MenuAVRISP500Khz);
    Add(MainForm.MenuAVRISP250Khz);
    Add(MainForm.MenuAVRISP125Khz);
  end;
  Result := N;
end;

//คลิปที่สัมผัสไม่แน่นมักกลับมาอ่านตรงกันเมื่อคล็อกช้าลง: ขยับลงหนึ่งขั้นจาก
//ตำแหน่งเดิม LadderPos เริ่มที่ -1 = ยังไม่รู้ ให้หาจากเมนูที่ติ๊กอยู่
//คืน False เมื่อช้าสุดแล้ว หรือฮาร์ดแวร์ตัวนี้ไม่มีเมนูความเร็ว
//ค่าที่คืนเป็น Tag ของเมนู ส่งให้ EnterProgMode25 ตรง ๆ ไม่ผ่าน SetSPISpeed
//เพราะ override ศูนย์ของ SetSPISpeed แปลว่า "ใช้ค่าจากเมนู" แต่บางเมนู
//(6 MHz ของ FT232H) มี Tag เป็นศูนย์จริง ๆ
function StepDownSPISpeed(var LadderPos: integer; out SpeedTag: integer;
  out SpeedName: string): boolean;
var
  Ladder: array[0..9] of TMenuItem;
  Count, i: integer;
begin
  Result := False;
  SpeedTag := 0;
  SpeedName := '';
  for i := 0 to High(Ladder) do Ladder[i] := nil;
  Count := SPISpeedMenuLadder(Ladder);
  if Count = 0 then Exit;

  if LadderPos < 0 then
    for i := 0 to Count - 1 do
      if Ladder[i].Checked then
      begin
        LadderPos := i;
        Break;
      end;
  if (LadderPos < 0) or (LadderPos >= Count - 1) then Exit;

  Inc(LadderPos);
  SpeedTag := Ladder[LadderPos].Tag;
  SpeedName := StringReplace(Ladder[LadderPos].Caption, '&', '',
                             [rfReplaceAll]);
  Result := True;
end;

function ReadPassesAgree(First: TMemoryStream; StartAddress, Size: cardinal;
  Passes: integer; AcceptedSPISpeed: PInteger = nil): boolean;
var
  Again: TMemoryStream;
  Diff: cardinal;
  At: int64;
  i, LadderPos, SpeedTag: integer;
  SpeedName: string;
  Dropped: boolean;
begin
  Result := True;
  if (Passes < 2) or (First = nil) or (First.Size = 0) then Exit;

  Again := TMemoryStream.Create;
  try
    LadderPos := -1;
    Dropped := False;
    i := 2;
    while i <= Passes do
    begin
      LogPrint(Format(STR_READ_PASS, [i, Passes]));

      ReadFlash25(Again, StartAddress, Size);
      if UserCancel then Exit(False);
      if not OpOK then Exit(False);

      if Again.Size <> First.Size then
      begin
        OpFail(Format('read pass %d returned %d bytes, the first returned %d',
                      [i, Again.Size, First.Size]));
        Exit(False);
      end;

      At := FirstDifference(PByte(First.Memory), PByte(Again.Memory), First.Size);
      if At >= 0 then
      begin
        Diff := CountDifferences(PByte(First.Memory), PByte(Again.Memory),
                                 First.Size);
        LogPrint(Format(STR_READ_UNSTABLE, [Diff, cardinal(At)]));

        //บันไดถอยคล็อก: อ่านไม่ตรงกันบ่อยที่สุดเพราะหน้าสัมผัสคลิปหลวมนิดเดียว
        //ซึ่งมักหายเมื่อช้าลงหนึ่งขั้น ถ้าช้าสุดแล้วยังไม่ตรงกันค่อยปฏิเสธ
        if not StepDownSPISpeed(LadderPos, SpeedTag, SpeedName) then
        begin
          OpFail(Format('two reads of the same chip disagree in %d bytes',
                        [Diff]), At);
          Exit(False);
        end;

        LogPrint(Format(STR_READ_RETRY_SLOWER, [SpeedName]));
        if not EnterProgMode25(SpeedTag, MainForm.MenuSendAB.Checked) then
        begin
          OpFail('the programmer did not accept the slower SPI clock');
          Exit(False);
        end;
        Dropped := True;

        //ตัวอ้างอิงเดิมถ่ายที่คล็อกเร็วและอาจเป็นฝั่งที่ผิดเอง อ่านใหม่ทั้งคู่
        //ที่ความเร็วนี้ แล้วเริ่มนับ pass ใหม่
        ReadFlash25(First, StartAddress, Size);
        if UserCancel then Exit(False);
        if not OpOK then Exit(False);
        i := 2;
        Continue;
      end;

      Inc(i);
    end;

    LogPrint(STR_READ_STABLE);
    //ตรงกันก็จริง แต่ตรงกันที่ความเร็วต่ำกว่าที่ผู้ใช้เลือก บอกให้รู้ว่า
    //งานหน้าจะช้าอีกถ้าไม่แก้หน้าสัมผัสหรือปรับเมนูความเร็วลง
    if Dropped then
    begin
      LogPrint(Format(STR_READ_STABLE_SLOWER, [SpeedName]));
      if AcceptedSPISpeed <> nil then AcceptedSPISpeed^ := SpeedTag;
    end;
  finally
    Again.Free;
  end;
end;

//ดูตัวข้อมูลที่อ่านมาได้ ไม่ใช่ดูว่าการรับส่งสำเร็จ
//
//เป็นคำเตือน ไม่ใช่การตัดสิน ชิปเปล่าอ่านได้ FF ทั้งก้อนอย่างถูกต้องเสมอ
//สิ่งที่ทำได้คือบอกว่าดัมป์นี้หน้าตาเหมือนความล้มเหลวแบบไหน แล้วให้คนตัดสิน
procedure ScanDumpAndReport(Stream: TMemoryStream);
var
  S: TImgStats;
  V: TImgVerdict;
  Kind: string;
  Map: TIFDMap;
  TableLines: TStringList;
  i: integer;
begin
  //ล้างก่อนทุกทางออก ไม่งั้นคำเตือนของงานก่อนหน้าจะไปโผล่ในบรรทัด JSON
  //ของงานถัดไป ซึ่งเป็นงานที่อาจไม่ได้อ่านอะไรมาเลย
  LastImageWarning := '';

  if not OpUI.ScanImage then Exit;
  if (Stream = nil) or (Stream.Size = 0) then Exit;

  S := imgcheck.ScanImage(PByte(Stream.Memory), Stream.Size);
  LogPrint(Format(STR_IMG_STATS, [StatsText(S)]));

  Kind := DetectImageKind(PByte(Stream.Memory), Stream.Size);
  if Kind <> '' then LogPrint(Format(STR_IMG_KIND, [Kind]));

  //ภาพที่มี Intel flash descriptor บอกผังส่วนของตัวเองอยู่แล้ว พ่นให้เห็นเลย
  //งานซ่อมส่วนใหญ่ต้องรู้ว่า BIOS เริ่มตรงไหนโดยไม่แตะ ME
  if ParseIFD(PByte(Stream.Memory), Stream.Size, Map) then
  begin
    LogPrint(STR_IFD_REGIONS);
    TableLines := TStringList.Create;
    try
      TableLines.Text := IFDDescribe(Map, Stream.Size);
      for i := 0 to TableLines.Count - 1 do LogPrint(TableLines[i]);
    finally
      TableLines.Free;
    end;
  end;

  V := ImageVerdict(S);
  if V <> ivOK then
  begin
    LastImageWarning := VerdictText(V, S);
    LogPrint(Format(STR_IMG_SUSPECT, [LastImageWarning]));
  end;
end;

//แรงดันที่ผู้ใช้เลือกไว้ในเมนู หน่วยเป็นมิลลิโวลต์ ศูนย์แปลว่า "ตามชิป"
function SelectedCH347Vcc: cardinal;
begin
  Result := CH347_VCC_1V8_MV;
  if MainForm.MenuCH347VccAuto.Checked then Exit(0);
  if MainForm.MenuCH347Vcc3V3.Checked then Exit(CH347_VCC_3V3_MV);
  if MainForm.MenuCH347Vcc1V8.Checked then Exit(CH347_VCC_1V8_MV);
end;

//ตั้งแรงดันฝั่งเป้าหมายให้ตรงกับที่เลือกไว้ ก่อนเริ่มคุยกับชิป
//
//คืน True เมื่อ "ไม่มีอะไรต้องทำ" ด้วย เพราะเครื่องที่ตั้งแรงดันไม่ได้ไม่ใช่
//ความผิดพลาด แค่ไม่มีความสามารถนี้ ผู้เรียกจึงเอาไปคุมการหยุดงานได้ตรง ๆ
//
//โหมดอัตโนมัติอ่านช่วง Vcc จากชิปที่เลือก ถ้าชิปนั้นไม่ได้ระบุช่วงไว้จะไม่เดา
//แต่คงค่าเดิมไว้แล้วเตือน เพราะการเดาผิดข้างสูงทำชิปพัง
//แรงดันของชิปที่เลือกอยู่ ผ่านตัวหาสามชั้นใน utilfunc
//
function ApplyCH347Vcc: boolean;
var
  Want: cardinal;
  MinMv, MaxMv: cardinal;
  ChipVcc: string;
  OpenedHere: boolean;
begin
  Result := True;
  if AsProgrammer.Programmer = nil then Exit;
  if AsProgrammer.Current_HW <> CHW_CH347 then Exit;

  //โปรแกรมนี้เปิดอุปกรณ์เฉพาะตอนทำงานแล้วปิดทันทีที่จบ ตอนผู้ใช้กดเลือก
  //แรงดันจากหน้าจอ อุปกรณ์จึงยังไม่ได้เปิด และ SupportsTargetVoltage คืน
  //False ทำให้ฟังก์ชันนี้ออกไปเงียบ ๆ โดยไม่ได้ตั้งอะไรเลย
  //
  //อาการที่ผู้ใช้เจอคือกดเลือก 3.3V แล้ววัดดู ยังได้ 1.8V เหมือนเดิม
  //
  //เปิดเองชั่วคราวแล้วปิดคืนจึงเป็นสิ่งที่ต้องทำ ระดับที่ตั้งไว้ค้างอยู่ใน
  //ฮาร์ดแวร์ต่อไปหลังปิด จึงยังมีผลตอนเริ่มงานจริง
  OpenedHere := False;
  if not AsProgrammer.Programmer.SupportsTargetVoltage then
  begin
    if not AsProgrammer.Programmer.DevOpen then Exit;
    OpenedHere := True;
    if not AsProgrammer.Programmer.SupportsTargetVoltage then
    begin
      AsProgrammer.Programmer.DevClose;
      Exit;
    end;
  end;
  try

  Want := SelectedCH347Vcc;
  if Want = 0 then
  begin
    MinMv := 0;
    MaxMv := 0;
    ChipVcc := CurrentChipVccText;
    if ChipVcc <> '' then
      //ช่วงในแค็ตตาล็อกเขียนเป็นข้อความ เช่น "3.3" ใช้ตัวแปลงเดียวกับ CLI
      if not VccRangeMv(ChipVcc, MinMv, MaxMv) then
      begin
        MinMv := 0;
        MaxMv := 0;
      end;

    if not CH347VccForChip(MinMv, MaxMv, Want) then
    begin
      LogPrint(STR_CH347_VCC_UNKNOWN);
      Exit;
    end;
  end;

  //ระดับตรงตามที่ขออยู่แล้ว ไม่มีอะไรขยับ
  if AsProgrammer.Programmer.GetTargetVoltageMv = Want then Exit;

  if not AsProgrammer.Programmer.SetTargetVoltageMv(Want) then
  begin
    LogPrint(Format(STR_CH347_VCC_FAILED, [Want]));
    Exit(False);
  end;

  LogPrint(Format(STR_CH347_VCC_SET, [Want]));
  //รางเพิ่งขยับจริง ทุกอย่างที่สรุปไว้ตอนรางเดิมใช้ไม่ได้แล้ว รวมถึงการที่
  //ชิปเคยตอบ: ชิปที่ตอบตอน 3.3V ไม่ใช่หลักฐานว่ามีชิปอยู่ตอน 1.8V
  NoteSession(seRailChanged);
  finally
    //ปิดคืนเฉพาะตัวที่เราเปิดเอง ห้ามไปปิดของงานที่กำลังเดินอยู่
    if OpenedHere then AsProgrammer.Programmer.DevClose;
  end;
end;

//กล่องเลือกแรงดันบนหน้าหลัก ทำตามโปรแกรมของผู้ผลิตบอร์ด CH347Ⅱ V2.13
//ซึ่งวางกลุ่มปุ่ม "切换电压" (3.3V/1.8V) กับช่องแสดงแรงดันของชิปไว้บน
//หน้าจอเลย ไม่ต้องมุดเมนู
//
//เมนู Options -> SPI -> CH347 target voltage ยังเป็นแหล่งความจริงหนึ่งเดียว
//กล่องนี้เป็นกระจกของเมนู จะโผล่เฉพาะตอนที่เครื่องที่เลือกคือ CH347
procedure RefreshCH347VccPanel;
var
  ChipVcc: string;
  WasVisible: boolean;
begin
  WasVisible := MainForm.GroupCH347Vcc.Visible;
  CH347VccPanelUpdating := True;
  try
    MainForm.GroupCH347Vcc.Visible := AsProgrammer.Current_HW = CHW_CH347;
    MainForm.RadioCH347VccAuto.Checked := MainForm.MenuCH347VccAuto.Checked;
    MainForm.RadioCH347Vcc3V3.Checked := MainForm.MenuCH347Vcc3V3.Checked;
    MainForm.RadioCH347Vcc1V8.Checked := MainForm.MenuCH347Vcc1V8.Checked;

    //แรงดันของชิปที่เลือกอยู่ วางข้างปุ่มให้เทียบกันได้ในสายตาเดียว
    //แบบเดียวกับช่อง "芯片电压" ของโปรแกรมผู้ผลิต
    ChipVcc := CatalogVccDisplay(CurrentChipVccText);
    if ChipVcc = '' then ChipVcc := '?';
    MainForm.LabelCH347ChipVcc.Caption := 'Chip: ' + ChipVcc;
  finally
    CH347VccPanelUpdating := False;
  end;

  //ภาพชิปต้องขยับหลบหรือทวงพื้นที่คืน ตามการโผล่หายของกล่องนี้
  if WasVisible <> MainForm.GroupCH347Vcc.Visible then LayoutLeftPanel;
end;

procedure TMainForm.MenuCH347VccClick(Sender: TObject);
begin
  //ตั้งให้เห็นผลทันทีที่เลือก ผู้ใช้จะได้ไม่ต้องเดาว่าต้องกดอ่านก่อนไหม
  //อุปกรณ์ที่ยังไม่ได้เปิดจะโดน ApplyCH347Vcc ตอนเริ่มงานอยู่แล้ว
  ApplyCH347Vcc;
  RefreshCH347VccPanel;
end;

procedure TMainForm.RadioCH347VccChange(Sender: TObject);
begin
  if CH347VccPanelUpdating then Exit;
  //ปุ่มที่เพิ่งดับก็ยิง OnChange มาด้วย สนใจเฉพาะตัวที่เพิ่งติด
  if not (Sender as TRadioButton).Checked then Exit;

  MenuCH347VccAuto.Checked := RadioCH347VccAuto.Checked;
  MenuCH347Vcc3V3.Checked := RadioCH347Vcc3V3.Checked;
  MenuCH347Vcc1V8.Checked := RadioCH347Vcc1V8.Checked;
  //เส้นทางเดียวกับการคลิกที่เมนูทุกประการ รวมทั้งการจ่ายจริงทันที
  MenuCH347VccClick(Sender);
end;

//ติ๊กเมนูแรงดันของ CH347 ให้เป็นระดับที่ขอ แล้วพยายามจ่ายจริงทันที
//
//ติ๊กทั้งสามรายการเองตรง ๆ ไม่พึ่งกลไก RadioItem ของ LCL เพราะพฤติกรรม
//ตอนตั้ง Checked จากโค้ด (ไม่ใช่ผู้ใช้คลิก) ต่างจากตอนคลิกจริง
//อุปกรณ์ที่ปิดอยู่จะได้ระดับนี้ตอนงานถัดไปเริ่ม เหมือนผู้ใช้เลือกเมนูเอง
procedure PinCH347VccMenu(Millivolts: cardinal);
begin
  MainForm.MenuCH347VccAuto.Checked := False;
  MainForm.MenuCH347Vcc3V3.Checked := Millivolts = CH347_VCC_3V3_MV;
  MainForm.MenuCH347Vcc1V8.Checked := Millivolts <> CH347_VCC_3V3_MV;
  LogPrint(Format(STR_CH347_VCC_SWITCHED,
                  [CH347VccLevelText(SelectedCH347Vcc)]));
  ApplyCH347Vcc;
  RefreshCH347VccPanel;
end;

//หลังรู้แล้วว่าชิปตัวนี้คืออะไร: บอกแรงดันที่ชิปต้องการ เทียบกับที่ตั้งไว้
//แล้วชี้ทางแก้ที่เมนู ไม่สลับให้เองเงียบ ๆ นอกจากผู้ใช้ตอบตกลงในกล่องถาม
//
//เรียกจาก SelectChipAny เพราะทุกทางที่ได้ชิปมา (Read ID, หน้าต่างค้นหา,
//เมนูเลือกชิป, CLI) ไหลผ่านที่นั่นหมด โหมด CLI ได้แค่บรรทัดใน log
//
//พูดเฉพาะกับบอร์ดที่พิสูจน์แล้วว่าสลับแรงดันได้ บอร์ดที่สลับไม่ได้ยังอยู่ใต้
//ด่าน VoltageWarningOK แบบเดิม ชี้ไปเมนูที่กดแล้วไม่มีผลมีแต่จะพาหลงทาง
//ชื่อชิปที่เพิ่งถามเรื่องแรงดันไปแล้วในรอบนี้ กันถามซ้ำทุกครั้งที่ตรวจชิป
var
  AskedVccForChip: string = '';

//ถามผู้ใช้เมื่อไม่มีทางไหนบอกแรงดันของชิปตัวนี้ได้เลย
//
//ไม่เดาให้เด็ดขาด เพราะสองทิศทางไม่เท่ากัน: เดาสูงเกินคือจ่าย 3.3V ใส่ชิป
//1.8V แล้วชิปพังถาวร ส่วนเดาต่ำเกินแค่ชิปไม่ตอบแล้วลองใหม่ได้ ทางที่ถูกคือ
//ให้คนเปิดดาต้าชีตแล้วบอกมา
//
//ต้องถามจากที่นี่เท่านั้น เพราะเส้นทางนี้อยู่บน UI thread ส่วนงานจริงวิ่งบน
//worker ซึ่งเปิดกล่องข้อความไม่ได้
//
//คำตอบไปปักหมุดที่เมนูโดยตรง ไม่ใช่เก็บในตัวแปรลับ ผู้ใช้จะได้เห็นค่าที่
//กำลังใช้อยู่ตลอดเวลา และเปลี่ยนเองได้ทีหลังจากที่เดิม
procedure AskChipVccFromDatasheet;
var
  Key: string;
begin
  if AsProgrammer.Current_HW <> CHW_CH347 then Exit;
  //ปักหมุดไว้แล้วแปลว่าผู้ใช้ตัดสินใจไปแล้ว ไม่ต้องไปกวนอีก
  if SelectedCH347Vcc <> 0 then Exit;

  Key := UpperCase(Trim(CurrentICParam.Name));
  if Key = '' then Exit;
  if Key = AskedVccForChip then Exit;
  //จำไว้ก่อนถาม ผู้ใช้กด "ไว้ก่อน" แล้วจะได้ไม่โดนถามซ้ำทุกครั้งที่ตรวจชิป
  AskedVccForChip := Key;

  case QuestionDlg('AsProgrammer',
         Format(STR_CH347_VCC_ASK, [CurrentICParam.Name]), mtWarning,
         [mrNo, STR_CH347_VCC_ASK_18, mrYes, STR_CH347_VCC_ASK_33,
          mrCancel, STR_CH347_VCC_ASK_LATER], 0) of
    mrNo:
      begin
        PinCH347VccMenu(CH347_VCC_1V8_MV);
        LogPrint(Format(STR_CH347_VCC_CONFIRMED,
          [CurrentICParam.Name, CH347VccLevelText(CH347_VCC_1V8_MV)]));
      end;
    mrYes:
      begin
        PinCH347VccMenu(CH347_VCC_3V3_MV);
        LogPrint(Format(STR_CH347_VCC_CONFIRMED,
          [CurrentICParam.Name, CH347VccLevelText(CH347_VCC_3V3_MV)]));
      end;
  else
    //ไม่เลือกก็ไม่เป็นไร แต่ต้องบอกให้ชัดว่าจะเกิดอะไรขึ้นต่อจากนี้
    LogPrint(STR_CH347_VCC_ASK_NONE);
  end;
end;

procedure CH347ChipVccGuidance;
var
  WantMv: cardinal;
  ChipText, PinnedText, WantText: string;
  Mismatch: string;
  Advice: TCH347VccAdvice;
begin
  if AsProgrammer.Current_HW <> CHW_CH347 then Exit;
  if not CH347VoltageControlSeen then Exit;

  //ผ่านตัวหาสามชั้น ไม่ใช่ช่อง vcc ดิบ ไม่งั้นคำเตือน "ปักไว้สูงเกิน" จะไม่
  //ทำงานกับชิปเกือบทุกตัว เพราะแค็ตตาล็อกแทบไม่เคยกรอกช่องนั้นไว้
  ChipText := CatalogVccDisplay(CurrentChipVccText);
  Advice := CH347VccAdvise(CurrentChipVccText, SelectedCH347Vcc, WantMv);

  case Advice of
    cvaChipVccUnknown:
      begin
        LogPrint(STR_CH347_VCC_NO_INFO);
        //ไม่รู้แล้วเดาไม่ได้ ต้องให้คนเปิดดาต้าชีตแล้วยืนยันมา
        AskChipVccFromDatasheet;
        LogPrint(STR_CH347_VCC_GUIDE);
      end;
    cvaNoUsableRail:
      LogPrint(Format(STR_CH347_VCC_NO_RAIL, [ChipText]));
    cvaAutoWillApply:
      begin
        LogPrint(Format(STR_CH347_VCC_CHIP, [ChipText]));
        LogPrint(Format(STR_CH347_VCC_AUTO_OK, [WantMv]));
      end;
    cvaPinnedMatches:
      begin
        LogPrint(Format(STR_CH347_VCC_CHIP, [ChipText]));
        LogPrint(STR_CH347_VCC_MATCH);
      end;
    cvaPinnedTooHigh, cvaPinnedTooLow:
      begin
        PinnedText := CH347VccLevelText(SelectedCH347Vcc);
        WantText := CH347VccLevelText(WantMv);
        if Advice = cvaPinnedTooHigh then
          Mismatch := Format(STR_CH347_VCC_TOO_HIGH, [ChipText, PinnedText])
        else
          Mismatch := Format(STR_CH347_VCC_TOO_LOW, [ChipText, PinnedText]);

        LogPrint(Format(STR_CH347_VCC_CHIP, [ChipText]));
        LogPrint(Mismatch);

        if CLIMode then
        begin
          LogPrint(STR_CH347_VCC_GUIDE);
          Exit;
        end;

        if MessageDlg('AsProgrammer',
             Mismatch + '.' + LineEnding + LineEnding +
             Format(STR_CH347_VCC_SWITCH_Q, [WantText]) + LineEnding +
             STR_CH347_VCC_GUIDE,
             mtWarning, [mbYes, mbNo], 0) = mrYes then
          PinCH347VccMenu(WantMv)
        else
          LogPrint(STR_CH347_VCC_GUIDE);
      end;
  end;
end;

//---------------------------------------------------- ด่านไฟฟ้าก่อนปลุกบัส
//
//จุดนี้คือที่เดียวที่ทั้งหน้าจอ บรรทัดคำสั่ง และสคริปต์ต้องผ่านก่อน CS/CLK
//ขยับ กติกา "ห้ามเขียนเมื่อแรงดันไม่ตรง" จึงอยู่ในหน่วยแกน (railreport กับ
//electricalpreflight) ไม่ได้อยู่ในตัวจัดการปุ่ม ที่นี่ทำแค่รวบรวมข้อเท็จจริง
//ส่งไปให้แกนตัดสิน แล้วรายงานผล

var
  ProgSession: TProgrammingSession = nil;

function Session: TProgrammingSession;
begin
  if ProgSession = nil then ProgSession := TProgrammingSession.Create;
  Result := ProgSession;
end;

procedure NoteSession(Event: TSessionEvent);
var
  Refusal: string;
begin
  if Session.Apply(Event, Refusal) then Exit;
  //เหตุการณ์ที่ถูกปฏิเสธไม่ใช่เหตุให้ล้มงาน แต่แปลว่ามีเส้นทางไหนสักเส้นที่
  //เดินผิดลำดับ หรือมีทางรวมที่ยังไม่ได้ป้อนเข้ามา ทั้งสองอย่างต้องเห็น
  LogPrint('session: ' + Refusal);
end;

function SessionAllows(Op: TSessionOperation): boolean;
begin
  Result := Session.MayStart(Op);
  if Result then Exit;
  //ข้อความบอกช่องว่างแรกที่ยังขาด ไม่ใช่รายการทั้งหมด เพราะช่องแรกคือช่องที่
  //ผู้ใช้ต้องไปปิด ส่วนที่เหลือมักตามมาเอง
  LogPrint('session: ' + Session.StartRefusal(Op));
end;

//ความเร็วบัสที่กำลังจะใช้จริง หน่วยเป็นเฮิรตซ์
//
//เมนูเก็บเป็นดัชนีของตัวหาร ไม่ใช่ตัวเลขความถี่ ด่านไฟฟ้าเทียบกับเพดานของ
//ชิปและของบอร์ดเป็นเฮิรตซ์ จึงต้องแปลงที่นี่ คืน 0 เมื่อไม่รู้ ซึ่งด่านจะ
//ถือว่าเป็นเรื่องที่ยังไม่มีใครวัด ไม่ใช่เหตุให้ปฏิเสธ
function CurrentBusHz: cardinal;
var
  Index: integer;
begin
  Result := 0;
  case AsProgrammer.Current_HW of
    CHW_CH347:
      begin
        //ตารางตัวหารของ CH347: ดัชนี 0 คือ 60MHz แล้วหารสองไปเรื่อย ๆ
        //ตรงกับลำดับรายการในเมนู MenuCH347SPIClock*
        Index := SetSPISpeed(0);
        if (Index >= 0) and (Index <= 7) then
          Result := cardinal(60000000) shr Index;
      end;
    CHW_FT232H:
      begin
        Index := SetSPISpeed(0);
        if Index = MainForm.MenuFT232SPI30Mhz.Tag then Result := 30000000
        else if Index = MainForm.MenuFT232SPI6Mhz.Tag then Result := 6000000;
      end;
  end;
end;

//ข้อกำหนดทางไฟฟ้าของชิปที่เลือกอยู่
//
//คืน False เมื่อไม่รู้แรงดันของชิป ซึ่งเกิดบ่อยมาก: chiplist.xml กรอกช่อง
//vcc ไว้ไม่กี่รายการ ตัวหาสามชั้นใน utilfunc ช่วยได้เยอะแต่ไม่ครบ เมื่อไม่รู้
//ก็ตัดสินไม่ได้ ผู้เรียกต้องเตือนแล้วปล่อยผ่าน ไม่ใช่แกล้งรู้
function CurrentChipRequirements(
  const Caps: TProgrammerElectricalCapabilities;
  out Target: TTargetElectricalRequirements): boolean;
var
  MinMv, MaxMv: cardinal;
begin
  FillChar(Target, SizeOf(Target), 0);
  Result := False;
  if not VccRangeMv(CurrentChipVccText, MinMv, MaxMv) then Exit;

  Target.Protocol := spSPI;
  Target.VccMinMv := MinMv;
  Target.VccMaxMv := MaxMv;
  //ขา I/O ของแฟลชอนุกรมทนได้ถึงระดับ Vcc ของมันเอง (ดาต้าชีตเขียน
  //Vcc + 0.4V ตอนสูงสุดสัมบูรณ์) เพดานที่ปลอดภัยจึงคือปลายบนของช่วง Vcc
  //ห้ามใส่ค่าที่กว้างกว่านี้ เพราะนี่คือด่านเดียวที่จับกรณี "ไฟเลี้ยงสลับ
  //แล้วแต่สัญญาณยังเป็นระดับเดิม"
  Target.VioMaxMv := MaxMv;
  //แค็ตตาล็อกไม่มีช่องความเร็วสูงสุดของชิป ใช้เพดานของเครื่องแทน แปลว่า
  //ด่านนี้จะจับได้เฉพาะกรณีที่ขอเกินกว่าที่ "เครื่อง" ทำได้ ส่วนเพดานของ
  //ชิปจริง ๆ เป็นงานของ Auto Tune Clock ไม่ใช่ของด่านนี้
  Target.MaxBusHz := Caps.MaxBusHz[spSPI];
  if Target.MaxBusHz = 0 then Target.MaxBusHz := 60000000;
  Target.RequiredProgrammerID := 'any';
  Target.RequiredAdapterID := 'none';
  Target.RequiresOpenDrain := False;
  //หนีบบนเมนบอร์ดคือเรื่องปกติของโปรแกรมนี้ ไฟจากภายนอกจึงไม่ใช่ความผิด
  //ในตัวมันเอง สิ่งที่ผิดคือจ่ายไฟชนกัน ซึ่ง piPowerSourceContention จับอยู่
  Target.AllowsExternalPower := True;
  Result := True;
end;

//รวบรวมสิ่งที่เครื่องบอกได้ ณ ตอนนี้ ผู้เรียกทุกคนใช้ชุดเดียวกัน
function CollectElectricalFacts(
  out Caps: TProgrammerElectricalCapabilities;
  out Obs: TElectricalObservation;
  out CapsValid, ObsValid: boolean): boolean;
begin
  FillChar(Caps, SizeOf(Caps), 0);
  FillChar(Obs, SizeOf(Obs), 0);
  CapsValid := False;
  ObsValid := False;
  Result := AsProgrammer.Programmer <> nil;
  if not Result then Exit;

  CapsValid := AsProgrammer.Programmer.GetElectricalCapabilities(Caps);
  ObsValid := AsProgrammer.Programmer.GetElectricalObservation(Obs);
  //ความเร็วบัสไม่ใช่ของที่ backend รู้ มันมาจากเมนูบนหน้าจอหรือจากสวิตช์
  //ของบรรทัดคำสั่ง เติมตรงนี้ที่เดียว ผู้เรียกจะได้ไม่ลืมทีละที่
  if ObsValid then Obs.RequestedBusHz := CurrentBusHz;
end;

procedure LogRailReport;
var
  Caps: TProgrammerElectricalCapabilities;
  Obs: TElectricalObservation;
  CapsValid, ObsValid: boolean;
  Lines: TRailLines;
  i: integer;
begin
  if not CollectElectricalFacts(Caps, Obs, CapsValid, ObsValid) then Exit;
  Lines := RailReportLines(BuildRailReport(Caps, Obs, CapsValid, ObsValid));
  for i := 0 to High(Lines) do LogPrint(Lines[i]);
end;

function BenchPreflightOK(Destructive: boolean): boolean;
var
  Caps: TProgrammerElectricalCapabilities;
  Adapter: TAdapterElectricalCapabilities;
  Obs: TElectricalObservation;
  Target: TTargetElectricalRequirements;
  Verdict: TBenchVerdict;
  CapsValid, ObsValid: boolean;
  Lines: TRailLines;
  i: integer;
begin
  Result := True;
  if not CollectElectricalFacts(Caps, Obs, CapsValid, ObsValid) then Exit;

  //ไม่มีอะแดปเตอร์ที่ประกาศตัวได้ในโปรแกรมนี้ ปล่อยว่างไว้ตรง ๆ ดีกว่า
  //กรอกค่าเดาแล้วให้ด่านเชื่อว่ามีของที่ไม่มีจริง
  FillChar(Adapter, SizeOf(Adapter), 0);
  Adapter.Present := False;

  if not CurrentChipRequirements(Caps, Target) then
  begin
    //ไม่รู้แรงดันของชิป ก็ไม่มีอะไรให้เทียบ ทางที่ถูกคือบอกตรง ๆ แล้วให้
    //ด่านเดิม (CH347ChipVccGuidance กับ AskChipVccFromDatasheet) ทำงานต่อ
    //การปฏิเสธตรงนี้จะทำให้ชิปส่วนใหญ่ในแค็ตตาล็อกใช้งานไม่ได้เลย
    LogPrint('preflight note: the chip supply voltage is unknown, so the ' +
             'rail could not be checked against it');
    Exit;
  end;

  Verdict := EvaluateBenchPreflight(Caps, Adapter, Target, Obs, Destructive);
  Lines := BenchVerdictLines(Verdict);
  for i := 0 to High(Lines) do LogPrint(Lines[i]);

  Result := Verdict.Allowed;
  //ล้มก่อนที่ CS หรือ CLK จะขยับ ไม่ใช่ล้มระหว่างทาง
  if not Result then
  begin
    LogPrint('preflight refused the operation; the bus was not started');
    //ผู้เรียกที่เป็นเครื่องต้องแยกได้ว่า "แรงดันผิด" ไม่ใช่ "ล้มเหลวเฉย ๆ"
    //เพราะสิ่งที่ต้องทำต่อไม่เหมือนกัน
    NoteCLIOutcome(coVoltageRefused);
    NoteSession(sePreflightFailed);
  end
  else if Session.Holds(sfChipDetected) then
    //ด่านไฟฟ้าผ่านได้ตั้งแต่ก่อนรู้จักชิป (เส้นทางปลุกบัสเพื่อไปอ่าน ID)
    //แต่ "ผ่านแล้ว" ในความหมายของลำดับขั้นต้องมีชิปให้ตัดสินก่อน
    NoteSession(sePreflightPassed);
end;

//------------------------------------------------ หาความเร็วที่สายรับไหวจริง
//
//README บอกอยู่แล้วว่าสายหนีบหรือสายยาวไม่รอดที่ 60MHz แล้วอ่านกลับได้ FF
//การปล่อยให้ผู้ใช้เลือกเองคือให้เขาเดาระหว่างเมนูตัวเลขที่ไม่มีผลตอบกลับ
//เร็วไปได้ขยะที่หน้าตาเหมือนชิปว่าง ช้าไปเสียเวลาเป็นนาทีต่อเมกะไบต์
//และไม่มีอะไรบอกว่าตอนนี้อยู่ฝั่งไหนของเส้น ที่นี่คือตัวหาเส้นนั้นให้
//
//กติกาการตัดสินอยู่ใน clocktune ซึ่งทดสอบด้วยชิปปลอมในหน่วยความจำได้ครบ
//ทุกกรณี ที่นี่ทำแค่ส่วนที่ต้องแตะฮาร์ดแวร์จริง: ติ๊กเมนู ปลุกบัส อ่าน ID
//และอ่านข้อมูลจริงมาทำลายพิมพ์

//ตัวอ่านของเครื่องทดสอบความจุ ใช้ซ้ำที่นี่เพราะเป็นทางอ่านแบบเดียวกับที่งาน
//จริงใช้ ตัวจริงอยู่ท้ายไฟล์ ประกาศล่วงหน้าไว้ให้สองฟังก์ชันข้างล่างเรียกได้
function CapTestRead(Address: QWord; Len: cardinal; out Data: TBytes;
  out ErrorText: string): boolean; forward;

type
  TSPIClockRung = record
    Hz: cardinal;
    Tag: integer;
  end;

var
  //บันไดความเร็วของงานปรับจูนรอบนี้ เรียงช้าไปเร็ว ตรงตามที่ clocktune ต้องการ
  TuneRungs: array of TSPIClockRung;

//บันไดความเร็วเป็นเฮิรตซ์ พร้อม Tag ของเมนูที่คู่กัน
//
//รับเฉพาะเครื่องที่รู้ความถี่จริงของทุกขั้น: CH347 กับ FT232H ส่วนเครื่องที่
//เมนูบอกแต่ชื่อขั้นโดยไม่มีตัวเลขที่ยืนยันได้ ไม่เอามาปรับจูน เพราะการเดา
//ความถี่แล้วรายงานว่า "จูนไว้ที่ 3MHz" ทั้งที่ไม่รู้ว่าใช่หรือเปล่า แย่กว่า
//การบอกตรง ๆ ว่าเครื่องนี้ยังไม่รองรับ
function BuildSPIClockRungs: integer;
var
  Items: array[0..15] of TMenuItem;
  Count, i, N: integer;
  Hz: cardinal;
begin
  SetLength(TuneRungs, 0);
  Result := 0;
  if (AsProgrammer.Current_HW <> CHW_CH347) and
     (AsProgrammer.Current_HW <> CHW_FT232H) then Exit;

  for i := 0 to High(Items) do Items[i] := nil;
  Count := SPISpeedMenuLadder(Items);
  if Count < 2 then Exit;

  N := 0;
  //เมนูเรียงเร็วไปช้า บันไดต้องเรียงกลับกัน
  for i := Count - 1 downto 0 do
  begin
    Hz := 0;
    case AsProgrammer.Current_HW of
      CHW_CH347:
        //ตารางตัวหารของ CH347: Tag คือจำนวนครั้งที่หาร 60MHz ด้วยสอง
        if (Items[i].Tag >= 0) and (Items[i].Tag <= 7) then
          Hz := cardinal(60000000) shr Items[i].Tag;
      CHW_FT232H:
        if Items[i] = MainForm.MenuFT232SPI30Mhz then Hz := 30000000
        else if Items[i] = MainForm.MenuFT232SPI6Mhz then Hz := 6000000;
    end;
    if Hz = 0 then Continue;
    SetLength(TuneRungs, N + 1);
    TuneRungs[N].Hz := Hz;
    TuneRungs[N].Tag := Items[i].Tag;
    Inc(N);
  end;
  Result := N;
end;

function TuneTagForHz(Hz: cardinal): integer;
var
  i: integer;
begin
  for i := 0 to High(TuneRungs) do
    if TuneRungs[i].Hz = Hz then Exit(TuneRungs[i].Tag);
  Result := -1;
end;

//พิมพ์ของชิปที่คล็อกหนึ่ง ๆ
//
//ไม่ใช้แค่ JEDEC ID สามไบต์ เพราะคล็อกที่พังเฉพาะทรานสเฟอร์ยาวจะผ่านการอ่าน
//สามไบต์ได้สบาย ๆ แล้วไปพังตอนอ่านจริงซึ่งสายเกินไป จึงผนวก CRC ของข้อมูล
//จริง 4KB เข้าไปด้วย นั่นคือทรานสเฟอร์แบบเดียวกับที่งานอ่านทั้งชิปใช้
function TuneIdentityReader(ClockHz: cardinal; out Identity: string): boolean;
var
  Tag: integer;
  ID: array[0..2] of byte;
  Data: TBytes;
  Err: string;
  Len: cardinal;
begin
  Identity := '';
  Result := False;

  Tag := TuneTagForHz(ClockHz);
  if Tag < 0 then Exit;
  if not EnterProgMode25(Tag, MainForm.MenuSendAB.Checked) then Exit;

  if not UsbAsp25_ReadJEDEC9FExact(ID) then Exit;
  Identity := IntToHex(ID[0], 2) + IntToHex(ID[1], 2) + IntToHex(ID[2], 2);

  Len := 4096;
  if (CurrentICParam.Size > 0) and (CurrentICParam.Size < Len) then
    Len := CurrentICParam.Size;
  Data := nil;
  if not CapTestRead(0, Len, Data, Err) then Exit;
  if cardinal(Length(Data)) <> Len then Exit;
  //ทรานสเฟอร์สั้นกว่าที่ขอคือสัญญาณของสายที่ชายขอบ ไม่ใช่ข้อมูลที่สั้นลง
  Identity := Identity + '-' +
    IntToHex(UpdateCRC32($FFFFFFFF, @Data[0], Len), 8);
  Result := True;
end;

function AutoTuneSPIClock: boolean;
var
  Ladder: TClockLadder;
  Tune: TTuneResult;
  Count, i, Tag: integer;
  Items: array[0..15] of TMenuItem;
  MenuCount: integer;
begin
  Result := False;
  Count := BuildSPIClockRungs;
  if Count < 2 then
  begin
    LogPrint('auto tune: this programmer does not expose a clock ladder with ' +
             'known frequencies; nothing to tune');
    Exit;
  end;

  SetLength(Ladder, Count);
  for i := 0 to Count - 1 do Ladder[i] := TuneRungs[i].Hz;

  LogPrint(Format('auto tune: probing %d clocks from %s to %s, three reads ' +
    'each', [Count, ClockText(Ladder[0]), ClockText(Ladder[Count - 1])]));

  //สามรอบต่อขั้น เพราะสองรอบที่บังเอิญตรงกันเกิดขึ้นบ่อยบนคล็อกที่ชายขอบ
  //ถอยหนึ่งขั้นเป็นระยะเผื่อ เส้นที่วัดได้ตอนบอร์ดยังเย็นและโต๊ะยังนิ่ง
  //ไม่ใช่เส้นที่อยู่ทนไปทั้งบ่าย
  Tune := AutoTuneClock(Ladder, @TuneIdentityReader, 3, 1);
  LogPrint('auto tune: ' + Tune.Detail);

  case Tune.Status of
    tsNoAnswer:
      begin
        LogPrint('auto tune: no clock produced an identity. Check the rail, ' +
                 'the orientation of pin 1, and that the chip is seated');
        Exit;
      end;
    tsUnstableAtSlowest:
      begin
        //สำคัญที่สุดคือห้ามบอกว่า "ลองช้ากว่านี้" เพราะช้ากว่านี้ไม่มีแล้ว
        //และไม่ใช่ทางแก้ ปัญหาอยู่ที่หน้าสัมผัส
        LogPrint('auto tune: the connection itself is unstable. Reseat the ' +
                 'clip or the socket; a slower clock will not help');
        Exit;
      end;
  end;

  //ติ๊กเมนูให้ตรงกับที่จูนได้ ผู้ใช้จะได้เห็นค่าที่กำลังใช้อยู่ในที่เดิม
  //ไม่ใช่เก็บไว้ในตัวแปรลับที่ไม่มีใครเห็น
  Tag := TuneTagForHz(Tune.ChosenHz);
  for i := 0 to High(Items) do Items[i] := nil;
  MenuCount := SPISpeedMenuLadder(Items);
  for i := 0 to MenuCount - 1 do
    Items[i].Checked := Items[i].Tag = Tag;

  LogPrint(Format('auto tune: using %s (stable to %s)',
    [ClockText(Tune.ChosenHz), ClockText(Tune.HighestStableHz)]));
  //กลับไปอยู่ที่ความเร็วที่เพิ่งเลือก ก่อนคืนการควบคุมให้ผู้เรียก
  Result := EnterProgModeSPI25;
end;

function ConnectionStableForDestructive: boolean;
const
  SAMPLE_LEN = 4096;
var
  Samples: array of TSamplePair;
  Addresses: array[0..2] of cardinal;
  Size, Len: cardinal;
  i: integer;
  Err: string;
  V: TStabilityVerdict;
begin
  Size := CurrentICParam.Size;
  if Size = 0 then
  begin
    //ไม่รู้ขนาดชิปก็ไม่รู้ว่าจะอ่านตรงไหน และ "ตรวจไม่ได้" ต้องไม่กลายเป็น
    //"ผ่าน" เด็ดขาด
    NoteCLIOutcome(coUnstable);
    LogPrint('connection check refused the operation: the chip size is ' +
             'unknown, so no sample region could be chosen');
    Exit(False);
  end;

  Len := SAMPLE_LEN;
  if Size < Len then Len := Size;
  Addresses[0] := 0;
  if Size <= Len then
  begin
    //ชิปเล็กกว่าหนึ่งตัวอย่าง อ่านทั้งตัวสองรอบไปเลย
    SetLength(Samples, 1);
  end
  else
  begin
    //หัว กลาง ท้าย เพราะสายที่ชายขอบมักพังไม่เท่ากันตลอดชิป และการสุ่มอ่าน
    //แต่หัวชิปคือการตรวจส่วนที่ปกติดีที่สุดอยู่แล้ว
    Addresses[1] := (Size div 2) and not (Len - 1);
    Addresses[2] := Size - Len;
    SetLength(Samples, 3);
  end;

  for i := 0 to High(Samples) do
  begin
    Samples[i].Address := Addresses[i];
    //สองรอบต้องเป็นการอ่านคนละครั้งจริง ๆ ไม่ใช่ก๊อปบัฟเฟอร์เดิม
    Samples[i].FirstOk := CapTestRead(Addresses[i], Len,
                                      Samples[i].First, Err);
    Samples[i].SecondOk := CapTestRead(Addresses[i], Len,
                                       Samples[i].Second, Err);
  end;

  V := EvaluateSampleStability(Samples);
  if V.Stable then
  begin
    LogPrint('connection check: ' + V.Reason);
    if V.AllBlank then
      LogPrint('connection check: the chip may be blank, or may not be ' +
               'connected; this check cannot tell those apart');
    Exit(True);
  end;

  NoteCLIOutcome(coUnstable);
  LogPrint('connection check refused the operation: ' + V.Reason);
  LogPrint(Format('connection check: sample at %.8X failed',
                  [V.FailedAddress]));
  if V.HasOffset then
    //ตำแหน่งไบต์แรกที่ไม่ตรง ไม่ใช่แค่ "ไม่ผ่าน"
    LogPrint(Format('connection check: first difference at address %.8X',
                    [V.FirstDifferingOffset]));
  LogPrint('connection check: erase and write are not allowed while the ' +
           'chip answers the same question two different ways');
  Result := False;
end;

//-------------------------------------------- ตรวจซ้ำในเซสชันใหม่หลังเขียน
//
//สิ่งที่ผู้ใช้ขอคือ "ปิดและเปิด target rail แล้ว verify ซ้ำ" ซึ่งเป็นวิธีจับ
//ชิปที่ตอบถูกจากบัฟเฟอร์ภายในโดยที่เซลล์จริงยังไม่ติด แต่บอร์ดที่โปรแกรมนี้
//รองรับทำไม่ได้สักตัว: GPIO6 ของ CH347 "เลือก" ระหว่าง 1.8V กับ 3.3V ไม่มี
//สถานะปิด และไม่มี backend ไหนมีคำสั่งตัดไฟฝั่งเป้าหมายเลย
//
//จึงทำเท่าที่ทำได้จริงและเรียกให้ตรงกับสิ่งที่ทำ: ปิดอุปกรณ์ USB เปิดใหม่
//ปลุกบัสใหม่ แล้วอ่านเทียบอีกรอบ
//
//สิ่งที่รอบนี้จับได้: การอ่านที่ถูกแคชไว้ในไดรเวอร์หรือใน DLL, หน้าสัมผัส
//ที่ชายขอบซึ่งโผล่เฉพาะตอน init ใหม่, และสถานะค้างในชิปที่หายไปเมื่อ CS
//ถูกยกและบัสถูกตั้งค่าใหม่ทั้งชุด
//
//สิ่งที่รอบนี้จับไม่ได้: การเก็บข้อมูลของเซลล์เมื่อไฟดับจริง ต้องมี load
//switch บนบอร์ดถึงจะตรวจได้ ซึ่งอยู่ในรายการฮาร์ดแวร์ที่ hardware/ บันทึกไว้
//แล้ว ห้ามรายงานว่าผ่าน "power-cycle verify" เด็ดขาด เพราะไม่ได้ทำ
//ตัวตรวจของเส้นทางเขียนปกติ ตัวจริงอยู่ท้ายไฟล์
procedure VerifyFlash25(var RomStream: TMemoryStream;
  StartAddress, DataSize: cardinal); forward;

function ReVerifyInFreshSession(StartAddr, Len: cardinal): boolean;
begin
  Result := True;
  if AsProgrammer.Programmer = nil then Exit;
  if RomF = nil then Exit;

  LogPrint('re-verifying in a fresh device session');

  ExitProgMode25;
  AsProgrammer.Programmer.DevClose;
  //ให้ไดรเวอร์ปล่อยหมายเลขอุปกรณ์คืนก่อน เปิดซ้ำเร็วเกินไปบางครั้งได้
  //แฮนเดิลเดิมกลับมาโดยที่สถานะยังไม่ถูกล้าง ซึ่งทำให้รอบนี้ไม่มีความหมาย
  Sleep(250);

  if not AsProgrammer.Programmer.DevOpen then
  begin
    //เปิดไม่ได้แปลว่าตรวจไม่ได้ ไม่ใช่ตรวจแล้วผ่าน
    OpFail('the device could not be reopened for the second verify pass');
    NoteCLIOutcome(coProgrammerLost);
    Exit(False);
  end;

  if not EnterProgModeSPI25 then
  begin
    OpFail('the bus could not be restarted for the second verify pass');
    Exit(False);
  end;

  RomF.Position := 0;
  MainForm.MPHexEditorEx.SaveToStream(RomF);
  RomF.Position := 0;
  VerifyFlash25(RomF, StartAddr, Len);
  Result := OpOK;
  if Result then
    LogPrint('the second verify pass agreed, in a session that shares no ' +
             'state with the first. Note this is a fresh USB session, not a ' +
             'power cycle: no supported programmer can remove target power, ' +
             'so data retention across a real power loss is untested')
  else
    LogPrint('the chip verified once and then disagreed in a fresh session; ' +
             'treat the write as failed');
end;

function EnterProgModeSPI25: boolean;
begin
  //ตั้งแรงดันก่อนปลุกบัสเสมอ ถ้าตั้งไม่ได้ตามที่ขอต้องไม่เดินงานต่อ
  //การเขียนชิป 1.8V ด้วยไฟ 3.3V ทำให้ชิปพังถาวร ยอมล้มงานดีกว่า
  if not ApplyCH347Vcc then Exit(False);
  //แล้วค่อยถามด่านไฟฟ้าว่าระดับที่จ่ายอยู่ใช้กับชิปตัวนี้ได้จริงไหม
  //ApplyCH347Vcc บอกได้แค่ว่า "ตั้งได้ตามที่ขอ" ไม่ได้บอกว่าที่ขอนั้นถูก
  if not BenchPreflightOK(False) then Exit(False);
  Result := EnterProgMode25(SetSPISpeed(0), MainForm.MenuSendAB.Checked);
end;

//---------------------------------------------------------------- chip tests
//
//callback ของเครื่องทดสอบใน chiptest.pas: อ่าน/ลบ/เขียนด้วย primitive ของ
//ตระกูล 25 ตรง ๆ ตัวลบใช้ opcode ของชิปที่เลือกอยู่ (ค่าปริยาย 20h/4KB)

var
  CapEraseOpcode: byte = $20;
  //ชิปเกิน 16MB คุยได้สองแบบ ตั้งโดย ChipTestBegin4B เท่านั้น:
  //CapUse4B = เข้าโหมด 4 ไบต์แล้ว ทุกเฟรมพกแอดเดรสเต็มสี่ไบต์
  //CapUseEAR = ชิปตระกูล C5h เฟรมยังเป็น 3 ไบต์ ทะเบียน EAR เติม A31:24
  CapUse4B: boolean = False;
  CapUseEAR: boolean = False;
  CapEARBank: integer = -1;   //-1 = ยังไม่รู้ บังคับเขียนครั้งแรกเสมอ

procedure ChipTestLogSink(const Msg: string);
begin
  LogPrint(Msg);
end;

//ตั้งหน้า 16MB ของชิปตระกูล EAR: WREN, เขียน C5h, แล้วอ่านกลับด้วย C8h
//ทะเบียนที่ไม่ยอมติดคือคำตอบ ไม่ใช่รายละเอียด เพราะหน้าที่ผิดแปลว่า
//ทุกคำสั่งถัดไปลงคนละ 16MB กับที่ตั้งใจทั้งยวง
function CapSetBank(Bank: byte; out ErrorText: string): boolean;
var
  Cmd: array[0..1] of byte;
  Back: array[0..0] of byte;
begin
  Result := False;
  ErrorText := '';
  if CapEARBank = integer(Bank) then Exit(True);

  UsbAsp25_Wren();
  Cmd[0] := $C5;
  Cmd[1] := Bank;
  if SPIWrite(1, 2, Cmd) <> 2 then
  begin
    ErrorText := 'the extended-address-register write was not transferred ' +
                 'exactly';
    Exit;
  end;
  Cmd[0] := $C8;
  if (SPIWrite(0, 1, Cmd) <> 1) or (SPIRead(1, 1, Back) <> 1) then
  begin
    ErrorText := 'the extended address register could not be read back';
    Exit;
  end;
  if Back[0] <> Bank then
  begin
    ErrorText := Format('the extended address register reads %.2x after ' +
                        'writing %.2x; the bank did not stick',
                        [Back[0], Bank]);
    Exit;
  end;
  CapEARBank := integer(Bank);
  Result := True;
end;

//เตรียมโหมดแอดเดรสให้เครื่องทดสอบ ผู้เรียกต้อง ChipTestEnd4B ใน finally
//เสมอ (เรียกซ้ำได้ปลอดภัยเมื่อไม่ได้เข้าโหมดใดเลย)
function ChipTestBegin4B(ChipSize: QWord): boolean;
var
  Err: string;
begin
  CapUse4B := False;
  CapUseEAR := False;
  CapEARBank := -1;
  Result := True;
  if ChipSize <= QWord(16) * 1024 * 1024 then Exit;

  if Chip25Entry4B = E4B_EXTC5 then
  begin
    //ตระกูล EAR: ไม่มีโหมดให้เข้า มีแต่หน้าให้ตั้ง เริ่มที่หน้า 0 และ
    //พิสูจน์เสียเลยว่าทะเบียนเขียนแล้วติดจริง
    CapUseEAR := True;
    Result := CapSetBank(0, Err);
    if not Result then OpFail(Err);
    Exit;
  end;

  CapUse4B := True;
  Result := Enter4B;
  if not Result then CapUse4B := False;
end;

//คืนสถานะแอดเดรสของชิปให้เหมือนก่อนเริ่ม: หน้า EAR กลับเป็นศูนย์
//(เครื่องมือทุกตัวบนโลกตั้งสมมุติฐานนั้น) และออกจากโหมด 4 ไบต์
procedure ChipTestEnd4B;
var
  Err: string;
begin
  if CapUseEAR then
  begin
    CapEARBank := -1; //บังคับให้เขียนจริง ไม่ใช่เชื่อแคชของตัวเอง
    if not CapSetBank(0, Err) then
      LogPrint('WARNING: the extended address register may be nonzero: ' +
               Err);
    CapUseEAR := False;
  end;
  Leave4B;
  CapUse4B := False;
end;

function CapTestRead(Address: QWord; Len: cardinal; out Data: TBytes;
  out ErrorText: string): boolean;
var
  Tmp: TBytes;
  Off: cardinal;
  Chunk, Got: integer;
begin
  Result := False;
  ErrorText := '';
  Data := nil;
  SetLength(Data, Len);
  Off := 0;
  while Off < Len do
  begin
    Chunk := AsProgrammer.Programmer.SPIMaxTransfer;
    if cardinal(Chunk) > Len - Off then Chunk := integer(Len - Off);
    //หน้า EAR: ก้อนห้ามข้ามขอบ 16MB และหน้าต้องตรงก่อนทุกคำสั่ง
    if CapUseEAR then
      Chunk := integer(EARChunkClamp(Address + Off, cardinal(Chunk)));
    Tmp := nil;
    SetLength(Tmp, Chunk);
    if CapUseEAR then
    begin
      if not CapSetBank(EARBankOf(Address + Off), ErrorText) then Exit;
      Got := UsbAsp25_Read($03, longword((Address + Off) and $FFFFFF),
                           Tmp, Chunk);
    end
    //ในโหมด 4 ไบต์ opcode 03h เดิมรับแอดเดรสเต็มสี่ไบต์
    else if CapUse4B then
      Got := UsbAsp25_Read32bitAddr($03, longword(Address + Off), Tmp, Chunk)
    else
      Got := UsbAsp25_Read($03, longword(Address + Off), Tmp, Chunk);
    if Got <> Chunk then
    begin
      ErrorText := Format('read at 0x%.8x moved %d of %d bytes',
                          [Address + Off, Got, Chunk]);
      Exit;
    end;
    Move(Tmp[0], Data[Off], Chunk);
    Inc(Off, cardinal(Chunk));
    OpProcessMessages;
  end;
  Result := True;
end;

function CapTestErase(Address: QWord; out ErrorText: string): boolean;
var
  WEL: boolean;
begin
  Result := False;
  ErrorText := '';
  //เซกเตอร์เรียงตามขอบของตัวเอง ไม่มีทางคร่อมขอบหน้า 16MB
  if CapUseEAR then
    if not CapSetBank(EARBankOf(Address), ErrorText) then Exit;
  if not UsbAsp25_WrenChecked(WEL) then
  begin
    ErrorText := 'the chip did not accept write enable';
    Exit;
  end;
  if CapUseEAR then
  begin
    if UsbAsp25_EraseSector(CapEraseOpcode, longword(Address and $FFFFFF),
                            False) < 0 then
    begin
      ErrorText := 'the erase command was not transferred exactly';
      Exit;
    end;
  end
  else if UsbAsp25_EraseSector(CapEraseOpcode, longword(Address),
                               CapUse4B) < 0 then
  begin
    ErrorText := 'the erase command was not transferred exactly';
    Exit;
  end;
  if not WaitNotBusy25(BUSY_TIMEOUT_SECTOR) then
  begin
    ErrorText := 'the chip stayed busy after the erase';
    Exit;
  end;
  Result := True;
end;

function CapTestProgram(Address: QWord; const Data: TBytes;
  out ErrorText: string): boolean;
var
  WEL: boolean;
begin
  Result := False;
  ErrorText := '';
  if (Length(Data) = 0) or (Length(Data) > 256) then
  begin
    ErrorText := 'a program chunk must be 1..256 bytes';
    Exit;
  end;
  //ก้อนเขียนยาวไม่เกินหนึ่งเพจและเรียงตามเพจ ไม่มีทางคร่อมขอบหน้า 16MB
  if CapUseEAR then
    if not CapSetBank(EARBankOf(Address), ErrorText) then Exit;
  if not UsbAsp25_WrenChecked(WEL) then
  begin
    ErrorText := 'the chip did not accept write enable';
    Exit;
  end;
  if CapUseEAR then
  begin
    if UsbAsp25_Write($02, longword(Address and $FFFFFF), Data,
                      Length(Data)) <> Length(Data) then
    begin
      ErrorText := 'the program command was not transferred exactly';
      Exit;
    end;
  end
  else if CapUse4B then
  begin
    if UsbAsp25_Write32bitAddr($02, longword(Address), Data,
                               Length(Data)) <> Length(Data) then
    begin
      ErrorText := 'the program command was not transferred exactly';
      Exit;
    end;
  end
  else if UsbAsp25_Write($02, longword(Address), Data, Length(Data)) <>
          Length(Data) then
  begin
    ErrorText := 'the program command was not transferred exactly';
    Exit;
  end;
  if not WaitNotBusy25(BUSY_TIMEOUT_PAGE) then
  begin
    ErrorText := 'the chip stayed busy after the page program';
    Exit;
  end;
  Result := True;
end;

procedure LockControl; forward;
procedure UnlockControl; forward;
function VoltageWarningOK: boolean; forward;

procedure RunChipCapacityTest;
var
  R: TCapacityResult;
  ClaimedSize: QWord;
  SectorSz: cardinal;
begin
  OpBegin(opkWrite);

  if not (MainForm.RadioSPI.Checked and
          (MainForm.ComboSPICMD.ItemIndex = SPI_CMD_25)) then
  begin
    OpFail('the capacity test works on 25-series SPI NOR only');
    Exit;
  end;
  if CurrentICParam.Size = 0 then
  begin
    OpFail('select a chip (or detect via SFDP) so the claimed size is known');
    Exit;
  end;
  ClaimedSize := CurrentICParam.Size;
  SectorSz := CurrentICParam.Sector;
  if SectorSz = 0 then SectorSz := 4096;
  CapEraseOpcode := CurrentICParam.SectorOpcode;
  if CapEraseOpcode = 0 then
    case SectorSz of
      4096:  CapEraseOpcode := $20;
      32768: CapEraseOpcode := $52;
      65536: CapEraseOpcode := $D8;
    else
      CapEraseOpcode := $20;
    end;

  if not OpenDevice then
  begin
    OpFail('the programmer could not be opened');
    Exit;
  end;
  //งานนี้ลบและเขียนจริงหลายนาที ปุ่มกับเมนูทั้งหน้าต่างต้องถูกล็อกเหมือน
  //งานเขียนปกติ ไม่งั้นคลิกระหว่างสแกนจะยิงงานซ้อนใส่อุปกรณ์ตัวเดียวกัน
  LockControl;
  try
    if not EnterProgModeSPI25 then
    begin
      OpFail('the programmer could not initialize the SPI bus');
      Exit;
    end;
    if not ContactIsStable then Exit;
    //ชิปที่ล็อกอยู่รับคำสั่งลบแล้วเมินเงียบ ๆ ผลจะออกมาเป็น "เก็บข้อมูล
    //ไม่อยู่" ทั้งที่ความจริงคือยังไม่ได้ปลดล็อก กันไว้ก่อนตรงนี้
    if not ProtectionGuardOK(0, cardinal(ClaimedSize)) then Exit;
    if not ChipTestBegin4B(ClaimedSize) then Exit;

    LogPrint(Format('True capacity test: claimed %d KB, %d KB sectors ' +
                    '(opcode %.2xh%s)',
                    [ClaimedSize div 1024, SectorSz div 1024,
                     CapEraseOpcode,
                     BoolToStr(CapUse4B, ', 4-byte addressing', '')]));
    if RunCapacityTest(ClaimedSize, SectorSz, @CapTestRead, @CapTestErase,
                       @CapTestProgram, @ChipTestLogSink, R) then
    begin
      if R.Genuine then
        LogPrint(Format('PASS: the chip really holds %d KB; the original ' +
                        'content was restored and verified',
                        [R.DetectedSize div 1024]))
      else
        OpFail(Format('FAKE: the chip claims %d KB but its addresses wrap ' +
                      'at %d KB -- that is the real capacity. The original ' +
                      'content of the real die was restored and verified',
                      [ClaimedSize div 1024, R.DetectedSize div 1024]));
    end
    else
    begin
      OpFail(R.ErrorText);
      if not R.RestoredOK then
        LogPrint('WARNING: not every touched sector could be restored; ' +
                 'the sectors named above may hold FF or marker data');
    end;
  finally
    ChipTestEnd4B;
    ExitProgMode25;
    AsProgrammer.Programmer.DevClose;
    LogPrint(STR_OP_RESULT + OpSummary);
    UnlockControl;
  end;
end;

procedure SurfaceProgressSink(BlocksDone, BlocksTotal: cardinal);
begin
  SetProgressMax(integer(BlocksTotal));
  SetProgressPos(integer(BlocksDone));
  OpProcessMessages;
end;

procedure RunChipSurfaceScan;
var
  R: TSurfaceScanResult;
  ChipSize: QWord;
  SectorSz: cardinal;
begin
  OpBegin(opkErase);

  if not (MainForm.RadioSPI.Checked and
          (MainForm.ComboSPICMD.ItemIndex = SPI_CMD_25)) then
  begin
    OpFail('the surface scan works on 25-series SPI NOR only');
    Exit;
  end;
  if CurrentICParam.Size = 0 then
  begin
    OpFail('select a chip (or detect via SFDP) so the size is known');
    Exit;
  end;
  ChipSize := CurrentICParam.Size;
  SectorSz := CurrentICParam.Sector;
  if SectorSz = 0 then SectorSz := 4096;
  CapEraseOpcode := CurrentICParam.SectorOpcode;
  if CapEraseOpcode = 0 then
    case SectorSz of
      4096:  CapEraseOpcode := $20;
      32768: CapEraseOpcode := $52;
      65536: CapEraseOpcode := $D8;
    else
      CapEraseOpcode := $20;
    end;

  if not OpenDevice then
  begin
    OpFail('the programmer could not be opened');
    Exit;
  end;
  //ลบทั้งชิปจริง ต้องล็อกหน้าจอเต็มรูปแบบเหมือนงานลบปกติ
  LockControl;
  try
    if not EnterProgModeSPI25 then
    begin
      OpFail('the programmer could not initialize the SPI bus');
      Exit;
    end;
    if not ContactIsStable then Exit;
    if not ProtectionGuardOK(0, cardinal(ChipSize)) then Exit;
    if not ChipTestBegin4B(ChipSize) then Exit;

    if RunSurfaceScan(ChipSize, SectorSz, @CapTestRead, @CapTestErase,
                      @CapTestProgram, @ChipTestLogSink,
                      @SurfaceProgressSink, @UserCancel, R) then
    begin
      if (R.SlowBlocks > 0) and (R.SlowMedianMs >= 10) then
        LogPrint(Format(STR_ERASE_WEAR_WARNING,
          [R.SlowBlocks, R.SlowWorstMs, cardinal(R.SlowWorstAddr),
           R.SlowMedianMs]));
      if R.BlocksBad = 0 then
        LogPrint(Format('PASS: all %d blocks held FF, 55, AA and their ' +
                        'own address', [R.BlocksTested]))
      else
        OpFail(Format('%d of %d blocks failed the pattern walk; the ' +
                      'first bad block is at 0x%.8x. This chip should ' +
                      'not carry data anyone cares about',
                      [R.BlocksBad, R.BlocksTested,
                       cardinal(R.FirstBadAddr)]));
      LogPrint('the chip is now fully erased');
    end
    else
      OpFail(R.ErrorText);
  finally
    ChipTestEnd4B;
    ExitProgMode25;
    AsProgrammer.Programmer.DevClose;
    SetProgressPos(0);
    LogPrint(STR_OP_RESULT + OpSummary);
    UnlockControl;
  end;
end;

//Implemented with the other backup helpers below.  EZP whole-chip operations
//live earlier in this unit and use the same atomic publication contract.
function PersistTrustedBackup(Backup: TMemoryStream;
  ExpectedSize: cardinal): boolean; forward;
procedure WriteBackupManifest(const BinFileName: string; Size: cardinal); forward;

//เขียนหรือลบทั้งชิปผ่าน EZP2023+ แล้วอ่านกลับมาเทียบทุกไบต์
//
//เฟิร์มแวร์ของเครื่องนี้ไม่รับคำสั่ง SPI ดิบ ๆ จึงเขียนทีละเพจแบบเส้นทาง
//ปกติไม่ได้ แต่มีคำสั่ง native แยกสำหรับเขียนทั้งชิปกับลบทั้งชิป และเพราะ
//มันอ่านได้ด้วย เราจึงตรวจผลได้เต็มร้อยแทนการเชื่อสถานะของเฟิร์มแวร์
procedure RunEZPWholeChipWrite(Blank: boolean);
var
  Dev: TEZPHardware;
  Image, BlankImage, Back, BackConfirm: TBytes;
  Size: cardinal;
  Stream: TMemoryStream;
  ControlsLocked: boolean;

  function VerifyPhysicalImage(const Expected: TBytes;
    EraseContext: boolean): boolean;
  var
    i: SizeInt;
  begin
    Result := False;
    LogPrint('reading the chip back to check every byte');
    if not Dev.ReadBackWholeChip(Back) then
    begin
      if EraseContext then
        OpFail('the erase finished but the read-back failed: ' +
               Dev.GetLastError)
      else
        OpFail('the write finished but the read-back failed: ' +
               Dev.GetLastError);
      Exit;
    end;
    if cardinal(Length(Back)) <> Size then
    begin
      OpFail(Format('the read-back returned %d bytes, expected %d',
                    [Length(Back), Size]));
      Exit;
    end;

    //A marginal clip can return one apparently valid all-FF page without any
    //USB error.  One real EF4017 run differed in only 171 bytes of one
    //256-byte page, then read correctly in a fresh process.  Never call a
    //destructive operation verified until two session-separated reads agree
    //across the entire array.  Sessions, not usb_reset: the vendor software
    //never uses USB resets, and session-separated reads were measured to
    //return fresh correct data seven sessions in a row in one process.
    LogPrint('reading a second independent pass to prove connection stability');
    if not Dev.ReadBackWholeChip(BackConfirm) then
    begin
      OpFail('the first read-back completed but the independent confirmation ' +
             'read failed: ' + Dev.GetLastError);
      Exit;
    end;
    if cardinal(Length(BackConfirm)) <> Size then
    begin
      OpFail(Format('the confirmation read-back returned %d bytes, expected %d',
                    [Length(BackConfirm), Size]));
      Exit;
    end;
    for i := 0 to SizeInt(Size) - 1 do
      if BackConfirm[i] <> Back[i] then
      begin
        LogPrint(Format('EZP2023+ independent read-backs disagree at %.8x ' +
          '(first %.2x, second %.2x)',
          [cardinal(i), Back[i], BackConfirm[i]]));
        OpFail(Format('the two reset-separated verification reads disagree ' +
          'at 0x%.8x (%.2x versus %.2x). The clip/socket connection is ' +
          'intermittent; reseat or isolate the chip before trusting any ' +
          'erase or write result',
          [cardinal(i), Back[i], BackConfirm[i]]), i);
        Exit;
      end;

    for i := 0 to SizeInt(Size) - 1 do
      if Back[i] <> Expected[i] then
      begin
        LogPrint(Format('%s%s (chip %.2x, expected %.2x)',
          [STR_VERIFY_ERROR, IntToHex(cardinal(i), 8),
           Back[i], Expected[i]]));
        if EraseContext then
          OpFail(Format('the firmware reported erase complete, but the ' +
            'flash still holds %.2x at 0x%.8x, so no image data was sent. ' +
            'The chip is rejecting erase: fully power down the target, ' +
            'isolate the chip from the board, check the clip/socket ' +
            'contacts, and ensure WP# (pin 3) is high and status-register ' +
            'protection is not locked',
            [Back[i], cardinal(i)]), i)
        else
          OpFail(Format('the programmer accepted the complete image, but ' +
            'the flash still holds %.2x instead of %.2x at 0x%.8x. Reads ' +
            'can work while programming is blocked: fully power down the ' +
            'target, isolate the chip from the board, check the clip/socket ' +
            'contacts, and ensure WP# (pin 3) is high and status-register ' +
            'protection is not locked',
            [Back[i], Expected[i], cardinal(i)]), i);
        Exit;
      end;
    Result := True;
  end;

  function BackupPhysicalImage: boolean;
  var
    i: SizeInt;
    BackupStream: TMemoryStream;
  begin
    Result := True;
    LastBackupFileName := '';
    LogPrint(STR_BACKUP_MAKING);
    if not Dev.ReadBackWholeChip(Back) then
    begin
      OpFail('the EZP2023+ could not read the pre-operation backup: ' +
             Dev.GetLastError);
      Exit(False);
    end;
    if cardinal(Length(Back)) <> Size then
    begin
      OpFail(Format('the EZP2023+ backup returned %d bytes, expected %d',
                    [Length(Back), Size]));
      Exit(False);
    end;

    if not Dev.ReadBackWholeChip(BackConfirm) then
    begin
      OpFail('the EZP2023+ could not confirm the pre-operation backup: ' +
             Dev.GetLastError);
      Exit(False);
    end;
    if cardinal(Length(BackConfirm)) <> Size then
    begin
      OpFail(Format('the EZP2023+ backup confirmation returned %d bytes, ' +
                    'expected %d', [Length(BackConfirm), Size]));
      Exit(False);
    end;
    for i := 0 to SizeInt(Size) - 1 do
      if Back[i] <> BackConfirm[i] then
      begin
        OpFail(Format('the two EZP2023+ backup reads disagree at 0x%.8x',
                      [cardinal(i)]), i);
        Exit(False);
      end;

    BackupStream := TMemoryStream.Create;
    try
      if Size > 0 then BackupStream.WriteBuffer(Back[0], Size);
      BackupStream.Position := 0;
      Result := PersistTrustedBackup(BackupStream, Size);
    finally
      BackupStream.Free;
    end;
  end;
begin
  if OperationRunning then Exit;
  if Blank then OpBegin(opkErase) else OpBegin(opkWrite);
  ForgetChipContent;
  ControlsLocked := False;
try
  if AsProgrammer.Current_HW <> CHW_EZP then
  begin
    OpFail('this path is only for the EZP2023+');
    Exit;
  end;
  if not (MainForm.RadioSPI.Checked and
          (MainForm.ComboSPICMD.ItemIndex = SPI_CMD_25)) then
  begin
    OpFail('the EZP2023+ backend drives 25-series SPI NOR only');
    Exit;
  end;

  //เส้นทางลบ/เขียนปกติผ่านด่านแรงดันก่อนแตะชิปทุกครั้ง เส้นทาง EZP ก็ต้อง
  //ผ่านเหมือนกัน: เครื่องนี้จ่ายราง 3.3 V เสมอ ชิป 1.8 V โดน 3.3 V คือพัง
  if not VoltageWarningOK then
  begin
    OpFail('aborted because of the supply voltage');
    Exit;
  end;

  Size := CurrentICParam.Size;
  if Size = 0 then
  begin
    OpFail('pick the chip first (Read ID, or choose it from the list)');
    Exit;
  end;

  //ภาพที่จะเขียนต้องเท่าขนาดชิปพอดี เพราะเครื่องเขียนทั้งตัวเสมอ
  //บัฟเฟอร์ที่สั้นกว่าจะถูกเติม FF ท้าย ซึ่งก็คือ "ลบส่วนที่เหลือ"
  //และต้องบอกผู้ใช้ตรง ๆ ไม่ใช่ทำเงียบ ๆ
  SetLength(Image, Size);
  if Blank then
    FillByte(Image[0], Size, $FF)
  else
  begin
    FillByte(Image[0], Size, $FF);
    Stream := TMemoryStream.Create;
    try
      MainForm.MPHexEditorEx.SaveToStream(Stream);
      Stream.Position := 0;
      if Stream.Size > int64(Size) then
      begin
        OpFail(Format('the buffer holds %d bytes but the chip is %d',
                      [Stream.Size, Size]));
        Exit;
      end;
      if Stream.Size < int64(Size) then
        LogPrint(Format('the buffer is %d bytes and the chip is %d: the ' +
          'EZP2023+ writes whole chips, so everything past the buffer will ' +
          'be erased to FF', [Stream.Size, Size]));
      Stream.ReadBuffer(Image[0], Stream.Size);
    finally
      Stream.Free;
    end;
  end;

  if not OpenDevice then
  begin
    OpFail('the programmer could not be opened');
    Exit;
  end;
    LockControl;
    ControlsLocked := True;
    Dev := TEZPHardware(AsProgrammer.Programmer);
    if not BackupPhysicalImage then
    begin
      LogPrint(STR_BACKUP_FAILED);
      Exit;
    end;
    if Blank then
      LogPrint(Format('EZP2023+: erasing all %d bytes with the firmware''s ' +
                      'native erase command', [Size]))
    else
      LogPrint(Format('EZP2023+: erasing and blank-checking all %d bytes ' +
                      'before writing, as required for 25-series SPI flash',
                      [Size]));
    SetProgressMax(integer(Size));

    //The vendor manual is explicit: its Write command does not erase a
    //25-series SPI flash.  "Auto" is three separate operations: Erase, Write,
    //Verify.  A real EF4017 probe confirmed that 0005 can program FF -> FE but
    //cannot restore FE -> FF.  Therefore every write must native-erase and
    //prove the entire chip blank before sending even the first image page.
    if not Dev.EraseWholeChip then
    begin
      OpFail(Dev.GetLastError);
      Exit;
    end;

    if Blank then
      BlankImage := Image
    else
    begin
      SetLength(BlankImage, Size);
      FillByte(BlankImage[0], Size, $FF);
    end;
    if not VerifyPhysicalImage(BlankImage, True) then Exit;
    LogPrint('the chip is erased and verified blank');

    if not Blank then
    begin
      LogPrint(Format('EZP2023+: writing all %d bytes to the verified blank ' +
                      'flash', [Size]));
      if not Dev.WriteWholeChip(Image) then
      begin
        OpFail(Dev.GetLastError);
        Exit;
      end;
      if not VerifyPhysicalImage(Image, False) then Exit;
      LogPrint('the whole chip was written and verified byte for byte');
    end;
    OpProgress(Size, Size);
  finally
    AsProgrammer.Programmer.DevClose;
    SetProgressPos(0);
    LogPrint(STR_OP_RESULT + OpSummary);
    if ControlsLocked then UnlockControl;
  end;
end;

procedure RunChipDoctor;
var
  ID: MEMORY_ID;
  Detail: string;
  WEL, ok, SavedContact: boolean;
  sreg: byte;
  Passed, Total: integer;
  Info: TSFDPInfo;
  Ladder: array[0..9] of TMenuItem;
  LCount: integer;
  BufA, BufB: TBytes;
  N: cardinal;
  Err: string;
  i: integer;

  procedure Verdict(const Name: string; Passed_: boolean;
    const FailDetail: string);
  begin
    Inc(Total);
    if Passed_ then
    begin
      Inc(Passed);
      LogPrint('  [PASS] ' + Name);
    end
    else
    begin
      LogPrint('  [FAIL] ' + Name + ': ' + FailDetail);
      OpFail(Name + ': ' + FailDetail);
    end;
  end;

begin
  OpBegin(opkDetect);
  Passed := 0;
  Total := 0;

  if not (MainForm.RadioSPI.Checked and
          (MainForm.ComboSPICMD.ItemIndex = SPI_CMD_25)) then
  begin
    OpFail('the chip health check works on 25-series SPI NOR only');
    Exit;
  end;
  if not OpenDevice then
  begin
    OpFail('the programmer could not be opened');
    Exit;
  end;
  //งานอ่านหลายนาทีบนอุปกรณ์ตัวเดียว ต้องล็อกหน้าจอกันคลิกซ้อนเหมือนงานอื่น
  LockControl;
  try
    if not EnterProgModeSPI25 then
    begin
      OpFail('the programmer could not initialize the SPI bus');
      Exit;
    end;

    LogPrint('Chip health check (nothing is written)');
    //หมออ่านแค่ช่วงต้นชิป (ไม่เกิน 256KB) เฟรม 3 ไบต์พอเสมอ
    CapUse4B := False;
    CapUseEAR := False;

    //1 ความนิ่งของรหัส: อ่านแปดครั้งต้องได้ค่าเดิม บังคับเปิดการตรวจ
    //ชั่วคราวแม้ผู้ใช้ปิดเมนูไว้ เพราะทั้งงานนี้คือการตรวจนั่นเอง
    SavedContact := MainForm.MenuCheckContact.Checked;
    MainForm.MenuCheckContact.Checked := True;
    ok := ContactIsStable;
    MainForm.MenuCheckContact.Checked := SavedContact;
    Verdict('id stable over eight reads', ok,
            'the id changed between reads; reseat the clip');
    if not ok then Exit; //บัสที่สั่นอ่านต่อไปก็ได้แต่คำตอบที่เชื่อไม่ได้

    //2 รหัสจากโอปโค้ดต่างยุคต้องเล่าเรื่องเดียวกัน
    FillChar(ID, SizeOf(ID), 0);
    UsbAsp25_ReadID(ID);
    ok := CrossCheckIDs(ID.ID9FH, ID.Got9F, ID.ID90H, ID.Got90,
                        ID.IDABH, ID.GotAB, ID.ID15H, ID.Got15, Detail);
    Verdict('id opcodes agree (9F/90/AB/15)', ok, Detail);

    //3 WEL ต้องติดตาม WREN และดับตาม WRDI: พิสูจน์ว่าชิปทำตามคำสั่ง
    //ไม่ใช่แค่ตอบรหัสได้ ไม่มีการเขียนใด ๆ เกิดขึ้น
    ok := UsbAsp25_WrenChecked(WEL) and WEL;
    if ok then
    begin
      UsbAsp25_Wrdi();
      ok := (UsbAsp25_ReadSR(sreg) = 1) and ((sreg and $02) = 0);
    end;
    Verdict('write-enable latch sets and clears on command', ok,
            'WEL did not follow WREN/WRDI; WP# may be held low, or the ' +
            'chip does not execute commands');

    //4 SFDP: มี/ไม่มีไม่ใช่ผิด แต่ถ้ามีแล้วขนาดไม่ตรงกับชิปที่เลือก
    //แปลว่าเลือกผิดเบอร์หรือชิปโกหก
    if SFDPDetect(Info) and Info.Valid then
    begin
      if (CurrentICParam.Size > 0) and (Info.Density > 0) and
         (QWord(Info.Density) <> QWord(CurrentICParam.Size)) then
        Verdict('SFDP size matches the selected chip', False,
                Format('the chip''s own SFDP declares %d KB but the ' +
                       'selected chip says %d KB',
                       [Info.Density div 1024, CurrentICParam.Size div 1024]))
      else
        Verdict('SFDP present and consistent', True, '');
    end
    else
      LogPrint('  [    ] no SFDP table (normal for older parts); size ' +
               'cross-check skipped');

    //5 อ่านช่วงต้นชิปที่คล็อกเร็วสุดและช้าสุดแล้วเทียบ ต่างกันเมื่อไร
    //คือหน้าสัมผัสหรือสายที่ชายขอบ ไม่ใช่ข้อมูล
    for i := 0 to High(Ladder) do Ladder[i] := nil;
    LCount := SPISpeedMenuLadder(Ladder);
    if LCount >= 2 then
    begin
      N := 262144;
      if (CurrentICParam.Size > 0) and (CurrentICParam.Size < N) then
        N := CurrentICParam.Size;
      ok := EnterProgMode25(Ladder[0].Tag, MainForm.MenuSendAB.Checked) and
            CapTestRead(0, N, BufA, Err) and
            EnterProgMode25(Ladder[LCount - 1].Tag,
                            MainForm.MenuSendAB.Checked) and
            CapTestRead(0, N, BufB, Err);
      EnterProgModeSPI25; //กลับไปที่ความเร็วที่ผู้ใช้เลือกเสมอ
      if ok then
      begin
        ok := True;
        for i := 0 to integer(N) - 1 do
          if BufA[i] <> BufB[i] then
          begin
            ok := False;
            Break;
          end;
        Verdict(Format('same %d KB at %s and %s', [N div 1024,
                Trim(StringReplace(Ladder[0].Caption, '&', '', [rfReplaceAll])),
                Trim(StringReplace(Ladder[LCount - 1].Caption, '&', '',
                     [rfReplaceAll]))]), ok,
                'the fast and slow reads disagree; the contact or wiring ' +
                'is marginal at speed');
      end
      else
        Verdict('dual-clock read', False, Err);
    end
    else
      LogPrint('  [    ] this programmer has one fixed clock; dual-clock ' +
               'read skipped');

    LogPrint(Format('%d of %d checks passed', [Passed, Total]));
    if Passed = Total then
      LogPrint('the chip looks healthy. For the capacity/counterfeit ' +
               'test, run Chip -> True capacity test');
  finally
    ExitProgMode25;
    AsProgrammer.Programmer.DevClose;
    LogPrint(STR_OP_RESULT + OpSummary);
    UnlockControl;
  end;
end;

//ดัมป์ตาราง SFDP ดิบ ๆ ลงไฟล์
//
//อ่านมาเท่าที่หัวตารางบอกว่ามี ไม่ใช่จำนวนคงที่ที่เดาเอา ชิปที่มีตารางเสริม
//หลายตารางจะยาวกว่าที่คนส่วนใหญ่คิด และการดัมป์มาไม่ครบทำให้ดัมป์นั้นใช้ไม่ได้
function DumpSFDPToFile(const FileName: string; out ErrMsg: string): boolean;
var
  Extent: cardinal;
  Buf: array of byte;
  Got: integer;
  F: TFileStream;
begin
  Result := False;
  ErrMsg := '';

  Extent := SFDPExtent(@UsbAsp25_ReadSFDP);
  if Extent = 0 then
  begin
    ErrMsg := 'this chip has no SFDP table';
    Exit;
  end;

  //ปัดขึ้นให้ลงตัวสี่ไบต์ ตารางนับเป็นดเวิร์ดเสมอ
  Extent := ((Extent + 3) div 4) * 4;
  SetLength(Buf, Extent);

  //ส่งทั้งอาร์เรย์ ไม่ใช่ Buf[0] เพราะพารามิเตอร์เป็น open array
  //การส่งสมาชิกตัวเดียวเข้าไปคือการบอกว่าอาร์เรย์ยาวหนึ่งไบต์ แล้วตัวรับ
  //จะเขียนทะลุออกไปนอกขอบโดยไม่มีอะไรฟ้อง
  Got := UsbAsp25_ReadSFDP(0, Buf, integer(Extent));
  if Got < integer(Extent) then
  begin
    ErrMsg := Format('read only %d of %d bytes of the SFDP table',
                     [Got, Extent]);
    Exit;
  end;

  try
    F := TFileStream.Create(FileName, fmCreate);
    try
      F.WriteBuffer(Buf[0], Extent);
    finally
      F.Free;
    end;
  except
    on E: Exception do
    begin
      ErrMsg := E.Message;
      Exit;
    end;
  end;

  LogPrint(Format('SFDP table dumped: %d bytes to %s', [Extent, FileName]));
  Result := True;
end;

//ตัวช่วยของงานเทียบข้อมูล ตัวจริงอยู่ท้ายไฟล์ แต่มีผู้เรียกอยู่ก่อนหน้านั้น
function FastSPIClockWarning: string; forward;
function ReportDiff(const A, B: array of byte; Size: integer): integer; forward;
function UIChipSize: cardinal; forward;
procedure MarkDiffInEditor(const A, B: array of byte; Size: integer); forward;
function ReadCurrentChip(Stream: TMemoryStream; Size: cardinal): boolean; forward;

//ตรวจว่าชิปที่เสียบอยู่ตรงกับที่เลือกไว้จริงหรือไม่
//ต้องเรียกตอนอยู่ในโหมดโปรแกรม คืน False เมื่อผู้ใช้เลือกไม่ทำต่อ
function VerifyChipID: boolean;
var
  ID: MEMORY_ID;
  Expected, s9F, s90, sAB, s15: string;
begin
  Result := True;

  if (not StrictProductionMode) and
     (not MainForm.MenuCheckIDBefore.Checked) then Exit;
  if not MainForm.RadioSPI.Checked then Exit;
  if MainForm.ComboSPICMD.ItemIndex <> SPI_CMD_25 then Exit;

  if StrictProductionMode then
    Expected := UpperCase(Trim(StrictProductionExpectedID))
  else
    Expected := UpperCase(Trim(CurrentICParam.ID));
  //ชิปบางตัวไม่มี id จึงไม่มีอะไรให้ตรวจ
  if (Expected = '') or (Expected = '0') then Exit;

  FillByte(ID.ID9FH, 3, $FF);
  FillByte(ID.ID90H, 2, $FF);
  FillByte(ID.IDABH, 1, $FF);
  FillByte(ID.ID15H, 2, $FF);

  UsbAsp25_ReadID(ID);

  //คำสั่งที่ไม่ได้คำตอบต้องแสดงว่าไม่ได้คำตอบ ไม่ใช่แสดงค่าที่ค้างในบัฟเฟอร์
  //เดิมสายที่เงียบสนิทจะพิมพ์ออกมาว่า ABh=AB และ 90h=9000 ซึ่งคือ opcode
  //ของเราเองสะท้อนกลับ ดูเหมือนชิปตอบอยู่ แล้วคนก็ไปตามหาปัญหาผิดเรื่อง
  if ID.Got9F then
    s9F := UpperCase(IntToHex(ID.ID9FH[0], 2) + IntToHex(ID.ID9FH[1], 2) + IntToHex(ID.ID9FH[2], 2))
  else
    s9F := '--';
  if ID.Got90 then
    s90 := UpperCase(IntToHex(ID.ID90H[0], 2) + IntToHex(ID.ID90H[1], 2))
  else
    s90 := '--';
  if ID.GotAB then
    sAB := UpperCase(IntToHex(ID.IDABH, 2))
  else
    sAB := '--';
  if ID.Got15 then
    s15 := UpperCase(IntToHex(ID.ID15H[0], 2) + IntToHex(ID.ID15H[1], 2))
  else
    s15 := '--';

  //A signed production job binds the standard 9Fh identity.  Legacy fallback
  //IDs and interactive overrides are deliberately unavailable at this trust
  //boundary.
  if StrictProductionMode then
  begin
    if ID.Got9F and (Expected = s9F) then
    begin
      LogPrint(STR_ID_OK + Expected);
      //ชิปในซ็อกเก็ตตอบมาและตรงกับที่เลือกไว้จริง ๆ
      ChipIdentityConfirmed := True;
      Exit(True);
    end;
    if not ID.Got9F then
      OpFail('strict production identity check received no exact JEDEC 9Fh reply')
    else
      OpFail('strict production JEDEC identity mismatch: expected ' +
             Expected + ', received ' + s9F);
    Exit(False);
  end;

  //เทียบเฉพาะคำสั่งที่ได้คำตอบจริง
  if (ID.Got9F and (Expected = s9F)) or (ID.Got90 and (Expected = s90)) or
     (ID.GotAB and (Expected = sAB)) or (ID.Got15 and (Expected = s15)) then
  begin
    LogPrint(STR_ID_OK + Expected);
    //ชิปในซ็อกเก็ตตอบมาและตรงกับที่เลือกไว้จริง ๆ
    ChipIdentityConfirmed := True;
    Exit;
  end;

  //ไม่มีคำสั่งไหนได้คำตอบเลย เป็นคนละเรื่องกับชิปผิดรุ่น และคำแนะนำก็คนละอย่าง
  //บอกให้ตรงเรื่อง ไม่งั้นคนจะไปไล่เปลี่ยนรุ่นชิปในเมนูทั้งที่ปัญหาอยู่ที่สาย
  if not (ID.Got9F or ID.Got90 or ID.GotAB or ID.Got15) then
  begin
    LogPrint(STR_ID_NO_ANSWER);
    if FastSPIClockWarning <> '' then
      LogPrint(Format(STR_NO_CHIP_CLOCK, [FastSPIClockWarning]));
    if CLIMode then Exit(False);

    //ไม่ต้องเด้งกล่องถามว่าจะไปต่อไหม
    //
    //"ไม่มีชิปตอบเลย" กับ "ชิปผิดรุ่น" อันตรายไม่เท่ากัน กรณีชิปผิดรุ่นต้อง
    //ถามจริง เพราะสั่งลบหรือเขียนใส่ชิปที่ไม่ใช่ตัวที่เลือกไว้ทำข้อมูลหาย
    //แต่กรณีไม่มีใครตอบ ไม่มีอะไรให้เสียหาย งานจะได้ FF หรือล้มไปเองอยู่แล้ว
    //ซึ่งเห็นชัดกว่ากล่องข้อความ
    //
    //ที่สำคัญคือมันเด้งตอนซ็อกเก็ตยังว่าง ซึ่งเป็นสถานะปกติก่อนเสียบชิป
    //คนใช้จึงต้องกดปิดกล่องนี้ทิ้งทุกครั้งโดยไม่ได้ข้อมูลอะไรเพิ่มเลย
    //เหตุผลทั้งหมดอยู่ในล็อกอยู่แล้ว รวมทั้งคำแนะนำเรื่องคล็อกที่เร็วเกินไป
    Result := True;
    Exit;
  end;

  LogPrint(STR_ID_MISMATCH + Expected + ', read 9Fh=' + s9F + ' 90h=' + s90 +
           ' ABh=' + sAB + ' 15h=' + s15);

  if CLIMode then Exit(False);
  Result := MessageDlg('AsProgrammer', STR_ID_MISMATCH_Q, mtWarning, [mbYes, mbNo], 0) = mrYes;
end;

//เตือนก่อนแตะชิป 1.8 โวลต์ ถ้าเครื่องโปรแกรมจ่ายไฟให้ไม่ได้
//CH341A จ่าย 3.3-5V, CH347 กับ FT232H จ่าย 3.3V ทั้งหมดสูงเกินไปสำหรับชิป 1.8V
//ต่อผิดครั้งเดียวชิปพังถาวร จึงต้องถามก่อนทุกครั้ง
function VoltageWarningOK: boolean;
var
  VMinMv, VMaxMv, VWantMv: cardinal;
begin
  Result := True;
  //Strict production has already passed the typed measured electrical gate.
  //Do not replace that result with a model-name heuristic or a dialog.
  if StrictProductionMode then Exit;

  //เดิมดูจากชื่อรุ่นอย่างเดียว ตามธรรมเนียมที่ใส่ _1.8V ต่อท้าย
  //ซึ่งพลาดชิป 1.8V ที่ชื่อไม่ได้บอก และนั่นคือกลุ่มใหญ่
  //  W25Q64FW  W25Q256FW  (id EF60xx)   MX25U6435F   GD25LQ32
  //ทั้งหมดนี้พังทันทีถ้าได้รับ 3.3V ซึ่งเป็นสิ่งที่เกิดขึ้นบ่อยที่สุด
  //ตอนนี้จึงเชื่อค่า vcc ใน chiplist ก่อน แล้วค่อยถอยไปดูชื่อ
  //ตัวหาสามชั้นรวมทั้งช่อง vcc ชื่อรุ่น และรหัส JEDEC ไว้แล้ว ชั้นที่สาม
  //คือชั้นที่จับกลุ่มใหญ่ที่ว่านี้ได้ (EF60xx, C225xx, C860xx ฯลฯ) ซึ่ง
  //ทั้งช่อง vcc และชื่อรุ่นไม่ได้บอกอะไรเลย
  if Pos('1.8', ChipVccText(CurrentICParam.Vcc, CurrentICParam.Name,
                            CurrentICParam.ID)) = 0 then Exit;

  //Bus Pirate ตั้งขาเป็น open-drain แล้วจ่ายไฟจากภายนอกได้ จึงไม่เตือน
  if AsProgrammer.Current_HW in [CHW_BUZZPIRAT, CHW_ARDUINO] then Exit;

  //CH347 ที่พิสูจน์แล้วว่าสลับแรงดันได้: ตัดสินจากระดับที่จะจ่ายจริง
  //ไม่ใช่จากชื่อรุ่นเครื่อง คำเตือนเรื่องไฟเลี้ยงภายนอกไม่เกี่ยวกับบอร์ดนี้
  if (AsProgrammer.Current_HW = CHW_CH347) and CH347VoltageControlSeen then
  begin
    //ปักหมุด 1.8V ไว้ หรือ Auto ที่อ่านช่วงจากแค็ตตาล็อกได้ (ชิปตรงหน้า
    //ผ่านด่านบนมาแปลว่าเป็นชิป 1.8V ช่วงที่อ่านได้จึงลงเอยที่ 1.8V เสมอ):
    //ระดับที่จะจ่ายคือ 1.8V จริง ไม่มีอะไรต้องเตือน
    if SelectedCH347Vcc = CH347_VCC_1V8_MV then Exit;
    if (SelectedCH347Vcc = 0) and
       VccRangeMv(CurrentChipVccText, VMinMv, VMaxMv) and
       CH347VccForChip(VMinMv, VMaxMv, VWantMv) and
       (VWantMv = CH347_VCC_1V8_MV) then Exit;

    //ปัก 3.3V ค้างไว้ หรือ Auto ที่ตัดสินไม่ได้เพราะแค็ตตาล็อกไม่บอกช่วง:
    //เสนอปัก 1.8V ให้ชัดก่อนเดินต่อ ทั้งสองปุ่มปลอดภัย ไม่มีปุ่มไหนแปลว่า
    //"จ่าย 3.3V ใส่ชิป 1.8V ต่อไป"
    if CLIMode then
    begin
      LogPrint(STR_VOLT_ABORTED);
      Exit(False);
    end;
    Result := MessageDlg('AsProgrammer', STR_CH347_VOLT_FIX_Q,
                         mtWarning, [mbYes, mbNo], 0) = mrYes;
    if Result then
      PinCH347VccMenu(CH347_VCC_1V8_MV)
    else
      LogPrint(STR_VOLT_ABORTED);
    Exit;
  end;

  if CLIMode then
  begin
    LogPrint(STR_VOLT_ABORTED);
    Exit(False);
  end;

  Result := MessageDlg('AsProgrammer', STR_VOLT_WARN, mtWarning, [mbYes, mbNo], 0) = mrYes;
  if not Result then LogPrint(STR_VOLT_ABORTED);
end;

//ถามผู้ใช้ ถ้าไม่มีใครนั่งอยู่ก็ตอบตามค่าที่ปลอดภัย
//โหมดบรรทัดคำสั่งต้องไม่ค้างรอคนกดปุ่ม เพราะมันรันจากสคริปต์
function AskUser(const Question: string; DefaultWhenHeadless: boolean): boolean;
begin
  if CLIMode then
  begin
    if CLIForce then Exit(True);
    Exit(DefaultWhenHeadless);
  end;

  Result := MessageDlg('AsProgrammer', Question, mtWarning, [mbYes, mbNo], 0) = mrYes;
end;

//เลขประจำตัวจากโรงงาน อ่านด้วยคำสั่ง 4Bh
//ต้องเรียกตอนอยู่ในโหมดโปรแกรมแล้ว คืนสตริงว่างเมื่อชิปไม่มีเลขนี้
function ReadChipUID: string;
var
  Buf: array[0..7] of byte;
  i, Got: integer;
  AllFF, AllZero: boolean;
begin
  Result := '';
  LastChipUIDTransferExact := False;
  if not MainForm.RadioSPI.Checked then Exit;
  if MainForm.ComboSPICMD.ItemIndex <> SPI_CMD_25 then Exit;

  FillByte(Buf, SizeOf(Buf), $FF);
  Got := UsbAsp25_ReadUniqueID(Buf);
  LastChipUIDTransferExact := Got = SizeOf(Buf);
  if not LastChipUIDTransferExact then
  begin
    LogPrint(Format('Unique-ID read was short: received %d of %d bytes',
                    [Got, SizeOf(Buf)]));
    Exit;
  end;

  AllFF := True;
  AllZero := True;
  for i := 0 to High(Buf) do
  begin
    if Buf[i] <> $FF then AllFF := False;
    if Buf[i] <> $00 then AllZero := False;
  end;

  //ชิปที่ไม่รองรับ 4Bh จะปล่อยสายค้างไว้ ได้ FF ล้วนหรือ 00 ล้วน
  if AllFF or AllZero then Exit;

  for i := 0 to High(Buf) do
    Result := Result + IntToHex(Buf[i], 2);
end;

//CRC32 ของสิ่งที่อยู่ใน hex editor ตอนนี้
//ใช้ทั้งตอนตรวจกับไฟล์งานและตอนเขียนบันทึกการผลิต
function BufferCRC32: cardinal;
var
  Stream: TMemoryStream;
  Data: array of byte;
begin
  Result := 0;
  if MainForm.MPHexEditorEx.DataSize = 0 then Exit;

  Stream := TMemoryStream.Create;
  try
    MainForm.MPHexEditorEx.SaveToStream(Stream);
    Stream.Position := 0;
    SetLength(Data, Stream.Size);
    if Length(Data) = 0 then Exit;
    Stream.ReadBuffer(Data[0], Length(Data));
    Result := UpdateCRC32($FFFFFFFF, @Data[0], Length(Data));
  finally
    Stream.Free;
  end;
end;

//เอาสิ่งที่ SFDP บอกมาใส่ในตัวแปรที่ spi25 ใช้เลือก opcode
//ทำให้การเข้าโหมด 4 ไบต์และการเขียน status register ใช้วิธีที่ชิปแจ้งเอง
//แทนที่จะยิงคำสั่งของทุกยี่ห้อใส่ชิปทุกตัว
procedure ApplySFDPHints(const Info: TSFDPInfo);
begin
  Chip25SFDPRead := True;

  //เก็บก่อนออก เพราะแผนผังเซกเตอร์กับตาราง 4BAIT อยู่คนละที่กับ DWORD-16
  //ชิปที่ไม่มี DWORD-16 ก็ยังมีแผนผังเซกเตอร์ให้ใช้ได้
  CurrentSFDP := Info;
  CurrentSFDPValid := Info.Valid;

  //ชิปที่มี opcode ชุด 4 ไบต์ของตัวเองไม่ต้องสลับโหมดเลย
  if Info.Has4BAIT then
  begin
    Chip25Read4BOpcode := Info.Read4BOpcode;
    Chip25PageProg4BOpcode := Info.PageProg4BOpcode;
    Chip25FastRead4BOpcode := Info.FastRead4BOpcode;
  end;

  //ชิปที่มีตาราง SFDP เป็นชิปตามมาตรฐาน JESD216 ซึ่งมีคำสั่งอ่านเร็ว 0Bh แน่นอน
  //ชิปเก่าที่ไม่มีตารางจะไม่มีวันมาถึงบรรทัดนี้ จึงยังใช้ 03h ตามเดิม
  Chip25FastRead := MainForm.MenuFastRead.Checked;

  if not Info.HasDword16 then Exit;

  if Info.SRWriteEnableOpcode <> 0 then
    Chip25SRWrenOpcode := Info.SRWriteEnableOpcode;

  //ลำดับสำคัญ: ชิปที่ประกาศ "มีชุดคำสั่ง 4 ไบต์เฉพาะ" มัก ประกาศวิธีสลับ
  //โหมดมาด้วย (เช่น W25Q256JV ประกาศทั้ง dedicated set และ WREN+B7)
  //เดิมทางนี้จับ dedicated set ก่อนแล้วตั้ง "ไม่ต้องสลับ" ซึ่งทำให้เส้นทาง
  //ที่ต้องสลับจริง (ลบเป็นช่วงด้วย opcode ธรรมดา) ล้มเหลวทั้งที่ชิปสลับได้
  if Info.Entry4B.Always4B then
    //ไม่มีโหมดให้สลับ ทุกคำสั่งรับสี่ไบต์อยู่แล้ว
    Chip25Entry4B := E4B_ALWAYS4B
  else if Info.Entry4B.WrenB7 then
    Chip25Entry4B := E4B_WREN_B7
  else if Info.Entry4B.B7NoWren then
    Chip25Entry4B := E4B_B7
  else if Info.Entry4B.BankReg17 then
    Chip25Entry4B := E4B_BANK17
  else if Info.Entry4B.DedicatedSet or Info.Entry4B.NvConfigB1 then
    //ชิปประกาศชัดว่ามีแต่ชุดคำสั่ง 4 ไบต์เฉพาะ หรือมีแต่ B1h (nonvolatile
    //config ซึ่งเปลี่ยนค่าตั้งต้นตอนเปิดไฟ ไม่ใช่โหมดของ session นี้ และ
    //การเขียนทับทั้ง register เสี่ยงตั้ง dual/quad ถาวร): ไม่มีทางสลับ
    //ที่ปลอดภัย งานอ่าน/เขียนใช้ opcode สี่ไบต์เฉพาะได้ ส่วนงานที่ต้อง
    //สลับโหมดจะถูกปฏิเสธพร้อมเหตุผลใน Enter4B
    Chip25Entry4B := E4B_NONE;
  //ไม่มีบิตไหนตั้งเลย: คงค่าเดิม (E4B_UNKNOWN) ให้ทางเดาที่ปลอดภัยที่สุด
  //คือ WREN + B7h ทำงานเหมือนที่ผ่านมา
end;

//ให้แน่ใจว่ารู้จักผู้ผลิตก่อนส่งคำสั่งที่ต่างกันตามยี่ห้อ
//ราคาคือคำสั่ง 9Fh หนึ่งครั้ง ซึ่งชิปตระกูล 25 ทุกตัวรับได้
procedure EnsureChipHints;
var
  ID: MEMORY_ID;
  Info: TSFDPInfo;
begin
  if not MainForm.RadioSPI.Checked then Exit;
  if MainForm.ComboSPICMD.ItemIndex <> SPI_CMD_25 then Exit;

  //รหัสผู้ผลิตกับตาราง SFDP เป็นคนละเรื่อง ต้องดูแยกกัน
  //ถ้าดูแค่รหัสผู้ผลิต ชิปที่ผ่านการตรวจรหัสมาแล้วจะไม่มีวันได้อ่าน SFDP
  //และวิธีเข้าโหมด 4 ไบต์ก็จะค้างอยู่ที่ค่าเดา
  if Chip25ManufID = 0 then
  begin
    FillByte(ID.ID9FH, 3, $FF);
    FillByte(ID.ID90H, 2, $FF);
    FillByte(ID.IDABH, 1, $FF);
    FillByte(ID.ID15H, 2, $FF);
    UsbAsp25_ReadID(ID);
    //จำไว้เฉพาะตอนที่ชิปตอบจริง ไม่งั้นรหัสที่จำไว้จะเป็น FFFFFF
    //แล้วรหัสปลอมนั้นจะตามไปโผล่ในตารางชิปของผู้ใช้ตอนกดบันทึกชิปที่ตรวจพบ
    if ID.Got9F then
      LastID9F := UpperCase(IntToHex(ID.ID9FH[0], 2) + IntToHex(ID.ID9FH[1], 2) +
                            IntToHex(ID.ID9FH[2], 2));
  end;

  //SFDP บอกวิธีเข้าโหมด 4 ไบต์ที่ถูกต้องของชิปตัวนี้ ถ้ามันมีตาราง
  if not Chip25SFDPRead then
    if SFDPDetect(Info) then
      ApplySFDPHints(Info)
    else
      //ไม่มีตาราง ก็ไม่ต้องมาลองใหม่ทุกครั้ง
      Chip25SFDPRead := True;
end;

//ชิปที่กำลังตรวจอยู่ใช้แอดเดรส 4 ไบต์หรือไม่
//TBlockLockProc เป็นตัวชี้ฟังก์ชันธรรมดา ส่งพารามิเตอร์เพิ่มเข้าไปไม่ได้
var
  GuardUse4B: boolean = False;

function GuardBlockLockReader(Addr: cardinal; out Locked: boolean): boolean;
begin
  Result := UsbAsp25_ReadBlockLock(Addr, GuardUse4B, Locked);
end;

//สแกนบิตล็อกรายบล็อกเมื่อ WPS = 1
//
//ความละเอียดของบิตล็อกไม่เท่ากันตลอดทั้งชิป แบบ Winbond คือ 64K ตรงกลาง
//แต่ 4K ในบล็อกหัวและบล็อกท้าย ถ้าสแกนด้วย 64K ทั้งชิปจะพลาดเซกเตอร์ 4K
//ที่ถูกล็อกอยู่ในบล็อกหัวหรือท้าย แล้วก็จะกลับไปเป็นปัญหาเดิมคือเขียนไม่ลง
//โดยไม่มีใครบอก จึงแบ่งสแกนเป็นสามช่วงตามความละเอียดจริง
function WPSBlocksLocked(StartAddr, Len, ChipSize: cardinal;
  out LockedAt: cardinal; out AnyReadable: boolean): boolean;
const
  BOOT = 64 * 1024;
  FINE = 4 * 1024;
var
  EndAddr, LoEnd, HiStart: cardinal;

  //สแกนช่วงย่อยหนึ่งช่วง แล้วรวมผลเข้ากับตัวแปรผลลัพธ์
  function Scan(FromA, ToA, Gran: cardinal): boolean;
  var
    R: boolean;
    At: cardinal;
  begin
    Result := False;
    if ToA <= FromA then Exit;
    Result := BlockLockConflict(@GuardBlockLockReader, ChipSize, Gran,
                                FromA, ToA - FromA, At, R);
    if R then AnyReadable := True;
    if Result then LockedAt := At;
  end;

  function LowerOf(A, B: cardinal): cardinal;
  begin
    if A < B then Result := A else Result := B;
  end;

  function HigherOf(A, B: cardinal): cardinal;
  begin
    if A > B then Result := A else Result := B;
  end;

var
  Entered4B: boolean;
begin
  Result := False;
  LockedAt := 0;
  AnyReadable := False;
  Entered4B := False;

  GuardUse4B := ChipSize > 16777216;

  if (StartAddr >= ChipSize) or (Len > ChipSize - StartAddr) then Exit;
  EndAddr := StartAddr + Len;
  if EndAddr <= StartAddr then Exit;

  //คำสั่ง 3Dh กับเฟรมสี่ไบต์ใช้ได้ก็ต่อเมื่อชิปอยู่ในโหมดสี่ไบต์จริง
  //ด่านนี้วิ่งก่อน Enter4B ของตัวงาน จึงต้องพาชิปเข้าโหมดเองชั่วคราว
  //เข้าไม่ได้ = อ่านบิตล็อกไม่ได้ = AnyReadable ค้าง False ให้ผู้เรียก
  //รายงานว่า "ไม่รู้" ตามระเบียบเดิม ไม่ใช่สแกนด้วยเฟรมผิดแล้วได้คำตอบมั่ว
  if GuardUse4B and (not Mode4BActive) then
  begin
    if Chip25Entry4B = E4B_NONE then Exit;
    if UsbAsp25_EN4B() <> 1 then Exit;
    Entered4B := True;
  end;
  try

  //บล็อกหัวและบล็อกท้ายของชิป ซึ่งล็อกกันทีละ 4K
  LoEnd := BOOT;
  if LoEnd > ChipSize then LoEnd := ChipSize;
  if ChipSize > BOOT then HiStart := ChipSize - BOOT else HiStart := ChipSize;

  //หัวชิป
  if StartAddr < LoEnd then
    if Scan(StartAddr, LowerOf(EndAddr, LoEnd), FINE) then Exit(True);

  //กลางชิป ล็อกกันทีละ 64K
  if (EndAddr > LoEnd) and (StartAddr < HiStart) then
    if Scan(HigherOf(StartAddr, LoEnd), LowerOf(EndAddr, HiStart), BOOT) then Exit(True);

  //ท้ายชิป
  if EndAddr > HiStart then
    if Scan(HigherOf(StartAddr, HiStart), EndAddr, FINE) then Exit(True);
  finally
    if Entered4B then
      if UsbAsp25_EX4B() <> 1 then
        LogPrint('the chip did not leave 4-byte-address mode cleanly after ' +
                 'the block-lock scan');
  end;
end;

//อ่านค่า configuration register ที่ DecodeProtVendor ต้องใช้ตามยี่ห้อ
//
//Macronix (และ SST ที่ใช้แผนผัง BP เดียวกัน) เก็บทิศทางล็อกไว้ที่ 15h
//Spansion เก็บ TBPROT ไว้ที่ 35h ซึ่งคือไบต์เดียวกับที่อ่านมาเป็น SR2 แล้ว
//การอ่าน 15h บนชิป Spansion ที่ไม่มีรีจิสเตอร์นั้นได้ FF จากบัสลอย ซึ่งห้าม
//เชื่อเป็นค่าจริงเด็ดขาด คืน False คือ "ไม่รู้" ให้ DecodeProtVendor ประกาศ
//RangeKnown = False แทนที่จะตีความช่วงล็อกกลับหัว
function ReadVendorCR(ManufID, SR2: byte; out CR: byte): boolean;
begin
  CR := 0;
  Result := False;
  case LayoutOf(ManufID) of
    plMacronix, plSST:
      begin
        if UsbAsp25_ReadSR(CR, $15) <> 1 then Exit;
        if CR = $FF then begin CR := 0; Exit; end;
        Result := True;
      end;
    plSpansion:
      begin
        if SR2 = $FF then Exit;
        CR := SR2;
        Result := True;
      end;
    plWinbond:
      begin
        //ตระกูล Winbond: 15h อ่าน Status Register 3 ซึ่งบิต 2 คือ WPS
        //ตัวจริง (บิต 2 ของ SR2 เป็นบิตสงวน) ชิปรุ่นเก่าที่ไม่มี SR3
        //ปล่อยสายลอยตอบ FF ซึ่งห้ามเชื่อ ไม่งั้น WPS จะดูเหมือนติด
        if UsbAsp25_ReadSR(CR, $15) <> 1 then Exit;
        if CR = $FF then begin CR := 0; Exit; end;
        Result := True;
      end;
  else
    //แผนผังอื่นไม่ใช้ CR เลย ส่ง False ไปก็ไม่เสียข้อมูลอะไร
  end;
end;

//ด่านตรวจบิตป้องกันการเขียน
//
//แฟลชที่ถูกล็อกอยู่จะรับคำสั่งลบหรือเขียนแล้วทิ้งไปเงียบ ๆ ไม่มีสัญญาณผิดพลาด
//ผู้ใช้จะเห็นแค่ว่า verify ไม่ผ่าน แล้วไปตามหาปัญหาผิดที่ ตรงสายบ้าง ตรงไฟบ้าง
//ทั้งที่คำตอบอยู่ใน status register มาตั้งแต่ต้น
function ProtectionGuardOK(StartAddr, Len: cardinal): boolean;
var
  GuardID: array[0..2] of byte;
  GuardIDText: string;
  SR1, SR2, CR: byte;
  HaveCR: boolean;
  P: TProtInfo;
  FromA, ToA, EndAddr: cardinal;
  ChipSize: cardinal;
  WPSReadable: boolean;
begin
  Result := True;

  if not MainForm.RadioSPI.Checked then Exit;
  if MainForm.ComboSPICMD.ItemIndex <> SPI_CMD_25 then Exit;
  if Len = 0 then Exit;

  ChipSize := OpUI.ChipSize;
  if ChipSize = 0 then ChipSize := CurrentICParam.Size;
  if (ChipSize = 0) or (StartAddr >= ChipSize) or
     (Len > ChipSize - StartAddr) then
  begin
    OpFail('the protection-check range is outside the selected chip');
    Exit(False);
  end;

  //ด่านลำดับขั้น: มาถึงตรงนี้ด้วยลำดับที่ถูกต้องหรือเปล่า
  //
  //ที่นี่คือทางรวมของทุกงานที่ทำลายข้อมูลทั้งเจ็ดเส้นทาง และอยู่หลังการ
  //ยืนยันของผู้ใช้แล้ว (แผน Smart Write, กล่องยืนยันการลบ, หรือ --force)
  //จึงเป็นจุดที่ถูกต้องทั้งสำหรับตรวจลำดับและสำหรับ arm
  //
  //ด่านนี้ "สร้าง" ข้อเท็จจริงที่ตัวเองต้องใช้ แทนที่จะเชื่อว่าขั้นก่อนหน้า
  //ทำไว้ให้แล้ว เพราะเส้นทางทั้งเจ็ดไม่ได้ผ่านด่านตรวจ ID ชุดเดียวกัน การ
  //สมมติว่าผ่านมาแล้วคือการปฏิเสธงานที่ถูกต้องห้าในเจ็ดเส้นทาง
  //
  //และการถาม ID ตรงนี้ดีกว่าการเชื่อของเก่าอยู่แล้ว: มันคือหลักฐานว่าชิป
  //ยังตอบอยู่ ณ วินาทีก่อนจะลบมัน ไม่ใช่ตอนที่กดปุ่มเมื่อสองนาทีที่แล้ว
  if not Session.Holds(sfChipDetected) then
  begin
    FillChar(GuardID, SizeOf(GuardID), $FF);
    GuardIDText := '';
    if UsbAsp25_ReadJEDEC9FExact(GuardID) then
      GuardIDText := IntToHex(GuardID[0], 2) + IntToHex(GuardID[1], 2) +
                     IntToHex(GuardID[2], 2);
    if IsMeaninglessIdentity(GuardIDText) then
    begin
      //บัสลอยอ่านได้ FF บัสที่ถูกกดอ่านได้ 00 ทั้งสองไม่ใช่ชิป
      NoteCLIOutcome(coNoChip);
      OpFail('no chip answered the JEDEC identity read immediately before ' +
             'this destructive operation');
      Exit(False);
    end;
    LogPrint('session: chip answered ' + GuardIDText + ' before the ' +
             'destructive step');
    NoteSession(seChipDetected);
  end;

  //ตรวจไฟฟ้าอีกครั้งตอนที่รู้แน่แล้วว่าชิปคือตัวไหน ด่านที่วิ่งไปตอนปลุกบัส
  //ตัดสินจากชิปที่ "เลือกไว้" ส่วนรอบนี้ตัดสินจากชิปที่ตอบจริง
  if not BenchPreflightOK(True) then
  begin
    OpFail('the electrical preflight refused this destructive operation');
    Exit(False);
  end;

  //ถามด้วย MayArm ไม่ใช่ MayStart เพราะ MayStart ต้องการ arm ซึ่งยังไม่ได้
  //ทำ ถ้า arm ก่อนแล้วค่อยถาม MayStart ก็เท่ากับถามคำถามที่เพิ่งทำให้เป็น
  //จริงด้วยตัวเอง ซึ่งไม่พิสูจน์อะไรเลย
  //
  //ถามในนามของ soErase ไม่ใช่ soWrite เพราะทางรวมนี้ใช้ร่วมกับการลบซึ่งไม่มี
  //ภาพ ส่วนงานเขียนที่ไม่มีภาพนั้นเป็นไปไม่ได้อยู่แล้วโดยตัวเส้นทางเอง
  if not Session.MayArm(soErase) then
  begin
    OpFail('the operation was reached out of order: ' +
           Session.ArmRefusal(soErase));
    Exit(False);
  end;
  NoteSession(seArmed);

  //โหมดอ่านอย่างเดียวมาก่อนทุกด่าน
  //
  //ตัวแลตช์จริงอยู่ใน spi25 ที่ตัวคำสั่ง ซึ่งจะปฏิเสธเงียบ ๆ อยู่แล้วไม่ว่า
  //จะมาทางไหน ที่นี่มีไว้เพื่อบอกคนว่าทำไม เพราะชั้นนี้คือชั้นที่รู้ว่า
  //ผู้ใช้กำลังพยายามทำอะไร ส่วน spi25 รู้แค่ว่ามีคำสั่งเขียนวิ่งเข้ามา
  if SafeModeBlocks(gaWrite) then
  begin
    LogPrint(SafeModeRefusal(gaWrite));
    NoteCLIOutcome(coChipLocked);
    OpFail('read-only safe mode is on');
    Exit(False);
  end;

  //ก่อนอย่างอื่นทั้งหมด: ชิปตัวนี้ตอบคำถามเดียวกันเหมือนเดิมทุกครั้งไหม
  //
  //คล็อกที่จูนแล้วพิสูจน์ได้แค่ว่าทะเบียนสามไบต์กลับมาครบ ไม่ได้พิสูจน์ว่า
  //ข้อมูลเป็นเมกะไบต์จะกลับมาครบด้วย ถ้าชิปตอบไม่เหมือนเดิม สิ่งที่พังไม่ใช่
  //แค่งานนี้ แต่รวมถึงไฟล์สำรองที่เพิ่งอ่านไปด้วย ซึ่งคือสิ่งเดียวที่จะกู้
  //กลับได้ตอนลบพลาด จึงต้องปฏิเสธ ไม่ใช่ลองใหม่
  //
  //ไม่มีทางลัดผ่านด้วย --force โดยตั้งใจ: --force แปลว่า "ฉันรู้ว่ากำลังทำ
  //อะไรอยู่" ซึ่งใช้กับเรื่องที่ผู้ใช้รู้ได้ ส่วนสายที่หลุด ๆ ติด ๆ ไม่ใช่
  //เรื่องที่ใครยืนยันแทนได้
  if not ConnectionStableForDestructive then
  begin
    OpFail('the connection is not stable enough to erase or write');
    Exit(False);
  end;

  SR1 := 0;
  SR2 := 0;
  if UsbAsp25_ReadSR(SR1, $05) <> 1 then
  begin
    OpFail('the primary protection status register could not be read');
    Exit(False);
  end;
  UsbAsp25_ReadSR(SR2, $35);

  //ต้องรู้ยี่ห้อก่อนตีความ: Macronix/ISSI มี BP สี่บิต Spansion ใช้บิต 6/5
  //เป็นธงความผิดพลาด ตีความด้วยแผนผัง Winbond จะรายงานช่วงล็อกเล็กกว่าจริง
  //แล้วการ์ดตัวนี้จะปล่อยงานเขียนผ่านทั้งที่ชิปจะทิ้งมันเงียบ ๆ
  EnsureChipHints;
  HaveCR := ReadVendorCR(Chip25ManufID, SR2, CR);

  //ชิปที่ไม่มี status register ตัวที่สองจะปล่อยสายค้างไว้ อ่านได้ FF ล้วน
  //ถ้าเชื่อค่านั้น CMP กับ WPS จะดูเหมือนถูกตั้ง แล้วการตีความจะผิดทั้งหมด
  if SR2 = $FF then SR2 := 0;

  P := DecodeProtVendor(Chip25ManufID, SR1, SR2, CR, HaveCR);

  //มีของถูกล็อกอยู่แต่บอกช่วงไม่ได้ = ไม่รู้ ไม่ใช่ปลอดภัย
  if not P.RangeKnown then
  begin
    LogPrint(Format(STR_PROT_HEADER, [SR1, SR2]));
    if CLIMode and (not CLIForce) then
    begin
      LogPrint(STR_GUARD_REFUSED);
      OpFail('the chip reports write protection but the locked range could not be decoded');
      Exit(False);
    end;
    Result := AskUser(STR_GUARD_Q, False);
    if not Result then
      OpFail('the chip reports write protection but the locked range could not be decoded');
    Exit;
  end;

  //WPS = 1 แปลว่าบิต BP ไม่มีความหมายแล้ว พื้นที่ที่ถูกล็อกมาจากบิตรายบล็อก
  //ซึ่งอ่านจาก status register ไม่ได้ ต้องไล่ถามทีละบล็อกด้วย 3Dh
  //
  //เดิมได้แค่พิมพ์ว่าตีความไม่ได้แล้วปล่อยผ่าน ซึ่งแปลว่าชิปกลุ่มนี้ไม่มี
  //การ์ดกันเขียนเลยทั้งที่เป็นกลุ่มที่ล็อกไว้จริง ๆ บ่อยที่สุด
  if P.WPS then
  begin
    LogPrint(Format(STR_PROT_HEADER, [SR1, SR2]));
    LogPrint(STR_WPS_SCANNING);

    if WPSBlocksLocked(StartAddr, Len, ChipSize, FromA, WPSReadable) then
    begin
      LogPrint(Format(STR_WPS_LOCKED, [FromA]));

      if CLIMode and (not CLIForce) then
      begin
        LogPrint(STR_GUARD_REFUSED);
        NoteCLIOutcome(coChipLocked);
        OpFail('target area is write protected by an individual block lock',
               FromA);
        Exit(False);
      end;

      Result := AskUser(STR_GUARD_Q, False);
      if not Result then
      begin
        NoteCLIOutcome(coChipLocked);
        OpFail('target area is write protected by an individual block lock',
               FromA);
      end;
      Exit;
    end;

    //อ่านบิตล็อกไม่ได้เลยแปลว่าไม่รู้ ซึ่งไม่เหมือนกับรู้ว่าไม่ล็อก
    //บอกตรง ๆ ดีกว่าเงียบแล้วปล่อยผ่านเหมือนว่าตรวจแล้ว
    if not WPSReadable then
    begin
      LogPrint(STR_WPS_UNREADABLE);
      OpFail('individual block-lock state could not be read');
      Exit(False);
    end
    else
      LogPrint(STR_WPS_CLEAR);

    Exit;
  end;

  if not ProtectedRange(P, ChipSize, FromA, ToA) then
  begin
    LogPrint(STR_GUARD_OK);
    Exit;
  end;

  //ช่วงที่ล็อกกับช่วงที่จะแตะทับกันหรือไม่
  EndAddr := StartAddr + Len - 1;
  if (ToA < StartAddr) or (FromA > EndAddr) then
  begin
    LogPrint(STR_GUARD_OK);
    Exit;
  end;

  LogPrint(Format(STR_PROT_HEADER, [SR1, SR2]));
  LogPrint(Format(STR_GUARD_BLOCKED, [FromA, ToA]));

  //SRP1 ล็อก status register ด้วยฮาร์ดแวร์ ปลดด้วยซอฟต์แวร์ไม่ได้เลย
  if P.SRP1 then LogPrint(STR_GUARD_SRP1);

  if CLIMode and (not CLIForce) then
  begin
    LogPrint(STR_GUARD_REFUSED);
    NoteCLIOutcome(coChipLocked);
    OpFail('target area is write protected', FromA);
    Exit(False);
  end;

  Result := AskUser(STR_GUARD_Q, False);
  if not Result then
  begin
    NoteCLIOutcome(coChipLocked);
    OpFail('target area is write protected', FromA);
  end;
end;

//ตรวจภาพในบัฟเฟอร์กับไฟล์งาน
//กันการหยิบไฟล์ผิดรุ่น ซึ่งเป็นความผิดพลาดที่พบบ่อยที่สุดในสายการผลิต
function JobFileGuardOK(Size: cardinal): boolean;
var
  ErrMsg: string;
begin
  Result := True;
  //The authenticated, versioned production manifest supersedes the legacy
  //three-field CRC job file.  Applying both policies can only create stale
  //configuration failures after the strict job has already been admitted.
  if StrictProductionMode then Exit;
  if CurrentJobLoadError <> '' then
  begin
    LogPrint(STR_JOB_FAILED + CurrentJobLoadError);
    OpFail('configured job file is unusable: ' + CurrentJobLoadError);
    Exit(False);
  end;
  if (ProdSettings.JobFile <> '') and (not CurrentJob.Loaded) then
  begin
    OpFail('the configured job file was not loaded');
    Exit(False);
  end;
  if not CurrentJob.Loaded then Exit;
  if Size = 0 then Exit;

  //อ่านจาก hex editor ไม่ใช่จาก RomF เพราะตอนที่ด่านนี้ทำงาน
  //RomF ยังเป็นของงานก่อนหน้า ยังไม่ได้ถูกเติมด้วยข้อมูลรอบนี้
  if not CheckJob(CurrentJob, CurrentICParam.Name, Size, BufferCRC32, ErrMsg) then
  begin
    LogPrint(STR_JOB_FAILED + ErrMsg);
    OpFail('job file mismatch: ' + ErrMsg);
    Exit(False);
  end;

  LogPrint(STR_JOB_OK);
end;

//โหลดไฟล์งานตามที่ตั้งไว้ ต้องเรียกใหม่ทุกครั้งที่ค่านั้นเปลี่ยน
procedure RefreshJobFile;
var
  ErrMsg: string;
begin
  FillChar(CurrentJob, SizeOf(CurrentJob), 0);
  CurrentJob.ChipName := '';
  CurrentJobLoadError := '';

  if ProdSettings.JobFile = '' then Exit;

  if LoadJobFile(ProdSettings.JobFile, CurrentJob, ErrMsg) then
    LogPrint(STR_JOB_LOADED + ProdSettings.JobFile)
  else
  begin
    CurrentJobLoadError := ErrMsg;
    LogPrint(STR_JOB_FAILED + ErrMsg);
  end;
end;

function TryAppendProdLogEntry(Size, CRC: cardinal; const UID: string;
  out ErrorText: string): boolean;
var
  Rec: TProdRecord;
begin
  Result := False;
  ErrorText := '';
  if ProdSettings.ProdLogFile = '' then
  begin
    ErrorText := 'no production evidence file is configured';
    Exit;
  end;

  Rec.TimeStamp := Now;
  Rec.ChipName := CurrentICParam.Name;
  Rec.UID := UID;
  Rec.Serial := '';
  if CurrentSerialValid then Rec.Serial := CurrentSerial.Text;
  Rec.Operator_ := ProdSettings.Operator_;
  Rec.Size := Size;
  Rec.CRC32 := CRC;
  Rec.Note := '';

  if OpOK then
    Rec.Outcome := poPass
  else
  begin
    Rec.Outcome := poFail;
    Rec.Note := LastOp.ErrorText;
  end;

  Result := AppendProdLog(ProdSettings.ProdLogFile, Rec);
  if not Result then
    ErrorText := 'cannot append ' + ProdSettings.ProdLogFile;
end;

//หนึ่งบรรทัดต่อชิปหนึ่งตัว ผ่านหรือไม่ผ่านเอาจากผลของงานล่าสุด
procedure WriteProdLogEntry(Size, CRC: cardinal; const UID: string);
var
  Err: string;
begin
  if ProdSettings.ProdLogFile = '' then Exit;

  if TryAppendProdLogEntry(Size, CRC, UID, Err) then
    LogPrint(STR_PROD_LOGGED + ProdSettings.ProdLogFile)
  else
  begin
    LogPrint(STR_PROD_LOG_FAIL + ProdSettings.ProdLogFile);
    OpFail('the production evidence could not be written: ' + Err);
  end;
end;

function EvidenceValue(const Value: string): string;
begin
  Result := StringReplace(Value, #13, ' ', [rfReplaceAll]);
  Result := StringReplace(Result, #10, ' ', [rfReplaceAll]);
  Result := StringReplace(Result, #9, ' ', [rfReplaceAll]);
end;

function TNORUIBridge.CommitEvidence(const Request: TOperationRequest;
  out ErrorText: string): boolean;
var
  Payload: TBytes;
  Text: RawByteString;
  FileName, PayloadHash, UIDText, LocalSerial: string;
begin
  if StrictMode then
  begin
    Result := False;
    ErrorText := '';
    if (EvidenceDirectory = '') or
       (not DirectoryExists(EvidenceDirectory)) then
    begin
      ErrorText := 'strict evidence directory does not exist';
      Exit;
    end;
    LocalSerial := SerialText;
    if LocalSerial = '' then LocalSerial := 'none';
    UIDText := Request.Chip.UniqueID;
    if UIDText = '' then UIDText := 'none';
    Text :=
      'format=AsProgrammer-ProX/verified-programming' + #10 +
      'version=1' + #10 +
      'result=PASS' + #10 +
      'job_id=' + EvidenceValue(StrictJobID) + #10 +
      'job_revision=' + IntToStr(StrictJobRevision) + #10 +
      'operation_id=' + EvidenceValue(Request.OperationID) + #10 +
      'operator=' + EvidenceValue(OperatorName) + #10 +
      'programmer_id=' + EvidenceValue(ProgrammerID) + #10 +
      'chip=' + EvidenceValue(Request.Chip.Name) + #10 +
      'jedec_id=' + Request.Chip.JedecID + #10 +
      'chip_profile_sha256=' + Request.Chip.ProfileHash + #10 +
      'uid=' + UIDText + #10 +
      'start_address=' + IntToStr(Request.Target.Address) + #10 +
      'length=' + IntToStr(Request.Target.Length) + #10 +
      'image_sha256=' + Request.ImageHash + #10 +
      'image_crc32=' + IntToHex(EvidenceCRC, 8) + #10 +
      'serial=' + EvidenceValue(LocalSerial) + #10 +
      'trusted_read_passes=' + IntToStr(ReadPasses) + #10 +
      'backup=trusted_full_chip' + #10 +
      'physical_verify=full_affected_blocks' + #10;
    SetLength(Payload, Length(Text));
    if Length(Text) > 0 then Move(Text[1], Payload[0], Length(Text));
    FileName := IncludeTrailingPathDelimiter(EvidenceDirectory) +
                Request.OperationID + '.evidence';
    //Strict runs always sign under the station key, so evidence cannot be
    //forged or re-attributed by anyone without it.  Admission guarantees the
    //key is present; its absence here is a programming error, not a fallback.
    if (EvidenceKeyID = '') or (Length(EvidenceKey) = 0) then
    begin
      ErrorText := 'strict evidence requires the station signing key';
      Exit;
    end;
    Result := SaveSignedEvidenceAtomic(FileName, Request.OperationID, Payload,
                EvidenceKeyID, EvidenceKey, PayloadHash, ErrorText);
    EvidenceCommitted := Result;
    if Result then
      LogPrint('Durable production evidence (HMAC key ' + EvidenceKeyID +
               '): ' + FileName + ' content SHA-256=' + PayloadHash);
    Exit;
  end;

  Result := TryAppendProdLogEntry(EvidenceSize, EvidenceCRC, EvidenceUID,
                                  ErrorText);
  EvidenceCommitted := Result;
  if Result then
    LogPrint(STR_PROD_LOGGED + ProdSettings.ProdLogFile);
end;

function TNORUIBridge.CommitFailureEvidence(const Request: TOperationRequest;
  const FailureText: string; out ErrorText: string): boolean;
var
  Payload: TBytes;
  Text: RawByteString;
  FileName, PayloadHash, UIDText, LocalSerial: string;
begin
  Result := False;
  ErrorText := '';
  if not StrictMode then
  begin
    ErrorText := 'failure envelopes are reserved for strict production mode';
    Exit;
  end;
  if (EvidenceDirectory = '') or
     (not DirectoryExists(EvidenceDirectory)) then
  begin
    ErrorText := 'strict evidence directory does not exist';
    Exit;
  end;

  UIDText := Request.Chip.UniqueID;
  if UIDText = '' then UIDText := 'none';
  LocalSerial := SerialText;
  if LocalSerial = '' then LocalSerial := 'none';
  Text :=
    'format=AsProgrammer-ProX/verified-programming' + #10 +
    'version=1' + #10 +
    'result=FAIL' + #10 +
    'job_id=' + EvidenceValue(StrictJobID) + #10 +
    'job_revision=' + IntToStr(StrictJobRevision) + #10 +
    'operation_id=' + EvidenceValue(Request.OperationID) + #10 +
    'operator=' + EvidenceValue(OperatorName) + #10 +
    'programmer_id=' + EvidenceValue(ProgrammerID) + #10 +
    'chip=' + EvidenceValue(Request.Chip.Name) + #10 +
    'jedec_id=' + Request.Chip.JedecID + #10 +
    'chip_profile_sha256=' + Request.Chip.ProfileHash + #10 +
    'uid=' + UIDText + #10 +
    'start_address=' + IntToStr(Request.Target.Address) + #10 +
    'length=' + IntToStr(Request.Target.Length) + #10 +
    'image_sha256=' + Request.ImageHash + #10 +
    'image_crc32=' + IntToHex(EvidenceCRC, 8) + #10 +
    'serial=' + EvidenceValue(LocalSerial) + #10 +
    'trusted_read_passes=' + IntToStr(ReadPasses) + #10 +
    'physical_verify=' +
      IfThen(PhysicalVerifyCompleted, 'completed', 'not_completed') + #10 +
    'error=' + EvidenceValue(FailureText) + #10;
  SetLength(Payload, Length(Text));
  if Length(Text) > 0 then Move(Text[1], Payload[0], Length(Text));
  FileName := IncludeTrailingPathDelimiter(EvidenceDirectory) +
              Request.OperationID + '.evidence';
  if (EvidenceKeyID = '') or (Length(EvidenceKey) = 0) then
  begin
    ErrorText := 'strict evidence requires the station signing key';
    Exit;
  end;
  Result := SaveSignedEvidenceAtomic(FileName, Request.OperationID, Payload,
              EvidenceKeyID, EvidenceKey, PayloadHash, ErrorText);
  EvidenceCommitted := Result;
  if Result then
    LogPrint('Durable failure evidence (HMAC key ' + EvidenceKeyID +
             '): ' + FileName + ' content SHA-256=' + PayloadHash);
end;

//ชิปตัวนี้เคยเขียนผ่านไปแล้วหรือยัง
//คืน False เมื่อเคยแล้วและผู้ใช้ไม่ยืนยันให้เขียนซ้ำ
function DuplicateChipGuardOK(const UID: string): boolean;
begin
  Result := True;
  if StrictProductionMode then Exit;
  if not ProdSettings.CheckUID then Exit;
  if ProdSettings.ProdLogFile = '' then Exit;
  if (not LastChipUIDTransferExact) or (UID = '') then
  begin
    OpFail('duplicate-UID checking is enabled but no exact usable UID was read');
    Exit(False);
  end;

  if not ProdLogHasPassedUID(ProdSettings.ProdLogFile, UID) then Exit;

  LogPrint(STR_PROD_UID_SEEN + UID);

  if CLIMode and (not CLIForce) then
  begin
    OpFail('this chip has already been programmed, unique ID ' + UID);
    Exit(False);
  end;

  Result := AskUser(STR_PROD_UID_SEEN + UID + #13#10#13#10 + 'Program it again?', False);
  if not Result then
    OpFail('this chip has already been programmed, unique ID ' + UID);
end;

//ชื่อกลุ่มผู้ผลิตสั้น ๆ สำหรับใช้เป็นชื่อธาตุใน xml
//JedecVendor คืนข้อความยาวอย่าง 'Spansion / Cypress / Infineon' เอามาทั้งดุ้นไม่ได้
function ShortVendorTag(ManufID: byte): string;
var
  Full: string;
  p: integer;
begin
  Full := JedecVendor(ManufID);
  if Full = '' then Exit('USER');

  p := Pos(' ', Full);
  if p > 1 then Full := Copy(Full, 1, p - 1);
  Result := UpperCase(Full);
end;

//บันทึกชิปที่ตั้งค่าอยู่ตอนนี้ลงตารางของผู้ใช้
function SaveCurrentChipToUserList(const AName: string): boolean;
var
  P: TSaveChipParams;
  ErrMsg: string;
begin
  Result := False;

  P.Vendor := ShortVendorTag(Chip25ManufID);
  P.Name := Trim(AName);
  P.ID := LastID9F;
  P.Size := CurrentICParam.Size;
  if P.Size = 0 then P.Size := UIChipSize;
  if CurrentICParam.Page > 0 then
    P.Page := cardinal(CurrentICParam.Page)
  else
    P.Page := 256;
  P.Sector := CurrentICParam.Sector;
  P.SectorCmd := CurrentICParam.SectorOpcode;
  P.Note := 'added from SFDP';

  if not SaveChipToUserList(ChipListFile3Name, P, ErrMsg) then
  begin
    LogPrint(STR_CHIPSAVE_FAIL + ErrMsg);
    Exit;
  end;

  LogPrint(STR_CHIPSAVE_OK + ChipListFile3Name);

  //โหลดไฟล์ที่เพิ่งเขียนกลับเข้ามา จะได้ค้นเจอทันทีโดยไม่ต้องปิดโปรแกรม
  //เมนู IC สร้างครั้งเดียวตอนเปิดโปรแกรม รายการใหม่จึงโผล่ในเมนูรอบหน้า
  try
    if ChipListFile3 <> nil then FreeAndNil(ChipListFile3);
    ReadXMLFile(ChipListFile3, ChipListFile3Name);
  except
    ChipListFile3 := nil;
  end;

  Result := True;
end;

//ตรวจว่าพื้นที่ที่จะเขียนถูกลบแล้วจริง
//การเขียนทับข้อมูลเดิมที่ยังไม่ได้ลบ แฟลชจะทำได้แค่เปลี่ยนบิต 1 เป็น 0
//ผลคือข้อมูลเพี้ยนโดยไม่มีใครแจ้ง จนกว่าจะไปเจอตอน verify
function BlankCheckBeforeWrite(StartAddress, Len: cardinal): boolean;
var
  Chunk: array[0..2047] of byte;
  Addr, Remain: cardinal;
  n, i, Got: integer;
  BlankByte: byte;
  Use4B, Native4B, FastRead: boolean;
  ReadOp: byte;
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

  Use4B := Needs4ByteAddress(StartAddress, Len, OpUI.ChipSize);
  Native4B := Use4B and Native4BRead;
  //EN4B ที่ส่งไม่ผ่านแปลว่าชิปยังอยู่โหมด 3 ไบต์ อ่านต่อไปคือคนละแอดเดรส
  if Use4B and (not Native4B) then
    if not Enter4B then Exit(False);
  PickReadOpcode(Native4B, ReadOp, FastRead);

  try
    while Remain > 0 do
    begin
      n := SizeOf(Chunk);
      if cardinal(n) > Remain then n := Remain;

      FillByte(Chunk, SizeOf(Chunk), 0);
      Got := ReadData25(ReadOp, FastRead, Use4B, Addr, Chunk, n);
      if Got <> n then
      begin
        OpFail(Format('short read during blank check: received %d of %d bytes',
                      [Got, n]), Addr);
        Exit(False);
      end;

      for i := 0 to n - 1 do
        if Chunk[i] <> BlankByte then
        begin
          LogPrint(STR_NOT_BLANK + IntToHex(Addr + cardinal(i), 8));
          Result := AskUser(STR_NOT_BLANK_Q, False);
          if not Result then
            OpFail('the target area is not erased',
                   Addr + cardinal(i));
          Exit;
        end;

      Inc(Addr, cardinal(n));
      Dec(Remain, cardinal(n));

      OpProcessMessages;
      if UserCancel then Exit(False);
    end;
  finally
    Leave4B;
  end;
end;

//Publish only an already trusted, complete snapshot.  The final name is never
//visible until the complete temporary file has been size-checked and renamed.
//ใบกำกับของไฟล์สำรอง เขียนคู่กับ .bin เสมอ
//
//ไฟล์ .bin ล้วน ๆ ตอบคำถามที่สำคัญที่สุดไม่ได้สักข้อ: มันมาจากชิปตัวไหน
//อ่านมาเมื่อไร ตอนนั้นจ่ายไฟกี่โวลต์ และไบต์ในไฟล์ยังเหมือนตอนที่อ่านมาไหม
//คำถามพวกนี้จะถูกถามตอนที่ต้องกู้คืน ซึ่งเป็นตอนที่หาคำตอบยากที่สุดพอดี
//
//ล้มเหลวที่นี่ไม่ทำให้งานสำรองล้มเหลว ไฟล์ .bin ที่เขียนสำเร็จแล้วยังกู้ได้
//อยู่ ใบกำกับที่หายไปแค่ทำให้ต้องเดามากขึ้น แต่ต้องบอกให้รู้ ไม่ใช่เงียบ
procedure WriteBackupManifest(const BinFileName: string; Size: cardinal);
var
  J: TJsonObject;
  Digest: TSHA256Digest;
  ErrMsg: string;
  Caps: TProgrammerElectricalCapabilities;
  Obs: TElectricalObservation;
  CapsValid, ObsValid: boolean;
  Report: TRailReport;
  ManifestName: string;
  Text: TBytes;
  i: integer;
begin
  //ชื่อไฟล์เดียวกับ .bin เพื่อให้จับคู่กันได้แม้ถูกย้ายหรือเปลี่ยนชื่อโฟลเดอร์
  ManifestName := ChangeFileExt(BinFileName, '.json');

  J.Init;
  J.AddInt('schema_version', CLI_SCHEMA_VERSION);
  J.AddString('image', ExtractFileName(BinFileName));
  J.AddInt('size', Size);
  //UTC ไม่ใช่เวลาท้องถิ่น ไฟล์สำรองเดินทางข้ามเครื่องและข้ามโซนเวลา
  J.AddString('read_utc',
    FormatDateTime('yyyy-mm-dd"T"hh:nn:ss"Z"', LocalTimeToUniversal(Now)));
  J.AddString('chip', CurrentICParam.Name);
  J.AddString('jedec_id', UpperCase(CurrentICParam.ID));

  if AsProgrammer.Programmer <> nil then
    J.AddString('programmer', AsProgrammer.Programmer.HardwareName)
  else
    J.AddNull('programmer');

  //แรงดันตอนที่อ่านมา ใช้กติกาเดียวกับรายงานรางไฟ: วัดไม่ได้คือ null
  //ไม่ใช่ศูนย์ ไฟล์สำรองที่อ้างว่า "อ่านมาที่ 0 V" แย่กว่าไฟล์ที่บอกว่าไม่รู้
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

  //SHA-256 ของไฟล์ที่เพิ่งเขียนลงดิสก์จริง ๆ ไม่ใช่ของบัฟเฟอร์ในหน่วยความจำ
  //เพราะสิ่งที่ต้องพิสูจน์คือไฟล์บนดิสก์ยังเหมือนเดิม
  if SHA256File(BinFileName, Digest, ErrMsg) then
    J.AddString('sha256', LowerCase(DigestToHex(Digest)))
  else
  begin
    J.AddNull('sha256');
    LogPrint('the backup was written but could not be hashed: ' + ErrMsg);
  end;

  SetLength(Text, Length(J.Text));
  for i := 1 to Length(J.Text) do Text[i - 1] := byte(J.Text[i]);
  if AtomicWriteDurable(ManifestName, Text, False, ErrMsg) then
    LogPrint('backup manifest: ' + ManifestName)
  else
    //ไม่ล้มงาน แต่ต้องไม่เงียบ
    LogPrint('the backup manifest could not be written: ' + ErrMsg);
  Text := nil;
end;

function PersistTrustedBackup(Backup: TMemoryStream;
  ExpectedSize: cardinal): boolean;
var
  Dir, FileName, ChipName, ErrMsg: string;
  Data: TBytes;
  i: integer;
begin
  Result := False;
  LastBackupFileName := '';
  if (Backup = nil) or (ExpectedSize = 0) or
     (Backup.Size <> int64(ExpectedSize)) or
     (QWord(ExpectedSize) > QWord(High(SizeInt))) then
  begin
    OpFail('the trusted backup snapshot is missing or has the wrong size');
    LogPrint(STR_BACKUP_FAILED);
    Exit;
  end;

  Dir := 'backup' + DirectorySeparator;
  if not DirectoryExists(Dir) then
    if not CreateDir(Dir) then
    begin
      OpFail('the backup directory could not be created');
      LogPrint(STR_BACKUP_FAILED);
      Exit;
    end;

  ChipName := CurrentICParam.Name;
  if ChipName = '' then ChipName := 'chip';
  for i := 1 to Length(ChipName) do
    if not (ChipName[i] in
            ['0'..'9', 'A'..'Z', 'a'..'z', '_', '-', '.']) then
      ChipName[i] := '_';

  FileName := Dir + ChipName + '_' +
              FormatDateTime('yyyymmdd-hhnnss-zzz', Now) + '-' +
              IntToHex(GetTickCount64 and $FFFF, 4) + '.bin';
  try
    SetLength(Data, SizeInt(ExpectedSize));
    Backup.Position := 0;
    Backup.ReadBuffer(Data[0], SizeInt(ExpectedSize));
  except
    on E: Exception do
    begin
      Data := nil;
      OpFail('the trusted backup snapshot could not be captured: ' + E.Message);
      LogPrint(STR_BACKUP_FAILED);
      Exit;
    end;
  end;

  ErrMsg := '';
  if not AtomicWriteDurable(FileName, Data, False, ErrMsg) then
  begin
    Data := nil;
    OpFail('the completed backup file could not be published durably: ' + ErrMsg);
    LogPrint(STR_BACKUP_FAILED);
    Exit;
  end;
  Data := nil;
  if (not FileExists(FileName)) or
     (FileSizeUtf8(FileName) <> int64(ExpectedSize)) then
  begin
    OpFail('the durable backup file is missing or has the wrong size');
    LogPrint(STR_BACKUP_FAILED);
    Exit;
  end;
  LastBackupFileName := FileName;
  LogPrint(STR_BACKUP_DONE + FileName);
  //บันทึกว่าไฟล์นี้คือชิปตัวไหน อ่านมาเมื่อไร ที่แรงดันเท่าไร และไบต์ตรงกับ
  //ตอนอ่านหรือเปล่า ไฟล์ .bin เปล่า ๆ ตอบไม่ได้สักข้อ
  WriteBackupManifest(FileName, ExpectedSize);
  Result := True;
end;

//สำรองเนื้อหาชิปก่อนเขียนหรือลบ
//คืน False เมื่อสำรองไม่สำเร็จ ซึ่งแปลว่าห้ามทำต่อ
function AutoBackupChip(TrustedCopy: TMemoryStream = nil;
  AcceptedSPISpeed: PInteger = nil): boolean;
var
  Backup, Again: TMemoryStream;
  RequiredPasses, PassNo: integer;
  Diff: cardinal;
  At: int64;

  function ReadFamilyPass(Stream: TMemoryStream): boolean;
  var
    ChunkSize: word;
  begin
    Result := False;
    Stream.Clear;
    if MainForm.RadioI2C.Checked then
    begin
      if MainForm.ComboAddrType.ItemIndex < 0 then
      begin
        OpFail('auto-backup needs a selected I2C address type');
        Exit;
      end;
      ChunkSize := 65535;
      if MainForm.CheckBox_I2C_ByteRead.Checked then ChunkSize := 1;
      ReadFlashI2C(Stream, 0, OpUI.ChipSize, ChunkSize, SetI2CDevAddr());
    end
    else if MainForm.RadioMW.Checked then
    begin
      if not IsNumber(MainForm.ComboMWBitLen.Text) then
      begin
        OpFail('auto-backup needs a valid MicroWire address bit length');
        Exit;
      end;
      ReadFlashMW(Stream, StrToInt(MainForm.ComboMWBitLen.Text), 0,
                  OpUI.ChipSize);
    end
    else if MainForm.RadioSPI.Checked then
      case MainForm.ComboSPICMD.ItemIndex of
        SPI_CMD_25:
          ReadFlash25(Stream, 0, OpUI.ChipSize);
        SPI_CMD_95:
          ReadFlash95(Stream, 0, OpUI.ChipSize);
        SPI_CMD_45:
          begin
            if not IsNumber(MainForm.ComboPageSize.Text) then
            begin
              OpFail('auto-backup needs a numeric DataFlash page size');
              Exit;
            end;
            ReadFlash45(Stream, 0, StrToInt(MainForm.ComboPageSize.Text),
                        OpUI.ChipSize);
          end;
        SPI_CMD_KB:
          ReadFlashKB(Stream, 0, OpUI.ChipSize);
      else
        begin
          LogPrint(STR_BACKUP_SKIPPED);
          OpFail('auto-backup has no safe reader for the selected SPI family');
          Exit;
        end;
      end
    else
    begin
      LogPrint(STR_BACKUP_SKIPPED);
      OpFail('auto-backup has no safe reader for the selected protocol');
      Exit;
    end;

    Result := OpOK and (Stream.Size = int64(OpUI.ChipSize));
    if not Result and OpOK then
      OpFail(Format('the backup read returned %d bytes, expected %d',
                    [Stream.Size, OpUI.ChipSize]));
  end;

begin
  Result := True;
  LastBackupFileName := '';

  //Every destructive path requires both a stable full-chip read and a
  //durably published recovery file.  TrustedCopy additionally returns the
  //same admitted bytes to a transactional planner.
  if OpUI.ChipSize = 0 then
  begin
    OpFail('auto-backup needs a non-zero selected chip size');
    LogPrint(STR_BACKUP_FAILED);
    Exit(False);
  end;

  RequiredPasses := 2;
  if StrictProductionMode then
  begin
    if (StrictProductionReadPasses < 2) or
       (StrictProductionReadPasses > 16) then
    begin
      OpFail('strict production read-pass count must be between 2 and 16');
      Exit(False);
    end;
    RequiredPasses := StrictProductionReadPasses;
  end;

  LogPrint(STR_BACKUP_MAKING);
  Backup := TMemoryStream.Create;
  Again := TMemoryStream.Create;
  try
    if not ReadFamilyPass(Backup) then
    begin
      LogPrint(STR_BACKUP_FAILED);
      Exit(False);
    end;

    //SPI NOR keeps its measured clock-fallback behavior.  Other families use
    //their established full-chip reader twice and fail closed on any mismatch.
    if MainForm.RadioSPI.Checked and
       (MainForm.ComboSPICMD.ItemIndex = SPI_CMD_25) then
    begin
      if not ReadPassesAgree(Backup, 0, OpUI.ChipSize,
                             RequiredPasses, AcceptedSPISpeed) then
      begin
        LogPrint(STR_BACKUP_FAILED);
        Exit(False);
      end;
    end
    else
      for PassNo := 2 to RequiredPasses do
      begin
        LogPrint(Format(STR_READ_PASS, [PassNo, RequiredPasses]));
        if not ReadFamilyPass(Again) then
        begin
          LogPrint(STR_BACKUP_FAILED);
          Exit(False);
        end;
        At := FirstDifference(PByte(Backup.Memory), PByte(Again.Memory),
                              Backup.Size);
        if At >= 0 then
        begin
          Diff := CountDifferences(PByte(Backup.Memory), PByte(Again.Memory),
                                   Backup.Size);
          LogPrint(Format(STR_READ_UNSTABLE, [Diff, cardinal(At)]));
          OpFail(Format('two backup reads disagree in %d bytes', [Diff]), At);
          LogPrint(STR_BACKUP_FAILED);
          Exit(False);
        end;
      end;

    if not (MainForm.RadioSPI.Checked and
            (MainForm.ComboSPICMD.ItemIndex = SPI_CMD_25)) then
      LogPrint(STR_READ_STABLE);

    if TrustedCopy <> nil then
    begin
      TrustedCopy.Clear;
      Backup.Position := 0;
      TrustedCopy.CopyFrom(Backup, Backup.Size);
      TrustedCopy.Position := 0;
    end;

    if not PersistTrustedBackup(Backup, OpUI.ChipSize) then Exit(False);
    Result := True;
  finally
    Again.Free;
    Backup.Free;
  end;
end;

//Publish the allocation only after the user has accepted the physical plan.
//A preview may calculate and display the personalized bytes, but it must not
//append evidence or consume the counter merely because the user inspected it.
function PublishCurrentSerialEvidence: boolean;
var
  LogF: TextFile;
begin
  Result := True;
  if (not ProdSettings.SNEnabled) or (not CurrentSerialValid) or
     (ProdSettings.SNLogFile = '') then Exit;

  try
    AssignFile(LogF, ProdSettings.SNLogFile);
    if FileExists(ProdSettings.SNLogFile) then Append(LogF) else Rewrite(LogF);
    WriteLn(LogF, FormatDateTime('yyyy-mm-dd hh:nn:ss', Now) + #9 +
                  CurrentICParam.Name + #9 + CurrentSerial.Text);
    CloseFile(LogF);
  except
    on E: Exception do
    begin
      LogPrint('Cannot write the serial number log file');
      OpFail('the serial-number evidence could not be written: ' + E.Message);
      Result := False;
    end;
  end;
end;

//ใส่เลขรันนิ่งตัวถัดไปลงในสตรีมก่อนเขียน และถ้ากำหนดไฟล์บันทึกไว้
//ก็เขียนเลขที่จ่ายไปต่อท้ายไฟล์นั้นด้วย
function ApplySerialToStream(Stream: TMemoryStream;
  PublishEvidence: boolean = True): boolean;
var
  Data: array of byte;
  Size: integer;
begin
  //ทุกทางออกที่ล้มเหลวต้อง OpFail ด้วย: ผู้เรียกทำแค่ `if not ... then Exit`
  //ถ้าคืน False เงียบ ๆ งานเขียนจะถูกยกเลิกทั้งที่ LastOp ยังไม่ถูกทำเครื่องหมาย
  //ว่าล้มเหลว แล้วสรุปท้ายงาน (รวมถึงบรรทัด PASS ในบันทึกการผลิต) จะโกหก
  Result := False;
  if Stream = nil then
  begin
    OpFail('there is no buffer to apply a serial number to');
    Exit;
  end;

  Size := Stream.Size;
  if Size = 0 then
  begin
    OpFail('the buffer is empty; nothing would be written');
    Exit;
  end;

  if not ProdSettings.SNEnabled then
  begin
    LastProgramCRC := UpdateCRC32($FFFFFFFF, Stream.Memory, Stream.Size);
    Exit(True);
  end;

  if not CurrentSerialValid then
  begin
    AllocateSerial(ProdSettings, CurrentSerial);
    CurrentSerialValid := CurrentSerial.Valid;
  end;

  if (not CurrentSerialValid) or
     (int64(ProdSettings.SNAddress) + CurrentSerial.Len > Size) then
  begin
    LogPrint(STR_SERIAL_NOFIT);
    OpFail('the serial number does not fit in the image');
    Exit(False);
  end;

  SetLength(Data, Size);
  Stream.Position := 0;
  Stream.ReadBuffer(Data[0], Size);

  if ApplyAllocatedSerial(CurrentSerial, ProdSettings.SNAddress,
                          Data, cardinal(Size)) then
  begin
    if PublishEvidence then
      LogPrint(STR_SERIAL_WRITTEN + CurrentSerial.Text +
               ' @ 0x' + IntToHex(ProdSettings.SNAddress, 6))
    else
      LogPrint('Preview serial number: ' + CurrentSerial.Text +
               ' @ 0x' + IntToHex(ProdSettings.SNAddress, 6));

    if PublishEvidence and (not PublishCurrentSerialEvidence) then Exit(False);

    Stream.Position := 0;
    Stream.WriteBuffer(Data[0], Size);
    LastProgramCRC := UpdateCRC32($FFFFFFFF, @Data[0], Size);
    Result := True;
  end
  else
    OpFail('the allocated serial number could not be applied to the image');

  Stream.Position := 0;
end;

//Persist the counter before the first programming command.  Failed units may
//consume a serial, but a crash can never cause that identity to be issued to a
//second physical unit.
function ReserveCurrentSerial: boolean;
begin
  Result := True;
  if (not ProdSettings.SNEnabled) or (not CurrentSerialValid) or
     CurrentSerialReserved then Exit;

  try
    ProdSettings.SNValue := ProdSettings.SNValue + ProdSettings.SNStep;
    SaveOptions(SettingsFile);
    CurrentSerialReserved := True;
  except
    on E: Exception do
    begin
      OpFail('the serial reservation could not be persisted: ' + E.Message);
      Result := False;
    end;
  end;
end;

//เติมค่าที่อ่านได้จาก SFDP ลงในหน้าจอและใน CurrentICParam
//ลำดับสำคัญ เพราะ RadioSPIChange จะล้างค่าในช่องต่าง ๆ ทิ้ง
//รายงานทุกอย่างที่อ่านได้จาก SFDP
//ไม่ใช่แค่ความอยากรู้ ถ้าชิปแจ้งว่าแผนผังเซกเตอร์ไม่สม่ำเสมอ ผู้ใช้ต้องรู้
//เพราะการลบเป็นช่วงจะพลาดถ้าเชื่อว่าทั้งชิปใช้เซกเตอร์ขนาดเดียว
procedure LogSFDPDetails(const Info: TSFDPInfo);
var
  i, t: integer;
  ESize: cardinal;
  EOpcode: byte;
  s: string;
begin
  LogPrint(STR_SFDP_FOUND + ' (JESD216 rev ' + IntToStr(Info.MajorRev) + '.' +
           IntToStr(Info.MinorRev) + ')');
  LogPrint('  Size: ' + IntToStr(Info.Density) + ' bytes');
  LogPrint('  Page: ' + IntToStr(Info.PageSize) + ' bytes');
  LogPrint('  Address bytes: ' + SFDPAddrBytesStr(Info));

  for i := 1 to 4 do
    if Info.EraseTypes[i].Size > 0 then
    begin
      s := '  Erase type ' + IntToStr(i) + ': ' + IntToStr(Info.EraseTypes[i].Size) +
           ' bytes, opcode 0x' + IntToHex(Info.EraseTypes[i].Opcode, 2);
      if Info.EraseTypes[i].Opcode4B <> 0 then
        s := s + ', 4 byte 0x' + IntToHex(Info.EraseTypes[i].Opcode4B, 2);
      LogPrint(s);
    end;

  if Info.HasDword16 then
  begin
    LogPrint(STR_SFDP_4B_ENTRY + SFDP4BEntryStr(Info));

    if Info.SRWriteEnableOpcode <> 0 then
      LogPrint(Format(STR_SFDP_SR_WREN, [Info.SRWriteEnableOpcode]));

    s := '';
    if Info.SoftReset66_99 then s := '66h then 99h';
    if Info.SoftResetF0 then
    begin
      if s <> '' then s := s + ', ';
      s := s + 'F0h';
    end;
    if s <> '' then LogPrint(STR_SFDP_RESET + s);
  end;

  if Info.Has4BAIT and ((Info.Read4BOpcode <> 0) or (Info.PageProg4BOpcode <> 0)) then
    LogPrint(Format(STR_SFDP_4B_OPCODES, [Info.Read4BOpcode, Info.PageProg4BOpcode]));

  if Info.HasSectorMap then
  begin
    if Info.Uniform then
      s := STR_SFDP_MAP_UNIFORM
    else
      s := STR_SFDP_MAP_MIXED;
    LogPrint(Format(STR_SFDP_MAP_HEADER, [Info.RegionCount, s]));

    for i := 0 to Info.RegionCount - 1 do
    begin
      ESize := 0;
      EOpcode := 0;
      //ขนาดลบที่เล็กที่สุดที่ช่วงนี้ใช้ได้
      for t := 1 to 4 do
        if ((Info.Regions[i].EraseTypeMask and (1 shl (t - 1))) <> 0) and
           (Info.EraseTypes[t].Size > 0) then
          if (ESize = 0) or (Info.EraseTypes[t].Size < ESize) then
          begin
            ESize := Info.EraseTypes[t].Size;
            EOpcode := Info.EraseTypes[t].Opcode;
          end;

      LogPrint(Format(STR_SFDP_MAP_REGION,
                      [i + 1, Info.Regions[i].Size, ESize, EOpcode]));
    end;
  end;
end;

procedure ApplySFDPInfo(const Info: TSFDPInfo);
var
  ESize: cardinal;
  EOpcode: byte;
begin
  LogSFDPDetails(Info);

  //เอาวิธีเข้าโหมด 4 ไบต์และคำสั่งปลดล็อกที่ชิปแจ้งมาใช้จริง
  ApplySFDPHints(Info);

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
  //Some backends (including EZP2023+) use firmware defaults and have no menu
  //branch below.  Never leak an uninitialized stack byte into SPIInit.
  Speed := 0;
  //แต่สำหรับ CH347 เลข 0 ไม่ใช่ค่ากลาง ๆ มันคือ 60MHz ซึ่งเร็วที่สุดที่ตั้งได้
  //"ยังไม่ได้เลือก" จึงห้ามแปลว่า "เร็วสุด" ตั้งพื้นไว้ที่ 15MHz เท่าค่าปริยาย
  //ของเมนู ถ้ามีรายการไหนติ๊กอยู่ โค้ดข้างล่างจะทับค่านี้เองอยู่แล้ว
  if AsProgrammer.Current_HW = CHW_CH347 then Speed := 2;
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

//ชื่อคล็อกปัจจุบัน ถ้าเร็วพอที่จะเป็นสาเหตุของ "ไม่มีชิปตอบ" คืนสตริงว่างถ้าไม่ใช่
//
//CH347 ตั้งได้ถึง 60MHz ซึ่งเกินกว่าที่สายหนีบหรือสายยาวจะรับไหวเกือบทุกกรณี
//บัสที่วิ่งไม่ทันอ่านกลับมาเป็น FF ทั้งหมด หน้าตาเหมือนซ็อกเก็ตว่างทุกประการ
//เตือนเฉพาะสองสเต็ปบนสุด ต่ำกว่านั้นถือว่าปัญหาน่าจะอยู่ที่อื่นจริง ๆ
function FastSPIClockWarning: string;
begin
  Result := '';
  if AsProgrammer.Current_HW <> CHW_CH347 then Exit;
  if MainForm.MenuCH347SPIClock60MHz.Checked then Result := '60 MHz';
  if MainForm.MenuCH347SPIClock30MHz.Checked then Result := '30 MHz';
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
  BytesRead, Got: integer;
  DataChunk: array[0..2047] of byte;
  Address: cardinal;

  //ตัวงานจริง จะรันบน thread เบื้องหลังถ้าเปิดโหมดนั้นไว้
  procedure DoWork;
  begin
  if (StartAddress >= ChipSize) or (ChipSize = 0) then
  begin
    LogPrint(STR_CHECK_SETTINGS);
    OpFail('the chip size, the page size or the range is not usable');
    exit;
  end;

  ChunkSize := 2;
  if ChunkSize > ChipSize then ChunkSize := ChipSize;

  LogPrint(STR_READING_FLASH);
  BytesRead := 0;
  Address := StartAddress;
  ProgressReset(ChipSize div ChunkSize);

  RomStream.Clear;

  while Address < ChipSize div 2 do
  begin
    //if ChunkSize > ((ChipSize div 2) - Address) then ChunkSize := (ChipSize div 2) - Address;

    Got := UsbAspMW_Read(AddrBitLen, Address, datachunk, ChunkSize);
    if Got <> ChunkSize then
    begin
      OpFail(Format('MicroWire short read: received %d of %d bytes',
                    [Got, ChunkSize]), int64(Address) * 2);
      Break;
    end;
    Inc(BytesRead, Got);
    RomStream.WriteBuffer(datachunk, Got);
    Inc(Address, ChunkSize div 2);

    ProgressStep(2);
    OpProcessMessages;

    if UserCancel then Break;
  end;

  if BytesRead <> ChipSize then
    begin
      LogPrint(STR_WRONG_BYTES_READ);
      OpFail('the number of bytes read does not match the size asked for');
    end
  else
    LogPrint(STR_DONE);

  SetProgressPos(0);
  end;

begin
  RunOperation(@DoWork);
end;

procedure WriteFlashMW(var RomStream: TMemoryStream; AddrBitLen: byte; StartAddress, ChipSize: cardinal);
var
  DataChunk: array[0..2047] of byte;
  Address, BytesWrite: cardinal;
  ChunkSize: Word;

  //ตัวงานจริง จะรันบน thread เบื้องหลังถ้าเปิดโหมดนั้นไว้
  procedure DoWork;
  var
    Wrote: integer;
  begin
  if (StartAddress >= ChipSize) or (ChipSize = 0) then
  begin
    LogPrint(STR_CHECK_SETTINGS);
    OpFail('the chip size, the page size or the range is not usable');
    exit;
  end;

  LogPrint(STR_WRITING_FLASH);
  BytesWrite := 0;
  Address := StartAddress;
  ProgressReset(ChipSize);

  ChunkSize := 2;

  if ChunkSize > ChipSize then ChunkSize := ChipSize;

  if UsbAspMW_Ewen(AddrBitLen) <> AddrBitLen + 3 then
  begin
    OpFail('the MicroWire EEPROM did not accept EWEN');
    Exit;
  end;

  try
    while Address < ChipSize div 2 do
    begin
      RomStream.ReadBuffer(DataChunk, ChunkSize);

      Wrote := UsbAspMW_Write(AddrBitLen, Address, datachunk, ChunkSize);
      if Wrote <> ChunkSize then
      begin
        OpFail(Format('MicroWire short write: sent %d of %d bytes',
                      [Wrote, ChunkSize]), int64(Address) * 2);
        Exit;
      end;
      Inc(BytesWrite, Wrote);
      Inc(Address, ChunkSize div 2);

      if not WaitNotBusyMW(BUSY_TIMEOUT_PAGE) then Exit;

      ProgressStep(ChunkSize);
      OpProcessMessages;

      if UserCancel then Break;
    end;

    if BytesWrite <> ChipSize then
      begin
        LogPrint(STR_WRONG_BYTES_WRITE);
        OpFail('the number of bytes written does not match the size asked for');
      end
    else
      LogPrint(STR_DONE);
  finally
    //Always put a serial EEPROM back into write-disabled state, including
    //after cancel, timeout, or a short transfer.
    if UsbAspMW_Ewds(AddrBitLen) <> AddrBitLen + 3 then
      OpFail('the MicroWire EEPROM could not be returned to EWDS');
  end;

  SetProgressPos(0);
  end;

begin
  RunOperation(@DoWork);
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
  Use4B, Native4B, FastRead: boolean;
  WriteOp, ReadOp: byte;

  //ตัวงานจริง จะรันบน thread เบื้องหลังถ้าเปิดโหมดนั้นไว้
  //ตัวนับลูปต้องเป็นตัวแปรในตัวเอง เพราะ FPC ไม่ยอมให้ใช้ตัวแปร
  //ของโพรซีเยอร์ชั้นนอกมาเป็นตัวนับ for
  procedure DoWork;
  var
    i, Wrote, Got: integer;
    WEL: boolean;
  begin
  if (WriteSize = 0) or (PageSize = 0) or
     (PageSize > SizeOf(DataChunk)) or
     (StartAddress > High(cardinal) - WriteSize) then
  begin
    LogPrint(STR_CHECK_SETTINGS);
    OpFail('the chip size, the page size or the range is not usable');
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

  //ชิปที่มีคำสั่งชุด 4 ไบต์ของตัวเองครบทั้งเขียน (12h) และอ่าน (13h)
  //ไม่ต้องสลับโหมดเลย ต้องมีครบทั้งคู่เพราะรอบตรวจหลังเขียนต้องอ่านกลับ
  //ถ้ามีแค่อย่างเดียวก็สลับโหมดตามเดิมซึ่งยังถูกต้องอยู่
  //
  //ตัวตัดสินคือขนาดชิปกับแอดเดรสที่จะแตะ ไม่ใช่ขนาดของบัฟเฟอร์
  //เดิมใช้ WriteSize ซึ่งแปลว่าการเขียนภาพ 4MB ลงชิป 32MB ที่แอดเดรส 16MB
  //ถูกส่งด้วยแอดเดรส 3 ไบต์ แอดเดรสวนกลับ แล้วข้อมูลไปทับบล็อกแรกของชิป
  Use4B := Needs4ByteAddress(StartAddress, WriteSize, OpUI.ChipSize);
  Native4B := Use4B and Native4BWrite and Native4BRead;

  if Native4B then
  begin
    WriteOp := Chip25PageProg4BOpcode;
    LogPrint(STR_4B_NATIVE);
  end
  else
  begin
    WriteOp := $02;
    //EN4B ที่ส่งไม่ผ่านแปลว่าชิปยังตีความแอดเดรสแบบ 3 ไบต์ เขียนต่อไป
    //แอดเดรสจะวนกลับแล้วไปทับบล็อกแรกของชิปก่อนที่งานจะถูกรายงานว่าล้มเหลว
    if Use4B then
      if not Enter4B then Exit;
  end;

  //opcode ที่ใช้อ่านกลับตอนตรวจ เลือกที่เดียวกับตอนอ่านปกติ
  PickReadOpcode(Native4B, ReadOp, FastRead);

  try
  while (Address-StartAddress) < WriteSize do
  begin
    //ต้องรีเซ็ตทุกเพจ เพราะตัวแปร local ที่มีค่าเริ่มต้นใน FPC เป็นแบบ static
    //ค่าจึงค้างข้ามมาจากการเขียนรอบก่อน
    SkipPage := False;

    //เฉพาะตอนเริ่มของ aai
    if (((WriteType = WT_SSTB) or (WriteType = WT_SSTW)) and (Address = StartAddress)) or
    //ตอนเริ่มเพจ
    (WriteType = WT_PAGE) then
    begin
      //A page-program command clears WEL.  Confirm it for every independent
      //page; a cable/WP#/transport failure after page one must not silently
      //drop the rest of the image.  SST AAI is one continuous sequence, so it
      //needs WREN only on its first item.
      if (WriteType = WT_PAGE) or (Address = StartAddress) then
        if not WrenOK then Exit;
    end;

    //คำนวณขนาดบัฟเฟอร์เพจแรก กันไม่ให้บัฟเฟอร์วนกลับเมื่อชนขอบแอดเดรส
    //ที่ต้องการคือจำนวนไบต์ที่เหลือจนถึงขอบเพจถัดไป ไม่ใช่เศษของขนาดชิป
    //สูตรเดิม (ChipSize - StartAddress) mod PageSize คืน 0 เมื่อแอดเดรสเริ่ม
    //ตรงขอบเพจพอดี เช่น 0x1000 บนชิป 8MB ผลคือ PageSize เป็นศูนย์
    //Address ไม่ขยับ แล้วลูปวนไม่รู้จบจนกว่าผู้ใช้จะกดยกเลิก
    if (StartAddress > 0) and (Address = StartAddress) and (PageSizeTemp > 2) then
      PageSize := FirstChunkSize(StartAddress, PageSizeTemp)
    else
      PageSize := PageSizeTemp;

    if (WriteSize - (Address-StartAddress)) < PageSize then PageSize := (WriteSize - (Address-StartAddress));
    RomStream.ReadBuffer(DataChunk, PageSize);
    Wrote := 0;

    if (WriteType = WT_SSTB) then
      if (Address = StartAddress) then //เขียนไบต์แรกพร้อมแอดเดรส
        Wrote := UsbAsp25_Write($AF, Address, datachunk, PageSize)
        else
        //ไบต์ที่เหลือเขียนโดยไม่ต้องส่งแอดเดรส
        Wrote := UsbAsp25_WriteSSTB($AF, datachunk[0]);

    if (WriteType = WT_SSTW) then
      if (Address = StartAddress) then //เขียนสองไบต์แรกพร้อมแอดเดรส
        Wrote := UsbAsp25_Write($AD, Address, datachunk, PageSize)
        else
        //ไบต์ที่เหลือเขียนโดยไม่ต้องส่งแอดเดรส
        Wrote := UsbAsp25_WriteSSTW($AD, datachunk[0], datachunk[1]);

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

        //Skipping an FF page is safe only when the target is already FF.
        //Otherwise old zero bits survive and an unchecked write can report
        //success with stale data.  Prove this page blank using the same
        //address strategy as the normal read path.
        if SkipPage then
        begin
          Got := ReadData25(ReadOp, FastRead, Use4B, Address,
                            DataChunk2, PageSize);
          if Got <> PageSize then
          begin
            OpFail(Format('short read while checking a skipped page: received %d of %d bytes',
                          [Got, PageSize]), Address);
            Exit;
          end;
          for i := 0 to PageSize - 1 do
            if DataChunk2[i] <> $FF then
            begin
              SkipPage := False;
              Break;
            end;
        end;
      end;

      if not SkipPage then
      begin
        if Use4B then //หน่วยความจำใหญ่กว่า 128Mbit
        begin
          //ใช้แอดเดรส 4 ไบต์
          Wrote := UsbAsp25_Write32bitAddr(WriteOp, Address, datachunk, PageSize)
        end
        else //หน่วยความจำไม่เกิน 128Mbit
          Wrote := UsbAsp25_Write($02, Address, datachunk, PageSize);
      end
      else
        Wrote := PageSize;
    end;

    if Wrote <> PageSize then
    begin
      OpFail(Format('SPI flash short write: sent %d of %d bytes',
                    [Wrote, PageSize]), Address);
      Exit;
    end;

    if (not OpUI.IgnoreBusy) and (not SkipPage) then  //ข้ามการตรวจสถานะ
    begin
      if not WaitNotBusy25(PageProgTimeout) then Exit;

      //ชิปแจ้งเองว่าคำสั่งเขียนล้มเหลวหรือไม่ ตรวจเฉพาะเพจแรกกับทุก ๆ 256 เพจ
      //เพราะการอ่านรีจิสเตอร์เพิ่มทุกเพจกินเวลาพอ ๆ กับการเขียนเอง
      if (Address = StartAddress) or ((ProgressPos and $FF) = 0) then
        if ChipReportedFailure('program at 0x' + IntToHex(Address, 8)) then Exit;
    end;

    if (OpUI.AutoCheck) and (WriteType = WT_PAGE) then
    begin
      Got := ReadData25(ReadOp, FastRead, Use4B, Address, datachunk2, PageSize);
      if Got <> PageSize then
      begin
        OpFail(Format('SPI flash short read after program: received %d of %d bytes',
                      [Got, PageSize]), Address);
        Exit;
      end;

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
        OpFail('the page did not read back as written',
               Address + cardinal(BadOffset));
        SetProgressPos(0);
        Exit;
      end;

      Retry := 0;
    end;

    Inc(BytesWrite, PageSize);
    Inc(Address, PageSize);
    Inc(ProgressPos);
    SetProgressPos(ProgressPos);
    ShowSpeed(Address - StartAddress, WriteSize, OpStarted);
    OpProcessMessages;

    if UserCancel then Break;
  end;

  finally
    Leave4B;
    UsbAsp25_Wrdi(); //สำหรับ sst
  end;

  OpProgress(Address - StartAddress, WriteSize);

  if BytesWrite <> WriteSize then
  begin
    LogPrint(STR_WRONG_BYTES_WRITE);
    OpFail(Format('wrote %d bytes but the buffer holds %d',
                  [BytesWrite, WriteSize]));
  end
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

  //ตัวงานจริง จะรันบน thread เบื้องหลังถ้าเปิดโหมดนั้นไว้
  //ตัวนับลูปต้องเป็นตัวแปรของตัวเอง เพราะ FPC ไม่ยอมให้ใช้ตัวแปร
  //ของโพรซีเยอร์ชั้นนอกมาเป็นตัวนับ for
  procedure DoWork;
  var
    i, Wrote, Got: integer;
    WEL: boolean;
  begin
  if (WriteSize = 0) or (PageSize = 0) or
     (PageSize > SizeOf(DataChunk)) or
     (not SPI95AddressRangeValid(ChipSize, StartAddress, WriteSize)) then
  begin
    LogPrint(STR_CHECK_SETTINGS);
    OpFail('the chip size, the page size or the range is not usable');
    exit;
  end;

  if OpUI.AutoCheck then
    LogPrint(STR_WRITING_FLASH_WCHK) else
      LogPrint(STR_WRITING_FLASH);

  PageSizeTemp := PageSize;
  BytesWrite := 0;
  Address := StartAddress;
  ProgressReset(WriteSize div PageSize);

  while (Address-StartAddress) < WriteSize do
  begin
    if not UsbAsp95_WrenChecked(WEL) then
    begin
      OpFail('the SPI EEPROM did not latch write enable (WEL stayed clear)',
             Address);
      Exit;
    end;

    PageSize := SPI95PageChunk(Address,
      WriteSize - (Address - StartAddress), PageSizeTemp);
    if PageSize = 0 then
    begin
      OpFail('the SPI EEPROM page size worked out to zero', Address);
      Exit;
    end;
    RomStream.ReadBuffer(DataChunk, PageSize);

    Wrote := UsbAsp95_Write(ChipSize, Address, datachunk, PageSize);
    if Wrote <> PageSize then
    begin
      OpFail(Format('SPI EEPROM short write: sent %d of %d bytes',
                    [Wrote, PageSize]), Address);
      Exit;
    end;

    if not OpUI.IgnoreBusy then  //ข้ามการตรวจสถานะ
      if not WaitNotBusy95(BUSY_TIMEOUT_SECTOR) then Exit;

    if OpUI.AutoCheck then
    begin
      Got := UsbAsp95_Read(ChipSize, Address, datachunk2, PageSize);
      if Got <> PageSize then
      begin
        OpFail(Format('SPI EEPROM short read after program: received %d of %d bytes',
                      [Got, PageSize]), Address);
        Exit;
      end;
      for i:=0 to PageSize-1 do
        if DataChunk2[i] <> DataChunk[i] then
        begin
          LogPrint(STR_VERIFY_ERROR+IntToHex(Address+i, 8));
          OpFail('the SPI EEPROM page did not read back as written',
                 Address + cardinal(i));
          SetProgressPos(0);
          Exit;
        end;
    end;

    Inc(BytesWrite, PageSize);
    Inc(Address, PageSize);
    ProgressStep(1);
    OpProcessMessages;
    if UserCancel then Break;
  end;

  if BytesWrite <> WriteSize then
    begin
      LogPrint(STR_WRONG_BYTES_WRITE);
      OpFail('the number of bytes written does not match the size asked for');
    end
  else
    LogPrint(STR_DONE);

  SetProgressPos(0);
  end;

begin
  RunOperation(@DoWork);
end;

procedure EraseEEPROM25(StartAddress, WriteSize: cardinal; PageSize: word; ChipSize: integer);
var
  DataChunk: array[0..2047] of byte;
  DataChunk2: array[0..2047] of byte;
  Address, BytesWrite: cardinal;
  PageSizeTemp: word;

  //ตัวงานจริง จะรันบน thread เบื้องหลังถ้าเปิดโหมดนั้นไว้
  //ตัวนับลูปต้องเป็นตัวแปรของตัวเอง เพราะ FPC ไม่ยอมให้ใช้ตัวแปร
  //ของโพรซีเยอร์ชั้นนอกมาเป็นตัวนับ for
  procedure DoWork;
  var
    i, Wrote, Got: integer;
    WEL: boolean;
  begin
  if (StartAddress >= WriteSize) or (WriteSize = 0) or (PageSize = 0) or
     (PageSize > SizeOf(DataChunk)) or
     (not SPI95AddressRangeValid(ChipSize, StartAddress,
                                 WriteSize - StartAddress)) then
  begin
    LogPrint(STR_CHECK_SETTINGS);
    OpFail('the chip size, the page size or the range is not usable');
    exit;
  end;

  BytesWrite := 0;
  Address := StartAddress;
  PageSizeTemp := PageSize;
  ProgressReset(WriteSize div PageSize);

  while Address < WriteSize do
  begin
    if not UsbAsp95_WrenChecked(WEL) then
    begin
      OpFail('the SPI EEPROM did not latch write enable (WEL stayed clear)',
             Address);
      Exit;
    end;

    PageSize := SPI95PageChunk(Address, WriteSize - Address, PageSizeTemp);
    if PageSize = 0 then
    begin
      OpFail('the SPI EEPROM page size worked out to zero', Address);
      Exit;
    end;

    FillByte(DataChunk, PageSize, $FF);

    Wrote := UsbAsp95_Write(ChipSize, Address, datachunk, PageSize);
    if Wrote <> PageSize then
    begin
      OpFail(Format('SPI EEPROM short write while erasing: sent %d of %d bytes',
                    [Wrote, PageSize]), Address);
      Exit;
    end;

    if not OpUI.IgnoreBusy then  //ข้ามการตรวจสถานะ
      if not WaitNotBusy95(BUSY_TIMEOUT_SECTOR) then Exit;

    if OpUI.AutoCheck then
    begin
      Got := UsbAsp95_Read(ChipSize, Address, datachunk2, PageSize);
      if Got <> PageSize then
      begin
        OpFail(Format('SPI EEPROM short read after erase: received %d of %d bytes',
                      [Got, PageSize]), Address);
        Exit;
      end;
      for i:=0 to PageSize-1 do
        if DataChunk2[i] <> DataChunk[i] then
        begin
          LogPrint(STR_VERIFY_ERROR+IntToHex(Address+i, 8));
          OpFail('the SPI EEPROM erase did not read back as blank',
                 Address + cardinal(i));
          SetProgressPos(0);
          Exit;
        end;
    end;

    Inc(BytesWrite, PageSize);
    Inc(Address, PageSize);
    ProgressStep(1);
    OpProcessMessages;

    if UserCancel then Break;
  end;

  if BytesWrite <> WriteSize then
    begin
      LogPrint(STR_WRONG_BYTES_WRITE);
      OpFail('the number of bytes written does not match the size asked for');
    end
  else
    LogPrint(STR_DONE);

  SetProgressPos(0);
  end;

begin
  RunOperation(@DoWork);
end;

function EraseFlashKB(chipsize: longword; pagesize: word): integer;
var
  i: integer;
  busy: boolean;
begin
  ProgressReset(chipsize div pagesize);

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

    ProgressStep(1);
  end;

  SetProgressPos(0);
end;

procedure WriteFlashKB(var RomStream: TMemoryStream; StartAddress, WriteSize: cardinal; PageSize: word);
var
  DataChunk: array[0..2047] of byte;
  DataChunk2: array[0..2047] of byte;
  Address, BytesWrite: cardinal;
  busy: boolean;
  SkipPage: boolean;

  //ตัวงานจริง จะรันบน thread เบื้องหลังถ้าเปิดโหมดนั้นไว้
  //ตัวนับลูปต้องเป็นตัวแปรของตัวเอง เพราะ FPC ไม่ยอมให้ใช้ตัวแปร
  //ของโพรซีเยอร์ชั้นนอกมาเป็นตัวนับ for
  procedure DoWork;
  var
    i: integer;
    BusyStarted: QWord;
  begin
  if (WriteSize = 0) or (PageSize = 0) or
     (PageSize > SizeOf(DataChunk)) or
     ((StartAddress mod PageSize) <> 0) or
     ((WriteSize mod PageSize) <> 0) or
     (QWord(StartAddress) + QWord(WriteSize) > QWord(High(cardinal))) or
     (RomStream = nil) or
     (RomStream.Size - RomStream.Position < WriteSize) then
  begin
    LogPrint(STR_CHECK_SETTINGS);
    OpFail('KB writes require a bounded, aligned complete-page buffer');
    exit;
  end;

  if OpUI.AutoCheck then
    LogPrint(STR_WRITING_FLASH_WCHK) else
      LogPrint(STR_WRITING_FLASH);

  BytesWrite := 0;
  Address := StartAddress;
  ProgressReset(WriteSize div PageSize);

  UsbAspMulti_EnableEDI();
  UsbAspMulti_WriteReg($FEA7, $A4); //เปิดสิทธิ์เขียน

  while BytesWrite < WriteSize do
  begin

    //ต้องรีเซ็ตทุกเพจ ตัวแปรมีค่าค้างจากรอบก่อนได้
    SkipPage := False;

    RomStream.ReadBuffer(DataChunk, PageSize);


    //ถ้าทั้งเพจเป็น 00 ก็ไม่ต้องเขียน
    if OpUI.SkipFF then
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

    //A missing chip used to spin forever here.  A per-page deadline keeps the
    //programmer session and cancellation responsive.
    BusyStarted := GetTickCount64;
    repeat
      if UserCancel then Exit;
      busy := UsbAspMulti_Busy();
      if busy and (GetTickCount64 - BusyStarted >= 30000) then
      begin
        OpFail('KB flash stayed busy for more than 30 seconds', Address);
        Exit;
      end;
      if busy then Sleep(1);
    until busy = false;

    BytesWrite := BytesWrite + PageSize;

     if (OpUI.AutoCheck) then
      begin
        for i:=0 to PageSize-1 do
        begin
          UsbAspMulti_Read(Address+i, DataChunk2[0]);
          if DataChunk2[0] <> DataChunk[i] then
          begin
            LogPrint(STR_VERIFY_ERROR+IntToHex(Address+i, 8));
            OpFail('the KB flash byte did not read back as written',
                   Address + cardinal(i));
            SetProgressPos(0);
            Exit;
          end;
        end;
      end;

    Inc(Address, PageSize);
    ProgressStep(1);
    OpProcessMessages;
    if UserCancel then Exit;
  end;

  if BytesWrite <> WriteSize then
    begin
      LogPrint(STR_WRONG_BYTES_WRITE);
      OpFail('the number of bytes written does not match the size asked for');
    end
  else
    LogPrint(STR_DONE);

  SetProgressPos(0);
  end;

begin
  RunOperation(@DoWork);
end;

procedure WriteFlash45(var RomStream: TMemoryStream; StartAddress, ChipSize: cardinal; PageSize: word; WriteType: integer);
var
  DataChunk: array[0..2047] of byte;
  DataChunk2: array[0..2047] of byte;
  PageAddress, BytesWrite: cardinal;

  //ตัวงานจริง จะรันบน thread เบื้องหลังถ้าเปิดโหมดนั้นไว้
  //ตัวนับลูปต้องเป็นตัวแปรของตัวเอง เพราะ FPC ไม่ยอมให้ใช้ตัวแปร
  //ของโพรซีเยอร์ชั้นนอกมาเป็นตัวนับ for
  procedure DoWork;
  var
    i, Wrote, Got: integer;
  begin
  if (StartAddress >= ChipSize) or (ChipSize = 0) or
     (PageSize = 0) or (PageSize > ChipSize) or
     (PageSize > SizeOf(DataChunk)) or
     (WriteType <> WT_PAGE) or (RomStream = nil) or
     (RomStream.Size - RomStream.Position < ChipSize) then
  begin
    LogPrint(STR_CHECK_SETTINGS);
    OpFail('the chip size, the page size or the range is not usable');
    exit;
  end;

  if OpUI.AutoCheck then
    LogPrint(STR_WRITING_FLASH_WCHK) else
      LogPrint(STR_WRITING_FLASH);

  BytesWrite := 0;
  if ((StartAddress mod PageSize) <> 0) or
     ((ChipSize mod PageSize) <> 0) then
  begin
    OpFail('DataFlash writes must be aligned to complete physical pages',
           StartAddress);
    Exit;
  end;

  //ขนาดเพจที่เลือกต้องตรงกับโหมดจริงของชิปก่อนจะเขียนไบต์แรก
  if not Check45Geometry(PageSize, QWord(StartAddress) + QWord(ChipSize)) then
    Exit;

  PageAddress := StartAddress div PageSize;
  ProgressReset(ChipSize div PageSize);

  while BytesWrite < ChipSize do
  begin
    //UsbAsp45_WREN(hUSBDev);
    RomStream.ReadBuffer(DataChunk, PageSize);

    if WriteType = WT_PAGE then
    begin
      Wrote := UsbAsp45_Write(PageAddress, datachunk, PageSize);
      if Wrote <> PageSize then
      begin
        OpFail(Format('DataFlash short write: sent %d of %d bytes',
                      [Wrote, PageSize]), int64(PageAddress) * PageSize);
        Exit;
      end;
    end
    else
    begin
      OpFail('unsupported DataFlash write mode');
      Exit;
    end;

    if not WaitNotBusy45(BUSY_TIMEOUT_PAGE) then Exit;

    if OpUI.AutoCheck then
    begin
      Got := UsbAsp45_Read(PageAddress, datachunk2, PageSize);
      if Got <> PageSize then
      begin
        OpFail(Format('DataFlash short read after program: received %d of %d bytes',
                      [Got, PageSize]), int64(PageAddress) * PageSize);
        Exit;
      end;
      for i:=0 to PageSize-1 do
        if DataChunk2[i] <> DataChunk[i] then
        begin
          LogPrint(STR_VERIFY_ERROR+IntToHex((PageAddress*PageSize )+i, 8));
          OpFail('the DataFlash page did not read back as written',
                 int64(PageAddress) * PageSize + i);
          Exit;
        end;
    end;

    Inc(BytesWrite, PageSize);
    Inc(PageAddress, 1);
    ProgressStep(1);
    OpProcessMessages;
    if UserCancel then Break;
  end;

  if BytesWrite <> ChipSize then
    begin
      LogPrint(STR_WRONG_BYTES_WRITE);
      OpFail('the number of bytes written does not match the size asked for');
    end
  else
    LogPrint(STR_DONE);

  SetProgressPos(0);
  end;

begin
  RunOperation(@DoWork);
end;

procedure ReadFlash25(var RomStream: TMemoryStream; StartAddress, ChipSize: cardinal);
const
  FLASH_SIZE_128MBIT = 16777216;
var
  ChunkSize: Word;
  BytesRead, Got: integer;
  DataChunk: array[0..65534] of byte;
  Address: cardinal;
  ProgressPos: integer;
  OpStarted: TDateTime;
  Use4B, Native4B, FastRead: boolean;
  ReadOp: byte;

  //ตัวงานจริง จะรันบน thread เบื้องหลังถ้าเปิดโหมดนั้นไว้
  procedure DoWork;
  begin
  if (StartAddress >= ChipSize) or (ChipSize = 0) then
  begin
    LogPrint(STR_CHECK_SETTINGS);
    OpFail('the chip size, the page size or the range is not usable');
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

  //ชิปที่มีคำสั่งอ่านชุด 4 ไบต์ของตัวเอง (13h) ไม่ต้องสลับโหมดเลย
  //ใช้กฎเดียวกับทางเขียน ทางลบ และทางตรวจ ทั้งสี่ทางต้องอยู่ในโหมดเดียวกัน
  Use4B := Needs4ByteAddress(StartAddress, ChipSize - StartAddress, ChipSize);
  Native4B := Use4B and Native4BRead;
  if Native4B then
    LogPrint(STR_4B_NATIVE)
  else
    //EN4B ที่ส่งไม่ผ่าน = ชิปยังอยู่โหมด 3 ไบต์ อ่านต่อได้แอดเดรสวนกลับ
    if Use4B then
      if not Enter4B then Exit;

  PickReadOpcode(Native4B, ReadOp, FastRead);
  if FastRead then LogPrint(Format(STR_FAST_READ, [ReadOp]));

  try
  while Address < ChipSize do
  begin
    if ChunkSize > (ChipSize - Address) then ChunkSize := ChipSize - Address;

    Got := ReadData25(ReadOp, FastRead, Use4B, Address, datachunk, ChunkSize);
    if Got <> ChunkSize then
    begin
      OpFail(Format('SPI flash short read: received %d of %d bytes',
                    [Got, ChunkSize]), Address);
      Break;
    end;
    Inc(BytesRead, Got);
    RomStream.WriteBuffer(datachunk, Got);
    Inc(Address, Got);

    Inc(ProgressPos);
    SetProgressPos(ProgressPos);
    ShowSpeed(Address - StartAddress, ChipSize - StartAddress, OpStarted);
    OpProcessMessages;

    if UserCancel then Break;
  end;

  finally
    Leave4B;
  end;

  OpProgress(Address - StartAddress, ChipSize - StartAddress);

  //ที่ต้องอ่านคือส่วนที่เหลือนับจากจุดเริ่ม ไม่ใช่ทั้งชิป
  //เทียบกับ ChipSize ตรง ๆ จะรายงานผิดทุกครั้งที่จุดเริ่มไม่ใช่ศูนย์
  if BytesRead <> integer(ChipSize - StartAddress) then
  begin
    LogPrint(STR_WRONG_BYTES_READ);
    OpFail(Format('read %d bytes but expected %d',
                  [BytesRead, ChipSize - StartAddress]));
  end
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
  BytesRead, Got: integer;
  DataChunk: array[0..2047] of byte;
  Address: cardinal;

  //ตัวงานจริง จะรันบน thread เบื้องหลังถ้าเปิดโหมดนั้นไว้
  procedure DoWork;
  begin
  if (StartAddress >= ChipSize) or (ChipSize = 0) then
  begin
    LogPrint(STR_CHECK_SETTINGS);
    OpFail('the chip size, the page size or the range is not usable');
    exit;
  end;

  ChunkSize := SizeOf(DataChunk);
  if ChunkSize > ChipSize then ChunkSize := ChipSize;

  LogPrint(STR_READING_FLASH);
  BytesRead := 0;
  Address := StartAddress;
  ProgressReset(ChipSize div ChunkSize);

  RomStream.Clear;

  while Address < ChipSize do
  begin
    if ChunkSize > (ChipSize - Address) then ChunkSize := ChipSize - Address;

    Got := UsbAsp95_Read(ChipSize, Address, datachunk, ChunkSize);
    if Got <> ChunkSize then
    begin
      OpFail(Format('SPI EEPROM short read: received %d of %d bytes',
                    [Got, ChunkSize]), Address);
      Break;
    end;
    Inc(BytesRead, Got);
    RomStream.WriteBuffer(datachunk, Got);
    Inc(Address, Got);

    ProgressStep(1);
    OpProcessMessages;

    if UserCancel then Break;
  end;

  if BytesRead <> ChipSize then
    begin
      LogPrint(STR_WRONG_BYTES_READ);
      OpFail('the number of bytes read does not match the size asked for');
    end
  else
    LogPrint(STR_DONE);

  SetProgressPos(0);
  end;

begin
  RunOperation(@DoWork);
end;

procedure ReadFlash45(var RomStream: TMemoryStream; StartAddress, PageSize, ChipSize: cardinal);
var
  ChunkSize: Word;
  BytesRead, Got: integer;
  DataChunk: array[0..2047] of byte;
  Address: cardinal;

  //ตัวงานจริง จะรันบน thread เบื้องหลังถ้าเปิดโหมดนั้นไว้
  procedure DoWork;
  begin
  if (StartAddress >= ChipSize) or (ChipSize = 0) then
  begin
    LogPrint(STR_CHECK_SETTINGS);
    OpFail('the chip size, the page size or the range is not usable');
    exit;
  end;

  //ขนาดเพจที่เลือกต้องตรงกับโหมดจริงของชิป ไม่งั้นทั้ง dump จะเลื่อนตำแหน่ง
  if not Check45Geometry(PageSize, QWord(ChipSize)) then Exit;

  ChunkSize := PageSize;
  if ChunkSize > ChipSize then ChunkSize := ChipSize;

  LogPrint(STR_READING_FLASH);
  BytesRead := 0;
  Address := StartAddress;
  ProgressReset(ChipSize div ChunkSize);

  RomStream.Clear;

  while Address < ChipSize div ChunkSize do
  begin
    if ChunkSize > (ChipSize - Address) then ChunkSize := ChipSize - Address;

    Got := UsbAsp45_Read(Address, datachunk, ChunkSize);
    if Got <> ChunkSize then
    begin
      OpFail(Format('DataFlash short read: received %d of %d bytes',
                    [Got, ChunkSize]), int64(Address) * ChunkSize);
      Break;
    end;
    Inc(BytesRead, Got);
    RomStream.WriteBuffer(datachunk, Got);
    Inc(Address, 1);

    ProgressStep(1);
    OpProcessMessages;

    if UserCancel then Break;
  end;

  if BytesRead <> ChipSize then
    begin
      LogPrint(STR_WRONG_BYTES_READ);
      OpFail('the number of bytes read does not match the size asked for');
    end
  else
    LogPrint(STR_DONE);

  SetProgressPos(0);
  end;

begin
  RunOperation(@DoWork);
end;

procedure ReadFlashKB(var RomStream: TMemoryStream; StartAddress, ChipSize: cardinal);
var
  ChunkSize: byte;
  BytesRead, Got: integer;
  DataChunk: byte;
  Address: cardinal;

  //ตัวงานจริง จะรันบน thread เบื้องหลังถ้าเปิดโหมดนั้นไว้
  procedure DoWork;
  begin
  if (StartAddress >= ChipSize) or (ChipSize = 0) then
  begin
    LogPrint(STR_CHECK_SETTINGS);
    OpFail('the chip size, the page size or the range is not usable');
    exit;
  end;

  ChunkSize := SizeOf(DataChunk);
  if ChunkSize > ChipSize then ChunkSize := ChipSize;

  LogPrint(STR_READING_FLASH);
  BytesRead := 0;
  Address := StartAddress;
  ProgressReset(ChipSize div ChunkSize);

  UsbAspMulti_EnableEDI();

  RomStream.Clear;

  while Address < ChipSize do
  begin
    if ChunkSize > (ChipSize - Address) then ChunkSize := ChipSize - Address;

    Got := UsbAspMulti_Read(Address, datachunk);
    if Got <> ChunkSize then
    begin
      OpFail(Format('KB flash short read: received %d of %d bytes',
                    [Got, ChunkSize]), Address);
      Break;
    end;
    Inc(BytesRead, Got);
    RomStream.WriteBuffer(datachunk, Got);
    Inc(Address, ChunkSize);

    ProgressStep(1);
    OpProcessMessages;

    if UserCancel then Break;
  end;

  if BytesRead <> ChipSize then
    begin
      LogPrint(STR_WRONG_BYTES_READ);
      OpFail('the number of bytes read does not match the size asked for');
    end
  else
    LogPrint(STR_DONE);

  SetProgressPos(0);
  end;

begin
  RunOperation(@DoWork);
end;


procedure VerifyFlash25(var RomStream: TMemoryStream; StartAddress, DataSize: cardinal);
const
  FLASH_SIZE_128MBIT = 16777216;
var
  ChunkSize: Word;
  BytesRead, Got: integer;
  DataChunk: array[0..16786] of byte;
  DataChunkFile: array[0..16786] of byte;
  Address: cardinal;
  ProgressPos: integer;
  OpStarted: TDateTime;
  Use4B, Native4B, FastRead: boolean;
  ReadOp: byte;

  //ตัวงานจริง จะรันบน thread เบื้องหลังถ้าเปิดโหมดนั้นไว้
  //ตัวนับลูปต้องเป็นตัวแปรในตัวเอง เพราะ FPC ไม่ยอมให้ใช้ตัวแปร
  //ของโพรซีเยอร์ชั้นนอกมาเป็นตัวนับ for
  procedure DoWork;
  var
    i, j, kk, ChunkCount: integer;
    Order: array of cardinal;
    Seed: cardinal;
    TIdx: cardinal;
    Off: QWord;
    Len: cardinal;
    StreamBase: int64;
  begin
  if (DataSize = 0) then
  begin
    LogPrint(STR_CHECK_SETTINGS);
    OpFail('the chip size, the page size or the range is not usable');
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
  StreamBase := RomStream.Position;

  //รีเซ็ตแบบ JEDEC (66h/99h) ก่อนรอบตรวจ: สิ่งที่เทียบต้องเป็นเนื้อ array
  //จริง ไม่ใช่สถานะหรือบัฟเฟอร์ค้างของอุปกรณ์ และโหมดค้างที่งานก่อนหน้า
  //ทิ้งไว้ก็ถูกล้างไปด้วย ชิปที่ไม่รู้จักคำสั่งนี้จะเมินมันอย่างปลอดภัย
  UsbAsp25_SoftReset;
  Sleep(1);

  //ชิปที่มีคำสั่งอ่านชุด 4 ไบต์ของตัวเอง (13h) ไม่ต้องสลับโหมดเลย
  //
  //ตัดสินจากขนาดชิปกับแอดเดรสที่จะแตะ ไม่ใช่ขนาดของบัฟเฟอร์ที่เอามาเทียบ
  //เดิมใช้ DataSize ซึ่งพลาดแบบเดียวกับทางเขียนเป๊ะ ๆ ผลคือรอบตรวจไปอ่าน
  //แอดเดรสที่วนกลับมาแล้วเทียบผ่าน ซึ่งแย่กว่าไม่ตรวจเลย เพราะมันยืนยัน
  //ความเสียหายว่าถูกต้อง
  Use4B := Needs4ByteAddress(StartAddress, DataSize, OpUI.ChipSize);
  Native4B := Use4B and Native4BRead;
  //EN4B ที่ส่งไม่ผ่าน = อ่านกลับมาเทียบคนละแอดเดรส ผลตรวจเชื่อไม่ได้เลย
  if (not Native4B) and Use4B then
    if not Enter4B then Exit;

  PickReadOpcode(Native4B, ReadOp, FastRead);

  //ตรวจแบบสลับลำดับก้อน: อุปกรณ์หรือชิปที่สะท้อนข้อมูลที่เพิ่งผ่านมือ
  //(บัฟเฟอร์อ่านล่วงหน้า สถานะค้าง) ผ่านการตรวจแบบไล่เรียงได้สบาย ๆ
  //แต่ผ่านลำดับสุ่มไม่ได้ ลำดับมาจาก LCG ค่าตายตัว ผลจึงทำซ้ำได้เสมอ
  ChunkCount := integer((QWord(DataSize) + ChunkSize - 1) div ChunkSize);
  SetLength(Order, ChunkCount);
  for i := 0 to ChunkCount - 1 do Order[i] := cardinal(i);
  Seed := $02C7E5A1;
  for i := ChunkCount - 1 downto 1 do
  begin
    Seed := Seed * 1103515245 + 12345;
    j := integer((Seed shr 16) mod cardinal(i + 1));
    TIdx := Order[i];
    Order[i] := Order[j];
    Order[j] := TIdx;
  end;

  try
  for kk := 0 to ChunkCount - 1 do
  begin
    Off := QWord(Order[kk]) * ChunkSize;
    Len := ChunkSize;
    if Off + Len > DataSize then Len := cardinal(DataSize - Off);
    Address := StartAddress + cardinal(Off);

    Got := ReadData25(ReadOp, FastRead, Use4B, Address, datachunk,
                      integer(Len));
    if Got <> integer(Len) then
    begin
      OpFail(Format('SPI flash short read during verify: received %d of %d bytes',
                    [Got, Len]), Address);
      Exit;
    end;
    Inc(BytesRead, Got);

    RomStream.Position := StreamBase + int64(Off);
    RomStream.ReadBuffer(DataChunkFile, Len);

    for i := 0 to integer(Len) - 1 do
    if DataChunk[i] <> DataChunkFile[i] then
    begin
      LogPrint(STR_VERIFY_ERROR+IntToHex(Address+cardinal(i), 8));
      OpFail('the chip does not match the buffer', Address + cardinal(i));
      SetProgressPos(0);
      Exit;
    end;

    Inc(ProgressPos);
    SetProgressPos(ProgressPos);
    ShowSpeed(cardinal(BytesRead), DataSize, OpStarted);
    OpProcessMessages;

    if UserCancel then Break;
  end;

  finally
    Leave4B;
  end;

  OpProgress(cardinal(BytesRead), DataSize);

  if (BytesRead <> DataSize) then
  begin
    LogPrint(STR_WRONG_BYTES_READ);
    OpFail(Format('read %d bytes but expected %d', [BytesRead, DataSize]));
  end
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
  BytesRead, Got: integer;
  DataChunk: array[0..2047] of byte;
  DataChunkFile: array[0..2047] of byte;
  Address: cardinal;

  //ตัวงานจริง จะรันบน thread เบื้องหลังถ้าเปิดโหมดนั้นไว้
  //ตัวนับลูปต้องเป็นตัวแปรของตัวเอง เพราะ FPC ไม่ยอมให้ใช้ตัวแปร
  //ของโพรซีเยอร์ชั้นนอกมาเป็นตัวนับ for
  procedure DoWork;
  var
    i: integer;
  begin
  if (DataSize = 0) then
  begin
    LogPrint(STR_CHECK_SETTINGS);
    OpFail('the chip size, the page size or the range is not usable');
    exit;
  end;

  ChunkSize := SizeOf(DataChunk);
  if ChunkSize > DataSize then ChunkSize := DataSize;

  LogPrint(STR_VERIFY);
  BytesRead := 0;
  Address := StartAddress;
  ProgressReset(DataSize div ChunkSize);

  while (Address-StartAddress) < DataSize do
  begin
    if ChunkSize > (DataSize - (Address-StartAddress)) then ChunkSize := DataSize - (Address-StartAddress);

    Got := UsbAsp95_Read(ChipSize, Address, datachunk, ChunkSize);
    if Got <> ChunkSize then
    begin
      OpFail(Format('SPI EEPROM short read during verify: received %d of %d bytes',
                    [Got, ChunkSize]), Address);
      Exit;
    end;
    Inc(BytesRead, Got);
    RomStream.ReadBuffer(DataChunkFile, ChunkSize);

    for i := 0 to ChunkSize -1 do
    if DataChunk[i] <> DataChunkFile[i] then
    begin
      LogPrint(STR_VERIFY_ERROR+IntToHex(Address+i, 8));
      OpFail('the SPI EEPROM does not match the buffer',
             Address + cardinal(i));
      SetProgressPos(0);
      Exit;
    end;

    Inc(Address, ChunkSize);

    ProgressStep(1);
    OpProcessMessages;

    if UserCancel then Break;
  end;

  if (BytesRead <> DataSize) then
    begin
      LogPrint(STR_WRONG_BYTES_READ);
      OpFail('the number of bytes read does not match the size asked for');
    end
  else
    LogPrint(STR_DONE);

  SetProgressPos(0);
  end;

begin
  RunOperation(@DoWork);
end;

procedure VerifyFlash45(var RomStream: TMemoryStream; StartAddress, PageSize, ChipSize: cardinal);
var
  ChunkSize: Word;
  BytesRead, Got: integer;
  DataChunk: array[0..2047] of byte;
  DataChunkFile: array[0..2047] of byte;
  PageAddress: cardinal;

  //ตัวงานจริง จะรันบน thread เบื้องหลังถ้าเปิดโหมดนั้นไว้
  //ตัวนับลูปต้องเป็นตัวแปรของตัวเอง เพราะ FPC ไม่ยอมให้ใช้ตัวแปร
  //ของโพรซีเยอร์ชั้นนอกมาเป็นตัวนับ for
  procedure DoWork;
  var
    i: integer;
  begin
  if (StartAddress >= ChipSize) or (ChipSize = 0) then
  begin
    LogPrint(STR_CHECK_SETTINGS);
    OpFail('the chip size, the page size or the range is not usable');
    exit;
  end;

  //ขนาดเพจที่เลือกต้องตรงกับโหมดจริงของชิป ไม่งั้น verify เทียบผิดตำแหน่งหมด
  if not Check45Geometry(PageSize, QWord(ChipSize)) then Exit;

  ChunkSize := PageSize;
  if ChunkSize > ChipSize then ChunkSize := ChipSize;

  LogPrint(STR_VERIFY);
  BytesRead := 0;
  PageAddress := StartAddress;
  ProgressReset(ChipSize div ChunkSize);

  while PageAddress < ChipSize div ChunkSize do
  begin
    //if ChunkSize > (ChipSize - Address) then ChunkSize := ChipSize - Address;

    Got := UsbAsp45_Read(PageAddress, datachunk, ChunkSize);
    if Got <> ChunkSize then
    begin
      OpFail(Format('DataFlash short read during verify: received %d of %d bytes',
                    [Got, ChunkSize]), int64(PageAddress) * ChunkSize);
      Exit;
    end;
    Inc(BytesRead, Got);
    RomStream.ReadBuffer(DataChunkFile, ChunkSize);

    for i := 0 to ChunkSize -1 do
    if DataChunk[i] <> DataChunkFile[i] then
    begin
      LogPrint(STR_VERIFY_ERROR+IntToHex((PageAddress*ChunkSize)+i, 8));
      OpFail('the DataFlash does not match the buffer',
             int64(PageAddress) * ChunkSize + i);
      SetProgressPos(0);
      Exit;
    end;

    Inc(PageAddress, 1);

    ProgressStep(1);
    OpProcessMessages;

    if UserCancel then Break;
  end;

  if (BytesRead <> ChipSize) then
    begin
      LogPrint(STR_WRONG_BYTES_READ);
      OpFail('the number of bytes read does not match the size asked for');
    end
  else
    LogPrint(STR_DONE);

  SetProgressPos(0);
  end;

begin
  RunOperation(@DoWork);
end;

procedure VerifyFlashMW(var RomStream: TMemoryStream; AddrBitLen: byte; StartAddress, ChipSize: cardinal);
var
  ChunkSize: Word;
  BytesRead, Got: integer;
  DataChunk: array[0..2047] of byte;
  DataChunkFile: array[0..2047] of byte;
  Address: cardinal;

  //ตัวงานจริง จะรันบน thread เบื้องหลังถ้าเปิดโหมดนั้นไว้
  //ตัวนับลูปต้องเป็นตัวแปรของตัวเอง เพราะ FPC ไม่ยอมให้ใช้ตัวแปร
  //ของโพรซีเยอร์ชั้นนอกมาเป็นตัวนับ for
  procedure DoWork;
  var
    i: integer;
  begin
  if (StartAddress >= ChipSize) or (ChipSize = 0) then
  begin
    LogPrint(STR_CHECK_SETTINGS);
    OpFail('the chip size, the page size or the range is not usable');
    exit;
  end;

  ChunkSize := 2;
  if ChunkSize > ChipSize then ChunkSize := ChipSize;

  LogPrint(STR_VERIFY);
  BytesRead := 0;
  Address := StartAddress;
  ProgressReset(ChipSize div ChunkSize);

  while Address < ChipSize div 2 do
  begin
    Got := UsbAspMW_Read(AddrBitLen, Address, datachunk, ChunkSize);
    if Got <> ChunkSize then
    begin
      OpFail(Format('MicroWire short read during verify: received %d of %d bytes',
                    [Got, ChunkSize]), int64(Address) * 2);
      Exit;
    end;
    Inc(BytesRead, Got);
    RomStream.ReadBuffer(DataChunkFile, ChunkSize);

    for i := 0 to ChunkSize -1 do
    if DataChunk[i] <> DataChunkFile[i] then
    begin
      LogPrint(STR_VERIFY_ERROR+IntToHex(Address+i, 8));
      OpFail('the MicroWire EEPROM does not match the buffer',
             int64(Address) * 2 + i);
      SetProgressPos(0);
      Exit;
    end;

    Inc(Address, ChunkSize div 2);

    ProgressStep(2);
    OpProcessMessages;
    if UserCancel then Break;
  end;

  if (BytesRead <> ChipSize) then
    begin
      LogPrint(STR_WRONG_BYTES_READ);
      OpFail('the number of bytes read does not match the size asked for');
    end
  else
    LogPrint(STR_DONE);

  SetProgressPos(0);
  end;

begin
  RunOperation(@DoWork);
end;

procedure VerifyFlashKB(var RomStream: TMemoryStream; StartAddress, ChipSize: cardinal);
var
  ChunkSize: byte;
  BytesRead, Got: integer;
  DataChunk: byte;
  DataChunkFile: byte;
  Address: cardinal;

  //ตัวงานจริง จะรันบน thread เบื้องหลังถ้าเปิดโหมดนั้นไว้
  procedure DoWork;
  begin
  if (StartAddress >= ChipSize) or (ChipSize = 0) then
  begin
    LogPrint(STR_CHECK_SETTINGS);
    OpFail('the chip size, the page size or the range is not usable');
    exit;
  end;

  ChunkSize := SizeOf(DataChunk);
  if ChunkSize > ChipSize then ChunkSize := ChipSize;

  LogPrint(STR_VERIFY);
  BytesRead := 0;
  Address := StartAddress;
  ProgressReset(ChipSize div ChunkSize);

  UsbAspMulti_EnableEDI();
  UsbAspMulti_WriteReg($FEAD, $08); //เปิดใช้งานแฟลช

  //RomStream.Clear;

  while Address < ChipSize do
  begin
    if ChunkSize > (ChipSize - Address) then ChunkSize := ChipSize - Address;

    Got := UsbAspMulti_Read(Address, datachunk);
    if Got <> ChunkSize then
    begin
      OpFail(Format('KB flash short read during verify: received %d of %d bytes',
                    [Got, ChunkSize]), Address);
      Exit;
    end;
    Inc(BytesRead, Got);
    RomStream.ReadBuffer(DataChunkFile, ChunkSize);

    if DataChunk <> DataChunkFile then
    begin
      LogPrint(STR_VERIFY_ERROR+IntToHex(Address, 8));
      OpFail('the KB flash does not match the buffer', Address);
      SetProgressPos(0);
      Exit;
    end;

    Inc(Address, ChunkSize);

    ProgressStep(1);
    OpProcessMessages;

    if UserCancel then Break;
  end;

  if BytesRead <> ChipSize then
    begin
      LogPrint(STR_WRONG_BYTES_READ);
      OpFail('the number of bytes read does not match the size asked for');
    end
  else
    LogPrint(STR_DONE);

  SetProgressPos(0);
  end;

begin
  RunOperation(@DoWork);
end;

procedure ReadFlashI2C(var RomStream: TMemoryStream; StartAddress, ChipSize: cardinal; ChunkSize: Word; DevAddr: byte);
var
  BytesRead, Got: integer;
  DataChunk: array[0..255] of byte;
  Address: cardinal;

  //ตัวงานจริง จะรันบน thread เบื้องหลังถ้าเปิดโหมดนั้นไว้
  procedure DoWork;
  begin
  if ChipSize = 0 then
  begin
    LogPrint(STR_CHECK_SETTINGS);
    OpFail('the chip size, the page size or the range is not usable');
    exit;
  end;

  if ChunkSize > SizeOf(DataChunk) then ChunkSize := SizeOf(DataChunk);
  if ChunkSize < 1 then ChunkSize := 1;
  if ChunkSize > ChipSize then ChunkSize := ChipSize;

  LogPrint(STR_READING_FLASH);
  BytesRead := 0;
  Address := StartAddress;
  ProgressReset(ChipSize div ChunkSize);

  RomStream.Clear;

  while Address < ChipSize do
  begin
    if ChunkSize > (ChipSize - Address) then ChunkSize := ChipSize - Address;

    Got := UsbAspI2C_Read(DevAddr, OpUI.I2CAddrType, Address,
                         datachunk, ChunkSize);
    if Got <> ChunkSize then
    begin
      OpFail(Format('I2C EEPROM short read: received %d of %d bytes',
                    [Got, ChunkSize]), Address);
      Break;
    end;
    Inc(BytesRead, Got);
    RomStream.WriteBuffer(DataChunk, Got);
    Inc(Address, Got);

    ProgressStep(1);
    OpProcessMessages;
    if UserCancel then Break;
  end;

  if BytesRead <> integer(ChipSize - StartAddress) then
  begin
    LogPrint(STR_WRONG_BYTES_READ);
    OpFail(Format('read %d bytes but expected %d',
                  [BytesRead, ChipSize - StartAddress]));
  end
  else
    LogPrint(STR_DONE);

  SetProgressPos(0);
  end;

begin
  RunOperation(@DoWork);
end;

procedure WriteFlashI2C(var RomStream: TMemoryStream; StartAddress, WriteSize: cardinal; PageSize: word; DevAddr: byte);
var
  DataChunk: array[0..2047] of byte;
  Address, BytesWrite: cardinal;
  PageSizeTemp: word;

  //ตัวงานจริง จะรันบน thread เบื้องหลังถ้าเปิดโหมดนั้นไว้
  procedure DoWork;
  var
    Wrote: integer;
    BusAddr: TI2CAddr;
  begin
  if (WriteSize = 0) or (PageSize = 0) or
     (PageSize > SizeOf(DataChunk)) or
     (WriteSize > High(integer)) or
     (not I2CAddressRangeValid(OpUI.I2CAddrType, StartAddress,
                               integer(WriteSize))) or
     (RomStream = nil) or
     (RomStream.Size - RomStream.Position < WriteSize) then
  begin
    LogPrint(STR_CHECK_SETTINGS);
    OpFail('the I2C write buffer, page size, or address range is invalid');
    exit;
  end;

  PageSizeTemp := PageSize;
  LogPrint(STR_WRITING_FLASH);
  BytesWrite := 0;
  Address := StartAddress;
  ProgressReset(WriteSize div PageSize);

  while (Address-StartAddress) < WriteSize do
  begin
    //คำนวณขนาดบัฟเฟอร์เพจแรก กันไม่ให้บัฟเฟอร์วนกลับเมื่อชนขอบแอดเดรส
    //
    //สูตรเดิมคือ (ขนาดชิป - แอดเดรสเริ่ม) mod PageSize ซึ่งคืน 0 ทุกครั้งที่
    //แอดเดรสเริ่มตรงขอบเพจพอดี เช่นเริ่มที่ 0x1000 บนชิป 32KB เพจ 64 ไบต์
    //ได้ 28672 mod 64 = 0 แล้ว PageSize เป็นศูนย์ Address ไม่ขยับ
    //ลูปวนไม่รู้จบจนกว่าผู้ใช้จะกดยกเลิก
    //
    //เป็นบั๊กตัวเดียวกับที่แก้ไปแล้วในทางของ SPI เมื่อรุ่น 4.3.1 แต่ทาง I2C
    //ยังคัดลอกสูตรเดิมไว้ FirstChunkSize เขียนและมีเทสต์อยู่แล้วตั้งแต่ตอนนั้น
    if (StartAddress > 0) and (Address = StartAddress) and (PageSizeTemp > 1) then
      PageSize := FirstChunkSize(StartAddress, PageSizeTemp)
    else
      PageSize := PageSizeTemp;

    if (WriteSize - (Address-StartAddress)) < PageSize then PageSize := (WriteSize - (Address-StartAddress));

    //กันไว้อีกชั้น แอดเดรสที่ไม่ขยับคือลูปที่ไม่มีวันจบ
    if PageSize = 0 then
    begin
      LogPrint(STR_CHECK_SETTINGS);
      OpFail('the page size worked out to zero, refusing to loop forever',
             Address);
      Break;
    end;

    RomStream.ReadBuffer(DataChunk, PageSize);
    if not BuildI2CAddr(DevAddr, OpUI.I2CAddrType, Address, BusAddr) then
    begin
      OpFail('the I2C address mode is invalid', Address);
      Break;
    end;
    Wrote := UsbAspI2C_Write(DevAddr, OpUI.I2CAddrType, Address,
                             datachunk, PageSize);
    if Wrote <> PageSize then
    begin
      OpFail(Format('I2C EEPROM short write: sent %d of %d bytes',
                    [Wrote, PageSize]), Address);
      Break;
    end;
    Inc(BytesWrite, Wrote);
    Inc(Address, PageSize);

    if not UsbAspI2C_WaitReady(BusAddr.DevByte, I2C_WRITE_CYCLE_MS) then
    begin
      LogPrint(STR_I2C_NO_ANSWER);
      OpFail('the chip stopped acknowledging during the write cycle', Address);
      Break;
    end;

    ProgressStep(1);
    OpProcessMessages;
    if UserCancel then Break;
  end;

  if BytesWrite <> WriteSize then
  begin
    LogPrint(STR_WRONG_BYTES_WRITE);
    OpFail(Format('wrote %d bytes but the buffer holds %d',
                  [BytesWrite, WriteSize]));
  end
  else
    LogPrint(STR_DONE);

  SetProgressPos(0);
  end;

begin
  RunOperation(@DoWork);
end;

//EndAddr คือแอดเดรสถัดจากไบต์สุดท้ายที่จะถูกลบ
//
//เดิมพารามิเตอร์ตัวนี้ชื่อ WriteSize เหมือนของ WriteFlashI2C แต่ถูกใช้เป็น
//แอดเดรสสิ้นสุด ไม่ใช่ความยาว สองตัวนี้ต่างกันทันทีที่จุดเริ่มไม่ใช่ศูนย์
//ชื่อที่โกหกแบบนี้คือรอให้ผู้เรียกรายถัดไปส่งค่าผิดชนิดเข้ามา
procedure EraseFlashI2C(StartAddress, EndAddr: cardinal; PageSize: word; DevAddr: byte);
var
  DataChunk: array[0..2047] of byte;
  Address, BytesWrite, Expected: cardinal;

  //ตัวงานจริง จะรันบน thread เบื้องหลังถ้าเปิดโหมดนั้นไว้
  procedure DoWork;
  var
    Wrote: integer;
    Chunk: cardinal;
    BusAddr: TI2CAddr;
  begin
  if (StartAddress >= EndAddr) or (EndAddr = 0) or (PageSize = 0) or
     (PageSize > SizeOf(DataChunk)) or
     (EndAddr - StartAddress > High(integer)) or
     (not I2CAddressRangeValid(OpUI.I2CAddrType, StartAddress,
                               integer(EndAddr - StartAddress))) then
  begin
    LogPrint(STR_CHECK_SETTINGS);
    OpFail('the erase range or the page size is empty');
    exit;
  end;

  LogPrint(STR_ERASING_FLASH);
  BytesWrite := 0;
  Address := StartAddress;
  Expected := EndAddr - StartAddress;
  ProgressReset(Expected div PageSize);

  while Address < EndAddr do
  begin
    //ก้อนแรกต้องจบที่ขอบเพจของตัวชิป: จุดเริ่มที่ไม่ตรงเพจ ถ้ายิงเต็มเพจ
    //ปลายก้อนจะวนกลับในบัฟเฟอร์เพจ แล้วไบต์ที่อยู่ต่ำกว่าช่วงที่ขอจะถูกลบ
    //ไปด้วยโดยไม่มีใครขอ (WriteFlashI2C แก้เรื่องเดียวกันด้วย FirstChunkSize)
    Chunk := PageSize - (Address mod PageSize);
    if (EndAddr - Address) < Chunk then Chunk := EndAddr - Address;
    if Chunk = 0 then Break;

    FillByte(DataChunk, Chunk, $FF);
    if not BuildI2CAddr(DevAddr, OpUI.I2CAddrType, Address, BusAddr) then
    begin
      OpFail('the I2C address mode is invalid', Address);
      Break;
    end;
    Wrote := UsbAspI2C_Write(DevAddr, OpUI.I2CAddrType, Address,
                             datachunk, Chunk);
    if Wrote <> integer(Chunk) then
    begin
      OpFail(Format('I2C EEPROM short write while erasing: sent %d of %d bytes',
                    [Wrote, Chunk]), Address);
      Break;
    end;
    Inc(BytesWrite, Wrote);
    Inc(Address, Chunk);

    if not UsbAspI2C_WaitReady(BusAddr.DevByte, I2C_WRITE_CYCLE_MS) then
    begin
      LogPrint(STR_I2C_NO_ANSWER);
      OpFail('the chip stopped acknowledging during the write cycle', Address);
      Break;
    end;

    ProgressStep(1);
    OpProcessMessages;
    if UserCancel then Break;
  end;

  if BytesWrite <> Expected then
  begin
    LogPrint(STR_WRONG_BYTES_WRITE);
    OpFail(Format('erased %d bytes but the range covers %d',
                  [BytesWrite, Expected]));
  end
  else
    LogPrint(STR_DONE);

  SetProgressPos(0);
  end;

begin
  RunOperation(@DoWork);
end;

procedure VerifyFlashI2C(var RomStream: TMemoryStream; StartAddress, DataSize: cardinal; ChunkSize: Word; DevAddr: byte);
var
  BytesRead, Got: integer;
  DataChunk: array[0..2047] of byte;
  DataChunkFile: array[0..2047] of byte;
  Address: cardinal;

  //ตัวงานจริง จะรันบน thread เบื้องหลังถ้าเปิดโหมดนั้นไว้
  //ตัวนับลูปต้องเป็นตัวแปรของตัวเอง เพราะ FPC ไม่ยอมให้ใช้ตัวแปร
  //ของโพรซีเยอร์ชั้นนอกมาเป็นตัวนับ for
  procedure DoWork;
  var
    i: integer;
  begin
  if (DataSize = 0) then
  begin
    LogPrint(STR_CHECK_SETTINGS);
    OpFail('the chip size, the page size or the range is not usable');
    exit;
  end;

  if ChunkSize > SizeOf(DataChunk) then ChunkSize := SizeOf(DataChunk);
  if ChunkSize < 1 then ChunkSize := 1;
  if ChunkSize > DataSize then ChunkSize := DataSize;

  LogPrint(STR_VERIFY);
  BytesRead := 0;
  Address := StartAddress;
  ProgressReset(DataSize div ChunkSize);

  while (Address-StartAddress) < DataSize do
  begin
    if ChunkSize > (DataSize - (Address - StartAddress)) then ChunkSize := DataSize -(Address - StartAddress) ;

    Got := UsbAspI2C_Read(DevAddr, OpUI.I2CAddrType, Address,
                         datachunk, ChunkSize);
    if Got <> ChunkSize then
    begin
      OpFail(Format('I2C EEPROM short read during verify: received %d of %d bytes',
                    [Got, ChunkSize]), Address);
      Exit;
    end;
    Inc(BytesRead, Got);
    RomStream.ReadBuffer(DataChunkFile, ChunkSize);

    for i := 0 to ChunkSize -1 do
    if DataChunk[i] <> DataChunkFile[i] then
    begin
      LogPrint(STR_VERIFY_ERROR+IntToHex(Address+i, 8));
      OpFail('the chip does not match the buffer', Address + cardinal(i));
      SetProgressPos(0);
      Exit;
    end;

    Inc(Address, ChunkSize);

    ProgressStep(1);
    OpProcessMessages;
    if UserCancel then Break;
  end;

  if (BytesRead <> DataSize) then
  begin
    LogPrint(STR_WRONG_BYTES_READ);
    OpFail(Format('read %d bytes but expected %d', [BytesRead, DataSize]));
  end
  else
    LogPrint(STR_DONE);

  SetProgressPos(0);
  end;

begin
  RunOperation(@DoWork);
end;

procedure SelectHW(programmer: THardwareList);
begin
  //เมนู Buzzpirat กับรายการพอร์ต COM ใช้เฉพาะกับเครื่องที่คุยผ่านพอร์ตอนุกรม
  //ถ้าใช้ CH341/CH347/FT232H อยู่ก็ไม่ต้องมีให้เกะกะ
  MainForm.MenuBuzzpirat.Visible := programmer = CHW_BUZZPIRAT;
  MainForm.ListcomportsMenuItem.Visible :=
    programmer in [CHW_BUZZPIRAT, CHW_ARDUINO, CHW_SERPROG];

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

  if programmer = CHW_EZP then
  begin
    //ความเร็วอยู่ในแพ็กเก็ตบอกชิป ไม่มีเมนูฝั่งนี้ และเครื่องนี้ทำ SPI
    //อย่างเดียวเท่าที่เราต่อไว้
    MainForm.MenuSPIClock.Visible:= false;
    MainForm.MenuCH347SPIClock.Visible:= false;
    MainForm.MenuAVRISPSPIClock.Visible:= false;
    MainForm.MenuArduinoSPIClock.Visible:= false;
    MainForm.MenuFT232SPIClock.Visible:= false;
    MainForm.MenuMicrowire.Enabled:= false;
    AsProgrammer.Current_HW := CHW_EZP;
  end;

  if programmer = CHW_SERPROG then
  begin
    //ความถี่อยู่ในมือเฟิร์มแวร์ของบอร์ด ไม่มีเมนูให้เลือกฝั่งนี้
    MainForm.MenuSPIClock.Visible:= false;
    MainForm.MenuCH347SPIClock.Visible:= false;
    MainForm.MenuAVRISPSPIClock.Visible:= false;
    MainForm.MenuArduinoSPIClock.Visible:= false;
    MainForm.MenuFT232SPIClock.Visible:= false;
    MainForm.MenuMicrowire.Enabled:= false;
    AsProgrammer.Current_HW := CHW_SERPROG;
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

  //กล่องเลือกแรงดันบนหน้าหลักผูกกับ CH347 เท่านั้น โผล่และหุบตามเครื่องที่เลือก
  RefreshCH347VccPanel;
end;

//ไล่เปิดอุปกรณ์ทีละตัว เพื่อดูว่ามีเครื่องโปรแกรมตัวไหนเสียบอยู่จริง
//ข้ามพวกที่ใช้พอร์ตอนุกรม เพราะการไล่เปิดพอร์ตมั่ว ๆ จะไปกวนอุปกรณ์อื่น
//EZP ใช้แค่ enumerate VID/PID ไม่เปิด handle จึงไม่รบกวนงานของโปรแกรมอื่น
function ProbeProgrammer(out Found: THardwareList): boolean;
const
  Candidates: array[0..5] of THardwareList =
    (CHW_CH341, CHW_CH347, CHW_FT232H, CHW_USBASP, CHW_AVRISP, CHW_EZP);
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
    if (Candidates[i] = CHW_EZP) and EZPDevicePresent then
    begin
      Found := Candidates[i];
      AsProgrammer.Current_HW := Saved;
      Exit(True);
    end
    else if (Candidates[i] <> CHW_EZP) and
            AsProgrammer.Programmer.DevOpen then
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
  MainForm.MenuHWSERPROG.Checked   := HW = CHW_SERPROG;
  MainForm.MenuHWEZP.Checked       := HW = CHW_EZP;
end;

//เช็คว่ามีเครื่องโปรแกรมต่ออยู่ไหม ถ้าตัวที่เลือกไว้หายไปและเปิดโหมดค้นหาอัตโนมัติ
//ก็สลับไปใช้ตัวที่เจอแทน
procedure PollProgrammer(Announce: boolean; StartupScan: boolean);
var
  Present, Was: boolean;
  Found: THardwareList;
begin
  if OperationRunning then Exit;

  Was := ProgrammerPresent;

  //ตอนเริ่มโปรแกรมต้องค้นจริงแม้ค่าที่จำไว้เป็น serial backend มิฉะนั้น
  //ค่าปริยาย Buzzpirat จะถูกนับว่า "มีอยู่" และตัดทาง auto-detect ทั้งหมด
  if StartupScan and MainForm.MenuAutoDetectHW.Checked and
     ProbeProgrammer(Found) then
  begin
    SelectHW(Found);
    SetHardwareMenuCheck(Found);
    Present := True;
    LogPrint(STR_HW_SWITCHED + AsProgrammer.Programmer.HardwareName);
  end
  //อุปกรณ์ serial ไม่เอามาวนเช็ค เพราะจะไปจับพอร์ตทิ้งขว้างตลอดเวลา
  else if AsProgrammer.Current_HW in
          [CHW_ARDUINO, CHW_BUZZPIRAT, CHW_SERPROG] then
    Present := True
  //EZP ตรวจ presence จากรายการ USB เท่านั้น ไม่เปิดหรือ claim ตัวเครื่อง
  else if AsProgrammer.Current_HW = CHW_EZP then
    Present := EZPDevicePresent
  else
  begin
    Present := AsProgrammer.Programmer.DevOpen;
    if Present then AsProgrammer.Programmer.DevClose;
  end;

  if (not Present) and MainForm.MenuAutoDetectHW.Checked then
    if ProbeProgrammer(Found) then
    begin
      SelectHW(Found);
      SetHardwareMenuCheck(Found);
      Present := True;
      LogPrint(STR_HW_SWITCHED + AsProgrammer.Programmer.HardwareName);
    end;

  ProgrammerPresent := Present;

  //ถอดหรือเสียบเครื่องโปรแกรม แปลว่าซ็อกเก็ตอาจมีชิปคนละตัวแล้ว
  //สิ่งที่รู้เกี่ยวกับชิปตัวเก่าต้องทิ้ง ไม่งั้นจะส่ง opcode ของยี่ห้อที่ไม่ใช่
  if Was <> ProgrammerPresent then
  begin
    Reset25ChipHints;
    ForgetSFDP;
    LastChipUID := '';
    LastID9F := '';
    //ตัวตนที่เคยยืนยันไว้และความรู้เรื่องเนื้อในชิป เป็นของซ็อกเก็ตรอบก่อน
    ForgetChipKnowledge;
  end;

  //พูดเฉพาะตอนสถานะเปลี่ยน ไม่งั้น log จะเต็มไปด้วยข้อความซ้ำทุกสามวินาที
  if Announce or (Was <> ProgrammerPresent) then
  begin
    if ProgrammerPresent then
      LogPrint(STR_HW_CONNECTED + AsProgrammer.Programmer.HardwareName)
    else
      LogPrint(STR_HW_DISCONNECTED);
  end;

  MainForm.ChipView.Invalidate;
  MainForm.UpdateWorkflowState;

  //เพิ่งเสียบเครื่องโปรแกรมเข้ามา ก็ถามชิปในซ็อกเก็ตให้เลย ไม่ต้องรอให้กด Read ID
  //ทำเฉพาะจังหวะที่สถานะเปลี่ยนจากไม่มีเป็นมี ไม่งั้นจะยิงคำสั่งใส่ชิปทุกสามวินาที
  //และทำเฉพาะโหมด SPI เพราะคำสั่งอ่านรหัสเป็นของ SPI
  if AppReady and ProgrammerPresent and (not Was) and
     MainForm.MenuAutoDetectChip.Checked and MainForm.RadioSPI.Checked then
  begin
    AutomaticChipDetection := True;
    try
      MainForm.ButtonReadIDClick(nil);
    finally
      AutomaticChipDetection := False;
    end;
  end;
end;

procedure LockControl;
begin
  //อ่านสถานะหน้าจอเก็บไว้ก่อนเริ่มงาน thread เบื้องหลังจะอ่านค่า
  //จาก OpUI ไม่ใช่จาก control โดยตรง
  CaptureUIState;
  ResetOperationCancellation;
  MainForm.ButtonCancel.Tag := 0; //legacy scripts still inspect this flag
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
  MainForm.BeginOperationTelemetry;
  MainForm.UpdateWorkflowState;
end;

procedure UnlockControl;
begin
  OperationRunning := False;
  MainForm.FinishOperationTelemetry;

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
  MainForm.UpdateWorkflowState;
end;

//เลือกชิปตามชื่อ โดยหาในไฟล์หลักก่อน แล้วค่อยหาในไฟล์เสริม
function SelectChipAny(const AName: string): boolean;
begin
  //เปลี่ยนชิปแล้ว สิ่งที่รู้เกี่ยวกับตัวเก่าใช้ไม่ได้อีก
  //ถ้าไม่ล้าง opcode ที่เลือกตามยี่ห้อจะเป็นของชิปตัวก่อนหน้า
  Reset25ChipHints;
  ForgetSFDP;
  //การเลือกชิปตัวใหม่ด้วยมือ ไม่ได้พิสูจน์อะไรกับซ็อกเก็ตเลย ธงยืนยันตัวตน
  //ของชิปตัวก่อนต้องตกไปด้วย ไม่งั้นชิปที่เลือกเองจะสวมสถานะ "ยืนยันแล้ว"
  //ผู้เรียกที่ยืนยันได้จริง (Read ID) จะตั้งธงกลับหลังเรียกฟังก์ชันนี้เอง
  ForgetChipSelectionKnowledge;

  Result := findchip.SelectChip(ChipListFile, AName);
  if not Result then
    Result := findchip.SelectChip(ChipListFile2, AName);
  if not Result then
    Result := findchip.SelectChip(ChipListFile3, AName);
  if not Result then
    Result := findchip.SelectChip(ChipListFile4, AName);
  if not Result then
    Result := findchip.SelectChip(ChipListFile5, AName);
  UpdateChipInfo;

  //รู้จักชิปแล้วก็รู้แรงดันที่มันต้องการแล้ว บอกตอนนี้เลย ไม่ใช่รอให้กดอ่าน
  //แล้วชิปเงียบ (ปัก 1.8 ไว้กับชิป 3.3) หรือแย่กว่านั้นคือพัง (กลับกัน)
  if Result then CH347ChipVccGuidance;
end;

procedure TMainForm.ChipClick(Sender: TObject);
begin
  if Sender is TMenuItem then
    SelectChipAny(TMenuItem(Sender).Caption);
end;

//ตั้งขนาดเองก็ถือว่าตั้งค่าชิปแล้ว ไฟดวง Chip ต้องติดตามด้วย
procedure TMainForm.ComboChipSizeChange(Sender: TObject);
begin
  UpdateChipInfo;
end;

procedure TMainForm.MPHexEditorExChange(Sender: TObject);
begin
  //ทางรวมของบัฟเฟอร์ ทุกทางที่โหลดไฟล์ อ่านจากชิป หรือแก้ด้วยมือ ผ่านที่นี่
  //หมด การไปดักที่ LoadFromStream ทีละจุด (มีแปดจุด) จะพลาดจุดที่เก้าที่มี
  //คนเพิ่มทีหลังเสมอ
  //
  //ภาพใหม่ล้างด่านไฟฟ้าที่ผ่านไปแล้วทิ้ง เพราะด่านนั้นตัดสินภาพก่อนหน้า
  if MPHexEditorEx.DataSize > 0 then
    NoteSession(seImageLoaded)
  else
    NoteSession(seImageCleared);

  StatusBar.Panels.Items[0].Text := STR_SIZE+IntToStr(MPHexEditorEx.DataSize);
  if MPHexEditorEx.Modified then
  begin
    StatusBar.Panels.Items[1].Text := STR_CHANGED;
    //ทุกทางที่โหลดบัฟเฟอร์ใหม่จะรีเซ็ต Modified เป็น False เอง ดังนั้น
    //Modified = True ที่นี่แปลว่าถูกแก้ด้วยมือหลังโหลดแล้วจริง ๆ
    if BufferSource in [bsFile, bsChip] then BufferSource := bsEdited;
  end
  else
    StatusBar.Panels.Items[1].Text := '';
  UpdateWorkflowState;
end;

procedure TMainForm.ComboItem1Click(Sender: TObject);
var
  CheckTemp: Boolean;
begin
  if OperationRunning then Exit;

  //SPI NOR uses the preservation-aware single-owner service.  Other legacy
  //protocols retain their protocol-specific sequence below.  The NOR path
  //asks only once, after its exact live-chip plan is visible.
  if RadioSPI.Checked and (ComboSPICMD.ItemIndex = SPI_CMD_25) then
  begin
    MenuSmartWriteClick(MenuSmartWrite);
    Exit;
  end;

  if MessageDlg('AsProgrammer', STR_COMBO_WARN, mtConfirmation,
                [mbYes, mbNo], 0) <> mrYes then Exit;

  if ButtonBlock.Enabled then
  begin
    ButtonBlockClick(Sender);
    if not OpOK then Exit;
  end;
  if ButtonErase.Enabled then
    if ComboSPICMD.ItemIndex <> SPI_CMD_45 then  //ชิปพวกนี้ลบเพจให้เองอยู่แล้ว
    begin
      ButtonEraseClick(Sender);
      if not OpOK then Exit;
    end;

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

procedure TMainForm.MenuSerprogCOMPortClick(Sender: TObject);
begin
  Serprog_COMPort := InputBox('Serprog COMPort','',Serprog_COMPort);
  MainForm.MenuSerprogCOMPort.Caption := 'Serprog COMPort: '+Serprog_COMPort;
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

  //เปิดมาแล้วเห็นชิปทั้งหมดเลย ไม่ใช่หน้าต่างว่างที่ต้องเดาว่าต้องพิมพ์อะไรก่อน
  //พิมพ์เมื่อไหร่ก็กรองให้ทันทีเหมือนเดิม
  ChipSearchForm.EditSearchChange(nil);

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

procedure TMainForm.MenuHWSERPROGClick(Sender: TObject);
begin
  SelectHW(CHW_SERPROG);
end;

procedure TMainForm.MenuHWEZPClick(Sender: TObject);
begin
  SelectHW(CHW_EZP);
end;

procedure TMainForm.MenuChipDoctorClick(Sender: TObject);
begin
  //เมนูไม่ถูกปิดตอนงานเดิน คลิกซ้อนแล้วอุปกรณ์ตัวเดียวกันโดนสองงานพร้อมกัน
  if OperationRunning then Exit;
  RunChipDoctor;
end;

//สลับโหมดอ่านอย่างเดียว
//
//เขียนสถานะลงหน่วย safemode ทันที ไม่ใช่ไปอ่านค่าติ๊กของเมนูตอนจะใช้งาน
//เพราะทางที่ไม่ได้ผ่านหน้าจอ (บรรทัดคำสั่ง สคริปต์) ก็ต้องเห็นสถานะเดียวกัน
procedure TMainForm.MenuSafeModeClick(Sender: TObject);
begin
  SetSafeMode(MenuSafeMode.Checked);
  if SafeModeActive then
    LogPrint('read-only safe mode is ON: erase, write, unlock and ' +
             'status-register edits are refused at the protocol layer, so ' +
             'no menu, script or command line can reach them')
  else
    LogPrint('read-only safe mode is OFF: this chip can be changed again');
end;

//หาความเร็วที่สายชุดนี้รับไหว แล้วติ๊กเมนูให้ตามนั้น
//
//เปิดและปิดอุปกรณ์เองครบวงจร เหมือนงานอื่นในโปรแกรมนี้ ที่นี่จึงเป็นที่เดียว
//ที่ผู้ใช้ต้องกด ไม่ต้องเข้าโหมดโปรแกรมเองก่อน
procedure TMainForm.MenuAutoTuneClockClick(Sender: TObject);
begin
  if OperationRunning then Exit;
  if AsProgrammer.Programmer = nil then Exit;

  LockControl;
  try
    if not OpenDevice then Exit;
    try
      //ต้องผ่านด่านไฟฟ้าก่อนเหมือนงานอื่นทุกงาน การไล่คล็อกคือการยิง CS/CLK
      //เข้าไปหลายสิบรอบ ซึ่งอันตรายเท่ากับงานอ่านถ้ารางไฟผิด
      if not EnterProgModeSPI25 then Exit;
      AutoTuneSPIClock;
    finally
      ExitProgMode25;
      AsProgrammer.Programmer.DevClose;
    end;
  finally
    UnlockControl;
  end;
end;

procedure TMainForm.MenuConnectionDoctorClick(Sender: TObject);
var
  DoctorForm: TForm;
  Results: TMemo;
  Footer: TPanel;
  CloseButton: TButton;
  Lines: TStringList;
  Caps: TProgrammerMemoryCapabilities;
  Protocol: TMemoryProtocol;
  ProtocolText, LiveID, ExpectedID, ErrorText: string;
  ID: MEMORY_ID;
  Opened, BusInitialized, BusTouched, CapsKnown, ProtocolSupported: boolean;
  LiveCheckAllowed: boolean;
  SavedManuf: byte;

  function DriverGuidance: string;
  begin
    case AsProgrammer.Current_HW of
      //ชื่อไดรเวอร์ ไม่ใช่พาธ: ตัวติดตั้งของผู้ผลิตไม่ได้อยู่ใน source tree
      //แล้ว รายละเอียดว่าเอามาจากไหนอยู่ใน vendor-manifest.json
      CHW_CH341:
        Result := 'Install the WCH CH341PAR driver.';
      CHW_CH347:
        Result := 'Install the WCH CH34xPAR driver.';
      CHW_FT232H:
        Result := 'Install the FTDI D2XX (CDM) driver.';
      CHW_USBASP, CHW_AVRISP:
        Result := 'Use Zadig to install the libusb-win32 driver.';
      CHW_ARDUINO, CHW_BUZZPIRAT, CHW_SERPROG:
        Result := 'Check the selected COM port and close any other program ' +
                  'that may own it.';
    else
      Result := 'Check the USB cable, driver, and that no other program owns ' +
                'the device.';
    end;
  end;

  procedure AddWiringGuidance;
  begin
    Lines.Add('');
    Lines.Add('Wiring checklist (power off before changing wires):');
    if RadioSPI.Checked then
    begin
      Lines.Add('  - Pin 1/orientation is correct; GND is common; VCC matches ' +
                'the chip.');
      Lines.Add('  - CS#, CLK, MOSI and MISO are not swapped; WP# and HOLD# ' +
                'are held high.');
    end
    else if RadioI2C.Checked then
    begin
      Lines.Add('  - GND is common; SDA/SCL have suitable pull-ups to the ' +
                'correct voltage.');
      Lines.Add('  - A0/A1/A2 match the address switches; WP is low only ' +
                'when writing is intended.');
    end
    else
    begin
      Lines.Add('  - GND is common; CS, SK, DI and DO are not swapped.');
      Lines.Add('  - Check the organization pin and the selected MicroWire ' +
                'address-bit length.');
    end;
    Lines.Add('  - For in-circuit work, remove board power and prevent the ' +
              'board from driving the same pins.');
  end;

begin
  if OperationRunning then
  begin
    MessageDlg(STR_DOCTOR_TITLE,
      'Finish or cancel the current operation before running connection checks.',
      mtInformation, [mbOK], 0);
    Exit;
  end;

  ConnectionDoctorSeen := True;
  Lines := TStringList.Create;
  Opened := False;
  BusInitialized := False;
  BusTouched := False;
  LiveCheckAllowed := False;
  SavedManuf := Chip25ManufID;
  try
    Lines.Add('These checks are non-destructive: no write-enable, status ' +
              'register, program, or erase command is sent.');
    Lines.Add('');

    if (AsProgrammer = nil) or (AsProgrammer.Programmer = nil) then
    begin
      Lines.Add('[FAIL] No programmer is selected. Choose one from the ' +
                'Programmer menu.');
      CapsKnown := False;
      ProtocolSupported := False;
    end
    else
    begin
      Lines.Add('[INFO] Selected programmer: ' +
                AsProgrammer.Programmer.HardwareName);
      CapsKnown := AsProgrammer.Programmer.GetMemoryCapabilities(Caps);

      if RadioI2C.Checked then
      begin
        Protocol := mpI2C;
        ProtocolText := 'I2C EEPROM';
      end
      else if RadioMW.Checked then
      begin
        Protocol := mpMicroWire;
        ProtocolText := 'MicroWire EEPROM';
      end
      else
      begin
        Protocol := mpSPI;
        ProtocolText := 'SPI memory';
      end;

      ProtocolSupported := CapsKnown and
        AsProgrammer.Programmer.SupportsProtocol(Protocol);
      if ProtocolSupported and RadioSPI.Checked and
         (not Caps.RawSPICommands) and
         ((ComboSPICMD.ItemIndex <> SPI_CMD_25) or
          (not Caps.NativeWholeChipRead)) then
        ProtocolSupported := False;

      if ProtocolSupported then
        Lines.Add('[PASS] Backend supports the selected ' + ProtocolText +
                  ' protocol.')
      else if CapsKnown then
        Lines.Add('[FAIL] This programmer backend does not support the ' +
                  'selected ' + ProtocolText + ' operation.')
      else
        Lines.Add('[WARN] The backend did not publish memory capabilities; ' +
                  'protocol support cannot be trusted.');

      try
        Opened := AsProgrammer.Programmer.DevOpen;
      except
        on E: Exception do
        begin
          ErrorText := E.ClassName + ': ' + E.Message;
          Opened := False;
        end;
      end;
      if Opened then
        Lines.Add('[PASS] Programmer opened; its driver/transport is available.')
      else
      begin
        if ErrorText = '' then ErrorText := AsProgrammer.Programmer.GetLastError;
        Lines.Add('[FAIL] Programmer could not be opened: ' + ErrorText);
        Lines.Add('       ' + DriverGuidance);
      end;
    end;

    //ผ่านตัวหาสามชั้น (ช่อง vcc, ท้ายชื่อรุ่น, รหัส JEDEC) ไม่ใช่ช่องดิบ
    //ไม่งั้นหมอตรวจจะบอกว่า "ไม่รู้แรงดัน" กับชิป 1.8V ที่รู้จักดีอย่าง
    //W25Q64JW แล้วปล่อยให้ตรวจสดด้วยราง 3.3V
    if CurrentICParam.Name = '' then
      Lines.Add('[WARN] No chip profile is selected. Pick the exact part first.')
    else
      Lines.Add(Format('[INFO] Selected chip: %s (%d bytes, VCC %s)',
        [CurrentICParam.Name, CurrentICParam.Size,
         IfThen(Trim(CurrentChipVccText) = '', 'not specified',
                CurrentChipVccText)]));

    if Trim(CurrentChipVccText) = '' then
      Lines.Add('[WARN] Chip voltage is unknown. Check the datasheet and ' +
                'measure VCC before connecting.')
    else if Pos('1.8', CurrentChipVccText) > 0 then
      Lines.Add('[WARN] This is a 1.8 V part. Do not connect ordinary ' +
                '3.3/5 V power or signals; use a verified 1.8 V adapter.')
    else
      Lines.Add('[INFO] Profile voltage: ' + CurrentChipVccText +
                '. Verify the actual rail with a meter; the application ' +
                'cannot measure it.');

    LiveCheckAllowed := (CurrentICParam.Name <> '') and
      (CurrentICParam.Size > 0) and (Trim(CurrentChipVccText) <> '') and
      (Pos('1.8', CurrentChipVccText) = 0);
    if Opened and ProtocolSupported and (not LiveCheckAllowed) then
      Lines.Add('[WARN] Live chip probing was skipped because a selected, ' +
                'sized, non-1.8 V profile is required before the doctor ' +
                'drives bus pins.');

    if Opened and ProtocolSupported and LiveCheckAllowed then
      try
        if RadioSPI.Checked and (not Caps.RawSPICommands) then
          Lines.Add('[INFO] This backend exposes safe native whole-chip SPI ' +
                    'operations but not arbitrary raw commands. The doctor ' +
                    'skipped JEDEC probing; use the backend''s normal Read ID ' +
                    'workflow for identity.')
        else if RadioSPI.Checked and (ComboSPICMD.ItemIndex <> SPI_CMD_KB) then
        begin
          BusTouched := True;
          BusInitialized := AsProgrammer.Programmer.SPIInit(SetSPISpeed(0));
          if not BusInitialized then
            Lines.Add('[FAIL] Programmer opened but SPI initialization failed: ' +
                      AsProgrammer.Programmer.GetLastError)
          else
          begin
            FillChar(ID, SizeOf(ID), 0);
            UsbAsp25_ReadID(ID);
            if ID.Got9F and (ID.ID9FH[0] <> $00) and
               (ID.ID9FH[0] <> $FF) then
            begin
              LiveID := UpperCase(IntToHex(ID.ID9FH[0], 2) +
                                  IntToHex(ID.ID9FH[1], 2) +
                                  IntToHex(ID.ID9FH[2], 2));
              Lines.Add('[PASS] A chip answered JEDEC 9Fh: ' + LiveID);
              ExpectedID := UpperCase(Trim(CurrentICParam.ID));
              if (ExpectedID <> '') and (ExpectedID <> '0') then
                if ExpectedID = LiveID then
                  Lines.Add('[PASS] Live identity matches the selected profile.')
                else
                  Lines.Add('[FAIL] Selected profile expects ' + ExpectedID +
                            ', but the live JEDEC identity is ' + LiveID + '.');
            end
            else
              Lines.Add('[FAIL] No valid JEDEC 9Fh identity answered. Check ' +
                        'orientation, power, CS, CLK, MOSI/MISO, and contact.');
          end;
        end
        else if RadioI2C.Checked then
        begin
          BusTouched := True;
          AsProgrammer.Programmer.I2CInit;
          BusInitialized := True;
          if ComboAddrType.ItemIndex < 0 then
            Lines.Add('[WARN] Select an I2C address type before testing the chip.')
          else if UsbAspI2C_BUSY(SetI2CDevAddr()) then
            Lines.Add('[FAIL] No EEPROM acknowledged the selected I2C ' +
                      'address. Check SDA/SCL, pull-ups and A0/A1/A2.')
          else
            Lines.Add('[PASS] An I2C device acknowledged the selected address.');
        end
        else if RadioMW.Checked then
        begin
          BusTouched := True;
          BusInitialized := AsProgrammer.Programmer.MWInit(SetSPISpeed(0));
          if BusInitialized then
            Lines.Add('[PASS] MicroWire bus initialization succeeded. This ' +
                      'protocol has no standard read-only device identity.')
          else
            Lines.Add('[FAIL] MicroWire initialization failed: ' +
                      AsProgrammer.Programmer.GetLastError);
        end
        else
          Lines.Add('[INFO] Use Read ID for the selected EC protocol; it has ' +
                    'no JEDEC memory identity.');
      except
        on E: Exception do
          Lines.Add('[FAIL] Read-only bus check raised ' + E.ClassName + ': ' +
                    E.Message);
      end;

    AddWiringGuidance;
    Lines.Add('');
    Lines.Add('If every electrical check passes, close this window and use ' +
              'Read ID/Read chip before any write. A successful open alone ' +
              'does not prove voltage or clip contact.');
  finally
    try
      if BusTouched and (AsProgrammer <> nil) and
         (AsProgrammer.Programmer <> nil) then
      begin
        if RadioI2C.Checked then AsProgrammer.Programmer.I2CDeinit
        else if RadioMW.Checked then AsProgrammer.Programmer.MWDeinit
        else AsProgrammer.Programmer.SPIDeinit;
      end;
    except
      on E: Exception do Lines.Add('[WARN] Bus cleanup reported: ' + E.Message);
    end;
    try
      if Opened and (AsProgrammer <> nil) and
         (AsProgrammer.Programmer <> nil) then
        AsProgrammer.Programmer.DevClose;
    except
      on E: Exception do Lines.Add('[WARN] Device close reported: ' + E.Message);
    end;
    Chip25ManufID := SavedManuf;
  end;

  DoctorForm := TForm.CreateNew(Self);
  try
    DoctorForm.Caption := STR_DOCTOR_TITLE;
    DoctorForm.Position := poScreenCenter;
    DoctorForm.BorderStyle := bsSizeable;
    DoctorForm.SetBounds(0, 0, 760, 620);

    Footer := TPanel.Create(DoctorForm);
    Footer.Parent := DoctorForm;
    Footer.Align := alBottom;
    Footer.Height := 52;
    Footer.BevelOuter := bvNone;

    CloseButton := TButton.Create(DoctorForm);
    CloseButton.Parent := Footer;
    CloseButton.Caption := 'Close';
    CloseButton.ModalResult := mrOK;
    CloseButton.Default := True;
    CloseButton.SetBounds(Footer.Width - 110, 10, 96, 32);
    CloseButton.Anchors := [akTop, akRight];

    Results := TMemo.Create(DoctorForm);
    Results.Parent := DoctorForm;
    Results.Align := alClient;
    Results.ReadOnly := True;
    Results.ScrollBars := ssAutoBoth;
    Results.WordWrap := True;
    Results.Font.Name := 'Consolas';
    Results.Font.Size := 10;
    Results.Lines.Assign(Lines);
    DoctorForm.ActiveControl := CloseButton;
    DoctorForm.ShowModal;
  finally
    DoctorForm.Free;
    Lines.Free;
  end;
end;

procedure TMainForm.MenuCapacityTestClick(Sender: TObject);
begin
  if OperationRunning then Exit;
  //เขียนจริง (สำรองและกู้คืนให้) แต่ไฟดับกลางคันคือข้อมูลบางเซกเตอร์หาย
  //ให้ผู้ใช้ตัดสินใจเองก่อนเสมอ
  if MessageDlg('True capacity test',
       'This test really erases and rewrites up to 17 sectors (they are ' +
       'backed up first and restored afterwards, byte-verified). ' +
       'If power is lost mid-test, those sectors are lost. ' + LineEnding +
       LineEnding + 'Run the test?',
       mtWarning, [mbYes, mbNo], 0) <> mrYes then Exit;
  RunChipCapacityTest;
end;

procedure TMainForm.MenuSurfaceScanClick(Sender: TObject);
begin
  if OperationRunning then Exit;
  if MessageDlg('Surface scan',
       'This scan ERASES THE ENTIRE CHIP and leaves it blank. Every ' +
       'block is erased and rewritten several times with test patterns ' +
       'to certify the cells and the addressing. Nothing is backed up.' +
       LineEnding + LineEnding + 'Erase everything and scan?',
       mtWarning, [mbYes, mbNo], 0) <> mrYes then Exit;
  RunChipSurfaceScan;
end;

procedure TMainForm.MenuItemBenchmarkClick(Sender: TObject);
var
  buffer: array[0..2047] of byte;
  i, cycles: integer;
  t: TDateTime;
  timeval: integer;
  ms, sec, d: word;
begin
  if OperationRunning then Exit;
  //ไม่มี OpBegin = แผง telemetry จะเอา LastOp ของงานก่อนหน้ามาหารเวลาของ
  //งานนี้ กลายเป็นสถิติที่ไม่เคยเกิดขึ้นจริง
  OpBegin(opkNone);
  ButtonCancel.Tag := 0;
  if not OpenDevice() then exit;
  EnterProgMode25(SetSPISpeed(0), MainForm.MenuSendAB.Checked);
  LockControl();
try
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
    OpProcessMessages;

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
    OpProcessMessages;

    if UserCancel then Break;
  end;

  t :=  Time() - TimeCounter;
  DecodeDateTime(t, d, d, d, d, d, sec, ms);

  timeval := (sec * 1000) + ms;
  if timeval = 0 then timeval := 1;

  LogPrint(STR_TIME + TimeToStr(t)+' '+
    IntToStr( Trunc(((cycles*sizeof(buffer)) / timeval) * 1000)) +' bytes/s');

finally
  //ข้อยกเว้นระหว่างวัด (ไดรเวอร์อนุกรมโยนได้จริง) ต้องไม่ทิ้ง
  //OperationRunning ค้าง True: ปุ่มทุกปุ่มจะตายและหน้าต่างปิดไม่ได้อีกเลย
  ExitProgMode25;
  AsProgrammer.Programmer.DevClose;
  UnlockControl();
end;
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
  if OperationRunning then Exit;
  OpBegin(opkNone);
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
  if OperationRunning then Exit;
  OpBegin(opkNone);
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
  UpdateWorkflowState;
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
  UpdateWorkflowState;
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
  UpdateWorkflowState;
end;

procedure TMainForm.ButtonWriteClick(Sender: TObject);
var
  PageSize: word;
  WriteType: byte;
  I2C_DevAddr: byte;
  I2C_ChunkSize: Word;
  ParsedPage: integer;
begin
  //All normal SPI NOR writes share the transactional planner/executor.  This
  //removes the legacy raw page-program path from GUI, batch, and CLI entry
  //points while leaving protocol-specific EEPROM/DataFlash writers intact.
  //EZP2023+ ไม่มีคำสั่ง SPI ดิบให้ตัววางแผนใช้ แต่เขียนทั้งชิปได้เอง
  //ปุ่มเดิมจึงพาไปเส้นทางนั้น ผู้ใช้ไม่ต้องรู้ว่าข้างในต่างกัน
  if RadioSPI.Checked and (ComboSPICMD.ItemIndex = SPI_CMD_25) and
     (AsProgrammer.Current_HW = CHW_EZP) then
  begin
    if Sender <> ComboItem1 then
      if MessageDlg('AsProgrammer',
           'The EZP2023+ writes the whole chip in one operation: ' +
           'everything on it is replaced by the buffer, and anything past ' +
           'the end of the buffer becomes FF.' + LineEnding + LineEnding +
           'Write the whole chip?',
           mtWarning, [mbYes, mbNo], 0) <> mrYes then
      begin
        OpBegin(opkWrite);
        OpCancel;
        Exit;
      end;
    RunEZPWholeChipWrite(False);
    Exit;
  end;

  if RadioSPI.Checked and (ComboSPICMD.ItemIndex = SPI_CMD_25) then
  begin
    MenuSmartWriteClick(Sender);
    Exit;
  end;

  I2C_ChunkSize := 65535;
  OpBegin(opkWrite);
  //ชิปกำลังจะถูกเปลี่ยนเนื้อใน ความรู้เดิมว่า "เปล่า" หรือ "มีข้อมูล"
  //ใช้ต่อไม่ได้อีก ไม่งั้นการเขียนรอบถัดไปจะอ้างสถานะก่อนเขียนรอบนี้
  ForgetChipContent;
  //TSerialAllocation มีสตริงที่จัดการโดยคอมไพเลอร์อยู่ข้างใน FillChar จะทับ
  //พอยน์เตอร์ทิ้งโดยไม่ลด refcount แล้วสตริงของงานก่อนจะรั่วทุกครั้งที่กดเขียน
  CurrentSerial := Default(TSerialAllocation);
  CurrentSerialValid := False;
  CurrentSerialReserved := False;
  LastProgramCRC := BufferCRC32;
try
  ButtonCancel.Tag := 0;
  if not OpenDevice() then
  begin
    OpFail('the programmer could not be opened');
    exit;
  end;
  if Sender <> ComboItem1 then
    if MessageDlg('AsProgrammer', STR_START_WRITE, mtConfirmation, [mbYes, mbNo], 0)
      <> mrYes then
    begin
      OpCancel;
      Exit;
    end;
  LockControl();

  //SPI scripts can issue destructive commands of their own, so they run only
  //after the same electrical, identity, protection and backup gates as the
  //built-in writer.  A legacy non-SPI script keeps its old entry point when
  //backup is off; when backup is requested it is deferred until the trusted
  //family-specific snapshot has been published.
  if (not RadioSPI.Checked) and (not MenuAutoBackup.Checked) and
     RunScriptFromFile(CurrentICParam.Script, 'write') then Exit;

  LogPrint(TimeToStr(Time()));

  if (not IsNumber(ComboChipSize.Text)) then
  begin
    LogPrint(STR_CHECK_SETTINGS);
    OpFail('the chip size is not a number');
    Exit;
  end;

  if MPHexEditorEx.DataSize > StrToInt(ComboChipSize.Text) - Hex2Dec('$'+StartAddressEdit.Text) then
  begin
    LogPrint(STR_WRONG_FILE_SIZE);
    OpFail('the buffer does not fit the chip from the given start address');
    Exit;
  end;

  //SPI
  if RadioSPI.Checked then
  begin
    if not VoltageWarningOK then
    begin
      OpFail('aborted because of the supply voltage');
      Exit;
    end;
    EnterProgMode25(SetSPISpeed(0), MainForm.MenuSendAB.Checked);
    if MenuResetChip.Checked and (ComboSPICMD.ItemIndex = SPI_CMD_25) then
    begin
      LogPrint(STR_RESETTING);
      UsbAsp25_SoftReset;
    end;

    //ตรวจว่าการเชื่อมต่อนิ่งก่อนจะไปแตะข้อมูล
    //เขียนหรือลบผ่านคลิปที่หลวมคือทางที่ตรงที่สุดไปสู่ชิปที่พัง
    if not ContactIsStable then Exit;

    if not VerifyChipID then
    begin
      OpFail('the chip in the socket does not match the selected one');
      Exit;
    end;

    //ต้องรู้จักชิปก่อน คำสั่งที่ต่างกันตามยี่ห้อและด่านตรวจต่าง ๆ พึ่งข้อมูลนี้
    EnsureChipHints;
    LastChipUID := ReadChipUID;
    if LastChipUID <> '' then LogPrint(STR_UNIQUE_ID + LastChipUID);

    if not DuplicateChipGuardOK(LastChipUID) then Exit;
    if not JobFileGuardOK(MPHexEditorEx.DataSize) then Exit;
    if not ProtectionGuardOK(Hex2Dec('$'+StartAddressEdit.Text), MPHexEditorEx.DataSize) then Exit;

    if not AutoBackupChip then
    begin
      OpFail('the backup could not be made');
      Exit;
    end;
    if RunScriptFromFile(CurrentICParam.Script, 'write') then Exit;
    if not BlankCheckBeforeWrite(Hex2Dec('$'+StartAddressEdit.Text), MPHexEditorEx.DataSize) then
    begin
      OpFail('the target area is not erased');
      Exit;
    end;

    if ComboSPICMD.ItemIndex <> SPI_CMD_KB then
      IsLockBitsEnabled;
    if (not IsNumber(ComboPageSize.Text)) and (UpperCase(ComboPageSize.Text)<>'SSTB') and (UpperCase(ComboPageSize.Text)<>'SSTW') then
    begin
      LogPrint(STR_CHECK_SETTINGS);
      OpFail('the chip size, the page size or the range is not usable');
      exit;
    end;

    if UpperCase(ComboPageSize.Text) = 'SSTB' then
    begin
      PageSize := 1;
      WriteType := WT_SSTB;
    end
    else if UpperCase(ComboPageSize.Text) = 'SSTW' then
    begin
      PageSize := 2;
      WriteType := WT_SSTW;
    end
    else
    begin
      ParsedPage := StrToInt(ComboPageSize.Text);
      if (ParsedPage < 1) or (ParsedPage > 2048) then
      begin
        OpFail('this protocol requires a numeric page size from 1 to 2048 bytes');
        Exit;
      end;
      PageSize := ParsedPage;
      WriteType := WT_PAGE;
    end;

    if (WriteType <> WT_PAGE) then
    begin
      OpFail('this protocol requires a numeric page size from 1 to 2048 bytes');
      Exit;
    end;
    if (ComboSPICMD.ItemIndex in [SPI_CMD_45, SPI_CMD_KB]) and
       ((MPHexEditorEx.DataSize mod PageSize) <> 0) then
    begin
      OpFail('the image must contain complete physical pages');
      Exit;
    end;
    if (ComboSPICMD.ItemIndex = SPI_CMD_95) and
       (not SPI95AddressRangeValid(StrToInt(ComboChipSize.Text),
                                  Hex2Dec('$' + StartAddressEdit.Text),
                                  MPHexEditorEx.DataSize)) then
    begin
      OpFail('the SPI EEPROM write range is outside the selected chip');
      Exit;
    end;
    TimeCounter := Time();

    RomF.Position := 0;
    MPHexEditorEx.SaveToStream(RomF);
    RomF.Position := 0;

    if not ApplySerialToStream(RomF) then Exit;
    if not ReserveCurrentSerial then Exit;

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

      //แล้วตรวจซ้ำอีกรอบในเซสชันใหม่ ถ้าผ่านรอบแรก
      if OpOK and (ComboSPICMD.ItemIndex <> SPI_CMD_KB) then
        ReVerifyInFreshSession(Hex2Dec('$'+StartAddressEdit.Text),
                               MPHexEditorEx.DataSize);
    end;

  end;
  //I2C
  if RadioI2C.Checked then
  begin
    if ( (ComboAddrType.ItemIndex < 0) or (not IsNumber(ComboPageSize.Text)) ) then
    begin
      LogPrint(STR_CHECK_SETTINGS);
      OpFail('the chip size, the page size or the range is not usable');
      exit;
    end;
    ParsedPage := StrToInt(ComboPageSize.Text);
    if (ParsedPage < 1) or (ParsedPage > 2048) or
       (MPHexEditorEx.DataSize > High(integer)) or
       (not I2CAddressRangeValid(ComboAddrType.ItemIndex,
          Hex2Dec('$' + StartAddressEdit.Text),
          integer(MPHexEditorEx.DataSize))) then
    begin
      OpFail('the I2C page size or complete address range is not usable');
      Exit;
    end;
    PageSize := ParsedPage;

    EnterProgModeI2C();

    //แอดเดรสของชิปตามช่องติ๊ก
    I2C_DevAddr := SetI2CDevAddr();

    if CheckBox_I2C_ByteRead.Checked then I2C_ChunkSize := 1;

    if UsbAspI2C_BUSY(I2C_DevAddr) then
    begin
      LogPrint(STR_I2C_NO_ANSWER);
      OpFail('the I2C EEPROM did not acknowledge its address');
      exit;
    end;
    if not AutoBackupChip then
    begin
      OpFail('the backup could not be made');
      Exit;
    end;
    if RunScriptFromFile(CurrentICParam.Script, 'write') then Exit;
    TimeCounter := Time();

    RomF.Position := 0;
    MPHexEditorEx.SaveToStream(RomF);
    RomF.Position := 0;
    if not ApplySerialToStream(RomF) then Exit;
    if not ReserveCurrentSerial then Exit;

    WriteFlashI2C(RomF, Hex2Dec('$'+StartAddressEdit.Text),
                  MPHexEditorEx.DataSize, PageSize, I2C_DevAddr);

    if MenuAutoCheck.Checked then
    begin
      if UsbAspI2C_BUSY(I2C_DevAddr) then
      begin
        LogPrint(STR_I2C_NO_ANSWER);
        OpFail('the I2C EEPROM stopped acknowledging before verification');
        exit;
      end;
      LogPrint(STR_TIME + TimeToStr(Time() - TimeCounter));

      TimeCounter := Time();

      RomF.Position := 0;
      VerifyFlashI2C(RomF, Hex2Dec('$'+StartAddressEdit.Text), RomF.Size, I2C_ChunkSize, I2C_DevAddr);
    end;

  end;
  //Microwire
  if RadioMW.Checked then
  begin
    if (not IsNumber(ComboMWBitLen.Text)) then
    begin
      LogPrint(STR_CHECK_SETTINGS);
      OpFail('the chip size, the page size or the range is not usable');
      exit;
    end;

    if not AsProgrammer.Programmer.MWInit(SetSPISpeed(0)) then
    begin
      OpFail('the programmer could not initialize the MicroWire bus');
      Exit;
    end;
    if not AutoBackupChip then
    begin
      OpFail('the backup could not be made');
      Exit;
    end;
    if RunScriptFromFile(CurrentICParam.Script, 'write') then Exit;
    TimeCounter := Time();

    RomF.Position := 0;
    MPHexEditorEx.SaveToStream(RomF);
    RomF.Position := 0;
    if not ApplySerialToStream(RomF) then Exit;
    if not ReserveCurrentSerial then Exit;

    WriteFlashMW(RomF, StrToInt(ComboMWBitLen.Text), 0, MPHexEditorEx.DataSize);

    if MenuAutoCheck.Checked then
    begin
      TimeCounter := Time();
      RomF.Position := 0;
      VerifyFlashMW(RomF, StrToInt(ComboMWBitLen.Text), 0, StrToInt(ComboChipSize.Text));
    end;

  end;

  LogPrint(STR_TIME + TimeToStr(Time() - TimeCounter));

finally
  //บันทึกการผลิตต้องเขียนทั้งตอนผ่านและตอนไม่ผ่าน ของที่ตกก็ต้องตามรอยได้
  if MPHexEditorEx.DataSize > 0 then
    WriteProdLogEntry(MPHexEditorEx.DataSize, LastProgramCRC, LastChipUID);

  LogPrint(STR_OP_RESULT + OpSummary);

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
  if OperationRunning then Exit;
  I2C_ChunkSize := 65535;
  if BlankCheck then OpBegin(opkBlankCheck) else OpBegin(opkVerify);
try
  ButtonCancel.Tag := 0;
  if not OpenDevice() then
  begin
    OpFail('the programmer could not be opened');
    exit;
  end;
  LockControl();

  if RunScriptFromFile(CurrentICParam.Script, 'verify') then Exit;

  LogPrint(TimeToStr(Time()));

  if not IsNumber(ComboChipSize.Text) then
  begin
    LogPrint(STR_CHECK_SETTINGS);
    OpFail('the chip size is not a number');
    Exit;
  end;

  if (MPHexEditorEx.DataSize > StrToInt(ComboChipSize.Text) - Hex2Dec('$'+StartAddressEdit.Text)) and (not BlankCheck) then
  begin
    LogPrint(STR_WRONG_FILE_SIZE);
    OpFail('the buffer does not fit the chip from the given start address');
    Exit;
  end;

  //SPI
  if RadioSPI.Checked then
  begin
    if not VoltageWarningOK then
    begin
      OpFail('aborted because of the supply voltage');
      Exit;
    end;
    EnterProgMode25(SetSPISpeed(0), MainForm.MenuSendAB.Checked);
    if not ContactIsStable then Exit;
    if not VerifyChipID then
    begin
      OpFail('the chip in the socket does not match the selected one');
      Exit;
    end;
    EnsureChipHints;
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
        OpFail('the chip size, the page size or the range is not usable');
        exit;
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
      OpFail('the chip size, the page size or the range is not usable');
      exit;
    end;

    EnterProgModeI2C();

    //แอดเดรสของชิปตามช่องติ๊ก
    I2C_DevAddr := SetI2CDevAddr();

    if CheckBox_I2C_ByteRead.Checked then I2C_ChunkSize := 1;

    if UsbAspI2C_BUSY(I2C_DevAddr) then
    begin
      LogPrint(STR_I2C_NO_ANSWER);
      OpFail('the I2C EEPROM did not acknowledge its address');
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
      OpFail('the chip size, the page size or the range is not usable');
      exit;
    end;

    if not AsProgrammer.Programmer.MWInit(SetSPISpeed(0)) then
    begin
      OpFail('the programmer could not initialize the MicroWire bus');
      Exit;
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

    VerifyFlashMW(RomF, StrToInt(ComboMWBitLen.Text), 0, RomF.Size);
  end;

  LogPrint(STR_TIME + TimeToStr(Time() - TimeCounter));

finally
  LogPrint(STR_OP_RESULT + OpSummary);
  ExitProgMode25;
  AsProgrammer.Programmer.DevClose;
  UnlockControl();
end;
end;

//Safely clear SPI NOR protection without disturbing unrelated configuration
//bits such as QE.  The caller owns an already-open, initialized SPI session.
function UnlockCurrentSPI25: boolean;
var
  SR1, SR2, CR, NewSR1, NewSR2: byte;
  HaveCR, Unlocked98: boolean;
  P: TProtInfo;
begin
  Result := False;
  Unlocked98 := False;
  EnsureChipHints;
  SR1 := 0;
  SR2 := 0;

  if UsbAsp25_ReadSR(SR1, $05) <> 1 then
  begin
    OpFail('the primary SPI NOR status register could not be read');
    Exit;
  end;
  if UsbAsp25_ReadSR(SR2, $35) <> 1 then SR2 := 0;
  //CR ต้องมาจากรีจิสเตอร์ที่ถูกตัวตามยี่ห้อ: Spansion ใช้ค่า 35h ไม่ใช่ 15h
  //ที่ชิปตระกูลนั้นไม่มี (ได้ FF จากบัสลอยแล้วทิศทางล็อกกลับหัว)
  HaveCR := ReadVendorCR(Chip25ManufID, SR2, CR);
  if SR2 = $FF then SR2 := 0;

  P := DecodeProtVendor(Chip25ManufID, SR1, SR2, CR, HaveCR);
  if not StillProtected(P) then Exit(True);
  if not CanUnlockBySoftware(P) then
  begin
    OpFail('the status register cannot be unlocked by software: ' +
           SRLockText(SRLockState(P)));
    Exit;
  end;

  ClearProtection(P, SR1, SR2, NewSR1, NewSR2);
  if not WrenOK then Exit;
  if P.Layout in [plWinbond, plUnknown] then
  begin
    if UsbAsp25_WriteSR_2byte(NewSR1, NewSR2) <> 3 then
    begin
      OpFail('the two-byte status-register write was not transferred exactly');
      Exit;
    end;
  end
  else if UsbAsp25_WriteSR(NewSR1) <> 2 then
  begin
    OpFail('the status-register write was not transferred exactly');
    Exit;
  end;
  if not WaitNotBusy25(BUSY_TIMEOUT_SECTOR) then Exit;

  if P.WPS then
  begin
    if not WrenOK then Exit;
    if UsbAsp25_GlobalUnlock <> 1 then
    begin
      OpFail('the global-unlock command was not transferred exactly');
      Exit;
    end;
    if not WaitNotBusy25(BUSY_TIMEOUT_SECTOR) then Exit;
    Unlocked98 := True;
  end;

  if UsbAsp25_ReadSR(SR1, $05) <> 1 then
  begin
    OpFail('the primary status register could not be read after unlock');
    Exit;
  end;
  if UsbAsp25_ReadSR(SR2, $35) <> 1 then SR2 := 0;
  HaveCR := ReadVendorCR(Chip25ManufID, SR2, CR);
  if SR2 = $FF then SR2 := 0;
  P := DecodeProtVendor(Chip25ManufID, SR1, SR2, CR, HaveCR);
  //ธง WPS เป็นตัวเลือกโหมด ไม่ใช่ตัวล็อก และ 98h ไม่ได้ล้างมัน สิ่งที่ 98h
  //ปลดคือบิตล็อกรายบล็อก ซึ่งด่านสแกน 3Dh ก่อนเขียนจะตรวจซ้ำอีกชั้นอยู่แล้ว
  //ถ้ายังนับ WPS เป็น "ยังล็อกอยู่" ตรงนี้ การปลดล็อกที่สำเร็จจริงจะถูก
  //รายงานว่าล้มเหลวทุกครั้ง
  if Unlocked98 then P.WPS := False;
  if StillProtected(P) then
  begin
    OpFail('the chip accepted the unlock command and stayed protected');
    Exit;
  end;
  Result := True;
end;

procedure TMainForm.ButtonBlockClick(Sender: TObject);
var
  sreg: byte;
  SR1, SR2, CR, NewSR1, NewSR2: byte;
  HaveCR: boolean;
  WEL: boolean;
  Prot: TProtInfo;
  Lock: TSRLock;
  i: integer;
  s: string;
  SLreg: array[0..31] of byte;
begin
try
  OpBegin(opkNone);
  ButtonCancel.Tag := 0;
  if not OpenDevice() then
  begin
    OpFail('the programmer could not be opened');
    Exit;
  end;
  sreg := 0;
  SR1 := 0; SR2 := 0; CR := 0;
  LockControl();

  if not VoltageWarningOK then
  begin
    OpFail('aborted because of the supply voltage');
    Exit;
  end;

  if not EnterProgMode25(SetSPISpeed(0), MainForm.MenuSendAB.Checked) then
  begin
    OpFail('the programmer could not initialize the SPI bus');
    Exit;
  end;
  if not ContactIsStable then Exit;
  if not VerifyChipID then
  begin
    OpFail('the chip in the socket does not match the selected one');
    Exit;
  end;

  if RunScriptFromFile(CurrentICParam.Script, 'unlock') then Exit;

  if ComboSPICMD.ItemIndex = SPI_CMD_25 then
  begin
    //ต้องรู้จักยี่ห้อก่อน เพราะบิตแต่ละตัวใน status register แปลว่าคนละอย่าง
    //ในแต่ละแผนผัง การเขียน 00h ทับทั้งไบต์โดยไม่ดูว่าบิตไหนคืออะไร จะล้าง
    //QE ไปด้วยบนชิปที่บอร์ดใช้โหมด quad แล้วบอร์ดนั้นจะบูตไม่ขึ้นอีกเลย
    EnsureChipHints;

    if UsbAsp25_ReadSR(SR1) <> 1 then
    begin
      OpFail('the SPI NOR status register could not be read');
      Exit;
    end;
    UsbAsp25_ReadSR(SR2, $35);
    //CR มาจากรีจิสเตอร์ที่ถูกตัวตามยี่ห้อ ไม่ใช่ยิง 15h ใส่ทุกชิป
    HaveCR := ReadVendorCR(Chip25ManufID, SR2, CR);
    if SR2 = $FF then SR2 := 0;
    LogPrint(STR_OLD_SREG + IntToBin(SR1, 8) + '(0x' + IntToHex(SR1, 2) + ')' +
             '  SR2=0x' + IntToHex(SR2, 2));

    Prot := DecodeProtVendor(Chip25ManufID, SR1, SR2, CR, HaveCR);
    LogPrint(Format(STR_PROT_LAYOUT, [LayoutName(Prot.Layout)]));

    //ชิปที่ล็อก status register ไว้ด้วยฮาร์ดแวร์หรือล็อกถาวร จะรับคำสั่ง
    //เขียนไปแล้วไม่ทำอะไร เดิมเราเขียนแล้วอ่านกลับมาแสดงค่าเดิม โดยไม่บอก
    //ว่าไม่สำเร็จ ผู้ใช้จึงไปเจอความจริงตอนเขียนไม่ผ่านในอีกหลายนาทีถัดมา
    Lock := SRLockState(Prot);
    LogPrint(Format(STR_SR_LOCK, [SRLockText(Lock)]));
    if not CanUnlockBySoftware(Prot) then
    begin
      OpFail('the status register cannot be unlocked by software: ' +
             SRLockText(Lock));
      Exit;
    end;

    ClearProtection(Prot, SR1, SR2, NewSR1, NewSR2);

    if not WrenOK then Exit;

    //เขียนสองไบต์เมื่อแผนผังนี้มี SR2 จริง ๆ ไม่งั้นเขียนไบต์เดียว
    //การยิงไบต์ที่สองใส่ชิปที่ไม่มี SR2 คือการส่งข้อมูลเกินให้คำสั่งที่
    //ไม่ได้รอรับมัน ซึ่งชิปแต่ละตัวตอบสนองต่างกันและไม่มีตัวไหนตอบสนองดี
    if Prot.Layout in [plWinbond, plUnknown] then
    begin
      if UsbAsp25_WriteSR_2byte(NewSR1, NewSR2) <> 3 then
      begin
        OpFail('the two-byte status-register write was not transferred exactly');
        Exit;
      end;
    end
    else if UsbAsp25_WriteSR(NewSR1) <> 2 then
    begin
      OpFail('the status-register write was not transferred exactly');
      Exit;
    end;

    if not WaitNotBusy25(BUSY_TIMEOUT_SECTOR) then Exit;

    //WPS = 1 แปลว่าบิต BP ไม่ใช่ตัวตัดสิน การล้าง BP จึงไม่ปลดอะไรเลย
    //ต้องปลดบิตล็อกรายบล็อกด้วยคำสั่งของมันเอง
    if Prot.WPS then
    begin
      LogPrint(STR_GLOBAL_UNLOCK);
      if WrenOK then
      begin
        if UsbAsp25_GlobalUnlock <> 1 then
        begin
          OpFail('the global-unlock command was not transferred exactly');
          Exit;
        end;
        if not WaitNotBusy25(BUSY_TIMEOUT_SECTOR) then Exit;
      end;
    end;

    //อ่านกลับมาดูว่าได้ผลจริงหรือไม่ ไม่ใช่แค่แสดงค่าแล้วปล่อยให้คนอ่านสรุปเอง
    if UsbAsp25_ReadSR(SR1) <> 1 then
    begin
      OpFail('the SPI NOR status register could not be read back');
      Exit;
    end;
    UsbAsp25_ReadSR(SR2, $35);
    HaveCR := ReadVendorCR(Chip25ManufID, SR2, CR);
    if SR2 = $FF then SR2 := 0;
    LogPrint(STR_NEW_SREG + IntToBin(SR1, 8) + '(0x' + IntToHex(SR1, 2) + ')' +
             '  SR2=0x' + IntToHex(SR2, 2));

    Prot := DecodeProtVendor(Chip25ManufID, SR1, SR2, CR, HaveCR);
    if StillProtected(Prot) then
    begin
      LogPrint(STR_UNLOCK_FAILED);
      OpFail('the chip accepted the unlock and stayed protected');
      Exit;
    end;

    if Prot.QE then LogPrint(STR_QE_KEPT);
    LogPrint(STR_UNLOCK_OK);
  end;

  if ComboSPICMD.ItemIndex = SPI_CMD_95 then
  begin
    if UsbAsp95_ReadSR(sreg) <> 1 then
    begin
      OpFail('the SPI EEPROM status register could not be read');
      Exit;
    end;
    LogPrint(STR_OLD_SREG+IntToBin(sreg, 8));

    sreg := 0; //
    if not UsbAsp95_WrenChecked(WEL) then
    begin
      OpFail('the SPI EEPROM did not latch write enable');
      Exit;
    end;
    if UsbAsp95_WriteSR(sreg) <> 2 then
    begin
      OpFail('the SPI EEPROM status-register write was not transferred exactly');
      Exit;
    end;

    //รอจนกว่าชิปจะพร้อม
    if not WaitNotBusy95(BUSY_TIMEOUT_SECTOR) then Exit;

    if UsbAsp95_ReadSR(sreg) <> 1 then
    begin
      OpFail('the SPI EEPROM status register could not be read back');
      Exit;
    end;
    if (sreg and $0C) <> 0 then
    begin
      OpFail('the SPI EEPROM stayed write protected after unlock');
      Exit;
    end;
    LogPrint(STR_NEW_SREG+IntToBin(sreg, 8));
  end;

  if ComboSPICMD.ItemIndex = SPI_CMD_45 then
  begin
    if UsbAsp45_DisableSP <> 4 then
    begin
      OpFail('the DataFlash protection-disable command was not transferred exactly');
      Exit;
    end;
    if UsbAsp45_ReadSR(sreg) <> 1 then
    begin
      OpFail('the DataFlash status register could not be read');
      Exit;
    end;
    LogPrint('Sreg: '+IntToBin(sreg, 8));

    if UsbAsp45_ReadSectorLockdown(SLreg) <> SizeOf(SLreg) then
    begin
      OpFail('the DataFlash lockdown register was not read exactly');
      Exit;
    end;

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
  ManufSaved: byte;
  Geo45: TAT45Geometry;
  P2_45, AT45Known: boolean;
  Page45: word;
  Total45: cardinal;
  Err45, Mode45: string;
  FamilyName, MatchVendor: string;
  VendorMatchCount, VendorMatchIndex, p: integer;
  ProbeMv: cardinal;
begin
  OpBegin(opkDetect);
  //เริ่มตรวจใหม่ = ลืมของเก่าไว้ก่อน ถ้าตรวจไม่สำเร็จก็ต้องไม่เหลือสถานะ
  //"ยืนยันตัวตนแล้ว" ค้างมาจากชิปตัวก่อนหน้า
  ForgetChipKnowledge;
  try
    if not OpenDevice() then
    begin
      OpFail('the programmer could not be opened');
      exit;
    end;
    LockControl();

    //CH347: เลือกแรงดันที่จะใช้แหย่ถามรหัส
    //
    //DevOpen เพิ่งบังคับ 1.8V ไปแล้ว ซึ่งเป็นระดับเดียวที่ไม่ทำชิปตัวไหนพัง
    //โหมด Auto จึงแหย่ที่ 1.8V เสมอ: ค่า Vcc ของชิปที่ "เลือกค้างไว้" ใช้
    //ไม่ได้ เพราะชิปในซ็อกเก็ตตอนนี้อาจเป็นคนละตัวกัน ยกขึ้น 3.3V เฉพาะเมื่อ
    //ผู้ใช้ปักหมุดไว้เองเท่านั้น (นั่นคือทางเดียวที่ชิป 3.3V ที่เงียบใส่
    //1.8V จะยอมคุยด้วย) ศูนย์ = เครื่องนี้คุมแรงดันไม่ได้
    ProbeMv := 0;
    if (AsProgrammer.Current_HW = CHW_CH347) and
       AsProgrammer.Programmer.SupportsTargetVoltage then
    begin
      ProbeMv := SelectedCH347Vcc;
      if ProbeMv = 0 then ProbeMv := CH347_VCC_1V8_MV;
      if AsProgrammer.Programmer.GetTargetVoltageMv <> ProbeMv then
      begin
        if AsProgrammer.Programmer.SetTargetVoltageMv(ProbeMv) then
          LogPrint(Format(STR_CH347_VCC_SET, [ProbeMv]))
        else
        begin
          LogPrint(Format(STR_CH347_VCC_FAILED, [ProbeMv]));
          ProbeMv := AsProgrammer.Programmer.GetTargetVoltageMv;
        end;
      end;
      if ProbeMv = CH347_VCC_3V3_MV then LogPrint(STR_CH347_PROBE_3V3);
    end;

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

    //DataFlash บอกขนาดเพจกับโหมดปัจจุบันของตัวเองผ่าน status register
    //อ่านตอนนี้ที่ยังอยู่ในโหมดโปรแกรม แล้วค่อยเอาไปเติมช่องหลังเลือกชิปเสร็จ
    AT45Known := False;
    if ComboSPICMD.ItemIndex = SPI_CMD_45 then
    begin
      if (not UsbAsp45_DetectGeometry(Geo45, P2_45, Page45, Total45,
                                      AT45Known, Err45)) and (Err45 <> '') then
        LogPrint(Err45);
    end;

    //การเลือกชิปจากรายการจะล้างสิ่งที่รู้เกี่ยวกับชิปตัวเก่าทิ้ง
    //ซึ่งรวมถึงสิ่งที่เพิ่งอ่านมาจากชิปตัวจริงเมื่อครู่นี้ด้วย
    //เก็บไว้ก่อน แล้วค่อยใส่กลับหลังเลือกเสร็จ
    ManufSaved := Chip25ManufID;

    ExitProgMode25;
    AsProgrammer.Programmer.DevClose;

    //คำสั่งที่ไม่ได้คำตอบต้องขึ้นว่า -- ไม่ใช่ค่าที่ค้างอยู่ในบัฟเฟอร์
    //และต้องไม่เอาไปค้นในตารางชิปด้วย เพราะมันไม่ใช่รหัสที่ชิปบอกมา
    if ID.Got9F then
      IDstr9FH := Upcase(IntToHex(ID.ID9FH[0], 2)+IntToHex(ID.ID9FH[1], 2)+IntToHex(ID.ID9FH[2], 2))
    else
      IDstr9FH := '--';
    if ID.Got90 then
      IDstr90H := Upcase(IntToHex(ID.ID90H[0], 2)+IntToHex(ID.ID90H[1], 2))
    else
      IDstr90H := '--';
    if ID.GotAB then
      IDstrABH := Upcase(IntToHex(ID.IDABH, 2))
    else
      IDstrABH := '--';
    if ID.Got15 then
      IDstr15H := Upcase(IntToHex(ID.ID15H[0], 2)+IntToHex(ID.ID15H[1], 2))
    else
      IDstr15H := '--';

    LogPrint('ID(9F): '+ IDstr9FH);
    LogPrint('ID(90): '+ IDstr90H);
    LogPrint('ID(AB): '+ IDstrABH);
    LogPrint('ID(15): '+ IDstr15H);

    //ทั้ง 00 หรือทั้ง FF แปลว่าไม่มีชิปตอบกลับ ไม่ต้องไปค้นฐานข้อมูลให้เสียเวลา
    if IsDeadID(ID.ID9FH) then
    begin
      LogPrint(STR_NO_CHIP);
      if FastSPIClockWarning <> '' then
        LogPrint(Format(STR_NO_CHIP_CLOCK, [FastSPIClockWarning]));

      //ความเงียบบนบอร์ดที่สลับแรงดันได้มีคำอธิบายเพิ่มอีกทาง: แรงดันไม่ตรง
      //กับชิป บอกทางต่อจากระดับที่เพิ่งใช้แหย่ไป แต่ห้ามยกแรงดันให้เอง
      //เพราะชิป 1.8V ที่แค่หนีบไม่แน่นจะพังคาที่ถ้าเดาผิด
      if ProbeMv = CH347_VCC_1V8_MV then
      begin
        //บอกในล็อก ไม่เด้งกล่องถาม
        //
        //ซ็อกเก็ตว่างคือสถานะปกติก่อนเสียบชิป กล่องนี้จึงเด้งตั้งแต่ยังไม่มี
        //ใครทำอะไร แล้วบังหน้าต่างหลักไว้ ต้องกดปิดทิ้งทุกครั้ง
        //
        //ปุ่ม "ใช่" ของมันคือปักแรงดันขึ้น 3.3V ให้เลย ซึ่งเป็นการเดาแทนผู้ใช้
        //ในทิศที่ทำชิปพังพอดี ถ้าของจริงเป็นชิป 1.8V ที่แค่หนีบไม่แน่น
        //คำแนะนำอยู่ในล็อกครบแล้ว ให้เขาไปเลือกเองที่ตัวเลือกแรงดันดีกว่า
        LogPrint(STR_CH347_DEAD_1V8);
        LogPrint(STR_CH347_VCC_GUIDE);
      end
      else if ProbeMv = CH347_VCC_3V3_MV then
      begin
        LogPrint(STR_CH347_DEAD_3V3);
        LogPrint(STR_CH347_VCC_GUIDE);
      end;

      OpFail('no chip answered');
      Exit;
    end;

    //เก็บรหัสไว้ใช้ตอนบันทึกชิปใหม่ลงตารางของผู้ใช้
    LastID9F := IDstr9FH;

    Vendor := JedecVendor(ID.ID9FH[0]);
    if Vendor <> '' then LogPrint(STR_VENDOR + Vendor);

    Matches := TStringList.Create;
    try
      //The same model can exist in the native, imported EZP and IMSProg
      //catalogues.  Count physical model names, not source-file duplicates.
      Matches.CaseSensitive := False;
      Matches.Sorted := True;
      Matches.Duplicates := dupIgnore;
      //ไล่จาก 9F ก่อน แล้วค่อยลองโอปโค้ดเก่ากว่าถ้ายังไม่เจอ
      //ค้นทั้งไฟล์หลักและไฟล์เสริมพร้อมกัน
      FindChipInto(ChipListFile, '', IDstr9FH, Matches);
      FindChipInto(ChipListFile2, '', IDstr9FH, Matches);
      FindChipInto(ChipListFile3, '', IDstr9FH, Matches);
      FindChipInto(ChipListFile4, '', IDstr9FH, Matches);
      FindChipInto(ChipListFile5, '', IDstr9FH, Matches);

      if Matches.Count = 0 then
      begin
        FindChipInto(ChipListFile, '', IDstr90H, Matches);
        FindChipInto(ChipListFile2, '', IDstr90H, Matches);
        FindChipInto(ChipListFile3, '', IDstr90H, Matches);
        FindChipInto(ChipListFile4, '', IDstr90H, Matches);
        FindChipInto(ChipListFile5, '', IDstr90H, Matches);
      end;

      if Matches.Count = 0 then
      begin
        FindChipInto(ChipListFile, '', IDstrABH, Matches);
        FindChipInto(ChipListFile2, '', IDstrABH, Matches);
        FindChipInto(ChipListFile3, '', IDstrABH, Matches);
        FindChipInto(ChipListFile4, '', IDstrABH, Matches);
        FindChipInto(ChipListFile5, '', IDstrABH, Matches);
      end;

      if Matches.Count = 0 then
      begin
        FindChipInto(ChipListFile, '', IDstr15H, Matches);
        FindChipInto(ChipListFile2, '', IDstr15H, Matches);
        FindChipInto(ChipListFile3, '', IDstr15H, Matches);
        FindChipInto(ChipListFile4, '', IDstr15H, Matches);
        FindChipInto(ChipListFile5, '', IDstr15H, Matches);
      end;

      if Matches.Count = 1 then
      begin
        //ตรงตัวเดียว เลือกให้เลย ไม่ต้องให้ผู้ใช้มากดซ้ำ
        ChipName := Matches[0];
        ChipName := Copy(ChipName, 1, Pos(' (', ChipName) - 1);
        SelectChipAny(ChipName);
        LogPrint(STR_DETECT_ONE + ChipName);
        //ชิปในซ็อกเก็ตตอบรหัสมาเอง และรหัสนั้นชี้ไปที่ชิ้นนี้ชิ้นเดียว
        //ต่างจากการที่ผู้ใช้เลือกชื่อจากเมนูเอง ซึ่งไม่ได้พิสูจน์อะไรเลย
        ChipIdentityConfirmed := True;
      end
      else if Matches.Count > 1 then
      begin
        LogPrint(Format(STR_DETECT_MANY, [Matches.Count]));
        //One JEDEC code commonly covers several die revisions/suffixes.  On
        //automatic EZP startup, opening a modal-looking chooser defeats
        //automatic detection even though the common programming geometry is
        //known.  Prefer an entry in the JEDEC manufacturer group, apply its
        //compatible geometry, and label it honestly as a family—not an exact
        //suffix.  A manual Read ID still shows every candidate.
        if (AsProgrammer.Current_HW = CHW_EZP) and
           (AutomaticChipDetection or CLIMode) then
        begin
          VendorMatchCount := 0;
          VendorMatchIndex := -1;
          MatchVendor := ' (' + UpperCase(Vendor) + ')';
          for p := 0 to Matches.Count - 1 do
            if EndsText(MatchVendor, UpperCase(Matches[p])) then
            begin
              Inc(VendorMatchCount);
              if VendorMatchIndex < 0 then VendorMatchIndex := p;
            end;
          if VendorMatchIndex < 0 then
          begin
            VendorMatchIndex := 0;
            VendorMatchCount := Matches.Count;
          end;

          ChipName := Matches[VendorMatchIndex];
          p := Pos(' (', ChipName);
          if p > 0 then ChipName := Copy(ChipName, 1, p - 1);
          if SelectChipAny(ChipName) then
          begin
            if Vendor = '' then Vendor := 'JEDEC';
            FamilyName := Format('%s %s compatible family (%d profiles)',
              [Vendor, IDstr9FH, VendorMatchCount]);
            CurrentICParam.Name := FamilyName;
            LabelChipName.Caption := FamilyName;
            //แรงดันเอาจากโปรไฟล์ที่เพิ่งโหลด: รหัส JEDEC แยกตระกูลแรงดัน
            //อยู่แล้ว (เช่น EF40xx = 3.3 V, EF60xx = 1.8 V) ห้ามเขียนทับ
            //ด้วยค่าตายตัว ไม่งั้นชิป 1.8 V หลุดด่าน VoltageWarningOK แล้ว
            //โดนราง 3.3 V ของ EZP พังคาซ็อกเก็ต ถ้าโปรไฟล์ตัวแทนไม่ระบุ
            //ให้ดูชื่อสมาชิกตระกูลทั้งหมด: มีใครบอก 1.8 ก็ถือว่า 1.8 ไว้
            //ก่อน (เตือนเกินดีกว่าเตือนขาด)
            if CurrentICParam.Vcc = '' then
              for p := 0 to Matches.Count - 1 do
                if Pos('1.8', Matches[p]) > 0 then
                begin
                  CurrentICParam.Vcc := '1.8';
                  Break;
                end;
            CurrentICParam.Note := Format(
              'JEDEC %s does not distinguish the exact package/die suffix. ' +
              'Compatible programming geometry was loaded from %s.',
              [IDstr9FH, ChipName]);
            ChipIdentityConfirmed := True;
            UpdateChipInfo;
            LogPrint('Automatic family profile: ' + FamilyName + '; exact ' +
                     'suffix remains intentionally unspecified');
          end
          else
          begin
            //โปรไฟล์ตัวแทนโหลดไม่ขึ้น อย่าแปะป้าย family ทับค่าของชิปตัว
            //เก่าที่ยังค้างอยู่ เปิดหน้าต่างเลือกเองตามปกติแทน
            LogPrint('the family representative "' + ChipName + '" could ' +
                     'not be loaded from the chip lists; pick the part ' +
                     'manually');
            if not CLIMode then
            begin
              ChipSearchForm.EditSearch.Text := '';
              ChipSearchForm.ListBoxChips.Items.Assign(Matches);
              ChipSearchForm.Show;
            end;
          end;
        end
        else if CLIMode then
          //โหมดบรรทัดคำสั่งไม่มีใครอยู่คลิกหน้าต่างเลือก บอกทางแก้ใน log แทน
          LogPrint('several chips share this id; pass --chip <name> to pick ' +
                   'the exact part')
        else
        begin
          ChipSearchForm.EditSearch.Text := '';
          ChipSearchForm.ListBoxChips.Items.Assign(Matches);
          ChipSearchForm.Show;
        end;
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

    //เพจของ DataFlash เอาจากชิปตัวจริง ไม่ใช่จากตาราง: ชิปเดียวกันอาจถูกสลับ
    //เป็นโหมด binary ถาวรไปแล้ว ซึ่งตาราง XML ไม่มีทางรู้
    if AT45Known then
    begin
      if P2_45 then Mode45 := 'binary (power-of-2)'
      else Mode45 := 'standard DataFlash';
      LogPrint(Format('%s: %d pages of %d bytes (%s page mode), %d bytes',
                      [Geo45.Family, Geo45.Pages, Page45, Mode45, Total45]));
      if ComboPageSize.Text <> IntToStr(Page45) then
      begin
        if IsNumber(ComboPageSize.Text) then
          LogPrint(Format('page size %s does not match the chip; set to %d',
                          [ComboPageSize.Text, Page45]));
        ComboPageSize.Text := IntToStr(Page45);
      end;
      if ComboChipSize.Text <> IntToStr(Total45) then
        ComboChipSize.Text := IntToStr(Total45);
    end;

    //ใส่สิ่งที่อ่านมาจากชิปตัวจริงกลับเข้าไป การเลือกรายการอาจล้างมันไปแล้ว
    //ถึงชิปจะมีในตารางอยู่แล้ว วิธีเข้าโหมด 4 ไบต์ก็ยังต้องเอาจาก SFDP
    //เพราะตารางชิปไม่ได้เก็บเรื่องนี้ไว้ และมันต่างกันไปตามยี่ห้อ
    Chip25ManufID := ManufSaved;
    if SfdpOK then
      ApplySFDPHints(Info)
    else
      Chip25SFDPRead := True;

  finally
    //ทางออกกลางคัน (KB9012, ไม่มีชิปตอบ) เคยทิ้งอุปกรณ์เปิดค้างไว้จนงาน
    //ถัดไปมาเปิดทับ DevClose ซ้ำบนอุปกรณ์ที่ปิดแล้วไม่มีผลข้างเคียง
    AsProgrammer.Programmer.DevClose;
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
    NoteBufferFromFile(OpenDialog.FileName);
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
    NoteBufferFromFile(OpenDialog.FileName);
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
    OpFail('the chip size, the page size or the range is not usable');
    exit;
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

    ReportDiff(A, B, Size);

    //ไม่ยุ่งกับตารางกลาง เพราะบัฟเฟอร์ที่ผู้ใช้เตรียมไว้ไม่เกี่ยวกับสองไฟล์นี้
    ShowCompareWindow(ExtractFileName(F1) + '   ' + IntToStr(S1.Size) + ' bytes',
                      ExtractFileName(F2) + '   ' + IntToStr(S2.Size) + ' bytes',
                      A, B, Size);
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
  //ไม่มี OpBegin = แผง telemetry จะยืม LastOp ของงานก่อนมาคิดสถิติผิด ๆ
  OpBegin(opkNone);

  S1 := TMemoryStream.Create;
  S2 := TMemoryStream.Create;
try
  ButtonCancel.Tag := 0;
  if not OpenDevice() then Exit;
  LockControl();

  if OpUI.ChipSize = 0 then
  begin
    LogPrint(STR_CHECK_SETTINGS);
    OpFail('the chip size, the page size or the range is not usable');
    exit;
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

  ReportDiff(A, B, Size);
  ShowCompareWindow('first chip   ' + CurrentICParam.Name,
                    'second chip   ' + CurrentICParam.Name,
                    A, B, Size);

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
  begin
    LogPrint(STR_PROD_SAVED);
    //ไฟล์งานอาจเพิ่งถูกตั้งหรือถูกเปลี่ยน อ่านใหม่ทันที
    RefreshJobFile;
  end;
end;

//บันทึกผลการผลิตทีละชิ้นลงไฟล์ CSV เปิดด้วย Excel ได้เลย
//งานผลิตจริงต้องตามรอยได้ว่าชิ้นไหนผ่านหรือไม่ผ่าน และได้เลขอะไรไป
procedure LogProduction(UnitNo: integer; Passed: boolean);
const
  FileName = 'production.csv';
var
  F: TextFile;
  IsNew: boolean;
  SerialText: string;
begin
  try
    IsNew := not FileExists(FileName);
    AssignFile(F, FileName);
    if IsNew then Rewrite(F) else Append(F);
    try
      if IsNew then
        WriteLn(F, 'timestamp,unit,chip,id,serial,result');

      SerialText := '';
      if CurrentSerialValid then SerialText := CurrentSerial.Text;
      WriteLn(F, Format('%s,%d,%s,%s,%s,%s', [
        FormatDateTime('yyyy-mm-dd hh:nn:ss', Now),
        UnitNo,
        CurrentICParam.Name,
        CurrentICParam.ID,
        SerialText,
        BoolToStr(Passed, 'PASS', 'FAIL')]));
    finally
      CloseFile(F);
    end;
  except
    on E: Exception do
    begin
      LogPrint('Cannot write production.csv');
      OpFail('batch evidence could not be written: ' + E.Message);
    end;
  end;
end;
//การผลิตเป็นชุด: เขียนชิปทีละตัวแล้วนับผลลัพธ์
//แต่ละรอบคือ ปลดล็อก ลบ แล้วเขียนพร้อมตรวจสอบ
procedure TMainForm.MenuRunBatchClick(Sender: TObject);
var
  Done, Passed, Failed: integer;
  Reply: integer;
  CheckTemp: boolean;
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

    if RadioSPI.Checked and (ComboSPICMD.ItemIndex = SPI_CMD_25) then
      MenuSmartWriteClick(ComboItem1)
    else
    begin
      //Batch output may never be counted as PASS without an exact readback.
      CheckTemp := MenuAutoCheck.Checked;
      MenuAutoCheck.Checked := True;
      try
        if ButtonBlock.Enabled then
        begin
          ButtonBlockClick(ComboItem1);
          if not OpOK then
          begin
            Inc(Done);
            Inc(Failed);
            LogPrint(Format(STR_BATCH_UNIT_FAIL, [Done]));
            LogProduction(Done, False);
            Continue;
          end;
        end;

        ButtonEraseClick(ComboItem1);
        if OpOK then ButtonWriteClick(ComboItem1);
      finally
        MenuAutoCheck.Checked := CheckTemp;
      end;
    end;

    Inc(Done);

    //ตัดสินจากผลลัพธ์แบบ typed เท่านั้น Tag เป็นเพียง compatibility flag
    //ของสคริปต์เก่า และไม่สามารถบอก verify mismatch หรือ short transfer ได้
    if not OpOK then
    begin
      Inc(Failed);
      LogPrint(Format(STR_BATCH_UNIT_FAIL, [Done]));
      LogProduction(Done, False);
    end
    else
    begin
      LogProduction(Done, True);
      if OpOK then
      begin
        Inc(Passed);
        LogPrint(Format(STR_BATCH_UNIT_OK, [Done]));
      end
      else
      begin
        Inc(Failed);
        LogPrint(Format(STR_BATCH_UNIT_FAIL, [Done]));
      end;
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
  SR1, SR2, CR: byte;
  HaveCR: boolean;
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

  //หน้าจอสรุปนี้ต้องตีความด้วยแผนผังของยี่ห้อจริง ไม่ใช่สมมุติเป็น Winbond
  //ไม่งั้นชิป Macronix ที่ล็อกครึ่งบนจะถูกสรุปว่าล็อกนิดเดียว
  EnsureChipHints;
  HaveCR := ReadVendorCR(Chip25ManufID, SR2, CR);
  if SR2 = $FF then SR2 := 0;

  LogPrint(Format(STR_PROT_HEADER, [SR1, SR2]));
  P := DecodeProtVendor(Chip25ManufID, SR1, SR2, CR, HaveCR);
  LogPrint(ProtToText(P));
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

  //ไม่มีกล่องข้อความเด้งแล้ว เพราะหน้าต่างเทียบที่เปิดตามมาบอกสรุปไว้บนหัว
  //อยู่แล้ว กล่องซ้อนขึ้นมาอีกชั้นมีแต่ต้องกดปิดทิ้งเปล่า ๆ
  Result := DiffCount;
end;

//ทำเครื่องหมายไบต์ที่ต่างลงในตารางกลาง ใช้ตอนเทียบบัฟเฟอร์กับชิป
//MPHexEditor จะระบายสีไบต์ที่มีเครื่องหมายนี้ด้วย ChangedText/ChangedBackground
//ต้องใช้ ByteChanged ไม่ใช่เขียนข้อมูลทับทีละไบต์ เพราะการเขียนไม่ได้ตั้งบิตนี้
//แถมยังสร้างรายการย้อนกลับทีละไบต์จนช้า
procedure MarkDiffInEditor(const A, B: array of byte; Size: integer);
var
  i, FirstDiff: integer;
begin
  //ตารางกลางถืออยู่ฝั่ง A แล้ว จึงแค่ทำเครื่องหมาย ไม่โหลดทับ
  //ถ้าโหลดทับ บัฟเฟอร์ที่ผู้ใช้เตรียมไว้จะหายไปโดยไม่ได้ตั้งใจ
  if MainForm.MPHexEditorEx.DataSize < Size then Exit;

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
      OpFail('the chip size, the page size or the range is not usable');
      exit;
    end;

    EnterProgModeI2C();
    I2C_DevAddr := SetI2CDevAddr();

    if UsbAspI2C_BUSY(I2C_DevAddr) then
    begin
      LogPrint(STR_I2C_NO_ANSWER);
      OpFail('the I2C EEPROM did not acknowledge its address');
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
      OpFail('the chip size, the page size or the range is not usable');
      exit;
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
            OpFail('the chip size, the page size or the range is not usable');
            exit;
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
    OpFail('the chip size, the page size or the range is not usable');
    exit;
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

  ReportDiff(A, B, Size);

  //ตารางกลางถือบัฟเฟอร์อยู่แล้ว จึงทำเครื่องหมายลงไปได้เลยโดยไม่ทับข้อมูล
  MarkDiffInEditor(A, B, Size);

  //หน้าต่างเทียบวางบัฟเฟอร์ไว้ซ้าย ชิปไว้ขวา ตามลำดับที่คนอ่านเข้าใจง่ายกว่า
  ShowCompareWindow('buffer   ' + IntToStr(Size) + ' bytes',
                    'chip   ' + CurrentICParam.Name,
                    B, A, Size);

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
  RequestOperationCancellation;
  if ActiveNORCancellation <> nil then
    ActiveNORCancellation.RequestCancellation;
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
      s.Add('Chipwright is built on the work of:');
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
      s.Add('Chipwright');
      s.Add('Version ' + PROX_VERSION);
      s.Add('');
      s.Add('Serial flash and EEPROM programmer for SPI, I2C and MicroWire.');
      s.Add('https://github.com/patnawa/Chipwright');
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
      if ChipListFile4 <> nil then
        s.Add('chiplist-ezp.xml       ' + IntToStr(CountChips(ChipListFile4)) +
              ' chips  (converted from an EZP database)');
      if ChipListFile5 <> nil then
        s.Add('chiplist-imsprog.xml   ' + IntToStr(CountChips(ChipListFile5)) +
              ' chips  (converted from IMSProg, GPL-3+)');
      if ChipListFile3 <> nil then
        s.Add('chiplist-user.xml      ' + IntToStr(CountChips(ChipListFile3)) +
              ' chips  (added by you)');
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
    'Chipwright ' + PROX_VERSION + LineEnding +
    'https://github.com/patnawa/Chipwright' + LineEnding + LineEnding +
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
var
  Parsed: QWord;
  Cleaned: string;
  c: char;
begin
  //Hex2Dec ยกข้อยกเว้นเมื่อเจอข้อความที่ไม่ใช่เลขฐานสิบหก ซึ่งเข้ามาได้ทาง
  //การวาง (ตัวกรองปุ่มกดกันได้แค่การพิมพ์) แล้วข้อยกเว้นที่หลุดหลัง OpBegin
  //จะจบงานโดยไม่มี OpFail = สรุป "OK" + แถว PASS ใน production log ทั้งที่
  //ไม่ได้เขียนอะไรเลย จึงล้างทิ้งที่ต้นทางที่เดียว: เก็บเฉพาะเลขฐานสิบหก
  //และจำกัดแปดหลัก ซึ่งครอบแอดเดรส 32 บิตทั้งหมดแล้ว
  Cleaned := '';
  for c in UpperCase(Trim(StartAddressEdit.Text)) do
    if (c in ['0'..'9', 'A'..'F']) and (Length(Cleaned) < 8) then
      Cleaned := Cleaned + c;
  if Cleaned = '' then Cleaned := '0';
  if Cleaned <> StartAddressEdit.Text then
  begin
    //การแก้ Text เรียก OnChange ซ้ำหนึ่งรอบ ซึ่งรอบนั้นไม่มีอะไรให้แก้แล้ว
    StartAddressEdit.Text := Cleaned;
    Exit;
  end;
  if not TryStrToQWord('$' + Trim(StartAddressEdit.Text), Parsed) then
    Parsed := 0;
  if Parsed > 0 then
     StartAddressEdit.Color:= clYellow
  else
     StartAddressEdit.Color:= clDefault;
  //แถบ Safe workflow ตรวจว่าภาพลงชิปได้จากแอดเดรสนี้หรือไม่ จึงต้องรู้ตัว
  //ทุกครั้งที่แอดเดรสเปลี่ยน
  UpdateWorkflowState;
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
  AsProgrammer.AddHW(TSerprogHardware.Create);
  AsProgrammer.AddHW(TEZPHardware.Create);

  SelectHW(CHW_BUZZPIRAT); // ทางลัดแบบหยาบ ๆ ของ dreg

  LoadChipList(ChipListFile);
  LoadChipList(ChipListFile2);
  LoadChipList(ChipListFile3);
  LoadChipList(ChipListFile4);
  LoadChipList(ChipListFile5);
  RomF := TMemoryStream.Create;
  ScriptEngine := TPasCalc.Create;
  ScriptsFunc.SetScriptFunctions(ScriptEngine);

  MPHexEditorEx.NoSizeChange := true;
  MPHexEditorEx.InsertMode := false;
  DefaultProdSettings(ProdSettings);
  LoadOptions(SettingsFile);
  RefreshJobFile;
  LoadLangList();

  //เลขเวอร์ชันมาจาก appver ที่เดียว แถบชื่อหน้าต่างกับ log จึงไม่มีวันค้างเลขเก่า
  Caption := 'Chipwright ' + PROX_VERSION;
  if Log.Lines.Count > 0 then
    Log.Lines[0] := 'Chipwright ' + PROX_VERSION;

  LoadModernIcons;
  CreateWorkflowBar;
  CreateTelemetryPanel;
  LayoutLeftPanel;
  ApplyTheme(MenuDarkTheme.Checked);
  UpdateChipInfo;

  //ค้นหาเครื่องโปรแกรมที่เสียบอยู่ตั้งแต่เปิดโปรแกรม แล้วเฝ้าดูต่อเป็นระยะ
  SetHardwareMenuCheck(AsProgrammer.Current_HW);
  PollProgrammer(True, True);
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

  //ตั้งแต่นี้ไปเปิดไดอะล็อกได้แล้ว
  //ถ้าเสียบเครื่องโปรแกรมมาตั้งแต่ก่อนเปิดโปรแกรม จังหวะเปลี่ยนสถานะผ่านไปแล้ว
  //จึงต้องตรวจชิปให้หนึ่งครั้งตรงนี้เอง
  AppReady := True;
  if ProgrammerPresent and MenuAutoDetectChip.Checked and RadioSPI.Checked then
  begin
    AutomaticChipDetection := True;
    try
      ButtonReadIDClick(nil);
    finally
      AutomaticChipDetection := False;
    end;
  end;

  //The first-run doctor is deliberately delayed until the form is visible:
  //its modal results window and driver guidance must never appear while LCL
  //is still constructing controls.  It remains available from Options.
  if (not CLIMode) and (not ConnectionDoctorSeen) then
    MenuConnectionDoctorClick(nil);
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
    NoteBufferFromFile(FileNames[0]);
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
    NoteBufferFromFile(FileNames[0]);
    LogPrint(STR_FILE_LOADED + ExtractFileName(FileNames[0]));
  finally
    Stream.Free;
  end;
end;

//ปุ่มลัดของเส้นทางหลักมีอยู่ทั้งในคำใบ้บนปุ่มและตรงนี้ ผู้ใช้จึงทำงานซ้ำ ๆ
//ได้โดยไม่ต้องเล็งไอคอนเล็ก ๆ ส่วน ESC ยังคงเป็นการขอยกเลิกแบบปลอดภัย:
//คำสั่ง erase/program ที่ส่งไปแล้วจะรอจนชิปกลับมาว่างก่อนหยุด
procedure TMainForm.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key = VK_ESCAPE then
  begin
    if OperationRunning then
    begin
      ButtonCancel.Tag := 1;
      RequestOperationCancellation;
      if ActiveNORCancellation <> nil then
        ActiveNORCancellation.RequestCancellation;
      Key := 0;
    end;
  end
  else if Key = VK_F1 then
  begin
    DebugconsoleMenuItemClick(Sender);
    Key := 0;
  end
  else if (Key = VK_F5) and FWorkflowDetect.Enabled then
  begin
    ButtonReadIDClick(Sender);
    Key := 0;
  end
  else if (ssCtrl in Shift) and not (ssShift in Shift) and
          (Key = Ord('O')) and FWorkflowOpen.Enabled then
  begin
    ButtonOpenHexClick(Sender);
    Key := 0;
  end
  else if (ssCtrl in Shift) and not (ssShift in Shift) and
          (Key = Ord('S')) and ButtonSaveHex.Enabled then
  begin
    ButtonSaveHexClick(Sender);
    Key := 0;
  end
  else if (ssCtrl in Shift) and not (ssShift in Shift) and
          (Key = Ord('R')) and FWorkflowRead.Enabled then
  begin
    ButtonReadClick(Sender);
    Key := 0;
  end
  else if (ssCtrl in Shift) and (ssShift in Shift) and
          (Key = Ord('P')) and FWorkflowSmart.Enabled then
  begin
    MenuSmartWriteClick(Sender);
    Key := 0;
  end
  else if (ssCtrl in Shift) and (ssShift in Shift) and
          (Key = Ord('V')) and FWorkflowVerify.Enabled then
  begin
    ButtonVerifyClick(Sender);
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
  ChipListFile3.Free;
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
  OpBegin(opkRead);
try
  ButtonCancel.Tag := 0;
  if not OpenDevice() then
  begin
    OpFail('the programmer could not be opened');
    exit;
  end;
  LockControl();

  if RunScriptFromFile(CurrentICParam.Script, 'read') then Exit;

  LogPrint(TimeToStr(Time()));

  if (not IsNumber(ComboChipSize.Text)) then
  begin
    LogPrint(STR_CHECK_SETTINGS);
    OpFail('the chip size is not a number');
    Exit;
  end;

  //SPI
  if RadioSPI.Checked then
  begin
    if not VoltageWarningOK then
    begin
      OpFail('aborted because of the supply voltage');
      Exit;
    end;
    EnterProgMode25(SetSPISpeed(0), MainForm.MenuSendAB.Checked);
    if MenuResetChip.Checked and (ComboSPICMD.ItemIndex = SPI_CMD_25) then
    begin
      LogPrint(STR_RESETTING);
      UsbAsp25_SoftReset;
    end;
    if not ContactIsStable then Exit;
    if not VerifyChipID then
    begin
      OpFail('the chip in the socket does not match the selected one');
      Exit;
    end;
    EnsureChipHints;
    TimeCounter := Time();

    if  ComboSPICMD.ItemIndex = SPI_CMD_KB then
    begin
      ReadFlashKB(RomF, 0, StrToInt(ComboChipSize.Text));
    end;

    if  ComboSPICMD.ItemIndex = SPI_CMD_25 then
    begin
      ReadFlash25(RomF, Hex2Dec('$'+StartAddressEdit.Text), StrToInt(ComboChipSize.Text));

      //อ่านซ้ำแล้วเทียบ ก่อนจะเอาผลไปโชว์หรือไปเซฟ
      if OpOK and (OpUI.ReadPasses > 1) then
        ReadPassesAgree(RomF, Hex2Dec('$'+StartAddressEdit.Text),
                        StrToInt(ComboChipSize.Text), OpUI.ReadPasses);

      if OpOK then ScanDumpAndReport(RomF);
    end;
    if  ComboSPICMD.ItemIndex = SPI_CMD_45 then
    begin
      if (not IsNumber(ComboPageSize.Text)) then
      begin
        LogPrint(STR_CHECK_SETTINGS);
        OpFail('the chip size, the page size or the range is not usable');
        exit;
      end;
      ReadFlash45(RomF, 0, StrToInt(ComboPageSize.Text), StrToInt(ComboChipSize.Text));
    end;

    if  ComboSPICMD.ItemIndex = SPI_CMD_95 then
      ReadFlash95(RomF, Hex2Dec('$'+StartAddressEdit.Text), StrToInt(ComboChipSize.Text));

    if OpOK then
    begin
      RomF.Position := 0;
      MPHexEditorEx.LoadFromStream(RomF);
      StatusBar.Panels.Items[2].Text := LabelChipName.Caption;
    end;
  end;
  //I2C
  if RadioI2C.Checked then
  begin
    if ComboAddrType.ItemIndex < 0 then
    begin
      LogPrint(STR_CHECK_SETTINGS);
      OpFail('the chip size, the page size or the range is not usable');
      exit;
    end;

    EnterProgModeI2c();

    //แอดเดรสของชิปตามช่องติ๊ก
    I2C_DevAddr := SetI2CDevAddr();

    if CheckBox_I2C_ByteRead.Checked then I2C_ChunkSize := 1;

    if UsbAspI2C_BUSY(I2C_DevAddr) then
    begin
      LogPrint(STR_I2C_NO_ANSWER);
      OpFail('the I2C EEPROM did not acknowledge its address');
      exit;
    end;
    TimeCounter := Time();
    ReadFlashI2C(RomF, Hex2Dec('$'+StartAddressEdit.Text), StrToInt(ComboChipSize.Text), I2C_ChunkSize, I2C_DevAddr);

    if OpOK then
    begin
      RomF.Position := 0;
      MPHexEditorEx.LoadFromStream(RomF);
      StatusBar.Panels.Items[2].Text := LabelChipName.Caption;
    end;
  end;
  //Microwire
  if RadioMw.Checked then
  begin
    if (not IsNumber(ComboMWBitLen.Text)) then
    begin
      LogPrint(STR_CHECK_SETTINGS);
      OpFail('the chip size, the page size or the range is not usable');
      exit;
    end;

    if not AsProgrammer.Programmer.MWInit(SetSPISpeed(0)) then
    begin
      OpFail('the programmer could not initialize the MicroWire bus');
      Exit;
    end;
    TimeCounter := Time();
    ReadFlashMW(RomF, StrToInt(ComboMWBitLen.Text), 0, StrToInt(ComboChipSize.Text));

    if OpOK then
    begin
      RomF.Position := 0;
      MPHexEditorEx.LoadFromStream(RomF);
      StatusBar.Panels.Items[2].Text := LabelChipName.Caption;
    end;
  end;

  if not OpOK then Exit;
  LogPrint(STR_TIME + TimeToStr(Time() - TimeCounter));

  //ทุกโปรโตคอลมาบรรจบที่นี่ เป็นจุดเดียวที่รู้ว่าการอ่านทั้งตัวสำเร็จแล้ว
  //จึงเป็นที่ที่ควรจำว่าชิปตัวนี้เปล่าหรือมีข้อมูล และบัฟเฟอร์มาจากชิป
  RememberChipContent(RomF);
  BufferSource := bsChip;
  BufferSourceName := CurrentICParam.Name;
  UpdateWorkflowState;

  CRC32 := UpdateCRC32($FFFFFFFF, Romf.Memory, Romf.Size);
  LogPrint('CRC32 = 0x'+IntToHex(CRC32, 8));

finally
  LogPrint(STR_OP_RESULT + OpSummary);
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
  //ขอยกเลิกเฉพาะเมื่อมีงานเดินอยู่จริง: CancelEvent เป็นแบบ manual-reset
  //และถูกล้างแค่ตอน LockControl การตั้งมันตอนไม่มีงาน (เช่นปิดหน้าต่าง
  //แล้วเปลี่ยนใจ) จะทำให้งานถัดไปเจอ "ผู้ใช้ยกเลิก" ค้างอยู่ตั้งแต่วินาทีแรก
  if OperationRunning then
  begin
    ButtonCancel.Tag := 1;
    RequestOperationCancellation;
    if ActiveNORCancellation <> nil then
      ActiveNORCancellation.RequestCancellation;

    //ในโหมดเบื้องหลังหน้าต่างยังใช้งานได้ จึงปิดได้ทั้งที่ยังคุยกับชิปอยู่
    //ต้องรอให้งานที่ทำอยู่จบก่อน
    CanClose := False;
    Exit;
  end;

  ScriptEditForm.FormCloseQuery(Sender, CanClose);
end;

procedure TMainForm.ButtonEraseClick(Sender: TObject);
var
  I2C_DevAddr: byte;
begin
  //EZP2023+ มีคำสั่ง native erase ของเฟิร์มแวร์เอง แล้วอ่านกลับตรวจ FF
  //ทุกไบต์ การเขียนภาพ FF ใช้แทนไม่ได้เพราะเฟิร์มแวร์ข้ามเพจ FF
  if RadioSPI.Checked and (ComboSPICMD.ItemIndex = SPI_CMD_25) and
     (AsProgrammer.Current_HW = CHW_EZP) then
  begin
    if Sender <> ComboItem1 then
      if MessageDlg('AsProgrammer', STR_START_ERASE, mtConfirmation,
           [mbYes, mbNo], 0) <> mrYes then
      begin
        OpBegin(opkErase);
        OpCancel;
        Exit;
      end;
    RunEZPWholeChipWrite(True);
    Exit;
  end;

  OpBegin(opkErase);
  //ชิปกำลังจะถูกเปลี่ยนเนื้อใน ความรู้เดิมว่า "เปล่า" หรือ "มีข้อมูล"
  //ใช้ต่อไม่ได้อีก ไม่งั้นการเขียนรอบถัดไปจะอ้างสถานะก่อนเขียนรอบนี้
  ForgetChipContent;
try
  ButtonCancel.Tag := 0;
  if not OpenDevice() then
  begin
    OpFail('the programmer could not be opened');
    exit;
  end;
  if Sender <> ComboItem1 then
    if MessageDlg('AsProgrammer', STR_START_ERASE, mtConfirmation, [mbYes, mbNo], 0)
      <> mrYes then
    begin
      OpCancel;
      Exit;
    end;
  LockControl();

  //Destructive SPI scripts are deferred until the built-in preflight below.
  if (not RadioSPI.Checked) and (not MenuAutoBackup.Checked) and
     RunScriptFromFile(CurrentICParam.Script, 'erase') then Exit;

  LogPrint(TimeToStr(Time()));

  //SPI
  if RadioSPI.Checked then
  begin
    if not VoltageWarningOK then
    begin
      OpFail('aborted because of the supply voltage');
      Exit;
    end;
    EnterProgMode25(SetSPISpeed(0), MainForm.MenuSendAB.Checked);
    if MenuResetChip.Checked and (ComboSPICMD.ItemIndex = SPI_CMD_25) then
    begin
      LogPrint(STR_RESETTING);
      UsbAsp25_SoftReset;
    end;

    //ตรวจว่าการเชื่อมต่อนิ่งก่อนจะไปแตะข้อมูล
    //เขียนหรือลบผ่านคลิปที่หลวมคือทางที่ตรงที่สุดไปสู่ชิปที่พัง
    if not ContactIsStable then Exit;

    if not VerifyChipID then
    begin
      OpFail('the chip in the socket does not match the selected one');
      Exit;
    end;

    EnsureChipHints;

    //ลบทั้งชิปแตะทุกไบต์ ด่านตรวจจึงครอบทั้งชิป
    if (ComboSPICMD.ItemIndex = SPI_CMD_25) and (OpUI.ChipSize > 0) then
      if not ProtectionGuardOK(0, OpUI.ChipSize) then Exit;

    if not AutoBackupChip then
    begin
      OpFail('the backup could not be made');
      Exit;
    end;
    if RunScriptFromFile(CurrentICParam.Script, 'erase') then Exit;

    if ComboSPICMD.ItemIndex <> SPI_CMD_KB then
      IsLockBitsEnabled;
    TimeCounter := Time();

    LogPrint(STR_ERASING_FLASH);

    if ComboSPICMD.ItemIndex = SPI_CMD_KB then
    begin

      if (not IsNumber(ComboChipSize.Text)) then
      begin
        LogPrint(STR_CHECK_SETTINGS);
        OpFail('the chip size, the page size or the range is not usable');
        exit;
      end;

      if (not IsNumber(ComboPageSize.Text)) then
      begin
        LogPrint(STR_CHECK_SETTINGS);
        OpFail('the chip size, the page size or the range is not usable');
        exit;
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
          OpFail('the chip size, the page size or the range is not usable');
          exit;
        end;

      EraseEEPROM25(0, StrToInt(ComboChipSize.Text), StrToInt(ComboPageSize.Text), StrToInt(ComboChipSize.Text));
    end;

    if ComboSPICMD.ItemIndex = SPI_CMD_45 then
    begin
      if UsbAsp45_ChipErase() <> 4 then
      begin
        OpFail('the DataFlash chip-erase command was not transferred exactly');
        Exit;
      end;

      if not WaitNotBusy45(ChipEraseTimeout) then Exit;
    end;

  end;

  //I2C
  if RadioI2C.Checked then
  begin
  if ( (ComboAddrType.ItemIndex < 0) or (not IsNumber(ComboPageSize.Text)) ) then
    begin
      LogPrint(STR_CHECK_SETTINGS);
      OpFail('the chip size, the page size or the range is not usable');
      exit;
    end;

    EnterProgModeI2C();

    //แอดเดรสของชิปตามช่องติ๊ก
    I2C_DevAddr := SetI2CDevAddr();

    if UsbAspI2C_BUSY(I2C_DevAddr) then
    begin
      LogPrint(STR_I2C_NO_ANSWER);
      OpFail('the I2C EEPROM did not acknowledge its address');
      exit;
    end;
    if not AutoBackupChip then
    begin
      OpFail('the backup could not be made');
      Exit;
    end;
    if RunScriptFromFile(CurrentICParam.Script, 'erase') then Exit;

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
      OpFail('the chip size, the page size or the range is not usable');
      exit;
    end;

    if not AsProgrammer.Programmer.MWInit(SetSPISpeed(0)) then
    begin
      OpFail('the programmer could not initialize the MicroWire bus');
      Exit;
    end;
    if not AutoBackupChip then
    begin
      OpFail('the backup could not be made');
      Exit;
    end;
    if RunScriptFromFile(CurrentICParam.Script, 'erase') then Exit;
    TimeCounter := Time();
    LogPrint(STR_ERASING_FLASH);
    if UsbAspMW_Ewen(StrToInt(ComboMWBitLen.Text)) <>
       StrToInt(ComboMWBitLen.Text) + 3 then
    begin
      OpFail('the MicroWire EEPROM did not accept EWEN');
      Exit;
    end;
    try
      if UsbAspMW_ChipErase(StrToInt(ComboMWBitLen.Text)) <>
         StrToInt(ComboMWBitLen.Text) + 3 then
      begin
        OpFail('the MicroWire chip-erase command was not transferred exactly');
        Exit;
      end;

      if not WaitNotBusyMW(BUSY_TIMEOUT_CHIP) then Exit;
    finally
      if UsbAspMW_Ewds(StrToInt(ComboMWBitLen.Text)) <>
         StrToInt(ComboMWBitLen.Text) + 3 then
        OpFail('the MicroWire EEPROM could not be returned to EWDS');
    end;
  end;


  LogPrint(STR_DONE);
  LogPrint(STR_TIME + TimeToStr(Time() - TimeCounter));

finally
  LogPrint(STR_OP_RESULT + OpSummary);
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
  OpBegin(opkErase);
  //ชิปกำลังจะถูกเปลี่ยนเนื้อใน ความรู้เดิมว่า "เปล่า" หรือ "มีข้อมูล"
  //ใช้ต่อไม่ได้อีก ไม่งั้นการเขียนรอบถัดไปจะอ้างสถานะก่อนเขียนรอบนี้
  ForgetChipContent;
  ButtonCancel.Tag := 0;

  if (not RadioSPI.Checked) or (ComboSPICMD.ItemIndex <> SPI_CMD_25) then
  begin
    LogPrint(STR_SECTOR_SPI25_ONLY);
    OpFail('range erase is only supported for SPI 25-series NOR flash');
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
       mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
    begin
      OpCancel;
      Exit;
    end;

  if not OpenDevice() then
  begin
    OpFail('the programmer could not be opened');
    Exit;
  end;
  LockControl();

  LogPrint(TimeToStr(Time()));
  if not VoltageWarningOK then
  begin
    OpFail('aborted because of the supply voltage');
    Exit;
  end;
  EnterProgMode25(SetSPISpeed(0), MenuSendAB.Checked);
  if not ContactIsStable then Exit;
  if not VerifyChipID then
  begin
    OpFail('the chip in the socket does not match the selected one');
    Exit;
  end;
  EnsureChipHints;
  if not ProtectionGuardOK(StartAddr, RangeLen) then Exit;
  if not AutoBackupChip then
  begin
    OpFail('the backup could not be made');
    Exit;
  end;

  IsLockBitsEnabled;
  TimeCounter := Time();

  if EraseRange25(StartAddr, RangeLen, SectorSize, Opcode) then
    LogPrint(STR_DONE);

  LogPrint(STR_TIME + TimeToStr(Time() - TimeCounter));

finally
  LogPrint(STR_OP_RESULT + OpSummary);
  ExitProgMode25;
  AsProgrammer.Programmer.DevClose;
  UnlockControl();
end;
end;

//Preservation-aware transactional SPI NOR programming.
//
//A trusted two-pass snapshot is overlaid with the requested patch.  The pure
//planner decides which bytes can be programmed 1->0 and which complete erase
//blocks must be read/modify/erased/restored.  One headless executor then owns
//the second hardware session, WREN/WEL checks, WIP draining, full-block
//verification, cancellation, 4-byte-mode cleanup, and evidence commit.
//อ่านทั้งชิปผ่านตัวจับคู่ตัวเดียวกับที่จะใช้เขียน
//
//อ่านผ่านทางเดียวกับที่เขียนโดยตั้งใจ: snapshot ที่มาจากเส้นทางอื่นอาจต่างกัน
//ในรายละเอียดที่ทำให้แผน differential ผิด
function ReadCurrentChipEEPROM(Device: TEEPROMDevice; Stream: TMemoryStream;
  ChipSize, PageSize: cardinal): boolean;
var
  Addr: QWord;
  Chunk, MaxChunk: cardinal;
  Data: TBytes;
  R: TEEPROMIOResult;
begin
  Result := False;
  Stream.Clear;
  ProgressReset(ChipSize);

  Addr := 0;
  while Addr < ChipSize do
  begin
    //อ่านทีละหลายหน้าเพื่อความเร็ว แต่ต้องไม่เกินที่ทรานสปอร์ตรับไหว
    //
    //MicroWire บน CH341 แปลงหนึ่งไบต์เป็นแปดบิตในบัฟเฟอร์คำสั่ง ซึ่งมีเพดาน
    //4096 ไบต์ ขอทีละ 4KB จึงกลายเป็น 32768 บิต แล้วคำสั่งล้มทั้งหมด
    //ทางเดิม (ReadFlashMW) อ่านทีละคำเดียวด้วยเหตุผลนี้
    if MainForm.RadioMW.Checked then MaxChunk := 64 else MaxChunk := 4096;
    Chunk := PageSize;
    while (Chunk < MaxChunk) and (Chunk + PageSize <= ChipSize - Addr) do
      Inc(Chunk, PageSize);
    if QWord(Chunk) > ChipSize - Addr then Chunk := cardinal(ChipSize - Addr);

    R := Device.ReadPage(Addr, Chunk, Data);
    if not R.Success then
    begin
      OpFail('snapshot read failed: ' + R.ErrorText, Addr);
      Exit;
    end;
    if (R.Transferred <> Chunk) or (cardinal(Length(Data)) <> Chunk) then
    begin
      OpFail(Format('snapshot short read: received %d of %d bytes',
                    [R.Transferred, Chunk]), Addr);
      Exit;
    end;
    Stream.WriteBuffer(Data[0], Chunk);
    Inc(Addr, Chunk);

    ProgressStep(Chunk);
    OpProcessMessages;
    if UserCancel then
    begin
      OpCancel;
      Exit;
    end;
  end;

  Stream.Position := 0;
  Result := Stream.Size = int64(ChipSize);
  if not Result then
    OpFail('the snapshot did not come back at the chip size');
end;

//ชิปที่เลือกอยู่เป็นตระกูล EEPROM ที่ Smart Write มีตัวจัดการให้หรือไม่
//(24Cxx ทาง I2C, 93xx ทาง MicroWire, 95xx ทาง SPI)
function IsEEPROMSmartWriteTarget: boolean;
begin
  Result := MainForm.RadioI2C.Checked or MainForm.RadioMW.Checked or
            (MainForm.RadioSPI.Checked and
             (MainForm.ComboSPICMD.ItemIndex = SPI_CMD_95));
end;

procedure AddBackupPreviewLine(Lines: TStrings);
begin
  if LastBackupFileName <> '' then
    Lines.Add('Backup file: ' + LastBackupFileName)
  else
    Lines.Add('Backup file: required but not published (execution is blocked)');
end;

procedure LogPreviewText(const Preview: string);
var
  Lines: TStringList;
  i: integer;
begin
  Lines := TStringList.Create;
  try
    Lines.Text := Preview;
    for i := 0 to Lines.Count - 1 do
      if Lines[i] <> '' then LogPrint(Lines[i]);
  finally
    Lines.Free;
  end;
end;

//สรุปแผน Smart Write ของ EEPROM เป็นภาษาคน แผนเดียวกันนี้ถูกส่งต่อให้
//executor จริง ไม่มีตัววางแผนชุดที่สองซ่อนอยู่หลังกล่องข้อความ
function EEPROMPlanPreviewText(const Plan: TEEPROMPlan;
  WriteCycleMs: cardinal): string;
var
  Writes: integer;
  EtaMs: QWord;
  Lines: TStringList;
begin
  Writes := EEPROMPlanCountKind(Plan, epsWrite);
  Lines := TStringList.Create;
  try
    Lines.Add(STR_SMART_PREVIEW_SAFE);
    Lines.Add('');
    Lines.Add(Format('Requested range: 0x%.6x .. 0x%.6x (%d bytes)',
      [Plan.RequestedAddress,
       Plan.RequestedAddress + Plan.RequestedLength - 1,
       Plan.RequestedLength]));
    if Writes = 0 then
      Lines.Add('The chip already matches the image; no page will be written')
    else
      Lines.Add(Format('Write: %d pages of %d bytes (%d bytes changed)',
        [Writes, Plan.PageSize, Plan.ChangedBytes]));
    Lines.Add(Format('Verify: %d page reads covering %d bytes',
      [EEPROMPlanCountKind(Plan, epsVerify), Plan.VerifyBytes]));
    EtaMs := QWord(Writes) * QWord(WriteCycleMs);
    if EtaMs > 0 then
      Lines.Add(Format('Estimated worst-case write-cycle time: about %d s, ' +
                       'plus readback', [(EtaMs + 999) div 1000]));
    AddBackupPreviewLine(Lines);
    Result := Lines.Text;
  finally
    Lines.Free;
  end;
end;

//สรุปแผน Smart Write เป็นภาษาคน
//เพดานเวลามาจากตัวเลขที่ชิปประกาศเอง (ทาง SFDP DWORD-10/11 ถ้ามี)
function NORPlanPreviewText(const Plan: TNORPlan): string;
var
  i: SizeInt;
  Op: integer;
  ByOpcode: array[0..255] of integer;
  ByOpcodeBytes: array[0..255] of QWord;
  WorstMs: QWord;
  Lines: TStringList;
begin
  FillChar(ByOpcode, SizeOf(ByOpcode), 0);
  FillChar(ByOpcodeBytes, SizeOf(ByOpcodeBytes), 0);
  WorstMs := 0;
  for i := 0 to High(Plan.Steps) do
    case Plan.Steps[i].Kind of
      npsErase:
        begin
          Inc(ByOpcode[Plan.Steps[i].Opcode]);
          Inc(ByOpcodeBytes[Plan.Steps[i].Opcode], Plan.Steps[i].Length);
          Inc(WorstMs, QWord(EraseTimeoutFor(Plan.Steps[i].Length)));
        end;
      npsProgram:
        Inc(WorstMs, QWord(PageProgTimeout));
      npsVerify: ;
    end;

  Lines := TStringList.Create;
  try
    Lines.Add(STR_SMART_PREVIEW_SAFE);
    Lines.Add('');
    Lines.Add(Format('Requested range: 0x%.6x .. 0x%.6x (%d bytes)',
      [Plan.RequestedAddress,
       Plan.RequestedAddress + Plan.RequestedLength - 1,
       Plan.RequestedLength]));
    if Plan.AffectedLength = 0 then
      Lines.Add('The chip already matches the image inside the requested ' +
                'range; no block will be touched')
    else
      Lines.Add(Format('Affected range: 0x%.6x .. 0x%.6x (%d bytes)',
        [Plan.AffectedAddress,
         Plan.AffectedAddress + Plan.AffectedLength - 1,
         Plan.AffectedLength]));
    for Op := 0 to 255 do
      if ByOpcode[Op] > 0 then
        Lines.Add(Format('Erase %.2xh: %d blocks, %d bytes',
          [Op, ByOpcode[Op], ByOpcodeBytes[Op]]));
    Lines.Add(Format('Program: %d page commands, %d bytes',
      [NORPlanCountKind(Plan, npsProgram), Plan.ProgramBytes]));
    Lines.Add(Format('Preserved neighbours restored: %d bytes',
      [Plan.PreservedBytesRewritten]));
    Lines.Add(Format('Verify: %d block reads covering %d bytes',
      [NORPlanCountKind(Plan, npsVerify), Plan.VerifyBytes]));
    if WorstMs > 0 then
      Lines.Add(Format(
        'Estimated chip-declared worst case: about %d s, plus readback',
        [(WorstMs + 999) div 1000]));
    AddBackupPreviewLine(Lines);
    Result := Lines.Text;
  finally
    Lines.Free;
  end;
end;

function ConfirmSmartWritePreview(const Preview: string;
  HasDestructiveSteps: boolean; AllowPrompt: boolean = True): boolean;
var
  Text: string;
begin
  Result := True;
  LogPrint('--- Smart Write plan preview ---');
  LogPreviewText(Preview);
  if CLIMode or (not AllowPrompt) then Exit;

  if SmartWritePlanOnly or (not HasDestructiveSteps) then
  begin
    MessageDlg(STR_SMART_PREVIEW_TITLE, Preview, mtInformation, [mbOK], 0);
    Exit;
  end;

  Text := Preview + LineEnding + STR_SMART_PREVIEW_GO;
  Result := MessageDlg(STR_SMART_PREVIEW_TITLE, Text, mtWarning,
                       [mbYes, mbNo], 0) = mrYes;
  if not Result then LogPrint(STR_SMART_PREVIEW_STOP);
end;

procedure TMainForm.MenuSmartWritePreviewClick(Sender: TObject);
var
  PreviousPlanOnly: boolean;
begin
  if OperationRunning then Exit;
  PreviousPlanOnly := SmartWritePlanOnly;
  SmartWritePlanOnly := True;
  try
    MenuSmartWriteClick(Sender);
  finally
    SmartWritePlanOnly := PreviousPlanOnly;
  end;
end;

procedure TMainForm.MenuSmartWriteClick(Sender: TObject);
var
  ChipSize, PageSize, PatchSize, PatchStart: cardinal;
  Parsed: QWord;
  Speed: integer;
  PreflightOpen, PreflightBus, ControlsLocked: boolean;
  Need4B, Native4B, PlanBuilt, OldWorker: boolean;
  Geometry: TNORGeometry;
  Plan: TNORPlan;
  Config: TSPI25NORConfig;
  PreflightID: MEMORY_ID;
  Trusted, PatchStream: TMemoryStream;
  CurrentBytes, PatchBytes: TBytes;
  Request: TOperationRequest;
  Token: TCancellationToken;
  Adapter: TSPI25NORAdapter;
  Executor: TNORPlanExecutor;
  Outcome: TOperationOutcome;
  Bridge: TNORUIBridge;
  Digest: TSHA256Digest;
  Err, NativeErr, FailureEvidenceError: string;
  ReadOpcode: byte;
  FastRead: boolean;
  GeometryIndex: SizeInt;
  ExecutorOptions: TNORExecutorOptions;
  ThisTimeout: cardinal;
  Preview: string;

  procedure ReleasePreflightSession;
  begin
    try
      Leave4B;
    except
      on E: Exception do
        if not LastOp.Failed then
          OpFail('4-byte-address cleanup raised ' + E.ClassName + ': ' +
                 E.Message);
    end;
    if PreflightBus then
    begin
      PreflightBus := False;
      try
        ExitProgMode25;
      except
        on E: Exception do
          if not LastOp.Failed then
            OpFail('SPI cleanup raised ' + E.ClassName + ': ' + E.Message);
      end;
    end;
    if PreflightOpen then
    begin
      PreflightOpen := False;
      try
        AsProgrammer.Programmer.DevClose;
      except
        on E: Exception do
          if not LastOp.Failed then
            OpFail('programmer close raised ' + E.ClassName + ': ' +
                   E.Message);
      end;
    end;
  end;

  function StreamBytes(Stream: TMemoryStream; out Data: TBytes): boolean;
  begin
    Data := nil;
    Result := False;
    if (Stream = nil) or (Stream.Size < 0) or
       (QWord(Stream.Size) > QWord(High(SizeInt))) then Exit;
    SetLength(Data, SizeInt(Stream.Size));
    Stream.Position := 0;
    if Length(Data) > 0 then Stream.ReadBuffer(Data[0], Length(Data));
    Result := True;
  end;

  function IsCanonicalUpperHex(const Value: string;
    RequiredChars: integer): boolean;
  var
    i: integer;
  begin
    Result := Length(Value) = RequiredChars;
    if not Result then Exit;
    for i := 1 to Length(Value) do
      if not (Value[i] in ['0'..'9', 'A'..'F']) then Exit(False);
  end;

  procedure ExecutePlan;
  begin
    Outcome := Executor.ExecuteBound(Request, Plan, Geometry, CurrentBytes,
      Token);
  end;

begin
  if OperationRunning then Exit;

  //EZP2023+ ไม่มีคำสั่ง SPI ดิบให้ตัววางแผนอ่าน sector ข้างเคียง ลบเป็น
  //ช่วง หรือโปรแกรมเฉพาะเพจที่เปลี่ยน มันรับได้แต่ภาพทั้งชิปผ่านคำสั่งของ
  //เฟิร์มแวร์ ปุ่ม Write ปกติคือเส้นทางที่ถูกต้องและตรวจกลับทุกไบต์ให้เอง
  if AsProgrammer.Current_HW = CHW_EZP then
  begin
    OpBegin(opkWrite);
    OpFail('Smart write is not available through the EZP2023+: its firmware ' +
      'only accepts a whole-chip image. Use ordinary Write; it still reads ' +
      'the entire chip back and verifies every byte.');
    Exit;
  end;

  //ตระกูลที่ลบไม่ได้ (24Cxx, 93xx, 95xx) มีตัวจัดการของตัวเอง: ไม่มีขั้นลบ
  //แผนจึงเป็นแค่ "เขียนเฉพาะหน้าที่ต่าง แล้วตรวจทุกหน้าที่แตะ"
  if IsEEPROMSmartWriteTarget then
  begin
    SmartWriteEEPROM(Sender);
    Exit;
  end;

  OpBegin(opkWrite);
  //FillChar ห้ามใช้กับเรคคอร์ดที่มีสตริง (ดูคำอธิบายที่จุดเดียวกันใน
  //ButtonWriteClick)
  CurrentSerial := Default(TSerialAllocation);
  CurrentSerialValid := False;
  CurrentSerialReserved := False;
  LastChipUID := '';
  LastProgramCRC := BufferCRC32;

  PreflightOpen := False;
  PreflightBus := False;
  ControlsLocked := False;
  PlanBuilt := False;
  Trusted := nil;
  PatchStream := nil;
  Token := nil;
  Adapter := nil;
  Executor := nil;
  Bridge := TNORUIBridge.Create;
  CurrentBytes := nil;
  PatchBytes := nil;
  FillChar(Outcome, SizeOf(Outcome), 0);
  InitOperationRequest(Request);
  Request.OperationID :=
    FormatDateTime('yyyymmddhhnnsszzz', Now) + '-' +
    IntToHex(GetTickCount64 and $FFFFFFFF, 8);
  LastStrictRunID := Request.OperationID;
  Request.Kind := okProgram;
  Request.Chip.Name := CurrentICParam.Name;
  Request.Chip.ProfileHash := StrictProductionProfileHash;
  Request.ImageHash := StrictProductionImageHash;
  Bridge.EvidenceSize := MPHexEditorEx.DataSize;
  Bridge.EvidenceCRC := LastProgramCRC;
  Bridge.EvidenceUID := '';
  Bridge.EvidenceCommitted := False;
  Bridge.StrictMode := StrictProductionMode;
  Bridge.StrictJobID := StrictProductionJobID;
  Bridge.StrictJobRevision := StrictProductionJobRevision;
  Bridge.EvidenceDirectory := StrictEvidenceDirectory;
  Bridge.EvidenceKeyID := StrictEvidenceKeyID;
  Bridge.EvidenceKey := StrictEvidenceKey;
  Bridge.OperatorName := ProdSettings.Operator_;
  Bridge.ProgrammerID := '';
  Bridge.ReadPasses := 2;
  if StrictProductionMode then
    Bridge.ReadPasses := StrictProductionReadPasses;
  Bridge.SerialText := '';
  Bridge.PhysicalVerifyCompleted := False;

  try
  try
    if StrictProductionMode and ProdSettings.SNEnabled then
    begin
      OpFail('strict production refuses unsigned serial-number personalization');
      Exit;
    end;
    if StrictProductionMode then
    begin
      if (StrictProductionJobID = '') or
         (StrictProductionJobRevision = 0) or
         (StrictAdmittedProgrammerID = '') or
         (not DirectoryExists(StrictEvidenceDirectory)) or
         (not IsCanonicalUpperHex(StrictProductionProfileHash, 64)) or
         (not IsCanonicalUpperHex(StrictProductionImageHash, 64)) or
         (not IsCanonicalUpperHex(StrictProductionExpectedID, 6)) or
         (StrictProductionPageSize = 0) or
         (StrictProductionEraseSize = 0) or
         (StrictProductionEraseOpcode = 0) or
         (StrictProductionReadPasses < 2) or
         (StrictProductionReadPasses > 16) then
      begin
        OpFail('strict production context is incomplete or non-canonical');
        Exit;
      end;
    end;
    if MPHexEditorEx.DataSize = 0 then
    begin
      LogPrint(STR_ERASE_RANGE_EMPTY);
      OpFail('the write buffer is empty');
      Exit;
    end;
    if (not RadioSPI.Checked) or
       (ComboSPICMD.ItemIndex <> SPI_CMD_25) then
    begin
      LogPrint(STR_SECTOR_SPI25_ONLY);
      OpFail('transactional Smart Write supports SPI 25-series NOR only');
      Exit;
    end;

    if (not TryStrToQWord(Trim(ComboChipSize.Text), Parsed)) or
       (Parsed = 0) or (Parsed > High(cardinal)) then
    begin
      OpFail('the chip size is not a usable positive integer');
      Exit;
    end;
    ChipSize := cardinal(Parsed);

    if (not TryStrToQWord('$' + Trim(StartAddressEdit.Text), Parsed)) or
       (Parsed > High(cardinal)) then
    begin
      OpFail('the start address is not a usable hexadecimal address');
      Exit;
    end;
    PatchStart := cardinal(Parsed);
    PatchSize := MPHexEditorEx.DataSize;
    Request.Target.Address := PatchStart;
    Request.Target.Length := PatchSize;
    Request.Chip.Capacity := ChipSize;
    if (PatchStart >= ChipSize) or (PatchSize > ChipSize - PatchStart) then
    begin
      OpFail('the requested patch does not fit the selected chip');
      Exit;
    end;

    if (not TryStrToQWord(Trim(ComboPageSize.Text), Parsed)) or
       (Parsed = 0) or (Parsed > 2048) then
    begin
      OpFail('Smart Write requires a numeric page size from 1 to 2048 bytes');
      Exit;
    end;
    PageSize := cardinal(Parsed);

    LockControl;
    ControlsLocked := True;
    if not OpenDevice then
    begin
      OpFail('the programmer could not be opened');
      Exit;
    end;
    PreflightOpen := True;
    if StrictProductionMode then
      Bridge.ProgrammerID := StrictAdmittedProgrammerID
    else
      Bridge.ProgrammerID := AsProgrammer.Programmer.HardwareName;

    if not VoltageWarningOK then
    begin
      OpFail('aborted because of the supply voltage');
      Exit;
    end;
    Speed := SetSPISpeed(0);
    if not EnterProgMode25(Speed, MenuSendAB.Checked) then
    begin
      OpFail('the programmer could not initialize the SPI bus');
      Exit;
    end;
    PreflightBus := True;

    if MenuResetChip.Checked then
    begin
      LogPrint(STR_RESETTING);
      if UsbAsp25_SoftReset <> 1 then
      begin
        OpFail('the SPI NOR reset sequence was not transferred exactly');
        Exit;
      end;
    end;
    if not ContactIsStable then Exit;
    if not VerifyChipID then
    begin
      OpFail('the chip in the socket does not match the selected one');
      Exit;
    end;
    EnsureChipHints;

    FillChar(PreflightID, SizeOf(PreflightID), 0);
    UsbAsp25_ReadID(PreflightID);
    if not PreflightID.Got9F then
    begin
      //ไม่ตอบ 9Fh แบบครบถ้วน = ไม่มีหลักฐานว่ามีชิปอยู่ตรงหน้า
      NoteSession(seChipLost);
      OpFail('the chip did not return an exact JEDEC 9Fh identity');
      Exit;
    end;
    //ชิปตอบด้วยตัวตนที่ครบถ้วนบนรางที่ตั้งอยู่ตอนนี้ นี่คือหลักฐานเดียวที่
    //นับว่า "มีชิปอยู่" ไม่ใช่การที่ผู้ใช้เลือกชื่อรุ่นจากเมนู
    NoteSession(seChipDetected);

    LastChipUID := ReadChipUID;
    if LastChipUID <> '' then LogPrint(STR_UNIQUE_ID + LastChipUID);
    Request.Chip.UniqueID := LastChipUID;
    Bridge.EvidenceUID := LastChipUID;
    if StrictProductionMode and (not StrictProductionUIDRequired) then
    begin
      OpFail('strict two-session programming requires a UID-bound production job');
      Exit;
    end;
    if StrictProductionMode and
       (StrictProductionUIDRequired and
        ((not LastChipUIDTransferExact) or (LastChipUID = ''))) then
    begin
      OpFail('the authenticated production job requires an exact usable chip UID');
      Exit;
    end;
    if not DuplicateChipGuardOK(LastChipUID) then Exit;
    if not JobFileGuardOK(PatchSize) then Exit;

    if StrictProductionMode then
    begin
      if ChipSize > 16777216 then
      begin
        OpFail('strict SPI NOR profile v1 does not bind 4-byte opcodes; ' +
               'chips above 16 MiB are rejected');
        Exit;
      end;
      if (StrictProductionPageSize = 0) or
         (PageSize <> StrictProductionPageSize) then
      begin
        OpFail('configured page size does not match the authenticated chip profile');
        Exit;
      end;
      if CurrentSFDPValid then
      begin
        if CurrentSFDP.Density <> ChipSize then
        begin
          OpFail('live SFDP density does not match the authenticated chip profile');
          Exit;
        end;
        if (CurrentSFDP.PageSize <> 0) and
           (CurrentSFDP.PageSize <> StrictProductionPageSize) then
        begin
          OpFail('live SFDP page size does not match the authenticated chip profile');
          Exit;
        end;
        if CurrentSFDP.SectorMapDeclared and
           ((not CurrentSFDP.HasSectorMap) or (not CurrentSFDP.Uniform)) then
        begin
          OpFail('strict chip profile v1 cannot authenticate an ambiguous or hybrid sector map');
          Exit;
        end;
      end;
    end;

    if CurrentSFDPValid and (CurrentSFDP.PageSize > 0) then
    begin
      if PageSize <> CurrentSFDP.PageSize then
        LogPrint(Format(
          'Using SFDP page size %d instead of configured value %d',
          [CurrentSFDP.PageSize, PageSize]));
      PageSize := CurrentSFDP.PageSize;
    end;

    Trusted := TMemoryStream.Create;
    if not AutoBackupChip(Trusted, @Speed) then
    begin
      OpFail('a trusted two-pass full-chip snapshot could not be made');
      Exit;
    end;

    PatchStream := TMemoryStream.Create;
    MPHexEditorEx.SaveToStream(PatchStream);
    PatchStream.Position := 0;
    //Planning personalizes an immutable copy, but publishing allocation
    //evidence and consuming the serial are deferred until this exact plan is
    //accepted.  Preview-only is therefore read-only outside the process too.
    if not ApplySerialToStream(PatchStream, False) then Exit;
    PatchSize := PatchStream.Size;
    Request.Target.Length := PatchSize;
    Bridge.EvidenceSize := PatchSize;
    Bridge.EvidenceCRC := LastProgramCRC;
    if CurrentSerialValid then Bridge.SerialText := CurrentSerial.Text;

    if (not StreamBytes(Trusted, CurrentBytes)) or
       (Length(CurrentBytes) <> ChipSize) or
       (not StreamBytes(PatchStream, PatchBytes)) or
       (Length(PatchBytes) <> PatchSize) then
    begin
      OpFail('the immutable snapshot or personalized patch could not be captured');
      Exit;
    end;

    if not SHA256Bytes(PatchBytes, Digest, Err) then
    begin
      OpFail('cannot hash the immutable personalized image: ' + Err);
      Exit;
    end;
    Request.ImageHash := DigestToHex(Digest);
    Request.Chip.ProfileHash := StrictProductionProfileHash;
    if StrictProductionMode and
       (Request.ImageHash <> StrictProductionImageHash) then
    begin
      OpFail('the immutable operation image no longer matches the authenticated job');
      Exit;
    end;

    Need4B := Needs4ByteAddress(PatchStart, PatchSize, ChipSize);
    Native4B := Need4B and Native4BRead and Native4BWrite;
    if Native4B then
    begin
      NativeErr := '';
      if not BuildCurrentNORGeometry(ChipSize, PageSize, True,
                                     Geometry, NativeErr) then
        Native4B := False;
    end;
    if not Native4B then
      if not BuildCurrentNORGeometry(ChipSize, PageSize, False,
                                     Geometry, Err) then
      begin
        if (NativeErr <> '') and Need4B then
          Err := Err + '; native 4-byte plan was also unavailable: ' +
                 NativeErr;
        OpFail('cannot construct a safe NOR geometry: ' + Err);
        Exit;
      end;

    if StrictProductionMode then
    begin
      if (Geometry.PageSize <> StrictProductionPageSize) or
         (StrictProductionEraseSize = 0) or
         (StrictProductionEraseOpcode = 0) then
      begin
        OpFail('runtime NOR geometry does not match the authenticated chip profile');
        Exit;
      end;
      for GeometryIndex := 0 to High(Geometry.Blocks) do
        if (Geometry.Blocks[GeometryIndex].Size <>
            StrictProductionEraseSize) or
           (Geometry.Blocks[GeometryIndex].Opcode <>
            StrictProductionEraseOpcode) then
        begin
          OpFail('runtime hybrid/alternate erase geometry is not bound by ' +
                 'the authenticated chip profile v1',
                 Geometry.Blocks[GeometryIndex].Address);
          Exit;
        end;
    end;

    if not BuildNORDifferentialPlan(CurrentBytes, PatchBytes, PatchStart,
                                    Geometry, Plan, Err) then
    begin
      OpFail('cannot construct the preservation-aware write plan: ' + Err);
      Exit;
    end;
    PlanBuilt := True;
    LogPrint(Format(
      'Smart plan: %d changed bytes, %d erase bytes, %d program bytes, ' +
      '%d verified bytes, %d preserved neighbour bytes restored',
      [Plan.ChangedBytes, Plan.EraseBytes, Plan.ProgramBytes,
       Plan.VerifyBytes, Plan.PreservedBytesRewritten]));

    Preview := NORPlanPreviewText(Plan);
    if not ConfirmSmartWritePreview(Preview,
                                    NORPlanHasDestructiveSteps(Plan),
                                    Sender <> ComboItem1) then
    begin
      OpCancel;
      Exit;
    end;
    //โหมดดูแผนอย่างเดียวจบตรงนี้ ก่อนด่านป้องกันและก่อน UnlockCurrentSPI25
    //ซึ่งเขียน status register จริง แผนถูกแสดงครบแล้ว และชิปยังไม่ถูกแตะ
    if SmartWritePlanOnly then Exit;

    if NORPlanHasDestructiveSteps(Plan) then
    begin
      if not PublishCurrentSerialEvidence then Exit;
      if not ReserveCurrentSerial then Exit;
      //Only now is the selected chip scheduled to change.  A cancelled or
      //preview-only plan keeps the content knowledge gathered by the read.
      ForgetChipContent;
    end;

    //The protection guard covers the planner's complete affected blocks, not
    //only the requested patch.  Erase commands can touch preserved neighbours.
    if NORPlanHasDestructiveSteps(Plan) then
    begin
      if (Plan.AffectedAddress > High(cardinal)) or
         (Plan.AffectedLength > High(cardinal)) then
      begin
        OpFail('the affected protection-check range does not fit this build');
        Exit;
      end;
      if not ProtectionGuardOK(cardinal(Plan.AffectedAddress),
                               cardinal(Plan.AffectedLength)) then Exit;
      if not UnlockCurrentSPI25 then Exit;
    end;

    if OperationCancellationRequested then
    begin
      OpCancel;
      Exit;
    end;

    InitSPI25NORConfig(Config);
    Config.SPISpeed := Speed;
    Config.SendAB := MenuSendAB.Checked;
    if AsProgrammer.Current_HW = CHW_BUZZPIRAT then
      Config.ReadTransport := srtCombinedWriteRead
    else
      Config.ReadTransport := srtSplitWriteRead;

    if Need4B then
    begin
      Config.AddressMode := sam4Byte;
      if Native4B then
      begin
        Config.FourByteStrategy := fbsNativeDedicatedOpcodes;
        PickReadOpcode(True, ReadOpcode, FastRead);
        Config.ReadOpcode := ReadOpcode;
        Config.ProgramOpcode := Chip25PageProg4BOpcode;
      end
      else
      begin
        case Chip25Entry4B of
          E4B_B7:
            Config.FourByteStrategy := fbsEnterB7;
          E4B_WREN_B7:
            Config.FourByteStrategy := fbsWriteEnableThenB7;
        else
          OpFail(
            'this large chip has no safely supported B7 or dedicated 4-byte strategy');
          Exit;
        end;
        PickReadOpcode(False, ReadOpcode, FastRead);
        Config.ReadOpcode := ReadOpcode;
        Config.ProgramOpcode := $02;
      end;
    end
    else
    begin
      Config.AddressMode := sam3Byte;
      Config.FourByteStrategy := fbsNotApplicable;
      PickReadOpcode(False, ReadOpcode, FastRead);
      Config.ReadOpcode := ReadOpcode;
      Config.ProgramOpcode := $02;
    end;
    Config.FastRead := FastRead;
    if not RequireSPI25MemoryIdentity(Config, PreflightID, 8, Err) then
    begin
      OpFail('cannot enforce the preflight chip identity: ' + Err);
      Exit;
    end;
    if LastChipUID <> '' then
      if not RequireSPI25UniqueIdentity(Config, LastChipUID, 2, Err) then
      begin
        OpFail('cannot bind the execution session to the preflight UID: ' + Err);
        Exit;
      end;
    if not ValidateSPI25NORConfig(Config, Err) then
    begin
      OpFail('invalid real-hardware NOR adapter configuration: ' + Err);
      Exit;
    end;

    Request.Chip.Name := CurrentICParam.Name;
    Request.Chip.JedecID :=
      IntToHex(PreflightID.ID9FH[0], 2) +
      IntToHex(PreflightID.ID9FH[1], 2) +
      IntToHex(PreflightID.ID9FH[2], 2);
    Request.Chip.UniqueID := LastChipUID;
    Request.Chip.Capacity := ChipSize;
    Request.Policy.RequireTrustedBackup := True;
    Request.Policy.RequireStableIdentity := True;
    Request.Policy.RequireFullVerify := True;
    Request.Policy.RequireEvidenceCommit :=
      StrictProductionMode or (ProdSettings.ProdLogFile <> '');
    Request.Policy.PreserveOutsideRange := True;

    //The immutable plan owns all bytes it may program, while CurrentBytes is
    //retained through execution so the reopened session can prove that the
    //same complete preimage is still connected before any WREN.
    PatchBytes := nil;
    FreeAndNil(Trusted);
    FreeAndNil(PatchStream);

    ReleasePreflightSession;
    //A cleanup failure means the first session did not return the chip and
    //programmer to a proven-safe state.  Never reopen the device or let the
    //executor commit PASS evidence after that failure.
    if not OpOK then Exit;

    Bridge.EvidenceSize := PatchSize;
    Bridge.EvidenceCRC := LastProgramCRC;
    Bridge.EvidenceUID := LastChipUID;
    Token := TCancellationToken.Create;
    ActiveNORCancellation := Token;
    try
      Adapter := TSPI25NORAdapter.Create(AsProgrammer.Programmer, Config);
      Executor := TNORPlanExecutor.Create(Adapter, @Bridge.Receive, nil,
                                          @Bridge.CommitEvidence);
      ExecutorOptions := Executor.Options;
      ExecutorOptions.ProgramTimeoutMs := PageProgTimeout;
      ExecutorOptions.EraseTimeoutMs := 1;
      for GeometryIndex := 0 to High(Geometry.Blocks) do
      begin
        ThisTimeout := EraseTimeoutFor(Geometry.Blocks[GeometryIndex].Size);
        if ThisTimeout > ExecutorOptions.EraseTimeoutMs then
          ExecutorOptions.EraseTimeoutMs := ThisTimeout;
      end;
      ExecutorOptions.StatusPollDelayMs := 1;
      Executor.Options := ExecutorOptions;

      //The transactional executor always runs on the device worker so the GUI
      //can deliver cancellation while a long erase/program is being drained.
      OldWorker := UseWorkerThread;
      UseWorkerThread := True;
      try
        RunOperation(@ExecutePlan);
        Bridge.PhysicalVerifyCompleted :=
          Outcome.PhysicalVerifyCompleted;
      finally
        UseWorkerThread := OldWorker;
      end;
    except
      on E: Exception do
        OpFail('transactional NOR executor setup failed: ' +
               E.ClassName + ': ' + E.Message);
    end;

    if not LastOp.Failed then
      case Outcome.Status of
        osSucceeded:
          begin
            OpProgress(PatchSize, PatchSize);
            LogPrint(STR_DONE);
          end;
        osCancelled:
          OpCancel;
        osFailed:
          if Outcome.HasFailureAddress then
            OpFail(OperationErrorName(Outcome.ErrorCode) + ': ' +
                   Outcome.ErrorText, Outcome.FailureAddress)
          else
            OpFail(OperationErrorName(Outcome.ErrorCode) + ': ' +
                   Outcome.ErrorText);
      else
        OpFail('the transactional NOR executor returned no terminal outcome');
      end;
  except
    on E: Exception do
      OpFail('transactional Smart Write raised ' + E.ClassName + ': ' +
             E.Message);
  end;
  finally
    ActiveNORCancellation := nil;
    try
      Executor.Free;
    except
      on E: Exception do
        if not LastOp.Failed then
          OpFail('executor cleanup raised ' + E.ClassName + ': ' + E.Message);
    end;
    Executor := nil;
    try
      Adapter.Free;
    except
      on E: Exception do
        if not LastOp.Failed then
          OpFail('adapter cleanup raised ' + E.ClassName + ': ' + E.Message);
    end;
    Adapter := nil;
    Token.Free;
    Token := nil;
    ReleasePreflightSession;

    if StrictProductionMode and (Bridge <> nil) and
       (not Bridge.EvidenceCommitted) and (not OpOK) then
    begin
      FailureEvidenceError := '';
      Err := LastOp.ErrorText;
      if Err = '' then
        if LastOp.Cancelled then Err := 'operation cancelled'
        else Err := 'operation failed without a diagnostic';
      if not Bridge.CommitFailureEvidence(Request, Err,
                                          FailureEvidenceError) then
        LogPrint('Strict failure evidence could not be written: ' +
                 FailureEvidenceError);
    end;

    //Failures before the engine's evidence phase are logged here.  A success
    //already committed by the engine must never be appended a second time.
    if (not SmartWritePlanOnly) and (ProdSettings.ProdLogFile <> '') and
       ((Bridge = nil) or (not Bridge.EvidenceCommitted)) then
      WriteProdLogEntry(MPHexEditorEx.DataSize, LastProgramCRC, LastChipUID);

    try
      Bridge.Free;
    except
      on E: Exception do
        if not LastOp.Failed then
          OpFail('evidence bridge cleanup raised ' + E.ClassName + ': ' +
                 E.Message);
    end;
    Bridge := nil;
    Trusted.Free;
    PatchStream.Free;
    CurrentBytes := nil;
    PatchBytes := nil;
    if PlanBuilt then ClearNORPlan(Plan);
    SetProgressPos(0);
    LogPrint(STR_OP_RESULT + OpSummary);
    if ControlsLocked then UnlockControl;
  end;
end;

//Smart Write สำหรับตระกูลที่ลบไม่ได้: 24Cxx, 93xx, 95xx
//
//EEPROM เขียนทับได้ทีละไบต์ ไม่มีขั้นลบ แผนจึงเหลือแค่ "เขียนเฉพาะหน้าที่
//ต่างจากภาพที่ต้องการ แล้วตรวจทุกหน้าที่อยู่ในช่วงที่ขอ" การตรวจหน้าที่
//ไม่ได้เขียนด้วยคือสิ่งเดียวที่จับได้ว่าชิปถูกสลับตัวหลังอ่าน snapshot
procedure TMainForm.SmartWriteEEPROM(Sender: TObject);
var
  Device: TEEPROMDevice;
  Executor: TEEPROMPlanExecutor;
  Token: TCancellationToken;
  Request: TOperationRequest;
  Outcome: TOperationOutcome;
  Plan: TEEPROMPlan;
  PlanBuilt, ControlsLocked, Opened, BusEntered: boolean;
  Snapshot, SnapshotConfirm, PatchStream: TMemoryStream;
  Current, Patch: TBytes;
  ChipSize, PageSize, PatchStart, PatchSize, WriteCycleMs: cardinal;
  DevAddr: byte;
  Parsed: QWord;
  Err: string;
  OldWorker: boolean;
  SnapshotDiff: int64;
  Preview: string;

  procedure ExecutePlan;
  begin
    Outcome := Executor.Execute(Request, Plan, ChipSize, Token);
  end;

begin
  if OperationRunning then Exit;
  OpBegin(opkWrite);
  CurrentSerial := Default(TSerialAllocation);
  CurrentSerialValid := False;
  CurrentSerialReserved := False;
  LastChipUID := '';
  LastProgramCRC := BufferCRC32;

  Device := nil;
  Executor := nil;
  Token := nil;
  Snapshot := nil;
  SnapshotConfirm := nil;
  PatchStream := nil;
  Current := nil;
  Patch := nil;
  PlanBuilt := False;
  ControlsLocked := False;
  Opened := False;
  BusEntered := False;
  DevAddr := 0;
  FillChar(Outcome, SizeOf(Outcome), 0);
  InitOperationRequest(Request);
  Request.OperationID :=
    FormatDateTime('yyyymmddhhnnsszzz', Now) + '-' +
    IntToHex(GetTickCount64 and $FFFFFFFF, 8);
  Request.Kind := okProgram;
  Request.Chip.Name := CurrentICParam.Name;
  //InitOperationRequest ตั้งค่านี้เป็น True มาให้ ซึ่งเหมาะกับทาง NOR ที่มี
  //ตัวส่งหลักฐานผูกอยู่ ทางนี้ยังไม่มี ถ้าปล่อยไว้ตัวจัดการจะจบงานที่
  //"ต้องส่งหลักฐานแต่ไม่มีตัวส่ง" แล้วชิปที่เขียนถูกทุกไบต์จะถูกรายงานว่าล้มเหลว
  //และถูกบันทึกลงบันทึกการผลิตว่า FAIL
  Request.Policy.RequireEvidenceCommit := False;

  try
  try
    if StrictProductionMode then
    begin
      OpFail('strict production is SPI-NOR-only');
      Exit;
    end;
    if MPHexEditorEx.DataSize = 0 then
    begin
      LogPrint(STR_ERASE_RANGE_EMPTY);
      OpFail('the write buffer is empty');
      Exit;
    end;

    if (not TryStrToQWord(Trim(ComboChipSize.Text), Parsed)) or
       (Parsed = 0) or (Parsed > High(cardinal)) then
    begin
      OpFail('the chip size is not a usable positive integer');
      Exit;
    end;
    ChipSize := cardinal(Parsed);

    if (not TryStrToQWord('$' + Trim(StartAddressEdit.Text), Parsed)) or
       (Parsed > High(cardinal)) then
    begin
      OpFail('the start address is not a usable hexadecimal address');
      Exit;
    end;
    PatchStart := cardinal(Parsed);
    PatchSize := MPHexEditorEx.DataSize;
    if (PatchStart >= ChipSize) or (PatchSize > ChipSize - PatchStart) then
    begin
      OpFail('the requested patch does not fit the selected chip');
      Exit;
    end;
    Request.Target.Address := PatchStart;
    Request.Target.Length := PatchSize;
    Request.Chip.Capacity := ChipSize;

    //ขนาดหน้าและตัวจับคู่ฮาร์ดแวร์ ต่างกันตามตระกูล
    if RadioMW.Checked then
    begin
      //93xx เป็นชิปแบบคำ: หน้าคือหนึ่งคำ = สองไบต์เสมอ
      if not IsNumber(ComboMWBitLen.Text) then
      begin
        OpFail('the MicroWire address bit length is not a number');
        Exit;
      end;
      PageSize := 2;
      WriteCycleMs := MW_ADAPTER_WRITE_CYCLE_MS;
      if ((PatchStart and 1) <> 0) or ((PatchSize and 1) <> 0) then
      begin
        OpFail('MicroWire Smart Write needs an even start address and length');
        Exit;
      end;
    end
    else
    begin
      if (not TryStrToQWord(Trim(ComboPageSize.Text), Parsed)) or
         (Parsed = 0) or (Parsed > 2048) then
      begin
        OpFail('Smart Write requires a numeric page size from 1 to 2048 bytes');
        Exit;
      end;
      PageSize := cardinal(Parsed);
      if RadioI2C.Checked then
        WriteCycleMs := I2C_ADAPTER_WRITE_CYCLE_MS
      else
        WriteCycleMs := SPI95_ADAPTER_WRITE_CYCLE_MS;
    end;

    if (ChipSize mod PageSize) <> 0 then
    begin
      OpFail(Format('the chip size %d is not a whole number of %d-byte pages',
                    [ChipSize, PageSize]));
      Exit;
    end;

    if RadioI2C.Checked and (ComboAddrType.ItemIndex < 0) then
    begin
      OpFail('the I2C address type is not selected');
      Exit;
    end;
    //ชนิด 7BIT ไม่มีไบต์แอดเดรสของหน่วยความจำเลย: BuildI2CAddr เอาแอดเดรส
    //ไปทำเป็นแอดเดรสอุปกรณ์แทน การเขียนแบบนี้จะยิงข้อมูลไปให้อุปกรณ์ตัวอื่น
    //บนบัส และไปรอ ACK จากอีกตัวหนึ่ง
    if RadioI2C.Checked and (ComboAddrType.ItemIndex = 0) then
    begin
      OpFail('Smart write needs a chip with memory address bytes; ' +
             '7BIT addressing has none');
      Exit;
    end;
    //หน้าเพจต้องไม่ข้ามขอบแบงก์ ไม่งั้นการรอ ACK จะไปรอแบงก์ก่อนหน้า
    //ซึ่งตอบทันทีทั้งที่ก้อนสุดท้ายยังเขียนไม่เสร็จ
    if RadioI2C.Checked and (PageSize > 256) then
    begin
      OpFail('I2C Smart write needs a page size of 256 bytes or less');
      Exit;
    end;

    LockControl;
    ControlsLocked := True;
    if not OpenDevice then
    begin
      OpFail('the programmer could not be opened');
      Exit;
    end;
    Opened := True;

    if not VoltageWarningOK then
    begin
      OpFail('aborted because of the supply voltage');
      Exit;
    end;

    //เข้าโหมดบัสตามตระกูล แล้วสร้างตัวจับคู่ฮาร์ดแวร์ให้ตรงกัน
    if RadioI2C.Checked then
    begin
      EnterProgModeI2C();
      BusEntered := True;
      DevAddr := SetI2CDevAddr();
      if UsbAspI2C_BUSY(DevAddr) then
      begin
        LogPrint(STR_I2C_NO_ANSWER);
        OpFail('the I2C EEPROM did not acknowledge its address');
        Exit;
      end;
      if not I2CAddressRangeValid(ComboAddrType.ItemIndex, PatchStart,
                                  integer(PatchSize)) then
      begin
        OpFail('the I2C address range is outside this address type');
        Exit;
      end;
      Device := TI2CEEPROMAdapter.Create(DevAddr, ComboAddrType.ItemIndex);
    end
    else if RadioMW.Checked then
    begin
      if not AsProgrammer.Programmer.MWInit(SetSPISpeed(0)) then
      begin
        OpFail('the programmer could not initialize the MicroWire bus');
        Exit;
      end;
      BusEntered := True;
      Device := TMWEEPROMAdapter.Create(StrToInt(ComboMWBitLen.Text));
    end
    else
    begin
      if not EnterProgMode25(SetSPISpeed(0), MenuSendAB.Checked) then
      begin
        OpFail('the programmer could not initialize the SPI bus');
        Exit;
      end;
      BusEntered := True;
      if not SPI95AddressRangeValid(integer(ChipSize), PatchStart,
                                    integer(PatchSize)) then
      begin
        OpFail('the SPI EEPROM write range is outside the selected chip');
        Exit;
      end;
      Device := TSPI95EEPROMAdapter.Create(integer(ChipSize));
    end;

    //snapshot ที่เชื่อถือได้: อ่านทั้งชิปผ่านทางอ่านของตระกูลนั้นเอง
    LastBackupFileName := '';
    LogPrint(STR_BACKUP_MAKING);
    Snapshot := TMemoryStream.Create;
    if not ReadCurrentChipEEPROM(Device, Snapshot, ChipSize, PageSize) then
    begin
      OpFail('a trusted full-chip snapshot could not be read');
      Exit;
    end;

    //The planner itself requires a trusted snapshot, regardless of whether
    //the user also asked to publish a recovery file.  A full-size marginal
    //read is not trustworthy until an independent pass agrees byte-for-byte.
    LogPrint(Format(STR_READ_PASS, [2, 2]));
    SnapshotConfirm := TMemoryStream.Create;
    if not ReadCurrentChipEEPROM(Device, SnapshotConfirm, ChipSize,
                                 PageSize) then
    begin
      OpFail('the EEPROM snapshot confirmation pass could not be read');
      Exit;
    end;
    SnapshotDiff := FirstDifference(PByte(Snapshot.Memory),
                                    PByte(SnapshotConfirm.Memory),
                                    Snapshot.Size);
    if SnapshotDiff >= 0 then
    begin
      OpFail('the two EEPROM snapshot reads disagree', SnapshotDiff);
      LogPrint(STR_BACKUP_FAILED);
      Exit;
    end;
    LogPrint(STR_READ_STABLE);
    FreeAndNil(SnapshotConfirm);

    if not PersistTrustedBackup(Snapshot, ChipSize) then
    begin
      OpFail('the trusted EEPROM backup could not be persisted');
      Exit;
    end;

    PatchStream := TMemoryStream.Create;
    MPHexEditorEx.SaveToStream(PatchStream);
    PatchStream.Position := 0;
    if not ApplySerialToStream(PatchStream, False) then Exit;
    PatchSize := PatchStream.Size;
    Request.Target.Length := PatchSize;

    SetLength(Current, ChipSize);
    Snapshot.Position := 0;
    Snapshot.ReadBuffer(Current[0], ChipSize);
    SetLength(Patch, PatchSize);
    PatchStream.Position := 0;
    if PatchSize > 0 then PatchStream.ReadBuffer(Patch[0], PatchSize);

    if not BuildEEPROMDifferentialPlan(Current, Patch, PatchStart, PageSize,
                                       Plan, Err) then
    begin
      OpFail('cannot construct the differential write plan: ' + Err);
      Exit;
    end;
    PlanBuilt := True;
    LogPrint(Format(
      'Smart plan: %d changed bytes, %d pages to write, %d bytes verified',
      [Plan.ChangedBytes, EEPROMPlanCountKind(Plan, epsWrite),
       Plan.VerifyBytes]));

    Preview := EEPROMPlanPreviewText(Plan, WriteCycleMs);
    if not ConfirmSmartWritePreview(
      Preview, EEPROMPlanCountKind(Plan, epsWrite) > 0,
      Sender <> ComboItem1) then
    begin
      OpCancel;
      Exit;
    end;
    if SmartWritePlanOnly then Exit;

    if EEPROMPlanCountKind(Plan, epsWrite) > 0 then
    begin
      if not PublishCurrentSerialEvidence then Exit;
      if not ReserveCurrentSerial then Exit;
      ForgetChipContent;
    end;

    if OperationCancellationRequested then
    begin
      OpCancel;
      Exit;
    end;

    Token := TCancellationToken.Create;
    ActiveNORCancellation := Token;
    Executor := TEEPROMPlanExecutor.Create(Device);

    OldWorker := UseWorkerThread;
    UseWorkerThread := True;
    try
      RunOperation(@ExecutePlan);
    finally
      UseWorkerThread := OldWorker;
    end;

    if not LastOp.Failed then
      case Outcome.Status of
        osSucceeded:
          begin
            OpProgress(PatchSize, PatchSize);
            LogPrint(STR_DONE);
          end;
        osCancelled:
          OpCancel;
        osFailed:
          if Outcome.HasFailureAddress then
            OpFail(OperationErrorName(Outcome.ErrorCode) + ': ' +
                   Outcome.ErrorText, Outcome.FailureAddress)
          else
            OpFail(OperationErrorName(Outcome.ErrorCode) + ': ' +
                   Outcome.ErrorText);
      else
        OpFail('the EEPROM executor returned no terminal outcome');
      end;
  except
    on E: Exception do
      OpFail('EEPROM Smart Write raised ' + E.ClassName + ': ' + E.Message);
  end;
  finally
    ActiveNORCancellation := nil;
    Executor.Free;
    Device.Free;
    Token.Free;
    Snapshot.Free;
    SnapshotConfirm.Free;
    PatchStream.Free;
    Current := nil;
    Patch := nil;
    if PlanBuilt then ClearEEPROMPlan(Plan);

    if BusEntered then
      try
        if RadioI2C.Checked then
          AsProgrammer.Programmer.I2CDeinit
        else if RadioMW.Checked then
          AsProgrammer.Programmer.MWDeinit
        else
          ExitProgMode25;
      except
        on E: Exception do
          if not LastOp.Failed then
            OpFail('bus cleanup raised ' + E.ClassName + ': ' + E.Message);
      end;
    if Opened then AsProgrammer.Programmer.DevClose;

    if (not SmartWritePlanOnly) and (ProdSettings.ProdLogFile <> '') and
       (MPHexEditorEx.DataSize > 0) then
      WriteProdLogEntry(MPHexEditorEx.DataSize, LastProgramCRC, LastChipUID);

    SetProgressPos(0);
    LogPrint(STR_OP_RESULT + OpSummary);
    if ControlsLocked then UnlockControl;
  end;
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
  NewName: string;
begin
  if OperationRunning then Exit;
  OpBegin(opkDetect);
try
  ButtonCancel.Tag := 0;

  if not RadioSPI.Checked then
  begin
    LogPrint(STR_SECTOR_SPI25_ONLY);
    OpFail('SFDP is only available for SPI 25 series chips');
    Exit;
  end;

  if not OpenDevice() then
  begin
    OpFail('the programmer could not be opened');
    Exit;
  end;
  LockControl();

  LogPrint(STR_SFDP_READING);
  EnterProgMode25(SetSPISpeed(0), MenuSendAB.Checked);

  //รหัสผู้ผลิตทำให้ตั้งชื่อรายการที่บันทึกได้ตรงยี่ห้อ
  EnsureChipHints;

  if not SFDPDetect(Info) then
  begin
    LogPrint(STR_SFDP_NOT_FOUND);
    OpFail('this chip has no SFDP table');
    Exit;
  end;

  //ทางเดียวกับตอนตรวจอัตโนมัติ ไม่มีโค้ดสองชุดที่ต้องดูแลให้ตรงกัน
  ApplySFDPInfo(Info);

  //ชิปที่ไม่มีในตารางใด ๆ เก็บไว้ใช้รอบหน้าได้ ไม่ต้องมาตรวจใหม่ทุกครั้ง
  if not CLIMode then
    if MessageDlg('AsProgrammer', Format(STR_CHIPSAVE_Q, [ChipListFile3Name]),
                  mtConfirmation, [mbYes, mbNo], 0) = mrYes then
    begin
      NewName := CurrentICParam.Name;
      if InputQuery('AsProgrammer', STR_CHIPSAVE_NONAME, NewName) then
        if Trim(NewName) <> '' then
        begin
          CurrentICParam.Name := Trim(NewName);
          LabelChipName.Caption := CurrentICParam.Name;
          SaveCurrentChipToUserList(CurrentICParam.Name);
        end;
    end;

finally
  LogPrint(STR_OP_RESULT + OpSummary);
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

    if MainForm.MenuAutoDetectChip.Checked then
      TDOMElement(ParentNode).SetAttribute('auto_detect_chip', '1') else
        TDOMElement(ParentNode).SetAttribute('auto_detect_chip', '0');

    if MainForm.MenuBlankBeforeWrite.Checked then
      TDOMElement(ParentNode).SetAttribute('blank_before_write', '1') else
        TDOMElement(ParentNode).SetAttribute('blank_before_write', '0');

    if MainForm.MenuCheckIDBefore.Checked then
      TDOMElement(ParentNode).SetAttribute('check_id', '1') else
        TDOMElement(ParentNode).SetAttribute('check_id', '0');

    //Recovery backups are an admission requirement, not a user preference.
    TDOMElement(ParentNode).SetAttribute('auto_backup', '1');

    TDOMElement(ParentNode).SetAttribute('connection_doctor_seen',
      BoolToStr(ConnectionDoctorSeen, '1', '0'));

    if MainForm.MenuFastRead.Checked then
      TDOMElement(ParentNode).SetAttribute('fast_read', '1') else
        TDOMElement(ParentNode).SetAttribute('fast_read', '0');

    if MainForm.MenuResetChip.Checked then
      TDOMElement(ParentNode).SetAttribute('reset_chip', '1') else
        TDOMElement(ParentNode).SetAttribute('reset_chip', '0');

    if MainForm.MenuVerifyErase.Checked then
      TDOMElement(ParentNode).SetAttribute('verify_erase', '1') else
        TDOMElement(ParentNode).SetAttribute('verify_erase', '0');

    if MainForm.MenuDoubleRead.Checked then
      TDOMElement(ParentNode).SetAttribute('double_read', '1') else
        TDOMElement(ParentNode).SetAttribute('double_read', '0');

    if MainForm.MenuCheckContact.Checked then
      TDOMElement(ParentNode).SetAttribute('check_contact', '1') else
        TDOMElement(ParentNode).SetAttribute('check_contact', '0');

    if MainForm.MenuScanImage.Checked then
      TDOMElement(ParentNode).SetAttribute('scan_image', '1') else
        TDOMElement(ParentNode).SetAttribute('scan_image', '0');

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
    if MainForm.MenuHWSERPROG.Checked then
      TDOMElement(ParentNode).SetAttribute('hw', 'serprog');
    if MainForm.MenuHWEZP.Checked then
      TDOMElement(ParentNode).SetAttribute('hw', 'ezp');

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
    TDOMElement(ParentNode).SetAttribute('prod_logfile', ProdSettings.ProdLogFile);
    TDOMElement(ParentNode).SetAttribute('prod_operator', ProdSettings.Operator_);
    TDOMElement(ParentNode).SetAttribute('prod_jobfile', ProdSettings.JobFile);
    TDOMElement(ParentNode).SetAttribute('prod_checkuid', BoolToStr(ProdSettings.CheckUID, '1', '0'));

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
    TDOMElement(ParentNode).SetAttribute('serprog_comport', Serprog_COMPort);
    TDOMElement(ParentNode).SetAttribute('serprog_baudrate', IntToStr(Serprog_BaudRate));

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

      if  Node.Attributes.GetNamedItem('auto_detect_chip') <> nil then
        MainForm.MenuAutoDetectChip.Checked :=
          Node.Attributes.GetNamedItem('auto_detect_chip').NodeValue = '1';

      if  Node.Attributes.GetNamedItem('check_id') <> nil then
        MainForm.MenuCheckIDBefore.Checked :=
          Node.Attributes.GetNamedItem('check_id').NodeValue = '1';

      //Migrate older profiles that allowed this safety gate to be disabled.
      MainForm.MenuAutoBackup.Checked := True;

      if Node.Attributes.GetNamedItem('connection_doctor_seen') <> nil then
        ConnectionDoctorSeen :=
          Node.Attributes.GetNamedItem('connection_doctor_seen').NodeValue = '1';

      if  Node.Attributes.GetNamedItem('fast_read') <> nil then
        MainForm.MenuFastRead.Checked :=
          Node.Attributes.GetNamedItem('fast_read').NodeValue = '1';

      if  Node.Attributes.GetNamedItem('reset_chip') <> nil then
        MainForm.MenuResetChip.Checked :=
          Node.Attributes.GetNamedItem('reset_chip').NodeValue = '1';

      if  Node.Attributes.GetNamedItem('verify_erase') <> nil then
        MainForm.MenuVerifyErase.Checked :=
          Node.Attributes.GetNamedItem('verify_erase').NodeValue = '1';

      if  Node.Attributes.GetNamedItem('double_read') <> nil then
        MainForm.MenuDoubleRead.Checked :=
          Node.Attributes.GetNamedItem('double_read').NodeValue = '1';

      if  Node.Attributes.GetNamedItem('check_contact') <> nil then
        MainForm.MenuCheckContact.Checked :=
          Node.Attributes.GetNamedItem('check_contact').NodeValue = '1';

      if  Node.Attributes.GetNamedItem('scan_image') <> nil then
        MainForm.MenuScanImage.Checked :=
          Node.Attributes.GetNamedItem('scan_image').NodeValue = '1';

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

      if Node.Attributes.GetNamedItem('prod_logfile') <> nil then
        ProdSettings.ProdLogFile := UTF16ToUTF8(Node.Attributes.GetNamedItem('prod_logfile').NodeValue);

      if Node.Attributes.GetNamedItem('prod_operator') <> nil then
        ProdSettings.Operator_ := UTF16ToUTF8(Node.Attributes.GetNamedItem('prod_operator').NodeValue);

      if Node.Attributes.GetNamedItem('prod_jobfile') <> nil then
        ProdSettings.JobFile := UTF16ToUTF8(Node.Attributes.GetNamedItem('prod_jobfile').NodeValue);

      if Node.Attributes.GetNamedItem('prod_checkuid') <> nil then
        ProdSettings.CheckUID := Node.Attributes.GetNamedItem('prod_checkuid').NodeValue = '1';

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

        if OptVal = 'serprog' then
        begin
          MainForm.MenuHWSERPROG.Checked := true;
          SelectHW(CHW_SERPROG);
        end;

        if OptVal = 'ezp' then
        begin
          MainForm.MenuHWEZP.Checked := true;
          SelectHW(CHW_EZP);
        end;


      end;

      if  Node.Attributes.GetNamedItem('arduino_comport') <> nil then
      begin
        OptVal := UTF16ToUTF8(Node.Attributes.GetNamedItem('arduino_comport').NodeValue);

        Arduino_COMPort := OptVal;
        MainForm.MenuArduinoCOMPort.Caption := 'Arduino COMPort: '+ Arduino_COMPort;
      end;

      if  Node.Attributes.GetNamedItem('serprog_comport') <> nil then
      begin
        OptVal := UTF16ToUTF8(Node.Attributes.GetNamedItem('serprog_comport').NodeValue);
        Serprog_COMPort := OptVal;
        MainForm.MenuSerprogCOMPort.Caption := 'Serprog COMPort: '+ Serprog_COMPort;
      end;

      if  Node.Attributes.GetNamedItem('serprog_baudrate') <> nil then
      begin
        OptVal := UTF16ToUTF8(Node.Attributes.GetNamedItem('serprog_baudrate').NodeValue);
        Serprog_BaudRate := StrToIntDef(OptVal, 115200);
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
