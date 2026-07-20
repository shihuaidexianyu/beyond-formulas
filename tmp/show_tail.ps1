param(
  [Parameter(Mandatory=$true)][string]$File,
  [Parameter(Mandatory=$true)][int]$Line
)
$lines = Get-Content $File
$total = $lines.Count
Write-Host "=== $File (total $total, match at line $Line) ==="
for ($i = $Line - 1; $i -lt $total; $i++) {
  Write-Host ("{0}: {1}" -f ($i+1), $lines[$i])
}
