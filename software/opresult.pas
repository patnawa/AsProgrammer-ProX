unit opresult;

//ผลของงานล่าสุดที่ทำกับชิป
//
//เดิมงานที่ล้มเหลวบอกได้แค่ผ่าน log ซึ่งเป็นข้อความสำหรับคนอ่าน
//โหมดบรรทัดคำสั่งจึงคืนรหัส 0 ทุกครั้งแม้เขียนไม่ผ่าน ซึ่งอันตรายมาก
//เมื่อเอาไปสั่งจากสายการผลิต เพราะชิปที่เสียจะผ่านด่านไปได้
//
//หน่วยนี้เป็นช่องทางเดียวที่ใช้ตอบว่างานสำเร็จหรือไม่ ไม่พึ่ง LCL
//จึงเอาไปทดสอบได้โดยไม่ต้องมีหน้าจอหรือฮาร์ดแวร์

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

type

  TOpKind = (
    opkNone,
    opkRead,
    opkWrite,
    opkErase,
    opkVerify,
    opkBlankCheck,
    opkDetect
  );

  //-1 ในช่อง FailAddress แปลว่าความผิดพลาดไม่ผูกกับแอดเดรสใดแอดเดรสหนึ่ง
  TOpResult = record
    Kind: TOpKind;
    Started: boolean;      //มีการเรียก OpBegin แล้วหรือยัง
    Failed: boolean;
    Cancelled: boolean;
    ErrorText: string;
    FailAddress: int64;
    BytesDone: cardinal;
    BytesTotal: cardinal;
  end;

const
  OP_NO_ADDRESS = -1;

var
  //งานล่าสุด เขียนจาก thread เบื้องหลัง อ่านจาก thread หลักหลังงานจบ
  //ไม่มีการอ่านและเขียนพร้อมกัน จึงไม่ต้องมี lock
  LastOp: TOpResult;

//เริ่มงานใหม่ ล้างผลของงานก่อนหน้าทิ้ง
procedure OpBegin(Kind: TOpKind);

//บันทึกความล้มเหลว ครั้งแรกที่เรียกเท่านั้นที่ถูกเก็บไว้
//เพราะสาเหตุแรกคือสาเหตุจริง ที่ตามมาเป็นผลพวง
procedure OpFail(const Msg: string; Addr: int64 = OP_NO_ADDRESS);

//ผู้ใช้สั่งยกเลิก นับเป็นไม่สำเร็จ แต่แยกจากความผิดพลาด
procedure OpCancel;

//ความคืบหน้า ใช้ตอนรายงานว่าไปถึงไหนก่อนล้ม
procedure OpProgress(BytesDone, BytesTotal: cardinal);

//งานนี้ผ่านหรือไม่ งานที่ยังไม่เริ่มถือว่าไม่ผ่าน
function OpOK: boolean;

//ข้อความสรุปบรรทัดเดียว สำหรับ log และโหมดบรรทัดคำสั่ง
function OpSummary: string;

//ชื่อชนิดงานแบบอ่านออก
function OpKindName(Kind: TOpKind): string;

implementation

procedure OpBegin(Kind: TOpKind);
begin
  LastOp.Kind := Kind;
  LastOp.Started := True;
  LastOp.Failed := False;
  LastOp.Cancelled := False;
  LastOp.ErrorText := '';
  LastOp.FailAddress := OP_NO_ADDRESS;
  LastOp.BytesDone := 0;
  LastOp.BytesTotal := 0;
end;

procedure OpFail(const Msg: string; Addr: int64 = OP_NO_ADDRESS);
begin
  //ถ้ายังไม่มีใครเรียก OpBegin ก็ถือว่างานนี้เริ่มแล้วโดยปริยาย
  //ไม่งั้นความล้มเหลวจะหายไปเงียบ ๆ ซึ่งเป็นสิ่งที่หน่วยนี้มีไว้เพื่อกัน
  LastOp.Started := True;

  if LastOp.Failed then Exit;

  LastOp.Failed := True;
  LastOp.ErrorText := Msg;
  LastOp.FailAddress := Addr;
end;

procedure OpCancel;
begin
  LastOp.Started := True;
  LastOp.Cancelled := True;
  if not LastOp.Failed then
  begin
    LastOp.Failed := True;
    LastOp.ErrorText := 'cancelled by the user';
    LastOp.FailAddress := OP_NO_ADDRESS;
  end;
end;

procedure OpProgress(BytesDone, BytesTotal: cardinal);
begin
  LastOp.BytesDone := BytesDone;
  LastOp.BytesTotal := BytesTotal;
end;

function OpOK: boolean;
begin
  Result := LastOp.Started and (not LastOp.Failed);
end;

function OpKindName(Kind: TOpKind): string;
begin
  case Kind of
    opkRead:       Result := 'read';
    opkWrite:      Result := 'write';
    opkErase:      Result := 'erase';
    opkVerify:     Result := 'verify';
    opkBlankCheck: Result := 'blank check';
    opkDetect:     Result := 'detect';
  else
    Result := 'operation';
  end;
end;

function OpSummary: string;
begin
  if not LastOp.Started then Exit('nothing was done');

  if not LastOp.Failed then
  begin
    Result := OpKindName(LastOp.Kind) + ': OK';
    if LastOp.BytesTotal > 0 then
      Result := Result + Format(' (%d bytes)', [LastOp.BytesTotal]);
    Exit;
  end;

  Result := OpKindName(LastOp.Kind) + ': FAILED';
  if LastOp.ErrorText <> '' then
    Result := Result + ' - ' + LastOp.ErrorText;
  if LastOp.FailAddress >= 0 then
    Result := Result + Format(' at 0x%.8x', [LastOp.FailAddress]);
end;

initialization
  LastOp.Kind := opkNone;
  LastOp.Started := False;
  LastOp.Failed := False;
  LastOp.Cancelled := False;
  LastOp.ErrorText := '';
  LastOp.FailAddress := OP_NO_ADDRESS;
  LastOp.BytesDone := 0;
  LastOp.BytesTotal := 0;

end.
