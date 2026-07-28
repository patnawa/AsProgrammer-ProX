unit serialnum;

//ตรรกะของเลขรันนิ่งอัตโนมัติ แยกออกจากไดอะล็อกโดยตั้งใจ
//หน่วยนี้ไม่พึ่ง LCL เลย จึงเอาไปทดสอบได้โดยไม่ต้องมีหน้าจอหรือฮาร์ดแวร์

{$mode objfpc}{$H+}

interface

uses
  SysUtils;
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

    //--- การตามรอยการผลิต ---
    ProdLogFile: string;    //ไฟล์ CSV บันทึกทีละตัว เว้นว่างคือไม่บันทึก
    Operator_: string;      //ชื่อผู้ปฏิบัติงาน ลงไปในบันทึกด้วย
    JobFile: string;        //ไฟล์งานที่กำหนด CRC32 ของภาพที่อนุมัติแล้ว
    CheckUID: boolean;      //ไม่ยอมเขียนชิปที่เคยผ่านไปแล้ว ดูจากเลขประจำตัว
  end;

  //One physical unit gets one immutable value.  Random serials must never be
  //regenerated independently for injection, verification and logging.
  TSerialAllocation = record
    Valid: boolean;
    Len: byte;
    Bytes: array[0..7] of byte;
    Text: string;
  end;

//ค่าเริ่มต้น
procedure DefaultProdSettings(out S: TProdSettings);

//สร้างไบต์ของเลขรันนิ่งจากค่าตัวนับปัจจุบัน
procedure BuildSerialBytes(const S: TProdSettings; out Bytes: array of byte);

//วางเลขลงบัฟเฟอร์ คืน False ถ้าเลขไม่พอดีกับบัฟเฟอร์
function ApplySerial(const S: TProdSettings; var Data: array of byte;
  DataSize: cardinal): boolean;

//รูปแบบที่อ่านออกของเลขรันนิ่ง ใช้ตอนเขียน log
function SerialToStr(const S: TProdSettings): string;

procedure AllocateSerial(const S: TProdSettings; out A: TSerialAllocation);
function ApplyAllocatedSerial(const A: TSerialAllocation; Address: cardinal;
  var Data: array of byte; DataSize: cardinal): boolean;

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

  S.ProdLogFile := '';
  S.Operator_ := '';
  S.JobFile := '';
  S.CheckUID := False;
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

procedure AllocateSerial(const S: TProdSettings; out A: TSerialAllocation);
var
  i: integer;
begin
  FillChar(A, SizeOf(A), 0);
  if (not S.SNEnabled) or (S.SNLength < 1) or (S.SNLength > 8) then Exit;

  A.Len := S.SNLength;
  BuildSerialBytes(S, A.Bytes);
  A.Text := '';
  for i := 0 to A.Len - 1 do
    A.Text := A.Text + IntToHex(A.Bytes[i], 2);
  A.Valid := True;
end;

function ApplyAllocatedSerial(const A: TSerialAllocation; Address: cardinal;
  var Data: array of byte; DataSize: cardinal): boolean;
var
  i: integer;
begin
  Result := False;
  if (not A.Valid) or (A.Len < 1) or (A.Len > 8) then Exit;
  if int64(Address) + A.Len > DataSize then Exit;

  for i := 0 to A.Len - 1 do
    Data[Address + cardinal(i)] := A.Bytes[i];
  Result := True;
end;

initialization
  Randomize;

end.
