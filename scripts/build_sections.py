#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
为《Beyond Formulas》生成“当前篇”的独立编译入口。

不修改任何 tex/ 正文：临时入口放在仓库根目录，复用 main.tex 的前言与宏，
并导入根目录 main.aux 的外部标签，使篇内交叉引用文字/页码尽量正确。
只编译打开的单个篇文件，避免每次改动都编译整本书。

用法：
    python scripts/build_sections.py --file tex/01-Mathematical-Language/01-Logic/03-量词与否定.tex
"""

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path

HYPERREF_RE = re.compile(r"^\s*\\usepackage\s*\{[^}]*hyperref[^}]*\}")
LABEL_RE = re.compile(r"\\label\s*\{\s*([^}]+)\s*\}")
NEWLABEL_RE = re.compile(r"^\s*\\newlabel\s*\{\s*([^}]+)\s*\}")
UNSAFE_FILENAME_CHARS = re.compile(r'[\\/:*?"<>|]')


def read_lines(path: Path) -> list[str]:
    return path.read_text(encoding="utf-8").splitlines()


def parse_preamble(root: Path) -> list[str]:
    main_tex = root / "main.tex"
    lines = read_lines(main_tex)
    try:
        doc_begin = next(
            i for i, line in enumerate(lines) if line.strip() == r"\begin{document}"
        )
    except StopIteration:
        sys.exit("错误：main.tex 中找不到 \\begin{document}")
    return lines[:doc_begin]


def make_xr_preamble(preamble_lines: list[str], aux_stem: str) -> list[str]:
    """在 hyperref 后插入 xr-hyper 与 \\externaldocument{}。"""
    new_lines = []
    inserted = False
    for line in preamble_lines:
        new_lines.append(line)
        if not inserted and HYPERREF_RE.match(line):
            new_lines.append(r"\usepackage{xr-hyper}")
            # 使用正斜杠，TeX 在 Windows 下也接受
            new_lines.append(rf"\externaldocument{{{aux_stem}}}")
            inserted = True
    return new_lines


def safe_filename(text: str) -> str:
    # 保留中文字符，仅去掉 Windows 文件名非法字符
    return UNSAFE_FILENAME_CHARS.sub("-", text).strip()


def resolve_target(root: Path, arg: str) -> str:
    """把用户给的路径规约为仓库内的 tex/ 相对路径（正斜杠）。"""
    raw = Path(arg)
    if raw.is_absolute():
        candidate = raw.resolve()
        try:
            rel = candidate.relative_to(root.resolve())
        except ValueError:
            sys.exit(f"错误：文件不在仓库内：{arg}")
    else:
        rel = (root.resolve() / raw).resolve().relative_to(root.resolve())

    posix = rel.as_posix()
    if not posix.startswith("tex/"):
        sys.exit("错误：请指定 tex/ 目录下的内容篇文件。")
    if rel.suffix != ".tex" or rel.name == "macros.tex":
        sys.exit("错误：请指定一个篇 .tex 文件。")
    if not (root / rel).exists():
        sys.exit(f"错误：文件不存在：{rel}")
    return posix


def write_filtered_aux(main_aux: Path, local_labels: set[str], out_aux: Path) -> None:
    """从 main.aux 中剔除目标篇自己的标签，避免重复定义。"""
    lines = read_lines(main_aux)
    out_lines = []
    for line in lines:
        m = NEWLABEL_RE.match(line)
        if m:
            label = m.group(1).strip()
            if label in local_labels:
                continue
        out_lines.append(line)
    out_aux.parent.mkdir(parents=True, exist_ok=True)
    out_aux.write_text("\n".join(out_lines) + "\n", encoding="utf-8")


def collect_local_labels(target: str, root: Path) -> set[str]:
    labels = set()
    text = (root / target).read_text(encoding="utf-8")
    for m in LABEL_RE.finditer(text):
        labels.add(m.group(1).strip())
    return labels


def main():
    parser = argparse.ArgumentParser(description="生成 Beyond Formulas 当前篇编译入口")
    parser.add_argument("--root", type=Path, default=Path.cwd(), help="仓库根目录（默认当前目录）")
    parser.add_argument("--build-dir", type=Path, default=None, help="中间文件目录（默认 root/build）")
    parser.add_argument("--meta", type=Path, default=None, help="写出机器可读 JSON 的路径")
    parser.add_argument("--file", required=True, help="要编译的篇 tex 文件")
    args = parser.parse_args()

    root = args.root.resolve()
    build_dir = (args.build_dir or root / "build").resolve()
    target = resolve_target(root, args.file)

    main_aux = root / "main.aux"
    if not main_aux.exists():
        sys.exit(
            "错误：没有 root/main.aux。请先完整编译一次（两遍 xelatex main.tex，"
            "或运行 .\\scripts\\build_chapters.ps1 -Full）。"
        )

    digest = hashlib.sha256(target.encode("utf-8")).hexdigest()[:8]
    wrapper_name = f"_sec_{digest}.tex"
    aux_stem = (build_dir / f"main-for-{digest}").relative_to(root).as_posix()

    local_labels = collect_local_labels(target, root)
    aux_path = build_dir / f"main-for-{digest}.aux"
    write_filtered_aux(main_aux, local_labels, aux_path)

    preamble = make_xr_preamble(parse_preamble(root), aux_stem)
    body = [r"\begin{document}", rf"\input{{{target}}}", r"\end{document}"]
    wrapper_path = root / wrapper_name
    wrapper_path.write_text("\n".join(preamble + body) + "\n", encoding="utf-8")

    rel = Path(target).with_suffix("")
    stub = rel.as_posix()
    if stub.startswith("tex/"):
        stub = stub[len("tex/"):]
    pdf_name = "sec-" + safe_filename(stub.replace("/", "-")) + ".pdf"
    info = {"wrapper": wrapper_name, "pdf": pdf_name, "target": target}
    if args.meta:
        meta_path = args.meta.resolve()
        meta_path.parent.mkdir(parents=True, exist_ok=True)
        meta_path.write_text(json.dumps(info, ensure_ascii=False), encoding="utf-8")
    print(f"生成：{wrapper_name} -> {pdf_name}")


if __name__ == "__main__":
    main()
