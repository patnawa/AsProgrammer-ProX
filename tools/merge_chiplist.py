#!/usr/bin/env python3
"""Merge chip entries from other lists into the master chiplist.xml.

The program happily loads chiplist-flashrom.xml, chiplist-ezp.xml and
chiplist-user.xml alongside the master list, so day to day nothing needs
merging. This tool is for the moments something does:

  * a chip saved into chiplist-user.xml via SFDP detection is confirmed
    good and should graduate into the shipped list;
  * an auxiliary list was regenerated (tools/import_flashchips.py,
    tools/import_ezp.py) and its genuinely new parts should be folded in;
  * two lists disagree about the same part and somebody needs to see the
    disagreement instead of whichever file happens to match first.

Usage:
    python tools/merge_chiplist.py chiplist.xml source.xml [source2.xml ...]
    python tools/merge_chiplist.py --write chiplist.xml source.xml

Without --write nothing is modified; the tool prints what would be added
and every conflict. With --write the new entries are inserted into the
master file *textually* -- under the existing vendor group when there is
one, in a new vendor group at the end of the section otherwise -- so the
master's comments, ordering and hand formatting survive untouched.
Conflicting entries are never written; they are reported and left alone.

A merged entry that also stays in its auxiliary file in the program
folder will match twice in Find IC. If you merge an auxiliary list,
remove that file from the folder, or merge only what you need.

Exit code 0 when clean (or --write succeeded and the result validates),
1 on conflicts or errors.
"""

import argparse
import subprocess
import sys
import xml.etree.ElementTree as ET
from pathlib import Path
from xml.sax.saxutils import quoteattr

# Attributes whose values are compared case-insensitively (hex digits).
HEX_ATTRS = {"id", "sectorcmd"}


def norm_attrs(attrs):
    """Attribute dict normalised for comparison, not for output."""
    out = {}
    for key, value in attrs.items():
        v = value.strip()
        if key in HEX_ATTRS:
            v = v.upper()
        out[key] = v
    return out


def load_entries(path):
    """{(section, name): (vendor, attrs)} for every chip element.

    The schema is <chiplist><SECTION><VENDOR><CHIPNAME attrs/>. A name that
    appears twice in one section keeps its first occurrence, matching how
    the program itself resolves a name lookup.
    """
    tree = ET.parse(path)
    root = tree.getroot()
    if root.tag != "chiplist":
        raise SystemExit(f"{path}: root element is {root.tag}, not chiplist")
    entries = {}
    vendors = set()
    for section in root:
        for vendor in section:
            vendors.add((section.tag, vendor.tag))
            for chip in vendor:
                key = (section.tag, chip.tag)
                if key not in entries:
                    entries[key] = (vendor.tag, dict(chip.attrib))
    return entries, vendors


def chip_line(name, attrs, indent="      "):
    parts = [name] + [f"{k}={quoteattr(v)}" for k, v in attrs.items()]
    return f"{indent}<{' '.join(parts)}/>\n"


def insert_into_master(master_path, additions):
    """Insert chip lines into the master file text, preserving everything.

    additions: {(section, vendor): [(name, attrs), ...]}
    """
    lines = master_path.read_text(encoding="utf-8").splitlines(keepends=True)

    # Find the closing line of a vendor group inside a section, or the
    # closing line of the section itself. Tag matching is textual but the
    # file was just parsed successfully, so the tags are well formed; the
    # only risk is a tag name occurring in a comment, which none do.
    def find_close(open_tag, close_tag, start=0):
        depth = 0
        opened = -1
        for i in range(start, len(lines)):
            stripped = lines[i].strip()
            if stripped.startswith(f"<{open_tag}>") or \
               stripped.startswith(f"<{open_tag} "):
                opened = i
                depth = 1
                if f"</{open_tag}>" in stripped or stripped.endswith("/>"):
                    return i, i
            elif opened >= 0 and stripped.startswith(close_tag):
                return opened, i
        return -1, -1

    for (section, vendor), chips in sorted(additions.items()):
        sec_open, sec_close = find_close(section, f"</{section}>")
        if sec_open < 0:
            print(f"  error  master has no <{section}> section; "
                  f"skipped {len(chips)} chips")
            continue
        ven_open, ven_close = -1, -1
        # search for the vendor only inside this section
        i, j = find_close(vendor, f"</{vendor}>", sec_open + 1)
        if 0 <= i < sec_close:
            ven_open, ven_close = i, j
        new_lines = [chip_line(name, attrs) for name, attrs in chips]
        if ven_close >= 0:
            lines[ven_close:ven_close] = new_lines
        else:
            block = [f"    <{vendor}>\n"] + new_lines + [f"    </{vendor}>\n"]
            lines[sec_close:sec_close] = block
        # each loop iteration re-scans the mutated list from scratch, so
        # positions never go stale (the file is ~1000 lines, merges rare)

    master_path.write_text("".join(lines), encoding="utf-8")


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("master", type=Path)
    ap.add_argument("sources", type=Path, nargs="+")
    ap.add_argument("--write", action="store_true",
                    help="insert the new entries into the master file")
    args = ap.parse_args()

    master_entries, _ = load_entries(args.master)

    additions = {}       # {(section, vendor): [(name, attrs)]}
    conflicts = []
    identical = 0
    seen_new = {}        # (section, name) -> source path, for cross-source dupes

    for src in args.sources:
        entries, _ = load_entries(src)
        for (section, name), (vendor, attrs) in sorted(entries.items()):
            key = (section, name)
            if key in master_entries:
                mvendor, mattrs = master_entries[key]
                if norm_attrs(mattrs) == norm_attrs(attrs):
                    identical += 1
                elif mvendor != vendor and norm_attrs(mattrs) != norm_attrs(attrs):
                    conflicts.append(
                        f"{section}/{name}: master ({mvendor}) has "
                        f"{mattrs}, {src.name} ({vendor}) has {attrs}")
                else:
                    conflicts.append(
                        f"{section}/{name}: master has {mattrs}, "
                        f"{src.name} has {attrs}")
                continue
            if key in seen_new:
                conflicts.append(
                    f"{section}/{name}: appears in both {seen_new[key]} "
                    f"and {src.name}; merge one of them at a time")
                continue
            seen_new[key] = src.name
            additions.setdefault((section, vendor), []).append((name, attrs))

    total_new = sum(len(v) for v in additions.values())
    print(f"{total_new} new, {identical} identical, "
          f"{len(conflicts)} conflicts")

    for (section, vendor), chips in sorted(additions.items()):
        for name, attrs in chips:
            print(f"  new      {section}/{vendor}/{name}  {attrs}")
    for c in conflicts:
        print(f"  conflict {c}")

    if not args.write:
        if total_new:
            print("\nnothing written; rerun with --write to apply "
                  "the new entries")
        return 1 if conflicts else 0

    if total_new:
        insert_into_master(args.master, additions)
        print(f"\nwrote {total_new} entries into {args.master}")
        # The validator is the safety net for what was just written.
        validator = Path(__file__).with_name("validate_chiplist.py")
        if validator.exists():
            rc = subprocess.call(
                [sys.executable, str(validator), str(args.master)])
            if rc != 0:
                print("the merged master FAILED validation; "
                      "review the changes before committing")
                return 1
    else:
        print("\nnothing to write")

    return 1 if conflicts else 0


if __name__ == "__main__":
    sys.exit(main())
