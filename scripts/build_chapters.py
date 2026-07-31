#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
为《Beyond Formulas》生成单章编译入口与过滤后的外部标签 aux。

用法：
    python scripts/build_chapters.py --list
    python scripts/build_chapters.py --chapter ch:004
    python scripts/build_chapters.py --all
"""

import argparse
import json
import re
import sys
from pathlib import Path

HYPERREF_RE = re.compile(r"^\s*\\usepackage\s*\{[^}]*hyperref[^}]*\}")
PART_RE = re.compile(r"^\s*\\part\s*\{(?P<title>[^}]+)\}")
CHAPTER_RE = re.compile(r"^\s*\\chapter\s*\*\s*\{(?P<title>[^}]+)\}")
CH_LABEL_RE = re.compile(r"\\phantomsection\s*\\label\s*\{\s*(ch:\d+)\s*\}")
INPUT_RE = re.compile(r"\\input\s*\{\s*(tex/[^}]+)\s*\}")
LABEL_RE = re.compile(r"\\label\s*\{\s*([^}]+)\s*\}")
NEWLABEL_RE = re.compile(r"^\s*\\newlabel\s*\{\s*([^}]+)\s*\}")

# Windows 文件名非法字符
UNSAFE_FILENAME_CHARS = re.compile(r'[\\/:*?"<>|]')


def read_lines(path: Path) -> list[str]:
    return path.read_text(encoding="utf-8").splitlines()


def parse_main_tex(root: Path):
    """解析 main.tex，返回 (preamble_lines, chapters)。"""
    main_tex = root / "main.tex"
    if not main_tex.exists():
        sys.exit(f"错误：找不到 {main_tex}")

    lines = read_lines(main_tex)
    try:
        doc_begin = next(i for i, line in enumerate(lines) if line.strip() == r"\begin{document}")
    except StopIteration:
        sys.exit("错误：main.tex 中找不到 \\begin{document}")

    preamble_lines = lines[:doc_begin]
    body_lines = lines[doc_begin + 1 :]

    chapters = []
    current_part = None
    part_index = 0
    i = 0
    n = len(body_lines)

    while i < n:
        line = body_lines[i]

        m_part = PART_RE.match(line)
        if m_part:
            part_index += 1
            current_part = {"index": part_index, "title": m_part.group("title").strip()}
            i += 1
            continue

        m_ch = CHAPTER_RE.match(line)
        if m_ch:
            title = m_ch.group("title").strip()
            block_lines = [line]
            label = None
            j = i + 1
            while j < n:
                l = body_lines[j]
                if CHAPTER_RE.match(l) or PART_RE.match(l) or l.strip() == r"\end{document}":
                    break
                block_lines.append(l)
                if label is None:
                    m_label = CH_LABEL_RE.search(l)
                    if m_label:
                        label = m_label.group(1)
                j += 1

            inputs = INPUT_RE.findall("\n".join(block_lines))
            chapters.append(
                {
                    "title": title,
                    "label": label,
                    "part": current_part,
                    "block_lines": block_lines,
                    "inputs": inputs,
                }
            )
            i = j
            continue

        i += 1

    return preamble_lines, chapters


def collect_local_labels(chapter: dict, root: Path) -> set[str]:
    """收集本章定义的所有标签：章标签 + 所有 input 文件里的 \\label{}。"""
    labels = set()
    if chapter.get("label"):
        labels.add(chapter["label"])

    for inp in chapter.get("inputs", []):
        p = root / inp
        if not p.exists():
            continue
        text = p.read_text(encoding="utf-8")
        for m in LABEL_RE.finditer(text):
            labels.add(m.group(1).strip())

    return labels


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


def chapter_pdf_name(chapter: dict) -> str:
    label_part = chapter["label"].replace(":", "")
    title = safe_filename(chapter["title"])
    if chapter.get("part"):
        return f"P{chapter['part']['index']:02d}-{label_part}-{title}.pdf"
    return f"{label_part}-{title}.pdf"


def chapter_tex_name(chapter: dict) -> str:
    return chapter["label"].replace(":", "") + ".tex"


def write_filtered_aux(main_aux: Path, local_labels: set[str], out_aux: Path):
    """从 main.aux 中剔除本地标签，生成外部引用 aux。"""
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


def write_wrapper(chapter: dict, preamble_lines: list[str], root: Path, build_dir: Path) -> Path:
    """生成单章编译入口，放在仓库根目录以保持 \\input 相对路径不变。"""
    tex_name = chapter_tex_name(chapter)
    wrapper_path = root / tex_name
    aux_rel = build_dir / f"main-for-{chapter['label'].replace(':', '')}"
    try:
        aux_stem = str(aux_rel.relative_to(root).as_posix())
    except ValueError:
        aux_stem = str(aux_rel.as_posix())

    modified_preamble = make_xr_preamble(preamble_lines, aux_stem)

    body = [r"\begin{document}"]
    if chapter.get("part"):
        body.append(f"\\part{{{chapter['part']['title']}}}")
    body.extend(chapter["block_lines"])
    body.append(r"\end{document}")

    wrapper_path.write_text("\n".join(modified_preamble + body) + "\n", encoding="utf-8")
    return wrapper_path


def generate_chapter(chapter: dict, preamble_lines: list[str], root: Path, build_dir: Path, main_aux: Path):
    local_labels = collect_local_labels(chapter, root)
    aux_path = build_dir / f"main-for-{chapter['label'].replace(':', '')}.aux"
    write_filtered_aux(main_aux, local_labels, aux_path)
    wrapper_path = write_wrapper(chapter, preamble_lines, root, build_dir)
    return {
        "label": chapter["label"],
        "title": chapter["title"],
        "part_index": chapter["part"]["index"] if chapter.get("part") else None,
        "part_title": chapter["part"]["title"] if chapter.get("part") else None,
        "wrapper": wrapper_path.name,
        "pdf": chapter_pdf_name(chapter),
        "inputs": chapter["inputs"],
    }


def find_chapter(chapters: list[dict], query: str) -> dict:
    if query.startswith("ch:"):
        matches = [c for c in chapters if c["label"] == query]
    else:
        matches = [c for c in chapters if query in c["title"]]

    if not matches:
        sys.exit(f"错误：找不到匹配的章节：{query}")
    if len(matches) > 1:
        print(f"错误：'{query}' 匹配到多个章节：")
        for c in matches:
            print(f"  {c['label']}  {c['title']}")
        sys.exit(1)
    return matches[0]


def main():
    parser = argparse.ArgumentParser(description="生成 Beyond Formulas 单章编译入口")
    parser.add_argument("--root", type=Path, default=Path.cwd(), help="仓库根目录（默认当前目录）")
    parser.add_argument("--build-dir", type=Path, default=None, help="中间文件目录（默认 root/build）")
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--list", action="store_true", help="列出所有章节")
    group.add_argument("--chapter", type=str, help="生成指定章（如 ch:004 或标题关键词）")
    group.add_argument("--all", action="store_true", help="生成全部章节入口与 manifest")
    args = parser.parse_args()

    root = args.root.resolve()
    build_dir = (args.build_dir or root / "build").resolve()
    main_aux = root / "main.aux"

    preamble_lines, chapters = parse_main_tex(root)

    if args.list:
        print(f"共 {len(chapters)} 章：")
        for c in chapters:
            part = c["part"]["title"] if c.get("part") else "（无 Part）"
            print(f"  {c['label']:8}  [{part}]  {c['title']}")
        return

    if args.chapter:
        if not main_aux.exists():
            sys.exit(f"错误：{main_aux} 不存在。请先编译完整书：xelatex main.tex（两遍）")
        chapter = find_chapter(chapters, args.chapter)
        info = generate_chapter(chapter, preamble_lines, root, build_dir, main_aux)
        print(f"已生成：{info['wrapper']} -> {info['pdf']}")
        print("META:" + json.dumps(info, ensure_ascii=True))
        print(f"外部 aux：{build_dir / ('main-for-' + chapter['label'].replace(':', '') + '.aux')}")
        return

    if args.all:
        if not main_aux.exists():
            sys.exit(f"错误：{main_aux} 不存在。请先编译完整书：xelatex main.tex（两遍）")
        build_dir.mkdir(parents=True, exist_ok=True)
        manifest = []
        for chapter in chapters:
            info = generate_chapter(chapter, preamble_lines, root, build_dir, main_aux)
            manifest.append(info)
            print(f"已生成：{info['wrapper']} -> {info['pdf']}")

        manifest_path = build_dir / "chapters-manifest.json"
        manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(f"\nmanifest 已写入：{manifest_path}")
        return


if __name__ == "__main__":
    main()
