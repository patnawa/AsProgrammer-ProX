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
  opresult, prodlog, chipsave, flashops, imgcheck,
  operationmodel, norplanner, norengine, spi25noradapter, prodcrypto,
  prodevidence, eepromengine, eepromadapters,
  pascalc, ScriptsFunc, ScriptEdit, comparewnd, appver,
  baseHW, UsbAspHW, ch341hw, ch347hw, avrisphw, arduinohw, buzzpirathw;

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
    FWorkflowPanel: TPanel;
    FWorkflowTitle: TLabel;
    FWorkflowState: TLabel;
    FWorkflowSep: TPanel;
    FWorkflowDetect: TButton;
    FWorkflowOpen: TButton;
    FWorkflowSmart: TButton;
    FWorkflowRead: TButton;
    FWorkflowVerify: TButton;
    procedure CreateWorkflowBar;
    procedure LayoutWorkflowBar;
    procedure UpdateWorkflowText;
    procedure UpdateWorkflowState;
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
  procedure PollProgrammer(Announce: boolean);
  function SelectChipAny(const AName: string): boolean;

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

  //สถานะที่วาดเป็นไฟบอกสถานะในแผงด้านซ้าย
  ProgrammerPresent: boolean = False;
  ChipDetected: boolean = False;

  //หน้าต่างหลักขึ้นแล้วหรือยัง ตรวจชิปอัตโนมัติอาจเปิดไดอะล็อก
  //ซึ่งห้ามเกิดตอนที่หน้าต่างยังสร้างไม่เสร็จ
  AppReady: boolean = False;

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

  //โหมดบรรทัดคำสั่งสั่งจำนวนรอบการอ่านมาเองได้ 0 = ใช้ค่าจากหน้าจอ
  CLIReadPasses: integer = 0;

  //รหัส 9Fh ที่อ่านได้ครั้งล่าสุด ใช้ตอนบันทึกชิปใหม่ลงตารางของผู้ใช้
  LastID9F: string = '';

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

//ตัวช่วยที่แถบ Safe workflow ต้องใช้ แต่นิยามอยู่ท้ายไฟล์
function IsEEPROMSmartWriteTarget: boolean; forward;

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

  FWorkflowOpen.Enabled := not OperationRunning;
  FWorkflowDetect.Enabled := (not OperationRunning) and
    ProgrammerPresent and RadioSPI.Checked;
  FWorkflowRead.Enabled := (not OperationRunning) and
    ProgrammerPresent and ChipDetected and SizeKnown;
  FWorkflowVerify.Enabled := FWorkflowRead.Enabled and HasBuffer;
  FWorkflowSmart.Enabled := FWorkflowVerify.Enabled and SmartCapable and
                            FitsChip and MWAligned;

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
  else if SmartCapable then
  begin
    StateText := STR_WORKFLOW_READY;
    StateColor := TColor($5B9E2E);
    NextStep := FWorkflowSmart;
  end
  else
  begin
    StateText := STR_WORKFLOW_LEGACY;
    StateColor := TColor($5B9E2E);
  end;

  //เน้นเฉพาะขั้นที่กดได้จริงตอนนี้ ของเดิมตัวหนาที่ Smart write ตลอดเวลา
  //ซึ่งชี้ไปที่ปุ่มที่ยังกดไม่ได้ตั้งแต่เปิดโปรแกรม
  FWorkflowDetect.Font.Style := [];
  FWorkflowOpen.Font.Style := [];
  FWorkflowSmart.Font.Style := [];
  if (NextStep <> nil) and NextStep.Enabled then
    NextStep.Font.Style := [fsBold];

  FWorkflowState.Caption := StateText;
  FWorkflowState.Hint := StateText;
  FWorkflowState.Font.Color := StateColor;
  FWorkflowState.Font.Style := [fsBold];
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
    //FF ล้วนคือบัสที่ไม่มีใครขับ ไม่ใช่ชิปที่พร้อม (density code 1111 ไม่มีจริง)
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
    for Idx := 0 to Total - 1 do
    begin
      //WEL is cleared by every accepted erase command.  Therefore every
      //sector needs a new WREN followed by an observed WEL=1; checking only
      //the first sector can silently skip all remaining sectors.
      if not WrenOK then Exit;

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

      //ชิปแจ้งเองว่าคำสั่งลบล้มเหลวหรือไม่
      if ChipReportedFailure('erase at 0x' + IntToHex(Plan[Idx].Addr, 8)) then Exit;

      SetProgressPos(Idx + 1);
      OpProcessMessages;

      if UserCancel then Exit;
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

//อ่านซ้ำอีกหลายรอบแล้วเทียบกับรอบแรก
//
//นี่คือด่านเดียวที่จับ "อ่านครบทุกไบต์แต่ได้ข้อมูลผิด" ได้ ซึ่งเป็นความ
//ล้มเหลวที่เงียบที่สุดของงานประเภทนี้ คลิปหนีบที่ขาใดขาหนึ่งแตะไม่สนิท
//ให้ไฟล์ที่ขนาดถูก อ่านครบ ไม่มีข้อความผิดพลาด และมีไบต์ผิดอยู่ข้างใน
//
//เมื่อสองรอบไม่ตรงกัน เราบอกไม่ได้ว่ารอบไหนถูก และไม่ควรเดา
//สิ่งที่บอกได้คือดัมป์นี้เชื่อไม่ได้ ซึ่งเป็นข้อมูลที่มีค่ากว่าการเดา
function ReadPassesAgree(First: TMemoryStream; StartAddress, Size: cardinal;
  Passes: integer): boolean;
var
  Again: TMemoryStream;
  Diff: cardinal;
  At: int64;
  i: integer;
begin
  Result := True;
  if (Passes < 2) or (First = nil) or (First.Size = 0) then Exit;

  Again := TMemoryStream.Create;
  try
    for i := 2 to Passes do
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
        OpFail(Format('two reads of the same chip disagree in %d bytes', [Diff]),
               At);
        Exit(False);
      end;
    end;

    LogPrint(STR_READ_STABLE);
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

  V := ImageVerdict(S);
  if V <> ivOK then
  begin
    LastImageWarning := VerdictText(V, S);
    LogPrint(Format(STR_IMG_SUSPECT, [LastImageWarning]));
  end;
end;

function EnterProgModeSPI25: boolean;
begin
  Result := EnterProgMode25(SetSPISpeed(0), MainForm.MenuSendAB.Checked);
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
    Exit;
  end;

  //ไม่มีคำสั่งไหนได้คำตอบเลย เป็นคนละเรื่องกับชิปผิดรุ่น และคำแนะนำก็คนละอย่าง
  //บอกให้ตรงเรื่อง ไม่งั้นคนจะไปไล่เปลี่ยนรุ่นชิปในเมนูทั้งที่ปัญหาอยู่ที่สาย
  if not (ID.Got9F or ID.Got90 or ID.GotAB or ID.Got15) then
  begin
    LogPrint(STR_ID_NO_ANSWER);
    if CLIMode then Exit(False);
    Result := MessageDlg('AsProgrammer', STR_ID_NO_ANSWER_Q, mtWarning, [mbYes, mbNo], 0) = mrYes;
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
  if CurrentICParam.Vcc <> '' then
  begin
    //ระบุมาแล้วว่าแรงดันเท่าไร ถ้าไม่ใช่ 1.8 ก็ไม่ต้องเตือน
    if Pos('1.8', CurrentICParam.Vcc) = 0 then Exit;
  end
  else
    if Pos('1.8V', UpperCase(CurrentICParam.Name)) = 0 then Exit;

  //Bus Pirate ตั้งขาเป็น open-drain แล้วจ่ายไฟจากภายนอกได้ จึงไม่เตือน
  if AsProgrammer.Current_HW in [CHW_BUZZPIRAT, CHW_ARDUINO] then Exit;

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

  if not SFDPNeeds4BSwitch(Info) then
    Chip25Entry4B := E4B_NONE
  else if Info.Entry4B.WrenB7 then
    Chip25Entry4B := E4B_WREN_B7
  else if Info.Entry4B.B7NoWren then
    Chip25Entry4B := E4B_B7
  else if Info.Entry4B.BankReg17 then
    Chip25Entry4B := E4B_BANK17
  else if Info.Entry4B.ExtAddrReg then
    Chip25Entry4B := E4B_EXTC5
  else if Info.Entry4B.NvConfigB1 then
    Chip25Entry4B := E4B_NVB1;
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

begin
  Result := False;
  LockedAt := 0;
  AnyReadable := False;

  GuardUse4B := ChipSize > 16777216;

  if (StartAddr >= ChipSize) or (Len > ChipSize - StartAddr) then Exit;
  EndAddr := StartAddr + Len;
  if EndAddr <= StartAddr then Exit;

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
        OpFail('target area is write protected by an individual block lock', FromA);
        Exit(False);
      end;

      Result := AskUser(STR_GUARD_Q, False);
      if not Result then
        OpFail('target area is write protected by an individual block lock', FromA);
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
    OpFail('target area is write protected', FromA);
    Exit(False);
  end;

  Result := AskUser(STR_GUARD_Q, False);
  if not Result then OpFail('target area is write protected', FromA);
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

//สำรองเนื้อหาชิปก่อนเขียนหรือลบ
//คืน False เมื่อสำรองไม่สำเร็จ ซึ่งแปลว่าห้ามทำต่อ
function AutoBackupChip(TrustedCopy: TMemoryStream = nil): boolean;
var
  Backup: TMemoryStream;
  Dir, FileName, TempName, ChipName: string;
  i, RequiredPasses: integer;
  SaveFile: boolean;
begin
  Result := True;
  FileName := '';
  TempName := '';
  SaveFile := MainForm.MenuAutoBackup.Checked;

  //A caller asking for TrustedCopy is the transactional planner, not merely
  //the optional backup-file feature.  It always needs two matching full-chip
  //reads even when the user chose not to publish a backup file.
  if (not SaveFile) and (TrustedCopy = nil) then Exit;
  if (not MainForm.RadioSPI.Checked) or
     (MainForm.ComboSPICMD.ItemIndex <> SPI_CMD_25) or
     (OpUI.ChipSize = 0) then
  begin
    //ผู้เรียกที่ขอ TrustedCopy คือตัววางแผนธุรกรรมซึ่งเป็น SPI25 เท่านั้น
    //มาถึงตรงนี้ได้แปลว่าผิดจริงและต้องล้ม ส่วนฟีเจอร์สำรองไฟล์อัตโนมัติ
    //บนตระกูลอื่น (95/45/KB/I2C/MW) ต้องข้ามแบบบอกกล่าวเหมือนเดิม ไม่ใช่
    //ล้มงานเขียนทั้งงานด้วยข้อความที่โทษ backup ทั้งที่ปัญหาคือตระกูลชิป
    if TrustedCopy <> nil then Exit(False);
    LogPrint(STR_BACKUP_SKIPPED);
    Exit;
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

  if SaveFile then
  begin
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
      if not (ChipName[i] in
              ['0'..'9', 'A'..'Z', 'a'..'z', '_', '-', '.']) then
        ChipName[i] := '_';

    FileName := Dir + ChipName + '_' +
                FormatDateTime('yyyymmdd-hhnnss-zzz', Now) + '-' +
                IntToHex(GetTickCount64 and $FFFF, 4) + '.bin';
    TempName := FileName + '.tmp';
  end;

  LogPrint(STR_BACKUP_MAKING);

  Backup := TMemoryStream.Create;
  try
    ReadFlash25(Backup, 0, OpUI.ChipSize);

    if (not OpOK) or (Backup.Size <> OpUI.ChipSize) then
    begin
      LogPrint(STR_BACKUP_FAILED);
      Exit(False);
    end;

    //A full-size wrong read is possible with a marginal clip, so a backup is
    //trusted only after an independent second pass matches byte-for-byte.
    if not ReadPassesAgree(Backup, 0, OpUI.ChipSize, RequiredPasses) then
    begin
      LogPrint(STR_BACKUP_FAILED);
      Exit(False);
    end;

    //The differential programmer needs the exact trusted bytes used for the
    //backup so it can restore neighbours in every erased block.  Return a
    //copy only after both independent reads agreed.
    if TrustedCopy <> nil then
    begin
      TrustedCopy.Clear;
      Backup.Position := 0;
      TrustedCopy.CopyFrom(Backup, Backup.Size);
      TrustedCopy.Position := 0;
    end;

    if SaveFile then
    begin
      //Publish atomically.  A crash or full disk may leave a .tmp file, but can
      //never leave a truncated file carrying the final backup name.
      Backup.SaveToFile(TempName);
      if (not FileExists(TempName)) or
         (FileSizeUtf8(TempName) <> int64(OpUI.ChipSize)) then
      begin
        DeleteFile(TempName);
        LogPrint(STR_BACKUP_FAILED);
        Exit(False);
      end;
      if not RenameFile(TempName, FileName) then
      begin
        DeleteFile(TempName);
        LogPrint(STR_BACKUP_FAILED);
        Exit(False);
      end;
      LogPrint(STR_BACKUP_DONE + FileName);
    end;
  finally
    if (TempName <> '') and FileExists(TempName) then DeleteFile(TempName);
    Backup.Free;
  end;
end;

//ใส่เลขรันนิ่งตัวถัดไปลงในสตรีมก่อนเขียน และถ้ากำหนดไฟล์บันทึกไว้
//ก็เขียนเลขที่จ่ายไปต่อท้ายไฟล์นั้นด้วย
function ApplySerialToStream(Stream: TMemoryStream): boolean;
var
  Data: array of byte;
  Size: integer;
  LogF: TextFile;
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
    LogPrint(STR_SERIAL_WRITTEN + CurrentSerial.Text +
             ' @ 0x' + IntToHex(ProdSettings.SNAddress, 6));

    if ProdSettings.SNLogFile <> '' then
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
          OpFail('the serial-number evidence could not be written: ' +
                 E.Message);
          Exit(False);
        end;
      end;

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
    i: integer;
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

  try
  while (Address-StartAddress) < DataSize do
  begin
    if ChunkSize > (DataSize - (Address-StartAddress)) then ChunkSize := DataSize - (Address-StartAddress);

    Got := ReadData25(ReadOp, FastRead, Use4B, Address, datachunk, ChunkSize);
    if Got <> ChunkSize then
    begin
      OpFail(Format('SPI flash short read during verify: received %d of %d bytes',
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

    Inc(ProgressPos);
    SetProgressPos(ProgressPos);
    ShowSpeed(Address - StartAddress, DataSize, OpStarted);
    OpProcessMessages;

    if UserCancel then Break;
  end;

  finally
    Leave4B;
  end;

  OpProgress(Address - StartAddress, DataSize);

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
    MainForm.UpdateWorkflowState;
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

  //ถอดหรือเสียบเครื่องโปรแกรม แปลว่าซ็อกเก็ตอาจมีชิปคนละตัวแล้ว
  //สิ่งที่รู้เกี่ยวกับชิปตัวเก่าต้องทิ้ง ไม่งั้นจะส่ง opcode ของยี่ห้อที่ไม่ใช่
  if Was <> ProgrammerPresent then
  begin
    Reset25ChipHints;
    ForgetSFDP;
    LastChipUID := '';
    LastID9F := '';
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
    MainForm.ButtonReadIDClick(nil);
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
  MainForm.UpdateWorkflowState;
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
  MainForm.UpdateWorkflowState;
end;

//เลือกชิปตามชื่อ โดยหาในไฟล์หลักก่อน แล้วค่อยหาในไฟล์เสริม
function SelectChipAny(const AName: string): boolean;
begin
  //เปลี่ยนชิปแล้ว สิ่งที่รู้เกี่ยวกับตัวเก่าใช้ไม่ได้อีก
  //ถ้าไม่ล้าง opcode ที่เลือกตามยี่ห้อจะเป็นของชิปตัวก่อนหน้า
  Reset25ChipHints;
  ForgetSFDP;

  Result := findchip.SelectChip(ChipListFile, AName);
  if not Result then
    Result := findchip.SelectChip(ChipListFile2, AName);
  if not Result then
    Result := findchip.SelectChip(ChipListFile3, AName);
  if not Result then
    Result := findchip.SelectChip(ChipListFile4, AName);
  UpdateChipInfo;
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
  StatusBar.Panels.Items[0].Text := STR_SIZE+IntToStr(MPHexEditorEx.DataSize);
  if MPHexEditorEx.Modified then
    StatusBar.Panels.Items[1].Text := STR_CHANGED
  else
    StatusBar.Panels.Items[1].Text := '';
  UpdateWorkflowState;
end;

procedure TMainForm.ComboItem1Click(Sender: TObject);
var
  CheckTemp: Boolean;
begin
  if MessageDlg('AsProgrammer', STR_COMBO_WARN, mtConfirmation, [mbYes, mbNo], 0)
    <> mrYes then Exit;

  //SPI NOR uses the preservation-aware single-owner service.  Other legacy
  //protocols retain their protocol-specific sequence below.
  if RadioSPI.Checked and (ComboSPICMD.ItemIndex = SPI_CMD_25) then
  begin
    MenuSmartWriteClick(ComboItem1);
    Exit;
  end;

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
  if RadioSPI.Checked and (ComboSPICMD.ItemIndex = SPI_CMD_25) then
  begin
    MenuSmartWriteClick(Sender);
    Exit;
  end;

  I2C_ChunkSize := 65535;
  OpBegin(opkWrite);
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
  //built-in writer.  Legacy non-SPI scripts retain their old entry point.
  if (not RadioSPI.Checked) and
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
  HaveCR: boolean;
  P: TProtInfo;
begin
  Result := False;
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
begin
  OpBegin(opkDetect);
  try
    if not OpenDevice() then
    begin
      OpFail('the programmer could not be opened');
      exit;
    end;
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
      OpFail('no chip answered');
      Exit;
    end;

    //เก็บรหัสไว้ใช้ตอนบันทึกชิปใหม่ลงตารางของผู้ใช้
    LastID9F := IDstr9FH;

    Vendor := JedecVendor(ID.ID9FH[0]);
    if Vendor <> '' then LogPrint(STR_VENDOR + Vendor);

    Matches := TStringList.Create;
    try
      //ไล่จาก 9F ก่อน แล้วค่อยลองโอปโค้ดเก่ากว่าถ้ายังไม่เจอ
      //ค้นทั้งไฟล์หลักและไฟล์เสริมพร้อมกัน
      FindChipInto(ChipListFile, '', IDstr9FH, Matches);
      FindChipInto(ChipListFile2, '', IDstr9FH, Matches);
      FindChipInto(ChipListFile3, '', IDstr9FH, Matches);
      FindChipInto(ChipListFile4, '', IDstr9FH, Matches);

      if Matches.Count = 0 then
      begin
        FindChipInto(ChipListFile, '', IDstr90H, Matches);
        FindChipInto(ChipListFile2, '', IDstr90H, Matches);
        FindChipInto(ChipListFile3, '', IDstr90H, Matches);
        FindChipInto(ChipListFile4, '', IDstr90H, Matches);
      end;

      if Matches.Count = 0 then
      begin
        FindChipInto(ChipListFile, '', IDstrABH, Matches);
        FindChipInto(ChipListFile2, '', IDstrABH, Matches);
        FindChipInto(ChipListFile3, '', IDstrABH, Matches);
        FindChipInto(ChipListFile4, '', IDstrABH, Matches);
      end;

      if Matches.Count = 0 then
      begin
        FindChipInto(ChipListFile, '', IDstr15H, Matches);
        FindChipInto(ChipListFile2, '', IDstr15H, Matches);
        FindChipInto(ChipListFile3, '', IDstr15H, Matches);
        FindChipInto(ChipListFile4, '', IDstr15H, Matches);
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

    //ใส่สิ่งที่อ่านมาจากชิปตัวจริงกลับเข้าไป การเลือกรายการอาจล้างมันไปแล้ว
    //ถึงชิปจะมีในตารางอยู่แล้ว วิธีเข้าโหมด 4 ไบต์ก็ยังต้องเอาจาก SFDP
    //เพราะตารางชิปไม่ได้เก็บเรื่องนี้ไว้ และมันต่างกันไปตามยี่ห้อ
    Chip25ManufID := ManufSaved;
    if SfdpOK then
      ApplySFDPHints(Info)
    else
      Chip25SFDPRead := True;

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
      s.Add('Version ' + PROX_VERSION);
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
      if ChipListFile4 <> nil then
        s.Add('chiplist-ezp.xml       ' + IntToStr(CountChips(ChipListFile4)) +
              ' chips  (converted from an EZP database)');
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
    'AsProgrammer ProX ' + PROX_VERSION + LineEnding +
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
var
  Parsed: QWord;
begin
  if StartAddressEdit.Text = '' then StartAddressEdit.Text := '0';
  //Hex2Dec ยกข้อยกเว้นเมื่อเจอข้อความที่ไม่ใช่เลขฐานสิบหก ซึ่งเข้ามาได้ทาง
  //การวาง (ตัวกรองปุ่มกดกันได้แค่การพิมพ์)
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

  SelectHW(CHW_BUZZPIRAT); // ทางลัดแบบหยาบ ๆ ของ dreg

  LoadChipList(ChipListFile);
  LoadChipList(ChipListFile2);
  LoadChipList(ChipListFile3);
  LoadChipList(ChipListFile4);
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
  Caption := 'AsProgrammer ProX ' + PROX_VERSION;
  if Log.Lines.Count > 0 then
    Log.Lines[0] := 'AsProgrammer ProX ' + PROX_VERSION;

  LoadModernIcons;
  CreateWorkflowBar;
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

  //ตั้งแต่นี้ไปเปิดไดอะล็อกได้แล้ว
  //ถ้าเสียบเครื่องโปรแกรมมาตั้งแต่ก่อนเปิดโปรแกรม จังหวะเปลี่ยนสถานะผ่านไปแล้ว
  //จึงต้องตรวจชิปให้หนึ่งครั้งตรงนี้เอง
  AppReady := True;
  if ProgrammerPresent and MenuAutoDetectChip.Checked and RadioSPI.Checked then
    ButtonReadIDClick(nil);
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
  ButtonCancel.Tag := 1;
  RequestOperationCancellation;
  if ActiveNORCancellation <> nil then
    ActiveNORCancellation.RequestCancellation;

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
  OpBegin(opkErase);
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
  if (not RadioSPI.Checked) and
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
  Chunk: cardinal;
  Data: TBytes;
  R: TEEPROMIOResult;
begin
  Result := False;
  Stream.Clear;
  ProgressReset(ChipSize);

  Addr := 0;
  while Addr < ChipSize do
  begin
    //อ่านทีละหลายหน้าเพื่อความเร็ว แต่ไม่เกิน 4KB ต่อครั้ง
    Chunk := PageSize;
    while (Chunk < 4096) and (Chunk + PageSize <= ChipSize - Addr) do
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

//สรุปแผน Smart Write ของ EEPROM เป็นภาษาคน สำหรับโหมดดูแผนอย่างเดียว
procedure LogEEPROMPlanPreview(const Plan: TEEPROMPlan; WriteCycleMs: cardinal);
var
  Writes: integer;
  EtaMs: QWord;
begin
  Writes := EEPROMPlanCountKind(Plan, epsWrite);
  LogPrint('--- Smart Write plan preview: nothing has been written ---');
  if Writes = 0 then
    LogPrint('The chip already matches the image; no page would be written')
  else
    LogPrint(Format('  write: %d pages of %d bytes (%d bytes changed)',
      [Writes, Plan.PageSize, Plan.ChangedBytes]));
  LogPrint(Format('  verify: %d page reads, %d bytes',
    [EEPROMPlanCountKind(Plan, epsVerify), Plan.VerifyBytes]));
  EtaMs := QWord(Writes) * QWord(WriteCycleMs);
  if EtaMs >= 1000 then
    LogPrint(Format('  worst-case write-cycle time: about %d s',
                    [(EtaMs + 999) div 1000]));
  LogPrint('Run Smart write without --plan-only to execute this plan.');
end;

//สรุปแผน Smart Write เป็นภาษาคน สำหรับโหมดดูแผนอย่างเดียว
//เพดานเวลามาจากตัวเลขที่ชิปประกาศเอง (ทาง SFDP DWORD-10/11 ถ้ามี)
procedure LogSmartPlanPreview(const Plan: TNORPlan);
var
  i: SizeInt;
  Op: integer;
  ByOpcode: array[0..255] of integer;
  ByOpcodeBytes: array[0..255] of QWord;
  WorstMs: QWord;
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

  LogPrint('--- Smart Write plan preview: nothing has been written ---');
  if Plan.AffectedLength = 0 then
    LogPrint('The chip already matches the image inside the requested range; ' +
             'no block would be touched')
  else
    LogPrint(Format('Affected range: 0x%.6x .. 0x%.6x (%d bytes)',
      [Plan.AffectedAddress,
       Plan.AffectedAddress + Plan.AffectedLength - 1,
       Plan.AffectedLength]));
  for Op := 0 to 255 do
    if ByOpcode[Op] > 0 then
      LogPrint(Format('  erase %.2xh: %d blocks, %d bytes',
        [Op, ByOpcode[Op], ByOpcodeBytes[Op]]));
  LogPrint(Format('  program: %d page commands, %d bytes ' +
    '(%d preserved neighbour bytes restored)',
    [NORPlanCountKind(Plan, npsProgram), Plan.ProgramBytes,
     Plan.PreservedBytesRewritten]));
  LogPrint(Format('  verify: %d block reads, %d bytes',
    [NORPlanCountKind(Plan, npsVerify), Plan.VerifyBytes]));
  if WorstMs > 0 then
    LogPrint(Format(
      '  chip-declared worst-case erase+program time: about %d s, ' +
      'plus verify readback', [(WorstMs + 999) div 1000]));
  LogPrint('Run Smart write without --plan-only to execute this plan.');
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
    Outcome := Executor.Execute(Request, Plan, Geometry, Token);
  end;

begin
  if OperationRunning then Exit;

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

    if (Sender <> ComboItem1) and (not CLIMode) then
      if MessageDlg('AsProgrammer', STR_COMBO_WARN, mtConfirmation,
                    [mbYes, mbNo], 0) <> mrYes then
      begin
        OpCancel;
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
      OpFail('the chip did not return an exact JEDEC 9Fh identity');
      Exit;
    end;

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
    if not AutoBackupChip(Trusted) then
    begin
      OpFail('a trusted two-pass full-chip snapshot could not be made');
      Exit;
    end;

    PatchStream := TMemoryStream.Create;
    MPHexEditorEx.SaveToStream(PatchStream);
    PatchStream.Position := 0;
    if not ApplySerialToStream(PatchStream) then Exit;
    if not ReserveCurrentSerial then Exit;
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

    //โหมดดูแผนอย่างเดียวจบตรงนี้ ก่อนด่านป้องกันและก่อน UnlockCurrentSPI25
    //ซึ่งเขียน status register จริง แผนถูกพิมพ์ครบแล้ว และชิปยังไม่ถูกแตะ
    if SmartWritePlanOnly then
    begin
      LogSmartPlanPreview(Plan);
      Exit;
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

    //Free full-chip duplicate buffers before execution.  Every byte needed by
    //the physical transaction is now owned by the immutable plan.
    CurrentBytes := nil;
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
    if (ProdSettings.ProdLogFile <> '') and
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
  Snapshot, PatchStream: TMemoryStream;
  Current, Patch: TBytes;
  ChipSize, PageSize, PatchStart, PatchSize, WriteCycleMs: cardinal;
  DevAddr: byte;
  Parsed: QWord;
  Err: string;
  OldWorker: boolean;

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
    LogPrint(STR_BACKUP_MAKING);
    Snapshot := TMemoryStream.Create;
    if not ReadCurrentChipEEPROM(Device, Snapshot, ChipSize, PageSize) then
    begin
      OpFail('a trusted full-chip snapshot could not be read');
      Exit;
    end;

    PatchStream := TMemoryStream.Create;
    MPHexEditorEx.SaveToStream(PatchStream);
    PatchStream.Position := 0;
    if not ApplySerialToStream(PatchStream) then Exit;
    if not ReserveCurrentSerial then Exit;
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

    if SmartWritePlanOnly then
    begin
      LogEEPROMPlanPreview(Plan, WriteCycleMs);
      Exit;
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
    PatchStream.Free;
    Current := nil;
    Patch := nil;
    if PlanBuilt then ClearEEPROMPlan(Plan);

    if BusEntered then
      try
        if RadioSPI.Checked then ExitProgMode25;
      except
        on E: Exception do
          if not LastOp.Failed then
            OpFail('bus cleanup raised ' + E.ClassName + ': ' + E.Message);
      end;
    if Opened then AsProgrammer.Programmer.DevClose;

    if (ProdSettings.ProdLogFile <> '') and (MPHexEditorEx.DataSize > 0) then
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

    if MainForm.MenuAutoBackup.Checked then
      TDOMElement(ParentNode).SetAttribute('auto_backup', '1') else
        TDOMElement(ParentNode).SetAttribute('auto_backup', '0');

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

      if  Node.Attributes.GetNamedItem('auto_backup') <> nil then
        MainForm.MenuAutoBackup.Checked :=
          Node.Attributes.GetNamedItem('auto_backup').NodeValue = '1';

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
