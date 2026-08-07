unit sfdpprofile;

// A chip that is not in the catalogue, described by what it says about itself.
//
// The catalogue holds 658 SPI NOR entries. The market holds thousands, and a
// part that is missing from the table is a dead end today: the JEDEC ID comes
// back, the vendor byte decodes, and then there is nowhere to go. Meanwhile
// the chip has been carrying a full description of its own geometry the whole
// time, in the SFDP parameter tables this program already parses completely.
//
// So this unit builds a profile from those tables. It is deliberately called
// *provisional* everywhere, because it differs from a catalogue entry in two
// ways that matter and must never be smoothed over:
//
//   - It is the chip's own claim. A counterfeit part reports the SFDP its
//     cloner wrote, and a 2 MiB die in a package marked 16 MiB will describe
//     itself as 16 MiB quite happily. The catalogue is somebody's reading of
//     a datasheet; this is the part talking about itself. Neither is proof,
//     but they fail differently, and the difference is worth stating.
//   - It cannot answer the voltage question. SFDP has no supply-voltage
//     field -- not in the basic table, not in DWORD-16, not anywhere. So a
//     provisional profile leaves the voltage unresolved on purpose, and the
//     four-tier ladder runs exactly as it does for a catalogue part: the
//     JEDEC ID prefixes in tier 4 still fire, and anything they do not cover
//     still stops and asks.
//
// That second point is the one that makes this safe to add. Broadening chip
// coverage is only worth doing if it does not broaden the set of parts whose
// voltage gets guessed at, and it does not: no path here concludes a voltage,
// and the synthesised name is built so that it cannot accidentally match the
// name-based inference rules either.
//
// What it will and will not offer:
//
//   - Reading needs a capacity and an address width. Almost every SFDP part
//     supplies both.
//   - Writing needs, in addition, a page size, an erase unit that tiles the
//     part, and an erase opcode. A chip that declares a sector map it cannot
//     resolve gets read-only, because guessing a uniform geometry on a
//     boot-block part erases the wrong physical blocks.
//
// No hardware access and no LCL unit is used here.

{$mode objfpc}{$H+}

interface

uses
  SysUtils, sfdp;

type
  TProfileLines = array of string;

  // How far a provisional profile may be trusted. Ordered, so a caller can
  // compare.
  TProvisionalCapability = (
    pvNone,       // nothing usable was established
    pvReadOnly,   // capacity and addressing are known; erase geometry is not
    pvReadWrite   // a complete, self-consistent geometry
  );

  TProvisionalProfile = record
    Valid: boolean;
    Capability: TProvisionalCapability;

    // A catalogue-safe identifier synthesised from the JEDEC ID and the
    // density, so the part has something to be called in a log, a backup
    // manifest and a session report. See SynthesiseName for why it is shaped
    // the way it is.
    Name: string;
    JedecID: string;              // exactly as read, uppercase hex

    CapacityBytes: QWord;
    PageSize: cardinal;
    EraseSize: cardinal;          // the smallest erase unit, when uniform
    EraseOpcode: byte;
    AddressBytes: byte;           // 3, 4, or 34 for "either"

    // True when SFDP declared a sector map, meaning the part is not uniform
    // and the erase geometry has to come from norgeometrybuild rather than
    // from EraseSize above.
    HasSectorMap: boolean;

    // Always False. It is a field rather than a comment so that a caller
    // copying this into a chip record cannot silently leave a voltage at
    // whatever the record was initialised to and have it read as knowledge.
    VoltageKnown: boolean;

    // Why the capability is what it is, in one sentence, for the operator.
    Note: string;
  end;

// Builds a profile, or says why it could not.
//
// JedecID is the response as read, uppercase hex, at least three bytes. It is
// required even though SFDP does not contain it: a profile with no identity
// cannot be checked against the part on the next operation, and re-checking
// identity before every destructive step is how this program catches a
// swapped chip.
function BuildProvisionalProfile(const JedecID: string;
  SFDPValid: boolean; const Info: TSFDPInfo;
  out Profile: TProvisionalProfile; out ErrMsg: string): boolean;

// The profile as lines for a log pane, a CLI or the session report. It leads
// with what the profile is, because an operator who does not notice that this
// part was described by itself rather than by the catalogue has been misled
// by the program.
function ProvisionalProfileLines(const Profile: TProvisionalProfile): TProfileLines;

// The synthesised name, exposed for the suite.
function SynthesiseName(const JedecID: string; CapacityBytes: QWord): string;

function CapabilityName(Capability: TProvisionalCapability): string;

implementation

const
  // The same charset chipprofile.ValidName and prodjob.ValidIdentifier
  // accept. A synthesised name that a production manifest would reject is a
  // name that works right up until somebody tries to use it for the thing
  // names are for.
  MAX_NAME_LENGTH = 96;

  // 16 MiB is the last byte a three-byte address reaches.
  THREE_BYTE_LIMIT = QWord(16) * 1024 * 1024;

function CapabilityName(Capability: TProvisionalCapability): string;
begin
  case Capability of
    pvReadOnly:  Result := 'read-only';
    pvReadWrite: Result := 'read/write';
  else
    Result := 'unusable';
  end;
end;

// A size that reads the way a person writes it, with no decimal point: SFDP
// densities are powers of two, so this is exact for every part that gets here.
function DensityText(Bytes: QWord): string;
begin
  if (Bytes >= 1024 * 1024) and ((Bytes mod (1024 * 1024)) = 0) then
    Result := IntToStr(Bytes div (1024 * 1024)) + 'M'
  else if (Bytes >= 1024) and ((Bytes mod 1024) = 0) then
    Result := IntToStr(Bytes div 1024) + 'K'
  else
    Result := IntToStr(Bytes);
end;

// Names a part the catalogue does not.
//
// The shape is deliberate in three ways.
//
// It is prefixed 'SFDP-', so that anyone reading a log, a backup manifest or
// an evidence record can see at a glance that this description came from the
// part rather than from the chip table. A synthesised name that looked like a
// manufacturer's part number would be the program inventing a part number.
//
// It contains the JEDEC ID, so the name identifies the thing it names. Two
// different parts cannot collide unless they answer identically, in which
// case the program has no way to tell them apart anyway.
//
// And it contains no substring the voltage inference keys on. Tier 2 looks
// for a '_1.8V' or '_3.3V' suffix and tier 3 for model prefixes such as
// 'MX25U'; a synthesised name must never trip either, because a name this
// unit made up is not evidence about a supply rail. Hex digits and the fixed
// 'SFDP-' prefix cannot form those patterns, and the suite pins it.
function SynthesiseName(const JedecID: string; CapacityBytes: QWord): string;
begin
  Result := 'SFDP-' + UpperCase(JedecID);
  if CapacityBytes > 0 then
    Result := Result + '-' + DensityText(CapacityBytes);
  if Length(Result) > MAX_NAME_LENGTH then
    SetLength(Result, MAX_NAME_LENGTH);
end;

function ValidJedecID(const Value: string): boolean;
var
  i: integer;
  AllZero, AllFF: boolean;
begin
  Result := False;
  if ((Length(Value) and 1) <> 0) or
     (Length(Value) < 6) or (Length(Value) > 32) then Exit;
  AllZero := True;
  AllFF := True;
  for i := 1 to Length(Value) do
  begin
    if not (Value[i] in ['0'..'9', 'A'..'F', 'a'..'f']) then Exit;
    if Value[i] <> '0' then AllZero := False;
    if not (Value[i] in ['F', 'f']) then AllFF := False;
  end;
  //All 00 or all FF is a floating bus, not a chip. Building a profile from
  //one would give a name and a geometry to an empty socket.
  if AllZero or AllFF then Exit;
  Result := True;
end;

function IsPowerOfTwo(Value: QWord): boolean;
begin
  Result := (Value <> 0) and ((Value and (Value - 1)) = 0);
end;

function BuildProvisionalProfile(const JedecID: string;
  SFDPValid: boolean; const Info: TSFDPInfo;
  out Profile: TProvisionalProfile; out ErrMsg: string): boolean;
var
  EraseSize: cardinal;
  EraseOpcode: byte;
  Reason: string;
begin
  Profile := Default(TProvisionalProfile);
  Profile.VoltageKnown := False;   //stated, not merely left alone
  ErrMsg := '';
  Result := False;

  if not ValidJedecID(JedecID) then
  begin
    ErrMsg := 'the JEDEC ID is missing, malformed, or all 00/FF';
    Exit;
  end;
  if not SFDPValid then
  begin
    //Not a failure of this unit. Plenty of real parts predate JESD216, and
    //for those the catalogue is the only source there has ever been.
    ErrMsg := 'the chip has no readable SFDP table';
    Exit;
  end;
  if (not Info.Valid) or (Info.Density = 0) then
  begin
    ErrMsg := 'the SFDP table declares no usable density';
    Exit;
  end;

  Profile.JedecID := UpperCase(JedecID);
  Profile.CapacityBytes := Info.Density;
  Profile.Name := SynthesiseName(Profile.JedecID, Info.Density);
  Profile.AddressBytes := Info.AddrBytes;
  Profile.HasSectorMap := Info.HasSectorMap;
  Profile.PageSize := Info.PageSize;
  Profile.Valid := True;

  //--- what would stop a read ---
  //
  //A part larger than three bytes can address, that says it only supports
  //three-byte addressing, is describing something impossible. One of the two
  //fields is wrong and there is no basis for preferring either.
  if (Info.Density > THREE_BYTE_LIMIT) and (Info.AddrBytes = 3) then
  begin
    Profile.Valid := False;
    Profile.Capability := pvNone;
    ErrMsg := Format('SFDP declares %d bytes but only three-byte addressing',
                     [Info.Density]);
    Profile.Note := ErrMsg;
    Exit;
  end;

  Profile.Capability := pvReadOnly;

  //--- what would stop a write ---
  //
  //Each of these leaves the part readable. Reading an unknown chip is how
  //somebody gets its contents off before doing anything else, and it is the
  //operation that cannot destroy anything, so it should be the last thing to
  //be refused.
  Reason := '';

  if Info.SectorMapDeclared and (not Info.HasSectorMap) then
    //The chip says it has a non-uniform layout and then produces a map that
    //cannot be resolved to one configuration. On a boot-block part, guessing
    //uniform 4K erases the wrong physical blocks and reports success.
    Reason := 'the chip declares an SFDP sector map whose active ' +
              'configuration is ambiguous'
  else if (Profile.PageSize = 0) or (Profile.PageSize > 65536) or
          (not IsPowerOfTwo(Profile.PageSize)) then
    Reason := 'the declared page size is not a usable power of two'
  else if not SFDPSmallestErase(Info, EraseSize, EraseOpcode) then
    Reason := 'the chip declares no erase type'
  else if (EraseOpcode = $00) or (EraseOpcode = $FF) then
    Reason := 'the declared erase opcode is 00 or FF, which is ambiguous'
  else if not IsPowerOfTwo(EraseSize) then
    Reason := 'the declared erase unit is not a power of two'
  else if Profile.PageSize > EraseSize then
    Reason := 'the declared page size is larger than the erase unit'
  else if (Info.Density mod EraseSize) <> 0 then
    //A capacity that is not a whole number of erase units means the last
    //erase would run off the end of the part or leave a tail that cannot be
    //erased at all.
    Reason := 'the declared capacity is not a whole number of erase units'
  else if (Info.Density > THREE_BYTE_LIMIT) and
          (not Info.HasSectorMap) and
          (Info.EraseTypes[1].Opcode4B = 0) and
          (Info.EraseTypes[2].Opcode4B = 0) and
          (Info.EraseTypes[3].Opcode4B = 0) and
          (Info.EraseTypes[4].Opcode4B = 0) and
          (not SFDPNeeds4BSwitch(Info)) then
    //A part above 16 MiB that claims a dedicated four-byte instruction set
    //and then names no four-byte erase opcode has not said how to erase its
    //upper half. Substituting a three-byte opcode there erases at a wrapped
    //address -- somewhere in the lower 16 MiB, silently.
    Reason := 'the chip is larger than 16 MiB and declares no four-byte ' +
              'erase opcode';

  if Reason <> '' then
  begin
    Profile.Note := 'read-only: ' + Reason;
    Exit(True);
  end;

  Profile.EraseSize := EraseSize;
  Profile.EraseOpcode := EraseOpcode;
  Profile.Capability := pvReadWrite;
  if Info.HasSectorMap then
    //EraseSize is the smallest unit the part offers, but the real block list
    //comes from the sector map. Saying so here stops a caller using
    //EraseSize as a uniform geometry on a boot-block part.
    Profile.Note := 'the chip declares a non-uniform sector map; the erase ' +
                    'block list comes from that map, not from one size'
  else
    Profile.Note := 'uniform geometry taken from the chip''s own SFDP tables';

  Result := True;
end;

//SFDP's encoding of the address width, in words. 34 is its way of saying the
//part accepts either, which is not the same as 3 or as 4 and must not render
//as "34".
function AddressText(AddrBytes: byte): string;
begin
  case AddrBytes of
    3:  Result := '3';
    4:  Result := '4';
    34: Result := '3 or 4';
  else
    Result := 'unknown';
  end;
end;

function ProvisionalProfileLines(
  const Profile: TProvisionalProfile): TProfileLines;

  procedure Add(const Line: string);
  var
    N: integer;
  begin
    N := Length(Result);
    SetLength(Result, N + 1);
    Result[N] := Line;
  end;

begin
  Result := nil;
  if not Profile.Valid then
  begin
    Add('No provisional profile: ' + Profile.Note);
    Exit;
  end;

  //Leads with what this is. An operator who does not notice that the part was
  //described by itself rather than by the chip table has been misled, and no
  //amount of correct detail below makes up for that.
  Add('Provisional profile, from the chip''s own SFDP tables -- not the ' +
      'chip catalogue.');
  Add('  Name:          ' + Profile.Name);
  Add('  JEDEC ID:      ' + Profile.JedecID);
  Add('  Capacity:      ' + IntToStr(Profile.CapacityBytes) +
      ' bytes (claimed by the chip, not verified)');
  Add('  Page size:     ' + IntToStr(Profile.PageSize));
  if Profile.HasSectorMap then
    Add('  Erase:         non-uniform; block list from the SFDP sector map')
  else if Profile.EraseSize > 0 then
    Add(Format('  Erase:         %d bytes, opcode %.2X',
               [Profile.EraseSize, Profile.EraseOpcode]))
  else
    Add('  Erase:         not established');
  Add('  Addressing:    ' + AddressText(Profile.AddressBytes) + ' byte');
  Add('  Usable for:    ' + CapabilityName(Profile.Capability));
  Add('  ' + Profile.Note);

  //SFDP carries no supply-voltage field of any kind, so this profile cannot
  //narrow the question by even one volt. Saying it plainly is the point: the
  //operator has just been shown a complete-looking description of a part, and
  //the one thing that destroys chips is not in it.
  Add('  Supply voltage: not stated by SFDP. The usual voltage rules still ' +
      'apply, and an unresolved part will still be asked about.');
end;

end.
