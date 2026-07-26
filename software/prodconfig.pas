unit prodconfig;

//ไดอะล็อกตั้งค่าเลขรันนิ่งและการผลิตเป็นชุด
//ตรรกะการสร้างเลขอยู่ใน serialnum ซึ่งไม่พึ่ง LCL และมีเทสต์ครอบไว้
//
//ไดอะล็อกสร้างด้วยโค้ด ไม่ได้มาจาก .lfm เพราะถ้าพิมพ์ผิดในไฟล์ฟอร์ม
//โปรแกรมจะเปิดไม่ขึ้นทั้งตัว แบบนี้พังได้แค่ไดอะล็อกนี้

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls, Dialogs, Graphics,
  serialnum;

//ไดอะล็อกตั้งค่า คืน True เมื่อผู้ใช้กด OK
function EditProdSettings(var S: TProdSettings): boolean;

implementation
//--------------------------------------------------------------------- ไดอะล็อก

type

  TProdForm = class(TForm)
  private
    ChkSN: TCheckBox;
    EdAddr: TEdit;
    EdLen: TEdit;
    CbMode: TComboBox;
    EdValue: TEdit;
    EdStep: TEdit;
    ChkBigEndian: TCheckBox;
    EdLog: TEdit;
    ChkBatch: TCheckBox;
    EdTarget: TEdit;
    procedure OkClick(Sender: TObject);
  public
    constructor CreateDialog(AOwner: TComponent);
    procedure Load(const S: TProdSettings);
    procedure Store(var S: TProdSettings);
  end;

function MakeLabel(Parent: TWinControl; ALeft, ATop: integer; const Caption: string): TLabel;
begin
  Result := TLabel.Create(Parent);
  Result.Parent := Parent;
  Result.Left := ALeft;
  Result.Top := ATop;
  Result.Caption := Caption;
end;

function MakeEdit(Parent: TWinControl; ALeft, ATop, AWidth: integer): TEdit;
begin
  Result := TEdit.Create(Parent);
  Result.Parent := Parent;
  Result.Left := ALeft;
  Result.Top := ATop;
  Result.Width := AWidth;
end;

constructor TProdForm.CreateDialog(AOwner: TComponent);
var
  BtnOk, BtnCancel: TButton;
  Bevel: TBevel;
begin
  inherited CreateNew(AOwner);

  Caption := 'Serial number and production';
  BorderStyle := bsDialog;
  Position := poScreenCenter;
  ClientWidth := 380;
  ClientHeight := 330;

  ChkSN := TCheckBox.Create(Self);
  ChkSN.Parent := Self;
  ChkSN.Left := 16;
  ChkSN.Top := 12;
  ChkSN.Width := 340;
  ChkSN.Caption := 'Write a serial number into the buffer before programming';

  MakeLabel(Self, 16, 46, 'Address in buffer (hex)');
  EdAddr := MakeEdit(Self, 210, 42, 150);

  MakeLabel(Self, 16, 76, 'Length (1..8 bytes)');
  EdLen := MakeEdit(Self, 210, 72, 150);

  MakeLabel(Self, 16, 106, 'Format');
  CbMode := TComboBox.Create(Self);
  CbMode.Parent := Self;
  CbMode.Left := 210;
  CbMode.Top := 102;
  CbMode.Width := 150;
  CbMode.Style := csDropDownList;
  CbMode.Items.Add('Increment');
  CbMode.Items.Add('BCD date + increment');
  CbMode.Items.Add('Random');
  CbMode.ItemIndex := 0;

  MakeLabel(Self, 16, 136, 'Start value (decimal)');
  EdValue := MakeEdit(Self, 210, 132, 150);

  MakeLabel(Self, 16, 166, 'Step');
  EdStep := MakeEdit(Self, 210, 162, 150);

  ChkBigEndian := TCheckBox.Create(Self);
  ChkBigEndian.Parent := Self;
  ChkBigEndian.Left := 210;
  ChkBigEndian.Top := 190;
  ChkBigEndian.Width := 150;
  ChkBigEndian.Caption := 'Most significant byte first';

  MakeLabel(Self, 16, 216, 'Log issued numbers to');
  EdLog := MakeEdit(Self, 210, 212, 150);

  Bevel := TBevel.Create(Self);
  Bevel.Parent := Self;
  Bevel.Left := 16;
  Bevel.Top := 244;
  Bevel.Width := 344;
  Bevel.Height := 2;
  Bevel.Shape := bsTopLine;

  ChkBatch := TCheckBox.Create(Self);
  ChkBatch.Parent := Self;
  ChkBatch.Left := 16;
  ChkBatch.Top := 254;
  ChkBatch.Width := 180;
  ChkBatch.Caption := 'Production batch mode';

  MakeLabel(Self, 210, 256, 'chips');
  EdTarget := MakeEdit(Self, 250, 252, 110);

  BtnOk := TButton.Create(Self);
  BtnOk.Parent := Self;
  BtnOk.Left := 196;
  BtnOk.Top := 292;
  BtnOk.Width := 80;
  BtnOk.Caption := 'OK';
  BtnOk.OnClick := @OkClick;
  BtnOk.Default := True;

  BtnCancel := TButton.Create(Self);
  BtnCancel.Parent := Self;
  BtnCancel.Left := 282;
  BtnCancel.Top := 292;
  BtnCancel.Width := 80;
  BtnCancel.Caption := 'Cancel';
  BtnCancel.ModalResult := mrCancel;
  BtnCancel.Cancel := True;
end;

procedure TProdForm.OkClick(Sender: TObject);
var
  Dummy: integer;
begin
  if not TryStrToInt('$' + Trim(EdAddr.Text), Dummy) then
  begin
    ShowMessage('Address must be a hexadecimal number');
    Exit;
  end;

  if not TryStrToInt(Trim(EdLen.Text), Dummy) then Dummy := 0;
  if (Dummy < 1) or (Dummy > 8) then
  begin
    ShowMessage('Length must be between 1 and 8 bytes');
    Exit;
  end;

  ModalResult := mrOk;
end;

procedure TProdForm.Load(const S: TProdSettings);
begin
  ChkSN.Checked := S.SNEnabled;
  EdAddr.Text := IntToHex(S.SNAddress, 6);
  EdLen.Text := IntToStr(S.SNLength);
  CbMode.ItemIndex := Ord(S.SNMode);
  EdValue.Text := IntToStr(S.SNValue);
  EdStep.Text := IntToStr(S.SNStep);
  ChkBigEndian.Checked := S.SNBigEndian;
  EdLog.Text := S.SNLogFile;
  ChkBatch.Checked := S.BatchEnabled;
  EdTarget.Text := IntToStr(S.BatchTarget);
end;

procedure TProdForm.Store(var S: TProdSettings);
var
  V: integer;
  Q: QWord;
begin
  S.SNEnabled := ChkSN.Checked;

  if TryStrToInt('$' + Trim(EdAddr.Text), V) then S.SNAddress := cardinal(V);
  if TryStrToInt(Trim(EdLen.Text), V) and (V >= 1) and (V <= 8) then S.SNLength := byte(V);

  if CbMode.ItemIndex >= 0 then S.SNMode := TSerialMode(CbMode.ItemIndex);

  if TryStrToQWord(Trim(EdValue.Text), Q) then S.SNValue := Q;
  if TryStrToInt(Trim(EdStep.Text), V) and (V > 0) then S.SNStep := cardinal(V);

  S.SNBigEndian := ChkBigEndian.Checked;
  S.SNLogFile := Trim(EdLog.Text);

  S.BatchEnabled := ChkBatch.Checked;
  if TryStrToInt(Trim(EdTarget.Text), V) and (V > 0) then S.BatchTarget := V;
end;

function EditProdSettings(var S: TProdSettings): boolean;
var
  F: TProdForm;
begin
  F := TProdForm.CreateDialog(nil);
  try
    F.Load(S);
    Result := F.ShowModal = mrOk;
    if Result then F.Store(S);
  finally
    F.Free;
  end;
end;

initialization
  Randomize;

end.
