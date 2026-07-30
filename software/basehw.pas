unit BaseHW;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, electricalpreflight;

type

//รายชื่ออุปกรณ์ที่รองรับ
THardwareList = (CHW_NONE, CHW_CH341, CHW_CH347, CHW_AVRISP, CHW_USBASP, CHW_ARDUINO, CHW_FT232H, CHW_BUZZPIRAT, CHW_SERPROG);

//คลาสฐานของฮาร์ดแวร์
TBaseHardware = class
protected
  FHardwareName: string;
  FHardwareID: THardwareList;
public
  property HardwareName: string read FHardwareName write FHardwareName;

  function GetLastError: string; virtual; abstract;
  function DevOpen: boolean; virtual; abstract;
  procedure DevClose; virtual; abstract;

  //SPI
  function SPIInit(speed: integer): boolean; virtual; abstract;
  procedure SPIDeinit; virtual; abstract;
  function SPIRead(CS: byte; BufferLen: integer; var buffer: array of byte): integer; virtual; abstract;
  function SPIWrite(CS: byte; BufferLen: integer; buffer: array of byte): integer; virtual; abstract;
  //Largest data phase one SPIRead/SPIWrite call can carry.  Vendor drivers
  //have hard per-call ceilings (the CH341 DLL refuses SPI streams above
  //~3.9KB) and they report such a refusal the same way as an unplugged
  //device, so a caller that exceeds the ceiling diagnoses a disconnect that
  //never happened.  Callers must split longer transfers into complete
  //re-addressed commands of at most this many bytes.
  function SPIMaxTransfer: integer; virtual;
  //Default split transaction for programmers that keep CS asserted across
  //SPIWrite(CS=0) and SPIRead(CS=1).  Backends requiring one native combined
  //exchange (for example Bus Pirate) override this method.
  function SPIWriteRead(CS: byte; WBufferLen: integer;
    WBuffer: array of byte; RBufferLen: integer;
    var RBuffer: array of byte): integer; virtual;

  //Production admission asks the backend for measured, model-specific facts.
  //The default is deliberately "unknown" so a backend cannot enter strict
  //production merely because no one implemented its electrical contract.
  function GetElectricalCapabilities(
    out Capabilities: TProgrammerElectricalCapabilities): boolean; virtual;
  function GetElectricalObservation(
    out Observation: TElectricalObservation): boolean; virtual;

  //I2C
  procedure I2CInit; virtual; abstract;
  procedure I2CDeinit; virtual; abstract;
  function I2CReadWrite(DevAddr: byte;
                        WBufferLen: integer; WBuffer: array of byte;
                        RBufferLen: integer; var RBuffer: array of byte): integer; virtual; abstract;
  //
  procedure I2CStart; virtual; abstract;
  procedure I2CStop; virtual; abstract;
  function I2CReadByte(ack: boolean): byte; virtual; abstract;
  function I2CWriteByte(data: byte): boolean; virtual; abstract; //คืนค่า ack

  //MICROWIRE
  function MWInit(speed: integer): boolean; virtual; abstract;
  procedure MWDeinit; virtual; abstract;
  function MWRead(CS: byte; BufferLen: integer; var buffer: array of byte): integer; virtual; abstract;
  //คืนจำนวนบิตที่เขียนได้
  function MWWrite(CS: byte; BitsWrite: byte; buffer: array of byte): integer; virtual; abstract;
  function MWIsBusy: boolean; virtual; abstract;
end;

//คลาสสำหรับจัดการฮาร์ดแวร์
TAsProgrammer = class
private
  FCurrent_HW : THardwareList;
  FCurrent_prog: TBaseHardware;
  FHwList: TList;

  procedure SetProgrammer(HW: THardwareList);
public
  constructor Create;
  destructor Destroy; Override;

  procedure AddHW(HW: pointer);

  property Current_HW : THardwareList read FCurrent_HW write SetProgrammer;
  property Programmer : TBaseHardware read FCurrent_prog;
end;

var
  //เครื่องโปรแกรมที่กำลังใช้อยู่
  //
  //ตัวแปรนี้เคยอยู่ใน main ซึ่งบังคับให้ทุกหน่วยที่ต้องคุยกับฮาร์ดแวร์
  //ต้อง uses main ตามไปด้วย และ main ลาก LCL ทั้งกองมาด้วย
  //ผลคือชั้นโปรโตคอลอย่าง spi25 เอาไปทดสอบโดยไม่มีหน้าจอไม่ได้เลย
  //ที่นี่คือที่ที่มันควรอยู่ตั้งแต่แรก เพราะชนิดของมันก็ประกาศอยู่ตรงนี้
  AsProgrammer: TAsProgrammer;

implementation

function TBaseHardware.SPIWriteRead(CS: byte; WBufferLen: integer;
  WBuffer: array of byte; RBufferLen: integer;
  var RBuffer: array of byte): integer;
var
  Sent: integer;
  Dummy: array[0..0] of byte;
begin
  Result := -1;
  if (WBufferLen < 0) or (RBufferLen < 0) or
     (WBufferLen > Length(WBuffer)) or
     (RBufferLen > Length(RBuffer)) then Exit;

  //ถ้าไม่มีเฟสอ่าน ต้องส่งด้วย CS ของผู้เรียกในทรานสเฟอร์เดียว: การส่งด้วย
  //CS=0 แล้ว Exit ทิ้งไว้จะค้าง CS ต่ำ และ opcode ของคำสั่งถัดไปจะกลายเป็น
  //ข้อมูลต่อท้ายคำสั่งเดิม
  if RBufferLen = 0 then
  begin
    if WBufferLen = 0 then Exit(0);
    Sent := SPIWrite(CS, WBufferLen, WBuffer);
    if Sent = WBufferLen then Result := 0;
    Exit;
  end;

  if WBufferLen > 0 then
  begin
    Sent := SPIWrite(0, WBufferLen, WBuffer);
    if Sent <> WBufferLen then
    begin
      //ส่งไม่ครบ: CS อาจยังต่ำอยู่ ปล่อยบัสแบบ best effort ก่อนรายงานล้มเหลว
      //เฟรมที่ขาดกลางคันชิปจะทิ้งเองตอน CS ยก ปล่อยค้างไว้อันตรายกว่า
      Dummy[0] := $FF;
      SPIRead(1, 1, Dummy);
      Exit;
    end;
  end;

  Result := SPIRead(CS, RBufferLen, RBuffer);
  if Result <> RBufferLen then Result := -1;
end;

function TBaseHardware.SPIMaxTransfer: integer;
begin
  //2048 is the chunk size every legacy read path has always used for
  //hardware without a larger proven limit; backends override with their own
  //measured value.
  Result := 2048;
end;

function TBaseHardware.GetElectricalCapabilities(
  out Capabilities: TProgrammerElectricalCapabilities): boolean;
begin
  FillChar(Capabilities, SizeOf(Capabilities), 0);
  Capabilities.Known := False;
  Result := False;
end;

function TBaseHardware.GetElectricalObservation(
  out Observation: TElectricalObservation): boolean;
begin
  FillChar(Observation, SizeOf(Observation), 0);
  Result := False;
end;

constructor TAsProgrammer.Create;
begin
  FCurrent_HW := CHW_NONE;
  FHwList := TList.Create;
end;

destructor TAsProgrammer.Destroy;
var
  i: integer;
begin
  for i := 0 to FHwList.Count-1 do
    TBaseHardware(FHwList.Items[i]).Free;
  FHwList.Free;
  inherited Destroy;
end;

procedure TAsProgrammer.AddHW(HW: pointer);
begin
  FHwList.Add(HW);
end;

procedure TAsProgrammer.SetProgrammer(HW: THardwareList);
var
  i: integer;
begin
  FCurrent_HW := CHW_NONE;
  FCurrent_prog := nil;
  for i :=0 to FHwList.Count-1 do
  begin
    if TBaseHardware(FHwList.Items[i]).FHardwareID = HW then
      begin
        FCurrent_prog := TBaseHardware(FHwList.Items[i]);
        FCurrent_HW := HW;
      end;
  end;
end;

end.

