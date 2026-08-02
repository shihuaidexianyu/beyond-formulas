#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Style checks for a single 篇 tex file.

Reuses the project's documented source conventions and reports line-level hits
so they can be fixed inside VS Code. Reads only, never modifies files.

Usage:
    python scripts/check_section.py --file tex/01-Mathematical-Language/01-Logic/03-quantifiers.tex
"""

import argparse
import re
import sys
from pathlib import Path


DOLLAR_RE = re.compile(r"(?<!\\)\$")
TOPRIME_RE = re.compile(r"\^\\top")
MATHFONT_RE = re.compile(r"\^\{?\s*\\mathsf|\\mathbb")
BARE_T_RE = re.compile(r"(?<!\\)\^T")
PR_RE = re.compile(r"\\Pr(?![a-zA-Z])")
QUOTE_RE = re.compile(r"[\u201c\u201d]")
STRAIGHT_QUOTE_RE = re.compile(r'"')
ITEMS_RE = re.compile(r"\\begin\{itemize\}")
ENUM_RE = re.compile(r"\\begin\{enumerate\}")


def is_comment_line(line: str) -> bool:
    return line.strip().startswith("%")


def has_unescaped_percent(line: str) -> bool:
    for i, ch in enumerate(line):
        if ch == "%" and (i == 0 or line[i - 1] != "\\"):
            return True
    return False


def check_file(path: Path) -> list[tuple[int, str]]:
    lines = path.read_text(encoding="utf-8").splitlines()
    issues: list[tuple[int, str]] = []

    for idx, line in enumerate(lines, start=1):
        if is_comment_line(line):
            continue

        if DOLLAR_RE.search(line):
            issues.append((idx, "unescaped $ (use \\(...\\) / \\[...\\])"))
        if TOPRIME_RE.search(line):
            issues.append((idx, "\\top found (use ^{\\trans})"))
        if MATHFONT_RE.search(line):
            issues.append((idx, "\\mathsf/\\mathbb found (use book macros)"))
        if BARE_T_RE.search(line):
            issues.append((idx, "bare ^T transpose found (use ^{\\trans})"))
        if PR_RE.search(line):
            issues.append((idx, "\\Pr found (use italic P)"))
        if QUOTE_RE.search(line):
            issues.append((idx, "curly quotes found (use ``...'' )"))
        if STRAIGHT_QUOTE_RE.search(line):
            issues.append((idx, "straight double quote found"))
        if has_unescaped_percent(line):
            issues.append((idx, "unescaped % found (use \\%)"))

    non_comment = [ln for ln in lines if ln.strip() and not is_comment_line(ln)]
    if non_comment:
        last = non_comment[-1].strip()
        item_env_count = len(ITEMS_RE.findall("\n".join(lines)))
        enum_env_count = len(ENUM_RE.findall("\n".join(lines)))
        if last.startswith("\\end{itemize}") and item_env_count == 1 and enum_env_count == 0:
            issues.append((len(lines), "section ends on a single itemize"))

    return issues


def main():
    parser = argparse.ArgumentParser(description="Check one Beyond Formulas section")
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

    if not rel.as_posix().startswith("tex/") or rel.suffix != ".tex":
        sys.exit("error: expected a .tex file under tex/")

    issues = check_file(target)
    if not issues:
        print(f"OK: {rel.as_posix()}")
        return

    print(f"{len(issues)} issue(s) in {rel.as_posix()}:")
    for lineno, message in issues:
        print(f"  {rel.as_posix()}:{lineno}: {message}")
    sys.exit(1)


if __name__ == "__main__":
    main()
