program operationrunner_tests;

{$mode objfpc}{$H+}

uses
  SysUtils, operationmodel, norplanner, norengine, operationrunner,
  virtualspi25;

type
  TSecondPassMismatchDevice = class(TVirtualSPI25)
  private
    FReads: cardinal;
  public
    function Read(Address: QWord; Len: cardinal;
      out Data: TBytes): TNORIOResult; override;
  end;

  // Models a clip/chip swap in the gap between the runner's trusted snapshot
  // session and the executor session.  Reset changes the physical image before
  // the second Open while retaining this subclass's open counter.
  TReopenSwapDevice = class(TVirtualSPI25)
  private
    FOpenCount: cardinal;
    FReplacement: TBytes;
  public
    constructor Create(const Geometry: TNORGeometry;
      const InitialData, ReplacementData: array of byte);
    function Open: TNORIOResult; override;
  end;

  TBackupRecorder = class
  public
    Called: boolean;
    Data: TBytes;
    RaiseOnCommit: boolean;
    function Commit(const Request: TOperationRequest;
      const Snapshot: TBytes; out ErrorText: string): boolean;
  end;

var
  Assertions: integer = 0;
  Failures: integer = 0;

procedure Check(const Name: string; Condition: boolean);
begin
  Inc(Assertions);
  if not Condition then
  begin
    Inc(Failures);
    WriteLn('  FAIL  ', Name);
  end
  else
    WriteLn('  ok    ', Name);
end;

function TSecondPassMismatchDevice.Read(Address: QWord; Len: cardinal;
  out Data: TBytes): TNORIOResult;
begin
  Result := inherited Read(Address, Len, Data);
  Inc(FReads);
  if Result.Success and (FReads = 2) and (Length(Data) > 7) then
    Data[7] := Data[7] xor 1;
end;

constructor TReopenSwapDevice.Create(const Geometry: TNORGeometry;
  const InitialData, ReplacementData: array of byte);
begin
  inherited Create(Geometry, InitialData);
  SetLength(FReplacement, Length(ReplacementData));
  if Length(ReplacementData) > 0 then
    Move(ReplacementData[0], FReplacement[0], Length(ReplacementData));
end;

function TReopenSwapDevice.Open: TNORIOResult;
begin
  Inc(FOpenCount);
  if FOpenCount = 2 then Reset(FReplacement);
  Result := inherited Open;
end;

function TBackupRecorder.Commit(const Request: TOperationRequest;
  const Snapshot: TBytes; out ErrorText: string): boolean;
begin
  Called := True;
  if RaiseOnCommit then
    raise Exception.Create('simulated backup storage failure');
  Data := Copy(Snapshot);
  ErrorText := '';
  Result := True;
end;

function MakeGeometry(out Geometry: TNORGeometry): boolean;
var
  Err: string;
begin
  Result := BuildUniformNORGeometry(1024, 64, 256, $20, Geometry, Err);
  if not Result then WriteLn('geometry: ', Err);
end;

function MakeInput(Mode: TNOROperationMode;
  const Geometry: TNORGeometry; Address: QWord;
  const Patch: TBytes): TNOROperationInput;
begin
  InitNOROperationInput(Result);
  Result.Mode := Mode;
  Result.Geometry := Geometry;
  Result.Patch := Copy(Patch);
  Result.ReadPasses := 2;
  Result.Operation.OperationID := 'operation-runner-test';
  Result.Operation.Kind := okProgram;
  Result.Operation.Target.Address := Address;
  Result.Operation.Target.Length := Length(Patch);
  Result.Operation.Chip.Name := 'virtual';
  Result.Operation.Chip.JedecID := 'EF4014';
  Result.Operation.Chip.Capacity := Geometry.ChipSize;
  Result.Operation.Policy.RequireEvidenceCommit := False;
end;

procedure FillInitial(out Data: TBytes);
var
  I: SizeInt;
begin
  SetLength(Data, 1024);
  for I := 0 to High(Data) do Data[I] := byte((I * 37 + 11) and $FF);
end;

procedure TestPreviewAndWrite;
var
  Geometry: TNORGeometry;
  Initial, Patch, Expected: TBytes;
  Device: TVirtualSPI25;
  Runner: TNOROperationRunner;
  Backup: TBackupRecorder;
  Input: TNOROperationInput;
  Preview, Written: TNOROperationResponse;
begin
  WriteLn('Deep runner: preview and write share one trusted workflow');
  Check('geometry', MakeGeometry(Geometry));
  FillInitial(Initial);
  SetLength(Patch, 4);
  Patch[0] := $FF;
  Patch[1] := $00;
  Patch[2] := $A5;
  Patch[3] := $5A;
  Expected := Copy(Initial);
  Move(Patch[0], Expected[100], Length(Patch));

  Device := TVirtualSPI25.Create(Geometry, Initial);
  Backup := TBackupRecorder.Create;
  Runner := TNOROperationRunner.Create(Device, nil, nil, @Backup.Commit);
  try
    Input := MakeInput(nomSmartPreview, Geometry, 100, Patch);
    Preview := Runner.Execute(Input);
    Check('preview succeeds', Preview.Outcome.Status = osSucceeded);
    Check('preview returns a plan', Preview.HasPlan);
    Check('preview captured a trusted backup', Length(Preview.Data) = 1024);
    Check('preview never mutates', Device.MutationCount = 0);

    Input.Mode := nomSmartWrite;
    Written := Runner.Execute(Input);
    Check('write succeeds', Written.Outcome.Status = osSucceeded);
    Check('physical verification completed',
      Written.Outcome.PhysicalVerifyCompleted);
    Check('write returns its plan', Written.HasPlan);
    Check('write returns the pre-write snapshot',
      Length(Written.Data) = Length(Initial));
    Check('backup was committed before mutation', Backup.Called);
    Check('backup contains the original chip',
      Length(Backup.Data) = Length(Initial));
    Check('desired image is on the chip', Device.MemoryEquals(Expected));
  finally
    Runner.Free;
    Backup.Free;
    Device.Free;
  end;
end;

procedure TestReadAndContactMismatch;
var
  Geometry: TNORGeometry;
  Initial, EmptyPatch: TBytes;
  Device: TSecondPassMismatchDevice;
  Runner: TNOROperationRunner;
  Input: TNOROperationInput;
  Response: TNOROperationResponse;
begin
  WriteLn('Deep runner: mismatched snapshots fail before mutation');
  Check('geometry for mismatch', MakeGeometry(Geometry));
  FillInitial(Initial);
  EmptyPatch := nil;
  Device := TSecondPassMismatchDevice.Create(Geometry, Initial);
  Runner := TNOROperationRunner.Create(Device);
  try
    Input := MakeInput(nomRead, Geometry, 0, EmptyPatch);
    Input.Operation.Kind := okRead;
    Input.Operation.Target.Length := Geometry.ChipSize;
    Response := Runner.Execute(Input);
    Check('mismatch fails', Response.Outcome.Status = osFailed);
    Check('mismatch is typed as unstable contact',
      Response.Outcome.ErrorCode = oeContactUnstable);
    Check('mismatch address is retained',
      Response.Outcome.HasFailureAddress and
      (Response.Outcome.FailureAddress = 7));
    Check('mismatch made no mutation', Device.MutationCount = 0);
    Check('mismatch still closed the device', Device.CloseCalls = 1);
  finally
    Runner.Free;
    Device.Free;
  end;
end;

procedure TestBackupAdmission;
var
  Geometry: TNORGeometry;
  Initial, Patch: TBytes;
  Device: TVirtualSPI25;
  Runner: TNOROperationRunner;
  Input: TNOROperationInput;
  Response: TNOROperationResponse;
  Backup: TBackupRecorder;
begin
  WriteLn('Deep runner: required backup is a mutation admission gate');
  Check('geometry for backup admission', MakeGeometry(Geometry));
  FillInitial(Initial);
  SetLength(Patch, 1);
  Patch[0] := $FF;
  Device := TVirtualSPI25.Create(Geometry, Initial);
  Runner := TNOROperationRunner.Create(Device);
  try
    Input := MakeInput(nomSmartWrite, Geometry, 100, Patch);
    Response := Runner.Execute(Input);
    Check('missing backup sink is refused',
      Response.Outcome.ErrorCode = oeBackupUntrusted);
    Check('backup refusal happens before mutation', Device.MutationCount = 0);
  finally
    Runner.Free;
    Device.Free;
  end;

  Device := TVirtualSPI25.Create(Geometry, Initial);
  Backup := TBackupRecorder.Create;
  Backup.RaiseOnCommit := True;
  Runner := TNOROperationRunner.Create(Device, nil, nil, @Backup.Commit);
  try
    Input := MakeInput(nomSmartWrite, Geometry, 100, Patch);
    Response := Runner.Execute(Input);
    Check('backup exception is returned as a typed failure',
      Response.Outcome.ErrorCode = oeBackupUntrusted);
    Check('backup exception happens before mutation', Device.MutationCount = 0);
  finally
    Runner.Free;
    Backup.Free;
    Device.Free;
  end;

  // A plan containing verification only does not need a recovery file because
  // no byte can change.  The runner still reopens and physically verifies it.
  Patch[0] := Initial[100];
  Device := TVirtualSPI25.Create(Geometry, Initial);
  Runner := TNOROperationRunner.Create(Device);
  try
    Input := MakeInput(nomSmartWrite, Geometry, 100, Patch);
    Response := Runner.Execute(Input);
    Check('no-op plan succeeds without backup sink',
      Response.Outcome.Status = osSucceeded);
    Check('no-op plan physically verifies',
      Response.Outcome.PhysicalVerifyCompleted);
    Check('no-op plan never mutates', Device.MutationCount = 0);
  finally
    Runner.Free;
    Device.Free;
  end;
end;

function DeviceCalled(const Device: TVirtualSPI25;
  Kind: TVirtualCallKind): boolean;
var
  I: SizeInt;
begin
  Result := False;
  for I := 0 to High(Device.Calls) do
    if Device.Calls[I].Kind = Kind then Exit(True);
end;

procedure TestReopenSwapRejectedBeforeMutation;
var
  Geometry: TNORGeometry;
  Initial, Replacement, Patch: TBytes;
  Device: TReopenSwapDevice;
  Runner: TNOROperationRunner;
  Backup: TBackupRecorder;
  Input: TNOROperationInput;
  Response: TNOROperationResponse;
begin
  WriteLn('Deep runner: executor binds mutation to the trusted preimage');
  Check('geometry for reopen swap', MakeGeometry(Geometry));
  FillInitial(Initial);
  Replacement := Copy(Initial);
  Replacement[90] := Replacement[90] xor 1;
  SetLength(Patch, 1);
  Patch[0] := $FF; // initial byte 100 is 7Fh, so the stale plan would erase

  Device := TReopenSwapDevice.Create(Geometry, Initial, Replacement);
  Backup := TBackupRecorder.Create;
  Runner := TNOROperationRunner.Create(Device, nil, nil, @Backup.Commit);
  try
    Input := MakeInput(nomSmartWrite, Geometry, 100, Patch);
    Response := Runner.Execute(Input);
    Check('backup committed before the executor reopen', Backup.Called);
    Check('reopen content change is a typed pre-mutation failure',
      (Response.Outcome.Status = osFailed) and
      (Response.Outcome.ErrorCode = oeContactUnstable));
    Check('first changed byte identifies the stale preimage',
      Response.Outcome.HasFailureAddress and
      (Response.Outcome.FailureAddress = 90));
    Check('reopen content change issues no erase or program',
      Device.MutationCount = 0);
    Check('reopen content change is rejected before WREN',
      not DeviceCalled(Device, vckWriteEnable));
  finally
    Runner.Free;
    Backup.Free;
    Device.Free;
  end;
end;

begin
  TestPreviewAndWrite;
  TestReadAndContactMismatch;
  TestBackupAdmission;
  TestReopenSwapRejectedBeforeMutation;
  WriteLn;
  WriteLn(Assertions, ' assertions, ', Failures, ' failures');
  if Failures <> 0 then Halt(1);
  WriteLn('ALL PASSED');
end.
