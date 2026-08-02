#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Mark the current 篇's part (and unit, if listed) as reviewed in docs/review.md.

Read-only against tex/; edits only docs/review.md. The unit rows in that file
carry (NN-UnitDir) markers so the script can locate them without parsing titles.

Usage:
    python scripts/mark_reviewed.py --file tex/02-Calculus/03-Differentiation/05-linear-approx.tex
"""

import argparse
import re
import sys
from pathlib import Path


CHECKBOX_RE = re.compile(r"^(?P<indent>.*-)\s*\[(?P<mark>[ x~])\](?P<rest>.*)$")


def mark_line(line: str) -> bool:
    m = CHECKBOX_RE.match(line)
    if not m:
        return False
    new_line = line[: m.start("mark")] + "x" + line[m.end("mark"):]
    if new_line == line:
        return False
    print(f"marked: {line.strip()}")
    return True


def apply_line(line: str, needle: str) -> bool:
    if needle in line:
        return mark_line(line)
    return False


def main():
    parser = argparse.ArgumentParser(description="Mark a section as reviewed")
    parser.add_argument("--root", type=Path, default=Path.cwd())
    parser.add_argument("--file", required=True, help="section .tex file")
    args = parser.parse_args()

    root = args.root.resolve()
    raw = Path(args.file)
    target = raw if raw.is_absolute() else (root / raw)
    target = target.resolve()
    try:
        rel = target.relative_to(root)
    except ValueError:
        sys.exit(f"error: file is outside the repo: {target}")
    posix = rel.as_posix()
    if not posix.startswith("tex/") or posix.count("/") < 3:
        sys.exit("error: expected a section under tex/<part>/<unit>/")

    parts = posix.split("/")
    part_dir = parts[1]
    unit_dir = parts[2]
    part_num = part_dir[:2]

    review_path = root / "docs" / "review.md"
    if not review_path.exists():
        sys.exit(f"error: {review_path} not found")

    updated = False
    lines = review_path.read_text(encoding="utf-8").splitlines()
    for i, line in enumerate(lines):
        if CHECKBOX_RE.match(line) and re.search(
            rf"(?<=\s){part_num}(?:\s|$)", line
        ):
            if mark_line(line):
                updated = True
                lines[i] = re.sub(
                    r"(^-\s*\[)[ x~](\])",
                    r"\g<1>x\2",
                    lines[i],
                )
            break

    for i, line in enumerate(lines):
        if f"（{unit_dir}）" in line and CHECKBOX_RE.match(line):
            if mark_line(line):
                updated = True
                lines[i] = re.sub(
                    r"(^-\s*\[)[ x~](\])",
                    r"\g<1>x\2",
                    lines[i],
                )
            break

    if not updated:
        print(f"no change: {posix} (already marked)")
        return

    review_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"updated: {posix}")


if __name__ == "__main__":
    main()
