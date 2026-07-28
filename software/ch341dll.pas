unit CH341DLL;
{$mode delphi}
interface
// 2004.05.28, 2004.10.20, 2005.01.08, 2005.03.25
//****************************************
//**  Copyright  (C)  W.ch  1999-2005   **
//**  Web:  http://www.winchiphead.com  **
//****************************************
//**  DLL for USB interface chip CH341  **
//**  C, VC5.0                          **
//****************************************
//
// USB总线接口芯片CH341并口应用层接口库 V1.5
// 南京沁恒电子有限公司  作者: W.ch 2005.03
// CH341-DLL  V1.5
// 运行环境: Windows 98/ME, Windows 2000/XP
// support USB chip: CH341, CH341A
// USB => Parallel, I2C, SPI, JTAG ...
// Частичный перевод TIFA
//
// The entry points below used to be static `external 'CH341DLL.DLL'`
// imports, which Windows resolves at process start -- so a missing DLL kept
// the whole program from launching even for someone who never touches a
// CH341.  They are now procedure variables bound at startup: each one binds
// to the real export when CH341DLL.DLL is present, and to a fail-closed stub
// (False/-1/0/nil, like an unplugged device) when the DLL or that single
// export is absent.  Call sites are unchanged.
uses SysUtils;
const
     FILE_DEVICE_UNKNOWN = $22;
     FILE_ANY_ACCESS = 0;
     METHOD_BUFFERED = 0;
     mCH341_PACKET_LENGTH = 32;			// CH341支持的数据包的长度
     mCH341_PKT_LEN_SHORT = 8 ;			// CH341支持的短数据包的长度



// WIN32应用层接口命令
//     IOCTL_CH341_COMMAND		( FILE_DEVICE_UNKNOWN << 16 | FILE_ANY_ACCESS << 14 | 0x0f34 << 2 | METHOD_BUFFERED )	// 专用接口
//     mWIN32_COMMAND_HEAD		mOFFSET( mWIN32_COMMAND, mBuffer )	// WIN32命令接口的头长度
     mCH341_MAX_NUMBER =	16;			// 最多同时连接的CH341数
     mMAX_BUFFER_LENGTH	=$1000;		// 数据缓冲区最大长度4096
//     mMAX_COMMAND_LENGTH		( mWIN32_COMMAND_HEAD + mMAX_BUFFER_LENGTH )	// 最大数据长度加上命令结构头的长度
     mDEFAULT_BUFFER_LEN=$0400;		// 数据缓冲区默认长度1024
//     mDEFAULT_COMMAND_LEN	( mWIN32_COMMAND_HEAD + mDEFAULT_BUFFER_LEN )	// 默认数据长度加上命令结构头的长度

// CH341端点地址
     mCH341_ENDP_INTER_UP=$81 ;		// CH341的中断数据上传端点的地址
     mCH341_ENDP_INTER_DOWN=$01;		// CH341的中断数据下传端点的地址
     mCH341_ENDP_DATA_UP=$82  ;		// CH341的数据块上传端点的地址
     mCH341_ENDP_DATA_DOWN=$02 ;		// CH341的数据块下传端点的地址

// 设备层接口提供的管道操作命令
     mPipeDeviceCtrl=$00000004;	// CH341的综合控制管道
     mPipeInterUp=$00000005  ;	// CH341的中断数据上传管道
     mPipeDataUp =$00000006  ;	// CH341的数据块上传管道
     mPipeDataDown=$00000007 ;	// CH341的数据块下传管道

// 应用层接口的功能代码
     mFuncNoOperation=$00000000;	// 无操作
     mFuncGetVersion =$00000001;	// 获取驱动程序版本号
     mFuncGetConfig  =$00000002	;// 获取USB设备配置描述符
     mFuncSetTimeout =$00000009	;// 设置USB通讯超时
     mFuncSetExclusive=$0000000b;	// 设置独占使用
     mFuncResetDevice =$0000000c ;	// 复位USB设备
     mFuncResetPipe  	=$0000000d ;	// 复位USB管道
     mFuncAbortPipe			=$0000000e;	// 取消USB管道的数据请求


// CH341并口专用的功能代码
     mFuncSetParaMode		=$0000000f  ;	// 设置并口模式
     mFuncReadData0			=$00000010 ;	// 从并口读取数据块0
     mFuncReadData1			=$00000011 ;	// 从并口读取数据块1
     mFuncWriteData0			=$00000012 ;	// 向并口写入数据块0
     mFuncWriteData1			=$00000013  ;	// 向并口写入数据块1
     mFuncWriteRead			=$00000014  ;	// 先输出再输入


// USB设备标准请求代码
     mUSB_CLR_FEATURE		=$01;
     mUSB_SET_FEATURE		=$03 ;
     mUSB_GET_STATUS			=$00 ;
     mUSB_SET_ADDRESS		=$05      ;
     mUSB_GET_DESCR			=$06   ;
     mUSB_SET_DESCR			=$07   ;
     mUSB_GET_CONFIG			=$08   ;
     mUSB_SET_CONFIG			=$09    ;
     mUSB_GET_INTERF			=$0a    ;
     mUSB_SET_INTERF			=$0b    ;
     mUSB_SYNC_FRAME			=$0c    ;

// CH341控制传输的厂商专用请求类型
     mCH341_VENDOR_READ		=$C0	 ;	// 通过控制传输实现的CH341厂商专用读操作
     mCH341_VENDOR_WRITE		=$40 ;		// 通过控制传输实现的CH341厂商专用写操作

// CH341控制传输的厂商专用请求代码
     mCH341_PARA_INIT		=$B1	;	// 初始化并口
     mCH341_I2C_STATUS		=$52	;	// 获取I2C接口的状态
     mCH341_I2C_COMMAND		=$53	 ;	// 发出I2C接口的命令

// CH341并口操作命令代码
     mCH341_PARA_CMD_R0		=$AC ;		// 从并口读数据0
     mCH341_PARA_CMD_R1		=$AD  ;		// 从并口读数据1
     mCH341_PARA_CMD_W0		=$A6  ;		// 向并口写数据0
     mCH341_PARA_CMD_W1		=$A7  ;		// 向并口写数据1
     mCH341_PARA_CMD_STS		=$A0  ;		// 获取并口状态

// CH341A并口操作命令代码
     mCH341A_CMD_SET_OUTPUT	=$A1;		// 设置并口输出
     mCH341A_CMD_IO_ADDR		=$A2 ;		// MEM带地址读写/输入输出,从次字节开始为命令流
     mCH341A_CMD_SPI_STREAM	=$A8  ;		// SPI接口的命令包,从次字节开始为数据流
     mCH341A_CMD_SIO_STREAM	=$A9  ;		// SIO接口的命令包,从次字节开始为数据流
     mCH341A_CMD_I2C_STREAM	=$AA  ;		// I2C接口的命令包,从次字节开始为I2C命令流
     mCH341A_CMD_UIO_STREAM	=$AB  ;		// UIO接口的命令包,从次字节开始为命令流

// CH341A控制传输的厂商专用请求代码
     mCH341A_BUF_CLEAR		=$B2 ;		// 清除未完成的数据
     mCH341A_I2C_CMD_X		=$54  ;		// 发出I2C接口的命令,立即执行
     mCH341A_DELAY_MS		=$5E  ;		// 以亳秒为单位延时指定时间
     mCH341A_GET_VER			=$5F   ;		// 获取芯片版本

     mCH341_EPP_IO_MAX	 =	( mCH341_PACKET_LENGTH - 1 )  ;	// CH341在EPP/MEM方式下单次读写数据块的最大长度
     mCH341A_EPP_IO_MAX		=$FF  ;		// CH341A在EPP/MEM方式下单次读写数据块的最大长度

     mCH341A_CMD_IO_ADDR_W	=$00   ;		// MEM带地址读写/输入输出的命令流:写数据,位6-位0为地址,下一个字节为待写数据
     mCH341A_CMD_IO_ADDR_R	=$80   ;		// MEM带地址读写/输入输出的命令流:读数据,位6-位0为地址,读出数据一起返回

     mCH341A_CMD_I2C_STM_STA	=$74	;	// I2C接口的命令流:产生起始位
     mCH341A_CMD_I2C_STM_STO	=$75   ;		// I2C接口的命令流:产生停止位
     mCH341A_CMD_I2C_STM_OUT	=$80	;	// I2C接口的命令流:输出数据,位5-位0为长度,后续字节为数据,0长度则只发送一个字节并返回应答
     mCH341A_CMD_I2C_STM_IN	=$C0	;	// I2C接口的命令流:输入数据,位5-位0为长度,0长度则只接收一个字节并发送无应答
//     mCH341A_CMD_I2C_STM_MAX   =	( min( =$3F, mCH341_PACKET_LENGTH ) );	// I2C接口的命令流单个命令输入输出数据的最大长度
     mCH341A_CMD_I2C_STM_SET	=$60  ;		// I2C接口的命令流:设置参数,位2=SPI的I/O数(0=单入单出,1=双入双出),位1位0=I2C速度(00=低速,01=标准,10=快速,11=高速)
     mCH341A_CMD_I2C_STM_US	=$40	;	// I2C接口的命令流:以微秒为单位延时,位3-位0为延时值
     mCH341A_CMD_I2C_STM_MS	=$50 ;		// I2C接口的命令流:以亳秒为单位延时,位3-位0为延时值
     mCH341A_CMD_I2C_STM_DLY	=$0F  ;		// I2C接口的命令流单个命令延时的最大值
     mCH341A_CMD_I2C_STM_END	=$00  ;		// I2C接口的命令流:命令包提前结束

     mCH341A_CMD_UIO_STM_IN	=$00  ;		// UIO接口的命令流:输入数据D7-D0
     mCH341A_CMD_UIO_STM_DIR	=$40  ;		// UIO接口的命令流:设定I/O方向D5-D0,位5-位0为方向数据
     mCH341A_CMD_UIO_STM_OUT	=$80 ;		// UIO接口的命令流:输出数据D5-D0,位5-位0为数据
     mCH341A_CMD_UIO_STM_US	=$C0   ;		// UIO接口的命令流:以微秒为单位延时,位5-位0为延时值
     mCH341A_CMD_UIO_STM_END	=$20	;	// UIO接口的命令流:命令包提前结束


// CH341并口工作模式
     mCH341_PARA_MODE_EPP	=$00 ;		// CH341并口工作模式为EPP方式
     mCH341_PARA_MODE_EPP17	=$00 ;		// CH341A并口工作模式为EPP方式V1.7
     mCH341_PARA_MODE_EPP19	=$01 ;		// CH341A并口工作模式为EPP方式V1.9
     mCH341_PARA_MODE_MEM	=$02 ;		// CH341并口工作模式为MEM方式


// 直接输入的状态信号的位定义
     mStateBitERR			=$00000100 ;	// 只读,ERR#引脚输入状态,1:高电平,0:低电平
     mStateBitPEMP			=$00000200 ;	// 只读,PEMP引脚输入状态,1:高电平,0:低电平
     mStateBitINT			=$00000400 ;	// 只读,INT#引脚输入状态,1:高电平,0:低电平
     mStateBitSLCT			=$00000800 ;	// 只读,SLCT引脚输入状态,1:高电平,0:低电平
     mStateBitSDA			=$00800000 ;	// 只读,SDA引脚输入状态,1:高电平,0:低电平

type
  PVOID = Pointer;
  PULONG=pcardinal;

Type
        mUspValue=record
        mUspValueLow : Byte;
        mUspValueHigh : Byte;
End;
Type
        mUspIndex=record
        mUspIndexLow : Byte;
        mUspIndexHigh  : Byte;
End ;
Type
    USB_SETUP_PKT=record
    mUspReqType : Byte;
    mUspRequest : Byte;
    mUspValue : mUspValue;
    mUspIndex : mUspIndex;
    mLength : Integer;
End ;
Type
   WIN32_COMMAND=record               //定义WIN32命令接口结构
   mFunction : cardinal;              //输入时指定功能代码或者管道号
                                      //输出时返回操作状态
   mLength : cardinal;                //存取长度,返回后续数据的长度
   mBuffer:array[0..(mCH341_PACKET_LENGTH-1)] of Byte;         //数据缓冲区,长度为0至255B                                           '数据缓冲区,长度为0至255B
End ;

Type mPWIN32_COMMAND=^WIN32_COMMAND;

var
   mUSB_SETUP_PKT :USB_SETUP_PKT;
   mWIN32_COMMAND : WIN32_COMMAND;

type  mPCH341_INT_ROUTINE=Procedure (  // 中断服务程序
      iStatus:cardinal );stdcall;      // 中断状态数据,见下行
      // 位7-位0对应CH341的D7-D0引脚
      // 位8对应CH341的ERR#引脚, 位9对应CH341的PEMP引脚, 位10对应CH341的INT#引脚, 位11对应CH341的SLCT引脚

// EEPROM型号
type
   EEPROM_TYPE =(ID_24C01,ID_24C02,ID_24C04,ID_24C08,ID_24C16,ID_24C32,ID_24C64,ID_24C128,ID_24C256,ID_24C512,ID_24C1024,ID_24C2048,ID_24C4096);

type	 mPCH341_NOTIFY_ROUTINE =ProceDure (  // 设备事件通知回调程序
	 iEventStatus:cardinal);stdcall;  // 设备事件和当前状态(在下行定义): 0=设备拔出事件, 3=设备插入事件

const	CH341_DEVICE_ARRIVAL =		3 ;		// 设备插入事件,已经插入
	CH341_DEVICE_REMOVE_PEND =	1 ;		// 设备将要拔出
	CH341_DEVICE_REMOVE    =	0 ;		// 设备拔出事件,已经拔出

//True when CH341DLL.DLL loaded; False plus the reason otherwise.
function CH341DriverAvailable(out Error: string): boolean;

var
  CH341OpenDevice: function(iIndex: cardinal): integer; stdcall;
  CH341CloseDevice: procedure(iIndex: cardinal); stdcall;
  CH341GetVersion: function: cardinal; stdcall;
  CH341DriverCommand: function(iIndex: cardinal;
    ioCommand: mPWIN32_COMMAND): cardinal; stdcall;
  CH341GetDrvVersion: function: cardinal; stdcall;
  CH341ResetDevice: function(iIndex: cardinal): boolean; stdcall;
  CH341GetDeviceDescr: function(iIndex: cardinal; oBuffer: PVOID;
    ioLength: PULONG): boolean; stdcall;
  CH341GetConfigDescr: function(iIndex: cardinal; oBuffer: PVOID;
    ioLength: PULONG): boolean; stdcall;
  CH341SetIntRoutine: function(iIndex: cardinal;
    iIntRoutine: mPCH341_INT_ROUTINE): boolean; stdcall;
  CH341ReadInter: function(iIndex: cardinal;
    iStatus: PULONG): boolean; stdcall;
  CH341AbortInter: function(iIndex: cardinal): boolean; stdcall;
  CH341SetParaMode: function(iIndex: cardinal;
    iMode: cardinal): boolean; stdcall;
  CH341InitParallel: function(iIndex: cardinal;
    iMode: cardinal): boolean; stdcall;
  CH341ReadData0: function(iIndex: cardinal; oBuffer: PVOID;
    ioLength: PULONG): boolean; stdcall;
  CH341ReadData1: function(iIndex: cardinal; oBuffer: PVOID;
    ioLength: PULONG): boolean; stdcall;
  CH341AbortRead: function(iIndex: cardinal): boolean; stdcall;
  CH341WriteData0: function(iIndex: cardinal; iBuffer: PVOID;
    ioLength: PULONG): boolean; stdcall;
  CH341WriteData1: function(iIndex: cardinal; iBuffer: PVOID;
    ioLength: PULONG): boolean; stdcall;
  CH341AbortWrite: function(iIndex: cardinal): boolean; stdcall;
  CH341GetStatus: function(iIndex: cardinal;
    iStatus: PULONG): boolean; stdcall;
  CH341ReadI2C: function(iIndex: cardinal; iDevice: byte; iAddr: byte;
    oByte: Pbytearray): boolean; stdcall;
  CH341WriteI2C: function(iIndex: cardinal; iDevice: byte; iAddr: byte;
    iByte: byte): boolean; stdcall;
  CH341EppReadData: function(iIndex: cardinal; oBuffer: PVOID;
    ioLength: PULONG): boolean; stdcall;
  CH341EppReadAddr: function(iIndex: cardinal; oBuffer: PVOID;
    ioLength: PULONG): boolean; stdcall;
  CH341EppWriteData: function(iIndex: cardinal; iBuffer: PVOID;
    ioLength: PULONG): boolean; stdcall;
  CH341EppWriteAddr: function(iIndex: cardinal; iBuffer: PVOID;
    ioLength: PULONG): boolean; stdcall;
  CH341EppSetAddr: function(iIndex: cardinal; iAddr: byte): boolean; stdcall;
  CH341MemReadAddr0: function(iIndex: cardinal; oBuffer: PVOID;
    ioLength: PULONG): boolean; stdcall;
  CH341MemReadAddr1: function(iIndex: cardinal; oBuffer: PVOID;
    ioLength: PULONG): boolean; stdcall;
  CH341MemWriteAddr0: function(iIndex: cardinal; iBuffer: PVOID;
    ioLength: PULONG): boolean; stdcall;
  CH341MemWriteAddr1: function(iIndex: cardinal; iBuffer: PVOID;
    ioLength: PULONG): boolean; stdcall;
  CH341SetExclusive: function(iIndex: cardinal;
    iExclusive: cardinal): boolean; stdcall;
  CH341SetTimeout: function(iIndex: cardinal; iWriteTimeout: cardinal;
    iReadTimeout: cardinal): boolean; stdcall;
  CH341ReadData: function(iIndex: cardinal; oBuffer: PVOID;
    ioLength: PULONG): boolean; stdcall;
  CH341WriteData: function(iIndex: cardinal; iBuffer: PVOID;
    ioLength: PULONG): boolean; stdcall;
  CH341GetDeviceName: function(iIndex: cardinal): PVOID; stdcall;
  CH341GetVerIC: function(iIndex: cardinal): cardinal; stdcall;
  CH341FlushBuffer: function(iIndex: cardinal): boolean; stdcall;
  CH341WriteRead: function(iIndex: cardinal; iWriteLength: cardinal;
    iWriteBuffer: PVOID; iReadStep: cardinal; iReadTimes: cardinal;
    oReadLength: PULONG; oReadBuffer: PVOID): boolean; stdcall;
  CH341SetStream: function(iIndex: cardinal;
    iMode: cardinal): boolean; stdcall;
  CH341SetDelaymS: function(iIndex: cardinal;
    iDelay: cardinal): boolean; stdcall;
  CH341StreamI2C: function(iIndex: cardinal; iWriteLength: cardinal;
    iWriteBuffer: PVOID; iReadLength: cardinal;
    oReadBuffer: PVOID): boolean; stdcall;
  CH341ReadEEPROM: function(iIndex: cardinal; iEepromID: EEPROM_TYPE;
    iAddr: cardinal; iLength: cardinal;
    oBuffer: Pbytearray): boolean; stdcall;
  CH341WriteEEPROM: function(iIndex: cardinal; iEepromID: EEPROM_TYPE;
    iAddr: cardinal; iLength: cardinal;
    iBuffer: Pbytearray): boolean; stdcall;
  CH341GetInput: function(iIndex: cardinal;
    iStatus: PULONG): boolean; stdcall;
  CH341SetOutput: function(iIndex: cardinal; iEnable: cardinal;
    iSetDirOut: cardinal; iSetDataOut: cardinal): boolean; stdcall;
  CH341Set_D5_D0: function(iIndex: cardinal; iSetDirOut: cardinal;
    iSetDataOut: cardinal): boolean; stdcall;
  CH341StreamSPI3: function(iIndex: cardinal; iChipSelect: cardinal;
    iLength: cardinal; ioBuffer: PVOID): boolean; stdcall;
  CH341StreamSPI4: function(iIndex: cardinal; iChipSelect: cardinal;
    iLength: cardinal; ioBuffer: PVOID): boolean; stdcall;
  CH341StreamSPI5: function(iIndex: cardinal; iChipSelect: cardinal;
    iLength: cardinal; ioBuffer: PVOID;
    ioBuffer2: PVOID): boolean; stdcall;
  CH341BitStreamSPI: function(iIndex: cardinal; iLength: cardinal;
    ioBuffer: PVOID): boolean; stdcall;
  CH341SetBufUpload: function(iIndex: cardinal;
    iEnableOrClear: cardinal): boolean; stdcall;
  CH341QueryBufUpload: function(iIndex: cardinal): integer; stdcall;
  CH341SetBufDownload: function(iIndex: cardinal;
    iEnableOrClear: cardinal): boolean; stdcall;
  CH341QueryBufDownload: function(iIndex: cardinal): integer; stdcall;
  CH341ResetInter: function(iIndex: cardinal): boolean; stdcall;
  CH341ResetRead: function(iIndex: cardinal): boolean; stdcall;
  CH341ResetWrite: function(iIndex: cardinal): boolean; stdcall;
  CH341SetDeviceNotify: function(iIndex: cardinal; iDeviceID: PCHAR;
    iNotifyRoutine: mPCH341_NOTIFY_ROUTINE): boolean; stdcall;
  CH341SetupSerial: function(iIndex: cardinal; iParityMode: cardinal;
    iBaudRate: cardinal): boolean; stdcall;

implementation

{$IFDEF WINDOWS}
uses Windows;
{$ENDIF}

var
  Lib: THandle = 0;
  LoadError: string = '';

// Fail-closed stubs, one per signature shape.  They behave exactly like an
// unplugged programmer: opens fail, queries return nothing, commands report
// failure.  No caller can dereference a nil entry point.

function Stub_IdxToInt(iIndex: cardinal): integer; stdcall;
begin Result := -1; end;

procedure Stub_IdxProc(iIndex: cardinal); stdcall;
begin end;

function Stub_ToCard: cardinal; stdcall;
begin Result := 0; end;

function Stub_CmdToCard(iIndex: cardinal;
  ioCommand: mPWIN32_COMMAND): cardinal; stdcall;
begin Result := 0; end;

function Stub_IdxToBool(iIndex: cardinal): boolean; stdcall;
begin Result := False; end;

function Stub_IdxToCard(iIndex: cardinal): cardinal; stdcall;
begin Result := 0; end;

function Stub_IdxToPtr(iIndex: cardinal): PVOID; stdcall;
begin Result := nil; end;

function Stub_BufLen(iIndex: cardinal; oBuffer: PVOID;
  ioLength: PULONG): boolean; stdcall;
begin Result := False; end;

function Stub_Status(iIndex: cardinal; iStatus: PULONG): boolean; stdcall;
begin Result := False; end;

function Stub_Card(iIndex: cardinal; iValue: cardinal): boolean; stdcall;
begin Result := False; end;

function Stub_CardCard(iIndex: cardinal; iA: cardinal;
  iB: cardinal): boolean; stdcall;
begin Result := False; end;

function Stub_CardCardCard(iIndex: cardinal; iA: cardinal; iB: cardinal;
  iC: cardinal): boolean; stdcall;
begin Result := False; end;

function Stub_IntRoutine(iIndex: cardinal;
  iIntRoutine: mPCH341_INT_ROUTINE): boolean; stdcall;
begin Result := False; end;

function Stub_ReadI2C(iIndex: cardinal; iDevice: byte; iAddr: byte;
  oByte: Pbytearray): boolean; stdcall;
begin Result := False; end;

function Stub_WriteI2C(iIndex: cardinal; iDevice: byte; iAddr: byte;
  iByte: byte): boolean; stdcall;
begin Result := False; end;

function Stub_EppSetAddr(iIndex: cardinal; iAddr: byte): boolean; stdcall;
begin Result := False; end;

function Stub_WriteRead(iIndex: cardinal; iWriteLength: cardinal;
  iWriteBuffer: PVOID; iReadStep: cardinal; iReadTimes: cardinal;
  oReadLength: PULONG; oReadBuffer: PVOID): boolean; stdcall;
begin Result := False; end;

function Stub_StreamI2C(iIndex: cardinal; iWriteLength: cardinal;
  iWriteBuffer: PVOID; iReadLength: cardinal;
  oReadBuffer: PVOID): boolean; stdcall;
begin Result := False; end;

function Stub_EEPROM(iIndex: cardinal; iEepromID: EEPROM_TYPE;
  iAddr: cardinal; iLength: cardinal; oBuffer: Pbytearray): boolean; stdcall;
begin Result := False; end;

function Stub_StreamSPI(iIndex: cardinal; iChipSelect: cardinal;
  iLength: cardinal; ioBuffer: PVOID): boolean; stdcall;
begin Result := False; end;

function Stub_StreamSPI5(iIndex: cardinal; iChipSelect: cardinal;
  iLength: cardinal; ioBuffer: PVOID; ioBuffer2: PVOID): boolean; stdcall;
begin Result := False; end;

function Stub_BitStream(iIndex: cardinal; iLength: cardinal;
  ioBuffer: PVOID): boolean; stdcall;
begin Result := False; end;

function Stub_SetOutput(iIndex: cardinal; iEnable: cardinal;
  iSetDirOut: cardinal; iSetDataOut: cardinal): boolean; stdcall;
begin Result := False; end;

function Stub_Notify(iIndex: cardinal; iDeviceID: PCHAR;
  iNotifyRoutine: mPCH341_NOTIFY_ROUTINE): boolean; stdcall;
begin Result := False; end;

function CH341DriverAvailable(out Error: string): boolean;
begin
  Result := Lib <> 0;
  if Result then Error := '' else Error := LoadError;
end;

//ผูกชื่อเข้ากับ export จริงเมื่อมี ไม่มีก็ใช้ stub ที่ล้มเหลวแบบปิดสนิท
//ผูกทีละตัว ไม่ใช่ทั้งหมดหรือไม่เอาเลย เพราะ DLL แต่ละรุ่นมี export ไม่เท่ากัน
procedure Bind(var P; Stub: Pointer; Name: PAnsiChar);
begin
  Pointer(P) := nil;
  {$IFDEF WINDOWS}
  if Lib <> 0 then Pointer(P) := GetProcAddress(Lib, Name);
  {$ENDIF}
  if Pointer(P) = nil then Pointer(P) := Stub;
end;

procedure BindAll;
begin
  Bind(CH341OpenDevice, @Stub_IdxToInt, 'CH341OpenDevice');
  Bind(CH341CloseDevice, @Stub_IdxProc, 'CH341CloseDevice');
  Bind(CH341GetVersion, @Stub_ToCard, 'CH341GetVersion');
  Bind(CH341DriverCommand, @Stub_CmdToCard, 'CH341DriverCommand');
  Bind(CH341GetDrvVersion, @Stub_ToCard, 'CH341GetDrvVersion');
  Bind(CH341ResetDevice, @Stub_IdxToBool, 'CH341ResetDevice');
  Bind(CH341GetDeviceDescr, @Stub_BufLen, 'CH341GetDeviceDescr');
  Bind(CH341GetConfigDescr, @Stub_BufLen, 'CH341GetConfigDescr');
  Bind(CH341SetIntRoutine, @Stub_IntRoutine, 'CH341SetIntRoutine');
  Bind(CH341ReadInter, @Stub_Status, 'CH341ReadInter');
  Bind(CH341AbortInter, @Stub_IdxToBool, 'CH341AbortInter');
  Bind(CH341SetParaMode, @Stub_Card, 'CH341SetParaMode');
  Bind(CH341InitParallel, @Stub_Card, 'CH341InitParallel');
  Bind(CH341ReadData0, @Stub_BufLen, 'CH341ReadData0');
  Bind(CH341ReadData1, @Stub_BufLen, 'CH341ReadData1');
  Bind(CH341AbortRead, @Stub_IdxToBool, 'CH341AbortRead');
  Bind(CH341WriteData0, @Stub_BufLen, 'CH341WriteData0');
  Bind(CH341WriteData1, @Stub_BufLen, 'CH341WriteData1');
  Bind(CH341AbortWrite, @Stub_IdxToBool, 'CH341AbortWrite');
  Bind(CH341GetStatus, @Stub_Status, 'CH341GetStatus');
  Bind(CH341ReadI2C, @Stub_ReadI2C, 'CH341ReadI2C');
  Bind(CH341WriteI2C, @Stub_WriteI2C, 'CH341WriteI2C');
  Bind(CH341EppReadData, @Stub_BufLen, 'CH341EppReadData');
  Bind(CH341EppReadAddr, @Stub_BufLen, 'CH341EppReadAddr');
  Bind(CH341EppWriteData, @Stub_BufLen, 'CH341EppWriteData');
  Bind(CH341EppWriteAddr, @Stub_BufLen, 'CH341EppWriteAddr');
  Bind(CH341EppSetAddr, @Stub_EppSetAddr, 'CH341EppSetAddr');
  Bind(CH341MemReadAddr0, @Stub_BufLen, 'CH341MemReadAddr0');
  Bind(CH341MemReadAddr1, @Stub_BufLen, 'CH341MemReadAddr1');
  Bind(CH341MemWriteAddr0, @Stub_BufLen, 'CH341MemWriteAddr0');
  Bind(CH341MemWriteAddr1, @Stub_BufLen, 'CH341MemWriteAddr1');
  Bind(CH341SetExclusive, @Stub_Card, 'CH341SetExclusive');
  Bind(CH341SetTimeout, @Stub_CardCard, 'CH341SetTimeout');
  Bind(CH341ReadData, @Stub_BufLen, 'CH341ReadData');
  Bind(CH341WriteData, @Stub_BufLen, 'CH341WriteData');
  Bind(CH341GetDeviceName, @Stub_IdxToPtr, 'CH341GetDeviceName');
  Bind(CH341GetVerIC, @Stub_IdxToCard, 'CH341GetVerIC');
  Bind(CH341FlushBuffer, @Stub_IdxToBool, 'CH341FlushBuffer');
  Bind(CH341WriteRead, @Stub_WriteRead, 'CH341WriteRead');
  Bind(CH341SetStream, @Stub_Card, 'CH341SetStream');
  Bind(CH341SetDelaymS, @Stub_Card, 'CH341SetDelaymS');
  Bind(CH341StreamI2C, @Stub_StreamI2C, 'CH341StreamI2C');
  Bind(CH341ReadEEPROM, @Stub_EEPROM, 'CH341ReadEEPROM');
  Bind(CH341WriteEEPROM, @Stub_EEPROM, 'CH341WriteEEPROM');
  Bind(CH341GetInput, @Stub_Status, 'CH341GetInput');
  Bind(CH341SetOutput, @Stub_SetOutput, 'CH341SetOutput');
  Bind(CH341Set_D5_D0, @Stub_CardCard, 'CH341Set_D5_D0');
  Bind(CH341StreamSPI3, @Stub_StreamSPI, 'CH341StreamSPI3');
  Bind(CH341StreamSPI4, @Stub_StreamSPI, 'CH341StreamSPI4');
  Bind(CH341StreamSPI5, @Stub_StreamSPI5, 'CH341StreamSPI5');
  Bind(CH341BitStreamSPI, @Stub_BitStream, 'CH341BitStreamSPI');
  Bind(CH341SetBufUpload, @Stub_Card, 'CH341SetBufUpload');
  Bind(CH341QueryBufUpload, @Stub_IdxToInt, 'CH341QueryBufUpload');
  Bind(CH341SetBufDownload, @Stub_Card, 'CH341SetBufDownload');
  Bind(CH341QueryBufDownload, @Stub_IdxToInt, 'CH341QueryBufDownload');
  Bind(CH341ResetInter, @Stub_IdxToBool, 'CH341ResetInter');
  Bind(CH341ResetRead, @Stub_IdxToBool, 'CH341ResetRead');
  Bind(CH341ResetWrite, @Stub_IdxToBool, 'CH341ResetWrite');
  Bind(CH341SetDeviceNotify, @Stub_Notify, 'CH341SetDeviceNotify');
  Bind(CH341SetupSerial, @Stub_CardCardCard, 'CH341SetupSerial');
end;

initialization
  {$IFDEF WINDOWS}
  Lib := LoadLibrary('CH341DLL.DLL');
  if Lib = 0 then
    LoadError := 'CH341DLL.DLL was not found next to the program';
  {$ELSE}
  LoadError := 'the CH341 vendor driver is only available on Windows';
  {$ENDIF}
  BindAll;

finalization
  {$IFDEF WINDOWS}
  if Lib <> 0 then FreeLibrary(Lib);
  {$ENDIF}

end.
