$pattern = '\\(sub)*subsection\{(自己|最后|留给|思考|判断|一个.*(实验|辨认)|一次正确|检验理解|动手|试试|练习)[^}]*\}'
$files = Get-ChildItem -Recurse "tex" -Filter *.tex | Where-Object { $_.FullName -notmatch '\\(00-MOC|学习路线|知识地图|macros)\.tex$' }
$report = @()
foreach ($f in $files) {
  $lines = Get-Content $f.FullName
  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match $pattern) {
      $next = -1
      for ($j = $i+1; $j -lt $lines.Count; $j++) {
        if ($lines[$j] -match '^\\(section|subsection|subsubsection)\{') { $next = $j; break }
      }
      $report += [PSCustomObject]@{
        File = $f.FullName.Replace("$PWD\", "")
        Line = $i+1
        Title = $matches[0]
        NextSectionAt = if ($next -ge 0) { $next+1 } else { "EOF" }
        TotalLines = $lines.Count
      }
    }
  }
}
$report | Format-Table -AutoSize | Out-String -Width 200
