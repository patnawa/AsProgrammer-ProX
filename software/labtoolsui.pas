unit labtoolsui;

// The three bench-tool windows.
//
// They live here rather than in main.pas for the same reason they live in
// their own menu: the flash programmer's screen has one job, and a bus
// scanner, a byte console and a serial terminal are three more. Keeping them
// out of the 16,000-line form unit is the point, not a side effect.
//
// The decisions these windows make -- which I2C addresses may be probed, how
// a typed hex command is parsed, how a reply is formatted -- are not here
// either. They are in labtools, tested, because they are the parts that are
// easy to get quietly wrong. What is left here is window construction and
// moving bytes.
//
// The implementation section uses main, and main's implementation uses this
// unit. That circularity is legal precisely because it is implementation to
// implementation, and it is the seam that lets UI move out of main.pas one
// window at a time without a flag-day rewrite.

{$mode objfpc}{$H+}

interface

// Each opens the programmer it needs, runs modally, and closes what it
// opened. The caller only has to decide that the operator asked for it.
procedure ShowI2CScanner;
procedure ShowSPIConsole;
procedure ShowUARTTerminal;

implementation

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls, Spin, Menus,
  basehw, spi25, synaser, labtools, safemode, main;

//---------------------------------------------------------------- Lab Tools
//
//เครื่องมือหน้าโต๊ะ แยกออกจากส่วนโปรแกรมชิปโดยตั้งใจ ทั้งในเมนูและในโค้ด
//หน้าหลักมีงานเดียวคือโปรแกรมชิป การเอาเครื่องสแกนบัสกับเทอร์มินัลไปยัดรวม
//ทำให้หน้าที่ต้องชัดที่สุดในโปรแกรมนี้รกขึ้นโดยไม่ได้อะไรกลับมา
//
//กติกาที่ตัดสินได้ (ช่วงแอดเดรสที่แหย่ได้ การแปลงเลขฐานสิบหกที่พิมพ์เข้ามา
//การจัดรูป hex dump) อยู่ใน labtools ซึ่งทดสอบครบแล้ว ที่นี่เหลือแค่การ
//ประกอบหน้าต่างกับการขยับไบต์

//ตัวจับเหตุการณ์ของหน้าต่างเครื่องมือ
//
//OnClick ของ LCL รับได้เฉพาะเมธอดของอ็อบเจกต์ ไม่รับโพรซีเดอร์ซ้อน จึงต้องมี
//คลาสเล็ก ๆ ถือสถานะของหน้าต่างไว้ ซึ่งกลายเป็นเรื่องดี: สถานะของเครื่องมือ
//ไม่ต้องไปปนกับ TMainForm ที่ใหญ่พออยู่แล้ว
type
  TSPIConsoleController = class
  public
    Memo: TMemo;
    Input: TEdit;
    ReadCount: TSpinEdit;
    procedure Send(Sender: TObject);
  end;

  TUARTController = class
  public
    Memo: TMemo;
    Input: TEdit;
    PortBox: TComboBox;
    BaudBox: TComboBox;
    OpenButton: TButton;
    Ser: TBlockSerial;
    IsOpen: boolean;
    procedure Pump;
    procedure ToggleOpen(Sender: TObject);
    procedure Send(Sender: TObject);
    procedure Poll(Sender: TObject);
  end;

procedure TSPIConsoleController.Send(Sender: TObject);
var
  Cmd, Reply: TByteArray;
  ErrMsg: string;
  Got, Want, i: integer;
  Lines: TStringArray;
begin
  if not ParseHexBytes(Input.Text, Cmd, ErrMsg) then
  begin
    Memo.Lines.Add('! ' + ErrMsg);
    Exit;
  end;
  Want := ReadCount.Value;
  Memo.Lines.Add('> ' + BytesToHexText(Cmd) +
                 Format('   (then read %d)', [Want]));

  SetLength(Reply, Want);
  if Want > 0 then FillChar(Reply[0], Want, $FF);
  Got := AsProgrammer.Programmer.SPIWriteRead(1, Length(Cmd), Cmd, Want, Reply);
  if Got < 0 then
  begin
    //-1 คือทั้ง "สายหลุด" และ "โหมดอ่านอย่างเดียวปฏิเสธ" แยกให้ผู้ใช้เห็น
    if SafeModeBlocks(gaWrite) then
      Memo.Lines.Add('< refused: ' + SafeModeRefusal(gaWrite))
    else
      Memo.Lines.Add('< the transfer did not complete');
    Exit;
  end;
  if Want = 0 then
  begin
    Memo.Lines.Add('< sent');
    Exit;
  end;
  Lines := HexDump(Reply, 0);
  for i := 0 to High(Lines) do Memo.Lines.Add('< ' + Lines[i]);
end;

procedure TUARTController.Pump;
var
  Chunk: string;
  n: integer;
begin
  if not IsOpen then Exit;
  n := Ser.WaitingData;
  if n <= 0 then Exit;
  if n > 4096 then n := 4096;
  Chunk := Ser.RecvBufferStr(n, 50);
  if Chunk <> '' then Memo.Lines.Add('< ' + Chunk);
end;

procedure TUARTController.ToggleOpen(Sender: TObject);
begin
  if IsOpen then
  begin
    Ser.CloseSocket;
    IsOpen := False;
    OpenButton.Caption := 'Open';
    Memo.Lines.Add('-- port closed --');
    Exit;
  end;
  if PortBox.Text = '' then
  begin
    Memo.Lines.Add('! pick a COM port first');
    Exit;
  end;
  Ser.CloseSocket;
  Ser.Connect(PortBox.Text);
  if Ser.LastError <> 0 then
  begin
    Memo.Lines.Add('! ' + PortBox.Text + ': ' + Ser.LastErrorDesc);
    Exit;
  end;
  Ser.Config(StrToIntDef(BaudBox.Text, 115200), 8, 'N', SB1, False, False);
  IsOpen := True;
  OpenButton.Caption := 'Close';
  Memo.Lines.Add('-- ' + PortBox.Text + ' open at ' + BaudBox.Text + ' 8N1 --');
end;

procedure TUARTController.Send(Sender: TObject);
begin
  if not IsOpen then
  begin
    Memo.Lines.Add('! the port is not open');
    Exit;
  end;
  Memo.Lines.Add('> ' + Input.Text);
  //CRLF เพราะอุปกรณ์ฝังตัวส่วนใหญ่คาดหวังแบบนั้น ตัวที่ต้องการ LF อย่างเดียว
  //มักไม่รังเกียจ CR ที่ตามมา
  Ser.SendString(Input.Text + #13#10);
  Input.SelectAll;
  Pump;
end;

procedure TUARTController.Poll(Sender: TObject);
begin
  Pump;
end;

//หน้าต่างผลลัพธ์แบบใช้ซ้ำ: memo อ่านอย่างเดียวกับปุ่มปิด
function MakeToolWindow(const Caption: string; Width, Height: integer;
  out Memo: TMemo): TForm;
var
  Footer: TPanel;
  CloseButton: TButton;
begin
  Result := TForm.CreateNew(nil);
  Result.Caption := Caption;
  Result.Position := poOwnerFormCenter;
  Result.Width := Width;
  Result.Height := Height;
  Result.BorderStyle := bsSizeable;

  Footer := TPanel.Create(Result);
  Footer.Parent := Result;
  Footer.Align := alBottom;
  Footer.Height := 40;
  Footer.BevelOuter := bvNone;

  CloseButton := TButton.Create(Result);
  CloseButton.Parent := Footer;
  CloseButton.Caption := 'Close';
  CloseButton.ModalResult := mrOk;
  CloseButton.Left := Width - 100;
  CloseButton.Top := 6;
  CloseButton.Width := 80;
  CloseButton.Anchors := [akRight, akTop];

  Memo := TMemo.Create(Result);
  Memo.Parent := Result;
  Memo.Align := alClient;
  Memo.ReadOnly := True;
  Memo.ScrollBars := ssBoth;
  Memo.WordWrap := False;
  Memo.Font.Name := 'Courier New';
  Memo.Font.Size := 9;
end;

//แหย่ทุกแอดเดรสที่แหย่ได้ แล้วบอกว่าตัวไหนตอบ
//
//ไม่แตะช่วงสงวนของ I2C เด็ดขาด: 0000xxx คือ general call ซึ่งอุปกรณ์ทุกตัว
//บนบัสรับคำสั่ง ส่วน1111xxx คือทางเข้าโหมดแอดเดรส 10 บิต การ "สแกน" ที่รวม
//สองช่วงนี้ไม่ใช่การถาม แต่เป็นการสั่ง
procedure ShowI2CScanner;
var
  Win: TForm;
  Memo: TMemo;
  Addr: byte;
  Found, Probed: integer;
  Opened: boolean;
  Row: string;
begin
  if OperationRunning then Exit;
  if AsProgrammer.Programmer = nil then Exit;

  Win := MakeToolWindow('I2C bus scanner', 560, 420, Memo);
  try
    Memo.Lines.Add('I2C bus scan');
    Memo.Lines.Add('');
    Opened := False;
    Found := 0;
    Probed := 0;
    LockControl;
    try
      if not OpenDevice then
      begin
        Memo.Lines.Add('no programmer could be opened');
        Win.ShowModal;
        Exit;
      end;
      Opened := True;
      AsProgrammer.Programmer.I2CInit;

      Memo.Lines.Add(Format('probing 0x%.2X..0x%.2X; the I2C reserved ' +
        'ranges are deliberately skipped',
        [I2C_FIRST_PROBE_ADDRESS, I2C_LAST_PROBE_ADDRESS]));
      Memo.Lines.Add('');

      for Addr := 0 to $7F do
      begin
        if not I2CAddressIsProbeable(Addr) then Continue;
        Inc(Probed);
        //แหย่ด้วยไบต์แอดเดรสเปล่า ๆ แล้วดู ACK ไม่เขียนอะไรตามหลังเลย
        AsProgrammer.Programmer.I2CStart;
        if AsProgrammer.Programmer.I2CWriteByte(I2CWriteByteFor(Addr)) then
        begin
          Inc(Found);
          Row := Format('  0x%.2X responds  (write byte 0x%.2X, read byte 0x%.2X)',
                        [Addr, I2CWriteByteFor(Addr), I2CReadByteFor(Addr)]);
          //ที่อยู่ยอดนิยมช่วยให้เดาได้ว่าเจออะไร แต่ไม่ยืนยันแทนผู้ใช้
          if (Addr >= $50) and (Addr <= $57) then
            Row := Row + '  - typical 24-series EEPROM';
          Memo.Lines.Add(Row);
        end;
        AsProgrammer.Programmer.I2CStop;
      end;

      Memo.Lines.Add('');
      Memo.Lines.Add(Format('%d of %d probed addresses responded',
                            [Found, Probed]));
      if Found = 0 then
      begin
        Memo.Lines.Add('');
        Memo.Lines.Add('Nothing answered. Check SDA and SCL are not swapped, ' +
                       'that both have pull-ups to the target rail, and that ' +
                       'GND is common.');
        //ตัวต้านทาน pull-up ที่คำนวณไว้สำหรับ 3.3V ขึ้นช้าเกินไปที่ 1.8V
        //อาการที่ได้คือเจอบ้างไม่เจอบ้าง ไม่ใช่ไม่เจอเลย แต่ควรบอกไว้
        Memo.Lines.Add('At 1.8 V, pull-ups sized for 3.3 V rise too slowly ' +
                       'and devices answer intermittently or not at all.');
      end;
    finally
      if Opened then
      begin
        AsProgrammer.Programmer.I2CDeinit;
        AsProgrammer.Programmer.DevClose;
      end;
      UnlockControl;
    end;
    Win.ShowModal;
  finally
    Win.Free;
  end;
end;

//ส่งไบต์ SPI ดิบ ๆ แล้วดูสิ่งที่ได้กลับมา
//
//เครื่องมือนี้ข้ามด่านทุกด่านที่โปรแกรมมี ยกเว้นด่านเดียว: โหมดอ่านอย่างเดียว
//ยังคุมอยู่เพราะแลตช์อยู่ที่ตัวคำสั่งใน spi25 ไม่ใช่ที่ปุ่ม
//
//ที่เหลือคือความรับผิดชอบของผู้ใช้ และหน้าต่างบอกไว้ตรง ๆ ว่าเป็นอย่างนั้น
procedure ShowSPIConsole;
var
  Win: TForm;
  Memo: TMemo;
  Bar: TPanel;
  SendButton: TButton;
  Ctl: TSPIConsoleController;
  Opened: boolean;
begin
  if OperationRunning then Exit;
  if AsProgrammer.Programmer = nil then Exit;

  Ctl := TSPIConsoleController.Create;
  Win := MakeToolWindow('SPI console', 720, 460, Memo);
  try
    Ctl.Memo := Memo;

    Bar := TPanel.Create(Win);
    Bar.Parent := Win;
    Bar.Align := alTop;
    Bar.Height := 40;
    Bar.BevelOuter := bvNone;

    Ctl.Input := TEdit.Create(Win);
    Ctl.Input.Parent := Bar;
    Ctl.Input.Left := 8;
    Ctl.Input.Top := 8;
    Ctl.Input.Width := 420;
    Ctl.Input.Text := '9F';
    Ctl.Input.Anchors := [akLeft, akTop, akRight];

    Ctl.ReadCount := TSpinEdit.Create(Win);
    Ctl.ReadCount.Parent := Bar;
    Ctl.ReadCount.Left := 436;
    Ctl.ReadCount.Top := 8;
    Ctl.ReadCount.Width := 70;
    Ctl.ReadCount.MinValue := 0;
    Ctl.ReadCount.MaxValue := 4096;
    Ctl.ReadCount.Value := 3;
    Ctl.ReadCount.Anchors := [akTop, akRight];

    SendButton := TButton.Create(Win);
    SendButton.Parent := Bar;
    SendButton.Left := 514;
    SendButton.Top := 7;
    SendButton.Width := 80;
    SendButton.Caption := 'Send';
    SendButton.OnClick := @Ctl.Send;
    SendButton.Anchors := [akTop, akRight];

    Memo.Lines.Add('SPI console: raw command bytes, then an optional read.');
    Memo.Lines.Add('');
    Memo.Lines.Add('This bypasses every guard except read-only safe mode,');
    Memo.Lines.Add('which is latched at the protocol layer and still applies.');
    Memo.Lines.Add('Nothing here checks that the opcode you type is safe for');
    Memo.Lines.Add('the part in the socket. 9F reads the JEDEC ID; C7 erases');
    Memo.Lines.Add('the entire chip.');
    Memo.Lines.Add('');

    Opened := False;
    LockControl;
    try
      if not OpenDevice then
      begin
        Memo.Lines.Add('no programmer could be opened');
        Win.ShowModal;
        Exit;
      end;
      Opened := True;
      if not EnterProgModeSPI25 then
      begin
        Memo.Lines.Add('the SPI bus could not be started; see the main log');
        Win.ShowModal;
        Exit;
      end;
      Memo.Lines.Add('bus ready.');
      Win.ShowModal;
    finally
      if Opened then
      begin
        ExitProgMode25;
        AsProgrammer.Programmer.DevClose;
      end;
      UnlockControl;
    end;
  finally
    Win.Free;
    Ctl.Free;
  end;
end;

//เทอร์มินัล UART บนพอร์ตอนุกรม
//
//ไม่ผ่านตัวโปรแกรมเมอร์เลย คุยกับพอร์ต COM ตรง ๆ ผ่าน synaser ตัวเดียวกับ
//ที่ Arduino/BusPirate/serprog ใช้ จึงใช้ได้กับอุปกรณ์อะไรก็ได้ที่เสียบอยู่
//ไม่ใช่แค่เครื่องโปรแกรมชิป
procedure ShowUARTTerminal;
var
  Win: TForm;
  Memo: TMemo;
  Bar: TPanel;
  SendButton: TButton;
  Timer: TTimer;
  Ctl: TUARTController;
  i: integer;
begin
  if OperationRunning then Exit;

  Ctl := TUARTController.Create;
  Ctl.Ser := TBlockSerial.Create;
  Ctl.IsOpen := False;
  Win := MakeToolWindow('UART terminal', 720, 460, Memo);
  try
    Ctl.Memo := Memo;

    Bar := TPanel.Create(Win);
    Bar.Parent := Win;
    Bar.Align := alTop;
    Bar.Height := 72;
    Bar.BevelOuter := bvNone;

    Ctl.PortBox := TComboBox.Create(Win);
    Ctl.PortBox.Parent := Bar;
    Ctl.PortBox.Left := 8;
    Ctl.PortBox.Top := 8;
    Ctl.PortBox.Width := 110;
    for i := 1 to 32 do Ctl.PortBox.Items.Add('COM' + IntToStr(i));

    Ctl.BaudBox := TComboBox.Create(Win);
    Ctl.BaudBox.Parent := Bar;
    Ctl.BaudBox.Left := 126;
    Ctl.BaudBox.Top := 8;
    Ctl.BaudBox.Width := 100;
    Ctl.BaudBox.Items.Add('9600');
    Ctl.BaudBox.Items.Add('19200');
    Ctl.BaudBox.Items.Add('38400');
    Ctl.BaudBox.Items.Add('57600');
    Ctl.BaudBox.Items.Add('115200');
    Ctl.BaudBox.Items.Add('921600');
    Ctl.BaudBox.ItemIndex := 4;

    Ctl.OpenButton := TButton.Create(Win);
    Ctl.OpenButton.Parent := Bar;
    Ctl.OpenButton.Left := 234;
    Ctl.OpenButton.Top := 7;
    Ctl.OpenButton.Width := 80;
    Ctl.OpenButton.Caption := 'Open';
    Ctl.OpenButton.OnClick := @Ctl.ToggleOpen;

    Ctl.Input := TEdit.Create(Win);
    Ctl.Input.Parent := Bar;
    Ctl.Input.Left := 8;
    Ctl.Input.Top := 40;
    Ctl.Input.Width := 600;
    Ctl.Input.Anchors := [akLeft, akTop, akRight];

    SendButton := TButton.Create(Win);
    SendButton.Parent := Bar;
    SendButton.Left := 616;
    SendButton.Top := 39;
    SendButton.Width := 80;
    SendButton.Caption := 'Send';
    SendButton.OnClick := @Ctl.Send;
    SendButton.Anchors := [akTop, akRight];

    //ดึงข้อมูลด้วยตัวจับเวลาบนเธรดหลัก ไม่ต้องมีเธรดอ่านแยก ซึ่งจะต้องมี
    //การซิงก์กับหน้าจอตามมาทั้งชุดเพื่อประโยชน์ที่เทอร์มินัลไม่ได้ต้องการ
    Timer := TTimer.Create(Win);
    Timer.Interval := 75;
    Timer.OnTimer := @Ctl.Poll;
    Timer.Enabled := True;

    Memo.Lines.Add('UART terminal. This talks straight to a COM port and');
    Memo.Lines.Add('does not go through the programmer at all.');
    Memo.Lines.Add('');
    Memo.Lines.Add('Lines are sent with CRLF appended.');
    Memo.Lines.Add('');
    Win.ShowModal;
  finally
    Timer.Enabled := False;
    if Ctl.IsOpen then Ctl.Ser.CloseSocket;
    Ctl.Ser.Free;
    Win.Free;
    Ctl.Free;
  end;
end;

end.
