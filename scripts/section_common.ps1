<#
.SYNOPSIS
    Shared helpers for per-section (篇) build/check scripts.

.DESCRIPTION
    Provides the repo root, an output-dir helper, and the PDF-to-tex
    resolution used by both the compile task and the style-check task. Keep
    PowerShell-compatible with both PowerShell 5.1 and PowerShell 7.
#>

$script:SectionRoot = Split-Path -Parent $PSScriptRoot

function Get-SectionRoot {
    return $script:SectionRoot
}

function Ensure-Dir($path) {
    if (-not (Test-Path $path)) {
        New-Item -ItemType Directory -Force -Path $path | Out-Null
    }
}

function Resolve-SectionInput {
    param(
        [Parameter(Mandatory = $true)]
        [string]$File,
        [Parameter(Mandatory = $true)]
        [string]$OutputDir,
        [Parameter(Mandatory = $true)]
        [string]$Root
    )

    if (-not ($File -match '\.pdf$')) {
        return [System.IO.Path]::GetFullPath($File)
    }

    $inputPath = [System.IO.Path]::GetFullPath($File)
    $outputDirFull = [System.IO.Path]::GetFullPath($OutputDir)
    if (-not $inputPath.StartsWith($outputDirFull, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "PDF must be inside $OutputDir to auto-resolve source: $File"
    }
    $rel = $inputPath.Substring($outputDirFull.Length).TrimStart('\', '/')

    if ($rel -match '[\\/]') {
        # New naming: pdf/sections mirrors the tex/ tree.
        $sourceRel = [System.IO.Path]::ChangeExtension($rel, ".tex")
        $sourcePath = Join-Path (Join-Path $Root "tex") $sourceRel
        if (-not (Test-Path $sourcePath)) {
            throw "Cannot map PDF back to a source tex file: $sourcePath"
        }
        return [System.IO.Path]::GetFullPath($sourcePath)
    }

    # Legacy naming: flat sec-<path-with-dashes>.pdf. Match against the
    # complete tex/ tree so hyphens inside path segments stay unambiguous.
    $legacyTarget = $rel.Substring(0, $rel.Length - 4)   # drop .pdf
    $texRoot = Join-Path $Root "tex"
    $legacyMatch = Get-ChildItem -Path $texRoot -Recurse -Filter *.tex | Where-Object {
        $candidateRel = $_.FullName.Substring($texRoot.Length).TrimStart('\', '/')
        $candidate = 'sec-' + ($candidateRel -replace '[\\/]', '-' -replace '\.tex$', '')
        $candidate -eq $legacyTarget
    }
    if (-not $legacyMatch) {
        throw "Cannot map legacy PDF back to a source tex file: $rel"
    }
    if ($legacyMatch.Count -gt 1) {
        throw "Legacy PDF maps to multiple source tex files: $rel"
    }
    return [System.IO.Path]::GetFullPath($legacyMatch[0].FullName)
}
