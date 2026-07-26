unit opthread;

//Выполнение длительных операций в фоновом потоке.
//Главный поток при этом продолжает качать сообщения, поэтому GUI не зависает
//и кнопка "Отмена" остается живой даже на блокирующих вызовах(Buzzpirat, CH341).
//
//ВАЖНО: код, выполняемый в фоновом потоке, не должен обращаться к элементам
//управления напрямую. Для лога и прогресса используйте LogPrint/SetProgress*
//из main, они сами переключаются на главный поток.

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
  //Выключено по умолчанию: старое поведение остается поведением по умолчанию
  UseWorkerThread: boolean = False;

//Выполняет AProc. В фоновом режиме - в отдельном потоке, иначе просто вызывает.
//Возвращает текст исключения из потока или пустую строку
function RunOperation(AProc: TNestedOp): string;

function InWorkerThread: boolean;

//Application.ProcessMessages, безопасный для вызова из рабочего потока
procedure OpProcessMessages;

implementation

constructor TOpThread.CreateOp(AProc: TNestedOp);
begin
  inherited Create(True);   //создаем приостановленным, чтобы успеть заполнить поля
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
  //В рабочем потоке качать очередь сообщений нельзя - это делает главный поток
  if not InWorkerThread then Application.ProcessMessages;
end;

function RunOperation(AProc: TNestedOp): string;
var
  T: TOpThread;
begin
  Result := '';

  //Вложенный запуск недопустим: уже находимся в рабочем потоке
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

    //Добираем то, что осталось в очереди синхронизации
    CheckSynchronize(0);
    Result := T.ErrorMsg;
  finally
    T.WaitFor;
    T.Free;
  end;
end;

end.
