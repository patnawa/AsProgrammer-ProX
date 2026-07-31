unit protbits;

//แปลความหมายบิตป้องกันการเขียนของ SPI NOR ตระกูล 25
//
//status register ดิบ ๆ อ่านแล้วไม่รู้เรื่อง หน่วยนี้แปลงเป็นข้อความที่อ่านออก
//และคำนวณกลับได้ว่าช่วงไหนของชิปถูกล็อกอยู่
//
//การจัดวางบิตยึดตาม Winbond W25Q ซึ่ง GigaDevice, XMC, Zetta และอีกหลายเจ้า
//ทำตาม ยี่ห้ออื่นอาจต่างออกไป จึงต้องบอกผู้ใช้ว่านี่คือการตีความ

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

type
  //การจัดวางบิตป้องกันต่างกันตามยี่ห้อ และต่างกันในทางที่อันตราย
  //
  //ตีความ Macronix ด้วยแผนผังของ Winbond จะอ่าน BP ได้แค่สามบิตจากสี่บิต
  //ช่วงที่รายงานจึงเล็กกว่าที่ถูกล็อกจริง แล้วการ์ดกันเขียนก็ปล่อยผ่าน
  //ส่วน Spansion ใช้บิต 6 กับ 5 เป็นธงความผิดพลาด ไม่ใช่ SEC กับ TB
  //อ่านเป็น SEC/TB จึงได้ทิศทางการล็อกที่กลับหัวเมื่อคำสั่งก่อนหน้าล้มเหลว
  TProtLayout = (
    plWinbond,    //SEC บิต6, TB บิต5, BP สามบิตที่ 4:2, CMP ที่ SR2 บิต6
    plMacronix,   //BP สี่บิตที่ 5:2, ไม่มี SEC, ทิศทางอยู่ใน config register
    plMicron,     //BP3 บิต6, TB บิต5, BP2:0 บิต 4:2
    plSpansion,   //บิต6 = P_ERR บิต5 = E_ERR, TBPROT อยู่ใน config register
    plSST,        //BP สี่บิตที่ 5:2, บิต7 = BPL
    plUnknown     //ไม่รู้จักยี่ห้อนี้ ใช้แผนผัง Winbond แต่ต้องบอกผู้ใช้
  );

  TProtInfo = record
    BP: byte;          //BP0..BP2 รวมเป็นตัวเลข 0..7 (0..15 บนแผนผังสี่บิต)
    TB: boolean;       //True = ล็อกจากล่าง, False = ล็อกจากบน
    SEC: boolean;      //True = หน่วยเป็นเซกเตอร์ 4K, False = บล็อก 64K
    CMP: boolean;      //กลับด้านพื้นที่ที่ถูกล็อก
    SRP0, SRP1: boolean;
    QE: boolean;
    WPS: boolean;
    Busy, WEL: boolean;

    //แผนผังที่ใช้ตีความ และตีความได้ครบหรือไม่
    //
    //RangeKnown = False แปลว่ารู้ว่ามีอะไรถูกล็อกอยู่ แต่บอกไม่ได้ว่าช่วงไหน
    //ผู้เรียกต้องปฏิบัติกับมันเหมือน "ไม่รู้" ไม่ใช่ "ปลอดภัย"
    Layout: TProtLayout;
    RangeKnown: boolean;
    BPBits: byte;      //3 หรือ 4 แล้วแต่แผนผัง
  end;

  //สถานะการล็อก status register ที่บอกได้จาก SRP1:SRP0
  TSRLock = (
    srlSoftware,   //0:0 เขียน status register ได้ตามปกติ
    srlHardware,   //0:1 ขา WP# เป็นตัวตัดสิน
    srlPowerLock,  //1:0 ล็อกจนกว่าจะตัดไฟแล้วจ่ายใหม่
    srlPermanent   //1:1 ล็อกถาวร ปลดไม่ได้อีกเลย
  );

  //ผลของคำสั่งเขียนหรือลบที่เพิ่งจบไป
  TPEFail = (
    peNone,
    peProgram,     //ชิปแจ้งว่าคำสั่งเขียนล้มเหลว
    peErase,       //ชิปแจ้งว่าคำสั่งลบล้มเหลว
    peProtect      //ชิปแจ้งว่าคำสั่งถูกปฏิเสธเพราะพื้นที่ถูกป้องกันอยู่
  );

//แยกบิตออกจาก status register สองไบต์ โดยใช้แผนผังของ Winbond
//เก็บไว้เพื่อความเข้ากันได้ ทางที่ควรใช้คือ DecodeProtEx ซึ่งรู้จักยี่ห้อ
function DecodeProt(SR1, SR2: byte): TProtInfo;

//แผนผังที่ยี่ห้อนี้ใช้ ดูจากไบต์แรกของ 9Fh
function LayoutOf(ManufID: byte): TProtLayout;
function LayoutName(L: TProtLayout): string;

//แยกบิตโดยรู้ว่าเป็นชิปยี่ห้อไหน
//
//CR คือรีจิสเตอร์ตัวที่สามซึ่งความหมายต่างกันตามยี่ห้อ: Macronix อ่านด้วย
//15h บิต 3 คือ TB, Spansion อ่านด้วย 35h บิต 5 คือ TBPROT, ส่วนตระกูล
//Winbond อ่านด้วย 15h ได้ Status Register 3 ซึ่งบิต 2 คือ WPS ตัวจริง
//(บิต 2 ของ SR2 ที่เคยใช้เป็นบิตสงวน อ่านได้ศูนย์เสมอ WPS จึงไม่เคยถูกเห็น
//และการ์ดบิตล็อกรายบล็อกทั้งเส้นไม่เคยได้ทำงานเลย)
//ส่งค่า 0 มาได้ถ้ายังไม่ได้อ่าน แล้วผลจะบอกว่าตีความช่วงไม่ได้
function DecodeProtEx(ManufID, SR1, SR2, CR: byte): TProtInfo;

//แบบเดียวกับ DecodeProtEx แต่บอกตรง ๆ ว่าอ่าน CR มาจริงหรือไม่
//
//การใช้ค่า 0 เป็นสัญญาณ "ยังไม่ได้อ่าน" แยกไม่ออกจาก CR ที่เป็นศูนย์จริง ๆ
//และเปิดทางให้ขยะอย่าง FF จากบัสลอยถูกเชื่อเป็นค่าจริง ผู้เรียกที่รู้ว่า
//การอ่านล้มเหลวหรือได้ FF ล้วนต้องส่ง HaveCR = False มา
function DecodeProtVendor(ManufID, SR1, SR2, CR: byte;
  HaveCR: boolean): TProtInfo;

//SRP1:SRP0 บอกอะไร
function SRLockState(const P: TProtInfo): TSRLock;
function SRLockText(L: TSRLock): string;

//ปลดล็อกด้วยการเขียน status register จะได้ผลหรือไม่
//ถ้าไม่ได้ผล การพยายามเขียนแล้วล้มเหลวเงียบ ๆ คือสิ่งที่จะเกิดขึ้น
function CanUnlockBySoftware(const P: TProtInfo): boolean;

//ชิปแจ้งว่าคำสั่งเขียนหรือลบที่เพิ่งจบไปล้มเหลวหรือไม่
//
//VendorStatus คือรีจิสเตอร์เฉพาะยี่ห้อ  Micron ใช้ flag status register (70h)
//Macronix ใช้ security register (2Bh)  Spansion อ่านจาก SR1 จึงไม่ต้องใช้
//ยี่ห้อที่ไม่มีธงพวกนี้คืน peNone เสมอ เพราะบิต 6 กับ 5 ของมันคือ SEC กับ TB
//การตีความบิตเหล่านั้นเป็นความผิดพลาดจะทำให้ชิปดี ๆ ถูกรายงานว่าเสีย
function ProgEraseFail(ManufID, SR1, VendorStatus: byte;
  HaveVendorStatus: boolean): TPEFail;
function PEFailText(F: TPEFail): string;

//ยี่ห้อนี้มีธงบอกความล้มเหลวให้อ่านหรือไม่ และต้องอ่านจากคำสั่งไหน
//คืน 0 เมื่อไม่ต้องอ่านรีจิสเตอร์เพิ่ม
function VendorStatusOpcode(ManufID: byte): byte;

//บิตใน SR1 ที่ประกอบกันเป็นการป้องกันของแผนผังนี้ คือบิตที่ต้องล้างเพื่อปลดล็อก
//
//หน้ากากนี้ต่างกันตามยี่ห้อในทางที่สำคัญ บิต 6 ของ Macronix คือ QE ไม่ใช่ SEC
//ส่วนบิต 6 กับ 5 ของ Spansion เป็นธงความผิดพลาดซึ่งเขียนไม่ได้อยู่แล้ว
function ProtectionMaskSR1(L: TProtLayout): byte;

//ค่าที่ควรเขียนกลับเพื่อปลดล็อก โดยไม่แตะบิตที่ไม่เกี่ยวข้อง
//
//สิ่งที่ต้องไม่หายไปคือ QE บอร์ดที่บูตจากแฟลชในโหมด quad จะบูตไม่ขึ้นอีกเลย
//ถ้า QE ถูกล้างไปพร้อมกับบิตป้องกัน และไม่มีอะไรบอกว่าทำไม
//เดิมการปลดล็อกเขียน 00h ทับทั้งไบต์โดยไม่ดูว่าบิตไหนคืออะไร
procedure ClearProtection(const P: TProtInfo; SR1, SR2: byte;
  out NewSR1, NewSR2: byte);

//ยังมีอะไรถูกป้องกันอยู่หรือไม่หลังจากพยายามปลดล็อกไปแล้ว
//ใช้ตรวจว่าการปลดล็อกได้ผลจริง ไม่ใช่ถูกชิปรับไว้แล้วเมินเฉย
function StillProtected(const P: TProtInfo): boolean;

//คำอธิบายแต่ละบิตแบบอ่านออก หนึ่งบรรทัดต่อหนึ่งเรื่อง
function ProtToText(const P: TProtInfo): string;

//ช่วงที่ถูกล็อกของชิปขนาด ChipSize
//คืน False เมื่อไม่มีอะไรถูกล็อก
//
//ระวัง: False แปลว่า "ไม่มีอะไรถูกล็อก" เท่านั้น ไม่ได้แปลว่า "เขียนได้แน่"
//ต้องดู P.RangeKnown ประกอบด้วย ถ้าเป็น False แปลว่ามีของถูกล็อกอยู่แต่บอก
//ไม่ได้ว่าตรงไหน ซึ่งต้องเตือนผู้ใช้ ไม่ใช่ปล่อยผ่าน
function ProtectedRange(const P: TProtInfo; ChipSize: cardinal;
  out FromAddr, ToAddr: cardinal): boolean;

//ประกอบ SR1 กลับจากค่าที่แก้แล้ว
function EncodeProtSR1(const P: TProtInfo): byte;

type
  //ตัวอ่านบิตล็อกของบล็อกหนึ่งบล็อก แยกออกจากฮาร์ดแวร์เพื่อให้ทดสอบได้
  //คืน False เมื่ออ่านไม่สำเร็จ ซึ่งไม่เหมือนกับอ่านได้ว่าไม่ล็อก
  TBlockLockProc = function(Addr: cardinal; out Locked: boolean): boolean;

//หาว่าช่วงที่จะแตะทับกับบล็อกที่ถูกล็อกไว้หรือไม่ เมื่อชิปตั้ง WPS = 1
//
//WPS = 1 แปลว่าบิต BP ใน status register ไม่มีความหมายแล้ว พื้นที่ที่ถูก
//ล็อกมาจากบิตรายบล็อกซึ่งต้องอ่านทีละบล็อกด้วย 3Dh เดิมโปรแกรมได้แค่บอกว่า
//ตีความไม่ได้แล้วปล่อยผ่าน ซึ่งแปลว่าชิปกลุ่มนี้ไม่มีการ์ดกันเขียนเลย
//
//สแกนเฉพาะบล็อกที่ทับกับช่วงที่ขอ ไม่ต้องไล่ทั้งชิป
//Readable บอกว่าอ่านบิตล็อกได้อย่างน้อยหนึ่งบล็อกหรือไม่ ถ้าอ่านไม่ได้เลย
//แปลว่าไม่รู้ ผู้เรียกต้องบอกผู้ใช้แบบนั้น ห้ามสรุปว่าปลอดภัย
function BlockLockConflict(Reader: TBlockLockProc;
  ChipSize, BlockSize, StartAddr, Len: cardinal;
  out LockedAt: cardinal; out Readable: boolean): boolean;

implementation

function LayoutOf(ManufID: byte): TProtLayout;
begin
  case ManufID of
    //Winbond และกลุ่มที่ทำตามแผนผังเดียวกัน
    //GigaDevice, Eon, XTX, Zetta, Fudan, Boya, Puya, Zbit
    $EF, $C8, $1C, $0B, $BA, $A1, $68, $85, $5E:
      Result := plWinbond;

    //Macronix และ ISSI ใช้ BP สี่บิต ไม่มี SEC
    $C2, $9D:
      Result := plMacronix;

    //Micron และ ST
    $20:
      Result := plMicron;

    //Spansion, Cypress, Infineon
    $01:
      Result := plSpansion;

    //SST
    $BF:
      Result := plSST;

  else
    Result := plUnknown;
  end;
end;

function LayoutName(L: TProtLayout): string;
begin
  case L of
    plWinbond:  Result := 'Winbond style';
    plMacronix: Result := 'Macronix style, four protect bits';
    plMicron:   Result := 'Micron style, four protect bits';
    plSpansion: Result := 'Spansion style, bits 6 and 5 are error flags';
    plSST:      Result := 'SST style, four protect bits';
  else
    Result := 'unknown vendor, read as Winbond';
  end;
end;

function DecodeProtVendor(ManufID, SR1, SR2, CR: byte;
  HaveCR: boolean): TProtInfo;
begin
  FillChar(Result, SizeOf(Result), 0);

  Result.Busy := (SR1 and $01) <> 0;
  Result.WEL  := (SR1 and $02) <> 0;
  Result.SRP0 := (SR1 and $80) <> 0;

  Result.SRP1 := (SR2 and $01) <> 0;
  Result.CMP  := (SR2 and $40) <> 0;

  Result.Layout := LayoutOf(ManufID);
  Result.RangeKnown := True;

  case Result.Layout of

    plMacronix, plSST:
      begin
        //BP กว้างสี่บิต บิต 5 เป็นบิตบนสุดของ BP ไม่ใช่ TB
        //อ่านด้วยแผนผังของ Winbond จะได้ BP แค่สามบิต ช่วงที่รายงานจึงเล็ก
        //กว่าที่ถูกล็อกจริง แล้วการ์ดกันเขียนก็ปล่อยผ่านทั้งที่ไม่ควร
        Result.BP := (SR1 shr 2) and $0F;
        Result.BPBits := 4;
        Result.SEC := False;
        Result.CMP := False;

        //ยี่ห้อพวกนี้ไม่มี SR2 ค่าที่ส่งเข้ามาจึงไม่มีความหมาย
        Result.SRP1 := False;
        Result.WPS  := False;

        //Macronix เก็บ QE ไว้ที่บิต 6 ของ SR1 ส่วน SST ไม่มี QE เลย
        if Result.Layout = plMacronix then
          Result.QE := (SR1 and $40) <> 0
        else
          Result.QE := False;

        //ทิศทางอยู่ใน configuration register บิต 3 ของ Macronix
        //ไม่ได้อ่านมาก็บอกไม่ได้ว่าล็อกจากบนหรือจากล่าง
        Result.TB := HaveCR and ((CR and $08) <> 0);
        if (Result.BP <> 0) and (not HaveCR) then Result.RangeKnown := False;
      end;

    plMicron:
      begin
        //BP3 อยู่ที่บิต 6, TB อยู่ที่บิต 5, BP2:0 อยู่ที่ 4:2
        Result.BP := ((SR1 shr 2) and $07) or (((SR1 shr 6) and $01) shl 3);
        Result.BPBits := 4;
        Result.TB  := (SR1 and $20) <> 0;
        Result.SEC := False;
        Result.CMP := False;
        Result.QE  := False;
        Result.SRP1 := False;
        Result.WPS  := False;
      end;

    plSpansion:
      begin
        //บิต 6 กับ 5 เป็น P_ERR กับ E_ERR อ่านเป็น SEC/TB ไม่ได้
        Result.BP := (SR1 shr 2) and $07;
        Result.BPBits := 3;
        Result.SEC := False;
        Result.CMP := False;
        Result.SRP1 := False;
        Result.WPS  := False;

        //TBPROT กับ QUAD อยู่ใน configuration register บิต 5 และบิต 1
        Result.TB := HaveCR and ((CR and $20) <> 0);
        Result.QE := HaveCR and ((CR and $02) <> 0);
        if (Result.BP <> 0) and (not HaveCR) then Result.RangeKnown := False;
      end;

  else
    //Winbond และยี่ห้อที่ยังไม่รู้จัก
    Result.BP   := (SR1 shr 2) and $07;
    Result.BPBits := 3;
    Result.TB   := (SR1 and $20) <> 0;
    Result.SEC  := (SR1 and $40) <> 0;
    Result.QE   := (SR2 and $02) <> 0;
    //WPS ตัวจริงอยู่ที่ Status Register 3 (อ่านด้วย 15h) บิต 2 ไม่ใช่ SR2
    //บิต 2 ซึ่งเป็นบิตสงวนที่อ่านได้ศูนย์เสมอ CR ของตระกูลนี้คือ SR3
    //ไม่ได้อ่านมาก็ต้องถือว่าไม่รู้ (False) แบบเดียวกับพฤติกรรมเดิม
    Result.WPS  := HaveCR and ((CR and $04) <> 0);
  end;
end;

function DecodeProtEx(ManufID, SR1, SR2, CR: byte): TProtInfo;
begin
  //ของเดิมใช้ค่า 0 เป็นสัญญาณ "ยังไม่ได้อ่าน CR" คงพฤติกรรมนั้นไว้ให้
  //ผู้เรียกเก่า ทางที่ควรใช้คือ DecodeProtVendor ที่บอก HaveCR ตรง ๆ
  Result := DecodeProtVendor(ManufID, SR1, SR2, CR, CR <> 0);
end;

function DecodeProt(SR1, SR2: byte): TProtInfo;
begin
  //EFh คือ Winbond ซึ่งเป็นแผนผังที่หน่วยนี้ใช้มาแต่เดิม
  Result := DecodeProtEx($EF, SR1, SR2, 0);
end;

function SRLockState(const P: TProtInfo): TSRLock;
begin
  if P.SRP1 then
  begin
    if P.SRP0 then Result := srlPermanent else Result := srlPowerLock;
  end
  else
  begin
    if P.SRP0 then Result := srlHardware else Result := srlSoftware;
  end;
end;

function SRLockText(L: TSRLock): string;
begin
  case L of
    srlSoftware:
      Result := 'the status register can be written';
    srlHardware:
      Result := 'the WP# pin decides: hold WP# high or the unlock will be ' +
                'accepted and silently ignored';
    srlPowerLock:
      Result := 'the status register is locked until the chip is powered ' +
                'down and up again';
  else
    Result := 'the status register is permanently locked, this chip can ' +
              'never be unlocked';
  end;
end;

function CanUnlockBySoftware(const P: TProtInfo): boolean;
begin
  //srlHardware ยังปลดได้ถ้าขา WP# ถูกดึงสูงไว้ ซึ่งเราไม่มีทางรู้จากที่นี่
  //จึงนับว่าปลดได้ แล้วให้การตรวจหลังปลดเป็นตัวจับว่าไม่สำเร็จ
  Result := SRLockState(P) in [srlSoftware, srlHardware];
end;

function VendorStatusOpcode(ManufID: byte): byte;
begin
  case ManufID of
    $20: Result := $70;   //Micron flag status register
    $C2: Result := $2B;   //Macronix security register
  else
    Result := 0;
  end;
end;

function ProtectionMaskSR1(L: TProtLayout): byte;
begin
  case L of
    //SRP0 บิต7, SEC บิต6, TB บิต5, BP2..BP0 บิต 4:2
    plWinbond:  Result := %11111100;

    //SRWD บิต7, BP3..BP0 บิต 5:2 และต้องไม่แตะบิต6 ซึ่งคือ QE
    plMacronix: Result := %10111100;

    //BPL บิต7, BP3..BP0 บิต 5:2 บิต6 เป็นสถานะ AAI ซึ่งอ่านอย่างเดียว
    plSST:      Result := %10111100;

    //SRWD บิต7, BP3 บิต6, TB บิต5, BP2..BP0 บิต 4:2
    plMicron:   Result := %11111100;

    //SRWD บิต7, BP2..BP0 บิต 4:2 บิต 6:5 เป็นธงความผิดพลาดซึ่งเขียนไม่ได้
    plSpansion: Result := %10011100;

  else
    //ไม่รู้จักยี่ห้อ ใช้หน้ากากของ Winbond
    Result := %11111100;
  end;
end;

procedure ClearProtection(const P: TProtInfo; SR1, SR2: byte;
  out NewSR1, NewSR2: byte);
begin
  NewSR1 := SR1 and (not ProtectionMaskSR1(P.Layout));

  //CMP กลับด้านพื้นที่ที่ถูกล็อก ถ้าไม่ล้างไปด้วย การล้าง BP จนเป็นศูนย์
  //จะกลายเป็นการล็อกทั้งชิปแทนที่จะเป็นการปลดล็อก
  //
  //WPS ไม่ได้อยู่ในไบต์นี้: มันคือบิต 2 ของ SR3 (บิต 2 ของ SR2 เป็นบิต
  //สงวน การล้างมันคือการยิงเป้าผิดตำแหน่ง) และถึงอยู่ก็ไม่ควรล้าง เพราะ
  //ของที่ล็อกจริงคือบิตรายบล็อก ซึ่งปลดด้วยคำสั่ง global unlock 98h
  //ในเส้นทางปลดล็อก ไม่ใช่ด้วยการเขียน status register
  //
  //QE อยู่ที่บิต 1 และต้องอยู่ต่อ ทุกบิตที่เหลือก็เก็บไว้ตามเดิม
  NewSR2 := SR2 and (not byte(%01000000));
end;

function StillProtected(const P: TProtInfo): boolean;
begin
  Result := (P.BP <> 0) or P.CMP or P.WPS;
end;

function ProgEraseFail(ManufID, SR1, VendorStatus: byte;
  HaveVendorStatus: boolean): TPEFail;
begin
  Result := peNone;

  //FF ล้วนคือสิ่งที่บัสที่ไม่มีใครขับกลับมาให้ ไม่ใช่คำตอบของชิป
  //บนรีจิสเตอร์ของ Micron ค่านั้นมีบิต 5 กับ 4 ติดอยู่ ซึ่งอ่านออกมาได้ว่า
  //"เขียนล้มเหลวและลบล้มเหลวพร้อมกัน" บวกกับบิต 7 ที่แปลว่าพร้อมใช้งาน
  //ซึ่งเป็นชุดค่าที่ชิปจริงไม่มีทางรายงาน อย่าเอาไปกล่าวหาชิปที่ยังดีอยู่
  if HaveVendorStatus and (VendorStatus = $FF) then Exit;

  case ManufID of

    //Micron และ ST: flag status register 70h
    //  บิต 5 erase error, บิต 4 program error, บิต 1 protection error
    //  (MT25Q/N25Q datasheet: bit 5 คือ erase, bit 4 คือ program)
    $20:
      begin
        if not HaveVendorStatus then Exit;
        if (VendorStatus and $02) <> 0 then Exit(peProtect);
        if (VendorStatus and $20) <> 0 then Exit(peErase);
        if (VendorStatus and $10) <> 0 then Exit(peProgram);
      end;

    //Macronix: security register 2Bh บิต 5 P_FAIL บิต 6 E_FAIL
    $C2:
      begin
        if not HaveVendorStatus then Exit;
        if (VendorStatus and $20) <> 0 then Exit(peProgram);
        if (VendorStatus and $40) <> 0 then Exit(peErase);
      end;

    //Spansion, Cypress, Infineon: อยู่ใน SR1 เอง
    //  บิต 6 P_ERR, บิต 5 E_ERR
    $01:
      begin
        if (SR1 and $40) <> 0 then Exit(peProgram);
        if (SR1 and $20) <> 0 then Exit(peErase);
      end;

  end;
end;

function PEFailText(F: TPEFail): string;
begin
  case F of
    peProgram: Result := 'the chip reported that the program command failed';
    peErase:   Result := 'the chip reported that the erase command failed';
    peProtect: Result := 'the chip refused the command because the area is protected';
  else
    Result := '';
  end;
end;

function EncodeProtSR1(const P: TProtInfo): byte;
begin
  Result := (P.BP and $07) shl 2;
  if P.TB then Result := Result or $20;
  if P.SEC then Result := Result or $40;
  if P.SRP0 then Result := Result or $80;
end;

function ProtectedRange(const P: TProtInfo; ChipSize: cardinal;
  out FromAddr, ToAddr: cardinal): boolean;
var
  Unit_, Area: cardinal;
begin
  Result := False;
  FromAddr := 0;
  ToAddr := 0;
  if ChipSize = 0 then Exit;

  //BP=0 คือไม่ล็อกอะไรเลย เว้นแต่ CMP กลับด้านให้กลายเป็นล็อกทั้งชิป
  if P.BP = 0 then
  begin
    if P.CMP then
    begin
      FromAddr := 0;
      ToAddr := ChipSize - 1;
      Exit(True);
    end;
    Exit(False);
  end;

  //BP=7 ล็อกทั้งชิป ไม่ว่าจะอยู่ในโหมดเซกเตอร์หรือไม่: ตาราง Winbond ระบุ
  //BP2:0 = 111 เป็น ALL ทุกแถว รวมแถว SEC=1 ด้วย (สูตร 4K shl 6 = 256K
  //ที่เคยใช้กับ SEC=1 รายงานพื้นที่เล็กกว่าจริง 32 เท่า แล้วการ์ดกันเขียน
  //ก็ปล่อยงานผ่านให้ชิปทิ้งเงียบ ๆ)
  //เป็นกรณีพิเศษของแผนผังที่ BP กว้างสามบิตเท่านั้น บนแผนผังสี่บิต 7 คือ
  //ค่ากลาง ๆ ค่าหนึ่ง ไม่ใช่ค่าสูงสุด การเหมาว่าล็อกทั้งชิปจะเกินความจริง
  if (P.BPBits <> 4) and (P.BP = 7) then
  begin
    if P.CMP then Exit(False);
    FromAddr := 0;
    ToAddr := ChipSize - 1;
    Exit(True);
  end;

  if P.SEC then Unit_ := 4 * 1024 else Unit_ := 64 * 1024;

  //ขนาดพื้นที่คือ 2^(BP-1) หน่วย
  //BP กว้างสี่บิตเลื่อนได้ถึง 14 ครั้ง ซึ่งบวกกับ 16 ของหน่วย 64K แล้วยังไม่ล้น
  //cardinal แต่ก็ไม่ปล่อยให้ไปพึ่งโชค เพราะการเลื่อนเกินขอบให้ผลที่ไม่นิยาม
  if (P.BP - 1) > 24 then
    Area := ChipSize
  else
    Area := Unit_ shl (P.BP - 1);
  if Area > ChipSize then Area := ChipSize;

  if P.TB then
  begin
    //ล็อกจากปลายล่าง
    FromAddr := 0;
    ToAddr := Area - 1;
  end
  else
  begin
    //ล็อกจากปลายบน
    FromAddr := ChipSize - Area;
    ToAddr := ChipSize - 1;
  end;

  //CMP กลับด้าน พื้นที่ที่เหลือกลายเป็นพื้นที่ที่ถูกล็อกแทน
  if P.CMP then
  begin
    if P.TB then
    begin
      FromAddr := Area;
      ToAddr := ChipSize - 1;
    end
    else
    begin
      FromAddr := 0;
      ToAddr := ChipSize - Area - 1;
    end;
  end;

  Result := ToAddr >= FromAddr;
end;

function BlockLockConflict(Reader: TBlockLockProc;
  ChipSize, BlockSize, StartAddr, Len: cardinal;
  out LockedAt: cardinal; out Readable: boolean): boolean;
var
  Addr, EndAddr: int64;
  Locked: boolean;
begin
  Result := False;
  Readable := False;
  LockedAt := 0;

  if (Reader = nil) or (ChipSize = 0) or (BlockSize = 0) or (Len = 0) then Exit;
  if StartAddr >= ChipSize then Exit;

  //บวกด้วย int64 เพราะ StartAddr + Len ล้น cardinal ได้
  EndAddr := int64(StartAddr) + int64(Len);
  if EndAddr > ChipSize then EndAddr := ChipSize;

  //เริ่มที่ต้นบล็อกที่แอดเดรสเริ่มตกอยู่ เพราะบิตล็อกคุมทั้งบล็อก
  Addr := (int64(StartAddr) div BlockSize) * BlockSize;

  while Addr < EndAddr do
  begin
    if Reader(cardinal(Addr), Locked) then
    begin
      Readable := True;
      if Locked then
      begin
        LockedAt := cardinal(Addr);
        Exit(True);
      end;
    end;
    Inc(Addr, BlockSize);
  end;
end;

function ProtToText(const P: TProtInfo): string;
begin
  Result :=
    Format('layout    %s', [LayoutName(P.Layout)]) + LineEnding +
    Format('BP        %d      protected size selector, %d bits wide',
           [P.BP, P.BPBits]) + LineEnding +
    Format('TB        %d      protect from the %s', [Ord(P.TB),
           BoolToStr(P.TB, 'bottom', 'top')]) + LineEnding +
    Format('SEC       %d      units are %s', [Ord(P.SEC),
           BoolToStr(P.SEC, '4 KB sectors', '64 KB blocks')]) + LineEnding +
    Format('CMP       %d      %s', [Ord(P.CMP),
           BoolToStr(P.CMP, 'the protected area is inverted', 'normal')]) + LineEnding +
    Format('SRP1:SRP0 %d:%d    %s', [Ord(P.SRP1), Ord(P.SRP0),
           SRLockText(SRLockState(P))]) + LineEnding +
    Format('WPS       %d      %s', [Ord(P.WPS),
           BoolToStr(P.WPS, 'individual block locks are in use', 'BP bits are in use')]) + LineEnding +
    Format('QE        %d      quad enable', [Ord(P.QE)]) + LineEnding +
    Format('WEL       %d      write enable latch', [Ord(P.WEL)]) + LineEnding +
    Format('BUSY      %d', [Ord(P.Busy)]);

  //บอกไว้ให้ชัดเมื่อรู้ว่ามีของถูกล็อกแต่บอกไม่ได้ว่าตรงไหน
  //เงียบไว้แล้วปล่อยให้คนอ่านสรุปเองว่าไม่มีอะไรล็อกคือความเข้าใจผิดที่แพง
  if not P.RangeKnown then
    Result := Result + LineEnding +
      'note      something is protected but the extent cannot be read ' +
      'from the status register alone on this vendor';
end;

end.
