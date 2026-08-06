unit ch347hw;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, basehw, msgstr, ch347dll, ch341dll, utilfunc;

type

{ TCH347Hardware }

TCH347Hardware = class(TBaseHardware)
private
  FDevOpened: boolean;
  FDevHandle: Longint;
  FStrError: string;
  FDevSPIConfig: _SPI_CONFIG;
  FTargetVoltageMv: cardinal;
  FVoltageSupported: boolean;
  //ตั้งเฉพาะขาแรงดัน ห้ามแตะขาไฟแสดงการทำงาน (ดูหมายเหตุที่ตัวฟังก์ชัน)
  function ApplyVccGPIO(VccBits: byte): boolean;
public
  constructor Create;
  destructor Destroy; override;

  function GetLastError: string; override;
  function DevOpen: boolean; override;
  procedure DevClose; override;

  function SupportsTargetVoltage: boolean; override;
  function GetTargetVoltageMv: cardinal; override;
  function SetTargetVoltageMv(Millivolts: cardinal): boolean; override;
  //ไม่ override SetActivityLED โดยตั้งใจ ไฟบนบอร์ดมีวงจรขับของตัวเองอยู่แล้ว

  //spi
  function SPIRead(CS: byte; BufferLen: integer; var buffer: array of byte): integer; override;
  function SPIWrite(CS: byte; BufferLen: integer; buffer: array of byte): integer; override;
  function SPIMaxTransfer: integer; override;
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
  function I2CWriteByte(data: byte): boolean; override; //คืนค่า ack

  //MICROWIRE
  function MWInit(speed: integer): boolean; override;
  procedure MWDeinit; override;
  function MWRead(CS: byte; BufferLen: integer; var buffer: array of byte): integer; override;
  function MWWrite(CS: byte; BitsWrite: byte; buffer: array of byte): integer; override;
  function MWIsBusy: boolean; override;
end;

implementation
uses main;

constructor TCH347Hardware.Create;
begin
  FDevHandle := -1;
  FHardwareName := 'CH347';
  FHardwareID := CHW_CH347;
  //ยังไม่เปิดอุปกรณ์ก็ยังไม่รู้ว่าจ่ายอยู่เท่าไร 0 แปลว่าไม่รู้ ไม่ใช่ไม่มีไฟ
  FTargetVoltageMv := 0;
  FVoltageSupported := False;
end;

destructor TCH347Hardware.Destroy;
begin
  DevClose;
end;

function TCH347Hardware.GetLastError: string;
begin
  result := FStrError;
end;

function TCH347Hardware.DevOpen: boolean;
var
  i: integer;
  err: integer;
begin
  if FDevOpened then DevClose;

  FDevHandle := -1;
  err := -1;

  for i := 0 to mCH341_MAX_NUMBER-1 do
  begin
    //CH347OpenDevice คืน HANDLE ไม่ใช่ดัชนี ล้มเหลวคือ INVALID_HANDLE_VALUE
    //ค่าที่ใช้ได้เป็นบวกเสมอในทางปฏิบัติ แต่เทียบกับ -1 ตรง ๆ ตามสัญญาของ WCH
    err := CH347OpenDevice(i);
    if (err = -1) or (err = 0) then Continue;

    //CH347DLL ครอบ API ของ CH341 ไว้ด้วย และไล่เจออุปกรณ์ CH341 เหมือนกัน
    //ตัวที่ไม่ใช่ CH347 ต้องปิดคืน ไม่งั้นเลือก CH341 ทีหลังแล้วเปิดไม่ได้
    //
    //ห้ามตัดสินจาก CH347GetChipType = 0 เพียงอย่างเดียว เพราะ 0 คือทั้ง
    //"เป็น CH341" และ "ถามไม่สำเร็จ" ดูรายละเอียดที่ utilfunc.CH347GateAccepts
    if not CH347GateAccepts(CH347ChipType(i), CH347DeviceName(i)) then
    begin
      CH347CloseDevice(i);
      err := -1;
      Continue;
    end;

    FDevHandle := i;
    Break;
  end;

  if FDevHandle < 0 then
  begin
    FStrError :=  STR_CONNECTION_ERROR+ FHardwareName +'('+IntToStr(err)+')';
    FDevOpened := false;
    Exit(false);
  end;

  FDevOpened := true;

  //บอร์ด CH347Ⅱ V2.13 สลับแรงดันด้วย GPIO6 ส่วน DLL รุ่นเก่าไม่มี export ของ
  //GPIO เลย เครื่องแบบนั้นจ่ายตามที่ฮาร์ดแวร์ตั้งไว้อย่างเดียว บอกผู้ใช้ว่า
  //ตั้งไม่ได้ดีกว่าปล่อยให้กดแล้วเงียบ
  FVoltageSupported := CH347GPIOAvailable;
  if FVoltageSupported then
  begin
    //ตั้ง 1.8V ทุกครั้งที่เปิด ตรงกับที่ฮาร์ดแวร์และโปรแกรมของผู้ผลิตทำ
    //เหตุผลเดียวกัน: ถ้าเผลอค้าง 3.3V ไว้จากงานก่อน แล้วงานนี้เป็นชิป 1.8V
    //ชิปพังตั้งแต่ยังไม่ทันสั่งอะไร ค่าต่ำสุดจึงเป็นค่าเริ่มต้นที่ถูกต้อง
    if ApplyVccGPIO(CH347_GPIO_VCC) then
      FTargetVoltageMv := CH347_VCC_1V8_MV
    else
    begin
      //ผูก export ได้แต่สั่งไม่ผ่าน แปลว่าไม่รู้ว่าตอนนี้จ่ายอยู่เท่าไร
      //อย่าอ้างว่าตั้งได้ทั้งที่เพิ่งตั้งไม่สำเร็จ
      FVoltageSupported := False;
      FTargetVoltageMv := 0;
    end;
  end
  else
    FTargetVoltageMv := 0;

  Result := true;
end;

//ตั้งเฉพาะขาเลือกแรงดัน (GPIO6) เท่านั้น
//
//ห้ามแตะ GPIO4 เด็ดขาด แม้จะรู้ว่าเป็นขาไฟแสดงการทำงานก็ตาม
//
//บอร์ดมีวงจรขับไฟดวงนั้นจากทราฟฟิกบนบัสอยู่แล้ว ตราบใดที่ขายังเป็นอินพุต
//(ปล่อยลอย) ไฟจะกะพริบตามงานเองโดยไม่ต้องมีใครสั่ง พอเราจับมันเป็นเอาต์พุต
//เมื่อไร วงจรนั้นก็ถูกกดทับทันที ไฟเลยดับสนิททั้งงาน ซึ่งแย่กว่าเดิม
//
//เคยพลาดมาแล้วจริง ๆ: รุ่นก่อนหน้าตั้ง GPIO4 เป็นเอาต์พุตแล้วดันขึ้นสูงตอน
//เปิดอุปกรณ์ ไฟเขียวที่เคยกะพริบตอนอ่าน EEPROM เลยหายไปทั้งดวง
//
//iEnable คลุมบิตเดียว ขาที่เหลือไม่ถูกแตะ จึงไม่ต้องอ่านสถานะเดิมกลับมาก่อน
function TCH347Hardware.ApplyVccGPIO(VccBits: byte): boolean;
begin
  if not FDevOpened then Exit(False);
  Result := CH347GPIO_Set(FDevHandle, CH347_GPIO_VCC, CH347_GPIO_VCC,
                          VccBits and CH347_GPIO_VCC);
end;

function TCH347Hardware.SupportsTargetVoltage: boolean;
begin
  Result := FDevOpened and FVoltageSupported;
end;

function TCH347Hardware.GetTargetVoltageMv: cardinal;
begin
  Result := FTargetVoltageMv;
end;

function TCH347Hardware.SetTargetVoltageMv(Millivolts: cardinal): boolean;
var
  VccBits: byte;
begin
  if not SupportsTargetVoltage then Exit(False);
  //ระดับที่บอร์ดจ่ายไม่ได้ต้องปฏิเสธ ไม่ใช่ปัดเป็นค่าใกล้เคียง การปัดขึ้น
  //ทำชิปพัง ส่วนการปัดลงทำให้ผู้ใช้เชื่อว่าตั้งได้แล้วทั้งที่ไม่ได้ตั้ง
  if not CH347VccDataBits(Millivolts, VccBits) then Exit(False);

  Result := ApplyVccGPIO(VccBits);
  if Result then FTargetVoltageMv := Millivolts;
end;

procedure TCH347Hardware.DevClose;
begin
  if FDevHandle >= 0 then
  begin
    //คืนบอร์ดให้อยู่ในสภาพปลอดภัยก่อนปล่อย: ดับไฟและลดกลับเป็น 1.8V
    //ระดับที่ค้างไว้ยังอยู่จนกว่าจะถอดสาย โปรแกรมตัวถัดไปที่เปิดต่อจะเจอ
    //ค่านี้ ถ้าปล่อยค้าง 3.3V ไว้แล้วคนถัดไปเสียบชิป 1.8V คือชิปพัง
    if FVoltageSupported then
      ApplyVccGPIO(CH347_GPIO_VCC);

    CH347CloseDevice(FDevHandle);
    FDevHandle := -1;
    FDevOpened := false;
    FVoltageSupported := False;
    FTargetVoltageMv := 0;
  end;
end;


//SPI___________________________________________________________________________

function TCH347Hardware.SPIInit(speed: integer): boolean;
begin
  if not FDevOpened then Exit(false);
  with FDevSPIConfig do
  begin
    iMode:= 0;
    iClock:= speed;
    iByteOrder:= 1;
    iSpiWriteReadInterval:= 0;
    iSpiOutDefaultData:= 0;
    iChipSelect:= $0;
    CS1Polarity:= 0;
    CS2Polarity:= 0;
    iIsAutoDeativeCS:= 0;
    iActiveDelay:= 0;
    iDelayDeactive:= 0;
  end;

  Result := CH347SPI_Init(FDevHandle, @FDevSPIConfig);

  //ไม่ยุ่งกับไฟแสดงการทำงาน วงจรบนบอร์ดกะพริบตามทราฟฟิกเองอยู่แล้ว
  //และครอบคลุมทั้ง SPI และ I2C ซึ่งดีกว่าที่โค้ดนี้เคยทำได้
end;

procedure TCH347Hardware.SPIDeinit;
begin
  if not FDevOpened then Exit;
end;

function TCH347Hardware.SPIMaxTransfer: integer;
begin
  //The chunk size the whole-chip read path has always used on CH347.
  Result := 65535;
end;

function TCH347Hardware.SPIRead(CS: byte; BufferLen: integer; var buffer: array of byte): integer;
begin
  if not FDevOpened then Exit(-1);

  if (CS = 1) then if not CH347SPI_Read(FDevHandle, $80, 0, @BufferLen, @buffer) then result :=-1 else result := BufferLen
  else
  begin
    CH347SPI_ChangeCS(FDevHandle, 0); //ชัก cs เอง
    if not CH347SPI_Read(FDevHandle, 0, 0, @BufferLen, @buffer) then result :=-1 else result := BufferLen;
  end;

end;

function TCH347Hardware.SPIWrite(CS: byte; BufferLen: integer; buffer: array of byte): integer;
begin
  if not FDevOpened then Exit(-1);

  if (CS = 1) then if not CH347SPI_Write(FDevHandle, $80, BufferLen, 500, @buffer) then result :=-1 else result := BufferLen
  else
  begin
    CH347SPI_ChangeCS(FDevHandle, 0); //ชัก cs เอง
    if not CH347SPI_Write(FDevHandle, 0, BufferLen, 500, @buffer) then result :=-1 else result := BufferLen;
  end;

end;

//i2c___________________________________________________________________________

procedure TCH347Hardware.I2CInit;
begin
  if not FDevOpened then Exit;
  CH347I2C_Set(FDevHandle, 1);
end;

procedure TCH347Hardware.I2CDeinit;
begin
  if not FDevOpened then Exit;
end;

function TCH347Hardware.I2CReadWrite(DevAddr: byte;
                        WBufferLen: integer; WBuffer: array of byte;
                        RBufferLen: integer; var RBuffer: array of byte): integer;
var
  full_buff: array of byte;
begin
  if not FDevOpened then Exit(-1);

  SetLength(full_buff, WBufferLen+1);
  move(WBuffer, full_buff[1], WBufferLen);
  full_buff[0] := DevAddr;

  if not CH347StreamI2C(FDevHandle, WBufferLen+1, @full_buff[0], RBufferLen, @RBuffer) then result := -1 else result := WBufferLen+RBufferLen;
end;

procedure TCH347Hardware.I2CStart;
var
  mLength: Cardinal;
  mBuffer: array[0..mCH347_PACKET_LENGTH-1] of Byte;
begin
  if not FDevOpened then Exit;

  mBuffer[0] := mCH341A_CMD_I2C_STREAM;   // รหัสคำสั่ง
  mBuffer[1] := mCH341A_CMD_I2C_STM_STA;  // รหัสบิตเริ่ม
  mBuffer[2] := mCH341A_CMD_I2C_STM_END;  // ปิดท้ายแพ็กเก็ต
  mLength := 3;                           // ความยาวแพ็กเก็ต

  CH347WriteData(FDevHandle, @mBuffer, @mLength); // เขียนบล็อกข้อมูล
end;

procedure TCH347Hardware.I2CStop;
var
  mLength: Cardinal;
  mBuffer: array[0..mCH347_PACKET_LENGTH-1] of Byte;
begin
  if not FDevOpened then Exit;

  mBuffer[0] := mCH341A_CMD_I2C_STREAM;   // รหัสคำสั่ง
  mBuffer[1] := mCH341A_CMD_I2C_STM_STO;  // รหัสบิตหยุด
  mBuffer[2] := mCH341A_CMD_I2C_STM_END;  // ปิดท้ายแพ็กเก็ต
  mLength := 3;                           // ความยาวแพ็กเก็ต

  CH347WriteData(FDevHandle, @mBuffer, @mLength); // เขียนบล็อกข้อมูล
end;

function TCH347Hardware.I2CReadByte(ack: boolean): byte;
var
  mLength: Cardinal;
  mBuffer: array[0..mCH347_PACKET_LENGTH-1] of Byte;
begin
  if not FDevOpened then Exit;

  mBuffer[0] := mCH341A_CMD_I2C_STREAM;
  mBuffer[1] := mCH341A_CMD_I2C_STM_IN;
  if ack then mBuffer[1] := mBuffer[1] or 1; // บิต ack
  mBuffer[2] := mCH341A_CMD_I2C_STM_END;

  mLength := 3;
  CH347WriteData(FDevHandle, @mBuffer, @mLength);

  mLength:= mCH347_PACKET_LENGTH;
  CH347ReadData(FDevHandle, @mBuffer, @mLength);

  result := mBuffer[0];
end;

function TCH347Hardware.I2CWriteByte(data: byte): boolean;
var
  mLength: Cardinal;
  mBuffer: array[0..mCH347_PACKET_LENGTH-1] of Byte;
begin
  if not FDevOpened then Exit;

  mBuffer[0] := mCH341A_CMD_I2C_STREAM;
  mBuffer[1] := mCH341A_CMD_I2C_STM_OUT or 1;
  mBuffer[2] := data;
  mBuffer[3] := mCH341A_CMD_I2C_STM_END;
  mLength := 4;
  CH347WriteData(FDevHandle, @mBuffer, @mLength);

  mLength:= mCH347_PACKET_LENGTH;
  CH347ReadData(FDevHandle, @mBuffer, @mLength);

  result := boolean(mBuffer[0]);
end;

//MICROWIRE_____________________________________________________________________

function TCH347Hardware.MWInit(speed: integer): boolean;
begin
    if not FDevOpened then Exit(false);
    main.LogPrint('MICROWIRE not supported');
    Exit(false);
end;

procedure TCH347Hardware.MWDeInit;
begin
  if not FDevOpened then Exit;

end;

function TCH347Hardware.MWRead(CS: byte; BufferLen: integer; var buffer: array of byte): integer;
begin
  if not FDevOpened then Exit(-1);

end;

function TCH347Hardware.MWWrite(CS: byte; BitsWrite: byte; buffer: array of byte): integer;
begin
  if not FDevOpened then Exit(-1);


end;

function TCH347Hardware.MWIsBusy: boolean;
begin

end;

end.

