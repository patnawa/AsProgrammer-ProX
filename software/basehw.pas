unit BaseHW;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type

//รายชื่ออุปกรณ์ที่รองรับ
THardwareList = (CHW_NONE, CHW_CH341, CHW_CH347, CHW_AVRISP, CHW_USBASP, CHW_ARDUINO, CHW_FT232H, CHW_BUZZPIRAT);

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
  function SPIWriteRead(CS: byte; WBufferLen: integer; WBuffer: array of byte;RBufferLen: integer; var RBuffer: array of byte): integer; virtual; abstract;

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

