unit eepromadapters;

// Real-hardware adapters binding eepromengine.TEEPROMDevice to the existing
// i2c/spi95/microwire primitives -- the same primitives the legacy buttons
// use, with the same exact-transfer discipline.
//
// Session ownership: the caller opens the programmer and enters the bus mode
// (OpenDevice + EnterProgModeI2C / EnterProgMode25 / MWInit), exactly like
// the button paths.  Open/Close here only gate ordering.  What IS the
// adapter's job is write-enable state and the write-cycle wait:
//   - 24Cxx acknowledges nothing during its internal write cycle, so every
//     page is followed by an ack-poll before the adapter returns;
//   - 95xx needs WREN before every page (a page program clears WEL) and a
//     WIP poll afterwards, both rejecting the FF dead-bus value;
//   - 93xx needs EWEN once for the whole session (done in Initialize, undone
//     with EWDS in Deinitialize) and a DO poll after every write.

{$mode objfpc}{$H+}

interface

uses
  SysUtils, eepromengine, i2c, spi95, microwire;

const
  // Generous upper bounds; the polls return as soon as the chip is ready.
  I2C_ADAPTER_WRITE_CYCLE_MS = 100;
  SPI95_ADAPTER_WRITE_CYCLE_MS = 1000;
  MW_ADAPTER_WRITE_CYCLE_MS = 5000;

type
  TI2CEEPROMAdapter = class(TEEPROMDevice)
  private
    FDevAddr, FAddrType: byte;
  public
    constructor Create(ADevAddr, AAddrType: byte);
    function Open: TEEPROMIOResult; override;
    function Initialize: TEEPROMIOResult; override;
    function WritePage(Address: QWord;
      const Data: TBytes): TEEPROMIOResult; override;
    function ReadPage(Address: QWord; Len: cardinal;
      out Data: TBytes): TEEPROMIOResult; override;
    function Deinitialize: TEEPROMIOResult; override;
    function Close: TEEPROMIOResult; override;
  end;

  TSPI95EEPROMAdapter = class(TEEPROMDevice)
  private
    FChipSize: integer;
  public
    constructor Create(AChipSize: integer);
    function Open: TEEPROMIOResult; override;
    function Initialize: TEEPROMIOResult; override;
    function WritePage(Address: QWord;
      const Data: TBytes): TEEPROMIOResult; override;
    function ReadPage(Address: QWord; Len: cardinal;
      out Data: TBytes): TEEPROMIOResult; override;
    function Deinitialize: TEEPROMIOResult; override;
    function Close: TEEPROMIOResult; override;
  end;

  // 93xx MicroWire is word-organised through these primitives: device
  // addresses are word addresses and transfers are two bytes, so the engine
  // must be planned with PageSize = 2 and even byte addresses.
  TMWEEPROMAdapter = class(TEEPROMDevice)
  private
    FAddrBitLen: byte;
    FWriteEnabled: boolean;
  public
    constructor Create(AAddrBitLen: byte);
    function Open: TEEPROMIOResult; override;
    function Initialize: TEEPROMIOResult; override;
    function WritePage(Address: QWord;
      const Data: TBytes): TEEPROMIOResult; override;
    function ReadPage(Address: QWord; Len: cardinal;
      out Data: TBytes): TEEPROMIOResult; override;
    function Deinitialize: TEEPROMIOResult; override;
    function Close: TEEPROMIOResult; override;
  end;

implementation

//---------------------------------------------------------------- I2C 24Cxx

constructor TI2CEEPROMAdapter.Create(ADevAddr, AAddrType: byte);
begin
  inherited Create;
  FDevAddr := ADevAddr;
  FAddrType := AAddrType;
end;

function TI2CEEPROMAdapter.Open: TEEPROMIOResult;
begin
  Result := EEPROMIOSuccess; // session owned by the caller
end;

function TI2CEEPROMAdapter.Initialize: TEEPROMIOResult;
begin
  // The caller entered I2C mode; a chip that does not acknowledge is caught
  // by the first real transfer, with an address to report.
  Result := EEPROMIOSuccess;
end;

function TI2CEEPROMAdapter.WritePage(Address: QWord;
  const Data: TBytes): TEEPROMIOResult;
var
  BusAddr: TI2CAddr;
  Wrote: integer;
begin
  if (Length(Data) = 0) or (Address > High(longword)) then
    Exit(EEPROMIOFailure(eioRejected, 'I2C page write parameters are invalid'));
  if not BuildI2CAddr(FDevAddr, FAddrType, longword(Address), BusAddr) then
    Exit(EEPROMIOFailure(eioRejected, 'the I2C address mode is invalid'));

  Wrote := UsbAspI2C_Write(FDevAddr, FAddrType, longword(Address),
                           Data, Length(Data));
  if Wrote <> Length(Data) then
    Exit(EEPROMIOFailure(eioTransport,
      Format('I2C page write sent %d of %d bytes', [Wrote, Length(Data)])));

  // The chip is deaf during its internal write cycle; only a successful
  // ack-poll proves the page settled.
  if not UsbAspI2C_WaitReady(BusAddr.DevByte, I2C_ADAPTER_WRITE_CYCLE_MS) then
    Exit(EEPROMIOFailure(eioTimeout,
      'the I2C EEPROM stopped acknowledging during the write cycle'));

  Result := EEPROMIOSuccess(cardinal(Wrote));
end;

function TI2CEEPROMAdapter.ReadPage(Address: QWord; Len: cardinal;
  out Data: TBytes): TEEPROMIOResult;
var
  Got: integer;
begin
  SetLength(Data, 0);
  if (Len = 0) or (Len > 65535) or (Address > High(longword)) then
    Exit(EEPROMIOFailure(eioRejected, 'I2C page read parameters are invalid'));
  SetLength(Data, Len);
  Got := UsbAspI2C_Read(FDevAddr, FAddrType, longword(Address), Data, Len);
  if Got <> integer(Len) then
  begin
    SetLength(Data, 0);
    Exit(EEPROMIOFailure(eioTransport,
      Format('I2C read returned %d of %d bytes', [Got, Len])));
  end;
  Result := EEPROMIOSuccess(Len);
end;

function TI2CEEPROMAdapter.Deinitialize: TEEPROMIOResult;
begin
  Result := EEPROMIOSuccess;
end;

function TI2CEEPROMAdapter.Close: TEEPROMIOResult;
begin
  Result := EEPROMIOSuccess;
end;

//---------------------------------------------------------------- SPI 95xx

constructor TSPI95EEPROMAdapter.Create(AChipSize: integer);
begin
  inherited Create;
  FChipSize := AChipSize;
end;

function TSPI95EEPROMAdapter.Open: TEEPROMIOResult;
begin
  Result := EEPROMIOSuccess;
end;

function TSPI95EEPROMAdapter.Initialize: TEEPROMIOResult;
begin
  Result := EEPROMIOSuccess;
end;

function TSPI95EEPROMAdapter.WritePage(Address: QWord;
  const Data: TBytes): TEEPROMIOResult;
var
  WEL: boolean;
  Wrote: integer;
  Status: byte;
begin
  if (Length(Data) = 0) or (Address > High(longword)) or
     (not SPI95AddressRangeValid(FChipSize, longword(Address),
                                 Length(Data))) then
    Exit(EEPROMIOFailure(eioRejected,
      'SPI EEPROM page write parameters are invalid'));

  // Every page needs its own observed WEL: a page program clears it, and a
  // WREN the chip ignored means everything after it is silently dropped.
  //UsbAsp95_WrenChecked คืนค่าเท่ากับ WEL เสมอ การเช็ค WEL ซ้ำหลังจากนั้น
  //จึงเป็นกิ่งที่ไม่มีวันทำงาน ต้องแยกสาเหตุด้วยการอ่าน SR เองแทน
  if not UsbAsp95_WrenChecked(WEL) then
  begin
    if UsbAsp95_ReadSR(Status) <> 1 then
      Exit(EEPROMIOFailure(eioTransport,
        'the SPI EEPROM write-enable transaction was not exact'));
    if Status = $FF then
      Exit(EEPROMIOFailure(eioDisconnected,
        'the SPI EEPROM status bus reads FF; no chip is answering'));
    //ชิปรับคำสั่งแล้วแต่ WEL ไม่ติด = ถูกป้องกันการเขียนอยู่ ไม่ใช่สายเสีย
    Exit(EEPROMIOFailure(eioRejected,
      'the SPI EEPROM did not latch write enable; it is write protected'));
  end;

  Wrote := UsbAsp95_Write(FChipSize, longword(Address), Data, Length(Data));
  if Wrote <> Length(Data) then
    Exit(EEPROMIOFailure(eioTransport,
      Format('SPI EEPROM page write sent %d of %d bytes',
             [Wrote, Length(Data)])));

  if not UsbAsp95_WaitReady(SPI95_ADAPTER_WRITE_CYCLE_MS, Status) then
  begin
    if Status = $FF then
      Exit(EEPROMIOFailure(eioDisconnected,
        'the SPI EEPROM status bus reads FF; no chip is answering'));
    Exit(EEPROMIOFailure(eioTimeout,
      'the SPI EEPROM stayed busy after the page write'));
  end;

  Result := EEPROMIOSuccess(cardinal(Wrote));
end;

function TSPI95EEPROMAdapter.ReadPage(Address: QWord; Len: cardinal;
  out Data: TBytes): TEEPROMIOResult;
var
  Got: integer;
begin
  SetLength(Data, 0);
  if (Len = 0) or (Len > 65535) or (Address > High(longword)) or
     (not SPI95AddressRangeValid(FChipSize, longword(Address),
                                 integer(Len))) then
    Exit(EEPROMIOFailure(eioRejected,
      'SPI EEPROM page read parameters are invalid'));
  SetLength(Data, Len);
  Got := UsbAsp95_Read(FChipSize, longword(Address), Data, Len);
  if Got <> integer(Len) then
  begin
    SetLength(Data, 0);
    Exit(EEPROMIOFailure(eioTransport,
      Format('SPI EEPROM read returned %d of %d bytes', [Got, Len])));
  end;
  Result := EEPROMIOSuccess(Len);
end;

function TSPI95EEPROMAdapter.Deinitialize: TEEPROMIOResult;
begin
  //ปล่อยชิปไว้ในสถานะห้ามเขียนให้เครื่องมือตัวถัดไป และถ้าทำไม่สำเร็จต้อง
  //บอก ไม่ใช่กลืนไว้ ไม่งั้นผลลัพธ์จะอ้างว่าชิปปลอดภัยทั้งที่ WEL ยังติดอยู่
  if UsbAsp95_Wrdi() <> 1 then
    Result := EEPROMIOFailure(eioTransport,
      'the SPI EEPROM write-disable was not transferred exactly; ' +
      'it may remain write-enabled')
  else
    Result := EEPROMIOSuccess;
end;

function TSPI95EEPROMAdapter.Close: TEEPROMIOResult;
begin
  Result := EEPROMIOSuccess;
end;

//---------------------------------------------------------------- 93xx MW

constructor TMWEEPROMAdapter.Create(AAddrBitLen: byte);
begin
  inherited Create;
  FAddrBitLen := AAddrBitLen;
  FWriteEnabled := False;
end;

function TMWEEPROMAdapter.Open: TEEPROMIOResult;
begin
  Result := EEPROMIOSuccess;
end;

function TMWEEPROMAdapter.Initialize: TEEPROMIOResult;
begin
  // EWEN is session state on 93xx; it is undone exactly once in
  // Deinitialize, which the engine guarantees to call.
  //
  // The flag goes up BEFORE the attempt on purpose: a short EWEN means some
  // of the frame already reached the chip, so it may well be write-enabled.
  // Marking it only on success would skip EWDS in cleanup and leave the part
  // write-enabled on the socket for whatever the next tool does.
  FWriteEnabled := True;
  if UsbAspMW_Ewen(FAddrBitLen) <> FAddrBitLen + 3 then
    Exit(EEPROMIOFailure(eioRejected,
      'the MicroWire EEPROM did not accept EWEN'));
  Result := EEPROMIOSuccess;
end;

function TMWEEPROMAdapter.WritePage(Address: QWord;
  const Data: TBytes): TEEPROMIOResult;
var
  Wrote: integer;
begin
  // Word-organised: two bytes at an even byte address, always.
  if (Length(Data) <> 2) or ((Address and 1) <> 0) or
     (Address div 2 > High(word)) then
    Exit(EEPROMIOFailure(eioRejected,
      'MicroWire writes are two bytes at an even address'));

  Wrote := UsbAspMW_Write(FAddrBitLen, word(Address div 2), Data, 2);
  if Wrote <> 2 then
    Exit(EEPROMIOFailure(eioTransport,
      Format('MicroWire write sent %d of 2 bytes', [Wrote])));

  if not UsbAspMW_WaitReady(MW_ADAPTER_WRITE_CYCLE_MS) then
    Exit(EEPROMIOFailure(eioTimeout,
      'the MicroWire EEPROM stayed busy after the write'));

  Result := EEPROMIOSuccess(2);
end;

function TMWEEPROMAdapter.ReadPage(Address: QWord; Len: cardinal;
  out Data: TBytes): TEEPROMIOResult;
var
  Got: integer;
begin
  SetLength(Data, 0);
  if (Len = 0) or ((Len and 1) <> 0) or (Len > 65534) or
     ((Address and 1) <> 0) or (Address div 2 > High(word)) then
    Exit(EEPROMIOFailure(eioRejected,
      'MicroWire reads are whole words at an even address'));
  SetLength(Data, Len);
  Got := UsbAspMW_Read(FAddrBitLen, word(Address div 2), Data, Len);
  if Got <> integer(Len) then
  begin
    SetLength(Data, 0);
    Exit(EEPROMIOFailure(eioTransport,
      Format('MicroWire read returned %d of %d bytes', [Got, Len])));
  end;
  Result := EEPROMIOSuccess(Len);
end;

function TMWEEPROMAdapter.Deinitialize: TEEPROMIOResult;
begin
  Result := EEPROMIOSuccess;
  if not FWriteEnabled then Exit;
  FWriteEnabled := False;
  if UsbAspMW_Ewds(FAddrBitLen) <> FAddrBitLen + 3 then
    Result := EEPROMIOFailure(eioTransport,
      'the MicroWire EEPROM did not accept EWDS; it may remain write-enabled');
end;

function TMWEEPROMAdapter.Close: TEEPROMIOResult;
begin
  Result := EEPROMIOSuccess;
end;

end.
