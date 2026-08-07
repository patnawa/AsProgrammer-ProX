unit simhw;

// A programmer that is not there.
//
// The whole program has been unusable without hardware. That costs three
// things: nobody can evaluate it before buying a CH347, a bug report cannot
// be reproduced without the reporter's chip, and the screenshots in the
// README can only be made by hand at a bench.
//
// The test suites have solved this for themselves several times over --
// virtualspi25, virtualeeprom, virtualspinand, mockhw -- but all of those sit
// above or beside TBaseHardware, so none of them can be *selected* as a
// programmer. This one is a TBaseHardware, so the application above it is
// entirely unchanged: the same detection, the same SFDP parsing, the same
// erase planner, the same admission ladder, driven against a chip that lives
// in an array.
//
// It models the wire, not the engine. Opcodes go in and bytes come out, with
// WEL and WIP behaving as a real part's do, so a bug in this program's
// command framing shows up here exactly as it would on silicon. A simulator
// written at the engine level would agree with the engine by construction and
// prove nothing.
//
// Two things about it are deliberately loud.
//
// It calls itself SIMULATED everywhere -- in the programmer name, in the
// electrical capabilities, and therefore in the rail report, the session
// report and the CLI's JSON. There is no configuration that makes it look
// like real hardware, because a screenshot or a report that came from this
// and does not say so is a false record of work on somebody's board.
//
// And its electrical capabilities are the honest ones for a thing with no
// pins: it reports that it cannot measure anything, exactly as the CH347
// does. It would have been easy to have it report a perfectly measured
// 1.8 V -- it is a simulator, it can say anything -- and that would make
// every electrical check pass while proving nothing about them.

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, basehw, electricalpreflight, signalchar;

const
  // A W25Q64-shaped part: 8 MiB, 256-byte pages, 4K/32K/64K erase, 3-byte
  // addressing, and an SFDP table describing exactly that. Chosen because it
  // is the most common part this program meets, so the simulated path
  // exercises the same code as the usual real one.
  SIM_JEDEC_0 = $EF;
  SIM_JEDEC_1 = $40;
  SIM_JEDEC_2 = $17;
  SIM_CAPACITY = 8 * 1024 * 1024;
  SIM_PAGE_SIZE = 256;

type
  TSimulatedHardware = class(TBaseHardware)
  private
    FMemory: TBytes;
    FSFDP: TBytes;
    FOpened: boolean;
    FInitialized: boolean;

    // Status registers, as a real part keeps them.
    FSR1: byte;              // bit 0 WIP, bit 1 WEL, bits 4:2 BP
    FSR2: byte;
    FSR3: byte;

    // The command latched by an SPIWrite with CS held low, waiting for its
    // data phase. This is the only state that makes the two-call framing in
    // spi25 work, and modelling it is the point: a backend that answered
    // each call independently would accept command sequences no chip does.
    FPending: TBytes;
    FPendingValid: boolean;

    // The bytes the next SPIRead will serve.
    FReply: TBytes;
    FReplyPos: integer;

    procedure BuildSFDP;
    procedure ClearPending;
    function AddressOf(const Cmd: TBytes; Offset: integer;
      Bytes: integer): QWord;
    // Runs a complete command: the latched header plus this data phase.
    function Execute(const Cmd: TBytes; const Data: TBytes;
      DataLen: integer): boolean;
    procedure PrepareReply(const Cmd: TBytes);
    procedure EraseRange(Address, Size: QWord);
  public
    constructor Create;
    destructor Destroy; override;

    function GetLastError: string; override;
    function DevOpen: boolean; override;
    procedure DevClose; override;

    function SPIInit(speed: integer): boolean; override;
    procedure SPIDeinit; override;
    function SPIRead(CS: byte; BufferLen: integer;
      var buffer: array of byte): integer; override;
    function SPIWrite(CS: byte; BufferLen: integer;
      buffer: array of byte): integer; override;
    function SPIMaxTransfer: integer; override;

    function GetElectricalCapabilities(
      out Capabilities: TProgrammerElectricalCapabilities): boolean; override;
    function GetElectricalObservation(
      out Observation: TElectricalObservation): boolean; override;

    procedure I2CInit; override;
    procedure I2CDeinit; override;
    function I2CReadWrite(DevAddr: byte;
      WBufferLen: integer; WBuffer: array of byte;
      RBufferLen: integer; var RBuffer: array of byte): integer; override;
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

    // Test and diagnostic access to the simulated die. Not used by the
    // application, which must reach the memory only through opcodes.
    function PeekByte(Address: QWord): byte;
    procedure PokeByte(Address: QWord; Value: byte);
  end;

implementation

const
  // The opcodes this simulator answers. Anything else is ignored the way a
  // real part ignores an opcode it does not implement: silently, returning
  // FF, which is exactly the behaviour that makes a wrong opcode hard to
  // notice and therefore worth reproducing.
  OP_WRSR    = $01;
  OP_PP      = $02;
  OP_READ    = $03;
  OP_WRDI    = $04;
  OP_RDSR1   = $05;
  OP_WREN    = $06;
  OP_FASTRD  = $0B;
  OP_SE4K    = $20;
  OP_RDSR3   = $15;
  OP_RDSR2   = $35;
  OP_BE32K   = $52;
  OP_SFDP    = $5A;
  OP_CE_60   = $60;
  OP_CE_C7   = $C7;
  OP_BE64K   = $D8;
  OP_RDID_9F = $9F;
  OP_RDID_90 = $90;
  OP_RDID_AB = $AB;

  SR1_WIP = $01;
  SR1_WEL = $02;

constructor TSimulatedHardware.Create;
begin
  inherited Create;
  FHardwareID := CHW_SIM;
  //The name reaches the status strip, the log banner, the session report and
  //the CLI's JSON. There is no setting that changes it.
  FHardwareName := 'SIMULATED (no hardware)';
  SetLength(FMemory, SIM_CAPACITY);
  //A fresh part is erased, which is what an unprogrammed die actually holds
  //and what makes an accidental "read before write" obviously empty rather
  //than plausibly full of zeroes.
  FillByte(FMemory[0], SIM_CAPACITY, $FF);
  BuildSFDP;
  ClearPending;
end;

destructor TSimulatedHardware.Destroy;
begin
  SetLength(FMemory, 0);
  SetLength(FSFDP, 0);
  inherited Destroy;
end;

// A real JESD216 rev 1.6 basic parameter table for the part above.
//
// Written out as words rather than a byte blob so that each field is legible
// and can be corrected. A simulator whose SFDP is a hex dump nobody can read
// is a simulator whose SFDP nobody will fix when the parser changes.
procedure TSimulatedHardware.BuildSFDP;
var
  TablePtr: cardinal;

  procedure PutDword(Offset: cardinal; Value: cardinal);
  begin
    FSFDP[Offset + 0] := Value and $FF;
    FSFDP[Offset + 1] := (Value shr 8) and $FF;
    FSFDP[Offset + 2] := (Value shr 16) and $FF;
    FSFDP[Offset + 3] := (Value shr 24) and $FF;
  end;

begin
  SetLength(FSFDP, 256);
  FillByte(FSFDP[0], 256, $FF);
  TablePtr := $30;

  //Header: 'SFDP', minor 6, major 1, one parameter header.
  FSFDP[0] := Ord('S'); FSFDP[1] := Ord('F');
  FSFDP[2] := Ord('D'); FSFDP[3] := Ord('P');
  FSFDP[4] := $06;
  FSFDP[5] := $01;
  FSFDP[6] := $00;          //NPH is the count minus one
  FSFDP[7] := $FF;

  //Parameter header for the basic table: id 00h/FFh, 20 dwords, at TablePtr.
  FSFDP[8] := $00;
  FSFDP[9] := $06;
  FSFDP[10] := $01;
  FSFDP[11] := 20;
  FSFDP[12] := TablePtr and $FF;
  FSFDP[13] := (TablePtr shr 8) and $FF;
  FSFDP[14] := (TablePtr shr 16) and $FF;
  FSFDP[15] := $FF;

  //DWORD-1: 4K erase with 20h, three-byte addressing, and both quad read
  //modes declared (bits 21 and 22).
  PutDword(TablePtr + 0, $00602001);
  //DWORD-2: density in bits, minus one.
  PutDword(TablePtr + 4, SIM_CAPACITY * 8 - 1);
  //DWORD-3: (1-4-4) EBh with 6 dummy cycles, (1-1-4) 6Bh with 8.
  PutDword(TablePtr + 8, $6B08EB06);
  //DWORD-8: erase type 1 = 2^12 with 20h, type 2 = 2^15 with 52h.
  PutDword(TablePtr + 28, $520F200C);
  //DWORD-9: erase type 3 = 2^16 with D8h.
  PutDword(TablePtr + 32, $0000D810);
  //DWORD-11: page size 2^8.
  PutDword(TablePtr + 40, $00000080);
  //DWORD-15: quad enable requirement 1 -- QE is bit 1 of status register 2,
  //read with 35h. Left clear in FSR2, so quadpolicy correctly declines to
  //use a quad read and correctly declines to turn it on.
  PutDword(TablePtr + 56, $00100000);
end;

procedure TSimulatedHardware.ClearPending;
begin
  SetLength(FPending, 0);
  FPendingValid := False;
  SetLength(FReply, 0);
  FReplyPos := 0;
end;

function TSimulatedHardware.GetLastError: string;
begin
  Result := '';
end;

function TSimulatedHardware.DevOpen: boolean;
begin
  FOpened := True;
  ClearPending;
  Result := True;
end;

procedure TSimulatedHardware.DevClose;
begin
  FOpened := False;
  FInitialized := False;
  ClearPending;
end;

function TSimulatedHardware.SPIInit(speed: integer): boolean;
begin
  //Speed is accepted and ignored. A simulator that refused a clock would be
  //asserting something about wiring it cannot have.
  FInitialized := FOpened;
  Result := FInitialized;
end;

procedure TSimulatedHardware.SPIDeinit;
begin
  FInitialized := False;
  ClearPending;
end;

function TSimulatedHardware.SPIMaxTransfer: integer;
begin
  //The CH347's figure, so that a caller's chunking behaviour against the
  //simulator is the behaviour it will have against real hardware.
  Result := 4096;
end;

function TSimulatedHardware.AddressOf(const Cmd: TBytes; Offset: integer;
  Bytes: integer): QWord;
var
  i: integer;
begin
  Result := 0;
  for i := 0 to Bytes - 1 do
  begin
    if Offset + i > High(Cmd) then Exit(High(QWord));
    Result := (Result shl 8) or Cmd[Offset + i];
  end;
end;

procedure TSimulatedHardware.EraseRange(Address, Size: QWord);
var
  First: QWord;
begin
  if Size = 0 then Exit;
  //Aligned down, as the chip does: an erase opcode carrying an address in the
  //middle of a sector erases the whole sector. Modelling that is important,
  //because a planner bug that produces unaligned addresses would otherwise
  //look correct here and destroy a neighbouring sector on silicon.
  First := (Address div Size) * Size;
  if First >= SIM_CAPACITY then Exit;
  if First + Size > SIM_CAPACITY then Size := SIM_CAPACITY - First;
  FillByte(FMemory[First], Size, $FF);
end;

// Prepares the bytes an SPIRead will serve for a latched command.
procedure TSimulatedHardware.PrepareReply(const Cmd: TBytes);
var
  Addr: QWord;
  i: integer;
begin
  SetLength(FReply, 0);
  FReplyPos := 0;
  if Length(Cmd) < 1 then Exit;

  case Cmd[0] of
    OP_RDID_9F:
      begin
        SetLength(FReply, 3);
        FReply[0] := SIM_JEDEC_0;
        FReply[1] := SIM_JEDEC_1;
        FReply[2] := SIM_JEDEC_2;
      end;
    OP_RDID_90, OP_RDID_AB:
      begin
        SetLength(FReply, 2);
        FReply[0] := SIM_JEDEC_0;
        FReply[1] := SIM_JEDEC_2;
      end;
    OP_RDSR1:
      begin
        SetLength(FReply, 1);
        FReply[0] := FSR1;
      end;
    OP_RDSR2:
      begin
        SetLength(FReply, 1);
        FReply[0] := FSR2;
      end;
    OP_RDSR3:
      begin
        SetLength(FReply, 1);
        FReply[0] := FSR3;
      end;
    OP_SFDP:
      begin
        //Three address bytes then one dummy byte, per JESD216.
        Addr := AddressOf(Cmd, 1, 3);
        SetLength(FReply, Length(FSFDP));
        for i := 0 to High(FReply) do
          if Addr + QWord(i) <= QWord(High(FSFDP)) then
            FReply[i] := FSFDP[Addr + QWord(i)]
          else
            FReply[i] := $FF;
      end;
    OP_READ, OP_FASTRD:
      begin
        Addr := AddressOf(Cmd, 1, 3);
        //A read that runs off the end of the die returns FF rather than
        //wrapping. Wrapping is what some real parts do, but reproducing it
        //would hide a caller's arithmetic error behind plausible data.
        SetLength(FReply, SIM_CAPACITY);
        for i := 0 to High(FReply) do
          if Addr + QWord(i) < SIM_CAPACITY then
            FReply[i] := FMemory[Addr + QWord(i)]
          else
            FReply[i] := $FF;
      end;
  end;
end;

function TSimulatedHardware.Execute(const Cmd: TBytes; const Data: TBytes;
  DataLen: integer): boolean;
var
  Addr, PageBase, Offset, Target: QWord;
  i: integer;
begin
  Result := True;
  if Length(Cmd) < 1 then Exit(False);

  case Cmd[0] of
    OP_WREN: FSR1 := FSR1 or SR1_WEL;
    OP_WRDI: FSR1 := FSR1 and (not SR1_WEL);

    OP_WRSR:
      begin
        //Silently ignored without WEL, exactly as a real part does. That
        //silence is the behaviour worth reproducing: it is why this program
        //verifies a status-register write by reading it back rather than
        //trusting that no error came out.
        if (FSR1 and SR1_WEL) = 0 then Exit;
        if Length(Cmd) >= 2 then FSR1 := Cmd[1]
        else if DataLen >= 1 then FSR1 := Data[0];
        if Length(Cmd) >= 3 then FSR2 := Cmd[2]
        else if DataLen >= 2 then FSR2 := Data[1];
        FSR1 := FSR1 and (not SR1_WEL);
      end;

    OP_PP:
      begin
        if (FSR1 and SR1_WEL) = 0 then Exit;
        Addr := AddressOf(Cmd, 1, 3);
        if Addr >= SIM_CAPACITY then Exit;
        PageBase := (Addr div SIM_PAGE_SIZE) * SIM_PAGE_SIZE;
        Offset := Addr - PageBase;
        for i := 0 to DataLen - 1 do
        begin
          //The page-buffer wrap a real 25-series part performs: a program
          //that runs past the end of its page comes back to the start of the
          //same page rather than continuing into the next. Reproducing it is
          //the point -- a caller that ignores page boundaries corrupts the
          //head of the page it is writing, and nothing else reports that.
          Target := PageBase + ((Offset + QWord(i)) mod SIM_PAGE_SIZE);
          if Target < SIM_CAPACITY then
            //Programming only clears bits, as flash does. A byte that was
            //not erased first cannot be set back to one, which is exactly
            //the failure a missing erase produces on silicon.
            FMemory[Target] := FMemory[Target] and Data[i];
        end;
        FSR1 := FSR1 and (not SR1_WEL);
      end;

    OP_SE4K:
      begin
        if (FSR1 and SR1_WEL) = 0 then Exit;
        EraseRange(AddressOf(Cmd, 1, 3), 4096);
        FSR1 := FSR1 and (not SR1_WEL);
      end;
    OP_BE32K:
      begin
        if (FSR1 and SR1_WEL) = 0 then Exit;
        EraseRange(AddressOf(Cmd, 1, 3), 32768);
        FSR1 := FSR1 and (not SR1_WEL);
      end;
    OP_BE64K:
      begin
        if (FSR1 and SR1_WEL) = 0 then Exit;
        EraseRange(AddressOf(Cmd, 1, 3), 65536);
        FSR1 := FSR1 and (not SR1_WEL);
      end;
    OP_CE_60, OP_CE_C7:
      begin
        if (FSR1 and SR1_WEL) = 0 then Exit;
        FillByte(FMemory[0], SIM_CAPACITY, $FF);
        FSR1 := FSR1 and (not SR1_WEL);
      end;
  end;
end;

function TSimulatedHardware.SPIWrite(CS: byte; BufferLen: integer;
  buffer: array of byte): integer;
var
  Data: TBytes;
  i: integer;
begin
  Result := -1;
  if (not FOpened) or (BufferLen < 0) or (BufferLen > Length(buffer)) then Exit;

  //A data phase for a command latched by a previous CS=0 write. This is the
  //shape spi25 uses for a page program: the header goes out with CS held
  //low, then the payload with CS released.
  if FPendingValid and (CS = 1) then
  begin
    SetLength(Data, BufferLen);
    for i := 0 to BufferLen - 1 do Data[i] := buffer[i];
    Execute(FPending, Data, BufferLen);
    ClearPending;
    Exit(BufferLen);
  end;

  SetLength(FPending, BufferLen);
  for i := 0 to BufferLen - 1 do FPending[i] := buffer[i];

  if CS = 0 then
  begin
    //Held low: something follows. Prepare a reply in case it is a read, and
    //keep the header in case it is a program.
    FPendingValid := True;
    PrepareReply(FPending);
  end
  else
  begin
    //Released: a complete command in one transfer.
    SetLength(Data, 0);
    Execute(FPending, Data, 0);
    ClearPending;
  end;
  Result := BufferLen;
end;

function TSimulatedHardware.SPIRead(CS: byte; BufferLen: integer;
  var buffer: array of byte): integer;
var
  i: integer;
begin
  Result := -1;
  if (not FOpened) or (BufferLen < 0) or (BufferLen > Length(buffer)) then Exit;

  for i := 0 to BufferLen - 1 do
    if FReplyPos + i <= High(FReply) then
      buffer[i] := FReply[FReplyPos + i]
    else
      //Past the end of what this command can answer, the bus floats. FF is
      //what a real one reads back, and it is the value this program is
      //careful never to mistake for data.
      buffer[i] := $FF;

  Inc(FReplyPos, BufferLen);
  if CS = 1 then ClearPending;
  Result := BufferLen;
end;

// --------------------------------------------------------- electrical
//
// The honest capabilities for a thing with no pins.
//
// It would have been easy to report a perfectly measured 1.8 V here. It is a
// simulator; it can say anything. And that is exactly why it must not: every
// electrical check would pass, the rail report would show numbers, and none
// of it would prove anything about the code those numbers flow through. So
// the simulator reports what the CH347 reports -- that it cannot measure --
// and the same "not measurable on this programmer" lines come out.

function TSimulatedHardware.GetElectricalCapabilities(
  out Capabilities: TProgrammerElectricalCapabilities): boolean;
var
  P: TSerialProtocol;
begin
  FillChar(Capabilities, SizeOf(Capabilities), 0);
  Capabilities.Known := True;
  //Deliberately unmistakable. This string reaches the rail report, the
  //session report and the CLI's JSON, and no setting changes it: a record of
  //work that came from here and does not say so is a false record.
  Capabilities.ProgrammerID := 'SIMULATED';
  Capabilities.FirmwareVersion := 'none';
  Capabilities.SupportedProtocols := [spSPI];

  //There are no pins to be unsafe.
  Capabilities.PinsSafeAtOpen := True;
  Capabilities.SupportsOpenDrain := False;

  //A simulated part is a 3.3 V part, matching the JEDEC id it answers with.
  Capabilities.PowerCapability := pcFixedTargetPower;
  Capabilities.FixedTargetMv := 3300;
  Capabilities.CanSetVio := False;
  Capabilities.FixedVioMv := 3300;
  //Asked of signalchar like every other backend, so the simulator cannot
  //become the one programmer that claims a verified signal level.
  ApplyMeasuredSignalLevel(Capabilities.ProgrammerID,
                           Capabilities.FixedVioMv, Capabilities);

  Capabilities.CanDetectExternalPower := False;
  Capabilities.CanMeasureTargetVoltage := False;
  Capabilities.CanMeasureTargetCurrent := False;
  Capabilities.HasCurrentLimit := False;

  for P := Low(TSerialProtocol) to High(TSerialProtocol) do
    Capabilities.MaxBusHz[P] := 0;
  Capabilities.MaxBusHz[spSPI] := 60000000;

  Result := True;
end;

function TSimulatedHardware.GetElectricalObservation(
  out Observation: TElectricalObservation): boolean;
begin
  FillChar(Observation, SizeOf(Observation), 0);
  if not FOpened then Exit(False);

  Observation.TargetPowerEnabled := True;
  Observation.SelectedTargetMv := 3300;
  Observation.SelectedProgrammerVioMv := 3300;
  ApplyObservedSignalLevel('SIMULATED', 3300, Observation);

  Observation.ExternalPowerKnown := False;
  Observation.TargetVoltageMeasured := False;
  Observation.TargetCurrentMeasured := False;
  Observation.CurrentLimitEnabled := False;

  Result := True;
end;

// ------------------------------------------------- protocols it does not do
//
// I2C and MicroWire are not simulated. Returning failure is the correct
// answer and matches GetMemoryCapabilities, which lists SPI only: a caller
// that asks is asking for something this backend does not offer, and a stub
// that silently succeeded would let an EEPROM operation appear to work.

procedure TSimulatedHardware.I2CInit;
begin
end;

procedure TSimulatedHardware.I2CDeinit;
begin
end;

function TSimulatedHardware.I2CReadWrite(DevAddr: byte;
  WBufferLen: integer; WBuffer: array of byte;
  RBufferLen: integer; var RBuffer: array of byte): integer;
begin
  Result := -1;
end;

procedure TSimulatedHardware.I2CStart;
begin
end;

procedure TSimulatedHardware.I2CStop;
begin
end;

function TSimulatedHardware.I2CReadByte(ack: boolean): byte;
begin
  Result := $FF;
end;

function TSimulatedHardware.I2CWriteByte(data: byte): boolean;
begin
  Result := False;
end;

function TSimulatedHardware.MWInit(speed: integer): boolean;
begin
  Result := False;
end;

procedure TSimulatedHardware.MWDeinit;
begin
end;

function TSimulatedHardware.MWRead(CS: byte; BufferLen: integer;
  var buffer: array of byte): integer;
begin
  Result := -1;
end;

function TSimulatedHardware.MWWrite(CS: byte; BitsWrite: byte;
  buffer: array of byte): integer;
begin
  Result := -1;
end;

function TSimulatedHardware.MWIsBusy: boolean;
begin
  Result := False;
end;

function TSimulatedHardware.PeekByte(Address: QWord): byte;
begin
  if Address >= SIM_CAPACITY then Exit($FF);
  Result := FMemory[Address];
end;

procedure TSimulatedHardware.PokeByte(Address: QWord; Value: byte);
begin
  if Address >= SIM_CAPACITY then Exit;
  FMemory[Address] := Value;
end;

end.
