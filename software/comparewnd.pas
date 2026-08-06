unit comparewnd;

//หน้าต่างเทียบข้อมูลสองฝั่งแบบเรียงคู่
//
//ก่อนหน้านี้ผลการเทียบมีแต่ข้อความใน log กับการไฮไลท์ในตารางกลาง
//ซึ่งเห็นได้ทีละฝั่ง ไม่รู้ว่าอีกฝั่งเป็นค่าอะไร หน้าต่างนี้เอาทั้งสองฝั่ง
//มาวางคู่กัน เลื่อนพร้อมกัน และระบายสีไบต์ที่ต่างกันทั้งสองข้าง
//
//สร้างด้วยโค้ด ไม่ได้มาจาก .lfm ด้วยเหตุผลเดียวกับ prodconfig
//คือถ้าไฟล์ฟอร์มมีปัญหา โปรแกรมจะเปิดไม่ขึ้นทั้งตัว แบบนี้พังได้แค่หน้าต่างนี้

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, ExtCtrls, StdCtrls, ComCtrls,
  Dialogs, LCLType, MPHexEditorEx, MPHexEditor;

//เปิดหน้าต่างเทียบ ฝั่ง A กับฝั่ง B ต้องยาวเท่ากันตามค่า Size
//TitleA และ TitleB คือข้อความหัวคอลัมน์ เช่นชื่อไฟล์พร้อมขนาดและ CRC32
procedure ShowCompareWindow(const TitleA, TitleB: string;
                            const A, B: array of byte; Size: integer);

implementation

const
  //จำนวนช่วงที่ยอมเก็บไว้ให้กระโดด มากกว่านี้คือไฟล์คนละเรื่องกัน
  //ไม่มีประโยชน์ที่จะไล่ทีละช่วงอยู่แล้ว
  MaxRanges = 5000;

type

  TCompareForm = class(TForm)
  private
    EdA, EdB: TMPHexEditorEx;
    LblA, LblB: TLabel;
    CbJump: TComboBox;
    ChkSync: TCheckBox;
    LblSummary: TLabel;
    Status: TStatusBar;

    //ตำแหน่งเริ่มต้นของแต่ละช่วงที่ต่างกัน ใช้ตอนกดข้ามไปช่วงถัดไป
    Ranges: array of integer;
    DataA, DataB: array of byte;
    Syncing: boolean;

    //ชื่อสองฝั่งแบบไม่มีตัวอักษร A B นำหน้า ใช้ตอนเขียนรายงาน
    NameA, NameB: string;

    procedure BuildUI;
    procedure TopLeftChanged(Sender: TObject);
    procedure SelChanged(Sender: TObject);
    procedure PrevClick(Sender: TObject);
    procedure NextClick(Sender: TObject);
    procedure JumpSelect(Sender: TObject);
    procedure SaveReportClick(Sender: TObject);
    procedure FormKey(Sender: TObject; var Key: word; Shift: TShiftState);
    procedure GoTo_(Ofs: integer);
    procedure ShowStatusFor(Ofs: integer);
  public
    constructor CreateCompare(AOwner: TComponent);
    procedure Fill(const TitleA, TitleB: string;
                   const A, B: array of byte; Size: integer);
  end;

var
  //หน้าต่างเดียวใช้ซ้ำ เทียบครั้งใหม่ก็แทนที่ของเดิม ไม่ใช่เปิดกองขึ้นมาเรื่อย ๆ
  CompareForm: TCompareForm = nil;

//ตั้งค่าตัวแก้ไขเลขฐานสิบหกให้เหมือนกับตารางกลางของหน้าต่างหลัก
//คนที่ชินกับตารางกลางอยู่แล้วจะได้ไม่ต้องเรียนรู้ใหม่
function MakeEditor(Parent: TWinControl): TMPHexEditorEx;
begin
  Result := TMPHexEditorEx.Create(Parent);
  Result.Parent := Parent;
  Result.Align := alClient;
  Result.BorderStyle := bsNone;
  Result.Font.Name := 'Courier New';
  Result.Font.Height := -13;
  Result.Font.Pitch := fpFixed;
  Result.Font.Style := [fsBold];
  Result.ParentFont := False;
  Result.BytesPerRow := 16;
  Result.BytesPerColumn := 1;
  Result.BytesPerBlock := 8;
  Result.Translation := tkASCII;
  Result.OffsetFormat := '8!10:0x|';
  Result.DrawGridLines := True;
  Result.ShowRuler := True;
  Result.DrawGutter3D := False;
  Result.FocusFrame := True;
  Result.NoSizeChange := True;

  //อ่านอย่างเดียว หน้าต่างนี้มีไว้ดู ไม่ได้มีไว้แก้
  //ถ้าแก้ได้จะเผลอแก้แล้วเข้าใจผิดว่าข้อมูลจริงเปลี่ยนตาม
  Result.ReadOnlyView := True;

  Result.Colors.Background := clWindow;
  Result.Colors.Offset := clBlack;
  Result.Colors.OddColumn := clNavy;
  Result.Colors.EvenColumn := clNavy;
  Result.Colors.OffsetBackground := clBtnFace;
  Result.Colors.CurrentOffsetBackground := clBtnShadow;
  Result.Colors.CurrentOffset := clBtnHighlight;
  Result.Colors.Grid := clBtnFace;
  Result.Colors.CursorFrame := clNavy;
  Result.Colors.NonFocusCursorFrame := clAqua;
  Result.Colors.ActiveFieldBackground := clWindow;

  //สีของไบต์ที่ต่างกัน เลือกโทนแดงเพราะตารางกลางใช้โทนเหลืองไปแล้ว
  //จะได้ไม่สับสนว่ากำลังดูหน้าต่างไหนอยู่
  Result.Colors.ChangedBackground := TColor($C6C6FF);   //RGB(255,198,198)
  Result.Colors.ChangedText := clMaroon;
end;

function MakeButton(Parent: TWinControl; ALeft, ATop, AWidth: integer;
                    const ACaption: string; AClick: TNotifyEvent): TButton;
begin
  Result := TButton.Create(Parent);
  Result.Parent := Parent;
  Result.Left := ALeft;
  Result.Top := ATop;
  Result.Width := AWidth;
  Result.Height := 26;
  Result.Caption := ACaption;
  Result.OnClick := AClick;
end;

constructor TCompareForm.CreateCompare(AOwner: TComponent);
begin
  inherited CreateNew(AOwner);
  BuildUI;
end;

procedure TCompareForm.BuildUI;
var
  Bar, PanA, PanB: TPanel;
  Split: TSplitter;
begin
  Caption := 'Compare';
  Position := poScreenCenter;

  //หนึ่งบรรทัดของตารางกินราว 620 พิกเซล สองบานจึงต้องการราว 1300
  //ถ้าจอแคบกว่านั้นก็เอาเท่าที่จอมี แล้วให้เลื่อนแนวนอนเอา
  ClientWidth := 1320;
  if ClientWidth > Screen.WorkAreaWidth - 40 then
    ClientWidth := Screen.WorkAreaWidth - 40;

  ClientHeight := 720;
  if ClientHeight > Screen.WorkAreaHeight - 60 then
    ClientHeight := Screen.WorkAreaHeight - 60;

  KeyPreview := True;
  OnKeyDown := @FormKey;

  Bar := TPanel.Create(Self);
  Bar.Parent := Self;
  Bar.Align := alTop;
  Bar.Height := 40;
  Bar.BevelOuter := bvNone;

  MakeButton(Bar, 8, 7, 150, 'Previous difference', @PrevClick);
  MakeButton(Bar, 164, 7, 150, 'Next difference', @NextClick);

  CbJump := TComboBox.Create(Bar);
  CbJump.Parent := Bar;
  CbJump.Left := 322;
  CbJump.Top := 8;
  CbJump.Width := 230;
  CbJump.Style := csDropDownList;
  CbJump.OnChange := @JumpSelect;

  ChkSync := TCheckBox.Create(Bar);
  ChkSync.Parent := Bar;
  ChkSync.Left := 562;
  ChkSync.Top := 11;
  ChkSync.Width := 110;
  ChkSync.Caption := 'Sync scrolling';
  ChkSync.Checked := True;

  MakeButton(Bar, 680, 7, 110, 'Save report...', @SaveReportClick);

  LblSummary := TLabel.Create(Bar);
  LblSummary.Parent := Bar;
  LblSummary.Left := 800;
  LblSummary.Top := 12;
  LblSummary.Anchors := [akLeft, akTop, akRight];
  LblSummary.AutoSize := False;
  LblSummary.Width := 360;

  Status := TStatusBar.Create(Self);
  Status.Parent := Self;
  Status.SimplePanel := True;

  //ฝั่ง A อยู่ซ้าย กว้างครึ่งหนึ่ง ลากเส้นแบ่งย้ายได้
  PanA := TPanel.Create(Self);
  PanA.Parent := Self;
  PanA.Align := alLeft;
  PanA.Width := ClientWidth div 2;
  PanA.BevelOuter := bvNone;

  Split := TSplitter.Create(Self);
  Split.Parent := Self;
  Split.Align := alLeft;
  Split.Left := PanA.Width + 1;

  PanB := TPanel.Create(Self);
  PanB.Parent := Self;
  PanB.Align := alClient;
  PanB.BevelOuter := bvNone;

  LblA := TLabel.Create(PanA);
  LblA.Parent := PanA;
  LblA.Align := alTop;
  LblA.Height := 22;
  LblA.Layout := tlCenter;
  LblA.Font.Style := [fsBold];
  //สองฝั่งใช้สีหัวคนละสี จะได้ไม่ต้องอ่านตัวอักษรก่อนว่ากำลังดูฝั่งไหน
  LblA.Font.Color := TColor($8A4A18);   //น้ำเงินเข้ม RGB(24,74,138)
  LblA.Caption := ' A';

  LblB := TLabel.Create(PanB);
  LblB.Parent := PanB;
  LblB.Align := alTop;
  LblB.Height := 22;
  LblB.Layout := tlCenter;
  LblB.Font.Style := [fsBold];
  LblB.Font.Color := TColor($0A6ED1);   //ส้มเข้ม RGB(209,110,10)
  LblB.Caption := ' B';

  EdA := MakeEditor(PanA);
  EdB := MakeEditor(PanB);

  EdA.OnTopLeftChanged := @TopLeftChanged;
  EdB.OnTopLeftChanged := @TopLeftChanged;
  EdA.OnSelectionChanged := @SelChanged;
  EdB.OnSelectionChanged := @SelChanged;
end;

//เลื่อนฝั่งหนึ่งแล้วอีกฝั่งตามไปด้วย ตัวแปร Syncing กันไม่ให้เรียกวนกลับมา
procedure TCompareForm.TopLeftChanged(Sender: TObject);
begin
  if Syncing or not ChkSync.Checked then Exit;

  Syncing := True;
  try
    if Sender = EdA then
    begin
      EdB.TopRow := EdA.TopRow;
      EdB.LeftCol := EdA.LeftCol;
    end
    else
    begin
      EdA.TopRow := EdB.TopRow;
      EdA.LeftCol := EdB.LeftCol;
    end;
  finally
    Syncing := False;
  end;
end;

//แถบล่างบอกว่าตำแหน่งที่เคอร์เซอร์อยู่ ทั้งสองฝั่งเป็นค่าอะไร
//เป็นคำถามแรกที่คนถามเสมอเวลาเห็นไบต์ที่ต่างกัน
procedure TCompareForm.ShowStatusFor(Ofs: integer);
var
  s: string;
begin
  if (Ofs < 0) or (Ofs >= Length(DataA)) then
  begin
    Status.SimpleText := '';
    Exit;
  end;

  s := 'Offset 0x' + IntToHex(Ofs, 8) +
       '   A = ' + IntToHex(DataA[Ofs], 2) + 'h' +
       '   B = ' + IntToHex(DataB[Ofs], 2) + 'h';

  if DataA[Ofs] <> DataB[Ofs] then
    s := s + '   different'
  else
    s := s + '   equal';

  Status.SimpleText := s;
end;

procedure TCompareForm.SelChanged(Sender: TObject);
begin
  if Syncing then Exit;

  Syncing := True;
  try
    //เคอร์เซอร์อีกฝั่งตามมาด้วย จะได้เทียบไบต์ตรงตำแหน่งเดียวกัน
    if Sender = EdA then
    begin
      if ChkSync.Checked then EdB.SelStart := EdA.SelStart;
      ShowStatusFor(EdA.SelStart);
    end
    else
    begin
      if ChkSync.Checked then EdA.SelStart := EdB.SelStart;
      ShowStatusFor(EdB.SelStart);
    end;
  finally
    Syncing := False;
  end;
end;

procedure TCompareForm.GoTo_(Ofs: integer);
var
  Row: integer;
begin
  if (Ofs < 0) or (Ofs >= Length(DataA)) then Exit;

  Syncing := True;
  try
    //เลื่อนให้บรรทัดเป้าหมายอยู่ห่างจากขอบบนสี่บรรทัด จะได้เห็นบริบทรอบ ๆ ด้วย
    Row := Ofs div EdA.BytesPerRow - 4;
    if Row < 0 then Row := 0;

    EdA.SelStart := Ofs;
    EdB.SelStart := Ofs;
    EdA.TopRow := Row;
    EdB.TopRow := Row;
  finally
    Syncing := False;
  end;

  ShowStatusFor(Ofs);
end;

procedure TCompareForm.NextClick(Sender: TObject);
var
  i, Cur: integer;
begin
  if Length(Ranges) = 0 then Exit;

  Cur := EdA.SelStart;
  for i := 0 to High(Ranges) do
    if Ranges[i] > Cur then
    begin
      CbJump.ItemIndex := i;
      GoTo_(Ranges[i]);
      Exit;
    end;

  //วนกลับไปช่วงแรก จะได้ไม่ต้องเลื่อนกลับขึ้นไปเอง
  CbJump.ItemIndex := 0;
  GoTo_(Ranges[0]);
end;

procedure TCompareForm.PrevClick(Sender: TObject);
var
  i, Cur: integer;
begin
  if Length(Ranges) = 0 then Exit;

  Cur := EdA.SelStart;
  for i := High(Ranges) downto 0 do
    if Ranges[i] < Cur then
    begin
      CbJump.ItemIndex := i;
      GoTo_(Ranges[i]);
      Exit;
    end;

  CbJump.ItemIndex := High(Ranges);
  GoTo_(Ranges[High(Ranges)]);
end;

procedure TCompareForm.JumpSelect(Sender: TObject);
begin
  if (CbJump.ItemIndex >= 0) and (CbJump.ItemIndex <= High(Ranges)) then
    GoTo_(Ranges[CbJump.ItemIndex]);
end;

procedure TCompareForm.FormKey(Sender: TObject; var Key: word; Shift: TShiftState);
begin
  if Key = VK_ESCAPE then
  begin
    Close;
    Key := 0;
  end
  else if Key = VK_F3 then
  begin
    if ssShift in Shift then PrevClick(nil) else NextClick(nil);
    Key := 0;
  end;
end;

//รายงานเป็นข้อความ เอาไปแนบใบตรวจงานหรือส่งต่อได้
procedure TCompareForm.SaveReportClick(Sender: TObject);
var
  Dlg: TSaveDialog;
  L: TStringList;
  i, RunStart: integer;
begin
  Dlg := TSaveDialog.Create(nil);
  L := TStringList.Create;
  try
    Dlg.Title := 'Save the compare report';
    Dlg.Filter := 'Text file|*.txt|All files|*.*';
    Dlg.DefaultExt := 'txt';
    Dlg.FileName := 'compare-report.txt';
    Dlg.Options := Dlg.Options + [ofOverwritePrompt];
    if not Dlg.Execute then Exit;

    L.Add('Chipwright, compare report');
    L.Add('A: ' + NameA);
    L.Add('B: ' + NameB);
    L.Add(Trim(LblSummary.Caption));
    L.Add('');
    L.Add('offset start  offset end    length  A      B');

    i := 0;
    while i < Length(DataA) do
    begin
      if DataA[i] <> DataB[i] then
      begin
        RunStart := i;
        while (i < Length(DataA)) and (DataA[i] <> DataB[i]) do Inc(i);
        L.Add('0x' + IntToHex(RunStart, 8) + '    0x' + IntToHex(i - 1, 8) +
              '    ' + Format('%6d', [i - RunStart]) +
              '  ' + IntToHex(DataA[RunStart], 2) + 'h    ' +
              IntToHex(DataB[RunStart], 2) + 'h');
      end
      else
        Inc(i);
    end;

    L.SaveToFile(Dlg.FileName);
  finally
    L.Free;
    Dlg.Free;
  end;
end;

procedure TCompareForm.Fill(const TitleA, TitleB: string;
                            const A, B: array of byte; Size: integer);
var
  S: TMemoryStream;
  i, DiffCount, RunStart, Shown: integer;
begin
  SetLength(DataA, Size);
  SetLength(DataB, Size);
  if Size > 0 then
  begin
    Move(A[0], DataA[0], Size);
    Move(B[0], DataB[0], Size);
  end;

  NameA := TitleA;
  NameB := TitleB;
  LblA.Caption := ' A   ' + TitleA;
  LblB.Caption := ' B   ' + TitleB;

  S := TMemoryStream.Create;
  try
    S.WriteBuffer(DataA[0], Size);
    S.Position := 0;
    EdA.LoadFromStream(S);

    S.Clear;
    S.WriteBuffer(DataB[0], Size);
    S.Position := 0;
    EdB.LoadFromStream(S);
  finally
    S.Free;
  end;

  //ทำเครื่องหมายไบต์ที่ต่างกันทั้งสองฝั่ง ตัวแก้ไขจะระบายสีให้เอง
  //ต้องใช้ ByteChanged ไม่ใช่เขียนทับข้อมูล เพราะการเขียนไม่ได้ตั้งบิตนี้
  //และยังสร้างรายการย้อนกลับทีละไบต์จนช้าเป็นนาทีในไฟล์ใหญ่
  SetLength(Ranges, 0);
  DiffCount := 0;
  i := 0;
  while i < Size do
  begin
    if DataA[i] <> DataB[i] then
    begin
      RunStart := i;
      while (i < Size) and (DataA[i] <> DataB[i]) do
      begin
        EdA.ByteChanged[i] := True;
        EdB.ByteChanged[i] := True;
        Inc(DiffCount);
        Inc(i);
      end;

      if Length(Ranges) < MaxRanges then
      begin
        SetLength(Ranges, Length(Ranges) + 1);
        Ranges[High(Ranges)] := RunStart;
      end;
    end
    else
      Inc(i);
  end;

  CbJump.Items.BeginUpdate;
  try
    CbJump.Items.Clear;
    //รายการที่กระโดดได้จำกัดไว้ ไม่งั้นเปิดรายการทีเดียวค้างเป็นวินาที
    Shown := High(Ranges);
    if Shown > 499 then Shown := 499;
    for i := 0 to Shown do
      CbJump.Items.Add(IntToStr(i + 1) + ':  0x' + IntToHex(Ranges[i], 8));
  finally
    CbJump.Items.EndUpdate;
  end;

  if DiffCount = 0 then
  begin
    LblSummary.Font.Color := TColor($2E8B2E);
    LblSummary.Caption := 'Identical: all ' + IntToStr(Size) + ' bytes match';
  end
  else
  begin
    LblSummary.Font.Color := clMaroon;
    LblSummary.Caption := IntToStr(DiffCount) + ' of ' + IntToStr(Size) +
                          ' bytes differ, in ' + IntToStr(Length(Ranges)) + ' ranges';
    if Length(Ranges) >= MaxRanges then
      LblSummary.Caption := LblSummary.Caption + '+';
  end;

  EdA.Invalidate;
  EdB.Invalidate;

  //เปิดมาที่ความต่างจุดแรกเลย ไม่ต้องให้ผู้ใช้ไล่หาเอง
  if Length(Ranges) > 0 then
  begin
    CbJump.ItemIndex := 0;
    GoTo_(Ranges[0]);
  end
  else
    ShowStatusFor(0);
end;

procedure ShowCompareWindow(const TitleA, TitleB: string;
                            const A, B: array of byte; Size: integer);
begin
  if Size <= 0 then Exit;

  if CompareForm = nil then
    CompareForm := TCompareForm.CreateCompare(Application);

  CompareForm.Fill(TitleA, TitleB, A, B, Size);
  CompareForm.Show;
  CompareForm.BringToFront;
end;

end.
