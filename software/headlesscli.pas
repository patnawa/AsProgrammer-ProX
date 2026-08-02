unit headlesscli;

// LCL-free command line front end.  This module deliberately does not use
// main, Forms, or any widgetset.  It is the first caller of the deep
// operationrunner interface and is suitable for Linux production hosts.

{$mode objfpc}{$H+}

interface

function RunHeadlessCLI: integer;

implementation

uses
  Classes, SysUtils, StrUtils, basehw, ch347proto, ch347usb, spi25noradapter,
  operationmodel, norplanner, norengine, operationrunner, prodevidence,
  prodcrypto, imgcheck, sfdp;

const
  EXIT_OK = 0;
  EXIT_FAILED = 1;
  EXIT_USAGE = 2;
  WRITE_GATE_ENV = 'ASPROGRAMMER_ENABLE_UNVALIDATED_CH347_WRITE';
  WRITE_GATE_VALUE = 'YES_I_HAVE_A_SACRIFICIAL_CHIP';

type
  TAtomicBackupSink = class
  private
    FFileName: string;
  public
    constructor Create(const FileName: string);
    function Commit(const Request: TOperationRequest;
      const Snapshot: TBytes; out ErrorText: string): boolean;
  end;

procedure Say(const S: string = '');
begin
  WriteLn(S);
end;

procedure Usage;
begin
  Say('AsProgrammer ProX headless CLI (no LCL)');
  Say;
  Say('Read-only hardware commands (CH347 over libusb):');
  Say('  AsProgrammerCLI --detect [--speed 2]');
  Say('  AsProgrammerCLI --read dump.bin --size BYTES [--passes 2]');
  Say('  AsProgrammerCLI --smart-preview patch.bin --size BYTES');
  Say('      --address N --page-size N --erase-size N --erase-opcode 20');
  Say;
  Say('Destructive hardware command (gated until live validation):');
  Say('  AsProgrammerCLI --smart-write patch.bin ... --backup original.bin --yes');
  Say('  Also set ' + WRITE_GATE_ENV + '=' + WRITE_GATE_VALUE);
  Say;
  Say('Offline commands:');
  Say('  AsProgrammerCLI --scan image.bin');
  Say('  AsProgrammerCLI --sfdp-decode table.bin');
  Say;
  Say('Options: --hw ch347 --speed 0..7 --native-4byte | --enter-4byte');
  Say('         --replace (allow replacing read output; never backup output)');
end;

function ArgValue(const Name: string): string;
var
  I: integer;
  Prefix: string;
begin
  Result := '';
  Prefix := '--' + Name + '=';
  for I := 1 to ParamCount do
  begin
    if SameText(ParamStr(I), '--' + Name) then
    begin
      // A missing value must not consume the next switch as a filename or
      // number (for example, "--read --size 1024").
      if (I < ParamCount) and
         not AnsiStartsText('--', ParamStr(I + 1)) then
        Result := ParamStr(I + 1);
      Exit;
    end;
    if AnsiStartsText(Prefix, ParamStr(I)) then
    begin
      Result := Copy(ParamStr(I), Length(Prefix) + 1, MaxInt);
      Exit;
    end;
  end;
end;

function HasFlag(const Name: string): boolean;
var
  I: integer;
begin
  Result := False;
  for I := 1 to ParamCount do
    if SameText(ParamStr(I), '--' + Name) then Exit(True);
end;

function HasOption(const Name: string): boolean;
var
  I: integer;
  Prefix: string;
begin
  Result := False;
  Prefix := '--' + Name + '=';
  for I := 1 to ParamCount do
    if SameText(ParamStr(I), '--' + Name) or
       AnsiStartsText(Prefix, ParamStr(I)) then
      Exit(True);
end;

function IsCLIFlag(const Name: string): boolean;
begin
  Result := SameText(Name, 'help') or SameText(Name, 'detect') or
    SameText(Name, 'yes') or SameText(Name, 'native-4byte') or
    SameText(Name, 'enter-4byte') or SameText(Name, 'replace');
end;

function IsCLIValueOption(const Name: string): boolean;
begin
  Result := SameText(Name, 'hw') or SameText(Name, 'speed') or
    SameText(Name, 'read') or SameText(Name, 'size') or
    SameText(Name, 'passes') or SameText(Name, 'smart-preview') or
    SameText(Name, 'smart-write') or SameText(Name, 'address') or
    SameText(Name, 'page-size') or SameText(Name, 'erase-size') or
    SameText(Name, 'erase-opcode') or SameText(Name, 'backup') or
    SameText(Name, 'scan') or SameText(Name, 'sfdp-decode');
end;

function ValidateCommandLine(out ErrorText: string): boolean;
var
  I, EqualsAt: integer;
  Token, Name, InlineValue: string;
  Seen: TStringList;
begin
  Result := False;
  ErrorText := '';
  Seen := TStringList.Create;
  try
    Seen.CaseSensitive := False;
    Seen.Sorted := True;
    Seen.Duplicates := dupError;
    I := 1;
    while I <= ParamCount do
    begin
      Token := ParamStr(I);
      if not AnsiStartsText('--', Token) then
      begin
        ErrorText := 'unexpected positional argument: ' + Token;
        Exit;
      end;
      Token := Copy(Token, 3, MaxInt);
      EqualsAt := Pos('=', Token);
      if EqualsAt > 0 then
      begin
        Name := Copy(Token, 1, EqualsAt - 1);
        InlineValue := Copy(Token, EqualsAt + 1, MaxInt);
      end
      else
      begin
        Name := Token;
        InlineValue := '';
      end;
      if (Name = '') or (not IsCLIFlag(Name) and
         not IsCLIValueOption(Name)) then
      begin
        ErrorText := 'unknown option: --' + Name;
        Exit;
      end;
      if Seen.IndexOf(Name) >= 0 then
      begin
        ErrorText := 'option may be specified only once: --' + Name;
        Exit;
      end;
      Seen.Add(Name);
      if IsCLIFlag(Name) then
      begin
        if EqualsAt > 0 then
        begin
          ErrorText := '--' + Name + ' does not take a value';
          Exit;
        end;
      end
      else if EqualsAt > 0 then
      begin
        if InlineValue = '' then
        begin
          ErrorText := '--' + Name + ' requires a value';
          Exit;
        end;
      end
      else
      begin
        if (I = ParamCount) or AnsiStartsText('--', ParamStr(I + 1)) then
        begin
          ErrorText := '--' + Name + ' requires a value';
          Exit;
        end;
        Inc(I);
      end;
      Inc(I);
    end;
    if (Seen.IndexOf('help') >= 0) and (Seen.Count <> 1) then
    begin
      ErrorText := '--help must be used by itself';
      Exit;
    end;
    Result := True;
  finally
    Seen.Free;
  end;
end;

function ParseUnsigned(const Text, LabelText: string; out Value: QWord;
  out ErrorText: string): boolean;
var
  S: string;
begin
  Result := False;
  Value := 0;
  ErrorText := '';
  S := Trim(Text);
  if S = '' then
  begin
    ErrorText := LabelText + ' is required';
    Exit;
  end;
  if AnsiStartsText('0x', S) then S := '$' + Copy(S, 3, MaxInt);
  if not TryStrToQWord(S, Value) then
  begin
    ErrorText := LabelText + ' must be an unsigned decimal or hexadecimal number';
    Exit;
  end;
  Result := True;
end;

function ParseByteValue(const Text, LabelText: string; out Value: byte;
  out ErrorText: string): boolean;
var
  N: QWord;
  S: string;
begin
  S := Trim(Text);
  // Opcodes are conventionally written as 20/D8 rather than $20/$D8.
  if (S <> '') and (Pos('$', S) <> 1) and not AnsiStartsText('0x', S) then
    S := '$' + S;
  Result := ParseUnsigned(S, LabelText, N, ErrorText) and (N <= 255);
  if Result then Value := byte(N)
  else if (ErrorText = '') or (N > 255) then
    ErrorText := LabelText + ' must fit in one byte';
end;

function LoadBytes(const FileName: string; out Data: TBytes;
  out ErrorText: string): boolean;
var
  Stream: TFileStream;
begin
  Result := False;
  Data := nil;
  ErrorText := '';
  try
    Stream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
    try
      if (QWord(Stream.Size) > QWord(High(SizeInt))) or
         (QWord(Stream.Size) > High(cardinal)) then
      begin
        ErrorText := 'file is too large for this process';
        Exit;
      end;
      SetLength(Data, SizeInt(Stream.Size));
      if (Length(Data) > 0) and
         (Stream.Read(Data[0], Length(Data)) <> Length(Data)) then
      begin
        ErrorText := 'short read from ' + FileName;
        Exit;
      end;
      Result := True;
    finally
      Stream.Free;
    end;
  except
    on E: Exception do ErrorText := E.Message;
  end;
end;

function StableJEDEC(Hardware: TBaseHardware; Speed: integer;
  Passes: cardinal; out ID: TSPI25JEDECID; out ErrorText: string): boolean;
var
  Cmd: array[0..0] of byte;
  Current: TSPI25JEDECID;
  Pass: cardinal;
  Opened, Initialized: boolean;
begin
  Result := False;
  FillChar(ID, SizeOf(ID), 0);
  ErrorText := '';
  Opened := False;
  Initialized := False;
  try
    if not Hardware.DevOpen then
    begin
      ErrorText := Hardware.GetLastError;
      Exit;
    end;
    Opened := True;
    if not Hardware.SPIInit(Speed) then
    begin
      ErrorText := Hardware.GetLastError;
      Exit;
    end;
    Initialized := True;
    Cmd[0] := $9F;
    for Pass := 1 to Passes do
    begin
      FillChar(Current, SizeOf(Current), 0);
      if (Hardware.SPIWrite(0, 1, Cmd) <> 1) or
         (Hardware.SPIRead(1, 3, Current) <> 3) then
      begin
        ErrorText := 'JEDEC read failed: ' + Hardware.GetLastError;
        Exit;
      end;
      if ((Current[0] = $00) and (Current[1] = $00) and
          (Current[2] = $00)) or
         ((Current[0] = $FF) and (Current[1] = $FF) and
          (Current[2] = $FF)) then
      begin
        ErrorText := 'no chip answered the JEDEC ID command';
        Exit;
      end;
      if Pass = 1 then ID := Current
      else if (ID[0] <> Current[0]) or (ID[1] <> Current[1]) or
              (ID[2] <> Current[2]) then
      begin
        ErrorText := Format('unstable JEDEC ID: expected %s, pass %d returned %s',
          [SPI25JEDECIDHex(ID), Pass, SPI25JEDECIDHex(Current)]);
        Exit;
      end;
    end;
    Result := True;
  finally
    if Initialized then Hardware.SPIDeinit;
    if Opened then Hardware.DevClose;
  end;
end;

function ConfigureAddressing(ChipSize: QWord; Native4, Enter4: boolean;
  var Config: TSPI25NORConfig; out ErrorText: string): boolean;
begin
  Result := False;
  if Native4 and Enter4 then
  begin
    ErrorText := '--native-4byte and --enter-4byte are mutually exclusive';
    Exit;
  end;
  if ChipSize <= $1000000 then
  begin
    Config.AddressMode := sam3Byte;
    Config.ReadOpcode := $03;
    Config.ProgramOpcode := $02;
    Config.FourByteStrategy := fbsNotApplicable;
    Exit(True);
  end;
  Config.AddressMode := sam4Byte;
  if Native4 then
  begin
    Config.ReadOpcode := $13;
    Config.ProgramOpcode := $12;
    Config.FourByteStrategy := fbsNativeDedicatedOpcodes;
    Exit(True);
  end;
  if Enter4 then
  begin
    Config.ReadOpcode := $03;
    Config.ProgramOpcode := $02;
    Config.FourByteStrategy := fbsEnterB7;
    Exit(True);
  end;
  ErrorText := 'chips over 16 MiB require --native-4byte or --enter-4byte; ' +
    'the headless CLI never guesses an addressing strategy';
end;

function PlanSummary(const Plan: TNORPlan): string;
begin
  Result := Format('changed=%d erase=%d bytes/%d commands, program=%d ' +
    'bytes/%d pages, verify=%d bytes, preserved=%d bytes',
    [Plan.ChangedBytes, Plan.EraseBytes,
     NORPlanCountKind(Plan, npsErase), Plan.ProgramBytes,
     NORPlanCountKind(Plan, npsProgram), Plan.VerifyBytes,
     Plan.PreservedBytesRewritten]);
end;

constructor TAtomicBackupSink.Create(const FileName: string);
begin
  inherited Create;
  FFileName := FileName;
end;

function TAtomicBackupSink.Commit(const Request: TOperationRequest;
  const Snapshot: TBytes; out ErrorText: string): boolean;
begin
  Result := AtomicWriteDurable(FFileName, Snapshot, False, ErrorText);
end;

function RunScan(const FileName: string): integer;
var
  Data: TBytes;
  Stats: TImgStats;
  Verdict: TImgVerdict;
  Err, Kind: string;
begin
  if not LoadBytes(FileName, Data, Err) then
  begin
    Say('FAILED: ' + Err);
    Exit(EXIT_FAILED);
  end;
  if Length(Data) = 0 then
  begin
    Say('FAILED: image is empty');
    Exit(EXIT_FAILED);
  end;
  Stats := ScanImage(@Data[0], Length(Data));
  Verdict := ImageVerdict(Stats);
  Say(StatsText(Stats));
  Kind := DetectImageKind(@Data[0], Length(Data));
  if Kind <> '' then Say('image: ' + Kind);
  Say(VerdictText(Verdict, Stats));
  if Verdict = ivOK then Result := EXIT_OK else Result := EXIT_FAILED;
end;

function RunSFDPDecode(const FileName: string): integer;
var
  Data: TBytes;
  Info: TSFDPInfo;
  Err: string;
  I: integer;
begin
  if not LoadBytes(FileName, Data, Err) then
  begin
    Say('FAILED: ' + Err);
    Exit(EXIT_FAILED);
  end;
  if (Length(Data) = 0) or
     (not SFDPDetectFromBuffer(@Data[0], Length(Data), Info)) then
  begin
    Say('FAILED: no valid SFDP table');
    Exit(EXIT_FAILED);
  end;
  Say(Format('SFDP %d.%d, capacity=%d, page=%d, addressing=%s',
    [Info.MajorRev, Info.MinorRev, Info.Density, Info.PageSize,
     SFDPAddrBytesStr(Info)]));
  for I := 1 to 4 do
    if Info.EraseTypes[I].Size <> 0 then
      Say(Format('erase %d: %d bytes, opcode %.2x, 4-byte %.2x',
        [I, Info.EraseTypes[I].Size, Info.EraseTypes[I].Opcode,
         Info.EraseTypes[I].Opcode4B]));
  if Info.SectorMapDeclared and not Info.HasSectorMap then
    Say('WARNING: a sector map is declared but could not be resolved');
  Result := EXIT_OK;
end;

function RunHardware: integer;
var
  HW: TCH347USBHardware;
  Adapter: TSPI25NORAdapter;
  Runner: TNOROperationRunner;
  Backup: TAtomicBackupSink;
  Config: TSPI25NORConfig;
  Geometry: TNORGeometry;
  Input: TNOROperationInput;
  Response: TNOROperationResponse;
  ID: TSPI25JEDECID;
  Data: TBytes;
  ErrorText, FileName, BackupName: string;
  ChipSize, Address, PageSize, EraseSize, ReadPasses: QWord;
  EraseOpcode: byte;
  Speed: integer;
  IsDetect, IsRead, IsPreview, IsWrite: boolean;
begin
  Result := EXIT_FAILED;
  IsDetect := HasFlag('detect');
  IsRead := HasOption('read');
  IsPreview := HasOption('smart-preview');
  IsWrite := HasOption('smart-write');
  if Ord(IsDetect) + Ord(IsRead) + Ord(IsPreview) + Ord(IsWrite) <> 1 then
  begin
    Say('FAILED: choose exactly one hardware operation');
    Exit(EXIT_USAGE);
  end;

  if (IsRead and (ArgValue('read') = '')) or
     (IsPreview and (ArgValue('smart-preview') = '')) or
     (IsWrite and (ArgValue('smart-write') = '')) then
  begin
    Say('FAILED: the selected operation requires a filename');
    Exit(EXIT_USAGE);
  end;

  if (ArgValue('hw') <> '') and not SameText(ArgValue('hw'), 'ch347') then
  begin
    Say('FAILED: the LCL-free build currently supports --hw ch347 only');
    Exit(EXIT_USAGE);
  end;
  Speed := 2;
  if ArgValue('speed') <> '' then
  begin
    if not ParseUnsigned(ArgValue('speed'), '--speed', ChipSize,
      ErrorText) or (ChipSize > CH347_DIVISOR_MAX) then
    begin
      Say('FAILED: --speed must be a CH347 divisor from 0 through 7');
      Exit(EXIT_USAGE);
    end;
    Speed := integer(ChipSize);
  end;

  ReadPasses := 2;
  if ArgValue('passes') <> '' then
  begin
    if not ParseUnsigned(ArgValue('passes'), '--passes', ReadPasses,
      ErrorText) or (ReadPasses < 2) or (ReadPasses > 16) then
    begin
      Say('FAILED: --passes must be from 2 through 16; a single read ' +
        'cannot establish a trusted snapshot');
      Exit(EXIT_USAGE);
    end;
  end;

  // Refuse an unvalidated destructive command before opening the programmer
  // or probing the target.  The runner repeats the backup admission check
  // immediately before mutation.
  if IsWrite then
  begin
    BackupName := ArgValue('backup');
    if BackupName = '' then
    begin
      Say('FAILED: --smart-write requires --backup FILE');
      Exit(EXIT_USAGE);
    end;
    if not HasFlag('yes') or
       (GetEnvironmentVariable(WRITE_GATE_ENV) <> WRITE_GATE_VALUE) then
    begin
      Say('REFUSED before device open: headless CH347 writes await live validation.');
      Say('Use --yes and set ' + WRITE_GATE_ENV + '=' + WRITE_GATE_VALUE +
        ' only with a sacrificial chip.');
      Exit(EXIT_FAILED);
    end;
  end;

  // Validate all geometry and filesystem inputs before opening USB. Apart
  // from making usage errors fast, this prevents a wrapped numeric value from
  // being silently admitted after a live probe.
  if not IsDetect then
  begin
    if not ParseUnsigned(ArgValue('size'), '--size', ChipSize,
      ErrorText) or (ChipSize = 0) then
    begin
      if ErrorText = '' then ErrorText := '--size must be greater than zero';
      Say('FAILED: ' + ErrorText);
      Exit(EXIT_USAGE);
    end;
    Address := 0;
    if (ArgValue('address') <> '') and
       not ParseUnsigned(ArgValue('address'), '--address', Address,
         ErrorText) then
    begin
      Say('FAILED: ' + ErrorText);
      Exit(EXIT_USAGE);
    end;
    if Address > ChipSize then
    begin
      Say('FAILED: --address runs past --size');
      Exit(EXIT_USAGE);
    end;
    if IsRead and (Address = ChipSize) then
    begin
      Say('FAILED: read range is empty at the end of the chip');
      Exit(EXIT_USAGE);
    end;

    InitSPI25NORConfig(Config);
    Config.SPISpeed := Speed;
    Config.InitDelayMs := 50;
    Config.WakeDelayMs := 2;
    if not ConfigureAddressing(ChipSize, HasFlag('native-4byte'),
      HasFlag('enter-4byte'), Config, ErrorText) then
    begin
      Say('FAILED: ' + ErrorText);
      Exit(EXIT_USAGE);
    end;
    PageSize := 256;
    EraseSize := 4096;
    EraseOpcode := $20;
    if (IsPreview or IsWrite) and
       ((ArgValue('page-size') = '') or (ArgValue('erase-size') = '') or
        (ArgValue('erase-opcode') = '')) then
    begin
      Say('FAILED: Smart operations require explicit --page-size, ' +
        '--erase-size, and --erase-opcode; geometry is never guessed');
      Exit(EXIT_USAGE);
    end;
    if (ArgValue('page-size') <> '') and
       not ParseUnsigned(ArgValue('page-size'), '--page-size', PageSize,
         ErrorText) then
    begin
      Say('FAILED: ' + ErrorText);
      Exit(EXIT_USAGE);
    end;
    if (ArgValue('erase-size') <> '') and
       not ParseUnsigned(ArgValue('erase-size'), '--erase-size', EraseSize,
         ErrorText) then
    begin
      Say('FAILED: ' + ErrorText);
      Exit(EXIT_USAGE);
    end;
    if (ArgValue('erase-opcode') <> '') and
       not ParseByteValue(ArgValue('erase-opcode'), '--erase-opcode',
         EraseOpcode, ErrorText) then
    begin
      Say('FAILED: ' + ErrorText);
      Exit(EXIT_USAGE);
    end;
    if (PageSize > QWord(High(cardinal))) or
       (EraseSize > QWord(High(cardinal))) then
    begin
      Say('FAILED: --page-size and --erase-size must fit in 32 bits; ' +
        'numeric values are never truncated');
      Exit(EXIT_USAGE);
    end;
    if not BuildUniformNORGeometry(ChipSize, cardinal(PageSize),
      cardinal(EraseSize), EraseOpcode, Geometry, ErrorText) then
    begin
      Say('FAILED: ' + ErrorText);
      Exit(EXIT_USAGE);
    end;

    if IsRead then
    begin
      FileName := ArgValue('read');
      if FileExists(FileName) and not HasFlag('replace') then
      begin
        Say('FAILED: read output already exists; add --replace explicitly');
        Exit(EXIT_USAGE);
      end;
    end
    else
    begin
      if IsPreview then FileName := ArgValue('smart-preview')
      else FileName := ArgValue('smart-write');
      if not LoadBytes(FileName, Data, ErrorText) then
      begin
        Say('FAILED: ' + ErrorText);
        Exit(EXIT_FAILED);
      end;
      if Length(Data) = 0 then
      begin
        Say('FAILED: patch file is empty');
        Exit(EXIT_USAGE);
      end;
      if QWord(Length(Data)) > ChipSize - Address then
      begin
        Say('FAILED: patch runs past the declared chip size');
        Exit(EXIT_USAGE);
      end;
      if IsWrite then
      begin
        if FileExists(BackupName) then
        begin
          Say('FAILED: backup output already exists and is never replaced');
          Exit(EXIT_USAGE);
        end;
        if not DirectoryExists(ExtractFileDir(ExpandFileName(BackupName))) then
        begin
          Say('FAILED: backup output directory does not exist');
          Exit(EXIT_USAGE);
        end;
      end;
    end;
  end;

  HW := TCH347USBHardware.Create;
  try
    if not StableJEDEC(HW, Speed, 8, ID, ErrorText) then
    begin
      Say('FAILED: ' + ErrorText);
      Exit;
    end;
    Say('stable JEDEC ID: ' + SPI25JEDECIDHex(ID));
    if IsDetect then Exit(EXIT_OK);
    RequireSPI25Identity(Config, ID, 8);

    Adapter := TSPI25NORAdapter.Create(HW, Config);
    Backup := nil;
    Runner := nil;
    try
      if IsWrite then
      begin
        Backup := TAtomicBackupSink.Create(BackupName);
        Runner := TNOROperationRunner.Create(Adapter, nil, nil,
          @Backup.Commit)
      end
      else
        Runner := TNOROperationRunner.Create(Adapter);

      InitNOROperationInput(Input);
      Input.Geometry := Geometry;
      Input.ReadPasses := cardinal(ReadPasses);
      Input.Operation.OperationID := FormatDateTime('yyyymmddhhnnsszzz', Now);
      Input.Operation.Chip.Name := 'JEDEC-' + SPI25JEDECIDHex(ID);
      Input.Operation.Chip.JedecID := SPI25JEDECIDHex(ID);
      Input.Operation.Chip.Capacity := ChipSize;
      Input.Operation.Policy.RequireEvidenceCommit := False;

      if IsRead then
      begin
        Input.Mode := nomRead;
        Input.Operation.Kind := okRead;
        Input.Operation.Target.Address := Address;
        Input.Operation.Target.Length := ChipSize - Address;
      end
      else
      begin
        Input.Patch := Data;
        Input.Operation.Kind := okProgram;
        Input.Operation.Target.Address := Address;
        Input.Operation.Target.Length := Length(Data);
        Input.Operation.Policy.RequireTrustedBackup := IsWrite;
        if IsWrite then Input.Mode := nomSmartWrite
        else Input.Mode := nomSmartPreview;
      end;

      Response := Runner.Execute(Input);
      if Response.Outcome.Status <> osSucceeded then
      begin
        Say('FAILED [' + OperationErrorName(Response.Outcome.ErrorCode) +
          ']: ' + Response.Outcome.ErrorText);
        Exit(EXIT_FAILED);
      end;
      if Response.HasPlan then Say('plan: ' + PlanSummary(Response.Plan));
      if IsRead then
      begin
        if not AtomicWriteDurable(FileName, Response.Data, HasFlag('replace'),
          ErrorText) then
        begin
          Say('FAILED saving read: ' + ErrorText);
          Exit(EXIT_FAILED);
        end;
        Say(Format('read %d trusted bytes to %s',
          [Length(Response.Data), FileName]));
        if Length(Response.Data) > 0 then
          Say(VerdictText(ImageVerdict(ScanImage(@Response.Data[0],
            Length(Response.Data))), ScanImage(@Response.Data[0],
            Length(Response.Data))));
      end
      else if IsPreview then
        Say('preview complete; no write-enable or mutation command was sent')
      else
        Say('smart write and full affected-block verification completed');
      Result := EXIT_OK;
    finally
      Runner.Free;
      Backup.Free;
      Adapter.Free;
    end;
  finally
    HW.Free;
  end;
end;

function RunHeadlessCLI: integer;
var
  ScanName, SFDPName, ArgumentError: string;
  ActionCount: integer;
begin
  if ParamCount = 0 then
  begin
    Usage;
    Exit(EXIT_OK);
  end;
  if not ValidateCommandLine(ArgumentError) then
  begin
    Say('FAILED: ' + ArgumentError);
    Exit(EXIT_USAGE);
  end;
  if HasFlag('help') then
  begin
    Usage;
    Exit(EXIT_OK);
  end;
  ActionCount := Ord(HasOption('scan')) + Ord(HasOption('sfdp-decode')) +
    Ord(HasFlag('detect')) + Ord(HasOption('read')) +
    Ord(HasOption('smart-preview')) + Ord(HasOption('smart-write'));
  if ActionCount <> 1 then
  begin
    Say('FAILED: choose exactly one operation');
    Usage;
    Exit(EXIT_USAGE);
  end;
  ScanName := ArgValue('scan');
  if HasOption('scan') then
  begin
    if ScanName = '' then
    begin
      Say('FAILED: --scan requires a filename');
      Exit(EXIT_USAGE);
    end;
    Exit(RunScan(ScanName));
  end;
  SFDPName := ArgValue('sfdp-decode');
  if HasOption('sfdp-decode') then
  begin
    if SFDPName = '' then
    begin
      Say('FAILED: --sfdp-decode requires a filename');
      Exit(EXIT_USAGE);
    end;
    Exit(RunSFDPDecode(SFDPName));
  end;
  if HasFlag('detect') or HasOption('read') or
     HasOption('smart-preview') or HasOption('smart-write') then
    Exit(RunHardware);
  Say('FAILED: no operation selected');
  Usage;
  Result := EXIT_USAGE;
end;

end.
