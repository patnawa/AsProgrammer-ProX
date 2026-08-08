# Extracts or replaces source comments, for translating them in bulk.
#
#   tools\comments.ps1 -Mode dump  -Files main.pas,spi25.pas -Out comments.tsv
#   tools\comments.ps1 -Mode apply -Map translated.tsv
#
# dump  writes  file <TAB> line <TAB> comment text
# apply reads the same columns back and rewrites the comment text in place,
# leaving the code before the comment untouched.
#
# Use -Out rather than `>`: under Windows PowerShell 5.1 redirection writes
# UTF-16, which apply's UTF-8 reader then fails to split and silently no-ops.
#
# Only // comments outside string literals and { } blocks that are not
# compiler directives ({$...}) are touched.

param(
  [ValidateSet('dump','apply')] [string]$Mode = 'dump',
  [string[]]$Files,
  [string]$Map,
  [string]$Out
)

$ErrorActionPreference = 'Stop'
$root = Join-Path (Split-Path -Parent $PSScriptRoot) 'software'
$utf8 = New-Object System.Text.UTF8Encoding($false)

function Find-CommentStart([string]$line) {
  # returns index of the // that starts a comment, or -1
  $inStr = $false
  for ($i = 0; $i -lt $line.Length; $i++) {
    $c = $line[$i]
    if ($c -eq "'") { $inStr = -not $inStr; continue }
    if ($inStr) { continue }
    if ($c -eq '/' -and $i + 1 -lt $line.Length -and $line[$i+1] -eq '/') { return $i }
    # a { that is not a directive starts a brace comment
    if ($c -eq '{' -and ($i + 1 -ge $line.Length -or $line[$i+1] -ne '$')) { return $i }
  }
  return -1
}

if ($Mode -eq 'dump') {
  $outLines = foreach ($f in $Files) {
    $path = Join-Path $root $f
    if (-not (Test-Path $path)) { continue }
    $lines = [System.IO.File]::ReadAllLines($path, $utf8)
    for ($n = 0; $n -lt $lines.Length; $n++) {
      $idx = Find-CommentStart $lines[$n]
      if ($idx -lt 0) { continue }
      $text = $lines[$n].Substring($idx).TrimEnd()
      if ($text -match '^\s*$') { continue }
      "{0}`t{1}`t{2}" -f $f, ($n + 1), $text
    }
  }
  if ($Out) {
    [System.IO.File]::WriteAllLines($Out, [string[]]$outLines, $utf8)
  } else {
    $outLines
  }
  exit 0
}

# apply
$rows = [System.IO.File]::ReadAllLines($Map, $utf8)
$byFile = @{}
$parsed = 0
foreach ($r in $rows) {
  if ($r.Trim() -eq '') { continue }
  $p = $r -split "`t", 3
  if ($p.Count -lt 3) { continue }
  if (-not $byFile.ContainsKey($p[0])) { $byFile[$p[0]] = @{} }
  $byFile[$p[0]][[int]$p[1]] = $p[2]
  $parsed++
}
if ($parsed -eq 0) {
  # A TSV with zero usable rows is an input problem (usually UTF-16 from `>`),
  # never a valid no-op; failing loudly beats "replaced nothing" silence.
  throw "no usable rows in $Map (is it tab-separated UTF-8? dump with -Out, not >)"
}

foreach ($f in $byFile.Keys) {
  $path = Join-Path $root $f
  if (-not (Test-Path $path)) { Write-Host "skip missing $f"; continue }
  $lines = [System.IO.File]::ReadAllLines($path, $utf8)
  $n = 0
  foreach ($ln in $byFile[$f].Keys) {
    $i = $ln - 1
    if ($i -lt 0 -or $i -ge $lines.Length) { continue }
    $idx = Find-CommentStart $lines[$i]
    if ($idx -lt 0) { continue }
    $lines[$i] = $lines[$i].Substring(0, $idx) + $byFile[$f][$ln]
    $n++
  }
  [System.IO.File]::WriteAllLines($path, $lines, $utf8)
  Write-Host "$f : $n comments replaced"
}
