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
  Classes, SysUtils, Forms;

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

//Application.ProcessMessages เวอร์ชันที่เรียกจาก thread เบื้องหลังได้อย่างปลอดภัย
procedure OpProcessMessages;

implementation

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

procedure OpProcessMessages;
begin
  //ห้ามปั๊มคิว message จาก thread เบื้องหลัง งานนี้เป็นของ thread หลัก
  if not InWorkerThread then Application.ProcessMessages;
end;

function RunOperation(AProc: TNestedOp): string;
var
  T: TOpThread;
begin
  Result := '';

  //ห้ามเรียกซ้อน เพราะตอนนี้อยู่บน thread เบื้องหลังอยู่แล้ว
  if (not UseWorkerThread) or InWorkerThread then
  begin
    AProc();
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
  finally
    T.WaitFor;
    T.Free;
  end;
end;

end.
