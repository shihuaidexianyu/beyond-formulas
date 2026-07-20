param(
  [Parameter(Mandatory=$true)][string]$File,
  [Parameter(Mandatory=$true)][int]$Line
)
$lines = Get-Content $File
$total = $lines.Count
$matchLine = $lines[$Line - 1]
if ($matchLine -notmatch '^\\(sub)*subsection\{') {
  Write-Host "SKIP: line $Line is not a subsection in $File"
  exit 0
}
# Verify the match line is one of the target titles
if ($matchLine -notmatch '(自己|最后|留给|思考|判断|一个.*(实验|辨认)|一次正确|检验理解|动手|试试|练习)') {
  Write-Host "SKIP: title not a target: $matchLine"
  exit 0
}
# Delete from $Line to EOF
$keep = $lines[0..($Line - 2)]
Set-Content -Path $File -Value $keep -Encoding UTF8
Write-Host "DELETED from line $Line to EOF in $File (was $total lines, now $($keep.Count))"
