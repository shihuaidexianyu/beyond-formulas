<#
.SYNOPSIS
    Compile a single section (篇) into its own PDF for fast preview.

.DESCRIPTION
    Creates a temporary wrapper that reuses the book preamble and macros,
    imports the root main.aux labels with xr-hyper, and compiles only the
    active section into pdf/sections. Run one full main.tex compile first
    so main.aux is fresh.

.EXAMPLE
    .\scripts\build_sections.ps1 -File tex\02-Calculus\03-Differentiation\05-linear-approx.tex
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
. (Join-Path $PSScriptRoot "section_common.ps1")
$root = Get-SectionRoot
$outputDir = Join-Path (Join-Path $root "pdf") "sections"
$buildDir = Join-Path $root "build"
$metaPath = Join-Path $buildDir "sections-meta.json"

Ensure-Dir $outputDir
Ensure-Dir $buildDir
Set-Location $root

# If the task was started while a generated PDF is the active tab (VS Code hands
# the active file to ${file}), resolve that PDF back to its source tex file.
$File = Resolve-SectionInput -File $File -OutputDir $outputDir -Root $root

Write-Host "=== Generate section wrapper: $File ===" -ForegroundColor Cyan
$pyOut = & $Python scripts/build_sections.py --root $root --meta $metaPath --file $File 2>&1
$pyOut | ForEach-Object { Write-Host "  $_" }
if ($LASTEXITCODE -ne 0) {
    throw "Failed to generate section wrapper."
}

if (-not (Test-Path $metaPath)) {
    throw "Metadata file missing: $metaPath"
}
$info = Get-Content $metaPath -Encoding UTF8 -Raw | ConvertFrom-Json
$wrapperName = $info.wrapper
$pdfName = $info.pdf
$wrapperPath = Join-Path $root $wrapperName
$base = [System.IO.Path]::GetFileNameWithoutExtension($wrapperName)
$srcPdf = Join-Path $outputDir "$base.pdf"
$dstPdf = Join-Path $outputDir $pdfName

$passes = @(
    @("-interaction=nonstopmode", "-synctex=1", "-output-directory", $outputDir, $wrapperPath),
    @("-interaction=nonstopmode", "-synctex=1", "-output-directory", $outputDir, $wrapperPath)
)
$passNum = 1
foreach ($args_ in $passes) {
    Write-Host "  xelatex pass $passNum : $wrapperName ..."
    & $Xelatex @args_
    if ($LASTEXITCODE -ne 0) {
        throw "$wrapperName compile failed (exit code $LASTEXITCODE)."
    }
    $passNum++
}

if (Test-Path $srcPdf) {
    $dstDir = Split-Path $dstPdf -Parent
    Ensure-Dir $dstDir
    Move-Item $srcPdf $dstPdf -Force
    $srcSynctex = Join-Path $outputDir "$base.synctex.gz"
    if (Test-Path $srcSynctex) {
        $dstStem = [System.IO.Path]::GetFileNameWithoutExtension($pdfName)
        $dstSynctex = Join-Path $dstDir "$dstStem.synctex.gz"
        Move-Item $srcSynctex $dstSynctex -Force
    }
} else {
    throw "Expected output not found: $srcPdf"
}

$log = Join-Path $outputDir "$base.log"
if (Test-Path $log) {
    $fatal = Select-String -Path $log -Pattern '^! |Undefined control sequence|Emergency stop'
    if ($fatal) {
        $fatal | ForEach-Object { Write-Host $_ -ForegroundColor Red }
        throw "$wrapperName has fatal LaTeX errors."
    }
}

if (-not $KeepAux) {
    Get-ChildItem -Path $outputDir -Filter "$base.*" | Where-Object { $_.Name -notlike '*.synctex.gz' } | Remove-Item -Force
}
if (Test-Path $wrapperPath) {
    Remove-Item $wrapperPath -Force
}

Write-Host "Done: $dstPdf" -ForegroundColor Green
