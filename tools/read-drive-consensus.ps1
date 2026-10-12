$ErrorActionPreference = 'Stop'
$dir = 'P:\My Drive\AI Agents & Prompts'
$f = Get-ChildItem -LiteralPath $dir -Filter '*.md' | Select-Object -First 1
$dest = 'C:\Users\D\Documents\Collider\docs\CONSENSUS-AGENT-DRIVE-AUTHORITATIVE.md'
$short = Join-Path $env:TEMP 'consensus-agent-drive.md'
Copy-Item -LiteralPath $f.FullName -Destination $short -Force
Copy-Item -LiteralPath $short -Destination $dest -Force
Write-Output "OK $((Get-Item -LiteralPath $dest).Length) bytes -> $dest"