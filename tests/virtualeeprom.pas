unit virtualeeprom;

// An EEPROM that exists only in memory, for driving eepromengine without
// hardware.
//
// It plays the role of adapter-plus-chip.  The adapter contract says a page
// write must be page-aligned and exactly one page long -- a real 24Cxx fed a
// chunk that crosses its page boundary silently wraps inside the page buffer
// and destroys bytes nobody asked it to touch.  The virtual device REJECTS
// such writes instead of reproducing the corruption, which turns any planner
// alignment bug into a loud test failure rather than a quietly wrong image.
//
// Deterministic failure injection: every device call increments CallIndex;
// when CallIndex reaches FailAtCall the call fails with FailError.  A test
// can therefore walk the failure through every single device interaction and
// assert that no injection point ever produces a false success.

{$mode objfpc}{$H+}

interface

uses
  SysUtils, operationmodel, eepromengine;

type
  TVirtualEEPROM = class(TEEPROMDevice)
  public
    Memory: TBytes;
    PageSize: cardinal;

    CallIndex: cardinal;        // increments on every device call
    FailAtCall: cardinal;       // 0 = never inject a failure
    FailError: TEEPROMIOError;

    OpenCount, InitCount, DeinitCount, CloseCount: integer;
    WritePagesDone: integer;
    ReadPagesDone: integer;

    // When True, one bit of the first byte of every written page is flipped
    // after the write settles -- a chip whose cells do not take the data.
    CorruptWrites: boolean;
    // When > 0, reads return this many bytes fewer than asked.
    ShortReadBy: cardinal;
    // When assigned, cancellation is requested from inside the Nth WritePage
    // (counted from 1), modelling a user pressing cancel mid-operation.
    CancelToken: TCancellationToken;
    CancelInWriteNumber: integer;

    constructor Create(AChipSize, APageSize: cardinal; Fill: byte = $FF);

    function Open: TEEPROMIOResult; override;
    function Initialize: TEEPROMIOResult; override;
    function WritePage(Address: QWord;
      const Data: TBytes): TEEPROMIOResult; override;
    function ReadPage(Address: QWord; Len: cardinal;
      out Data: TBytes): TEEPROMIOResult; override;
    function Deinitialize: TEEPROMIOResult; override;
    function Close: TEEPROMIOResult; override;

    // Total device calls a clean run of the given plan performs; used by the
    // fault matrix to know how far FailAtCall has to walk.
    class function CallsForPlan(const Plan: TEEPROMPlan): cardinal;
  private
    function InjectedFailure(out R: TEEPROMIOResult): boolean;
  end;

implementation

constructor TVirtualEEPROM.Create(AChipSize, APageSize: cardinal; Fill: byte);
begin
  inherited Create;
  SetLength(Memory, AChipSize);
  if AChipSize > 0 then FillChar(Memory[0], AChipSize, Fill);
  PageSize := APageSize;
  CallIndex := 0;
  FailAtCall := 0;
  FailError := eioTransport;
  OpenCount := 0;
  InitCount := 0;
  DeinitCount := 0;
  CloseCount := 0;
  WritePagesDone := 0;
  ReadPagesDone := 0;
  CorruptWrites := False;
  ShortReadBy := 0;
  CancelToken := nil;
  CancelInWriteNumber := 0;
end;

function TVirtualEEPROM.InjectedFailure(out R: TEEPROMIOResult): boolean;
begin
  Inc(CallIndex);
  Result := (FailAtCall <> 0) and (CallIndex = FailAtCall);
  if Result then
    R := EEPROMIOFailure(FailError, 'injected failure at device call ' +
                         IntToStr(CallIndex));
end;

function TVirtualEEPROM.Open: TEEPROMIOResult;
begin
  if InjectedFailure(Result) then Exit;
  Inc(OpenCount);
  Result := EEPROMIOSuccess;
end;

function TVirtualEEPROM.Initialize: TEEPROMIOResult;
begin
  if InjectedFailure(Result) then Exit;
  Inc(InitCount);
  Result := EEPROMIOSuccess;
end;

function TVirtualEEPROM.WritePage(Address: QWord;
  const Data: TBytes): TEEPROMIOResult;
begin
  if InjectedFailure(Result) then Exit;

  // The adapter contract: page-aligned, exactly one page, inside the chip.
  // A violation on real silicon would wrap inside the page buffer; here it
  // must fail the test instead.
  if (PageSize = 0) or (Address mod PageSize <> 0) then
    Exit(EEPROMIOFailure(eioRejected,
      'virtual chip: write is not page aligned'));
  if cardinal(Length(Data)) <> PageSize then
    Exit(EEPROMIOFailure(eioRejected,
      'virtual chip: write is not exactly one page'));
  if Address > QWord(Length(Memory)) - PageSize then
    Exit(EEPROMIOFailure(eioRejected,
      'virtual chip: write runs past the end of the chip'));

  Move(Data[0], Memory[SizeInt(Address)], PageSize);
  if CorruptWrites then
    Memory[SizeInt(Address)] := Memory[SizeInt(Address)] xor $01;
  Inc(WritePagesDone);

  if (CancelToken <> nil) and (CancelInWriteNumber > 0) and
     (WritePagesDone = CancelInWriteNumber) then
    CancelToken.RequestCancellation;

  Result := EEPROMIOSuccess(PageSize);
end;

function TVirtualEEPROM.ReadPage(Address: QWord; Len: cardinal;
  out Data: TBytes): TEEPROMIOResult;
var
  Got: cardinal;
begin
  SetLength(Data, 0);
  if InjectedFailure(Result) then Exit;

  if (Len = 0) or (Address > QWord(Length(Memory))) or
     (QWord(Len) > QWord(Length(Memory)) - Address) then
    Exit(EEPROMIOFailure(eioRejected,
      'virtual chip: read is outside the chip'));

  Got := Len;
  if ShortReadBy > 0 then
  begin
    if ShortReadBy >= Got then Got := 0 else Got := Got - ShortReadBy;
  end;
  SetLength(Data, Got);
  if Got > 0 then Move(Memory[SizeInt(Address)], Data[0], Got);
  Inc(ReadPagesDone);
  Result := EEPROMIOSuccess(Got);
end;

function TVirtualEEPROM.Deinitialize: TEEPROMIOResult;
begin
  if InjectedFailure(Result) then Exit;
  Inc(DeinitCount);
  Result := EEPROMIOSuccess;
end;

function TVirtualEEPROM.Close: TEEPROMIOResult;
begin
  if InjectedFailure(Result) then Exit;
  Inc(CloseCount);
  Result := EEPROMIOSuccess;
end;

class function TVirtualEEPROM.CallsForPlan(const Plan: TEEPROMPlan): cardinal;
begin
  // open + initialize + one call per plan step + deinitialize + close
  Result := 2 + cardinal(Length(Plan.Steps)) + 2;
end;

end.
