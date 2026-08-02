unit nandengine;

// Executor for TNANDPlan: the piece that turns a validated plan into device
// calls, and the only piece allowed to talk to a NAND device.
//
// What it enforces, in the order it matters:
//
//   - The bad-block scan runs with on-die ECC off, reading the factory
//     marker byte raw. An erased page has no valid ECC codeword, and some
//     parts (GD5F) flag that as an ECC failure, which would make a factory
//     fresh chip look completely bad. ECC is restored afterwards.
//   - Reads of main-only images run with ECC on, and the ECC status is
//     checked after every page. Corrected pages are counted and reported;
//     an uncorrectable page fails the whole read naming the block and page,
//     because returning plausible garbage is the worst outcome a dump can
//     have. Raw reads (main+spare) run with ECC off: the point of a raw
//     image is the bytes as stored, parity included.
//   - Programming unlocks the chip first and reads the protection register
//     back. A protected NAND accepts program/erase and does nothing, which
//     otherwise surfaces as a verify error a full chip later.
//   - Every erase checks E_FAIL and every program checks P_FAIL. Those are
//     the chip's own word that the operation failed even though BUSY
//     cleared normally.
//   - After programming, every written page is read back and compared,
//     unless the caller explicitly turns that off.
//
// The engine follows the plan exactly; it never chooses blocks itself.
// Planning (and the guarantee that no bad block is ever touched) lives in
// nandplanner, validated independently by ValidateNANDPlan.

{$mode objfpc}{$H+}

interface

uses
  SysUtils, nandmodel, nandplanner;

type
  TNANDIOError = (
    nnioNone,
    nnioTransport,     //the transfer itself failed or was short
    nnioTimeout,       //BUSY never cleared inside the ceiling
    nnioRejected       //the device refused the request (bad arguments)
  );

  //Array-command disposition at the hardware boundary. A transport error
  //while clocking 10h/D8h cannot prove that the chip did not receive it.
  TNANDIOMutationState = (
    nimsNone,
    nimsPossiblyIssued,
    nimsCompletedIdle
  );

  TNANDIOResult = record
    Success: boolean;
    Error: TNANDIOError;
    ErrorText: string;
    MutationState: TNANDIOMutationState;
  end;

  TNANDECCStatus = (
    neccGood,          //no bit errors
    neccCorrected,     //bit errors existed and the chip fixed them
    neccUncorrectable  //the data returned is not trustworthy
  );

  //Stable outcome codes for callers that must not parse translated/log text.
  TNANDRunErrorCode = (
    nreNone,
    nreInvalidRequest,
    nreInvalidPlan,
    nreTransport,
    nreTimeout,
    nreRejected,
    nreProtection,
    nreEraseFailed,
    nreProgramFailed,
    nreUncorrectableECC,
    nreVerifyMismatch,
    nreCleanupFailed,
    nreUnknownBusy,
    nreCancelled
  );

  TNANDRunDisposition = (
    nrdNoArrayMutation,
    nrdArrayIdle,
    nrdArrayBusyUnknown,
    nrdDeviceStateUnknown
  );

  //Hardware adapters and the virtual chip implement this. Methods block
  //until the operation completes (or times out) and return typed results;
  //completion flags (P_FAIL, E_FAIL, ECC) come back explicitly rather than
  //being folded into Success, so the engine can name what went wrong.
  TNANDDevice = class
  public
    //Column-addressed read of one page after loading it into the cache.
    //Offset is the column (0 = first main byte; PageSize = first spare
    //byte). ECC reflects the chip's judgement of this page load.
    function ReadPage(Block, Page, Offset, Len: cardinal; out Data: TBytes;
      out ECC: TNANDECCStatus): TNANDIOResult; virtual; abstract;
    //Program Len bytes at column Offset of the given page, then execute.
    //ProgramFailed is the chip's P_FAIL flag.
    function ProgramPage(Block, Page, Offset: cardinal; const Data: TBytes;
      out ProgramFailed: boolean): TNANDIOResult; virtual; abstract;
    //EraseFailed is the chip's E_FAIL flag.
    function EraseBlock(Block: cardinal; out EraseFailed: boolean):
      TNANDIOResult; virtual; abstract;
    //On-die ECC control (feature register B0 on real parts). Setting must
    //read back the register and fail when the bit did not stick.
    function SetECC(Enabled: boolean): TNANDIOResult; virtual; abstract;
    function GetECC(out Enabled: boolean): TNANDIOResult; virtual; abstract;
    //Raw feature-register access lets a mutation session restore the exact
    //A0h/B0h bytes it inherited, not merely one interpreted bit.
    function GetProtection(out Value: byte): TNANDIOResult; virtual; abstract;
    function SetProtection(Value: byte): TNANDIOResult; virtual; abstract;
    function GetConfiguration(out Value: byte): TNANDIOResult;
      virtual; abstract;
    function SetConfiguration(Value: byte): TNANDIOResult;
      virtual; abstract;
    //Bounded OIP drain. Success means status was observed with OIP clear;
    //failure means callers must treat the array as potentially still busy.
    function EnsureIdle: TNANDIOResult; virtual; abstract;
    //04h plus status readback. Used after every mutation attempt because a
    //failure after WREN/program-load can leave WEL set without OIP ever set.
    function WriteDisable: TNANDIOResult; virtual; abstract;
    //Clear all block protection and read the register back; fails when the
    //chip kept any protection bit set.
    function UnlockAll: TNANDIOResult; virtual; abstract;
  end;

  //Checked between steps; a True return stops the run at the next step
  //boundary. Erase/program of one step is never interrupted midway.
  TNANDShouldStop = function: boolean;

  //Called after each completed step so a UI can move a progress bar.
  TNANDStepDone = procedure(StepsDone, StepsTotal: SizeInt);

  TNANDRunReport = record
    Success: boolean;
    ErrorCode: TNANDRunErrorCode;
    ErrorText: string;
    Disposition: TNANDRunDisposition;
    CleanupFailed: boolean;
    CleanupErrorText: string;
    Cancelled: boolean;
    //Where it failed, when it failed on a specific page.
    FailBlock, FailPage: cardinal;
    HasFailAddress: boolean;
    //Pages whose data the chip had to correct: the dump is fine but the
    //part is aging, and the caller deserves to know.
    CorrectedPages: cardinal;
    //The same, per block (allocated by read runs): a cluster of corrected
    //pages in one block is a block wearing out, not random noise.
    CorrectedPerBlock: array of cardinal;
    StepsDone: SizeInt;
  end;

//Scan every block's factory markers (first spare byte of each of the first
//two pages) into a fresh map. Vendors are allowed to mark either page. ECC is
//turned off for the scan and restored afterwards, even on failure.
function ScanNANDBadBlocks(Device: TNANDDevice;
  const Geometry: TNANDGeometry; out Map: TNANDBlockMap;
  out ErrorText: string): boolean;

//Execute a read plan into Image (sized by the caller to the plan's total
//read bytes). ECC on for main-only layouts, off for raw.
function ExecuteNANDRead(Device: TNANDDevice; const Geometry: TNANDGeometry;
  const Map: TNANDBlockMap; const Plan: TNANDPlan; var Image: TBytes;
  ShouldStop: TNANDShouldStop; StepDone: TNANDStepDone): TNANDRunReport;

//Execute an erase-only plan. Every erased block is read back page by page
//with ECC disabled and every main-area byte must be FF before PASS. A pending
//cancellation is honoured only before the next block, never between its
//erase command and verification.
function ExecuteNANDErase(Device: TNANDDevice;
  const Geometry: TNANDGeometry; const Map: TNANDBlockMap;
  const Plan: TNANDPlan; ShouldStop: TNANDShouldStop;
  StepDone: TNANDStepDone): TNANDRunReport;

//Execute a program plan from Image. Unlocks first, erases and programs per
//the plan, checks E_FAIL/P_FAIL, and reads every programmed page back in
//full. Verify remains in this legacy interface only so old callers fail
//closed when passing False; new code should call ExecuteNANDWrite.
function ExecuteNANDProgram(Device: TNANDDevice;
  const Geometry: TNANDGeometry; const Map: TNANDBlockMap;
  const Plan: TNANDPlan; const Image: TBytes; Verify: boolean;
  ShouldStop: TNANDShouldStop; StepDone: TNANDStepDone): TNANDRunReport;

//Safe phase-3 entry for main-area writes. Verification cannot be disabled.
function ExecuteNANDWrite(Device: TNANDDevice;
  const Geometry: TNANDGeometry; const Map: TNANDBlockMap;
  const Plan: TNANDPlan; const Image: TBytes;
  ShouldStop: TNANDShouldStop; StepDone: TNANDStepDone): TNANDRunReport;

//ตัวช่วยสร้างผลลัพธ์ ให้อะแดปเตอร์กับชิปจำลองใช้ร่วมกัน
function NANDIOSuccess: TNANDIOResult;
function NANDIOFailure(Error: TNANDIOError;
  const ErrorText: string): TNANDIOResult;

implementation

function NANDIOSuccess: TNANDIOResult;
begin
  Result.Success := True;
  Result.Error := nnioNone;
  Result.ErrorText := '';
  Result.MutationState := nimsNone;
end;

function NANDIOFailure(Error: TNANDIOError;
  const ErrorText: string): TNANDIOResult;
begin
  Result.Success := False;
  Result.Error := Error;
  Result.ErrorText := ErrorText;
  Result.MutationState := nimsNone;
end;

function ClearReport: TNANDRunReport;
begin
  Result.Success := False;
  Result.ErrorCode := nreNone;
  Result.ErrorText := '';
  Result.Disposition := nrdNoArrayMutation;
  Result.CleanupFailed := False;
  Result.CleanupErrorText := '';
  Result.Cancelled := False;
  Result.FailBlock := 0;
  Result.FailPage := 0;
  Result.HasFailAddress := False;
  Result.CorrectedPages := 0;
  Result.CorrectedPerBlock := nil;
  Result.StepsDone := 0;
end;

function RunErrorForIO(const IO: TNANDIOResult): TNANDRunErrorCode;
begin
  case IO.Error of
    nnioTimeout:  Result := nreTimeout;
    nnioRejected: Result := nreRejected;
  else
    Result := nreTransport;
  end;
end;

type
  TNANDMutationSession = record
    SnapshotTaken: boolean;
    OriginalProtection: byte;
    OriginalConfiguration: byte;
    ArrayCommandMayHaveIssued: boolean;
    WriteEnableMayBeSet: boolean;
  end;

procedure NoteMutationIO(var Session: TNANDMutationSession;
  const IO: TNANDIOResult);
begin
  if IO.MutationState in [nimsPossiblyIssued, nimsCompletedIdle] then
    Session.ArrayCommandMayHaveIssued := True;
end;

procedure AddCleanupError(var Report: TNANDRunReport; const Text: string);
begin
  Report.CleanupFailed := True;
  if Report.CleanupErrorText <> '' then
    Report.CleanupErrorText := Report.CleanupErrorText + '; ';
  Report.CleanupErrorText := Report.CleanupErrorText + Text;
end;

function CaptureMutationSession(Device: TNANDDevice;
  var Session: TNANDMutationSession; var Report: TNANDRunReport): boolean;
var
  IO: TNANDIOResult;
begin
  FillChar(Session, SizeOf(Session), 0);
  Result := False;
  IO := Device.GetProtection(Session.OriginalProtection);
  if not IO.Success then
  begin
    Report.ErrorCode := RunErrorForIO(IO);
    Report.ErrorText := 'reading the protection register failed: ' +
                        IO.ErrorText;
    Exit;
  end;
  IO := Device.GetConfiguration(Session.OriginalConfiguration);
  if not IO.Success then
  begin
    Report.ErrorCode := RunErrorForIO(IO);
    Report.ErrorText := 'reading the configuration register failed: ' +
                        IO.ErrorText;
    Exit;
  end;
  Session.SnapshotTaken := True;
  Result := True;
end;

procedure FinishMutationSession(Device: TNANDDevice;
  const Session: TNANDMutationSession; var Report: TNANDRunReport);
var
  IO: TNANDIOResult;
  Actual: byte;
  IdleProven: boolean;
begin
  if not Session.SnapshotTaken then Exit;
  IdleProven := True;
  if Session.ArrayCommandMayHaveIssued then
  begin
    IO := Device.EnsureIdle;
    IdleProven := IO.Success;
    if IdleProven then
      Report.Disposition := nrdArrayIdle
    else
    begin
      Report.Disposition := nrdArrayBusyUnknown;
      AddCleanupError(Report,
        'array idle could not be proven after a possibly-issued command: ' +
        IO.ErrorText);
    end;
  end;

  //Feature writes while OIP may still be set are not a cleanup attempt; they
  //are another unbounded ambiguity. Restore only after status proved idle.
  if IdleProven then
  begin
    if Session.WriteEnableMayBeSet then
    begin
      IO := Device.WriteDisable;
      if not IO.Success then
      begin
        Report.Disposition := nrdDeviceStateUnknown;
        AddCleanupError(Report,
          'write-disable cleanup could not prove WEL clear: ' + IO.ErrorText);
      end;
    end;

    IO := Device.SetConfiguration(Session.OriginalConfiguration);
    if not IO.Success then
      AddCleanupError(Report, 'restoring the configuration register failed: ' +
        IO.ErrorText)
    else
    begin
      IO := Device.GetConfiguration(Actual);
      if not IO.Success then
        AddCleanupError(Report,
          'verifying the configuration-register restore failed: ' +
          IO.ErrorText)
      else if Actual <> Session.OriginalConfiguration then
        AddCleanupError(Report, Format(
          'configuration-register restore did not stick (wanted %.2x, read %.2x)',
          [Session.OriginalConfiguration, Actual]));
    end;

    //Always attempt A0 even if B0 cleanup failed. Restoring protection last
    //keeps the chip writable long enough to repair B0 first.
    IO := Device.SetProtection(Session.OriginalProtection);
    if not IO.Success then
      AddCleanupError(Report, 'restoring the protection register failed: ' +
        IO.ErrorText)
    else
    begin
      IO := Device.GetProtection(Actual);
      if not IO.Success then
        AddCleanupError(Report,
          'verifying the protection-register restore failed: ' + IO.ErrorText)
      else if Actual <> Session.OriginalProtection then
        AddCleanupError(Report, Format(
          'protection-register restore did not stick (wanted %.2x, read %.2x)',
          [Session.OriginalProtection, Actual]));
    end;
  end
  else
    AddCleanupError(Report,
      'A0h/B0h restoration was skipped because the array may still be busy');

  if Report.CleanupFailed then
  begin
    Report.Success := False;
    if Report.ErrorCode = nreNone then
      if Report.Disposition = nrdArrayBusyUnknown then
        Report.ErrorCode := nreUnknownBusy
      else
        Report.ErrorCode := nreCleanupFailed;
    if Report.ErrorText = '' then
      Report.ErrorText := 'cleanup failed: ' + Report.CleanupErrorText
    else
      Report.ErrorText := Report.ErrorText + '; cleanup failed: ' +
                          Report.CleanupErrorText;
  end;
end;

function ScanNANDBadBlocks(Device: TNANDDevice;
  const Geometry: TNANDGeometry; out Map: TNANDBlockMap;
  out ErrorText: string): boolean;
var
  Block, Page: cardinal;
  Marker: TBytes;
  ECCWas: boolean;
  ECC: TNANDECCStatus;
  IO, RestoreIO: TNANDIOResult;
begin
  Result := False;
  ErrorText := '';
  Map := NewNANDBlockMap(Geometry);

  if not ValidateNANDGeometry(Geometry, ErrorText) then Exit;
  if Device = nil then
  begin
    ErrorText := 'no device';
    Exit;
  end;

  //จำสถานะ ECC เดิมไว้ก่อนปิด เพจว่างไม่มี codeword ให้ตรวจ บางเจ้า (GD5F)
  //ตีเป็น ECC fail ทั้งที่บล็อกดีสนิท ปิดเสียก่อนแล้วอ่าน marker ดิบ ๆ
  IO := Device.GetECC(ECCWas);
  if not IO.Success then
  begin
    ErrorText := 'reading the ECC state failed: ' + IO.ErrorText;
    Exit;
  end;
  IO := Device.SetECC(False);
  if not IO.Success then
  begin
    ErrorText := 'disabling ECC for the scan failed: ' + IO.ErrorText;
    Exit;
  end;

  try
    for Block := 0 to Geometry.BlockCount - 1 do
    begin
      Map[Block] := nbsGood;
      for Page := 0 to 1 do
      begin
        IO := Device.ReadPage(Block, Page, Geometry.PageSize, 1, Marker, ECC);
        if not IO.Success then
        begin
          ErrorText := Format(
            'reading marker page %d of block %d failed: %s',
            [Page, Block, IO.ErrorText]);
          Map := NewNANDBlockMap(Geometry);  //ทั้งแผนที่กลับเป็น unknown
          Exit;
        end;
        if Length(Marker) < 1 then
        begin
          ErrorText := Format('block %d marker page %d returned no byte',
                              [Block, Page]);
          Map := NewNANDBlockMap(Geometry);
          Exit;
        end;
        if NANDMarkerState(Marker[0]) <> nbsGood then
          Map[Block] := nbsFactoryBad;
      end;
    end;
    Result := True;
  finally
    //คืนสถานะ ECC เดิมเสมอ ต่อให้สแกนล้มกลางทาง เครื่องอ่านถัดไปจะได้ไม่
    //เจอชิปที่ ECC หายไปเฉย ๆ
    RestoreIO := Device.SetECC(ECCWas);
    if Result and (not RestoreIO.Success) then
    begin
      Result := False;
      ErrorText := 'restoring the ECC state failed: ' + RestoreIO.ErrorText;
      //แผนที่ที่สแกนเสร็จแล้วยังถูกต้องอยู่ ปล่อยไว้ให้ผู้เรียกใช้ได้
    end;
  end;
end;

//ส่วนที่ read กับ program-verify ใช้ร่วมกัน: อ่านหนึ่ง step แล้วตัดสิน ECC
function ReadStepChecked(Device: TNANDDevice; const Step: TNANDStep;
  ECCExpected: boolean; var Report: TNANDRunReport;
  out Data: TBytes): boolean;
var
  IO: TNANDIOResult;
  ECC: TNANDECCStatus;
begin
  Result := False;
  IO := Device.ReadPage(Step.Block, Step.Page, 0, Step.Length, Data, ECC);
  if not IO.Success then
  begin
    Report.ErrorCode := RunErrorForIO(IO);
    Report.ErrorText := Format('reading block %d page %d failed: %s',
                               [Step.Block, Step.Page, IO.ErrorText]);
    Report.FailBlock := Step.Block;
    Report.FailPage := Step.Page;
    Report.HasFailAddress := True;
    Exit;
  end;
  if cardinal(Length(Data)) <> Step.Length then
  begin
    Report.ErrorCode := nreTransport;
    Report.ErrorText := Format(
      'block %d page %d returned %d bytes of the %d requested',
      [Step.Block, Step.Page, Length(Data), Step.Length]);
    Report.FailBlock := Step.Block;
    Report.FailPage := Step.Page;
    Report.HasFailAddress := True;
    Exit;
  end;
  //ผลตัดสินของ ECC มีความหมายเฉพาะตอนที่เปิดอยู่
  if ECCExpected then
  begin
    if ECC = neccUncorrectable then
    begin
      Report.ErrorCode := nreUncorrectableECC;
      Report.ErrorText := Format(
        'block %d page %d has uncorrectable bit errors; the data is not ' +
        'trustworthy', [Step.Block, Step.Page]);
      Report.FailBlock := Step.Block;
      Report.FailPage := Step.Page;
      Report.HasFailAddress := True;
      Exit;
    end;
    if ECC = neccCorrected then Inc(Report.CorrectedPages);
  end;
  Result := True;
end;

function ExecuteNANDRead(Device: TNANDDevice; const Geometry: TNANDGeometry;
  const Map: TNANDBlockMap; const Plan: TNANDPlan; var Image: TBytes;
  ShouldStop: TNANDShouldStop; StepDone: TNANDStepDone): TNANDRunReport;
var
  i: SizeInt;
  Data: TBytes;
  IO: TNANDIOResult;
  UseECC: boolean;
  ErrorText: string;
  PrevCorrected: cardinal;
begin
  Result := ClearReport;

  if Device = nil then
  begin
    Result.ErrorCode := nreInvalidRequest;
    Result.ErrorText := 'no device';
    Exit;
  end;
  if not ValidateNANDPlan(Plan, Geometry, Map, ErrorText) then
  begin
    Result.ErrorCode := nreInvalidPlan;
    Result.ErrorText := 'the plan does not validate: ' + ErrorText;
    Exit;
  end;
  if QWord(Length(Image)) < Plan.ReadBytes then
  begin
    Result.ErrorCode := nreInvalidRequest;
    Result.ErrorText := Format('the image buffer holds %d bytes; the plan ' +
                               'reads %d', [Length(Image), Plan.ReadBytes]);
    Exit;
  end;

  //main-only = ให้ชิปแก้บิตให้ แล้วเช็คคำตัดสินทุกเพจ
  //raw = อยากได้ไบต์ตามจริงรวม parity ต้องปิด ECC ไม่งั้นได้ของที่แก้แล้ว
  UseECC := Geometry.Layout = nilMainOnly;
  IO := Device.SetECC(UseECC);
  if not IO.Success then
  begin
    Result.ErrorCode := RunErrorForIO(IO);
    Result.ErrorText := 'setting the ECC state failed: ' + IO.ErrorText;
    Exit;
  end;

  SetLength(Result.CorrectedPerBlock, Geometry.BlockCount);

  for i := 0 to High(Plan.Steps) do
  begin
    if Assigned(ShouldStop) and ShouldStop() then
    begin
      Result.ErrorCode := nreCancelled;
      Result.Cancelled := True;
      Result.ErrorText := 'cancelled';
      Exit;
    end;
    if Plan.Steps[i].Kind <> nskRead then
    begin
      Result.ErrorCode := nreInvalidPlan;
      Result.ErrorText := Format('step %d of a read plan is not a read', [i]);
      Exit;
    end;

    PrevCorrected := Result.CorrectedPages;
    if not ReadStepChecked(Device, Plan.Steps[i], UseECC, Result, Data) then
      Exit;
    if Result.CorrectedPages > PrevCorrected then
      Inc(Result.CorrectedPerBlock[Plan.Steps[i].Block]);

    Move(Data[0], Image[Plan.Steps[i].ImageOffset], Plan.Steps[i].Length);
    Inc(Result.StepsDone);
    if Assigned(StepDone) then StepDone(Result.StepsDone, Length(Plan.Steps));
  end;

  Result.Success := True;
end;

function ExecuteNANDErase(Device: TNANDDevice;
  const Geometry: TNANDGeometry; const Map: TNANDBlockMap;
  const Plan: TNANDPlan; ShouldStop: TNANDShouldStop;
  StepDone: TNANDStepDone): TNANDRunReport;
var
  i: SizeInt;
  Page, ByteIndex: cardinal;
  IO: TNANDIOResult;
  ECC: TNANDECCStatus;
  Failed: boolean;
  Data: TBytes;
  ErrorText: string;
  Session: TNANDMutationSession;
begin
  Result := ClearReport;

  if Device = nil then
  begin
    Result.ErrorCode := nreInvalidRequest;
    Result.ErrorText := 'no device';
    Exit;
  end;
  if not ValidateNANDPlan(Plan, Geometry, Map, ErrorText) then
  begin
    Result.ErrorCode := nreInvalidPlan;
    Result.ErrorText := 'the plan does not validate: ' + ErrorText;
    Exit;
  end;
  for i := 0 to High(Plan.Steps) do
    if Plan.Steps[i].Kind <> nskErase then
    begin
      Result.ErrorCode := nreInvalidPlan;
      Result.ErrorText := Format('step %d of an erase plan is not an erase',
                                 [i]);
      Exit;
    end;
  if Length(Plan.Steps) = 0 then
  begin
    Result.Success := True;
    Exit;
  end;

  if not CaptureMutationSession(Device, Session, Result) then Exit;
  try
    IO := Device.UnlockAll;
    if not IO.Success then
    begin
      Result.ErrorCode := nreProtection;
      Result.ErrorText := 'unlocking the chip failed: ' + IO.ErrorText;
      Exit;
    end;
    //An erased page has no valid ECC codeword on several supported parts.
    //Read the physical main area for blank verification. The exact inherited
    //B0h byte (including every unrelated vendor bit) is restored in finally.
    IO := Device.SetECC(False);
    if not IO.Success then
    begin
      Result.ErrorCode := RunErrorForIO(IO);
      Result.ErrorText := 'disabling ECC for erase verification failed: ' +
                          IO.ErrorText;
      Exit;
    end;

    for i := 0 to High(Plan.Steps) do
    begin
      if Assigned(ShouldStop) and ShouldStop() then
      begin
        Result.ErrorCode := nreCancelled;
        Result.Cancelled := True;
        Result.ErrorText := 'cancelled';
        Exit;
      end;

      //EraseBlock performs WREN internally. Treat WEL as possibly set even
      //when the adapter fails before it can identify whether D8h was issued.
      Session.WriteEnableMayBeSet := True;
      IO := Device.EraseBlock(Plan.Steps[i].Block, Failed);
      NoteMutationIO(Session, IO);
      if not IO.Success then
      begin
        Result.ErrorCode := RunErrorForIO(IO);
        Result.ErrorText := Format('erasing block %d failed: %s',
          [Plan.Steps[i].Block, IO.ErrorText]);
        Result.FailBlock := Plan.Steps[i].Block;
        Result.HasFailAddress := True;
        Exit;
      end;
      if Failed then
      begin
        Result.ErrorCode := nreEraseFailed;
        Result.ErrorText := Format(
          'the chip reports E_FAIL erasing block %d; the block has gone bad',
          [Plan.Steps[i].Block]);
        Result.FailBlock := Plan.Steps[i].Block;
        Result.HasFailAddress := True;
        Exit;
      end;

      //Cancellation is deliberately not checked inside this loop. Once a
      //block has been mutated, the executor finishes proving its state.
      for Page := 0 to Geometry.PagesPerBlock - 1 do
      begin
        Data := nil;
        IO := Device.ReadPage(Plan.Steps[i].Block, Page, 0,
                              Geometry.PageSize, Data, ECC);
        if not IO.Success then
        begin
          Result.ErrorCode := RunErrorForIO(IO);
          Result.ErrorText := Format(
            'reading erased block %d page %d failed: %s',
            [Plan.Steps[i].Block, Page, IO.ErrorText]);
          Result.FailBlock := Plan.Steps[i].Block;
          Result.FailPage := Page;
          Result.HasFailAddress := True;
          Exit;
        end;
        if cardinal(Length(Data)) <> Geometry.PageSize then
        begin
          Result.ErrorCode := nreTransport;
          Result.ErrorText := Format(
            'erased block %d page %d returned %d of %d bytes',
            [Plan.Steps[i].Block, Page, Length(Data), Geometry.PageSize]);
          Result.FailBlock := Plan.Steps[i].Block;
          Result.FailPage := Page;
          Result.HasFailAddress := True;
          Exit;
        end;
        for ByteIndex := 0 to Geometry.PageSize - 1 do
          if Data[ByteIndex] <> $FF then
          begin
            Result.ErrorCode := nreVerifyMismatch;
            Result.ErrorText := Format(
              'block %d page %d is not blank at byte %d: read %.2x',
              [Plan.Steps[i].Block, Page, ByteIndex, Data[ByteIndex]]);
            Result.FailBlock := Plan.Steps[i].Block;
            Result.FailPage := Page;
            Result.HasFailAddress := True;
            Exit;
          end;
      end;

      Inc(Result.StepsDone);
      if Assigned(StepDone) then
        StepDone(Result.StepsDone, Length(Plan.Steps));
    end;
    Result.Success := True;
  finally
    FinishMutationSession(Device, Session, Result);
  end;
end;

function ExecuteNANDProgram(Device: TNANDDevice;
  const Geometry: TNANDGeometry; const Map: TNANDBlockMap;
  const Plan: TNANDPlan; const Image: TBytes; Verify: boolean;
  ShouldStop: TNANDShouldStop; StepDone: TNANDStepDone): TNANDRunReport;
var
  i: SizeInt;
  j: cardinal;
  Data, ReadBack: TBytes;
  IO: TNANDIOResult;
  UseECC: boolean;
  ErrorText: string;
  Failed: boolean;
  VerifyStep: TNANDStep;
  ExpectedByte: byte;
  Session: TNANDMutationSession;
begin
  Result := ClearReport;

  if Device = nil then
  begin
    Result.ErrorCode := nreInvalidRequest;
    Result.ErrorText := 'no device';
    Exit;
  end;
  if not Verify then
  begin
    Result.ErrorCode := nreInvalidRequest;
    Result.ErrorText := 'SPI NAND writes require full physical read-back ' +
                        'verification';
    Exit;
  end;
  if Geometry.Layout <> nilMainOnly then
  begin
    Result.ErrorCode := nreInvalidRequest;
    Result.ErrorText := 'SPI NAND writes accept main-area images only; ' +
      'raw writes could overwrite bad-block markers and ECC bytes';
    Exit;
  end;
  if not ValidateNANDPlan(Plan, Geometry, Map, ErrorText) then
  begin
    Result.ErrorCode := nreInvalidPlan;
    Result.ErrorText := 'the plan does not validate: ' + ErrorText;
    Exit;
  end;
  if QWord(Length(Image)) < Plan.ProgramBytes then
  begin
    Result.ErrorCode := nreInvalidRequest;
    Result.ErrorText := Format('the image holds %d bytes; the plan ' +
                               'programs %d', [Length(Image),
                               Plan.ProgramBytes]);
    Exit;
  end;
  if Length(Plan.Steps) = 0 then
  begin
    Result.Success := True;
    Exit;
  end;

  if not CaptureMutationSession(Device, Session, Result) then Exit;
  try
    //ชิปที่ยังล็อกอยู่รับคำสั่งแล้วเงียบ ไม่ตั้ง P_FAIL ด้วยซ้ำ ปลดล็อกและ
    //อ่านทะเบียนกลับมาดูก่อนเริ่ม ไม่ใช่ไปเจอความจริงตอน verify พังทั้งชิป
    IO := Device.UnlockAll;
    if not IO.Success then
    begin
      Result.ErrorCode := nreProtection;
      Result.ErrorText := 'unlocking the chip failed: ' + IO.ErrorText;
      Exit;
    end;

    UseECC := Geometry.Layout = nilMainOnly;
    IO := Device.SetECC(UseECC);
    if not IO.Success then
    begin
      Result.ErrorCode := RunErrorForIO(IO);
      Result.ErrorText := 'setting the ECC state failed: ' + IO.ErrorText;
      Exit;
    end;

    for i := 0 to High(Plan.Steps) do
    begin
    //A program plan is grouped as erase + all programmed pages for one
    //block. Poll only at the next erase boundary: once a block is erased,
    //finish programming and verifying that block before honouring cancel.
    if (Plan.Steps[i].Kind = nskErase) and Assigned(ShouldStop) and
       ShouldStop() then
    begin
      Result.ErrorCode := nreCancelled;
      Result.Cancelled := True;
      Result.ErrorText := 'cancelled';
      Exit;
    end;

    case Plan.Steps[i].Kind of
      nskErase:
        begin
          Session.WriteEnableMayBeSet := True;
          IO := Device.EraseBlock(Plan.Steps[i].Block, Failed);
          NoteMutationIO(Session, IO);
          if not IO.Success then
          begin
            Result.ErrorCode := RunErrorForIO(IO);
            Result.ErrorText := Format('erasing block %d failed: %s',
                                       [Plan.Steps[i].Block, IO.ErrorText]);
            Result.FailBlock := Plan.Steps[i].Block;
            Result.HasFailAddress := True;
            Exit;
          end;
          //E_FAIL คือชิปบอกเองว่าลบไม่สำเร็จทั้งที่ BUSY เคลียร์ปกติ
          if Failed then
          begin
            Result.ErrorCode := nreEraseFailed;
            Result.ErrorText := Format(
              'the chip reports E_FAIL erasing block %d; the block has ' +
              'gone bad and the job needs replanning around it',
              [Plan.Steps[i].Block]);
            Result.FailBlock := Plan.Steps[i].Block;
            Result.HasFailAddress := True;
            Exit;
          end;
        end;
      nskProgram:
        begin
          Data := nil;
          SetLength(Data, Plan.Steps[i].Length);
          Move(Image[Plan.Steps[i].ImageOffset], Data[0],
               Plan.Steps[i].Length);
          Session.WriteEnableMayBeSet := True;
          IO := Device.ProgramPage(Plan.Steps[i].Block, Plan.Steps[i].Page,
                                   0, Data, Failed);
          NoteMutationIO(Session, IO);
          if not IO.Success then
          begin
            Result.ErrorCode := RunErrorForIO(IO);
            Result.ErrorText := Format(
              'programming block %d page %d failed: %s',
              [Plan.Steps[i].Block, Plan.Steps[i].Page, IO.ErrorText]);
            Result.FailBlock := Plan.Steps[i].Block;
            Result.FailPage := Plan.Steps[i].Page;
            Result.HasFailAddress := True;
            Exit;
          end;
          if Failed then
          begin
            Result.ErrorCode := nreProgramFailed;
            Result.ErrorText := Format(
              'the chip reports P_FAIL programming block %d page %d',
              [Plan.Steps[i].Block, Plan.Steps[i].Page]);
            Result.FailBlock := Plan.Steps[i].Block;
            Result.FailPage := Plan.Steps[i].Page;
            Result.HasFailAddress := True;
            Exit;
          end;

          //อ่านกลับทันทีทั้งเพจที่เขียน ชิปที่เมินคำสั่งเงียบ ๆ (ล็อกด้วย
          //วิธีที่ปลดไม่ครบ WP# ค้าง ฯลฯ) โผล่ที่นี่ ไม่ใช่หลังจบงาน
          if Verify then
          begin
            VerifyStep := Plan.Steps[i];
            VerifyStep.Length := Geometry.PageSize;
            if not ReadStepChecked(Device, VerifyStep, UseECC, Result,
                                   ReadBack) then Exit;
            for j := 0 to Geometry.PageSize - 1 do
            begin
              if j < cardinal(Length(Data)) then ExpectedByte := Data[j]
              else ExpectedByte := $FF;
              if ReadBack[j] <> ExpectedByte then
              begin
                Result.ErrorCode := nreVerifyMismatch;
                Result.ErrorText := Format(
                  'block %d page %d did not read back as written at ' +
                  'byte %d: wrote %.2x, read %.2x',
                  [Plan.Steps[i].Block, Plan.Steps[i].Page, j,
                   ExpectedByte, ReadBack[j]]);
                Result.FailBlock := Plan.Steps[i].Block;
                Result.FailPage := Plan.Steps[i].Page;
                Result.HasFailAddress := True;
                Exit;
              end;
            end;
          end;
        end;
      nskRead:
        begin
          Result.ErrorCode := nreInvalidPlan;
          Result.ErrorText := Format(
            'step %d of a program plan is a read', [i]);
          Exit;
        end;
    end;

      Inc(Result.StepsDone);
      if Assigned(StepDone) then StepDone(Result.StepsDone, Length(Plan.Steps));
    end;

    Result.Success := True;
  finally
    FinishMutationSession(Device, Session, Result);
  end;
end;

function ExecuteNANDWrite(Device: TNANDDevice;
  const Geometry: TNANDGeometry; const Map: TNANDBlockMap;
  const Plan: TNANDPlan; const Image: TBytes;
  ShouldStop: TNANDShouldStop; StepDone: TNANDStepDone): TNANDRunReport;
begin
  Result := ExecuteNANDProgram(Device, Geometry, Map, Plan, Image, True,
                               ShouldStop, StepDone);
end;

end.
