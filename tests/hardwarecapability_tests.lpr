program hardwarecapability_tests;

{$mode objfpc}{$H+}

uses
  SysUtils, basehw;

type
  TDummyHardware = class(TBaseHardware)
  public
    constructor Create(ID: THardwareList);
    function GetLastError: string; override;
    function DevOpen: boolean; override;
    procedure DevClose; override;
    function SPIInit(speed: integer): boolean; override;
    procedure SPIDeinit; override;
    function SPIRead(CS: byte; BufferLen: integer;
      var buffer: array of byte): integer; override;
    function SPIWrite(CS: byte; BufferLen: integer;
      buffer: array of byte): integer; override;
    procedure I2CInit; override;
    procedure I2CDeinit; override;
    function I2CReadWrite(DevAddr: byte; WBufferLen: integer;
      WBuffer: array of byte; RBufferLen: integer;
      var RBuffer: array of byte): integer; override;
    procedure I2CStart; override;
    procedure I2CStop; override;
    function I2CReadByte(ack: boolean): byte; override;
    function I2CWriteByte(data: byte): boolean; override;
    function MWInit(speed: integer): boolean; override;
    procedure MWDeinit; override;
    function MWRead(CS: byte; BufferLen: integer;
      var buffer: array of byte): integer; override;
    function MWWrite(CS: byte; BitsWrite: byte;
      buffer: array of byte): integer; override;
    function MWIsBusy: boolean; override;
  end;

var
  Failures, Assertions: integer;

procedure Check(const Name: string; Condition: boolean);
begin
  Inc(Assertions);
  if not Condition then
  begin
    Inc(Failures);
    WriteLn('FAIL: ', Name);
  end;
end;

constructor TDummyHardware.Create(ID: THardwareList);
begin
  inherited Create;
  FHardwareID := ID;
end;

function TDummyHardware.GetLastError: string; begin Result := ''; end;
function TDummyHardware.DevOpen: boolean; begin Result := True; end;
procedure TDummyHardware.DevClose; begin end;
function TDummyHardware.SPIInit(speed: integer): boolean; begin Result := True; end;
procedure TDummyHardware.SPIDeinit; begin end;
function TDummyHardware.SPIRead(CS: byte; BufferLen: integer;
  var buffer: array of byte): integer; begin Result := BufferLen; end;
function TDummyHardware.SPIWrite(CS: byte; BufferLen: integer;
  buffer: array of byte): integer; begin Result := BufferLen; end;
procedure TDummyHardware.I2CInit; begin end;
procedure TDummyHardware.I2CDeinit; begin end;
function TDummyHardware.I2CReadWrite(DevAddr: byte; WBufferLen: integer;
  WBuffer: array of byte; RBufferLen: integer;
  var RBuffer: array of byte): integer; begin Result := RBufferLen; end;
procedure TDummyHardware.I2CStart; begin end;
procedure TDummyHardware.I2CStop; begin end;
function TDummyHardware.I2CReadByte(ack: boolean): byte; begin Result := $FF; end;
function TDummyHardware.I2CWriteByte(data: byte): boolean; begin Result := True; end;
function TDummyHardware.MWInit(speed: integer): boolean; begin Result := True; end;
procedure TDummyHardware.MWDeinit; begin end;
function TDummyHardware.MWRead(CS: byte; BufferLen: integer;
  var buffer: array of byte): integer; begin Result := BufferLen; end;
function TDummyHardware.MWWrite(CS: byte; BitsWrite: byte;
  buffer: array of byte): integer; begin Result := BitsWrite; end;
function TDummyHardware.MWIsBusy: boolean; begin Result := False; end;

procedure TestCapabilities;
var
  HW: TDummyHardware;
  Caps: TProgrammerMemoryCapabilities;

  procedure CheckProtocols(ID: THardwareList;
    Expected: TMemoryProtocols; const LabelText: string);
  begin
    HW := TDummyHardware.Create(ID);
    try
      Check(LabelText + ' capabilities known', HW.GetMemoryCapabilities(Caps));
      Check(LabelText + ' protocol set is exact', Caps.Protocols = Expected);
    finally
      HW.Free;
    end;
  end;
begin
  HW := TDummyHardware.Create(CHW_USBASP);
  try
    Check('USBASP capabilities known', HW.GetMemoryCapabilities(Caps));
    Check('USBASP exposes all three protocols',
      Caps.Protocols = [mpSPI, mpI2C, mpMicroWire]);
    Check('USBASP accepts raw SPI', Caps.RawSPICommands);
  finally
    HW.Free;
  end;

  CheckProtocols(CHW_CH341, [mpSPI, mpI2C, mpMicroWire], 'CH341');
  CheckProtocols(CHW_CH347, [mpSPI, mpI2C], 'CH347 DLL backend');
  CheckProtocols(CHW_AVRISP, [mpSPI, mpI2C, mpMicroWire], 'AVRISP');
  CheckProtocols(CHW_ARDUINO, [mpSPI, mpI2C, mpMicroWire], 'Arduino');
  CheckProtocols(CHW_FT232H, [mpSPI, mpI2C, mpMicroWire], 'FT232H');
  CheckProtocols(CHW_BUZZPIRAT, [mpSPI, mpI2C], 'Buzzpirat');

  HW := TDummyHardware.Create(CHW_EZP);
  try
    Check('EZP capabilities known', HW.GetMemoryCapabilities(Caps));
    Check('EZP is SPI-family only', Caps.Protocols = [mpSPI]);
    Check('EZP does not claim arbitrary SPI', not Caps.RawSPICommands);
    Check('EZP explicitly exposes native whole-chip operations',
      Caps.NativeWholeChipRead and Caps.NativeWholeChipWrite and
      Caps.NativeWholeChipErase);
  finally
    HW.Free;
  end;

  HW := TDummyHardware.Create(CHW_SERPROG);
  try
    Check('serprog supports SPI', HW.SupportsProtocol(mpSPI));
    Check('serprog does not pretend to support I2C',
      not HW.SupportsProtocol(mpI2C));
  finally
    HW.Free;
  end;
end;

begin
  TestCapabilities;
  WriteLn(Assertions, ' assertions, ', Failures, ' failures');
  if Failures <> 0 then Halt(1);
  WriteLn('ALL PASSED');
end.
