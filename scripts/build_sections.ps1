<#
.SYNOPSIS
    编译当前篇（单个 篇 tex 文件）为独立 PDF，用于快速预览。

.DESCRIPTION
    生成包含全书前言与宏的临时入口，导入根目录 main.aux 的标签，
    只编译被打开的单个篇文件。需要先至少完整编译一次 main.tex。

.EXAMPLE
    .\scripts\build_sections.ps1 -File tex\01-Mathematical-Language\01-Logic\03-量词与否定.tex
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$File,
    [switch]$KeepAux,
    [string]$Xelatex = "xelatex",
    [string]$Python = "python"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$outputDir = Join-Path $root "pdf" "sections"
$buildDir = Join-Path $root "build"
$metaPath = Join-Path $buildDir "sections-meta.json"

function Ensure-Dir($path) {
    if (-not (Test-Path $path)) {
        New-Item -ItemType Directory -Force -Path $path | Out-Null
    }
}

Ensure-Dir $outputDir
Ensure-Dir $buildDir
Set-Location $root

Write-Host "=== 生成当前篇编译入口：$File ===" -ForegroundColor Cyan
$pyOut = & $Python scripts/build_sections.py --root $root --meta $metaPath --file $File 2>&1
$pyOut | ForEach-Object { Write-Host "  $_" }
if ($LASTEXITCODE -ne 0) {
    throw "生成当前篇入口失败。"
}

if (-not (Test-Path $metaPath)) {
    throw "无法找到 build_sections.py 的元数据文件：$metaPath"
}
$info = Get-Content $metaPath -Encoding UTF8 -Raw | ConvertFrom-Json
$wrapperName = $info.wrapper
$pdfName = $info.pdf
$wrapperPath = Join-Path $root $wrapperName
$base = [System.IO.Path]::GetFileNameWithoutExtension($wrapperName)
$srcPdf = Join-Path $outputDir "$base.pdf"
$dstPdf = Join-Path $outputDir $pdfName

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

if (Test-Path $srcPdf) {
    Move-Item $srcPdf $dstPdf -Force
} else {
    throw "未找到预期输出：$srcPdf"
}

$log = Join-Path $outputDir "$base.log"
if (Test-Path $log) {
    $fatal = Select-String -Path $log -Pattern '^! |Undefined control sequence|Emergency stop'
    if ($fatal) {
        $fatal | ForEach-Object { Write-Host $_ -ForegroundColor Red }
        throw "$wrapperName 存在致命 LaTeX 错误。"
    }
}

if (-not $KeepAux) {
    Get-ChildItem -Path $outputDir -Filter "$base.*" | Where-Object { $_.Extension -ne '.pdf' } | Remove-Item -Force
}
if (Test-Path $wrapperPath) {
    Remove-Item $wrapperPath -Force
}

Write-Host "完成：$dstPdf" -ForegroundColor Green
