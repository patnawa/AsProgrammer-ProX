unit writeadmission;

// Whether this image can be written to this chip at this address, and if not,
// the one sentence that says why.
//
// The rule lived inside the GUI's workflow-strip painter, which meant the
// command line had its own separate answer to the same question. Two answers
// to "does this fit" is one answer too many: the GUI would grey out a button
// while the CLI accepted the job, or the reverse, and which one was right
// depended on which file somebody had edited more recently.
//
// It is also the check that decides whether a write runs off the end of a
// part. Getting it wrong does not produce an error; it produces a write that
// stops partway with the chip half-programmed, which is discovered at verify
// if verify is on at all.
//
// So it is one function, here, with no UI and no hardware, and both front ends
// ask it.
//
// The reason strings are ordered deliberately. An operator with three things
// wrong wants the first one to fix, not a list, and the order runs from "you
// have not started yet" to "you are nearly there".

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

type
  TWriteProtocol = (
    wpSPI25,        // 25-series SPI NOR
    wpSPIOther,     // 45/95-series and the KB variants
    wpI2C,          // 24-series EEPROM
    wpMicrowire     // 93-series, word addressed
  );

  TWriteTarget = record
    Protocol: TWriteProtocol;

    BufferSize: QWord;
    ChipSize: QWord;
    ChipSizeKnown: boolean;

    StartAddress: QWord;
    // False when the address box did not parse at all, which is different
    // from an address that parsed and is out of range.
    StartAddressValid: boolean;

    PageSize: QWord;
    PageSizeValid: boolean;

    // Established facts about the session, supplied by the caller.
    ProgrammerPresent: boolean;
    ChipSelected: boolean;
    // The chip answered on the bus, as opposed to being picked from a menu.
    ChipIdentityProven: boolean;
    SmartWriteSupported: boolean;
  end;

  TWriteAdmission = record
    HasBuffer: boolean;
    FitsChip: boolean;
    Aligned: boolean;
    // True when the page size is usable, including the MicroWire case where
    // the field is not consulted at all.
    PageUsable: boolean;
    // Every gate passed; a plain write may proceed.
    MayWrite: boolean;
    // The same, plus the protocol has a differential writer.
    MaySmartWrite: boolean;
    // Empty exactly when MaySmartWrite is True.
    Reason: string;
    // True when the only thing missing is a live identity read. Callers may
    // treat this as a warning rather than a refusal, because selecting a
    // chip by name and writing it is a legitimate, if unproven, workflow.
    OnlyIdentityUnproven: boolean;
  end;

// Page sizes outside this range are not a chip anyone makes; they are a typo
// or a parse that silently produced a stray value.
const
  MIN_PAGE_SIZE = 1;
  MAX_PAGE_SIZE = 2048;

function EvaluateWriteAdmission(const T: TWriteTarget): TWriteAdmission;

// True when the protocol addresses words rather than bytes, so the address
// and the length must both be even. 93-series parts are the ones that do.
function ProtocolIsWordAddressed(P: TWriteProtocol): boolean;

// True when the protocol needs a page size from the operator at all.
// MicroWire does not: its handler fixes the page at two bytes itself, so
// demanding a valid page-size box would refuse a job for a field that has no
// effect.
function ProtocolNeedsPageSize(P: TWriteProtocol): boolean;

implementation

function ProtocolIsWordAddressed(P: TWriteProtocol): boolean;
begin
  Result := P = wpMicrowire;
end;

function ProtocolNeedsPageSize(P: TWriteProtocol): boolean;
begin
  Result := P <> wpMicrowire;
end;

function EvaluateWriteAdmission(const T: TWriteTarget): TWriteAdmission;
var
  PageOK: boolean;
begin
  Result.HasBuffer := T.BufferSize > 0;
  Result.FitsChip := False;
  Result.Aligned := True;
  Result.PageUsable := False;
  Result.MayWrite := False;
  Result.MaySmartWrite := False;
  Result.Reason := '';
  Result.OnlyIdentityUnproven := False;

  //The image has to start inside the chip and end inside it too.  Computing
  //the tail as ChipSize - StartAddress rather than StartAddress + BufferSize
  //keeps an enormous buffer from wrapping the addition and reporting a fit.
  Result.FitsChip := T.ChipSizeKnown and T.StartAddressValid and
                     (T.StartAddress < T.ChipSize) and
                     (T.BufferSize <= T.ChipSize - T.StartAddress);

  if ProtocolIsWordAddressed(T.Protocol) then
    Result.Aligned := ((T.StartAddress and 1) = 0) and
                      ((T.BufferSize and 1) = 0);

  PageOK := (not ProtocolNeedsPageSize(T.Protocol)) or
            (T.PageSizeValid and (T.PageSize >= MIN_PAGE_SIZE) and
             (T.PageSize <= MAX_PAGE_SIZE));
  Result.PageUsable := PageOK;

  //Ordered from "you have not started" to "you are nearly there", so the
  //sentence names the next thing to do rather than the worst thing wrong.
  if not T.ProgrammerPresent then
    Result.Reason := 'Connect a programmer first'
  else if not Result.HasBuffer then
    Result.Reason := 'Open an image first'
  else if not T.ChipSelected then
    Result.Reason := 'Select or detect a chip first'
  else if not T.ChipSizeKnown then
    Result.Reason := 'The chip size is not set'
  else if not T.StartAddressValid then
    Result.Reason := 'The start address is not a valid hex number'
  else if not Result.FitsChip then
    Result.Reason := 'The image does not fit the chip from this start address'
  else if not Result.Aligned then
    Result.Reason := 'This chip is word addressed: the start address and the ' +
                     'image length must both be even'
  else if not PageOK then
    Result.Reason := Format('The page size must be a number from %d to %d',
                            [MIN_PAGE_SIZE, MAX_PAGE_SIZE])
  else if not T.ChipIdentityProven then
  begin
    //Last, and softest.  Picking a chip by name and writing it is a real
    //workflow; it is just one nobody has proved yet, so this is the only
    //reason a caller may reasonably choose to downgrade to a warning.
    Result.Reason := 'The chip in the socket has not answered an identity ' +
                     'read yet';
    Result.OnlyIdentityUnproven := True;
  end;

  //Everything above the identity question is a hard gate.
  Result.MayWrite := T.ProgrammerPresent and Result.HasBuffer and
                     T.ChipSelected and T.ChipSizeKnown and
                     T.StartAddressValid and Result.FitsChip and
                     Result.Aligned and PageOK;

  Result.MaySmartWrite := Result.MayWrite and T.SmartWriteSupported;
  if Result.MayWrite and (not T.SmartWriteSupported) then
    Result.Reason := 'Smart write covers SPI NOR, SPI 95, I2C 24 and ' +
                     'MicroWire 93';
  if Result.MaySmartWrite and (not Result.OnlyIdentityUnproven) then
    Result.Reason := '';
end;

end.
