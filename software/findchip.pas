unit findchip;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, StdCtrls,
  ExtCtrls, dom, utilfunc, lazUTF8, Masks;

type

  { TChipSearchForm }

  TChipSearchForm = class(TForm)
    Bevel1: TBevel;
    ChipSearchSelectButton: TButton;
    EditSearch: TEdit;
    Label1: TLabel;
    ListBoxChips: TListBox;
    procedure ChipSearchSelectButtonClick(Sender: TObject);
    procedure EditSearchChange(Sender: TObject);
    procedure ListBoxChipsDblClick(Sender: TObject);
  private
    { ส่วนประกาศแบบ private }
  public
    { ส่วนประกาศแบบ public }
  end;

  procedure FindChip(XMLfile: TXMLDocument; chipname: string; chipid: string = '');

  //คืน True เมื่อเจอชิปชื่อนี้ในไฟล์และตั้งค่าให้แล้ว
  //ต้องรู้ผลเพราะรายชื่อชิปอาจมาจากไฟล์มากกว่าหนึ่งไฟล์
  function SelectChip(XMLfile: TXMLDocument; chipname: string): boolean;

  //เหมือน FindChip แต่ใส่ผลลงในลิสต์ที่ส่งมา ไม่ยุ่งกับหน้าต่างค้นหาและ log
  //ใช้ตอนตรวจหาชิปอัตโนมัติ ซึ่งต้องนับจำนวนผลก่อนจะตัดสินใจ
  procedure FindChipInto(XMLfile: TXMLDocument; chipname, chipid: string; Dest: TStrings);

var
  ChipSearchForm: TChipSearchForm;

implementation

uses main, scriptsfunc;

{$R *.lfm}

//เทียบชื่อชิปกับคำค้น
//ถ้าคำค้นมี * หรือ ? จะเทียบแบบ wildcard เช่น 25q*1.8 หา 25Q ที่เป็นชิป 1.8V
//ถ้าไม่มี ก็หาแบบข้อความย่อยเหมือนเดิม
function ChipNameMatches(const ChipName, Query: string): boolean;
begin
  if Query = '' then Exit(True);

  if (Pos('*', Query) > 0) or (Pos('?', Query) > 0) then
  begin
    try
      Result := MatchesMask(UpCase(ChipName), UpCase(Query));
    except
      Result := False;   //คำค้นที่รูปแบบผิดไม่ควรทำให้โปรแกรมล้ม
    end;
  end
  else
    Result := Pos(UpCase(Query), UpCase(ChipName)) > 0;
end;

//แอตทริบิวต์ตัวเลขที่พิมพ์ผิดในตารางชิป (รวมตารางผู้ใช้ซึ่งแก้ด้วยมือได้)
//ต้องไม่พาโปรแกรมล้มทั้งตัว: StrToInt ที่ไม่มีการ์ดยกข้อยกเว้น แล้วโหมด
//บรรทัดคำสั่งจะตายด้วย runtime error 217 แทน exit code อ่านไม่ออกก็ถือว่า
//ไม่ได้ระบุ
function AttrInt(Node: TDOMNode; const AttrName: string; Def: integer): integer;
var
  S: string;
begin
  Result := Def;
  if Node.Attributes.GetNamedItem(AttrName) = nil then Exit;
  S := UTF16ToUTF8(Node.Attributes.GetNamedItem(AttrName).NodeValue);
  if not TryStrToInt(S, Result) then Result := Def;
end;
procedure FindChipInto(XMLfile: TXMLDocument; chipname, chipid: string; Dest: TStrings);
var
  Node, ChipNode: TDOMNode;
  j, i: integer;
  cs: string;
begin
  if XMLfile = nil then Exit;
  if Dest = nil then Exit;

  Node := XMLfile.DocumentElement.FirstChild;

  while Assigned(Node) do
  begin
    with Node.ChildNodes do
    try
      for j := 0 to (Count - 1) do
        for i := 0 to (Item[j].ChildNodes.Count - 1) do
        begin
          ChipNode := Item[j].ChildNodes.Item[i];
          //คอมเมนต์ในไฟล์ XML ก็เป็นโหนดลูกเหมือนกัน ต้องไม่ถูกนับเป็นชิป
          //(เคยเห็นแถว "#comment (ZEMPRO)" โผล่ในหน้าต่างค้นหา)
          if ChipNode.NodeType <> ELEMENT_NODE then Continue;

          if chipid <> '' then
          begin
            if ChipNode.HasAttributes then
              if ChipNode.Attributes.GetNamedItem('id') <> nil then
              begin
                cs := UTF16ToUTF8(ChipNode.Attributes.GetNamedItem('id').NodeValue);
                if UpCase(cs) = UpCase(chipid) then
                  Dest.Add(UTF16ToUTF8(ChipNode.NodeName) + ' (' +
                           UTF16ToUTF8(Item[j].NodeName) + ')');
              end;
          end
          else
          begin
            cs := UTF16ToUTF8(ChipNode.NodeName);
            if ChipNameMatches(cs, chipname) then
              Dest.Add(cs + ' (' + UTF16ToUTF8(Item[j].NodeName) + ')');
          end;
        end;
    finally
      Free;
    end;
    Node := Node.NextSibling;
  end;
end;

//ค้นหาชิปจากชื่อ ถ้า id ไม่ว่างจะค้นจาก id อย่างเดียว
procedure FindChip(XMLfile: TXMLDocument; chipname: string; chipid: string = '');
var
  Node, ChipNode: TDOMNode;
  j, i: integer;
  cs: string;
begin
  if XMLfile <> nil then
  begin
    Node := XMLfile.DocumentElement.FirstChild;

    while Assigned(Node) do
    begin
     //Node.NodeName; //หมวด (SPI, I2C...)

     // ใช้พรอเพอร์ตี ChildNodes
     with Node.ChildNodes do
     try
       for j := 0 to (Count - 1) do
       begin
         //Item[j].NodeName; //หมวดผู้ผลิต

         for i := 0 to (Item[j].ChildNodes.Count - 1) do
         begin

           ChipNode := Item[j].ChildNodes.Item[i];
           if ChipNode.NodeType <> ELEMENT_NODE then Continue;
           if chipid <> '' then
           begin
             if (ChipNode.HasAttributes) then
               if  ChipNode.Attributes.GetNamedItem('id') <> nil then
               begin
                 cs := UTF16ToUTF8(ChipNode.Attributes.GetNamedItem('id').NodeValue); //id
                 if Upcase(cs) = Upcase(chipid) then
                 begin
                   ChipSearchForm.ListBoxChips.Items.Append(UTF16ToUTF8(ChipNode.NodeName)+' ('+ UTF16ToUTF8(Item[j].NodeName) +')');
                   LogPrint(UTF16ToUTF8(ChipNode.NodeName)+' ('+ UTF16ToUTF8(Item[j].NodeName) +')');
                 end;
               end;
           end
           else
           begin
             cs := UTF16ToUTF8(ChipNode.NodeName); //ชิป
             if ChipNameMatches(cs, chipname) then
             begin
               ChipSearchForm.ListBoxChips.Items.Append(cs+' ('+ UTF16ToUTF8(Item[j].NodeName) +')');
               LogPrint(cs+' ('+ UTF16ToUTF8(Item[j].NodeName) +')');
             end;
           end;

         end;
       end;
     finally
       Free;
     end;
     Node := Node.NextSibling;
    end;
  end;
end;

function SelectChip(XMLfile: TXMLDocument; chipname: string): boolean;
var
  Node, ChipNode: TDOMNode;
  j, i: integer;
  cs: string;
begin
  Result := False;

  if XMLfile <> nil then
  begin
    Node := XMLfile.DocumentElement.FirstChild;

    while Assigned(Node) do
    begin
     //Node.NodeName; //หมวด (SPI, I2C...)

     // ใช้พรอเพอร์ตี ChildNodes
     with Node.ChildNodes do
     try
       for j := 0 to (Count - 1) do
       begin
         //Item[j].NodeName; //หมวดผู้ผลิต

         for i := 0 to (Item[j].ChildNodes.Count - 1) do
         begin
           if Item[j].ChildNodes.Item[i].NodeType <> ELEMENT_NODE then
             Continue;
           cs := UTF16ToUTF8(Item[j].ChildNodes.Item[i].NodeName); //ชิป
           if Upcase(chipname) = Upcase(cs) then
           begin
             ChipNode := Item[j].ChildNodes.Item[i];
             if (ChipNode.HasAttributes) then
             begin
               //ชื่อถูกตั้งเฉพาะเมื่อโหนดใช้ได้จริง: โหนดที่ไม่มีแอตทริบิวต์
               //ทำให้ฟังก์ชันตอบ "ไม่พบ" และห้ามทิ้งชื่อใหม่ค้างไว้บน
               //พารามิเตอร์ของชิปตัวเก่า
               Main.CurrentICParam.Name := UTF16ToUTF8(ChipNode.NodeName);

               //หมายเหตุของชิป เช่นข้อควรระวังเรื่องแรงดัน
               if ChipNode.Attributes.GetNamedItem('note') <> nil then
                 Main.CurrentICParam.Note := UTF16ToUTF8(ChipNode.Attributes.GetNamedItem('note').NodeValue)
               else
                 Main.CurrentICParam.Note := '';

               //แรงดันใช้งานของชิป เช่น 1.8
               //
               //เดิมดูจากชื่อรุ่นว่ามี 1.8V อยู่ในนั้นหรือไม่ ซึ่งพลาดชิป 1.8V
               //ที่ชื่อไม่ได้บอก เช่น W25Q64FW MX25U6435F GD25LQ32
               //ซึ่งเป็นกลุ่มที่พังเพราะจ่ายไฟเกินบ่อยที่สุด
               if ChipNode.Attributes.GetNamedItem('vcc') <> nil then
                 Main.CurrentICParam.Vcc := UTF16ToUTF8(ChipNode.Attributes.GetNamedItem('vcc').NodeValue)
               else
                 Main.CurrentICParam.Vcc := '';

               //ต้องมี id ไว้ตรวจก่อนเขียนและก่อนลบ
               if ChipNode.Attributes.GetNamedItem('id') <> nil then
                 Main.CurrentICParam.ID := UpperCase(UTF16ToUTF8(ChipNode.Attributes.GetNamedItem('id').NodeValue))
               else
                 Main.CurrentICParam.ID := '';

               if  ChipNode.Attributes.GetNamedItem('spicmd') <> nil then
               begin
                 if UpperCase(ChipNode.Attributes.GetNamedItem('spicmd').NodeValue) = 'KB'then
                   Main.CurrentICParam.SpiCmd:= SPI_CMD_KB;
                 if ChipNode.Attributes.GetNamedItem('spicmd').NodeValue = '45' then
                   Main.CurrentICParam.SpiCmd:= SPI_CMD_45;
                 if ChipNode.Attributes.GetNamedItem('spicmd').NodeValue = '25' then
                   Main.CurrentICParam.SpiCmd:= SPI_CMD_25;
                 if ChipNode.Attributes.GetNamedItem('spicmd').NodeValue = '95' then
                   Main.CurrentICParam.SpiCmd:= SPI_CMD_95;

                 MainForm.ComboSPICMD.ItemIndex := CurrentICParam.SpiCmd;
                 MainForm.RadioSPI.Checked:= true;
                 MainForm.RadioSPIChange(MainForm);
               end
               else //ค่าเริ่มต้นคือชุดคำสั่ง spicmd 25
               if (ChipNode.Attributes.GetNamedItem('addrtype') = nil) and
                     (ChipNode.Attributes.GetNamedItem('addrbitlen') = nil) then
                     begin
                        Main.CurrentICParam.SpiCmd:= SPI_CMD_25;
                        MainForm.ComboSPICMD.ItemIndex := CurrentICParam.SpiCmd;
                        MainForm.RadioSPI.Checked:= true;
                        MainForm.RadioSPIChange(MainForm);
                     end;

               Main.CurrentICParam.MWAddLen := AttrInt(ChipNode, 'addrbitlen', 0);
               if Main.CurrentICParam.MWAddLen > 0 then
                 MainForm.RadioMw.Checked := true;

               if ChipNode.Attributes.GetNamedItem('addrtype') <> nil then
                 if IsNumber(UTF16ToUTF8(ChipNode.Attributes.GetNamedItem('addrtype').NodeValue)) then
                 begin
                   MainForm.RadioI2C.Checked:= true;
                   Main.CurrentICParam.I2CAddrType := StrToInt(UTF16ToUTF8(ChipNode.Attributes.GetNamedItem('addrtype').NodeValue));
                 end;

               if  ChipNode.Attributes.GetNamedItem('page') <> nil then
               begin
                 if UpCase(UTF16ToUTF8(ChipNode.Attributes.GetNamedItem('page').NodeValue)) = 'SSTB' then
                   Main.CurrentICParam.Page := -1
                 else if UpCase(UTF16ToUTF8(ChipNode.Attributes.GetNamedItem('page').NodeValue)) = 'SSTW' then
                   Main.CurrentICParam.Page := -2
                 else
                   Main.CurrentICParam.Page := AttrInt(ChipNode, 'page', 0);
               end
               else
                 Main.CurrentICParam.Page := 0;

               Main.CurrentICParam.Size := AttrInt(ChipNode, 'size', 0);

               //ขนาดเซกเตอร์สำหรับลบ ถ้าไม่ระบุจะใช้ 4096
               if ChipNode.Attributes.GetNamedItem('sector') <> nil then
               begin
                 if IsNumber(UTF16ToUTF8(ChipNode.Attributes.GetNamedItem('sector').NodeValue)) then
                   Main.CurrentICParam.Sector := StrToInt(UTF16ToUTF8(ChipNode.Attributes.GetNamedItem('sector').NodeValue))
                 else
                   Main.CurrentICParam.Sector := 0;
               end
               else
                 Main.CurrentICParam.Sector := 0;

               //opcode สำหรับลบเซกเตอร์ (HEX) ถ้าไม่ระบุจะเลือกให้ตามขนาด
               Main.CurrentICParam.SectorOpcode := 0;
               if ChipNode.Attributes.GetNamedItem('sectorcmd') <> nil then
                 if IsNumber('$'+UTF16ToUTF8(ChipNode.Attributes.GetNamedItem('sectorcmd').NodeValue)) then
                   Main.CurrentICParam.SectorOpcode := StrToInt('$'+UTF16ToUTF8(ChipNode.Attributes.GetNamedItem('sectorcmd').NodeValue));

               if ChipNode.Attributes.GetNamedItem('script') <> nil then
               begin
                 Main.CurrentICParam.Script:= UTF16ToUTF8(ChipNode.Attributes.GetNamedItem('script').NodeValue);
                 MainForm.ComboBox_chip_scriptrun.Items := scriptsfunc.GetScriptSectionsFromFile(Main.CurrentICParam.Script);
                 MainForm.ComboBox_chip_scriptrun.ItemIndex := 0;
               end
               else
               begin
                 Main.CurrentICParam.Script := '';
                 MainForm.ComboBox_chip_scriptrun.Items.Clear;
               end;


                MainForm.LabelChipName.Caption := CurrentICParam.Name;

                if CurrentICParam.MWAddLen > 0 then
                  MainForm.ComboMWBitLen.Text := IntToStr(CurrentICParam.MWAddLen)
                else
                  MainForm.ComboMWBitLen.Text := 'MW addr len';

                MainForm.ComboAddrType.ItemIndex := CurrentICParam.I2CAddrType;

                if CurrentICParam.Page > 0 then
                  MainForm.ComboPageSize.Text := IntToStr(CurrentICParam.Page)
                else if CurrentICParam.Page = -1 then
                  MainForm.ComboPageSize.Text := 'SSTB'
                else if CurrentICParam.Page = -2 then
                  MainForm.ComboPageSize.Text := 'SSTW'
                else
                  MainForm.ComboPageSize.Text := 'Page size';

                if CurrentICParam.Size > 0 then
                  MainForm.ComboChipSize.Text := IntToStr(CurrentICParam.Size)
                else
                  MainForm.ComboChipSize.Text := 'Chip size';

                Result := True;
              end;
           end;
         end;

       end;
     finally
       Free;
     end;
     Node := Node.NextSibling;
    end;
  end;
end;

{ TChipSearchForm }

procedure TChipSearchForm.EditSearchChange(Sender: TObject);
begin
  ListBoxChips.Clear;
  //ค้นทุกไฟล์ที่โปรแกรมโหลด ไม่ใช่แค่สองไฟล์แรก: ของเดิมข้ามตารางผู้ใช้
  //ตาราง EZP และตาราง IMSProg ไปเงียบ ๆ ชิปที่มีอยู่จริงเลยหาไม่เจอ
  FindChip(chiplistfile, EditSearch.Text);
  FindChip(ChipListFile2, EditSearch.Text);
  FindChip(ChipListFile3, EditSearch.Text);
  FindChip(ChipListFile4, EditSearch.Text);
  FindChip(ChipListFile5, EditSearch.Text);
end;

procedure TChipSearchForm.ChipSearchSelectButtonClick(Sender: TObject);
begin
  ChipSearchForm.ListBoxChipsDblClick(Sender);
  ChipSearchForm.Hide;
end;

procedure TChipSearchForm.ListBoxChipsDblClick(Sender: TObject);
var
  chipname: string;
begin
  if ListBoxChips.ItemIndex >= 0 then
  begin
    chipname := ListBoxChips.Items[ListBoxChips.ItemIndex];
    chipname := copy(chipname, 1, pos(' (', chipname)-1); //ตัดชื่อผู้ผลิตออก
    //ต้องผ่าน SelectChipAny เท่านั้น เพราะมันหาในไฟล์หลักก่อนแล้วค่อยไปไฟล์เสริม
    //และที่สำคัญคือมันรีเฟรชสรุปข้อมูลชิปกับไฟสถานะให้ด้วย
    //ถ้าเรียก SelectChip ตรง ๆ ไฟดวง Chip จะไม่ติด ทั้งที่เลือกชิปสำเร็จแล้ว
    Main.SelectChipAny(chipname);
  end;
end;

end.

