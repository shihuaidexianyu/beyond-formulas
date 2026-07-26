# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

**Beyond Formulas**（《从公式到结构、判断与可信计算》）is a Chinese-language mathematics knowledge framework written in LaTeX (`ctexbook`). It spans mathematical language, calculus, linear algebra, discrete math, probability, stochastic processes, information theory, numerical analysis, convex optimization, matrix calculus, mathematical statistics, real analysis, machine learning, deep learning, dynamical systems, and control/RL.

There is no package manager, no build system, and no test suite — the entire project is LaTeX prose. Current scale: 17 `\part`s, 139 `\chapter*`s, ~609 `.tex` files under `tex/`, ~1500 PDF pages.

**Entry point**: `main.tex`

## Build and validate

From the repo root:

```powershell
xelatex -interaction=nonstopmode main.tex
xelatex -interaction=nonstopmode main.tex
```

Two passes are required to stabilize the TOC and `\hyperref` cross-references. Or `latexmk -xelatex main.tex`.

**There is no per-file build.** Sections are pulled in with `\input` (not `\include`), so `\includeonly` is unavailable — the only way to check a single edited section is a full compile.

After compiling, the validation gate is:

```powershell
Select-String -Path main.log -Pattern 'Undefined control sequence|LaTeX Warning: Reference|LaTeX Warning: There were undefined'
```

Zero errors and zero undefined references is the pass condition.

### Style scanners

`tmp/readability/scan_*.py` are read-only Python scanners that check the source conventions below (unescaped `%`, `$...$`, curly quotes, `^\top`, `\Pr`, macro-glue artifacts, tail-bullet endings, oversized `\norm`). Run from the repo root:

```powershell
python tmp/readability/scan_artifacts.py    # 综合扫描：宏粘连 / \mathbb / ^\top / “” / $ / \Pr
python tmp/readability/scan_percent.py      # 未转义的 %（会吞掉行尾）
python tmp/readability/scan_tail_bullets.py # 以单条 itemize 结尾的篇
```

`tmp/readability/apply_*.py` and `fix_*.py` are one-shot batch rewriters from past migrations — read before reusing; they mutate `tex/` in place.

### Structural check

Every section file must be reachable from `main.tex`. Two files currently on disk are *not* `\input` anywhere (`13-Machine-Learning/11-Information-Theoretic-Learning/02-…`, `16-Control-and-Reinforcement-Learning/01-Classical-Control/04-Kalman滤波…`) — they do not appear in the book. When adding a file, adding it to `main.tex` is not optional; diff the `\input{...}` set against `tex/**/*.tex` if unsure.

## Architecture

### `main.tex` is the single source of structure

`main.tex` holds the preamble (all packages — subfiles never `\usepackage`), `\input{tex/macros.tex}`, the theorem environments, and then the entire book skeleton as a flat sequence of chapter blocks. Content files contain no structural metadata beyond their own `\section`.

```
tex/macros.tex                # global math macros (\providecommand only)
tex/00-MOC.tex                # whole-book intro          → ch:001
tex/知识地图.tex               # knowledge map             → ch:002
tex/学习路线.tex               # learning paths            → ch:003
tex/问题索引.tex               # problem index             → ch:138
tex/洞见索引.tex               # insight index             → ch:139
tex/01-Mathematical-Language/ … tex/17-References/
```

Each `tex/NN-Subject/` is a **Part**; each subdirectory inside it is a **unit = one book chapter**; each `NN-中文标题.tex` inside a unit is a **篇 (section)**.

Two chapter-block shapes appear in `main.tex`, and the difference matters:

```latex
\part{微积分}
\chapter*{微积分：局部变化怎样累积成整体}   % Part 导读 — NO \addcontentsline (stays out of the TOC)
\phantomsection\label{ch:009}
\input{tex/02-Calculus/00-MOC.tex}
\clearpage

\chapter*{函数与预备知识：先看清什么量依赖什么量}  % unit chapter — HAS \addcontentsline
\phantomsection\label{ch:010}
\addcontentsline{toc}{chapter}{函数与预备知识：先看清什么量依赖什么量}
\input{tex/02-Calculus/01-Functions-and-Precalculus/00-MOC.tex}
\input{tex/02-Calculus/01-Functions-and-Precalculus/01-从实数轴到函数.tex}
\clearpage
```

Chapter titles live **only** in `main.tex` — renaming a unit means editing that `\chapter*` + `\addcontentsline` pair (the `ch:NNN` label need not change). `ch:NNN` is a three-digit number that must be unique but need not be consecutive; pick any unused one.

### Numbering and navigation model

- `\setcounter{secnumdepth}{0}` — nothing is numbered, anywhere.
- `\setcounter{tocdepth}{0}` — the printed TOC lists chapters only, while `bookmarksdepth=1` makes PDF bookmarks reach 篇 level. That asymmetry is deliberate: readers locate sections via bookmarks without inflating the paper TOC.
- Theorem environments (`definition` 定义, `theorem` 定理, `proposition` 命题, `lemma` 引理, `example` 例, `remark` 注记) are all `\newtheorem*` — unnumbered, consistent with the above.

### Labels and cross-references

- Unit `00-MOC.tex` files **must not** open with `\section{...}` — the 导读 text runs directly under the chapter title from `main.tex`. Same for Part-level `00-MOC.tex`.
- 篇 files open with `\section{...}` and a `\label` on the **next line**, mirroring the full directory path:
  ```latex
  \section{全概率公式与 Bayes 更新}
  \label{sec:05-Probability/02-Conditional-Probability/02}
  ```
- Inside a 篇, use `\subsection`; avoid `\subsubsection`.
- Same-unit references use prose (“上一节 / 下一节 / 本节”). Cross-unit references **must** be wrapped: ``\hyperref[ch:NNN]{``章标题''}`` or ``\hyperref[sec:...]{``篇名''}``. A bare quoted 篇名 with no `\hyperref` is a dead reference and is not acceptable.
- Headings containing math need `\texorpdfstring{数学}{纯文本}` so bookmarks stay clean.

## Source conventions

These are enforced on new and revised material; legacy files migrate opportunistically when touched.

- **Inline math** `\(...\)`, **display math** `\[...\]`. Never `$...$` or `$$...$$`.
- Derivations of two or more steps go in `\[ \begin{aligned} ... \end{aligned} \]` — a long chain inside a single `\[...\]` renders as one overfull line regardless of source newlines.
- Display math carries no Chinese punctuation and no full Chinese sentences (including inside `\text{}` / `\boxed{}`); short quantifier tags like `\qquad\text{对所有 }t\ge0` are fine.
- **Use the macros in `tex/macros.tex`**: `\E \Var \Cov \Corr \Bias \SE \MSE`, `\R \N \Z \Q \C`, `\ind`, `\argmax \argmin`, `\trans \conj`, `\trace \diag \rank \nullsp \rangesp`, `\norm \abs \ip \set \given`, `\sign \relu \softmax \logsumexp`, `\KL \TV`, `\eqdef`. New shared macros go there with `\providecommand` — never `\newcommand` inside a content file. One-off operators use `\operatorname{...}` in place.
- **Transpose is always `^{\trans}`** — never `^\top`, `^{\mathsf T}`, or bare `^T`.
- **Probability is italic `P`** — never `\Pr` or `\mathbb{P}`. (`\Prob` exists as a compatibility alias; do not use it in new text.)
- `%` in prose must be escaped as `\%` (an unescaped one silently swallows the rest of the line); percentages are written `\(95\%\)`.
- Chinese quotes are ``` ``...'' ``` — not `“”` and not `"`.
- Lists: `itemize`/`enumerate` followed by `\tightlist`, at most one nesting level, never used as a substitute for argument. Do not re-emit pandoc's `\def\labelenumi`.
- Tables: `longtable` with `\def\LTcaptype{none}`.
- Files are UTF-8 with LF endings (`.gitattributes` enforces this). Names are `NN-中文标题.tex` — when inserting between existing files, renumber the whole sequence; no `01b` suffixes.

### Known drift

The corpus predates some of these rules. As of now roughly 41 files (concentrated in `tex/07-Information-Theory/`) still use `$...$`, ~96 curly quotes remain, and a handful of `^\top` / `\Pr` sites survive. Fix these in files you are already editing; do not launch unrelated sweeps.

## Content conventions

- No 练习/习题/任务 sections anywhere — understanding is tested through worked demonstrations, counterexamples, and boundary variations instead.
- Each 篇 opens from a problem, a cognitive conflict, or a concrete example — not from a definition. The entry problem and the core insight should land within the first fifth of the text.
- Theorems state which failure mode each hypothesis blocks (“条件对账”), with counterexamples placed adjacent.
- Each 篇 ends either with a transition sentence (what the next 篇 adds or removes) or with a boundary summary (when it fails, what is not guaranteed) — never abruptly, and never on a single-item `itemize`.

## Companion files

- **STYLE_GUIDE.md** — full typographic/writing rules with enforcement levels.
- **AGENTS.md** — long-form guide for AI assistants; authoritative for structural edge cases.
- **TODO.md** — writing philosophy (motivation-first, cognitive conflict, first-principles reconstruction).
- **README.md** — human-facing introduction.

Note: `AGENTS.md`, `STYLE_GUIDE.md`, and `TODO.md` are listed in `.gitignore` and are **not tracked** — they exist in this working copy but will be absent from a fresh clone. This file is therefore written to stand alone for the rules that matter.

`reference-materials/` holds a local, untracked reference library, including `深度学习-sol/` — a sister project with Markdown notes and runnable NumPy/PyTorch code and its own pytest suite (`pytest code/tests` from that directory).
