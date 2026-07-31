unit search;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, StdCtrls,
  Menus, utilfunc;

type

  { TSearchForm }

  TSearchForm = class(TForm)
    CaseSenseCheckBox: TCheckBox;
    ReplaceAllCheckBox: TCheckBox;
    ReplaceCheckBox: TCheckBox;
    ReplaceEdit: TEdit;
    FromBeginingCheckBox: TCheckBox;
    FindButton: TButton;
    HexCheckBox: TCheckBox;
    ReplaceLabel: TLabel;
    SearchLabel: TLabel;
    TextToFindEdit: TEdit;
    procedure FindButtonClick(Sender: TObject);
  private
    { private declarations }
  public
    { public declarations }
  end;

var
  SearchForm: TSearchForm;

implementation

uses main, msgstr;

{$R *.lfm}


{ TSearchForm }
procedure TSearchForm.FindButtonClick(Sender: TObject);
var
  s, r: PChar;
  shex, rhex: ansistring;
  FoundPosition, StrLen, RStrLen, SearchStartPos: integer;
  FirstSearch: boolean = true;
begin

 StrLen := Length(TextToFindEdit.Text);
 RStrLen := Length(ReplaceEdit.Text);
 if StrLen = 0 then Exit;

 s := PChar(MainForm.MPHexEditorEx.PrepareFindReplaceData(UTF8ToAnsi(TextToFindEdit.Text), not CaseSenseCheckBox.Checked, true));

 if HexCheckBox.Checked then
 begin
   //ครึ่งไบต์ที่ค้าง หรือตัวอักษรที่ไม่ใช่ฐานสิบหก ต้องถูกปฏิเสธ ไม่งั้น
   //จะไปค้นด้วยบัฟเฟอร์ที่ครึ่งหนึ่งไม่เคยถูกเติมค่า แล้ว "เจอ" ตำแหน่งมั่ว
   if Odd(StrLen) then
   begin
     ShowMessage('the hex search pattern has an odd number of digits');
     Exit;
   end;
   StrLen := StrLen div 2;
   SetLength(shex, StrLen);
   if HexTobin(s, PChar(shex), StrLen) <> StrLen then
   begin
     ShowMessage('the search pattern is not valid hex');
     Exit;
   end;
 end;

 if ((ReplaceCheckBox.Checked) or (ReplaceAllCheckBox.Checked)) then
 begin
   r := Pchar(UTF8ToAnsi(ReplaceEdit.Text));
   if HexCheckBox.Checked then
   begin
     if Odd(RStrLen) then
     begin
       ShowMessage('the hex replacement has an odd number of digits');
       Exit;
     end;
     RStrLen := RStrLen div 2;
     SetLength(rhex, RStrLen);
     if HexTobin(r, PChar(rhex), RStrLen) <> RStrLen then
     begin
       ShowMessage('the replacement is not valid hex');
       Exit;
     end;
   end;
 end;

 if FromBeginingCheckBox.Checked then
   SearchStartPos := 0
 else
   SearchStartPos := MainForm.MPHexEditorEx.SelStart+1;

 repeat
   if HexCheckBox.Checked then
     FoundPosition := MainForm.MPHexEditorEx.Find(PChar(shex), StrLen, SearchStartPos, MainForm.MPHexEditorEx.DataSize-1, false)
   else
     FoundPosition := MainForm.MPHexEditorEx.Find(s, StrLen, SearchStartPos, MainForm.MPHexEditorEx.DataSize-1, not CaseSenseCheckBox.Checked);

   if FoundPosition >= 0 then
   begin
     FirstSearch := false;
     if not ReplaceAllCheckBox.Checked then
     begin
       MainForm.MPHexEditorEx.SelStart:= FoundPosition;
       MainForm.MPHexEditorEx.SelEnd:= FoundPosition+StrLen-1;
     end;
   end
   else
   begin
     if FirstSearch then ShowMessage(STR_NOT_FOUND_HEX);
     Exit;
   end;

   if ((ReplaceCheckBox.Checked) or (ReplaceAllCheckBox.Checked)) then
   begin
     if HexCheckBox.Checked then
       MainForm.MPHexEditorEx.Replace(PChar(rhex), FoundPosition, StrLen, RStrLen)
     else
       MainForm.MPHexEditorEx.Replace(r, FoundPosition, StrLen, RStrLen);
     //Find นับตำแหน่งเริ่มแบบรวมปลายทั้งสองข้าง การบวกเผื่ออีกหนึ่งเคยทำให้
     //คู่ที่ติดกันถูกข้าม (FF FF FF FF เหลือไบต์ 1 กับ 3 ไม่ถูกแทน) และ
     //หลังแทนที่แล้วข้อมูลเลื่อนตามขนาดใหม่ จึงต้องไล่ต่อจากท้ายของ
     //ข้อความใหม่ ไม่ใช่ท้ายของข้อความเก่า
     SearchStartPos := FoundPosition + RStrLen;
   end
   else
     SearchStartPos := FoundPosition + StrLen;
 until (not ReplaceAllCheckBox.Checked);

end;


end.

