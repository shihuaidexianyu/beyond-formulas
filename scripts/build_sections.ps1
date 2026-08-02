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
$root = Split-Path -Parent $PSScriptRoot
$outputDir = Join-Path (Join-Path $root "pdf") "sections"
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

# If the task was started while a generated PDF is the active tab (VS Code hands
# the active file to ${file}), resolve that PDF back to its source tex file.
if ($File -match '\.pdf$') {
    $inputPath = [System.IO.Path]::GetFullPath($File)
    $outputDirFull = [System.IO.Path]::GetFullPath($outputDir)
    if (-not $inputPath.StartsWith($outputDirFull, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "PDF must be inside $outputDir to auto-resolve source: $File"
    }
    $rel = $inputPath.Substring($outputDirFull.Length).TrimStart('\', '/')
    $sourceRel = [System.IO.Path]::ChangeExtension($rel, ".tex")
    $sourcePath = Join-Path (Join-Path $root "tex") $sourceRel
    if (-not (Test-Path $sourcePath)) {
        throw "Cannot map PDF back to a source tex file: $sourcePath"
    }
    $File = [System.IO.Path]::GetFullPath($sourcePath)
    Write-Host "Resolved PDF $rel -> source $sourceRel" -ForegroundColor Yellow
}

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
    @("-interaction=nonstopmode", "-output-directory", $outputDir, $wrapperPath),
    @("-interaction=nonstopmode", "-output-directory", $outputDir, $wrapperPath)
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
    Get-ChildItem -Path $outputDir -Filter "$base.*" | Where-Object { $_.Extension -ne '.pdf' } | Remove-Item -Force
}
if (Test-Path $wrapperPath) {
    Remove-Item $wrapperPath -Force
}

Write-Host "Done: $dstPdf" -ForegroundColor Green
