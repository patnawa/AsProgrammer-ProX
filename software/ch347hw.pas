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
  FLedOn: boolean;
  //สองขานี้เขียนแยกกันคนละ mask จะได้ไม่กวนกันเอง
  function ApplyVccGPIO(VccBits: byte): boolean;
  function ApplyLedGPIO(On: boolean): boolean;
public
  constructor Create;
  destructor Destroy; override;

  function GetLastError: string; override;
  function DevOpen: boolean; override;
  procedure DevClose; override;

  function SupportsTargetVoltage: boolean; override;
  function GetTargetVoltageMv: cardinal; override;
  function SetTargetVoltageMv(Millivolts: cardinal): boolean; override;
  procedure SetActivityLED(Active: boolean); override;

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
  FLedOn := False;
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

  //ห้ามแตะ GPIO ตอนเปิดอุปกรณ์
  //
  //ขา GPIO ของ CH347T ใช้ขาร่วมกับฟังก์ชันอื่น การจับขาเป็นเอาต์พุตทั้งที่
  //ยังไม่มีใครขอ จึงไปกวนบัสของงานที่ไม่ได้เกี่ยวกับแรงดันเลย อาการที่เจอคือ
  //อ่าน EEPROM ผ่าน I2C ไม่เจอชิป ทั้งที่ก่อนหน้านี้เคยเจอ
  //
  //เป็นความผิดแบบเดียวกับที่เคยทำกับ GPIO4 แล้วไฟแสดงการทำงานดับ บทเรียนคือ
  //อย่าไปยึดขาที่ใช้ร่วมกับคนอื่นถ้ายังไม่ถึงเวลาต้องใช้จริง ๆ
  //
  //ความปลอดภัยไม่ได้หายไป: ฮาร์ดแวร์รุ่นนี้ตั้งต้นที่ 1.8V ตอนจ่ายไฟอยู่แล้ว
  //และ DevClose ยังลดกลับเป็น 1.8V ให้เหมือนเดิม ที่หายไปคือการเขียนซ้ำโดย
  //ไม่มีใครขอเท่านั้น
  //
  //0 แปลว่า "ยังไม่รู้ว่าจ่ายอยู่เท่าไร" ไม่ใช่ "ไม่มีไฟ" ผู้เรียกที่อยากได้
  //ระดับที่แน่นอนต้องสั่ง SetTargetVoltageMv เอง ซึ่ง ApplyCH347Vcc ทำให้อยู่
  //แล้วก่อนเริ่มงานทุกครั้ง
  FTargetVoltageMv := 0;

  Result := true;
end;

//ตั้งเฉพาะขาเลือกแรงดัน (GPIO6) เท่านั้น
//
//iEnable คลุมบิตเดียว ขาที่เหลือไม่ถูกแตะ จึงไม่ต้องอ่านสถานะเดิมกลับมาก่อน
//และไฟแสดงการทำงานที่ GPIO4 ก็ไม่ขยับตามเวลาสลับแรงดัน เพราะอยู่คนละ mask
function TCH347Hardware.ApplyVccGPIO(VccBits: byte): boolean;
begin
  if not FDevOpened then Exit(False);
  Result := CH347GPIO_Set(FDevHandle, CH347_GPIO_VCC, CH347_GPIO_VCC,
                          VccBits and CH347_GPIO_VCC);
end;

//ไฟแสดงการทำงานอยู่ที่ GPIO4 และต้องสั่งเอง บอร์ดไม่ได้ขับให้
//
//เคยเข้าใจผิดว่าบอร์ดกะพริบเองแล้วถอดโค้ดส่วนนี้ออกไป ผลคือไฟไม่ติดเลย
//วัดจริงแล้ว: สุ่มอ่าน GPIO4 ระหว่างยิง SPI 400 รอบ ค่าไม่ขยับสักครั้งเดียว
//แปลว่าไม่มีวงจรขับจากทราฟฟิก ต้องเขียนขาเอาเองเหมือนที่โปรแกรมผู้ผลิตทำ
//
//ต่อแบบ active low: ระดับต่ำคือไฟติด ตอนไม่มีงานขาอยู่ที่ระดับสูงและไฟดับ
//
//mask คลุมเฉพาะ GPIO4 ขาแรงดันที่ GPIO6 จึงไม่ถูกแตะเลย ทั้งสองอยู่คนละ
//คำสั่งกัน สลับไฟกี่ครั้งก็ไม่ทำให้แรงดันขยับ
function TCH347Hardware.ApplyLedGPIO(On: boolean): boolean;
var
  Level: byte;
begin
  if not FDevOpened then Exit(False);
  if On then Level := 0 else Level := CH347_GPIO_ACT_LED;
  Result := CH347GPIO_Set(FDevHandle, CH347_GPIO_ACT_LED,
                          CH347_GPIO_ACT_LED, Level);
end;

procedure TCH347Hardware.SetActivityLED(Active: boolean);
begin
  if not FDevOpened then Exit;
  if FLedOn = Active then Exit;
  //ไฟไม่ติดไม่ใช่เหตุให้ล้มงาน จำสถานะไว้เท่าที่สั่งผ่านจริง
  if ApplyLedGPIO(Active) then FLedOn := Active;
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
    //ลดกลับเป็น 1.8V ก่อนปล่อย เฉพาะเมื่อรอบนี้เราเป็นคนตั้งไว้เอง
    //
    //ระดับที่ค้างไว้ยังอยู่จนกว่าจะถอดสาย ถ้าปล่อยค้าง 3.3V ไว้แล้วคนถัดไป
    //เสียบชิป 1.8V คือชิปพัง จึงต้องลดกลับให้
    //
    //แต่ถ้ารอบนี้ไม่เคยตั้งแรงดันเลย (เช่น งาน I2C ล้วน ๆ) ก็ไม่ต้องไปแตะขา
    //ด้วยเหตุผลเดียวกับที่ DevOpen ไม่แตะ: ขานี้ใช้ร่วมกับฟังก์ชันอื่น
    if FLedOn then ApplyLedGPIO(False);

    if FVoltageSupported and (FTargetVoltageMv <> 0) then
      ApplyVccGPIO(CH347_GPIO_VCC);

    CH347CloseDevice(FDevHandle);
    FDevHandle := -1;
    FDevOpened := false;
    FVoltageSupported := False;
    FTargetVoltageMv := 0;
    FLedOn := False;
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

  //ติดไฟตอนเริ่มงาน ดับตอนจบ ไม่กะพริบรายทรานสเฟอร์ เพราะการสลับ GPIO
  //หนึ่งครั้งคือการคุย USB หนึ่งรอบ ทำทุกบล็อกแล้วความเร็วอ่านตกเห็น ๆ
  if Result then SetActivityLED(True);
end;

procedure TCH347Hardware.SPIDeinit;
begin
  if not FDevOpened then Exit;
  SetActivityLED(False);
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
  //EEPROM วิ่งบน I2C ไม่ใช่ SPI รอบก่อนผูกไฟไว้กับ SPIInit อย่างเดียว
  //อ่าน EEPROM ทีไรไฟจึงไม่ติด ทั้งที่งานเดินอยู่จริง
  SetActivityLED(True);
end;

procedure TCH347Hardware.I2CDeinit;
begin
  if not FDevOpened then Exit;
  SetActivityLED(False);
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

