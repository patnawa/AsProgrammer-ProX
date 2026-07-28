#!/usr/bin/env python3
"""Build SFDP parameter tables for tests/sfdp from datasheet values.

These are CONSTRUCTED, not captured from silicon. Every field here is written
from the published JESD216 encoding and the part's datasheet, so they exercise
the parser against the shapes real parts have -- a uniform 3-byte part, a
4-byte part with a dedicated instruction set, a boot-block part whose sector
map is not uniform, and configurable maps that must not be guessed.

A table dumped from a real chip is worth more than any of these. Get one with:

    AsProgrammer.exe --sfdp-dump w25q128jv.bin --chip W25Q128JV

then drop it in tests/sfdp/ and add a manifest line. The suite picks it up with
no code change, and the parser can never silently regress on that part again.

    python tools/make_sfdp_fixtures.py
"""

import os, struct

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                   'tests', 'sfdp')


def dw(*vals):
    return b''.join(struct.pack('<I', v) for v in vals)


def build(basic, extra_tables=(), major=1, minor=6):
    """SFDP header + parameter headers + tables, laid out back to back."""
    nph = len(extra_tables)                       # NPH is the count minus one
    header = b'SFDP' + bytes([minor, major, nph, 0xFF])

    tables = [(0x00, 0xFF, basic)] + list(extra_tables)
    ptr = 8 + len(tables) * 8
    param_headers = b''
    body = b''
    for lsb, msb, data in tables:
        assert len(data) % 4 == 0
        table_minor = {(0x81, 0xFF): 0, (0x84, 0xFF): 1}.get(
            (lsb, msb), minor)
        param_headers += bytes([lsb, table_minor, major, len(data) // 4,
                                ptr & 0xFF, (ptr >> 8) & 0xFF,
                                (ptr >> 16) & 0xFF, msb])
        body += data
        ptr += len(data)

    return header + param_headers + body


def basic_table(density_bits, erase_types, page_shift=8, addr_mode=0,
                erase4k_op=0x20, dword16=None, timing=True):
    """The 20-dword JESD216B basic table, enough of it to be realistic."""
    d = [0] * 20

    # DWORD-1: 4K erase supported (bits 1:0 = 01), its opcode, address bytes
    d[0] = 0x01 | (erase4k_op << 8) | (addr_mode << 17) | (0xF << 23)
    # DWORD-2: density, as bits minus one
    d[1] = density_bits - 1

    # DWORD-8 and DWORD-9: the four erase types, size as a power of two
    def pack_pair(a, b):
        v = 0
        if a: v |= (a[0] & 0xFF) | ((a[1] & 0xFF) << 8)
        if b: v |= ((b[0] & 0xFF) << 16) | ((b[1] & 0xFF) << 24)
        return v
    et = list(erase_types) + [None] * (4 - len(erase_types))
    d[7] = pack_pair(et[0], et[1])
    d[8] = pack_pair(et[2], et[3])

    if timing:
        # DWORD-10: multiplier in bits 3:0, then four 7-bit erase times.
        # count 15 with unit 01 (16 ms) -> typical 256 ms; multiplier 1 -> x4.
        mult = 1
        d[9] = mult
        for i in range(4):
            count, unit = 15, 1
            d[9] |= ((count & 0x1F) | ((unit & 0x03) << 5)) << (4 + i * 7)

        # DWORD-11: page size at bits 7:4, page program time at 13:8,
        # chip erase time at 30:24
        d[10] = 1 | (page_shift << 4)
        pp_count, pp_unit = 7, 1           # (7+1) * 64 us = 512 us typical
        d[10] |= ((pp_count & 0x1F) << 8) | ((pp_unit & 0x01) << 13)
        ce_count, ce_unit = 24, 1         # (24+1) * 256 ms = 6.4 s typical
        d[10] |= ((ce_count & 0x1F) << 24) | ((ce_unit & 0x03) << 29)
    else:
        d[10] = page_shift << 4

    if dword16 is not None:
        d[15] = dword16

    return dw(*d)


def region_dword(size, mask):
    assert size > 0 and size % 256 == 0
    # Bits 31:8 carry the 256-byte-unit count minus one; bits 7:4 are reserved
    # as ones and bits 3:0 select the supported erase types.
    return 0xF0 | (mask & 0x0F) | ((((size // 256) - 1) & 0xFFFFFF) << 8)


def map_descriptor(config_id, regions, end):
    """One FF81h map descriptor, including all of its region DWORDs."""
    assert regions and len(regions) <= 256
    # Bits 31:24 and 7:2 are reserved as ones. Bit 1 selects a map; bit 0 is
    # the end-of-map-sequence indicator.
    hdr = (0xFF << 24) | ((len(regions) - 1) << 16) | \
          ((config_id & 0xFF) << 8) | 0xFE | int(bool(end))
    out = [hdr]
    for size, mask in regions:
        out.append(region_dword(size, mask))
    return dw(*out)


def sector_map(regions):
    """FF81h static configuration zero: one map and no detect commands."""
    return map_descriptor(0, regions, True)


def config_command(opcode, mask, address=0xFFFFFFFF, end=True,
                   address_len=0, latency=0):
    """One two-DWORD configuration-detection command descriptor."""
    assert mask and not (mask & (mask - 1)) and mask <= 0x80
    assert 0 <= address_len <= 3 and 0 <= latency <= 0xF
    first = ((mask & 0xFF) << 24) | ((address_len & 3) << 22) | \
            (3 << 20) | ((latency & 0xF) << 16) | \
            ((opcode & 0xFF) << 8) | 0xFC | int(bool(end))
    return dw(first, address)


def bait(flags, erase_ops):
    return dw(flags, erase_ops)


FIXTURES = {}

# --- a plain 64 Mbit uniform part, 3 byte addressing (W25Q64BV shape) ---
FIXTURES['w25q64-uniform.bin'] = (
    build(basic_table(64 * 1024 * 1024,
                      [(12, 0x20), (15, 0x52), (16, 0xD8)],
                      addr_mode=0)),
    'density=8388608 page=256 addr=3 erase1=4096/20 erase2=32768/52 '
    'erase3=65536/D8 sectormap=0 timing=1',
)

# --- a 256 Mbit part with a dedicated 4 byte instruction set (MX25L256 shape) ---
#   DWORD-16 bit 29 (of the 24..31 field, i.e. bit 5) = dedicated 4B opcodes
#   4BAIT bit 0 = 13h read, bit 1 = 0Ch fast read, bit 6 = 12h page program,
#   bits 9..12 = the four erase types have 4 byte twins
FIXTURES['mx25l256-4byte.bin'] = (
    build(basic_table(256 * 1024 * 1024,
                      [(12, 0x20), (15, 0x52), (16, 0xD8)],
                      addr_mode=1,
                      dword16=(0x20 << 24) | 0x02),
          extra_tables=[(0x84, 0xFF,
                         bait(0x01 | 0x02 | 0x40 | (1 << 9) | (1 << 11),
                              0x21 | (0xDC << 16)))]),
    'density=33554432 page=256 addr=34 read4b=13 fastread4b=0C prog4b=12 '
    'erase1op4b=21 erase3op4b=DC sectormap=0 timing=1',
)

# --- a boot block part: 64K of 4K sectors at each end, 64K blocks between ---
_MB8 = 8 * 1024 * 1024
_BOOT_REGIONS = [
    (0x10000, 0b0001),                  # bottom boot: 4K only
    (_MB8 - 0x20000, 0b0111),           # main: 4K, 32K, 64K
    (0x10000, 0b0001),                  # top boot: 4K only
]
FIXTURES['bootblock-8mb.bin'] = (
    build(basic_table(64 * 1024 * 1024,
                      [(12, 0x20), (15, 0x52), (16, 0xD8)]),
          extra_tables=[(0x81, 0xFF, sector_map(_BOOT_REGIONS))]),
    'density=8388608 page=256 sectormap=1 regions=3 uniform=0 timing=1',
)

# A command descriptor means software must read the live configuration bit,
# build the selector, and match its map ID. A parser of an offline SFDP image
# cannot know whether configuration 0 or 1 is active.
FIXTURES['configurable-maps-unresolved.bin'] = (
    build(basic_table(64 * 1024 * 1024,
                      [(12, 0x20), (15, 0x52), (16, 0xD8)]),
          extra_tables=[(0x81, 0xFF,
                         config_command(0x35, 0x04) +
                         map_descriptor(0, [(_MB8, 0b0100)], False) +
                         map_descriptor(1, _BOOT_REGIONS, True))]),
    'density=8388608 page=256 sectormap=0 regions=0 timing=1',
)

# Multiple map descriptors without detection commands are structurally
# ambiguous. Even though configuration ID zero exists, selecting it would be
# an unsupported assumption about mutable device state.
FIXTURES['ambiguous-maps.bin'] = (
    build(basic_table(64 * 1024 * 1024,
                      [(12, 0x20), (15, 0x52), (16, 0xD8)]),
          extra_tables=[(0x81, 0xFF,
                         map_descriptor(0, [(_MB8, 0b0100)], False) +
                         map_descriptor(1, [(_MB8, 0b0001)], True))]),
    'density=8388608 page=256 sectormap=0 regions=0 timing=1',
)

# Regression trap for the original bug: bit 0 says "last descriptor"; only
# bit 1 distinguishes map from command. This is therefore a command descriptor
# and must never be decoded as a one-region sector map.
FIXTURES['descriptor-bit0-trap.bin'] = (
    build(basic_table(64 * 1024 * 1024,
                      [(12, 0x20), (15, 0x52), (16, 0xD8)]),
          extra_tables=[(0x81, 0xFF,
                         dw(0xFF0000FD, region_dword(_MB8, 0b0001)))]),
    'density=8388608 page=256 sectormap=0 regions=0 timing=1',
)


def main():
    os.makedirs(OUT, exist_ok=True)
    manifest = ["# Generated by tools/make_sfdp_fixtures.py -- constructed from",
                "# datasheet values, not captured from silicon. Real dumps made",
                "# with --sfdp-dump are more valuable; add them here with a line.",
                "#",
                "# <file> <space separated key=value expectations>"]
    for name, (data, expect) in sorted(FIXTURES.items()):
        with open(os.path.join(OUT, name), 'wb') as f:
            f.write(data)
        manifest.append(f"{name} {expect}")
        print(f"{name}: {len(data)} bytes")

    with open(os.path.join(OUT, 'manifest.txt'), 'w', newline='\n') as f:
        f.write('\n'.join(manifest) + '\n')
    print(f"manifest.txt: {len(FIXTURES)} entries")


if __name__ == '__main__':
    main()
