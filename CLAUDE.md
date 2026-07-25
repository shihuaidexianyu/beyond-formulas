# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

This is **Beyond Formulas** — a Chinese-language mathematics knowledge framework written in LaTeX (`ctexbook`). It covers mathematical language, calculus, linear algebra, discrete math, probability, stochastic processes, information theory, numerical analysis, convex optimization, matrix calculus, mathematical statistics, real analysis, machine learning, deep learning, dynamical systems, and control/reinforcement learning. The compiled book is ~1027 pages across 530 `.tex` source files.

The repository also contains `reference-materials/深度学习-sol/`, a sister project ("Deep Learning: From Formulas to Diagnosable Models") with Markdown notes and executable Python code (NumPy/PyTorch). That sub-project has its own README.

**Entry point**: `main.tex`

## Build / compile

From the repo root:

```powershell
xelatex main.tex
xelatex main.tex
```

Two passes are required to stabilize the table of contents and cross-references. Or use latexmk:

```powershell
latexmk -xelatex main.tex
```

**Prerequisites**: A TeX distribution with XeLaTeX, CTeX, AMS math packages, `longtable`, `enumitem`, `tocloft`, `hyperref`, `booktabs`, `tikz`, and `xcolor`.

## Architecture

```
main.tex                     # Document entry — documentclass, packages, \input chain
tex/macros.tex               # Global math symbol macros (\E, \Var, \R, \trans, etc.)
tex/00-MOC.tex               # Whole-book introduction
tex/学习路线.tex              # Learning path recommendations
tex/知识地图.tex              # Knowledge map
tex/问题索引.tex              # Problem index
tex/洞见索引.tex              # Insight index
tex/01-Mathematical-Language/ # Part 1: logic, sets, proofs, induction
tex/02-Calculus/              # Part 2: limits, derivatives, integrals, series, multivariable
tex/03-Linear-Algebra/        # Part 3: vector spaces, orthogonality, eigenvalues, SVD, tensors
tex/04-Discrete-Mathematics/  # Part 4: combinatorics, recurrences, graphs, number theory, groups
tex/05-Probability/           # Part 5: probability spaces, random variables, common distributions
tex/06-Random-Processes/      # Part 6: counting processes, Markov chains, SDE, ARMA
tex/07-Information-Theory/    # Part 7: entropy, divergences, source/channel coding
tex/08-Numerical-Analysis/    # Part 8: floating point, root finding, interpolation, ODE, FFT
tex/09-Convex-Optimization/   # Part 9: convex sets, duality, algorithms, non-convex
tex/10-Matrix-Calculus/       # Part 10: derivative conventions, differentials, trace calculus
tex/11-Mathematical-Statistics/ # Part 11: estimation, testing, regression, random matrix theory
tex/12-Real-Analysis-Support/ # Part 12: completeness, convergence, measure, Lp, manifolds
tex/13-Machine-Learning/      # Part 13: learning problems, linear models, trees, kernels, PGM
tex/14-Deep-Learning/         # Part 14: backprop, CNNs, RNNs, attention, VAEs, GANs, diffusion
tex/15-Differential-Equations-and-Dynamical-Systems/ # Part 15
tex/16-Control-and-Reinforcement-Learning/ # Part 16
tex/17-References/            # References and recommended materials
```

### How content is organized

- Each subdirectory is a **chapter** (单元), driven by `main.tex` via `\chapter*` + `\input`.
- Each subdirectory contains a `00-MOC.tex` (Map of Content / 导读) and numbered `.tex` files for individual sections.
- **`00-MOC.tex` files must NOT start with `\section{...}`** — the chapter title lives only in `main.tex`'s `\chapter*` line.
- Section `.tex` files start with `\section{...}\label{sec:Part/Unit/NN}`.
- Chapter labels use `ch:NNN` (three-digit, unique, not required to be consecutive).
- Section labels follow the pattern `sec:Part/Unit/NN`.

### Key structural conventions

- **No section numbering**: `\setcounter{secnumdepth}{0}` — all section heads are unnumbered.
- **Table of contents shows chapters only**: `\setcounter{tocdepth}{0}`.
- **Theorem environments are unnumbered**: `definition`, `theorem`, `proposition`, `lemma`, `example`, `remark` (defined in `main.tex` preamble via `amsthm`).
- **Cross-references must use `\hyperref`**: ``\hyperref[ch:NNN]{``章标题''}`` for chapters, ``\hyperref[sec:...]{``篇名''}`` for sections. Bare section names without `\hyperref` are treated as dead references.

## Important conventions (see STYLE_GUIDE.md for full details)

- **Inline math**: `\(...\)` — **never** `$...$`.
- **Display math**: `\[...\]` — **never** `$$...$$`.
- **Multi-step derivations**: use `\[ \begin{aligned} ... \end{aligned} \]`.
- **Matrix transpose**: always `^{\trans}` (from `tex/macros.tex`), never `^\top` or `^T`.
- **Probability**: italic `P` only, never `\Pr` or `\mathbb{P}`.
- **Use macros from `tex/macros.tex`**: `\E`, `\Var`, `\Cov`, `\R`, `\N`, `\Z`, `\ind`, `\argmax`, `\argmin`, `\KL`, `\norm`, `\abs`, `\ip`, `\set`, `\given`, etc. Add new macros there (with `\providecommand`), not in individual files.
- **Chinese quotes**: ``` ``...'' ```, not `""` or `""`.
- **File names**: `NN-中文标题.tex` with two-digit sequence numbers. When inserting between existing files, renumber the whole sequence — no `01b` suffixes.
- **File encoding**: UTF-8 with LF line endings.

## Adding or modifying content

### Adding a new chapter (单元)

1. Create subdirectory under `tex/XX-Subject/YY-New-Unit/` with `00-MOC.tex` and section files.
2. In `main.tex`, add a chapter block before the relevant `\clearpage`:
   ```latex
   \chapter*{单元标题}
   \phantomsection\label{ch:NNN}
   \addcontentsline{toc}{chapter}{单元标题}
   \input{tex/XX-Subject/YY-New-Unit/00-MOC.tex}
   \input{tex/XX-Subject/YY-New-Unit/01-小节标题.tex}
   \clearpage
   ```
3. Pick an unused three-digit number for `ch:NNN`.

### Adding a new section

1. Create `NN-中文标题.tex` in the unit subdirectory, starting with `\section{...}\label{sec:Part/Unit/NN}`.
2. Add `\input{tex/XX-Subject/YY-Unit/NN-中文标题.tex}` in the unit's chapter block in `main.tex`.

### Modifying existing content

- Edit `.tex` files directly.
- Chapter titles are in `main.tex` only — changing a chapter name means updating `main.tex`'s `\chapter*` line.
- After structural changes, run two `xelatex` passes and check for undefined references.

## Validation

- The only "test" is: `xelatex main.tex` must complete with zero errors and no undefined references.
- Check that all `\hyperref` labels point to existing `\label` targets.
- The `reference-materials/深度学习-sol/` sub-project has its own pytest suite: `pytest code/tests` from that directory (Python 3.12, PyTorch, NumPy).

## Companion files

- **AGENTS.md** — comprehensive guide for AI assistants (this file is an abridged reference; AGENTS.md is authoritative for edge cases).
- **STYLE_GUIDE.md** — full typographic and writing style rules with enforcement levels.
- **TODO.md** — writing philosophy and quality principles (motivation-first, cognitive conflict, worked examples, etc.).
- **README.md** — human-oriented project introduction.
