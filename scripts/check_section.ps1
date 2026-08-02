<#
.SYNOPSIS
    Run style checks on a single 篇 tex file (or the tex resolved from
    a generated section PDF).
.EXAMPLE
    .\scripts\check_section.ps1 -File tex\02-Calculus\03-Differentiation\05-linear-approx.tex
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
Write-Host "=== Check section: $File ===" -ForegroundColor Cyan
& $Python scripts/check_section.py --root $root --file $File
exit $LASTEXITCODE
