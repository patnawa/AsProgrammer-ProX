#!/usr/bin/env python3
"""Sanity checks for the chip tables.

chiplist.xml is a thousand hand maintained lines. A typo in it does not crash
anything, it just makes one chip behave wrongly, and that only shows up when
somebody puts that exact part in the socket. This runs in the build so the
typo is caught while it is still cheap.

Usage:
    python tools/validate_chiplist.py chiplist.xml [chiplist-flashrom.xml ...]

Exit code 0 when everything is fine, 1 when there is an error. Warnings do
not fail the build: chips that genuinely share an id are normal.
"""

import sys
import xml.etree.ElementTree as ET
from collections import defaultdict

MAX_PAGE = 2048
PAGE_KEYWORDS = {"SSTB", "SSTW"}


class Report:
    def __init__(self):
        self.errors = []
        self.warnings = []

    def error(self, where, msg):
        self.errors.append(f"{where}: {msg}")

    def warn(self, where, msg):
        self.warnings.append(f"{where}: {msg}")


def is_power_of_two(n):
    return n > 0 and (n & (n - 1)) == 0


def check_chip(rep, path, protocol, vendor, elem):
    name = elem.tag
    where = f"{path}/{vendor}/{name}"
    attrs = elem.attrib

    # Microwire parts are addressed in bits, not pages; they carry addrbitlen
    # instead and a page attribute would mean nothing.
    wants_page = protocol.upper() != "MICROWIRE"

    # --- size ---
    raw_size = attrs.get("size")
    if raw_size is None:
        rep.error(where, "no size attribute")
        return None
    try:
        size = int(raw_size)
    except ValueError:
        rep.error(where, f"size is not a number: {raw_size!r}")
        return None
    if size <= 0:
        rep.error(where, f"size must be positive, got {size}")
        return None
    if not is_power_of_two(size):
        # Some genuine parts are not a power of two, so this is only a warning.
        rep.warn(where, f"size {size} is not a power of two")

    # --- page ---
    raw_page = attrs.get("page")
    if raw_page is None:
        if wants_page:
            rep.error(where, "no page attribute")
        elif attrs.get("addrbitlen") is None:
            rep.error(where, "a Microwire chip needs addrbitlen")
    elif raw_page.upper() not in PAGE_KEYWORDS:
        try:
            page = int(raw_page)
        except ValueError:
            rep.error(where, f"page is neither a number nor SSTB/SSTW: {raw_page!r}")
        else:
            if page < 1:
                rep.error(where, f"page must be at least 1, got {page}")
            elif page > MAX_PAGE:
                rep.error(where, f"page {page} is larger than the {MAX_PAGE} byte buffer")
            elif page > size:
                rep.error(where, f"page {page} is larger than the chip ({size})")

    # --- id ---
    chip_id = attrs.get("id", "")
    if chip_id and chip_id != "0":
        if len(chip_id) % 2 != 0:
            rep.error(where, f"id has an odd number of hex digits: {chip_id!r}")
        try:
            int(chip_id, 16)
        except ValueError:
            rep.error(where, f"id is not hexadecimal: {chip_id!r}")

    # --- sector ---
    raw_sector = attrs.get("sector")
    if raw_sector is not None:
        try:
            sector = int(raw_sector)
        except ValueError:
            rep.error(where, f"sector is not a number: {raw_sector!r}")
        else:
            if sector <= 0:
                rep.error(where, f"sector must be positive, got {sector}")
            elif size % sector != 0:
                # Erase walks the chip in whole sectors; a size that is not a
                # multiple of the sector leaves a piece that cannot be erased.
                rep.error(where, f"size {size} is not a multiple of sector {sector}")

    # --- sectorcmd ---
    raw_cmd = attrs.get("sectorcmd")
    if raw_cmd is not None:
        try:
            cmd = int(raw_cmd, 16)
        except ValueError:
            rep.error(where, f"sectorcmd is not hexadecimal: {raw_cmd!r}")
        else:
            if not 0 <= cmd <= 0xFF:
                rep.error(where, f"sectorcmd is not a single byte: {raw_cmd!r}")

    return chip_id.upper() if chip_id else None


def check_file(rep, path):
    try:
        tree = ET.parse(path)
    except ET.ParseError as e:
        rep.error(path, f"cannot parse: {e}")
        return 0

    root = tree.getroot()
    names = defaultdict(list)
    ids = defaultdict(list)
    count = 0

    # chiplist / protocol / vendor / chip
    for protocol in root:
        for vendor in protocol:
            for chip in vendor:
                count += 1
                # The fingerprint decides whether a repeated name is a dead
                # line or merely an ambiguous one.
                fingerprint = (chip.attrib.get("id", ""),
                               chip.attrib.get("size", ""),
                               chip.attrib.get("page", ""))
                names[chip.tag].append((f"{protocol.tag}/{vendor.tag}", fingerprint))
                chip_id = check_chip(rep, path, protocol.tag, vendor.tag, chip)
                if chip_id:
                    ids[chip_id].append(chip.tag)

    for name, places in names.items():
        if len(places) < 2:
            continue

        where = ", ".join(p for p, _ in places)
        fingerprints = {f for _, f in places}

        if len(fingerprints) == 1:
            # Same name and same parameters: every copy after the first can
            # never be reached by anything, so it is dead weight.
            rep.error(path, f"chip {name!r} is listed {len(places)} times with "
                            f"identical parameters ({where})")
        else:
            # Same name, different parameters. Auto detect can still reach
            # them by id, but picking by name silently takes the first, and
            # the chip picker shows two rows that look the same.
            rep.warn(path, f"chip name {name!r} is used by {len(places)} "
                           f"different entries ({where}); selecting it by name "
                           f"always picks the first")

    for chip_id, chips in ids.items():
        if len(chips) > 8:
            rep.warn(path, f"id {chip_id} is shared by {len(chips)} chips")

    return count


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 1

    rep = Report()
    total = 0

    for path in argv[1:]:
        try:
            total += check_file(rep, path)
        except OSError as e:
            rep.error(path, f"cannot read: {e}")

    for w in rep.warnings:
        print(f"  warning  {w}")
    for e in rep.errors:
        print(f"  ERROR    {e}")

    print(f"  {total} chips checked, {len(rep.errors)} errors, "
          f"{len(rep.warnings)} warnings")

    return 1 if rep.errors else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
