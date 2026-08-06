unit opthread;

//รันงานที่ใช้เวลานานบน thread เบื้องหลัง
//ระหว่างนั้น thread หลักยังปั๊ม message ต่อ หน้าต่างจึงไม่ค้าง
//และปุ่ม Cancel ยังกดได้แม้ตอนที่ไดรเวอร์บล็อกอยู่ (Buzzpirat, CH341)
//
//สำคัญ: โค้ดที่รันบน thread เบื้องหลังห้ามแตะ control โดยตรง
//ถ้าจะเขียน log หรืออัปเดต progress ให้เรียก LogPrint/SetProgress* จาก main
//ซึ่งจะสลับไป thread หลักให้เอง

{$mode objfpc}{$H+}
{$modeswitch nestedprocvars}

interface

uses
  Classes, SysUtils, Forms, SyncObjs;

type

  TNestedOp = procedure is nested;

  TOpThread = class(TThread)
  private
    FProc: TNestedOp;
    FErrorMsg: string;
  protected
    procedure Execute; override;
  public
    constructor CreateOp(AProc: TNestedOp);
    property ErrorMsg: string read FErrorMsg;
  end;

var
  //ปิดไว้เป็นค่าเริ่มต้น พฤติกรรมเดิมจึงยังเป็นค่าเริ่มต้น
  UseWorkerThread: boolean = False;

//เรียก AProc ถ้าเปิดโหมดเบื้องหลังจะรันบน thread แยก ถ้าไม่เปิดก็เรียกตรง ๆ
//คืนข้อความ exception จาก thread หรือสตริงว่างถ้าไม่มีข้อผิดพลาด
function RunOperation(AProc: TNestedOp): string;

function InWorkerThread: boolean;

//Cancellation is shared between the UI thread and the device worker.  It must
//not be stored in an LCL control: reading Button.Tag from a worker is undefined
//and occasionally races with destruction of the form.
procedure ResetOperationCancellation;
procedure RequestOperationCancellation;
function OperationCancellationRequested: boolean;

//Application.ProcessMessages เวอร์ชันที่เรียกจาก thread เบื้องหลังได้อย่างปลอดภัย
procedure OpProcessMessages;

implementation

uses
  opresult, basehw;

var
  CancelEvent: TEvent;

//ดับไฟแสดงการทำงานให้ชัวร์เมื่องานจบ
//
//ไฟติดตอน SPIInit และดับตอน SPIDeinit ซึ่งอยู่คนละฟังก์ชันกัน งานที่จบด้วย
//ข้อผิดพลาดหรือถูกยกเลิกจะข้าม ExitProgMode25 ไป ไฟจึงค้างติดทั้งที่ไม่มีงาน
//เหลืออยู่ แล้วครั้งต่อไปผู้ใช้ก็อ่านไฟดวงนี้ไม่ได้อีกเลย
//
//ที่นี่คือจุดเดียวที่ทุกงานวิ่งผ่านและจบแน่นอนทุกทาง จึงเป็นที่ที่ถูกต้อง
//เครื่องที่ไม่มีไฟดวงนี้ SetActivityLED เป็นตัวเปล่า เรียกไปก็ไม่เสียอะไร
procedure QuiesceActivityLED;
begin
  if AsProgrammer = nil then Exit;
  if AsProgrammer.Programmer = nil then Exit;
  AsProgrammer.Programmer.SetActivityLED(False);
end;

constructor TOpThread.CreateOp(AProc: TNestedOp);
begin
  inherited Create(True);   //สร้างแบบหยุดไว้ก่อน จะได้ใส่ค่าลงฟิลด์ให้ครบก่อนเริ่มรัน
  FProc := AProc;
  FErrorMsg := '';
  FreeOnTerminate := False;
  Start;
end;

procedure TOpThread.Execute;
begin
  try
    FProc();
  except
    on E: Exception do
      FErrorMsg := E.ClassName + ': ' + E.Message;
  end;
end;

function InWorkerThread: boolean;
begin
  Result := GetCurrentThreadId <> MainThreadID;
end;

procedure ResetOperationCancellation;
begin
  CancelEvent.ResetEvent;
end;

procedure RequestOperationCancellation;
begin
  CancelEvent.SetEvent;
end;

function OperationCancellationRequested: boolean;
begin
  Result := CancelEvent.WaitFor(0) = wrSignaled;
end;

procedure OpProcessMessages;
begin
  //ห้ามปั๊มคิว message จาก thread เบื้องหลัง งานนี้เป็นของ thread หลัก
  if not InWorkerThread then Application.ProcessMessages;
end;

function RunOperation(AProc: TNestedOp): string;
var
  T: TOpThread;
  Nested: boolean;
begin
  Result := '';
  //งานที่ซ้อนอยู่ในงานใหญ่ยังไม่จบจริง ห้ามดับไฟแทนงานที่ยังทำอยู่
  Nested := InWorkerThread;

  //ห้ามเรียกซ้อน เพราะตอนนี้อยู่บน thread เบื้องหลังอยู่แล้ว
  if (not UseWorkerThread) or Nested then
  begin
    try
      AProc();
    except
      on E: Exception do
      begin
        Result := E.ClassName + ': ' + E.Message;
        OpFail('operation raised an exception: ' + Result);
      end;
    end;
    if not Nested then QuiesceActivityLED;
    Exit;
  end;

  T := TOpThread.CreateOp(AProc);
  try
    while not T.Finished do
    begin
      Application.ProcessMessages;
      CheckSynchronize(10);
    end;

    //เก็บกวาดสิ่งที่ยังค้างอยู่ในคิว synchronize
    CheckSynchronize(0);
    Result := T.ErrorMsg;
    if Result <> '' then
      OpFail('background operation raised an exception: ' + Result);
  finally
    T.WaitFor;
    T.Free;
    //ถึงตรงนี้ worker จบแน่นอนแล้ว ไม่ว่าจะจบด้วยทางไหน
    QuiesceActivityLED;
  end;
end;

initialization
  CancelEvent := TEvent.Create(nil, True, False, '');

finalization
  CancelEvent.Free;

end.
