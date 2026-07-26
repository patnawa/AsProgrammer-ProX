unit prodconfig;

//เลขรันนิ่งอัตโนมัติและโหมดผลิตเป็นชุด
//
//ไดอะล็อกสร้างด้วยโค้ด ไม่ได้มาจาก .lfm เพราะถ้าพิมพ์ผิดในไฟล์ฟอร์ม
//โปรแกรมจะเปิดไม่ขึ้นทั้งตัว แบบนี้พังได้แค่ไดอะล็อกนี้

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls, Dialogs, Graphics;

type

  TSerialMode = (
    smIncrement,        //นับอย่างเดียว
    smDateIncrement,    //วันที่แบบ BCD ปี เดือน วัน แล้วตามด้วยตัวนับ
    smRandom            //ไบต์สุ่ม
  );

  TProdSettings = record
    SNEnabled: boolean;
    SNAddress: cardinal;    //ตำแหน่งในบัฟเฟอร์ที่จะวางเลข
    SNLength: byte;         //1..8 ไบต์
    SNMode: TSerialMode;
    SNValue: QWord;         //ค่าตัวนับปัจจุบัน
    SNStep: cardinal;
    SNBigEndian: boolean;   //เรียงไบต์สูงขึ้นก่อน
    SNLogFile: string;      //ไฟล์บันทึกเลขที่จ่ายไป เว้นว่างคือไม่บันทึก

    BatchEnabled: boolean;
    BatchTarget: integer;   //จะเขียนกี่ตัวต่อหนึ่งรอบการผลิต
  end;

//ไดอะล็อกตั้งค่า คืน True เมื่อผู้ใช้กด OK
function EditProdSettings(var S: TProdSettings): boolean;

//ค่าเริ่มต้น
procedure DefaultProdSettings(out S: TProdSettings);

//สร้างไบต์ของเลขรันนิ่งจากค่าตัวนับปัจจุบัน
procedure BuildSerialBytes(const S: TProdSettings; out Bytes: array of byte);

//วางเลขลงบัฟเฟอร์ คืน False ถ้าเลขไม่พอดีกับบัฟเฟอร์
function ApplySerial(const S: TProdSettings; var Data: array of byte;
  DataSize: cardinal): boolean;

//รูปแบบที่อ่านออกของเลขรันนิ่ง ใช้ตอนเขียน log
function SerialToStr(const S: TProdSettings): string;

implementation

procedure DefaultProdSettings(out S: TProdSettings);
begin
  S.SNEnabled := False;
  S.SNAddress := 0;
  S.SNLength := 4;
  S.SNMode := smIncrement;
  S.SNValue := 1;
  S.SNStep := 1;
  S.SNBigEndian := True;
  S.SNLogFile := 'serials.log';

  S.BatchEnabled := False;
  S.BatchTarget := 10;
end;

function ToBCD(V: byte): byte;
begin
  Result := byte(((V div 10) shl 4) or (V mod 10));
end;

procedure BuildSerialBytes(const S: TProdSettings; out Bytes: array of byte);
var
  i, CounterBytes, Offset: integer;
  V: QWord;
  Y, M, D: word;
  t: byte;
begin
  FillByte(Bytes[0], S.SNLength, 0);

  case S.SNMode of

    smRandom:
      for i := 0 to S.SNLength - 1 do
        Bytes[i] := byte(Random(256));

    smDateIncrement:
      begin
        DecodeDate(Date, Y, M, D);

        //วันที่กินไป 3 ไบต์ ใส่ได้ต่อเมื่อเลขยาวพอ
        if S.SNLength >= 4 then
        begin
          Bytes[0] := ToBCD(byte(Y mod 100));
          Bytes[1] := ToBCD(byte(M));
          Bytes[2] := ToBCD(byte(D));
          Offset := 3;
        end
        else
          Offset := 0;

        CounterBytes := S.SNLength - Offset;
        V := S.SNValue;

        for i := CounterBytes - 1 downto 0 do
        begin
          Bytes[Offset + i] := byte(V and $FF);
          V := V shr 8;
        end;
      end;

  else  //smIncrement
    begin
      V := S.SNValue;
      for i := S.SNLength - 1 downto 0 do
      begin
        Bytes[i] := byte(V and $FF);
        V := V shr 8;
      end;
    end;
  end;

  //ไบต์ถูกเรียงสูงขึ้นก่อน ถ้าต้องการสลับก็กลับด้านตรงนี้
  if not S.SNBigEndian then
    for i := 0 to (S.SNLength div 2) - 1 do
    begin
      t := Bytes[i];
      Bytes[i] := Bytes[S.SNLength - 1 - i];
      Bytes[S.SNLength - 1 - i] := t;
    end;
end;

function ApplySerial(const S: TProdSettings; var Data: array of byte;
  DataSize: cardinal): boolean;
var
  Bytes: array[0..7] of byte;
  i: integer;
begin
  Result := False;
  if (not S.SNEnabled) or (S.SNLength < 1) or (S.SNLength > 8) then Exit;
  if S.SNAddress + S.SNLength > DataSize then Exit;

  BuildSerialBytes(S, Bytes);

  for i := 0 to S.SNLength - 1 do
    Data[S.SNAddress + cardinal(i)] := Bytes[i];

  Result := True;
end;

function SerialToStr(const S: TProdSettings): string;
var
  Bytes: array[0..7] of byte;
  i: integer;
begin
  BuildSerialBytes(S, Bytes);
  Result := '';
  for i := 0 to S.SNLength - 1 do
    Result := Result + IntToHex(Bytes[i], 2);
end;

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
