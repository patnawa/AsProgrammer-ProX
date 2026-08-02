program AsProgrammerCLI;

{$mode objfpc}{$H+}

{$IFDEF UNIX}
{$IFDEF UseCThreads}
uses cthreads, SysUtils, headlesscli;
{$ELSE}
uses SysUtils, headlesscli;
{$ENDIF}
{$ELSE}
uses SysUtils, headlesscli;
{$ENDIF}

var
  ExitCode: integer;
begin
  try
    ExitCode := RunHeadlessCLI;
  except
    on E: Exception do
    begin
      WriteLn(StdErr, 'FAILED: ', E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
  Halt(ExitCode);
end.
