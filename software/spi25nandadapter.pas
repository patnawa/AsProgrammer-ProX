unit spi25nandadapter;

// Wire framing between TNANDDevice and a TBaseHardware SPI programmer.
//
// The SPI NAND command model, which is nothing like NOR:
//
//   13h + 3-byte row      load a page into the chip's cache
//   03h + 2-byte column   read from the cache (one dummy byte after the
//                         column on every part in the catalog)
//   06h                   write enable, WEL confirmed via C0h
//   02h + 2-byte column   program load (resets the cache to FF first)
//   10h + 3-byte row      program execute
//   D8h + 3-byte row      block erase
//   0Fh/1Fh + register    get/set feature (A0h protection, B0h config,
//                         C0h status)
//   FFh                   reset
//
// Every command that starts an internal operation is followed by polling
// OIP in C0h, and the completion flags the chip itself raises -- P_FAIL,
// E_FAIL, and the ECC status bits -- are returned to the engine explicitly.
// An all-FF status byte is a bus nobody is driving, not a chip that is
// ready, same rule as everywhere else in this program.
//
// The adapter does not open or close the programmer: the caller owns the
// session (the CLI opens the device and initializes SPI exactly as it does
// for SFDP dumps). It also does not choose blocks or check bad-block maps;
// that is the planner's job, enforced by the engine.

{$mode objfpc}{$H+}

interface

uses
  SysUtils, BaseHW, nandmodel, nandengine, nandcatalog;

const
  NAND_FEAT_PROTECTION = $A0;
  NAND_FEAT_CONFIG     = $B0;
  NAND_FEAT_STATUS     = $C0;

  NAND_STATUS_OIP    = $01;
  NAND_STATUS_WEL    = $02;
  NAND_STATUS_E_FAIL = $04;
  NAND_STATUS_P_FAIL = $08;
  NAND_STATUS_ECC    = $30;  //bits 5:4
  NAND_CONFIG_ECC_E  = $10;  //bit 4 of B0h
  //BP bits (and TB where present) across the catalog's vendors all live in
  //bits 6:3 of A0h. After an unlock they must all read back clear.
  NAND_PROT_BP_MASK  = $78;

type
  TSPINANDReadTransport = (sntSplitWriteRead, sntCombinedWriteRead);

  TSPINANDConfig = record
    ReadTransport: TSPINANDReadTransport;
    ReadTimeoutMs: cardinal;     //page load: tens of microseconds really
    ProgramTimeoutMs: cardinal;  //hundreds of microseconds typically
    EraseTimeoutMs: cardinal;    //up to ~10 ms per block
    ResetTimeoutMs: cardinal;
    DrainTimeoutMs: cardinal;    //post-error proof that OIP really cleared
    PollDelayMs: cardinal;       //0 = spin as fast as the bus allows
  end;

  TSPINANDDevice = class(TNANDDevice)
  private
    FHW: TBaseHardware;
    FGeometry: TNANDGeometry;
    FConfig: TSPINANDConfig;

    function WriteExact(CS: byte; const Data: TBytes;
      const Context: string): TNANDIOResult;
    function Exchange(const Header: TBytes; Len: cardinal; out Data: TBytes;
      const Context: string): TNANDIOResult;
    function GetFeature(Reg: byte; out Value: byte): TNANDIOResult;
    function SetFeature(Reg, Value: byte): TNANDIOResult;
    function WaitReady(TimeoutMs: cardinal; const Context: string;
      out Status: byte): TNANDIOResult;
    function WriteEnableChecked: TNANDIOResult;
    function RowAddress(Block, Page: cardinal): cardinal;
    function ECCVerdict(Status: byte): TNANDECCStatus;
  public
    constructor Create(HW: TBaseHardware; const Geometry: TNANDGeometry;
      const Config: TSPINANDConfig);

    //FFh then wait: brings a chip another tool left mid-operation back.
    function Reset: TNANDIOResult;
    //Raw bytes clocked out after 9Fh, for nandcatalog.NANDIdentify.
    function ReadRawID(out Raw: TBytes): TNANDIOResult;
    //Read consecutive 256-byte ONFI parameter-page copies from the checked
    //vendor mode in nandcatalog, restoring B0h exactly on every exit path.
    function ReadONFIParameterPages(
      const Access: TSPINANDParameterPageAccess;
      out Raw: TBytes): TNANDIOResult;

    function ReadPage(Block, Page, Offset, Len: cardinal; out Data: TBytes;
      out ECC: TNANDECCStatus): TNANDIOResult; override;
    function ProgramPage(Block, Page, Offset: cardinal; const Data: TBytes;
      out ProgramFailed: boolean): TNANDIOResult; override;
    function EraseBlock(Block: cardinal; out EraseFailed: boolean):
      TNANDIOResult; override;
    function SetECC(Enabled: boolean): TNANDIOResult; override;
    function GetECC(out Enabled: boolean): TNANDIOResult; override;
    function GetProtection(out Value: byte): TNANDIOResult; override;
    function SetProtection(Value: byte): TNANDIOResult; override;
    function GetConfiguration(out Value: byte): TNANDIOResult; override;
    function SetConfiguration(Value: byte): TNANDIOResult; override;
    function EnsureIdle: TNANDIOResult; override;
    function WriteDisable: TNANDIOResult; override;
    function UnlockAll: TNANDIOResult; override;
  end;

function DefaultSPINANDConfig: TSPINANDConfig;

implementation

function DefaultSPINANDConfig: TSPINANDConfig;
begin
  Result.ReadTransport := sntSplitWriteRead;
  //เพดานหลวมกว่าดาต้าชีตมาก เพราะนี่คือเพดานกันค้าง ไม่ใช่ความเร็วที่คาด
  Result.ReadTimeoutMs := 100;
  Result.ProgramTimeoutMs := 200;
  Result.EraseTimeoutMs := 1000;
  Result.ResetTimeoutMs := 500;
  Result.DrainTimeoutMs := 2000;
  Result.PollDelayMs := 0;
end;

constructor TSPINANDDevice.Create(HW: TBaseHardware;
  const Geometry: TNANDGeometry; const Config: TSPINANDConfig);
begin
  inherited Create;
  FHW := HW;
  FGeometry := Geometry;
  FConfig := Config;
end;

function TSPINANDDevice.WriteExact(CS: byte; const Data: TBytes;
  const Context: string): TNANDIOResult;
var
  N: integer;
begin
  if FHW = nil then
    Exit(NANDIOFailure(nnioRejected, Context + ': no hardware'));
  if Length(Data) = 0 then
    Exit(NANDIOFailure(nnioRejected, Context + ': empty write'));
  try
    N := FHW.SPIWrite(CS, Length(Data), Data);
  except
    on E: Exception do
      Exit(NANDIOFailure(nnioTransport, Context + ': ' + E.Message));
  end;
  if N <> Length(Data) then
    Exit(NANDIOFailure(nnioTransport,
      Format('%s: sent %d of %d bytes', [Context, N, Length(Data)])));
  Result := NANDIOSuccess;
end;

function TSPINANDDevice.Exchange(const Header: TBytes; Len: cardinal;
  out Data: TBytes; const Context: string): TNANDIOResult;
var
  N: integer;
begin
  Data := nil;
  if FHW = nil then
    Exit(NANDIOFailure(nnioRejected, Context + ': no hardware'));
  if (Len = 0) or (QWord(Len) > QWord(High(integer))) then
    Exit(NANDIOFailure(nnioRejected, Context + ': unusable reply length'));

  if FConfig.ReadTransport = sntSplitWriteRead then
  begin
    Result := WriteExact(0, Header, Context + ' command');
    if not Result.Success then Exit;
    SetLength(Data, Len);
    FillByte(Data[0], Len, $FF);
    try
      N := FHW.SPIRead(1, Len, Data);
    except
      on E: Exception do
      begin
        Data := nil;
        Exit(NANDIOFailure(nnioTransport, Context + ': ' + E.Message));
      end;
    end;
  end
  else
  begin
    SetLength(Data, Len);
    FillByte(Data[0], Len, $FF);
    try
      N := FHW.SPIWriteRead(1, Length(Header), Header, Len, Data);
    except
      on E: Exception do
      begin
        Data := nil;
        Exit(NANDIOFailure(nnioTransport, Context + ': ' + E.Message));
      end;
    end;
  end;

  if N <> integer(Len) then
  begin
    Data := nil;
    Exit(NANDIOFailure(nnioTransport,
      Format('%s: received %d of %d bytes', [Context, N, Len])));
  end;
  Result := NANDIOSuccess;
end;

function TSPINANDDevice.GetFeature(Reg: byte; out Value: byte): TNANDIOResult;
var
  Header, Reply: TBytes;
begin
  Value := $FF;
  SetLength(Header, 2);
  Header[0] := $0F;
  Header[1] := Reg;
  Result := Exchange(Header, 1, Reply, Format('get feature %.2x', [Reg]));
  if Result.Success then Value := Reply[0];
end;

function TSPINANDDevice.SetFeature(Reg, Value: byte): TNANDIOResult;
var
  Command: TBytes;
begin
  SetLength(Command, 3);
  Command[0] := $1F;
  Command[1] := Reg;
  Command[2] := Value;
  Result := WriteExact(1, Command, Format('set feature %.2x', [Reg]));
end;

function TSPINANDDevice.WaitReady(TimeoutMs: cardinal; const Context: string;
  out Status: byte): TNANDIOResult;
var
  Deadline: QWord;
begin
  Status := $FF;
  Deadline := GetTickCount64 + QWord(TimeoutMs);
  repeat
    Result := GetFeature(NAND_FEAT_STATUS, Status);
    if not Result.Success then Exit;
    //FF ล้วนคือบัสที่ไม่มีใครขับ: OIP=1, WEL=1, ทุก fail bit ติด พร้อมกัน
    //ไม่มีชิปจริงตัวไหนตอบแบบนี้ ตัดเป็นบัสเงียบทันที ไม่รอครบ timeout
    if Status = $FF then
      Exit(NANDIOFailure(nnioTransport,
        Context + ': the status bus reads FF; no chip is answering'));
    if (Status and NAND_STATUS_OIP) = 0 then Exit(NANDIOSuccess);
    if GetTickCount64 >= Deadline then
      Exit(NANDIOFailure(nnioTimeout,
        Format('%s: still busy after %d ms', [Context, TimeoutMs])));
    if FConfig.PollDelayMs > 0 then Sleep(FConfig.PollDelayMs);
  until False;
end;

function TSPINANDDevice.WriteEnableChecked: TNANDIOResult;
var
  Command: TBytes;
  Status: byte;
begin
  SetLength(Command, 1);
  Command[0] := $06;
  Result := WriteExact(1, Command, 'write enable');
  if not Result.Success then Exit;
  //ชิปที่ WP# ค้างต่ำรับ 06h แล้วเมินเฉย อ่าน WEL กลับมาดูก่อนจะเชื่อ
  Result := GetFeature(NAND_FEAT_STATUS, Status);
  if not Result.Success then Exit;
  if Status = $FF then
    Exit(NANDIOFailure(nnioTransport,
      'write enable: the status bus reads FF; no chip is answering'));
  if (Status and NAND_STATUS_WEL) = 0 then
    Exit(NANDIOFailure(nnioRejected,
      'the chip did not accept write enable (WP# held low, or protected)'));
end;

function TSPINANDDevice.RowAddress(Block, Page: cardinal): cardinal;
begin
  Result := Block * FGeometry.PagesPerBlock + Page;
end;

function TSPINANDDevice.ECCVerdict(Status: byte): TNANDECCStatus;
begin
  //บิต 5:4 ของ C0h: 00 ไม่มีอะไร, 01 แก้แล้ว, 10 แก้ไม่ได้, 11 แก้แล้ว
  //แต่จำนวนบิตถึงเกณฑ์เตือน (GD5F) ซึ่งข้อมูลยังถูก จึงนับเป็น corrected
  case (Status and NAND_STATUS_ECC) shr 4 of
    0: Result := neccGood;
    2: Result := neccUncorrectable;
  else
    Result := neccCorrected;
  end;
end;

function TSPINANDDevice.Reset: TNANDIOResult;
var
  Command: TBytes;
  Status: byte;
begin
  SetLength(Command, 1);
  Command[0] := $FF;
  Result := WriteExact(1, Command, 'reset');
  if not Result.Success then Exit;
  Result := WaitReady(FConfig.ResetTimeoutMs, 'reset', Status);
end;

function TSPINANDDevice.ReadRawID(out Raw: TBytes): TNANDIOResult;
var
  Header: TBytes;
begin
  SetLength(Header, 1);
  Header[0] := $9F;
  //สี่ไบต์พอสำหรับทั้งทรง [dummy][mfr][dev][dev] และ [mfr][dev][dev]
  Result := Exchange(Header, 4, Raw, 'read id');
end;

function TSPINANDDevice.ReadONFIParameterPages(
  const Access: TSPINANDParameterPageAccess;
  out Raw: TBytes): TNANDIOResult;
var
  Before, Wanted, AfterRestore, Active: byte;
  Block, Page: cardinal;
  ReadLength: QWord;
  ECC: TNANDECCStatus;
  RestoreIO: TNANDIOResult;
  PrimaryError: string;
begin
  Raw := nil;
  if not Access.Supported then
    Exit(NANDIOFailure(nnioRejected,
      'this catalog entry has no verified ONFI parameter-page access mode'));
  if Access.CopyCount = 0 then
    Exit(NANDIOFailure(nnioRejected,
      'the ONFI parameter-page copy count is zero'));
  if FGeometry.PagesPerBlock = 0 then
    Exit(NANDIOFailure(nnioRejected, 'the NAND geometry has no pages'));

  Block := Access.RowAddress div FGeometry.PagesPerBlock;
  Page := Access.RowAddress mod FGeometry.PagesPerBlock;
  ReadLength := QWord(Access.CopyCount) * 256;
  if (Block >= FGeometry.BlockCount) or
     (ReadLength > QWord(FGeometry.PageSize) + QWord(FGeometry.SpareSize)) or
     (ReadLength > High(cardinal)) then
    Exit(NANDIOFailure(nnioRejected,
      'the ONFI parameter-page cache range is outside this NAND geometry'));

  Result := GetFeature(NAND_FEAT_CONFIG, Before);
  if not Result.Success then Exit;
  Wanted := (Before or Access.ConfigSetMask) and
            (not Access.ConfigClearMask);

  //Set-feature changes persistent device state until explicitly restored.
  //Once the original byte is known, every path below must attempt cleanup.
  try
    Result := SetFeature(NAND_FEAT_CONFIG, Wanted);
    if not Result.Success then Exit;
    Result := GetFeature(NAND_FEAT_CONFIG, Active);
    if not Result.Success then Exit;
    if ((Active and Access.ConfigSetMask) <> Access.ConfigSetMask) or
       ((Active and Access.ConfigClearMask) <> 0) then
    begin
      Result := NANDIOFailure(nnioRejected, Format(
        'the ONFI parameter-page mode did not stick (B0h reads %.2x)',
        [Active]));
      Exit;
    end;

    Result := ReadPage(Block, Page, 0, cardinal(ReadLength), Raw, ECC);
  finally
    PrimaryError := Result.ErrorText;
    RestoreIO := SetFeature(NAND_FEAT_CONFIG, Before);
    if RestoreIO.Success then
    begin
      RestoreIO := GetFeature(NAND_FEAT_CONFIG, AfterRestore);
      if RestoreIO.Success and (AfterRestore <> Before) then
        RestoreIO := NANDIOFailure(nnioRejected, Format(
          'configuration restore did not stick (wanted %.2x, read %.2x)',
          [Before, AfterRestore]));
    end;
    if not RestoreIO.Success then
    begin
      Raw := nil;
      if PrimaryError <> '' then
        PrimaryError := PrimaryError + '; ';
      Result := NANDIOFailure(RestoreIO.Error,
        PrimaryError + 'restoring B0h after ONFI read failed: ' +
        RestoreIO.ErrorText);
    end;
  end;
end;

function TSPINANDDevice.ReadPage(Block, Page, Offset, Len: cardinal;
  out Data: TBytes; out ECC: TNANDECCStatus): TNANDIOResult;
var
  Command, Header: TBytes;
  Row: cardinal;
  Status: byte;
begin
  Data := nil;
  ECC := neccGood;
  if (Block >= FGeometry.BlockCount) or
     (Page >= FGeometry.PagesPerBlock) or
     (Len = 0) or
     (QWord(Offset) + QWord(Len) >
      QWord(FGeometry.PageSize) + QWord(FGeometry.SpareSize)) then
    Exit(NANDIOFailure(nnioRejected, 'page read outside the chip'));

  Row := RowAddress(Block, Page);
  SetLength(Command, 4);
  Command[0] := $13;
  Command[1] := byte(Row shr 16);
  Command[2] := byte(Row shr 8);
  Command[3] := byte(Row);
  Result := WriteExact(1, Command, 'page-to-cache');
  if not Result.Success then Exit;

  Result := WaitReady(FConfig.ReadTimeoutMs, 'page-to-cache', Status);
  if not Result.Success then Exit;
  ECC := ECCVerdict(Status);

  SetLength(Header, 4);
  Header[0] := $03;
  Header[1] := byte(Offset shr 8);
  Header[2] := byte(Offset);
  Header[3] := $00; //dummy
  Result := Exchange(Header, Len, Data, 'read-from-cache');
end;

function TSPINANDDevice.ProgramPage(Block, Page, Offset: cardinal;
  const Data: TBytes; out ProgramFailed: boolean): TNANDIOResult;
var
  Command: TBytes;
  Row: cardinal;
  Status: byte;
begin
  ProgramFailed := False;
  if (Block >= FGeometry.BlockCount) or
     (Page >= FGeometry.PagesPerBlock) or
     (Length(Data) = 0) or
     (QWord(Offset) + QWord(Length(Data)) >
      QWord(FGeometry.PageSize) + QWord(FGeometry.SpareSize)) then
    Exit(NANDIOFailure(nnioRejected, 'page program outside the chip'));

  Result := WriteEnableChecked;
  if not Result.Success then Exit;

  //02h ล้าง cache เป็น FF ก่อนโหลด ท้ายเพจที่ payload ไม่ถึงจึงคง FF
  //ซึ่งคือสถานะลบอยู่แล้ว ไม่มีไบต์แปลกปลอมไปโดนเขียน
  SetLength(Command, 3 + Length(Data));
  Command[0] := $02;
  Command[1] := byte(Offset shr 8);
  Command[2] := byte(Offset);
  Move(Data[0], Command[3], Length(Data));
  Result := WriteExact(1, Command, 'program load');
  if not Result.Success then Exit;

  Row := RowAddress(Block, Page);
  SetLength(Command, 4);
  Command[0] := $10;
  Command[1] := byte(Row shr 16);
  Command[2] := byte(Row shr 8);
  Command[3] := byte(Row);
  Result := WriteExact(1, Command, 'program execute');
  if not Result.Success then
  begin
    Result.MutationState := nimsPossiblyIssued;
    Exit;
  end;

  Result := WaitReady(FConfig.ProgramTimeoutMs, 'program', Status);
  if not Result.Success then
  begin
    Result.MutationState := nimsPossiblyIssued;
    Exit;
  end;
  ProgramFailed := (Status and NAND_STATUS_P_FAIL) <> 0;
  Result.MutationState := nimsCompletedIdle;
end;

function TSPINANDDevice.EraseBlock(Block: cardinal;
  out EraseFailed: boolean): TNANDIOResult;
var
  Command: TBytes;
  Row: cardinal;
  Status: byte;
begin
  EraseFailed := False;
  if Block >= FGeometry.BlockCount then
    Exit(NANDIOFailure(nnioRejected, 'block erase outside the chip'));

  Result := WriteEnableChecked;
  if not Result.Success then Exit;

  Row := RowAddress(Block, 0);
  SetLength(Command, 4);
  Command[0] := $D8;
  Command[1] := byte(Row shr 16);
  Command[2] := byte(Row shr 8);
  Command[3] := byte(Row);
  Result := WriteExact(1, Command, 'block erase');
  if not Result.Success then
  begin
    Result.MutationState := nimsPossiblyIssued;
    Exit;
  end;

  Result := WaitReady(FConfig.EraseTimeoutMs, 'erase', Status);
  if not Result.Success then
  begin
    Result.MutationState := nimsPossiblyIssued;
    Exit;
  end;
  EraseFailed := (Status and NAND_STATUS_E_FAIL) <> 0;
  Result.MutationState := nimsCompletedIdle;
end;

function TSPINANDDevice.SetECC(Enabled: boolean): TNANDIOResult;
var
  Value, After: byte;
begin
  //อ่าน-แก้-เขียน: B0h มีบิตอื่นอยู่ด้วย (BUF ของ Winbond เป็นต้น)
  //และเขียนแล้วต้องอ่านกลับ บิตที่ไม่ยอมติดคือคำตอบ ไม่ใช่รายละเอียด
  Result := GetFeature(NAND_FEAT_CONFIG, Value);
  if not Result.Success then Exit;
  if Enabled then Value := Value or NAND_CONFIG_ECC_E
  else Value := Value and (not NAND_CONFIG_ECC_E);
  Result := SetFeature(NAND_FEAT_CONFIG, Value);
  if not Result.Success then Exit;
  Result := GetFeature(NAND_FEAT_CONFIG, After);
  if not Result.Success then Exit;
  if ((After and NAND_CONFIG_ECC_E) <> 0) <> Enabled then
    Exit(NANDIOFailure(nnioRejected,
      'the ECC enable bit did not stick in the configuration register'));
end;

function TSPINANDDevice.GetECC(out Enabled: boolean): TNANDIOResult;
var
  Value: byte;
begin
  Result := GetFeature(NAND_FEAT_CONFIG, Value);
  Enabled := Result.Success and ((Value and NAND_CONFIG_ECC_E) <> 0);
end;

function TSPINANDDevice.GetProtection(out Value: byte): TNANDIOResult;
begin
  Result := GetFeature(NAND_FEAT_PROTECTION, Value);
end;

function TSPINANDDevice.SetProtection(Value: byte): TNANDIOResult;
begin
  Result := SetFeature(NAND_FEAT_PROTECTION, Value);
end;

function TSPINANDDevice.GetConfiguration(out Value: byte): TNANDIOResult;
begin
  Result := GetFeature(NAND_FEAT_CONFIG, Value);
end;

function TSPINANDDevice.SetConfiguration(Value: byte): TNANDIOResult;
begin
  Result := SetFeature(NAND_FEAT_CONFIG, Value);
end;

function TSPINANDDevice.EnsureIdle: TNANDIOResult;
var
  Deadline: QWord;
  Status: byte;
  LastError: string;
begin
  //Unlike the normal operation poll, cleanup must tolerate a transient
  //transport failure: keep trying inside one strict deadline. Success still
  //requires an actual non-FF status sample with OIP observed clear.
  Deadline := GetTickCount64 + QWord(FConfig.DrainTimeoutMs);
  LastError := '';
  repeat
    Result := GetFeature(NAND_FEAT_STATUS, Status);
    if Result.Success then
    begin
      if Status = $FF then
        LastError := 'the status bus reads FF; no chip is answering'
      else if (Status and NAND_STATUS_OIP) = 0 then
        Exit(NANDIOSuccess)
      else
        LastError := 'OIP remains set';
    end
    else
      LastError := Result.ErrorText;

    if GetTickCount64 >= Deadline then
      Exit(NANDIOFailure(nnioTimeout, Format(
        'mutation drain could not prove idle after %d ms: %s',
        [FConfig.DrainTimeoutMs, LastError])));
    if FConfig.PollDelayMs > 0 then Sleep(FConfig.PollDelayMs);
  until False;
end;

function TSPINANDDevice.WriteDisable: TNANDIOResult;
var
  Command: TBytes;
  Status: byte;
begin
  SetLength(Command, 1);
  Command[0] := $04;
  Result := WriteExact(1, Command, 'write disable');
  if not Result.Success then Exit;
  Result := GetFeature(NAND_FEAT_STATUS, Status);
  if not Result.Success then Exit;
  if Status = $FF then
    Exit(NANDIOFailure(nnioTransport,
      'write disable: the status bus reads FF; no chip is answering'));
  if (Status and NAND_STATUS_WEL) <> 0 then
    Exit(NANDIOFailure(nnioRejected,
      'write disable did not clear WEL in the status register'));
end;

function TSPINANDDevice.UnlockAll: TNANDIOResult;
var
  After: byte;
begin
  Result := SetFeature(NAND_FEAT_PROTECTION, $00);
  if not Result.Success then Exit;
  Result := GetFeature(NAND_FEAT_PROTECTION, After);
  if not Result.Success then Exit;
  //ทะเบียนอ่านกลับมา FF ล้วนคือบัสเงียบ ไม่ใช่ชิปที่ปลดล็อกแล้ว
  if After = $FF then
    Exit(NANDIOFailure(nnioTransport,
      'the protection register reads FF; no chip is answering'));
  if (After and NAND_PROT_BP_MASK) <> 0 then
    Exit(NANDIOFailure(nnioRejected, Format(
      'the chip kept protection bits set after unlock (A0h reads %.2x); ' +
      'WP# may be held low, or BRWD is set', [After])));
end;

end.
