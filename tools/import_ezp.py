#!/usr/bin/env python3
"""Convert an EZP programmer chip database (.Dat) into chiplist XML.

    python tools/import_ezp.py "EZP2023+.Dat" -o chiplist-ezp.xml

The EZP2023+ / EZP2020 software keeps its chip table in a flat file of fixed
68 byte records.  This reads that file and writes the entries out in the same
schema as chiplist.xml, skipping anything already present in the tables we
ship so the result only ever adds chips.

Record layout, 68 bytes, verified against EZP2023+.Dat (878 records):

    0..47   name, NUL padded, "FAMILY,MANUFACTURER,PART"
            the PART half is sometimes annotated in Chinese (GBK)
    48..51  little endian u32, the JEDEC id read by 9Fh:
            byte 48 = 3rd id byte, 49 = 2nd, 50 = manufacturer, 51 = 0
    52..55  little endian u32, chip size in bytes
    56..57  little endian u16, program page size in bytes
    58      u8,  chip class: 0 SPI flash, 1 24-EEPROM, 2 93-EEPROM,
            3 25-EEPROM, 4 95-EEPROM
    59      u8,  which programming algorithm the firmware should run
    60..61  little endian u16, delay in milliseconds
    62..63  little endian u16, "extend"
    64..65  little endian u16, EEPROM size on parts that carry one
    66      u8,  EEPROM page size
    67      u8,  supply voltage: 0 = 3.3 V, 1 = 1.8 V, 2 = 5.0 V

    Bytes 58..67 were "purpose not established" here until the field names
    were confirmed against the ezp_chip_data struct that libezp2023plus
    documents (github.com/alexandro-45/libezp2023plus) and re-checked
    against this file.  Only the voltage is used below: class is redundant
    with the family in the name, and the algorithm/delay/extend fields are
    instructions for the EZP firmware, which is not what drives this
    program's chips.

    Page is a u16, not the low half of a u32.  Reading it as a u32 gives
    values like 196624 for CAT25C02P, whose page is really 16; the 0x0003 in
    the next halfword is a separate field.  Checked against the datasheet
    page sizes for CAT25C02P (16), 25LC010 (16), X25256 (64), M95512 (128)
    and M95M01 (256).

There is a prebuilt ELF called ezp_parser that dumps the same file as C
structs.  This does not shell out to it, for three reasons found by comparing
the two outputs:

  * it prints the id with %hhx, which drops leading zeros, so AT25FS010
    (1F 66 01) comes out as "0x6610000" and the id is silently wrong
  * it does not decode the GBK part names, so they arrive as mojibake
  * it walks two records past the end of the file and prints empty entries

Families
--------
Only the SPI families are imported by default.  For those, everything
chiplist.xml needs is actually in the record: the id, the size and the page
size.  The I2C and MicroWire families are not: chiplist needs an "addrtype"
or an "addrbitlen" that the EZP file simply does not carry, and getting one
of those wrong means reading or writing the wrong part of an EEPROM without
any error.  Pass --i2c to derive addrtype from the size using the standard
24Cxx geometries; there is deliberately no equivalent for MicroWire, where
the address width depends on how the part is strapped and cannot be inferred.

Licence
-------
The EZP database is a third party file.  Chip ids, sizes and page sizes are
facts out of the manufacturers' datasheets rather than authorship, but the
selection as a whole is somebody else's compilation, so the output is written
to its own file exactly like chiplist-flashrom.xml.  Delete it and the
program still works.
"""

import argparse
import re
import struct
import sys
import xml.etree.ElementTree as ET
from collections import Counter, defaultdict

RECORD = 68
NAME_LEN = 48

# EZP family -> (chiplist section, spicmd attribute or None for the default)
SPI_FAMILIES = {
    "SPI_FLASH": ("SPI", None),   # 25 series NOR, the default command set
    "25_EEPROM": ("SPI", "95"),   # 25xx SPI EEPROM
    "95_EEPROM": ("SPI", "95"),   # 95xx SPI EEPROM
    "45_EEPROM": ("SPI", "45"),   # Atmel DataFlash
}

# SPI_NAND is in some of these files.  It is deliberately not imported: NAND
# needs bad block handling, spare areas and ECC, none of which this program
# has, so an entry would only offer the user a chip it cannot actually read.

# Standard 24Cxx geometries.  size -> addrtype, matching the constants in
# software/i2c.pas.  Only used with --i2c.
I2C_ADDRTYPE = {
    128: 1, 256: 1,          # 24C01, 24C02   one address byte
    512: 2,                  # 24C04          + 1 bit in the control byte
    1024: 3,                 # 24C08          + 2 bits
    2048: 4,                 # 24C16          + 3 bits
    4096: 5, 8192: 5, 16384: 5, 32768: 5, 65536: 5,   # 24C32..24C512, 2 bytes
}

VALID_NAME = re.compile(r"[^A-Za-z0-9_.-]")

# Byte 67 is the rail the EZP2023+ switches on, NOT the chip's rating, and
# the difference matters enough to spell out.  Across all 877 records in
# EZP2023+.Dat (ver 3.0):
#
#     0 (3.3 V)  444 records -- every SPI flash, INCLUDING every part whose
#                own name ends in "(1.8V)": W25Q64FW, GD25LQ128, the
#                BoyaMicro AL series, all of them
#     2 (5.0 V)  431 records -- the 24 / 93 / 25 EEPROM families
#     1 (1.8 V)    1 record  -- EN25LF40, alone against its whole family
#   255            2 records -- trailing duplicates of A25L05PU, junk
#
# So the vendor's software drives 1.8 V parts from the 3.3 V rail and warns
# the operator by putting "(1.8V)" in the chip's name; it does not encode
# the requirement in the field.  Taking byte 67 as the chip's voltage would
# therefore mark every 1.8 V part in the file as 3.3 V -- the exact mistake
# that destroys one.  The field is trusted only where it says 5 V, which
# agrees with the datasheets for those EEPROM families, and the single
# 1.8 V claim is ignored as a typo in the vendor's own table.
EZP_VOLTAGE_5V = 2

# 1.8 V therefore still comes from the name, which is where this vendor
# actually records it.  Not every part says so in words -- W25Q64FW is a
# 1.8 V part whose name never mentions it -- so these maker conventions
# fill the gap:
#
#   EF60xx / EF70xx  Winbond W25Q..FW / ..EW / ..DW / ..BW / ..NW
#   MX25U / MX66U    Macronix, U is the 1.8 V suffix
#   MT25QU           Micron, U likewise
#   GD25LQ / GD25WQ  GigaDevice low voltage parts
LOW_VOLTAGE_ID = ("EF60", "EF70")
LOW_VOLTAGE_NAME = re.compile(r"^(MX25U|MX66U|MT25QU|GD25LQ|GD25WQ|W25Q\d+(FW|EW|DW|BW|NW))",
                              re.IGNORECASE)


VOLTAGE_CLASHES = []


def report_voltage_clash(name: str, declared: str, why: str) -> None:
    VOLTAGE_CLASHES.append(f"{name}: the record says {declared} V but {why}")


def is_1v8(name: str, chip_id: str) -> bool:
    if "1.8V" in name.upper():
        return True
    if chip_id and chip_id.upper().startswith(LOW_VOLTAGE_ID):
        return True
    return bool(LOW_VOLTAGE_NAME.match(name))


def decode_name(raw: bytes) -> str:
    """Decode a record name.  The part half may be annotated in GBK."""
    raw = raw.split(b"\x00", 1)[0]
    for enc in ("ascii", "gbk", "latin-1"):
        try:
            return raw.decode(enc)
        except UnicodeDecodeError:
            continue
    return raw.decode("latin-1", "replace")


def xml_name(part: str):
    """Turn a part name into a legal XML element name, or None if nothing is left.

    chiplist.xml uses the element name as the chip name and prefixes an
    underscore when the name would otherwise start with a digit, so this
    follows the same convention.
    """
    # drop any parenthesised annotation: "A25L16P(bottom)" -> "A25L16P"
    part = re.sub(r"\(.*?\)?$", "", part).strip()
    part = VALID_NAME.sub("", part)
    if not part:
        return None
    if not (part[0].isalpha() or part[0] == "_"):
        part = "_" + part
    return part


def read_records(path):
    blob = open(path, "rb").read()
    if len(blob) % RECORD:
        print(f"  warning  {len(blob)} bytes is not a whole number of "
              f"{RECORD} byte records; the tail is ignored", file=sys.stderr)

    for off in range(0, len(blob) - RECORD + 1, RECORD):
        rec = blob[off:off + RECORD]
        name = decode_name(rec[:NAME_LEN])
        if not name.strip():
            continue

        id2, id1, man, _pad = rec[48:52]
        (size, page, clazz, algorithm, delay, extend,
         eeprom, eeprom_page, voltage) = struct.unpack("<IHBBHHHBB",
                                                       rec[52:68])

        parts = name.split(",")
        if len(parts) < 3:
            continue

        yield {
            "family": parts[0].strip(),
            "maker": parts[1].strip() or "UNKNOWN",
            "part": ",".join(parts[2:]).strip(),
            "man": man, "id1": id1, "id2": id2,
            "size": size, "page": page,
            "clazz": clazz, "algorithm": algorithm,
            "delay": delay, "extend": extend,
            "eeprom": eeprom, "eeprom_page": eeprom_page,
            "voltage": voltage,
        }


def existing_names(paths):
    """Every chip name already in the tables we ship, upper case."""
    seen = set()
    for p in paths:
        try:
            root = ET.parse(p).getroot()
        except (OSError, ET.ParseError) as e:
            print(f"  warning  could not read {p}: {e}", file=sys.stderr)
            continue
        for chip in root.iter():
            if chip.get("size") is None:
                continue
            n = chip.tag.upper()
            seen.add(n)
            seen.add(n.lstrip("_"))
    return seen


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("dat", nargs="+", help="one or more EZP .Dat chip databases")
    ap.add_argument("-o", "--out", default="chiplist-ezp.xml")
    ap.add_argument("--existing", nargs="*", default=["chiplist.xml",
                                                      "chiplist-flashrom.xml"],
                    help="tables to skip duplicates against")
    ap.add_argument("--i2c", action="store_true",
                    help="also import 24_EEPROM, deriving addrtype from the size")
    ap.add_argument("--all", action="store_true",
                    help="do not skip chips that are already in the shipped tables")
    args = ap.parse_args()

    known = set() if args.all else existing_names(args.existing)

    # section -> maker -> list of (name, attrs)
    out = defaultdict(lambda: defaultdict(list))
    emitted = set()
    stats = Counter()

    records = []
    for path in args.dat:
        n = 0
        for r in read_records(path):
            records.append(r)
            n += 1
        print(f"  {n:5d}  records read from {path}")

    for r in records:
        fam = r["family"]
        stats[f"seen:{fam}"] += 1

        if fam in SPI_FAMILIES:
            section, spicmd = SPI_FAMILIES[fam]
            addrtype = None
        elif fam == "24_EEPROM" and args.i2c:
            section, spicmd = "I2C", None
            addrtype = I2C_ADDRTYPE.get(r["size"])
            if addrtype is None:
                stats["skipped:i2c size has no standard addrtype"] += 1
                continue
        else:
            stats[f"skipped:family {fam}"] += 1
            continue

        # The tail of the file holds records that are not real chips: stale
        # name buffers with FF filled fields.  Rather than trust the record
        # count, refuse anything whose geometry cannot be true.  MAX_PAGE
        # matches the buffer the program writes a page from.
        if not (0 < r["size"] <= 128 * 1024 * 1024):
            stats["skipped:size out of range"] += 1
            continue
        if not (0 < r["page"] <= 2048):
            stats["skipped:page out of range"] += 1
            continue
        if r["page"] > r["size"]:
            stats["skipped:page larger than the chip"] += 1
            continue
        if r["size"] % r["page"]:
            stats["skipped:size is not a whole number of pages"] += 1
            continue

        name = xml_name(r["part"])
        if not name:
            stats["skipped:name unusable"] += 1
            continue

        key = name.upper()
        if key in emitted or key.lstrip("_") in emitted:
            stats["skipped:duplicate inside the EZP file"] += 1
            continue
        if key in known or key.lstrip("_") in known:
            stats["skipped:already in a shipped table"] += 1
            continue

        attrs = {}
        # 00 and FF are what an absent id looks like; parts that only answer
        # ABh or 15h genuinely have no 9Fh id, and chiplist allows no id at all
        if r["man"] not in (0x00, 0xFF):
            attrs["id"] = f"{r['man']:02X}{r['id1']:02X}{r['id2']:02X}"
        if r["page"]:
            attrs["page"] = str(r["page"])
        attrs["size"] = str(r["size"])
        if spicmd:
            attrs["spicmd"] = spicmd
        if addrtype is not None:
            attrs["addrtype"] = str(addrtype)
        # 1.8 V from the name (see EZP_VOLTAGE_5V above for why the record
        # cannot supply it), 5 V from the record where it says so.  A part
        # that looks 1.8 V by name and 5 V by record is a contradiction
        # nobody should resolve silently.
        if is_1v8(name, attrs.get("id", "")):
            attrs["vcc"] = "1.8"
            stats["marked as 1.8 V from the name"] += 1
            if r["voltage"] == EZP_VOLTAGE_5V:
                report_voltage_clash(name, "5.0",
                                     "the name says 1.8 V")
        elif r["voltage"] == EZP_VOLTAGE_5V:
            attrs["vcc"] = "5.0"
            stats["marked as 5 V from the record"] += 1

        out[section][r["maker"]].append((name, attrs))
        emitted.add(key)
        stats[f"imported:{fam}"] += 1

    root = ET.Element("chiplist")
    total = 0
    for section in sorted(out):
        sec = ET.SubElement(root, section)
        for maker in sorted(out[section]):
            grp = ET.SubElement(sec, VALID_NAME.sub("_", maker) or "UNKNOWN")
            for name, attrs in sorted(out[section][maker]):
                ET.SubElement(grp, name, attrs)
                total += 1

    ET.indent(root, space="  ")
    header = (
        "<!-- Generated by tools/import_ezp.py from an EZP programmer .Dat "
        "chip database.\n"
        "     Third party data, kept in its own file like chiplist-flashrom.xml.\n"
        "     Delete this file and the program still works. -->\n")
    with open(args.out, "w", encoding="utf-8") as f:
        f.write('<?xml version="1.0" encoding="utf-8"?>\n')
        f.write(header)
        f.write(ET.tostring(root, encoding="unicode"))
        f.write("\n")

    for k in sorted(stats):
        print(f"  {stats[k]:5d}  {k}")
    if VOLTAGE_CLASHES:
        print(f"\n{len(VOLTAGE_CLASHES)} voltage disagreements "
              f"(the record won; check these against the datasheet):")
        for c in VOLTAGE_CLASHES:
            print(f"  {c}")
    print(f"\n{total} chips written to {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
