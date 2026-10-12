$ErrorActionPreference = 'Stop'
$src = 'C:\Users\D\Documents\Collider\source\build\web'
$dst = 'C:\Users\D\Documents\Collider\app'
# Mirror the fresh build over the served directory. Robocopy keeps timestamps
# and does not delete the extras the build does not emit.
$args = @($src, $dst, '/MIR', '/R:2', '/W:1', '/NFL', '/NDL', '/NJH', '/NJS', '/NP')
& robocopy @args | Out-Null
$code = $LASTEXITCODE
if ($code -ge 8) { throw "robocopy failed with $code" }
Write-Host "robocopy exit $code (0-7 are success)"
Get-Item "$dst\main.dart.js" | Select-Object Length, LastWriteTime | Format-List
Get-Item "$dst\assets\html\consensus.html" | Select-Object Length, LastWriteTime | Format-List