program sfdpprofile_tests;

// Describing a chip the catalogue has never heard of, from what the chip says
// about itself.
//
// Two groups of assertions carry the weight.
//
// The first is about writing. Every way a declared geometry can be incoherent
// -- an ambiguous sector map, a capacity that is not a whole number of erase
// units, a part above 16 MiB with no four-byte erase opcode -- has to leave
// the part readable and refuse the write. Reading is the operation that
// cannot destroy anything and gets somebody's data off an unknown part, so it
// must be the last thing surrendered.
//
// The second is about voltage, and it is the reason this feature is safe to
// have at all. SFDP contains no supply-voltage field, so a provisional
// profile must not narrow that question by any route -- including the
// accidental one, where a name this unit invented happens to match a pattern
// the name-based voltage inference keys on.

{$mode objfpc}{$H+}

uses
  SysUtils, sfdp, sfdpprofile;

var
  Failures, Assertions: integer;

procedure Check(const Name: string; Condition: boolean);
begin
  Inc(Assertions);
  if not Condition then
  begin
    Inc(Failures);
    WriteLn('FAIL: ', Name);
  end;
end;

// A plain uniform part: 8 MiB, 256-byte pages, 4K/32K/64K erase, three-byte
// addressing. What a W25Q64 style table decodes to.
function UniformInfo: TSFDPInfo;
begin
  Result := Default(TSFDPInfo);
  Result.Valid := True;
  Result.MajorRev := 1;
  Result.MinorRev := 6;
  Result.Density := 8 * 1024 * 1024;
  Result.PageSize := 256;
  Result.AddrBytes := 3;
  Result.Supports4KErase := True;
  Result.Erase4KOpcode := $20;
  Result.EraseTypes[1].Size := 4096;    Result.EraseTypes[1].Opcode := $20;
  Result.EraseTypes[2].Size := 32768;   Result.EraseTypes[2].Opcode := $52;
  Result.EraseTypes[3].Size := 65536;   Result.EraseTypes[3].Opcode := $D8;
end;

// A 32 MiB part in four-byte mode with a dedicated instruction set and the
// four-byte erase opcodes named, as a Micron MT25Q reports itself.
function BigInfo: TSFDPInfo;
begin
  Result := Default(TSFDPInfo);
  Result.Valid := True;
  Result.Density := 32 * 1024 * 1024;
  Result.PageSize := 256;
  Result.AddrBytes := 4;
  Result.HasDword16 := True;
  Result.Entry4B.DedicatedSet := True;
  Result.EraseTypes[1].Size := 4096;  Result.EraseTypes[1].Opcode := $20;
  Result.EraseTypes[1].Opcode4B := $21;
  Result.EraseTypes[3].Size := 65536; Result.EraseTypes[3].Opcode := $D8;
  Result.EraseTypes[3].Opcode4B := $DC;
  Result.Has4BAIT := True;
end;

function LinesContain(const Lines: TProfileLines; const Needle: string): boolean;
var
  i: integer;
begin
  for i := 0 to High(Lines) do
    if Pos(Needle, Lines[i]) > 0 then Exit(True);
  Result := False;
end;

// ------------------------------------------------------ the ordinary case

procedure TestAUniformPartIsFullyDescribed;
var
  P: TProvisionalProfile;
  Err: string;
begin
  WriteLn('A uniform part with a complete table is usable for read and write');

  Check('a profile is built',
        BuildProvisionalProfile('EF4017', True, UniformInfo, P, Err));
  Check('it is valid', P.Valid);
  Check('and offers writing', P.Capability = pvReadWrite);
  Check('the capacity comes from the density', P.CapacityBytes = 8 * 1024 * 1024);
  Check('the page size comes from the table', P.PageSize = 256);
  Check('the erase unit is the smallest declared', P.EraseSize = 4096);
  Check('with its opcode', P.EraseOpcode = $20);
  Check('three byte addressing', P.AddressBytes = 3);
  Check('and no sector map', not P.HasSectorMap);

  Check('the name identifies the part', P.Name = 'SFDP-EF4017-8M');
  Check('the JEDEC ID is kept exactly', P.JedecID = 'EF4017');
end;

procedure TestABigPartInFourByteMode;
var
  P: TProvisionalProfile;
  Err: string;
begin
  WriteLn('A 32 MiB part that named its four-byte opcodes is writable');

  Check('a profile is built',
        BuildProvisionalProfile('20BB19', True, BigInfo, P, Err));
  Check('it offers writing', P.Capability = pvReadWrite);
  Check('four byte addressing', P.AddressBytes = 4);
  Check('the size is in the name', P.Name = 'SFDP-20BB19-32M');
end;

// ----------------------------------------------- what stops a write, only

procedure TestAnAmbiguousSectorMapIsReadOnly;
var
  Info: TSFDPInfo;
  P: TProvisionalProfile;
  Err: string;
begin
  WriteLn('A chip that declares a sector map it cannot resolve is read-only');

  //A boot-block part where 4K sectors sit next to 64K blocks. Guessing a
  //uniform 4K geometry erases the wrong physical blocks and reports success,
  //which is the single most expensive mistake this program could make.
  Info := UniformInfo;
  Info.SectorMapDeclared := True;
  Info.HasSectorMap := False;

  Check('a profile is still built',
        BuildProvisionalProfile('EF4017', True, Info, P, Err));
  //The part is still perfectly readable, and reading is how somebody gets
  //their data off it before deciding anything else.
  Check('reading is still offered', P.Capability = pvReadOnly);
  Check('and the reason names the map', Pos('ambiguous', P.Note) > 0);
  Check('no erase unit is offered', P.EraseSize = 0);
end;

procedure TestAResolvedSectorMapIsWritableButNotUniform;
var
  Info: TSFDPInfo;
  P: TProvisionalProfile;
  Err: string;
begin
  WriteLn('A resolved sector map is writable, and says the layout is not uniform');
  Info := UniformInfo;
  Info.SectorMapDeclared := True;
  Info.HasSectorMap := True;
  Info.RegionCount := 3;

  Check('a profile is built',
        BuildProvisionalProfile('EF4017', True, Info, P, Err));
  Check('writing is offered', P.Capability = pvReadWrite);
  Check('the map is flagged', P.HasSectorMap);
  //A caller that took EraseSize as a uniform geometry here would erase a
  //boot-block part on the wrong boundaries, so the note says where the real
  //block list comes from.
  Check('and the note says the block list comes from the map',
        Pos('sector map', P.Note) > 0);
  Check('the report does not offer one erase size',
        not LinesContain(ProvisionalProfileLines(P), 'opcode'));
end;

procedure TestIncoherentGeometryIsReadOnly;
var
  Info: TSFDPInfo;
  P: TProvisionalProfile;
  Err: string;
begin
  WriteLn('Every incoherent geometry falls back to read-only, never to a guess');

  //No erase type at all.
  Info := UniformInfo;
  Info.EraseTypes[1].Size := 0; Info.EraseTypes[2].Size := 0;
  Info.EraseTypes[3].Size := 0; Info.Supports4KErase := False;
  Info.Erase4KOpcode := 0;
  Check('no erase type declared',
        BuildProvisionalProfile('EF4017', True, Info, P, Err) and
        (P.Capability = pvReadOnly));
  Check('and it says so', Pos('no erase type', P.Note) > 0);

  //An erase opcode of FF is what a floating bus returns, not a command.
  Info := UniformInfo;
  Info.EraseTypes[1].Opcode := $FF;
  Check('an FF erase opcode',
        BuildProvisionalProfile('EF4017', True, Info, P, Err) and
        (P.Capability = pvReadOnly));

  //A capacity that is not a whole number of erase units leaves a tail that
  //cannot be erased, or an erase that runs off the end.
  Info := UniformInfo;
  Info.Density := 8 * 1024 * 1024 + 4095;
  Check('a capacity that is not a whole number of erase units',
        BuildProvisionalProfile('EF4017', True, Info, P, Err) and
        (P.Capability = pvReadOnly));
  Check('and it says so', Pos('whole number of erase units', P.Note) > 0);

  //A page larger than the erase unit cannot be programmed within one.
  Info := UniformInfo;
  Info.PageSize := 8192;
  Info.EraseTypes[1].Size := 4096;
  Check('a page larger than the erase unit',
        BuildProvisionalProfile('EF4017', True, Info, P, Err) and
        (P.Capability = pvReadOnly));

  //A page size that is not a power of two is a misparse, not a part.
  Info := UniformInfo;
  Info.PageSize := 300;
  Check('a page size that is not a power of two',
        BuildProvisionalProfile('EF4017', True, Info, P, Err) and
        (P.Capability = pvReadOnly));
end;

procedure TestABigPartWithNoFourByteEraseOpcode;
var
  Info: TSFDPInfo;
  P: TProvisionalProfile;
  Err: string;
begin
  WriteLn('Above 16 MiB, an unnamed four-byte erase opcode is read-only');

  //This one is worth spelling out. Substituting the three-byte opcode on a
  //part above 16 MiB does not fail -- it erases at a wrapped address,
  //somewhere in the lower 16 MiB, and reports success.
  Info := BigInfo;
  Info.EraseTypes[1].Opcode4B := 0;
  Info.EraseTypes[3].Opcode4B := 0;

  Check('a profile is built',
        BuildProvisionalProfile('20BB19', True, Info, P, Err));
  Check('but writing is refused', P.Capability = pvReadOnly);
  Check('and the reason names the size', Pos('16 MiB', P.Note) > 0);
  //The read still works, because reading uses the four-byte read opcode,
  //which this part did declare.
  Check('reading is still offered', P.Capability >= pvReadOnly);
end;

procedure TestAnImpossibleCombinationIsRefusedOutright;
var
  Info: TSFDPInfo;
  P: TProvisionalProfile;
  Err: string;
begin
  WriteLn('A part that describes something impossible gets no profile at all');

  //32 MiB reachable only by a three-byte address. One of the two fields is
  //wrong and there is no basis for preferring either, so neither reading nor
  //writing is offered.
  Info := BigInfo;
  Info.AddrBytes := 3;

  Check('no profile is built',
        not BuildProvisionalProfile('20BB19', True, Info, P, Err));
  Check('it is marked invalid', not P.Valid);
  Check('nothing is usable', P.Capability = pvNone);
  Check('and the error names the contradiction',
        Pos('three-byte addressing', Err) > 0);
end;

// ---------------------------------------------------------- the refusals

procedure TestNothingToBuildFrom;
var
  P: TProvisionalProfile;
  Err: string;
  Info: TSFDPInfo;
begin
  WriteLn('Without a chip and a table there is no profile');

  Check('no SFDP, no profile',
        not BuildProvisionalProfile('EF4017', False, UniformInfo, P, Err));
  Check('and it says why', Pos('no readable SFDP', Err) > 0);

  Info := Default(TSFDPInfo);
  Info.Valid := True;
  Check('a table with no density is not a description',
        not BuildProvisionalProfile('EF4017', True, Info, P, Err));

  //An all-FF or all-00 identity is a floating bus. Giving it a name and a
  //geometry would be describing an empty socket as a part.
  Check('an all-FF identity is a floating bus',
        not BuildProvisionalProfile('FFFFFF', True, UniformInfo, P, Err));
  Check('an all-00 identity likewise',
        not BuildProvisionalProfile('000000', True, UniformInfo, P, Err));
  Check('and a short one is not an identity',
        not BuildProvisionalProfile('EF', True, UniformInfo, P, Err));
  Check('nor is a non-hex one',
        not BuildProvisionalProfile('EFZZ17', True, UniformInfo, P, Err));
end;

// ------------------------------------------------------------- voltage

procedure TestNoPathHereConcludesAVoltage;
var
  P: TProvisionalProfile;
  Err: string;
  Lines: TProfileLines;
  Upper: string;
begin
  WriteLn('A provisional profile narrows the voltage question by nothing');

  Check('a profile is built',
        BuildProvisionalProfile('EF6017', True, UniformInfo, P, Err));
  //SFDP has no supply-voltage field anywhere: not in the basic table, not in
  //DWORD-16. So the profile must say it does not know, rather than leaving a
  //zeroed field that a caller reads as a range.
  Check('the profile does not claim to know the voltage', not P.VoltageKnown);

  Lines := ProvisionalProfileLines(P);
  Check('and the report says so out loud',
        LinesContain(Lines, 'not stated by SFDP'));
  Check('and reminds the reader the usual rules still apply',
        LinesContain(Lines, 'still be asked about'));
end;

procedure TestTheSynthesisedNameCannotTripVoltageInference;
var
  P: TProvisionalProfile;
  Err: string;
  Info: TSFDPInfo;
begin
  WriteLn('A name this program invented is never evidence about a rail');

  //The four-tier ladder infers 1.8 V from a '_1.8V' suffix (tier 2) and from
  //model prefixes such as MX25U (tier 3). A synthesised name that matched
  //either would be the program inferring a supply voltage from a string it
  //made up itself -- and tiers 2 and 3 can only conclude 1.8 V, so the
  //failure would be silent rather than loud.
  Info := UniformInfo;
  Check('a profile is built',
        BuildProvisionalProfile('C22539', True, Info, P, Err));

  Check('the name is marked as synthesised', Copy(P.Name, 1, 5) = 'SFDP-');
  Check('it carries no voltage suffix',
        (Pos('1.8V', P.Name) = 0) and (Pos('3.3V', P.Name) = 0) and
        (Pos('_', P.Name) = 0));
  //Hex digits and the fixed prefix cannot form a manufacturer model prefix,
  //but assert it rather than reasoning about it.
  Check('and no model prefix the voltage rules key on',
        (Pos('MX25U', UpperCase(P.Name)) = 0) and
        (Pos('MX66U', UpperCase(P.Name)) = 0));

  //Tier 4 works from the JEDEC ID, not the name, so it is unaffected -- and
  //that is the tier that catches the dangerous parts. EF6017 is a W25Q64FW:
  //1.8 V, with a name that says nothing.
  Check('the real JEDEC ID is preserved for the rules that use it',
        P.JedecID = 'C22539');
end;

procedure TestNamesStayValidIdentifiers;
var
  P: TProvisionalProfile;
  Err: string;
  i: integer;
  Ok: boolean;
begin
  WriteLn('A synthesised name is usable everywhere a chip name is');

  Check('a profile is built',
        BuildProvisionalProfile('EF4017', True, UniformInfo, P, Err));

  //The charset chipprofile.ValidName and prodjob.ValidIdentifier accept. A
  //name that a production manifest would reject is one that works right up
  //until somebody uses it for what names are for.
  Ok := (Length(P.Name) >= 1) and (Length(P.Name) <= 96);
  for i := 1 to Length(P.Name) do
    if not (P.Name[i] in ['A'..'Z', 'a'..'z', '0'..'9', '.', '_', '-', '+']) then
      Ok := False;
  Check('the name is a portable identifier', Ok);
end;

procedure TestTheReportLeadsWithWhatItIs;
var
  P: TProvisionalProfile;
  Err: string;
  Lines: TProfileLines;
begin
  WriteLn('The report says where the description came from, first');

  Check('a profile is built',
        BuildProvisionalProfile('EF4017', True, UniformInfo, P, Err));
  Lines := ProvisionalProfileLines(P);

  //An operator who does not notice that this part described itself, rather
  //than being looked up, has been misled -- and no amount of correct detail
  //below makes up for that.
  Check('the first line says it is provisional',
        Pos('Provisional', Lines[0]) > 0);
  Check('and that it did not come from the catalogue',
        Pos('not the chip catalogue', Lines[0] + Lines[1]) > 0);
  //A counterfeit reports whatever SFDP its cloner wrote, so a claimed
  //capacity is a claim.
  Check('the capacity is labelled as claimed',
        LinesContain(Lines, 'claimed by the chip, not verified'));

  //And a refusal explains itself rather than producing an empty report.
  Check('no profile at all still produces a reason',
        not BuildProvisionalProfile('FFFFFF', True, UniformInfo, P, Err));
  Lines := ProvisionalProfileLines(P);
  Check('which the report carries', Pos('No provisional profile', Lines[0]) > 0);
end;

begin
  TestAUniformPartIsFullyDescribed;
  TestABigPartInFourByteMode;
  TestAnAmbiguousSectorMapIsReadOnly;
  TestAResolvedSectorMapIsWritableButNotUniform;
  TestIncoherentGeometryIsReadOnly;
  TestABigPartWithNoFourByteEraseOpcode;
  TestAnImpossibleCombinationIsRefusedOutright;
  TestNothingToBuildFrom;
  TestNoPathHereConcludesAVoltage;
  TestTheSynthesisedNameCannotTripVoltageInference;
  TestNamesStayValidIdentifiers;
  TestTheReportLeadsWithWhatItIs;
  WriteLn(Assertions, ' assertions, ', Failures, ' failures');
  if Failures <> 0 then Halt(1);
  WriteLn('ALL PASSED');
end.
