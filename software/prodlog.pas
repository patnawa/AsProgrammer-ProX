unit prodlog;

//บันทึกการผลิตและไฟล์งาน
//
//ชิปแต่ละตัวมีเลขประจำตัวจากโรงงานอ่านได้ด้วยคำสั่ง 4Bh ซึ่งไม่ซ้ำกัน
//เอาไว้ตอบสองคำถามที่สายการผลิตต้องตอบให้ได้
//
//  ตัวนี้เคยผ่านการเขียนไปแล้วหรือยัง   กันการเขียนซ้ำและกันของหลุดออกไปสองรอบ
//  ตัวที่ส่งออกไปเมื่อวานเขียนอะไรลงไป  ต้องย้อนดูได้ว่าเป็นเฟิร์มแวร์ตัวไหน
//
//ไฟล์งานเก็บ CRC32 ของภาพที่อนุมัติแล้ว ถ้าไฟล์ที่โหลดมาไม่ตรง โปรแกรม
//จะไม่ยอมเขียน เป็นด่านกันการหยิบไฟล์ผิดรุ่นซึ่งเป็นความผิดพลาดที่พบบ่อยที่สุด
//
//หน่วยนี้ไม่พึ่ง LCL จึงเอาไปทดสอบได้โดยไม่ต้องมีหน้าจอหรือฮาร์ดแวร์

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type

  TProdOutcome = (poPass, poFail);

  TProdRecord = record
    TimeStamp: TDateTime;
    ChipName: string;
    UID: string;          //เลขประจำตัวจาก 4Bh เป็นเลขฐานสิบหก ว่างได้ถ้าชิปไม่มี
    Serial: string;       //เลขรันนิ่งที่เขียนลงไป ว่างได้
    Operator_: string;    //ชื่อผู้ปฏิบัติงาน ว่างได้
    Size: cardinal;
    CRC32: cardinal;
    Outcome: TProdOutcome;
    Note: string;         //เหตุผลเมื่อไม่ผ่าน
  end;

  TJobFile = record
    Loaded: boolean;
    ChipName: string;     //ว่าง = ไม่ตรวจชื่อชิป
    Size: cardinal;       //0 = ไม่ตรวจขนาด
    CRC32: cardinal;
    HasCRC: boolean;
  end;

const
  PRODLOG_HEADER = 'timestamp,chip,uid,serial,operator,size,crc32,result,note';

//ต่อท้ายไฟล์บันทึก สร้างไฟล์พร้อมหัวตารางให้ถ้ายังไม่มี
//คืน False เมื่อเขียนไฟล์ไม่ได้ ซึ่งในสายการผลิตต้องถือว่าเป็นความล้มเหลว
//เพราะของที่ไม่มีบันทึกก็เท่ากับของที่ตามรอยไม่ได้
function AppendProdLog(const FileName: string; const Rec: TProdRecord): boolean;

//เคยมีบรรทัดที่ UID นี้ผ่านไปแล้วหรือไม่
//ไฟล์ที่ไม่มีอยู่ถือว่ายังไม่เคย ไม่ใช่ความผิดพลาด
function ProdLogHasPassedUID(const FileName, UID: string): boolean; overload;
//แบบที่แยก "อ่านไฟล์ไม่ได้" ออกจาก "ไม่เคยผ่าน": ไฟล์ที่มีอยู่แต่โหลดไม่ขึ้น
//(ถูกล็อก/เสีย) ต้องให้ผู้เรียกปิดประตูเอง ไม่ใช่เงียบเหมือนไม่เคยเจอ
function ProdLogHasPassedUID(const FileName, UID: string;
  out ReadFailed: boolean): boolean; overload;

//จำนวนบรรทัดที่ผ่านและไม่ผ่าน ใช้สรุปตอนจบชุดการผลิต
procedure ProdLogCount(const FileName: string; out Passed, Failed: integer);

//หนึ่งบรรทัดของไฟล์บันทึก แยกออกมาให้เทสต์เรียกได้
function ProdRecordToCSV(const Rec: TProdRecord): string;

//--- ไฟล์งาน ---

//อ่านไฟล์งาน รูปแบบเป็น key=value บรรทัดละคู่ บรรทัดที่ขึ้นต้นด้วย # คือหมายเหตุ
//  chip=W25Q64BV
//  size=8388608
//  crc32=1A2B3C4D
function LoadJobFile(const FileName: string; out Job: TJobFile;
  out ErrMsg: string): boolean;

//ภาพที่โหลดมาตรงกับที่ไฟล์งานกำหนดหรือไม่
//คืน False พร้อมเหตุผล ผู้เรียกต้องไม่เขียนต่อ
function CheckJob(const Job: TJobFile; const ChipName: string;
  Size, CRC: cardinal; out ErrMsg: string): boolean;

implementation

//ใส่เครื่องหมายคำพูดเมื่อข้อความมีอักขระที่ทำให้ CSV เพี้ยน
function CSVQuote(const S: string): string;
var
  i: integer;
  NeedQuote: boolean;
begin
  Result := '';
  NeedQuote := False;

  for i := 1 to Length(S) do
  begin
    if S[i] = '"' then
      Result := Result + '""'
    else
      Result := Result + S[i];

    if (S[i] = ',') or (S[i] = '"') or (S[i] = #13) or (S[i] = #10) then
      NeedQuote := True;
  end;

  if NeedQuote then Result := '"' + Result + '"';
end;

function ProdRecordToCSV(const Rec: TProdRecord): string;
const
  OutcomeName: array[TProdOutcome] of string = ('PASS', 'FAIL');
begin
  Result :=
    FormatDateTime('yyyy-mm-dd hh:nn:ss', Rec.TimeStamp) + ',' +
    CSVQuote(Rec.ChipName) + ',' +
    CSVQuote(Rec.UID) + ',' +
    CSVQuote(Rec.Serial) + ',' +
    CSVQuote(Rec.Operator_) + ',' +
    IntToStr(Rec.Size) + ',' +
    IntToHex(Rec.CRC32, 8) + ',' +
    OutcomeName[Rec.Outcome] + ',' +
    CSVQuote(Rec.Note);
end;

function AppendProdLog(const FileName: string; const Rec: TProdRecord): boolean;
var
  F: TextFile;
  Existed: boolean;
begin
  Result := False;
  if FileName = '' then Exit;

  Existed := FileExists(FileName);

  try
    AssignFile(F, FileName);
    if Existed then Append(F) else Rewrite(F);
    try
      if not Existed then WriteLn(F, PRODLOG_HEADER);
      WriteLn(F, ProdRecordToCSV(Rec));
    finally
      CloseFile(F);
    end;
    Result := True;
  except
    Result := False;
  end;
end;

//ช่องที่ n ของบรรทัด CSV นับจาก 0 คืนสตริงว่างเมื่อไม่มีช่องนั้น
function CSVField(const Line: string; Index: integer): string;
var
  i, Field: integer;
  InQuote: boolean;
  C: char;
begin
  Result := '';
  Field := 0;
  InQuote := False;
  i := 1;

  while i <= Length(Line) do
  begin
    C := Line[i];

    if InQuote then
    begin
      if C = '"' then
      begin
        //สองตัวติดกันคือเครื่องหมายคำพูดจริงหนึ่งตัว
        if (i < Length(Line)) and (Line[i+1] = '"') then
        begin
          if Field = Index then Result := Result + '"';
          Inc(i);
        end
        else
          InQuote := False;
      end
      else
        if Field = Index then Result := Result + C;
    end
    else
    begin
      if C = '"' then
        InQuote := True
      else if C = ',' then
      begin
        if Field = Index then Exit;
        Inc(Field);
      end
      else
        if Field = Index then Result := Result + C;
    end;

    Inc(i);
  end;
end;

function ProdLogHasPassedUID(const FileName, UID: string): boolean; overload;
var
  ReadFailed: boolean;
begin
  Result := ProdLogHasPassedUID(FileName, UID, ReadFailed);
end;

function ProdLogHasPassedUID(const FileName, UID: string;
  out ReadFailed: boolean): boolean; overload;
var
  L: TStringList;
  i: integer;
  Want: string;
begin
  Result := False;
  ReadFailed := False;

  //ชิปที่ไม่มีเลขประจำตัวก็ตรวจซ้ำไม่ได้ ไม่ใช่เรื่องผิดปกติ
  Want := UpperCase(Trim(UID));
  if Want = '' then Exit;
  if not FileExists(FileName) then Exit;

  L := TStringList.Create;
  try
    try
      L.LoadFromFile(FileName);
    except
      ReadFailed := True;
      Exit;
    end;

    for i := 0 to L.Count - 1 do
    begin
      if Trim(L[i]) = '' then Continue;
      if UpperCase(CSVField(L[i], 2)) <> Want then Continue;
      if UpperCase(Trim(CSVField(L[i], 7))) = 'PASS' then Exit(True);
    end;
  finally
    L.Free;
  end;
end;

procedure ProdLogCount(const FileName: string; out Passed, Failed: integer);
var
  L: TStringList;
  i: integer;
  R: string;
begin
  Passed := 0;
  Failed := 0;
  if not FileExists(FileName) then Exit;

  L := TStringList.Create;
  try
    try
      L.LoadFromFile(FileName);
    except
      Exit;
    end;

    for i := 0 to L.Count - 1 do
    begin
      if Trim(L[i]) = '' then Continue;
      R := UpperCase(Trim(CSVField(L[i], 7)));
      if R = 'PASS' then Inc(Passed)
      else if R = 'FAIL' then Inc(Failed);
    end;
  finally
    L.Free;
  end;
end;

//--------------------------------------------------------------- ไฟล์งาน

function LoadJobFile(const FileName: string; out Job: TJobFile;
  out ErrMsg: string): boolean;
var
  L: TStringList;
  i, p: integer;
  Key, Val, Line: string;
  V: int64;
begin
  Result := False;
  ErrMsg := '';

  FillChar(Job, SizeOf(Job), 0);
  Job.ChipName := '';

  if not FileExists(FileName) then
  begin
    ErrMsg := 'job file not found: ' + FileName;
    Exit;
  end;

  L := TStringList.Create;
  try
    try
      L.LoadFromFile(FileName);
    except
      ErrMsg := 'cannot read the job file: ' + FileName;
      Exit;
    end;

    for i := 0 to L.Count - 1 do
    begin
      Line := Trim(L[i]);
      if (Line = '') or (Line[1] = '#') or (Line[1] = ';') then Continue;

      p := Pos('=', Line);
      if p < 2 then Continue;

      Key := LowerCase(Trim(Copy(Line, 1, p - 1)));
      Val := Trim(Copy(Line, p + 1, Length(Line)));

      if Key = 'chip' then
        Job.ChipName := Val
      else if Key = 'size' then
      begin
        if TryStrToInt64(Val, V) and (V > 0) then Job.Size := cardinal(V);
      end
      else if Key = 'crc32' then
      begin
        //ยอมรับทั้ง 1A2B3C4D และ 0x1A2B3C4D
        if (Length(Val) > 2) and (LowerCase(Copy(Val, 1, 2)) = '0x') then
          Val := Copy(Val, 3, Length(Val));
        if TryStrToInt64('$' + Val, V) then
        begin
          Job.CRC32 := cardinal(V);
          Job.HasCRC := True;
        end
        else
        begin
          ErrMsg := 'crc32 is not a hexadecimal number: ' + Val;
          Exit;
        end;
      end;
    end;
  finally
    L.Free;
  end;

  if (Job.ChipName = '') and (Job.Size = 0) and (not Job.HasCRC) then
  begin
    ErrMsg := 'the job file sets nothing to check';
    Exit;
  end;

  Job.Loaded := True;
  Result := True;
end;

function CheckJob(const Job: TJobFile; const ChipName: string;
  Size, CRC: cardinal; out ErrMsg: string): boolean;
begin
  Result := True;
  ErrMsg := '';

  if not Job.Loaded then Exit;

  if (Job.ChipName <> '') and (not SameText(Job.ChipName, ChipName)) then
  begin
    ErrMsg := Format('the job is for %s but %s is selected',
                     [Job.ChipName, ChipName]);
    Exit(False);
  end;

  if (Job.Size > 0) and (Job.Size <> Size) then
  begin
    ErrMsg := Format('the job expects %d bytes but the buffer holds %d',
                     [Job.Size, Size]);
    Exit(False);
  end;

  if Job.HasCRC and (Job.CRC32 <> CRC) then
  begin
    ErrMsg := Format('the job expects CRC32 %.8x but the buffer is %.8x',
                     [Job.CRC32, CRC]);
    Exit(False);
  end;
end;

end.
