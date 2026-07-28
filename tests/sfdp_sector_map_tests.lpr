program sfdp_sector_map_tests;

{$mode objfpc}{$H+}

uses
  SysUtils, sfdp, spi25;

var
  Failures: integer = 0;

procedure Check(const Name: string; Condition: boolean);
begin
  if Condition then
    WriteLn('  ok   ', Name)
  else
  begin
    WriteLn('  FAIL ', Name);
    Inc(Failures);
  end;
end;

procedure CheckRejectedMap(AChip: TFakeChip; const Prefix: string);
var
  Info: TSFDPInfo;
  EraseSize: cardinal;
  Opcode: byte;
begin
  SetFakeChip(AChip);
  Check(Prefix + ': base SFDP still detects', SFDPDetect(Info));
  Check(Prefix + ': sector map fails closed', not Info.HasSectorMap);
  Check(Prefix + ': no partial regions escape', Info.RegionCount = 0);
  Check(Prefix + ': no erase geometry is returned',
        not SFDPSectorAt(Info, 0, EraseSize, Opcode));
end;

procedure TestStaticMap;
var
  Info: TSFDPInfo;
  EraseSize: cardinal;
  Opcode: byte;
begin
  WriteLn('JESD216 static sector-map descriptor');
  SetFakeChip(fcBootBlock);

  Check('base SFDP detects', SFDPDetect(Info));
  Check('bit 1 identifies the map descriptor', Info.HasSectorMap);
  Check('the last-map bit permits one resolved map', Info.RegionCount = 3);
  Check('the complete map covers the declared density',
        Info.Regions[0].Size + Info.Regions[1].Size +
        Info.Regions[2].Size = Info.Density);
  Check('the boot region has a usable 4K erase',
        SFDPSectorAt(Info, 0, EraseSize, Opcode) and
        (EraseSize = 4096) and (Opcode = $20));
end;

begin
  WriteLn('SFDP sector-map hardening tests');
  WriteLn;

  TestStaticMap;

  WriteLn('Descriptor type and active-configuration safety');
  CheckRejectedMap(fcMapBitTrap, 'bit 0 without bit 1');
  CheckRejectedMap(fcConfigurableMap, 'unresolved detection command');
  CheckRejectedMap(fcAmbiguousMaps, 'multiple maps without selector');

  WriteLn;
  if Failures = 0 then
    WriteLn('ALL PASSED')
  else
    WriteLn(Failures, ' FAILURES');
  Halt(Failures);
end.
