#!/usr/bin/env python3
"""Fail on release/docs drift and report translation-catalog coverage."""

from __future__ import annotations

import ast
import os
import re
import sys
from collections import Counter
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


def require_match(pattern: str, text: str, label: str) -> str:
    match = re.search(pattern, text, re.MULTILINE)
    if not match:
        raise ValueError(f"could not find {label}")
    return match.group(1)


def po_value(block_lines: list[str], field: str) -> str | None:
    for index, line in enumerate(block_lines):
        match = re.match(rf"^{field}\s+(\".*\")$", line)
        if not match:
            continue
        pieces = [match.group(1)]
        for continuation in block_lines[index + 1 :]:
            if not re.match(r'^\".*\"$', continuation):
                break
            pieces.append(continuation)
        try:
            return "".join(ast.literal_eval(piece) for piece in pieces)
        except (SyntaxError, ValueError):
            # Several inherited catalogs contain literal, unescaped quote
            # characters inside a translated string. gettext tooling already
            # owns syntax validation; coverage reporting must remain useful
            # while it points at those legacy catalogs instead of crashing.
            escapes = {"n": "\n", "r": "\r", "t": "\t", '"': '"', "\\": "\\"}

            def permissive_unquote(piece: str) -> str:
                inner = piece[1:-1]
                return re.sub(
                    r'\\([nrt"\\])',
                    lambda found: escapes[found.group(1)],
                    inner,
                )

            return "".join(permissive_unquote(piece) for piece in pieces)
    return None


def parse_po(path: Path) -> tuple[dict[str, str], list[str]]:
    entries: list[tuple[str, str]] = []
    for block in re.split(r"\r?\n\s*\r?\n", path.read_text(encoding="utf-8")):
        lines = [line.rstrip("\r") for line in block.splitlines() if line]
        msgid = po_value(lines, "msgid")
        if msgid is None or msgid == "":
            continue
        msgstr = po_value(lines, "msgstr")
        entries.append((msgid, msgstr or ""))

    counts = Counter(msgid for msgid, _ in entries)
    duplicates = sorted(msgid for msgid, count in counts.items() if count > 1)
    return dict(entries), duplicates


def parse_pascal_resourcestrings(text: str) -> dict[str, str]:
    """Evaluate the string-only constant expressions in msgstr.pas."""
    start = re.search(r"^resourcestring\s*$", text, re.MULTILINE | re.IGNORECASE)
    end = re.search(r"^implementation\s*$", text, re.MULTILINE | re.IGNORECASE)
    if not start or not end or end.start() <= start.end():
        raise ValueError("could not locate msgstr.pas resourcestring section")
    section = text[start.end() : end.start()]
    declarations = list(
        re.finditer(r"^\s*(STR_[A-Z0-9_]+)\s*=", section, re.MULTILINE | re.IGNORECASE)
    )

    def evaluate(expression: str, name: str) -> str:
        value: list[str] = []
        index = 0
        while index < len(expression):
            char = expression[index]
            if char.isspace() or char == "+":
                index += 1
                continue
            if expression.startswith("//", index):
                newline = expression.find("\n", index)
                index = len(expression) if newline < 0 else newline + 1
                continue
            if char == ";":
                return "".join(value)
            if char == "'":
                index += 1
                while index < len(expression):
                    if expression[index] != "'":
                        value.append(expression[index])
                        index += 1
                    elif index + 1 < len(expression) and expression[index + 1] == "'":
                        value.append("'")
                        index += 2
                    else:
                        index += 1
                        break
                else:
                    raise ValueError(f"unterminated Pascal string in {name}")
                continue
            if char == "#":
                match = re.match(r"#([0-9]+)", expression[index:])
                if not match:
                    raise ValueError(f"bad character code in {name}")
                value.append(chr(int(match.group(1))))
                index += len(match.group(0))
                continue
            if expression[index : index + len("LineEnding")].lower() == "lineending":
                # The shipped GUI/catalog is Windows; Lazarus extracts CRLF.
                value.append("\r\n")
                index += len("LineEnding")
                continue
            token = expression[index : index + 24].splitlines()[0]
            raise ValueError(f"unsupported resourcestring expression in {name}: {token!r}")
        raise ValueError(f"resourcestring {name} has no terminating semicolon")

    result: dict[str, str] = {}
    for position, declaration in enumerate(declarations):
        expression_end = (
            declarations[position + 1].start()
            if position + 1 < len(declarations)
            else len(section)
        )
        name = declaration.group(1).lower()
        result[name] = evaluate(section[declaration.end() : expression_end], name)
    return result


def suite_names(text: str, windows: bool) -> list[str]:
    if windows:
        return re.findall(r'Run-Suite\s+"([A-Za-z0-9_]+)"', text)
    return re.findall(r"^\s*run_suite\s+([A-Za-z0-9_]+)\s", text, re.MULTILINE)


def main() -> int:
    failures: list[str] = []

    try:
        app_version = require_match(
            r"PROX_VERSION\s*=\s*'([0-9.]+)'", read("software/appver.pas"),
            "PROX_VERSION",
        )
        lpi_text = read("software/AsProgrammer.lpi")
        lpi_version = require_match(
            r'ProductVersion="([0-9.]+)"', lpi_text,
            "Lazarus ProductVersion",
        )
        lpi_file_version = ".".join(
            require_match(pattern, lpi_text, label)
            for pattern, label in (
                (r'<MajorVersionNr Value="([0-9]+)"', "Lazarus major version"),
                (r'<MinorVersionNr Value="([0-9]+)"', "Lazarus minor version"),
                (r'<RevisionNr Value="([0-9]+)"', "Lazarus revision"),
                (r'<BuildNr Value="([0-9]+)"', "Lazarus build number"),
            )
        )
        readme = read("README.md")
        if "img.shields.io/github/v/release/patnawa/Chipwright" not in readme:
            raise ValueError("README must use the repository-backed latest-release badge")
        changelog_version = require_match(
            r"^##\s+([0-9.]+)\b", read("CHANGELOG.md"),
            "newest CHANGELOG version",
        )
        versions = {
            "software/appver.pas": app_version,
            "software/AsProgrammer.lpi ProductVersion": lpi_version,
            "software/AsProgrammer.lpi FileVersion": lpi_file_version,
            "CHANGELOG newest entry": changelog_version,
        }
        if len(set(versions.values())) != 1:
            failures.append(
                "version drift: " + ", ".join(f"{name}={value}" for name, value in versions.items())
            )
        print(f"version: {app_version}")
    except (OSError, UnicodeError, ValueError) as exc:
        failures.append(str(exc))

    try:
        workflow = read(".github/workflows/build.yml")
        publish_job = re.search(
            r"^  publish:\s*$([\s\S]*?)(?=^  [A-Za-z0-9_-]+:\s*$|\Z)",
            workflow,
            re.MULTILINE,
        )
        if not publish_job:
            raise ValueError("build workflow has no publish job")
        if not re.search(
            r"^    environment:\s*github-release\s*$",
            publish_job.group(1),
            re.MULTILINE,
        ):
            failures.append(
                "privileged publish job must use the protected github-release environment"
            )
        print("release control: publish job is bound to github-release")
    except (OSError, UnicodeError, ValueError) as exc:
        failures.append(str(exc))

    try:
        windows_suites = suite_names(read("tools/build.ps1"), windows=True)
        posix_suites = suite_names(read("tools/build.sh"), windows=False)
        docs = read("docs/testing.md")
        marker = re.search(
            r"<!-- suite-catalog:start -->(.*?)<!-- suite-catalog:end -->",
            docs,
            re.DOTALL,
        )
        if not marker:
            raise ValueError("docs/testing.md has no suite catalog markers")
        documented_suites = re.findall(r"^- `([A-Za-z0-9_]+)`", marker.group(1), re.MULTILINE)

        for label, names in (
            ("tools/build.ps1", windows_suites),
            ("tools/build.sh", posix_suites),
            ("docs/testing.md", documented_suites),
        ):
            duplicates = [name for name, count in Counter(names).items() if count > 1]
            if duplicates:
                failures.append(f"duplicate suites in {label}: {', '.join(sorted(duplicates))}")

        win_set = set(windows_suites)
        posix_set = set(posix_suites)
        doc_set = set(documented_suites)
        if win_set != posix_set:
            failures.append(
                "platform suite drift: Windows-only="
                f"{sorted(win_set - posix_set)}, POSIX-only={sorted(posix_set - win_set)}"
            )
        if doc_set != win_set:
            failures.append(
                "suite documentation drift: undocumented="
                f"{sorted(win_set - doc_set)}, stale={sorted(doc_set - win_set)}"
            )
        if "AsProgrammerCLI" not in docs or "ch347smoke" not in docs:
            failures.append("docs/testing.md must document the headless CLI and CH347 smoke compile checks")
        print(f"suite catalog: {len(win_set)} suites agree across Windows, POSIX, and docs")
    except (OSError, UnicodeError, ValueError) as exc:
        failures.append(str(exc))

    coverage_lines = [
        "### Localization coverage",
        "",
        "Reference: `software/lang/en.po` message IDs. Missing translations are reported, not failed.",
        "",
        "| Catalog | Translated | Coverage | Missing | Extra | Duplicate IDs |",
        "|---|---:|---:|---:|---:|---:|",
    ]
    try:
        catalogs: dict[str, dict[str, str]] = {}
        duplicate_counts: dict[str, int] = {}
        for path in sorted((ROOT / "software/lang").glob("*.po")):
            messages, duplicates = parse_po(path)
            catalogs[path.name] = messages
            duplicate_counts[path.name] = len(duplicates)

        reference = set(catalogs["en.po"])
        if not reference:
            failures.append("software/lang/en.po contains no translatable messages")

        resources = parse_pascal_resourcestrings(read("software/msgstr.pas"))
        en_po_text = read("software/lang/en.po")
        catalog_resource_names = {
            name.lower()
            for name in re.findall(r"msgstr[.:](str_[A-Za-z0-9_]+)", en_po_text)
        }
        source_resource_names = set(resources)
        if catalog_resource_names != source_resource_names:
            failures.append(
                "resourcestring catalog drift: missing references="
                f"{sorted(source_resource_names - catalog_resource_names)}, "
                f"stale references={sorted(catalog_resource_names - source_resource_names)}"
            )
        missing_values = sorted(
            name for name, value in resources.items() if value not in reference
        )
        if missing_values:
            failures.append(
                "en.po does not represent current msgstr.pas values: "
                + ", ".join(missing_values)
            )
        print(
            f"resourcestring catalog: {len(resources)} source values represented by en.po"
        )

        for name, messages in catalogs.items():
            present = reference & set(messages)
            translated = sum(1 for msgid in present if messages[msgid].strip())
            percent = (100.0 * translated / len(reference)) if reference else 0.0
            missing = len(reference - set(messages))
            extra = len(set(messages) - reference)
            coverage_lines.append(
                f"| `{name}` | {translated}/{len(reference)} | {percent:.1f}% | "
                f"{missing} | {extra} | {duplicate_counts[name]} |"
            )
        print("\n".join(coverage_lines))
    except (OSError, UnicodeError, ValueError, KeyError) as exc:
        failures.append(f"localization report failed: {exc}")

    summary_path = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary_path:
        with open(summary_path, "a", encoding="utf-8") as summary:
            summary.write("\n".join(coverage_lines) + "\n")

    if failures:
        for failure in failures:
            print(f"FAILED: {failure}", file=sys.stderr)
        return 1
    print("metadata checks passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
