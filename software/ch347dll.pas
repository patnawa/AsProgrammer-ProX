unit CH347DLL;

// CH347 vendor-driver binding, resolved at run time.
//
// These used to be static `external 'CH347DLL.DLL'` imports.  Static imports
// are resolved by Windows at process start, so a missing CH347DLL.DLL kept
// the whole program from launching -- even for someone who only owns a CH341
// or an FT232H.  Now the DLL is loaded on first use; if it is absent, every
// call fails the same way an unplugged programmer does, and the UI reports
// "no programmer", not a system error dialog before the window exists.
//
// The wrapper functions keep the exact vendor names and signatures, so call
// sites did not change.

{$mode objfpc}{$H+}

interface

uses
  SysUtils, utilfunc;

//SPI Controller Configuration
type _SPI_CONFIG = packed record
	iMode: byte;                 // 0-3:SPI Mode0/1/2/3
	iClock: byte;                // 0=60MHz, 1=30MHz, 2=15MHz, 3=7.5MHz, 4=3.75MHz, 5=1.875MHz, 6=937.5KHz,7=468.75KHz
	iByteOrder: byte;            // 0=LSB first(LSB), 1=MSB first(MSB)
	iSpiWriteReadInterval: word; // The SPI interface routinely reads and writes data command, the unit is uS
	iSpiOutDefaultData: byte;    // SPI prints data by default when it reads data
	iChipSelect: cardinal;           // Piece of selected control, if bit 7 is 0, slice selection control is ignored, if bit 7 is 1, the parameter is valid: bit 1 bit 0 is 00/01 and CS1/CS2 pins are selected as low level active chip options respectively
	CS1Polarity: byte;           // Bit 0: CS1 polarity control: 0: effective low level; 1: effective lhigh level;
	CS2Polarity: byte;           // Bit 0: CS2 polarity control: 0: effective low level; 1: effective lhigh level;
	iIsAutoDeativeCS: word;      // Whether to undo slice selection automatically after the operation is complete
	iActiveDelay: word;          // Set the latency for read/write operations after slice selection,the unit is us
	iDelayDeactive: cardinal;        // Delay time for read and write operations after slice selection is unselected,the unit is us
end;

  mpSpiCfgS = ^_SPI_CONFIG;

const
  mCH347_PACKET_LENGTH = 512;		// Length of packets supported by ch347
  mCH341_MAX_NUMBER = 16;			// Maximum number of CH375 connected at the same time

  mCH341A_CMD_I2C_STREAM = $AA;		// The command package of the I2C interface, starting from the secondary byte, is the I2C command stream

  mCH341A_CMD_I2C_STM_STA =	$74;		// Command flow of I2C interface: generate start bit
  mCH341A_CMD_I2C_STM_STO =	$75;		// Command flow of I2C interface: generate stop bit
  mCH341A_CMD_I2C_STM_OUT =	$80;		// Command flow of I2C interface: output data, bit 5- bit 0 is the length, subsequent bytes are data, and length 0 only sends one byte and returns an answer
  mCH341A_CMD_I2C_STM_IN =	$C0;		// I2C interface command flow: input data, bit 5-bit 0 is the length, and 0 length only receives one byte and sends no response
  mCH341A_CMD_I2C_STM_SET =	$60;		// Command flow of I2C interface: set parameters, bit 2=i/o number of SPI (0= single input single output, 1= double input double output), bit 1 0=i2c speed (00= low speed, 01= standard, 10= fast, 11= high speed)
  mCH341A_CMD_I2C_STM_US =	$40;		// Command flow of I2C interface: delay in microseconds, bit 3- bit 0 as delay value
  mCH341A_CMD_I2C_STM_MS =	$50;		// Command flow of I2C interface: delay in microseconds, bit 3-bit 0 as delay value
  mCH341A_CMD_I2C_STM_DLY =	$0F;		// Maximum value of single command delay of command flow of I2C interface
  mCH341A_CMD_I2C_STM_END =	$00;		// Command flow of I2C interface: Command package ends in advance

//ค่าคงที่ของชนิดชิปกับกติกาการคัดอุปกรณ์อยู่ใน utilfunc เพราะเป็นข้อมูลล้วน
//ทดสอบได้โดยไม่ต้องมี DLL จริง ที่นี่แค่ re-export ให้ผู้เรียกเดิมไม่ต้องแก้

//True when CH347DLL.DLL is present and every entry point resolved.
//False plus a reason otherwise; callers may show the reason once.
function CH347DriverAvailable(out Error: string): boolean;

//ถามว่าอุปกรณ์ที่เปิดไว้ที่ดัชนีนี้เป็นชิปตระกูลไหน คืน CH347_CHIP_UNKNOWN
//เมื่อ DLL รุ่นนั้นไม่มี export ตัวนี้ (รุ่นเก่าไม่มี) ผู้เรียกต้องรับมือได้
function CH347ChipType(iIndex: cardinal): integer;

//พาธของอุปกรณ์ที่ดัชนีนี้ คืนสตริงว่างเมื่อถามไม่ได้
//
//ตั้งใจอ่านผ่าน CH341GetDeviceName ของ CH347DLL.DLL ไม่ใช่ของ CH341DLL.DLL
//เพราะ DLL ตัวนี้ใช้ตารางแฮนเดิลร่วมกันทั้งสองตระกูล ดัชนีที่ CH347OpenDevice
//เปิดไว้จึงเป็นดัชนีเดียวกับที่ฟังก์ชันนี้อ่าน ส่วน DLL คนละไฟล์กันไล่ลำดับ
//อุปกรณ์ของใครของมัน เอามาปนกันแล้วจะได้พาธของเครื่องอื่นเมื่อเสียบหลายตัว
//ต้องเรียกหลังเปิดอุปกรณ์สำเร็จแล้วเท่านั้น
function CH347DeviceName(iIndex: cardinal): string;

//มี export ของ GPIO ให้ใช้ไหม
//
//แยกถามต่างหากเพราะสองตัวนี้ผูกแบบไม่บังคับ DLL รุ่นเก่าขาดไปก็ยังอ่านเขียน
//ชิปได้ตามปกติ เสียแค่สลับแรงดันกับไฟแสดงการทำงานไม่ได้ ผู้เรียกจึงต้องถาม
//ก่อนจะไปโฆษณาความสามารถนี้กับผู้ใช้
function CH347GPIOAvailable: boolean;

//อ่านทิศทางกับระดับของ GPIO ทั้งแปดขาในไบต์เดียว บิต n คือ GPIOn
//ทิศทาง 1 = ขาออก
function CH347GPIO_Get(iIndex: cardinal; iDir: pbyte;
  iData: pbyte): boolean; stdcall;

//ตั้ง GPIO เฉพาะขาที่ธงใน iEnable เปิดไว้ ขาที่ไม่ได้เลือกไม่ถูกแตะ
function CH347GPIO_Set(iIndex: cardinal; iEnable: byte;
  iSetDirOut: byte; iSetDataOut: byte): boolean; stdcall;

function CH347OpenDevice(DevI: cardinal): integer; stdcall;
function CH347CloseDevice(iIndex: cardinal): boolean; stdcall;
function CH347ReadData(iIndex: cardinal; oBuffer: pointer;
  ioLength: pcardinal): boolean; stdcall;
function CH347WriteData(iIndex: cardinal; iBuffer: pointer;
  ioLength: pcardinal): boolean; stdcall;
function CH347SPI_Init(iIndex: cardinal; SpiCfg: mpSpiCfgS): boolean; stdcall;
function CH347SPI_ChangeCS(iIndex: cardinal; iStatus: byte): boolean; stdcall;
function CH347SPI_SetChipSelect(iIndex: cardinal; iEnableSelect: word;
  iChipSelect: word; iIsAutoDeativeCS: cardinal; iActiveDelay: cardinal;
  iDelayDeactive: cardinal): boolean; stdcall;
function CH347SPI_Write(iIndex: cardinal; iChipSelect: cardinal;
  iLength: cardinal; iWriteStep: cardinal; ioBuffer: pointer): boolean; stdcall;
function CH347SPI_Read(iIndex: cardinal; iChipSelect: cardinal;
  oLength: cardinal; iLength: pcardinal; ioBuffer: pointer): boolean; stdcall;
function CH347SPI_WriteRead(iIndex: cardinal; iChipSelect: cardinal;
  iLength: cardinal; ioBuffer: pointer): boolean; stdcall;
function CH347StreamSPI4(iIndex: cardinal; iChipSelect: cardinal;
  iLength: cardinal; ioBuffer: pointer): boolean; stdcall;
function CH347I2C_Set(iIndex: cardinal; iMode: cardinal): boolean; stdcall;
function CH347I2C_SetDelaymS(iIndex: cardinal;
  iDelay: cardinal): boolean; stdcall;
function CH347StreamI2C(iIndex: cardinal; iWriteLength: cardinal;
  iWriteBuffer: pointer; iReadLength: cardinal;
  oReadBuffer: pointer): boolean; stdcall;

implementation

{$IFDEF WINDOWS}
uses
  Windows;

type
  T_CH347OpenDevice = function(DevI: cardinal): integer; stdcall;
  T_CH347CloseDevice = function(iIndex: cardinal): boolean; stdcall;
  T_CH347ReadData = function(iIndex: cardinal; oBuffer: pointer;
    ioLength: pcardinal): boolean; stdcall;
  T_CH347WriteData = function(iIndex: cardinal; iBuffer: pointer;
    ioLength: pcardinal): boolean; stdcall;
  T_CH347SPI_Init = function(iIndex: cardinal;
    SpiCfg: mpSpiCfgS): boolean; stdcall;
  T_CH347SPI_ChangeCS = function(iIndex: cardinal;
    iStatus: byte): boolean; stdcall;
  T_CH347SPI_SetChipSelect = function(iIndex: cardinal; iEnableSelect: word;
    iChipSelect: word; iIsAutoDeativeCS: cardinal; iActiveDelay: cardinal;
    iDelayDeactive: cardinal): boolean; stdcall;
  T_CH347SPI_Write = function(iIndex: cardinal; iChipSelect: cardinal;
    iLength: cardinal; iWriteStep: cardinal;
    ioBuffer: pointer): boolean; stdcall;
  T_CH347SPI_Read = function(iIndex: cardinal; iChipSelect: cardinal;
    oLength: cardinal; iLength: pcardinal;
    ioBuffer: pointer): boolean; stdcall;
  T_CH347SPI_WriteRead = function(iIndex: cardinal; iChipSelect: cardinal;
    iLength: cardinal; ioBuffer: pointer): boolean; stdcall;
  T_CH347StreamSPI4 = function(iIndex: cardinal; iChipSelect: cardinal;
    iLength: cardinal; ioBuffer: pointer): boolean; stdcall;
  T_CH347I2C_Set = function(iIndex: cardinal;
    iMode: cardinal): boolean; stdcall;
  T_CH347I2C_SetDelaymS = function(iIndex: cardinal;
    iDelay: cardinal): boolean; stdcall;
  T_CH347StreamI2C = function(iIndex: cardinal; iWriteLength: cardinal;
    iWriteBuffer: pointer; iReadLength: cardinal;
    oReadBuffer: pointer): boolean; stdcall;
  T_CH347GetChipType = function(iIndex: cardinal): byte; stdcall;
  T_CH341GetDeviceName = function(iIndex: cardinal): Pointer; stdcall;
  T_CH347GPIO_Get = function(iIndex: cardinal; iDir: pbyte;
    iData: pbyte): boolean; stdcall;
  T_CH347GPIO_Set = function(iIndex: cardinal; iEnable: byte;
    iSetDirOut: byte; iSetDataOut: byte): boolean; stdcall;

var
  Lib: HMODULE = 0;
  LoadTried: boolean = False;
  LoadError: string = '';
  LoadLock: TRTLCriticalSection;

  p_CH347OpenDevice: T_CH347OpenDevice = nil;
  p_CH347CloseDevice: T_CH347CloseDevice = nil;
  p_CH347ReadData: T_CH347ReadData = nil;
  p_CH347WriteData: T_CH347WriteData = nil;
  p_CH347SPI_Init: T_CH347SPI_Init = nil;
  p_CH347SPI_ChangeCS: T_CH347SPI_ChangeCS = nil;
  p_CH347SPI_SetChipSelect: T_CH347SPI_SetChipSelect = nil;
  p_CH347SPI_Write: T_CH347SPI_Write = nil;
  p_CH347SPI_Read: T_CH347SPI_Read = nil;
  p_CH347SPI_WriteRead: T_CH347SPI_WriteRead = nil;
  p_CH347StreamSPI4: T_CH347StreamSPI4 = nil;
  p_CH347I2C_Set: T_CH347I2C_Set = nil;
  p_CH347I2C_SetDelaymS: T_CH347I2C_SetDelaymS = nil;
  p_CH347StreamI2C: T_CH347StreamI2C = nil;
  //ตัวเลือกเสริม ไม่ได้อยู่ในชุดที่บังคับต้องมี DLL รุ่นเก่าไม่มี export นี้
  p_CH347GetChipType: T_CH347GetChipType = nil;
  p_CH341GetDeviceName: T_CH341GetDeviceName = nil;
  p_CH347GPIO_Get: T_CH347GPIO_Get = nil;
  p_CH347GPIO_Set: T_CH347GPIO_Set = nil;

function Resolve(const Name: string; out Proc: FARPROC): boolean;
begin
  Proc := GetProcAddress(Lib, PChar(Name));
  Result := Proc <> nil;
  if not Result then
    LoadError := 'CH347DLL.DLL does not export ' + Name;
end;

function EnsureCH347: boolean;
var
  Loaded: HMODULE;
begin
  //งานยาวรันบน worker thread ขณะที่ PollProgrammer ยังเดินอยู่บน thread หลัก
  //ทั้งสองเข้ามาที่นี่พร้อมกันได้ ถ้าตั้ง Lib ก่อน resolve เสร็จ อีก thread
  //จะเห็นว่า "โหลดแล้ว" แล้วเรียกพอยน์เตอร์ที่ยังเป็น nil
  EnterCriticalSection(LoadLock);
  try
  if not LoadTried then
  begin
    Loaded := LoadLibrary('CH347DLL.DLL');
    Lib := Loaded;
    if Lib = 0 then
      LoadError := 'CH347DLL.DLL was not found next to the program'
    else if not (Resolve('CH347OpenDevice', FARPROC(p_CH347OpenDevice)) and
                 Resolve('CH347CloseDevice', FARPROC(p_CH347CloseDevice)) and
                 Resolve('CH347ReadData', FARPROC(p_CH347ReadData)) and
                 Resolve('CH347WriteData', FARPROC(p_CH347WriteData)) and
                 Resolve('CH347SPI_Init', FARPROC(p_CH347SPI_Init)) and
                 Resolve('CH347SPI_ChangeCS',
                         FARPROC(p_CH347SPI_ChangeCS)) and
                 Resolve('CH347SPI_SetChipSelect',
                         FARPROC(p_CH347SPI_SetChipSelect)) and
                 Resolve('CH347SPI_Write', FARPROC(p_CH347SPI_Write)) and
                 Resolve('CH347SPI_Read', FARPROC(p_CH347SPI_Read)) and
                 Resolve('CH347SPI_WriteRead',
                         FARPROC(p_CH347SPI_WriteRead)) and
                 Resolve('CH347StreamSPI4', FARPROC(p_CH347StreamSPI4)) and
                 Resolve('CH347I2C_Set', FARPROC(p_CH347I2C_Set)) and
                 Resolve('CH347I2C_SetDelaymS',
                         FARPROC(p_CH347I2C_SetDelaymS)) and
                 Resolve('CH347StreamI2C', FARPROC(p_CH347StreamI2C))) then
    begin
      FreeLibrary(Lib);
      Lib := 0;
    end;
    //ผูกแยกจากชุดบังคับ ขาดไปก็ยังใช้ CH347 ได้ตามปกติ แค่แยกชิปไม่ออก
    if Lib <> 0 then
    begin
      p_CH347GetChipType :=
        T_CH347GetChipType(GetProcAddress(Lib, 'CH347GetChipType'));
      p_CH341GetDeviceName :=
        T_CH341GetDeviceName(GetProcAddress(Lib, 'CH341GetDeviceName'));
      p_CH347GPIO_Get :=
        T_CH347GPIO_Get(GetProcAddress(Lib, 'CH347GPIO_Get'));
      p_CH347GPIO_Set :=
        T_CH347GPIO_Set(GetProcAddress(Lib, 'CH347GPIO_Set'));
    end;
    //ตั้งธงเป็นอันสุดท้าย หลังพอยน์เตอร์ทุกตัวพร้อมใช้งานแล้วจริง ๆ
    LoadTried := True;
  end;
  Result := Lib <> 0;
  finally
    LeaveCriticalSection(LoadLock);
  end;
end;

function CH347DriverAvailable(out Error: string): boolean;
begin
  Result := EnsureCH347;
  if Result then Error := '' else Error := LoadError;
end;

function CH347ChipType(iIndex: cardinal): integer;
begin
  if not EnsureCH347 then Exit(CH347_CHIP_UNKNOWN);
  if p_CH347GetChipType = nil then Exit(CH347_CHIP_UNKNOWN);
  Result := p_CH347GetChipType(iIndex);
end;

function CH347DeviceName(iIndex: cardinal): string;
var
  Name: Pointer;
begin
  Result := '';
  if not EnsureCH347 then Exit;
  if p_CH341GetDeviceName = nil then Exit;
  Name := p_CH341GetDeviceName(iIndex);
  if Name = nil then Exit;
  Result := string(AnsiString(PAnsiChar(Name)));
end;

function CH347GPIOAvailable: boolean;
begin
  Result := EnsureCH347 and (p_CH347GPIO_Get <> nil) and
            (p_CH347GPIO_Set <> nil);
end;

function CH347GPIO_Get(iIndex: cardinal; iDir: pbyte;
  iData: pbyte): boolean; stdcall;
begin
  if not EnsureCH347 then Exit(False);
  if p_CH347GPIO_Get = nil then Exit(False);
  Result := p_CH347GPIO_Get(iIndex, iDir, iData);
end;

function CH347GPIO_Set(iIndex: cardinal; iEnable: byte;
  iSetDirOut: byte; iSetDataOut: byte): boolean; stdcall;
begin
  if not EnsureCH347 then Exit(False);
  if p_CH347GPIO_Set = nil then Exit(False);
  Result := p_CH347GPIO_Set(iIndex, iEnable, iSetDirOut, iSetDataOut);
end;

function CH347OpenDevice(DevI: cardinal): integer; stdcall;
begin
  if not EnsureCH347 then Exit(-1);
  Result := p_CH347OpenDevice(DevI);
end;

function CH347CloseDevice(iIndex: cardinal): boolean; stdcall;
begin
  if not EnsureCH347 then Exit(False);
  Result := p_CH347CloseDevice(iIndex);
end;

function CH347ReadData(iIndex: cardinal; oBuffer: pointer;
  ioLength: pcardinal): boolean; stdcall;
begin
  if not EnsureCH347 then Exit(False);
  Result := p_CH347ReadData(iIndex, oBuffer, ioLength);
end;

function CH347WriteData(iIndex: cardinal; iBuffer: pointer;
  ioLength: pcardinal): boolean; stdcall;
begin
  if not EnsureCH347 then Exit(False);
  Result := p_CH347WriteData(iIndex, iBuffer, ioLength);
end;

function CH347SPI_Init(iIndex: cardinal; SpiCfg: mpSpiCfgS): boolean; stdcall;
begin
  if not EnsureCH347 then Exit(False);
  Result := p_CH347SPI_Init(iIndex, SpiCfg);
end;

function CH347SPI_ChangeCS(iIndex: cardinal; iStatus: byte): boolean; stdcall;
begin
  if not EnsureCH347 then Exit(False);
  Result := p_CH347SPI_ChangeCS(iIndex, iStatus);
end;

function CH347SPI_SetChipSelect(iIndex: cardinal; iEnableSelect: word;
  iChipSelect: word; iIsAutoDeativeCS: cardinal; iActiveDelay: cardinal;
  iDelayDeactive: cardinal): boolean; stdcall;
begin
  if not EnsureCH347 then Exit(False);
  Result := p_CH347SPI_SetChipSelect(iIndex, iEnableSelect, iChipSelect,
    iIsAutoDeativeCS, iActiveDelay, iDelayDeactive);
end;

function CH347SPI_Write(iIndex: cardinal; iChipSelect: cardinal;
  iLength: cardinal; iWriteStep: cardinal; ioBuffer: pointer): boolean; stdcall;
begin
  if not EnsureCH347 then Exit(False);
  Result := p_CH347SPI_Write(iIndex, iChipSelect, iLength, iWriteStep,
                             ioBuffer);
end;

function CH347SPI_Read(iIndex: cardinal; iChipSelect: cardinal;
  oLength: cardinal; iLength: pcardinal; ioBuffer: pointer): boolean; stdcall;
begin
  if not EnsureCH347 then Exit(False);
  Result := p_CH347SPI_Read(iIndex, iChipSelect, oLength, iLength, ioBuffer);
end;

function CH347SPI_WriteRead(iIndex: cardinal; iChipSelect: cardinal;
  iLength: cardinal; ioBuffer: pointer): boolean; stdcall;
begin
  if not EnsureCH347 then Exit(False);
  Result := p_CH347SPI_WriteRead(iIndex, iChipSelect, iLength, ioBuffer);
end;

function CH347StreamSPI4(iIndex: cardinal; iChipSelect: cardinal;
  iLength: cardinal; ioBuffer: pointer): boolean; stdcall;
begin
  if not EnsureCH347 then Exit(False);
  Result := p_CH347StreamSPI4(iIndex, iChipSelect, iLength, ioBuffer);
end;

function CH347I2C_Set(iIndex: cardinal; iMode: cardinal): boolean; stdcall;
begin
  if not EnsureCH347 then Exit(False);
  Result := p_CH347I2C_Set(iIndex, iMode);
end;

function CH347I2C_SetDelaymS(iIndex: cardinal;
  iDelay: cardinal): boolean; stdcall;
begin
  if not EnsureCH347 then Exit(False);
  Result := p_CH347I2C_SetDelaymS(iIndex, iDelay);
end;

function CH347StreamI2C(iIndex: cardinal; iWriteLength: cardinal;
  iWriteBuffer: pointer; iReadLength: cardinal;
  oReadBuffer: pointer): boolean; stdcall;
begin
  if not EnsureCH347 then Exit(False);
  Result := p_CH347StreamI2C(iIndex, iWriteLength, iWriteBuffer,
                             iReadLength, oReadBuffer);
end;

{$ELSE}

// Non-Windows: the CH347 vendor DLL does not exist here.  Every call fails
// like an absent device until the libusb backend (design doc phase 3) lands.

function CH347DriverAvailable(out Error: string): boolean;
begin
  Error := 'the CH347 vendor driver is only available on Windows';
  Result := False;
end;

function CH347ChipType(iIndex: cardinal): integer;
begin
  Result := CH347_CHIP_UNKNOWN;
end;

function CH347DeviceName(iIndex: cardinal): string;
begin
  Result := '';
end;

function CH347GPIOAvailable: boolean;
begin
  Result := False;
end;

function CH347GPIO_Get(iIndex: cardinal; iDir: pbyte;
  iData: pbyte): boolean; stdcall;
begin
  Result := False;
end;

function CH347GPIO_Set(iIndex: cardinal; iEnable: byte;
  iSetDirOut: byte; iSetDataOut: byte): boolean; stdcall;
begin
  Result := False;
end;

function CH347OpenDevice(DevI: cardinal): integer; stdcall;
begin
  Result := -1;
end;

function CH347CloseDevice(iIndex: cardinal): boolean; stdcall;
begin
  Result := False;
end;

function CH347ReadData(iIndex: cardinal; oBuffer: pointer;
  ioLength: pcardinal): boolean; stdcall;
begin
  Result := False;
end;

function CH347WriteData(iIndex: cardinal; iBuffer: pointer;
  ioLength: pcardinal): boolean; stdcall;
begin
  Result := False;
end;

function CH347SPI_Init(iIndex: cardinal; SpiCfg: mpSpiCfgS): boolean; stdcall;
begin
  Result := False;
end;

function CH347SPI_ChangeCS(iIndex: cardinal; iStatus: byte): boolean; stdcall;
begin
  Result := False;
end;

function CH347SPI_SetChipSelect(iIndex: cardinal; iEnableSelect: word;
  iChipSelect: word; iIsAutoDeativeCS: cardinal; iActiveDelay: cardinal;
  iDelayDeactive: cardinal): boolean; stdcall;
begin
  Result := False;
end;

function CH347SPI_Write(iIndex: cardinal; iChipSelect: cardinal;
  iLength: cardinal; iWriteStep: cardinal; ioBuffer: pointer): boolean; stdcall;
begin
  Result := False;
end;

function CH347SPI_Read(iIndex: cardinal; iChipSelect: cardinal;
  oLength: cardinal; iLength: pcardinal; ioBuffer: pointer): boolean; stdcall;
begin
  Result := False;
end;

function CH347SPI_WriteRead(iIndex: cardinal; iChipSelect: cardinal;
  iLength: cardinal; ioBuffer: pointer): boolean; stdcall;
begin
  Result := False;
end;

function CH347StreamSPI4(iIndex: cardinal; iChipSelect: cardinal;
  iLength: cardinal; ioBuffer: pointer): boolean; stdcall;
begin
  Result := False;
end;

function CH347I2C_Set(iIndex: cardinal; iMode: cardinal): boolean; stdcall;
begin
  Result := False;
end;

function CH347I2C_SetDelaymS(iIndex: cardinal;
  iDelay: cardinal): boolean; stdcall;
begin
  Result := False;
end;

function CH347StreamI2C(iIndex: cardinal; iWriteLength: cardinal;
  iWriteBuffer: pointer; iReadLength: cardinal;
  oReadBuffer: pointer): boolean; stdcall;
begin
  Result := False;
end;

{$ENDIF}

{$IFDEF WINDOWS}
initialization
  InitCriticalSection(LoadLock);

finalization
  DoneCriticalSection(LoadLock);
{$ENDIF}

end.
