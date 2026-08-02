#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Print a small progress summary for docs/review.md.

Usage:
    python scripts/review_summary.py
"""

import re
import sys
from pathlib import Path

CHECKBOX_RE = re.compile(r"^\s*-\s*\[([ x~])\]\s*(.*)$")


def main():
    root = Path.cwd()
    path = root / "docs" / "review.md"
    if not path.exists():
        sys.exit(f"error: {path} not found")

    counts = {"x": 0, "~": 0, " ": 0}
    lines = path.read_text(encoding="utf-8").splitlines()
    for line in lines:
        m = CHECKBOX_RE.match(line)
        if not m:
            continue
        key = m.group(1) if m.group(1) != " " else " "
        counts[key] += 1

    total = sum(counts.values())
    pct = round(100 * counts["x"] / total, 1) if total else 0
    print(f"reviewed: {counts['x']}   in-progress: {counts['~']}   todo: {counts[' ']}   total: {total}   ({pct}% done)")
    print("detail: docs/review.md")


if __name__ == "__main__":
    main()
