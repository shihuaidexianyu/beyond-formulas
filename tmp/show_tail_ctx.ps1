param(
  [Parameter(Mandatory=$true)][string]$File,
  [Parameter(Mandatory=$true)][int]$Line
)
$lines = Get-Content $File
$total = $lines.Count
$matchLine = $lines[$Line - 1]
if ($matchLine -notmatch '^\\(sub)*subsection\{') {
  Write-Host "ERROR: line $Line is not a subsection: $matchLine"
  exit 1
}
Write-Host "=== $File (total $total, match at line $Line) ==="
# print context before
$ctxStart = [Math]::Max(0, $Line - 3)
for ($i = $ctxStart; $i -lt $Line - 1; $i++) {
  Write-Host ("CTX {0}: {1}" -f ($i+1), $lines[$i])
}
Write-Host "--- TO DELETE from line $Line to EOF ---"
for ($i = $Line - 1; $i -lt $total; $i++) {
  Write-Host ("{0}: {1}" -f ($i+1), $lines[$i])
}
