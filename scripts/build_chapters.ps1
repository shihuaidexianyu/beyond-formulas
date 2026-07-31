<#
.SYNOPSIS
    编译《Beyond Formulas》完整书或单章 PDF。

.DESCRIPTION
    默认先编译完整书以刷新 main.aux，再生成并编译指定章或全部章。
    单章 PDF 会导入完整书的标签，使交叉引用文本/页码正确。

.EXAMPLE
    .\scripts\build_chapters.ps1 -Full
    .\scripts\build_chapters.ps1 -All
    .\scripts\build_chapters.ps1 -Chapter ch:004
    .\scripts\build_chapters.ps1 -Chapter "函数与预备知识" -SkipFull
    .\scripts\build_chapters.ps1 -All -Parallel -ThrottleLimit 4
#>
[CmdletBinding()]
param(
    [switch]$Full,                 # 只编译完整书
    [switch]$All,                  # 编译完整书 + 全部单章
    [string[]]$Chapter,            # 编译一个或多个章（ch:NNN 或标题关键词）
    [switch]$Parallel,             # 并行编译单章（实验性）
    [int]$ThrottleLimit = 4,      # 并行并发数
    [switch]$KeepAux,              # 保留单章 aux/log
    [switch]$SkipFull,             # 跳过完整书编译（要求 main.aux 已存在且新鲜）
    [string]$Xelatex = "xelatex",  # xelatex 路径
    [string]$Python = "python"     # python 路径
)

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$outputDir = Join-Path $root "pdf" "chapters"
$buildDir = Join-Path $root "build"

function Ensure-Dir($path) {
    if (-not (Test-Path $path)) {
        New-Item -ItemType Directory -Force -Path $path | Out-Null
    }
}

function Invoke-FullBuild {
    Write-Host "=== 编译完整书 ===" -ForegroundColor Cyan
    Set-Location $root

    $log = Join-Path $root "main.log"
    $pdf = Join-Path $root "main.pdf"

    # 先清理旧的 main.pdf，避免误判
    if (Test-Path $pdf) { Remove-Item $pdf -Force }

    $passes = @(
        @("-interaction=nonstopmode", "main.tex"),
        @("-interaction=nonstopmode", "main.tex")
    )
    $passNum = 1
    foreach ($args_ in $passes) {
        Write-Host "完整书第 $passNum 次 xelatex ..."
        & $Xelatex @args_
        if ($LASTEXITCODE -ne 0) {
            throw "完整书第 $passNum 次编译失败（退出码 $LASTEXITCODE）。请查看 $log"
        }
        $passNum++
    }

    # 验证：未定义控制序列、未定义引用
    $bad = Select-String -Path $log `
        -Pattern 'Undefined control sequence|LaTeX Warning: Reference|LaTeX Warning: There were undefined'
    if ($bad) {
        $bad | ForEach-Object { Write-Host $_ -ForegroundColor Red }
        throw "完整书存在未定义引用或控制序列，请先修正。"
    }

    Write-Host "完整书编译完成：$pdf" -ForegroundColor Green
}

function Test-MainAux {
    $aux = Join-Path $root "main.aux"
    if (-not (Test-Path $aux)) {
        throw "$aux 不存在。请先运行 -Full 或不带 -SkipFull 的编译。"
    }
}

function Invoke-ChapterCompile($wrapperName, $pdfName) {
    $wrapperPath = Join-Path $root $wrapperName
    $base = [System.IO.Path]::GetFileNameWithoutExtension($wrapperName)
    $srcPdf = Join-Path $outputDir "$base.pdf"
    $dstPdf = Join-Path $outputDir $pdfName

    Ensure-Dir $outputDir

    $passes = @(
        @("-interaction=nonstopmode", "-output-directory", $outputDir, $wrapperPath),
        @("-interaction=nonstopmode", "-output-directory", $outputDir, $wrapperPath)
    )
    $passNum = 1
    foreach ($args_ in $passes) {
        Write-Host "  第 $passNum 次 xelatex：$wrapperName ..."
        & $Xelatex @args_
        if ($LASTEXITCODE -ne 0) {
            throw "$wrapperName 第 $passNum 次编译失败（退出码 $LASTEXITCODE）。"
        }
        $passNum++
    }

    # 重命名为含标题的中文名
    if (Test-Path $srcPdf) {
        Move-Item $srcPdf $dstPdf -Force
    } else {
        throw "未找到预期输出：$srcPdf"
    }

    # 简单检查致命错误（允许未解决的引用警告）
    $log = Join-Path $outputDir "$base.log"
    if (Test-Path $log) {
        $fatal = Select-String -Path $log -Pattern '^! |Undefined control sequence|Emergency stop'
        if ($fatal) {
            $fatal | ForEach-Object { Write-Host $_ -ForegroundColor Red }
            throw "$wrapperName 存在致命 LaTeX 错误。"
        }
    }

    # 清理单章辅助文件
    if (-not $KeepAux) {
        Get-ChildItem -Path $outputDir -Filter "$base.*" | Where-Object { $_.Extension -ne '.pdf' } | Remove-Item -Force
    }

    # 删除根目录的临时入口
    if (Test-Path $wrapperPath) { Remove-Item $wrapperPath -Force }

    return $dstPdf
}

function Build-ChapterByQuery($query) {
    Write-Host "=== 生成并编译：$query ===" -ForegroundColor Cyan
    Set-Location $root

    $pyOut = & $Python scripts/build_chapters.py --chapter $query 2>&1
    $pyOut | ForEach-Object { Write-Host "  $_" }
    if ($LASTEXITCODE -ne 0) {
        throw "生成章节入口失败：$query"
    }

    # 解析 Python 输出中的机器可读 META 行（避免中文编码问题）
    $meta = $pyOut | Select-String -Pattern '^META:(.+)$'
    if (-not $meta) {
        throw "无法解析 build_chapters.py 的 META 输出。"
    }
    $info = $meta.Matches[0].Groups[1].Value | ConvertFrom-Json
    $wrapperName = $info.wrapper
    $pdfName = $info.pdf

    $outPdf = Invoke-ChapterCompile $wrapperName $pdfName
    Write-Host "完成：$outPdf" -ForegroundColor Green
    return $outPdf
}

function Build-AllChapters {
    Write-Host "=== 生成全部单章入口 ===" -ForegroundColor Cyan
    Set-Location $root

    & $Python scripts/build_chapters.py --all 2>&1 | ForEach-Object { Write-Host "  $_" }
    if ($LASTEXITCODE -ne 0) {
        throw "生成全部章节入口失败。"
    }

    $manifestPath = Join-Path $buildDir "chapters-manifest.json"
    $manifest = Get-Content $manifestPath -Encoding UTF8 | ConvertFrom-Json -Depth 10

    Ensure-Dir $outputDir

    $completed = @()
    $failed = @()

    if ($Parallel) {
        Write-Host "=== 并行编译 $($manifest.Count) 章（并发 $ThrottleLimit） ===" -ForegroundColor Cyan
        $manifest | ForEach-Object -Parallel {
            $root_ = $using:root
            $outputDir_ = $using:outputDir
            $Xelatex_ = $using:Xelatex
            $KeepAux_ = $using:KeepAux
            $wrapperName = $_.wrapper
            $pdfName = $_.pdf

            $wrapperPath = Join-Path $root_ $wrapperName
            $base = [System.IO.Path]::GetFileNameWithoutExtension($wrapperName)
            $srcPdf = Join-Path $outputDir_ "$base.pdf"
            $dstPdf = Join-Path $outputDir_ $pdfName

            $passes = @(
                @("-interaction=nonstopmode", "-output-directory", $outputDir_, $wrapperPath),
                @("-interaction=nonstopmode", "-output-directory", $outputDir_, $wrapperPath)
            )
            $ok = $true
            $passNum = 1
            foreach ($args_ in $passes) {
                & $Xelatex_ @args_ | Out-Null
                if ($LASTEXITCODE -ne 0) { $ok = $false; break }
                $passNum++
            }

            if ($ok -and (Test-Path $srcPdf)) {
                Move-Item $srcPdf $dstPdf -Force
                if (-not $KeepAux_) {
                    Get-ChildItem -Path $outputDir_ -Filter "$base.*" | Where-Object { $_.Extension -ne '.pdf' } | Remove-Item -Force
                }
                Remove-Item $wrapperPath -Force
                [PSCustomObject]@{ Status = 'OK'; Pdf = $dstPdf }
            } else {
                [PSCustomObject]@{ Status = 'FAIL'; Wrapper = $wrapperName }
            }
        } -ThrottleLimit $ThrottleLimit | ForEach-Object {
            if ($_.Status -eq 'OK') {
                $completed += $_.Pdf
            } else {
                $failed += $_.Wrapper
            }
        }
    } else {
        Write-Host "=== 顺序编译 $($manifest.Count) 章 ===" -ForegroundColor Cyan
        foreach ($entry in $manifest) {
            try {
                $outPdf = Invoke-ChapterCompile $entry.wrapper $entry.pdf
                $completed += $outPdf
                Write-Host "完成：$outPdf" -ForegroundColor Green
            } catch {
                Write-Host "失败：$($entry.wrapper) - $_" -ForegroundColor Red
                $failed += $entry.wrapper
            }
        }
    }

    Write-Host ""
    Write-Host "=== 单章编译汇总 ===" -ForegroundColor Cyan
    Write-Host "成功：$($completed.Count)"
    Write-Host "失败：$($failed.Count)"
    if ($failed.Count -gt 0) {
        $failed | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
    }
}

# ===== 主流程 =====

Ensure-Dir $outputDir
Ensure-Dir $buildDir

if ($Full) {
    Invoke-FullBuild
    return
}

if ($All -or $Chapter) {
    if (-not $SkipFull) {
        Invoke-FullBuild
    } else {
        Test-MainAux
    }
}

if ($All) {
    Build-AllChapters
    return
}

if ($Chapter) {
    foreach ($q in $Chapter) {
        Build-ChapterByQuery $q
    }
    return
}

Write-Host "请指定 -Full、-All 或 -Chapter。使用 Get-Help .\scripts\build_chapters.ps1 查看说明。" -ForegroundColor Yellow
