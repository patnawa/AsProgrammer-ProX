unit chipsave;

//บันทึกชิปที่ตรวจเจอลงตารางชิปของผู้ใช้
//
//เขียนลง chiplist-user.xml ไม่ใช่ chiplist.xml ที่แจกมากับโปรแกรม โดยตั้งใจ
//ไฟล์ที่แจกมามีพันกว่าบรรทัดที่คนอื่นดูแลอยู่ ถ้าเขียนพลาดกลางไฟล์
//โปรแกรมจะเปิดตารางชิปไม่ขึ้นทั้งไฟล์ ส่วนไฟล์ของผู้ใช้พังได้แค่ของตัวเอง
//และอัปเดตโปรแกรมทับก็ไม่หาย

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, DOM, XMLRead, XMLWrite;

const
  UserChipListName = 'chiplist-user.xml';

type
  TSaveChipParams = record
    Vendor: string;      //ชื่อกลุ่มผู้ผลิต ว่างได้ จะใช้ USER แทน
    Name: string;
    ID: string;          //เลขฐานสิบหก ว่างได้
    Size: cardinal;
    Page: cardinal;
    Sector: cardinal;    //0 = ไม่ระบุ
    SectorCmd: byte;     //0 = ไม่ระบุ
    Note: string;
  end;

//ชื่อธาตุ XML ที่ปลอดภัย ชื่อชิปบางตัวมีอักขระที่ใช้เป็นชื่อธาตุไม่ได้
function SafeElementName(const S: string): string;

//บันทึกหรือทับของเดิมที่ชื่อซ้ำ คืน False พร้อมเหตุผลเมื่อทำไม่ได้
function SaveChipToUserList(const FileName: string; const P: TSaveChipParams;
  out ErrMsg: string): boolean;

implementation

function SafeElementName(const S: string): string;
var
  i: integer;
  C: char;
begin
  Result := '';

  for i := 1 to Length(S) do
  begin
    C := S[i];
    if (C in ['A'..'Z', 'a'..'z', '0'..'9', '_', '.', '-']) then
      Result := Result + C
    else
      Result := Result + '_';
  end;

  if Result = '' then Result := 'CHIP';

  //ชื่อธาตุห้ามขึ้นต้นด้วยตัวเลข จุด หรือขีด
  if Result[1] in ['0'..'9', '.', '-'] then Result := '_' + Result;
end;

//หาธาตุลูกตามชื่อ สร้างใหม่ถ้ายังไม่มี
function ChildByName(Doc: TXMLDocument; Parent: TDOMNode;
  const Name: string): TDOMNode;
var
  i: integer;
begin
  Result := nil;

  for i := 0 to Parent.ChildNodes.Count - 1 do
    if Parent.ChildNodes[i].NodeName = Name then
      Exit(Parent.ChildNodes[i]);

  Result := Doc.CreateElement(Name);
  Parent.AppendChild(Result);
end;

function SaveChipToUserList(const FileName: string; const P: TSaveChipParams;
  out ErrMsg: string): boolean;
var
  Doc: TXMLDocument;
  Root, SPINode, VendorNode, ChipNode: TDOMNode;
  ElemName, VendorName: string;
  i: integer;
begin
  Result := False;
  ErrMsg := '';
  Doc := nil;

  if Trim(P.Name) = '' then
  begin
    ErrMsg := 'the chip has no name';
    Exit;
  end;

  if P.Size = 0 then
  begin
    ErrMsg := 'the chip size is not known';
    Exit;
  end;

  ElemName := SafeElementName(P.Name);
  VendorName := SafeElementName(Trim(P.Vendor));
  if Trim(P.Vendor) = '' then VendorName := 'USER';

  try
    try
      if FileExists(FileName) then
        ReadXMLFile(Doc, FileName)
      else
        Doc := TXMLDocument.Create;
    except
      on E: Exception do
      begin
        //ไฟล์เดิมเสีย อย่าเขียนทับเงียบ ๆ ผู้ใช้อาจมีชิปที่เพิ่มเองอยู่ในนั้น
        ErrMsg := 'cannot read ' + FileName + ': ' + E.Message;
        Exit;
      end;
    end;

    Root := Doc.DocumentElement;
    if Root = nil then
    begin
      Root := Doc.CreateElement('chiplist');
      Doc.AppendChild(Root);
    end;

    SPINode := ChildByName(Doc, Root, 'SPI');
    VendorNode := ChildByName(Doc, SPINode, VendorName);

    //ชื่อซ้ำให้ทับของเดิม ไม่ใช่เพิ่มอีกตัว ไม่งั้นตารางจะมีชื่อซ้ำสองรายการ
    ChipNode := nil;
    for i := 0 to VendorNode.ChildNodes.Count - 1 do
      if VendorNode.ChildNodes[i].NodeName = ElemName then
      begin
        ChipNode := VendorNode.ChildNodes[i];
        Break;
      end;

    if ChipNode = nil then
    begin
      ChipNode := Doc.CreateElement(ElemName);
      VendorNode.AppendChild(ChipNode);
    end;

    TDOMElement(ChipNode).SetAttribute('id', UpperCase(Trim(P.ID)));
    TDOMElement(ChipNode).SetAttribute('page', IntToStr(P.Page));
    TDOMElement(ChipNode).SetAttribute('size', IntToStr(P.Size));

    if P.Sector > 0 then
      TDOMElement(ChipNode).SetAttribute('sector', IntToStr(P.Sector));
    if P.SectorCmd > 0 then
      TDOMElement(ChipNode).SetAttribute('sectorcmd', IntToHex(P.SectorCmd, 2));
    if Trim(P.Note) <> '' then
      TDOMElement(ChipNode).SetAttribute('note', Trim(P.Note));

    try
      WriteXMLFile(Doc, FileName);
    except
      on E: Exception do
      begin
        ErrMsg := 'cannot write ' + FileName + ': ' + E.Message;
        Exit;
      end;
    end;

    Result := True;
  finally
    Doc.Free;
  end;
end;

end.
