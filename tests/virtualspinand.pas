unit virtualspinand;

// An SPI NAND that lives in memory, for testing the engine without silicon.
//
// It models the properties that make NAND dangerous rather than the wire
// protocol: factory bad-block markers in the spare area, program that can
// only clear bits (a page programmed twice without an erase ANDs, exactly
// like the real cell array), P_FAIL/E_FAIL completion flags, corrected and
// uncorrectable ECC verdicts injectable per page, block protection that
// silently ignores program and erase (which is what real parts do), and a
// fail-the-Nth-device-call switch for the fault matrix tests.

{$mode objfpc}{$H+}

interface

uses
  SysUtils, nandmodel, nandengine;

type
  TVirtualSPINAND = class(TNANDDevice)
  private
    FGeometry: TNANDGeometry;
    FMain: array of TBytes;    //per page: main area
    FSpare: array of TBytes;   //per page: spare area
    FErased: array of boolean; //per page: erased since last program?
    FECCOn: boolean;
    FLocked: boolean;
    FCallCount: integer;

    function PageIndex(Block, Page: cardinal): SizeInt;
    function CallGate(out IO: TNANDIOResult): boolean;
  public
    //Inject a failure into the Nth device call (1-based); 0 = never.
    FailAtCall: integer;
    //Pages with injected ECC verdicts, as PageIndex values.
    CorrectedAt: array of SizeInt;
    UncorrectableAt: array of SizeInt;
    //Completion-flag injection.
    FailProgramBlock, FailProgramPage: integer;  //-1 = never
    FailEraseBlock: integer;                     //-1 = never
    //Counters the tests assert on.
    EraseCalls, ProgramCalls, ReadCalls: integer;
    ECCOffDuringScan: boolean; //latched whenever a spare read sees ECC off

    constructor Create(const Geometry: TNANDGeometry);
    procedure MarkFactoryBad(Block: cardinal);
    procedure InjectCorrected(Block, Page: cardinal);
    procedure InjectUncorrectable(Block, Page: cardinal);
    function MainByte(Block, Page, Offset: cardinal): byte;
    property Locked: boolean read FLocked write FLocked;
    property ECCOn: boolean read FECCOn write FECCOn;
    //Every device call ever made, feature calls included; the fault matrix
    //aims FailAtCall relative to this.
    property CallCount: integer read FCallCount;

    function ReadPage(Block, Page, Offset, Len: cardinal; out Data: TBytes;
      out ECC: TNANDECCStatus): TNANDIOResult; override;
    function ProgramPage(Block, Page, Offset: cardinal; const Data: TBytes;
      out ProgramFailed: boolean): TNANDIOResult; override;
    function EraseBlock(Block: cardinal; out EraseFailed: boolean):
      TNANDIOResult; override;
    function SetECC(Enabled: boolean): TNANDIOResult; override;
    function GetECC(out Enabled: boolean): TNANDIOResult; override;
    function UnlockAll: TNANDIOResult; override;
  end;

implementation

constructor TVirtualSPINAND.Create(const Geometry: TNANDGeometry);
var
  Pages: SizeInt;
  i: SizeInt;
begin
  inherited Create;
  FGeometry := Geometry;
  Pages := SizeInt(Geometry.BlockCount) * SizeInt(Geometry.PagesPerBlock);
  SetLength(FMain, Pages);
  SetLength(FSpare, Pages);
  SetLength(FErased, Pages);
  for i := 0 to Pages - 1 do
  begin
    SetLength(FMain[i], Geometry.PageSize);
    FillByte(FMain[i][0], Geometry.PageSize, $FF);
    SetLength(FSpare[i], Geometry.SpareSize);
    FillByte(FSpare[i][0], Geometry.SpareSize, $FF);
    FErased[i] := True;
  end;
  FECCOn := True;      //on-die ECC ships enabled on real parts
  FLocked := True;     //and so does block protection
  FailAtCall := 0;
  FailProgramBlock := -1;
  FailProgramPage := -1;
  FailEraseBlock := -1;
end;

function TVirtualSPINAND.PageIndex(Block, Page: cardinal): SizeInt;
begin
  Result := SizeInt(Block) * SizeInt(FGeometry.PagesPerBlock) + SizeInt(Page);
end;

//Every public device call passes here so the fault matrix can kill any one
//of them. Returns True when this call must fail.
function TVirtualSPINAND.CallGate(out IO: TNANDIOResult): boolean;
begin
  Inc(FCallCount);
  Result := (FailAtCall > 0) and (FCallCount = FailAtCall);
  if Result then
    IO := NANDIOFailure(nnioTransport, 'injected transport failure')
  else
    IO := NANDIOSuccess;
end;

procedure TVirtualSPINAND.MarkFactoryBad(Block: cardinal);
begin
  FSpare[PageIndex(Block, 0)][0] := $00;
end;

procedure TVirtualSPINAND.InjectCorrected(Block, Page: cardinal);
begin
  SetLength(CorrectedAt, Length(CorrectedAt) + 1);
  CorrectedAt[High(CorrectedAt)] := PageIndex(Block, Page);
end;

procedure TVirtualSPINAND.InjectUncorrectable(Block, Page: cardinal);
begin
  SetLength(UncorrectableAt, Length(UncorrectableAt) + 1);
  UncorrectableAt[High(UncorrectableAt)] := PageIndex(Block, Page);
end;

function TVirtualSPINAND.MainByte(Block, Page, Offset: cardinal): byte;
begin
  Result := FMain[PageIndex(Block, Page)][Offset];
end;

function TVirtualSPINAND.ReadPage(Block, Page, Offset, Len: cardinal;
  out Data: TBytes; out ECC: TNANDECCStatus): TNANDIOResult;
var
  Idx, k: SizeInt;
  i: cardinal;
  Col: cardinal;
begin
  Data := nil;
  ECC := neccGood;
  Inc(ReadCalls);
  if CallGate(Result) then Exit;

  if (Block >= FGeometry.BlockCount) or
     (Page >= FGeometry.PagesPerBlock) or
     (Offset + Len > FGeometry.PageSize + FGeometry.SpareSize) then
    Exit(NANDIOFailure(nnioRejected, 'address outside the chip'));

  Idx := PageIndex(Block, Page);

  //อ่าน marker ตอน ECC ปิดคือพฤติกรรมที่ engine สัญญาไว้ จดไว้ให้เทสต์ดู
  if (Offset >= FGeometry.PageSize) and (not FECCOn) then
    ECCOffDuringScan := True;

  SetLength(Data, Len);
  for i := 0 to Len - 1 do
  begin
    Col := Offset + i;
    if Col < FGeometry.PageSize then
      Data[i] := FMain[Idx][Col]
    else
      Data[i] := FSpare[Idx][Col - FGeometry.PageSize];
  end;

  if FECCOn then
  begin
    for k := 0 to High(UncorrectableAt) do
      if UncorrectableAt[k] = Idx then
      begin
        ECC := neccUncorrectable;
        Exit(NANDIOSuccess);
      end;
    for k := 0 to High(CorrectedAt) do
      if CorrectedAt[k] = Idx then
      begin
        ECC := neccCorrected;
        Exit(NANDIOSuccess);
      end;
  end;

  Result := NANDIOSuccess;
end;

function TVirtualSPINAND.ProgramPage(Block, Page, Offset: cardinal;
  const Data: TBytes; out ProgramFailed: boolean): TNANDIOResult;
var
  Idx: SizeInt;
  i: cardinal;
begin
  ProgramFailed := False;
  Inc(ProgramCalls);
  if CallGate(Result) then Exit;

  if (Block >= FGeometry.BlockCount) or
     (Page >= FGeometry.PagesPerBlock) or
     (Offset + cardinal(Length(Data)) > FGeometry.PageSize +
      FGeometry.SpareSize) then
    Exit(NANDIOFailure(nnioRejected, 'address outside the chip'));

  //ชิปที่ยังล็อกอยู่รับคำสั่งแล้วไม่ทำอะไรเลย ไม่ตั้ง P_FAIL ด้วย นี่คือ
  //พฤติกรรมจริงที่ทำให้ engine ต้องปลดล็อกและอ่านทะเบียนกลับก่อนเสมอ
  if FLocked then Exit(NANDIOSuccess);

  if (FailProgramBlock >= 0) and (cardinal(FailProgramBlock) = Block) and
     (cardinal(FailProgramPage) = Page) then
  begin
    ProgramFailed := True;
    Exit(NANDIOSuccess);
  end;

  Idx := PageIndex(Block, Page);
  //เซลล์จริงโปรแกรมได้แต่ 1 -> 0 เพจที่ไม่ได้ลบก่อนจะกลายเป็น AND ของ
  //สองภาพ ไม่ใช่ภาพใหม่ ตัวจำลองทำแบบเดียวกันเพื่อให้บั๊กชนิดนั้นมองเห็น
  if Length(Data) > 0 then
    for i := 0 to cardinal(High(Data)) do
    begin
      if Offset + i < FGeometry.PageSize then
        FMain[Idx][Offset + i] := FMain[Idx][Offset + i] and Data[i]
      else
        FSpare[Idx][Offset + i - FGeometry.PageSize] :=
          FSpare[Idx][Offset + i - FGeometry.PageSize] and Data[i];
    end;
  FErased[Idx] := False;
  Result := NANDIOSuccess;
end;

function TVirtualSPINAND.EraseBlock(Block: cardinal;
  out EraseFailed: boolean): TNANDIOResult;
var
  Page: cardinal;
  Idx: SizeInt;
begin
  EraseFailed := False;
  Inc(EraseCalls);
  if CallGate(Result) then Exit;

  if Block >= FGeometry.BlockCount then
    Exit(NANDIOFailure(nnioRejected, 'block outside the chip'));

  if FLocked then Exit(NANDIOSuccess);  //เมินเงียบ ๆ เหมือนชิปจริง

  if (FailEraseBlock >= 0) and (cardinal(FailEraseBlock) = Block) then
  begin
    EraseFailed := True;
    Exit(NANDIOSuccess);
  end;

  for Page := 0 to FGeometry.PagesPerBlock - 1 do
  begin
    Idx := PageIndex(Block, Page);
    FillByte(FMain[Idx][0], FGeometry.PageSize, $FF);
    FillByte(FSpare[Idx][0], FGeometry.SpareSize, $FF);
    FErased[Idx] := True;
  end;
  Result := NANDIOSuccess;
end;

function TVirtualSPINAND.SetECC(Enabled: boolean): TNANDIOResult;
begin
  if CallGate(Result) then Exit;
  FECCOn := Enabled;
end;

function TVirtualSPINAND.GetECC(out Enabled: boolean): TNANDIOResult;
begin
  Enabled := FECCOn;
  if CallGate(Result) then Exit;
end;

function TVirtualSPINAND.UnlockAll: TNANDIOResult;
begin
  if CallGate(Result) then Exit;
  FLocked := False;
end;

end.
