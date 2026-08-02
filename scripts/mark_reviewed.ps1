<#
.SYNOPSIS
    Mark the current 篇 as reviewed in docs/review.md.
.EXAMPLE
    .\scripts\mark_reviewed.ps1 -File tex\02-Calculus\03-Differentiation\05-linear-approx.tex
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$File,
    [string]$Python = "python"
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "section_common.ps1")
$root = Get-SectionRoot
$outputDir = Join-Path (Join-Path $root "pdf") "sections"

$File = Resolve-SectionInput -File $File -OutputDir $outputDir -Root $root
Write-Host "=== Mark reviewed: $File ===" -ForegroundColor Cyan
& $Python scripts/mark_reviewed.py --root $root --file $File
& $Python scripts/review_summary.py
exit $LASTEXITCODE
