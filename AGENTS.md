# AGENTS.md

> 本文件面向 AI 编程助手。读者应当被视作对该项目一无所知。

## 项目概述

本项目是一份用 LaTeX 编写的中文数学笔记，标题为《数学基础笔记》，目标是为数据科学、机器学习及相关方向提供一条从“会用公式”到“能判断公式为什么成立、什么时候失效、算出的结果是否可信”的学习路径。

项目不是一门编程项目，也不依赖任何包管理器（无 `pyproject.toml`、`package.json`、`Cargo.toml`、`Makefile` 等）。全部源码就是 LaTeX 文件，入口为根目录下的 `main.tex`。

- **入口文件**：`main.tex`
- **内容目录**：`tex/`
- **当前 .tex 文件数量**：441 个（含各章 `00-MOC.tex` 导读文件与 `tex/macros.tex`）
- **主要自然语言**：中文（文档、注释、章节名均使用中文）
- **数学环境**：英文符号与公式

## 技术栈与编译方式

- **文档类**：`ctexbook`（`\documentclass[UTF8,openany]{ctexbook}`），支持中文与 Unicode。
- **推荐编译引擎**：**XeLaTeX**，因为正文包含中文、数学公式和 Unicode 符号。
- **常用宏包**：`geometry`、`amsmath`、`amssymb`、`mathtools`、`booktabs`、`longtable`、`array`、`enumitem`、`xcolor`、`hyperref`。
- **目录与交叉引用**：使用 `hyperref` 生成蓝色链接，依赖两次编译以稳定目录和引用。

### 编译命令

```powershell
cd "C:/Users/exqin/Desktop/数学基础"
xelatex main.tex
xelatex main.tex
```

或使用 `latexmk`：

```powershell
latexmk -xelatex main.tex
```

### 编译产物

默认会在项目根目录生成 `.pdf`、`.aux`、`.log`、`.toc`、`.out`、`.synctex.gz` 等文件。根目录 `.gitignore` 已忽略这些编译产物，以及本地参考资料库、源码备份和工作截图；版本控制只保留可重建文档所需的源码与项目说明。

## 代码与目录组织

内容完全位于 `tex/` 目录下，按学科划分为 16 个“Part”（含 References），每个内容 Part 下再按主题划分子目录。

```
tex/
├── 00-MOC.tex                  # 总入口 / 全书导读
├── 学习路线.tex                 # 学习路线建议
├── 01-Mathematical-Language/    # 数学语言
├── 02-Calculus/                 # 微积分
├── 03-Linear-Algebra/           # 线性代数
│   └── 09-Tensors/              # 张量与张量分解
├── 04-Discrete-Mathematics/     # 离散数学
│   ├── 06-Groups-and-Symmetry/  # 群与对称
│   └── 07-Boolean-Algebra-and-Automata/ # 布尔代数与自动机
├── 05-Probability/              # 概率论
├── 06-Random-Processes/         # 随机过程
├── 07-Information-Theory/       # 信息论
├── 08-Numerical-Analysis/       # 数值分析
├── 09-Convex-Optimization/      # 凸优化
├── 10-Matrix-Calculus/          # 矩阵微积分
├── 11-Mathematical-Statistics/  # 数理统计
├── 12-Real-Analysis-Support/    # 实分析支撑
├── 13-Integrated-Applications/  # 综合应用
├── 14-Differential-Equations-and-Dynamical-Systems/ # 微分方程与动力系统
├── 15-Control-and-Reinforcement-Learning/ # 控制与强化学习
└── 16-References/               # 参考资料
```

### 文件命名约定

- 每个子目录下都有一个 **`00-MOC.tex`**（Map of Content），作为该章/该节的导读或总览。
- 具体小节的文件名形如 `01-命题与逻辑连接词.tex`，以两位数字序号开头，后跟中文标题。
- **一个子目录单元 = 书中的一个章**。`main.tex` 为每个单元调用一次 `\chapter*` 与 `\addcontentsline{toc}{chapter}{...}`，章标题只在这里维护；随后连续 `\input` 该单元的 `00-MOC.tex` 与各篇文件，最后 `\clearpage`。
- 单元 `00-MOC.tex` 的**首行 `\section{...}` 已删除**：导读文字直接作为章首文字出现，章标题只存在于 `main.tex` 的 `\chapter*` 行。
- 单元内各篇文件以 `\section{...}` 开头，渲染为章内小节。**全书不设小节编号**（`\setcounter{secnumdepth}{0}`），**目录只列章**（`\setcounter{tocdepth}{0}`）。
- `main.tex` 中 Part 14、Part 15 依次位于 `\part{References}` 之前；每个 Part 先有英文目录名的 `\part` 与 Part 导读章，再按单元加入中文“主题：钩子句”章块。

### 内容单元示例

```
tex/05-Probability/
├── 00-MOC.tex
├── 01-Probability-Spaces/
│   ├── 00-MOC.tex
│   ├── 01-随机实验样本空间与事件.tex
│   ├── 02-概率公理与概率空间.tex
│   └── 03-从现实问题到概率模型.tex
├── 02-Conditional-Probability/
│   ├── 00-MOC.tex
│   └── ...
└── ...
```

## 写作与代码风格

### LaTeX 风格

- 文档类与宏包集中在 `main.tex` 中加载，子文件不重复加载宏包。
- **全局符号宏集中在 `tex/macros.tex`**（`main.tex` 导言区 `\input{tex/macros.tex}`）：`\E \Prob \Var \Cov \R \N \Z \Q \C \KL \ind \argmax \argmin \trans \norm \abs \ip \set \given` 等，全部为 `\providecommand`。新增或修改数学内容时优先使用宏；风格约定见 `STYLE_GUIDE.md`。
- 列表环境使用 `enumitem` 宏包，并在 `main.tex` 中定义了 `\tightlist` 命令以压缩间距：`\providecommand{\tightlist}{\setlength{\itemsep}{0pt}\setlength{\parskip}{0pt}}`。
- 表格主要使用 `longtable` 环境，并配合 `\def\LTcaptype{none}` 避免表格标题计数器递增。
- 中文标点与西文公式混用，章节标题和正文以中文为主。
- 数学符号使用标准 AMS 宏包加上述项目宏，不另外自定义大量命令。

### 内容风格

- 每章通常从“为什么需要”开始，用例子建立直觉，再给出定义、定理和推导。
- 强调反例、边界条件和常见误解，例如“前提为假时蕴含为何为真”、“P 值不是原假设为真的概率”。
- 用完整示范、反例与边界变化检验理解是否迁移；不设置“练习/习题/任务”式小节。

## 测试与验证

本项目没有自动化测试套件。验证内容正确性的主要方式是：

1. **LaTeX 编译通过**：运行 `xelatex main.tex` 无错误、无致命警告。
2. **目录结构一致**：新增单元后需在 `main.tex` 中按现有模式追加单元章块（`\chapter*`、`\addcontentsline`、连续 `\input`、`\clearpage`）；新增篇目后需在该单元章块内追加 `\input`。
3. **交叉引用检查**：确保各 `00-MOC.tex` 与正文中以``标题''形式引用的其他章与 `main.tex` 中的实际章标题一致。
4. **内容审校**：数学定义、量词范围、反例和边界条件需人工核对。

## 修改与扩展指南

### 新增一个学科 Part

1. 在 `tex/` 下新建对应目录，例如 `tex/17-New-Subject/`。
2. 在该目录下创建 `00-MOC.tex` 作为 Part 导读。
3. 按主题划分子目录，每个子目录（单元）下放置 `00-MOC.tex` 与具体小节 `.tex` 文件。
4. 在 `main.tex` 末尾、References Part 之前添加：

   ```latex
   \part{New-Subject}
   \chapter*{17-New-Subject}
   \addcontentsline{toc}{chapter}{17-New-Subject}
   \input{tex/17-New-Subject/00-MOC.tex}
   \clearpage
   ```

5. 继续按下面的"新增一个单元"模式追加各单元章块。

### 新增一个单元

1. 在对应 Part 下新建子目录，例如 `tex/XX-Subject/YY-New-Unit/`。
2. 创建 `00-MOC.tex` 作为单元导读（直接以导读文字开头，**不要**写 `\section{...}` 首行——章标题只放在 `main.tex`）。
3. 在 `main.tex` 中对应位置追加单元章块：

   ```latex
   \chapter*{单元标题}
   \addcontentsline{toc}{chapter}{单元标题}
   \input{tex/XX-Subject/YY-New-Unit/00-MOC.tex}
   \input{tex/XX-Subject/YY-New-Unit/01-小节标题.tex}
   \clearpage
   ```

### 新增一节

1. 在对应单元子目录中创建新 `.tex` 文件，文件名遵循 `NN-中文标题.tex` 的格式。
2. 文件内容通常以 `\section{...}` 开头（渲染为章内小节，无编号）。
3. 在该单元章块内对应位置追加一行 `\input{tex/XX-Subject/YY-Unit/NN-中文标题.tex}`，**不需要**新增 `\chapter*`。

### 修改现有章节

- 直接编辑 `tex/` 下对应的 `.tex` 文件。
- 章标题只存在于 `main.tex` 的 `\chapter*` 行；重命名一个单元时修改该行即可，并保持与各篇内容一致。
- 篇与篇相互引用使用"上一节/下一节/本节"（同一章内），跨单元引用用``单元标题''（中文书名号式引号）。

## 安全与部署

- 本项目是纯静态文档，不涉及网络、数据库、密钥或运行时环境。
- 没有部署流程；发布产物是编译得到的 PDF。
- 不涉及用户输入或外部依赖，因此没有传统意义上的安全漏洞向量。
- 如果未来通过 CI 自动编译 PDF，注意保持 `ctex` 宏包与 XeLaTeX 环境的可用性。

## 参考资料

各学科的推荐课程、教材和公开讲义统一列在 `tex/16-References/00-MOC.tex` 中。引用遵循短引述原则，不在知识库中大段复制受版权保护的内容。
