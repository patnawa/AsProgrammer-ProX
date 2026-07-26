#!/usr/bin/env python3
"""แปลงตารางชิปของ flashrom ให้เป็น chiplist ของ AsProgrammer ProX

ผลลัพธ์คือ chiplist-flashrom.xml ซึ่งเป็นงานดัดแปลงจากตารางชิปของ flashrom
ไฟล์นั้นจึงยังคงสัญญาอนุญาต GPL-2.0-or-later ไม่ใช่ MIT เหมือนโค้ดโปรแกรม
ตัวสคริปต์จะใส่หัวลิขสิทธิ์ให้เองอัตโนมัติ

วิธีใช้:
    git clone --depth 1 https://github.com/flashrom/flashrom
    python tools/import_flashchips.py flashrom chiplist-flashrom.xml

สคริปต์จะข้ามชิปที่มี id อยู่ใน chiplist.xml อยู่แล้ว ไฟล์ที่ได้จึงมีแต่
ชิปที่เพิ่มเข้ามาใหม่จริง ๆ
"""

import os
import re
import sys
import xml.etree.ElementTree as ET

HEADER = """<?xml version="1.0" encoding="utf-8"?>
<!--
  chiplist-flashrom.xml

  ตารางชิปเพิ่มเติม แปลงมาจากตารางชิปของโครงการ flashrom โดยอัตโนมัติ
  ด้วย tools/import_flashchips.py

  ไฟล์นี้เป็นงานดัดแปลงจาก flashrom จึงอยู่ภายใต้สัญญาอนุญาต
  GPL-2.0-or-later ไม่ใช่ MIT แบบโค้ดส่วนอื่นของโปรแกรม

  SPDX-License-Identifier: GPL-2.0-or-later
  SPDX-FileCopyrightText: 2000 Silicon Integrated System Corporation
  SPDX-FileCopyrightText: 2000 Ronald G. Minnich
  SPDX-FileCopyrightText: 2004 Tyan Corp
  SPDX-FileCopyrightText: 2005-2008 coresystems GmbH
  SPDX-FileCopyrightText: 2006-2009 Carl-Daniel Hailfinger
  SPDX-FileCopyrightText: 2009 Sean Nelson
  SPDX-FileCopyrightText: ผู้ร่วมพัฒนา flashrom ท่านอื่น ๆ

  ต้นทาง: https://github.com/flashrom/flashrom
-->
<chiplist>
  <SPI>
"""

FOOTER = """  </SPI>
</chiplist>
"""

# SPI_BLOCK_ERASE_XX -> โอปโค้ด
ERASE_RE = re.compile(r"SPI_BLOCK_ERASE_([0-9A-Fa-f]{2})")


def load_defines(path):
    """อ่าน #define NAME 0xVALUE จาก flashchips.h"""
    out = {}
    with open(path, encoding="utf-8", errors="replace") as f:
        for line in f:
            m = re.match(r"\s*#define\s+([A-Za-z0-9_]+)\s+(0[xX][0-9A-Fa-f]+)", line)
            if m:
                out[m.group(1)] = int(m.group(2), 16)
    return out


def resolve(expr, defines):
    """ค่าอาจเขียนเป็นตัวเลข ชื่อ define หรือนิพจน์ง่าย ๆ"""
    expr = expr.strip().rstrip(",").strip()
    if not expr:
        return None
    if expr in defines:
        return defines[expr]
    try:
        return int(expr, 0)
    except ValueError:
        pass
    # รูปแบบอย่าง 4 * 1024
    m = re.fullmatch(r"(\d+)\s*\*\s*(\d+)", expr)
    if m:
        return int(m.group(1)) * int(m.group(2))
    return None


def split_entries(text):
    """ตัดข้อความออกเป็นบล็อกละหนึ่งชิป โดยยึดจากบรรทัด .name"""
    idx = [m.start() for m in re.finditer(r"^\s*\.name\s*=", text, re.M)]
    for i, start in enumerate(idx):
        end = idx[i + 1] if i + 1 < len(idx) else len(text)
        yield text[start:end]


def field(block, name):
    m = re.search(r"\.%s\s*=\s*([^,\n]+)" % name, block)
    return m.group(1).strip() if m else None


def smallest_eraser(block, defines):
    """คืน (ขนาดเซกเตอร์เล็กสุด, โอปโค้ด) จากรายการ block_erasers"""
    best = None
    # จับคู่ eraseblocks กับ block_erase ที่ตามมาทีละคู่
    for m in re.finditer(
        r"\.eraseblocks\s*=\s*\{\s*\{([^}]*)\}.*?\.block_erase\s*=\s*([A-Za-z0-9_]+)",
        block,
        re.S,
    ):
        size = resolve(m.group(1).split(",")[0], defines)
        op = ERASE_RE.search(m.group(2))
        if size and op:
            opcode = int(op.group(1), 16)
            # ข้ามการลบทั้งชิป ซึ่ง flashrom เก็บเป็นบล็อกเดียวเท่าขนาดชิป
            if opcode in (0x60, 0xC7):
                continue
            if best is None or size < best[0]:
                best = (size, opcode)
    return best


def xml_name(name, taken):
    """ชื่อชิปถูกใช้เป็นชื่อ element ต้องล้างให้ถูกกติกา XML"""
    s = re.sub(r"[^0-9A-Za-z._-]", "_", name)
    s = re.sub(r"_+", "_", s).strip("_")
    if not s:
        s = "chip"
    if not re.match(r"[A-Za-z_]", s[0]):
        s = "_" + s
    base = s
    n = 2
    while s in taken:
        s = "%s__%d" % (base, n)
        n += 1
    taken.add(s)
    return s


def existing_ids(chiplist_path):
    ids = set()
    if not os.path.exists(chiplist_path):
        return ids
    try:
        root = ET.parse(chiplist_path).getroot()
    except ET.ParseError:
        return ids
    for el in root.iter():
        v = el.get("id")
        if v:
            ids.add(v.upper())
    return ids


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        return 1

    flashrom_dir = sys.argv[1]
    out_path = sys.argv[2]
    chiplist = sys.argv[3] if len(sys.argv) > 3 else "chiplist.xml"

    header = os.path.join(flashrom_dir, "include", "flashchips.h")
    if not os.path.exists(header):
        header = os.path.join(flashrom_dir, "flashchips.h")
    defines = load_defines(header)
    print("defines: %d" % len(defines))

    known = existing_ids(chiplist)
    print("ids already in %s: %d" % (chiplist, len(known)))

    chips_dir = os.path.join(flashrom_dir, "flashchips")
    if not os.path.isdir(chips_dir):
        chips_dir = flashrom_dir

    by_vendor = {}
    taken = set()
    total = skipped_dup = skipped_nonspi = skipped_bad = 0

    for fname in sorted(os.listdir(chips_dir)):
        if not fname.endswith(".c"):
            continue
        vendor_key = os.path.splitext(fname)[0].upper()
        with open(os.path.join(chips_dir, fname), encoding="utf-8", errors="replace") as f:
            text = f.read()

        for block in split_entries(text):
            total += 1

            bus = field(block, "bustype") or ""
            if "BUS_SPI" not in bus:
                skipped_nonspi += 1
                continue

            name = field(block, "name")
            if not name:
                skipped_bad += 1
                continue
            name = name.strip().strip('"')

            mfr = resolve(field(block, "manufacture_id") or "", defines)
            model = resolve(field(block, "model_id") or "", defines)
            size_kib = resolve(field(block, "total_size") or "", defines)
            page = resolve(field(block, "page_size") or "", defines)

            if mfr is None or model is None or not size_kib or not page:
                skipped_bad += 1
                continue
            if mfr > 0xFF or model > 0xFFFF:
                skipped_bad += 1
                continue

            chip_id = "%02X%04X" % (mfr, model)
            if chip_id in known:
                skipped_dup += 1
                continue

            # ชิป 1.8 โวลต์ ตั้งชื่อตามธรรมเนียมของ AsProgrammer
            volt = field(block, "voltage") or ""
            mv = re.findall(r"\d+", volt)
            if mv and int(mv[0]) < 1900:
                name += "_1.8V"

            attrs = {
                "id": chip_id,
                "page": str(page),
                "size": str(size_kib * 1024),
            }
            er = smallest_eraser(block, defines)
            if er:
                attrs["sector"] = str(er[0])
                attrs["sectorcmd"] = "%02X" % er[1]

            by_vendor.setdefault(vendor_key, []).append((xml_name(name, taken), attrs))

    with open(out_path, "w", encoding="utf-8") as f:
        f.write(HEADER)
        written = 0
        for vendor in sorted(by_vendor):
            f.write("    <%s>\n" % vendor)
            for elname, attrs in by_vendor[vendor]:
                parts = " ".join('%s="%s"' % (k, attrs[k])
                                 for k in ("id", "page", "size", "sector", "sectorcmd")
                                 if k in attrs)
                f.write("      <%s %s/>\n" % (elname, parts))
                written += 1
            f.write("    </%s>\n" % vendor)
        f.write(FOOTER)

    print("entries seen      : %d" % total)
    print("skipped non-SPI   : %d" % skipped_nonspi)
    print("skipped unparsable: %d" % skipped_bad)
    print("skipped duplicate : %d" % skipped_dup)
    print("written           : %d  -> %s" % (written, out_path))
    return 0


if __name__ == "__main__":
    sys.exit(main())
