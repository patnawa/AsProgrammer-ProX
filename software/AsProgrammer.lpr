program AsProgrammer;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Interfaces, // บรรทัดนี้ดึง widgetset ของ LCL เข้ามา
  Forms, main, i2c, microwire,
  spi95, search, sregedit, findchip, ScriptEdit, spi25;

{$R *.res}

begin
  LoadXML;
  Translate(SettingsFile);
  RequireDerivedFormResource := True;
  Application.Scaled:=True;
  Application.Initialize;
  Application.CreateForm(TMainForm, MainForm);
  Application.CreateForm(TSearchForm, SearchForm);
  Application.CreateForm(TsregeditForm, sregeditForm);
  Application.CreateForm(TChipSearchForm, ChipSearchForm);
  Application.CreateForm(TScriptEditForm, ScriptEditForm);
  Application.Run;
end.

