unit utilfunc;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

function SetBit(const value: byte; const BitNum: byte): byte;
function ClearBit(const value: byte; const BitNum: byte): byte;
function IsBitSet(const value: DWORD; const BitNum : byte): boolean;
procedure BitSet(bit_val: byte; var val: byte; bit_num: byte);
function BitNum(value: cardinal): integer;
function ByteNum(value: cardinal): integer;

function IsNumber(strSource: string): boolean;

function UpdateCRC32(InitCRC: Cardinal; BufPtr: Pointer; Len: Int64): Cardinal;

//ไดรเวอร์ CH34xPAR ตัวเดียวรับทั้ง CH341 และ CH347 และ CH341DLL.DLL ก็ใส่
//อุปกรณ์ทั้งสองตระกูลลงในรายการเดียวกัน เปิดข้ามตระกูลได้ทั้งที่โปรโตคอลคนละอย่าง
//ทางเดียวที่แยกออกคือดู PID ในพาธของอุปกรณ์ที่ CH341GetDeviceName คืนมา
type
  TWCHDeviceKind = (wchUnknown, wchCH341, wchCH347);

function WCHDeviceKindFromPath(const Path: string): TWCHDeviceKind;

//ชนิดชิปที่ CH347GetChipType คืนมา ค่าตามหัวไฟล์ของ WCH
//อยู่ที่นี่เพราะเป็นข้อมูลล้วน ๆ หน่วยทดสอบจึงเรียกได้โดยไม่ต้องมี DLL
const
  CH347_CHIP_CH341 = 0;
  CH347_CHIP_CH347T = 1;
  CH347_CHIP_CH347F = 2;
  CH347_CHIP_CH339W = 3;
  CH347_CHIP_UNKNOWN = -1;

//แบ็กเอนด์ CH347 ควรรับอุปกรณ์ที่เปิดได้ตัวนี้ไว้ไหม
//
//CH347GetChipType คืน 0 ทั้งตอนที่อุปกรณ์เป็น CH341 จริง และตอนที่ถามไม่สำเร็จ
//ในไบนารีของ WCH ทางออกที่ล้มเหลวทุกเส้น (DeviceIoControl ไม่ผ่าน หรือไบต์
//เวอร์ชันชิปต่ำกว่า 0x18) จบที่ xor al,al เหมือนกันหมด แยกสองกรณีนี้ไม่ได้เลย
//ดังนั้น 0 เดี่ยว ๆ ไม่ใช่หลักฐานว่าเป็น CH341 และห้ามใช้ปฏิเสธอุปกรณ์
//
//กติกาคือปฏิเสธเฉพาะตอนที่ "รู้แน่" ว่าเป็น CH341 ซึ่งมีอยู่ทางเดียวคือ PID
//ในพาธของอุปกรณ์ ที่เหลือทั้งหมดรับไว้ก่อน เพราะการรับ CH341 มาผิดตัวแค่ทำให้
//เปิดแล้วคุยไม่รู้เรื่อง แต่การปฏิเสธ CH347 ของจริงทำให้เครื่องหายไปทั้งตัว
function CH347GateAccepts(ChipType: integer; const Path: string): boolean;

//บอร์ดโปรแกรมเมอร์ CH347Ⅱ V2.13 ต่อขา GPIO ของ CH347 ไว้สองเส้น
//
//  GPIO6 ($40) เลือกแรงดันฝั่งเป้าหมาย ระดับต่ำ = 3.3V ระดับสูง = 1.8V
//  GPIO4 ($10) ไฟแสดงการทำงานบนบอร์ด
//
//ค่าเหล่านี้ถอดจากจุดเรียก CH347GPIO_Set ในโปรแกรมของผู้ผลิต (สองจุดที่ต่างกัน
//แค่ไบต์ข้อมูล $00 กับ $40 โดยแยกทางด้วย ItemIndex ของกลุ่มปุ่มเลือกแรงดัน)
//แล้วยืนยันซ้ำกับเครื่องจริงด้วย CH347GPIO_Get ซึ่งอ่านทิศทางได้ $50 พอดีกับ
//สองขานี้ ไม่ใช่การเดาจากเอกสาร
//
//ระดับตอนเปิดเครื่องคือ 1.8V ทั้งฝั่งฮาร์ดแวร์และฝั่งโปรแกรมของผู้ผลิต ตั้งใจ
//ให้เป็นค่าที่ปลอดภัยที่สุดไว้ก่อน กันจ่ายไฟเกินใส่ชิป 1.8V แล้วพัง
const
  CH347_GPIO_VCC     = $40;   //GPIO6 เลือกแรงดัน
  CH347_GPIO_ACT_LED = $10;   //GPIO4 ไฟแสดงการทำงาน
  CH347_VCC_1V8_MV   = 1800;
  CH347_VCC_3V3_MV   = 3300;

//แปลงแรงดันเป้าหมายเป็นบิตข้อมูลของ GPIO6
//คืน False เมื่อไม่ใช่ระดับที่บอร์ดนี้จ่ายได้ และเมื่อนั้น DataBits จะเป็นค่า
//ของ 1.8V ไว้ให้ เผื่อผู้เรียกพลาดไม่ตรวจผลลัพธ์ จะได้ไม่กลายเป็นจ่าย 3.3V
function CH347VccDataBits(Millivolts: cardinal; out DataBits: byte): boolean;

//เลือกแรงดันที่เหมาะกับช่วง Vcc ของชิป
//
//ชิปที่รับได้ทั้งสองระดับให้เลือกค่าต่ำไว้ก่อน เพราะจ่ายเกินทำชิปพังถาวร
//ส่วนจ่ายขาดแค่คุยไม่รู้เรื่องแล้วลองใหม่ได้ ช่วงที่ว่างหรือกลับหัวถือว่า
//ไม่รู้ คืน False ไม่เดาให้ ผู้เรียกต้องไปถามผู้ใช้เอง
function CH347VccForChip(VccMinMv, VccMaxMv: cardinal;
  out Millivolts: cardinal): boolean;

//แปลงช่อง Vcc ของแค็ตตาล็อก (เช่น "3.3" หรือ "1.8V") เป็นช่วงมิลลิโวลต์
//
//รับเฉพาะระดับมาตรฐานที่เขียนไว้ในแค็ตตาล็อกจริง ๆ ข้อความอื่นคืน False
//และช่วงศูนย์ ไม่ใช่พยายามแกะตัวเลขเอง เพราะเดาผิดข้างสูงทำชิปพัง
function VccRangeMv(const Text: string; out MinMv, MaxMv: cardinal): boolean;

//คำตัดสินหลังรู้จักชิปแล้ว สำหรับบอร์ด CH347 ที่สลับแรงดันได้
//ใช้เลือกว่าจะบอกทางผู้ใช้ว่าอย่างไร ไม่ใช่สลับแรงดันให้เองเงียบ ๆ
type
  TCH347VccAdvice = (
    cvaChipVccUnknown,   //แค็ตตาล็อกไม่ระบุแรงดัน ต้องเปิดดาต้าชีตเอง
    cvaNoUsableRail,     //ชิปต้องการระดับที่บอร์ดนี้จ่ายไม่ได้ (เช่น 5V)
    cvaAutoWillApply,    //เมนูเป็น Auto โปรแกรมจะตั้งให้เองตอนเริ่มงาน
    cvaPinnedMatches,    //ระดับที่ปักหมุดไว้อยู่ในช่วงที่ชิปรับได้แล้ว
    cvaPinnedTooHigh,    //ปักไว้สูงกว่าที่ชิปทนได้ จ่ายจริงเมื่อไรชิปพัง
    cvaPinnedTooLow      //ปักไว้ต่ำกว่าที่ชิปต้องการ ชิปแค่ไม่ตอบ ไม่พัง
  );

//ตัดสินจากช่อง vcc ของแค็ตตาล็อกกับระดับที่ผู้ใช้ปักหมุดไว้ (0 = Auto)
//
//WantMv คือระดับที่บอร์ดควรจ่ายให้ชิปตัวนี้ เชื่อถือได้เฉพาะเมื่อคำตอบ
//ไม่ใช่สองแบบแรก นอกนั้นคง 1.8V ไว้ ทิศทางเดียวกับผู้ช่วยตัวอื่นในไฟล์นี้:
//พลาดต้องพลาดไปทางต่ำ
//
//การเทียบระดับที่ปักไว้ใช้ช่วงของชิป ไม่ใช่เทียบเท่ากับ WantMv ตรง ๆ
//เพราะชิปช่วงกว้างรับได้หลายระดับ ระดับที่อยู่ในช่วงถือว่าใช้ได้ แม้ไม่ใช่
//ค่าที่โหมด Auto จะเลือกให้
function CH347VccAdvise(const CatalogVcc: string; PinnedMv: cardinal;
  out WantMv: cardinal): TCH347VccAdvice;

//ชื่อระดับแรงดันของบอร์ด ใช้คำเดียวกับเมนูเสมอ ข้อความชี้ทางจะได้ไม่หลงทาง
//และไม่ผ่านการจัดรูปเลขตามท้องถิ่น ซึ่งเปลี่ยนจุดทศนิยมเป็นจุลภาคได้
function CH347VccLevelText(Millivolts: cardinal): string;

//ข้อความแรงดันจากแค็ตตาล็อกสำหรับแสดงผล: เติม " V" เมื่อไม่มีหน่วยติดมา
//ช่องว่างคืนช่องว่าง ผู้เรียกต้องตัดสินใจเองว่าจะพูดถึงมันไหม
function CatalogVccDisplay(const Raw: string): string;

//หาแรงดันของชิปให้ได้ก่อนจะไปตัดสินใจอะไรต่อ
//
//ปัญหาคือ chiplist.xml มีแอตทริบิวต์ vcc อยู่แค่ 5 รายการจาก 658 รายการ
//ผู้เรียกที่ดูช่อง vcc อย่างเดียวจึงได้ค่าว่างกับชิปเกือบทุกตัว แล้วก็เงียบ
//ทั้งที่ควรจะเตือน ที่นี่จึงไล่หาสามทางเรียงตามความน่าเชื่อถือ:
//
//  1. ช่อง vcc ในแค็ตตาล็อก ระบุมาตรง ๆ เชื่อได้ที่สุด
//  2. ส่วนท้ายชื่อรุ่น _1.8V / _3.3V ตามธรรมเนียมของ chiplist.xml
//  3. รหัส JEDEC ที่รู้แน่ว่าเป็นตระกูล 1.8V เช่น EF60xx (Winbond W25Q..JW/FW
//     และ W74M) หรือ C225xx (Macronix MX25U) ซึ่งชื่อรุ่นไม่ได้บอกไว้เลย
//
//ทางที่สามสรุปได้เฉพาะ 1.8V เท่านั้น และห้ามสรุปเป็น 3.3V จากรหัสเด็ดขาด
//เพราะทิศทางของความผิดพลาดไม่เท่ากัน: เดาสูงเกินคือจ่าย 3.3V ใส่ชิป 1.8V
//แล้วชิปพังถาวร ส่วนเดาต่ำเกินคือชิปไม่ตอบ แล้วลองใหม่ได้
//
//คืนสตริงรูปแบบเดียวกับช่อง vcc ("1.8" / "3.3") หรือค่าว่างเมื่อไม่รู้จริง ๆ
function ChipVccText(const CatalogVcc, ChipName, ChipID: string): string;

implementation

const
  CRC32Table: array[0..255] of Cardinal =
  ($00000000, $77073096, $EE0E612C, $990951BA,
    $076DC419, $706AF48F, $E963A535, $9E6495A3,
    $0EDB8832, $79DCB8A4, $E0D5E91E, $97D2D988,
    $09B64C2B, $7EB17CBD, $E7B82D07, $90BF1D91,

    $1DB71064, $6AB020F2, $F3B97148, $84BE41DE,
    $1ADAD47D, $6DDDE4EB, $F4D4B551, $83D385C7,
    $136C9856, $646BA8C0, $FD62F97A, $8A65C9EC,
    $14015C4F, $63066CD9, $FA0F3D63, $8D080DF5,

    $3B6E20C8, $4C69105E, $D56041E4, $A2677172,
    $3C03E4D1, $4B04D447, $D20D85FD, $A50AB56B,
    $35B5A8FA, $42B2986C, $DBBBC9D6, $ACBCF940,
    $32D86CE3, $45DF5C75, $DCD60DCF, $ABD13D59,

    $26D930AC, $51DE003A, $C8D75180, $BFD06116,
    $21B4F4B5, $56B3C423, $CFBA9599, $B8BDA50F,
    $2802B89E, $5F058808, $C60CD9B2, $B10BE924,
    $2F6F7C87, $58684C11, $C1611DAB, $B6662D3D,

    $76DC4190, $01DB7106, $98D220BC, $EFD5102A,
    $71B18589, $06B6B51F, $9FBFE4A5, $E8B8D433,
    $7807C9A2, $0F00F934, $9609A88E, $E10E9818,
    $7F6A0DBB, $086D3D2D, $91646C97, $E6635C01,

    $6B6B51F4, $1C6C6162, $856530D8, $F262004E,
    $6C0695ED, $1B01A57B, $8208F4C1, $F50FC457,
    $65B0D9C6, $12B7E950, $8BBEB8EA, $FCB9887C,
    $62DD1DDF, $15DA2D49, $8CD37CF3, $FBD44C65,

    $4DB26158, $3AB551CE, $A3BC0074, $D4BB30E2,
    $4ADFA541, $3DD895D7, $A4D1C46D, $D3D6F4FB,
    $4369E96A, $346ED9FC, $AD678846, $DA60B8D0,
    $44042D73, $33031DE5, $AA0A4C5F, $DD0D7CC9,

    $5005713C, $270241AA, $BE0B1010, $C90C2086,
    $5768B525, $206F85B3, $B966D409, $CE61E49F,
    $5EDEF90E, $29D9C998, $B0D09822, $C7D7A8B4,
    $59B33D17, $2EB40D81, $B7BD5C3B, $C0BA6CAD,

    $EDB88320, $9ABFB3B6, $03B6E20C, $74B1D29A,
    $EAD54739, $9DD277AF, $04DB2615, $73DC1683,
    $E3630B12, $94643B84, $0D6D6A3E, $7A6A5AA8,
    $E40ECF0B, $9309FF9D, $0A00AE27, $7D079EB1,

    $F00F9344, $8708A3D2, $1E01F268, $6906C2FE,
    $F762575D, $806567CB, $196C3671, $6E6B06E7,
    $FED41B76, $89D32BE0, $10DA7A5A, $67DD4ACC,
    $F9B9DF6F, $8EBEEFF9, $17B7BE43, $60B08ED5,

    $D6D6A3E8, $A1D1937E, $38D8C2C4, $04FDFF252,
    $D1BB67F1, $A6BC5767, $3FB506DD, $048B2364B,
    $D80D2BDA, $AF0A1B4C, $36034AF6, $041047A60,
    $DF60EFC3, $A867DF55, $316E8EEF, $04669BE79,

    $CB61B38C, $BC66831A, $256FD2A0, $5268E236,
    $CC0C7795, $BB0B4703, $220216B9, $5505262F,
    $C5BA3BBE, $B2BD0B28, $2BB45A92, $5CB36A04,
    $C2D7FFA7, $B5D0CF31, $2CD99E8B, $5BDEAE1D,

    $9B64C2B0, $EC63F226, $756AA39C, $026D930A,
    $9C0906A9, $EB0E363F, $72076785, $05005713,
    $95BF4A82, $E2B87A14, $7BB12BAE, $0CB61B38,
    $92D28E9B, $E5D5BE0D, $7CDCEFB7, $0BDBDF21,

    $86D3D2D4, $F1D4E242, $68DDB3F8, $1FDA836E,
    $81BE16CD, $F6B9265B, $6FB077E1, $18B74777,
    $88085AE6, $FF0F6A70, $66063BCA, $11010B5C,
    $8F659EFF, $F862AE69, $616BFFD3, $166CCF45,

    $A00AE278, $D70DD2EE, $4E048354, $3903B3C2,
    $A7672661, $D06016F7, $4969474D, $3E6E77DB,
    $AED16A4A, $D9D65ADC, $40DF0B66, $37D83BF0,
    $A9BCAE53, $DEBB9EC5, $47B2CF7F, $30B5FFE9,

    $BDBDF21C, $CABAC28A, $53B39330, $24B4A3A6,
    $BAD03605, $CDD70693, $54DE5729, $23D967BF,
    $B3667A2E, $C4614AB8, $5D681B02, $2A6F2B94,
    $B40BBE37, $C30C8EA1, $5A05DF1B, $2D02EF8D);

function SetBit(const value: byte; const BitNum: byte): byte;
begin
  Result := value or (1 shl BitNum);
end;

function ClearBit(const value: byte; const BitNum: byte): byte;
begin
  Result := value and (not (1 shl BitNum));
end;

function IsBitSet(const value: DWORD; const BitNum : byte): boolean;
begin
  result:=((Value shr BitNum) and 1) = 1;
end;

procedure BitSet(bit_val: byte; var val: byte; bit_num: byte);
begin
  if Boolean(bit_val) then
   val := SetBit(val, bit_num)
  else
   val := ClearBit(val, bit_num);
end;

//ต้องใช้กี่บิตถึงจะเก็บค่านี้ได้
function BitNum(value: cardinal): integer;
var
  i: integer;
  m: cardinal;
begin

  i:= 0;
  m:= 1;

  while m < value do
  begin
    m := m*2;
    Inc(i);
  end;

  result := i;
end;

//ต้องใช้กี่ไบต์ถึงจะเก็บบิตจำนวนนี้ได้
function ByteNum(value: cardinal): integer;
begin
  result := value div 8;
  if (Frac(value /8) > 0) then Inc(result);
end;

function IsNumber(strSource: string): boolean;
begin
  try
    StrToInt(strSource);
    Result:=true;
  except
    on EConvertError do Result:=false;
  end;
end;

//พาธหน้าตาแบบนี้: \\?\usb#vid_1a86&pid_55db&mi_02#7&2887b016&0&0002#{guid}
//อ่านเลขสี่หลักฐานสิบหกหลัง pid_ ออกมาแล้วเทียบกับตารางที่รู้จัก
//ที่ไม่รู้จักคืน wchUnknown ไม่ใช่เดา ผู้เรียกจะได้เลือกเองว่าจะปล่อยผ่านไหม
function WCHDeviceKindFromPath(const Path: string): TWCHDeviceKind;
var
  p: integer;
  Hex: string;
  PID: integer;
begin
  Result := wchUnknown;

  p := Pos('pid_', LowerCase(Path));
  if p = 0 then Exit;

  Hex := Copy(Path, p + 4, 4);
  if Length(Hex) < 4 then Exit;
  if not TryStrToInt('$' + Hex, PID) then Exit;

  case PID of
    //CH341A ในโหมด EPP/MEM คือ 5512 ส่วน 5584 คือตัวเดียวกันหลังลง CH341PAR
    $5512, $5584: Result := wchCH341;
    //CH347T โหมด 1/2/3 และ CH347F ทุกตัวใช้ CH347DLL ไม่ใช่ CH341DLL
    $55DA, $55DB, $55DC, $55DD, $55DE, $55E7: Result := wchCH347;
  end;
end;

function CH347GateAccepts(ChipType: integer; const Path: string): boolean;
begin
  //ตอบว่าเป็นตระกูล CH347 มาชัด ๆ ก็จบ ไม่ต้องไปดูพาธให้เสียเวลา
  if (ChipType = CH347_CHIP_CH347T) or (ChipType = CH347_CHIP_CH347F) or
     (ChipType = CH347_CHIP_CH339W) then Exit(True);

  //ที่เหลือคลุมเครือ ตัดออกได้เฉพาะเมื่อพาธยืนยันว่าเป็น CH341
  //พาธว่างหรืออ่านไม่ได้ก็นับว่าไม่รู้ และไม่รู้แปลว่ารับไว้
  Result := WCHDeviceKindFromPath(Path) <> wchCH341;
end;

function CH347VccDataBits(Millivolts: cardinal; out DataBits: byte): boolean;
begin
  //ตั้งค่าปลอดภัยไว้ก่อนเสมอ แล้วค่อยลดลงเมื่อรู้แน่ว่าผู้เรียกขอ 3.3V
  DataBits := CH347_GPIO_VCC;
  if Millivolts = CH347_VCC_3V3_MV then
  begin
    DataBits := 0;
    Exit(True);
  end;
  Result := Millivolts = CH347_VCC_1V8_MV;
end;

function CH347VccForChip(VccMinMv, VccMaxMv: cardinal;
  out Millivolts: cardinal): boolean;
begin
  Millivolts := CH347_VCC_1V8_MV;

  if (VccMinMv = 0) or (VccMaxMv = 0) or (VccMinMv > VccMaxMv) then Exit(False);

  //ไล่จากระดับต่ำขึ้นสูง ตัวแรกที่อยู่ในช่วงคือคำตอบ
  if (CH347_VCC_1V8_MV >= VccMinMv) and (CH347_VCC_1V8_MV <= VccMaxMv) then
    Exit(True);

  if (CH347_VCC_3V3_MV >= VccMinMv) and (CH347_VCC_3V3_MV <= VccMaxMv) then
  begin
    Millivolts := CH347_VCC_3V3_MV;
    Exit(True);
  end;

  //ชิปที่ต้องการ 5V หรือระดับอื่นที่บอร์ดนี้จ่ายไม่ได้ตกมาที่นี่
  Result := False;
end;

function VccRangeMv(const Text: string; out MinMv, MaxMv: cardinal): boolean;
var
  S: string;
begin
  MinMv := 0;
  MaxMv := 0;
  S := UpperCase(StringReplace(Trim(Text), ' ', '', [rfReplaceAll]));
  if (S = '1.8') or (S = '1.8V') then
  begin
    MinMv := 1650;
    MaxMv := 1950;
  end
  else if (S = '2.5') or (S = '2.5V') then
  begin
    MinMv := 2300;
    MaxMv := 2700;
  end
  else if (S = '3.3') or (S = '3.3V') then
  begin
    MinMv := 2700;
    MaxMv := 3600;
  end
  else if (S = '5') or (S = '5V') or (S = '5.0') or (S = '5.0V') then
  begin
    MinMv := 4500;
    MaxMv := 5500;
  end;
  Result := MinMv <> 0;
end;

//รหัส JEDEC สี่หลักแรกของตระกูลที่เป็น 1.8V ล้วน
//
//ตรวจทานกับตารางชิปทุกไฟล์ที่มากับโปรแกรม (chiplist, flashrom, ezp,
//imsprog รวม 1751 รายการ): ทุกรายการที่ขึ้นต้นด้วยรหัสเหล่านี้เป็นชิป 1.8V
//ทั้งหมด ไม่มีสมาชิกแรงดันอื่นปนเลย และ tools\validate_chiplist.py คุม
//ข้อกำหนดนี้ไว้ในทุก build กันตารางรุ่นหลังลากรหัสไหนไปใช้กับชิปแรงดันอื่น
//
//C225 เคยอยู่ในรายการนี้และเป็นกับดัก: Macronix แปะรหัส C225xx ให้ทั้ง
//MX25U (1.8V) และ MX25L1635E/1636E/3239E/6439E (3V) กับ MX25V4035/8035
//(2.3-3.6V) รหัสจึงสรุปแรงดันไม่ได้ ตระกูล MX25U ใช้กติกาชื่อรุ่นใน
//ChipVccText แทน เพราะชื่อไม่ชนกันแม้รหัสชน ห้ามเอา C225 กลับมาใส่
const
  Vcc18Prefixes: array[0..18] of string = (
    'EF50',   //Winbond W25Q..BW
    'EF60',   //Winbond W25Q..EW/FW/JW, W74M..JW
    'EF80',   //Winbond W25Q..JW-IM, W25Q512NW-IM
    'EF8A',   //Winbond W77Q..JW/NW secure flash
    'EF8E',   //Winbond W77T..NW secure flash
    'EF5B',   //Winbond W35T..NW
    'C860',   //GigaDevice GD25LQ/LD/LB/LR
    'C863',   //GigaDevice GD25LF
    'C867',   //GigaDevice GD25LB..E/LR..E
    '2041',   //XMC XM25QU/LU/RU
    '2050',   //XMC XM25QU/LU
    '2044',   //XMC XM25RU256C
    '20BB',   //Micron MT25QU, N25Q..A11/..1E
    '2C5B',   //Micron MT35XU
    '9D70',   //ISSI IS25WP
    '9D12',   //ISSI IS25WQ
    'E060',   //Boya BY25Q..AL, ACE ACE25A..G
    '1C38',   //EON EN25S
    'BA00'    //Zetta ZD25LQ
  );

function ChipVccText(const CatalogVcc, ChipName, ChipID: string): string;
var
  N, I: string;
  k: integer;
begin
  //1. ระบุมาในแค็ตตาล็อกแล้ว จบ
  Result := Trim(CatalogVcc);
  if Result <> '' then Exit;

  //2. ชื่อรุ่นบอกไว้เอง
  N := UpperCase(ChipName);
  if Pos('1.8V', N) > 0 then Exit('1.8');
  if Pos('3.3V', N) > 0 then Exit('3.3');

  //2.5 ตระกูลที่สะกดแรงดันไว้ในชื่อ: MX25U/MX66U คือสาย 1.8V ของ Macronix
  //ตัดสินจากชื่อ ไม่ใช่จากรหัส เพราะ Macronix ใช้รหัส C225xx ปนกันทั้ง
  //MX25U (1.8V), MX25L1635E/3239E/6439E (3V) และ MX25V (ช่วงกว้าง)
  //ชื่อรุ่นไม่เคยชนกัน รหัสชน
  if (Pos('MX25U', N) = 1) or (Pos('MX66U', N) = 1) then Exit('1.8');

  //3. รหัส JEDEC ของตระกูล 1.8V ที่ชื่อไม่ได้บอก
  I := UpperCase(Trim(ChipID));
  if Length(I) >= 4 then
    for k := Low(Vcc18Prefixes) to High(Vcc18Prefixes) do
      if Copy(I, 1, 4) = Vcc18Prefixes[k] then Exit('1.8');

  //ไม่รู้ ต้องบอกว่าไม่รู้ ห้ามเดาเป็น 3.3 เพราะนั่นคือทิศที่ทำชิปพัง
  Result := '';
end;

function CH347VccAdvise(const CatalogVcc: string; PinnedMv: cardinal;
  out WantMv: cardinal): TCH347VccAdvice;
var
  MinMv, MaxMv: cardinal;
begin
  WantMv := CH347_VCC_1V8_MV;
  if not VccRangeMv(CatalogVcc, MinMv, MaxMv) then Exit(cvaChipVccUnknown);
  if not CH347VccForChip(MinMv, MaxMv, WantMv) then Exit(cvaNoUsableRail);
  if PinnedMv = 0 then Exit(cvaAutoWillApply);
  if (PinnedMv >= MinMv) and (PinnedMv <= MaxMv) then Exit(cvaPinnedMatches);
  if PinnedMv > MaxMv then Exit(cvaPinnedTooHigh);
  Result := cvaPinnedTooLow;
end;

function CH347VccLevelText(Millivolts: cardinal): string;
begin
  case Millivolts of
    CH347_VCC_1V8_MV: Result := '1.8 V';
    CH347_VCC_3V3_MV: Result := '3.3 V';
    else Result := IntToStr(Millivolts) + ' mV';
  end;
end;

function CatalogVccDisplay(const Raw: string): string;
begin
  Result := Trim(Raw);
  if Result = '' then Exit;
  if Pos('V', UpperCase(Result)) = 0 then Result := Result + ' V';
end;

function UpdateCRC32(InitCRC: Cardinal; BufPtr: Pointer; Len: Int64): Cardinal;
var
  crc: Cardinal;
  index: Integer;
  i: Cardinal;
  P: PByte;
begin
  if len < 1 then Exit(0);
  crc := InitCRC;
  //อ่านทีละไบต์จริง ๆ: ของเดิม cast เป็น Cardinal ทำให้โหลดสี่ไบต์ต่อรอบ
  //(ค่า CRC ถูกเพราะ and $FF ทิ้งส่วนเกิน) สามรอบท้ายจึงอ่านเลยท้ายบัฟเฟอร์
  P := PByte(BufPtr);
  for i := 0 to Len - 1 do
  begin
    index := ( crc xor P[i] ) and $000000FF;
    crc := (crc shr 8) xor CRC32Table[index];
  end;
  Result := not crc;
end;

end.

