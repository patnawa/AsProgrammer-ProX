unit buzzpirathw;

// By Dreg, Based from arduinohw

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, basehw, msgstr, utilfunc, Dialogs;

type
  TBhlClearLog           = function:integer; stdcall;
  TBhlResetOnce          = function(setf: integer): integer; stdcall;

  TBhlI2CInit            = function(dbglvl: integer; com_name: pchar; power: integer; pullups: integer; khz: integer; just_i2c_scanner: integer): integer; stdcall;
  TBhlI2CClose           = function:integer; stdcall;
  TBhlI2CGetMemaux       = function:pbyte; stdcall;
  TBhlI2CReadWrite       = function(devaddr: integer; bufflen: integer; buffer: PByteArray; length: integer): integer; stdcall;
  TBhlI2CStart           = function:integer; stdcall;
  TBhlI2CStop            = function:integer; stdcall;
  TBhlI2CReadByte        = function:integer; stdcall;
  TBhlI2CWriteByte       = function(byte_val: integer): integer; stdcall;

  TBhlSPIInit            = function(dbglvl: integer; com_name: pchar; spibug: integer; power: integer; pullups: integer; khz: integer; set_smphase_end: integer; set_cke_act_to_idle: integer; set_ckp_idle_high: integer; set_out_3v3: integer; set_cs_active_high: integer) : integer; stdcall;
  TBhlSPIClose           = function:integer; stdcall;
  TBhlSPIReadWriteNoCs   = function(size: integer; bufferw: PByteArray; size_wbuffer: integer): integer; stdcall;
  TBhlSPICsLow           = function: integer; stdcall;
  TBhlSPICsHigh          = function: integer; stdcall;
  TBhlSPIGetMemaux   = function:pbyte; stdcall;
{ TBuzzpiratHardware }

TBuzzpiratHardware = class(TBaseHardware)
private
  FDevOpened: boolean;
  FStrError: string;

  BhlClearLog: TBhlClearLog;
  BhlResetOnce: TBhlResetOnce;

  BhlI2CInit: TBhlI2CInit;
  BhlI2CClose: TBhlI2CClose;
  BhlI2CGetMemaux: TBhlI2CGetMemaux;
  BhlI2CReadWrite: TBhlI2CReadWrite;
  BhlI2CStart: TBhlI2CStart;
  BhlI2CStop: TBhlI2CStop;
  BhlI2CReadByte: TBhlI2CReadByte;
  BhlI2CWriteByte: TBhlI2CWriteByte;

  BhlSPIInit: TBhlSPIInit;
  BhlSPIClose: TBhlSPIClose;
  BhlSPIReadWriteNoCs: TBhlSPIReadWriteNoCs;
  BhlSPICsLow: TBhlSPICsLow;
  BhlSPICsHigh: TBhlSPICsHigh;
  BhlSPIGetMemaux: TBhlSPIGetMemaux;

public
  constructor Create;
  destructor Destroy; override;

  function GetLastError: string; override;
  function DevOpen: boolean; override;
  procedure DevClose; override;

  //spi
  function SPIRead(CS: byte; BufferLen: integer; var buffer: array of byte): integer; override;
  function SPIWrite(CS: byte; BufferLen: integer; buffer: array of byte): integer; override;
  function SPIWriteRead(CS: byte; WBufferLen: integer; WBuffer: array of byte; RBufferLen: integer; var RBuffer: array of byte): integer; override;
  function SPIInit(speed: integer): boolean; override;
  procedure SPIDeinit; override;

  //I2C
  procedure I2CInit; override;
  procedure I2CDeinit; override;
  function I2CReadWrite(DevAddr: byte;
                        WBufferLen: integer; WBuffer: array of byte;
                        RBufferLen: integer; var RBuffer: array of byte): integer; override;
  procedure I2CStart; override;
  procedure I2CStop; override;
  function I2CReadByte(ack: boolean): byte; override;
  function I2CWriteByte(data: byte): boolean; override; //return ack

  //MICROWIRE
  function MWInit(speed: integer): boolean; override;
  procedure MWDeinit; override;
  function MWRead(CS: byte; BufferLen: integer; var buffer: array of byte): integer; override;
  function MWWrite(CS: byte; BitsWrite: byte; buffer: array of byte): integer; override;
  function MWIsBusy: boolean; override;
end;

implementation

uses main;

constructor TBuzzpiratHardware.Create;
begin
  FHardwareName := 'Buzzpirat / Buspirate';
  FHardwareID := CHW_BUZZPIRAT;
end;

destructor TBuzzpiratHardware.Destroy;
begin
  DevClose;
end;

function TBuzzpiratHardware.GetLastError: string;
begin
    result := FStrError;
end;

function TBuzzpiratHardware.DevOpen: boolean;
var Handle: THandle;
  khz: integer;
  pullups: integer;
  spibug: integer;
  power: integer;
  dbglvl: integer;
  just_i2c_scanner: integer;
  memaux: pbyte;
  i2c_info: string;
  len: integer;
  FCOMPort: string;
  set_smphase_end: integer;
  set_cke_act_to_idle: integer;
  set_ckp_idle_high: integer;
  set_out_3v3: integer;
  set_cs_active_high: integer;
begin
  if FDevOpened then DevClose;

  FDevOpened := false;

  FCOMPort := main.Buzzpirat_COMPort;

  if FCOMPort = '' then
  begin
    FStrError:= 'No port selected!';
    Exit(false);
  end;

  Handle := LoadLibrary('buzzpirathlp.dll');
  if Handle <> 0 then
  begin
    BhlClearLog          := TBhlClearLog(GetProcAddress(Handle, 'bhl_asprog_clear_log'));
    BhlResetOnce         := TBhlResetOnce(GetProcAddress(Handle, 'bhl_asprog_reset_once'));

    BhlI2CInit           := TBhlI2CInit(GetProcAddress(Handle, 'bhl_asprog_i2c_init'));
    BhlI2CClose          := TBhlI2CClose(GetProcAddress(Handle, 'bhl_asprog_i2c_close'));
    BhlI2CGetMemaux      := TBhlI2CGetMemaux(GetProcAddress(Handle, 'bhl_asprog_i2c_get_memaux'));
    BhlI2CReadWrite      := TBhlI2CReadWrite(GetProcAddress(Handle, 'bhl_asprog_i2c_readwrite'));
    BhlI2CStart          := TBhlI2CStart(GetProcAddress(Handle, 'bhl_asprog_i2c_start'));
    BhlI2CStop           := TBhlI2CStop(GetProcAddress(Handle, 'bhl_asprog_i2c_stop'));
    BhlI2CReadByte       := TBhlI2CReadByte(GetProcAddress(Handle, 'bhl_asprog_i2c_read_byte'));
    BhlI2CWriteByte      := TBhlI2CWriteByte(GetProcAddress(Handle, 'bhl_asprog_i2c_write_byte'));

    BhlSPIInit           := TBhlSPIInit(GetProcAddress(Handle, 'bhl_asprog_spi_init'));
    BhlSPIClose          := TBhlSPIClose(GetProcAddress(Handle, 'bhl_asprog_spi_close'));
    BhlSPIReadWriteNoCs  := TBhlSPIReadWriteNoCs(GetProcAddress(Handle, 'bhl_asprog_spi_readwrite_no_cs'));
    BhlSPICsLow          := TBhlSPICsLow(GetProcAddress(Handle, 'bhl_asprog_spi_cs_low'));
    BhlSPICsHigh         := TBhlSPICsHigh(GetProcAddress(Handle, 'bhl_asprog_spi_cs_high'));
    BhlSPIGetMemaux      := TBhlSPIGetMemaux(GetProcAddress(Handle, 'bhl_asprog_spi_get_memaux'));
    if (BhlI2CInit = nil) or (BhlI2CClose = nil) or (BhlI2CGetMemaux = nil) or
    (BhlI2CReadWrite = nil) or (BhlI2CStart = nil) or (BhlI2CStop = nil) or
    (BhlI2CReadByte = nil) or (BhlI2CWriteByte = nil) or (BhlSPIInit = nil) or
    (BhlSPIClose = nil) or  (BhlSPIReadWriteNoCs = nil) or  (BhlSPICsLow = nil) or
    (BhlSPICsHigh = nil) or (BhlSPIGetMemaux = nil) or (BhlClearLog = nil) or
    (BhlResetOnce = nil) then
    begin
       FStrError:= 'buzzpirathlp.dll bad symbols';
       Exit(false);
    end;
  end
  else
  begin
       FStrError:= 'buzzpirathlp.dll not found';
       Exit(false);
  end;

  if MainForm.ClearBuzzlogMenuItem.Checked then  BhlClearLog();

  if MainForm.MenuBuzzpiratResetEach.Checked then
  begin
       BhlResetOnce(0);
  end
  else
  begin
      BhlResetOnce(1);
  end;

  pullups := 0;
  power := 0;
  spibug := 0;
  dbglvl := 0;

  if MainForm.MenuBuzzpiratLessdbg.Checked then
  begin
    LogPrint('dbglvl 1');
    dbglvl := 1;
  end;

  if MainForm.MenuBuzzpiratSPIBUG.Checked then
  begin
       LogPrint('SPIBUG FIX ON');
       spibug := 1;
  end;

  if MainForm.MenuBuzzpiratPower.Checked then
  begin
       LogPrint('Power ON');
       power := 1;
  end;

  if MainForm.MenuBuzzpiratPullups.Checked then
  begin
       LogPrint('Pull-ups ON');
       pullups := 1;
  end;

  khz := 0;

  if MainForm.RadioI2C.Checked then
  begin
    just_i2c_scanner := 0;

    if MainForm.MenuBuzzpiratI2C5KHz.Checked then
    begin
         LogPrint('5khz');
         khz := 5;
    end
    else if MainForm.MenuBuzzpiratI2C50KHz.Checked then
    begin
         LogPrint('50khz');
         khz := 50;
    end
    else if MainForm.MenuBuzzpiratI2C100KHz.Checked then
    begin
         LogPrint('100khz');
         khz := 100;
    end
    else if MainForm.MenuBuzzpiratI2C400KHz.Checked then
    begin
         LogPrint('400khz (not recommended)');
         khz := 400;
    end;

    if MainForm.MenuBuzzpiratJustI2CScan.Checked then
    begin
         LogPrint('JUST I2C SCANNER');
         just_i2c_scanner := 1;
    end;

    LogPrint('keep pressing ESC key to cancel... keep pressing F1 to relaunch this console... ASProgrammer GUI will be unresponsive while BUS PIRATE is operating. BUS PIRATE is slow, please be (very) patient. If bus pirate console freezes(~2 mins without output)/crash : close this program, reconnect USB port and try again.');

    if BhlI2CInit(dbglvl, PChar(FCOMPort), power, pullups, khz, just_i2c_scanner) <> 1 then
    begin
      LogPrint('I2C Init fail');
      Exit(false);
    end;

    if just_i2c_scanner = 1 then
    begin
      memaux := BhlI2CGetMemaux();

      len := 0;
      while memaux[len] <> 0 do
          Inc(len);
      SetString(i2c_info, PChar(memaux), len);
      ShowMessage(i2c_info);
      LogPrint(i2c_info);
      if MainForm.MenuBuzzpiratResetEach.Checked then BhlI2CClose();
      Exit(false);
    end;

    FDevOpened := true;
    Exit(true);
  end;

  if MainForm.RadioSPI.Checked then
  begin
    set_smphase_end := 0;
    set_cke_act_to_idle := 0;
    set_ckp_idle_high := 0;
    set_out_3v3 := 0;
    set_cs_active_high := 0;

    if MainForm.MenuBuzzpiratSPI30KHz.Checked then
    begin
         LogPrint('30khz');
         khz := 30;
    end
    else if MainForm.MenuBuzzpiratSPI125KHz.Checked then
    begin
         LogPrint('125khz');
         khz := 125;
    end
    else if MainForm.MenuBuzzpiratSPI250KHz.Checked then
    begin
         LogPrint('250khz');
         khz := 250;
    end
    else if MainForm.MenuBuzzpiratSPI1MHz.Checked then
    begin
         LogPrint('1mhz (not recommended)');
         khz := 1;
    end
    else if MainForm.MenuBuzzpiratSPI2MHz.Checked then
    begin
         LogPrint('2mhz (not recommended)');
         khz := 2;
    end
    else if MainForm.MenuBuzzpiratSPI2P6MHz.Checked then
    begin
         LogPrint('2.6mhz (not recommended)');
         khz := 26;
    end
    else if MainForm.MenuBuzzpiratSPI4MHz.Checked then
    begin
         LogPrint('4mhz (not recommended)');
         khz := 4;
    end
    else if MainForm.MenuBuzzpiratSPI8MHz.Checked then
    begin
         LogPrint('8mhz (not recommended)');
         khz := 8;
    end;

    if MainForm.MenuBuzzpiratSPINormal.Checked then
    begin
         LogPrint('out 3v3');
         set_out_3v3 := 1;
    end
    else
    begin
      LogPrint('out Open Drain(HiZ)');
    end;

    if BhlSPIInit(dbglvl, PChar(FCOMPort), spibug, power, pullups, khz, set_smphase_end, set_cke_act_to_idle, set_ckp_idle_high, set_out_3v3, set_cs_active_high) <> 1 then
    begin
      LogPrint('SPI Init fail');
      Exit(false);
    end;

    FDevOpened := true;
    Exit(true);
  end;

  LogPrint('Not Implemented Yet');
  Exit(false);
end;

procedure TBuzzpiratHardware.DevClose;
begin
  if FDevOpened then
  begin
    if MainForm.MenuBuzzpiratResetEach.Checked then
    begin
         BhlI2CClose();
         BhlSPIClose();
    end;
  end;

  FDevOpened := false;
end;


//SPI___________________________________________________________________________

function TBuzzpiratHardware.SPIInit(speed: integer): boolean;
begin
  if not FDevOpened then Exit(false);
end;

procedure TBuzzpiratHardware.SPIDeinit;
begin
  if not FDevOpened then Exit;
end;

function TBuzzpiratHardware.SPIWriteRead(CS: byte; WBufferLen: integer; WBuffer: array of byte; RBufferLen: integer; var RBuffer: array of byte): integer;
var
  sMessage: pbyte;
  i: Integer;
begin
  if not FDevOpened then Exit(-1);

  if RBufferLen > 0 then FillChar(RBuffer, RBufferLen - 1, 105);

  BhlSPICsLow();
  if BhlSPIReadWriteNoCs(RBufferLen, @WBuffer[0], WBufferLen) <> 1 then
    begin
         BhlSPICsHigh();
         LogPrint('Error SPIRead BhlSPIReadWriteNoCs');
         Exit(-1);
    end;
  BhlSPICsHigh();

  sMessage := BhlSPIGetMemaux();

  for i := 0 to RBufferLen - 1 do
     RBuffer[i] := sMessage[i];
  result := RBufferLen;
end;

function TBuzzpiratHardware.SPIRead(CS: byte; BufferLen: integer; var buffer: array of byte): integer;
var
  sMessage: pbyte;
  i: Integer;
begin
  if not FDevOpened then Exit(-1);

  if BufferLen > 0 then FillChar(buffer, BufferLen - 1, 105);

  if (CS = 1) then
  begin
    BhlSPICsLow();
    if BhlSPIReadWriteNoCs(BufferLen, nil, 0) <> 1 then
    begin
         BhlSPICsHigh();
         LogPrint('Error SPIRead BhlSPIReadWriteNoCs (CS:1)');
         Exit(-1);
    end;
    BhlSPICsHigh();
  end
  else
  begin
      BhlSPICsLow();
      if BhlSPIReadWriteNoCs(BufferLen, nil, 0) <> 1 then
      begin
         BhlSPICsHigh();
         LogPrint('Error SPIRead BhlSPIReadWriteNoCs (CS:0)');
         Exit(-1);
      end;
  end;

  sMessage := BhlSPIGetMemaux();

  for i := 0 to BufferLen - 1 do
    buffer[i] := sMessage[i];
  result := BufferLen;
end;

function TBuzzpiratHardware.SPIWrite(CS: byte; BufferLen: integer; buffer: array of byte): integer;
begin
  if not FDevOpened then Exit(-1);

  if (CS = 1) then
  begin
    BhlSPICsLow();
    if BhlSPIReadWriteNoCs(0, @buffer[0], BufferLen) <> 1 then
    begin
         BhlSPICsHigh();
         LogPrint('Error SPIRead BhlSPIReadWriteNoCs (CS:1)');
         Exit(-1);
    end;
    BhlSPICsHigh();
  end
  else
  begin
      BhlSPICsLow();
      if BhlSPIReadWriteNoCs(0, @buffer[0], BufferLen) <> 1 then
      begin
         BhlSPICsHigh();
         LogPrint('Error SPIRead BhlSPIReadWriteNoCs (CS:0)');
         Exit(-1);
      end;
  end;

  result := BufferLen;
end;

//i2c___________________________________________________________________________

procedure TBuzzpiratHardware.I2CInit;
begin
  if not FDevOpened then Exit;
end;

procedure TBuzzpiratHardware.I2CDeinit;
begin
  if not FDevOpened then Exit;
end;

function TBuzzpiratHardware.I2CReadWrite(DevAddr: byte;
                        WBufferLen: integer; WBuffer: array of byte;
                        RBufferLen: integer; var RBuffer: array of byte): integer;
var
  sMessage: pbyte;
  i: Integer;
begin
  if not FDevOpened then Exit(-1);

  if RBufferLen > 0 then FillChar(RBuffer, RBufferLen - 1, 105);

  if BhlI2CReadWrite(DevAddr, RBufferLen, @WBuffer[0], WBufferLen) <> 1 then
  begin
    LogPrint('Error BhlI2CReadWrite');
    Exit(-1);
  end;

  sMessage := BhlI2CGetMemaux();

  for i := 0 to RBufferLen - 1 do
    RBuffer[i] := sMessage[i];
  result := RBufferLen + WBufferLen;
end;

procedure TBuzzpiratHardware.I2CStart;
begin
  if not FDevOpened then Exit;

  if BhlI2CStart() <> 1 then
  begin
    LogPrint('Error BhlI2CStart');
    Exit;
  end;
end;

procedure TBuzzpiratHardware.I2CStop;
begin
  if not FDevOpened then Exit;

  if BhlI2CStop() <> 1 then
  begin
    LogPrint('Error BhlI2CStop');
    Exit;
  end;
end;

function TBuzzpiratHardware.I2CReadByte(ack: boolean): byte;
var
  Status: byte;
begin
  if not FDevOpened then Exit;

  if BhlI2CReadByte() <> 1 then
  begin
    LogPrint('Error BhlI2CReadByte');
    Exit(0);
  end;

  result := BhlI2CGetmemaux()[0];
end;

function TBuzzpiratHardware.I2CWriteByte(data: byte): boolean;
var
  Status: byte;
begin
  if not FDevOpened then Exit;

  if BhlI2CWriteByte(data) <> 1 then
    begin
      LogPrint('Error BhlI2CWriteByte');
      Exit(false);
    end;

  Exit(true);
end;

//MICROWIRE_____________________________________________________________________

function TBuzzpiratHardware.MWInit(speed: integer): boolean;
var buff: byte;
begin
  if not FDevOpened then Exit(false);

  LogPrint('Not Implemented Yet');
  Exit(false);
end;

procedure TBuzzpiratHardware.MWDeInit;
var buff: byte;
begin
  if not FDevOpened then Exit;

  LogPrint('Not Implemented Yet');
  Exit;
end;

function TBuzzpiratHardware.MWRead(CS: byte; BufferLen: integer; var buffer: array of byte): integer;
var buff:  byte;
    bytes: integer;
const chunk = 64;
begin
  if not FDevOpened then Exit(-1);

  LogPrint('Not Implemented Yet');
  Exit(-1);
end;

function TBuzzpiratHardware.MWWrite(CS: byte; BitsWrite: byte; buffer: array of byte): integer;
var buff: byte;
    bytes: byte;
const chunk = 32;
begin
  if not FDevOpened then Exit(-1);

  LogPrint('Not Implemented Yet');
  Exit(-1);
end;

function TBuzzpiratHardware.MWIsBusy: boolean;
var
  buff: byte;
begin
  LogPrint('Not Implemented Yet');
  Exit(false);
end;




end.

