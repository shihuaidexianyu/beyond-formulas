# Beyond Formulas 分章/整书编译脚本

这两个脚本在**不修改任何 `tex/` 正文**的前提下，为每章生成临时编译入口，并导入完整书的标签，使单章 PDF 的交叉引用文字/页码保持正确。

## 前置要求

- Windows + PowerShell 7（`pwsh`）或 Windows PowerShell 5.1
- Python 3
- XeLaTeX（TeX Live 2026 已验证）
- `xr-hyper` 宏包（TeX Live 自带）

## 文件

- `build_chapters.py` — 解析 `main.tex`、生成本章编译入口、生成过滤后的外部标签 aux。
- `build_chapters.ps1` — 编排完整书/单章的编译、重命名、清理。

## 用法

```powershell
# 只编译完整书（刷新 main.aux）
.\scripts\build_chapters.ps1 -Full

# 先编译完整书，再编译全部单章
.\scripts\build_chapters.ps1 -All

# 只编译指定章（默认先编译完整书）
.\scripts\build_chapters.ps1 -Chapter ch:004
.\scripts\build_chapters.ps1 -Chapter "函数与预备知识"

# 若确定 main.aux 已是最新，可跳过完整书编译
.\scripts\build_chapters.ps1 -Chapter ch:004 -SkipFull

# 并行编译全部单章（实验性）
.\scripts\build_chapters.ps1 -All -Parallel -ThrottleLimit 4

# 保留单章 aux/log 以便排查
.\scripts\build_chapters.ps1 -Chapter ch:004 -KeepAux
```

## 输出

- 完整书：`main.pdf`（仓库根目录）
- 单章 PDF：`pdf/chapters/P{part_index}-ch{NNN}-{标题}.pdf`
  - 前两章和参考资料没有 Part 前缀，文件名为 `ch{NNN}-{标题}.pdf`。
- 中间产物：
  - `build/main-for-chNNN.aux`：过滤后的外部引用 aux。
  - `build/chapters-manifest.json`：章节清单。
  - 临时入口 `chNNN.tex` 编译成功后自动删除（失败时保留）。

## 交叉引用

单章编译会提示 `LaTeX Warning: There were undefined references` 的**第一次**（因为本章标签尚未写入自己的 aux），第二遍编译后本章内部引用即正常。

指向其他章的引用通过 `xr-hyper` + `build/main-for-chNNN.aux` 解析为完整书中的文字/页码；由于单章 PDF 不含其他章内容，点击这些链接不会跳转。

## 故障排查

- 如果 `main.aux` 不存在，脚本会要求先运行 `-Full`。
- 如果正文有改动，建议先 `-Full` 刷新 `main.aux`，再编译单章。
- 检查 `pdf/chapters/chNNN.log`（使用 `-KeepAux`）可定位单章编译错误。
