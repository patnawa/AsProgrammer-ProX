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

  TNANDIOResult = record
    Success: boolean;
    Error: TNANDIOError;
    ErrorText: string;
  end;

  TNANDECCStatus = (
    neccGood,          //no bit errors
    neccCorrected,     //bit errors existed and the chip fixed them
    neccUncorrectable  //the data returned is not trustworthy
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
    ErrorText: string;
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

//Scan every block's factory marker (first byte of the spare area of the
//block's first page) into a fresh map. ECC is turned off for the scan and
//restored to its previous state afterwards, even on failure.
function ScanNANDBadBlocks(Device: TNANDDevice;
  const Geometry: TNANDGeometry; out Map: TNANDBlockMap;
  out ErrorText: string): boolean;

//Execute a read plan into Image (sized by the caller to the plan's total
//read bytes). ECC on for main-only layouts, off for raw.
function ExecuteNANDRead(Device: TNANDDevice; const Geometry: TNANDGeometry;
  const Map: TNANDBlockMap; const Plan: TNANDPlan; var Image: TBytes;
  ShouldStop: TNANDShouldStop; StepDone: TNANDStepDone): TNANDRunReport;

//Execute a program plan from Image. Unlocks first, erases and programs per
//the plan, checks E_FAIL/P_FAIL, and (unless Verify is false) reads every
//programmed page back and compares.
function ExecuteNANDProgram(Device: TNANDDevice;
  const Geometry: TNANDGeometry; const Map: TNANDBlockMap;
  const Plan: TNANDPlan; const Image: TBytes; Verify: boolean;
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
end;

function NANDIOFailure(Error: TNANDIOError;
  const ErrorText: string): TNANDIOResult;
begin
  Result.Success := False;
  Result.Error := Error;
  Result.ErrorText := ErrorText;
end;

function ClearReport: TNANDRunReport;
begin
  Result.Success := False;
  Result.ErrorText := '';
  Result.Cancelled := False;
  Result.FailBlock := 0;
  Result.FailPage := 0;
  Result.HasFailAddress := False;
  Result.CorrectedPages := 0;
  Result.CorrectedPerBlock := nil;
  Result.StepsDone := 0;
end;

function ScanNANDBadBlocks(Device: TNANDDevice;
  const Geometry: TNANDGeometry; out Map: TNANDBlockMap;
  out ErrorText: string): boolean;
var
  Block: cardinal;
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
      IO := Device.ReadPage(Block, 0, Geometry.PageSize, 1, Marker, ECC);
      if not IO.Success then
      begin
        ErrorText := Format('reading the marker of block %d failed: %s',
                            [Block, IO.ErrorText]);
        Map := NewNANDBlockMap(Geometry);  //ทั้งแผนที่กลับเป็น unknown
        Exit;
      end;
      if Length(Marker) < 1 then
      begin
        ErrorText := Format('block %d returned no marker byte', [Block]);
        Map := NewNANDBlockMap(Geometry);
        Exit;
      end;
      Map[Block] := NANDMarkerState(Marker[0]);
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
    Report.ErrorText := Format('reading block %d page %d failed: %s',
                               [Step.Block, Step.Page, IO.ErrorText]);
    Report.FailBlock := Step.Block;
    Report.FailPage := Step.Page;
    Report.HasFailAddress := True;
    Exit;
  end;
  if cardinal(Length(Data)) <> Step.Length then
  begin
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
    Result.ErrorText := 'no device';
    Exit;
  end;
  if not ValidateNANDPlan(Plan, Geometry, Map, ErrorText) then
  begin
    Result.ErrorText := 'the plan does not validate: ' + ErrorText;
    Exit;
  end;
  if QWord(Length(Image)) < Plan.ReadBytes then
  begin
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
    Result.ErrorText := 'setting the ECC state failed: ' + IO.ErrorText;
    Exit;
  end;

  SetLength(Result.CorrectedPerBlock, Geometry.BlockCount);

  for i := 0 to High(Plan.Steps) do
  begin
    if Assigned(ShouldStop) and ShouldStop() then
    begin
      Result.Cancelled := True;
      Result.ErrorText := 'cancelled';
      Exit;
    end;
    if Plan.Steps[i].Kind <> nskRead then
    begin
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
begin
  Result := ClearReport;

  if Device = nil then
  begin
    Result.ErrorText := 'no device';
    Exit;
  end;
  if not ValidateNANDPlan(Plan, Geometry, Map, ErrorText) then
  begin
    Result.ErrorText := 'the plan does not validate: ' + ErrorText;
    Exit;
  end;
  if QWord(Length(Image)) < Plan.ProgramBytes then
  begin
    Result.ErrorText := Format('the image holds %d bytes; the plan ' +
                               'programs %d', [Length(Image),
                               Plan.ProgramBytes]);
    Exit;
  end;

  //ชิปที่ยังล็อกอยู่รับคำสั่งแล้วเงียบ ไม่ตั้ง P_FAIL ด้วยซ้ำ ปลดล็อกและ
  //อ่านทะเบียนกลับมาดูก่อนเริ่ม ไม่ใช่ไปเจอความจริงตอน verify พังทั้งชิป
  IO := Device.UnlockAll;
  if not IO.Success then
  begin
    Result.ErrorText := 'unlocking the chip failed: ' + IO.ErrorText;
    Exit;
  end;

  UseECC := Geometry.Layout = nilMainOnly;
  IO := Device.SetECC(UseECC);
  if not IO.Success then
  begin
    Result.ErrorText := 'setting the ECC state failed: ' + IO.ErrorText;
    Exit;
  end;

  for i := 0 to High(Plan.Steps) do
  begin
    if Assigned(ShouldStop) and ShouldStop() then
    begin
      Result.Cancelled := True;
      Result.ErrorText := 'cancelled';
      Exit;
    end;

    case Plan.Steps[i].Kind of
      nskErase:
        begin
          IO := Device.EraseBlock(Plan.Steps[i].Block, Failed);
          if not IO.Success then
          begin
            Result.ErrorText := Format('erasing block %d failed: %s',
                                       [Plan.Steps[i].Block, IO.ErrorText]);
            Result.FailBlock := Plan.Steps[i].Block;
            Result.HasFailAddress := True;
            Exit;
          end;
          //E_FAIL คือชิปบอกเองว่าลบไม่สำเร็จทั้งที่ BUSY เคลียร์ปกติ
          if Failed then
          begin
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
          IO := Device.ProgramPage(Plan.Steps[i].Block, Plan.Steps[i].Page,
                                   0, Data, Failed);
          if not IO.Success then
          begin
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
            if not ReadStepChecked(Device, VerifyStep, UseECC, Result,
                                   ReadBack) then Exit;
            for j := 0 to Plan.Steps[i].Length - 1 do
              if ReadBack[j] <> Data[j] then
              begin
                Result.ErrorText := Format(
                  'block %d page %d did not read back as written at ' +
                  'byte %d: wrote %.2x, read %.2x',
                  [Plan.Steps[i].Block, Plan.Steps[i].Page, j,
                   Data[j], ReadBack[j]]);
                Result.FailBlock := Plan.Steps[i].Block;
                Result.FailPage := Plan.Steps[i].Page;
                Result.HasFailAddress := True;
                Exit;
              end;
          end;
        end;
      nskRead:
        begin
          Result.ErrorText := Format(
            'step %d of a program plan is a read', [i]);
          Exit;
        end;
    end;

    Inc(Result.StepsDone);
    if Assigned(StepDone) then StepDone(Result.StepsDone, Length(Plan.Steps));
  end;

  Result.Success := True;
end;

end.
